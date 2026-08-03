impl _trace_enabled -> bool {
    val = os.environ.get('JAC_QUERY_TRACE', '');
    return val.lower() in ('1', 'true', 'yes', 'on', 'plan');
}


impl _build_view(mem: Memory, q: GraphQuery) -> _View {
    view = _View();
    for anchor in list(mem.get_mem().values()) {
        if not isinstance(anchor, EdgeAnchor) or not anchor.is_populated() {
            continue;
        }
        if not _edge_alive(anchor) {
            view.detached.add(anchor.id);
        } elif anchor.hash == 0 {
            view.fresh.append(anchor);
            view.live_edges[anchor.id] = anchor;
        }
    }
    for arch in q.origin {
        oanch = arch.__jac__;
        if isinstance(oanch, NodeAnchor) and oanch.is_populated() {
            view.live_nodes[oanch.id] = oanch;
        }
    }
    return view;
}


impl _edge_alive(ea: EdgeAnchor) -> bool {
    src = ea.source;
    if src is None or not src.is_populated() {
        return True;
    }
    for e in src.edges {
        if e.id == ea.id {
            return True;
        }
    }
    return False;
}


impl _live_row(
    ea: EdgeAnchor, cur: set[UUID], hop: QHop
) -> (tuple[UUID, UUID] | None) {
    src = ea.source;
    tgt = ea.target;
    if src is None or tgt is None {
        return None;
    }
    other: (NodeAnchor | None) = None;
    if hop.dir == 1 {
        if tgt.id in cur {
            other = src;
        } elif ea.is_undirected and src.id in cur {
            other = tgt;
        }
    } elif hop.dir == 3 {
        if src.id in cur {
            other = tgt;
        } elif tgt.id in cur {
            other = src;
        }
    } else {
        if src.id in cur {
            other = tgt;
        } elif ea.is_undirected and tgt.id in cur {
            other = src;
        }
    }
    if other is None {
        return None;
    }
    if hop.`edge is not None and not isinstance(ea.archetype, hop.`edge) {
        return None;
    }
    nd = hop.nd;
    if nd is not None {
        if not other.is_populated() or other.archetype is None {
            return None;
        }
        types = nd if isinstance(nd, tuple) else (nd, );
        for nt in types {
            if not isinstance(other.archetype, nt) {
                return None;
            }
        }
    }
    return (ea.id, other.id);
}


impl _node_pred_keep(
    mem: Memory, view: _View, ids: list[UUID], preds: list[QPred]
) -> list[UUID] {
    if not preds or not ids {
        return ids;
    }
    resident: dict[UUID, Anchor] = {};
    remote: list[UUID] = [];
    pool = mem.get_mem();
    for i in ids {
        a = pool.get(i) or view.live_nodes.get(i);
        if a is not None and a.is_populated() and a.archetype is not None {
            resident[i] = a;
        } else {
            remote.append(i);
        }
    }
    remote_keep: set[UUID] = set();
    if remote {
        engine_keep = mem.filter_ids(remote, preds);
        assert engine_keep is not None , (
            "non-resident ids require an engine filter_ids implementation"
        );
        remote_keep = engine_keep;
    }
    out: list[UUID] = [];
    for i in ids {
        if i in resident {
            arch = resident[i].archetype;
            if all(p.matches(getattr(arch, p.field, None)) for p in preds) {
                out.append(i);
            }
        } elif i in remote_keep {
            out.append(i);
        }
    }
    return out;
}


impl _edge_pred_keep(
    mem: Memory, view: _View, rows: list[tuple[UUID, UUID]], epreds: list[QPred]
) -> list[tuple[UUID, UUID]] {
    if not epreds or not rows {
        return rows;
    }
    pool = mem.get_mem();
    resident: dict[UUID, Anchor] = {};
    remote: list[UUID] = [];
    for (eid, _) in rows {
        a = pool.get(eid) or view.live_edges.get(eid);
        if a is not None and a.is_populated() and a.archetype is not None {
            resident[eid] = a;
        } else {
            remote.append(eid);
        }
    }
    remote_keep: set[UUID] = set();
    if remote {
        engine_keep = mem.filter_ids(remote, epreds);
        assert engine_keep is not None , (
            "non-resident edge ids require an engine filter_ids implementation"
        );
        remote_keep = engine_keep;
    }
    out: list[tuple[UUID, UUID]] = [];
    for (eid, nid) in rows {
        if eid in resident {
            arch = resident[eid].archetype;
            if all(p.matches(getattr(arch, p.field, None)) for p in epreds) {
                out.append((eid, nid));
            }
        } elif eid in remote_keep {
            out.append((eid, nid));
        }
    }
    return out;
}


