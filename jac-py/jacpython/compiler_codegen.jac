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

import from objects { PyObj, PyInt, py_none, PySlice }
import from opcode_meta {
    OP_RESUME,
    OP_RETURN_VALUE,
    OP_LOAD_CONST,
    OP_LOAD_SMALL_INT,
    OP_LOAD_NAME,
    OP_LOAD_GLOBAL,
    OP_BINARY_OP,
    OP_UNARY_NEGATIVE,
    OP_UNARY_INVERT,
    OP_UNARY_NOT,
    OP_PUSH_NULL,
    OP_CALL,
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
    mk_instr,
    mk_jump,
    cfg_builder,
    stmt_cont,
    new_cfg_builder,
    loop_frame,
}
import from compiler_symtable { sym_block, sym_dict_get, sym_scope_of, SCOPE_GLOBAL_EXPLICIT, SCOPE_GLOBAL_IMPLICIT }
import from compiler_diagnostics { lowering_diagnostic }

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

# Name load opcode from symtable facts. Module scope always uses LOAD_NAME
# (CPython: implicit globals are still LOAD_NAME at module level). LOAD_GLOBAL
# is for nested scopes with explicit/implicit global classification.
def name_load_opcode(g: cfg_builder, name: str) -> int {
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

# cmpop -> CPython 3.14 COMPARE_OP oparg (low bits carry cache metadata).
def cmpop_oparg(op: PyObj) -> int {
    if isinstance(op, Lt) {
        return 2;
    }
    return -1;
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
            if register_int_const and v >= 0 and v <= 255 and not g.u.dead_small_int_const {
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
        idx = g.u.add_name(n.id);
        g.emit_op(
            name_load_opcode(g, n.id),
            idx,
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
        visit_expr(g, b.left);
        visit_expr(g, b.right);
        opid = binop_id(b.op);
        if opid < 0 {
            codegen_fail(g, "NotImplementedError", "unsupported binary operator");
            return None;
        }
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
        visit_expr(g, ca.func);
        g.emit_op(OP_PUSH_NULL, 0, floc);
        cmp_cleanup: basicblock | None = None;
        call_args = ca.args;
        if call_args is None {
            call_args = [];
        }
        ai = 0;
        while ai < len(call_args) {
            arg_cleanup = visit_expr(g, call_args[ai], False, False);
            if arg_cleanup is not None {
                cmp_cleanup = arg_cleanup;
            }
            ai = ai + 1;
        }
        cloc_call = nloc(ca.lineno, ca.end_lineno, ca.col_offset, ca.end_col_offset);
        g.emit_op(OP_CALL, len(call_args), cloc_call);
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
    codegen_fail(
        g, "NotImplementedError", "unsupported expression: " + ast_node_name(e as ast_node)
    );
    return None;
}

# The callable's location, used for PUSH_NULL. For the slice the callable is a
# Name; this stays general for future Attribute/method lowering.
def call_func_loc(f: expr) -> cloc {
    return expr_loc(f);
}

# The top-level expression's location, assigned to the trailing RETURN_VALUE in
# eval mode (matches CPython's observed co_positions).
def top_loc(e: expr) -> cloc {
    return expr_loc(e);
}

# Build a unverified_cfg for an eval-mode expression. Emits RESUME (module/eval
# scope: lineno 0), the expression, then RETURN_VALUE carrying the expression's
# span. addNone is false for eval (no trailing None push).
def compile_eval(e: expr, filename: str, name: str, firstlineno: int) -> unverified_cfg {
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
            cloc_call = nloc(ca.lineno, ca.end_lineno, ca.col_offset, ca.end_col_offset);
            emit_compare_cleanup(g, cleanup, cloc_call);
            g.emit_op(OP_CALL, len(ca.args), cloc_call);
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
        idx = g.u.add_name(n.id);
        tloc = expr_loc(n);
        g.emit_op(OP_STORE_NAME, idx, tloc);
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
        g, "NotImplementedError", "unsupported deletion target: " + ast_node_name(t as ast_node)
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

# Module-level epilogue (LOAD_CONST None; RETURN_VALUE).
def emit_module_return(g: cfg_builder, lc: cloc) {
    none_idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, lc);
    g.emit_op(OP_RETURN_VALUE, 0, lc);
}

# Lower statements [from_idx..] in order.
def visit_stmts(
    g: cfg_builder,
    stmts: list[stmt],
    from_idx: int = 0,
    more_follows_after: bool = False
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
        cont = visit_stmt(g, stmts[si], follow, stmts, si + 1);
        last = cont.loc;
        if cont.terminated {
            terminated = True;
        }
        if codegen_busy(g) {
            return stmt_cont(loc=last, terminated=terminated);
        }
        si = si + 1;
    }
    return stmt_cont(loc=last, terminated=terminated);
}

# Lower a statement suffix (used to duplicate tails after if/while/for).
def visit_stmt_tail(
    g: cfg_builder,
    tail: list[stmt],
    from_idx: int,
    more_follows_after: bool = False
) -> stmt_cont {
    return visit_stmts(g, tail, from_idx, more_follows_after);
}

def visit_if(
    g: cfg_builder, i: If, more_code_follows: bool, tail: list[stmt], tail_idx: int
) -> stmt_cont {
    iloc = nloc(i.lineno, i.end_lineno, i.col_offset, i.end_col_offset);
    test_loc = expr_loc(i.test);
    visit_expr(g, i.test);
    if codegen_busy(g) {
        return stmt_cont(loc=iloc);
    }
    g.emit_op(OP_TO_BOOL, 0, test_loc);
    false_blk = g.new_block();
    has_else = len(i.orelse) > 0;
    if more_code_follows {
        if has_else {
            dup_tail = g.new_block();
            g.emit_jump(OP_POP_JUMP_IF_FALSE, false_blk.id, test_loc);
            body_cont = visit_stmts(g, i.body);
            if codegen_busy(g) {
                return stmt_cont(loc=body_cont.loc);
            }
            g.emit_jump(OP_JUMP_FORWARD, dup_tail.id, iloc);
            g.use(false_blk);
            else_cont = visit_stmts(g, i.orelse);
            if codegen_busy(g) {
                return stmt_cont(loc=else_cont.loc);
            }
            g.emit_jump(OP_JUMP_FORWARD, dup_tail.id, iloc);
            g.use(dup_tail);
            tail_cont = visit_stmt_tail(g, tail, tail_idx);
            return stmt_cont(loc=tail_cont.loc, next_si=len(tail));
        }
        tail_blk = g.new_block();
        g.emit_jump(OP_POP_JUMP_IF_FALSE, tail_blk.id, test_loc);
        body_cont = visit_stmts(g, i.body);
        if codegen_busy(g) {
            return stmt_cont(loc=body_cont.loc);
        }
        g.use(tail_blk);
        tail_cont = visit_stmt_tail(g, tail, tail_idx);
        return stmt_cont(loc=tail_cont.loc, next_si=len(tail));
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
    visit_expr(g, w.test);
    if codegen_busy(g) {
        return stmt_cont(loc=wloc);
    }
    g.emit_op(OP_TO_BOOL, 0, test_loc);
    exit_blk = g.new_block();
    tail_dup_blk = None;
    if more_code_follows {
        tail_dup_blk = g.new_block();
        g.emit_jump(OP_POP_JUMP_IF_FALSE, tail_dup_blk.id, test_loc);
    } else {
        g.emit_jump(OP_POP_JUMP_IF_FALSE, exit_blk.id, test_loc);
    }
    break_blk = exit_blk;
    if more_code_follows {
        break_blk = g.new_block();
    }
    break_is_stub = more_code_follows;
    g.push_loop(head, break_blk, break_is_stub);
    body_cont = visit_stmts(g, w.body);
    if codegen_busy(g) {
        g.pop_loop();
        return stmt_cont(loc=body_cont.loc);
    }
    if not body_cont.terminated {
        g.emit_jump(OP_JUMP_BACKWARD, head.id, body_cont.loc);
    }
    g.pop_loop();
    if more_code_follows {
        g.use(break_blk);
        g.emit_op(OP_NOP, 0, wloc);
        br_cont = visit_stmt_tail(g, tail, tail_idx);
        if codegen_busy(g) {
            return br_cont;
        }
        g.use(tail_dup_blk);
        tail_cont = visit_stmt_tail(g, tail, tail_idx);
        return stmt_cont(loc=tail_cont.loc, next_si=len(tail));
    }
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
    break_blk = after;
    needs_break_stub = more_code_follows;
    if not needs_break_stub {
        needs_break_stub = loop_body_has_break(f.body);
    }
    if needs_break_stub {
        break_blk = g.new_block();
    }
    tail_dup_blk = None;
    if more_code_follows {
        tail_dup_blk = g.new_block();
    }
    g.push_loop(loop_hdr, break_blk, more_code_follows or needs_break_stub);
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
        if more_code_follows {
            br_cont = visit_stmt_tail(g, tail, tail_idx);
            if codegen_busy(g) {
                return br_cont;
            }
            g.use(after);
            g.emit_op(OP_END_FOR, 0, iter_loc);
            g.emit_op(OP_POP_ITER, 0, iter_loc);
            if len(f.orelse) > 0 {
                visit_stmts(g, f.orelse);
            }
            g.use(tail_dup_blk);
            tail_cont = visit_stmt_tail(g, tail, tail_idx);
            return stmt_cont(loc=tail_cont.loc, next_si=len(tail));
        }
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
    tail_idx: int = 0
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
            codegen_fail(g, "NotImplementedError", "unsupported augmented assignment operator");
            return stmt_cont(loc=stmt_loc(s));
        }
        if isinstance(aa.target, Name) {
            n = aa.target as Name;
            visit_expr(g, n);
            visit_expr(g, aa.value);
            g.emit_op(OP_BINARY_OP, opid, aloc);
            idx = g.u.add_name(n.id);
            tloc = expr_loc(n);
            g.emit_op(OP_STORE_NAME, idx, tloc);
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
            cloc_call = nloc(ca.lineno, ca.end_lineno, ca.col_offset, ca.end_col_offset);
            g.emit_op(OP_POP_TOP, 0, eloc);
            after = g.new_block();
            g.emit_jump(OP_JUMP_FORWARD, after.id, eloc);
            emit_compare_cleanup(g, cmp_cleanup, cloc_call);
            g.emit_op(OP_CALL, len(ca.args), cloc_call);
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
        return visit_if(g, s as If, more_code_follows, t, tail_idx);
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
    codegen_fail(
        g, "NotImplementedError", "unsupported statement: " + ast_node_name(s as ast_node)
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
    return u;
}
