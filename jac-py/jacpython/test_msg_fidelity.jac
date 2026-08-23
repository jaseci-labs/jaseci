# Message-fidelity regression pins (TODO.md item 9 sweep).
#
# Each fixture compiles the same source the host CPython would run, executes it
# on ceval, and pins the byte-exact error text reported against the system
# python3 oracle. Covers native method-descriptor arg errors (slice qualname
# forms) and the lifted module leaves (itertools, deque, array, csv, bytes).
#
# Companion to test_ordering_typeerror_messages.jac (which owns the binop
# surface); kept separate so both files can evolve append-only.
#
# - struct.error / json.JSONDecodeError / csv.Error texts: catch-and-inspect on
#   those host-proxy exceptions crashes in ceval.jac's host_exception path
#   (builtins lookup by bare type name), so no stable text can be pinned until
#   that lane fixes exception reconstruction.

import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }
import from objects { PyObj, PyStr, is_error }

# Exec `src` on ceval with fresh module globals; fails the test on raise.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<msg_fidelity>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_str(expr: str) -> str {
    ns = vm_exec(
        "try:\n"
        "    r = " + expr + "\n"
        "except BaseException as e:\n"
        "    r = type(e).__name__ + ': ' + str(e)\n"
    );
    return to_host(ns["r"]) as str;
}

def vm_str_src(src: str) -> str {
    ns = vm_exec(src);
    return to_host(ns["r"]) as str;
}

# ---- item 9: owner-prefixed method-descriptor qualnames --------------------

test "slice.indices zero args pins owner-qualified message" {
    assert vm_str("repr(slice(1, 2).indices())")
        == "TypeError: slice.indices() takes exactly one argument (0 given)";
}

test "slice.indices too many args pins given-count" {
    assert vm_str("repr(slice(1, 2).indices(1, 2, 3, 4))")
        == "TypeError: slice.indices() takes exactly one argument (4 given)";
}

test "tuple.count zero args pins owner-qualified message" {
    assert vm_str("repr((1, 2).count())")
        == "TypeError: tuple.count() takes exactly one argument (0 given)";
}

test "float.fromhex zero args pins owner-qualified message" {
    assert vm_str("repr(float.fromhex())")
        == "TypeError: float.fromhex() takes exactly one argument (0 given)";
}

test "str.split three args pins at-most form" {
    assert vm_str("repr('ab'.split(None, 1, 2))")
        == "TypeError: split() takes at most 2 arguments (3 given)";
}

# ---- lifted module leaves --------------------------------------------------

test "itertools.batched zero n pins minimum wording" {
    assert vm_str("list(__import__('itertools').batched('ab', 0))")
        == "ValueError: n must be at least one";
}

test "deque.remove missing value pins membership wording" {
    assert vm_str_src(
        "from collections import deque\n"
        "try:\n"
        "    r = deque([1]).remove(9)\n"
        "except BaseException as e:\n"
        "    r = type(e).__name__ + ': ' + str(e)\n"
    ) == "ValueError: deque.remove(x): x not in deque";
}

test "deque.pop empty pins empty wording" {
    assert vm_str_src(
        "from collections import deque\n"
        "try:\n"
        "    r = deque().pop()\n"
        "except BaseException as e:\n"
        "    r = type(e).__name__ + ': ' + str(e)\n"
    ) == "IndexError: pop from an empty deque";
}

test "array.insert non-int pins interpreted-as-integer form" {
    assert vm_str_src(
        "from array import array\n"
        "try:\n"
        "    r = array('i').insert('x', 1)\n"
        "except BaseException as e:\n"
        "    r = type(e).__name__ + ': ' + str(e)\n"
    ) == "TypeError: 'str' object cannot be interpreted as an integer";
}

test "csv.reader zero args pins at-least-got form" {
    assert vm_str("repr(__import__('csv').reader())")
        == "TypeError: reader expected at least 1 argument, got 0";
}

test "csv.writer zero args pins at-least-got form" {
    assert vm_str("repr(__import__('csv').writer())")
        == "TypeError: writer expected at least 1 argument, got 0";
}

test "bytes.count str needle pins bytes-likes wording" {
    assert vm_str("b'ab'.count('a')")
        == "TypeError: argument should be integer or bytes-like object, not 'str'";
}
