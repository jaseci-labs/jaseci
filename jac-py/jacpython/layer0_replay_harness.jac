# Layer 0/1 host-replay harness (TODO.md Layer 0/1, jac-py/PLAN.md §6.6).
# Test-free module: regression tests in layer0_replay.jac; P3 ratchet in
# layer0_replay_p3_gate.jac. Import this, not layer0_replay, when you need a
# clean ceval slate.
import from objects { PyObj, PyStr, PyError, is_error }
import from pyc_first { unmarshal, exec_code, exec_module, to_host, build_copy_module }

::py::
import ast
import marshal


def _l0_harvest(source):
    """Extract (expr_src, expected_src) pairs from assertEqual/assertEquals calls."""
    pairs = []
    try:
        tree = ast.parse(source)
    except SyntaxError:
        return pairs
    for node in ast.walk(tree):
        if (
            isinstance(node, ast.Call)
            and isinstance(node.func, ast.Attribute)
            and node.func.attr in ("assertEqual", "assertEquals")
            and len(node.args) >= 2
        ):
            a = ast.get_source_segment(source, node.args[0])
            b = ast.get_source_segment(source, node.args[1])
            if a is not None and b is not None:
                pairs.append((a, b))
    return pairs


def _l0_is_selfcontained(expr_src):
    """A replayable expression evaluates on the host with no test-local state."""
    try:
        eval(expr_src, {"__builtins__": __builtins__}, {})
        return True
    except BaseException:
        return False


def _l0_expected(expr_src):
    return eval(expr_src, {"__builtins__": __builtins__}, {})


def _l0_compile_eval(expr_src):
    # Eval-mode code object ends in RETURN_VALUE, so jacpython's ceval yields the
    # expression value directly -- no module-globals plumbing needed.
    return marshal.dumps(compile(expr_src, "<layer0>", "eval"))


def _l0_host_equal(a, b):
    try:
        # Two NaNs are a conformance MATCH (both sides computed NaN); `nan == nan`
        # is False, which would otherwise flag a correct jacpython result.
        if a != a and b != b:
            return True
        return bool(a == b)
    except BaseException:
        return False


# ---- Layer 1: statement-shaped (exec-mode) replay --------------------------
# Layer 0 replays self-contained *expressions*. Layer 1 lifts that to whole test
# *methods*: run a method's self-contained setup statements (a generator def, a
# few binds) in BOTH host CPython and jacpython, then evaluate each `self.assert*`
# argument against that shared, stateful namespace on both sides and diff. This
# is what exercises generator FUNCTIONS (def+yield, .send/.throw/.close, yield
# from) -- none of which fit Layer 0's single-expression eval -- against the real
# corpus, and threads generator state across a method's asserts exactly as
# CPython does when it runs the method once.
_L1_CHECKS = {
    "assertEqual", "assertNotEqual", "assertTrue", "assertFalse",
    "assertIs", "assertIsNot", "assertIsNone", "assertIsNotNone",
    "assertGreater", "assertLess", "assertGreaterEqual", "assertLessEqual",
}

# Fixture-mode-only extensions. Legacy stems must keep their exact harvest
# sets (ratcheted baselines), so these extra assert families are recognized
# only when fixtures=True. Semantics are the harness's established per-arg
# differential one: each argument expression is evaluated on both engines and
# compared cross-engine -- not the assertion relation itself.
_L1_FIXTURE_CHECKS = {
    "assertListEqual", "assertTupleEqual", "assertSetEqual", "assertDictEqual",
    "assertIn", "assertNotIn", "assertCountEqual",
    "assertIsInstance", "assertNotIsInstance",
}


def _stmt_scope_nodes(stmt):
    # ast.walk(stmt) minus nested function/class subtrees: names bound in an
    # inner scope (e.g. a method parameter named `self`) are not fixture-state
    # references of the enclosing test method.
    stack = list(ast.iter_child_nodes(stmt))
    while stack:
        n = stack.pop()
        if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            continue
        yield n
        stack.extend(ast.iter_child_nodes(n))


