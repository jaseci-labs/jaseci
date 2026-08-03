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
        vanch = arch?.__jac__;
        if isinstance(vanch, NodeAnchor) and vanch.is_populated() {
            view.live_nodes[vanch.id] = vanch;
        }
    }
    if q.level != 'fresh' {
        view.proj = _projection_for(mem);
    }
    return view;
}


impl _projection_for(mem: Memory) -> any {
    import from jaclang.runtimelib.projection { get_projection, projection_enabled }
    if not projection_enabled() {
        return None;
    }
    l3 = mem?.l3;
    if l3 is None {
        return None;
    }
    key = (
        f"{type(l3).__name__}:"
        + str(getattr(l3, 'path', '') or '')
        + str(getattr(l3, 'mongo_url', '') or '')
        + ':'
        + str(getattr(l3, 'db_name', '') or '')
        + ':'
        + str(getattr(l3, 'collection_name', '') or '')
        + '|'
        + os.environ.get('JAC_PROJECTION_POD', '')
    );
    return get_projection(key);
}


impl _page_rows(
    view: _View, nid: UUID, page: dict, hop: QHop
) -> (list[tuple[UUID, UUID]] | None) {
    ename = hop.`edge.__name__ if hop.`edge is not None else None;
    nd = hop.nd;
    nd_names: (tuple | None) = None;
    if nd is not None {
        types = nd if isinstance(nd, tuple) else (nd, );
        nd_names = tuple(t.__name__ for t in types);
    }
    out: list[tuple[UUID, UUID]] = [];
    nbr = cast(dict, page.get('nbr') or {});
    for row in cast(list, page.get('adj') or []) {
        row_t = cast(tuple, row);
        eid = cast(UUID, row_t[0]);
        e_anc = cast(tuple, row_t[1]);
        undir = bool(row_t[2]);
        is_out = bool(row_t[3]);
        other = cast(UUID, row_t[4]);
        e_cols = cast(dict, row_t[5]);
        if hop.dir == 2 {
            if not (is_out or undir) {
                continue;
            }
        } elif hop.dir == 1 {
            if is_out and not undir {
                continue;
            }
        }
        if ename is not None and ename not in e_anc {
            continue;
        }
        if hop.epreds and not all(p.matches(e_cols.get(p.field)) for p in hop.epreds) {
            continue;
        }
        if nd_names is not None {
            raw = view.proj.summary_of(other) or nbr.get(other);
            if raw is None {
                return None;
            }
            o_anc = cast(tuple, cast(tuple, raw)[0]);
            miss = False;
            for n in nd_names {
                if n not in o_anc {
                    miss = True;
                    break;
                }
            }
            if miss {
                continue;
            }
        }
        out.append((eid, other));
    }
    return out;
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
    summary_pass: set[UUID] = set();
    summary_known: set[UUID] = set();
    if view.proj is not None {
        still: list[UUID] = [];
        for i in remote {
            summ = view.proj.summary_of(i);
            if summ is None {
                still.append(i);
                continue;
            }
            summary_known.add(i);
            cols = cast(dict, cast(tuple, summ)[1]);
            if all(p.matches(cols.get(p.field)) for p in preds) {
                summary_pass.add(i);
            }
        }
        remote = still;
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
        } elif i in summary_pass or i in remote_keep {
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
        } elif eid not in view.epred_ok {
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
        } elif eid in view.epred_ok or eid in remote_keep {
            out.append((eid, nid));
        }
    }
    return out;
}


