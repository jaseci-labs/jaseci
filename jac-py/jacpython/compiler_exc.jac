# Exception-handling codegen (try/except/finally, with, raise) extracted
# from compiler_codegen.jac. Pure mechanical move; see compiler_codegen.jac for
# the module-initialization ordering contract.

import from objects { py_none }
import from opcode_meta {
    OP_BUILD_LIST,
    OP_CALL,
    OP_CALL_INTRINSIC_1,
    OP_CALL_INTRINSIC_2,
    OP_CHECK_EG_MATCH,
    OP_CHECK_EXC_MATCH,
    OP_CLEANUP_THROW,
    OP_COPY,
    OP_END_SEND,
    OP_GET_AWAITABLE,
    OP_JUMP_BACKWARD_NO_INTERRUPT,
    OP_JUMP_FORWARD,
    OP_LIST_APPEND,
    OP_LOAD_CONST,
    OP_LOAD_SPECIAL,
    OP_NOP,
    OP_NOT_TAKEN,
    OP_POP_EXCEPT,
    OP_POP_JUMP_IF_FALSE,
    OP_POP_JUMP_IF_NONE,
    OP_POP_JUMP_IF_NOT_NONE,
    OP_POP_JUMP_IF_TRUE,
    OP_POP_TOP,
    OP_PUSH_EXC_INFO,
    OP_RAISE_VARARGS,
    OP_RERAISE,
    OP_RESUME,
    OP_SEND,
    OP_STORE_FAST,
    OP_SWAP,
    OP_TO_BOOL,
    OP_WITH_EXCEPT_START,
    OP_YIELD_VALUE,
}
import from ast_nodes {
    AsyncWith,
    ExceptHandler,
    Raise,
    Return,
    Try,
    TryStar,
    With,
    stmt,
}
import from compiler_ir {
    basicblock,
    cfg_builder,
    cloc,
    except_region,
    loc,
    no_loc,
    stmt_cont,
}
import from compiler_emit {
    codegen_busy,
    codegen_fail,
    emit_await_send_except_regions,
    emit_await_send_loop_footer,
    emit_await_send_loop_header,
    visit_expr,
}
import from codegen_util {
    body_is_try_except_only,
    body_is_try_finally_only,
    exec_tail_emits_code,
    expr_loc,
    nloc,
    stmt_loc,
    try_handler_span,
}
import from compiler_annotations { ann_scope_plan }
import from compiler_codegen { emit_module_return, emit_name_delete, emit_name_store, visit_return_stmt, visit_stmt_tail, visit_stmts, visit_store_target_tos }
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
    `protect = g.generator_protect_start;
    if `protect >= 0 {
        g.u.except_regions.append(
            except_region(
                start_block=`protect,
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


# Clear an except-as binding (STORE None + DELETE) before handler exit.
def emit_except_as_cleanup(g: cfg_builder, bind_name: str, cloc: cloc) {
    none_idx = g.u.add_const(py_none());
    g.emit_op(OP_LOAD_CONST, none_idx, cloc);
    emit_name_store(g, bind_name, cloc);
    emit_name_delete(g, bind_name, cloc);
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
    tail_join: basicblock | None = None,
    ann_ctx: ann_scope_plan | None = None
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
    body_cont = visit_stmts(g, t.body, 0, True, None, 0, None, ann_ctx);
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    g.use(protect_end);
    finally_cont = visit_stmts(g, t.finalbody, 0, False, None, 0, None, ann_ctx);
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
        tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more, ann_ctx);
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
    finally_except_cont = visit_stmts(g, t.finalbody, 0, False, None, 0, None, ann_ctx);
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
        return stmt_cont(loc=tloc, next_si=len(tail), terminated=tail_terminated);
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
    tloc: cloc,
    ann_ctx: ann_scope_plan | None = None
) {
    g.use(blk);
    if with_nop {
        g.emit_op(OP_NOP, 0, tloc);
    }
    fc = visit_stmts(g, finalbody, 0, False, None, 0, None, ann_ctx);
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
        tc = visit_stmt_tail(g, tail, tail_idx, tail_more, ann_ctx);
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
# try/except (CPython compiles them identically). Multiple handlers chained after
# one try, optional else and finally. Handlers may bind via `except E as e`;
# each bound handler gets its own as-cleanup unwind block.


# Coalesce spans that share handler/depth/lasti into maximal runs (CPython's
# exception-table builder merges contiguous same-target ranges; overlapping
# spans with identical handler metadata also fold into the covering range).
# Comparison is in LAYOUT position, not block id: deferred blocks are placed
# at first use, so id order does not match layout order.
def merge_except_spans(g: cfg_builder, spans: list[except_region]) -> list[except_region] {
    pos_of: dict[int, int] = {};
    bi = 0;
    while bi < len(g.u.blocks) {
        pos_of[g.u.blocks[bi].id] = bi;
        bi = bi + 1;
    }
    order: list[int] = [];
    i = 0;
    while i < len(spans) {
        order.append(i);
        i = i + 1;
    }
    ni = 0;
    while ni < len(order) {
        nj = ni + 1;
        while nj < len(order) {
            a = pos_of.get(spans[order[nj]].start_block, 0);
            b = pos_of.get(spans[order[ni]].start_block, 0);
            if a < b {
                tmp = order[ni];
                order[ni] = order[nj];
                order[nj] = tmp;
            }
            nj = nj + 1;
        }
        ni = ni + 1;
    }
    out: list[except_region] = [];
    oi = 0;
    while oi < len(order) {
        cur = spans[order[oi]];
        oi = oi + 1;
        while oi < len(order) {
            nxt = spans[order[oi]];
            if nxt.handler_block != cur.handler_block
                or nxt.stack_depth != cur.stack_depth
                or nxt.preserve_lasti != cur.preserve_lasti {
                break;
            }
            nxt_pos = pos_of.get(nxt.start_block, -1);
            cur_end_pos = pos_of.get(cur.end_block, -1);
            if nxt_pos < 0 or cur_end_pos < 0 or nxt_pos > cur_end_pos {
                break;
            }
            new_end = cur.end_block;
            if pos_of.get(nxt.end_block, -1) > cur_end_pos {
                new_end = nxt.end_block;
            }
            cur = except_region(
                start_block=cur.start_block,
                end_block=new_end,
                handler_block=cur.handler_block,
                stack_depth=cur.stack_depth,
                preserve_lasti=cur.preserve_lasti
            );
            oi = oi + 1;
        }
        out.append(cur);
    }
    return out;
}


def visit_try_except_finally(
    g: cfg_builder,
    t: Try,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None,
    ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    tloc = stmt_loc(t);
    nh = len(t.handlers);
    noloc = no_loc();
    last_is_bare = t.handlers[nh - 1].type is None;

    nop_blk = g.new_block();
    try_body = g.new_block();
    g.use(nop_blk);
    g.emit_op(OP_NOP, 0, tloc);
    g.use(try_body);
    protect_start = g.cur.id;
    body_cont = visit_stmts(g, t.body, 0, True, None, 0, None, ann_ctx);
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }

    protect_end = g.new_block();
    g.use(protect_end);
    normal_reaches_fin = not body_cont.terminated;
    has_else = t.orelse is not None and len(t.orelse) > 0;
    dead_blocks = -1;
    dead_regions = -1;
    dead_pending = -1;
    dead_ntf_ss = -1;
    dead_ntf_se = -1;
    dead_ntf_us = -1;
    dead_nte = -1;
    if has_else {
        if body_cont.terminated {
            # CPython still compiles a dead else after a terminated body: its
            # names and consts register first, then the unreachable code is
            # stripped by the flowgraph. Emit into throwaway blocks and drop
            # them so registration order matches without keeping the bytes.
            dead_blocks = len(g.u.blocks);
            dead_regions = len(g.u.except_regions);
            dead_pending = len(g.u.pending_try_unwind_regions);
            dead_ntf_ss = g.u.nested_try_finally_success_start;
            dead_ntf_se = g.u.nested_try_finally_success_end;
            dead_ntf_us = g.u.nested_try_finally_unwind_start;
            dead_nte = g.u.nested_try_except_end;
            g.use(g.new_block());
        }
        else_cont = visit_stmts(g, t.orelse, 0, True, None, 0, None, ann_ctx);
        if codegen_busy(g) {
            return stmt_cont(loc=tloc);
        }
        if dead_blocks >= 0 {
            g.u.blocks = g.u.blocks[0:dead_blocks];
            g.u.except_regions = g.u.except_regions[0:dead_regions];
            g.u.pending_try_unwind_regions =
                g.u.pending_try_unwind_regions[0:dead_pending];
            g.u.nested_try_finally_success_start = dead_ntf_ss;
            g.u.nested_try_finally_success_end = dead_ntf_se;
            g.u.nested_try_finally_unwind_start = dead_ntf_us;
            g.u.nested_try_except_end = dead_nte;
        } elif else_cont.terminated {
            normal_reaches_fin = False;
        }
    }

    # Deferred layout blocks; placed below in CPython's layout order.
    fin_inline = g.new_deferred_block();
    handler_entry = g.new_deferred_block();
    nt_blks: list[basicblock] = [];
    body_blks: list[basicblock] = [];
    epi_blks: list[basicblock] = [];
    next_blks: list[basicblock] = [];
    as_unwind_blks: list[basicblock] = [];
    binds: list[str | None] = [];
    hi = 0;
    while hi < nh {
        nt_blks.append(g.new_deferred_block());
        body_blks.append(g.new_deferred_block());
        epi_blks.append(g.new_deferred_block());
        as_unwind_blks.append(g.new_deferred_block());
        binds.append((t.handlers[hi] as ExceptHandler).name);
        if hi < nh - 1 {
            next_blks.append(g.new_deferred_block());
        }
        hi = hi + 1;
    }
    reraise_blk = g.new_deferred_block();
    inner_unwind = g.new_deferred_block();
    fin_except = g.new_deferred_block();
    outer_unwind = g.new_deferred_block();

    # Exception-table spans collected during emission, coalesced at the end.
    spans: list[except_region] = [];

    # try body -> first handler.
    if body_is_try_finally_only(t.body) {
        if g.u.nested_try_finally_success_start >= 0
            and g.u.nested_try_finally_success_end >= 0 {
            spans.append(
                except_region(
                    start_block=g.u.nested_try_finally_success_start,
                    end_block=g.u.nested_try_finally_success_end,
                    handler_block=handler_entry.id,
                    stack_depth=1
                )
            );
        }
        if g.u.nested_try_finally_unwind_start >= 0 {
            spans.append(
                except_region(
                    start_block=g.u.nested_try_finally_unwind_start,
                    end_block=handler_entry.id,
                    handler_block=handler_entry.id,
                    stack_depth=1
                )
            );
        }
    } elif body_is_try_except_only(t.body) and g.u.nested_try_except_end >= 0 {
        # The nested try/except owns [body start, its unwind]; this region
        # protects only what follows it so entries never overlap.
        spans.append(
            except_region(
                start_block=g.u.nested_try_except_end,
                end_block=protect_end.id,
                handler_block=handler_entry.id,
                stack_depth=1
            )
        );
    } else {
        spans.append(
            except_region(
                start_block=protect_start,
                end_block=protect_end.id,
                handler_block=handler_entry.id,
                stack_depth=1
            )
        );
    }

    fin_early = normal_reaches_fin;
    if has_else and normal_reaches_fin {
        # else clause -> exceptional finally handler directly (no active except
        # frame on that path).
        spans.append(
            except_region(
                start_block=protect_end.id,
                end_block=fin_inline.id,
                handler_block=fin_except.id,
                stack_depth=1
            )
        );
    }

    falls: list[bool] = [];
    nested_in: list[bool] = [];
    hi = 0;
    while hi < nh {
        falls.append(False);
        nested_in.append(False);
        hi = hi + 1;
    }

    if fin_early {
        g.use(fin_inline);
    }

    g.use(handler_entry);
    g.emit_op(OP_PUSH_EXC_INFO, 0, noloc);
    hi = 0;
    while hi < nh {
        h = t.handlers[hi] as ExceptHandler;
        hloc = try_handler_span(h);
        if hi > 0 {
            g.use(next_blks[hi - 1]);
        }
        if h.type is not None {
            visit_expr(g, h.type);
            if codegen_busy(g) {
                return stmt_cont(loc=tloc);
            }
            g.emit_op(OP_CHECK_EXC_MATCH, 0, hloc);
            if hi < nh - 1 {
                g.emit_jump(OP_POP_JUMP_IF_FALSE, next_blks[hi].id, hloc);
            } else {
                g.emit_jump(OP_POP_JUMP_IF_FALSE, reraise_blk.id, hloc);
            }
            if hi > 0 {
                # CPython keeps this NOT_TAKEN in its own uncovered block for
                # chained handlers; normalize_jumps skips the inline insert.
                g.use(nt_blks[hi]);
                g.emit_op(OP_NOT_TAKEN, 0, noloc);
            }
        }
        # Binding store belongs to the MATCH block (CPython splits the
        # exception-table body region AFTER the store, matching slice-3 flat
        # lowering). Unbound handlers keep POP_TOP at the top of the body
        # block, exactly as CPython's L5/L6 NOT_TAKEN / POP_TOP block pair.
        if binds[hi] is not None {
            emit_name_store(g, binds[hi] as str, hloc);
            g.use(body_blks[hi]);
        } else {
            g.use(body_blks[hi]);
            g.emit_op(OP_POP_TOP, 0, hloc);
        }
        # While emitting this handler body, advertise the inline success
        # epilogue (POP_EXCEPT [+ except-as cleanup] + jump to fin) and the
        # enclosing cleanup block so a nested try falling through finishes the
        # handler exactly the way CPython duplicates the epilogue per path.
        saved_ffin = g.handler_fallthrough_fin;
        saved_fbwd = g.handler_fallthrough_backward;
        saved_ffh = g.handler_fallthrough_fin_handler;
        saved_fbind = g.handler_fallthrough_bind;
        saved_feu = g.handler_enclosing_unwind;
        saved_fell = g.handler_fell_through;
        saved_nd = g.handler_nest_depth;
        g.handler_fallthrough_fin = fin_inline;
        g.handler_fallthrough_backward = fin_early;
        g.handler_fallthrough_fin_handler = fin_except.id;
        g.handler_fallthrough_bind = binds[hi];
        g.handler_enclosing_unwind = inner_unwind.id;
        g.handler_fell_through = False;
        g.handler_nest_depth = saved_nd + 1;
        hbody = visit_stmts(g, h.body, 0, False, None, 0, None, ann_ctx);
        nested_fell = g.handler_fell_through;
        g.handler_fallthrough_fin = saved_ffin;
        g.handler_fallthrough_backward = saved_fbwd;
        g.handler_fallthrough_fin_handler = saved_ffh;
        g.handler_fallthrough_bind = saved_fbind;
        g.handler_enclosing_unwind = saved_feu;
        g.handler_fell_through = saved_fell;
        g.handler_nest_depth = saved_nd;
        if codegen_busy(g) {
            return stmt_cont(loc=tloc);
        }
        if nested_fell {
            nested_in[hi] = True;
        }
        if not hbody.terminated {
            falls[hi] = True;
            g.use(epi_blks[hi]);
            g.emit_op(OP_POP_EXCEPT, 0, hbody.loc);
            if binds[hi] is not None {
                emit_except_as_cleanup(g, binds[hi] as str, hbody.loc);
            }
            if fin_early {
                g.emit_jump(OP_JUMP_BACKWARD_NO_INTERRUPT, fin_inline.id, hbody.loc);
            } else {
                g.emit_jump(OP_JUMP_FORWARD, fin_inline.id, hbody.loc);
            }
        }
        if binds[hi] is not None {
            # Per-handler as-cleanup unwind: an exception raised inside a bound
            # handler's body clears the binding before re-raising (CPython emits
            # one such block per bound handler, laid out after its epilogue,
            # regardless of whether the body terminates).
            g.use(as_unwind_blks[hi]);
            emit_except_as_cleanup(g, binds[hi] as str, noloc);
            g.emit_op(OP_RERAISE, 1, noloc);
        }
        hi = hi + 1;
    }
    if not last_is_bare {
        g.use(reraise_blk);
        g.emit_op(OP_RERAISE, 0, try_handler_span(t.handlers[nh - 1]));
    }
    g.use(inner_unwind);
    g.emit_op(OP_COPY, 3, noloc);
    g.emit_op(OP_POP_EXCEPT, 0, noloc);
    g.emit_op(OP_RERAISE, 1, noloc);

    # Per-handler protected spans -> inner unwind (COPY 3 / POP_EXCEPT / RERAISE 1).
    hi = 0;
    while hi < nh {
        h = t.handlers[hi] as ExceptHandler;
        typed = h.type is not None;
        entry_id = handler_entry.id;
        if hi > 0 {
            entry_id = next_blks[hi - 1].id;
        }
        if nested_in[hi] {
            # Handler body = nested try that fell through: its own regions carve
            # out its span. Protect only the match code before it and the tail
            # from its unwind onward (which merges with the next handler's
            # match span, matching CPython's coalesced entries).
            inner_start = g.u.nested_try_except_start;
            if inner_start < 0 {
                inner_start = entry_id;
            }
            # Match portion -> shared unwind.
            spans.append(
                except_region(
                    start_block=entry_id,
                    end_block=inner_start,
                    handler_block=inner_unwind.id,
                    stack_depth=3,
                    preserve_lasti=True
                )
            );
            after_id = inner_unwind.id;
            if hi < nh - 1 {
                after_id = next_blks[hi].id;
            } else {
                if not last_is_bare {
                    after_id = reraise_blk.id;
                }
            }
            # Body portion -> as-cleanup unwind when bound (clears binding
            # before re-raise), shared unwind otherwise.
            body_handler = inner_unwind.id;
            if binds[hi] is not None {
                body_handler = as_unwind_blks[hi].id;
                spans.append(
                    except_region(
                        start_block=as_unwind_blks[hi].id,
                        end_block=after_id,
                        handler_block=inner_unwind.id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
            }
            spans.append(
                except_region(
                    start_block=g.u.nested_try_except_end,
                    end_block=after_id,
                    handler_block=body_handler,
                    stack_depth=3,
                    preserve_lasti=True
                )
            );
        } elif typed and falls[hi] {
            if binds[hi] is not None {
                # Bound handler: CPython splits at the body boundary - match
                # code unwinds via the shared COPY 3 / POP_EXCEPT / RERAISE 1
                # chain, body exceptions clear the binding first.
                spans.append(
                    except_region(
                        start_block=entry_id,
                        end_block=body_blks[hi].id,
                        handler_block=inner_unwind.id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
                spans.append(
                    except_region(
                        start_block=body_blks[hi].id,
                        end_block=epi_blks[hi].id,
                        handler_block=as_unwind_blks[hi].id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
            } elif hi == 0 {
                spans.append(
                    except_region(
                        start_block=entry_id,
                        end_block=epi_blks[hi].id,
                        handler_block=inner_unwind.id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
            } else {
                spans.append(
                    except_region(
                        start_block=entry_id,
                        end_block=nt_blks[hi].id,
                        handler_block=inner_unwind.id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
                spans.append(
                    except_region(
                        start_block=body_blks[hi].id,
                        end_block=epi_blks[hi].id,
                        handler_block=inner_unwind.id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
            }
            # Exceptions while clearing the binding unwind via the shared chain
            # (coalesces with the following reraise span when present).
            if binds[hi] is not None {
                au_end = inner_unwind.id;
                if hi < nh - 1 {
                    au_end = next_blks[hi].id;
                } else {
                    if not last_is_bare {
                        au_end = reraise_blk.id;
                    }
                }
                spans.append(
                    except_region(
                        start_block=as_unwind_blks[hi].id,
                        end_block=au_end,
                        handler_block=inner_unwind.id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
            }
        } else {
            end_id = inner_unwind.id;
            if hi < nh - 1 {
                end_id = next_blks[hi].id;
            } else {
                if not last_is_bare {
                    end_id = reraise_blk.id;
                }
            }
            if not typed {
                if falls[hi] {
                    end_id = epi_blks[hi].id;
                }
            }
            if binds[hi] is not None {
                # Terminated bound handler body (explicit raise/return): CPython
                # still splits - match portion via the shared chain, everything
                # from the body start through the as-cleanup block itself.
                spans.append(
                    except_region(
                        start_block=entry_id,
                        end_block=body_blks[hi].id,
                        handler_block=inner_unwind.id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
                spans.append(
                    except_region(
                        start_block=body_blks[hi].id,
                        end_block=as_unwind_blks[hi].id,
                        handler_block=as_unwind_blks[hi].id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
                # The as-cleanup block itself unwinds via the shared chain
                # (merges with the following reraise span when present).
                au_end = inner_unwind.id;
                if hi < nh - 1 {
                    au_end = next_blks[hi].id;
                } else {
                    if not last_is_bare {
                        au_end = reraise_blk.id;
                    }
                }
                spans.append(
                    except_region(
                        start_block=as_unwind_blks[hi].id,
                        end_block=au_end,
                        handler_block=inner_unwind.id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
            } else {
                spans.append(
                    except_region(
                        start_block=entry_id,
                        end_block=end_id,
                        handler_block=inner_unwind.id,
                        stack_depth=3,
                        preserve_lasti=True
                    )
                );
            }
        }
        if falls[hi] {
            fe_end = fin_except.id;
            if hi < nh - 1 {
                fe_end = next_blks[hi].id;
            } else {
                if not last_is_bare {
                    fe_end = reraise_blk.id;
                } elif not fin_early {
                    # Bare last handler: no reraise block follows, so the span
                    # runs through the unwind chain into the late inline
                    # finally's leading NOP (merges with the inner-unwind span).
                    fe_end = fin_inline.id;
                }
            }
            if binds[hi] is not None {
                # The epilogue span ends where the as-cleanup block begins:
                # cleanup failures unwind via the fin handler from base depth.
                fe_end = as_unwind_blks[hi].id;
            }
            spans.append(
                except_region(
                    start_block=epi_blks[hi].id,
                    end_block=fe_end,
                    handler_block=fin_except.id,
                    stack_depth=1
                )
            );
        }
        hi = hi + 1;
    }
    if not last_is_bare {
        spans.append(
            except_region(
                start_block=reraise_blk.id,
                end_block=inner_unwind.id,
                handler_block=inner_unwind.id,
                stack_depth=3,
                preserve_lasti=True
            )
        );
    }

    # Inline finally copy on fall-through paths: placed before the handlers when
    # the normal path reaches it, otherwise after the unwind chain with the
    # single-predecessor leading NOP CPython emits there.
    any_reaches_fin = fin_early;
    fi = 0;
    while fi < nh {
        if falls[fi] or nested_in[fi] {
            any_reaches_fin = True;
        }
        fi = fi + 1;
    }
    if any_reaches_fin {
        late_preds = 0;
        if not fin_early {
            fi = 0;
            while fi < nh {
                if falls[fi] or nested_in[fi] {
                    late_preds = late_preds + 1;
                }
                fi = fi + 1;
            }
        }
    }
    # Inner unwind chain -> exceptional finally handler. With a late inline
    # copy the range ends at the copy's leading NOP (unprotected, like
    # CPython); otherwise it runs to the fin handler itself. Registered
    # even when no path reaches an inline copy - CPython keeps this entry
    # defensively (the COPY/POP_EXCEPT/RERAISE sequence can itself fault).
    iu_span_end = fin_except.id;
    if not fin_early and any_reaches_fin {
        iu_span_end = fin_inline.id;
    }
    spans.append(
        except_region(
            start_block=inner_unwind.id,
            end_block=iu_span_end,
            handler_block=fin_except.id,
            stack_depth=1
        )
    );
    if any_reaches_fin {
        emit_finally_inline_block(
            g,
            t.finalbody,
            fin_inline,
            not fin_early and late_preds == 1,
            more_code_follows,
            tail,
            tail_idx,
            tloc, ann_ctx);
        if codegen_busy(g) {
            return stmt_cont(loc=tloc);
        }
    }

    # Exceptional finally handler: run finalbody under PUSH_EXC_INFO, re-raise.
    g.use(fin_except);
    g.emit_op(OP_PUSH_EXC_INFO, 0, noloc);
    fe_cont = visit_stmts(g, t.finalbody, 0, False, None, 0, None, ann_ctx);
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    g.emit_op(OP_RERAISE, 0, fe_cont.loc);
    g.use(outer_unwind);
    g.emit_op(OP_COPY, 3, noloc);
    g.emit_op(OP_POP_EXCEPT, 0, noloc);
    g.emit_op(OP_RERAISE, 1, noloc);
    spans.append(
        except_region(
            start_block=fin_except.id,
            end_block=outer_unwind.id,
            handler_block=outer_unwind.id,
            stack_depth=3,
            preserve_lasti=True
        )
    );

    merged = merge_except_spans(g, spans);
    mi = 0;
    while mi < len(merged) {
        g.u.except_regions.append(merged[mi]);
        mi = mi + 1;
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
    tail_join: basicblock | None = None,
    ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    tloc = stmt_loc(t);
    if t.finalbody is not None and len(t.finalbody) > 0 {
        if t.handlers is not None and len(t.handlers) > 0 {
            return visit_try_except_finally(
                g, t, more_code_follows, tail, tail_idx, tail_join, ann_ctx);
        }
        return visit_try_finally(g, t, more_code_follows, tail, tail_idx, tail_join, ann_ctx);
    }
    if t.handlers is None or len(t.handlers) == 0 {
        codegen_fail(g, "NotImplementedError", "try without except");
        return stmt_cont(loc=tloc);
    }
    g.u.nested_try_except_end = -1;
    nop_blk = g.new_block();
    g.u.nested_try_except_start = nop_blk.id;
    try_body = g.new_block();
    # CPython's flowgraph drops a NOP whose line equals the previous
    # instruction's line; after PEP 649 annotation setup bytes that is
    # exactly the case for a Try opening the scope's body. Read the previous
    # line before switching to the (still empty) nop block.
    prev_line = -1;
    if len(g.cur.instrs) > 0 {
        prev_line = g.cur.instrs[len(g.cur.instrs) - 1].loc.lineno;
    }
    g.use(nop_blk);
    if prev_line != tloc.lineno {
        g.emit_op(OP_NOP, 0, tloc);
    }
    g.use(try_body);
    protect_start = g.cur.id;
    try_follows = more_code_follows;
    if not try_follows and tail is not None and tail_idx < len(tail) {
        try_follows = True;
    }
    body_cont = visit_stmts(g, t.body, 0, try_follows, tail, tail_idx, tail_join, ann_ctx);
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    protect_end = g.new_block();
    after_try_epilogue = g.new_block();
    g.use(protect_end);
    g.use(after_try_epilogue);
    normal_terminated = body_cont.terminated;
    if t.orelse is not None and len(t.orelse) > 0 and not body_cont.terminated {
        else_cont = visit_stmts(g, t.orelse, 0, try_follows, tail, tail_idx, tail_join, ann_ctx);
        if codegen_busy(g) {
            return stmt_cont(loc=tloc);
        }
        if else_cont.terminated {
            normal_terminated = True;
        }
    }
    body_fini_region_start: int = -1;
    if try_follows or g.handler_fallthrough_fin is not None {
        if g.handler_fallthrough_fin is not None
            and not normal_terminated
            and not try_follows {
            # Nested inside an enclosing handler: finish it inline (CPython
            # duplicates the enclosing handler epilogue on each success path).
            g.handler_fell_through = True;
            body_fini_region_start = g.cur.id;
            g.emit_op(OP_POP_EXCEPT, 0, body_cont.loc);
            if g.handler_fallthrough_bind is not None {
                emit_except_as_cleanup(
                    g, g.handler_fallthrough_bind as str, body_cont.loc
                );
            }
            if g.handler_fallthrough_backward {
                g.emit_jump(
                    OP_JUMP_BACKWARD_NO_INTERRUPT,
                    g.handler_fallthrough_fin.id,
                    body_cont.loc
                );
            } else {
                g.emit_jump(OP_JUMP_FORWARD, g.handler_fallthrough_fin.id, body_cont.loc);
            }
        } elif try_follows {
            tail_more = False;
            if tail is not None and tail_idx + 1 < len(tail) {
                tail_more = exec_tail_emits_code(tail, tail_idx + 1);
            }
            tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more, ann_ctx);
            if codegen_busy(g) {
                return stmt_cont(loc=body_cont.loc);
            }
            if not tail_cont.terminated and not normal_terminated {
                emit_module_return(g, tail_cont.loc);
            }
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
    } elif body_is_try_except_only(t.body) and g.u.nested_try_except_end >= 0 {
        g.u.except_regions.append(
            except_region(
                start_block=g.u.nested_try_except_end,
                end_block=protect_end.id,
                handler_block=handler_entry.id,
                stack_depth=1
            )
        );
    } else {
        g.u.except_regions.append(
            except_region(
                start_block=protect_start,
                end_block=protect_end.id,
                handler_block=handler_entry.id,
                stack_depth=1 + g.handler_nest_depth
            )
        );
    }
    noloc = no_loc();
    g.use(handler_entry);
    handler_region_start = handler_entry.id;
    g.emit_op(OP_PUSH_EXC_INFO, 0, noloc);
    if body_fini_region_start >= 0 {
        # Inline enclosing-handler epilogue after the body: protected by the
        # enclosing finally handler (CPython: the POP_EXCEPT + jump-to-finally
        # range maps to the fin handler at base depth).
        g.u.except_regions.append(
            except_region(
                start_block=body_fini_region_start,
                end_block=handler_entry.id,
                handler_block=g.handler_fallthrough_fin_handler,
                stack_depth=1
            )
        );
    }
    hloc = try_handler_span(t.handlers[0]);
    need_reraise_except_region = False;
    merged_handler_unwind_start = -1;
    except_as_unwind_start = -1;
    nested_fini_starts: list[int] = [];
    nested_fini_ends: list[int] = [];
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
        hbody = visit_stmts(g, h.body, 0, False, None, 0, None, ann_ctx);
        if codegen_busy(g) {
            return stmt_cont(loc=tloc);
        }
        handler_region_end = handler_tails[hi][0];
        handler_success = handler_tails[hi][1];
        g.use(handler_region_end);
        if not hbody.terminated {
            need_reraise_except_region = True;
            g.emit_op(OP_POP_EXCEPT, 0, hbody.loc);
            if bind_name is not None {
                emit_except_as_cleanup(g, bind_name, hbody.loc);
            }
            g.use(handler_success);
            if g.handler_fallthrough_fin is not None and not try_follows {
                # Nested in an enclosing handler: emit its epilogue inline
                # (second POP_EXCEPT + jump to finally) instead of returning.
                g.handler_fell_through = True;
                g.emit_op(OP_POP_EXCEPT, 0, hbody.loc);
                if g.handler_fallthrough_bind is not None {
                    emit_except_as_cleanup(
                        g, g.handler_fallthrough_bind as str, hbody.loc
                    );
                }
                if g.handler_fallthrough_backward {
                    g.emit_jump(
                        OP_JUMP_BACKWARD_NO_INTERRUPT,
                        g.handler_fallthrough_fin.id,
                        hbody.loc
                    );
                } else {
                    g.emit_jump(
                        OP_JUMP_FORWARD, g.handler_fallthrough_fin.id, hbody.loc
                    );
                }
            } else {
                emit_module_return(g, hbody.loc);
            }
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
                    stack_depth=3 + g.handler_nest_depth,
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
                    stack_depth=3 + g.handler_nest_depth,
                    preserve_lasti=True
                )
            );
        } else {
            if not hbody.terminated {
                if g.handler_fallthrough_fin is not None {
                    # Nested in an enclosing handler: CPython protects the match
                    # code AND the handler body with our own unwind (an
                    # exception in the body re-enters our cleanup path only up
                    # to the first POP_EXCEPT), then splits: the first
                    # POP_EXCEPT maps to the ENCLOSING try's cleanup and the
                    # inline epilogue maps to the fin handler.
                    append_try_unwind_region(
                        g,
                        except_region(
                            start_block=handler_region_start,
                            end_block=handler_region_end.id,
                            handler_block=-1,
                            stack_depth=3 + g.handler_nest_depth,
                            preserve_lasti=True
                        )
                    );
                    g.u.except_regions.append(
                        except_region(
                            start_block=handler_region_end.id,
                            end_block=handler_success.id,
                            handler_block=g.handler_enclosing_unwind,
                            stack_depth=3,
                            preserve_lasti=True
                        )
                    );
                    nested_fini_starts.append(handler_success.id);
                    if hi < len(t.handlers) - 1 {
                        nested_fini_ends.append(next_handlers[hi].id);
                    } else {
                        nested_fini_ends.append(-1);
                    }
                } else {
                    append_try_unwind_region(
                        g,
                        except_region(
                            start_block=handler_region_start,
                            end_block=handler_region_end.id,
                            handler_block=-1,
                            stack_depth=3 + g.handler_nest_depth,
                            preserve_lasti=True
                        )
                    );
                }
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
    nfi = 0;
    while nfi < len(nested_fini_starts) {
        fini_end = nested_fini_ends[nfi];
        if fini_end < 0 {
            # Last handler: the fin-protected epilogue ends at the no-match
            # reraise block (CPython L8..L9), not at the empty block after it.
            fini_end = reraise_blk.id;
        }
        g.u.except_regions.append(
            except_region(
                start_block=nested_fini_starts[nfi],
                end_block=fini_end,
                handler_block=g.handler_fallthrough_fin_handler,
                stack_depth=1
            )
        );
        nfi = nfi + 1;
    }
    if need_reraise_except_region {
        if except_as_unwind_start >= 0 {
            append_try_unwind_region(
                g,
                except_region(
                    start_block=except_as_unwind_start,
                    end_block=unwind_blk.id,
                    handler_block=-1,
                    stack_depth=3 + g.handler_nest_depth,
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
                    stack_depth=3 + g.handler_nest_depth,
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
                stack_depth=3 + g.handler_nest_depth,
                preserve_lasti=True
            )
        );
    }
    bind_try_unwind_handlers(g, unwind_blk.id);
    g.use(unwind_blk);
    g.emit_op(OP_COPY, 3, noloc);
    g.emit_op(OP_POP_EXCEPT, 0, noloc);
    g.emit_op(OP_RERAISE, 1, noloc);
    # Publish this statement's last block for an enclosing try whose body is
    # exactly this try/except, so its body span starts after our regions.
    g.u.nested_try_except_end = unwind_blk.id;
    return stmt_cont(loc=tloc, terminated=True);
}


# once the parser rules set except* ends from their final token.
def trystar_best_end(base: cloc, ln: int | None, col: int | None) -> cloc {
    if ln is None {
        return base;
    }
    take = False;
    if base.end_lineno is None or ln > base.end_lineno {
        take = True;
    } elif ln == base.end_lineno {
        if col is not None
            and (base.end_col_offset is None or col > base.end_col_offset) {
            take = True;
        }
    }
    if take {
        return nloc(base.lineno, ln, base.col_offset, col);
    }
    return base;
}

def trystar_last_body_loc(body: list[stmt]) -> cloc | None {
    if body is None or len(body) == 0 {
        return None;
    }
    s = body[len(body) - 1];
    return nloc(s.lineno, s.end_lineno, s.col_offset, s.end_col_offset);
}

def trystar_handler_loc(h: ExceptHandler) -> cloc {
    end = trystar_last_body_loc(h.body);
    el = h.lineno;
    ec = h.col_offset;
    if end is not None {
        if end.end_lineno is not None {
            el = end.end_lineno;
        }
        if end.end_col_offset is not None {
            ec = end.end_col_offset;
        }
    }
    return nloc(h.lineno, el, h.col_offset, ec);
}

def trystar_stmt_loc(t: TryStar) -> cloc {
    best = nloc(t.lineno, t.lineno, t.col_offset, t.col_offset);
    cand = trystar_last_body_loc(t.body);
    if cand is not None {
        best = trystar_best_end(best, cand.end_lineno, cand.end_col_offset);
    }
    if t.orelse is not None {
        cand = trystar_last_body_loc(t.orelse);
        if cand is not None {
            best = trystar_best_end(best, cand.end_lineno, cand.end_col_offset);
        }
    }
    if t.finalbody is not None {
        cand = trystar_last_body_loc(t.finalbody);
        if cand is not None {
            best = trystar_best_end(best, cand.end_lineno, cand.end_col_offset);
        }
    }
    hi = 0;
    while hi < len(t.handlers) {
        cand = trystar_handler_loc(t.handlers[hi] as ExceptHandler);
        best = trystar_best_end(best, cand.end_lineno, cand.end_col_offset);
        hi = hi + 1;
    }
    return best;
}


# Lower try/except* (ExceptionGroup handlers). Dispatch + guards; the byte
# layout lives in visit_try_star_except. CPython: codegen_try_star.
def visit_try_star(
    g: cfg_builder,
    t: TryStar,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None,
    ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    tloc = stmt_loc(t);
    if t.finalbody is not None and len(t.finalbody) > 0 {
        codegen_fail(g, "NotImplementedError", "except* with finally");
        return stmt_cont(loc=tloc);
    }
    if t.handlers is None or len(t.handlers) == 0 {
        codegen_fail(g, "NotImplementedError", "try* without except*");
        return stmt_cont(loc=tloc);
    }
    if g.handler_fallthrough_fin is not None {
        # Plain-except handlers duplicate their epilogue on each nested success
        # path (handler_fallthrough_* machinery); except* bodies are instead
        # wrapped per-handler by SETUP_CLEANUP regions. Bridging the two
        # conventions is its own slice.
        codegen_fail(g, "NotImplementedError", "except* inside except handler");
        return stmt_cont(loc=tloc);
    }
    return visit_try_star_except(g, t, more_code_follows, tail, tail_idx, tail_join, ann_ctx);
}


# Lower flat try/except*[/else] into CPython 3.14's ExceptionGroup walk:
# a results list accumulates the unmatched remainder of each CHECK_EG_MATCH
# split, then INTRINSIC_PREP_RERAISE_STAR recombines it for reraise.
#
# Layout (pinned against host dis for bare/bound/multi/else shapes):
#   [nop] [body] [else] [normal-path continuation]
#   he: PUSH_EXC_INFO, BUILD_LIST 0, COPY 2, match0, bind0
#   per handler i>0: match_i, NOT_TAKEN (own block), pre_i (bind store)
#   per handler: body_i, x_i (success epilogue), ce_i (cleanup_end), nm_i (no-match)
#   rr_match: PREP_RERAISE_STAR walk, rr_nt: NOT_TAKEN, rr_pt/rr_pe,
#   reraise, unwind (COPY 3 / POP_EXCEPT / RERAISE 1)
# The last handler's ewe epilogue (LIST_APPEND 1) folds into x/ce/nm tails;
# non-last ones jump straight to the next handler's match block.
def visit_try_star_except(
    g: cfg_builder,
    t: TryStar,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None,
    ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    tloc = trystar_stmt_loc(t);
    nh = len(t.handlers);
    noloc = no_loc();
    nest = g.handler_nest_depth;

    nop_blk = g.new_block();
    g.u.nested_try_except_end = -1;
    try_body = g.new_block();
    prev_line = -1;
    if len(g.cur.instrs) > 0 {
        prev_line = g.cur.instrs[len(g.cur.instrs) - 1].loc.lineno;
    }
    g.use(nop_blk);
    if prev_line != tloc.lineno {
        g.emit_op(OP_NOP, 0, tloc);
    }
    g.use(try_body);
    protect_start = g.cur.id;
    try_follows = more_code_follows;
    if not try_follows and tail is not None and tail_idx < len(tail) {
        try_follows = True;
    }
    body_cont = visit_stmts(g, t.body, 0, try_follows, tail, tail_idx, tail_join, ann_ctx);
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    protect_end = g.new_block();
    g.use(protect_end);
    normal_terminated = body_cont.terminated;
    if t.orelse is not None and len(t.orelse) > 0 and not body_cont.terminated {
        else_cont = visit_stmts(g, t.orelse, 0, try_follows, tail, tail_idx, tail_join, ann_ctx);
        if codegen_busy(g) {
            return stmt_cont(loc=tloc);
        }
        if else_cont.terminated {
            normal_terminated = True;
        }
    }
    join_blk: basicblock | None = None;
    if try_follows {
        # Own block so the nothing-to-reraise path can jump back to it.
        join_blk = g.new_block();
        g.use(join_blk);
        tail_more = False;
        if tail is not None and tail_idx + 1 < len(tail) {
            tail_more = exec_tail_emits_code(tail, tail_idx + 1);
        }
        tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more, ann_ctx);
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

    # Deferred structural blocks; first use fixes layout order below the
    # normal-path continuation, matching CPython's label placement.
    he = g.new_deferred_block();
    b_blks: list[basicblock] = [];
    x_blks: list[basicblock] = [];
    ce_blks: list[basicblock] = [];
    nm_blks: list[basicblock] = [];
    match_blks: list[basicblock] = [];
    nt_blks: list[basicblock] = [];
    pre_blks: list[basicblock] = [];
    hi = 0;
    while hi < nh {
        b_blks.append(g.new_deferred_block());
        x_blks.append(g.new_deferred_block());
        ce_blks.append(g.new_deferred_block());
        nm_blks.append(g.new_deferred_block());
        if hi > 0 {
            match_blks.append(g.new_deferred_block());
            nt_blks.append(g.new_deferred_block());
            pre_blks.append(g.new_deferred_block());
        }
        hi = hi + 1;
    }
    rr_match = g.new_deferred_block();
    rr_nt = g.new_deferred_block();
    rr_pt = g.new_deferred_block();
    rr_pe = g.new_deferred_block();
    reraise_blk = g.new_deferred_block();
    unwind_blk = g.new_deferred_block();

    hi = 0;
    while hi < nh {
        h = t.handlers[hi] as ExceptHandler;
        if h.type is None {
            codegen_fail(g, "SyntaxError", "except* requires an exception type");
            return stmt_cont(loc=tloc);
        }
        hi = hi + 1;
    }

    spans: list[except_region] = [];
    spans.append(
        except_region(
            start_block=protect_start,
            end_block=protect_end.id,
            handler_block=he.id,
            stack_depth=1 + nest
        )
    );
    spans.append(
        except_region(
            start_block=he.id,
            end_block=b_blks[0].id,
            handler_block=unwind_blk.id,
            stack_depth=3 + nest,
            preserve_lasti=True
        )
    );

    hloc0 = trystar_handler_loc(t.handlers[0] as ExceptHandler);
    g.use(he);
    g.emit_op(OP_PUSH_EXC_INFO, 0, noloc);
    g.emit_op(OP_BUILD_LIST, 0, hloc0);
    g.emit_op(OP_COPY, 2, hloc0);
    hi = 0;
    while hi < nh {
        h = t.handlers[hi] as ExceptHandler;
        hloc = trystar_handler_loc(h);
        if hi > 0 {
            g.use(match_blks[hi - 1]);
        }
        visit_expr(g, h.type);
        if codegen_busy(g) {
            return stmt_cont(loc=tloc);
        }
        g.emit_op(OP_CHECK_EG_MATCH, 0, hloc);
        g.emit_op(OP_COPY, 1, hloc);
        g.emit_jump(OP_POP_JUMP_IF_NONE, nm_blks[hi].id, hloc);
        if hi > 0 {
            # Standalone NOT_TAKEN keeps normalize_jumps from inlining it into
            # the protected match run (CPython leaves this block uncovered);
            # it carries the handler span like the rest of the match group.
            g.use(nt_blks[hi - 1]);
            g.emit_op(OP_NOT_TAKEN, 0, hloc);
            g.use(pre_blks[hi - 1]);
        }
        if h.name is not None {
            emit_name_store(g, h.name as str, hloc);
        } else {
            g.emit_op(OP_POP_TOP, 0, hloc);
        }
        g.use(b_blks[hi]);
        hbody = visit_stmts(g, h.body, 0, False, None, 0, None, ann_ctx);
        if codegen_busy(g) {
            return stmt_cont(loc=tloc);
        }
        last = hi == nh - 1;
        if len(b_blks[hi].instrs) == 0 and not hbody.terminated {
            # Empty handler body (e.g. `pass`): CPython's inner SETUP_CLEANUP
            # region vanishes and the he/mid spans coalesce into one entry, so
            # collapse b/x into a single block (the deferred x block is never
            # placed).
            x_blks[hi] = b_blks[hi];
        }
        g.use(x_blks[hi]);
        if not hbody.terminated {
            # CPython propagates the body's trailing location into the success
            # epilogue (POP_BLOCK/name-clear/jump chain); the no-match path
            # keeps the handler span.
            if h.name is not None {
                emit_except_as_cleanup(g, h.name as str, hbody.loc);
            }
            if last {
                g.emit_op(OP_LIST_APPEND, 1, hbody.loc);
            }
            if last {
                g.emit_jump(OP_JUMP_FORWARD, rr_match.id, hbody.loc);
            } else {
                g.emit_jump(OP_JUMP_FORWARD, match_blks[hi].id, hbody.loc);
            }
        }
        g.use(ce_blks[hi]);
        if h.name is not None {
            emit_except_as_cleanup(g, h.name as str, noloc);
        }
        g.emit_op(OP_LIST_APPEND, 3, noloc);
        g.emit_op(OP_POP_TOP, 0, noloc);
        if last {
            g.emit_op(OP_LIST_APPEND, 1, noloc);
            g.emit_jump(OP_JUMP_FORWARD, rr_match.id, noloc);
        } else {
            g.emit_jump(OP_JUMP_FORWARD, match_blks[hi].id, noloc);
        }
        g.use(nm_blks[hi]);
        g.emit_op(OP_POP_TOP, 0, hloc);
        if last {
            g.emit_op(OP_LIST_APPEND, 1, hloc);
            # Fall through into the reraise-star walk.
            g.use(rr_match);
        }
        hi = hi + 1;
    }
    # CALL_INTRINSIC_2 oparg 1 = INTRINSIC_PREP_RERAISE_STAR.
    g.emit_op(OP_CALL_INTRINSIC_2, 1, noloc);
    g.emit_op(OP_COPY, 1, noloc);
    g.emit_jump(OP_POP_JUMP_IF_NOT_NONE, reraise_blk.id, noloc);
    g.use(rr_nt);
    g.emit_op(OP_NOT_TAKEN, 0, noloc);
    g.use(rr_pt);
    g.emit_op(OP_POP_TOP, 0, noloc);
    g.use(rr_pe);
    g.emit_op(OP_POP_EXCEPT, 0, noloc);
    if join_blk is not None {
        g.emit_jump(OP_JUMP_BACKWARD_NO_INTERRUPT, join_blk.id, noloc);
    } else {
        emit_module_return(g, noloc);
    }
    g.use(reraise_blk);
    g.emit_op(OP_SWAP, 2, noloc);
    g.emit_op(OP_POP_EXCEPT, 0, noloc);
    g.emit_op(OP_RERAISE, 0, noloc);
    g.use(unwind_blk);
    g.emit_op(OP_COPY, 3, noloc);
    g.emit_op(OP_POP_EXCEPT, 0, noloc);
    g.emit_op(OP_RERAISE, 1, noloc);

    # Exception-table spans, in host entry order; merge_except_spans coalesces
    # the empty-body case where the he span and the mid run become adjacent.
    hi = 0;
    while hi < nh {
        if x_blks[hi].id != b_blks[hi].id {
            spans.append(
                except_region(
                    start_block=b_blks[hi].id,
                    end_block=x_blks[hi].id,
                    handler_block=ce_blks[hi].id,
                    stack_depth=6 + nest,
                    preserve_lasti=True
                )
            );
        }
        if hi < nh - 1 {
            spans.append(
                except_region(
                    start_block=x_blks[hi].id,
                    end_block=nt_blks[hi].id,
                    handler_block=unwind_blk.id,
                    stack_depth=3 + nest,
                    preserve_lasti=True
                )
            );
            spans.append(
                except_region(
                    start_block=pre_blks[hi].id,
                    end_block=b_blks[hi + 1].id,
                    handler_block=unwind_blk.id,
                    stack_depth=3 + nest,
                    preserve_lasti=True
                )
            );
        } else {
            spans.append(
                except_region(
                    start_block=x_blks[hi].id,
                    end_block=rr_nt.id,
                    handler_block=unwind_blk.id,
                    stack_depth=3 + nest,
                    preserve_lasti=True
                )
            );
        }
        hi = hi + 1;
    }
    spans.append(
        except_region(
            start_block=rr_pt.id,
            end_block=rr_pe.id,
            handler_block=unwind_blk.id,
            stack_depth=3 + nest,
            preserve_lasti=True
        )
    );
    merged = merge_except_spans(g, spans);
    mi = 0;
    while mi < len(merged) {
        g.u.except_regions.append(merged[mi]);
        mi = mi + 1;
    }
    return stmt_cont(loc=tloc, terminated=True);
}


# Lower with (single item, optional_vars required).
def visit_with(
    g: cfg_builder,
    w: With,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None,
    ann_ctx: ann_scope_plan | None = None
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
    body_cont = visit_stmts(g, w.body, 0, with_follows, tail, tail_idx, tail_join, ann_ctx);
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
        tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more, ann_ctx);
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
    tail_join: basicblock | None = None,
    ann_ctx: ann_scope_plan | None = None
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
    enter_als = emit_await_send_loop_header(g, OP_GET_AWAITABLE, 1, 3, cloc);
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
    body_cont = visit_stmts(g, w.body, 0, with_follows, tail, tail_idx, tail_join, ann_ctx);
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
    exit_als = emit_await_send_loop_header(g, OP_GET_AWAITABLE, 2, 3, wloc);
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
                tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more, ann_ctx);
                if codegen_busy(g) {
                    return stmt_cont(loc=body_cont.loc);
                }
                if not tail_cont.terminated {
                    emit_module_return(g, tail_cont.loc);
                }
            }
        } else {
            tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more, ann_ctx);
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
        g, exit_als, exit_ct, exit_cj, 3, -1, protect_end.id, enter_cj.id, 2, True
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
