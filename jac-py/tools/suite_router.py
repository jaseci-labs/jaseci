#!/usr/bin/env python3
"""Suite router: classify CPython Lib/test suites into farm routing buckets.

Static analyzer run BEFORE any farm time is spent. For each pinned-tree
``Lib/test/test_*.py`` suite (CPython pin per CURRENT.md / fetch_cpython_reference.py)
it parses imports and top-level feature usage and assigns exactly one primary
bucket, keeping every matched signal for audit:

- QUARANTINE          threading/multiprocessing/signals/socket/network/subprocess/
                      locale/ctypes/tkinter/platform-specific (jac-py/PLAN.md v1
                      non-goals: threading deferred, ctypes out, platform wrappers
                      bind-later).
- RUNTIME-GAP         test bodies use syntax/features mapping to known-missing
                      native ops (evidence-based: vm_opcode_fixtures EMISSION_OPCODES
                      diff + BAND11 learnings; implemented features such as
                      zero-arg super() and ``from x import *`` are NOT tagged).
- NEEDS-FACADE        depends on C accelerator modules with pure-Python fallbacks
                      (detected data-driven from Lib source: try/_x import/
                      except ImportError) -> route via the stdlib_delegate pattern
                      (see jac-py/jacpython/test_stdlib_delegate.jac).
- SELF-HOST-CANDIDATE tests a specific pure-Lib module whose own source could be
                      py2jac'd so the suite runs against native code (highest
                      future value; listed explicitly).
- MECHANICAL          pure-python-under-test, no forbidden deps -> convertible by
                      convert_suite.py as-is.

Already-conformant suites (existing test_*_parity.jac files plus gated entries in
conformance_baseline.json) are overlaid as ``conformant`` flags; they keep their
intrinsic bucket so the manifest stays re-runnable as coverage grows.

Usage:
    .venv/bin/python jac-py/tools/suite_router.py \\
        [--tree reference/cpython] [-o jac-py/tools/suite_routing.json] ...
"""
from __future__ import annotations

import argparse
import ast
import json
import re
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent

BUCKET_ORDER = (
    "QUARANTINE",
    "RUNTIME-GAP",
    "NEEDS-FACADE",
    "SELF-HOST-CANDIDATE",
    "MECHANICAL",
)

# jac-py/PLAN.md v1 non-goals / deferred substrate, expressed as imported
# module roots. Direct imports only -- test.support internals do not count.
# (The C-extension ABI is a stated non-goal; _testcapi/_testinternalcapi are
# deleted from the port target per PLAN §3.)
_FORBIDDEN_ROOTS = frozenset(
    {
        # C test scaffolding (non-goal, deleted substrate)
        "_testcapi", "_testinternalcapi", "_testbuffer", "_testmultiphase",
        "_xxsubinterpreters", "_interpreters",
        # threading / multiprocessing / signals (deferred, PLAN §12.4)
        "threading", "_thread", "multiprocessing", "signal", "_signal",
        # socket / network stack (bind-later wrappers)
        "socket", "_socket", "selectors", "select", "ssl", "asyncio",
        "http", "urllib.request", "urllib.error", "ftp", "smtplib",
        "imaplib", "nntplib", "telnetlib", "xmlrpc", "socketserver",
        "asynchat", "asyncore",
        # process spawning
        "subprocess",
        # locale / i18n substrate
        "locale", "_locale", "gettext", "iconv",
        # FFI / GUI
        "ctypes", "_ctypes", "tkinter", "curses", "_curses", "tty", "pty",
        # platform-only
        "winreg", "_winapi", "_wmi", "posixshmem", "posix_ipc", "ossaudiodev",
    }
)

_NETWORK_PREFIXES = ("urllib.", "xmlrpc.", "http.")

# AST/text features -> known-missing native ops. Evidence:
#   * vm_opcode_fixtures.EMISSION_OPCODES diff vs reference _opcode_metadata:
#     CHECK_EG_MATCH / CALL_INTRINSIC_2 absent (Band 11 lowered except* parsing,
#     ExceptionGroup runtime still pending -- BAND11_SLICE_LEARNINGS.md).
#   * DICT_MERGE absent ({**x} merge into existing dict sites).
#   * Instrumentation ops absent (sys.settrace/setprofile/sys.monitoring).
# Deliberately NOT here: zero-arg super() (LOAD_SUPER_ATTR landed, PLAN §449),
# ``from x import *`` (VM supports, PLAN §544), async generators (ORACLE_GOLDENS
# b7_async), generators/yield-from (T7 cliffs).
_GAP_FEATURES: tuple[tuple[str, tuple[str, ...], re.Pattern[str] | None], ...] = (
    ("except*-exception-group", ("CHECK_EG_MATCH", "CALL_INTRINSIC_2"), None),
    ("dict-unpack-merge", ("DICT_MERGE",), None),
    (
        "tracing-instrumentation",
        ("INSTRUMENTED_*",),
        re.compile(r"sys\.(settrace|setprofile|monitoring)\b"),
    ),
)

