"""ComposeGenPass implementation — uni walk for native Compose codegen."""
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { CodeContext, Tokens as Tok }
import from jaclang.compiler.passes.ecmascript.intent.model { IntentModule }
import from jaclang.compiler.passes.ecmascript.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}
import from jaclang.compiler.passes.compose.jac_to_kotlin { JacToKotlin }
import from jaclang.compiler.passes.compose.compose_view_builder { ComposeViewBuilder }
import from jaclang.compiler.passes.compose.kotlin_ast { KtNode, KtLiteral }

def _unwrap_body(nd: uni.Ability) -> (list[uni.UniNode] | None) {
    body = nd.body;
    if isinstance(body, uni.ImplDef) {
        return list(body.body) if body.body else [];
    }
    if isinstance(body, list) {
        return body;
    }
    return None;
}

impl ComposeGenPass.before_pass -> None {
    self.reactive_vars = set();
    self.reactive_vars_stack = [];
    self._view_stack = [];
    self._recorded_arch_has = set();
    self.lowerer = JacToKotlin(reactive_vars=self.reactive_vars);
    self.view_builder = ComposeViewBuilder(lowerer=self.lowerer);
}

impl ComposeGenPass.after_pass -> None {
    for diag in self.lowerer.diagnostics {
        self.model.add_diagnostic(diag);
    }
    for diag in self.view_builder.diagnostics {
        self.model.add_diagnostic(diag);
    }
}

impl ComposeGenPass._return_type_includes_composable(rt: uni.Expr) -> bool {
    if (
        isinstance(rt, uni.BinaryExpr)
        and isinstance(rt.op, uni.Token)
        and rt.op.name == Tok.BW_OR.name
    ) {
        return (
            self._return_type_includes_composable(rt.left)
            or self._return_type_includes_composable(rt.right)
        );
    }
    return isinstance(rt, uni.Name) and rt.value in (
        'Composable', 'JsxElement', 'JsxPage', 'JsxLayout'
    );
}

impl ComposeGenPass._return_type_route_role(rt: uni.Expr) -> (str | None) {
    if (
        isinstance(rt, uni.BinaryExpr)
        and isinstance(rt.op, uni.Token)
        and rt.op.name == Tok.BW_OR.name
    ) {
        left_role = self._return_type_route_role(rt.left);
        return left_role or self._return_type_route_role(rt.right);
    }
    if isinstance(rt, uni.Name) {
        if rt.value == 'JsxPage' {
            return 'page';
        }
        if rt.value == 'JsxLayout' {
            return 'layout';
        }
    }
    return None;
}

impl ComposeGenPass.enter_ability(nd: uni.Ability) -> None {
    self._view_stack.append(None);
    self.reactive_vars_stack.append(self.reactive_vars);
    self.reactive_vars = set(self.reactive_vars);
    self.lowerer.reactive_vars = self.reactive_vars;

    if (
        nd.code_context == CodeContext.CLIENT
        and not nd.is_method
        and isinstance(nd.signature, uni.FuncSignature)
        and nd.signature.return_type is not None
        and self._return_type_includes_composable(nd.signature.return_type)
    ) {
        name = nd.name_ref.sym_name;
        self.model.current = name;
        self.model.ensure_component(name);
        if name in ("app", "App") {
            comp = self.model.ensure_component(name);
            comp.is_screen = True;
            comp.route_path = "/";
        } elif self._return_type_route_role(nd.signature.return_type) == "page" {
            comp = self.model.ensure_component(name);
            comp.is_screen = True;
        }
    }
}

impl ComposeGenPass.exit_arch_has(nd: uni.ArchHas) -> None {
    self._record_arch_has(nd);
}

def _ref_head_name(expr: (uni.UniNode | None)) -> (str | None) {
    cur = expr;
    while True {
        if isinstance(cur, uni.FuncCall) {
            cur = cur.target;
        } elif isinstance(cur, uni.AtomTrailer) {
            cur = cur.target;
        } else {
            break;
        }
    }
    return cur.value if isinstance(cur, uni.Name) else None;
}

impl ComposeGenPass._sync_lowerer_reactive_vars -> None {
    comp = self.model.current_component();
    names: set[str] = set();
    for s in comp.state {
        names.add(s.name);
    }
    for r in comp.refs {
        names.add(r.name);
    }
    self.reactive_vars = names;
    self.lowerer.reactive_vars = names;
}

