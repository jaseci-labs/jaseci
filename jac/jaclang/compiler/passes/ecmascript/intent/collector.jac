"""IntentCollector: records reactive/view intent into IntentModule.

This is the single recording seam extracted from EsastGenPass. During the uni
walk the pass calls collector.record_* / enter_component / mark_screen instead
of a backend.lower_* directly. The collector:

  1. Records each intent into its pass-scoped IntentModule exactly once (the
     single source of truth — no backend-specific lowering is baked into the
     recording).
  2. Delegates estree production to the FrameworkBackend (React/Preact/Solid)
     so JS output is byte-identical to the previous inline backend.lower_*
     calls (eager splice, P0.4).

Leaves are es.Expression / es.Statement already lowered by EsastGenPass; the
collector re-implements no expression visitors (it piggybacks on the walk).

The Compose/Android path uses ComposeGenPass directly (kotlin_ast leaves) and
does not go through this collector.

Frozen extraction surface (P0.2 inventory) — every backend-coupled call site
that routes through here:
  exit_name            lower_state_read
  exit_assignment      record_state_update           (StateUpdate ctor)
  exit_try_stmt        record_async_boundary         (AsyncBoundary ctor)
  exit_jsx_element     record_view_symbols           (+ record_view via jsx_processor)
  _transform_to_useeff record_effect                 (Effect ctor)
  exit_arch_has        record_ref_field              (RefField ctor)
  exit_arch_has        record_state_field            (StateField ctor)
  enter_ability        enter_component / mark_screen
  jsx_processor        record_view                   (ViewElement)
lower_view_expr is backend-internal (ReactBackend.lower_view), not a pass site.
"""
import jaclang.compiler.passes.ecmascript.estree as es;
import jaclang.jac0core.unitree as uni;
import type from jaclang.compiler.passes.ecmascript.esast_gen_pass { EsastGenPass }
import from jaclang.compiler.passes.ecmascript.framework_backend { FrameworkBackend }
import from jaclang.compiler.passes.ecmascript.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}
import type from jaclang.compiler.passes.ecmascript.view_ir { ViewElement }
import from jaclang.compiler.passes.ecmascript.intent.model { IntentModule }

obj IntentCollector {
    has pass_ref: EsastGenPass,
        _own_module: (IntentModule | None) = None,
        _linked_module: (IntentModule | None) = None;

    def init(pass_ref: EsastGenPass) -> None {
        self.pass_ref = pass_ref;
    }

    def _backend -> FrameworkBackend {
        self.pass_ref._ensure_backend();
        return self.pass_ref.backend;
    }

    def module -> IntentModule {
        if self._linked_module is not None {
            return self._linked_module;
        }
        if self._own_module is None {
            self._own_module = IntentModule();
        }
        self._linked_module = self._own_module;
        return self._linked_module;
    }

    # --- component / screen tracking ----------------------------------------

    def enter_component(name: str) -> None {
        m = self.module();
        m.current = name;
        m.ensure_component(name);
    }

    def mark_screen(
        name: str, is_screen: bool = True, route_path: (str | None) = "/"
    ) -> None {
        comp = self.module().ensure_component(name);
        comp.is_screen = is_screen;
        if route_path {
            comp.route_path = route_path;
        }
    }

    # --- state read ---------------------------------------------------------

    def lower_state_read(name: str) -> es.Expression {
        return self._backend().lower_state_read(name);
    }

    # --- reactive intent recording (records once; lowers estree for JS) ---

    def record_state_field(nd: uni.UniNode, s: StateField) -> list[es.Statement] {
        self.module().current_component().state.append(s);
        b = self._backend();
        for sym in b.runtime_symbols(s) {
            self.pass_ref._inject_runtime_import(sym, nd);
        }
        return b.lower_state_field(s);
    }

    def record_ref_field(nd: uni.UniNode, r: RefField) -> list[es.Statement] {
        self.module().current_component().refs.append(r);
        b = self._backend();
        for sym in b.runtime_symbols(r) {
            self.pass_ref._inject_runtime_import(sym, nd);
        }
        return b.lower_ref_field(r);
    }

    def record_state_update(nd: uni.UniNode, u: StateUpdate) -> es.Expression {
        self.module().current_component().updates.append(u);
        return self._backend().lower_state_update(u);
    }

    def record_effect(nd: uni.UniNode, e: Effect) -> list[es.Statement] {
        self.module().current_component().effects.append(e);
        b = self._backend();
        for sym in b.runtime_symbols(e) {
            self.pass_ref._inject_runtime_import(sym, nd);
        }
        return b.lower_effect(e);
    }

    def record_async_boundary(
        nd: uni.UniNode, a: AsyncBoundary
    ) -> es.Expression {
        self.module().current_component().asyncs.append(a);
        b = self._backend();
        for sym in b.runtime_symbols(a) {
            self.pass_ref._inject_runtime_import(sym, nd);
        }
        return b.lower_async_boundary(a);
    }

    def record_view_symbols(nd: uni.UniNode, view: ViewElement) -> None {
        b = self._backend();
        for sym in b.runtime_symbols(view) {
            self.pass_ref._inject_runtime_import(sym, nd);
        }
    }

    def record_view(view: ViewElement, sync_loc: any) -> es.Expression {
        # JsxProcessor lowers bottom-up; keep the latest (outermost) root view.
        self.module().current_component().view = view;
        return self._backend().lower_view(view, sync_loc);
    }
}
