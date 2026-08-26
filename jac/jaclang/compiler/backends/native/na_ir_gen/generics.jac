import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import from jaclang.compiler.frontend.diagnostics { E5092 }
import jaclang.compiler.frontend.unitree as uni;
import os;

obj NaIRGenGenerics(NaIRGenState) {
    def _ct_eval -> any;
    def _ct_value_with_bindings(nd: uni.Expr) -> tuple;
    def _ct_native_const(v: any, nd: uni.Expr) -> (ir.Value | None);
    def _ct_fold(nd: (uni.UniNode | None)) -> (ir.Value | None);
    def _ability_has_ct_params(ability: uni.Ability) -> bool;
    def _solve_ct_args(ability: uni.Ability, nd: uni.FuncCall) -> (dict | None);
    def _bind_ct_target(tgt: uni.UniNode, v: any) -> None;
    def _mangled_of(t: any) -> (str | None);
    def _syntactic_bind_type_params(
        tag_node: (uni.UniNode | None), actual: any, tp_names: list[str], solution: dict
    ) -> None;

    def _solve_generic_call(ability: uni.Ability, nd: uni.FuncCall) -> (dict | None);
    def _instantiate_generic(nd: uni.FuncCall, func_name: str) -> (ir.Function | None);
    def _stamp_mono_fn(
        ability: uni.Ability, spec_name: str, memo_key: str
    ) -> (ir.Function | None);

    def _instantiate_generic_method(
        nd: uni.FuncCall, owner_arch: str, method_name: str
    ) -> (ir.Function | None);

    def _instantiate_generic_for_target(
        func_name: str, tag_node: uni.UniNode
    ) -> (ir.Function | None);

    def _stamp_mono_method(
        ability: uni.Ability,
        arch_name: str,
        method_name: str,
        spec_name: str,
        memo_key: str
    ) -> (ir.Function | None);

    def _find_source_ability(mod_name: str, func_name: str) -> (uni.Ability | None);
}
