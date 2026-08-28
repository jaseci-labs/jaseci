"""TTG-backed prefetch prediction policy."""

import time as _time;
import from logging { getLogger as _getLogger }
import from jaclang.runtime.ttg { JacTTGGenerator }
import from jaclang.runtime.prefetch_policy_types {
    PrefetchPlanRequest,
    PrefetchPlanResult
}

def ttg_policy_plan(request: PrefetchPlanRequest) -> PrefetchPlanResult {
    result = PrefetchPlanResult(ids=[]);
    if request.start_anchor is None or request.start_id is None {
        return result;
    }
    plan_start = _time.perf_counter();
    result.ids = JacTTGGenerator.get_ttg_prefetch_list(
        request.warch,
        request.start_anchor,
        mem=request.mem,
        max_length=request.max_length
    );
    result.plan_ms = (_time.perf_counter() - plan_start) * 1000;
    result.resolve_ms = float(getattr(JacTTGGenerator, "_last_resolve_ms", 0.0));
    _getLogger(__name__).info(
        f"[TTG] ids={len(result.ids)} "
        f"plan_ms={result.plan_ms:.3f} resolve_ms={result.resolve_ms:.3f}"
    );
    return result;
}
