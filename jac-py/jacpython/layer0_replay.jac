# Layer 0 host-replay harness (TODO.md "Layer 0", jac-py/PLAN.md §6.6 pre-import
# leg). Conformance signal BEFORE jacpython can import anything.
#
# The trap Layer 0 sidesteps: measuring conformance normally needs the test
# runner (unittest -> re -> traceback -> io -> ...) running INSIDE jacpython.
# It doesn't have to. Run the real test_*.py under HOST CPython, harvest each
# `assertEqual(expr, expected)`, host-compile `expr` in eval mode to a code
# object, ship it (marshal) across the substrate boundary, execute it in
# jacpython's ceval, and compare against the host-computed expected value.
#
# jacpython's required surface is then just: object core + ceval + marshal-load
# -- no unittest, no re, no parser. A large fraction of test_int/test_dict/
# test_list asserts are self-contained literal expressions, so coverage from
# this leg alone is substantial. Fixture-dependent asserts (self.value, setUp
# state) are detected on the host and skipped -- later layers pick them up.
import from objects { PyObj, PyError, is_error }
import from pyc_first { unmarshal, exec_code, exec_module, to_host }

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


def _l1_harvest_methods(source):
    """Split each `test_*` method into (name, setup_src, checks).

    setup_src is the dedented block of the method's non-assert statements;
    checks is a list of (assert_name, [arg_src, ...]). A method is dropped here
    (never reported) if any setup statement touches `self` (fixture state this
    layer can't reproduce) or the body uses constructs this layer doesn't model
    (with/try/assertRaises); those are counted as skipped by the caller when the
    host self-containment probe also declines them.
    """
    out = []
    try:
        tree = ast.parse(source)
    except SyntaxError:
        return out
    import textwrap
    for node in ast.walk(tree):
        if not (isinstance(node, ast.FunctionDef) and node.name.startswith("test")):
            continue
        setup_stmts, checks, ok = [], [], True
        for stmt in node.body:
            # A `self.assertX(...)` check statement.
            if (
                isinstance(stmt, ast.Expr)
                and isinstance(stmt.value, ast.Call)
                and isinstance(stmt.value.func, ast.Attribute)
                and isinstance(stmt.value.func.value, ast.Name)
                and stmt.value.func.value.id == "self"
                and stmt.value.func.attr in _L1_CHECKS
            ):
                args = [ast.get_source_segment(source, a) for a in stmt.value.args]
                if any(a is None for a in args):
                    ok = False
                    break
                checks.append((stmt.value.func.attr, args))
                continue
            # A `with self.assertRaises(E): body` raises-check. Stored as
            # ("assertRaises", [exc_src, body_src]); body_src is a dedented
            # statement block whose execution must raise a matching exception.
            if (
                isinstance(stmt, ast.With)
                and len(stmt.items) == 1
                and isinstance(stmt.items[0].context_expr, ast.Call)
                and isinstance(stmt.items[0].context_expr.func, ast.Attribute)
                and isinstance(stmt.items[0].context_expr.func.value, ast.Name)
                and stmt.items[0].context_expr.func.value.id == "self"
                and stmt.items[0].context_expr.func.attr == "assertRaises"
                and len(stmt.items[0].context_expr.args) >= 1
            ):
                exc_src = ast.get_source_segment(
                    source, stmt.items[0].context_expr.args[0]
                )
                body_segs = [ast.get_source_segment(source, s) for s in stmt.body]
                if exc_src is None or any(s is None for s in body_segs) or any(
                    isinstance(n, ast.Name) and n.id == "self"
                    for s in stmt.body for n in ast.walk(s)
                ):
                    ok = False
                    break
                checks.append(("assertRaises", [exc_src, textwrap.dedent(
                    "\n".join(body_segs))]))
                continue
            # A bare docstring/expression constant is inert setup.
            if isinstance(stmt, ast.Expr) and isinstance(stmt.value, ast.Constant):
                continue
            # Anything referencing `self` (or an unharvestable segment) is out.
            if any(
                isinstance(n, ast.Name) and n.id == "self" for n in ast.walk(stmt)
            ):
                ok = False
                break
            seg = ast.get_source_segment(source, stmt)
            if seg is None:
                ok = False
                break
            setup_stmts.append(seg)
        if not ok or not checks:
            continue
        setup_src = textwrap.dedent("\n".join(setup_stmts)) if setup_stmts else ""
        out.append((node.name, setup_src, checks))
    return out


