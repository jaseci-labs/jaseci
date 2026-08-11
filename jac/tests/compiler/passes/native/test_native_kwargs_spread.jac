"""`**` spread lowers into a callee's `**kwargs` sink; not onto named params.

Native already lowered the declaration half of kwargs: a callee with a
`**kwargs` sink gets a trailing dict slot in its LLVM signature, and
`_codegen_kwargs_dict` collects a call site's leftover *literal* keywords
into that dict at compile time. What it rejected outright was the `**`
spread, so every forwarding wrapper in the compiler's own diagnostics chain
(`emit` -> `format_message`) sat behind an E5090.

A spread into a sink needs no runtime name-to-slot binding: the keys land in
the sink dict whatever they are. So the spread operand is now merged into the
sink with an index loop over the source dict, reusing the same len/get_key/
get_val primitives dict iteration already uses.

A spread onto *declared named parameters* is the genuinely hard case -- it
would need runtime keyword binding -- and stays rejected.

Refs #8039
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_force_opts }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

"""Compile a .jac fixture natively and return the JIT engine."""
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
    return ctypes.CFUNCTYPE(restype, *argtypes)(addr);
}

"""Run a snippet through the front-end check schedule with the native
capability authority on -- the `jac check` path that surfaces E5090."""
def check_na_inline(label: str, code: str) -> JacProgram {
    prog = JacProgram();
    prog.compile(
        file_path=os.path.join(FIXTURES, f"_kwspread_{label}.jac"),
        use_str=code,
        options=CompileOptions(
            type_check=True,
            no_cgen=True,
            force_codespace="native",
            force_target_program=True
        )
    );
    return prog;
}

"""Return True if the program emitted at least one alert with the given code."""
def has_error_code(prog: JacProgram, code: str) -> bool {
    for alrt in prog.errors_had {
        if alrt.code is not None and alrt.code.code == code {
            return True;
        }
    }
    return False;
}

"""Format errors for assertion messages."""
def fmt_errors(prog: JacProgram) -> str {
    return str([str(e) for e in prog.errors_had]);
}

# sink() encodes both arity and identity: base + 100*len(kw), then +1000 / +2000
# / +4000 for keys "p" / "q" / "r". A count-only check would pass even if the
# merge inserted the wrong keys, so every expectation below pins the key set.

test "literal keywords still fill the sink (no regression)" {
    (eng, _) = compile_native("kwargs_spread.jac");
    f = get_func(eng, "call_literal_kwargs", ctypes.c_int64, ctypes.c_int64);
    # p, q -> 10 + 200 + 1000 + 2000
    assert f(10) == 3210 , f"got {f(10)}";
}

test "a forwarded **kwargs reaches the inner sink with its keys intact" {
    (eng, _) = compile_native("kwargs_spread.jac");
    f = get_func(eng, "call_forwarded", ctypes.c_int64, ctypes.c_int64);
    # p, r -> 10 + 200 + 1000 + 4000
    assert f(10) == 5210 , f"got {f(10)}";
}

test "a plain dict spreads into the sink" {
    (eng, _) = compile_native("kwargs_spread.jac");
    f = get_func(eng, "call_spread_dict", ctypes.c_int64, ctypes.c_int64);
    # p, q, r -> 10 + 300 + 1000 + 2000 + 4000
    assert f(10) == 7310 , f"got {f(10)}";
}

test "a spread merges with literal keywords at the same call site" {
    (eng, _) = compile_native("kwargs_spread.jac");
    f = get_func(eng, "call_spread_plus_literal", ctypes.c_int64, ctypes.c_int64);
    # q literal + r spread -> 10 + 200 + 2000 + 4000
    assert f(10) == 6210 , f"got {f(10)}";
}

test "spreading an empty dict yields an empty sink" {
    (eng, _) = compile_native("kwargs_spread.jac");
    f = get_func(eng, "call_spread_empty", ctypes.c_int64, ctypes.c_int64);
    assert f(10) == 10 , f"got {f(10)}";
}

test "the spread fixture compiles with no native diagnostics" {
    prog = JacProgram();
    prog.compile(
        file_path=str(os.path.join(FIXTURES, "kwargs_spread.jac")),
        options=native_force_opts()
    );
    assert not prog.errors_had , fmt_errors(prog);
}

# ─────────────────────────────────────────────────────────────────────
# The genuinely dynamic case stays rejected
# ─────────────────────────────────────────────────────────────────────

test "guardrail: a spread onto declared named params is still rejected" {
    prog = check_na_inline(
        "onto_named",
        "def sink(a: int, b: int) -> int { return a + b; }\n"
        "def use -> int {\n"
        "    d: dict[str, int] = {\"b\": 2};\n"
        "    return sink(1, **d);\n"
        "}\n"
    );
    assert has_error_code(prog, "E5090") , (
        f"expected E5090 for a spread with no sink, got {fmt_errors(prog)}"
    );
}

test "a spread into a sink no longer trips the capability gate" {
    prog = check_na_inline(
        "into_sink",
        "def sink(a: int, **kw: int) -> int { return a + len(kw); }\n"
        "def use -> int {\n"
        "    d: dict[str, int] = {\"b\": 2};\n"
        "    return sink(1, **d);\n"
        "}\n"
    );
    assert not prog.errors_had , fmt_errors(prog);
}
