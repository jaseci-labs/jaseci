edge Role {
    has in_kid: bool = True;
}

edge KidRole(Role) {}

edge ImplOf {}

edge AccessRole(Role) {}

edge AccessorsRole(Role) {}

edge AliasRole(Role) {}

edge ArchTagInfoRole(Role) {}

edge ArchTypeRole(Role) {}

edge ArgPatternsRole(Role) {}

edge AssignmentsRole(Role) {}

edge AssignsRole(Role) {}

edge AttributesRole(Role) {}

edge AugOpRole(Role) {}

edge AwaitingBodyRole(Role) {}

edge BaseClassesRole(Role) {}

edge BodyRole(Role) {}

edge BoundRole(Role) {}

edge CasesRole(Role) {}

edge CastTypeRole(Role) {}

edge CauseRole(Role) {}

edge ChainRole(Role) {}

edge ChildrenRole(Role) {}

edge ClibDeclsRole(Role) {}

edge CodeRole(Role) {}

edge CollectionRole(Role) {}

edge ComparesRole(Role) {}

edge ComprRole(Role) {}

edge ConditionRole(Role) {}

edge ConditionalRole(Role) {}

edge ConnAssignRole(Role) {}

edge ConnTypeRole(Role) {}

edge CountByRole(Role) {}

edge CtrlRole(Role) {}

edge DecoratorsRole(Role) {}

edge DefaultValRole(Role) {}

edge DescriptionRole(Role) {}

edge DocRole(Role) {}

edge DynamicTagRole(Role) {}

edge EdgeSpecRole(Role) {}

edge ElseBodyRole(Role) {}

edge ElseValueRole(Role) {}

edge EndRole(Role) {}

edge ErrorMsgRole(Role) {}

edge EventRole(Role) {}

edge ExTypeRole(Role) {}

edge ExceptsRole(Role) {}

edge ExprRole(Role) {}

edge ExprsRole(Role) {}

edge FTypeRole(Role) {}

edge FilterCondRole(Role) {}

edge FinallyBodyRole(Role) {}

edge FormatPartRole(Role) {}

edge FormatSpecRole(Role) {}

edge FromLocRole(Role) {}

edge FromTargetRole(Role) {}

edge GuardRole(Role) {}

edge HintRole(Role) {}

edge InsertLocRole(Role) {}

edge ItemsRole(Role) {}

edge IterRole(Role) {}

edge KeyRole(Role) {}

edge KeywordsRole(Role) {}

edge KvPairRole(Role) {}

edge KvPairsRole(Role) {}

edge KwPatternsRole(Role) {}

edge KwargsRole(Role) {}

edge KwonlyargsRole(Role) {}

edge LeftRole(Role) {}

edge MainRole(Role) {}

edge NameRole(Role) {}

edge NameRefRole(Role) {}

edge OpRole(Role) {}

edge OperandRole(Role) {}

edge OpsRole(Role) {}

edge OutExprRole(Role) {}

edge ParamsRole(Role) {}

edge PartsRole(Role) {}

edge PathRole(Role) {}

edge PatternRole(Role) {}

edge PatternsRole(Role) {}

edge PosonlyParamsRole(Role) {}

edge ReturnTypeRole(Role) {}

edge RightRole(Role) {}

edge RightsRole(Role) {}

edge SignatureRole(Role) {}

edge SlicesRole(Role) {}

edge SpecRole(Role) {}

edge SrcEndpointRole(Role) {}

edge StartRole(Role) {}

edge StepRole(Role) {}

edge StopRole(Role) {}

edge StringsRole(Role) {}

edge TargetRole(Role) {}

edge TgtEndpointRole(Role) {}

edge TokRole(Role) {}

edge TypeCtxRole(Role) {}

edge TypeParamsRole(Role) {}

edge TypeTagRole(Role) {}

edge UnpackRole(Role) {}

edge ValueRole(Role) {}

edge ValueTypeRole(Role) {}

edge ValuesRole(Role) {}

edge VarargsRole(Role) {}

edge VarsRole(Role) {}

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
