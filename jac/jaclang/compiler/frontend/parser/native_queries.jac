import from jaclang.compiler.frontend.unitree { UniNode }
import from jaclang.compiler.frontend.roles {
    Role,
    Kid,
    ImplOf,
    AccessRole,
    AccessorsRole,
    AliasRole,
    ArchTagInfoRole,
    ArchTypeRole,
    ArgPatternsRole,
    AssignmentsRole,
    AssignsRole,
    AttributesRole,
    AugOpRole,
    AwaitingBodyRole,
    BaseClassesRole,
    BodyRole,
    BoundRole,
    CasesRole,
    CastTypeRole,
    CauseRole,
    ChainRole,
    ChildrenRole,
    ClibDeclsRole,
    CodeRole,
    CollectionRole,
    ComparesRole,
    ComprRole,
    ConditionRole,
    ConditionalRole,
    ConnAssignRole,
    ConnTypeRole,
    CountByRole,
    CtrlRole,
    DecoratorsRole,
    DefaultValRole,
    DescriptionRole,
    DocRole,
    DynamicTagRole,
    EdgeSpecRole,
    ElseBodyRole,
    ElseValueRole,
    EndRole,
    ErrorMsgRole,
    EventRole,
    ExTypeRole,
    ExceptsRole,
    ExprRole,
    ExprsRole,
    FTypeRole,
    FilterCondRole,
    FinallyBodyRole,
    FormatPartRole,
    FormatSpecRole,
    FromLocRole,
    FromTargetRole,
    GuardRole,
    HintRole,
    InsertLocRole,
    ItemsRole,
    IterRole,
    KeyRole,
    KeywordsRole,
    KvPairRole,
    KvPairsRole,
    KwPatternsRole,
    KwargsRole,
    KwonlyargsRole,
    LeftRole,
    MainRole,
    NameRole,
    NameRefRole,
    OpRole,
    OperandRole,
    OpsRole,
    OutExprRole,
    ParamsRole,
    PartsRole,
    PathRole,
    PatternRole,
    PatternsRole,
    PosonlyParamsRole,
    ReturnTypeRole,
    RightRole,
    RightsRole,
    SignatureRole,
    SlicesRole,
    SpecRole,
    SrcEndpointRole,
    StartRole,
    StepRole,
    StopRole,
    StringsRole,
    TargetRole,
    TgtEndpointRole,
    TokRole,
    TypeCtxRole,
    TypeParamsRole,
    TypeTagRole,
    UnpackRole,
    ValueRole,
    ValueTypeRole,
    ValuesRole,
    VarargsRole,
    VarsRole
}
import from jaclang.compiler.frontend.relations {
    SymOf,
    Defines,
    Uses,
    InScope,
    ScopePrimary,
    ScopeOverload,
    ScopeChild,
    ScopeParent,
    CfgSucc,
    CfgTrue,
    CfgFalse,
    PlacedIn,
    DecidedCodespace,
    CalleeDecl,
    Absorbs,
    AttachedComment,
    TypeParamOf,
    TypeArgOf,
    ParamOf,
    ReturnsOf,
    GuardOf,
    ParamTypeOf,
    ParamDefaultOf,
    UnionMemberOf,
    BoundOf,
    ConstraintOf,
    OverloadOf,
    EnumClassOf,
    ValueTypeOf,
    MemberInfoOf,
    DeclScopeOf
}

def:pub qo_Role(n: UniNode) -> list[UniNode] {
    return [n ->:Role:->];
}

def:pub qi_Role(n: UniNode) -> list[UniNode] {
    return [n <-:Role:<-];
}

def:pub qo_Kid(n: UniNode) -> list[UniNode] {
    return [n ->:Kid:->];
}

def:pub qi_Kid(n: UniNode) -> list[UniNode] {
    return [n <-:Kid:<-];
}

def:pub qo_ImplOf(n: UniNode) -> list[UniNode] {
    return [n ->:ImplOf:->];
}

def:pub qi_ImplOf(n: UniNode) -> list[UniNode] {
    return [n <-:ImplOf:<-];
}

def:pub qo_AccessRole(n: UniNode) -> list[UniNode] {
    return [n ->:AccessRole:->];
}

def:pub qi_AccessRole(n: UniNode) -> list[UniNode] {
    return [n <-:AccessRole:<-];
}

def:pub qo_AccessorsRole(n: UniNode) -> list[UniNode] {
    return [n ->:AccessorsRole:->];
}

def:pub qi_AccessorsRole(n: UniNode) -> list[UniNode] {
    return [n <-:AccessorsRole:<-];
}

def:pub qo_AliasRole(n: UniNode) -> list[UniNode] {
    return [n ->:AliasRole:->];
}

def:pub qi_AliasRole(n: UniNode) -> list[UniNode] {
    return [n <-:AliasRole:<-];
}

