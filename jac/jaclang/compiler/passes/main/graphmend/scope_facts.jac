import from pathlib { Path }
import jaclang.jac0core.unitree as uni;
import type from jaclang.jac0core.program { JacProgram }

def find_class(
    mod: uni.Module, name: str, prog: JacProgram, seen: set[str]
) -> (uni.Archetype | None) {
    for arch in mod.get_all_sub_nodes(uni.Archetype) {
        if arch.sym_name == name {
            return arch;
        }
    }
    for imp in mod.get_all_sub_nodes(uni.Import) {
        if imp.from_loc is None {
            continue;
        }
        target = _import_target(imp, name);
        if target is None {
            continue;
        }
        m2 = materialize_module(prog, imp.from_loc, seen);
        if m2 is None {
            continue;
        }
        got = find_class(m2, target, prog, seen);
        if got is not None {
            return got;
        }
    }
    return None;
}

def _import_target(imp: uni.Import, name: str) -> (str | None) {
    for item in imp.items {
        if not isinstance(item, uni.ModuleItem) {
            continue;
        }
        if not isinstance(item.name, uni.Name) {
            continue;
        }
        local = item.alias.value if (item.alias is not None) else item.name.value;
        if local == name {
            return item.name.value;
        }
    }
    return None;
}

def materialize_module(
    prog: JacProgram, mp: uni.ModulePath, seen: set[str]
) -> (uni.Module | None) {
    try {
        path = str(Path(mp.resolve_relative_path()).resolve());
    } except Exception {
        return None;
    }
    if not (path.endswith('.py') or path.endswith('.jac')) {
        return None;
    }
    if path in seen {
        return prog.mod.hub.get(path);
    }
    seen.add(path);
    existing = prog.mod.hub.get(path);
    if existing is not None {
        return existing;
    }
    try {
        return prog.compile(file_path=path, no_cgen=True, type_check=False);
    } except Exception {
        return None;
    }
}

def wrapping_classes(
    prog: JacProgram, current: uni.Module, decorator: str
) -> list[uni.Archetype] {
    out: list[uni.Archetype] = [];
    ids: set[int] = set();
    mods: list[uni.Module] = [current];
    for m in prog.mod.hub.values() {
        if m is not current {
            mods.append(m);
        }
    }
    for m in mods {
        for arch in m.get_all_sub_nodes(uni.Archetype) {
            if id(arch) in ids {
                continue;
            }
            for ab in arch.get_all_sub_nodes(uni.Ability) {
                found = False;
                for dec in (ab.decorators or []) {
                    base = dec.target if isinstance(dec, uni.FuncCall) else dec;
                    if isinstance(base, uni.Name) and (base.value == decorator) {
                        ids.add(id(arch));
                        out.append(arch);
                        found = True;
                        break;
                    }
                }
                if found {
                    break;
                }
            }
        }
    }
    return out;
}

def class_init(arch: uni.Archetype) -> (uni.Ability | None) {
    for ab in arch.get_all_sub_nodes(uni.Ability) {
        if ab.sym_name == '__init__' {
            return ab;
        }
    }
    return None;
}

def attr_annotation(arch: uni.Archetype, attr: str) -> (str | None) {
    ctor = class_init(arch);
    if ctor is None {
        return None;
    }
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
        return None;
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
            and (t.right.value == attr)
            and (a.value.value in params)
        ) {
            return params[a.value.value];
        }
    }
    return None;
}

def attr_dict_kind(arch: uni.Archetype, attr: str) -> (str | None) {
    ctor = class_init(arch);
    if ctor is None {
        return None;
    }
    kind: (str | None) = None;
    for ab in _init_reachable(arch, ctor) {
        for stmt in ab.get_all_sub_nodes(uni.IfStmt) {
            if _body_raises(stmt) and (_negated_dict_isinstance_attr(stmt) == attr) {
                kind = 'dict';
            }
        }
    }
    if kind is None {
        return None;
    }
    for ab in _init_reachable(arch, ctor) {
        for stmt in ab.get_all_sub_nodes(uni.IfStmt) {
            if _body_is_only_return(stmt)
                and (_is_none_check_attr(stmt.condition) == attr) {
                kind = 'dict_or_none';
            }
        }
    }
    return kind;
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
