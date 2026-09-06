"""Explicit runtime imports share the kernel used by native walker dispatch."""

import ctypes;
import from tests.support { compile_native }

test "an imported walker operation acts on the active kernel" {
    (engine, _) = compile_native("osp_runtime_import.jac");
    address = engine.get_function_address("probe");
    assert address != 0;
    probe = ctypes.CFUNCTYPE(ctypes.c_int64)(address);
    assert probe() == 1;
}
