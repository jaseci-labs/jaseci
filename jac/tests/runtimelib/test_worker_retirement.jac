"""A pool worker retires on how much it is holding, not just how many files.

`JAC_TEST_RECYCLE` bounds files served per worker, which bounds a slow drip
but not a single heavy compile: one native fixture can take a worker from
under 500 MB to several GB, and the count-based cap then keeps that worker
alive for the two dozen files it has left to serve. On a runner with no
headroom the agent itself is killed, which produces no step log and no test
output at all.

Retirement therefore takes whichever bound trips first. `JAC_TEST_RECYCLE_MB`
carries the memory bound; either can be disabled with 0.

The memory bound is a share of the same budget `default_jobs` divides to pick
the worker count, so `jobs * cap` cannot exceed it whatever the box. A fixed
default cannot hold that: shipped at 8192 MB against a per-worker sizing
assumption of 2 GiB, the bound sat four times above the budget and never once
fired in CI, leaving the file count as the only real limit.

Sizing and shedding are the other half. A `passes-native` runner with 14.6 GB
free admitted four workers that together reached 12.2 GB and exhausted the box
in 218 seconds, so `_WORKER_MEM_BYTES` now carries the measured per-worker cost
rather than half of it. Where a lane is heavier still, the pool sheds a worker
on real memory pressure, and `_shed_threshold` keeps that ahead of the point
where the run has to stop.
"""

import from jaclang.testing.test_runner {
    _limit_from_text,
    _mem_budget_bytes,
    _shed_threshold,
    _rss_cap_for,
    _should_retire,
    _worker_rss_mb
}

test "a worker under both bounds keeps serving" {
    assert not _should_retire(served=3, recycle=25, rss_mb=400, rss_cap=2048);
}

test "the file count still retires a worker" {
    assert _should_retire(served=25, recycle=25, rss_mb=400, rss_cap=2048);
    assert _should_retire(served=26, recycle=25, rss_mb=400, rss_cap=2048);
}

test "a single heavy file retires a worker the count would have kept" {
    assert _should_retire(served=1, recycle=25, rss_mb=4608, rss_cap=2048) , (
        "a worker holding 4.5 GB after one file kept serving because the "
        "count-based cap had 24 files left to go"
    );
}

test "either bound can be disabled with 0" {
    assert not _should_retire(served=99, recycle=0, rss_mb=400, rss_cap=2048);
    assert not _should_retire(served=3, recycle=25, rss_mb=99999, rss_cap=0);
    assert not _should_retire(served=99, recycle=0, rss_mb=99999, rss_cap=0);
}

test "the worker can read its own footprint" {
    mb = _worker_rss_mb();
    assert mb > 0 , "a live worker reports no resident memory";
    assert mb < 1024 * 1024 , f"implausible footprint {mb} MB: check the unit";
}

test "the cap is the budget split across the workers sharing the box" {
    gib = 1024 * 1024 * 1024;
    assert _rss_cap_for(budget=9 * gib, jobs=4) == 2304;
    assert _rss_cap_for(budget=9 * gib, jobs=2) == 4608;
}

test "workers cannot together outgrow the budget that sized the pool" {
    gib = 1024 * 1024 * 1024;
    for (budget, jobs) in [(9 * gib, 4), (4 * gib, 2), (60 * gib, 12)] {
        cap = _rss_cap_for(budget=budget, jobs=jobs);
        assert (cap * jobs * 1024 * 1024) <= budget , (
            f"{jobs} workers capped at {cap} MB each exceed the "
            f"{budget // gib} GiB budget the pool sized itself against"
        );
    }
}

test "an unreadable budget falls back to the per-worker sizing assumption" {
    assert _rss_cap_for(budget=0, jobs=4) == 3072;
}

test "this box budgets a cap its own worker count can live inside" {
    assert _mem_budget_bytes() > 0 , "no memory budget could be read";
    assert _rss_cap_for(budget=_mem_budget_bytes(), jobs=1) > 0;
}

test "the footprint is what the worker holds, not its high-water mark" {
    import os;
    if not os.path.exists("/proc/self/status") {
        return;
    }
    before = _worker_rss_mb();
    blob = bytearray(256 * 1024 * 1024);
    held = _worker_rss_mb();
    del blob;
    freed = _worker_rss_mb();
    assert (held - before) >= 200 , "a 256 MB allocation did not move the footprint";
    assert (held - freed) >= 200 , (
        "the footprint stayed at its high-water mark after the memory went "
        "back, so a worker that spiked once would read as oversized forever"
    );
}

test "a cgroup ceiling is read, and an absent one reads as no ceiling" {
    assert _limit_from_text("6442450944\n") == 6442450944;
    assert _limit_from_text("max\n") == 0;
    assert _limit_from_text("9223372036854771712\n") == 0 , (
        "cgroup v1 spells unlimited as a near-maxint sentinel, which would "
        "otherwise be taken for a real ceiling"
    );
}

test "a pool sheds a worker before it reaches the stop threshold" {
    gib = 1024 * 1024 * 1024;
    assert _shed_threshold(mem_start=15 * gib) > (1536 * 1024 * 1024) , (
        "shedding must get a chance on a large box before the run is stopped"
    );
    assert _shed_threshold(mem_start=2 * gib) == (3072 * 1024 * 1024) , (
        "on a small box the proportional threshold falls under the stop "
        "threshold, so it floors at twice it and the pool still sheds first"
    );
}
