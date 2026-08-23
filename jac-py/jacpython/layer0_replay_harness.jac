# Layer 0/1 host-replay harness (TODO.md Layer 0/1, jac-py/PLAN.md §6.6).
# Test-free module: regression tests in layer0_replay.jac; P3 ratchet in
# layer0_replay_p3_gate.jac. Import this, not layer0_replay, when you need a
# clean ceval slate.
import from objects { PyObj, PyStr, PyError, is_error }
import from pyc_first { unmarshal, exec_code, exec_module, to_host, build_copy_module }

import ast;
import marshal;


def _l0_harvest(source: str) -> list {
    # Extract (expr_src, expected_src) pairs from assertEqual/assertEquals calls.
    pairs = [];
    try {
        tree: any = ast.parse(source);
    } except SyntaxError {
        return pairs;
    }
    for x in ast.walk(tree) {
        if (
            isinstance(x, ast.Call)
            and isinstance(getattr(x, "func"), ast.Attribute)
            and str(getattr(getattr(x, "func"), "attr")) in ("assertEqual", "assertEquals")
            and len(getattr(x, "args")) >= 2
        ) {
            a = ast.get_source_segment(source, getattr(x, "args")[0]);
            b = ast.get_source_segment(source, getattr(x, "args")[1]);
            if a is not None and b is not None {
                pairs.append((str(a), str(b)));
            }
        }
    }
    return pairs;
}


def _l0_is_selfcontained(expr_src: str) -> bool {
    # A replayable expression evaluates on the host with no test-local state.
    try {
        eval(expr_src, {"__builtins__": __builtins__}, {});
        return True;
    } except BaseException {
        return False;
    }
}


def _l0_expected(expr_src: str) -> any {
    return eval(expr_src, {"__builtins__": __builtins__}, {});
}


def _l0_compile_eval(expr_src: str) -> any {
    # Eval-mode code object ends in RETURN_VALUE, so jacpython's ceval yields the
    # expression value directly -- no module-globals plumbing needed.
    return marshal.dumps(compile(expr_src, "<layer0>", "eval"));
}


def _l0_host_equal(a: any, b: any) -> bool {
    try {
        # Two NaNs are a conformance MATCH (both sides computed NaN); `nan == nan`
        # is False, which would otherwise flag a correct jacpython result.
        if a != a and b != b {
            return True;
        }
        return bool(a == b);
    } except BaseException {
        return False;
    }
}


# ---- Layer 1: statement-shaped (exec-mode) replay --------------------------
# Layer 0 replays self-contained *expressions*. Layer 1 lifts that to whole test
# *methods*: run a method's self-contained setup statements (a generator def, a
# few binds) in BOTH host CPython and jacpython, then evaluate each `self.assert*`
# argument against that shared, stateful namespace on both sides and diff. This
# is what exercises generator FUNCTIONS (def+yield, .send/.throw/.close, yield
# from) -- none of which fit Layer 0's single-expression eval -- against the real
# corpus, and threads generator state across a method's asserts exactly as
# CPython does when it runs the method once.
glob _L1_CHECKS = {
    "assertEqual", "assertNotEqual", "assertTrue", "assertFalse",
    "assertIs", "assertIsNot", "assertIsNone", "assertIsNotNone",
    "assertGreater", "assertLess", "assertGreaterEqual", "assertLessEqual",
};

# Fixture-mode-only extensions. Legacy stems must keep their exact harvest
# sets (ratcheted baselines), so these extra assert families are recognized
# only when fixtures=True. Semantics are the harness's established per-arg
# differential one: each argument expression is evaluated on both engines and
# compared cross-engine -- not the assertion relation itself.
glob _L1_FIXTURE_CHECKS = {
    "assertListEqual", "assertTupleEqual", "assertSetEqual", "assertDictEqual",
    "assertIn", "assertNotIn", "assertCountEqual",
    "assertIsInstance", "assertNotIsInstance",
};

