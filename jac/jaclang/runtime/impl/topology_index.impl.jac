"""Implementation of the transient TTG topology index."""

import logging;
import from uuid { UUID }

glob logger = logging.getLogger(__name__);


def _uniq_uuids(ids: list[UUID]) -> list[UUID] {
    out: list[UUID] = [];
    seen: set[UUID] = set();
    for uid in ids {
        if uid in seen {
            continue;
        }
        seen.add(uid);
        out.append(uid);
    }
    return out;
}


def _ancestors(raw: any, fallback: str) -> list[str] {
    vals: list[str] = [];
    if isinstance(raw, str) and raw {
        for part in raw.split(',') {
            val = part.strip();
            if val and val not in vals {
                vals.append(val);
            }
        }
    }
    if fallback and fallback not in vals {
        vals.insert(0, fallback);
    }
    return vals;
}


impl TopologyIndex.clear -> None {
    self.node_types = {};
    self.node_owners = {};
    self.type_ancestors = {};
    self.out_by_src = {};
    self.in_by_dst = {};
    self.edge_ids = set();
    self.loaded_roots = set();
    self.loaded_hops = set();
}


impl TopologyIndex.add_type(type_name: str, ancestors: list[str]) -> None {
    if not type_name {
        return;
    }
    bucket = self.type_ancestors.setdefault(type_name, set());
    bucket.add(type_name);
    for anc in ancestors {
        if anc {
            bucket.add(anc);
        }
    }
}


impl TopologyIndex.add_node(
    node_id: UUID,
    type_name: str,
    ancestors: list[str],
    owner_root: (UUID | None) = None
) -> None {
    if not type_name {
        type_name = "unknown";
    }
    if owner_root is None and type_name == "Root" {
        owner_root = node_id;
    }
    self.node_types[node_id] = type_name;
    if owner_root is not None {
        self.node_owners[node_id] = owner_root;
    }
    self.add_type(type_name, ancestors);
}


impl TopologyIndex.add_edge(
    edge_id: UUID,
    src: UUID,
    dst: UUID,
    edge_type: str,
    ancestors: list[str],
    undirected: bool = False
) -> None {
    if edge_id in self.edge_ids {
        return;
    }
    self.edge_ids.add(edge_id);
    self.add_type(edge_type, ancestors);
    topo_edge = TopologyEdge(
        id=edge_id,
        src=src,
        dst=dst,
        edge_type=edge_type,
        undirected=undirected
    );
    self.out_by_src.setdefault(src, []).append(topo_edge);
    self.in_by_dst.setdefault(dst, []).append(topo_edge);
}


impl TopologyIndex.mark_roots_loaded(root_ids: list[UUID]) -> None {
    for root_id in root_ids {
        self.loaded_roots.add(root_id);
    }
}


impl TopologyIndex.has_root(root_id: UUID) -> bool {
    return root_id in self.loaded_roots;
}


def _norm_hop_part(value: (str | None)) -> str {
    return value if value is not None else "";
}


def _norm_direction(direction: int) -> int {
    dir = int(direction or 2);
    return dir if dir in (1, 2, 3) else 2;
}


def _hop_key(
    origin_id: UUID,
    edge_type: (str | None),
    node_type: (str | None),
    direction: int
) -> tuple[UUID, str, str, int] {
    return (
        origin_id,
        _norm_hop_part(edge_type),
        _norm_hop_part(node_type),
        _norm_direction(direction)
    );
}


impl TopologyIndex.mark_hops_loaded(
    origin_ids: list[UUID],
    edge_type: (str | None),
    node_type: (str | None),
    direction: int
) -> None {
    for origin_id in origin_ids {
        self.loaded_hops.add(_hop_key(origin_id, edge_type, node_type, direction));
    }
}


impl TopologyIndex.has_hop(
    origin_id: UUID,
    edge_type: (str | None),
    node_type: (str | None),
    direction: int
) -> bool {
    return _hop_key(origin_id, edge_type, node_type, direction) in self.loaded_hops;
}