# Pure-Lib modules whose accelerator fallback this tool must recognize even if
# the data-driven Lib scan misses the idiom (belt-and-suspenders; verified ids
# below come from the actual try/except ImportError pattern in 3.14.6 Lib).
_KNOWN_FACADES = {
    "pickle": "_pickle",
    "datetime": "_datetime",
    "heapq": "_heapq",
    "bisect": "_bisect",
    "collections": "_collections",
    "functools": "_functools",
    "json": "_json",
    "csv": "_csv",
    "random": "_random",
    "struct": "_struct",
    "zoneinfo": "_zoneinfo",
    "abc": "_abc",
    # Accelerators loaded below package __init__ depth (outside the facade-scan
    # roots), verified in the pinned tree:
    "dbm": "_gdbm",          # Lib/dbm/__init__.py try-import
    "sqlite3": "_sqlite3",   # Lib/sqlite3/dbapi2.py import
    "xml": "_elementtree",   # Lib/xml/etree/ElementTree.py try-import
}

# Conformance ground truth already green (do not spend farm time again):
#  * jac-py/tests/test_<mod>_parity.jac files (full differential parity legs)
#  * jac-py/tests/test_p2_libtest_partial.jac subjects (partial Lib/test legs)
#  * conformance_baseline.json stdlib_delegate entries (full-suite gates)
_PARITY_MODULES = (
    "array", "binascii", "collections", "csv", "datetime", "functools",
    "itertools", "json", "random", "struct",
)
_PARTIAL_LIBTEST_MODULES = ("bisect", "heapq", "platform", "stat")
_DELEGATE_MODULES = ("base64", "binascii", "datetime", "hashlib", "re",
                     "uuid", "zlib")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--tree", type=Path, default=_REPO / "reference" / "cpython",
        help="pinned CPython checkout root",
    )
    parser.add_argument(
        "-o", "--output", type=Path,
        default=_HERE / "suite_routing.json",
        help="routing JSON output path (farm input manifest)",
    )
    parser.add_argument(
        "--summary", type=Path,
        default=_HERE / "suite_routing.md",
        help="markdown summary table path",
    )
    return parser.parse_args(argv)


# ---------------------------------------------------------------- Lib scans


def _lib_py_files(tree: Path) -> list[Path]:
    return sorted((tree / "Lib").rglob("*.py"))


def _imports_accelerator(node: ast.AST) -> list[str]:
    """Return _-prefixed accelerator module names referenced by this stmt."""
    out: list[str] = []
    if isinstance(node, ast.Import):
        out.extend(a.name for a in node.names if a.name.startswith("_"))
    elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
        if node.module.startswith("_"):
            out.append(node.module)
        # ``from _json import scanner``: the module operand is the accelerator;
        # bare underscore *attribute* aliases are not modules.
    return out





def scan_facade_map(tree: Path) -> dict[str, str]:
    """Data-driven: pure-Lib module -> accelerator it falls back to.

    Only genuine facade sites are scanned: top-level ``Lib/*.py`` files and
    package ``__init__.py`` files (the ``try: from _x import *`` idiom lives
    there). Deeper intra-package imports of private submodules and underscore
    *attribute* aliases (``from enum import _simple_enum``) are not accelerator
    loads. An imported ``_x`` counts as a C accelerator only when no
    ``Lib/_x.py`` exists -- otherwise it is itself pure Python (``_py_abc``,
    ``_collections_abc``, ``_weakrefset``...).
    """
    lib = tree / "Lib"
    files = [
        f for f in sorted(lib.rglob("*.py"))
        if (len(f.relative_to(lib).parts) == 1 or f.name == "__init__.py")
        and f.relative_to(lib).parts[0] != "test"
    ]
    pure_underscore = {
        f.with_suffix("").name for f in lib.glob("_*.py")
    } | {"_py"}
    # Not accelerators: dunder pseudo-modules and Windows-only C extensions
    # that never load on the (Linux) farm.
    non_accelerator = pure_underscore | {
        "__main__", "__init__", "_winapi", "_wmi", "nt",
    }
    facades: dict[str, str] = {}
    for f in files:
        try:
            src = f.read_text(encoding="utf-8", errors="replace")
            mod_tree = ast.parse(src)
        except SyntaxError:
            continue
        rel = f.relative_to(tree / "Lib")
        pure_mod = (
            rel.with_suffix("").as_posix()
            if f.name != "__init__.py"
            else rel.parent.as_posix()
        )
        hits = {
            acc.split(".")[0]
            for node in ast.walk(mod_tree)
            for acc in _imports_accelerator(node)
            if acc.split(".")[0] not in non_accelerator
        }
        owner = pure_mod.split("/")[0]
        if owner:
            for h in sorted(hits):
                facades.setdefault(owner, h)
    for pure, acc in _KNOWN_FACADES.items():
        facades.setdefault(pure, acc)
    return facades


