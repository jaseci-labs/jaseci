import from jaclang.compiler.frontend.relations { Codespace }
import from jaclang.compiler.frontend.unitree {
    Ability,
    ArchHas,
    AssertStmt,
    Assignment,
    AstAsyncNode,
    AstSymbolNode,
    AtomTrailer,
    ConnectOp,
    ContextAwareNode,
    EdgeOpRef,
    EdgeRefTrailer,
    EnumBlockStmt,
    Expr,
    ExprStmt,
    FormattedValue,
    FuncCall,
    GlobalVars,
    HasVar,
    IfStmt,
    Import,
    InForStmt,
    IndexSlice,
    JsxElement,
    JsxNormalAttribute,
    MatchStar,
    Module,
    ModuleItem,
    ModulePath,
    Name,
    NameAtom,
    ParamVar,
    PythonModuleAst,
    ReturnStmt,
    Source,
    SpecialVarRef,
    SubTag,
    Symbol,
    Token,
    TypeAlias,
    TypeParam,
    UnaryExpr,
    UniNode,
    UniScopeNode,
    WalkerStmtOnlyNode,
    YieldExpr
}
import from jaclang.compiler.frontend.constant {
    EdgeDir,
    OwnershipKind,
    ParamKind
}

def:pub nf_h_UniNode__ctx_parent(n: UniNode) -> int {
    return 0 if n._ctx_parent is None else 1;
}

def:pub nf_g_UniNode__ctx_parent(n: UniNode) -> UniNode {
    v = n._ctx_parent;
    return v if v is not None else n;
}

def:pub nf_g_UniNode_ct_pruned(n: UniNode) -> int {
    return 1 if n.ct_pruned else 0;
}

def:pub nf_s_UniNode_ct_pruned(n: UniNode, v: int) -> int {
    n.ct_pruned = v != 0;
    return 0;
}

def:pub nf_g_UniScopeNode_scope_name(n: UniScopeNode) -> str {
    return n.scope_name;
}

def:pub nf_s_UniScopeNode_scope_name(n: UniScopeNode, v: str) -> int {
    n.scope_name = v;
    return 0;
}

def:pub nf_g_Module_name(n: Module) -> str {
    return n.name;
}

def:pub nf_s_Module_name(n: Module, v: str) -> int {
    n.name = v;
    return 0;
}

def:pub nf_h_Module_source(n: Module) -> int {
    return 0 if n.source is None else 1;
}

def:pub nf_g_Module_source(n: Module) -> UniNode {
    v = n.source;
    return v if v is not None else n;
}

def:pub nf_g_Module_stub_only(n: Module) -> int {
    return 1 if n.stub_only else 0;
}

def:pub nf_s_Module_stub_only(n: Module, v: int) -> int {
    n.stub_only = v != 0;
    return 0;
}

def:pub nf_g_Module_is_raised_from_py(n: Module) -> int {
    return 1 if n.is_raised_from_py else 0;
}

def:pub nf_s_Module_is_raised_from_py(n: Module, v: int) -> int {
    n.is_raised_from_py = v != 0;
    return 0;
}

def:pub nf_g_Module_parse_failed(n: Module) -> int {
    return 1 if n.parse_failed else 0;
}

def:pub nf_s_Module_parse_failed(n: Module, v: int) -> int {
    n.parse_failed = v != 0;
    return 0;
}

def:pub nf_h_Module_mobui_enforced_root(n: Module) -> int {
    return 0 if n.mobui_enforced_root is None else 1;
}

def:pub nf_g_Module_mobui_enforced_root(n: Module) -> str {
    v = n.mobui_enforced_root;
    return v if v is not None else "";
}

def:pub nf_s_Module_mobui_enforced_root(n: Module, v: str) -> int {
    n.mobui_enforced_root = v;
    return 0;
}

def:pub nf_h_Module_jac_project_root(n: Module) -> int {
    return 0 if n.jac_project_root is None else 1;
}

