# Compiler codegen for the P4 back track (PLAN.md P0.10).
#
# Walks a hand-built (later: parser-produced) ast_nodes.jac tree and emits IR
# into a unverified_cfg. Dispatch is locked to na-legal ordered isinstance
# if-chains (PLAN.md dispatch decision). Covers the expression slice only:
# Constant, Name, BinOp, UnaryOp, Call, plus the eval/module wrapper.
#
# Location assignment matches CPython 3.14 exactly (verified per-instruction via
# code.co_positions()): RESUME -> (0, firstlineno, 0, 0); RETURN_VALUE -> the
# top-level expression's span; PUSH_NULL -> the callable's span; every other
# instruction -> its owning AST node's span.
#
# Product module: imports compiler_ir + opcode_meta + ast_nodes only. No host
# tokenize/ast/compile/marshal.

import from objects { PyObj, PyInt, PyStr, py_none, PySlice, PyCode, PyTuple }
import from opcode_meta {
    OP_RESUME,
    OP_RETURN_VALUE,
    OP_LOAD_CONST,
    OP_LOAD_SMALL_INT,
    OP_LOAD_NAME,
    OP_LOAD_GLOBAL,
    OP_LOAD_BUILD_CLASS,
    OP_MAKE_FUNCTION,
    OP_MAKE_CELL,
    OP_COPY_FREE_VARS,
    OP_LOAD_DEREF,
    OP_STORE_DEREF,
    OP_BUILD_TUPLE,
    OP_SET_FUNCTION_ATTRIBUTE,
    OP_BINARY_OP,
    CO_OPTIMIZED,
    CO_NEWLOCALS,
    CO_NESTED,
    CO_VARARGS,
    CO_VARKEYWORDS,
    OP_UNARY_NEGATIVE,
    OP_UNARY_INVERT,
    OP_UNARY_NOT,
    OP_PUSH_NULL,
    OP_CALL,
    OP_CALL_KW,
    OP_LOAD_LOCALS,
    OP_COMPARE_OP,
    OP_POP_TOP,
    OP_STORE_NAME,
    OP_STORE_ATTR,
    OP_STORE_SUBSCR,
    OP_LOAD_ATTR,
    OP_DELETE_NAME,
    OP_DELETE_ATTR,
    OP_DELETE_SUBSCR,
    OP_POP_JUMP_IF_FALSE,
    OP_POP_JUMP_IF_TRUE,
    OP_JUMP_FORWARD,
    OP_JUMP_BACKWARD,
    OP_COPY,
    OP_SWAP,
    OP_TO_BOOL,
    OP_NOP,
    OP_GET_ITER,
    OP_FOR_ITER,
    OP_END_FOR,
    OP_POP_ITER,
    OP_BUILD_LIST,
    OP_LIST_APPEND,
    OP_BUILD_SET,
    OP_SET_ADD,
    OP_BUILD_MAP,
    OP_MAP_ADD,
    OP_LOAD_FAST,
    OP_LOAD_FAST_BORROW,
    OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW,
    OP_LOAD_FAST_AND_CLEAR,
    OP_STORE_FAST,
    OP_STORE_FAST_STORE_FAST,
    OP_STORE_FAST_LOAD_FAST,
    OP_UNPACK_SEQUENCE,
    OP_RERAISE,
    NB_ADD,
    NB_SUBTRACT,
    NB_MULTIPLY,
    NB_TRUE_DIVIDE,
    NB_FLOOR_DIVIDE,
    NB_REMAINDER,
    NB_POWER,
    NB_LSHIFT,
    NB_RSHIFT,
    NB_OR,
    NB_XOR,
    NB_AND,
    NB_MATRIX_MULTIPLY,
    NB_SUBSCR,
    NB_INPLACE_ADD,
    NB_INPLACE_SUBTRACT,
    NB_INPLACE_MULTIPLY,
    NB_INPLACE_TRUE_DIVIDE,
    NB_INPLACE_FLOOR_DIVIDE,
    NB_INPLACE_REMAINDER,
    NB_INPLACE_POWER,
    NB_INPLACE_LSHIFT,
    NB_INPLACE_RSHIFT,
    NB_INPLACE_OR,
    NB_INPLACE_XOR,
    NB_INPLACE_AND,
    NB_INPLACE_MATRIX_MULTIPLY,
    CMP_LT,
    CMP_LE,
    CMP_EQ,
    CMP_NE,
    CMP_GT,
    CMP_GE,
    compare_oparg,
    compare_filter_oparg,
}
import from ast_nodes {
    ast_node,
    expr,
    stmt,
    Constant,
    Name,
    BinOp,
    UnaryOp,
    Call,
    Compare,
    Assign,
    Expr,
    Pass,
    Return,
    AugAssign,
    AnnAssign,
    Delete,
    Attribute,
    Subscript,
    Slice,
    Load,
    Store,
    Lt,
    Gt,
    Eq,
    NotEq,
    LtE,
    GtE,
    Add,
    Sub,
    Mult,
    Div,
    Mod,
    Pow,
    LShift,
    RShift,
    BitOr,
    BitXor,
    BitAnd,
    FloorDiv,
    MatMult,
    USub,
    UAdd,
    Invert,
    Not,
    BoolOp,
    And,
    Or,
    NamedExpr,
    Lambda,
    IfExp,
    Dict,
    Set,
    ListComp,
    SetComp,
    DictComp,
    GeneratorExp,
    comprehension,
    Await,
    Yield,
    YieldFrom,
    FormattedValue,
    JoinedStr,
    Interpolation,
    TemplateStr,
    Starred,
    List,
    Tuple,
    FunctionDef,
    AsyncFunctionDef,
    keyword,
    arguments,
    ClassDef,
    TypeAlias,
    For,
    AsyncFor,
    While,
    If,
    With,
    AsyncWith,
    Match,
    Raise,
    Try,
    TryStar,
    Assert,
    Import,
    ImportFrom,
    Global,
    Nonlocal,
    Break,
    Continue,
}
import from compiler_ir {
    cloc,
    unverified_cfg,
    basicblock,
    cinstr,
    loc,
    no_loc,
    mk_instr,
    mk_jump,
    cfg_builder,
    stmt_cont,
    new_cfg_builder,
    loop_frame,
    except_region,
    comp_handler,
}
import from compiler_symtable {
    sym_block,
    sym_dict_get,
    sym_flag_set,
    sym_scope_of,
    sym_sorted_names,
    DEF_COMP_ITER,
    SCOPE_GLOBAL_EXPLICIT,
    SCOPE_GLOBAL_IMPLICIT,
    SCOPE_LOCAL,
    SCOPE_CELL,
    SCOPE_FREE,
    sym_block_tuple_names,
}
import from compiler_diagnostics { lowering_diagnostic }
import from flowgraph { verify_cfg }
import from assembler { assemble }

# Record the first codegen diagnostic on the builder's unit.
def codegen_fail(g: cfg_builder, kind: str, message: str) {
    u = g.u;
    if u.diag is None {
        u.diag = lowering_diagnostic(kind=kind, message=message);
    }
}

def codegen_busy(g: cfg_builder) -> bool {
    return g.u.diag is not None;
}

# Fast locals for a compile unit. Module scope: comprehension iteration variables
# only. Function scope: parameters (definition order) then other locals (sorted).
def fast_varnames_from_sym(block: sym_block) -> list[str] {
    if block.block_type == "function" {
        out: list[str] = [];
        pi = 0;
        while pi < len(block.varnames) {
            out.append(block.varnames[pi]);
            pi = pi + 1;
        }
        names = sym_sorted_names(block.symbols);
        ni = 0;
        while ni < len(names) {
            name = names[ni];
            flags = block.symbols[name];
            if sym_scope_of(flags) == SCOPE_LOCAL {
                found = False;
                fi = 0;
                while fi < len(out) {
                    if out[fi] == name {
                        found = True;
                    }
                    fi = fi + 1;
                }
                if not found {
                    out.append(name);
                }
            }
            ni = ni + 1;
        }
        return out;
    }
    names = sym_sorted_names(block.symbols);
    out: list[str] = [];
    ni = 0;
    while ni < len(names) {
        name = names[ni];
        flags = block.symbols[name];
        if block.block_type == "module" {
            if sym_flag_set(flags, DEF_COMP_ITER) {
                out.append(name);
            }
        } elif sym_scope_of(flags) == SCOPE_LOCAL {
            out.append(name);
        }
        ni = ni + 1;
    }
    return out;
}

def cellvars_from_sym(block: sym_block) -> list[str] {
    return sym_block_tuple_names(block.symbols, SCOPE_CELL);
}

def freevars_from_sym(block: sym_block) -> list[str] {
    return sym_block_tuple_names(block.symbols, SCOPE_FREE);
}

def varname_index(u: unverified_cfg, name: str) -> int {
    vi = 0;
    while vi < len(u.varnames) {
        if u.varnames[vi] == name {
            return vi;
        }
        vi = vi + 1;
    }
    return -1;
}

# Merged locals-plus index for MAKE_CELL / LOAD_DEREF / LOAD_FAST_BORROW (CPython 3.11+).
def localsplus_index_u(u: unverified_cfg, name: str) -> int {
    vi = varname_index(u, name);
    if vi >= 0 {
        return vi;
    }
    idx = len(u.varnames);
    ci = 0;
    while ci < len(u.cellvars) {
        cname = u.cellvars[ci];
        if varname_index(u, cname) < 0 {
            if cname == name {
                return idx;
            }
            idx = idx + 1;
        }
        ci = ci + 1;
    }
    fi = 0;
    while fi < len(u.freevars) {
        if u.freevars[fi] == name {
            return idx;
        }
        idx = idx + 1;
        fi = fi + 1;
    }
    return -1;
}

def localsplus_index(g: cfg_builder, name: str) -> int {
    return localsplus_index_u(g.u, name);
}

# CPython emits MAKE_CELL(s), optional COPY_FREE_VARS, then RESUME.
def emit_function_prologue(g: cfg_builder, sym_fn: sym_block, firstlineno: int) {
    u = g.u;
    u.cellvars = cellvars_from_sym(sym_fn);
    u.freevars = freevars_from_sym(sym_fn);
    ploc = loc(0, firstlineno, 0, 0);
    ci = 0;
    while ci < len(u.cellvars) {
        lp = localsplus_index_u(u, u.cellvars[ci]);
        g.emit_op(OP_MAKE_CELL, lp, ploc);
        ci = ci + 1;
    }
    if len(u.freevars) > 0 {
        g.emit_op(OP_COPY_FREE_VARS, len(u.freevars), ploc);
    }
    g.emit_op(OP_RESUME, 0, ploc);
}

# Fold default expressions when every value is a Constant (CPython LOAD_CONST tuple).
def fold_default_values(defaults: list[expr]) -> list[PyObj] | None {
    items: list[PyObj] = [];
    di = 0;
    while di < len(defaults) {
        d = defaults[di];
        if not isinstance(d, Constant) {
            return None;
        }
        items.append((d as Constant).value);
        di = di + 1;
    }
    return items;
}

# Compile default expressions in the enclosing scope; leaves defaults tuple on stack.
def emit_function_defaults(
    g: cfg_builder, defaults: list[expr], tloc: cloc
) -> bool {
    if len(defaults) == 0 {
        return True;
    }
    folded = fold_default_values(defaults);
    if folded is not None {
        tup = PyTuple(t="tuple", items=folded);
        idx = g.u.add_const(tup);
        g.emit_op(OP_LOAD_CONST, idx, tloc);
        return True;
    }
    di = 0;
    while di < len(defaults) {
        visit_expr(g, defaults[di]);
        if codegen_busy(g) {
            return False;
        }
        di = di + 1;
    }
    g.emit_op(OP_BUILD_TUPLE, len(defaults), tloc);
    return True;
}

def args_have_kw_defaults(args: arguments) -> bool {
    ki = 0;
    while ki < len(args.kw_defaults) {
        if args.kw_defaults[ki] is not None {
            return True;
        }
        ki = ki + 1;
    }
    return False;
}

# Compile kw-only default expressions; leaves kwdefaults dict on stack.
def emit_function_kwdefaults(
    g: cfg_builder, args: arguments, tloc: cloc
) -> bool {
    pair_count = 0;
    ki = 0;
    while ki < len(args.kwonlyargs) {
        kd: expr | None = None;
        if ki < len(args.kw_defaults) {
            kd = args.kw_defaults[ki];
        }
        if kd is not None {
            a = args.kwonlyargs[ki] as arg;
            key_idx = g.u.add_const(PyStr(t="str", val=a.arg));
            g.emit_op(OP_LOAD_CONST, key_idx, tloc);
            visit_expr(g, kd);
            if codegen_busy(g) {
                return False;
            }
            pair_count = pair_count + 1;
        }
        ki = ki + 1;
    }
    if pair_count > 0 {
        g.emit_op(OP_BUILD_MAP, pair_count, tloc);
    }
    return True;
}

# Nested code on stack; defaults/kwdefaults/closure + SET_FUNCTION_ATTRIBUTE when needed.
def emit_make_function_with_closure(
    g: cfg_builder,
    sym_fn: sym_block,
    co: PyCode,
    tloc: cloc,
    args: arguments | None = None
) {
    has_defaults = args is not None and len(args.defaults) > 0;
    has_kwdefaults = args is not None and args_have_kw_defaults(args);
    cidx = g.u.add_const(co);
    if has_defaults {
        if not emit_function_defaults(g, args.defaults, tloc) {
            return;
        }
    }
    if has_kwdefaults {
        if not emit_function_kwdefaults(g, args, tloc) {
            return;
        }
    }
    child_free = freevars_from_sym(sym_fn);
    if len(child_free) > 0 {
        fi = 0;
        while fi < len(child_free) {
            lp = localsplus_index(g, child_free[fi]);
            g.emit_op(OP_LOAD_FAST_BORROW, lp, tloc);
            fi = fi + 1;
        }
        g.emit_op(OP_BUILD_TUPLE, len(child_free), tloc);
    }
    g.emit_op(OP_LOAD_CONST, cidx, tloc);
    g.emit_op(OP_MAKE_FUNCTION, 0, tloc);
    if len(child_free) > 0 {
        g.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 8, tloc);
    }
    if has_kwdefaults {
        g.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 2, tloc);
    }
    if has_defaults {
        g.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 1, tloc);
    }
}

