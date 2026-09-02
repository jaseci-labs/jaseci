#!/usr/bin/env python3
"""Compare TTG prefetch UUID dumps with runtime access logs."""

from __future__ import annotations

import argparse
import csv
from collections import Counter, OrderedDict
from pathlib import Path
from uuid import UUID


def canon(raw: str) -> str | None:
    try:
        return str(UUID(str(raw).strip()))
    except (TypeError, ValueError):
        return None


def ordered_unique(values: list[str]) -> list[str]:
    return list(OrderedDict((value, None) for value in values).keys())


def load_prefetch(path: Path) -> tuple[list[str], dict[str, str]]:
    ids: list[str] = []
    types: dict[str, str] = {}
    with path.open(newline="") as fh:
        reader = csv.DictReader(fh)
        if not reader.fieldnames or "id" not in reader.fieldnames:
            raise SystemExit(f"{path} is not a prefetch dump with an id column")
        for row in reader:
            uid = canon(row.get("id", ""))
            if uid is None:
                continue
            ids.append(uid)
            typ = (row.get("type") or "").strip()
            if typ and uid not in types:
                types[uid] = typ
    return ordered_unique(ids), types


def load_access(path: Path) -> tuple[list[dict[str, str]], dict[str, str]]:
    rows: list[dict[str, str]] = []
    types: dict[str, str] = {}
    with path.open(newline="") as fh:
        reader = csv.DictReader(fh)
        required = {"id", "tier", "type"}
        if not reader.fieldnames or not required.issubset(set(reader.fieldnames)):
            raise SystemExit(f"{path} is not an access log with id,tier,type columns")
        for row in reader:
            uid = canon(row.get("id", ""))
            if uid is None:
                continue
            tier = (row.get("tier") or "").strip()
            typ = (row.get("type") or "").strip()
            rows.append({"id": uid, "tier": tier, "type": typ})
            if typ and uid not in types:
                types[uid] = typ
    return rows, types


def by_type(ids: set[str], types: dict[str, str]) -> dict[str, int]:
    counts: Counter[str] = Counter()
    for uid in ids:
        counts[types.get(uid) or "unknown"] += 1
    return dict(sorted(counts.items()))


def write_list(out_dir: Path | None, name: str, ids: list[str]) -> None:
    if out_dir is None:
        return
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / name).write_text("".join(f"{uid}\n" for uid in ids))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Diff JAC_PREFETCH_DUMP UUIDs against access_log UUIDs."
    )
    parser.add_argument("--prefetch", required=True, type=Path)
    parser.add_argument("--access", required=True, type=Path)
    parser.add_argument("--type", dest="type_filter", default="")
    parser.add_argument("--sample", type=int, default=12)
    parser.add_argument("--out-dir", type=Path)
    args = parser.parse_args()

    prefetch_ids, prefetch_types = load_prefetch(args.prefetch)
    access_rows, access_types = load_access(args.access)
    types = {**prefetch_types, **access_types}

    if args.type_filter:
        access_rows = [r for r in access_rows if r["type"] == args.type_filter]
        prefetch_ids = [
            uid for uid in prefetch_ids if prefetch_types.get(uid) == args.type_filter
        ]

    actual_ids = ordered_unique([r["id"] for r in access_rows])
    l3_ids = ordered_unique([r["id"] for r in access_rows if r["tier"] == "L3"])

    prefetch_set = set(prefetch_ids)
    actual_set = set(actual_ids)
    l3_set = set(l3_ids)

    missed_actual = [uid for uid in actual_ids if uid not in prefetch_set]
    missed_l3 = [uid for uid in l3_ids if uid not in prefetch_set]
    wasted = [uid for uid in prefetch_ids if uid not in actual_set]

    tier_counts = Counter(r["tier"] for r in access_rows)
    print(f"prefetch_unique={len(prefetch_set)}")
    print(f"actual_unique={len(actual_set)}")
    print(f"access_tiers={dict(sorted(tier_counts.items()))}")
    print(f"missed_actual={len(missed_actual)}")
    print(f"missed_l3={len(missed_l3)}")
    print(f"wasted_prefetch={len(wasted)}")
    print(f"prefetch_by_type={by_type(prefetch_set, types)}")
    print(f"actual_by_type={by_type(actual_set, types)}")
    print(f"missed_l3_by_type={by_type(set(missed_l3), types)}")
    print(f"wasted_by_type={by_type(set(wasted), types)}")
    print(f"missed_l3_sample={missed_l3[:args.sample]}")
    print(f"wasted_sample={wasted[:args.sample]}")

    write_list(args.out_dir, "prefetch_ids.txt", prefetch_ids)
    write_list(args.out_dir, "actual_ids.txt", actual_ids)
    write_list(args.out_dir, "l3_ids.txt", l3_ids)
    write_list(args.out_dir, "missed_actual_ids.txt", missed_actual)
    write_list(args.out_dir, "missed_l3_ids.txt", missed_l3)
    write_list(args.out_dir, "wasted_prefetch_ids.txt", wasted)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
