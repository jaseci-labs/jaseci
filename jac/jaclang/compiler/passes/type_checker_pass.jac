import from jaclang.compiler.frontend.unitree {
    Ability,
    ArchHas,
    Archetype,
    AssertStmt,
    Assignment,
    AstSymbolNode,
    AtomTrailer,
    BinaryExpr,
    BuiltinType,
    CodeBlockStmt,
    CompareExpr,
    DeleteStmt,
    EdgeRefTrailer,
    Enum,
    EventSignature,
    Expr,
    ExprAsItem,
    FilterCompr,
    FormattedValue,
    FuncCall,
    FuncSignature,
    HasVar,
    ImplDef,
    Import,
    InForStmt,
    IndexSlice,
    JsxElement,
    JsxElementName,
    KWPair,
    LambdaExpr,
    ListVal,
    Module,
    ModuleCode,
    ModuleItem,
    ModulePath,
    Name,
    Null,
    ParamVar,
    RaiseStmt,
    ReportStmt,
    ReturnStmt,
    Slice,
    SpecialVarRef,
    Symbol,
    SubTag,
    Token,
    UnaryExpr,
    TupleVal,
    TypeAlias,
    UniNode,
    VisitStmt,
    IfStmt,
    ElseIf,
    WhileStmt,
    WithStmt,
    YieldExpr
}
import from jaclang.compiler.passes.uni_pass { UniPass }
import from jaclang.compiler.frontend.constant { Tokens as Tok }
import from jaclang.compiler.frontend.diagnostics { E0033, E0108, E0109 }
import from jaclang.compiler.types.ct_value { CT_DEFERRED, CtValue }
import from jaclang.compiler.types.types {
    AnyType,
    ClassType,
    FunctionType,
    ModuleType,
    TypeBase,
    TypeVarType,
    UnionType,
    UnknownType
}
import from jaclang.compiler.types.type_utils {
    PropertyWriteKind,
    get_declared_generator_return_type,
    get_generator_yield_type,
    is_generator_family_type
}
import from jaclang.compiler.types.operations {
    ARITHMETIC_OPERATORS,
    AUG_OPERATOR_MAP,
    AUG_TO_BINARY_MAP,
    BINARY_OPERATOR_MAP,
    BITWISE_OPERATORS,
    SHIFT_OPERATORS,
    get_numeric_promotion_type,
    get_pow_result_type
}
import type from jaclang.compiler.types.type_evaluator { TypeEvaluator }
import type from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.diagnostics {
    Category,
    DiagnosticInfo,
    E1001,
    E1002,
    E1003,
    E1004,
    E1005,
    E1010,
    E1011,
    E1020,
    E1021,
    E1022,
    E1042,
    E1060,
    E1061,
    E1090,
    E1091,
    E1092,
    E1093,
    E1094,
    E1095,
    E1106,
    E1107,
    E1112,
    E1113,
    E1116,
    E1117,
    E1119,
    E1124,
    E5095,
    W1036,
    W1037,
    W1052,
    W2014,
    W6008,
    E2015
}


glob FW_INTERVAL_OPS: dict[str, str] = {
         "PLUS": "+",
         "MINUS": "-",
         "STAR_MUL": "*"
     };

walker TypeCheckPass(UniPass) {
    has prog: JacProgram,
        evaluator: TypeEvaluator postinit,
        _lambda_depth: int = 0,
        _prev_eval_pass: any = None,
        _prev_ct_quiet: bool = False;

    def postinit -> None;

    static has PROVIDES: tuple = ('inference', ),
        HOST_PASS: bool = True;

    def init(prog: JacProgram, **kwargs: any) -> None;
    def before_pass() -> None;
    def after_pass() -> None;
    def _stamp_fixed_width() -> None;
    def _provably_in_range(nd: Expr, name: str) -> bool;
    def _insert_builtin_symbols() -> None;
    def _install_client_state_setters() -> None;
    def _client_state_field_owner(nd: HasVar) -> (Ability | None);
    def enter_ability(nd: Ability) -> None;
    def exit_ability(nd: Ability) -> None;
    def enter_lambda_expr(nd: LambdaExpr) -> None;
    def exit_lambda_expr(nd: LambdaExpr) -> None;
    def exit_type_alias(nd: TypeAlias) -> None;
    def exit_archetype(nd: Archetype) -> None;
    def exit_enum(nd: Enum) -> None;
    def exit_import(nd: Import) -> None;
    def exit_assignment(nd: Assignment) -> None;
    def exit_atom_trailer(nd: AtomTrailer) -> None;
    def exit_binary_expr(nd: BinaryExpr) -> None;
    def exit_compare_expr(nd: CompareExpr) -> None;
    def _diag_erased_membership(nd: CompareExpr, hay: Expr, op_text: str
    ) -> None;

    def exit_func_call(nd: FuncCall) -> None;
    def _check_intrinsic_call(nd: FuncCall) -> None;
    def _check_intrinsic_collision(nd: Ability) -> None;
    def exit_jsx_element(nd: JsxElement) -> None;
    def exit_filter_compr(nd: FilterCompr) -> None;
    def exit_return_stmt(nd: ReturnStmt) -> None;
    def exit_formatted_value(nd: FormattedValue) -> None;
    def exit_edge_ref_trailer(nd: EdgeRefTrailer) -> None;
    def exit_special_var_ref(nd: SpecialVarRef) -> None;
    def exit_name(nd: Name) -> None;
    def exit_param_var(nd: ParamVar) -> None;
    def exit_has_var(nd: HasVar) -> None;
    def exit_in_for_stmt(nd: InForStmt) -> None;
    def exit_raise_stmt(nd: RaiseStmt) -> None;
    def enter_with_stmt(nd: WithStmt) -> None;
    def exit_with_stmt(nd: WithStmt) -> None;
    def enter_if_stmt(nd: IfStmt) -> None;
    def enter_else_if(nd: ElseIf) -> None;
    def _resolve_comptime_if(nd: IfStmt) -> None;
    def _in_comptime_context(nd: UniNode) -> bool;
    def _check_comptime_only_use(nd: Name) -> None;
    def exit_if_stmt(nd: IfStmt) -> None;
    def exit_else_if(nd: ElseIf) -> None;
    def exit_while_stmt(nd: WhileStmt) -> None;
    def exit_assert_stmt(nd: AssertStmt) -> None;
    def exit_yield_expr(nd: YieldExpr) -> None;
    def exit_delete_stmt(nd: DeleteStmt) -> None;
    def exit_visit_stmt(nd: VisitStmt) -> None;
    def exit_report_stmt(nd: ReportStmt) -> None;
    def exit_impl_def(nd: ImplDef) -> None;
    def exit_sub_tag(nd: SubTag) -> None;
    def _eval_unpacking_names(container: Expr) -> None;
    def _body_always_returns(body: list[CodeBlockStmt]) -> bool;
    def _check_bare_generic(ann_node: UniNode, ty: object
    ) -> None;

    def _check_explicit_any(ann_node: UniNode) -> None;
    def _check_walker_reports_shape(nd: HasVar, declared_type: object
    ) -> None;

    def _enclosing_walker_report_elem_type(nd: UniNode
    ) -> (TypeBase | None);

    def _check_event_trigger_archetype(nd: Ability) -> None;
    def _check_unresolved_lambda_params() -> None;
}