def sym_class_child(parent: sym_block, class_name: str) -> sym_block | None {
    ci = 0;
    while ci < len(parent.children) {
        ch = parent.children[ci];
        if ch.block_type == "class" and ch.name == class_name {
            return ch;
        }
        ci = ci + 1;
    }
    return None;
}

def sym_function_child(parent: sym_block, fn_name: str) -> sym_block | None {
    ci = 0;
    while ci < len(parent.children) {
        ch = parent.children[ci];
        if ch.block_type == "function" and ch.name == fn_name {
            return ch;
        }
        ci = ci + 1;
    }
    return None;
}

def sym_function_child_at(
    parent: sym_block, fn_name: str, lineno: int, col_offset: int
) -> sym_block | None {
    ci = 0;
    while ci < len(parent.children) {
        ch = parent.children[ci];
        if ch.block_type == "function"
            and ch.name == fn_name
            and ch.lineno == lineno
            and ch.col_offset == col_offset {
            return ch;
        }
        ci = ci + 1;
    }
    return None;
}

def unit_fail(u: unverified_cfg, kind: str, message: str) {
    if u.diag is None {
        u.diag = lowering_diagnostic(kind=kind, message=message);
    }
}

def function_argcounts(args: arguments) -> tuple[int, int, int] {
    posonly = len(args.posonlyargs);
    regular = len(args.args);
    kwonly = len(args.kwonlyargs);
    return (posonly + regular, posonly, kwonly);
}

def function_code_flags(args: arguments) -> int {
    flags = CO_OPTIMIZED | CO_NEWLOCALS;
    if args.vararg is not None {
        flags = flags | CO_VARARGS;
    }
    if args.kwarg is not None {
        flags = flags | CO_VARKEYWORDS;
    }
    return flags;
}

def emit_name_load(
    g: cfg_builder, name: str, tloc: cloc, for_call: bool = False
) -> bool {
    # Returns True when a separate PUSH_NULL is required before CALL (LOAD_NAME
    # and fast locals). LOAD_GLOBAL folds NULL into the oparg low bit (CPython 3.14).
    fi = fast_local_index(g, name);
    if fi >= 0 {
        g.emit_op(OP_LOAD_FAST_BORROW, fi, tloc);
        return True;
    }
    if g.sym_top is not None and g.sym_top.block_type != "module" {
        flags = sym_dict_get(g.sym_top.symbols, name, 0);
        scope = sym_scope_of(flags);
        if scope == SCOPE_FREE or scope == SCOPE_CELL {
            idx = localsplus_index(g, name);
            g.emit_op(OP_LOAD_DEREF, idx, tloc);
            return True;
        }
    }
    opc = name_load_opcode(g, name);
    idx = g.u.add_name(name);
    if for_call and opc == OP_LOAD_GLOBAL {
        g.emit_op(opc, (idx << 1) | 1, tloc);
        return False;
    }
    g.emit_op(opc, idx, tloc);
    return True;
}

def emit_name_store(g: cfg_builder, name: str, tloc: cloc) {
    fi = fast_local_index(g, name);
    if fi >= 0 {
        g.emit_op(OP_STORE_FAST, fi, tloc);
        return;
    }
    if g.sym_top is not None and g.sym_top.block_type != "module" {
        flags = sym_dict_get(g.sym_top.symbols, name, 0);
        scope = sym_scope_of(flags);
        if scope == SCOPE_FREE or scope == SCOPE_CELL {
            idx = localsplus_index(g, name);
            g.emit_op(OP_STORE_DEREF, idx, tloc);
            return;
        }
    }
    idx = g.u.add_name(name);
    g.emit_op(OP_STORE_NAME, idx, tloc);
}

# Name load opcode from symtable facts. Module scope uses LOAD_NAME for globals
# and LOAD_FAST when the name is a comprehension / local slot in varnames.
def name_load_opcode(g: cfg_builder, name: str) -> int {
    if fast_local_index(g, name) >= 0 {
        return OP_LOAD_FAST;
    }
    if g.sym_top is None or g.sym_top.block_type == "module" {
        return OP_LOAD_NAME;
    }
    flags = sym_dict_get(g.sym_top.symbols, name, 0);
    scope = sym_scope_of(flags);
    if scope == SCOPE_GLOBAL_EXPLICIT or scope == SCOPE_GLOBAL_IMPLICIT {
        return OP_LOAD_GLOBAL;
    }
    return OP_LOAD_NAME;
}

# AST class name for unsupported-node diagnostics (ordered isinstance chain).
def ast_node_name(n: ast_node) -> str {
    if isinstance(n, BoolOp) {
        return "BoolOp";
    }
    if isinstance(n, NamedExpr) {
        return "NamedExpr";
    }
    if isinstance(n, BinOp) {
        return "BinOp";
    }
    if isinstance(n, UnaryOp) {
        return "UnaryOp";
    }
    if isinstance(n, Lambda) {
        return "Lambda";
    }
    if isinstance(n, IfExp) {
        return "IfExp";
    }
    if isinstance(n, Dict) {
        return "Dict";
    }
    if isinstance(n, Set) {
        return "Set";
    }
    if isinstance(n, ListComp) {
        return "ListComp";
    }
    if isinstance(n, SetComp) {
        return "SetComp";
    }
    if isinstance(n, DictComp) {
        return "DictComp";
    }
    if isinstance(n, GeneratorExp) {
        return "GeneratorExp";
    }
    if isinstance(n, Await) {
        return "Await";
    }
    if isinstance(n, Yield) {
        return "Yield";
    }
    if isinstance(n, YieldFrom) {
        return "YieldFrom";
    }
    if isinstance(n, Compare) {
        return "Compare";
    }
    if isinstance(n, Call) {
        return "Call";
    }
    if isinstance(n, FormattedValue) {
        return "FormattedValue";
    }
    if isinstance(n, JoinedStr) {
        return "JoinedStr";
    }
    if isinstance(n, Interpolation) {
        return "Interpolation";
    }
    if isinstance(n, TemplateStr) {
        return "TemplateStr";
    }
    if isinstance(n, Constant) {
        return "Constant";
    }
    if isinstance(n, Attribute) {
        return "Attribute";
    }
    if isinstance(n, Subscript) {
        return "Subscript";
    }
    if isinstance(n, Starred) {
        return "Starred";
    }
    if isinstance(n, Name) {
        return "Name";
    }
    if isinstance(n, List) {
        return "List";
    }
    if isinstance(n, Tuple) {
        return "Tuple";
    }
    if isinstance(n, Slice) {
        return "Slice";
    }
    if isinstance(n, FunctionDef) {
        return "FunctionDef";
    }
    if isinstance(n, AsyncFunctionDef) {
        return "AsyncFunctionDef";
    }
    if isinstance(n, ClassDef) {
        return "ClassDef";
    }
    if isinstance(n, Return) {
        return "Return";
    }
    if isinstance(n, Delete) {
        return "Delete";
    }
    if isinstance(n, Assign) {
        return "Assign";
    }
    if isinstance(n, TypeAlias) {
        return "TypeAlias";
    }
    if isinstance(n, AugAssign) {
        return "AugAssign";
    }
    if isinstance(n, AnnAssign) {
        return "AnnAssign";
    }
    if isinstance(n, For) {
        return "For";
    }
    if isinstance(n, AsyncFor) {
        return "AsyncFor";
    }
    if isinstance(n, While) {
        return "While";
    }
    if isinstance(n, If) {
        return "If";
    }
    if isinstance(n, With) {
        return "With";
    }
    if isinstance(n, AsyncWith) {
        return "AsyncWith";
    }
    if isinstance(n, Match) {
        return "Match";
    }
    if isinstance(n, Raise) {
        return "Raise";
    }
    if isinstance(n, Try) {
        return "Try";
    }
    if isinstance(n, TryStar) {
        return "TryStar";
    }
    if isinstance(n, Assert) {
        return "Assert";
    }
    if isinstance(n, Import) {
        return "Import";
    }
    if isinstance(n, ImportFrom) {
        return "ImportFrom";
    }
    if isinstance(n, Global) {
        return "Global";
    }
    if isinstance(n, Nonlocal) {
        return "Nonlocal";
    }
    if isinstance(n, Expr) {
        return "Expr";
    }
    if isinstance(n, Pass) {
        return "Pass";
    }
    if isinstance(n, Break) {
        return "Break";
    }
    if isinstance(n, Continue) {
        return "Continue";
    }
    return "ast_node";
}

# Normalize an AST node's location: end_lineno is int|None; None means "same as
# lineno" (CPython's convention for single-line nodes).
def nloc(lineno: int, end_ln: int | None, col: int, end_col: int | None) -> cloc {
    el = lineno;
    if end_ln is not None {
        el = end_ln as int;
    }
    ec = -1;
    if end_col is not None {
        ec = end_col as int;
    }
    return loc(lineno, el, col, ec);
}

# Operator AST node -> NB_* binary-op id (opcode.h).
def binop_id(op: PyObj) -> int {
    if isinstance(op, Add) {
        return NB_ADD;
    }
    if isinstance(op, Sub) {
        return NB_SUBTRACT;
    }
    if isinstance(op, Mult) {
        return NB_MULTIPLY;
    }
    if isinstance(op, Div) {
        return NB_TRUE_DIVIDE;
    }
    if isinstance(op, FloorDiv) {
        return NB_FLOOR_DIVIDE;
    }
    if isinstance(op, Mod) {
        return NB_REMAINDER;
    }
    if isinstance(op, Pow) {
        return NB_POWER;
    }
    if isinstance(op, LShift) {
        return NB_LSHIFT;
    }
    if isinstance(op, RShift) {
        return NB_RSHIFT;
    }
    if isinstance(op, BitOr) {
        return NB_OR;
    }
    if isinstance(op, BitXor) {
        return NB_XOR;
    }
    if isinstance(op, BitAnd) {
        return NB_AND;
    }
    if isinstance(op, MatMult) {
        return NB_MATRIX_MULTIPLY;
    }
    return -1;
}

# AugAssign operator -> NB_INPLACE_* id (opcode.h).
def inplace_binop_id(op: PyObj) -> int {
    if isinstance(op, Add) {
        return NB_INPLACE_ADD;
    }
    if isinstance(op, Sub) {
        return NB_INPLACE_SUBTRACT;
    }
    if isinstance(op, Mult) {
        return NB_INPLACE_MULTIPLY;
    }
    if isinstance(op, Div) {
        return NB_INPLACE_TRUE_DIVIDE;
    }
    if isinstance(op, FloorDiv) {
        return NB_INPLACE_FLOOR_DIVIDE;
    }
    if isinstance(op, Mod) {
        return NB_INPLACE_REMAINDER;
    }
    if isinstance(op, Pow) {
        return NB_INPLACE_POWER;
    }
    if isinstance(op, LShift) {
        return NB_INPLACE_LSHIFT;
    }
    if isinstance(op, RShift) {
        return NB_INPLACE_RSHIFT;
    }
    if isinstance(op, BitOr) {
        return NB_INPLACE_OR;
    }
    if isinstance(op, BitXor) {
        return NB_INPLACE_XOR;
    }
    if isinstance(op, BitAnd) {
        return NB_INPLACE_AND;
    }
    if isinstance(op, MatMult) {
        return NB_INPLACE_MATRIX_MULTIPLY;
    }
    return -1;
}

# Source span for an expression node (store/load/delete targets and calls).
def expr_loc(e: expr) -> cloc {
    if isinstance(e, Name) {
        n = e as Name;
        return nloc(n.lineno, n.end_lineno, n.col_offset, n.end_col_offset);
    }
    if isinstance(e, Attribute) {
        a = e as Attribute;
        return nloc(a.lineno, a.end_lineno, a.col_offset, a.end_col_offset);
    }
    if isinstance(e, Subscript) {
        s = e as Subscript;
        return nloc(s.lineno, s.end_lineno, s.col_offset, s.end_col_offset);
    }
    if isinstance(e, Constant) {
        c = e as Constant;
        return nloc(c.lineno, c.end_lineno, c.col_offset, c.end_col_offset);
    }
    if isinstance(e, BinOp) {
        b = e as BinOp;
        return nloc(b.lineno, b.end_lineno, b.col_offset, b.end_col_offset);
    }
    if isinstance(e, UnaryOp) {
        un = e as UnaryOp;
        return nloc(un.lineno, un.end_lineno, un.col_offset, un.end_col_offset);
    }
    if isinstance(e, Call) {
        ca = e as Call;
        return nloc(ca.lineno, ca.end_lineno, ca.col_offset, ca.end_col_offset);
    }
    if isinstance(e, Compare) {
        c = e as Compare;
        return nloc(c.lineno, c.end_lineno, c.col_offset, c.end_col_offset);
    }
    if isinstance(e, ListComp) {
        lc = e as ListComp;
        return nloc(lc.lineno, lc.end_lineno, lc.col_offset, lc.end_col_offset);
    }
    if isinstance(e, SetComp) {
        sc = e as SetComp;
        return nloc(sc.lineno, sc.end_lineno, sc.col_offset, sc.end_col_offset);
    }
    if isinstance(e, DictComp) {
        dc = e as DictComp;
        return nloc(dc.lineno, dc.end_lineno, dc.col_offset, dc.end_col_offset);
    }
    if isinstance(e, Tuple) {
        t = e as Tuple;
        return nloc(t.lineno, t.end_lineno, t.col_offset, t.end_col_offset);
    }
    return loc(1, 1, 0, 0);
}

# Fold a constant Slice AST node into a PySlice const, or None if non-constant.
def fold_slice_const(sl: Slice) -> PyObj | None {
    lo: PyObj = py_none();
    if sl.lower is not None {
        if not isinstance(sl.lower, Constant) {
            return None;
        }
        lo = (sl.lower as Constant).value;
    }
    up: PyObj = py_none();
    if sl.upper is not None {
        if not isinstance(sl.upper, Constant) {
            return None;
        }
        up = (sl.upper as Constant).value;
    }
    st: PyObj = py_none();
    if sl.step is not None {
        if not isinstance(sl.step, Constant) {
            return None;
        }
        st = (sl.step as Constant).value;
    }
    return PySlice(t="slice", start=lo, stop=up, step=st);
}