def:pub qo_ArchTagInfoRole(n: UniNode) -> list[UniNode] {
    return [n ->:ArchTagInfoRole:->];
}

def:pub qi_ArchTagInfoRole(n: UniNode) -> list[UniNode] {
    return [n <-:ArchTagInfoRole:<-];
}

def:pub qo_ArchTypeRole(n: UniNode) -> list[UniNode] {
    return [n ->:ArchTypeRole:->];
}

def:pub qi_ArchTypeRole(n: UniNode) -> list[UniNode] {
    return [n <-:ArchTypeRole:<-];
}

def:pub qo_ArgPatternsRole(n: UniNode) -> list[UniNode] {
    return [n ->:ArgPatternsRole:->];
}

def:pub qi_ArgPatternsRole(n: UniNode) -> list[UniNode] {
    return [n <-:ArgPatternsRole:<-];
}

def:pub qo_AssignmentsRole(n: UniNode) -> list[UniNode] {
    return [n ->:AssignmentsRole:->];
}

def:pub qi_AssignmentsRole(n: UniNode) -> list[UniNode] {
    return [n <-:AssignmentsRole:<-];
}

def:pub qo_AssignsRole(n: UniNode) -> list[UniNode] {
    return [n ->:AssignsRole:->];
}

def:pub qi_AssignsRole(n: UniNode) -> list[UniNode] {
    return [n <-:AssignsRole:<-];
}

def:pub qo_AttributesRole(n: UniNode) -> list[UniNode] {
    return [n ->:AttributesRole:->];
}

def:pub qi_AttributesRole(n: UniNode) -> list[UniNode] {
    return [n <-:AttributesRole:<-];
}

def:pub qo_AugOpRole(n: UniNode) -> list[UniNode] {
    return [n ->:AugOpRole:->];
}

def:pub qi_AugOpRole(n: UniNode) -> list[UniNode] {
    return [n <-:AugOpRole:<-];
}

def:pub qo_AwaitingBodyRole(n: UniNode) -> list[UniNode] {
    return [n ->:AwaitingBodyRole:->];
}

def:pub qi_AwaitingBodyRole(n: UniNode) -> list[UniNode] {
    return [n <-:AwaitingBodyRole:<-];
}

def:pub qo_BaseClassesRole(n: UniNode) -> list[UniNode] {
    return [n ->:BaseClassesRole:->];
}

def:pub qi_BaseClassesRole(n: UniNode) -> list[UniNode] {
    return [n <-:BaseClassesRole:<-];
}

def:pub qo_BodyRole(n: UniNode) -> list[UniNode] {
    return [n ->:BodyRole:->];
}

def:pub qi_BodyRole(n: UniNode) -> list[UniNode] {
    return [n <-:BodyRole:<-];
}

def:pub qo_BoundRole(n: UniNode) -> list[UniNode] {
    return [n ->:BoundRole:->];
}

def:pub qi_BoundRole(n: UniNode) -> list[UniNode] {
    return [n <-:BoundRole:<-];
}

def:pub qo_CasesRole(n: UniNode) -> list[UniNode] {
    return [n ->:CasesRole:->];
}

def:pub qi_CasesRole(n: UniNode) -> list[UniNode] {
    return [n <-:CasesRole:<-];
}

def:pub qo_CastTypeRole(n: UniNode) -> list[UniNode] {
    return [n ->:CastTypeRole:->];
}

def:pub qi_CastTypeRole(n: UniNode) -> list[UniNode] {
    return [n <-:CastTypeRole:<-];
}

def:pub qo_CauseRole(n: UniNode) -> list[UniNode] {
    return [n ->:CauseRole:->];
}

def:pub qi_CauseRole(n: UniNode) -> list[UniNode] {
    return [n <-:CauseRole:<-];
}

def:pub qo_ChainRole(n: UniNode) -> list[UniNode] {
    return [n ->:ChainRole:->];
}

def:pub qi_ChainRole(n: UniNode) -> list[UniNode] {
    return [n <-:ChainRole:<-];
}

def:pub qo_ChildrenRole(n: UniNode) -> list[UniNode] {
    return [n ->:ChildrenRole:->];
}

def:pub qi_ChildrenRole(n: UniNode) -> list[UniNode] {
    return [n <-:ChildrenRole:<-];
}

def:pub qo_ClibDeclsRole(n: UniNode) -> list[UniNode] {
    return [n ->:ClibDeclsRole:->];
}

def:pub qi_ClibDeclsRole(n: UniNode) -> list[UniNode] {
    return [n <-:ClibDeclsRole:<-];
}

def:pub qo_CodeRole(n: UniNode) -> list[UniNode] {
    return [n ->:CodeRole:->];
}

def:pub qi_CodeRole(n: UniNode) -> list[UniNode] {
    return [n <-:CodeRole:<-];
}