impl ComposeGenPass._record_arch_has(nd: uni.ArchHas) -> None {
    if id(nd) in self._recorded_arch_has {
        return;
    }
    owner: (uni.UniNode | None) = nd.parent;
    while owner is not None and not isinstance(owner, (uni.Ability, uni.Archetype)) {
        owner = owner.parent;
    }
    if isinstance(owner, uni.Archetype) {
        return;
    }
    if not nd.in_client_context() and owner is None {
        return;
    }
    comp = self.model.current_component();
    existing: set[str] = set();
    for s in comp.state {
        existing.add(s.name);
    }
    for r in comp.refs {
        existing.add(r.name);
    }
    for has_var in nd.vars {
        var_name = has_var.name.sym_name;
        if var_name in existing {
            continue;
        }
        ref_ctor = (
            isinstance(has_var.value, uni.FuncCall)
            and _ref_head_name(has_var.value.target) == 'Ref'
        );
        ref_typed = (
            has_var.type_tag is not None
            and _ref_head_name(has_var.type_tag.tag) == 'Ref'
        );
        if ref_ctor or ref_typed {
            init_kt: KtNode = KtLiteral(value=None);
            if isinstance(has_var.value, uni.FuncCall) and has_var.value.params {
                seed = has_var.value.params[0];
                seed_expr = seed.value if isinstance(seed, uni.KWPair) else seed;
                converted = self.lowerer.convert_expr(seed_expr);
                if converted is not None {
                    init_kt = converted;
                }
            }
            comp.refs.append(RefField(name=var_name, init_expr=init_kt));
            self.reactive_vars.add(var_name);
            self.lowerer.reactive_vars.add(var_name);
            existing.add(var_name);
            continue;
        }
        init_kt = self.lowerer.convert_expr(has_var.value) if has_var.value else None;
        if init_kt is None {
            init_kt = KtLiteral(value=None);
        }
        comp.state.append(StateField(name=var_name, init_expr=init_kt));
        self.reactive_vars.add(var_name);
        self.lowerer.reactive_vars.add(var_name);
        existing.add(var_name);
    }
    self._recorded_arch_has.add(id(nd));
}

impl ComposeGenPass.exit_assignment(nd: uni.Assignment) -> None {
    if len(nd.target) != 1 or not isinstance(nd.target[0], uni.Name) {
        return;
    }
    name = nd.target[0].sym_name;
    if name not in self.reactive_vars {
        return;
    }
    value_kt = self.lowerer.convert_expr(nd.value);
    if value_kt is None {
        return;
    }
    aug_op: (str | None) = None;
    if nd.aug_op and nd.aug_op.name {
        aug_map = {
            Tok.ADD_EQ.name: '+',
            Tok.SUB_EQ.name: '-',
            Tok.MUL_EQ.name: '*',
            Tok.DIV_EQ.name: '/',
            Tok.MOD_EQ.name: '%'
        };
        aug_op = aug_map.get(nd.aug_op.name);
    }
    comp = self.model.current_component();
    comp.updates.append(StateUpdate(name=name, value=value_kt, aug_op=aug_op));
}

impl ComposeGenPass._transform_to_effect(nd: uni.Ability) -> None {
    inner = _unwrap_body(nd);
    body_stmts: list = [];
    if inner {
        body_stmts = self.lowerer.convert_stmts(inner);
    }
    is_entry = nd.signature.event.name == Tok.KW_ENTRY;
    is_async = nd.is_async;
    deps: list = [];
    comp = self.model.current_component();
    comp.effects.append(
        Effect(body=body_stmts, deps=deps, is_entry=is_entry, is_async=is_async)
    );
}

impl ComposeGenPass.exit_ability(nd: uni.Ability) -> None {
    if isinstance(nd.signature, uni.EventSignature) and nd.in_client_context() {
        self._transform_to_effect(nd);
    }

    inner = _unwrap_body(nd);
    if inner {
        self._sync_lowerer_reactive_vars();
        for stmt in inner {
            if isinstance(stmt, uni.ReturnStmt) and stmt.expr {
                if isinstance(stmt.expr, uni.JsxElement) {
                    view = self.view_builder.build_element(stmt.expr);
                    if view is not None {
                        comp = self.model.current_component();
                        comp.compose_view = view;
                    }
                }
            }
        }
    }

    if self.reactive_vars_stack {
        self.reactive_vars = self.reactive_vars_stack.pop();
        self.lowerer.reactive_vars = self.reactive_vars;
    } else {
        self.reactive_vars = set();
        self.lowerer.reactive_vars = set();
    }
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
    mod: uni.Module, prog: any = None, into: (IntentModule | None) = None
) -> IntentModule {
    pass_inst = ComposeGenPass(ir_in=mod, prog=prog);
    if into is not None {
        pass_inst.model = into;
    }
    pass_inst.transform(mod);
    return pass_inst.model;
}