# Emit the subscript key (index or constant slice) onto the stack.
# register_small_int: CPython keeps small-index literals in co_consts for
# BINARY_OP[] loads but not for STORE_SUBSCR stores (byte-exact parity).
def visit_subscript_index(
    g: cfg_builder, key: expr, lc: cloc, register_small_int: bool = False
) {
    if isinstance(key, Slice) {
        folded = fold_slice_const(key as Slice);
        if folded is not None {
            idx = g.u.add_const(folded);
            g.emit_op(OP_LOAD_CONST, idx, lc);
            return;
        }
    }
    if isinstance(key, Constant) {
        cv = (key as Constant).value;
        if isinstance(cv, PyInt) {
            kloc = expr_loc(key);
            if register_small_int {
                g.u.add_const((key as Constant).value);
            }
            emit_folded_int(g, (cv as PyInt).val, kloc);
            return;
        }
    }
    visit_expr(g, key);
}

# UnaryOp AST node -> opcode (None if the operator maps to no instruction in
# this slice; the caller reports it loudly).
def unary_opcode(op: PyObj) -> int {
    if isinstance(op, USub) {
        return OP_UNARY_NEGATIVE;
    }
    if isinstance(op, Invert) {
        return OP_UNARY_INVERT;
    }
    if isinstance(op, Not) {
        return OP_UNARY_NOT;
    }
    return -1;
}

# cmpop AST node -> CMP_* rich-compare kind (cmp_op tuple order).
def ast_cmp_kind(op: PyObj) -> int {
    if isinstance(op, Lt) {
        return CMP_LT;
    }
    if isinstance(op, LtE) {
        return CMP_LE;
    }
    if isinstance(op, Eq) {
        return CMP_EQ;
    }
    if isinstance(op, NotEq) {
        return CMP_NE;
    }
    if isinstance(op, Gt) {
        return CMP_GT;
    }
    if isinstance(op, GtE) {
        return CMP_GE;
    }
    return -1;
}

# cmpop -> CPython 3.14 COMPARE_OP oparg (low bits carry cache metadata).
def cmpop_oparg(op: PyObj) -> int {
    kind = ast_cmp_kind(op);
    if kind < 0 {
        return -1;
    }
    return compare_oparg(kind);
}

# Comprehension filters use bool-context compare opargs (base | 16).
def cmpop_filter_oparg(op: PyObj) -> int {
    kind = ast_cmp_kind(op);
    if kind < 0 {
        return -1;
    }
    return compare_filter_oparg(kind);
}

# Chained-compare lowering (compile.c): keep the middle operand on the stack
# across links; short-circuit on the first false with SWAP/POP cleanup.
# false_shortcircuit_returns: only the eval-mode top-level expression may return
# from the module on a false chain link. use_join: fall through to a shared join
# block (BoolOp rhs); otherwise return the cleanup block for suffix duplication.
def visit_compare(
    g: cfg_builder, c: Compare, false_shortcircuit_returns: bool, use_join: bool = True
) -> basicblock | None {
    n = len(c.ops);
    cloc_cmp = nloc(c.lineno, c.end_lineno, c.col_offset, c.end_col_offset);
    visit_expr(g, c.left, false_shortcircuit_returns=false_shortcircuit_returns);
    cleanup: basicblock | None = None;
    if n > 1 {
        cleanup = g.new_block();
    }
    ei = 0;
    while ei < n {
        visit_expr(g, c.comparators[ei]);
        if n > 1 and ei == 0 {
            g.emit_op(OP_SWAP, 2, cloc_cmp);
            g.emit_op(OP_COPY, 2, cloc_cmp);
        }
        oparg = cmpop_oparg(c.ops[ei]);
        if oparg < 0 {
            codegen_fail(g, "NotImplementedError", "unsupported comparison operator");
            return None;
        }
        g.emit_op(OP_COMPARE_OP, oparg, cloc_cmp);
        if ei < n - 1 {
            g.emit_op(OP_COPY, 1, cloc_cmp);
            g.emit_op(OP_TO_BOOL, 0, cloc_cmp);
            if cleanup is not None {
                g.emit_jump(OP_POP_JUMP_IF_FALSE, cleanup.id, cloc_cmp);
            }
            g.emit_op(OP_POP_TOP, 0, cloc_cmp);
        }
        ei = ei + 1;
    }
    if cleanup is not None {
        if false_shortcircuit_returns {
            main_blk = g.cur;
            g.use(cleanup);
            g.emit_op(OP_SWAP, 2, cloc_cmp);
            g.emit_op(OP_POP_TOP, 0, cloc_cmp);
            g.emit_op(OP_RETURN_VALUE, 0, cloc_cmp);
            g.use(main_blk);
            return None;
        }
        if use_join {
            join = g.new_block();
            g.emit_jump(OP_JUMP_FORWARD, join.id, cloc_cmp);
            g.use(cleanup);
            g.emit_op(OP_SWAP, 2, cloc_cmp);
            g.emit_op(OP_POP_TOP, 0, cloc_cmp);
            g.use(join);
            return None;
        }
        return cleanup;
    }
    return None;
}

def emit_compare_cleanup(g: cfg_builder, cleanup: basicblock, lc: cloc) {
    g.use(cleanup);
    g.emit_op(OP_SWAP, 2, lc);
    g.emit_op(OP_POP_TOP, 0, lc);
}

# Constant-fold a BinOp when both operands are literal ints (CPython peephole).
def try_fold_binop(left: expr, op: PyObj, right: expr) -> PyObj | None {
    if not isinstance(left, Constant) {
        return None;
    }
    if not isinstance(right, Constant) {
        return None;
    }
    lc = left as Constant;
    rc = right as Constant;
    if not isinstance(lc.value, PyInt) {
        return None;
    }
    if not isinstance(rc.value, PyInt) {
        return None;
    }
    lv = (lc.value as PyInt).val;
    rv = (rc.value as PyInt).val;
    if isinstance(op, Add) {
        return PyInt(t="int", val=lv + rv);
    }
    return None;
}

# Emit a folded literal: LOAD_SMALL_INT for 0..255, else LOAD_CONST.
def emit_folded_int(g: cfg_builder, v: int, lc: cloc) {
    if v >= 0 and v <= 255 {
        g.emit_op(OP_LOAD_SMALL_INT, v, lc);
        return;
    }
    idx = g.u.add_const(PyInt(t="int", val=v));
    g.emit_op(OP_LOAD_CONST, idx, lc);
}

# BoolOp lowering (compile.c): short-circuit and/or chains with COPY/TO_BOOL.
# Returns the false-exit block when false_shortcircuit_returns so the caller
# can place its RETURN after the true-path suffix (CPython block layout).
def visit_boolop(
    g: cfg_builder, b: BoolOp, false_shortcircuit_returns: bool
) -> basicblock | None {
    bl = nloc(b.lineno, b.end_lineno, b.col_offset, b.end_col_offset);
    n = len(b.values);
    if n < 2 {
        codegen_fail(g, "NotImplementedError", "BoolOp requires at least two values");
        return None;
    }
    is_and = isinstance(b.op, And);
    is_or = isinstance(b.op, Or);
    if not is_and and not is_or {
        codegen_fail(g, "NotImplementedError", "unsupported boolean operator");
        return None;
    }
    jump_op = OP_POP_JUMP_IF_FALSE;
    if is_or {
        jump_op = OP_POP_JUMP_IF_TRUE;
    }
    join: basicblock | None = None;
    if not false_shortcircuit_returns {
        join = g.new_block();
    }
    false_exit: basicblock | None = None;
    vi = 0;
    while vi < n - 1 {
        visit_expr(g, b.values[vi]);
        if false_shortcircuit_returns and false_exit is None {
            false_exit = g.new_block();
        }
        g.emit_op(OP_COPY, 1, bl);
        g.emit_op(OP_TO_BOOL, 0, bl);
        if false_shortcircuit_returns {
            false_target = false_exit.id;
        } else {
            false_target = join.id;
        }
        g.emit_jump(jump_op, false_target, bl);
        g.emit_op(OP_POP_TOP, 0, bl);
        vi = vi + 1;
    }
    visit_expr(g, b.values[n - 1]);
    if join is not None {
        g.emit_jump(OP_JUMP_FORWARD, join.id, bl);
        g.use(join);
        return None;
    }
    if false_shortcircuit_returns {
        return false_exit;
    }
    return None;
}

# Visit one expression. Returns a chained-compare cleanup block when the caller
# must duplicate its suffix (CALL / STORE), else None.
def visit_expr(
    g: cfg_builder,
    e: expr,
    false_shortcircuit_returns: bool = False,
    compare_use_join: bool = True,
    register_int_const: bool = True
) -> basicblock | None {
    if codegen_busy(g) {
        return None;
    }
    if isinstance(e, Constant) {
        c = e as Constant;
        cloc = nloc(c.lineno, c.end_lineno, c.col_offset, c.end_col_offset);
        if isinstance(c.value, PyInt) {
            v = (c.value as PyInt).val;
            if register_int_const
                and v >= 0
                and v <= 255
                and not g.u.dead_small_int_const {
                g.u.add_const(c.value);
                g.u.dead_small_int_const = True;
            } elif register_int_const and (v < 0 or v > 255) {
                g.u.add_const(c.value);
            }
            emit_folded_int(g, v, cloc);
            return None;
        }
        idx = g.u.add_const(c.value);
        g.emit_op(OP_LOAD_CONST, idx, cloc);
        return None;
    }
    if isinstance(e, Name) {
        n = e as Name;
        emit_name_load(
            g,
            n.id,
            nloc(n.lineno, n.end_lineno, n.col_offset, n.end_col_offset)
        );
        return None;
    }
    if isinstance(e, BinOp) {
        b = e as BinOp;
        bl = nloc(b.lineno, b.end_lineno, b.col_offset, b.end_col_offset);
        if isinstance(b.left, Constant) {
            g.u.add_const((b.left as Constant).value);
        }
        if isinstance(b.right, Constant) {
            g.u.add_const((b.right as Constant).value);
        }
        folded = try_fold_binop(b.left, b.op, b.right);
        if folded is not None and isinstance(folded, PyInt) {
            emit_folded_int(g, (folded as PyInt).val, bl);
            return None;
        }
        opid = binop_id(b.op);
        if opid < 0 {
            codegen_fail(g, "NotImplementedError", "unsupported binary operator");
            return None;
        }
        if try_emit_fast_local_pair_load(g, b.left, b.right, bl) {
            g.emit_op(OP_BINARY_OP, opid, bl);
            return None;
        }
        visit_expr(g, b.left);
        visit_expr(g, b.right);
        g.emit_op(OP_BINARY_OP, opid, bl);
        return None;
    }
    if isinstance(e, UnaryOp) {
        un = e as UnaryOp;
        visit_expr(g, un.operand);
        opc = unary_opcode(un.op);
        if opc < 0 {
            codegen_fail(g, "NotImplementedError", "unsupported unary operator");
            return None;
        }
        g.emit_op(
            opc, 0, nloc(un.lineno, un.end_lineno, un.col_offset, un.end_col_offset)
        );
        return None;
    }
    if isinstance(e, Compare) {
        return visit_compare(
            g, e as Compare, false_shortcircuit_returns, compare_use_join
        );
    }
    if isinstance(e, BoolOp) {
        return visit_boolop(g, e as BoolOp, false_shortcircuit_returns);
    }
    if isinstance(e, Call) {
        ca = e as Call;
        floc = call_func_loc(ca.func);
        if isinstance(ca.func, Name) {
            nf = ca.func as Name;
            nloc_fn = nloc(
                nf.lineno, nf.end_lineno, nf.col_offset, nf.end_col_offset
            );
            needs_null = emit_name_load(g, nf.id, nloc_fn, True);
            if needs_null {
                g.emit_op(OP_PUSH_NULL, 0, floc);
            }
        } elif isinstance(ca.func, Attribute) {
            attr = ca.func as Attribute;
            aloc = expr_loc(attr);
            visit_expr(g, attr.value);
            idx = g.u.add_name(attr.attr);
            g.emit_op(OP_LOAD_ATTR, (idx << 1) | 1, aloc);
        } else {
            visit_expr(g, ca.func);
            g.emit_op(OP_PUSH_NULL, 0, floc);
        }
        cmp_cleanup: basicblock | None = None;
        call_args = call_effective_args(ca);
        ai = 0;
        while ai < len(call_args) {
            arg_cleanup = visit_expr(
                g, call_args[ai], False, False, not g.u.nested_code_emitted
            );
            if arg_cleanup is not None {
                cmp_cleanup = arg_cleanup;
            }
            ai = ai + 1;
        }
        cloc_call = nloc(ca.lineno, ca.end_lineno, ca.col_offset, ca.end_col_offset);
        kws = call_effective_keywords(ca);
        if len(kws) > 0 {
            emit_call_keyword_values(
                g, ca, cloc_call, False, not g.u.nested_code_emitted
            );
            if codegen_busy(g) {
                return cmp_cleanup;
            }
        }
        emit_call_instruction(g, ca, cloc_call);
        return cmp_cleanup;
    }
    if isinstance(e, Attribute) {
        a = e as Attribute;
        aloc = expr_loc(a);
        visit_expr(g, a.value);
        idx = g.u.add_name(a.attr);
        g.emit_op(OP_LOAD_ATTR, idx * 2, aloc);
        return None;
    }
    if isinstance(e, Subscript) {
        s = e as Subscript;
        sloc = expr_loc(s);
        visit_expr(g, s.value);
        visit_subscript_index(g, s.slice, sloc, True);
        g.emit_op(OP_BINARY_OP, NB_SUBSCR, sloc);
        return None;
    }
    if isinstance(e, ListComp) {
        visit_list_comp(g, e as ListComp);
        return None;
    }
    if isinstance(e, SetComp) {
        visit_set_comp(g, e as SetComp);
        return None;
    }
    if isinstance(e, DictComp) {
        visit_dict_comp(g, e as DictComp);
        return None;
    }
    if isinstance(e, Lambda) {
        visit_lambda(g, e as Lambda);
        return None;
    }
    codegen_fail(
        g,
        "NotImplementedError",
        "unsupported expression: " + ast_node_name(e as ast_node)
    );
    return None;
}

