# PEP 649 (CPython 3.14) deferred annotations for MODULE scope.
#
# A module-scope annotated assignment never evaluates the annotation inline.
# The scope gains a cellvar __conditional_annotations__ (a set of annotation
# indices), a synthetic __annotate__(format) code object that builds the
# {name: value} dict on demand, and per-statement SET_ADD registration bytes.
# Function-local AnnAssign stays assignment-only (annotations vanish), and
# class bodies still trap until the __classdict__ closure plumbing lands.
#
# Byte-shape notes pinned against the host oracle (b11_annotations goldens):
#   - Setup bytes sit at scope entry (right after RESUME): optional
#     LOAD_CONST <code>/MAKE_FUNCTION/STORE_NAME __annotate__, then
#     BUILD_SET 0/STORE_NAME __conditional_annotations__. But the __annotate__
#     const/name table slots are only allocated AFTER the whole body has been
#     visited -- the oracle's consts/names order proves CPython defers the
#     resolution, so we patch the two placeholder instructions at end of unit.
#   - The nested __annotate__ code object: flags OPTIMIZED|NEWLOCALS,
#     varnames ['format'] positional-only, consts ['2' dead slot, target
#     names...]; body is a format>2 guard raising NotImplementedError, then
#     BUILD_MAP 0 plus one guarded COPY/STORE_SUBSCR entry per annotation.

import from objects { PyStr, PyInt, py_none, hashkey_equal }
import from opcode_meta {
    OP_RESUME,
    OP_LOAD_FAST,
    OP_LOAD_SMALL_INT,
    OP_LOAD_CONST,
    OP_COMPARE_OP,
    OP_POP_JUMP_IF_FALSE,
    OP_LOAD_COMMON_CONSTANT,
    OP_RAISE_VARARGS,
    OP_BUILD_MAP,
    OP_LOAD_GLOBAL,
    OP_CONTAINS_OP,
    OP_COPY,
    OP_STORE_SUBSCR,
    OP_RETURN_VALUE,
    OP_MAKE_FUNCTION,
    OP_STORE_NAME,
    OP_BUILD_SET,
    OP_SET_ADD,
    OP_POP_TOP,
    OP_LOAD_NAME,
    OP_STORE_FAST,
    OP_STORE_ATTR,
    OP_LOAD_DEREF,
    OP_LOAD_FAST_BORROW,
    OP_LOAD_FROM_DICT_OR_GLOBALS,
    OP_BUILD_TUPLE,
    OP_COPY_FREE_VARS,
    OP_SET_FUNCTION_ATTRIBUTE,
    OP_STORE_DEREF,
    CMP_GT,
    CO_OPTIMIZED,
    CO_NEWLOCALS,
    CO_NESTED,
    compare_oparg,
}
import from ast_nodes {
    stmt,
    expr,
    AnnAssign,
    AugAssign,
    ClassDef,
    Name,
    Attribute,
    Subscript,
    Slice,
    Tuple,
    List,
    Set,
    Dict,
    BinOp,
    UnaryOp,
    BoolOp,
    Compare,
    Call,
    IfExp,
    Starred,
    Constant,
    FormattedValue,
    JoinedStr,
    TemplateStr,
    Interpolation,
    If,
    While,
    For,
    AsyncFor,
    Try,
    With,
    AsyncWith,
    Match,
    ExceptHandler,
    match_case,
    Assign,
    Expr,
    Return,
    Delete,
    Raise,
    Assert,
    Global,
    Nonlocal,
    Import,
    ImportFrom,
    Pass,
    Break,
    Continue,
    FunctionDef,
    AsyncFunctionDef,
    Lambda,
    ListComp,
    SetComp,
    DictComp,
    GeneratorExp,
    Yield,
    YieldFrom,
    Await,
    NamedExpr,
}
import from compiler_ir {
    cloc,
    cinstr,
    cfg_builder,
    unverified_cfg,
    loc,
    new_cfg_builder,
    stmt_cont,
}
import from codegen_util { expr_loc, stmt_loc, nloc, no_loc }
import from compiler_symtable {
    sym_block,
    sym_dict_get,
    SCOPE_GLOBAL_IMPLICIT,
    SYM_USE,
    sym_set_scope,
}
import from flowgraph { verify_cfg }
import from assembler { assemble }
import from compiler_emit {
    visit_expr,
    visit_subscript_index,
    codegen_mangle,
    fast_local_index,
    localsplus_index,
    localsplus_index_u,
    codegen_fail,
    codegen_busy,
}

# One deferred annotation: an annotated name plus its expression, in
# construction order (the index baked into the SET_ADD registration).
obj ann_entry {
    has target: str,
        annotation: expr,
        owner_lineno: int,
        owner_col: int,
        index: int,
        # Full span of the owning AnnAssign (CPython's location for the
        # registration and __annotate__ entry instructions).
        owner_loc: cloc | None = None,
        # True when the AnnAssign sits under control flow (If/While/For/Try/
        # With/Match). Class scopes only membership-check conditional entries
        # inside __annotate__; module scopes check every entry.
        conditional: bool = False;
}

