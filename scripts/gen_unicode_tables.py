#!/usr/bin/env python3
"""Generate na_stdlib/unicodedata.jac from CPython unicodedata tables.

Uses the host interpreter's ``unicodedata`` module (expected Python 3.14+)
to build compact sorted range tables for ``category`` and ``east_asian_width``.
"""

from __future__ import annotations

import argparse
import sys
import unicodedata
from pathlib import Path

# East-asian-width property values are multi-char in Python except one-letter
# codes; store them as single lookup-table characters (see _EAW_CODES).
_EAW_TO_CHAR: dict[str, str] = {
    "W": "W",
    "F": "F",
    "N": "N",
    "Na": "a",
    "H": "H",
    "A": "S",
}

_MAX_CODEPOINT = 0x10FFFF
_SURROGATE_LO = 0xD800
_SURROGATE_HI = 0xDFFF

_MODULE_DOC = '''"""Native `unicodedata` floor (Mechanism B -- pure Jac, no FFI).

`east_asian_width(ch)` and `category(ch)` answered from compact,
sorted range tables compiled into this module. The tables were generated
from CPython 3.14 `unicodedata` (Unicode {version}) by
`vendor/jac/scripts/gen_unicode_tables.py`; they are exact for every
code point against that Unicode version and drift silently when CPython
adopts a newer one (same trade-off as any vendored table).

Representation: `_BOUNDS[i]` starts a run whose category index is
`_CATIDS[i]` (index into `_CAT_CODES`); the run ends where the next run
starts. East-asian-width runs are analogous (`_EAW_BOUNDS` / `_EAW_IDS`
into `_EAW_CODES`). Lookup is a binary search over the boundary list.

SCOPE: `ch` must be a single-character string; other lengths answer the
lookup for the empty string as "" (documented divergence: CPython raises
TypeError). Only these two entry points are provided -- `name`,
`lookup`, `normalize`, `combining`, `mirrored`, etc. are out of scope.
"""'''

_LOOKUP_HELPERS = '''
def _seg_code(bounds: list[int], ids: list[int], cp: int) -> int {
    lo: int = 0;
    hi: int = len(bounds) - 1;
    ans: int = 0;
    while lo <= hi {
        mid: int = (lo + hi) // 2;
        if bounds[mid] <= cp {
            ans = mid;
            lo = mid + 1;
        } else {
            hi = mid - 1;
        }
    }
    return ids[ans];
}


def:pub category(ch: str) -> str {
    if len(ch) != 1 {
        return "";
    }
    idx: int = _seg_code(_BOUNDS, _CATIDS, ord(ch));
    return _CAT_CODES[idx * 2 : idx * 2 + 2];
}


def:pub east_asian_width(ch: str) -> str {
    if len(ch) != 1 {
        return "";
    }
    idx: int = _seg_code(_EAW_BOUNDS, _EAWIDS, ord(ch));
    return _EAW_CODES[idx];
}
'''


def _iter_codepoints() -> list[int]:
    out: list[int] = []
    for cp in range(_MAX_CODEPOINT + 1):
        if _SURROGATE_LO <= cp <= _SURROGATE_HI:
            continue
        out.append(cp)
    return out


def _build_runs(codepoints: list[int], prop_fn) -> tuple[list[int], list[str]]:
    """Return (bounds, values) for consecutive runs with the same property."""
    bounds: list[int] = []
    values: list[str] = []
    prev: str | None = None
    for cp in codepoints:
        val = prop_fn(cp)
        if val != prev:
            bounds.append(cp)
            values.append(val)
            prev = val
    return bounds, values


def _encode_eaw(values: list[str]) -> tuple[str, list[int]]:
    """Map EAW property strings to single-char codes and index list."""
    codes: list[str] = []
    index: dict[str, int] = {}
    ids: list[int] = []
    for val in values:
        ch = _EAW_TO_CHAR[val]
        if ch not in index:
            index[ch] = len(codes)
            codes.append(ch)
        ids.append(index[ch])
    return "".join(codes), ids


def _encode_category(values: list[str]) -> tuple[str, list[int]]:
    """Map 2-char category strings to concatenated code string and index list."""
    codes: list[str] = []
    index: dict[str, int] = {}
    ids: list[int] = []
    for val in values:
        if val not in index:
            index[val] = len(codes)
            codes.append(val)
        ids.append(index[val])
    return "".join(codes), ids


def _format_int_list(name: str, items: list[int], *, per_line: int = 12) -> str:
    """Format a Jac ``glob`` integer list with wrapped lines."""
    lines = [f"glob {name}: list[int] = ["]
    row: list[str] = []
    for i, val in enumerate(items):
        row.append(str(val))
        if len(row) == per_line or i == len(items) - 1:
            lines.append("    " + ", ".join(row) + ("," if i < len(items) - 1 else ","))
            row = []
    lines.append("     ];")
    return "\n".join(lines)


def generate() -> str:
    codepoints = _iter_codepoints()
    version = unicodedata.unidata_version

    cat_bounds, cat_values = _build_runs(codepoints, lambda cp: unicodedata.category(chr(cp)))
    cat_codes, cat_ids = _encode_category(cat_values)

    eaw_bounds, eaw_values = _build_runs(
        codepoints, lambda cp: unicodedata.east_asian_width(chr(cp))
    )
    eaw_codes, eaw_ids = _encode_eaw(eaw_values)

    parts = [
        _MODULE_DOC.format(version=version),
        "",
        f'glob UNIDATA_VERSION: str = "{version}";',
        "",
        f'glob _CAT_CODES: str = "{cat_codes}";',
        "",
        _format_int_list("_BOUNDS", cat_bounds),
        "",
        _format_int_list("_CATIDS", cat_ids),
        "",
        f'glob _EAW_CODES: str = "{eaw_codes}";',
        "",
        _format_int_list("_EAW_BOUNDS", eaw_bounds),
        "",
        _format_int_list("_EAWIDS", eaw_ids),
        _LOOKUP_HELPERS,
    ]
    return "\n".join(parts)


def _default_output() -> Path:
    here = Path(__file__).resolve().parent
    return (
        here.parent
        / "jac"
        / "jaclang"
        / "runtimelib"
        / "na_stdlib"
        / "unicodedata.jac"
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--stdout",
        action="store_true",
        help="write generated Jac to stdout instead of the default output path",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=None,
        help="output .jac file (default: na_stdlib/unicodedata.jac)",
    )
    args = parser.parse_args(argv)

    text = generate()
    if args.stdout:
        sys.stdout.write(text)
        if not text.endswith("\n"):
            sys.stdout.write("\n")
        return 0

    out = args.output if args.output is not None else _default_output()
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8")
    print(f"wrote {out}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
