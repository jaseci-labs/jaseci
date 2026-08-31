import from jaclang.runtime.adj_provider { UNHANDLED, install_adjacency_provider }
import from jaclang.runtime.archetype { NodeArchetype, light_edge_view }
import jaclang.compiler.store.host as _host;

glob EKIND_OF: dict = {},
     CLS_OF: dict = {},
     EXPAND: dict = {};

def register_edge(cls: type, ekind: int, is_struct: bool) -> None {
    EKIND_OF[cls] = ekind;
    CLS_OF[ekind] = cls;
    EXPAND.clear();
    _host.register_ekind(ekind, 1 if is_struct else 0);
}

def ekinds_for(cls: type) -> list {
    hit = EXPAND.get(cls);
    if hit is not None {
        return hit;
    }
    out = [
        EKIND_OF[c]
        for c in EKIND_OF.keys()
        if issubclass(c, cls)
    ];
    EXPAND[cls] = out;
    return out;
}

def _views(handles: list) -> list {
    out = [];
    for h in handles {
        v = _host.view_of(h);
        if v is not None {
            out.append(v);
        }
    }
    return out;
}

def _edge_views(src: any, handles: list, ekind: int, direction: int) -> list {
    cls = CLS_OF[ekind];
    out = [];
    for h in handles {
        peer = _host.view_of(h);
        if peer is None {
            continue;
        }
        if direction == 0 {
            out.append(light_edge_view(cls, src.__jac__, peer.__jac__));
        } else {
            out.append(light_edge_view(cls, peer.__jac__, src.__jac__));
        }
    }
    return out;
}

def connect(
    left: any,
    right: any,
    edge_cls: any,
    undir: bool,
    conn_assign: any,
    edges_only: bool
) -> any {
    if not isinstance(edge_cls, type) {
        return UNHANDLED;
    }
    ekind = EKIND_OF.get(edge_cls);
    if ekind is None {
        return UNHANDLED;
    }
    if undir or conn_assign is not None {
        raise RuntimeError(
            "jacstore: undirected/assign connect unsupported on IR edges"
        );
    }
    lefts = [left] if isinstance(left, NodeArchetype) else left;
    rights = [right] if isinstance(right, NodeArchetype) else right;
    for l in lefts {
        for r in rights {
            _host.edge_add(l._ts, r._ts, ekind);
        }
    }
    if edges_only {
        out = [];
        for l in lefts {
            for r in rights {
                out.append(light_edge_view(edge_cls, l.__jac__, r.__jac__));
            }
        }
        return out;
    }
    return right;
}

def hop(origin: any, dir: int, edge_type: any, edges_only: bool) -> any {
    h = getattr(origin, "_ts", -1);
    if h < 0 {
        return UNHANDLED;
    }
    if edge_type is not None {
        ekinds = ekinds_for(edge_type);
        if not ekinds {
            return UNHANDLED;
        }
    } else {
        ekinds = [k for k in CLS_OF.keys()];
    }
    out = [];
    if dir == 2 or dir == 3 {
        for ek in ekinds {
            hs = _host.adj(h, ek, 0);
            if hs {
                if edges_only {
                    out.extend(_edge_views(origin, hs, ek, 0));
                } else {
                    out.extend(_views(hs));
                }
            }
        }
    }
    if dir == 1 or dir == 3 {
        for ek in ekinds {
            hs = _host.adj(h, ek, 1);
            if hs {
                if edges_only {
                    out.extend(_edge_views(origin, hs, ek, 1));
                } else {
                    out.extend(_views(hs));
                }
            }
        }
    }
    if edge_type is None {
        import from jaclang.runtime.archetype { light_hop, light_hop_answers }
        anchor = origin.__jac__;
        if light_hop_answers(anchor, None) {
            extra = light_hop(anchor, dir, None, edges_only);
            if extra {
                seen = set([id(x) for x in out]);
                for x in extra {
                    if id(x) not in seen {
                        out.append(x);
                    }
                }
            }
        }
    }
    return out;
}

def clear_edges(origin: any, dir: int, edge_type: any) -> any {
    h = getattr(origin, "_ts", -1);
    if h < 0 or edge_type is None {
        return UNHANDLED;
    }
    ekinds = ekinds_for(edge_type);
    if not ekinds {
        return UNHANDLED;
    }
    for ek in ekinds {
        if dir == 2 or dir == 3 {
            _host.adj_clear(origin._ts, ek, 0);
        }
        if dir == 1 or dir == 3 {
            _host.adj_clear(origin._ts, ek, 1);
        }
    }
    return True;
}

def refs(path: any, lazy: bool) -> any {
    for qh in path.hops {
        e = getattr(qh, "edge", None);
        if e is not None and not ekinds_for(e) {
            return UNHANDLED;
        }
        if qh.epreds or qh.preds or qh.only is not None {
            raise RuntimeError("jacstore: predicated query unsupported on IR");
        }
    }
    if path.order or path.limit is not None or path.offset {
        raise RuntimeError("jacstore: ordered/limited query unsupported on IR");
    }
    cur = list(path.origin);
    n_hops = len(path.hops);
    i = 0;
    for qh in path.hops {
        i += 1;
        want_edges = path.edges_only and i == n_hops;
        qe = getattr(qh, "edge", None);
        nxt = [];
        for nd in cur {
            got = hop(nd, qh.dir, qe, want_edges);
            if got is UNHANDLED {
                import from jaclang.runtime.archetype { light_hop }
                got = light_hop(nd.__jac__, qh.dir, qe, want_edges);
            }
            nxt.extend(got);
        }
        if qh.nd is not None {
            nxt = [x for x in nxt if isinstance(x, qh.nd)];
        }
        seen = set();
        deduped = [];
        for x in nxt {
            if id(x) not in seen {
                seen.add(id(x));
                deduped.append(x);
            }
        }
        cur = deduped;
    }
    if path.slc is not None {
        cur = cur[path.slc];
    }
    return cur;
}

def disconnect(left: any, right: any, dir: any, filter_fn: any) -> any {
    raise RuntimeError("jacstore: disconnect unsupported on IR nodes");
}

def install -> None {
    import jaclang.compiler.store.provider as me;
    install_adjacency_provider(me);
}
