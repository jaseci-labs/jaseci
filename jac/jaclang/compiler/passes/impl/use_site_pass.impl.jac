import json;
import re;
import sys;
import from jaclang { JacRuntime as Jac }
import from jaclang.compiler.driver.mtp { FunctionInfo }
import from jaclang.compiler.passes.mtir_gen_pass { mtir_scope_str }
import from jaclang.compiler.tools.unparse_pass { unparse_node }

def _rep(key: str, val: str) -> str {
    text = val or '';
    if (not text) or re.search(r'[\s"\\]', text) {
        return key + '=' + json.dumps(text);
    }
    return key + '=' + text;
}

impl UseSitePass.postinit -> None {
    super.postinit();
}

impl UseSitePass.transform(ir_in: Module) -> Module {
    self.ir_out = ir_in;
    ir_in spawn self;
    out = self.ir_out;
    assert isinstance(out, Module);
    return out;
}

impl UseSitePass.run_walk with Module entry {
    self.ir_out = self._run_impl(here);
}

impl UseSitePass._run_impl(ir_in: Module) -> Module {
    prog = Jac.program;
    if prog is None {
        return ir_in;
    }
    mtir_map = prog.mtir_map;
    if not mtir_map {
        return ir_in;
    }
    rows: list[tuple[(str, UseSiteInfo)]] = [];
    for nd in ir_in.get_all_sub_nodes(Ability) {
        if not nd.is_genai_ability {
            continue;
        }
        scope = mtir_scope_str(nd);
        info = mtir_map.get(scope);
        if not isinstance(info, FunctionInfo) {
            continue;
        }
        us = self._analyze(ir_in, nd);
        info.use_site = us;
        rows.append((scope, us));
    }
    if rows and self._report_enabled() {
        self._emit_report(rows);
    }
    return ir_in;
}

impl UseSitePass._analyze(mod: Module, nd: Ability) -> UseSiteInfo {
    seen: dict[int, NameAtom] = {};
    ab_sym = nd.sym;
    if ab_sym is not None {
        for u in ab_sym.uses {
            seen[id(u)] = u;
        }
    }
    sites: list[FuncCall] = [];
    for u in seen.values() {
        if u.find_parent_of_type(Module) is not mod {
            continue;
        }
        p = u.parent;
        if isinstance(p, FuncCall) and p.target is u {
            sites.append(p);
        } elif isinstance(p, AtomTrailer) and p.right is u {
            gp = p.parent;
            if isinstance(gp, FuncCall) and gp.target is p {
                sites.append(gp);
            }
        }
    }
    if not sites {
        return self._reject('no call site in declaring module');
    }
    cands: list[tuple[((Ability | None), UseSiteInfo, list[tuple[(int, str)]])]] = [];
    for call in sites {
        (cd, cand, pairs) = self._analyze_site(nd, call);
        if not cand.resolved {
            return cand;
        }
        cands.append((cd, cand, pairs));
    }
    (cd0, first, merged) = cands[0];
    all_pairs: list[tuple[(int, str)]] = list(merged);
    for (cd, cand, pairs) in cands[1:] {
        if (id(cd) != id(cd0)) or (cand.param_name != first.param_name) {
            return self._reject('call sites resolve to different consumers');
        }
        all_pairs.extend(pairs);
    }
    first.fields_read = self._merge_fields(all_pairs);
    return first;
}

