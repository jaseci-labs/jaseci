#!/usr/bin/env python3
"""D2 mechanical test-conversion pipeline: CPython Lib/test file -> .jac pins.

For every ``test_*`` method in a CPython ``Lib/test`` file this tool:

1. Extracts the method via AST and mechanically rewrites the common
   ``unittest`` assertion vocabulary (``assertEqual``, ``assertRaises``, ...)
   into plain asserts/try-except. Anything outside the supported vocabulary
   (other ``self.*`` attributes, unresolved names, skip machinery, decorators)
   is quarantined with a reason instead of silently mistranslating.
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
"""
from __future__ import annotations

import argparse
import ast
import builtins
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

TOOL_VERSION = "conv_suite-0.2.0"
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
    if len(call.args) >= 2 and not regex:
        fn = call.args[1]
        starargs: list[ast.expr] = []
        if len(call.args) > 2:
            starargs = [
                ast.Starred(value=ast.Tuple(elts=list(call.args[2:]), ctx=ast.Load()), ctx=ast.Load())
            ]
        invoke: ast.expr = ast.Call(func=fn, args=starargs, keywords=list(call.keywords))
        tried: list[ast.stmt] = [ast.Expr(value=invoke)]
    else:
        if len(call.args) >= 2:
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

    return rec(stmts), needs_re


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


def _check_self_usage(body: list[ast.stmt]) -> None:
    for node in ast.walk(ast.Module(body=body, type_ignores=[])):
        if (
            isinstance(node, ast.Attribute)
            and isinstance(node.value, ast.Name)
            and node.value.id == "self"
        ):
            raise Unsupported(f"uses-self.{node.attr}")


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
# Extraction


def _src(node: ast.AST, source: str) -> str:
    seg = ast.get_source_segment(source, node)
    return seg or ast.unparse(node)


def collect_prelude(tree: ast.Module, source: str) -> tuple[list[ast.stmt], set[str]]:
    """Module-level imports/assigns/function defs usable as snippet prelude."""
    stmts: list[ast.stmt] = []
    names: set[str] = set()
    for node in tree.body:
        if isinstance(node, (ast.Import, ast.ImportFrom, ast.Assign, ast.AnnAssign, ast.FunctionDef)):
            stmts.append(node)
            names |= _bound_names(node)
    return stmts, names


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
            binds = _bound_names(item)
            if binds & used:
                kept[idx] = item
                new_used = _loaded_names(item)
                if not new_used <= used:
                    used |= new_used
                    changed = True
    return [kept[i] for i in sorted(kept)]


def extract_tests(tree: ast.Module, source: str) -> Extraction:
    result = Extraction()
    prelude, prelude_names = collect_prelude(tree, source)

    candidates: list[tuple[str, list[ast.stmt]]] = []
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
                candidates.append((ident, list(member.body)))
        elif isinstance(node, ast.FunctionDef) and node.name.startswith("test"):
            for deco in node.decorator_list:
                reason = _decorator_reason(deco)
                if reason:
                    result.quarantined.append(Quarantined(node.name, reason))
                    break
            else:
                candidates.append((node.name, list(node.body)))

    for ident, body_stmts in candidates:
        try:
            rewritten, needs_re = rewrite_block(body_stmts)
            # After rewriting, any surviving self.* attribute is an unsupported
            # construct (fixture access, custom helper, skip machinery).
            _check_self_usage(rewritten)
            kept_prelude = _prune_prelude(rewritten, prelude, prelude_names)
            available = prelude_names | _bound_names(ast.Module(body=kept_prelude, type_ignores=[]))
            _check_names(rewritten, available)
        except Unsupported as exc:
            result.quarantined.append(Quarantined(ident, str(exc)))
            continue
        snippet = render_snippet(rewritten, kept_prelude, needs_re)
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
# Snippet rendering


def _concat_expr(parts: list[ast.expr]) -> ast.expr:
    """left-to-right string concatenation expression."""
    out = parts[0]
    for part in parts[1:]:
        out = ast.BinOp(left=out, op=ast.Add(), right=part)
    return out


def render_snippet(body: list[ast.stmt], prelude: list[ast.stmt], needs_re: bool) -> str:
    module = ast.Module(body=[], type_ignores=[])
    stmts: list[ast.stmt] = []
    if needs_re:
        stmts.append(ast.Import(names=[ast.alias(name="re as _re", asname=None)]))
    stmts.extend(prelude)
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
