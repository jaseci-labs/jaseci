"""The pool dispatches within the machine's memory, not just within its slots.

`default_jobs` sizes the pool by free memory at start, but a worker's footprint
grows with what it serves (one native compile can add gigabytes in a single
item), so N slots that fit at spawn time can exceed the machine mid-run. On a
CI runner that kills the agent itself: the job ends with no step log and no
test output at all, and the per-worker RSS ceiling never gets a chance to fire
because it is only consulted between items.

Dispatch is therefore gated on available memory. Before handing out an item
the pool checks that the reserve (the largest single-item growth seen so far,
floored at MEM_RESERVE_FLOOR_MB) is free for it and for every item already in
flight, since each of those may still grow by that much before it reports;
it parks the worker otherwise, and retires a parked worker that already holds
more than its share of the start budget so its memory returns while it
waits. One item is always in flight, so a scarce machine slows the pool down
instead of stopping it.

`JAC_WORKPOOL_MEM_AVAIL_MB` overrides the /proc/meminfo reading and
`JAC_WORKPOOL_RESERVE_MB` the reserve, which is how these tests script a
starved machine without allocating anything.
"""

import os;
import time;
import from jaclang.cli.workpool { WorkPool, available_memory_mb, pool_available }

glob _done: list[int] = [],
     _inflight: list[int] = [0],
     _peak: list[int] = [0],
     _peak_squeezed: list[int] = [0],
     _peak_recovered: list[int] = [0],
     _squeeze_after: list[int] = [0],
     _recover_after: list[int] = [0],
     _squeezed: list[bool] = [False],
     _recovered: list[bool] = [False],
     _spawned: list[int] = [0],
     _vacant: list[int] = [0];

def _job(request: dict[(str, any)]) -> any {
    time.sleep(0.02);
    return {"idx": int(request["idx"])};
}

def _on_dispatch(idx: int, path: str) {
    _inflight[0] += 1;
    if _inflight[0] > _peak[0] {
        _peak[0] = _inflight[0];
    }
    if _recovered[0] {
        if _inflight[0] > _peak_recovered[0] {
            _peak_recovered[0] = _inflight[0];
        }
    } elif _squeezed[0] and _inflight[0] > _peak_squeezed[0] {
        _peak_squeezed[0] = _inflight[0];
    }
}

def _on_record(idx: int, record: dict[(str, any)]) {
    _inflight[0] -= 1;
    if isinstance(record.get("result"), dict) {
        _done.append(idx);
    }
    if (
        _squeeze_after[0] > 0 and not _squeezed[0] and len(_done) >= _squeeze_after[0]
    ) {
        # The machine runs out of memory mid-run: every dispatch from here on
        # sees 1 MB available.
        os.environ["JAC_WORKPOOL_MEM_AVAIL_MB"] = "1";
        _squeezed[0] = True;
    }
    if (
        _recover_after[0] > 0
        and _squeezed[0]
        and not _recovered[0]
        and len(_done) >= _recover_after[0]
    ) {
        # Memory comes back: the vacated slots should refill.
        os.environ["JAC_WORKPOOL_MEM_AVAIL_MB"] = "50";
        _recovered[0] = True;
    }
}

def _run(items: int, jobs: int, env: dict[str, str]) -> int {
    _done.clear();
    _inflight[0] = 0;
    _peak[0] = 0;
    _peak_squeezed[0] = 0;
    _peak_recovered[0] = 0;
    _squeezed[0] = False;
    _recovered[0] = False;
    saved = {k: os.environ.get(k) for k in env};
    try {
        for (k, v) in env.items() {
            os.environ[k] = v;
        }
        pool = WorkPool(
            items=[f"item-{i}" for i in range(items)],
            job=_job,
            on_record=_on_record,
            on_dispatch=_on_dispatch,
            jobs=jobs
        );
        pool.run();
        _spawned[0] = pool.spawned;
        _vacant[0] = len(pool.vacant);
    } finally {
        for (k, v) in saved.items() {
            if v is None {
                os.environ.pop(k, None);
            } else {
                os.environ[k] = v;
            }
        }
    }
    return _peak[0];
}

