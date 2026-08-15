import os;
import sys;
import from pathlib { Path }
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.main.graphmend.ast_edit { split_params }
import from jaclang.compiler.passes.main.graphmend.torch_attr_table {
    decorator_base,
    has_torch_compile_decorator,
    is_torch_attr_target
}
import from jaclang.jac0core.passes.sym_resolve { symbol_ability, symbol_archetype }
import type from jaclang.jac0core.program { JacProgram }

def compiled_region_ids(
    prog: JacProgram,
    current: uni.Module,
    seen: set[str],
    wrapped: (list[uni.UniNode] | None) = None
) -> set[int] {
    mods: list[uni.Module] = [current];
    for m in prog.mod.hub.values() {
        if m is not current {
            mods.append(m);
        }
    }
    ids: set[int] = set();
    work: list[uni.Ability] = [];
    bounds = prog.graphmend_boundary;
    for m in mods {
        for arch in m.get_all_sub_nodes(uni.Archetype) {
            if has_torch_compile_decorator(arch) {
                ids.add(id(arch));
                for meth in arch.get_all_sub_nodes(uni.Ability) {
                    _seed(work, bounds, meth);
                }
            }
        }
        for ab in m.get_all_sub_nodes(uni.Ability) {
            if has_torch_compile_decorator(ab) {
                _seed(work, bounds, ab);
            }
        }
        for fwd in module_entry_forwards(prog, m, seen) {
            _seed(work, bounds, fwd);
        }
    }
    for w in (wrapped or []) {
        if isinstance(w, uni.Archetype) {
            for meth in w.get_all_sub_nodes(uni.Ability) {
                if meth.sym_name == 'forward' {
                    _seed(work, bounds, meth);
                }
            }
        } elif isinstance(w, uni.Ability) {
            _seed(work, bounds, w);
        }
    }
    while work {
        ab = work.pop();
        if id(ab) in ids {
            continue;
        }
        ids.add(id(ab));
        owner = bounds.get(id(ab)) or ab;
        callee: (uni.Ability | None) = None;
        for call in ab.get_all_sub_nodes(uni.FuncCall) {
            callee = _resolve_callee(ab, call, prog, seen);
            if (callee is not None) and (id(callee) not in ids) {
                bounds.setdefault(id(callee), owner);
                work.append(callee);
            }
        }
        for dec in (ab.decorators or []) {
            deco = _resolve_decorator(ab, dec, prog, seen);
            if deco is None {
                continue;
            }
            for closure in _wrapper_closures(deco) {
                if id(closure) not in ids {
                    bounds.setdefault(id(closure), owner);
                    work.append(closure);
                }
            }
        }
    }
    return ids;
}

def _seed(work: list[uni.Ability], bounds: dict[int, uni.Ability], ab: uni.Ability) {
    bounds[id(ab)] = ab;
    work.append(ab);
}

def region_context_key(prog: JacProgram, target_path: str) -> str {
    import hashlib;
    parts: list[str] = [];
    for (path, mod) in prog.mod.hub.items() {
        if path == target_path {
            continue;
        }
        parts.append(path + '\x00' + _hub_source_digest(prog, path, mod));
    }
    if not parts {
        return '';
    }
    h = hashlib.sha256();
    for part in sorted(parts) {
        h.update(part.encode('utf-8'));
        h.update(b"\n");
    }
    return h.hexdigest()[:16];
}

def _hub_source_digest(prog: JacProgram, path: str, mod: uni.Module) -> str {
    import hashlib;
    cached = prog.graphmend_hub_digests.get(path);
    if (cached is not None) and (cached[0] is mod) {
        return cached[1];
    }
    src = mod.source.value if (mod.source is not None) else '';
    digest = hashlib.sha256(src.encode('utf-8')).hexdigest()[:16];
    prog.graphmend_hub_digests[path] = (mod, digest);
    return digest;
}

def entry_key(ab: uni.Ability) -> str {
    parts: list[str] = [ab.sym_name];
    cur: (uni.UniNode | None) = ab.parent;
    while cur is not None {
        if isinstance(cur, (uni.Archetype, uni.Ability)) {
            parts.append(cur.sym_name);
        }
        cur = cur.parent;
    }
    parts.reverse();
    mod = ab.find_parent_of_type(uni.Module);
    path = _norm(mod.loc.mod_path) if (mod is not None) else '';
    return path + '::' + '.'.join(parts);
}

