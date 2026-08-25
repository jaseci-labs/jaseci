#!/usr/bin/env python3
"""D2 mechanical test-conversion pipeline: CPython Lib/test file -> .jac pins.

For every ``test_*`` method in a CPython ``Lib/test`` file this tool:

1. Extracts the method via AST and mechanically rewrites the common
   ``unittest`` assertion vocabulary (``assertEqual``, ``assertRaises``, ...)
   into plain asserts/try-except. ``setUp`` bodies are spliced ahead of each
   test (fixture vocabulary), and plain ``self.<attr>`` loads/stores are
   satisfied by binding ``self`` to a bare namespace object; anything outside
   the supported vocabulary (other ``self.*`` attributes, unresolved names,
   skip machinery, decorators) is quarantined with a reason instead of
   silently mistranslating.
2. Captures the HOST ORACLE first: each rewritten snippet runs under host
   CPython in a sandboxed subprocess (fresh cwd, minimal env, hard timeout).
   A snippet is only pinnable when the host prints the success marker;
   host-failing/host-timing-out snippets carry no usable oracle.
3. Emits a ``.jac`` pin file following the repo parity convention
   (``test "..." { ... }`` blocks calling ``layer_p2_libtest.p2_libtest_run_snippet``
   so every snippet executes on jacpython's ceval, never the host).
4. Writes a ``<name>.conv.json`` sidecar (per-test status, oracle, quarantine
   reasons) and registers the module in the conformance manifest consumed by
   ``conformance_dashboard.py``.

Usage:
    .venv/bin/python jac-py/tools/convert_suite.py \\
        reference/cpython/Lib/test/test_copy.py [-o OUTDIR] [--name conv_copy]

Package-style suites (``Lib/test/test_string/``, ``test_doctest/``, ...)
are directories: pass the INNER ``test_*.py`` file path explicitly and
disambiguate the output with ``--name`` (an inner file's stem can match
other suites), e.g.::

    .venv/bin/python jac-py/tools/convert_suite.py \\
        reference/cpython/Lib/test/test_string/test_string.py \\
        --name conv_string
"""
from __future__ import annotations

import argparse
import ast
import builtins
import copy
import doctest
import json
import os
import subprocess
import sys
import tempfile
import textwrap
from dataclasses import dataclass, field
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_DEFAULT_LIB = _REPO / "reference" / "cpython" / "Lib"
_TESTS_DIR = _REPO / "jac-py" / "tests"
_MANIFEST = _TESTS_DIR / "conformance_manifest_convpipe.json"

TOOL_VERSION = "conv_suite-0.4.0"
CPYTHON_VERSION = "3.14.6"


def attempt_header(command: list[str]) -> dict:
    """Build-contract fingerprint block shared by every emitted artifact."""
    import hashlib
    import subprocess as sp

    def _git(args: list[str], cwd: Path) -> str:
        try:
            return sp.run(["git"] + args, cwd=str(cwd), capture_output=True,
                          text=True, timeout=10).stdout.strip()
        except Exception:
            return "unknown"

    jac_exe = _REPO / ".venv" / "bin" / "jac"
    jac_sha = "unknown"
    if jac_exe.is_file():
        jac_sha = _git(["rev-parse", "HEAD"], _REPO)
    cpython_sha = _git(["rev-parse", "HEAD"], _REPO / "reference" / "cpython")
    hashes = {}
    for label, p in (("jac_source", _REPO / "jac"),):
        pass  # source-tree hash too costly per attempt; sha fields carry provenance
    return {
        "schema_version": 1,
        "tool_version": TOOL_VERSION,
        "jac_sha": jac_sha,
        "cpython": {"version": CPYTHON_VERSION, "sha": cpython_sha},
        "command": command,
        "generated_at": __import__("datetime").datetime.now().isoformat(timespec="seconds"),
        "hashes": hashes,
    }


def file_sha256(path: Path) -> str:
    import hashlib
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return h.hexdigest()

HOST_TIMEOUT = 60  # seconds, hard limit per oracle capture

_ORACLE_OK = "ok"
_ORACLE_EXC = "ORACLE_EXC "

@dataclass
class Quarantined:
    ident: str
    reason: str


@dataclass
class Pinned:
    ident: str
    snippet: str
    oracle: dict  # {"status": "ok"} after the host pass


@dataclass
class Extraction:
    pinned: list[Pinned] = field(default_factory=list)
    quarantined: list[Quarantined] = field(default_factory=list)


class Unsupported(Exception):
    """Raised during rewrite when a construct has no mechanical mapping."""


# ---------------------------------------------------------------------------
# Assertion rewriting (AST -> AST)


def _call_name(node: ast.expr) -> str | None:
    if (
        isinstance(node, ast.Attribute)
        and isinstance(node.value, ast.Name)
        and node.value.id == "self"
    ):
        return node.attr
    return None


def _msg_of(call: ast.Call, label: str, operands: list[ast.expr]) -> ast.expr:
    parts: list[ast.expr] = [ast.Constant(value=label)]
    parts.extend(operands)
    extra = None
    for kw in call.keywords:
        if kw.arg == "msg":
            extra = kw.value
    if extra is not None:
        parts.append(extra)
    return ast.Tuple(elts=parts, ctx=ast.Load())


def _binary_assert(
    call: ast.Call, label: str, op: type[ast.cmpop]
) -> ast.Assert:
    _need_args(call, 2)
    a, b = call.args[0], call.args[1]
    return ast.Assert(
        test=ast.Compare(left=a, ops=[op()], comparators=[b]),
        msg=_msg_of(call, label, [a, b]),
    )


def _unary_assert(call: ast.Call, negate: bool) -> ast.Assert:
    _need_args(call, 1)
    x = call.args[0]
    test: ast.expr = x
    if negate:
        test = ast.UnaryOp(op=ast.Not(), operand=x)
    return ast.Assert(test=test, msg=_msg_of(call, "assertFalse" if negate else "assertTrue", [x]))


def _isinstance_assert(call: ast.Call, negate: bool) -> ast.Assert:
    _need_args(call, 2)
    a, b = call.args[0], call.args[1]
    test: ast.expr = ast.Call(
        func=ast.Name(id="isinstance", ctx=ast.Load()), args=[a, b], keywords=[]
    )
    if negate:
        test = ast.UnaryOp(op=ast.Not(), operand=test)
    return ast.Assert(test=test, msg=_msg_of(call, "assertIsInstance", [a, b]))


def _almost_assert(call: ast.Call, negate: bool) -> ast.Assert:
    _need_args(call, 2)
    a, b = call.args[0], call.args[1]
    places: ast.expr = ast.Constant(value=7)
    if len(call.args) >= 3:
        places = call.args[2]
    for kw in call.keywords:
        if kw.arg == "places":
            places = kw.value
    delta = ast.BinOp(left=a, op=ast.Sub(), right=b)
    test: ast.expr = ast.Compare(
        left=ast.Call(
            func=ast.Name(id="round", ctx=ast.Load()), args=[delta, places], keywords=[]
        ),
        ops=[ast.NotEq() if negate else ast.Eq()],
        comparators=[ast.Constant(value=0)],
    )
    label = "assertNotAlmostEqual" if negate else "assertAlmostEqual"
    return ast.Assert(test=test, msg=_msg_of(call, label, [a, b]))


def _issubclass_assert(call: ast.Call) -> ast.Assert:
    _need_args(call, 2)
    a, b = call.args[0], call.args[1]
    return ast.Assert(
        test=ast.Call(func=ast.Name(id="issubclass", ctx=ast.Load()), args=[a, b], keywords=[]),
        msg=_msg_of(call, "assertIsSubclass", [a, b]),
    )


def _hasattr_assert(call: ast.Call, negate: bool) -> ast.Assert:
    _need_args(call, 2)
    obj, attr = call.args[0], call.args[1]
    test: ast.expr = ast.Call(
        func=ast.Name(id="hasattr", ctx=ast.Load()), args=[obj, attr], keywords=[]
    )
    if negate:
        test = ast.UnaryOp(op=ast.Not(), operand=test)
    label = "assertNotHasAttr" if negate else "assertHasAttr"
    return ast.Assert(test=test, msg=_msg_of(call, label, [obj, attr]))


def _regex_assert(call: ast.Call, negate: bool) -> ast.Assert:
    # assertRegex(text, pattern): CPython searches pattern IN text.
    _need_args(call, 2)
    text, pattern = call.args[0], call.args[1]
    test: ast.expr = ast.Call(
        func=ast.Attribute(value=ast.Name(id="_re", ctx=ast.Load()), attr="search", ctx=ast.Load()),
        args=[pattern, text],
        keywords=[],
    )
    if negate:
        test = ast.UnaryOp(op=ast.Not(), operand=test)
    label = "assertNotRegex" if negate else "assertRegex"
    return ast.Assert(test=test, msg=_msg_of(call, label, [text, pattern]))


