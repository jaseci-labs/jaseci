"""view_ir → Compose kotlin_ast / source (host-tag + curated vocab)."""
import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.compose { kotlin_ast as kt }
import from jaclang.compiler.passes.compose.kotlin_unparse { kt_to_source }
import from jaclang.compiler.passes.compose.es_to_kotlin { es_expr_to_kt }
import from jaclang.compiler.passes.compose.tailwind_to_modifier {
    translate_tailwind,
    LayoutKind
}
import from jaclang.compiler.passes.ecmascript.intent.model { IntentComponent }
import from jaclang.compiler.passes.ecmascript.view_ir {
    HostTag,
    ComponentTag,
    FragmentTag,
    DynamicTag,
    StaticAttr,
    DynamicAttr,
    EventAttr,
    TextChild,
    DynamicChild,
    ElementChild,
    IfChild,
    EachChild,
    SlotChild
}
import type from jaclang.compiler.passes.ecmascript.view_ir { ViewElement }

glob _CURATED: set[str] = {
    "Button",
    "Input",
    "TextArea",
    "Select",
    "Card",
    "CardHeader",
    "CardBody",
    "StatsCard",
    "Badge",
    "Alert",
    "Spinner",
    "Modal",
    "Show",
    "For",
    "Outlet",
    "Link"
};

def _named(name: str, value: kt.KtNode) -> kt.KtNamedArg {
    return kt.KtNamedArg(name=name, value=value);
}

def _text_call(expr: kt.KtNode, tw: (any | None) = None) -> kt.KtComposableCall {
    # Compose Text requires a String; coerce non-literal values.
    text_expr: kt.KtNode = expr;
    if not (isinstance(expr, kt.KtLiteral) and isinstance(expr.value, str)) {
        text_expr = kt.KtRaw(code=f"({kt_to_source(expr)}).toString()");
    }
    args = [_named("text", text_expr)];
    if tw is not None {
        if tw.text_style.color {
            args.append(_named("color", kt.KtRaw(code=tw.text_style.color)));
        }
        if tw.text_style.font_size {
            args.append(
                _named("fontSize", kt.KtRaw(code=tw.text_style.font_size))
            );
        }
        if tw.text_style.font_weight {
            args.append(
                _named("fontWeight", kt.KtRaw(code=tw.text_style.font_weight))
            );
        }
        if tw.text_style.font_family {
            args.append(
                _named("fontFamily", kt.KtRaw(code=tw.text_style.font_family))
            );
        }
    }
    return kt.KtComposableCall(name="Text", args=args);
}

def _es_needs_coroutine(nd: any, depth: int = 0) -> bool {
    if nd is None or depth > 40 {
        return False;
    }
    if isinstance(nd, es.AwaitExpression) {
        return True;
    }
    if isinstance(nd, es.CallExpression) and isinstance(nd.callee, es.Identifier) {
        if nd.callee.name in ("__jacSpawn", "jacSpawn") {
            return True;
        }
    }
    if isinstance(nd, list) or isinstance(nd, tuple) {
        for item in nd {
            if _es_needs_coroutine(item, depth + 1) {
                return True;
            }
        }
        return False;
    }
    for attr in (
        "body", "expression", "argument", "arguments", "left", "right",
        "consequent", "alternate", "test", "block", "handler", "finalizer",
        "declarations", "init", "update", "cases", "discriminant", "elements",
        "properties", "value", "object", "property", "callee", "params"
    ) {
        child = getattr(nd, attr, None);
        if child is not None and _es_needs_coroutine(child, depth + 1) {
            return True;
        }
    }
    return False;
}

