import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.compose { kotlin_ast as kt }
import from jaclang.compiler.passes.compose.surface {
    is_compose_primitive,
    is_compose_event_attr
}
import from jaclang.compiler.passes.compose.view_ir {
    ComposeElement,
    ComposeAttr,
    ComposeTextChild,
    ComposeDynamicChild,
    ComposeRawChild,
    ComposeElementChild,
    ComposeIfChild,
    ComposeEachChild
}
import from jaclang.compiler.passes.compose.jac_to_kotlin { JacToKotlin }
import from jaclang.compiler.passes.compose.compose_native_emit { ComposeNativeEmitter }

def _tag_name(nd: uni.JsxElement) -> (str | None) {
    if nd.dynamic_tag is not None {
        return None;
    }
    if nd.is_fragment or not nd.name {
        return "";
    }
    parts = nd.name.parts or [];
    if not parts or not isinstance(parts[0], uni.Name) {
        return None;
    }
    return parts[0].value;
}

def _is_user_component(name: str) -> bool {
    if not name {
        return False;
    }
    return name[0].isupper() and not is_compose_primitive(name);
}

def _jsx_attr_name(name_nd: any) -> str {
    if isinstance(name_nd, uni.Name) {
        return name_nd.sym_name;
    }
    if isinstance(name_nd, uni.Token) {
        return name_nd.value;
    }
    return str(name_nd);
}

def _kt_string_content(kt_node: kt.KtNode) -> (str | None) {
    if isinstance(kt_node, kt.KtLiteral) and isinstance(kt_node.value, str) {
        return kt_node.value;
    }
    if isinstance(kt_node, kt.KtStringTemplate) {
        parts: list[str] = [];
        for part in kt_node.parts {
            if isinstance(part, str) {
                parts.append(part);
            } else {
                return None;
            }
        }
        return ''.join(parts);
    }
    return None;
}

def _jsx_expr_to_kt(
    expr: (uni.UniNode | None), builder: ComposeViewBuilder
) -> (kt.KtNode | None) {
    if expr is None {
        return None;
    }
    if isinstance(expr, uni.JsxElement) {
        built = builder.build_element(expr);
        if built is None {
            return None;
        }
        return ComposeNativeEmitter()._emit_element(built);
    }
    return builder.lowerer.convert_expr(expr);
}

def _raw_kotlin_from_children(
    children:
        list[
            ComposeTextChild
                | ComposeDynamicChild
                | ComposeRawChild
                | ComposeElementChild
                | ComposeIfChild
                | ComposeEachChild
        ]
) -> (str | None) {
    parts: list[str] = [];
    for child in children {
        if isinstance(child, ComposeTextChild) {
            if isinstance(child.value, kt.KtLiteral)
                and isinstance(child.value.value, str) {
                parts.append(child.value.value);
            }
        }
    }
    if not parts {
        return None;
    }
    return "\n".join(parts);
}

impl ComposeViewBuilder.build_element(nd: uni.JsxElement) -> (ComposeElement | None) {
    cached = self._view_by_node.get(id(nd));
    if cached is not None {
        return cached;
    }
    tag = _tag_name(nd);
    if tag is None {
        self.diagnostics.append(
            "dynamic JSX tags are unsupported in Compose surface v1"
        );
        return None;
    }
    if tag == "" {
        children = self.build_children(list(nd.children or []));
        if len(children) == 1 and isinstance(children[0], ComposeElementChild) {
            return children[0].element;
        }
        elem = ComposeElement(name="Column", attrs=[], children=children, jac_node=nd);
        self._view_by_node[id(nd)] = elem;
        return elem;
    }
    if not tag[0].isupper() {
        self.diagnostics.append(
            f"lowercase host tag <{tag}> is not supported — use Compose primitives (Column, Text, …)"
        );
        return None;
    }
    attrs: list[ComposeAttr] = [];
    for attr in (nd.attributes or []) {
        if isinstance(attr, uni.JsxNormalAttribute) {
            aname = _jsx_attr_name(attr.name);
            if attr.value is None {
                continue;
            }
            kt_val = _jsx_expr_to_kt(attr.value, self);
            if kt_val is None {
                continue;
            }
            attrs.append(
                ComposeAttr(
                    name=aname,
                    value=kt_val,
                    is_event=is_compose_event_attr(aname),
                    jac_node=attr
                )
            );
        } elif isinstance(attr, uni.JsxSpreadAttribute) {
            self.diagnostics.append(
                "spread attributes are unsupported in Compose surface v1"
            );
        }
    }
    children = self.build_children(list(nd.children or []));
    if tag == "Raw" {
        raw_code: (str | None) = None;
        for attr in attrs {
            if attr.name == "kotlin" {
                raw_code = _kt_string_content(attr.value);
                if raw_code is None and isinstance(attr.value, kt.KtRaw) {
                    raw_code = attr.value.code;
                }
                if raw_code is not None {
                    break;
                }
            }
        }
        if raw_code is None {
            raw_code = _raw_kotlin_from_children(children);
        }
        if raw_code is None {
            self.diagnostics.append(
                "<Raw> requires a kotlin= attribute or raw Kotlin text children"
            );
            return None;
        }
        elem = ComposeElement(
            name="Raw",
            attrs=[
                ComposeAttr(
                    name="kotlin",
                    value=kt.KtRaw(code=raw_code),
                    is_event=False,
                    jac_node=nd
                )
            ],
            children=[ComposeRawChild(code=raw_code, jac_node=nd)],
            jac_node=nd
        );
        self._view_by_node[id(nd)] = elem;
        return elem;
    }
    elem = ComposeElement(
        name=tag,
        is_user_component=_is_user_component(tag),
        attrs=attrs,
        children=children,
        jac_node=nd
    );
    self._view_by_node[id(nd)] = elem;
    return elem;
}

