#!/usr/bin/env python3
"""Diff the bytecode sections of two jir cache generations.

A generation directory is one compiler state's view of the module cache.
Comparing SEC_BYTECODE byte-for-byte across two generations measures how
much of an invalidation was real: artifacts that come out identical were
spurious rebuilds, and a produce-cone key that excludes the edited files
would have kept them warm.

Usage:
    jir_generation_diff.py <gen-dir-a> <gen-dir-b>
    jir_generation_diff.py --latest [modules-root]

With --latest, the two most recently modified generation directories under
the modules root (default: the platform jir module cache) are compared.
"""

from __future__ import annotations

import os
import struct
import sys
from pathlib import Path

HEADER_MIN = 20
SECTIONS_MAGIC = b"JIRX"
SEC_BYTECODE = 0x02
SEC_TERMINATOR = 0xFF


def read_bytecode(path: Path) -> bytes | None:
    data = path.read_bytes()
    pos = data.find(SECTIONS_MAGIC, HEADER_MIN)
    if pos < 0:
        return None
    pos += len(SECTIONS_MAGIC)
    while pos < len(data):
        sec_type = data[pos]
        pos += 1
        if sec_type == SEC_TERMINATOR:
            break
        if pos + 4 > len(data):
            break
        (sec_len,) = struct.unpack_from("<I", data, pos)
        pos += 4
        if sec_type == SEC_BYTECODE:
            return data[pos : pos + sec_len]
        pos += sec_len
    return None


def default_modules_root() -> Path:
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Caches" / "jac" / "jir" / "modules"
    xdg = os.environ.get("XDG_CACHE_HOME")
    base = Path(xdg) if xdg else Path.home() / ".cache"
    return base / "jac" / "jir" / "modules"


def is_generation(path: Path) -> bool:
    name = path.name
    return (
        path.is_dir()
        and len(name) == 16
        and all(ch in "0123456789abcdef" for ch in name)
    )


def latest_two(root: Path) -> tuple[Path, Path]:
    gens = sorted(
        (p for p in root.iterdir() if is_generation(p)),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    if len(gens) < 2:
        raise SystemExit(f"need at least two generations under {root}")
    return gens[1], gens[0]


def main() -> int:
    args = sys.argv[1:]
    if args and args[0] == "--latest":
        this_root = Path(args[1]) if len(args) > 1 else default_modules_root()
        gen_a, gen_b = latest_two(this_root)
    elif len(args) == 2:
        gen_a, gen_b = Path(args[0]), Path(args[1])
    else:
        print(__doc__)
        return 2

    names_a = {p.name for p in gen_a.glob("*.jir")}
    names_b = {p.name for p in gen_b.glob("*.jir")}
    common = sorted(names_a & names_b)
    identical = 0
    missing = 0
    differing: list[str] = []
    for name in common:
        bc_a = read_bytecode(gen_a / name)
        bc_b = read_bytecode(gen_b / name)
        if bc_a is None or bc_b is None:
            missing += 1
        elif bc_a == bc_b:
            identical += 1
        else:
            differing.append(name)

    print(f"generation A: {gen_a}  ({len(names_a)} jirs)")
    print(f"generation B: {gen_b}  ({len(names_b)} jirs)")
    print(f"common: {len(common)}  identical: {identical}  "
          f"different: {len(differing)}  no-bytecode: {missing}")
    if common:
        spurious = 100.0 * identical / len(common)
        print(f"spurious-invalidation rate: {spurious:.1f}%")
    for name in differing:
        print(f"  differs: {name}")
    only_a = sorted(names_a - names_b)
    only_b = sorted(names_b - names_a)
    if only_a:
        print(f"only in A: {len(only_a)}")
    if only_b:
        print(f"only in B: {len(only_b)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
