# Match-statement codegen extracted from compiler_codegen.jac.
# Pure mechanical move; see compiler_codegen.jac for the module-initialization
# ordering contract.

import from objects {
    PyInt,
    PyObj,
    PyStr,
    PyTuple,
}
import from opcode_meta {
    CMP_EQ,
    CMP_GE,
    NB_SUBSCR,
    NB_SUBTRACT,
    OP_BINARY_OP,
    OP_BUILD_MAP,
    OP_BUILD_TUPLE,
    OP_COMPARE_OP,
    OP_COPY,
    OP_DELETE_SUBSCR,
    OP_DICT_UPDATE,
    OP_GET_LEN,
    OP_IS_OP,
    OP_JUMP_FORWARD,
    OP_LOAD_CONST,
    OP_LOAD_FAST,
    OP_LOAD_FAST_BORROW,
    OP_MATCH_CLASS,
    OP_MATCH_KEYS,
    OP_MATCH_MAPPING,
    OP_MATCH_SEQUENCE,
    OP_NOP,
    OP_POP_JUMP_IF_FALSE,
    OP_POP_JUMP_IF_NONE,
    OP_POP_JUMP_IF_NOT_NONE,
    OP_POP_TOP,
    OP_STORE_FAST_STORE_FAST,
    OP_SWAP,
    OP_UNPACK_EX,
    OP_UNPACK_SEQUENCE,
    compare_filter_oparg,
    compare_oparg,
}
import from ast_nodes {
    Attribute,
    Constant,
    Match,
    MatchAs,
    MatchClass,
    MatchMapping,
    MatchOr,
    MatchSequence,
    MatchSingleton,
    MatchStar,
    MatchValue,
    Name,
    expr,
    pattern,
    stmt,
}
import from compiler_ir {
    basicblock,
    cfg_builder,
    cloc,
    loc,
    stmt_cont,
}
import from flowgraph { optimize_swap_range }
import from compiler_emit {
    codegen_busy,
    codegen_fail,
    codegen_mangle,
    emit_branch_if_test_false,
    fast_local_index,
    visit_expr,
    visit_test_expr,
}
import from codegen_util {
    exec_tail_emits_code,
    expr_loc,
    match_pattern_loc,
    match_pattern_unwrap_or,
    match_pattern_wildcard,
    nloc,
    stmt_loc,
}
import from compiler_annotations { ann_scope_plan }
import from compiler_codegen { emit_module_return, emit_name_store, visit_stmt_tail, visit_stmts }
obj match_pat_ctx {
    has stores: list[str],
        on_top: int,
        cleanup_blocks: list[basicblock],
        max_cleanup: int,
        allow_irrefutable: bool;
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
    has ctx: match_pat_ctx,
        next_arm: basicblock;
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
    g: cfg_builder, ctx: match_pat_ctx, next_arm: basicblock, jump_op: int, loc: cloc
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
            codegen_fail(g, "SyntaxError", "multiple assignments to name in pattern");
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
    g: cfg_builder, p: pattern, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool {
    allow = ctx.allow_irrefutable;
    ctx.allow_irrefutable = True;
    ok = emit_match_pattern(g, p, ctx, next_arm, ploc);
    ctx.allow_irrefutable = allow;
    return ok;
}


def emit_match_pattern_value(
    g: cfg_builder, mv: MatchValue, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
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
    g: cfg_builder, ma: MatchAs, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
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


def match_star_capture_name(
    patterns: list[pattern], idx: int, star_idx: int
) -> str | None {
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
    g: cfg_builder,
    ms: MatchSequence,
    ctx: match_pat_ctx,
    next_arm: basicblock,
    ploc: cloc
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
                    g, "SyntaxError", "multiple starred names in sequence pattern"
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
    kwd_patterns: list[pattern] = mc.kwd_patterns
        if mc.kwd_patterns is not None
        else [];
    nargs = len(cls_patterns);
    nattrs = len(kwd_attrs);
    if nattrs != len(kwd_patterns) {
        codegen_fail(
            g,
            "SyntaxError",
            "kwd_attrs / kwd_patterns length mismatch in class pattern"
        );
        return False;
    }
    ai = 0;
    while ai < nattrs {
        aj = ai + 1;
        while aj < nattrs {
            if kwd_attrs[ai] == kwd_attrs[aj] {
                codegen_fail(
                    g,
                    "SyntaxError",
                    "attribute name repeated in class pattern: " + kwd_attrs[ai]
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
    g: cfg_builder,
    mm: MatchMapping,
    ctx: match_pat_ctx,
    next_arm: basicblock,
    ploc: cloc
) -> bool {
    keys: list[expr] = mm.keys if mm.keys is not None else [];
    patterns: list[pattern] = mm.patterns if mm.patterns is not None else [];
    size = len(keys);
    if size != len(patterns) {
        codegen_fail(
            g, "SyntaxError", "keys / patterns length mismatch in mapping pattern"
        );
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
                    codegen_fail(
                        g, "SyntaxError", "mapping pattern checks duplicate key"
                    );
                    return False;
                }
                si = si + 1;
            }
            seen.append(kv);
        } elif isinstance(key, Attribute) {
            all_const = False;
        } else {
            codegen_fail(
                g,
                "SyntaxError",
                "mapping pattern keys may only match literals and attribute lookups"
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
    g: cfg_builder, mo: MatchOr, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
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
    g: cfg_builder, p: pattern, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
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
        return emit_match_pattern_singleton(
            g, p as MatchSingleton, ctx, next_arm, ploc
        );
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
    tail_join: basicblock | None = None,
    ann_ctx: ann_scope_plan | None = None
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
            guard_kind = visit_test_expr(g, arm.guard, gloc);
            if codegen_busy(g) {
                return stmt_cont(loc=mloc);
            }
            emit_branch_if_test_false(g, guard_kind, next_arm.id, gloc);
        }
        if ci != loop_end - 1 {
            g.emit_op(OP_POP_TOP, 0, ploc);
        }
        body_cont = visit_stmts(g, arm.body, 0, body_follows, tail, tail_idx, join_blk, ann_ctx);
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
            guard_kind = visit_test_expr(g, arm.guard, gloc);
            if codegen_busy(g) {
                return stmt_cont(loc=mloc);
            }
            emit_branch_if_test_false(g, guard_kind, match_end.id, gloc);
        }
        body_cont = visit_stmts(g, arm.body, 0, body_follows, tail, tail_idx, join_blk, ann_ctx);
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
        tail_cont = visit_stmt_tail(g, tail, tail_idx, tail_more, ann_ctx);
        return stmt_cont(
            loc=tail_cont.loc,
            next_si=len(tail),
            terminated=terminated or tail_cont.terminated
        );
    }
    return stmt_cont(loc=mloc, terminated=terminated);
}