def _dedent_segment(seg, base_col):
    # ast.get_source_segment keeps ABSOLUTE indentation on continuation lines
    # while the first line loses its own indent (base_col). Every non-blank
    # continuation line therefore carries >= base_col leading columns: strip
    # exactly base_col so the block's RELATIVE shape survives. (Stripping a
    # min-delta would no-op whenever sibling clauses sit at base_col, e.g.
    # try/except/else.) Single-line segments pass through.
    lines = seg.split("\n")
    if len(lines) < 2 or base_col <= 0:
        return seg
    fixed = [lines[0]] + [
        l[base_col:] if len(l) >= base_col and l[:base_col].strip() == "" else l
        for l in lines[1:]
    ]
    return "\n".join(fixed)


def _l1_is_check_expr(s, names=None):
    """True for a `self.assertX(...)` expression statement (X in names)."""
    return (
        isinstance(s, ast.Expr)
        and isinstance(s.value, ast.Call)
        and isinstance(s.value.func, ast.Attribute)
        and isinstance(s.value.func.value, ast.Name)
        and s.value.func.value.id == "self"
        and s.value.func.attr in (names if names is not None else _L1_CHECKS)
    )


def _l1_is_raises_call(s):
    """True for a bare `self.assertRaises(E, callable, *args, **kwargs)`
    expression statement (the non-with form)."""
    return (
        isinstance(s, ast.Expr)
        and isinstance(s.value, ast.Call)
        and isinstance(s.value.func, ast.Attribute)
        and isinstance(s.value.func.value, ast.Name)
        and s.value.func.value.id == "self"
        and s.value.func.attr == "assertRaises"
        and len(s.value.args) >= 2
    )


def _l1_is_subtest_with(s):
    """True for a `with self.subTest(...):` statement."""
    return (
        isinstance(s, ast.With)
        and len(s.items) == 1
        and isinstance(s.items[0].context_expr, ast.Call)
        and isinstance(s.items[0].context_expr.func, ast.Attribute)
        and isinstance(s.items[0].context_expr.func.value, ast.Name)
        and s.items[0].context_expr.func.value.id == "self"
        and s.items[0].context_expr.func.attr == "subTest"
    )


def _l1_is_raises_with(s):
    """True for a `with self.assertRaises(E): ...` statement."""
    return (
        isinstance(s, ast.With)
        and len(s.items) == 1
        and isinstance(s.items[0].context_expr, ast.Call)
        and isinstance(s.items[0].context_expr.func, ast.Attribute)
        and isinstance(s.items[0].context_expr.func.value, ast.Name)
        and s.items[0].context_expr.func.value.id == "self"
        and s.items[0].context_expr.func.attr == "assertRaises"
        and len(s.items[0].context_expr.args) >= 1
    )


def _l1_lift_try_checks(try_node):
    """Collect harvestable check nodes from a Try's body/orelse/finalbody
    (recursing into nested Trys). Handler bodies are NEVER touched: their
    exception bindings are invisible to post-hoc evaluation.

    The Try statement itself stays COMPLETELY intact in setup -- source
    segments always render the original text, so any in-place assert still
    executes on both legs during setup (divergence surfaces honestly as a
    probe decline or replay error); the lifted copy adds post-hoc value
    comparison on top. Never rewrites control flow: the old expansion made
    `try: x=risky() except: x=0` run as `x=risky(); x=0` on both legs --
    identical wrong code, FALSE GREEN.

    Returns (check_nodes_in_order)."""
    lifted = []
    for region in (try_node.body, try_node.orelse, try_node.finalbody):
        for s in region:
            if isinstance(s, ast.Try):
                lifted.extend(_l1_lift_try_checks(s))
            elif _l1_is_check_expr(s) or _l1_is_raises_with(s):
                lifted.append(s)
    return lifted


def _l1_flatten_seq(stmts):
    """Flatten a statement sequence for harvesting. Try blocks stay whole;
    their nested checks ride along as siblings so the harvest loop lifts them
    like top-level checks (see _l1_lift_try_checks)."""
    out = []
    for s in stmts:
        if isinstance(s, ast.Try):
            out.append(s)
            out.extend(_l1_lift_try_checks(s))
        else:
            out.append(s)
    return out


