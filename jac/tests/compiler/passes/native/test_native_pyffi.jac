"""Native jac calling the CPython C-API through `import from python` clib
externs, JIT path. This is the capability the sealed jac materializer
(compiler/native_materialize.jac) is built on: under the JIT the symbols
resolve from the host process image; sealed artifacts bind them via ELF lazy
PLT / Mach-O flat lookup. PYFUNCTYPE keeps the GIL held across the call,
which every CPython C-API entry requires."""

import ctypes;
import os;
import jaclang.jac0core.unitree as uni;
import from tests.support { TESTS_DIR, native_force_opts }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

test "cpython api reachable through dlsym raw pointers" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, "pyffi_probe.jac")),
        options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"compile errors: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , "no native engine";
    rt_addr = eng.get_function_address("roundtrip");
    assert rt_addr != 0;
    rt_fn = ctypes.PYFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(rt_addr);
    assert rt_fn(41) == 41;
    assert rt_fn(-7) == -7;
    assert rt_fn(1 << 40) == 1 << 40;
}