# The callable's location, used for PUSH_NULL. For the slice the callable is a
# Name; this stays general for future Attribute/method lowering.
def call_func_loc(f: expr) -> cloc {
    return expr_loc(f);
}

def call_effective_args(ca: Call) -> list[expr] {
    args = ca.args;
    if args is None {
        args = [];
    }
    return args;
}

def call_effective_keywords(ca: Call) -> list[keyword] {
    kws = ca.keywords;
    if kws is None {
        kws = [];
    }
    return kws;
}

# Push keyword-argument values, then the names tuple (bottom -> top: vals…, names).
def emit_call_keyword_values(
    g: cfg_builder,
    ca: Call,
    cloc_call: cloc,
    comp_mode: bool = False,
    register_int_const: bool = True
) {
    kws = call_effective_keywords(ca);
    ki = 0;
    while ki < len(kws) {
        kw = kws[ki];
        if kw.arg is None {
            codegen_fail(
                g, "NotImplementedError", "keyword argument unpacking not supported"
            );
            return;
        }
        if comp_mode {
            visit_comp_elt(g, kw.value, [], False);
        } else {
            visit_expr(g, kw.value, False, False, register_int_const);
        }
        if codegen_busy(g) {
            return;
        }
        ki = ki + 1;
    }
    if len(kws) == 0 {
        return;
    }
    names: list[PyObj] = [];
    ki = 0;
    while ki < len(kws) {
        names.append(PyStr(t="str", val=kws[ki].arg));
        ki = ki + 1;
    }
    tup = PyTuple(t="tuple", items=names);
    tidx = g.u.add_const(tup);
    g.emit_op(OP_LOAD_CONST, tidx, cloc_call);
}

# Positional and keyword values must already be on the stack (names tuple last for CALL_KW).
def emit_call_instruction(g: cfg_builder, ca: Call, cloc_call: cloc) {
    args = call_effective_args(ca);
    kws = call_effective_keywords(ca);
    if len(kws) > 0 {
        ki = 0;
        while ki < len(kws) {
            if kws[ki].arg is None {
                codegen_fail(
                    g, "NotImplementedError", "keyword argument unpacking not supported"
                );
                return;
            }
            ki = ki + 1;
        }
        g.emit_op(OP_CALL_KW, len(args) + len(kws), cloc_call);
    } else {
        g.emit_op(OP_CALL, len(args), cloc_call);
    }
}

# The top-level expression's location, assigned to the trailing RETURN_VALUE in
# eval mode (matches CPython's observed co_positions).
def top_loc(e: expr) -> cloc {
    return expr_loc(e);
}

# Build a unverified_cfg for an eval-mode expression. Emits RESUME (module/eval
# scope: lineno 0), the expression, then RETURN_VALUE carrying the expression's
# span. addNone is false for eval (no trailing None push).
def compile_eval(
    e: expr, filename: str, name: str, firstlineno: int
) -> unverified_cfg {
    u = unverified_cfg(
        filename=filename, name=name, qualname=name, firstlineno=firstlineno
    );
    entry = u.add_block();
    g = new_cfg_builder(u, entry);
    g.emit_op(OP_RESUME, 0, loc(0, firstlineno, 0, 0));
    cleanup = visit_expr(g, e, false_shortcircuit_returns=True);
    if codegen_busy(g) {
        return u;
    }
    eloc = top_loc(e);
    g.emit_op(OP_RETURN_VALUE, 0, eloc);
    if cleanup is not None {
        if isinstance(e, Call) {
            ca = e as Call;
            cloc_call = nloc(
                ca.lineno, ca.end_lineno, ca.col_offset, ca.end_col_offset
            );
            emit_compare_cleanup(g, cleanup, cloc_call);
            if len(call_effective_keywords(ca)) > 0 {
                emit_call_keyword_values(g, ca, cloc_call);
            }
            emit_call_instruction(g, ca, cloc_call);
            g.emit_op(OP_RETURN_VALUE, 0, eloc);
        } else {
            g.use(cleanup);
            g.emit_op(OP_RETURN_VALUE, 0, eloc);
        }
    }
    return u;
}

# ---------------- exec mode (statements, PLAN.md P0.12 band 2) ----------------
#
# visit_stmt lowers the straight-line statement set (Assign / Expr / Pass) into
# the current block. Returns the source location carried by the last instruction
# it emitted -- CPython's implicit module return (LOAD_CONST None; RETURN_VALUE)
# is generated with NO_LOCATION and inherits the preceding instruction's
# location, so compile_exec uses this return value for the epilogue. A statement
# that emits no instructions (Pass) returns its own location so the epilogue
# still lands on the statement's span (matches CPython's location fixup).

def stmt_loc(s: stmt) -> cloc {
    if isinstance(s, Assign) {
        a = s as Assign;
        # CPython attributes STORE_NAME to the assignment target's span, not the
        # whole Assign. For band 2 the target is a single Name.
        if len(a.targets) > 0 {
            return expr_loc(a.targets[0]);
        }
        return nloc(a.lineno, a.end_lineno, a.col_offset, a.end_col_offset);
    }
    if isinstance(s, AugAssign) {
        aa = s as AugAssign;
        return expr_loc(aa.target);
    }
    if isinstance(s, Delete) {
        d = s as Delete;
        return nloc(d.lineno, d.end_lineno, d.col_offset, d.end_col_offset);
    }
    if isinstance(s, Return) {
        r = s as Return;
        return nloc(r.lineno, r.end_lineno, r.col_offset, r.end_col_offset);
    }
    if isinstance(s, Expr) {
        x = s as Expr;
        return nloc(x.lineno, x.end_lineno, x.col_offset, x.end_col_offset);
    }
    if isinstance(s, Pass) {
        p = s as Pass;
        return nloc(p.lineno, p.end_lineno, p.col_offset, p.end_col_offset);
    }
    if isinstance(s, If) {
        i = s as If;
        return nloc(i.lineno, i.end_lineno, i.col_offset, i.end_col_offset);
    }
    if isinstance(s, While) {
        w = s as While;
        return nloc(w.lineno, w.end_lineno, w.col_offset, w.end_col_offset);
    }
    if isinstance(s, For) {
        f = s as For;
        return nloc(f.lineno, f.end_lineno, f.col_offset, f.end_col_offset);
    }
    if isinstance(s, Break) {
        b = s as Break;
        return nloc(b.lineno, b.end_lineno, b.col_offset, b.end_col_offset);
    }
    if isinstance(s, Continue) {
        c = s as Continue;
        return nloc(c.lineno, c.end_lineno, c.col_offset, c.end_col_offset);
    }
    return loc(1, 1, 0, 0);
}

# Store value already on the stack into an assignment target (name / attribute /
# subscript). CPython stack layout before STORE_ATTR / STORE_SUBSCR: value below
# owner (and index for subscript), with owner/index on TOS.
def visit_store_target_tos(g: cfg_builder, t: expr) -> stmt_cont {
    if codegen_busy(g) {
        return stmt_cont(loc=expr_loc(t));
    }
    if isinstance(t, Name) {
        n = t as Name;
        tloc = expr_loc(n);
        emit_name_store(g, n.id, tloc);
        return stmt_cont(loc=tloc);
    }
    if isinstance(t, Attribute) {
        a = t as Attribute;
        visit_expr(g, a.value);
        idx = g.u.add_name(a.attr);
        tloc = expr_loc(a);
        g.emit_op(OP_STORE_ATTR, idx, tloc);
        return stmt_cont(loc=tloc);
    }
    if isinstance(t, Subscript) {
        s = t as Subscript;
        sloc = expr_loc(s);
        visit_expr(g, s.value);
        visit_subscript_index(g, s.slice, sloc);
        g.emit_op(OP_STORE_SUBSCR, 0, sloc);
        return stmt_cont(loc=sloc);
    }
    codegen_fail(
        g,
        "NotImplementedError",
        "unsupported assignment target: " + ast_node_name(t as ast_node)
    );
    return stmt_cont(loc=expr_loc(t));
}

# Store value into an assignment target (name / attribute / subscript).
def visit_store_target(g: cfg_builder, t: expr, value: expr) -> stmt_cont {
    visit_expr(g, value);
    return visit_store_target_tos(g, t);
}

# Delete one target (name / attribute / subscript).
def visit_delete_target(g: cfg_builder, t: expr) -> stmt_cont {
    if codegen_busy(g) {
        return stmt_cont(loc=expr_loc(t));
    }
    if isinstance(t, Name) {
        n = t as Name;
        idx = g.u.add_name(n.id);
        tloc = expr_loc(n);
        g.emit_op(OP_DELETE_NAME, idx, tloc);
        return stmt_cont(loc=tloc);
    }
    if isinstance(t, Attribute) {
        a = t as Attribute;
        visit_expr(g, a.value);
        idx = g.u.add_name(a.attr);
        tloc = expr_loc(a);
        g.emit_op(OP_DELETE_ATTR, idx, tloc);
        return stmt_cont(loc=tloc);
    }
    if isinstance(t, Subscript) {
        s = t as Subscript;
        visit_expr(g, s.value);
        visit_subscript_index(g, s.slice, expr_loc(s));
        tloc = expr_loc(s);
        g.emit_op(OP_DELETE_SUBSCR, 0, tloc);
        return stmt_cont(loc=tloc);
    }
    codegen_fail(
        g,
        "NotImplementedError",
        "unsupported deletion target: " + ast_node_name(t as ast_node)
    );
    return stmt_cont(loc=expr_loc(t));
}

# True when any statement from from_idx onward emits bytecode (Pass alone does not).
def exec_tail_emits_code(body: list[stmt], from_idx: int) -> bool {
    si = from_idx;
    while si < len(body) {
        if not isinstance(body[si], Pass) {
            return True;
        }
        si = si + 1;
    }
    return False;
}

def fast_local_index(g: cfg_builder, name: str) -> int {
    vi = 0;
    while vi < len(g.u.varnames) {
        if g.u.varnames[vi] == name {
            return vi;
        }
        vi = vi + 1;
    }
    return -1;
}

# CPython 3.14 fuses two fast-local loads for binops (e.g. `return x + y`).
def try_emit_fast_local_pair_load(
    g: cfg_builder, left: expr, right: expr, tloc: cloc
) -> bool {
    if not isinstance(left, Name) or not isinstance(right, Name) {
        return False;
    }
    lfi = fast_local_index(g, (left as Name).id);
    rfi = fast_local_index(g, (right as Name).id);
    if lfi < 0 or rfi < 0 {
        return False;
    }
    pair_arg = lfi * 16 + rfi;
    g.emit_op(OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW, pair_arg, tloc);
    return True;
}

def comp_name_bound(name: str, bound_names: list[str]) -> bool {
    bi = 0;
    while bi < len(bound_names) {
        if bound_names[bi] == name {
            return True;
        }
        bi = bi + 1;
    }
    return False;
}

def comp_target_slots(g: cfg_builder, target: expr) -> list[int] | None {
    if isinstance(target, Name) {
        fi = fast_local_index(g, (target as Name).id);
        if fi < 0 {
            return None;
        }
        return [fi];
    }
    if isinstance(target, Tuple) {
        elts = (target as Tuple).elts;
        if len(elts) != 2 {
            return None;
        }
        if not isinstance(elts[0], Name) or not isinstance(elts[1], Name) {
            return None;
        }
        fi0 = fast_local_index(g, (elts[0] as Name).id);
        fi1 = fast_local_index(g, (elts[1] as Name).id);
        if fi0 < 0 or fi1 < 0 {
            return None;
        }
        return [fi0, fi1];
    }
    return None;
}

def comp_bound_names_from_target(target: expr) -> list[str] | None {
    if isinstance(target, Name) {
        return [(target as Name).id];
    }
    if isinstance(target, Tuple) {
        elts = (target as Tuple).elts;
        if len(elts) != 2 {
            return None;
        }
        if not isinstance(elts[0], Name) or not isinstance(elts[1], Name) {
            return None;
        }
        return [(elts[0] as Name).id, (elts[1] as Name).id];
    }
    return None;
}

def comp_name_fast_index(g: cfg_builder, e: expr, bound_names: list[str]) -> int {
    if not isinstance(e, Name) {
        return -1;
    }
    nid = (e as Name).id;
    if not comp_name_bound(nid, bound_names) {
        return -1;
    }
    return fast_local_index(g, nid);
}

def comp_append_handler(
    g: cfg_builder,
    start_blk: int,
    protect_end: int,
    stack_depth: int,
    fast_index: int,
    cloc_comp: cloc,
    handler_group: int,
    second_fast_index: int = -1,
    swap_depth: int = 2
) {
    reg = except_region(
        start_block=start_blk,
        end_block=protect_end,
        handler_block=-1,
        stack_depth=stack_depth
    );
    g.u.except_regions.append(reg);
    g.u.comp_handlers.append(
        comp_handler(
            region_index=len(g.u.except_regions) - 1,
            fast_index=fast_index,
            second_fast_index=second_fast_index,
            swap_depth=swap_depth,
            loc=cloc_comp,
            group=handler_group
        )
    );
}