def _l1_harvest_one(source, node, allow_self=False):
    """Harvest one test method body -> (setup_stmts, checks) or None.

    Shared by legacy and fixture modes; sees ONLY the method's own statements,
    so fixture composition stays a caller-side concern. allow_self (fixture
    mode only) keeps setup statements that touch `self`: the composed namespace
    defines a synthetic fixture object, so `self.attr` resolves there -- and
    anything the fixture can't provide fails the host probe honestly."""
    setup_stmts, checks = [], []
    import textwrap
    # Worklist (not recursion) so fixture mode can splice `with self.subTest`
    # bodies in place, preserving execution order while dropping the pure-
    # labelling wrapper. Legacy never sees subTest/extra asserts: any self-
    # touch already dropped those methods there.
    pending = list(_l1_flatten_seq(node.body))
    check_names = (_L1_CHECKS | _L1_FIXTURE_CHECKS) if allow_self else None
    i = 0
    while i < len(pending):
        stmt = pending[i]
        i += 1
        if allow_self and _l1_is_subtest_with(stmt):
            pending[i:i] = list(stmt.body)
            continue
        # A `self.assertX(...)` check statement.
        if _l1_is_check_expr(stmt, check_names):
            args = [ast.get_source_segment(source, a) for a in stmt.value.args]
            if any(a is None for a in args):
                return None
            checks.append((stmt.value.func.attr, args))
            continue
        # A `with self.assertRaises(E): body` raises-check. Stored as
        # ("assertRaises", [exc_src, body_src]); body_src is a dedented
        # statement block whose execution must raise a matching exception.
        if _l1_is_raises_with(stmt):
            exc_src = ast.get_source_segment(
                source, stmt.items[0].context_expr.args[0]
            )
            body_nodes = list(stmt.body)
            body_segs = [ast.get_source_segment(source, s) for s in body_nodes]
            if exc_src is None or any(s is None for s in body_segs) or (
                not allow_self
                and any(
                    isinstance(n, ast.Name) and n.id == "self"
                    for s in stmt.body for n in _stmt_scope_nodes(s)
                )
            ):
                return None
            body_fixed = "\n".join(
                _dedent_segment(seg, n.col_offset)
                for n, seg in zip(body_nodes, body_segs)
            )
            checks.append(("assertRaises", [exc_src, textwrap.dedent(body_fixed)]))
            continue
        # A bare `self.assertRaises(E, callable, *args, **kwargs)` call. Stored
        # like a raises-check but with the WRAPPED CALL reconstructed from
        # segments -- replaying the raw statement would need unittest's
        # assertRaises, which the fixture namespace deliberately lacks.
        if allow_self and _l1_is_raises_call(stmt):
            call = stmt.value
            exc_src = ast.get_source_segment(source, call.args[0])
            fn_src = ast.get_source_segment(source, call.args[1])
            arg_srcs = [
                ast.get_source_segment(source, a) for a in call.args[2:]
            ] + [
                f"{kw.arg}={ast.get_source_segment(source, kw.value)}"
                for kw in call.keywords
                if kw.arg is not None and ast.get_source_segment(source, kw.value)
            ]
            if exc_src is None or fn_src is None or any(
                a is None for a in arg_srcs
            ):
                return None
            checks.append(("assertRaises", [exc_src, fn_src + "(" + ", ".join(arg_srcs) + ")"]))
            continue
        # A bare docstring/expression constant is inert setup.
        if isinstance(stmt, ast.Expr) and isinstance(stmt.value, ast.Constant):
            continue
        # Kept-intact Try: control flow must not be rewritten (see
        # _l1_lift_try_checks), so bypass the self-touch drop here. Nested
        # self refs are handled honestly: lifted checks evaluate post-hoc;
        # unlifted ones (handler bodies) NameError during setup exec since
        # the layer-1 namespace has no self -> host probe declines -> skip.
        if isinstance(stmt, ast.Try):
            seg = ast.get_source_segment(source, stmt)
            if seg is None:
                return None
            setup_stmts.append(_dedent_segment(seg, stmt.col_offset))
            continue
        # Anything referencing `self` (or an unharvestable segment) is out.
        # The walk skips nested def/class subtrees: a method parameter named
        # `self` inside a locally-defined class/function is its own scope,
        # not fixture state (the host replayability probe still guards the
        # remainder). Only Load-scope references at statement scope count.
        if not allow_self and any(
            isinstance(n, ast.Name) and n.id == "self"
            for n in _stmt_scope_nodes(stmt)
        ):
            return None
        seg = ast.get_source_segment(source, stmt)
        if seg is None:
            return None
        setup_stmts.append(_dedent_segment(seg, stmt.col_offset))
    if not checks:
        return None
    return (setup_stmts, checks)