# Per-scope plan shared by the setup emitter, the per-statement visitor, and
# the end-of-unit nested-code builder. load_const_ins / store_name_ins are
# the placeholder instructions whose opargs are patched once the synthesized
# __annotate__ PyCode exists.
obj ann_scope_plan {
    has entries: list[ann_entry] = [],
        any_annotation: bool = False,
        body_first_lineno: int = 1,
        # Full span of the scope's first statement: CPython attributes the
        # annotation setup bytes and the __annotate__ guard/epilogue to it.
        # For class scopes this is the `class` statement's own full span.
        head_loc: cloc | None = None,
        load_const_ins: cinstr | None = None,
        store_name_ins: cinstr | None = None,
        # --- class-scope extension ---------------------------------------
        is_class: bool = False,
        # Qualname of the owning class; the nested fn becomes
        # `<owner>.__annotate__`.
        owner_qualname: str = "",
        # The class itself is nested (defined inside a function): its
        # __annotate__ inherits CO_NESTED.
        nested_class: bool = False,
        # True when at least one entry sits under control flow: only then does
        # the class gain the __conditional_annotations__ cellvar, the closure
        # tuple grows to two cells, and conditional entries get membership
        # checks inside __annotate__.
        any_conditional: bool = False;
}

# --- planning -------------------------------------------------------------

# Deep-collect the module scope's annotated assignments in source order.
# Descends into same-scope control flow (If/While/For/Try/With/Match);
# never enters function/class bodies (they own their scopes).
def collect_ann_plan(body: list[stmt]) -> ann_scope_plan {
    plan = ann_scope_plan();
    if len(body) > 0 {
        plan.body_first_lineno = ann_stmt_span(body[0]).lineno;
        plan.head_loc = ann_stmt_span(body[0]);
    }
    ann_collect_stmts(plan, body);
    return plan;
}

# Same collection for a CLASS body: head/firstlineno derive from the class
# statement itself, and control-flow depth marks per-entry conditionality.
def collect_ann_plan_class(cd: ClassDef, class_qname: str, nested: bool) -> ann_scope_plan {
    plan = ann_scope_plan();
    plan.is_class = True;
    plan.owner_qualname = class_qname;
    plan.nested_class = nested;
    plan.body_first_lineno = cd.lineno;
    plan.head_loc = nloc(cd.lineno, cd.end_lineno, cd.col_offset, cd.end_col_offset);
    ann_collect_stmts(plan, cd.body);
    return plan;
}

