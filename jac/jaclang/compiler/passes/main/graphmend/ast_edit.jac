import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { GraphMendHelper }
import type from jaclang.jac0core.program { JacProgram }

def gen_name(at: uni.UniNode, value: str, store: bool) -> uni.Name {
    anchor: any = at;
    nm = uni.Name.gen_stub_from_node(anchor, value);
    if store {
        nm.expr_ctx = uni.ExprCtx.STORE;
    }
    return nm;
}

def gen_string(at: uni.UniNode, value: str) -> uni.String {
    return uni.String(
        orig_src=at.loc.orig_src,
        name='STRING',
        value=value,
        line=at.loc.first_line,
        end_line=at.loc.last_line,
        col_start=at.loc.col_start,
        col_end=at.loc.col_end,
        pos_start=at.loc.pos_start,
        pos_end=at.loc.pos_end
    );
}

def need_helper(prog: JacProgram, at: uni.UniNode, helper: GraphMendHelper) -> None {
    mod = at.find_parent_of_type(uni.Module);
    if mod is None {
        return;
    }
    needed = prog.graphmend_helpers.get(id(mod));
    if needed is None {
        needed = set();
        prog.graphmend_helpers[id(mod)] = needed;
    }
    needed.add(helper);
}

def torch_call(at: uni.UniNode, fname: str, args: list) -> uni.FuncCall {
    torch_nm = gen_name(at, 'torch', False);
    fn_nm = gen_name(at, fname, False);
    target = uni.AtomTrailer(
        target=torch_nm,
        right=fn_nm,
        is_attr=True,
        is_null_ok=False,
        kid=[torch_nm, fn_nm]
    );
    return uni.FuncCall(
        target=target, params=args, genai_call=None, kid=[target] + args
    );
}

def insert_after(stmt: uni.UniNode, new_stmt: uni.UniNode) -> None {
    parent = stmt.parent;
    if parent is None {
        return;
    }
    holder: any = parent;
    body = holder?.body;
    if isinstance(body, list) and (stmt in body) {
        i = body.index(stmt);
        setattr(holder, 'body', body[:(i + 1)] + [new_stmt] + body[(i + 1):]);
    }
    if stmt in parent.kid {
        j = parent.kid.index(stmt);
        parent.set_kids(
            list(parent.kid[:(j + 1)]) + [new_stmt] + list(parent.kid[(j + 1):])
        );
    }
    new_stmt.parent = parent;
}

def replace_stmt(old: uni.UniNode, new_nodes: list) -> None {
    parent = old.parent;
    if parent is None {
        return;
    }
    holder: any = parent;
    body = holder?.body;
    if isinstance(body, list) and (old in body) {
        i = body.index(old);
        setattr(holder, 'body', list(body[:i]) + new_nodes + list(body[(i + 1):]));
    }
    if old in parent.kid {
        j = parent.kid.index(old);
        parent.set_kids(list(parent.kid[:j]) + new_nodes + list(parent.kid[(j + 1):]));
    }
    for child in new_nodes {
        child.parent = parent;
    }
}