def _l1_parse(source):
    try:
        return ast.parse(source)
    except SyntaxError:
        return None


def _l1_harvest_methods_parsed(tree, source):
    """Split each `test_*` method into (name, setup_src, checks).

    setup_src is the dedented block of the method's non-assert statements;
    checks is a list of (assert_name, [arg_src, ...]). A method is dropped here
    (never reported) if any setup statement touches `self` (fixture state this
    layer can't reproduce) or the body uses constructs this layer doesn't model
    (with/try/assertRaises); those are counted as skipped by the caller when the
    host self-containment probe also declines them.
    """
    out = []
    for node in ast.walk(tree):
        if not (isinstance(node, ast.FunctionDef) and node.name.startswith("test")):
            continue
        harvested = _l1_harvest_one(source, node)
        if harvested is None:
            continue
        setup_stmts, checks = harvested
        import textwrap
        setup_src = textwrap.dedent("\n".join(setup_stmts)) if setup_stmts else ""
        out.append((node.name, setup_src, checks))
    return out


def _l1_harvest_methods(source):
    tree = _l1_parse(source)
    if tree is None:
        return []
    return _l1_harvest_methods_parsed(tree, source)


# ---- Fixture mode (opt-in per manifest entry: "fixtures": true) ------------
# Legacy harvesting drops any method whose setup touches `self`, so fixture-
# driven CPython test files (setUp bodies, class-level attributes, module-level
# helper classes/functions) yield zero harvestable methods. Fixture mode makes
# such methods replayable WITHOUT changing what legacy stems harvest:
#
#   1. Module-level imports, simple assigns and def/class definitions are
#      carried into the replayed namespace (each non-def guarded with
#      try/except so one unimportable extension module can't poison the whole
#      file -- both legs run identical guarded code).
#   2. Class-level data attributes are replayed onto a synthetic fixture
#      instance (`self`); lambda-valued attributes attach to the fixture CLASS
#      instead so `self.f(x)` binds self exactly like the real class does.
#   3. The enclosing class's setUp body (resolved base-first through
#      module-level bases) is inlined ahead of the test body.
#
# Honesty invariants are preserved: anything still unrunnable (properties,
# helper methods on self like check()/hash_constructors, unittest.skip
# decorators, subTest plumbing) fails the HOST self-containment probe first
# and counts as skipped -- never passed; both legs always execute identical
# source, so there is no fixture-shaped false green.


def _l1_fixture_preamble(tree, source):
    """Module-level statements carried into every fixture-mode setup: imports,
    simple assigns, function/class defs, and Try/If blocks that conditionally
    bind extension-module names (_hashlib & co). Each statement gets its own
    try/except so an unimportable optional module or a class-creation side
    effect degrades to honest per-method skips instead of poisoning the file.
    unittest.TestCase subclasses are NOT carried: creating them runs decorator
    machinery (skip* marks referencing test.support) that replayed methods
    never need -- their data lives in the class-attr fixture instead."""
    import textwrap
    parts = []
    for stmt in tree.body:
        if isinstance(stmt, ast.If) and any(
            isinstance(n, ast.Compare)
            and any(isinstance(x, ast.Constant) and x.value == "__main__"
                    for x in [n.left] + n.comparators)
            for n in _stmt_scope_nodes(stmt)
        ):
            # `if __name__ == "__main__": unittest.main()` is CLI plumbing;
            # replayed namespaces run under __name__ == "__main__" so carrying
            # it would launch a whole unittest run inside every setup.
            continue
        emit = None
        if isinstance(stmt, (ast.Import, ast.ImportFrom, ast.Assign,
                             ast.AnnAssign, ast.FunctionDef,
                             ast.AsyncFunctionDef, ast.Try, ast.If)):
            emit = stmt
        elif isinstance(stmt, ast.ClassDef):
            if not any(
                (isinstance(b, ast.Name) and b.id.find("TestCase") != -1)
                or (isinstance(b, ast.Attribute) and b.attr.find("TestCase") != -1)
                for b in stmt.bases
            ):
                emit = stmt
        if emit is None:
            continue
        seg = ast.get_source_segment(source, stmt)
        if seg is None:
            continue
        seg = _dedent_segment(seg, stmt.col_offset)
        parts.append(
            "try:\n" + textwrap.indent(seg, "    ") + "\nexcept BaseException:\n    pass"
        )
    return "\n".join(parts)


