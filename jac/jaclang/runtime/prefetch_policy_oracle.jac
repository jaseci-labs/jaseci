"""Oracle prefetch policy."""

import json;
import logging;
import os;
import from pathlib { Path }
import from uuid { UUID }

import from jaclang.runtime.prefetch_policy_types {
    PrefetchPlanRequest,
    PrefetchPlanResult
}
import from jaclang.runtime.topology_index { ingest_topology_rows }

glob logger = logging.getLogger(__name__);

def _oracle_file_path(request: PrefetchPlanRequest) -> str {
    env_path = os.environ.get("JAC_PREFETCH_ORACLE_FILE", "");
    if env_path {
        return env_path;
    }
    cfg = request.config;
    if cfg is None {
        return "";
    }
    run_cfg = cfg?.run;
    val = getattr(run_cfg, "prefetch_oracle_file", "") if run_cfg is not None else "";
    return val if isinstance(val, str) else str(val);
}


def _oracle_topology_file_path(request: PrefetchPlanRequest, oracle_path: Path) -> str {
    env_path = os.environ.get("JAC_PREFETCH_ORACLE_TOPOLOGY_FILE", "");
    if env_path {
        return env_path;
    }
    cfg = request.config;
    run_cfg = cfg?.run if cfg is not None else None;
    val = (
        getattr(run_cfg, "prefetch_oracle_topology_file", "")
        if run_cfg is not None else ""
    );
    if val {
        return val if isinstance(val, str) else str(val);
    }
    return str(oracle_path) + ".topology.json";
}


def _oracle_record_topology_file_path(cfg: any) -> str {
    env_path = os.environ.get("JAC_PREFETCH_ORACLE_RECORD_TOPOLOGY_FILE", "");
    if env_path {
        return env_path;
    }
    run_cfg = cfg?.run if cfg is not None else None;
    val = (
        getattr(run_cfg, "prefetch_oracle_record_topology_file", "")
        if run_cfg is not None else ""
    );
    return val if isinstance(val, str) else str(val);
}


