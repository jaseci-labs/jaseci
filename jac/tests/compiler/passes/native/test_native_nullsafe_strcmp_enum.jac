"""Native tests for null-safe string comparison and enum-class lowering (#7851).

Comparing a possibly-null `str` (an unset `str | None` field) against a string
literal used to dereference NULL inside `strcmp` and segfault; a null operand
now compares as if it were the empty string. Separately, an enum-class used as a
parameter or return type must lower to its backing integer instead of failing.
"""

import ctypes;
import os;
import from pathlib { Path }
import from jaclang.jac0core.program { JacProgram }
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

def compile_native(fixture: str) -> tuple[ExecutionEngine, uni.Module] {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, ir);
}

def get_func(eng: object, name: str, restype: type | None, *argtypes: type) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(restype, *argtypes)(addr);
}

test "null string compares as empty, not a segfault" {
    (eng, _) = compile_native("nullsafe_strcmp_enum.jac");
    # b.label is unset (None); comparing it must be safe.
    assert get_func(eng, "null_eq_empty", ctypes.c_int64)() == 1;
    assert get_func(eng, "null_ne_word", ctypes.c_int64)() == 0;
    # A set string still compares by value.
    assert get_func(eng, "set_then_eq", ctypes.c_int64)() == 1;
}

test "enum-class parameter and return type lower cleanly" {
    (eng, _) = compile_native("nullsafe_strcmp_enum.jac");
    flip = get_func(eng, "flip", ctypes.c_int64, ctypes.c_int64);
    assert flip(0) == 1;
    assert flip(1) == 0;
    mode_is_on = get_func(eng, "mode_is_on", ctypes.c_int64, ctypes.c_int64);
    assert mode_is_on(1) == 1;
    assert mode_is_on(0) == 0;
}