def ann_stmt_span(s: stmt) -> cloc {
    # Full source span of a statement. Every concrete stmt subclass carries
    # the four position fields; the shared base does not, so dispatch per type.
    if isinstance(s, Assign) {
        a = s as Assign;
        return nloc(a.lineno, a.end_lineno, a.col_offset, a.end_col_offset);
    }
    if isinstance(s, AugAssign) {
        aa = s as AugAssign;
        return nloc(aa.lineno, aa.end_lineno, aa.col_offset, aa.end_col_offset);
    }
    if isinstance(s, AnnAssign) {
        an2 = s as AnnAssign;
        return nloc(an2.lineno, an2.end_lineno, an2.col_offset, an2.end_col_offset);
    }
    if isinstance(s, Return) {
        r = s as Return;
        return nloc(r.lineno, r.end_lineno, r.col_offset, r.end_col_offset);
    }
    if isinstance(s, Delete) {
        d = s as Delete;
        return nloc(d.lineno, d.end_lineno, d.col_offset, d.end_col_offset);
    }
    if isinstance(s, Expr) {
        x = s as Expr;
        return nloc(x.lineno, x.end_lineno, x.col_offset, x.end_col_offset);
    }
    if isinstance(s, Raise) {
        rr = s as Raise;
        return nloc(rr.lineno, rr.end_lineno, rr.col_offset, rr.end_col_offset);
    }
    if isinstance(s, Assert) {
        asrt = s as Assert;
        return nloc(asrt.lineno, asrt.end_lineno, asrt.col_offset, asrt.end_col_offset);
    }
    if isinstance(s, Import) {
        im = s as Import;
        return nloc(im.lineno, im.end_lineno, im.col_offset, im.end_col_offset);
    }
    if isinstance(s, ImportFrom) {
        imf = s as ImportFrom;
        return nloc(imf.lineno, imf.end_lineno, imf.col_offset, imf.end_col_offset);
    }
    if isinstance(s, Global) {
        gl = s as Global;
        return nloc(gl.lineno, gl.end_lineno, gl.col_offset, gl.end_col_offset);
    }
    if isinstance(s, Nonlocal) {
        nl = s as Nonlocal;
        return nloc(nl.lineno, nl.end_lineno, nl.col_offset, nl.end_col_offset);
    }
    if isinstance(s, Pass) {
        ps = s as Pass;
        return nloc(ps.lineno, ps.end_lineno, ps.col_offset, ps.end_col_offset);
    }
    if isinstance(s, Break) {
        br = s as Break;
        return nloc(br.lineno, br.end_lineno, br.col_offset, br.end_col_offset);
    }
    if isinstance(s, Continue) {
        cn = s as Continue;
        return nloc(cn.lineno, cn.end_lineno, cn.col_offset, cn.end_col_offset);
    }
    if isinstance(s, FunctionDef) {
        fd = s as FunctionDef;
        return nloc(fd.lineno, fd.end_lineno, fd.col_offset, fd.end_col_offset);
    }
    if isinstance(s, AsyncFunctionDef) {
        afd = s as AsyncFunctionDef;
        return nloc(afd.lineno, afd.end_lineno, afd.col_offset, afd.end_col_offset);
    }
    if isinstance(s, ClassDef) {
        cd = s as ClassDef;
        return nloc(cd.lineno, cd.end_lineno, cd.col_offset, cd.end_col_offset);
    }
    if isinstance(s, If) {
        ii = s as If;
        return nloc(ii.lineno, ii.end_lineno, ii.col_offset, ii.end_col_offset);
    }
    if isinstance(s, While) {
        ww = s as While;
        return nloc(ww.lineno, ww.end_lineno, ww.col_offset, ww.end_col_offset);
    }
    if isinstance(s, For) {
        ff = s as For;
        return nloc(ff.lineno, ff.end_lineno, ff.col_offset, ff.end_col_offset);
    }
    if isinstance(s, AsyncFor) {
        af2 = s as AsyncFor;
        return nloc(af2.lineno, af2.end_lineno, af2.col_offset, af2.end_col_offset);
    }
    if isinstance(s, Try) {
        tt = s as Try;
        return nloc(tt.lineno, tt.end_lineno, tt.col_offset, tt.end_col_offset);
    }
    if isinstance(s, With) {
        wwi = s as With;
        return nloc(wwi.lineno, wwi.end_lineno, wwi.col_offset, wwi.end_col_offset);
    }
    if isinstance(s, AsyncWith) {
        awi = s as AsyncWith;
        return nloc(awi.lineno, awi.end_lineno, awi.col_offset, awi.end_col_offset);
    }
    if isinstance(s, Match) {
        mm = s as Match;
        return nloc(mm.lineno, mm.end_lineno, mm.col_offset, mm.end_col_offset);
    }
    return loc(1, 1, 0, 0);
}

def ann_collect_stmts(plan: ann_scope_plan, stmts: list[stmt], cond_depth: int = 0) {
    # Try.orelse/finalbody (and other optional blocks) arrive as None when the
    # source omits them; nothing to collect.
    if stmts is None {
        return;
    }
    si = 0;
    while si < len(stmts) {
        ann_collect_stmt(plan, stmts[si], cond_depth);
        si = si + 1;
    }
}

def ann_collect_stmt(plan: ann_scope_plan, s: stmt, cond_depth: int) {
    if isinstance(s, AnnAssign) {
        an = s as AnnAssign;
        plan.any_annotation = True;
        if isinstance(an.target, Name) {
            n = an.target as Name;
            cond = cond_depth > 0;
            if cond {
                plan.any_conditional = True;
            }
            plan.entries.append(
                ann_entry(
                    target=n.id,
                    annotation=an.annotation,
                    owner_lineno=an.lineno,
                    owner_col=an.col_offset,
                    index=len(plan.entries),
                    owner_loc=nloc(
                        an.lineno, an.end_lineno, an.col_offset, an.end_col_offset
                    ),
                    conditional=cond
                )
            );
        }
        return;
    }
    if isinstance(s, If) {
        i = s as If;
        ann_collect_stmts(plan, i.body, cond_depth + 1);
        ann_collect_stmts(plan, i.orelse, cond_depth + 1);
        return;
    }
    if isinstance(s, While) {
        w = s as While;
        ann_collect_stmts(plan, w.body, cond_depth + 1);
        ann_collect_stmts(plan, w.orelse, cond_depth + 1);
        return;
    }
    if isinstance(s, For) {
        f = s as For;
        ann_collect_stmts(plan, f.body, cond_depth + 1);
        ann_collect_stmts(plan, f.orelse, cond_depth + 1);
        return;
    }
    if isinstance(s, AsyncFor) {
        af = s as AsyncFor;
        ann_collect_stmts(plan, af.body, cond_depth + 1);
        ann_collect_stmts(plan, af.orelse, cond_depth + 1);
        return;
    }
    if isinstance(s, Try) {
        t = s as Try;
        ann_collect_stmts(plan, t.body, cond_depth + 1);
        hi = 0;
        while hi < len(t.handlers) {
            h = t.handlers[hi] as ExceptHandler;
            ann_collect_stmts(plan, h.body, cond_depth + 1);
            hi = hi + 1;
        }
        ann_collect_stmts(plan, t.orelse, cond_depth + 1);
        ann_collect_stmts(plan, t.finalbody, cond_depth + 1);
        return;
    }
    if isinstance(s, With) {
        wi = s as With;
        ann_collect_stmts(plan, wi.body, cond_depth + 1);
        return;
    }
    if isinstance(s, AsyncWith) {
        awi = s as AsyncWith;
        ann_collect_stmts(plan, awi.body, cond_depth + 1);
        return;
    }
    if isinstance(s, Match) {
        m = s as Match;
        ci = 0;
        while ci < len(m.cases) {
            mc = m.cases[ci] as match_case;
            ann_collect_stmts(plan, mc.body, cond_depth + 1);
            ci = ci + 1;
        }
        return;
    }
}

