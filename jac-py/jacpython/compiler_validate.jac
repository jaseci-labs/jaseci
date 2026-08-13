# AST validation for the P4 back track (INTEGRATION_PLAN Phase 2).
#
# Owns language legality independent of scope resolution: placement of return,
# break, continue, and yield; expression contexts on names, attributes, and
# subscripts; legal store and delete targets. Codegen receives validated AST
# only via product_compile.jac.

import from ast_nodes {
    expr,
    stmt,
    Constant,
    Name,
    BinOp,
    UnaryOp,
    Call,
    Compare,
    BoolOp,
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
    Tuple,
    List,
    Dict,
    Starred,
    Load,
    Store,
    Del,
    Break,
    Continue,
    Yield,
    YieldFrom,
    Global,
    Nonlocal,
    For,
    While,
    If,
    Try,
    With,
    FunctionDef,
    ClassDef,
    AsyncFunctionDef,
    AsyncFor,
    AsyncWith,
}
import from compiler_diagnostics {
    compiler_diagnostic,
    validation_diagnostic,
}

obj validation_result {
    has diag: compiler_diagnostic | None = None;
}

def validation_ok -> validation_result {
    return validation_result();
}

def validation_error(
    kind: str, message: str, lineno: int = -1, col_offset: int = -1
) -> validation_result {
    return validation_result(
        diag=validation_diagnostic(
            kind=kind, message=message, lineno=lineno, col_offset=col_offset
        )
    );
}

# --- expression context ---

def validate_load_expr(e: expr) -> validation_result {
    if isinstance(e, Name) {
        n = e as Name;
        if not isinstance(n.ctx, Load) {
            return validation_error(
                "SyntaxError",
                "name '" + n.id + "' is not defined",
                n.lineno,
                n.col_offset
            );
        }
        return validation_ok();
    }
    if isinstance(e, Attribute) {
        a = e as Attribute;
        if not isinstance(a.ctx, Load) {
            return validation_error(
                "SyntaxError",
                "illegal expression context",
                a.lineno,
                a.col_offset
            );
        }
        inner = validate_load_expr(a.value);
        if inner.diag is not None {
            return inner;
        }
        return validation_ok();
    }
    if isinstance(e, Subscript) {
        s = e as Subscript;
        if not isinstance(s.ctx, Load) {
            return validation_error(
                "SyntaxError",
                "illegal expression context",
                s.lineno,
                s.col_offset
            );
        }
        inner = validate_load_expr(s.value);
        if inner.diag is not None {
            return inner;
        }
        return validate_subscript_slice(s.slice);
    }
    if isinstance(e, Constant) {
        return validation_ok();
    }
    if isinstance(e, BinOp) {
        b = e as BinOp;
        left = validate_load_expr(b.left);
        if left.diag is not None {
            return left;
        }
        return validate_load_expr(b.right);
    }
    if isinstance(e, UnaryOp) {
        return validate_load_expr((e as UnaryOp).operand);
    }
    if isinstance(e, Compare) {
        c = e as Compare;
        left = validate_load_expr(c.left);
        if left.diag is not None {
            return left;
        }
        ci = 0;
        while ci < len(c.comparators) {
            cmp = validate_load_expr(c.comparators[ci]);
            if cmp.diag is not None {
                return cmp;
            }
            ci = ci + 1;
        }
        return validation_ok();
    }
    if isinstance(e, Call) {
        ca = e as Call;
        func = validate_load_expr(ca.func);
        if func.diag is not None {
            return func;
        }
        args = ca.args;
        if args is None {
            args = [];
        }
        ai = 0;
        while ai < len(args) {
            arg = validate_load_expr(args[ai]);
            if arg.diag is not None {
                return arg;
            }
            ai = ai + 1;
        }
        return validation_ok();
    }
    if isinstance(e, BoolOp) {
        bo = e as BoolOp;
        vi = 0;
        while vi < len(bo.values) {
            vr = validate_load_expr(bo.values[vi]);
            if vr.diag is not None {
                return vr;
            }
            vi = vi + 1;
        }
        return validation_ok();
    }
    if isinstance(e, List) {
        li = e as List;
        ei = 0;
        while ei < len(li.elts) {
            vr = validate_load_expr(li.elts[ei]);
            if vr.diag is not None {
                return vr;
            }
            ei = ei + 1;
        }
        return validation_ok();
    }
    if isinstance(e, Tuple) {
        tu = e as Tuple;
        ei = 0;
        while ei < len(tu.elts) {
            vr = validate_load_expr(tu.elts[ei]);
            if vr.diag is not None {
                return vr;
            }
            ei = ei + 1;
        }
        return validation_ok();
    }
    if isinstance(e, Starred) {
        return validate_load_expr((e as Starred).value);
    }
    if isinstance(e, Slice) {
        return validate_subscript_slice(e);
    }
    return validation_ok();
}

