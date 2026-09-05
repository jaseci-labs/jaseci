from __future__ import annotations

import sys
import threading
import unittest
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from uuid import UUID

SRC = Path(__file__).resolve().parents[2]
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

from jaclang.runtime.prefetch_policy_capre_runtime import (  # noqa: E402
    CapreConfig,
    capre_metrics_snapshot,
    capre_record_demand_access,
    capre_reset_for_tests,
    capre_trace_snapshot,
    run_capre_for_test,
    start_capre_for_test,
)


def uid(num: int) -> UUID:
    return UUID(int=num)


@dataclass
class FakeRow:
    id: UUID
    kind: str
    arch_type: str
    root_id: UUID | None = None
    src: UUID | None = None
    dst: UUID | None = None
    undirected: bool = False
    adjacency: list[UUID] | None = None
    ancestry: list[str] = field(default_factory=list)


class FakeStore:
    def __init__(self, rows: dict[UUID, FakeRow]) -> None:
        self.rows_by_id = rows
        self.lock = threading.Lock()
        self.started: dict[UUID, threading.Event] = {rid: threading.Event() for rid in rows}
        self.release: dict[UUID, threading.Event] = {}
        self.issue_order: list[UUID] = []
        self.complete_order: list[UUID] = []
        self.inflight: set[UUID] = set()
        self.concurrent_pairs: set[frozenset[UUID]] = set()
        self.load_counts: Counter[UUID] = Counter()
        self.rows_called = 0

    def reader_clone(self):
        return self

    def close(self) -> None:
        pass

    def load_full(self, ids: list[UUID]) -> dict[UUID, FakeRow]:
        assert len(ids) == 1, f"CAPRe test store expects single-object loads, got {ids!r}"
        obj_id = ids[0]
        with self.lock:
            self.load_counts[obj_id] += 1
            self.issue_order.append(obj_id)
            self.started.setdefault(obj_id, threading.Event()).set()
            for other in self.inflight:
                self.concurrent_pairs.add(frozenset({obj_id, other}))
            self.inflight.add(obj_id)
        gate = self.release.get(obj_id)
        if gate is not None:
            assert gate.wait(3), f"timed out waiting to release {obj_id}"
        with self.lock:
            self.inflight.discard(obj_id)
            self.complete_order.append(obj_id)
        row = self.rows_by_id.get(obj_id)
        return {obj_id: row} if row is not None else {}

    def rows(self, *_args, **_kwargs):
        self.rows_called += 1
        raise AssertionError("CAPRe must not use database-side traversal rows()")


class FakeMem:
    def __init__(self, store: FakeStore) -> None:
        self.store = store
        self.__mem__: dict[UUID, object] = {}
        self.__raw_mem__: dict[UUID, FakeRow] = {}
        self._raw_lock = threading.Lock()
        self._deleted: set[UUID] = set()
        self._prefetch_ids: set[UUID] = set()
        self._prefetch_done = threading.Event()

    def read_barrier(self) -> None:
        pass

    def store_raw(self, rid: UUID, row: FakeRow) -> None:
        with self._raw_lock:
            if rid not in self.__mem__:
                self.__raw_mem__[rid] = row


def edge(eid: UUID, src: UUID, dst: UUID, typ: str = "E") -> FakeRow:
    return FakeRow(eid, "EdgeAnchor", typ, src=src, dst=dst)


def node(nid: UUID, typ: str, adjacency: list[UUID] | None = None) -> FakeRow:
    return FakeRow(nid, "NodeAnchor", typ, adjacency=list(adjacency or []))


def spec(chain, from_type="Root"):
    return {"from_type": from_type, "chain": chain}