impl _heal_sweep(
    mem: Memory, view: _View, nanch: NodeAnchor, engine_eids: set[UUID]
) -> None {
    suspects: list[EdgeAnchor] = [];
    for stub in list(nanch.edges) {
        if stub.id in engine_eids or stub.id in view.probed or stub.is_populated() {
            continue;
        }
        view.probed.add(stub.id);
        suspects.append(stub);
    }
    if not suspects {
        return;
    }
    present = mem.existing_ids([st.id for st in suspects]);
    if present is None {
        return;
    }
    alive: list[EdgeAnchor] = [];
    for st in suspects {
        if st.id in present {
            alive.append(st);
        } else {
            mem.quarantine_ref(nanch, st);
        }
    }
    if not alive {
        return;
    }
    endpoints = mem.edge_endpoints([st.id for st in alive]);
    if endpoints is None {
        return;
    }
    pool = mem.get_mem();
    other_of: dict[UUID, UUID] = {};
    to_check: list[UUID] = [];
    for st in alive {
        ends = endpoints.get(st.id);
        if ends is None {
            continue;
        }
        (src_id, dst_id) = ends;
        other_id = dst_id if src_id == nanch.id else src_id;
        resident = pool.get(other_id) or view.live_nodes.get(other_id);
        if resident is not None and resident.is_populated() {
            continue;
        }
        other_of[st.id] = other_id;
        to_check.append(other_id);
    }
    if not to_check {
        return;
    }
    ok_nodes = mem.existing_ids(to_check);
    if ok_nodes is None {
        return;
    }
    for st in alive {
        oid = other_of.get(st.id);
        if oid is None {
            continue;
        }
        other_id: UUID = oid;
        if other_id in ok_nodes {
            continue;
        }
        mem.quarantine_ref(nanch, st);
        try {
            import from jaclang.runtimelib.memory { TieredMemory }
            if isinstance(mem, TieredMemory) and mem.l3 is not None {
                mem.l3.quarantine_dangling(other_id, st.id, 'node');
            }
        } except Exception {
            ;
        }
        view.detached.add(st.id);
    }
}


impl _hop_once(
    mem: Memory, view: _View, cur: list[UUID], hop: QHop, hop_idx: int
) -> list[UUID] {
    cur_set = set(cur);
    view.epred_ok = set();
    local_pairs: list[tuple[UUID, UUID]] = [];
    engine_cur: list[UUID] = [];
    proj = view.proj;
    if proj is not None {
        for nid in cur {
            page = proj.fresh_page(nid);
            rows_l = _page_rows(view, nid, page, hop) if page is not None else None;
            if rows_l is None {
                engine_cur.append(nid);
            } else {
                local_pairs.extend(rows_l);
            }
        }
    } else {
        engine_cur = list(cur);
    }
    engine_rows = mem.hop_rows(engine_cur, hop, ordered=True);
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
    n_local = 0;
    for (eid, nid) in local_pairs {
        if eid in seen_eids or eid in view.detached or eid in view.live_edges {
            continue;
        }
        seen_eids.add(eid);
        view.epred_ok.add(eid);
        rows.append((eid, nid));
        n_local += 1;
    }
    live_edges: list[EdgeAnchor] = [];
    for ea in view.fresh {
        if ea.id not in seen_eids {
            seen_eids.add(ea.id);
            live_edges.append(ea);
        }
    }
    pool = mem.get_mem();
    all_eids: set[UUID] = set(seen_eids);
    for nid in cur {
        nanch = pool.get(nid) or view.live_nodes.get(nid);
        if not isinstance(nanch, NodeAnchor) or not nanch.is_populated() {
            continue;
        }
        if engine_rows is not None {
            _heal_sweep(mem, view, nanch, all_eids);
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
    if proj is not None and engine_rows is not None and engine_cur {
        to_warm = engine_cur[:proj.warm_cap];
        pages = mem.node_pages(to_warm);
        if pages {
            proj.absorb(pages);
        }
    }
    if _trace_enabled() {
        logger.info(
            f"[gquery] hop[{hop_idx}] {hop.repr()} in={len(cur)} "
            f"engine_rows={n_engine} proj_rows={n_local} live_rows={n_live} "
            f"out={len(ids)}"
        );
    }
    return ids;
}


impl _resolve_ids(mem: Memory, view: _View, q: GraphQuery, upto: int) -> list[UUID] {
    seen: set[UUID] = set();
    cur: list[UUID] = [];
    for arch in q.origin {
        oanch = arch?.__jac__;
        if not isinstance(oanch, Anchor) {
            continue;
        }
        aid = oanch.id;
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
