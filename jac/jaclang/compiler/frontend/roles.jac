import from typing { ClassVar }

edge Role {
    with entry {
        NAME: ClassVar[str] = "";
    }

    has in_kid: bool = True;
}

edge KidRole(Role) {
    with entry {
        NAME: ClassVar[str] = "kid";
    }
}

edge ImplOf {}

edge AccessRole(Role) {
    with entry {
        NAME: ClassVar[str] = "access";
    }
}

edge AccessorsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "accessors";
    }
}

edge AliasRole(Role) {
    with entry {
        NAME: ClassVar[str] = "alias";
    }
}

edge ArchTagInfoRole(Role) {
    with entry {
        NAME: ClassVar[str] = "arch_tag_info";
    }
}

edge ArchTypeRole(Role) {
    with entry {
        NAME: ClassVar[str] = "arch_type";
    }
}

edge ArgPatternsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "arg_patterns";
    }
}

edge AssignmentsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "assignments";
    }
}

edge AssignsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "assigns";
    }
}

edge AttributesRole(Role) {
    with entry {
        NAME: ClassVar[str] = "attributes";
    }
}

edge AugOpRole(Role) {
    with entry {
        NAME: ClassVar[str] = "aug_op";
    }
}

edge AwaitingBodyRole(Role) {
    with entry {
        NAME: ClassVar[str] = "awaiting_body";
    }
}

edge BaseClassesRole(Role) {
    with entry {
        NAME: ClassVar[str] = "base_classes";
    }
}

edge BodyRole(Role) {
    with entry {
        NAME: ClassVar[str] = "body";
    }
}

edge BoundRole(Role) {
    with entry {
        NAME: ClassVar[str] = "bound";
    }
}

edge CasesRole(Role) {
    with entry {
        NAME: ClassVar[str] = "cases";
    }
}

edge CastTypeRole(Role) {
    with entry {
        NAME: ClassVar[str] = "cast_type";
    }
}

edge CauseRole(Role) {
    with entry {
        NAME: ClassVar[str] = "cause";
    }
}

edge ChainRole(Role) {
    with entry {
        NAME: ClassVar[str] = "chain";
    }
}

edge ChildrenRole(Role) {
    with entry {
        NAME: ClassVar[str] = "children";
    }
}

edge ClibDeclsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "clib_decls";
    }
}

edge CodeRole(Role) {
    with entry {
        NAME: ClassVar[str] = "code";
    }
}

edge CollectionRole(Role) {
    with entry {
        NAME: ClassVar[str] = "collection";
    }
}

edge ComparesRole(Role) {
    with entry {
        NAME: ClassVar[str] = "compares";
    }
}

edge ComprRole(Role) {
    with entry {
        NAME: ClassVar[str] = "compr";
    }
}

edge ConditionRole(Role) {
    with entry {
        NAME: ClassVar[str] = "condition";
    }
}

edge ConditionalRole(Role) {
    with entry {
        NAME: ClassVar[str] = "conditional";
    }
}

edge ConnAssignRole(Role) {
    with entry {
        NAME: ClassVar[str] = "conn_assign";
    }
}

edge ConnTypeRole(Role) {
    with entry {
        NAME: ClassVar[str] = "conn_type";
    }
}

edge CountByRole(Role) {
    with entry {
        NAME: ClassVar[str] = "count_by";
    }
}

edge CtrlRole(Role) {
    with entry {
        NAME: ClassVar[str] = "ctrl";
    }
}

edge DecoratorsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "decorators";
    }
}

edge DefaultValRole(Role) {
    with entry {
        NAME: ClassVar[str] = "default_val";
    }
}

edge DescriptionRole(Role) {
    with entry {
        NAME: ClassVar[str] = "description";
    }
}

edge DocRole(Role) {
    with entry {
        NAME: ClassVar[str] = "doc";
    }
}

edge DynamicTagRole(Role) {
    with entry {
        NAME: ClassVar[str] = "dynamic_tag";
    }
}

edge EdgeSpecRole(Role) {
    with entry {
        NAME: ClassVar[str] = "edge_spec";
    }
}

edge ElseBodyRole(Role) {
    with entry {
        NAME: ClassVar[str] = "else_body";
    }
}

edge ElseValueRole(Role) {
    with entry {
        NAME: ClassVar[str] = "else_value";
    }
}

edge EndRole(Role) {
    with entry {
        NAME: ClassVar[str] = "end";
    }
}

edge ErrorMsgRole(Role) {
    with entry {
        NAME: ClassVar[str] = "error_msg";
    }
}

edge EventRole(Role) {
    with entry {
        NAME: ClassVar[str] = "event";
    }
}

edge ExTypeRole(Role) {
    with entry {
        NAME: ClassVar[str] = "ex_type";
    }
}

edge ExceptsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "excepts";
    }
}

edge ExprRole(Role) {
    with entry {
        NAME: ClassVar[str] = "expr";
    }
}

edge ExprsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "exprs";
    }
}

edge FTypeRole(Role) {
    with entry {
        NAME: ClassVar[str] = "f_type";
    }
}