def _l1_fixture_mro(cls_node, classes):
    """Base-first order over module-level bases resolvable by name (unittest
    TestCase bases and anything nested/renamed are simply absent)."""
    seen, order = set(), []

    def visit(c):
        if id(c) in seen:
            return
        seen.add(id(c))
        for b in c.bases:
            if isinstance(b, ast.Name) and b.id in classes:
                visit(classes[b.id])
        order.append(c)

    visit(cls_node)
    return order


def _l1_class_attr_lines(cls_node, source):
    """Class-level data attrs -> `self.X = <seg>` lines; lambda values attach
    to the fixture class so attribute access binds self like a real method."""
    lines = []
    for stmt in cls_node.body:
        value = getattr(stmt, "value", None)
        if value is None:
            continue
        targets = []
        if isinstance(stmt, ast.Assign):
            targets = stmt.targets
        elif isinstance(stmt, ast.AnnAssign):
            targets = [stmt.target]
        else:
            continue
        seg = ast.get_source_segment(source, value)
        if seg is None:
            continue
        names = []
        for t in targets:
            if isinstance(t, ast.Name):
                names.append(t.id)
            elif isinstance(t, ast.Tuple) and all(
                isinstance(e, ast.Name) for e in t.elts
            ):
                names.extend(e.id for e in t.elts)
            else:
                names = []
                break
        if not names:
            continue
        if isinstance(value, ast.Lambda):
            lines.append(f"_L1Fixture.{names[0]} = {seg}")
        else:
            lines.append(
                ", ".join("self." + n for n in names) + " = " + seg
            )
    return lines


def _l1_fixture_setup_body(cls_node, source):
    """Dedented setUp body of cls_node (docstrings dropped), or None."""
    import textwrap
    for stmt in cls_node.body:
        if isinstance(stmt, ast.FunctionDef) and stmt.name == "setUp":
            parts = []
            for s in stmt.body:
                if isinstance(s, ast.Expr) and isinstance(s.value, ast.Constant):
                    continue
                seg = ast.get_source_segment(source, s)
                if seg is None:
                    return None
                parts.append(_dedent_segment(seg, s.col_offset))
            return textwrap.dedent("\n".join(parts))
    return None


def _l1_harvest_methods_fixture(tree, source):
    """Fixture-mode variant of _l1_harvest_methods."""
    import textwrap
    classes = {
        n.name: n for n in ast.walk(tree) if isinstance(n, ast.ClassDef)
    }
    parents = {}
    for n in ast.walk(tree):
        for c in ast.iter_child_nodes(n):
            parents[c] = n
    preamble = _l1_fixture_preamble(tree, source)
    out = []
    for node in ast.walk(tree):
        if not (isinstance(node, ast.FunctionDef) and node.name.startswith("test")):
            continue
        harvested = _l1_harvest_one(source, node, allow_self=True)
        if harvested is None:
            continue
        setup_stmts, checks = harvested
        attr_lines, setUp_src = [], None
        cls = parents.get(node)
        if isinstance(cls, ast.ClassDef):
            for c in _l1_fixture_mro(cls, classes):
                attr_lines.extend(_l1_class_attr_lines(c, source))
                body = _l1_fixture_setup_body(c, source)
                if body is not None:
                    setUp_src = body
        head = [preamble] if preamble else []
        head.append("class _L1Fixture:\n    pass\nself = _L1Fixture()")
        head.extend(attr_lines)
        if setUp_src is not None:
            head.append(setUp_src)
        setup_src = textwrap.dedent("\n".join(head + setup_stmts))
        out.append((node.name, setup_src, checks))
    return out


def _l1_host_setup(setup_src):
    import copy
    ns = {"__name__": "__main__", "__builtins__": __builtins__, "copy": copy}
    if setup_src:
        exec(compile(setup_src, "<layer1>", "exec"), ns)
    return ns


def _l1_host_eval_in(ns, expr_src):
    return eval(compile(expr_src, "<layer1>", "eval"), ns)