# Lower a comprehension element expression. The innermost loop target is already
# on the stack from STORE_FAST_LOAD_FAST; references to bound names must not load.
def visit_comp_elt(
    g: cfg_builder, e: expr, bound_names: list[str], filter_compare: bool = False
) {
    if isinstance(e, Name) {
        n = e as Name;
        if comp_name_bound(n.id, bound_names) {
            return;
        }
        visit_expr(g, e);
        return;
    }
    if isinstance(e, Compare) {
        c = e as Compare;
        cloc_cmp = expr_loc(c);
        visit_comp_elt(g, c.left, bound_names, filter_compare);
        if codegen_busy(g) {
            return;
        }
        ci = 0;
        while ci < len(c.comparators) {
            visit_comp_elt(g, c.comparators[ci], bound_names, filter_compare);
            if codegen_busy(g) {
                return;
            }
            oparg = cmpop_oparg(c.ops[ci]);
            if filter_compare {
                oparg = cmpop_filter_oparg(c.ops[ci]);
            }
            if oparg < 0 {
                codegen_fail(
                    g, "NotImplementedError", "unsupported comparison operator"
                );
                return;
            }
            g.emit_op(OP_COMPARE_OP, oparg, cloc_cmp);
            ci = ci + 1;
        }
        return;
    }
    if isinstance(e, Call) {
        ca = e as Call;
        floc = call_func_loc(ca.func);
        visit_comp_elt(g, ca.func, bound_names, filter_compare);
        if codegen_busy(g) {
            return;
        }
        g.emit_op(OP_PUSH_NULL, 0, floc);
        call_args = call_effective_args(ca);
        ai = 0;
        while ai < len(call_args) {
            visit_comp_elt(g, call_args[ai], bound_names, filter_compare);
            if codegen_busy(g) {
                return;
            }
            ai = ai + 1;
        }
        cloc_call = nloc(ca.lineno, ca.end_lineno, ca.col_offset, ca.end_col_offset);
        kws = call_effective_keywords(ca);
        if len(kws) > 0 {
            emit_call_keyword_values(g, ca, cloc_call, True);
            if codegen_busy(g) {
                return;
            }
        }
        emit_call_instruction(g, ca, cloc_call);
        return;
    }
    if isinstance(e, BinOp) {
        b = e as BinOp;
        bl = nloc(b.lineno, b.end_lineno, b.col_offset, b.end_col_offset);
        visit_comp_elt(g, b.left, bound_names, filter_compare);
        if codegen_busy(g) {
            return;
        }
        visit_comp_elt(g, b.right, bound_names, filter_compare);
        if codegen_busy(g) {
            return;
        }
        opid = binop_id(b.op);
        if opid < 0 {
            codegen_fail(g, "NotImplementedError", "unsupported binary operator");
            return;
        }
        g.emit_op(OP_BINARY_OP, opid, bl);
        return;
    }
    if isinstance(e, UnaryOp) {
        un = e as UnaryOp;
        ul = nloc(un.lineno, un.end_lineno, un.col_offset, un.end_col_offset);
        visit_comp_elt(g, un.operand, bound_names, filter_compare);
        if codegen_busy(g) {
            return;
        }
        opc = unary_opcode(un.op);
        if opc < 0 {
            codegen_fail(g, "NotImplementedError", "unsupported unary operator");
            return;
        }
        g.emit_op(opc, 0, ul);
        return;
    }
    visit_expr(g, e);
}

def comp_emit_bind_target(g: cfg_builder, target: expr, slots: list[int]) {
    tloc = expr_loc(target);
    if len(slots) == 1 {
        pair_arg = slots[0] * 16 + slots[0];
        g.emit_op(OP_STORE_FAST_LOAD_FAST, pair_arg, tloc);
        return;
    }
    unpack_loc = tloc;
    store_loc = tloc;
    if isinstance(target, Tuple) {
        elts = (target as Tuple).elts;
        if len(elts) > 0 {
            store_loc = expr_loc(elts[0]);
        }
    }
    g.emit_op(OP_UNPACK_SEQUENCE, len(slots), unpack_loc);
    pair_arg = slots[0] * 16 + slots[1];
    g.emit_op(OP_STORE_FAST_STORE_FAST, pair_arg, store_loc);
}

def comp_emit_filters(
    g: cfg_builder,
    ifs: list[expr],
    bound_names: list[str],
    loop_hdr: basicblock,
    stack_depth: int,
    cloc_comp: cloc,
    fast_index: int,
    region_start: int,
    handler_group: int,
    filter_jump_loc: cloc,
    second_fast_index: int = -1,
    swap_depth: int = 2
) -> tuple[basicblock | None, int] {
    element_entry: basicblock | None = None;
    ii = 0;
    while ii < len(ifs) {
        ife = ifs[ii];
        visit_comp_elt(g, ife, bound_names, True);
        if codegen_busy(g) {
            return (element_entry, region_start);
        }
        filter_post = g.new_block();
        comp_append_handler(
            g,
            region_start,
            filter_post.id,
            stack_depth,
            fast_index,
            cloc_comp,
            handler_group,
            second_fast_index,
            swap_depth
        );
        g.use(filter_post);
        pass_blk = g.new_block();
        g.emit_jump(OP_POP_JUMP_IF_TRUE, pass_blk.id, filter_jump_loc);
        g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, filter_jump_loc);
        g.use(pass_blk);
        region_start = pass_blk.id;
        element_entry = pass_blk;
        ii = ii + 1;
    }
    return (element_entry, region_start);
}

def comp_finish_loop(
    g: cfg_builder,
    loop_hdr: basicblock,
    for_iter_idx: int,
    region_start: int,
    iter_loc: cloc,
    stack_depth: int,
    slots: list[int],
    cloc_comp: cloc,
    handler_group: int,
    second_fast: int,
    swap_depth: int
) {
    after = g.new_block();
    loop_hdr.instrs[for_iter_idx].target_block = after.id;
    g.use(after);
    g.emit_op(OP_END_FOR, 0, iter_loc);
    g.emit_op(OP_POP_ITER, 0, iter_loc);
    protect_end = g.new_block();
    comp_append_handler(
        g,
        region_start,
        protect_end.id,
        stack_depth,
        slots[0],
        cloc_comp,
        handler_group,
        second_fast,
        swap_depth
    );
    g.use(protect_end);
    comp_emit_cleanup(g, slots, cloc_comp, swap_depth);
}

def comp_emit_single_elt(
    g: cfg_builder,
    elt: expr,
    bound_names: list[str],
    add_op: int,
    elt_loc: cloc,
    has_filters: bool,
    filter_jump_loc: cloc | None = None
) {
    emit_loc = elt_loc;
    if has_filters and filter_jump_loc is not None {
        emit_loc = filter_jump_loc;
    }
    if has_filters
        and len(bound_names) == 1
        and isinstance(elt, Name)
        and (elt as Name).id == bound_names[0] {
        fi = fast_local_index(g, (elt as Name).id);
        g.emit_op(OP_LOAD_FAST_BORROW, fi, emit_loc);
        g.emit_op(add_op, 2, emit_loc);
        return;
    }
    visit_comp_elt(g, elt, bound_names);
    if codegen_busy(g) {
        return;
    }
    g.emit_op(add_op, 2, emit_loc);
}

def comp_dict_map_loc(dc: DictComp) -> cloc {
    return nloc(
        dc.key.lineno, dc.value.end_lineno, dc.key.col_offset, dc.value.end_col_offset
    );
}

def visit_comp_dict_kv(
    g: cfg_builder, dc: DictComp, bound_names: list[str], has_filters: bool = False
) {
    kfi = comp_name_fast_index(g, dc.key, bound_names);
    kv_loc = expr_loc(dc.key);
    map_loc = comp_dict_map_loc(dc);
    if isinstance(dc.key, Name) and isinstance(dc.value, Name) and kfi >= 0 {
        vfi = comp_name_fast_index(g, dc.value, bound_names);
        if vfi >= 0 {
            pair_arg = kfi * 16 + vfi;
            g.emit_op(OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW, pair_arg, expr_loc(dc.key));
            g.emit_op(OP_MAP_ADD, 2, map_loc);
            return;
        }
    }
    if isinstance(dc.key, Name) and kfi >= 0 {
        if isinstance(dc.value, BinOp) {
            b = dc.value as BinOp;
            if isinstance(b.left, Name)
                and (b.left as Name).id == (dc.key as Name).id {
                pair_arg = kfi * 16 + kfi;
                pair_loc = expr_loc(b.left);
                if has_filters {
                    pair_loc = expr_loc(dc.key);
                }
                g.emit_op(OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW, pair_arg, pair_loc);
                visit_comp_elt(g, b.right, bound_names);
                if codegen_busy(g) {
                    return;
                }
                opid = binop_id(b.op);
                if opid < 0 {
                    codegen_fail(
                        g, "NotImplementedError", "unsupported binary operator"
                    );
                    return;
                }
                bl = nloc(b.lineno, b.end_lineno, b.col_offset, b.end_col_offset);
                g.emit_op(OP_BINARY_OP, opid, bl);
                g.emit_op(OP_MAP_ADD, 2, map_loc);
                return;
            }
        }
        g.emit_op(OP_LOAD_FAST_BORROW, kfi, kv_loc);
        visit_comp_elt(g, dc.value, bound_names);
        if codegen_busy(g) {
            return;
        }
        g.emit_op(OP_MAP_ADD, 2, map_loc);
        return;
    }
    visit_comp_elt(g, dc.key, bound_names);
    if codegen_busy(g) {
        return;
    }
    visit_comp_elt(g, dc.value, bound_names);
    if codegen_busy(g) {
        return;
    }
    g.emit_op(OP_MAP_ADD, 2, map_loc);
}

def comp_emit_cleanup(
    g: cfg_builder, slots: list[int], cloc_comp: cloc, swap_depth: int
) {
    g.emit_op(OP_SWAP, swap_depth, cloc_comp);
    if len(slots) == 2 {
        g.emit_op(OP_STORE_FAST, slots[1], cloc_comp);
        g.emit_op(OP_STORE_FAST, slots[0], cloc_comp);
        return;
    }
    g.emit_op(OP_STORE_FAST, slots[0], cloc_comp);
}

def comp_emit_setup(
    g: cfg_builder,
    gen: comprehension,
    slots: list[int],
    build_op: int,
    cloc_comp: cloc,
    iter_loc: cloc
) -> tuple[int, basicblock, int] {
    visit_expr(g, gen.iter);
    if codegen_busy(g) {
        loop_hdr = g.new_block();
        return (-1, loop_hdr, -1);
    }
    g.emit_op(OP_GET_ITER, 0, iter_loc);
    si = 0;
    while si < len(slots) {
        g.emit_op(OP_LOAD_FAST_AND_CLEAR, slots[si], cloc_comp);
        si = si + 1;
    }
    swap_depth = 2;
    if len(slots) == 2 {
        swap_depth = 3;
        g.emit_op(OP_SWAP, swap_depth, cloc_comp);
    } else {
        g.emit_op(OP_SWAP, swap_depth, cloc_comp);
    }
    comp_body = g.new_block();
    g.use(comp_body);
    start_blk = g.cur.id;
    g.emit_op(build_op, 0, cloc_comp);
    g.emit_op(OP_SWAP, 2, cloc_comp);
    loop_hdr = g.new_block();
    g.use(loop_hdr);
    for_iter_idx = len(loop_hdr.instrs);
    g.emit_jump(OP_FOR_ITER, 0, iter_loc);
    return (start_blk, loop_hdr, for_iter_idx);
}

# Emit comprehension cleanup handlers after the module RETURN_VALUE (dead code on
# the normal path; reached only via the exception table).
def emit_deferred_comp_handlers(g: cfg_builder) {
    emitted_groups: list[int] = [];
    emitted_blocks: list[int] = [];
    hi = 0;
    while hi < len(g.u.comp_handlers) {
        h = g.u.comp_handlers[hi];
        handler_blk = -1;
        gi = 0;
        while gi < len(emitted_groups) {
            if emitted_groups[gi] == h.group {
                handler_blk = emitted_blocks[gi];
                break;
            }
            gi = gi + 1;
        }
        if handler_blk < 0 {
            handler = g.new_block();
            handler_blk = handler.id;
            emitted_groups.append(h.group);
            emitted_blocks.append(handler_blk);
            g.use(handler);
            noloc = no_loc();
            g.emit_op(OP_SWAP, 2, noloc);
            g.emit_op(OP_POP_TOP, 0, noloc);
            if h.second_fast_index >= 0 {
                g.emit_op(OP_SWAP, 3, h.loc);
                g.emit_op(OP_STORE_FAST, h.second_fast_index, h.loc);
                g.emit_op(OP_STORE_FAST, h.fast_index, h.loc);
            } else {
                g.emit_op(OP_SWAP, h.swap_depth, h.loc);
                g.emit_op(OP_STORE_FAST, h.fast_index, h.loc);
            }
            g.emit_op(OP_RERAISE, 0, h.loc);
        }
        g.u.except_regions[h.region_index].handler_block = handler_blk;
        hi = hi + 1;
    }
}

# Inline list comprehension (module-level / expression context).
def visit_list_comp(g: cfg_builder, lc: ListComp) {
    if len(lc.generators) == 0 {
        codegen_fail(g, "NotImplementedError", "empty list comprehension");
        return;
    }
    gen = lc.generators[0];
    bound_names = comp_bound_names_from_target(gen.target);
    slots = comp_target_slots(g, gen.target);
    if bound_names is None or slots is None {
        codegen_fail(g, "NotImplementedError", "unsupported list comprehension target");
        return;
    }
    cloc_comp = expr_loc(lc);
    iter_loc = expr_loc(gen.iter);
    elt_loc = expr_loc(lc.elt);
    filter_jump_loc = expr_loc(lc.elt);
    handler_group = g.u.comp_handler_group;
    g.u.comp_handler_group = handler_group + 1;
    setup = comp_emit_setup(g, gen, slots, OP_BUILD_LIST, cloc_comp, iter_loc);
    if codegen_busy(g) {
        return;
    }
    start_blk = setup[0];
    loop_hdr = setup[1];
    for_iter_idx = setup[2];
    swap_depth = 2;
    stack_depth = 3;
    second_fast = -1;
    if len(slots) == 2 {
        swap_depth = 3;
        stack_depth = 4;
        second_fast = slots[1];
    }
    comp_emit_bind_target(g, gen.target, slots);
    if codegen_busy(g) {
        return;
    }
    filt = comp_emit_filters(
        g,
        gen.ifs,
        bound_names,
        loop_hdr,
        stack_depth,
        cloc_comp,
        slots[0],
        start_blk,
        handler_group,
        filter_jump_loc,
        second_fast,
        swap_depth
    );
    if codegen_busy(g) {
        return;
    }
    region_start = filt[1];
    comp_emit_single_elt(
        g,
        lc.elt,
        bound_names,
        OP_LIST_APPEND,
        elt_loc,
        len(gen.ifs) > 0,
        filter_jump_loc
    );
    if codegen_busy(g) {
        return;
    }
    if len(gen.ifs) > 0 {
        g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, filter_jump_loc);
    } else {
        g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, elt_loc);
    }
    comp_finish_loop(
        g,
        loop_hdr,
        for_iter_idx,
        region_start,
        iter_loc,
        stack_depth,
        slots,
        cloc_comp,
        handler_group,
        second_fast,
        swap_depth
    );
}

