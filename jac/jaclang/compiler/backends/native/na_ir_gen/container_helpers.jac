import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import from jaclang.compiler.frontend.codeinfo {
    HDR_ALLOC_ID_OFF,
    HDR_DTOR_OFF,
    HDR_TAG_OFF
}
import from jaclang.compiler.frontend.constant { Tokens as Tok }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.types.types { UnknownType }

obj NaIRGenContainerHelpers(NaIRGenState) {
    def _emit_key_comparison(
        b: ir.IRBuilder,
        key_type: ir.Type,
        stored_val: ir.Value,
        search_val: ir.Value,
        key_size: int = 0
    ) -> ir.Value;

    def _elem_kind(elem_type: ir.Type) -> str;
    def _emit_jacval_retain_fn -> ir.Function;
    def _emit_jacval_release_fn -> ir.Function;
    def _emit_jacval_rc_fn(fn_name: str, is_retain: bool) -> ir.Function;
    def _container_managed_fields(layout: dict) -> list;
    def _spread_operand(nd: (uni.UniNode | None)) -> (uni.Expr | None);
    def _container_src_info(
        val: (ir.Value | None), operand: (uni.UniNode | None)
    ) -> (dict | None);

    def _elem_slot_llvm(t: any) -> (ir.Type | None);
    def _list_spec_for_elem_llvm(elem_llvm: ir.Type) -> str;
    def _list_spec_for_type(t: any) -> (str | None);
    def _dict_spec_for_type(t: any) -> (str | None);
    def _set_spec_for_type(t: any) -> (str | None);
    def _aos_spec_for_expr(expr: (uni.UniNode | None)) -> (str | None);
    def _list_helpers_for(expr: (uni.UniNode | None)) -> (dict | None);
    def _list_spec_for_expr(expr: (uni.UniNode | None)) -> (str | None);
    def _dict_spec_for_expr(expr: (uni.UniNode | None)) -> (str | None);
    def _set_spec_for_expr(expr: (uni.UniNode | None)) -> (str | None);
    def _expr_type_of(expr: (uni.UniNode | None)) -> any;
    def _sym_type_of(nd: (uni.UniNode | None)) -> any;
    def _to_bool_of(val: ir.Value, expr: (uni.UniNode | None)) -> ir.Value;
    def _coerce_typed(val: ir.Value, target_type: ir.Type, src_ty: any) -> ir.Value;
    def _binop_typed(
        op: str,
        left: ir.Value,
        right: ir.Value,
        lty: any,
        rty: any,
        resolved: any = None
    ) -> (ir.Value | None);

    def _cmp_typed(
        op: str, left: ir.Value, right: ir.Value, is_float: bool, lty: any, rty: any
    ) -> (ir.Value | None);

    def _callee_name_of(call: (uni.UniNode | None)) -> (str | None);
    def _builtin_call_is(call: (uni.UniNode | None), name: str) -> bool;
    def _method_call_is(
        call: (uni.UniNode | None), name: str, owner_kinds: tuple
    ) -> bool;

    def _module_member_is(
        expr: (uni.UniNode | None), module: str, member: str
    ) -> bool;

    def _emit_spread_copy(
        src: ir.Value,
        src_helpers: dict,
        dest: ir.Value,
        dest_helpers: dict,
        dest_kind: str,
        loc: str,
        src_elem_ty: any = None
    ) -> None;

    def _emit_elem_retain(b: ir.IRBuilder, elem_type: ir.Type, val: ir.Value) -> None;
    def _emit_elem_release(b: ir.IRBuilder, elem_type: ir.Type, val: ir.Value) -> None;
    def _container_layout_dense(data_types: list) -> dict;
    def _container_layout_hash(key_type: ir.Type, val_type: (ir.Type | None)) -> dict;
    def _container_struct_fields(layout: dict) -> list;
    def _emit_live_slot_loop(
        fn: ir.Function,
        b: ir.IRBuilder,
        cont: ir.Value,
        layout: dict,
        tag: str,
        body_cb: object,
        fields: (list | None) = None
    ) -> ir.IRBuilder;

    def _emit_rc_alloc_container(
        b: ir.IRBuilder, container_ptr_type: ir.Type, layout: dict, initial_cap: int = 8
    ) -> tuple;

    def _emit_grow_array(
        b: ir.IRBuilder,
        arr_ptr: ir.Value,
        elem_type: ir.Type,
        cur_len: ir.Value,
        cap_ptr: ir.Value,
        cur_cap: ir.Value
    ) -> ir.Value;

    def _emit_rc_destructor_preamble(
        release_fn: ir.Function, ptr_type: ir.Type
    ) -> tuple;

    def _emit_container_new_fn(
        fn_name: str,
        container_ptr_type: ir.Type,
        layout: dict,
        dtor_fn: (ir.Function | None) = None,
        type_name: str = "container"
    ) -> ir.Function;

    def _emit_container_len_fn(
        fn_name: str, container_ptr_type: ir.Type
    ) -> ir.Function;

    def _emit_container_release_fn(
        fn_name: str, container_ptr_type: ir.Type, layout: dict
    ) -> ir.Function;

    def _emit_release_header_free(
        release_fn: ir.Function, b: ir.IRBuilder, done_bb: ir.Block
    ) -> None;

    def _emit_array_get_fn(
        fn_name: str,
        container_ptr_type: ir.Type,
        elem_type: ir.Type,
        data_field_idx: int
    ) -> ir.Function;

    def _tuple_box_release_fn(
        struct_type: ir.LiteralStructType
    ) -> (ir.Function | None);

    def _tuple_box_trace_fn(struct_type: ir.LiteralStructType) -> (ir.Function | None);
    def _emit_tuple_box_lifecycle(
        raw: ir.Value, struct_type: ir.LiteralStructType
    ) -> None;

    def _emit_container_trace_fn(
        trace_fn_name: str, container_ptr_type: ir.Type, layout: dict
    ) -> ir.Function;
}
