import from jaclang.jac0core.parser.parser { parse_program }
import from jaclang.jac0core.unitree {
    Ability,
    ArchBlockStmt,
    ArchHas,
    ArchSpec,
    Archetype,
    AssertStmt,
    AssignCompr,
    Assignment,
    AstAccessNode,
    AstAsyncNode,
    AstDocNode,
    AstElseBodyNode,
    AstImplNeedingNode,
    AstSymbolNode,
    AstSymbolStubNode,
    AstTypedVarNode,
    AtomExpr,
    AtomTrailer,
    AtomUnit,
    AwaitExpr,
    AwaitingClause,
    BinaryExpr,
    Bool,
    BoolExpr,
    BuiltinType,
    CastExpr,
    CfgExpr,
    CodeBlockStmt,
    CommentToken,
    CompareExpr,
    ConcurrentExpr,
    ConditionalNode,
    ConnectOp,
    ContextAwareNode,
    CtBlock,
    CtElse,
    CtFor,
    CtIf,
    CtName,
    CtSplice,
    CtrlStmt,
    DeleteStmt,
    DictCompr,
    DictVal,
    DisconnectOp,
    DisengageStmt,
    EdgeOpRef,
    EdgeRefTrailer,
    ElementStmt,
    Ellipsis,
    ElseIf,
    ElseStmt,
    EmptyToken,
    Enum,
    EnumBlockStmt,
    EventSignature,
    Except,
    Expr,
    ExprAsItem,
    ExprStmt,
    FString,
    FilterCompr,
    FinallyStmt,
    Float,
    ForeverStmt,
    FormattedValue,
    FuncCall,
    FuncSignature,
    GenCompr,
    GlobalVars,
    HasVar,
    IfElseExpr,
    IfStmt,
    ImplDef,
    Import,
    InForStmt,
    IndexSlice,
    InheritedSymbolTable,
    InnerCompr,
    Int,
    IterForStmt,
    JsxAttribute,
    JsxChild,
    JsxComment,
    JsxElement,
    JsxElementName,
    JsxExpression,
    JsxNormalAttribute,
    JsxSlot,
    JsxSpreadAttribute,
    JsxText,
    KVPair,
    KWPair,
    LambdaExpr,
    ListCompr,
    ListVal,
    Literal,
    MatchArch,
    MatchAs,
    MatchCase,
    MatchKVPair,
    MatchMapping,
    MatchOr,
    MatchPattern,
    MatchSequence,
    MatchSingleton,
    MatchStar,
    MatchStmt,
    MatchValue,
    MatchWild,
    Module,
    ModuleCode,
    ModuleItem,
    ModulePath,
    MultiString,
    Name,
    NameAtom,
    Null,
    OpenStmt,
    ParamVar,
    ProgramModule,
    PyInlineCode,
    PythonModuleAst,
    RaiseStmt,
    ReportStmt,
    ReturnStmt,
    SemDef,
    Semi,
    SetCompr,
    SetVal,
    Slice,
    Source,
    SpecialVarRef,
    String,
    SubTag,
    SwitchCase,
    SwitchStmt,
    Symbol,
    Test,
    Token,
    TryStmt,
    TupleVal,
    TypeAlias,
    TypeParam,
    TypedCtxBlock,
    UnaryExpr,
    UniCFGNode,
    UniNode,
    UniScopeNode,
    VisitStmt,
    WalkerStmtOnlyNode,
    WhileStmt,
    WithStmt,
    YieldExpr
}
import from jaclang.jac0core.constant {
    CodeContext,
    EdgeDir,
    ExprCtx,
    OwnershipKind,
    ParamKind,
    SymbolAccess,
    SymbolType
}
import from jaclang.jac0core.srcloc { CodeLocInfo }

import from python {
    def PyLong_FromLongLong(v: int) -> int;  def PyBool_FromLong(v: int) -> int;  def PyFloat_FromDouble(
        v: float
    ) -> int;  def PyUnicode_FromStringAndSize(s: str, n: int) -> int;  def PyList_New(
        n: int
    ) -> int;  def PyList_SetItem(l: int, i: int, v: int) -> i32;  def PyDict_New -> int;  def PyDict_SetItem(
        d: int, k: int, v: int
    ) -> i32;  def PySet_New(i: int) -> int;  def PySet_Add(s: int, v: int) -> i32;  def PyObject_CallOneArg(
        f: int, a: int
    ) -> int;  def PyObject_GenericGetDict(o: int, ctx: int) -> int;  def Py_IncRef(
        o: int
    ) -> None;  def Py_DecRef(o: int) -> None;  def Py_GetConstant(cid: int) -> int;
}

glob _mat_classes: list[int] = [],
     _mat_news: list[int] = [],
     _mat_keys: list[int] = [],
     _mat_enums: list[int] = [],
     _mat_memo: dict[int, int] = {};

def _py_none -> int {
    return Py_GetConstant(0);
}

def _py_str(s: str) -> int {
    return PyUnicode_FromStringAndSize(s, len(s));
}

def mat_reset(ncls: int, nkeys: int, nenums: int) {
    _mat_classes.clear();
    _mat_news.clear();
    _mat_keys.clear();
    _mat_enums.clear();
    i = 0;
    while i < ncls {
        _mat_classes.append(0);
        _mat_news.append(0);
        i += 1;
    }
    i = 0;
    while i < nkeys {
        _mat_keys.append(0);
        i += 1;
    }
    i = 0;
    while i < nenums {
        _mat_enums.append(0);
        i += 1;
    }
}

def mat_set_class(i: int, cls_h: int, new_h: int) {
    _mat_classes[i] = cls_h;
    _mat_news[i] = new_h;
}

def mat_set_key(i: int, key_h: int) {
    _mat_keys[i] = key_h;
}

def mat_set_enum(i: int, member_h: int) {
    _mat_enums[i] = member_h;
}

def mat_materialize(mod: Module) -> int {
    root_h = _emit_node(mod);
    for (_addr, h) in _mat_memo.items() {
        Py_DecRef(h);
    }
    _mat_memo.clear();
    return root_h;
}


def _enum_CodeContext(v: CodeContext) -> int {
    if v == CodeContext.SERVER {
        h = _mat_enums[0];
        Py_IncRef(h);
        return h;
    } elif v == CodeContext.CLIENT {
        h = _mat_enums[1];
        Py_IncRef(h);
        return h;
    } elif v == CodeContext.NATIVE {
        h = _mat_enums[2];
        Py_IncRef(h);
        return h;
    }
    return PyLong_FromLongLong(0);
}

def _enum_SymbolType(v: SymbolType) -> int {
    if v == SymbolType.MODULE {
        h = _mat_enums[3];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.MOD_VAR {
        h = _mat_enums[4];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.VAR {
        h = _mat_enums[5];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.IMM_VAR {
        h = _mat_enums[6];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.ABILITY {
        h = _mat_enums[7];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.OBJECT_ARCH {
        h = _mat_enums[8];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.NODE_ARCH {
        h = _mat_enums[9];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.EDGE_ARCH {
        h = _mat_enums[10];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.WALKER_ARCH {
        h = _mat_enums[11];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.ENUM_ARCH {
        h = _mat_enums[12];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.TEST {
        h = _mat_enums[13];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.TYPE {
        h = _mat_enums[14];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.IMPL {
        h = _mat_enums[15];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.SEM {
        h = _mat_enums[16];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.HAS_VAR {
        h = _mat_enums[17];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.METHOD {
        h = _mat_enums[18];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.CONSTRUCTOR {
        h = _mat_enums[19];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.ENUM_MEMBER {
        h = _mat_enums[20];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.NUMBER {
        h = _mat_enums[21];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.STRING {
        h = _mat_enums[22];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.BOOL {
        h = _mat_enums[23];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.SEQUENCE {
        h = _mat_enums[24];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.NULL {
        h = _mat_enums[25];
        Py_IncRef(h);
        return h;
    } elif v == SymbolType.UNKNOWN {
        h = _mat_enums[26];
        Py_IncRef(h);
        return h;
    }
    return PyLong_FromLongLong(0);
}

def _enum_ExprCtx(v: ExprCtx) -> int {
    if v == ExprCtx.LOAD {
        h = _mat_enums[27];
        Py_IncRef(h);
        return h;
    } elif v == ExprCtx.STORE {
        h = _mat_enums[28];
        Py_IncRef(h);
        return h;
    } elif v == ExprCtx.DEL {
        h = _mat_enums[29];
        Py_IncRef(h);
        return h;
    }
    return PyLong_FromLongLong(0);
}

def _enum_EdgeDir(v: EdgeDir) -> int {
    if v == EdgeDir.IN {
        h = _mat_enums[30];
        Py_IncRef(h);
        return h;
    } elif v == EdgeDir.OUT {
        h = _mat_enums[31];
        Py_IncRef(h);
        return h;
    } elif v == EdgeDir.ANY {
        h = _mat_enums[32];
        Py_IncRef(h);
        return h;
    }
    return PyLong_FromLongLong(0);
}

def _enum_ParamKind(v: ParamKind) -> int {
    if v == ParamKind.POSONLY {
        h = _mat_enums[33];
        Py_IncRef(h);
        return h;
    } elif v == ParamKind.NORMAL {
        h = _mat_enums[34];
        Py_IncRef(h);
        return h;
    } elif v == ParamKind.VARARG {
        h = _mat_enums[35];
        Py_IncRef(h);
        return h;
    } elif v == ParamKind.KWONLY {
        h = _mat_enums[36];
        Py_IncRef(h);
        return h;
    } elif v == ParamKind.KWARG {
        h = _mat_enums[37];
        Py_IncRef(h);
        return h;
    }
    return PyLong_FromLongLong(0);
}

def _enum_OwnershipKind(v: OwnershipKind) -> int {
    if v == OwnershipKind.NONE {
        h = _mat_enums[38];
        Py_IncRef(h);
        return h;
    } elif v == OwnershipKind.OWN {
        h = _mat_enums[39];
        Py_IncRef(h);
        return h;
    } elif v == OwnershipKind.BORROW {
        h = _mat_enums[40];
        Py_IncRef(h);
        return h;
    } elif v == OwnershipKind.MUT_BORROW {
        h = _mat_enums[41];
        Py_IncRef(h);
        return h;
    } elif v == OwnershipKind.IMM {
        h = _mat_enums[42];
        Py_IncRef(h);
        return h;
    }
    return PyLong_FromLongLong(0);
}

def _enum_SymbolAccess(v: SymbolAccess) -> int {
    if v == SymbolAccess.PRIVATE {
        h = _mat_enums[43];
        Py_IncRef(h);
        return h;
    } elif v == SymbolAccess.PUBLIC {
        h = _mat_enums[44];
        Py_IncRef(h);
        return h;
    } elif v == SymbolAccess.PROTECTED {
        h = _mat_enums[45];
        Py_IncRef(h);
        return h;
    }
    return PyLong_FromLongLong(0);
}

def _emit_Archetype(nd: Archetype) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[0], _mat_classes[0]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_0_0 = nd.kid;
    v_0_0 = PyList_New(len(fv_0_0));
    li_0_0l = 0;
    for it_0_0l in fv_0_0 {
        e_0_0l = _emit_node(it_0_0l);
        PyList_SetItem(v_0_0, li_0_0l, e_0_0l);
        li_0_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_0_0);
    Py_DecRef(v_0_0);

    fv_0_1 = nd.parent;
    if fv_0_1 is None {
        v_0_1 = _py_none();
    } else {
        v_0_1 = _emit_node(fv_0_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_0_1);
    Py_DecRef(v_0_1);

    v_0_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_0_2);
    Py_DecRef(v_0_2);

    fv_0_3 = nd._in_mod_nodes;
    v_0_3 = PyList_New(len(fv_0_3));
    li_0_3l = 0;
    for it_0_3l in fv_0_3 {
        e_0_3l = _emit_node(it_0_3l);
        PyList_SetItem(v_0_3, li_0_3l, e_0_3l);
        li_0_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_0_3);
    Py_DecRef(v_0_3);

    v_0_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_0_4);
    Py_DecRef(v_0_4);

    fv_0_5 = nd.loc;
    v_0_5 = _emit_CodeLocInfo(fv_0_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_0_5);
    Py_DecRef(v_0_5);

    fv_0_6 = nd.code_context;
    v_0_6 = _enum_CodeContext(fv_0_6);
    PyDict_SetItem(d_h, _mat_keys[6], v_0_6);
    Py_DecRef(v_0_6);

    fv_0_7 = nd.codespace_dual;
    v_0_7 = PyBool_FromLong(1 if fv_0_7 else 0);
    PyDict_SetItem(d_h, _mat_keys[7], v_0_7);
    Py_DecRef(v_0_7);

    fv_0_8 = nd.doc;
    if fv_0_8 is None {
        v_0_8 = _py_none();
    } else {
        v_0_8 = _emit_node(fv_0_8);
    }
    PyDict_SetItem(d_h, _mat_keys[8], v_0_8);
    Py_DecRef(v_0_8);

    fv_0_9 = nd.bb_in;
    v_0_9 = PyList_New(len(fv_0_9));
    li_0_9l = 0;
    for it_0_9l in fv_0_9 {
        e_0_9l = _emit_node(it_0_9l);
        PyList_SetItem(v_0_9, li_0_9l, e_0_9l);
        li_0_9l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_0_9);
    Py_DecRef(v_0_9);

    fv_0_10 = nd.bb_out;
    v_0_10 = PyList_New(len(fv_0_10));
    li_0_10l = 0;
    for it_0_10l in fv_0_10 {
        e_0_10l = _emit_node(it_0_10l);
        PyList_SetItem(v_0_10, li_0_10l, e_0_10l);
        li_0_10l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_0_10);
    Py_DecRef(v_0_10);

    fv_0_11 = nd.affected_symbols;
    v_0_11 = PySet_New(0);
    if len(fv_0_11) != 0 {
        Py_DecRef(v_0_11);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_0_11);
    Py_DecRef(v_0_11);

    fv_0_12 = nd.name_spec;
    v_0_12 = _emit_node(fv_0_12);
    PyDict_SetItem(d_h, _mat_keys[12], v_0_12);
    Py_DecRef(v_0_12);

    fv_0_13 = nd.semstr;
    v_0_13 = _py_str(fv_0_13);
    PyDict_SetItem(d_h, _mat_keys[13], v_0_13);
    Py_DecRef(v_0_13);

    fv_0_14 = nd.is_async;
    v_0_14 = PyBool_FromLong(1 if fv_0_14 else 0);
    PyDict_SetItem(d_h, _mat_keys[14], v_0_14);
    Py_DecRef(v_0_14);

    fv_0_15 = nd.decorators;
    if fv_0_15 is None {
        v_0_15 = _py_none();
    } else {
        v_0_15 = PyList_New(len(fv_0_15));
        li_0_15l = 0;
        for it_0_15l in fv_0_15 {
            e_0_15l = _emit_node(it_0_15l);
            PyList_SetItem(v_0_15, li_0_15l, e_0_15l);
            li_0_15l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[15], v_0_15);
    Py_DecRef(v_0_15);

    fv_0_16 = nd.access;
    if fv_0_16 is None {
        v_0_16 = _py_none();
    } else {
        v_0_16 = _emit_node(fv_0_16);
    }
    PyDict_SetItem(d_h, _mat_keys[16], v_0_16);
    Py_DecRef(v_0_16);

    v_0_17 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[17], v_0_17);
    Py_DecRef(v_0_17);

    fv_0_18 = nd.scope_name;
    v_0_18 = _py_str(fv_0_18);
    PyDict_SetItem(d_h, _mat_keys[18], v_0_18);
    Py_DecRef(v_0_18);

    fv_0_19 = nd.parent_scope;
    if fv_0_19 is None {
        v_0_19 = _py_none();
    } else {
        v_0_19 = _emit_node(fv_0_19);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_0_19);
    Py_DecRef(v_0_19);

    fv_0_20 = nd.kid_scope;
    v_0_20 = PyList_New(len(fv_0_20));
    li_0_20l = 0;
    for it_0_20l in fv_0_20 {
        e_0_20l = _emit_node(it_0_20l);
        PyList_SetItem(v_0_20, li_0_20l, e_0_20l);
        li_0_20l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_0_20);
    Py_DecRef(v_0_20);

    fv_0_21 = nd.names_in_scope;
    v_0_21 = PyDict_New();
    for (dk_0_21d, dv_0_21d) in fv_0_21.items() {
        kh_0_21d = _py_str(dk_0_21d);
        vh_0_21d = _emit_Symbol(dv_0_21d);
        PyDict_SetItem(v_0_21, kh_0_21d, vh_0_21d);
        Py_DecRef(kh_0_21d);
        Py_DecRef(vh_0_21d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_0_21);
    Py_DecRef(v_0_21);

    fv_0_22 = nd.names_in_scope_overload;
    v_0_22 = PyDict_New();
    for (dk_0_22d, dv_0_22d) in fv_0_22.items() {
        kh_0_22d = _py_str(dk_0_22d);
        vh_0_22d = PyList_New(len(dv_0_22d));
        li_0_22dl = 0;
        for it_0_22dl in dv_0_22d {
            e_0_22dl = _emit_Symbol(it_0_22dl);
            PyList_SetItem(vh_0_22d, li_0_22dl, e_0_22dl);
            li_0_22dl += 1;
        }
        PyDict_SetItem(v_0_22, kh_0_22d, vh_0_22d);
        Py_DecRef(kh_0_22d);
        Py_DecRef(vh_0_22d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_0_22);
    Py_DecRef(v_0_22);

    fv_0_23 = nd.implicit_rebinds;
    v_0_23 = PyDict_New();
    for (dk_0_23d, dv_0_23d) in fv_0_23.items() {
        kh_0_23d = _py_str(dk_0_23d);
        vh_0_23d = _emit_Symbol(dv_0_23d);
        PyDict_SetItem(v_0_23, kh_0_23d, vh_0_23d);
        Py_DecRef(kh_0_23d);
        Py_DecRef(vh_0_23d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_0_23);
    Py_DecRef(v_0_23);

    fv_0_24 = nd.name;
    v_0_24 = _emit_node(fv_0_24);
    PyDict_SetItem(d_h, _mat_keys[24], v_0_24);
    Py_DecRef(v_0_24);

    fv_0_25 = nd.arch_type;
    v_0_25 = _emit_node(fv_0_25);
    PyDict_SetItem(d_h, _mat_keys[25], v_0_25);
    Py_DecRef(v_0_25);

    fv_0_26 = nd.base_classes;
    if fv_0_26 is None {
        v_0_26 = _py_none();
    } else {
        v_0_26 = PyList_New(len(fv_0_26));
        li_0_26l = 0;
        for it_0_26l in fv_0_26 {
            e_0_26l = _emit_node(it_0_26l);
            PyList_SetItem(v_0_26, li_0_26l, e_0_26l);
            li_0_26l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[26], v_0_26);
    Py_DecRef(v_0_26);

    fv_0_27 = nd.keywords;
    if fv_0_27 is None {
        v_0_27 = _py_none();
    } else {
        v_0_27 = PyList_New(len(fv_0_27));
        li_0_27l = 0;
        for it_0_27l in fv_0_27 {
            e_0_27l = _emit_node(it_0_27l);
            PyList_SetItem(v_0_27, li_0_27l, e_0_27l);
            li_0_27l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[27], v_0_27);
    Py_DecRef(v_0_27);

    fv_0_28 = nd.type_params;
    if fv_0_28 is None {
        v_0_28 = _py_none();
    } else {
        v_0_28 = PyList_New(len(fv_0_28));
        li_0_28l = 0;
        for it_0_28l in fv_0_28 {
            e_0_28l = _emit_node(it_0_28l);
            PyList_SetItem(v_0_28, li_0_28l, e_0_28l);
            li_0_28l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[28], v_0_28);
    Py_DecRef(v_0_28);

    fv_0_29 = nd.src_endpoint;
    if fv_0_29 is None {
        v_0_29 = _py_none();
    } else {
        v_0_29 = _emit_node(fv_0_29);
    }
    PyDict_SetItem(d_h, _mat_keys[29], v_0_29);
    Py_DecRef(v_0_29);

    fv_0_30 = nd.tgt_endpoint;
    if fv_0_30 is None {
        v_0_30 = _py_none();
    } else {
        v_0_30 = _emit_node(fv_0_30);
    }
    PyDict_SetItem(d_h, _mat_keys[30], v_0_30);
    Py_DecRef(v_0_30);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_Enum(nd: Enum) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[1], _mat_classes[1]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_1_0 = nd.kid;
    v_1_0 = PyList_New(len(fv_1_0));
    li_1_0l = 0;
    for it_1_0l in fv_1_0 {
        e_1_0l = _emit_node(it_1_0l);
        PyList_SetItem(v_1_0, li_1_0l, e_1_0l);
        li_1_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_1_0);
    Py_DecRef(v_1_0);

    fv_1_1 = nd.parent;
    if fv_1_1 is None {
        v_1_1 = _py_none();
    } else {
        v_1_1 = _emit_node(fv_1_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_1_1);
    Py_DecRef(v_1_1);

    v_1_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_1_2);
    Py_DecRef(v_1_2);

    fv_1_3 = nd._in_mod_nodes;
    v_1_3 = PyList_New(len(fv_1_3));
    li_1_3l = 0;
    for it_1_3l in fv_1_3 {
        e_1_3l = _emit_node(it_1_3l);
        PyList_SetItem(v_1_3, li_1_3l, e_1_3l);
        li_1_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_1_3);
    Py_DecRef(v_1_3);

    v_1_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_1_4);
    Py_DecRef(v_1_4);

    fv_1_5 = nd.loc;
    v_1_5 = _emit_CodeLocInfo(fv_1_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_1_5);
    Py_DecRef(v_1_5);

    fv_1_6 = nd.code_context;
    v_1_6 = _enum_CodeContext(fv_1_6);
    PyDict_SetItem(d_h, _mat_keys[6], v_1_6);
    Py_DecRef(v_1_6);

    fv_1_7 = nd.codespace_dual;
    v_1_7 = PyBool_FromLong(1 if fv_1_7 else 0);
    PyDict_SetItem(d_h, _mat_keys[7], v_1_7);
    Py_DecRef(v_1_7);

    fv_1_8 = nd.doc;
    if fv_1_8 is None {
        v_1_8 = _py_none();
    } else {
        v_1_8 = _emit_node(fv_1_8);
    }
    PyDict_SetItem(d_h, _mat_keys[8], v_1_8);
    Py_DecRef(v_1_8);

    fv_1_9 = nd.bb_in;
    v_1_9 = PyList_New(len(fv_1_9));
    li_1_9l = 0;
    for it_1_9l in fv_1_9 {
        e_1_9l = _emit_node(it_1_9l);
        PyList_SetItem(v_1_9, li_1_9l, e_1_9l);
        li_1_9l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_1_9);
    Py_DecRef(v_1_9);

    fv_1_10 = nd.bb_out;
    v_1_10 = PyList_New(len(fv_1_10));
    li_1_10l = 0;
    for it_1_10l in fv_1_10 {
        e_1_10l = _emit_node(it_1_10l);
        PyList_SetItem(v_1_10, li_1_10l, e_1_10l);
        li_1_10l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_1_10);
    Py_DecRef(v_1_10);

    fv_1_11 = nd.affected_symbols;
    v_1_11 = PySet_New(0);
    if len(fv_1_11) != 0 {
        Py_DecRef(v_1_11);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_1_11);
    Py_DecRef(v_1_11);

    fv_1_12 = nd.name_spec;
    v_1_12 = _emit_node(fv_1_12);
    PyDict_SetItem(d_h, _mat_keys[12], v_1_12);
    Py_DecRef(v_1_12);

    fv_1_13 = nd.semstr;
    v_1_13 = _py_str(fv_1_13);
    PyDict_SetItem(d_h, _mat_keys[13], v_1_13);
    Py_DecRef(v_1_13);

    fv_1_14 = nd.is_async;
    v_1_14 = PyBool_FromLong(1 if fv_1_14 else 0);
    PyDict_SetItem(d_h, _mat_keys[14], v_1_14);
    Py_DecRef(v_1_14);

    fv_1_15 = nd.decorators;
    if fv_1_15 is None {
        v_1_15 = _py_none();
    } else {
        v_1_15 = PyList_New(len(fv_1_15));
        li_1_15l = 0;
        for it_1_15l in fv_1_15 {
            e_1_15l = _emit_node(it_1_15l);
            PyList_SetItem(v_1_15, li_1_15l, e_1_15l);
            li_1_15l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[15], v_1_15);
    Py_DecRef(v_1_15);

    fv_1_16 = nd.access;
    if fv_1_16 is None {
        v_1_16 = _py_none();
    } else {
        v_1_16 = _emit_node(fv_1_16);
    }
    PyDict_SetItem(d_h, _mat_keys[16], v_1_16);
    Py_DecRef(v_1_16);

    v_1_17 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[17], v_1_17);
    Py_DecRef(v_1_17);

    fv_1_18 = nd.scope_name;
    v_1_18 = _py_str(fv_1_18);
    PyDict_SetItem(d_h, _mat_keys[18], v_1_18);
    Py_DecRef(v_1_18);

    fv_1_19 = nd.parent_scope;
    if fv_1_19 is None {
        v_1_19 = _py_none();
    } else {
        v_1_19 = _emit_node(fv_1_19);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_1_19);
    Py_DecRef(v_1_19);

    fv_1_20 = nd.kid_scope;
    v_1_20 = PyList_New(len(fv_1_20));
    li_1_20l = 0;
    for it_1_20l in fv_1_20 {
        e_1_20l = _emit_node(it_1_20l);
        PyList_SetItem(v_1_20, li_1_20l, e_1_20l);
        li_1_20l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_1_20);
    Py_DecRef(v_1_20);

    fv_1_21 = nd.names_in_scope;
    v_1_21 = PyDict_New();
    for (dk_1_21d, dv_1_21d) in fv_1_21.items() {
        kh_1_21d = _py_str(dk_1_21d);
        vh_1_21d = _emit_Symbol(dv_1_21d);
        PyDict_SetItem(v_1_21, kh_1_21d, vh_1_21d);
        Py_DecRef(kh_1_21d);
        Py_DecRef(vh_1_21d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_1_21);
    Py_DecRef(v_1_21);

    fv_1_22 = nd.names_in_scope_overload;
    v_1_22 = PyDict_New();
    for (dk_1_22d, dv_1_22d) in fv_1_22.items() {
        kh_1_22d = _py_str(dk_1_22d);
        vh_1_22d = PyList_New(len(dv_1_22d));
        li_1_22dl = 0;
        for it_1_22dl in dv_1_22d {
            e_1_22dl = _emit_Symbol(it_1_22dl);
            PyList_SetItem(vh_1_22d, li_1_22dl, e_1_22dl);
            li_1_22dl += 1;
        }
        PyDict_SetItem(v_1_22, kh_1_22d, vh_1_22d);
        Py_DecRef(kh_1_22d);
        Py_DecRef(vh_1_22d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_1_22);
    Py_DecRef(v_1_22);

    fv_1_23 = nd.implicit_rebinds;
    v_1_23 = PyDict_New();
    for (dk_1_23d, dv_1_23d) in fv_1_23.items() {
        kh_1_23d = _py_str(dk_1_23d);
        vh_1_23d = _emit_Symbol(dv_1_23d);
        PyDict_SetItem(v_1_23, kh_1_23d, vh_1_23d);
        Py_DecRef(kh_1_23d);
        Py_DecRef(vh_1_23d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_1_23);
    Py_DecRef(v_1_23);

    fv_1_24 = nd.name;
    v_1_24 = _emit_node(fv_1_24);
    PyDict_SetItem(d_h, _mat_keys[24], v_1_24);
    Py_DecRef(v_1_24);

    fv_1_25 = nd.value_type;
    if fv_1_25 is None {
        v_1_25 = _py_none();
    } else {
        v_1_25 = _emit_node(fv_1_25);
    }
    PyDict_SetItem(d_h, _mat_keys[31], v_1_25);
    Py_DecRef(v_1_25);

    fv_1_26 = nd.base_classes;
    if fv_1_26 is None {
        v_1_26 = _py_none();
    } else {
        v_1_26 = PyList_New(len(fv_1_26));
        li_1_26l = 0;
        for it_1_26l in fv_1_26 {
            e_1_26l = _emit_node(it_1_26l);
            PyList_SetItem(v_1_26, li_1_26l, e_1_26l);
            li_1_26l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[26], v_1_26);
    Py_DecRef(v_1_26);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_Ability(nd: Ability) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[2], _mat_classes[2]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_2_0 = nd.kid;
    v_2_0 = PyList_New(len(fv_2_0));
    li_2_0l = 0;
    for it_2_0l in fv_2_0 {
        e_2_0l = _emit_node(it_2_0l);
        PyList_SetItem(v_2_0, li_2_0l, e_2_0l);
        li_2_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_2_0);
    Py_DecRef(v_2_0);

    fv_2_1 = nd.parent;
    if fv_2_1 is None {
        v_2_1 = _py_none();
    } else {
        v_2_1 = _emit_node(fv_2_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_2_1);
    Py_DecRef(v_2_1);

    v_2_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_2_2);
    Py_DecRef(v_2_2);

    fv_2_3 = nd._in_mod_nodes;
    v_2_3 = PyList_New(len(fv_2_3));
    li_2_3l = 0;
    for it_2_3l in fv_2_3 {
        e_2_3l = _emit_node(it_2_3l);
        PyList_SetItem(v_2_3, li_2_3l, e_2_3l);
        li_2_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_2_3);
    Py_DecRef(v_2_3);

    v_2_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_2_4);
    Py_DecRef(v_2_4);

    fv_2_5 = nd.loc;
    v_2_5 = _emit_CodeLocInfo(fv_2_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_2_5);
    Py_DecRef(v_2_5);

    fv_2_6 = nd.code_context;
    v_2_6 = _enum_CodeContext(fv_2_6);
    PyDict_SetItem(d_h, _mat_keys[6], v_2_6);
    Py_DecRef(v_2_6);

    fv_2_7 = nd.codespace_dual;
    v_2_7 = PyBool_FromLong(1 if fv_2_7 else 0);
    PyDict_SetItem(d_h, _mat_keys[7], v_2_7);
    Py_DecRef(v_2_7);

    fv_2_8 = nd.access;
    if fv_2_8 is None {
        v_2_8 = _py_none();
    } else {
        v_2_8 = _emit_node(fv_2_8);
    }
    PyDict_SetItem(d_h, _mat_keys[16], v_2_8);
    Py_DecRef(v_2_8);

    fv_2_9 = nd.doc;
    if fv_2_9 is None {
        v_2_9 = _py_none();
    } else {
        v_2_9 = _emit_node(fv_2_9);
    }
    PyDict_SetItem(d_h, _mat_keys[8], v_2_9);
    Py_DecRef(v_2_9);

    fv_2_10 = nd.is_async;
    v_2_10 = PyBool_FromLong(1 if fv_2_10 else 0);
    PyDict_SetItem(d_h, _mat_keys[14], v_2_10);
    Py_DecRef(v_2_10);

    fv_2_11 = nd.bb_in;
    v_2_11 = PyList_New(len(fv_2_11));
    li_2_11l = 0;
    for it_2_11l in fv_2_11 {
        e_2_11l = _emit_node(it_2_11l);
        PyList_SetItem(v_2_11, li_2_11l, e_2_11l);
        li_2_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_2_11);
    Py_DecRef(v_2_11);

    fv_2_12 = nd.bb_out;
    v_2_12 = PyList_New(len(fv_2_12));
    li_2_12l = 0;
    for it_2_12l in fv_2_12 {
        e_2_12l = _emit_node(it_2_12l);
        PyList_SetItem(v_2_12, li_2_12l, e_2_12l);
        li_2_12l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_2_12);
    Py_DecRef(v_2_12);

    fv_2_13 = nd.affected_symbols;
    v_2_13 = PySet_New(0);
    if len(fv_2_13) != 0 {
        Py_DecRef(v_2_13);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_2_13);
    Py_DecRef(v_2_13);

    fv_2_14 = nd.name_spec;
    v_2_14 = _emit_node(fv_2_14);
    PyDict_SetItem(d_h, _mat_keys[12], v_2_14);
    Py_DecRef(v_2_14);

    fv_2_15 = nd.semstr;
    v_2_15 = _py_str(fv_2_15);
    PyDict_SetItem(d_h, _mat_keys[13], v_2_15);
    Py_DecRef(v_2_15);

    v_2_16 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[17], v_2_16);
    Py_DecRef(v_2_16);

    fv_2_17 = nd.scope_name;
    v_2_17 = _py_str(fv_2_17);
    PyDict_SetItem(d_h, _mat_keys[18], v_2_17);
    Py_DecRef(v_2_17);

    fv_2_18 = nd.parent_scope;
    if fv_2_18 is None {
        v_2_18 = _py_none();
    } else {
        v_2_18 = _emit_node(fv_2_18);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_2_18);
    Py_DecRef(v_2_18);

    fv_2_19 = nd.kid_scope;
    v_2_19 = PyList_New(len(fv_2_19));
    li_2_19l = 0;
    for it_2_19l in fv_2_19 {
        e_2_19l = _emit_node(it_2_19l);
        PyList_SetItem(v_2_19, li_2_19l, e_2_19l);
        li_2_19l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_2_19);
    Py_DecRef(v_2_19);

    fv_2_20 = nd.names_in_scope;
    v_2_20 = PyDict_New();
    for (dk_2_20d, dv_2_20d) in fv_2_20.items() {
        kh_2_20d = _py_str(dk_2_20d);
        vh_2_20d = _emit_Symbol(dv_2_20d);
        PyDict_SetItem(v_2_20, kh_2_20d, vh_2_20d);
        Py_DecRef(kh_2_20d);
        Py_DecRef(vh_2_20d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_2_20);
    Py_DecRef(v_2_20);

    fv_2_21 = nd.names_in_scope_overload;
    v_2_21 = PyDict_New();
    for (dk_2_21d, dv_2_21d) in fv_2_21.items() {
        kh_2_21d = _py_str(dk_2_21d);
        vh_2_21d = PyList_New(len(dv_2_21d));
        li_2_21dl = 0;
        for it_2_21dl in dv_2_21d {
            e_2_21dl = _emit_Symbol(it_2_21dl);
            PyList_SetItem(vh_2_21d, li_2_21dl, e_2_21dl);
            li_2_21dl += 1;
        }
        PyDict_SetItem(v_2_21, kh_2_21d, vh_2_21d);
        Py_DecRef(kh_2_21d);
        Py_DecRef(vh_2_21d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_2_21);
    Py_DecRef(v_2_21);

    fv_2_22 = nd.implicit_rebinds;
    v_2_22 = PyDict_New();
    for (dk_2_22d, dv_2_22d) in fv_2_22.items() {
        kh_2_22d = _py_str(dk_2_22d);
        vh_2_22d = _emit_Symbol(dv_2_22d);
        PyDict_SetItem(v_2_22, kh_2_22d, vh_2_22d);
        Py_DecRef(kh_2_22d);
        Py_DecRef(vh_2_22d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_2_22);
    Py_DecRef(v_2_22);

    fv_2_23 = nd.name_ref;
    if fv_2_23 is None {
        v_2_23 = _py_none();
    } else {
        if isinstance(fv_2_23, NameAtom) {
            v_2_23 = _emit_node(fv_2_23);
        } elif isinstance(fv_2_23, CtName) {
            v_2_23 = _emit_node(fv_2_23);
        } else {
            v_2_23 = _py_none();
        }
    }
    PyDict_SetItem(d_h, _mat_keys[32], v_2_23);
    Py_DecRef(v_2_23);

    fv_2_24 = nd.is_override;
    v_2_24 = PyBool_FromLong(1 if fv_2_24 else 0);
    PyDict_SetItem(d_h, _mat_keys[33], v_2_24);
    Py_DecRef(v_2_24);

    fv_2_25 = nd.is_static;
    v_2_25 = PyBool_FromLong(1 if fv_2_25 else 0);
    PyDict_SetItem(d_h, _mat_keys[34], v_2_25);
    Py_DecRef(v_2_25);

    fv_2_26 = nd.is_classmethod;
    v_2_26 = PyBool_FromLong(1 if fv_2_26 else 0);
    PyDict_SetItem(d_h, _mat_keys[35], v_2_26);
    Py_DecRef(v_2_26);

    fv_2_27 = nd.is_abstract;
    v_2_27 = PyBool_FromLong(1 if fv_2_27 else 0);
    PyDict_SetItem(d_h, _mat_keys[36], v_2_27);
    Py_DecRef(v_2_27);

    fv_2_28 = nd.signature;
    if fv_2_28 is None {
        v_2_28 = _py_none();
    } else {
        if isinstance(fv_2_28, FuncSignature) {
            v_2_28 = _emit_node(fv_2_28);
        } elif isinstance(fv_2_28, EventSignature) {
            v_2_28 = _emit_node(fv_2_28);
        } else {
            v_2_28 = _py_none();
        }
    }
    PyDict_SetItem(d_h, _mat_keys[37], v_2_28);
    Py_DecRef(v_2_28);

    fv_2_29 = nd.decorators;
    if fv_2_29 is None {
        v_2_29 = _py_none();
    } else {
        v_2_29 = PyList_New(len(fv_2_29));
        li_2_29l = 0;
        for it_2_29l in fv_2_29 {
            e_2_29l = _emit_node(it_2_29l);
            PyList_SetItem(v_2_29, li_2_29l, e_2_29l);
            li_2_29l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[15], v_2_29);
    Py_DecRef(v_2_29);

    fv_2_30 = nd.type_params;
    if fv_2_30 is None {
        v_2_30 = _py_none();
    } else {
        v_2_30 = PyList_New(len(fv_2_30));
        li_2_30l = 0;
        for it_2_30l in fv_2_30 {
            e_2_30l = _emit_node(it_2_30l);
            PyList_SetItem(v_2_30, li_2_30l, e_2_30l);
            li_2_30l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[28], v_2_30);
    Py_DecRef(v_2_30);

    fv_2_31 = nd.accessor_kind;
    v_2_31 = _py_str(fv_2_31);
    PyDict_SetItem(d_h, _mat_keys[38], v_2_31);
    Py_DecRef(v_2_31);

    v_2_32 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[39], v_2_32);
    Py_DecRef(v_2_32);

    fv_2_33 = nd.is_ct_only;
    v_2_33 = PyBool_FromLong(1 if fv_2_33 else 0);
    PyDict_SetItem(d_h, _mat_keys[40], v_2_33);
    Py_DecRef(v_2_33);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_BuiltinType(nd: BuiltinType) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[3], _mat_classes[3]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_3_0 = nd.kid;
    v_3_0 = PyList_New(len(fv_3_0));
    li_3_0l = 0;
    for it_3_0l in fv_3_0 {
        e_3_0l = _emit_node(it_3_0l);
        PyList_SetItem(v_3_0, li_3_0l, e_3_0l);
        li_3_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_3_0);
    Py_DecRef(v_3_0);

    fv_3_1 = nd.parent;
    if fv_3_1 is None {
        v_3_1 = _py_none();
    } else {
        v_3_1 = _emit_node(fv_3_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_3_1);
    Py_DecRef(v_3_1);

    v_3_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_3_2);
    Py_DecRef(v_3_2);

    fv_3_3 = nd._in_mod_nodes;
    v_3_3 = PyList_New(len(fv_3_3));
    li_3_3l = 0;
    for it_3_3l in fv_3_3 {
        e_3_3l = _emit_node(it_3_3l);
        PyList_SetItem(v_3_3, li_3_3l, e_3_3l);
        li_3_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_3_3);
    Py_DecRef(v_3_3);

    v_3_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_3_4);
    Py_DecRef(v_3_4);

    fv_3_5 = nd.loc;
    v_3_5 = _emit_CodeLocInfo(fv_3_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_3_5);
    Py_DecRef(v_3_5);

    fv_3_6 = nd.orig_src;
    v_3_6 = _emit_node(fv_3_6);
    PyDict_SetItem(d_h, _mat_keys[41], v_3_6);
    Py_DecRef(v_3_6);

    fv_3_7 = nd.name;
    v_3_7 = _py_str(fv_3_7);
    PyDict_SetItem(d_h, _mat_keys[24], v_3_7);
    Py_DecRef(v_3_7);

    fv_3_8 = nd.value;
    v_3_8 = _py_str(fv_3_8);
    PyDict_SetItem(d_h, _mat_keys[42], v_3_8);
    Py_DecRef(v_3_8);

    fv_3_9 = nd.line_no;
    v_3_9 = PyLong_FromLongLong(fv_3_9);
    PyDict_SetItem(d_h, _mat_keys[43], v_3_9);
    Py_DecRef(v_3_9);

    fv_3_10 = nd.end_line;
    v_3_10 = PyLong_FromLongLong(fv_3_10);
    PyDict_SetItem(d_h, _mat_keys[44], v_3_10);
    Py_DecRef(v_3_10);

    fv_3_11 = nd.c_start;
    v_3_11 = PyLong_FromLongLong(fv_3_11);
    PyDict_SetItem(d_h, _mat_keys[45], v_3_11);
    Py_DecRef(v_3_11);

    fv_3_12 = nd.c_end;
    v_3_12 = PyLong_FromLongLong(fv_3_12);
    PyDict_SetItem(d_h, _mat_keys[46], v_3_12);
    Py_DecRef(v_3_12);

    fv_3_13 = nd.pos_start;
    v_3_13 = PyLong_FromLongLong(fv_3_13);
    PyDict_SetItem(d_h, _mat_keys[47], v_3_13);
    Py_DecRef(v_3_13);

    fv_3_14 = nd.pos_end;
    v_3_14 = PyLong_FromLongLong(fv_3_14);
    PyDict_SetItem(d_h, _mat_keys[48], v_3_14);
    Py_DecRef(v_3_14);

    fv_3_15 = nd._is_synthetic;
    v_3_15 = PyBool_FromLong(1 if fv_3_15 else 0);
    PyDict_SetItem(d_h, _mat_keys[49], v_3_15);
    Py_DecRef(v_3_15);

    fv_3_16 = nd._type_sym_tab;
    if fv_3_16 is None {
        v_3_16 = _py_none();
    } else {
        v_3_16 = _emit_node(fv_3_16);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_3_16);
    Py_DecRef(v_3_16);

    v_3_17 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_3_17);
    Py_DecRef(v_3_17);

    fv_3_18 = nd.attached_tokens;
    if fv_3_18 is None {
        v_3_18 = _py_none();
    } else {
        v_3_18 = PyList_New(len(fv_3_18));
        li_3_18l = 0;
        for it_3_18l in fv_3_18 {
            e_3_18l = _emit_node(it_3_18l);
            PyList_SetItem(v_3_18, li_3_18l, e_3_18l);
            li_3_18l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_3_18);
    Py_DecRef(v_3_18);

    fv_3_19 = nd.name_spec;
    v_3_19 = _emit_node(fv_3_19);
    PyDict_SetItem(d_h, _mat_keys[12], v_3_19);
    Py_DecRef(v_3_19);

    fv_3_20 = nd.semstr;
    v_3_20 = _py_str(fv_3_20);
    PyDict_SetItem(d_h, _mat_keys[13], v_3_20);
    Py_DecRef(v_3_20);

    fv_3_21 = nd.is_enum_stmt;
    v_3_21 = PyBool_FromLong(1 if fv_3_21 else 0);
    PyDict_SetItem(d_h, _mat_keys[53], v_3_21);
    Py_DecRef(v_3_21);

    fv_3_22 = nd.name_of;
    v_3_22 = _emit_node(fv_3_22);
    PyDict_SetItem(d_h, _mat_keys[54], v_3_22);
    Py_DecRef(v_3_22);

    fv_3_23 = nd._sym;
    if fv_3_23 is None {
        v_3_23 = _py_none();
    } else {
        v_3_23 = _emit_Symbol(fv_3_23);
    }
    PyDict_SetItem(d_h, _mat_keys[55], v_3_23);
    Py_DecRef(v_3_23);

    fv_3_24 = nd._sym_name;
    v_3_24 = _py_str(fv_3_24);
    PyDict_SetItem(d_h, _mat_keys[56], v_3_24);
    Py_DecRef(v_3_24);

    fv_3_25 = nd._sym_category;
    v_3_25 = _enum_SymbolType(fv_3_25);
    PyDict_SetItem(d_h, _mat_keys[57], v_3_25);
    Py_DecRef(v_3_25);

    fv_3_26 = nd._expr_ctx;
    v_3_26 = _enum_ExprCtx(fv_3_26);
    PyDict_SetItem(d_h, _mat_keys[58], v_3_26);
    Py_DecRef(v_3_26);

    fv_3_27 = nd.is_kwesc;
    v_3_27 = PyBool_FromLong(1 if fv_3_27 else 0);
    PyDict_SetItem(d_h, _mat_keys[59], v_3_27);
    Py_DecRef(v_3_27);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ImplDef(nd: ImplDef) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[4], _mat_classes[4]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_4_0 = nd.kid;
    v_4_0 = PyList_New(len(fv_4_0));
    li_4_0l = 0;
    for it_4_0l in fv_4_0 {
        e_4_0l = _emit_node(it_4_0l);
        PyList_SetItem(v_4_0, li_4_0l, e_4_0l);
        li_4_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_4_0);
    Py_DecRef(v_4_0);

    fv_4_1 = nd.parent;
    if fv_4_1 is None {
        v_4_1 = _py_none();
    } else {
        v_4_1 = _emit_node(fv_4_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_4_1);
    Py_DecRef(v_4_1);

    v_4_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_4_2);
    Py_DecRef(v_4_2);

    fv_4_3 = nd._in_mod_nodes;
    v_4_3 = PyList_New(len(fv_4_3));
    li_4_3l = 0;
    for it_4_3l in fv_4_3 {
        e_4_3l = _emit_node(it_4_3l);
        PyList_SetItem(v_4_3, li_4_3l, e_4_3l);
        li_4_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_4_3);
    Py_DecRef(v_4_3);

    v_4_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_4_4);
    Py_DecRef(v_4_4);

    fv_4_5 = nd.loc;
    v_4_5 = _emit_CodeLocInfo(fv_4_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_4_5);
    Py_DecRef(v_4_5);

    fv_4_6 = nd.code_context;
    v_4_6 = _enum_CodeContext(fv_4_6);
    PyDict_SetItem(d_h, _mat_keys[6], v_4_6);
    Py_DecRef(v_4_6);

    fv_4_7 = nd.codespace_dual;
    v_4_7 = PyBool_FromLong(1 if fv_4_7 else 0);
    PyDict_SetItem(d_h, _mat_keys[7], v_4_7);
    Py_DecRef(v_4_7);

    fv_4_8 = nd.bb_in;
    v_4_8 = PyList_New(len(fv_4_8));
    li_4_8l = 0;
    for it_4_8l in fv_4_8 {
        e_4_8l = _emit_node(it_4_8l);
        PyList_SetItem(v_4_8, li_4_8l, e_4_8l);
        li_4_8l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_4_8);
    Py_DecRef(v_4_8);

    fv_4_9 = nd.bb_out;
    v_4_9 = PyList_New(len(fv_4_9));
    li_4_9l = 0;
    for it_4_9l in fv_4_9 {
        e_4_9l = _emit_node(it_4_9l);
        PyList_SetItem(v_4_9, li_4_9l, e_4_9l);
        li_4_9l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_4_9);
    Py_DecRef(v_4_9);

    fv_4_10 = nd.affected_symbols;
    v_4_10 = PySet_New(0);
    if len(fv_4_10) != 0 {
        Py_DecRef(v_4_10);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_4_10);
    Py_DecRef(v_4_10);

    fv_4_11 = nd.doc;
    if fv_4_11 is None {
        v_4_11 = _py_none();
    } else {
        v_4_11 = _emit_node(fv_4_11);
    }
    PyDict_SetItem(d_h, _mat_keys[8], v_4_11);
    Py_DecRef(v_4_11);

    fv_4_12 = nd.name_spec;
    v_4_12 = _emit_node(fv_4_12);
    PyDict_SetItem(d_h, _mat_keys[12], v_4_12);
    Py_DecRef(v_4_12);

    fv_4_13 = nd.semstr;
    v_4_13 = _py_str(fv_4_13);
    PyDict_SetItem(d_h, _mat_keys[13], v_4_13);
    Py_DecRef(v_4_13);

    fv_4_14 = nd.scope_name;
    v_4_14 = _py_str(fv_4_14);
    PyDict_SetItem(d_h, _mat_keys[18], v_4_14);
    Py_DecRef(v_4_14);

    fv_4_15 = nd.parent_scope;
    if fv_4_15 is None {
        v_4_15 = _py_none();
    } else {
        v_4_15 = _emit_node(fv_4_15);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_4_15);
    Py_DecRef(v_4_15);

    fv_4_16 = nd.kid_scope;
    v_4_16 = PyList_New(len(fv_4_16));
    li_4_16l = 0;
    for it_4_16l in fv_4_16 {
        e_4_16l = _emit_node(it_4_16l);
        PyList_SetItem(v_4_16, li_4_16l, e_4_16l);
        li_4_16l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_4_16);
    Py_DecRef(v_4_16);

    fv_4_17 = nd.names_in_scope;
    v_4_17 = PyDict_New();
    for (dk_4_17d, dv_4_17d) in fv_4_17.items() {
        kh_4_17d = _py_str(dk_4_17d);
        vh_4_17d = _emit_Symbol(dv_4_17d);
        PyDict_SetItem(v_4_17, kh_4_17d, vh_4_17d);
        Py_DecRef(kh_4_17d);
        Py_DecRef(vh_4_17d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_4_17);
    Py_DecRef(v_4_17);

    fv_4_18 = nd.names_in_scope_overload;
    v_4_18 = PyDict_New();
    for (dk_4_18d, dv_4_18d) in fv_4_18.items() {
        kh_4_18d = _py_str(dk_4_18d);
        vh_4_18d = PyList_New(len(dv_4_18d));
        li_4_18dl = 0;
        for it_4_18dl in dv_4_18d {
            e_4_18dl = _emit_Symbol(it_4_18dl);
            PyList_SetItem(vh_4_18d, li_4_18dl, e_4_18dl);
            li_4_18dl += 1;
        }
        PyDict_SetItem(v_4_18, kh_4_18d, vh_4_18d);
        Py_DecRef(kh_4_18d);
        Py_DecRef(vh_4_18d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_4_18);
    Py_DecRef(v_4_18);

    fv_4_19 = nd.implicit_rebinds;
    v_4_19 = PyDict_New();
    for (dk_4_19d, dv_4_19d) in fv_4_19.items() {
        kh_4_19d = _py_str(dk_4_19d);
        vh_4_19d = _emit_Symbol(dv_4_19d);
        PyDict_SetItem(v_4_19, kh_4_19d, vh_4_19d);
        Py_DecRef(kh_4_19d);
        Py_DecRef(vh_4_19d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_4_19);
    Py_DecRef(v_4_19);

    fv_4_20 = nd.decorators;
    if fv_4_20 is None {
        v_4_20 = _py_none();
    } else {
        v_4_20 = PyList_New(len(fv_4_20));
        li_4_20l = 0;
        for it_4_20l in fv_4_20 {
            e_4_20l = _emit_node(it_4_20l);
            PyList_SetItem(v_4_20, li_4_20l, e_4_20l);
            li_4_20l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[15], v_4_20);
    Py_DecRef(v_4_20);

    fv_4_21 = nd.target;
    v_4_21 = PyList_New(len(fv_4_21));
    li_4_21l = 0;
    for it_4_21l in fv_4_21 {
        e_4_21l = _emit_node(it_4_21l);
        PyList_SetItem(v_4_21, li_4_21l, e_4_21l);
        li_4_21l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[60], v_4_21);
    Py_DecRef(v_4_21);

    fv_4_22 = nd.spec;
    if fv_4_22 is None {
        v_4_22 = _py_none();
    } else {
        if isinstance(fv_4_22, list) {
            tl_4_22: list[Expr] = fv_4_22;
            v_4_22 = PyList_New(len(tl_4_22));
            li_4_22l = 0;
            for it_4_22l in tl_4_22 {
                e_4_22l = _emit_node(it_4_22l);
                PyList_SetItem(v_4_22, li_4_22l, e_4_22l);
                li_4_22l += 1;
            }
        } elif isinstance(fv_4_22, FuncSignature) {
            v_4_22 = _emit_node(fv_4_22);
        } elif isinstance(fv_4_22, EventSignature) {
            v_4_22 = _emit_node(fv_4_22);
        } else {
            v_4_22 = _py_none();
        }
    }
    PyDict_SetItem(d_h, _mat_keys[61], v_4_22);
    Py_DecRef(v_4_22);

    fv_4_23 = nd.body;
    if isinstance(fv_4_23, list) {
        tl_4_23: list[CodeBlockStmt] = fv_4_23;
        v_4_23 = PyList_New(len(tl_4_23));
        li_4_23l = 0;
        for it_4_23l in tl_4_23 {
            e_4_23l = _emit_node(it_4_23l);
            PyList_SetItem(v_4_23, li_4_23l, e_4_23l);
            li_4_23l += 1;
        }
    } elif isinstance(fv_4_23, Expr) {
        v_4_23 = _emit_node(fv_4_23);
    } else {
        v_4_23 = _py_none();
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_4_23);
    Py_DecRef(v_4_23);

    fv_4_24 = nd.decl_link;
    if fv_4_24 is None {
        v_4_24 = _py_none();
    } else {
        v_4_24 = _emit_node(fv_4_24);
    }
    PyDict_SetItem(d_h, _mat_keys[62], v_4_24);
    Py_DecRef(v_4_24);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_SpecialVarRef(nd: SpecialVarRef) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[5], _mat_classes[5]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_5_0 = nd.kid;
    v_5_0 = PyList_New(len(fv_5_0));
    li_5_0l = 0;
    for it_5_0l in fv_5_0 {
        e_5_0l = _emit_node(it_5_0l);
        PyList_SetItem(v_5_0, li_5_0l, e_5_0l);
        li_5_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_5_0);
    Py_DecRef(v_5_0);

    fv_5_1 = nd.parent;
    if fv_5_1 is None {
        v_5_1 = _py_none();
    } else {
        v_5_1 = _emit_node(fv_5_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_5_1);
    Py_DecRef(v_5_1);

    v_5_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_5_2);
    Py_DecRef(v_5_2);

    fv_5_3 = nd._in_mod_nodes;
    v_5_3 = PyList_New(len(fv_5_3));
    li_5_3l = 0;
    for it_5_3l in fv_5_3 {
        e_5_3l = _emit_node(it_5_3l);
        PyList_SetItem(v_5_3, li_5_3l, e_5_3l);
        li_5_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_5_3);
    Py_DecRef(v_5_3);

    v_5_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_5_4);
    Py_DecRef(v_5_4);

    fv_5_5 = nd.loc;
    v_5_5 = _emit_CodeLocInfo(fv_5_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_5_5);
    Py_DecRef(v_5_5);

    fv_5_6 = nd.orig_src;
    v_5_6 = _emit_node(fv_5_6);
    PyDict_SetItem(d_h, _mat_keys[41], v_5_6);
    Py_DecRef(v_5_6);

    fv_5_7 = nd.name;
    v_5_7 = _py_str(fv_5_7);
    PyDict_SetItem(d_h, _mat_keys[24], v_5_7);
    Py_DecRef(v_5_7);

    fv_5_8 = nd.value;
    v_5_8 = _py_str(fv_5_8);
    PyDict_SetItem(d_h, _mat_keys[42], v_5_8);
    Py_DecRef(v_5_8);

    fv_5_9 = nd.line_no;
    v_5_9 = PyLong_FromLongLong(fv_5_9);
    PyDict_SetItem(d_h, _mat_keys[43], v_5_9);
    Py_DecRef(v_5_9);

    fv_5_10 = nd.end_line;
    v_5_10 = PyLong_FromLongLong(fv_5_10);
    PyDict_SetItem(d_h, _mat_keys[44], v_5_10);
    Py_DecRef(v_5_10);

    fv_5_11 = nd.c_start;
    v_5_11 = PyLong_FromLongLong(fv_5_11);
    PyDict_SetItem(d_h, _mat_keys[45], v_5_11);
    Py_DecRef(v_5_11);

    fv_5_12 = nd.c_end;
    v_5_12 = PyLong_FromLongLong(fv_5_12);
    PyDict_SetItem(d_h, _mat_keys[46], v_5_12);
    Py_DecRef(v_5_12);

    fv_5_13 = nd.pos_start;
    v_5_13 = PyLong_FromLongLong(fv_5_13);
    PyDict_SetItem(d_h, _mat_keys[47], v_5_13);
    Py_DecRef(v_5_13);

    fv_5_14 = nd.pos_end;
    v_5_14 = PyLong_FromLongLong(fv_5_14);
    PyDict_SetItem(d_h, _mat_keys[48], v_5_14);
    Py_DecRef(v_5_14);

    fv_5_15 = nd._is_synthetic;
    v_5_15 = PyBool_FromLong(1 if fv_5_15 else 0);
    PyDict_SetItem(d_h, _mat_keys[49], v_5_15);
    Py_DecRef(v_5_15);

    fv_5_16 = nd._type_sym_tab;
    if fv_5_16 is None {
        v_5_16 = _py_none();
    } else {
        v_5_16 = _emit_node(fv_5_16);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_5_16);
    Py_DecRef(v_5_16);

    v_5_17 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_5_17);
    Py_DecRef(v_5_17);

    fv_5_18 = nd.attached_tokens;
    if fv_5_18 is None {
        v_5_18 = _py_none();
    } else {
        v_5_18 = PyList_New(len(fv_5_18));
        li_5_18l = 0;
        for it_5_18l in fv_5_18 {
            e_5_18l = _emit_node(it_5_18l);
            PyList_SetItem(v_5_18, li_5_18l, e_5_18l);
            li_5_18l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_5_18);
    Py_DecRef(v_5_18);

    fv_5_19 = nd.name_spec;
    v_5_19 = _emit_node(fv_5_19);
    PyDict_SetItem(d_h, _mat_keys[12], v_5_19);
    Py_DecRef(v_5_19);

    fv_5_20 = nd.semstr;
    v_5_20 = _py_str(fv_5_20);
    PyDict_SetItem(d_h, _mat_keys[13], v_5_20);
    Py_DecRef(v_5_20);

    fv_5_21 = nd.is_enum_stmt;
    v_5_21 = PyBool_FromLong(1 if fv_5_21 else 0);
    PyDict_SetItem(d_h, _mat_keys[53], v_5_21);
    Py_DecRef(v_5_21);

    fv_5_22 = nd.name_of;
    v_5_22 = _emit_node(fv_5_22);
    PyDict_SetItem(d_h, _mat_keys[54], v_5_22);
    Py_DecRef(v_5_22);

    fv_5_23 = nd._sym;
    if fv_5_23 is None {
        v_5_23 = _py_none();
    } else {
        v_5_23 = _emit_Symbol(fv_5_23);
    }
    PyDict_SetItem(d_h, _mat_keys[55], v_5_23);
    Py_DecRef(v_5_23);

    fv_5_24 = nd._sym_name;
    v_5_24 = _py_str(fv_5_24);
    PyDict_SetItem(d_h, _mat_keys[56], v_5_24);
    Py_DecRef(v_5_24);

    fv_5_25 = nd._sym_category;
    v_5_25 = _enum_SymbolType(fv_5_25);
    PyDict_SetItem(d_h, _mat_keys[57], v_5_25);
    Py_DecRef(v_5_25);

    fv_5_26 = nd._expr_ctx;
    v_5_26 = _enum_ExprCtx(fv_5_26);
    PyDict_SetItem(d_h, _mat_keys[58], v_5_26);
    Py_DecRef(v_5_26);

    fv_5_27 = nd.is_kwesc;
    v_5_27 = PyBool_FromLong(1 if fv_5_27 else 0);
    PyDict_SetItem(d_h, _mat_keys[59], v_5_27);
    Py_DecRef(v_5_27);

    fv_5_28 = nd.orig;
    v_5_28 = _emit_node(fv_5_28);
    PyDict_SetItem(d_h, _mat_keys[63], v_5_28);
    Py_DecRef(v_5_28);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_TypeAlias(nd: TypeAlias) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[6], _mat_classes[6]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_6_0 = nd.kid;
    v_6_0 = PyList_New(len(fv_6_0));
    li_6_0l = 0;
    for it_6_0l in fv_6_0 {
        e_6_0l = _emit_node(it_6_0l);
        PyList_SetItem(v_6_0, li_6_0l, e_6_0l);
        li_6_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_6_0);
    Py_DecRef(v_6_0);

    fv_6_1 = nd.parent;
    if fv_6_1 is None {
        v_6_1 = _py_none();
    } else {
        v_6_1 = _emit_node(fv_6_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_6_1);
    Py_DecRef(v_6_1);

    v_6_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_6_2);
    Py_DecRef(v_6_2);

    fv_6_3 = nd._in_mod_nodes;
    v_6_3 = PyList_New(len(fv_6_3));
    li_6_3l = 0;
    for it_6_3l in fv_6_3 {
        e_6_3l = _emit_node(it_6_3l);
        PyList_SetItem(v_6_3, li_6_3l, e_6_3l);
        li_6_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_6_3);
    Py_DecRef(v_6_3);

    v_6_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_6_4);
    Py_DecRef(v_6_4);

    fv_6_5 = nd.loc;
    v_6_5 = _emit_CodeLocInfo(fv_6_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_6_5);
    Py_DecRef(v_6_5);

    fv_6_6 = nd.code_context;
    v_6_6 = _enum_CodeContext(fv_6_6);
    PyDict_SetItem(d_h, _mat_keys[6], v_6_6);
    Py_DecRef(v_6_6);

    fv_6_7 = nd.codespace_dual;
    v_6_7 = PyBool_FromLong(1 if fv_6_7 else 0);
    PyDict_SetItem(d_h, _mat_keys[7], v_6_7);
    Py_DecRef(v_6_7);

    fv_6_8 = nd.access;
    if fv_6_8 is None {
        v_6_8 = _py_none();
    } else {
        v_6_8 = _emit_node(fv_6_8);
    }
    PyDict_SetItem(d_h, _mat_keys[16], v_6_8);
    Py_DecRef(v_6_8);

    fv_6_9 = nd.doc;
    if fv_6_9 is None {
        v_6_9 = _py_none();
    } else {
        v_6_9 = _emit_node(fv_6_9);
    }
    PyDict_SetItem(d_h, _mat_keys[8], v_6_9);
    Py_DecRef(v_6_9);

    fv_6_10 = nd.name_spec;
    v_6_10 = _emit_node(fv_6_10);
    PyDict_SetItem(d_h, _mat_keys[12], v_6_10);
    Py_DecRef(v_6_10);

    fv_6_11 = nd.semstr;
    v_6_11 = _py_str(fv_6_11);
    PyDict_SetItem(d_h, _mat_keys[13], v_6_11);
    Py_DecRef(v_6_11);

    fv_6_12 = nd.scope_name;
    v_6_12 = _py_str(fv_6_12);
    PyDict_SetItem(d_h, _mat_keys[18], v_6_12);
    Py_DecRef(v_6_12);

    fv_6_13 = nd.parent_scope;
    if fv_6_13 is None {
        v_6_13 = _py_none();
    } else {
        v_6_13 = _emit_node(fv_6_13);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_6_13);
    Py_DecRef(v_6_13);

    fv_6_14 = nd.kid_scope;
    v_6_14 = PyList_New(len(fv_6_14));
    li_6_14l = 0;
    for it_6_14l in fv_6_14 {
        e_6_14l = _emit_node(it_6_14l);
        PyList_SetItem(v_6_14, li_6_14l, e_6_14l);
        li_6_14l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_6_14);
    Py_DecRef(v_6_14);

    fv_6_15 = nd.names_in_scope;
    v_6_15 = PyDict_New();
    for (dk_6_15d, dv_6_15d) in fv_6_15.items() {
        kh_6_15d = _py_str(dk_6_15d);
        vh_6_15d = _emit_Symbol(dv_6_15d);
        PyDict_SetItem(v_6_15, kh_6_15d, vh_6_15d);
        Py_DecRef(kh_6_15d);
        Py_DecRef(vh_6_15d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_6_15);
    Py_DecRef(v_6_15);

    fv_6_16 = nd.names_in_scope_overload;
    v_6_16 = PyDict_New();
    for (dk_6_16d, dv_6_16d) in fv_6_16.items() {
        kh_6_16d = _py_str(dk_6_16d);
        vh_6_16d = PyList_New(len(dv_6_16d));
        li_6_16dl = 0;
        for it_6_16dl in dv_6_16d {
            e_6_16dl = _emit_Symbol(it_6_16dl);
            PyList_SetItem(vh_6_16d, li_6_16dl, e_6_16dl);
            li_6_16dl += 1;
        }
        PyDict_SetItem(v_6_16, kh_6_16d, vh_6_16d);
        Py_DecRef(kh_6_16d);
        Py_DecRef(vh_6_16d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_6_16);
    Py_DecRef(v_6_16);

    fv_6_17 = nd.implicit_rebinds;
    v_6_17 = PyDict_New();
    for (dk_6_17d, dv_6_17d) in fv_6_17.items() {
        kh_6_17d = _py_str(dk_6_17d);
        vh_6_17d = _emit_Symbol(dv_6_17d);
        PyDict_SetItem(v_6_17, kh_6_17d, vh_6_17d);
        Py_DecRef(kh_6_17d);
        Py_DecRef(vh_6_17d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_6_17);
    Py_DecRef(v_6_17);

    fv_6_18 = nd.bb_in;
    v_6_18 = PyList_New(len(fv_6_18));
    li_6_18l = 0;
    for it_6_18l in fv_6_18 {
        e_6_18l = _emit_node(it_6_18l);
        PyList_SetItem(v_6_18, li_6_18l, e_6_18l);
        li_6_18l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_6_18);
    Py_DecRef(v_6_18);

    fv_6_19 = nd.bb_out;
    v_6_19 = PyList_New(len(fv_6_19));
    li_6_19l = 0;
    for it_6_19l in fv_6_19 {
        e_6_19l = _emit_node(it_6_19l);
        PyList_SetItem(v_6_19, li_6_19l, e_6_19l);
        li_6_19l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_6_19);
    Py_DecRef(v_6_19);

    fv_6_20 = nd.affected_symbols;
    v_6_20 = PySet_New(0);
    if len(fv_6_20) != 0 {
        Py_DecRef(v_6_20);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_6_20);
    Py_DecRef(v_6_20);

    fv_6_21 = nd.name;
    v_6_21 = _emit_node(fv_6_21);
    PyDict_SetItem(d_h, _mat_keys[24], v_6_21);
    Py_DecRef(v_6_21);

    fv_6_22 = nd.type_params;
    if fv_6_22 is None {
        v_6_22 = _py_none();
    } else {
        v_6_22 = PyList_New(len(fv_6_22));
        li_6_22l = 0;
        for it_6_22l in fv_6_22 {
            e_6_22l = _emit_node(it_6_22l);
            PyList_SetItem(v_6_22, li_6_22l, e_6_22l);
            li_6_22l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[28], v_6_22);
    Py_DecRef(v_6_22);

    fv_6_23 = nd.value;
    v_6_23 = _emit_node(fv_6_23);
    PyDict_SetItem(d_h, _mat_keys[42], v_6_23);
    Py_DecRef(v_6_23);

    fv_6_24 = nd.is_distinct;
    v_6_24 = PyBool_FromLong(1 if fv_6_24 else 0);
    PyDict_SetItem(d_h, _mat_keys[64], v_6_24);
    Py_DecRef(v_6_24);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_Name(nd: Name) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[7], _mat_classes[7]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_7_0 = nd.kid;
    v_7_0 = PyList_New(len(fv_7_0));
    li_7_0l = 0;
    for it_7_0l in fv_7_0 {
        e_7_0l = _emit_node(it_7_0l);
        PyList_SetItem(v_7_0, li_7_0l, e_7_0l);
        li_7_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_7_0);
    Py_DecRef(v_7_0);

    fv_7_1 = nd.parent;
    if fv_7_1 is None {
        v_7_1 = _py_none();
    } else {
        v_7_1 = _emit_node(fv_7_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_7_1);
    Py_DecRef(v_7_1);

    v_7_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_7_2);
    Py_DecRef(v_7_2);

    fv_7_3 = nd._in_mod_nodes;
    v_7_3 = PyList_New(len(fv_7_3));
    li_7_3l = 0;
    for it_7_3l in fv_7_3 {
        e_7_3l = _emit_node(it_7_3l);
        PyList_SetItem(v_7_3, li_7_3l, e_7_3l);
        li_7_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_7_3);
    Py_DecRef(v_7_3);

    v_7_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_7_4);
    Py_DecRef(v_7_4);

    fv_7_5 = nd.loc;
    v_7_5 = _emit_CodeLocInfo(fv_7_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_7_5);
    Py_DecRef(v_7_5);

    fv_7_6 = nd.orig_src;
    v_7_6 = _emit_node(fv_7_6);
    PyDict_SetItem(d_h, _mat_keys[41], v_7_6);
    Py_DecRef(v_7_6);

    fv_7_7 = nd.name;
    v_7_7 = _py_str(fv_7_7);
    PyDict_SetItem(d_h, _mat_keys[24], v_7_7);
    Py_DecRef(v_7_7);

    fv_7_8 = nd.value;
    v_7_8 = _py_str(fv_7_8);
    PyDict_SetItem(d_h, _mat_keys[42], v_7_8);
    Py_DecRef(v_7_8);

    fv_7_9 = nd.line_no;
    v_7_9 = PyLong_FromLongLong(fv_7_9);
    PyDict_SetItem(d_h, _mat_keys[43], v_7_9);
    Py_DecRef(v_7_9);

    fv_7_10 = nd.end_line;
    v_7_10 = PyLong_FromLongLong(fv_7_10);
    PyDict_SetItem(d_h, _mat_keys[44], v_7_10);
    Py_DecRef(v_7_10);

    fv_7_11 = nd.c_start;
    v_7_11 = PyLong_FromLongLong(fv_7_11);
    PyDict_SetItem(d_h, _mat_keys[45], v_7_11);
    Py_DecRef(v_7_11);

    fv_7_12 = nd.c_end;
    v_7_12 = PyLong_FromLongLong(fv_7_12);
    PyDict_SetItem(d_h, _mat_keys[46], v_7_12);
    Py_DecRef(v_7_12);

    fv_7_13 = nd.pos_start;
    v_7_13 = PyLong_FromLongLong(fv_7_13);
    PyDict_SetItem(d_h, _mat_keys[47], v_7_13);
    Py_DecRef(v_7_13);

    fv_7_14 = nd.pos_end;
    v_7_14 = PyLong_FromLongLong(fv_7_14);
    PyDict_SetItem(d_h, _mat_keys[48], v_7_14);
    Py_DecRef(v_7_14);

    fv_7_15 = nd._is_synthetic;
    v_7_15 = PyBool_FromLong(1 if fv_7_15 else 0);
    PyDict_SetItem(d_h, _mat_keys[49], v_7_15);
    Py_DecRef(v_7_15);

    fv_7_16 = nd._type_sym_tab;
    if fv_7_16 is None {
        v_7_16 = _py_none();
    } else {
        v_7_16 = _emit_node(fv_7_16);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_7_16);
    Py_DecRef(v_7_16);

    v_7_17 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_7_17);
    Py_DecRef(v_7_17);

    fv_7_18 = nd.attached_tokens;
    if fv_7_18 is None {
        v_7_18 = _py_none();
    } else {
        v_7_18 = PyList_New(len(fv_7_18));
        li_7_18l = 0;
        for it_7_18l in fv_7_18 {
            e_7_18l = _emit_node(it_7_18l);
            PyList_SetItem(v_7_18, li_7_18l, e_7_18l);
            li_7_18l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_7_18);
    Py_DecRef(v_7_18);

    fv_7_19 = nd.name_spec;
    v_7_19 = _emit_node(fv_7_19);
    PyDict_SetItem(d_h, _mat_keys[12], v_7_19);
    Py_DecRef(v_7_19);

    fv_7_20 = nd.semstr;
    v_7_20 = _py_str(fv_7_20);
    PyDict_SetItem(d_h, _mat_keys[13], v_7_20);
    Py_DecRef(v_7_20);

    fv_7_21 = nd.is_enum_stmt;
    v_7_21 = PyBool_FromLong(1 if fv_7_21 else 0);
    PyDict_SetItem(d_h, _mat_keys[53], v_7_21);
    Py_DecRef(v_7_21);

    fv_7_22 = nd.name_of;
    v_7_22 = _emit_node(fv_7_22);
    PyDict_SetItem(d_h, _mat_keys[54], v_7_22);
    Py_DecRef(v_7_22);

    fv_7_23 = nd._sym;
    if fv_7_23 is None {
        v_7_23 = _py_none();
    } else {
        v_7_23 = _emit_Symbol(fv_7_23);
    }
    PyDict_SetItem(d_h, _mat_keys[55], v_7_23);
    Py_DecRef(v_7_23);

    fv_7_24 = nd._sym_name;
    v_7_24 = _py_str(fv_7_24);
    PyDict_SetItem(d_h, _mat_keys[56], v_7_24);
    Py_DecRef(v_7_24);

    fv_7_25 = nd._sym_category;
    v_7_25 = _enum_SymbolType(fv_7_25);
    PyDict_SetItem(d_h, _mat_keys[57], v_7_25);
    Py_DecRef(v_7_25);

    fv_7_26 = nd._expr_ctx;
    v_7_26 = _enum_ExprCtx(fv_7_26);
    PyDict_SetItem(d_h, _mat_keys[58], v_7_26);
    Py_DecRef(v_7_26);

    fv_7_27 = nd.is_kwesc;
    v_7_27 = PyBool_FromLong(1 if fv_7_27 else 0);
    PyDict_SetItem(d_h, _mat_keys[59], v_7_27);
    Py_DecRef(v_7_27);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_GenCompr(nd: GenCompr) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[8], _mat_classes[8]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_8_0 = nd.kid;
    v_8_0 = PyList_New(len(fv_8_0));
    li_8_0l = 0;
    for it_8_0l in fv_8_0 {
        e_8_0l = _emit_node(it_8_0l);
        PyList_SetItem(v_8_0, li_8_0l, e_8_0l);
        li_8_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_8_0);
    Py_DecRef(v_8_0);

    fv_8_1 = nd.parent;
    if fv_8_1 is None {
        v_8_1 = _py_none();
    } else {
        v_8_1 = _emit_node(fv_8_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_8_1);
    Py_DecRef(v_8_1);

    v_8_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_8_2);
    Py_DecRef(v_8_2);

    fv_8_3 = nd._in_mod_nodes;
    v_8_3 = PyList_New(len(fv_8_3));
    li_8_3l = 0;
    for it_8_3l in fv_8_3 {
        e_8_3l = _emit_node(it_8_3l);
        PyList_SetItem(v_8_3, li_8_3l, e_8_3l);
        li_8_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_8_3);
    Py_DecRef(v_8_3);

    v_8_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_8_4);
    Py_DecRef(v_8_4);

    fv_8_5 = nd.loc;
    v_8_5 = _emit_CodeLocInfo(fv_8_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_8_5);
    Py_DecRef(v_8_5);

    fv_8_6 = nd._type_sym_tab;
    if fv_8_6 is None {
        v_8_6 = _py_none();
    } else {
        v_8_6 = _emit_node(fv_8_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_8_6);
    Py_DecRef(v_8_6);

    v_8_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_8_7);
    Py_DecRef(v_8_7);

    fv_8_8 = nd.attached_tokens;
    if fv_8_8 is None {
        v_8_8 = _py_none();
    } else {
        v_8_8 = PyList_New(len(fv_8_8));
        li_8_8l = 0;
        for it_8_8l in fv_8_8 {
            e_8_8l = _emit_node(it_8_8l);
            PyList_SetItem(v_8_8, li_8_8l, e_8_8l);
            li_8_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_8_8);
    Py_DecRef(v_8_8);

    fv_8_9 = nd.name_spec;
    v_8_9 = _emit_node(fv_8_9);
    PyDict_SetItem(d_h, _mat_keys[12], v_8_9);
    Py_DecRef(v_8_9);

    fv_8_10 = nd.semstr;
    v_8_10 = _py_str(fv_8_10);
    PyDict_SetItem(d_h, _mat_keys[13], v_8_10);
    Py_DecRef(v_8_10);

    fv_8_11 = nd.scope_name;
    v_8_11 = _py_str(fv_8_11);
    PyDict_SetItem(d_h, _mat_keys[18], v_8_11);
    Py_DecRef(v_8_11);

    fv_8_12 = nd.parent_scope;
    if fv_8_12 is None {
        v_8_12 = _py_none();
    } else {
        v_8_12 = _emit_node(fv_8_12);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_8_12);
    Py_DecRef(v_8_12);

    fv_8_13 = nd.kid_scope;
    v_8_13 = PyList_New(len(fv_8_13));
    li_8_13l = 0;
    for it_8_13l in fv_8_13 {
        e_8_13l = _emit_node(it_8_13l);
        PyList_SetItem(v_8_13, li_8_13l, e_8_13l);
        li_8_13l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_8_13);
    Py_DecRef(v_8_13);

    fv_8_14 = nd.names_in_scope;
    v_8_14 = PyDict_New();
    for (dk_8_14d, dv_8_14d) in fv_8_14.items() {
        kh_8_14d = _py_str(dk_8_14d);
        vh_8_14d = _emit_Symbol(dv_8_14d);
        PyDict_SetItem(v_8_14, kh_8_14d, vh_8_14d);
        Py_DecRef(kh_8_14d);
        Py_DecRef(vh_8_14d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_8_14);
    Py_DecRef(v_8_14);

    fv_8_15 = nd.names_in_scope_overload;
    v_8_15 = PyDict_New();
    for (dk_8_15d, dv_8_15d) in fv_8_15.items() {
        kh_8_15d = _py_str(dk_8_15d);
        vh_8_15d = PyList_New(len(dv_8_15d));
        li_8_15dl = 0;
        for it_8_15dl in dv_8_15d {
            e_8_15dl = _emit_Symbol(it_8_15dl);
            PyList_SetItem(vh_8_15d, li_8_15dl, e_8_15dl);
            li_8_15dl += 1;
        }
        PyDict_SetItem(v_8_15, kh_8_15d, vh_8_15d);
        Py_DecRef(kh_8_15d);
        Py_DecRef(vh_8_15d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_8_15);
    Py_DecRef(v_8_15);

    fv_8_16 = nd.implicit_rebinds;
    v_8_16 = PyDict_New();
    for (dk_8_16d, dv_8_16d) in fv_8_16.items() {
        kh_8_16d = _py_str(dk_8_16d);
        vh_8_16d = _emit_Symbol(dv_8_16d);
        PyDict_SetItem(v_8_16, kh_8_16d, vh_8_16d);
        Py_DecRef(kh_8_16d);
        Py_DecRef(vh_8_16d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_8_16);
    Py_DecRef(v_8_16);

    fv_8_17 = nd.bb_in;
    v_8_17 = PyList_New(len(fv_8_17));
    li_8_17l = 0;
    for it_8_17l in fv_8_17 {
        e_8_17l = _emit_node(it_8_17l);
        PyList_SetItem(v_8_17, li_8_17l, e_8_17l);
        li_8_17l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_8_17);
    Py_DecRef(v_8_17);

    fv_8_18 = nd.bb_out;
    v_8_18 = PyList_New(len(fv_8_18));
    li_8_18l = 0;
    for it_8_18l in fv_8_18 {
        e_8_18l = _emit_node(it_8_18l);
        PyList_SetItem(v_8_18, li_8_18l, e_8_18l);
        li_8_18l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_8_18);
    Py_DecRef(v_8_18);

    fv_8_19 = nd.affected_symbols;
    v_8_19 = PySet_New(0);
    if len(fv_8_19) != 0 {
        Py_DecRef(v_8_19);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_8_19);
    Py_DecRef(v_8_19);

    fv_8_20 = nd.out_expr;
    v_8_20 = _emit_node(fv_8_20);
    PyDict_SetItem(d_h, _mat_keys[65], v_8_20);
    Py_DecRef(v_8_20);

    fv_8_21 = nd.compr;
    v_8_21 = PyList_New(len(fv_8_21));
    li_8_21l = 0;
    for it_8_21l in fv_8_21 {
        e_8_21l = _emit_node(it_8_21l);
        PyList_SetItem(v_8_21, li_8_21l, e_8_21l);
        li_8_21l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[66], v_8_21);
    Py_DecRef(v_8_21);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ModuleCode(nd: ModuleCode) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[9], _mat_classes[9]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_9_0 = nd.kid;
    v_9_0 = PyList_New(len(fv_9_0));
    li_9_0l = 0;
    for it_9_0l in fv_9_0 {
        e_9_0l = _emit_node(it_9_0l);
        PyList_SetItem(v_9_0, li_9_0l, e_9_0l);
        li_9_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_9_0);
    Py_DecRef(v_9_0);

    fv_9_1 = nd.parent;
    if fv_9_1 is None {
        v_9_1 = _py_none();
    } else {
        v_9_1 = _emit_node(fv_9_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_9_1);
    Py_DecRef(v_9_1);

    v_9_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_9_2);
    Py_DecRef(v_9_2);

    fv_9_3 = nd._in_mod_nodes;
    v_9_3 = PyList_New(len(fv_9_3));
    li_9_3l = 0;
    for it_9_3l in fv_9_3 {
        e_9_3l = _emit_node(it_9_3l);
        PyList_SetItem(v_9_3, li_9_3l, e_9_3l);
        li_9_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_9_3);
    Py_DecRef(v_9_3);

    v_9_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_9_4);
    Py_DecRef(v_9_4);

    fv_9_5 = nd.loc;
    v_9_5 = _emit_CodeLocInfo(fv_9_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_9_5);
    Py_DecRef(v_9_5);

    fv_9_6 = nd.code_context;
    v_9_6 = _enum_CodeContext(fv_9_6);
    PyDict_SetItem(d_h, _mat_keys[6], v_9_6);
    Py_DecRef(v_9_6);

    fv_9_7 = nd.codespace_dual;
    v_9_7 = PyBool_FromLong(1 if fv_9_7 else 0);
    PyDict_SetItem(d_h, _mat_keys[7], v_9_7);
    Py_DecRef(v_9_7);

    fv_9_8 = nd.doc;
    if fv_9_8 is None {
        v_9_8 = _py_none();
    } else {
        v_9_8 = _emit_node(fv_9_8);
    }
    PyDict_SetItem(d_h, _mat_keys[8], v_9_8);
    Py_DecRef(v_9_8);

    fv_9_9 = nd.is_enum_stmt;
    v_9_9 = PyBool_FromLong(1 if fv_9_9 else 0);
    PyDict_SetItem(d_h, _mat_keys[53], v_9_9);
    Py_DecRef(v_9_9);

    fv_9_10 = nd.bb_in;
    v_9_10 = PyList_New(len(fv_9_10));
    li_9_10l = 0;
    for it_9_10l in fv_9_10 {
        e_9_10l = _emit_node(it_9_10l);
        PyList_SetItem(v_9_10, li_9_10l, e_9_10l);
        li_9_10l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_9_10);
    Py_DecRef(v_9_10);

    fv_9_11 = nd.bb_out;
    v_9_11 = PyList_New(len(fv_9_11));
    li_9_11l = 0;
    for it_9_11l in fv_9_11 {
        e_9_11l = _emit_node(it_9_11l);
        PyList_SetItem(v_9_11, li_9_11l, e_9_11l);
        li_9_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_9_11);
    Py_DecRef(v_9_11);

    fv_9_12 = nd.affected_symbols;
    v_9_12 = PySet_New(0);
    if len(fv_9_12) != 0 {
        Py_DecRef(v_9_12);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_9_12);
    Py_DecRef(v_9_12);

    fv_9_13 = nd.name;
    if fv_9_13 is None {
        v_9_13 = _py_none();
    } else {
        v_9_13 = _emit_node(fv_9_13);
    }
    PyDict_SetItem(d_h, _mat_keys[24], v_9_13);
    Py_DecRef(v_9_13);

    fv_9_14 = nd.body;
    v_9_14 = PyList_New(len(fv_9_14));
    li_9_14l = 0;
    for it_9_14l in fv_9_14 {
        e_9_14l = _emit_node(it_9_14l);
        PyList_SetItem(v_9_14, li_9_14l, e_9_14l);
        li_9_14l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_9_14);
    Py_DecRef(v_9_14);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_SetCompr(nd: SetCompr) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[10], _mat_classes[10]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_10_0 = nd.kid;
    v_10_0 = PyList_New(len(fv_10_0));
    li_10_0l = 0;
    for it_10_0l in fv_10_0 {
        e_10_0l = _emit_node(it_10_0l);
        PyList_SetItem(v_10_0, li_10_0l, e_10_0l);
        li_10_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_10_0);
    Py_DecRef(v_10_0);

    fv_10_1 = nd.parent;
    if fv_10_1 is None {
        v_10_1 = _py_none();
    } else {
        v_10_1 = _emit_node(fv_10_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_10_1);
    Py_DecRef(v_10_1);

    v_10_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_10_2);
    Py_DecRef(v_10_2);

    fv_10_3 = nd._in_mod_nodes;
    v_10_3 = PyList_New(len(fv_10_3));
    li_10_3l = 0;
    for it_10_3l in fv_10_3 {
        e_10_3l = _emit_node(it_10_3l);
        PyList_SetItem(v_10_3, li_10_3l, e_10_3l);
        li_10_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_10_3);
    Py_DecRef(v_10_3);

    v_10_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_10_4);
    Py_DecRef(v_10_4);

    fv_10_5 = nd.loc;
    v_10_5 = _emit_CodeLocInfo(fv_10_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_10_5);
    Py_DecRef(v_10_5);

    fv_10_6 = nd._type_sym_tab;
    if fv_10_6 is None {
        v_10_6 = _py_none();
    } else {
        v_10_6 = _emit_node(fv_10_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_10_6);
    Py_DecRef(v_10_6);

    v_10_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_10_7);
    Py_DecRef(v_10_7);

    fv_10_8 = nd.attached_tokens;
    if fv_10_8 is None {
        v_10_8 = _py_none();
    } else {
        v_10_8 = PyList_New(len(fv_10_8));
        li_10_8l = 0;
        for it_10_8l in fv_10_8 {
            e_10_8l = _emit_node(it_10_8l);
            PyList_SetItem(v_10_8, li_10_8l, e_10_8l);
            li_10_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_10_8);
    Py_DecRef(v_10_8);

    fv_10_9 = nd.name_spec;
    v_10_9 = _emit_node(fv_10_9);
    PyDict_SetItem(d_h, _mat_keys[12], v_10_9);
    Py_DecRef(v_10_9);

    fv_10_10 = nd.semstr;
    v_10_10 = _py_str(fv_10_10);
    PyDict_SetItem(d_h, _mat_keys[13], v_10_10);
    Py_DecRef(v_10_10);

    fv_10_11 = nd.scope_name;
    v_10_11 = _py_str(fv_10_11);
    PyDict_SetItem(d_h, _mat_keys[18], v_10_11);
    Py_DecRef(v_10_11);

    fv_10_12 = nd.parent_scope;
    if fv_10_12 is None {
        v_10_12 = _py_none();
    } else {
        v_10_12 = _emit_node(fv_10_12);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_10_12);
    Py_DecRef(v_10_12);

    fv_10_13 = nd.kid_scope;
    v_10_13 = PyList_New(len(fv_10_13));
    li_10_13l = 0;
    for it_10_13l in fv_10_13 {
        e_10_13l = _emit_node(it_10_13l);
        PyList_SetItem(v_10_13, li_10_13l, e_10_13l);
        li_10_13l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_10_13);
    Py_DecRef(v_10_13);

    fv_10_14 = nd.names_in_scope;
    v_10_14 = PyDict_New();
    for (dk_10_14d, dv_10_14d) in fv_10_14.items() {
        kh_10_14d = _py_str(dk_10_14d);
        vh_10_14d = _emit_Symbol(dv_10_14d);
        PyDict_SetItem(v_10_14, kh_10_14d, vh_10_14d);
        Py_DecRef(kh_10_14d);
        Py_DecRef(vh_10_14d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_10_14);
    Py_DecRef(v_10_14);

    fv_10_15 = nd.names_in_scope_overload;
    v_10_15 = PyDict_New();
    for (dk_10_15d, dv_10_15d) in fv_10_15.items() {
        kh_10_15d = _py_str(dk_10_15d);
        vh_10_15d = PyList_New(len(dv_10_15d));
        li_10_15dl = 0;
        for it_10_15dl in dv_10_15d {
            e_10_15dl = _emit_Symbol(it_10_15dl);
            PyList_SetItem(vh_10_15d, li_10_15dl, e_10_15dl);
            li_10_15dl += 1;
        }
        PyDict_SetItem(v_10_15, kh_10_15d, vh_10_15d);
        Py_DecRef(kh_10_15d);
        Py_DecRef(vh_10_15d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_10_15);
    Py_DecRef(v_10_15);

    fv_10_16 = nd.implicit_rebinds;
    v_10_16 = PyDict_New();
    for (dk_10_16d, dv_10_16d) in fv_10_16.items() {
        kh_10_16d = _py_str(dk_10_16d);
        vh_10_16d = _emit_Symbol(dv_10_16d);
        PyDict_SetItem(v_10_16, kh_10_16d, vh_10_16d);
        Py_DecRef(kh_10_16d);
        Py_DecRef(vh_10_16d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_10_16);
    Py_DecRef(v_10_16);

    fv_10_17 = nd.bb_in;
    v_10_17 = PyList_New(len(fv_10_17));
    li_10_17l = 0;
    for it_10_17l in fv_10_17 {
        e_10_17l = _emit_node(it_10_17l);
        PyList_SetItem(v_10_17, li_10_17l, e_10_17l);
        li_10_17l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_10_17);
    Py_DecRef(v_10_17);

    fv_10_18 = nd.bb_out;
    v_10_18 = PyList_New(len(fv_10_18));
    li_10_18l = 0;
    for it_10_18l in fv_10_18 {
        e_10_18l = _emit_node(it_10_18l);
        PyList_SetItem(v_10_18, li_10_18l, e_10_18l);
        li_10_18l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_10_18);
    Py_DecRef(v_10_18);

    fv_10_19 = nd.affected_symbols;
    v_10_19 = PySet_New(0);
    if len(fv_10_19) != 0 {
        Py_DecRef(v_10_19);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_10_19);
    Py_DecRef(v_10_19);

    fv_10_20 = nd.out_expr;
    v_10_20 = _emit_node(fv_10_20);
    PyDict_SetItem(d_h, _mat_keys[65], v_10_20);
    Py_DecRef(v_10_20);

    fv_10_21 = nd.compr;
    v_10_21 = PyList_New(len(fv_10_21));
    li_10_21l = 0;
    for it_10_21l in fv_10_21 {
        e_10_21l = _emit_node(it_10_21l);
        PyList_SetItem(v_10_21, li_10_21l, e_10_21l);
        li_10_21l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[66], v_10_21);
    Py_DecRef(v_10_21);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_Test(nd: Test) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[11], _mat_classes[11]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_11_0 = nd.kid;
    v_11_0 = PyList_New(len(fv_11_0));
    li_11_0l = 0;
    for it_11_0l in fv_11_0 {
        e_11_0l = _emit_node(it_11_0l);
        PyList_SetItem(v_11_0, li_11_0l, e_11_0l);
        li_11_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_11_0);
    Py_DecRef(v_11_0);

    fv_11_1 = nd.parent;
    if fv_11_1 is None {
        v_11_1 = _py_none();
    } else {
        v_11_1 = _emit_node(fv_11_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_11_1);
    Py_DecRef(v_11_1);

    v_11_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_11_2);
    Py_DecRef(v_11_2);

    fv_11_3 = nd._in_mod_nodes;
    v_11_3 = PyList_New(len(fv_11_3));
    li_11_3l = 0;
    for it_11_3l in fv_11_3 {
        e_11_3l = _emit_node(it_11_3l);
        PyList_SetItem(v_11_3, li_11_3l, e_11_3l);
        li_11_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_11_3);
    Py_DecRef(v_11_3);

    v_11_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_11_4);
    Py_DecRef(v_11_4);

    fv_11_5 = nd.loc;
    v_11_5 = _emit_CodeLocInfo(fv_11_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_11_5);
    Py_DecRef(v_11_5);

    fv_11_6 = nd.code_context;
    v_11_6 = _enum_CodeContext(fv_11_6);
    PyDict_SetItem(d_h, _mat_keys[6], v_11_6);
    Py_DecRef(v_11_6);

    fv_11_7 = nd.codespace_dual;
    v_11_7 = PyBool_FromLong(1 if fv_11_7 else 0);
    PyDict_SetItem(d_h, _mat_keys[7], v_11_7);
    Py_DecRef(v_11_7);

    fv_11_8 = nd.name_spec;
    v_11_8 = _emit_node(fv_11_8);
    PyDict_SetItem(d_h, _mat_keys[12], v_11_8);
    Py_DecRef(v_11_8);

    fv_11_9 = nd.semstr;
    v_11_9 = _py_str(fv_11_9);
    PyDict_SetItem(d_h, _mat_keys[13], v_11_9);
    Py_DecRef(v_11_9);

    fv_11_10 = nd.doc;
    if fv_11_10 is None {
        v_11_10 = _py_none();
    } else {
        v_11_10 = _emit_node(fv_11_10);
    }
    PyDict_SetItem(d_h, _mat_keys[8], v_11_10);
    Py_DecRef(v_11_10);

    fv_11_11 = nd.bb_in;
    v_11_11 = PyList_New(len(fv_11_11));
    li_11_11l = 0;
    for it_11_11l in fv_11_11 {
        e_11_11l = _emit_node(it_11_11l);
        PyList_SetItem(v_11_11, li_11_11l, e_11_11l);
        li_11_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_11_11);
    Py_DecRef(v_11_11);

    fv_11_12 = nd.bb_out;
    v_11_12 = PyList_New(len(fv_11_12));
    li_11_12l = 0;
    for it_11_12l in fv_11_12 {
        e_11_12l = _emit_node(it_11_12l);
        PyList_SetItem(v_11_12, li_11_12l, e_11_12l);
        li_11_12l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_11_12);
    Py_DecRef(v_11_12);

    fv_11_13 = nd.affected_symbols;
    v_11_13 = PySet_New(0);
    if len(fv_11_13) != 0 {
        Py_DecRef(v_11_13);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_11_13);
    Py_DecRef(v_11_13);

    fv_11_14 = nd.scope_name;
    v_11_14 = _py_str(fv_11_14);
    PyDict_SetItem(d_h, _mat_keys[18], v_11_14);
    Py_DecRef(v_11_14);

    fv_11_15 = nd.parent_scope;
    if fv_11_15 is None {
        v_11_15 = _py_none();
    } else {
        v_11_15 = _emit_node(fv_11_15);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_11_15);
    Py_DecRef(v_11_15);

    fv_11_16 = nd.kid_scope;
    v_11_16 = PyList_New(len(fv_11_16));
    li_11_16l = 0;
    for it_11_16l in fv_11_16 {
        e_11_16l = _emit_node(it_11_16l);
        PyList_SetItem(v_11_16, li_11_16l, e_11_16l);
        li_11_16l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_11_16);
    Py_DecRef(v_11_16);

    fv_11_17 = nd.names_in_scope;
    v_11_17 = PyDict_New();
    for (dk_11_17d, dv_11_17d) in fv_11_17.items() {
        kh_11_17d = _py_str(dk_11_17d);
        vh_11_17d = _emit_Symbol(dv_11_17d);
        PyDict_SetItem(v_11_17, kh_11_17d, vh_11_17d);
        Py_DecRef(kh_11_17d);
        Py_DecRef(vh_11_17d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_11_17);
    Py_DecRef(v_11_17);

    fv_11_18 = nd.names_in_scope_overload;
    v_11_18 = PyDict_New();
    for (dk_11_18d, dv_11_18d) in fv_11_18.items() {
        kh_11_18d = _py_str(dk_11_18d);
        vh_11_18d = PyList_New(len(dv_11_18d));
        li_11_18dl = 0;
        for it_11_18dl in dv_11_18d {
            e_11_18dl = _emit_Symbol(it_11_18dl);
            PyList_SetItem(vh_11_18d, li_11_18dl, e_11_18dl);
            li_11_18dl += 1;
        }
        PyDict_SetItem(v_11_18, kh_11_18d, vh_11_18d);
        Py_DecRef(kh_11_18d);
        Py_DecRef(vh_11_18d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_11_18);
    Py_DecRef(v_11_18);

    fv_11_19 = nd.implicit_rebinds;
    v_11_19 = PyDict_New();
    for (dk_11_19d, dv_11_19d) in fv_11_19.items() {
        kh_11_19d = _py_str(dk_11_19d);
        vh_11_19d = _emit_Symbol(dv_11_19d);
        PyDict_SetItem(v_11_19, kh_11_19d, vh_11_19d);
        Py_DecRef(kh_11_19d);
        Py_DecRef(vh_11_19d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_11_19);
    Py_DecRef(v_11_19);

    fv_11_20 = nd.name;
    if isinstance(fv_11_20, Name) {
        v_11_20 = _emit_node(fv_11_20);
    } elif isinstance(fv_11_20, Token) {
        v_11_20 = _emit_node(fv_11_20);
    } else {
        v_11_20 = _py_none();
    }
    PyDict_SetItem(d_h, _mat_keys[24], v_11_20);
    Py_DecRef(v_11_20);

    fv_11_21 = nd.body;
    v_11_21 = PyList_New(len(fv_11_21));
    li_11_21l = 0;
    for it_11_21l in fv_11_21 {
        e_11_21l = _emit_node(it_11_21l);
        PyList_SetItem(v_11_21, li_11_21l, e_11_21l);
        li_11_21l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_11_21);
    Py_DecRef(v_11_21);

    fv_11_22 = nd.description;
    if fv_11_22 is None {
        v_11_22 = _py_none();
    } else {
        v_11_22 = _emit_node(fv_11_22);
    }
    PyDict_SetItem(d_h, _mat_keys[67], v_11_22);
    Py_DecRef(v_11_22);

    fv_11_23 = nd.decorators;
    if fv_11_23 is None {
        v_11_23 = _py_none();
    } else {
        v_11_23 = PyList_New(len(fv_11_23));
        li_11_23l = 0;
        for it_11_23l in fv_11_23 {
            e_11_23l = _emit_node(it_11_23l);
            PyList_SetItem(v_11_23, li_11_23l, e_11_23l);
            li_11_23l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[15], v_11_23);
    Py_DecRef(v_11_23);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_String(nd: String) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[12], _mat_classes[12]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_12_0 = nd.kid;
    v_12_0 = PyList_New(len(fv_12_0));
    li_12_0l = 0;
    for it_12_0l in fv_12_0 {
        e_12_0l = _emit_node(it_12_0l);
        PyList_SetItem(v_12_0, li_12_0l, e_12_0l);
        li_12_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_12_0);
    Py_DecRef(v_12_0);

    fv_12_1 = nd.parent;
    if fv_12_1 is None {
        v_12_1 = _py_none();
    } else {
        v_12_1 = _emit_node(fv_12_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_12_1);
    Py_DecRef(v_12_1);

    v_12_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_12_2);
    Py_DecRef(v_12_2);

    fv_12_3 = nd._in_mod_nodes;
    v_12_3 = PyList_New(len(fv_12_3));
    li_12_3l = 0;
    for it_12_3l in fv_12_3 {
        e_12_3l = _emit_node(it_12_3l);
        PyList_SetItem(v_12_3, li_12_3l, e_12_3l);
        li_12_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_12_3);
    Py_DecRef(v_12_3);

    v_12_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_12_4);
    Py_DecRef(v_12_4);

    fv_12_5 = nd.loc;
    v_12_5 = _emit_CodeLocInfo(fv_12_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_12_5);
    Py_DecRef(v_12_5);

    fv_12_6 = nd.orig_src;
    v_12_6 = _emit_node(fv_12_6);
    PyDict_SetItem(d_h, _mat_keys[41], v_12_6);
    Py_DecRef(v_12_6);

    fv_12_7 = nd.name;
    v_12_7 = _py_str(fv_12_7);
    PyDict_SetItem(d_h, _mat_keys[24], v_12_7);
    Py_DecRef(v_12_7);

    fv_12_8 = nd.value;
    v_12_8 = _py_str(fv_12_8);
    PyDict_SetItem(d_h, _mat_keys[42], v_12_8);
    Py_DecRef(v_12_8);

    fv_12_9 = nd.line_no;
    v_12_9 = PyLong_FromLongLong(fv_12_9);
    PyDict_SetItem(d_h, _mat_keys[43], v_12_9);
    Py_DecRef(v_12_9);

    fv_12_10 = nd.end_line;
    v_12_10 = PyLong_FromLongLong(fv_12_10);
    PyDict_SetItem(d_h, _mat_keys[44], v_12_10);
    Py_DecRef(v_12_10);

    fv_12_11 = nd.c_start;
    v_12_11 = PyLong_FromLongLong(fv_12_11);
    PyDict_SetItem(d_h, _mat_keys[45], v_12_11);
    Py_DecRef(v_12_11);

    fv_12_12 = nd.c_end;
    v_12_12 = PyLong_FromLongLong(fv_12_12);
    PyDict_SetItem(d_h, _mat_keys[46], v_12_12);
    Py_DecRef(v_12_12);

    fv_12_13 = nd.pos_start;
    v_12_13 = PyLong_FromLongLong(fv_12_13);
    PyDict_SetItem(d_h, _mat_keys[47], v_12_13);
    Py_DecRef(v_12_13);

    fv_12_14 = nd.pos_end;
    v_12_14 = PyLong_FromLongLong(fv_12_14);
    PyDict_SetItem(d_h, _mat_keys[48], v_12_14);
    Py_DecRef(v_12_14);

    fv_12_15 = nd._is_synthetic;
    v_12_15 = PyBool_FromLong(1 if fv_12_15 else 0);
    PyDict_SetItem(d_h, _mat_keys[49], v_12_15);
    Py_DecRef(v_12_15);

    fv_12_16 = nd._type_sym_tab;
    if fv_12_16 is None {
        v_12_16 = _py_none();
    } else {
        v_12_16 = _emit_node(fv_12_16);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_12_16);
    Py_DecRef(v_12_16);

    v_12_17 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_12_17);
    Py_DecRef(v_12_17);

    fv_12_18 = nd.attached_tokens;
    if fv_12_18 is None {
        v_12_18 = _py_none();
    } else {
        v_12_18 = PyList_New(len(fv_12_18));
        li_12_18l = 0;
        for it_12_18l in fv_12_18 {
            e_12_18l = _emit_node(it_12_18l);
            PyList_SetItem(v_12_18, li_12_18l, e_12_18l);
            li_12_18l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_12_18);
    Py_DecRef(v_12_18);

    fv_12_19 = nd.name_spec;
    v_12_19 = _emit_node(fv_12_19);
    PyDict_SetItem(d_h, _mat_keys[12], v_12_19);
    Py_DecRef(v_12_19);

    fv_12_20 = nd.semstr;
    v_12_20 = _py_str(fv_12_20);
    PyDict_SetItem(d_h, _mat_keys[13], v_12_20);
    Py_DecRef(v_12_20);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_Int(nd: Int) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[13], _mat_classes[13]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_13_0 = nd.kid;
    v_13_0 = PyList_New(len(fv_13_0));
    li_13_0l = 0;
    for it_13_0l in fv_13_0 {
        e_13_0l = _emit_node(it_13_0l);
        PyList_SetItem(v_13_0, li_13_0l, e_13_0l);
        li_13_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_13_0);
    Py_DecRef(v_13_0);

    fv_13_1 = nd.parent;
    if fv_13_1 is None {
        v_13_1 = _py_none();
    } else {
        v_13_1 = _emit_node(fv_13_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_13_1);
    Py_DecRef(v_13_1);

    v_13_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_13_2);
    Py_DecRef(v_13_2);

    fv_13_3 = nd._in_mod_nodes;
    v_13_3 = PyList_New(len(fv_13_3));
    li_13_3l = 0;
    for it_13_3l in fv_13_3 {
        e_13_3l = _emit_node(it_13_3l);
        PyList_SetItem(v_13_3, li_13_3l, e_13_3l);
        li_13_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_13_3);
    Py_DecRef(v_13_3);

    v_13_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_13_4);
    Py_DecRef(v_13_4);

    fv_13_5 = nd.loc;
    v_13_5 = _emit_CodeLocInfo(fv_13_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_13_5);
    Py_DecRef(v_13_5);

    fv_13_6 = nd.orig_src;
    v_13_6 = _emit_node(fv_13_6);
    PyDict_SetItem(d_h, _mat_keys[41], v_13_6);
    Py_DecRef(v_13_6);

    fv_13_7 = nd.name;
    v_13_7 = _py_str(fv_13_7);
    PyDict_SetItem(d_h, _mat_keys[24], v_13_7);
    Py_DecRef(v_13_7);

    fv_13_8 = nd.value;
    v_13_8 = _py_str(fv_13_8);
    PyDict_SetItem(d_h, _mat_keys[42], v_13_8);
    Py_DecRef(v_13_8);

    fv_13_9 = nd.line_no;
    v_13_9 = PyLong_FromLongLong(fv_13_9);
    PyDict_SetItem(d_h, _mat_keys[43], v_13_9);
    Py_DecRef(v_13_9);

    fv_13_10 = nd.end_line;
    v_13_10 = PyLong_FromLongLong(fv_13_10);
    PyDict_SetItem(d_h, _mat_keys[44], v_13_10);
    Py_DecRef(v_13_10);

    fv_13_11 = nd.c_start;
    v_13_11 = PyLong_FromLongLong(fv_13_11);
    PyDict_SetItem(d_h, _mat_keys[45], v_13_11);
    Py_DecRef(v_13_11);

    fv_13_12 = nd.c_end;
    v_13_12 = PyLong_FromLongLong(fv_13_12);
    PyDict_SetItem(d_h, _mat_keys[46], v_13_12);
    Py_DecRef(v_13_12);

    fv_13_13 = nd.pos_start;
    v_13_13 = PyLong_FromLongLong(fv_13_13);
    PyDict_SetItem(d_h, _mat_keys[47], v_13_13);
    Py_DecRef(v_13_13);

    fv_13_14 = nd.pos_end;
    v_13_14 = PyLong_FromLongLong(fv_13_14);
    PyDict_SetItem(d_h, _mat_keys[48], v_13_14);
    Py_DecRef(v_13_14);

    fv_13_15 = nd._is_synthetic;
    v_13_15 = PyBool_FromLong(1 if fv_13_15 else 0);
    PyDict_SetItem(d_h, _mat_keys[49], v_13_15);
    Py_DecRef(v_13_15);

    fv_13_16 = nd._type_sym_tab;
    if fv_13_16 is None {
        v_13_16 = _py_none();
    } else {
        v_13_16 = _emit_node(fv_13_16);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_13_16);
    Py_DecRef(v_13_16);

    v_13_17 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_13_17);
    Py_DecRef(v_13_17);

    fv_13_18 = nd.attached_tokens;
    if fv_13_18 is None {
        v_13_18 = _py_none();
    } else {
        v_13_18 = PyList_New(len(fv_13_18));
        li_13_18l = 0;
        for it_13_18l in fv_13_18 {
            e_13_18l = _emit_node(it_13_18l);
            PyList_SetItem(v_13_18, li_13_18l, e_13_18l);
            li_13_18l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_13_18);
    Py_DecRef(v_13_18);

    fv_13_19 = nd.name_spec;
    v_13_19 = _emit_node(fv_13_19);
    PyDict_SetItem(d_h, _mat_keys[12], v_13_19);
    Py_DecRef(v_13_19);

    fv_13_20 = nd.semstr;
    v_13_20 = _py_str(fv_13_20);
    PyDict_SetItem(d_h, _mat_keys[13], v_13_20);
    Py_DecRef(v_13_20);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ArchSpec(nd: ArchSpec) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[14], _mat_classes[14]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_14_0 = nd.kid;
    v_14_0 = PyList_New(len(fv_14_0));
    li_14_0l = 0;
    for it_14_0l in fv_14_0 {
        e_14_0l = _emit_node(it_14_0l);
        PyList_SetItem(v_14_0, li_14_0l, e_14_0l);
        li_14_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_14_0);
    Py_DecRef(v_14_0);

    fv_14_1 = nd.parent;
    if fv_14_1 is None {
        v_14_1 = _py_none();
    } else {
        v_14_1 = _emit_node(fv_14_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_14_1);
    Py_DecRef(v_14_1);

    v_14_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_14_2);
    Py_DecRef(v_14_2);

    fv_14_3 = nd._in_mod_nodes;
    v_14_3 = PyList_New(len(fv_14_3));
    li_14_3l = 0;
    for it_14_3l in fv_14_3 {
        e_14_3l = _emit_node(it_14_3l);
        PyList_SetItem(v_14_3, li_14_3l, e_14_3l);
        li_14_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_14_3);
    Py_DecRef(v_14_3);

    v_14_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_14_4);
    Py_DecRef(v_14_4);

    fv_14_5 = nd.loc;
    v_14_5 = _emit_CodeLocInfo(fv_14_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_14_5);
    Py_DecRef(v_14_5);

    fv_14_6 = nd.doc;
    if fv_14_6 is None {
        v_14_6 = _py_none();
    } else {
        v_14_6 = _emit_node(fv_14_6);
    }
    PyDict_SetItem(d_h, _mat_keys[8], v_14_6);
    Py_DecRef(v_14_6);

    fv_14_7 = nd.bb_in;
    v_14_7 = PyList_New(len(fv_14_7));
    li_14_7l = 0;
    for it_14_7l in fv_14_7 {
        e_14_7l = _emit_node(it_14_7l);
        PyList_SetItem(v_14_7, li_14_7l, e_14_7l);
        li_14_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_14_7);
    Py_DecRef(v_14_7);

    fv_14_8 = nd.bb_out;
    v_14_8 = PyList_New(len(fv_14_8));
    li_14_8l = 0;
    for it_14_8l in fv_14_8 {
        e_14_8l = _emit_node(it_14_8l);
        PyList_SetItem(v_14_8, li_14_8l, e_14_8l);
        li_14_8l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_14_8);
    Py_DecRef(v_14_8);

    fv_14_9 = nd.affected_symbols;
    v_14_9 = PySet_New(0);
    if len(fv_14_9) != 0 {
        Py_DecRef(v_14_9);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_14_9);
    Py_DecRef(v_14_9);

    fv_14_10 = nd.name_spec;
    v_14_10 = _emit_node(fv_14_10);
    PyDict_SetItem(d_h, _mat_keys[12], v_14_10);
    Py_DecRef(v_14_10);

    fv_14_11 = nd.semstr;
    v_14_11 = _py_str(fv_14_11);
    PyDict_SetItem(d_h, _mat_keys[13], v_14_11);
    Py_DecRef(v_14_11);

    fv_14_12 = nd.is_async;
    v_14_12 = PyBool_FromLong(1 if fv_14_12 else 0);
    PyDict_SetItem(d_h, _mat_keys[14], v_14_12);
    Py_DecRef(v_14_12);

    fv_14_13 = nd.decorators;
    if fv_14_13 is None {
        v_14_13 = _py_none();
    } else {
        v_14_13 = PyList_New(len(fv_14_13));
        li_14_13l = 0;
        for it_14_13l in fv_14_13 {
            e_14_13l = _emit_node(it_14_13l);
            PyList_SetItem(v_14_13, li_14_13l, e_14_13l);
            li_14_13l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[15], v_14_13);
    Py_DecRef(v_14_13);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_Bool(nd: Bool) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[15], _mat_classes[15]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_15_0 = nd.kid;
    v_15_0 = PyList_New(len(fv_15_0));
    li_15_0l = 0;
    for it_15_0l in fv_15_0 {
        e_15_0l = _emit_node(it_15_0l);
        PyList_SetItem(v_15_0, li_15_0l, e_15_0l);
        li_15_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_15_0);
    Py_DecRef(v_15_0);

    fv_15_1 = nd.parent;
    if fv_15_1 is None {
        v_15_1 = _py_none();
    } else {
        v_15_1 = _emit_node(fv_15_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_15_1);
    Py_DecRef(v_15_1);

    v_15_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_15_2);
    Py_DecRef(v_15_2);

    fv_15_3 = nd._in_mod_nodes;
    v_15_3 = PyList_New(len(fv_15_3));
    li_15_3l = 0;
    for it_15_3l in fv_15_3 {
        e_15_3l = _emit_node(it_15_3l);
        PyList_SetItem(v_15_3, li_15_3l, e_15_3l);
        li_15_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_15_3);
    Py_DecRef(v_15_3);

    v_15_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_15_4);
    Py_DecRef(v_15_4);

    fv_15_5 = nd.loc;
    v_15_5 = _emit_CodeLocInfo(fv_15_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_15_5);
    Py_DecRef(v_15_5);

    fv_15_6 = nd.orig_src;
    v_15_6 = _emit_node(fv_15_6);
    PyDict_SetItem(d_h, _mat_keys[41], v_15_6);
    Py_DecRef(v_15_6);

    fv_15_7 = nd.name;
    v_15_7 = _py_str(fv_15_7);
    PyDict_SetItem(d_h, _mat_keys[24], v_15_7);
    Py_DecRef(v_15_7);

    fv_15_8 = nd.value;
    v_15_8 = _py_str(fv_15_8);
    PyDict_SetItem(d_h, _mat_keys[42], v_15_8);
    Py_DecRef(v_15_8);

    fv_15_9 = nd.line_no;
    v_15_9 = PyLong_FromLongLong(fv_15_9);
    PyDict_SetItem(d_h, _mat_keys[43], v_15_9);
    Py_DecRef(v_15_9);

    fv_15_10 = nd.end_line;
    v_15_10 = PyLong_FromLongLong(fv_15_10);
    PyDict_SetItem(d_h, _mat_keys[44], v_15_10);
    Py_DecRef(v_15_10);

    fv_15_11 = nd.c_start;
    v_15_11 = PyLong_FromLongLong(fv_15_11);
    PyDict_SetItem(d_h, _mat_keys[45], v_15_11);
    Py_DecRef(v_15_11);

    fv_15_12 = nd.c_end;
    v_15_12 = PyLong_FromLongLong(fv_15_12);
    PyDict_SetItem(d_h, _mat_keys[46], v_15_12);
    Py_DecRef(v_15_12);

    fv_15_13 = nd.pos_start;
    v_15_13 = PyLong_FromLongLong(fv_15_13);
    PyDict_SetItem(d_h, _mat_keys[47], v_15_13);
    Py_DecRef(v_15_13);

    fv_15_14 = nd.pos_end;
    v_15_14 = PyLong_FromLongLong(fv_15_14);
    PyDict_SetItem(d_h, _mat_keys[48], v_15_14);
    Py_DecRef(v_15_14);

    fv_15_15 = nd._is_synthetic;
    v_15_15 = PyBool_FromLong(1 if fv_15_15 else 0);
    PyDict_SetItem(d_h, _mat_keys[49], v_15_15);
    Py_DecRef(v_15_15);

    fv_15_16 = nd._type_sym_tab;
    if fv_15_16 is None {
        v_15_16 = _py_none();
    } else {
        v_15_16 = _emit_node(fv_15_16);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_15_16);
    Py_DecRef(v_15_16);

    v_15_17 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_15_17);
    Py_DecRef(v_15_17);

    fv_15_18 = nd.attached_tokens;
    if fv_15_18 is None {
        v_15_18 = _py_none();
    } else {
        v_15_18 = PyList_New(len(fv_15_18));
        li_15_18l = 0;
        for it_15_18l in fv_15_18 {
            e_15_18l = _emit_node(it_15_18l);
            PyList_SetItem(v_15_18, li_15_18l, e_15_18l);
            li_15_18l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_15_18);
    Py_DecRef(v_15_18);

    fv_15_19 = nd.name_spec;
    v_15_19 = _emit_node(fv_15_19);
    PyDict_SetItem(d_h, _mat_keys[12], v_15_19);
    Py_DecRef(v_15_19);

    fv_15_20 = nd.semstr;
    v_15_20 = _py_str(fv_15_20);
    PyDict_SetItem(d_h, _mat_keys[13], v_15_20);
    Py_DecRef(v_15_20);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_DictCompr(nd: DictCompr) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[16], _mat_classes[16]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_16_0 = nd.kid;
    v_16_0 = PyList_New(len(fv_16_0));
    li_16_0l = 0;
    for it_16_0l in fv_16_0 {
        e_16_0l = _emit_node(it_16_0l);
        PyList_SetItem(v_16_0, li_16_0l, e_16_0l);
        li_16_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_16_0);
    Py_DecRef(v_16_0);

    fv_16_1 = nd.parent;
    if fv_16_1 is None {
        v_16_1 = _py_none();
    } else {
        v_16_1 = _emit_node(fv_16_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_16_1);
    Py_DecRef(v_16_1);

    v_16_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_16_2);
    Py_DecRef(v_16_2);

    fv_16_3 = nd._in_mod_nodes;
    v_16_3 = PyList_New(len(fv_16_3));
    li_16_3l = 0;
    for it_16_3l in fv_16_3 {
        e_16_3l = _emit_node(it_16_3l);
        PyList_SetItem(v_16_3, li_16_3l, e_16_3l);
        li_16_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_16_3);
    Py_DecRef(v_16_3);

    v_16_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_16_4);
    Py_DecRef(v_16_4);

    fv_16_5 = nd.loc;
    v_16_5 = _emit_CodeLocInfo(fv_16_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_16_5);
    Py_DecRef(v_16_5);

    fv_16_6 = nd._type_sym_tab;
    if fv_16_6 is None {
        v_16_6 = _py_none();
    } else {
        v_16_6 = _emit_node(fv_16_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_16_6);
    Py_DecRef(v_16_6);

    v_16_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_16_7);
    Py_DecRef(v_16_7);

    fv_16_8 = nd.attached_tokens;
    if fv_16_8 is None {
        v_16_8 = _py_none();
    } else {
        v_16_8 = PyList_New(len(fv_16_8));
        li_16_8l = 0;
        for it_16_8l in fv_16_8 {
            e_16_8l = _emit_node(it_16_8l);
            PyList_SetItem(v_16_8, li_16_8l, e_16_8l);
            li_16_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_16_8);
    Py_DecRef(v_16_8);

    fv_16_9 = nd.name_spec;
    v_16_9 = _emit_node(fv_16_9);
    PyDict_SetItem(d_h, _mat_keys[12], v_16_9);
    Py_DecRef(v_16_9);

    fv_16_10 = nd.semstr;
    v_16_10 = _py_str(fv_16_10);
    PyDict_SetItem(d_h, _mat_keys[13], v_16_10);
    Py_DecRef(v_16_10);

    fv_16_11 = nd.scope_name;
    v_16_11 = _py_str(fv_16_11);
    PyDict_SetItem(d_h, _mat_keys[18], v_16_11);
    Py_DecRef(v_16_11);

    fv_16_12 = nd.parent_scope;
    if fv_16_12 is None {
        v_16_12 = _py_none();
    } else {
        v_16_12 = _emit_node(fv_16_12);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_16_12);
    Py_DecRef(v_16_12);

    fv_16_13 = nd.kid_scope;
    v_16_13 = PyList_New(len(fv_16_13));
    li_16_13l = 0;
    for it_16_13l in fv_16_13 {
        e_16_13l = _emit_node(it_16_13l);
        PyList_SetItem(v_16_13, li_16_13l, e_16_13l);
        li_16_13l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_16_13);
    Py_DecRef(v_16_13);

    fv_16_14 = nd.names_in_scope;
    v_16_14 = PyDict_New();
    for (dk_16_14d, dv_16_14d) in fv_16_14.items() {
        kh_16_14d = _py_str(dk_16_14d);
        vh_16_14d = _emit_Symbol(dv_16_14d);
        PyDict_SetItem(v_16_14, kh_16_14d, vh_16_14d);
        Py_DecRef(kh_16_14d);
        Py_DecRef(vh_16_14d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_16_14);
    Py_DecRef(v_16_14);

    fv_16_15 = nd.names_in_scope_overload;
    v_16_15 = PyDict_New();
    for (dk_16_15d, dv_16_15d) in fv_16_15.items() {
        kh_16_15d = _py_str(dk_16_15d);
        vh_16_15d = PyList_New(len(dv_16_15d));
        li_16_15dl = 0;
        for it_16_15dl in dv_16_15d {
            e_16_15dl = _emit_Symbol(it_16_15dl);
            PyList_SetItem(vh_16_15d, li_16_15dl, e_16_15dl);
            li_16_15dl += 1;
        }
        PyDict_SetItem(v_16_15, kh_16_15d, vh_16_15d);
        Py_DecRef(kh_16_15d);
        Py_DecRef(vh_16_15d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_16_15);
    Py_DecRef(v_16_15);

    fv_16_16 = nd.implicit_rebinds;
    v_16_16 = PyDict_New();
    for (dk_16_16d, dv_16_16d) in fv_16_16.items() {
        kh_16_16d = _py_str(dk_16_16d);
        vh_16_16d = _emit_Symbol(dv_16_16d);
        PyDict_SetItem(v_16_16, kh_16_16d, vh_16_16d);
        Py_DecRef(kh_16_16d);
        Py_DecRef(vh_16_16d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_16_16);
    Py_DecRef(v_16_16);

    fv_16_17 = nd.bb_in;
    v_16_17 = PyList_New(len(fv_16_17));
    li_16_17l = 0;
    for it_16_17l in fv_16_17 {
        e_16_17l = _emit_node(it_16_17l);
        PyList_SetItem(v_16_17, li_16_17l, e_16_17l);
        li_16_17l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_16_17);
    Py_DecRef(v_16_17);

    fv_16_18 = nd.bb_out;
    v_16_18 = PyList_New(len(fv_16_18));
    li_16_18l = 0;
    for it_16_18l in fv_16_18 {
        e_16_18l = _emit_node(it_16_18l);
        PyList_SetItem(v_16_18, li_16_18l, e_16_18l);
        li_16_18l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_16_18);
    Py_DecRef(v_16_18);

    fv_16_19 = nd.affected_symbols;
    v_16_19 = PySet_New(0);
    if len(fv_16_19) != 0 {
        Py_DecRef(v_16_19);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_16_19);
    Py_DecRef(v_16_19);

    fv_16_20 = nd.kv_pair;
    v_16_20 = _emit_node(fv_16_20);
    PyDict_SetItem(d_h, _mat_keys[68], v_16_20);
    Py_DecRef(v_16_20);

    fv_16_21 = nd.compr;
    v_16_21 = PyList_New(len(fv_16_21));
    li_16_21l = 0;
    for it_16_21l in fv_16_21 {
        e_16_21l = _emit_node(it_16_21l);
        PyList_SetItem(v_16_21, li_16_21l, e_16_21l);
        li_16_21l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[66], v_16_21);
    Py_DecRef(v_16_21);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_Ellipsis(nd: Ellipsis) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[17], _mat_classes[17]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_17_0 = nd.kid;
    v_17_0 = PyList_New(len(fv_17_0));
    li_17_0l = 0;
    for it_17_0l in fv_17_0 {
        e_17_0l = _emit_node(it_17_0l);
        PyList_SetItem(v_17_0, li_17_0l, e_17_0l);
        li_17_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_17_0);
    Py_DecRef(v_17_0);

    fv_17_1 = nd.parent;
    if fv_17_1 is None {
        v_17_1 = _py_none();
    } else {
        v_17_1 = _emit_node(fv_17_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_17_1);
    Py_DecRef(v_17_1);

    v_17_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_17_2);
    Py_DecRef(v_17_2);

    fv_17_3 = nd._in_mod_nodes;
    v_17_3 = PyList_New(len(fv_17_3));
    li_17_3l = 0;
    for it_17_3l in fv_17_3 {
        e_17_3l = _emit_node(it_17_3l);
        PyList_SetItem(v_17_3, li_17_3l, e_17_3l);
        li_17_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_17_3);
    Py_DecRef(v_17_3);

    v_17_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_17_4);
    Py_DecRef(v_17_4);

    fv_17_5 = nd.loc;
    v_17_5 = _emit_CodeLocInfo(fv_17_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_17_5);
    Py_DecRef(v_17_5);

    fv_17_6 = nd.orig_src;
    v_17_6 = _emit_node(fv_17_6);
    PyDict_SetItem(d_h, _mat_keys[41], v_17_6);
    Py_DecRef(v_17_6);

    fv_17_7 = nd.name;
    v_17_7 = _py_str(fv_17_7);
    PyDict_SetItem(d_h, _mat_keys[24], v_17_7);
    Py_DecRef(v_17_7);

    fv_17_8 = nd.value;
    v_17_8 = _py_str(fv_17_8);
    PyDict_SetItem(d_h, _mat_keys[42], v_17_8);
    Py_DecRef(v_17_8);

    fv_17_9 = nd.line_no;
    v_17_9 = PyLong_FromLongLong(fv_17_9);
    PyDict_SetItem(d_h, _mat_keys[43], v_17_9);
    Py_DecRef(v_17_9);

    fv_17_10 = nd.end_line;
    v_17_10 = PyLong_FromLongLong(fv_17_10);
    PyDict_SetItem(d_h, _mat_keys[44], v_17_10);
    Py_DecRef(v_17_10);

    fv_17_11 = nd.c_start;
    v_17_11 = PyLong_FromLongLong(fv_17_11);
    PyDict_SetItem(d_h, _mat_keys[45], v_17_11);
    Py_DecRef(v_17_11);

    fv_17_12 = nd.c_end;
    v_17_12 = PyLong_FromLongLong(fv_17_12);
    PyDict_SetItem(d_h, _mat_keys[46], v_17_12);
    Py_DecRef(v_17_12);

    fv_17_13 = nd.pos_start;
    v_17_13 = PyLong_FromLongLong(fv_17_13);
    PyDict_SetItem(d_h, _mat_keys[47], v_17_13);
    Py_DecRef(v_17_13);

    fv_17_14 = nd.pos_end;
    v_17_14 = PyLong_FromLongLong(fv_17_14);
    PyDict_SetItem(d_h, _mat_keys[48], v_17_14);
    Py_DecRef(v_17_14);

    fv_17_15 = nd._is_synthetic;
    v_17_15 = PyBool_FromLong(1 if fv_17_15 else 0);
    PyDict_SetItem(d_h, _mat_keys[49], v_17_15);
    Py_DecRef(v_17_15);

    fv_17_16 = nd._type_sym_tab;
    if fv_17_16 is None {
        v_17_16 = _py_none();
    } else {
        v_17_16 = _emit_node(fv_17_16);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_17_16);
    Py_DecRef(v_17_16);

    v_17_17 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_17_17);
    Py_DecRef(v_17_17);

    fv_17_18 = nd.attached_tokens;
    if fv_17_18 is None {
        v_17_18 = _py_none();
    } else {
        v_17_18 = PyList_New(len(fv_17_18));
        li_17_18l = 0;
        for it_17_18l in fv_17_18 {
            e_17_18l = _emit_node(it_17_18l);
            PyList_SetItem(v_17_18, li_17_18l, e_17_18l);
            li_17_18l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_17_18);
    Py_DecRef(v_17_18);

    fv_17_19 = nd.name_spec;
    v_17_19 = _emit_node(fv_17_19);
    PyDict_SetItem(d_h, _mat_keys[12], v_17_19);
    Py_DecRef(v_17_19);

    fv_17_20 = nd.semstr;
    v_17_20 = _py_str(fv_17_20);
    PyDict_SetItem(d_h, _mat_keys[13], v_17_20);
    Py_DecRef(v_17_20);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_Float(nd: Float) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[18], _mat_classes[18]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_18_0 = nd.kid;
    v_18_0 = PyList_New(len(fv_18_0));
    li_18_0l = 0;
    for it_18_0l in fv_18_0 {
        e_18_0l = _emit_node(it_18_0l);
        PyList_SetItem(v_18_0, li_18_0l, e_18_0l);
        li_18_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_18_0);
    Py_DecRef(v_18_0);

    fv_18_1 = nd.parent;
    if fv_18_1 is None {
        v_18_1 = _py_none();
    } else {
        v_18_1 = _emit_node(fv_18_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_18_1);
    Py_DecRef(v_18_1);

    v_18_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_18_2);
    Py_DecRef(v_18_2);

    fv_18_3 = nd._in_mod_nodes;
    v_18_3 = PyList_New(len(fv_18_3));
    li_18_3l = 0;
    for it_18_3l in fv_18_3 {
        e_18_3l = _emit_node(it_18_3l);
        PyList_SetItem(v_18_3, li_18_3l, e_18_3l);
        li_18_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_18_3);
    Py_DecRef(v_18_3);

    v_18_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_18_4);
    Py_DecRef(v_18_4);

    fv_18_5 = nd.loc;
    v_18_5 = _emit_CodeLocInfo(fv_18_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_18_5);
    Py_DecRef(v_18_5);

    fv_18_6 = nd.orig_src;
    v_18_6 = _emit_node(fv_18_6);
    PyDict_SetItem(d_h, _mat_keys[41], v_18_6);
    Py_DecRef(v_18_6);

    fv_18_7 = nd.name;
    v_18_7 = _py_str(fv_18_7);
    PyDict_SetItem(d_h, _mat_keys[24], v_18_7);
    Py_DecRef(v_18_7);

    fv_18_8 = nd.value;
    v_18_8 = _py_str(fv_18_8);
    PyDict_SetItem(d_h, _mat_keys[42], v_18_8);
    Py_DecRef(v_18_8);

    fv_18_9 = nd.line_no;
    v_18_9 = PyLong_FromLongLong(fv_18_9);
    PyDict_SetItem(d_h, _mat_keys[43], v_18_9);
    Py_DecRef(v_18_9);

    fv_18_10 = nd.end_line;
    v_18_10 = PyLong_FromLongLong(fv_18_10);
    PyDict_SetItem(d_h, _mat_keys[44], v_18_10);
    Py_DecRef(v_18_10);

    fv_18_11 = nd.c_start;
    v_18_11 = PyLong_FromLongLong(fv_18_11);
    PyDict_SetItem(d_h, _mat_keys[45], v_18_11);
    Py_DecRef(v_18_11);

    fv_18_12 = nd.c_end;
    v_18_12 = PyLong_FromLongLong(fv_18_12);
    PyDict_SetItem(d_h, _mat_keys[46], v_18_12);
    Py_DecRef(v_18_12);

    fv_18_13 = nd.pos_start;
    v_18_13 = PyLong_FromLongLong(fv_18_13);
    PyDict_SetItem(d_h, _mat_keys[47], v_18_13);
    Py_DecRef(v_18_13);

    fv_18_14 = nd.pos_end;
    v_18_14 = PyLong_FromLongLong(fv_18_14);
    PyDict_SetItem(d_h, _mat_keys[48], v_18_14);
    Py_DecRef(v_18_14);

    fv_18_15 = nd._is_synthetic;
    v_18_15 = PyBool_FromLong(1 if fv_18_15 else 0);
    PyDict_SetItem(d_h, _mat_keys[49], v_18_15);
    Py_DecRef(v_18_15);

    fv_18_16 = nd._type_sym_tab;
    if fv_18_16 is None {
        v_18_16 = _py_none();
    } else {
        v_18_16 = _emit_node(fv_18_16);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_18_16);
    Py_DecRef(v_18_16);

    v_18_17 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_18_17);
    Py_DecRef(v_18_17);

    fv_18_18 = nd.attached_tokens;
    if fv_18_18 is None {
        v_18_18 = _py_none();
    } else {
        v_18_18 = PyList_New(len(fv_18_18));
        li_18_18l = 0;
        for it_18_18l in fv_18_18 {
            e_18_18l = _emit_node(it_18_18l);
            PyList_SetItem(v_18_18, li_18_18l, e_18_18l);
            li_18_18l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_18_18);
    Py_DecRef(v_18_18);

    fv_18_19 = nd.name_spec;
    v_18_19 = _emit_node(fv_18_19);
    PyDict_SetItem(d_h, _mat_keys[12], v_18_19);
    Py_DecRef(v_18_19);

    fv_18_20 = nd.semstr;
    v_18_20 = _py_str(fv_18_20);
    PyDict_SetItem(d_h, _mat_keys[13], v_18_20);
    Py_DecRef(v_18_20);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_GlobalVars(nd: GlobalVars) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[19], _mat_classes[19]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_19_0 = nd.kid;
    v_19_0 = PyList_New(len(fv_19_0));
    li_19_0l = 0;
    for it_19_0l in fv_19_0 {
        e_19_0l = _emit_node(it_19_0l);
        PyList_SetItem(v_19_0, li_19_0l, e_19_0l);
        li_19_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_19_0);
    Py_DecRef(v_19_0);

    fv_19_1 = nd.parent;
    if fv_19_1 is None {
        v_19_1 = _py_none();
    } else {
        v_19_1 = _emit_node(fv_19_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_19_1);
    Py_DecRef(v_19_1);

    v_19_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_19_2);
    Py_DecRef(v_19_2);

    fv_19_3 = nd._in_mod_nodes;
    v_19_3 = PyList_New(len(fv_19_3));
    li_19_3l = 0;
    for it_19_3l in fv_19_3 {
        e_19_3l = _emit_node(it_19_3l);
        PyList_SetItem(v_19_3, li_19_3l, e_19_3l);
        li_19_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_19_3);
    Py_DecRef(v_19_3);

    v_19_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_19_4);
    Py_DecRef(v_19_4);

    fv_19_5 = nd.loc;
    v_19_5 = _emit_CodeLocInfo(fv_19_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_19_5);
    Py_DecRef(v_19_5);

    fv_19_6 = nd.code_context;
    v_19_6 = _enum_CodeContext(fv_19_6);
    PyDict_SetItem(d_h, _mat_keys[6], v_19_6);
    Py_DecRef(v_19_6);

    fv_19_7 = nd.codespace_dual;
    v_19_7 = PyBool_FromLong(1 if fv_19_7 else 0);
    PyDict_SetItem(d_h, _mat_keys[7], v_19_7);
    Py_DecRef(v_19_7);

    fv_19_8 = nd.doc;
    if fv_19_8 is None {
        v_19_8 = _py_none();
    } else {
        v_19_8 = _emit_node(fv_19_8);
    }
    PyDict_SetItem(d_h, _mat_keys[8], v_19_8);
    Py_DecRef(v_19_8);

    fv_19_9 = nd.access;
    if fv_19_9 is None {
        v_19_9 = _py_none();
    } else {
        v_19_9 = _emit_node(fv_19_9);
    }
    PyDict_SetItem(d_h, _mat_keys[16], v_19_9);
    Py_DecRef(v_19_9);

    fv_19_10 = nd.bb_in;
    v_19_10 = PyList_New(len(fv_19_10));
    li_19_10l = 0;
    for it_19_10l in fv_19_10 {
        e_19_10l = _emit_node(it_19_10l);
        PyList_SetItem(v_19_10, li_19_10l, e_19_10l);
        li_19_10l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_19_10);
    Py_DecRef(v_19_10);

    fv_19_11 = nd.bb_out;
    v_19_11 = PyList_New(len(fv_19_11));
    li_19_11l = 0;
    for it_19_11l in fv_19_11 {
        e_19_11l = _emit_node(it_19_11l);
        PyList_SetItem(v_19_11, li_19_11l, e_19_11l);
        li_19_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_19_11);
    Py_DecRef(v_19_11);

    fv_19_12 = nd.affected_symbols;
    v_19_12 = PySet_New(0);
    if len(fv_19_12) != 0 {
        Py_DecRef(v_19_12);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_19_12);
    Py_DecRef(v_19_12);

    fv_19_13 = nd.assignments;
    v_19_13 = PyList_New(len(fv_19_13));
    li_19_13l = 0;
    for it_19_13l in fv_19_13 {
        e_19_13l = _emit_node(it_19_13l);
        PyList_SetItem(v_19_13, li_19_13l, e_19_13l);
        li_19_13l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[69], v_19_13);
    Py_DecRef(v_19_13);

    fv_19_14 = nd.is_frozen;
    v_19_14 = PyBool_FromLong(1 if fv_19_14 else 0);
    PyDict_SetItem(d_h, _mat_keys[70], v_19_14);
    Py_DecRef(v_19_14);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ListCompr(nd: ListCompr) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[20], _mat_classes[20]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_20_0 = nd.kid;
    v_20_0 = PyList_New(len(fv_20_0));
    li_20_0l = 0;
    for it_20_0l in fv_20_0 {
        e_20_0l = _emit_node(it_20_0l);
        PyList_SetItem(v_20_0, li_20_0l, e_20_0l);
        li_20_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_20_0);
    Py_DecRef(v_20_0);

    fv_20_1 = nd.parent;
    if fv_20_1 is None {
        v_20_1 = _py_none();
    } else {
        v_20_1 = _emit_node(fv_20_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_20_1);
    Py_DecRef(v_20_1);

    v_20_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_20_2);
    Py_DecRef(v_20_2);

    fv_20_3 = nd._in_mod_nodes;
    v_20_3 = PyList_New(len(fv_20_3));
    li_20_3l = 0;
    for it_20_3l in fv_20_3 {
        e_20_3l = _emit_node(it_20_3l);
        PyList_SetItem(v_20_3, li_20_3l, e_20_3l);
        li_20_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_20_3);
    Py_DecRef(v_20_3);

    v_20_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_20_4);
    Py_DecRef(v_20_4);

    fv_20_5 = nd.loc;
    v_20_5 = _emit_CodeLocInfo(fv_20_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_20_5);
    Py_DecRef(v_20_5);

    fv_20_6 = nd._type_sym_tab;
    if fv_20_6 is None {
        v_20_6 = _py_none();
    } else {
        v_20_6 = _emit_node(fv_20_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_20_6);
    Py_DecRef(v_20_6);

    v_20_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_20_7);
    Py_DecRef(v_20_7);

    fv_20_8 = nd.attached_tokens;
    if fv_20_8 is None {
        v_20_8 = _py_none();
    } else {
        v_20_8 = PyList_New(len(fv_20_8));
        li_20_8l = 0;
        for it_20_8l in fv_20_8 {
            e_20_8l = _emit_node(it_20_8l);
            PyList_SetItem(v_20_8, li_20_8l, e_20_8l);
            li_20_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_20_8);
    Py_DecRef(v_20_8);

    fv_20_9 = nd.name_spec;
    v_20_9 = _emit_node(fv_20_9);
    PyDict_SetItem(d_h, _mat_keys[12], v_20_9);
    Py_DecRef(v_20_9);

    fv_20_10 = nd.semstr;
    v_20_10 = _py_str(fv_20_10);
    PyDict_SetItem(d_h, _mat_keys[13], v_20_10);
    Py_DecRef(v_20_10);

    fv_20_11 = nd.scope_name;
    v_20_11 = _py_str(fv_20_11);
    PyDict_SetItem(d_h, _mat_keys[18], v_20_11);
    Py_DecRef(v_20_11);

    fv_20_12 = nd.parent_scope;
    if fv_20_12 is None {
        v_20_12 = _py_none();
    } else {
        v_20_12 = _emit_node(fv_20_12);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_20_12);
    Py_DecRef(v_20_12);

    fv_20_13 = nd.kid_scope;
    v_20_13 = PyList_New(len(fv_20_13));
    li_20_13l = 0;
    for it_20_13l in fv_20_13 {
        e_20_13l = _emit_node(it_20_13l);
        PyList_SetItem(v_20_13, li_20_13l, e_20_13l);
        li_20_13l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_20_13);
    Py_DecRef(v_20_13);

    fv_20_14 = nd.names_in_scope;
    v_20_14 = PyDict_New();
    for (dk_20_14d, dv_20_14d) in fv_20_14.items() {
        kh_20_14d = _py_str(dk_20_14d);
        vh_20_14d = _emit_Symbol(dv_20_14d);
        PyDict_SetItem(v_20_14, kh_20_14d, vh_20_14d);
        Py_DecRef(kh_20_14d);
        Py_DecRef(vh_20_14d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_20_14);
    Py_DecRef(v_20_14);

    fv_20_15 = nd.names_in_scope_overload;
    v_20_15 = PyDict_New();
    for (dk_20_15d, dv_20_15d) in fv_20_15.items() {
        kh_20_15d = _py_str(dk_20_15d);
        vh_20_15d = PyList_New(len(dv_20_15d));
        li_20_15dl = 0;
        for it_20_15dl in dv_20_15d {
            e_20_15dl = _emit_Symbol(it_20_15dl);
            PyList_SetItem(vh_20_15d, li_20_15dl, e_20_15dl);
            li_20_15dl += 1;
        }
        PyDict_SetItem(v_20_15, kh_20_15d, vh_20_15d);
        Py_DecRef(kh_20_15d);
        Py_DecRef(vh_20_15d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_20_15);
    Py_DecRef(v_20_15);

    fv_20_16 = nd.implicit_rebinds;
    v_20_16 = PyDict_New();
    for (dk_20_16d, dv_20_16d) in fv_20_16.items() {
        kh_20_16d = _py_str(dk_20_16d);
        vh_20_16d = _emit_Symbol(dv_20_16d);
        PyDict_SetItem(v_20_16, kh_20_16d, vh_20_16d);
        Py_DecRef(kh_20_16d);
        Py_DecRef(vh_20_16d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_20_16);
    Py_DecRef(v_20_16);

    fv_20_17 = nd.bb_in;
    v_20_17 = PyList_New(len(fv_20_17));
    li_20_17l = 0;
    for it_20_17l in fv_20_17 {
        e_20_17l = _emit_node(it_20_17l);
        PyList_SetItem(v_20_17, li_20_17l, e_20_17l);
        li_20_17l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_20_17);
    Py_DecRef(v_20_17);

    fv_20_18 = nd.bb_out;
    v_20_18 = PyList_New(len(fv_20_18));
    li_20_18l = 0;
    for it_20_18l in fv_20_18 {
        e_20_18l = _emit_node(it_20_18l);
        PyList_SetItem(v_20_18, li_20_18l, e_20_18l);
        li_20_18l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_20_18);
    Py_DecRef(v_20_18);

    fv_20_19 = nd.affected_symbols;
    v_20_19 = PySet_New(0);
    if len(fv_20_19) != 0 {
        Py_DecRef(v_20_19);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_20_19);
    Py_DecRef(v_20_19);

    fv_20_20 = nd.out_expr;
    v_20_20 = _emit_node(fv_20_20);
    PyDict_SetItem(d_h, _mat_keys[65], v_20_20);
    Py_DecRef(v_20_20);

    fv_20_21 = nd.compr;
    v_20_21 = PyList_New(len(fv_20_21));
    li_20_21l = 0;
    for it_20_21l in fv_20_21 {
        e_20_21l = _emit_node(it_20_21l);
        PyList_SetItem(v_20_21, li_20_21l, e_20_21l);
        li_20_21l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[66], v_20_21);
    Py_DecRef(v_20_21);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_Null(nd: Null) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[21], _mat_classes[21]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_21_0 = nd.kid;
    v_21_0 = PyList_New(len(fv_21_0));
    li_21_0l = 0;
    for it_21_0l in fv_21_0 {
        e_21_0l = _emit_node(it_21_0l);
        PyList_SetItem(v_21_0, li_21_0l, e_21_0l);
        li_21_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_21_0);
    Py_DecRef(v_21_0);

    fv_21_1 = nd.parent;
    if fv_21_1 is None {
        v_21_1 = _py_none();
    } else {
        v_21_1 = _emit_node(fv_21_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_21_1);
    Py_DecRef(v_21_1);

    v_21_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_21_2);
    Py_DecRef(v_21_2);

    fv_21_3 = nd._in_mod_nodes;
    v_21_3 = PyList_New(len(fv_21_3));
    li_21_3l = 0;
    for it_21_3l in fv_21_3 {
        e_21_3l = _emit_node(it_21_3l);
        PyList_SetItem(v_21_3, li_21_3l, e_21_3l);
        li_21_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_21_3);
    Py_DecRef(v_21_3);

    v_21_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_21_4);
    Py_DecRef(v_21_4);

    fv_21_5 = nd.loc;
    v_21_5 = _emit_CodeLocInfo(fv_21_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_21_5);
    Py_DecRef(v_21_5);

    fv_21_6 = nd.orig_src;
    v_21_6 = _emit_node(fv_21_6);
    PyDict_SetItem(d_h, _mat_keys[41], v_21_6);
    Py_DecRef(v_21_6);

    fv_21_7 = nd.name;
    v_21_7 = _py_str(fv_21_7);
    PyDict_SetItem(d_h, _mat_keys[24], v_21_7);
    Py_DecRef(v_21_7);

    fv_21_8 = nd.value;
    v_21_8 = _py_str(fv_21_8);
    PyDict_SetItem(d_h, _mat_keys[42], v_21_8);
    Py_DecRef(v_21_8);

    fv_21_9 = nd.line_no;
    v_21_9 = PyLong_FromLongLong(fv_21_9);
    PyDict_SetItem(d_h, _mat_keys[43], v_21_9);
    Py_DecRef(v_21_9);

    fv_21_10 = nd.end_line;
    v_21_10 = PyLong_FromLongLong(fv_21_10);
    PyDict_SetItem(d_h, _mat_keys[44], v_21_10);
    Py_DecRef(v_21_10);

    fv_21_11 = nd.c_start;
    v_21_11 = PyLong_FromLongLong(fv_21_11);
    PyDict_SetItem(d_h, _mat_keys[45], v_21_11);
    Py_DecRef(v_21_11);

    fv_21_12 = nd.c_end;
    v_21_12 = PyLong_FromLongLong(fv_21_12);
    PyDict_SetItem(d_h, _mat_keys[46], v_21_12);
    Py_DecRef(v_21_12);

    fv_21_13 = nd.pos_start;
    v_21_13 = PyLong_FromLongLong(fv_21_13);
    PyDict_SetItem(d_h, _mat_keys[47], v_21_13);
    Py_DecRef(v_21_13);

    fv_21_14 = nd.pos_end;
    v_21_14 = PyLong_FromLongLong(fv_21_14);
    PyDict_SetItem(d_h, _mat_keys[48], v_21_14);
    Py_DecRef(v_21_14);

    fv_21_15 = nd._is_synthetic;
    v_21_15 = PyBool_FromLong(1 if fv_21_15 else 0);
    PyDict_SetItem(d_h, _mat_keys[49], v_21_15);
    Py_DecRef(v_21_15);

    fv_21_16 = nd._type_sym_tab;
    if fv_21_16 is None {
        v_21_16 = _py_none();
    } else {
        v_21_16 = _emit_node(fv_21_16);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_21_16);
    Py_DecRef(v_21_16);

    v_21_17 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_21_17);
    Py_DecRef(v_21_17);

    fv_21_18 = nd.attached_tokens;
    if fv_21_18 is None {
        v_21_18 = _py_none();
    } else {
        v_21_18 = PyList_New(len(fv_21_18));
        li_21_18l = 0;
        for it_21_18l in fv_21_18 {
            e_21_18l = _emit_node(it_21_18l);
            PyList_SetItem(v_21_18, li_21_18l, e_21_18l);
            li_21_18l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_21_18);
    Py_DecRef(v_21_18);

    fv_21_19 = nd.name_spec;
    v_21_19 = _emit_node(fv_21_19);
    PyDict_SetItem(d_h, _mat_keys[12], v_21_19);
    Py_DecRef(v_21_19);

    fv_21_20 = nd.semstr;
    v_21_20 = _py_str(fv_21_20);
    PyDict_SetItem(d_h, _mat_keys[13], v_21_20);
    Py_DecRef(v_21_20);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_PyInlineCode(nd: PyInlineCode) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[22], _mat_classes[22]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_22_0 = nd.kid;
    v_22_0 = PyList_New(len(fv_22_0));
    li_22_0l = 0;
    for it_22_0l in fv_22_0 {
        e_22_0l = _emit_node(it_22_0l);
        PyList_SetItem(v_22_0, li_22_0l, e_22_0l);
        li_22_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_22_0);
    Py_DecRef(v_22_0);

    fv_22_1 = nd.parent;
    if fv_22_1 is None {
        v_22_1 = _py_none();
    } else {
        v_22_1 = _emit_node(fv_22_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_22_1);
    Py_DecRef(v_22_1);

    v_22_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_22_2);
    Py_DecRef(v_22_2);

    fv_22_3 = nd._in_mod_nodes;
    v_22_3 = PyList_New(len(fv_22_3));
    li_22_3l = 0;
    for it_22_3l in fv_22_3 {
        e_22_3l = _emit_node(it_22_3l);
        PyList_SetItem(v_22_3, li_22_3l, e_22_3l);
        li_22_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_22_3);
    Py_DecRef(v_22_3);

    v_22_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_22_4);
    Py_DecRef(v_22_4);

    fv_22_5 = nd.loc;
    v_22_5 = _emit_CodeLocInfo(fv_22_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_22_5);
    Py_DecRef(v_22_5);

    fv_22_6 = nd.doc;
    if fv_22_6 is None {
        v_22_6 = _py_none();
    } else {
        v_22_6 = _emit_node(fv_22_6);
    }
    PyDict_SetItem(d_h, _mat_keys[8], v_22_6);
    Py_DecRef(v_22_6);

    fv_22_7 = nd.is_enum_stmt;
    v_22_7 = PyBool_FromLong(1 if fv_22_7 else 0);
    PyDict_SetItem(d_h, _mat_keys[53], v_22_7);
    Py_DecRef(v_22_7);

    fv_22_8 = nd.bb_in;
    v_22_8 = PyList_New(len(fv_22_8));
    li_22_8l = 0;
    for it_22_8l in fv_22_8 {
        e_22_8l = _emit_node(it_22_8l);
        PyList_SetItem(v_22_8, li_22_8l, e_22_8l);
        li_22_8l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_22_8);
    Py_DecRef(v_22_8);

    fv_22_9 = nd.bb_out;
    v_22_9 = PyList_New(len(fv_22_9));
    li_22_9l = 0;
    for it_22_9l in fv_22_9 {
        e_22_9l = _emit_node(it_22_9l);
        PyList_SetItem(v_22_9, li_22_9l, e_22_9l);
        li_22_9l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_22_9);
    Py_DecRef(v_22_9);

    fv_22_10 = nd.affected_symbols;
    v_22_10 = PySet_New(0);
    if len(fv_22_10) != 0 {
        Py_DecRef(v_22_10);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_22_10);
    Py_DecRef(v_22_10);

    fv_22_11 = nd.code;
    v_22_11 = _emit_node(fv_22_11);
    PyDict_SetItem(d_h, _mat_keys[71], v_22_11);
    Py_DecRef(v_22_11);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_SemDef(nd: SemDef) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[23], _mat_classes[23]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_23_0 = nd.kid;
    v_23_0 = PyList_New(len(fv_23_0));
    li_23_0l = 0;
    for it_23_0l in fv_23_0 {
        e_23_0l = _emit_node(it_23_0l);
        PyList_SetItem(v_23_0, li_23_0l, e_23_0l);
        li_23_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_23_0);
    Py_DecRef(v_23_0);

    fv_23_1 = nd.parent;
    if fv_23_1 is None {
        v_23_1 = _py_none();
    } else {
        v_23_1 = _emit_node(fv_23_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_23_1);
    Py_DecRef(v_23_1);

    v_23_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_23_2);
    Py_DecRef(v_23_2);

    fv_23_3 = nd._in_mod_nodes;
    v_23_3 = PyList_New(len(fv_23_3));
    li_23_3l = 0;
    for it_23_3l in fv_23_3 {
        e_23_3l = _emit_node(it_23_3l);
        PyList_SetItem(v_23_3, li_23_3l, e_23_3l);
        li_23_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_23_3);
    Py_DecRef(v_23_3);

    v_23_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_23_4);
    Py_DecRef(v_23_4);

    fv_23_5 = nd.loc;
    v_23_5 = _emit_CodeLocInfo(fv_23_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_23_5);
    Py_DecRef(v_23_5);

    fv_23_6 = nd.doc;
    if fv_23_6 is None {
        v_23_6 = _py_none();
    } else {
        v_23_6 = _emit_node(fv_23_6);
    }
    PyDict_SetItem(d_h, _mat_keys[8], v_23_6);
    Py_DecRef(v_23_6);

    fv_23_7 = nd.name_spec;
    v_23_7 = _emit_node(fv_23_7);
    PyDict_SetItem(d_h, _mat_keys[12], v_23_7);
    Py_DecRef(v_23_7);

    fv_23_8 = nd.semstr;
    v_23_8 = _py_str(fv_23_8);
    PyDict_SetItem(d_h, _mat_keys[13], v_23_8);
    Py_DecRef(v_23_8);

    fv_23_9 = nd.scope_name;
    v_23_9 = _py_str(fv_23_9);
    PyDict_SetItem(d_h, _mat_keys[18], v_23_9);
    Py_DecRef(v_23_9);

    fv_23_10 = nd.parent_scope;
    if fv_23_10 is None {
        v_23_10 = _py_none();
    } else {
        v_23_10 = _emit_node(fv_23_10);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_23_10);
    Py_DecRef(v_23_10);

    fv_23_11 = nd.kid_scope;
    v_23_11 = PyList_New(len(fv_23_11));
    li_23_11l = 0;
    for it_23_11l in fv_23_11 {
        e_23_11l = _emit_node(it_23_11l);
        PyList_SetItem(v_23_11, li_23_11l, e_23_11l);
        li_23_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_23_11);
    Py_DecRef(v_23_11);

    fv_23_12 = nd.names_in_scope;
    v_23_12 = PyDict_New();
    for (dk_23_12d, dv_23_12d) in fv_23_12.items() {
        kh_23_12d = _py_str(dk_23_12d);
        vh_23_12d = _emit_Symbol(dv_23_12d);
        PyDict_SetItem(v_23_12, kh_23_12d, vh_23_12d);
        Py_DecRef(kh_23_12d);
        Py_DecRef(vh_23_12d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_23_12);
    Py_DecRef(v_23_12);

    fv_23_13 = nd.names_in_scope_overload;
    v_23_13 = PyDict_New();
    for (dk_23_13d, dv_23_13d) in fv_23_13.items() {
        kh_23_13d = _py_str(dk_23_13d);
        vh_23_13d = PyList_New(len(dv_23_13d));
        li_23_13dl = 0;
        for it_23_13dl in dv_23_13d {
            e_23_13dl = _emit_Symbol(it_23_13dl);
            PyList_SetItem(vh_23_13d, li_23_13dl, e_23_13dl);
            li_23_13dl += 1;
        }
        PyDict_SetItem(v_23_13, kh_23_13d, vh_23_13d);
        Py_DecRef(kh_23_13d);
        Py_DecRef(vh_23_13d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_23_13);
    Py_DecRef(v_23_13);

    fv_23_14 = nd.implicit_rebinds;
    v_23_14 = PyDict_New();
    for (dk_23_14d, dv_23_14d) in fv_23_14.items() {
        kh_23_14d = _py_str(dk_23_14d);
        vh_23_14d = _emit_Symbol(dv_23_14d);
        PyDict_SetItem(v_23_14, kh_23_14d, vh_23_14d);
        Py_DecRef(kh_23_14d);
        Py_DecRef(vh_23_14d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_23_14);
    Py_DecRef(v_23_14);

    fv_23_15 = nd.bb_in;
    v_23_15 = PyList_New(len(fv_23_15));
    li_23_15l = 0;
    for it_23_15l in fv_23_15 {
        e_23_15l = _emit_node(it_23_15l);
        PyList_SetItem(v_23_15, li_23_15l, e_23_15l);
        li_23_15l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_23_15);
    Py_DecRef(v_23_15);

    fv_23_16 = nd.bb_out;
    v_23_16 = PyList_New(len(fv_23_16));
    li_23_16l = 0;
    for it_23_16l in fv_23_16 {
        e_23_16l = _emit_node(it_23_16l);
        PyList_SetItem(v_23_16, li_23_16l, e_23_16l);
        li_23_16l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_23_16);
    Py_DecRef(v_23_16);

    fv_23_17 = nd.affected_symbols;
    v_23_17 = PySet_New(0);
    if len(fv_23_17) != 0 {
        Py_DecRef(v_23_17);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_23_17);
    Py_DecRef(v_23_17);

    fv_23_18 = nd.target;
    v_23_18 = PyList_New(len(fv_23_18));
    li_23_18l = 0;
    for it_23_18l in fv_23_18 {
        e_23_18l = _emit_node(it_23_18l);
        PyList_SetItem(v_23_18, li_23_18l, e_23_18l);
        li_23_18l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[60], v_23_18);
    Py_DecRef(v_23_18);

    fv_23_19 = nd.value;
    v_23_19 = _emit_node(fv_23_19);
    PyDict_SetItem(d_h, _mat_keys[42], v_23_19);
    Py_DecRef(v_23_19);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ArchHas(nd: ArchHas) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[24], _mat_classes[24]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_24_0 = nd.kid;
    v_24_0 = PyList_New(len(fv_24_0));
    li_24_0l = 0;
    for it_24_0l in fv_24_0 {
        e_24_0l = _emit_node(it_24_0l);
        PyList_SetItem(v_24_0, li_24_0l, e_24_0l);
        li_24_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_24_0);
    Py_DecRef(v_24_0);

    fv_24_1 = nd.parent;
    if fv_24_1 is None {
        v_24_1 = _py_none();
    } else {
        v_24_1 = _emit_node(fv_24_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_24_1);
    Py_DecRef(v_24_1);

    v_24_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_24_2);
    Py_DecRef(v_24_2);

    fv_24_3 = nd._in_mod_nodes;
    v_24_3 = PyList_New(len(fv_24_3));
    li_24_3l = 0;
    for it_24_3l in fv_24_3 {
        e_24_3l = _emit_node(it_24_3l);
        PyList_SetItem(v_24_3, li_24_3l, e_24_3l);
        li_24_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_24_3);
    Py_DecRef(v_24_3);

    v_24_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_24_4);
    Py_DecRef(v_24_4);

    fv_24_5 = nd.loc;
    v_24_5 = _emit_CodeLocInfo(fv_24_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_24_5);
    Py_DecRef(v_24_5);

    fv_24_6 = nd.access;
    if fv_24_6 is None {
        v_24_6 = _py_none();
    } else {
        v_24_6 = _emit_node(fv_24_6);
    }
    PyDict_SetItem(d_h, _mat_keys[16], v_24_6);
    Py_DecRef(v_24_6);

    fv_24_7 = nd.doc;
    if fv_24_7 is None {
        v_24_7 = _py_none();
    } else {
        v_24_7 = _emit_node(fv_24_7);
    }
    PyDict_SetItem(d_h, _mat_keys[8], v_24_7);
    Py_DecRef(v_24_7);

    fv_24_8 = nd.bb_in;
    v_24_8 = PyList_New(len(fv_24_8));
    li_24_8l = 0;
    for it_24_8l in fv_24_8 {
        e_24_8l = _emit_node(it_24_8l);
        PyList_SetItem(v_24_8, li_24_8l, e_24_8l);
        li_24_8l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_24_8);
    Py_DecRef(v_24_8);

    fv_24_9 = nd.bb_out;
    v_24_9 = PyList_New(len(fv_24_9));
    li_24_9l = 0;
    for it_24_9l in fv_24_9 {
        e_24_9l = _emit_node(it_24_9l);
        PyList_SetItem(v_24_9, li_24_9l, e_24_9l);
        li_24_9l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_24_9);
    Py_DecRef(v_24_9);

    fv_24_10 = nd.affected_symbols;
    v_24_10 = PySet_New(0);
    if len(fv_24_10) != 0 {
        Py_DecRef(v_24_10);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_24_10);
    Py_DecRef(v_24_10);

    fv_24_11 = nd.is_static;
    v_24_11 = PyBool_FromLong(1 if fv_24_11 else 0);
    PyDict_SetItem(d_h, _mat_keys[34], v_24_11);
    Py_DecRef(v_24_11);

    fv_24_12 = nd.vars;
    v_24_12 = PyList_New(len(fv_24_12));
    li_24_12l = 0;
    for it_24_12l in fv_24_12 {
        e_24_12l = _emit_node(it_24_12l);
        PyList_SetItem(v_24_12, li_24_12l, e_24_12l);
        li_24_12l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[72], v_24_12);
    Py_DecRef(v_24_12);

    fv_24_13 = nd.is_frozen;
    v_24_13 = PyBool_FromLong(1 if fv_24_13 else 0);
    PyDict_SetItem(d_h, _mat_keys[70], v_24_13);
    Py_DecRef(v_24_13);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_EdgeOpRef(nd: EdgeOpRef) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[25], _mat_classes[25]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_25_0 = nd.kid;
    v_25_0 = PyList_New(len(fv_25_0));
    li_25_0l = 0;
    for it_25_0l in fv_25_0 {
        e_25_0l = _emit_node(it_25_0l);
        PyList_SetItem(v_25_0, li_25_0l, e_25_0l);
        li_25_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_25_0);
    Py_DecRef(v_25_0);

    fv_25_1 = nd.parent;
    if fv_25_1 is None {
        v_25_1 = _py_none();
    } else {
        v_25_1 = _emit_node(fv_25_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_25_1);
    Py_DecRef(v_25_1);

    v_25_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_25_2);
    Py_DecRef(v_25_2);

    fv_25_3 = nd._in_mod_nodes;
    v_25_3 = PyList_New(len(fv_25_3));
    li_25_3l = 0;
    for it_25_3l in fv_25_3 {
        e_25_3l = _emit_node(it_25_3l);
        PyList_SetItem(v_25_3, li_25_3l, e_25_3l);
        li_25_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_25_3);
    Py_DecRef(v_25_3);

    v_25_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_25_4);
    Py_DecRef(v_25_4);

    fv_25_5 = nd.loc;
    v_25_5 = _emit_CodeLocInfo(fv_25_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_25_5);
    Py_DecRef(v_25_5);

    fv_25_6 = nd.from_walker;
    v_25_6 = PyBool_FromLong(1 if fv_25_6 else 0);
    PyDict_SetItem(d_h, _mat_keys[73], v_25_6);
    Py_DecRef(v_25_6);

    fv_25_7 = nd._type_sym_tab;
    if fv_25_7 is None {
        v_25_7 = _py_none();
    } else {
        v_25_7 = _emit_node(fv_25_7);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_25_7);
    Py_DecRef(v_25_7);

    v_25_8 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_25_8);
    Py_DecRef(v_25_8);

    fv_25_9 = nd.attached_tokens;
    if fv_25_9 is None {
        v_25_9 = _py_none();
    } else {
        v_25_9 = PyList_New(len(fv_25_9));
        li_25_9l = 0;
        for it_25_9l in fv_25_9 {
            e_25_9l = _emit_node(it_25_9l);
            PyList_SetItem(v_25_9, li_25_9l, e_25_9l);
            li_25_9l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_25_9);
    Py_DecRef(v_25_9);

    fv_25_10 = nd.name_spec;
    v_25_10 = _emit_node(fv_25_10);
    PyDict_SetItem(d_h, _mat_keys[12], v_25_10);
    Py_DecRef(v_25_10);

    fv_25_11 = nd.semstr;
    v_25_11 = _py_str(fv_25_11);
    PyDict_SetItem(d_h, _mat_keys[13], v_25_11);
    Py_DecRef(v_25_11);

    fv_25_12 = nd.filter_cond;
    if fv_25_12 is None {
        v_25_12 = _py_none();
    } else {
        v_25_12 = _emit_node(fv_25_12);
    }
    PyDict_SetItem(d_h, _mat_keys[74], v_25_12);
    Py_DecRef(v_25_12);

    fv_25_13 = nd.edge_dir;
    v_25_13 = _enum_EdgeDir(fv_25_13);
    PyDict_SetItem(d_h, _mat_keys[75], v_25_13);
    Py_DecRef(v_25_13);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ElseIf(nd: ElseIf) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[26], _mat_classes[26]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_26_0 = nd.kid;
    v_26_0 = PyList_New(len(fv_26_0));
    li_26_0l = 0;
    for it_26_0l in fv_26_0 {
        e_26_0l = _emit_node(it_26_0l);
        PyList_SetItem(v_26_0, li_26_0l, e_26_0l);
        li_26_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_26_0);
    Py_DecRef(v_26_0);

    fv_26_1 = nd.parent;
    if fv_26_1 is None {
        v_26_1 = _py_none();
    } else {
        v_26_1 = _emit_node(fv_26_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_26_1);
    Py_DecRef(v_26_1);

    v_26_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_26_2);
    Py_DecRef(v_26_2);

    fv_26_3 = nd._in_mod_nodes;
    v_26_3 = PyList_New(len(fv_26_3));
    li_26_3l = 0;
    for it_26_3l in fv_26_3 {
        e_26_3l = _emit_node(it_26_3l);
        PyList_SetItem(v_26_3, li_26_3l, e_26_3l);
        li_26_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_26_3);
    Py_DecRef(v_26_3);

    v_26_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_26_4);
    Py_DecRef(v_26_4);

    fv_26_5 = nd.loc;
    v_26_5 = _emit_CodeLocInfo(fv_26_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_26_5);
    Py_DecRef(v_26_5);

    fv_26_6 = nd.bb_in;
    v_26_6 = PyList_New(len(fv_26_6));
    li_26_6l = 0;
    for it_26_6l in fv_26_6 {
        e_26_6l = _emit_node(it_26_6l);
        PyList_SetItem(v_26_6, li_26_6l, e_26_6l);
        li_26_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_26_6);
    Py_DecRef(v_26_6);

    fv_26_7 = nd.bb_out;
    v_26_7 = PyList_New(len(fv_26_7));
    li_26_7l = 0;
    for it_26_7l in fv_26_7 {
        e_26_7l = _emit_node(it_26_7l);
        PyList_SetItem(v_26_7, li_26_7l, e_26_7l);
        li_26_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_26_7);
    Py_DecRef(v_26_7);

    fv_26_8 = nd.affected_symbols;
    v_26_8 = PySet_New(0);
    if len(fv_26_8) != 0 {
        Py_DecRef(v_26_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_26_8);
    Py_DecRef(v_26_8);

    fv_26_9 = nd.else_body;
    if fv_26_9 is None {
        v_26_9 = _py_none();
    } else {
        if isinstance(fv_26_9, ElseStmt) {
            v_26_9 = _emit_node(fv_26_9);
        } elif isinstance(fv_26_9, ElseIf) {
            v_26_9 = _emit_node(fv_26_9);
        } else {
            v_26_9 = _py_none();
        }
    }
    PyDict_SetItem(d_h, _mat_keys[76], v_26_9);
    Py_DecRef(v_26_9);

    fv_26_10 = nd.scope_name;
    v_26_10 = _py_str(fv_26_10);
    PyDict_SetItem(d_h, _mat_keys[18], v_26_10);
    Py_DecRef(v_26_10);

    fv_26_11 = nd.parent_scope;
    if fv_26_11 is None {
        v_26_11 = _py_none();
    } else {
        v_26_11 = _emit_node(fv_26_11);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_26_11);
    Py_DecRef(v_26_11);

    fv_26_12 = nd.kid_scope;
    v_26_12 = PyList_New(len(fv_26_12));
    li_26_12l = 0;
    for it_26_12l in fv_26_12 {
        e_26_12l = _emit_node(it_26_12l);
        PyList_SetItem(v_26_12, li_26_12l, e_26_12l);
        li_26_12l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_26_12);
    Py_DecRef(v_26_12);

    fv_26_13 = nd.names_in_scope;
    v_26_13 = PyDict_New();
    for (dk_26_13d, dv_26_13d) in fv_26_13.items() {
        kh_26_13d = _py_str(dk_26_13d);
        vh_26_13d = _emit_Symbol(dv_26_13d);
        PyDict_SetItem(v_26_13, kh_26_13d, vh_26_13d);
        Py_DecRef(kh_26_13d);
        Py_DecRef(vh_26_13d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_26_13);
    Py_DecRef(v_26_13);

    fv_26_14 = nd.names_in_scope_overload;
    v_26_14 = PyDict_New();
    for (dk_26_14d, dv_26_14d) in fv_26_14.items() {
        kh_26_14d = _py_str(dk_26_14d);
        vh_26_14d = PyList_New(len(dv_26_14d));
        li_26_14dl = 0;
        for it_26_14dl in dv_26_14d {
            e_26_14dl = _emit_Symbol(it_26_14dl);
            PyList_SetItem(vh_26_14d, li_26_14dl, e_26_14dl);
            li_26_14dl += 1;
        }
        PyDict_SetItem(v_26_14, kh_26_14d, vh_26_14d);
        Py_DecRef(kh_26_14d);
        Py_DecRef(vh_26_14d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_26_14);
    Py_DecRef(v_26_14);

    fv_26_15 = nd.implicit_rebinds;
    v_26_15 = PyDict_New();
    for (dk_26_15d, dv_26_15d) in fv_26_15.items() {
        kh_26_15d = _py_str(dk_26_15d);
        vh_26_15d = _emit_Symbol(dv_26_15d);
        PyDict_SetItem(v_26_15, kh_26_15d, vh_26_15d);
        Py_DecRef(kh_26_15d);
        Py_DecRef(vh_26_15d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_26_15);
    Py_DecRef(v_26_15);

    fv_26_16 = nd.condition;
    v_26_16 = _emit_node(fv_26_16);
    PyDict_SetItem(d_h, _mat_keys[77], v_26_16);
    Py_DecRef(v_26_16);

    fv_26_17 = nd.body;
    v_26_17 = PyList_New(len(fv_26_17));
    li_26_17l = 0;
    for it_26_17l in fv_26_17 {
        e_26_17l = _emit_node(it_26_17l);
        PyList_SetItem(v_26_17, li_26_17l, e_26_17l);
        li_26_17l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_26_17);
    Py_DecRef(v_26_17);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_Import(nd: Import) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[27], _mat_classes[27]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_27_0 = nd.kid;
    v_27_0 = PyList_New(len(fv_27_0));
    li_27_0l = 0;
    for it_27_0l in fv_27_0 {
        e_27_0l = _emit_node(it_27_0l);
        PyList_SetItem(v_27_0, li_27_0l, e_27_0l);
        li_27_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_27_0);
    Py_DecRef(v_27_0);

    fv_27_1 = nd.parent;
    if fv_27_1 is None {
        v_27_1 = _py_none();
    } else {
        v_27_1 = _emit_node(fv_27_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_27_1);
    Py_DecRef(v_27_1);

    v_27_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_27_2);
    Py_DecRef(v_27_2);

    fv_27_3 = nd._in_mod_nodes;
    v_27_3 = PyList_New(len(fv_27_3));
    li_27_3l = 0;
    for it_27_3l in fv_27_3 {
        e_27_3l = _emit_node(it_27_3l);
        PyList_SetItem(v_27_3, li_27_3l, e_27_3l);
        li_27_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_27_3);
    Py_DecRef(v_27_3);

    v_27_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_27_4);
    Py_DecRef(v_27_4);

    fv_27_5 = nd.loc;
    v_27_5 = _emit_CodeLocInfo(fv_27_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_27_5);
    Py_DecRef(v_27_5);

    fv_27_6 = nd.code_context;
    v_27_6 = _enum_CodeContext(fv_27_6);
    PyDict_SetItem(d_h, _mat_keys[6], v_27_6);
    Py_DecRef(v_27_6);

    fv_27_7 = nd.codespace_dual;
    v_27_7 = PyBool_FromLong(1 if fv_27_7 else 0);
    PyDict_SetItem(d_h, _mat_keys[7], v_27_7);
    Py_DecRef(v_27_7);

    fv_27_8 = nd.doc;
    if fv_27_8 is None {
        v_27_8 = _py_none();
    } else {
        v_27_8 = _emit_node(fv_27_8);
    }
    PyDict_SetItem(d_h, _mat_keys[8], v_27_8);
    Py_DecRef(v_27_8);

    fv_27_9 = nd.bb_in;
    v_27_9 = PyList_New(len(fv_27_9));
    li_27_9l = 0;
    for it_27_9l in fv_27_9 {
        e_27_9l = _emit_node(it_27_9l);
        PyList_SetItem(v_27_9, li_27_9l, e_27_9l);
        li_27_9l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_27_9);
    Py_DecRef(v_27_9);

    fv_27_10 = nd.bb_out;
    v_27_10 = PyList_New(len(fv_27_10));
    li_27_10l = 0;
    for it_27_10l in fv_27_10 {
        e_27_10l = _emit_node(it_27_10l);
        PyList_SetItem(v_27_10, li_27_10l, e_27_10l);
        li_27_10l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_27_10);
    Py_DecRef(v_27_10);

    fv_27_11 = nd.affected_symbols;
    v_27_11 = PySet_New(0);
    if len(fv_27_11) != 0 {
        Py_DecRef(v_27_11);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_27_11);
    Py_DecRef(v_27_11);

    fv_27_12 = nd.from_loc;
    if fv_27_12 is None {
        v_27_12 = _py_none();
    } else {
        v_27_12 = _emit_node(fv_27_12);
    }
    PyDict_SetItem(d_h, _mat_keys[78], v_27_12);
    Py_DecRef(v_27_12);

    fv_27_13 = nd.items;
    v_27_13 = PyList_New(len(fv_27_13));
    li_27_13l = 0;
    for it_27_13l in fv_27_13 {
        e_27_13l = _emit_node(it_27_13l);
        PyList_SetItem(v_27_13, li_27_13l, e_27_13l);
        li_27_13l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[79], v_27_13);
    Py_DecRef(v_27_13);

    fv_27_14 = nd.is_absorb;
    v_27_14 = PyBool_FromLong(1 if fv_27_14 else 0);
    PyDict_SetItem(d_h, _mat_keys[80], v_27_14);
    Py_DecRef(v_27_14);

    fv_27_15 = nd.is_typed;
    v_27_15 = PyBool_FromLong(1 if fv_27_15 else 0);
    PyDict_SetItem(d_h, _mat_keys[81], v_27_15);
    Py_DecRef(v_27_15);

    fv_27_16 = nd.clib_decls;
    if fv_27_16 is None {
        v_27_16 = _py_none();
    } else {
        v_27_16 = PyList_New(len(fv_27_16));
        li_27_16l = 0;
        for it_27_16l in fv_27_16 {
            e_27_16l = _emit_node(it_27_16l);
            PyList_SetItem(v_27_16, li_27_16l, e_27_16l);
            li_27_16l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[82], v_27_16);
    Py_DecRef(v_27_16);

    fv_27_17 = nd.hint;
    if fv_27_17 is None {
        v_27_17 = _py_none();
    } else {
        v_27_17 = _emit_node(fv_27_17);
    }
    PyDict_SetItem(d_h, _mat_keys[83], v_27_17);
    Py_DecRef(v_27_17);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_InForStmt(nd: InForStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[28], _mat_classes[28]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_28_0 = nd.kid;
    v_28_0 = PyList_New(len(fv_28_0));
    li_28_0l = 0;
    for it_28_0l in fv_28_0 {
        e_28_0l = _emit_node(it_28_0l);
        PyList_SetItem(v_28_0, li_28_0l, e_28_0l);
        li_28_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_28_0);
    Py_DecRef(v_28_0);

    fv_28_1 = nd.parent;
    if fv_28_1 is None {
        v_28_1 = _py_none();
    } else {
        v_28_1 = _emit_node(fv_28_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_28_1);
    Py_DecRef(v_28_1);

    v_28_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_28_2);
    Py_DecRef(v_28_2);

    fv_28_3 = nd._in_mod_nodes;
    v_28_3 = PyList_New(len(fv_28_3));
    li_28_3l = 0;
    for it_28_3l in fv_28_3 {
        e_28_3l = _emit_node(it_28_3l);
        PyList_SetItem(v_28_3, li_28_3l, e_28_3l);
        li_28_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_28_3);
    Py_DecRef(v_28_3);

    v_28_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_28_4);
    Py_DecRef(v_28_4);

    fv_28_5 = nd.loc;
    v_28_5 = _emit_CodeLocInfo(fv_28_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_28_5);
    Py_DecRef(v_28_5);

    fv_28_6 = nd.is_async;
    v_28_6 = PyBool_FromLong(1 if fv_28_6 else 0);
    PyDict_SetItem(d_h, _mat_keys[14], v_28_6);
    Py_DecRef(v_28_6);

    fv_28_7 = nd.else_body;
    if fv_28_7 is None {
        v_28_7 = _py_none();
    } else {
        if isinstance(fv_28_7, ElseStmt) {
            v_28_7 = _emit_node(fv_28_7);
        } elif isinstance(fv_28_7, ElseIf) {
            v_28_7 = _emit_node(fv_28_7);
        } else {
            v_28_7 = _py_none();
        }
    }
    PyDict_SetItem(d_h, _mat_keys[76], v_28_7);
    Py_DecRef(v_28_7);

    fv_28_8 = nd.bb_in;
    v_28_8 = PyList_New(len(fv_28_8));
    li_28_8l = 0;
    for it_28_8l in fv_28_8 {
        e_28_8l = _emit_node(it_28_8l);
        PyList_SetItem(v_28_8, li_28_8l, e_28_8l);
        li_28_8l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_28_8);
    Py_DecRef(v_28_8);

    fv_28_9 = nd.bb_out;
    v_28_9 = PyList_New(len(fv_28_9));
    li_28_9l = 0;
    for it_28_9l in fv_28_9 {
        e_28_9l = _emit_node(it_28_9l);
        PyList_SetItem(v_28_9, li_28_9l, e_28_9l);
        li_28_9l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_28_9);
    Py_DecRef(v_28_9);

    fv_28_10 = nd.affected_symbols;
    v_28_10 = PySet_New(0);
    if len(fv_28_10) != 0 {
        Py_DecRef(v_28_10);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_28_10);
    Py_DecRef(v_28_10);

    fv_28_11 = nd.scope_name;
    v_28_11 = _py_str(fv_28_11);
    PyDict_SetItem(d_h, _mat_keys[18], v_28_11);
    Py_DecRef(v_28_11);

    fv_28_12 = nd.parent_scope;
    if fv_28_12 is None {
        v_28_12 = _py_none();
    } else {
        v_28_12 = _emit_node(fv_28_12);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_28_12);
    Py_DecRef(v_28_12);

    fv_28_13 = nd.kid_scope;
    v_28_13 = PyList_New(len(fv_28_13));
    li_28_13l = 0;
    for it_28_13l in fv_28_13 {
        e_28_13l = _emit_node(it_28_13l);
        PyList_SetItem(v_28_13, li_28_13l, e_28_13l);
        li_28_13l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_28_13);
    Py_DecRef(v_28_13);

    fv_28_14 = nd.names_in_scope;
    v_28_14 = PyDict_New();
    for (dk_28_14d, dv_28_14d) in fv_28_14.items() {
        kh_28_14d = _py_str(dk_28_14d);
        vh_28_14d = _emit_Symbol(dv_28_14d);
        PyDict_SetItem(v_28_14, kh_28_14d, vh_28_14d);
        Py_DecRef(kh_28_14d);
        Py_DecRef(vh_28_14d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_28_14);
    Py_DecRef(v_28_14);

    fv_28_15 = nd.names_in_scope_overload;
    v_28_15 = PyDict_New();
    for (dk_28_15d, dv_28_15d) in fv_28_15.items() {
        kh_28_15d = _py_str(dk_28_15d);
        vh_28_15d = PyList_New(len(dv_28_15d));
        li_28_15dl = 0;
        for it_28_15dl in dv_28_15d {
            e_28_15dl = _emit_Symbol(it_28_15dl);
            PyList_SetItem(vh_28_15d, li_28_15dl, e_28_15dl);
            li_28_15dl += 1;
        }
        PyDict_SetItem(v_28_15, kh_28_15d, vh_28_15d);
        Py_DecRef(kh_28_15d);
        Py_DecRef(vh_28_15d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_28_15);
    Py_DecRef(v_28_15);

    fv_28_16 = nd.implicit_rebinds;
    v_28_16 = PyDict_New();
    for (dk_28_16d, dv_28_16d) in fv_28_16.items() {
        kh_28_16d = _py_str(dk_28_16d);
        vh_28_16d = _emit_Symbol(dv_28_16d);
        PyDict_SetItem(v_28_16, kh_28_16d, vh_28_16d);
        Py_DecRef(kh_28_16d);
        Py_DecRef(vh_28_16d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_28_16);
    Py_DecRef(v_28_16);

    fv_28_17 = nd.target;
    v_28_17 = _emit_node(fv_28_17);
    PyDict_SetItem(d_h, _mat_keys[60], v_28_17);
    Py_DecRef(v_28_17);

    fv_28_18 = nd.collection;
    v_28_18 = _emit_node(fv_28_18);
    PyDict_SetItem(d_h, _mat_keys[84], v_28_18);
    Py_DecRef(v_28_18);

    fv_28_19 = nd.body;
    v_28_19 = PyList_New(len(fv_28_19));
    li_28_19l = 0;
    for it_28_19l in fv_28_19 {
        e_28_19l = _emit_node(it_28_19l);
        PyList_SetItem(v_28_19, li_28_19l, e_28_19l);
        li_28_19l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_28_19);
    Py_DecRef(v_28_19);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_IterForStmt(nd: IterForStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[29], _mat_classes[29]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_29_0 = nd.kid;
    v_29_0 = PyList_New(len(fv_29_0));
    li_29_0l = 0;
    for it_29_0l in fv_29_0 {
        e_29_0l = _emit_node(it_29_0l);
        PyList_SetItem(v_29_0, li_29_0l, e_29_0l);
        li_29_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_29_0);
    Py_DecRef(v_29_0);

    fv_29_1 = nd.parent;
    if fv_29_1 is None {
        v_29_1 = _py_none();
    } else {
        v_29_1 = _emit_node(fv_29_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_29_1);
    Py_DecRef(v_29_1);

    v_29_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_29_2);
    Py_DecRef(v_29_2);

    fv_29_3 = nd._in_mod_nodes;
    v_29_3 = PyList_New(len(fv_29_3));
    li_29_3l = 0;
    for it_29_3l in fv_29_3 {
        e_29_3l = _emit_node(it_29_3l);
        PyList_SetItem(v_29_3, li_29_3l, e_29_3l);
        li_29_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_29_3);
    Py_DecRef(v_29_3);

    v_29_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_29_4);
    Py_DecRef(v_29_4);

    fv_29_5 = nd.loc;
    v_29_5 = _emit_CodeLocInfo(fv_29_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_29_5);
    Py_DecRef(v_29_5);

    fv_29_6 = nd.is_async;
    v_29_6 = PyBool_FromLong(1 if fv_29_6 else 0);
    PyDict_SetItem(d_h, _mat_keys[14], v_29_6);
    Py_DecRef(v_29_6);

    fv_29_7 = nd.else_body;
    if fv_29_7 is None {
        v_29_7 = _py_none();
    } else {
        if isinstance(fv_29_7, ElseStmt) {
            v_29_7 = _emit_node(fv_29_7);
        } elif isinstance(fv_29_7, ElseIf) {
            v_29_7 = _emit_node(fv_29_7);
        } else {
            v_29_7 = _py_none();
        }
    }
    PyDict_SetItem(d_h, _mat_keys[76], v_29_7);
    Py_DecRef(v_29_7);

    fv_29_8 = nd.bb_in;
    v_29_8 = PyList_New(len(fv_29_8));
    li_29_8l = 0;
    for it_29_8l in fv_29_8 {
        e_29_8l = _emit_node(it_29_8l);
        PyList_SetItem(v_29_8, li_29_8l, e_29_8l);
        li_29_8l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_29_8);
    Py_DecRef(v_29_8);

    fv_29_9 = nd.bb_out;
    v_29_9 = PyList_New(len(fv_29_9));
    li_29_9l = 0;
    for it_29_9l in fv_29_9 {
        e_29_9l = _emit_node(it_29_9l);
        PyList_SetItem(v_29_9, li_29_9l, e_29_9l);
        li_29_9l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_29_9);
    Py_DecRef(v_29_9);

    fv_29_10 = nd.affected_symbols;
    v_29_10 = PySet_New(0);
    if len(fv_29_10) != 0 {
        Py_DecRef(v_29_10);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_29_10);
    Py_DecRef(v_29_10);

    fv_29_11 = nd.scope_name;
    v_29_11 = _py_str(fv_29_11);
    PyDict_SetItem(d_h, _mat_keys[18], v_29_11);
    Py_DecRef(v_29_11);

    fv_29_12 = nd.parent_scope;
    if fv_29_12 is None {
        v_29_12 = _py_none();
    } else {
        v_29_12 = _emit_node(fv_29_12);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_29_12);
    Py_DecRef(v_29_12);

    fv_29_13 = nd.kid_scope;
    v_29_13 = PyList_New(len(fv_29_13));
    li_29_13l = 0;
    for it_29_13l in fv_29_13 {
        e_29_13l = _emit_node(it_29_13l);
        PyList_SetItem(v_29_13, li_29_13l, e_29_13l);
        li_29_13l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_29_13);
    Py_DecRef(v_29_13);

    fv_29_14 = nd.names_in_scope;
    v_29_14 = PyDict_New();
    for (dk_29_14d, dv_29_14d) in fv_29_14.items() {
        kh_29_14d = _py_str(dk_29_14d);
        vh_29_14d = _emit_Symbol(dv_29_14d);
        PyDict_SetItem(v_29_14, kh_29_14d, vh_29_14d);
        Py_DecRef(kh_29_14d);
        Py_DecRef(vh_29_14d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_29_14);
    Py_DecRef(v_29_14);

    fv_29_15 = nd.names_in_scope_overload;
    v_29_15 = PyDict_New();
    for (dk_29_15d, dv_29_15d) in fv_29_15.items() {
        kh_29_15d = _py_str(dk_29_15d);
        vh_29_15d = PyList_New(len(dv_29_15d));
        li_29_15dl = 0;
        for it_29_15dl in dv_29_15d {
            e_29_15dl = _emit_Symbol(it_29_15dl);
            PyList_SetItem(vh_29_15d, li_29_15dl, e_29_15dl);
            li_29_15dl += 1;
        }
        PyDict_SetItem(v_29_15, kh_29_15d, vh_29_15d);
        Py_DecRef(kh_29_15d);
        Py_DecRef(vh_29_15d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_29_15);
    Py_DecRef(v_29_15);

    fv_29_16 = nd.implicit_rebinds;
    v_29_16 = PyDict_New();
    for (dk_29_16d, dv_29_16d) in fv_29_16.items() {
        kh_29_16d = _py_str(dk_29_16d);
        vh_29_16d = _emit_Symbol(dv_29_16d);
        PyDict_SetItem(v_29_16, kh_29_16d, vh_29_16d);
        Py_DecRef(kh_29_16d);
        Py_DecRef(vh_29_16d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_29_16);
    Py_DecRef(v_29_16);

    fv_29_17 = nd.iter;
    v_29_17 = _emit_node(fv_29_17);
    PyDict_SetItem(d_h, _mat_keys[85], v_29_17);
    Py_DecRef(v_29_17);

    fv_29_18 = nd.condition;
    v_29_18 = _emit_node(fv_29_18);
    PyDict_SetItem(d_h, _mat_keys[77], v_29_18);
    Py_DecRef(v_29_18);

    fv_29_19 = nd.count_by;
    v_29_19 = _emit_node(fv_29_19);
    PyDict_SetItem(d_h, _mat_keys[86], v_29_19);
    Py_DecRef(v_29_19);

    fv_29_20 = nd.body;
    v_29_20 = PyList_New(len(fv_29_20));
    li_29_20l = 0;
    for it_29_20l in fv_29_20 {
        e_29_20l = _emit_node(it_29_20l);
        PyList_SetItem(v_29_20, li_29_20l, e_29_20l);
        li_29_20l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_29_20);
    Py_DecRef(v_29_20);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_Literal(nd: Literal) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[30], _mat_classes[30]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_30_0 = nd.kid;
    v_30_0 = PyList_New(len(fv_30_0));
    li_30_0l = 0;
    for it_30_0l in fv_30_0 {
        e_30_0l = _emit_node(it_30_0l);
        PyList_SetItem(v_30_0, li_30_0l, e_30_0l);
        li_30_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_30_0);
    Py_DecRef(v_30_0);

    fv_30_1 = nd.parent;
    if fv_30_1 is None {
        v_30_1 = _py_none();
    } else {
        v_30_1 = _emit_node(fv_30_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_30_1);
    Py_DecRef(v_30_1);

    v_30_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_30_2);
    Py_DecRef(v_30_2);

    fv_30_3 = nd._in_mod_nodes;
    v_30_3 = PyList_New(len(fv_30_3));
    li_30_3l = 0;
    for it_30_3l in fv_30_3 {
        e_30_3l = _emit_node(it_30_3l);
        PyList_SetItem(v_30_3, li_30_3l, e_30_3l);
        li_30_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_30_3);
    Py_DecRef(v_30_3);

    v_30_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_30_4);
    Py_DecRef(v_30_4);

    fv_30_5 = nd.loc;
    v_30_5 = _emit_CodeLocInfo(fv_30_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_30_5);
    Py_DecRef(v_30_5);

    fv_30_6 = nd.orig_src;
    v_30_6 = _emit_node(fv_30_6);
    PyDict_SetItem(d_h, _mat_keys[41], v_30_6);
    Py_DecRef(v_30_6);

    fv_30_7 = nd.name;
    v_30_7 = _py_str(fv_30_7);
    PyDict_SetItem(d_h, _mat_keys[24], v_30_7);
    Py_DecRef(v_30_7);

    fv_30_8 = nd.value;
    v_30_8 = _py_str(fv_30_8);
    PyDict_SetItem(d_h, _mat_keys[42], v_30_8);
    Py_DecRef(v_30_8);

    fv_30_9 = nd.line_no;
    v_30_9 = PyLong_FromLongLong(fv_30_9);
    PyDict_SetItem(d_h, _mat_keys[43], v_30_9);
    Py_DecRef(v_30_9);

    fv_30_10 = nd.end_line;
    v_30_10 = PyLong_FromLongLong(fv_30_10);
    PyDict_SetItem(d_h, _mat_keys[44], v_30_10);
    Py_DecRef(v_30_10);

    fv_30_11 = nd.c_start;
    v_30_11 = PyLong_FromLongLong(fv_30_11);
    PyDict_SetItem(d_h, _mat_keys[45], v_30_11);
    Py_DecRef(v_30_11);

    fv_30_12 = nd.c_end;
    v_30_12 = PyLong_FromLongLong(fv_30_12);
    PyDict_SetItem(d_h, _mat_keys[46], v_30_12);
    Py_DecRef(v_30_12);

    fv_30_13 = nd.pos_start;
    v_30_13 = PyLong_FromLongLong(fv_30_13);
    PyDict_SetItem(d_h, _mat_keys[47], v_30_13);
    Py_DecRef(v_30_13);

    fv_30_14 = nd.pos_end;
    v_30_14 = PyLong_FromLongLong(fv_30_14);
    PyDict_SetItem(d_h, _mat_keys[48], v_30_14);
    Py_DecRef(v_30_14);

    fv_30_15 = nd._is_synthetic;
    v_30_15 = PyBool_FromLong(1 if fv_30_15 else 0);
    PyDict_SetItem(d_h, _mat_keys[49], v_30_15);
    Py_DecRef(v_30_15);

    fv_30_16 = nd._type_sym_tab;
    if fv_30_16 is None {
        v_30_16 = _py_none();
    } else {
        v_30_16 = _emit_node(fv_30_16);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_30_16);
    Py_DecRef(v_30_16);

    v_30_17 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_30_17);
    Py_DecRef(v_30_17);

    fv_30_18 = nd.attached_tokens;
    if fv_30_18 is None {
        v_30_18 = _py_none();
    } else {
        v_30_18 = PyList_New(len(fv_30_18));
        li_30_18l = 0;
        for it_30_18l in fv_30_18 {
            e_30_18l = _emit_node(it_30_18l);
            PyList_SetItem(v_30_18, li_30_18l, e_30_18l);
            li_30_18l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_30_18);
    Py_DecRef(v_30_18);

    fv_30_19 = nd.name_spec;
    v_30_19 = _emit_node(fv_30_19);
    PyDict_SetItem(d_h, _mat_keys[12], v_30_19);
    Py_DecRef(v_30_19);

    fv_30_20 = nd.semstr;
    v_30_20 = _py_str(fv_30_20);
    PyDict_SetItem(d_h, _mat_keys[13], v_30_20);
    Py_DecRef(v_30_20);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_NameAtom(nd: NameAtom) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[31], _mat_classes[31]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_31_0 = nd.kid;
    v_31_0 = PyList_New(len(fv_31_0));
    li_31_0l = 0;
    for it_31_0l in fv_31_0 {
        e_31_0l = _emit_node(it_31_0l);
        PyList_SetItem(v_31_0, li_31_0l, e_31_0l);
        li_31_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_31_0);
    Py_DecRef(v_31_0);

    fv_31_1 = nd.parent;
    if fv_31_1 is None {
        v_31_1 = _py_none();
    } else {
        v_31_1 = _emit_node(fv_31_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_31_1);
    Py_DecRef(v_31_1);

    v_31_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_31_2);
    Py_DecRef(v_31_2);

    fv_31_3 = nd._in_mod_nodes;
    v_31_3 = PyList_New(len(fv_31_3));
    li_31_3l = 0;
    for it_31_3l in fv_31_3 {
        e_31_3l = _emit_node(it_31_3l);
        PyList_SetItem(v_31_3, li_31_3l, e_31_3l);
        li_31_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_31_3);
    Py_DecRef(v_31_3);

    v_31_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_31_4);
    Py_DecRef(v_31_4);

    fv_31_5 = nd.loc;
    v_31_5 = _emit_CodeLocInfo(fv_31_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_31_5);
    Py_DecRef(v_31_5);

    fv_31_6 = nd._type_sym_tab;
    if fv_31_6 is None {
        v_31_6 = _py_none();
    } else {
        v_31_6 = _emit_node(fv_31_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_31_6);
    Py_DecRef(v_31_6);

    v_31_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_31_7);
    Py_DecRef(v_31_7);

    fv_31_8 = nd.attached_tokens;
    if fv_31_8 is None {
        v_31_8 = _py_none();
    } else {
        v_31_8 = PyList_New(len(fv_31_8));
        li_31_8l = 0;
        for it_31_8l in fv_31_8 {
            e_31_8l = _emit_node(it_31_8l);
            PyList_SetItem(v_31_8, li_31_8l, e_31_8l);
            li_31_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_31_8);
    Py_DecRef(v_31_8);

    fv_31_9 = nd.name_spec;
    v_31_9 = _emit_node(fv_31_9);
    PyDict_SetItem(d_h, _mat_keys[12], v_31_9);
    Py_DecRef(v_31_9);

    fv_31_10 = nd.semstr;
    v_31_10 = _py_str(fv_31_10);
    PyDict_SetItem(d_h, _mat_keys[13], v_31_10);
    Py_DecRef(v_31_10);

    fv_31_11 = nd.is_enum_stmt;
    v_31_11 = PyBool_FromLong(1 if fv_31_11 else 0);
    PyDict_SetItem(d_h, _mat_keys[53], v_31_11);
    Py_DecRef(v_31_11);

    fv_31_12 = nd.name_of;
    v_31_12 = _emit_node(fv_31_12);
    PyDict_SetItem(d_h, _mat_keys[54], v_31_12);
    Py_DecRef(v_31_12);

    fv_31_13 = nd._sym;
    if fv_31_13 is None {
        v_31_13 = _py_none();
    } else {
        v_31_13 = _emit_Symbol(fv_31_13);
    }
    PyDict_SetItem(d_h, _mat_keys[55], v_31_13);
    Py_DecRef(v_31_13);

    fv_31_14 = nd._sym_name;
    v_31_14 = _py_str(fv_31_14);
    PyDict_SetItem(d_h, _mat_keys[56], v_31_14);
    Py_DecRef(v_31_14);

    fv_31_15 = nd._sym_category;
    v_31_15 = _enum_SymbolType(fv_31_15);
    PyDict_SetItem(d_h, _mat_keys[57], v_31_15);
    Py_DecRef(v_31_15);

    fv_31_16 = nd._expr_ctx;
    v_31_16 = _enum_ExprCtx(fv_31_16);
    PyDict_SetItem(d_h, _mat_keys[58], v_31_16);
    Py_DecRef(v_31_16);

    fv_31_17 = nd.is_getattr_resolved;
    v_31_17 = PyBool_FromLong(1 if fv_31_17 else 0);
    PyDict_SetItem(d_h, _mat_keys[87], v_31_17);
    Py_DecRef(v_31_17);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_AssignCompr(nd: AssignCompr) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[32], _mat_classes[32]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_32_0 = nd.kid;
    v_32_0 = PyList_New(len(fv_32_0));
    li_32_0l = 0;
    for it_32_0l in fv_32_0 {
        e_32_0l = _emit_node(it_32_0l);
        PyList_SetItem(v_32_0, li_32_0l, e_32_0l);
        li_32_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_32_0);
    Py_DecRef(v_32_0);

    fv_32_1 = nd.parent;
    if fv_32_1 is None {
        v_32_1 = _py_none();
    } else {
        v_32_1 = _emit_node(fv_32_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_32_1);
    Py_DecRef(v_32_1);

    v_32_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_32_2);
    Py_DecRef(v_32_2);

    fv_32_3 = nd._in_mod_nodes;
    v_32_3 = PyList_New(len(fv_32_3));
    li_32_3l = 0;
    for it_32_3l in fv_32_3 {
        e_32_3l = _emit_node(it_32_3l);
        PyList_SetItem(v_32_3, li_32_3l, e_32_3l);
        li_32_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_32_3);
    Py_DecRef(v_32_3);

    v_32_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_32_4);
    Py_DecRef(v_32_4);

    fv_32_5 = nd.loc;
    v_32_5 = _emit_CodeLocInfo(fv_32_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_32_5);
    Py_DecRef(v_32_5);

    fv_32_6 = nd._type_sym_tab;
    if fv_32_6 is None {
        v_32_6 = _py_none();
    } else {
        v_32_6 = _emit_node(fv_32_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_32_6);
    Py_DecRef(v_32_6);

    v_32_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_32_7);
    Py_DecRef(v_32_7);

    fv_32_8 = nd.attached_tokens;
    if fv_32_8 is None {
        v_32_8 = _py_none();
    } else {
        v_32_8 = PyList_New(len(fv_32_8));
        li_32_8l = 0;
        for it_32_8l in fv_32_8 {
            e_32_8l = _emit_node(it_32_8l);
            PyList_SetItem(v_32_8, li_32_8l, e_32_8l);
            li_32_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_32_8);
    Py_DecRef(v_32_8);

    fv_32_9 = nd.name_spec;
    v_32_9 = _emit_node(fv_32_9);
    PyDict_SetItem(d_h, _mat_keys[12], v_32_9);
    Py_DecRef(v_32_9);

    fv_32_10 = nd.semstr;
    v_32_10 = _py_str(fv_32_10);
    PyDict_SetItem(d_h, _mat_keys[13], v_32_10);
    Py_DecRef(v_32_10);

    fv_32_11 = nd.assigns;
    v_32_11 = PyList_New(len(fv_32_11));
    li_32_11l = 0;
    for it_32_11l in fv_32_11 {
        e_32_11l = _emit_node(it_32_11l);
        PyList_SetItem(v_32_11, li_32_11l, e_32_11l);
        li_32_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[88], v_32_11);
    Py_DecRef(v_32_11);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_Assignment(nd: Assignment) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[33], _mat_classes[33]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_33_0 = nd.kid;
    v_33_0 = PyList_New(len(fv_33_0));
    li_33_0l = 0;
    for it_33_0l in fv_33_0 {
        e_33_0l = _emit_node(it_33_0l);
        PyList_SetItem(v_33_0, li_33_0l, e_33_0l);
        li_33_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_33_0);
    Py_DecRef(v_33_0);

    fv_33_1 = nd.parent;
    if fv_33_1 is None {
        v_33_1 = _py_none();
    } else {
        v_33_1 = _emit_node(fv_33_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_33_1);
    Py_DecRef(v_33_1);

    v_33_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_33_2);
    Py_DecRef(v_33_2);

    fv_33_3 = nd._in_mod_nodes;
    v_33_3 = PyList_New(len(fv_33_3));
    li_33_3l = 0;
    for it_33_3l in fv_33_3 {
        e_33_3l = _emit_node(it_33_3l);
        PyList_SetItem(v_33_3, li_33_3l, e_33_3l);
        li_33_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_33_3);
    Py_DecRef(v_33_3);

    v_33_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_33_4);
    Py_DecRef(v_33_4);

    fv_33_5 = nd.loc;
    v_33_5 = _emit_CodeLocInfo(fv_33_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_33_5);
    Py_DecRef(v_33_5);

    fv_33_6 = nd.type_tag;
    if fv_33_6 is None {
        v_33_6 = _py_none();
    } else {
        v_33_6 = _emit_node(fv_33_6);
    }
    PyDict_SetItem(d_h, _mat_keys[89], v_33_6);
    Py_DecRef(v_33_6);

    fv_33_7 = nd.is_enum_stmt;
    v_33_7 = PyBool_FromLong(1 if fv_33_7 else 0);
    PyDict_SetItem(d_h, _mat_keys[53], v_33_7);
    Py_DecRef(v_33_7);

    fv_33_8 = nd.bb_in;
    v_33_8 = PyList_New(len(fv_33_8));
    li_33_8l = 0;
    for it_33_8l in fv_33_8 {
        e_33_8l = _emit_node(it_33_8l);
        PyList_SetItem(v_33_8, li_33_8l, e_33_8l);
        li_33_8l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_33_8);
    Py_DecRef(v_33_8);

    fv_33_9 = nd.bb_out;
    v_33_9 = PyList_New(len(fv_33_9));
    li_33_9l = 0;
    for it_33_9l in fv_33_9 {
        e_33_9l = _emit_node(it_33_9l);
        PyList_SetItem(v_33_9, li_33_9l, e_33_9l);
        li_33_9l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_33_9);
    Py_DecRef(v_33_9);

    fv_33_10 = nd.affected_symbols;
    v_33_10 = PySet_New(0);
    if len(fv_33_10) != 0 {
        Py_DecRef(v_33_10);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_33_10);
    Py_DecRef(v_33_10);

    fv_33_11 = nd.target;
    v_33_11 = PyList_New(len(fv_33_11));
    li_33_11l = 0;
    for it_33_11l in fv_33_11 {
        e_33_11l = _emit_node(it_33_11l);
        PyList_SetItem(v_33_11, li_33_11l, e_33_11l);
        li_33_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[60], v_33_11);
    Py_DecRef(v_33_11);

    fv_33_12 = nd.value;
    if fv_33_12 is None {
        v_33_12 = _py_none();
    } else {
        if isinstance(fv_33_12, Expr) {
            v_33_12 = _emit_node(fv_33_12);
        } elif isinstance(fv_33_12, YieldExpr) {
            v_33_12 = _emit_node(fv_33_12);
        } else {
            v_33_12 = _py_none();
        }
    }
    PyDict_SetItem(d_h, _mat_keys[42], v_33_12);
    Py_DecRef(v_33_12);

    fv_33_13 = nd.mutable;
    v_33_13 = PyBool_FromLong(1 if fv_33_13 else 0);
    PyDict_SetItem(d_h, _mat_keys[90], v_33_13);
    Py_DecRef(v_33_13);

    fv_33_14 = nd.aug_op;
    if fv_33_14 is None {
        v_33_14 = _py_none();
    } else {
        v_33_14 = _emit_node(fv_33_14);
    }
    PyDict_SetItem(d_h, _mat_keys[91], v_33_14);
    Py_DecRef(v_33_14);

    fv_33_15 = nd.na_move_lowerable;
    v_33_15 = PyBool_FromLong(1 if fv_33_15 else 0);
    PyDict_SetItem(d_h, _mat_keys[92], v_33_15);
    Py_DecRef(v_33_15);

    fv_33_16 = nd.na_overwrite_consumed;
    v_33_16 = PyBool_FromLong(1 if fv_33_16 else 0);
    PyDict_SetItem(d_h, _mat_keys[93], v_33_16);
    Py_DecRef(v_33_16);

    fv_33_17 = nd.na_flow_reduce;
    v_33_17 = _py_str(fv_33_17);
    PyDict_SetItem(d_h, _mat_keys[94], v_33_17);
    Py_DecRef(v_33_17);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_CtElse(nd: CtElse) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[34], _mat_classes[34]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_34_0 = nd.kid;
    v_34_0 = PyList_New(len(fv_34_0));
    li_34_0l = 0;
    for it_34_0l in fv_34_0 {
        e_34_0l = _emit_node(it_34_0l);
        PyList_SetItem(v_34_0, li_34_0l, e_34_0l);
        li_34_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_34_0);
    Py_DecRef(v_34_0);

    fv_34_1 = nd.parent;
    if fv_34_1 is None {
        v_34_1 = _py_none();
    } else {
        v_34_1 = _emit_node(fv_34_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_34_1);
    Py_DecRef(v_34_1);

    v_34_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_34_2);
    Py_DecRef(v_34_2);

    fv_34_3 = nd._in_mod_nodes;
    v_34_3 = PyList_New(len(fv_34_3));
    li_34_3l = 0;
    for it_34_3l in fv_34_3 {
        e_34_3l = _emit_node(it_34_3l);
        PyList_SetItem(v_34_3, li_34_3l, e_34_3l);
        li_34_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_34_3);
    Py_DecRef(v_34_3);

    v_34_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_34_4);
    Py_DecRef(v_34_4);

    fv_34_5 = nd.loc;
    v_34_5 = _emit_CodeLocInfo(fv_34_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_34_5);
    Py_DecRef(v_34_5);

    fv_34_6 = nd.doc;
    if fv_34_6 is None {
        v_34_6 = _py_none();
    } else {
        v_34_6 = _emit_node(fv_34_6);
    }
    PyDict_SetItem(d_h, _mat_keys[8], v_34_6);
    Py_DecRef(v_34_6);

    fv_34_7 = nd.bb_in;
    v_34_7 = PyList_New(len(fv_34_7));
    li_34_7l = 0;
    for it_34_7l in fv_34_7 {
        e_34_7l = _emit_node(it_34_7l);
        PyList_SetItem(v_34_7, li_34_7l, e_34_7l);
        li_34_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_34_7);
    Py_DecRef(v_34_7);

    fv_34_8 = nd.bb_out;
    v_34_8 = PyList_New(len(fv_34_8));
    li_34_8l = 0;
    for it_34_8l in fv_34_8 {
        e_34_8l = _emit_node(it_34_8l);
        PyList_SetItem(v_34_8, li_34_8l, e_34_8l);
        li_34_8l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_34_8);
    Py_DecRef(v_34_8);

    fv_34_9 = nd.affected_symbols;
    v_34_9 = PySet_New(0);
    if len(fv_34_9) != 0 {
        Py_DecRef(v_34_9);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_34_9);
    Py_DecRef(v_34_9);

    fv_34_10 = nd.body;
    v_34_10 = PyList_New(len(fv_34_10));
    li_34_10l = 0;
    for it_34_10l in fv_34_10 {
        e_34_10l = _emit_node(it_34_10l);
        PyList_SetItem(v_34_10, li_34_10l, e_34_10l);
        li_34_10l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_34_10);
    Py_DecRef(v_34_10);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_CtFor(nd: CtFor) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[35], _mat_classes[35]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_35_0 = nd.kid;
    v_35_0 = PyList_New(len(fv_35_0));
    li_35_0l = 0;
    for it_35_0l in fv_35_0 {
        e_35_0l = _emit_node(it_35_0l);
        PyList_SetItem(v_35_0, li_35_0l, e_35_0l);
        li_35_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_35_0);
    Py_DecRef(v_35_0);

    fv_35_1 = nd.parent;
    if fv_35_1 is None {
        v_35_1 = _py_none();
    } else {
        v_35_1 = _emit_node(fv_35_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_35_1);
    Py_DecRef(v_35_1);

    v_35_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_35_2);
    Py_DecRef(v_35_2);

    fv_35_3 = nd._in_mod_nodes;
    v_35_3 = PyList_New(len(fv_35_3));
    li_35_3l = 0;
    for it_35_3l in fv_35_3 {
        e_35_3l = _emit_node(it_35_3l);
        PyList_SetItem(v_35_3, li_35_3l, e_35_3l);
        li_35_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_35_3);
    Py_DecRef(v_35_3);

    v_35_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_35_4);
    Py_DecRef(v_35_4);

    fv_35_5 = nd.loc;
    v_35_5 = _emit_CodeLocInfo(fv_35_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_35_5);
    Py_DecRef(v_35_5);

    fv_35_6 = nd.doc;
    if fv_35_6 is None {
        v_35_6 = _py_none();
    } else {
        v_35_6 = _emit_node(fv_35_6);
    }
    PyDict_SetItem(d_h, _mat_keys[8], v_35_6);
    Py_DecRef(v_35_6);

    fv_35_7 = nd.bb_in;
    v_35_7 = PyList_New(len(fv_35_7));
    li_35_7l = 0;
    for it_35_7l in fv_35_7 {
        e_35_7l = _emit_node(it_35_7l);
        PyList_SetItem(v_35_7, li_35_7l, e_35_7l);
        li_35_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_35_7);
    Py_DecRef(v_35_7);

    fv_35_8 = nd.bb_out;
    v_35_8 = PyList_New(len(fv_35_8));
    li_35_8l = 0;
    for it_35_8l in fv_35_8 {
        e_35_8l = _emit_node(it_35_8l);
        PyList_SetItem(v_35_8, li_35_8l, e_35_8l);
        li_35_8l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_35_8);
    Py_DecRef(v_35_8);

    fv_35_9 = nd.affected_symbols;
    v_35_9 = PySet_New(0);
    if len(fv_35_9) != 0 {
        Py_DecRef(v_35_9);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_35_9);
    Py_DecRef(v_35_9);

    fv_35_10 = nd.target;
    v_35_10 = _emit_node(fv_35_10);
    PyDict_SetItem(d_h, _mat_keys[60], v_35_10);
    Py_DecRef(v_35_10);

    fv_35_11 = nd.iter;
    v_35_11 = _emit_node(fv_35_11);
    PyDict_SetItem(d_h, _mat_keys[85], v_35_11);
    Py_DecRef(v_35_11);

    fv_35_12 = nd.body;
    v_35_12 = PyList_New(len(fv_35_12));
    li_35_12l = 0;
    for it_35_12l in fv_35_12 {
        e_35_12l = _emit_node(it_35_12l);
        PyList_SetItem(v_35_12, li_35_12l, e_35_12l);
        li_35_12l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_35_12);
    Py_DecRef(v_35_12);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_CtIf(nd: CtIf) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[36], _mat_classes[36]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_36_0 = nd.kid;
    v_36_0 = PyList_New(len(fv_36_0));
    li_36_0l = 0;
    for it_36_0l in fv_36_0 {
        e_36_0l = _emit_node(it_36_0l);
        PyList_SetItem(v_36_0, li_36_0l, e_36_0l);
        li_36_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_36_0);
    Py_DecRef(v_36_0);

    fv_36_1 = nd.parent;
    if fv_36_1 is None {
        v_36_1 = _py_none();
    } else {
        v_36_1 = _emit_node(fv_36_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_36_1);
    Py_DecRef(v_36_1);

    v_36_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_36_2);
    Py_DecRef(v_36_2);

    fv_36_3 = nd._in_mod_nodes;
    v_36_3 = PyList_New(len(fv_36_3));
    li_36_3l = 0;
    for it_36_3l in fv_36_3 {
        e_36_3l = _emit_node(it_36_3l);
        PyList_SetItem(v_36_3, li_36_3l, e_36_3l);
        li_36_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_36_3);
    Py_DecRef(v_36_3);

    v_36_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_36_4);
    Py_DecRef(v_36_4);

    fv_36_5 = nd.loc;
    v_36_5 = _emit_CodeLocInfo(fv_36_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_36_5);
    Py_DecRef(v_36_5);

    fv_36_6 = nd.doc;
    if fv_36_6 is None {
        v_36_6 = _py_none();
    } else {
        v_36_6 = _emit_node(fv_36_6);
    }
    PyDict_SetItem(d_h, _mat_keys[8], v_36_6);
    Py_DecRef(v_36_6);

    fv_36_7 = nd.bb_in;
    v_36_7 = PyList_New(len(fv_36_7));
    li_36_7l = 0;
    for it_36_7l in fv_36_7 {
        e_36_7l = _emit_node(it_36_7l);
        PyList_SetItem(v_36_7, li_36_7l, e_36_7l);
        li_36_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_36_7);
    Py_DecRef(v_36_7);

    fv_36_8 = nd.bb_out;
    v_36_8 = PyList_New(len(fv_36_8));
    li_36_8l = 0;
    for it_36_8l in fv_36_8 {
        e_36_8l = _emit_node(it_36_8l);
        PyList_SetItem(v_36_8, li_36_8l, e_36_8l);
        li_36_8l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_36_8);
    Py_DecRef(v_36_8);

    fv_36_9 = nd.affected_symbols;
    v_36_9 = PySet_New(0);
    if len(fv_36_9) != 0 {
        Py_DecRef(v_36_9);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_36_9);
    Py_DecRef(v_36_9);

    fv_36_10 = nd.condition;
    v_36_10 = _emit_node(fv_36_10);
    PyDict_SetItem(d_h, _mat_keys[77], v_36_10);
    Py_DecRef(v_36_10);

    fv_36_11 = nd.body;
    v_36_11 = PyList_New(len(fv_36_11));
    li_36_11l = 0;
    for it_36_11l in fv_36_11 {
        e_36_11l = _emit_node(it_36_11l);
        PyList_SetItem(v_36_11, li_36_11l, e_36_11l);
        li_36_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_36_11);
    Py_DecRef(v_36_11);

    fv_36_12 = nd.else_body;
    if fv_36_12 is None {
        v_36_12 = _py_none();
    } else {
        v_36_12 = _emit_node(fv_36_12);
    }
    PyDict_SetItem(d_h, _mat_keys[76], v_36_12);
    Py_DecRef(v_36_12);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_DictVal(nd: DictVal) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[37], _mat_classes[37]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_37_0 = nd.kid;
    v_37_0 = PyList_New(len(fv_37_0));
    li_37_0l = 0;
    for it_37_0l in fv_37_0 {
        e_37_0l = _emit_node(it_37_0l);
        PyList_SetItem(v_37_0, li_37_0l, e_37_0l);
        li_37_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_37_0);
    Py_DecRef(v_37_0);

    fv_37_1 = nd.parent;
    if fv_37_1 is None {
        v_37_1 = _py_none();
    } else {
        v_37_1 = _emit_node(fv_37_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_37_1);
    Py_DecRef(v_37_1);

    v_37_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_37_2);
    Py_DecRef(v_37_2);

    fv_37_3 = nd._in_mod_nodes;
    v_37_3 = PyList_New(len(fv_37_3));
    li_37_3l = 0;
    for it_37_3l in fv_37_3 {
        e_37_3l = _emit_node(it_37_3l);
        PyList_SetItem(v_37_3, li_37_3l, e_37_3l);
        li_37_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_37_3);
    Py_DecRef(v_37_3);

    v_37_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_37_4);
    Py_DecRef(v_37_4);

    fv_37_5 = nd.loc;
    v_37_5 = _emit_CodeLocInfo(fv_37_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_37_5);
    Py_DecRef(v_37_5);

    fv_37_6 = nd._type_sym_tab;
    if fv_37_6 is None {
        v_37_6 = _py_none();
    } else {
        v_37_6 = _emit_node(fv_37_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_37_6);
    Py_DecRef(v_37_6);

    v_37_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_37_7);
    Py_DecRef(v_37_7);

    fv_37_8 = nd.attached_tokens;
    if fv_37_8 is None {
        v_37_8 = _py_none();
    } else {
        v_37_8 = PyList_New(len(fv_37_8));
        li_37_8l = 0;
        for it_37_8l in fv_37_8 {
            e_37_8l = _emit_node(it_37_8l);
            PyList_SetItem(v_37_8, li_37_8l, e_37_8l);
            li_37_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_37_8);
    Py_DecRef(v_37_8);

    fv_37_9 = nd.name_spec;
    v_37_9 = _emit_node(fv_37_9);
    PyDict_SetItem(d_h, _mat_keys[12], v_37_9);
    Py_DecRef(v_37_9);

    fv_37_10 = nd.semstr;
    v_37_10 = _py_str(fv_37_10);
    PyDict_SetItem(d_h, _mat_keys[13], v_37_10);
    Py_DecRef(v_37_10);

    fv_37_11 = nd.kv_pairs;
    v_37_11 = PyList_New(len(fv_37_11));
    li_37_11l = 0;
    for it_37_11l in fv_37_11 {
        e_37_11l = _emit_node(it_37_11l);
        PyList_SetItem(v_37_11, li_37_11l, e_37_11l);
        li_37_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[95], v_37_11);
    Py_DecRef(v_37_11);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_FString(nd: FString) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[38], _mat_classes[38]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_38_0 = nd.kid;
    v_38_0 = PyList_New(len(fv_38_0));
    li_38_0l = 0;
    for it_38_0l in fv_38_0 {
        e_38_0l = _emit_node(it_38_0l);
        PyList_SetItem(v_38_0, li_38_0l, e_38_0l);
        li_38_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_38_0);
    Py_DecRef(v_38_0);

    fv_38_1 = nd.parent;
    if fv_38_1 is None {
        v_38_1 = _py_none();
    } else {
        v_38_1 = _emit_node(fv_38_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_38_1);
    Py_DecRef(v_38_1);

    v_38_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_38_2);
    Py_DecRef(v_38_2);

    fv_38_3 = nd._in_mod_nodes;
    v_38_3 = PyList_New(len(fv_38_3));
    li_38_3l = 0;
    for it_38_3l in fv_38_3 {
        e_38_3l = _emit_node(it_38_3l);
        PyList_SetItem(v_38_3, li_38_3l, e_38_3l);
        li_38_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_38_3);
    Py_DecRef(v_38_3);

    v_38_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_38_4);
    Py_DecRef(v_38_4);

    fv_38_5 = nd.loc;
    v_38_5 = _emit_CodeLocInfo(fv_38_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_38_5);
    Py_DecRef(v_38_5);

    fv_38_6 = nd._type_sym_tab;
    if fv_38_6 is None {
        v_38_6 = _py_none();
    } else {
        v_38_6 = _emit_node(fv_38_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_38_6);
    Py_DecRef(v_38_6);

    v_38_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_38_7);
    Py_DecRef(v_38_7);

    fv_38_8 = nd.attached_tokens;
    if fv_38_8 is None {
        v_38_8 = _py_none();
    } else {
        v_38_8 = PyList_New(len(fv_38_8));
        li_38_8l = 0;
        for it_38_8l in fv_38_8 {
            e_38_8l = _emit_node(it_38_8l);
            PyList_SetItem(v_38_8, li_38_8l, e_38_8l);
            li_38_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_38_8);
    Py_DecRef(v_38_8);

    fv_38_9 = nd.name_spec;
    v_38_9 = _emit_node(fv_38_9);
    PyDict_SetItem(d_h, _mat_keys[12], v_38_9);
    Py_DecRef(v_38_9);

    fv_38_10 = nd.semstr;
    v_38_10 = _py_str(fv_38_10);
    PyDict_SetItem(d_h, _mat_keys[13], v_38_10);
    Py_DecRef(v_38_10);

    fv_38_11 = nd.start;
    if fv_38_11 is None {
        v_38_11 = _py_none();
    } else {
        v_38_11 = _emit_node(fv_38_11);
    }
    PyDict_SetItem(d_h, _mat_keys[96], v_38_11);
    Py_DecRef(v_38_11);

    fv_38_12 = nd.parts;
    v_38_12 = PyList_New(len(fv_38_12));
    li_38_12l = 0;
    for it_38_12l in fv_38_12 {
        e_38_12l = _emit_node(it_38_12l);
        PyList_SetItem(v_38_12, li_38_12l, e_38_12l);
        li_38_12l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[97], v_38_12);
    Py_DecRef(v_38_12);

    fv_38_13 = nd.end;
    if fv_38_13 is None {
        v_38_13 = _py_none();
    } else {
        v_38_13 = _emit_node(fv_38_13);
    }
    PyDict_SetItem(d_h, _mat_keys[98], v_38_13);
    Py_DecRef(v_38_13);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_FilterCompr(nd: FilterCompr) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[39], _mat_classes[39]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_39_0 = nd.kid;
    v_39_0 = PyList_New(len(fv_39_0));
    li_39_0l = 0;
    for it_39_0l in fv_39_0 {
        e_39_0l = _emit_node(it_39_0l);
        PyList_SetItem(v_39_0, li_39_0l, e_39_0l);
        li_39_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_39_0);
    Py_DecRef(v_39_0);

    fv_39_1 = nd.parent;
    if fv_39_1 is None {
        v_39_1 = _py_none();
    } else {
        v_39_1 = _emit_node(fv_39_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_39_1);
    Py_DecRef(v_39_1);

    v_39_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_39_2);
    Py_DecRef(v_39_2);

    fv_39_3 = nd._in_mod_nodes;
    v_39_3 = PyList_New(len(fv_39_3));
    li_39_3l = 0;
    for it_39_3l in fv_39_3 {
        e_39_3l = _emit_node(it_39_3l);
        PyList_SetItem(v_39_3, li_39_3l, e_39_3l);
        li_39_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_39_3);
    Py_DecRef(v_39_3);

    v_39_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_39_4);
    Py_DecRef(v_39_4);

    fv_39_5 = nd.loc;
    v_39_5 = _emit_CodeLocInfo(fv_39_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_39_5);
    Py_DecRef(v_39_5);

    fv_39_6 = nd._type_sym_tab;
    if fv_39_6 is None {
        v_39_6 = _py_none();
    } else {
        v_39_6 = _emit_node(fv_39_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_39_6);
    Py_DecRef(v_39_6);

    v_39_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_39_7);
    Py_DecRef(v_39_7);

    fv_39_8 = nd.attached_tokens;
    if fv_39_8 is None {
        v_39_8 = _py_none();
    } else {
        v_39_8 = PyList_New(len(fv_39_8));
        li_39_8l = 0;
        for it_39_8l in fv_39_8 {
            e_39_8l = _emit_node(it_39_8l);
            PyList_SetItem(v_39_8, li_39_8l, e_39_8l);
            li_39_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_39_8);
    Py_DecRef(v_39_8);

    fv_39_9 = nd.name_spec;
    v_39_9 = _emit_node(fv_39_9);
    PyDict_SetItem(d_h, _mat_keys[12], v_39_9);
    Py_DecRef(v_39_9);

    fv_39_10 = nd.semstr;
    v_39_10 = _py_str(fv_39_10);
    PyDict_SetItem(d_h, _mat_keys[13], v_39_10);
    Py_DecRef(v_39_10);

    fv_39_11 = nd.f_type;
    if fv_39_11 is None {
        v_39_11 = _py_none();
    } else {
        v_39_11 = _emit_node(fv_39_11);
    }
    PyDict_SetItem(d_h, _mat_keys[99], v_39_11);
    Py_DecRef(v_39_11);

    fv_39_12 = nd.compares;
    v_39_12 = PyList_New(len(fv_39_12));
    li_39_12l = 0;
    for it_39_12l in fv_39_12 {
        e_39_12l = _emit_node(it_39_12l);
        PyList_SetItem(v_39_12, li_39_12l, e_39_12l);
        li_39_12l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[100], v_39_12);
    Py_DecRef(v_39_12);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_IfStmt(nd: IfStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[40], _mat_classes[40]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_40_0 = nd.kid;
    v_40_0 = PyList_New(len(fv_40_0));
    li_40_0l = 0;
    for it_40_0l in fv_40_0 {
        e_40_0l = _emit_node(it_40_0l);
        PyList_SetItem(v_40_0, li_40_0l, e_40_0l);
        li_40_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_40_0);
    Py_DecRef(v_40_0);

    fv_40_1 = nd.parent;
    if fv_40_1 is None {
        v_40_1 = _py_none();
    } else {
        v_40_1 = _emit_node(fv_40_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_40_1);
    Py_DecRef(v_40_1);

    v_40_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_40_2);
    Py_DecRef(v_40_2);

    fv_40_3 = nd._in_mod_nodes;
    v_40_3 = PyList_New(len(fv_40_3));
    li_40_3l = 0;
    for it_40_3l in fv_40_3 {
        e_40_3l = _emit_node(it_40_3l);
        PyList_SetItem(v_40_3, li_40_3l, e_40_3l);
        li_40_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_40_3);
    Py_DecRef(v_40_3);

    v_40_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_40_4);
    Py_DecRef(v_40_4);

    fv_40_5 = nd.loc;
    v_40_5 = _emit_CodeLocInfo(fv_40_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_40_5);
    Py_DecRef(v_40_5);

    fv_40_6 = nd.bb_in;
    v_40_6 = PyList_New(len(fv_40_6));
    li_40_6l = 0;
    for it_40_6l in fv_40_6 {
        e_40_6l = _emit_node(it_40_6l);
        PyList_SetItem(v_40_6, li_40_6l, e_40_6l);
        li_40_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_40_6);
    Py_DecRef(v_40_6);

    fv_40_7 = nd.bb_out;
    v_40_7 = PyList_New(len(fv_40_7));
    li_40_7l = 0;
    for it_40_7l in fv_40_7 {
        e_40_7l = _emit_node(it_40_7l);
        PyList_SetItem(v_40_7, li_40_7l, e_40_7l);
        li_40_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_40_7);
    Py_DecRef(v_40_7);

    fv_40_8 = nd.affected_symbols;
    v_40_8 = PySet_New(0);
    if len(fv_40_8) != 0 {
        Py_DecRef(v_40_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_40_8);
    Py_DecRef(v_40_8);

    fv_40_9 = nd.else_body;
    if fv_40_9 is None {
        v_40_9 = _py_none();
    } else {
        if isinstance(fv_40_9, ElseStmt) {
            v_40_9 = _emit_node(fv_40_9);
        } elif isinstance(fv_40_9, ElseIf) {
            v_40_9 = _emit_node(fv_40_9);
        } else {
            v_40_9 = _py_none();
        }
    }
    PyDict_SetItem(d_h, _mat_keys[76], v_40_9);
    Py_DecRef(v_40_9);

    fv_40_10 = nd.scope_name;
    v_40_10 = _py_str(fv_40_10);
    PyDict_SetItem(d_h, _mat_keys[18], v_40_10);
    Py_DecRef(v_40_10);

    fv_40_11 = nd.parent_scope;
    if fv_40_11 is None {
        v_40_11 = _py_none();
    } else {
        v_40_11 = _emit_node(fv_40_11);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_40_11);
    Py_DecRef(v_40_11);

    fv_40_12 = nd.kid_scope;
    v_40_12 = PyList_New(len(fv_40_12));
    li_40_12l = 0;
    for it_40_12l in fv_40_12 {
        e_40_12l = _emit_node(it_40_12l);
        PyList_SetItem(v_40_12, li_40_12l, e_40_12l);
        li_40_12l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_40_12);
    Py_DecRef(v_40_12);

    fv_40_13 = nd.names_in_scope;
    v_40_13 = PyDict_New();
    for (dk_40_13d, dv_40_13d) in fv_40_13.items() {
        kh_40_13d = _py_str(dk_40_13d);
        vh_40_13d = _emit_Symbol(dv_40_13d);
        PyDict_SetItem(v_40_13, kh_40_13d, vh_40_13d);
        Py_DecRef(kh_40_13d);
        Py_DecRef(vh_40_13d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_40_13);
    Py_DecRef(v_40_13);

    fv_40_14 = nd.names_in_scope_overload;
    v_40_14 = PyDict_New();
    for (dk_40_14d, dv_40_14d) in fv_40_14.items() {
        kh_40_14d = _py_str(dk_40_14d);
        vh_40_14d = PyList_New(len(dv_40_14d));
        li_40_14dl = 0;
        for it_40_14dl in dv_40_14d {
            e_40_14dl = _emit_Symbol(it_40_14dl);
            PyList_SetItem(vh_40_14d, li_40_14dl, e_40_14dl);
            li_40_14dl += 1;
        }
        PyDict_SetItem(v_40_14, kh_40_14d, vh_40_14d);
        Py_DecRef(kh_40_14d);
        Py_DecRef(vh_40_14d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_40_14);
    Py_DecRef(v_40_14);

    fv_40_15 = nd.implicit_rebinds;
    v_40_15 = PyDict_New();
    for (dk_40_15d, dv_40_15d) in fv_40_15.items() {
        kh_40_15d = _py_str(dk_40_15d);
        vh_40_15d = _emit_Symbol(dv_40_15d);
        PyDict_SetItem(v_40_15, kh_40_15d, vh_40_15d);
        Py_DecRef(kh_40_15d);
        Py_DecRef(vh_40_15d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_40_15);
    Py_DecRef(v_40_15);

    fv_40_16 = nd.condition;
    v_40_16 = _emit_node(fv_40_16);
    PyDict_SetItem(d_h, _mat_keys[77], v_40_16);
    Py_DecRef(v_40_16);

    fv_40_17 = nd.body;
    v_40_17 = PyList_New(len(fv_40_17));
    li_40_17l = 0;
    for it_40_17l in fv_40_17 {
        e_40_17l = _emit_node(it_40_17l);
        PyList_SetItem(v_40_17, li_40_17l, e_40_17l);
        li_40_17l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_40_17);
    Py_DecRef(v_40_17);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_IndexSlice(nd: IndexSlice) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[41], _mat_classes[41]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_41_0 = nd.kid;
    v_41_0 = PyList_New(len(fv_41_0));
    li_41_0l = 0;
    for it_41_0l in fv_41_0 {
        e_41_0l = _emit_node(it_41_0l);
        PyList_SetItem(v_41_0, li_41_0l, e_41_0l);
        li_41_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_41_0);
    Py_DecRef(v_41_0);

    fv_41_1 = nd.parent;
    if fv_41_1 is None {
        v_41_1 = _py_none();
    } else {
        v_41_1 = _emit_node(fv_41_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_41_1);
    Py_DecRef(v_41_1);

    v_41_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_41_2);
    Py_DecRef(v_41_2);

    fv_41_3 = nd._in_mod_nodes;
    v_41_3 = PyList_New(len(fv_41_3));
    li_41_3l = 0;
    for it_41_3l in fv_41_3 {
        e_41_3l = _emit_node(it_41_3l);
        PyList_SetItem(v_41_3, li_41_3l, e_41_3l);
        li_41_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_41_3);
    Py_DecRef(v_41_3);

    v_41_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_41_4);
    Py_DecRef(v_41_4);

    fv_41_5 = nd.loc;
    v_41_5 = _emit_CodeLocInfo(fv_41_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_41_5);
    Py_DecRef(v_41_5);

    fv_41_6 = nd._type_sym_tab;
    if fv_41_6 is None {
        v_41_6 = _py_none();
    } else {
        v_41_6 = _emit_node(fv_41_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_41_6);
    Py_DecRef(v_41_6);

    v_41_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_41_7);
    Py_DecRef(v_41_7);

    fv_41_8 = nd.attached_tokens;
    if fv_41_8 is None {
        v_41_8 = _py_none();
    } else {
        v_41_8 = PyList_New(len(fv_41_8));
        li_41_8l = 0;
        for it_41_8l in fv_41_8 {
            e_41_8l = _emit_node(it_41_8l);
            PyList_SetItem(v_41_8, li_41_8l, e_41_8l);
            li_41_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_41_8);
    Py_DecRef(v_41_8);

    fv_41_9 = nd.name_spec;
    v_41_9 = _emit_node(fv_41_9);
    PyDict_SetItem(d_h, _mat_keys[12], v_41_9);
    Py_DecRef(v_41_9);

    fv_41_10 = nd.semstr;
    v_41_10 = _py_str(fv_41_10);
    PyDict_SetItem(d_h, _mat_keys[13], v_41_10);
    Py_DecRef(v_41_10);

    fv_41_11 = nd.slices;
    v_41_11 = PyList_New(len(fv_41_11));
    li_41_11l = 0;
    for it_41_11l in fv_41_11 {
        e_41_11l = _emit_node(it_41_11l);
        PyList_SetItem(v_41_11, li_41_11l, e_41_11l);
        li_41_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[101], v_41_11);
    Py_DecRef(v_41_11);

    fv_41_12 = nd.is_range;
    v_41_12 = PyBool_FromLong(1 if fv_41_12 else 0);
    PyDict_SetItem(d_h, _mat_keys[102], v_41_12);
    Py_DecRef(v_41_12);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_JsxElement(nd: JsxElement) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[42], _mat_classes[42]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_42_0 = nd.kid;
    v_42_0 = PyList_New(len(fv_42_0));
    li_42_0l = 0;
    for it_42_0l in fv_42_0 {
        e_42_0l = _emit_node(it_42_0l);
        PyList_SetItem(v_42_0, li_42_0l, e_42_0l);
        li_42_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_42_0);
    Py_DecRef(v_42_0);

    fv_42_1 = nd.parent;
    if fv_42_1 is None {
        v_42_1 = _py_none();
    } else {
        v_42_1 = _emit_node(fv_42_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_42_1);
    Py_DecRef(v_42_1);

    v_42_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_42_2);
    Py_DecRef(v_42_2);

    fv_42_3 = nd._in_mod_nodes;
    v_42_3 = PyList_New(len(fv_42_3));
    li_42_3l = 0;
    for it_42_3l in fv_42_3 {
        e_42_3l = _emit_node(it_42_3l);
        PyList_SetItem(v_42_3, li_42_3l, e_42_3l);
        li_42_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_42_3);
    Py_DecRef(v_42_3);

    v_42_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_42_4);
    Py_DecRef(v_42_4);

    fv_42_5 = nd.loc;
    v_42_5 = _emit_CodeLocInfo(fv_42_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_42_5);
    Py_DecRef(v_42_5);

    fv_42_6 = nd._type_sym_tab;
    if fv_42_6 is None {
        v_42_6 = _py_none();
    } else {
        v_42_6 = _emit_node(fv_42_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_42_6);
    Py_DecRef(v_42_6);

    v_42_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_42_7);
    Py_DecRef(v_42_7);

    fv_42_8 = nd.attached_tokens;
    if fv_42_8 is None {
        v_42_8 = _py_none();
    } else {
        v_42_8 = PyList_New(len(fv_42_8));
        li_42_8l = 0;
        for it_42_8l in fv_42_8 {
            e_42_8l = _emit_node(it_42_8l);
            PyList_SetItem(v_42_8, li_42_8l, e_42_8l);
            li_42_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_42_8);
    Py_DecRef(v_42_8);

    fv_42_9 = nd.name_spec;
    v_42_9 = _emit_node(fv_42_9);
    PyDict_SetItem(d_h, _mat_keys[12], v_42_9);
    Py_DecRef(v_42_9);

    fv_42_10 = nd.semstr;
    v_42_10 = _py_str(fv_42_10);
    PyDict_SetItem(d_h, _mat_keys[13], v_42_10);
    Py_DecRef(v_42_10);

    fv_42_11 = nd.name;
    if fv_42_11 is None {
        v_42_11 = _py_none();
    } else {
        v_42_11 = _emit_node(fv_42_11);
    }
    PyDict_SetItem(d_h, _mat_keys[24], v_42_11);
    Py_DecRef(v_42_11);

    fv_42_12 = nd.attributes;
    if fv_42_12 is None {
        v_42_12 = _py_none();
    } else {
        v_42_12 = PyList_New(len(fv_42_12));
        li_42_12l = 0;
        for it_42_12l in fv_42_12 {
            e_42_12l = _emit_node(it_42_12l);
            PyList_SetItem(v_42_12, li_42_12l, e_42_12l);
            li_42_12l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[103], v_42_12);
    Py_DecRef(v_42_12);

    fv_42_13 = nd.children;
    if fv_42_13 is None {
        v_42_13 = _py_none();
    } else {
        v_42_13 = PyList_New(len(fv_42_13));
        li_42_13l = 0;
        for it_42_13l in fv_42_13 {
            e_42_13l = _emit_node(it_42_13l);
            PyList_SetItem(v_42_13, li_42_13l, e_42_13l);
            li_42_13l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[104], v_42_13);
    Py_DecRef(v_42_13);

    fv_42_14 = nd.is_self_closing;
    v_42_14 = PyBool_FromLong(1 if fv_42_14 else 0);
    PyDict_SetItem(d_h, _mat_keys[105], v_42_14);
    Py_DecRef(v_42_14);

    fv_42_15 = nd.is_fragment;
    v_42_15 = PyBool_FromLong(1 if fv_42_15 else 0);
    PyDict_SetItem(d_h, _mat_keys[106], v_42_15);
    Py_DecRef(v_42_15);

    fv_42_16 = nd.dynamic_tag;
    if fv_42_16 is None {
        v_42_16 = _py_none();
    } else {
        v_42_16 = _emit_node(fv_42_16);
    }
    PyDict_SetItem(d_h, _mat_keys[107], v_42_16);
    Py_DecRef(v_42_16);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ListVal(nd: ListVal) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[43], _mat_classes[43]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_43_0 = nd.kid;
    v_43_0 = PyList_New(len(fv_43_0));
    li_43_0l = 0;
    for it_43_0l in fv_43_0 {
        e_43_0l = _emit_node(it_43_0l);
        PyList_SetItem(v_43_0, li_43_0l, e_43_0l);
        li_43_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_43_0);
    Py_DecRef(v_43_0);

    fv_43_1 = nd.parent;
    if fv_43_1 is None {
        v_43_1 = _py_none();
    } else {
        v_43_1 = _emit_node(fv_43_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_43_1);
    Py_DecRef(v_43_1);

    v_43_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_43_2);
    Py_DecRef(v_43_2);

    fv_43_3 = nd._in_mod_nodes;
    v_43_3 = PyList_New(len(fv_43_3));
    li_43_3l = 0;
    for it_43_3l in fv_43_3 {
        e_43_3l = _emit_node(it_43_3l);
        PyList_SetItem(v_43_3, li_43_3l, e_43_3l);
        li_43_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_43_3);
    Py_DecRef(v_43_3);

    v_43_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_43_4);
    Py_DecRef(v_43_4);

    fv_43_5 = nd.loc;
    v_43_5 = _emit_CodeLocInfo(fv_43_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_43_5);
    Py_DecRef(v_43_5);

    fv_43_6 = nd._type_sym_tab;
    if fv_43_6 is None {
        v_43_6 = _py_none();
    } else {
        v_43_6 = _emit_node(fv_43_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_43_6);
    Py_DecRef(v_43_6);

    v_43_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_43_7);
    Py_DecRef(v_43_7);

    fv_43_8 = nd.attached_tokens;
    if fv_43_8 is None {
        v_43_8 = _py_none();
    } else {
        v_43_8 = PyList_New(len(fv_43_8));
        li_43_8l = 0;
        for it_43_8l in fv_43_8 {
            e_43_8l = _emit_node(it_43_8l);
            PyList_SetItem(v_43_8, li_43_8l, e_43_8l);
            li_43_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_43_8);
    Py_DecRef(v_43_8);

    fv_43_9 = nd.name_spec;
    v_43_9 = _emit_node(fv_43_9);
    PyDict_SetItem(d_h, _mat_keys[12], v_43_9);
    Py_DecRef(v_43_9);

    fv_43_10 = nd.semstr;
    v_43_10 = _py_str(fv_43_10);
    PyDict_SetItem(d_h, _mat_keys[13], v_43_10);
    Py_DecRef(v_43_10);

    fv_43_11 = nd.values;
    v_43_11 = PyList_New(len(fv_43_11));
    li_43_11l = 0;
    for it_43_11l in fv_43_11 {
        e_43_11l = _emit_node(it_43_11l);
        PyList_SetItem(v_43_11, li_43_11l, e_43_11l);
        li_43_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[108], v_43_11);
    Py_DecRef(v_43_11);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_MultiString(nd: MultiString) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[44], _mat_classes[44]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_44_0 = nd.kid;
    v_44_0 = PyList_New(len(fv_44_0));
    li_44_0l = 0;
    for it_44_0l in fv_44_0 {
        e_44_0l = _emit_node(it_44_0l);
        PyList_SetItem(v_44_0, li_44_0l, e_44_0l);
        li_44_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_44_0);
    Py_DecRef(v_44_0);

    fv_44_1 = nd.parent;
    if fv_44_1 is None {
        v_44_1 = _py_none();
    } else {
        v_44_1 = _emit_node(fv_44_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_44_1);
    Py_DecRef(v_44_1);

    v_44_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_44_2);
    Py_DecRef(v_44_2);

    fv_44_3 = nd._in_mod_nodes;
    v_44_3 = PyList_New(len(fv_44_3));
    li_44_3l = 0;
    for it_44_3l in fv_44_3 {
        e_44_3l = _emit_node(it_44_3l);
        PyList_SetItem(v_44_3, li_44_3l, e_44_3l);
        li_44_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_44_3);
    Py_DecRef(v_44_3);

    v_44_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_44_4);
    Py_DecRef(v_44_4);

    fv_44_5 = nd.loc;
    v_44_5 = _emit_CodeLocInfo(fv_44_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_44_5);
    Py_DecRef(v_44_5);

    fv_44_6 = nd._type_sym_tab;
    if fv_44_6 is None {
        v_44_6 = _py_none();
    } else {
        v_44_6 = _emit_node(fv_44_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_44_6);
    Py_DecRef(v_44_6);

    v_44_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_44_7);
    Py_DecRef(v_44_7);

    fv_44_8 = nd.attached_tokens;
    if fv_44_8 is None {
        v_44_8 = _py_none();
    } else {
        v_44_8 = PyList_New(len(fv_44_8));
        li_44_8l = 0;
        for it_44_8l in fv_44_8 {
            e_44_8l = _emit_node(it_44_8l);
            PyList_SetItem(v_44_8, li_44_8l, e_44_8l);
            li_44_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_44_8);
    Py_DecRef(v_44_8);

    fv_44_9 = nd.name_spec;
    v_44_9 = _emit_node(fv_44_9);
    PyDict_SetItem(d_h, _mat_keys[12], v_44_9);
    Py_DecRef(v_44_9);

    fv_44_10 = nd.semstr;
    v_44_10 = _py_str(fv_44_10);
    PyDict_SetItem(d_h, _mat_keys[13], v_44_10);
    Py_DecRef(v_44_10);

    fv_44_11 = nd.strings;
    v_44_11 = PyList_New(len(fv_44_11));
    li_44_11l = 0;
    for it_44_11l in fv_44_11 {
        e_44_11l = _emit_node(it_44_11l);
        PyList_SetItem(v_44_11, li_44_11l, e_44_11l);
        li_44_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[109], v_44_11);
    Py_DecRef(v_44_11);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_SetVal(nd: SetVal) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[45], _mat_classes[45]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_45_0 = nd.kid;
    v_45_0 = PyList_New(len(fv_45_0));
    li_45_0l = 0;
    for it_45_0l in fv_45_0 {
        e_45_0l = _emit_node(it_45_0l);
        PyList_SetItem(v_45_0, li_45_0l, e_45_0l);
        li_45_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_45_0);
    Py_DecRef(v_45_0);

    fv_45_1 = nd.parent;
    if fv_45_1 is None {
        v_45_1 = _py_none();
    } else {
        v_45_1 = _emit_node(fv_45_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_45_1);
    Py_DecRef(v_45_1);

    v_45_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_45_2);
    Py_DecRef(v_45_2);

    fv_45_3 = nd._in_mod_nodes;
    v_45_3 = PyList_New(len(fv_45_3));
    li_45_3l = 0;
    for it_45_3l in fv_45_3 {
        e_45_3l = _emit_node(it_45_3l);
        PyList_SetItem(v_45_3, li_45_3l, e_45_3l);
        li_45_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_45_3);
    Py_DecRef(v_45_3);

    v_45_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_45_4);
    Py_DecRef(v_45_4);

    fv_45_5 = nd.loc;
    v_45_5 = _emit_CodeLocInfo(fv_45_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_45_5);
    Py_DecRef(v_45_5);

    fv_45_6 = nd._type_sym_tab;
    if fv_45_6 is None {
        v_45_6 = _py_none();
    } else {
        v_45_6 = _emit_node(fv_45_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_45_6);
    Py_DecRef(v_45_6);

    v_45_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_45_7);
    Py_DecRef(v_45_7);

    fv_45_8 = nd.attached_tokens;
    if fv_45_8 is None {
        v_45_8 = _py_none();
    } else {
        v_45_8 = PyList_New(len(fv_45_8));
        li_45_8l = 0;
        for it_45_8l in fv_45_8 {
            e_45_8l = _emit_node(it_45_8l);
            PyList_SetItem(v_45_8, li_45_8l, e_45_8l);
            li_45_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_45_8);
    Py_DecRef(v_45_8);

    fv_45_9 = nd.name_spec;
    v_45_9 = _emit_node(fv_45_9);
    PyDict_SetItem(d_h, _mat_keys[12], v_45_9);
    Py_DecRef(v_45_9);

    fv_45_10 = nd.semstr;
    v_45_10 = _py_str(fv_45_10);
    PyDict_SetItem(d_h, _mat_keys[13], v_45_10);
    Py_DecRef(v_45_10);

    fv_45_11 = nd.values;
    if fv_45_11 is None {
        v_45_11 = _py_none();
    } else {
        v_45_11 = PyList_New(len(fv_45_11));
        li_45_11l = 0;
        for it_45_11l in fv_45_11 {
            e_45_11l = _emit_node(it_45_11l);
            PyList_SetItem(v_45_11, li_45_11l, e_45_11l);
            li_45_11l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[108], v_45_11);
    Py_DecRef(v_45_11);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_TryStmt(nd: TryStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[46], _mat_classes[46]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_46_0 = nd.kid;
    v_46_0 = PyList_New(len(fv_46_0));
    li_46_0l = 0;
    for it_46_0l in fv_46_0 {
        e_46_0l = _emit_node(it_46_0l);
        PyList_SetItem(v_46_0, li_46_0l, e_46_0l);
        li_46_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_46_0);
    Py_DecRef(v_46_0);

    fv_46_1 = nd.parent;
    if fv_46_1 is None {
        v_46_1 = _py_none();
    } else {
        v_46_1 = _emit_node(fv_46_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_46_1);
    Py_DecRef(v_46_1);

    v_46_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_46_2);
    Py_DecRef(v_46_2);

    fv_46_3 = nd._in_mod_nodes;
    v_46_3 = PyList_New(len(fv_46_3));
    li_46_3l = 0;
    for it_46_3l in fv_46_3 {
        e_46_3l = _emit_node(it_46_3l);
        PyList_SetItem(v_46_3, li_46_3l, e_46_3l);
        li_46_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_46_3);
    Py_DecRef(v_46_3);

    v_46_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_46_4);
    Py_DecRef(v_46_4);

    fv_46_5 = nd.loc;
    v_46_5 = _emit_CodeLocInfo(fv_46_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_46_5);
    Py_DecRef(v_46_5);

    fv_46_6 = nd.else_body;
    if fv_46_6 is None {
        v_46_6 = _py_none();
    } else {
        if isinstance(fv_46_6, ElseStmt) {
            v_46_6 = _emit_node(fv_46_6);
        } elif isinstance(fv_46_6, ElseIf) {
            v_46_6 = _emit_node(fv_46_6);
        } else {
            v_46_6 = _py_none();
        }
    }
    PyDict_SetItem(d_h, _mat_keys[76], v_46_6);
    Py_DecRef(v_46_6);

    fv_46_7 = nd.bb_in;
    v_46_7 = PyList_New(len(fv_46_7));
    li_46_7l = 0;
    for it_46_7l in fv_46_7 {
        e_46_7l = _emit_node(it_46_7l);
        PyList_SetItem(v_46_7, li_46_7l, e_46_7l);
        li_46_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_46_7);
    Py_DecRef(v_46_7);

    fv_46_8 = nd.bb_out;
    v_46_8 = PyList_New(len(fv_46_8));
    li_46_8l = 0;
    for it_46_8l in fv_46_8 {
        e_46_8l = _emit_node(it_46_8l);
        PyList_SetItem(v_46_8, li_46_8l, e_46_8l);
        li_46_8l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_46_8);
    Py_DecRef(v_46_8);

    fv_46_9 = nd.affected_symbols;
    v_46_9 = PySet_New(0);
    if len(fv_46_9) != 0 {
        Py_DecRef(v_46_9);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_46_9);
    Py_DecRef(v_46_9);

    fv_46_10 = nd.scope_name;
    v_46_10 = _py_str(fv_46_10);
    PyDict_SetItem(d_h, _mat_keys[18], v_46_10);
    Py_DecRef(v_46_10);

    fv_46_11 = nd.parent_scope;
    if fv_46_11 is None {
        v_46_11 = _py_none();
    } else {
        v_46_11 = _emit_node(fv_46_11);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_46_11);
    Py_DecRef(v_46_11);

    fv_46_12 = nd.kid_scope;
    v_46_12 = PyList_New(len(fv_46_12));
    li_46_12l = 0;
    for it_46_12l in fv_46_12 {
        e_46_12l = _emit_node(it_46_12l);
        PyList_SetItem(v_46_12, li_46_12l, e_46_12l);
        li_46_12l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_46_12);
    Py_DecRef(v_46_12);

    fv_46_13 = nd.names_in_scope;
    v_46_13 = PyDict_New();
    for (dk_46_13d, dv_46_13d) in fv_46_13.items() {
        kh_46_13d = _py_str(dk_46_13d);
        vh_46_13d = _emit_Symbol(dv_46_13d);
        PyDict_SetItem(v_46_13, kh_46_13d, vh_46_13d);
        Py_DecRef(kh_46_13d);
        Py_DecRef(vh_46_13d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_46_13);
    Py_DecRef(v_46_13);

    fv_46_14 = nd.names_in_scope_overload;
    v_46_14 = PyDict_New();
    for (dk_46_14d, dv_46_14d) in fv_46_14.items() {
        kh_46_14d = _py_str(dk_46_14d);
        vh_46_14d = PyList_New(len(dv_46_14d));
        li_46_14dl = 0;
        for it_46_14dl in dv_46_14d {
            e_46_14dl = _emit_Symbol(it_46_14dl);
            PyList_SetItem(vh_46_14d, li_46_14dl, e_46_14dl);
            li_46_14dl += 1;
        }
        PyDict_SetItem(v_46_14, kh_46_14d, vh_46_14d);
        Py_DecRef(kh_46_14d);
        Py_DecRef(vh_46_14d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_46_14);
    Py_DecRef(v_46_14);

    fv_46_15 = nd.implicit_rebinds;
    v_46_15 = PyDict_New();
    for (dk_46_15d, dv_46_15d) in fv_46_15.items() {
        kh_46_15d = _py_str(dk_46_15d);
        vh_46_15d = _emit_Symbol(dv_46_15d);
        PyDict_SetItem(v_46_15, kh_46_15d, vh_46_15d);
        Py_DecRef(kh_46_15d);
        Py_DecRef(vh_46_15d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_46_15);
    Py_DecRef(v_46_15);

    fv_46_16 = nd.body;
    v_46_16 = PyList_New(len(fv_46_16));
    li_46_16l = 0;
    for it_46_16l in fv_46_16 {
        e_46_16l = _emit_node(it_46_16l);
        PyList_SetItem(v_46_16, li_46_16l, e_46_16l);
        li_46_16l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_46_16);
    Py_DecRef(v_46_16);

    fv_46_17 = nd.excepts;
    v_46_17 = PyList_New(len(fv_46_17));
    li_46_17l = 0;
    for it_46_17l in fv_46_17 {
        e_46_17l = _emit_node(it_46_17l);
        PyList_SetItem(v_46_17, li_46_17l, e_46_17l);
        li_46_17l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[110], v_46_17);
    Py_DecRef(v_46_17);

    fv_46_18 = nd.awaiting_body;
    if fv_46_18 is None {
        v_46_18 = _py_none();
    } else {
        v_46_18 = _emit_node(fv_46_18);
    }
    PyDict_SetItem(d_h, _mat_keys[111], v_46_18);
    Py_DecRef(v_46_18);

    fv_46_19 = nd.finally_body;
    if fv_46_19 is None {
        v_46_19 = _py_none();
    } else {
        v_46_19 = _emit_node(fv_46_19);
    }
    PyDict_SetItem(d_h, _mat_keys[112], v_46_19);
    Py_DecRef(v_46_19);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_TupleVal(nd: TupleVal) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[47], _mat_classes[47]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_47_0 = nd.kid;
    v_47_0 = PyList_New(len(fv_47_0));
    li_47_0l = 0;
    for it_47_0l in fv_47_0 {
        e_47_0l = _emit_node(it_47_0l);
        PyList_SetItem(v_47_0, li_47_0l, e_47_0l);
        li_47_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_47_0);
    Py_DecRef(v_47_0);

    fv_47_1 = nd.parent;
    if fv_47_1 is None {
        v_47_1 = _py_none();
    } else {
        v_47_1 = _emit_node(fv_47_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_47_1);
    Py_DecRef(v_47_1);

    v_47_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_47_2);
    Py_DecRef(v_47_2);

    fv_47_3 = nd._in_mod_nodes;
    v_47_3 = PyList_New(len(fv_47_3));
    li_47_3l = 0;
    for it_47_3l in fv_47_3 {
        e_47_3l = _emit_node(it_47_3l);
        PyList_SetItem(v_47_3, li_47_3l, e_47_3l);
        li_47_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_47_3);
    Py_DecRef(v_47_3);

    v_47_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_47_4);
    Py_DecRef(v_47_4);

    fv_47_5 = nd.loc;
    v_47_5 = _emit_CodeLocInfo(fv_47_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_47_5);
    Py_DecRef(v_47_5);

    fv_47_6 = nd._type_sym_tab;
    if fv_47_6 is None {
        v_47_6 = _py_none();
    } else {
        v_47_6 = _emit_node(fv_47_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_47_6);
    Py_DecRef(v_47_6);

    v_47_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_47_7);
    Py_DecRef(v_47_7);

    fv_47_8 = nd.attached_tokens;
    if fv_47_8 is None {
        v_47_8 = _py_none();
    } else {
        v_47_8 = PyList_New(len(fv_47_8));
        li_47_8l = 0;
        for it_47_8l in fv_47_8 {
            e_47_8l = _emit_node(it_47_8l);
            PyList_SetItem(v_47_8, li_47_8l, e_47_8l);
            li_47_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_47_8);
    Py_DecRef(v_47_8);

    fv_47_9 = nd.name_spec;
    v_47_9 = _emit_node(fv_47_9);
    PyDict_SetItem(d_h, _mat_keys[12], v_47_9);
    Py_DecRef(v_47_9);

    fv_47_10 = nd.semstr;
    v_47_10 = _py_str(fv_47_10);
    PyDict_SetItem(d_h, _mat_keys[13], v_47_10);
    Py_DecRef(v_47_10);

    fv_47_11 = nd.values;
    v_47_11 = PyList_New(len(fv_47_11));
    li_47_11l = 0;
    for it_47_11l in fv_47_11 {
        e_47_11l = _emit_node(it_47_11l);
        PyList_SetItem(v_47_11, li_47_11l, e_47_11l);
        li_47_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[108], v_47_11);
    Py_DecRef(v_47_11);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_TypedCtxBlock(nd: TypedCtxBlock) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[48], _mat_classes[48]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_48_0 = nd.kid;
    v_48_0 = PyList_New(len(fv_48_0));
    li_48_0l = 0;
    for it_48_0l in fv_48_0 {
        e_48_0l = _emit_node(it_48_0l);
        PyList_SetItem(v_48_0, li_48_0l, e_48_0l);
        li_48_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_48_0);
    Py_DecRef(v_48_0);

    fv_48_1 = nd.parent;
    if fv_48_1 is None {
        v_48_1 = _py_none();
    } else {
        v_48_1 = _emit_node(fv_48_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_48_1);
    Py_DecRef(v_48_1);

    v_48_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_48_2);
    Py_DecRef(v_48_2);

    fv_48_3 = nd._in_mod_nodes;
    v_48_3 = PyList_New(len(fv_48_3));
    li_48_3l = 0;
    for it_48_3l in fv_48_3 {
        e_48_3l = _emit_node(it_48_3l);
        PyList_SetItem(v_48_3, li_48_3l, e_48_3l);
        li_48_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_48_3);
    Py_DecRef(v_48_3);

    v_48_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_48_4);
    Py_DecRef(v_48_4);

    fv_48_5 = nd.loc;
    v_48_5 = _emit_CodeLocInfo(fv_48_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_48_5);
    Py_DecRef(v_48_5);

    fv_48_6 = nd.bb_in;
    v_48_6 = PyList_New(len(fv_48_6));
    li_48_6l = 0;
    for it_48_6l in fv_48_6 {
        e_48_6l = _emit_node(it_48_6l);
        PyList_SetItem(v_48_6, li_48_6l, e_48_6l);
        li_48_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_48_6);
    Py_DecRef(v_48_6);

    fv_48_7 = nd.bb_out;
    v_48_7 = PyList_New(len(fv_48_7));
    li_48_7l = 0;
    for it_48_7l in fv_48_7 {
        e_48_7l = _emit_node(it_48_7l);
        PyList_SetItem(v_48_7, li_48_7l, e_48_7l);
        li_48_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_48_7);
    Py_DecRef(v_48_7);

    fv_48_8 = nd.affected_symbols;
    v_48_8 = PySet_New(0);
    if len(fv_48_8) != 0 {
        Py_DecRef(v_48_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_48_8);
    Py_DecRef(v_48_8);

    fv_48_9 = nd.from_walker;
    v_48_9 = PyBool_FromLong(1 if fv_48_9 else 0);
    PyDict_SetItem(d_h, _mat_keys[73], v_48_9);
    Py_DecRef(v_48_9);

    fv_48_10 = nd.scope_name;
    v_48_10 = _py_str(fv_48_10);
    PyDict_SetItem(d_h, _mat_keys[18], v_48_10);
    Py_DecRef(v_48_10);

    fv_48_11 = nd.parent_scope;
    if fv_48_11 is None {
        v_48_11 = _py_none();
    } else {
        v_48_11 = _emit_node(fv_48_11);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_48_11);
    Py_DecRef(v_48_11);

    fv_48_12 = nd.kid_scope;
    v_48_12 = PyList_New(len(fv_48_12));
    li_48_12l = 0;
    for it_48_12l in fv_48_12 {
        e_48_12l = _emit_node(it_48_12l);
        PyList_SetItem(v_48_12, li_48_12l, e_48_12l);
        li_48_12l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_48_12);
    Py_DecRef(v_48_12);

    fv_48_13 = nd.names_in_scope;
    v_48_13 = PyDict_New();
    for (dk_48_13d, dv_48_13d) in fv_48_13.items() {
        kh_48_13d = _py_str(dk_48_13d);
        vh_48_13d = _emit_Symbol(dv_48_13d);
        PyDict_SetItem(v_48_13, kh_48_13d, vh_48_13d);
        Py_DecRef(kh_48_13d);
        Py_DecRef(vh_48_13d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_48_13);
    Py_DecRef(v_48_13);

    fv_48_14 = nd.names_in_scope_overload;
    v_48_14 = PyDict_New();
    for (dk_48_14d, dv_48_14d) in fv_48_14.items() {
        kh_48_14d = _py_str(dk_48_14d);
        vh_48_14d = PyList_New(len(dv_48_14d));
        li_48_14dl = 0;
        for it_48_14dl in dv_48_14d {
            e_48_14dl = _emit_Symbol(it_48_14dl);
            PyList_SetItem(vh_48_14d, li_48_14dl, e_48_14dl);
            li_48_14dl += 1;
        }
        PyDict_SetItem(v_48_14, kh_48_14d, vh_48_14d);
        Py_DecRef(kh_48_14d);
        Py_DecRef(vh_48_14d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_48_14);
    Py_DecRef(v_48_14);

    fv_48_15 = nd.implicit_rebinds;
    v_48_15 = PyDict_New();
    for (dk_48_15d, dv_48_15d) in fv_48_15.items() {
        kh_48_15d = _py_str(dk_48_15d);
        vh_48_15d = _emit_Symbol(dv_48_15d);
        PyDict_SetItem(v_48_15, kh_48_15d, vh_48_15d);
        Py_DecRef(kh_48_15d);
        Py_DecRef(vh_48_15d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_48_15);
    Py_DecRef(v_48_15);

    fv_48_16 = nd.type_ctx;
    v_48_16 = _emit_node(fv_48_16);
    PyDict_SetItem(d_h, _mat_keys[113], v_48_16);
    Py_DecRef(v_48_16);

    fv_48_17 = nd.body;
    v_48_17 = PyList_New(len(fv_48_17));
    li_48_17l = 0;
    for it_48_17l in fv_48_17 {
        e_48_17l = _emit_node(it_48_17l);
        PyList_SetItem(v_48_17, li_48_17l, e_48_17l);
        li_48_17l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_48_17);
    Py_DecRef(v_48_17);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_VisitStmt(nd: VisitStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[49], _mat_classes[49]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_49_0 = nd.kid;
    v_49_0 = PyList_New(len(fv_49_0));
    li_49_0l = 0;
    for it_49_0l in fv_49_0 {
        e_49_0l = _emit_node(it_49_0l);
        PyList_SetItem(v_49_0, li_49_0l, e_49_0l);
        li_49_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_49_0);
    Py_DecRef(v_49_0);

    fv_49_1 = nd.parent;
    if fv_49_1 is None {
        v_49_1 = _py_none();
    } else {
        v_49_1 = _emit_node(fv_49_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_49_1);
    Py_DecRef(v_49_1);

    v_49_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_49_2);
    Py_DecRef(v_49_2);

    fv_49_3 = nd._in_mod_nodes;
    v_49_3 = PyList_New(len(fv_49_3));
    li_49_3l = 0;
    for it_49_3l in fv_49_3 {
        e_49_3l = _emit_node(it_49_3l);
        PyList_SetItem(v_49_3, li_49_3l, e_49_3l);
        li_49_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_49_3);
    Py_DecRef(v_49_3);

    v_49_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_49_4);
    Py_DecRef(v_49_4);

    fv_49_5 = nd.loc;
    v_49_5 = _emit_CodeLocInfo(fv_49_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_49_5);
    Py_DecRef(v_49_5);

    fv_49_6 = nd.from_walker;
    v_49_6 = PyBool_FromLong(1 if fv_49_6 else 0);
    PyDict_SetItem(d_h, _mat_keys[73], v_49_6);
    Py_DecRef(v_49_6);

    fv_49_7 = nd.else_body;
    if fv_49_7 is None {
        v_49_7 = _py_none();
    } else {
        if isinstance(fv_49_7, ElseStmt) {
            v_49_7 = _emit_node(fv_49_7);
        } elif isinstance(fv_49_7, ElseIf) {
            v_49_7 = _emit_node(fv_49_7);
        } else {
            v_49_7 = _py_none();
        }
    }
    PyDict_SetItem(d_h, _mat_keys[76], v_49_7);
    Py_DecRef(v_49_7);

    fv_49_8 = nd.bb_in;
    v_49_8 = PyList_New(len(fv_49_8));
    li_49_8l = 0;
    for it_49_8l in fv_49_8 {
        e_49_8l = _emit_node(it_49_8l);
        PyList_SetItem(v_49_8, li_49_8l, e_49_8l);
        li_49_8l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_49_8);
    Py_DecRef(v_49_8);

    fv_49_9 = nd.bb_out;
    v_49_9 = PyList_New(len(fv_49_9));
    li_49_9l = 0;
    for it_49_9l in fv_49_9 {
        e_49_9l = _emit_node(it_49_9l);
        PyList_SetItem(v_49_9, li_49_9l, e_49_9l);
        li_49_9l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_49_9);
    Py_DecRef(v_49_9);

    fv_49_10 = nd.affected_symbols;
    v_49_10 = PySet_New(0);
    if len(fv_49_10) != 0 {
        Py_DecRef(v_49_10);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_49_10);
    Py_DecRef(v_49_10);

    fv_49_11 = nd.insert_loc;
    if fv_49_11 is None {
        v_49_11 = _py_none();
    } else {
        v_49_11 = _emit_node(fv_49_11);
    }
    PyDict_SetItem(d_h, _mat_keys[114], v_49_11);
    Py_DecRef(v_49_11);

    fv_49_12 = nd.target;
    v_49_12 = _emit_node(fv_49_12);
    PyDict_SetItem(d_h, _mat_keys[60], v_49_12);
    Py_DecRef(v_49_12);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_WhileStmt(nd: WhileStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[50], _mat_classes[50]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_50_0 = nd.kid;
    v_50_0 = PyList_New(len(fv_50_0));
    li_50_0l = 0;
    for it_50_0l in fv_50_0 {
        e_50_0l = _emit_node(it_50_0l);
        PyList_SetItem(v_50_0, li_50_0l, e_50_0l);
        li_50_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_50_0);
    Py_DecRef(v_50_0);

    fv_50_1 = nd.parent;
    if fv_50_1 is None {
        v_50_1 = _py_none();
    } else {
        v_50_1 = _emit_node(fv_50_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_50_1);
    Py_DecRef(v_50_1);

    v_50_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_50_2);
    Py_DecRef(v_50_2);

    fv_50_3 = nd._in_mod_nodes;
    v_50_3 = PyList_New(len(fv_50_3));
    li_50_3l = 0;
    for it_50_3l in fv_50_3 {
        e_50_3l = _emit_node(it_50_3l);
        PyList_SetItem(v_50_3, li_50_3l, e_50_3l);
        li_50_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_50_3);
    Py_DecRef(v_50_3);

    v_50_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_50_4);
    Py_DecRef(v_50_4);

    fv_50_5 = nd.loc;
    v_50_5 = _emit_CodeLocInfo(fv_50_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_50_5);
    Py_DecRef(v_50_5);

    fv_50_6 = nd.else_body;
    if fv_50_6 is None {
        v_50_6 = _py_none();
    } else {
        if isinstance(fv_50_6, ElseStmt) {
            v_50_6 = _emit_node(fv_50_6);
        } elif isinstance(fv_50_6, ElseIf) {
            v_50_6 = _emit_node(fv_50_6);
        } else {
            v_50_6 = _py_none();
        }
    }
    PyDict_SetItem(d_h, _mat_keys[76], v_50_6);
    Py_DecRef(v_50_6);

    fv_50_7 = nd.bb_in;
    v_50_7 = PyList_New(len(fv_50_7));
    li_50_7l = 0;
    for it_50_7l in fv_50_7 {
        e_50_7l = _emit_node(it_50_7l);
        PyList_SetItem(v_50_7, li_50_7l, e_50_7l);
        li_50_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_50_7);
    Py_DecRef(v_50_7);

    fv_50_8 = nd.bb_out;
    v_50_8 = PyList_New(len(fv_50_8));
    li_50_8l = 0;
    for it_50_8l in fv_50_8 {
        e_50_8l = _emit_node(it_50_8l);
        PyList_SetItem(v_50_8, li_50_8l, e_50_8l);
        li_50_8l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_50_8);
    Py_DecRef(v_50_8);

    fv_50_9 = nd.affected_symbols;
    v_50_9 = PySet_New(0);
    if len(fv_50_9) != 0 {
        Py_DecRef(v_50_9);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_50_9);
    Py_DecRef(v_50_9);

    fv_50_10 = nd.scope_name;
    v_50_10 = _py_str(fv_50_10);
    PyDict_SetItem(d_h, _mat_keys[18], v_50_10);
    Py_DecRef(v_50_10);

    fv_50_11 = nd.parent_scope;
    if fv_50_11 is None {
        v_50_11 = _py_none();
    } else {
        v_50_11 = _emit_node(fv_50_11);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_50_11);
    Py_DecRef(v_50_11);

    fv_50_12 = nd.kid_scope;
    v_50_12 = PyList_New(len(fv_50_12));
    li_50_12l = 0;
    for it_50_12l in fv_50_12 {
        e_50_12l = _emit_node(it_50_12l);
        PyList_SetItem(v_50_12, li_50_12l, e_50_12l);
        li_50_12l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_50_12);
    Py_DecRef(v_50_12);

    fv_50_13 = nd.names_in_scope;
    v_50_13 = PyDict_New();
    for (dk_50_13d, dv_50_13d) in fv_50_13.items() {
        kh_50_13d = _py_str(dk_50_13d);
        vh_50_13d = _emit_Symbol(dv_50_13d);
        PyDict_SetItem(v_50_13, kh_50_13d, vh_50_13d);
        Py_DecRef(kh_50_13d);
        Py_DecRef(vh_50_13d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_50_13);
    Py_DecRef(v_50_13);

    fv_50_14 = nd.names_in_scope_overload;
    v_50_14 = PyDict_New();
    for (dk_50_14d, dv_50_14d) in fv_50_14.items() {
        kh_50_14d = _py_str(dk_50_14d);
        vh_50_14d = PyList_New(len(dv_50_14d));
        li_50_14dl = 0;
        for it_50_14dl in dv_50_14d {
            e_50_14dl = _emit_Symbol(it_50_14dl);
            PyList_SetItem(vh_50_14d, li_50_14dl, e_50_14dl);
            li_50_14dl += 1;
        }
        PyDict_SetItem(v_50_14, kh_50_14d, vh_50_14d);
        Py_DecRef(kh_50_14d);
        Py_DecRef(vh_50_14d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_50_14);
    Py_DecRef(v_50_14);

    fv_50_15 = nd.implicit_rebinds;
    v_50_15 = PyDict_New();
    for (dk_50_15d, dv_50_15d) in fv_50_15.items() {
        kh_50_15d = _py_str(dk_50_15d);
        vh_50_15d = _emit_Symbol(dv_50_15d);
        PyDict_SetItem(v_50_15, kh_50_15d, vh_50_15d);
        Py_DecRef(kh_50_15d);
        Py_DecRef(vh_50_15d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_50_15);
    Py_DecRef(v_50_15);

    fv_50_16 = nd.condition;
    v_50_16 = _emit_node(fv_50_16);
    PyDict_SetItem(d_h, _mat_keys[77], v_50_16);
    Py_DecRef(v_50_16);

    fv_50_17 = nd.body;
    v_50_17 = PyList_New(len(fv_50_17));
    li_50_17l = 0;
    for it_50_17l in fv_50_17 {
        e_50_17l = _emit_node(it_50_17l);
        PyList_SetItem(v_50_17, li_50_17l, e_50_17l);
        li_50_17l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_50_17);
    Py_DecRef(v_50_17);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_WithStmt(nd: WithStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[51], _mat_classes[51]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_51_0 = nd.kid;
    v_51_0 = PyList_New(len(fv_51_0));
    li_51_0l = 0;
    for it_51_0l in fv_51_0 {
        e_51_0l = _emit_node(it_51_0l);
        PyList_SetItem(v_51_0, li_51_0l, e_51_0l);
        li_51_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_51_0);
    Py_DecRef(v_51_0);

    fv_51_1 = nd.parent;
    if fv_51_1 is None {
        v_51_1 = _py_none();
    } else {
        v_51_1 = _emit_node(fv_51_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_51_1);
    Py_DecRef(v_51_1);

    v_51_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_51_2);
    Py_DecRef(v_51_2);

    fv_51_3 = nd._in_mod_nodes;
    v_51_3 = PyList_New(len(fv_51_3));
    li_51_3l = 0;
    for it_51_3l in fv_51_3 {
        e_51_3l = _emit_node(it_51_3l);
        PyList_SetItem(v_51_3, li_51_3l, e_51_3l);
        li_51_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_51_3);
    Py_DecRef(v_51_3);

    v_51_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_51_4);
    Py_DecRef(v_51_4);

    fv_51_5 = nd.loc;
    v_51_5 = _emit_CodeLocInfo(fv_51_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_51_5);
    Py_DecRef(v_51_5);

    fv_51_6 = nd.is_async;
    v_51_6 = PyBool_FromLong(1 if fv_51_6 else 0);
    PyDict_SetItem(d_h, _mat_keys[14], v_51_6);
    Py_DecRef(v_51_6);

    fv_51_7 = nd.bb_in;
    v_51_7 = PyList_New(len(fv_51_7));
    li_51_7l = 0;
    for it_51_7l in fv_51_7 {
        e_51_7l = _emit_node(it_51_7l);
        PyList_SetItem(v_51_7, li_51_7l, e_51_7l);
        li_51_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_51_7);
    Py_DecRef(v_51_7);

    fv_51_8 = nd.bb_out;
    v_51_8 = PyList_New(len(fv_51_8));
    li_51_8l = 0;
    for it_51_8l in fv_51_8 {
        e_51_8l = _emit_node(it_51_8l);
        PyList_SetItem(v_51_8, li_51_8l, e_51_8l);
        li_51_8l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_51_8);
    Py_DecRef(v_51_8);

    fv_51_9 = nd.affected_symbols;
    v_51_9 = PySet_New(0);
    if len(fv_51_9) != 0 {
        Py_DecRef(v_51_9);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_51_9);
    Py_DecRef(v_51_9);

    fv_51_10 = nd.scope_name;
    v_51_10 = _py_str(fv_51_10);
    PyDict_SetItem(d_h, _mat_keys[18], v_51_10);
    Py_DecRef(v_51_10);

    fv_51_11 = nd.parent_scope;
    if fv_51_11 is None {
        v_51_11 = _py_none();
    } else {
        v_51_11 = _emit_node(fv_51_11);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_51_11);
    Py_DecRef(v_51_11);

    fv_51_12 = nd.kid_scope;
    v_51_12 = PyList_New(len(fv_51_12));
    li_51_12l = 0;
    for it_51_12l in fv_51_12 {
        e_51_12l = _emit_node(it_51_12l);
        PyList_SetItem(v_51_12, li_51_12l, e_51_12l);
        li_51_12l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_51_12);
    Py_DecRef(v_51_12);

    fv_51_13 = nd.names_in_scope;
    v_51_13 = PyDict_New();
    for (dk_51_13d, dv_51_13d) in fv_51_13.items() {
        kh_51_13d = _py_str(dk_51_13d);
        vh_51_13d = _emit_Symbol(dv_51_13d);
        PyDict_SetItem(v_51_13, kh_51_13d, vh_51_13d);
        Py_DecRef(kh_51_13d);
        Py_DecRef(vh_51_13d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_51_13);
    Py_DecRef(v_51_13);

    fv_51_14 = nd.names_in_scope_overload;
    v_51_14 = PyDict_New();
    for (dk_51_14d, dv_51_14d) in fv_51_14.items() {
        kh_51_14d = _py_str(dk_51_14d);
        vh_51_14d = PyList_New(len(dv_51_14d));
        li_51_14dl = 0;
        for it_51_14dl in dv_51_14d {
            e_51_14dl = _emit_Symbol(it_51_14dl);
            PyList_SetItem(vh_51_14d, li_51_14dl, e_51_14dl);
            li_51_14dl += 1;
        }
        PyDict_SetItem(v_51_14, kh_51_14d, vh_51_14d);
        Py_DecRef(kh_51_14d);
        Py_DecRef(vh_51_14d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_51_14);
    Py_DecRef(v_51_14);

    fv_51_15 = nd.implicit_rebinds;
    v_51_15 = PyDict_New();
    for (dk_51_15d, dv_51_15d) in fv_51_15.items() {
        kh_51_15d = _py_str(dk_51_15d);
        vh_51_15d = _emit_Symbol(dv_51_15d);
        PyDict_SetItem(v_51_15, kh_51_15d, vh_51_15d);
        Py_DecRef(kh_51_15d);
        Py_DecRef(vh_51_15d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_51_15);
    Py_DecRef(v_51_15);

    fv_51_16 = nd.exprs;
    v_51_16 = PyList_New(len(fv_51_16));
    li_51_16l = 0;
    for it_51_16l in fv_51_16 {
        e_51_16l = _emit_node(it_51_16l);
        PyList_SetItem(v_51_16, li_51_16l, e_51_16l);
        li_51_16l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[115], v_51_16);
    Py_DecRef(v_51_16);

    fv_51_17 = nd.body;
    v_51_17 = PyList_New(len(fv_51_17));
    li_51_17l = 0;
    for it_51_17l in fv_51_17 {
        e_51_17l = _emit_node(it_51_17l);
        PyList_SetItem(v_51_17, li_51_17l, e_51_17l);
        li_51_17l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_51_17);
    Py_DecRef(v_51_17);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_Semi(nd: Semi) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[52], _mat_classes[52]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_52_0 = nd.kid;
    v_52_0 = PyList_New(len(fv_52_0));
    li_52_0l = 0;
    for it_52_0l in fv_52_0 {
        e_52_0l = _emit_node(it_52_0l);
        PyList_SetItem(v_52_0, li_52_0l, e_52_0l);
        li_52_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_52_0);
    Py_DecRef(v_52_0);

    fv_52_1 = nd.parent;
    if fv_52_1 is None {
        v_52_1 = _py_none();
    } else {
        v_52_1 = _emit_node(fv_52_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_52_1);
    Py_DecRef(v_52_1);

    v_52_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_52_2);
    Py_DecRef(v_52_2);

    fv_52_3 = nd._in_mod_nodes;
    v_52_3 = PyList_New(len(fv_52_3));
    li_52_3l = 0;
    for it_52_3l in fv_52_3 {
        e_52_3l = _emit_node(it_52_3l);
        PyList_SetItem(v_52_3, li_52_3l, e_52_3l);
        li_52_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_52_3);
    Py_DecRef(v_52_3);

    v_52_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_52_4);
    Py_DecRef(v_52_4);

    fv_52_5 = nd.loc;
    v_52_5 = _emit_CodeLocInfo(fv_52_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_52_5);
    Py_DecRef(v_52_5);

    fv_52_6 = nd.orig_src;
    v_52_6 = _emit_node(fv_52_6);
    PyDict_SetItem(d_h, _mat_keys[41], v_52_6);
    Py_DecRef(v_52_6);

    fv_52_7 = nd.name;
    v_52_7 = _py_str(fv_52_7);
    PyDict_SetItem(d_h, _mat_keys[24], v_52_7);
    Py_DecRef(v_52_7);

    fv_52_8 = nd.value;
    v_52_8 = _py_str(fv_52_8);
    PyDict_SetItem(d_h, _mat_keys[42], v_52_8);
    Py_DecRef(v_52_8);

    fv_52_9 = nd.line_no;
    v_52_9 = PyLong_FromLongLong(fv_52_9);
    PyDict_SetItem(d_h, _mat_keys[43], v_52_9);
    Py_DecRef(v_52_9);

    fv_52_10 = nd.end_line;
    v_52_10 = PyLong_FromLongLong(fv_52_10);
    PyDict_SetItem(d_h, _mat_keys[44], v_52_10);
    Py_DecRef(v_52_10);

    fv_52_11 = nd.c_start;
    v_52_11 = PyLong_FromLongLong(fv_52_11);
    PyDict_SetItem(d_h, _mat_keys[45], v_52_11);
    Py_DecRef(v_52_11);

    fv_52_12 = nd.c_end;
    v_52_12 = PyLong_FromLongLong(fv_52_12);
    PyDict_SetItem(d_h, _mat_keys[46], v_52_12);
    Py_DecRef(v_52_12);

    fv_52_13 = nd.pos_start;
    v_52_13 = PyLong_FromLongLong(fv_52_13);
    PyDict_SetItem(d_h, _mat_keys[47], v_52_13);
    Py_DecRef(v_52_13);

    fv_52_14 = nd.pos_end;
    v_52_14 = PyLong_FromLongLong(fv_52_14);
    PyDict_SetItem(d_h, _mat_keys[48], v_52_14);
    Py_DecRef(v_52_14);

    fv_52_15 = nd._is_synthetic;
    v_52_15 = PyBool_FromLong(1 if fv_52_15 else 0);
    PyDict_SetItem(d_h, _mat_keys[49], v_52_15);
    Py_DecRef(v_52_15);

    fv_52_16 = nd.bb_in;
    v_52_16 = PyList_New(len(fv_52_16));
    li_52_16l = 0;
    for it_52_16l in fv_52_16 {
        e_52_16l = _emit_node(it_52_16l);
        PyList_SetItem(v_52_16, li_52_16l, e_52_16l);
        li_52_16l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_52_16);
    Py_DecRef(v_52_16);

    fv_52_17 = nd.bb_out;
    v_52_17 = PyList_New(len(fv_52_17));
    li_52_17l = 0;
    for it_52_17l in fv_52_17 {
        e_52_17l = _emit_node(it_52_17l);
        PyList_SetItem(v_52_17, li_52_17l, e_52_17l);
        li_52_17l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_52_17);
    Py_DecRef(v_52_17);

    fv_52_18 = nd.affected_symbols;
    v_52_18 = PySet_New(0);
    if len(fv_52_18) != 0 {
        Py_DecRef(v_52_18);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_52_18);
    Py_DecRef(v_52_18);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_AtomExpr(nd: AtomExpr) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[53], _mat_classes[53]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_53_0 = nd.kid;
    v_53_0 = PyList_New(len(fv_53_0));
    li_53_0l = 0;
    for it_53_0l in fv_53_0 {
        e_53_0l = _emit_node(it_53_0l);
        PyList_SetItem(v_53_0, li_53_0l, e_53_0l);
        li_53_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_53_0);
    Py_DecRef(v_53_0);

    fv_53_1 = nd.parent;
    if fv_53_1 is None {
        v_53_1 = _py_none();
    } else {
        v_53_1 = _emit_node(fv_53_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_53_1);
    Py_DecRef(v_53_1);

    v_53_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_53_2);
    Py_DecRef(v_53_2);

    fv_53_3 = nd._in_mod_nodes;
    v_53_3 = PyList_New(len(fv_53_3));
    li_53_3l = 0;
    for it_53_3l in fv_53_3 {
        e_53_3l = _emit_node(it_53_3l);
        PyList_SetItem(v_53_3, li_53_3l, e_53_3l);
        li_53_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_53_3);
    Py_DecRef(v_53_3);

    v_53_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_53_4);
    Py_DecRef(v_53_4);

    fv_53_5 = nd.loc;
    v_53_5 = _emit_CodeLocInfo(fv_53_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_53_5);
    Py_DecRef(v_53_5);

    fv_53_6 = nd._type_sym_tab;
    if fv_53_6 is None {
        v_53_6 = _py_none();
    } else {
        v_53_6 = _emit_node(fv_53_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_53_6);
    Py_DecRef(v_53_6);

    v_53_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_53_7);
    Py_DecRef(v_53_7);

    fv_53_8 = nd.attached_tokens;
    if fv_53_8 is None {
        v_53_8 = _py_none();
    } else {
        v_53_8 = PyList_New(len(fv_53_8));
        li_53_8l = 0;
        for it_53_8l in fv_53_8 {
            e_53_8l = _emit_node(it_53_8l);
            PyList_SetItem(v_53_8, li_53_8l, e_53_8l);
            li_53_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_53_8);
    Py_DecRef(v_53_8);

    fv_53_9 = nd.name_spec;
    v_53_9 = _emit_node(fv_53_9);
    PyDict_SetItem(d_h, _mat_keys[12], v_53_9);
    Py_DecRef(v_53_9);

    fv_53_10 = nd.semstr;
    v_53_10 = _py_str(fv_53_10);
    PyDict_SetItem(d_h, _mat_keys[13], v_53_10);
    Py_DecRef(v_53_10);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_AwaitingClause(nd: AwaitingClause) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[54], _mat_classes[54]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_54_0 = nd.kid;
    v_54_0 = PyList_New(len(fv_54_0));
    li_54_0l = 0;
    for it_54_0l in fv_54_0 {
        e_54_0l = _emit_node(it_54_0l);
        PyList_SetItem(v_54_0, li_54_0l, e_54_0l);
        li_54_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_54_0);
    Py_DecRef(v_54_0);

    fv_54_1 = nd.parent;
    if fv_54_1 is None {
        v_54_1 = _py_none();
    } else {
        v_54_1 = _emit_node(fv_54_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_54_1);
    Py_DecRef(v_54_1);

    v_54_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_54_2);
    Py_DecRef(v_54_2);

    fv_54_3 = nd._in_mod_nodes;
    v_54_3 = PyList_New(len(fv_54_3));
    li_54_3l = 0;
    for it_54_3l in fv_54_3 {
        e_54_3l = _emit_node(it_54_3l);
        PyList_SetItem(v_54_3, li_54_3l, e_54_3l);
        li_54_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_54_3);
    Py_DecRef(v_54_3);

    v_54_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_54_4);
    Py_DecRef(v_54_4);

    fv_54_5 = nd.loc;
    v_54_5 = _emit_CodeLocInfo(fv_54_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_54_5);
    Py_DecRef(v_54_5);

    fv_54_6 = nd.bb_in;
    v_54_6 = PyList_New(len(fv_54_6));
    li_54_6l = 0;
    for it_54_6l in fv_54_6 {
        e_54_6l = _emit_node(it_54_6l);
        PyList_SetItem(v_54_6, li_54_6l, e_54_6l);
        li_54_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_54_6);
    Py_DecRef(v_54_6);

    fv_54_7 = nd.bb_out;
    v_54_7 = PyList_New(len(fv_54_7));
    li_54_7l = 0;
    for it_54_7l in fv_54_7 {
        e_54_7l = _emit_node(it_54_7l);
        PyList_SetItem(v_54_7, li_54_7l, e_54_7l);
        li_54_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_54_7);
    Py_DecRef(v_54_7);

    fv_54_8 = nd.affected_symbols;
    v_54_8 = PySet_New(0);
    if len(fv_54_8) != 0 {
        Py_DecRef(v_54_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_54_8);
    Py_DecRef(v_54_8);

    fv_54_9 = nd.scope_name;
    v_54_9 = _py_str(fv_54_9);
    PyDict_SetItem(d_h, _mat_keys[18], v_54_9);
    Py_DecRef(v_54_9);

    fv_54_10 = nd.parent_scope;
    if fv_54_10 is None {
        v_54_10 = _py_none();
    } else {
        v_54_10 = _emit_node(fv_54_10);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_54_10);
    Py_DecRef(v_54_10);

    fv_54_11 = nd.kid_scope;
    v_54_11 = PyList_New(len(fv_54_11));
    li_54_11l = 0;
    for it_54_11l in fv_54_11 {
        e_54_11l = _emit_node(it_54_11l);
        PyList_SetItem(v_54_11, li_54_11l, e_54_11l);
        li_54_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_54_11);
    Py_DecRef(v_54_11);

    fv_54_12 = nd.names_in_scope;
    v_54_12 = PyDict_New();
    for (dk_54_12d, dv_54_12d) in fv_54_12.items() {
        kh_54_12d = _py_str(dk_54_12d);
        vh_54_12d = _emit_Symbol(dv_54_12d);
        PyDict_SetItem(v_54_12, kh_54_12d, vh_54_12d);
        Py_DecRef(kh_54_12d);
        Py_DecRef(vh_54_12d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_54_12);
    Py_DecRef(v_54_12);

    fv_54_13 = nd.names_in_scope_overload;
    v_54_13 = PyDict_New();
    for (dk_54_13d, dv_54_13d) in fv_54_13.items() {
        kh_54_13d = _py_str(dk_54_13d);
        vh_54_13d = PyList_New(len(dv_54_13d));
        li_54_13dl = 0;
        for it_54_13dl in dv_54_13d {
            e_54_13dl = _emit_Symbol(it_54_13dl);
            PyList_SetItem(vh_54_13d, li_54_13dl, e_54_13dl);
            li_54_13dl += 1;
        }
        PyDict_SetItem(v_54_13, kh_54_13d, vh_54_13d);
        Py_DecRef(kh_54_13d);
        Py_DecRef(vh_54_13d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_54_13);
    Py_DecRef(v_54_13);

    fv_54_14 = nd.implicit_rebinds;
    v_54_14 = PyDict_New();
    for (dk_54_14d, dv_54_14d) in fv_54_14.items() {
        kh_54_14d = _py_str(dk_54_14d);
        vh_54_14d = _emit_Symbol(dv_54_14d);
        PyDict_SetItem(v_54_14, kh_54_14d, vh_54_14d);
        Py_DecRef(kh_54_14d);
        Py_DecRef(vh_54_14d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_54_14);
    Py_DecRef(v_54_14);

    fv_54_15 = nd.body;
    v_54_15 = PyList_New(len(fv_54_15));
    li_54_15l = 0;
    for it_54_15l in fv_54_15 {
        e_54_15l = _emit_node(it_54_15l);
        PyList_SetItem(v_54_15, li_54_15l, e_54_15l);
        li_54_15l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_54_15);
    Py_DecRef(v_54_15);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_CfgExpr(nd: CfgExpr) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[55], _mat_classes[55]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_55_0 = nd.kid;
    v_55_0 = PyList_New(len(fv_55_0));
    li_55_0l = 0;
    for it_55_0l in fv_55_0 {
        e_55_0l = _emit_node(it_55_0l);
        PyList_SetItem(v_55_0, li_55_0l, e_55_0l);
        li_55_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_55_0);
    Py_DecRef(v_55_0);

    fv_55_1 = nd.parent;
    if fv_55_1 is None {
        v_55_1 = _py_none();
    } else {
        v_55_1 = _emit_node(fv_55_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_55_1);
    Py_DecRef(v_55_1);

    v_55_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_55_2);
    Py_DecRef(v_55_2);

    fv_55_3 = nd._in_mod_nodes;
    v_55_3 = PyList_New(len(fv_55_3));
    li_55_3l = 0;
    for it_55_3l in fv_55_3 {
        e_55_3l = _emit_node(it_55_3l);
        PyList_SetItem(v_55_3, li_55_3l, e_55_3l);
        li_55_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_55_3);
    Py_DecRef(v_55_3);

    v_55_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_55_4);
    Py_DecRef(v_55_4);

    fv_55_5 = nd.loc;
    v_55_5 = _emit_CodeLocInfo(fv_55_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_55_5);
    Py_DecRef(v_55_5);

    fv_55_6 = nd._type_sym_tab;
    if fv_55_6 is None {
        v_55_6 = _py_none();
    } else {
        v_55_6 = _emit_node(fv_55_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_55_6);
    Py_DecRef(v_55_6);

    v_55_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_55_7);
    Py_DecRef(v_55_7);

    fv_55_8 = nd.attached_tokens;
    if fv_55_8 is None {
        v_55_8 = _py_none();
    } else {
        v_55_8 = PyList_New(len(fv_55_8));
        li_55_8l = 0;
        for it_55_8l in fv_55_8 {
            e_55_8l = _emit_node(it_55_8l);
            PyList_SetItem(v_55_8, li_55_8l, e_55_8l);
            li_55_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_55_8);
    Py_DecRef(v_55_8);

    fv_55_9 = nd.bb_in;
    v_55_9 = PyList_New(len(fv_55_9));
    li_55_9l = 0;
    for it_55_9l in fv_55_9 {
        e_55_9l = _emit_node(it_55_9l);
        PyList_SetItem(v_55_9, li_55_9l, e_55_9l);
        li_55_9l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_55_9);
    Py_DecRef(v_55_9);

    fv_55_10 = nd.bb_out;
    v_55_10 = PyList_New(len(fv_55_10));
    li_55_10l = 0;
    for it_55_10l in fv_55_10 {
        e_55_10l = _emit_node(it_55_10l);
        PyList_SetItem(v_55_10, li_55_10l, e_55_10l);
        li_55_10l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_55_10);
    Py_DecRef(v_55_10);

    fv_55_11 = nd.affected_symbols;
    v_55_11 = PySet_New(0);
    if len(fv_55_11) != 0 {
        Py_DecRef(v_55_11);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_55_11);
    Py_DecRef(v_55_11);

    fv_55_12 = nd.sc_true_target;
    if fv_55_12 is None {
        v_55_12 = _py_none();
    } else {
        v_55_12 = _emit_node(fv_55_12);
    }
    PyDict_SetItem(d_h, _mat_keys[116], v_55_12);
    Py_DecRef(v_55_12);

    fv_55_13 = nd.sc_false_target;
    if fv_55_13 is None {
        v_55_13 = _py_none();
    } else {
        v_55_13 = _emit_node(fv_55_13);
    }
    PyDict_SetItem(d_h, _mat_keys[117], v_55_13);
    Py_DecRef(v_55_13);

    fv_55_14 = nd.expr;
    v_55_14 = _emit_node(fv_55_14);
    PyDict_SetItem(d_h, _mat_keys[118], v_55_14);
    Py_DecRef(v_55_14);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_CtName(nd: CtName) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[56], _mat_classes[56]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_56_0 = nd.kid;
    v_56_0 = PyList_New(len(fv_56_0));
    li_56_0l = 0;
    for it_56_0l in fv_56_0 {
        e_56_0l = _emit_node(it_56_0l);
        PyList_SetItem(v_56_0, li_56_0l, e_56_0l);
        li_56_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_56_0);
    Py_DecRef(v_56_0);

    fv_56_1 = nd.parent;
    if fv_56_1 is None {
        v_56_1 = _py_none();
    } else {
        v_56_1 = _emit_node(fv_56_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_56_1);
    Py_DecRef(v_56_1);

    v_56_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_56_2);
    Py_DecRef(v_56_2);

    fv_56_3 = nd._in_mod_nodes;
    v_56_3 = PyList_New(len(fv_56_3));
    li_56_3l = 0;
    for it_56_3l in fv_56_3 {
        e_56_3l = _emit_node(it_56_3l);
        PyList_SetItem(v_56_3, li_56_3l, e_56_3l);
        li_56_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_56_3);
    Py_DecRef(v_56_3);

    v_56_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_56_4);
    Py_DecRef(v_56_4);

    fv_56_5 = nd.loc;
    v_56_5 = _emit_CodeLocInfo(fv_56_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_56_5);
    Py_DecRef(v_56_5);

    fv_56_6 = nd._type_sym_tab;
    if fv_56_6 is None {
        v_56_6 = _py_none();
    } else {
        v_56_6 = _emit_node(fv_56_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_56_6);
    Py_DecRef(v_56_6);

    v_56_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_56_7);
    Py_DecRef(v_56_7);

    fv_56_8 = nd.attached_tokens;
    if fv_56_8 is None {
        v_56_8 = _py_none();
    } else {
        v_56_8 = PyList_New(len(fv_56_8));
        li_56_8l = 0;
        for it_56_8l in fv_56_8 {
            e_56_8l = _emit_node(it_56_8l);
            PyList_SetItem(v_56_8, li_56_8l, e_56_8l);
            li_56_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_56_8);
    Py_DecRef(v_56_8);

    fv_56_9 = nd.name_spec;
    v_56_9 = _emit_node(fv_56_9);
    PyDict_SetItem(d_h, _mat_keys[12], v_56_9);
    Py_DecRef(v_56_9);

    fv_56_10 = nd.semstr;
    v_56_10 = _py_str(fv_56_10);
    PyDict_SetItem(d_h, _mat_keys[13], v_56_10);
    Py_DecRef(v_56_10);

    fv_56_11 = nd.parts;
    v_56_11 = PyList_New(len(fv_56_11));
    li_56_11l = 0;
    for it_56_11l in fv_56_11 {
        e_56_11l = _emit_node(it_56_11l);
        PyList_SetItem(v_56_11, li_56_11l, e_56_11l);
        li_56_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[97], v_56_11);
    Py_DecRef(v_56_11);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_CtSplice(nd: CtSplice) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[57], _mat_classes[57]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_57_0 = nd.kid;
    v_57_0 = PyList_New(len(fv_57_0));
    li_57_0l = 0;
    for it_57_0l in fv_57_0 {
        e_57_0l = _emit_node(it_57_0l);
        PyList_SetItem(v_57_0, li_57_0l, e_57_0l);
        li_57_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_57_0);
    Py_DecRef(v_57_0);

    fv_57_1 = nd.parent;
    if fv_57_1 is None {
        v_57_1 = _py_none();
    } else {
        v_57_1 = _emit_node(fv_57_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_57_1);
    Py_DecRef(v_57_1);

    v_57_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_57_2);
    Py_DecRef(v_57_2);

    fv_57_3 = nd._in_mod_nodes;
    v_57_3 = PyList_New(len(fv_57_3));
    li_57_3l = 0;
    for it_57_3l in fv_57_3 {
        e_57_3l = _emit_node(it_57_3l);
        PyList_SetItem(v_57_3, li_57_3l, e_57_3l);
        li_57_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_57_3);
    Py_DecRef(v_57_3);

    v_57_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_57_4);
    Py_DecRef(v_57_4);

    fv_57_5 = nd.loc;
    v_57_5 = _emit_CodeLocInfo(fv_57_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_57_5);
    Py_DecRef(v_57_5);

    fv_57_6 = nd._type_sym_tab;
    if fv_57_6 is None {
        v_57_6 = _py_none();
    } else {
        v_57_6 = _emit_node(fv_57_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_57_6);
    Py_DecRef(v_57_6);

    v_57_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_57_7);
    Py_DecRef(v_57_7);

    fv_57_8 = nd.attached_tokens;
    if fv_57_8 is None {
        v_57_8 = _py_none();
    } else {
        v_57_8 = PyList_New(len(fv_57_8));
        li_57_8l = 0;
        for it_57_8l in fv_57_8 {
            e_57_8l = _emit_node(it_57_8l);
            PyList_SetItem(v_57_8, li_57_8l, e_57_8l);
            li_57_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_57_8);
    Py_DecRef(v_57_8);

    fv_57_9 = nd.name_spec;
    v_57_9 = _emit_node(fv_57_9);
    PyDict_SetItem(d_h, _mat_keys[12], v_57_9);
    Py_DecRef(v_57_9);

    fv_57_10 = nd.semstr;
    v_57_10 = _py_str(fv_57_10);
    PyDict_SetItem(d_h, _mat_keys[13], v_57_10);
    Py_DecRef(v_57_10);

    fv_57_11 = nd.expr;
    v_57_11 = _emit_node(fv_57_11);
    PyDict_SetItem(d_h, _mat_keys[118], v_57_11);
    Py_DecRef(v_57_11);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_DisengageStmt(nd: DisengageStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[58], _mat_classes[58]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_58_0 = nd.kid;
    v_58_0 = PyList_New(len(fv_58_0));
    li_58_0l = 0;
    for it_58_0l in fv_58_0 {
        e_58_0l = _emit_node(it_58_0l);
        PyList_SetItem(v_58_0, li_58_0l, e_58_0l);
        li_58_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_58_0);
    Py_DecRef(v_58_0);

    fv_58_1 = nd.parent;
    if fv_58_1 is None {
        v_58_1 = _py_none();
    } else {
        v_58_1 = _emit_node(fv_58_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_58_1);
    Py_DecRef(v_58_1);

    v_58_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_58_2);
    Py_DecRef(v_58_2);

    fv_58_3 = nd._in_mod_nodes;
    v_58_3 = PyList_New(len(fv_58_3));
    li_58_3l = 0;
    for it_58_3l in fv_58_3 {
        e_58_3l = _emit_node(it_58_3l);
        PyList_SetItem(v_58_3, li_58_3l, e_58_3l);
        li_58_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_58_3);
    Py_DecRef(v_58_3);

    v_58_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_58_4);
    Py_DecRef(v_58_4);

    fv_58_5 = nd.loc;
    v_58_5 = _emit_CodeLocInfo(fv_58_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_58_5);
    Py_DecRef(v_58_5);

    fv_58_6 = nd.from_walker;
    v_58_6 = PyBool_FromLong(1 if fv_58_6 else 0);
    PyDict_SetItem(d_h, _mat_keys[73], v_58_6);
    Py_DecRef(v_58_6);

    fv_58_7 = nd.bb_in;
    v_58_7 = PyList_New(len(fv_58_7));
    li_58_7l = 0;
    for it_58_7l in fv_58_7 {
        e_58_7l = _emit_node(it_58_7l);
        PyList_SetItem(v_58_7, li_58_7l, e_58_7l);
        li_58_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_58_7);
    Py_DecRef(v_58_7);

    fv_58_8 = nd.bb_out;
    v_58_8 = PyList_New(len(fv_58_8));
    li_58_8l = 0;
    for it_58_8l in fv_58_8 {
        e_58_8l = _emit_node(it_58_8l);
        PyList_SetItem(v_58_8, li_58_8l, e_58_8l);
        li_58_8l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_58_8);
    Py_DecRef(v_58_8);

    fv_58_9 = nd.affected_symbols;
    v_58_9 = PySet_New(0);
    if len(fv_58_9) != 0 {
        Py_DecRef(v_58_9);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_58_9);
    Py_DecRef(v_58_9);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_Except(nd: Except) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[59], _mat_classes[59]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_59_0 = nd.kid;
    v_59_0 = PyList_New(len(fv_59_0));
    li_59_0l = 0;
    for it_59_0l in fv_59_0 {
        e_59_0l = _emit_node(it_59_0l);
        PyList_SetItem(v_59_0, li_59_0l, e_59_0l);
        li_59_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_59_0);
    Py_DecRef(v_59_0);

    fv_59_1 = nd.parent;
    if fv_59_1 is None {
        v_59_1 = _py_none();
    } else {
        v_59_1 = _emit_node(fv_59_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_59_1);
    Py_DecRef(v_59_1);

    v_59_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_59_2);
    Py_DecRef(v_59_2);

    fv_59_3 = nd._in_mod_nodes;
    v_59_3 = PyList_New(len(fv_59_3));
    li_59_3l = 0;
    for it_59_3l in fv_59_3 {
        e_59_3l = _emit_node(it_59_3l);
        PyList_SetItem(v_59_3, li_59_3l, e_59_3l);
        li_59_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_59_3);
    Py_DecRef(v_59_3);

    v_59_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_59_4);
    Py_DecRef(v_59_4);

    fv_59_5 = nd.loc;
    v_59_5 = _emit_CodeLocInfo(fv_59_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_59_5);
    Py_DecRef(v_59_5);

    fv_59_6 = nd.bb_in;
    v_59_6 = PyList_New(len(fv_59_6));
    li_59_6l = 0;
    for it_59_6l in fv_59_6 {
        e_59_6l = _emit_node(it_59_6l);
        PyList_SetItem(v_59_6, li_59_6l, e_59_6l);
        li_59_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_59_6);
    Py_DecRef(v_59_6);

    fv_59_7 = nd.bb_out;
    v_59_7 = PyList_New(len(fv_59_7));
    li_59_7l = 0;
    for it_59_7l in fv_59_7 {
        e_59_7l = _emit_node(it_59_7l);
        PyList_SetItem(v_59_7, li_59_7l, e_59_7l);
        li_59_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_59_7);
    Py_DecRef(v_59_7);

    fv_59_8 = nd.affected_symbols;
    v_59_8 = PySet_New(0);
    if len(fv_59_8) != 0 {
        Py_DecRef(v_59_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_59_8);
    Py_DecRef(v_59_8);

    fv_59_9 = nd.scope_name;
    v_59_9 = _py_str(fv_59_9);
    PyDict_SetItem(d_h, _mat_keys[18], v_59_9);
    Py_DecRef(v_59_9);

    fv_59_10 = nd.parent_scope;
    if fv_59_10 is None {
        v_59_10 = _py_none();
    } else {
        v_59_10 = _emit_node(fv_59_10);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_59_10);
    Py_DecRef(v_59_10);

    fv_59_11 = nd.kid_scope;
    v_59_11 = PyList_New(len(fv_59_11));
    li_59_11l = 0;
    for it_59_11l in fv_59_11 {
        e_59_11l = _emit_node(it_59_11l);
        PyList_SetItem(v_59_11, li_59_11l, e_59_11l);
        li_59_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_59_11);
    Py_DecRef(v_59_11);

    fv_59_12 = nd.names_in_scope;
    v_59_12 = PyDict_New();
    for (dk_59_12d, dv_59_12d) in fv_59_12.items() {
        kh_59_12d = _py_str(dk_59_12d);
        vh_59_12d = _emit_Symbol(dv_59_12d);
        PyDict_SetItem(v_59_12, kh_59_12d, vh_59_12d);
        Py_DecRef(kh_59_12d);
        Py_DecRef(vh_59_12d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_59_12);
    Py_DecRef(v_59_12);

    fv_59_13 = nd.names_in_scope_overload;
    v_59_13 = PyDict_New();
    for (dk_59_13d, dv_59_13d) in fv_59_13.items() {
        kh_59_13d = _py_str(dk_59_13d);
        vh_59_13d = PyList_New(len(dv_59_13d));
        li_59_13dl = 0;
        for it_59_13dl in dv_59_13d {
            e_59_13dl = _emit_Symbol(it_59_13dl);
            PyList_SetItem(vh_59_13d, li_59_13dl, e_59_13dl);
            li_59_13dl += 1;
        }
        PyDict_SetItem(v_59_13, kh_59_13d, vh_59_13d);
        Py_DecRef(kh_59_13d);
        Py_DecRef(vh_59_13d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_59_13);
    Py_DecRef(v_59_13);

    fv_59_14 = nd.implicit_rebinds;
    v_59_14 = PyDict_New();
    for (dk_59_14d, dv_59_14d) in fv_59_14.items() {
        kh_59_14d = _py_str(dk_59_14d);
        vh_59_14d = _emit_Symbol(dv_59_14d);
        PyDict_SetItem(v_59_14, kh_59_14d, vh_59_14d);
        Py_DecRef(kh_59_14d);
        Py_DecRef(vh_59_14d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_59_14);
    Py_DecRef(v_59_14);

    fv_59_15 = nd.ex_type;
    v_59_15 = _emit_node(fv_59_15);
    PyDict_SetItem(d_h, _mat_keys[119], v_59_15);
    Py_DecRef(v_59_15);

    fv_59_16 = nd.name;
    if fv_59_16 is None {
        v_59_16 = _py_none();
    } else {
        v_59_16 = _emit_node(fv_59_16);
    }
    PyDict_SetItem(d_h, _mat_keys[24], v_59_16);
    Py_DecRef(v_59_16);

    fv_59_17 = nd.body;
    v_59_17 = PyList_New(len(fv_59_17));
    li_59_17l = 0;
    for it_59_17l in fv_59_17 {
        e_59_17l = _emit_node(it_59_17l);
        PyList_SetItem(v_59_17, li_59_17l, e_59_17l);
        li_59_17l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_59_17);
    Py_DecRef(v_59_17);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_FinallyStmt(nd: FinallyStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[60], _mat_classes[60]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_60_0 = nd.kid;
    v_60_0 = PyList_New(len(fv_60_0));
    li_60_0l = 0;
    for it_60_0l in fv_60_0 {
        e_60_0l = _emit_node(it_60_0l);
        PyList_SetItem(v_60_0, li_60_0l, e_60_0l);
        li_60_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_60_0);
    Py_DecRef(v_60_0);

    fv_60_1 = nd.parent;
    if fv_60_1 is None {
        v_60_1 = _py_none();
    } else {
        v_60_1 = _emit_node(fv_60_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_60_1);
    Py_DecRef(v_60_1);

    v_60_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_60_2);
    Py_DecRef(v_60_2);

    fv_60_3 = nd._in_mod_nodes;
    v_60_3 = PyList_New(len(fv_60_3));
    li_60_3l = 0;
    for it_60_3l in fv_60_3 {
        e_60_3l = _emit_node(it_60_3l);
        PyList_SetItem(v_60_3, li_60_3l, e_60_3l);
        li_60_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_60_3);
    Py_DecRef(v_60_3);

    v_60_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_60_4);
    Py_DecRef(v_60_4);

    fv_60_5 = nd.loc;
    v_60_5 = _emit_CodeLocInfo(fv_60_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_60_5);
    Py_DecRef(v_60_5);

    fv_60_6 = nd.bb_in;
    v_60_6 = PyList_New(len(fv_60_6));
    li_60_6l = 0;
    for it_60_6l in fv_60_6 {
        e_60_6l = _emit_node(it_60_6l);
        PyList_SetItem(v_60_6, li_60_6l, e_60_6l);
        li_60_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_60_6);
    Py_DecRef(v_60_6);

    fv_60_7 = nd.bb_out;
    v_60_7 = PyList_New(len(fv_60_7));
    li_60_7l = 0;
    for it_60_7l in fv_60_7 {
        e_60_7l = _emit_node(it_60_7l);
        PyList_SetItem(v_60_7, li_60_7l, e_60_7l);
        li_60_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_60_7);
    Py_DecRef(v_60_7);

    fv_60_8 = nd.affected_symbols;
    v_60_8 = PySet_New(0);
    if len(fv_60_8) != 0 {
        Py_DecRef(v_60_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_60_8);
    Py_DecRef(v_60_8);

    fv_60_9 = nd.scope_name;
    v_60_9 = _py_str(fv_60_9);
    PyDict_SetItem(d_h, _mat_keys[18], v_60_9);
    Py_DecRef(v_60_9);

    fv_60_10 = nd.parent_scope;
    if fv_60_10 is None {
        v_60_10 = _py_none();
    } else {
        v_60_10 = _emit_node(fv_60_10);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_60_10);
    Py_DecRef(v_60_10);

    fv_60_11 = nd.kid_scope;
    v_60_11 = PyList_New(len(fv_60_11));
    li_60_11l = 0;
    for it_60_11l in fv_60_11 {
        e_60_11l = _emit_node(it_60_11l);
        PyList_SetItem(v_60_11, li_60_11l, e_60_11l);
        li_60_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_60_11);
    Py_DecRef(v_60_11);

    fv_60_12 = nd.names_in_scope;
    v_60_12 = PyDict_New();
    for (dk_60_12d, dv_60_12d) in fv_60_12.items() {
        kh_60_12d = _py_str(dk_60_12d);
        vh_60_12d = _emit_Symbol(dv_60_12d);
        PyDict_SetItem(v_60_12, kh_60_12d, vh_60_12d);
        Py_DecRef(kh_60_12d);
        Py_DecRef(vh_60_12d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_60_12);
    Py_DecRef(v_60_12);

    fv_60_13 = nd.names_in_scope_overload;
    v_60_13 = PyDict_New();
    for (dk_60_13d, dv_60_13d) in fv_60_13.items() {
        kh_60_13d = _py_str(dk_60_13d);
        vh_60_13d = PyList_New(len(dv_60_13d));
        li_60_13dl = 0;
        for it_60_13dl in dv_60_13d {
            e_60_13dl = _emit_Symbol(it_60_13dl);
            PyList_SetItem(vh_60_13d, li_60_13dl, e_60_13dl);
            li_60_13dl += 1;
        }
        PyDict_SetItem(v_60_13, kh_60_13d, vh_60_13d);
        Py_DecRef(kh_60_13d);
        Py_DecRef(vh_60_13d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_60_13);
    Py_DecRef(v_60_13);

    fv_60_14 = nd.implicit_rebinds;
    v_60_14 = PyDict_New();
    for (dk_60_14d, dv_60_14d) in fv_60_14.items() {
        kh_60_14d = _py_str(dk_60_14d);
        vh_60_14d = _emit_Symbol(dv_60_14d);
        PyDict_SetItem(v_60_14, kh_60_14d, vh_60_14d);
        Py_DecRef(kh_60_14d);
        Py_DecRef(vh_60_14d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_60_14);
    Py_DecRef(v_60_14);

    fv_60_15 = nd.body;
    v_60_15 = PyList_New(len(fv_60_15));
    li_60_15l = 0;
    for it_60_15l in fv_60_15 {
        e_60_15l = _emit_node(it_60_15l);
        PyList_SetItem(v_60_15, li_60_15l, e_60_15l);
        li_60_15l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_60_15);
    Py_DecRef(v_60_15);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ForeverStmt(nd: ForeverStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[61], _mat_classes[61]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_61_0 = nd.kid;
    v_61_0 = PyList_New(len(fv_61_0));
    li_61_0l = 0;
    for it_61_0l in fv_61_0 {
        e_61_0l = _emit_node(it_61_0l);
        PyList_SetItem(v_61_0, li_61_0l, e_61_0l);
        li_61_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_61_0);
    Py_DecRef(v_61_0);

    fv_61_1 = nd.parent;
    if fv_61_1 is None {
        v_61_1 = _py_none();
    } else {
        v_61_1 = _emit_node(fv_61_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_61_1);
    Py_DecRef(v_61_1);

    v_61_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_61_2);
    Py_DecRef(v_61_2);

    fv_61_3 = nd._in_mod_nodes;
    v_61_3 = PyList_New(len(fv_61_3));
    li_61_3l = 0;
    for it_61_3l in fv_61_3 {
        e_61_3l = _emit_node(it_61_3l);
        PyList_SetItem(v_61_3, li_61_3l, e_61_3l);
        li_61_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_61_3);
    Py_DecRef(v_61_3);

    v_61_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_61_4);
    Py_DecRef(v_61_4);

    fv_61_5 = nd.loc;
    v_61_5 = _emit_CodeLocInfo(fv_61_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_61_5);
    Py_DecRef(v_61_5);

    fv_61_6 = nd.bb_in;
    v_61_6 = PyList_New(len(fv_61_6));
    li_61_6l = 0;
    for it_61_6l in fv_61_6 {
        e_61_6l = _emit_node(it_61_6l);
        PyList_SetItem(v_61_6, li_61_6l, e_61_6l);
        li_61_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_61_6);
    Py_DecRef(v_61_6);

    fv_61_7 = nd.bb_out;
    v_61_7 = PyList_New(len(fv_61_7));
    li_61_7l = 0;
    for it_61_7l in fv_61_7 {
        e_61_7l = _emit_node(it_61_7l);
        PyList_SetItem(v_61_7, li_61_7l, e_61_7l);
        li_61_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_61_7);
    Py_DecRef(v_61_7);

    fv_61_8 = nd.affected_symbols;
    v_61_8 = PySet_New(0);
    if len(fv_61_8) != 0 {
        Py_DecRef(v_61_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_61_8);
    Py_DecRef(v_61_8);

    fv_61_9 = nd.scope_name;
    v_61_9 = _py_str(fv_61_9);
    PyDict_SetItem(d_h, _mat_keys[18], v_61_9);
    Py_DecRef(v_61_9);

    fv_61_10 = nd.parent_scope;
    if fv_61_10 is None {
        v_61_10 = _py_none();
    } else {
        v_61_10 = _emit_node(fv_61_10);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_61_10);
    Py_DecRef(v_61_10);

    fv_61_11 = nd.kid_scope;
    v_61_11 = PyList_New(len(fv_61_11));
    li_61_11l = 0;
    for it_61_11l in fv_61_11 {
        e_61_11l = _emit_node(it_61_11l);
        PyList_SetItem(v_61_11, li_61_11l, e_61_11l);
        li_61_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_61_11);
    Py_DecRef(v_61_11);

    fv_61_12 = nd.names_in_scope;
    v_61_12 = PyDict_New();
    for (dk_61_12d, dv_61_12d) in fv_61_12.items() {
        kh_61_12d = _py_str(dk_61_12d);
        vh_61_12d = _emit_Symbol(dv_61_12d);
        PyDict_SetItem(v_61_12, kh_61_12d, vh_61_12d);
        Py_DecRef(kh_61_12d);
        Py_DecRef(vh_61_12d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_61_12);
    Py_DecRef(v_61_12);

    fv_61_13 = nd.names_in_scope_overload;
    v_61_13 = PyDict_New();
    for (dk_61_13d, dv_61_13d) in fv_61_13.items() {
        kh_61_13d = _py_str(dk_61_13d);
        vh_61_13d = PyList_New(len(dv_61_13d));
        li_61_13dl = 0;
        for it_61_13dl in dv_61_13d {
            e_61_13dl = _emit_Symbol(it_61_13dl);
            PyList_SetItem(vh_61_13d, li_61_13dl, e_61_13dl);
            li_61_13dl += 1;
        }
        PyDict_SetItem(v_61_13, kh_61_13d, vh_61_13d);
        Py_DecRef(kh_61_13d);
        Py_DecRef(vh_61_13d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_61_13);
    Py_DecRef(v_61_13);

    fv_61_14 = nd.implicit_rebinds;
    v_61_14 = PyDict_New();
    for (dk_61_14d, dv_61_14d) in fv_61_14.items() {
        kh_61_14d = _py_str(dk_61_14d);
        vh_61_14d = _emit_Symbol(dv_61_14d);
        PyDict_SetItem(v_61_14, kh_61_14d, vh_61_14d);
        Py_DecRef(kh_61_14d);
        Py_DecRef(vh_61_14d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_61_14);
    Py_DecRef(v_61_14);

    fv_61_15 = nd.body;
    v_61_15 = PyList_New(len(fv_61_15));
    li_61_15l = 0;
    for it_61_15l in fv_61_15 {
        e_61_15l = _emit_node(it_61_15l);
        PyList_SetItem(v_61_15, li_61_15l, e_61_15l);
        li_61_15l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_61_15);
    Py_DecRef(v_61_15);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_InnerCompr(nd: InnerCompr) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[62], _mat_classes[62]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_62_0 = nd.kid;
    v_62_0 = PyList_New(len(fv_62_0));
    li_62_0l = 0;
    for it_62_0l in fv_62_0 {
        e_62_0l = _emit_node(it_62_0l);
        PyList_SetItem(v_62_0, li_62_0l, e_62_0l);
        li_62_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_62_0);
    Py_DecRef(v_62_0);

    fv_62_1 = nd.parent;
    if fv_62_1 is None {
        v_62_1 = _py_none();
    } else {
        v_62_1 = _emit_node(fv_62_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_62_1);
    Py_DecRef(v_62_1);

    v_62_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_62_2);
    Py_DecRef(v_62_2);

    fv_62_3 = nd._in_mod_nodes;
    v_62_3 = PyList_New(len(fv_62_3));
    li_62_3l = 0;
    for it_62_3l in fv_62_3 {
        e_62_3l = _emit_node(it_62_3l);
        PyList_SetItem(v_62_3, li_62_3l, e_62_3l);
        li_62_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_62_3);
    Py_DecRef(v_62_3);

    v_62_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_62_4);
    Py_DecRef(v_62_4);

    fv_62_5 = nd.loc;
    v_62_5 = _emit_CodeLocInfo(fv_62_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_62_5);
    Py_DecRef(v_62_5);

    fv_62_6 = nd.is_async;
    v_62_6 = PyBool_FromLong(1 if fv_62_6 else 0);
    PyDict_SetItem(d_h, _mat_keys[14], v_62_6);
    Py_DecRef(v_62_6);

    fv_62_7 = nd.scope_name;
    v_62_7 = _py_str(fv_62_7);
    PyDict_SetItem(d_h, _mat_keys[18], v_62_7);
    Py_DecRef(v_62_7);

    fv_62_8 = nd.parent_scope;
    if fv_62_8 is None {
        v_62_8 = _py_none();
    } else {
        v_62_8 = _emit_node(fv_62_8);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_62_8);
    Py_DecRef(v_62_8);

    fv_62_9 = nd.kid_scope;
    v_62_9 = PyList_New(len(fv_62_9));
    li_62_9l = 0;
    for it_62_9l in fv_62_9 {
        e_62_9l = _emit_node(it_62_9l);
        PyList_SetItem(v_62_9, li_62_9l, e_62_9l);
        li_62_9l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_62_9);
    Py_DecRef(v_62_9);

    fv_62_10 = nd.names_in_scope;
    v_62_10 = PyDict_New();
    for (dk_62_10d, dv_62_10d) in fv_62_10.items() {
        kh_62_10d = _py_str(dk_62_10d);
        vh_62_10d = _emit_Symbol(dv_62_10d);
        PyDict_SetItem(v_62_10, kh_62_10d, vh_62_10d);
        Py_DecRef(kh_62_10d);
        Py_DecRef(vh_62_10d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_62_10);
    Py_DecRef(v_62_10);

    fv_62_11 = nd.names_in_scope_overload;
    v_62_11 = PyDict_New();
    for (dk_62_11d, dv_62_11d) in fv_62_11.items() {
        kh_62_11d = _py_str(dk_62_11d);
        vh_62_11d = PyList_New(len(dv_62_11d));
        li_62_11dl = 0;
        for it_62_11dl in dv_62_11d {
            e_62_11dl = _emit_Symbol(it_62_11dl);
            PyList_SetItem(vh_62_11d, li_62_11dl, e_62_11dl);
            li_62_11dl += 1;
        }
        PyDict_SetItem(v_62_11, kh_62_11d, vh_62_11d);
        Py_DecRef(kh_62_11d);
        Py_DecRef(vh_62_11d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_62_11);
    Py_DecRef(v_62_11);

    fv_62_12 = nd.implicit_rebinds;
    v_62_12 = PyDict_New();
    for (dk_62_12d, dv_62_12d) in fv_62_12.items() {
        kh_62_12d = _py_str(dk_62_12d);
        vh_62_12d = _emit_Symbol(dv_62_12d);
        PyDict_SetItem(v_62_12, kh_62_12d, vh_62_12d);
        Py_DecRef(kh_62_12d);
        Py_DecRef(vh_62_12d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_62_12);
    Py_DecRef(v_62_12);

    fv_62_13 = nd.bb_in;
    v_62_13 = PyList_New(len(fv_62_13));
    li_62_13l = 0;
    for it_62_13l in fv_62_13 {
        e_62_13l = _emit_node(it_62_13l);
        PyList_SetItem(v_62_13, li_62_13l, e_62_13l);
        li_62_13l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_62_13);
    Py_DecRef(v_62_13);

    fv_62_14 = nd.bb_out;
    v_62_14 = PyList_New(len(fv_62_14));
    li_62_14l = 0;
    for it_62_14l in fv_62_14 {
        e_62_14l = _emit_node(it_62_14l);
        PyList_SetItem(v_62_14, li_62_14l, e_62_14l);
        li_62_14l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_62_14);
    Py_DecRef(v_62_14);

    fv_62_15 = nd.affected_symbols;
    v_62_15 = PySet_New(0);
    if len(fv_62_15) != 0 {
        Py_DecRef(v_62_15);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_62_15);
    Py_DecRef(v_62_15);

    fv_62_16 = nd.target;
    v_62_16 = _emit_node(fv_62_16);
    PyDict_SetItem(d_h, _mat_keys[60], v_62_16);
    Py_DecRef(v_62_16);

    fv_62_17 = nd.collection;
    v_62_17 = _emit_node(fv_62_17);
    PyDict_SetItem(d_h, _mat_keys[84], v_62_17);
    Py_DecRef(v_62_17);

    fv_62_18 = nd.conditional;
    if fv_62_18 is None {
        v_62_18 = _py_none();
    } else {
        v_62_18 = PyList_New(len(fv_62_18));
        li_62_18l = 0;
        for it_62_18l in fv_62_18 {
            e_62_18l = _emit_node(it_62_18l);
            PyList_SetItem(v_62_18, li_62_18l, e_62_18l);
            li_62_18l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[120], v_62_18);
    Py_DecRef(v_62_18);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_MatchCase(nd: MatchCase) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[63], _mat_classes[63]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_63_0 = nd.kid;
    v_63_0 = PyList_New(len(fv_63_0));
    li_63_0l = 0;
    for it_63_0l in fv_63_0 {
        e_63_0l = _emit_node(it_63_0l);
        PyList_SetItem(v_63_0, li_63_0l, e_63_0l);
        li_63_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_63_0);
    Py_DecRef(v_63_0);

    fv_63_1 = nd.parent;
    if fv_63_1 is None {
        v_63_1 = _py_none();
    } else {
        v_63_1 = _emit_node(fv_63_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_63_1);
    Py_DecRef(v_63_1);

    v_63_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_63_2);
    Py_DecRef(v_63_2);

    fv_63_3 = nd._in_mod_nodes;
    v_63_3 = PyList_New(len(fv_63_3));
    li_63_3l = 0;
    for it_63_3l in fv_63_3 {
        e_63_3l = _emit_node(it_63_3l);
        PyList_SetItem(v_63_3, li_63_3l, e_63_3l);
        li_63_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_63_3);
    Py_DecRef(v_63_3);

    v_63_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_63_4);
    Py_DecRef(v_63_4);

    fv_63_5 = nd.loc;
    v_63_5 = _emit_CodeLocInfo(fv_63_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_63_5);
    Py_DecRef(v_63_5);

    fv_63_6 = nd.bb_in;
    v_63_6 = PyList_New(len(fv_63_6));
    li_63_6l = 0;
    for it_63_6l in fv_63_6 {
        e_63_6l = _emit_node(it_63_6l);
        PyList_SetItem(v_63_6, li_63_6l, e_63_6l);
        li_63_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_63_6);
    Py_DecRef(v_63_6);

    fv_63_7 = nd.bb_out;
    v_63_7 = PyList_New(len(fv_63_7));
    li_63_7l = 0;
    for it_63_7l in fv_63_7 {
        e_63_7l = _emit_node(it_63_7l);
        PyList_SetItem(v_63_7, li_63_7l, e_63_7l);
        li_63_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_63_7);
    Py_DecRef(v_63_7);

    fv_63_8 = nd.affected_symbols;
    v_63_8 = PySet_New(0);
    if len(fv_63_8) != 0 {
        Py_DecRef(v_63_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_63_8);
    Py_DecRef(v_63_8);

    fv_63_9 = nd.scope_name;
    v_63_9 = _py_str(fv_63_9);
    PyDict_SetItem(d_h, _mat_keys[18], v_63_9);
    Py_DecRef(v_63_9);

    fv_63_10 = nd.parent_scope;
    if fv_63_10 is None {
        v_63_10 = _py_none();
    } else {
        v_63_10 = _emit_node(fv_63_10);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_63_10);
    Py_DecRef(v_63_10);

    fv_63_11 = nd.kid_scope;
    v_63_11 = PyList_New(len(fv_63_11));
    li_63_11l = 0;
    for it_63_11l in fv_63_11 {
        e_63_11l = _emit_node(it_63_11l);
        PyList_SetItem(v_63_11, li_63_11l, e_63_11l);
        li_63_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_63_11);
    Py_DecRef(v_63_11);

    fv_63_12 = nd.names_in_scope;
    v_63_12 = PyDict_New();
    for (dk_63_12d, dv_63_12d) in fv_63_12.items() {
        kh_63_12d = _py_str(dk_63_12d);
        vh_63_12d = _emit_Symbol(dv_63_12d);
        PyDict_SetItem(v_63_12, kh_63_12d, vh_63_12d);
        Py_DecRef(kh_63_12d);
        Py_DecRef(vh_63_12d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_63_12);
    Py_DecRef(v_63_12);

    fv_63_13 = nd.names_in_scope_overload;
    v_63_13 = PyDict_New();
    for (dk_63_13d, dv_63_13d) in fv_63_13.items() {
        kh_63_13d = _py_str(dk_63_13d);
        vh_63_13d = PyList_New(len(dv_63_13d));
        li_63_13dl = 0;
        for it_63_13dl in dv_63_13d {
            e_63_13dl = _emit_Symbol(it_63_13dl);
            PyList_SetItem(vh_63_13d, li_63_13dl, e_63_13dl);
            li_63_13dl += 1;
        }
        PyDict_SetItem(v_63_13, kh_63_13d, vh_63_13d);
        Py_DecRef(kh_63_13d);
        Py_DecRef(vh_63_13d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_63_13);
    Py_DecRef(v_63_13);

    fv_63_14 = nd.implicit_rebinds;
    v_63_14 = PyDict_New();
    for (dk_63_14d, dv_63_14d) in fv_63_14.items() {
        kh_63_14d = _py_str(dk_63_14d);
        vh_63_14d = _emit_Symbol(dv_63_14d);
        PyDict_SetItem(v_63_14, kh_63_14d, vh_63_14d);
        Py_DecRef(kh_63_14d);
        Py_DecRef(vh_63_14d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_63_14);
    Py_DecRef(v_63_14);

    fv_63_15 = nd.pattern;
    v_63_15 = _emit_node(fv_63_15);
    PyDict_SetItem(d_h, _mat_keys[121], v_63_15);
    Py_DecRef(v_63_15);

    fv_63_16 = nd.guard;
    if fv_63_16 is None {
        v_63_16 = _py_none();
    } else {
        v_63_16 = _emit_node(fv_63_16);
    }
    PyDict_SetItem(d_h, _mat_keys[122], v_63_16);
    Py_DecRef(v_63_16);

    fv_63_17 = nd.body;
    v_63_17 = PyList_New(len(fv_63_17));
    li_63_17l = 0;
    for it_63_17l in fv_63_17 {
        e_63_17l = _emit_node(it_63_17l);
        PyList_SetItem(v_63_17, li_63_17l, e_63_17l);
        li_63_17l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_63_17);
    Py_DecRef(v_63_17);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_OpenStmt(nd: OpenStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[64], _mat_classes[64]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_64_0 = nd.kid;
    v_64_0 = PyList_New(len(fv_64_0));
    li_64_0l = 0;
    for it_64_0l in fv_64_0 {
        e_64_0l = _emit_node(it_64_0l);
        PyList_SetItem(v_64_0, li_64_0l, e_64_0l);
        li_64_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_64_0);
    Py_DecRef(v_64_0);

    fv_64_1 = nd.parent;
    if fv_64_1 is None {
        v_64_1 = _py_none();
    } else {
        v_64_1 = _emit_node(fv_64_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_64_1);
    Py_DecRef(v_64_1);

    v_64_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_64_2);
    Py_DecRef(v_64_2);

    fv_64_3 = nd._in_mod_nodes;
    v_64_3 = PyList_New(len(fv_64_3));
    li_64_3l = 0;
    for it_64_3l in fv_64_3 {
        e_64_3l = _emit_node(it_64_3l);
        PyList_SetItem(v_64_3, li_64_3l, e_64_3l);
        li_64_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_64_3);
    Py_DecRef(v_64_3);

    v_64_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_64_4);
    Py_DecRef(v_64_4);

    fv_64_5 = nd.loc;
    v_64_5 = _emit_CodeLocInfo(fv_64_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_64_5);
    Py_DecRef(v_64_5);

    fv_64_6 = nd.bb_in;
    v_64_6 = PyList_New(len(fv_64_6));
    li_64_6l = 0;
    for it_64_6l in fv_64_6 {
        e_64_6l = _emit_node(it_64_6l);
        PyList_SetItem(v_64_6, li_64_6l, e_64_6l);
        li_64_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_64_6);
    Py_DecRef(v_64_6);

    fv_64_7 = nd.bb_out;
    v_64_7 = PyList_New(len(fv_64_7));
    li_64_7l = 0;
    for it_64_7l in fv_64_7 {
        e_64_7l = _emit_node(it_64_7l);
        PyList_SetItem(v_64_7, li_64_7l, e_64_7l);
        li_64_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_64_7);
    Py_DecRef(v_64_7);

    fv_64_8 = nd.affected_symbols;
    v_64_8 = PySet_New(0);
    if len(fv_64_8) != 0 {
        Py_DecRef(v_64_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_64_8);
    Py_DecRef(v_64_8);

    fv_64_9 = nd.scope_name;
    v_64_9 = _py_str(fv_64_9);
    PyDict_SetItem(d_h, _mat_keys[18], v_64_9);
    Py_DecRef(v_64_9);

    fv_64_10 = nd.parent_scope;
    if fv_64_10 is None {
        v_64_10 = _py_none();
    } else {
        v_64_10 = _emit_node(fv_64_10);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_64_10);
    Py_DecRef(v_64_10);

    fv_64_11 = nd.kid_scope;
    v_64_11 = PyList_New(len(fv_64_11));
    li_64_11l = 0;
    for it_64_11l in fv_64_11 {
        e_64_11l = _emit_node(it_64_11l);
        PyList_SetItem(v_64_11, li_64_11l, e_64_11l);
        li_64_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_64_11);
    Py_DecRef(v_64_11);

    fv_64_12 = nd.names_in_scope;
    v_64_12 = PyDict_New();
    for (dk_64_12d, dv_64_12d) in fv_64_12.items() {
        kh_64_12d = _py_str(dk_64_12d);
        vh_64_12d = _emit_Symbol(dv_64_12d);
        PyDict_SetItem(v_64_12, kh_64_12d, vh_64_12d);
        Py_DecRef(kh_64_12d);
        Py_DecRef(vh_64_12d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_64_12);
    Py_DecRef(v_64_12);

    fv_64_13 = nd.names_in_scope_overload;
    v_64_13 = PyDict_New();
    for (dk_64_13d, dv_64_13d) in fv_64_13.items() {
        kh_64_13d = _py_str(dk_64_13d);
        vh_64_13d = PyList_New(len(dv_64_13d));
        li_64_13dl = 0;
        for it_64_13dl in dv_64_13d {
            e_64_13dl = _emit_Symbol(it_64_13dl);
            PyList_SetItem(vh_64_13d, li_64_13dl, e_64_13dl);
            li_64_13dl += 1;
        }
        PyDict_SetItem(v_64_13, kh_64_13d, vh_64_13d);
        Py_DecRef(kh_64_13d);
        Py_DecRef(vh_64_13d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_64_13);
    Py_DecRef(v_64_13);

    fv_64_14 = nd.implicit_rebinds;
    v_64_14 = PyDict_New();
    for (dk_64_14d, dv_64_14d) in fv_64_14.items() {
        kh_64_14d = _py_str(dk_64_14d);
        vh_64_14d = _emit_Symbol(dv_64_14d);
        PyDict_SetItem(v_64_14, kh_64_14d, vh_64_14d);
        Py_DecRef(kh_64_14d);
        Py_DecRef(vh_64_14d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_64_14);
    Py_DecRef(v_64_14);

    fv_64_15 = nd.target;
    v_64_15 = _emit_node(fv_64_15);
    PyDict_SetItem(d_h, _mat_keys[60], v_64_15);
    Py_DecRef(v_64_15);

    fv_64_16 = nd.body;
    v_64_16 = PyList_New(len(fv_64_16));
    li_64_16l = 0;
    for it_64_16l in fv_64_16 {
        e_64_16l = _emit_node(it_64_16l);
        PyList_SetItem(v_64_16, li_64_16l, e_64_16l);
        li_64_16l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_64_16);
    Py_DecRef(v_64_16);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_SwitchCase(nd: SwitchCase) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[65], _mat_classes[65]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_65_0 = nd.kid;
    v_65_0 = PyList_New(len(fv_65_0));
    li_65_0l = 0;
    for it_65_0l in fv_65_0 {
        e_65_0l = _emit_node(it_65_0l);
        PyList_SetItem(v_65_0, li_65_0l, e_65_0l);
        li_65_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_65_0);
    Py_DecRef(v_65_0);

    fv_65_1 = nd.parent;
    if fv_65_1 is None {
        v_65_1 = _py_none();
    } else {
        v_65_1 = _emit_node(fv_65_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_65_1);
    Py_DecRef(v_65_1);

    v_65_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_65_2);
    Py_DecRef(v_65_2);

    fv_65_3 = nd._in_mod_nodes;
    v_65_3 = PyList_New(len(fv_65_3));
    li_65_3l = 0;
    for it_65_3l in fv_65_3 {
        e_65_3l = _emit_node(it_65_3l);
        PyList_SetItem(v_65_3, li_65_3l, e_65_3l);
        li_65_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_65_3);
    Py_DecRef(v_65_3);

    v_65_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_65_4);
    Py_DecRef(v_65_4);

    fv_65_5 = nd.loc;
    v_65_5 = _emit_CodeLocInfo(fv_65_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_65_5);
    Py_DecRef(v_65_5);

    fv_65_6 = nd.bb_in;
    v_65_6 = PyList_New(len(fv_65_6));
    li_65_6l = 0;
    for it_65_6l in fv_65_6 {
        e_65_6l = _emit_node(it_65_6l);
        PyList_SetItem(v_65_6, li_65_6l, e_65_6l);
        li_65_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_65_6);
    Py_DecRef(v_65_6);

    fv_65_7 = nd.bb_out;
    v_65_7 = PyList_New(len(fv_65_7));
    li_65_7l = 0;
    for it_65_7l in fv_65_7 {
        e_65_7l = _emit_node(it_65_7l);
        PyList_SetItem(v_65_7, li_65_7l, e_65_7l);
        li_65_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_65_7);
    Py_DecRef(v_65_7);

    fv_65_8 = nd.affected_symbols;
    v_65_8 = PySet_New(0);
    if len(fv_65_8) != 0 {
        Py_DecRef(v_65_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_65_8);
    Py_DecRef(v_65_8);

    fv_65_9 = nd.scope_name;
    v_65_9 = _py_str(fv_65_9);
    PyDict_SetItem(d_h, _mat_keys[18], v_65_9);
    Py_DecRef(v_65_9);

    fv_65_10 = nd.parent_scope;
    if fv_65_10 is None {
        v_65_10 = _py_none();
    } else {
        v_65_10 = _emit_node(fv_65_10);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_65_10);
    Py_DecRef(v_65_10);

    fv_65_11 = nd.kid_scope;
    v_65_11 = PyList_New(len(fv_65_11));
    li_65_11l = 0;
    for it_65_11l in fv_65_11 {
        e_65_11l = _emit_node(it_65_11l);
        PyList_SetItem(v_65_11, li_65_11l, e_65_11l);
        li_65_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_65_11);
    Py_DecRef(v_65_11);

    fv_65_12 = nd.names_in_scope;
    v_65_12 = PyDict_New();
    for (dk_65_12d, dv_65_12d) in fv_65_12.items() {
        kh_65_12d = _py_str(dk_65_12d);
        vh_65_12d = _emit_Symbol(dv_65_12d);
        PyDict_SetItem(v_65_12, kh_65_12d, vh_65_12d);
        Py_DecRef(kh_65_12d);
        Py_DecRef(vh_65_12d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_65_12);
    Py_DecRef(v_65_12);

    fv_65_13 = nd.names_in_scope_overload;
    v_65_13 = PyDict_New();
    for (dk_65_13d, dv_65_13d) in fv_65_13.items() {
        kh_65_13d = _py_str(dk_65_13d);
        vh_65_13d = PyList_New(len(dv_65_13d));
        li_65_13dl = 0;
        for it_65_13dl in dv_65_13d {
            e_65_13dl = _emit_Symbol(it_65_13dl);
            PyList_SetItem(vh_65_13d, li_65_13dl, e_65_13dl);
            li_65_13dl += 1;
        }
        PyDict_SetItem(v_65_13, kh_65_13d, vh_65_13d);
        Py_DecRef(kh_65_13d);
        Py_DecRef(vh_65_13d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_65_13);
    Py_DecRef(v_65_13);

    fv_65_14 = nd.implicit_rebinds;
    v_65_14 = PyDict_New();
    for (dk_65_14d, dv_65_14d) in fv_65_14.items() {
        kh_65_14d = _py_str(dk_65_14d);
        vh_65_14d = _emit_Symbol(dv_65_14d);
        PyDict_SetItem(v_65_14, kh_65_14d, vh_65_14d);
        Py_DecRef(kh_65_14d);
        Py_DecRef(vh_65_14d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_65_14);
    Py_DecRef(v_65_14);

    fv_65_15 = nd.pattern;
    if fv_65_15 is None {
        v_65_15 = _py_none();
    } else {
        v_65_15 = _emit_node(fv_65_15);
    }
    PyDict_SetItem(d_h, _mat_keys[121], v_65_15);
    Py_DecRef(v_65_15);

    fv_65_16 = nd.body;
    v_65_16 = PyList_New(len(fv_65_16));
    li_65_16l = 0;
    for it_65_16l in fv_65_16 {
        e_65_16l = _emit_node(it_65_16l);
        PyList_SetItem(v_65_16, li_65_16l, e_65_16l);
        li_65_16l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_65_16);
    Py_DecRef(v_65_16);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_AssertStmt(nd: AssertStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[66], _mat_classes[66]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_66_0 = nd.kid;
    v_66_0 = PyList_New(len(fv_66_0));
    li_66_0l = 0;
    for it_66_0l in fv_66_0 {
        e_66_0l = _emit_node(it_66_0l);
        PyList_SetItem(v_66_0, li_66_0l, e_66_0l);
        li_66_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_66_0);
    Py_DecRef(v_66_0);

    fv_66_1 = nd.parent;
    if fv_66_1 is None {
        v_66_1 = _py_none();
    } else {
        v_66_1 = _emit_node(fv_66_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_66_1);
    Py_DecRef(v_66_1);

    v_66_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_66_2);
    Py_DecRef(v_66_2);

    fv_66_3 = nd._in_mod_nodes;
    v_66_3 = PyList_New(len(fv_66_3));
    li_66_3l = 0;
    for it_66_3l in fv_66_3 {
        e_66_3l = _emit_node(it_66_3l);
        PyList_SetItem(v_66_3, li_66_3l, e_66_3l);
        li_66_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_66_3);
    Py_DecRef(v_66_3);

    v_66_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_66_4);
    Py_DecRef(v_66_4);

    fv_66_5 = nd.loc;
    v_66_5 = _emit_CodeLocInfo(fv_66_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_66_5);
    Py_DecRef(v_66_5);

    fv_66_6 = nd.bb_in;
    v_66_6 = PyList_New(len(fv_66_6));
    li_66_6l = 0;
    for it_66_6l in fv_66_6 {
        e_66_6l = _emit_node(it_66_6l);
        PyList_SetItem(v_66_6, li_66_6l, e_66_6l);
        li_66_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_66_6);
    Py_DecRef(v_66_6);

    fv_66_7 = nd.bb_out;
    v_66_7 = PyList_New(len(fv_66_7));
    li_66_7l = 0;
    for it_66_7l in fv_66_7 {
        e_66_7l = _emit_node(it_66_7l);
        PyList_SetItem(v_66_7, li_66_7l, e_66_7l);
        li_66_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_66_7);
    Py_DecRef(v_66_7);

    fv_66_8 = nd.affected_symbols;
    v_66_8 = PySet_New(0);
    if len(fv_66_8) != 0 {
        Py_DecRef(v_66_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_66_8);
    Py_DecRef(v_66_8);

    fv_66_9 = nd.condition;
    v_66_9 = _emit_node(fv_66_9);
    PyDict_SetItem(d_h, _mat_keys[77], v_66_9);
    Py_DecRef(v_66_9);

    fv_66_10 = nd.error_msg;
    if fv_66_10 is None {
        v_66_10 = _py_none();
    } else {
        v_66_10 = _emit_node(fv_66_10);
    }
    PyDict_SetItem(d_h, _mat_keys[123], v_66_10);
    Py_DecRef(v_66_10);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_AstImplNeedingNode(nd: AstImplNeedingNode) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[67], _mat_classes[67]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_67_0 = nd.kid;
    v_67_0 = PyList_New(len(fv_67_0));
    li_67_0l = 0;
    for it_67_0l in fv_67_0 {
        e_67_0l = _emit_node(it_67_0l);
        PyList_SetItem(v_67_0, li_67_0l, e_67_0l);
        li_67_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_67_0);
    Py_DecRef(v_67_0);

    fv_67_1 = nd.parent;
    if fv_67_1 is None {
        v_67_1 = _py_none();
    } else {
        v_67_1 = _emit_node(fv_67_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_67_1);
    Py_DecRef(v_67_1);

    v_67_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_67_2);
    Py_DecRef(v_67_2);

    fv_67_3 = nd._in_mod_nodes;
    v_67_3 = PyList_New(len(fv_67_3));
    li_67_3l = 0;
    for it_67_3l in fv_67_3 {
        e_67_3l = _emit_node(it_67_3l);
        PyList_SetItem(v_67_3, li_67_3l, e_67_3l);
        li_67_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_67_3);
    Py_DecRef(v_67_3);

    v_67_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_67_4);
    Py_DecRef(v_67_4);

    fv_67_5 = nd.loc;
    v_67_5 = _emit_CodeLocInfo(fv_67_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_67_5);
    Py_DecRef(v_67_5);

    fv_67_6 = nd.name_spec;
    v_67_6 = _emit_node(fv_67_6);
    PyDict_SetItem(d_h, _mat_keys[12], v_67_6);
    Py_DecRef(v_67_6);

    fv_67_7 = nd.semstr;
    v_67_7 = _py_str(fv_67_7);
    PyDict_SetItem(d_h, _mat_keys[13], v_67_7);
    Py_DecRef(v_67_7);

    v_67_8 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[17], v_67_8);
    Py_DecRef(v_67_8);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_CtrlStmt(nd: CtrlStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[68], _mat_classes[68]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_68_0 = nd.kid;
    v_68_0 = PyList_New(len(fv_68_0));
    li_68_0l = 0;
    for it_68_0l in fv_68_0 {
        e_68_0l = _emit_node(it_68_0l);
        PyList_SetItem(v_68_0, li_68_0l, e_68_0l);
        li_68_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_68_0);
    Py_DecRef(v_68_0);

    fv_68_1 = nd.parent;
    if fv_68_1 is None {
        v_68_1 = _py_none();
    } else {
        v_68_1 = _emit_node(fv_68_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_68_1);
    Py_DecRef(v_68_1);

    v_68_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_68_2);
    Py_DecRef(v_68_2);

    fv_68_3 = nd._in_mod_nodes;
    v_68_3 = PyList_New(len(fv_68_3));
    li_68_3l = 0;
    for it_68_3l in fv_68_3 {
        e_68_3l = _emit_node(it_68_3l);
        PyList_SetItem(v_68_3, li_68_3l, e_68_3l);
        li_68_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_68_3);
    Py_DecRef(v_68_3);

    v_68_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_68_4);
    Py_DecRef(v_68_4);

    fv_68_5 = nd.loc;
    v_68_5 = _emit_CodeLocInfo(fv_68_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_68_5);
    Py_DecRef(v_68_5);

    fv_68_6 = nd.bb_in;
    v_68_6 = PyList_New(len(fv_68_6));
    li_68_6l = 0;
    for it_68_6l in fv_68_6 {
        e_68_6l = _emit_node(it_68_6l);
        PyList_SetItem(v_68_6, li_68_6l, e_68_6l);
        li_68_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_68_6);
    Py_DecRef(v_68_6);

    fv_68_7 = nd.bb_out;
    v_68_7 = PyList_New(len(fv_68_7));
    li_68_7l = 0;
    for it_68_7l in fv_68_7 {
        e_68_7l = _emit_node(it_68_7l);
        PyList_SetItem(v_68_7, li_68_7l, e_68_7l);
        li_68_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_68_7);
    Py_DecRef(v_68_7);

    fv_68_8 = nd.affected_symbols;
    v_68_8 = PySet_New(0);
    if len(fv_68_8) != 0 {
        Py_DecRef(v_68_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_68_8);
    Py_DecRef(v_68_8);

    fv_68_9 = nd.ctrl;
    v_68_9 = _emit_node(fv_68_9);
    PyDict_SetItem(d_h, _mat_keys[124], v_68_9);
    Py_DecRef(v_68_9);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_DeleteStmt(nd: DeleteStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[69], _mat_classes[69]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_69_0 = nd.kid;
    v_69_0 = PyList_New(len(fv_69_0));
    li_69_0l = 0;
    for it_69_0l in fv_69_0 {
        e_69_0l = _emit_node(it_69_0l);
        PyList_SetItem(v_69_0, li_69_0l, e_69_0l);
        li_69_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_69_0);
    Py_DecRef(v_69_0);

    fv_69_1 = nd.parent;
    if fv_69_1 is None {
        v_69_1 = _py_none();
    } else {
        v_69_1 = _emit_node(fv_69_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_69_1);
    Py_DecRef(v_69_1);

    v_69_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_69_2);
    Py_DecRef(v_69_2);

    fv_69_3 = nd._in_mod_nodes;
    v_69_3 = PyList_New(len(fv_69_3));
    li_69_3l = 0;
    for it_69_3l in fv_69_3 {
        e_69_3l = _emit_node(it_69_3l);
        PyList_SetItem(v_69_3, li_69_3l, e_69_3l);
        li_69_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_69_3);
    Py_DecRef(v_69_3);

    v_69_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_69_4);
    Py_DecRef(v_69_4);

    fv_69_5 = nd.loc;
    v_69_5 = _emit_CodeLocInfo(fv_69_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_69_5);
    Py_DecRef(v_69_5);

    fv_69_6 = nd.bb_in;
    v_69_6 = PyList_New(len(fv_69_6));
    li_69_6l = 0;
    for it_69_6l in fv_69_6 {
        e_69_6l = _emit_node(it_69_6l);
        PyList_SetItem(v_69_6, li_69_6l, e_69_6l);
        li_69_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_69_6);
    Py_DecRef(v_69_6);

    fv_69_7 = nd.bb_out;
    v_69_7 = PyList_New(len(fv_69_7));
    li_69_7l = 0;
    for it_69_7l in fv_69_7 {
        e_69_7l = _emit_node(it_69_7l);
        PyList_SetItem(v_69_7, li_69_7l, e_69_7l);
        li_69_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_69_7);
    Py_DecRef(v_69_7);

    fv_69_8 = nd.affected_symbols;
    v_69_8 = PySet_New(0);
    if len(fv_69_8) != 0 {
        Py_DecRef(v_69_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_69_8);
    Py_DecRef(v_69_8);

    fv_69_9 = nd.target;
    v_69_9 = _emit_node(fv_69_9);
    PyDict_SetItem(d_h, _mat_keys[60], v_69_9);
    Py_DecRef(v_69_9);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ExprStmt(nd: ExprStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[70], _mat_classes[70]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_70_0 = nd.kid;
    v_70_0 = PyList_New(len(fv_70_0));
    li_70_0l = 0;
    for it_70_0l in fv_70_0 {
        e_70_0l = _emit_node(it_70_0l);
        PyList_SetItem(v_70_0, li_70_0l, e_70_0l);
        li_70_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_70_0);
    Py_DecRef(v_70_0);

    fv_70_1 = nd.parent;
    if fv_70_1 is None {
        v_70_1 = _py_none();
    } else {
        v_70_1 = _emit_node(fv_70_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_70_1);
    Py_DecRef(v_70_1);

    v_70_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_70_2);
    Py_DecRef(v_70_2);

    fv_70_3 = nd._in_mod_nodes;
    v_70_3 = PyList_New(len(fv_70_3));
    li_70_3l = 0;
    for it_70_3l in fv_70_3 {
        e_70_3l = _emit_node(it_70_3l);
        PyList_SetItem(v_70_3, li_70_3l, e_70_3l);
        li_70_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_70_3);
    Py_DecRef(v_70_3);

    v_70_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_70_4);
    Py_DecRef(v_70_4);

    fv_70_5 = nd.loc;
    v_70_5 = _emit_CodeLocInfo(fv_70_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_70_5);
    Py_DecRef(v_70_5);

    fv_70_6 = nd.bb_in;
    v_70_6 = PyList_New(len(fv_70_6));
    li_70_6l = 0;
    for it_70_6l in fv_70_6 {
        e_70_6l = _emit_node(it_70_6l);
        PyList_SetItem(v_70_6, li_70_6l, e_70_6l);
        li_70_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_70_6);
    Py_DecRef(v_70_6);

    fv_70_7 = nd.bb_out;
    v_70_7 = PyList_New(len(fv_70_7));
    li_70_7l = 0;
    for it_70_7l in fv_70_7 {
        e_70_7l = _emit_node(it_70_7l);
        PyList_SetItem(v_70_7, li_70_7l, e_70_7l);
        li_70_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_70_7);
    Py_DecRef(v_70_7);

    fv_70_8 = nd.affected_symbols;
    v_70_8 = PySet_New(0);
    if len(fv_70_8) != 0 {
        Py_DecRef(v_70_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_70_8);
    Py_DecRef(v_70_8);

    fv_70_9 = nd.expr;
    v_70_9 = _emit_node(fv_70_9);
    PyDict_SetItem(d_h, _mat_keys[118], v_70_9);
    Py_DecRef(v_70_9);

    fv_70_10 = nd.in_fstring;
    v_70_10 = PyBool_FromLong(1 if fv_70_10 else 0);
    PyDict_SetItem(d_h, _mat_keys[125], v_70_10);
    Py_DecRef(v_70_10);

    fv_70_11 = nd.has_semi;
    v_70_11 = PyBool_FromLong(1 if fv_70_11 else 0);
    PyDict_SetItem(d_h, _mat_keys[126], v_70_11);
    Py_DecRef(v_70_11);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_HasVar(nd: HasVar) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[71], _mat_classes[71]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_71_0 = nd.kid;
    v_71_0 = PyList_New(len(fv_71_0));
    li_71_0l = 0;
    for it_71_0l in fv_71_0 {
        e_71_0l = _emit_node(it_71_0l);
        PyList_SetItem(v_71_0, li_71_0l, e_71_0l);
        li_71_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_71_0);
    Py_DecRef(v_71_0);

    fv_71_1 = nd.parent;
    if fv_71_1 is None {
        v_71_1 = _py_none();
    } else {
        v_71_1 = _emit_node(fv_71_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_71_1);
    Py_DecRef(v_71_1);

    v_71_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_71_2);
    Py_DecRef(v_71_2);

    fv_71_3 = nd._in_mod_nodes;
    v_71_3 = PyList_New(len(fv_71_3));
    li_71_3l = 0;
    for it_71_3l in fv_71_3 {
        e_71_3l = _emit_node(it_71_3l);
        PyList_SetItem(v_71_3, li_71_3l, e_71_3l);
        li_71_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_71_3);
    Py_DecRef(v_71_3);

    v_71_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_71_4);
    Py_DecRef(v_71_4);

    fv_71_5 = nd.loc;
    v_71_5 = _emit_CodeLocInfo(fv_71_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_71_5);
    Py_DecRef(v_71_5);

    fv_71_6 = nd.name_spec;
    v_71_6 = _emit_node(fv_71_6);
    PyDict_SetItem(d_h, _mat_keys[12], v_71_6);
    Py_DecRef(v_71_6);

    fv_71_7 = nd.semstr;
    v_71_7 = _py_str(fv_71_7);
    PyDict_SetItem(d_h, _mat_keys[13], v_71_7);
    Py_DecRef(v_71_7);

    fv_71_8 = nd.type_tag;
    if fv_71_8 is None {
        v_71_8 = _py_none();
    } else {
        v_71_8 = _emit_node(fv_71_8);
    }
    PyDict_SetItem(d_h, _mat_keys[89], v_71_8);
    Py_DecRef(v_71_8);

    fv_71_9 = nd.name;
    if isinstance(fv_71_9, Name) {
        v_71_9 = _emit_node(fv_71_9);
    } elif isinstance(fv_71_9, CtName) {
        v_71_9 = _emit_node(fv_71_9);
    } else {
        v_71_9 = _py_none();
    }
    PyDict_SetItem(d_h, _mat_keys[24], v_71_9);
    Py_DecRef(v_71_9);

    fv_71_10 = nd.value;
    if fv_71_10 is None {
        v_71_10 = _py_none();
    } else {
        v_71_10 = _emit_node(fv_71_10);
    }
    PyDict_SetItem(d_h, _mat_keys[42], v_71_10);
    Py_DecRef(v_71_10);

    fv_71_11 = nd.defer;
    v_71_11 = PyBool_FromLong(1 if fv_71_11 else 0);
    PyDict_SetItem(d_h, _mat_keys[127], v_71_11);
    Py_DecRef(v_71_11);

    fv_71_12 = nd.accessors;
    if fv_71_12 is None {
        v_71_12 = _py_none();
    } else {
        v_71_12 = PyList_New(len(fv_71_12));
        li_71_12l = 0;
        for it_71_12l in fv_71_12 {
            e_71_12l = _emit_node(it_71_12l);
            PyList_SetItem(v_71_12, li_71_12l, e_71_12l);
            li_71_12l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[128], v_71_12);
    Py_DecRef(v_71_12);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_LambdaExpr(nd: LambdaExpr) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[72], _mat_classes[72]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_72_0 = nd.kid;
    v_72_0 = PyList_New(len(fv_72_0));
    li_72_0l = 0;
    for it_72_0l in fv_72_0 {
        e_72_0l = _emit_node(it_72_0l);
        PyList_SetItem(v_72_0, li_72_0l, e_72_0l);
        li_72_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_72_0);
    Py_DecRef(v_72_0);

    fv_72_1 = nd.parent;
    if fv_72_1 is None {
        v_72_1 = _py_none();
    } else {
        v_72_1 = _emit_node(fv_72_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_72_1);
    Py_DecRef(v_72_1);

    v_72_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_72_2);
    Py_DecRef(v_72_2);

    fv_72_3 = nd._in_mod_nodes;
    v_72_3 = PyList_New(len(fv_72_3));
    li_72_3l = 0;
    for it_72_3l in fv_72_3 {
        e_72_3l = _emit_node(it_72_3l);
        PyList_SetItem(v_72_3, li_72_3l, e_72_3l);
        li_72_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_72_3);
    Py_DecRef(v_72_3);

    v_72_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_72_4);
    Py_DecRef(v_72_4);

    fv_72_5 = nd.loc;
    v_72_5 = _emit_CodeLocInfo(fv_72_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_72_5);
    Py_DecRef(v_72_5);

    fv_72_6 = nd._type_sym_tab;
    if fv_72_6 is None {
        v_72_6 = _py_none();
    } else {
        v_72_6 = _emit_node(fv_72_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_72_6);
    Py_DecRef(v_72_6);

    v_72_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_72_7);
    Py_DecRef(v_72_7);

    fv_72_8 = nd.attached_tokens;
    if fv_72_8 is None {
        v_72_8 = _py_none();
    } else {
        v_72_8 = PyList_New(len(fv_72_8));
        li_72_8l = 0;
        for it_72_8l in fv_72_8 {
            e_72_8l = _emit_node(it_72_8l);
            PyList_SetItem(v_72_8, li_72_8l, e_72_8l);
            li_72_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_72_8);
    Py_DecRef(v_72_8);

    fv_72_9 = nd.scope_name;
    v_72_9 = _py_str(fv_72_9);
    PyDict_SetItem(d_h, _mat_keys[18], v_72_9);
    Py_DecRef(v_72_9);

    fv_72_10 = nd.parent_scope;
    if fv_72_10 is None {
        v_72_10 = _py_none();
    } else {
        v_72_10 = _emit_node(fv_72_10);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_72_10);
    Py_DecRef(v_72_10);

    fv_72_11 = nd.kid_scope;
    v_72_11 = PyList_New(len(fv_72_11));
    li_72_11l = 0;
    for it_72_11l in fv_72_11 {
        e_72_11l = _emit_node(it_72_11l);
        PyList_SetItem(v_72_11, li_72_11l, e_72_11l);
        li_72_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_72_11);
    Py_DecRef(v_72_11);

    fv_72_12 = nd.names_in_scope;
    v_72_12 = PyDict_New();
    for (dk_72_12d, dv_72_12d) in fv_72_12.items() {
        kh_72_12d = _py_str(dk_72_12d);
        vh_72_12d = _emit_Symbol(dv_72_12d);
        PyDict_SetItem(v_72_12, kh_72_12d, vh_72_12d);
        Py_DecRef(kh_72_12d);
        Py_DecRef(vh_72_12d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_72_12);
    Py_DecRef(v_72_12);

    fv_72_13 = nd.names_in_scope_overload;
    v_72_13 = PyDict_New();
    for (dk_72_13d, dv_72_13d) in fv_72_13.items() {
        kh_72_13d = _py_str(dk_72_13d);
        vh_72_13d = PyList_New(len(dv_72_13d));
        li_72_13dl = 0;
        for it_72_13dl in dv_72_13d {
            e_72_13dl = _emit_Symbol(it_72_13dl);
            PyList_SetItem(vh_72_13d, li_72_13dl, e_72_13dl);
            li_72_13dl += 1;
        }
        PyDict_SetItem(v_72_13, kh_72_13d, vh_72_13d);
        Py_DecRef(kh_72_13d);
        Py_DecRef(vh_72_13d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_72_13);
    Py_DecRef(v_72_13);

    fv_72_14 = nd.implicit_rebinds;
    v_72_14 = PyDict_New();
    for (dk_72_14d, dv_72_14d) in fv_72_14.items() {
        kh_72_14d = _py_str(dk_72_14d);
        vh_72_14d = _emit_Symbol(dv_72_14d);
        PyDict_SetItem(v_72_14, kh_72_14d, vh_72_14d);
        Py_DecRef(kh_72_14d);
        Py_DecRef(vh_72_14d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_72_14);
    Py_DecRef(v_72_14);

    fv_72_15 = nd.body;
    if isinstance(fv_72_15, list) {
        tl_72_15: list[CodeBlockStmt] = fv_72_15;
        v_72_15 = PyList_New(len(tl_72_15));
        li_72_15l = 0;
        for it_72_15l in tl_72_15 {
            e_72_15l = _emit_node(it_72_15l);
            PyList_SetItem(v_72_15, li_72_15l, e_72_15l);
            li_72_15l += 1;
        }
    } elif isinstance(fv_72_15, Expr) {
        v_72_15 = _emit_node(fv_72_15);
    } else {
        v_72_15 = _py_none();
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_72_15);
    Py_DecRef(v_72_15);

    fv_72_16 = nd.signature;
    if fv_72_16 is None {
        v_72_16 = _py_none();
    } else {
        v_72_16 = _emit_node(fv_72_16);
    }
    PyDict_SetItem(d_h, _mat_keys[37], v_72_16);
    Py_DecRef(v_72_16);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_MatchStmt(nd: MatchStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[73], _mat_classes[73]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_73_0 = nd.kid;
    v_73_0 = PyList_New(len(fv_73_0));
    li_73_0l = 0;
    for it_73_0l in fv_73_0 {
        e_73_0l = _emit_node(it_73_0l);
        PyList_SetItem(v_73_0, li_73_0l, e_73_0l);
        li_73_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_73_0);
    Py_DecRef(v_73_0);

    fv_73_1 = nd.parent;
    if fv_73_1 is None {
        v_73_1 = _py_none();
    } else {
        v_73_1 = _emit_node(fv_73_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_73_1);
    Py_DecRef(v_73_1);

    v_73_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_73_2);
    Py_DecRef(v_73_2);

    fv_73_3 = nd._in_mod_nodes;
    v_73_3 = PyList_New(len(fv_73_3));
    li_73_3l = 0;
    for it_73_3l in fv_73_3 {
        e_73_3l = _emit_node(it_73_3l);
        PyList_SetItem(v_73_3, li_73_3l, e_73_3l);
        li_73_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_73_3);
    Py_DecRef(v_73_3);

    v_73_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_73_4);
    Py_DecRef(v_73_4);

    fv_73_5 = nd.loc;
    v_73_5 = _emit_CodeLocInfo(fv_73_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_73_5);
    Py_DecRef(v_73_5);

    fv_73_6 = nd.bb_in;
    v_73_6 = PyList_New(len(fv_73_6));
    li_73_6l = 0;
    for it_73_6l in fv_73_6 {
        e_73_6l = _emit_node(it_73_6l);
        PyList_SetItem(v_73_6, li_73_6l, e_73_6l);
        li_73_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_73_6);
    Py_DecRef(v_73_6);

    fv_73_7 = nd.bb_out;
    v_73_7 = PyList_New(len(fv_73_7));
    li_73_7l = 0;
    for it_73_7l in fv_73_7 {
        e_73_7l = _emit_node(it_73_7l);
        PyList_SetItem(v_73_7, li_73_7l, e_73_7l);
        li_73_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_73_7);
    Py_DecRef(v_73_7);

    fv_73_8 = nd.affected_symbols;
    v_73_8 = PySet_New(0);
    if len(fv_73_8) != 0 {
        Py_DecRef(v_73_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_73_8);
    Py_DecRef(v_73_8);

    fv_73_9 = nd.target;
    v_73_9 = _emit_node(fv_73_9);
    PyDict_SetItem(d_h, _mat_keys[60], v_73_9);
    Py_DecRef(v_73_9);

    fv_73_10 = nd.cases;
    v_73_10 = PyList_New(len(fv_73_10));
    li_73_10l = 0;
    for it_73_10l in fv_73_10 {
        e_73_10l = _emit_node(it_73_10l);
        PyList_SetItem(v_73_10, li_73_10l, e_73_10l);
        li_73_10l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[129], v_73_10);
    Py_DecRef(v_73_10);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_Module(nd: Module) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[74], _mat_classes[74]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_74_0 = nd.kid;
    v_74_0 = PyList_New(len(fv_74_0));
    li_74_0l = 0;
    for it_74_0l in fv_74_0 {
        e_74_0l = _emit_node(it_74_0l);
        PyList_SetItem(v_74_0, li_74_0l, e_74_0l);
        li_74_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_74_0);
    Py_DecRef(v_74_0);

    fv_74_1 = nd.parent;
    if fv_74_1 is None {
        v_74_1 = _py_none();
    } else {
        v_74_1 = _emit_node(fv_74_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_74_1);
    Py_DecRef(v_74_1);

    v_74_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_74_2);
    Py_DecRef(v_74_2);

    fv_74_3 = nd._in_mod_nodes;
    v_74_3 = PyList_New(len(fv_74_3));
    li_74_3l = 0;
    for it_74_3l in fv_74_3 {
        e_74_3l = _emit_node(it_74_3l);
        PyList_SetItem(v_74_3, li_74_3l, e_74_3l);
        li_74_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_74_3);
    Py_DecRef(v_74_3);

    v_74_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_74_4);
    Py_DecRef(v_74_4);

    fv_74_5 = nd.loc;
    v_74_5 = _emit_CodeLocInfo(fv_74_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_74_5);
    Py_DecRef(v_74_5);

    fv_74_6 = nd.doc;
    if fv_74_6 is None {
        v_74_6 = _py_none();
    } else {
        v_74_6 = _emit_node(fv_74_6);
    }
    PyDict_SetItem(d_h, _mat_keys[8], v_74_6);
    Py_DecRef(v_74_6);

    fv_74_7 = nd.scope_name;
    v_74_7 = _py_str(fv_74_7);
    PyDict_SetItem(d_h, _mat_keys[18], v_74_7);
    Py_DecRef(v_74_7);

    fv_74_8 = nd.parent_scope;
    if fv_74_8 is None {
        v_74_8 = _py_none();
    } else {
        v_74_8 = _emit_node(fv_74_8);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_74_8);
    Py_DecRef(v_74_8);

    fv_74_9 = nd.kid_scope;
    v_74_9 = PyList_New(len(fv_74_9));
    li_74_9l = 0;
    for it_74_9l in fv_74_9 {
        e_74_9l = _emit_node(it_74_9l);
        PyList_SetItem(v_74_9, li_74_9l, e_74_9l);
        li_74_9l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_74_9);
    Py_DecRef(v_74_9);

    fv_74_10 = nd.names_in_scope;
    v_74_10 = PyDict_New();
    for (dk_74_10d, dv_74_10d) in fv_74_10.items() {
        kh_74_10d = _py_str(dk_74_10d);
        vh_74_10d = _emit_Symbol(dv_74_10d);
        PyDict_SetItem(v_74_10, kh_74_10d, vh_74_10d);
        Py_DecRef(kh_74_10d);
        Py_DecRef(vh_74_10d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_74_10);
    Py_DecRef(v_74_10);

    fv_74_11 = nd.names_in_scope_overload;
    v_74_11 = PyDict_New();
    for (dk_74_11d, dv_74_11d) in fv_74_11.items() {
        kh_74_11d = _py_str(dk_74_11d);
        vh_74_11d = PyList_New(len(dv_74_11d));
        li_74_11dl = 0;
        for it_74_11dl in dv_74_11d {
            e_74_11dl = _emit_Symbol(it_74_11dl);
            PyList_SetItem(vh_74_11d, li_74_11dl, e_74_11dl);
            li_74_11dl += 1;
        }
        PyDict_SetItem(v_74_11, kh_74_11d, vh_74_11d);
        Py_DecRef(kh_74_11d);
        Py_DecRef(vh_74_11d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_74_11);
    Py_DecRef(v_74_11);

    fv_74_12 = nd.implicit_rebinds;
    v_74_12 = PyDict_New();
    for (dk_74_12d, dv_74_12d) in fv_74_12.items() {
        kh_74_12d = _py_str(dk_74_12d);
        vh_74_12d = _emit_Symbol(dv_74_12d);
        PyDict_SetItem(v_74_12, kh_74_12d, vh_74_12d);
        Py_DecRef(kh_74_12d);
        Py_DecRef(vh_74_12d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_74_12);
    Py_DecRef(v_74_12);

    fv_74_13 = nd.name;
    v_74_13 = _py_str(fv_74_13);
    PyDict_SetItem(d_h, _mat_keys[24], v_74_13);
    Py_DecRef(v_74_13);

    fv_74_14 = nd.source;
    v_74_14 = _emit_node(fv_74_14);
    PyDict_SetItem(d_h, _mat_keys[130], v_74_14);
    Py_DecRef(v_74_14);

    fv_74_15 = nd.body;
    v_74_15 = PyList_New(len(fv_74_15));
    li_74_15l = 0;
    for it_74_15l in fv_74_15 {
        e_74_15l = _emit_node(it_74_15l);
        PyList_SetItem(v_74_15, li_74_15l, e_74_15l);
        li_74_15l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_74_15);
    Py_DecRef(v_74_15);

    fv_74_16 = nd.terminals;
    v_74_16 = PyList_New(len(fv_74_16));
    li_74_16l = 0;
    for it_74_16l in fv_74_16 {
        e_74_16l = _emit_node(it_74_16l);
        PyList_SetItem(v_74_16, li_74_16l, e_74_16l);
        li_74_16l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[131], v_74_16);
    Py_DecRef(v_74_16);

    fv_74_17 = nd.stub_only;
    v_74_17 = PyBool_FromLong(1 if fv_74_17 else 0);
    PyDict_SetItem(d_h, _mat_keys[132], v_74_17);
    Py_DecRef(v_74_17);

    fv_74_18 = nd.src_terminals;
    v_74_18 = PyList_New(len(fv_74_18));
    li_74_18l = 0;
    for it_74_18l in fv_74_18 {
        e_74_18l = _emit_node(it_74_18l);
        PyList_SetItem(v_74_18, li_74_18l, e_74_18l);
        li_74_18l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[133], v_74_18);
    Py_DecRef(v_74_18);

    fv_74_19 = nd.is_raised_from_py;
    v_74_19 = PyBool_FromLong(1 if fv_74_19 else 0);
    PyDict_SetItem(d_h, _mat_keys[134], v_74_19);
    Py_DecRef(v_74_19);

    fv_74_20 = nd.decided_codespace;
    v_74_20 = _py_str(fv_74_20);
    PyDict_SetItem(d_h, _mat_keys[135], v_74_20);
    Py_DecRef(v_74_20);

    fv_74_21 = nd.parse_failed;
    v_74_21 = PyBool_FromLong(1 if fv_74_21 else 0);
    PyDict_SetItem(d_h, _mat_keys[136], v_74_21);
    Py_DecRef(v_74_21);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ParamVar(nd: ParamVar) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[75], _mat_classes[75]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_75_0 = nd.kid;
    v_75_0 = PyList_New(len(fv_75_0));
    li_75_0l = 0;
    for it_75_0l in fv_75_0 {
        e_75_0l = _emit_node(it_75_0l);
        PyList_SetItem(v_75_0, li_75_0l, e_75_0l);
        li_75_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_75_0);
    Py_DecRef(v_75_0);

    fv_75_1 = nd.parent;
    if fv_75_1 is None {
        v_75_1 = _py_none();
    } else {
        v_75_1 = _emit_node(fv_75_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_75_1);
    Py_DecRef(v_75_1);

    v_75_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_75_2);
    Py_DecRef(v_75_2);

    fv_75_3 = nd._in_mod_nodes;
    v_75_3 = PyList_New(len(fv_75_3));
    li_75_3l = 0;
    for it_75_3l in fv_75_3 {
        e_75_3l = _emit_node(it_75_3l);
        PyList_SetItem(v_75_3, li_75_3l, e_75_3l);
        li_75_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_75_3);
    Py_DecRef(v_75_3);

    v_75_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_75_4);
    Py_DecRef(v_75_4);

    fv_75_5 = nd.loc;
    v_75_5 = _emit_CodeLocInfo(fv_75_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_75_5);
    Py_DecRef(v_75_5);

    fv_75_6 = nd.name_spec;
    v_75_6 = _emit_node(fv_75_6);
    PyDict_SetItem(d_h, _mat_keys[12], v_75_6);
    Py_DecRef(v_75_6);

    fv_75_7 = nd.semstr;
    v_75_7 = _py_str(fv_75_7);
    PyDict_SetItem(d_h, _mat_keys[13], v_75_7);
    Py_DecRef(v_75_7);

    fv_75_8 = nd.type_tag;
    if fv_75_8 is None {
        v_75_8 = _py_none();
    } else {
        v_75_8 = _emit_node(fv_75_8);
    }
    PyDict_SetItem(d_h, _mat_keys[89], v_75_8);
    Py_DecRef(v_75_8);

    fv_75_9 = nd.name;
    if isinstance(fv_75_9, Name) {
        v_75_9 = _emit_node(fv_75_9);
    } elif isinstance(fv_75_9, CtName) {
        v_75_9 = _emit_node(fv_75_9);
    } else {
        v_75_9 = _py_none();
    }
    PyDict_SetItem(d_h, _mat_keys[24], v_75_9);
    Py_DecRef(v_75_9);

    fv_75_10 = nd.unpack;
    if fv_75_10 is None {
        v_75_10 = _py_none();
    } else {
        v_75_10 = _emit_node(fv_75_10);
    }
    PyDict_SetItem(d_h, _mat_keys[137], v_75_10);
    Py_DecRef(v_75_10);

    fv_75_11 = nd.value;
    if fv_75_11 is None {
        v_75_11 = _py_none();
    } else {
        v_75_11 = _emit_node(fv_75_11);
    }
    PyDict_SetItem(d_h, _mat_keys[42], v_75_11);
    Py_DecRef(v_75_11);

    fv_75_12 = nd.param_kind;
    v_75_12 = _enum_ParamKind(fv_75_12);
    PyDict_SetItem(d_h, _mat_keys[138], v_75_12);
    Py_DecRef(v_75_12);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_PythonModuleAst(nd: PythonModuleAst) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[76], _mat_classes[76]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_76_0 = nd.kid;
    v_76_0 = PyList_New(len(fv_76_0));
    li_76_0l = 0;
    for it_76_0l in fv_76_0 {
        e_76_0l = _emit_node(it_76_0l);
        PyList_SetItem(v_76_0, li_76_0l, e_76_0l);
        li_76_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_76_0);
    Py_DecRef(v_76_0);

    fv_76_1 = nd.parent;
    if fv_76_1 is None {
        v_76_1 = _py_none();
    } else {
        v_76_1 = _emit_node(fv_76_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_76_1);
    Py_DecRef(v_76_1);

    v_76_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_76_2);
    Py_DecRef(v_76_2);

    fv_76_3 = nd._in_mod_nodes;
    v_76_3 = PyList_New(len(fv_76_3));
    li_76_3l = 0;
    for it_76_3l in fv_76_3 {
        e_76_3l = _emit_node(it_76_3l);
        PyList_SetItem(v_76_3, li_76_3l, e_76_3l);
        li_76_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_76_3);
    Py_DecRef(v_76_3);

    v_76_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_76_4);
    Py_DecRef(v_76_4);

    fv_76_5 = nd.loc;
    v_76_5 = _emit_CodeLocInfo(fv_76_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_76_5);
    Py_DecRef(v_76_5);

    fv_76_6 = nd.orig_src;
    v_76_6 = _emit_node(fv_76_6);
    PyDict_SetItem(d_h, _mat_keys[41], v_76_6);
    Py_DecRef(v_76_6);

    fv_76_7 = nd.name;
    v_76_7 = _py_str(fv_76_7);
    PyDict_SetItem(d_h, _mat_keys[24], v_76_7);
    Py_DecRef(v_76_7);

    fv_76_8 = nd.value;
    v_76_8 = _py_str(fv_76_8);
    PyDict_SetItem(d_h, _mat_keys[42], v_76_8);
    Py_DecRef(v_76_8);

    fv_76_9 = nd.line_no;
    v_76_9 = PyLong_FromLongLong(fv_76_9);
    PyDict_SetItem(d_h, _mat_keys[43], v_76_9);
    Py_DecRef(v_76_9);

    fv_76_10 = nd.end_line;
    v_76_10 = PyLong_FromLongLong(fv_76_10);
    PyDict_SetItem(d_h, _mat_keys[44], v_76_10);
    Py_DecRef(v_76_10);

    fv_76_11 = nd.c_start;
    v_76_11 = PyLong_FromLongLong(fv_76_11);
    PyDict_SetItem(d_h, _mat_keys[45], v_76_11);
    Py_DecRef(v_76_11);

    fv_76_12 = nd.c_end;
    v_76_12 = PyLong_FromLongLong(fv_76_12);
    PyDict_SetItem(d_h, _mat_keys[46], v_76_12);
    Py_DecRef(v_76_12);

    fv_76_13 = nd.pos_start;
    v_76_13 = PyLong_FromLongLong(fv_76_13);
    PyDict_SetItem(d_h, _mat_keys[47], v_76_13);
    Py_DecRef(v_76_13);

    fv_76_14 = nd.pos_end;
    v_76_14 = PyLong_FromLongLong(fv_76_14);
    PyDict_SetItem(d_h, _mat_keys[48], v_76_14);
    Py_DecRef(v_76_14);

    fv_76_15 = nd._is_synthetic;
    v_76_15 = PyBool_FromLong(1 if fv_76_15 else 0);
    PyDict_SetItem(d_h, _mat_keys[49], v_76_15);
    Py_DecRef(v_76_15);

    fv_76_16 = nd.ast;
    v_76_16 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[139], v_76_16);
    Py_DecRef(v_76_16);

    fv_76_17 = nd.file_path;
    v_76_17 = _py_str(fv_76_17);
    PyDict_SetItem(d_h, _mat_keys[140], v_76_17);
    Py_DecRef(v_76_17);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_RaiseStmt(nd: RaiseStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[77], _mat_classes[77]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_77_0 = nd.kid;
    v_77_0 = PyList_New(len(fv_77_0));
    li_77_0l = 0;
    for it_77_0l in fv_77_0 {
        e_77_0l = _emit_node(it_77_0l);
        PyList_SetItem(v_77_0, li_77_0l, e_77_0l);
        li_77_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_77_0);
    Py_DecRef(v_77_0);

    fv_77_1 = nd.parent;
    if fv_77_1 is None {
        v_77_1 = _py_none();
    } else {
        v_77_1 = _emit_node(fv_77_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_77_1);
    Py_DecRef(v_77_1);

    v_77_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_77_2);
    Py_DecRef(v_77_2);

    fv_77_3 = nd._in_mod_nodes;
    v_77_3 = PyList_New(len(fv_77_3));
    li_77_3l = 0;
    for it_77_3l in fv_77_3 {
        e_77_3l = _emit_node(it_77_3l);
        PyList_SetItem(v_77_3, li_77_3l, e_77_3l);
        li_77_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_77_3);
    Py_DecRef(v_77_3);

    v_77_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_77_4);
    Py_DecRef(v_77_4);

    fv_77_5 = nd.loc;
    v_77_5 = _emit_CodeLocInfo(fv_77_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_77_5);
    Py_DecRef(v_77_5);

    fv_77_6 = nd.bb_in;
    v_77_6 = PyList_New(len(fv_77_6));
    li_77_6l = 0;
    for it_77_6l in fv_77_6 {
        e_77_6l = _emit_node(it_77_6l);
        PyList_SetItem(v_77_6, li_77_6l, e_77_6l);
        li_77_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_77_6);
    Py_DecRef(v_77_6);

    fv_77_7 = nd.bb_out;
    v_77_7 = PyList_New(len(fv_77_7));
    li_77_7l = 0;
    for it_77_7l in fv_77_7 {
        e_77_7l = _emit_node(it_77_7l);
        PyList_SetItem(v_77_7, li_77_7l, e_77_7l);
        li_77_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_77_7);
    Py_DecRef(v_77_7);

    fv_77_8 = nd.affected_symbols;
    v_77_8 = PySet_New(0);
    if len(fv_77_8) != 0 {
        Py_DecRef(v_77_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_77_8);
    Py_DecRef(v_77_8);

    fv_77_9 = nd.cause;
    if fv_77_9 is None {
        v_77_9 = _py_none();
    } else {
        v_77_9 = _emit_node(fv_77_9);
    }
    PyDict_SetItem(d_h, _mat_keys[141], v_77_9);
    Py_DecRef(v_77_9);

    fv_77_10 = nd.from_target;
    if fv_77_10 is None {
        v_77_10 = _py_none();
    } else {
        v_77_10 = _emit_node(fv_77_10);
    }
    PyDict_SetItem(d_h, _mat_keys[142], v_77_10);
    Py_DecRef(v_77_10);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ReportStmt(nd: ReportStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[78], _mat_classes[78]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_78_0 = nd.kid;
    v_78_0 = PyList_New(len(fv_78_0));
    li_78_0l = 0;
    for it_78_0l in fv_78_0 {
        e_78_0l = _emit_node(it_78_0l);
        PyList_SetItem(v_78_0, li_78_0l, e_78_0l);
        li_78_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_78_0);
    Py_DecRef(v_78_0);

    fv_78_1 = nd.parent;
    if fv_78_1 is None {
        v_78_1 = _py_none();
    } else {
        v_78_1 = _emit_node(fv_78_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_78_1);
    Py_DecRef(v_78_1);

    v_78_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_78_2);
    Py_DecRef(v_78_2);

    fv_78_3 = nd._in_mod_nodes;
    v_78_3 = PyList_New(len(fv_78_3));
    li_78_3l = 0;
    for it_78_3l in fv_78_3 {
        e_78_3l = _emit_node(it_78_3l);
        PyList_SetItem(v_78_3, li_78_3l, e_78_3l);
        li_78_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_78_3);
    Py_DecRef(v_78_3);

    v_78_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_78_4);
    Py_DecRef(v_78_4);

    fv_78_5 = nd.loc;
    v_78_5 = _emit_CodeLocInfo(fv_78_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_78_5);
    Py_DecRef(v_78_5);

    fv_78_6 = nd.bb_in;
    v_78_6 = PyList_New(len(fv_78_6));
    li_78_6l = 0;
    for it_78_6l in fv_78_6 {
        e_78_6l = _emit_node(it_78_6l);
        PyList_SetItem(v_78_6, li_78_6l, e_78_6l);
        li_78_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_78_6);
    Py_DecRef(v_78_6);

    fv_78_7 = nd.bb_out;
    v_78_7 = PyList_New(len(fv_78_7));
    li_78_7l = 0;
    for it_78_7l in fv_78_7 {
        e_78_7l = _emit_node(it_78_7l);
        PyList_SetItem(v_78_7, li_78_7l, e_78_7l);
        li_78_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_78_7);
    Py_DecRef(v_78_7);

    fv_78_8 = nd.affected_symbols;
    v_78_8 = PySet_New(0);
    if len(fv_78_8) != 0 {
        Py_DecRef(v_78_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_78_8);
    Py_DecRef(v_78_8);

    fv_78_9 = nd.expr;
    v_78_9 = _emit_node(fv_78_9);
    PyDict_SetItem(d_h, _mat_keys[118], v_78_9);
    Py_DecRef(v_78_9);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ReturnStmt(nd: ReturnStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[79], _mat_classes[79]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_79_0 = nd.kid;
    v_79_0 = PyList_New(len(fv_79_0));
    li_79_0l = 0;
    for it_79_0l in fv_79_0 {
        e_79_0l = _emit_node(it_79_0l);
        PyList_SetItem(v_79_0, li_79_0l, e_79_0l);
        li_79_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_79_0);
    Py_DecRef(v_79_0);

    fv_79_1 = nd.parent;
    if fv_79_1 is None {
        v_79_1 = _py_none();
    } else {
        v_79_1 = _emit_node(fv_79_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_79_1);
    Py_DecRef(v_79_1);

    v_79_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_79_2);
    Py_DecRef(v_79_2);

    fv_79_3 = nd._in_mod_nodes;
    v_79_3 = PyList_New(len(fv_79_3));
    li_79_3l = 0;
    for it_79_3l in fv_79_3 {
        e_79_3l = _emit_node(it_79_3l);
        PyList_SetItem(v_79_3, li_79_3l, e_79_3l);
        li_79_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_79_3);
    Py_DecRef(v_79_3);

    v_79_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_79_4);
    Py_DecRef(v_79_4);

    fv_79_5 = nd.loc;
    v_79_5 = _emit_CodeLocInfo(fv_79_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_79_5);
    Py_DecRef(v_79_5);

    fv_79_6 = nd.bb_in;
    v_79_6 = PyList_New(len(fv_79_6));
    li_79_6l = 0;
    for it_79_6l in fv_79_6 {
        e_79_6l = _emit_node(it_79_6l);
        PyList_SetItem(v_79_6, li_79_6l, e_79_6l);
        li_79_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_79_6);
    Py_DecRef(v_79_6);

    fv_79_7 = nd.bb_out;
    v_79_7 = PyList_New(len(fv_79_7));
    li_79_7l = 0;
    for it_79_7l in fv_79_7 {
        e_79_7l = _emit_node(it_79_7l);
        PyList_SetItem(v_79_7, li_79_7l, e_79_7l);
        li_79_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_79_7);
    Py_DecRef(v_79_7);

    fv_79_8 = nd.affected_symbols;
    v_79_8 = PySet_New(0);
    if len(fv_79_8) != 0 {
        Py_DecRef(v_79_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_79_8);
    Py_DecRef(v_79_8);

    fv_79_9 = nd.expr;
    if fv_79_9 is None {
        v_79_9 = _py_none();
    } else {
        v_79_9 = _emit_node(fv_79_9);
    }
    PyDict_SetItem(d_h, _mat_keys[118], v_79_9);
    Py_DecRef(v_79_9);

    fv_79_10 = nd.is_implicit;
    v_79_10 = PyBool_FromLong(1 if fv_79_10 else 0);
    PyDict_SetItem(d_h, _mat_keys[143], v_79_10);
    Py_DecRef(v_79_10);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_Source(nd: Source) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[80], _mat_classes[80]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_80_0 = nd.kid;
    v_80_0 = PyList_New(len(fv_80_0));
    li_80_0l = 0;
    for it_80_0l in fv_80_0 {
        e_80_0l = _emit_node(it_80_0l);
        PyList_SetItem(v_80_0, li_80_0l, e_80_0l);
        li_80_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_80_0);
    Py_DecRef(v_80_0);

    fv_80_1 = nd.parent;
    if fv_80_1 is None {
        v_80_1 = _py_none();
    } else {
        v_80_1 = _emit_node(fv_80_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_80_1);
    Py_DecRef(v_80_1);

    v_80_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_80_2);
    Py_DecRef(v_80_2);

    fv_80_3 = nd._in_mod_nodes;
    v_80_3 = PyList_New(len(fv_80_3));
    li_80_3l = 0;
    for it_80_3l in fv_80_3 {
        e_80_3l = _emit_node(it_80_3l);
        PyList_SetItem(v_80_3, li_80_3l, e_80_3l);
        li_80_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_80_3);
    Py_DecRef(v_80_3);

    v_80_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_80_4);
    Py_DecRef(v_80_4);

    fv_80_5 = nd.loc;
    v_80_5 = _emit_CodeLocInfo(fv_80_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_80_5);
    Py_DecRef(v_80_5);

    fv_80_6 = nd.orig_src;
    v_80_6 = _emit_node(fv_80_6);
    PyDict_SetItem(d_h, _mat_keys[41], v_80_6);
    Py_DecRef(v_80_6);

    fv_80_7 = nd.name;
    v_80_7 = _py_str(fv_80_7);
    PyDict_SetItem(d_h, _mat_keys[24], v_80_7);
    Py_DecRef(v_80_7);

    fv_80_8 = nd.value;
    v_80_8 = _py_str(fv_80_8);
    PyDict_SetItem(d_h, _mat_keys[42], v_80_8);
    Py_DecRef(v_80_8);

    fv_80_9 = nd.line_no;
    v_80_9 = PyLong_FromLongLong(fv_80_9);
    PyDict_SetItem(d_h, _mat_keys[43], v_80_9);
    Py_DecRef(v_80_9);

    fv_80_10 = nd.end_line;
    v_80_10 = PyLong_FromLongLong(fv_80_10);
    PyDict_SetItem(d_h, _mat_keys[44], v_80_10);
    Py_DecRef(v_80_10);

    fv_80_11 = nd.c_start;
    v_80_11 = PyLong_FromLongLong(fv_80_11);
    PyDict_SetItem(d_h, _mat_keys[45], v_80_11);
    Py_DecRef(v_80_11);

    fv_80_12 = nd.c_end;
    v_80_12 = PyLong_FromLongLong(fv_80_12);
    PyDict_SetItem(d_h, _mat_keys[46], v_80_12);
    Py_DecRef(v_80_12);

    fv_80_13 = nd.pos_start;
    v_80_13 = PyLong_FromLongLong(fv_80_13);
    PyDict_SetItem(d_h, _mat_keys[47], v_80_13);
    Py_DecRef(v_80_13);

    fv_80_14 = nd.pos_end;
    v_80_14 = PyLong_FromLongLong(fv_80_14);
    PyDict_SetItem(d_h, _mat_keys[48], v_80_14);
    Py_DecRef(v_80_14);

    fv_80_15 = nd._is_synthetic;
    v_80_15 = PyBool_FromLong(1 if fv_80_15 else 0);
    PyDict_SetItem(d_h, _mat_keys[49], v_80_15);
    Py_DecRef(v_80_15);

    fv_80_16 = nd.comments;
    v_80_16 = PyList_New(len(fv_80_16));
    li_80_16l = 0;
    for it_80_16l in fv_80_16 {
        e_80_16l = _emit_node(it_80_16l);
        PyList_SetItem(v_80_16, li_80_16l, e_80_16l);
        li_80_16l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[144], v_80_16);
    Py_DecRef(v_80_16);

    fv_80_17 = nd.inline_suppressions;
    v_80_17 = PyDict_New();
    for (dk_80_17d, dv_80_17d) in fv_80_17.items() {
        kh_80_17d = PyLong_FromLongLong(dk_80_17d);
        vh_80_17d = PySet_New(0);
        if len(dv_80_17d) != 0 {
            Py_DecRef(vh_80_17d);
            return 0;
        }
        PyDict_SetItem(v_80_17, kh_80_17d, vh_80_17d);
        Py_DecRef(kh_80_17d);
        Py_DecRef(vh_80_17d);
    }
    PyDict_SetItem(d_h, _mat_keys[145], v_80_17);
    Py_DecRef(v_80_17);

    fv_80_18 = nd.file_path;
    v_80_18 = _py_str(fv_80_18);
    PyDict_SetItem(d_h, _mat_keys[140], v_80_18);
    Py_DecRef(v_80_18);

    fv_80_19 = nd._hash;
    v_80_19 = _py_str(fv_80_19);
    PyDict_SetItem(d_h, _mat_keys[146], v_80_19);
    Py_DecRef(v_80_19);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_SwitchStmt(nd: SwitchStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[81], _mat_classes[81]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_81_0 = nd.kid;
    v_81_0 = PyList_New(len(fv_81_0));
    li_81_0l = 0;
    for it_81_0l in fv_81_0 {
        e_81_0l = _emit_node(it_81_0l);
        PyList_SetItem(v_81_0, li_81_0l, e_81_0l);
        li_81_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_81_0);
    Py_DecRef(v_81_0);

    fv_81_1 = nd.parent;
    if fv_81_1 is None {
        v_81_1 = _py_none();
    } else {
        v_81_1 = _emit_node(fv_81_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_81_1);
    Py_DecRef(v_81_1);

    v_81_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_81_2);
    Py_DecRef(v_81_2);

    fv_81_3 = nd._in_mod_nodes;
    v_81_3 = PyList_New(len(fv_81_3));
    li_81_3l = 0;
    for it_81_3l in fv_81_3 {
        e_81_3l = _emit_node(it_81_3l);
        PyList_SetItem(v_81_3, li_81_3l, e_81_3l);
        li_81_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_81_3);
    Py_DecRef(v_81_3);

    v_81_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_81_4);
    Py_DecRef(v_81_4);

    fv_81_5 = nd.loc;
    v_81_5 = _emit_CodeLocInfo(fv_81_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_81_5);
    Py_DecRef(v_81_5);

    fv_81_6 = nd.bb_in;
    v_81_6 = PyList_New(len(fv_81_6));
    li_81_6l = 0;
    for it_81_6l in fv_81_6 {
        e_81_6l = _emit_node(it_81_6l);
        PyList_SetItem(v_81_6, li_81_6l, e_81_6l);
        li_81_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_81_6);
    Py_DecRef(v_81_6);

    fv_81_7 = nd.bb_out;
    v_81_7 = PyList_New(len(fv_81_7));
    li_81_7l = 0;
    for it_81_7l in fv_81_7 {
        e_81_7l = _emit_node(it_81_7l);
        PyList_SetItem(v_81_7, li_81_7l, e_81_7l);
        li_81_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_81_7);
    Py_DecRef(v_81_7);

    fv_81_8 = nd.affected_symbols;
    v_81_8 = PySet_New(0);
    if len(fv_81_8) != 0 {
        Py_DecRef(v_81_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_81_8);
    Py_DecRef(v_81_8);

    fv_81_9 = nd.target;
    v_81_9 = _emit_node(fv_81_9);
    PyDict_SetItem(d_h, _mat_keys[60], v_81_9);
    Py_DecRef(v_81_9);

    fv_81_10 = nd.cases;
    v_81_10 = PyList_New(len(fv_81_10));
    li_81_10l = 0;
    for it_81_10l in fv_81_10 {
        e_81_10l = _emit_node(it_81_10l);
        PyList_SetItem(v_81_10, li_81_10l, e_81_10l);
        li_81_10l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[129], v_81_10);
    Py_DecRef(v_81_10);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_AstSymbolStubNode(nd: AstSymbolStubNode) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[82], _mat_classes[82]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_82_0 = nd.kid;
    v_82_0 = PyList_New(len(fv_82_0));
    li_82_0l = 0;
    for it_82_0l in fv_82_0 {
        e_82_0l = _emit_node(it_82_0l);
        PyList_SetItem(v_82_0, li_82_0l, e_82_0l);
        li_82_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_82_0);
    Py_DecRef(v_82_0);

    fv_82_1 = nd.parent;
    if fv_82_1 is None {
        v_82_1 = _py_none();
    } else {
        v_82_1 = _emit_node(fv_82_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_82_1);
    Py_DecRef(v_82_1);

    v_82_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_82_2);
    Py_DecRef(v_82_2);

    fv_82_3 = nd._in_mod_nodes;
    v_82_3 = PyList_New(len(fv_82_3));
    li_82_3l = 0;
    for it_82_3l in fv_82_3 {
        e_82_3l = _emit_node(it_82_3l);
        PyList_SetItem(v_82_3, li_82_3l, e_82_3l);
        li_82_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_82_3);
    Py_DecRef(v_82_3);

    v_82_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_82_4);
    Py_DecRef(v_82_4);

    fv_82_5 = nd.loc;
    v_82_5 = _emit_CodeLocInfo(fv_82_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_82_5);
    Py_DecRef(v_82_5);

    fv_82_6 = nd.name_spec;
    v_82_6 = _emit_node(fv_82_6);
    PyDict_SetItem(d_h, _mat_keys[12], v_82_6);
    Py_DecRef(v_82_6);

    fv_82_7 = nd.semstr;
    v_82_7 = _py_str(fv_82_7);
    PyDict_SetItem(d_h, _mat_keys[13], v_82_7);
    Py_DecRef(v_82_7);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_AtomTrailer(nd: AtomTrailer) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[83], _mat_classes[83]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_83_0 = nd.kid;
    v_83_0 = PyList_New(len(fv_83_0));
    li_83_0l = 0;
    for it_83_0l in fv_83_0 {
        e_83_0l = _emit_node(it_83_0l);
        PyList_SetItem(v_83_0, li_83_0l, e_83_0l);
        li_83_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_83_0);
    Py_DecRef(v_83_0);

    fv_83_1 = nd.parent;
    if fv_83_1 is None {
        v_83_1 = _py_none();
    } else {
        v_83_1 = _emit_node(fv_83_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_83_1);
    Py_DecRef(v_83_1);

    v_83_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_83_2);
    Py_DecRef(v_83_2);

    fv_83_3 = nd._in_mod_nodes;
    v_83_3 = PyList_New(len(fv_83_3));
    li_83_3l = 0;
    for it_83_3l in fv_83_3 {
        e_83_3l = _emit_node(it_83_3l);
        PyList_SetItem(v_83_3, li_83_3l, e_83_3l);
        li_83_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_83_3);
    Py_DecRef(v_83_3);

    v_83_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_83_4);
    Py_DecRef(v_83_4);

    fv_83_5 = nd.loc;
    v_83_5 = _emit_CodeLocInfo(fv_83_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_83_5);
    Py_DecRef(v_83_5);

    fv_83_6 = nd._type_sym_tab;
    if fv_83_6 is None {
        v_83_6 = _py_none();
    } else {
        v_83_6 = _emit_node(fv_83_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_83_6);
    Py_DecRef(v_83_6);

    v_83_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_83_7);
    Py_DecRef(v_83_7);

    fv_83_8 = nd.attached_tokens;
    if fv_83_8 is None {
        v_83_8 = _py_none();
    } else {
        v_83_8 = PyList_New(len(fv_83_8));
        li_83_8l = 0;
        for it_83_8l in fv_83_8 {
            e_83_8l = _emit_node(it_83_8l);
            PyList_SetItem(v_83_8, li_83_8l, e_83_8l);
            li_83_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_83_8);
    Py_DecRef(v_83_8);

    fv_83_9 = nd.target;
    v_83_9 = _emit_node(fv_83_9);
    PyDict_SetItem(d_h, _mat_keys[60], v_83_9);
    Py_DecRef(v_83_9);

    fv_83_10 = nd.right;
    if isinstance(fv_83_10, AtomExpr) {
        v_83_10 = _emit_node(fv_83_10);
    } elif isinstance(fv_83_10, Expr) {
        v_83_10 = _emit_node(fv_83_10);
    } else {
        v_83_10 = _py_none();
    }
    PyDict_SetItem(d_h, _mat_keys[147], v_83_10);
    Py_DecRef(v_83_10);

    fv_83_11 = nd.is_attr;
    v_83_11 = PyBool_FromLong(1 if fv_83_11 else 0);
    PyDict_SetItem(d_h, _mat_keys[148], v_83_11);
    Py_DecRef(v_83_11);

    fv_83_12 = nd.is_null_ok;
    v_83_12 = PyBool_FromLong(1 if fv_83_12 else 0);
    PyDict_SetItem(d_h, _mat_keys[149], v_83_12);
    Py_DecRef(v_83_12);

    fv_83_13 = nd.is_genai;
    v_83_13 = PyBool_FromLong(1 if fv_83_13 else 0);
    PyDict_SetItem(d_h, _mat_keys[150], v_83_13);
    Py_DecRef(v_83_13);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_AtomUnit(nd: AtomUnit) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[84], _mat_classes[84]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_84_0 = nd.kid;
    v_84_0 = PyList_New(len(fv_84_0));
    li_84_0l = 0;
    for it_84_0l in fv_84_0 {
        e_84_0l = _emit_node(it_84_0l);
        PyList_SetItem(v_84_0, li_84_0l, e_84_0l);
        li_84_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_84_0);
    Py_DecRef(v_84_0);

    fv_84_1 = nd.parent;
    if fv_84_1 is None {
        v_84_1 = _py_none();
    } else {
        v_84_1 = _emit_node(fv_84_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_84_1);
    Py_DecRef(v_84_1);

    v_84_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_84_2);
    Py_DecRef(v_84_2);

    fv_84_3 = nd._in_mod_nodes;
    v_84_3 = PyList_New(len(fv_84_3));
    li_84_3l = 0;
    for it_84_3l in fv_84_3 {
        e_84_3l = _emit_node(it_84_3l);
        PyList_SetItem(v_84_3, li_84_3l, e_84_3l);
        li_84_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_84_3);
    Py_DecRef(v_84_3);

    v_84_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_84_4);
    Py_DecRef(v_84_4);

    fv_84_5 = nd.loc;
    v_84_5 = _emit_CodeLocInfo(fv_84_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_84_5);
    Py_DecRef(v_84_5);

    fv_84_6 = nd._type_sym_tab;
    if fv_84_6 is None {
        v_84_6 = _py_none();
    } else {
        v_84_6 = _emit_node(fv_84_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_84_6);
    Py_DecRef(v_84_6);

    v_84_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_84_7);
    Py_DecRef(v_84_7);

    fv_84_8 = nd.attached_tokens;
    if fv_84_8 is None {
        v_84_8 = _py_none();
    } else {
        v_84_8 = PyList_New(len(fv_84_8));
        li_84_8l = 0;
        for it_84_8l in fv_84_8 {
            e_84_8l = _emit_node(it_84_8l);
            PyList_SetItem(v_84_8, li_84_8l, e_84_8l);
            li_84_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_84_8);
    Py_DecRef(v_84_8);

    fv_84_9 = nd.value;
    if isinstance(fv_84_9, Expr) {
        v_84_9 = _emit_node(fv_84_9);
    } elif isinstance(fv_84_9, YieldExpr) {
        v_84_9 = _emit_node(fv_84_9);
    } elif isinstance(fv_84_9, Ability) {
        v_84_9 = _emit_node(fv_84_9);
    } else {
        v_84_9 = _py_none();
    }
    PyDict_SetItem(d_h, _mat_keys[42], v_84_9);
    Py_DecRef(v_84_9);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_AwaitExpr(nd: AwaitExpr) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[85], _mat_classes[85]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_85_0 = nd.kid;
    v_85_0 = PyList_New(len(fv_85_0));
    li_85_0l = 0;
    for it_85_0l in fv_85_0 {
        e_85_0l = _emit_node(it_85_0l);
        PyList_SetItem(v_85_0, li_85_0l, e_85_0l);
        li_85_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_85_0);
    Py_DecRef(v_85_0);

    fv_85_1 = nd.parent;
    if fv_85_1 is None {
        v_85_1 = _py_none();
    } else {
        v_85_1 = _emit_node(fv_85_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_85_1);
    Py_DecRef(v_85_1);

    v_85_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_85_2);
    Py_DecRef(v_85_2);

    fv_85_3 = nd._in_mod_nodes;
    v_85_3 = PyList_New(len(fv_85_3));
    li_85_3l = 0;
    for it_85_3l in fv_85_3 {
        e_85_3l = _emit_node(it_85_3l);
        PyList_SetItem(v_85_3, li_85_3l, e_85_3l);
        li_85_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_85_3);
    Py_DecRef(v_85_3);

    v_85_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_85_4);
    Py_DecRef(v_85_4);

    fv_85_5 = nd.loc;
    v_85_5 = _emit_CodeLocInfo(fv_85_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_85_5);
    Py_DecRef(v_85_5);

    fv_85_6 = nd._type_sym_tab;
    if fv_85_6 is None {
        v_85_6 = _py_none();
    } else {
        v_85_6 = _emit_node(fv_85_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_85_6);
    Py_DecRef(v_85_6);

    v_85_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_85_7);
    Py_DecRef(v_85_7);

    fv_85_8 = nd.attached_tokens;
    if fv_85_8 is None {
        v_85_8 = _py_none();
    } else {
        v_85_8 = PyList_New(len(fv_85_8));
        li_85_8l = 0;
        for it_85_8l in fv_85_8 {
            e_85_8l = _emit_node(it_85_8l);
            PyList_SetItem(v_85_8, li_85_8l, e_85_8l);
            li_85_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_85_8);
    Py_DecRef(v_85_8);

    fv_85_9 = nd.target;
    v_85_9 = _emit_node(fv_85_9);
    PyDict_SetItem(d_h, _mat_keys[60], v_85_9);
    Py_DecRef(v_85_9);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_BinaryExpr(nd: BinaryExpr) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[86], _mat_classes[86]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_86_0 = nd.kid;
    v_86_0 = PyList_New(len(fv_86_0));
    li_86_0l = 0;
    for it_86_0l in fv_86_0 {
        e_86_0l = _emit_node(it_86_0l);
        PyList_SetItem(v_86_0, li_86_0l, e_86_0l);
        li_86_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_86_0);
    Py_DecRef(v_86_0);

    fv_86_1 = nd.parent;
    if fv_86_1 is None {
        v_86_1 = _py_none();
    } else {
        v_86_1 = _emit_node(fv_86_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_86_1);
    Py_DecRef(v_86_1);

    v_86_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_86_2);
    Py_DecRef(v_86_2);

    fv_86_3 = nd._in_mod_nodes;
    v_86_3 = PyList_New(len(fv_86_3));
    li_86_3l = 0;
    for it_86_3l in fv_86_3 {
        e_86_3l = _emit_node(it_86_3l);
        PyList_SetItem(v_86_3, li_86_3l, e_86_3l);
        li_86_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_86_3);
    Py_DecRef(v_86_3);

    v_86_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_86_4);
    Py_DecRef(v_86_4);

    fv_86_5 = nd.loc;
    v_86_5 = _emit_CodeLocInfo(fv_86_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_86_5);
    Py_DecRef(v_86_5);

    fv_86_6 = nd._type_sym_tab;
    if fv_86_6 is None {
        v_86_6 = _py_none();
    } else {
        v_86_6 = _emit_node(fv_86_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_86_6);
    Py_DecRef(v_86_6);

    v_86_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_86_7);
    Py_DecRef(v_86_7);

    fv_86_8 = nd.attached_tokens;
    if fv_86_8 is None {
        v_86_8 = _py_none();
    } else {
        v_86_8 = PyList_New(len(fv_86_8));
        li_86_8l = 0;
        for it_86_8l in fv_86_8 {
            e_86_8l = _emit_node(it_86_8l);
            PyList_SetItem(v_86_8, li_86_8l, e_86_8l);
            li_86_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_86_8);
    Py_DecRef(v_86_8);

    fv_86_9 = nd.left;
    v_86_9 = _emit_node(fv_86_9);
    PyDict_SetItem(d_h, _mat_keys[151], v_86_9);
    Py_DecRef(v_86_9);

    fv_86_10 = nd.right;
    v_86_10 = _emit_node(fv_86_10);
    PyDict_SetItem(d_h, _mat_keys[147], v_86_10);
    Py_DecRef(v_86_10);

    fv_86_11 = nd.op;
    if isinstance(fv_86_11, Token) {
        v_86_11 = _emit_node(fv_86_11);
    } elif isinstance(fv_86_11, DisconnectOp) {
        v_86_11 = _emit_node(fv_86_11);
    } elif isinstance(fv_86_11, ConnectOp) {
        v_86_11 = _emit_node(fv_86_11);
    } else {
        v_86_11 = _py_none();
    }
    PyDict_SetItem(d_h, _mat_keys[152], v_86_11);
    Py_DecRef(v_86_11);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_BoolExpr(nd: BoolExpr) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[87], _mat_classes[87]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_87_0 = nd.kid;
    v_87_0 = PyList_New(len(fv_87_0));
    li_87_0l = 0;
    for it_87_0l in fv_87_0 {
        e_87_0l = _emit_node(it_87_0l);
        PyList_SetItem(v_87_0, li_87_0l, e_87_0l);
        li_87_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_87_0);
    Py_DecRef(v_87_0);

    fv_87_1 = nd.parent;
    if fv_87_1 is None {
        v_87_1 = _py_none();
    } else {
        v_87_1 = _emit_node(fv_87_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_87_1);
    Py_DecRef(v_87_1);

    v_87_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_87_2);
    Py_DecRef(v_87_2);

    fv_87_3 = nd._in_mod_nodes;
    v_87_3 = PyList_New(len(fv_87_3));
    li_87_3l = 0;
    for it_87_3l in fv_87_3 {
        e_87_3l = _emit_node(it_87_3l);
        PyList_SetItem(v_87_3, li_87_3l, e_87_3l);
        li_87_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_87_3);
    Py_DecRef(v_87_3);

    v_87_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_87_4);
    Py_DecRef(v_87_4);

    fv_87_5 = nd.loc;
    v_87_5 = _emit_CodeLocInfo(fv_87_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_87_5);
    Py_DecRef(v_87_5);

    fv_87_6 = nd._type_sym_tab;
    if fv_87_6 is None {
        v_87_6 = _py_none();
    } else {
        v_87_6 = _emit_node(fv_87_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_87_6);
    Py_DecRef(v_87_6);

    v_87_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_87_7);
    Py_DecRef(v_87_7);

    fv_87_8 = nd.attached_tokens;
    if fv_87_8 is None {
        v_87_8 = _py_none();
    } else {
        v_87_8 = PyList_New(len(fv_87_8));
        li_87_8l = 0;
        for it_87_8l in fv_87_8 {
            e_87_8l = _emit_node(it_87_8l);
            PyList_SetItem(v_87_8, li_87_8l, e_87_8l);
            li_87_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_87_8);
    Py_DecRef(v_87_8);

    fv_87_9 = nd.op;
    v_87_9 = _emit_node(fv_87_9);
    PyDict_SetItem(d_h, _mat_keys[152], v_87_9);
    Py_DecRef(v_87_9);

    fv_87_10 = nd.values;
    v_87_10 = PyList_New(len(fv_87_10));
    li_87_10l = 0;
    for it_87_10l in fv_87_10 {
        e_87_10l = _emit_node(it_87_10l);
        PyList_SetItem(v_87_10, li_87_10l, e_87_10l);
        li_87_10l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[108], v_87_10);
    Py_DecRef(v_87_10);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_CastExpr(nd: CastExpr) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[88], _mat_classes[88]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_88_0 = nd.kid;
    v_88_0 = PyList_New(len(fv_88_0));
    li_88_0l = 0;
    for it_88_0l in fv_88_0 {
        e_88_0l = _emit_node(it_88_0l);
        PyList_SetItem(v_88_0, li_88_0l, e_88_0l);
        li_88_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_88_0);
    Py_DecRef(v_88_0);

    fv_88_1 = nd.parent;
    if fv_88_1 is None {
        v_88_1 = _py_none();
    } else {
        v_88_1 = _emit_node(fv_88_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_88_1);
    Py_DecRef(v_88_1);

    v_88_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_88_2);
    Py_DecRef(v_88_2);

    fv_88_3 = nd._in_mod_nodes;
    v_88_3 = PyList_New(len(fv_88_3));
    li_88_3l = 0;
    for it_88_3l in fv_88_3 {
        e_88_3l = _emit_node(it_88_3l);
        PyList_SetItem(v_88_3, li_88_3l, e_88_3l);
        li_88_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_88_3);
    Py_DecRef(v_88_3);

    v_88_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_88_4);
    Py_DecRef(v_88_4);

    fv_88_5 = nd.loc;
    v_88_5 = _emit_CodeLocInfo(fv_88_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_88_5);
    Py_DecRef(v_88_5);

    fv_88_6 = nd._type_sym_tab;
    if fv_88_6 is None {
        v_88_6 = _py_none();
    } else {
        v_88_6 = _emit_node(fv_88_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_88_6);
    Py_DecRef(v_88_6);

    v_88_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_88_7);
    Py_DecRef(v_88_7);

    fv_88_8 = nd.attached_tokens;
    if fv_88_8 is None {
        v_88_8 = _py_none();
    } else {
        v_88_8 = PyList_New(len(fv_88_8));
        li_88_8l = 0;
        for it_88_8l in fv_88_8 {
            e_88_8l = _emit_node(it_88_8l);
            PyList_SetItem(v_88_8, li_88_8l, e_88_8l);
            li_88_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_88_8);
    Py_DecRef(v_88_8);

    fv_88_9 = nd.value;
    v_88_9 = _emit_node(fv_88_9);
    PyDict_SetItem(d_h, _mat_keys[42], v_88_9);
    Py_DecRef(v_88_9);

    fv_88_10 = nd.cast_type;
    v_88_10 = _emit_node(fv_88_10);
    PyDict_SetItem(d_h, _mat_keys[153], v_88_10);
    Py_DecRef(v_88_10);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_CodeBlockStmt(nd: CodeBlockStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[89], _mat_classes[89]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_89_0 = nd.kid;
    v_89_0 = PyList_New(len(fv_89_0));
    li_89_0l = 0;
    for it_89_0l in fv_89_0 {
        e_89_0l = _emit_node(it_89_0l);
        PyList_SetItem(v_89_0, li_89_0l, e_89_0l);
        li_89_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_89_0);
    Py_DecRef(v_89_0);

    fv_89_1 = nd.parent;
    if fv_89_1 is None {
        v_89_1 = _py_none();
    } else {
        v_89_1 = _emit_node(fv_89_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_89_1);
    Py_DecRef(v_89_1);

    v_89_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_89_2);
    Py_DecRef(v_89_2);

    fv_89_3 = nd._in_mod_nodes;
    v_89_3 = PyList_New(len(fv_89_3));
    li_89_3l = 0;
    for it_89_3l in fv_89_3 {
        e_89_3l = _emit_node(it_89_3l);
        PyList_SetItem(v_89_3, li_89_3l, e_89_3l);
        li_89_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_89_3);
    Py_DecRef(v_89_3);

    v_89_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_89_4);
    Py_DecRef(v_89_4);

    fv_89_5 = nd.loc;
    v_89_5 = _emit_CodeLocInfo(fv_89_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_89_5);
    Py_DecRef(v_89_5);

    fv_89_6 = nd.bb_in;
    v_89_6 = PyList_New(len(fv_89_6));
    li_89_6l = 0;
    for it_89_6l in fv_89_6 {
        e_89_6l = _emit_node(it_89_6l);
        PyList_SetItem(v_89_6, li_89_6l, e_89_6l);
        li_89_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_89_6);
    Py_DecRef(v_89_6);

    fv_89_7 = nd.bb_out;
    v_89_7 = PyList_New(len(fv_89_7));
    li_89_7l = 0;
    for it_89_7l in fv_89_7 {
        e_89_7l = _emit_node(it_89_7l);
        PyList_SetItem(v_89_7, li_89_7l, e_89_7l);
        li_89_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_89_7);
    Py_DecRef(v_89_7);

    fv_89_8 = nd.affected_symbols;
    v_89_8 = PySet_New(0);
    if len(fv_89_8) != 0 {
        Py_DecRef(v_89_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_89_8);
    Py_DecRef(v_89_8);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_CommentToken(nd: CommentToken) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[90], _mat_classes[90]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_90_0 = nd.kid;
    v_90_0 = PyList_New(len(fv_90_0));
    li_90_0l = 0;
    for it_90_0l in fv_90_0 {
        e_90_0l = _emit_node(it_90_0l);
        PyList_SetItem(v_90_0, li_90_0l, e_90_0l);
        li_90_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_90_0);
    Py_DecRef(v_90_0);

    fv_90_1 = nd.parent;
    if fv_90_1 is None {
        v_90_1 = _py_none();
    } else {
        v_90_1 = _emit_node(fv_90_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_90_1);
    Py_DecRef(v_90_1);

    v_90_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_90_2);
    Py_DecRef(v_90_2);

    fv_90_3 = nd._in_mod_nodes;
    v_90_3 = PyList_New(len(fv_90_3));
    li_90_3l = 0;
    for it_90_3l in fv_90_3 {
        e_90_3l = _emit_node(it_90_3l);
        PyList_SetItem(v_90_3, li_90_3l, e_90_3l);
        li_90_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_90_3);
    Py_DecRef(v_90_3);

    v_90_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_90_4);
    Py_DecRef(v_90_4);

    fv_90_5 = nd.loc;
    v_90_5 = _emit_CodeLocInfo(fv_90_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_90_5);
    Py_DecRef(v_90_5);

    fv_90_6 = nd.orig_src;
    v_90_6 = _emit_node(fv_90_6);
    PyDict_SetItem(d_h, _mat_keys[41], v_90_6);
    Py_DecRef(v_90_6);

    fv_90_7 = nd.name;
    v_90_7 = _py_str(fv_90_7);
    PyDict_SetItem(d_h, _mat_keys[24], v_90_7);
    Py_DecRef(v_90_7);

    fv_90_8 = nd.value;
    v_90_8 = _py_str(fv_90_8);
    PyDict_SetItem(d_h, _mat_keys[42], v_90_8);
    Py_DecRef(v_90_8);

    fv_90_9 = nd.line_no;
    v_90_9 = PyLong_FromLongLong(fv_90_9);
    PyDict_SetItem(d_h, _mat_keys[43], v_90_9);
    Py_DecRef(v_90_9);

    fv_90_10 = nd.end_line;
    v_90_10 = PyLong_FromLongLong(fv_90_10);
    PyDict_SetItem(d_h, _mat_keys[44], v_90_10);
    Py_DecRef(v_90_10);

    fv_90_11 = nd.c_start;
    v_90_11 = PyLong_FromLongLong(fv_90_11);
    PyDict_SetItem(d_h, _mat_keys[45], v_90_11);
    Py_DecRef(v_90_11);

    fv_90_12 = nd.c_end;
    v_90_12 = PyLong_FromLongLong(fv_90_12);
    PyDict_SetItem(d_h, _mat_keys[46], v_90_12);
    Py_DecRef(v_90_12);

    fv_90_13 = nd.pos_start;
    v_90_13 = PyLong_FromLongLong(fv_90_13);
    PyDict_SetItem(d_h, _mat_keys[47], v_90_13);
    Py_DecRef(v_90_13);

    fv_90_14 = nd.pos_end;
    v_90_14 = PyLong_FromLongLong(fv_90_14);
    PyDict_SetItem(d_h, _mat_keys[48], v_90_14);
    Py_DecRef(v_90_14);

    fv_90_15 = nd._is_synthetic;
    v_90_15 = PyBool_FromLong(1 if fv_90_15 else 0);
    PyDict_SetItem(d_h, _mat_keys[49], v_90_15);
    Py_DecRef(v_90_15);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_CompareExpr(nd: CompareExpr) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[91], _mat_classes[91]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_91_0 = nd.kid;
    v_91_0 = PyList_New(len(fv_91_0));
    li_91_0l = 0;
    for it_91_0l in fv_91_0 {
        e_91_0l = _emit_node(it_91_0l);
        PyList_SetItem(v_91_0, li_91_0l, e_91_0l);
        li_91_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_91_0);
    Py_DecRef(v_91_0);

    fv_91_1 = nd.parent;
    if fv_91_1 is None {
        v_91_1 = _py_none();
    } else {
        v_91_1 = _emit_node(fv_91_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_91_1);
    Py_DecRef(v_91_1);

    v_91_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_91_2);
    Py_DecRef(v_91_2);

    fv_91_3 = nd._in_mod_nodes;
    v_91_3 = PyList_New(len(fv_91_3));
    li_91_3l = 0;
    for it_91_3l in fv_91_3 {
        e_91_3l = _emit_node(it_91_3l);
        PyList_SetItem(v_91_3, li_91_3l, e_91_3l);
        li_91_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_91_3);
    Py_DecRef(v_91_3);

    v_91_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_91_4);
    Py_DecRef(v_91_4);

    fv_91_5 = nd.loc;
    v_91_5 = _emit_CodeLocInfo(fv_91_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_91_5);
    Py_DecRef(v_91_5);

    fv_91_6 = nd._type_sym_tab;
    if fv_91_6 is None {
        v_91_6 = _py_none();
    } else {
        v_91_6 = _emit_node(fv_91_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_91_6);
    Py_DecRef(v_91_6);

    v_91_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_91_7);
    Py_DecRef(v_91_7);

    fv_91_8 = nd.attached_tokens;
    if fv_91_8 is None {
        v_91_8 = _py_none();
    } else {
        v_91_8 = PyList_New(len(fv_91_8));
        li_91_8l = 0;
        for it_91_8l in fv_91_8 {
            e_91_8l = _emit_node(it_91_8l);
            PyList_SetItem(v_91_8, li_91_8l, e_91_8l);
            li_91_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_91_8);
    Py_DecRef(v_91_8);

    fv_91_9 = nd.left;
    v_91_9 = _emit_node(fv_91_9);
    PyDict_SetItem(d_h, _mat_keys[151], v_91_9);
    Py_DecRef(v_91_9);

    fv_91_10 = nd.rights;
    v_91_10 = PyList_New(len(fv_91_10));
    li_91_10l = 0;
    for it_91_10l in fv_91_10 {
        e_91_10l = _emit_node(it_91_10l);
        PyList_SetItem(v_91_10, li_91_10l, e_91_10l);
        li_91_10l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[154], v_91_10);
    Py_DecRef(v_91_10);

    fv_91_11 = nd.ops;
    v_91_11 = PyList_New(len(fv_91_11));
    li_91_11l = 0;
    for it_91_11l in fv_91_11 {
        e_91_11l = _emit_node(it_91_11l);
        PyList_SetItem(v_91_11, li_91_11l, e_91_11l);
        li_91_11l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[155], v_91_11);
    Py_DecRef(v_91_11);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ConcurrentExpr(nd: ConcurrentExpr) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[92], _mat_classes[92]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_92_0 = nd.kid;
    v_92_0 = PyList_New(len(fv_92_0));
    li_92_0l = 0;
    for it_92_0l in fv_92_0 {
        e_92_0l = _emit_node(it_92_0l);
        PyList_SetItem(v_92_0, li_92_0l, e_92_0l);
        li_92_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_92_0);
    Py_DecRef(v_92_0);

    fv_92_1 = nd.parent;
    if fv_92_1 is None {
        v_92_1 = _py_none();
    } else {
        v_92_1 = _emit_node(fv_92_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_92_1);
    Py_DecRef(v_92_1);

    v_92_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_92_2);
    Py_DecRef(v_92_2);

    fv_92_3 = nd._in_mod_nodes;
    v_92_3 = PyList_New(len(fv_92_3));
    li_92_3l = 0;
    for it_92_3l in fv_92_3 {
        e_92_3l = _emit_node(it_92_3l);
        PyList_SetItem(v_92_3, li_92_3l, e_92_3l);
        li_92_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_92_3);
    Py_DecRef(v_92_3);

    v_92_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_92_4);
    Py_DecRef(v_92_4);

    fv_92_5 = nd.loc;
    v_92_5 = _emit_CodeLocInfo(fv_92_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_92_5);
    Py_DecRef(v_92_5);

    fv_92_6 = nd._type_sym_tab;
    if fv_92_6 is None {
        v_92_6 = _py_none();
    } else {
        v_92_6 = _emit_node(fv_92_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_92_6);
    Py_DecRef(v_92_6);

    v_92_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_92_7);
    Py_DecRef(v_92_7);

    fv_92_8 = nd.attached_tokens;
    if fv_92_8 is None {
        v_92_8 = _py_none();
    } else {
        v_92_8 = PyList_New(len(fv_92_8));
        li_92_8l = 0;
        for it_92_8l in fv_92_8 {
            e_92_8l = _emit_node(it_92_8l);
            PyList_SetItem(v_92_8, li_92_8l, e_92_8l);
            li_92_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_92_8);
    Py_DecRef(v_92_8);

    fv_92_9 = nd.tok;
    if fv_92_9 is None {
        v_92_9 = _py_none();
    } else {
        v_92_9 = _emit_node(fv_92_9);
    }
    PyDict_SetItem(d_h, _mat_keys[156], v_92_9);
    Py_DecRef(v_92_9);

    fv_92_10 = nd.target;
    v_92_10 = _emit_node(fv_92_10);
    PyDict_SetItem(d_h, _mat_keys[60], v_92_10);
    Py_DecRef(v_92_10);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ConditionalNode(nd: ConditionalNode) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[93], _mat_classes[93]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_93_0 = nd.kid;
    v_93_0 = PyList_New(len(fv_93_0));
    li_93_0l = 0;
    for it_93_0l in fv_93_0 {
        e_93_0l = _emit_node(it_93_0l);
        PyList_SetItem(v_93_0, li_93_0l, e_93_0l);
        li_93_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_93_0);
    Py_DecRef(v_93_0);

    fv_93_1 = nd.parent;
    if fv_93_1 is None {
        v_93_1 = _py_none();
    } else {
        v_93_1 = _emit_node(fv_93_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_93_1);
    Py_DecRef(v_93_1);

    v_93_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_93_2);
    Py_DecRef(v_93_2);

    fv_93_3 = nd._in_mod_nodes;
    v_93_3 = PyList_New(len(fv_93_3));
    li_93_3l = 0;
    for it_93_3l in fv_93_3 {
        e_93_3l = _emit_node(it_93_3l);
        PyList_SetItem(v_93_3, li_93_3l, e_93_3l);
        li_93_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_93_3);
    Py_DecRef(v_93_3);

    v_93_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_93_4);
    Py_DecRef(v_93_4);

    fv_93_5 = nd.loc;
    v_93_5 = _emit_CodeLocInfo(fv_93_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_93_5);
    Py_DecRef(v_93_5);

    fv_93_6 = nd.bb_in;
    v_93_6 = PyList_New(len(fv_93_6));
    li_93_6l = 0;
    for it_93_6l in fv_93_6 {
        e_93_6l = _emit_node(it_93_6l);
        PyList_SetItem(v_93_6, li_93_6l, e_93_6l);
        li_93_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_93_6);
    Py_DecRef(v_93_6);

    fv_93_7 = nd.bb_out;
    v_93_7 = PyList_New(len(fv_93_7));
    li_93_7l = 0;
    for it_93_7l in fv_93_7 {
        e_93_7l = _emit_node(it_93_7l);
        PyList_SetItem(v_93_7, li_93_7l, e_93_7l);
        li_93_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_93_7);
    Py_DecRef(v_93_7);

    fv_93_8 = nd.affected_symbols;
    v_93_8 = PySet_New(0);
    if len(fv_93_8) != 0 {
        Py_DecRef(v_93_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_93_8);
    Py_DecRef(v_93_8);

    fv_93_9 = nd.sc_true_target;
    if fv_93_9 is None {
        v_93_9 = _py_none();
    } else {
        v_93_9 = _emit_node(fv_93_9);
    }
    PyDict_SetItem(d_h, _mat_keys[116], v_93_9);
    Py_DecRef(v_93_9);

    fv_93_10 = nd.sc_false_target;
    if fv_93_10 is None {
        v_93_10 = _py_none();
    } else {
        v_93_10 = _emit_node(fv_93_10);
    }
    PyDict_SetItem(d_h, _mat_keys[117], v_93_10);
    Py_DecRef(v_93_10);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_CtBlock(nd: CtBlock) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[94], _mat_classes[94]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_94_0 = nd.kid;
    v_94_0 = PyList_New(len(fv_94_0));
    li_94_0l = 0;
    for it_94_0l in fv_94_0 {
        e_94_0l = _emit_node(it_94_0l);
        PyList_SetItem(v_94_0, li_94_0l, e_94_0l);
        li_94_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_94_0);
    Py_DecRef(v_94_0);

    fv_94_1 = nd.parent;
    if fv_94_1 is None {
        v_94_1 = _py_none();
    } else {
        v_94_1 = _emit_node(fv_94_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_94_1);
    Py_DecRef(v_94_1);

    v_94_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_94_2);
    Py_DecRef(v_94_2);

    fv_94_3 = nd._in_mod_nodes;
    v_94_3 = PyList_New(len(fv_94_3));
    li_94_3l = 0;
    for it_94_3l in fv_94_3 {
        e_94_3l = _emit_node(it_94_3l);
        PyList_SetItem(v_94_3, li_94_3l, e_94_3l);
        li_94_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_94_3);
    Py_DecRef(v_94_3);

    v_94_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_94_4);
    Py_DecRef(v_94_4);

    fv_94_5 = nd.loc;
    v_94_5 = _emit_CodeLocInfo(fv_94_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_94_5);
    Py_DecRef(v_94_5);

    fv_94_6 = nd._type_sym_tab;
    if fv_94_6 is None {
        v_94_6 = _py_none();
    } else {
        v_94_6 = _emit_node(fv_94_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_94_6);
    Py_DecRef(v_94_6);

    v_94_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_94_7);
    Py_DecRef(v_94_7);

    fv_94_8 = nd.attached_tokens;
    if fv_94_8 is None {
        v_94_8 = _py_none();
    } else {
        v_94_8 = PyList_New(len(fv_94_8));
        li_94_8l = 0;
        for it_94_8l in fv_94_8 {
            e_94_8l = _emit_node(it_94_8l);
            PyList_SetItem(v_94_8, li_94_8l, e_94_8l);
            li_94_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_94_8);
    Py_DecRef(v_94_8);

    fv_94_9 = nd.expr;
    v_94_9 = _emit_node(fv_94_9);
    PyDict_SetItem(d_h, _mat_keys[118], v_94_9);
    Py_DecRef(v_94_9);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_DisconnectOp(nd: DisconnectOp) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[95], _mat_classes[95]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_95_0 = nd.kid;
    v_95_0 = PyList_New(len(fv_95_0));
    li_95_0l = 0;
    for it_95_0l in fv_95_0 {
        e_95_0l = _emit_node(it_95_0l);
        PyList_SetItem(v_95_0, li_95_0l, e_95_0l);
        li_95_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_95_0);
    Py_DecRef(v_95_0);

    fv_95_1 = nd.parent;
    if fv_95_1 is None {
        v_95_1 = _py_none();
    } else {
        v_95_1 = _emit_node(fv_95_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_95_1);
    Py_DecRef(v_95_1);

    v_95_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_95_2);
    Py_DecRef(v_95_2);

    fv_95_3 = nd._in_mod_nodes;
    v_95_3 = PyList_New(len(fv_95_3));
    li_95_3l = 0;
    for it_95_3l in fv_95_3 {
        e_95_3l = _emit_node(it_95_3l);
        PyList_SetItem(v_95_3, li_95_3l, e_95_3l);
        li_95_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_95_3);
    Py_DecRef(v_95_3);

    v_95_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_95_4);
    Py_DecRef(v_95_4);

    fv_95_5 = nd.loc;
    v_95_5 = _emit_CodeLocInfo(fv_95_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_95_5);
    Py_DecRef(v_95_5);

    fv_95_6 = nd.from_walker;
    v_95_6 = PyBool_FromLong(1 if fv_95_6 else 0);
    PyDict_SetItem(d_h, _mat_keys[73], v_95_6);
    Py_DecRef(v_95_6);

    fv_95_7 = nd.edge_spec;
    v_95_7 = _emit_node(fv_95_7);
    PyDict_SetItem(d_h, _mat_keys[157], v_95_7);
    Py_DecRef(v_95_7);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_EdgeRefTrailer(nd: EdgeRefTrailer) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[96], _mat_classes[96]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_96_0 = nd.kid;
    v_96_0 = PyList_New(len(fv_96_0));
    li_96_0l = 0;
    for it_96_0l in fv_96_0 {
        e_96_0l = _emit_node(it_96_0l);
        PyList_SetItem(v_96_0, li_96_0l, e_96_0l);
        li_96_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_96_0);
    Py_DecRef(v_96_0);

    fv_96_1 = nd.parent;
    if fv_96_1 is None {
        v_96_1 = _py_none();
    } else {
        v_96_1 = _emit_node(fv_96_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_96_1);
    Py_DecRef(v_96_1);

    v_96_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_96_2);
    Py_DecRef(v_96_2);

    fv_96_3 = nd._in_mod_nodes;
    v_96_3 = PyList_New(len(fv_96_3));
    li_96_3l = 0;
    for it_96_3l in fv_96_3 {
        e_96_3l = _emit_node(it_96_3l);
        PyList_SetItem(v_96_3, li_96_3l, e_96_3l);
        li_96_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_96_3);
    Py_DecRef(v_96_3);

    v_96_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_96_4);
    Py_DecRef(v_96_4);

    fv_96_5 = nd.loc;
    v_96_5 = _emit_CodeLocInfo(fv_96_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_96_5);
    Py_DecRef(v_96_5);

    fv_96_6 = nd._type_sym_tab;
    if fv_96_6 is None {
        v_96_6 = _py_none();
    } else {
        v_96_6 = _emit_node(fv_96_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_96_6);
    Py_DecRef(v_96_6);

    v_96_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_96_7);
    Py_DecRef(v_96_7);

    fv_96_8 = nd.attached_tokens;
    if fv_96_8 is None {
        v_96_8 = _py_none();
    } else {
        v_96_8 = PyList_New(len(fv_96_8));
        li_96_8l = 0;
        for it_96_8l in fv_96_8 {
            e_96_8l = _emit_node(it_96_8l);
            PyList_SetItem(v_96_8, li_96_8l, e_96_8l);
            li_96_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_96_8);
    Py_DecRef(v_96_8);

    fv_96_9 = nd.chain;
    v_96_9 = PyList_New(len(fv_96_9));
    li_96_9l = 0;
    for it_96_9l in fv_96_9 {
        e_96_9l = _emit_node(it_96_9l);
        PyList_SetItem(v_96_9, li_96_9l, e_96_9l);
        li_96_9l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[158], v_96_9);
    Py_DecRef(v_96_9);

    fv_96_10 = nd.edges_only;
    v_96_10 = PyBool_FromLong(1 if fv_96_10 else 0);
    PyDict_SetItem(d_h, _mat_keys[159], v_96_10);
    Py_DecRef(v_96_10);

    fv_96_11 = nd.is_async;
    v_96_11 = PyBool_FromLong(1 if fv_96_11 else 0);
    PyDict_SetItem(d_h, _mat_keys[14], v_96_11);
    Py_DecRef(v_96_11);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ElementStmt(nd: ElementStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[97], _mat_classes[97]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_97_0 = nd.kid;
    v_97_0 = PyList_New(len(fv_97_0));
    li_97_0l = 0;
    for it_97_0l in fv_97_0 {
        e_97_0l = _emit_node(it_97_0l);
        PyList_SetItem(v_97_0, li_97_0l, e_97_0l);
        li_97_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_97_0);
    Py_DecRef(v_97_0);

    fv_97_1 = nd.parent;
    if fv_97_1 is None {
        v_97_1 = _py_none();
    } else {
        v_97_1 = _emit_node(fv_97_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_97_1);
    Py_DecRef(v_97_1);

    v_97_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_97_2);
    Py_DecRef(v_97_2);

    fv_97_3 = nd._in_mod_nodes;
    v_97_3 = PyList_New(len(fv_97_3));
    li_97_3l = 0;
    for it_97_3l in fv_97_3 {
        e_97_3l = _emit_node(it_97_3l);
        PyList_SetItem(v_97_3, li_97_3l, e_97_3l);
        li_97_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_97_3);
    Py_DecRef(v_97_3);

    v_97_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_97_4);
    Py_DecRef(v_97_4);

    fv_97_5 = nd.loc;
    v_97_5 = _emit_CodeLocInfo(fv_97_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_97_5);
    Py_DecRef(v_97_5);

    fv_97_6 = nd.doc;
    if fv_97_6 is None {
        v_97_6 = _py_none();
    } else {
        v_97_6 = _emit_node(fv_97_6);
    }
    PyDict_SetItem(d_h, _mat_keys[8], v_97_6);
    Py_DecRef(v_97_6);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ElseStmt(nd: ElseStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[98], _mat_classes[98]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_98_0 = nd.kid;
    v_98_0 = PyList_New(len(fv_98_0));
    li_98_0l = 0;
    for it_98_0l in fv_98_0 {
        e_98_0l = _emit_node(it_98_0l);
        PyList_SetItem(v_98_0, li_98_0l, e_98_0l);
        li_98_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_98_0);
    Py_DecRef(v_98_0);

    fv_98_1 = nd.parent;
    if fv_98_1 is None {
        v_98_1 = _py_none();
    } else {
        v_98_1 = _emit_node(fv_98_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_98_1);
    Py_DecRef(v_98_1);

    v_98_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_98_2);
    Py_DecRef(v_98_2);

    fv_98_3 = nd._in_mod_nodes;
    v_98_3 = PyList_New(len(fv_98_3));
    li_98_3l = 0;
    for it_98_3l in fv_98_3 {
        e_98_3l = _emit_node(it_98_3l);
        PyList_SetItem(v_98_3, li_98_3l, e_98_3l);
        li_98_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_98_3);
    Py_DecRef(v_98_3);

    v_98_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_98_4);
    Py_DecRef(v_98_4);

    fv_98_5 = nd.loc;
    v_98_5 = _emit_CodeLocInfo(fv_98_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_98_5);
    Py_DecRef(v_98_5);

    fv_98_6 = nd.scope_name;
    v_98_6 = _py_str(fv_98_6);
    PyDict_SetItem(d_h, _mat_keys[18], v_98_6);
    Py_DecRef(v_98_6);

    fv_98_7 = nd.parent_scope;
    if fv_98_7 is None {
        v_98_7 = _py_none();
    } else {
        v_98_7 = _emit_node(fv_98_7);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_98_7);
    Py_DecRef(v_98_7);

    fv_98_8 = nd.kid_scope;
    v_98_8 = PyList_New(len(fv_98_8));
    li_98_8l = 0;
    for it_98_8l in fv_98_8 {
        e_98_8l = _emit_node(it_98_8l);
        PyList_SetItem(v_98_8, li_98_8l, e_98_8l);
        li_98_8l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_98_8);
    Py_DecRef(v_98_8);

    fv_98_9 = nd.names_in_scope;
    v_98_9 = PyDict_New();
    for (dk_98_9d, dv_98_9d) in fv_98_9.items() {
        kh_98_9d = _py_str(dk_98_9d);
        vh_98_9d = _emit_Symbol(dv_98_9d);
        PyDict_SetItem(v_98_9, kh_98_9d, vh_98_9d);
        Py_DecRef(kh_98_9d);
        Py_DecRef(vh_98_9d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_98_9);
    Py_DecRef(v_98_9);

    fv_98_10 = nd.names_in_scope_overload;
    v_98_10 = PyDict_New();
    for (dk_98_10d, dv_98_10d) in fv_98_10.items() {
        kh_98_10d = _py_str(dk_98_10d);
        vh_98_10d = PyList_New(len(dv_98_10d));
        li_98_10dl = 0;
        for it_98_10dl in dv_98_10d {
            e_98_10dl = _emit_Symbol(it_98_10dl);
            PyList_SetItem(vh_98_10d, li_98_10dl, e_98_10dl);
            li_98_10dl += 1;
        }
        PyDict_SetItem(v_98_10, kh_98_10d, vh_98_10d);
        Py_DecRef(kh_98_10d);
        Py_DecRef(vh_98_10d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_98_10);
    Py_DecRef(v_98_10);

    fv_98_11 = nd.implicit_rebinds;
    v_98_11 = PyDict_New();
    for (dk_98_11d, dv_98_11d) in fv_98_11.items() {
        kh_98_11d = _py_str(dk_98_11d);
        vh_98_11d = _emit_Symbol(dv_98_11d);
        PyDict_SetItem(v_98_11, kh_98_11d, vh_98_11d);
        Py_DecRef(kh_98_11d);
        Py_DecRef(vh_98_11d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_98_11);
    Py_DecRef(v_98_11);

    fv_98_12 = nd.body;
    v_98_12 = PyList_New(len(fv_98_12));
    li_98_12l = 0;
    for it_98_12l in fv_98_12 {
        e_98_12l = _emit_node(it_98_12l);
        PyList_SetItem(v_98_12, li_98_12l, e_98_12l);
        li_98_12l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_98_12);
    Py_DecRef(v_98_12);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_EmptyToken(nd: EmptyToken) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[99], _mat_classes[99]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_99_0 = nd.kid;
    v_99_0 = PyList_New(len(fv_99_0));
    li_99_0l = 0;
    for it_99_0l in fv_99_0 {
        e_99_0l = _emit_node(it_99_0l);
        PyList_SetItem(v_99_0, li_99_0l, e_99_0l);
        li_99_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_99_0);
    Py_DecRef(v_99_0);

    fv_99_1 = nd.parent;
    if fv_99_1 is None {
        v_99_1 = _py_none();
    } else {
        v_99_1 = _emit_node(fv_99_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_99_1);
    Py_DecRef(v_99_1);

    v_99_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_99_2);
    Py_DecRef(v_99_2);

    fv_99_3 = nd._in_mod_nodes;
    v_99_3 = PyList_New(len(fv_99_3));
    li_99_3l = 0;
    for it_99_3l in fv_99_3 {
        e_99_3l = _emit_node(it_99_3l);
        PyList_SetItem(v_99_3, li_99_3l, e_99_3l);
        li_99_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_99_3);
    Py_DecRef(v_99_3);

    v_99_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_99_4);
    Py_DecRef(v_99_4);

    fv_99_5 = nd.loc;
    v_99_5 = _emit_CodeLocInfo(fv_99_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_99_5);
    Py_DecRef(v_99_5);

    fv_99_6 = nd.orig_src;
    v_99_6 = _emit_node(fv_99_6);
    PyDict_SetItem(d_h, _mat_keys[41], v_99_6);
    Py_DecRef(v_99_6);

    fv_99_7 = nd.name;
    v_99_7 = _py_str(fv_99_7);
    PyDict_SetItem(d_h, _mat_keys[24], v_99_7);
    Py_DecRef(v_99_7);

    fv_99_8 = nd.value;
    v_99_8 = _py_str(fv_99_8);
    PyDict_SetItem(d_h, _mat_keys[42], v_99_8);
    Py_DecRef(v_99_8);

    fv_99_9 = nd.line_no;
    v_99_9 = PyLong_FromLongLong(fv_99_9);
    PyDict_SetItem(d_h, _mat_keys[43], v_99_9);
    Py_DecRef(v_99_9);

    fv_99_10 = nd.end_line;
    v_99_10 = PyLong_FromLongLong(fv_99_10);
    PyDict_SetItem(d_h, _mat_keys[44], v_99_10);
    Py_DecRef(v_99_10);

    fv_99_11 = nd.c_start;
    v_99_11 = PyLong_FromLongLong(fv_99_11);
    PyDict_SetItem(d_h, _mat_keys[45], v_99_11);
    Py_DecRef(v_99_11);

    fv_99_12 = nd.c_end;
    v_99_12 = PyLong_FromLongLong(fv_99_12);
    PyDict_SetItem(d_h, _mat_keys[46], v_99_12);
    Py_DecRef(v_99_12);

    fv_99_13 = nd.pos_start;
    v_99_13 = PyLong_FromLongLong(fv_99_13);
    PyDict_SetItem(d_h, _mat_keys[47], v_99_13);
    Py_DecRef(v_99_13);

    fv_99_14 = nd.pos_end;
    v_99_14 = PyLong_FromLongLong(fv_99_14);
    PyDict_SetItem(d_h, _mat_keys[48], v_99_14);
    Py_DecRef(v_99_14);

    fv_99_15 = nd._is_synthetic;
    v_99_15 = PyBool_FromLong(1 if fv_99_15 else 0);
    PyDict_SetItem(d_h, _mat_keys[49], v_99_15);
    Py_DecRef(v_99_15);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_EventSignature(nd: EventSignature) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[100], _mat_classes[100]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_100_0 = nd.kid;
    v_100_0 = PyList_New(len(fv_100_0));
    li_100_0l = 0;
    for it_100_0l in fv_100_0 {
        e_100_0l = _emit_node(it_100_0l);
        PyList_SetItem(v_100_0, li_100_0l, e_100_0l);
        li_100_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_100_0);
    Py_DecRef(v_100_0);

    fv_100_1 = nd.parent;
    if fv_100_1 is None {
        v_100_1 = _py_none();
    } else {
        v_100_1 = _emit_node(fv_100_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_100_1);
    Py_DecRef(v_100_1);

    v_100_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_100_2);
    Py_DecRef(v_100_2);

    fv_100_3 = nd._in_mod_nodes;
    v_100_3 = PyList_New(len(fv_100_3));
    li_100_3l = 0;
    for it_100_3l in fv_100_3 {
        e_100_3l = _emit_node(it_100_3l);
        PyList_SetItem(v_100_3, li_100_3l, e_100_3l);
        li_100_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_100_3);
    Py_DecRef(v_100_3);

    v_100_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_100_4);
    Py_DecRef(v_100_4);

    fv_100_5 = nd.loc;
    v_100_5 = _emit_CodeLocInfo(fv_100_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_100_5);
    Py_DecRef(v_100_5);

    fv_100_6 = nd.from_walker;
    v_100_6 = PyBool_FromLong(1 if fv_100_6 else 0);
    PyDict_SetItem(d_h, _mat_keys[73], v_100_6);
    Py_DecRef(v_100_6);

    fv_100_7 = nd.event;
    v_100_7 = _emit_node(fv_100_7);
    PyDict_SetItem(d_h, _mat_keys[160], v_100_7);
    Py_DecRef(v_100_7);

    fv_100_8 = nd.arch_tag_info;
    if fv_100_8 is None {
        v_100_8 = _py_none();
    } else {
        v_100_8 = _emit_node(fv_100_8);
    }
    PyDict_SetItem(d_h, _mat_keys[161], v_100_8);
    Py_DecRef(v_100_8);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_FormattedValue(nd: FormattedValue) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[101], _mat_classes[101]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_101_0 = nd.kid;
    v_101_0 = PyList_New(len(fv_101_0));
    li_101_0l = 0;
    for it_101_0l in fv_101_0 {
        e_101_0l = _emit_node(it_101_0l);
        PyList_SetItem(v_101_0, li_101_0l, e_101_0l);
        li_101_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_101_0);
    Py_DecRef(v_101_0);

    fv_101_1 = nd.parent;
    if fv_101_1 is None {
        v_101_1 = _py_none();
    } else {
        v_101_1 = _emit_node(fv_101_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_101_1);
    Py_DecRef(v_101_1);

    v_101_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_101_2);
    Py_DecRef(v_101_2);

    fv_101_3 = nd._in_mod_nodes;
    v_101_3 = PyList_New(len(fv_101_3));
    li_101_3l = 0;
    for it_101_3l in fv_101_3 {
        e_101_3l = _emit_node(it_101_3l);
        PyList_SetItem(v_101_3, li_101_3l, e_101_3l);
        li_101_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_101_3);
    Py_DecRef(v_101_3);

    v_101_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_101_4);
    Py_DecRef(v_101_4);

    fv_101_5 = nd.loc;
    v_101_5 = _emit_CodeLocInfo(fv_101_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_101_5);
    Py_DecRef(v_101_5);

    fv_101_6 = nd._type_sym_tab;
    if fv_101_6 is None {
        v_101_6 = _py_none();
    } else {
        v_101_6 = _emit_node(fv_101_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_101_6);
    Py_DecRef(v_101_6);

    v_101_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_101_7);
    Py_DecRef(v_101_7);

    fv_101_8 = nd.attached_tokens;
    if fv_101_8 is None {
        v_101_8 = _py_none();
    } else {
        v_101_8 = PyList_New(len(fv_101_8));
        li_101_8l = 0;
        for it_101_8l in fv_101_8 {
            e_101_8l = _emit_node(it_101_8l);
            PyList_SetItem(v_101_8, li_101_8l, e_101_8l);
            li_101_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_101_8);
    Py_DecRef(v_101_8);

    fv_101_9 = nd.format_part;
    v_101_9 = _emit_node(fv_101_9);
    PyDict_SetItem(d_h, _mat_keys[162], v_101_9);
    Py_DecRef(v_101_9);

    fv_101_10 = nd.conversion;
    v_101_10 = PyLong_FromLongLong(fv_101_10);
    PyDict_SetItem(d_h, _mat_keys[163], v_101_10);
    Py_DecRef(v_101_10);

    fv_101_11 = nd.format_spec;
    if fv_101_11 is None {
        v_101_11 = _py_none();
    } else {
        v_101_11 = _emit_node(fv_101_11);
    }
    PyDict_SetItem(d_h, _mat_keys[164], v_101_11);
    Py_DecRef(v_101_11);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_FuncCall(nd: FuncCall) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[102], _mat_classes[102]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_102_0 = nd.kid;
    v_102_0 = PyList_New(len(fv_102_0));
    li_102_0l = 0;
    for it_102_0l in fv_102_0 {
        e_102_0l = _emit_node(it_102_0l);
        PyList_SetItem(v_102_0, li_102_0l, e_102_0l);
        li_102_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_102_0);
    Py_DecRef(v_102_0);

    fv_102_1 = nd.parent;
    if fv_102_1 is None {
        v_102_1 = _py_none();
    } else {
        v_102_1 = _emit_node(fv_102_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_102_1);
    Py_DecRef(v_102_1);

    v_102_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_102_2);
    Py_DecRef(v_102_2);

    fv_102_3 = nd._in_mod_nodes;
    v_102_3 = PyList_New(len(fv_102_3));
    li_102_3l = 0;
    for it_102_3l in fv_102_3 {
        e_102_3l = _emit_node(it_102_3l);
        PyList_SetItem(v_102_3, li_102_3l, e_102_3l);
        li_102_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_102_3);
    Py_DecRef(v_102_3);

    v_102_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_102_4);
    Py_DecRef(v_102_4);

    fv_102_5 = nd.loc;
    v_102_5 = _emit_CodeLocInfo(fv_102_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_102_5);
    Py_DecRef(v_102_5);

    fv_102_6 = nd._type_sym_tab;
    if fv_102_6 is None {
        v_102_6 = _py_none();
    } else {
        v_102_6 = _emit_node(fv_102_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_102_6);
    Py_DecRef(v_102_6);

    v_102_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_102_7);
    Py_DecRef(v_102_7);

    fv_102_8 = nd.attached_tokens;
    if fv_102_8 is None {
        v_102_8 = _py_none();
    } else {
        v_102_8 = PyList_New(len(fv_102_8));
        li_102_8l = 0;
        for it_102_8l in fv_102_8 {
            e_102_8l = _emit_node(it_102_8l);
            PyList_SetItem(v_102_8, li_102_8l, e_102_8l);
            li_102_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_102_8);
    Py_DecRef(v_102_8);

    fv_102_9 = nd.target;
    v_102_9 = _emit_node(fv_102_9);
    PyDict_SetItem(d_h, _mat_keys[60], v_102_9);
    Py_DecRef(v_102_9);

    fv_102_10 = nd.params;
    if fv_102_10 is None {
        v_102_10 = _py_none();
    } else {
        v_102_10 = PyList_New(len(fv_102_10));
        li_102_10l = 0;
        for it_102_10l in fv_102_10 {
            e_102_10l = _emit_node(it_102_10l);
            PyList_SetItem(v_102_10, li_102_10l, e_102_10l);
            li_102_10l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[165], v_102_10);
    Py_DecRef(v_102_10);

    fv_102_11 = nd.genai_call;
    if fv_102_11 is None {
        v_102_11 = _py_none();
    } else {
        v_102_11 = _emit_node(fv_102_11);
    }
    PyDict_SetItem(d_h, _mat_keys[166], v_102_11);
    Py_DecRef(v_102_11);

    fv_102_12 = nd.call_kind;
    if fv_102_12 is None {
        v_102_12 = _py_none();
    } else {
        v_102_12 = _py_str(fv_102_12);
    }
    PyDict_SetItem(d_h, _mat_keys[167], v_102_12);
    Py_DecRef(v_102_12);

    fv_102_13 = nd.callee_decl;
    if fv_102_13 is None {
        v_102_13 = _py_none();
    } else {
        v_102_13 = _emit_node(fv_102_13);
    }
    PyDict_SetItem(d_h, _mat_keys[168], v_102_13);
    Py_DecRef(v_102_13);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_IfElseExpr(nd: IfElseExpr) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[103], _mat_classes[103]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_103_0 = nd.kid;
    v_103_0 = PyList_New(len(fv_103_0));
    li_103_0l = 0;
    for it_103_0l in fv_103_0 {
        e_103_0l = _emit_node(it_103_0l);
        PyList_SetItem(v_103_0, li_103_0l, e_103_0l);
        li_103_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_103_0);
    Py_DecRef(v_103_0);

    fv_103_1 = nd.parent;
    if fv_103_1 is None {
        v_103_1 = _py_none();
    } else {
        v_103_1 = _emit_node(fv_103_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_103_1);
    Py_DecRef(v_103_1);

    v_103_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_103_2);
    Py_DecRef(v_103_2);

    fv_103_3 = nd._in_mod_nodes;
    v_103_3 = PyList_New(len(fv_103_3));
    li_103_3l = 0;
    for it_103_3l in fv_103_3 {
        e_103_3l = _emit_node(it_103_3l);
        PyList_SetItem(v_103_3, li_103_3l, e_103_3l);
        li_103_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_103_3);
    Py_DecRef(v_103_3);

    v_103_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_103_4);
    Py_DecRef(v_103_4);

    fv_103_5 = nd.loc;
    v_103_5 = _emit_CodeLocInfo(fv_103_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_103_5);
    Py_DecRef(v_103_5);

    fv_103_6 = nd._type_sym_tab;
    if fv_103_6 is None {
        v_103_6 = _py_none();
    } else {
        v_103_6 = _emit_node(fv_103_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_103_6);
    Py_DecRef(v_103_6);

    v_103_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_103_7);
    Py_DecRef(v_103_7);

    fv_103_8 = nd.attached_tokens;
    if fv_103_8 is None {
        v_103_8 = _py_none();
    } else {
        v_103_8 = PyList_New(len(fv_103_8));
        li_103_8l = 0;
        for it_103_8l in fv_103_8 {
            e_103_8l = _emit_node(it_103_8l);
            PyList_SetItem(v_103_8, li_103_8l, e_103_8l);
            li_103_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_103_8);
    Py_DecRef(v_103_8);

    fv_103_9 = nd.condition;
    v_103_9 = _emit_node(fv_103_9);
    PyDict_SetItem(d_h, _mat_keys[77], v_103_9);
    Py_DecRef(v_103_9);

    fv_103_10 = nd.value;
    v_103_10 = _emit_node(fv_103_10);
    PyDict_SetItem(d_h, _mat_keys[42], v_103_10);
    Py_DecRef(v_103_10);

    fv_103_11 = nd.else_value;
    v_103_11 = _emit_node(fv_103_11);
    PyDict_SetItem(d_h, _mat_keys[169], v_103_11);
    Py_DecRef(v_103_11);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_JsxComment(nd: JsxComment) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[104], _mat_classes[104]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_104_0 = nd.kid;
    v_104_0 = PyList_New(len(fv_104_0));
    li_104_0l = 0;
    for it_104_0l in fv_104_0 {
        e_104_0l = _emit_node(it_104_0l);
        PyList_SetItem(v_104_0, li_104_0l, e_104_0l);
        li_104_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_104_0);
    Py_DecRef(v_104_0);

    fv_104_1 = nd.parent;
    if fv_104_1 is None {
        v_104_1 = _py_none();
    } else {
        v_104_1 = _emit_node(fv_104_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_104_1);
    Py_DecRef(v_104_1);

    v_104_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_104_2);
    Py_DecRef(v_104_2);

    fv_104_3 = nd._in_mod_nodes;
    v_104_3 = PyList_New(len(fv_104_3));
    li_104_3l = 0;
    for it_104_3l in fv_104_3 {
        e_104_3l = _emit_node(it_104_3l);
        PyList_SetItem(v_104_3, li_104_3l, e_104_3l);
        li_104_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_104_3);
    Py_DecRef(v_104_3);

    v_104_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_104_4);
    Py_DecRef(v_104_4);

    fv_104_5 = nd.loc;
    v_104_5 = _emit_CodeLocInfo(fv_104_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_104_5);
    Py_DecRef(v_104_5);

    fv_104_6 = nd.value;
    v_104_6 = _emit_node(fv_104_6);
    PyDict_SetItem(d_h, _mat_keys[42], v_104_6);
    Py_DecRef(v_104_6);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_JsxExpression(nd: JsxExpression) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[105], _mat_classes[105]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_105_0 = nd.kid;
    v_105_0 = PyList_New(len(fv_105_0));
    li_105_0l = 0;
    for it_105_0l in fv_105_0 {
        e_105_0l = _emit_node(it_105_0l);
        PyList_SetItem(v_105_0, li_105_0l, e_105_0l);
        li_105_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_105_0);
    Py_DecRef(v_105_0);

    fv_105_1 = nd.parent;
    if fv_105_1 is None {
        v_105_1 = _py_none();
    } else {
        v_105_1 = _emit_node(fv_105_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_105_1);
    Py_DecRef(v_105_1);

    v_105_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_105_2);
    Py_DecRef(v_105_2);

    fv_105_3 = nd._in_mod_nodes;
    v_105_3 = PyList_New(len(fv_105_3));
    li_105_3l = 0;
    for it_105_3l in fv_105_3 {
        e_105_3l = _emit_node(it_105_3l);
        PyList_SetItem(v_105_3, li_105_3l, e_105_3l);
        li_105_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_105_3);
    Py_DecRef(v_105_3);

    v_105_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_105_4);
    Py_DecRef(v_105_4);

    fv_105_5 = nd.loc;
    v_105_5 = _emit_CodeLocInfo(fv_105_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_105_5);
    Py_DecRef(v_105_5);

    fv_105_6 = nd.expr;
    v_105_6 = _emit_node(fv_105_6);
    PyDict_SetItem(d_h, _mat_keys[118], v_105_6);
    Py_DecRef(v_105_6);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_JsxNormalAttribute(nd: JsxNormalAttribute) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[106], _mat_classes[106]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_106_0 = nd.kid;
    v_106_0 = PyList_New(len(fv_106_0));
    li_106_0l = 0;
    for it_106_0l in fv_106_0 {
        e_106_0l = _emit_node(it_106_0l);
        PyList_SetItem(v_106_0, li_106_0l, e_106_0l);
        li_106_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_106_0);
    Py_DecRef(v_106_0);

    fv_106_1 = nd.parent;
    if fv_106_1 is None {
        v_106_1 = _py_none();
    } else {
        v_106_1 = _emit_node(fv_106_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_106_1);
    Py_DecRef(v_106_1);

    v_106_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_106_2);
    Py_DecRef(v_106_2);

    fv_106_3 = nd._in_mod_nodes;
    v_106_3 = PyList_New(len(fv_106_3));
    li_106_3l = 0;
    for it_106_3l in fv_106_3 {
        e_106_3l = _emit_node(it_106_3l);
        PyList_SetItem(v_106_3, li_106_3l, e_106_3l);
        li_106_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_106_3);
    Py_DecRef(v_106_3);

    v_106_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_106_4);
    Py_DecRef(v_106_4);

    fv_106_5 = nd.loc;
    v_106_5 = _emit_CodeLocInfo(fv_106_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_106_5);
    Py_DecRef(v_106_5);

    fv_106_6 = nd.name;
    if isinstance(fv_106_6, Name) {
        v_106_6 = _emit_node(fv_106_6);
    } elif isinstance(fv_106_6, Token) {
        v_106_6 = _emit_node(fv_106_6);
    } else {
        v_106_6 = _py_none();
    }
    PyDict_SetItem(d_h, _mat_keys[24], v_106_6);
    Py_DecRef(v_106_6);

    fv_106_7 = nd.value;
    if fv_106_7 is None {
        v_106_7 = _py_none();
    } else {
        if isinstance(fv_106_7, String) {
            v_106_7 = _emit_node(fv_106_7);
        } elif isinstance(fv_106_7, Expr) {
            v_106_7 = _emit_node(fv_106_7);
        } else {
            v_106_7 = _py_none();
        }
    }
    PyDict_SetItem(d_h, _mat_keys[42], v_106_7);
    Py_DecRef(v_106_7);

    fv_106_8 = nd.is_shorthand;
    v_106_8 = PyBool_FromLong(1 if fv_106_8 else 0);
    PyDict_SetItem(d_h, _mat_keys[170], v_106_8);
    Py_DecRef(v_106_8);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_JsxSlot(nd: JsxSlot) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[107], _mat_classes[107]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_107_0 = nd.kid;
    v_107_0 = PyList_New(len(fv_107_0));
    li_107_0l = 0;
    for it_107_0l in fv_107_0 {
        e_107_0l = _emit_node(it_107_0l);
        PyList_SetItem(v_107_0, li_107_0l, e_107_0l);
        li_107_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_107_0);
    Py_DecRef(v_107_0);

    fv_107_1 = nd.parent;
    if fv_107_1 is None {
        v_107_1 = _py_none();
    } else {
        v_107_1 = _emit_node(fv_107_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_107_1);
    Py_DecRef(v_107_1);

    v_107_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_107_2);
    Py_DecRef(v_107_2);

    fv_107_3 = nd._in_mod_nodes;
    v_107_3 = PyList_New(len(fv_107_3));
    li_107_3l = 0;
    for it_107_3l in fv_107_3 {
        e_107_3l = _emit_node(it_107_3l);
        PyList_SetItem(v_107_3, li_107_3l, e_107_3l);
        li_107_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_107_3);
    Py_DecRef(v_107_3);

    v_107_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_107_4);
    Py_DecRef(v_107_4);

    fv_107_5 = nd.loc;
    v_107_5 = _emit_CodeLocInfo(fv_107_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_107_5);
    Py_DecRef(v_107_5);

    fv_107_6 = nd.body;
    v_107_6 = PyList_New(len(fv_107_6));
    li_107_6l = 0;
    for it_107_6l in fv_107_6 {
        e_107_6l = _emit_node(it_107_6l);
        PyList_SetItem(v_107_6, li_107_6l, e_107_6l);
        li_107_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[17], v_107_6);
    Py_DecRef(v_107_6);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_JsxSpreadAttribute(nd: JsxSpreadAttribute) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[108], _mat_classes[108]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_108_0 = nd.kid;
    v_108_0 = PyList_New(len(fv_108_0));
    li_108_0l = 0;
    for it_108_0l in fv_108_0 {
        e_108_0l = _emit_node(it_108_0l);
        PyList_SetItem(v_108_0, li_108_0l, e_108_0l);
        li_108_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_108_0);
    Py_DecRef(v_108_0);

    fv_108_1 = nd.parent;
    if fv_108_1 is None {
        v_108_1 = _py_none();
    } else {
        v_108_1 = _emit_node(fv_108_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_108_1);
    Py_DecRef(v_108_1);

    v_108_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_108_2);
    Py_DecRef(v_108_2);

    fv_108_3 = nd._in_mod_nodes;
    v_108_3 = PyList_New(len(fv_108_3));
    li_108_3l = 0;
    for it_108_3l in fv_108_3 {
        e_108_3l = _emit_node(it_108_3l);
        PyList_SetItem(v_108_3, li_108_3l, e_108_3l);
        li_108_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_108_3);
    Py_DecRef(v_108_3);

    v_108_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_108_4);
    Py_DecRef(v_108_4);

    fv_108_5 = nd.loc;
    v_108_5 = _emit_CodeLocInfo(fv_108_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_108_5);
    Py_DecRef(v_108_5);

    fv_108_6 = nd.expr;
    v_108_6 = _emit_node(fv_108_6);
    PyDict_SetItem(d_h, _mat_keys[118], v_108_6);
    Py_DecRef(v_108_6);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_JsxText(nd: JsxText) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[109], _mat_classes[109]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_109_0 = nd.kid;
    v_109_0 = PyList_New(len(fv_109_0));
    li_109_0l = 0;
    for it_109_0l in fv_109_0 {
        e_109_0l = _emit_node(it_109_0l);
        PyList_SetItem(v_109_0, li_109_0l, e_109_0l);
        li_109_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_109_0);
    Py_DecRef(v_109_0);

    fv_109_1 = nd.parent;
    if fv_109_1 is None {
        v_109_1 = _py_none();
    } else {
        v_109_1 = _emit_node(fv_109_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_109_1);
    Py_DecRef(v_109_1);

    v_109_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_109_2);
    Py_DecRef(v_109_2);

    fv_109_3 = nd._in_mod_nodes;
    v_109_3 = PyList_New(len(fv_109_3));
    li_109_3l = 0;
    for it_109_3l in fv_109_3 {
        e_109_3l = _emit_node(it_109_3l);
        PyList_SetItem(v_109_3, li_109_3l, e_109_3l);
        li_109_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_109_3);
    Py_DecRef(v_109_3);

    v_109_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_109_4);
    Py_DecRef(v_109_4);

    fv_109_5 = nd.loc;
    v_109_5 = _emit_CodeLocInfo(fv_109_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_109_5);
    Py_DecRef(v_109_5);

    fv_109_6 = nd.value;
    if isinstance(fv_109_6, Token) {
        v_109_6 = _emit_node(fv_109_6);
    } else {
        v_109_6 = _py_none();
    }
    PyDict_SetItem(d_h, _mat_keys[42], v_109_6);
    Py_DecRef(v_109_6);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_MatchArch(nd: MatchArch) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[110], _mat_classes[110]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_110_0 = nd.kid;
    v_110_0 = PyList_New(len(fv_110_0));
    li_110_0l = 0;
    for it_110_0l in fv_110_0 {
        e_110_0l = _emit_node(it_110_0l);
        PyList_SetItem(v_110_0, li_110_0l, e_110_0l);
        li_110_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_110_0);
    Py_DecRef(v_110_0);

    fv_110_1 = nd.parent;
    if fv_110_1 is None {
        v_110_1 = _py_none();
    } else {
        v_110_1 = _emit_node(fv_110_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_110_1);
    Py_DecRef(v_110_1);

    v_110_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_110_2);
    Py_DecRef(v_110_2);

    fv_110_3 = nd._in_mod_nodes;
    v_110_3 = PyList_New(len(fv_110_3));
    li_110_3l = 0;
    for it_110_3l in fv_110_3 {
        e_110_3l = _emit_node(it_110_3l);
        PyList_SetItem(v_110_3, li_110_3l, e_110_3l);
        li_110_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_110_3);
    Py_DecRef(v_110_3);

    v_110_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_110_4);
    Py_DecRef(v_110_4);

    fv_110_5 = nd.loc;
    v_110_5 = _emit_CodeLocInfo(fv_110_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_110_5);
    Py_DecRef(v_110_5);

    fv_110_6 = nd.name;
    if isinstance(fv_110_6, AtomTrailer) {
        v_110_6 = _emit_node(fv_110_6);
    } elif isinstance(fv_110_6, NameAtom) {
        v_110_6 = _emit_node(fv_110_6);
    } else {
        v_110_6 = _py_none();
    }
    PyDict_SetItem(d_h, _mat_keys[24], v_110_6);
    Py_DecRef(v_110_6);

    fv_110_7 = nd.arg_patterns;
    if fv_110_7 is None {
        v_110_7 = _py_none();
    } else {
        v_110_7 = PyList_New(len(fv_110_7));
        li_110_7l = 0;
        for it_110_7l in fv_110_7 {
            e_110_7l = _emit_node(it_110_7l);
            PyList_SetItem(v_110_7, li_110_7l, e_110_7l);
            li_110_7l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[171], v_110_7);
    Py_DecRef(v_110_7);

    fv_110_8 = nd.kw_patterns;
    if fv_110_8 is None {
        v_110_8 = _py_none();
    } else {
        v_110_8 = PyList_New(len(fv_110_8));
        li_110_8l = 0;
        for it_110_8l in fv_110_8 {
            e_110_8l = _emit_node(it_110_8l);
            PyList_SetItem(v_110_8, li_110_8l, e_110_8l);
            li_110_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[172], v_110_8);
    Py_DecRef(v_110_8);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_MatchAs(nd: MatchAs) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[111], _mat_classes[111]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_111_0 = nd.kid;
    v_111_0 = PyList_New(len(fv_111_0));
    li_111_0l = 0;
    for it_111_0l in fv_111_0 {
        e_111_0l = _emit_node(it_111_0l);
        PyList_SetItem(v_111_0, li_111_0l, e_111_0l);
        li_111_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_111_0);
    Py_DecRef(v_111_0);

    fv_111_1 = nd.parent;
    if fv_111_1 is None {
        v_111_1 = _py_none();
    } else {
        v_111_1 = _emit_node(fv_111_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_111_1);
    Py_DecRef(v_111_1);

    v_111_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_111_2);
    Py_DecRef(v_111_2);

    fv_111_3 = nd._in_mod_nodes;
    v_111_3 = PyList_New(len(fv_111_3));
    li_111_3l = 0;
    for it_111_3l in fv_111_3 {
        e_111_3l = _emit_node(it_111_3l);
        PyList_SetItem(v_111_3, li_111_3l, e_111_3l);
        li_111_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_111_3);
    Py_DecRef(v_111_3);

    v_111_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_111_4);
    Py_DecRef(v_111_4);

    fv_111_5 = nd.loc;
    v_111_5 = _emit_CodeLocInfo(fv_111_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_111_5);
    Py_DecRef(v_111_5);

    fv_111_6 = nd.name;
    v_111_6 = _emit_node(fv_111_6);
    PyDict_SetItem(d_h, _mat_keys[24], v_111_6);
    Py_DecRef(v_111_6);

    fv_111_7 = nd.pattern;
    if fv_111_7 is None {
        v_111_7 = _py_none();
    } else {
        v_111_7 = _emit_node(fv_111_7);
    }
    PyDict_SetItem(d_h, _mat_keys[121], v_111_7);
    Py_DecRef(v_111_7);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_MatchKVPair(nd: MatchKVPair) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[112], _mat_classes[112]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_112_0 = nd.kid;
    v_112_0 = PyList_New(len(fv_112_0));
    li_112_0l = 0;
    for it_112_0l in fv_112_0 {
        e_112_0l = _emit_node(it_112_0l);
        PyList_SetItem(v_112_0, li_112_0l, e_112_0l);
        li_112_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_112_0);
    Py_DecRef(v_112_0);

    fv_112_1 = nd.parent;
    if fv_112_1 is None {
        v_112_1 = _py_none();
    } else {
        v_112_1 = _emit_node(fv_112_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_112_1);
    Py_DecRef(v_112_1);

    v_112_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_112_2);
    Py_DecRef(v_112_2);

    fv_112_3 = nd._in_mod_nodes;
    v_112_3 = PyList_New(len(fv_112_3));
    li_112_3l = 0;
    for it_112_3l in fv_112_3 {
        e_112_3l = _emit_node(it_112_3l);
        PyList_SetItem(v_112_3, li_112_3l, e_112_3l);
        li_112_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_112_3);
    Py_DecRef(v_112_3);

    v_112_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_112_4);
    Py_DecRef(v_112_4);

    fv_112_5 = nd.loc;
    v_112_5 = _emit_CodeLocInfo(fv_112_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_112_5);
    Py_DecRef(v_112_5);

    fv_112_6 = nd.key;
    if isinstance(fv_112_6, MatchPattern) {
        v_112_6 = _emit_node(fv_112_6);
    } elif isinstance(fv_112_6, NameAtom) {
        v_112_6 = _emit_node(fv_112_6);
    } elif isinstance(fv_112_6, AtomExpr) {
        v_112_6 = _emit_node(fv_112_6);
    } else {
        v_112_6 = _py_none();
    }
    PyDict_SetItem(d_h, _mat_keys[173], v_112_6);
    Py_DecRef(v_112_6);

    fv_112_7 = nd.value;
    v_112_7 = _emit_node(fv_112_7);
    PyDict_SetItem(d_h, _mat_keys[42], v_112_7);
    Py_DecRef(v_112_7);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_MatchMapping(nd: MatchMapping) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[113], _mat_classes[113]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_113_0 = nd.kid;
    v_113_0 = PyList_New(len(fv_113_0));
    li_113_0l = 0;
    for it_113_0l in fv_113_0 {
        e_113_0l = _emit_node(it_113_0l);
        PyList_SetItem(v_113_0, li_113_0l, e_113_0l);
        li_113_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_113_0);
    Py_DecRef(v_113_0);

    fv_113_1 = nd.parent;
    if fv_113_1 is None {
        v_113_1 = _py_none();
    } else {
        v_113_1 = _emit_node(fv_113_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_113_1);
    Py_DecRef(v_113_1);

    v_113_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_113_2);
    Py_DecRef(v_113_2);

    fv_113_3 = nd._in_mod_nodes;
    v_113_3 = PyList_New(len(fv_113_3));
    li_113_3l = 0;
    for it_113_3l in fv_113_3 {
        e_113_3l = _emit_node(it_113_3l);
        PyList_SetItem(v_113_3, li_113_3l, e_113_3l);
        li_113_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_113_3);
    Py_DecRef(v_113_3);

    v_113_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_113_4);
    Py_DecRef(v_113_4);

    fv_113_5 = nd.loc;
    v_113_5 = _emit_CodeLocInfo(fv_113_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_113_5);
    Py_DecRef(v_113_5);

    fv_113_6 = nd.values;
    v_113_6 = PyList_New(len(fv_113_6));
    li_113_6l = 0;
    for it_113_6l in fv_113_6 {
        e_113_6l = _emit_node(it_113_6l);
        PyList_SetItem(v_113_6, li_113_6l, e_113_6l);
        li_113_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[108], v_113_6);
    Py_DecRef(v_113_6);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_MatchOr(nd: MatchOr) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[114], _mat_classes[114]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_114_0 = nd.kid;
    v_114_0 = PyList_New(len(fv_114_0));
    li_114_0l = 0;
    for it_114_0l in fv_114_0 {
        e_114_0l = _emit_node(it_114_0l);
        PyList_SetItem(v_114_0, li_114_0l, e_114_0l);
        li_114_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_114_0);
    Py_DecRef(v_114_0);

    fv_114_1 = nd.parent;
    if fv_114_1 is None {
        v_114_1 = _py_none();
    } else {
        v_114_1 = _emit_node(fv_114_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_114_1);
    Py_DecRef(v_114_1);

    v_114_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_114_2);
    Py_DecRef(v_114_2);

    fv_114_3 = nd._in_mod_nodes;
    v_114_3 = PyList_New(len(fv_114_3));
    li_114_3l = 0;
    for it_114_3l in fv_114_3 {
        e_114_3l = _emit_node(it_114_3l);
        PyList_SetItem(v_114_3, li_114_3l, e_114_3l);
        li_114_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_114_3);
    Py_DecRef(v_114_3);

    v_114_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_114_4);
    Py_DecRef(v_114_4);

    fv_114_5 = nd.loc;
    v_114_5 = _emit_CodeLocInfo(fv_114_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_114_5);
    Py_DecRef(v_114_5);

    fv_114_6 = nd.patterns;
    v_114_6 = PyList_New(len(fv_114_6));
    li_114_6l = 0;
    for it_114_6l in fv_114_6 {
        e_114_6l = _emit_node(it_114_6l);
        PyList_SetItem(v_114_6, li_114_6l, e_114_6l);
        li_114_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[174], v_114_6);
    Py_DecRef(v_114_6);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_MatchSequence(nd: MatchSequence) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[115], _mat_classes[115]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_115_0 = nd.kid;
    v_115_0 = PyList_New(len(fv_115_0));
    li_115_0l = 0;
    for it_115_0l in fv_115_0 {
        e_115_0l = _emit_node(it_115_0l);
        PyList_SetItem(v_115_0, li_115_0l, e_115_0l);
        li_115_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_115_0);
    Py_DecRef(v_115_0);

    fv_115_1 = nd.parent;
    if fv_115_1 is None {
        v_115_1 = _py_none();
    } else {
        v_115_1 = _emit_node(fv_115_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_115_1);
    Py_DecRef(v_115_1);

    v_115_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_115_2);
    Py_DecRef(v_115_2);

    fv_115_3 = nd._in_mod_nodes;
    v_115_3 = PyList_New(len(fv_115_3));
    li_115_3l = 0;
    for it_115_3l in fv_115_3 {
        e_115_3l = _emit_node(it_115_3l);
        PyList_SetItem(v_115_3, li_115_3l, e_115_3l);
        li_115_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_115_3);
    Py_DecRef(v_115_3);

    v_115_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_115_4);
    Py_DecRef(v_115_4);

    fv_115_5 = nd.loc;
    v_115_5 = _emit_CodeLocInfo(fv_115_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_115_5);
    Py_DecRef(v_115_5);

    fv_115_6 = nd.values;
    v_115_6 = PyList_New(len(fv_115_6));
    li_115_6l = 0;
    for it_115_6l in fv_115_6 {
        e_115_6l = _emit_node(it_115_6l);
        PyList_SetItem(v_115_6, li_115_6l, e_115_6l);
        li_115_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[108], v_115_6);
    Py_DecRef(v_115_6);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_MatchSingleton(nd: MatchSingleton) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[116], _mat_classes[116]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_116_0 = nd.kid;
    v_116_0 = PyList_New(len(fv_116_0));
    li_116_0l = 0;
    for it_116_0l in fv_116_0 {
        e_116_0l = _emit_node(it_116_0l);
        PyList_SetItem(v_116_0, li_116_0l, e_116_0l);
        li_116_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_116_0);
    Py_DecRef(v_116_0);

    fv_116_1 = nd.parent;
    if fv_116_1 is None {
        v_116_1 = _py_none();
    } else {
        v_116_1 = _emit_node(fv_116_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_116_1);
    Py_DecRef(v_116_1);

    v_116_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_116_2);
    Py_DecRef(v_116_2);

    fv_116_3 = nd._in_mod_nodes;
    v_116_3 = PyList_New(len(fv_116_3));
    li_116_3l = 0;
    for it_116_3l in fv_116_3 {
        e_116_3l = _emit_node(it_116_3l);
        PyList_SetItem(v_116_3, li_116_3l, e_116_3l);
        li_116_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_116_3);
    Py_DecRef(v_116_3);

    v_116_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_116_4);
    Py_DecRef(v_116_4);

    fv_116_5 = nd.loc;
    v_116_5 = _emit_CodeLocInfo(fv_116_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_116_5);
    Py_DecRef(v_116_5);

    fv_116_6 = nd.value;
    if isinstance(fv_116_6, Bool) {
        v_116_6 = _emit_node(fv_116_6);
    } elif isinstance(fv_116_6, Null) {
        v_116_6 = _emit_node(fv_116_6);
    } else {
        v_116_6 = _py_none();
    }
    PyDict_SetItem(d_h, _mat_keys[42], v_116_6);
    Py_DecRef(v_116_6);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_MatchStar(nd: MatchStar) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[117], _mat_classes[117]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_117_0 = nd.kid;
    v_117_0 = PyList_New(len(fv_117_0));
    li_117_0l = 0;
    for it_117_0l in fv_117_0 {
        e_117_0l = _emit_node(it_117_0l);
        PyList_SetItem(v_117_0, li_117_0l, e_117_0l);
        li_117_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_117_0);
    Py_DecRef(v_117_0);

    fv_117_1 = nd.parent;
    if fv_117_1 is None {
        v_117_1 = _py_none();
    } else {
        v_117_1 = _emit_node(fv_117_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_117_1);
    Py_DecRef(v_117_1);

    v_117_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_117_2);
    Py_DecRef(v_117_2);

    fv_117_3 = nd._in_mod_nodes;
    v_117_3 = PyList_New(len(fv_117_3));
    li_117_3l = 0;
    for it_117_3l in fv_117_3 {
        e_117_3l = _emit_node(it_117_3l);
        PyList_SetItem(v_117_3, li_117_3l, e_117_3l);
        li_117_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_117_3);
    Py_DecRef(v_117_3);

    v_117_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_117_4);
    Py_DecRef(v_117_4);

    fv_117_5 = nd.loc;
    v_117_5 = _emit_CodeLocInfo(fv_117_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_117_5);
    Py_DecRef(v_117_5);

    fv_117_6 = nd.name;
    v_117_6 = _emit_node(fv_117_6);
    PyDict_SetItem(d_h, _mat_keys[24], v_117_6);
    Py_DecRef(v_117_6);

    fv_117_7 = nd.is_list;
    v_117_7 = PyBool_FromLong(1 if fv_117_7 else 0);
    PyDict_SetItem(d_h, _mat_keys[175], v_117_7);
    Py_DecRef(v_117_7);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_MatchValue(nd: MatchValue) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[118], _mat_classes[118]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_118_0 = nd.kid;
    v_118_0 = PyList_New(len(fv_118_0));
    li_118_0l = 0;
    for it_118_0l in fv_118_0 {
        e_118_0l = _emit_node(it_118_0l);
        PyList_SetItem(v_118_0, li_118_0l, e_118_0l);
        li_118_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_118_0);
    Py_DecRef(v_118_0);

    fv_118_1 = nd.parent;
    if fv_118_1 is None {
        v_118_1 = _py_none();
    } else {
        v_118_1 = _emit_node(fv_118_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_118_1);
    Py_DecRef(v_118_1);

    v_118_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_118_2);
    Py_DecRef(v_118_2);

    fv_118_3 = nd._in_mod_nodes;
    v_118_3 = PyList_New(len(fv_118_3));
    li_118_3l = 0;
    for it_118_3l in fv_118_3 {
        e_118_3l = _emit_node(it_118_3l);
        PyList_SetItem(v_118_3, li_118_3l, e_118_3l);
        li_118_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_118_3);
    Py_DecRef(v_118_3);

    v_118_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_118_4);
    Py_DecRef(v_118_4);

    fv_118_5 = nd.loc;
    v_118_5 = _emit_CodeLocInfo(fv_118_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_118_5);
    Py_DecRef(v_118_5);

    fv_118_6 = nd.value;
    v_118_6 = _emit_node(fv_118_6);
    PyDict_SetItem(d_h, _mat_keys[42], v_118_6);
    Py_DecRef(v_118_6);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_MatchWild(nd: MatchWild) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[119], _mat_classes[119]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_119_0 = nd.kid;
    v_119_0 = PyList_New(len(fv_119_0));
    li_119_0l = 0;
    for it_119_0l in fv_119_0 {
        e_119_0l = _emit_node(it_119_0l);
        PyList_SetItem(v_119_0, li_119_0l, e_119_0l);
        li_119_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_119_0);
    Py_DecRef(v_119_0);

    fv_119_1 = nd.parent;
    if fv_119_1 is None {
        v_119_1 = _py_none();
    } else {
        v_119_1 = _emit_node(fv_119_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_119_1);
    Py_DecRef(v_119_1);

    v_119_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_119_2);
    Py_DecRef(v_119_2);

    fv_119_3 = nd._in_mod_nodes;
    v_119_3 = PyList_New(len(fv_119_3));
    li_119_3l = 0;
    for it_119_3l in fv_119_3 {
        e_119_3l = _emit_node(it_119_3l);
        PyList_SetItem(v_119_3, li_119_3l, e_119_3l);
        li_119_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_119_3);
    Py_DecRef(v_119_3);

    v_119_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_119_4);
    Py_DecRef(v_119_4);

    fv_119_5 = nd.loc;
    v_119_5 = _emit_CodeLocInfo(fv_119_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_119_5);
    Py_DecRef(v_119_5);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_SubTag(nd: SubTag) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[120], _mat_classes[120]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_120_0 = nd.kid;
    v_120_0 = PyList_New(len(fv_120_0));
    li_120_0l = 0;
    for it_120_0l in fv_120_0 {
        e_120_0l = _emit_node(it_120_0l);
        PyList_SetItem(v_120_0, li_120_0l, e_120_0l);
        li_120_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_120_0);
    Py_DecRef(v_120_0);

    fv_120_1 = nd.parent;
    if fv_120_1 is None {
        v_120_1 = _py_none();
    } else {
        v_120_1 = _emit_node(fv_120_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_120_1);
    Py_DecRef(v_120_1);

    v_120_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_120_2);
    Py_DecRef(v_120_2);

    fv_120_3 = nd._in_mod_nodes;
    v_120_3 = PyList_New(len(fv_120_3));
    li_120_3l = 0;
    for it_120_3l in fv_120_3 {
        e_120_3l = _emit_node(it_120_3l);
        PyList_SetItem(v_120_3, li_120_3l, e_120_3l);
        li_120_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_120_3);
    Py_DecRef(v_120_3);

    v_120_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_120_4);
    Py_DecRef(v_120_4);

    fv_120_5 = nd.loc;
    v_120_5 = _emit_CodeLocInfo(fv_120_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_120_5);
    Py_DecRef(v_120_5);

    v_120_6 = _emit_node(nd.kid[len(nd.kid) - 1]);
    PyDict_SetItem(d_h, _mat_keys[176], v_120_6);
    Py_DecRef(v_120_6);

    fv_120_7 = nd.ownership;
    v_120_7 = _enum_OwnershipKind(fv_120_7);
    PyDict_SetItem(d_h, _mat_keys[177], v_120_7);
    Py_DecRef(v_120_7);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_TypeParam(nd: TypeParam) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[121], _mat_classes[121]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_121_0 = nd.kid;
    v_121_0 = PyList_New(len(fv_121_0));
    li_121_0l = 0;
    for it_121_0l in fv_121_0 {
        e_121_0l = _emit_node(it_121_0l);
        PyList_SetItem(v_121_0, li_121_0l, e_121_0l);
        li_121_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_121_0);
    Py_DecRef(v_121_0);

    fv_121_1 = nd.parent;
    if fv_121_1 is None {
        v_121_1 = _py_none();
    } else {
        v_121_1 = _emit_node(fv_121_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_121_1);
    Py_DecRef(v_121_1);

    v_121_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_121_2);
    Py_DecRef(v_121_2);

    fv_121_3 = nd._in_mod_nodes;
    v_121_3 = PyList_New(len(fv_121_3));
    li_121_3l = 0;
    for it_121_3l in fv_121_3 {
        e_121_3l = _emit_node(it_121_3l);
        PyList_SetItem(v_121_3, li_121_3l, e_121_3l);
        li_121_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_121_3);
    Py_DecRef(v_121_3);

    v_121_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_121_4);
    Py_DecRef(v_121_4);

    fv_121_5 = nd.loc;
    v_121_5 = _emit_CodeLocInfo(fv_121_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_121_5);
    Py_DecRef(v_121_5);

    fv_121_6 = nd.name_spec;
    v_121_6 = _emit_node(fv_121_6);
    PyDict_SetItem(d_h, _mat_keys[12], v_121_6);
    Py_DecRef(v_121_6);

    fv_121_7 = nd.semstr;
    v_121_7 = _py_str(fv_121_7);
    PyDict_SetItem(d_h, _mat_keys[13], v_121_7);
    Py_DecRef(v_121_7);

    fv_121_8 = nd.name;
    v_121_8 = _emit_node(fv_121_8);
    PyDict_SetItem(d_h, _mat_keys[24], v_121_8);
    Py_DecRef(v_121_8);

    fv_121_9 = nd.bound;
    if fv_121_9 is None {
        v_121_9 = _py_none();
    } else {
        v_121_9 = _emit_node(fv_121_9);
    }
    PyDict_SetItem(d_h, _mat_keys[178], v_121_9);
    Py_DecRef(v_121_9);

    fv_121_10 = nd.default_val;
    if fv_121_10 is None {
        v_121_10 = _py_none();
    } else {
        v_121_10 = _emit_node(fv_121_10);
    }
    PyDict_SetItem(d_h, _mat_keys[179], v_121_10);
    Py_DecRef(v_121_10);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_UnaryExpr(nd: UnaryExpr) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[122], _mat_classes[122]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_122_0 = nd.kid;
    v_122_0 = PyList_New(len(fv_122_0));
    li_122_0l = 0;
    for it_122_0l in fv_122_0 {
        e_122_0l = _emit_node(it_122_0l);
        PyList_SetItem(v_122_0, li_122_0l, e_122_0l);
        li_122_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_122_0);
    Py_DecRef(v_122_0);

    fv_122_1 = nd.parent;
    if fv_122_1 is None {
        v_122_1 = _py_none();
    } else {
        v_122_1 = _emit_node(fv_122_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_122_1);
    Py_DecRef(v_122_1);

    v_122_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_122_2);
    Py_DecRef(v_122_2);

    fv_122_3 = nd._in_mod_nodes;
    v_122_3 = PyList_New(len(fv_122_3));
    li_122_3l = 0;
    for it_122_3l in fv_122_3 {
        e_122_3l = _emit_node(it_122_3l);
        PyList_SetItem(v_122_3, li_122_3l, e_122_3l);
        li_122_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_122_3);
    Py_DecRef(v_122_3);

    v_122_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_122_4);
    Py_DecRef(v_122_4);

    fv_122_5 = nd.loc;
    v_122_5 = _emit_CodeLocInfo(fv_122_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_122_5);
    Py_DecRef(v_122_5);

    fv_122_6 = nd._type_sym_tab;
    if fv_122_6 is None {
        v_122_6 = _py_none();
    } else {
        v_122_6 = _emit_node(fv_122_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_122_6);
    Py_DecRef(v_122_6);

    v_122_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_122_7);
    Py_DecRef(v_122_7);

    fv_122_8 = nd.attached_tokens;
    if fv_122_8 is None {
        v_122_8 = _py_none();
    } else {
        v_122_8 = PyList_New(len(fv_122_8));
        li_122_8l = 0;
        for it_122_8l in fv_122_8 {
            e_122_8l = _emit_node(it_122_8l);
            PyList_SetItem(v_122_8, li_122_8l, e_122_8l);
            li_122_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_122_8);
    Py_DecRef(v_122_8);

    fv_122_9 = nd.operand;
    v_122_9 = _emit_node(fv_122_9);
    PyDict_SetItem(d_h, _mat_keys[180], v_122_9);
    Py_DecRef(v_122_9);

    fv_122_10 = nd.op;
    v_122_10 = _emit_node(fv_122_10);
    PyDict_SetItem(d_h, _mat_keys[152], v_122_10);
    Py_DecRef(v_122_10);

    fv_122_11 = nd.ownership;
    v_122_11 = _enum_OwnershipKind(fv_122_11);
    PyDict_SetItem(d_h, _mat_keys[177], v_122_11);
    Py_DecRef(v_122_11);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_YieldExpr(nd: YieldExpr) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[123], _mat_classes[123]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_123_0 = nd.kid;
    v_123_0 = PyList_New(len(fv_123_0));
    li_123_0l = 0;
    for it_123_0l in fv_123_0 {
        e_123_0l = _emit_node(it_123_0l);
        PyList_SetItem(v_123_0, li_123_0l, e_123_0l);
        li_123_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_123_0);
    Py_DecRef(v_123_0);

    fv_123_1 = nd.parent;
    if fv_123_1 is None {
        v_123_1 = _py_none();
    } else {
        v_123_1 = _emit_node(fv_123_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_123_1);
    Py_DecRef(v_123_1);

    v_123_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_123_2);
    Py_DecRef(v_123_2);

    fv_123_3 = nd._in_mod_nodes;
    v_123_3 = PyList_New(len(fv_123_3));
    li_123_3l = 0;
    for it_123_3l in fv_123_3 {
        e_123_3l = _emit_node(it_123_3l);
        PyList_SetItem(v_123_3, li_123_3l, e_123_3l);
        li_123_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_123_3);
    Py_DecRef(v_123_3);

    v_123_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_123_4);
    Py_DecRef(v_123_4);

    fv_123_5 = nd.loc;
    v_123_5 = _emit_CodeLocInfo(fv_123_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_123_5);
    Py_DecRef(v_123_5);

    fv_123_6 = nd._type_sym_tab;
    if fv_123_6 is None {
        v_123_6 = _py_none();
    } else {
        v_123_6 = _emit_node(fv_123_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_123_6);
    Py_DecRef(v_123_6);

    v_123_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_123_7);
    Py_DecRef(v_123_7);

    fv_123_8 = nd.attached_tokens;
    if fv_123_8 is None {
        v_123_8 = _py_none();
    } else {
        v_123_8 = PyList_New(len(fv_123_8));
        li_123_8l = 0;
        for it_123_8l in fv_123_8 {
            e_123_8l = _emit_node(it_123_8l);
            PyList_SetItem(v_123_8, li_123_8l, e_123_8l);
            li_123_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_123_8);
    Py_DecRef(v_123_8);

    fv_123_9 = nd.expr;
    if fv_123_9 is None {
        v_123_9 = _py_none();
    } else {
        v_123_9 = _emit_node(fv_123_9);
    }
    PyDict_SetItem(d_h, _mat_keys[118], v_123_9);
    Py_DecRef(v_123_9);

    fv_123_10 = nd.with_from;
    v_123_10 = PyBool_FromLong(1 if fv_123_10 else 0);
    PyDict_SetItem(d_h, _mat_keys[181], v_123_10);
    Py_DecRef(v_123_10);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_Token(nd: Token) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[124], _mat_classes[124]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_124_0 = nd.kid;
    v_124_0 = PyList_New(len(fv_124_0));
    li_124_0l = 0;
    for it_124_0l in fv_124_0 {
        e_124_0l = _emit_node(it_124_0l);
        PyList_SetItem(v_124_0, li_124_0l, e_124_0l);
        li_124_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_124_0);
    Py_DecRef(v_124_0);

    fv_124_1 = nd.parent;
    if fv_124_1 is None {
        v_124_1 = _py_none();
    } else {
        v_124_1 = _emit_node(fv_124_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_124_1);
    Py_DecRef(v_124_1);

    v_124_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_124_2);
    Py_DecRef(v_124_2);

    fv_124_3 = nd._in_mod_nodes;
    v_124_3 = PyList_New(len(fv_124_3));
    li_124_3l = 0;
    for it_124_3l in fv_124_3 {
        e_124_3l = _emit_node(it_124_3l);
        PyList_SetItem(v_124_3, li_124_3l, e_124_3l);
        li_124_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_124_3);
    Py_DecRef(v_124_3);

    v_124_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_124_4);
    Py_DecRef(v_124_4);

    fv_124_5 = nd.loc;
    v_124_5 = _emit_CodeLocInfo(fv_124_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_124_5);
    Py_DecRef(v_124_5);

    fv_124_6 = nd.orig_src;
    v_124_6 = _emit_node(fv_124_6);
    PyDict_SetItem(d_h, _mat_keys[41], v_124_6);
    Py_DecRef(v_124_6);

    fv_124_7 = nd.name;
    v_124_7 = _py_str(fv_124_7);
    PyDict_SetItem(d_h, _mat_keys[24], v_124_7);
    Py_DecRef(v_124_7);

    fv_124_8 = nd.value;
    v_124_8 = _py_str(fv_124_8);
    PyDict_SetItem(d_h, _mat_keys[42], v_124_8);
    Py_DecRef(v_124_8);

    fv_124_9 = nd.line_no;
    v_124_9 = PyLong_FromLongLong(fv_124_9);
    PyDict_SetItem(d_h, _mat_keys[43], v_124_9);
    Py_DecRef(v_124_9);

    fv_124_10 = nd.end_line;
    v_124_10 = PyLong_FromLongLong(fv_124_10);
    PyDict_SetItem(d_h, _mat_keys[44], v_124_10);
    Py_DecRef(v_124_10);

    fv_124_11 = nd.c_start;
    v_124_11 = PyLong_FromLongLong(fv_124_11);
    PyDict_SetItem(d_h, _mat_keys[45], v_124_11);
    Py_DecRef(v_124_11);

    fv_124_12 = nd.c_end;
    v_124_12 = PyLong_FromLongLong(fv_124_12);
    PyDict_SetItem(d_h, _mat_keys[46], v_124_12);
    Py_DecRef(v_124_12);

    fv_124_13 = nd.pos_start;
    v_124_13 = PyLong_FromLongLong(fv_124_13);
    PyDict_SetItem(d_h, _mat_keys[47], v_124_13);
    Py_DecRef(v_124_13);

    fv_124_14 = nd.pos_end;
    v_124_14 = PyLong_FromLongLong(fv_124_14);
    PyDict_SetItem(d_h, _mat_keys[48], v_124_14);
    Py_DecRef(v_124_14);

    fv_124_15 = nd._is_synthetic;
    v_124_15 = PyBool_FromLong(1 if fv_124_15 else 0);
    PyDict_SetItem(d_h, _mat_keys[49], v_124_15);
    Py_DecRef(v_124_15);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ArchBlockStmt(nd: ArchBlockStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[125], _mat_classes[125]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_125_0 = nd.kid;
    v_125_0 = PyList_New(len(fv_125_0));
    li_125_0l = 0;
    for it_125_0l in fv_125_0 {
        e_125_0l = _emit_node(it_125_0l);
        PyList_SetItem(v_125_0, li_125_0l, e_125_0l);
        li_125_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_125_0);
    Py_DecRef(v_125_0);

    fv_125_1 = nd.parent;
    if fv_125_1 is None {
        v_125_1 = _py_none();
    } else {
        v_125_1 = _emit_node(fv_125_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_125_1);
    Py_DecRef(v_125_1);

    v_125_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_125_2);
    Py_DecRef(v_125_2);

    fv_125_3 = nd._in_mod_nodes;
    v_125_3 = PyList_New(len(fv_125_3));
    li_125_3l = 0;
    for it_125_3l in fv_125_3 {
        e_125_3l = _emit_node(it_125_3l);
        PyList_SetItem(v_125_3, li_125_3l, e_125_3l);
        li_125_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_125_3);
    Py_DecRef(v_125_3);

    v_125_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_125_4);
    Py_DecRef(v_125_4);

    fv_125_5 = nd.loc;
    v_125_5 = _emit_CodeLocInfo(fv_125_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_125_5);
    Py_DecRef(v_125_5);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_AstAccessNode(nd: AstAccessNode) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[126], _mat_classes[126]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_126_0 = nd.kid;
    v_126_0 = PyList_New(len(fv_126_0));
    li_126_0l = 0;
    for it_126_0l in fv_126_0 {
        e_126_0l = _emit_node(it_126_0l);
        PyList_SetItem(v_126_0, li_126_0l, e_126_0l);
        li_126_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_126_0);
    Py_DecRef(v_126_0);

    fv_126_1 = nd.parent;
    if fv_126_1 is None {
        v_126_1 = _py_none();
    } else {
        v_126_1 = _emit_node(fv_126_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_126_1);
    Py_DecRef(v_126_1);

    v_126_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_126_2);
    Py_DecRef(v_126_2);

    fv_126_3 = nd._in_mod_nodes;
    v_126_3 = PyList_New(len(fv_126_3));
    li_126_3l = 0;
    for it_126_3l in fv_126_3 {
        e_126_3l = _emit_node(it_126_3l);
        PyList_SetItem(v_126_3, li_126_3l, e_126_3l);
        li_126_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_126_3);
    Py_DecRef(v_126_3);

    v_126_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_126_4);
    Py_DecRef(v_126_4);

    fv_126_5 = nd.loc;
    v_126_5 = _emit_CodeLocInfo(fv_126_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_126_5);
    Py_DecRef(v_126_5);

    fv_126_6 = nd.access;
    if fv_126_6 is None {
        v_126_6 = _py_none();
    } else {
        v_126_6 = _emit_node(fv_126_6);
    }
    PyDict_SetItem(d_h, _mat_keys[16], v_126_6);
    Py_DecRef(v_126_6);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_AstAsyncNode(nd: AstAsyncNode) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[127], _mat_classes[127]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_127_0 = nd.kid;
    v_127_0 = PyList_New(len(fv_127_0));
    li_127_0l = 0;
    for it_127_0l in fv_127_0 {
        e_127_0l = _emit_node(it_127_0l);
        PyList_SetItem(v_127_0, li_127_0l, e_127_0l);
        li_127_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_127_0);
    Py_DecRef(v_127_0);

    fv_127_1 = nd.parent;
    if fv_127_1 is None {
        v_127_1 = _py_none();
    } else {
        v_127_1 = _emit_node(fv_127_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_127_1);
    Py_DecRef(v_127_1);

    v_127_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_127_2);
    Py_DecRef(v_127_2);

    fv_127_3 = nd._in_mod_nodes;
    v_127_3 = PyList_New(len(fv_127_3));
    li_127_3l = 0;
    for it_127_3l in fv_127_3 {
        e_127_3l = _emit_node(it_127_3l);
        PyList_SetItem(v_127_3, li_127_3l, e_127_3l);
        li_127_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_127_3);
    Py_DecRef(v_127_3);

    v_127_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_127_4);
    Py_DecRef(v_127_4);

    fv_127_5 = nd.loc;
    v_127_5 = _emit_CodeLocInfo(fv_127_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_127_5);
    Py_DecRef(v_127_5);

    fv_127_6 = nd.is_async;
    v_127_6 = PyBool_FromLong(1 if fv_127_6 else 0);
    PyDict_SetItem(d_h, _mat_keys[14], v_127_6);
    Py_DecRef(v_127_6);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_AstDocNode(nd: AstDocNode) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[128], _mat_classes[128]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_128_0 = nd.kid;
    v_128_0 = PyList_New(len(fv_128_0));
    li_128_0l = 0;
    for it_128_0l in fv_128_0 {
        e_128_0l = _emit_node(it_128_0l);
        PyList_SetItem(v_128_0, li_128_0l, e_128_0l);
        li_128_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_128_0);
    Py_DecRef(v_128_0);

    fv_128_1 = nd.parent;
    if fv_128_1 is None {
        v_128_1 = _py_none();
    } else {
        v_128_1 = _emit_node(fv_128_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_128_1);
    Py_DecRef(v_128_1);

    v_128_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_128_2);
    Py_DecRef(v_128_2);

    fv_128_3 = nd._in_mod_nodes;
    v_128_3 = PyList_New(len(fv_128_3));
    li_128_3l = 0;
    for it_128_3l in fv_128_3 {
        e_128_3l = _emit_node(it_128_3l);
        PyList_SetItem(v_128_3, li_128_3l, e_128_3l);
        li_128_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_128_3);
    Py_DecRef(v_128_3);

    v_128_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_128_4);
    Py_DecRef(v_128_4);

    fv_128_5 = nd.loc;
    v_128_5 = _emit_CodeLocInfo(fv_128_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_128_5);
    Py_DecRef(v_128_5);

    fv_128_6 = nd.doc;
    if fv_128_6 is None {
        v_128_6 = _py_none();
    } else {
        v_128_6 = _emit_node(fv_128_6);
    }
    PyDict_SetItem(d_h, _mat_keys[8], v_128_6);
    Py_DecRef(v_128_6);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_AstElseBodyNode(nd: AstElseBodyNode) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[129], _mat_classes[129]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_129_0 = nd.kid;
    v_129_0 = PyList_New(len(fv_129_0));
    li_129_0l = 0;
    for it_129_0l in fv_129_0 {
        e_129_0l = _emit_node(it_129_0l);
        PyList_SetItem(v_129_0, li_129_0l, e_129_0l);
        li_129_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_129_0);
    Py_DecRef(v_129_0);

    fv_129_1 = nd.parent;
    if fv_129_1 is None {
        v_129_1 = _py_none();
    } else {
        v_129_1 = _emit_node(fv_129_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_129_1);
    Py_DecRef(v_129_1);

    v_129_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_129_2);
    Py_DecRef(v_129_2);

    fv_129_3 = nd._in_mod_nodes;
    v_129_3 = PyList_New(len(fv_129_3));
    li_129_3l = 0;
    for it_129_3l in fv_129_3 {
        e_129_3l = _emit_node(it_129_3l);
        PyList_SetItem(v_129_3, li_129_3l, e_129_3l);
        li_129_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_129_3);
    Py_DecRef(v_129_3);

    v_129_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_129_4);
    Py_DecRef(v_129_4);

    fv_129_5 = nd.loc;
    v_129_5 = _emit_CodeLocInfo(fv_129_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_129_5);
    Py_DecRef(v_129_5);

    fv_129_6 = nd.else_body;
    if fv_129_6 is None {
        v_129_6 = _py_none();
    } else {
        if isinstance(fv_129_6, ElseStmt) {
            v_129_6 = _emit_node(fv_129_6);
        } elif isinstance(fv_129_6, ElseIf) {
            v_129_6 = _emit_node(fv_129_6);
        } else {
            v_129_6 = _py_none();
        }
    }
    PyDict_SetItem(d_h, _mat_keys[76], v_129_6);
    Py_DecRef(v_129_6);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_AstSymbolNode(nd: AstSymbolNode) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[130], _mat_classes[130]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_130_0 = nd.kid;
    v_130_0 = PyList_New(len(fv_130_0));
    li_130_0l = 0;
    for it_130_0l in fv_130_0 {
        e_130_0l = _emit_node(it_130_0l);
        PyList_SetItem(v_130_0, li_130_0l, e_130_0l);
        li_130_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_130_0);
    Py_DecRef(v_130_0);

    fv_130_1 = nd.parent;
    if fv_130_1 is None {
        v_130_1 = _py_none();
    } else {
        v_130_1 = _emit_node(fv_130_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_130_1);
    Py_DecRef(v_130_1);

    v_130_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_130_2);
    Py_DecRef(v_130_2);

    fv_130_3 = nd._in_mod_nodes;
    v_130_3 = PyList_New(len(fv_130_3));
    li_130_3l = 0;
    for it_130_3l in fv_130_3 {
        e_130_3l = _emit_node(it_130_3l);
        PyList_SetItem(v_130_3, li_130_3l, e_130_3l);
        li_130_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_130_3);
    Py_DecRef(v_130_3);

    v_130_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_130_4);
    Py_DecRef(v_130_4);

    fv_130_5 = nd.loc;
    v_130_5 = _emit_CodeLocInfo(fv_130_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_130_5);
    Py_DecRef(v_130_5);

    fv_130_6 = nd.name_spec;
    v_130_6 = _emit_node(fv_130_6);
    PyDict_SetItem(d_h, _mat_keys[12], v_130_6);
    Py_DecRef(v_130_6);

    fv_130_7 = nd.semstr;
    v_130_7 = _py_str(fv_130_7);
    PyDict_SetItem(d_h, _mat_keys[13], v_130_7);
    Py_DecRef(v_130_7);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_AstTypedVarNode(nd: AstTypedVarNode) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[131], _mat_classes[131]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_131_0 = nd.kid;
    v_131_0 = PyList_New(len(fv_131_0));
    li_131_0l = 0;
    for it_131_0l in fv_131_0 {
        e_131_0l = _emit_node(it_131_0l);
        PyList_SetItem(v_131_0, li_131_0l, e_131_0l);
        li_131_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_131_0);
    Py_DecRef(v_131_0);

    fv_131_1 = nd.parent;
    if fv_131_1 is None {
        v_131_1 = _py_none();
    } else {
        v_131_1 = _emit_node(fv_131_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_131_1);
    Py_DecRef(v_131_1);

    v_131_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_131_2);
    Py_DecRef(v_131_2);

    fv_131_3 = nd._in_mod_nodes;
    v_131_3 = PyList_New(len(fv_131_3));
    li_131_3l = 0;
    for it_131_3l in fv_131_3 {
        e_131_3l = _emit_node(it_131_3l);
        PyList_SetItem(v_131_3, li_131_3l, e_131_3l);
        li_131_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_131_3);
    Py_DecRef(v_131_3);

    v_131_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_131_4);
    Py_DecRef(v_131_4);

    fv_131_5 = nd.loc;
    v_131_5 = _emit_CodeLocInfo(fv_131_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_131_5);
    Py_DecRef(v_131_5);

    fv_131_6 = nd.type_tag;
    if fv_131_6 is None {
        v_131_6 = _py_none();
    } else {
        v_131_6 = _emit_node(fv_131_6);
    }
    PyDict_SetItem(d_h, _mat_keys[89], v_131_6);
    Py_DecRef(v_131_6);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ConnectOp(nd: ConnectOp) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[132], _mat_classes[132]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_132_0 = nd.kid;
    v_132_0 = PyList_New(len(fv_132_0));
    li_132_0l = 0;
    for it_132_0l in fv_132_0 {
        e_132_0l = _emit_node(it_132_0l);
        PyList_SetItem(v_132_0, li_132_0l, e_132_0l);
        li_132_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_132_0);
    Py_DecRef(v_132_0);

    fv_132_1 = nd.parent;
    if fv_132_1 is None {
        v_132_1 = _py_none();
    } else {
        v_132_1 = _emit_node(fv_132_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_132_1);
    Py_DecRef(v_132_1);

    v_132_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_132_2);
    Py_DecRef(v_132_2);

    fv_132_3 = nd._in_mod_nodes;
    v_132_3 = PyList_New(len(fv_132_3));
    li_132_3l = 0;
    for it_132_3l in fv_132_3 {
        e_132_3l = _emit_node(it_132_3l);
        PyList_SetItem(v_132_3, li_132_3l, e_132_3l);
        li_132_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_132_3);
    Py_DecRef(v_132_3);

    v_132_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_132_4);
    Py_DecRef(v_132_4);

    fv_132_5 = nd.loc;
    v_132_5 = _emit_CodeLocInfo(fv_132_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_132_5);
    Py_DecRef(v_132_5);

    fv_132_6 = nd.conn_type;
    if fv_132_6 is None {
        v_132_6 = _py_none();
    } else {
        v_132_6 = _emit_node(fv_132_6);
    }
    PyDict_SetItem(d_h, _mat_keys[182], v_132_6);
    Py_DecRef(v_132_6);

    fv_132_7 = nd.conn_assign;
    if fv_132_7 is None {
        v_132_7 = _py_none();
    } else {
        v_132_7 = _emit_node(fv_132_7);
    }
    PyDict_SetItem(d_h, _mat_keys[183], v_132_7);
    Py_DecRef(v_132_7);

    fv_132_8 = nd.edge_dir;
    v_132_8 = _enum_EdgeDir(fv_132_8);
    PyDict_SetItem(d_h, _mat_keys[75], v_132_8);
    Py_DecRef(v_132_8);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ContextAwareNode(nd: ContextAwareNode) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[133], _mat_classes[133]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_133_0 = nd.kid;
    v_133_0 = PyList_New(len(fv_133_0));
    li_133_0l = 0;
    for it_133_0l in fv_133_0 {
        e_133_0l = _emit_node(it_133_0l);
        PyList_SetItem(v_133_0, li_133_0l, e_133_0l);
        li_133_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_133_0);
    Py_DecRef(v_133_0);

    fv_133_1 = nd.parent;
    if fv_133_1 is None {
        v_133_1 = _py_none();
    } else {
        v_133_1 = _emit_node(fv_133_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_133_1);
    Py_DecRef(v_133_1);

    v_133_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_133_2);
    Py_DecRef(v_133_2);

    fv_133_3 = nd._in_mod_nodes;
    v_133_3 = PyList_New(len(fv_133_3));
    li_133_3l = 0;
    for it_133_3l in fv_133_3 {
        e_133_3l = _emit_node(it_133_3l);
        PyList_SetItem(v_133_3, li_133_3l, e_133_3l);
        li_133_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_133_3);
    Py_DecRef(v_133_3);

    v_133_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_133_4);
    Py_DecRef(v_133_4);

    fv_133_5 = nd.loc;
    v_133_5 = _emit_CodeLocInfo(fv_133_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_133_5);
    Py_DecRef(v_133_5);

    fv_133_6 = nd.code_context;
    v_133_6 = _enum_CodeContext(fv_133_6);
    PyDict_SetItem(d_h, _mat_keys[6], v_133_6);
    Py_DecRef(v_133_6);

    fv_133_7 = nd.codespace_dual;
    v_133_7 = PyBool_FromLong(1 if fv_133_7 else 0);
    PyDict_SetItem(d_h, _mat_keys[7], v_133_7);
    Py_DecRef(v_133_7);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_EnumBlockStmt(nd: EnumBlockStmt) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[134], _mat_classes[134]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_134_0 = nd.kid;
    v_134_0 = PyList_New(len(fv_134_0));
    li_134_0l = 0;
    for it_134_0l in fv_134_0 {
        e_134_0l = _emit_node(it_134_0l);
        PyList_SetItem(v_134_0, li_134_0l, e_134_0l);
        li_134_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_134_0);
    Py_DecRef(v_134_0);

    fv_134_1 = nd.parent;
    if fv_134_1 is None {
        v_134_1 = _py_none();
    } else {
        v_134_1 = _emit_node(fv_134_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_134_1);
    Py_DecRef(v_134_1);

    v_134_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_134_2);
    Py_DecRef(v_134_2);

    fv_134_3 = nd._in_mod_nodes;
    v_134_3 = PyList_New(len(fv_134_3));
    li_134_3l = 0;
    for it_134_3l in fv_134_3 {
        e_134_3l = _emit_node(it_134_3l);
        PyList_SetItem(v_134_3, li_134_3l, e_134_3l);
        li_134_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_134_3);
    Py_DecRef(v_134_3);

    v_134_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_134_4);
    Py_DecRef(v_134_4);

    fv_134_5 = nd.loc;
    v_134_5 = _emit_CodeLocInfo(fv_134_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_134_5);
    Py_DecRef(v_134_5);

    fv_134_6 = nd.is_enum_stmt;
    v_134_6 = PyBool_FromLong(1 if fv_134_6 else 0);
    PyDict_SetItem(d_h, _mat_keys[53], v_134_6);
    Py_DecRef(v_134_6);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_Expr(nd: Expr) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[135], _mat_classes[135]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_135_0 = nd.kid;
    v_135_0 = PyList_New(len(fv_135_0));
    li_135_0l = 0;
    for it_135_0l in fv_135_0 {
        e_135_0l = _emit_node(it_135_0l);
        PyList_SetItem(v_135_0, li_135_0l, e_135_0l);
        li_135_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_135_0);
    Py_DecRef(v_135_0);

    fv_135_1 = nd.parent;
    if fv_135_1 is None {
        v_135_1 = _py_none();
    } else {
        v_135_1 = _emit_node(fv_135_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_135_1);
    Py_DecRef(v_135_1);

    v_135_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_135_2);
    Py_DecRef(v_135_2);

    fv_135_3 = nd._in_mod_nodes;
    v_135_3 = PyList_New(len(fv_135_3));
    li_135_3l = 0;
    for it_135_3l in fv_135_3 {
        e_135_3l = _emit_node(it_135_3l);
        PyList_SetItem(v_135_3, li_135_3l, e_135_3l);
        li_135_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_135_3);
    Py_DecRef(v_135_3);

    v_135_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_135_4);
    Py_DecRef(v_135_4);

    fv_135_5 = nd.loc;
    v_135_5 = _emit_CodeLocInfo(fv_135_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_135_5);
    Py_DecRef(v_135_5);

    fv_135_6 = nd._type_sym_tab;
    if fv_135_6 is None {
        v_135_6 = _py_none();
    } else {
        v_135_6 = _emit_node(fv_135_6);
    }
    PyDict_SetItem(d_h, _mat_keys[50], v_135_6);
    Py_DecRef(v_135_6);

    v_135_7 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[51], v_135_7);
    Py_DecRef(v_135_7);

    fv_135_8 = nd.attached_tokens;
    if fv_135_8 is None {
        v_135_8 = _py_none();
    } else {
        v_135_8 = PyList_New(len(fv_135_8));
        li_135_8l = 0;
        for it_135_8l in fv_135_8 {
            e_135_8l = _emit_node(it_135_8l);
            PyList_SetItem(v_135_8, li_135_8l, e_135_8l);
            li_135_8l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[52], v_135_8);
    Py_DecRef(v_135_8);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ExprAsItem(nd: ExprAsItem) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[136], _mat_classes[136]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_136_0 = nd.kid;
    v_136_0 = PyList_New(len(fv_136_0));
    li_136_0l = 0;
    for it_136_0l in fv_136_0 {
        e_136_0l = _emit_node(it_136_0l);
        PyList_SetItem(v_136_0, li_136_0l, e_136_0l);
        li_136_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_136_0);
    Py_DecRef(v_136_0);

    fv_136_1 = nd.parent;
    if fv_136_1 is None {
        v_136_1 = _py_none();
    } else {
        v_136_1 = _emit_node(fv_136_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_136_1);
    Py_DecRef(v_136_1);

    v_136_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_136_2);
    Py_DecRef(v_136_2);

    fv_136_3 = nd._in_mod_nodes;
    v_136_3 = PyList_New(len(fv_136_3));
    li_136_3l = 0;
    for it_136_3l in fv_136_3 {
        e_136_3l = _emit_node(it_136_3l);
        PyList_SetItem(v_136_3, li_136_3l, e_136_3l);
        li_136_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_136_3);
    Py_DecRef(v_136_3);

    v_136_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_136_4);
    Py_DecRef(v_136_4);

    fv_136_5 = nd.loc;
    v_136_5 = _emit_CodeLocInfo(fv_136_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_136_5);
    Py_DecRef(v_136_5);

    fv_136_6 = nd.expr;
    v_136_6 = _emit_node(fv_136_6);
    PyDict_SetItem(d_h, _mat_keys[118], v_136_6);
    Py_DecRef(v_136_6);

    fv_136_7 = nd.alias;
    if fv_136_7 is None {
        v_136_7 = _py_none();
    } else {
        v_136_7 = _emit_node(fv_136_7);
    }
    PyDict_SetItem(d_h, _mat_keys[184], v_136_7);
    Py_DecRef(v_136_7);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_FuncSignature(nd: FuncSignature) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[137], _mat_classes[137]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_137_0 = nd.kid;
    v_137_0 = PyList_New(len(fv_137_0));
    li_137_0l = 0;
    for it_137_0l in fv_137_0 {
        e_137_0l = _emit_node(it_137_0l);
        PyList_SetItem(v_137_0, li_137_0l, e_137_0l);
        li_137_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_137_0);
    Py_DecRef(v_137_0);

    fv_137_1 = nd.parent;
    if fv_137_1 is None {
        v_137_1 = _py_none();
    } else {
        v_137_1 = _emit_node(fv_137_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_137_1);
    Py_DecRef(v_137_1);

    v_137_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_137_2);
    Py_DecRef(v_137_2);

    fv_137_3 = nd._in_mod_nodes;
    v_137_3 = PyList_New(len(fv_137_3));
    li_137_3l = 0;
    for it_137_3l in fv_137_3 {
        e_137_3l = _emit_node(it_137_3l);
        PyList_SetItem(v_137_3, li_137_3l, e_137_3l);
        li_137_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_137_3);
    Py_DecRef(v_137_3);

    v_137_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_137_4);
    Py_DecRef(v_137_4);

    fv_137_5 = nd.loc;
    v_137_5 = _emit_CodeLocInfo(fv_137_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_137_5);
    Py_DecRef(v_137_5);

    fv_137_6 = nd.posonly_params;
    v_137_6 = PyList_New(len(fv_137_6));
    li_137_6l = 0;
    for it_137_6l in fv_137_6 {
        e_137_6l = _emit_node(it_137_6l);
        PyList_SetItem(v_137_6, li_137_6l, e_137_6l);
        li_137_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[185], v_137_6);
    Py_DecRef(v_137_6);

    fv_137_7 = nd.params;
    if fv_137_7 is None {
        v_137_7 = _py_none();
    } else {
        v_137_7 = PyList_New(len(fv_137_7));
        li_137_7l = 0;
        for it_137_7l in fv_137_7 {
            e_137_7l = _emit_node(it_137_7l);
            PyList_SetItem(v_137_7, li_137_7l, e_137_7l);
            li_137_7l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[165], v_137_7);
    Py_DecRef(v_137_7);

    fv_137_8 = nd.varargs;
    if fv_137_8 is None {
        v_137_8 = _py_none();
    } else {
        v_137_8 = _emit_node(fv_137_8);
    }
    PyDict_SetItem(d_h, _mat_keys[186], v_137_8);
    Py_DecRef(v_137_8);

    fv_137_9 = nd.kwonlyargs;
    v_137_9 = PyList_New(len(fv_137_9));
    li_137_9l = 0;
    for it_137_9l in fv_137_9 {
        e_137_9l = _emit_node(it_137_9l);
        PyList_SetItem(v_137_9, li_137_9l, e_137_9l);
        li_137_9l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[187], v_137_9);
    Py_DecRef(v_137_9);

    fv_137_10 = nd.kwargs;
    if fv_137_10 is None {
        v_137_10 = _py_none();
    } else {
        v_137_10 = _emit_node(fv_137_10);
    }
    PyDict_SetItem(d_h, _mat_keys[188], v_137_10);
    Py_DecRef(v_137_10);

    fv_137_11 = nd.return_type;
    if fv_137_11 is None {
        v_137_11 = _py_none();
    } else {
        v_137_11 = _emit_node(fv_137_11);
    }
    PyDict_SetItem(d_h, _mat_keys[189], v_137_11);
    Py_DecRef(v_137_11);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_JsxAttribute(nd: JsxAttribute) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[138], _mat_classes[138]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_138_0 = nd.kid;
    v_138_0 = PyList_New(len(fv_138_0));
    li_138_0l = 0;
    for it_138_0l in fv_138_0 {
        e_138_0l = _emit_node(it_138_0l);
        PyList_SetItem(v_138_0, li_138_0l, e_138_0l);
        li_138_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_138_0);
    Py_DecRef(v_138_0);

    fv_138_1 = nd.parent;
    if fv_138_1 is None {
        v_138_1 = _py_none();
    } else {
        v_138_1 = _emit_node(fv_138_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_138_1);
    Py_DecRef(v_138_1);

    v_138_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_138_2);
    Py_DecRef(v_138_2);

    fv_138_3 = nd._in_mod_nodes;
    v_138_3 = PyList_New(len(fv_138_3));
    li_138_3l = 0;
    for it_138_3l in fv_138_3 {
        e_138_3l = _emit_node(it_138_3l);
        PyList_SetItem(v_138_3, li_138_3l, e_138_3l);
        li_138_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_138_3);
    Py_DecRef(v_138_3);

    v_138_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_138_4);
    Py_DecRef(v_138_4);

    fv_138_5 = nd.loc;
    v_138_5 = _emit_CodeLocInfo(fv_138_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_138_5);
    Py_DecRef(v_138_5);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_JsxChild(nd: JsxChild) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[139], _mat_classes[139]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_139_0 = nd.kid;
    v_139_0 = PyList_New(len(fv_139_0));
    li_139_0l = 0;
    for it_139_0l in fv_139_0 {
        e_139_0l = _emit_node(it_139_0l);
        PyList_SetItem(v_139_0, li_139_0l, e_139_0l);
        li_139_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_139_0);
    Py_DecRef(v_139_0);

    fv_139_1 = nd.parent;
    if fv_139_1 is None {
        v_139_1 = _py_none();
    } else {
        v_139_1 = _emit_node(fv_139_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_139_1);
    Py_DecRef(v_139_1);

    v_139_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_139_2);
    Py_DecRef(v_139_2);

    fv_139_3 = nd._in_mod_nodes;
    v_139_3 = PyList_New(len(fv_139_3));
    li_139_3l = 0;
    for it_139_3l in fv_139_3 {
        e_139_3l = _emit_node(it_139_3l);
        PyList_SetItem(v_139_3, li_139_3l, e_139_3l);
        li_139_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_139_3);
    Py_DecRef(v_139_3);

    v_139_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_139_4);
    Py_DecRef(v_139_4);

    fv_139_5 = nd.loc;
    v_139_5 = _emit_CodeLocInfo(fv_139_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_139_5);
    Py_DecRef(v_139_5);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_JsxElementName(nd: JsxElementName) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[140], _mat_classes[140]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_140_0 = nd.kid;
    v_140_0 = PyList_New(len(fv_140_0));
    li_140_0l = 0;
    for it_140_0l in fv_140_0 {
        e_140_0l = _emit_node(it_140_0l);
        PyList_SetItem(v_140_0, li_140_0l, e_140_0l);
        li_140_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_140_0);
    Py_DecRef(v_140_0);

    fv_140_1 = nd.parent;
    if fv_140_1 is None {
        v_140_1 = _py_none();
    } else {
        v_140_1 = _emit_node(fv_140_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_140_1);
    Py_DecRef(v_140_1);

    v_140_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_140_2);
    Py_DecRef(v_140_2);

    fv_140_3 = nd._in_mod_nodes;
    v_140_3 = PyList_New(len(fv_140_3));
    li_140_3l = 0;
    for it_140_3l in fv_140_3 {
        e_140_3l = _emit_node(it_140_3l);
        PyList_SetItem(v_140_3, li_140_3l, e_140_3l);
        li_140_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_140_3);
    Py_DecRef(v_140_3);

    v_140_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_140_4);
    Py_DecRef(v_140_4);

    fv_140_5 = nd.loc;
    v_140_5 = _emit_CodeLocInfo(fv_140_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_140_5);
    Py_DecRef(v_140_5);

    fv_140_6 = nd.parts;
    v_140_6 = PyList_New(len(fv_140_6));
    li_140_6l = 0;
    for it_140_6l in fv_140_6 {
        e_140_6l = _emit_node(it_140_6l);
        PyList_SetItem(v_140_6, li_140_6l, e_140_6l);
        li_140_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[97], v_140_6);
    Py_DecRef(v_140_6);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_KVPair(nd: KVPair) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[141], _mat_classes[141]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_141_0 = nd.kid;
    v_141_0 = PyList_New(len(fv_141_0));
    li_141_0l = 0;
    for it_141_0l in fv_141_0 {
        e_141_0l = _emit_node(it_141_0l);
        PyList_SetItem(v_141_0, li_141_0l, e_141_0l);
        li_141_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_141_0);
    Py_DecRef(v_141_0);

    fv_141_1 = nd.parent;
    if fv_141_1 is None {
        v_141_1 = _py_none();
    } else {
        v_141_1 = _emit_node(fv_141_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_141_1);
    Py_DecRef(v_141_1);

    v_141_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_141_2);
    Py_DecRef(v_141_2);

    fv_141_3 = nd._in_mod_nodes;
    v_141_3 = PyList_New(len(fv_141_3));
    li_141_3l = 0;
    for it_141_3l in fv_141_3 {
        e_141_3l = _emit_node(it_141_3l);
        PyList_SetItem(v_141_3, li_141_3l, e_141_3l);
        li_141_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_141_3);
    Py_DecRef(v_141_3);

    v_141_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_141_4);
    Py_DecRef(v_141_4);

    fv_141_5 = nd.loc;
    v_141_5 = _emit_CodeLocInfo(fv_141_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_141_5);
    Py_DecRef(v_141_5);

    fv_141_6 = nd.key;
    if fv_141_6 is None {
        v_141_6 = _py_none();
    } else {
        v_141_6 = _emit_node(fv_141_6);
    }
    PyDict_SetItem(d_h, _mat_keys[173], v_141_6);
    Py_DecRef(v_141_6);

    fv_141_7 = nd.value;
    v_141_7 = _emit_node(fv_141_7);
    PyDict_SetItem(d_h, _mat_keys[42], v_141_7);
    Py_DecRef(v_141_7);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_KWPair(nd: KWPair) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[142], _mat_classes[142]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_142_0 = nd.kid;
    v_142_0 = PyList_New(len(fv_142_0));
    li_142_0l = 0;
    for it_142_0l in fv_142_0 {
        e_142_0l = _emit_node(it_142_0l);
        PyList_SetItem(v_142_0, li_142_0l, e_142_0l);
        li_142_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_142_0);
    Py_DecRef(v_142_0);

    fv_142_1 = nd.parent;
    if fv_142_1 is None {
        v_142_1 = _py_none();
    } else {
        v_142_1 = _emit_node(fv_142_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_142_1);
    Py_DecRef(v_142_1);

    v_142_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_142_2);
    Py_DecRef(v_142_2);

    fv_142_3 = nd._in_mod_nodes;
    v_142_3 = PyList_New(len(fv_142_3));
    li_142_3l = 0;
    for it_142_3l in fv_142_3 {
        e_142_3l = _emit_node(it_142_3l);
        PyList_SetItem(v_142_3, li_142_3l, e_142_3l);
        li_142_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_142_3);
    Py_DecRef(v_142_3);

    v_142_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_142_4);
    Py_DecRef(v_142_4);

    fv_142_5 = nd.loc;
    v_142_5 = _emit_CodeLocInfo(fv_142_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_142_5);
    Py_DecRef(v_142_5);

    fv_142_6 = nd.key;
    if fv_142_6 is None {
        v_142_6 = _py_none();
    } else {
        v_142_6 = _emit_node(fv_142_6);
    }
    PyDict_SetItem(d_h, _mat_keys[173], v_142_6);
    Py_DecRef(v_142_6);

    fv_142_7 = nd.value;
    v_142_7 = _emit_node(fv_142_7);
    PyDict_SetItem(d_h, _mat_keys[42], v_142_7);
    Py_DecRef(v_142_7);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_MatchPattern(nd: MatchPattern) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[143], _mat_classes[143]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_143_0 = nd.kid;
    v_143_0 = PyList_New(len(fv_143_0));
    li_143_0l = 0;
    for it_143_0l in fv_143_0 {
        e_143_0l = _emit_node(it_143_0l);
        PyList_SetItem(v_143_0, li_143_0l, e_143_0l);
        li_143_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_143_0);
    Py_DecRef(v_143_0);

    fv_143_1 = nd.parent;
    if fv_143_1 is None {
        v_143_1 = _py_none();
    } else {
        v_143_1 = _emit_node(fv_143_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_143_1);
    Py_DecRef(v_143_1);

    v_143_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_143_2);
    Py_DecRef(v_143_2);

    fv_143_3 = nd._in_mod_nodes;
    v_143_3 = PyList_New(len(fv_143_3));
    li_143_3l = 0;
    for it_143_3l in fv_143_3 {
        e_143_3l = _emit_node(it_143_3l);
        PyList_SetItem(v_143_3, li_143_3l, e_143_3l);
        li_143_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_143_3);
    Py_DecRef(v_143_3);

    v_143_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_143_4);
    Py_DecRef(v_143_4);

    fv_143_5 = nd.loc;
    v_143_5 = _emit_CodeLocInfo(fv_143_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_143_5);
    Py_DecRef(v_143_5);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ModuleItem(nd: ModuleItem) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[144], _mat_classes[144]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_144_0 = nd.kid;
    v_144_0 = PyList_New(len(fv_144_0));
    li_144_0l = 0;
    for it_144_0l in fv_144_0 {
        e_144_0l = _emit_node(it_144_0l);
        PyList_SetItem(v_144_0, li_144_0l, e_144_0l);
        li_144_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_144_0);
    Py_DecRef(v_144_0);

    fv_144_1 = nd.parent;
    if fv_144_1 is None {
        v_144_1 = _py_none();
    } else {
        v_144_1 = _emit_node(fv_144_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_144_1);
    Py_DecRef(v_144_1);

    v_144_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_144_2);
    Py_DecRef(v_144_2);

    fv_144_3 = nd._in_mod_nodes;
    v_144_3 = PyList_New(len(fv_144_3));
    li_144_3l = 0;
    for it_144_3l in fv_144_3 {
        e_144_3l = _emit_node(it_144_3l);
        PyList_SetItem(v_144_3, li_144_3l, e_144_3l);
        li_144_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_144_3);
    Py_DecRef(v_144_3);

    v_144_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_144_4);
    Py_DecRef(v_144_4);

    fv_144_5 = nd.loc;
    v_144_5 = _emit_CodeLocInfo(fv_144_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_144_5);
    Py_DecRef(v_144_5);

    fv_144_6 = nd.name;
    if isinstance(fv_144_6, Name) {
        v_144_6 = _emit_node(fv_144_6);
    } elif isinstance(fv_144_6, Token) {
        v_144_6 = _emit_node(fv_144_6);
    } else {
        v_144_6 = _py_none();
    }
    PyDict_SetItem(d_h, _mat_keys[24], v_144_6);
    Py_DecRef(v_144_6);

    fv_144_7 = nd.alias;
    if fv_144_7 is None {
        v_144_7 = _py_none();
    } else {
        v_144_7 = _emit_node(fv_144_7);
    }
    PyDict_SetItem(d_h, _mat_keys[184], v_144_7);
    Py_DecRef(v_144_7);

    fv_144_8 = nd.abs_path;
    if fv_144_8 is None {
        v_144_8 = _py_none();
    } else {
        v_144_8 = _py_str(fv_144_8);
    }
    PyDict_SetItem(d_h, _mat_keys[190], v_144_8);
    Py_DecRef(v_144_8);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ModulePath(nd: ModulePath) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[145], _mat_classes[145]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_145_0 = nd.kid;
    v_145_0 = PyList_New(len(fv_145_0));
    li_145_0l = 0;
    for it_145_0l in fv_145_0 {
        e_145_0l = _emit_node(it_145_0l);
        PyList_SetItem(v_145_0, li_145_0l, e_145_0l);
        li_145_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_145_0);
    Py_DecRef(v_145_0);

    fv_145_1 = nd.parent;
    if fv_145_1 is None {
        v_145_1 = _py_none();
    } else {
        v_145_1 = _emit_node(fv_145_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_145_1);
    Py_DecRef(v_145_1);

    v_145_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_145_2);
    Py_DecRef(v_145_2);

    fv_145_3 = nd._in_mod_nodes;
    v_145_3 = PyList_New(len(fv_145_3));
    li_145_3l = 0;
    for it_145_3l in fv_145_3 {
        e_145_3l = _emit_node(it_145_3l);
        PyList_SetItem(v_145_3, li_145_3l, e_145_3l);
        li_145_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_145_3);
    Py_DecRef(v_145_3);

    v_145_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_145_4);
    Py_DecRef(v_145_4);

    fv_145_5 = nd.loc;
    v_145_5 = _emit_CodeLocInfo(fv_145_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_145_5);
    Py_DecRef(v_145_5);

    fv_145_6 = nd.path;
    if fv_145_6 is None {
        v_145_6 = _py_none();
    } else {
        v_145_6 = PyList_New(len(fv_145_6));
        li_145_6l = 0;
        for it_145_6l in fv_145_6 {
            e_145_6l = _emit_node(it_145_6l);
            PyList_SetItem(v_145_6, li_145_6l, e_145_6l);
            li_145_6l += 1;
        }
    }
    PyDict_SetItem(d_h, _mat_keys[191], v_145_6);
    Py_DecRef(v_145_6);

    fv_145_7 = nd.level;
    v_145_7 = PyLong_FromLongLong(fv_145_7);
    PyDict_SetItem(d_h, _mat_keys[192], v_145_7);
    Py_DecRef(v_145_7);

    fv_145_8 = nd.alias;
    if fv_145_8 is None {
        v_145_8 = _py_none();
    } else {
        v_145_8 = _emit_node(fv_145_8);
    }
    PyDict_SetItem(d_h, _mat_keys[184], v_145_8);
    Py_DecRef(v_145_8);

    fv_145_9 = nd.abs_path;
    if fv_145_9 is None {
        v_145_9 = _py_none();
    } else {
        v_145_9 = _py_str(fv_145_9);
    }
    PyDict_SetItem(d_h, _mat_keys[190], v_145_9);
    Py_DecRef(v_145_9);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_ProgramModule(nd: ProgramModule) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[146], _mat_classes[146]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_146_0 = nd.kid;
    v_146_0 = PyList_New(len(fv_146_0));
    li_146_0l = 0;
    for it_146_0l in fv_146_0 {
        e_146_0l = _emit_node(it_146_0l);
        PyList_SetItem(v_146_0, li_146_0l, e_146_0l);
        li_146_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_146_0);
    Py_DecRef(v_146_0);

    fv_146_1 = nd.parent;
    if fv_146_1 is None {
        v_146_1 = _py_none();
    } else {
        v_146_1 = _emit_node(fv_146_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_146_1);
    Py_DecRef(v_146_1);

    v_146_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_146_2);
    Py_DecRef(v_146_2);

    fv_146_3 = nd._in_mod_nodes;
    v_146_3 = PyList_New(len(fv_146_3));
    li_146_3l = 0;
    for it_146_3l in fv_146_3 {
        e_146_3l = _emit_node(it_146_3l);
        PyList_SetItem(v_146_3, li_146_3l, e_146_3l);
        li_146_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_146_3);
    Py_DecRef(v_146_3);

    v_146_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_146_4);
    Py_DecRef(v_146_4);

    fv_146_5 = nd.loc;
    v_146_5 = _emit_CodeLocInfo(fv_146_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_146_5);
    Py_DecRef(v_146_5);

    fv_146_6 = nd.main_mod;
    if fv_146_6 is None {
        v_146_6 = _py_none();
    } else {
        v_146_6 = _emit_node(fv_146_6);
    }
    PyDict_SetItem(d_h, _mat_keys[193], v_146_6);
    Py_DecRef(v_146_6);

    fv_146_7 = nd.main;
    v_146_7 = _emit_node(fv_146_7);
    PyDict_SetItem(d_h, _mat_keys[194], v_146_7);
    Py_DecRef(v_146_7);

    fv_146_8 = nd.hub;
    v_146_8 = PyDict_New();
    for (dk_146_8d, dv_146_8d) in fv_146_8.items() {
        kh_146_8d = _py_str(dk_146_8d);
        vh_146_8d = _emit_node(dv_146_8d);
        PyDict_SetItem(v_146_8, kh_146_8d, vh_146_8d);
        Py_DecRef(kh_146_8d);
        Py_DecRef(vh_146_8d);
    }
    PyDict_SetItem(d_h, _mat_keys[195], v_146_8);
    Py_DecRef(v_146_8);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_Slice(nd: Slice) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[147], _mat_classes[147]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_147_0 = nd.kid;
    v_147_0 = PyList_New(len(fv_147_0));
    li_147_0l = 0;
    for it_147_0l in fv_147_0 {
        e_147_0l = _emit_node(it_147_0l);
        PyList_SetItem(v_147_0, li_147_0l, e_147_0l);
        li_147_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_147_0);
    Py_DecRef(v_147_0);

    fv_147_1 = nd.parent;
    if fv_147_1 is None {
        v_147_1 = _py_none();
    } else {
        v_147_1 = _emit_node(fv_147_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_147_1);
    Py_DecRef(v_147_1);

    v_147_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_147_2);
    Py_DecRef(v_147_2);

    fv_147_3 = nd._in_mod_nodes;
    v_147_3 = PyList_New(len(fv_147_3));
    li_147_3l = 0;
    for it_147_3l in fv_147_3 {
        e_147_3l = _emit_node(it_147_3l);
        PyList_SetItem(v_147_3, li_147_3l, e_147_3l);
        li_147_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_147_3);
    Py_DecRef(v_147_3);

    v_147_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_147_4);
    Py_DecRef(v_147_4);

    fv_147_5 = nd.loc;
    v_147_5 = _emit_CodeLocInfo(fv_147_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_147_5);
    Py_DecRef(v_147_5);

    fv_147_6 = nd.start;
    if fv_147_6 is None {
        v_147_6 = _py_none();
    } else {
        v_147_6 = _emit_node(fv_147_6);
    }
    PyDict_SetItem(d_h, _mat_keys[96], v_147_6);
    Py_DecRef(v_147_6);

    fv_147_7 = nd.stop;
    if fv_147_7 is None {
        v_147_7 = _py_none();
    } else {
        v_147_7 = _emit_node(fv_147_7);
    }
    PyDict_SetItem(d_h, _mat_keys[196], v_147_7);
    Py_DecRef(v_147_7);

    fv_147_8 = nd.step;
    if fv_147_8 is None {
        v_147_8 = _py_none();
    } else {
        v_147_8 = _emit_node(fv_147_8);
    }
    PyDict_SetItem(d_h, _mat_keys[197], v_147_8);
    Py_DecRef(v_147_8);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_UniCFGNode(nd: UniCFGNode) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[148], _mat_classes[148]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_148_0 = nd.kid;
    v_148_0 = PyList_New(len(fv_148_0));
    li_148_0l = 0;
    for it_148_0l in fv_148_0 {
        e_148_0l = _emit_node(it_148_0l);
        PyList_SetItem(v_148_0, li_148_0l, e_148_0l);
        li_148_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_148_0);
    Py_DecRef(v_148_0);

    fv_148_1 = nd.parent;
    if fv_148_1 is None {
        v_148_1 = _py_none();
    } else {
        v_148_1 = _emit_node(fv_148_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_148_1);
    Py_DecRef(v_148_1);

    v_148_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_148_2);
    Py_DecRef(v_148_2);

    fv_148_3 = nd._in_mod_nodes;
    v_148_3 = PyList_New(len(fv_148_3));
    li_148_3l = 0;
    for it_148_3l in fv_148_3 {
        e_148_3l = _emit_node(it_148_3l);
        PyList_SetItem(v_148_3, li_148_3l, e_148_3l);
        li_148_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_148_3);
    Py_DecRef(v_148_3);

    v_148_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_148_4);
    Py_DecRef(v_148_4);

    fv_148_5 = nd.loc;
    v_148_5 = _emit_CodeLocInfo(fv_148_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_148_5);
    Py_DecRef(v_148_5);

    fv_148_6 = nd.bb_in;
    v_148_6 = PyList_New(len(fv_148_6));
    li_148_6l = 0;
    for it_148_6l in fv_148_6 {
        e_148_6l = _emit_node(it_148_6l);
        PyList_SetItem(v_148_6, li_148_6l, e_148_6l);
        li_148_6l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[9], v_148_6);
    Py_DecRef(v_148_6);

    fv_148_7 = nd.bb_out;
    v_148_7 = PyList_New(len(fv_148_7));
    li_148_7l = 0;
    for it_148_7l in fv_148_7 {
        e_148_7l = _emit_node(it_148_7l);
        PyList_SetItem(v_148_7, li_148_7l, e_148_7l);
        li_148_7l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[10], v_148_7);
    Py_DecRef(v_148_7);

    fv_148_8 = nd.affected_symbols;
    v_148_8 = PySet_New(0);
    if len(fv_148_8) != 0 {
        Py_DecRef(v_148_8);
        return 0;
    }
    PyDict_SetItem(d_h, _mat_keys[11], v_148_8);
    Py_DecRef(v_148_8);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_UniScopeNode(nd: UniScopeNode) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[149], _mat_classes[149]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_149_0 = nd.kid;
    v_149_0 = PyList_New(len(fv_149_0));
    li_149_0l = 0;
    for it_149_0l in fv_149_0 {
        e_149_0l = _emit_node(it_149_0l);
        PyList_SetItem(v_149_0, li_149_0l, e_149_0l);
        li_149_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_149_0);
    Py_DecRef(v_149_0);

    fv_149_1 = nd.parent;
    if fv_149_1 is None {
        v_149_1 = _py_none();
    } else {
        v_149_1 = _emit_node(fv_149_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_149_1);
    Py_DecRef(v_149_1);

    v_149_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_149_2);
    Py_DecRef(v_149_2);

    fv_149_3 = nd._in_mod_nodes;
    v_149_3 = PyList_New(len(fv_149_3));
    li_149_3l = 0;
    for it_149_3l in fv_149_3 {
        e_149_3l = _emit_node(it_149_3l);
        PyList_SetItem(v_149_3, li_149_3l, e_149_3l);
        li_149_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_149_3);
    Py_DecRef(v_149_3);

    v_149_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_149_4);
    Py_DecRef(v_149_4);

    fv_149_5 = nd.loc;
    v_149_5 = _emit_CodeLocInfo(fv_149_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_149_5);
    Py_DecRef(v_149_5);

    fv_149_6 = nd.scope_name;
    v_149_6 = _py_str(fv_149_6);
    PyDict_SetItem(d_h, _mat_keys[18], v_149_6);
    Py_DecRef(v_149_6);

    fv_149_7 = nd.parent_scope;
    if fv_149_7 is None {
        v_149_7 = _py_none();
    } else {
        v_149_7 = _emit_node(fv_149_7);
    }
    PyDict_SetItem(d_h, _mat_keys[19], v_149_7);
    Py_DecRef(v_149_7);

    fv_149_8 = nd.kid_scope;
    v_149_8 = PyList_New(len(fv_149_8));
    li_149_8l = 0;
    for it_149_8l in fv_149_8 {
        e_149_8l = _emit_node(it_149_8l);
        PyList_SetItem(v_149_8, li_149_8l, e_149_8l);
        li_149_8l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[20], v_149_8);
    Py_DecRef(v_149_8);

    fv_149_9 = nd.names_in_scope;
    v_149_9 = PyDict_New();
    for (dk_149_9d, dv_149_9d) in fv_149_9.items() {
        kh_149_9d = _py_str(dk_149_9d);
        vh_149_9d = _emit_Symbol(dv_149_9d);
        PyDict_SetItem(v_149_9, kh_149_9d, vh_149_9d);
        Py_DecRef(kh_149_9d);
        Py_DecRef(vh_149_9d);
    }
    PyDict_SetItem(d_h, _mat_keys[21], v_149_9);
    Py_DecRef(v_149_9);

    fv_149_10 = nd.names_in_scope_overload;
    v_149_10 = PyDict_New();
    for (dk_149_10d, dv_149_10d) in fv_149_10.items() {
        kh_149_10d = _py_str(dk_149_10d);
        vh_149_10d = PyList_New(len(dv_149_10d));
        li_149_10dl = 0;
        for it_149_10dl in dv_149_10d {
            e_149_10dl = _emit_Symbol(it_149_10dl);
            PyList_SetItem(vh_149_10d, li_149_10dl, e_149_10dl);
            li_149_10dl += 1;
        }
        PyDict_SetItem(v_149_10, kh_149_10d, vh_149_10d);
        Py_DecRef(kh_149_10d);
        Py_DecRef(vh_149_10d);
    }
    PyDict_SetItem(d_h, _mat_keys[22], v_149_10);
    Py_DecRef(v_149_10);

    fv_149_11 = nd.implicit_rebinds;
    v_149_11 = PyDict_New();
    for (dk_149_11d, dv_149_11d) in fv_149_11.items() {
        kh_149_11d = _py_str(dk_149_11d);
        vh_149_11d = _emit_Symbol(dv_149_11d);
        PyDict_SetItem(v_149_11, kh_149_11d, vh_149_11d);
        Py_DecRef(kh_149_11d);
        Py_DecRef(vh_149_11d);
    }
    PyDict_SetItem(d_h, _mat_keys[23], v_149_11);
    Py_DecRef(v_149_11);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_WalkerStmtOnlyNode(nd: WalkerStmtOnlyNode) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[150], _mat_classes[150]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_150_0 = nd.kid;
    v_150_0 = PyList_New(len(fv_150_0));
    li_150_0l = 0;
    for it_150_0l in fv_150_0 {
        e_150_0l = _emit_node(it_150_0l);
        PyList_SetItem(v_150_0, li_150_0l, e_150_0l);
        li_150_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_150_0);
    Py_DecRef(v_150_0);

    fv_150_1 = nd.parent;
    if fv_150_1 is None {
        v_150_1 = _py_none();
    } else {
        v_150_1 = _emit_node(fv_150_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_150_1);
    Py_DecRef(v_150_1);

    v_150_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_150_2);
    Py_DecRef(v_150_2);

    fv_150_3 = nd._in_mod_nodes;
    v_150_3 = PyList_New(len(fv_150_3));
    li_150_3l = 0;
    for it_150_3l in fv_150_3 {
        e_150_3l = _emit_node(it_150_3l);
        PyList_SetItem(v_150_3, li_150_3l, e_150_3l);
        li_150_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_150_3);
    Py_DecRef(v_150_3);

    v_150_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_150_4);
    Py_DecRef(v_150_4);

    fv_150_5 = nd.loc;
    v_150_5 = _emit_CodeLocInfo(fv_150_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_150_5);
    Py_DecRef(v_150_5);

    fv_150_6 = nd.from_walker;
    v_150_6 = PyBool_FromLong(1 if fv_150_6 else 0);
    PyDict_SetItem(d_h, _mat_keys[73], v_150_6);
    Py_DecRef(v_150_6);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_UniNode(nd: UniNode) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[151], _mat_classes[151]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_151_0 = nd.kid;
    v_151_0 = PyList_New(len(fv_151_0));
    li_151_0l = 0;
    for it_151_0l in fv_151_0 {
        e_151_0l = _emit_node(it_151_0l);
        PyList_SetItem(v_151_0, li_151_0l, e_151_0l);
        li_151_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[0], v_151_0);
    Py_DecRef(v_151_0);

    fv_151_1 = nd.parent;
    if fv_151_1 is None {
        v_151_1 = _py_none();
    } else {
        v_151_1 = _emit_node(fv_151_1);
    }
    PyDict_SetItem(d_h, _mat_keys[1], v_151_1);
    Py_DecRef(v_151_1);

    v_151_2 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[2], v_151_2);
    Py_DecRef(v_151_2);

    fv_151_3 = nd._in_mod_nodes;
    v_151_3 = PyList_New(len(fv_151_3));
    li_151_3l = 0;
    for it_151_3l in fv_151_3 {
        e_151_3l = _emit_node(it_151_3l);
        PyList_SetItem(v_151_3, li_151_3l, e_151_3l);
        li_151_3l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[3], v_151_3);
    Py_DecRef(v_151_3);

    v_151_4 = _py_none();
    PyDict_SetItem(d_h, _mat_keys[4], v_151_4);
    Py_DecRef(v_151_4);

    fv_151_5 = nd.loc;
    v_151_5 = _emit_CodeLocInfo(fv_151_5);
    PyDict_SetItem(d_h, _mat_keys[5], v_151_5);
    Py_DecRef(v_151_5);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_CodeLocInfo(nd: CodeLocInfo) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[152], _mat_classes[152]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_152_0 = nd.first_tok;
    v_152_0 = _emit_node(fv_152_0);
    PyDict_SetItem(d_h, _mat_keys[198], v_152_0);
    Py_DecRef(v_152_0);

    fv_152_1 = nd.last_tok;
    v_152_1 = _emit_node(fv_152_1);
    PyDict_SetItem(d_h, _mat_keys[199], v_152_1);
    Py_DecRef(v_152_1);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_InheritedSymbolTable(nd: InheritedSymbolTable) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[153], _mat_classes[153]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_153_0 = nd.base_symbol_table;
    v_153_0 = _emit_node(fv_153_0);
    PyDict_SetItem(d_h, _mat_keys[200], v_153_0);
    Py_DecRef(v_153_0);

    fv_153_1 = nd.load_all_symbols;
    v_153_1 = PyBool_FromLong(1 if fv_153_1 else 0);
    PyDict_SetItem(d_h, _mat_keys[201], v_153_1);
    Py_DecRef(v_153_1);

    fv_153_2 = nd.symbols;
    v_153_2 = PyList_New(len(fv_153_2));
    li_153_2l = 0;
    for it_153_2l in fv_153_2 {
        e_153_2l = _py_str(it_153_2l);
        PyList_SetItem(v_153_2, li_153_2l, e_153_2l);
        li_153_2l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[202], v_153_2);
    Py_DecRef(v_153_2);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_Symbol(nd: Symbol) -> int {
    h = _mat_memo.get(id(nd), 0);
    if h != 0 {
        Py_IncRef(h);
        return h;
    }
    obj_h = PyObject_CallOneArg(_mat_news[154], _mat_classes[154]);
    if obj_h == 0 {
        return 0;
    }
    _mat_memo[id(nd)] = obj_h;
    d_h = PyObject_GenericGetDict(obj_h, 0);
    if d_h == 0 {
        return 0;
    }

    fv_154_0 = nd.defn;
    v_154_0 = PyList_New(len(fv_154_0));
    li_154_0l = 0;
    for it_154_0l in fv_154_0 {
        e_154_0l = _emit_node(it_154_0l);
        PyList_SetItem(v_154_0, li_154_0l, e_154_0l);
        li_154_0l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[203], v_154_0);
    Py_DecRef(v_154_0);

    fv_154_1 = nd.uses;
    v_154_1 = PyList_New(len(fv_154_1));
    li_154_1l = 0;
    for it_154_1l in fv_154_1 {
        e_154_1l = _emit_node(it_154_1l);
        PyList_SetItem(v_154_1, li_154_1l, e_154_1l);
        li_154_1l += 1;
    }
    PyDict_SetItem(d_h, _mat_keys[204], v_154_1);
    Py_DecRef(v_154_1);

    fv_154_2 = nd.access;
    v_154_2 = _enum_SymbolAccess(fv_154_2);
    PyDict_SetItem(d_h, _mat_keys[16], v_154_2);
    Py_DecRef(v_154_2);

    fv_154_3 = nd.parent_tab;
    if fv_154_3 is None {
        v_154_3 = _py_none();
    } else {
        v_154_3 = _emit_node(fv_154_3);
    }
    PyDict_SetItem(d_h, _mat_keys[205], v_154_3);
    Py_DecRef(v_154_3);

    fv_154_4 = nd.imported;
    v_154_4 = PyBool_FromLong(1 if fv_154_4 else 0);
    PyDict_SetItem(d_h, _mat_keys[206], v_154_4);
    Py_DecRef(v_154_4);

    fv_154_5 = nd.semstr;
    v_154_5 = _py_str(fv_154_5);
    PyDict_SetItem(d_h, _mat_keys[13], v_154_5);
    Py_DecRef(v_154_5);

    fv_154_6 = nd.ownership;
    v_154_6 = _enum_OwnershipKind(fv_154_6);
    PyDict_SetItem(d_h, _mat_keys[177], v_154_6);
    Py_DecRef(v_154_6);

    fv_154_7 = nd.param_rebound;
    v_154_7 = PyBool_FromLong(1 if fv_154_7 else 0);
    PyDict_SetItem(d_h, _mat_keys[207], v_154_7);
    Py_DecRef(v_154_7);

    fv_154_8 = nd.na_escapes;
    v_154_8 = PyBool_FromLong(1 if fv_154_8 else 0);
    PyDict_SetItem(d_h, _mat_keys[208], v_154_8);
    Py_DecRef(v_154_8);

    fv_154_9 = nd.na_region_handle;
    v_154_9 = PyBool_FromLong(1 if fv_154_9 else 0);
    PyDict_SetItem(d_h, _mat_keys[209], v_154_9);
    Py_DecRef(v_154_9);

    fv_154_10 = nd.na_stack_ok;
    v_154_10 = PyBool_FromLong(1 if fv_154_10 else 0);
    PyDict_SetItem(d_h, _mat_keys[210], v_154_10);
    Py_DecRef(v_154_10);
    Py_DecRef(d_h);
    Py_IncRef(obj_h);
    return obj_h;
}

def _emit_node(nd: UniNode) -> int {
    if isinstance(nd, Archetype) {
        return _emit_Archetype(nd);
    } elif isinstance(nd, Enum) {
        return _emit_Enum(nd);
    } elif isinstance(nd, Ability) {
        return _emit_Ability(nd);
    } elif isinstance(nd, BuiltinType) {
        return _emit_BuiltinType(nd);
    } elif isinstance(nd, ImplDef) {
        return _emit_ImplDef(nd);
    } elif isinstance(nd, SpecialVarRef) {
        return _emit_SpecialVarRef(nd);
    } elif isinstance(nd, TypeAlias) {
        return _emit_TypeAlias(nd);
    } elif isinstance(nd, Name) {
        return _emit_Name(nd);
    } elif isinstance(nd, GenCompr) {
        return _emit_GenCompr(nd);
    } elif isinstance(nd, ModuleCode) {
        return _emit_ModuleCode(nd);
    } elif isinstance(nd, SetCompr) {
        return _emit_SetCompr(nd);
    } elif isinstance(nd, Test) {
        return _emit_Test(nd);
    } elif isinstance(nd, String) {
        return _emit_String(nd);
    } elif isinstance(nd, Int) {
        return _emit_Int(nd);
    } elif isinstance(nd, ArchSpec) {
        return _emit_ArchSpec(nd);
    } elif isinstance(nd, Bool) {
        return _emit_Bool(nd);
    } elif isinstance(nd, DictCompr) {
        return _emit_DictCompr(nd);
    } elif isinstance(nd, Ellipsis) {
        return _emit_Ellipsis(nd);
    } elif isinstance(nd, Float) {
        return _emit_Float(nd);
    } elif isinstance(nd, GlobalVars) {
        return _emit_GlobalVars(nd);
    } elif isinstance(nd, ListCompr) {
        return _emit_ListCompr(nd);
    } elif isinstance(nd, Null) {
        return _emit_Null(nd);
    } elif isinstance(nd, PyInlineCode) {
        return _emit_PyInlineCode(nd);
    } elif isinstance(nd, SemDef) {
        return _emit_SemDef(nd);
    } elif isinstance(nd, ArchHas) {
        return _emit_ArchHas(nd);
    } elif isinstance(nd, EdgeOpRef) {
        return _emit_EdgeOpRef(nd);
    } elif isinstance(nd, ElseIf) {
        return _emit_ElseIf(nd);
    } elif isinstance(nd, Import) {
        return _emit_Import(nd);
    } elif isinstance(nd, InForStmt) {
        return _emit_InForStmt(nd);
    } elif isinstance(nd, IterForStmt) {
        return _emit_IterForStmt(nd);
    } elif isinstance(nd, Literal) {
        return _emit_Literal(nd);
    } elif isinstance(nd, NameAtom) {
        return _emit_NameAtom(nd);
    } elif isinstance(nd, AssignCompr) {
        return _emit_AssignCompr(nd);
    } elif isinstance(nd, Assignment) {
        return _emit_Assignment(nd);
    } elif isinstance(nd, CtElse) {
        return _emit_CtElse(nd);
    } elif isinstance(nd, CtFor) {
        return _emit_CtFor(nd);
    } elif isinstance(nd, CtIf) {
        return _emit_CtIf(nd);
    } elif isinstance(nd, DictVal) {
        return _emit_DictVal(nd);
    } elif isinstance(nd, FString) {
        return _emit_FString(nd);
    } elif isinstance(nd, FilterCompr) {
        return _emit_FilterCompr(nd);
    } elif isinstance(nd, IfStmt) {
        return _emit_IfStmt(nd);
    } elif isinstance(nd, IndexSlice) {
        return _emit_IndexSlice(nd);
    } elif isinstance(nd, JsxElement) {
        return _emit_JsxElement(nd);
    } elif isinstance(nd, ListVal) {
        return _emit_ListVal(nd);
    } elif isinstance(nd, MultiString) {
        return _emit_MultiString(nd);
    } elif isinstance(nd, SetVal) {
        return _emit_SetVal(nd);
    } elif isinstance(nd, TryStmt) {
        return _emit_TryStmt(nd);
    } elif isinstance(nd, TupleVal) {
        return _emit_TupleVal(nd);
    } elif isinstance(nd, TypedCtxBlock) {
        return _emit_TypedCtxBlock(nd);
    } elif isinstance(nd, VisitStmt) {
        return _emit_VisitStmt(nd);
    } elif isinstance(nd, WhileStmt) {
        return _emit_WhileStmt(nd);
    } elif isinstance(nd, WithStmt) {
        return _emit_WithStmt(nd);
    } elif isinstance(nd, Semi) {
        return _emit_Semi(nd);
    } elif isinstance(nd, AtomExpr) {
        return _emit_AtomExpr(nd);
    } elif isinstance(nd, AwaitingClause) {
        return _emit_AwaitingClause(nd);
    } elif isinstance(nd, CfgExpr) {
        return _emit_CfgExpr(nd);
    } elif isinstance(nd, CtName) {
        return _emit_CtName(nd);
    } elif isinstance(nd, CtSplice) {
        return _emit_CtSplice(nd);
    } elif isinstance(nd, DisengageStmt) {
        return _emit_DisengageStmt(nd);
    } elif isinstance(nd, Except) {
        return _emit_Except(nd);
    } elif isinstance(nd, FinallyStmt) {
        return _emit_FinallyStmt(nd);
    } elif isinstance(nd, ForeverStmt) {
        return _emit_ForeverStmt(nd);
    } elif isinstance(nd, InnerCompr) {
        return _emit_InnerCompr(nd);
    } elif isinstance(nd, MatchCase) {
        return _emit_MatchCase(nd);
    } elif isinstance(nd, OpenStmt) {
        return _emit_OpenStmt(nd);
    } elif isinstance(nd, SwitchCase) {
        return _emit_SwitchCase(nd);
    } elif isinstance(nd, AssertStmt) {
        return _emit_AssertStmt(nd);
    } elif isinstance(nd, AstImplNeedingNode) {
        return _emit_AstImplNeedingNode(nd);
    } elif isinstance(nd, CtrlStmt) {
        return _emit_CtrlStmt(nd);
    } elif isinstance(nd, DeleteStmt) {
        return _emit_DeleteStmt(nd);
    } elif isinstance(nd, ExprStmt) {
        return _emit_ExprStmt(nd);
    } elif isinstance(nd, HasVar) {
        return _emit_HasVar(nd);
    } elif isinstance(nd, LambdaExpr) {
        return _emit_LambdaExpr(nd);
    } elif isinstance(nd, MatchStmt) {
        return _emit_MatchStmt(nd);
    } elif isinstance(nd, Module) {
        return _emit_Module(nd);
    } elif isinstance(nd, ParamVar) {
        return _emit_ParamVar(nd);
    } elif isinstance(nd, PythonModuleAst) {
        return _emit_PythonModuleAst(nd);
    } elif isinstance(nd, RaiseStmt) {
        return _emit_RaiseStmt(nd);
    } elif isinstance(nd, ReportStmt) {
        return _emit_ReportStmt(nd);
    } elif isinstance(nd, ReturnStmt) {
        return _emit_ReturnStmt(nd);
    } elif isinstance(nd, Source) {
        return _emit_Source(nd);
    } elif isinstance(nd, SwitchStmt) {
        return _emit_SwitchStmt(nd);
    } elif isinstance(nd, AstSymbolStubNode) {
        return _emit_AstSymbolStubNode(nd);
    } elif isinstance(nd, AtomTrailer) {
        return _emit_AtomTrailer(nd);
    } elif isinstance(nd, AtomUnit) {
        return _emit_AtomUnit(nd);
    } elif isinstance(nd, AwaitExpr) {
        return _emit_AwaitExpr(nd);
    } elif isinstance(nd, BinaryExpr) {
        return _emit_BinaryExpr(nd);
    } elif isinstance(nd, BoolExpr) {
        return _emit_BoolExpr(nd);
    } elif isinstance(nd, CastExpr) {
        return _emit_CastExpr(nd);
    } elif isinstance(nd, CodeBlockStmt) {
        return _emit_CodeBlockStmt(nd);
    } elif isinstance(nd, CommentToken) {
        return _emit_CommentToken(nd);
    } elif isinstance(nd, CompareExpr) {
        return _emit_CompareExpr(nd);
    } elif isinstance(nd, ConcurrentExpr) {
        return _emit_ConcurrentExpr(nd);
    } elif isinstance(nd, ConditionalNode) {
        return _emit_ConditionalNode(nd);
    } elif isinstance(nd, CtBlock) {
        return _emit_CtBlock(nd);
    } elif isinstance(nd, DisconnectOp) {
        return _emit_DisconnectOp(nd);
    } elif isinstance(nd, EdgeRefTrailer) {
        return _emit_EdgeRefTrailer(nd);
    } elif isinstance(nd, ElementStmt) {
        return _emit_ElementStmt(nd);
    } elif isinstance(nd, ElseStmt) {
        return _emit_ElseStmt(nd);
    } elif isinstance(nd, EmptyToken) {
        return _emit_EmptyToken(nd);
    } elif isinstance(nd, EventSignature) {
        return _emit_EventSignature(nd);
    } elif isinstance(nd, FormattedValue) {
        return _emit_FormattedValue(nd);
    } elif isinstance(nd, FuncCall) {
        return _emit_FuncCall(nd);
    } elif isinstance(nd, IfElseExpr) {
        return _emit_IfElseExpr(nd);
    } elif isinstance(nd, JsxComment) {
        return _emit_JsxComment(nd);
    } elif isinstance(nd, JsxExpression) {
        return _emit_JsxExpression(nd);
    } elif isinstance(nd, JsxNormalAttribute) {
        return _emit_JsxNormalAttribute(nd);
    } elif isinstance(nd, JsxSlot) {
        return _emit_JsxSlot(nd);
    } elif isinstance(nd, JsxSpreadAttribute) {
        return _emit_JsxSpreadAttribute(nd);
    } elif isinstance(nd, JsxText) {
        return _emit_JsxText(nd);
    } elif isinstance(nd, MatchArch) {
        return _emit_MatchArch(nd);
    } elif isinstance(nd, MatchAs) {
        return _emit_MatchAs(nd);
    } elif isinstance(nd, MatchKVPair) {
        return _emit_MatchKVPair(nd);
    } elif isinstance(nd, MatchMapping) {
        return _emit_MatchMapping(nd);
    } elif isinstance(nd, MatchOr) {
        return _emit_MatchOr(nd);
    } elif isinstance(nd, MatchSequence) {
        return _emit_MatchSequence(nd);
    } elif isinstance(nd, MatchSingleton) {
        return _emit_MatchSingleton(nd);
    } elif isinstance(nd, MatchStar) {
        return _emit_MatchStar(nd);
    } elif isinstance(nd, MatchValue) {
        return _emit_MatchValue(nd);
    } elif isinstance(nd, MatchWild) {
        return _emit_MatchWild(nd);
    } elif isinstance(nd, SubTag) {
        return _emit_SubTag(nd);
    } elif isinstance(nd, TypeParam) {
        return _emit_TypeParam(nd);
    } elif isinstance(nd, UnaryExpr) {
        return _emit_UnaryExpr(nd);
    } elif isinstance(nd, YieldExpr) {
        return _emit_YieldExpr(nd);
    } elif isinstance(nd, Token) {
        return _emit_Token(nd);
    } elif isinstance(nd, ArchBlockStmt) {
        return _emit_ArchBlockStmt(nd);
    } elif isinstance(nd, AstAccessNode) {
        return _emit_AstAccessNode(nd);
    } elif isinstance(nd, AstAsyncNode) {
        return _emit_AstAsyncNode(nd);
    } elif isinstance(nd, AstDocNode) {
        return _emit_AstDocNode(nd);
    } elif isinstance(nd, AstElseBodyNode) {
        return _emit_AstElseBodyNode(nd);
    } elif isinstance(nd, AstSymbolNode) {
        return _emit_AstSymbolNode(nd);
    } elif isinstance(nd, AstTypedVarNode) {
        return _emit_AstTypedVarNode(nd);
    } elif isinstance(nd, ConnectOp) {
        return _emit_ConnectOp(nd);
    } elif isinstance(nd, ContextAwareNode) {
        return _emit_ContextAwareNode(nd);
    } elif isinstance(nd, EnumBlockStmt) {
        return _emit_EnumBlockStmt(nd);
    } elif isinstance(nd, Expr) {
        return _emit_Expr(nd);
    } elif isinstance(nd, ExprAsItem) {
        return _emit_ExprAsItem(nd);
    } elif isinstance(nd, FuncSignature) {
        return _emit_FuncSignature(nd);
    } elif isinstance(nd, JsxAttribute) {
        return _emit_JsxAttribute(nd);
    } elif isinstance(nd, JsxChild) {
        return _emit_JsxChild(nd);
    } elif isinstance(nd, JsxElementName) {
        return _emit_JsxElementName(nd);
    } elif isinstance(nd, KVPair) {
        return _emit_KVPair(nd);
    } elif isinstance(nd, KWPair) {
        return _emit_KWPair(nd);
    } elif isinstance(nd, MatchPattern) {
        return _emit_MatchPattern(nd);
    } elif isinstance(nd, ModuleItem) {
        return _emit_ModuleItem(nd);
    } elif isinstance(nd, ModulePath) {
        return _emit_ModulePath(nd);
    } elif isinstance(nd, ProgramModule) {
        return _emit_ProgramModule(nd);
    } elif isinstance(nd, Slice) {
        return _emit_Slice(nd);
    } elif isinstance(nd, UniCFGNode) {
        return _emit_UniCFGNode(nd);
    } elif isinstance(nd, UniScopeNode) {
        return _emit_UniScopeNode(nd);
    } elif isinstance(nd, WalkerStmtOnlyNode) {
        return _emit_WalkerStmtOnlyNode(nd);
    } elif isinstance(nd, UniNode) {
        return _emit_UniNode(nd);
    }
    return _py_none();
}