# ------------------------------------------------------------- per-suite AST


_DYNAMIC_IMPORT_RE = re.compile(
    r"\b(?:import_module|import_fresh_module|import_extension)\(\s*['\"]([\w.]+)['\"]"
)


def collect_imports(tree: ast.Module, source: str) -> set[str]:
    """Absolute imports anywhere in the suite, plus dynamic import_module()
    string arguments (test.support.import_helper hides real deps like
    dbm.gnu or _xxsubinterpreters from plain AST analysis)."""
    mods: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            mods.update(a.name for a in node.names)
        elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
            mods.add(node.module)
            mods.update(f"{node.module}.{a.name}" for a in node.names if a.name != "*")
    mods.update(_DYNAMIC_IMPORT_RE.findall(source))
    return mods


def _root_of(mod: str) -> str:
    return mod.split(".")[0]


def detect_quarantine(imports: set[str], source: str) -> list[str]:
    sig: list[str] = []
    seen: set[str] = set()
    for mod in sorted(imports):
        hit = None
        if mod == "test.support.script_helper":
            hit = "subprocess"  # assert_python_* spawns interpreter processes
        elif mod == "test.support.threading_helper":
            hit = "threading"
        elif mod == "test.support.socket_helper":
            hit = "socket"
        elif mod == "test._test_multiprocessing":
            # Shared multiprocessing test corpus loaded by the
            # test_multiprocessing_{fork,forkserver,spawn} packages.
            hit = "multiprocessing"
        elif mod in _FORBIDDEN_ROOTS or _root_of(mod) in _FORBIDDEN_ROOTS:
            hit = _root_of(mod)
        else:
            for pref in _NETWORK_PREFIXES:
                if mod.startswith(pref):
                    hit = pref.rstrip(".")
                    break
        if hit and hit not in seen:
            seen.add(hit)
            sig.append(f"forbidden-import:{hit}")
    if "requires_working_threading" in source:
        sig.append("forbidden-import:threading [requires_working_threading]")
    if re.search(
        r"\bsys\.platform\b|\bplatform\.(system|machine|release|win32)|\bos\.name\b"
        r"|\bos\.(openpty|forkpty|fork)\b",
        source,
    ):        sig.append("platform-specific-checks")
    return sig


def detect_runtime_gaps(tree: ast.Module, source: str) -> list[str]:
    sig: list[str] = []
    kinds: set[type] = set()
    dict_merge = False
    for node in ast.walk(tree):
        kinds.add(type(node))
        if (
            isinstance(node, ast.Call)
            and isinstance(node.func, ast.Name)
            and node.func.id == "dict"
            and any(kw.arg is None for kw in node.keywords)
        ):
            dict_merge = True
    for name, ops, rx in _GAP_FEATURES:
        triggered = False
        detail = ""
        if name == "except*-exception-group":
            triggered = ast.TryStar in kinds
        elif name == "dict-unpack-merge":
            triggered = dict_merge
        elif rx is not None:
            m = rx.search(source)
            triggered = bool(m)
            detail = m.group(0) if m else ""
        if triggered:
            sig.append(f"{name} (missing ops: {', '.join(ops)}){'' if not detail else ' [' + detail + ']'}")
    return sig


