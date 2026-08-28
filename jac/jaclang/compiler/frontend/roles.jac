edge Role {
    static has NAME: str = "";

    has in_kid: bool = True;
}

edge KidRole(Role) {
    static has NAME: str = "kid";
}

edge ImplOf {}

edge AccessRole(Role) {
    static has NAME: str = "access";
}

edge AccessorsRole(Role) {
    static has NAME: str = "accessors";
}

edge AliasRole(Role) {
    static has NAME: str = "alias";
}

edge ArchTagInfoRole(Role) {
    static has NAME: str = "arch_tag_info";
}

edge ArchTypeRole(Role) {
    static has NAME: str = "arch_type";
}

edge ArgPatternsRole(Role) {
    static has NAME: str = "arg_patterns";
}

edge AssignmentsRole(Role) {
    static has NAME: str = "assignments";
}

edge AssignsRole(Role) {
    static has NAME: str = "assigns";
}

edge AttributesRole(Role) {
    static has NAME: str = "attributes";
}

edge AugOpRole(Role) {
    static has NAME: str = "aug_op";
}

edge AwaitingBodyRole(Role) {
    static has NAME: str = "awaiting_body";
}

edge BaseClassesRole(Role) {
    static has NAME: str = "base_classes";
}

edge BodyRole(Role) {
    static has NAME: str = "body";
}

edge BoundRole(Role) {
    static has NAME: str = "bound";
}

edge CasesRole(Role) {
    static has NAME: str = "cases";
}

edge CastTypeRole(Role) {
    static has NAME: str = "cast_type";
}

edge CauseRole(Role) {
    static has NAME: str = "cause";
}

edge ChainRole(Role) {
    static has NAME: str = "chain";
}

edge ChildrenRole(Role) {
    static has NAME: str = "children";
}

edge ClibDeclsRole(Role) {
    static has NAME: str = "clib_decls";
}

edge CodeRole(Role) {
    static has NAME: str = "code";
}

edge CollectionRole(Role) {
    static has NAME: str = "collection";
}

edge ComparesRole(Role) {
    static has NAME: str = "compares";
}

edge ComprRole(Role) {
    static has NAME: str = "compr";
}

edge ConditionRole(Role) {
    static has NAME: str = "condition";
}

edge ConditionalRole(Role) {
    static has NAME: str = "conditional";
}

edge ConnAssignRole(Role) {
    static has NAME: str = "conn_assign";
}

edge ConnTypeRole(Role) {
    static has NAME: str = "conn_type";
}

edge CountByRole(Role) {
    static has NAME: str = "count_by";
}

edge CtrlRole(Role) {
    static has NAME: str = "ctrl";
}

edge DecoratorsRole(Role) {
    static has NAME: str = "decorators";
}

edge DefaultValRole(Role) {
    static has NAME: str = "default_val";
}

edge DescriptionRole(Role) {
    static has NAME: str = "description";
}

edge DocRole(Role) {
    static has NAME: str = "doc";
}

edge DynamicTagRole(Role) {
    static has NAME: str = "dynamic_tag";
}

edge EdgeSpecRole(Role) {
    static has NAME: str = "edge_spec";
}

edge ElseBodyRole(Role) {
    static has NAME: str = "else_body";
}

edge ElseValueRole(Role) {
    static has NAME: str = "else_value";
}

edge EndRole(Role) {
    static has NAME: str = "end";
}

edge ErrorMsgRole(Role) {
    static has NAME: str = "error_msg";
}

edge EventRole(Role) {
    static has NAME: str = "event";
}

edge ExTypeRole(Role) {
    static has NAME: str = "ex_type";
}

edge ExceptsRole(Role) {
    static has NAME: str = "excepts";
}

edge ExprRole(Role) {
    static has NAME: str = "expr";
}

edge ExprsRole(Role) {
    static has NAME: str = "exprs";
}

edge FTypeRole(Role) {
    static has NAME: str = "f_type";
}

edge FilterCondRole(Role) {
    static has NAME: str = "filter_cond";
}

edge FinallyBodyRole(Role) {
    static has NAME: str = "finally_body";
}

edge FormatPartRole(Role) {
    static has NAME: str = "format_part";
}

edge FormatSpecRole(Role) {
    static has NAME: str = "format_spec";
}

edge FromLocRole(Role) {
    static has NAME: str = "from_loc";
}

edge FromTargetRole(Role) {
    static has NAME: str = "from_target";
}

