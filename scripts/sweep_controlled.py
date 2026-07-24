#!/usr/bin/env python3
"""Controlled multi-work sweep for interopbench iop_* kernels.

Reproduces the work-size sweep (per_call vs work -> slope/intercept) that fed
the paper's slope and callback-fixed-cost claims, but under a PINNED CPU
governor (recorded in env.json). Runs the REAL kernels as subprocesses
(``jac run kernels/<k>.jac <variant> <work> <calls>``) -- the exact path the
harness uses -- parallelised across invocations.

Output schema matches the archived sweep_results.json (cells.<k>.variants.<v>
.per_work.<w>.median_per_call_ns) so slopes are directly comparable.

Usage:
    python3 scripts/sweep_controlled.py --reps 20 \
        --out results/controlled/sweep_perf.json
"""

from __future__ import annotations

import argparse
import json
import re
import statistics
import subprocess
import sys
from datetime import UTC, datetime
from multiprocessing import Pool
from pathlib import Path

BENCH = Path(__file__).resolve().parents[1] / "jac" / "examples" / "interopbench"

# kernel -> variants (matches the kernels' with-entry dispatch)
VARIANTS = {
    "iop_call": ["free", "bridge"],
    "iop_cb": ["free", "bridge"],
    "iop_symmetric": ["sv_local", "sv_to_na", "na_local", "na_to_sv"],
}

# work sizes match the archived sweep design points (25..3200) for comparability
DEFAULT_WORKS = [25, 50, 100, 200, 400, 800, 1600, 3200]
DEFAULT_CALLS = 40
METRIC_RE = re.compile(rb"m:(?:per_call_ns|invoke_ns)=(\d+)")


def run_one(task: tuple) -> tuple:
    kernel, variant, work, calls = task
    cmd = ["jac", "run", f"kernels/{kernel}.jac", variant, str(work), str(calls)]
    try:
        p = subprocess.run(cmd, cwd=str(BENCH), capture_output=True, timeout=60)
    except subprocess.TimeoutExpired:
        return (task, None)
    m = METRIC_RE.findall(p.stdout)
    per_call = int(m[-1]) if m else None
    return (task, per_call)


def governor() -> dict:
    g = "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
    t = "/sys/devices/system/cpu/intel_pstate/no_turbo"
    try:
        gov = Path(g).read_text().strip()
        tur = Path(t).read_text().strip() if Path(t).exists() else None
    except OSError:
        gov, tur = None, None
    return {"governor": gov, "turbo_disabled": tur}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kernels", default=",".join(VARIANTS))
    ap.add_argument("--works", default=",".join(map(str, DEFAULT_WORKS)))
    ap.add_argument("--calls", type=int, default=DEFAULT_CALLS)
    ap.add_argument("--reps", type=int, default=20)
    ap.add_argument("--jobs", type=int, default=8)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    kernels = [k.strip() for k in args.kernels.split(",") if k.strip()]
    works = [int(w) for w in args.works.split(",") if w.strip()]
    out = Path(args.out)

    tasks = []
    for k in kernels:
        for v in VARIANTS.get(k, []):
            for w in works:
                for _ in range(args.reps):
                    tasks.append((k, v, w, args.calls))

    print(
        f"sweep: {len(tasks)} invocations "
        f"({len(kernels)} kernels x {sum(len(VARIANTS[k]) for k in kernels)} variants "
        f"x {len(works)} works x {args.reps} reps), jobs={args.jobs}",
        file=sys.stderr,
    )

    # guardrail: refuse to run unless governor is pinned
    gov = governor()
    if gov["governor"] and gov["governor"] != "performance":
        print(
            f"ABORT: governor is '{gov['governor']}' (not 'performance'). "
            f"Pin it first: echo performance | sudo tee "
            f"/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor",
            file=sys.stderr,
        )
        sys.exit(2)

    results: dict = {}
    done = 0
    with Pool(args.jobs) as pool:
        for task, per_call in pool.imap_unordered(run_one, tasks):
            k, v, w, _ = task
            done += 1
            if done % 50 == 0:
                print(f"  ...{done}/{len(tasks)}", file=sys.stderr)
            if per_call is None:
                continue
            results.setdefault(k, {}).setdefault(v, {}).setdefault(w, []).append(
                per_call
            )

    cells = {}
    for k in kernels:
        vcell = {}
        for v in VARIANTS.get(k, []):
            pw = {}
            for w in works:
                xs = results.get(k, {}).get(v, {}).get(w, [])
                if not xs:
                    continue
                pw[str(w)] = {
                    "median_per_call_ns": statistics.median(xs),
                    "min": min(xs),
                    "max": max(xs),
                    "stdev": statistics.pstdev(xs) if len(xs) > 1 else 0.0,
                    "samples": xs,
                    "n": len(xs),
                }
            vcell[v] = {"per_work": pw}
        cells[k] = {"variants": vcell}

    doc = {
        "schema_version": 1,
        "kind": "controlled_sweep",
        "captured_utc": datetime.now(UTC).isoformat(),
        "calls": args.calls,
        "reps": args.reps,
        "works": works,
        "kernels": kernels,
        "machine_control": gov,
        "note": "CPU governor pinned to performance. See results/controlled/env.json for full provenance.",
        "cells": cells,
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(doc, indent=1))
    print(f"wrote {out}", file=sys.stderr)


if __name__ == "__main__":
    main()