def:pub qo_CollectionRole(n: UniNode) -> list[UniNode] {
    return [n ->:CollectionRole:->];
}

def:pub qi_CollectionRole(n: UniNode) -> list[UniNode] {
    return [n <-:CollectionRole:<-];
}

def:pub qo_ComparesRole(n: UniNode) -> list[UniNode] {
    return [n ->:ComparesRole:->];
}

def:pub qi_ComparesRole(n: UniNode) -> list[UniNode] {
    return [n <-:ComparesRole:<-];
}

def:pub qo_ComprRole(n: UniNode) -> list[UniNode] {
    return [n ->:ComprRole:->];
}

def:pub qi_ComprRole(n: UniNode) -> list[UniNode] {
    return [n <-:ComprRole:<-];
}

def:pub qo_ConditionRole(n: UniNode) -> list[UniNode] {
    return [n ->:ConditionRole:->];
}

def:pub qi_ConditionRole(n: UniNode) -> list[UniNode] {
    return [n <-:ConditionRole:<-];
}

def:pub qo_ConditionalRole(n: UniNode) -> list[UniNode] {
    return [n ->:ConditionalRole:->];
}

def:pub qi_ConditionalRole(n: UniNode) -> list[UniNode] {
    return [n <-:ConditionalRole:<-];
}

def:pub qo_ConnAssignRole(n: UniNode) -> list[UniNode] {
    return [n ->:ConnAssignRole:->];
}

def:pub qi_ConnAssignRole(n: UniNode) -> list[UniNode] {
    return [n <-:ConnAssignRole:<-];
}

def:pub qo_ConnTypeRole(n: UniNode) -> list[UniNode] {
    return [n ->:ConnTypeRole:->];
}

def:pub qi_ConnTypeRole(n: UniNode) -> list[UniNode] {
    return [n <-:ConnTypeRole:<-];
}

def:pub qo_CountByRole(n: UniNode) -> list[UniNode] {
    return [n ->:CountByRole:->];
}

def:pub qi_CountByRole(n: UniNode) -> list[UniNode] {
    return [n <-:CountByRole:<-];
}

def:pub qo_CtrlRole(n: UniNode) -> list[UniNode] {
    return [n ->:CtrlRole:->];
}

def:pub qi_CtrlRole(n: UniNode) -> list[UniNode] {
    return [n <-:CtrlRole:<-];
}

def:pub qo_DecoratorsRole(n: UniNode) -> list[UniNode] {
    return [n ->:DecoratorsRole:->];
}

def:pub qi_DecoratorsRole(n: UniNode) -> list[UniNode] {
    return [n <-:DecoratorsRole:<-];
}

def:pub qo_DefaultValRole(n: UniNode) -> list[UniNode] {
    return [n ->:DefaultValRole:->];
}

def:pub qi_DefaultValRole(n: UniNode) -> list[UniNode] {
    return [n <-:DefaultValRole:<-];
}

def:pub qo_DescriptionRole(n: UniNode) -> list[UniNode] {
    return [n ->:DescriptionRole:->];
}

def:pub qi_DescriptionRole(n: UniNode) -> list[UniNode] {
    return [n <-:DescriptionRole:<-];
}

def:pub qo_DocRole(n: UniNode) -> list[UniNode] {
    return [n ->:DocRole:->];
}

def:pub qi_DocRole(n: UniNode) -> list[UniNode] {
    return [n <-:DocRole:<-];
}

def:pub qo_DynamicTagRole(n: UniNode) -> list[UniNode] {
    return [n ->:DynamicTagRole:->];
}

def:pub qi_DynamicTagRole(n: UniNode) -> list[UniNode] {
    return [n <-:DynamicTagRole:<-];
}

def:pub qo_EdgeSpecRole(n: UniNode) -> list[UniNode] {
    return [n ->:EdgeSpecRole:->];
}

def:pub qi_EdgeSpecRole(n: UniNode) -> list[UniNode] {
    return [n <-:EdgeSpecRole:<-];
}

def:pub qo_ElseBodyRole(n: UniNode) -> list[UniNode] {
    return [n ->:ElseBodyRole:->];
}

def:pub qi_ElseBodyRole(n: UniNode) -> list[UniNode] {
    return [n <-:ElseBodyRole:<-];
}

def:pub qo_ElseValueRole(n: UniNode) -> list[UniNode] {
    return [n ->:ElseValueRole:->];
}

def:pub qi_ElseValueRole(n: UniNode) -> list[UniNode] {
    return [n <-:ElseValueRole:<-];
}

def:pub qo_EndRole(n: UniNode) -> list[UniNode] {
    return [n ->:EndRole:->];
}

def:pub qi_EndRole(n: UniNode) -> list[UniNode] {
    return [n <-:EndRole:<-];
}