def:pub nf_g_Module_jac_project_root(n: Module) -> str {
    v = n.jac_project_root;
    return v if v is not None else "";
}

def:pub nf_s_Module_jac_project_root(n: Module, v: str) -> int {
    n.jac_project_root = v;
    return 0;
}

def:pub nf_g_Module_access_enforced(n: Module) -> int {
    return 1 if n.access_enforced else 0;
}

def:pub nf_s_Module_access_enforced(n: Module, v: int) -> int {
    n.access_enforced = v != 0;
    return 0;
}

def:pub nf_g_Module_ct_resolved(n: Module) -> int {
    return 1 if n.ct_resolved else 0;
}

def:pub nf_s_Module_ct_resolved(n: Module, v: int) -> int {
    n.ct_resolved = v != 0;
    return 0;
}

def:pub nf_g_Module_native_viols_reported(n: Module) -> int {
    return 1 if n.native_viols_reported else 0;
}

def:pub nf_s_Module_native_viols_reported(n: Module, v: int) -> int {
    n.native_viols_reported = v != 0;
    return 0;
}

def:pub nf_g_Module_client_viols_reported(n: Module) -> int {
    return 1 if n.client_viols_reported else 0;
}

def:pub nf_s_Module_client_viols_reported(n: Module, v: int) -> int {
    n.client_viols_reported = v != 0;
    return 0;
}

def:pub nf_h_AstSymbolNode_name_spec(n: AstSymbolNode) -> int {
    return 0 if n.name_spec is None else 1;
}

def:pub nf_g_AstSymbolNode_name_spec(n: AstSymbolNode) -> UniNode {
    v = n.name_spec;
    return v if v is not None else n;
}

def:pub nf_g_AstSymbolNode_semstr(n: AstSymbolNode) -> str {
    return n.semstr;
}

def:pub nf_s_AstSymbolNode_semstr(n: AstSymbolNode, v: str) -> int {
    n.semstr = v;
    return 0;
}

def:pub nf_g_ContextAwareNode_codespace_dual(n: ContextAwareNode) -> int {
    return 1 if n.codespace_dual else 0;
}

def:pub nf_s_ContextAwareNode_codespace_dual(n: ContextAwareNode, v: int) -> int {
    n.codespace_dual = v != 0;
    return 0;
}

def:pub nf_g_TypeAlias_is_distinct(n: TypeAlias) -> int {
    return 1 if n.is_distinct else 0;
}

def:pub nf_s_TypeAlias_is_distinct(n: TypeAlias, v: int) -> int {
    n.is_distinct = v != 0;
    return 0;
}

def:pub nf_g_AstAsyncNode_is_async(n: AstAsyncNode) -> int {
    return 1 if n.is_async else 0;
}

def:pub nf_s_AstAsyncNode_is_async(n: AstAsyncNode, v: int) -> int {
    n.is_async = v != 0;
    return 0;
}

def:pub nf_g_Ability_is_override(n: Ability) -> int {
    return 1 if n.is_override else 0;
}

def:pub nf_s_Ability_is_override(n: Ability, v: int) -> int {
    n.is_override = v != 0;
    return 0;
}

def:pub nf_g_Ability_is_static(n: Ability) -> int {
    return 1 if n.is_static else 0;
}

def:pub nf_s_Ability_is_static(n: Ability, v: int) -> int {
    n.is_static = v != 0;
    return 0;
}

def:pub nf_g_Ability_is_classmethod(n: Ability) -> int {
    return 1 if n.is_classmethod else 0;
}

def:pub nf_s_Ability_is_classmethod(n: Ability, v: int) -> int {
    n.is_classmethod = v != 0;
    return 0;
}

def:pub nf_g_Ability_is_abstract(n: Ability) -> int {
    return 1 if n.is_abstract else 0;
}

def:pub nf_s_Ability_is_abstract(n: Ability, v: int) -> int {
    n.is_abstract = v != 0;
    return 0;
}

