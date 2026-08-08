"""Congruence tests for coercion routing at three native seams (N2).

`NaIRGenPass._coerce_type` implements optional wrapping and checked
unwrapping, but call arguments, call receivers, and tuple-unpack stores
did not route through it. Each test below writes the idiomatic jac that
those seams used to reject and asserts the native result equals the
result of the same fixture run through the sv/bytecode pathway.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_force_opts }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.runtime { JacRuntime }
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

"""Import the same fixture through the sv/bytecode pathway."""
def sv_module -> object {
    return JacRuntime.jac_import(
        target="coercion_routing", base_path=FIXTURES, override_name="cr_sv_mod"
    )[0];
}

test "call argument: a plain value wraps into an optional parameter" {
    (eng, _) = compile_native("coercion_routing.jac");
    sv = sv_module();
    f = get_func(eng, "arg_wrap", ctypes.c_int64, ctypes.c_int64);
    for n in [3, 0, -4] {
        assert f(n) == sv.arg_wrap(n) , (
            f"arg_wrap({n}): native {f(n)} != sv {sv.arg_wrap(n)}"
        );
    }
    assert f(3) == 13 , "base 10 + 3 through the int|None parameter";
}

test "call argument: an explicit None reaches an optional parameter" {
    (eng, _) = compile_native("coercion_routing.jac");
    sv = sv_module();
    f = get_func(eng, "arg_wrap_none", ctypes.c_int64);
    assert f() == sv.arg_wrap_none() , f"arg_wrap_none: {f()} != {sv.arg_wrap_none()}";
    assert f() == -1 , "None selects the None branch";
}

test "call argument: a narrowed optional unwraps into a plain parameter" {
    (eng, _) = compile_native("coercion_routing.jac");
    sv = sv_module();
    f = get_func(eng, "arg_unwrap", ctypes.c_int64, ctypes.c_int64);
    for n in [4, 0] {
        assert f(n) == sv.arg_unwrap(n) , (
            f"arg_unwrap({n}): native {f(n)} != sv {sv.arg_unwrap(n)}"
        );
    }
    assert f(4) == 18 , "base 10 + 4 * 2 after the unwrap";
    assert f(0) == -1 , "the None branch still wins";
}

test "call argument: a narrowed optional container unwraps for a method arg" {
    (eng, _) = compile_native("coercion_routing.jac");
    sv = sv_module();
    f = get_func(eng, "arg_unwrap_container", ctypes.c_int64, ctypes.c_int64);
    for flag in [1, 0] {
        assert f(flag) == sv.arg_unwrap_container(flag) , (
            f"arg_unwrap_container({flag}): native {f(flag)} != "
            f"sv {sv.arg_unwrap_container(flag)}"
        );
    }
    assert f(1) == 446 , "extend copies all three elements";
    assert f(0) == 1 , "the None guard returns the untouched length";
}

test "call receiver: an optional list receiver unwraps for append" {
    (eng, _) = compile_native("coercion_routing.jac");
    sv = sv_module();
    f = get_func(eng, "opt_list_receiver", ctypes.c_int64, ctypes.c_int64);
    for n in [2, 9] {
        assert f(n) == sv.opt_list_receiver(n) , (
            f"opt_list_receiver({n}): native {f(n)} != sv {sv.opt_list_receiver(n)}"
        );
    }
    assert f(2) == 212 , "two appends land: len 2, [1, 2]";
}

test "call receiver: a narrowed optional list receiver still takes both branches" {
    (eng, _) = compile_native("coercion_routing.jac");
    sv = sv_module();
    f = get_func(eng, "opt_list_receiver_guarded", ctypes.c_int64, ctypes.c_int64);
    for flag in [3, 0] {
        assert f(flag) == sv.opt_list_receiver_guarded(flag) , (
            f"opt_list_receiver_guarded({flag}): native {f(flag)} != "
            f"sv {sv.opt_list_receiver_guarded(flag)}"
        );
    }
    assert f(3) == 73 , "appends land on the narrowed receiver";
    assert f(0) == -1 , "the None guard still returns early";
}

test "unpack store: plain elements wrap into optional-typed targets" {
    (eng, _) = compile_native("coercion_routing.jac");
    sv = sv_module();
    f = get_func(eng, "unpack_wrap", ctypes.c_int64, ctypes.c_int64);
    for n in [3, 7] {
        assert f(n) == sv.unpack_wrap(n) , (
            f"unpack_wrap({n}): native {f(n)} != sv {sv.unpack_wrap(n)}"
        );
    }
    assert f(3) == 34 , "(a, b) = (3, 4) through int|None targets";
}

test "unpack store: optional elements unwrap into plain targets" {
    (eng, _) = compile_native("coercion_routing.jac");
    sv = sv_module();
    f = get_func(eng, "unpack_unwrap", ctypes.c_int64, ctypes.c_int64);
    for n in [5, 1] {
        assert f(n) == sv.unpack_unwrap(n) , (
            f"unpack_unwrap({n}): native {f(n)} != sv {sv.unpack_unwrap(n)}"
        );
    }
    assert f(5) == 56 , "(p, q) = (5, 6) after the unwrap";
}
