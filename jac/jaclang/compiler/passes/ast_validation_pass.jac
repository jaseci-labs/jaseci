import keyword;
import from jaclang.compiler.frontend.unitree {
    Ability,
    ArchHas,
    Archetype,
    Assignment,
    AtomTrailer,
    BinaryExpr,
    ContextAwareNode,
    CtrlStmt,
    DeleteStmt,
    ElseStmt,
    Enum,
    ExprAsItem,
    ExprStmt,
    ForeverStmt,
    FuncCall,
    FuncSignature,
    GlobalVars,
    HasVar,
    IfStmt,
    ImplDef,
    Import,
    InForStmt,
    InnerCompr,
    IterForStmt,
    JsxElement,
    JsxNormalAttribute,
    JsxSlot,
    KWPair,
    LambdaExpr,
    ListVal,
    MatchStmt,
    Module,
    ModuleCode,
    Name,
    ParamVar,
    ReturnStmt,
    SpecialVarRef,
    SwitchStmt,
    Token,
    TryStmt,
    TupleVal,
    UniNode,
    WhileStmt,
    WithStmt,
    YieldExpr
}
import from jaclang.compiler.frontend.constant { CodeContext, Tokens as Tok }
import from jaclang.compiler.passes.uni_pass { UniPass }
import from jaclang.compiler.frontend.diagnostics {
    E0010,
    E0020,
    E0023,
    E0024,
    E0031,
    E0040,
    E0041,
    E0042,
    E0043,
    E0044,
    E0050,
    E0051,
    E0052,
    E0055,
    E0058,
    E0063,
    E0065,
    E0066,
    E0067,
    E0071,
    E0075,
    E0076,
    E0082,
    E2019,
    E2020,
    E2021,
    E2022,
    E2024,
    E2084,
    W2019,
    W2020,
    W2021
}

walker ASTValidationPass(UniPass) {
    def enter_try_stmt(nd: TryStmt) -> None;
    def enter_match_stmt(nd: MatchStmt) -> None;
    def enter_module_code(nd: ModuleCode) -> None;
    def enter_binary_expr(nd: BinaryExpr) -> None;
    def enter_name(nd: Name) -> None;
    def enter_func_signature(nd: FuncSignature) -> None;
    def enter_iter_for_stmt(nd: IterForStmt) -> None;
    def enter_import(nd: Import) -> None;
    def enter_enum(nd: Enum) -> None;
    def enter_switch_stmt(nd: SwitchStmt) -> None;
    def enter_assignment(nd: Assignment) -> None;
    def _check_render_phase_state_write(nd: Assignment
    ) -> None;

    def _scope_declares_state(scope: (Ability | ImplDef), name: str
    ) -> bool;

    def _returns_jsx(scope: (Ability | ImplDef)) -> bool;
    def enter_in_for_stmt(nd: InForStmt) -> None;
    def enter_inner_compr(nd: InnerCompr) -> None;
    def enter_has_var(nd: HasVar) -> None;
    def enter_expr_as_item(nd: ExprAsItem) -> None;
    def enter_delete_stmt(nd: DeleteStmt) -> None;
    def _reject_non_bindable(target: object) -> None;
    def enter_param_var(nd: ParamVar) -> None;
    def enter_yield_expr(nd: YieldExpr) -> None;
    def enter_ctrl_stmt(nd: CtrlStmt) -> None;
    def enter_global_vars(nd: GlobalVars) -> None;
    def enter_func_call(nd: FuncCall) -> None;
    def enter_archetype(nd: Archetype) -> None;
    def enter_jsx_slot(nd: JsxSlot) -> None;
    def enter_expr_stmt(nd: ExprStmt) -> None;
    def _check_slot_body(stmts: list[UniNode], in_loop: bool, loop_kw: str
    ) -> None;

    def _check_slot_else(else_body: object, in_loop: bool, loop_kw: str
    ) -> None;

    def _slot_emits_keyless_jsx(stmts: list[UniNode]) -> bool;
    def _slot_has_key_attr(el: JsxElement) -> bool;
}
