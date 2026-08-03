impl _trace_enabled -> bool {
    val = os.environ.get('JAC_QUERY_TRACE', '');
    return val.lower() in ('1', 'true', 'yes', 'on', 'plan');
}


impl _build_overlay(mem: Memory) -> _Overlay {
    ov = _Overlay();
    for anchor in list(mem.get_mem().values()) {
        if not isinstance(anchor, EdgeAnchor) or not anchor.is_populated() {
            continue;
        }
        if anchor.hash == 0 {
            if _edge_alive(anchor) {
                ov.fresh.append(anchor);
                ov.fresh_ids.add(anchor.id);
            } else {
                ov.detached.add(anchor.id);
            }
        } elif not _edge_alive(anchor) {
            ov.detached.add(anchor.id);
        }
    }
    return ov;
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


impl _node_pred_keep(mem: Memory, ids: list[UUID], preds: list[QPred]) -> list[UUID] {
    if not preds or not ids {
        return ids;
    }
    resident: dict[UUID, Anchor] = {};
    remote: list[UUID] = [];
    pool = mem.get_mem();
    for i in ids {
        a = pool.get(i);
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
    mem: Memory, rows: list[tuple[UUID, UUID]], overlay: _Overlay, epreds: list[QPred]
) -> list[tuple[UUID, UUID]] {
    if not epreds or not rows {
        return rows;
    }
    pool = mem.get_mem();
    resident: dict[UUID, Anchor] = {};
    remote: list[UUID] = [];
    for (eid, _) in rows {
        a = pool.get(eid);
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
    mem: Memory, overlay: _Overlay, cur: list[UUID], hop: QHop, hop_idx: int
) -> list[UUID] {
    cur_set = set(cur);
    engine_rows = mem.hop_rows(cur, hop, ordered=True);
    rows: list[tuple[UUID, UUID]] = [];
    n_engine = 0;
    if engine_rows is not None {
        for (eid, nid) in engine_rows {
            if eid in overlay.detached or eid in overlay.fresh_ids {
                continue;
            }
            rows.append((eid, nid));
            n_engine += 1;
        }
    }
    n_live = 0;
    for ea in overlay.fresh {
        r = _live_row(ea, cur_set, hop);
        if r is not None {
            rows.append(r);
            n_live += 1;
        }
    }
    rows = _edge_pred_keep(mem, rows, overlay, hop.epreds);
    seen: set[UUID] = set();
    ids: list[UUID] = [];
    for (_, nid) in rows {
        if nid not in seen {
            seen.add(nid);
            ids.append(nid);
        }
    }
    ids = _node_pred_keep(mem, ids, hop.preds);
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
            f"engine_rows={n_engine} overlay_rows={n_live} out={len(ids)}"
        );
    }
    return ids;
}


impl _materialize(mem: Memory, ids: list[UUID]) -> list[Anchor] {
    if not ids {
        return [];
    }
    import from jaclang.runtimelib.memory { TieredMemory }
    loaded: dict[UUID, Anchor];
    if isinstance(mem, TieredMemory) {
        loaded = mem.batch_get(ids);
    } else {
        loaded = {
            i: a
            for i in ids
            if (a := mem.get(i)) is not None
        };
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
    return all(p.matches(getattr(arch, p.field, None)) for p in hop.preds);
}


impl resolve_query_prefix(mem: Memory, q: GraphQuery, upto: int) -> list[UUID] {
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
    overlay = _build_overlay(mem);
    for (i, hop) in enumerate(q.hops[:upto]) {
        cur = _hop_once(mem, overlay, cur, hop, i);
        if not cur {
            break;
        }
    }
    return cur;
}


impl resolve_query_edges(mem: Memory, q: GraphQuery) -> list[Anchor] {
    if not q.origin or not q.hops {
        return [];
    }
    prefix_ids = resolve_query_prefix(mem, q, len(q.hops) - 1);
    if not prefix_ids {
        return [];
    }
    hop = q.hops[-1];
    frontier = _materialize(mem, prefix_ids);
    cur_set = {a.id for a in frontier};
    edge_ids: list[UUID] = [];
    seen: set[UUID] = set();
    for n in frontier {
        if not isinstance(n, NodeAnchor) or not n.is_populated() {
            continue;
        }
        for stub in n.edges {
            if stub.id not in seen {
                seen.add(stub.id);
                edge_ids.append(stub.id);
            }
        }
    }
    candidates = _materialize(mem, edge_ids);
    out: list[Anchor] = [];
    for ea in candidates {
        if not isinstance(ea, EdgeAnchor) or not ea.is_populated() {
            continue;
        }
        if ea.archetype is None {
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
        ewant = hop.only_ids();
        if ewant is not None and other.id not in ewant {
            continue;
        }
        if hop.nd is not None or hop.preds {
            other_l = _materialize(mem, [other.id]);
            if not other_l {
                continue;
            }
            if not _verify_last_hop(other_l[0], hop) {
                continue;
            }
        }
        out.append(ea);
    }
    if q.slc is not None {
        out = out[q.slc];
    }
    return out;
}


impl resolve_query(mem: Memory, q: GraphQuery) -> list[Anchor] {
    if not q.origin {
        return [];
    }
    ids = resolve_query_prefix(mem, q, len(q.hops));
    if not q.hops {
        if q.slc is not None {
            ids = ids[q.slc];
        }
        return _materialize(mem, ids);
    }
    if q.slc is not None {
        ids = ids[q.slc];
    }
    winners = _materialize(mem, ids);
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