# Inline set comprehension.
def visit_set_comp(g: cfg_builder, sc: SetComp) {
    if len(sc.generators) == 0 {
        codegen_fail(g, "NotImplementedError", "empty set comprehension");
        return;
    }
    gen = sc.generators[0];
    bound_names = comp_bound_names_from_target(gen.target);
    slots = comp_target_slots(g, gen.target);
    if bound_names is None or slots is None {
        codegen_fail(g, "NotImplementedError", "unsupported set comprehension target");
        return;
    }
    cloc_comp = expr_loc(sc);
    iter_loc = expr_loc(gen.iter);
    elt_loc = expr_loc(sc.elt);
    filter_jump_loc = expr_loc(sc.elt);
    handler_group = g.u.comp_handler_group;
    g.u.comp_handler_group = handler_group + 1;
    setup = comp_emit_setup(g, gen, slots, OP_BUILD_SET, cloc_comp, iter_loc);
    if codegen_busy(g) {
        return;
    }
    start_blk = setup[0];
    loop_hdr = setup[1];
    for_iter_idx = setup[2];
    swap_depth = 2;
    stack_depth = 3;
    second_fast = -1;
    if len(slots) == 2 {
        swap_depth = 3;
        stack_depth = 4;
        second_fast = slots[1];
    }
    comp_emit_bind_target(g, gen.target, slots);
    if codegen_busy(g) {
        return;
    }
    filt = comp_emit_filters(
        g,
        gen.ifs,
        bound_names,
        loop_hdr,
        stack_depth,
        cloc_comp,
        slots[0],
        start_blk,
        handler_group,
        filter_jump_loc,
        second_fast,
        swap_depth
    );
    if codegen_busy(g) {
        return;
    }
    region_start = filt[1];
    comp_emit_single_elt(
        g, sc.elt, bound_names, OP_SET_ADD, elt_loc, len(gen.ifs) > 0, filter_jump_loc
    );
    if codegen_busy(g) {
        return;
    }
    if len(gen.ifs) > 0 {
        g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, filter_jump_loc);
    } else {
        g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, elt_loc);
    }
    comp_finish_loop(
        g,
        loop_hdr,
        for_iter_idx,
        region_start,
        iter_loc,
        stack_depth,
        slots,
        cloc_comp,
        handler_group,
        second_fast,
        swap_depth
    );
}

# Inline dict comprehension.
def visit_dict_comp(g: cfg_builder, dc: DictComp) {
    if len(dc.generators) == 0 {
        codegen_fail(g, "NotImplementedError", "empty dict comprehension");
        return;
    }
    gen = dc.generators[0];
    bound_names = comp_bound_names_from_target(gen.target);
    slots = comp_target_slots(g, gen.target);
    if bound_names is None or slots is None {
        codegen_fail(g, "NotImplementedError", "unsupported dict comprehension target");
        return;
    }
    cloc_comp = expr_loc(dc);
    iter_loc = expr_loc(gen.iter);
    filter_jump_loc = comp_dict_map_loc(dc);
    handler_group = g.u.comp_handler_group;
    g.u.comp_handler_group = handler_group + 1;
    setup = comp_emit_setup(g, gen, slots, OP_BUILD_MAP, cloc_comp, iter_loc);
    if codegen_busy(g) {
        return;
    }
    start_blk = setup[0];
    loop_hdr = setup[1];
    for_iter_idx = setup[2];
    swap_depth = 2;
    stack_depth = 3;
    second_fast = -1;
    if len(slots) == 2 {
        swap_depth = 3;
        stack_depth = 4;
        second_fast = slots[1];
    }
    comp_emit_bind_target(g, gen.target, slots);
    if codegen_busy(g) {
        return;
    }
    filt = comp_emit_filters(
        g,
        gen.ifs,
        bound_names,
        loop_hdr,
        stack_depth,
        cloc_comp,
        slots[0],
        start_blk,
        handler_group,
        filter_jump_loc,
        second_fast,
        swap_depth
    );
    if codegen_busy(g) {
        return;
    }
    region_start = filt[1];
    visit_comp_dict_kv(g, dc, bound_names, len(gen.ifs) > 0);
    if codegen_busy(g) {
        return;
    }
    if len(gen.ifs) > 0 {
        g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, filter_jump_loc);
    } else {
        g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, comp_dict_map_loc(dc));
    }
    comp_finish_loop(
        g,
        loop_hdr,
        for_iter_idx,
        region_start,
        iter_loc,
        stack_depth,
        slots,
        cloc_comp,
        handler_group,
        second_fast,
        swap_depth
    );
}

# Module-level epilogue (LOAD_CONST None; RETURN_VALUE).
def emit_module_return(g: cfg_builder, lc: cloc) {
    none_idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, lc);
    g.emit_op(OP_RETURN_VALUE, 0, lc);
}

# Lower statements [from_idx..] in order. When tail/tail_idx are set, the suffix
# starting at tail_idx is the enclosing construct's continuation. tail_join is an
# optional shared join block for nested if/loop tails owned by an outer visitor.
def visit_stmts(
    g: cfg_builder,
    stmts: list[stmt],
    from_idx: int = 0,
    more_follows_after: bool = False,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None
) -> stmt_cont {
    if len(stmts) == 0 or from_idx >= len(stmts) {
        return stmt_cont(loc=loc(1, 1, 0, 0));
    }
    last = stmt_loc(stmts[from_idx]);
    terminated = False;
    si = from_idx;
    while si < len(stmts) {
        follow = more_follows_after;
        if not follow {
            follow = exec_tail_emits_code(stmts, si + 1);
        }
        if not follow and tail is not None {
            follow = exec_tail_emits_code(tail, tail_idx);
        }
        cont = visit_stmt(g, stmts[si], follow, tail, tail_idx, tail_join);
        last = cont.loc;
        if cont.terminated {
            terminated = True;
        }
        if codegen_busy(g) {
            return stmt_cont(loc=last, terminated=terminated);
        }
        if cont.next_si >= 0 {
            si = cont.next_si;
        } else {
            si = si + 1;
        }
    }
    return stmt_cont(loc=last, terminated=terminated);
}

# Lower a statement suffix once at the current block.
def visit_stmt_tail(
    g: cfg_builder, tail: list[stmt], from_idx: int, more_follows_after: bool = False
) -> stmt_cont {
    return visit_stmts(g, tail, from_idx, more_follows_after);
}

# Emit tail suffix and finish the module when CPython duplicates it per branch.
def emit_tail_and_finish(
    g: cfg_builder, tail: list[stmt], tail_idx: int, end_loc: cloc
) -> stmt_cont {
    tail_cont = visit_stmt_tail(g, tail, tail_idx);
    if codegen_busy(g) {
        return tail_cont;
    }
    emit_module_return(g, tail_cont.loc);
    return stmt_cont(loc=end_loc, next_si=len(tail), terminated=True);
}

# Lower an if/while test (CPython bool context): single Compare uses COMPARE_OP
# with bool oparg; other expressions use TO_BOOL after visit_expr.
def visit_test_expr(g: cfg_builder, e: expr, test_loc: cloc) {
    if isinstance(e, Compare) {
        c = e as Compare;
        if len(c.ops) == 1 {
            cloc_cmp = nloc(c.lineno, c.end_lineno, c.col_offset, c.end_col_offset);
            visit_expr(g, c.left);
            visit_expr(g, c.comparators[0]);
            oparg = cmpop_filter_oparg(c.ops[0]);
            if oparg < 0 {
                codegen_fail(
                    g, "NotImplementedError", "unsupported comparison operator"
                );
                return;
            }
            g.emit_op(OP_COMPARE_OP, oparg, cloc_cmp);
            return;
        }
    }
    visit_expr(g, e);
    g.emit_op(OP_TO_BOOL, 0, test_loc);
}

def visit_if(
    g: cfg_builder,
    i: If,
    more_code_follows: bool,
    tail: list[stmt],
    tail_idx: int,
    tail_join: basicblock | None = None
) -> stmt_cont {
    iloc = nloc(i.lineno, i.end_lineno, i.col_offset, i.end_col_offset);
    test_loc = expr_loc(i.test);
    visit_test_expr(g, i.test, test_loc);
    if codegen_busy(g) {
        return stmt_cont(loc=iloc);
    }
    false_blk = g.new_block();
    has_else = len(i.orelse) > 0;
    if more_code_follows {
        tail_more = exec_tail_emits_code(tail, tail_idx);
        if has_else {
            if tail_more {
                join = g.new_block();
                g.emit_jump(OP_POP_JUMP_IF_FALSE, false_blk.id, test_loc);
                body_cont = visit_stmts(g, i.body, 0, False, tail, tail_idx);
                if codegen_busy(g) {
                    return stmt_cont(loc=body_cont.loc);
                }
                if not body_cont.terminated {
                    g.emit_jump(OP_JUMP_FORWARD, join.id, iloc);
                }
                g.use(false_blk);
                else_cont = visit_stmts(g, i.orelse, 0, False, tail, tail_idx);
                if codegen_busy(g) {
                    return stmt_cont(loc=else_cont.loc);
                }
                g.use(join);
                tail_cont = visit_stmt_tail(
                    g, tail, tail_idx, exec_tail_emits_code(tail, tail_idx + 1)
                );
                return stmt_cont(
                    loc=tail_cont.loc,
                    next_si=len(tail),
                    terminated=tail_cont.terminated
                );
            }
            g.emit_jump(OP_POP_JUMP_IF_FALSE, false_blk.id, test_loc);
            body_cont = visit_stmts(g, i.body, 0, False, tail, tail_idx);
            if codegen_busy(g) {
                return stmt_cont(loc=body_cont.loc);
            }
            fin = emit_tail_and_finish(g, tail, tail_idx, iloc);
            if codegen_busy(g) {
                return fin;
            }
            g.use(false_blk);
            else_cont = visit_stmts(g, i.orelse, 0, False, tail, tail_idx);
            if codegen_busy(g) {
                return stmt_cont(loc=else_cont.loc);
            }
            return emit_tail_and_finish(g, tail, tail_idx, iloc);
        }
        join = tail_join;
        owns_tail = False;
        if join is None {
            join = g.new_block();
            owns_tail = True;
        }
        g.emit_jump(OP_POP_JUMP_IF_FALSE, join.id, test_loc);
        body_cont = visit_stmts(g, i.body, 0, False, tail, tail_idx, join);
        if codegen_busy(g) {
            return stmt_cont(loc=body_cont.loc);
        }
        if owns_tail {
            g.use(join);
            tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more);
            return stmt_cont(
                loc=tail_cont.loc,
                next_si=len(tail),
                terminated=tail_cont.terminated
            );
        }
        return stmt_cont(loc=body_cont.loc);
    }
    g.emit_jump(OP_POP_JUMP_IF_FALSE, false_blk.id, test_loc);
    body_cont = visit_stmts(g, i.body);
    if codegen_busy(g) {
        return stmt_cont(loc=body_cont.loc);
    }
    emit_module_return(g, body_cont.loc);
    g.use(false_blk);
    if has_else {
        else_cont = visit_stmts(g, i.orelse);
        if codegen_busy(g) {
            return stmt_cont(loc=else_cont.loc);
        }
        emit_module_return(g, else_cont.loc);
    } else {
        emit_module_return(g, test_loc);
    }
    return stmt_cont(loc=iloc, terminated=True);
}

def visit_while(
    g: cfg_builder, w: While, more_code_follows: bool, tail: list[stmt], tail_idx: int
) -> stmt_cont {
    wloc = nloc(w.lineno, w.end_lineno, w.col_offset, w.end_col_offset);
    test_loc = expr_loc(w.test);
    head = g.new_block();
    g.use(head);
    visit_test_expr(g, w.test, test_loc);
    if codegen_busy(g) {
        return stmt_cont(loc=wloc);
    }
    has_break = loop_body_has_break(w.body);
    if more_code_follows {
        exit_blk = g.new_block();
        g.emit_jump(OP_POP_JUMP_IF_FALSE, exit_blk.id, test_loc);
        break_blk = g.new_block();
        g.push_loop(head, break_blk, has_break);
        body_cont = visit_stmts(g, w.body);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=body_cont.loc);
        }
        if not body_cont.terminated {
            g.emit_jump(OP_JUMP_BACKWARD, head.id, body_cont.loc);
        }
        g.pop_loop();
        tail_more = exec_tail_emits_code(tail, tail_idx);
        if has_break {
            g.use(break_blk);
            g.emit_op(OP_NOP, 0, wloc);
            if tail_more {
                g.emit_jump(OP_JUMP_FORWARD, exit_blk.id, wloc);
            } else {
                br_cont = emit_tail_and_finish(g, tail, tail_idx, wloc);
                if codegen_busy(g) {
                    return br_cont;
                }
            }
        }
        g.use(exit_blk);
        if len(w.orelse) > 0 {
            else_cont = visit_stmts(g, w.orelse);
            if codegen_busy(g) {
                return stmt_cont(loc=else_cont.loc);
            }
        }
        if has_break and not tail_more {
            return stmt_cont(loc=wloc, next_si=len(tail), terminated=True);
        }
        tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more);
        return stmt_cont(loc=tail_cont.loc, next_si=len(tail));
    }
    if len(g.loop_stack) > 0 {
        after_body = g.new_block();
        g.emit_jump(OP_POP_JUMP_IF_FALSE, after_body.id, test_loc);
        if has_break {
            break_blk = g.new_block();
            g.push_loop(head, break_blk, True);
        } else {
            g.push_loop(head, after_body, False);
        }
        body_cont = visit_stmts(g, w.body);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=body_cont.loc);
        }
        if not body_cont.terminated {
            g.emit_jump(OP_JUMP_BACKWARD, head.id, body_cont.loc);
        }
        g.pop_loop();
        if has_break {
            g.use(break_blk);
            g.emit_jump(OP_JUMP_BACKWARD, after_body.id, wloc);
        }
        g.use(after_body);
        return stmt_cont(loc=wloc, terminated=False);
    }
    g.emit_jump(OP_POP_JUMP_IF_FALSE, 0, test_loc);
    pop_false_ins = g.cur.instrs[len(g.cur.instrs) - 1];
    g.push_loop(head, head, False);
    body_cont = visit_stmts(g, w.body);
    if codegen_busy(g) {
        g.pop_loop();
        return stmt_cont(loc=body_cont.loc);
    }
    if not body_cont.terminated {
        g.emit_jump(OP_JUMP_BACKWARD, head.id, body_cont.loc);
    }
    g.pop_loop();
    exit_blk = g.new_block();
    pop_false_ins.target_block = exit_blk.id;
    g.use(exit_blk);
    if len(w.orelse) > 0 {
        else_cont = visit_stmts(g, w.orelse);
        if codegen_busy(g) {
            return stmt_cont(loc=else_cont.loc);
        }
        emit_module_return(g, else_cont.loc);
    } else {
        emit_module_return(g, test_loc);
    }
    return stmt_cont(loc=wloc, terminated=True);
}