def:pub qo_ErrorMsgRole(n: UniNode) -> list[UniNode] {
    return [n ->:ErrorMsgRole:->];
}

def:pub qi_ErrorMsgRole(n: UniNode) -> list[UniNode] {
    return [n <-:ErrorMsgRole:<-];
}

def:pub qo_EventRole(n: UniNode) -> list[UniNode] {
    return [n ->:EventRole:->];
}

def:pub qi_EventRole(n: UniNode) -> list[UniNode] {
    return [n <-:EventRole:<-];
}

def:pub qo_ExTypeRole(n: UniNode) -> list[UniNode] {
    return [n ->:ExTypeRole:->];
}

def:pub qi_ExTypeRole(n: UniNode) -> list[UniNode] {
    return [n <-:ExTypeRole:<-];
}

def:pub qo_ExceptsRole(n: UniNode) -> list[UniNode] {
    return [n ->:ExceptsRole:->];
}

def:pub qi_ExceptsRole(n: UniNode) -> list[UniNode] {
    return [n <-:ExceptsRole:<-];
}

def:pub qo_ExprRole(n: UniNode) -> list[UniNode] {
    return [n ->:ExprRole:->];
}

def:pub qi_ExprRole(n: UniNode) -> list[UniNode] {
    return [n <-:ExprRole:<-];
}

def:pub qo_ExprsRole(n: UniNode) -> list[UniNode] {
    return [n ->:ExprsRole:->];
}

def:pub qi_ExprsRole(n: UniNode) -> list[UniNode] {
    return [n <-:ExprsRole:<-];
}

def:pub qo_FTypeRole(n: UniNode) -> list[UniNode] {
    return [n ->:FTypeRole:->];
}

def:pub qi_FTypeRole(n: UniNode) -> list[UniNode] {
    return [n <-:FTypeRole:<-];
}

def:pub qo_FilterCondRole(n: UniNode) -> list[UniNode] {
    return [n ->:FilterCondRole:->];
}

def:pub qi_FilterCondRole(n: UniNode) -> list[UniNode] {
    return [n <-:FilterCondRole:<-];
}

def:pub qo_FinallyBodyRole(n: UniNode) -> list[UniNode] {
    return [n ->:FinallyBodyRole:->];
}

def:pub qi_FinallyBodyRole(n: UniNode) -> list[UniNode] {
    return [n <-:FinallyBodyRole:<-];
}

def:pub qo_FormatPartRole(n: UniNode) -> list[UniNode] {
    return [n ->:FormatPartRole:->];
}

def:pub qi_FormatPartRole(n: UniNode) -> list[UniNode] {
    return [n <-:FormatPartRole:<-];
}

def:pub qo_FormatSpecRole(n: UniNode) -> list[UniNode] {
    return [n ->:FormatSpecRole:->];
}

def:pub qi_FormatSpecRole(n: UniNode) -> list[UniNode] {
    return [n <-:FormatSpecRole:<-];
}

def:pub qo_FromLocRole(n: UniNode) -> list[UniNode] {
    return [n ->:FromLocRole:->];
}

def:pub qi_FromLocRole(n: UniNode) -> list[UniNode] {
    return [n <-:FromLocRole:<-];
}

def:pub qo_FromTargetRole(n: UniNode) -> list[UniNode] {
    return [n ->:FromTargetRole:->];
}

def:pub qi_FromTargetRole(n: UniNode) -> list[UniNode] {
    return [n <-:FromTargetRole:<-];
}

def:pub qo_GuardRole(n: UniNode) -> list[UniNode] {
    return [n ->:GuardRole:->];
}

def:pub qi_GuardRole(n: UniNode) -> list[UniNode] {
    return [n <-:GuardRole:<-];
}

def:pub qo_HintRole(n: UniNode) -> list[UniNode] {
    return [n ->:HintRole:->];
}

def:pub qi_HintRole(n: UniNode) -> list[UniNode] {
    return [n <-:HintRole:<-];
}

def:pub qo_InsertLocRole(n: UniNode) -> list[UniNode] {
    return [n ->:InsertLocRole:->];
}

def:pub qi_InsertLocRole(n: UniNode) -> list[UniNode] {
    return [n <-:InsertLocRole:<-];
}

def:pub qo_ItemsRole(n: UniNode) -> list[UniNode] {
    return [n ->:ItemsRole:->];
}

def:pub qi_ItemsRole(n: UniNode) -> list[UniNode] {
    return [n <-:ItemsRole:<-];
}

def:pub qo_IterRole(n: UniNode) -> list[UniNode] {
    return [n ->:IterRole:->];
}

def:pub qi_IterRole(n: UniNode) -> list[UniNode] {
    return [n <-:IterRole:<-];
}

def:pub qo_KeyRole(n: UniNode) -> list[UniNode] {
    return [n ->:KeyRole:->];
}

