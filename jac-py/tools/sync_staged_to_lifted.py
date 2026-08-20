#!/usr/bin/env python3
"""Copy hand-staged oracle modules into the P2 lifted corpus tree.

Hand-staged modules (see ``p2_staged_manifest.json``) intentionally diverge from
fresh c2jac lift output. After tier-B burn-down on the staged oracle, copy the
staged file into ``_lifted/p2_corpus_wave1/`` so density metrics and T8 queues
reflect the oracle truth.

Usage:
    python jac-py/tools/sync_staged_to_lifted.py
    python jac-py/tools/sync_staged_to_lifted.py --dry-run
    python jac-py/tools/sync_staged_to_lifted.py --stem getbuildinfo
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_MANIFEST = _HERE / "p2_staged_manifest.json"


def _load_manifest() -> dict:
    return json.loads(_MANIFEST.read_text(encoding="utf-8"))


def _hand_modules(manifest: dict, stem_filter: str | None) -> list[dict]:
    rows = [m for m in manifest["modules"] if m.get("staging") == "hand"]
    if stem_filter:
        rows = [m for m in rows if m["stem"] == stem_filter]
    return rows


def sync_hand_staged(*, dry_run: bool = False, stem: str | None = None) -> int:
    manifest = _load_manifest()
    staged_dir = _REPO / manifest["staged_dir"]
    lifted_dir = _REPO / manifest["lifted_dir"]
    rows = _hand_modules(manifest, stem)
    if stem and not rows:
        print(f"error: {stem!r} is not a hand-staged module", file=sys.stderr)
        return 1

    copied = 0
    for row in rows:
        name = row["stem"]
        src = staged_dir / f"{name}.jac"
        dst = lifted_dir / f"{name}.jac"
        if not src.is_file():
            print(f"error: missing staged oracle {src}", file=sys.stderr)
            return 1
        if dry_run:
            print(f"would copy {src.relative_to(_REPO)} -> {dst.relative_to(_REPO)}")
        else:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            print(f"copied {src.relative_to(_REPO)} -> {dst.relative_to(_REPO)}")
        copied += 1

    if copied == 0:
        print("no hand-staged modules to sync", file=sys.stderr)
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print planned copies without writing",
    )
    parser.add_argument(
        "--stem",
        metavar="NAME",
        help="sync one hand-staged module only",
    )
    args = parser.parse_args()
    return sync_hand_staged(dry_run=args.dry_run, stem=args.stem)


if __name__ == "__main__":
    raise SystemExit(main())
