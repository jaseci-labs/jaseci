"""Prefetch prediction policy facade."""

import logging;
import from typing { cast }
import from uuid { UUID }

import from jaclang.runtime.prefetch_policy_types {
    PrefetchPlanRequest,
    PrefetchPlanResult
}
import from jaclang.runtime.prefetch_policy_none { none_policy_plan }
import from jaclang.runtime.prefetch_policy_ttg { ttg_policy_plan }
import from jaclang.runtime.prefetch_policy_oracle { oracle_policy_plan }
import from jaclang.runtime.prefetch_policy_capre { capre_policy_plan }
import from jaclang.runtime.prefetch_policy_markov { markov_policy_plan }
import from jaclang.runtime.prefetch_policy_coaccess { coaccess_policy_plan }
import from jaclang.runtime.prefetch_policy_history {
    history_policy_plan,
    start_history_observation,
    finish_history_observation,
    clear_history_observations,
    record_history_observation
}
import from jaclang.runtime.prefetch_policy_manual {
    manual_policy_plan,
    register_manual_prefetch_plan,
    unregister_manual_prefetch_plan,
    clear_manual_prefetch_plans
}

glob logger = logging.getLogger(__name__);

def normalize_prefetch_policy_name(policy_name: str) -> str {
    return (policy_name or "").strip().lower();
}

def get_prefetch_plan(
    policy_name: str,
    warch: any,
    start_anchor: any,
    mem: any = None,
    max_length: int = 200,
    config: any = None
) -> PrefetchPlanResult {
    policy = normalize_prefetch_policy_name(policy_name);
    start_id = cast(
        (UUID | None), start_anchor?.id if start_anchor is not None else None
    );
    request = PrefetchPlanRequest(
        policy=policy,
        warch=warch,
        start_anchor=start_anchor,
        start_id=start_id,
        mem=mem,
        max_length=max_length,
        config=config
    );
    if policy in ("", "none", "off", "false", "0") {
        return none_policy_plan(request);
    }
    if policy == "ttg" {
        return ttg_policy_plan(request);
    }
    if policy == "oracle" {
        return oracle_policy_plan(request);
    }
    if policy == "capre" {
        return capre_policy_plan(request);
    }
    if policy == "markov" {
        return markov_policy_plan(request);
    }
    if policy == "coaccess" {
        return coaccess_policy_plan(request);
    }
    if policy == "history" {
        return history_policy_plan(request);
    }
    if policy == "manual" {
        return manual_policy_plan(request);
    }
    logger.warning(f"unknown prefetch policy '{policy_name}', skipping prefetch");
    return none_policy_plan(request);
}
