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

import from objects { PyObj, PyInt, PyStr, py_none, PyNoneType, PySlice, PyCode, PyTuple }
import from opcode_meta {
    OP_RESUME,
    OP_RETURN_GENERATOR,
    OP_RETURN_VALUE,
    OP_YIELD_VALUE,
    OP_GET_YIELD_FROM_ITER,
    OP_GET_AWAITABLE,
    OP_GET_AITER,
    OP_GET_ANEXT,
    OP_END_ASYNC_FOR,
    OP_SEND,
    OP_END_SEND,
    OP_CLEANUP_THROW,
    OP_JUMP_BACKWARD_NO_INTERRUPT,
    OP_CALL_INTRINSIC_1,
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
    CO_GENERATOR,
    CO_COROUTINE,
    CO_ASYNC_GENERATOR,
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
    OP_IS_OP,
    OP_CONTAINS_OP,
    OP_POP_TOP,
    OP_IMPORT_NAME,
    OP_IMPORT_FROM,
    OP_STORE_NAME,
    OP_STORE_GLOBAL,
    OP_STORE_ATTR,
    OP_STORE_SUBSCR,
    OP_LOAD_ATTR,
    OP_DELETE_NAME,
    OP_DELETE_GLOBAL,
    OP_DELETE_ATTR,
    OP_DELETE_SUBSCR,
    OP_POP_JUMP_IF_FALSE,
    OP_POP_JUMP_IF_TRUE,
    OP_POP_JUMP_IF_NOT_NONE,
    OP_POP_JUMP_IF_NONE,
    OP_JUMP_FORWARD,
    OP_JUMP_BACKWARD,
    OP_COPY,
    OP_SWAP,
    OP_GET_LEN,
    OP_MATCH_SEQUENCE,
    OP_MATCH_MAPPING,
    OP_MATCH_KEYS,
    OP_MATCH_CLASS,
    OP_DICT_UPDATE,
    OP_TO_BOOL,
    OP_NOP,
    OP_NOT_TAKEN,
    OP_GET_ITER,
    OP_FOR_ITER,
    OP_END_FOR,
    OP_POP_ITER,
    OP_BUILD_LIST,
    OP_LIST_APPEND,
    OP_LIST_EXTEND,
    OP_BUILD_SET,
    OP_SET_ADD,
    OP_SET_UPDATE,
    OP_BUILD_MAP,
    OP_MAP_ADD,
    OP_LOAD_FAST,
    OP_LOAD_FAST_BORROW,
    OP_LOAD_FAST_CHECK,
    OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW,
    OP_LOAD_FAST_AND_CLEAR,
    OP_STORE_FAST,
    OP_DELETE_FAST,
    OP_STORE_FAST_STORE_FAST,
    OP_STORE_FAST_LOAD_FAST,
    OP_UNPACK_SEQUENCE,
    OP_UNPACK_EX,
    OP_PUSH_EXC_INFO,
    OP_POP_EXCEPT,
    OP_CHECK_EXC_MATCH,
    OP_RERAISE,
    OP_RAISE_VARARGS,
    OP_LOAD_SPECIAL,
    OP_WITH_EXCEPT_START,
    OP_LOAD_COMMON_CONSTANT,
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
    Is,
    IsNot,
    In,
    NotIn,
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
    match_case,
    pattern,
    MatchValue,
    MatchSingleton,
    MatchAs,
    MatchOr,
    MatchSequence,
    MatchMapping,
    MatchClass,
    MatchStar,
    Raise,
    Try,
    TryStar,
    ExceptHandler,
    Assert,
    Import,
    ImportFrom,
    alias,
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
    mangle_name,
    DEF_COMP_ITER,
    SCOPE_GLOBAL_EXPLICIT,
    SCOPE_GLOBAL_IMPLICIT,
    SCOPE_LOCAL,
    SCOPE_CELL,
    SCOPE_FREE,
    sym_block_tuple_names,
}
import from compiler_diagnostics { lowering_diagnostic }
import from flowgraph { verify_cfg, optimize_swap_range }
import from assembler { assemble }
import from codegen_util { fold_default_values, args_have_kw_defaults, function_argcounts, function_code_flags, ast_node_name, nloc, function_def_loc, async_function_def_loc, binop_id, inplace_binop_id, expr_loc, fold_slice_const, unary_opcode, ast_cmp_kind, cmpop_oparg, cmpop_filter_oparg, try_fold_binop, call_func_loc, call_effective_args, call_effective_keywords, top_loc, stmt_loc, seq_target_elts, is_seq_literal, display_has_starred, display_all_constant, display_const_items, starred_target_index, exec_tail_emits_code, comp_name_bound, comp_bound_names_from_target, comp_leftmost_leaf, comp_dict_map_loc, try_handler_span, body_is_try_finally_only, match_pattern_loc, match_pattern_unwrap_or, match_pattern_wildcard, loop_body_has_break, import_bind_name, class_effective_bases, class_effective_keywords }

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

# Class-body private name mangling (__x -> _C__x) for bytecode name tables.
def codegen_mangle(g: cfg_builder, name: str) -> str {
    return mangle_name(g.private, name);
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
        li = 0;
        while li < len(block.local_varnames) {
            name = block.local_varnames[li];
            flags = sym_dict_get(block.symbols, name, 0);
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
            li = li + 1;
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

# CPython emits MAKE_CELL(s), optional COPY_FREE_VARS, then RESUME. Generators
# and coroutines prepend RETURN_GENERATOR; POP_TOP before RESUME (protect region
# starts at the following block).
def emit_function_prologue(
    g: cfg_builder, sym_fn: sym_block, firstlineno: int, is_suspendable: bool = False
) -> int {
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
    protect_start = -1;
    g.generator_protect_start = -1;
    if is_suspendable {
        g.emit_op(OP_RETURN_GENERATOR, 0, ploc);
        g.emit_op(OP_POP_TOP, 0, ploc);
        resume_blk = g.new_block();
        g.use(resume_blk);
        protect_start = resume_blk.id;
        g.generator_protect_start = protect_start;
    }
    g.emit_op(OP_RESUME, 0, ploc);
    return protect_start;
}

# Suspendable functions: PEP 479 StopIteration handler at end of co_code.
def emit_generator_except_handler(g: cfg_builder, protect_start: int) {
    if protect_start < 0 {
        return;
    }
    noloc = no_loc();
    handler = g.new_block();
    g.use(handler);
    g.emit_op(OP_CALL_INTRINSIC_1, 3, noloc);
    g.emit_op(OP_RERAISE, 1, noloc);
    if len(g.u.pending_pep479_regions) == 0 {
        g.u.except_regions.append(
            except_region(
                start_block=protect_start,
                end_block=handler.id,
                handler_block=handler.id,
                stack_depth=2,
                preserve_lasti=True
            )
        );
    }
    pi = 0;
    while pi < len(g.u.pending_pep479_regions) {
        ri = g.u.pending_pep479_regions[pi];
        g.u.except_regions[ri].handler_block = handler.id;
        if g.u.except_regions[ri].end_block < 0 {
            g.u.except_regions[ri].end_block = handler.id;
        }
        pi = pi + 1;
    }
}

# GET_YIELD_FROM_ITER / GET_AWAITABLE + SEND loop shared by yield-from and await.
def emit_send_delegation_loop(
    g: cfg_builder,
    get_iter_op: int,
    get_iter_arg: int,
    resume_after_yield_arg: int,
    yloc: cloc
) {
    als = emit_await_send_loop_header(
        g, get_iter_op, get_iter_arg, resume_after_yield_arg, yloc
    );
    (ct, cj) = emit_await_send_loop_footer(g, als, yloc);
    emit_await_send_except_regions(g, als, ct, cj, 3, -1);
    g.use(als.end_send_blk);
}

# GET_AWAITABLE / GET_YIELD_FROM_ITER + SEND loop (footer deferred for async-with).
obj await_send_loop {
    has send_blk: basicblock,
        yield_blk: basicblock,
        after_resume_blk: basicblock,
        end_send_blk: basicblock;
}

def emit_await_send_loop_header(
    g: cfg_builder,
    get_iter_op: int,
    get_iter_arg: int,
    resume_after_yield_arg: int,
    yloc: cloc,
    emit_end_send: bool = True
) -> await_send_loop {
    g.emit_op(get_iter_op, get_iter_arg, yloc);
    none_idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, yloc);
    send_blk = g.new_block();
    yield_blk = g.new_block();
    after_resume_blk = g.new_block();
    end_send_blk = g.new_block();
    g.use(send_blk);
    g.emit_jump(OP_SEND, end_send_blk.id, yloc);
    g.use(yield_blk);
    g.emit_op(OP_YIELD_VALUE, 1, yloc);
    g.use(after_resume_blk);
    g.emit_op(OP_RESUME, resume_after_yield_arg, yloc);
    g.emit_jump(OP_JUMP_BACKWARD_NO_INTERRUPT, send_blk.id, yloc);
    g.use(end_send_blk);
    if emit_end_send {
        g.emit_op(OP_END_SEND, 0, yloc);
    }
    return await_send_loop(
        send_blk=send_blk,
        yield_blk=yield_blk,
        after_resume_blk=after_resume_blk,
        end_send_blk=end_send_blk
    );
}

def emit_await_send_loop_footer(
    g: cfg_builder, als: await_send_loop, yloc: cloc
) -> tuple[basicblock, basicblock] {
    cleanup_throw_blk = g.new_block();
    cleanup_jump_blk = g.new_block();
    g.use(cleanup_throw_blk);
    g.emit_op(OP_CLEANUP_THROW, 0, yloc);
    g.use(cleanup_jump_blk);
    g.emit_jump(OP_JUMP_BACKWARD_NO_INTERRUPT, als.end_send_blk.id, yloc);
    return (cleanup_throw_blk, cleanup_jump_blk);
}

# Inline footer before END_SEND (async-with except __aexit__ await).
def emit_await_send_loop_inline_footer(
    g: cfg_builder,
    get_iter_op: int,
    get_iter_arg: int,
    resume_after_yield_arg: int,
    yloc: cloc
) -> tuple[await_send_loop, basicblock, basicblock] {
    g.emit_op(get_iter_op, get_iter_arg, yloc);
    none_idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, yloc);
    send_blk = g.new_block();
    yield_blk = g.new_block();
    after_resume_blk = g.new_block();
    cleanup_throw_blk = g.new_block();
    end_send_blk = g.new_block();
    g.use(send_blk);
    g.emit_jump(OP_SEND, end_send_blk.id, yloc);
    g.use(yield_blk);
    g.emit_op(OP_YIELD_VALUE, 1, yloc);
    g.use(after_resume_blk);
    g.emit_op(OP_RESUME, resume_after_yield_arg, yloc);
    g.emit_jump(OP_JUMP_BACKWARD_NO_INTERRUPT, send_blk.id, yloc);
    g.use(cleanup_throw_blk);
    g.emit_op(OP_CLEANUP_THROW, 0, yloc);
    g.use(end_send_blk);
    als = await_send_loop(
        send_blk=send_blk,
        yield_blk=yield_blk,
        after_resume_blk=after_resume_blk,
        end_send_blk=end_send_blk
    );
    return (als, cleanup_throw_blk, end_send_blk);
}

def emit_await_send_except_regions(
    g: cfg_builder,
    als: await_send_loop,
    cleanup_throw_blk: basicblock,
    cleanup_jump_blk: basicblock,
    cleanup_stack_depth: int,
    after_resume_handler: int,
    pep479_start: int = -1,
    pep479_end: int = -1,
    after_resume_stack_depth: int = 2,
    after_resume_preserve_lasti: bool = True
) {
    protect = g.generator_protect_start;
    if protect < 0 {
        return;
    }
    if pep479_start >= 0 {
        protect = pep479_start;
    }
    pep479_end_blk = cleanup_jump_blk.id;
    if pep479_end >= 0 {
        pep479_end_blk = pep479_end;
    }
    g.u.except_regions.append(
        except_region(
            start_block=protect,
            end_block=als.yield_blk.id,
            handler_block=-1,
            stack_depth=2,
            preserve_lasti=True
        )
    );
    g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    g.u.except_regions.append(
        except_region(
            start_block=als.yield_blk.id,
            end_block=als.after_resume_blk.id,
            handler_block=cleanup_throw_blk.id,
            stack_depth=cleanup_stack_depth,
            preserve_lasti=False
        )
    );
    ar_handler = after_resume_handler;
    if ar_handler < 0 {
        ar_handler = -1;
    }
    g.u.except_regions.append(
        except_region(
            start_block=als.after_resume_blk.id,
            end_block=pep479_end_blk,
            handler_block=ar_handler,
            stack_depth=after_resume_stack_depth,
            preserve_lasti=after_resume_preserve_lasti
        )
    );
    if after_resume_handler < 0 {
        g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    }
}

# GET_ANEXT + SEND loop blocks for async-for (footer emitted after the loop body).
obj anext_send_loop {
    has loop_hdr: basicblock,
        send_blk: basicblock,
        yield_blk: basicblock,
        after_resume_blk: basicblock,
        end_send_blk: basicblock;
}

# Loop header: GET_ANEXT, LOAD_CONST None, SEND/YIELD/RESUME/END_SEND.
def emit_anext_send_loop_header(
    g: cfg_builder, loop_hdr: basicblock, resume_after_yield_arg: int, yloc: cloc
) -> anext_send_loop {
    g.use(loop_hdr);
    g.emit_op(OP_GET_ANEXT, 0, yloc);
    none_idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, yloc);
    send_blk = g.new_block();
    yield_blk = g.new_block();
    after_resume_blk = g.new_block();
    end_send_blk = g.new_block();
    g.use(send_blk);
    g.emit_jump(OP_SEND, end_send_blk.id, yloc);
    g.use(yield_blk);
    g.emit_op(OP_YIELD_VALUE, 1, yloc);
    g.use(after_resume_blk);
    g.emit_op(OP_RESUME, resume_after_yield_arg, yloc);
    g.emit_jump(OP_JUMP_BACKWARD_NO_INTERRUPT, send_blk.id, yloc);
    g.use(end_send_blk);
    g.emit_op(OP_END_SEND, 0, yloc);
    return anext_send_loop(
        loop_hdr=loop_hdr,
        send_blk=send_blk,
        yield_blk=yield_blk,
        after_resume_blk=after_resume_blk,
        end_send_blk=end_send_blk
    );
}

def emit_anext_send_except_regions(
    g: cfg_builder,
    als: anext_send_loop,
    store_blk: basicblock,
    cleanup_throw_blk: basicblock,
    cleanup_jump_blk: basicblock,
    async_for_handler: basicblock
) {
    g.u.except_regions.append(
        except_region(
            start_block=als.loop_hdr.id,
            end_block=als.yield_blk.id,
            handler_block=async_for_handler.id,
            stack_depth=2,
            preserve_lasti=False
        )
    );
    # END_SEND through NOT_TAKEN only; loop body uses a separate PEP 479 region.
    g.u.except_regions.append(
        except_region(
            start_block=als.after_resume_blk.id,
            end_block=store_blk.id,
            handler_block=async_for_handler.id,
            stack_depth=2,
            preserve_lasti=False
        )
    );
    g.u.except_regions.append(
        except_region(
            start_block=cleanup_throw_blk.id,
            end_block=cleanup_jump_blk.id,
            handler_block=async_for_handler.id,
            stack_depth=2,
            preserve_lasti=False
        )
    );
    protect = g.generator_protect_start;
    if protect >= 0 {
        g.u.except_regions.append(
            except_region(
                start_block=protect,
                end_block=als.loop_hdr.id,
                handler_block=-1,
                stack_depth=2,
                preserve_lasti=True
            )
        );
        g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
        g.u.except_regions.append(
            except_region(
                start_block=als.yield_blk.id,
                end_block=als.after_resume_blk.id,
                handler_block=cleanup_throw_blk.id,
                stack_depth=4,
                preserve_lasti=False
            )
        );
    }
}

# CLEANUP_THROW footer for async-for (laid out after the loop body's JUMP_BACK).
def emit_anext_send_loop_footer(
    g: cfg_builder, als: anext_send_loop, yloc: cloc
) -> tuple[basicblock, basicblock] {
    cleanup_throw_blk = g.new_block();
    cleanup_jump_blk = g.new_block();
    g.use(cleanup_throw_blk);
    g.emit_op(OP_CLEANUP_THROW, 0, yloc);
    g.use(cleanup_jump_blk);
    g.emit_jump(OP_JUMP_BACKWARD_NO_INTERRUPT, als.end_send_blk.id, yloc);
    return (cleanup_throw_blk, cleanup_jump_blk);
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



def emit_name_load(
    g: cfg_builder, name: str, tloc: cloc, for_call: bool = False
) -> bool {
    # Returns True when a separate PUSH_NULL is required before CALL (LOAD_NAME
    # and fast locals). LOAD_GLOBAL folds NULL into the oparg low bit (CPython 3.14).
    name = codegen_mangle(g, name);
    fi = fast_local_index(g, name);
    if fi >= 0 {
        # Inside a comprehension body the loop target's borrowed copy is left on
        # the stack by STORE_FAST_LOAD_FAST at bind time; the first evaluated
        # reference to it consumes that copy (emits nothing). Every later
        # reference loads its own borrow.
        if fi == g.u.comp_pending_borrow {
            g.u.comp_pending_borrow = -1;
            return True;
        }
        # Inside a comprehension body, coalesce with an immediately preceding
        # borrow load into LOAD_FAST_BORROW_LOAD_FAST_BORROW, keeping the first
        # load's position (CPython's superinstruction peephole).
        if g.u.comp_depth > 0 and len(g.cur.instrs) > 0 {
            prev = g.cur.instrs[len(g.cur.instrs) - 1];
            if prev.opcode == OP_LOAD_FAST_BORROW {
                prev.opcode = OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW;
                prev.oparg = prev.oparg * 16 + fi;
                return True;
            }
        }
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
    if opc == OP_LOAD_GLOBAL {
        # CPython encodes LOAD_GLOBAL's oparg as (name_index << 1) | push_null,
        # where the low bit requests the extra NULL for a following CALL. The VM
        # decodes name_index = arg >> 1, so the shift is required for every
        # LOAD_GLOBAL, not just the call form (idx==0 masked this before).
        if for_call {
            g.emit_op(opc, (idx << 1) | 1, tloc);
            return False;
        }
        g.emit_op(opc, idx << 1, tloc);
        return True;
    }
    g.emit_op(opc, idx, tloc);
    return True;
}

def emit_name_store(g: cfg_builder, name: str, tloc: cloc) {
    name = codegen_mangle(g, name);
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
        if scope == SCOPE_GLOBAL_EXPLICIT or scope == SCOPE_GLOBAL_IMPLICIT {
            idx = g.u.add_name(name);
            g.emit_op(OP_STORE_GLOBAL, idx, tloc);
            return;
        }
    }
    idx = g.u.add_name(name);
    g.emit_op(OP_STORE_NAME, idx, tloc);
}

def emit_name_delete(g: cfg_builder, name: str, tloc: cloc) {
    name = codegen_mangle(g, name);
    fi = fast_local_index(g, name);
    if fi >= 0 {
        g.emit_op(OP_DELETE_FAST, fi, tloc);
        return;
    }
    if g.sym_top is not None and g.sym_top.block_type != "module" {
        flags = sym_dict_get(g.sym_top.symbols, name, 0);
        scope = sym_scope_of(flags);
        if scope == SCOPE_FREE or scope == SCOPE_CELL {
            codegen_fail(
                g, "NotImplementedError", "delete of cell/free var not supported"
            );
            return;
        }
        if scope == SCOPE_GLOBAL_EXPLICIT or scope == SCOPE_GLOBAL_IMPLICIT {
            idx = g.u.add_name(name);
            g.emit_op(OP_DELETE_GLOBAL, idx, tloc);
            return;
        }
    }
    idx = g.u.add_name(name);
    g.emit_op(OP_DELETE_NAME, idx, tloc);
}

# Clear an except-as binding (STORE None + DELETE) before handler exit.
def emit_except_as_cleanup(g: cfg_builder, bind_name: str, cloc: cloc) {
    none_idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, cloc);
    emit_name_store(g, bind_name, cloc);
    emit_name_delete(g, bind_name, cloc);
}

