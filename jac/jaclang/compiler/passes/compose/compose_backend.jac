"""view_ir → Compose Kotlin source (used by compose_emit)."""
import from jaclang.compiler.passes.ecmascript.intent.model { IntentComponent }
import type from jaclang.compiler.passes.ecmascript.view_ir { ViewElement }

obj ViewComposeEmitter {
    has diagnostics: list[str] = [],
        needs_coroutine_scope: bool = False;

    def emit_view(view: (ViewElement | None)) -> any;
    def emit_component_view(comp: IntentComponent) -> str;
}