impl UseSitePass._analyze_site(
    nd: Ability, call: FuncCall
) -> tuple[((Ability | None), UseSiteInfo, list[tuple[(int, str)]])] {
    p = call.parent;
    if isinstance(p, FuncCall) and p.target is not call {
        for x in (p.params or []) {
            if x is call {
                (cd, us) = self._consumer_from(nd, p, call, []);
                return (cd, us, []);
            }
        }
    }
    if isinstance(p, KWPair) and p.value is call {
        gp = p.parent;
        if isinstance(gp, FuncCall) {
            for x in (gp.params or []) {
                if x is p {
                    (cd, us) = self._consumer_from(nd, gp, p, []);
                    return (cd, us, []);
                }
            }
        }
    }
    if not (isinstance(p, Assignment) and (p.value is call) and (p.aug_op is None)) {
        return (None, self._reject('result not bound to a single local'), []);
    }
    targets = list(p.target);
    tgt0: any = targets[0] if len(targets) == 1 else None;
    if not isinstance(tgt0, Name) {
        return (None, self._reject('result not bound to a single local'), []);
    }
    tgt_sym = tgt0.sym;
    if tgt_sym is None {
        return (None, self._reject('result not bound to a single local'), []);
    }
    return self._analyze_local(nd, tgt_sym, self._enclosing_fn_scope(p));
}

impl UseSitePass._analyze_local(
    nd: Ability, sym: Symbol, home: (UniNode | None)
) -> tuple[((Ability | None), UseSiteInfo, list[tuple[(int, str)]])] {
    if len(sym.defn) > 1 {
        return (None, self._reject('local is reassigned'), []);
    }
    seen: dict[int, NameAtom] = {};
    for u in sym.uses {
        seen[id(u)] = u;
    }
    arg_uses: list[tuple[(FuncCall, UniNode)]] = [];
    field_pairs: list[tuple[(int, str)]] = [];
    for u in seen.values() {
        if self._is_def_name(u) {
            continue;
        }
        pu = u.parent;
        if isinstance(pu, Assignment) and pu.aug_op is not None {
            for t in pu.target {
                if t is u {
                    return (None, self._reject('local is reassigned'), []);
                }
            }
        }
        if self._enclosing_fn_scope(u) is not home {
            return (None, self._reject('use escapes into a nested scope'), []);
        }
        if u.find_parent_of_type(ListCompr) is not None
            or u.find_parent_of_type(DictCompr) is not None
            or u.find_parent_of_type(InnerCompr) is not None {
            return (None, self._reject('use inside a comprehension'), []);
        }
        if u.find_parent_of_type(WhileStmt) is not None
            or u.find_parent_of_type(InForStmt) is not None
            or u.find_parent_of_type(IterForStmt) is not None {
            return (None, self._reject('use inside a loop'), []);
        }
        (kind, payload) = self._classify(u);
        if kind == 'field' {
            field_pairs.extend(payload);
        } elif kind == 'arg' {
            arg_uses.append(payload);
        } else {
            return (None, self._reject(payload), []);
        }
    }
    if not arg_uses {
        return (None, self._reject('no consumer call'), []);
    }
    outs: list[tuple[((Ability | None), UseSiteInfo)]] = [];
    for (call, arg) in arg_uses {
        (cd, cand) = self._consumer_from(nd, call, arg, field_pairs);
        if not cand.resolved {
            return (cd, cand, []);
        }
        outs.append((cd, cand));
    }
    (cd0, first) = outs[0];
    for (cd, cand) in outs[1:] {
        if id(cd) != id(cd0) {
            return (None, self._reject('uses reach more than one consumer'), []);
        }
        if cand.param_name != first.param_name {
            return (
                None,
                self._reject('uses reach different parameters of the consumer'),
                []
            );
        }
    }
    return (cd0, first, field_pairs);
}

impl UseSitePass._classify(u: NameAtom) -> tuple[(str, any)] {
    p = u.parent;
    if isinstance(p, AtomTrailer) and p.target is u {
        return self._walk_trailer_chain(u);
    }
    if isinstance(p, FuncCall) {
        if p.target is u {
            return ('reject', 'result called as a function');
        }
        for x in (p.params or []) {
            if x is u {
                return ('arg', (p, u));
            }
        }
        return ('reject', 'use is a transformed expression');
    }
    if isinstance(p, KWPair) and p.value is u {
        gp = p.parent;
        if isinstance(gp, FuncCall) {
            for x in (gp.params or []) {
                if x is p {
                    return ('arg', (gp, p));
                }
            }
        }
        return ('reject', 'use is a transformed expression');
    }
    if isinstance(p, ReturnStmt) {
        return ('reject', 'result escapes via return');
    }
    if isinstance(p, (ListVal, SetVal, TupleVal, KVPair)) {
        return ('reject', 'result escapes into a container');
    }
    if isinstance(p, Assignment) {
        return ('reject', 'result escapes into another binding');
    }
    if isinstance(p, ExprStmt) {
        return ('reject', 'result used as a bare statement');
    }
    return ('reject', 'use is a transformed expression');
}

