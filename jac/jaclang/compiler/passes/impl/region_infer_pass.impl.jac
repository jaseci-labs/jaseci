import from jaclang.compiler.frontend.unitree {
    Assignment,
    BinaryExpr,
    ConnectOp,
    CtrlStmt,
    ExprStmt,
    FuncSignature,
    ModuleCode,
    RaiseStmt,
    ReturnStmt,
    Symbol,
    Token,
    YieldExpr
}
import from jaclang.compiler.frontend.roles { BodyRole }
import from jaclang.compiler.frontend.constant { SymbolStorage, Tokens as Tok }

impl RegionInferPass.transform(ir_in: Module) -> Module {
    self.ir_out = ir_in;
    ir_in spawn self;
    out = self.ir_out;
    assert isinstance(out, Module);
    return out;
}

impl RegionInferPass.run_walk with Module entry {
    self.ir_out = self._run_impl(here);
}

impl RegionInferPass._run_impl(ir_in: Module) -> Module {
    owners: list[UniNode] = [];
    for ab in ir_in.get_all_sub_nodes(Ability) {
        if isinstance(ab.signature, FuncSignature)
            and isinstance(ab.body, (list, tuple)) {
            owners.append(ab);
        }
    }
    for mc in ir_in.get_all_sub_nodes(ModuleCode) {
        if isinstance(mc.body, (list, tuple)) {
            owners.append(mc);
        }
    }
    for owner in owners {
        body = list(owner.body);
        groups = self._scan_block(body);
        if not groups {
            continue;
        }
        ordered = sorted(groups, reverse=True);
        for grp in ordered {
            (open_idx, close_idx) = grp;
            self._wrap_in_open(owner, body, open_idx, close_idx);
        }
    }
    return ir_in;
}

