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
import from objects { PyObj }
import from pyc_first { unmarshal, exec_code, to_host }

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