def _count_equal_assert(call: ast.Call) -> ast.Assert:
    _need_args(call, 2)
    a, b = call.args[0], call.args[1]
    # sorted(a, key=repr) == sorted(b, key=repr): repr keys keep the compare
    # total for unorderable element types; no lambda so snippets stay trivial
    # for the guest VM.
    def _sorted(x: ast.expr) -> ast.expr:
        return ast.Call(
            func=ast.Name(id="sorted", ctx=ast.Load()),
            args=[x],
            keywords=[ast.keyword(arg="key", value=ast.Name(id="repr", ctx=ast.Load()))],
        )

    return ast.Assert(
        test=ast.Compare(
            left=_sorted(a), ops=[ast.Eq()], comparators=[_sorted(b)]
        ),
        msg=_msg_of(call, "assertCountEqual", [a, b]),
    )


def _need_args(call: ast.Call, n: int) -> None:
    if len(call.args) < n:
        raise Unsupported("too few operands")


_EQUALITY_ALIASES = {
    "assertEqual": ast.Eq,
    "assertEquals": ast.Eq,
    "assertNotEqual": ast.NotEq,
    "assertMultiLineEqual": ast.Eq,
    "assertListEqual": ast.Eq,
    "assertTupleEqual": ast.Eq,
    "assertDictEqual": ast.Eq,
    "assertSetEqual": ast.Eq,
    "assertFrozenSetEqual": ast.Eq,
}

_ORDER_ALIASES = {
    "assertLess": ast.Lt,
    "assertLessEqual": ast.LtE,
    "assertGreater": ast.Gt,
    "assertGreaterEqual": ast.GtE,
}


def rewrite_assert_stmt(stmt: ast.stmt) -> list[ast.stmt]:
    """Rewrite one statement; returns replacement statements.

    Raises Unsupported when there is no mechanical mapping.
    """
    if isinstance(stmt, ast.Assert):
        return [stmt]
    if isinstance(stmt, ast.Raise):
        # self.fail(...) -> raise AssertionError(...); any other raise is
        # already valid Python and passes through untouched.
        if isinstance(stmt.exc, ast.Call) and _call_name(stmt.exc.func) == "fail":
            msg = stmt.exc.args[0] if stmt.exc.args else ast.Constant(value="fail()")
            return [
                ast.Raise(exc=ast.Call(func=ast.Name(id="AssertionError", ctx=ast.Load()), args=[msg], keywords=[]), cause=None)
            ]
        return [stmt]
    if not isinstance(stmt, ast.Expr) or not isinstance(stmt.value, ast.Call):
        raise Unsupported(f"statement {type(stmt).__name__}")
    call = stmt.value
    fname = _call_name(call.func)
    if fname is None:
        raise Unsupported("non-self call statement")
    if fname == "fail":
        msg = call.args[0] if call.args else ast.Constant(value="fail()")
        return [
            ast.Raise(exc=ast.Call(func=ast.Name(id="AssertionError", ctx=ast.Load()), args=[msg], keywords=[]), cause=None)
        ]
    if fname in ("assertWarns", "assertWarnsRegex", "assertLogs", "assertNoLogs"):
        raise Unsupported(fname)
    if fname in ("assertRaises", "assertRaisesRegex"):
        return _rewrite_raises(call, regex=fname == "assertRaisesRegex")
    if fname in _EQUALITY_ALIASES:
        return [_binary_assert(call, fname, _EQUALITY_ALIASES[fname])]
    if fname in _ORDER_ALIASES:
        return [_binary_assert(call, fname, _ORDER_ALIASES[fname])]
    if fname == "assertTrue":
        return [_unary_assert(call, negate=False)]
    if fname == "assertFalse":
        return [_unary_assert(call, negate=True)]
    if fname == "assertIs":
        return [_binary_assert(call, fname, ast.Is)]
    if fname == "assertIsNot":
        return [_binary_assert(call, fname, ast.IsNot)]
    if fname == "assertIn":
        return [_binary_assert(call, fname, ast.In)]
    if fname == "assertNotIn":
        return [_binary_assert(call, fname, ast.NotIn)]
    if fname == "assertIsNone":
        return [_is_none_assert(call, negate=False)]
    if fname == "assertIsNotNone":
        return [_is_none_assert(call, True)]
    if fname == "assertIsInstance":
        return [_isinstance_assert(call, negate=False)]
    if fname == "assertIsNotInstance":
        return [_isinstance_assert(call, negate=True)]
    if fname == "assertAlmostEqual":
        return [_almost_assert(call, negate=False)]
    if fname == "assertNotAlmostEqual":
        return [_almost_assert(call, negate=True)]
    if fname == "assertCountEqual":
        return [_count_equal_assert(call)]
    if fname == "assertIsSubclass":
        return [_issubclass_assert(call)]
    if fname == "assertHasAttr":
        return [_hasattr_assert(call, negate=False)]
    if fname == "assertNotHasAttr":
        return [_hasattr_assert(call, negate=True)]
    if fname == "assertRegex":
        return [_regex_assert(call, negate=False)]
    if fname == "assertNotRegex":
        return [_regex_assert(call, negate=True)]
    raise Unsupported(f"self.{fname}")


def _is_none_assert(call: ast.Call, negate: bool) -> ast.Assert:
    _need_args(call, 1)
    x = call.args[0]
    test: ast.expr = ast.Compare(
        left=x, ops=[ast.Is() if not negate else ast.IsNot()],
        comparators=[ast.Constant(value=None)],
    )
    label = "assertIsNotNone" if negate else "assertIsNone"
    return ast.Assert(test=test, msg=_msg_of(call, label, [x]))


def _rewrite_raises(call: ast.Call, regex: bool) -> list[ast.stmt]:
    """Both forms: ``self.assertRaises(E, fn, *a)`` and (via caller for With)
    the context-manager form is handled separately in rewrite_with."""
    _need_args(call, 1)
    exc = call.args[0]
    handler = ast.ExceptHandler(
        type=exc, name=None, body=[ast.Pass()],
    )
    body: list[ast.stmt] = []
    if regex:
        _need_args(call, 2)
        pattern = call.args[1]
        body.append(
            ast.Assert(
                test=ast.Call(
                    func=ast.Attribute(
                        value=ast.Name(id="_re", ctx=ast.Load()),
                        attr="search", ctx=ast.Load(),
                    ),
                    args=[pattern, ast.Call(func=ast.Name(id="str", ctx=ast.Load()), args=[ast.Name(id="_exc", ctx=ast.Load())], keywords=[])],
                    keywords=[],
                ),
                msg=ast.Constant(value="assertRaisesRegex: message mismatch"),
            )
        )
    else_stmt: list[ast.stmt] = [
        ast.Raise(
            exc=ast.Call(
                func=ast.Name(id="AssertionError", ctx=ast.Load()),
                args=[ast.Constant(value="assertRaises: did not raise")],
                keywords=[],
            ),
            cause=None,
        )
    ]
    if len(call.args) >= (3 if regex else 2):
        # Call form: assertRaises(E, fn, *a) /
        # assertRaisesRegex(E, pattern, fn, *a). args[1] (or [2] for the
        # regex form) is the pattern; everything after it is callable + args.
        offset = 2 if regex else 1
        fn = call.args[offset]
        extra = list(call.args[offset + 1 :])
        starargs: list[ast.expr] = []
        if extra:
            starargs = [
                ast.Starred(value=ast.Tuple(elts=extra, ctx=ast.Load()), ctx=ast.Load())
            ]
        invoke: ast.expr = ast.Call(func=fn, args=starargs, keywords=list(call.keywords))
        tried: list[ast.stmt] = [ast.Expr(value=invoke)]
    else:
        if regex:
            raise Unsupported("assertRaisesRegex call form")
        raise Unsupported("context-manager form routed wrongly")
    return [
        ast.Try(
            body=tried,
            handlers=[handler],
            orelse=[],
            finalbody=[],
        )
    ]


def rewrite_raises_with(item: ast.withitem, body: list[ast.stmt]) -> ast.Try:
    """``with self.assertRaises(E[, regex]): <body>`` -> try/except/else."""
    call = item.context_expr
    fname = _call_name(call.func) if isinstance(call, ast.Call) else None
    if fname not in ("assertRaises", "assertRaisesRegex") or not isinstance(call, ast.Call):
        raise Unsupported("non-assertRaises with-block")
    _need_args(call, 1)
    exc = call.args[0]
    regex = None
    if fname == "assertRaisesRegex":
        _need_args(call, 2)
        regex = call.args[1]
    handler_body: list[ast.stmt] = []
    if regex is not None:
        handler_body.append(
            ast.Assert(
                test=ast.Call(
                    func=ast.Attribute(
                        value=ast.Name(id="_re", ctx=ast.Load()),
                        attr="search", ctx=ast.Load(),
                    ),
                    args=[regex, ast.Call(func=ast.Name(id="str", ctx=ast.Load()), args=[ast.Name(id="_exc", ctx=ast.Load())], keywords=[])],
                    keywords=[],
                ),
                msg=ast.Constant(value="assertRaisesRegex: message mismatch"),
            )
        )
    handler = ast.ExceptHandler(type=exc, name="_exc", body=handler_body or [ast.Pass()])
    return ast.Try(
        body=list(body),
        handlers=[handler],
        orelse=[
            ast.Raise(
                exc=ast.Call(
                    func=ast.Name(id="AssertionError", ctx=ast.Load()),
                    args=[ast.Constant(value="assertRaises: did not raise")],
                    keywords=[],
                ),
                cause=None,
            )
        ],
        finalbody=[],
    )