def _as_click_lambda(
    handler: kt.KtNode, needs_coro: bool = False
) -> kt.KtNode {
    lam: kt.KtLambda;
    if isinstance(handler, kt.KtLambda) {
        lam = handler;
    } else {
        lam = kt.KtLambda(
            params=[], body=[kt.KtExprStmt(expression=handler)]
        );
    }
    if not needs_coro {
        return lam;
    }
    # onClick is not suspend — wrap spawn/await bodies in scope.launch.
    inner = kt.KtLambda(
        params=[],
        body=list(lam.body),
        expression_body=lam.expression_body
    );
    launch = kt.KtCall(
        callee=kt.KtMemberAccess(
            object=kt.KtIdentifier(name="scope"),
            property=kt.KtIdentifier(name="launch")
        ),
        args=[],
        trailing_lambda=inner
    );
    return kt.KtLambda(params=[], body=[kt.KtExprStmt(expression=launch)]);
}

def _dom_change_assign_target(handler: es.Expression) -> (str | None) {
    # Match `e => { name = e.target.value }` / arrow with assignment body.
    expr: any = handler;
    if isinstance(handler, es.ArrowFunctionExpression) {
        arrow_body = handler.body;
        if isinstance(arrow_body, es.BlockStatement) {
            stmts = arrow_body.body;
            if isinstance(stmts, list) and len(stmts) == 1 {
                stmt = stmts[0];
                if isinstance(stmt, es.ExpressionStatement) {
                    expr = stmt.expression;
                }
            }
        } else {
            expr = arrow_body;
        }
    }
    if isinstance(expr, es.AssignmentExpression) and isinstance(expr.left, es.Identifier) {
        right = expr.right;
        if isinstance(right, es.MemberExpression) {
            return expr.left.name;
        }
    }
    return None;
}

def _input_value_change_lambda(attrs: list) -> kt.KtNode {
    for attr in attrs {
        if isinstance(attr, EventAttr) and attr.name in (
            "onChange", "onchange", "onValueChange"
        ) {
            target = _dom_change_assign_target(attr.handler);
            if target {
                return kt.KtLambda(
                    params=["it"],
                    body=[
                        kt.KtExprStmt(
                            expression=kt.KtAssignment(
                                left=kt.KtIdentifier(name=target),
                                operator="=",
                                right=kt.KtIdentifier(name="it")
                            )
                        )
                    ]
                );
            }
            converted = es_expr_to_kt(attr.handler);
            if isinstance(converted, kt.KtLambda) {
                return converted;
            }
            if converted {
                return kt.KtLambda(
                    params=["it"], body=[kt.KtExprStmt(expression=converted)]
                );
            }
        }
    }
    return kt.KtLambda(params=["it"], body=[]);
}

def _class_name_attr(attrs: list) -> str {
    for attr in attrs {
        if (isinstance(attr, StaticAttr) or isinstance(attr, DynamicAttr))
        and attr.name in ("className", "class") {
            if isinstance(attr.value, es.Literal) and isinstance(attr.value.value, str) {
                return attr.value.value;
            }
        }
    }
    return "";
}

def _event_handler(attrs: list, names: set[str]) -> (kt.KtNode | None) {
    for attr in attrs {
        if isinstance(attr, EventAttr) and attr.name in names {
            return es_expr_to_kt(attr.handler);
        }
    }
    return None;
}

def _event_needs_coroutine(attrs: list, names: set[str]) -> bool {
    for attr in attrs {
        if isinstance(attr, EventAttr) and attr.name in names {
            return _es_needs_coroutine(attr.handler);
        }
    }
    return False;
}

def _attr_value(attrs: list, name: str) -> (kt.KtNode | None) {
    for attr in attrs {
        if (isinstance(attr, StaticAttr) or isinstance(attr, DynamicAttr)) and attr.name == name {
            return es_expr_to_kt(attr.value);
        }
    }
    return None;
}

def _layout_name(layout: LayoutKind) -> str {
    if layout == LayoutKind.ROW {
        return "Row";
    } elif layout == LayoutKind.BOX {
        return "Box";
    } elif layout == LayoutKind.FLOW_ROW {
        return "FlowRow";
    } elif layout == LayoutKind.FLOW_COLUMN {
        return "FlowColumn";
    } elif layout == LayoutKind.LAZY_GRID {
        return "LazyVerticalGrid";
    } elif layout == LayoutKind.HIDDEN {
        return "Hidden";
    }
    return "Column";
}