def loop_body_has_break(stmts: list[stmt]) -> bool {
    si = 0;
    while si < len(stmts) {
        s = stmts[si];
        if isinstance(s, Break) {
            return True;
        }
        if isinstance(s, If) {
            iff = s as If;
            if loop_body_has_break(iff.body) {
                return True;
            }
            if loop_body_has_break(iff.orelse) {
                return True;
            }
        }
        si = si + 1;
    }
    return False;
}

def visit_for(
    g: cfg_builder, f: For, more_code_follows: bool, tail: list[stmt], tail_idx: int
) -> stmt_cont {
    floc = nloc(f.lineno, f.end_lineno, f.col_offset, f.end_col_offset);
    iter_loc = expr_loc(f.iter);
    visit_expr(g, f.iter);
    if codegen_busy(g) {
        return stmt_cont(loc=floc);
    }
    g.emit_op(OP_GET_ITER, 0, iter_loc);
    loop_hdr = g.new_block();
    g.use(loop_hdr);
    after = g.new_block();
    has_break = loop_body_has_break(f.body);
    if more_code_follows {
        break_blk = g.new_block();
        g.push_loop(loop_hdr, break_blk, has_break);
        g.emit_jump(OP_FOR_ITER, after.id, iter_loc);
        store = visit_store_target_tos(g, f.target);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=store.loc);
        }
        body_cont = visit_stmts(g, f.body);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=body_cont.loc);
        }
        if not body_cont.terminated {
            g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, body_cont.loc);
        }
        g.pop_loop();
        tail_more = exec_tail_emits_code(tail, tail_idx);
        if has_break {
            g.use(break_blk);
            g.emit_op(OP_POP_TOP, 0, iter_loc);
            if tail_more {
                g.emit_jump(OP_JUMP_FORWARD, after.id, iter_loc);
            } else {
                br_cont = emit_tail_and_finish(g, tail, tail_idx, floc);
                if codegen_busy(g) {
                    return br_cont;
                }
            }
        }
        g.use(after);
        g.emit_op(OP_END_FOR, 0, iter_loc);
        g.emit_op(OP_POP_ITER, 0, iter_loc);
        if len(f.orelse) > 0 {
            else_cont = visit_stmts(g, f.orelse);
            if codegen_busy(g) {
                return stmt_cont(loc=else_cont.loc);
            }
        }
        if has_break and not tail_more {
            return stmt_cont(loc=floc, next_si=len(tail), terminated=True);
        }
        tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more);
        return stmt_cont(loc=tail_cont.loc, next_si=len(tail));
    }
    break_blk = after;
    needs_break_stub = has_break;
    if needs_break_stub {
        break_blk = g.new_block();
    }
    g.push_loop(loop_hdr, break_blk, needs_break_stub);
    g.emit_jump(OP_FOR_ITER, after.id, iter_loc);
    store = visit_store_target_tos(g, f.target);
    if codegen_busy(g) {
        g.pop_loop();
        return stmt_cont(loc=store.loc);
    }
    body_cont = visit_stmts(g, f.body);
    if codegen_busy(g) {
        g.pop_loop();
        return stmt_cont(loc=body_cont.loc);
    }
    if not body_cont.terminated {
        g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, body_cont.loc);
    }
    g.pop_loop();
    if needs_break_stub {
        g.use(break_blk);
        g.emit_op(OP_POP_TOP, 0, iter_loc);
        emit_module_return(g, iter_loc);
    }
    g.use(after);
    g.emit_op(OP_END_FOR, 0, iter_loc);
    g.emit_op(OP_POP_ITER, 0, iter_loc);
    if len(f.orelse) > 0 {
        else_cont = visit_stmts(g, f.orelse);
        if codegen_busy(g) {
            return stmt_cont(loc=else_cont.loc);
        }
        emit_module_return(g, else_cont.loc);
    } else {
        emit_module_return(g, iter_loc);
    }
    return stmt_cont(loc=floc, terminated=True);
}

# Lower one statement into the builder's current block.
def visit_stmt(
    g: cfg_builder,
    s: stmt,
    more_code_follows: bool = False,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None
) -> stmt_cont {
    if codegen_busy(g) {
        return stmt_cont(loc=stmt_loc(s));
    }
    if isinstance(s, Assign) {
        asgn = s as Assign;
        last = stmt_loc(s);
        copy_loc = nloc(
            asgn.lineno, asgn.end_lineno, asgn.col_offset, asgn.end_col_offset
        );
        cmp_cleanup = visit_expr(g, asgn.value, False, False);
        if cmp_cleanup is not None and more_code_follows {
            join = g.new_block();
            cmp_loc = expr_loc(asgn.value);
            g.emit_jump(OP_JUMP_FORWARD, join.id, cmp_loc);
            emit_compare_cleanup(g, cmp_cleanup, cmp_loc);
            g.use(join);
            ti = 0;
            while ti < len(asgn.targets) {
                if ti < len(asgn.targets) - 1 {
                    g.emit_op(OP_COPY, 1, copy_loc);
                }
                emit = visit_store_target_tos(g, asgn.targets[ti]);
                last = emit.loc;
                ti = ti + 1;
            }
            return stmt_cont(loc=last);
        }
        ti = 0;
        while ti < len(asgn.targets) {
            if ti < len(asgn.targets) - 1 {
                g.emit_op(OP_COPY, 1, copy_loc);
            }
            emit = visit_store_target_tos(g, asgn.targets[ti]);
            last = emit.loc;
            ti = ti + 1;
        }
        if cmp_cleanup is not None {
            none_idx = g.u.add_const(py_none());
            g.emit_op(OP_LOAD_CONST, none_idx, last);
            g.emit_op(OP_RETURN_VALUE, 0, last);
            emit_compare_cleanup(g, cmp_cleanup, expr_loc(asgn.value));
            ti = 0;
            while ti < len(asgn.targets) {
                if ti < len(asgn.targets) - 1 {
                    g.emit_op(OP_COPY, 1, copy_loc);
                }
                emit = visit_store_target_tos(g, asgn.targets[ti]);
                last = emit.loc;
                ti = ti + 1;
            }
            g.emit_op(OP_LOAD_CONST, none_idx, last);
            g.emit_op(OP_RETURN_VALUE, 0, last);
            return stmt_cont(loc=last, terminated=True);
        }
        return stmt_cont(loc=last);
    }
    if isinstance(s, AugAssign) {
        aa = s as AugAssign;
        opid = inplace_binop_id(aa.op);
        aloc = nloc(aa.lineno, aa.end_lineno, aa.col_offset, aa.end_col_offset);
        if opid < 0 {
            codegen_fail(
                g, "NotImplementedError", "unsupported augmented assignment operator"
            );
            return stmt_cont(loc=stmt_loc(s));
        }
        if isinstance(aa.target, Name) {
            n = aa.target as Name;
            visit_expr(g, n);
            visit_expr(g, aa.value);
            g.emit_op(OP_BINARY_OP, opid, aloc);
            tloc = expr_loc(n);
            emit_name_store(g, n.id, tloc);
            return stmt_cont(loc=tloc);
        }
        if isinstance(aa.target, Attribute) {
            attr = aa.target as Attribute;
            tloc = expr_loc(attr);
            visit_expr(g, attr.value);
            g.emit_op(OP_COPY, 1, tloc);
            idx = g.u.add_name(attr.attr);
            g.emit_op(OP_LOAD_ATTR, idx * 2, tloc);
            visit_expr(g, aa.value);
            g.emit_op(OP_BINARY_OP, opid, aloc);
            g.emit_op(OP_SWAP, 2, tloc);
            g.emit_op(OP_STORE_ATTR, idx, tloc);
            return stmt_cont(loc=tloc);
        }
        if isinstance(aa.target, Subscript) {
            sub = aa.target as Subscript;
            sloc = expr_loc(sub);
            visit_expr(g, sub.value);
            visit_subscript_index(g, sub.slice, sloc, True);
            g.emit_op(OP_COPY, 2, sloc);
            g.emit_op(OP_COPY, 2, sloc);
            g.emit_op(OP_BINARY_OP, NB_SUBSCR, sloc);
            visit_expr(g, aa.value, register_int_const=False);
            g.emit_op(OP_BINARY_OP, opid, aloc);
            g.emit_op(OP_SWAP, 3, sloc);
            g.emit_op(OP_SWAP, 2, sloc);
            g.emit_op(OP_STORE_SUBSCR, 0, sloc);
            return stmt_cont(loc=sloc);
        }
        codegen_fail(
            g,
            "NotImplementedError",
            "unsupported augmented assignment target: "
                + ast_node_name(aa.target as ast_node)
        );
        return stmt_cont(loc=stmt_loc(s));
    }
    if isinstance(s, Delete) {
        d = s as Delete;
        last = stmt_loc(s);
        ti = 0;
        while ti < len(d.targets) {
            emit = visit_delete_target(g, d.targets[ti]);
            last = emit.loc;
            ti = ti + 1;
        }
        return stmt_cont(loc=last);
    }
    if isinstance(s, Expr) {
        x = s as Expr;
        cmp_cleanup = visit_expr(g, x.value, False, False);
        eloc = nloc(x.lineno, x.end_lineno, x.col_offset, x.end_col_offset);
        if cmp_cleanup is not None and isinstance(x.value, Call) {
            ca = x.value as Call;
            cloc_call = nloc(
                ca.lineno, ca.end_lineno, ca.col_offset, ca.end_col_offset
            );
            g.emit_op(OP_POP_TOP, 0, eloc);
            after = g.new_block();
            g.emit_jump(OP_JUMP_FORWARD, after.id, eloc);
            emit_compare_cleanup(g, cmp_cleanup, cloc_call);
            if len(call_effective_keywords(ca)) > 0 {
                emit_call_keyword_values(g, ca, cloc_call);
            }
            emit_call_instruction(g, ca, cloc_call);
            g.emit_op(OP_POP_TOP, 0, eloc);
            g.use(after);
        } elif cmp_cleanup is not None {
            g.emit_op(OP_POP_TOP, 0, eloc);
            after = g.new_block();
            g.emit_jump(OP_JUMP_FORWARD, after.id, eloc);
            emit_compare_cleanup(g, cmp_cleanup, eloc);
            g.emit_op(OP_POP_TOP, 0, eloc);
            g.use(after);
        } else {
            g.emit_op(OP_POP_TOP, 0, eloc);
        }
        return stmt_cont(loc=eloc);
    }
    if isinstance(s, Pass) {
        ploc = stmt_loc(s);
        if more_code_follows {
            g.emit_op(OP_NOP, 0, ploc);
        }
        return stmt_cont(loc=ploc);
    }
    if isinstance(s, If) {
        t = tail;
        if t is None {
            t = [];
        }
        return visit_if(g, s as If, more_code_follows, t, tail_idx, tail_join);
    }
    if isinstance(s, While) {
        t = tail;
        if t is None {
            t = [];
        }
        return visit_while(g, s as While, more_code_follows, t, tail_idx);
    }
    if isinstance(s, For) {
        t = tail;
        if t is None {
            t = [];
        }
        return visit_for(g, s as For, more_code_follows, t, tail_idx);
    }
    if isinstance(s, Break) {
        b = s as Break;
        bloc = stmt_loc(b);
        frame = g.current_loop();
        if frame is None {
            codegen_fail(g, "SyntaxError", "'break' outside loop");
            return stmt_cont(loc=bloc);
        }
        if frame.break_is_stub {
            g.emit_jump(OP_JUMP_FORWARD, frame.break_blk.id, bloc);
        } else {
            emit_module_return(g, bloc);
        }
        return stmt_cont(loc=bloc, terminated=True);
    }
    if isinstance(s, Continue) {
        c = s as Continue;
        cloc_stmt = stmt_loc(c);
        frame = g.current_loop();
        if frame is None {
            codegen_fail(g, "SyntaxError", "'continue' not properly in loop");
            return stmt_cont(loc=cloc_stmt);
        }
        g.emit_jump(OP_JUMP_BACKWARD, frame.continue_blk.id, cloc_stmt);
        return stmt_cont(loc=cloc_stmt, terminated=True);
    }
    if isinstance(s, Return) {
        visit_return_stmt(g, s as Return);
        return stmt_cont(loc=stmt_loc(s), terminated=True);
    }
    if isinstance(s, FunctionDef) {
        return visit_function_def(g, s as FunctionDef);
    }
    if isinstance(s, ClassDef) {
        return visit_class_def(g, s as ClassDef);
    }
    codegen_fail(
        g,
        "NotImplementedError",
        "unsupported statement: " + ast_node_name(s as ast_node)
    );
    return stmt_cont(loc=stmt_loc(s));
}