def _is_self_assert_stmt(stmt: ast.stmt) -> bool:
    """True when the statement is a unittest assertion needing rewrite."""
    if isinstance(stmt, (ast.Assert, ast.Raise)):
        return True
    return (
        isinstance(stmt, ast.Expr)
        and isinstance(stmt.value, ast.Call)
        and _call_name(stmt.value.func) is not None
    )


def rewrite_block(stmts: list[ast.stmt]) -> tuple[list[ast.stmt], bool]:
    """Recursively rewrite a statement list; returns (new stmts, needs_re)."""
    needs_re = False

    def rec(block: list[ast.stmt]) -> list[ast.stmt]:
        nonlocal needs_re
        new: list[ast.stmt] = []
        for stmt in block:
            if isinstance(stmt, (ast.If, ast.For, ast.AsyncFor, ast.While)):
                stmt.body = rec(stmt.body)
                stmt.orelse = rec(stmt.orelse)
                new.append(stmt)
            elif isinstance(stmt, (ast.Try, ast.TryStar)):
                stmt.body = rec(stmt.body)
                stmt.orelse = rec(stmt.orelse)
                stmt.finalbody = rec(stmt.finalbody)
                for handler in stmt.handlers:
                    handler.body = rec(handler.body)
                new.append(stmt)
            elif isinstance(stmt, ast.With):
                handled = False
                if len(stmt.items) == 1:
                    call = stmt.items[0].context_expr
                    if (
                        isinstance(call, ast.Call)
                        and _call_name(call.func) in ("assertRaises", "assertRaisesRegex")
                    ):
                        out_stmt = rewrite_raises_with(stmt.items[0], stmt.body)
                        needs_re = needs_re or _with_needs_re(stmt.items[0])
                        new.append(out_stmt)
                        handled = True
                    elif isinstance(call, ast.Call) and _call_name(call.func) == "subTest":
                        # unittest subTest scopes failure labels without stopping
                        # the test; any failing subtest makes the host oracle
                        # non-"ok", so such cases never become pins. Inlining the
                        # body plainly is therefore oracle-safe.
                        new.extend(rec(stmt.body))
                        handled = True
                if not handled:
                    stmt.body = rec(stmt.body)
                    new.append(stmt)
            else:
                if _is_self_assert_stmt(stmt):
                    new.extend(rewrite_assert_stmt(stmt))
                else:
                    # Plain statements (assignments, nested helper defs, ...)
                    # are already valid Python.
                    if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)):
                        stmt.body = rec(stmt.body)
                    new.append(stmt)
        return new

    new_block = rec(stmts)
    # Any emitted statement loading _re requires the module import. Scanning
    # the final AST (not per-rewrite flags) keeps every vocabulary addition
    # that may emit _re.search honest without plumbing a flag through each.
    for node in ast.walk(ast.Module(body=new_block, type_ignores=[])):
        if isinstance(node, ast.Name) and node.id == "_re" and isinstance(node.ctx, ast.Load):
            needs_re = True
            break
    return new_block, needs_re


def _with_needs_re(item: ast.withitem) -> bool:
    call = item.context_expr
    return isinstance(call, ast.Call) and _call_name(call.func) == "assertRaisesRegex"


# ---------------------------------------------------------------------------
# Name resolution checks


_BUILTIN_NAMES: set[str] = set(dir(builtins))
_EXTRA_ALLOWED = {
    "True", "False", "None", "__name__", "__class__", "self",
    "_re", "_exc", "AssertionError", "Exception", "BaseException",
}


def _bound_names(nodes: ast.AST) -> set[str]:
    out: set[str] = set()
    for node in ast.walk(nodes):
        if isinstance(node, ast.Name) and isinstance(node.ctx, (ast.Store, ast.Del)):
            out.add(node.id)
        elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            out.add(node.name)
        elif isinstance(node, ast.arg):
            out.add(node.arg)
        elif isinstance(node, ast.alias):
            out.add(node.asname or node.name.split(".")[0])
        elif isinstance(node, ast.excepthandler) and node.name:
            out.add(node.name)
    return out


def _loaded_names(nodes: ast.AST) -> set[str]:
    return {
        node.id
        for node in ast.walk(nodes)
        if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Load)
    }


def _self_attr_stores(body: list[ast.stmt]) -> set[str]:
    """Attribute names assigned via ``self.<attr> = ...`` anywhere in body."""
    out: set[str] = set()
    for node in ast.walk(ast.Module(body=body, type_ignores=[])):
        targets: list[ast.expr] = []
        if isinstance(node, ast.Assign):
            targets = node.targets
        elif isinstance(node, ast.AnnAssign):
            targets = [node.target]
        for t in targets:
            if isinstance(t, ast.Attribute) and isinstance(t.value, ast.Name) \
                    and t.value.id == "self":
                out.add(t.attr)
    return out


def _scan_self_usage(body: list[ast.stmt], namespace_callable: set[str] | None = None) -> tuple[set[str], set[str]]:
    """Partition ``self.*`` references into namespace-safe attrs vs calls.

    Returns (ns_attrs, call_attrs): ``ns_attrs`` are plain attribute
    loads/stores (``self.data``, ``self.data[i] = x``) that a bare namespace
    object bound to ``self`` satisfies at runtime; ``call_attrs`` are
    ``self.method(...)`` references that need helper-vocabulary lifting (the
    caller reports them unsupported when the rewriter left them behind).
    """
    tree = ast.Module(body=body, type_ignores=[])
    call_func_ids = {
        id(node.func)
        for node in ast.walk(tree)
        if isinstance(node, ast.Call)
        and isinstance(node.func, ast.Attribute)
        and isinstance(node.func.value, ast.Name)
        and node.func.value.id == "self"
    }
    ns_attrs: set[str] = set()
    call_attrs: set[str] = set()
    for node in ast.walk(tree):
        if (
            isinstance(node, ast.Attribute)
            and isinstance(node.value, ast.Name)
            and node.value.id == "self"
        ):
            if id(node) in call_func_ids:
                call_attrs.add(node.attr)
            else:
                ns_attrs.add(node.attr)
    return ns_attrs, call_attrs


_NS_PRELUDE_SRC = "class _SelfNS:\n    pass\nself = _SelfNS()\n"


def _namespace_prelude() -> list[ast.stmt]:
    """AST prelude binding ``self`` to a bare attribute namespace."""
    return ast.parse(_NS_PRELUDE_SRC).body


def _check_self_usage(body: list[ast.stmt], prefix: str = "") -> None:
    _, call_attrs = _scan_self_usage(body)
    if call_attrs:
        raise Unsupported(f"{prefix}uses-self.{sorted(call_attrs)[0]}")


def _check_names(body: list[ast.stmt], available: set[str]) -> None:
    local = _bound_names(ast.Module(body=body, type_ignores=[])) | available | _EXTRA_ALLOWED | _BUILTIN_NAMES
    for name in sorted(_loaded_names(ast.Module(body=body, type_ignores=[]))):
        if name not in local:
            raise Unsupported(f"unresolved-name:{name}")


_SKIP_DECOS = {
    "skip", "skipIf", "skipUnless", "expectedFailure",
    "skipUnlessDB", "requires",  # support.requires* caught below
}


def _decorator_reason(deco: ast.expr) -> str | None:
    name = None
    if isinstance(deco, ast.Name):
        name = deco.id
    elif isinstance(deco, ast.Attribute):
        base = deco.value.id if isinstance(deco.value, ast.Name) else ""
        if deco.attr in _SKIP_DECOS:
            return f"decorator:{base}.{deco.attr}" if base else f"decorator:{deco.attr}"
        if base == "support" or deco.attr.startswith("requires"):
            return f"decorator:{base}.{deco.attr}"
        return None
    elif isinstance(deco, ast.Call):
        return _decorator_reason(deco.func)
    if name and name in _SKIP_DECOS:
        return f"decorator:{name}"
    return None


# ---------------------------------------------------------------------------
# Fixture-vocabulary lifting (custom TestCase helper methods)
#
# Suites like test_htmlparser route every assertion through helpers defined
# on the TestCase hierarchy (``self._run_check(...)``). Those methods are
# mechanically liftable: drop the ``self`` parameter, rewrite nested
# ``self.helper(...)`` calls to plain calls, and reuse the standard
# assertion vocabulary inside the helper body. Anything a helper does that
# has no mechanical mapping (instance state, decorators, unresolved names)
# quarantines the *test* with the helper's precise reason instead of
# mistranslating.


@dataclass
class _ClassInfo:
    methods: dict[str, ast.FunctionDef]
    bases: list[str]


def _module_class_map(tree: ast.Module) -> dict[str, _ClassInfo]:
    cmap: dict[str, _ClassInfo] = {}
    for node in tree.body:
        if isinstance(node, ast.ClassDef):
            cmap[node.name] = _ClassInfo(
                methods={
                    m.name: m for m in node.body if isinstance(m, ast.FunctionDef)
                },
                bases=[b.id for b in node.bases if isinstance(b, ast.Name)],
            )
    return cmap


