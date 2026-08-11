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

import from objects { PyObj, PyInt }
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
}
import from ast_nodes {
    expr,
    Constant,
    Name,
    BinOp,
    UnaryOp,
    Call,
    Compare,
    Load,
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
    # Unhandled node: fail loudly with the node kind (PLAN.md: no silent skips).
}

# The callable's location, used for PUSH_NULL. For the slice the callable is a
# Name; this stays general for future Attribute/method lowering.
def call_func_loc(f: expr) -> cloc {
    if isinstance(f, Name) {
        n = f as Name;
        return nloc(n.lineno, n.end_lineno, n.col_offset, n.end_col_offset);
    }
    return loc(1, 1, 0, 0);
}

# The top-level expression's location, assigned to the trailing RETURN_VALUE in
# eval mode (matches CPython's observed co_positions).
def top_loc(e: expr) -> cloc {
    if isinstance(e, Constant) {
        c = e as Constant;
        return nloc(c.lineno, c.end_lineno, c.col_offset, c.end_col_offset);
    }
    if isinstance(e, Name) {
        n = e as Name;
        return nloc(n.lineno, n.end_lineno, n.col_offset, n.end_col_offset);
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
    entry.instrs.append(mk_instr(OP_RETURN_VALUE, 0, top_loc(e)));
    return u;
}
