import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import from jaclang.compiler.frontend.diagnostics { E5092 }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.types.type_utils { apply_solved_type_vars }
import from jaclang.compiler.types.types { FunctionType, TypeVarType }

obj NaIRGenGenerics(NaIRGenState) {
    def _mangled_of(t: any) -> (str | None);
    def _mono_solution_of(
        ability: uni.Ability, bindings: (dict | None)
    ) -> (dict | None);

    def _mono_spec_of(base: str, solution: dict) -> tuple;
    def _lower_mono_signature(
        ability: uni.Ability, spec_name: str
    ) -> (ir.FunctionType | None);

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
}