def _resolve_method(
    cmap: dict[str, _ClassInfo], cls_name: str | None, attr: str
) -> ast.FunctionDef | None:
    """attr on cls_name or its in-module bases (BFS); test methods excluded."""
    seen: set[str] = set()
    queue = [cls_name] if cls_name else []
    while queue:
        name = queue.pop(0)
        if name in seen:
            continue
        seen.add(name)
        info = cmap.get(name)
        if info is None:
            continue
        fn = info.methods.get(attr)
        if fn is not None and not attr.startswith("test"):
            return fn
        queue.extend(info.bases)
    return None


def _drop_self_arg(fn: ast.FunctionDef) -> ast.arguments:
    """Copy fn.args minus the leading ``self`` parameter."""
    a = fn.args
    posonly = list(a.posonlyargs)
    args = list(a.args)
    if posonly and posonly[0].arg == "self":
        posonly.pop(0)
    elif args and args[0].arg == "self":
        args.pop(0)
    else:
        raise Unsupported("missing-self-parameter")
    total_before = len(a.posonlyargs) + len(a.args)
    defaults = list(a.defaults)
    if len(defaults) == total_before:
        # self itself was defaulted; shift defaults with the parameter list
        defaults = defaults[1:]
    return ast.arguments(
        posonlyargs=posonly,
        args=args,
        vararg=a.vararg,
        kwonlyargs=list(a.kwonlyargs),
        kw_defaults=list(a.kw_defaults),
        kwarg=a.kwarg,
        defaults=defaults,
    )


class _HelperCallRewriter(ast.NodeTransformer):
    """``self.helper(...)`` -> ``helper(...)``, lifting helper transitively.

    self-attribute calls that do not resolve to an in-module method are left
    untouched so downstream checks report them with their usual reason.
    """

    def __init__(self, session: "_FixtureVocab") -> None:
        self.session = session

    def visit_Call(self, node: ast.Call) -> ast.AST:
        self.generic_visit(node)
        func = node.func
        if (
            isinstance(func, ast.Attribute)
            and isinstance(func.value, ast.Name)
            and func.value.id == "self"
            and _resolve_method(self.session.cmap, self.session.cls_name, func.attr)
            is not None
        ):
            self.session.ensure(func.attr)
            node.func = ast.Name(id=func.attr, ctx=ast.Load())
        return node


class _FixtureVocab:
    """Per-candidate lifting session for one test method's class."""

    def __init__(self, cls_name: str | None, cmap: dict[str, _ClassInfo],
                 available_names: set[str]) -> None:
        self.cls_name = cls_name
        self.cmap = cmap
        self.available_names = available_names
        self.lifted: list[ast.FunctionDef] = []  # insertion order
        self.needs_re = False
        self.needs_ns = False
        # self.<attr> names that resolve to callables at runtime (class-level
        # attribute seeds or setUp-assigned); calls through them are legal
        # once the namespace exists.
        self.allowed_calls: set[str] = set()
        self._ok: dict[str, ast.FunctionDef] = {}
        self._failed: dict[str, Unsupported] = {}

    def ensure(self, attr: str) -> ast.FunctionDef:
        if attr in self._ok:
            return self._ok[attr]
        if attr in self._failed:
            raise self._failed[attr]
        try:
            fn = _resolve_method(self.cmap, self.cls_name, attr)
            if fn is None:
                raise Unsupported("not-in-class-hierarchy")
            lifted, needs_re = self._lift(fn)
        except Unsupported as exc:
            wrapped = Unsupported(f"helper:{attr}({exc})")
            self._failed[attr] = wrapped
            raise wrapped from None
        self._ok[attr] = lifted
        self.lifted.append(lifted)
        self.needs_re = self.needs_re or needs_re
        return lifted

    def _lift(self, fn: ast.FunctionDef) -> tuple[ast.FunctionDef, bool]:
        # Deep-copy before transforming: helper methods are tree nodes shared
        # by every test candidate; in-place substitution would leak one
        # candidate's rewriting into the next candidate's lift.
        fn = copy.deepcopy(fn)
        if fn.decorator_list:
            raise Unsupported("decorated-helper")
        args = _drop_self_arg(fn)
        rewriter = _HelperCallRewriter(self)
        body = [rewriter.visit(stmt) for stmt in fn.body]
        body, needs_re = rewrite_block(body)
        ns_attrs, call_attrs = _scan_self_usage(body)
        bad = {a for a in call_attrs if a not in self.allowed_calls}
        if bad:
            raise Unsupported(f"uses-self.{sorted(bad)[0]}")
        if ns_attrs or (call_attrs and self.allowed_calls):
            self.needs_ns = True
        try:
            siblings = {f.name for f in self.lifted} | {
                f.name for f in self._ok.values()
            }
            params = {
                a.arg
                for group in (
                    args.posonlyargs, args.args, args.kwonlyargs,
                    ([args.vararg] if args.vararg else []),
                    ([args.kwarg] if args.kwarg else []),
                )
                for a in group
            }
            _check_names(body, self.available_names | siblings | params)
        except Unsupported as exc:
            raise Unsupported(str(exc)) from None
        return (
            ast.FunctionDef(
                name=fn.name,
                args=args,
                body=body,
                decorator_list=[],
                returns=None,
                type_params=[],
            ),
            needs_re,
        )


def _helper_class_deps(
    lifted: list[ast.FunctionDef], mod_classes: dict[str, ast.ClassDef]
) -> list[ast.stmt]:
    """Module classes referenced by lifted helpers, base classes first.

    Helper bodies construct fixture classes (EventCollector & co.); those
    must join the prune pool or name resolution would quarantine every
    helper-using test. Test bodies referencing classes directly keep the
    stricter pre-existing behavior (classes stay out of scope for them).
    """
    if not lifted:
        return []
    used: set[str] = set()
    for fn in lifted:
        used |= _loaded_names(ast.Module(body=[fn], type_ignores=[]))
    ordered: list[ast.ClassDef] = []
    placed: set[str] = set()
    pending = [c for c in mod_classes.values() if c.name in used]
    while pending:
        rest = []
        progressed = False
        for cnode in pending:
            deps = {
                b.id for b in cnode.bases if isinstance(b, ast.Name)
            } & set(mod_classes)
            if deps <= placed:
                ordered.append(cnode)
                placed.add(cnode.name)
                used |= _loaded_names(cnode)
                progressed = True
            else:
                rest.append(cnode)
        pending = [c for c in rest if c.name not in placed and c.name in used]
        if not progressed and pending:
            # cyclic or externally-unsatisfied bases; emit remaining as-is
            ordered.extend(pending)
            break
    return ordered


def _class_attr_seeds(
    cls_name: str | None, cmap: dict[str, _ClassInfo],
    mod_classes: dict[str, ast.ClassDef],
) -> list[tuple[str, ast.expr]]:
    """Class-level attribute assignments along the MRO, base-first.

    ``module = py_operator``-style attributes resolve via class attribute
    lookup in CPython; with a namespace ``self`` they must be seeded onto it.
    Later (sub)class assignments override earlier ones. Method names are not
    attributes here -- the helper vocabulary handles those separately.
    """
    if cls_name is None:
        return []
    chain: list[str] = []
    seen: set[str] = set()
    stack = [cls_name]
    while stack:
        name = stack.pop()
        if name in seen:
            continue
        seen.add(name)
        chain.append(name)
        info = cmap.get(name)
        if info is not None:
            stack.extend(reversed(info.bases))
    seeds: dict[str, ast.expr] = {}
    for name in chain:
        cd = mod_classes.get(name)
        if cd is None:
            continue
        for stmt in cd.body:
            if isinstance(stmt, ast.Assign) and len(stmt.targets) == 1 \
                    and isinstance(stmt.targets[0], ast.Name):
                seeds[stmt.targets[0].id] = stmt.value
            elif isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name) \
                    and stmt.value is not None:
                seeds[stmt.target.id] = stmt.value
    # Drop names that are methods on any class in the chain (a method always
    # wins over a same-named data attribute in the lookup that matters here,
    # and calling conventions differ).
    for name in chain:
        info = cmap.get(name)
        if info is not None:
            for meth in info.methods:
                seeds.pop(meth, None)
    return sorted(seeds.items())