def:pub qi_KeyRole(n: UniNode) -> list[UniNode] {
    return [n <-:KeyRole:<-];
}

def:pub qo_KeywordsRole(n: UniNode) -> list[UniNode] {
    return [n ->:KeywordsRole:->];
}

def:pub qi_KeywordsRole(n: UniNode) -> list[UniNode] {
    return [n <-:KeywordsRole:<-];
}

def:pub qo_KvPairRole(n: UniNode) -> list[UniNode] {
    return [n ->:KvPairRole:->];
}

def:pub qi_KvPairRole(n: UniNode) -> list[UniNode] {
    return [n <-:KvPairRole:<-];
}

def:pub qo_KvPairsRole(n: UniNode) -> list[UniNode] {
    return [n ->:KvPairsRole:->];
}

def:pub qi_KvPairsRole(n: UniNode) -> list[UniNode] {
    return [n <-:KvPairsRole:<-];
}

def:pub qo_KwPatternsRole(n: UniNode) -> list[UniNode] {
    return [n ->:KwPatternsRole:->];
}

def:pub qi_KwPatternsRole(n: UniNode) -> list[UniNode] {
    return [n <-:KwPatternsRole:<-];
}

def:pub qo_KwargsRole(n: UniNode) -> list[UniNode] {
    return [n ->:KwargsRole:->];
}

def:pub qi_KwargsRole(n: UniNode) -> list[UniNode] {
    return [n <-:KwargsRole:<-];
}

def:pub qo_KwonlyargsRole(n: UniNode) -> list[UniNode] {
    return [n ->:KwonlyargsRole:->];
}

def:pub qi_KwonlyargsRole(n: UniNode) -> list[UniNode] {
    return [n <-:KwonlyargsRole:<-];
}

def:pub qo_LeftRole(n: UniNode) -> list[UniNode] {
    return [n ->:LeftRole:->];
}

def:pub qi_LeftRole(n: UniNode) -> list[UniNode] {
    return [n <-:LeftRole:<-];
}

def:pub qo_MainRole(n: UniNode) -> list[UniNode] {
    return [n ->:MainRole:->];
}

def:pub qi_MainRole(n: UniNode) -> list[UniNode] {
    return [n <-:MainRole:<-];
}

def:pub qo_NameRole(n: UniNode) -> list[UniNode] {
    return [n ->:NameRole:->];
}

def:pub qi_NameRole(n: UniNode) -> list[UniNode] {
    return [n <-:NameRole:<-];
}

def:pub qo_NameRefRole(n: UniNode) -> list[UniNode] {
    return [n ->:NameRefRole:->];
}

def:pub qi_NameRefRole(n: UniNode) -> list[UniNode] {
    return [n <-:NameRefRole:<-];
}

def:pub qo_OpRole(n: UniNode) -> list[UniNode] {
    return [n ->:OpRole:->];
}

def:pub qi_OpRole(n: UniNode) -> list[UniNode] {
    return [n <-:OpRole:<-];
}

def:pub qo_OperandRole(n: UniNode) -> list[UniNode] {
    return [n ->:OperandRole:->];
}

def:pub qi_OperandRole(n: UniNode) -> list[UniNode] {
    return [n <-:OperandRole:<-];
}

def:pub qo_OpsRole(n: UniNode) -> list[UniNode] {
    return [n ->:OpsRole:->];
}

def:pub qi_OpsRole(n: UniNode) -> list[UniNode] {
    return [n <-:OpsRole:<-];
}

def:pub qo_OutExprRole(n: UniNode) -> list[UniNode] {
    return [n ->:OutExprRole:->];
}

def:pub qi_OutExprRole(n: UniNode) -> list[UniNode] {
    return [n <-:OutExprRole:<-];
}

def:pub qo_ParamsRole(n: UniNode) -> list[UniNode] {
    return [n ->:ParamsRole:->];
}

def:pub qi_ParamsRole(n: UniNode) -> list[UniNode] {
    return [n <-:ParamsRole:<-];
}

def:pub qo_PartsRole(n: UniNode) -> list[UniNode] {
    return [n ->:PartsRole:->];
}

def:pub qi_PartsRole(n: UniNode) -> list[UniNode] {
    return [n <-:PartsRole:<-];
}

def:pub qo_PathRole(n: UniNode) -> list[UniNode] {
    return [n ->:PathRole:->];
}

def:pub qi_PathRole(n: UniNode) -> list[UniNode] {
    return [n <-:PathRole:<-];
}

def:pub qo_PatternRole(n: UniNode) -> list[UniNode] {
    return [n ->:PatternRole:->];
}

def:pub qi_PatternRole(n: UniNode) -> list[UniNode] {
    return [n <-:PatternRole:<-];
}

def:pub qo_PatternsRole(n: UniNode) -> list[UniNode] {
    return [n ->:PatternsRole:->];
}