def ann_entry_for(plan: ann_scope_plan, an: AnnAssign) -> ann_entry | None {
    ei = 0;
    while ei < len(plan.entries) {
        e = plan.entries[ei];
        if e.owner_lineno == an.lineno and e.owner_col == an.col_offset {
            return e;
        }
        ei = ei + 1;
    }
    return None;
}

# --- statement lowering ---------------------------------------------------

# Lower one AnnAssign. Scope dispatch:
#  - function locals: assignment side only (PEP 649 drops local annotations);
#  - class bodies: value store plus, for conditional entries only, a SET_ADD
#    registration into the __conditional_annotations__ cellvar. Bare Name
#    targets at the top level emit nothing -- their annotation lives solely
#    in the synthesized __annotate__ (built by finish_class_annotations).
#  - module scope: inline value store, then SET_ADD registration of the
#    annotation index into __conditional_annotations__. Attribute/subscript
#    targets never join the annotation dict -- they keep plain assignment
#    semantics (bare forms evaluate the target object and discard it).
def visit_ann_assign(
    g: cfg_builder, an: AnnAssign, plan: ann_scope_plan | None = None
) -> stmt_cont {
    aloc = stmt_loc(an as stmt);
    if g.sym_top is not None and g.sym_top.block_type == "function" {
        if an.value is None {
            return stmt_cont(loc=aloc);
        }
        visit_expr(g, an.value);
        if codegen_busy(g) {
            return stmt_cont(loc=aloc);
        }
        tloc = ann_store_target_tos(g, an.target);
        return stmt_cont(loc=tloc);
    }
    if g.sym_top is not None and g.sym_top.block_type == "class" {
        if plan is None or not plan.is_class {
            codegen_fail(
                g,
                "SystemError",
                "class-scope annotation without a class annotation plan"
            );
            return stmt_cont(loc=aloc);
        }
        last = aloc;
        if an.value is not None {
            visit_expr(g, an.value);
            if codegen_busy(g) {
                return stmt_cont(loc=aloc);
            }
            last = ann_store_target_tos(g, an.target);
        }
        ent = ann_entry_for(plan, an);
        if ent is not None and ent.conditional {
            rloc = aloc;
            if ent.owner_loc is not None {
                rloc = ent.owner_loc;
            }
            cond_idx = localsplus_index(g, "__conditional_annotations__");
            g.emit_op(OP_LOAD_DEREF, cond_idx, rloc);
            ann_emit_index_int(g, ent.index, rloc);
            g.emit_op(OP_SET_ADD, 1, rloc);
            g.emit_op(OP_POP_TOP, 0, rloc);
            last = rloc;
        }
        return stmt_cont(loc=last);
    }
    if plan is None {
        codegen_fail(
            g,
            "SystemError",
            "module-scope annotation without an annotation plan"
        );
        return stmt_cont(loc=aloc);
    }
    ent = ann_entry_for(plan, an);
    if ent is None {
        if an.value is None {
            tvloc = ann_target_value_loc(an);
            visit_expr(g, ann_target_value(an));
            g.emit_op(OP_POP_TOP, 0, tvloc);
            return stmt_cont(loc=tvloc);
        }
        visit_expr(g, an.value);
        if codegen_busy(g) {
            return stmt_cont(loc=aloc);
        }
        tloc = ann_store_target_tos(g, an.target);
        return stmt_cont(loc=tloc);
    }
    last = aloc;
    if an.value is not None {
        visit_expr(g, an.value);
        if codegen_busy(g) {
            return stmt_cont(loc=aloc);
        }
        last = ann_store_target_tos(g, an.target);
    }
    rloc = aloc;
    if ent.owner_loc is not None {
        rloc = ent.owner_loc;
    }
    cond_idx = g.u.add_name("__conditional_annotations__");
    g.emit_op(OP_LOAD_NAME, cond_idx, rloc);
    ann_emit_index_int(g, ent.index, rloc);
    g.emit_op(OP_SET_ADD, 1, rloc);
    g.emit_op(OP_POP_TOP, 0, rloc);
    last = rloc;
    return stmt_cont(loc=last);
}

