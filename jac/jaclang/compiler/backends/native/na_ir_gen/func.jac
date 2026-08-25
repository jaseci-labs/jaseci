import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import from jaclang.compiler.frontend.codeinfo { HDR_DTOR_OFF }
import from jaclang.compiler.frontend.constant { CodeContext, Tokens as Tok }
import from jaclang.compiler.frontend.diagnostics { E5092 }
import from jaclang.compiler.backends.py.module_codegen_pass { ModuleCodegenPass }
import from jaclang.compiler.types.types { FunctionType }
import jaclang.compiler.frontend.unitree as uni;
import os;
import sys;

obj NaIRGenFunc(NaIRGenState) {
    def _forward_declare_functions(module: uni.Module) -> None;
    def _maybe_declare_ability(nd: uni.ElementStmt) -> None;
    def _ability_fn_type(nd: uni.Ability) -> FunctionType;
    def _lower_sig_param(
        nd: uni.Ability, p: any, pv: (uni.ParamVar | None)
    ) -> ir.Type;

    def _lower_sig_return(nd: uni.Ability, fn_t: FunctionType) -> ir.Type;
    def _ability_llvm_sig(nd: uni.Ability) -> tuple;
    def _apply_ownership_param_attrs(
        func: ir.Function, params: list, base: int
    ) -> None;

    def _codegen_ability(nd: uni.Ability) -> None;
    def _codegen_nested_ability(nd: uni.Ability) -> None;
    def _predeclare_nested_siblings(nd: uni.Ability) -> None;
    def _codegen_test(nd: uni.Test) -> None;
    def _apply_static_decorators -> None;
    def _generator_elem_type(nd: uni.Ability) -> (ir.Type | None);
    def _codegen_generator(nd: uni.Ability, func: ir.Function) -> None;
    def _emit_generator_drop_fn(name: str, slots: list[tuple]) -> ir.Function;
    def _define_function(name: str, fnty: ir.FunctionType) -> ir.Function;
    def _codegen_entry(nodes: list[uni.ModuleCode]) -> None;
    def _declare_clib_ability(nd: uni.Ability) -> None;
    def _emit_glob_init_func -> None;
}