def _l1_host_raises(ns, body_src):
    """Execute a statement block; return the raised exception's type name, or
    None if it completed without raising."""
    try:
        exec(compile(body_src, "<layer1>", "exec"), ns)
        return None
    except BaseException as e:
        return type(e).__name__


def _l1_raise_match(jac_name, host_name):
    """Conformance for a raises-check: jacpython must raise the same concrete
    exception type CPython did (both non-empty and equal)."""
    return bool(host_name is not None and jac_name != "" and jac_name == host_name)


def _l1_host_replayable(setup_src, checks):
    """True iff the method runs end-to-end on the HOST with no fixture state --
    setup execs, every assert argument evaluates, and every raises-check body
    actually raises its expected type. Filters out methods that need imports/
    state we don't carry, so they're honestly counted as skipped rather than
    charged against jacpython as failures."""
    try:
        ns = _l1_host_setup(setup_src)
        for name, args in checks:
            if name == "assertRaises":
                _l1_host_eval_in(ns, args[0])  # expected-exc name must resolve
                if _l1_host_raises(ns, args[1]) is None:
                    return False
                continue
            for arg_src in args:
                _l1_host_eval_in(ns, arg_src)
        return True
    except BaseException:
        return False


def _l1_compile_setup(setup_src):
    return marshal.dumps(compile(setup_src or "pass", "<layer1>", "exec"))
::py::



# The two-dimensional ledger TODO.md Layer 1 calls for, seeded at Layer 0:
# passed/failed are real conformance; skipped is the honest scaffolding count
# (asserts that need fixture state this layer can't carry).
obj ReplayResult {
    has passed: int = 0,
        failed: int = 0,
        skipped: int = 0,
        errored: int = 0,
        failures: list[str] = [],
        errors: list[str] = [];
}

# jacpython raised while replaying (marshal/ceval gap)
# Replay one self-contained expression through the jacpython object core + ceval
# and diff against the host's own evaluation. Returns True on match. Guarded:
# a marshal-reader desync or an unsupported opcode is a tool gap to be counted,
# never a crash that aborts the whole file's measurement.
def replay_expr(expr_src: str) -> bool {
    try {
        co: PyObj = unmarshal(_l0_compile_eval(expr_src) as list[int]);
        got: PyObj = exec_code(co, [], {});
        return _l0_host_equal(to_host(got), _l0_expected(expr_src)) as bool;
    } except Exception as e {
        return False;
    }
}

# Replay `expr_src` in jacpython and diff against host(`expected_src`).
# Returns 1 (match), 0 (mismatch), or -1 (jacpython raised -- a real gap).
def _replay_pair(expr_src: str, expected_src: str) -> int {
    try {
        got: PyObj = exec_code(
            unmarshal(_l0_compile_eval(expr_src) as list[int]), [], {}
        );
        expected = _l0_expected(expected_src);
        if _l0_host_equal(to_host(got), expected) as bool {
            return 1;
        }
        return 0;
    } except Exception as e {
        return -1;
    }
}

# Drive a whole test-file source string: harvest its assertEqual pairs, replay
# every self-contained one, tally the rest as scaffolding-skips. The errored
# count is the honest "tool gap discovered here" signal (PLAN.md item #6).
def layer0_replay_source(source: str) -> ReplayResult {
    result = ReplayResult();
    pairs = _l0_harvest(source);
    for pair in pairs {
        expr_src: str = pair[0] as str;
        expected_src: str = pair[1] as str;
        if not (
            (_l0_is_selfcontained(expr_src) as bool)
            and (_l0_is_selfcontained(expected_src) as bool)
        ) {
            result.skipped = result.skipped + 1;
            continue;
        }
        verdict = _replay_pair(expr_src, expected_src);
        if verdict == 1 {
            result.passed = result.passed + 1;
        } elif verdict == 0 {
            result.failed = result.failed + 1;
            result.failures.append(expr_src);
        } else {
            result.errored = result.errored + 1;
            result.errors.append(expr_src);
        }
    }
    return result;
}

# ---- Layer 1 driver (jac side) --------------------------------------------