def module_entry_forwards(
    prog: JacProgram, mod: uni.Module, seen: set[str]
) -> list[uni.Ability] {
    out: list[uni.Ability] = [];
    if not module_binds_torch(mod) {
        return out;
    }
    for arch in mod.get_all_sub_nodes(uni.Archetype) {
        fwd: (uni.Ability | None) = None;
        for meth in arch.get_all_sub_nodes(uni.Ability) {
            if (meth.sym_name == 'forward')
                and (meth.find_parent_of_type(uni.Archetype) is arch) {
                fwd = meth;
            }
        }
        if fwd is None {
            continue;
        }
        if binds_torch_module_base(prog, arch, seen, 0) {
            out.append(fwd);
        }
    }
    return out;
}

def module_binds_torch(mod: uni.Module) -> bool {
    for mp in mod.get_all_sub_nodes(uni.ModulePath) {
        if mp.level != 0 {
            continue;
        }
        p = mp.dot_path_str;
        if (p == 'torch') or p.startswith('torch.') {
            return True;
        }
    }
    return False;
}

def binds_torch_module_base(
    prog: JacProgram, arch: uni.Archetype, seen: set[str], depth: int
) -> bool {
    if depth > 4 {
        return False;
    }
    mod = arch.find_parent_of_type(uni.Module);
    for base in (arch.base_classes or []) {
        if _is_torch_module_ref(base) {
            return True;
        }
        if mod is None {
            continue;
        }
        nm = _base_name(base);
        if nm is None {
            continue;
        }
        parent = find_class(mod, nm, prog, seen);
        if (parent is None) or (parent is arch) {
            continue;
        }
        if binds_torch_module_base(prog, parent, seen, depth + 1) {
            return True;
        }
    }
    return False;
}

def _base_name(base: uni.Expr) -> (str | None) {
    if isinstance(base, uni.Name) {
        return base.value;
    }
    if isinstance(base, uni.AtomTrailer) and isinstance(base.right, uni.Name) {
        return base.right.value;
    }
    return None;
}

def _is_torch_module_ref(base: uni.Expr) -> bool {
    if isinstance(base, uni.Name) and (base.value == 'Module') {
        return _binds_module_item(base, 'torch.nn', 'Module');
    }
    if not (isinstance(base, uni.AtomTrailer) and isinstance(base.right, uni.Name)) {
        return False;
    }
    if base.right.value != 'Module' {
        return False;
    }
    inner = base.target;
    if isinstance(inner, uni.Name) {
        return _binds_module_item(inner, 'torch', 'nn')
            or _binds_module_path(inner, 'torch.nn');
    }
    if (
        isinstance(inner, uni.AtomTrailer)
        and isinstance(inner.right, uni.Name)
        and (inner.right.value == 'nn')
        and isinstance(inner.target, uni.Name)
    ) {
        return _binds_module_path(inner.target, 'torch');
    }
    return False;
}

def _binds_module_item(nm: uni.Name, from_path: str, item_name: str) -> bool {
    decl = _sym_decl(nm);
    mi = decl.find_parent_of_type(uni.ModuleItem) if (decl is not None) else None;
    if mi is None {
        return False;
    }
    if not (isinstance(mi.name, uni.Name) and (mi.name.value == item_name)) {
        return False;
    }
    mp = mi.parent.from_loc if isinstance(mi.parent, uni.Import) else None;
    return (mp is not None) and (mp.dot_path_str == from_path);
}

def _binds_module_path(nm: uni.Name, dotted: str) -> bool {
    decl = _sym_decl(nm);
    mp = decl.find_parent_of_type(uni.ModulePath) if (decl is not None) else None;
    if (mp is None) or mp.is_import_from {
        return False;
    }
    return mp.dot_path_str == dotted;
}