impl _hop_once(
    mem: Memory, view: _View, cur: list[UUID], hop: QHop, hop_idx: int
) -> list[UUID] {
    cur_set = set(cur);
    engine_rows = mem.hop_rows(cur, hop, ordered=True);
    rows: list[tuple[UUID, UUID]] = [];
    n_engine = 0;
    seen_eids: set[UUID] = set();
    if engine_rows is not None {
        for (eid, nid) in engine_rows {
            if eid in view.detached or eid in view.live_edges {
                continue;
            }
            seen_eids.add(eid);
            rows.append((eid, nid));
            n_engine += 1;
        }
    }
    live_edges: list[EdgeAnchor] = [];
    for ea in view.fresh {
        if ea.id not in seen_eids {
            seen_eids.add(ea.id);
            live_edges.append(ea);
        }
    }
    pool = mem.get_mem();
    for nid in cur {
        nanch = pool.get(nid) or view.live_nodes.get(nid);
        if not isinstance(nanch, NodeAnchor) or not nanch.is_populated() {
            continue;
        }
        for stub in nanch.edges {
            if stub.id in seen_eids
                or not stub.is_populated()
                or stub.id in view.detached
                or stub.hash != 0 {
                continue;
            }
            seen_eids.add(stub.id);
            live_edges.append(stub);
        }
    }
    n_live = 0;
    for ea in live_edges {
        r = _live_row(ea, cur_set, hop);
        if r is not None {
            rows.append(r);
            n_live += 1;
            view.live_edges[ea.id] = ea;
            src = ea.source;
            tgt = ea.target;
            if src is not None and src.is_populated() {
                view.live_nodes[src.id] = src;
            }
            if tgt is not None and tgt.is_populated() {
                view.live_nodes[tgt.id] = tgt;
            }
        }
    }
    rows = _edge_pred_keep(mem, view, rows, hop.epreds);
    seen: set[UUID] = set();
    ids: list[UUID] = [];
    for (_, nid) in rows {
        if nid not in seen {
            seen.add(nid);
            ids.append(nid);
        }
    }
    ids = _node_pred_keep(mem, view, ids, hop.preds);
    want = hop.only_ids();
    if want is not None {
        ids = [
            i
            for i in ids
            if i in want
        ];
    }
    if _trace_enabled() {
        logger.info(
            f"[gquery] hop[{hop_idx}] {hop.repr()} in={len(cur)} "
            f"engine_rows={n_engine} live_rows={n_live} out={len(ids)}"
        );
    }
    return ids;
}


impl _resolve_ids(mem: Memory, view: _View, q: GraphQuery, upto: int) -> list[UUID] {
    seen: set[UUID] = set();
    cur: list[UUID] = [];
    for arch in q.origin {
        aid = arch.__jac__.id;
        if aid not in seen {
            seen.add(aid);
            cur.append(aid);
        }
    }
    if upto <= 0 or not cur {
        return cur;
    }
    for (i, hop) in enumerate(q.hops[:upto]) {
        cur = _hop_once(mem, view, cur, hop, i);
        if not cur {
            break;
        }
    }
    return cur;
}


impl _materialize(mem: Memory, view: _View, ids: list[UUID]) -> list[Anchor] {
    if not ids {
        return [];
    }
    import from jaclang.runtimelib.memory { TieredMemory }
    loaded: dict[UUID, Anchor] = {};
    missing: list[UUID] = [];
    for i in ids {
        live = view.live_nodes.get(i);
        if live is not None and live.is_populated() and live.archetype is not None {
            loaded[i] = live;
        } else {
            missing.append(i);
        }
    }
    if missing {
        if isinstance(mem, TieredMemory) {
            loaded.update(mem.batch_get(missing));
        } else {
            for i in missing {
                if (a := mem.get(i)) is not None {
                    loaded[i] = a;
                }
            }
        }
    }
    return [
        loaded[i]
        for i in ids
        if i in loaded
    ];
}