impl UseSitePass._walk_trailer_chain(u: NameAtom) -> tuple[(str, any)] {
    pairs: list[tuple[(int, str)]] = [];
    cur: UniNode = u;
    tr = cur.parent;
    while isinstance(tr, AtomTrailer) and tr.target is cur {
        right = tr.right;
        if tr.is_attr and isinstance(right, Name) {
            pairs.append((right.loc.pos_start, right.sym_name));
        }
        cur = tr;
        tr = cur.parent;
    }
    if isinstance(tr, FuncCall) and tr.target is cur {
        return ('reject', 'result used as a method receiver');
    }
    if not pairs {
        return ('reject', 'use is a transformed expression');
    }
    return ('field', pairs);
}

impl UseSitePass._consumer_from(
    nd: Ability, call: FuncCall, arg_node: UniNode, field_pairs: list[tuple[(int, str)]]
) -> tuple[((Ability | None), UseSiteInfo)] {
    cd = call.callee_decl;
    if cd is None {
        return (None, self._reject('consumer could not be resolved'));
    }
    if cd is nd {
        return (None, self._reject('consumer is the producing ability itself'));
    }
    if cd.is_genai_ability {
        return (None, self._reject('consumer is itself a by-llm ability'));
    }
    cname = cd.py_resolve_name();
    sig = cd.signature;
    if cname.startswith('__ability_') or not isinstance(sig, FuncSignature) {
        return (None, self._reject('consumer has no ordinary signature'));
    }
    pv = self._param_for_arg(cd, sig, call, arg_node);
    if pv is None {
        return (None, self._reject('receiving parameter not identifiable'));
    }
    arch = cd.find_parent_of_type(Archetype);
    cd_sym = cd.sym;
    csem = cd_sym.semstr if cd_sym is not None else None;
    us = UseSiteInfo(
        resolved=True,
        reason='',
        consumer_name=cname,
        consumer_semstr=csem or None,
        consumer_module=cd.loc.mod_path or None,
        consumer_parent_class=arch.name.value if arch is not None else None,
        param_name=pv.name.value,
        param_semstr=self._param_semstr(pv),
        param_type=self._param_type_str(pv),
        fields_read=self._merge_fields(field_pairs)
    );
    return (cd, us);
}

impl UseSitePass._param_for_arg(
    cd: Ability, sig: FuncSignature, call: FuncCall, arg_node: UniNode
) -> (ParamVar | None) {
    if sig.varargs is not None or sig.kwargs is not None {
        return None;
    }

    positional = list(sig.posonly_params) + list(sig.params or []);
    by_name = list(sig.params or []) + list(sig.kwonlyargs);
    stripped = self._strip_receiver(cd, call, positional, by_name);
    if not stripped[0] {
        return None;
    }
    positional = stripped[1];
    by_name = stripped[2];
    args = list(call.params or []);
    if isinstance(arg_node, KWPair) {
        key = arg_node.key;
        if key is None {
            return None;
        }
        for p in by_name {
            if p.name.value == key.sym_name {
                return p;
            }
        }
        return None;
    }
    idx = -1;
    for i in range(len(args)) {
        if args[i] is arg_node {
            idx = i;
            break;
        }
    }
    if idx < 0 or idx >= len(positional) {
        return None;
    }
    for j in range(idx) {
        if isinstance(args[j], KWPair) {
            return None;
        }
    }
    return positional[idx];
}