# Emit a Return statement and finish the compile unit (no module epilogue).
def visit_return_stmt(g: cfg_builder, r: Return) {
    rloc = nloc(r.lineno, r.end_lineno, r.col_offset, r.end_col_offset);
    if r.value is not None {
        visit_expr(g, r.value);
        g.emit_op(OP_RETURN_VALUE, 0, rloc);
        return;
    }
    none_idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, rloc);
    g.emit_op(OP_RETURN_VALUE, 0, rloc);
}

# Class body boilerplate through __firstlineno__ (CPython compile_class).
def class_body_has_function(cd: ClassDef) -> bool {
    bi = 0;
    while bi < len(cd.body) {
        s = cd.body[bi];
        if isinstance(s, FunctionDef) or isinstance(s, AsyncFunctionDef) {
            return True;
        }
        bi = bi + 1;
    }
    return False;
}

def emit_class_body_prologue(g: cfg_builder, cd: ClassDef) {
    cloc = nloc(cd.lineno, cd.end_lineno, cd.col_offset, cd.end_col_offset);
    ploc = loc(0, cd.lineno, 0, 0);
    if len(g.u.cellvars) > 0 {
        ci = 0;
        while ci < len(g.u.cellvars) {
            lp = localsplus_index_u(g.u, g.u.cellvars[ci]);
            g.emit_op(OP_MAKE_CELL, lp, ploc);
            ci = ci + 1;
        }
    }
    g.emit_op(OP_RESUME, 0, ploc);
    nidx = g.u.add_name("__name__");
    g.emit_op(OP_LOAD_NAME, nidx, cloc);
    midx = g.u.add_name("__module__");
    g.emit_op(OP_STORE_NAME, midx, cloc);
    qidx = g.u.add_const(PyStr(t="str", val=cd.name));
    g.emit_op(OP_LOAD_CONST, qidx, cloc);
    qnidx = g.u.add_name("__qualname__");
    g.emit_op(OP_STORE_NAME, qnidx, cloc);
    emit_folded_int(g, cd.lineno, cloc);
    flidx = g.u.add_name("__firstlineno__");
    g.emit_op(OP_STORE_NAME, flidx, cloc);
    if len(g.u.cellvars) > 0 {
        g.emit_op(OP_LOAD_LOCALS, 0, cloc);
        cd_lp = localsplus_index_u(g.u, "__classdict__");
        g.emit_op(OP_STORE_DEREF, cd_lp, cloc);
    }
}

# __static_attributes__, optional __classdictcell__, and implicit RETURN_VALUE None.
def emit_class_body_epilogue(g: cfg_builder, last: cloc) {
    tup = PyTuple(t="tuple", items=[]);
    tidx = g.u.add_const(tup);
    g.emit_op(OP_LOAD_CONST, tidx, last);
    saidx = g.u.add_name("__static_attributes__");
    g.emit_op(OP_STORE_NAME, saidx, last);
    if len(g.u.cellvars) > 0 {
        cd_lp = localsplus_index_u(g.u, "__classdict__");
        g.emit_op(OP_LOAD_FAST_BORROW, cd_lp, last);
        cdidx = g.u.add_name("__classdictcell__");
        g.emit_op(OP_STORE_NAME, cdidx, last);
    }
    none_idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, last);
    g.emit_op(OP_RETURN_VALUE, 0, last);
}

# Lower `class name: ...` at module/class scope into nested PyCode + LOAD_BUILD_CLASS.
def visit_class_def(g: cfg_builder, cd: ClassDef) -> stmt_cont {
    cloc = nloc(cd.lineno, cd.end_lineno, cd.col_offset, cd.end_col_offset);
    if g.sym_top is None {
        codegen_fail(g, "SystemError", "class definition without symtable");
        return stmt_cont(loc=cloc);
    }
    sym_cls = sym_class_child(g.sym_top, cd.name);
    if sym_cls is None {
        codegen_fail(g, "SystemError", "missing symtable for class " + cd.name);
        return stmt_cont(loc=cloc);
    }
    u_cls = compile_class_cfg(cd, g.u.filename, sym_cls);
    if u_cls.diag is not None {
        g.u.diag = u_cls.diag;
        return stmt_cont(loc=cloc);
    }
    cfg_cls = verify_cfg(u_cls);
    if cfg_cls.diag is not None {
        g.u.diag = cfg_cls.diag;
        return stmt_cont(loc=cloc);
    }
    co = assemble(cfg_cls);
    g.u.nested_code_emitted = True;
    g.emit_op(OP_LOAD_BUILD_CLASS, 0, cloc);
    g.emit_op(OP_PUSH_NULL, 0, cloc);
    cidx = g.u.add_const(co);
    g.emit_op(OP_LOAD_CONST, cidx, cloc);
    g.emit_op(OP_MAKE_FUNCTION, 0, cloc);
    name_idx = g.u.add_const(PyStr(t="str", val=cd.name));
    g.emit_op(OP_LOAD_CONST, name_idx, cloc);
    g.emit_op(OP_CALL, 2, cloc);
    if g.sym_top is not None and g.sym_top.block_type == "function" {
        fi = fast_local_index(g, cd.name);
        if fi < 0 {
            codegen_fail(
                g, "SystemError", "missing fast local for nested class " + cd.name
            );
            return stmt_cont(loc=cloc);
        }
        g.emit_op(OP_STORE_FAST, fi, cloc);
    } else {
        nidx = g.u.add_name(cd.name);
        g.emit_op(OP_STORE_NAME, nidx, cloc);
    }
    return stmt_cont(loc=cloc);
}

# Build unverified_cfg for a class body (nested code object before assembly).
def compile_class_cfg(
    cd: ClassDef, filename: str, sym_cls: sym_block
) -> unverified_cfg {
    u = unverified_cfg(
        filename=filename,
        name=cd.name,
        qualname=cd.name,
        firstlineno=cd.lineno
    );
    if sym_cls.nested {
        u.flags = CO_NESTED;
    }
    if class_body_has_function(cd) {
        u.cellvars = ["__classdict__"];
    }
    entry = u.add_block();
    g = new_cfg_builder(u, entry, sym_cls);
    emit_class_body_prologue(g, cd);
    last = loc(0, cd.lineno, 0, 0);
    bi = 0;
    while bi < len(cd.body) {
        s = cd.body[bi];
        cont = visit_stmt(
            g, s, exec_tail_emits_code(cd.body, bi + 1), cd.body, bi + 1
        );
        last = cont.loc;
        if codegen_busy(g) {
            return u;
        }
        if cont.next_si >= 0 {
            bi = cont.next_si;
        } else {
            bi = bi + 1;
        }
    }
    emit_class_body_epilogue(g, last);
    return u;
}

# Lower `def name(...): ...` at module/class scope into nested PyCode + MAKE_FUNCTION.
def visit_function_def(g: cfg_builder, fd: FunctionDef) -> stmt_cont {
    floc = nloc(fd.lineno, fd.end_lineno, fd.col_offset, fd.end_col_offset);
    if g.sym_top is None {
        codegen_fail(g, "SystemError", "function definition without symtable");
        return stmt_cont(loc=floc);
    }
    sym_fn = sym_function_child(g.sym_top, fd.name);
    if sym_fn is None {
        codegen_fail(g, "SystemError", "missing symtable for function " + fd.name);
        return stmt_cont(loc=floc);
    }
    decorators = fd.decorator_list;
    if decorators is None {
        decorators = [];
    }
    u_fn = compile_function_cfg(fd, g.u.filename, sym_fn);
    if u_fn.diag is not None {
        g.u.diag = u_fn.diag;
        return stmt_cont(loc=floc);
    }
    cfg_fn = verify_cfg(u_fn);
    if cfg_fn.diag is not None {
        g.u.diag = cfg_fn.diag;
        return stmt_cont(loc=floc);
    }
    co = assemble(cfg_fn);
    g.u.nested_code_emitted = True;
    di = 0;
    while di < len(decorators) {
        visit_expr(g, decorators[di]);
        di = di + 1;
    }
    emit_make_function_with_closure(g, sym_fn, co, floc, fd.args);
    ri = len(decorators) - 1;
    while ri >= 0 {
        dec = decorators[ri];
        g.emit_op(OP_CALL, 0, expr_loc(dec));
        ri = ri - 1;
    }
    if g.sym_top is not None and g.sym_top.block_type == "function" {
        fi = fast_local_index(g, fd.name);
        if fi < 0 {
            codegen_fail(
                g, "SystemError", "missing fast local for nested function " + fd.name
            );
            return stmt_cont(loc=floc);
        }
        g.emit_op(OP_STORE_FAST, fi, floc);
    } else {
        nidx = g.u.add_name(fd.name);
        g.emit_op(OP_STORE_NAME, nidx, floc);
    }
    return stmt_cont(loc=floc);
}

# Lower `lambda ...: expr` into nested PyCode + MAKE_FUNCTION (value on stack).
def visit_lambda(g: cfg_builder, lam: Lambda) {
    lloc = nloc(lam.lineno, lam.end_lineno, lam.col_offset, lam.end_col_offset);
    if g.sym_top is None {
        codegen_fail(g, "SystemError", "lambda without symtable");
        return;
    }
    sym_fn = sym_function_child_at(
        g.sym_top, "lambda", lam.lineno, lam.col_offset
    );
    if sym_fn is None {
        codegen_fail(g, "SystemError", "missing symtable for lambda");
        return;
    }
    u_fn = compile_lambda_cfg(lam, g.u.filename, sym_fn);
    if u_fn.diag is not None {
        g.u.diag = u_fn.diag;
        return;
    }
    cfg_fn = verify_cfg(u_fn);
    if cfg_fn.diag is not None {
        g.u.diag = cfg_fn.diag;
        return;
    }
    co = assemble(cfg_fn);
    g.u.nested_code_emitted = True;
    emit_make_function_with_closure(g, sym_fn, co, lloc, lam.args);
}

# Build unverified_cfg for a lambda body (expression + RETURN_VALUE).
def compile_lambda_cfg(
    lam: Lambda, filename: str, sym_fn: sym_block
) -> unverified_cfg {
    (argcount, posonly, kwonly) = function_argcounts(lam.args);
    u = unverified_cfg(
        filename=filename,
        name="<lambda>",
        qualname="<lambda>",
        firstlineno=lam.lineno
    );
    u.argcount = argcount;
    u.posonlyargcount = posonly;
    u.kwonlyargcount = kwonly;
    u.flags = function_code_flags(lam.args);
    u.varnames = fast_varnames_from_sym(sym_fn);
    entry = u.add_block();
    g = new_cfg_builder(u, entry, sym_fn);
    emit_function_prologue(g, sym_fn, lam.lineno);
    bloc = expr_loc(lam.body);
    visit_expr(g, lam.body);
    if codegen_busy(g) {
        return u;
    }
    g.emit_op(OP_RETURN_VALUE, 0, bloc);
    return u;
}

# Build unverified_cfg for a function body (nested code object before assembly).
def compile_function_cfg(
    fd: FunctionDef, filename: str, sym_fn: sym_block
) -> unverified_cfg {
    (argcount, posonly, kwonly) = function_argcounts(fd.args);
    u = unverified_cfg(
        filename=filename,
        name=fd.name,
        qualname=fd.name,
        firstlineno=fd.lineno
    );
    u.argcount = argcount;
    u.posonlyargcount = posonly;
    u.kwonlyargcount = kwonly;
    u.flags = function_code_flags(fd.args);
    u.varnames = fast_varnames_from_sym(sym_fn);
    entry = u.add_block();
    g = new_cfg_builder(u, entry, sym_fn);
    emit_function_prologue(g, sym_fn, fd.lineno);
    last = loc(0, fd.lineno, 0, 0);
    terminated = False;
    bi = 0;
    while bi < len(fd.body) {
        s = fd.body[bi];
        cont = visit_stmt(
            g, s, exec_tail_emits_code(fd.body, bi + 1), fd.body, bi + 1
        );
        last = cont.loc;
        if cont.terminated {
            terminated = True;
        }
        if codegen_busy(g) {
            return u;
        }
        if cont.next_si >= 0 {
            bi = cont.next_si;
        } else {
            bi = bi + 1;
        }
    }
    if not terminated {
        none_idx = u.add_const(py_none());
        g.emit_op(OP_LOAD_CONST, none_idx, last);
        g.emit_op(OP_RETURN_VALUE, 0, last);
    }
    return u;
}

# Build a unverified_cfg for an exec-mode module body. Emits RESUME (module scope:
# lineno 0), each statement, then the implicit LOAD_CONST None; RETURN_VALUE
# epilogue. The epilogue carries the last-emitted instruction's location (or the
# last statement's location when it emitted nothing, e.g. Pass), matching
# CPython's NO_LOCATION inheritance at the end of _PyCodegen_AddReturnAtEnd.
def compile_exec(
    body: list[stmt],
    filename: str,
    name: str,
    firstlineno: int,
    sym_top: sym_block | None = None
) -> unverified_cfg {
    u = unverified_cfg(
        filename=filename, name=name, qualname=name, firstlineno=firstlineno
    );
    if sym_top is not None {
        u.varnames = fast_varnames_from_sym(sym_top);
    }
    entry = u.add_block();
    g = new_cfg_builder(u, entry, sym_top);
    g.emit_op(OP_RESUME, 0, loc(0, firstlineno, 0, 0));
    last = loc(0, firstlineno, 0, 0);
    terminated = False;
    si = 0;
    while si < len(body) {
        s = body[si];
        cont = visit_stmt(g, s, exec_tail_emits_code(body, si + 1), body, si + 1);
        last = cont.loc;
        if cont.terminated {
            terminated = True;
        }
        if codegen_busy(g) {
            return u;
        }
        if cont.next_si >= 0 {
            si = cont.next_si;
        } else {
            si = si + 1;
        }
    }
    if terminated {
        return u;
    }
    none_idx = u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, last);
    g.emit_op(OP_RETURN_VALUE, 0, last);
    emit_deferred_comp_handlers(g);
    return u;
}
