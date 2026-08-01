import from jaclang.compiler.passes.ecmascript.intent.model { IntentModule }
import type from jaclang.compiler.passes.compose.view_ir { ComposeElement }

obj ComposeModule {
    has intent: IntentModule = IntentModule(),
        compose_views: dict[str, ComposeElement] = {},
        kotlin_imports: list[str] = [];

    def compose_view_for(name: str) -> (ComposeElement | None) {
        return self.compose_views.get(name);
    }

    def add_kotlin_import(line: str) {
        if line and line not in self.kotlin_imports {
            self.kotlin_imports.append(line);
        }
    }

    def merge_from(other: ComposeModule) -> None {
        if other is None or other is self {
            return;
        }
        self.intent.merge_from(other.intent);
        for (name, view) in other.compose_views.items() {
            self.compose_views[name] = view;
        }
        for line in other.kotlin_imports {
            self.add_kotlin_import(line);
        }
    }
}