# Identity-family asserts evaluate the assertion RELATION atomically on each
# engine -- `(a) is (b)` wholly in jacpython, `host_a is host_b` over
# host-evaluated operands -- instead of marshaling operands across the bridge.
# The engines run independent executions of the same source, so no to_host
# mapping can make a guest type object is-identical to the host's own class
# object (cf. TODO item 58; same identity-non-round-trip class as deviation
# D-RANGE-ID).
glob _L1_IDENTITY_CHECKS = {
    "assertIs", "assertIsNot", "assertIsInstance", "assertNotIsInstance",
};


def _stmt_scope_nodes(stmt: any) -> any {
    # ast.walk(stmt) minus nested function/class subtrees: names bound in an
    # inner scope (e.g. a method parameter named `self`) are not fixture-state
    # references of the enclosing test method.
    stack = list(ast.iter_child_nodes(stmt));
    while stack {
        n = stack.pop();
        if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)) {
            continue;
        }
        yield n;
        stack.extend(ast.iter_child_nodes(n));
    }
}


def _dedent_segment(seg: any, base_col: any) -> str {
    # ast.get_source_segment keeps ABSOLUTE indentation on continuation lines
    # while the first line loses its own indent (base_col). Every non-blank
    # continuation line therefore carries >= base_col leading columns: strip
    # exactly base_col so the block's RELATIVE shape survives. (Stripping a
    # min-delta would no-op whenever sibling clauses sit at base_col, e.g.
    # try/except/else.) Single-line segments pass through.
    bc = int(base_col);
    lines = str(seg).split("\n");
    if len(lines) < 2 or bc <= 0 {
        return str(seg);
    }
    fixed: list[str] = [lines[0]];
    for line in lines[1:] {
        if len(line) >= bc and line[:bc].strip() == "" {
            fixed.append(line[bc:]);
        } else {
            fixed.append(line);
        }
    }
    return "\n".join(fixed);
}


def _l1_is_check_expr(s: any, names: any = None) -> bool {
    # True for a `self.assertX(...)` expression statement (X in names).
    if not isinstance(s, ast.Expr) {
        return False;
    }
    check_names = _L1_CHECKS;
    if names is not None {
        check_names = names;
    }
    val = getattr(s, "value");
    if not isinstance(val, ast.Call) {
        return False;
    }
    fn = getattr(val, "func");
    if not isinstance(fn, ast.Attribute) {
        return False;
    }
    recv = getattr(fn, "value");
    return (
        isinstance(recv, ast.Name)
        and str(getattr(recv, "id")) == "self"
        and str(getattr(fn, "attr")) in (check_names as set)
    );
}


def _l1_is_raises_call(s: any) -> bool {
    # True for a bare `self.assertRaises(E, callable, *args, **kwargs)`
    # expression statement (the non-with form).
    if not isinstance(s, ast.Expr) {
        return False;
    }
    val = getattr(s, "value");
    if not isinstance(val, ast.Call) {
        return False;
    }
    fn = getattr(val, "func");
    if not isinstance(fn, ast.Attribute) {
        return False;
    }
    recv = getattr(fn, "value");
    return (
        isinstance(recv, ast.Name)
        and str(getattr(recv, "id")) == "self"
        and str(getattr(fn, "attr")) == "assertRaises"
        and len(getattr(val, "args")) >= 2
    );
}


def _l1_is_subtest_with(s: any) -> bool {
    # True for a `with self.subTest(...):` statement.
    if not isinstance(s, ast.With) {
        return False;
    }
    items = getattr(s, "items");
    ctx = getattr(items[0], "context_expr");
    if len(items) != 1 or not isinstance(ctx, ast.Call) {
        return False;
    }
    fn = getattr(ctx, "func");
    if not isinstance(fn, ast.Attribute) {
        return False;
    }
    recv = getattr(fn, "value");
    return (
        isinstance(recv, ast.Name)
        and str(getattr(recv, "id")) == "self"
        and str(getattr(fn, "attr")) == "subTest"
    );
}


def _l1_is_raises_with(s: any) -> bool {
    # True for a `with self.assertRaises(E): ...` statement.
    if not isinstance(s, ast.With) {
        return False;
    }
    items = getattr(s, "items");
    ctx = getattr(items[0], "context_expr");
    if len(items) != 1 or not isinstance(ctx, ast.Call) {
        return False;
    }
    fn = getattr(ctx, "func");
    if not isinstance(fn, ast.Attribute) {
        return False;
    }
    recv = getattr(fn, "value");
    return (
        isinstance(recv, ast.Name)
        and str(getattr(recv, "id")) == "self"
        and str(getattr(fn, "attr")) == "assertRaises"
        and len(getattr(ctx, "args")) >= 1
    );
}


