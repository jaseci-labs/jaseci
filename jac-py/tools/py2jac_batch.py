#!/usr/bin/env python3
"""T5 py2jac batch mode (jac-py/PLAN.md §6.5).

Walks an input tree of ``.py`` files, orders them by their intra-tree import
graph (SCC-aware, so import cycles convert together instead of failing),
converts each via ``jac tool py2jac``, quarantines per-file failures into a
JSON sidecar, transitively skips dependents of quarantined files, mirrors the
layout into an output root of ``.jac`` files, and writes an aggregate report.
``--incremental`` skips files whose source hash and previous status are
unchanged (state kept in a JSON sidecar beside the report).

The CLI surface of the real converter (verified against #7255 cleanup):
``<jac> tool py2jac <file.py>`` prints Jac to stdout and exits 0 on success,
non-zero on failure with diagnostics on stderr.

Usage:
    .venv/bin/python jac-py/tools/py2jac_batch.py Lib/ -o jac-py/Lib/ \\
        [--incremental] [--report report.json] [--exclude 'test_*'] ...
"""
from __future__ import annotations

import argparse
import ast
import fnmatch
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Callable

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_JAC = _REPO / ".venv" / "bin" / "jac"

_SKIP_DIRS = {"__pycache__", ".git", ".hg", ".svn", "node_modules"}

_ERR_TRUNCATE = 2000

Converter = Callable[[Path], tuple[str | None, str | None]]


def _dotted(path: Path) -> str:
    return ".".join(path.with_suffix("").parts)


def module_of(rel: Path) -> str:
    if rel.name == "__init__.py":
        return _dotted(rel.parent) if str(rel.parent) != "." else ""
    return _dotted(rel.with_suffix(""))


def build_module_index(files: list[Path]) -> dict[str, Path]:
    return {module_of(f): f for f in files}


def _candidate_modules(
    node: ast.stmt, own_package: str
) -> list[str]:
    out: list[str] = []
    if isinstance(node, ast.Import):
        for alias in node.names:
            out.extend(_prefixes(alias.name))
    elif isinstance(node, ast.ImportFrom):
        if node.level:
            # Relative import resolves against the owning *package* (already
            # computed by the caller), then walks up (level - 1) more.
            base_parts = own_package.split(".") if own_package else []
            up = node.level - 1
            base_parts = base_parts[: len(base_parts) - up] if up else base_parts
            if node.module:
                base_parts = base_parts + node.module.split(".")
            prefix = ".".join(base_parts)
            out.extend(_prefixes(prefix))
        else:
            prefix = node.module or ""
            out.extend(_prefixes(prefix))
        for alias in node.names:
            cand = f"{prefix}.{alias.name}" if prefix else alias.name
            out.append(cand)
    return [c for c in out if c]


def _prefixes(dotted: str) -> list[str]:
    parts = dotted.split(".") if dotted else []
    return [".".join(parts[: i + 1]) for i in range(len(parts))]


def extract_deps(
    source: Path, index: dict[str, Path], own_module: str
) -> list[Path]:
    try:
        tree = ast.parse(source.read_text(encoding="utf-8", errors="replace"))
    except SyntaxError:
        return []
    own_package = (
        own_module if source.name == "__init__.py"
        else own_module.rpartition(".")[0]
    )
    deps: set[Path] = set()
    for node in ast.walk(tree):
        if not isinstance(node, (ast.Import, ast.ImportFrom)):
            continue
        for cand in _candidate_modules(node, own_package):
            target = index.get(cand)
            if target is not None and target != source:
                deps.add(target)
    return sorted(deps)


def tarjan_scc(nodes: list[Path], edges: dict[Path, list[Path]]) -> list[list[Path]]:
    index_of: dict[Path, int] = {}
    lowlink: dict[Path, int] = {}
    on_stack: set[Path] = set()
    stack: list[Path] = []
    sccs: list[list[Path]] = []
    counter = 0

    for root in nodes:
        if root in index_of:
            continue
        work = [(root, 0)]
        while work:
            node, ei = work.pop()
            if ei == 0:
                index_of[node] = counter
                lowlink[node] = counter
                counter += 1
                stack.append(node)
                on_stack.add(node)
            descended = False
            succs = edges.get(node, [])
            while ei < len(succs):
                succ = succs[ei]
                ei += 1
                if succ not in index_of:
                    work.append((node, ei))
                    work.append((succ, 0))
                    descended = True
                    break
                if succ in on_stack:
                    lowlink[node] = min(lowlink[node], index_of[succ])
            if descended:
                continue
            if lowlink[node] == index_of[node]:
                comp = []
                while True:
                    w = stack.pop()
                    on_stack.discard(w)
                    comp.append(w)
                    if w == node:
                        break
                sccs.append(comp)
            if work:
                parent = work[-1][0]
                lowlink[parent] = min(lowlink[parent], lowlink[node])
    return sccs