def _sym_decl(nm: uni.Name) -> (uni.UniNode | None) {
    sym = nm.sym;
    if sym is None {
        st = nm.sym_tab;
        if st is None {
            return None;
        }
        sym = st.lookup(nm.value, deep=True);
    }
    if sym is None {
        return None;
    }
    return sym.decl;
}

def module_is_seed(prog: JacProgram, mod: uni.Module, seen: set[str]) -> bool {
    if not module_binds_torch(mod) {
        return False;
    }
    for call in mod.get_all_sub_nodes(uni.FuncCall) {
        if is_torch_attr_target(call.target, 'compile') {
            return True;
        }
    }
    for ab in mod.get_all_sub_nodes(uni.Ability) {
        if has_torch_compile_decorator(ab) {
            return True;
        }
    }
    for arch in mod.get_all_sub_nodes(uni.Archetype) {
        if has_torch_compile_decorator(arch) {
            return True;
        }
    }
    return len(module_entry_forwards(prog, mod, seen)) > 0;
}

def register_claim(prog: JacProgram, mod: uni.Module, seen: set[str]) -> bool {
    path = _norm(mod.loc.mod_path);
    if not path {
        return False;
    }
    if path not in prog.graphmend_claimed {
        if not module_is_seed(prog, mod, seen) {
            return False;
        }
        prog.graphmend_claimed.add(path);
    }
    if path in prog.graphmend_claim_walked {
        return True;
    }
    prog.graphmend_claim_walked.add(path);
    pkg_root = top_package_dir(path);
    for target in claim_targets(mod, pkg_root) {
        prog.graphmend_claimed.add(target);
        if target not in prog.graphmend_claim_parent {
            prog.graphmend_claim_parent[target] = path;
        }
    }
    return True;
}

def claim_chain_reaches(prog: JacProgram, chain_root: str, target: str) -> bool {
    cur = target;
    seen_paths: set[str] = set();
    while cur {
        if cur == chain_root {
            return True;
        }
        if cur in seen_paths {
            return False;
        }
        seen_paths.add(cur);
        nxt = prog.graphmend_claim_parent.get(cur);
        if nxt is None {
            return False;
        }
        cur = nxt;
    }
    return False;
}

def entry_module(key: str) -> str {
    return key.split('::')[0];
}

def claim_path(prog: JacProgram, path: str) -> bool {
    rp = _norm(path);
    known = rp in prog.graphmend_claimed;
    if known and (rp in prog.graphmend_claim_walked) {
        return True;
    }
    mod = load_module_for_claim(prog, rp);
    if mod is None {
        return known;
    }
    return register_claim(prog, mod, set());
}

def load_module_for_claim(prog: JacProgram, path: str) -> (uni.Module | None) {
    existing = prog.mod.hub.get(path);
    if existing is not None {
        return existing;
    }
    _saved_opts = prog._compile_options;
    try {
        return prog.compile(file_path=path, no_cgen=True, type_check=False);
    } except Exception {
        return None;
    } finally {
        prog._compile_options = _saved_opts;
    }
}

def claim_targets(mod: uni.Module, pkg_root: str) -> list[str] {
    out: list[str] = [];
    if not pkg_root {
        return out;
    }
    for imp in mod.get_all_sub_nodes(uni.Import) {
        if import_is_type_checking(imp) {
            continue;
        }
        for p in _import_paths(imp) {
            if _within(p, pkg_root) and (p not in out) {
                out.append(p);
            }
        }
    }
    return out;
}

def _import_paths(imp: uni.Import) -> list[str] {
    out: list[str] = [];
    from_loc = imp.from_loc;
    if from_loc is not None {
        if _denied_path(from_loc) {
            return out;
        }
        _add_resolved(out, from_loc);
        for item in imp.items {
            if isinstance(item, uni.ModuleItem) {
                _add_resolved_item(out, item);
            }
        }
        return out;
    }
    for item in imp.items {
        if isinstance(item, uni.ModulePath) and (not _denied_path(item)) {
            _add_resolved(out, item);
        }
    }
    return out;
}

def _denied_path(mp: uni.ModulePath) -> bool {
    if mp.level != 0 {
        return False;
    }
    top = mp.dot_path_str.lstrip('.').split('.')[0];
    return (top in {'torch', 'jaclang'}) or (top in sys.stdlib_module_names);
}