def:pub qi_PatternsRole(n: UniNode) -> list[UniNode] {
    return [n <-:PatternsRole:<-];
}

def:pub qo_PosonlyParamsRole(n: UniNode) -> list[UniNode] {
    return [n ->:PosonlyParamsRole:->];
}

def:pub qi_PosonlyParamsRole(n: UniNode) -> list[UniNode] {
    return [n <-:PosonlyParamsRole:<-];
}

def:pub qo_ReturnTypeRole(n: UniNode) -> list[UniNode] {
    return [n ->:ReturnTypeRole:->];
}

def:pub qi_ReturnTypeRole(n: UniNode) -> list[UniNode] {
    return [n <-:ReturnTypeRole:<-];
}

def:pub qo_RightRole(n: UniNode) -> list[UniNode] {
    return [n ->:RightRole:->];
}

def:pub qi_RightRole(n: UniNode) -> list[UniNode] {
    return [n <-:RightRole:<-];
}

def:pub qo_RightsRole(n: UniNode) -> list[UniNode] {
    return [n ->:RightsRole:->];
}

def:pub qi_RightsRole(n: UniNode) -> list[UniNode] {
    return [n <-:RightsRole:<-];
}

def:pub qo_SignatureRole(n: UniNode) -> list[UniNode] {
    return [n ->:SignatureRole:->];
}

def:pub qi_SignatureRole(n: UniNode) -> list[UniNode] {
    return [n <-:SignatureRole:<-];
}

def:pub qo_SlicesRole(n: UniNode) -> list[UniNode] {
    return [n ->:SlicesRole:->];
}

def:pub qi_SlicesRole(n: UniNode) -> list[UniNode] {
    return [n <-:SlicesRole:<-];
}

def:pub qo_SpecRole(n: UniNode) -> list[UniNode] {
    return [n ->:SpecRole:->];
}

def:pub qi_SpecRole(n: UniNode) -> list[UniNode] {
    return [n <-:SpecRole:<-];
}

def:pub qo_SrcEndpointRole(n: UniNode) -> list[UniNode] {
    return [n ->:SrcEndpointRole:->];
}

def:pub qi_SrcEndpointRole(n: UniNode) -> list[UniNode] {
    return [n <-:SrcEndpointRole:<-];
}

def:pub qo_StartRole(n: UniNode) -> list[UniNode] {
    return [n ->:StartRole:->];
}

def:pub qi_StartRole(n: UniNode) -> list[UniNode] {
    return [n <-:StartRole:<-];
}

def:pub qo_StepRole(n: UniNode) -> list[UniNode] {
    return [n ->:StepRole:->];
}

def:pub qi_StepRole(n: UniNode) -> list[UniNode] {
    return [n <-:StepRole:<-];
}

def:pub qo_StopRole(n: UniNode) -> list[UniNode] {
    return [n ->:StopRole:->];
}

def:pub qi_StopRole(n: UniNode) -> list[UniNode] {
    return [n <-:StopRole:<-];
}

def:pub qo_StringsRole(n: UniNode) -> list[UniNode] {
    return [n ->:StringsRole:->];
}

def:pub qi_StringsRole(n: UniNode) -> list[UniNode] {
    return [n <-:StringsRole:<-];
}

def:pub qo_TargetRole(n: UniNode) -> list[UniNode] {
    return [n ->:TargetRole:->];
}

def:pub qi_TargetRole(n: UniNode) -> list[UniNode] {
    return [n <-:TargetRole:<-];
}

def:pub qo_TgtEndpointRole(n: UniNode) -> list[UniNode] {
    return [n ->:TgtEndpointRole:->];
}

def:pub qi_TgtEndpointRole(n: UniNode) -> list[UniNode] {
    return [n <-:TgtEndpointRole:<-];
}

def:pub qo_TokRole(n: UniNode) -> list[UniNode] {
    return [n ->:TokRole:->];
}

def:pub qi_TokRole(n: UniNode) -> list[UniNode] {
    return [n <-:TokRole:<-];
}

def:pub qo_TypeCtxRole(n: UniNode) -> list[UniNode] {
    return [n ->:TypeCtxRole:->];
}

def:pub qi_TypeCtxRole(n: UniNode) -> list[UniNode] {
    return [n <-:TypeCtxRole:<-];
}

def:pub qo_TypeParamsRole(n: UniNode) -> list[UniNode] {
    return [n ->:TypeParamsRole:->];
}

def:pub qi_TypeParamsRole(n: UniNode) -> list[UniNode] {
    return [n <-:TypeParamsRole:<-];
}

def:pub qo_TypeTagRole(n: UniNode) -> list[UniNode] {
    return [n ->:TypeTagRole:->];
}

def:pub qi_TypeTagRole(n: UniNode) -> list[UniNode] {
    return [n <-:TypeTagRole:<-];
}

