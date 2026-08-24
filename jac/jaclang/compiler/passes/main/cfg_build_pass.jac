import from typing { cast }
import from jaclang.jac0core.unitree {
    Ability,
    Archetype,
    AssertStmt,
    AstElseBodyNode,
    AtomUnit,
    AwaitingClause,
    BoolExpr,
    CfgExpr,
    CodeBlockStmt,
    CtrlStmt,
    DictCompr,
    DisengageStmt,
    ElseIf,
    ElseStmt,
    Except,
    Expr,
    FinallyStmt,
    ForeverStmt,
    GenCompr,
    GlobalVars,
    IfElseExpr,
    IfStmt,
    ImplDef,
    InForStmt,
    InnerCompr,
    IterForStmt,
    JsxSlot,
    LambdaExpr,
    ListCompr,
    MatchCase,
    MatchStmt,
    ModuleCode,
    Name,
    OpenStmt,
    RaiseStmt,
    ReturnStmt,
    SemDef,
    Semi,
    SetCompr,
    SwitchCase,
    SwitchStmt,
    Test,
    Token,
    TryStmt,
    TypeAlias,
    TypedCtxBlock,
    UniCFGNode,
    UniNode,
    WhileStmt,
    WithStmt
}
import from jaclang.jac0core.passes.uni_pass { UniPass }

class CFGBuildPass(UniPass) {
    static has PROVIDES: tuple = ('cfg', );

    def before_pass(self: CFGBuildPass) -> None;
    def link_bbs(self: CFGBuildPass, source: UniCFGNode, target: UniCFGNode) -> None;
    def _link_sequential(self: CFGBuildPass, body: Sequence[CodeBlockStmt]) -> None;
    def _exit_wired(self: CFGBuildPass, nd: UniCFGNode) -> bool;
    def _connect_tails(
        self: CFGBuildPass, parent: UniNode, target: UniCFGNode
    ) -> None;

    def _link_body_tails_to_header(
        self: CFGBuildPass, nd: WhileStmt | ForeverStmt | InForStmt | IterForStmt
    ) -> None;

    def _is_terminal(self: CFGBuildPass, nd: UniNode) -> bool;
    def _find_parent_of_types(
        self: CFGBuildPass, nd: UniNode, types: tuple[type[UniCFGNode], ...]
    ) -> (UniCFGNode | None);

    def _next_in_body(
        self: CFGBuildPass, body: Sequence[CodeBlockStmt], child: UniNode
    ) -> (UniCFGNode | None);

    def _find_next_cfg_stmt_after(
        self: CFGBuildPass, parent: UniNode, child: UniNode
    ) -> (UniCFGNode | None);

    def _find_next_cfg_stmt_after_branch(
        self: CFGBuildPass, nd: UniNode
    ) -> (UniCFGNode | None);

    def _wire_bool_operands(
        self: CFGBuildPass,
        values: list[CfgExpr],
        op_is_and: bool,
        true_target: (UniCFGNode | None),
        false_target: (UniCFGNode | None)
    ) -> CfgExpr;

    def _wire_bool_chain(
        self: CFGBuildPass,
        values: list[CfgExpr],
        op_is_and: bool,
        true_target: (UniCFGNode | None),
        false_target: (UniCFGNode | None)
    ) -> CfgExpr;

    def _set_and_link(
        self: CFGBuildPass,
        cfg: CfgExpr,
        true_target: (UniCFGNode | None),
        false_target: (UniCFGNode | None)
    ) -> None;

    def enter_node(self: CFGBuildPass, nd: UniNode) -> None;
    def enter_if_stmt(self: CFGBuildPass, nd: IfStmt) -> None;
    def enter_else_if(self: CFGBuildPass, nd: ElseIf) -> None;
    def enter_assert_stmt(self: CFGBuildPass, nd: AssertStmt) -> None;
    def enter_match_stmt(self: CFGBuildPass, nd: MatchStmt) -> None;
    def exit_bool_expr(self: CFGBuildPass, nd: BoolExpr) -> None;
    def exit_if_else_expr(self: CFGBuildPass, nd: IfElseExpr) -> None;
    def exit_if_stmt(self: CFGBuildPass, nd: IfStmt) -> None;
    def exit_else_if(self: CFGBuildPass, nd: ElseIf) -> None;
    def exit_else_stmt(self: CFGBuildPass, nd: ElseStmt) -> None;
    def exit_while_stmt(self: CFGBuildPass, nd: WhileStmt) -> None;
    def exit_forever_stmt(self: CFGBuildPass, nd: ForeverStmt) -> None;
    def exit_in_for_stmt(self: CFGBuildPass, nd: InForStmt) -> None;
    def exit_iter_for_stmt(self: CFGBuildPass, nd: IterForStmt) -> None;
    def exit_list_compr(self: CFGBuildPass, nd: ListCompr) -> None;
    def exit_set_compr(self: CFGBuildPass, nd: SetCompr) -> None;
    def exit_gen_compr(self: CFGBuildPass, nd: GenCompr) -> None;
    def exit_dict_compr(self: CFGBuildPass, nd: DictCompr) -> None;
    def _wire_compr_filters(
        self: CFGBuildPass, target_node: UniCFGNode, comprs: list[InnerCompr]
    ) -> None;

    def exit_ctrl_stmt(self: CFGBuildPass, nd: CtrlStmt) -> None;
    def exit_try_stmt(self: CFGBuildPass, nd: TryStmt) -> None;
    def exit_except(self: CFGBuildPass, nd: Except) -> None;
    def exit_finally_stmt(self: CFGBuildPass, nd: FinallyStmt) -> None;
    def exit_match_stmt(self: CFGBuildPass, nd: MatchStmt) -> None;
    def exit_match_case(self: CFGBuildPass, nd: MatchCase) -> None;
    def exit_switch_stmt(self: CFGBuildPass, nd: SwitchStmt) -> None;
    def exit_switch_case(self: CFGBuildPass, nd: SwitchCase) -> None;
    def exit_with_stmt(self: CFGBuildPass, nd: WithStmt) -> None;
    def exit_typed_ctx_block(self: CFGBuildPass, nd: TypedCtxBlock) -> None;
    def exit_open_stmt(self: CFGBuildPass, nd: OpenStmt) -> None;
    def exit_jsx_slot(self: CFGBuildPass, nd: JsxSlot) -> None;
    def exit_ability(self: CFGBuildPass, nd: Ability) -> None;
    def exit_archetype(self: CFGBuildPass, nd: Archetype) -> None;
    def exit_impl_def(self: CFGBuildPass, nd: ImplDef) -> None;
    def exit_module_code(self: CFGBuildPass, nd: ModuleCode) -> None;
    def exit_test(self: CFGBuildPass, nd: Test) -> None;
}

obj CoalesceBBPass(UniPass) {
    has basic_blocks: dict[int, dict[str, list[UniCFGNode]]] = {},
        bb_counter: int = 0;

    def before_pass -> None;
    def get_bb(nd: UniCFGNode) -> list[UniCFGNode];
    def enter_node(nd: UniNode) -> None;
    def printgraph_cfg -> str;
    def _node_label(nd: UniNode) -> str;
    def _has_bool_sc(condition: Expr) -> bool;
}

def _is_structural_child(nd: UniNode) -> bool;
def cfg_dot_from_file(file_name: str) -> str;
