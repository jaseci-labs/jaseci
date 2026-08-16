import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { EdgeDir, Tokens as Tok }
import from jaclang.compiler.passes.compose.jac_to_kotlin { JacToKotlin }
import from jaclang.compiler.passes.compose.kotlin_unparse { kt_to_source }
import from jaclang.compiler.passes.compose { kotlin_ast as kt }
import from jaclang.compiler.passes.compose.rpc_client {
    RpcClientEmitter,
    kotlin_default_literal,
    walker_to_pascal
}

def _jacgraph_tpl_dir() -> str {
    import os;
    import jaclang;
    return os.path.join(
        os.path.dirname(jaclang.__file__),
        "compiler",
        "passes",
        "compose",
        "gradle_templates",
        "jacgraph"
    );
}

glob _JACGRAPH_TPL_CACHE: dict[str, str] = {};

def _read_jacgraph_tpl(name: str, package_name: str) -> str {
    if name not in _JACGRAPH_TPL_CACHE {
        import os;
        with open(os.path.join(_jacgraph_tpl_dir(), name), encoding="utf-8") as f {
            _JACGRAPH_TPL_CACHE[name] = f.read();
        }
    }
    return _JACGRAPH_TPL_CACHE[name].replace("{{package}}", package_name);
}

impl emit_jacgraph_templates(package_name: str) -> dict[str, str] {
    anchor = _read_jacgraph_tpl("JacAnchor.kt", package_name);
    graph = _read_jacgraph_tpl("JacGraph.kt", package_name);
    serializers = _read_jacgraph_tpl("JacGraphSerializers.kt", package_name);
    walker_src = _read_jacgraph_tpl("Walker.kt", package_name);
    return {
        "JacAnchor.kt": anchor,
        "JacGraph.kt": graph,
        "JacGraphSerializers.kt": serializers,
        "Walker.kt": walker_src
    };
}

def _jac_type_text(type_expr: (uni.Expr | None)) -> str {
    if type_expr is None {
        return "";
    }
    if isinstance(type_expr, uni.Name) {
        return type_expr.value;
    }
    if isinstance(type_expr, uni.AtomExpr) {
        return type_expr.sym_name;
    }
    return str(type_expr);
}

def _has_var_type(has_var: uni.HasVar) -> str {
    tag = has_var.type_tag;
    if tag and tag.tag {
        return _jac_type_text(tag.tag);
    }
    return "Any";
}

def _has_var_default(has_var: uni.HasVar) -> (str | None) {
    if has_var.value is None {
        return None;
    }
    import from jaclang.compiler.passes.compose.jac_to_kotlin { jac_expr_to_kt }
    kt_val = jac_expr_to_kt(has_var.value);
    if kt_val {
        return kt_to_source(kt_val);
    }
    return None;
}

def _emit_node_class(arch: uni.Archetype, emitter: RpcClientEmitter) -> str {
    name = arch.name.sym_name if arch.name else "Node";
    fields: list[str] = [];
    for hv in arch.get_has_vars() {
        fname = hv.name.sym_name if hv.name else "";
        if not fname {
            continue;
        }
        ftype = emitter.jac_type_to_kotlin(_has_var_type(hv));
        default_lit = kotlin_default_literal(_has_var_type(hv), None);
        if hv.value is not None {
            default_lit = _has_var_default(hv);
        }
        if default_lit is not None {
            fields.append(f"    var {fname}: {ftype} = {default_lit}");
        } elif ftype.endswith('?') {
            fields.append(f"    var {fname}: {ftype} = null");
        } else {
            fields.append(f"    var {fname}: {ftype}");
        }
    }
    body = ",\n".join(fields);
    if body {
        body = "\n" + body + ",\n";
    }
    return (
        f"@Serializable\nclass {name}({body}) : Node() {{\n"
        f"    override val id: String = java.util.UUID.randomUUID().toString()\n"
        f'    override val type: String = "{name}"\n'
        f"}}\n"
    );
}

def _is_pub_walker(manifest: any, walker_name: str) -> bool {
    access: dict[str, bool] = getattr(manifest, 'walker_access', {}) or {};
    return not access.get(walker_name, True);
}

def _collect_pub_walker_archetypes(
    mod: uni.Module, manifest: any
) -> list[uni.Archetype] {
    walkers: list[uni.Archetype] = [];
    pub_names: set[str] = set();
    if manifest is not None {
        access: dict[str, bool] = getattr(manifest, 'walker_access', {}) or {};
        for name in access.keys() {
            if _is_pub_walker(manifest, name) {
                pub_names.add(name);
            }
        }
        bindings: dict[str, any] = getattr(manifest, 'bindings', {}) or {};
        for name in bindings.keys() {
            if _is_pub_walker(manifest, name) {
                pub_names.add(name);
            }
        }
    }
    for item in (mod.body or []) {
        if not isinstance(item, uni.Archetype) {
            continue;
        }
        if item.arch_kind != "walker" {
            continue;
        }
        wname = item.name.sym_name if item.name else "";
        if pub_names and wname not in pub_names {
            continue;
        }
        walkers.append(item);
    }
    return walkers;
}

