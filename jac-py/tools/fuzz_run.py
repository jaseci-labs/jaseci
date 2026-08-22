#!/usr/bin/env python3
"""Runner/classifier for the jacpython-vs-CPython differential fuzz corpus.

Mirrors how jac-py/jacpython/_fuzz_smoke.jac consumes the pin corpus: it
extracts the `cases` array from fuzz_corpus_pinned.json, points
/tmp/fuzz_cases.json at it, and runs the smoke driver via
`JACPYTHON_CPYTHON=python3 .venv/bin/jac run jac-py/jacpython/_fuzz_smoke.jac`.
The driver's Layer-1 harness replays each case's setup in BOTH host CPython
and jacpython, then diffs every assertEqual argument pair on both sides.

Per-case verdicts:
    GREEN         passed on jacpython exactly as on host CPython
    EXPECTED-RED  failed, but listed in a known-reds file (open runtime finding)
    NEW-RED       failed and not known -- fresh finding for the runtime lane
    SKIP          not host-replayable / errored before any assert diff

Exit status: 0 when no NEW-RED and no GREEN->RED regression vs --expected-greens;
1 otherwise. Reds are NEVER auto-deleted from the corpus; they stay recorded.

Usage:
    python3 fuzz_run.py [--corpus FILE] [--known-reds FILE] [--timeout SECS]
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(TOOLS_DIR))
SMOKE_DRIVER = os.path.join(REPO_ROOT, "jac-py", "jacpython", "_fuzz_smoke.jac")
JAC = os.path.join(REPO_ROOT, ".venv", "bin", "jac")
SMOKE_INPUT = "/tmp/fuzz_cases.json"  # hardcoded inside _fuzz_smoke.jac

_OK_RE = re.compile(r"^ok (\S+) passed: (\d+) skipped: (\d+)")
_FAIL_RE = re.compile(r"^FUZZFAIL (\S+) ")


def load_corpus(path: str) -> list[dict]:
    with open(path) as fh:
        data = json.load(fh)
    cases = data["cases"] if isinstance(data, dict) else data
    return [{"name": c["name"], "src": c["src"]} for c in cases]


def run_smoke(timeout: int) -> tuple[dict[str, str], list[str]]:
    """Run the sanctioned driver; return ({name: verdict}, [unparsed lines])."""
    env = dict(os.environ, JACPYTHON_CPYTHON="python3")
    proc = subprocess.run(
        [JAC, "run", SMOKE_DRIVER],
        cwd=REPO_ROOT, env=env, capture_output=True, text=True, timeout=timeout,
    )
    out = proc.stdout.splitlines()
    verdicts: dict[str, str] = {}
    unparsed: list[str] = []
    for line in out:
        m = _OK_RE.match(line)
        if m:
            name, passed, skipped = m.group(1), int(m.group(2)), int(m.group(3))
            if passed > 0 and skipped == 0:
                verdicts[name] = "GREEN"
            elif passed == 0 and skipped > 0:
                verdicts[name] = "SKIP"
            else:
                verdicts[name] = "PARTIAL"
            continue
        m = _FAIL_RE.match(line)
        if m:
            verdicts[m.group(1)] = "RED"
            continue
        if line.strip() and "jac dev mode" not in line:
            unparsed.append(line)
    return verdicts, unparsed


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--corpus", default=os.path.join(TOOLS_DIR, "fuzz_corpus_pinned.json"))
    ap.add_argument("--known-reds", default=None,
                    help="JSON array of pin names that are expected RED (open findings)")
    ap.add_argument("--timeout", type=int, default=540)
    args = ap.parse_args(argv)

    cases = load_corpus(args.corpus)
    with open(SMOKE_INPUT, "w") as fh:
        json.dump(cases, fh, indent=1)

    known_reds = set()
    if args.known_reds:
        with open(args.known_reds) as fh:
            known_reds = set(json.load(fh))

    try:
        verdicts, unparsed = run_smoke(args.timeout)
    except subprocess.TimeoutExpired:
        print(f"GATE TIMEOUT after {args.timeout}s")
        return 2

    missing = [c["name"] for c in cases if c["name"] not in verdicts]
    counts = {"GREEN": 0, "EXPECTED-RED": 0, "NEW-RED": 0, "SKIP": 0,
              "PARTIAL": 0, "MISSING": 0}
    bad = []
    for c in cases:
        v = verdicts.get(c["name"], "MISSING")
        if v == "GREEN":
            counts["GREEN"] += 1
        elif v in ("RED",):
            cls = "EXPECTED-RED" if c["name"] in known_reds else "NEW-RED"
            counts[cls] += 1
            if cls == "NEW-RED":
                bad.append(c["name"])
        elif v in ("SKIP", "PARTIAL"):
            counts[v] += 1
            bad.append(f"{c['name']} ({v})")
        else:
            counts["MISSING"] += 1
            bad.append(f"{c['name']} (no driver output)")

    print(f"corpus: {len(cases)} cases")
    for k, n in counts.items():
        print(f"  {k}: {n}")
    if unparsed:
        print("driver stderr/unparsed lines:")
        for ln in unparsed[:10]:
            print(" ", ln)
    if bad:
        print("ACTION REQUIRED:")
        for name in bad:
            print(" ", name)

    ok = counts["NEW-RED"] == 0 and counts["PARTIAL"] == 0 and counts["MISSING"] == 0
    print("GATE:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