def _component_name(tag: ComponentTag) -> str {
    ref = tag.ref;
    if isinstance(ref, es.Identifier) {
        return ref.name;
    }
    if isinstance(ref, es.MemberExpression) and isinstance(ref.property, es.Identifier) {
        return ref.property.name;
    }
    return "";
}

def _emit_children(children: list, emitter: ViewComposeEmitter) -> list[kt.KtNode] {
    nodes: list[kt.KtNode] = [];
    for child in children {
        if isinstance(child, TextChild) {
            val = es_expr_to_kt(child.value);
            if val is None {
                val = kt.KtLiteral(value="");
            }
            nodes.append(_text_call(val));
        } elif isinstance(child, DynamicChild) {
            val = es_expr_to_kt(child.value);
            if val is None {
                val = kt.KtLiteral(value="");
            }
            nodes.append(_text_call(val));
        } elif isinstance(child, ElementChild) {
            child_node = emitter.emit_view(child.element);
            if child_node is not None {
                nodes.append(child_node);
            }
        } elif isinstance(child, SlotChild) {
            nodes.append(
                kt.KtCall(callee=kt.KtIdentifier(name="content"), args=[])
            );
        } elif isinstance(child, IfChild) {
            test = es_expr_to_kt(child.test) or kt.KtLiteral(value=True);
            cons = _emit_children(child.consequent, emitter);
            alt = (
                _emit_children(child.alternate, emitter)
                if child.alternate
                else []
            );
            nodes.append(kt.KtIf(test=test, consequent=cons, alternate=alt));
        } elif isinstance(child, EachChild) {
            items = es_expr_to_kt(child.items) or kt.KtListLiteral(elements=[]);
            body = _emit_children(child.body, emitter);
            nodes.append(
                kt.KtCall(
                    callee=kt.KtMemberAccess(
                        object=items,
                        property=kt.KtIdentifier(name="forEach")
                    ),
                    args=[],
                    trailing_lambda=kt.KtLambda(
                        params=[child.item], body=body
                    )
                )
            );
        }
    }
    return nodes;
}

def _note_unsupported(emitter: ViewComposeEmitter, tw: any) -> None {
    for u in tw.unsupported {
        msg = f"unsupported Tailwind class: {u}";
        if msg not in emitter.diagnostics {
            emitter.diagnostics.append(msg);
        }
    }
}

def _layout_args(tw: any) -> list[kt.KtNamedArg] {
    args: list[kt.KtNamedArg] = [];
    if tw.modifier.calls {
        args.append(_named("modifier", tw.modifier));
    }
    is_row = tw.layout in (LayoutKind.ROW, LayoutKind.FLOW_ROW);
    if is_row {
        arr = tw.arrangement or tw.horizontal_arrangement;
        if arr {
            args.append(_named("horizontalArrangement", kt.KtRaw(code=arr)));
        }
        if tw.vertical_alignment {
            args.append(
                _named("verticalAlignment", kt.KtRaw(code=tw.vertical_alignment))
            );
        }
    } else {
        arr = tw.arrangement or tw.vertical_arrangement;
        if arr {
            args.append(_named("verticalArrangement", kt.KtRaw(code=arr)));
        }
        if tw.horizontal_alignment {
            args.append(
                _named(
                    "horizontalAlignment",
                    kt.KtRaw(code=tw.horizontal_alignment)
                )
            );
        }
        if tw.horizontal_arrangement and not tw.arrangement {
            args.append(
                _named(
                    "horizontalArrangement",
                    kt.KtRaw(code=tw.horizontal_arrangement)
                )
            );
        }
    }
    return args;
}

