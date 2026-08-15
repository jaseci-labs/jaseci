import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { GraphBreakKind }
import from jaclang.compiler.passes.main.graphmend.scope_facts {
    compiled_region_ids,
    entry_key,
    find_ability,
    find_class,
    register_claim
}
import from jaclang.compiler.passes.main.graphmend.torch_attr_table {
    cond_is_data_dependent,
    defining_assignment,
    is_side_effect_name,
    is_torch_attr_target
}

impl GraphBreakDetectPass.before_pass -> None {
    self._enabled = self.prog._compile_options.graphmend is True;
    if not self._enabled {
        self.prune_signal = True;
        return;
    }
    register_claim(self.prog, self.ir_in, self._mat_seen);
    wrapped = self._collect_entry_points();
    self._entry_ids = set();
    for e in wrapped {
        if isinstance(e, uni.Ability) {
            self._entry_ids.add(id(e));
            self.prog.graphmend_wrapped.add(entry_key(e));
        } elif isinstance(e, uni.Archetype) {
            for meth in e.get_all_sub_nodes(uni.Ability) {
                if meth.sym_name == 'forward' {
                    self.prog.graphmend_wrapped.add(entry_key(meth));
                }
            }
        }
    }
    self._entry_ids |= compiled_region_ids(
        self.prog, self.ir_in, self._mat_seen, wrapped
    );
    members: list[uni.UniNode] = [];
    members.extend(self.ir_in.get_all_sub_nodes(uni.Ability));
    members.extend(self.ir_in.get_all_sub_nodes(uni.Archetype));
    local = False;
    for member in members {
        if id(member) in self._entry_ids {
            local = True;
            break;
        }
    }
    self._record_noop(local);
    if not local {
        self._enabled = False;
        self.prune_signal = True;
        return;
    }
    self._spine_ids = set();
    for member in members {
        if id(member) in self._entry_ids {
            cur: (uni.UniNode | None) = member.parent;
            while cur is not None {
                self._spine_ids.add(id(cur));
                cur = cur.parent;
            }
        }
    }
}

impl GraphBreakDetectPass._record_noop(local: bool) -> None {
    path = self.ir_in.loc.mod_path;
    if (not local) and (not self._saw_compile_call) {
        self.prog.graphmend_noop_mods.add(path);
    } else {
        self.prog.graphmend_noop_mods.discard(path);
    }
}

impl GraphBreakDetectPass.enter_ability(nd: uni.Ability) -> None {
    if not self._enabled {
        return;
    }
    if (id(nd) in self._entry_ids) or (id(nd) in self._spine_ids) {
        return;
    }
    if self._in_torch_compiled_scope(nd) {
        return;
    }
    self.prune_signal = True;
}

impl GraphBreakDetectPass._collect_entry_points -> list[uni.UniNode] {
    out: list[uni.UniNode] = [];
    ids: set[int] = set();
    for call in self.ir_in.get_all_sub_nodes(uni.FuncCall) {
        if is_torch_attr_target(call.target, 'compile') {
            self._saw_compile_call = True;
            entry = self._resolve_wrapped_entry(call);
            if (entry is not None) and (id(entry) not in ids) {
                ids.add(id(entry));
                out.append(entry);
            }
        }
    }
    return out;
}

impl GraphBreakDetectPass._resolve_wrapped_entry(
    call: uni.FuncCall
) -> (uni.UniNode | None) {
    arg: (uni.Expr | None) = None;
    for p in (call.params or []) {
        if not isinstance(p, uni.KWPair) {
            arg = p;
            break;
        }
    }
    if arg is None {
        return None;
    }
    inner = arg.target if isinstance(arg, uni.FuncCall) else arg;
    if not isinstance(inner, uni.Name) {
        return None;
    }
    resolved = self._def_node(inner.value, call);
    if resolved is not None {
        return resolved;
    }
    imported = self._import_def_node(inner.value, call);
    if imported is not None {
        return imported;
    }
    assign = self._var_assignment(inner.value, call);
    if (assign is not None) and (assign.value is not None) {
        v = assign.value;
        cls = v.target if isinstance(v, uni.FuncCall) else v;
        if isinstance(cls, uni.Name) {
            local = self._def_node(cls.value, call);
            if local is not None {
                return local;
            }
            return self._import_def_node(cls.value, call);
        }
    }
    return None;
}

impl GraphBreakDetectPass._import_def_node(
    name: str, ctx: uni.UniNode
) -> (uni.UniNode | None) {
    mod = ctx.find_parent_of_type(uni.Module);
    if mod is None {
        return None;
    }
    cls = find_class(mod, name, self.prog, self._mat_seen);
    if cls is not None {
        return cls;
    }
    return find_ability(mod, name, self.prog, self._mat_seen);
}