def ann_store_target_tos(g: cfg_builder, t: expr) -> cloc {
    if isinstance(t, Name) {
        n = t as Name;
        tloc = expr_loc(n);
        name = codegen_mangle(g, n.id);
        fi = fast_local_index(g, name);
        if fi >= 0 {
            g.emit_op(OP_STORE_FAST, fi, tloc);
            return tloc;
        }
        idx = g.u.add_name(name);
        g.emit_op(OP_STORE_NAME, idx, tloc);
        return tloc;
    }
    if isinstance(t, Attribute) {
        a = t as Attribute;
        visit_expr(g, a.value);
        idx = g.u.add_name(codegen_mangle(g, a.attr));
        tloc = expr_loc(a);
        g.emit_op(OP_STORE_ATTR, idx, tloc);
        return tloc;
    }
    if isinstance(t, Subscript) {
        su = t as Subscript;
        if isinstance(su.slice, Slice) {
            codegen_fail(
                g,
                "NotImplementedError",
                "slice-subscript annotated-assignment target not supported"
            );
            return expr_loc(su);
        }
        sloc = expr_loc(su);
        visit_expr(g, su.value);
        visit_subscript_index(g, su.slice, sloc);
        g.emit_op(OP_STORE_SUBSCR, 0, sloc);
        return sloc;
    }
    codegen_fail(
        g,
        "NotImplementedError",
        "unsupported annotated-assignment target kind"
    );
    return expr_loc(t);
}

def ann_target_value(an: AnnAssign) -> expr {
    if isinstance(an.target, Attribute) {
        return (an.target as Attribute).value;
    }
    return (an.target as Subscript).value;
}

def ann_target_value_loc(an: AnnAssign) -> cloc {
    return expr_loc(ann_target_value(an));
}

# Small-int operand emission with CPython's dead-const rule: the FIRST
# 0..255 literal seen while the const pool is empty keeps a dead pool slot;
# later small ints are pure LOAD_SMALL_INT with no pool entry.
def ann_emit_index_int(g: cfg_builder, v: int, lc: cloc) {
    if v >= 0 and v <= 255 {
        if len(g.u.consts) == 0 {
            g.u.add_const(PyInt(t="int", val=v));
            g.u.dead_small_int_const = True;
        }
        g.emit_op(OP_LOAD_SMALL_INT, v, lc);
        return;
    }
    idx = g.u.add_const(PyInt(t="int", val=v));
    g.emit_op(OP_LOAD_CONST, idx, lc);
}

# --- scope-entry setup and end-of-unit finish ------------------------------

# Emit the scope-entry annotation machinery into the module unit (caller has
# already set u.cellvars and emitted MAKE_CELL + RESUME). The __annotate__
# LOAD_CONST/STORE_NAME placeholders carry oparg 0 until
# finish_module_annotations patches them post-body, mirroring the host's
# deferred const/name slot allocation.
def emit_module_annotation_setup(g: cfg_builder, plan: ann_scope_plan, lc: cloc) {
    if len(plan.entries) > 0 {
        g.emit_op(OP_LOAD_CONST, 0, lc);
        plan.load_const_ins = g.cur.instrs[len(g.cur.instrs) - 1];
        g.emit_op(OP_MAKE_FUNCTION, 0, lc);
        g.emit_op(OP_STORE_NAME, 0, lc);
        plan.store_name_ins = g.cur.instrs[len(g.cur.instrs) - 1];
    }
    if plan.any_annotation {
        g.emit_op(OP_BUILD_SET, 0, lc);
        cond_idx = g.u.add_name("__conditional_annotations__");
        g.emit_op(OP_STORE_NAME, cond_idx, lc);
    }
}

