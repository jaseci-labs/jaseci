"""CAPRe-style asynchronous object-load baseline for Jac TTG experiments.

This module intentionally does not call TTG's SQL traversal executor.  It reuses
TTG's statically recovered visit paths, then advances those paths with ordinary
known-id object loads through the existing Store.load_full() API.
"""

from __future__ import annotations

import csv
import json
import logging
import os
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any
from uuid import UUID, uuid4

logger = logging.getLogger(__name__)


def _as_uuid(raw: Any) -> UUID | None:
    if raw is None:
        return None
    if isinstance(raw, UUID):
        return raw
    try:
        return UUID(str(raw))
    except Exception:
        return None


def _env_bool(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None or raw == "":
        return default
    return raw.strip().lower() not in {"0", "false", "no", "off"}


def _env_int(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if raw is None or raw == "":
        return default
    try:
        return int(raw)
    except (TypeError, ValueError):
        return default


def _env_float(name: str, default: float) -> float:
    raw = os.environ.get(name)
    if raw is None or raw == "":
        return default
    try:
        return float(raw)
    except (TypeError, ValueError):
        return default


@dataclass(frozen=True)
class CapreHop:
    edge_type: str | None
    node_type: str | None
    direction: int = 2


@dataclass(frozen=True)
class CapreSpec:
    idx: int
    from_type: str | None
    chain: tuple[CapreHop, ...]
    is_visit: bool = True
    origin_name: str = ""


@dataclass
class CapreConfig:
    enabled: bool = True
    max_concurrent: int = 4
    max_depth: int = 0
    max_objects: int = 200
    trace_file: str = ""
    metrics_file: str = ""
    drain_at_exit: bool = True
    shutdown_timeout_s: float = 30.0


@dataclass
class _RowView:
    id: UUID
    kind: str
    arch_type: str = ""
    root_id: UUID | None = None
    src: UUID | None = None
    dst: UUID | None = None
    undirected: bool = False
    adjacency: list[UUID] | None = None
    ancestry: list[str] = field(default_factory=list)


@dataclass
class CapreState:
    mem: Any
    config: CapreConfig
    specs: list[CapreSpec]
    start_id: UUID | None
    root_id: UUID | None = None
    run_id: str = field(default_factory=lambda: str(uuid4()))
    lock: threading.RLock = field(default_factory=threading.RLock)
    cond: threading.Condition = field(init=False)
    done_event: threading.Event = field(default_factory=threading.Event)
    stop_event: threading.Event = field(default_factory=threading.Event)
    executor: ThreadPoolExecutor | None = None
    driver_thread: threading.Thread | None = None
    pending_tasks: int = 0
    started_at: float = field(default_factory=time.perf_counter)
    finished_at: float | None = None
    drain_ms: float = 0.0
    prefetch_wall_ms: float = 0.0
    outputs_written: bool = False
    issued: set[UUID] = field(default_factory=set)
    prefetched: set[UUID] = field(default_factory=set)
    demanded: set[UUID] = field(default_factory=set)
    useful_prefetches: set[UUID] = field(default_factory=set)
    late_prefetches: set[UUID] = field(default_factory=set)
    in_flight: dict[UUID, threading.Event] = field(default_factory=dict)
    duplicate_prefetches_suppressed: int = 0
    prefetch_l3_requests: int = 0
    prefetch_l3_objects: int = 0
    demand_l3_requests: int = 0
    demand_l3_objects: int = 0
    db_round_trips: int = 0
    peak_inflight: int = 0
    inflight_samples: list[int] = field(default_factory=list)
    limit_dropped: int = 0
    depth_dropped: int = 0
    cache_skips: int = 0
    errors: list[str] = field(default_factory=list)
    trace: list[dict[str, Any]] = field(default_factory=list)

    def __post_init__(self) -> None:
        self.cond = threading.Condition(self.lock)

    def trace_event(
        self,
        event: str,
        uid: UUID | None = None,
        *,
        request_type: str = "prefetch",
        parent_id: UUID | None = None,
        path_id: str = "",
        depth: int = 0,
        kind: str = "",
        note: str = "",
        elapsed_ms: float | None = None,
        object_count: int = 1,
    ) -> None:
        now = time.perf_counter()
        with self.lock:
            self.trace.append(
                {
                    "run_id": self.run_id,
                    "policy": "capre",
                    "event": event,
                    "t_ms": f"{(now - self.started_at) * 1000.0:.3f}",
                    "id": str(uid) if uid is not None else "",
                    "request_type": request_type,
                    "parent_id": str(parent_id) if parent_id is not None else "",
                    "path_id": path_id,
                    "depth": depth,
                    "kind": kind,
                    "inflight": len(self.in_flight),
                    "object_count": object_count,
                    "elapsed_ms": "" if elapsed_ms is None else f"{elapsed_ms:.3f}",
                    "note": note,
                }
            )

    def _sample_inflight_locked(self) -> None:
        cur = len(self.in_flight)
        self.peak_inflight = max(self.peak_inflight, cur)
        self.inflight_samples.append(cur)

    def submit(self, fn: Any, *args: Any) -> None:
        with self.cond:
            if self.stop_event.is_set() or self.executor is None:
                return
            self.pending_tasks += 1
            self.executor.submit(self._run_task, fn, args)

    def _run_task(self, fn: Any, args: tuple[Any, ...]) -> None:
        try:
            fn(*args)
        except Exception as exc:  # pragma: no cover - surfaced via metrics/logs.
            with self.lock:
                self.errors.append(f"{type(exc).__name__}: {exc}")
            logger.debug("CAPRe prefetch task failed: %s", exc)
        finally:
            with self.cond:
                self.pending_tasks -= 1
                if self.pending_tasks <= 0:
                    self.cond.notify_all()

    def wait_for_tasks(self) -> None:
        with self.cond:
            while self.pending_tasks > 0:
                self.cond.wait()

    def origins_for(self, spec: CapreSpec) -> list[UUID]:
        if spec.origin_name == "root":
            return [self.root_id] if self.root_id is not None else []
        return [self.start_id] if self.start_id is not None else []

    def snapshot(self) -> dict[str, Any]:
        with self.lock:
            unused = self.prefetched - self.demanded - self.useful_prefetches
            avg_inflight = (
                sum(self.inflight_samples) / len(self.inflight_samples)
                if self.inflight_samples
                else 0.0
            )
            total_l3 = self.prefetch_l3_requests + self.demand_l3_requests
            return {
                "policy": "capre",
                "run_id": self.run_id,
                "enabled": self.config.enabled,
                "specs": len(self.specs),
                "prefetch_l3_requests": self.prefetch_l3_requests,
                "prefetch_l3_objects": self.prefetch_l3_objects,
                "demand_l3_requests": self.demand_l3_requests,
                "demand_l3_objects": self.demand_l3_objects,
                "total_l3_requests": total_l3,
                "demand_l2_hits": 0,
                "demand_l2_hit_rate": 0.0,
                "useful_prefetches": len(self.useful_prefetches),
                "late_prefetches": len(self.late_prefetches),
                "unused_prefetches": len(unused),
                "duplicate_prefetches_suppressed": self.duplicate_prefetches_suppressed,
                "bytes_transferred": 0,
                "bytes_available": False,
                "peak_inflight": self.peak_inflight,
                "avg_inflight": avg_inflight,
                "app_db_round_trips": self.db_round_trips,
                "cache_skips": self.cache_skips,
                "limit_dropped": self.limit_dropped,
                "depth_dropped": self.depth_dropped,
                "issued_objects": len(self.issued),
                "prefetched_objects": len(self.prefetched),
                "demanded_objects": len(self.demanded),
                "inflight_objects": len(self.in_flight),
                "done": self.finished_at is not None,
                "drain_ms": self.drain_ms,
                "prefetch_wall_ms": self.prefetch_wall_ms,
                "errors": len(self.errors),
                "trace_file": self.config.trace_file,
                "metrics_file": self.config.metrics_file,
            }

    def write_outputs(self) -> None:
        with self.lock:
            if self.outputs_written:
                return
            self.outputs_written = True
            trace_rows = list(self.trace)
            metrics = self.snapshot()
            trace_file = self.config.trace_file
            metrics_file = self.config.metrics_file
        if trace_file:
            _append_trace_file(trace_file, trace_rows)
        if metrics_file:
            _append_metrics_file(metrics_file, metrics)


def _append_trace_file(path_raw: str, rows: list[dict[str, Any]]) -> None:
    if not rows:
        return
    path = Path(path_raw)
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "run_id",
        "policy",
        "event",
        "t_ms",
        "id",
        "request_type",
        "parent_id",
        "path_id",
        "depth",
        "kind",
        "inflight",
        "object_count",
        "elapsed_ms",
        "note",
    ]
    exists = path.exists()
    with path.open("a", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames, extrasaction="ignore")
        if not exists:
            writer.writeheader()
        writer.writerows(rows)


def _append_metrics_file(path_raw: str, metrics: dict[str, Any]) -> None:
    path = Path(path_raw)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a") as fh:
        fh.write(json.dumps(metrics, sort_keys=True, separators=(",", ":")) + "\n")


def _resolve_type_name(raw: Any) -> str | None:
    if raw is None:
        return None
    if isinstance(raw, str):
        return raw
    try:
        from jaclang.runtime.ttg import JacTTGGenerator

        resolved = JacTTGGenerator._resolve_type_name(raw)
        if resolved is not None:
            return str(resolved)
    except Exception:
        pass
    name = getattr(raw, "__name__", None)
    return str(name) if name else str(raw)


def _specs_from_visits(visits: list[Any]) -> list[CapreSpec]:
    specs: list[CapreSpec] = []
    for raw in visits:
        if isinstance(raw, CapreSpec):
            specs.append(raw)
            continue
        if isinstance(raw, dict):
            specs.append(_spec_from_dict(raw, len(specs)))
            continue
        raw_chain = getattr(raw, "edge_chain", None)
        if raw_chain is None:
            raw_chain = [(_resolve_type_name(getattr(raw, "edge_type", None)), None, 2)]
        chain = _normalize_chain(raw_chain)
        if not chain:
            continue
        specs.append(
            CapreSpec(
                idx=len(specs),
                from_type=_resolve_type_name(getattr(raw, "from_node_type", None)),
                chain=tuple(chain),
                is_visit=bool(getattr(raw, "is_visit", True)),
                origin_name=str(getattr(raw, "origin_name", "") or ""),
            )
        )
    return specs


def _spec_from_dict(raw: dict[str, Any], idx: int) -> CapreSpec:
    raw_chain = raw.get("chain") or raw.get("edge_chain") or []
    return CapreSpec(
        idx=int(raw.get("idx", idx)),
        from_type=_resolve_type_name(raw.get("from_type")),
        chain=tuple(_normalize_chain(raw_chain)),
        is_visit=bool(raw.get("is_visit", True)),
        origin_name=str(raw.get("origin_name") or ""),
    )


def _normalize_chain(raw_chain: Any) -> list[CapreHop]:
    out: list[CapreHop] = []
    for hop in raw_chain or []:
        if isinstance(hop, CapreHop):
            out.append(hop)
            continue
        if isinstance(hop, dict):
            edge_type = _resolve_type_name(hop.get("edge_type") or hop.get("edge"))
            node_type = _resolve_type_name(hop.get("node_type") or hop.get("node"))
            direction_raw = hop.get("direction", hop.get("dir", 2))
        else:
            try:
                edge_type = _resolve_type_name(hop[0])
                node_type = _resolve_type_name(hop[1])
                direction_raw = hop[2] if len(hop) > 2 else 2
            except Exception:
                continue
        try:
            direction = int(direction_raw or 2)
        except Exception:
            direction = 2
        if direction not in (1, 2, 3):
            direction = 2
        out.append(CapreHop(edge_type=edge_type, node_type=node_type, direction=direction))
    return out


def _extract_specs_for_warch(warch: Any) -> list[CapreSpec]:
    if warch is None:
        return []
    from jaclang.runtime.ttg import JacTTGGenerator

    return _specs_from_visits(JacTTGGenerator._extract_visits_from_ast(warch))


def _run_config(cfg: Any, max_length: int = 0) -> CapreConfig:
    run_cfg = getattr(cfg, "run", None)
    enabled = bool(getattr(run_cfg, "capre_enabled", True)) if run_cfg is not None else True
    enabled = _env_bool("JAC_CAPRE_ENABLED", enabled)
    workers_default = 4
    if run_cfg is not None:
        try:
            workers_default = int(getattr(run_cfg, "capre_max_concurrent", 0) or 0)
        except Exception:
            workers_default = 0
        if workers_default <= 0:
            try:
                workers_default = int(getattr(run_cfg, "prefetch_workers", 0) or 0)
            except Exception:
                workers_default = 0
    if workers_default <= 0:
        workers_default = 4
    max_concurrent = max(1, _env_int("JAC_CAPRE_MAX_CONCURRENT", workers_default))
    max_depth_default = int(getattr(run_cfg, "capre_max_depth", 0) or 0) if run_cfg is not None else 0
    max_depth = max(0, _env_int("JAC_CAPRE_MAX_DEPTH", max_depth_default))
    max_objects_default = int(getattr(run_cfg, "capre_max_objects", 0) or 0) if run_cfg is not None else 0
    if max_objects_default <= 0 and max_length > 0:
        max_objects_default = int(max_length)
    max_objects = max(0, _env_int("JAC_CAPRE_MAX_OBJECTS", max_objects_default))
    trace_file = os.environ.get("JAC_CAPRE_TRACE_FILE", "")
    metrics_file = os.environ.get("JAC_CAPRE_METRICS_FILE", "")
    if run_cfg is not None:
        trace_file = trace_file or str(getattr(run_cfg, "capre_trace_file", "") or "")
        metrics_file = metrics_file or str(getattr(run_cfg, "capre_metrics_file", "") or "")
    profile_dir = os.environ.get("JAC_PROFILE_DIR", "")
    if profile_dir:
        trace_file = trace_file or str(Path(profile_dir) / "capre_trace.csv")
        metrics_file = metrics_file or str(Path(profile_dir) / "capre_metrics.jsonl")
    drain_default = bool(getattr(run_cfg, "capre_drain_at_exit", True)) if run_cfg is not None else True
    drain_at_exit = _env_bool("JAC_CAPRE_DRAIN_AT_EXIT", drain_default)
    timeout_default = (
        float(getattr(run_cfg, "capre_shutdown_timeout_s", 30.0) or 30.0)
        if run_cfg is not None
        else 30.0
    )
    shutdown_timeout_s = max(0.0, _env_float("JAC_CAPRE_SHUTDOWN_TIMEOUT_S", timeout_default))
    return CapreConfig(
        enabled=enabled,
        max_concurrent=max_concurrent,
        max_depth=max_depth,
        max_objects=max_objects,
        trace_file=trace_file,
        metrics_file=metrics_file,
        drain_at_exit=drain_at_exit,
        shutdown_timeout_s=shutdown_timeout_s,
    )


def capre_plan_metadata(request: Any) -> dict[str, Any]:
    start = time.perf_counter()
    specs = _extract_specs_for_warch(getattr(request, "warch", None))
    return {
        "ids": 0,
        "specs": len(specs),
        "topology_ms": 0.0,
        "plan_ms": (time.perf_counter() - start) * 1000.0,
        "resolve_ms": 0.0,
    }


def start_capre_prefetch(
    ctx: Any,
    cfg: Any,
    warch: Any,
    start_anchor: Any,
    max_length: int = 0,
) -> dict[str, Any]:
    plan_start = time.perf_counter()
    mem = getattr(ctx, "mem", None)
    start_id = _as_uuid(getattr(start_anchor, "id", None))
    config = _run_config(cfg, max_length)
    if not config.enabled or mem is None or getattr(mem, "store", None) is None or start_id is None:
        return {
            "ids": 0,
            "specs": 0,
            "topology_ms": 0.0,
            "plan_ms": (time.perf_counter() - plan_start) * 1000.0,
            "resolve_ms": 0.0,
            "started": False,
        }
    specs = _extract_specs_for_warch(warch)
    root_id: UUID | None = None
    if any(spec.origin_name == "root" for spec in specs):
        root_id = _as_uuid(getattr(getattr(ctx, "user_root", None), "id", None))
    state = _install_state(mem, specs, start_id, root_id, config)
    _start_state(state)
    return {
        "ids": 0,
        "specs": len(specs),
        "topology_ms": 0.0,
        "plan_ms": (time.perf_counter() - plan_start) * 1000.0,
        "resolve_ms": 0.0,
        "started": True,
        "state": state,
    }


def start_capre_for_test(
    mem: Any,
    specs: list[Any],
    origins: list[UUID],
    config: CapreConfig | None = None,
) -> CapreState:
    norm_specs = _specs_from_visits(specs)
    start_id = origins[0] if origins else None
    root_id = origins[1] if len(origins) > 1 else None
    state = _install_state(mem, norm_specs, start_id, root_id, config or CapreConfig())
    _start_state(state)
    return state


def run_capre_for_test(
    mem: Any,
    specs: list[Any],
    origins: list[UUID],
    config: CapreConfig | None = None,
) -> CapreState:
    state = start_capre_for_test(mem, specs, origins, config)
    _finish_state(state, wait=True)
    return state


def _install_state(
    mem: Any,
    specs: list[CapreSpec],
    start_id: UUID | None,
    root_id: UUID | None,
    config: CapreConfig,
) -> CapreState:
    old = getattr(mem, "_capre_state", None)
    if isinstance(old, CapreState) and old.finished_at is None:
        old.stop_event.set()
        _finish_state(old, wait=True)
    state = CapreState(mem=mem, config=config, specs=specs, start_id=start_id, root_id=root_id)
    setattr(mem, "_capre_state", state)
    try:
        mem._prefetch_ids = set()
        mem._prefetch_done = state.done_event
    except Exception:
        pass
    return state


def _start_state(state: CapreState) -> None:
    if not state.specs:
        state.finished_at = time.perf_counter()
        state.done_event.set()
        _set_mem_prefetch_done(state)
        return
    state.driver_thread = threading.Thread(target=_driver, args=(state,), daemon=True)
    state.driver_thread.start()


def _driver(state: CapreState) -> None:
    start = time.perf_counter()
    state.trace_event("trigger", request_type="method_entry", note="walker_spawn_entry")
    try:
        with ThreadPoolExecutor(max_workers=state.config.max_concurrent) as executor:
            state.executor = executor
            for spec in state.specs:
                for origin in state.origins_for(spec):
                    path_id = f"spec{spec.idx}:{origin}"
                    state.submit(_advance_path, state, origin, spec, 0, None, path_id, spec.from_type)
            state.wait_for_tasks()
    except Exception as exc:
        with state.lock:
            state.errors.append(f"{type(exc).__name__}: {exc}")
        logger.debug("CAPRe driver failed: %s", exc)
    finally:
        elapsed_ms = (time.perf_counter() - start) * 1000.0
        with state.lock:
            state.finished_at = time.perf_counter()
            state.prefetch_wall_ms = elapsed_ms
        state.done_event.set()
        _set_mem_prefetch_done(state)
        state.write_outputs()


def _finish_state(state: CapreState, wait: bool) -> dict[str, Any]:
    start = time.perf_counter()
    if wait and state.driver_thread is not None and state.driver_thread.is_alive():
        timeout = state.config.shutdown_timeout_s
        state.driver_thread.join(timeout=timeout if timeout > 0 else None)
    if state.driver_thread is not None and state.driver_thread.is_alive():
        state.stop_event.set()
        state.driver_thread.join(timeout=state.config.shutdown_timeout_s or 0.0)
    with state.lock:
        state.drain_ms += (time.perf_counter() - start) * 1000.0
    state.write_outputs()
    return state.snapshot()


def finish_capre_prefetch(ctx: Any, cfg: Any = None) -> dict[str, Any]:
    mem = getattr(ctx, "mem", ctx)
    state = getattr(mem, "_capre_state", None)
    if not isinstance(state, CapreState):
        return {}
    config = state.config
    wait = bool(config.drain_at_exit)
    return _finish_state(state, wait=wait)


def capre_metrics_snapshot(mem: Any) -> dict[str, Any]:
    state = getattr(mem, "_capre_state", None)
    if not isinstance(state, CapreState):
        return {}
    return state.snapshot()


def capre_trace_snapshot(mem: Any) -> list[dict[str, Any]]:
    state = getattr(mem, "_capre_state", None)
    if not isinstance(state, CapreState):
        return []
    with state.lock:
        return list(state.trace)


def capre_reset_for_tests(mem: Any) -> None:
    state = getattr(mem, "_capre_state", None)
    if isinstance(state, CapreState):
        state.stop_event.set()
        _finish_state(state, wait=True)
    if hasattr(mem, "_capre_state"):
        delattr(mem, "_capre_state")


def capre_record_demand_access(mem: Any, raw_id: Any, tier: str = "") -> None:
    state = getattr(mem, "_capre_state", None)
    uid = _as_uuid(raw_id)
    if not isinstance(state, CapreState) or uid is None:
        return
    with state.lock:
        state.demanded.add(uid)
        if uid in state.in_flight:
            state.late_prefetches.add(uid)
            note = "late_prefetch"
        elif uid in state.prefetched:
            state.useful_prefetches.add(uid)
            note = "useful_prefetch"
        else:
            note = ""
    state.trace_event("demand_access", uid, request_type=f"demand_{tier}", note=note)


def capre_record_demand_l3_request(mem: Any, ids: Any) -> None:
    state = getattr(mem, "_capre_state", None)
    if not isinstance(state, CapreState):
        return
    id_list = [_as_uuid(i) for i in list(ids or [])]
    clean = [i for i in id_list if i is not None]
    with state.lock:
        state.demand_l3_requests += 1
        state.demand_l3_objects += len(clean)
        state.db_round_trips += 1
    for uid in clean:
        state.trace_event("issue", uid, request_type="demand_l3", object_count=len(clean))


def _advance_path(
    state: CapreState,
    current_id: UUID,
    spec: CapreSpec,
    depth: int,
    parent_id: UUID | None,
    path_id: str,
    expected_type: str | None,
) -> None:
    if state.stop_event.is_set():
        return
    row = _load_id(state, current_id, parent_id=parent_id, depth=depth, kind="node", path_id=path_id)
    if row is None or _row_kind(row) != "NodeAnchor":
        return
    if expected_type is not None and not _type_matches(row, expected_type):
        return
    if state.config.max_depth > 0 and depth >= state.config.max_depth:
        with state.lock:
            state.depth_dropped += 1
        state.trace_event("depth_limit", current_id, parent_id=parent_id, path_id=path_id, depth=depth)
        return
    if depth >= len(spec.chain):
        return
    hop = spec.chain[depth]
    target_ids = _resolve_hop_target_ids(state, row, hop, depth, path_id)
    next_depth = depth + 1
    for target_id in target_ids:
        if next_depth >= len(spec.chain):
            state.submit(_terminal_load, state, target_id, hop.node_type, current_id, next_depth, path_id)
        else:
            state.submit(
                _advance_path,
                state,
                target_id,
                spec,
                next_depth,
                current_id,
                path_id,
                hop.node_type,
            )


def _terminal_load(
    state: CapreState,
    target_id: UUID,
    expected_type: str | None,
    parent_id: UUID | None,
    depth: int,
    path_id: str,
) -> None:
    row = _load_id(state, target_id, parent_id=parent_id, depth=depth, kind="node", path_id=path_id)
    if row is not None and expected_type is not None and not _type_matches(row, expected_type):
        state.trace_event("type_miss", target_id, parent_id=parent_id, path_id=path_id, depth=depth)


def _resolve_hop_target_ids(
    state: CapreState,
    node_row: Any,
    hop: CapreHop,
    depth: int,
    path_id: str,
) -> list[UUID]:
    origin_id = _as_uuid(getattr(node_row, "id", None))
    if origin_id is None:
        return []
    edge_ids = [_as_uuid(eid) for eid in list(getattr(node_row, "adjacency", None) or [])]
    targets: list[UUID] = []
    seen_targets: set[UUID] = set()
    seen_edges: set[UUID] = set()
    for edge_id in edge_ids:
        if edge_id is None or edge_id in seen_edges:
            continue
        seen_edges.add(edge_id)
        edge_row = _load_id(
            state,
            edge_id,
            parent_id=origin_id,
            depth=depth,
            kind="edge",
            path_id=path_id,
        )
        if edge_row is None or _row_kind(edge_row) != "EdgeAnchor":
            continue
        if not _type_matches(edge_row, hop.edge_type):
            continue
        other = _edge_other(edge_row, origin_id, hop.direction)
        if other is not None and other not in seen_targets:
            seen_targets.add(other)
            targets.append(other)
    return targets


def _load_id(
    state: CapreState,
    uid: UUID,
    *,
    parent_id: UUID | None,
    depth: int,
    kind: str,
    path_id: str,
) -> Any | None:
    cached = _cached_row(state.mem, uid)
    if cached is not None:
        with state.lock:
            state.cache_skips += 1
        state.trace_event("cache_skip", uid, parent_id=parent_id, path_id=path_id, depth=depth, kind=kind)
        return cached

    event: threading.Event | None = None
    do_load = False
    with state.lock:
        cached = _cached_row(state.mem, uid)
        if cached is not None:
            state.cache_skips += 1
            state.trace_event("cache_skip", uid, parent_id=parent_id, path_id=path_id, depth=depth, kind=kind)
            return cached
        event = state.in_flight.get(uid)
        if event is not None:
            state.duplicate_prefetches_suppressed += 1
            state.trace_event("duplicate_wait", uid, parent_id=parent_id, path_id=path_id, depth=depth, kind=kind)
        else:
            if state.config.max_objects > 0 and state.prefetch_l3_objects >= state.config.max_objects:
                state.limit_dropped += 1
                state.trace_event("object_limit", uid, parent_id=parent_id, path_id=path_id, depth=depth, kind=kind)
                return None
            event = threading.Event()
            state.in_flight[uid] = event
            state.issued.add(uid)
            state.prefetch_l3_requests += 1
            state.prefetch_l3_objects += 1
            state.db_round_trips += 1
            state._sample_inflight_locked()
            _add_mem_prefetch_id(state.mem, uid)
            state.trace_event("issue", uid, request_type="prefetch_l3", parent_id=parent_id, path_id=path_id, depth=depth, kind=kind)
            do_load = True

    if not do_load:
        assert event is not None
        event.wait()
        return _cached_row(state.mem, uid)

    loaded_row: Any | None = None
    load_start = time.perf_counter()
    try:
        store = getattr(state.mem, "store", None)
        if store is None:
            return None
        try:
            read_barrier = getattr(state.mem, "read_barrier", None)
            if callable(read_barrier):
                read_barrier()
        except Exception:
            pass
        reader = None
        load_store = store
        try:
            reader_clone = getattr(store, "reader_clone", None)
            if callable(reader_clone):
                reader = reader_clone()
                load_store = reader
            loaded = load_store.load_full([uid])
        finally:
            if reader is not None and reader is not store:
                close = getattr(reader, "close", None)
                if callable(close):
                    try:
                        close()
                    except Exception:
                        pass
        if loaded:
            for raw_id, row in loaded.items():
                rid = _as_uuid(raw_id) or _as_uuid(getattr(row, "id", None))
                if rid is None:
                    continue
                if rid == uid:
                    loaded_row = row
                store_raw = getattr(state.mem, "store_raw", None)
                if callable(store_raw):
                    store_raw(rid, row)
            if loaded_row is None:
                loaded_row = _cached_row(state.mem, uid)
            with state.lock:
                if loaded_row is not None:
                    state.prefetched.add(uid)
        return loaded_row
    except Exception as exc:
        with state.lock:
            state.errors.append(f"{type(exc).__name__}: {exc}")
        logger.debug("CAPRe ordinary object load failed for %s: %s", uid, exc)
        return None
    finally:
        elapsed_ms = (time.perf_counter() - load_start) * 1000.0
        with state.lock:
            state.in_flight.pop(uid, None)
            if loaded_row is not None:
                state.prefetched.add(uid)
            state._sample_inflight_locked()
            state.trace_event(
                "complete",
                uid,
                request_type="prefetch_l3",
                parent_id=parent_id,
                path_id=path_id,
                depth=depth,
                kind=kind,
                elapsed_ms=elapsed_ms,
            )
            if event is not None:
                event.set()


def _cached_row(mem: Any, uid: UUID) -> Any | None:
    row = _row_from_l1(mem, uid)
    if row is not None:
        return row
    lock = getattr(mem, "_raw_lock", None)
    if lock is not None:
        lock.acquire()
    try:
        raw = getattr(mem, "__raw_mem__", None)
        if isinstance(raw, dict):
            return raw.get(uid)
    finally:
        if lock is not None:
            lock.release()
    return None


def _row_from_l1(mem: Any, uid: UUID) -> _RowView | None:
    l1 = getattr(mem, "__mem__", None)
    if not isinstance(l1, dict):
        return None
    anchor = l1.get(uid)
    if anchor is None:
        return None
    arch = getattr(anchor, "archetype", None)
    arch_type = type(arch).__name__ if arch is not None else ""
    if hasattr(anchor, "edges"):
        adjacency: list[UUID] = []
        for edge in list(getattr(anchor, "edges", []) or []):
            edge_id = _as_uuid(getattr(edge, "id", None))
            if edge_id is not None:
                adjacency.append(edge_id)
        root_id = _as_uuid(getattr(anchor, "root", None))
        return _RowView(
            id=uid,
            kind="NodeAnchor",
            arch_type=arch_type,
            root_id=root_id,
            adjacency=adjacency,
        )
    if hasattr(anchor, "source") and hasattr(anchor, "target"):
        source = getattr(anchor, "source", None)
        target = getattr(anchor, "target", None)
        return _RowView(
            id=uid,
            kind="EdgeAnchor",
            arch_type=arch_type,
            src=_as_uuid(getattr(source, "id", None)),
            dst=_as_uuid(getattr(target, "id", None)),
            undirected=bool(getattr(anchor, "is_undirected", False)),
        )
    return None


def _row_kind(row: Any) -> str:
    return str(getattr(row, "kind", "") or "")


def _type_matches(row: Any, wanted: str | None) -> bool:
    if wanted is None or wanted == "":
        return True
    actual = str(getattr(row, "arch_type", "") or "")
    if actual == wanted:
        return True
    ancestry = getattr(row, "ancestry", None) or []
    try:
        return wanted in set(str(x) for x in ancestry)
    except Exception:
        return False


def _edge_other(edge_row: Any, origin: UUID, direction: int) -> UUID | None:
    src = _as_uuid(getattr(edge_row, "src", None))
    dst = _as_uuid(getattr(edge_row, "dst", None))
    undirected = bool(getattr(edge_row, "undirected", False))
    if src == origin and (direction in (2, 3) or (direction == 1 and undirected)):
        return dst
    if dst == origin and (direction in (1, 3) or (direction == 2 and undirected)):
        return src
    return None


def _add_mem_prefetch_id(mem: Any, uid: UUID) -> None:
    try:
        ids = getattr(mem, "_prefetch_ids", None)
        if not isinstance(ids, set):
            ids = set()
            setattr(mem, "_prefetch_ids", ids)
        ids.add(uid)
    except Exception:
        pass


def _set_mem_prefetch_done(state: CapreState) -> None:
    try:
        done = getattr(state.mem, "_prefetch_done", None)
        if done is not None and hasattr(done, "set"):
            done.set()
    except Exception:
        pass