def _l1_lift_try_checks(try_node: any) -> list {
    # Collect harvestable check nodes from a Try's body/orelse/finalbody
    # (recursing into nested Trys). Handler bodies are NEVER touched: their
    # exception bindings are invisible to post-hoc evaluation.
    #
    # The Try statement itself stays COMPLETELY intact in setup -- source
    # segments always render the original text, so any in-place assert still
    # executes on both legs during setup (divergence surfaces honestly as a
    # probe decline or replay error); the lifted copy adds post-hoc value
    # comparison on top. Never rewrites control flow: the old expansion made
    # `try: x=risky() except: x=0` run as `x=risky(); x=0` on both legs --
    # identical wrong code, FALSE GREEN.
    #
    # Returns (check_nodes_in_order).
    lifted = [];
    for region in (getattr(try_node, "body"), getattr(try_node, "orelse"), getattr(try_node, "finalbody")) {
        for s in region {
            if isinstance(s, ast.Try) {
                lifted.extend(_l1_lift_try_checks(s));
            } elif _l1_is_check_expr(s) or _l1_is_raises_with(s) {
                lifted.append(s);
            }
        }
    }
    return lifted;
}


def _l1_flatten_seq(stmts: any) -> list {
    # Flatten a statement sequence for harvesting. Try blocks stay whole;
    # their nested checks ride along as siblings so the harvest loop lifts them
    # like top-level checks (see _l1_lift_try_checks).
    out = [];
    for s in stmts {
        if isinstance(s, ast.Try) {
            out.append(s);
            out.extend(_l1_lift_try_checks(s));
        } else {
            out.append(s);
        }
    }
    return out;
}