# Build the synthetic __annotate__ code object now that the whole body (and
# its const/name pools) is emitted, then patch the two placeholder opargs.
def finish_module_annotations(g: cfg_builder, plan: ann_scope_plan) {
    lci = plan.load_const_ins;
    if len(plan.entries) == 0 or lci is None {
        return;
    }
    sym = ann_synthetic_sym(plan);
    if sym is None {
        codegen_fail(
            g,
            "NotImplementedError",
            "unsupported construct inside deferred annotation"
        );
        return;
    }
    u_fn = build_annotate_fn_cfg(sym, plan, g.u.filename);
    cfg_fn = verify_cfg(u_fn);
    if cfg_fn.diag is not None {
        g.u.diag = cfg_fn.diag;
        return;
    }
    co = assemble(cfg_fn);
    g.u.nested_code_emitted = True;
    # Insert the code object after all statement-produced consts but before
    # any None the control-flow duplication enqueued mid-loop (host defers
    # the shared return-None to scope finalization, we cannot). Literal-None
    # predecessors remain a documented divergence.
    ci = len(g.u.consts);
    none_key = py_none().tp_hashkey();
    ni2 = 0;
    while ni2 < len(g.u.consts) {
        if hashkey_equal(g.u.consts[ni2].tp_hashkey(), none_key) {
            ci = ni2;
            break;
        }
        ni2 = ni2 + 1;
    }
    bi = 0;
    while bi < len(g.u.blocks) {
        ii2 = 0;
        blk = g.u.blocks[bi];
        while ii2 < len(blk.instrs) {
            ins = blk.instrs[ii2];
            if ins.opcode == OP_LOAD_CONST and ins.oparg >= ci
                and ins != plan.load_const_ins {
                ins.oparg = ins.oparg + 1;
            }
            ii2 = ii2 + 1;
        }
        bi = bi + 1;
    }
    g.u.consts.append(co);
    ri = len(g.u.consts) - 1;
    while ri > ci {
        g.u.consts[ri] = g.u.consts[ri - 1];
        ri = ri - 1;
    }
    g.u.consts[ci] = co;
    ni = g.u.add_name("__annotate__");
    lci.oparg = ci;
    sni = plan.store_name_ins;
    if sni is not None {
        sni.oparg = ni;
    }
}

# Class-scope entry setup: the conditional-annotation set cell (present only
# when at least one entry sits under control flow) is seeded right after the
# prologue's LOAD_LOCALS/STORE_DEREF __classdict__. The caller has already
# appended "__conditional_annotations__" to u.cellvars so MAKE_CELL ran for it.
def emit_class_annotation_setup(g: cfg_builder, plan: ann_scope_plan, lc: cloc) {
    if not plan.any_conditional {
        return;
    }
    g.emit_op(OP_BUILD_SET, 0, lc);
    clp = localsplus_index(g, "__conditional_annotations__");
    g.emit_op(OP_STORE_DEREF, clp, lc);
}

# Build the class's synthetic __annotate__ code object and emit the closure
# block that stores it as __annotate_func__ (LOAD_FAST_BORROW cells,
# BUILD_TUPLE, LOAD_CONST <code>, MAKE_FUNCTION, SET_FUNCTION_ATTRIBUTE 8,
# STORE_NAME). Runs AFTER the body loop but BEFORE the epilogue, so the code
# object's const lands after all statement consts yet before the epilogue's
# ()/None -- matching CPython, which compiles the annotate fn during class
# finalization. Unlike the module path, no placeholder patching is needed:
# appending to the const pool here is already in host order (class bodies
# cannot contain return statements, so no duplicated return-None joins exist).
def finish_class_annotations(g: cfg_builder, plan: ann_scope_plan) {
    if len(plan.entries) == 0 {
        return;
    }
    sym = ann_synthetic_sym(plan);
    if sym is None {
        codegen_fail(
            g,
            "NotImplementedError",
            "unsupported construct inside deferred annotation"
        );
        return;
    }
    u_fn = build_annotate_fn_cfg(sym, plan, g.u.filename, True);
    cfg_fn = verify_cfg(u_fn);
    if cfg_fn.diag is not None {
        g.u.diag = cfg_fn.diag;
        return;
    }
    co = assemble(cfg_fn);
    g.u.nested_code_emitted = True;
    bloc = plan.head_loc;
    if bloc is None {
        bloc = no_loc();
    }
    clp = localsplus_index_u(g.u, "__classdict__");
    g.emit_op(OP_LOAD_FAST_BORROW, clp, bloc);
    nclosure = 1;
    if plan.any_conditional {
        cond_lp = localsplus_index_u(g.u, "__conditional_annotations__");
        g.emit_op(OP_LOAD_FAST_BORROW, cond_lp, bloc);
        nclosure = 2;
    }
    g.emit_op(OP_BUILD_TUPLE, nclosure, bloc);
    ci = g.u.add_const(co);
    g.emit_op(OP_LOAD_CONST, ci, bloc);
    g.emit_op(OP_MAKE_FUNCTION, 0, bloc);
    g.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 8, bloc);
    aidx = g.u.add_name("__annotate_func__");
    g.emit_op(OP_STORE_NAME, aidx, bloc);
}

# --- nested __annotate__ code object ---------------------------------------