impl TopologyIndex.node_type(node_id: UUID) -> (str | None) {
    return self.node_types.get(node_id);
}


impl TopologyIndex.owner_root_for(node_id: UUID) -> (UUID | None) {
    return self.node_owners.get(node_id);
}


def _type_matches(idx: TopologyIndex, actual: str, wanted: (str | None)) -> bool {
    if wanted is None {
        return True;
    }
    if not actual {
        return False;
    }
    if actual == wanted {
        return True;
    }
    ancestors = idx.type_ancestors.get(actual);
    return ancestors is not None and wanted in ancestors;
}


def _edge_other(topo_edge: TopologyEdge, origin: UUID, direction: int) -> (UUID | None) {
    if topo_edge.src == origin {
        if direction in (2, 3) or (direction == 1 and topo_edge.undirected) {
            return topo_edge.dst;
        }
    }
    if topo_edge.dst == origin {
        if direction in (1, 3) or (direction == 2 and topo_edge.undirected) {
            return topo_edge.src;
        }
    }
    return None;
}


def _candidate_edges(
    idx: TopologyIndex, origin: UUID, direction: int
) -> list[TopologyEdge] {
    edges: list[TopologyEdge] = [];
    seen: set[UUID] = set();

    def add_many(items: list[TopologyEdge]) {
        for edge in items {
            if edge.id in seen {
                continue;
            }
            seen.add(edge.id);
            edges.append(edge);
        }
    }

    if direction in (2, 3) {
        add_many(idx.out_by_src.get(origin, []));
    }
    if direction in (1, 3) {
        add_many(idx.in_by_dst.get(origin, []));
    }
    if direction == 2 {
        add_many([e for e in idx.in_by_dst.get(origin, []) if e.undirected]);
    }
    if direction == 1 {
        add_many([e for e in idx.out_by_src.get(origin, []) if e.undirected]);
    }
    return edges;
}


impl TopologyIndex.resolve_chain(
    origin_ids: list[UUID],
    chain: list[tuple[str | None, str | None, int]],
    limit: int = 0
) -> list[UUID] {
    current = _uniq_uuids(origin_ids);
    if not chain {
        return current[:limit] if limit > 0 else current;
    }
    for (edge_type, node_type, direction) in chain {
        next_ids: list[UUID] = [];
        seen_nodes: set[UUID] = set();
        seen_edges: set[UUID] = set();
        for origin in current {
            for edge in _candidate_edges(self, origin, int(direction or 2)) {
                if edge.id in seen_edges {
                    continue;
                }
                other = _edge_other(edge, origin, int(direction or 2));
                if other is None {
                    continue;
                }
                if not _type_matches(self, edge.edge_type, edge_type) {
                    continue;
                }
                target_type = self.node_types.get(other, "");
                if not _type_matches(self, target_type, node_type) {
                    continue;
                }
                seen_edges.add(edge.id);
                if other in seen_nodes {
                    continue;
                }
                seen_nodes.add(other);
                next_ids.append(other);
                if limit > 0 and len(next_ids) >= limit {
                    break;
                }
            }
            if limit > 0 and len(next_ids) >= limit {
                break;
            }
        }
        current = next_ids;
        if not current {
            break;
        }
    }
    return current[:limit] if limit > 0 else current;
}


impl TopologyIndex.__len__ -> int {
    return len(self.node_types);
}


def _topology_index_for(mem: any) -> TopologyIndex {
    idx = mem?._topology_index;
    if not isinstance(idx, TopologyIndex) {
        idx = TopologyIndex();
        mem._topology_index = idx;
    }
    return idx;
}


def _pending_seed_ids(idx: TopologyIndex, node_ids: list[UUID]) -> list[UUID] {
    pending: list[UUID] = [];
    for uid in _uniq_uuids(node_ids) {
        owner = idx.owner_root_for(uid);
        if owner is not None and idx.has_root(owner) {
            continue;
        }
        pending.append(uid);
    }
    return pending;
}