def _apply_fixture_vocab(
    body: list[ast.stmt],
    cls_name: str,
    cmap: dict[str, _ClassInfo],
    mod_classes: dict[str, ast.ClassDef],
    available_names: set[str],
) -> tuple[list[ast.stmt], list[ast.stmt], list[ast.stmt], bool]:
    """Lift custom helper vocabulary for one test candidate.

    Returns (rewritten body, lifted helper defs, extra prelude statements,
    namespace seed assignments, needs_re).

    Lifted helpers are returned separately (not folded into the prelude
    pool): they are emitted *inside* the wrapped snippet body so any ``self``
    reference in a helper resolves through the namespace closure instead of
    raising NameError at module scope.
    """
    session = _FixtureVocab(cls_name, cmap, available_names)
    # self.<attr> callables: class-attr seeds plus anything any method of the
    # class chain (ancestors and descendants) stores onto self (setUp and
    # friends). Calls through these resolve at runtime once the namespace
    # exists.
    related: list[str] = []
    seen_cls = {cls_name}
    stack = [cls_name]
    while stack:
        name = stack.pop()
        related.append(name)
        info = cmap.get(name)
        if info is not None:
            for b in info.bases:
                if b not in seen_cls:
                    seen_cls.add(b)
                    stack.append(b)
            for child in cmap:
                if cls_name in cmap[child].bases or name in cmap[child].bases:
                    if child not in seen_cls:
                        seen_cls.add(child)
                        stack.append(child)
    for name in related:
        info = cmap.get(name)
        if info is None:
            continue
        for meth in info.methods.values():
            session.allowed_calls |= _self_attr_stores(meth.body)
    session.allowed_calls |= set(_class_attr_seeds(cls_name, cmap, mod_classes))
    prefix: list[ast.stmt] = []
    if _resolve_method(cmap, cls_name, "setUp") is not None:
        # unittest runs setUp before every test; splice its lifted body so
        # locals it binds become locals of the test. A setUp that cannot be
        # lifted cleanly fails the whole test via ensure()'s reason.
        prefix = list(session.ensure("setUp").body)
        prefix = [copy.deepcopy(s) for s in prefix]
    rewriter = _HelperCallRewriter(session)
    stmts = [rewriter.visit(s) for s in prefix + list(body)]
    rewritten, needs_re = rewrite_block(stmts)
    # Scan lifted helper bodies together with the test body: a helper's
    # ``self.<attr>`` load/store has the same runtime fate as one written
    # inline in the test.
    scanned = [*session.lifted, *rewritten]
    ns_attrs, call_attrs = _scan_self_usage(scanned)
    bad = {a for a in call_attrs if a not in session.allowed_calls}
    if bad:
        raise Unsupported(f"uses-self.{sorted(bad)[0]}")
    # Namespace loads must be satisfiable at runtime: class-level seeds plus
    # stores that actually execute inside the snippet (spliced setUp, test
    # body, lifted helpers). Stores confined to unlifted methods (__init__
    # and friends) never run, so a load of such an attr would only die as an
    # opaque AttributeError during oracle capture -- quarantine it precisely
    # instead.
    executed_stores = _self_attr_stores(scanned)
    seed_attrs = {attr for attr, _ in _class_attr_seeds(cls_name, cmap, mod_classes)}
    unseeded = ns_attrs - seed_attrs - executed_stores
    if unseeded:
        raise Unsupported(f"uses-self.{sorted(unseeded)[0]}")
    helper_defs = list(session.lifted)
    extra_prelude = _helper_class_deps(session.lifted, mod_classes)
    ns_block: list[ast.stmt] = []
    if bool(ns_attrs) or session.needs_ns:
        ns_block = _namespace_prelude()
        for attr, value in _class_attr_seeds(cls_name, cmap, mod_classes):
            assign = ast.Assign(
                targets=[ast.Attribute(value=ast.Name(id="self", ctx=ast.Load()),
                                       attr=attr, ctx=ast.Store())],
                value=copy.deepcopy(value),
            )
            ast.fix_missing_locations(assign)
            ns_block.append(assign)
    return rewritten, helper_defs, extra_prelude, ns_block, needs_re or session.needs_re


# ---------------------------------------------------------------------------
# Extraction


def _src(node: ast.AST, source: str) -> str:
    seg = ast.get_source_segment(source, node)
    return seg or ast.unparse(node)


def collect_prelude(tree: ast.Module, source: str, include_classes: bool = False) -> tuple[list[ast.stmt], set[str]]:
    """Module-level imports/assigns/function defs/classes usable as prelude.

    Everything enters the same prunable pool: ``_prune_prelude`` keeps only
    items whose bindings the test body (transitively) references, so a
    module-level helper class lands in a snippet only when the body actually
    names it -- previously such references quarantined as
    ``unresolved-name:<Class>``.
    """
    stmts: list[ast.stmt] = []
    names: set[str] = set()
    for node in tree.body:
        if isinstance(node, (ast.Import, ast.ImportFrom, ast.Assign, ast.AnnAssign,
                             ast.FunctionDef)):
            stmts.append(node)
            names |= _bound_names(node)
        elif include_classes and isinstance(node, ast.ClassDef):
            stmts.append(node)
            names.add(node.name)
    return stmts, names


def _prelude_bindings(item: ast.stmt) -> set[str]:
    """Names a prelude item binds; classes bind exactly their own name
    (_bound_names would also pull in method/arg names, wrongly matching
    unrelated bodies during pruning)."""
    if isinstance(item, ast.ClassDef):
        return {item.name}
    return _bound_names(item)


def _prune_prelude(
    body: list[ast.stmt], prelude: list[ast.stmt], prelude_names: set[str]
) -> list[ast.stmt]:
    """Fixpoint: keep only prelude items whose bindings the body (+ kept
    items transitively) reference."""
    used = set(_loaded_names(ast.Module(body=body, type_ignores=[])))
    kept: dict[int, ast.stmt] = {}
    changed = True
    while changed:
        changed = False
        for idx, item in enumerate(prelude):
            if idx in kept:
                continue
            binds = _prelude_bindings(item)
            if binds & used:
                kept[idx] = item
                new_used = _loaded_names(item)
                if not new_used <= used:
                    used |= new_used
                    changed = True
    return [kept[i] for i in sorted(kept)]


def extract_tests(tree: ast.Module, source: str) -> Extraction:
    result = Extraction()
    prelude, prelude_names = collect_prelude(tree, source, include_classes=True)
    cmap = _module_class_map(tree)
    mod_classes = {
        node.name: node for node in tree.body if isinstance(node, ast.ClassDef)
    }
    # Lifted helper bodies may reference module-level fixture classes; those
    # are materialized into the snippet pool afterwards (_helper_class_deps).
    vocab_available = prelude_names | set(mod_classes)

    candidates: list[tuple[str | None, str, list[ast.stmt]]] = []
    for node in tree.body:
        if isinstance(node, ast.ClassDef):
            class_reason = None
            for deco in node.decorator_list:
                reason = _decorator_reason(deco)
                if reason:
                    class_reason = reason
            for member in node.body:
                if not isinstance(member, ast.FunctionDef) or not member.name.startswith("test"):
                    continue
                ident = f"{node.name}.{member.name}"
                reason = class_reason
                if reason is None:
                    for deco in member.decorator_list:
                        reason = _decorator_reason(deco)
                        if reason:
                            break
                if reason is not None:
                    result.quarantined.append(Quarantined(ident, reason))
                    continue
                candidates.append((node.name, ident, list(member.body)))
        elif isinstance(node, ast.FunctionDef) and node.name.startswith("test"):
            for deco in node.decorator_list:
                reason = _decorator_reason(deco)
                if reason:
                    result.quarantined.append(Quarantined(node.name, reason))
                    break
            else:
                candidates.append((None, node.name, list(node.body)))

    # Concrete-subclass variant expansion: a test-bearing base class whose
    # subclasses carry distinct class attributes (``module = py_operator`` vs
    # ``c_operator``) runs once per concrete leaf in CPython, each seeing its
    # own attribute values through the MRO. Expand such candidates per leaf;
    # classes without in-module descendants keep their single candidate.
    children: dict[str, list[str]] = {}
    for cname, info in cmap.items():
        for b in info.bases:
            children.setdefault(b, []).append(cname)

    def _leaves(name: str) -> list[str]:
        kids = children.get(name, [])
        if not kids:
            return [name]
        out: list[str] = []
        for k in kids:
            out.extend(_leaves(k))
        return out

    expanded: list[tuple[str | None, str, list[ast.stmt]]] = []
    for cls_name, ident, body_stmts in candidates:
        if cls_name is not None and children.get(cls_name):
            for leaf in _leaves(cls_name):
                expanded.append(
                    (leaf, f"{leaf}.{ident.split('.', 1)[1]}", body_stmts)
                )
        else:
            expanded.append((cls_name, ident, body_stmts))
    candidates = expanded

    for cls_name, ident, body_stmts in candidates:
        try:
            extra_prelude: list[ast.stmt] = []
            ns_block: list[ast.stmt] = []
            helper_defs: list[ast.FunctionDef] = []
            if cls_name is not None:
                rewritten, helper_defs, extra_prelude, ns_block, needs_re = _apply_fixture_vocab(
                    body_stmts, cls_name, cmap, mod_classes, vocab_available
                )
            else:
                rewritten, needs_re = rewrite_block(body_stmts)
                # Module-level test functions have no self binding; keep the
                # strict sweep there (any self.* reference is unsupported).
                _check_self_usage(rewritten)
            if ns_block:
                rewritten = ns_block + rewritten
            # Lifted helpers nest inside the wrapped body so their ``self``
            # references resolve through the namespace closure.
            candidate = [*helper_defs, *rewritten]
            pool = prelude + extra_prelude
            pool_names = prelude_names | {
                binding
                for item in extra_prelude
                for binding in _prelude_bindings(item)
            }
            kept_prelude = _prune_prelude(candidate, pool, pool_names)
            available = pool_names | _bound_names(ast.Module(body=kept_prelude, type_ignores=[]))
            _check_names(candidate, available)
        except Unsupported as exc:
            result.quarantined.append(Quarantined(ident, str(exc)))
            continue
        snippet = render_snippet(candidate, kept_prelude, needs_re)
        result.pinned.append(Pinned(ident, snippet, oracle={}))

    # self.skipTest anywhere in candidate bodies -> quarantine (checked after
    # the general self.* sweep would already have flagged it, but keep the
    # explicit reason for readability).
    for pin in list(result.pinned):
        if "skipTest" in pin.snippet:
            result.pinned.remove(pin)
            result.quarantined.append(Quarantined(pin.ident, "self.skipTest"))
    return result


