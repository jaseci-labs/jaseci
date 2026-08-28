"""Last-observed-access-set prefetch policy."""

import threading;
import from typing { cast }
import from uuid { UUID }

import from jaclang.runtime.prefetch_policy_types {
    PrefetchPlanRequest,
    PrefetchPlanResult,
    dedupe_cap_uuid_list,
    prefetch_walker_keys
}

glob _history_lock: threading.Lock = threading.Lock(),
     _history_by_walker: dict[str, list[UUID]] = {};

def history_policy_plan(request: PrefetchPlanRequest) -> PrefetchPlanResult {
    import time as _time;
    plan_start = _time.perf_counter();
    ids: list[UUID] = [];
    with _history_lock {
        for key in prefetch_walker_keys(request.warch) {
            if key in _history_by_walker {
                ids = list(_history_by_walker[key]);
                break;
            }
        }
    }
    return PrefetchPlanResult(
        ids=dedupe_cap_uuid_list(ids, request.max_length),
        plan_ms=(_time.perf_counter() - plan_start) * 1000
    );
}

def record_history_observation(warch: any, ids: list, max_length: int = 200) -> None {
    capped = dedupe_cap_uuid_list(ids, max_length);
    if not capped {
        return;
    }
    keys = prefetch_walker_keys(warch);
    with _history_lock {
        for key in keys {
            _history_by_walker[key] = list(capped);
        }
    }
}

def clear_history_observations {
    with _history_lock {
        _history_by_walker.clear();
    }
}

def start_history_observation(ctx: any) -> bool {
    try {
        ctx._prefetch_observed_ids = [];
        import from jaclang.runtime.prefetch { prefetch_observation_begin }
        prefetch_observation_begin();
        return True;
    } except Exception {
        return False;
    }
}

def finish_history_observation(ctx: any, warch: any, max_length: int = 200) {
    try {
        ids = cast(list, getattr(ctx, "_prefetch_observed_ids", []));
        record_history_observation(warch, ids, max_length);
        delattr(ctx, "_prefetch_observed_ids");
    } except Exception {
        ;
    } finally {
        try {
            import from jaclang.runtime.prefetch { prefetch_observation_end }
            prefetch_observation_end();
        } except Exception {
            ;
        }
    }
}
