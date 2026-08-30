"""Hand-registered prefetch policy for experiments."""

import threading;
import from typing { cast }

import from jaclang.runtime.prefetch_policy_types {
    PrefetchPlanRequest,
    PrefetchPlanResult,
    dedupe_cap_uuid_list,
    prefetch_walker_keys
}

glob _manual_lock: threading.Lock = threading.Lock(),
     _manual_generators: dict[str, any] = {};

def _manual_key(walker_ref: any) -> str {
    if isinstance(walker_ref, str) {
        return walker_ref;
    }
    if isinstance(walker_ref, `type) {
        simple: str = str(getattr(walker_ref, "__name__", str(walker_ref)));
        module: str = str(getattr(walker_ref, "__module__", ""));
        return f"{module}.{simple}" if module else simple;
    }
    keys = prefetch_walker_keys(walker_ref);
    return keys[0] if keys else str(walker_ref);
}

def register_manual_prefetch_plan(walker_ref: any, generator: any) {
    key = _manual_key(walker_ref);
    with _manual_lock {
        _manual_generators[key] = generator;
    }
}

def unregister_manual_prefetch_plan(walker_ref: any) -> bool {
    key = _manual_key(walker_ref);
    with _manual_lock {
        if key in _manual_generators {
            del _manual_generators[key];
            return True;
        }
    }
    return False;
}

def clear_manual_prefetch_plans {
    with _manual_lock {
        _manual_generators.clear();
    }
}

def manual_policy_plan(request: PrefetchPlanRequest) -> PrefetchPlanResult {
    import time as _time;
    plan_start = _time.perf_counter();
    generator = None;
    with _manual_lock {
        for key in prefetch_walker_keys(request.warch) {
            if key in _manual_generators {
                generator = _manual_generators[key];
                break;
            }
        }
    }
    if generator is None {
        return PrefetchPlanResult(
            ids=[], plan_ms=(_time.perf_counter() - plan_start) * 1000
        );
    }
    raw: any = generator(request);
    if isinstance(raw, PrefetchPlanResult) {
        raw.ids = dedupe_cap_uuid_list(raw.ids, request.max_length);
        if raw.plan_ms == 0.0 {
            raw.plan_ms = (_time.perf_counter() - plan_start) * 1000;
        }
        return raw;
    }
    raw_ids = cast(list, raw if isinstance(raw, list) else []);
    return PrefetchPlanResult(
        ids=dedupe_cap_uuid_list(raw_ids, request.max_length),
        plan_ms=(_time.perf_counter() - plan_start) * 1000
    );
}
