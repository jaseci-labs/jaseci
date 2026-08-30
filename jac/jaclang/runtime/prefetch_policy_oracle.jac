"""Oracle prefetch policy.

The oracle input is an explicit UUID list, one UUID per line.
"""

import logging;
import os;
import from pathlib { Path }
import from uuid { UUID }

import from jaclang.runtime.prefetch_policy_types {
    PrefetchPlanRequest,
    PrefetchPlanResult
}

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

def _resolve_oracle_path(request: PrefetchPlanRequest, raw_path: str) -> Path {
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
            if id in seen {
                continue;
            }
            seen.add(id);
            if _is_resident_in_prefetch_cache(request.mem, id) {
                continue;
            }
            ids.append(id);
            if len(ids) >= request.max_length {
                break;
            }
        }
    }
    return PrefetchPlanResult(
        ids=ids, plan_ms=(_time.perf_counter() - plan_start) * 1000
    );
}