# Name load opcode from symtable facts. Module scope uses LOAD_NAME for globals
# and LOAD_FAST when the name is a comprehension / local slot in varnames.
def name_load_opcode(g: cfg_builder, name: str) -> int {
    name = codegen_mangle(g, name);
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





# Emit the single comparison opcode for one cmpop link. Identity/membership ops
# lower to IS_OP / CONTAINS_OP (negation folded into oparg 1) and always yield a
# bool, so bool_context only affects the COMPARE_OP oparg. Returns False when the
# op node is not a recognized cmpop (caller reports NotImplementedError).
def emit_cmp_link(g: cfg_builder, op: PyObj, lc: cloc, bool_context: bool) -> bool {
    if isinstance(op, Is) {
        g.emit_op(OP_IS_OP, 0, lc);
        return True;
    }
    if isinstance(op, IsNot) {
        g.emit_op(OP_IS_OP, 1, lc);
        return True;
    }
    if isinstance(op, In) {
        g.emit_op(OP_CONTAINS_OP, 0, lc);
        return True;
    }
    if isinstance(op, NotIn) {
        g.emit_op(OP_CONTAINS_OP, 1, lc);
        return True;
    }
    kind = ast_cmp_kind(op);
    if kind < 0 {
        return False;
    }
    if bool_context {
        g.emit_op(OP_COMPARE_OP, compare_filter_oparg(kind), lc);
    } else {
        g.emit_op(OP_COMPARE_OP, compare_oparg(kind), lc);
    }
    return True;
}

# CPython folds `x is None` / `x is not None` in bool (test/filter) context into
# POP_JUMP_IF_NONE / POP_JUMP_IF_NOT_NONE, dropping the LOAD_CONST None + IS_OP.
# That jump peephole is a separate slice; until it lands, identity tests against
# the None literal in bool context must fail loudly rather than emit
# non-conformant IS_OP bytecode. Value-context `x is None` (plain IS_OP) is fine.
def is_none_identity_test(op: PyObj, comparand: expr) -> bool {
    if not isinstance(op, Is) and not isinstance(op, IsNot) {
        return False;
    }
    if not isinstance(comparand, Constant) {
        return False;
    }
    return isinstance((comparand as Constant).value, PyNoneType);
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
        if not emit_cmp_link(g, c.ops[ei], cloc_cmp, False) {
            codegen_fail(g, "NotImplementedError", "unsupported comparison operator");
            return None;
        }
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


# Emit a folded literal: LOAD_SMALL_INT for 0..255, else LOAD_CONST.
def emit_folded_int(g: cfg_builder, v: int, lc: cloc) {
    if v >= 0 and v <= 255 {
        g.emit_op(OP_LOAD_SMALL_INT, v, lc);
        return;
    }
    idx = g.u.add_const(PyInt(t="int", val=v));
    g.emit_op(OP_LOAD_CONST, idx, lc);
}

# Register literal int operands in co_consts without emitting (CPython dead
# small-int slot + out-of-range LOAD_CONST operands). Used by Constant visit
# and by peephole-folded BinOp so folded exprs keep the same const pool.
def register_int_literal_const(
    g: cfg_builder, e: expr, register_int_const: bool
) {
    if not register_int_const {
        return;
    }
    if not isinstance(e, Constant) {
        return;
    }
    c = e as Constant;
    if not isinstance(c.value, PyInt) {
        return;
    }
    v = (c.value as PyInt).val;
    in_class_body = g.sym_top is not None and g.sym_top.block_type == "class";
    if in_class_body {
        return;
    }
    if v >= 0 and v <= 255 {
        # CPython keeps the dead small-int slot ONLY when it lands at const
        # index 0 (pool empty). Once a code object / string / other const has
        # been added, small ints are pure LOAD_SMALL_INT with no pool entry.
        if len(g.u.consts) == 0 {
            g.u.add_const(c.value);
            g.u.dead_small_int_const = True;
        }
    } else {
        g.u.add_const(c.value);
    }
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
            register_int_literal_const(g, e, register_int_const);
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
        folded = try_fold_binop(b.left, b.op, b.right);
        if folded is not None and isinstance(folded, PyInt) {
            register_int_literal_const(g, b.left, register_int_const);
            register_int_literal_const(g, b.right, register_int_const);
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
            idx = g.u.add_name(codegen_mangle(g, attr.attr));
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
        idx = g.u.add_name(codegen_mangle(g, a.attr));
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
    if isinstance(e, Yield) {
        y = e as Yield;
        yloc = nloc(y.lineno, y.end_lineno, y.col_offset, y.end_col_offset);
        if y.value is not None {
            visit_expr(g, y.value);
        } else {
            none_idx = g.u.add_const(py_none());
            g.emit_op(OP_LOAD_CONST, none_idx, yloc);
        }
        # In an async generator, each yielded value is wrapped by
        # INTRINSIC_ASYNC_GEN_WRAP (4) before YIELD_VALUE.
        if (g.u.flags & CO_ASYNC_GENERATOR) != 0 {
            g.emit_op(OP_CALL_INTRINSIC_1, 4, yloc);
        }
        g.emit_op(OP_YIELD_VALUE, 0, yloc);
        g.emit_op(OP_RESUME, 5, yloc);
        return None;
    }
    if isinstance(e, YieldFrom) {
        yf = e as YieldFrom;
        yloc = nloc(yf.lineno, yf.end_lineno, yf.col_offset, yf.end_col_offset);
        visit_expr(g, yf.value);
        if codegen_busy(g) {
            return None;
        }
        emit_send_delegation_loop(
            g, OP_GET_YIELD_FROM_ITER, 0, 2, yloc
        );
        return None;
    }
    if isinstance(e, Await) {
        a = e as Await;
        aloc = nloc(a.lineno, a.end_lineno, a.col_offset, a.end_col_offset);
        visit_expr(g, a.value);
        if codegen_busy(g) {
            return None;
        }
        emit_send_delegation_loop(g, OP_GET_AWAITABLE, 0, 3, aloc);
        return None;
    }
    if isinstance(e, Tuple) {
        tup = e as Tuple;
        telts = tup.elts if tup.elts is not None else [];
        dloc = nloc(tup.lineno, tup.end_lineno, tup.col_offset, tup.end_col_offset);
        if display_has_starred(telts) {
            emit_starred_list_build(g, telts, dloc);
            if codegen_busy(g) {
                return None;
            }
            # INTRINSIC_LIST_TO_TUPLE == 6
            g.emit_op(OP_CALL_INTRINSIC_1, 6, dloc);
            return None;
        }
        if display_all_constant(telts) {
            cidx = g.u.add_const(PyTuple(t="tuple", items=display_const_items(telts)));
            g.emit_op(OP_LOAD_CONST, cidx, dloc);
            return None;
        }
        di = 0;
        while di < len(telts) {
            visit_expr(g, telts[di]);
            di = di + 1;
        }
        if codegen_busy(g) {
            return None;
        }
        g.emit_op(OP_BUILD_TUPLE, len(telts), dloc);
        return None;
    }
    if isinstance(e, List) {
        lst = e as List;
        lelts = lst.elts if lst.elts is not None else [];
        dloc = nloc(lst.lineno, lst.end_lineno, lst.col_offset, lst.end_col_offset);
        if display_has_starred(lelts) {
            emit_starred_list_build(g, lelts, dloc);
            return None;
        }
        if len(lelts) > 0 and display_all_constant(lelts) {
            # CPython packs an all-constant list as an empty list extended by a
            # folded const tuple: BUILD_LIST 0; LOAD_CONST (tuple); LIST_EXTEND 1.
            g.emit_op(OP_BUILD_LIST, 0, dloc);
            cidx = g.u.add_const(PyTuple(t="tuple", items=display_const_items(lelts)));
            g.emit_op(OP_LOAD_CONST, cidx, dloc);
            g.emit_op(OP_LIST_EXTEND, 1, dloc);
            return None;
        }
        di = 0;
        while di < len(lelts) {
            visit_expr(g, lelts[di]);
            di = di + 1;
        }
        if codegen_busy(g) {
            return None;
        }
        g.emit_op(OP_BUILD_LIST, len(lelts), dloc);
        return None;
    }
    if isinstance(e, Set) {
        st = e as Set;
        selts = st.elts if st.elts is not None else [];
        dloc = nloc(st.lineno, st.end_lineno, st.col_offset, st.end_col_offset);
        if display_has_starred(selts) {
            g.emit_op(OP_BUILD_SET, 0, dloc);
            si = 0;
            while si < len(selts) {
                sel = selts[si];
                if isinstance(sel, Starred) {
                    visit_expr(g, (sel as Starred).value);
                    if codegen_busy(g) {
                        return None;
                    }
                    g.emit_op(OP_SET_UPDATE, 1, dloc);
                } else {
                    visit_expr(g, sel);
                    if codegen_busy(g) {
                        return None;
                    }
                    g.emit_op(OP_SET_ADD, 1, dloc);
                }
                si = si + 1;
            }
            return None;
        }
        si = 0;
        while si < len(selts) {
            visit_expr(g, selts[si]);
            si = si + 1;
        }
        if codegen_busy(g) {
            return None;
        }
        g.emit_op(OP_BUILD_SET, len(selts), dloc);
        return None;
    }
    if isinstance(e, Dict) {
        dd = e as Dict;
        dkeys = dd.keys if dd.keys is not None else [];
        dvals = dd.values if dd.values is not None else [];
        dloc = nloc(dd.lineno, dd.end_lineno, dd.col_offset, dd.end_col_offset);
        has_star = False;
        si2 = 0;
        while si2 < len(dkeys) {
            if dkeys[si2] is None {
                has_star = True;
            }
            si2 = si2 + 1;
        }
        if not has_star {
            di = 0;
            while di < len(dkeys) {
                visit_expr(g, dkeys[di]);
                visit_expr(g, dvals[di]);
                di = di + 1;
            }
            if codegen_busy(g) {
                return None;
            }
            g.emit_op(OP_BUILD_MAP, len(dkeys), dloc);
            return None;
        }
        # dict-merge display: `{**a, 'k': v, ...}`. Walk left-to-right,
        # accumulating consecutive literal k:v pairs into `n`. When a `**x`
        # (key None) is reached, flush any pending pairs as BUILD_MAP n (which
        # DICT_UPDATEs onto the running base once one exists), then merge x with
        # DICT_UPDATE 1. Mirrors CPython 3.14 codegen_dict.
        n = 0;
        have_dict = False;
        di = 0;
        while di < len(dkeys) {
            k = dkeys[di];
            if k is None {
                if n > 0 or (not have_dict) {
                    g.emit_op(OP_BUILD_MAP, n, dloc);
                    if have_dict {
                        g.emit_op(OP_DICT_UPDATE, 1, dloc);
                    }
                    have_dict = True;
                    n = 0;
                }
                visit_expr(g, dvals[di]);
                g.emit_op(OP_DICT_UPDATE, 1, dloc);
            } else {
                visit_expr(g, k);
                visit_expr(g, dvals[di]);
                n = n + 1;
            }
            di = di + 1;
        }
        if n > 0 or (not have_dict) {
            g.emit_op(OP_BUILD_MAP, n, dloc);
            if have_dict {
                g.emit_op(OP_DICT_UPDATE, 1, dloc);
            }
        }
        if codegen_busy(g) {
            return None;
        }
        return None;
    }
    codegen_fail(
        g,
        "NotImplementedError",
        "unsupported expression: " + ast_node_name(e as ast_node)
    );
    return None;
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
        idx = g.u.add_name(codegen_mangle(g, a.attr));
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
    if isinstance(t, Tuple) or isinstance(t, List) {
        last_loc = emit_unpack_stores(g, seq_target_elts(t), expr_loc(t));
        return stmt_cont(loc=last_loc);
    }
    codegen_fail(
        g,
        "NotImplementedError",
        "unsupported assignment target: " + ast_node_name(t as ast_node)
    );
    return stmt_cont(loc=expr_loc(t));
}






# Build a list on the stack from a display element list containing starred
# entries: BUILD_LIST 0, then LIST_EXTEND for each *starred and LIST_APPEND for
# each plain element. Shared by starred list and starred tuple displays.
def emit_starred_list_build(g: cfg_builder, elts: list[expr], dloc: cloc) -> None {
    g.emit_op(OP_BUILD_LIST, 0, dloc);
    i = 0;
    while i < len(elts) {
        el = elts[i];
        if isinstance(el, Starred) {
            visit_expr(g, (el as Starred).value);
            if codegen_busy(g) {
                return None;
            }
            g.emit_op(OP_LIST_EXTEND, 1, dloc);
        } else {
            visit_expr(g, el);
            if codegen_busy(g) {
                return None;
            }
            g.emit_op(OP_LIST_APPEND, 1, dloc);
        }
        i = i + 1;
    }
    return None;
}


# With the sequence value on TOS, emit UNPACK_SEQUENCE (no star) or UNPACK_EX
# (starred), then store each element target left-to-right. Nested Tuple/List
# targets recurse; a Starred target stores the captured list into its .value.
def emit_unpack_stores(g: cfg_builder, elts: list[expr], tloc: cloc) -> cloc {
    star = starred_target_index(elts);
    n = len(elts);
    if star < 0 {
        g.emit_op(OP_UNPACK_SEQUENCE, n, tloc);
    } else {
        before = star;
        after = n - star - 1;
        g.emit_op(OP_UNPACK_EX, before + after * 256, tloc);
    }
    last_loc = tloc;
    i = 0;
    while i < n {
        el = elts[i];
        if isinstance(el, Starred) {
            se = visit_store_target_tos(g, (el as Starred).value);
        } else {
            se = visit_store_target_tos(g, el);
        }
        last_loc = se.loc;
        i = i + 1;
    }
    return last_loc;
}

# Store `value` into a target. CPython elides the sequence round-trip when both
# sides are same-arity sequence literals with no starred target: evaluate the
# RHS elements in order, reorder (SWAP for n<=3, BUILD_TUPLE+UNPACK_SEQUENCE for
# n>=4), then store each target left-to-right.
def visit_store_target(g: cfg_builder, t: expr, value: expr) -> stmt_cont {
    if is_seq_literal(t) and is_seq_literal(value) {
        telts = seq_target_elts(t);
        velts = seq_target_elts(value);
        if len(telts) == len(velts)
            and starred_target_index(telts) < 0
            and starred_target_index(velts) < 0 {
            return visit_store_seq_literal(g, telts, velts, expr_loc(t));
        }
    }
    visit_expr(g, value);
    return visit_store_target_tos(g, t);
}

def visit_store_seq_literal(
    g: cfg_builder, telts: list[expr], velts: list[expr], tloc: cloc, vloc: cloc
) -> stmt_cont {
    n = len(velts);
    i = 0;
    while i < n {
        visit_expr(g, velts[i]);
        i = i + 1;
    }
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    if n == 1 {
        return visit_store_target_tos(g, telts[0]);
    }
    if n <= 3 {
        # SWAP carries the target span; BUILD_TUPLE carries the RHS span.
        g.emit_op(OP_SWAP, n, tloc);
    } else {
        g.emit_op(OP_BUILD_TUPLE, n, vloc);
        g.emit_op(OP_UNPACK_SEQUENCE, n, tloc);
    }
    last_loc = tloc;
    i = 0;
    while i < n {
        se = visit_store_target_tos(g, telts[i]);
        last_loc = se.loc;
        i = i + 1;
    }
    return stmt_cont(loc=last_loc);
}

# Delete one target (name / attribute / subscript).
def visit_delete_target(g: cfg_builder, t: expr) -> stmt_cont {
    if codegen_busy(g) {
        return stmt_cont(loc=expr_loc(t));
    }
    if isinstance(t, Name) {
        n = t as Name;
        tloc = expr_loc(n);
        # emit_name_delete picks DELETE_FAST / DELETE_GLOBAL / DELETE_NAME from
        # the symtable scope (and rejects cell/free deletion).
        emit_name_delete(g, n.id, tloc);
        return stmt_cont(loc=tloc);
    }
    if isinstance(t, Attribute) {
        a = t as Attribute;
        visit_expr(g, a.value);
        idx = g.u.add_name(codegen_mangle(g, a.attr));
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
    # A pending comprehension borrow means one operand consumes the copy already
    # on the stack (emits nothing), so the two loads cannot fuse into a pair.
    if lfi == g.u.comp_pending_borrow or rfi == g.u.comp_pending_borrow {
        return False;
    }
    pair_arg = lfi * 16 + rfi;
    g.emit_op(OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW, pair_arg, tloc);
    return True;
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



# True when the comprehension's first evaluated body expression begins with the
# single loop variable -- the case CPython fuses into STORE_FAST_LOAD_FAST.
def comp_lead_is_loopvar(
    g: cfg_builder, gen: comprehension, body_first: expr,
    bound_names: list[str], slots: list[int]
) -> bool {
    if len(slots) != 1 {
        return False;
    }
    first: expr = body_first;
    if len(gen.ifs) > 0 {
        first = gen.ifs[0];
    }
    leaf = comp_leftmost_leaf(first);
    if not isinstance(leaf, Name) {
        return False;
    }
    nid = (leaf as Name).id;
    if not comp_name_bound(nid, bound_names) {
        return False;
    }
    return fast_local_index(g, nid) == slots[0];
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
        # Loop-var and ordinary name loads both go through emit_name_load, which
        # consumes the STORE_FAST_LOAD_FAST borrow for the first loop-var
        # reference and emits LOAD_FAST_BORROW for the rest.
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
            if filter_compare and is_none_identity_test(c.ops[ci], c.comparators[ci]) {
                codegen_fail(
                    g, "NotImplementedError", "is-None jump peephole not supported"
                );
                return;
            }
            visit_comp_elt(g, c.comparators[ci], bound_names, filter_compare);
            if codegen_busy(g) {
                return;
            }
            if not emit_cmp_link(g, c.ops[ci], cloc_cmp, filter_compare) {
                codegen_fail(
                    g, "NotImplementedError", "unsupported comparison operator"
                );
                return;
            }
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
        opid = binop_id(b.op);
        if opid < 0 {
            codegen_fail(g, "NotImplementedError", "unsupported binary operator");
            return;
        }
        # Operands emit LOAD_FAST_BORROW individually; adjacent borrow loads are
        # coalesced into LOAD_FAST_BORROW_LOAD_FAST_BORROW by emit_name_load's
        # in-comprehension fuse (CPython's superinstruction peephole).
        visit_comp_elt(g, b.left, bound_names, filter_compare);
        if codegen_busy(g) {
            return;
        }
        visit_comp_elt(g, b.right, bound_names, filter_compare);
        if codegen_busy(g) {
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

# Bind the comprehension loop target. When `lead` is true the first evaluated
# reference in the body is the (single) loop var, so CPython fuses the store with
# that first load into STORE_FAST_LOAD_FAST, leaving a borrowed copy on the stack
# that emit_name_load consumes for that reference (comp_pending_borrow). Otherwise
# a plain STORE_FAST binds it and every reference loads its own borrow.
def comp_emit_bind_target(
    g: cfg_builder, target: expr, slots: list[int], lead: bool = False
) {
    tloc = expr_loc(target);
    g.u.comp_pending_borrow = -1;
    if len(slots) == 1 {
        if lead {
            pair_arg = slots[0] * 16 + slots[0];
            g.emit_op(OP_STORE_FAST_LOAD_FAST, pair_arg, tloc);
            g.u.comp_pending_borrow = slots[0];
        } else {
            g.emit_op(OP_STORE_FAST, slots[0], tloc);
        }
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


def visit_comp_dict_kv(
    g: cfg_builder, dc: DictComp, bound_names: list[str], has_filters: bool = False
) {
    # Key then value in evaluation order; the first loop-var reference (usually
    # the key) consumes the STORE_FAST_LOAD_FAST borrow via emit_name_load, and
    # adjacent loop-var value loads fuse into LOAD_FAST_BORROW_LOAD_FAST_BORROW.
    map_loc = comp_dict_map_loc(dc);
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

# Inline async list comprehension `[elt async for target in aiter]` inside an
# `async def`. The comprehension's implicit function is inlined (PEP 709): the
# loop uses GET_AITER / GET_ANEXT / SEND / END_ASYNC_FOR (mirroring statement
# async-for) in place of GET_ITER / FOR_ITER, while the list-build / append /
# loop-var save-restore scaffolding matches the sync inline listcomp. Single
# generator only.
def visit_list_comp_async(
    g: cfg_builder,
    lc: ListComp,
    gen: comprehension,
    bound_names: list[str],
    slots: list[int]
) {
    cloc_comp = expr_loc(lc);
    iter_loc = expr_loc(gen.iter);
    elt_loc = expr_loc(lc.elt);
    handler_group = g.u.comp_handler_group;
    g.u.comp_handler_group = handler_group + 1;
    protect = g.generator_protect_start;

    swap_depth = 2;
    if len(slots) == 2 {
        swap_depth = 3;
    }

    # --- setup: evaluate iterable, GET_AITER, clear+save loop-var slot(s) ---
    visit_expr(g, gen.iter);
    if codegen_busy(g) {
        return;
    }
    g.emit_op(OP_GET_AITER, 0, iter_loc);
    si = 0;
    while si < len(slots) {
        g.emit_op(OP_LOAD_FAST_AND_CLEAR, slots[si], cloc_comp);
        si = si + 1;
    }
    g.emit_op(OP_SWAP, swap_depth, cloc_comp);

    # --- comp body block: BUILD_LIST, SWAP (protected list-build) ---
    comp_body = g.new_block();
    g.use(comp_body);
    g.emit_op(OP_BUILD_LIST, 0, cloc_comp);
    g.emit_op(OP_SWAP, 2, cloc_comp);

    # --- async loop header: GET_ANEXT/LOAD_CONST/SEND/YIELD/RESUME/END_SEND ---
    loop_hdr = g.new_block();
    als = emit_anext_send_loop_header(g, loop_hdr, 3, iter_loc);

    # --- store/append block (kept separate: it is an exception-region edge) ---
    store_blk = g.new_block();
    g.use(store_blk);
    g.u.comp_depth = g.u.comp_depth + 1;
    comp_emit_bind_target(
        g, gen.target, slots,
        comp_lead_is_loopvar(g, gen, lc.elt, bound_names, slots)
    );
    if codegen_busy(g) {
        g.u.comp_depth = g.u.comp_depth - 1;
        return;
    }
    comp_emit_single_elt(g, lc.elt, bound_names, OP_LIST_APPEND, elt_loc, False);
    if codegen_busy(g) {
        g.u.comp_depth = g.u.comp_depth - 1;
        return;
    }
    g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, elt_loc);
    g.u.comp_depth = g.u.comp_depth - 1;

    # --- footer: CLEANUP_THROW / JUMP_BACKWARD_NO_INTERRUPT + END_ASYNC_FOR ---
    (cleanup_throw, cleanup_jump) = emit_anext_send_loop_footer(g, als, iter_loc);
    end_async_handler = g.new_block();
    g.use(end_async_handler);
    g.emit_jump(OP_END_ASYNC_FOR, als.end_send_blk.id, iter_loc);

    # --- after loop: restore outer loop-var, leaving the built list on TOS ---
    after = g.new_block();
    g.use(after);
    comp_emit_cleanup(g, slots, cloc_comp, swap_depth);

    # ---------------- exception regions (non-overlapping, CPython order) -------
    # Comprehension save/restore handler (SWAP/POP + restore loop-var + RERAISE),
    # covering the three ranges not owned by the async-loop handlers.
    comp_append_handler(
        g, comp_body.id, loop_hdr.id, 3, slots[0], cloc_comp, handler_group, -1, 2
    );
    # async loop: GET_ANEXT..SEND -> END_ASYNC_FOR
    g.u.except_regions.append(
        except_region(
            start_block=loop_hdr.id,
            end_block=als.yield_blk.id,
            handler_block=end_async_handler.id,
            stack_depth=4,
            preserve_lasti=False
        )
    );
    # YIELD_VALUE -> CLEANUP_THROW
    g.u.except_regions.append(
        except_region(
            start_block=als.yield_blk.id,
            end_block=als.after_resume_blk.id,
            handler_block=cleanup_throw.id,
            stack_depth=6,
            preserve_lasti=False
        )
    );
    # RESUME..END_SEND -> END_ASYNC_FOR
    g.u.except_regions.append(
        except_region(
            start_block=als.after_resume_blk.id,
            end_block=store_blk.id,
            handler_block=end_async_handler.id,
            stack_depth=4,
            preserve_lasti=False
        )
    );
    comp_append_handler(
        g, store_blk.id, cleanup_throw.id, 3, slots[0], cloc_comp, handler_group, -1, 2
    );
    # CLEANUP_THROW -> END_ASYNC_FOR
    g.u.except_regions.append(
        except_region(
            start_block=cleanup_throw.id,
            end_block=cleanup_jump.id,
            handler_block=end_async_handler.id,
            stack_depth=4,
            preserve_lasti=False
        )
    );
    comp_append_handler(
        g, end_async_handler.id, after.id, 3, slots[0], cloc_comp, handler_group, -1, 2
    );
    # PEP 479 wrap: tail (after loop through RETURN_VALUE) and head (setup before
    # BUILD_LIST). Handlers/ends resolved by emit_generator_except_handler.
    g.u.except_regions.append(
        except_region(
            start_block=after.id,
            end_block=-1,
            handler_block=-1,
            stack_depth=2,
            preserve_lasti=True
        )
    );
    g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    if protect >= 0 {
        g.u.except_regions.append(
            except_region(
                start_block=protect,
                end_block=comp_body.id,
                handler_block=-1,
                stack_depth=2,
                preserve_lasti=True
            )
        );
        g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    }
}

# Inline async set comprehension `{elt async for target in aiter}` inside an
# `async def`. Same shape as visit_list_comp_async with BUILD_SET/SET_ADD.
def visit_set_comp_async(
    g: cfg_builder,
    sc: SetComp,
    gen: comprehension,
    bound_names: list[str],
    slots: list[int]
) {
    cloc_comp = expr_loc(sc);
    iter_loc = expr_loc(gen.iter);
    elt_loc = expr_loc(sc.elt);
    handler_group = g.u.comp_handler_group;
    g.u.comp_handler_group = handler_group + 1;
    protect = g.generator_protect_start;

    swap_depth = 2;
    if len(slots) == 2 {
        swap_depth = 3;
    }

    visit_expr(g, gen.iter);
    if codegen_busy(g) {
        return;
    }
    g.emit_op(OP_GET_AITER, 0, iter_loc);
    si = 0;
    while si < len(slots) {
        g.emit_op(OP_LOAD_FAST_AND_CLEAR, slots[si], cloc_comp);
        si = si + 1;
    }
    g.emit_op(OP_SWAP, swap_depth, cloc_comp);

    comp_body = g.new_block();
    g.use(comp_body);
    g.emit_op(OP_BUILD_SET, 0, cloc_comp);
    g.emit_op(OP_SWAP, 2, cloc_comp);

    loop_hdr = g.new_block();
    als = emit_anext_send_loop_header(g, loop_hdr, 3, iter_loc);

    store_blk = g.new_block();
    g.use(store_blk);
    g.u.comp_depth = g.u.comp_depth + 1;
    comp_emit_bind_target(
        g, gen.target, slots,
        comp_lead_is_loopvar(g, gen, sc.elt, bound_names, slots)
    );
    if codegen_busy(g) {
        g.u.comp_depth = g.u.comp_depth - 1;
        return;
    }
    comp_emit_single_elt(g, sc.elt, bound_names, OP_SET_ADD, elt_loc, False);
    if codegen_busy(g) {
        g.u.comp_depth = g.u.comp_depth - 1;
        return;
    }
    g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, elt_loc);
    g.u.comp_depth = g.u.comp_depth - 1;

    (cleanup_throw, cleanup_jump) = emit_anext_send_loop_footer(g, als, iter_loc);
    end_async_handler = g.new_block();
    g.use(end_async_handler);
    g.emit_jump(OP_END_ASYNC_FOR, als.end_send_blk.id, iter_loc);

    after = g.new_block();
    g.use(after);
    comp_emit_cleanup(g, slots, cloc_comp, swap_depth);

    comp_append_handler(
        g, comp_body.id, loop_hdr.id, 3, slots[0], cloc_comp, handler_group, -1, 2
    );
    g.u.except_regions.append(
        except_region(
            start_block=loop_hdr.id,
            end_block=als.yield_blk.id,
            handler_block=end_async_handler.id,
            stack_depth=4,
            preserve_lasti=False
        )
    );
    g.u.except_regions.append(
        except_region(
            start_block=als.yield_blk.id,
            end_block=als.after_resume_blk.id,
            handler_block=cleanup_throw.id,
            stack_depth=6,
            preserve_lasti=False
        )
    );
    g.u.except_regions.append(
        except_region(
            start_block=als.after_resume_blk.id,
            end_block=store_blk.id,
            handler_block=end_async_handler.id,
            stack_depth=4,
            preserve_lasti=False
        )
    );
    comp_append_handler(
        g, store_blk.id, cleanup_throw.id, 3, slots[0], cloc_comp, handler_group, -1, 2
    );
    g.u.except_regions.append(
        except_region(
            start_block=cleanup_throw.id,
            end_block=cleanup_jump.id,
            handler_block=end_async_handler.id,
            stack_depth=4,
            preserve_lasti=False
        )
    );
    comp_append_handler(
        g, end_async_handler.id, after.id, 3, slots[0], cloc_comp, handler_group, -1, 2
    );
    g.u.except_regions.append(
        except_region(
            start_block=after.id,
            end_block=-1,
            handler_block=-1,
            stack_depth=2,
            preserve_lasti=True
        )
    );
    g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    if protect >= 0 {
        g.u.except_regions.append(
            except_region(
                start_block=protect,
                end_block=comp_body.id,
                handler_block=-1,
                stack_depth=2,
                preserve_lasti=True
            )
        );
        g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    }
}

# Inline async dict comprehension `{k: v async for target in aiter}` inside an
# `async def`. Same shape as visit_list_comp_async with BUILD_MAP/MAP_ADD.
def visit_dict_comp_async(
    g: cfg_builder,
    dc: DictComp,
    gen: comprehension,
    bound_names: list[str],
    slots: list[int]
) {
    cloc_comp = expr_loc(dc);
    iter_loc = expr_loc(gen.iter);
    map_loc = comp_dict_map_loc(dc);
    handler_group = g.u.comp_handler_group;
    g.u.comp_handler_group = handler_group + 1;
    protect = g.generator_protect_start;

    swap_depth = 2;
    if len(slots) == 2 {
        swap_depth = 3;
    }

    visit_expr(g, gen.iter);
    if codegen_busy(g) {
        return;
    }
    g.emit_op(OP_GET_AITER, 0, iter_loc);
    si = 0;
    while si < len(slots) {
        g.emit_op(OP_LOAD_FAST_AND_CLEAR, slots[si], cloc_comp);
        si = si + 1;
    }
    g.emit_op(OP_SWAP, swap_depth, cloc_comp);

    comp_body = g.new_block();
    g.use(comp_body);
    g.emit_op(OP_BUILD_MAP, 0, cloc_comp);
    g.emit_op(OP_SWAP, 2, cloc_comp);

    loop_hdr = g.new_block();
    als = emit_anext_send_loop_header(g, loop_hdr, 3, iter_loc);

    store_blk = g.new_block();
    g.use(store_blk);
    g.u.comp_depth = g.u.comp_depth + 1;
    comp_emit_bind_target(
        g, gen.target, slots,
        comp_lead_is_loopvar(g, gen, dc.key, bound_names, slots)
    );
    if codegen_busy(g) {
        g.u.comp_depth = g.u.comp_depth - 1;
        return;
    }
    visit_comp_dict_kv(g, dc, bound_names, False);
    if codegen_busy(g) {
        g.u.comp_depth = g.u.comp_depth - 1;
        return;
    }
    g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, map_loc);
    g.u.comp_depth = g.u.comp_depth - 1;

    (cleanup_throw, cleanup_jump) = emit_anext_send_loop_footer(g, als, iter_loc);
    end_async_handler = g.new_block();
    g.use(end_async_handler);
    g.emit_jump(OP_END_ASYNC_FOR, als.end_send_blk.id, iter_loc);

    after = g.new_block();
    g.use(after);
    comp_emit_cleanup(g, slots, cloc_comp, swap_depth);

    comp_append_handler(
        g, comp_body.id, loop_hdr.id, 3, slots[0], cloc_comp, handler_group, -1, 2
    );
    g.u.except_regions.append(
        except_region(
            start_block=loop_hdr.id,
            end_block=als.yield_blk.id,
            handler_block=end_async_handler.id,
            stack_depth=4,
            preserve_lasti=False
        )
    );
    g.u.except_regions.append(
        except_region(
            start_block=als.yield_blk.id,
            end_block=als.after_resume_blk.id,
            handler_block=cleanup_throw.id,
            stack_depth=6,
            preserve_lasti=False
        )
    );
    g.u.except_regions.append(
        except_region(
            start_block=als.after_resume_blk.id,
            end_block=store_blk.id,
            handler_block=end_async_handler.id,
            stack_depth=4,
            preserve_lasti=False
        )
    );
    comp_append_handler(
        g, store_blk.id, cleanup_throw.id, 3, slots[0], cloc_comp, handler_group, -1, 2
    );
    g.u.except_regions.append(
        except_region(
            start_block=cleanup_throw.id,
            end_block=cleanup_jump.id,
            handler_block=end_async_handler.id,
            stack_depth=4,
            preserve_lasti=False
        )
    );
    comp_append_handler(
        g, end_async_handler.id, after.id, 3, slots[0], cloc_comp, handler_group, -1, 2
    );
    g.u.except_regions.append(
        except_region(
            start_block=after.id,
            end_block=-1,
            handler_block=-1,
            stack_depth=2,
            preserve_lasti=True
        )
    );
    g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    if protect >= 0 {
        g.u.except_regions.append(
            except_region(
                start_block=protect,
                end_block=comp_body.id,
                handler_block=-1,
                stack_depth=2,
                preserve_lasti=True
            )
        );
        g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
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
    if gen.is_async == 1 {
        if len(lc.generators) != 1 {
            codegen_fail(
                g, "NotImplementedError", "async list comprehension with multiple generators"
            );
            return;
        }
        visit_list_comp_async(g, lc, gen, bound_names, slots);
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
    g.u.comp_depth = g.u.comp_depth + 1;
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
    comp_emit_bind_target(
        g, gen.target, slots,
        comp_lead_is_loopvar(g, gen, lc.elt, bound_names, slots)
    );
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
    g.u.comp_depth = g.u.comp_depth - 1;
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
    if gen.is_async == 1 {
        if len(sc.generators) != 1 {
            codegen_fail(
                g, "NotImplementedError", "async set comprehension with multiple generators"
            );
            return;
        }
        visit_set_comp_async(g, sc, gen, bound_names, slots);
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
    g.u.comp_depth = g.u.comp_depth + 1;
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
    comp_emit_bind_target(
        g, gen.target, slots,
        comp_lead_is_loopvar(g, gen, sc.elt, bound_names, slots)
    );
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
    g.u.comp_depth = g.u.comp_depth - 1;
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
    if gen.is_async == 1 {
        if len(dc.generators) != 1 {
            codegen_fail(
                g, "NotImplementedError", "async dict comprehension with multiple generators"
            );
            return;
        }
        visit_dict_comp_async(g, dc, gen, bound_names, slots);
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
    g.u.comp_depth = g.u.comp_depth + 1;
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
    comp_emit_bind_target(
        g, gen.target, slots,
        comp_lead_is_loopvar(g, gen, dc.key, bound_names, slots)
    );
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
    g.u.comp_depth = g.u.comp_depth - 1;
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


# Lower raise (exc/cause forms; bare re-raise in handler context).
def visit_raise_stmt(g: cfg_builder, r: Raise) -> stmt_cont {
    rloc = nloc(r.lineno, r.end_lineno, r.col_offset, r.end_col_offset);
    if r.cause is not None {
        if r.exc is None {
            codegen_fail(g, "SyntaxError", "raise from without exception");
            return stmt_cont(loc=rloc);
        }
        visit_expr(g, r.exc);
        if codegen_busy(g) {
            return stmt_cont(loc=rloc);
        }
        visit_expr(g, r.cause);
        if codegen_busy(g) {
            return stmt_cont(loc=rloc);
        }
        g.emit_op(OP_RAISE_VARARGS, 2, rloc);
        return stmt_cont(loc=rloc, terminated=True);
    }
    if r.exc is not None {
        visit_expr(g, r.exc);
        if codegen_busy(g) {
            return stmt_cont(loc=rloc);
        }
        g.emit_op(OP_RAISE_VARARGS, 1, rloc);
        return stmt_cont(loc=rloc, terminated=True);
    }
    g.emit_op(OP_RAISE_VARARGS, 0, rloc);
    return stmt_cont(loc=rloc, terminated=True);
}


# Lower try/finally without except/else.
def visit_try_finally(
    g: cfg_builder,
    t: Try,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None
) -> stmt_cont {
    tloc = stmt_loc(t);
    nop_blk = g.new_block();
    try_entry = g.new_block();
    protect_end = g.new_block();
    after_protected = g.new_block();
    finally_except = g.new_block();
    unwind = g.new_block();
    g.use(nop_blk);
    g.emit_op(OP_NOP, 0, tloc);
    g.use(try_entry);
    protect_start = g.cur.id;
    try_follows = more_code_follows;
    if not try_follows and tail is not None and tail_idx < len(tail) {
        try_follows = True;
    }
    body_cont = visit_stmts(g, t.body, 0, True);
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    g.use(protect_end);
    finally_cont = visit_stmts(g, t.finalbody);
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    g.u.nested_try_finally_success_start = protect_end.id;
    g.use(after_protected);
    fallthrough_blk: basicblock | None = None;
    tail_end_blk: basicblock | None = None;
    tail_done = False;
    tail_terminated = False;
    if try_follows and tail is not None and tail_idx < len(tail) {
        tail_more = False;
        if tail_idx + 1 < len(tail) {
            tail_more = exec_tail_emits_code(tail, tail_idx + 1);
        }
        tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more);
        if codegen_busy(g) {
            return stmt_cont(loc=finally_cont.loc);
        }
        tail_done = True;
        tail_terminated = tail_cont.terminated;
        tail_end_blk = g.cur;
        if tail_cont.terminated {
            emit_module_return(g, tail_cont.loc);
        }
    } elif try_follows {
        fallthrough_blk = g.cur;
    } else {
        emit_module_return(g, finally_cont.loc);
    }
    g.u.nested_try_finally_success_end = after_protected.id;
    noloc = no_loc();
    g.use(finally_except);
    g.emit_op(OP_PUSH_EXC_INFO, 0, noloc);
    finally_except_cont = visit_stmts(g, t.finalbody);
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    g.emit_op(OP_RERAISE, 0, finally_except_cont.loc);
    g.u.except_regions.append(
        except_region(
            start_block=protect_start,
            end_block=protect_end.id,
            handler_block=finally_except.id,
            stack_depth=1
        )
    );
    g.u.except_regions.append(
        except_region(
            start_block=finally_except.id,
            end_block=unwind.id,
            handler_block=unwind.id,
            stack_depth=3,
            preserve_lasti=True
        )
    );
    g.use(unwind);
    g.u.nested_try_finally_unwind_start = unwind.id;
    g.emit_op(OP_COPY, 3, noloc);
    g.emit_op(OP_POP_EXCEPT, 0, noloc);
    g.emit_op(OP_RERAISE, 1, noloc);
    if fallthrough_blk is not None {
        g.use(fallthrough_blk);
        return stmt_cont(loc=tloc, terminated=False);
    }
    if tail_done {
        if tail_end_blk is not None {
            g.use(tail_end_blk);
        }
        return stmt_cont(
            loc=tloc, next_si=len(tail), terminated=tail_terminated
        );
    }
    return stmt_cont(loc=tloc, terminated=True);
}

def append_try_unwind_region(g: cfg_builder, reg: except_region) {
    g.u.except_regions.append(reg);
    g.u.pending_try_unwind_regions.append(len(g.u.except_regions) - 1);
}

def bind_try_unwind_handlers(g: cfg_builder, unwind_block: int) {
    pi = 0;
    while pi < len(g.u.pending_try_unwind_regions) {
        ri = g.u.pending_try_unwind_regions[pi];
        g.u.except_regions[ri].handler_block = unwind_block;
        pi = pi + 1;
    }
}

# Emit the inline (normal-path) copy of a finally body followed by the module
# return / tail continuation. `with_nop` matches CPython's leading NOP that
# appears when the finally block is laid out after the handlers (terminated
# body path).
def emit_finally_inline_block(
    g: cfg_builder,
    finalbody: list[stmt],
    blk: basicblock,
    with_nop: bool,
    more_code_follows: bool,
    tail: list[stmt] | None,
    tail_idx: int,
    tloc: cloc
) {
    g.use(blk);
    if with_nop {
        g.emit_op(OP_NOP, 0, tloc);
    }
    fc = visit_stmts(g, finalbody);
    if codegen_busy(g) {
        return;
    }
    fin_follows = more_code_follows;
    if not fin_follows and tail is not None and tail_idx < len(tail) {
        fin_follows = True;
    }
    if fin_follows {
        tail_more = False;
        if tail is not None and tail_idx + 1 < len(tail) {
            tail_more = exec_tail_emits_code(tail, tail_idx + 1);
        }
        tc = visit_stmt_tail(g, tail, tail_idx, tail_more);
        if codegen_busy(g) {
            return;
        }
        if not tc.terminated {
            emit_module_return(g, tc.loc);
        }
    } else {
        emit_module_return(g, fc.loc);
    }
}

# Lower flat try/except[/else]/finally by forward-nesting the finally around the
# try/except (CPython compiles them identically). Single handler, no as-binding.
def visit_try_except_finally(
    g: cfg_builder,
    t: Try,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None
) -> stmt_cont {
    tloc = stmt_loc(t);
    if len(t.handlers) != 1 {
        codegen_fail(
            g, "NotImplementedError",
            "try/except/finally: only a single handler is supported"
        );
        return stmt_cont(loc=tloc);
    }
    h0 = t.handlers[0];
    if h0.name is not None {
        codegen_fail(
            g, "NotImplementedError",
            "try/except/finally: except-as binding not supported"
        );
        return stmt_cont(loc=tloc);
    }
    noloc = no_loc();
    is_bare = h0.type is None;
    hloc = try_handler_span(h0);

    nop_blk = g.new_block();
    try_body = g.new_block();
    g.use(nop_blk);
    g.emit_op(OP_NOP, 0, tloc);
    g.use(try_body);
    protect_start = g.cur.id;
    body_cont = visit_stmts(g, t.body, 0, True);
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }

    protect_end = g.new_block();
    g.use(protect_end);
    normal_reaches_fin = not body_cont.terminated;
    if t.orelse is not None and len(t.orelse) > 0 and not body_cont.terminated {
        else_cont = visit_stmts(g, t.orelse, 0, True);
        if codegen_busy(g) {
            return stmt_cont(loc=tloc);
        }
        if else_cont.terminated {
            normal_reaches_fin = False;
        }
    }

    has_else = t.orelse is not None and len(t.orelse) > 0;

    fin_inline = g.new_deferred_block();
    handler_entry = g.new_deferred_block();
    handler_success = g.new_deferred_block();
    reraise_blk = g.new_deferred_block();
    inner_unwind = g.new_deferred_block();
    fin_except = g.new_deferred_block();
    outer_unwind = g.new_deferred_block();

    # try body -> inner except handler
    g.u.except_regions.append(
        except_region(
            start_block=protect_start,
            end_block=protect_end.id,
            handler_block=handler_entry.id,
            stack_depth=1
        )
    );

    # Lay the inline finally on the normal fall-through path (right after the
    # body/else) but leave it empty for now: its ops — and therefore its interned
    # names — are emitted after the handler so co_names order matches CPython.
    if normal_reaches_fin {
        g.use(fin_inline);
    }

    # Inner except handler.
    g.use(handler_entry);
    g.emit_op(OP_PUSH_EXC_INFO, 0, noloc);
    if not is_bare {
        visit_expr(g, h0.type);
        if codegen_busy(g) {
            return stmt_cont(loc=tloc);
        }
        g.emit_op(OP_CHECK_EXC_MATCH, 0, hloc);
        g.emit_jump(OP_POP_JUMP_IF_FALSE, reraise_blk.id, hloc);
    }
    g.emit_op(OP_POP_TOP, 0, hloc);
    hbody = visit_stmts(g, h0.body);
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    handler_reaches_fin = not hbody.terminated;
    if handler_reaches_fin {
        g.use(handler_success);
        g.emit_op(OP_POP_EXCEPT, 0, hbody.loc);
        if normal_reaches_fin {
            g.emit_jump(OP_JUMP_BACKWARD_NO_INTERRUPT, fin_inline.id, hbody.loc);
        } else {
            g.emit_jump(OP_JUMP_FORWARD, fin_inline.id, hbody.loc);
        }
    }
    if not is_bare {
        g.use(reraise_blk);
        g.emit_op(OP_RERAISE, 0, hloc);
    }
    g.use(inner_unwind);
    g.emit_op(OP_COPY, 3, noloc);
    g.emit_op(OP_POP_EXCEPT, 0, noloc);
    g.emit_op(OP_RERAISE, 1, noloc);

    # Fill the inline finally copy. When the normal path is live the block was
    # already placed above; otherwise it is laid out here (after the handlers)
    # with the leading NOP CPython emits on that path.
    emit_finally_inline_block(
        g, t.finalbody, fin_inline, not normal_reaches_fin,
        more_code_follows, tail, tail_idx, tloc
    );
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }

    # Exceptional (finally) handler: run finally, then re-raise.
    g.use(fin_except);
    g.emit_op(OP_PUSH_EXC_INFO, 0, noloc);
    fe_cont = visit_stmts(g, t.finalbody);
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    g.emit_op(OP_RERAISE, 0, fe_cont.loc);
    g.use(outer_unwind);
    g.emit_op(OP_COPY, 3, noloc);
    g.emit_op(OP_POP_EXCEPT, 0, noloc);
    g.emit_op(OP_RERAISE, 1, noloc);

    # Inner except handler code -> inner unwind.
    g.u.except_regions.append(
        except_region(
            start_block=handler_entry.id,
            end_block=handler_success.id,
            handler_block=inner_unwind.id,
            stack_depth=3,
            preserve_lasti=True
        )
    );
    if not is_bare {
        g.u.except_regions.append(
            except_region(
                start_block=reraise_blk.id,
                end_block=inner_unwind.id,
                handler_block=inner_unwind.id,
                stack_depth=3,
                preserve_lasti=True
            )
        );
    }
    inner_unwind_region_end = fin_except.id;
    if not normal_reaches_fin {
        inner_unwind_region_end = fin_inline.id;
    }
    # Inner handler epilogue -> finally handler. With a typed handler the epilogue
    # ends at the no-match RERAISE block; a bare handler has no such block, so the
    # epilogue and the inner unwind form one contiguous finally-protected range.
    unwind_region_start = inner_unwind.id;
    if not is_bare {
        if handler_reaches_fin {
            g.u.except_regions.append(
                except_region(
                    start_block=handler_success.id,
                    end_block=reraise_blk.id,
                    handler_block=fin_except.id,
                    stack_depth=1
                )
            );
        }
    } elif handler_reaches_fin {
        unwind_region_start = handler_success.id;
    }
    g.u.except_regions.append(
        except_region(
            start_block=unwind_region_start,
            end_block=inner_unwind_region_end,
            handler_block=fin_except.id,
            stack_depth=1
        )
    );
    # Finally handler -> outer unwind.
    g.u.except_regions.append(
        except_region(
            start_block=fin_except.id,
            end_block=outer_unwind.id,
            handler_block=outer_unwind.id,
            stack_depth=3,
            preserve_lasti=True
        )
    );
    # else body (normal-path, laid out before the inline finally) -> finally
    # handler, so an exception raised in the else clause still runs finally.
    if has_else and normal_reaches_fin {
        g.u.except_regions.append(
            except_region(
                start_block=protect_end.id,
                end_block=fin_inline.id,
                handler_block=fin_except.id,
                stack_depth=1
            )
        );
    }
    return stmt_cont(loc=tloc, terminated=True);
}

# Lower try/except (typed handlers; optional finally deferred).
def visit_try(
    g: cfg_builder,
    t: Try,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None
) -> stmt_cont {
    tloc = stmt_loc(t);
    if t.finalbody is not None and len(t.finalbody) > 0 {
        if t.handlers is not None and len(t.handlers) > 0 {
            return visit_try_except_finally(
                g, t, more_code_follows, tail, tail_idx, tail_join
            );
        }
        return visit_try_finally(
            g, t, more_code_follows, tail, tail_idx, tail_join
        );
    }
    if t.handlers is None or len(t.handlers) == 0 {
        codegen_fail(g, "NotImplementedError", "try without except");
        return stmt_cont(loc=tloc);
    }
    nop_blk = g.new_block();
    try_body = g.new_block();
    g.use(nop_blk);
    g.emit_op(OP_NOP, 0, tloc);
    g.use(try_body);
    protect_start = g.cur.id;
    try_follows = more_code_follows;
    if not try_follows and tail is not None and tail_idx < len(tail) {
        try_follows = True;
    }
    body_cont = visit_stmts(g, t.body, 0, try_follows, tail, tail_idx, tail_join);
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    protect_end = g.new_block();
    after_try_epilogue = g.new_block();
    g.use(protect_end);
    g.use(after_try_epilogue);
    normal_terminated = body_cont.terminated;
    if t.orelse is not None and len(t.orelse) > 0 and not body_cont.terminated {
        else_cont = visit_stmts(
            g, t.orelse, 0, try_follows, tail, tail_idx, tail_join
        );
        if codegen_busy(g) {
            return stmt_cont(loc=tloc);
        }
        if else_cont.terminated {
            normal_terminated = True;
        }
    }
    if try_follows {
        tail_more = False;
        if tail is not None and tail_idx + 1 < len(tail) {
            tail_more = exec_tail_emits_code(tail, tail_idx + 1);
        }
        tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more);
        if codegen_busy(g) {
            return stmt_cont(loc=body_cont.loc);
        }
        if not tail_cont.terminated and not normal_terminated {
            emit_module_return(g, tail_cont.loc);
        }
    } else {
        if not normal_terminated {
            emit_module_return(g, body_cont.loc);
        }
    }
    handler_entry = g.new_block();
    handler_body_entries: list[basicblock] = [];
    handler_tails: list[tuple[basicblock, basicblock]] = [];
    as_unwind_tails: list[tuple[basicblock, basicblock]] = [];
    next_handlers: list[basicblock] = [];
    hi = 0;
    while hi < len(t.handlers) {
        handler_body_entries.append(g.new_block());
        handler_tails.append((g.new_block(), g.new_block()));
        as_unwind_tails.append((g.new_block(), g.new_block()));
        if hi < len(t.handlers) - 1 {
            next_handlers.append(g.new_block());
        }
        hi = hi + 1;
    }
    reraise_blk = g.new_block();
    if body_is_try_finally_only(t.body) {
        if g.u.nested_try_finally_success_start >= 0
            and g.u.nested_try_finally_success_end >= 0 {
            g.u.except_regions.append(
                except_region(
                    start_block=g.u.nested_try_finally_success_start,
                    end_block=g.u.nested_try_finally_success_end,
                    handler_block=handler_entry.id,
                    stack_depth=1
                )
            );
        }
        if g.u.nested_try_finally_unwind_start >= 0 {
            g.u.except_regions.append(
                except_region(
                    start_block=g.u.nested_try_finally_unwind_start,
                    end_block=handler_entry.id,
                    handler_block=handler_entry.id,
                    stack_depth=1
                )
            );
        }
    } else {
        g.u.except_regions.append(
            except_region(
                start_block=protect_start,
                end_block=protect_end.id,
                handler_block=handler_entry.id,
                stack_depth=1
            )
        );
    }
    noloc = no_loc();
    g.use(handler_entry);
    handler_region_start = handler_entry.id;
    g.emit_op(OP_PUSH_EXC_INFO, 0, noloc);
    hloc = try_handler_span(t.handlers[0]);
    need_reraise_except_region = False;
    merged_handler_unwind_start = -1;
    except_as_unwind_start = -1;
    hi = 0;
    while hi < len(t.handlers) {
        h = t.handlers[hi];
        if hi > 0 {
            g.use(next_handlers[hi - 1]);
            handler_region_start = g.cur.id;
        }
        hloc = try_handler_span(h);
        if h.type is None {
            # bare except: always matches, no CHECK_EXC_MATCH / POP_JUMP.
        } else {
            visit_expr(g, h.type);
            if codegen_busy(g) {
                return stmt_cont(loc=tloc);
            }
            g.emit_op(OP_CHECK_EXC_MATCH, 0, hloc);
            if hi < len(t.handlers) - 1 {
                g.emit_jump(OP_POP_JUMP_IF_FALSE, next_handlers[hi].id, hloc);
            } else {
                g.emit_jump(OP_POP_JUMP_IF_FALSE, reraise_blk.id, hloc);
            }
        }
        bind_name = h.name;
        if bind_name is not None {
            emit_name_store(g, bind_name, hloc);
        } else {
            g.emit_op(OP_POP_TOP, 0, hloc);
        }
        handler_body_start = handler_body_entries[hi].id;
        g.use(handler_body_entries[hi]);
        hbody = visit_stmts(g, h.body);
        if codegen_busy(g) {
            return stmt_cont(loc=tloc);
        }
        handler_region_end = handler_tails[hi][0];
        handler_success = handler_tails[hi][1];
        g.use(handler_region_end);
        if not hbody.terminated {
            need_reraise_except_region = True;
            g.use(handler_success);
            g.emit_op(OP_POP_EXCEPT, 0, hbody.loc);
            if bind_name is not None {
                emit_except_as_cleanup(g, bind_name, hbody.loc);
            }
            emit_module_return(g, hbody.loc);
        } else {
            if merged_handler_unwind_start < 0 {
                merged_handler_unwind_start = handler_region_start;
            }
        }
        if bind_name is not None {
            append_try_unwind_region(
                g,
                except_region(
                    start_block=handler_region_start,
                    end_block=handler_body_start,
                    handler_block=-1,
                    stack_depth=3,
                    preserve_lasti=True
                )
            );
            as_unwind = as_unwind_tails[hi][0];
            g.use(as_unwind);
            except_as_unwind_start = as_unwind.id;
            emit_except_as_cleanup(g, bind_name, hbody.loc);
            g.emit_op(OP_RERAISE, 1, hbody.loc);
            as_unwind_end = as_unwind_tails[hi][1];
            g.u.except_regions.append(
                except_region(
                    start_block=handler_body_start,
                    end_block=handler_region_end.id,
                    handler_block=as_unwind.id,
                    stack_depth=3,
                    preserve_lasti=True
                )
            );
        } else {
            if not hbody.terminated {
                append_try_unwind_region(
                    g,
                    except_region(
                        start_block=handler_region_start,
                        end_block=handler_region_end.id,
                        handler_block=-1,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
            }
        }
        hi = hi + 1;
    }
    last_is_bare = t.handlers[len(t.handlers) - 1].type is None;
    if not last_is_bare {
        g.use(reraise_blk);
        g.emit_op(OP_RERAISE, 0, hloc);
    }
    reraise_end = g.new_block();
    unwind_blk = g.new_block();
    if need_reraise_except_region {
        if except_as_unwind_start >= 0 {
            append_try_unwind_region(
                g,
                except_region(
                    start_block=except_as_unwind_start,
                    end_block=unwind_blk.id,
                    handler_block=-1,
                    stack_depth=3,
                    preserve_lasti=True
                )
            );
        } elif not last_is_bare {
            append_try_unwind_region(
                g,
                except_region(
                    start_block=reraise_blk.id,
                    end_block=reraise_end.id,
                    handler_block=-1,
                    stack_depth=3,
                    preserve_lasti=True
                )
            );
        }
    } else {
        append_try_unwind_region(
            g,
            except_region(
                start_block=merged_handler_unwind_start,
                end_block=unwind_blk.id,
                handler_block=-1,
                stack_depth=3,
                preserve_lasti=True
            )
        );
    }
    bind_try_unwind_handlers(g, unwind_blk.id);
    g.use(unwind_blk);
    g.emit_op(OP_COPY, 3, noloc);
    g.emit_op(OP_POP_EXCEPT, 0, noloc);
    g.emit_op(OP_RERAISE, 1, noloc);
    return stmt_cont(loc=tloc, terminated=True);
}

# Lower with (single item, optional_vars required).
def visit_with(
    g: cfg_builder,
    w: With,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None
) -> stmt_cont {
    wloc = stmt_loc(w);
    if len(w.items) < 1 {
        codegen_fail(g, "SyntaxError", "with requires at least one item");
        return stmt_cont(loc=wloc);
    }
    noloc = no_loc();
    n = len(w.items);
    # --- enters: for each item, emit context-manager setup + bind target ---
    store_ids: list[int] = [];
    ei = 0;
    while ei < n {
        it = w.items[ei];
        cl = expr_loc(it.context_expr);
        visit_expr(g, it.context_expr);
        if codegen_busy(g) {
            return stmt_cont(loc=wloc);
        }
        g.emit_op(OP_COPY, 1, cl);
        g.emit_op(OP_LOAD_SPECIAL, 1, cl);
        g.emit_op(OP_SWAP, 2, cl);
        g.emit_op(OP_SWAP, 3, cl);
        g.emit_op(OP_LOAD_SPECIAL, 0, cl);
        g.emit_op(OP_CALL, 0, cl);
        if codegen_busy(g) {
            return stmt_cont(loc=wloc);
        }
        bind_blk = g.new_block();
        g.use(bind_blk);
        if it.optional_vars is None {
            g.emit_op(OP_POP_TOP, 0, cl);
        } else {
            visit_store_target_tos(g, it.optional_vars);
            if codegen_busy(g) {
                return stmt_cont(loc=wloc);
            }
        }
        store_ids.append(g.cur.id);
        ei = ei + 1;
    }
    # --- body ---
    with_body = g.new_block();
    g.use(with_body);
    with_follows = more_code_follows;
    if not with_follows and tail is not None and tail_idx < len(tail) {
        with_follows = True;
    }
    body_cont = visit_stmts(g, w.body, 0, with_follows, tail, tail_idx, tail_join);
    if codegen_busy(g) {
        return stmt_cont(loc=wloc);
    }
    # --- inline __exit__ calls, innermost first (xs[k] is frame n-1-k) ---
    none_idx = g.u.add_const(py_none());
    xs: list[basicblock] = [];
    k = 0;
    while k < n {
        xblk = g.new_block();
        g.use(xblk);
        g.emit_op(OP_LOAD_CONST, none_idx, wloc);
        g.emit_op(OP_LOAD_CONST, none_idx, wloc);
        g.emit_op(OP_LOAD_CONST, none_idx, wloc);
        g.emit_op(OP_CALL, 3, wloc);
        g.emit_op(OP_POP_TOP, 0, wloc);
        xs.append(xblk);
        k = k + 1;
    }
    # normal-path continuation (after outermost inline exit)
    if with_follows {
        tail_more = False;
        if tail is not None and tail_idx + 1 < len(tail) {
            tail_more = exec_tail_emits_code(tail, tail_idx + 1);
        }
        tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more);
        if codegen_busy(g) {
            return stmt_cont(loc=body_cont.loc);
        }
        if not tail_cont.terminated {
            emit_module_return(g, tail_cont.loc);
        }
    } else {
        emit_module_return(g, body_cont.loc);
    }
    # --- cleanup handlers, innermost first (ws/ends/uns[k] is frame n-1-k) ---
    ws: list[basicblock] = [];
    ends: list[basicblock] = [];
    uns: list[basicblock] = [];
    k = 0;
    while k < n {
        i_frame = n - 1 - k;
        with_except = g.new_block();
        g.use(with_except);
        g.emit_op(OP_PUSH_EXC_INFO, 0, noloc);
        g.emit_op(OP_WITH_EXCEPT_START, 0, noloc);
        g.emit_op(OP_TO_BOOL, 0, noloc);
        suppressed = g.new_block();
        g.emit_jump(OP_POP_JUMP_IF_TRUE, suppressed.id, noloc);
        g.emit_op(OP_RERAISE, 2, noloc);
        g.use(suppressed);
        g.emit_op(OP_POP_TOP, 0, noloc);
        cleanup_end = g.new_block();
        g.use(cleanup_end);
        g.emit_op(OP_POP_EXCEPT, 0, noloc);
        g.emit_op(OP_POP_TOP, 0, noloc);
        g.emit_op(OP_POP_TOP, 0, noloc);
        g.emit_op(OP_POP_TOP, 0, noloc);
        if i_frame > 0 {
            # fall back to the enclosing frame's inline __exit__ (xs[k+1] = X_{i-1})
            g.emit_jump(OP_JUMP_BACKWARD_NO_INTERRUPT, xs[k + 1].id, wloc);
        } else {
            emit_module_return(g, wloc);
        }
        unwind = g.new_block();
        g.use(unwind);
        g.emit_op(OP_COPY, 3, noloc);
        g.emit_op(OP_POP_EXCEPT, 0, noloc);
        g.emit_op(OP_RERAISE, 1, noloc);
        ws.append(with_except);
        ends.append(cleanup_end);
        uns.append(unwind);
        k = k + 1;
    }
    # --- exception regions (carved so the assembler emits them verbatim) ---
    i = 0;
    while i < n {
        s_i = store_ids[i];
        x_i = xs[n - 1 - i];
        w_i = ws[n - 1 - i];
        e_i = ends[n - 1 - i];
        u_i = uns[n - 1 - i];
        if i == n - 1 {
            # innermost: protected body
            g.u.except_regions.append(
                except_region(
                    start_block=s_i,
                    end_block=x_i.id,
                    handler_block=w_i.id,
                    stack_depth=4 + 2 * i,
                    preserve_lasti=True
                )
            );
        } else {
            s_next = store_ids[i + 1];
            x_next = xs[n - 2 - i];
            e_next = ends[n - 2 - i];
            # enter of the next-inner item
            g.u.except_regions.append(
                except_region(
                    start_block=s_i,
                    end_block=s_next,
                    handler_block=w_i.id,
                    stack_depth=4 + 2 * i,
                    preserve_lasti=True
                )
            );
            # inline __exit__ of the next-inner frame
            g.u.except_regions.append(
                except_region(
                    start_block=x_next.id,
                    end_block=x_i.id,
                    handler_block=w_i.id,
                    stack_depth=4 + 2 * i,
                    preserve_lasti=True
                )
            );
            # cleanup tail + unwind of the next-inner frame
            g.u.except_regions.append(
                except_region(
                    start_block=e_next.id,
                    end_block=w_i.id,
                    handler_block=w_i.id,
                    stack_depth=4 + 2 * i,
                    preserve_lasti=True
                )
            );
        }
        # this frame's own cleanup handler
        g.u.except_regions.append(
            except_region(
                start_block=w_i.id,
                end_block=e_i.id,
                handler_block=u_i.id,
                stack_depth=6 + 2 * i,
                preserve_lasti=True
            )
        );
        i = i + 1;
    }
    return stmt_cont(loc=wloc, terminated=True);
}

# Lower async with (single item, optional_vars required).
def visit_async_with(
    g: cfg_builder,
    w: AsyncWith,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None
) -> stmt_cont {
    wloc = stmt_loc(w);
    if len(w.items) != 1 {
        codegen_fail(g, "NotImplementedError", "multiple with items not supported");
        return stmt_cont(loc=wloc);
    }
    item = w.items[0];
    cloc = expr_loc(item.context_expr);
    visit_expr(g, item.context_expr);
    if codegen_busy(g) {
        return stmt_cont(loc=wloc);
    }
    g.emit_op(OP_COPY, 1, cloc);
    g.emit_op(OP_LOAD_SPECIAL, 3, cloc);
    g.emit_op(OP_SWAP, 2, cloc);
    g.emit_op(OP_SWAP, 3, cloc);
    g.emit_op(OP_LOAD_SPECIAL, 2, cloc);
    g.emit_op(OP_CALL, 0, cloc);
    if codegen_busy(g) {
        return stmt_cont(loc=wloc);
    }
    enter_als = emit_await_send_loop_header(
        g, OP_GET_AWAITABLE, 1, 3, cloc
    );
    bind_blk = g.new_block();
    g.use(bind_blk);
    if item.optional_vars is None {
        g.emit_op(OP_POP_TOP, 0, cloc);
    } else {
        visit_store_target_tos(g, item.optional_vars);
        if codegen_busy(g) {
            return stmt_cont(loc=wloc);
        }
    }
    protect_start = bind_blk.id;
    with_body = g.new_block();
    g.use(with_body);
    with_follows = more_code_follows;
    if not with_follows and tail is not None and tail_idx < len(tail) {
        with_follows = True;
    }
    body_cont = visit_stmts(g, w.body, 0, with_follows, tail, tail_idx, tail_join);
    if codegen_busy(g) {
        return stmt_cont(loc=wloc);
    }
    protect_end = g.new_block();
    g.use(protect_end);
    none_idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, wloc);
    g.emit_op(OP_LOAD_CONST, none_idx, wloc);
    g.emit_op(OP_LOAD_CONST, none_idx, wloc);
    g.emit_op(OP_CALL, 3, wloc);
    exit_als = emit_await_send_loop_header(
        g, OP_GET_AWAITABLE, 2, 3, wloc
    );
    g.emit_op(OP_POP_TOP, 0, wloc);
    if with_follows {
        tail_more = False;
        if tail is not None and tail_idx + 1 < len(tail) {
            tail_more = exec_tail_emits_code(tail, tail_idx + 1);
        }
        if tail is not None and tail_idx < len(tail) {
            ts = tail[tail_idx];
            if isinstance(ts, Return) {
                visit_return_stmt(g, ts as Return, False, True);
            } else {
                tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more);
                if codegen_busy(g) {
                    return stmt_cont(loc=body_cont.loc);
                }
                if not tail_cont.terminated {
                    emit_module_return(g, tail_cont.loc);
                }
            }
        } else {
            tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more);
            if codegen_busy(g) {
                return stmt_cont(loc=body_cont.loc);
            }
            if not tail_cont.terminated {
                emit_module_return(g, tail_cont.loc);
            }
        }
    } else {
        emit_module_return(g, body_cont.loc);
    }
    (enter_ct, enter_cj) = emit_await_send_loop_footer(g, enter_als, cloc);
    emit_await_send_except_regions(
        g, enter_als, enter_ct, enter_cj, 5, -1, -1, bind_blk.id, 2, True
    );
    (exit_ct, exit_cj) = emit_await_send_loop_footer(g, exit_als, wloc);
    emit_await_send_except_regions(
        g,
        exit_als,
        exit_ct,
        exit_cj,
        3,
        -1,
        protect_end.id,
        enter_cj.id,
        2,
        True
    );
    g.u.except_regions.append(
        except_region(
            start_block=exit_ct.id,
            end_block=exit_cj.id,
            handler_block=-1,
            stack_depth=2,
            preserve_lasti=True
        )
    );
    g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    with_except = g.new_block();
    noloc = no_loc();
    g.use(with_except);
    g.emit_op(OP_PUSH_EXC_INFO, 0, noloc);
    g.emit_op(OP_WITH_EXCEPT_START, 0, noloc);
    (except_als, except_ct, except_cj) = emit_await_send_loop_inline_footer(
        g, OP_GET_AWAITABLE, 2, 3, noloc
    );
    g.use(except_als.end_send_blk);
    g.emit_op(OP_END_SEND, 0, noloc);
    g.emit_op(OP_TO_BOOL, 0, noloc);
    not_taken_blk = g.new_block();
    reraise_blk = g.new_block();
    suppressed = g.new_block();
    g.emit_jump(OP_POP_JUMP_IF_TRUE, suppressed.id, noloc);
    g.use(not_taken_blk);
    g.emit_op(OP_NOT_TAKEN, 0, noloc);
    g.use(reraise_blk);
    g.emit_op(OP_RERAISE, 2, noloc);
    g.use(suppressed);
    g.emit_op(OP_POP_TOP, 0, noloc);
    cleanup_end = g.new_block();
    g.use(cleanup_end);
    g.emit_op(OP_POP_EXCEPT, 0, noloc);
    g.emit_op(OP_POP_TOP, 0, noloc);
    g.emit_op(OP_POP_TOP, 0, noloc);
    g.emit_op(OP_POP_TOP, 0, noloc);
    if with_follows and tail is not None and tail_idx < len(tail) {
        ts = tail[tail_idx];
        if isinstance(ts, Return) {
            visit_return_stmt(g, ts as Return, True);
        } else {
            emit_module_return(g, wloc);
        }
    } else {
        emit_module_return(g, wloc);
    }
    g.u.except_regions.append(
        except_region(
            start_block=cleanup_end.id,
            end_block=-1,
            handler_block=-1,
            stack_depth=2,
            preserve_lasti=True
        )
    );
    g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    unwind = g.new_block();
    g.u.except_regions.append(
        except_region(
            start_block=except_als.yield_blk.id,
            end_block=except_als.after_resume_blk.id,
            handler_block=except_ct.id,
            stack_depth=8,
            preserve_lasti=False
        )
    );
    g.u.except_regions.append(
        except_region(
            start_block=except_als.after_resume_blk.id,
            end_block=not_taken_blk.id,
            handler_block=unwind.id,
            stack_depth=6,
            preserve_lasti=True
        )
    );
    g.u.except_regions.append(
        except_region(
            start_block=protect_start,
            end_block=protect_end.id,
            handler_block=with_except.id,
            stack_depth=4,
            preserve_lasti=True
        )
    );
    g.u.except_regions.append(
        except_region(
            start_block=with_except.id,
            end_block=except_als.yield_blk.id,
            handler_block=unwind.id,
            stack_depth=6,
            preserve_lasti=True
        )
    );
    g.u.except_regions.append(
        except_region(
            start_block=reraise_blk.id,
            end_block=cleanup_end.id,
            handler_block=unwind.id,
            stack_depth=6,
            preserve_lasti=True
        )
    );
    g.use(unwind);
    g.emit_op(OP_COPY, 3, noloc);
    g.emit_op(OP_POP_EXCEPT, 0, noloc);
    g.emit_op(OP_RERAISE, 1, noloc);
    if with_follows {
        return stmt_cont(loc=wloc, next_si=len(tail), terminated=True);
    }
    return stmt_cont(loc=wloc, terminated=True);
}

# Lower assert (test + optional message).
def visit_assert_stmt(g: cfg_builder, a: Assert) -> stmt_cont {
    aloc = nloc(a.lineno, a.end_lineno, a.col_offset, a.end_col_offset);
    test_loc = expr_loc(a.test);
    visit_test_expr(g, a.test, test_loc);
    if codegen_busy(g) {
        return stmt_cont(loc=aloc);
    }
    ok = g.new_block();
    g.emit_jump(OP_POP_JUMP_IF_TRUE, ok.id, test_loc);
    g.emit_op(OP_LOAD_COMMON_CONSTANT, 0, aloc);
    if a.msg is not None {
        visit_expr(g, a.msg);
        if codegen_busy(g) {
            return stmt_cont(loc=aloc);
        }
        g.emit_op(OP_CALL, 0, aloc);
    }
    g.emit_op(OP_RAISE_VARARGS, 1, aloc);
    g.use(ok);
    return stmt_cont(loc=aloc);
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

obj match_pat_ctx {
    has stores: list[str];
    has on_top: int;
    has cleanup_blocks: list[basicblock];
    has max_cleanup: int;
    has allow_irrefutable: bool;
}




def match_subject_use_load_fast(g: cfg_builder, m: Match) -> bool {
    has_default = 0;
    if len(m.cases) > 1 {
        if match_pattern_wildcard(m.cases[len(m.cases) - 1].pattern) {
            has_default = 1;
        }
    }
    if len(m.cases) - has_default > 1 {
        return True;
    }
    ci = 0;
    while ci < len(m.cases) {
        raw = m.cases[ci].pattern;
        if isinstance(raw, MatchOr) and len((raw as MatchOr).patterns) > 1 {
            # Multi-alternative OR copies the subject per alternative, so it must
            # be owned (LOAD_FAST), not borrowed.
            return True;
        }
        p = match_pattern_unwrap_or(raw);
        if isinstance(p, MatchSequence) or isinstance(p, MatchMapping) {
            return True;
        }
        ci = ci + 1;
    }
    return False;
}

def match_emit_subject(g: cfg_builder, m: Match) {
    subj = m.subject;
    if isinstance(subj, Name) {
        n = subj as Name;
        tloc = nloc(n.lineno, n.end_lineno, n.col_offset, n.end_col_offset);
        name = codegen_mangle(g, n.id);
        fi = fast_local_index(g, name);
        if fi >= 0 {
            if match_subject_use_load_fast(g, m) {
                g.emit_op(OP_LOAD_FAST, fi, tloc);
            } else {
                g.emit_op(OP_LOAD_FAST_BORROW, fi, tloc);
            }
            return;
        }
    }
    visit_expr(g, subj);
}

obj match_case_start {
    has ctx: match_pat_ctx;
    has next_arm: basicblock;
}

# Exact maximum fail-pop depth for a pattern entered with `on_top` extra stack
# items and `nstores` deferred capture names. Mirrors emit_match_pattern's
# on_top/stores accounting so cleanup blocks can be pre-allocated in layout order
# (block id order == layout order is assumed by the flowgraph). Returns
# (max_pops, nstores_after); max_pops is -1 when the pattern never jumps to fail.
def match_fail_levels(p: pattern, on_top: int, nstores: int) -> tuple[int, int] {
    p = match_pattern_unwrap_or(p);
    if isinstance(p, MatchValue) or isinstance(p, MatchSingleton) {
        return (on_top + nstores, nstores);
    }
    if isinstance(p, MatchAs) {
        ma = p as MatchAs;
        if ma.pattern is None {
            ns = nstores;
            if ma.name is not None {
                ns = nstores + 1;
            }
            return (-1, ns);
        }
        sub = match_fail_levels(ma.pattern, on_top + 1, nstores);
        ns2 = sub[1];
        if ma.name is not None {
            ns2 = ns2 + 1;
        }
        return (sub[0], ns2);
    }
    if isinstance(p, MatchSequence) {
        ms = p as MatchSequence;
        patterns = ms.patterns;
        size = len(patterns);
        star = -1;
        only_wildcard = True;
        pi = 0;
        while pi < size {
            pat = patterns[pi];
            if isinstance(pat, MatchStar) {
                star = pi;
                mst = pat as MatchStar;
                if mst.name is not None {
                    only_wildcard = False;
                }
            } elif not match_pattern_wildcard(pat) {
                only_wildcard = False;
            }
            pi = pi + 1;
        }
        d1 = (on_top + 1) + nstores;
        if star >= 0 {
            return (d1, nstores);
        }
        if only_wildcard or match_sequence_all_captures(patterns) {
            return (d1, nstores);
        }
        maxf = d1;
        cur = on_top + size;
        ns = nstores;
        pi = 0;
        while pi < size {
            cur = cur - 1;
            sub = match_fail_levels(patterns[pi], cur, ns);
            if sub[0] > maxf {
                maxf = sub[0];
            }
            ns = sub[1];
            pi = pi + 1;
        }
        return (maxf, ns);
    }
    if isinstance(p, MatchMapping) {
        mm = p as MatchMapping;
        mm_keys: list[expr] = mm.keys if mm.keys is not None else [];
        mm_patterns: list[pattern] = mm.patterns if mm.patterns is not None else [];
        size = len(mm_keys);
        d1 = (on_top + 1) + nstores;
        if size == 0 and mm.rest is None {
            return (d1, nstores);
        }
        maxf = d1;
        f2 = (on_top + 3) + nstores;
        if f2 > maxf {
            maxf = f2;
        }
        cur = on_top + size + 2;
        ns = nstores;
        pi = 0;
        while pi < size {
            cur = cur - 1;
            sub = match_fail_levels(mm_patterns[pi], cur, ns);
            if sub[0] > maxf {
                maxf = sub[0];
            }
            ns = sub[1];
            pi = pi + 1;
        }
        if mm.rest is not None {
            ns = ns + 1;
        }
        return (maxf, ns);
    }
    if isinstance(p, MatchClass) {
        mc = p as MatchClass;
        mc_patterns: list[pattern] = mc.patterns if mc.patterns is not None else [];
        mc_kwd: list[pattern] = mc.kwd_patterns if mc.kwd_patterns is not None else [];
        nargs = len(mc_patterns);
        nattrs = len(mc_kwd);
        total = nargs + nattrs;
        maxf = (on_top + 1) + nstores;
        cur = on_top + total;
        ns = nstores;
        i = 0;
        while i < total {
            cur = cur - 1;
            sp: pattern = mc_patterns[i] if i < nargs else mc_kwd[i - nargs];
            if not match_pattern_wildcard(sp) {
                sub = match_fail_levels(sp, cur, ns);
                if sub[0] > maxf {
                    maxf = sub[0];
                }
                ns = sub[1];
            }
            i = i + 1;
        }
        return (maxf, ns);
    }
    return (on_top + nstores, nstores);
}

def match_arm_cleanup_levels(p: pattern) -> int {
    res = match_fail_levels(p, 0, 0);
    if res[0] < 0 {
        return 0;
    }
    return res[0];
}

# Allocate `levels` cleanup blocks + next_arm so their block ids ascend in the
# exact layout order needed for fail-pop fallthrough chaining: the block reached
# by an N-deep fail pops N items across N contiguous blocks that fall through to
# next_arm. cleanup_blocks[i] is the target for a fail that must pop i+1 items.
def match_begin_case(g: cfg_builder, levels: int) -> match_case_start {
    # Deferred blocks: laid out at use() (CPython USE_LABEL) so the fail-pop chain
    # and next_arm land after the arm body, and after any deferred blocks a MatchOr
    # alternative emits. Placement order (not allocation order) is authoritative.
    cleanup: list[basicblock] = [];
    i = 0;
    while i < levels {
        blk = g.new_deferred_block();
        blk.exit_inline_ok = True;
        cleanup.append(blk);
        i = i + 1;
    }
    next_arm = g.new_deferred_block();
    next_arm.exit_inline_ok = True;
    ctx = match_pat_ctx(
        stores=[],
        on_top=0,
        cleanup_blocks=cleanup,
        max_cleanup=0,
        allow_irrefutable=False
    );
    return match_case_start(ctx=ctx, next_arm=next_arm);
}

def match_ensure_cleanup_blocks(g: cfg_builder, ctx: match_pat_ctx, n: int) {
    while len(ctx.cleanup_blocks) < n {
        blk = g.new_deferred_block();
        ctx.cleanup_blocks.append(blk);
    }
}

def match_jump_to_fail(
    g: cfg_builder,
    ctx: match_pat_ctx,
    next_arm: basicblock,
    jump_op: int,
    loc: cloc
) {
    pops = ctx.on_top + len(ctx.stores);
    if pops > ctx.max_cleanup {
        ctx.max_cleanup = pops;
    }
    if pops == 0 {
        g.emit_jump(jump_op, next_arm.id, loc);
        return;
    }
    match_ensure_cleanup_blocks(g, ctx, pops);
    g.emit_jump(jump_op, ctx.cleanup_blocks[pops - 1].id, loc);
}

def match_emit_reset_fail_pop(
    g: cfg_builder, ctx: match_pat_ctx, next_arm: basicblock, loc: cloc
) {
    idx = ctx.max_cleanup - 1;
    while idx >= 0 {
        g.use(ctx.cleanup_blocks[idx]);
        g.emit_op(OP_POP_TOP, 0, loc);
        idx = idx - 1;
    }
    g.use(next_arm);
    ctx.max_cleanup = 0;
}

def match_pattern_rotate(g: cfg_builder, loc: cloc, count: int) {
    while count > 1 {
        g.emit_op(OP_SWAP, count, loc);
        count = count - 1;
    }
}

def match_pattern_helper_store_name(
    g: cfg_builder, name: str | None, ctx: match_pat_ctx, loc: cloc
) -> bool {
    if name is None {
        g.emit_op(OP_POP_TOP, 0, loc);
        return True;
    }
    si = 0;
    while si < len(ctx.stores) {
        if ctx.stores[si] == name {
            codegen_fail(
                g,
                "SyntaxError",
                "multiple assignments to name in pattern"
            );
            return False;
        }
        si = si + 1;
    }
    rot = ctx.on_top + len(ctx.stores) + 1;
    match_pattern_rotate(g, loc, rot);
    ctx.stores.append(name);
    return True;
}

def match_emit_case_stores(g: cfg_builder, ctx: match_pat_ctx, loc: cloc) {
    # Emit separate stores in capture order; optimize_swap_range folds adjacent
    # STORE_FAST pairs into STORE_FAST_STORE_FAST (and reorders via static swaps)
    # to match CPython's post-optimizer shape.
    n = len(ctx.stores);
    si = 0;
    while si < n {
        emit_name_store(g, ctx.stores[si], loc);
        si = si + 1;
    }
}

def emit_match_pattern_sub(
    g: cfg_builder,
    p: pattern,
    ctx: match_pat_ctx,
    next_arm: basicblock,
    ploc: cloc
) -> bool {
    allow = ctx.allow_irrefutable;
    ctx.allow_irrefutable = True;
    ok = emit_match_pattern(g, p, ctx, next_arm, ploc);
    ctx.allow_irrefutable = allow;
    return ok;
}

def emit_match_pattern_value(
    g: cfg_builder,
    mv: MatchValue,
    ctx: match_pat_ctx,
    next_arm: basicblock,
    ploc: cloc
) -> bool {
    visit_expr(g, mv.value);
    if codegen_busy(g) {
        return False;
    }
    oparg = compare_filter_oparg(CMP_EQ);
    g.emit_op(OP_COMPARE_OP, oparg, ploc);
    match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
    return True;
}

def emit_match_pattern_singleton(
    g: cfg_builder,
    ms: MatchSingleton,
    ctx: match_pat_ctx,
    next_arm: basicblock,
    ploc: cloc
) -> bool {
    if ms.value is None {
        match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_NOT_NONE, ploc);
        return True;
    }
    idx = g.u.add_const(ms.value);
    g.emit_op(OP_LOAD_CONST, idx, ploc);
    g.emit_op(OP_IS_OP, 0, ploc);
    match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
    return True;
}

def emit_match_pattern_as(
    g: cfg_builder,
    ma: MatchAs,
    ctx: match_pat_ctx,
    next_arm: basicblock,
    ploc: cloc
) -> bool {
    if ma.pattern is None {
        if not ctx.allow_irrefutable {
            if ma.name is not None {
                codegen_fail(
                    g,
                    "SyntaxError",
                    "name capture makes remaining patterns unreachable"
                );
                return False;
            }
            codegen_fail(
                g, "SyntaxError", "wildcard makes remaining patterns unreachable"
            );
            return False;
        }
        return match_pattern_helper_store_name(g, ma.name, ctx, ploc);
    }
    ctx.on_top = ctx.on_top + 1;
    g.emit_op(OP_COPY, 1, ploc);
    if not emit_match_pattern(g, ma.pattern, ctx, next_arm, ploc) {
        return False;
    }
    ctx.on_top = ctx.on_top - 1;
    return match_pattern_helper_store_name(g, ma.name, ctx, ploc);
}

def match_sequence_all_captures(patterns: list[pattern]) -> bool {
    if len(patterns) == 0 {
        return False;
    }
    pi = 0;
    while pi < len(patterns) {
        p = match_pattern_unwrap_or(patterns[pi]);
        if not isinstance(p, MatchAs) {
            return False;
        }
        ma = p as MatchAs;
        if ma.pattern is not None or ma.name is None or ma.name == "_" {
            return False;
        }
        pi = pi + 1;
    }
    return True;
}

def match_emit_sequence_capture_stores(
    g: cfg_builder, patterns: list[pattern], ploc: cloc
) {
    n = len(patterns);
    if n == 2 {
        na = codegen_mangle(g, (match_pattern_unwrap_or(patterns[0]) as MatchAs).name);
        nb = codegen_mangle(g, (match_pattern_unwrap_or(patterns[1]) as MatchAs).name);
        fa = fast_local_index(g, na);
        fb = fast_local_index(g, nb);
        if fa >= 0 and fb >= 0 {
            pair = fa * 16 + fb;
            g.emit_op(OP_STORE_FAST_STORE_FAST, pair, ploc);
            return;
        }
    }
    pi = n - 1;
    while pi >= 0 {
        ma = match_pattern_unwrap_or(patterns[pi]) as MatchAs;
        emit_name_store(g, ma.name, ploc);
        pi = pi - 1;
    }
}

def match_star_capture_name(patterns: list[pattern], idx: int, star_idx: int) -> str | None {
    if idx == star_idx {
        return (patterns[idx] as MatchStar).name;
    }
    return (match_pattern_unwrap_or(patterns[idx]) as MatchAs).name;
}

def match_seq_star_all_captures(patterns: list[pattern], star_idx: int) -> bool {
    if len(patterns) == 0 {
        return False;
    }
    pi = 0;
    while pi < len(patterns) {
        if pi == star_idx {
            mst = patterns[pi] as MatchStar;
            if mst.name is None or mst.name == "_" {
                return False;
            }
        } else {
            p = match_pattern_unwrap_or(patterns[pi]);
            if not isinstance(p, MatchAs) {
                return False;
            }
            ma = p as MatchAs;
            if ma.pattern is not None or ma.name is None or ma.name == "_" {
                return False;
            }
        }
        pi = pi + 1;
    }
    return True;
}

def match_emit_star_capture_stores(
    g: cfg_builder, patterns: list[pattern], star_idx: int, ploc: cloc
) {
    n = len(patterns);
    if n == 2 {
        na = codegen_mangle(g, match_star_capture_name(patterns, 0, star_idx));
        nb = codegen_mangle(g, match_star_capture_name(patterns, 1, star_idx));
        fa = fast_local_index(g, na);
        fb = fast_local_index(g, nb);
        if fa >= 0 and fb >= 0 {
            g.emit_op(OP_STORE_FAST_STORE_FAST, fa * 16 + fb, ploc);
            return;
        }
    }
    # UNPACK_EX leaves element[0] on top, so bind forward; opt_superinstructions
    # fuses the first adjacent STORE_FAST pair (matching CPython's left-to-right
    # STORE_FAST_STORE_FAST peephole, e.g. `[a,*mid,b]` -> (a,mid) + b).
    pi = 0;
    while pi < n {
        emit_name_store(g, match_star_capture_name(patterns, pi, star_idx), ploc);
        pi = pi + 1;
    }
}

# CPython pattern_helper_sequence_subscr: used when the star element is a bare
# wildcard (`*_`). The tail is dropped, so the fixed elements are read off the
# subject by index (nonnegative before the star, len-relative after it) rather
# than unpacked. The subject stays on the stack and is popped at the end.
def emit_match_sequence_subscr(
    g: cfg_builder,
    patterns: list[pattern],
    star_idx: int,
    next_arm: basicblock,
    ctx: match_pat_ctx,
    ploc: cloc
) -> bool {
    size = len(patterns);
    pi = 0;
    while pi < size {
        if pi == star_idx {
            pi = pi + 1;
            continue;
        }
        pat = patterns[pi];
        if match_pattern_wildcard(pat) {
            pi = pi + 1;
            continue;
        }
        g.emit_op(OP_COPY, 1, ploc);
        if pi < star_idx {
            idx_const = g.u.add_const(PyInt(t="int", val=pi));
            g.emit_op(OP_LOAD_CONST, idx_const, ploc);
        } else {
            g.emit_op(OP_GET_LEN, 0, ploc);
            neg_const = g.u.add_const(PyInt(t="int", val=size - pi));
            g.emit_op(OP_LOAD_CONST, neg_const, ploc);
            g.emit_op(OP_BINARY_OP, NB_SUBTRACT, ploc);
        }
        g.emit_op(OP_BINARY_OP, NB_SUBSCR, ploc);
        # The element value sits on top with the subject preserved below. A plain
        # capture stores it immediately (CPython emits a bare STORE_FAST here, no
        # rotate); nested sub-patterns fall back to the general on-stack path.
        up = match_pattern_unwrap_or(pat);
        if isinstance(up, MatchAs) and (up as MatchAs).pattern is None {
            emit_name_store(g, (up as MatchAs).name, ploc);
        } else {
            ctx.on_top = ctx.on_top + 1;
            if not emit_match_pattern_sub(g, pat, ctx, next_arm, ploc) {
                return False;
            }
            ctx.on_top = ctx.on_top - 1;
        }
        pi = pi + 1;
    }
    ctx.on_top = ctx.on_top - 1;
    g.emit_op(OP_POP_TOP, 0, ploc);
    return True;
}

def emit_match_pattern_sequence(
    g: cfg_builder, ms: MatchSequence, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool {
    patterns = ms.patterns;
    size = len(patterns);
    star = -1;
    star_wild = 0;
    only_wildcard = 1;
    pi = 0;
    while pi < size {
        pat = patterns[pi];
        if isinstance(pat, MatchStar) {
            if star >= 0 {
                codegen_fail(
                    g,
                    "SyntaxError",
                    "multiple starred names in sequence pattern"
                );
                return False;
            }
            star = pi;
            mst = pat as MatchStar;
            if mst.name is None {
                star_wild = 1;
                only_wildcard = only_wildcard and 1;
            } else {
                only_wildcard = 0;
            }
            pi = pi + 1;
            continue;
        }
        if match_pattern_wildcard(pat) {
            only_wildcard = only_wildcard and 1;
        } else {
            only_wildcard = 0;
        }
        pi = pi + 1;
    }
    if star >= 0 {
        n_before = star;
        n_after = size - star - 1;
        n_fixed = n_before + n_after;
        ctx.on_top = ctx.on_top + 1;
        g.emit_op(OP_MATCH_SEQUENCE, 0, ploc);
        match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
        # CPython only checks the length when there is at least one fixed
        # element around the star; `[*rest]` skips the length guard entirely.
        if n_fixed > 0 {
            g.emit_op(OP_GET_LEN, 0, ploc);
            nfx_idx = g.u.add_const(PyInt(t="int", val=n_fixed));
            g.emit_op(OP_LOAD_CONST, nfx_idx, ploc);
            g.emit_op(OP_COMPARE_OP, compare_oparg(CMP_GE), ploc);
            match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
        }
        if only_wildcard {
            ctx.on_top = ctx.on_top - 1;
            g.emit_op(OP_POP_TOP, 0, ploc);
            return True;
        }
        if star_wild {
            # `[a, *_]`: the star swallows the tail without binding, so CPython
            # subscripts the fixed elements off the subject instead of unpacking.
            return emit_match_sequence_subscr(g, patterns, star, next_arm, ctx, ploc);
        }
        # Capture star: split the subject with UNPACK_EX (n_before | n_after<<8).
        ctx.on_top = ctx.on_top - 1;
        g.emit_op(OP_UNPACK_EX, n_before + n_after * 256, ploc);
        if match_seq_star_all_captures(patterns, star) {
            match_emit_star_capture_stores(g, patterns, star, ploc);
            return True;
        }
        ctx.on_top = ctx.on_top + size;
        pi = 0;
        while pi < size {
            ctx.on_top = ctx.on_top - 1;
            if pi == star {
                mst2 = patterns[pi] as MatchStar;
                if not match_pattern_helper_store_name(g, mst2.name, ctx, ploc) {
                    return False;
                }
            } else {
                if not emit_match_pattern_sub(g, patterns[pi], ctx, next_arm, ploc) {
                    return False;
                }
            }
            pi = pi + 1;
        }
        return True;
    }
    ctx.on_top = ctx.on_top + 1;
    g.emit_op(OP_MATCH_SEQUENCE, 0, ploc);
    match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
    g.emit_op(OP_GET_LEN, 0, ploc);
    # CPython interns the length const (ADDOP_LOAD_CONST_NEW) and the optimizer
    # folds it to LOAD_SMALL_INT while keeping it in the pool, so later consts
    # (e.g. a following class pattern's attr-name tuple) keep CPython's indices.
    seq_sz_idx = g.u.add_const(PyInt(t="int", val=size));
    g.emit_op(OP_LOAD_CONST, seq_sz_idx, ploc);
    oparg = compare_oparg(CMP_EQ);
    g.emit_op(OP_COMPARE_OP, oparg, ploc);
    match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
    ctx.on_top = ctx.on_top - 1;
    if only_wildcard {
        g.emit_op(OP_POP_TOP, 0, ploc);
        return True;
    }
    if match_sequence_all_captures(patterns) {
        g.emit_op(OP_UNPACK_SEQUENCE, size, ploc);
        match_emit_sequence_capture_stores(g, patterns, ploc);
        return True;
    }
    g.emit_op(OP_UNPACK_SEQUENCE, size, ploc);
    ctx.on_top = ctx.on_top + size;
    pi = 0;
    while pi < size {
        ctx.on_top = ctx.on_top - 1;
        if not emit_match_pattern_sub(g, patterns[pi], ctx, next_arm, ploc) {
            return False;
        }
        pi = pi + 1;
    }
    return True;
}

# CPython codegen_pattern_class. Emits the class-check, then unpacks the
# attribute tuple and matches sub-patterns. Positional patterns first, then
# keyword patterns (attr names carried in a const tuple for MATCH_CLASS).
def emit_match_pattern_class(
    g: cfg_builder, mc: MatchClass, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool {
    cls_patterns: list[pattern] = mc.patterns if mc.patterns is not None else [];
    kwd_attrs: list[str] = mc.kwd_attrs if mc.kwd_attrs is not None else [];
    kwd_patterns: list[pattern] = mc.kwd_patterns if mc.kwd_patterns is not None else [];
    nargs = len(cls_patterns);
    nattrs = len(kwd_attrs);
    if nattrs != len(kwd_patterns) {
        codegen_fail(g, "SyntaxError", "kwd_attrs / kwd_patterns length mismatch in class pattern");
        return False;
    }
    ai = 0;
    while ai < nattrs {
        aj = ai + 1;
        while aj < nattrs {
            if kwd_attrs[ai] == kwd_attrs[aj] {
                codegen_fail(
                    g, "SyntaxError", "attribute name repeated in class pattern: " + kwd_attrs[ai]
                );
                return False;
            }
            aj = aj + 1;
        }
        ai = ai + 1;
    }
    visit_expr(g, mc.cls);
    if codegen_busy(g) {
        return False;
    }
    attr_items: list[PyObj] = [];
    ki = 0;
    while ki < nattrs {
        attr_items.append(PyStr(t="str", val=kwd_attrs[ki]));
        ki = ki + 1;
    }
    names_idx = g.u.add_const(PyTuple(t="tuple", items=attr_items));
    g.emit_op(OP_LOAD_CONST, names_idx, ploc);
    g.emit_op(OP_MATCH_CLASS, nargs, ploc);
    g.emit_op(OP_COPY, 1, ploc);
    ctx.on_top = ctx.on_top + 1;
    match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_NONE, ploc);
    total = nargs + nattrs;
    g.emit_op(OP_UNPACK_SEQUENCE, total, ploc);
    ctx.on_top = ctx.on_top + total - 1;
    i = 0;
    while i < total {
        ctx.on_top = ctx.on_top - 1;
        sp: pattern = cls_patterns[i] if i < nargs else kwd_patterns[i - nargs];
        if match_pattern_wildcard(sp) {
            g.emit_op(OP_POP_TOP, 0, ploc);
        } elif not emit_match_pattern_sub(g, sp, ctx, next_arm, ploc) {
            return False;
        }
        i = i + 1;
    }
    return True;
}

# CPython codegen_pattern_mapping. MATCH_MAPPING + length check, MATCH_KEYS
# against a key tuple, then sub-patterns on the values; **rest binds remaining
# items via the CPython dict-copy/delete idiom.
def emit_match_pattern_mapping(
    g: cfg_builder, mm: MatchMapping, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool {
    keys: list[expr] = mm.keys if mm.keys is not None else [];
    patterns: list[pattern] = mm.patterns if mm.patterns is not None else [];
    size = len(keys);
    if size != len(patterns) {
        codegen_fail(g, "SyntaxError", "keys / patterns length mismatch in mapping pattern");
        return False;
    }
    ctx.on_top = ctx.on_top + 1;
    g.emit_op(OP_MATCH_MAPPING, 0, ploc);
    match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
    if size == 0 and mm.rest is None {
        ctx.on_top = ctx.on_top - 1;
        g.emit_op(OP_POP_TOP, 0, ploc);
        return True;
    }
    if size > 0 {
        g.emit_op(OP_GET_LEN, 0, ploc);
        # CPython emits LOAD_CONST(size) (ADDOP_LOAD_CONST_NEW); rewrite_small_ints
        # folds it to LOAD_SMALL_INT but keeps the const in the pool, so later
        # consts (the key tuple) keep CPython's indices.
        sz_idx = g.u.add_const(PyInt(t="int", val=size));
        g.emit_op(OP_LOAD_CONST, sz_idx, ploc);
        g.emit_op(OP_COMPARE_OP, compare_oparg(CMP_GE), ploc);
        match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_FALSE, ploc);
    }
    all_const = True;
    seen: list[PyObj] = [];
    ki = 0;
    while ki < size {
        key = keys[ki];
        if isinstance(key, Constant) {
            kv = (key as Constant).value;
            hk = kv.tp_hashkey();
            si = 0;
            while si < len(seen) {
                if seen[si].tp_hashkey() == hk {
                    codegen_fail(g, "SyntaxError", "mapping pattern checks duplicate key");
                    return False;
                }
                si = si + 1;
            }
            seen.append(kv);
        } elif isinstance(key, Attribute) {
            all_const = False;
        } else {
            codegen_fail(
                g, "SyntaxError", "mapping pattern keys may only match literals and attribute lookups"
            );
            return False;
        }
        ki = ki + 1;
    }
    if all_const {
        key_items: list[PyObj] = [];
        ki = 0;
        while ki < size {
            key_items.append((keys[ki] as Constant).value);
            ki = ki + 1;
        }
        keys_idx = g.u.add_const(PyTuple(t="tuple", items=key_items));
        g.emit_op(OP_LOAD_CONST, keys_idx, ploc);
    } else {
        ki = 0;
        while ki < size {
            visit_expr(g, keys[ki]);
            if codegen_busy(g) {
                return False;
            }
            ki = ki + 1;
        }
        g.emit_op(OP_BUILD_TUPLE, size, ploc);
    }
    g.emit_op(OP_MATCH_KEYS, 0, ploc);
    ctx.on_top = ctx.on_top + 2;
    g.emit_op(OP_COPY, 1, ploc);
    match_jump_to_fail(g, ctx, next_arm, OP_POP_JUMP_IF_NONE, ploc);
    g.emit_op(OP_UNPACK_SEQUENCE, size, ploc);
    ctx.on_top = ctx.on_top + size - 1;
    pi = 0;
    while pi < size {
        ctx.on_top = ctx.on_top - 1;
        if not emit_match_pattern_sub(g, patterns[pi], ctx, next_arm, ploc) {
            return False;
        }
        pi = pi + 1;
    }
    ctx.on_top = ctx.on_top - 2;
    if mm.rest is not None {
        g.emit_op(OP_BUILD_MAP, 0, ploc);
        g.emit_op(OP_SWAP, 3, ploc);
        g.emit_op(OP_DICT_UPDATE, 2, ploc);
        g.emit_op(OP_UNPACK_SEQUENCE, size, ploc);
        sz = size;
        while sz > 0 {
            g.emit_op(OP_COPY, 1 + sz, ploc);
            g.emit_op(OP_SWAP, 2, ploc);
            g.emit_op(OP_DELETE_SUBSCR, 0, ploc);
            sz = sz - 1;
        }
        return match_pattern_helper_store_name(g, mm.rest, ctx, ploc);
    }
    g.emit_op(OP_POP_TOP, 0, ploc);
    g.emit_op(OP_POP_TOP, 0, ploc);
    return True;
}

# Lower a multi-alternative MatchOr (CPython codegen_pattern_or). Each alternative
# copies the subject, tests it, and on success jumps to a shared `end`. On failure
# it falls to the next alternative (subject preserved underneath); the last
# alternative's failure pops the surviving subject and jumps to next_arm. `end`
# and the per-alternative entries are deferred blocks so they lay out after the
# preceding alternative bodies (allocation order != layout order). Captures inside
# alternatives (name permutation across arms) need a sequence/display subject to
# oracle-verify and are gated off until that slice lands.
def emit_match_pattern_or(
    g: cfg_builder,
    mo: MatchOr,
    ctx: match_pat_ctx,
    next_arm: basicblock,
    ploc: cloc
) -> bool {
    end = g.new_deferred_block();
    end.exit_inline_ok = True;
    size = len(mo.patterns);
    outer_allow = ctx.allow_irrefutable;
    i = 0;
    while i < size {
        alt = mo.patterns[i];
        is_last = i == size - 1;
        alt_fail = g.new_deferred_block();
        g.emit_op(OP_COPY, 1, ploc);
        alt_ctx = match_pat_ctx(
            stores=[],
            on_top=0,
            cleanup_blocks=[],
            max_cleanup=0,
            allow_irrefutable=is_last and outer_allow
        );
        if not emit_match_pattern(g, alt, alt_ctx, alt_fail, ploc) {
            return False;
        }
        if codegen_busy(g) {
            return False;
        }
        if len(alt_ctx.stores) != 0 {
            codegen_fail(
                g, "NotImplementedError", "capture inside match-or alternative"
            );
            return False;
        }
        g.emit_jump(OP_JUMP_FORWARD, end.id, ploc);
        g.use(alt_fail);
        if is_last {
            # Total failure: pop the subject copy that survived every alternative,
            # then continue to the arm's fail target.
            g.emit_op(OP_POP_TOP, 0, ploc);
            g.emit_jump(OP_JUMP_FORWARD, next_arm.id, ploc);
        }
        i = i + 1;
    }
    g.use(end);
    g.emit_op(OP_POP_TOP, 0, ploc);
    return True;
}

def emit_match_pattern(
    g: cfg_builder,
    p: pattern,
    ctx: match_pat_ctx,
    next_arm: basicblock,
    ploc: cloc
) -> bool {
    if isinstance(p, MatchOr) {
        mo = p as MatchOr;
        if len(mo.patterns) > 1 {
            return emit_match_pattern_or(g, mo, ctx, next_arm, ploc);
        }
    }
    p = match_pattern_unwrap_or(p);
    if isinstance(p, MatchValue) {
        return emit_match_pattern_value(g, p as MatchValue, ctx, next_arm, ploc);
    }
    if isinstance(p, MatchSingleton) {
        return emit_match_pattern_singleton(g, p as MatchSingleton, ctx, next_arm, ploc);
    }
    if isinstance(p, MatchAs) {
        return emit_match_pattern_as(g, p as MatchAs, ctx, next_arm, ploc);
    }
    if isinstance(p, MatchSequence) {
        return emit_match_pattern_sequence(g, p as MatchSequence, ctx, next_arm, ploc);
    }
    if isinstance(p, MatchClass) {
        return emit_match_pattern_class(g, p as MatchClass, ctx, next_arm, ploc);
    }
    if isinstance(p, MatchMapping) {
        return emit_match_pattern_mapping(g, p as MatchMapping, ctx, next_arm, ploc);
    }
    codegen_fail(g, "NotImplementedError", "unsupported match pattern");
    return False;
}

# Lower match (CPython codegen_match_inner shape; slice 1–3 patterns + guards).
def visit_match(
    g: cfg_builder,
    m: Match,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None
) -> stmt_cont {
    mloc = stmt_loc(m);
    if len(m.cases) == 0 {
        return stmt_cont(loc=mloc);
    }
    match_emit_subject(g, m);
    if codegen_busy(g) {
        return stmt_cont(loc=mloc);
    }
    has_default = 0;
    if len(m.cases) > 1 {
        last_pat = m.cases[len(m.cases) - 1].pattern;
        if match_pattern_wildcard(last_pat) {
            has_default = 1;
        }
    }
    join_blk = tail_join;
    owns_join = False;
    if more_code_follows {
        if join_blk is None {
            join_blk = g.new_deferred_block();
            join_blk.exit_inline_ok = True;
            owns_join = True;
        }
    }
    match_end = join_blk;
    owns_match_end = False;
    if match_end is None {
        match_end = g.new_deferred_block();
        match_end.exit_inline_ok = True;
        owns_match_end = True;
    }
    body_follows = more_code_follows;
    if not body_follows and tail is not None and tail_idx < len(tail) {
        body_follows = True;
    }
    loop_end = len(m.cases) - has_default;
    terminated = False;
    ci = 0;
    while ci < loop_end {
        arm = m.cases[ci];
        ploc = match_pattern_loc(arm.pattern);
        start = match_begin_case(g, match_arm_cleanup_levels(arm.pattern));
        ctx = start.ctx;
        next_arm = start.next_arm;
        if ci != loop_end - 1 {
            g.emit_op(OP_COPY, 1, ploc);
        }
        ctx.allow_irrefutable = arm.guard is not None or ci == loop_end - 1;
        opt_lo = len(g.cur.instrs);
        if not emit_match_pattern(g, arm.pattern, ctx, next_arm, ploc) {
            return stmt_cont(loc=mloc);
        }
        if codegen_busy(g) {
            return stmt_cont(loc=mloc);
        }
        match_emit_case_stores(g, ctx, ploc);
        # Fold the arm's naive rotate (SWAP) + separate stores into CPython's
        # optimized shape (swaptimize + static swaps + STORE_FAST_STORE_FAST).
        optimize_swap_range(g.cur, opt_lo);
        if arm.guard is not None {
            gloc = expr_loc(arm.guard);
            visit_test_expr(g, arm.guard, gloc);
            if codegen_busy(g) {
                return stmt_cont(loc=mloc);
            }
            g.emit_jump(OP_POP_JUMP_IF_FALSE, next_arm.id, gloc);
        }
        if ci != loop_end - 1 {
            g.emit_op(OP_POP_TOP, 0, ploc);
        }
        body_cont = visit_stmts(
            g, arm.body, 0, body_follows, tail, tail_idx, join_blk
        );
        if codegen_busy(g) {
            return stmt_cont(loc=mloc);
        }
        if body_cont.terminated {
            terminated = True;
        } else {
            g.emit_jump(OP_JUMP_FORWARD, match_end.id, ploc);
        }
        match_emit_reset_fail_pop(g, ctx, next_arm, ploc);
        ci = ci + 1;
    }
    if has_default {
        arm = m.cases[len(m.cases) - 1];
        ploc = match_pattern_loc(arm.pattern);
        if len(m.cases) == 1 {
            g.emit_op(OP_POP_TOP, 0, ploc);
        } else {
            g.emit_op(OP_NOP, 0, ploc);
        }
        if arm.guard is not None {
            gloc = expr_loc(arm.guard);
            visit_test_expr(g, arm.guard, gloc);
            if codegen_busy(g) {
                return stmt_cont(loc=mloc);
            }
            g.emit_jump(OP_POP_JUMP_IF_FALSE, match_end.id, gloc);
        }
        body_cont = visit_stmts(
            g, arm.body, 0, body_follows, tail, tail_idx, join_blk
        );
        if codegen_busy(g) {
            return stmt_cont(loc=mloc);
        }
        if body_cont.terminated {
            terminated = True;
        }
    }
    if owns_match_end {
        g.use(match_end);
        if not more_code_follows and not terminated {
            emit_module_return(g, mloc);
            terminated = True;
        }
    }
    if owns_join and join_blk is not None {
        g.use(join_blk);
        tail_more = exec_tail_emits_code(tail, tail_idx);
        tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more);
        return stmt_cont(
            loc=tail_cont.loc,
            next_si=len(tail),
            terminated=terminated or tail_cont.terminated
        );
    }
    return stmt_cont(loc=mloc, terminated=terminated);
}

# Lower an if/while test (CPython bool context): single Compare uses COMPARE_OP
# with bool oparg; other expressions use TO_BOOL after visit_expr.
# visit_test_expr return kinds. NORMAL leaves a bool on the stack, consumed by a
# POP_JUMP_IF_FALSE. IS_NONE / IS_NOT_NONE leave the bare operand on the stack;
# the caller must consume it with POP_JUMP_IF_NOT_NONE / POP_JUMP_IF_NONE (the
# CPython `x is None` jump peephole), via emit_branch_if_test_false.
glob TEST_NORMAL: int = 0;
glob TEST_IS_NONE: int = 1;
glob TEST_IS_NOT_NONE: int = 2;

def visit_test_expr(
    g: cfg_builder, e: expr, test_loc: cloc, allow_none_peephole: bool = False
) -> int {
    if isinstance(e, Compare) {
        c = e as Compare;
        if len(c.ops) == 1 {
            cloc_cmp = nloc(c.lineno, c.end_lineno, c.col_offset, c.end_col_offset);
            if is_none_identity_test(c.ops[0], c.comparators[0]) {
                if allow_none_peephole {
                    # Emit only the left operand; the branch site folds the
                    # identity + jump into POP_JUMP_IF_NONE / _NOT_NONE.
                    visit_expr(g, c.left);
                    # CPython compiles the None comparand's LOAD_CONST (adding
                    # None to co_consts) before the peephole removes the load, so
                    # None still occupies its const-pool slot. Register it here to
                    # match co_consts ordering (and suppress a spurious dead
                    # small-int slot at index 0).
                    g.u.add_const(py_none());
                    if isinstance(c.ops[0], Is) {
                        return TEST_IS_NONE;
                    }
                    return TEST_IS_NOT_NONE;
                }
                codegen_fail(
                    g, "NotImplementedError", "is-None jump peephole not supported"
                );
                return TEST_NORMAL;
            }
            visit_expr(g, c.left);
            visit_expr(g, c.comparators[0]);
            if not emit_cmp_link(g, c.ops[0], cloc_cmp, True) {
                codegen_fail(
                    g, "NotImplementedError", "unsupported comparison operator"
                );
                return TEST_NORMAL;
            }
            return TEST_NORMAL;
        }
    }
    visit_expr(g, e);
    g.emit_op(OP_TO_BOOL, 0, test_loc);
    return TEST_NORMAL;
}

# Emit the conditional branch taken when a visit_test_expr result is FALSE. For
# the None-identity kinds this is the CPython jump peephole:
#   `x is None`     -> POP_JUMP_IF_NOT_NONE  (branch away when x is NOT None)
#   `x is not None` -> POP_JUMP_IF_NONE      (branch away when x IS None)
def emit_branch_if_test_false(
    g: cfg_builder, kind: int, target_id: int, loc: cloc
) {
    if kind == TEST_IS_NONE {
        g.emit_jump(OP_POP_JUMP_IF_NOT_NONE, target_id, loc);
        return;
    }
    if kind == TEST_IS_NOT_NONE {
        g.emit_jump(OP_POP_JUMP_IF_NONE, target_id, loc);
        return;
    }
    g.emit_jump(OP_POP_JUMP_IF_FALSE, target_id, loc);
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
    kind = visit_test_expr(g, i.test, test_loc, True);
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
                emit_branch_if_test_false(g, kind, false_blk.id, test_loc);
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
            # tail_more is False but more_code_follows is True: the real
            # continuation is in the CALLER's own statement list, not in `tail`
            # (which is empty/exhausted here). This branch is only reached from
            # visit_stmts-style callers -- the compile_fn_cfg/module driver
            # always has more_code_follows == tail_more, so it never lands here.
            # Converge both branches at `join` and return next_si=-1 so the
            # caller emits its following statements. Using emit_tail_and_finish
            # here would append a module return AND return next_si=len(tail)=0,
            # resetting the caller's index -> infinite loop on
            # `if c: return; if d: ... else: ...; <more>`.
            join = g.new_block();
            emit_branch_if_test_false(g, kind, false_blk.id, test_loc);
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
            return stmt_cont(loc=iloc);
        }
        join = tail_join;
        owns_tail = False;
        if join is None {
            join = g.new_block();
            owns_tail = True;
        }
        emit_branch_if_test_false(g, kind, join.id, test_loc);
        body_cont = visit_stmts(g, i.body, 0, False, tail, tail_idx, join);
        if codegen_busy(g) {
            return stmt_cont(loc=body_cont.loc);
        }
        if owns_tail {
            g.use(join);
            if tail_more {
                tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more);
                return stmt_cont(
                    loc=tail_cont.loc,
                    next_si=len(tail),
                    terminated=tail_cont.terminated
                );
            }
            # No code in `tail` to duplicate: the real continuation lives in the
            # caller's own statement list (e.g. visit_stmts over a loop body).
            # Fall through at `join` and let the caller emit its following
            # statements. Returning next_si=len(tail)=0 here would reset the
            # caller's index to 0 -> infinite loop (hangs `while: if c: break; more`).
            return stmt_cont(loc=body_cont.loc);
        }
        return stmt_cont(loc=body_cont.loc);
    }
    # more_code_follows == False: nothing follows this if in the current
    # statement list. Two sub-cases, distinguished by `tail`:
    #
    # (a) tail is None -- a loop body (or other back-edge context): the
    #     continuation is the loop's JUMP_BACKWARD, not a return. Fall through and
    #     let the enclosing loop emit the back-edge; never synthesize a return.
    #
    # (b) tail is not None -- the function/module/compound tail: CPython
    #     DUPLICATES the implicit `return None` into each falling-through branch
    #     (verified: `if a in xs: r=1` emits a return after the true body AND at
    #     the false label). Preserve that duplication, but skip the return after a
    #     branch that already terminates (return/raise/continue) -- emitting one
    #     there is dead code after a terminator ("Invalid CFG").
    if tail is None {
        emit_branch_if_test_false(g, kind, false_blk.id, test_loc);
        body_cont = visit_stmts(g, i.body);
        if codegen_busy(g) {
            return stmt_cont(loc=body_cont.loc);
        }
        if has_else {
            join = None;
            if not body_cont.terminated {
                join = g.new_block();
                g.emit_jump(OP_JUMP_FORWARD, join.id, iloc);
            }
            g.use(false_blk);
            else_cont = visit_stmts(g, i.orelse);
            if codegen_busy(g) {
                return stmt_cont(loc=else_cont.loc);
            }
            if join is not None {
                g.use(join);
                return stmt_cont(loc=iloc, terminated=False);
            }
            return stmt_cont(loc=iloc, terminated=else_cont.terminated);
        }
        g.use(false_blk);
        return stmt_cont(loc=iloc, terminated=False);
    }
    emit_branch_if_test_false(g, kind, false_blk.id, test_loc);
    body_cont = visit_stmts(g, i.body);
    if codegen_busy(g) {
        return stmt_cont(loc=body_cont.loc);
    }
    if not body_cont.terminated {
        emit_module_return(g, body_cont.loc);
    }
    g.use(false_blk);
    if has_else {
        else_cont = visit_stmts(g, i.orelse);
        if codegen_busy(g) {
            return stmt_cont(loc=else_cont.loc);
        }
        if not else_cont.terminated {
            emit_module_return(g, else_cont.loc);
        }
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
    kind = visit_test_expr(g, w.test, test_loc, True);
    if codegen_busy(g) {
        return stmt_cont(loc=wloc);
    }
    has_break = loop_body_has_break(w.body);
    if more_code_follows {
        exit_blk = g.new_block();
        emit_branch_if_test_false(g, kind, exit_blk.id, test_loc);
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
        return stmt_cont(
            loc=tail_cont.loc, next_si=len(tail), terminated=tail_cont.terminated
        );
    }
    if len(g.loop_stack) > 0 {
        after_body = g.new_block();
        emit_branch_if_test_false(g, kind, after_body.id, test_loc);
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
    emit_branch_if_test_false(g, kind, 0, test_loc);
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
        return stmt_cont(
            loc=tail_cont.loc, next_si=len(tail), terminated=tail_cont.terminated
        );
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

def visit_async_for(
    g: cfg_builder, af: AsyncFor, more_code_follows: bool, tail: list[stmt], tail_idx: int
) -> stmt_cont {
    floc = nloc(af.lineno, af.end_lineno, af.col_offset, af.end_col_offset);
    iter_loc = expr_loc(af.iter);
    visit_expr(g, af.iter);
    if codegen_busy(g) {
        return stmt_cont(loc=floc);
    }
    g.emit_op(OP_GET_AITER, 0, iter_loc);
    loop_hdr = g.new_block();
    has_break = loop_body_has_break(af.body);
    als = emit_anext_send_loop_header(g, loop_hdr, 3, iter_loc);
    if more_code_follows {
        store_blk = g.new_block();
        g.use(store_blk);
        g.emit_op(OP_NOT_TAKEN, 0, iter_loc);
        break_tgt = loop_hdr;
        if has_break {
            break_tgt = g.new_block();
        }
        g.push_loop(loop_hdr, break_tgt, has_break);
        store = visit_store_target_tos(g, af.target);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=store.loc);
        }
        body_cont = visit_stmts(g, af.body);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=body_cont.loc);
        }
        if not body_cont.terminated {
            g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, body_cont.loc);
        }
        g.pop_loop();
        (cleanup_throw, cleanup_jump) = emit_anext_send_loop_footer(g, als, iter_loc);
        end_async_handler = g.new_block();
        emit_anext_send_except_regions(
            g, als, store_blk, cleanup_throw, cleanup_jump, end_async_handler
        );
        g.u.except_regions.append(
            except_region(
                start_block=store_blk.id,
                end_block=cleanup_throw.id,
                handler_block=-1,
                stack_depth=2,
                preserve_lasti=True
            )
        );
        g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
        tail_more = exec_tail_emits_code(tail, tail_idx);
        after = g.new_block();
        if has_break {
            g.use(break_tgt);
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
        g.use(end_async_handler);
        g.emit_jump(OP_END_ASYNC_FOR, als.end_send_blk.id, iter_loc);
        g.async_for_end_async_block = end_async_handler.id;
        g.u.except_regions.append(
            except_region(
                start_block=end_async_handler.id,
                end_block=-1,
                handler_block=-1,
                stack_depth=2,
                preserve_lasti=True
            )
        );
        g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
        g.use(after);
        if len(af.orelse) > 0 {
            else_cont = visit_stmts(g, af.orelse);
            if codegen_busy(g) {
                return stmt_cont(loc=else_cont.loc);
            }
        }
        if has_break and not tail_more {
            return stmt_cont(loc=floc, next_si=len(tail), terminated=True);
        }
        tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more);
        return stmt_cont(
            loc=tail_cont.loc,
            next_si=len(tail),
            terminated=tail_cont.terminated
        );
    }
    needs_break_stub = has_break;
    store_blk = g.new_block();
    g.use(store_blk);
    g.emit_op(OP_NOT_TAKEN, 0, iter_loc);
    break_tgt = loop_hdr;
    if needs_break_stub {
        break_tgt = g.new_block();
    }
    g.push_loop(loop_hdr, break_tgt, needs_break_stub);
    store = visit_store_target_tos(g, af.target);
    if codegen_busy(g) {
        g.pop_loop();
        return stmt_cont(loc=store.loc);
    }
    body_cont = visit_stmts(g, af.body);
    if codegen_busy(g) {
        g.pop_loop();
        return stmt_cont(loc=body_cont.loc);
    }
    if not body_cont.terminated {
        g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, body_cont.loc);
    }
    g.pop_loop();
    (cleanup_throw, cleanup_jump) = emit_anext_send_loop_footer(g, als, iter_loc);
    end_async_handler = g.new_block();
    emit_anext_send_except_regions(
        g, als, store_blk, cleanup_throw, cleanup_jump, end_async_handler
    );
    g.u.except_regions.append(
        except_region(
            start_block=store_blk.id,
            end_block=cleanup_throw.id,
            handler_block=-1,
            stack_depth=2,
            preserve_lasti=True
        )
    );
    g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    if needs_break_stub {
        g.use(break_tgt);
        g.emit_op(OP_POP_TOP, 0, iter_loc);
        emit_module_return(g, iter_loc);
    }
    after = g.new_block();
    g.use(end_async_handler);
    g.emit_jump(OP_END_ASYNC_FOR, als.end_send_blk.id, iter_loc);
    g.async_for_end_async_block = end_async_handler.id;
    g.u.except_regions.append(
        except_region(
            start_block=end_async_handler.id,
            end_block=-1,
            handler_block=-1,
            stack_depth=2,
            preserve_lasti=True
        )
    );
    g.u.pending_pep479_regions.append(len(g.u.except_regions) - 1);
    g.use(after);
    if len(af.orelse) > 0 {
        else_cont = visit_stmts(g, af.orelse);
        if codegen_busy(g) {
            return stmt_cont(loc=else_cont.loc);
        }
        emit_module_return(g, else_cont.loc);
    } else {
        emit_module_return(g, iter_loc);
    }
    return stmt_cont(loc=floc, terminated=True);
}


