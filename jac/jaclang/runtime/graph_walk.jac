"""Traversal over live anchors.

Walking a graph is the primitive. A store is something some of a graph's nodes
additionally have, and it is what pulls in `jaclang.data.query_planner`: SQL
compilation, predicate pushdown, residual filters, the round trip that turns
anchors into store keys and back. A graph that has never been connected to a
root has none of that, and answering `[-->]` over it should not go near any of
it.

This module is that primitive. Given origin anchors and a `GraphQuery` it
answers the query from the anchors themselves -- edge lists, direction, node
and edge type filters, predicates, `only` pins, slices and limits -- and knows
nothing about sessions, SQL or pushdown. `needs_store` is the single predicate
that decides when the planner has to be involved at all, and the planner calls
back in here for the part of a mixed query that its SQL arm cannot answer.

Access control is a parameter rather than a lookup: a caller that has already
resolved whether the context is gated passes it in, because resolving it means
walking to the execution context and back through two root properties.
"""

import from jaclang.runtime.archetype {
    Anchor,
    EdgeAnchor,
    NodeAnchor,
    anchor_key
}
import from jaclang.runtime.graph_query { GraphQuery, QHop, QPred }

glob __all__ = [
    'access_gated',
    'acl_read_ok',
    'bounded',
    'edge_pair_for',
    'hop_matches_node',
    'needs_store',
    'origin_anchors',
    'pred_subject',
    'unique_anchors',
    'walk',
    'walk_edges',
    'walk_nodes'
];


"""Is access control active in this context?

It is not when there is no context, and it is not when the request runs as the
system root, which owns everything. Both are the ordinary case for a script.
"""
def access_gated -> bool {
    import from jaclang.runtime.runtime { JacRuntimeInterface }
    try {
        jctx = JacRuntimeInterface.get_context();
    } except Exception {
        return False;
    }
    ur = jctx?.user_root;
    return ur is not None and ur != jctx.system_root;
}


"""May the current root read this anchor?"""
def acl_read_ok(anchor: Anchor) -> bool {
    import from jaclang.runtime.archetype { AccessLevel }
    import from jaclang.runtime.runtime { JacRuntimeInterface }
    level = JacRuntimeInterface.check_access_level(anchor);
    return level.value > AccessLevel.NO_ACCESS.value;
}


"""Does answering a query from these origins require reading the store?

Only if there is a store and at least one origin has a row in it. Everything
else -- a script with no store at all, a subgraph built in memory and not yet
attached to a root -- is answered by `walk`, whether or not access control is
gated, since the walk applies the gate itself.
"""
def needs_store(mem: any, origins: list[Anchor]) -> bool {
    if not origins or mem?.store is None {
        return False;
    }
    for a in origins {
        if a.persistent {
            return True;
        }
    }
    return False;
}


"""The distinct anchors a query starts from, in the order it names them."""
def origin_anchors(q: GraphQuery) -> list[Anchor] {
    seen: set = set();
    out: list[Anchor] = [];
    for arch in q.origin {
        oanch = arch?.__jac__;
        if isinstance(oanch, Anchor) {
            key = anchor_key(oanch);
            if key not in seen {
                seen.add(key);
                out.append(oanch);
            }
        }
    }
    return out;
}


"""The value a predicate tests, read off an archetype."""
def pred_subject(arch: any, p: QPred) -> any {
    if isinstance(p.field, tuple) {
        return tuple(getattr(arch, name, None) for name in p.field);
    }
    return getattr(arch, p.field, None);
}


"""Does this anchor satisfy the hop's node type, predicates and `only` pins?"""
def hop_matches_node(anchor: Anchor, hop: QHop) -> bool {
    if not anchor.is_populated() or anchor.archetype is None {
        return False;
    }
    nd = hop.nd;
    if nd is not None {
        types = nd if isinstance(nd, tuple) else (nd, );
        for nt in types {
            if not isinstance(anchor.archetype, nt) {
                return False;
            }
        }
    }
    for p in hop.preds {
        if not p.matches(pred_subject(anchor.archetype, p)) {
            return False;
        }
    }
    want = hop.only_keys();
    return want is None or anchor_key(anchor) in want;
}


