import from dataclasses { field }
import from jaclang.compiler.frontend.unitree {
    Ability,
    ArchHas,
    Archetype,
    Assignment,
    AstSymbolNode,
    AtomTrailer,
    BinaryExpr,
    DictCompr,
    ElseIf,
    ElseStmt,
    Enum,
    Except,
    ExprAsItem,
    FinallyStmt,
    ForeverStmt,
    GenCompr,
    GlobalVars,
    HasVar,
    IfStmt,
    ImplDef,
    Import,
    InForStmt,
    InnerCompr,
    IterForStmt,
    LambdaExpr,
    ListCompr,
    MatchCase,
    Module,
    ModuleItem,
    ModulePath,
    Name,
    OpenStmt,
    ParamVar,
    SemDef,
    SetCompr,
    SwitchCase,
    Test,
    Token,
    TryStmt,
    TypeAlias,
    TypeParam,
    TypedCtxBlock,
    UniNode,
    UniScopeNode,
    WhileStmt,
    WithStmt,
    bind_assignment_targets,
    def_insert_unpacking,
    find_python_scope_node_of,
    record_cross_scope_rebind,
    rebind_or_def_insert
}
import from jaclang.compiler.frontend.constant { SymbolAccess }
import from jaclang.compiler.passes.uni_pass { UniPass }
import from jaclang.compiler.frontend.diagnostics { E0064, E0077 }

glob TEST_ASSERT_METHOD_NAMES = (
         'assertAlmostEqual',
         'assertCountEqual',
         'assertDictEqual',
         'assertEndsWith',
         'assertEqual',
         'assertFalse',
         'assertGreater',
         'assertGreaterEqual',
         'assertHasAttr',
         'assertIn',
         'assertIs',
         'assertIsInstance',
         'assertIsNone',
         'assertIsNot',
         'assertIsNotNone',
         'assertIsSubclass',
         'assertLess',
         'assertLessEqual',
         'assertListEqual',
         'assertLogs',
         'assertMultiLineEqual',
         'assertNoLogs',
         'assertNotAlmostEqual',
         'assertNotEndsWith',
         'assertNotEqual',
         'assertNotHasAttr',
         'assertNotIn',
         'assertNotIsInstance',
         'assertNotIsSubclass',
         'assertNotRegex',
         'assertNotStartsWith',
         'assertRaises',
         'assertRaisesRegex',
         'assertRegex',
         'assertSequenceEqual',
         'assertSetEqual',
         'assertStartsWith',
         'assertTrue',
         'assertTupleEqual',
         'assertWarns',
         'assertWarnsRegex'
     );

walker SymTabBuildPass(UniPass) {
    has cur_sym_tab: list[UniScopeNode] = field(default_factory=`list);

    def before_pass() -> None;
    def push_scope_and_link(key_node: UniScopeNode) -> None;
    def pop_scope() -> UniScopeNode;

    has cur_scope: UniScopeNode { getter; }

    def _bind_import_path_symbols(module_path: ModulePath
    ) -> None;

    def enter_module(nd: Module) -> None;
    def exit_module(nd: Module) -> None;
    def enter_type_alias(nd: TypeAlias) -> None;
    def exit_type_alias(nd: TypeAlias) -> None;
    def enter_type_param(nd: TypeParam) -> None;
    def exit_global_vars(nd: GlobalVars) -> None;
    def exit_assignment(nd: Assignment) -> None;
    def exit_binary_expr(nd: BinaryExpr) -> None;
    def enter_test(nd: Test) -> None;
    def exit_test(nd: Test) -> None;
    def _exit_import_absorb(nd: Import) -> None;
    def exit_import(nd: Import) -> None;
    def import_binding_scope(nd: AstSymbolNode) -> UniScopeNode;
    def exit_module_path(nd: ModulePath) -> None;
    def exit_module_item(nd: ModuleItem) -> None;
    def enter_archetype(nd: Archetype) -> None;
    def exit_archetype(nd: Archetype) -> None;
    def enter_ability(nd: Ability) -> None;
    def exit_ability(nd: Ability) -> None;
    def enter_impl_def(nd: ImplDef) -> None;
    def exit_impl_def(nd: ImplDef) -> None;
    def enter_sem_def(nd: SemDef) -> None;
    def exit_sem_def(nd: SemDef) -> None;
    def enter_enum(nd: Enum) -> None;
    def enter_has_var(nd: HasVar) -> None;
    def enter_param_var(nd: ParamVar) -> None;
    def exit_atom_trailer(nd: AtomTrailer) -> None;
    def _is_self_member_assignment(nd: AtomTrailer) -> bool;
    def exit_enum(nd: Enum) -> None;
    def enter_typed_ctx_block(nd: TypedCtxBlock) -> None;
    def exit_typed_ctx_block(nd: TypedCtxBlock) -> None;
    def enter_open_stmt(nd: OpenStmt) -> None;
    def exit_open_stmt(nd: OpenStmt) -> None;
    def enter_if_stmt(nd: IfStmt) -> None;
    def exit_if_stmt(nd: IfStmt) -> None;
    def enter_else_if(nd: ElseIf) -> None;
    def exit_else_if(nd: ElseIf) -> None;
    def enter_else_stmt(nd: ElseStmt) -> None;
    def exit_else_stmt(nd: ElseStmt) -> None;
    def enter_try_stmt(nd: TryStmt) -> None;
    def exit_try_stmt(nd: TryStmt) -> None;
    def enter_except(nd: Except) -> None;
    def exit_except(nd: Except) -> None;
    def enter_finally_stmt(nd: FinallyStmt) -> None;
    def exit_finally_stmt(nd: FinallyStmt) -> None;
    def enter_iter_for_stmt(nd: IterForStmt) -> None;
    def exit_iter_for_stmt(nd: IterForStmt) -> None;
    def enter_in_for_stmt(nd: InForStmt) -> None;
    def exit_in_for_stmt(nd: InForStmt) -> None;
    def enter_while_stmt(nd: WhileStmt) -> None;
    def exit_while_stmt(nd: WhileStmt) -> None;
    def enter_forever_stmt(nd: ForeverStmt) -> None;
    def exit_forever_stmt(nd: ForeverStmt) -> None;
    def enter_with_stmt(nd: WithStmt) -> None;
    def exit_with_stmt(nd: WithStmt) -> None;
    def exit_expr_as_item(nd: ExprAsItem) -> None;
    def enter_lambda_expr(nd: LambdaExpr) -> None;
    def exit_lambda_expr(nd: LambdaExpr) -> None;
    def enter_list_compr(nd: ListCompr) -> None;
    def exit_list_compr(nd: ListCompr) -> None;
    def enter_set_compr(nd: SetCompr) -> None;
    def exit_set_compr(nd: SetCompr) -> None;
    def enter_gen_compr(nd: GenCompr) -> None;
    def exit_gen_compr(nd: GenCompr) -> None;
    def enter_dict_compr(nd: DictCompr) -> None;
    def exit_dict_compr(nd: DictCompr) -> None;
    def enter_inner_compr(nd: InnerCompr) -> None;
    def exit_inner_compr(nd: InnerCompr) -> None;
    def enter_match_case(nd: MatchCase) -> None;
    def exit_match_case(nd: MatchCase) -> None;
    def enter_switch_case(nd: SwitchCase) -> None;
    def exit_switch_case(nd: SwitchCase) -> None;
}