edge GuardRole(Role) {
    static has NAME: str = "guard";
}

edge HintRole(Role) {
    static has NAME: str = "hint";
}

edge InsertLocRole(Role) {
    static has NAME: str = "insert_loc";
}

edge ItemsRole(Role) {
    static has NAME: str = "items";
}

edge IterRole(Role) {
    static has NAME: str = "iter";
}

edge KeyRole(Role) {
    static has NAME: str = "key";
}

edge KeywordsRole(Role) {
    static has NAME: str = "keywords";
}

edge KvPairRole(Role) {
    static has NAME: str = "kv_pair";
}

edge KvPairsRole(Role) {
    static has NAME: str = "kv_pairs";
}

edge KwPatternsRole(Role) {
    static has NAME: str = "kw_patterns";
}

edge KwargsRole(Role) {
    static has NAME: str = "kwargs";
}

edge KwonlyargsRole(Role) {
    static has NAME: str = "kwonlyargs";
}

edge LeftRole(Role) {
    static has NAME: str = "left";
}

edge MainRole(Role) {
    static has NAME: str = "main";
}

edge NameRole(Role) {
    static has NAME: str = "name";
}

edge NameRefRole(Role) {
    static has NAME: str = "name_ref";
}

edge OpRole(Role) {
    static has NAME: str = "op";
}

edge OperandRole(Role) {
    static has NAME: str = "operand";
}

edge OpsRole(Role) {
    static has NAME: str = "ops";
}

edge OutExprRole(Role) {
    static has NAME: str = "out_expr";
}

edge ParamsRole(Role) {
    static has NAME: str = "params";
}

edge PartsRole(Role) {
    static has NAME: str = "parts";
}

edge PathRole(Role) {
    static has NAME: str = "path";
}

edge PatternRole(Role) {
    static has NAME: str = "pattern";
}

edge PatternsRole(Role) {
    static has NAME: str = "patterns";
}

edge PosonlyParamsRole(Role) {
    static has NAME: str = "posonly_params";
}

edge ReturnTypeRole(Role) {
    static has NAME: str = "return_type";
}

edge RightRole(Role) {
    static has NAME: str = "right";
}

edge RightsRole(Role) {
    static has NAME: str = "rights";
}

edge SignatureRole(Role) {
    static has NAME: str = "signature";
}

edge SlicesRole(Role) {
    static has NAME: str = "slices";
}

edge SpecRole(Role) {
    static has NAME: str = "spec";
}

edge SrcEndpointRole(Role) {
    static has NAME: str = "src_endpoint";
}

edge StartRole(Role) {
    static has NAME: str = "start";
}

edge StepRole(Role) {
    static has NAME: str = "step";
}

edge StopRole(Role) {
    static has NAME: str = "stop";
}

edge StringsRole(Role) {
    static has NAME: str = "strings";
}

edge TargetRole(Role) {
    static has NAME: str = "target";
}

edge TgtEndpointRole(Role) {
    static has NAME: str = "tgt_endpoint";
}

edge TokRole(Role) {
    static has NAME: str = "tok";
}

edge TypeCtxRole(Role) {
    static has NAME: str = "type_ctx";
}

edge TypeParamsRole(Role) {
    static has NAME: str = "type_params";
}

edge TypeTagRole(Role) {
    static has NAME: str = "type_tag";
}

edge UnpackRole(Role) {
    static has NAME: str = "unpack";
}

edge ValueRole(Role) {
    static has NAME: str = "value";
}

edge ValueTypeRole(Role) {
    static has NAME: str = "value_type";
}

edge ValuesRole(Role) {
    static has NAME: str = "values";
}

edge VarargsRole(Role) {
    static has NAME: str = "varargs";
}

edge VarsRole(Role) {
    static has NAME: str = "vars";
}

