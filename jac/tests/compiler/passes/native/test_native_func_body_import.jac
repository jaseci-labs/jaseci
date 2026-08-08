"""Function-body `import from` statements must lower on the native backend.

Roadmap item N8c of jaseci-labs/jac#7967: module-level imports lower, but an
import written inside a function body raised "Native lowering failed for
statement 'Import'" and then a cascade of "Native lowering failed for ..." for
every name the import bound. The body-scoped spelling is the house idiom for
lazy and conditional imports, so it must lower rather than merely fail
politely.

Results are compared against the sv/bytecode run of the same fixture.
"""

import ctypes;
import importlib;
import os;
import sys;
import from tests.support { TESTS_DIR, native_force_opts }
import from jaclang.jac0core.program { JacProgram }
import jaclang.jac0core.unitree as uni;
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

"""Import the fixture on the sv/bytecode pathway and hand back its module."""
def sv_module(stem: str) -> object {
    added = False;
    if FIXTURES not in sys.path {
        sys.path.insert(0, FIXTURES);
        added = True;
    }
    try {
        sys.modules.pop(stem, None);
        return importlib.import_module(stem);
    } finally {
        if added {
            sys.path.remove(FIXTURES);
        }
    }
}

test "function-body imports lower and agree with sv" {
    (eng, _) = compile_native("func_body_import.jac");
    sv = sv_module("func_body_import");
    cases = [
        "floor_half",
        "ceil_third",
        "conditional_import",
        "sibling_import",
        "sibling_type_import",
        "method_import"
    ];
    for name in cases {
        addr = eng.get_function_address(name);
        assert addr != 0 , f"'{name}' not found in the JIT engine";
        na_fn = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr);
        sv_fn = getattr(sv, name);
        for arg in [0, 9, 17] {
            assert na_fn(arg) == sv_fn(arg) , (
                f"{name}({arg}): native {na_fn(arg)} != sv {sv_fn(arg)}"
            );
        }
    }
}