def order_files(
    files: list[Path], deps: dict[Path, list[Path]]
) -> list[list[Path]]:
    """Return SCC groups ordered so dependencies precede dependents."""
    sccs = tarjan_scc(sorted(files), deps)
    comp_of: dict[Path, int] = {}
    for ci, comp in enumerate(sccs):
        for f in comp:
            comp_of[f] = ci
    comp_deps: list[set[int]] = [set() for _ in sccs]
    for f in files:
        for d in deps.get(f, []):
            if comp_of[d] != comp_of[f]:
                comp_deps[comp_of[f]].add(comp_of[d])

    perm: list[int] = []
    temp: set[int] = set()
    done: set[int] = set()

    def visit(ci: int) -> None:
        if ci in done or ci in temp:
            return
        temp.add(ci)
        for dj in sorted(comp_deps[ci]):
            visit(dj)
        temp.discard(ci)
        done.add(ci)
        perm.append(ci)

    for ci in range(len(sccs)):
        visit(ci)
    return [sorted(sccs[ci], key=str) for ci in perm]


def default_converter(jac_bin: Path) -> Converter:
    def convert(src: Path) -> tuple[str | None, str | None]:
        proc = subprocess.run(
            [str(jac_bin), "tool", "py2jac", str(src)],
            cwd=_REPO,
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            err = (proc.stderr or proc.stdout or "").strip()
            if len(err) > _ERR_TRUNCATE:
                err = err[-_ERR_TRUNCATE:]
            return None, err or f"exit code {proc.returncode}"
        return proc.stdout, None

    return convert


def discover_files(
    root: Path,
    include: list[str],
    exclude: list[str],
    modules: list[str],
) -> list[Path]:
    index_all: dict[str, Path] = {}
    walked: list[Path] = []
    for p in sorted(root.rglob("*.py")):
        if any(part in _SKIP_DIRS for part in p.relative_to(root).parts[:-1]):
            continue
        rel = p.relative_to(root)
        if exclude and any(fnmatch.fnmatch(rel.as_posix(), pat) for pat in exclude):
            continue
        if include and not any(fnmatch.fnmatch(rel.as_posix(), pat) for pat in include):
            continue
        walked.append(p)
        index_all[module_of(rel)] = rel

    if modules:
        wanted: set[Path] = set()
        for mod in modules:
            rel = index_all.get(mod)
            if rel is None:
                raise SystemExit(f"module not found under {root}: {mod}")
            wanted.add(root / rel)
            prefix = mod + "."
            for m, r in index_all.items():
                if m.startswith(prefix):
                    wanted.add(root / r)
        walked = [p for p in walked if p in wanted]
    return walked


def run_batch(
    input_root: Path,
    output_root: Path,
    jac_bin: Path = _JAC,
    incremental: bool = False,
    report_path: Path | None = None,
    quarantine_path: Path | None = None,
    state_path: Path | None = None,
    include: list[str] | None = None,
    exclude: list[str] | None = None,
    modules: list[str] | None = None,
    converter: Converter | None = None,
) -> dict:
    input_root = input_root.resolve()
    output_root = output_root.resolve()
    report_path = (report_path or output_root / "py2jac_batch.report.json").resolve()
    quarantine_path = (
        quarantine_path or output_root / "py2jac_batch.quarantine.json"
    ).resolve()
    state_path = (state_path or output_root / "py2jac_batch.state.json").resolve()

    files = discover_files(input_root, include or [], exclude or [], modules or [])
    index = build_module_index([f.relative_to(input_root) for f in files])
    rel_index = {k: input_root / v for k, v in index.items()}

    deps: dict[Path, list[Path]] = {}
    hashes: dict[Path, str] = {}
    module_by_path = {input_root / rel: mod for mod, rel in index.items()}
    for f in files:
        deps[f] = extract_deps(f, rel_index, module_by_path[f])
        hashes[f] = hashlib.sha256(f.read_bytes()).hexdigest()

    groups = order_files(files, deps)

    prev_state: dict[str, dict] = {}
    if incremental and state_path.is_file():
        try:
            prev_state = json.loads(state_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            prev_state = {}

    if converter is None:
        converter = default_converter(jac_bin)

    status_by_file: dict[Path, str] = {}
    errors_by_file: dict[Path, str] = {}
    cached_by_file: dict[Path, bool] = {}
    new_state: dict[str, dict] = {}

    def blocked(dep: Path) -> bool:
        return status_by_file.get(dep, "") in ("failed", "skipped-dependency")

    for group in groups:
        group_blocked = any(
            any(blocked(d) for d in deps.get(f, [])) for f in group
        )
        for src in group:
            rel = src.relative_to(input_root)
            key = rel.as_posix()
            if group_blocked:
                status_by_file[src] = "skipped-dependency"
                continue
            entry = prev_state.get(key)
            out_path = output_root / rel.with_suffix(".jac")
            if (
                incremental
                and entry
                and entry.get("sha256") == hashes[src]
                and entry.get("status") == "ok"
                and out_path.is_file()
            ):
                status_by_file[src] = "ok"
                cached_by_file[src] = True
                new_state[key] = entry
                continue
            code, err = converter(src)
            if err is not None:
                status_by_file[src] = "failed"
                errors_by_file[src] = err
                continue
            out_path.parent.mkdir(parents=True, exist_ok=True)
            out_path.write_text(code, encoding="utf-8")
            status_by_file[src] = "ok"
            new_state[key] = {"sha256": hashes[src], "status": "ok"}
        # Mark remaining SCC members skipped once a sibling fails: inside a
        # cycle every member is (transitively) a dependent of every other.
        if group_blocked is False:
            if any(status_by_file[s] == "failed" for s in group) and len(group) > 1:
                for src in group:
                    if status_by_file[src] != "failed":
                        status_by_file[src] = "skipped-dependency"
                        errors_by_file.pop(src, None)

    counts = {"ok": 0, "failed": 0, "skipped-dependency": 0}
    file_rows = []
    for src in sorted(files, key=lambda p: p.relative_to(input_root).as_posix()):
        rel = src.relative_to(input_root)
        status = status_by_file.get(src, "skipped-dependency")
        counts[status] += 1
        row = {
            "source": rel.as_posix(),
            "output": rel.with_suffix(".jac").as_posix()
            if status == "ok"
            else None,
            "status": status,
            "error": errors_by_file.get(src),
            "sha256": hashes[src],
            "deps": [
                d.relative_to(input_root).as_posix() for d in deps.get(src, [])
            ],
        }
        if cached_by_file.get(src):
            row["cached"] = True
        file_rows.append(row)

    report = {
        "tool": "py2jac_batch",
        "input_root": str(input_root),
        "output_root": str(output_root),
        "converter": f"{jac_bin} tool py2jac",
        "counts": counts,
        "total": len(file_rows),
        "files": file_rows,
    }

    output_root.mkdir(parents=True, exist_ok=True)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    quarantined = [
        {
            "source": row["source"],
            "status": row["status"],
            "error": row["error"],
        }
        for row in file_rows
        if row["status"] != "ok"
    ]
    quarantine_doc = {
        "report": report_path.name,
        "counts": {
            "failed": counts["failed"],
            "skipped-dependency": counts["skipped-dependency"],
        },
        "files": quarantined,
    }
    quarantine_path.write_text(
        json.dumps(quarantine_doc, indent=2) + "\n", encoding="utf-8"
    )

    state_path.parent.mkdir(parents=True, exist_ok=True)
    state_path.write_text(json.dumps(new_state, indent= 2) + "\n", encoding="utf-8")

    print(
        f"py2jac_batch: {counts['ok']} ok, {counts['failed']} failed, "
        f"{counts['skipped-dependency']} skipped-dependency "
        f"(total {len(file_rows)})"
    )
    print(f"report -> {report_path}")
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_dir", type=Path, help="root of the Python tree")
    parser.add_argument(
        "-o", "--output-dir", type=Path, required=True, help=".jac output root"
    )
    parser.add_argument(
        "--incremental",
        action="store_true",
        help="skip files whose source hash and prior status are unchanged",
    )
    parser.add_argument("--report", type=Path, help="aggregate report JSON path")
    parser.add_argument(
        "--quarantine", type=Path, help="quarantine sidecar JSON path"
    )
    parser.add_argument("--state", type=Path, help="incremental state JSON path")
    parser.add_argument(
        "--module",
        action="append",
        default=[],
        dest="modules",
        help="restrict to these modules (repeatable, includes submodules)",
    )
    parser.add_argument(
        "--include",
        action="append",
        default=[],
        help="glob patterns (posix relpath) to include (repeatable)",
    )
    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        help="glob patterns (posix relpath) to exclude (repeatable)",
    )
    parser.add_argument("--jac", type=Path, default=_JAC, help="jac binary")
    args = parser.parse_args(argv)

    if not args.input_dir.is_dir():
        print(f"py2jac_batch: not a directory: {args.input_dir}", file=sys.stderr)
        return 1
    if not args.jac.is_file():
        print(f"py2jac_batch: missing jac binary: {args.jac}", file=sys.stderr)
        return 1

    run_batch(
        input_root=args.input_dir,
        output_root=args.output_dir,
        jac_bin=args.jac,
        incremental=args.incremental,
        report_path=args.report,
        quarantine_path=args.quarantine,
        state_path=args.state,
        include=args.include,
        exclude=args.exclude,
        modules=args.modules,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