# Run a method's setup in jacpython, returning the resulting module namespace.
# `copy` is seeded with the native copy shim (matching the host setup) so a
# `copy.copy(gen)` check raises CPython's TypeError natively rather than draining
# the generator to a host list; a setup that binds `copy` itself takes precedence.
def layer1_run_setup(setup_src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    # Strict: a setup that raises must surface here, so the caller counts the
    # method as ERRORED — replaying asserts against a partial namespace yields
    # misleading FAILED verdicts (HARNESS A). exec_module discards the outcome.
    outcome = exec_code(unmarshal(_l1_compile_setup(setup_src) as list[int]), [], ns);
    if is_error(outcome) {
        raise RuntimeError((outcome as PyError).exception.message);
    }
    if not ("copy" in ns) {
        ns["copy"] = build_copy_module();
    }
    return ns;
}

# Evaluate `expr_src` (eval-mode) against a jacpython namespace, so names bound
# by the setup (generators, locals) resolve. Eval-mode code ends in RETURN_VALUE.
def layer1_eval_in(ns: dict[str, PyObj], expr_src: str) -> PyObj {
    return exec_code(unmarshal(_l0_compile_eval(expr_src) as list[int]), [], ns);
}

# Execute a statement block (exec-mode) against a jacpython namespace and report
# the type name of a raised exception, or "" if it completed without raising --
# the jac side of an assertRaises check. run_frame surfaces an uncaught raise as
# its return value, so an error result IS jacpython's raise.
def _l1_jac_raise_name(ns: dict[str, PyObj], body_src: str) -> str {
    outcome = exec_code(unmarshal(_l1_compile_setup(body_src) as list[int]), [], ns);
    if is_error(outcome) {
        return (outcome as PyError).exception.type_name;
    }
    return "";
}

# Replay one harvested method: build the jacpython and host namespaces once, then
# evaluate every assert argument against both in source order (so shared
# generator state advances identically) and diff each. Returns 1 (all match),
# 0 (a real divergence), or -1 (jacpython raised -- a ceval/marshal gap).
def _l1_replay_method(setup_src: str, checks: any) -> int {
    try {
        ns_jac = layer1_run_setup(setup_src);
        ns_host = _l1_host_setup(setup_src);
        for chk in checks {
            if (chk[0] as str) == "assertRaises" {
                # jacpython and CPython must raise the same exception type when
                # the check body runs against the shared namespace.
                jac_name = _l1_jac_raise_name(ns_jac, chk[1][1] as str);
                host_name = _l1_host_raises(ns_host, chk[1][1]);
                if not (_l1_raise_match(jac_name, host_name) as bool) {
                    return 0;
                }
                continue;
            }
            for arg_src in chk[1] {
                jac_got: PyObj = layer1_eval_in(ns_jac, arg_src as str);
                host_exp = _l1_host_eval_in(ns_host, arg_src);
                if not (_l0_host_equal(to_host(jac_got), host_exp) as bool) {
                    return 0;
                }
            }
        }
        return 1;
    } except Exception as e {
        return -1;
    }
}

# Drive a whole test-file source through Layer 1: harvest replayable methods,
# probe each for host self-containment (fixture-free), and replay the rest.
# With fixtures=True, methods gain a synthetic fixture namespace built from the
# module preamble, class-level attributes, and an inlined setUp body (see the
# fixture-mode block above). Legacy stems must NOT pass fixtures=True -- their
# harvest sets and baselines are defined by the legacy pass.
def layer1_replay_source(source: str, fixtures: bool = False) -> ReplayResult {
    result = ReplayResult();
    tree = _l1_parse(source);
    if tree is None {
        return result;
    }
    if fixtures {
        methods = _l1_harvest_methods_fixture(tree, source);
    } else {
        methods = _l1_harvest_methods_parsed(tree, source);
    }
    for method in methods {
        setup_src: str = method[1] as str;
        checks = method[2];
        if not (_l1_host_replayable(setup_src, checks) as bool) {
            result.skipped = result.skipped + 1;
            continue;
        }
        verdict = _l1_replay_method(setup_src, checks);
        if verdict == 1 {
            result.passed = result.passed + 1;
        } elif verdict == 0 {
            result.failed = result.failed + 1;
            result.failures.append(method[0] as str);
        } else {
            result.errored = result.errored + 1;
            result.errors.append(method[0] as str);
        }
    }
    return result;
}