def _button_args(
    attrs: list, tw: any, emitter: ViewComposeEmitter
) -> list[kt.KtNamedArg] {
    args: list[kt.KtNamedArg] = [];
    on_click = _event_handler(attrs, {"onClick", "onclick"});
    needs_coro = _event_needs_coroutine(attrs, {"onClick", "onclick"});
    if needs_coro {
        emitter.needs_coroutine_scope = True;
    }
    if on_click {
        args.append(_named("onClick", _as_click_lambda(on_click, needs_coro)));
    }
    if tw.background_color or (tw.text_style and tw.text_style.color) {
        container = tw.background_color or "JacDesign.primary";
        content = (
            tw.text_style.color
            if tw.text_style and tw.text_style.color
            else "Color.White"
        );
        args.append(
            _named(
                "colors",
                kt.KtRaw(
                    code=(
                        "ButtonDefaults.buttonColors("
                        f"containerColor = {container}, "
                        f"contentColor = {content})"
                    )
                )
            )
        );
    }
    return args;
}

def _with_modifier(
    args: list[kt.KtNamedArg], class_name: str, emitter: ViewComposeEmitter
) -> list[kt.KtNamedArg] {
    if not class_name {
        return args;
    }
    tw = translate_tailwind(class_name);
    _note_unsupported(emitter, tw);
    layout_args = _layout_args(tw);
    if not layout_args {
        return args;
    }
    return layout_args + list(args);
}

impl ViewComposeEmitter.emit_view(view: (ViewElement | None)) -> (kt.KtNode | None) {
    if view is None {
        return kt.KtComposableCall(name="Column", args=[], content=[]);
    }
    tag = view.tag;
    children = _emit_children(view.children, self);
    class_name = _class_name_attr(view.attrs);

    if isinstance(tag, FragmentTag) {
        if len(children) == 1 {
            return children[0];
        }
        return kt.KtComposableCall(name="Column", args=[], content=children);
    }
    if isinstance(tag, DynamicTag) {
        self.diagnostics.append("unsupported: dynamic tag");
        return kt.KtRaw(code="/* unsupported: dynamic tag */");
    }
    if isinstance(tag, ComponentTag) {
        cname = _component_name(tag);
        if cname == "Show" and len(view.attrs) > 0 {
            return kt.KtComposableCall(name="Column", args=[], content=children);
        }
        if cname == "For" {
            return kt.KtComposableCall(name="Column", args=[], content=children);
        }
        if cname == "Spinner" {
            return kt.KtComposableCall(
                name="CircularProgressIndicator", args=[], content=[]
            );
        }
        if cname in ("Button",) or cname == "Button" {
            tw = translate_tailwind(class_name);
            _note_unsupported(self, tw);
            args = _button_args(view.attrs, tw, self);
            if not children {
                children = [_text_call(kt.KtLiteral(value=""))];
            }
            return kt.KtComposableCall(name="Button", args=args, content=children);
        }
        if cname in ("Card", "CardHeader", "CardBody", "StatsCard", "Alert", "Badge") {
            return kt.KtComposableCall(
                name="Card",
                args=_with_modifier([], class_name, self),
                content=children
            );
        }
        if cname in ("Input", "TextArea") {
            value = _attr_value(view.attrs, "value") or kt.KtLiteral(value="");
            args = [
                _named("value", value),
                _named("onValueChange", _input_value_change_lambda(view.attrs))
            ];
            if cname == "TextArea" {
                args.append(_named("maxLines", kt.KtLiteral(value=6)));
            }
            return kt.KtComposableCall(
                name="OutlinedTextField", args=args, content=[]
            );
        }
        if cname not in _CURATED {
            msg = f"unsupported component: {cname}";
            if msg not in self.diagnostics {
                self.diagnostics.append(msg);
            }
            diag = [kt.KtRaw(code=f"/* {msg} */")];
            return kt.KtComposableCall(
                name="Column", args=[], content=diag + children
            );
        }
        return kt.KtComposableCall(name="Column", args=[], content=children);
    }

    if not isinstance(tag, HostTag) {
        return kt.KtComposableCall(name="Column", args=[], content=children);
    }

    host = tag.name.lower();
    tw = translate_tailwind(class_name);
    _note_unsupported(self, tw);
    layout = _layout_name(tw.layout);