def _ingest_topology_rows(idx: TopologyIndex, rows: list) -> list[UUID] {
    loaded: list[UUID] = [];
    edge_buf: list[tuple[UUID, UUID, UUID, str, list[str], bool]] = [];
    for r in rows {
        ord = int(str(r[0]));
        rid = UUID(str(r[1]));
        arch_type = str(r[2] or "");
        owner = UUID(str(r[3])) if r[3] else None;
        if ord == 0 {
            idx.add_node(rid, arch_type, _ancestors(r[7], arch_type), owner);
        } elif ord == 1 {
            if r[4] and r[5] {
                edge_buf.append((
                    rid,
                    UUID(str(r[4])),
                    UUID(str(r[5])),
                    arch_type,
                    _ancestors(r[7], arch_type),
                    r[6] if isinstance(r[6], bool)
                    else str(r[6]).lower() in ("true", "t", "1")
                ));
            }
        } elif ord == 2 {
            loaded.append(rid);
        }
    }
    for (eid, src, dst, etype, ancestors, undir) in edge_buf {
        idx.add_edge(eid, src, dst, etype, ancestors, undir);
    }
    return loaded;
}


impl ingest_topology_rows(mem: any, rows: list) -> TopologyIndex {
    idx = _topology_index_for(mem);
    lock = getattr(mem, "_topology_lock", None);
    if lock is not None {
        lock.acquire();
    }
    try {
        _ingest_topology_rows(idx, rows);
    } finally {
        if lock is not None {
            lock.release();
        }
    }
    if mem is not None {
        mem._topology_index = idx;
        mem.__topology_index__ = idx;
    }
    return idx;
}