edge FilterCondRole(Role) {
    with entry {
        NAME: ClassVar[str] = "filter_cond";
    }
}

edge FinallyBodyRole(Role) {
    with entry {
        NAME: ClassVar[str] = "finally_body";
    }
}

edge FormatPartRole(Role) {
    with entry {
        NAME: ClassVar[str] = "format_part";
    }
}

edge FormatSpecRole(Role) {
    with entry {
        NAME: ClassVar[str] = "format_spec";
    }
}

edge FromLocRole(Role) {
    with entry {
        NAME: ClassVar[str] = "from_loc";
    }
}

edge FromTargetRole(Role) {
    with entry {
        NAME: ClassVar[str] = "from_target";
    }
}

edge GuardRole(Role) {
    with entry {
        NAME: ClassVar[str] = "guard";
    }
}

edge HintRole(Role) {
    with entry {
        NAME: ClassVar[str] = "hint";
    }
}

edge InsertLocRole(Role) {
    with entry {
        NAME: ClassVar[str] = "insert_loc";
    }
}

edge ItemsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "items";
    }
}

edge IterRole(Role) {
    with entry {
        NAME: ClassVar[str] = "iter";
    }
}

edge KeyRole(Role) {
    with entry {
        NAME: ClassVar[str] = "key";
    }
}

edge KeywordsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "keywords";
    }
}

edge KvPairRole(Role) {
    with entry {
        NAME: ClassVar[str] = "kv_pair";
    }
}

edge KvPairsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "kv_pairs";
    }
}

edge KwPatternsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "kw_patterns";
    }
}

edge KwargsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "kwargs";
    }
}

edge KwonlyargsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "kwonlyargs";
    }
}

edge LeftRole(Role) {
    with entry {
        NAME: ClassVar[str] = "left";
    }
}

edge MainRole(Role) {
    with entry {
        NAME: ClassVar[str] = "main";
    }
}

edge NameRole(Role) {
    with entry {
        NAME: ClassVar[str] = "name";
    }
}

edge NameRefRole(Role) {
    with entry {
        NAME: ClassVar[str] = "name_ref";
    }
}

edge OpRole(Role) {
    with entry {
        NAME: ClassVar[str] = "op";
    }
}

edge OperandRole(Role) {
    with entry {
        NAME: ClassVar[str] = "operand";
    }
}

edge OpsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "ops";
    }
}

edge OutExprRole(Role) {
    with entry {
        NAME: ClassVar[str] = "out_expr";
    }
}

edge ParamsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "params";
    }
}

edge PartsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "parts";
    }
}

edge PathRole(Role) {
    with entry {
        NAME: ClassVar[str] = "path";
    }
}

edge PatternRole(Role) {
    with entry {
        NAME: ClassVar[str] = "pattern";
    }
}

edge PatternsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "patterns";
    }
}

edge PosonlyParamsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "posonly_params";
    }
}

edge ReturnTypeRole(Role) {
    with entry {
        NAME: ClassVar[str] = "return_type";
    }
}

edge RightRole(Role) {
    with entry {
        NAME: ClassVar[str] = "right";
    }
}

edge RightsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "rights";
    }
}

edge SignatureRole(Role) {
    with entry {
        NAME: ClassVar[str] = "signature";
    }
}

edge SlicesRole(Role) {
    with entry {
        NAME: ClassVar[str] = "slices";
    }
}

edge SpecRole(Role) {
    with entry {
        NAME: ClassVar[str] = "spec";
    }
}

edge SrcEndpointRole(Role) {
    with entry {
        NAME: ClassVar[str] = "src_endpoint";
    }
}

edge StartRole(Role) {
    with entry {
        NAME: ClassVar[str] = "start";
    }
}

edge StepRole(Role) {
    with entry {
        NAME: ClassVar[str] = "step";
    }
}

edge StopRole(Role) {
    with entry {
        NAME: ClassVar[str] = "stop";
    }
}

edge StringsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "strings";
    }
}

edge TargetRole(Role) {
    with entry {
        NAME: ClassVar[str] = "target";
    }
}

edge TgtEndpointRole(Role) {
    with entry {
        NAME: ClassVar[str] = "tgt_endpoint";
    }
}

edge TokRole(Role) {
    with entry {
        NAME: ClassVar[str] = "tok";
    }
}

edge TypeCtxRole(Role) {
    with entry {
        NAME: ClassVar[str] = "type_ctx";
    }
}

edge TypeParamsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "type_params";
    }
}

edge TypeTagRole(Role) {
    with entry {
        NAME: ClassVar[str] = "type_tag";
    }
}

edge UnpackRole(Role) {
    with entry {
        NAME: ClassVar[str] = "unpack";
    }
}

edge ValueRole(Role) {
    with entry {
        NAME: ClassVar[str] = "value";
    }
}

edge ValueTypeRole(Role) {
    with entry {
        NAME: ClassVar[str] = "value_type";
    }
}

edge ValuesRole(Role) {
    with entry {
        NAME: ClassVar[str] = "values";
    }
}

edge VarargsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "varargs";
    }
}

edge VarsRole(Role) {
    with entry {
        NAME: ClassVar[str] = "vars";
    }
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