impl GraphBreakDetectPass._def_node(
    name: str, ctx: uni.UniNode
) -> (uni.UniNode | None) {
    st = ctx.sym_tab;
    if not st {
        return None;
    }
    sym = st.lookup(name, deep=True);
    if (not sym) or (not sym.defn) {
        return None;
    }
    cur: (uni.UniNode | None) = sym.defn[0];
    while cur {
        if isinstance(cur, (uni.Ability, uni.Archetype)) {
            return cur;
        }
        cur = cur.parent;
    }
    return None;
}

impl GraphBreakDetectPass._var_assignment(
    name: str, ctx: uni.UniNode
) -> (uni.Assignment | None) {
    st = ctx.sym_tab;
    if not st {
        return None;
    }
    sym = st.lookup(name, deep=True);
    if not sym {
        return None;
    }
    return defining_assignment(sym);
}

impl GraphBreakDetectPass._in_torch_compiled_scope(nd: uni.UniNode) -> bool {
    cur = nd.parent;
    while cur {
        if id(cur) in self._entry_ids {
            return True;
        }
        cur = cur.parent;
    }
    return False;
}

impl GraphBreakDetectPass.enter_func_call(nd: uni.FuncCall) -> None {
    if not self._enabled {
        return;
    }
    if not self._in_torch_compiled_scope(nd) {
        return;
    }
    name = self._call_name(nd);
    if (name is not None) and is_side_effect_name(name) {
        if self._is_user_defined(nd, name) {
            return;
        }
        target = nd.target;
        if isinstance(target, uni.AtomTrailer) {
            if not self._base_binds_logger(target) {
                return;
            }
        } elif name != 'print' {
            return;
        }
        self.prog.graphmend_breaks[nd] = GraphBreakKind.SIDE_EFFECT;
    }
}

impl GraphBreakDetectPass._base_binds_logger(t: uni.AtomTrailer) -> bool {
    base = t.target;
    if not isinstance(base, uni.Name) {
        return False;
    }
    st = base.sym_tab;
    sym = st.lookup(base.value, deep=True) if st else None;
    if sym is None {
        return False;
    }
    decl = sym.decl;
    if decl is not None {
        mi = decl.find_parent_of_type(uni.ModuleItem);
        if (mi is not None) and isinstance(mi.name, uni.Name) {
            local = mi.alias.value if (mi.alias is not None) else mi.name.value;
            if local == 'logging' {
                return True;
            }
        }
        mp = decl.find_parent_of_type(uni.ModulePath);
        if (mp is not None)
            and (mp.dot_path_str.lstrip('.').split('.')[-1] == 'logging') {
            return True;
        }
    }
    assign = defining_assignment(sym);
    v = assign.value if (assign is not None) else None;
    if not isinstance(v, uni.FuncCall) {
        return False;
    }
    leaf = v.target.right if isinstance(v.target, uni.AtomTrailer) else v.target;
    return isinstance(leaf, uni.Name) and (leaf.value in {'getLogger', 'get_logger'});
}

impl GraphBreakDetectPass._call_name(nd: uni.FuncCall) -> (str | None) {
    target = nd.target;
    if isinstance(target, uni.Name) {
        return target.value;
    }
    if (isinstance(target, uni.AtomTrailer) and isinstance(target.right, uni.Name)) {
        return target.right.value;
    }
    return None;
}

impl GraphBreakDetectPass._is_user_defined(nd: uni.FuncCall, name: str) -> bool {
    st = nd.sym_tab;
    if not st {
        return False;
    }
    sym = st.lookup(name, deep=True);
    return bool(sym and sym.defn);
}

impl GraphBreakDetectPass.enter_if_stmt(nd: uni.IfStmt) -> None {
    if not self._enabled {
        return;
    }
    if isinstance(nd, uni.ElseIf) {
        return;
    }
    if not self._in_torch_compiled_scope(nd) {
        return;
    }
    if not cond_is_data_dependent(nd.condition) {
        return;
    }
    if self._body_is_only_raise(nd.body) {
        self.prog.graphmend_breaks[nd] = GraphBreakKind.VAL_GUARD;
    } else {
        self.prog.graphmend_breaks[nd] = GraphBreakKind.DYN_CTRL_FL;
    }
}

impl GraphBreakDetectPass._body_is_only_raise(
    body: Sequence[uni.CodeBlockStmt]
) -> bool {
    if (not body) or (len(body) != 1) {
        return False;
    }
    return isinstance(body[0], uni.RaiseStmt);
}
