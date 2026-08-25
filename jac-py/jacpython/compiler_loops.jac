# Loop/if control-flow codegen (if, while, for, async for) extracted from
# compiler_codegen.jac. Pure mechanical move; see compiler_codegen.jac for the
# module-initialization ordering contract.

import from opcode_meta {
    OP_END_ASYNC_FOR,
    OP_END_FOR,
    OP_FOR_ITER,
    OP_GET_AITER,
    OP_GET_ITER,
    OP_JUMP_BACKWARD,
    OP_JUMP_FORWARD,
    OP_LOAD_CONST,
    OP_NOP,
    OP_NOT_TAKEN,
    OP_POP_ITER,
    OP_POP_JUMP_IF_FALSE,
    OP_POP_JUMP_IF_TRUE,
    OP_POP_TOP,
    OP_RETURN_VALUE,
    has_target,
    is_scope_exit_opcode,
    is_unconditional_jump_opcode,
}
import from ast_nodes {
    AsyncFor,
    For,
    If,
    While,
    stmt,
}
import from compiler_ir {
    basicblock,
    break_site,
    cfg_builder,
    cloc,
    cinstr,
    except_region,
    loc,
    loop_frame,
    mk_instr,
    no_loc,
    stmt_cont,
}
import from objects { py_none }
import from flowgraph { MAX_COPY_SIZE, copy_cinstr }
import from compiler_emit {
    codegen_busy,
    codegen_fail,
    emit_anext_send_loop_footer,
    emit_anext_send_loop_header,
    emit_branch_if_test_false,
    emit_branch_if_test_true,
    visit_expr,
    visit_test_expr,
}
import from codegen_util {
    exec_tail_emits_code,
    expr_loc,
    loop_body_has_break,
    nloc,
}
import from compiler_annotations { ann_scope_plan }
import from compiler_codegen { emit_module_return, emit_tail_and_finish, visit_stmt_tail, visit_stmts, visit_store_target_tos }
import from compiler_exc { emit_anext_send_except_regions }

# ---------------- break-edge tail duplication (CPython parity) ----------------
#
# CPython lowers `break` as an unwind plus a jump to the loop's exit anchor,
# which sits AFTER orelse (codegen.c codegen_break / codegen_for). Its flowgraph
# optimizer then tail-duplicates that anchor into each break edge when the
# anchor ends up a small scope-exit block (flowgraph.c
# inline_small_exit_blocks, MAX_COPY_SIZE) and prunes the artificial break NOP
# per line-number rules. We emit the post-optimizer shape directly: break sites
# record themselves in the loop frame, the shared continuation block is built
# once, then finish_break_sites copies it over each break jump when CPython
# would have.

# A loop compiled with a None tail (nested-loop context) cannot finish its
# break sites inline: its shared continuation is appended to by the CALLER
# after this visitor returns (the enclosing loop's back edge, following
# statements, or the driver epilogue). Those loops record a finish job; the
# enclosing visitor flushes the queue once the continuation block can receive
# no further instructions. Flushing drives the SAME finish_break_sites
# mechanism as the synchronous tail-present path -- there is one splicer, and
# deferral only changes WHEN it observes the finalized continuation.
obj pending_break_finish {
    has frame: loop_frame,
        join: basicblock,
        allow_nop: bool,
        # While-family nested loops only: the conditional that guards the loop
        # body targets the continuation as its FALSE edge. When the finalized
        # continuation turns out artificial, CPython's passes thread that edge
        # through it (conditional reversal): jump-true to the body, with a
        # copy of the continuation inlined after the test.
        test_blk: basicblock | None = None,
        branch_idx: int = -1,
        body_hdr: basicblock | None = None;
}

glob pending_break_finishes: list[pending_break_finish] = [];

def push_pending_break_finish(frame: loop_frame, join: basicblock, allow_nop: bool) {
    pending_break_finishes.append(
        pending_break_finish(frame=frame, join=join, allow_nop=allow_nop)
    );
}

