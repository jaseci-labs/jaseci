import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.constant { Tokens as Tok }

obj NaIRGenRepr(NaIRGenState) {
    def _emit_container_repr(val: ir.Value, t: any) -> (ir.Value | None);
    def _repr_fn_for_type(t: any) -> (ir.Function | None);
    def _repr_cache_key(t: any) -> (str | None);
    def _repr_str_fn -> ir.Function;
    def _repr_leaf_fn(kind: str) -> (ir.Function | None);
    def _repr_jacval_fn -> (ir.Function | None);
    def _str_jacval_fn -> (ir.Function | None);
    def _repr_obj_fn(arch_name: str) -> ir.Function;
    def _repr_list_fn(t: any, key: str) -> (ir.Function | None);
    def _repr_dict_fn(t: any, key: str) -> (ir.Function | None);
    def _repr_set_fn(t: any, key: str) -> (ir.Function | None);
    def _repr_tuple_fn(t: any, key: str) -> (ir.Function | None);
    def _repr_seq_fn(
        fn_name: str,
        cont_ptr_ty: ir.Type,
        elem_fn: ir.Function,
        open_text: str,
        close_text: str,
        empty_text: (str | None),
        get_fn: (ir.Function | None) = None
    ) -> ir.Function;

    def _repr_const_str(text: str) -> ir.Value;
    def _repr_acc_concat(acc_slot: ir.Value, piece: ir.Value, own_piece: bool) -> None;
    def _repr_maybe_sep(
        fn: ir.Function, i_val: ir.Value, acc_slot: ir.Value, sep_g: ir.Value
    ) -> None;

    def _repr_call_elem_fn(elem_fn: ir.Function, elem: ir.Value) -> ir.Value;
}
