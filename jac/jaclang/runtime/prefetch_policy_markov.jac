"""Offline Markov prefetch policy."""

import json;
import logging;
import os;
import from pathlib { Path }

import from jaclang.runtime.prefetch_policy_types {
    PrefetchPlanRequest,
    PrefetchPlanResult,
    dedupe_cap_uuid_list
}

glob logger = logging.getLogger(__name__);

def _markov_file_path(request: PrefetchPlanRequest) -> str {
    env_path = os.environ.get("JAC_PREFETCH_MARKOV_FILE", "");
    if env_path {
        return env_path;
    }
    cfg = request.config;
    if cfg is None {
        return "";
    }
    run_cfg = cfg?.run;
    val = getattr(run_cfg, "prefetch_markov_file", "") if run_cfg is not None else "";
    return val if isinstance(val, str) else str(val);
}

def _resolve_markov_path(request: PrefetchPlanRequest, raw_path: str) -> Path {
    p = Path(raw_path);
    if p.is_absolute() {
        return p;
    }
    cfg = request.config;
    project_root = cfg?.project_root if cfg is not None else None;
    if project_root is not None {
        return Path(str(project_root)) / p;
    }
    return p;
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

def markov_policy_plan(request: PrefetchPlanRequest) -> PrefetchPlanResult {
    import time as _time;
    plan_start = _time.perf_counter();
    raw_path = _markov_file_path(request);
    if not raw_path {
        logger.error(
            "prefetching=markov requires run.prefetch_markov_file or JAC_PREFETCH_MARKOV_FILE"
        );
        raise ValueError("markov prefetch policy missing model file");
    }
    path = _resolve_markov_path(request, raw_path);
    if not path.exists() {
        logger.error(f"markov prefetch model file does not exist: {path}");
        raise FileNotFoundError(str(path));
    }
    with path.open() as fh {
        model = json.load(fh);
    }
    if not isinstance(model, dict) {
        logger.error(
            f"invalid markov model at {path}: top-level JSON must be an object"
        );
        raise ValueError("invalid markov prefetch model");
    }
    ids = _select_model_plan(model, request);
    capped = dedupe_cap_uuid_list(ids, request.max_length);
    return PrefetchPlanResult(
        ids=capped, plan_ms=(_time.perf_counter() - plan_start) * 1000
    );
}
