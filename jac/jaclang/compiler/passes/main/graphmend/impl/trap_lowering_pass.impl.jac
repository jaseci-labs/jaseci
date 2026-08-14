import builtins;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { GraphBreakKind, GraphMendHelper }
import from jaclang.compiler.passes.main.graphmend.torch_attr_table {
    has_torch_compile_decorator,
    is_torch_attr_target
}

impl TrapLoweringPass.exit_assignment(nd: uni.Assignment) -> None {
    if (not self._enabled) or (not self.prog.graphmend_scope) {
        return;
    }
    value = nd.value;
    if (
        (not isinstance(value, uni.FuncCall))
        or (not is_torch_attr_target(value.target, 'compile'))
    ) {
        return;
    }
    if (not nd.target) or (len(nd.target) != 1) {
        return;
    }
    tgt = nd.target[0];
    if not isinstance(tgt, uni.Name) {
        return;
    }
    self._need_helper(nd, GraphMendHelper.TRAP_GUARD);
    self._insert_after(nd, self._boundary_attach_stmt(nd, tgt.value));
}

impl TrapLoweringPass._boundary_attach_stmt(
    at: uni.UniNode, name: str
) -> uni.Assignment {
    store = self._gen_name(at, name);
    store.expr_ctx = uni.ExprCtx.STORE;
    guard = self._gen_name(at, '__jac_trap_guard__');
    arg = self._gen_name(at, name);
    call = uni.FuncCall(target=guard, params=[arg], genai_call=None, kid=[guard, arg]);
    return uni.Assignment(
        target=[store], value=call, type_tag=None, mutable=True, kid=[store, call]
    );
}

