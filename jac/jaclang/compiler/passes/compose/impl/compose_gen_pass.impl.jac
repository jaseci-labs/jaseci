"""ComposeGenPass implementation — uni walk for native Compose codegen."""
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.compose.compose_model { ComposeModule }
import from jaclang.compiler.passes.ecmascript.intent.collector { IntentCollector }
import from jaclang.compiler.passes.ecmascript.intent.session { IntentSession }
import from jaclang.compiler.passes.ecmascript.intent.detection {
    COMPOSE_COMPONENT_TYPES,
    unwrap_ability_body
}
import from jaclang.compiler.passes.compose.compose_leaf_converter { ComposeLeafConverter }
import from jaclang.compiler.passes.compose.compose_intent_adapter { ComposeIntentAdapter }
import from jaclang.compiler.passes.compose.jac_to_kotlin { JacToKotlin }
import from jaclang.compiler.passes.compose.compose_view_builder { ComposeViewBuilder }
import from jaclang.compiler.passes.compose.kotlin_ast { KtLiteral }

impl ComposeGenPass.before_pass -> None {
    self._view_stack = [];
    self.reactive_vars = set();
    self.lowerer = JacToKotlin(reactive_vars=self.reactive_vars);
    self.view_builder = ComposeViewBuilder(lowerer=self.lowerer);
    self.collector = IntentCollector();
    self.collector.link_module(self.model.intent);
    self.converter = ComposeLeafConverter(
        lowerer=self.lowerer,
        null_expr=KtLiteral(value=None),
        fallback_expr=KtLiteral(value=None),
        reactive_vars=self.reactive_vars
    );
    self.intent_session = IntentSession(
        collector=self.collector,
        adapter=ComposeIntentAdapter(collector=self.collector),
        converter=self.converter,
        pass_ref=self,
        component_types=COMPOSE_COMPONENT_TYPES,
        strict_arch_has=False,
        use_arch_has_dedup=True,
        skip_existing_policy="module",
        reactive_vars=self.reactive_vars
    );
}

impl ComposeGenPass.after_pass -> None {
    for diag in self.lowerer.diagnostics {
        self.model.intent.add_diagnostic(diag);
    }
    for diag in self.view_builder.diagnostics {
        self.model.intent.add_diagnostic(diag);
    }
}

impl ComposeGenPass.enter_ability(nd: uni.Ability) -> None {
    self._view_stack.append(None);
    self.intent_session.enter_ability(nd);
}

impl ComposeGenPass.exit_arch_has(nd: uni.ArchHas) -> None {
    scan = self.intent_session.scan_arch_has(nd);
    if scan is not None {
        self.intent_session.adapter.apply_arch_has_scan(nd, scan);
    }
}

impl ComposeGenPass._sync_lowerer_reactive_vars -> None {
    names = self.collector.existing_reactive_names();
    self.reactive_vars = names;
    self.intent_session.reactive_vars = names;
    self.collector.reactive_vars = names;
    self.lowerer.reactive_vars = names;
    if self.converter is not None {
        self.converter.reactive_vars = names;
    }
}

impl ComposeGenPass.exit_assignment(nd: uni.Assignment) -> None {
    update = self.intent_session.scan_state_update(nd);
    if update is not None {
        self.intent_session.adapter.lower_state_update(nd, update);
    }
}

impl ComposeGenPass.exit_ability(nd: uni.Ability) -> None {
    if isinstance(nd.signature, uni.EventSignature) and nd.in_client_context() {
        self.intent_session.record_and_lower_effect(nd);
    }

    inner = unwrap_ability_body(nd);
    if inner {
        self._sync_lowerer_reactive_vars();
        for stmt in inner {
            if isinstance(stmt, uni.ReturnStmt) and stmt.expr {
                if isinstance(stmt.expr, uni.JsxElement) {
                    view = self.view_builder.build_element(stmt.expr);
                    if view is not None {
                        comp_name = self.model.intent.current;
                        if comp_name is not None {
                            self.model.compose_views[comp_name] = view;
                        }
                    }
                }
            }
        }
    }

    self.intent_session.pop_ability_scope();
    if self._view_stack {
        self._view_stack.pop();
    }
}

impl ComposeGenPass.exit_jsx_element(nd: uni.JsxElement) -> None {
    # Root JSX inside a component body is captured via return statement.
    # Nested elements are built bottom-up by ComposeViewBuilder.
    return;
}

impl run_compose_gen_pass(
    mod: uni.Module, prog: any = None, into: (ComposeModule | None) = None
) -> ComposeModule {
    pass_inst = ComposeGenPass(ir_in=mod, prog=prog);
    if into is not None {
        pass_inst.model = into;
        pass_inst.collector.link_module(into.intent);
    }
    pass_inst.transform(mod);
    return pass_inst.model;
}