impl warm_topology_for_nodes(mem: any, node_ids: list[UUID]) -> TopologyIndex {
    idx = _topology_index_for(mem);
    pending = _pending_seed_ids(idx, node_ids);
    if not pending or mem is None or mem?.store is None {
        return idx;
    }
    mem.read_barrier();
    lock = getattr(mem, "_topology_lock", None);
    if lock is not None {
        lock.acquire();
    }
    try {
        pending = _pending_seed_ids(idx, pending);
        if not pending {
            return idx;
        }
        rows = mem.store.rows(
            """
            WITH seed(id) AS (
                SELECT unnest(CAST(:node_ids AS uuid[]))
            ),
            seed_roots(root_id) AS (
                SELECT DISTINCT
                    CASE
                        WHEN a.kind = 'NodeAnchor' AND a.arch_type = 'Root'
                            THEN a.id
                        ELSE a.root_id
                    END AS root_id
                FROM anchors a
                JOIN seed s ON s.id = a.id
                WHERE a.kind = 'NodeAnchor'
            ),
            wanted_roots(root_id) AS (
                SELECT root_id
                FROM seed_roots
                WHERE root_id IS NOT NULL
                  AND NOT (root_id = ANY(CAST(:loaded_roots AS uuid[])))
            ),
            local_nodes(id) AS (
                SELECT wr.root_id
                FROM wanted_roots wr
                UNION
                SELECT n.id
                FROM anchors n
                JOIN wanted_roots wr ON wr.root_id = n.root_id
                WHERE n.kind = 'NodeAnchor'
            ),
            edge_rows AS (
                SELECT e.id, e.arch_type, e.src, e.dst, e.undirected, e.seq
                FROM anchors e
                JOIN local_nodes n ON n.id = e.src
                WHERE e.kind = 'EdgeAnchor'
                UNION
                SELECT e.id, e.arch_type, e.src, e.dst, e.undirected, e.seq
                FROM anchors e
                JOIN local_nodes n ON n.id = e.dst
                WHERE e.kind = 'EdgeAnchor'
            ),
            all_node_ids(id) AS (
                SELECT id FROM local_nodes
                UNION
                SELECT src FROM edge_rows WHERE src IS NOT NULL
                UNION
                SELECT dst FROM edge_rows WHERE dst IS NOT NULL
            ),
            node_rows AS (
                SELECT
                    0 AS ord,
                    n.id,
                    n.arch_type,
                    CASE
                        WHEN n.kind = 'NodeAnchor' AND n.arch_type = 'Root'
                            THEN n.id
                        ELSE n.root_id
                    END AS owner_root,
                    NULL::uuid AS src,
                    NULL::uuid AS dst,
                    false AS undirected,
                    COALESCE(string_agg(DISTINCT gt.ancestor, ','), n.arch_type)
                        AS ancestors,
                    NULL::bigint AS seq
                FROM anchors n
                JOIN all_node_ids a ON a.id = n.id
                LEFT JOIN graph_types gt ON gt.type_name = n.arch_type
                WHERE n.kind = 'NodeAnchor'
                GROUP BY n.id, n.kind, n.arch_type, n.root_id
            ),
            edge_out AS (
                SELECT
                    1 AS ord,
                    e.id,
                    e.arch_type,
                    NULL::uuid AS owner_root,
                    e.src,
                    e.dst,
                    e.undirected,
                    COALESCE(string_agg(DISTINCT gt.ancestor, ','), e.arch_type)
                        AS ancestors,
                    e.seq
                FROM edge_rows e
                LEFT JOIN graph_types gt ON gt.type_name = e.arch_type
                GROUP BY e.id, e.arch_type, e.src, e.dst, e.undirected, e.seq
            ),
            root_out AS (
                SELECT
                    2 AS ord,
                    wr.root_id AS id,
                    ''::text AS arch_type,
                    wr.root_id AS owner_root,
                    NULL::uuid AS src,
                    NULL::uuid AS dst,
                    false AS undirected,
                    ''::text AS ancestors,
                    NULL::bigint AS seq
                FROM wanted_roots wr
            )
            SELECT ord, id, arch_type, owner_root, src, dst, undirected, ancestors, seq
            FROM node_rows
            UNION ALL
            SELECT ord, id, arch_type, owner_root, src, dst, undirected, ancestors, seq
            FROM edge_out
            UNION ALL
            SELECT ord, id, arch_type, owner_root, src, dst, undirected, ancestors, seq
            FROM root_out
            ORDER BY ord, seq NULLS FIRST, id
            """,
            {
                'node_ids': [str(i) for i in pending],
                'loaded_roots': [str(i) for i in idx.loaded_roots]
            }
        );
        loaded = _ingest_topology_rows(idx, rows);
        idx.mark_roots_loaded(loaded);
        if loaded {
            logger.debug(
                f"[GTI] warmed roots={len(loaded)} nodes={len(idx.node_types)} "
                f"edges={len(idx.edge_ids)}"
            );
        }
    } finally {
        if lock is not None {
            lock.release();
        }
    }
    return idx;
}


