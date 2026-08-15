import ast as ast3;
import from collections.abc { Sequence }
import from jaclang.jac0core.unitree {
    Ability,
    Archetype,
    AstSymbolNode,
    AtomTrailer,
    ContextAwareNode,
    Enum,
    Except,
    ExprAsItem,
    FuncSignature,
    ImplDef,
    KWPair,
    ModulePath,
    ParamVar,
    TypeAlias,
    UniNode
}
import from jaclang.jac0core.constant { CodeContext }
import from jaclang.jac0core.passes { UniPass }

obj PyJacAstLinkPass(UniPass) {
    def link_jac_py_nodes(jac_node: UniNode, py_nodes: list[ast3.AST]) -> None;
    def exit_module_path(nd: ModulePath) -> None;
    def exit_type_alias(nd: TypeAlias) -> None;
    def exit_archetype(nd: Archetype) -> None;
    def exit_enum(nd: Enum) -> None;
    def exit_ability(nd: Ability) -> None;
    def exit_impl_def(nd: ImplDef) -> None;
    def exit_param_var(nd: ParamVar) -> None;
    def exit_except(nd: Except) -> None;
    def exit_expr_as_item(nd: ExprAsItem) -> None;
    def exit_k_w_pair(nd: KWPair) -> None;
    def exit_atom_trailer(nd: AtomTrailer) -> None;
}