impl UseSitePass._strip_receiver(
    cd: Ability, call: FuncCall, positional: list, by_name: list
) -> tuple[(bool, list, list)] {
    if cd.method_owner is None or cd.is_static {
        return (True, positional, by_name);
    }
    tgt = call.target;
    if not (isinstance(tgt, AtomTrailer) and tgt.is_attr) {
        return (False, [], []);
    }
    if positional and positional[0].name.value in ('self', 'cls') {
        return (True, positional[1:], by_name);
    }
    return (True, positional, by_name);
}

impl UseSitePass._param_semstr(pv: ParamVar) -> (str | None) {
    nm_sym = pv.name.sym;
    if nm_sym is not None and nm_sym.semstr {
        return nm_sym.semstr;
    }
    tag = pv.type_tag;
    tag_expr = tag.tag if tag is not None else None;
    if isinstance(tag_expr, AstSymbolNode) {
        ty_sym = tag_expr.sym;
        if ty_sym is not None and ty_sym.semstr {
            return ty_sym.semstr;
        }
    }
    return None;
}

impl UseSitePass._param_type_str(pv: ParamVar) -> str {
    tag = pv.type_tag;
    if tag is None {
        return '';
    }
    try {
        return self._norm_type(unparse_node(tag.tag));
    } except Exception {
        return '';
    }
}

impl UseSitePass._norm_type(text: str) -> str {
    out = re.sub(r"\s+", ' ', text);
    out = re.sub(r"\s*([\[\],|])\s*", r"\1", out);
    return out.strip();
}

impl UseSitePass._is_def_name(nm: NameAtom) -> bool {
    p = nm.parent;
    if isinstance(p, Assignment) and p.aug_op is None {
        for tgt in p.target {
            if tgt is nm {
                return True;
            }
        }
    }
    return False;
}

impl UseSitePass._enclosing_fn_scope(nd: UniNode) -> (UniNode | None) {
    cur = nd.parent;
    while cur is not None {
        if isinstance(cur, (Ability, LambdaExpr, Test, ModuleCode)) {
            return cur;
        }
        cur = cur.parent;
    }
    return None;
}

impl UseSitePass._merge_fields(pairs: list[tuple[(int, str)]]) -> list[str] {
    best: dict[str, int] = {};
    for (pos, nm) in pairs {
        prev = best.get(nm);
        if prev is None or pos < prev {
            best[nm] = pos;
        }
    }
    ordered: list[tuple[(int, str)]] = [(best[k], k) for k in best];
    ordered.sort();
    return [it[1] for it in ordered];
}

impl UseSitePass._reject(reason: str) -> UseSiteInfo {
    return UseSiteInfo(resolved=False, reason=reason, fields_read=[]);
}

impl UseSitePass._report_enabled -> bool {
    import os;
    return os.environ.get('JAC_USE_SITE_REPORT', '').strip().lower()
        in ('1', 'true', 'yes');
}

impl UseSitePass._emit_report(rows: list[tuple[(str, UseSiteInfo)]]) -> None {
    import sys;

    try {
        for (scope, us) in rows {
            parts: list[str] = ['[use-site]', _rep('scope', scope)];
            if us.resolved {
                label = f"{us.consumer_parent_class}.{us.consumer_name}"
                    if us.consumer_parent_class
                    else us.consumer_name;
                parts.append('resolved=yes');
                parts.append(_rep('consumer', label));
                parts.append(_rep('param', us.param_name));
                parts.append(_rep('type', us.param_type));
                parts.append(_rep('fields', ','.join(us.fields_read or [])));
                parts.append(_rep('consumer_module', us.consumer_module or ''));
            } else {
                parts.append('resolved=no');
                parts.append(_rep('reason', us.reason));
            }
            sys.stderr.write(' '.join(parts) + "\n");
        }
    } except Exception {}
}