class CapreRuntimeTests(unittest.TestCase):
    def tearDown(self) -> None:
        pass

    def test_dependent_chain_serializes_on_identity_discovery(self) -> None:
        root, a, b, e1, e2 = uid(1), uid(2), uid(3), uid(11), uid(12)
        store = FakeStore(
            {
                root: node(root, "Root", [e1]),
                e1: edge(e1, root, a, "Next"),
                a: node(a, "A", [e2]),
                e2: edge(e2, a, b, "Next"),
                b: node(b, "B"),
            }
        )
        store.release[a] = threading.Event()
        mem = FakeMem(store)
        mem.__raw_mem__[root] = store.rows_by_id[root]
        state = start_capre_for_test(
            mem,
            [spec([("Next", "A", 2), ("Next", "B", 2)])],
            [root],
            CapreConfig(max_concurrent=4, max_objects=20),
        )
        self.assertTrue(store.started[a].wait(3))
        self.assertNotIn(e2, store.issue_order)
        self.assertNotIn(b, store.issue_order)
        store.release[a].set()
        state.driver_thread.join(3)
        self.assertFalse(state.driver_thread.is_alive())
        self.assertLess(store.issue_order.index(a), store.issue_order.index(e2))
        self.assertLess(store.issue_order.index(e2), store.issue_order.index(b))
        capre_reset_for_tests(mem)

    def test_independent_branches_overlap(self) -> None:
        root, a, c, e1, e2 = uid(10), uid(20), uid(30), uid(101), uid(102)
        store = FakeStore(
            {
                root: node(root, "Root", [e1, e2]),
                e1: edge(e1, root, a, "ToA"),
                e2: edge(e2, root, c, "ToC"),
                a: node(a, "A"),
                c: node(c, "C"),
            }
        )
        store.release[a] = threading.Event()
        store.release[c] = threading.Event()
        mem = FakeMem(store)
        mem.__raw_mem__[root] = store.rows_by_id[root]
        state = start_capre_for_test(
            mem,
            [spec([("ToA", "A", 2)]), spec([("ToC", "C", 2)])],
            [root],
            CapreConfig(max_concurrent=6, max_objects=20),
        )
        self.assertTrue(store.started[a].wait(3))
        self.assertTrue(store.started[c].wait(3))
        self.assertIn(frozenset({a, c}), store.concurrent_pairs)
        store.release[a].set()
        store.release[c].set()
        state.driver_thread.join(3)
        self.assertFalse(state.driver_thread.is_alive())
        capre_reset_for_tests(mem)

    def test_collection_fanout_overlaps_each_elements_dependent_tail(self) -> None:
        root = uid(100)
        t1, t2 = uid(101), uid(102)
        a1, a2 = uid(201), uid(202)
        e1, e2, e3, e4 = uid(301), uid(302), uid(303), uid(304)
        store = FakeStore(
            {
                root: node(root, "Root", [e1, e2]),
                e1: edge(e1, root, t1, "Txn"),
                e2: edge(e2, root, t2, "Txn"),
                t1: node(t1, "Transaction", [e3]),
                t2: node(t2, "Transaction", [e4]),
                e3: edge(e3, t1, a1, "Account"),
                e4: edge(e4, t2, a2, "Account"),
                a1: node(a1, "Account"),
                a2: node(a2, "Account"),
            }
        )
        store.release[a1] = threading.Event()
        store.release[a2] = threading.Event()
        mem = FakeMem(store)
        mem.__raw_mem__[root] = store.rows_by_id[root]
        state = start_capre_for_test(
            mem,
            [spec([("Txn", "Transaction", 2), ("Account", "Account", 2)])],
            [root],
            CapreConfig(max_concurrent=8, max_objects=30),
        )
        self.assertTrue(store.started[a1].wait(3))
        self.assertTrue(store.started[a2].wait(3))
        self.assertIn(frozenset({a1, a2}), store.concurrent_pairs)
        store.release[a1].set()
        store.release[a2].set()
        state.driver_thread.join(3)
        self.assertFalse(state.driver_thread.is_alive())
        capre_reset_for_tests(mem)

    def test_duplicate_paths_suppress_duplicate_object_loads(self) -> None:
        root, a, e1 = uid(400), uid(401), uid(402)
        store = FakeStore(
            {
                root: node(root, "Root", [e1]),
                e1: edge(e1, root, a, "Next"),
                a: node(a, "A"),
            }
        )
        store.release[a] = threading.Event()
        mem = FakeMem(store)
        mem.__raw_mem__[root] = store.rows_by_id[root]
        state = start_capre_for_test(
            mem,
            [spec([("Next", "A", 2)]), spec([("Next", "A", 2)])],
            [root],
            CapreConfig(max_concurrent=4, max_objects=20),
        )
        self.assertTrue(store.started[a].wait(3))
        store.release[a].set()
        state.driver_thread.join(3)
        self.assertFalse(state.driver_thread.is_alive())
        metrics = capre_metrics_snapshot(mem)
        self.assertEqual(store.load_counts[a], 1)
        self.assertGreaterEqual(metrics["duplicate_prefetches_suppressed"], 1)
        capre_reset_for_tests(mem)

    def test_cached_object_skips_prefetch_l3(self) -> None:
        root, a, e1 = uid(500), uid(501), uid(502)
        store = FakeStore(
            {
                root: node(root, "Root", [e1]),
                e1: edge(e1, root, a, "Next"),
                a: node(a, "A"),
            }
        )
        mem = FakeMem(store)
        mem.__raw_mem__[root] = store.rows_by_id[root]
        mem.__raw_mem__[a] = store.rows_by_id[a]
        run_capre_for_test(
            mem,
            [spec([("Next", "A", 2)])],
            [root],
            CapreConfig(max_concurrent=2, max_objects=20),
        )
        self.assertEqual(store.load_counts[a], 0)
        capre_reset_for_tests(mem)

    def test_demand_race_records_late_then_not_useful_until_completed_demand(self) -> None:
        root, a, e1 = uid(600), uid(601), uid(602)
        store = FakeStore(
            {
                root: node(root, "Root", [e1]),
                e1: edge(e1, root, a, "Next"),
                a: node(a, "A"),
            }
        )
        store.release[a] = threading.Event()
        mem = FakeMem(store)
        mem.__raw_mem__[root] = store.rows_by_id[root]
        state = start_capre_for_test(
            mem,
            [spec([("Next", "A", 2)])],
            [root],
            CapreConfig(max_concurrent=4, max_objects=20),
        )
        self.assertTrue(store.started[a].wait(3))
        capre_record_demand_access(mem, a, "L3")
        self.assertEqual(capre_metrics_snapshot(mem)["late_prefetches"], 1)
        store.release[a].set()
        state.driver_thread.join(3)
        self.assertFalse(state.driver_thread.is_alive())
        self.assertEqual(capre_metrics_snapshot(mem)["useful_prefetches"], 0)
        capre_reset_for_tests(mem)

    def test_branch_conservatism_prefetches_alternative_static_paths(self) -> None:
        root, a, c, e1, e2 = uid(700), uid(701), uid(702), uid(703), uid(704)
        store = FakeStore(
            {
                root: node(root, "Root", [e1, e2]),
                e1: edge(e1, root, a, "IfTrue"),
                e2: edge(e2, root, c, "IfFalse"),
                a: node(a, "A"),
                c: node(c, "C"),
            }
        )
        mem = FakeMem(store)
        mem.__raw_mem__[root] = store.rows_by_id[root]
        run_capre_for_test(
            mem,
            [spec([("IfTrue", "A", 2)]), spec([("IfFalse", "C", 2)])],
            [root],
            CapreConfig(max_concurrent=4, max_objects=20),
        )
        self.assertEqual(store.load_counts[a], 1)
        self.assertEqual(store.load_counts[c], 1)
        capre_reset_for_tests(mem)

    def test_run_isolation_uses_session_local_state(self) -> None:
        root1, a1, e1 = uid(800), uid(801), uid(802)
        root2, a2, e2 = uid(900), uid(901), uid(902)
        store1 = FakeStore({root1: node(root1, "Root", [e1]), e1: edge(e1, root1, a1, "Next"), a1: node(a1, "A")})
        store2 = FakeStore({root2: node(root2, "Root", [e2]), e2: edge(e2, root2, a2, "Next"), a2: node(a2, "A")})
        mem1 = FakeMem(store1)
        mem2 = FakeMem(store2)
        mem1.__raw_mem__[root1] = store1.rows_by_id[root1]
        mem2.__raw_mem__[root2] = store2.rows_by_id[root2]
        run_capre_for_test(mem1, [spec([("Next", "A", 2)])], [root1], CapreConfig(max_concurrent=2, max_objects=20))
        run_capre_for_test(mem2, [spec([("Next", "A", 2)])], [root2], CapreConfig(max_concurrent=2, max_objects=20))
        self.assertEqual(store1.load_counts[a2], 0)
        self.assertEqual(store2.load_counts[a1], 0)
        self.assertNotEqual(capre_metrics_snapshot(mem1)["run_id"], capre_metrics_snapshot(mem2)["run_id"])
        capre_reset_for_tests(mem1)
        capre_reset_for_tests(mem2)

    def test_no_database_side_traversal_rows_call(self) -> None:
        root, a, e1 = uid(1000), uid(1001), uid(1002)
        store = FakeStore({root: node(root, "Root", [e1]), e1: edge(e1, root, a, "Next"), a: node(a, "A")})
        mem = FakeMem(store)
        mem.__raw_mem__[root] = store.rows_by_id[root]
        run_capre_for_test(mem, [spec([("Next", "A", 2)])], [root], CapreConfig(max_concurrent=2, max_objects=20))
        self.assertEqual(store.rows_called, 0)
        trace = capre_trace_snapshot(mem)
        self.assertFalse(any("TTG" in row.get("note", "") for row in trace))
        capre_reset_for_tests(mem)


if __name__ == "__main__":
    unittest.main()