"""The far end of `e` from `cur`, if this hop accepts that edge at all.

Endpoints are compared with `anchor_key` semantics rather than by store key:
a transient anchor has no key, and a persisted one can be present as both a
stub and the populated record.
"""
def edge_pair_for(e: EdgeAnchor, cur: Anchor, hop: QHop) -> (Anchor | None) {
    import from jaclang.runtime.archetype { same_anchor }
    src = e.source;
    tgt = e.target;
    if src is None or tgt is None or e.archetype is None {
        return None;
    }
    other: (Anchor | None) = None;
    from_src = same_anchor(src, cur);
    from_tgt = same_anchor(tgt, cur);
    if hop.dir == 1 {
        if from_tgt {
            other = src;
        } elif e.is_undirected and from_src {
            other = tgt;
        }
    } elif hop.dir == 3 {
        if from_src {
            other = tgt;
        } elif from_tgt {
            other = src;
        }
    } else {
        if from_src {
            other = tgt;
        } elif e.is_undirected and from_tgt {
            other = src;
        }
    }
    if other is None {
        return None;
    }
    if hop.`edge is not None and not isinstance(e.archetype, hop.`edge) {
        return None;
    }
    for p in hop.epreds {
        if not p.matches(pred_subject(e.archetype, p)) {
            return None;
        }
    }
    return other if hop_matches_node(other, hop) else None;
}


"""Walk `upto` hops from `origins`, returning (node, edge that reached it).

The origins themselves are the zero-hop answer, so `upto == 0` returns them
paired with no edge.
"""
def walk(
    origins: list[Anchor], q: GraphQuery, upto: int, gated: bool
) -> list[tuple[Anchor, (EdgeAnchor | None)]] {
    frontier: list[Anchor] = list(origins);
    pairs: list[tuple[Anchor, (EdgeAnchor | None)]] = [(a, None) for a in origins];
    nhops = min(upto, len(q.hops));
    i = 0;
    while i < nhops {
        hop = q.hops[i];
        i += 1;
        nxt: list[tuple[Anchor, (EdgeAnchor | None)]] = [];
        seen_edges: set = set();
        for cur in frontier {
            if not isinstance(cur, NodeAnchor) or not cur.is_populated() {
                continue;
            }
            for e in list(cur.edges) {
                if not e.is_populated() {
                    continue;
                }
                ekey = anchor_key(e);
                if ekey in seen_edges {
                    continue;
                }
                other = edge_pair_for(e, cur, hop);
                if other is not None {
                    if gated and not acl_read_ok(other) {
                        continue;
                    }
                    seen_edges.add(ekey);
                    nxt.append((other, e));
                }
            }
        }
        pairs = nxt;
        # The last hop's frontier is the answer, and every caller dedupes it.
        if i < nhops {
            frontier = unique_anchors(nxt);
        }
    }
    return pairs;
}


"""Distinct nodes of a walk, in first-seen order."""
def unique_anchors(
    pairs: list[tuple[Anchor, (EdgeAnchor | None)]]
) -> list[Anchor] {
    seen: set = set();
    out: list[Anchor] = [];
    for (a, _) in pairs {
        key = anchor_key(a);
        if key not in seen {
            seen.add(key);
            out.append(a);
        }
    }
    return out;
}


"""Apply a query's slice or limit/offset to an already-resolved list.

Only correct where nothing was pushed into SQL, which is exactly here.
"""
def bounded(out: list[Anchor], q: GraphQuery) -> list[Anchor] {
    if q.limit is not None {
        stop = None if q.limit is None else q.offset + q.limit;
        return out[q.offset:stop];
    }
    if q.slc is not None {
        return out[q.slc];
    }
    return out;
}


"""Answer a node query from live anchors."""
def walk_nodes(origins: list[Anchor], q: GraphQuery, gated: bool) -> list[Anchor] {
    return bounded(unique_anchors(walk(origins, q, len(q.hops), gated)), q);
}


"""Answer an edge query from live anchors.

`from_visit` interleaves each edge with the node it reached, which is what
`visit` consumes; otherwise the edges alone are the answer.
"""
def walk_edges(origins: list[Anchor], q: GraphQuery, gated: bool) -> list[Anchor] {
    if not q.hops {
        return [];
    }
    edges: list[Anchor] = [];
    node_of: dict = {};
    seen: set = set();
    for (a, e) in walk(origins, q, len(q.hops), gated) {
        if e is None {
            continue;
        }
        ekey = anchor_key(e);
        if ekey in seen {
            continue;
        }
        seen.add(ekey);
        edges.append(e);
        node_of[ekey] = a;
    }
    if not q.from_visit {
        return edges[q.slc] if q.slc is not None else edges;
    }
    out: list[Anchor] = [];
    seen_nodes: set = set();
    for e in edges {
        out.append(e);
        nd = node_of.get(anchor_key(e));
        if nd is None {
            continue;
        }
        nkey = anchor_key(nd);
        if nkey in seen_nodes {
            continue;
        }
        seen_nodes.add(nkey);
        out.append(nd);
    }
    return out[q.slc] if q.slc is not None else out;
}
