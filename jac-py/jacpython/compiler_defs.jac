# Definition and import codegen (class/function defs, import statements)
# extracted from compiler_codegen.jac. Pure mechanical move; see
# compiler_codegen.jac for the module-initialization ordering contract.

import from objects {
    PyCode,
    PyInt,
    PyObj,
    PyStr,
    PyTuple,
    py_none,
}
import from opcode_meta {
    CO_ASYNC_GENERATOR,
    CO_COROUTINE,
    CO_GENERATOR,
    CO_NESTED,
    CO_NEWLOCALS,
    CO_OPTIMIZED,
    CMP_GT,
    OP_CALL,
    OP_CALL_INTRINSIC_1,
    OP_CALL_KW,
    OP_COMPARE_OP,
    OP_BUILD_TUPLE,
    OP_COPY,
    OP_COPY_FREE_VARS,
    OP_IMPORT_FROM,
    OP_IMPORT_NAME,
    OP_LOAD_BUILD_CLASS,
    OP_LOAD_COMMON_CONSTANT,
    OP_LOAD_CONST,
    OP_LOAD_FAST_BORROW,
    OP_LOAD_LOCALS,
    OP_LOAD_NAME,
    OP_MAKE_CELL,
    OP_MAKE_FUNCTION,
    OP_POP_JUMP_IF_FALSE,
    OP_POP_TOP,
    OP_PUSH_NULL,
    OP_RAISE_VARARGS,
    OP_RESUME,
    OP_RETURN_VALUE,
    OP_SET_FUNCTION_ATTRIBUTE,
    OP_LOAD_SMALL_INT,
    OP_STORE_DEREF,
    OP_STORE_FAST,
    OP_STORE_NAME,
    compare_oparg,
}
import from ast_nodes {
    AsyncFunctionDef,
    ClassDef,
    FunctionDef,
    Import,
    ImportFrom,
    Name,
    TypeAlias,
    TypeVar,
    type_param,
    arguments,
    keyword,
    stmt,
}
import from compiler_ir {
    cfg_builder,
    cloc,
    loc,
    new_cfg_builder,
    no_loc,
    stmt_cont,
    unverified_cfg,
}
import from compiler_symtable { sym_block }
import from flowgraph { verify_cfg }
import from assembler { assemble }
import from compiler_emit {
    cellvars_from_sym,
    codegen_busy,
    codegen_fail,
    emit_folded_int,
    emit_function_prologue,
    emit_make_function_with_closure,
    fast_local_index,
    fast_varnames_from_sym,
    freevars_from_sym,
    localsplus_index,
    localsplus_index_u,
    sym_function_child_at,
    visit_expr,
}
import from codegen_util {
    async_function_def_loc,
    class_effective_bases,
    class_effective_keywords,
    exec_tail_emits_code,
    expr_loc,
    function_argcounts,
    function_code_flags,
    function_def_loc,
    import_bind_name,
    nloc,
}
import from compiler_codegen { emit_name_store, visit_stmt }
import from compiler_exc { emit_generator_except_handler, emit_deferred_comp_handlers }
import from compiler_annotations {
    collect_ann_plan_class,
    emit_class_annotation_setup,
    finish_class_annotations
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


# A direct type alias in the body closes over __classdict__, forcing the
# classdict cell even with no functions/annotations present.
def class_body_has_typealias(cd: ClassDef) -> bool {
    bi = 0;
    while bi < len(cd.body) {
        if isinstance(cd.body[bi], TypeAlias) {
            return True;
        }
        bi = bi + 1;
    }
    return False;
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


# Class-body prologue locations (CPython 3.14): MAKE_CELL carries NO_LOCATION;
# RESUME points at the class statement line (def-line form, like nested scopes).
# CPython spans for `class` statements run through the last body statement
# (same parser-end_tok overshoot as function_def_loc, see codegen_util).
def class_def_loc(cd: ClassDef) -> cloc {
    last = cd.body[len(cd.body) - 1];
    end_ln = last.lineno;
    end_col = last.col_offset;
    if last.end_lineno is not None {
        end_ln = last.end_lineno;
    }
    if last.end_col_offset is not None {
        end_col = last.end_col_offset;
    }
    return loc(cd.lineno, end_ln, cd.col_offset, end_col);
}


def emit_class_body_prologue(g: cfg_builder, class_qname: str, body_firstlineno: int) {
    # CPython 3.14 locations: MAKE_CELL carries NO_LOCATION; RESUME and the
    # __name__/__module__/__qualname__ boilerplate all sit on the scope's
    # first line (the first decorator's line for a decorated class) with
    # zero-width columns. CPython spans for `class` statements run through
    # the last body statement (same parser-end_tok overshoot as
    # function_def_loc, see codegen_util).
    cloc = loc(body_firstlineno, body_firstlineno, 0, 0);
    noloc = no_loc();
    # CPython order: COPY_FREE_VARS (class-body free vars) precedes MAKE_CELLs.
    if len(g.u.freevars) > 0 {
        g.emit_op(OP_COPY_FREE_VARS, len(g.u.freevars), noloc);
    }
    if len(g.u.cellvars) > 0 {
        ci = 0;
        while ci < len(g.u.cellvars) {
            lp = localsplus_index_u(g.u, g.u.cellvars[ci]);
            g.emit_op(OP_MAKE_CELL, lp, noloc);
            ci = ci + 1;
        }
    }
    g.emit_op(OP_RESUME, 0, cloc);
    nidx = g.u.add_name("__name__");
    g.emit_op(OP_LOAD_NAME, nidx, cloc);
    midx = g.u.add_name("__module__");
    g.emit_op(OP_STORE_NAME, midx, cloc);
    qidx = g.u.add_const(PyStr(t="str", val=class_qname));
    g.emit_op(OP_LOAD_CONST, qidx, cloc);
    qnidx = g.u.add_name("__qualname__");
    g.emit_op(OP_STORE_NAME, qnidx, cloc);
    emit_folded_int(g, body_firstlineno, cloc);
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
    # Module-level LOAD_BUILD_CLASS sequence rows carry the full class span
    # (through the last body statement), matching CPython's LOC(cls).
    cloc = class_def_loc(cd);
    if g.sym_top is None {
        codegen_fail(g, "SystemError", "class definition without symtable");
        return stmt_cont(loc=cloc);
    }
    sym_cls = sym_class_child(g.sym_top, cd.name);
    if sym_cls is None {
        codegen_fail(g, "SystemError", "missing symtable for class " + cd.name);
        return stmt_cont(loc=cloc);
    }
    decorators = cd.decorator_list;
    if decorators is None {
        decorators = [];
    }
    # CPython codegen_class: decorator expressions evaluate in the ENCLOSING
    # scope, left-to-right, before the class body is compiled -- their
    # names/consts therefore precede the body's in both tables.
    di = 0;
    while di < len(decorators) {
        visit_expr(g, decorators[di], False, False);
        if codegen_busy(g) {
            return stmt_cont(loc=cloc);
        }
        di = di + 1;
    }
    u_cls = compile_class_cfg(
        cd, g.u.filename, sym_cls, g.private,
        decorators[0].lineno if len(decorators) > 0 else None
    );
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
    # Class body free vars: push the enclosing scope's cells as the closure
    # tuple (LOAD_FAST_BORROW on a cell slot yields the cell itself), then
    # attach it with SET_FUNCTION_ATTRIBUTE(closure).
    cls_free = freevars_from_sym(sym_cls);
    if len(cls_free) > 0 {
        fi = 0;
        while fi < len(cls_free) {
            lp = localsplus_index(g, cls_free[fi]);
            g.emit_op(OP_LOAD_FAST_BORROW, lp, cloc);
            fi = fi + 1;
        }
        g.emit_op(OP_BUILD_TUPLE, len(cls_free), cloc);
    }
    cidx = g.u.add_const(co);
    g.emit_op(OP_LOAD_CONST, cidx, cloc);
    g.emit_op(OP_MAKE_FUNCTION, 0, cloc);
    if len(cls_free) > 0 {
        g.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 8, cloc);
    }
    name_idx = g.u.add_const(PyStr(t="str", val=cd.name));
    g.emit_op(OP_LOAD_CONST, name_idx, cloc);
    emit_class_build_call(g, cd, cloc);
    if codegen_busy(g) {
        return stmt_cont(loc=cloc);
    }
    # Apply decorators outermost-last: CALL 0 per decorator, right-to-left
    # through decorator_list, each row carrying that decorator's span
    # (CPython codegen_apply_decorators).
    ri = len(decorators) - 1;
    while ri >= 0 {
        dec = decorators[ri];
        g.emit_op(OP_CALL, 0, expr_loc(dec));
        ri = ri - 1;
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
    enclosing_private: str | None = None,
    body_firstlineno: int | None = None
) -> unverified_cfg {
    # CPython codegen_class scopes the class body at the first decorator's
    # line when decorated (drives co_firstlineno, RESUME/boilerplate rows,
    # and __firstlineno__); otherwise the `class` line.
    if body_firstlineno is None {
        body_firstlineno = cd.lineno;
    }
    class_qname = sym_class_qualname(cd, sym_cls, enclosing_private);
    u = unverified_cfg(
        filename=filename, name=cd.name, qualname=class_qname,
        firstlineno=body_firstlineno
    );
    if sym_cls.nested {
        u.flags = CO_NESTED;
    }
    ann_plan = collect_ann_plan_class(cd, class_qname, sym_cls.nested);
    # Class bodies are transparent closure scopes: free vars captured by
    # methods (or direct body references to enclosing function cells) must
    # survive into the class-body code object so method creation inside the
    # body can close over those cells.
    u.freevars = freevars_from_sym(sym_cls);
    if class_body_has_function(cd) or ann_plan.any_annotation
        or class_body_has_typealias(cd) {
        u.cellvars = ["__classdict__"];
        if ann_plan.any_conditional {
            u.cellvars.append("__conditional_annotations__");
        }
    }
    entry_blk = u.add_block();
    g = new_cfg_builder(u, entry_blk, sym_cls, cd.name);
    emit_class_body_prologue(g, class_qname, body_firstlineno);
    emit_class_annotation_setup(g, ann_plan, nloc(cd.lineno, cd.end_lineno,
        cd.col_offset, cd.end_col_offset));
    last = loc(0, cd.lineno, 0, 0);
    bi = 0;
    while bi < len(cd.body) {
        s = cd.body[bi];
        cont = visit_stmt(
            g, s, exec_tail_emits_code(cd.body, bi + 1), cd.body, bi + 1,
            None, ann_plan
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
    finish_class_annotations(g, ann_plan);
    if codegen_busy(g) {
        return u;
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
        fd.name, fd.args, fd.body, fd.lineno, g.u.filename, sym_fn, g.private,
        decorators[0].lineno if len(decorators) > 0 else None
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
        afd.name, afd.args, afd.body, afd.lineno, g.u.filename, sym_fn, g.private,
        decorators[0].lineno if len(decorators) > 0 else None
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


# Build unverified_cfg for a function/async body (nested code object before assembly).
def compile_fn_cfg(
    name: str,
    args: arguments,
    body: list[stmt],
    lineno: int,
    filename: str,
    sym_fn: sym_block,
    private: str | None = None,
    body_firstlineno: int | None = None
) -> unverified_cfg {
    # CPython codegen_function scopes the body at the first decorator's line
    # when decorated (drives co_firstlineno and the prologue rows).
    if body_firstlineno is None {
        body_firstlineno = lineno;
    }
    (argcount, posonly, kwonly) = function_argcounts(args);
    u = unverified_cfg(
        filename=filename, name=name, qualname=name, firstlineno=body_firstlineno
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
    entry_blk = u.add_block();
    g = new_cfg_builder(u, entry_blk, sym_fn, private);
    protect_start = emit_function_prologue(g, sym_fn, body_firstlineno, is_suspendable);
    last = loc(0, body_firstlineno, 0, 0);
    terminated = False;
    bi = 0;
    while bi < len(body) {
        s = body[bi];
        cont = visit_stmt(g, s, exec_tail_emits_code(body, bi + 1), body, bi + 1);
        last = cont.loc;
        if cont.terminated {
            # CPython compiles the remaining statements and then drops them as
            # unreachable blocks (flowgraph remove_unreachable). Visiting them
            # here would append live bytes after a terminator, so stop now.
            # The implicit-return None const is still interned by CPython's
            # (dead) epilogue emission; remove_unused_consts keeps it only at
            # index 0, exactly like the host. Deferred comp cleanup handlers
            # are emitted here too -- CPython lays them out after the (dead)
            # epilogue regardless of how the body ended.
            u.add_const(py_none());
            u.flush_late_consts();
            return u;
        }
        if codegen_busy(g) {
            u.flush_late_consts();
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
    u.flush_late_consts();
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


# ---------------- PEP 695 `type X = v` / `type X[T, ...] = v` ----------------
#
# CPython lowers a type alias into a lazily-evaluated value function whose only
# parameter is `.format` (guarded: formats above 2 raise NotImplementedError)
# plus a 3-tuple (name, type_params_or_None, function) handed to
# CALL_INTRINSIC_1(INTRINSIC_TYPEALIAS). With type parameters the tuple build
# moves into a hidden `<generic parameters of X>` scope that constructs one
# TypeVar per parameter and closes the value function over those cells.

def typealias_target_name(ta: TypeAlias) -> str | None {
    if isinstance(ta.name, Name) {
        return ((ta.name as Name).id);
    }
    return None;
}


# The lazy value scope: argcount 1 (.format), format guard, then the alias
# value expression. Generic aliases additionally take the type params as
# free vars (COPY_FREE_VARS in the prologue via their symtable cells).
def typealias_value_cfg(
    ta: TypeAlias,
    name: str,
    qualname: str,
    filename: str,
    sym_v: sym_block,
    private: str | None,
    in_class: bool
) -> unverified_cfg {
    u = unverified_cfg(
        filename=filename, name=name, qualname=qualname, firstlineno=ta.lineno
    );
    u.argcount = 1;
    u.posonlyargcount = 1;
    u.flags = CO_OPTIMIZED | CO_NEWLOCALS;
    if sym_v.nested {
        u.flags = u.flags | CO_NESTED;
    }
    u.varnames = [".format"];
    u.freevars = freevars_from_sym(sym_v);
    if in_class {
        # Directly inside a class body the lazy scope closes over the class
        # dict cell and resolves bare names through it (PEP 649 hook).
        u.freevars.append("__classdict__");
        u.classdict_names = True;
    }
    entry_blk = u.add_block();
    g = new_cfg_builder(u, entry_blk, sym_v, private);
    # Prologue: COPY_FREE_VARS, MAKE_CELL(s), RESUME (CPython flowgraph order).
    # Nested-scope locations: NO_LOCATION for cell plumbing, def-line RESUME.
    u.cellvars = cellvars_from_sym(sym_v);
    noloc = no_loc();
    if len(u.freevars) > 0 {
        g.emit_op(OP_COPY_FREE_VARS, len(u.freevars), noloc);
    }
    ci = 0;
    while ci < len(u.cellvars) {
        g.emit_op(
            OP_MAKE_CELL, localsplus_index_u(u, u.cellvars[ci]), noloc
        );
        ci = ci + 1;
    }
    g.emit_op(OP_RESUME, 0, loc(ta.lineno, ta.lineno, 0, 0));
    hloc = nloc(ta.lineno, ta.end_lineno, ta.col_offset, ta.end_col_offset);
    # Guard: if .format > 2: raise NotImplementedError (formats 0/1 only).
    g.emit_op(OP_LOAD_FAST_BORROW, localsplus_index_u(u, ".format"), hloc);
    # Dead small-int slot: the guard literal keeps const pool slot 0.
    u.add_const(PyInt(t="int", val=2));
    u.dead_small_int_const = True;
    g.emit_op(OP_LOAD_SMALL_INT, 2, hloc);
    g.emit_op(OP_COMPARE_OP, compare_oparg(CMP_GT), hloc);
    after = g.new_block();
    g.emit_jump(OP_POP_JUMP_IF_FALSE, after.id, hloc);
    g.emit_op(OP_LOAD_COMMON_CONSTANT, 1, hloc);
    g.emit_op(OP_RAISE_VARARGS, 1, hloc);
    g.use(after);
    visit_expr(g, ta.value);
    if codegen_busy(g) {
        u.flush_late_consts();
        return u;
    }
    g.emit_op(OP_RETURN_VALUE, 0, hloc);
    u.flush_late_consts();
    return u;
}


# The hidden <generic parameters of X> scope: builds one TypeVar per param
# into cells, then assembles (name, (typevar, ...), closure-wrapped value fn).
def typealias_genparams_cfg(
    ta: TypeAlias,
    tps: list[type_param],
    name: str,
    filename: str,
    sym_gp: sym_block,
    co_value: PyCode,
    private: str | None,
    in_class: bool,
    qualname: str
) -> unverified_cfg {
    u = unverified_cfg(
        filename=filename,
        name="<generic parameters of " + name + ">",
        qualname=qualname,
        firstlineno=ta.lineno
    );
    u.flags = CO_OPTIMIZED | CO_NEWLOCALS;
    if sym_gp.nested {
        u.flags = u.flags | CO_NESTED;
    }
    u.freevars = freevars_from_sym(sym_gp);
    if in_class {
        u.freevars.append("__classdict__");
    }
    entry_blk = u.add_block();
    g = new_cfg_builder(u, entry_blk, sym_gp, private);
    u.cellvars = cellvars_from_sym(sym_gp);
    noloc = no_loc();
    if len(u.freevars) > 0 {
        g.emit_op(OP_COPY_FREE_VARS, len(u.freevars), noloc);
    }
    ci = 0;
    while ci < len(u.cellvars) {
        g.emit_op(
            OP_MAKE_CELL, localsplus_index_u(u, u.cellvars[ci]), noloc
        );
        ci = ci + 1;
    }
    g.emit_op(OP_RESUME, 0, loc(ta.lineno, ta.lineno, 0, 0));
    tloc = nloc(ta.lineno, ta.end_lineno, ta.col_offset, ta.end_col_offset);
    nidx = g.u.add_const(PyStr(t="str", val=name));
    g.emit_op(OP_LOAD_CONST, nidx, tloc);
    np = len(tps);
    pi = 0;
    while pi < np {
        tv_name = (tps[pi] as TypeVar).name;
        pidx = g.u.add_const(PyStr(t="str", val=tv_name));
        g.emit_op(OP_LOAD_CONST, pidx, tloc);
        g.emit_op(OP_CALL_INTRINSIC_1, 7, tloc);
        g.emit_op(OP_COPY, 1, tloc);
        g.emit_op(OP_STORE_DEREF, localsplus_index_u(u, tv_name), tloc);
        pi = pi + 1;
    }
    g.emit_op(OP_BUILD_TUPLE, np, tloc);
    def_tup = PyTuple(t="tuple", items=[PyInt(t="int", val=1)]);
    didx = g.u.add_const(def_tup);
    g.emit_op(OP_LOAD_CONST, didx, tloc);
    nclosure = np;
    pi = 0;
    while pi < np {
        tv_name = (tps[pi] as TypeVar).name;
        g.emit_op(
            OP_LOAD_FAST_BORROW, localsplus_index_u(u, tv_name), tloc
        );
        pi = pi + 1;
    }
    if in_class {
        g.emit_op(
            OP_LOAD_FAST_BORROW, localsplus_index_u(u, "__classdict__"), tloc
        );
        nclosure = nclosure + 1;
    }
    g.emit_op(OP_BUILD_TUPLE, nclosure, tloc);
    cidx = g.u.add_const(co_value);
    g.emit_op(OP_LOAD_CONST, cidx, tloc);
    g.emit_op(OP_MAKE_FUNCTION, 0, tloc);
    g.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 8, tloc);
    g.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 1, tloc);
    g.emit_op(OP_BUILD_TUPLE, 3, tloc);
    g.emit_op(OP_CALL_INTRINSIC_1, 11, tloc);
    g.emit_op(OP_RETURN_VALUE, 0, tloc);
    u.flush_late_consts();
    return u;
}


# Lower `type name[params] = value` at module/class/function scope.
def visit_type_alias(g: cfg_builder, ta: TypeAlias) -> stmt_cont {
    tloc = nloc(ta.lineno, ta.end_lineno, ta.col_offset, ta.end_col_offset);
    if g.sym_top is None {
        codegen_fail(g, "SystemError", "type alias without symtable");
        return stmt_cont(loc=tloc);
    }
    name = typealias_target_name(ta);
    if name is None {
        codegen_fail(g, "SyntaxError", "invalid type alias target");
        return stmt_cont(loc=tloc);
    }
    tps: list[type_param] = [];
    if ta.type_params is not None {
        tps = ta.type_params;
    }
    generic = len(tps) > 0;
    gp_name = "<generic parameters of " + name + ">";
    sym_v = None;
    if generic {
        sym_gp = sym_function_child_at(
            g.sym_top, gp_name, ta.lineno, ta.col_offset
        );
        if sym_gp is None {
            codegen_fail(
                g, "SystemError", "missing symtable for " + gp_name
            );
            return stmt_cont(loc=tloc);
        }
        sym_params = sym_gp;
        sym_v = sym_function_child_at(sym_gp, name, ta.lineno, ta.col_offset);
    } else {
        sym_v = sym_function_child_at(g.sym_top, name, ta.lineno, ta.col_offset);
    }
    if sym_v is None {
        codegen_fail(g, "SystemError", "missing symtable for type alias " + name);
        return stmt_cont(loc=tloc);
    }
    sym_value = sym_v;
    # CPython qualname rules: plain name at module scope, <Class>.Name in a
    # class body, and <parent>.<locals>.Name under a function scope.
    vqname = name;
    gpqname = "<generic parameters of " + name + ">";
    if g.sym_top.block_type == "class" {
        vqname = g.u.qualname + "." + name;
        gpqname = g.u.qualname + "." + gpqname;
    } elif g.sym_top.block_type != "module" {
        vqname = g.u.qualname + ".<locals>." + name;
        gpqname = g.u.qualname + ".<locals>." + gpqname;
    }
    in_class = g.sym_top.block_type == "class";
    if generic and in_class {
        # Needs classdict-aware deref loads (LOAD_FROM_DICT_OR_DEREF) for the
        # type-param cells inside the lazy scope; the shared name-load path in
        # compiler_emit only has the _OR_GLOBALS variant today. Fail loudly
        # rather than emitting silently-wrong bytes.
        codegen_fail(
            g,
            "NotImplementedError",
            "generic type alias directly inside a class body is not supported"
        );
        return stmt_cont(loc=tloc);
    }
    u_v = typealias_value_cfg(
        ta, name, vqname, g.u.filename, sym_value, g.private, in_class
    );
    if u_v.diag is not None {
        g.u.diag = u_v.diag;
        return stmt_cont(loc=tloc);
    }
    if generic {
        cfg_v = verify_cfg(u_v);
        if cfg_v.diag is not None {
            g.u.diag = cfg_v.diag;
            return stmt_cont(loc=tloc);
        }
        co_v = assemble(cfg_v);
        u_gp = typealias_genparams_cfg(
            ta, tps, name, g.u.filename, sym_params, co_v, g.private, in_class,
            gpqname
        );
        if u_gp.diag is not None {
            g.u.diag = u_gp.diag;
            return stmt_cont(loc=tloc);
        }
        cfg_gp = verify_cfg(u_gp);
        if cfg_gp.diag is not None {
            g.u.diag = cfg_gp.diag;
            return stmt_cont(loc=tloc);
        }
        co_gp = assemble(cfg_gp);
        g.u.nested_code_emitted = True;
        if in_class {
            clp = localsplus_index(g, "__classdict__");
            g.emit_op(OP_LOAD_FAST_BORROW, clp, tloc);
            g.emit_op(OP_BUILD_TUPLE, 1, tloc);
        }
        gidx = g.u.add_const(co_gp);
        g.emit_op(OP_LOAD_CONST, gidx, tloc);
        g.emit_op(OP_MAKE_FUNCTION, 0, tloc);
        if in_class {
            g.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 8, tloc);
        }
        g.emit_op(OP_PUSH_NULL, 0, tloc);
        g.emit_op(OP_CALL, 0, tloc);
    } else {
        cfg_v = verify_cfg(u_v);
        if cfg_v.diag is not None {
            g.u.diag = cfg_v.diag;
            return stmt_cont(loc=tloc);
        }
        co_v = assemble(cfg_v);
        g.u.nested_code_emitted = True;
        nidx = g.u.add_const(PyStr(t="str", val=name));
        none_idx = g.u.add_const(py_none());
        def_tup = PyTuple(t="tuple", items=[PyInt(t="int", val=1)]);
        didx = g.u.add_const(def_tup);
        vidx = g.u.add_const(co_v);
        g.emit_op(OP_LOAD_CONST, nidx, tloc);
        g.emit_op(OP_LOAD_CONST, none_idx, tloc);
        g.emit_op(OP_LOAD_CONST, didx, tloc);
        if in_class {
            clp = localsplus_index(g, "__classdict__");
            g.emit_op(OP_LOAD_FAST_BORROW, clp, tloc);
            g.emit_op(OP_BUILD_TUPLE, 1, tloc);
        }
        g.emit_op(OP_LOAD_CONST, vidx, tloc);
        g.emit_op(OP_MAKE_FUNCTION, 0, tloc);
        if in_class {
            g.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 8, tloc);
        }
        g.emit_op(OP_SET_FUNCTION_ATTRIBUTE, 1, tloc);
        g.emit_op(OP_BUILD_TUPLE, 3, tloc);
        g.emit_op(OP_CALL_INTRINSIC_1, 11, tloc);
    }
    if codegen_busy(g) {
        return stmt_cont(loc=tloc);
    }
    if g.sym_top is not None and g.sym_top.block_type == "function" {
        fi = fast_local_index(g, name);
        if fi < 0 {
            codegen_fail(
                g, "SystemError", "missing fast local for type alias " + name
            );
            return stmt_cont(loc=tloc);
        }
        g.emit_op(OP_STORE_FAST, fi, tloc);
    } else {
        nidx2 = g.u.add_name(name);
        g.emit_op(OP_STORE_NAME, nidx2, tloc);
    }
    return stmt_cont(loc=tloc);
}