def validate_stmt_list(
    body: list[stmt], in_function: bool, in_loop: bool, in_async: bool
) -> validation_result {
    si = 0;
    while si < len(body) {
        r = validate_stmt(body[si], in_function, in_loop, in_async);
        if r.diag is not None {
            return r;
        }
        si = si + 1;
    }
    return validation_ok();
}

def validate_duplicate_names(
    names: list[str], kind: str, lineno: int, col_offset: int
) -> validation_result {
    ni = 0;
    while ni < len(names) {
        nj = ni + 1;
        while nj < len(names) {
            if names[ni] == names[nj] {
                return validation_error(
                    "SyntaxError",
                    "name '" + names[ni] + "' is repeated in " + kind + " declaration",
                    lineno,
                    col_offset
                );
            }
            nj = nj + 1;
        }
        ni = ni + 1;
    }
    return validation_ok();
}

def validate_subscript_slice(key: expr) -> validation_result {
    if isinstance(key, Slice) {
        sl = key as Slice;
        if sl.lower is not None {
            lo = validate_load_expr(sl.lower);
            if lo.diag is not None {
                return lo;
            }
        }
        if sl.upper is not None {
            up = validate_load_expr(sl.upper);
            if up.diag is not None {
                return up;
            }
        }
        if sl.step is not None {
            st = validate_load_expr(sl.step);
            if st.diag is not None {
                return st;
            }
        }
        return validation_ok();
    }
    return validate_load_expr(key);
}

# --- store / delete targets ---

def validate_store_target(t: expr) -> validation_result {
    if isinstance(t, Name) {
        n = t as Name;
        if not isinstance(n.ctx, Store) {
            return validation_error(
                "SyntaxError",
                "cannot assign to " + n.id,
                n.lineno,
                n.col_offset
            );
        }
        return validation_ok();
    }
    if isinstance(t, Attribute) {
        a = t as Attribute;
        if not isinstance(a.ctx, Store) {
            return validation_error(
                "SyntaxError",
                "illegal target for assignment",
                a.lineno,
                a.col_offset
            );
        }
        return validate_load_expr(a.value);
    }
    if isinstance(t, Subscript) {
        s = t as Subscript;
        if not isinstance(s.ctx, Store) {
            return validation_error(
                "SyntaxError",
                "illegal target for assignment",
                s.lineno,
                s.col_offset
            );
        }
        inner = validate_load_expr(s.value);
        if inner.diag is not None {
            return inner;
        }
        return validate_subscript_slice(s.slice);
    }
    # Unsupported but syntactically valid targets (tuple unpacking, etc.) are
    # codegen's job with NotImplementedError, not validation SyntaxError.
    return validation_ok();
}

