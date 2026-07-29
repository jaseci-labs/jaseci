"""reactive_intent → Compose kotlin source prelude."""
import from jaclang.compiler.passes.ecmascript.intent.model { IntentComponent }
import from jaclang.compiler.passes.ecmascript.reactive_intent {
    IntentExpr,
    IntentStmt
}
import from jaclang.compiler.passes.ecmascript.intent.leaves {
    intent_expr_to_src,
    intent_stmts_to_src
}

obj ReactiveComposeEmitter {
    def emit_prelude(comp: IntentComponent) -> str;
    def _expr_src(expr: (IntentExpr | None)) -> str;
    def _stmts_src(stmts: list[IntentStmt], indent: str = "        ") -> str;
}