# Does control fall out of the block (CPython BB_HAS_FALLTHROUGH)?
def block_is_terminated(b: basicblock) -> bool {
    n = len(b.instrs);
    if n == 0 {
        return False;
    }
    op = b.instrs[n - 1].opcode;
    return is_unconditional_jump_opcode(op) or is_scope_exit_opcode(op);
}

# Finish every job recorded since `from_idx`. Called only at points where all
# continuation blocks touched by those jobs are final: right after the owning
# visitor emitted its own trailing instructions (back edge) into the current
# block. Jobs are consumed even when neither inline predicate fires -- keeping
# the plain jump then matches CPython, whose pass simply does not rewrite.
def flush_pending_break_finishes(g: cfg_builder, from_idx: int) {
    while from_idx < len(pending_break_finishes) {
        job = pending_break_finishes[from_idx];
        pending_break_finishes.pop(from_idx);
        if not block_is_terminated(job.join) {
            # Falling-through continuations are finalized by the unit drivers
            # (epilogue synthesis needs tail context this lane does not have);
            # leaving the plain jump matches today's verified shapes.
            continue;
        }
        finish_break_sites(g, job.frame, job.join, no_loc(), True, job.allow_nop);
        if job.test_blk is not None and job.branch_idx >= 0
            and job.body_hdr is not None
            and join_artificial_tail(job.join) {
            # Thread the test's false edge through the artificial anchor
            # exactly as CPython's optimizer does: reverse the conditional
            # onto the body and inline the anchor copy after the test (the
            # NOT_TAKEN after the forward conditional is added later).
            br = job.test_blk.instrs[job.branch_idx];
            if br.opcode == OP_POP_JUMP_IF_FALSE {
                br.opcode = OP_POP_JUMP_IF_TRUE;
                hdr = job.body_hdr as basicblock;
                br.target_block = hdr.id;
                ci = 0;
                while ci < len(job.join.instrs) {
                    job.test_blk.instrs.append(copy_cinstr(job.join.instrs[ci]));
                    ci = ci + 1;
                }
            }
        }
    }
}

# Mirror inline_small_exit_blocks' target test for the continuation block.
# The driver-appended unit epilogue (LOAD_CONST None; RETURN_VALUE) counts
# toward MAX_COPY_SIZE when the tail itself falls through.
def join_inlinable(join: basicblock, tail_terminated: bool) -> bool {
    count = len(join.instrs);
    if not tail_terminated {
        count = count + 2;
    } else {
        if count == 0 {
            return False;
        }
        if not is_scope_exit_opcode(join.instrs[count - 1].opcode) {
            return False;
        }
    }
    if count > MAX_COPY_SIZE {
        return False;
    }
    ii = 0;
    while ii < len(join.instrs) {
        if has_target(join.instrs[ii].opcode) {
            # A branch inside the continuation means CPython's block would have
            # been split before the scope exit; no duplication happened there.
            return False;
        }
        ii = ii + 1;
    }
    return True;
}

# Mirror inline_small_or_no_lineno_blocks' second target test (flowgraph.c):
# a continuation consisting solely of artificial (line-less) instructions that
# does not fall through is appended to every jumping predecessor regardless of
# size -- this is the shape nested-loop continuations take (the enclosing loop's
# back edge, END_FOR/POP_ITER cleanups). No MAX_COPY_SIZE cap applies there.
def join_artificial_tail(join: basicblock) -> bool {
    n = len(join.instrs);
    if n == 0 {
        return False;
    }
    if not block_is_terminated(join) {
        return False;
    }
    ii = 0;
    while ii < n {
        if join.instrs[ii].loc.lineno >= 0 {
            return False;
        }
        ii = ii + 1;
    }
    return True;
}