# CPython's import prefix keeps int 0 in co_consts even though level uses
# LOAD_SMALL_INT (same dead-small-int slot as literal folding).
def ensure_import_prefix_consts(g: cfg_builder) {
    # Same dead-small-int rule: 0 is kept only at const index 0 (pool empty).
    if len(g.u.consts) == 0 {
        g.u.add_const(PyInt(t="int", val=0));
        g.u.dead_small_int_const = True;
    }
}

# LOAD_SMALL_INT level, LOAD_CONST fromlist, IMPORT_NAME modname (CPython import).
def emit_import_name_call(
    g: cfg_builder, modname: str, level: int, fromlist: PyObj | None, iloc: cloc
) {
    ensure_import_prefix_consts(g);
    emit_folded_int(g, level, iloc);
    if fromlist is None {
        none_idx = g.u.add_const(py_none());
        g.emit_op(OP_LOAD_CONST, none_idx, iloc);
    } else {
        fl_idx = g.u.add_const(fromlist);
        g.emit_op(OP_LOAD_CONST, fl_idx, iloc);
    }
    midx = g.u.add_name(modname);
    g.emit_op(OP_IMPORT_NAME, midx, iloc);
}

def visit_import(g: cfg_builder, imp: Import) -> stmt_cont {
    iloc = nloc(imp.lineno, imp.end_lineno, imp.col_offset, imp.end_col_offset);
    ni = 0;
    while ni < len(imp.names) {
        a = imp.names[ni];
        emit_import_name_call(g, a.name, 0, None, iloc);
        emit_name_store(g, import_bind_name(a), iloc);
        ni = ni + 1;
    }
    return stmt_cont(loc=iloc);
}