def _l1_harvest_one(source: str, method_node: any, allow_self: bool = False) -> any {
    # Harvest one test method body -> (setup_stmts, checks) or None.
    #
    # Shared by legacy and fixture modes; sees ONLY the method's own statements,
    # so fixture composition stays a caller-side concern. allow_self (fixture
    # mode only) keeps setup statements that touch `self`: the composed namespace
    # defines a synthetic fixture object, so `self.attr` resolves there -- and
    # anything the fixture can't provide fails the host probe honestly.
    setup_stmts: list[str] = [];
    checks: list = [];
    import textwrap;
    # Worklist (not recursion) so fixture mode can splice `with self.subTest`
    # bodies in place, preserving execution order while dropping the pure-
    # labelling wrapper. Legacy never sees subTest/extra asserts: any self-
    # touch already dropped those methods there.
    pending: list = list(_l1_flatten_seq(getattr(method_node, "body")));
    check_names: set | None = None;
    if allow_self {
        check_names = _L1_CHECKS | _L1_FIXTURE_CHECKS;
    }
    i = 0;
    while i < len(pending) {
        stmt = pending[i];
        i += 1;
        if allow_self and _l1_is_subtest_with(stmt) {
            pending = pending[:i] + list(getattr(stmt, "body")) + pending[i:];
            continue;
        }
        # A `self.assertX(...)` check statement.
        if _l1_is_check_expr(stmt, check_names) {
            val = getattr(stmt, "value");
            args: list[str | None] = [];
            for a in getattr(val, "args") {
                args.append(ast.get_source_segment(source, a));
            }
            any_missing = False;
            for a in args {
                if a is None {
                    any_missing = True;
                }
            }
            if any_missing {
                return None;
            }
            checks.append((str(getattr(getattr(val, "func"), "attr")), args));
            continue;
        }
        # A `with self.assertRaises(E): body` raises-check. Stored as
        # ("assertRaises", [exc_src, body_src]); body_src is a dedented
        # statement block whose execution must raise a matching exception.
        if _l1_is_raises_with(stmt) {
            ctx_args = getattr(getattr(getattr(stmt, "items")[0], "context_expr"), "args");
            exc_src = ast.get_source_segment(source, ctx_args[0]);
            body_nodes: list = list(getattr(stmt, "body"));
            body_segs: list[str | None] = [];
            for s in body_nodes {
                body_segs.append(ast.get_source_segment(source, s));
            }
            self_touched = False;
            if not allow_self {
                for s in body_nodes {
                    for n in _stmt_scope_nodes(s) {
                        if isinstance(n, ast.Name) and str(getattr(n, "id")) == "self" {
                            self_touched = True;
                        }
                    }
                }
            }
            bad = exc_src is None or self_touched;
            for s in body_segs {
                if s is None {
                    bad = True;
                }
            }
            if bad {
                return None;
            }
            fixed_parts: list[str] = [];
            for idx in range(len(body_nodes)) {
                fixed_parts.append(
                    _dedent_segment(body_segs[idx], getattr(body_nodes[idx], "col_offset"))
                );
            }
            checks.append(("assertRaises", [str(exc_src), textwrap.dedent("\n".join(fixed_parts))]));
            continue;
        }
        # A bare `self.assertRaises(E, callable, *args, **kwargs)` call. Stored
        # like a raises-check but with the WRAPPED CALL reconstructed from
        # segments -- replaying the raw statement would need unittest's
        # assertRaises, which the fixture namespace deliberately lacks.
        if allow_self and _l1_is_raises_call(stmt) {
            call = getattr(stmt, "value");
            exc_src = ast.get_source_segment(source, getattr(call, "args")[0]);
            fn_src = ast.get_source_segment(source, getattr(call, "args")[1]);
            arg_srcs: list[str | None] = [];
            for a in getattr(call, "args")[2:] {
                arg_srcs.append(ast.get_source_segment(source, a));
            }
            for kw in getattr(call, "keywords") {
                kw_seg = ast.get_source_segment(source, getattr(kw, "value"));
                if getattr(kw, "arg") is not None and kw_seg {
                    arg_srcs.append(str(getattr(kw, "arg")) + "=" + str(kw_seg));
                }
            }
            bad_call = exc_src is None or fn_src is None;
            for a in arg_srcs {
                if a is None {
                    bad_call = True;
                }
            }
            if bad_call {
                return None;
            }
            joined: list[str] = [];
            for a in arg_srcs {
                joined.append(str(a));
            }
            checks.append(("assertRaises", [str(exc_src), str(fn_src) + "(" + ", ".join(joined) + ")"]));
            continue;
        }
        # A bare docstring/expression constant is inert setup.
        if isinstance(stmt, ast.Expr) and isinstance(getattr(stmt, "value"), ast.Constant) {
            continue;
        }
        # Kept-intact Try: control flow must not be rewritten (see
        # _l1_lift_try_checks), so bypass the self-touch drop here. Nested
        # self refs are handled honestly: lifted checks evaluate post-hoc;
        # unlifted ones (handler bodies) NameError during setup exec since
        # the layer-1 namespace has no self -> host probe declines -> skip.
        if isinstance(stmt, ast.Try) {
            seg = ast.get_source_segment(source, stmt);
            if seg is None {
                return None;
            }
            setup_stmts.append(_dedent_segment(seg, getattr(stmt, "col_offset")));
            continue;
        }
        # Anything referencing `self` (or an unharvestable segment) is out.
        # The walk skips nested def/class subtrees: a method parameter named
        # `self` inside a locally-defined class/function is its own scope,
        # not fixture state (the host replayability probe still guards the
        # remainder). Only Load-scope references at statement scope count.
        if not allow_self {
            touches_self = False;
            for n in _stmt_scope_nodes(stmt) {
                if isinstance(n, ast.Name) and str(getattr(n, "id")) == "self" {
                    touches_self = True;
                }
            }
            if touches_self {
                return None;
            }
        }
        seg = ast.get_source_segment(source, stmt);
        if seg is None {
            return None;
        }
        setup_stmts.append(_dedent_segment(seg, getattr(stmt, "col_offset")));
    }
    if not checks {
        return None;
    }
    return (setup_stmts, checks);
}


def _l1_parse(source: str) -> any {
    try {
        tree: any = ast.parse(source);
        return tree;
    } except SyntaxError {
        return None;
    }
}