    if host in ("span", "p", "b", "strong", "code", "label", "pre")
    or host in ("h1", "h2", "h3", "h4", "h5", "h6") {
        text_expr: kt.KtNode = kt.KtLiteral(value="");
        for child in view.children {
            if (isinstance(child, TextChild) or isinstance(child, DynamicChild)) {
                converted = es_expr_to_kt(child.value);
                if converted {
                    text_expr = converted;
                    break;
                }
            }
        }
        if host == "pre" and not tw.text_style.font_family {
            tw.text_style.font_family = "FontFamily.Monospace";
        }
        return _text_call(text_expr, tw);
    }

    if host == "hr" {
        return kt.KtComposableCall(name="HorizontalDivider", args=[], content=[]);
    }
    if host == "button" {
        args = _button_args(view.attrs, tw, self);
        body = children if children else [_text_call(kt.KtLiteral(value=""))];
        return kt.KtComposableCall(name="Button", args=args, content=body);
    }
    if host == "input" {
        value = _attr_value(view.attrs, "value") or kt.KtLiteral(value="");
        args = [
            _named("value", value),
            _named("onValueChange", _input_value_change_lambda(view.attrs))
        ];
        ph = _attr_value(view.attrs, "placeholder");
        if ph {
            args.append(
                _named(
                    "placeholder",
                    kt.KtLambda(params=[], body=[_text_call(ph)])
                )
            );
        }
        return kt.KtComposableCall(
            name="OutlinedTextField", args=args, content=[]
        );
    }
    if host == "textarea" {
        value = _attr_value(view.attrs, "value") or kt.KtLiteral(value="");
        on_change = _event_handler(
            view.attrs, {"onChange", "onchange", "onValueChange"}
        );
        return kt.KtComposableCall(
            name="OutlinedTextField",
            args=[
                _named("value", value),
                _named(
                    "onValueChange",
                    on_change
                    if on_change
                    else kt.KtLambda(params=["it"], body=[])
                ),
                _named("maxLines", kt.KtLiteral(value=8))
            ],
            content=[]
        );
    }
    if host == "img" {
        self.diagnostics.append("img/AsyncImage deferred");
        return kt.KtRaw(
            code="/* img — AsyncImage deferred */ Box {}"
        );
    }
    if host in ("svg", "circle", "line", "polyline", "polygon", "path") {
        self.diagnostics.append("svg/canvas deferred");
        return kt.KtRaw(code="/* svg/canvas deferred */");
    }
    if host in ("select", "option") {
        return kt.KtComposableCall(
            name="Column", args=[], content=children
        );
    }

    if layout == "Hidden" {
        return kt.KtIf(
            test=kt.KtLiteral(value=False),
            consequent=children,
            alternate=[]
        );
    }

    args = _layout_args(tw);
    if host in ("ul", "ol") {
        return kt.KtComposableCall(name="Column", args=args, content=children);
    }
    if host == "li" {
        return kt.KtComposableCall(name="Row", args=args, content=children);
    }
    if host in ("table", "thead", "tbody") {
        return kt.KtComposableCall(name="Column", args=args, content=children);
    }
    if host in ("tr",) {
        return kt.KtComposableCall(name="Row", args=args, content=children);
    }
    if host in ("th", "td") {
        return kt.KtComposableCall(name="Box", args=args, content=children);
    }
    if host in ("header", "footer", "nav") and not class_name {
        return kt.KtComposableCall(name="Row", args=args, content=children);
    }
    return kt.KtComposableCall(name=layout, args=args, content=children);
}

impl ViewComposeEmitter.emit_component_view(comp: IntentComponent) -> str {
    view_node = self.emit_view(comp.view);
    if view_node is None {
        return "    Column(modifier = Modifier.fillMaxSize()) {\n    }";
    }
    src = kt_to_source(view_node).strip();
    lines = src.split("\n");
    return "\n".join([f"    {line}" if line else "" for line in lines]);
}
