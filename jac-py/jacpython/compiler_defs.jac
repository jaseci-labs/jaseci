# Definition and import codegen (class/function defs, import statements)
# extracted from compiler_codegen.jac. Pure mechanical move; see
# compiler_codegen.jac for the module-initialization ordering contract.

import from objects {
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
    OP_CALL,
    OP_CALL_KW,
    OP_IMPORT_FROM,
    OP_IMPORT_NAME,
    OP_LOAD_BUILD_CLASS,
    OP_LOAD_CONST,
    OP_LOAD_FAST_BORROW,
    OP_LOAD_LOCALS,
    OP_LOAD_NAME,
    OP_MAKE_CELL,
    OP_MAKE_FUNCTION,
    OP_POP_TOP,
    OP_PUSH_NULL,
    OP_RESUME,
    OP_RETURN_VALUE,
    OP_STORE_DEREF,
    OP_STORE_FAST,
    OP_STORE_NAME,
}
import from ast_nodes {
    AsyncFunctionDef,
    ClassDef,
    FunctionDef,
    Import,
    ImportFrom,
    arguments,
    keyword,
    stmt,
}
import from compiler_ir {
    cfg_builder,
    cloc,
    loc,
    new_cfg_builder,
    stmt_cont,
    unverified_cfg,
}
import from compiler_symtable { sym_block }
import from flowgraph { verify_cfg }
import from assembler { assemble }
import from compiler_emit {
    codegen_busy,
    codegen_fail,
    emit_folded_int,
    emit_function_prologue,
    emit_make_function_with_closure,
    fast_local_index,
    fast_varnames_from_sym,
    localsplus_index_u,
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
        filename=filename, name=cd.name, qualname=class_qname, firstlineno=cd.lineno
    );
    if sym_cls.nested {
        u.flags = CO_NESTED;
    }
    if class_body_has_function(cd) {
        u.cellvars = ["__classdict__"];
    }
    entry_blk = u.add_block();
    g = new_cfg_builder(u, entry_blk, sym_cls, cd.name);
    emit_class_body_prologue(g, cd, class_qname);
    last = loc(0, cd.lineno, 0, 0);
    bi = 0;
    while bi < len(cd.body) {
        s = cd.body[bi];
        cont = visit_stmt(g, s, exec_tail_emits_code(cd.body, bi + 1), cd.body, bi + 1);
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
    u = unverified_cfg(filename=filename, name=name, qualname=name, firstlineno=lineno);
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
    protect_start = emit_function_prologue(g, sym_fn, lineno, is_suspendable);
    last = loc(0, lineno, 0, 0);
    terminated = False;
    bi = 0;
    while bi < len(body) {
        s = body[bi];
        cont = visit_stmt(g, s, exec_tail_emits_code(body, bi + 1), body, bi + 1);
        last = cont.loc;
        if cont.terminated {
            terminated = True;
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