# Build the synthetic __annotate__(format) code object. Two modes:
#  - module (default): names resolve global-implicit (LOAD_GLOBAL) and every
#    entry is membership-checked against the conditional-annotation set.
#  - class_mode: freevars are the closure cells (always __classdict__, plus
#    __conditional_annotations__ when any entry is conditional), bare Name
#    loads go through the classdict hook (LOAD_DEREF/__FROM_DICT_OR_GLOBALS),
#    only conditional entries get membership checks, and the qualname is
#    `<owner>.__annotate__`.
def build_annotate_fn_cfg(
    sym: sym_block, plan: ann_scope_plan, filename: str, class_mode: bool = False
) -> unverified_cfg {
    qualname = "__annotate__";
    if class_mode {
        qualname = plan.owner_qualname + ".__annotate__";
    }
    u = unverified_cfg(
        filename=filename,
        name="__annotate__",
        qualname=qualname,
        firstlineno=plan.body_first_lineno
    );
    u.argcount = 1;
    u.posonlyargcount = 1;
    u.flags = CO_OPTIMIZED | CO_NEWLOCALS;
    if class_mode {
        if plan.nested_class {
            u.flags = u.flags | CO_NESTED;
        }
        u.freevars.append("__classdict__");
        if plan.any_conditional {
            u.freevars.append("__conditional_annotations__");
        }
        u.classdict_names = True;
    }
    u.varnames = ["format"];
    hloc = plan.head_loc;
    if hloc is None {
        hloc = no_loc();
    }
    entry_blk = u.add_block();
    g = new_cfg_builder(u, entry_blk, sym);
    ploc = loc(
        plan.body_first_lineno,
        plan.body_first_lineno,
        0,
        0
    );
    if class_mode {
        g.emit_op(OP_COPY_FREE_VARS, len(u.freevars), ploc);
    }
    g.emit_op(OP_RESUME, 0, ploc);
    # format guard: raise NotImplementedError when format > 2 (formats 0 and
    # 1 are the only ones PEP 749 defines today). Guard, BUILD_MAP,
    # STORE_SUBSCR and RETURN_VALUE all carry the scope-head location; only
    # the annotation expression's own instructions carry their spans.
    g.emit_op(OP_LOAD_FAST, 0, hloc);
    ann_emit_index_int(g, 2, hloc);
    g.emit_op(OP_COMPARE_OP, compare_oparg(CMP_GT), hloc);
    after = g.new_block();
    g.emit_jump(OP_POP_JUMP_IF_FALSE, after.id, hloc);
    g.emit_op(OP_LOAD_COMMON_CONSTANT, 1, hloc);
    g.emit_op(OP_RAISE_VARARGS, 1, hloc);
    g.use(after);
    g.emit_op(OP_BUILD_MAP, 0, hloc);
    ei = 0;
    while ei < len(plan.entries) {
        e = plan.entries[ei];
        eloc = e.owner_loc;
        if eloc is None {
            eloc = expr_loc(e.annotation);
        }
        checked = not class_mode or e.conditional;
        nb: basicblock | None = None;
        if checked {
            ann_emit_index_int(g, e.index, eloc);
            if class_mode {
                clp2 = localsplus_index_u(u, "__conditional_annotations__");
                g.emit_op(OP_LOAD_DEREF, clp2, eloc);
            } else {
                cond_idx = u.add_name("__conditional_annotations__");
                g.emit_op(OP_LOAD_GLOBAL, cond_idx << 1, eloc);
            }
            g.emit_op(OP_CONTAINS_OP, 0, eloc);
            nb = g.new_block();
            g.emit_jump(OP_POP_JUMP_IF_FALSE, nb.id, eloc);
        }
        visit_expr(g, e.annotation);
        if codegen_busy(g) {
            return u;
        }
        g.emit_op(OP_COPY, 2, eloc);
        tidx = u.add_const(PyStr(t="str", val=e.target));
        g.emit_op(OP_LOAD_CONST, tidx, eloc);
        g.emit_op(OP_STORE_SUBSCR, 0, hloc);
        if nb is not None {
            g.use(nb);
        }
        ei = ei + 1;
    }
    g.emit_op(OP_RETURN_VALUE, 0, hloc);
    return u;
}

# Every free name in an annotation expression resolves global-implicit inside
# __annotate__. Binding forms (walrus/lambda/comprehensions/yield) would need
# their own scopes or locals -- report them so the unit fails loudly instead
# of emitting silently-wrong bytes.
def ann_synthetic_sym(plan: ann_scope_plan) -> sym_block | None {
    sym = sym_block(
        block_type="function",
        name="__annotate__",
        lineno=plan.body_first_lineno,
        col_offset=0
    );
    ei = 0;
    while ei < len(plan.entries) {
        err = ann_mark_names(sym, plan.entries[ei].annotation);
        if err is not None {
            return None;
        }
        ei = ei + 1;
    }
    return sym;
}

def ann_mark_global(sym: sym_block, name: str) {
    if sym_dict_get(sym.symbols, name, -1) == -1 {
        sym.symbols[name] = sym_set_scope(0, SCOPE_GLOBAL_IMPLICIT) | SYM_USE;
    }
}