def _add_resolved(out: list[str], mp: uni.ModulePath) -> None {
    try {
        _keep(out, mp.resolve_relative_path());
    } except Exception {
        return;
    }
}

def _add_resolved_item(out: list[str], item: uni.ModuleItem) -> None {
    try {
        _keep(out, item.resolve_relative_path());
    } except Exception {
        return;
    }
}

def _keep(out: list[str], raw: str) -> None {
    if not (raw.endswith('.py') or raw.endswith('.jac')) {
        return;
    }
    if not os.path.isfile(raw) {
        return;
    }
    resolved = _norm(raw);
    if resolved not in out {
        out.append(resolved);
    }
}

def import_is_type_checking(imp: uni.Import) -> bool {
    child: uni.UniNode = imp;
    cur: (uni.UniNode | None) = imp.parent;
    while cur is not None {
        if isinstance(cur, uni.IfStmt) {
            in_body = False;
            for stmt in (cur.body or []) {
                if stmt is child {
                    in_body = True;
                }
            }
            if in_body and _cond_is_type_checking(cur.condition) {
                return True;
            }
        }
        child = cur;
        cur = cur.parent;
    }
    return False;
}

def _cond_is_type_checking(cond: uni.Expr) -> bool {
    if isinstance(cond, uni.Name) {
        return (cond.value == 'TYPE_CHECKING')
            and _binds_module_item(cond, 'typing', 'TYPE_CHECKING');
    }
    if (
        isinstance(cond, uni.AtomTrailer)
        and isinstance(cond.right, uni.Name)
        and (cond.right.value == 'TYPE_CHECKING')
        and isinstance(cond.target, uni.Name)
    ) {
        return _binds_module_path(cond.target, 'typing');
    }
    return False;
}

def top_package_dir(path: str) -> str {
    d = os.path.dirname(_norm(path));
    while _is_package_dir(d) {
        parent = os.path.dirname(d);
        if (parent == d) or (not _is_package_dir(parent)) {
            break;
        }
        d = parent;
    }
    return d;
}

def _is_package_dir(d: str) -> bool {
    for nm in ('__init__.py', '__init__.jac') {
        if os.path.isfile(os.path.join(d, nm)) {
            return True;
        }
    }
    return False;
}

def _within(path: str, pkg_root: str) -> bool {
    return (path == pkg_root) or path.startswith(pkg_root + os.sep);
}

def _norm(path: str) -> str {
    try {
        return str(Path(path).resolve());
    } except Exception {
        return path;
    }
}

def param_names(fn: uni.Ability) -> list[str] {
    out: list[str] = [];
    sig = fn.signature;
    if not isinstance(sig, uni.FuncSignature) {
        return out;
    }
    for p in (sig.get_parameters() or []) {
        if p?.name is not None {
            out.append(p.name.value);
        }
    }
    return out;
}

def _wrapper_closures(deco: uni.Ability) -> list[uni.Ability] {
    params = param_names(deco);
    out: list[uni.Ability] = [];
    if not params {
        return out;
    }
    for closure in deco.get_all_sub_nodes(uni.Ability) {
        for call in closure.get_all_sub_nodes(uni.FuncCall) {
            if isinstance(call.target, uni.Name) and (call.target.value in params) {
                out.append(closure);
                break;
            }
        }
    }
    return out;
}

def _resolve_decorator(
    site: uni.Ability, dec: uni.Expr, prog: JacProgram, seen: set[str]
) -> (uni.Ability | None) {
    base = decorator_base(dec);
    if not isinstance(base, uni.Name) {
        return None;
    }
    mod = site.find_parent_of_type(uni.Module);
    if mod is None {
        return None;
    }
    return find_ability(mod, base.value, prog, seen);
}

def self_attr_name(nd: (uni.Expr | None)) -> (str | None) {
    if (
        isinstance(nd, uni.AtomTrailer)
        and isinstance(nd.right, uni.Name)
        and isinstance(nd.target, uni.Name)
        and (nd.target.value == 'self')
    ) {
        return nd.right.value;
    }
    return None;
}