# Would CPython's remove_redundant_nops keep the artificial NOP emitted before
# a break jump that was tail-duplicated? It survives only when it differs in
# line from both its predecessor and the first copied instruction.
def break_nop_kept(site: break_site, first_copy_loc: cloc) -> bool {
    if site.loc.lineno < 0 {
        return False;
    }
    instrs = site.blk.instrs;
    if site.instr_idx > 0
        and instrs[site.instr_idx - 1].loc.lineno == site.loc.lineno {
        return False;
    }
    if first_copy_loc.lineno == site.loc.lineno or first_copy_loc.lineno < 0 {
        return False;
    }
    return True;
}

def finish_break_sites(
    g: cfg_builder,
    frame: loop_frame,
    join: basicblock,
    tail_loc: cloc,
    tail_terminated: bool,
    allow_nop: bool
) {
    # CPython tries the small scope-exit copy first, then the artificial
    # no-lineno copy (optimize_cfg runs inline_small_or_no_lineno_blocks).
    copies: list[cinstr] | None = None;
    if join_inlinable(join, tail_terminated) {
        copies = [];
        ci = 0;
        while ci < len(join.instrs) {
            copies.append(copy_cinstr(join.instrs[ci]));
            ci = ci + 1;
        }
        if not tail_terminated {
            none_idx = g.u.add_const(py_none());
            copies.append(mk_instr(OP_LOAD_CONST, none_idx, tail_loc));
            copies.append(mk_instr(OP_RETURN_VALUE, 0, tail_loc));
        }
    } elif join_artificial_tail(join) {
        copies = [];
        ci = 0;
        while ci < len(join.instrs) {
            copies.append(copy_cinstr(join.instrs[ci]));
            ci = ci + 1;
        }
    }
    if copies is None or len(copies) == 0 {
        return;
    }
    # Exit-per-block invariant (mirrors CPython flowgraph.c structure):
    # cfg_builder_maybe_start_new_block starts a fresh block after any
    # terminator, so a jump is always the LAST instruction of its block and
    # inline_small_or_no_lineno_blocks only ever rewrites
    # basicblock_last_instr -- one exit per block, structurally. Our break
    # sites record the index of their jump, which is last-instruction at
    # record time and stays last because visit_stmts halts at the
    # unconditional terminator. Several sites may still share a block; the
    # splice below therefore runs in DESCENDING index order, which keeps
    # lower indices valid while higher ones are rewritten. Enforce both
    # properties loudly instead of trusting callers.
    prev_blk_id = -1;
    prev_idx = -1;
    si = len(frame.break_sites) - 1;
    while si >= 0 {
        site = frame.break_sites[si];
        if site.instr_idx < 0 or site.instr_idx >= len(site.blk.instrs) {
            codegen_fail(
                g,
                "SystemError",
                "break site index out of range in finish_break_sites"
            );
            return;
        }
        if not is_unconditional_jump_opcode(site.blk.instrs[site.instr_idx].opcode) {
            codegen_fail(
                g,
                "SystemError",
                "break site does not point at its recorded jump"
            );
            return;
        }
        if site.blk.id == prev_blk_id and site.instr_idx >= prev_idx {
            # Same block as the site spliced just before us (higher index);
            # ours must sit strictly below it or the rebuild above would
            # drop instructions between the two exits.
            codegen_fail(
                g,
                "SystemError",
                "break sites in one block not in descending order"
            );
            return;
        }
        prev_blk_id = site.blk.id;
        prev_idx = site.instr_idx;
        si = si - 1;
    }
    first_loc = copies[0].loc;
    si = len(frame.break_sites) - 1;
    while si >= 0 {
        site = frame.break_sites[si];
        old = site.blk.instrs;
        new_instrs: list[cinstr] = old[0:site.instr_idx];
        ci = 0;
        while ci < len(copies) {
            new_instrs.append(copy_cinstr(copies[ci]));
            ci = ci + 1;
        }
        ki = site.instr_idx + 1;
        while ki < len(old) {
            new_instrs.append(old[ki]);
            ki = ki + 1;
        }
        site.blk.instrs = new_instrs;
        if allow_nop and break_nop_kept(site, first_loc) {
            new_instrs.insert(site.instr_idx, mk_instr(OP_NOP, 0, site.loc));
        }
        si = si - 1;
    }
}
def visit_if(
    g: cfg_builder,
    i: If,
    more_code_follows: bool,
    tail: list[stmt],
    tail_idx: int,
    tail_join: basicblock | None = None,
    ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    iloc = nloc(i.lineno, i.end_lineno, i.col_offset, i.end_col_offset);
    test_loc = expr_loc(i.`test);
    kind = visit_test_expr(g, i.`test, test_loc, True);
    if codegen_busy(g) {
        return stmt_cont(loc=iloc);
    }
    false_blk = g.new_block();
    has_else = len(i.orelse) > 0;
    if more_code_follows {
        # tail is None in loop-body contexts: the continuation is the enclosing
        # loop's back edge, not a statement suffix to duplicate or consume.
        tail_more = tail is not None and exec_tail_emits_code(tail, tail_idx);
        if has_else {
            if tail_more {
                join = g.new_block();
                emit_branch_if_test_false(g, kind, false_blk.id, test_loc);
                body_cont = visit_stmts(g, i.body, 0, False, tail, tail_idx, None, ann_ctx);
                if codegen_busy(g) {
                    return stmt_cont(loc=body_cont.loc);
                }
                if not body_cont.terminated {
                    g.emit_jump(OP_JUMP_FORWARD, join.id, iloc);
                }
                g.use(false_blk);
                else_cont = visit_stmts(g, i.orelse, 0, False, tail, tail_idx, None, ann_ctx);
                if codegen_busy(g) {
                    return stmt_cont(loc=else_cont.loc);
                }
                g.use(join);
                tail_cont = visit_stmt_tail(
                    g, tail, tail_idx, exec_tail_emits_code(tail, tail_idx + 1), ann_ctx);
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
            body_cont = visit_stmts(g, i.body, 0, False, tail, tail_idx, None, ann_ctx);
            if codegen_busy(g) {
                return stmt_cont(loc=body_cont.loc);
            }
            if not body_cont.terminated {
                g.emit_jump(OP_JUMP_FORWARD, join.id, iloc);
            }
            g.use(false_blk);
            else_cont = visit_stmts(g, i.orelse, 0, False, tail, tail_idx, None, ann_ctx);
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
        body_cont = visit_stmts(g, i.body, 0, False, tail, tail_idx, join, ann_ctx);
        if codegen_busy(g) {
            return stmt_cont(loc=body_cont.loc);
        }
        if owns_tail {
            g.use(join);
            if tail_more {
                tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more, ann_ctx);
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
        body_cont = visit_stmts(g, i.body, 0, False, None, 0, None, ann_ctx);
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
            else_cont = visit_stmts(g, i.orelse, 0, False, None, 0, None, ann_ctx);
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
    body_cont = visit_stmts(g, i.body, 0, False, None, 0, None, ann_ctx);
    if codegen_busy(g) {
        return stmt_cont(loc=body_cont.loc);
    }
    if not body_cont.terminated {
        emit_module_return(g, body_cont.loc);
    }
    g.use(false_blk);
    if has_else {
        else_cont = visit_stmts(g, i.orelse, 0, False, None, 0, None, ann_ctx);
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
    g: cfg_builder,
    w: While,
    more_code_follows: bool,
    tail: list[stmt],
    tail_idx: int,
    ann_ctx: ann_scope_plan | None = None
) -> stmt_cont {
    wloc = nloc(w.lineno, w.end_lineno, w.col_offset, w.end_col_offset);
    test_loc = expr_loc(w.`test);
    head = g.new_block();
    g.use(head);
    kind = visit_test_expr(g, w.`test, test_loc, True);
    if codegen_busy(g) {
        return stmt_cont(loc=wloc);
    }
    has_break = loop_body_has_break(w.body);
    if more_code_follows {
        # Deferred: placed at first use AFTER the body is visited. Eager
        # placement would fix these blocks' layout position ahead of blocks
        # allocated while visiting the body (if/loop fragments), so the
        # join's fall-through and break-site splices would land inside body
        # code (infinite loops) instead of the post-loop continuation.
        exit_blk = g.new_deferred_block();
        # Break edges target the shared continuation AFTER orelse (CPython's
        # `end` label): break must skip the else clause.
        if has_break {
            join = g.new_deferred_block();
            g.push_loop(head, join, True);
            break_frame = g.current_loop();
        } else {
            g.push_loop(head, exit_blk, False);
        }
        emit_branch_if_test_false(g, kind, exit_blk.id, test_loc);
        body_snap = len(pending_break_finishes);
        body_cont = visit_stmts(g, w.body, 0, False, None, 0, None, ann_ctx);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=body_cont.loc);
        }
        if not body_cont.terminated {
            g.emit_jump(OP_JUMP_BACKWARD, head.id, body_cont.loc);
        }
        g.pop_loop();
        # The back edge above is the last write into any nested loop's
        # continuation; finish its deferred break sites now.
        flush_pending_break_finishes(g, body_snap);
        tail_more = tail is not None and exec_tail_emits_code(tail, tail_idx);
        g.use(exit_blk);
        else_terminated = False;
        if len(w.orelse) > 0 {
            else_snap = len(pending_break_finishes);
            else_cont = visit_stmts(g, w.orelse, 0, False, None, 0, None, ann_ctx);
            if codegen_busy(g) {
                return stmt_cont(loc=else_cont.loc);
            }
            flush_pending_break_finishes(g, else_snap);
            else_terminated = else_cont.terminated;
        }
        if else_terminated and not has_break {
            # Normal loop exit runs the else, which terminates; with no break
            # there is no path to the trailing statements, so they are
            # unreachable. CPython drops them (DCE); emitting them here would be
            # dead code after a terminator ("Invalid CFG").
            return stmt_cont(loc=wloc, next_si=len(tail), terminated=True);
        }
        if not has_break {
            if tail is None {
                # Nested-loop context: the caller emits the continuation into
                # the current block.
                return stmt_cont(loc=wloc);
            }
            tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more, ann_ctx);
            return stmt_cont(
                loc=tail_cont.loc, next_si=len(tail), terminated=tail_cont.terminated
            );
        }
        g.use(join);
        if tail is None {
            # Nested-loop context: the caller appends the continuation into
            # `join` after this returns. Defer finishing until the enclosing
            # visitor finalizes the block.
            push_pending_break_finish(break_frame, join, True);
            return stmt_cont(loc=wloc);
        }
        tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more, ann_ctx);
        if codegen_busy(g) {
            return stmt_cont(loc=tail_cont.loc);
        }
        # WHILE-loop unwind emits nothing before the jump, but CPython's
        # artificial break NOP survives tail duplication when its line differs
        # from the copied continuation's first line.
        finish_break_sites(
            g,
            break_frame,
            join,
            tail_cont.loc,
            tail_cont.terminated,
            True
        );
        return stmt_cont(
            loc=tail_cont.loc, next_si=len(tail), terminated=tail_cont.terminated
        );
    }
    if len(g.loop_stack) > 0 {
        # CPython lowers a nested trailing loop with its anchor as a shared
        # continuation: the enclosing loop's back edge is appended into it
        # once this visitor returns, and the optimizer threads BOTH the break
        # edges AND the test's false edge through that artificial block
        # (conditional reversal: jump-true to the body, continuation copy
        # inlined after the test; normalize_jumps adds NOT_TAKEN). body_hdr
        # reserves the body-start position the reversed conditional targets;
        # it stays an unreferenced (zero-byte) boundary when the continuation
        # ends up line-bearing and no threading happens.
        parent = g.current_loop();
        body_hdr = g.new_block();
        after_body = g.new_deferred_block();
        emit_branch_if_test_false(g, kind, after_body.id, test_loc);
        test_blk = g.cur;
        branch_idx = len(g.cur.instrs) - 1;
        if has_break {
            g.push_loop(head, after_body, True);
            break_frame = g.current_loop();
        } else {
            g.push_loop(head, after_body, False);
        }
        body_snap = len(pending_break_finishes);
        g.use(body_hdr);
        body_cont = visit_stmts(g, w.body, 0, False, None, 0, None, ann_ctx);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=body_cont.loc);
        }
        if not body_cont.terminated {
            # Artificial like CPython's NO_LOCATION back edge: the copied jump
            # on each break edge must carry no line, and the all-artificial
            # predicate below keys off it.
            g.emit_jump(OP_JUMP_BACKWARD, head.id, no_loc());
        }
        g.pop_loop();
        flush_pending_break_finishes(g, body_snap);
        if has_break and parent is not None {
            # Our own continuation gains the caller's back edge after we
            # return; defer like the tail-is-None path above.
            job = pending_break_finish(
                frame=break_frame,
                join=after_body,
                allow_nop=True,
                test_blk=test_blk,
                branch_idx=branch_idx,
                body_hdr=body_hdr
            );
            pending_break_finishes.append(job);
        }
        g.use(after_body);
        return stmt_cont(loc=wloc, terminated=False);
    }
    emit_branch_if_test_false(g, kind, 0, test_loc);
    pop_false_ins = g.cur.instrs[len(g.cur.instrs) - 1];
    g.push_loop(head, head, False);
    body_snap = len(pending_break_finishes);
    body_cont = visit_stmts(g, w.body, 0, False, None, 0, None, ann_ctx);
    if codegen_busy(g) {
        g.pop_loop();
        return stmt_cont(loc=body_cont.loc);
    }
    if not body_cont.terminated {
        g.emit_jump(OP_JUMP_BACKWARD, head.id, body_cont.loc);
    }
    g.pop_loop();
    flush_pending_break_finishes(g, body_snap);
    exit_blk = g.new_block();
    pop_false_ins.target_block = exit_blk.id;
    g.use(exit_blk);
    if len(w.orelse) > 0 {
        else_snap = len(pending_break_finishes);
        else_cont = visit_stmts(g, w.orelse, 0, False, None, 0, None, ann_ctx);
        if codegen_busy(g) {
            return stmt_cont(loc=else_cont.loc);
        }
        flush_pending_break_finishes(g, else_snap);
        emit_module_return(g, else_cont.loc);
    } else {
        emit_module_return(g, test_loc);
    }
    return stmt_cont(loc=wloc, terminated=True);
}