# ---------------------------------------------------------------------------
# Module-level doctest extraction (test_genexps-style files)


def _eval_str_value(value: ast.expr, modname: str) -> str | None:
    """Statically evaluate a module-level string expression.

    Handles plain constants and the ``"..." % {'modname': __name__}``
    interpolation idiom (test_descrtut). ``__name__`` is substituted with
    *modname*, which must equal the ``__name__`` both the host oracle and
    the guest harness exec snippets under ("__main__").
    """
    try:
        val = ast.literal_eval(value)
    except (ValueError, SyntaxError, TypeError, MemoryError):
        if (
            isinstance(value, ast.BinOp)
            and isinstance(value.op, ast.Mod)
            and isinstance(value.left, ast.Constant)
            and isinstance(value.left.value, str)
        ):
            right: dict[str, object] = {}
            dict_node = value.right
            if not isinstance(dict_node, ast.Dict):
                return None
            ok = True
            for k, v in zip(dict_node.keys, dict_node.values):
                if k is None or not isinstance(k, ast.Constant):
                    ok = False
                    break
                if isinstance(v, ast.Name) and v.id == "__name__":
                    right[k.value] = modname
                    continue
                try:
                    right[k.value] = ast.literal_eval(v)
                except (ValueError, SyntaxError, TypeError, MemoryError):
                    ok = False
                    break
            if not ok:
                return None
            try:
                val = value.left.value % right
            except (TypeError, ValueError, KeyError):
                return None
        else:
            return None
    return val if isinstance(val, str) else None


def collect_doctest_sources(tree: ast.Module, modname: str) -> list[tuple[str, str]]:
    """Find module-level doctest texts: ``doctests = "..."`` registered via
    ``__test__`` (dict of label -> string/name), falling back to any
    module-level string constant named ``doctests`` containing examples."""
    strings: dict[str, str] = {}
    test_map: dict | None = None
    for node in tree.body:
        target_name = None
        value = None
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            target_name, value = node.targets[0].id, node.value
        elif isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name) and node.value is not None:
            target_name, value = node.target.id, node.value
        if target_name is None:
            continue
        if target_name == "__test__":
            if isinstance(value, ast.Dict):
                test_map = {
                    k.value: v
                    for k, v in zip(value.keys, value.values)
                    if isinstance(k, ast.Constant)
                }
            continue
        text = _eval_str_value(value, modname)
        if text is not None and ">>>" in text:
            strings[target_name] = text

    sources: list[tuple[str, str]] = []
    if test_map is not None:
        for label, ref in test_map.items():
            if isinstance(ref, ast.Constant) and isinstance(ref.value, str):
                if ">>>" in ref.value:
                    sources.append((str(label), ref.value))
            elif isinstance(ref, ast.Name) and ref.id in strings:
                sources.append((str(label), strings[ref.id]))
    if not sources and "doctests" in strings:
        sources.append(("doctests", strings["doctests"]))
    return sources


class _PrintRenamer(ast.NodeTransformer):
    """Route print output into the snippet-local capture buffer.

    Renames ``print(...)`` calls AND bare ``print`` loads (e.g. the
    ``a['print'] = print`` idiom before ``exec(..., a)``) to ``_d_print``,
    since the ambient print is overridden by the guest harness with its own
    capture and would otherwise bypass the buffer on one side only.
    """

    def visit_Call(self, node: ast.Call) -> ast.AST:
        self.generic_visit(node)
        if isinstance(node.func, ast.Name) and node.func.id == "print":
            node.func = ast.Name(id="_d_print", ctx=ast.Load())
        return node

    def visit_Name(self, node: ast.Name) -> ast.AST:
        if node.id == "print" and isinstance(node.ctx, ast.Load):
            return ast.Name(id="_d_print", ctx=ast.Load())
        return node


def _norm_want(want: str) -> str:
    lines = [ln.rstrip() for ln in want.splitlines()]
    while lines and not lines[-1]:
        lines.pop()
    while lines and not lines[0]:
        lines.pop(0)
    lines = ["" if ln.strip() == "<BLANKLINE>" else ln for ln in lines]
    return "\n".join(lines)


_DOCTEST_HELPERS = """\
_d_buf = []
def _d_print(*args, sep=' '):
    _d_buf.append(sep.join(str(a) for a in args))
def _d_clear():
    _d_buf.clear()
def _d_ell_match(want, got):
    parts = want.split('...')
    if len(parts) == 1:
        return want == got
    if not got.startswith(parts[0]) or not got.endswith(parts[-1]):
        return False
    pos = len(parts[0])
    end = len(got) - len(parts[-1])
    for seg in parts[1:-1]:
        idx = got.find(seg, pos)
        if idx < 0 or idx > end:
            return False
        pos = idx + len(seg)
    return True
def _d_check(idx, want, ell=False):
    got = chr(10).join(_d_buf)
    ok = _d_ell_match(want, got) if ell else got == want
    if not ok and want in ('0', '1'):
        # doctest OutputChecker accepts False for 0 and True for 1.
        ok = got == ('False' if want == '0' else 'True')
    assert ok, ('doctest', idx, got, want)
"""


def _exc_ident(exc_msg: str) -> str | None:
    head = exc_msg.partition(":")[0].strip()
    parts = head.split(".")
    if parts and all(p.isidentifier() for p in parts):
        return head
    return None


def _example_stmts(idx: int, example: doctest.Example, stem: str) -> tuple[list[ast.stmt], str | None]:
    """Render one doctest example as snippet statements.

    Returns (statements, quarantine_reason). quarantine_reason is None when
    the example translated cleanly.
    """
    # Expected outputs hardcoding the real module path (e.g. "TypeError:
    # test.test_unpack_ex.f() ..." or reprs like <class 'test.metaclass.B'>)
    # can never match a standalone snippet; quarantine rather than pin a
    # false failure.
    for probe in (example.want, example.exc_msg or ""):
        if f"test_{stem}" in probe or f"test.{stem}" in probe:
            return [], "doctest-module-qualified-expected"
    opts = set(example.options)
    if opts - {doctest.ELLIPSIS} or (opts and example.options.get(doctest.ELLIPSIS) is not True):
        return [], f"doctest-options:{sorted(example.options)}"
    use_ell = doctest.ELLIPSIS in opts
    try:
        # compile() is authoritative: ast.parse accepts constructs real
        # compilation rejects (multiple starred targets, repeated kwargs).
        compile(example.source, "<doctest>", "exec")
    except SyntaxError:
        # Compile-time-invalid source (e.g. pep646 syntax errors): run it
        # through exec() and assert the SyntaxError surfaces.
        src_lit = ast.Constant(value=example.source)
        return [
            ast.Try(
                body=[ast.Expr(value=ast.Call(func=ast.Name(id="exec", ctx=ast.Load()), args=[src_lit], keywords=[])),
                      ast.Raise(exc=ast.Call(func=ast.Name(id="AssertionError", ctx=ast.Load()),
                                             args=[ast.Constant(value=f"ex{idx}: expected SyntaxError")], keywords=[]), cause=None)],
                handlers=[ast.ExceptHandler(type=ast.Name(id="SyntaxError", ctx=ast.Load()), name=None, body=[ast.Pass()])],
                orelse=[], finalbody=[],
            )
        ], None

    parsed = ast.parse(example.source)

    if example.exc_msg is not None:
        exc_name = _exc_ident(example.exc_msg)
        if exc_name is None:
            return [], f"doctest-exc-msg:{example.exc_msg[:60]}"
        expected = _norm_want(example.exc_msg)
        renamer = _PrintRenamer()
        body = [renamer.visit(stmt) for stmt in parsed.body]
        msg_expr: ast.expr = ast.Call(func=ast.Name(id="str", ctx=ast.Load()), args=[ast.Name(id="_d_e", ctx=ast.Load())], keywords=[])
        # str(SyntaxError) appends file/line info that doctest's
        # format_exception_only strips; e.msg is the bare message.
        msg_expr = ast.IfExp(
            test=ast.Call(
                func=ast.Name(id="isinstance", ctx=ast.Load()),
                args=[ast.Name(id="_d_e", ctx=ast.Load()), ast.Name(id="SyntaxError", ctx=ast.Load())],
                keywords=[],
            ),
            body=ast.Attribute(value=ast.Name(id="_d_e", ctx=ast.Load()), attr="msg", ctx=ast.Load()),
            orelse=msg_expr,
        )
        got_exc = ast.BinOp(
            left=ast.Attribute(
                value=ast.Call(func=ast.Name(id="type", ctx=ast.Load()), args=[ast.Name(id="_d_e", ctx=ast.Load())], keywords=[]),
                attr="__name__", ctx=ast.Load(),
            ),
            op=ast.Add(),
            right=ast.IfExp(
                test=ast.Compare(
                    left=msg_expr,
                    ops=[ast.NotEq()],
                    comparators=[ast.Constant(value="")],
                ),
                body=ast.BinOp(left=ast.Constant(value=": "), op=ast.Add(), right=msg_expr),
                orelse=ast.Constant(value=""),
            ),
        )
        if "..." in expected:
            check_test: ast.expr = ast.Call(
                func=ast.Name(id="_d_ell_match", ctx=ast.Load()),
                args=[ast.Constant(value=expected), got_exc], keywords=[],
            )
        else:
            check_test = ast.Compare(left=got_exc, ops=[ast.Eq()], comparators=[ast.Constant(value=expected)])
        return [
            ast.Try(
                body=[ast.Expr(value=ast.Call(func=ast.Name(id="_d_clear", ctx=ast.Load()), args=[], keywords=[])), *list(body)],
                handlers=[ast.ExceptHandler(type=_name_or_attr(exc_name), name="_d_e", body=[ast.Assert(test=check_test, msg=ast.Tuple(elts=[ast.Constant(value=f"doctest-exc{idx}"), ast.Name(id="_d_e", ctx=ast.Load())], ctx=ast.Load()))])],
                orelse=[ast.Raise(exc=ast.Call(func=ast.Name(id="AssertionError", ctx=ast.Load()),
                                               args=[ast.Constant(value=f"ex{idx}: expected {exc_name}")], keywords=[]), cause=None)],
                finalbody=[],
            )
        ], None

    # Output example: reset buffer. Every top-level expression statement
    # appends repr(result), mirroring compile(..., "single") displayhook
    # semantics for multi-statement sources like ``A[*b] = 1; A``.
    renamer = _PrintRenamer()
    want = _norm_want(example.want)
    clear = ast.Expr(value=ast.Call(func=ast.Name(id="_d_clear", ctx=ast.Load()), args=[], keywords=[]))
    out: list[ast.stmt] = [clear]
    if is_expr := (len(parsed.body) == 1 and isinstance(parsed.body[0], ast.Expr)):
        out.append(ast.Assign(
            targets=[ast.Name(id="_d_r", ctx=ast.Store())],
            value=renamer.visit(parsed.body[0].value),
        ))
    else:
        for stmt in parsed.body:
            if isinstance(stmt, ast.Expr):
                out.append(ast.Assign(
                    targets=[ast.Name(id="_d_r", ctx=ast.Store())],
                    value=renamer.visit(stmt.value),
                ))
                out.append(_d_flush_stmt())
            else:
                out.append(renamer.visit(stmt))
    if is_expr and want:
        out.append(_d_flush_stmt())
    if want:
        out.append(ast.Expr(value=ast.Call(
            func=ast.Name(id="_d_check", ctx=ast.Load()),
            args=[ast.Constant(value=idx), ast.Constant(value=want)],
            keywords=[ast.keyword(arg="ell", value=ast.Constant(value=True))] if use_ell else [],
        )))
    return out, None


