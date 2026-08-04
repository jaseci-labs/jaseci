import from jaclang.jac0core.diagnostics { E1308, E1313 }

impl OwnershipCheckPass._flow_for_stmts -> list[uni.InForStmt] {
    import from jaclang.jac0core.constant { Tokens as Tok }
    out: list[uni.InForStmt] = [];
    for lp in self.ir_in.get_all_sub_nodes(uni.InForStmt) {
        for k in lp.kid {
            if isinstance(k, uni.Token) and k.name == Tok.KW_FLOW {
                out.append(lp);
                break;
            }
        }
    }
    return out;
}

impl OwnershipCheckPass._emit_flow_for_diagnostics -> None {
    import from jaclang.jac0core.constant { Tokens as Tok }
    _flows = self._flow_for_stmts();
    if not _flows {
        return;
    }
    _flow_ids = {id(f) for f in _flows};
    for lp in _flows {
        _coll = lp.collection;
        if not (isinstance(_coll, uni.UnaryExpr) and is_borrow_kind(_coll.ownership)) {
            self.emit(
                E1313,
                node_override=_coll,
                name="a non-lent collection (iterate `&xs` or `&mut xs`)"
            );
        }
        _coll_sids: set[int] = set();
        for cn in _coll.get_all_sub_nodes(uni.Name) {
            _cs = self._sym_id(cn);
            if _cs is not None {
                _coll_sids.add(_cs);
            }
        }
        if isinstance(_coll, uni.Name) {
            _cs0 = self._sym_id(_coll);
            if _cs0 is not None {
                _coll_sids.add(_cs0);
            }
        }
        for inner in lp.get_all_sub_nodes(uni.InForStmt) {
            if id(inner) in _flow_ids {
                self.emit(E1313, node_override=inner, name="a nested `flow for`");
            }
        }
        _flagged: set[int] = set();
        for st in (lp.body or []) {
            _subs: list[uni.UniNode] = (
                [st]
                + list(st.get_all_sub_nodes(uni.ReturnStmt))
                + list(st.get_all_sub_nodes(uni.DisengageStmt))
                + list(st.get_all_sub_nodes(uni.YieldExpr))
                + list(st.get_all_sub_nodes(uni.CtrlStmt))
            );
            for sub in _subs {
                if isinstance(sub, uni.ReturnStmt) {
                    self.emit(
                        E1313, node_override=sub, name="a `return` in the loop body"
                    );
                } elif isinstance(sub, uni.DisengageStmt) {
                    self.emit(
                        E1313, node_override=sub, name="`disengage` in the loop body"
                    );
                } elif isinstance(sub, uni.YieldExpr) {
                    self.emit(
                        E1313, node_override=sub, name="a `yield` in the loop body"
                    );
                } elif isinstance(sub, uni.CtrlStmt)
                    and sub.ctrl is not None
                    and sub.ctrl.name == Tok.KW_BREAK {
                    _enc: (uni.UniNode | None) = sub.parent;
                    while _enc is not None
                        and not isinstance(
                            _enc, (uni.WhileStmt, uni.InForStmt, uni.IterForStmt)
                        ) {
                        _enc = _enc.parent;
                    }
                    if _enc is lp {
                        self.emit(
                            E1313,
                            node_override=sub,
                            name="a `break` out of the loop body"
                        );
                    }
                }
            }
            for nm in st.get_all_sub_nodes(uni.Name) {
                sym = nm.sym;
                if sym is None or sym.decl is None {
                    continue;
                }
                if self._is_ancestor(lp, sym.decl) {
                    continue;
                }
                if isinstance(nm.parent, uni.FuncCall) and nm.parent.target is nm {
                    continue;
                }
                _ab = sym.decl.find_parent_of_type(uni.Ability);
                if _ab is not None and _ab.name_ref is sym.decl {
                    continue;
                }
                sid = self._sym_id(nm);
                if sid is None or sid in _flagged or sid in _coll_sids {
                    continue;
                }
                _is_write = False;
                _wp = nm.parent;
                if isinstance(_wp, uni.Assignment) {
                    _wt = _wp.target
                        if isinstance(_wp.target, (list, tuple))
                        else [(_wp.target)];
                    for t in _wt {
                        if t is nm {
                            _is_write = True;
                        }
                    }
                }
                if not _is_write {
                    if self._is_deep_immutable_scalar(nm) {
                        continue;
                    }
                    if sym.ownership == OwnershipKind.IMM {
                        continue;
                    }
                }
                _flagged.add(sid);
                self.emit(E1308, node_override=nm, name=nm.sym_name);
            }
        }
    }
}

impl OwnershipCheckPass._emit_sendability_diagnostics -> None {
    tracked = set(self.owned_decl);
    tracked.update(self.borrow_meta);
    tracked.update(self.imm_decl);
    for nd in self.idx_assignments {
        for tgt in nd.target {
            if isinstance(tgt, uni.Name) and tgt.sym {
                tracked.add(id(tgt.sym));
            }
        }
    }
    for param in self.idx_params {
        if isinstance(param.name, uni.Name) and param.name.sym {
            tracked.add(id(param.name.sym));
        }
    }

