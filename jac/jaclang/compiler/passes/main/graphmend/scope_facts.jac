import jaclang.jac0core.unitree as uni;

def collect_scope_facts(
    mod: uni.Module,
    decor_classes: dict[str, list[str]],
    attr_types: dict[str, dict[str, str]],
    dict_attrs: dict[str, dict[str, str]]
) {
    for arch in mod.get_all_sub_nodes(uni.Archetype) {
        cls = arch.sym_name;
        if not cls {
            continue;
        }
        _collect_decorators(arch, cls, decor_classes);
        ctor = _class_init(arch);
        if ctor is None {
            continue;
        }
        _collect_attr_types(ctor, cls, attr_types);
        for ab in _init_reachable(arch, ctor) {
            _collect_dict_invariants(ab, cls, dict_attrs);
        }
    }
}

def _collect_decorators(
    arch: uni.Archetype, cls: str, decor_classes: dict[str, list[str]]
) {
    for ab in arch.get_all_sub_nodes(uni.Ability) {
        for dec in (ab.decorators or []) {
            base = dec.target if isinstance(dec, uni.FuncCall) else dec;
            if isinstance(base, uni.Name) {
                bucket = decor_classes.setdefault(base.value, []);
                if cls not in bucket {
                    bucket.append(cls);
                }
            }
        }
    }
}

def _class_init(arch: uni.Archetype) -> (uni.Ability | None) {
    for ab in arch.get_all_sub_nodes(uni.Ability) {
        if ab.sym_name == '__init__' {
            return ab;
        }
    }
    return None;
}

def _init_reachable(arch: uni.Archetype, ctor: uni.Ability) -> list[uni.Ability] {
    called: set[str] = set();
    for c in ctor.get_all_sub_nodes(uni.FuncCall) {
        t = c.target;
        if (
            isinstance(t, uni.AtomTrailer)
            and isinstance(t.right, uni.Name)
            and isinstance(t.target, uni.Name)
            and (t.target.value == 'self')
        ) {
            called.add(t.right.value);
        }
    }
    out: list[uni.Ability] = [ctor];
    for ab in arch.get_all_sub_nodes(uni.Ability) {
        if ab.sym_name in called {
            out.append(ab);
        }
    }
    return out;
}

def _collect_attr_types(
    ctor: uni.Ability, cls: str, attr_types: dict[str, dict[str, str]]
) {
    params: dict[str, str] = {};
    sig = ctor.signature;
    if isinstance(sig, uni.FuncSignature) {
        for p in (sig.get_parameters() or []) {
            if p?.name is None {
                continue;
            }
            ann = p.type_tag.tag if isinstance(p.type_tag, uni.SubTag) else p.type_tag;
            if isinstance(ann, uni.Name) {
                params[p.name.value] = ann.value;
            }
        }
    }
    if not params {
        return;
    }
    for a in ctor.get_all_sub_nodes(uni.Assignment) {
        if (len(a.target) != 1) or (not isinstance(a.value, uni.Name)) {
            continue;
        }
        t = a.target[0];
        if (
            isinstance(t, uni.AtomTrailer)
            and isinstance(t.right, uni.Name)
            and isinstance(t.target, uni.Name)
            and (t.target.value == 'self')
            and (a.value.value in params)
        ) {
            attr_types.setdefault(cls, {})[t.right.value] = params[a.value.value];
        }
    }
}

def _collect_dict_invariants(
    ab: uni.Ability, cls: str, dict_attrs: dict[str, dict[str, str]]
) {
    for stmt in ab.get_all_sub_nodes(uni.IfStmt) {
        if not _body_raises(stmt) {
            continue;
        }
        attr = _negated_dict_isinstance_attr(stmt);
        if attr is None {
            continue;
        }
        dict_attrs.setdefault(cls, {})[attr] = 'dict';
    }
    for stmt in ab.get_all_sub_nodes(uni.IfStmt) {
        if not _body_is_only_return(stmt) {
            continue;
        }
        attr = _is_none_check_attr(stmt.condition);
        if (attr is not None) and (dict_attrs.get(cls, {}).get(attr) == 'dict') {
            dict_attrs[cls][attr] = 'dict_or_none';
        }
    }
}

def _body_raises(stmt: uni.IfStmt) -> bool {
    for s in (stmt.body or []) {
        if isinstance(s, uni.RaiseStmt) {
            return True;
        }
    }
    return False;
}

def _body_is_only_return(stmt: uni.IfStmt) -> bool {
    body = stmt.body or [];
    return (len(body) == 1) and isinstance(body[0], uni.ReturnStmt);
}

def _negated_dict_isinstance_attr(stmt: uni.IfStmt) -> (str | None) {
    for c in stmt.condition.get_all_sub_nodes(uni.FuncCall) {
        if not (isinstance(c.target, uni.Name) and (c.target.value == 'isinstance')) {
            continue;
        }
        params = [
            p
            for p in (c.params or [])
            if not isinstance(p, uni.KWPair)
        ];
        if len(params) != 2 {
            continue;
        }
        (recv, ty) = (params[0], params[1]);
        if not (isinstance(ty, uni.Name) and (ty.value == 'dict')) {
            continue;
        }
        if not (
            isinstance(recv, uni.AtomTrailer)
            and isinstance(recv.right, uni.Name)
            and isinstance(recv.target, uni.Name)
            and (recv.target.value == 'self')
        ) {
            continue;
        }
        if _under_not(c, stmt) {
            return recv.right.value;
        }
    }
    return None;
}

def _under_not(nd: uni.UniNode, stop: uni.UniNode) -> bool {
    cur: (uni.UniNode | None) = nd.parent;
    while (cur is not None) and (cur is not stop) {
        if isinstance(cur, uni.UnaryExpr)
            and (cur.op is not None)
            and (cur.op.value == 'not') {
            return True;
        }
        cur = cur.parent;
    }
    return False;
}

def _is_none_check_attr(cond: uni.Expr) -> (str | None) {
    if not cond.get_all_sub_nodes(uni.Null) {
        return None;
    }
    for at in cond.get_all_sub_nodes(uni.AtomTrailer) {
        if (
            isinstance(at.right, uni.Name)
            and isinstance(at.target, uni.Name)
            and (at.target.value == 'self')
        ) {
            return at.right.value;
        }
    }
    return None;
}