impl ComposeViewBuilder.build_children(
    children: list[uni.UniNode]
) -> list[
    ComposeTextChild
        | ComposeDynamicChild
        | ComposeRawChild
        | ComposeElementChild
        | ComposeIfChild
        | ComposeEachChild
] {
    result:
        list[
            ComposeTextChild
                | ComposeDynamicChild
                | ComposeElementChild
                | ComposeIfChild
                | ComposeEachChild
        ] = [];
    for child in children {
        if isinstance(child, uni.JsxText) {
            text = child.get_normalized_text();
            if not text {
                continue;
            }
            if text.startswith('"') and text.endswith('"') and len(text) >= 2 {
                text = text[1:-1];
            } elif text.startswith("'") and text.endswith("'") and len(text) >= 2 {
                text = text[1:-1];
            }
            result.append(
                ComposeTextChild(value=kt.KtLiteral(value=text), jac_node=child)
            );
        } elif isinstance(child, uni.JsxComment) {
            continue;
        } elif isinstance(child, uni.JsxExpression) {
            lifted = self._lift_control_flow(child);
            if lifted is not None {
                result.append(lifted);
            } else {
                kt_val = self.lowerer.convert_expr(child.expr);
                if kt_val is None {
                    continue;
                }
                if isinstance(kt_val, kt.KtLiteral) and isinstance(kt_val.value, str) {
                    result.append(ComposeTextChild(value=kt_val, jac_node=child));
                } else {
                    result.append(ComposeDynamicChild(value=kt_val, jac_node=child));
                }
            }
        } elif isinstance(child, uni.JsxElement) {
            built = self.build_element(child);
            if built is not None {
                result.append(ComposeElementChild(element=built, jac_node=child));
            }
        }
    }
    return result;
}

impl ComposeViewBuilder._lift_control_flow(
    child: uni.JsxExpression
) -> (ComposeIfChild | ComposeEachChild | None) {
    expr = child.expr;
    if isinstance(expr, uni.ListCompr) {
        return self._lift_each(child, expr);
    }
    if isinstance(expr, uni.IfElseExpr) {
        return self._lift_if(child, expr);
    }
    return None;
}

impl ComposeViewBuilder._lift_each(
    child: uni.JsxExpression, compr: uni.ListCompr
) -> (ComposeEachChild | None) {
    if len(compr.compr) != 1 {
        return None;
    }
    inner = compr.compr[0];
    out_expr = compr.out_expr;
    if not isinstance(out_expr, uni.JsxElement) {
        return None;
    }
    item_name = 'item';
    if isinstance(inner.target, uni.Name) {
        item_name = inner.target.sym_name;
    }
    items = self.lowerer.convert_expr(inner.collection);
    body_elem = self.build_element(out_expr);
    if items is None or body_elem is None {
        return None;
    }
    return ComposeEachChild(
        items=items,
        item_name=item_name,
        body=[ComposeElementChild(element=body_elem, jac_node=out_expr)],
        jac_node=child
    );
}

impl ComposeViewBuilder._lift_if(
    child: uni.JsxExpression, ternary: uni.IfElseExpr
) -> (ComposeIfChild | None) {
    cons_inner = ternary.value;
    alt_inner = ternary.else_value;
    if not isinstance(cons_inner, uni.JsxElement) {
        return None;
    }
    cons = self.build_element(cons_inner);
    if cons is None {
        return None;
    }
    alt_children: list = [];
    if isinstance(alt_inner, uni.JsxElement) {
        alt_elem = self.build_element(alt_inner);
        if alt_elem is not None {
            alt_children = [ComposeElementChild(element=alt_elem, jac_node=alt_inner)];
        }
    }
    test = self.lowerer.convert_expr(ternary.condition);
    if test is None {
        return None;
    }
    return ComposeIfChild(
        `test=test,
        consequent=[ComposeElementChild(element=cons, jac_node=cons_inner)],
        alternate=alt_children,
        jac_node=child
    );
}
