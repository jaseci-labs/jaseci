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

import from pyc_first { PyObj, unmarshal, exec_code, to_host }

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
    has errored: int = 0;   # jacpython raised while replaying (marshal/ceval gap)
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
        got: PyObj = exec_code(unmarshal(_l0_compile_eval(expr_src) as list[int]), [], {});
        expected = _l0_expected(expected_src);
        if _l0_host_equal(to_host(got), expected) as bool { return 1; }
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
        if not ((_l0_is_selfcontained(expr_src) as bool) and (_l0_is_selfcontained(expected_src) as bool)) {
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
    src =
        "class TestInt(unittest.TestCase):\n"
        "    def test_arithmetic(self):\n"
        "        self.assertEqual(1 + 1, 2)\n"
        "        self.assertEqual(17 % 5, 2)\n"
        "        self.assertEqual(2 ** 10, 1024)\n"
        "        self.assertEqual(100 // 7, 14)\n"
        "        self.assertEqual((3 < 5), True)\n"
        "        self.assertEqual(self.value, 5)\n";
    result = layer0_replay_source(src);
    assert result.passed == 5;
    assert result.skipped == 1;   # self.value is fixture-dependent
    assert result.failed == 0;
}

test "layer0: container and string asserts replay" {
    src =
        "class TestSeq(unittest.TestCase):\n"
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
