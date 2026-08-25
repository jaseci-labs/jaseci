import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import from jaclang.compiler.frontend.diagnostics { E5092 }
import jaclang.compiler.frontend.unitree as uni;

obj NaIRGenContextMgr(NaIRGenState) {
    def _codegen_with(nd: uni.WithStmt) -> None;
    def _context_manager_class(expr_item: uni.ExprAsItem) -> (str | None);
    def _codegen_with_recursive(exprs: object, idx: int, body: object) -> None;
}
