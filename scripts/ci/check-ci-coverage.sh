#!/usr/bin/env bash
# Verify ci-coverage.yml stays synchronized with .github/workflows/ci.yml.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Optional overrides let router-tests feed in a mutated manifest for the
# fail-closed negative case on event_excluded_jobs.
MANIFEST="${1:-${ROOT}/scripts/ci/ci-coverage.yml}"
WORKFLOW="${2:-${ROOT}/.github/workflows/ci.yml}"

python3 - "$MANIFEST" "$WORKFLOW" <<'PY'
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    raise SystemExit("PyYAML required")

manifest_path = Path(sys.argv[1])
workflow_path = Path(sys.argv[2])
manifest = yaml.safe_load(manifest_path.read_text())
workflow_data = yaml.safe_load(workflow_path.read_text())
workflow_jobs = set(workflow_data.get("jobs", {}).keys())

metadata = set(manifest.get("metadata_jobs", []))
manifest_jobs = set(manifest.get("jobs", []))
expected = manifest_jobs | metadata | set(manifest.get("always_run_jobs", []))
missing_in_manifest = sorted(workflow_jobs - expected)
missing_in_workflow = sorted(manifest_jobs - workflow_jobs)

errors = []
if missing_in_manifest:
    errors.append(
        "Workflow jobs missing from manifest: " + ", ".join(missing_in_manifest)
    )
if missing_in_workflow:
    errors.append(
        "Manifest jobs missing from workflow: " + ", ".join(missing_in_workflow)
    )

# everything-passed needs must include every non-metadata job.
needs = set(workflow_data.get("jobs", {}).get("everything-passed", {}).get("needs", []))
gate_missing = sorted((workflow_jobs - metadata) - needs)
if gate_missing:
    errors.append(
        "everything-passed missing needs for: " + ", ".join(gate_missing)
    )

# ci-router must expose run_<job> for every routable manifest job.
# jac-check always runs independently (no router gate).
def job_to_run_output(job: str) -> str:
    return f"run_{job.replace('-', '_')}"

always_run = set(manifest.get("always_run_jobs", []))
routable_jobs = manifest_jobs - always_run - {"jac-check"}
router_outputs = set(
    workflow_data.get("jobs", {}).get("ci-router", {}).get("outputs", {}).keys()
)
router_metadata = {"full_ci", "audit_fail", "unknown", "selected_jobs"}
router_job_outputs = router_outputs - router_metadata

expected_outputs = {job_to_run_output(j) for j in routable_jobs}
missing_router = sorted(expected_outputs - router_job_outputs)
extra_router = sorted(router_job_outputs - expected_outputs)
if missing_router:
    errors.append(
        "ci-router missing run_* outputs for: " + ", ".join(missing_router)
    )
if extra_router:
    errors.append(
        "ci-router has run_* outputs with no manifest job: " + ", ".join(extra_router)
    )

# event_excluded_jobs: every job must exist in `jobs` and every event must be
# a real workflow trigger. PyYAML parses the bare `on:` key as boolean True.
event_excluded = manifest.get("event_excluded_jobs", {}) or {}
on_field = workflow_data.get("on")
if on_field is None:
    on_field = workflow_data.get(True)
triggers = set(on_field.keys()) if isinstance(on_field, dict) else set(on_field or [])
referenced = {j for jobs in event_excluded.values() for j in jobs}
bad_jobs = sorted(referenced - manifest_jobs)
bad_events = sorted(set(event_excluded) - triggers)
if bad_jobs:
    errors.append("event_excluded_jobs lists unknown jobs: " + ", ".join(bad_jobs))
if bad_events:
    errors.append("event_excluded_jobs lists unknown events: " + ", ".join(bad_events))

full_ci_excluded = set(manifest.get("full_ci_excluded_jobs", []))
bad_excluded = sorted(full_ci_excluded - manifest_jobs)
if bad_excluded:
    errors.append(
        "full_ci_excluded_jobs lists unknown jobs: " + ", ".join(bad_excluded)
    )

if errors:
    for e in errors:
        print(f"::error::{e}")
    raise SystemExit(1)

print("CI manifest and workflow are synchronized.")
PY
