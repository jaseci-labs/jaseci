import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.diagnostics { E5092 }
import jaclang.jac0core.unitree as uni;

obj NaIRGenContextMgr(NaIRGenState) {
    def _codegen_with(nd: uni.WithStmt) -> None;
    def _context_manager_class(expr_item: uni.ExprAsItem) -> (str | None);
    def _codegen_with_recursive(exprs: object, idx: int, body: object) -> None;
}
