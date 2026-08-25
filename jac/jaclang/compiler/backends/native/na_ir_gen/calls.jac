import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import from jaclang.compiler.frontend.codeinfo { HDR_TAG_OFF }
import from jaclang.compiler.frontend.constant { Tokens as Tok }
import from jaclang.compiler.frontend.diagnostics { E5092, E9001 }
import jaclang.compiler.frontend.unitree as uni;
import os;
import from jaclang.compiler.types.types { ClassType, EnumMemberType, UnionType }

obj NaIRGenCalls(NaIRGenState) {
    def _codegen_call(nd: uni.FuncCall) -> (ir.Value | None);
    def _codegen_builtin_call(nd: uni.FuncCall) -> (ir.Value | None);
    def _codegen_managed_call(nd: uni.FuncCall) -> (ir.Value | None);
    def _codegen_region_call(nd: uni.FuncCall) -> (ir.Value | None);
    def _codegen_type_call(nd: uni.FuncCall) -> (ir.Value | None);
    def _codegen_iter_call(nd: uni.FuncCall) -> (ir.Value | None);
    def _codegen_complex_call(nd: uni.FuncCall) -> (ir.Value | None);
    def _codegen_builtin_nary(nd: uni.FuncCall, func_name: str) -> (ir.Value | None);
    def _codegen_builtin_unary(nd: uni.FuncCall, func_name: str) -> (ir.Value | None);
    def _codegen_len_call(nd: uni.FuncCall) -> (ir.Value | None);
    def _empty_container_of_type(
        t: any, func_name: str, nd: uni.UniNode
    ) -> (ir.Value | None);

    def _codegen_empty_container_ctor(
        nd: uni.FuncCall, func_name: str
    ) -> (ir.Value | None);

    def _codegen_range_or_slice(nd: uni.FuncCall, func_name: str) -> (ir.Value | None);
    def _codegen_input_call(nd: uni.FuncCall) -> (ir.Value | None);
    def _module_call_qualifier(nd: uni.FuncCall) -> (str | None);
    def _callee_function(nd: uni.FuncCall, func_name: str) -> (ir.Function | None);
    def _nogc_owned_release_args(nd: uni.FuncCall, release_args: list) -> list;
    def _codegen_intrinsic(nd: uni.FuncCall, intr: object) -> (ir.Value | None);
    def _intrinsic_operand(
        nd: uni.FuncCall, intr: object, arg: uni.Expr, spec: str
    ) -> (ir.Value | None);

    def _emit_intrinsic_rc_runtime(
        nd: uni.FuncCall, intr: object, args: list
    ) -> (ir.Value | None);

    def _emit_intrinsic_float_bits(
        nd: uni.FuncCall, intr: object, args: list
    ) -> (ir.Value | None);

    def _emit_intrinsic_bits_float(
        nd: uni.FuncCall, intr: object, args: list
    ) -> (ir.Value | None);

    def _emit_unsupported_builtin_call(nd: uni.FuncCall, func_name: str) -> None;
    def _call_args_lowered(
        nd: uni.UniNode, func: ir.Function, func_name: str, coerced: list
    ) -> bool;

    def _emit_new(nd: uni.FuncCall) -> (ir.Value | None);
    def _codegen_decorated_call(nd: uni.FuncCall, func_name: str) -> (ir.Value | None);
    def _emit_isinstance(nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_isinstance_ptr_tags(operand: ir.Value, tags: list[int]) -> ir.Value;
    def _isinstance_arm_class(v: uni.UniNode) -> any;
    def _isinstance_target_names(
        nd: uni.FuncCall, operand: ir.Value, type_arg: uni.UniNode
    ) -> (list[str] | None);

    def _isinstance_name_kinds(type_arg: uni.UniNode, names: list[str]) -> dict;
    def _isinstance_operand_is_pyb(nd: uni.FuncCall, operand: ir.Value) -> bool;
    def _isinstance_abc_reduction(t: any, name: str) -> (list[str] | None);
    def _isinstance_static_verdict(kind: str, operand_t: any) -> (bool | None);
    def _enum_union_tags(operand_expr: uni.UniNode, names: list[str]) -> tuple;
    def _arch_alias_target(nd: (uni.UniNode | None)) -> (str | None);
    def _emit_isinstance_user(
        nd: uni.FuncCall, operand: ir.Value, names: list[str]
    ) -> (ir.Value | None);

    def _emit_isinstance_core(
        nd: uni.FuncCall, operand: ir.Value
    ) -> (ir.Value | None);

    def _emit_isinstance_mixed(
        nd: uni.FuncCall, operand: ir.Value, tags: list[int], names: list[str]
    ) -> (ir.Value | None);

    def _jacval_tags_for_kind(kind: str) -> list[int];
    def _codegen_call_args(nd: uni.FuncCall) -> list;
    def _coerce_narrowed_arg(
        nd: (uni.UniNode | None), val: (ir.Value | None)
    ) -> (ir.Value | None);

    def _codegen_receiver(nd: (uni.UniNode | None)) -> (ir.Value | None);
    def _emit_take_ref(value: ir.Value, op: str, loc: str = "") -> None;
    def _codegen_bound_args(
        nd: uni.FuncCall, func: ir.Function, self_offset: int = 0
    ) -> list;

    def _spread_tuple_values(tv: ir.Value, tuple_t: any) -> list;
    def _bind_arg_slot(
        func: ir.Function, slot: int, val: ir.Value, src_ty: any
    ) -> ir.Value;

    def _finish_bound_args(
        nd: uni.FuncCall, func: ir.Function, self_offset: int, args: list
    ) -> list;

    def _abandoned_args(func: ir.Function, self_offset: int, args: list) -> list;
    def _callee_jac_arity(func: ir.Function, self_offset: int) -> int;
    def _checker_flagged(nd: uni.UniNode) -> bool;
    def _stub_default_value(
        nd: uni.FuncCall, param: any, expected_type: (ir.Type | None)
    ) -> ir.Value;

    def _codegen_varargs_list(
        nd: uni.FuncCall, extras: list, expected: (ir.Type | None), elem_tb: any
    ) -> (ir.Value | None);

    def _codegen_kwargs_dict(
        nd: uni.FuncCall,
        leftover: dict,
        expected: (ir.Type | None),
        order: (list | None) = None,
        bind_records: (list | None) = None,
        val_tb: any = None
    ) -> (ir.Value | None);

    def _merge_dict_into(
        dst: ir.Value,
        src: ir.Value,
        helpers: dict,
        dict_key: str,
        loc: str,
        skip_keys: (ir.Value | None) = None
    ) -> bool;

    def _prep_kwbind_record(
        name: str,
        slot_type: ir.Type,
        args_idx: int,
        stored: ir.Value,
        bound_kind: (str | None),
        required_kind: (str | None)
    ) -> dict;

    def _try_flow_future(nd: uni.ConcurrentExpr) -> (ir.Value | None);
}