def:pub qo_UnpackRole(n: UniNode) -> list[UniNode] {
    return [n ->:UnpackRole:->];
}

def:pub qi_UnpackRole(n: UniNode) -> list[UniNode] {
    return [n <-:UnpackRole:<-];
}

def:pub qo_ValueRole(n: UniNode) -> list[UniNode] {
    return [n ->:ValueRole:->];
}

def:pub qi_ValueRole(n: UniNode) -> list[UniNode] {
    return [n <-:ValueRole:<-];
}

def:pub qo_ValueTypeRole(n: UniNode) -> list[UniNode] {
    return [n ->:ValueTypeRole:->];
}

def:pub qi_ValueTypeRole(n: UniNode) -> list[UniNode] {
    return [n <-:ValueTypeRole:<-];
}

def:pub qo_ValuesRole(n: UniNode) -> list[UniNode] {
    return [n ->:ValuesRole:->];
}

def:pub qi_ValuesRole(n: UniNode) -> list[UniNode] {
    return [n <-:ValuesRole:<-];
}

def:pub qo_VarargsRole(n: UniNode) -> list[UniNode] {
    return [n ->:VarargsRole:->];
}

def:pub qi_VarargsRole(n: UniNode) -> list[UniNode] {
    return [n <-:VarargsRole:<-];
}

def:pub qo_VarsRole(n: UniNode) -> list[UniNode] {
    return [n ->:VarsRole:->];
}

def:pub qi_VarsRole(n: UniNode) -> list[UniNode] {
    return [n <-:VarsRole:<-];
}

def:pub qo_SymOf(n: UniNode) -> list[UniNode] {
    return [n ->:SymOf:->];
}

def:pub qi_SymOf(n: UniNode) -> list[UniNode] {
    return [n <-:SymOf:<-];
}

def:pub qo_Defines(n: UniNode) -> list[UniNode] {
    return [n ->:Defines:->];
}

def:pub qi_Defines(n: UniNode) -> list[UniNode] {
    return [n <-:Defines:<-];
}

def:pub qo_Uses(n: UniNode) -> list[UniNode] {
    return [n ->:Uses:->];
}

def:pub qi_Uses(n: UniNode) -> list[UniNode] {
    return [n <-:Uses:<-];
}

def:pub qo_InScope(n: UniNode) -> list[UniNode] {
    return [n ->:InScope:->];
}

def:pub qi_InScope(n: UniNode) -> list[UniNode] {
    return [n <-:InScope:<-];
}

def:pub qo_ScopePrimary(n: UniNode) -> list[UniNode] {
    return [n ->:ScopePrimary:->];
}

def:pub qi_ScopePrimary(n: UniNode) -> list[UniNode] {
    return [n <-:ScopePrimary:<-];
}

def:pub qo_ScopeOverload(n: UniNode) -> list[UniNode] {
    return [n ->:ScopeOverload:->];
}

def:pub qi_ScopeOverload(n: UniNode) -> list[UniNode] {
    return [n <-:ScopeOverload:<-];
}

def:pub qo_ScopeChild(n: UniNode) -> list[UniNode] {
    return [n ->:ScopeChild:->];
}

def:pub qi_ScopeChild(n: UniNode) -> list[UniNode] {
    return [n <-:ScopeChild:<-];
}

def:pub qo_ScopeParent(n: UniNode) -> list[UniNode] {
    return [n ->:ScopeParent:->];
}

def:pub qi_ScopeParent(n: UniNode) -> list[UniNode] {
    return [n <-:ScopeParent:<-];
}

def:pub qo_CfgSucc(n: UniNode) -> list[UniNode] {
    return [n ->:CfgSucc:->];
}

def:pub qi_CfgSucc(n: UniNode) -> list[UniNode] {
    return [n <-:CfgSucc:<-];
}

def:pub qo_CfgTrue(n: UniNode) -> list[UniNode] {
    return [n ->:CfgTrue:->];
}

def:pub qi_CfgTrue(n: UniNode) -> list[UniNode] {
    return [n <-:CfgTrue:<-];
}

def:pub qo_CfgFalse(n: UniNode) -> list[UniNode] {
    return [n ->:CfgFalse:->];
}

def:pub qi_CfgFalse(n: UniNode) -> list[UniNode] {
    return [n <-:CfgFalse:<-];
}

def:pub qo_PlacedIn(n: UniNode) -> list[UniNode] {
    return [n ->:PlacedIn:->];
}

def:pub qi_PlacedIn(n: UniNode) -> list[UniNode] {
    return [n <-:PlacedIn:<-];
}

def:pub qo_DecidedCodespace(n: UniNode) -> list[UniNode] {
    return [n ->:DecidedCodespace:->];
}

def:pub qi_DecidedCodespace(n: UniNode) -> list[UniNode] {
    return [n <-:DecidedCodespace:<-];
}