def _d_flush_stmt() -> ast.stmt:
    """Emit ``if _d_r is not None: _d_buf.append(repr(_d_r))`` (displayhook)."""
    return ast.If(
        test=ast.Compare(
            left=ast.Name(id="_d_r", ctx=ast.Load()),
            ops=[ast.IsNot()],
            comparators=[ast.Constant(value=None)],
        ),
        body=[ast.Expr(value=ast.Call(
            func=ast.Attribute(value=ast.Name(id="_d_buf", ctx=ast.Load()), attr="append", ctx=ast.Load()),
            args=[ast.Call(func=ast.Name(id="repr", ctx=ast.Load()), args=[ast.Name(id="_d_r", ctx=ast.Load())], keywords=[])],
            keywords=[],
        ))],
        orelse=[],
    )


def _name_or_attr(dotted: str) -> ast.expr:
    parts = dotted.split(".")
    node: ast.expr = ast.Name(id=parts[0], ctx=ast.Load())
    for part in parts[1:]:
        node = ast.Attribute(value=node, attr=part, ctx=ast.Load())
    return node


def extract_module_doctests(tree: ast.Module, source: str, modname: str, stem: str) -> Extraction:
    """Convert module-level doctest strings into runnable pins.

    One pin per labeled docstring (preserves doctest's shared-namespace
    execution order); each example becomes an inline buffer/compare block.
    Module-level prelude (imports/classes/functions) is pruned to what the
    examples reference, mirroring the unittest-method path.
    """
    result = Extraction()
    sources = collect_doctest_sources(tree, modname)
    if not sources:
        return result
    parser = doctest.DocTestParser()
    all_bodies: dict[str, list[ast.stmt]] = {}
    for label, text in sources:
        ident = f"{stem}.doctests:{label}"
        examples = parser.get_examples(text)
        if not examples:
            result.quarantined.append(Quarantined(ident, "doctest-no-examples"))
            continue
        helper_stmts = ast.parse(_DOCTEST_HELPERS).body
        body: list[ast.stmt] = list(helper_stmts)
        dropped_bindings: set[str] = set()
        for i, example in enumerate(examples):
            stmts, reason = _example_stmts(i, example, stem)
            try:
                ex_tree = ast.parse(example.source)
            except SyntaxError:
                ex_tree = ast.Module(body=[], type_ignores=[])
            loads = _loaded_names(ex_tree)
            if reason is None and loads & dropped_bindings:
                # A definition this example relies on was dropped; running it
                # would produce a false failure (or mask one).
                reason = f"doctest-depends-on-dropped:{sorted(loads & dropped_bindings)[:4]}"
            if reason is not None:
                # Drop only the offending example; keep the rest of the
                # docstring runnable. Account for it as a per-example
                # quarantine entry.
                result.quarantined.append(Quarantined(f"{ident}.ex{i}", reason))
                dropped_bindings |= _bound_names(ex_tree)
                continue
            body.extend(stmts)
        all_bodies[ident] = body
    if not all_bodies:
        return result
    prelude, prelude_names = collect_prelude(tree, source, include_classes=True)
    # Fixpoint closure over everything the examples reference, including
    # prelude-to-prelude deps (e.g. `tool = Tool()` needs class Tool).
    kept_prelude = _prune_prelude(
        [s for b in all_bodies.values() for s in b], prelude, prelude_names
    )
    for label, text in sources:
        ident = f"{stem}.doctests:{label}"
        body = all_bodies.get(ident)
        if body is None:
            continue
        snippet = render_snippet(body, kept_prelude, needs_re=False, wrap=False)
        result.pinned.append(Pinned(ident, snippet, {}))
    return result


# ---------------------------------------------------------------------------
# Snippet rendering


def _concat_expr(parts: list[ast.expr]) -> ast.expr:
    """left-to-right string concatenation expression."""
    out = parts[0]
    for part in parts[1:]:
        out = ast.BinOp(left=out, op=ast.Add(), right=part)
    return out


def render_snippet(
    body: list[ast.stmt], prelude: list[ast.stmt], needs_re: bool, wrap: bool = True
) -> str:
    module = ast.Module(body=[], type_ignores=[])
    stmts: list[ast.stmt] = []
    if needs_re:
        stmts.append(ast.Import(names=[ast.alias(name="re as _re", asname=None)]))
    stmts.extend(prelude)
    if not wrap:
        # Doctest pins run at module level: classes/examples must get
        # module-level __qualname__ (doctest execs at globals scope) and
        # repr(class) like "<class '__main__.C'>" must match the oracle.
        stmts.extend(body)
        # Any failure raises and aborts the process (harness reports it);
        # reaching this line means every check passed.
        stmts.append(ast.Expr(value=ast.Call(func=ast.Name(id="print", ctx=ast.Load()), args=[ast.Constant(value=_ORACLE_OK)], keywords=[])))
        module.body = stmts
        ast.fix_missing_locations(module)
        return textwrap.dedent(ast.unparse(module)) + "\n"
    stmts.append(
        ast.FunctionDef(
            name="_t",
            args=ast.arguments(
                posonlyargs=[], args=[], vararg=None, kwonlyargs=[],
                kw_defaults=[], kwarg=None, defaults=[],
            ),
            body=body,
            decorator_list=[],
            returns=None,
            type_params=[],
        )
    )
    stmts.append(
        ast.Try(
            body=[ast.Expr(value=ast.Call(func=ast.Name(id="_t", ctx=ast.Load()), args=[], keywords=[]))],
            handlers=[
                ast.ExceptHandler(
                    type=ast.Name(id="BaseException", ctx=ast.Load()),
                    name="_e",
                    body=[
                        ast.Expr(
                            value=ast.Call(
                                func=ast.Name(id="print", ctx=ast.Load()),
                                args=[
                                    _concat_expr([
                                        ast.Constant(value=_ORACLE_EXC),
                                        ast.Attribute(
                                            value=ast.Call(
                                                func=ast.Name(id="type", ctx=ast.Load()),
                                                args=[ast.Name(id="_e", ctx=ast.Load())],
                                                keywords=[],
                                            ),
                                            attr="__name__",
                                            ctx=ast.Load(),
                                        ),
                                        ast.Constant(value=" "),
                                        ast.Call(
                                            func=ast.Name(id="repr", ctx=ast.Load()),
                                            args=[
                                                ast.Call(
                                                    func=ast.Name(id="str", ctx=ast.Load()),
                                                    args=[ast.Name(id="_e", ctx=ast.Load())],
                                                    keywords=[],
                                                )
                                            ],
                                            keywords=[],
                                        ),
                                    ])
                                ],
                                keywords=[],
                            )
                        )
                    ],
                )
            ],
            orelse=[ast.Expr(value=ast.Call(func=ast.Name(id="print", ctx=ast.Load()), args=[ast.Constant(value=_ORACLE_OK)], keywords=[]))],
            finalbody=[],
        )
    )
    module.body = stmts
    ast.fix_missing_locations(module)
    text = ast.unparse(module)
    return textwrap.dedent(text) + "\n"