def _l1_harvest_methods_parsed(tree: any, source: str) -> list {
    # Split each `test_*` method into (name, setup_src, checks).
    #
    # setup_src is the dedented block of the method's non-assert statements;
    # checks is a list of (assert_name, [arg_src, ...]). A method is dropped here
    # (never reported) if any setup statement touches `self` (fixture state this
    # layer can't reproduce) or the body uses constructs this layer doesn't model
    # (with/try/assertRaises); those are counted as skipped by the caller when the
    # host self-containment probe also declines them.
    out: list = [];
    for ast_node in ast.walk(tree) {
        if not (isinstance(ast_node, ast.FunctionDef) and str(getattr(ast_node, "name")).startswith("test")) {
            continue;
        }
        harvested = _l1_harvest_one(source, ast_node);
        if harvested is None {
            continue;
        }
        setup_stmts: list[str] = harvested[0];
        checks: list = harvested[1];
        import textwrap;
        setup_src = "";
        if setup_stmts {
            setup_src = textwrap.dedent("\n".join(setup_stmts));
        }
        out.append((str(getattr(ast_node, "name")), setup_src, checks));
    }
    return out;
}


def _l1_harvest_methods(source: str) -> list {
    tree = _l1_parse(source);
    if tree is None {
        return [];
    }
    return _l1_harvest_methods_parsed(tree, source);
}


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


def _l1_fixture_preamble(tree: any, source: str) -> str {
    # Module-level statements carried into every fixture-mode setup: imports,
    # simple assigns, function/class defs, and Try/If blocks that conditionally
    # bind extension-module names (_hashlib & co). Each statement gets its own
    # try/except so an unimportable optional module or a class-creation side
    # effect degrades to honest per-method skips instead of poisoning the file.
    # unittest.TestCase subclasses are NOT carried: creating them runs decorator
    # machinery (skip* marks referencing test.support) that replayed methods
    # never need -- their data lives in the class-attr fixture instead.
    import textwrap;
    parts: list[str] = [];
    for stmt in getattr(tree, "body") {
        is_main_guard = False;
        if isinstance(stmt, ast.If) {
            for n in _stmt_scope_nodes(stmt) {
                if isinstance(n, ast.Compare) {
                    left = getattr(n, "left");
                    if isinstance(left, ast.Constant) and str(getattr(left, "value")) == "__main__" {
                        is_main_guard = True;
                    }
                    for x in getattr(n, "comparators") {
                        if isinstance(x, ast.Constant) and str(getattr(x, "value")) == "__main__" {
                            is_main_guard = True;
                        }
                    }
                }
            }
        }
        if is_main_guard {
            # `if __name__ == "__main__": unittest.main()` is CLI plumbing;
            # replayed namespaces run under __name__ == "__main__" so carrying
            # it would launch a whole unittest run inside every setup.
            continue;
        }
        emit = None;
        if isinstance(stmt, (ast.Import, ast.ImportFrom, ast.Assign,
                             ast.AnnAssign, ast.FunctionDef,
                             ast.AsyncFunctionDef, ast.Try, ast.If)) {
            emit = stmt;
        } elif isinstance(stmt, ast.ClassDef) {
            carries_testcase_base = False;
            for b in getattr(stmt, "bases") {
                if (isinstance(b, ast.Name) and str(getattr(b, "id")).find("TestCase") != -1)
                    or (isinstance(b, ast.Attribute) and str(getattr(b, "attr")).find("TestCase") != -1) {
                    carries_testcase_base = True;
                }
            }
            if not carries_testcase_base {
                emit = stmt;
            }
        }
        if emit is None {
            continue;
        }
        seg = ast.get_source_segment(source, emit);
        if seg is None {
            continue;
        }
        seg = _dedent_segment(seg, getattr(emit, "col_offset"));
        parts.append(
            "try:\n" + textwrap.indent(seg, "    ") + "\nexcept BaseException:\n    pass"
        );
    }
    return "\n".join(parts);
}


