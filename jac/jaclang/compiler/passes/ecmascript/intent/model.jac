"""IntentModule: the single source of truth for reactive/view intent.

Promoted from the former compose/model.jac's ComposeModule so that reactive/view IR is a
first-class, backend-agnostic pass artifact. The IntentCollector populates this
during the EsastGenPass uni walk; a JS backend (EstreeLoweringBackend) consumes
it to produce estree, and the Compose emitter consumes it to produce Kotlin.

Design notes (see PLAN.md):
- Leaves are IntentExpr / IntentStmt (es.Expression|KtNode) — estree on the JS
  path, kotlin_ast on the Compose path. The IntentCollector piggybacks on
  EsastGenPass's expression lowering for JS; ComposeGenPass lowers Jac→kotlin_ast
  at collection time and never touches estree.
- Eager splice (P0.4): for the JS path the collector lowers inline via the
  FrameworkBackend and returns the estree for the pass to slot at the recorded
  source nd.gen.es_ast. The source node is therefore in hand at record time and
  does not need to be stored on each IR object (the deferred/two-phase
  alternative would store a back-ref; eager does not).
- Consumers (compose_emit, compose_backend, reactive_compose, android_target)
  import these Intent* types directly; the old compose/model.jac Compose* aliases
  were removed (P2.3).
"""
import from jaclang.compiler.passes.ecmascript.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}
import type from jaclang.compiler.passes.ecmascript.view_ir { ViewElement }
import type from jaclang.compiler.passes.compose.view_ir { ComposeElement }

obj IntentRoute {
    has path: str = "/",
        screen_name: str = "HomeScreen",
        component: (str | None) = None;
}

obj IntentComponent {
    has name: str = "",
        state: list[StateField] = [],
        refs: list[RefField] = [],
        effects: list[Effect] = [],
        asyncs: list[AsyncBoundary] = [],
        updates: list[StateUpdate] = [],
        view: (ViewElement | None) = None,
        compose_view: (ComposeElement | None) = None,
        is_screen: bool = False,
        route_path: (str | None) = None;
}

obj IntentModule {
    has components: dict[str, IntentComponent] = {},
        current: (str | None) = None,
        routes: list[IntentRoute] = [],
        imports: list[str] = [],
        package_name: str = "dev.jac.generated",
        app_name: str = "Jac App",
        backend_url: str = "",
        diagnostics: list[str] = [],
        interop_manifest: any = None;

    def add_import(imp: str) -> None {
        if imp not in self.imports {
            self.imports.append(imp);
        }
    }

    def ensure_component(name: str) -> IntentComponent {
        if name not in self.components {
            self.components[name] = IntentComponent(name=name);
        }
        return self.components[name];
    }

    def current_component -> IntentComponent {
        cname = self.current if self.current else "__root__";
        return self.ensure_component(cname);
    }

    def add_diagnostic(msg: str) -> None {
        self.diagnostics.append(msg);
    }

    def merge_from(other: IntentModule) -> None {
        if other is None or other is self {
            return;
        }
        for (name, comp) in other.components.items() {
            dst = self.ensure_component(name);
            if comp.compose_view is not None {
                dst.compose_view = comp.compose_view;
            }
            if comp.view is not None {
                dst.view = comp.view;
            }
            dst.state.extend(comp.state);
            dst.refs.extend(comp.refs);
            dst.effects.extend(comp.effects);
            dst.asyncs.extend(comp.asyncs);
            dst.updates.extend(comp.updates);
            if comp.is_screen {
                dst.is_screen = True;
            }
            if comp.route_path {
                dst.route_path = comp.route_path;
            }
        }
        for imp in other.imports {
            self.add_import(imp);
        }
        for diag in other.diagnostics {
            self.add_diagnostic(diag);
        }
    }
}