impl warm_topology_for_hop(
    mem: any,
    origin_ids: list[UUID],
    edge_type: (str | None),
    node_type: (str | None),
    direction: int
) -> TopologyIndex {
    idx = _topology_index_for(mem);
    origins = _uniq_uuids(origin_ids);
    if not origins or mem is None or mem?.store is None {
        return idx;
    }
    dir = _norm_direction(direction);
    mem.read_barrier();
    lock = getattr(mem, "_topology_lock", None);
    if lock is not None {
        lock.acquire();
    }
    try {
        rows = mem.store.rows(
            """
            WITH seed(id) AS (
                SELECT unnest(CAST(:origin_ids AS uuid[]))
            ),
            origin_nodes AS (
                SELECT
                    n.id,
                    n.arch_type,
                    CASE
                        WHEN n.kind = 'NodeAnchor' AND n.arch_type = 'Root'
                            THEN n.id
                        ELSE n.root_id
                    END AS owner_root
                FROM anchors n
                JOIN seed s ON s.id = n.id
                WHERE n.kind = 'NodeAnchor'
            ),
            edge_rows AS (
                SELECT DISTINCT
                    e.id,
                    e.arch_type,
                    e.src,
                    e.dst,
                    e.undirected,
                    e.seq
                FROM anchors e
                JOIN seed s ON (
                    (CAST(:direction AS int) = 1
                        AND (e.dst = s.id OR (e.undirected AND e.src = s.id)))
                    OR (CAST(:direction AS int) = 2
                        AND (e.src = s.id OR (e.undirected AND e.dst = s.id)))
                    OR (CAST(:direction AS int) = 3
                        AND (e.src = s.id OR e.dst = s.id))
                )
                JOIN anchors tgt ON (
                    tgt.id = CASE WHEN e.src = s.id THEN e.dst ELSE e.src END
                    AND tgt.kind = 'NodeAnchor'
                )
                WHERE e.kind = 'EdgeAnchor'
                  AND e.src IS NOT NULL
                  AND e.dst IS NOT NULL
                  AND (
                      CAST(:edge_type AS text) IS NULL
                      OR e.arch_type = CAST(:edge_type AS text)
                      OR EXISTS (
                          SELECT 1 FROM graph_types gt
                          WHERE gt.type_name = e.arch_type
                            AND gt.ancestor = CAST(:edge_type AS text)
                      )
                  )
                  AND (
                      CAST(:node_type AS text) IS NULL
                      OR tgt.arch_type = CAST(:node_type AS text)
                      OR EXISTS (
                          SELECT 1 FROM graph_types gt
                          WHERE gt.type_name = tgt.arch_type
                            AND gt.ancestor = CAST(:node_type AS text)
                      )
                  )
            ),
            all_node_ids(id) AS (
                SELECT id FROM origin_nodes
                UNION
                SELECT src FROM edge_rows WHERE src IS NOT NULL
                UNION
                SELECT dst FROM edge_rows WHERE dst IS NOT NULL
            ),
            node_rows AS (
                SELECT
                    0 AS ord,
                    n.id,
                    n.arch_type,
                    CASE
                        WHEN n.kind = 'NodeAnchor' AND n.arch_type = 'Root'
                            THEN n.id
                        ELSE n.root_id
                    END AS owner_root,
                    NULL::uuid AS src,
                    NULL::uuid AS dst,
                    false AS undirected,
                    COALESCE(string_agg(DISTINCT gt.ancestor, ','), n.arch_type)
                        AS ancestors,
                    NULL::bigint AS seq
                FROM anchors n
                JOIN all_node_ids a ON a.id = n.id
                LEFT JOIN graph_types gt ON gt.type_name = n.arch_type
                WHERE n.kind = 'NodeAnchor'
                GROUP BY n.id, n.kind, n.arch_type, n.root_id
            ),
            edge_out AS (
                SELECT
                    1 AS ord,
                    e.id,
                    e.arch_type,
                    NULL::uuid AS owner_root,
                    e.src,
                    e.dst,
                    e.undirected,
                    COALESCE(string_agg(DISTINCT gt.ancestor, ','), e.arch_type)
                        AS ancestors,
                    e.seq
                FROM edge_rows e
                LEFT JOIN graph_types gt ON gt.type_name = e.arch_type
                GROUP BY e.id, e.arch_type, e.src, e.dst, e.undirected, e.seq
            )
            SELECT ord, id, arch_type, owner_root, src, dst, undirected, ancestors, seq
            FROM node_rows
            UNION ALL
            SELECT ord, id, arch_type, owner_root, src, dst, undirected, ancestors, seq
            FROM edge_out
            ORDER BY ord, seq NULLS FIRST, id
            """,
            {
                'origin_ids': [str(i) for i in origins],
                'edge_type': edge_type,
                'node_type': node_type,
                'direction': dir
            }
        );
        _ingest_topology_rows(idx, rows);
        idx.mark_hops_loaded(origins, edge_type, node_type, dir);
        logger.debug(
            f"[GTI] warmed hop origins={len(origins)} edge={edge_type} "
            f"node={node_type} dir={dir} nodes={len(idx.node_types)} "
            f"edges={len(idx.edge_ids)}"
        );
    } finally {
        if lock is not None {
            lock.release();
        }
    }
    return idx;
}
