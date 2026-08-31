"""Field-to-role map for the PyObject-unitree bridge (#8789).

Generated from the role-backed getters in unitree.impl/roles.impl.jac and
impl/unitree.impl.jac: for each class, the fields whose storage is graph
adjacency rather than a struct slot, with the role edge class, direction
(2 = out, 1 = in), and result shape:

- "many": the full adjacency list
- "one": exactly one target (indexed [0])
- "opt": first target or None
- "shaped": runtime one/many/none via the node's _role_shapes (np_role_shape)
- "complex": hand-written logic -- the bridge leaves the twin's getter in
  place and routes its edge reads through the graph seam

Regenerate by rerunning the extraction over the getter impls after role
schema changes.
"""

ROLE_FIELDS: dict[str, dict[str, tuple[str, int, str]]] = {
    'Ability': {
        'decorators': ('DecoratorsRole', 2, 'many'),
        'event_triggers': ('EventTriggerOf', 2, 'many'),
        'name_ref': ('NameRefRole', 2, 'opt'),
        'signature': ('SignatureRole', 2, 'opt'),
        'type_params': ('TypeParamsRole', 2, 'many'),
    },
    'ArchHas': {
        'vars': ('VarsRole', 2, 'many'),
    },
    'ArchSpec': {
        'decorators': ('DecoratorsRole', 2, 'many'),
    },
    'Archetype': {
        'arch_type': ('ArchTypeRole', 2, 'one'),
        'base_classes': ('BaseClassesRole', 2, 'many'),
        'keywords': ('KeywordsRole', 2, 'many'),
        'name': ('NameRole', 2, 'one'),
        'src_endpoint': ('SrcEndpointRole', 2, 'opt'),
        'tgt_endpoint': ('TgtEndpointRole', 2, 'opt'),
        'type_params': ('TypeParamsRole', 2, 'many'),
    },
    'AssertStmt': {
        'condition': ('ConditionRole', 2, 'one'),
        'error_msg': ('ErrorMsgRole', 2, 'opt'),
    },
    'AssignCompr': {
        'assigns': ('AssignsRole', 2, 'many'),
    },
    'Assignment': {
        'aug_op': ('AugOpRole', 2, 'opt'),
        'target': ('TargetRole', 2, 'many'),
        'value': ('ValueRole', 2, 'opt'),
    },
    'AstAccessNode': {
        'access': ('AccessRole', 2, 'opt'),
    },
    'AstDocNode': {
        'doc': ('DocRole', 2, 'opt'),
    },
    'AstElseBodyNode': {
        'else_body': ('ElseBodyRole', 2, 'opt'),
    },
    'AstImplNeedingNode': {
        'body': ('BodyRole', 2, 'shaped'),
    },
    'AstTypedVarNode': {
        'type': ('TypeOf', 2, 'opt'),
        'type_tag': ('TypeTagRole', 2, 'opt'),
    },
    'AtomTrailer': {
        'right': ('RightRole', 2, 'one'),
        'target': ('TargetRole', 2, 'one'),
    },
    'AtomUnit': {
        'value': ('ValueRole', 2, 'one'),
    },
    'AwaitExpr': {
        'target': ('TargetRole', 2, 'one'),
    },
    'AwaitingClause': {
        'body': ('BodyRole', 2, 'many'),
    },
    'BinaryExpr': {
        'left': ('LeftRole', 2, 'one'),
        'op': ('OpRole', 2, 'one'),
        'right': ('RightRole', 2, 'one'),
    },
    'BoolExpr': {
        'op': ('OpRole', 2, 'one'),
        'values': ('ValuesRole', 2, 'many'),
    },
    'CastExpr': {
        'cast_type': ('CastTypeRole', 2, 'one'),
        'value': ('ValueRole', 2, 'one'),
    },
    'CfgExpr': {
        'expr': ('ExprRole', 2, 'one'),
    },
    'CompareExpr': {
        'left': ('LeftRole', 2, 'one'),
        'ops': ('OpsRole', 2, 'many'),
        'rights': ('RightsRole', 2, 'many'),
    },
    'ConcurrentExpr': {
        'target': ('TargetRole', 2, 'one'),
        'tok': ('TokRole', 2, 'opt'),
    },
    'ConditionalNode': {
        'sc_false_target': ('CfgFalse', 2, 'opt'),
        'sc_true_target': ('CfgTrue', 2, 'opt'),
    },
    'ConnectOp': {
        'conn_assign': ('ConnAssignRole', 2, 'opt'),
        'conn_type': ('ConnTypeRole', 2, 'opt'),
    },
    'ContextAwareNode': {
        'code_context': ('PlacedIn', 2, 'complex'),
    },
    'CtrlStmt': {
        'ctrl': ('CtrlRole', 2, 'one'),
    },
    'DeleteStmt': {
        'targets': ('TargetRole', 2, 'many'),
    },
    'DictCompr': {
        'compr': ('ComprRole', 2, 'many'),
        'kv_pair': ('KvPairRole', 2, 'one'),
    },
    'DictVal': {
        'kv_pairs': ('KvPairsRole', 2, 'many'),
    },
    'DisconnectOp': {
        'edge_spec': ('EdgeSpecRole', 2, 'one'),
    },
    'EdgeOpRef': {
        'filter_cond': ('FilterCondRole', 2, 'opt'),
    },
    'EdgeRefTrailer': {
        'chain': ('ChainRole', 2, 'many'),
    },
    'ElseStmt': {
        'body': ('BodyRole', 2, 'many'),
    },
    'Enum': {
        'base_classes': ('BaseClassesRole', 2, 'many'),
        'name': ('NameRole', 2, 'one'),
        'value_type': ('ValueTypeRole', 2, 'opt'),
    },
    'EventSignature': {
        'arch_tag_info': ('ArchTagInfoRole', 2, 'opt'),
        'event': ('EventRole', 2, 'one'),
    },
    'Except': {
        'body': ('BodyRole', 2, 'many'),
        'ex_type': ('ExTypeRole', 2, 'one'),
        'name': ('NameRole', 2, 'opt'),
    },
    'Expr': {
        'narrowed_type': ('NarrowedTypeOf', 2, 'opt'),
        'type': ('TypeOf', 2, 'opt'),
    },
    'ExprAsItem': {
        'alias': ('AliasRole', 2, 'opt'),
        'expr': ('ExprRole', 2, 'one'),
    },
    'ExprStmt': {
        'expr': ('ExprRole', 2, 'one'),
    },
    'FString': {
        'end': ('EndRole', 2, 'opt'),
        'parts': ('PartsRole', 2, 'many'),
        'start': ('StartRole', 2, 'opt'),
    },
    'FilterCompr': {
        'compares': ('ComparesRole', 2, 'many'),
        'f_type': ('FTypeRole', 2, 'opt'),
    },
    'FinallyStmt': {
        'body': ('BodyRole', 2, 'many'),
    },
    'ForeverStmt': {
        'body': ('BodyRole', 2, 'many'),
    },
    'FormattedValue': {
        'format_part': ('FormatPartRole', 2, 'one'),
        'format_spec': ('FormatSpecRole', 2, 'opt'),
    },
    'FuncCall': {
        'callee_decl': ('CalleeDecl', 2, 'opt'),
        'params': ('ParamsRole', 2, 'many'),
        'target': ('TargetRole', 2, 'one'),
    },
    'FuncSignature': {
        'kwargs': ('KwargsRole', 2, 'opt'),
        'kwonlyargs': ('KwonlyargsRole', 2, 'many'),
        'params': ('ParamsRole', 2, 'many'),
        'posonly_params': ('PosonlyParamsRole', 2, 'many'),
        'return_type': ('ReturnTypeRole', 2, 'opt'),
        'varargs': ('VarargsRole', 2, 'opt'),
    },
    'GlobalVars': {
        'assignments': ('AssignmentsRole', 2, 'many'),
    },
    'HasVar': {
        'accessors': ('AccessorsRole', 2, 'shaped'),
        'name': ('NameRole', 2, 'one'),
        'value': ('ValueRole', 2, 'opt'),
    },
    'IfElseExpr': {
        'condition': ('ConditionRole', 2, 'one'),
        'else_value': ('ElseValueRole', 2, 'one'),
        'value': ('ValueRole', 2, 'one'),
    },
    'IfStmt': {
        'body': ('BodyRole', 2, 'many'),
        'condition': ('ConditionRole', 2, 'one'),
    },
    'ImplDef': {
        'body': ('BodyRole', 2, 'shaped'),
        'decl_link': ('ImplOf', 1, 'opt'),
        'decorators': ('DecoratorsRole', 2, 'many'),
        'spec': ('SpecRole', 2, 'shaped'),
        'target': ('TargetRole', 2, 'many'),
    },
    'Import': {
        'absorbed_mod': ('Absorbs', 2, 'opt'),
        'clib_decls': ('ClibDeclsRole', 2, 'many'),
        'from_loc': ('FromLocRole', 2, 'opt'),
        'hint': ('HintRole', 2, 'opt'),
        'items': ('ItemsRole', 2, 'many'),
    },
    'InForStmt': {
        'body': ('BodyRole', 2, 'many'),
        'collection': ('CollectionRole', 2, 'one'),
        'target': ('TargetRole', 2, 'one'),
    },
    'IndexSlice': {
        'slices': ('SlicesRole', 2, 'many'),
    },
    'InnerCompr': {
        'collection': ('CollectionRole', 2, 'one'),
        'conditional': ('ConditionalRole', 2, 'many'),
        'target': ('TargetRole', 2, 'one'),
    },
    'IterForStmt': {
        'body': ('BodyRole', 2, 'many'),
        'condition': ('ConditionRole', 2, 'one'),
        'count_by': ('CountByRole', 2, 'one'),
        'iter': ('IterRole', 2, 'one'),
    },
    'JsxComment': {
        'value': ('ValueRole', 2, 'one'),
    },
    'JsxElement': {
        'attributes': ('AttributesRole', 2, 'many'),
        'children': ('ChildrenRole', 2, 'many'),
        'dynamic_tag': ('DynamicTagRole', 2, 'opt'),
        'name': ('NameRole', 2, 'opt'),
    },
    'JsxElementName': {
        'parts': ('PartsRole', 2, 'many'),
    },
    'JsxExpression': {
        'expr': ('ExprRole', 2, 'one'),
    },
    'JsxNormalAttribute': {
        'name': ('NameRole', 2, 'one'),
        'value': ('ValueRole', 2, 'opt'),
    },
    'JsxSlot': {
        'body': ('BodyRole', 2, 'many'),
    },
    'JsxSpreadAttribute': {
        'expr': ('ExprRole', 2, 'one'),
    },
    'KVPair': {
        'key': ('KeyRole', 2, 'opt'),
        'value': ('ValueRole', 2, 'one'),
    },
    'KWPair': {
        'key': ('KeyRole', 2, 'opt'),
        'value': ('ValueRole', 2, 'one'),
    },
    'LambdaExpr': {
        'body': ('BodyRole', 2, 'shaped'),
        'signature': ('SignatureRole', 2, 'opt'),
    },
    'ListCompr': {
        'compr': ('ComprRole', 2, 'many'),
        'out_expr': ('OutExprRole', 2, 'one'),
    },
    'ListVal': {
        'values': ('ValuesRole', 2, 'many'),
    },
    'MatchArch': {
        'arg_patterns': ('ArgPatternsRole', 2, 'many'),
        'kw_patterns': ('KwPatternsRole', 2, 'many'),
        'name': ('NameRole', 2, 'one'),
    },
    'MatchAs': {
        'name': ('NameRole', 2, 'one'),
        'pattern': ('PatternRole', 2, 'opt'),
    },
    'MatchCase': {
        'body': ('BodyRole', 2, 'many'),
        'guard': ('GuardRole', 2, 'opt'),
        'pattern': ('PatternRole', 2, 'one'),
    },
    'MatchKVPair': {
        'key': ('KeyRole', 2, 'one'),
        'value': ('ValueRole', 2, 'one'),
    },
    'MatchMapping': {
        'values': ('ValuesRole', 2, 'many'),
    },
    'MatchOr': {
        'patterns': ('PatternsRole', 2, 'many'),
    },
    'MatchSequence': {
        'values': ('ValuesRole', 2, 'many'),
    },
    'MatchSingleton': {
        'value': ('ValueRole', 2, 'one'),
    },
    'MatchStar': {
        'name': ('NameRole', 2, 'one'),
    },
    'MatchStmt': {
        'cases': ('CasesRole', 2, 'many'),
        'target': ('TargetRole', 2, 'one'),
    },
    'MatchValue': {
        'value': ('ValueRole', 2, 'one'),
    },
    'Module': {
        'body': ('BodyRole', 2, 'many'),
        'decided_codespace': ('DecidedCodespace', 2, 'complex'),
    },
    'ModuleCode': {
        'body': ('BodyRole', 2, 'many'),
        'name': ('NameRole', 2, 'opt'),
    },
    'ModuleItem': {
        'alias': ('AliasRole', 2, 'opt'),
        'name': ('NameRole', 2, 'one'),
    },
    'ModulePath': {
        'alias': ('AliasRole', 2, 'opt'),
        'path': ('PathRole', 2, 'many'),
    },
    'MultiString': {
        'strings': ('StringsRole', 2, 'many'),
    },
    'NameAtom': {
        'sym': ('SymOf', 2, 'opt'),
    },
    'OpenStmt': {
        'body': ('BodyRole', 2, 'many'),
        'target': ('TargetRole', 2, 'one'),
    },
    'ParamVar': {
        'name': ('NameRole', 2, 'one'),
        'unpack': ('UnpackRole', 2, 'opt'),
        'value': ('ValueRole', 2, 'opt'),
    },
    'ProgramModule': {
        'main': ('MainRole', 2, 'one'),
        'main_mod': ('MainRole', 2, 'complex'),
    },
    'PyInlineCode': {
        'code': ('CodeRole', 2, 'one'),
    },
    'RaiseStmt': {
        'cause': ('CauseRole', 2, 'opt'),
        'from_target': ('FromTargetRole', 2, 'opt'),
    },
    'ReportStmt': {
        'expr': ('ExprRole', 2, 'one'),
    },
    'ReturnStmt': {
        'expr': ('ExprRole', 2, 'opt'),
    },
    'SemDef': {
        'target': ('TargetRole', 2, 'many'),
        'value': ('ValueRole', 2, 'one'),
    },
    'SetVal': {
        'values': ('ValuesRole', 2, 'many'),
    },
    'Slice': {
        'start': ('StartRole', 2, 'opt'),
        'step': ('StepRole', 2, 'opt'),
        'stop': ('StopRole', 2, 'opt'),
    },
    'SwitchCase': {
        'body': ('BodyRole', 2, 'many'),
        'pattern': ('PatternRole', 2, 'opt'),
    },
    'SwitchStmt': {
        'cases': ('CasesRole', 2, 'many'),
        'target': ('TargetRole', 2, 'one'),
    },
    'Symbol': {
        'defn': ('Defines', 2, 'many'),
        'parent_tab': ('InScope', 1, 'opt'),
        'uses': ('Uses', 2, 'many'),
    },
    'Test': {
        'body': ('BodyRole', 2, 'many'),
        'decorators': ('DecoratorsRole', 2, 'many'),
        'description': ('DescriptionRole', 2, 'opt'),
        'name': ('NameRole', 2, 'one'),
    },
    'TryStmt': {
        'awaiting_body': ('AwaitingBodyRole', 2, 'opt'),
        'body': ('BodyRole', 2, 'many'),
        'excepts': ('ExceptsRole', 2, 'many'),
        'finally_body': ('FinallyBodyRole', 2, 'opt'),
    },
    'TupleVal': {
        'values': ('ValuesRole', 2, 'many'),
    },
    'TypeAlias': {
        'name': ('NameRole', 2, 'one'),
        'type_params': ('TypeParamsRole', 2, 'many'),
        'value': ('ValueRole', 2, 'one'),
    },
    'TypeParam': {
        'bound': ('BoundRole', 2, 'opt'),
        'default_val': ('DefaultValRole', 2, 'opt'),
        'name': ('NameRole', 2, 'one'),
    },
    'TypedCtxBlock': {
        'body': ('BodyRole', 2, 'many'),
        'type_ctx': ('TypeCtxRole', 2, 'one'),
    },
    'UnaryExpr': {
        'op': ('OpRole', 2, 'one'),
        'operand': ('OperandRole', 2, 'one'),
    },
    'UniCFGNode': {
        'bb_in': ('CfgSucc', 1, 'many'),
        'bb_out': ('CfgSucc', 2, 'many'),
    },
    'UniNode': {
        'kid': ('Kid', 2, 'many'),
        'parent': ('Kid', 1, 'opt'),
    },
    'UniScopeNode': {
        'kid_scope': ('ScopeChild', 2, 'many'),
        'parent_scope': ('ScopeChild', 1, 'opt'),
    },
    'VisitStmt': {
        'insert_loc': ('InsertLocRole', 2, 'opt'),
        'target': ('TargetRole', 2, 'one'),
    },
    'WhileStmt': {
        'body': ('BodyRole', 2, 'many'),
        'condition': ('ConditionRole', 2, 'one'),
    },
    'WithStmt': {
        'body': ('BodyRole', 2, 'many'),
        'exprs': ('ExprsRole', 2, 'many'),
    },
    'YieldExpr': {
        'expr': ('ExprRole', 2, 'opt'),
    },
}
