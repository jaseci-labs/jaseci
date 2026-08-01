import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.ecmascript.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}

import type from jaclang.compiler.passes.ecmascript.view_ir { ViewElement }
import from jaclang.compiler.passes.compose.kotlin_ast { KtNode }

def _es_leaf(leaf: (es.Expression | KtNode)) -> es.Expression {
    assert not isinstance(leaf, KtNode) , "ComposeBackend ES lowering receives estree expressions, not Kotlin nodes";
    return leaf;
}

impl ComposeBackend.name -> str {
    return "compose";
}

impl ComposeBackend.runtime_module -> str {
    return "@jac/runtime";
}

impl ComposeBackend.jsx_factory_name -> str {
    return "__jacComposeView";
}

impl ComposeBackend.import_source(symbol: str) -> str {
    return "@jac/runtime";
}

impl ComposeBackend.required_globals -> list[str] {
    return ["__jacComposeView"];
}

impl ComposeBackend.runtime_source_basename -> str {
    return "compose_runtime.jac";
}

impl ComposeBackend.vite_aliases -> dict[str, str] {
    return {};
}

impl ComposeBackend.vite_plugin_lines -> (tuple[str, str] | None) {
    return None;
}

impl ComposeBackend.build_entry_script(
    entry_module: str, install_global_handlers: bool = True
) -> str {
    return (
        f"import './{entry_module}.js';\n"
        "// Compose Android target — entry shim for runtime resolution only.\n"
    );
}

impl ComposeBackend.build_pages_entry_script(
    entry_module: str, auth_redirect: str, has_app_wrapper: bool
) -> str {
    return (
        f"import './{entry_module}.js';\n"
        "// Compose Android target — pages entry shim for runtime resolution only.\n"
    );
}

impl ComposeBackend.lower_state_field(s: StateField) -> list[es.Statement] {
    declarator = es.VariableDeclarator(
        id=es.Identifier(name=s.name), init=_es_leaf(s.init_expr)
    );
    return [es.VariableDeclaration(declarations=[declarator], kind="const")];
}

impl ComposeBackend.lower_ref_field(r: RefField) -> list[es.Statement] {
    declarator = es.VariableDeclarator(
        id=es.Identifier(name=r.name), init=_es_leaf(r.init_expr)
    );
    return [es.VariableDeclaration(declarations=[declarator], kind="const")];
}

impl ComposeBackend.lower_state_read(name: str) -> es.Expression {
    return es.Identifier(name=name);
}

impl ComposeBackend.lower_view_expr(expr: es.Expression) -> es.Expression {
    return expr;
}

impl ComposeBackend.lower_state_update(u: StateUpdate) -> es.Expression {
    return es.AssignmentExpression(
        operator="=", left=es.Identifier(name=u.name), right=_es_leaf(u.value)
    );
}

impl ComposeBackend.lower_effect(e: Effect) -> list[es.Statement] {
    return [];
}

impl ComposeBackend.lower_async_boundary(a: AsyncBoundary) -> es.Expression {
    return es.Identifier(name="null");
}

impl ComposeBackend.lower_view(view: ViewElement, sync_loc: any) -> es.Expression {
    tag = view.tag?.name or "View";
    return es.CallExpression(
        callee=es.Identifier(name="__jacComposeView"), arguments=[es.Literal(value=tag)]
    );
}

impl ComposeBackend.runtime_symbols(intent: any) -> list[str] {
    return [];
}