def:pub qo_CalleeDecl(n: UniNode) -> list[UniNode] {
    return [n ->:CalleeDecl:->];
}

def:pub qi_CalleeDecl(n: UniNode) -> list[UniNode] {
    return [n <-:CalleeDecl:<-];
}

def:pub qo_Absorbs(n: UniNode) -> list[UniNode] {
    return [n ->:Absorbs:->];
}

def:pub qi_Absorbs(n: UniNode) -> list[UniNode] {
    return [n <-:Absorbs:<-];
}

def:pub qo_AttachedComment(n: UniNode) -> list[UniNode] {
    return [n ->:AttachedComment:->];
}

def:pub qi_AttachedComment(n: UniNode) -> list[UniNode] {
    return [n <-:AttachedComment:<-];
}

def:pub qo_TypeParamOf(n: UniNode) -> list[UniNode] {
    return [n ->:TypeParamOf:->];
}

def:pub qi_TypeParamOf(n: UniNode) -> list[UniNode] {
    return [n <-:TypeParamOf:<-];
}

def:pub qo_TypeArgOf(n: UniNode) -> list[UniNode] {
    return [n ->:TypeArgOf:->];
}

def:pub qi_TypeArgOf(n: UniNode) -> list[UniNode] {
    return [n <-:TypeArgOf:<-];
}

def:pub qo_ParamOf(n: UniNode) -> list[UniNode] {
    return [n ->:ParamOf:->];
}

def:pub qi_ParamOf(n: UniNode) -> list[UniNode] {
    return [n <-:ParamOf:<-];
}

def:pub qo_ReturnsOf(n: UniNode) -> list[UniNode] {
    return [n ->:ReturnsOf:->];
}

def:pub qi_ReturnsOf(n: UniNode) -> list[UniNode] {
    return [n <-:ReturnsOf:<-];
}

def:pub qo_GuardOf(n: UniNode) -> list[UniNode] {
    return [n ->:GuardOf:->];
}

def:pub qi_GuardOf(n: UniNode) -> list[UniNode] {
    return [n <-:GuardOf:<-];
}

def:pub qo_ParamTypeOf(n: UniNode) -> list[UniNode] {
    return [n ->:ParamTypeOf:->];
}

def:pub qi_ParamTypeOf(n: UniNode) -> list[UniNode] {
    return [n <-:ParamTypeOf:<-];
}

def:pub qo_ParamDefaultOf(n: UniNode) -> list[UniNode] {
    return [n ->:ParamDefaultOf:->];
}

def:pub qi_ParamDefaultOf(n: UniNode) -> list[UniNode] {
    return [n <-:ParamDefaultOf:<-];
}

def:pub qo_UnionMemberOf(n: UniNode) -> list[UniNode] {
    return [n ->:UnionMemberOf:->];
}

def:pub qi_UnionMemberOf(n: UniNode) -> list[UniNode] {
    return [n <-:UnionMemberOf:<-];
}

def:pub qo_BoundOf(n: UniNode) -> list[UniNode] {
    return [n ->:BoundOf:->];
}

def:pub qi_BoundOf(n: UniNode) -> list[UniNode] {
    return [n <-:BoundOf:<-];
}

def:pub qo_ConstraintOf(n: UniNode) -> list[UniNode] {
    return [n ->:ConstraintOf:->];
}

def:pub qi_ConstraintOf(n: UniNode) -> list[UniNode] {
    return [n <-:ConstraintOf:<-];
}

def:pub qo_OverloadOf(n: UniNode) -> list[UniNode] {
    return [n ->:OverloadOf:->];
}

def:pub qi_OverloadOf(n: UniNode) -> list[UniNode] {
    return [n <-:OverloadOf:<-];
}

def:pub qo_EnumClassOf(n: UniNode) -> list[UniNode] {
    return [n ->:EnumClassOf:->];
}

def:pub qi_EnumClassOf(n: UniNode) -> list[UniNode] {
    return [n <-:EnumClassOf:<-];
}

def:pub qo_ValueTypeOf(n: UniNode) -> list[UniNode] {
    return [n ->:ValueTypeOf:->];
}

def:pub qi_ValueTypeOf(n: UniNode) -> list[UniNode] {
    return [n <-:ValueTypeOf:<-];
}

def:pub qo_MemberInfoOf(n: UniNode) -> list[UniNode] {
    return [n ->:MemberInfoOf:->];
}

def:pub qi_MemberInfoOf(n: UniNode) -> list[UniNode] {
    return [n <-:MemberInfoOf:<-];
}

def:pub qo_DeclScopeOf(n: UniNode) -> list[UniNode] {
    return [n ->:DeclScopeOf:->];
}

def:pub qi_DeclScopeOf(n: UniNode) -> list[UniNode] {
    return [n <-:DeclScopeOf:<-];
}
