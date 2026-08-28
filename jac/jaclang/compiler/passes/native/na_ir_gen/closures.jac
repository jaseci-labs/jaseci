import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.diagnostics { E5092 }
import jaclang.jac0core.unitree as uni;

obj NaIRGenClosures(NaIRGenState) {
    def _scan_closure_escapes(nd: uni.UniNode, body: (list | tuple)) -> None;
    def _closure_sig_struct(fnty: ir.FunctionType) -> tuple;
    def _closure_struct_of(val_type: ir.Type) -> (str | None);
    def _closure_cell_struct(slot_type: ir.Type) -> str;
    def _emit_closure_cell(var_name: str, slot_type: ir.Type) -> ir.Value;
    def _emit_closure_thunk(
        target_fn: ir.Function, declared_count: int, cap_info: list
    ) -> ir.Function;

    def _emit_closure_pair(
        target_fn: ir.Function, declared_fnty: ir.FunctionType, cap_info: list
    ) -> (ir.Value | None);

    def _emit_closure_value(var_name: str, nd: uni.UniNode) -> (ir.Value | None);
    def _emit_closure_escape_error(var_name: str, nd: uni.UniNode) -> None;
    def _codegen_closure_call(
        nd: uni.FuncCall, clos_val: ir.Value, struct_name: str
    ) -> (ir.Value | None);
    def _emit_callable_trampoline(real_fn: ir.Function, bound: bool) -> ir.Function;
    def _make_bound_callable(real_fn: ir.Function, recv: ir.Value) -> ir.Value;
    def _emit_bare_callable_call(nd: uni.FuncCall, pair: ir.Value) -> ir.Value;
    def _codegen_method_reference_value(
        nd: uni.UniNode, target_name: (str | None), right_name: (str | None)
    ) -> (ir.Value | None);
}
