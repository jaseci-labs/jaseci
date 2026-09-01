import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import from jaclang.compiler.frontend.constant { CodeContext, Tokens as Tok }
import from jaclang.compiler.frontend.diagnostics { E5026 }
import from jaclang.compiler.backends.py.module_codegen_pass { ModuleCodegenPass }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.backends.py.const_fold { fold_const }

obj NaIRGenGlobals(NaIRGenState) {
    def _register_enums(module: uni.Module) -> None;
    def _register_globals(module: uni.Module) -> None;
    def _quiet_glob_type(type_expr: (uni.UniNode | None)) -> (ir.Type | None);
    def _glob_native_use_exists(target: uni.UniNode) -> bool;
    def _register_entry_globals(module: uni.Module) -> None;
    def _codegen_global_vars(nd: uni.GlobalVars) -> None;
    def _infer_global_init_type(value_node: uni.UniNode) -> (ir.Type | None);
    def _codegen_const_expr(
        nd: uni.UniNode, target_type: ir.Type
    ) -> (ir.Constant | None);
}
