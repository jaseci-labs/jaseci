TABLE = {
 "UniNode": {
  "_ctx_parent": [
   "ref",
   True,
   None
  ],
  "ct_pruned": [
   "bool",
   False,
   None
  ]
 },
 "UniScopeNode": {
  "scope_name": [
   "str",
   False,
   None
  ]
 },
 "Module": {
  "name": [
   "str",
   False,
   None
  ],
  "source": [
   "ref",
   False,
   None
  ],
  "stub_only": [
   "bool",
   False,
   None
  ],
  "is_raised_from_py": [
   "bool",
   False,
   None
  ],
  "parse_failed": [
   "bool",
   False,
   None
  ],
  "mobui_enforced_root": [
   "str",
   True,
   None
  ],
  "jac_project_root": [
   "str",
   True,
   None
  ],
  "access_enforced": [
   "bool",
   False,
   None
  ],
  "ct_resolved": [
   "bool",
   False,
   None
  ],
  "native_viols_reported": [
   "bool",
   False,
   None
  ],
  "client_viols_reported": [
   "bool",
   False,
   None
  ]
 },
 "AstSymbolNode": {
  "name_spec": [
   "ref",
   False,
   None
  ],
  "semstr": [
   "str",
   False,
   None
  ]
 },
 "ContextAwareNode": {
  "codespace_dual": [
   "bool",
   False,
   None
  ]
 },
 "TypeAlias": {
  "is_distinct": [
   "bool",
   False,
   None
  ]
 },
 "AstAsyncNode": {
  "is_async": [
   "bool",
   False,
   None
  ]
 },
 "Ability": {
  "is_override": [
   "bool",
   False,
   None
  ],
  "is_static": [
   "bool",
   False,
   None
  ],
  "is_classmethod": [
   "bool",
   False,
   None
  ],
  "is_abstract": [
   "bool",
   False,
   None
  ],
  "accessor_kind": [
   "str",
   False,
   None
  ],
  "is_comptime": [
   "bool",
   False,
   None
  ]
 },
 "WalkerStmtOnlyNode": {
  "from_walker": [
   "bool",
   False,
   None
  ]
 },
 "IfStmt": {
  "is_comptime": [
   "bool",
   False,
   None
  ]
 },
 "InForStmt": {
  "is_comptime": [
   "bool",
   False,
   None
  ]
 },
 "Expr": {
  "_type_sym_tab": [
   "ref",
   True,
   None
  ],
  "_type_cache_ok": [
   "bool",
   False,
   None
  ],
  "coerce_to": [
   "str",
   True,
   None
  ],
  "fw": [
   "str",
   True,
   None
  ],
  "fw_safe": [
   "bool",
   False,
   None
  ]
 },
 "EnumBlockStmt": {
  "is_enum_stmt": [
   "bool",
   False,
   None
  ]
 },
 "NameAtom": {
  "name_of": [
   "ref",
   False,
   None
  ],
  "_sym_name": [
   "str",
   False,
   None
  ],
  "is_getattr_resolved": [
   "bool",
   False,
   None
  ]
 },
 "Name": {
  "is_enum_stmt": [
   "bool",
   False,
   None
  ],
  "is_kwesc": [
   "bool",
   False,
   None
  ]
 },
 "Token": {
  "orig_src": [
   "ref",
   False,
   None
  ],
  "name": [
   "str",
   False,
   None
  ],
  "value": [
   "str",
   False,
   None
  ],
  "line_no": [
   "int",
   False,
   None
  ],
  "end_line": [
   "int",
   False,
   None
  ],
  "c_start": [
   "int",
   False,
   None
  ],
  "c_end": [
   "int",
   False,
   None
  ],
  "pos_start": [
   "int",
   False,
   None
  ],
  "pos_end": [
   "int",
   False,
   None
  ],
  "_is_synthetic": [
   "bool",
   False,
   None
  ]
 },
 "SpecialVarRef": {
  "orig": [
   "ref",
   False,
   None
  ]
 },
 "IndexSlice": {
  "is_range": [
   "bool",
   False,
   None
  ]
 },
 "EdgeOpRef": {
  "edge_dir": [
   "enum",
   False,
   "EdgeDir"
  ]
 },
 "JsxElement": {
  "is_self_closing": [
   "bool",
   False,
   None
  ],
  "is_fragment": [
   "bool",
   False,
   None
  ]
 },
 "TypeParam": {
  "is_comptime": [
   "bool",
   False,
   None
  ]
 },
 "ParamVar": {
  "param_kind": [
   "enum",
   False,
   "ParamKind"
  ],
  "is_comptime": [
   "bool",
   False,
   None
  ]
 },
 "HasVar": {
  "defer": [
   "bool",
   False,
   None
  ]
 },
 "GlobalVars": {
  "is_frozen": [
   "bool",
   False,
   None
  ]
 },
 "ArchHas": {
  "is_static": [
   "bool",
   False,
   None
  ],
  "is_frozen": [
   "bool",
   False,
   None
  ]
 },
 "Import": {
  "is_absorb": [
   "bool",
   False,
   None
  ],
  "is_typed": [
   "bool",
   False,
   None
  ],
  "is_comptime": [
   "bool",
   False,
   None
  ],
  "native_only_drop": [
   "bool",
   False,
   None
  ]
 },
 "AssertStmt": {
  "is_comptime": [
   "bool",
   False,
   None
  ]
 },
 "Assignment": {
  "mutable": [
   "bool",
   False,
   None
  ],
  "na_move_lowerable": [
   "bool",
   False,
   None
  ],
  "na_overwrite_consumed": [
   "bool",
   False,
   None
  ],
  "na_flow_reduce": [
   "str",
   False,
   None
  ],
  "is_comptime": [
   "bool",
   False,
   None
  ]
 },
 "ExprStmt": {
  "in_fstring": [
   "bool",
   False,
   None
  ],
  "has_semi": [
   "bool",
   False,
   None
  ]
 },
 "ReturnStmt": {
  "is_implicit": [
   "bool",
   False,
   None
  ]
 },
 "UnaryExpr": {
  "ownership": [
   "enum",
   False,
   "OwnershipKind"
  ]
 },
 "FormattedValue": {
  "conversion": [
   "int",
   False,
   None
  ]
 },
 "AtomTrailer": {
  "is_attr": [
   "bool",
   False,
   None
  ],
  "is_null_ok": [
   "bool",
   False,
   None
  ],
  "is_genai": [
   "bool",
   False,
   None
  ]
 },
 "YieldExpr": {
  "with_from": [
   "bool",
   False,
   None
  ]
 },
 "FuncCall": {
  "genai_call": [
   "ref",
   True,
   None
  ],
  "call_kind": [
   "str",
   True,
   None
  ],
  "chunks_recv_type": [
   "str",
   True,
   None
  ]
 },
 "EdgeRefTrailer": {
  "edges_only": [
   "bool",
   False,
   None
  ],
  "is_async": [
   "bool",
   False,
   None
  ]
 },
 "MatchStar": {
  "is_list": [
   "bool",
   False,
   None
  ]
 },
 "SubTag": {
  "ownership": [
   "enum",
   False,
   "OwnershipKind"
  ]
 },
 "ModulePath": {
  "level": [
   "int",
   False,
   None
  ],
  "abs_path": [
   "str",
   True,
   None
  ]
 },
 "ModuleItem": {
  "abs_path": [
   "str",
   True,
   None
  ]
 },
 "ConnectOp": {
  "edge_dir": [
   "enum",
   False,
   "EdgeDir"
  ]
 },
 "JsxNormalAttribute": {
  "is_shorthand": [
   "bool",
   False,
   None
  ]
 },
 "Source": {
  "file_path": [
   "str",
   False,
   None
  ],
  "_hash": [
   "str",
   False,
   None
  ]
 },
 "PythonModuleAst": {
  "orig_src": [
   "ref",
   False,
   None
  ],
  "file_path": [
   "str",
   False,
   None
  ]
 },
 "Symbol": {
  "name": [
   "str",
   False,
   None
  ],
  "imported": [
   "bool",
   False,
   None
  ],
  "semstr": [
   "str",
   False,
   None
  ],
  "ownership": [
   "enum",
   False,
   "OwnershipKind"
  ],
  "param_rebound": [
   "bool",
   False,
   None
  ],
  "na_escapes": [
   "bool",
   False,
   None
  ],
  "na_region_handle": [
   "bool",
   False,
   None
  ],
  "na_stack_ok": [
   "bool",
   False,
   None
  ]
 },
 "Codespace": {
  "kind": [
   "str",
   False,
   None
  ]
 }
}
NODE_CLASSES = ["UniNode", "UniScopeNode", "Module", "TypeAlias", "Test", "Archetype", "ImplDef", "SemDef", "Enum", "Ability", "TypedCtxBlock", "OpenStmt", "IfStmt", "ElseIf", "ElseStmt", "TryStmt", "AwaitingClause", "Except", "FinallyStmt", "IterForStmt", "InForStmt", "WhileStmt", "ForeverStmt", "WithStmt", "LambdaExpr", "InnerCompr", "ListCompr", "GenCompr", "SetCompr", "DictCompr", "MatchCase", "SwitchCase", "AstSymbolNode", "AstSymbolStubNode", "AtomExpr", "NameAtom", "Name", "SpecialVarRef", "BuiltinType", "MultiString", "FString", "ListVal", "SetVal", "TupleVal", "DictVal", "IndexSlice", "EdgeOpRef", "FilterCompr", "AssignCompr", "JsxElement", "Literal", "Float", "Int", "String", "Bool", "Null", "Ellipsis", "AstImplNeedingNode", "ArchSpec", "TypeParam", "ParamVar", "HasVar", "AstAccessNode", "GlobalVars", "ArchHas", "ContextAwareNode", "ModuleCode", "Import", "AstDocNode", "ElementStmt", "PyInlineCode", "AssertStmt", "AstAsyncNode", "AstElseBodyNode", "VisitStmt", "AstTypedVarNode", "Assignment", "WalkerStmtOnlyNode", "EventSignature", "DisengageStmt", "DisconnectOp", "UniCFGNode", "ConditionalNode", "CfgExpr", "CodeBlockStmt", "ExprStmt", "RaiseStmt", "CtrlStmt", "DeleteStmt", "ReportStmt", "ReturnStmt", "MatchStmt", "SwitchStmt", "Semi", "Expr", "AwaitExpr", "CastExpr", "ConcurrentExpr", "BinaryExpr", "CompareExpr", "BoolExpr", "UnaryExpr", "IfElseExpr", "FormattedValue", "AtomTrailer", "AtomUnit", "YieldExpr", "FuncCall", "EdgeRefTrailer", "ArchBlockStmt", "EnumBlockStmt", "MatchPattern", "MatchOr", "MatchAs", "MatchWild", "MatchValue", "MatchSingleton", "MatchSequence", "MatchMapping", "MatchKVPair", "MatchStar", "MatchArch", "SubTag", "ProgramModule", "ModulePath", "ModuleItem", "FuncSignature", "ExprAsItem", "KVPair", "KWPair", "Slice", "ConnectOp", "JsxElementName", "JsxAttribute", "JsxSpreadAttribute", "JsxNormalAttribute", "JsxChild", "JsxText", "JsxExpression", "JsxSlot", "JsxComment", "Token", "EmptyToken", "Source", "PythonModuleAst", "CommentToken", "Symbol", "Codespace"]
