import from collections.abc { Sequence }
import from jaclang.compiler.frontend.unitree {
    Ability,
    ArchHas,
    Archetype,
    Assignment,
    AstSymbolNode,
    AtomExpr,
    AtomTrailer,
    DisengageStmt,
    EdgeOpRef,
    EventSignature,
    ExprAsItem,
    FuncSignature,
    HasVar,
    ImplDef,
    InForStmt,
    InnerCompr,
    Name,
    ParamVar,
    SpecialVarRef,
    TypedCtxBlock,
    UniNode,
    VisitStmt
}
import from jaclang.compiler.frontend.constant { ExprCtx }
import from jaclang.compiler.frontend.constant { Tokens as Tok }
import from jaclang.compiler.passes.uni_pass { UniPass }
import from jaclang.compiler.frontend.diagnostics {
    E2004,
    E2005,
    W2006,
    W2007,
    E2008,
    W2029
}

def inform_from_walker(nd: UniNode) -> None;

walker SemanticAnalysisPass(UniPass) {
    def enter_archetype(nd: Archetype) -> None;
    def _check_archetype(nd: Archetype) -> None;
    def _property_type_names(methods: list[Ability]
    ) -> dict[str, str];

    def _update_ctx(nd: UniNode) -> None;
    def enter_has_var(nd: HasVar) -> None;
    def enter_param_var(nd: ParamVar) -> None;
    def enter_assignment(nd: Assignment) -> None;
    def enter_in_for_stmt(nd: InForStmt) -> None;
    def enter_expr_as_item(nd: ExprAsItem) -> None;
    def enter_inner_compr(nd: InnerCompr) -> None;
    def _change_atom_trailer_ctx(nd: AtomTrailer) -> None;
}