def:pub nf_g_Ability_accessor_kind(n: Ability) -> str {
    return n.accessor_kind;
}

def:pub nf_s_Ability_accessor_kind(n: Ability, v: str) -> int {
    n.accessor_kind = v;
    return 0;
}

def:pub nf_g_Ability_is_comptime(n: Ability) -> int {
    return 1 if n.is_comptime else 0;
}

def:pub nf_s_Ability_is_comptime(n: Ability, v: int) -> int {
    n.is_comptime = v != 0;
    return 0;
}

def:pub nf_g_WalkerStmtOnlyNode_from_walker(n: WalkerStmtOnlyNode) -> int {
    return 1 if n.from_walker else 0;
}

def:pub nf_s_WalkerStmtOnlyNode_from_walker(n: WalkerStmtOnlyNode, v: int) -> int {
    n.from_walker = v != 0;
    return 0;
}

def:pub nf_g_IfStmt_is_comptime(n: IfStmt) -> int {
    return 1 if n.is_comptime else 0;
}

def:pub nf_s_IfStmt_is_comptime(n: IfStmt, v: int) -> int {
    n.is_comptime = v != 0;
    return 0;
}

def:pub nf_g_InForStmt_is_comptime(n: InForStmt) -> int {
    return 1 if n.is_comptime else 0;
}

def:pub nf_s_InForStmt_is_comptime(n: InForStmt, v: int) -> int {
    n.is_comptime = v != 0;
    return 0;
}

def:pub nf_h_Expr__type_sym_tab(n: Expr) -> int {
    return 0 if n._type_sym_tab is None else 1;
}

def:pub nf_g_Expr__type_sym_tab(n: Expr) -> UniNode {
    v = n._type_sym_tab;
    return v if v is not None else n;
}

def:pub nf_g_Expr__type_cache_ok(n: Expr) -> int {
    return 1 if n._type_cache_ok else 0;
}

def:pub nf_s_Expr__type_cache_ok(n: Expr, v: int) -> int {
    n._type_cache_ok = v != 0;
    return 0;
}

def:pub nf_h_Expr_coerce_to(n: Expr) -> int {
    return 0 if n.coerce_to is None else 1;
}

def:pub nf_g_Expr_coerce_to(n: Expr) -> str {
    v = n.coerce_to;
    return v if v is not None else "";
}

def:pub nf_s_Expr_coerce_to(n: Expr, v: str) -> int {
    n.coerce_to = v;
    return 0;
}

def:pub nf_h_Expr_fw(n: Expr) -> int {
    return 0 if n.fw is None else 1;
}

def:pub nf_g_Expr_fw(n: Expr) -> str {
    v = n.fw;
    return v if v is not None else "";
}

def:pub nf_s_Expr_fw(n: Expr, v: str) -> int {
    n.fw = v;
    return 0;
}

def:pub nf_g_Expr_fw_safe(n: Expr) -> int {
    return 1 if n.fw_safe else 0;
}

def:pub nf_s_Expr_fw_safe(n: Expr, v: int) -> int {
    n.fw_safe = v != 0;
    return 0;
}

def:pub nf_g_EnumBlockStmt_is_enum_stmt(n: EnumBlockStmt) -> int {
    return 1 if n.is_enum_stmt else 0;
}

def:pub nf_s_EnumBlockStmt_is_enum_stmt(n: EnumBlockStmt, v: int) -> int {
    n.is_enum_stmt = v != 0;
    return 0;
}

def:pub nf_h_NameAtom_name_of(n: NameAtom) -> int {
    return 0 if n.name_of is None else 1;
}

def:pub nf_g_NameAtom_name_of(n: NameAtom) -> UniNode {
    v = n.name_of;
    return v if v is not None else n;
}

def:pub nf_g_NameAtom__sym_name(n: NameAtom) -> str {
    return n._sym_name;
}

