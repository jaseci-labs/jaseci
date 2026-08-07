"""Native exponentiation (`**`) parity tests.

Regression coverage for the power-lowering seam in
`na_ir_gen_pass.impl/math.impl.jac` and the `int ** int` type contract in
`compiler/type_system/operations.jac`. Each case compiles a fixture that
previously lowered to invalid/unsound IR and asserts the JIT result against
CPython semantics: literal & dynamic exponents, builtin `pow`, `**=`, the
fixed-width i32 kernel, float power, and the zero-base ZeroDivisionError.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_force_opts }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

"""Compile a .jac fixture and return the JIT engine."""
def compile_native(fixture: str) -> tuple[ExecutionEngine, uni.Module] {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, ir);
}

"""Get a ctypes-callable function from the JIT engine."""
def get_func(eng: object, name: str, restype: type | None, *argtypes: type) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

# int ** non-negative literal stays int and matches CPython.
test "pow: int ** non-negative literal is int" {
    (eng, _) = compile_native("pow_semantics.jac");
    get_func(eng, "jac_entry", None)();
    pos = get_func(eng, "ipow_pos", ctypes.c_int64);
    assert pos() == 8;
    sq = get_func(eng, "ipow_sq", ctypes.c_int64);
    assert sq() == 49;
    one = get_func(eng, "ipow_one", ctypes.c_int64);
    assert one() == 1;
}

# int ** negative literal is float (Python: 4 ** -2 == 0.0625).
test "pow: int ** negative literal is float" {
    (eng, _) = compile_native("pow_semantics.jac");
    get_func(eng, "jac_entry", None)();
    neg = get_func(eng, "ipow_neg", ctypes.c_double);
    assert neg() == 0.0625;
}

# int ** dynamic exponent is float and follows the runtime sign of exp.
test "pow: int ** dynamic exponent follows runtime sign" {
    (eng, _) = compile_native("pow_semantics.jac");
    get_func(eng, "jac_entry", None)();
    dyn = get_func(
        eng, "ipow_dyn", ctypes.c_double, ctypes.c_int64, ctypes.c_int64
    );
    assert dyn(2, 3) == 8.0;
    assert dyn(2, -1) == 0.5;
    assert dyn(3, 0) == 1.0;
}

# i32 ** i32 exercises the fixed-width kernel without an i64 widen.
test "pow: fixed-width i32 kernel matches at true width" {
    (eng, _) = compile_native("pow_semantics.jac");
    get_func(eng, "jac_entry", None)();
    d = get_func(
        eng, "ipow_i32_dyn", ctypes.c_double, ctypes.c_int32, ctypes.c_int32
    );
    assert d(2, 3) == 8.0;
    assert d(5, 2) == 25.0;
}

# float ** float and builtin pow(float, float) lower to libm pow.
test "pow: float operands use libm pow" {
    (eng, _) = compile_native("pow_semantics.jac");
    get_func(eng, "jac_entry", None)();
    fp = get_func(
        eng, "fpow", ctypes.c_double, ctypes.c_double, ctypes.c_double
    );
    assert fp(2.0, 3.0) == 8.0;
    assert fp(9.0, 0.5) == 3.0;
    bp = get_func(
        eng, "bpow", ctypes.c_double, ctypes.c_double, ctypes.c_double
    );
    assert bp(2.0, 10.0) == 1024.0;
}

# `**=` lowers through the shared scalar-aug helper for both int and float.
test "pow: augmented assignment (**=) for int and float" {
    (eng, _) = compile_native("pow_semantics.jac");
    get_func(eng, "jac_entry", None)();
    ia = get_func(eng, "ipow_aug", ctypes.c_int64, ctypes.c_int64);
    assert ia(2) == 8;
    assert ia(3) == 27;
    fa = get_func(eng, "fpow_aug", ctypes.c_double, ctypes.c_double);
    assert fa(3.0) == 9.0;
    assert fa(5.0) == 25.0;
}

# 0 ** negative raises ZeroDivisionError (literal and dynamic exponent).
test "pow: zero base with negative exponent raises ZeroDivisionError" {
    (eng, _) = compile_native("pow_semantics.jac");
    get_func(eng, "jac_entry", None)();
    lit = get_func(eng, "ipow_zero_base_neg", ctypes.c_int64);
    assert lit() == 1;
    dyn = get_func(eng, "ipow_zero_base_dyn", ctypes.c_int64);
    assert dyn() == 1;
}
