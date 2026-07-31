"""ComposeModule — Android Compose codegen artifact.

Wraps target-neutral IntentModule semantics with native Compose view IR keyed
by component name. ComposeGenPass and ComposeEmit use this type; the JS path
continues to use IntentModule alone.
"""
import from jaclang.compiler.passes.ecmascript.intent.model { IntentModule }
import type from jaclang.compiler.passes.compose.view_ir { ComposeElement }

obj ComposeModule {
    has intent: IntentModule = IntentModule(),
        compose_views: dict[str, ComposeElement] = {};

    def compose_view_for(name: str) -> (ComposeElement | None) {
        return self.compose_views.get(name);
    }

    def merge_from(other: ComposeModule) -> None {
        if other is None or other is self {
            return;
        }
        self.intent.merge_from(other.intent);
        for (name, view) in other.compose_views.items() {
            self.compose_views[name] = view;
        }
    }
}