def:pub nf_s_NameAtom__sym_name(n: NameAtom, v: str) -> int {
    n._sym_name = v;
    return 0;
}

def:pub nf_g_NameAtom_is_getattr_resolved(n: NameAtom) -> int {
    return 1 if n.is_getattr_resolved else 0;
}

def:pub nf_s_NameAtom_is_getattr_resolved(n: NameAtom, v: int) -> int {
    n.is_getattr_resolved = v != 0;
    return 0;
}

def:pub nf_g_Name_is_enum_stmt(n: Name) -> int {
    return 1 if n.is_enum_stmt else 0;
}

def:pub nf_s_Name_is_enum_stmt(n: Name, v: int) -> int {
    n.is_enum_stmt = v != 0;
    return 0;
}

def:pub nf_h_Token_orig_src(n: Token) -> int {
    return 0 if n.orig_src is None else 1;
}

def:pub nf_g_Token_orig_src(n: Token) -> UniNode {
    v = n.orig_src;
    return v if v is not None else n;
}

def:pub nf_g_Token_name(n: Token) -> str {
    return n.name;
}

def:pub nf_s_Token_name(n: Token, v: str) -> int {
    n.name = v;
    return 0;
}

def:pub nf_g_Token_value(n: Token) -> str {
    return n.value;
}

def:pub nf_s_Token_value(n: Token, v: str) -> int {
    n.value = v;
    return 0;
}

def:pub nf_g_Token_line_no(n: Token) -> int {
    return n.line_no;
}

def:pub nf_s_Token_line_no(n: Token, v: int) -> int {
    n.line_no = v;
    return 0;
}

def:pub nf_g_Token_end_line(n: Token) -> int {
    return n.end_line;
}

def:pub nf_s_Token_end_line(n: Token, v: int) -> int {
    n.end_line = v;
    return 0;
}

def:pub nf_g_Token_c_start(n: Token) -> int {
    return n.c_start;
}

def:pub nf_s_Token_c_start(n: Token, v: int) -> int {
    n.c_start = v;
    return 0;
}

def:pub nf_g_Token_c_end(n: Token) -> int {
    return n.c_end;
}

def:pub nf_s_Token_c_end(n: Token, v: int) -> int {
    n.c_end = v;
    return 0;
}

def:pub nf_g_Token_pos_start(n: Token) -> int {
    return n.pos_start;
}

def:pub nf_s_Token_pos_start(n: Token, v: int) -> int {
    n.pos_start = v;
    return 0;
}

def:pub nf_g_Token_pos_end(n: Token) -> int {
    return n.pos_end;
}

def:pub nf_s_Token_pos_end(n: Token, v: int) -> int {
    n.pos_end = v;
    return 0;
}

def:pub nf_g_Token__is_synthetic(n: Token) -> int {
    return 1 if n._is_synthetic else 0;
}

def:pub nf_s_Token__is_synthetic(n: Token, v: int) -> int {
    n._is_synthetic = v != 0;
    return 0;
}

def:pub nf_g_Name_is_kwesc(n: Name) -> int {
    return 1 if n.is_kwesc else 0;
}

def:pub nf_s_Name_is_kwesc(n: Name, v: int) -> int {
    n.is_kwesc = v != 0;
    return 0;
}

def:pub nf_h_SpecialVarRef_orig(n: SpecialVarRef) -> int {
    return 0 if n.orig is None else 1;
}

def:pub nf_g_SpecialVarRef_orig(n: SpecialVarRef) -> UniNode {
    v = n.orig;
    return v if v is not None else n;
}

def:pub nf_g_IndexSlice_is_range(n: IndexSlice) -> int {
    return 1 if n.is_range else 0;
}

def:pub nf_s_IndexSlice_is_range(n: IndexSlice, v: int) -> int {
    n.is_range = v != 0;
    return 0;
}

def:pub nf_g_EdgeOpRef_edge_dir(n: EdgeOpRef) -> int {
    return n.edge_dir.value;
}

