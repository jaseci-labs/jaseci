#!/usr/bin/env bash
# Ensure compiler/runtime shard directories cover all test files (no omissions).
# Shard layout is defined in scripts/ci/ci-coverage.yml (compiler_shards, runtime_shards).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="${ROOT}/scripts/ci/ci-coverage.yml"

python3 - "$ROOT" "$MANIFEST" <<'PY'
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    raise SystemExit("PyYAML required")

root = Path(sys.argv[1])
manifest_path = Path(sys.argv[2])
manifest = yaml.safe_load(manifest_path.read_text())
jac = root / "jac"


def resolve(rel: str) -> Path:
    return jac / rel


def test_files(base: Path) -> set[Path]:
    if not base.exists():
        return set()
    return {
        p
        for p in base.rglob("test_*.jac")
        if "fixtures" not in p.parts
    }


def collect_shard_files(cfg: dict) -> set[Path]:
    found: set[Path] = set()
    for rel in cfg.get("paths", []):
        found |= test_files(resolve(rel))
    for rel in cfg.get("ignore", []):
        ignore_path = resolve(rel)
        found = {
            p
            for p in found
            if ignore_path not in p.parents and p.parent != ignore_path
        }
    for rel in cfg.get("ignore_cli_docs", []):
        found.discard(resolve(rel))
    return found


compiler_shards = manifest.get("compiler_shards", {})
runtime_shards = manifest.get("runtime_shards", {})

if not compiler_shards:
    raise SystemExit("::error::compiler_shards missing from ci-coverage.yml")
if not runtime_shards:
    raise SystemExit("::error::runtime_shards missing from ci-coverage.yml")

compiler_all: set[Path] = set()
for cfg in compiler_shards.values():
    for rel in cfg.get("paths", []):
        compiler_all |= test_files(resolve(rel))

compiler_covered: set[Path] = set()
for name, cfg in compiler_shards.items():
    shard_files = collect_shard_files(cfg)
    overlap = compiler_covered & shard_files
    if overlap:
        sample = sorted(overlap)[:3]
        raise SystemExit(
            f"::error::Compiler shard {name} overlaps prior shards, e.g. {sample}"
        )
    compiler_covered |= shard_files

runtime_all: set[Path] = set()
for cfg in runtime_shards.values():
    for rel in cfg.get("paths", []):
        runtime_all |= test_files(resolve(rel))

# Subtract paths owned by other jobs (test-client, test-docs), declared in runtime_shards.
inventory_exclude: set[Path] = set()
for cfg in runtime_shards.values():
    for rel in cfg.get("ignore", []):
        inventory_exclude |= test_files(resolve(rel))
    for rel in cfg.get("ignore_cli_docs", []):
        inventory_exclude.add(resolve(rel))
runtime_all -= inventory_exclude

runtime_covered: set[Path] = set()
for name, cfg in runtime_shards.items():
    shard_files = collect_shard_files(cfg)
    overlap = runtime_covered & shard_files
    if overlap:
        sample = sorted(overlap)[:3]
        raise SystemExit(
            f"::error::Runtime shard {name} overlaps prior shards, e.g. {sample}"
        )
    runtime_covered |= shard_files

errors = []
if compiler_all != compiler_covered:
    missing = sorted(compiler_all - compiler_covered)
    extra = sorted(compiler_covered - compiler_all)
    if missing:
        errors.append(f"Compiler shard missing {len(missing)} tests, e.g. {missing[:3]}")
    if extra:
        errors.append(f"Compiler shard extra {len(extra)} tests, e.g. {extra[:3]}")

if runtime_all != runtime_covered:
    missing = sorted(runtime_all - runtime_covered)
    if missing:
        errors.append(f"Runtime shard missing {len(missing)} tests, e.g. {missing[:3]}")

print(f"Compiler inventory: {len(compiler_all)} test files across {len(compiler_shards)} shards")
print(
    f"Runtime inventory (excl. client, docs): {len(runtime_all)} test files "
    f"across {len(runtime_shards)} shards"
)

if errors:
    for e in errors:
        print(f"::error::{e}")
    raise SystemExit(1)

print("Shard inventory complete.")
PY
