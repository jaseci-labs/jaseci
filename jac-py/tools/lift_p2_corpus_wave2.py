#!/usr/bin/env python3
"""Lift the P2 wave-2 corpus with ``jac tool c2jac``.

Reads ``jac-py/tools/p2_corpus_wave2/manifest.json``. Run from repo root:

    .venv/bin/python jac-py/tools/lift_p2_corpus_wave2.py
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import shutil
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_MANIFEST = _HERE / "p2_corpus_wave2" / "manifest.json"
_JAC = _REPO / ".venv" / "bin" / "jac"


def _run(cmd: list[str]) -> None:
    proc = subprocess.run(cmd, cwd=_REPO, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"command failed ({proc.returncode}): {' '.join(cmd)}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=_MANIFEST,
        help="corpus manifest JSON (default: jac-py/tools/p2_corpus_wave2/manifest.json)",
    )
    args = parser.parse_args(argv)
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    out_dir = (_REPO / manifest["lift_output"]).resolve()
    if not _JAC.is_file():
        print(f"lift_p2_corpus_wave2: missing {_JAC}", file=sys.stderr)
        return 1
    out_dir.mkdir(parents=True, exist_ok=True)
    staging = (_HERE / "p2_corpus_wave2" / "_staging").resolve()
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)

    for row in manifest["files"]:
        src = (_REPO / row["source"]).resolve()
        if not src.is_file():
            print(f"lift_p2_corpus_wave2: missing source {src}", file=sys.stderr)
            return 1
        stem = row["stem"]
        (staging / f"{stem}.c").write_bytes(src.read_bytes())

    cmd = [
        str(_JAC),
        "tool",
        "c2jac",
        "--project",
        str(staging.relative_to(_REPO)),
        "-o",
        str(out_dir.relative_to(_REPO)),
    ]
    _run(cmd)

    report = out_dir / "project.c2jac.report.json"
    _post_lift_wave2(out_dir, report)
    print(f"lifted corpus -> {out_dir.relative_to(_REPO)}")
    print(f"aggregate report -> {report.relative_to(_REPO)}")
    return 0


def _post_lift_wave2(out_dir: Path, report: Path) -> None:
    """Apply wave-2 burn-down after fresh c2jac lift (hand sync + T8 rule pass)."""
    if str(_HERE) not in sys.path:
        sys.path.insert(0, str(_HERE))
    from sync_staged_to_lifted import sync_hand_staged
    from t8_driver import RulePatcher, refresh_aggregate_report, run_loop

    code = sync_hand_staged(wave="wave2", refresh_reports=False)
    if code != 0:
        raise RuntimeError("post-lift sync_hand_staged(wave2) failed")

    if not report.is_file():
        return

    run_loop(
        report,
        RulePatcher(),
        max_iterations=20,
        run_tests=False,
    )
    refresh_aggregate_report(report)

    staged_pystrnicmp = _REPO / "jac-py/Modules/pystrnicmp.jac"
    lifted_pystrnicmp = out_dir / "pystrnicmp.jac"
    if lifted_pystrnicmp.is_file():
        shutil.copy2(lifted_pystrnicmp, staged_pystrnicmp)


if __name__ == "__main__":
    raise SystemExit(main())