    import from jaclang.jac0core.constant { Tokens as Tok }
    for cexpr in self.idx_concurrent {
        if cexpr.tok is not None and cexpr.tok.name == Tok.KW_WAIT {
            continue;
        }
        names: list[uni.Name] = [];
        if isinstance(cexpr.target, uni.Name) {
            names.append(cexpr.target);
        }
        for nm in cexpr.target.get_all_sub_nodes(uni.Name) {
            names.append(nm);
        }
        for nm in names {
            if not self._is_read_name(nm) {
                continue;
            }
            sid = self._sym_id(nm);
            if sid is None or sid not in tracked or nm.sym is None {
                continue;
            }
            if self._is_deep_immutable_scalar(nm) {
                continue;
            }
            ownership = nm.sym.ownership;
            if ownership == OwnershipKind.IMM {
                continue;
            }
            if ownership == OwnershipKind.OWN and self._is_move_producing_use(nm) {
                continue;
            }
            if ownership == OwnershipKind.OWN
                and isinstance(nm.parent, uni.UnaryExpr)
                and is_borrow_kind(nm.parent.ownership)
                and self._flow_lend_joined(cexpr, sid) {
                continue;
            }
            if nm.find_parent_of_type(uni.OpenStmt) is not None {
                continue;
            }
            if self._borrow_sym_of(nm) is not None {
                owner = self._escaping_borrow_owner(nm);
                if owner is not None {
                    borrow_id = self._borrow_sym_of(nm);
                    related = self._owner_decl_related(borrow_id, owner);
                    self.emit(E1308, node_override=nm, name=owner, related=related);
                } else {
                    self.emit(E1308, node_override=nm, name=nm.sym_name);
                }
            } else {
                self.emit(E1308, node_override=nm, name=nm.sym_name);
            }
            break;
        }
    }
}

impl OwnershipCheckPass._flow_lend_joined(
    cexpr: uni.ConcurrentExpr, owner_sid: SymId
) -> bool {
    import from jaclang.jac0core.constant { Tokens as Tok }
    asgn = cexpr.find_parent_of_type(uni.Assignment);
    if asgn is None
        or asgn.value is not cexpr
        or len(asgn.target) != 1
        or not isinstance(asgn.target[0], uni.Name)
        or asgn.target[0].sym is None {
        return False;
    }
    handle_sid = self._name_sym_id(asgn.target[0]);
    container = asgn.parent;
    _cbody = container?.body;
    if not isinstance(_cbody, (list, tuple)) or asgn not in _cbody {
        return False;
    }
    body: list[uni.UniNode] = [s for s in _cbody];
    idx = body.index(asgn);
    for st in body[idx + 1:] {
        _wait_found = False;
        _wait_nodes: list[uni.ConcurrentExpr] = [];
        for wc in st.get_all_sub_nodes(uni.ConcurrentExpr) {
            if wc.tok is not None and wc.tok.name == Tok.KW_WAIT {
                for wn in ([wc.target] if isinstance(wc.target, uni.Name) else [])
                    + list(wc.target.get_all_sub_nodes(uni.Name)) {
                    if self._sym_id(wn) == handle_sid {
                        _wait_found = True;
                        _wait_nodes.append(wc);
                    }
                }
            }
        }
        _owner_touched = False;
        for on in st.get_all_sub_nodes(uni.Name) {
            if self._sym_id(on) == owner_sid {
                _owner_touched = True;
            }
        }
        _exits: list[uni.UniNode] = (
            (
                [st]
                    if isinstance(st, (uni.ReturnStmt, uni.RaiseStmt, uni.CtrlStmt))
                    else []
            )
            + list(st.get_all_sub_nodes(uni.ReturnStmt))
            + list(st.get_all_sub_nodes(uni.RaiseStmt))
            + list(st.get_all_sub_nodes(uni.CtrlStmt))
            + list(st.get_all_sub_nodes(uni.YieldExpr))
        );
        _side_exit = False;
        for ex in _exits {
            _joins_first = False;
            for w in _wait_nodes {
                if ex is w or self._is_ancestor(ex, w) {
                    _joins_first = True;
                }
            }
            if not _joins_first {
                _side_exit = True;
            }
        }
        if _wait_found and not _side_exit {
            return not _owner_touched;
        }
        if _side_exit or _owner_touched {
            return False;
        }
    }
    return False;
}

impl OwnershipCheckPass._is_deep_immutable_scalar(nm: uni.Name) -> bool {
    t = nm.type;
    if t is None {
        return False;
    }
    _mangled = "";
    try {
        _mangled = t.mangle();
    } except Exception {
        return False;
    }
    return _mangled in ("int", "float", "bool", "str", "bytes");
}
