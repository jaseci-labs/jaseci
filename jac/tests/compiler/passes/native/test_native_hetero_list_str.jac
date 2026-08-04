"""A heap string stored into a heterogeneous list survives read-back.

A mixed-type list (e.g. `[int, str]`) lowers to a raw-integer backing store, so a
pointer element is boxed as an integer the container does not reference-count.
The regression: the source string was freed at its last use while the escaping
list still held it, so the element became a dangling pointer overwritten by the
next allocation -- the string read back as garbage/empty. These tests store a
heap string into a mixed list via every affected path (index assignment of a
local, slices directly in a literal, a string argument, and a churn loop that
forces backing-store growth) and assert it reads back intact.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_force_opts }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     ),
     FIXTURE = "hetero_list_str.jac";


def _compile(fixture: str) -> object {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine for {fixture}";
    return eng;
}


def _get(eng: object, name: str, restype: type | None, *argtypes: type) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(restype, *argtypes)(addr);
}


test "heap string stored in a heterogeneous list by index assignment survives" {
    eng = _compile(FIXTURE);
    via_local = _get(eng, "via_local", ctypes.c_char_p, ctypes.c_char_p);
    # r = [19, ""]; r[1] = s[5:12]; return r[1]  -> the sliced substring intact
    assert via_local(b"u-ca=iso8601").decode("utf-8") == "iso8601";
    assert via_local(b"12345abcdefg").decode("utf-8") == "abcdefg";
}


test "heap slices placed directly in a mixed list literal survive" {
    eng = _compile(FIXTURE);
    a = _get(eng, "via_literal_a", ctypes.c_char_p, ctypes.c_char_p);
    b = _get(eng, "via_literal_b", ctypes.c_char_p, ctypes.c_char_p);
    # r = [99, s[0:3], s[5:12]]
    assert a(b"u-ca=iso8601").decode("utf-8") == "u-c";
    assert b(b"u-ca=iso8601").decode("utf-8") == "iso8601";
}


test "string passed as an argument and stored in a mixed list survives" {
    eng = _compile(FIXTURE);
    via_arg = _get(eng, "via_arg", ctypes.c_char_p, ctypes.c_int64, ctypes.c_char_p);
    assert via_arg(7, b"hello").decode("utf-8") == "hello";
    assert via_arg(0, b"").decode("utf-8") == "";
}


test "many heterogeneous lists in a loop stay consistent (no corruption)" {
    eng = _compile(FIXTURE);
    churn = _get(eng, "churn", ctypes.c_int64, ctypes.c_int64);
    # Each iter builds [i, "v" + str(i)] and sums len(list[1]). "v0".."v9" -> 2,
    # "v10".."v99" -> 3, "v100".."v999" -> 4. Sum over i in [0, 1000):
    #   10*2 + 90*3 + 900*4 = 20 + 270 + 3600 = 3890.
    assert churn(1000) == 3890;
    assert churn(0) == 0;
}