def validate_delete_target(t: expr) -> validation_result {
    if isinstance(t, Name) {
        n = t as Name;
        if not isinstance(n.ctx, Del) {
            return validation_error(
                "SyntaxError",
                "cannot delete " + n.id,
                n.lineno,
                n.col_offset
            );
        }
        return validation_ok();
    }
    if isinstance(t, Attribute) {
        a = t as Attribute;
        if not isinstance(a.ctx, Del) {
            return validation_error(
                "SyntaxError",
                "illegal target for deletion",
                a.lineno,
                a.col_offset
            );
        }
        return validate_load_expr(a.value);
    }
    if isinstance(t, Subscript) {
        s = t as Subscript;
        if not isinstance(s.ctx, Del) {
            return validation_error(
                "SyntaxError",
                "illegal target for deletion",
                s.lineno,
                s.col_offset
            );
        }
        inner = validate_load_expr(s.value);
        if inner.diag is not None {
            return inner;
        }
        return validate_subscript_slice(s.slice);
    }
    return validation_ok();
}

# --- statements ---

def validate_stmt(
    s: stmt, in_function: bool, in_loop: bool, in_async: bool = False
) -> validation_result {
    if isinstance(s, Return) {
        r = s as Return;
        if not in_function {
            return validation_error(
                "SyntaxError",
                "'return' outside function",
                r.lineno,
                r.col_offset
            );
        }
        if r.value is not None {
            return validate_load_expr(r.value);
        }
        return validation_ok();
    }
    if isinstance(s, Break) {
        b = s as Break;
        if not in_loop {
            return validation_error(
                "SyntaxError",
                "'break' outside loop",
                b.lineno,
                b.col_offset
            );
        }
        return validation_ok();
    }
    if isinstance(s, Continue) {
        c = s as Continue;
        if not in_loop {
            return validation_error(
                "SyntaxError",
                "'continue' outside loop",
                c.lineno,
                c.col_offset
            );
        }
        return validation_ok();
    }
    if isinstance(s, Yield) or isinstance(s, YieldFrom) {
        if not in_function {
            lineno = 1;
            col = 0;
            if isinstance(s, Yield) {
                yy = s as Yield;
                lineno = yy.lineno;
                col = yy.col_offset;
            }
            if isinstance(s, YieldFrom) {
                yf = s as YieldFrom;
                lineno = yf.lineno;
                col = yf.col_offset;
            }
            return validation_error(
                "SyntaxError",
                "'yield' outside function",
                lineno,
                col
            );
        }
        return validation_ok();
    }
    if isinstance(s, Assign) {
        a = s as Assign;
        val = validate_load_expr(a.value);
        if val.diag is not None {
            return val;
        }
        ti = 0;
        while ti < len(a.targets) {
            tgt = validate_store_target(a.targets[ti]);
            if tgt.diag is not None {
                return tgt;
            }
            ti = ti + 1;
        }
        return validation_ok();
    }
    if isinstance(s, AugAssign) {
        aa = s as AugAssign;
        tgt = validate_store_target(aa.target);
        if tgt.diag is not None {
            return tgt;
        }
        return validate_load_expr(aa.value);
    }
    if isinstance(s, AnnAssign) {
        an = s as AnnAssign;
        tgt = validate_store_target(an.target);
        if tgt.diag is not None {
            return tgt;
        }
        if an.value is not None {
            return validate_load_expr(an.value);
        }
        return validation_ok();
    }
    if isinstance(s, Delete) {
        d = s as Delete;
        ti = 0;
        while ti < len(d.targets) {
            tgt = validate_delete_target(d.targets[ti]);
            if tgt.diag is not None {
                return tgt;
            }
            ti = ti + 1;
        }
        return validation_ok();
    }
    if isinstance(s, Expr) {
        return validate_load_expr((s as Expr).value);
    }
    if isinstance(s, Pass) {
        return validation_ok();
    }
    if isinstance(s, Global) {
        g = s as Global;
        return validate_duplicate_names(g.names, "global", g.lineno, g.col_offset);
    }
    if isinstance(s, Nonlocal) {
        nl = s as Nonlocal;
        if not in_function {
            return validation_error(
                "SyntaxError",
                "nonlocal declaration not allowed at module level",
                nl.lineno,
                nl.col_offset
            );
        }
        return validate_duplicate_names(nl.names, "nonlocal", nl.lineno, nl.col_offset);
    }
    if isinstance(s, For) {
        fo = s as For;
        tgt = validate_store_target(fo.target);
        if tgt.diag is not None {
            return tgt;
        }
        it = validate_load_expr(fo.iter);
        if it.diag is not None {
            return it;
        }
        body = validate_stmt_list(fo.body, in_function, True, in_async);
        if body.diag is not None {
            return body;
        }
        return validate_stmt_list(fo.orelse, in_function, in_loop, in_async);
    }
    if isinstance(s, AsyncFor) {
        if not in_async {
            af = s as AsyncFor;
            return validation_error(
                "SyntaxError",
                "'async for' outside async function",
                af.lineno,
                af.col_offset
            );
        }
        afo = s as AsyncFor;
        tgt = validate_store_target(afo.target);
        if tgt.diag is not None {
            return tgt;
        }
        it = validate_load_expr(afo.iter);
        if it.diag is not None {
            return it;
        }
        body = validate_stmt_list(afo.body, in_function, True, True);
        if body.diag is not None {
            return body;
        }
        return validate_stmt_list(afo.orelse, in_function, in_loop, True);
    }
    if isinstance(s, While) {
        wh = s as While;
        te = validate_load_expr(wh.test);
        if te.diag is not None {
            return te;
        }
        body = validate_stmt_list(wh.body, in_function, True, in_async);
        if body.diag is not None {
            return body;
        }
        return validate_stmt_list(wh.orelse, in_function, in_loop, in_async);
    }
    if isinstance(s, If) {
        iff = s as If;
        te = validate_load_expr(iff.test);
        if te.diag is not None {
            return te;
        }
        body = validate_stmt_list(iff.body, in_function, in_loop, in_async);
        if body.diag is not None {
            return body;
        }
        return validate_stmt_list(iff.orelse, in_function, in_loop, in_async);
    }
    if isinstance(s, Try) {
        tr = s as Try;
        body = validate_stmt_list(tr.body, in_function, in_loop, in_async);
        if body.diag is not None {
            return body;
        }
        body = validate_stmt_list(tr.orelse, in_function, in_loop, in_async);
        if body.diag is not None {
            return body;
        }
        return validate_stmt_list(tr.finalbody, in_function, in_loop, in_async);
    }
    if isinstance(s, With) {
        wi = s as With;
        ii = 0;
        while ii < len(wi.items) {
            item = wi.items[ii];
            ce = validate_load_expr(item.context_expr);
            if ce.diag is not None {
                return ce;
            }
            if item.optional_vars is not None {
                ov = validate_store_target(item.optional_vars);
                if ov.diag is not None {
                    return ov;
                }
            }
            ii = ii + 1;
        }
        return validate_stmt_list(wi.body, in_function, in_loop, in_async);
    }
    if isinstance(s, AsyncWith) {
        if not in_async {
            aw = s as AsyncWith;
            return validation_error(
                "SyntaxError",
                "'async with' outside async function",
                aw.lineno,
                aw.col_offset
            );
        }
        awi = s as AsyncWith;
        ii = 0;
        while ii < len(awi.items) {
            item = awi.items[ii];
            ce = validate_load_expr(item.context_expr);
            if ce.diag is not None {
                return ce;
            }
            if item.optional_vars is not None {
                ov = validate_store_target(item.optional_vars);
                if ov.diag is not None {
                    return ov;
                }
            }
            ii = ii + 1;
        }
        return validate_stmt_list(awi.body, in_function, in_loop, True);
    }
    if isinstance(s, FunctionDef) {
        fd = s as FunctionDef;
        return validate_stmt_list(fd.body, True, False, False);
    }
    if isinstance(s, AsyncFunctionDef) {
        afd = s as AsyncFunctionDef;
        return validate_stmt_list(afd.body, True, False, True);
    }
    if isinstance(s, ClassDef) {
        cd = s as ClassDef;
        return validate_stmt_list(cd.body, False, False, in_async);
    }
    return validation_ok();
}

