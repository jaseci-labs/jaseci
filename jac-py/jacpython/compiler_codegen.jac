# Compiler codegen for the P4 back track (PLAN.md P0.10).
#
# Walks a hand-built (later: parser-produced) ast_nodes.jac tree and emits IR
# into a compile_unit. Dispatch is locked to na-legal ordered isinstance
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

import from objects { PyObj, PyInt, py_none, PySlice, py_error }
import from opcode_meta {
    OP_RESUME,
    OP_RETURN_VALUE,
    OP_LOAD_CONST,
    OP_LOAD_SMALL_INT,
    OP_LOAD_NAME,
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
    OP_COPY,
    OP_SWAP,
    OP_TO_BOOL,
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
    compile_unit,
    basicblock,
    cinstr,
    loc,
    mk_instr,
    mk_jump,
}

# Record the first codegen diagnostic on u (PLAN.md: no silent skips).
def codegen_fail(u: compile_unit, kind: str, message: str) -> None {
    if u.diag is None {
        u.diag = py_error(kind, message);
    }
}

def codegen_busy(u: compile_unit) -> bool {
    return u.diag is not None;
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
def visit_subscript_index(u: compile_unit, blk: basicblock, key: expr, lc: cloc) -> None {
    if isinstance(key, Slice) {
        folded = fold_slice_const(key as Slice);
        if folded is not None {
            idx = u.add_const(folded);
            blk.instrs.append(mk_instr(OP_LOAD_CONST, idx, lc));
            return;
        }
    }
    visit_expr(u, blk, key);
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
def visit_compare(u: compile_unit, blk: basicblock, c: Compare) -> None {
    n = len(c.ops);
    cloc_cmp = nloc(c.lineno, c.end_lineno, c.col_offset, c.end_col_offset);
    visit_expr(u, blk, c.left);
    cleanup: basicblock | None = None;
    if n > 1 {
        cleanup = u.add_block();
    }
    ei = 0;
    while ei < n {
        visit_expr(u, blk, c.comparators[ei]);
        if n > 1 and ei == 0 {
            blk.instrs.append(mk_instr(OP_SWAP, 2, cloc_cmp));
            blk.instrs.append(mk_instr(OP_COPY, 2, cloc_cmp));
        }
        oparg = cmpop_oparg(c.ops[ei]);
        if oparg < 0 {
            return;
        }
        blk.instrs.append(mk_instr(OP_COMPARE_OP, oparg, cloc_cmp));
        if ei < n - 1 {
            blk.instrs.append(mk_instr(OP_COPY, 1, cloc_cmp));
            blk.instrs.append(mk_instr(OP_TO_BOOL, 0, cloc_cmp));
            if cleanup is not None {
                blk.instrs.append(
                    mk_jump(OP_POP_JUMP_IF_FALSE, cleanup.id, cloc_cmp)
                );
            }
            blk.instrs.append(mk_instr(OP_POP_TOP, 0, cloc_cmp));
        }
        ei = ei + 1;
    }
    if cleanup is not None {
        cleanup.instrs.append(mk_instr(OP_SWAP, 2, cloc_cmp));
        cleanup.instrs.append(mk_instr(OP_POP_TOP, 0, cloc_cmp));
        cleanup.instrs.append(mk_instr(OP_RETURN_VALUE, 0, cloc_cmp));
    }
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
def emit_folded_int(u: compile_unit, blk: basicblock, v: int, lc: cloc) -> None {
    if v >= 0 and v <= 255 {
        blk.instrs.append(mk_instr(OP_LOAD_SMALL_INT, v, lc));
        return;
    }
    idx = u.add_const(PyInt(t="int", val=v));
    blk.instrs.append(mk_instr(OP_LOAD_CONST, idx, lc));
}

# Visit one expression, appending IR into the current block. Consumes no host
# objects; constants/names are registered in the unit's deterministic tables.
def visit_expr(u: compile_unit, blk: basicblock, e: expr) -> None {
    if codegen_busy(u) {
        return;
    }
    if isinstance(e, Constant) {
        c = e as Constant;
        idx = u.add_const(c.value);
        blk.instrs.append(
            mk_instr(OP_LOAD_CONST, idx, nloc(c.lineno, c.end_lineno, c.col_offset, c.end_col_offset))
        );
        return;
    }
    if isinstance(e, Name) {
        n = e as Name;
        idx = u.add_name(n.id);
        blk.instrs.append(
            mk_instr(OP_LOAD_NAME, idx, nloc(n.lineno, n.end_lineno, n.col_offset, n.end_col_offset))
        );
        return;
    }
    if isinstance(e, BinOp) {
        b = e as BinOp;
        bl = nloc(b.lineno, b.end_lineno, b.col_offset, b.end_col_offset);
        # Operand literals stay in the const table even when folded (CPython).
        if isinstance(b.left, Constant) {
            u.add_const((b.left as Constant).value);
        }
        if isinstance(b.right, Constant) {
            u.add_const((b.right as Constant).value);
        }
        folded = try_fold_binop(b.left, b.op, b.right);
        if folded is not None and isinstance(folded, PyInt) {
            emit_folded_int(u, blk, (folded as PyInt).val, bl);
            return;
        }
        visit_expr(u, blk, b.left);
        visit_expr(u, blk, b.right);
        opid = binop_id(b.op);
        if opid < 0 {
            codegen_fail(u, "SyntaxError", "unsupported binary operator");
            return;
        }
        blk.instrs.append(mk_instr(OP_BINARY_OP, opid, bl));
        return;
    }
    if isinstance(e, UnaryOp) {
        un = e as UnaryOp;
        visit_expr(u, blk, un.operand);
        opc = unary_opcode(un.op);
        if opc < 0 {
            codegen_fail(u, "SyntaxError", "unsupported unary operator");
            return;
        }
        blk.instrs.append(
            mk_instr(opc, 0, nloc(un.lineno, un.end_lineno, un.col_offset, un.end_col_offset))
        );
        return;
    }
    if isinstance(e, Compare) {
        visit_compare(u, blk, e as Compare);
        return;
    }
    if isinstance(e, Call) {
        ca = e as Call;
        # Plain call lowering (codegen_call, non-method): load callable, push the
        # NULL marker, load args left-to-right, then CALL(argc). PUSH_NULL and the
        # callable share the callable's span; CALL spans the whole call.
        floc = call_func_loc(ca.func);
        visit_expr(u, blk, ca.func);
        blk.instrs.append(mk_instr(OP_PUSH_NULL, 0, floc));
        ai = 0;
        while ai < len(ca.args) {
            visit_expr(u, blk, ca.args[ai]);
            ai = ai + 1;
        }
        blk.instrs.append(
            mk_instr(OP_CALL, len(ca.args), nloc(ca.lineno, ca.end_lineno, ca.col_offset, ca.end_col_offset))
        );
        return;
    }
    if isinstance(e, Attribute) {
        a = e as Attribute;
        aloc = expr_loc(a);
        visit_expr(u, blk, a.value);
        idx = u.add_name(a.attr);
        blk.instrs.append(mk_instr(OP_LOAD_ATTR, idx * 2, aloc));
        return;
    }
    if isinstance(e, Subscript) {
        s = e as Subscript;
        sloc = expr_loc(s);
        visit_expr(u, blk, s.value);
        visit_subscript_index(u, blk, s.slice, sloc);
        blk.instrs.append(mk_instr(OP_BINARY_OP, NB_SUBSCR, sloc));
        return;
    }
    codegen_fail(
        u, "SyntaxError", "unsupported expression: " + ast_node_name(e as ast_node)
    );
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

# Build a compile_unit for an eval-mode expression. Emits RESUME (module/eval
# scope: lineno 0), the expression, then RETURN_VALUE carrying the expression's
# span. addNone is false for eval (no trailing None push).
def compile_eval(
    e: expr, filename: str, name: str, firstlineno: int
) -> compile_unit {
    u = compile_unit(
        filename=filename,
        name=name,
        qualname=name,
        firstlineno=firstlineno
    );
    entry = u.add_block();
    entry.instrs.append(mk_instr(OP_RESUME, 0, loc(0, firstlineno, 0, 0)));
    visit_expr(u, entry, e);
    if codegen_busy(u) {
        return u;
    }
    entry.instrs.append(mk_instr(OP_RETURN_VALUE, 0, top_loc(e)));
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
    return loc(1, 1, 0, 0);
}

# Store value already on the stack into an assignment target (name / attribute /
# subscript). CPython stack layout before STORE_ATTR / STORE_SUBSCR: value below
# owner (and index for subscript), with owner/index on TOS.
def visit_store_target_tos(u: compile_unit, blk: basicblock, t: expr) -> cloc {
    if codegen_busy(u) {
        return expr_loc(t);
    }
    if isinstance(t, Name) {
        n = t as Name;
        idx = u.add_name(n.id);
        tloc = expr_loc(n);
        blk.instrs.append(mk_instr(OP_STORE_NAME, idx, tloc));
        return tloc;
    }
    if isinstance(t, Attribute) {
        a = t as Attribute;
        visit_expr(u, blk, a.value);
        idx = u.add_name(a.attr);
        tloc = expr_loc(a);
        blk.instrs.append(mk_instr(OP_STORE_ATTR, idx, tloc));
        return tloc;
    }
    if isinstance(t, Subscript) {
        s = t as Subscript;
        sloc = expr_loc(s);
        visit_expr(u, blk, s.value);
        visit_subscript_index(u, blk, s.slice, sloc);
        blk.instrs.append(mk_instr(OP_STORE_SUBSCR, 0, sloc));
        return sloc;
    }
    codegen_fail(
        u,
        "SyntaxError",
        "unsupported assignment target: " + ast_node_name(t as ast_node)
    );
    return expr_loc(t);
}

# Store value into an assignment target (name / attribute / subscript).
def visit_store_target(u: compile_unit, blk: basicblock, t: expr, value: expr) -> cloc {
    visit_expr(u, blk, value);
    return visit_store_target_tos(u, blk, t);
}

# Delete one target (name / attribute / subscript).
def visit_delete_target(u: compile_unit, blk: basicblock, t: expr) -> cloc {
    if codegen_busy(u) {
        return expr_loc(t);
    }
    if isinstance(t, Name) {
        n = t as Name;
        idx = u.add_name(n.id);
        tloc = expr_loc(n);
        blk.instrs.append(mk_instr(OP_DELETE_NAME, idx, tloc));
        return tloc;
    }
    if isinstance(t, Attribute) {
        a = t as Attribute;
        visit_expr(u, blk, a.value);
        idx = u.add_name(a.attr);
        tloc = expr_loc(a);
        blk.instrs.append(mk_instr(OP_DELETE_ATTR, idx, tloc));
        return tloc;
    }
    if isinstance(t, Subscript) {
        s = t as Subscript;
        visit_expr(u, blk, s.value);
        visit_subscript_index(u, blk, s.slice, expr_loc(s));
        tloc = expr_loc(s);
        blk.instrs.append(mk_instr(OP_DELETE_SUBSCR, 0, tloc));
        return tloc;
    }
    codegen_fail(
        u,
        "SyntaxError",
        "unsupported deletion target: " + ast_node_name(t as ast_node)
    );
    return expr_loc(t);
}

# Lower one statement, appending IR into blk. Returns the location of the last
# instruction emitted (used for the module epilogue).
def visit_stmt(u: compile_unit, blk: basicblock, s: stmt) -> cloc {
    if codegen_busy(u) {
        return stmt_loc(s);
    }
    if isinstance(s, Assign) {
        a = s as Assign;
        last = stmt_loc(s);
        visit_expr(u, blk, a.value);
        ti = 0;
        while ti < len(a.targets) {
            if ti < len(a.targets) - 1 {
                tloc = expr_loc(a.targets[ti]);
                blk.instrs.append(mk_instr(OP_COPY, 1, tloc));
            }
            last = visit_store_target_tos(u, blk, a.targets[ti]);
            ti = ti + 1;
        }
        return last;
    }
    if isinstance(s, AugAssign) {
        aa = s as AugAssign;
        opid = inplace_binop_id(aa.op);
        aloc = nloc(aa.lineno, aa.end_lineno, aa.col_offset, aa.end_col_offset);
        if opid < 0 {
            codegen_fail(u, "SyntaxError", "unsupported augmented assignment operator");
            return stmt_loc(s);
        }
        if isinstance(aa.target, Name) {
            n = aa.target as Name;
            visit_expr(u, blk, n);
            visit_expr(u, blk, aa.value);
            blk.instrs.append(mk_instr(OP_BINARY_OP, opid, aloc));
            idx = u.add_name(n.id);
            tloc = expr_loc(n);
            blk.instrs.append(mk_instr(OP_STORE_NAME, idx, tloc));
            return tloc;
        }
        if isinstance(aa.target, Attribute) {
            a = aa.target as Attribute;
            tloc = expr_loc(a);
            visit_expr(u, blk, a.value);
            blk.instrs.append(mk_instr(OP_COPY, 1, tloc));
            idx = u.add_name(a.attr);
            blk.instrs.append(mk_instr(OP_LOAD_ATTR, idx * 2, tloc));
            visit_expr(u, blk, aa.value);
            blk.instrs.append(mk_instr(OP_BINARY_OP, opid, aloc));
            blk.instrs.append(mk_instr(OP_SWAP, 2, tloc));
            blk.instrs.append(mk_instr(OP_STORE_ATTR, idx, tloc));
            return tloc;
        }
        if isinstance(aa.target, Subscript) {
            sub = aa.target as Subscript;
            sloc = expr_loc(sub);
            visit_expr(u, blk, sub.value);
            visit_subscript_index(u, blk, sub.slice, sloc);
            blk.instrs.append(mk_instr(OP_COPY, 2, sloc));
            blk.instrs.append(mk_instr(OP_COPY, 2, sloc));
            blk.instrs.append(mk_instr(OP_BINARY_OP, NB_SUBSCR, sloc));
            visit_expr(u, blk, aa.value);
            blk.instrs.append(mk_instr(OP_BINARY_OP, opid, aloc));
            blk.instrs.append(mk_instr(OP_SWAP, 3, sloc));
            blk.instrs.append(mk_instr(OP_SWAP, 2, sloc));
            blk.instrs.append(mk_instr(OP_STORE_SUBSCR, 0, sloc));
            return sloc;
        }
        codegen_fail(
            u,
            "SyntaxError",
            "unsupported augmented assignment target: "
            + ast_node_name(aa.target as ast_node)
        );
        return stmt_loc(s);
    }
    if isinstance(s, Delete) {
        d = s as Delete;
        last = stmt_loc(s);
        ti = 0;
        while ti < len(d.targets) {
            last = visit_delete_target(u, blk, d.targets[ti]);
            ti = ti + 1;
        }
        return last;
    }
    if isinstance(s, Expr) {
        x = s as Expr;
        visit_expr(u, blk, x.value);
        eloc = nloc(x.lineno, x.end_lineno, x.col_offset, x.end_col_offset);
        blk.instrs.append(mk_instr(OP_POP_TOP, 0, eloc));
        return eloc;
    }
    if isinstance(s, Pass) {
        return stmt_loc(s);
    }
    codegen_fail(
        u, "SyntaxError", "unsupported statement: " + ast_node_name(s as ast_node)
    );
    return stmt_loc(s);
}

# Emit a Return statement and finish the compile unit (no module epilogue).
def visit_return_stmt(u: compile_unit, blk: basicblock, r: Return) -> None {
    rloc = nloc(r.lineno, r.end_lineno, r.col_offset, r.end_col_offset);
    if r.value is not None {
        visit_expr(u, blk, r.value);
        blk.instrs.append(mk_instr(OP_RETURN_VALUE, 0, rloc));
        return;
    }
    none_idx = u.add_const(py_none());
    blk.instrs.append(mk_instr(OP_LOAD_CONST, none_idx, rloc));
    blk.instrs.append(mk_instr(OP_RETURN_VALUE, 0, rloc));
}

# Build a compile_unit for an exec-mode module body. Emits RESUME (module scope:
# lineno 0), each statement, then the implicit LOAD_CONST None; RETURN_VALUE
# epilogue. The epilogue carries the last-emitted instruction's location (or the
# last statement's location when it emitted nothing, e.g. Pass), matching
# CPython's NO_LOCATION inheritance at the end of _PyCodegen_AddReturnAtEnd.
def compile_exec(
    body: list[stmt], filename: str, name: str, firstlineno: int
) -> compile_unit {
    u = compile_unit(
        filename=filename,
        name=name,
        qualname=name,
        firstlineno=firstlineno
    );
    entry = u.add_block();
    entry.instrs.append(mk_instr(OP_RESUME, 0, loc(0, firstlineno, 0, 0)));
    last = loc(0, firstlineno, 0, 0);
    si = 0;
    while si < len(body) {
        s = body[si];
        if isinstance(s, Return) {
            codegen_fail(u, "SyntaxError", "'return' outside function");
            return u;
        }
        last = visit_stmt(u, entry, s);
        if codegen_busy(u) {
            return u;
        }
        si = si + 1;
    }
    none_idx = u.add_const(py_none());
    entry.instrs.append(mk_instr(OP_LOAD_CONST, none_idx, last));
    entry.instrs.append(mk_instr(OP_RETURN_VALUE, 0, last));
    return u;
}