def:pub nf_s_EdgeOpRef_edge_dir(n: EdgeOpRef, v: int) -> int {
    n.edge_dir = EdgeDir(v);
    return 0;
}

def:pub nf_g_JsxElement_is_self_closing(n: JsxElement) -> int {
    return 1 if n.is_self_closing else 0;
}

def:pub nf_s_JsxElement_is_self_closing(n: JsxElement, v: int) -> int {
    n.is_self_closing = v != 0;
    return 0;
}

def:pub nf_g_JsxElement_is_fragment(n: JsxElement) -> int {
    return 1 if n.is_fragment else 0;
}

def:pub nf_s_JsxElement_is_fragment(n: JsxElement, v: int) -> int {
    n.is_fragment = v != 0;
    return 0;
}

def:pub nf_g_TypeParam_is_comptime(n: TypeParam) -> int {
    return 1 if n.is_comptime else 0;
}

def:pub nf_s_TypeParam_is_comptime(n: TypeParam, v: int) -> int {
    n.is_comptime = v != 0;
    return 0;
}

def:pub nf_g_ParamVar_param_kind(n: ParamVar) -> int {
    return n.param_kind.value;
}

def:pub nf_s_ParamVar_param_kind(n: ParamVar, v: int) -> int {
    n.param_kind = ParamKind(v);
    return 0;
}

def:pub nf_g_ParamVar_is_comptime(n: ParamVar) -> int {
    return 1 if n.is_comptime else 0;
}

def:pub nf_s_ParamVar_is_comptime(n: ParamVar, v: int) -> int {
    n.is_comptime = v != 0;
    return 0;
}

def:pub nf_g_HasVar_defer(n: HasVar) -> int {
    return 1 if n.defer else 0;
}

def:pub nf_s_HasVar_defer(n: HasVar, v: int) -> int {
    n.defer = v != 0;
    return 0;
}

def:pub nf_g_GlobalVars_is_frozen(n: GlobalVars) -> int {
    return 1 if n.is_frozen else 0;
}

def:pub nf_s_GlobalVars_is_frozen(n: GlobalVars, v: int) -> int {
    n.is_frozen = v != 0;
    return 0;
}

def:pub nf_g_ArchHas_is_static(n: ArchHas) -> int {
    return 1 if n.is_static else 0;
}

def:pub nf_s_ArchHas_is_static(n: ArchHas, v: int) -> int {
    n.is_static = v != 0;
    return 0;
}

def:pub nf_g_ArchHas_is_frozen(n: ArchHas) -> int {
    return 1 if n.is_frozen else 0;
}

def:pub nf_s_ArchHas_is_frozen(n: ArchHas, v: int) -> int {
    n.is_frozen = v != 0;
    return 0;
}

def:pub nf_g_Import_is_absorb(n: Import) -> int {
    return 1 if n.is_absorb else 0;
}

def:pub nf_s_Import_is_absorb(n: Import, v: int) -> int {
    n.is_absorb = v != 0;
    return 0;
}

def:pub nf_g_Import_is_typed(n: Import) -> int {
    return 1 if n.is_typed else 0;
}

def:pub nf_s_Import_is_typed(n: Import, v: int) -> int {
    n.is_typed = v != 0;
    return 0;
}

def:pub nf_g_Import_is_comptime(n: Import) -> int {
    return 1 if n.is_comptime else 0;
}

def:pub nf_s_Import_is_comptime(n: Import, v: int) -> int {
    n.is_comptime = v != 0;
    return 0;
}

def:pub nf_g_Import_native_only_drop(n: Import) -> int {
    return 1 if n.native_only_drop else 0;
}

def:pub nf_s_Import_native_only_drop(n: Import, v: int) -> int {
    n.native_only_drop = v != 0;
    return 0;
}

def:pub nf_g_AssertStmt_is_comptime(n: AssertStmt) -> int {
    return 1 if n.is_comptime else 0;
}