def _l1_fixture_mro(cls_node: any, classes: dict) -> list {
    # Base-first order over module-level bases resolvable by name (unittest
    # TestCase bases and anything nested/renamed are simply absent).
    seen: set = set();
    order: list = [];

    def visit_cls(c: any) {
        if id(c) in seen {
            return;
        }
        seen.add(id(c));
        for b in getattr(c, "bases") {
            if isinstance(b, ast.Name) and str(getattr(b, "id")) in classes {
                visit_cls(classes[str(getattr(b, "id"))]);
            }
        }
        order.append(c);
    }

    visit_cls(cls_node);
    return order;
}


def _l1_class_attr_lines(cls_node: any, source: str) -> list[str] {
    # Class-level data attrs -> `self.X = <seg>` lines; lambda values attach
    # to the fixture class so attribute access binds self like a real method.
    lines: list[str] = [];
    for stmt in getattr(cls_node, "body") {
        value = getattr(stmt, "value", None);
        if value is None {
            continue;
        }
        targets: list = [];
        if isinstance(stmt, ast.Assign) {
            targets = getattr(stmt, "targets");
        } elif isinstance(stmt, ast.AnnAssign) {
            targets = [getattr(stmt, "target")];
        } else {
            continue;
        }
        seg = ast.get_source_segment(source, value);
        if seg is None {
            continue;
        }
        names: list[str] = [];
        aborted = False;
        for t in targets {
            if isinstance(t, ast.Name) {
                names.append(str(getattr(t, "id")));
            } elif isinstance(t, ast.Tuple) {
                all_named = True;
                for e in getattr(t, "elts") {
                    if not isinstance(e, ast.Name) {
                        all_named = False;
                    }
                }
                if all_named {
                    for e in getattr(t, "elts") {
                        names.append(str(getattr(e, "id")));
                    }
                } else {
                    names = [];
                    aborted = True;
                }
            } else {
                names = [];
                aborted = True;
            }
            if aborted {
                break;
            }
        }
        if not names {
            continue;
        }
        if isinstance(value, ast.Lambda) {
            lines.append("_L1Fixture." + names[0] + " = " + str(seg));
        } else {
            lhs_parts: list[str] = [];
            for n in names {
                lhs_parts.append("self." + n);
            }
            lines.append(", ".join(lhs_parts) + " = " + str(seg));
        }
    }
    return lines;
}


def _l1_fixture_setup_body(cls_node: any, source: str) -> any {
    # Dedented setUp body of cls_node (docstrings dropped), or None.
    import textwrap;
    for stmt in getattr(cls_node, "body") {
        if isinstance(stmt, ast.FunctionDef) and str(getattr(stmt, "name")) == "setUp" {
            parts: list[str] = [];
            missing_seg = False;
            for s in getattr(stmt, "body") {
                if isinstance(s, ast.Expr) and isinstance(getattr(s, "value"), ast.Constant) {
                    continue;
                }
                seg = ast.get_source_segment(source, s);
                if seg is None {
                    missing_seg = True;
                    break;
                }
                parts.append(_dedent_segment(seg, getattr(s, "col_offset")));
            }
            if missing_seg {
                return None;
            }
            return textwrap.dedent("\n".join(parts));
        }
    }
    return None;
}


def _l1_harvest_methods_fixture(tree: any, source: str) -> list {
    # Fixture-mode variant of _l1_harvest_methods.
    import textwrap;
    classes: dict = {};
    for n in ast.walk(tree) {
        if isinstance(n, ast.ClassDef) {
            classes[str(getattr(n, "name"))] = n;
        }
    }
    parents: dict = {};
    for n in ast.walk(tree) {
        for c in ast.iter_child_nodes(n) {
            parents[c] = n;
        }
    }
    preamble = _l1_fixture_preamble(tree, source);
    out: list = [];
    for ast_node in ast.walk(tree) {
        if not (isinstance(ast_node, ast.FunctionDef) and str(getattr(ast_node, "name")).startswith("test")) {
            continue;
        }
        harvested = _l1_harvest_one(source, ast_node, allow_self=True);
        if harvested is None {
            continue;
        }
        setup_stmts: list[str] = harvested[0];
        checks: list = harvested[1];
        attr_lines: list[str] = [];
        setUp_src = None;
        cls = parents.get(ast_node);
        if isinstance(cls, ast.ClassDef) {
            for c in _l1_fixture_mro(cls, classes) {
                attr_lines.extend(_l1_class_attr_lines(c, source));
                body = _l1_fixture_setup_body(c, source);
                if body is not None {
                    setUp_src = body;
                }
            }
        }
        head: list[str] = [];
        if preamble {
            head.append(preamble);
        }
        head.append("class _L1Fixture:\n    pass\nself = _L1Fixture()");
        head.extend(attr_lines);
        if setUp_src is not None {
            head.append(str(setUp_src));
        }
        setup_src = textwrap.dedent("\n".join(head + setup_stmts));
        out.append((str(getattr(ast_node, "name")), setup_src, checks));
    }
    return out;
}


