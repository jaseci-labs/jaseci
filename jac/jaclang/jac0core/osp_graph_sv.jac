import jaclang.jac0core.osp_graph as _graph;
import from dataclasses { field }
import from jaclang.jac0core.archetype { Anchor, EdgeAnchor, NodeAnchor }

obj _SvStore {
    has h_of_id: dict[str, int] = {},
        registered: set[str] = field(default_factory=`set);
}

glob _obj_of_h: list[(Anchor | None)] = [None],
     _tag_of_cls: dict[(type, int)] = {},
     _fallback: _SvStore = _SvStore();

def _mem_or_ctx(mem: any) -> any {
    if mem is not None {
        return mem;
    }
    import from jaclang.jac0core.runtime { JacRuntimeInterface }
    try {
        return JacRuntimeInterface.get_context().mem;
    } except Exception {
        return None;
    }
}

def _store_for(m: any) -> _SvStore {
    if m is None {
        return _fallback;
    }
    d = m.__dict__;
    st = d.get('_osp_sv_store');
    if st is None {
        st = _SvStore();
        d['_osp_sv_store'] = st;
    }
    return st;
}

def _mint(st: _SvStore, anchor: Anchor) -> int {
    key = str(anchor.id);
    h = st.h_of_id.get(key, 0);
    if h == 0 {
        _obj_of_h.append(anchor);
        h = len(_obj_of_h) - 1;
        st.h_of_id[key] = h;
        return h;
    }
    if anchor.is_populated() or _obj_of_h[h] is None {
        _obj_of_h[h] = anchor;
    }
    return h;
}

def handle_of(anchor: Anchor, mem: any = None) -> int {
    return _mint(_store_for(_mem_or_ctx(mem)), anchor);
}

def obj_of(h: int) -> (Anchor | None) {
    if h <= 0 or h >= len(_obj_of_h) {
        return None;
    }
    return _obj_of_h[h];
}

def tag_for(edge_a: EdgeAnchor) -> int {
    cls = `type(edge_a.archetype);
    t = _tag_of_cls.get(cls);
    if t is None {
        import from jaclang.jac0core.osp_model { stable_osp_tag }
        t = stable_osp_tag(cls.__name__);
        _tag_of_cls[cls] = t;
    }
    return t;
}

def _resolve(cand: (Anchor | None), m: any) -> (Anchor | None) {
    if cand is None or m is None {
        return cand;
    }
    cur = m.get_mem().get(cand.id);
    if cur is not None and cur.is_populated() {
        return cur;
    }
    return cand;
}

def sv_conn(
    src_a: NodeAnchor,
    tgt_a: NodeAnchor,
    edge_a: EdgeAnchor,
    is_undirected: bool,
    mem: any = None
) -> None {
    m = _mem_or_ctx(mem);
    st = _store_for(m);
    key = str(edge_a.id);
    if key in st.registered {
        _mint(st, edge_a);
        return;
    }
    eh = _mint(st, edge_a);
    _graph.osp_conn(
        _mint(st, src_a),
        _mint(st, tgt_a),
        eh,
        1 if is_undirected else 0,
        tag_for(edge_a),
        0,
        0
    );
    st.registered.add(key);
}

def sv_live_edges(
    origin_a: NodeAnchor,
    dir_int: int,
    edge_type: (type | None),
    edges_only: bool,
    mem: any = None
) -> list[Anchor] {
    m = _mem_or_ctx(mem);
    st = _store_for(m);
    oh = _mint(st, origin_a);
    if edge_type is None {
        out: list[Anchor] = [];
        for h in _graph.osp_refs(oh, dir_int, -1, 1 if edges_only else 0) {
            a = _resolve(obj_of(h), m);
            if a is not None {
                out.append(a);
            }
        }
        return out;
    }
    okey = str(origin_a.id);
    hits: list[EdgeAnchor] = [];
    for h in _graph.osp_refs(oh, dir_int, -1, 1) {
        e = _resolve(obj_of(h), m);
        if not isinstance(e, EdgeAnchor) or not e.is_populated() {
            continue;
        }
        if isinstance(e.archetype, edge_type) {
            hits.append(e);
        }
    }
    if edges_only {
        return hits;
    }
    ends: list[Anchor] = [];
    seen: set[str] = set();
    for e in hits {
        o_a = e.target if str(e.source.id) == okey else e.source;
        ra = _resolve(o_a, m);
        if ra is None {
            continue;
        }
        rk = str(ra.id);
        if rk not in seen {
            seen.add(rk);
            ends.append(ra);
        }
    }
    return ends;
}

def sv_candidate_edges_between(
    src_a: NodeAnchor, tgt_a: NodeAnchor, dir_int: int, mem: any = None
) -> list[EdgeAnchor] {
    skey = str(src_a.id);
    tkey = str(tgt_a.id);
    out: list[EdgeAnchor] = [];
    for e in sv_live_edges(src_a, dir_int, None, True, mem) {
        if not isinstance(e, EdgeAnchor) or not e.is_populated() {
            continue;
        }
        okey = str(e.target.id) if str(e.source.id) == skey else str(e.source.id);
        if okey == tkey {
            out.append(e);
        }
    }
    return out;
}

def sv_register_hydrated(node_a: NodeAnchor, mem: any = None) -> None {
    if not isinstance(node_a, NodeAnchor) or not node_a.is_populated() {
        return;
    }
    m = _mem_or_ctx(mem);
    _mint(_store_for(m), node_a);
    for e in list(node_a.edges) {
        if not e.is_populated() {
            continue;
        }
        src_a = e.source;
        tgt_a = e.target;
        if src_a is None or tgt_a is None {
            continue;
        }
        sv_conn(src_a, tgt_a, e, e.is_undirected, m);
    }
}

def sv_forget_edge(edge_a: EdgeAnchor, mem: any = None) {
    m = _mem_or_ctx(mem);
    st = _store_for(m);
    key = str(edge_a.id);
    st.registered.discard(key);
    h = st.h_of_id.get(key, 0);
    if h > 0 {
        _graph.osp_disconnect(h);
    }
}