impl TrapLoweringPass._insert_after(stmt: uni.UniNode, new_stmt: uni.UniNode) -> None {
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

impl TrapLoweringPass.before_pass -> None {
    self._enabled = (self.prog._compile_options.graphmend is True)
        and "trap" not in self.prog._compile_options.graphmend_disable;
    if not self._enabled {
        self.prune_signal = True;
    }
}

impl TrapLoweringPass.exit_if_stmt(nd: uni.IfStmt) -> None {
    if not self._enabled {
        return;
    }
    if self.prog.graphmend_breaks.get(id(nd)) != GraphBreakKind.VAL_GUARD {
        return;
    }
    if self._inside_try(nd) {
        return;
    }
    if (not nd.body) or (len(nd.body) != 1) {
        return;
    }
    rs = nd.body[0];
    if not isinstance(rs, uni.RaiseStmt) {
        return;
    }
    cond = nd.condition;
    negated_compare = False;
    x: (uni.Expr | None) = None;
    if isinstance(cond, uni.UnaryExpr)
        and (cond.op is not None)
        and (cond.op.value == 'not') {
        x = cond.operand;
    } elif self._condition_is_tensor(cond, nd) {
        x = self._torch_call(nd, 'logical_not', [cond]);
        negated_compare = True;
    }
    if x is None {
        return;
    }
    msg = self._raise_message(rs);
    wrap = self._enclosing_compiled_fn(nd);
    covered = (wrap is not None) or self.prog.graphmend_scoped_compile;
    type_name = self._exception_type_name(rs) if covered else None;
    marked = (
        self._marked_message(nd, msg, type_name)
            if ((type_name is not None) and (msg is not None))
            else None
    );
    if marked is None {
        return;
    }
    if not self._torch_binds_module(nd) {
        return;
    }
    eq = self._torch_equal_args(x);
    if eq is not None {
        (a, b) = eq;
        self._need_helper(nd, GraphMendHelper.EQ_ASSERT);
        self._replace(nd, [self._eq_assert_stmt(nd, a, b, marked)]);
        self._mark_guard(wrap);
    } elif negated_compare {
        self._replace(nd, [self._assert_async_stmt(nd, x, marked)]);
        self._mark_guard(wrap);
    } elif self._returns_tensor_bool(x) and self._tensor_receiver_provable(x, nd) {
        self._replace(nd, [self._assert_async_stmt(nd, x, marked)]);
        self._mark_guard(wrap);
    }
}

impl TrapLoweringPass._inside_try(nd: uni.UniNode) -> bool {
    cur: (uni.UniNode | None) = nd.parent;
    while cur is not None {
        if isinstance(cur, uni.TryStmt) {
            return True;
        }
        if isinstance(cur, uni.Ability) {
            return False;
        }
        cur = cur.parent;
    }
    return False;
}

impl TrapLoweringPass._enclosing_compiled_fn(nd: uni.UniNode) -> (uni.Ability | None) {
    ab = nd.find_parent_of_type(uni.Ability);
    if (ab is not None) and has_torch_compile_decorator(ab) {
        return ab;
    }
    return None;
}

impl TrapLoweringPass._exception_type_name(rs: uni.RaiseStmt) -> (str | None) {
    cause = rs.cause;
    if cause is None {
        return None;
    }
    target = cause.target if isinstance(cause, uni.FuncCall) else cause;
    if not isinstance(target, uni.Name) {
        return None;
    }
    if target.sym is not None {
        return None;
    }
    cls = getattr(builtins, target.value, None);
    if isinstance(cls, type) and issubclass(cls, BaseException) {
        return target.value;
    }
    return None;
}

impl TrapLoweringPass._marked_message(
    at: uni.UniNode, msg: uni.Expr, type_name: str
) -> (uni.String | None) {
    if not isinstance(msg, (uni.String, uni.MultiString)) {
        return None;
    }
    if isinstance(msg, uni.MultiString) {
        for part in msg.strings {
            if not isinstance(part, uni.String) {
                return None;
            }
        }
    }
    lit = str(msg.lit_value);
    if "[[/GM-TRAP]]" in lit {
        return None;
    }
    text = "[[GM-TRAP " + type_name + "]]" + lit + "[[/GM-TRAP]]";
    return self._str(at, text);
}

impl TrapLoweringPass._need_helper(at: uni.UniNode, helper: GraphMendHelper) -> None {
    mod = at.find_parent_of_type(uni.Module);
    if mod is None {
        return;
    }
    needed = self.prog.graphmend_helpers.get(id(mod));
    if needed is None {
        needed = set();
        self.prog.graphmend_helpers[id(mod)] = needed;
    }
    needed.add(helper);
}

impl TrapLoweringPass._mark_guard(ability: (uni.Ability | None)) -> None {
    if ability is None {
        return;
    }
    self._guarded_fns.add(id(ability));
    self._need_helper(ability, GraphMendHelper.TRAP_GUARD);
}

impl TrapLoweringPass.exit_ability(nd: uni.Ability) -> None {
    if not self._enabled {
        return;
    }
    if id(nd) not in self._guarded_fns {
        return;
    }
    dec = self._gen_name(nd, '__jac_trap_guard__');
    nd.decorators = [dec] + list(nd.decorators or []);
    nd.set_kids([dec] + list(nd.kid));
    dec.parent = nd;
}

impl TrapLoweringPass._torch_equal_args(x: uni.Expr) -> (tuple | None) {
    if not isinstance(x, uni.FuncCall) {
        return None;
    }
    call: uni.FuncCall = x;
    if not is_torch_attr_target(call.target, 'equal') {
        return None;
    }
    pos = [
        p
        for p in (call.params or [])
        if not isinstance(p, uni.KWPair)
    ];
    if len(pos) < 2 {
        return None;
    }
    return (pos[0], pos[1]);
}

impl TrapLoweringPass._returns_tensor_bool(x: uni.Expr) -> bool {
    return (
        isinstance(x, uni.FuncCall)
        and isinstance(x.target, uni.AtomTrailer)
        and isinstance(x.target.right, uni.Name)
        and (x.target.right.value in _TENSOR_BOOL_OPS)
    );
}

impl TrapLoweringPass._raise_message(rs: uni.RaiseStmt) -> (uni.Expr | None) {
    if rs.from_target is not None {
        return None;
    }
    cause = rs.cause;
    if not isinstance(cause, uni.FuncCall) {
        return None;
    }
    call: uni.FuncCall = cause;
    pos = [
        p
        for p in (call.params or [])
        if not isinstance(p, uni.KWPair)
    ];
    if (len(pos) != 1) or (len(pos) != len(call.params or [])) {
        return None;
    }
    return pos[0];
}

impl TrapLoweringPass._gen_name(at: uni.UniNode, value: str) -> uni.Name {
    anchor: any = at;
    return uni.Name.gen_stub_from_node(anchor, value);
}

impl TrapLoweringPass._str(at: uni.UniNode, text: str) -> uni.String {
    esc = text.encode('unicode_escape').decode('ascii').replace('"', '\\"');
    return uni.String(
        orig_src=at.loc.orig_src,
        name='STRING',
        value=f'"{esc}"',
        line=at.loc.first_line,
        end_line=at.loc.last_line,
        col_start=at.loc.col_start,
        col_end=at.loc.col_end,
        pos_start=at.loc.pos_start,
        pos_end=at.loc.pos_end
    );
}

impl TrapLoweringPass._call_stmt(call: uni.FuncCall) -> uni.ExprStmt {
    return uni.ExprStmt(expr=call, in_fstring=False, kid=[call]);
}

impl TrapLoweringPass._eq_assert_stmt(
    at: uni.UniNode, a: uni.Expr, b: uni.Expr, msg: uni.Expr
) -> uni.ExprStmt {
    helper = self._gen_name(at, '__jac_tensor_eq_assert__');
    params = [a, b, msg];
    call = uni.FuncCall(
        target=helper, params=params, genai_call=None, kid=[helper] + params
    );
    return self._call_stmt(call);
}

impl TrapLoweringPass._assert_async_stmt(
    at: uni.UniNode, x: uni.Expr, msg: uni.Expr
) -> uni.ExprStmt {
    torch_nm = self._gen_name(at, 'torch');
    assert_nm = self._gen_name(at, '_assert_async');
    target = uni.AtomTrailer(
        target=torch_nm,
        right=assert_nm,
        is_attr=True,
        is_null_ok=False,
        kid=[torch_nm, assert_nm]
    );
    params = [x, msg];
    call = uni.FuncCall(
        target=target, params=params, genai_call=None, kid=[target] + params
    );
    return self._call_stmt(call);
}

impl TrapLoweringPass._condition_is_tensor(cond: uni.Expr, site: uni.UniNode) -> bool {
    if isinstance(cond, uni.AtomUnit) and isinstance(cond.value, uni.Expr) {
        return self._condition_is_tensor(cond.value, site);
    }
    if isinstance(cond, uni.CompareExpr) {
        if len(cond.ops or []) != 1 {
            return False;
        }
        if cond.ops[0].value not in {'==', '!=', '<', '>', '<=', '>='} {
            return False;
        }
        operands = [cond.left] + list(cond.rights or []);
        for e in operands {
            if self._operand_is_tensor(e, site) {
                return True;
            }
        }
    }
    return False;
}

impl TrapLoweringPass._operand_is_tensor(e: uni.Expr, site: uni.UniNode) -> bool {
    if isinstance(e, uni.AtomUnit) and isinstance(e.value, uni.Expr) {
        return self._operand_is_tensor(e.value, site);
    }
    if self._returns_tensor_bool(e) or isinstance(e, uni.FuncCall) {
        if self._tensor_receiver_provable(e, site) {
            return True;
        }
    }
    return self._tensor_expr_provable(e, site);
}

impl TrapLoweringPass._torch_call(
    at: uni.UniNode, fname: str, args: list
) -> uni.FuncCall {
    torch_nm = self._gen_name(at, 'torch');
    fn_nm = self._gen_name(at, fname);
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

impl TrapLoweringPass._tensor_receiver_provable(
    x: uni.Expr, site: uni.UniNode
) -> bool {
    if not (isinstance(x, uni.FuncCall) and isinstance(x.target, uni.AtomTrailer)) {
        return False;
    }
    if self.prog.graphmend_scoped_compile {
        return True;
    }
    return self._tensor_expr_provable(x.target.target, site);
}

impl TrapLoweringPass._tensor_expr_provable(e: uni.Expr, site: uni.UniNode) -> bool {
    if isinstance(e, uni.AtomUnit) and isinstance(e.value, uni.Expr) {
        return self._tensor_expr_provable(e.value, site);
    }
    if isinstance(e, uni.Name) {
        return self._param_is_tensor(e.value, site);
    }
    if isinstance(e, uni.BinaryExpr) {
        return self._tensor_expr_provable(e.left, site)
            or self._tensor_expr_provable(e.right, site);
    }
    if isinstance(e, uni.CompareExpr) {
        if self._tensor_expr_provable(e.left, site) {
            return True;
        }
        for r in (e.rights or []) {
            if self._tensor_expr_provable(r, site) {
                return True;
            }
        }
        return False;
    }
    return False;
}

impl TrapLoweringPass._param_is_tensor(name: str, site: uni.UniNode) -> bool {
    ab = site.find_parent_of_type(uni.Ability);
    if ab is None {
        return False;
    }
    sig = ab.signature;
    if not isinstance(sig, uni.FuncSignature) {
        return False;
    }
    for p in (sig.get_parameters() or []) {
        if (p?.name is None) or (p.name.value != name) {
            continue;
        }
        ann = p.type_tag.tag if isinstance(p.type_tag, uni.SubTag) else p.type_tag;
        if isinstance(ann, uni.Name) {
            return self._binds_torch_tensor(ann);
        }
        return is_torch_attr_target(ann, 'Tensor');
    }
    return False;
}

impl TrapLoweringPass._torch_binds_module(site: uni.UniNode) -> bool {
    sym = site.sym_tab.lookup('torch');
    decl = sym.decl if (sym is not None) else None;
    mp = decl.find_parent_of_type(uni.ModulePath) if (decl is not None) else None;
    if (mp is None) or mp.is_import_from or (mp.alias is not None) {
        return False;
    }
    return mp.dot_path_str == 'torch';
}

impl TrapLoweringPass._binds_torch_tensor(ann: uni.Name) -> bool {
    decl = ann.sym.decl if (ann.sym is not None) else None;
    mi = decl.find_parent_of_type(uni.ModuleItem) if (decl is not None) else None;
    if mi is None {
        return False;
    }
    if not (isinstance(mi.name, uni.Name) and (mi.name.value == 'Tensor')) {
        return False;
    }
    mp = mi.parent.from_loc if isinstance(mi.parent, uni.Import) else None;
    return (mp is not None) and (mp.dot_path_str == 'torch');
}

impl TrapLoweringPass._replace(old: uni.UniNode, new_nodes: list) -> None {
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