def:pub nf_s_AssertStmt_is_comptime(n: AssertStmt, v: int) -> int {
    n.is_comptime = v != 0;
    return 0;
}

def:pub nf_g_Assignment_mutable(n: Assignment) -> int {
    return 1 if n.mutable else 0;
}

def:pub nf_s_Assignment_mutable(n: Assignment, v: int) -> int {
    n.mutable = v != 0;
    return 0;
}

def:pub nf_g_Assignment_na_move_lowerable(n: Assignment) -> int {
    return 1 if n.na_move_lowerable else 0;
}

def:pub nf_s_Assignment_na_move_lowerable(n: Assignment, v: int) -> int {
    n.na_move_lowerable = v != 0;
    return 0;
}

def:pub nf_g_Assignment_na_overwrite_consumed(n: Assignment) -> int {
    return 1 if n.na_overwrite_consumed else 0;
}

def:pub nf_s_Assignment_na_overwrite_consumed(n: Assignment, v: int) -> int {
    n.na_overwrite_consumed = v != 0;
    return 0;
}

def:pub nf_g_Assignment_na_flow_reduce(n: Assignment) -> str {
    return n.na_flow_reduce;
}

def:pub nf_s_Assignment_na_flow_reduce(n: Assignment, v: str) -> int {
    n.na_flow_reduce = v;
    return 0;
}

def:pub nf_g_Assignment_is_comptime(n: Assignment) -> int {
    return 1 if n.is_comptime else 0;
}

def:pub nf_s_Assignment_is_comptime(n: Assignment, v: int) -> int {
    n.is_comptime = v != 0;
    return 0;
}

def:pub nf_g_ExprStmt_in_fstring(n: ExprStmt) -> int {
    return 1 if n.in_fstring else 0;
}

def:pub nf_s_ExprStmt_in_fstring(n: ExprStmt, v: int) -> int {
    n.in_fstring = v != 0;
    return 0;
}

def:pub nf_g_ExprStmt_has_semi(n: ExprStmt) -> int {
    return 1 if n.has_semi else 0;
}

def:pub nf_s_ExprStmt_has_semi(n: ExprStmt, v: int) -> int {
    n.has_semi = v != 0;
    return 0;
}

def:pub nf_g_ReturnStmt_is_implicit(n: ReturnStmt) -> int {
    return 1 if n.is_implicit else 0;
}

def:pub nf_s_ReturnStmt_is_implicit(n: ReturnStmt, v: int) -> int {
    n.is_implicit = v != 0;
    return 0;
}

def:pub nf_g_UnaryExpr_ownership(n: UnaryExpr) -> int {
    return n.ownership.value;
}

def:pub nf_s_UnaryExpr_ownership(n: UnaryExpr, v: int) -> int {
    n.ownership = OwnershipKind(v);
    return 0;
}

def:pub nf_g_FormattedValue_conversion(n: FormattedValue) -> int {
    return n.conversion;
}

def:pub nf_s_FormattedValue_conversion(n: FormattedValue, v: int) -> int {
    n.conversion = v;
    return 0;
}

def:pub nf_g_AtomTrailer_is_attr(n: AtomTrailer) -> int {
    return 1 if n.is_attr else 0;
}

def:pub nf_s_AtomTrailer_is_attr(n: AtomTrailer, v: int) -> int {
    n.is_attr = v != 0;
    return 0;
}

def:pub nf_g_AtomTrailer_is_null_ok(n: AtomTrailer) -> int {
    return 1 if n.is_null_ok else 0;
}

def:pub nf_s_AtomTrailer_is_null_ok(n: AtomTrailer, v: int) -> int {
    n.is_null_ok = v != 0;
    return 0;
}

def:pub nf_g_AtomTrailer_is_genai(n: AtomTrailer) -> int {
    return 1 if n.is_genai else 0;
}

