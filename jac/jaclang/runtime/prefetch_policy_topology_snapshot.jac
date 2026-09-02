"""Topology snapshot helpers for offline prefetch policies."""

import json;
import logging;
import os;
import from pathlib { Path }
import from uuid { UUID }

import from jaclang.runtime.topology_index { ingest_topology_rows }

glob logger = logging.getLogger(__name__);

def resolve_path_for_config(cfg: any, raw_path: str) -> Path {
    p = Path(raw_path);
    if p.is_absolute() {
        return p;
    }
    project_root = cfg?.project_root if cfg is not None else None;
    if project_root is not None {
        return Path(str(project_root)) / p;
    }
    return p;
}

def topology_snapshot_file_path(primary_file: Path) -> str {
    return str(primary_file) + ".topology.json";
}

def _json_safe_value(raw: any) -> any {
    if raw is None or isinstance(raw, (bool, int, float, str)) {
        return raw;
    }
    return str(raw);
}

def _json_safe_rows(rows: list) -> list {
    return [[_json_safe_value(value) for value in row] for row in rows];
}

def _snapshot_ids(snapshot: dict, policy: str) -> set[UUID] {
    raw_ids = snapshot.get("ids", None);
    if not isinstance(raw_ids, list) {
        raise ValueError(f"{policy} topology snapshot missing ids list");
    }
    out: set[UUID] = set();
    for raw in raw_ids {
        out.add(UUID(str(raw)));
    }
    return out;
}

def _validate_snapshot_ids(
    snapshot: dict, ids: list[UUID], path: Path, policy: str
) -> None {
    available = _snapshot_ids(snapshot, policy);
    missing = [str(uid) for uid in ids if uid not in available];
    if missing {
        raise ValueError(
            f"{policy} topology snapshot {path} does not cover "
            f"{len(missing)} planned id(s); first missing={missing[0]}"
        );
    }
}

def _prefetch_topology_rows(mem: any, ids: list[UUID]) -> list {
    if mem is None or mem.store is None or not ids {
        return [];
    }
    mem.read_barrier();
    return mem.store.rows(
        """
        WITH planned_ids AS (
            SELECT unnest(CAST(:ids AS uuid[])) AS id
        ),
        edge_rows AS (
            SELECT DISTINCT e.id, e.arch_type, e.src, e.dst, e.undirected, e.seq
            FROM anchors e
            JOIN planned_ids p ON e.id = p.id OR e.src = p.id OR e.dst = p.id
            WHERE e.kind = 'EdgeAnchor'
              AND e.src IS NOT NULL
              AND e.dst IS NOT NULL
        ),
        node_ids AS (
            SELECT id FROM planned_ids
            UNION
            SELECT src AS id FROM edge_rows
            UNION
            SELECT dst AS id FROM edge_rows
        ),
        node_rows AS (
            SELECT
                0 AS ord,
                n.id,
                n.arch_type,
                n.root_id AS owner_root,
                NULL::uuid AS src,
                NULL::uuid AS dst,
                false AS undirected,
                COALESCE(string_agg(DISTINCT gt.ancestor, ','), n.arch_type)
                    AS ancestors,
                NULL::bigint AS seq
            FROM anchors n
            JOIN node_ids ni ON ni.id = n.id
            LEFT JOIN graph_types gt ON gt.type_name = n.arch_type
            WHERE n.kind = 'NodeAnchor'
            GROUP BY n.id, n.arch_type, n.root_id
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
        {"ids": [str(i) for i in ids]}
    );
}

def write_prefetch_topology_snapshot(
    mem: any, ids: list[UUID], raw_path: str, cfg: any = None, policy: str = "prefetch"
) -> int {
    path = resolve_path_for_config(cfg, raw_path);
    if mem is None or mem.store is None {
        raise ValueError(f"{policy} topology snapshot recording requires a persistent store");
    }
    rows = _prefetch_topology_rows(mem, ids);
    if ids and not rows {
        raise ValueError(f"{policy} topology snapshot recording produced no rows");
    }
    payload = {
        "version": 1,
        "kind": f"{policy}_topology_snapshot",
        "policy": policy,
        "ids": [str(uid) for uid in ids],
        "rows": _json_safe_rows(rows),
        "query_count": 1
    };
    path.parent.mkdir(parents=True, exist_ok=True);
    tmp = Path(str(path) + ".tmp");
    tmp.write_text(json.dumps(payload, separators=(",", ":")) + "\n");
    os.replace(str(tmp), str(path));
    logger.info(
        f"[PREFETCH-TOPOLOGY-RECORD] policy={policy} ids={len(ids)} "
        f"topology_rows={len(rows)} path={path}"
    );
    return len(rows);
}

def _mark_prefetch_hops(idx: any, ids: list[UUID]) -> None {
    roots: list[UUID] = [];
    seen_roots: set[UUID] = set();
    for uid in ids {
        owner = idx.owner_root_for(uid);
        if owner is not None and owner not in seen_roots {
            seen_roots.add(owner);
            roots.append(owner);
        }
    }
    idx.mark_roots_loaded(roots);
    for uid in ids {
        type_name = idx.node_type(uid);
        if type_name is None {
            continue;
        }
        combos: set[tuple[str | None, str | None, int]] = set();
        for edge in idx.out_by_src.get(uid, []) {
            dst_type = idx.node_type(edge.dst);
            combos.add((edge.edge_type, dst_type, 1));
            combos.add((edge.edge_type, dst_type, 2));
            combos.add((edge.edge_type, None, 1));
            combos.add((edge.edge_type, None, 2));
            combos.add((None, dst_type, 1));
            combos.add((None, dst_type, 2));
            combos.add((None, None, 1));
            combos.add((None, None, 2));
        }
        for edge in idx.in_by_dst.get(uid, []) {
            src_type = idx.node_type(edge.src);
            combos.add((edge.edge_type, src_type, 3));
            combos.add((edge.edge_type, src_type, 2));
            combos.add((edge.edge_type, None, 3));
            combos.add((edge.edge_type, None, 2));
            combos.add((None, src_type, 3));
            combos.add((None, src_type, 2));
            combos.add((None, None, 3));
            combos.add((None, None, 2));
        }
        for (edge_type, node_type, direction) in combos {
            idx.mark_hops_loaded([uid], edge_type, node_type, direction);
        }
    }
}

def warm_prefetch_topology_from_snapshot(
    mem: any, ids: list[UUID], path: Path, policy: str = "prefetch"
) -> float {
    import time as _time;
    start = _time.perf_counter();
    if not path.exists() {
        logger.error(f"{policy} topology snapshot does not exist: {path}");
        raise FileNotFoundError(str(path));
    }
    with path.open() as fh {
        snapshot = json.load(fh);
    }
    if not isinstance(snapshot, dict) {
        raise ValueError(f"invalid {policy} topology snapshot at {path}");
    }
    _validate_snapshot_ids(snapshot, ids, path, policy);
    raw_rows = snapshot.get("rows", None);
    if not isinstance(raw_rows, list) {
        raise ValueError(f"{policy} topology snapshot {path} missing rows list");
    }
    rows: list = raw_rows;
    if mem is not None and rows {
        idx = ingest_topology_rows(mem, rows);
        _mark_prefetch_hops(idx, ids);
    }
    logger.info(
        f"[PREFETCH-TOPOLOGY] policy={policy} ids={len(ids)} "
        f"topology_rows={len(rows)} source=snapshot path={path} query_count=0"
    );
    return (_time.perf_counter() - start) * 1000;
}