def validate_module_body(body: list[stmt]) -> validation_result {
    return validate_stmt_list(body, in_function=False, in_loop=False, in_async=False);
}

def validate_eval_expr(e: expr) -> validation_result {
    return validate_load_expr(e);
}

# ---------------- tests ----------------

import from compiler_diagnostics { compiler_diag_kind, compiler_diag_message }
import from objects { PyInt }
import from ast_nodes { USub }

test "compiler_validate: module return rejected" {
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=1,
        col_offset=7,
        end_lineno=1,
        end_col_offset=8
    );
    r = validate_module_body(
        [Return(value=one, lineno=1, col_offset=0, end_lineno=1, end_col_offset=8)]
    );
    assert r.diag is not None;
    assert compiler_diag_kind(r.diag) == "SyntaxError";
    assert compiler_diag_message(r.diag) == "'return' outside function";
}

test "compiler_validate: pass module accepted" {
    r = validate_module_body(
        [Pass(lineno=1, col_offset=0, end_lineno=1, end_col_offset=4)]
    );
    assert r.diag is None;
}

test "compiler_validate: assign with load target rejected" {
    x = Name(
        id="x", ctx=Load(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=1,
        col_offset=4,
        end_lineno=1,
        end_col_offset=5
    );
    r = validate_module_body(
        [
            Assign(
                targets=[x],
                value=one,
                type_comment=None,
                lineno=1,
                col_offset=0,
                end_lineno=1,
                end_col_offset=5
            )
        ]
    );
    assert r.diag is not None;
    assert compiler_diag_kind(r.diag) == "SyntaxError";
}

test "compiler_validate: unsupported tuple target defers to codegen" {
    x = Name(
        id="x", ctx=Store(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    y = Name(
        id="y", ctx=Store(), lineno=1, col_offset=2, end_lineno=1, end_col_offset=3
    );
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=1,
        col_offset=6,
        end_lineno=1,
        end_col_offset=7
    );
    r = validate_module_body(
        [
            Assign(
                targets=[Tuple(elts=[x, y], ctx=Store(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=4)],
                value=one,
                type_comment=None,
                lineno=1,
                col_offset=0,
                end_lineno=1,
                end_col_offset=7
            )
        ]
    );
    assert r.diag is None;
}

test "compiler_validate: eval expr accepted" {
    x = Name(
        id="x", ctx=Load(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    r = validate_eval_expr(
        UnaryOp(
            op=USub(), operand=x, lineno=1, col_offset=0, end_lineno=1, end_col_offset=2
        )
    );
    assert r.diag is None;
}

test "compiler_validate: break outside loop rejected" {
    r = validate_module_body(
        [Break(lineno=1, col_offset=0, end_lineno=1, end_col_offset=5)]
    );
    assert r.diag is not None;
    assert compiler_diag_message(r.diag) == "'break' outside loop";
}

test "compiler_validate: nonlocal at module rejected" {
    r = validate_module_body(
        [Nonlocal(names=["x"], lineno=1, col_offset=0, end_lineno=1, end_col_offset=13)]
    );
    assert r.diag is not None;
    assert compiler_diag_message(r.diag) == "nonlocal declaration not allowed at module level";
}

test "compiler_validate: break inside while accepted" {
    r = validate_module_body(
        [
            While(
                test=Constant(
                    value=PyInt(t="int", val=1),
                    kind=None,
                    lineno=1,
                    col_offset=5,
                    end_lineno=1,
                    end_col_offset=6
                ),
                body=[Break(lineno=2, col_offset=4, end_lineno=2, end_col_offset=9)],
                orelse=[],
                lineno=1,
                col_offset=0,
                end_lineno=2,
                end_col_offset=9
            )
        ]
    );
    assert r.diag is None;
}
