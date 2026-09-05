"""CAPRe-style policy facade.

The runtime dispatcher handles CAPRe specially because CAPRe produces dependent
ordinary object-load tasks instead of a complete UUID plan.
"""

import from jaclang.runtime.prefetch_policy_types {
    PrefetchPlanRequest,
    PrefetchPlanResult
}
import from jaclang.runtime.prefetch_policy_capre_runtime { capre_plan_metadata }


def capre_policy_plan(request: PrefetchPlanRequest) -> PrefetchPlanResult {
    meta = capre_plan_metadata(request);
    return PrefetchPlanResult(
        ids=[],
        topology_ms=float(meta.get("topology_ms", 0.0)),
        plan_ms=float(meta.get("plan_ms", 0.0)),
        resolve_ms=float(meta.get("resolve_ms", 0.0)),
        single_query=False
    );
}