# ---------------------------------------------------------------------------
# Host oracle capture


def capture_host_oracle(snippet: str, cpython_lib: Path) -> dict:
    """Run one snippet under host CPython in a sandboxed subprocess."""
    with tempfile.TemporaryDirectory(prefix="conv_suite_") as td:
        tdp = Path(td)
        script = tdp / "oracle_snippet.py"
        script.write_text(snippet, encoding="utf-8")
        env = {
            "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
            "HOME": str(tdp),
            "PYTHONPATH": str(cpython_lib),
            "PYTHONDONTWRITEBYTECODE": "1",
        }
        try:
            proc = subprocess.run(
                [sys.executable, str(script)],
                cwd=str(tdp),
                env=env,
                capture_output=True,
                text=True,
                timeout=HOST_TIMEOUT,
            )
        except subprocess.TimeoutExpired:
            return {"status": "timeout"}
        lines = [ln for ln in proc.stdout.splitlines() if ln.strip()]
        if lines and lines[-1].startswith(_ORACLE_OK):
            return {"status": "ok"}
        if lines and lines[-1].startswith(_ORACLE_EXC):
            payload = lines[-1][len(_ORACLE_EXC):]
            exc_type, _, literal = payload.partition(" ")
            try:
                msg = ast.literal_eval(literal)
            except (ValueError, SyntaxError):
                msg = literal
            return {"status": "raised", "exc_type": exc_type, "exc_msg": msg}
        tail = (proc.stderr or proc.stdout or "").strip().splitlines()
        return {
            "status": "error",
            "detail": tail[-1][:200] if tail else f"exit {proc.returncode}",
        }


# ---------------------------------------------------------------------------
# Pin + manifest emission


def _jac_string(text: str) -> str:
    """Escape a Python snippet as a Jac-compatible string literal.

    JSON escapes (\\n, \\", \\\\, \\uXXXX) are accepted by the Jac lexer.
    """
    return json.dumps(text, ensure_ascii=True)


_PIN_HEADER = '''\
# Generated by jac-py/tools/convert_suite.py — DO NOT EDIT BY HAND.
# Output-oracle pins: every snippet replays its CPython Lib/test method on
# jacpython's ceval via layer_p2_libtest and asserts the host-captured
# outcome (host oracle captured at generation time).
import from layer_p2_libtest {{ p2_libtest_run_snippet }}
'''


def emit_pin_file(pins: list[Pinned], source_file: Path) -> str:
    out = [_PIN_HEADER.format(), ""]
    out.append(f'# Source: {source_file.name}\n')
    for pin in pins:
        lit = _jac_string(pin.snippet)
        out.append(f'test "{pin.ident}" {{')
        out.append(f"    (ok, detail) = p2_libtest_run_snippet({lit});")
        out.append('    assert ok , "RUN<" + detail + ">";')
        out.append('    assert detail == "ok" , "GOT<" + detail + ">";')
        out.append("}\n")
    return "\n".join(out)


def write_manifest_entry(stem: str, outdir: Path, pins_file: str, total: int) -> Path:
    doc: dict = {}
    if _MANIFEST.is_file():
        doc = json.loads(_MANIFEST.read_text(encoding="utf-8"))
    else:
        doc = {
            "version": 1,
            "wave": "conv_pipeline",
            "description": "D2 mechanical test-conversion pipeline (convert_suite/diff_runner)",
            "module_count": 0,
            "modules": [],
        }
    rel_pins = str(Path(outdir.relative_to(_REPO)) / pins_file) if outdir.is_relative_to(_REPO) else pins_file
    row = {
        "stem": stem,
        "gate_type": "oracle",
        "status": "converted",
        "oracle_tests": [rel_pins],
        "libtest_snippets": [],
        "notes": f"{total} output-oracle pins generated from CPython Lib/test; run diff_runner to gate.",
        "conversion_meta": str(Path(outdir.relative_to(_REPO)) / f"{stem}.conv.json")
        if outdir.is_relative_to(_REPO)
        else f"{stem}.conv.json",
    }
    for i, existing in enumerate(doc["modules"]):
        if existing.get("stem") == stem:
            doc["modules"][i] = row
            break
    else:
        doc["modules"].append(row)
    doc["module_count"] = len(doc["modules"])
    _MANIFEST.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
    return _MANIFEST


# ---------------------------------------------------------------------------


def run_conversion(source: Path, outdir: Path, name: str, cpython_lib: Path, write_manifest: bool) -> dict:
    command = ["convert_suite.py", str(source), "-o", str(outdir), "--name", name]
    header = attempt_header(command)
    source_text = source.read_text(encoding="utf-8")
    tree = ast.parse(source_text)
    extraction = extract_tests(tree, source_text)
    doctests = extract_module_doctests(tree, source_text, "__main__", name.removeprefix("conv_"))
    extraction.pinned.extend(doctests.pinned)
    extraction.quarantined.extend(doctests.quarantined)

    meta: dict = {
        **header,
        "source_file": str(source),
        "generator": "jac-py/tools/convert_suite.py",
        "module_stem": name.removeprefix("conv_"),
        "pins_file": f"{name}_pins.jac",
        "pins": [],
        "quarantined": [],
    }

    survivors: list[Pinned] = []
    for pin in extraction.pinned:
        oracle = capture_host_oracle(pin.snippet, cpython_lib)
        if oracle["status"] == "ok":
            pin.oracle = oracle
            survivors.append(pin)
            meta["pins"].append({"ident": pin.ident, "status": "pinned", "oracle": oracle, "snippet": pin.snippet})
        elif oracle["status"] == "timeout":
            meta["pins"].append({"ident": pin.ident, "status": "quarantined", "reason": "host-timeout"})
        elif oracle["status"] == "raised":
            meta["pins"].append(
                {
                    "ident": pin.ident,
                    "status": "quarantined",
                    "reason": f"host-raised:{oracle['exc_type']}: {oracle['exc_msg'][:120]}",
                }
            )
        else:
            meta["pins"].append(
                {"ident": pin.ident, "status": "quarantined", "reason": f"harness-error:{oracle.get('detail', '')[:120]}"}
            )
    for q in extraction.quarantined:
        meta["quarantined"].append({"ident": q.ident, "reason": q.reason})
    meta["counts"] = {
        "extracted": len(extraction.pinned) + len(extraction.quarantined),
        "pinned": len(survivors),
        "quarantined": len(meta["pins"]) - len(survivors) + len(extraction.quarantined),
    }
    # Write-time invariants: the transient class behind a reported
    # counts-vs-entries mismatch (counts.pinned != #status-pinned entries)
    # should fail loudly here instead of poisoning downstream dashboards.
    assert meta["counts"]["pinned"] == sum(
        1 for p in meta["pins"] if p["status"] == "pinned"
    ), f"{name}: counts.pinned != status-pinned entries"
    assert meta["counts"]["extracted"] == len(meta["pins"]) + len(meta["quarantined"]), \
        f"{name}: counts.extracted != pins + quarantined"

    outdir.mkdir(parents=True, exist_ok=True)
    pins_path = outdir / meta["pins_file"]
    pins_path.write_text(emit_pin_file(survivors, source), encoding="utf-8")
    meta["hashes"] = {"pins_jac": file_sha256(pins_path)}
    meta_path = outdir / "conversion.json"
    meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")

    manifest_path = None
    if write_manifest:
        manifest_path = write_manifest_entry(name.removeprefix("conv_"), outdir, meta["pins_file"], len(survivors))

    return {
        "pins_file": str(pins_path),
        "meta_file": str(meta_path),
        "manifest": str(manifest_path) if manifest_path else None,
        "counts": meta["counts"],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cpython_test_file", help="CPython Lib/test .py file (named file)")
    parser.add_argument("-o", "--outdir", default=None, help="output dir (default: jac-py/tests/conv_<stem>)")
    parser.add_argument("--name", default=None, help="conversion name (default: conv_<stem>)")
    parser.add_argument("--cpython-lib", default=str(_DEFAULT_LIB), help="pinned CPython Lib dir")
    parser.add_argument("--no-manifest", action="store_true", help="skip conformance manifest update")
    args = parser.parse_args(argv)

    source = Path(args.cpython_test_file)
    if not source.is_file() or source.suffix != ".py":
        parser.error(f"not a named .py file: {source}")
    stem = source.stem.removeprefix("test_")
    name = args.name or f"conv_{stem}"
    outdir = Path(args.outdir) if args.outdir else _TESTS_DIR / name

    result = run_conversion(source, outdir, name, Path(args.cpython_lib), not args.no_manifest)
    counts = result["counts"]
    print(f"converted {source.name}: {counts['pinned']} pinned, "
          f"{counts['quarantined']} quarantined of {counts['extracted']} extracted")
    print(f"pins:     {result['pins_file']}")
    print(f"meta:     {result['meta_file']}")
    if result["manifest"]:
        print(f"manifest: {result['manifest']}")
    print(f"next: .venv/bin/python jac-py/tools/diff_runner.py {result['pins_file']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