def _resolve_path_for_config(cfg: any, raw_path: str) -> Path {
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


def _resolve_oracle_path(request: PrefetchPlanRequest, raw_path: str) -> Path {
    return _resolve_path_for_config(request.config, raw_path);
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


def _snapshot_ids(snapshot: dict) -> set[UUID] {
    raw_ids = snapshot.get("ids", None);
    if not isinstance(raw_ids, list) {
        raise ValueError("oracle topology snapshot missing ids list");
    }
    out: set[UUID] = set();
    for raw in raw_ids {
        out.add(UUID(str(raw)));
    }
    return out;
}


def _validate_snapshot_ids(snapshot: dict, ids: list[UUID], path: Path) -> None {
    available = _snapshot_ids(snapshot);
    missing = [str(uid) for uid in ids if uid not in available];
    if missing {
        raise ValueError(
            f"oracle topology snapshot {path} does not cover "
            f"{len(missing)} planned id(s); first missing={missing[0]}"
        );
    }
}


def _is_resident_in_prefetch_cache(mem: any, id: UUID) -> bool {
    if mem is None {
        return False;
    }
    l1 = mem?.__mem__;
    if isinstance(l1, dict) and id in l1 {
        return True;
    }
    raw = mem?.__raw_mem__;
    if isinstance(raw, dict) and id in raw {
        return True;
    }
    return False;
}

def _append_oracle_id(ids: list[UUID], seen: set[UUID], mem: any, raw: any) -> None {
    try {
        id = raw if isinstance(raw, UUID) else UUID(str(raw));
    } except Exception {
        return;
    }
    if id in seen {
        return;
    }
    seen.add(id);
    if _is_resident_in_prefetch_cache(mem, id) {
        return;
    }
    ids.append(id);
}

def _oracle_topology_rows(mem: any, ids: list[UUID]) -> list {
    if mem is None or mem.store is None or not ids {
        return [];
    }
    mem.read_barrier();
    return mem.store.rows(
        """
        WITH oracle_ids AS (
            SELECT unnest(CAST(:ids AS uuid[])) AS id
        ),
        edge_rows AS (
            SELECT DISTINCT e.id, e.arch_type, e.src, e.dst, e.undirected, e.seq
            FROM anchors e
            JOIN oracle_ids o ON e.id = o.id OR e.src = o.id OR e.dst = o.id
            WHERE e.kind = 'EdgeAnchor'
              AND e.src IS NOT NULL
              AND e.dst IS NOT NULL
        ),
        node_ids AS (
            SELECT id FROM oracle_ids
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


def write_oracle_topology_snapshot(
    mem: any, ids: list[UUID], raw_path: str, cfg: any = None
) -> int {
    path = _resolve_path_for_config(cfg, raw_path);
    if mem is None or mem.store is None {
        raise ValueError("oracle topology snapshot recording requires a persistent store");
    }
    rows = _oracle_topology_rows(mem, ids);
    if ids and not rows {
        raise ValueError("oracle topology snapshot recording produced no rows");
    }
    payload = {
        "version": 1,
        "kind": "oracle_topology_snapshot",
        "ids": [str(uid) for uid in ids],
        "rows": _json_safe_rows(rows),
        "query_count": 1
    };
    path.parent.mkdir(parents=True, exist_ok=True);
    tmp = Path(str(path) + ".tmp");
    tmp.write_text(json.dumps(payload, separators=(",", ":")) + "\n");
    os.replace(str(tmp), str(path));
    logger.info(
        f"[ORACLE-TOPOLOGY-RECORD] ids={len(ids)} topology_rows={len(rows)} "
        f"path={path}"
    );
    return len(rows);
}


def maybe_write_oracle_topology_snapshot(ctx: any, cfg: any) -> None {
    raw_path = _oracle_record_topology_file_path(cfg);
    if not raw_path {
        return;
    }
    import from jaclang.server.session { access_log_seen_ids_snapshot }
    ids = access_log_seen_ids_snapshot();
    mem = ctx?.mem if ctx is not None else None;
    write_oracle_topology_snapshot(mem, ids, raw_path, cfg);
}


def _mark_oracle_hops(idx: any, ids: list[UUID]) -> None {
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


def _warm_oracle_topology_from_snapshot(
    mem: any, ids: list[UUID], path: Path
) -> float {
    import time as _time;
    start = _time.perf_counter();
    if not path.exists() {
        logger.error(f"oracle topology snapshot does not exist: {path}");
        raise FileNotFoundError(str(path));
    }
    with path.open() as fh {
        snapshot = json.load(fh);
    }
    if not isinstance(snapshot, dict) {
        raise ValueError(f"invalid oracle topology snapshot at {path}");
    }
    _validate_snapshot_ids(snapshot, ids, path);
    raw_rows = snapshot.get("rows", None);
    if not isinstance(raw_rows, list) {
        raise ValueError(f"oracle topology snapshot {path} missing rows list");
    }
    rows: list = raw_rows;
    if mem is not None and rows {
        idx = ingest_topology_rows(mem, rows);
        _mark_oracle_hops(idx, ids);
    }
    logger.info(
        f"[ORACLE-TOPOLOGY] ids={len(ids)} topology_rows={len(rows)} "
        f"source=snapshot path={path} query_count=0"
    );
    return (_time.perf_counter() - start) * 1000;
}

def oracle_policy_plan(request: PrefetchPlanRequest) -> PrefetchPlanResult {
    import time as _time;
    plan_start = _time.perf_counter();
    raw_path = _oracle_file_path(request);
    if not raw_path {
        logger.error(
            "prefetching=oracle requires run.prefetch_oracle_file or JAC_PREFETCH_ORACLE_FILE"
        );
        raise ValueError("oracle prefetch policy missing UUID file");
    }
    path = _resolve_oracle_path(request, raw_path);
    if not path.exists() {
        logger.error(f"oracle prefetch UUID file does not exist: {path}");
        raise FileNotFoundError(str(path));
    }
    ids: list[UUID] = [];
    seen: set[UUID] = set();
    with path.open() as fh {
        for (line_no, line_obj) in enumerate(fh, start=1) {
            line: str = str(line_obj);
            raw: str = line.strip();
            if not raw or raw.startswith("#") {
                continue;
            }
            if "#" in raw {
                raw = raw.split("#", 1)[0].strip();
            }
            if not raw {
                continue;
            }
            try {
                id = UUID(raw);
            } except Exception as e {
                logger.error(f"invalid oracle UUID at {path}:{line_no}: {raw}");
                raise e;
            }
            _append_oracle_id(ids, seen, request.mem, id);
            if request.max_length > 0 and len(ids) >= request.max_length {
                break;
            }
        }
    }
    raw_topology_path = _oracle_topology_file_path(request, path);
    topology_path = _resolve_oracle_path(request, raw_topology_path);
    topology_ms = _warm_oracle_topology_from_snapshot(request.mem, ids, topology_path);
    return PrefetchPlanResult(
        ids=ids,
        topology_ms=topology_ms,
        plan_ms=(_time.perf_counter() - plan_start) * 1000,
        single_query=True
    );
}