impl _verify_last_hop(anchor: Anchor, hop: QHop) -> bool {
    arch = anchor.archetype;
    if arch is None {
        return False;
    }
    nd = hop.nd;
    if nd is not None {
        types = nd if isinstance(nd, tuple) else (nd, );
        for nt in types {
            if not isinstance(arch, nt) {
                return False;
            }
        }
    }
    if not all(p.matches(getattr(arch, p.field, None)) for p in hop.preds) {
        return False;
    }
    want = hop.only_ids();
    return want is None or anchor.id in want;
}


impl resolve_query_prefix(mem: Memory, q: GraphQuery, upto: int) -> list[UUID] {
    view = _build_view(mem, q);
    return _resolve_ids(mem, view, q, upto);
}


impl resolve_query(mem: Memory, q: GraphQuery) -> list[Anchor] {
    if not q.origin {
        return [];
    }
    view = _build_view(mem, q);
    ids = _resolve_ids(mem, view, q, len(q.hops));
    if q.slc is not None {
        ids = ids[q.slc];
    }
    winners = _materialize(mem, view, ids);
    if not q.hops {
        return winners;
    }
    last = q.hops[-1];
    verified = [
        w
        for w in winners
        if _verify_last_hop(w, last)
    ];
    if _trace_enabled() {
        logger.info(
            f"[gquery] final materialized={len(winners)} "
            f"verified={len(verified)} slc={q.slc}"
        );
    }
    return verified;
}


impl resolve_query_edges(mem: Memory, q: GraphQuery) -> list[Anchor] {
    if not q.origin or not q.hops {
        return [];
    }
    view = _build_view(mem, q);
    prefix_ids = _resolve_ids(mem, view, q, len(q.hops) - 1);
    if not prefix_ids {
        return [];
    }
    hop = q.hops[-1];
    frontier = _materialize(mem, view, prefix_ids);
    cur_set = {a.id for a in frontier};
    pool = mem.get_mem();
    candidates: list[EdgeAnchor] = [];
    seen: set[UUID] = set();
    pending: list[UUID] = [];
    for n in frontier {
        if not isinstance(n, NodeAnchor) or not n.is_populated() {
            continue;
        }
        for stub in n.edges {
            if stub.id in seen {
                continue;
            }
            seen.add(stub.id);
            found = pool.get(stub.id) or view.live_edges.get(stub.id);
            if found is None and stub.is_populated() {
                found = stub;
            }
            if isinstance(found, EdgeAnchor) and found.is_populated() {
                candidates.append(found);
            } else {
                pending.append(stub.id);
            }
        }
    }
    if pending {
        import from jaclang.runtimelib.memory { TieredMemory }
        fetched: dict[UUID, Anchor];
        if isinstance(mem, TieredMemory) {
            fetched = mem.batch_get(pending);
        } else {
            fetched = {
                i: a
                for i in pending
                if (a := mem.get(i)) is not None
            };
        }
        for i in pending {
            fa = fetched.get(i);
            if isinstance(fa, EdgeAnchor) and fa.is_populated() {
                candidates.append(fa);
            }
        }
    }
    out: list[Anchor] = [];
    seen_nodes: set[UUID] = set();
    ewant = hop.only_ids();
    for ea in candidates {
        if ea.archetype is None or ea.id in view.detached {
            continue;
        }
        src = ea.source;
        tgt = ea.target;
        if src is None or tgt is None {
            continue;
        }
        hit = False;
        if hop.dir == 1 {
            hit = tgt.id in cur_set or (ea.is_undirected and src.id in cur_set);
        } elif hop.dir == 3 {
            hit = src.id in cur_set or tgt.id in cur_set;
        } else {
            hit = src.id in cur_set or (ea.is_undirected and tgt.id in cur_set);
        }
        if not hit {
            continue;
        }
        if hop.`edge is not None and not isinstance(ea.archetype, hop.`edge) {
            continue;
        }
        if hop.epreds
            and not all(
                p.matches(getattr(ea.archetype, p.field, None)) for p in hop.epreds
            ) {
            continue;
        }
        other = tgt if src.id in cur_set else src;
        if ewant is not None and other.id not in ewant {
            continue;
        }
        if hop.nd is not None or hop.preds or q.from_visit {
            other_l = _materialize(mem, view, [other.id]);
            if not other_l {
                continue;
            }
            if not _verify_last_hop(other_l[0], hop) {
                continue;
            }
            out.append(ea);
            if q.from_visit and other.id not in seen_nodes {
                seen_nodes.add(other.id);
                out.append(other_l[0]);
            }
        } else {
            out.append(ea);
        }
    }
    if q.slc is not None {
        out = out[q.slc];
    }
    return out;
}
