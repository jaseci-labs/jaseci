"""Runtime prefetch dispatcher and lightweight instrumentation."""

import logging;
import os;
import sys as _sys;
import threading;
import time as _time;
import from uuid { UUID }

import from jaclang.runtime.archetype { NodeAnchor }

glob logger = logging.getLogger(__name__),
     _prefetch_metrics_lock: threading.Lock = threading.Lock(),
     _prefetch_worker_times: list[float] = [],
     _prefetch_observation_count: int = 0;

def prefetch_worker_times_append(elapsed_ms: float) -> None {
    with _prefetch_metrics_lock {
        _prefetch_worker_times.append(elapsed_ms);
    }
}

def prefetch_worker_times_snapshot -> list[float] {
    with _prefetch_metrics_lock {
        return list(_prefetch_worker_times);
    }
}

def prefetch_worker_times_reset -> None {
    with _prefetch_metrics_lock {
        _prefetch_worker_times.clear();
    }
}

def prefetch_observation_begin -> None {
    with _prefetch_metrics_lock {
        _prefetch_observation_count += 1;
    }
}

def prefetch_observation_end -> None {
    with _prefetch_metrics_lock {
        _prefetch_observation_count = max(_prefetch_observation_count - 1, 0);
    }
}

def observe_anchor_access(id: UUID) -> None {
    with _prefetch_metrics_lock {
        active = _prefetch_observation_count > 0;
    }
    if not active {
        return;
    }
    try {
        import from jaclang.runtime.runtime { JacRuntimeInterface }
        ctx = JacRuntimeInterface.get_context();
        obs = ctx?._prefetch_observed_ids;
        if isinstance(obs, list) {
            obs.append(id);
        }
    } except Exception {
        ;
    }
}

def _chunk_evenly(items: list, n: int) -> list {
    if n <= 1 or len(items) <= 1 {
        return [items];
    }
    out: list = [];
    for k in range(n) {
        shard = items[k::n];
        if shard {
            out.append(shard);
        }
    }
    return out;
}

def _signal_done_after_all(threads: list, done: any) {
    for t in threads {
        t.join();
    }
    done.set();
}

def _prefetch_worker(mem: any, ids: list) -> None {
    try {
        mem.prefetch(ids);
    } except Exception as e {
        logger.debug(f"prefetch worker failed: {e}");
    }
}

def dispatch_prefetch(
    ctx: any, prefetch_ids: list, mode: str, workers: int = 1
) -> None {
    ctx.mem._prefetch_ids = set(prefetch_ids);
    ctx.mem._prefetch_done = threading.Event();
    if not prefetch_ids {
        ctx.mem._prefetch_done.set();
        return;
    }
    if mode == "process" {
        logger.warning(
            "async_prefetch='process' does not populate the parent raw cache on "
            "the Postgres backend; using thread mode"
        );
        mode = "thread";
    }
    if mode == "thread" {
        shards = _chunk_evenly(prefetch_ids, workers);
        threads: list = [];
        for shard in shards {
            t = threading.Thread(
                target=_prefetch_worker, args=(ctx.mem, shard), daemon=True,
            );
            t.start();
            threads.append(t);
        }
        ctx.mem._prefetch_thread = threads[0] if threads else None;
        ctx.mem._prefetch_threads = threads;
        if threads {
            mon = threading.Thread(
                target=_signal_done_after_all,
                args=(threads, ctx.mem._prefetch_done),
                daemon=True,
            );
            mon.start();
        } else {
            ctx.mem._prefetch_done.set();
        }
        return;
    }
    if workers <= 1 {
        _prefetch_worker(ctx.mem, prefetch_ids);
        ctx.mem._prefetch_done.set();
        return;
    }
    shards = _chunk_evenly(prefetch_ids, workers);
    threads: list = [];
    for shard in shards {
        t = threading.Thread(target=_prefetch_worker, args=(ctx.mem, shard));
        t.start();
        threads.append(t);
    }
    for t in threads {
        t.join();
    }
    ctx.mem._prefetch_done.set();
}

def run_prefetch_policy(ctx: any, cfg: any, warch: any, nd: NodeAnchor) -> tuple {
    if cfg is None or cfg?.run is None {
        return (0.0, 0.0, 0.0, 0.0);
    }
    run_cfg = cfg.run;
    policy_name: str = str(getattr(run_cfg, "prefetching", ""));
    limit: int = int(getattr(run_cfg, "prefetch_limit", 0) or 0);
    import from jaclang.runtime.prefetch_policy {
        get_prefetch_plan,
        normalize_prefetch_policy_name
    }
    policy = normalize_prefetch_policy_name(policy_name);
    if not policy_name or policy in ("none", "off", "false", "0") {
        return (0.0, 0.0, 0.0, 0.0);
    }
    if limit <= 0 and policy != "oracle" {
        return (0.0, 0.0, 0.0, 0.0);
    }
    plan = get_prefetch_plan(
        policy_name, warch, nd, mem=ctx.mem, max_length=limit, config=cfg
    );
    dispatch_ms = 0.0;
    if plan.ids {
        prefetch_start = _time.perf_counter();
        mode: str = str(getattr(run_cfg, "async_prefetch", ""));
        workers: int = int(getattr(run_cfg, "prefetch_workers", 1) or 1);
        if plan.single_query {
            workers = 1;
        }
        dispatch_prefetch(ctx, plan.ids, mode, workers);
        dispatch_ms = (_time.perf_counter() - prefetch_start) * 1000;
        gil_fn = getattr(_sys, "_is_gil_enabled", None);
        gil_enabled = gil_fn() if gil_fn is not None else True;
        logger.info(
            f"[PREFETCH] mode={mode or 'sync'} "
            f"workers={workers} ids={len(plan.ids)} "
            f"dispatch_ms={dispatch_ms:.2f} gil_enabled={gil_enabled}"
        );
    }
    logger.info(
        f"[PREFETCH-POLICY] policy={policy} ids={len(plan.ids)} "
        f"topology_ms={plan.topology_ms:.3f} plan_ms={plan.plan_ms:.3f}"
    );
    return (plan.topology_ms, plan.plan_ms, dispatch_ms, plan.resolve_ms);
}
