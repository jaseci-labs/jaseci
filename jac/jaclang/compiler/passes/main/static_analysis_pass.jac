import from collections.abc { Sequence }
import from jaclang.jac0core.unitree {
    Ability,
    Archetype,
    Assignment,
    AtomTrailer,
    BinaryExpr,
    Bool,
    CompareExpr,
    ConnectOp,
    CtrlStmt,
    DisconnectOp,
    DisengageStmt,
    EdgeOpRef,
    ElseIf,
    ElseStmt,
    EventSignature,
    FString,
    FilterCompr,
    FinallyStmt,
    Float,
    ForeverStmt,
    FormattedValue,
    FuncSignature,
    IfStmt,
    ImplDef,
    Import,
    InForStmt,
    Int,
    IterForStmt,
    KWPair,
    MatchPattern,
    Module,
    ModuleItem,
    ModulePath,
    Name,
    Null,
    RaiseStmt,
    ReturnStmt,
    Semi,
    SubTag,
    Token,
    UniNode,
    UniScopeNode,
    WhileStmt
}
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.constant { ExprCtx, SymbolType }
import from jaclang.jac0core.diagnostics {
    W1103,
    W1104,
    W2001,
    W2002,
    W2003,
    W2058,
    W2063,
    W2070,
    W2074,
    W2075,
    E2018,
    E2027,
    E2055,
    E2083
}

obj StaticAnalysisPass(Transform[Module, Module]) {
    has ir_in: Module,
        prog: any,
        cancel_token: any = None;

    static has PROVIDES: tuple = ('static-checks', );

    def postinit -> None;
    def transform(ir_in: Module) -> Module;
    def _check_unused_symbols(scope: UniScopeNode) -> None;
    def _check_undefined_names(mod: Module) -> None;
    def _literal_case_suggestion(name: str) -> (str | None);
    def _osp_shape_position(name_nd: Name) -> (str | None);
    def _native_type_position(name_nd: Name) -> (str | None);
    def _check_unreachable_code(mod: Module) -> None;
    def _check_semantic_patterns(mod: Module) -> None;
    def _check_redundant_imports(mod: Module) -> None;
    def _check_client_imports(mod: Module) -> None;
    def _check_placement_warnings(mod: Module) -> None;
}
