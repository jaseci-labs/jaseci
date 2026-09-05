#!/usr/bin/env python3
"""Small CAPRe sanity trace for the TTG/CAPRe execution distinction."""

from __future__ import annotations

import csv
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from uuid import UUID

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "jac"
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))
TESTS = SRC / "tests" / "runtimelib"
if str(TESTS) not in sys.path:
    sys.path.insert(0, str(TESTS))

from test_capre_policy_runtime import FakeMem, FakeStore, edge, node, spec, uid  # noqa: E402
from jaclang.runtime.prefetch_policy_capre_runtime import (  # noqa: E402
    CapreConfig,
    capre_metrics_snapshot,
    capre_trace_snapshot,
    start_capre_for_test,
)


def build_graph():
    root = uid(1)
    a, b, c = uid(2), uid(3), uid(4)
    t1, t2, acct1, acct2 = uid(5), uid(6), uid(7), uid(8)
    e_ra, e_ab, e_rc, e_rt1, e_rt2, e_t1a, e_t2a = (uid(i) for i in range(101, 108))
    rows = {
        root: node(root, "Root", [e_ra, e_rc, e_rt1, e_rt2]),
        e_ra: edge(e_ra, root, a, "Next"),
        a: node(a, "A", [e_ab]),
        e_ab: edge(e_ab, a, b, "Next"),
        b: node(b, "B"),
        e_rc: edge(e_rc, root, c, "Other"),
        c: node(c, "C"),
        e_rt1: edge(e_rt1, root, t1, "Txn"),
        e_rt2: edge(e_rt2, root, t2, "Txn"),
        t1: node(t1, "Transaction", [e_t1a]),
        t2: node(t2, "Transaction", [e_t2a]),
        e_t1a: edge(e_t1a, t1, acct1, "Account"),
        e_t2a: edge(e_t2a, t2, acct2, "Account"),
        acct1: node(acct1, "Account"),
        acct2: node(acct2, "Account"),
    }
    specs = [
        spec([("Next", "A", 2), ("Next", "B", 2)]),
        spec([("Other", "C", 2)]),
        spec([("Txn", "Transaction", 2), ("Account", "Account", 2)]),
    ]
    return root, rows, specs


def measured_none(root: UUID, rows: dict[UUID, object]) -> dict[str, float | int | str]:
    store = FakeStore(rows)
    mem = FakeMem(store)
    mem.__raw_mem__[root] = rows[root]
    start = time.perf_counter()
    for obj_id in [uid(101), uid(2), uid(102), uid(3), uid(103), uid(4), uid(104), uid(5), uid(106), uid(7), uid(105), uid(6), uid(107), uid(8)]:
        store.load_full([obj_id])
    return {"policy": "none", "elapsed_ms": (time.perf_counter() - start) * 1000.0, "db_requests": len(store.issue_order)}


def measured_capre(root: UUID, rows: dict[UUID, object], specs: list[dict]) -> tuple[dict[str, object], list[dict[str, object]]]:
    store = FakeStore(rows)
    mem = FakeMem(store)
    mem.__raw_mem__[root] = rows[root]
    start = time.perf_counter()
    state = start_capre_for_test(mem, specs, [root], CapreConfig(max_concurrent=6, max_objects=50))
    state.driver_thread.join(5)
    elapsed = (time.perf_counter() - start) * 1000.0
    metrics = capre_metrics_snapshot(mem)
    metrics["elapsed_ms"] = elapsed
    return metrics, capre_trace_snapshot(mem)


def measured_ttg_like(root: UUID, rows: dict[UUID, object]) -> dict[str, float | int | str]:
    store = FakeStore(rows)
    start = time.perf_counter()
    # One synthetic server-side traversal RTT, then ordinary materialization of known IDs.
    time.sleep(0.001)
    for obj_id in [uid(2), uid(3), uid(4), uid(5), uid(6), uid(7), uid(8)]:
        store.load_full([obj_id])
    return {"policy": "ttg_like", "elapsed_ms": (time.perf_counter() - start) * 1000.0, "db_requests": len(store.issue_order) + 1}


def main() -> None:
    root, rows, specs = build_graph()
    none = measured_none(root, rows)
    capre, trace = measured_capre(root, rows, specs)
    ttg = measured_ttg_like(root, rows)
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/tmp/capre_micro_trace.csv")
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="") as fh:
        fieldnames = sorted({k for row in trace for k in row.keys()})
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(trace)
    print("policy,elapsed_ms,db_requests,prefetch_l3,peak_inflight")
    print(f"none,{none['elapsed_ms']:.3f},{none['db_requests']},,0")
    print(f"capre,{capre['elapsed_ms']:.3f},{capre['app_db_round_trips']},{capre['prefetch_l3_requests']},{capre['peak_inflight']}")
    print(f"ttg_like,{ttg['elapsed_ms']:.3f},{ttg['db_requests']},,0")
    print(f"trace={out}")


if __name__ == "__main__":
    main()