test "with memory to spare the pool fills every slot" {
    if not pool_available() {
        return;
    }
    peak = _run(
        24, 4, {"JAC_WORKPOOL_MEM_AVAIL_MB": "1000000", "JAC_WORKPOOL_RESERVE_MB": "1"}
    );
    assert sorted(_done) == list(range(24));
    assert peak == 4 , f"only {peak} items in flight with 4 slots and memory to spare";
}

test "a starved machine still completes every item, one at a time" {
    if not pool_available() {
        return;
    }
    peak = _run(
        24, 4, {"JAC_WORKPOOL_MEM_AVAIL_MB": "1", "JAC_WORKPOOL_RESERVE_MB": "4096"}
    );
    assert sorted(_done) == list(range(24)) , (
        f"items lost under memory pressure: {len(_done)}/24"
    );
    assert peak == 1 , f"{peak} items were in flight with no memory to spare";
}

test "workers parked mid-run over their share are retired, and refilled when memory returns" {
    if not pool_available() {
        return;
    }
    # 50 MB available against a 10 MB reserve lets all four slots start (the
    # fourth needs 40 MB free), and the 30 MB start budget gives each slot a
    # 7 MB share, under any worker that has served an item (a forked child
    # reports only what it touched since the fork, about 10 MB here). After
    # four items the machine is squeezed to 1 MB: from then on one item is in
    # flight and every parked worker is over its share, so it is retired and
    # its slot left vacant. After twelve items memory comes back and the
    # vacant slots refill.
    _squeeze_after[0] = 4;
    _recover_after[0] = 12;
    try {
        peak = _run(
            24, 4, {"JAC_WORKPOOL_MEM_AVAIL_MB": "50", "JAC_WORKPOOL_RESERVE_MB": "10"}
        );
    } finally {
        _squeeze_after[0] = 0;
        _recover_after[0] = 0;
    }
    assert sorted(_done) == list(range(24)) , (
        f"items lost across retire-and-refill: {len(_done)}/24"
    );
    assert peak == 4 , f"only {peak} items in flight before the squeeze";
    assert _peak_squeezed[0] == 1 , (
        f"{_peak_squeezed[0]} items in flight after the machine was squeezed"
    );
    assert _spawned[0] > 4 , (
        f"only {_spawned[0]} workers were ever spawned, so no vacated slot was "
        "refilled after memory returned"
    );
    assert _peak_recovered[0] >= 2 , (
        f"only {_peak_recovered[0]} items in flight after memory returned"
    );
}

test "workers parked on a machine that never recovers stay retired" {
    if not pool_available() {
        return;
    }
    _squeeze_after[0] = 4;
    try {
        _run(
            24, 4, {"JAC_WORKPOOL_MEM_AVAIL_MB": "50", "JAC_WORKPOOL_RESERVE_MB": "10"}
        );
    } finally {
        _squeeze_after[0] = 0;
    }
    assert sorted(_done) == list(range(24));
    assert _spawned[0] == 4 , (
        f"{_spawned[0]} workers were spawned on a machine with no memory to give them"
    );
    assert _vacant[0] == 3 , (
        f"{_vacant[0]} slots were vacated; the three parked workers over their "
        "share should all have been retired"
    );
}

test "available memory honors the override and otherwise reads the host" {
    saved = os.environ.get("JAC_WORKPOOL_MEM_AVAIL_MB");
    try {
        os.environ["JAC_WORKPOOL_MEM_AVAIL_MB"] = "1234";
        assert available_memory_mb() == 1234;
        os.environ.pop("JAC_WORKPOOL_MEM_AVAIL_MB", None);
        host = available_memory_mb();
        assert host == -1 or host > 0 , f"unexpected host reading {host}";
    } finally {
        if saved is None {
            os.environ.pop("JAC_WORKPOOL_MEM_AVAIL_MB", None);
        } else {
            os.environ["JAC_WORKPOOL_MEM_AVAIL_MB"] = saved;
        }
    }
}

test "an item in flight keeps its reserve, so a second one needs twice the room" {
    if not pool_available() {
        return;
    }
    # 15 MB free against a 10 MB reserve: the first item fits, the second would
    # need 20 MB, so the pool runs one at a time even though four slots exist.
    peak = _run(
        12, 4, {"JAC_WORKPOOL_MEM_AVAIL_MB": "15", "JAC_WORKPOOL_RESERVE_MB": "10"}
    );
    assert sorted(_done) == list(range(12));
    assert peak == 1 , f"{peak} items in flight with room for only one reserve";
}