def:pub nf_s_AtomTrailer_is_genai(n: AtomTrailer, v: int) -> int {
    n.is_genai = v != 0;
    return 0;
}

def:pub nf_g_YieldExpr_with_from(n: YieldExpr) -> int {
    return 1 if n.with_from else 0;
}

def:pub nf_s_YieldExpr_with_from(n: YieldExpr, v: int) -> int {
    n.with_from = v != 0;
    return 0;
}

def:pub nf_h_FuncCall_genai_call(n: FuncCall) -> int {
    return 0 if n.genai_call is None else 1;
}

def:pub nf_g_FuncCall_genai_call(n: FuncCall) -> UniNode {
    v = n.genai_call;
    return v if v is not None else n;
}

def:pub nf_h_FuncCall_call_kind(n: FuncCall) -> int {
    return 0 if n.call_kind is None else 1;
}

def:pub nf_g_FuncCall_call_kind(n: FuncCall) -> str {
    v = n.call_kind;
    return v if v is not None else "";
}

def:pub nf_s_FuncCall_call_kind(n: FuncCall, v: str) -> int {
    n.call_kind = v;
    return 0;
}

def:pub nf_h_FuncCall_chunks_recv_type(n: FuncCall) -> int {
    return 0 if n.chunks_recv_type is None else 1;
}

def:pub nf_g_FuncCall_chunks_recv_type(n: FuncCall) -> str {
    v = n.chunks_recv_type;
    return v if v is not None else "";
}

def:pub nf_s_FuncCall_chunks_recv_type(n: FuncCall, v: str) -> int {
    n.chunks_recv_type = v;
    return 0;
}

def:pub nf_g_EdgeRefTrailer_edges_only(n: EdgeRefTrailer) -> int {
    return 1 if n.edges_only else 0;
}

def:pub nf_s_EdgeRefTrailer_edges_only(n: EdgeRefTrailer, v: int) -> int {
    n.edges_only = v != 0;
    return 0;
}

def:pub nf_g_EdgeRefTrailer_is_async(n: EdgeRefTrailer) -> int {
    return 1 if n.is_async else 0;
}

def:pub nf_s_EdgeRefTrailer_is_async(n: EdgeRefTrailer, v: int) -> int {
    n.is_async = v != 0;
    return 0;
}

def:pub nf_g_MatchStar_is_list(n: MatchStar) -> int {
    return 1 if n.is_list else 0;
}

def:pub nf_s_MatchStar_is_list(n: MatchStar, v: int) -> int {
    n.is_list = v != 0;
    return 0;
}

def:pub nf_g_SubTag_ownership(n: SubTag) -> int {
    return n.ownership.value;
}

def:pub nf_s_SubTag_ownership(n: SubTag, v: int) -> int {
    n.ownership = OwnershipKind(v);
    return 0;
}

def:pub nf_g_ModulePath_level(n: ModulePath) -> int {
    return n.level;
}

def:pub nf_s_ModulePath_level(n: ModulePath, v: int) -> int {
    n.level = v;
    return 0;
}

def:pub nf_h_ModulePath_abs_path(n: ModulePath) -> int {
    return 0 if n.abs_path is None else 1;
}

def:pub nf_g_ModulePath_abs_path(n: ModulePath) -> str {
    v = n.abs_path;
    return v if v is not None else "";
}

def:pub nf_s_ModulePath_abs_path(n: ModulePath, v: str) -> int {
    n.abs_path = v;
    return 0;
}

def:pub nf_h_ModuleItem_abs_path(n: ModuleItem) -> int {
    return 0 if n.abs_path is None else 1;
}

def:pub nf_g_ModuleItem_abs_path(n: ModuleItem) -> str {
    v = n.abs_path;
    return v if v is not None else "";
}

def:pub nf_s_ModuleItem_abs_path(n: ModuleItem, v: str) -> int {
    n.abs_path = v;
    return 0;
}

def:pub nf_g_ConnectOp_edge_dir(n: ConnectOp) -> int {
    return n.edge_dir.value;
}