def _l1_host_setup(setup_src: str) -> dict {
    import copy;
    ns: dict = {"__name__": "__main__", "__builtins__": __builtins__, "copy": copy};
    if setup_src {
        exec(compile(setup_src, "<layer1>", "exec"), ns);
    }
    return ns;
}


def _l1_host_eval_in(ns: dict, expr_src: str) -> any {
    return eval(compile(expr_src, "<layer1>", "eval"), ns);
}


def _l1_host_raises(ns: dict, body_src: str) -> any {
    # Execute a statement block; return the raised exception's type name, or
    # None if it completed without raising.
    try {
        exec(compile(body_src, "<layer1>", "exec"), ns);
        return None;
    } except BaseException as e {
        return type(e).__name__;
    }
}


def _l1_raise_match(jac_name: str, host_name: any) -> bool {
    # Conformance for a raises-check: jacpython must raise the same concrete
    # exception type CPython did (both non-empty and equal).
    return bool(host_name is not None and jac_name != "" and jac_name == host_name);
}


def _l1_host_replayable(setup_src: str, checks: list) -> bool {
    # True iff the method runs end-to-end on the HOST with no fixture state --
    # setup execs, every assert argument evaluates, and every raises-check body
    # actually raises its expected type. Filters out methods that need imports/
    # state we don't carry, so they're honestly counted as skipped rather than
    # charged against jacpython as failures.
    try {
        ns = _l1_host_setup(setup_src);
        for check_entry in checks {
            name = check_entry[0];
            args = check_entry[1];
            if name == "assertRaises" {
                _l1_host_eval_in(ns, args[0]);  # expected-exc name must resolve
                if _l1_host_raises(ns, args[1]) is None {
                    return False;
                }
                continue;
            }
            for arg_src in args {
                _l1_host_eval_in(ns, arg_src);
            }
        }
        return True;
    } except BaseException {
        return False;
    }
}


def _l1_compile_setup(setup_src: str) -> any {
    src = setup_src;
    if not src {
        src = "pass";
    }
    return marshal.dumps(compile(src, "<layer1>", "exec"));
}



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
            if (chk[0] as str) in _L1_IDENTITY_CHECKS and len(chk[1]) == 2 {
                # Relation evaluated where its operands live: synthesize ONE
                # eval-mode expression for the guest; compute the identical
                # relation natively over host-evaluated operands on the host.
                name_id = chk[0] as str;
                a_src = chk[1][0] as str;
                b_src = chk[1][1] as str;
                if name_id == "assertIs" {
                    rel_src = "(" + a_src + ") is (" + b_src + ")";
                } elif name_id == "assertIsNot" {
                    rel_src = "(" + a_src + ") is not (" + b_src + ")";
                } elif name_id == "assertIsInstance" {
                    rel_src = "isinstance((" + a_src + "), (" + b_src + "))";
                } else {
                    rel_src = (
                        "not isinstance((" + a_src + "), (" + b_src + "))"
                    );
                }
                jac_rel = to_host(layer1_eval_in(ns_jac, rel_src));
                host_a = _l1_host_eval_in(ns_host, a_src);
                host_b = _l1_host_eval_in(ns_host, b_src);
                if name_id == "assertIs" {
                    host_rel = bool(host_a is host_b);
                } elif name_id == "assertIsNot" {
                    host_rel = bool(host_a is not host_b);
                } elif name_id == "assertIsInstance" {
                    host_rel = bool(isinstance(host_a, host_b));
                } else {
                    host_rel = bool(not isinstance(host_a, host_b));
                }
                if ((jac_rel as bool) != (host_rel as bool)) {
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
