#!/usr/bin/env python3
"""Copy hand-staged oracle modules into the P2 lifted corpus tree.

Hand-staged modules (see ``p2_staged_manifest*.json``) intentionally diverge from
fresh c2jac lift output. After tier-B burn-down on the staged oracle, copy the
staged file into ``_lifted/p2_corpus_wave*/`` so density metrics and T8 queues
reflect the oracle truth. The staged per-file sidecar is synced alongside so
the lifted Tier-B counts stay auditable against the staged oracle instead of
being silently reset to a clean slate.

Usage:
    python jac-py/tools/sync_staged_to_lifted.py
    python jac-py/tools/sync_staged_to_lifted.py --wave wave2
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


def _discover_manifests() -> dict[str, Path]:
    """Map wave name -> staged manifest path (wave1 uses the unsuffixed file)."""
    manifests: dict[str, Path] = {"wave1": _HERE / "p2_staged_manifest.json"}
    for path in sorted(_HERE.glob("p2_staged_manifest_wave*.json")):
        manifests[path.stem.removeprefix("p2_staged_manifest_")] = path
    return manifests


_MANIFESTS = _discover_manifests()


def _load_manifest(wave: str) -> dict:
    path = _MANIFESTS.get(wave)
    if path is None or not path.is_file():
        raise ValueError(f"unknown or missing wave manifest: {wave!r}")
    return json.loads(path.read_text(encoding="utf-8"))


def _hand_modules(manifest: dict, stem_filter: str | None) -> list[dict]:
    rows = [m for m in manifest["modules"] if m.get("staging") == "hand"]
    if stem_filter:
        rows = [m for m in rows if m["stem"] == stem_filter]
    return rows


def _sidecar_for_output(output: Path) -> Path:
    stem = output.with_suffix("")
    return stem.parent / f"{stem.name}.c2jac.report.json"


def _sync_sidecar(stem: str, staged_dir: Path, lifted_dir: Path) -> None:
    """Mirror the staged sidecar into the lifted tree with counts preserved.

    Zeroing the lifted sidecar here used to silently reset the staged oracle's
    Tier-B counts to a clean slate after every sync, leaving no audit trail of
    how many sites the canonical oracle still carries. Copying the staged
    sidecar (with a ``staged_sync`` provenance marker) keeps the aggregate
    ratchet truthful; a fresh lift overwrites it again from real output.
    """
    src = staged_dir / f"{stem}.c2jac.report.json"
    dst = lifted_dir / f"{stem}.c2jac.report.json"
    if not src.is_file():
        raise FileNotFoundError(
            f"missing staged sidecar {src} — refresh tier-B measurements for "
            "the staged oracle before syncing"
        )
    data = json.loads(src.read_text(encoding="utf-8"))
    data["output"] = (lifted_dir / f"{stem}.jac").relative_to(_REPO).as_posix()
    data["staged_sync"] = True
    dst.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def refresh_wave_aggregate(manifest: dict) -> None:
    from t8_driver import refresh_aggregate_report

    lifted_dir = _REPO / manifest["lifted_dir"]
    aggregate = lifted_dir / "project.c2jac.report.json"
    if aggregate.is_file():
        refresh_aggregate_report(aggregate)


def sync_hand_staged(
    *,
    dry_run: bool = False,
    stem: str | None = None,
    wave: str = "wave1",
    refresh_reports: bool = True,
) -> int:
    manifest = _load_manifest(wave)
    staged_dir = _REPO / manifest["staged_dir"]
    lifted_dir = _REPO / manifest["lifted_dir"]
    rows = _hand_modules(manifest, stem)
    if stem and not rows:
        print(f"error: {stem!r} is not a hand-staged module in {wave}", file=sys.stderr)
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
            print(
                f"would sync sidecar "
                f"{_sidecar_for_output(dst).relative_to(_REPO)} (counts preserved)"
            )
        else:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            _sync_sidecar(name, staged_dir, lifted_dir)
            print(f"copied {src.relative_to(_REPO)} -> {dst.relative_to(_REPO)}")
        copied += 1

    if copied == 0:
        print("no hand-staged modules to sync", file=sys.stderr)
        return 1

    if refresh_reports and not dry_run:
        refresh_wave_aggregate(manifest)
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
    parser.add_argument(
        "--wave",
        choices=tuple(_MANIFESTS),
        default="wave1",
        help="P2 wave manifest (default: wave1)",
    )
    parser.add_argument(
        "--no-refresh-reports",
        action="store_true",
        help="skip aggregate project.c2jac.report.json reconcile",
    )
    args = parser.parse_args()
    return sync_hand_staged(
        dry_run=args.dry_run,
        stem=args.stem,
        wave=args.wave,
        refresh_reports=not args.no_refresh_reports,
    )


if __name__ == "__main__":
    raise SystemExit(main())