glob ROLE_SLOTS: tuple[tuple[str, str, str], ...] = (
    ("Ability", "name_ref", "one"),
    ("Ability", "signature", "one"),
    ("Ability", "decorators", "many"),
    ("Ability", "type_params", "many"),
    ("ArchHas", "vars", "many"),
    ("ArchSpec", "decorators", "many"),
    ("Archetype", "name", "one"),
    ("Archetype", "arch_type", "one"),
    ("Archetype", "base_classes", "many"),
    ("Archetype", "keywords", "many"),
    ("Archetype", "type_params", "many"),
    ("Archetype", "src_endpoint", "one"),
    ("Archetype", "tgt_endpoint", "one"),
    ("AssertStmt", "condition", "one"),
    ("AssertStmt", "error_msg", "one"),
    ("AssignCompr", "assigns", "many"),
    ("Assignment", "target", "many"),
    ("Assignment", "value", "one"),
    ("Assignment", "aug_op", "one"),
    ("AstAccessNode", "access", "one"),
    ("AstDocNode", "doc", "one"),
    ("AstElseBodyNode", "else_body", "one"),
    ("AstImplNeedingNode", "body", "shaped"),
    ("AstTypedVarNode", "type_tag", "one"),
    ("AtomTrailer", "target", "one"),
    ("AtomTrailer", "right", "one"),
    ("AtomUnit", "value", "one"),
    ("AwaitExpr", "target", "one"),
    ("AwaitingClause", "body", "many"),
    ("BinaryExpr", "left", "one"),
    ("BinaryExpr", "right", "one"),
    ("BinaryExpr", "op", "one"),
    ("BoolExpr", "op", "one"),
    ("BoolExpr", "values", "many"),
    ("CastExpr", "value", "one"),
    ("CastExpr", "cast_type", "one"),
    ("CfgExpr", "expr", "one"),
    ("CompareExpr", "left", "one"),
    ("CompareExpr", "rights", "many"),
    ("CompareExpr", "ops", "many"),
    ("ConcurrentExpr", "tok", "one"),
    ("ConcurrentExpr", "target", "one"),
    ("ConnectOp", "conn_type", "one"),
    ("ConnectOp", "conn_assign", "one"),
    ("CtrlStmt", "ctrl", "one"),
    ("DeleteStmt", "target", "one"),
    ("DictCompr", "kv_pair", "one"),
    ("DictCompr", "compr", "many"),
    ("DictVal", "kv_pairs", "many"),
    ("DisconnectOp", "edge_spec", "one"),
    ("EdgeOpRef", "filter_cond", "one"),
    ("EdgeRefTrailer", "chain", "many"),
    ("ElseStmt", "body", "many"),
    ("Enum", "name", "one"),
    ("Enum", "value_type", "one"),
    ("Enum", "base_classes", "many"),
    ("EventSignature", "event", "one"),
    ("EventSignature", "arch_tag_info", "one"),
    ("Except", "ex_type", "one"),
    ("Except", "name", "one"),
    ("Except", "body", "many"),
    ("ExprAsItem", "expr", "one"),
    ("ExprAsItem", "alias", "one"),
    ("ExprStmt", "expr", "one"),
    ("FString", "start", "one"),
    ("FString", "parts", "many"),
    ("FString", "end", "one"),
    ("FilterCompr", "f_type", "one"),
    ("FilterCompr", "compares", "many"),
    ("FinallyStmt", "body", "many"),
    ("ForeverStmt", "body", "many"),
    ("FormattedValue", "format_part", "one"),
    ("FormattedValue", "format_spec", "one"),
    ("FuncCall", "target", "one"),
    ("FuncCall", "params", "many"),
    ("FuncSignature", "posonly_params", "many"),
    ("FuncSignature", "params", "many"),
    ("FuncSignature", "varargs", "one"),
    ("FuncSignature", "kwonlyargs", "many"),
    ("FuncSignature", "kwargs", "one"),
    ("FuncSignature", "return_type", "one"),
    ("GlobalVars", "assignments", "many"),
    ("HasVar", "name", "one"),
    ("HasVar", "value", "one"),
    ("HasVar", "accessors", "many"),
    ("IfElseExpr", "condition", "one"),
    ("IfElseExpr", "value", "one"),
    ("IfElseExpr", "else_value", "one"),
    ("IfStmt", "condition", "one"),
    ("IfStmt", "body", "many"),
    ("ImplDef", "decorators", "many"),
    ("ImplDef", "target", "many"),
    ("ImplDef", "spec", "shaped"),
    ("ImplDef", "body", "shaped"),
    ("Import", "from_loc", "one"),
    ("Import", "items", "many"),
    ("Import", "clib_decls", "many"),
    ("Import", "hint", "one"),
    ("InForStmt", "target", "one"),
    ("InForStmt", "collection", "one"),
    ("InForStmt", "body", "many"),
    ("IndexSlice", "slices", "many"),
    ("InnerCompr", "target", "one"),
    ("InnerCompr", "collection", "one"),
    ("InnerCompr", "conditional", "many"),
    ("IterForStmt", "iter", "one"),
    ("IterForStmt", "condition", "one"),
    ("IterForStmt", "count_by", "one"),
    ("IterForStmt", "body", "many"),
    ("JsxComment", "value", "one"),
    ("JsxElement", "name", "one"),
    ("JsxElement", "attributes", "many"),
    ("JsxElement", "children", "many"),
    ("JsxElement", "dynamic_tag", "one"),
    ("JsxElementName", "parts", "many"),
    ("JsxExpression", "expr", "one"),
    ("JsxNormalAttribute", "name", "one"),
    ("JsxNormalAttribute", "value", "one"),
    ("JsxSlot", "body", "many"),
    ("JsxSpreadAttribute", "expr", "one"),
    ("KVPair", "key", "one"),
    ("KVPair", "value", "one"),
    ("KWPair", "key", "one"),
    ("KWPair", "value", "one"),
    ("LambdaExpr", "body", "shaped"),
    ("LambdaExpr", "signature", "one"),
    ("ListCompr", "out_expr", "one"),
    ("ListCompr", "compr", "many"),
    ("ListVal", "values", "many"),
    ("MatchArch", "name", "one"),
    ("MatchArch", "arg_patterns", "many"),
    ("MatchArch", "kw_patterns", "many"),
    ("MatchAs", "name", "one"),
    ("MatchAs", "pattern", "one"),
    ("MatchCase", "pattern", "one"),
    ("MatchCase", "guard", "one"),
    ("MatchCase", "body", "many"),
    ("MatchKVPair", "key", "one"),
    ("MatchKVPair", "value", "one"),
    ("MatchMapping", "values", "many"),
    ("MatchOr", "patterns", "many"),
    ("MatchSequence", "values", "many"),
    ("MatchSingleton", "value", "one"),
    ("MatchStar", "name", "one"),
    ("MatchStmt", "target", "one"),
    ("MatchStmt", "cases", "many"),
    ("MatchValue", "value", "one"),
    ("Module", "body", "many"),
    ("ModuleCode", "name", "one"),
    ("ModuleCode", "body", "many"),
    ("ModuleItem", "name", "one"),
    ("ModuleItem", "alias", "one"),
    ("ModulePath", "path", "many"),
    ("ModulePath", "alias", "one"),
    ("MultiString", "strings", "many"),
    ("OpenStmt", "target", "one"),
    ("OpenStmt", "body", "many"),
    ("ParamVar", "name", "one"),
    ("ParamVar", "unpack", "one"),
    ("ParamVar", "value", "one"),
    ("ProgramModule", "main", "one"),
    ("PyInlineCode", "code", "one"),
    ("RaiseStmt", "cause", "one"),
    ("RaiseStmt", "from_target", "one"),
    ("ReportStmt", "expr", "one"),
    ("ReturnStmt", "expr", "one"),
    ("SemDef", "target", "many"),
    ("SemDef", "value", "one"),
    ("SetVal", "values", "many"),
    ("Slice", "start", "one"),
    ("Slice", "stop", "one"),
    ("Slice", "step", "one"),
    ("SwitchCase", "pattern", "one"),
    ("SwitchCase", "body", "many"),
    ("SwitchStmt", "target", "one"),
    ("SwitchStmt", "cases", "many"),
    ("Test", "name", "one"),
    ("Test", "body", "many"),
    ("Test", "description", "one"),
    ("Test", "decorators", "many"),
    ("TryStmt", "body", "many"),
    ("TryStmt", "excepts", "many"),
    ("TryStmt", "awaiting_body", "one"),
    ("TryStmt", "finally_body", "one"),
    ("TupleVal", "values", "many"),
    ("TypeAlias", "name", "one"),
    ("TypeAlias", "type_params", "many"),
    ("TypeAlias", "value", "one"),
    ("TypeParam", "name", "one"),
    ("TypeParam", "bound", "one"),
    ("TypeParam", "default_val", "one"),
    ("TypedCtxBlock", "type_ctx", "one"),
    ("TypedCtxBlock", "body", "many"),
    ("UnaryExpr", "operand", "one"),
    ("UnaryExpr", "op", "one"),
    ("VisitStmt", "insert_loc", "one"),
    ("VisitStmt", "target", "one"),
    ("WhileStmt", "condition", "one"),
    ("WhileStmt", "body", "many"),
    ("WithStmt", "exprs", "many"),
    ("WithStmt", "body", "many"),
    ("YieldExpr", "expr", "one")
);
