import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import jaclang.compiler.frontend.unitree as uni;

obj NaIRGenRegion(NaIRGenState) {
    def _register_region_kernel -> None;
    def _region_kernel_fn(name: str) -> ir.Function;
    def _emit_region_tls_slot -> None;
    def _region_i64(val: ir.Value, name: str = "rgn.i64") -> ir.Value;
    def _region_ptr(val: ir.Value, name: str = "rgn.p") -> ir.Value;
    def _region_new_handle -> ir.Value;
    def _region_current -> ir.Value;
    def _region_of_value(val: ir.Value) -> ir.Value;
    def _region_enter(hdl: ir.Value) -> None;
    def _region_leave -> None;
    def _emit_region_leaves(count: int) -> None;
    def _region_depth -> ir.Value;
    def _region_unwind(depth: ir.Value) -> None;
    def _region_alloc_object(
        hdl: ir.Value, size: ir.Value, type_name: (str | None)
    ) -> ir.Value;

    def _region_partition(hdl: ir.Value) -> ir.Value;
    def _region_owns(ptr: ir.Value) -> ir.Value;
    def _emit_region_handle_drop(alloca: ir.Value, var_name: str) -> None;
    def _register_region_handle_var(nd: uni.Assignment, var_name: str) -> None;
    def _lower_partition_unpack(nd: uni.Assignment) -> bool;
    def _emit_struct_drop_fields_fn(type_name: str) -> (ir.Function | None);
}
