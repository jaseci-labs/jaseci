"""Tests for how `jac test` orders and slices the work it discovered.

The runner banks what each file cost and plans the next run from it. Two
properties matter and neither is visible from a suite's pass/fail line, so
they are pinned here directly against `plan_units`:

  - **A cold record plans exactly as before.** A file with no recorded cost
    stays whole and sorts ahead of the measured ones, so a fresh checkout
    behaves the way it did when the dispatch unit was always a whole file.
  - **Striding is opt-in.** A file is split only where `[dev] test_shard` or
    `JAC_TEST_SHARD` names it. Nothing in a test file declares that its cases
    are independent, and a case that leans on one before it changes its
    verdict once the stride moves it, so the runner may not split on its own.

`plan_units` is pure, so these need no forked workers and no real suite.
"""

import os;
import tempfile;
import from pathlib { Path }
import from jaclang.runtimelib.test_runner {
    TestPlan,
    load_durations,
    plan_units,
    save_durations,
    _shard_allowed
}

def _plan(files: list[str]) -> TestPlan {
    return TestPlan(files=files, explicit=set());
}

test "a file with no recorded cost stays whole and is planned first" {
    plan = _plan(["/x/slow.jac", "/x/unknown.jac"]);
    units = plan_units(plan, 8, {"/x/slow.jac": 400.0}, {"/x/slow.jac": 50}, ["*"]);
    assert units[0].path == "/x/unknown.jac";
    assert units[0].nshards == 1;
    assert [
        u.path
        for u in units
        if u.path == "/x/unknown.jac"
    ]
        == ["/x/unknown.jac"];
}

test "measured files are planned longest-first" {
    plan = _plan(["/x/a.jac", "/x/b.jac", "/x/c.jac"]);
    costs = {"/x/a.jac": 10.0, "/x/b.jac": 90.0, "/x/c.jac": 50.0};
    units = plan_units(plan, 4, costs, {}, []);
    assert [u.path for u in units] == ["/x/b.jac", "/x/c.jac", "/x/a.jac"];
}

test "an unnamed file is never strided, however expensive it is" {
    plan = _plan(["/x/huge.jac"]);
    units = plan_units(plan, 8, {"/x/huge.jac": 900.0}, {"/x/huge.jac": 90}, []);
    assert len(units) == 1;
    assert units[0].nshards == 1;
}

test "a named file above the slice target is strided" {
    plan = _plan(["/x/huge.jac"]);
    units = plan_units(
        plan, 8, {"/x/huge.jac": 900.0}, {"/x/huge.jac": 90}, ["*huge*"]
    );
    assert len(units) > 1;
    assert {u.nshards for u in units} == {len(units)};
    assert sorted(u.shard for u in units) == list(range(len(units)));
}

test "a stride is never finer than the tests the file was seen to hold" {
    plan = _plan(["/x/few.jac"]);
    units = plan_units(plan, 12, {"/x/few.jac": 600.0}, {"/x/few.jac": 3}, ["*few*"]);
    assert len(units) <= 3;
}

test "serial runs are never strided" {
    plan = _plan(["/x/huge.jac"]);
    units = plan_units(plan, 1, {"/x/huge.jac": 900.0}, {"/x/huge.jac": 90}, ["*"]);
    assert len(units) == 1;
}

test "shard globs match on path segments and on full globs" {
    assert _shard_allowed("/a/b/test_x.jac", ["test_x.jac"]);
    assert _shard_allowed("/a/b/test_x.jac", ["*/b/*"]);
    assert not _shard_allowed("/a/b/test_x.jac", ["test_y.jac"]);
    assert not _shard_allowed("/a/b/test_x.jac", []);
}

test "a recorded cost survives a save and load round trip" {
    with tempfile.TemporaryDirectory() as tmp {
        probe = str(Path(tmp) / "suite.jac");
        Path(probe).write_text("", encoding="utf-8");
        cwd = os.getcwd();
        os.chdir(tmp);
        try {
            save_durations({probe: 12.5}, {probe: 7});
            (seconds, counts) = load_durations();
        } finally {
            os.chdir(cwd);
        }
    }
    assert seconds.get(probe) == 12.5;
    assert counts.get(probe) == 7;
}