def detect_facade(
    imports: set[str], facades: dict[str, str], pure_underscore: set[str],
    source: str,
) -> list[str]:
    sig: set[str] = set()
    accels = set(facades.values())
    if re.search(r"\bcodecs\.(lookup|register|decode|encode)\b", source):
        # Codec registry hits load C codec accelerators (_codecs_jp & co.)
        # implicitly -- invisible to import analysis.
        sig.add("implicit-codec-dependency:codecs->_codecs_*")
    if "test.multibytecodec_support" in imports:
        # test_codecencodings_* / test_codecmaps_* ride the C
        # _multibytecodec machinery via this shared helper.
        sig.add("implicit-codec-dependency:test.multibytecodec_support->_multibytecodec")
    for mod in sorted(imports):
        root = _root_of(mod)
        if "." in root or root.startswith("__"):
            continue
        if root in facades:
            # Pure-Lib wrapper around a try/_x-import accelerator.
            sig.add(f"facade-module:{root}->{facades[root]}")
        elif root.startswith("_") and (
            root in accels or root not in pure_underscore
        ):
            # Direct load of a C accelerator with no Lib/_x.py fallback
            # (e.g. _xxtestfuzz).
            sig.add(f"direct-accelerator-import:{root}")
    return sorted(sig)


def subject_of(suite_name: str) -> str:
    assert suite_name.startswith("test_")
    return suite_name[len("test_"):]


def detect_self_host(subject: str, tree: Path, facades: dict[str, str]) -> list[str]:
    lib = tree / "Lib"
    candidates = [
        lib / f"{subject}.py",
        lib / subject / "__init__.py",
    ]
    for c in candidates:
        if c.is_file():
            if subject in facades:
                return []  # facade bucket owns it
            return [f"pure-lib-subject:{subject}"]
    return []


# ------------------------------------------------------------------ overlay


def build_conformant_map(tools_dir: Path) -> dict[str, str]:
    """suite name -> coverage kind ('parity' | 'delegate' | 'partial')."""
    out: dict[str, str] = {}
    tests_dir = tools_dir.parent / "tests"
    for mod in _PARITY_MODULES:
        matches = sorted(tests_dir.glob(f"test_{mod}*_parity.jac"))
        if matches:
            out[f"test_{mod}"] = "parity"
    for mod in _PARTIAL_LIBTEST_MODULES:
        out.setdefault(f"test_{mod}", "partial")
    for mod in _DELEGATE_MODULES:
        out.setdefault(f"test_{mod}", "delegate")
    baseline = tools_dir / "conformance_baseline.json"
    if baseline.is_file():
        entries = json.loads(baseline.read_text(encoding="utf-8"))["entries"]
        for key, val in entries.items():
            if val.get("gate_type") != "libtest" or val.get("status") != "gated":
                continue
            mod = key.removeprefix("_").removesuffix("module")
            suite = f"test_{mod}"
            if suite in out:
                continue
            if (tools_dir.parent / "tests" / f"{suite}.jac").exists() or \
               (Path("reference/cpython/Lib") / f"{mod}.py").exists():
                out.setdefault(suite, "partial")
    return out


# ------------------------------------------------------------------- driver


def classify_suite(
    path: Path, tree: Path, facades: dict[str, str], pure_underscore: set[str]
) -> dict:
    suite = path.stem
    subject = subject_of(suite)
    source = path.read_text(encoding="utf-8", errors="replace")
    signals: list[str] = []
    try:
        parsed = ast.parse(source)
    except SyntaxError as exc:
        bucket = "MECHANICAL"
        signals.append(f"ast-parse-failed:{exc.lineno}")
    else:
        imports = collect_imports(parsed, source)
        q = detect_quarantine(imports, source)
        g = detect_runtime_gaps(parsed, source)
        f = detect_facade(imports, facades, pure_underscore, source)
        s = detect_self_host(subject, tree, facades)
        signals.extend(q + g + f + s)
        if q:
            bucket = "QUARANTINE"
        elif g:
            bucket = "RUNTIME-GAP"
        elif f:
            bucket = "NEEDS-FACADE"
        elif s:
            bucket = "SELF-HOST-CANDIDATE"
        else:
            bucket = "MECHANICAL"
    return {"suite": suite, "bucket": bucket, "signals": signals}