def visit_import_from(g: cfg_builder, imp: ImportFrom) -> stmt_cont {
    iloc = nloc(imp.lineno, imp.end_lineno, imp.col_offset, imp.end_col_offset);
    level = 0;
    if imp.level is not None {
        level = imp.level;
    }
    modname = "";
    if imp.module is not None {
        modname = imp.module;
    }
    names: list[PyObj] = [];
    ni = 0;
    while ni < len(imp.names) {
        names.append(PyStr(t="str", val=imp.names[ni].name));
        ni = ni + 1;
    }
    fromlist = PyTuple(t="tuple", items=names);
    emit_import_name_call(g, modname, level, fromlist, iloc);
    ni = 0;
    while ni < len(imp.names) {
        a = imp.names[ni];
        fidx = g.u.add_name(a.name);
        g.emit_op(OP_IMPORT_FROM, fidx, iloc);
        emit_name_store(g, import_bind_name(a), iloc);
        ni = ni + 1;
    }
    g.emit_op(OP_POP_TOP, 0, iloc);
    return stmt_cont(loc=iloc);
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
        # Same-arity, no-star sequence-literal elision: CPython avoids the
        # build/unpack round-trip by evaluating the RHS elements and reordering
        # in place (SWAP for n<=3, BUILD_TUPLE+UNPACK_SEQUENCE for n>=4).
        if len(asgn.targets) == 1
            and is_seq_literal(asgn.targets[0])
            and is_seq_literal(asgn.value) {
            telts = seq_target_elts(asgn.targets[0]);
            velts = seq_target_elts(asgn.value);
            if len(telts) == len(velts)
                and starred_target_index(telts) < 0
                and starred_target_index(velts) < 0 {
                emit = visit_store_seq_literal(
                    g, telts, velts, expr_loc(asgn.targets[0]), expr_loc(asgn.value)
                );
                return stmt_cont(loc=emit.loc);
            }
        }
        if len(asgn.targets) == 1 and isinstance(asgn.value, Name) {
            vn = asgn.value as Name;
            vfi = fast_local_index(g, codegen_mangle(g, vn.id));
            if vfi >= 0 {
                vloc = expr_loc(vn);
                g.emit_op(OP_LOAD_FAST, vfi, vloc);
                emit = visit_store_target_tos(g, asgn.targets[0]);
                return stmt_cont(loc=emit.loc);
            }
        }
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
            idx = g.u.add_name(codegen_mangle(g, attr.attr));
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
    if isinstance(s, Global) or isinstance(s, Nonlocal) {
        # global / nonlocal are scope declarations resolved entirely in the
        # symtable (they retarget name loads/stores to STORE_GLOBAL / STORE_DEREF).
        # They emit no bytecode of their own.
        return stmt_cont(loc=stmt_loc(s));
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
    if isinstance(s, AsyncFor) {
        t = tail;
        if t is None {
            t = [];
        }
        return visit_async_for(g, s as AsyncFor, more_code_follows, t, tail_idx);
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
    if isinstance(s, AsyncFunctionDef) {
        return visit_async_function_def(g, s as AsyncFunctionDef);
    }
    if isinstance(s, ClassDef) {
        return visit_class_def(g, s as ClassDef);
    }
    if isinstance(s, Import) {
        return visit_import(g, s as Import);
    }
    if isinstance(s, ImportFrom) {
        return visit_import_from(g, s as ImportFrom);
    }
    if isinstance(s, Try) {
        t = tail;
        if t is None {
            t = [];
        }
        return visit_try(g, s as Try, more_code_follows, t, tail_idx, tail_join);
    }
    if isinstance(s, Raise) {
        return visit_raise_stmt(g, s as Raise);
    }
    if isinstance(s, With) {
        t = tail;
        if t is None {
            t = [];
        }
        return visit_with(g, s as With, more_code_follows, t, tail_idx, tail_join);
    }
    if isinstance(s, AsyncWith) {
        t = tail;
        if t is None {
            t = [];
        }
        return visit_async_with(g, s as AsyncWith, more_code_follows, t, tail_idx, tail_join);
    }
    if isinstance(s, Match) {
        t = tail;
        if t is None {
            t = [];
        }
        return visit_match(g, s as Match, more_code_follows, t, tail_idx, tail_join);
    }
    if isinstance(s, Assert) {
        return visit_assert_stmt(g, s as Assert);
    }
    codegen_fail(
        g,
        "NotImplementedError",
        "unsupported statement: " + ast_node_name(s as ast_node)
    );
    return stmt_cont(loc=stmt_loc(s));
}

# Emit a Return statement and finish the compile unit (no module epilogue).
def visit_return_stmt(
    g: cfg_builder, r: Return, check_fast: bool = False, borrow_fast: bool = False
) {
    rloc = nloc(r.lineno, r.end_lineno, r.col_offset, r.end_col_offset);
    if r.value is not None {
        if isinstance(r.value, Name) {
            n = r.value as Name;
            name = codegen_mangle(g, n.id);
            fi = fast_local_index(g, name);
            if fi >= 0 {
                if check_fast {
                    g.emit_op(OP_LOAD_FAST_CHECK, fi, rloc);
                } elif borrow_fast {
                    g.emit_op(OP_LOAD_FAST_BORROW, fi, rloc);
                } else {
                    g.emit_op(OP_LOAD_FAST, fi, rloc);
                }
                g.emit_op(OP_RETURN_VALUE, 0, rloc);
                return;
            }
        }
        visit_expr(g, r.value);
        g.emit_op(OP_RETURN_VALUE, 0, rloc);
        return;
    }
    none_idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, rloc);
    g.emit_op(OP_RETURN_VALUE, 0, rloc);
}



def sym_class_qualname(
    cd: ClassDef, sym_cls: sym_block, enclosing_private: str | None
) -> str {
    if sym_cls.nested and enclosing_private is not None {
        return enclosing_private + "." + cd.name;
    }
    return cd.name;
}

# LOAD_BUILD_CLASS call: name const is already on stack; push bases and keywords.
def emit_class_build_call(g: cfg_builder, cd: ClassDef, cloc: cloc) {
    bases = class_effective_bases(cd);
    kws = class_effective_keywords(cd);
    bi = 0;
    while bi < len(bases) {
        visit_expr(g, bases[bi], False, False);
        if codegen_busy(g) {
            return;
        }
        bi = bi + 1;
    }
    if len(kws) == 0 {
        g.emit_op(OP_CALL, 2 + len(bases), cloc);
        return;
    }
    ki = 0;
    while ki < len(kws) {
        kw = kws[ki];
        if kw.arg is None {
            codegen_fail(
                g, "NotImplementedError", "keyword argument unpacking not supported"
            );
            return;
        }
        visit_expr(g, kw.value, False, False);
        if codegen_busy(g) {
            return;
        }
        ki = ki + 1;
    }
    names: list[PyObj] = [];
    ki = 0;
    while ki < len(kws) {
        names.append(PyStr(t="str", val=kws[ki].arg));
        ki = ki + 1;
    }
    tup = PyTuple(t="tuple", items=names);
    tidx = g.u.add_const(tup);
    g.emit_op(OP_LOAD_CONST, tidx, cloc);
    g.emit_op(OP_CALL_KW, 2 + len(bases) + len(kws), cloc);
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

def emit_class_body_prologue(g: cfg_builder, cd: ClassDef, class_qname: str) {
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
    qidx = g.u.add_const(PyStr(t="str", val=class_qname));
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
    u_cls = compile_class_cfg(cd, g.u.filename, sym_cls, g.private);
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
    emit_class_build_call(g, cd, cloc);
    if codegen_busy(g) {
        return stmt_cont(loc=cloc);
    }
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
    cd: ClassDef,
    filename: str,
    sym_cls: sym_block,
    enclosing_private: str | None = None
) -> unverified_cfg {
    class_qname = sym_class_qualname(cd, sym_cls, enclosing_private);
    u = unverified_cfg(
        filename=filename,
        name=cd.name,
        qualname=class_qname,
        firstlineno=cd.lineno
    );
    if sym_cls.nested {
        u.flags = CO_NESTED;
    }
    if class_body_has_function(cd) {
        u.cellvars = ["__classdict__"];
    }
    entry = u.add_block();
    g = new_cfg_builder(u, entry, sym_cls, cd.name);
    emit_class_body_prologue(g, cd, class_qname);
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
    floc = function_def_loc(fd);
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
    u_fn = compile_fn_cfg(
        fd.name, fd.args, fd.body, fd.lineno, g.u.filename, sym_fn, g.private
    );
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

# Lower `async def name(...): ...` at module/class scope into nested PyCode + MAKE_FUNCTION.
def visit_async_function_def(g: cfg_builder, afd: AsyncFunctionDef) -> stmt_cont {
    floc = async_function_def_loc(afd);
    if g.sym_top is None {
        codegen_fail(g, "SystemError", "function definition without symtable");
        return stmt_cont(loc=floc);
    }
    sym_fn = sym_function_child(g.sym_top, afd.name);
    if sym_fn is None {
        codegen_fail(g, "SystemError", "missing symtable for function " + afd.name);
        return stmt_cont(loc=floc);
    }
    decorators = afd.decorator_list;
    if decorators is None {
        decorators = [];
    }
    u_fn = compile_fn_cfg(
        afd.name, afd.args, afd.body, afd.lineno, g.u.filename, sym_fn, g.private
    );
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
    emit_make_function_with_closure(g, sym_fn, co, floc, afd.args);
    ri = len(decorators) - 1;
    while ri >= 0 {
        dec = decorators[ri];
        g.emit_op(OP_CALL, 0, expr_loc(dec));
        ri = ri - 1;
    }
    if g.sym_top is not None and g.sym_top.block_type == "function" {
        fi = fast_local_index(g, afd.name);
        if fi < 0 {
            codegen_fail(
                g, "SystemError", "missing fast local for nested function " + afd.name
            );
            return stmt_cont(loc=floc);
        }
        g.emit_op(OP_STORE_FAST, fi, floc);
    } else {
        nidx = g.u.add_name(afd.name);
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
    u_fn = compile_lambda_cfg(lam, g.u.filename, sym_fn, g.private);
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
    lam: Lambda, filename: str, sym_fn: sym_block, private: str | None = None
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
    g = new_cfg_builder(u, entry, sym_fn, private);
    emit_function_prologue(g, sym_fn, lam.lineno);
    bloc = expr_loc(lam.body);
    visit_expr(g, lam.body);
    if codegen_busy(g) {
        return u;
    }
    g.emit_op(OP_RETURN_VALUE, 0, bloc);
    return u;
}

# Build unverified_cfg for a function/async body (nested code object before assembly).
def compile_fn_cfg(
    name: str,
    args: arguments,
    body: list[stmt],
    lineno: int,
    filename: str,
    sym_fn: sym_block,
    private: str | None = None
) -> unverified_cfg {
    (argcount, posonly, kwonly) = function_argcounts(args);
    u = unverified_cfg(
        filename=filename,
        name=name,
        qualname=name,
        firstlineno=lineno
    );
    u.argcount = argcount;
    u.posonlyargcount = posonly;
    u.kwonlyargcount = kwonly;
    is_suspendable = sym_fn.generator or sym_fn.coroutine;
    u.flags = function_code_flags(args);
    if sym_fn.generator and sym_fn.coroutine {
        u.flags = u.flags | CO_ASYNC_GENERATOR;
    } elif sym_fn.generator {
        u.flags = u.flags | CO_GENERATOR;
    } elif sym_fn.coroutine {
        u.flags = u.flags | CO_COROUTINE;
    }
    u.varnames = fast_varnames_from_sym(sym_fn);
    entry = u.add_block();
    g = new_cfg_builder(u, entry, sym_fn, private);
    protect_start = emit_function_prologue(g, sym_fn, lineno, is_suspendable);
    last = loc(0, lineno, 0, 0);
    terminated = False;
    bi = 0;
    while bi < len(body) {
        s = body[bi];
        cont = visit_stmt(
            g, s, exec_tail_emits_code(body, bi + 1), body, bi + 1
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
    emit_deferred_comp_handlers(g);
    if is_suspendable {
        emit_generator_except_handler(g, protect_start);
    }
    return u;
}

# Build unverified_cfg for a `def` body (nested code object before assembly).
def compile_function_cfg(
    fd: FunctionDef, filename: str, sym_fn: sym_block, private: str | None = None
) -> unverified_cfg {
    return compile_fn_cfg(
        fd.name, fd.args, fd.body, fd.lineno, filename, sym_fn, private
    );
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
