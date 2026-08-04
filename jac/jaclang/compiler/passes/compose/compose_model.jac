import from jaclang.compiler.passes.ecmascript.intent.model { IntentModule }
import type from jaclang.compiler.passes.compose.view_ir { ComposeElement }

obj ComposeModule {
    has intent: IntentModule = IntentModule(),
        compose_views: dict[str, ComposeElement] = {},
        kotlin_imports: list[str] = [];

    def compose_view_for(name: str) -> (ComposeElement | None) {
        return self.compose_views.get(name);
    }

    # Re-key a page's component from its source export name (e.g. `View`) to a
    # route-unique identity (the path-derived `component_import`, e.g.
    # `PagesAbout`). Several pages routinely export the same name, so the
    # source export cannot be the merge key — renaming before merge keeps each
    # page's component and view distinct. `comp.name` and the `compose_views`
    # entry move together so emit_component_view's `compose_view_for(comp.name)`
    # lookup still resolves.
    def rename_component(old_name: str, new_name: str) -> None {
        if not old_name or old_name == new_name {
            return;
        }
        comp = self.intent.components.pop(old_name, None);
        if comp is None {
            return;
        }
        comp.name = new_name;
        self.intent.components[new_name] = comp;
        view = self.compose_views.pop(old_name, None);
        if view is not None {
            self.compose_views[new_name] = view;
        }
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