def _collect_node_archetypes(mod: uni.Module) -> list[uni.Archetype] {
    nodes: list[uni.Archetype] = [];
    for item in (mod.body or []) {
        if isinstance(item, uni.Archetype) and item.arch_kind == "node" {
            nodes.append(item);
        }
    }
    return nodes;
}

def _is_root_entry_ability(abil: uni.Ability) -> bool {
    if not isinstance(abil.signature, uni.EventSignature) {
        return False;
    }
    if abil.signature.event.name != Tok.KW_ENTRY.name {
        return False;
    }
    tag = abil.signature.arch_tag_info;
    if tag is None {
        return True;
    }
    if isinstance(tag, uni.Name) {
        return tag.sym_name in ("Root", "root");
    }
    if isinstance(tag, uni.AtomExpr) {
        return tag.sym_name in ("Root", "root");
    }
    return False;
}

def _walker_entry_body(arch: uni.Archetype) -> (list[uni.UniNode] | None) {
    for abil in arch.get_methods() {
        if not _is_root_entry_ability(abil) {
            continue;
        }
        body = abil.body;
        if isinstance(body, uni.ImplDef) {
            body = body.body;
        }
        if isinstance(body, list) {
            return body;
        }
        return None;
    }
    return None;
}

def _walker_has_fields(arch: uni.Archetype, emitter: RpcClientEmitter) -> list[str] {
    params: list[str] = [];
    for hv in arch.get_has_vars() {
        fname = hv.name.sym_name if hv.name else "";
        if not fname {
            continue;
        }
        ftype = emitter.jac_type_to_kotlin(_has_var_type(hv));
        params.append(f"val {fname}: {ftype}");
    }
    return params;
}

def _emit_walker_class(
    arch: uni.Archetype, lowerer: JacToKotlin, result: SvLowerResult
) -> str {
    wname = arch.name.sym_name if arch.name else "Walker";
    pascal = walker_to_pascal(wname);
    emitter = RpcClientEmitter();
    params = _walker_has_fields(arch, emitter);
    param_src = ", ".join(params);
    body_nodes = _walker_entry_body(arch);
    if body_nodes is None {
        result.diagnostics.append(
            f"sv_lower: walker '{wname}' has no supported 'with Root entry' ability"
        );
        return "";
    }
    lowerer.walker_mode = True;
    lowerer.declared_locals = set();
    stmts = lowerer.convert_stmts(body_nodes);
    for diag in lowerer.diagnostics {
        result.diagnostics.append(diag);
    }
    if not stmts {
        body_src = "";
    } else {
        body_src = kt_to_source(kt.KtBlock(body=stmts));
        if body_src.startswith("{\n") and body_src.endswith("\n}") {
            body_src = body_src[2:-2];
        }
    }
    if body_src {
        body_src = "\n        " + body_src.replace("\n", "\n        ") + "\n    ";
    }
    return (
        f"class {pascal}({param_src}) : Walker() {{\n"
        f"    override fun onRootEntry(here: Node) {{{body_src}}}\n"
        f"}}\n"
    );
}

def _emit_sv_nodes(
    mod: uni.Module, manifest: any, package_name: str, result: SvLowerResult
) -> str {
    emitter = RpcClientEmitter(package_name=package_name);
    blocks: list[str] = [];
    for node_arch in _collect_node_archetypes(mod) {
        name = node_arch.name.sym_name if node_arch.name else "Node";
        result.node_names.append(name);
        blocks.append(_emit_node_class(node_arch, emitter));
    }
    lowerer = JacToKotlin(walker_mode=True);
    for walker_arch in _collect_pub_walker_archetypes(mod, manifest) {
        wsrc = _emit_walker_class(walker_arch, lowerer, result);
        if wsrc {
            blocks.append(wsrc);
        }
    }
    if not blocks {
        return "";
    }
    return (
        f"package {package_name}\n\n" "import kotlinx.serialization.Serializable\n\n"
        + "\n".join(blocks)
    );
}

impl run_sv_lower(mod: uni.Module, manifest: any, package_name: str) -> SvLowerResult {
    result = SvLowerResult();
    nodes_src = _emit_sv_nodes(mod, manifest, package_name, result);
    if nodes_src {
        result.files["SvNodes.kt"] = nodes_src;
    }
    return result;
}
