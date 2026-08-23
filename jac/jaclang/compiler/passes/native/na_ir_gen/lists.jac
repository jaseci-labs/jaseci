import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.diagnostics { E5092 }
import jaclang.jac0core.unitree as uni;
import os;

obj NaIRGenLists(NaIRGenState) {
    def _spec_from_list_slot_type(t: (ir.Type | None)) -> (str | None);
    def _reflavor_list(
        val: ir.Value, src_spec: str, dst_spec: str, src_elem_ty: any = None
    ) -> (ir.Value | None);

    def _cast_to_list_elem(
        b: any, val: ir.Value, elem_type: ir.Type, name: str
    ) -> ir.Value;

    def _list_elem_ready(
        val: ir.Value,
        expr: (uni.UniNode | None),
        spec: str,
        elem_llvm: ir.Type,
        loc: str
    ) -> tuple;

    def _emit_list_helpers(elem_type_name: str, elem_type: ir.Type) -> None;
    def _emit_aos_list_helpers(tname: str) -> ir.Type;
    def _codegen_list_val(nd: uni.ListVal) -> (ir.Value | None);
    def _codegen_index(
        target_val: ir.Value, index_val: ir.Value, elem_type_name: str
    ) -> (ir.Value | None);

    def _codegen_any_subscript(
        jacval: ir.Value, key_val: ir.Value, key_ty: any = None
    ) -> (ir.Value | None);

    def _codegen_any_len(jacval: ir.Value) -> ir.Value;
    def _codegen_index_set(
        target_val: ir.Value, index_val: ir.Value, value: ir.Value, elem_type_name: str
    ) -> None;
}
