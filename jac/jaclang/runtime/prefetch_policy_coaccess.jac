"""Offline co-access clustering prefetch policy."""

import json;
import logging;
import os;
import from pathlib { Path }

import from jaclang.runtime.prefetch_policy_types {
    PrefetchPlanRequest,
    PrefetchPlanResult,
    dedupe_cap_uuid_list
}
import from jaclang.runtime.prefetch_policy_topology_snapshot {
    resolve_path_for_config,
    topology_snapshot_file_path,
    warm_prefetch_topology_from_snapshot,
    write_prefetch_topology_snapshot
}

glob logger = logging.getLogger(__name__);

def _coaccess_file_path(request: PrefetchPlanRequest) -> str {
    env_path = os.environ.get("JAC_PREFETCH_COACCESS_FILE", "");
    if env_path {
        return env_path;
    }
    cfg = request.config;
    if cfg is None {
        return "";
    }
    run_cfg = cfg?.run;
    val = getattr(run_cfg, "prefetch_coaccess_file", "") if run_cfg is not None else "";
    return val if isinstance(val, str) else str(val);
}

def _resolve_coaccess_path(request: PrefetchPlanRequest, raw_path: str) -> Path {
    return resolve_path_for_config(request.config, raw_path);
}

def _coaccess_topology_file_path(
    request: PrefetchPlanRequest, model_path: Path
) -> str {
    env_path = os.environ.get("JAC_PREFETCH_COACCESS_TOPOLOGY_FILE", "");
    if env_path {
        return env_path;
    }
    cfg = request.config;
    run_cfg = cfg?.run if cfg is not None else None;
    val = (
        getattr(run_cfg, "prefetch_coaccess_topology_file", "")
        if run_cfg is not None else ""
    );
    if val {
        return val if isinstance(val, str) else str(val);
    }
    return topology_snapshot_file_path(model_path);
}

def _coaccess_record_topology_file_path(request: PrefetchPlanRequest) -> str {
    env_path = os.environ.get("JAC_PREFETCH_COACCESS_RECORD_TOPOLOGY_FILE", "");
    if env_path {
        return env_path;
    }
    cfg = request.config;
    run_cfg = cfg?.run if cfg is not None else None;
    val = (
        getattr(run_cfg, "prefetch_coaccess_record_topology_file", "")
        if run_cfg is not None else ""
    );
    return val if isinstance(val, str) else str(val);
}

def _model_entry_plan(model_entry: any) -> list {
    if isinstance(model_entry, dict) {
        raw = model_entry.get("plan", model_entry.get("ids", []));
        return raw if isinstance(raw, list) else [];
    }
    return model_entry if isinstance(model_entry, list) else [];
}

def _select_model_plan(model: dict, request: PrefetchPlanRequest) -> list {
    start_key = str(request.start_id) if request.start_id is not None else "";
    plans = model.get("plans", {});
    if isinstance(plans, dict) {
        if start_key and start_key in plans {
            return _model_entry_plan(plans[start_key]);
        }
        if "*" in plans {
            return _model_entry_plan(plans["*"]);
        }
    }
    starts = model.get("starts", {});
    if isinstance(starts, dict) {
        if start_key and start_key in starts {
            return _model_entry_plan(starts[start_key]);
        }
        if "*" in starts {
            return _model_entry_plan(starts["*"]);
        }
    }
    return _model_entry_plan(model.get("plan", model.get("fallback", [])));
}

def coaccess_policy_plan(request: PrefetchPlanRequest) -> PrefetchPlanResult {
    import time as _time;
    plan_start = _time.perf_counter();
    raw_path = _coaccess_file_path(request);
    if not raw_path {
        logger.error(
            "prefetching=coaccess requires run.prefetch_coaccess_file or JAC_PREFETCH_COACCESS_FILE"
        );
        raise ValueError("co-access prefetch policy missing model file");
    }
    path = _resolve_coaccess_path(request, raw_path);
    if not path.exists() {
        logger.error(f"co-access prefetch model file does not exist: {path}");
        raise FileNotFoundError(str(path));
    }
    with path.open() as fh {
        model = json.load(fh);
    }
    if not isinstance(model, dict) {
        logger.error(
            f"invalid co-access model at {path}: top-level JSON must be an object"
        );
        raise ValueError("invalid co-access prefetch model");
    }
    ids = _select_model_plan(model, request);
    capped = dedupe_cap_uuid_list(ids, request.max_length);
    record_topology_path = _coaccess_record_topology_file_path(request);
    if record_topology_path {
        topology_start = _time.perf_counter();
        write_prefetch_topology_snapshot(
            request.mem, capped, record_topology_path, request.config, "coaccess"
        );
        topology_ms = (_time.perf_counter() - topology_start) * 1000;
    } else {
        raw_topology_path = _coaccess_topology_file_path(request, path);
        topology_path = _resolve_coaccess_path(request, raw_topology_path);
        topology_ms = warm_prefetch_topology_from_snapshot(
            request.mem, capped, topology_path, "coaccess"
        );
    }
    return PrefetchPlanResult(
        ids=capped,
        topology_ms=topology_ms,
        plan_ms=(_time.perf_counter() - plan_start) * 1000
    );
}