def route(tree: Path, output: Path, summary: Path) -> dict:
    libtest = tree / "Lib" / "test"
    suites = sorted(libtest.glob("test_*.py"))
    facades = scan_facade_map(tree)
    pure_underscore = {
        f.with_suffix("").name for f in (tree / "Lib").glob("_*.py")
    } | {"_py"}
    rows = [classify_suite(p, tree, facades, pure_underscore) for p in suites]

    # Package-style suites (3.14 split test_json/test_asyncio/test_ctypes/...
    # into directories): aggregate every inner test_*.py into one row with the
    # union of signals and the highest-priority member bucket.
    packages = sorted(d for d in libtest.glob("test_*") if d.is_dir())
    pkg_rows: list[dict] = []
    for pkg in packages:
        members = sorted(pkg.rglob("test_*.py"))
        if not members:
            continue
        classified = [
            classify_suite(p, tree, facades, pure_underscore) for p in members
        ]
        sigs = sorted({s for c in classified for s in c["signals"]})
        bucket = next(
            b for b in BUCKET_ORDER if any(c["bucket"] == b for c in classified)
        )
        pkg_rows.append(
            {"suite": pkg.name, "bucket": bucket, "signals": sigs}
        )
    rows.extend(pkg_rows)

    conformant = build_conformant_map(_HERE)
    for row in rows:
        cov = conformant.get(row["suite"])
        row["conformant"] = cov is not None
        row["coverage"] = cov

    counts: dict[str, int] = {b: 0 for b in BUCKET_ORDER}
    for row in rows:
        counts[row["bucket"]] += 1

    doc = {
        "tool": "suite_router",
        "pin": {
            "version": "3.14.6",
            "tree": str(tree),
            "policy": "CURRENT.md / fetch_cpython_reference.py",
        },
        "total_suites": len(rows),
        "file_suites": len(suites),
        "package_suites": len(pkg_rows),
        "bucket_counts": counts,
        "conformant_count": sum(1 for r in rows if r["conformant"]),
        "facades_detected": facades,
        "suites": rows,
    }
    output.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")

    summary.write_text(render_summary(doc), encoding="utf-8")

    print(
        "suite_router: "
        + ", ".join(f"{b}={counts[b]}" for b in BUCKET_ORDER)
        + f"; conformant={doc['conformant_count']} (total {len(rows)})"
    )
    print(f"manifest -> {output}")
    print(f"summary  -> {summary}")
    return doc


def render_summary(doc: dict) -> str:
    lines: list[str] = []
    pin = doc["pin"]
    lines.append("# Suite routing (static, pre-farm)")
    lines.append("")
    lines.append(
        f"Pin: CPython {pin['version']} (`{pin['tree']}`, see CURRENT.md). "
        f"{doc['file_suites']} top-level suites + {doc['package_suites']} "
        "package-style suites (test_json/test_asyncio/... aggregated over their "
        f"inner test_*.py) = {doc['total_suites']} classified before any farm "
        f"time is spent; {doc['conformant_count']} already covered by parity/gate "
        "legs (flagged `conformant`, kept in their intrinsic bucket)."
    )
    lines.append("")
    lines.append("| Bucket | Count | Meaning |")
    lines.append("|---|---|---|")
    meanings = {
        "MECHANICAL": "pure-python-under-test, convertible by convert_suite.py",
        "NEEDS-FACADE": "C accelerator w/ pure-Python fallback -> stdlib_delegate pattern",
        "SELF-HOST-CANDIDATE": "pure-Lib subject could be py2jac'd; tests then run native",
        "RUNTIME-GAP": "needs known-missing ops/runtime features",
        "QUARANTINE": "threads/signals/socket/subprocess/locale/ctypes/tkinter/platform",
    }
    for b in BUCKET_ORDER:
        lines.append(f"| {b} | {doc['bucket_counts'][b]} | {meanings[b]} |")
    lines.append("")
    for b in BUCKET_ORDER:
        members = [r["suite"] for r in doc["suites"] if r["bucket"] == b]
        lines.append(f"## {b} ({len(members)})")
        lines.append("")
        if b == "SELF-HOST-CANDIDATE":
            lines.append("Highest future value: py2jac the subject module, rerun suite against native code.")
            lines.append("")
        for m in members:
            row = next(r for r in doc["suites"] if r["suite"] == m)
            flags = []
            if row["conformant"]:
                flags.append(f"conformant:{row['coverage']}")
            tail = f" ({'; '.join(flags)})" if flags else ""
            sigs = "; ".join(row["signals"]) if row["signals"] else "no signals"
            lines.append(f"- `{m}`: {sigs}{tail}")
        lines.append("")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if not (args.tree / "Lib" / "test").is_dir():
        print(f"suite_router: not a CPython tree: {args.tree}", file=sys.stderr)
        return 1
    # Keep the user-facing path as given so the committed manifest stays
    # portable; pathlib resolves lazily for all globs below.
    route(args.tree, args.output.resolve(), args.summary.resolve())
    return 0


if __name__ == "__main__":
    sys.exit(main())
