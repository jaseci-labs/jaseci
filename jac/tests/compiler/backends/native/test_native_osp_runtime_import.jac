"""Explicit runtime imports share the kernel used by native walker dispatch."""

import ctypes;
import from tests.support { compile_native, get_func }
import from jaclang.compiler.frontend.codeinfo {
    OSP_KERNEL_REL,
    OSP_GRAPH_REL,
    kernel_unit_path,
    is_kernel_unit_path,
    native_module_key
}

test "explicit runtime imports use distinct source unit identities" {
    kernel = kernel_unit_path(OSP_KERNEL_REL);
    graph = kernel_unit_path(OSP_GRAPH_REL);
    assert is_kernel_unit_path(kernel);
    assert is_kernel_unit_path(graph);
    assert native_module_key(kernel) != native_module_key(graph);
    assert not is_kernel_unit_path("/checkout/osp_kernel.jac");
}

test "an imported walker operation acts on the active kernel" {
    (engine, _) = compile_native("osp_runtime_import.jac");
    probe = get_func(engine, "probe", ctypes.c_int64);
    assert probe() == 1;
}