def visit_for(
    g: cfg_builder,
    f: For,
    more_code_follows: bool,
    tail: list[stmt],
    tail_idx: int,
    ann_ctx: ann_scope_plan | None = None
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
        # Break edges target the shared continuation AFTER orelse (CPython's
        # `end` label): break must skip the else clause.
        if has_break {
            join = g.new_block();
            g.push_loop(loop_hdr, join, True);
            break_frame = g.current_loop();
            break_frame.pops_iter = True;
        } else {
            g.push_loop(loop_hdr, after, False);
        }
        g.emit_jump(OP_FOR_ITER, after.id, iter_loc);
        store = visit_store_target_tos(g, f.target);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=store.loc);
        }
        body_snap = len(pending_break_finishes);
        body_cont = visit_stmts(g, f.body, 0, False, None, 0, None, ann_ctx);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=body_cont.loc);
        }
        if not body_cont.terminated {
            g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, body_cont.loc);
        }
        g.pop_loop();
        # The back edge above is the last write into any nested loop's
        # continuation; finish its deferred break sites now.
        flush_pending_break_finishes(g, body_snap);
        tail_more = tail is not None and exec_tail_emits_code(tail, tail_idx);
        g.use(after);
        g.emit_op(OP_END_FOR, 0, iter_loc);
        g.emit_op(OP_POP_ITER, 0, iter_loc);
        else_terminated = False;
        if len(f.orelse) > 0 {
            else_snap = len(pending_break_finishes);
            else_cont = visit_stmts(g, f.orelse, 0, False, None, 0, None, ann_ctx);
            if codegen_busy(g) {
                return stmt_cont(loc=else_cont.loc);
            }
            flush_pending_break_finishes(g, else_snap);
            else_terminated = else_cont.terminated;
        }
        if else_terminated and not has_break {
            # Normal loop exit runs the else, which terminates; with no break
            # there is no path to the trailing statements, so they are
            # unreachable. CPython drops them (DCE); emitting them here would be
            # dead code after a terminator ("Invalid CFG").
            return stmt_cont(loc=floc, next_si=len(tail), terminated=True);
        }
        if not has_break {
            if tail is None {
                # Nested-loop context: the caller emits the continuation into
                # the current block.
                return stmt_cont(loc=floc);
            }
            tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more, ann_ctx);
            return stmt_cont(
                loc=tail_cont.loc, next_si=len(tail), terminated=tail_cont.terminated
            );
        }
        g.use(join);
        if tail is None {
            # Nested-loop context: the caller appends the continuation into
            # `join` after this returns. Defer finishing until the enclosing
            # visitor finalizes the block.
            push_pending_break_finish(break_frame, join, False);
            return stmt_cont(loc=floc);
        }
        tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more, ann_ctx);
        if codegen_busy(g) {
            return stmt_cont(loc=tail_cont.loc);
        }
        finish_break_sites(
            g,
            break_frame,
            join,
            tail_cont.loc,
            tail_cont.terminated,
            False
        );
        return stmt_cont(
            loc=tail_cont.loc, next_si=len(tail), terminated=tail_cont.terminated
        );
    }
    if len(g.loop_stack) > 0 {
        # Nested trailing loop: CPython emits the exhaustion target as the
        # END_FOR/POP_ITER cleanup, then continues IN THE SAME BLOCK STREAM into
        # the shared continuation (`end`, USE_LABEL after the cleanup) which
        # receives the enclosing loop's back edge once this visitor returns.
        # Break edges target that continuation; inline_small_or_no_lineno_blocks
        # then copies its artificial content over each break jump.
        after = g.new_deferred_block();
        join = after;
        if has_break {
            join = g.new_deferred_block();
            g.push_loop(loop_hdr, join, True);
            break_frame = g.current_loop();
            break_frame.pops_iter = True;
        } else {
            g.push_loop(loop_hdr, after, False);
        }
        g.emit_jump(OP_FOR_ITER, after.id, iter_loc);
        store = visit_store_target_tos(g, f.target);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=store.loc);
        }
        body_snap = len(pending_break_finishes);
        body_cont = visit_stmts(g, f.body, 0, False, None, 0, None, ann_ctx);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=body_cont.loc);
        }
        if not body_cont.terminated {
            # Artificial like CPython's NO_LOCATION back edge: the copied jump
            # on each break edge must carry no line, and the all-artificial
            # predicate in finish_break_sites keys off it.
            g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, no_loc());
        }
        g.pop_loop();
        flush_pending_break_finishes(g, body_snap);
        g.use(after);
        g.emit_op(OP_END_FOR, 0, iter_loc);
        g.emit_op(OP_POP_ITER, 0, iter_loc);
        if has_break {
            # Our own continuation gains the caller's back edge after we
            # return; defer like the tail-is-None path above.
            push_pending_break_finish(break_frame, join, False);
            g.use(join);
        }
        return stmt_cont(loc=floc);
    }
    # Module/unit-final loop (no enclosing loop, nothing follows): same shared
    # continuation shape as CPython. The unit driver appends its implicit
    # return into the continuation for the natural path; finish_break_sites
    # synthesizes that epilogue over each break edge now.
    after = g.new_deferred_block();
    if has_break {
        join = g.new_deferred_block();
        g.push_loop(loop_hdr, join, True);
        break_frame = g.current_loop();
        break_frame.pops_iter = True;
    } else {
        g.push_loop(loop_hdr, after, False);
        join = after;
    }
    g.emit_jump(OP_FOR_ITER, after.id, iter_loc);
    store = visit_store_target_tos(g, f.target);
    if codegen_busy(g) {
        g.pop_loop();
        return stmt_cont(loc=store.loc);
    }
    body_snap = len(pending_break_finishes);
    body_cont = visit_stmts(g, f.body, 0, False, None, 0, None, ann_ctx);
    if codegen_busy(g) {
        g.pop_loop();
        return stmt_cont(loc=body_cont.loc);
    }
    if not body_cont.terminated {
        g.emit_jump(OP_JUMP_BACKWARD, loop_hdr.id, no_loc());
    }
    g.pop_loop();
    flush_pending_break_finishes(g, body_snap);
    g.use(after);
    g.emit_op(OP_END_FOR, 0, iter_loc);
    g.emit_op(OP_POP_ITER, 0, iter_loc);
    else_terminated = False;
    if len(f.orelse) > 0 {
        else_snap = len(pending_break_finishes);
        else_cont = visit_stmts(g, f.orelse, 0, False, None, 0, None, ann_ctx);
        if codegen_busy(g) {
            return stmt_cont(loc=else_cont.loc);
        }
        flush_pending_break_finishes(g, else_snap);
        else_terminated = else_cont.terminated;
    }
    if has_break {
        g.use(join);
        finish_break_sites(g, break_frame, join, floc, else_terminated, False);
        return stmt_cont(loc=floc, terminated=else_terminated);
    }
    if else_terminated {
        return stmt_cont(loc=floc, terminated=True);
    }
    return stmt_cont(loc=floc, terminated=False);
}