# Returns None on success or a trap message for unsupported constructs.
def ann_mark_names(sym: sym_block, e: expr) -> str | None {
    if isinstance(e, Name) {
        ann_mark_global(sym, (e as Name).id);
        return None;
    }
    if isinstance(e, Constant) {
        return None;
    }
    if isinstance(e, Slice) {
        sl = e as Slice;
        if sl.lower is not None {
            return ann_mark_names(sym, sl.lower);
        }
        if sl.upper is not None {
            return ann_mark_names(sym, sl.upper);
        }
        if sl.step is not None {
            return ann_mark_names(sym, sl.step);
        }
        return None;
    }
    if isinstance(e, Attribute) {
        return ann_mark_names(sym, (e as Attribute).value);
    }
    if isinstance(e, Subscript) {
        su = e as Subscript;
        err = ann_mark_names(sym, su.value);
        if err is not None {
            return err;
        }
        return ann_mark_names(sym, su.slice);
    }
    if isinstance(e, Tuple) {
        return ann_mark_elts(sym, (e as Tuple).elts);
    }
    if isinstance(e, List) {
        return ann_mark_elts(sym, (e as List).elts);
    }
    if isinstance(e, Set) {
        se = e as Set;
        return ann_mark_elts(sym, se.elts);
    }
    if isinstance(e, Dict) {
        d = e as Dict;
        err = ann_mark_elts(sym, d.keys);
        if err is not None {
            return err;
        }
        return ann_mark_elts(sym, d.values);
    }
    if isinstance(e, BinOp) {
        b = e as BinOp;
        err = ann_mark_names(sym, b.left);
        if err is not None {
            return err;
        }
        return ann_mark_names(sym, b.right);
    }
    if isinstance(e, UnaryOp) {
        return ann_mark_names(sym, (e as UnaryOp).operand);
    }
    if isinstance(e, BoolOp) {
        return ann_mark_elts(sym, (e as BoolOp).values);
    }
    if isinstance(e, Compare) {
        c = e as Compare;
        err = ann_mark_names(sym, c.left);
        if err is not None {
            return err;
        }
        return ann_mark_elts(sym, c.comparators);
    }
    if isinstance(e, Call) {
        ca = e as Call;
        err = ann_mark_names(sym, ca.func);
        if err is not None {
            return err;
        }
        err = ann_mark_elts(sym, ca.args);
        if err is not None {
            return err;
        }
        ki = 0;
        while ki < len(ca.keywords) {
            err = ann_mark_names(sym, ca.keywords[ki].value);
            if err is not None {
                return err;
            }
            ki = ki + 1;
        }
        return None;
    }
    if isinstance(e, IfExp) {
        ie = e as IfExp;
        err = ann_mark_names(sym, ie.`test);
        if err is not None {
            return err;
        }
        err = ann_mark_names(sym, ie.body);
        if err is not None {
            return err;
        }
        return ann_mark_names(sym, ie.orelse);
    }
    if isinstance(e, Starred) {
        return ann_mark_names(sym, (e as Starred).value);
    }
    if isinstance(e, TemplateStr) {
        ts = e as TemplateStr;
        vi = 0;
        while vi < len(ts.values) {
            err = ann_mark_names(sym, ts.values[vi]);
            if err is not None {
                return err;
            }
            vi = vi + 1;
        }
        return None;
    }
    if isinstance(e, JoinedStr) {
        js = e as JoinedStr;
        vi = 0;
        while vi < len(js.values) {
            err = ann_mark_names(sym, js.values[vi]);
            if err is not None {
                return err;
            }
            vi = vi + 1;
        }
        return None;
    }
    if isinstance(e, Interpolation) {
        ip = e as Interpolation;
        err = ann_mark_names(sym, ip.value);
        if err is not None {
            return err;
        }
        if ip.format_spec is not None {
            return ann_mark_names(sym, ip.format_spec);
        }
        return None;
    }
    if isinstance(e, FormattedValue) {
        fv = e as FormattedValue;
        err = ann_mark_names(sym, fv.value);
        if err is not None {
            return err;
        }
        if fv.format_spec is not None {
            return ann_mark_names(sym, fv.format_spec as expr);
        }
        return None;
    }
    return ann_unsupported_in_annotation(e);
}

def ann_mark_elts(sym: sym_block, elts: list[expr | None]) -> str | None {
    ei = 0;
    while ei < len(elts) {
        elt = elts[ei];
        if elt is not None {
            err = ann_mark_names(sym, elt as expr);
            if err is not None {
                return err;
            }
        }
        ei = ei + 1;
    }
    return None;
}

def ann_unsupported_in_annotation(e: expr) -> str {
    kind = "construct";
    if isinstance(e, Lambda) {
        kind = "lambda";
    } elif isinstance(e, ListComp) {
        kind = "list comprehension";
    } elif isinstance(e, SetComp) {
        kind = "set comprehension";
    } elif isinstance(e, DictComp) {
        kind = "dict comprehension";
    } elif isinstance(e, GeneratorExp) {
        kind = "generator expression";
    } elif isinstance(e, NamedExpr) {
        kind = "named expression";
    } elif isinstance(e, Yield) or isinstance(e, YieldFrom) {
        kind = "yield";
    } elif isinstance(e, Await) {
        kind = "await";
    }
    return "unsupported " + kind + " inside deferred annotation";
}