def lexical_ability(scope: (uni.Ability | None), name: str) -> (uni.Ability | None) {
    cur: (uni.Ability | None) = scope;
    while cur is not None {
        for nested in cur.get_all_sub_nodes(uni.Ability) {
            if nested.sym_name == name {
                return nested;
            }
        }
        cur = cur.find_parent_of_type(uni.Ability);
    }
    return None;
}

def _resolve_callee(
    site: uni.Ability, call: uni.FuncCall, prog: JacProgram, seen: set[str]
) -> (uni.Ability | None) {
    t = call.target;
    if isinstance(t, uni.Name) {
        found = lexical_ability(site, t.value);
        if found is not None {
            return found;
        }
        mod = site.find_parent_of_type(uni.Module);
        if mod is None {
            return None;
        }
        return find_ability(mod, t.value, prog, seen);
    }
    if not (isinstance(t, uni.AtomTrailer) and isinstance(t.right, uni.Name)) {
        return None;
    }
    arch = site.find_parent_of_type(uni.Archetype);
    if arch is None {
        return None;
    }
    attr = self_attr_name(t);
    if attr is not None {
        found = class_method(arch, attr, prog, seen, 0);
        if found is not None {
            return found;
        }
        held = _self_attr_archetype(arch, attr, prog, seen);
        if (held is None) or (not binds_torch_module_base(prog, held, seen, 0)) {
            return None;
        }
        return class_method(held, 'forward', prog, seen, 0);
    }
    holder = self_attr_name(t.target);
    if holder is None {
        return None;
    }
    owner = _self_attr_archetype(arch, holder, prog, seen);
    if owner is None {
        return None;
    }
    return class_method(owner, t.right.value, prog, seen, 0);
}

def class_method(
    arch: uni.Archetype, name: str, prog: JacProgram, seen: set[str], depth: int
) -> (uni.Ability | None) {
    found = symbol_ability(arch.lookup(name, deep=False));
    if (found is not None) or (depth > 4) {
        return found;
    }
    mod = arch.find_parent_of_type(uni.Module);
    if mod is None {
        return None;
    }
    for base in (arch.base_classes or []) {
        if (not isinstance(base, uni.Name)) or _is_torch_module_ref(base) {
            continue;
        }
        parent = find_class(mod, base.value, prog, seen);
        if (parent is None) or (parent is arch) {
            continue;
        }
        got = class_method(parent, name, prog, seen, depth + 1);
        if got is not None {
            return got;
        }
    }
    return None;
}

def _self_attr_archetype(
    arch: uni.Archetype, attr: str, prog: JacProgram, seen: set[str]
) -> (uni.Archetype | None) {
    ctor = class_init(arch);
    mod = arch.find_parent_of_type(uni.Module);
    if (ctor is None) or (mod is None) {
        return None;
    }
    hits: list[uni.Assignment] = [];
    for ab in _init_reachable(arch, ctor) {
        for a in ab.get_all_sub_nodes(uni.Assignment) {
            if (len(a.target or []) == 1) and (self_attr_name(a.target[0]) == attr) {
                hits.append(a);
            }
        }
    }
    if len(hits) != 1 {
        return None;
    }
    v = hits[0].value;
    if isinstance(v, uni.FuncCall) and isinstance(v.target, uni.Name) {
        return find_class(mod, v.target.value, prog, seen);
    }
    if isinstance(v, uni.Name) {
        ann = attr_annotation(arch, attr);
        return find_class(mod, ann, prog, seen) if (ann is not None) else None;
    }
    return None;
}