impl RegionInferPass._is_def_name(nm: NameAtom) -> bool {
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

impl RegionInferPass._arch_of_call(expr: (UniNode | None)) -> (Archetype | None) {
    if not isinstance(expr, FuncCall) or not isinstance(expr.target, Name) {
        return None;
    }
    sym = expr.target.sym;
    if sym is None or sym.decl is None {
        return None;
    }
    decl = sym.decl;
    arch = decl if isinstance(decl, Archetype) else decl.find_parent_of_type(Archetype);
    if arch is not None and arch.name.value == expr.target.sym_name {
        return arch;
    }
    return None;
}

impl RegionInferPass._connect_chain_leaves(expr: UniNode) -> (list[Name] | None) {
    if isinstance(expr, BinaryExpr) and isinstance(expr.op, ConnectOp) {
        l = self._connect_chain_leaves(expr.left);
        r = self._connect_chain_leaves(expr.right);
        if l is None or r is None {
            return None;
        }
        return l + r;
    }
    if isinstance(expr, Name) {
        return [expr];
    }
    return None;
}

impl RegionInferPass._blessed_arch_call(fc: FuncCall, member_sids: set[int]) -> bool {
    par = fc.parent;
    if isinstance(par, Assignment) and par.value is fc {
        tgts = par.target if isinstance(par.target, (list, tuple)) else [(par.target)];
        if len(tgts) == 1
            and isinstance(tgts[0], Name)
            and tgts[0].sym is not None
            and id(tgts[0].sym) in member_sids {
            return True;
        }
    }
    if isinstance(par, BinaryExpr)
        and isinstance(par.op, Token)
        and par.op.name == Tok.KW_SPAWN
        and (par.left is fc or par.right is fc) {
        arch = self._arch_of_call(fc);
        return arch is not None and arch.arch_type.name == Tok.KW_WALKER;
    }
    if isinstance(par, ConnectOp) and par.conn_type is fc {
        return True;
    }
    return False;
}

impl RegionInferPass._extent_poisoned(
    body: Sequence[UniNode], open_idx: int, close_idx: int, member_sids: set[int]
) -> bool {
    for s2 in body[open_idx:close_idx + 1] {
        if isinstance(s2, (OpenStmt, ReturnStmt, CtrlStmt, RaiseStmt)) {
            return True;
        }
        if s2.get_all_sub_nodes(ReturnStmt)
            or s2.get_all_sub_nodes(CtrlStmt)
            or s2.get_all_sub_nodes(RaiseStmt)
            or s2.get_all_sub_nodes(YieldExpr)
            or s2.get_all_sub_nodes(OpenStmt) {
            return True;
        }
        for sub in s2.get_all_sub_nodes(Name) {
            if sub.sym_name in ("root", "here") {
                return True;
            }
        }
        for sub in s2.get_all_sub_nodes(FuncCall) {
            if self._arch_of_call(sub) is not None
                and not self._blessed_arch_call(sub, member_sids) {
                return True;
            }
        }
    }
    return False;
}

impl RegionInferPass._scan_block(body: Sequence[UniNode]) -> list[tuple[int, int]] {
    stmt_idx: dict[int, int] = {};
    for (i, s) in enumerate(body) {
        stmt_idx[id(s)] = i;
    }
    members: dict[int, tuple[Symbol, int]] = {};
    order: list[int] = [];
    bad: set[int] = set();
    for (i, s) in enumerate(body) {
        if not isinstance(s, Assignment) {
            continue;
        }
        tgts = s.target if isinstance(s.target, (list, tuple)) else [(s.target)];
        if len(tgts) != 1 or not isinstance(tgts[0], Name) {
            continue;
        }
        tsym = tgts[0].sym;
        if tsym is None
            or tsym.storage not in (SymbolStorage.LOCAL, SymbolStorage.MODULE_GLOBAL) {
            continue;
        }
        arch = self._arch_of_call(s.value);
        if arch is None or arch.arch_type.name != Tok.KW_NODE {
            continue;
        }
        sid = id(tsym);
        if sid in members {
            bad.add(sid);
            continue;
        }
        for d in tsym.defn {
            _dc: (UniNode | None) = d;
            while _dc is not None and id(_dc) not in stmt_idx {
                _dc = _dc.parent;
            }
            if _dc is None {
                bad.add(sid);
            }
        }
        members[sid] = (tsym, i);
        order.append(sid);
    }
    if not members {
        return [];
    }
    label: dict[int, int] = {};
    for (k, sid) in enumerate(order) {
        label[sid] = k;
    }
    spawned: set[int] = set();
    last_idx: dict[int, int] = {sid: members[sid][1] for sid in order};
    for sid in order {
        sym: Symbol = members[sid][0];
        uses: dict[int, NameAtom] = {};
        for u0 in sym.uses {
            if not self._is_def_name(u0) {
                uses[id(u0)] = u0;
            }
        }
        for u in uses.values() {
            _cur: (UniNode | None) = u;
            top: (UniNode | None) = None;
            while _cur is not None {
                if id(_cur) in stmt_idx {
                    top = _cur;
                    break;
                }
                _cur = _cur.parent;
            }
            if top is None {
                bad.add(sid);
                continue;
            }
            ti = stmt_idx[id(top)];
            expr = top.expr if isinstance(top, ExprStmt) else top;
            ok = False;
            if isinstance(expr, BinaryExpr) and isinstance(expr.op, ConnectOp) {
                leaves = self._connect_chain_leaves(expr);
                if leaves is not None {
                    good = True;
                    seen_u = False;
                    lsids: list[int] = [];
                    for lf in leaves {
                        if lf is u {
                            seen_u = True;
                        }
                        if lf.sym is None or id(lf.sym) not in members {
                            good = False;
                        } else {
                            lsids.append(id(lf.sym));
                        }
                    }
                    if good and seen_u {
                        ok = True;
                        for l2 in lsids {
                            if label[l2] != label[sid] {
                                _from = label[l2];
                                for s3 in order {
                                    if label[s3] == _from {
                                        label[s3] = label[sid];
                                    }
                                }
                            }
                        }
                    }
                }
            } elif isinstance(expr, BinaryExpr)
                and isinstance(expr.op, Token)
                and expr.op.name == Tok.KW_SPAWN
                and isinstance(top, ExprStmt)
                and (expr.left is u or expr.right is u) {
                ok = True;
                spawned.add(sid);
            }
            if not ok {
                bad.add(sid);
            } elif ti > last_idx[sid] {
                last_idx[sid] = ti;
            }
        }
    }
    groups: dict[int, list[int]] = {};
    for sid in order {
        lb = label[sid];
        if lb not in groups {
            groups[lb] = [];
        }
        groups[lb].append(sid);
    }
    out: list[tuple[int, int]] = [];
    used_ranges: list[tuple[int, int]] = [];
    for (lb, sids) in groups.items() {
        if any([(s in bad) for s in sids]) {
            continue;
        }
        if not any([(s in spawned) for s in sids]) {
            continue;
        }
        open_idx = -1;
        close_idx = -1;
        for s in sids {
            _oi: int = members[s][1];
            _ci: int = last_idx[s];
            if open_idx < 0 or _oi < open_idx {
                open_idx = _oi;
            }
            if _ci > close_idx {
                close_idx = _ci;
            }
        }
        if close_idx <= open_idx {
            continue;
        }
        if self._extent_poisoned(body, open_idx, close_idx, set(sids)) {
            continue;
        }
        overlap = False;
        for rng in used_ranges {
            (ro, rc) = rng;
            if not (close_idx < ro or rc < open_idx) {
                overlap = True;
            }
        }
        if overlap {
            continue;
        }
        used_ranges.append((open_idx, close_idx));
        out.append((open_idx, close_idx));
    }
    return out;
}

impl RegionInferPass._wrap_in_open(
    owner: UniNode, body: Sequence[UniNode], open_idx: int, close_idx: int
) -> (OpenStmt | None) {
    stmts = list(body[open_idx:close_idx + 1]);
    first = stmts[0];
    scope = first.sym_tab;
    region_sym = scope.lookup("Region");
    if region_sym is None {
        return None;
    }
    loc = first.loc;
    handle_name = Name(
        orig_src=self.ir_in.loc.orig_src,
        name=Tok.NAME,
        value="Region",
        line=loc.first_line,
        end_line=loc.first_line,
        col_start=loc.col_start,
        col_end=loc.col_start + len("Region"),
        pos_start=0,
        pos_end=0
    );
    handle_name.sym = region_sym;
    region_sym.add_use(handle_name);
    handle_call = FuncCall(
        target=handle_name, params=[], genai_call=None, kid=[handle_name]
    );
    opened = OpenStmt(target=handle_call, body=stmts, kid=[handle_call, *stmts]);
    kids = list(owner.kid);
    first_pos = -1;
    last_pos = -1;
    for (i, k) in enumerate(kids) {
        if k is first {
            first_pos = i;
        }
        if k is stmts[-1] {
            last_pos = i;
        }
    }
    if first_pos < 0 or last_pos < first_pos {
        return None;
    }
    with owner.structure_thawed() as _thaw {
        owner.set_kids(
            [*kids[:first_pos], opened, *kids[last_pos + 1:]], pos_update=False
        );
        owner._role_set(BodyRole, [*body[:open_idx], opened, *body[close_idx + 1:]]);
    }
    scope.link_kid_scope(opened);
    return opened;
}