def visit_async_for(
    g: cfg_builder,
    af: AsyncFor,
    more_code_follows: bool,
    tail: list[stmt],
    tail_idx: int,
    ann_ctx: ann_scope_plan | None = None
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
        if has_break {
            # Break sites emit the iterator POP_TOP themselves (CPython unwind).
            af_frame = g.current_loop();
            af_frame.pops_iter = True;
        }
        store = visit_store_target_tos(g, af.target);
        if codegen_busy(g) {
            g.pop_loop();
            return stmt_cont(loc=store.loc);
        }
        body_cont = visit_stmts(g, af.body, 0, False, None, 0, None, ann_ctx);
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
            # The per-site iterator POP_TOP already ran at each break; this
            # convergence block only routes to the continuation.
            g.use(break_tgt);
            if tail_more {
                g.emit_jump(OP_JUMP_FORWARD, after.id, iter_loc);
            } else {
                br_cont = emit_tail_and_finish(g, tail, tail_idx, floc, ann_ctx);
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
            else_cont = visit_stmts(g, af.orelse, 0, False, None, 0, None, ann_ctx);
            if codegen_busy(g) {
                return stmt_cont(loc=else_cont.loc);
            }
        }
        if has_break and not tail_more {
            return stmt_cont(loc=floc, next_si=len(tail), terminated=True);
        }
        tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more, ann_ctx);
        return stmt_cont(
            loc=tail_cont.loc, next_si=len(tail), terminated=tail_cont.terminated
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
    if needs_break_stub {
        # Break sites emit the iterator POP_TOP themselves (CPython unwind).
        af_frame = g.current_loop();
        af_frame.pops_iter = True;
    }
    store = visit_store_target_tos(g, af.target);
    if codegen_busy(g) {
        g.pop_loop();
        return stmt_cont(loc=store.loc);
    }
    body_cont = visit_stmts(g, af.body, 0, False, None, 0, None, ann_ctx);
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
        else_cont = visit_stmts(g, af.orelse, 0, False, None, 0, None, ann_ctx);
        if codegen_busy(g) {
            return stmt_cont(loc=else_cont.loc);
        }
        emit_module_return(g, else_cont.loc);
    } else {
        emit_module_return(g, iter_loc);
    }
    return stmt_cont(loc=floc, terminated=True);
}