def find_ability(
    mod: uni.Module, name: str, prog: JacProgram, seen: set[str]
) -> (uni.Ability | None) {
    found = symbol_ability(mod.lookup(name, deep=False));
    if found is not None {
        return found;
    }
    for imp in mod.get_all_sub_nodes(uni.Import) {
        if imp.from_loc is None {
            continue;
        }
        top = imp.from_loc.dot_path_str.lstrip('.').split('.')[0];
        if (top in {'torch', 'jaclang'}) or (top in sys.stdlib_module_names) {
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
        got = find_ability(m2, target, prog, seen);
        if got is not None {
            return got;
        }
    }
    return None;
}

def find_class(
    mod: uni.Module, name: str, prog: JacProgram, seen: set[str]
) -> (uni.Archetype | None) {
    found = symbol_archetype(mod.lookup(name, deep=False));
    if found is not None {
        return found;
    }
    for imp in mod.get_all_sub_nodes(uni.Import) {
        if (imp.from_loc is None) or _denied_path(imp.from_loc) {
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
    _saved_opts = prog._compile_options;
    try {
        return prog.compile(file_path=path, no_cgen=True, type_check=False);
    } except Exception {
        return None;
    } finally {
        prog._compile_options = _saved_opts;
    }
}

def module_imports_plain(mod: uni.Module, name: str) -> bool {
    found = False;
    for mp in mod.get_all_sub_nodes(uni.ModulePath) {
        if (mp.alias is None)
            and (not mp.is_import_from)
            and (mp.dot_path_str == name) {
            found = True;
        }
    }
    if not found {
        return False;
    }
    for a in mod.get_all_sub_nodes(uni.Assignment) {
        if a.find_parent_of_type(uni.Ability) is not None {
            continue;
        }
        for t in (a.target or []) {
            targets = list(t.values) if isinstance(t, uni.TupleVal) else [t];
            for tg in targets {
                if isinstance(tg, uni.Name) and (tg.value == name) {
                    return False;
                }
            }
        }
    }
    for ab in mod.get_all_sub_nodes(uni.Ability) {
        if ab.sym_name == name {
            return False;
        }
    }
    return True;
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
            if (id(arch) not in ids) and _decorated_with(arch, decorator) {
                ids.add(id(arch));
                out.append(arch);
            }
        }
    }
    return out;
}

def _decorated_with(arch: uni.Archetype, decorator: str) -> bool {
    for ab in arch.get_all_sub_nodes(uni.Ability) {
        for dec in (ab.decorators or []) {
            base = decorator_base(dec);
            if isinstance(base, uni.Name) and (base.value == decorator) {
                return True;
            }
        }
    }
    return False;
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
        if (self_attr_name(t) == attr) and (a.value.value in params) {
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
    is_dict = False;
    or_none = False;
    for ab in _init_reachable(arch, ctor) {
        for stmt in ab.get_all_sub_nodes(uni.IfStmt) {
            if _body_raises(stmt) and (_negated_dict_isinstance_attr(stmt) == attr) {
                is_dict = True;
            }
            if body_is_only(stmt.body, uni.ReturnStmt)
                and (_is_none_check_attr(stmt.condition) == attr) {
                or_none = True;
            }
        }
    }
    if not is_dict {
        return None;
    }
    return 'dict_or_none' if or_none else 'dict';
}

def _init_reachable(arch: uni.Archetype, ctor: uni.Ability) -> list[uni.Ability] {
    called: set[str] = set();
    for c in ctor.get_all_sub_nodes(uni.FuncCall) {
        attr = self_attr_name(c.target);
        if attr is not None {
            called.add(attr);
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

def body_is_only(body: any, typ: any) -> bool {
    stmts = body or [];
    return (len(stmts) == 1) and isinstance(stmts[0], typ);
}

def _body_raises(stmt: uni.IfStmt) -> bool {
    for s in (stmt.body or []) {
        if isinstance(s, uni.RaiseStmt) {
            return True;
        }
    }
    return False;
}

def _negated_dict_isinstance_attr(stmt: uni.IfStmt) -> (str | None) {
    for c in stmt.condition.get_all_sub_nodes(uni.FuncCall) {
        if not (isinstance(c.target, uni.Name) and (c.target.value == 'isinstance')) {
            continue;
        }
        params = split_params(c.params)[0];
        if len(params) != 2 {
            continue;
        }
        (recv, ty) = (params[0], params[1]);
        if not (isinstance(ty, uni.Name) and (ty.value == 'dict')) {
            continue;
        }
        attr = self_attr_name(recv);
        if attr is None {
            continue;
        }
        if _under_not(c, stmt) {
            return attr;
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
        attr = self_attr_name(at);
        if attr is not None {
            return attr;
        }
    }
    return None;
}
