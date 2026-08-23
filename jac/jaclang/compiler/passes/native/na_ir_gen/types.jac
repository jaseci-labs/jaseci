import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.constant { OwnershipKind }
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.diagnostics { E5090, E5092 }
import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY, NumericKind }
import from jaclang.compiler.type_system.type_utils { convert_to_instance }
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.type_system.types {
    AnyType,
    ClassType,
    EnumMemberType,
    FunctionType,
    NeverType,
    ResolvedOperator,
    TypeVarType,
    UnionType,
    UnknownType
}

obj NaIRGenTypes(NaIRGenState) {
    def _tb_class_name(t: any) -> (str | None);
    def _tb_is(t: any, names: tuple) -> bool;
    def _tb_args(t: any) -> list;
    def _tb_members(t: any) -> list;
    def _tb_non_none(t: any) -> list;
    def _tb_has_none(t: any) -> bool;
    def _tb_opt_payload(t: any) -> (any | None);
    def _tb_elem(t: any, idx: int = 0) -> (any | None);
    def _tb_decl(t: any) -> (uni.UniNode | None);
    def _tuple_type_of(args: list) -> any;
    def _tb_builtin(name: str) -> any;
    def _tb_kind(t: any) -> str;
    def _tb_payload_kind(t: any) -> str;
    def _tb_solve(t: any) -> any;
    def _tb_spec_match(t: any, names: tuple) -> (any | None);
    def _tb_erased(t: any) -> bool;
    def _jac_optional_type(payload: ir.Type) -> ir.Type;
    def _opt_payload_of(t: ir.Type) -> (ir.Type | None);
    def _opt_ptr_payload_of(t: ir.Type) -> (ir.Type | None);
    def _flow_narrowed_type_of(expr: (uni.UniNode | None)) -> (any | None);
    def _narrowed_flow_type(nd: uni.UniNode) -> (any | None);
    def _apply_flow_narrowing(nd: uni.UniNode, val: ir.Value) -> ir.Value;
    def _lower_function_type_raw(t: any) -> ir.Type;
    def _stack_entry_alloca(var_type: ir.Type, name: str) -> ir.Value;
    def _abi_sizeof(t: ir.Type) -> int;
    def _resolve_jac_type(type_expr: (uni.UniNode | None)) -> ir.Type;
    def _annotation_type_of(type_expr: (uni.UniNode | None)) -> (any | None);
    def _lower_list_for_elem(elem_llvm: ir.Type) -> ir.Type;
    def _resolve_decl_type(
        type_expr: (uni.UniNode | None), value: (uni.UniNode | None)
    ) -> ir.Type;

    def _widened_tuple_decl_type(
        type_expr: (uni.UniNode | None), value: (uni.UniNode | None)
    ) -> (ir.Type | None);

    def _tuple_struct_of(elem_types: list) -> ir.Type;
    def _resolve_sig_type(type_expr: (uni.UniNode | None)) -> ir.Type;
    def _resolve_field_type(var: uni.UniNode) -> ir.Type;
    def _foreign_optional_field(tb: any) -> bool;
    def _typevar_optional_field(tb: any) -> bool;
    def _erased_typevar_names(tb: any) -> list[str];
    def _erased_seq_type(tb: any) -> (ir.Type | None);
    def _emit_unlowerable_type(
        type_expr: uni.UniNode, tb: any, declaration: bool = False
    ) -> ir.Type;

    def _lower_type(t: any) -> (ir.Type | None);
    def _lower_cache_key(t: any) -> (tuple | None);
    def _na_loc -> str;
    def _tb_spec_key(t: any, names: tuple, registry: dict) -> (str | None);
    def _lower_union(t: any) -> (ir.Type | None);
    def _unify_repr_lowering(reprs: list) -> (ir.Type | None);
    def _lower_class_type(t: any) -> (ir.Type | None);
    def _lower_function_type(t: any) -> ir.Type;
    def _tuple_key_of(expr: (uni.UniNode | None)) -> (str | None);
    def _set_spec_of(expr: (uni.UniNode | None)) -> (str | None);
    def _dict_key_of(expr: (uni.UniNode | None)) -> (str | None);
    def _list_spec_of(expr: (uni.UniNode | None)) -> (str | None);
    def _spec_of(
        expr: (uni.UniNode | None), names: tuple, registry: dict
    ) -> (str | None);

    def _struct_name_of(expr: (uni.UniNode | None)) -> (str | None);
    def _struct_name_for_key(tk: any) -> (str | None);
    def _struct_ptr_pointee_name(val: ir.Value) -> (str | None);
    def _struct_array_elem_ptr(ptr: ir.Value, idx_val: ir.Value) -> ir.Value;
    def _get_name(nd: (uni.UniNode | None)) -> (str | None);
    def _to_bool(val: ir.Value, ty: any) -> ir.Value;
    def _to_bool_str_desc(val: ir.Value) -> ir.Value;
    def _to_bool_optional(val: ir.Value, payload_ty: any) -> ir.Value;
    def _to_bool_container(val: ir.Value) -> ir.Value;
    def _jacval_truthy(jv: ir.Value) -> ir.Value;
    def _jacval_is_none(jv: ir.Value, negate: bool) -> ir.Value;
    def _entry_alloca(var_type: ir.Type, name: str) -> ir.Value;
    def _zero_const(ty: ir.Type) -> ir.Constant;
    def _coerce_type(
        val: ir.Value, target_type: ir.Type, src_ty: any = None
    ) -> ir.Value;

    def _coerce_type_inner(
        val: ir.Value, target_type: ir.Type, src_ty: any = None
    ) -> ir.Value;

    def _promote_to_float(
        left: ir.Value, right: ir.Value, lty: any, rty: any
    ) -> tuple[(ir.Value, ir.Value)];

    def _emit_binary_op(
        op: str,
        left: ir.Value,
        right: ir.Value,
        lty: any,
        rty: any,
        resolved: (ResolvedOperator | None) = None
    ) -> (ir.Value | None);

    def _emit_str_concat(left: ir.Value, right: ir.Value) -> ir.Value;
    def _emit_arch_dunder_binop(
        op: str,
        left: ir.Value,
        right: ir.Value,
        lty: any,
        rty: any,
        resolved: (ResolvedOperator | None) = None
    ) -> (ir.Value | None);

    def _emit_comparison(
        op: str, left: ir.Value, right: ir.Value, is_float: bool, lty: any, rty: any
    ) -> (ir.Value | None);

    def _emit_scalar_cmp(
        op: str, left: ir.Value, right: ir.Value, is_float: bool
    ) -> (ir.Value | None);

    def _is_jacval_ty(t: ir.Type) -> bool;
    def _is_jacval_boxable(t: ir.Type) -> bool;
    def _emit_jacval_ordering(
        op: str, jv: ir.Value, peer: ir.Value, jv_on_left: bool
    ) -> (ir.Value | None);

    def _emit_mixed_jacval_comparison(
        op: str, left: ir.Value, right: ir.Value, lty: any, rty: any
    ) -> (ir.Value | None);

    def _emit_optional_eq(
        op: str, left: ir.Value, right: ir.Value, is_float: bool, lty: any, rty: any
    ) -> (ir.Value | None);

    def _emit_jacval_eq(left: ir.Value, right: ir.Value) -> ir.Value;
    def _opt_membership_operand(left: ir.Value, slot_type: ir.Type) -> tuple;
    def _codegen_int_floor_divmod(
        left: ir.Value, right: ir.Value
    ) -> tuple[(ir.Value, ir.Value)];

    def _codegen_float_floor_div(left: ir.Value, right: ir.Value) -> ir.Value;
    def _codegen_float_floor_mod(left: ir.Value, right: ir.Value) -> ir.Value;
    def _spec_union_agreement(t: any, names: tuple) -> (any | None);
    def _elem_storage_llvm(t: any) -> (ir.Type | None);
    def _aos_elem_of(type_expr: uni.UniNode | None) -> (str | None);
    def _resolve_clib_type(type_expr: (uni.UniNode | None)) -> ir.Type;
}