def:pub nf_s_ConnectOp_edge_dir(n: ConnectOp, v: int) -> int {
    n.edge_dir = EdgeDir(v);
    return 0;
}

def:pub nf_g_JsxNormalAttribute_is_shorthand(n: JsxNormalAttribute) -> int {
    return 1 if n.is_shorthand else 0;
}

def:pub nf_s_JsxNormalAttribute_is_shorthand(n: JsxNormalAttribute, v: int) -> int {
    n.is_shorthand = v != 0;
    return 0;
}

def:pub nf_g_Source_file_path(n: Source) -> str {
    return n.file_path;
}

def:pub nf_s_Source_file_path(n: Source, v: str) -> int {
    n.file_path = v;
    return 0;
}

def:pub nf_g_Source__hash(n: Source) -> str {
    return n._hash;
}

def:pub nf_s_Source__hash(n: Source, v: str) -> int {
    n._hash = v;
    return 0;
}

def:pub nf_h_PythonModuleAst_orig_src(n: PythonModuleAst) -> int {
    return 0 if n.orig_src is None else 1;
}

def:pub nf_g_PythonModuleAst_orig_src(n: PythonModuleAst) -> UniNode {
    v = n.orig_src;
    return v if v is not None else n;
}

def:pub nf_g_PythonModuleAst_file_path(n: PythonModuleAst) -> str {
    return n.file_path;
}

def:pub nf_s_PythonModuleAst_file_path(n: PythonModuleAst, v: str) -> int {
    n.file_path = v;
    return 0;
}

def:pub nf_g_Symbol_name(n: Symbol) -> str {
    return n.name;
}

def:pub nf_s_Symbol_name(n: Symbol, v: str) -> int {
    n.name = v;
    return 0;
}

def:pub nf_g_Symbol_imported(n: Symbol) -> int {
    return 1 if n.imported else 0;
}

def:pub nf_s_Symbol_imported(n: Symbol, v: int) -> int {
    n.imported = v != 0;
    return 0;
}

def:pub nf_g_Symbol_semstr(n: Symbol) -> str {
    return n.semstr;
}

def:pub nf_s_Symbol_semstr(n: Symbol, v: str) -> int {
    n.semstr = v;
    return 0;
}

def:pub nf_g_Symbol_ownership(n: Symbol) -> int {
    return n.ownership.value;
}

def:pub nf_s_Symbol_ownership(n: Symbol, v: int) -> int {
    n.ownership = OwnershipKind(v);
    return 0;
}

def:pub nf_g_Symbol_param_rebound(n: Symbol) -> int {
    return 1 if n.param_rebound else 0;
}

def:pub nf_s_Symbol_param_rebound(n: Symbol, v: int) -> int {
    n.param_rebound = v != 0;
    return 0;
}

def:pub nf_g_Symbol_na_escapes(n: Symbol) -> int {
    return 1 if n.na_escapes else 0;
}

def:pub nf_s_Symbol_na_escapes(n: Symbol, v: int) -> int {
    n.na_escapes = v != 0;
    return 0;
}

def:pub nf_g_Symbol_na_region_handle(n: Symbol) -> int {
    return 1 if n.na_region_handle else 0;
}

def:pub nf_s_Symbol_na_region_handle(n: Symbol, v: int) -> int {
    n.na_region_handle = v != 0;
    return 0;
}

def:pub nf_g_Symbol_na_stack_ok(n: Symbol) -> int {
    return 1 if n.na_stack_ok else 0;
}

def:pub nf_s_Symbol_na_stack_ok(n: Symbol, v: int) -> int {
    n.na_stack_ok = v != 0;
    return 0;
}

def:pub nf_g_Codespace_kind(n: Codespace) -> str {
    return n.kind;
}

def:pub nf_s_Codespace_kind(n: Codespace, v: str) -> int {
    n.kind = v;
    return 0;
}