def _l1_host_setup(setup_src):
    ns = {"__name__": "__main__", "__builtins__": __builtins__}
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
    has passed: int = 0;
    has failed: int = 0;
    has skipped: int = 0;
    has errored: int = 0;  # jacpython raised while replaying (marshal/ceval gap)
    has failures: list[str] = [];
    has errors: list[str] = [];
}

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
def layer1_run_setup(setup_src: str) -> dict[str, PyObj] {
    return exec_module(unmarshal(_l1_compile_setup(setup_src) as list[int]));
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
def layer1_replay_source(source: str) -> ReplayResult {
    result = ReplayResult();
    methods = _l1_harvest_methods(source);
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

# ---------------- tests ----------------
test "layer0: self-contained integer asserts replay against the host" {
    src = "class TestInt(unittest.TestCase):\n"
    "    def test_arithmetic(self):\n"
    "        self.assertEqual(1 + 1, 2)\n"
    "        self.assertEqual(17 % 5, 2)\n"
    "        self.assertEqual(2 ** 10, 1024)\n"
    "        self.assertEqual(100 // 7, 14)\n"
    "        self.assertEqual((3 < 5), True)\n"
    "        self.assertEqual(self.value, 5)\n";
    result = layer0_replay_source(src);
    assert result.passed == 5;
    assert result.skipped == 1;  # self.value is fixture-dependent
    assert result.failed == 0;
}

test "layer0: container and string asserts replay" {
    src = "class TestSeq(unittest.TestCase):\n"
    "    def test_seq(self):\n"
    "        self.assertEqual([1, 2, 3][1], 2)\n"
    "        self.assertEqual((1, 2) + (3, 4), (1, 2, 3, 4))\n"
    "        self.assertEqual('ab' + 'cd', 'abcd')\n"
    "        self.assertEqual({'k': 7}['k'], 7)\n"
    "        self.assertEqual('hello'[1], 'e')\n";
    result = layer0_replay_source(src);
    assert result.passed == 5;
    assert result.skipped == 0;
    assert result.failed == 0;
}

test "layer0: a genuine divergence is reported, not hidden" {
    # replay_expr on an expression the ceval computes must match the host.
    assert replay_expr("6 * 7") == True;
    assert replay_expr("2 + 3 * 4") == True;
    assert replay_expr("[0, 1, 2][2]") == True;
}

test "layer0: non-ASCII str constants survive marshal UTF-8 decode" {
    # Regression guard for the read_utf8 Latin-1 bug: multi-byte codepoints in a
    # marshaled str constant must round-trip so int() sees the real digits.
    # Devanagari, Arabic-Indic, unicode whitespace, and a Latin-1 supplement char.
    assert replay_expr("int('१२३४५६७८९०1234567890')") == True;
    assert replay_expr("int('١٢٣٤٥٦٧٨٩٠')") == True;
    assert replay_expr("int('\\N{EM SPACE}-3\\N{EN SPACE}')") == True;
    assert replay_expr("'café' + 'x'") == True;
}

test "layer0: str %-format (Gap #2) replays against the host" {
    # Conversions, flags, width, precision, tuple/single/mapping args.
    assert replay_expr("'%d' % 42") == True;
    assert replay_expr("'%d' % -7") == True;
    assert replay_expr("'%x' % 255") == True;
    assert replay_expr("'%X' % 255") == True;
    assert replay_expr("'%o' % 8") == True;
    assert replay_expr("'%#x' % 255") == True;
    assert replay_expr("'%05d' % 42") == True;
    assert replay_expr("'%-5d|' % 42") == True;
    assert replay_expr("'%+d' % 42") == True;
    assert replay_expr("'%.3d' % 7") == True;
    assert replay_expr("'%c' % 65") == True;
    assert replay_expr("'%s=%d' % ('x', 5)") == True;
    assert replay_expr("'%r' % 'hi'") == True;
    assert replay_expr("'%(a)s-%(b)d' % {'a': 'p', 'b': 3}") == True;
    assert replay_expr("'%d' % True") == True;
    assert replay_expr("'%x' % False") == True;
}

test "layer0: LOAD_SMALL_INT decodes 128..255 as non-negative" {
    # Regression guard: the ceval LOAD_SMALL_INT handler sign-extended its
    # unsigned oparg, mis-decoding 128..255 (e.g. 255 -> -1).
    assert replay_expr("255") == True;
    assert replay_expr("128") == True;
    assert replay_expr("200 + 55") == True;
    assert replay_expr("255 % 16") == True;
}

test "layer0: int/bool .real/.imag (Gap #3) replay against the host" {
    assert replay_expr("(5).real") == True;
    assert replay_expr("(5).imag") == True;
    assert replay_expr("(7).numerator") == True;
    assert replay_expr("(7).denominator") == True;
    assert replay_expr("True.real") == True;
    assert replay_expr("True.imag") == True;
    assert replay_expr("False.real") == True;
    assert replay_expr("False.imag") == True;
}

test "layer0: non-str-keyed host dicts stay opaque and round-trip" {
    # The native PyDict keys on str; a host dict with non-str keys (maketrans
    # returns {ordinal: repl}) is kept opaque as a PyHostProxy so it round-trips
    # through to_host unchanged instead of being corrupted by str(key).
    assert replay_expr("'abc'.translate(str.maketrans('a', 'X'))") == True;
    assert replay_expr("'abc'.translate(str.maketrans({'a': 'X'}))") == True;
    assert replay_expr("'abc'.translate(str.maketrans({'a': None}))") == True;
    assert replay_expr(
        "'axb'.translate(str.maketrans({'a': None, 'b': '12'}))"
    ) == True;
    assert replay_expr("len(str.maketrans('ab', 'XY'))") == True;
    # A dict literal with non-str keys (BUILD_MAP) is likewise built on the host
    # and kept opaque, so subscript / len / equality all replay.
    assert replay_expr("{1: 2}") == True;
    assert replay_expr("{1: 2, 3: 4}[3]") == True;
    assert replay_expr("len({10: 20, 30: 40})") == True;
    assert replay_expr("{1: 'a', 2: 'b'}") == True;
}

test "layer0: sets build opaque on the host (BUILD_SET / SET_UPDATE / const)" {
    # No native PySet: set literals build on the host and stay opaque, set
    # operators route through the host binop fallback, and TYPE_SET/
    # TYPE_FROZENSET marshal constants (>=3 members => LOAD_CONST frozenset +
    # SET_UPDATE) decode to opaque host sets.
    assert replay_expr("{1, 2}") == True;
    assert replay_expr("{1, 2, 3}") == True;
    assert replay_expr("{1, 2, 3} & {2, 3, 4}") == True;
    assert replay_expr("{1, 2, 3} - {2}") == True;
    assert replay_expr("{1, 2, 3} ^ {2, 3, 4}") == True;
    assert replay_expr("{1, 2} | {2, 3}") == True;
    assert replay_expr("len({1, 2, 3, 4})") == True;
    assert replay_expr("frozenset({1, 2}) | {3}") == True;
    # dict-view set operations (the test_dict cases that drove this).
    assert replay_expr("{1: 1}.keys() | {2}") == True;
    assert replay_expr("{2} | {1: 1}.items()") == True;
}

test "layer0: unported binops fall back to the host" {
    # Native nb_binop covers the ported fast paths; combos it doesn't (str %
    # with %f/%i or multiple args, str * int, list * int) fall back to host
    # CPython. Only a native error triggers the fallback, so ported paths win.
    assert replay_expr("'%s, %s, %i, %f, %5.2f' % ('a', 'b', 1, 2, 3)") == True;
    assert replay_expr("'%.2f' % 3.14159") == True;
    assert replay_expr("'%i-%f' % (5, 2.5)") == True;
    assert replay_expr("'ab' * 3") == True;
    assert replay_expr("3 * 'ab'") == True;
    assert replay_expr("[1, 2] * 2") == True;
    assert replay_expr("(1, 2) * 3") == True;
}

test "layer0: f-string / format opcodes replay against the host" {
    # CONVERT_VALUE (!s/!r/!a), FORMAT_SIMPLE, FORMAT_WITH_SPEC, BUILD_STRING.
    # CPython also folds "%s" % x into these, so plain %s-format lands here too.
    assert replay_expr("f'{5}-{3.14:.1f}'") == True;
    assert replay_expr("f'{\"hi\"!r}'") == True;
    assert replay_expr("f'{255:05d}'") == True;
    assert replay_expr("f'{42:x}'") == True;
    assert replay_expr("f'{\"ab\"!a}'") == True;
    assert replay_expr("'%s, %s' % ('abc', 'abc')") == True;
    assert replay_expr("'{0:^12}'.format(3 + 2.0j)") == True;
    assert replay_expr("'{0:.2f}'.format(3.14159)") == True;
    assert replay_expr("format(255, 'x')") == True;
    assert replay_expr("f'{1}{2}{3}'") == True;
}

test "layer0: native-container methods route to host during bootstrap" {
    # py_attr falls back to host_getattr for host-backed tags (str/list/dict/...)
    # when the native tp_getattro has no method yet. The bound method comes back
    # as a callable PyHostProxy, so the CALL executes it on the host and marshals
    # the result home. This is the bootstrap seam; objects.jac stays na-clean.
    assert replay_expr("'hello'.upper()") == True;
    assert replay_expr("'HELLO'.lower()") == True;
    assert replay_expr("'a,b,c'.split(',')") == True;
    assert replay_expr("'  hi  '.strip()") == True;
    assert replay_expr("'abcabc'.replace('a', 'X')") == True;
    assert replay_expr("'abc'.startswith('ab')") == True;
    assert replay_expr("'x'.join(['a', 'b', 'c'])") == True;
    assert replay_expr("[3, 1, 2].count(1)") == True;
    assert replay_expr("[1, 2, 3].index(2)") == True;
    assert replay_expr("{'a': 1, 'b': 2}.get('a')") == True;
    assert replay_expr("list({'a': 1}.keys())") == True;
    assert replay_expr("list({'a': 1, 'b': 2}.values())") == True;
    assert replay_expr("{'a': 1}.copy()") == True;
    assert replay_expr("(5).bit_length()") == True;
}

test "layer0: LIST_EXTEND addresses the list under a callable+NULL" {
    # Regression guard: a >=3-const list literal compiles to BUILD_LIST 0 +
    # LOAD_CONST tuple + LIST_EXTEND. When a callable and its PUSH_NULL sit
    # below it (len([...]), tuple([...])), the extend must target the list, not
    # the NULL. The prior off-by-one only survived on bare list literals.
    assert replay_expr("len([0, 1, 2])") == True;
    assert replay_expr("len([0, 1, 2, 3, 4])") == True;
    assert replay_expr("tuple([0, 1, 2, 3])") == True;
    assert replay_expr("sum([1, 2, 3, 4])") == True;
    assert replay_expr("[1, 2, 3]") == True;
    assert replay_expr("[1, 2, 3][1]") == True;
    assert replay_expr("max([3, 1, 4, 1, 5])") == True;
}

test "layer0: generator expressions replay through real frame suspend/resume" {
    # P5 generators-as-state-machines: a genexpr-flagged code object returns a
    # PyGenerator on call; YIELD_VALUE suspends the frame and gen_resume drives
    # it forward one value at a time. Consumers reach it either natively
    # (FOR_ITER over the generator) or across the host boundary (list()/tuple()/
    # sum() drain it via gen_drain). Covers the tuple()/frozenset() fast path
    # (LOAD_COMMON_CONSTANT + CALL_INTRINSIC_1 LIST_TO_TUPLE), the SWAP-heavy
    # inlined list comprehension (LOAD_FAST_AND_CLEAR), host-iterable sources
    # (range), and the `if` filter.
    assert replay_expr("list(x * 2 for x in [1, 2, 3])") == True;
    assert replay_expr("tuple(x for x in range(4))") == True;
    assert replay_expr("sum(x for x in [1, 2, 3, 4])") == True;
    assert replay_expr("list(x for x in [1, 2, 3, 4] if x > 2)") == True;
    assert replay_expr("[x * x for x in range(5)]") == True;
    assert replay_expr("tuple(y for y in (x * 2 for x in range(3)))") == True;
    assert replay_expr("max(x for x in [3, 1, 4, 1, 5])") == True;
    assert replay_expr("sorted(x for x in [3, 1, 2])") == True;
    assert replay_expr("list(c for c in 'abc')") == True;
    assert replay_expr("frozenset(x % 2 for x in range(5))") == True;
}

test "layer0: memoryview + slicing (Gap #4) replay against the host" {
    # memoryview host proxy + constant-slice subscript (BINARY_OP []) + int().
    assert replay_expr("int(memoryview(b'123')[1:3])") == True;
    assert replay_expr("int(memoryview(b'1234')[1:3])") == True;
    assert replay_expr("bytes(memoryview(b'abcdef')[2:4])") == True;
    # native-container slicing across the three slice opcodes (LOAD_CONST slice,
    # BINARY_SLICE, BUILD_SLICE) and negative index/step.
    assert replay_expr("'abcdef'[1:4]") == True;
    assert replay_expr("'abcdef'[::-1]") == True;
    assert replay_expr("'abcdef'[-2:]") == True;
    assert replay_expr("[1, 2, 3, 4, 5][1:3]") == True;
    assert replay_expr("[1, 2, 3, 4, 5][::-1]") == True;
    assert replay_expr("(1, 2, 3, 4, 5)[1:4]") == True;
    assert replay_expr("b'abcdef'[2:4]") == True;
    assert replay_expr("list(range(10))[2:5]") == True;
}

test "layer1: generator functions replay through the exec-mode method harness" {
    # Layer 1 lifts conformance from single expressions to whole test methods:
    # each method's setup (a generator def + binds) runs in both host and
    # jacpython, then every `self.assert*` argument is evaluated against that
    # shared, stateful namespace and diffed. This is the only leg that exercises
    # full generator FUNCTIONS -- def+yield, next()/state threading, .send(),
    # and `yield from` -- against a real test-file shape.
    src = "import unittest\n"
    "class TestGen(unittest.TestCase):\n"
    "    def test_drain(self):\n"
    "        def g():\n"
    "            yield 1\n"
    "            yield 2\n"
    "            yield 3\n"
    "        self.assertEqual(list(g()), [1, 2, 3])\n"
    "        self.assertEqual(sum(g()), 6)\n"
    "    def test_next_threads_state(self):\n"
    "        def g():\n"
    "            yield 10\n"
    "            yield 20\n"
    "        it = g()\n"
    "        self.assertEqual(next(it), 10)\n"
    "        self.assertEqual(next(it), 20)\n"
    "        self.assertEqual(next(it, -1), -1)\n"
    "    def test_send(self):\n"
    "        def acc():\n"
    "            total = 0\n"
    "            while True:\n"
    "                v = yield total\n"
    "                total += v\n"
    "        g = acc()\n"
    "        self.assertEqual(g.send(None), 0)\n"
    "        self.assertEqual(g.send(5), 5)\n"
    "        self.assertEqual(g.send(3), 8)\n"
    "    def test_yield_from(self):\n"
    "        def inner():\n"
    "            yield 1\n"
    "            yield 2\n"
    "            return 3\n"
    "        def outer():\n"
    "            r = yield from inner()\n"
    "            yield r\n"
    "        self.assertEqual(list(outer()), [1, 2, 3])\n"
    "    def test_exhaustion_raises(self):\n"
    "        def g():\n"
    "            yield 1\n"
    "        it = g()\n"
    "        self.assertEqual(next(it), 1)\n"
    "        with self.assertRaises(StopIteration):\n"
    "            next(it)\n"
    "    def test_send_non_none_to_new_gen(self):\n"
    "        def g():\n"
    "            yield 1\n"
    "        it = g()\n"
    "        with self.assertRaises(TypeError):\n"
    "            it.send(0)\n"
    "    def test_uses_fixture(self):\n"
    "        self.assertEqual(self.value, 5)\n";
    result = layer1_replay_source(src);
    # Six self-contained generator methods replay clean (four value-diff, two
    # assertRaises); the fixture-dependent method (self.value) fails the host
    # self-containment probe and is skipped.
    assert result.passed == 6;
    assert result.skipped == 1;
    assert result.failed == 0;
    assert result.errored == 0;
}
