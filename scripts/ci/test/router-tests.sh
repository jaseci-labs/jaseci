#!/usr/bin/env bash
# Fast safety tests for the CI router (no jac build required).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CLASSIFY="${ROOT}/scripts/ci/classify-changed-files.sh"

assert_json() {
  python3 -c "import json,sys; json.loads(sys.argv[1])" "$1"
}

selected_contains() {
  python3 - "$1" "$2" <<'PY'
import json, sys
data = json.loads(sys.argv[1])
jobs = set(data["selected_jobs"])
print("yes" if sys.argv[2] in jobs else "no")
PY
}

json_field() {
  python3 -c "import json,sys; print(json.loads(sys.argv[1])[sys.argv[2]])" "$1" "$2"
}

run_paths() {
  printf '%s\0' "$@" | "$CLASSIFY" 2>/dev/null | tail -1
}

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

# Representative allowlist paths
docs=$(run_paths 'jac/jaclang/cli/docs/foo.md')
assert_json "$docs"
[ "$(json_field "$docs" full_ci)" = "False" ] || fail docs full_ci
[ "$(selected_contains "$docs" test-docs)" = "yes" ] || fail docs test-docs
pass "docs path"

scale=$(run_paths 'jac/jaclang/scale/server/foo.jac')
[ "$(selected_contains "$scale" test-scale)" = "yes" ] || fail scale test-scale
[ "$(selected_contains "$scale" test-scale-k8s)" = "no" ] || fail scale should not auto-k8s
[ "$(selected_contains "$scale" test-jac-site-smoke)" = "yes" ] || fail scale jac-site-smoke
pass "scale path without k8s"

k8s=$(run_paths 'jac/jaclang/scale/tests/deploy/foo.jac')
[ "$(selected_contains "$k8s" test-scale-k8s)" = "yes" ] || fail k8s deploy
pass "scale k8s path"

# Launcher-only change scopes to test-launcher (leaf build-time dep), not full CI.
launcher=$(run_paths 'jac/launcher/main.zig')
[ "$(json_field "$launcher" full_ci)" = "False" ] || fail launcher full_ci
[ "$(selected_contains "$launcher" test-launcher)" = "yes" ] || fail launcher test-launcher
[ "$(selected_contains "$launcher" test-client)" = "no" ] || fail launcher should not pull in test-client
[ "$(selected_contains "$launcher" test-precompile)" = "no" ] || fail launcher should not pull in test-precompile
pass "launcher-only path"

# Native-only change scopes to the native cross lanes + Linux codegen shard.
native=$(run_paths 'jac/native/shim.c')
[ "$(json_field "$native" full_ci)" = "False" ] || fail native full_ci
[ "$(selected_contains "$native" test-native-macos)" = "yes" ] || fail native macos
[ "$(selected_contains "$native" test-native-aarch64)" = "yes" ] || fail native aarch64
[ "$(selected_contains "$native" test-compiler-passes-native)" = "yes" ] || fail native linux codegen
[ "$(selected_contains "$native" test-launcher)" = "no" ] || fail native should not pull in launcher
pass "native-only path"

# compiler/jac0core stay full CI -- they ripple across every lane and are NOT
# narrowable. Guards against re-introducing the dead conditional_jobs.
compiler=$(run_paths 'jac/jaclang/compiler/passes/main/foo.jac')
[ "$(json_field "$compiler" full_ci)" = "True" ] || fail compiler should stay full CI
jac0core=$(run_paths 'jac/jaclang/jac0core/x.jac')
[ "$(json_field "$jac0core" full_ci)" = "True" ] || fail jac0core should stay full CI
publish=$(run_paths 'jac/jaclang/publish/x.jac')
[ "$(json_field "$publish" full_ci)" = "True" ] || fail publish should stay full CI
pass "central-hub paths stay full CI"

# launcher mixed with another allowlist category → full CI (mixing escalates).
launcher_mixed=$(run_paths 'jac/launcher/main.zig' 'jac/jaclang/cli/docs/x.md')
[ "$(json_field "$launcher_mixed" full_ci)" = "True" ] || fail launcher+docs mixed should be full CI
pass "launcher mixed category escalates"

# build.zig / build.zig.zon stayed full_ci (must not be narrowed with launcher).
bz=$(run_paths 'jac/build.zig')
[ "$(json_field "$bz" full_ci)" = "True" ] || fail build.zig should stay full CI
pass "build.zig stays full CI"

# CI-only changes escalate to full_ci but must not pull installer-test (tests the
# live release binary; only scripts/install.sh should select it on PRs).
ci_only=$(run_paths '.github/workflows/ci.yml')
[ "$(json_field "$ci_only" full_ci)" = "True" ] || fail ci-only full_ci
[ "$(selected_contains "$ci_only" installer-test)" = "no" ] || fail ci-only installer-test
pass "ci-only path excludes installer-test"

install=$(run_paths 'scripts/install.sh')
[ "$(selected_contains "$install" installer-test)" = "yes" ] || fail install.sh installer-test
pass "install.sh selects installer-test"

# Unknown path → full CI + audit_fail
unknown=$(run_paths 'mystery-root/foo.txt' || true)
[ "$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d['full_ci'], d['audit_fail'])" "$unknown")" = "True True" ] || fail unknown  # two fields
pass "unknown path fail-closed"

# Mixed allowlist categories → full CI
mixed=$(run_paths 'release_notes/x.md' 'jac/jaclang/byllm/foo.jac')
[ "$(json_field "$mixed" mixed_categories)" = "True" ] || fail mixed
[ "$(json_field "$mixed" full_ci)" = "True" ] || fail mixed full
pass "mixed categories"

# Test-only shard
test_only=$(run_paths 'jac/tests/compiler/passes/main/test_foo.jac')
[ "$(selected_contains "$test_only" test-compiler-passes-main)" = "yes" ] || fail test shard
[ "$(json_field "$test_only" full_ci)" = "False" ] || fail test-only full
pass "test-only shard"

# Full mode selects every manifest job
full=$(scripts/ci/classify-changed-files.sh --mode full 2>/dev/null | tail -1)
count=$(python3 -c "import json,sys; print(len(json.loads(sys.argv[1])['selected_jobs']))" "$full")
[ "$count" -ge 25 ] || fail "full mode job count $count"
pass "full mode"

# Manifest/workflow sync + shard inventory run as dedicated coverage-audit
# steps in CI; skip the duplicate invocation here so they don't run twice.
if [ "${GITHUB_ACTIONS:-}" != "true" ]; then
  "${ROOT}/scripts/ci/check-ci-coverage.sh"
  pass "manifest sync"

  "${ROOT}/scripts/ci/verify-shard-inventory.sh"
  pass "shard inventory"
else
  pass "manifest sync (skipped: dedicated CI step)"
  pass "shard inventory (skipped: dedicated CI step)"
fi

# Validate expected jobs helper
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT
python3 - "$TMPDIR_TEST" <<'PY'
import json, subprocess, sys, os
d = sys.argv[1]
selected = ["test-docs", "build-jac"]
needs = {"test-docs": {"result": "success"}, "test-scale": {"result": "skipped"}}
s = os.path.join(d, "s.json"); n = os.path.join(d, "n.json")
open(s, "w").write(json.dumps(selected))
open(n, "w").write(json.dumps(needs))
subprocess.check_call(["scripts/ci/validate-expected-jobs.sh", s, n, "pr"])
needs["test-docs"]["result"] = "skipped"
open(n, "w").write(json.dumps(needs))
try:
    subprocess.check_call(["scripts/ci/validate-expected-jobs.sh", s, n, "pr"])
    raise SystemExit("expected validation failure")
except subprocess.CalledProcessError:
    pass
print("validate unexpected skip ok")
PY
pass "validate-expected-jobs"

# Aggregate gate must be event-aware: jobs the workflow structurally skips on
# a given event (declared in ci-coverage.yml) must not turn full mode red.
python3 - "$TMPDIR_TEST" <<'PY'
import json, os, subprocess, sys

d = sys.argv[1]
s = os.path.join(d, "s.json")
n = os.path.join(d, "n.json")
open(s, "w").write(json.dumps([]))  # full mode ignores `selected`

base = ["test-docs", "test-scale", "k8s-real-e2e", "installer-test"]
ok = {j: "success" for j in base}

def run(mode, event, results):
    open(n, "w").write(json.dumps({j: {"result": r} for j, r in results.items()}))
    return subprocess.run(
        ["scripts/ci/validate-expected-jobs.sh", s, n, mode, event],
        capture_output=True, text=True,
    )

def expect_ok(label, **kw):
    r = run(**kw)
    assert r.returncode == 0, f"{label}: expected pass\n{r.stdout}"

def expect_fail(label, **kw):
    r = run(**kw)
    assert r.returncode != 0, f"{label}: expected fail"

# Reported P0: full mode on push tolerates the two structural skips.
expect_ok("push tolerates installer+k8s skip", mode="full", event="push",
          results={**ok, "installer-test": "skipped", "k8s-real-e2e": "skipped"})

# Fail-closed: a non-excluded job skipped on push still fails.
expect_fail("push fails on non-excluded skip", mode="full", event="push",
            results={**ok, "installer-test": "skipped", "test-docs": "skipped"})

# merge_group only excludes installer-test; k8s-real-e2e runs there.
expect_ok("merge_group tolerates installer skip", mode="full", event="merge_group",
          results={**ok, "installer-test": "skipped"})
expect_fail("merge_group fails on k8s skip", mode="full", event="merge_group",
            results={**ok, "installer-test": "skipped", "k8s-real-e2e": "skipped"})

# schedule mirrors merge_group for installer-test.
expect_ok("schedule tolerates installer skip", mode="full", event="schedule",
          results={**ok, "installer-test": "skipped"})

# Guard for the original bug: with no event, full mode stays strict.
expect_fail("full without event is strict", mode="full", event="",
            results={**ok, "installer-test": "skipped", "k8s-real-e2e": "skipped"})

print("event-aware aggregate gate ok")
PY
pass "event-aware full-mode gate"

# skip-k8s label: router may select k8s jobs but workflow skips them.
python3 - "$TMPDIR_TEST" <<'PY'
import json, os, subprocess, sys

d = sys.argv[1]
s = os.path.join(d, "s.json")
n = os.path.join(d, "n.json")
selected = ["test-scale-k8s", "k8s-real-e2e", "test-scale"]
open(s, "w").write(json.dumps(selected))
open(n, "w").write(json.dumps({
    "test-scale": {"result": "success"},
    "test-scale-k8s": {"result": "skipped"},
    "k8s-real-e2e": {"result": "skipped"},
}))
r = subprocess.run(
    ["scripts/ci/validate-expected-jobs.sh", s, n, "pr", "pull_request", '["skip-k8s"]'],
    capture_output=True, text=True,
)
assert r.returncode == 0, f"skip-k8s should tolerate k8s skips\n{r.stdout}\n{r.stderr}"
open(n, "w").write(json.dumps({
    "test-scale": {"result": "success"},
    "test-scale-k8s": {"result": "skipped"},
    "k8s-real-e2e": {"result": "skipped"},
}))
r = subprocess.run(
    ["scripts/ci/validate-expected-jobs.sh", s, n, "pr", "pull_request", ""],
    capture_output=True, text=True,
)
assert r.returncode != 0, "without skip-k8s label k8s skips must fail"
print("skip-k8s label gate ok")
PY
pass "skip-k8s label aggregate gate"

# check-ci-coverage must reject a bad event_excluded_jobs entry (fail-closed).
BAD_DIR="$(mktemp -d)"
BAD_MANIFEST="$BAD_DIR/bad.yml"
cp scripts/ci/ci-coverage.yml "$BAD_MANIFEST"
python3 - "$BAD_MANIFEST" <<'PY'
import sys, yaml
from pathlib import Path
p = Path(sys.argv[1])
m = yaml.safe_load(p.read_text())
m.setdefault("event_excluded_jobs", {})      # bad job name ...
m["event_excluded_jobs"]["push"] = ["nonexistent-job"]
m["event_excluded_jobs"]["totally-fake-event"] = ["installer-test"]   # ... and bad event
p.write_text(yaml.safe_dump(m, sort_keys=False))
PY
if scripts/ci/check-ci-coverage.sh "$BAD_MANIFEST" .github/workflows/ci.yml >/dev/null 2>&1; then
  fail "check-ci-coverage accepted unknown event_excluded job/event"
fi
pass "coverage rejects unknown event_excluded job/event"

# event_excluded_jobs must match each job's structural `if:` gate in ci.yml.
python3 - <<'PY'
import re, sys, yaml
from pathlib import Path

manifest = yaml.safe_load(Path("scripts/ci/ci-coverage.yml").read_text())
workflow = yaml.safe_load(Path(".github/workflows/ci.yml").read_text())
excluded = manifest.get("event_excluded_jobs", {}) or {}
jobs = workflow.get("jobs", {})

def normalize_if(expr: str) -> str:
    return re.sub(r"\s+", " ", expr.strip())

def structurally_excluded(if_clause: str, event: str) -> bool:
    expr = normalize_if(if_clause)
    expr = re.sub(r"!contains\([^)]+\)", "True", expr)
    expr = re.sub(r"contains\([^)]+\)", "False", expr)
    expr = re.sub(
        r"needs\.ci-router\.outputs\.\w+ == 'true'", "True", expr, flags=re.I
    )
    expr = re.sub(
        r"github\.event_name == '(\w+)'",
        lambda m: repr(m.group(1) == event),
        expr,
    )
    expr = re.sub(
        r"github\.event_name != '(\w+)'",
        lambda m: repr(m.group(1) != event),
        expr,
    )
    expr = expr.replace("||", " or ").replace("&&", " and ")
    try:
        return not bool(eval(expr, {"__builtins__": {}}, {}))
    except Exception as exc:
        raise AssertionError(f"cannot parse if: {if_clause!r}: {exc}") from exc

errors = []
for event, job_list in excluded.items():
    for job in job_list:
        job_def = jobs.get(job)
        if not job_def:
            errors.append(f"{job}: missing from ci.yml")
            continue
        if_clause = job_def.get("if")
        if not if_clause:
            errors.append(f"{job}: no if: gate but listed under {event}")
            continue
        if not structurally_excluded(if_clause, event):
            errors.append(
                f"{job}: if: gate does not structurally exclude event {event!r}"
            )

if errors:
    print("event_excluded_jobs / ci.yml if: parity failures:", file=sys.stderr)
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)
print("event_excluded_jobs parity ok")
PY
pass "event_excluded_jobs matches ci.yml if: gates"

# pr_label_skips must match each job's label `if:` gate in ci.yml.
python3 - <<'PY'
import re, sys, yaml
from pathlib import Path

manifest = yaml.safe_load(Path("scripts/ci/ci-coverage.yml").read_text())
workflow = yaml.safe_load(Path(".github/workflows/ci.yml").read_text())
label_skips = manifest.get("pr_label_skips", {}) or {}
jobs = workflow.get("jobs", {})

LABEL_CONTAINS = re.compile(
    r"contains\(github\.event\.pull_request\.labels\.\*\.name, '([^']+)'\)"
)


def normalize_if(expr: str) -> str:
    return re.sub(r"\s+", " ", expr.strip())


def structurally_label_skipped(if_clause: str, label: str) -> bool:
    """Job must not run on pull_request when the label is present."""
    expr = normalize_if(if_clause)
    expr = re.sub(
        rf"!contains\(github\.event\.pull_request\.labels\.\*\.name, '{label}'\)",
        "False",
        expr,
    )
    expr = re.sub(
        rf"contains\(github\.event\.pull_request\.labels\.\*\.name, '{label}'\)",
        "True",
        expr,
    )
    expr = re.sub(r"!contains\([^)]+\)", "True", expr)
    expr = re.sub(r"contains\([^)]+\)", "False", expr)
    expr = re.sub(
        r"needs\.ci-router\.outputs\.\w+ == 'true'", "True", expr, flags=re.I
    )
    expr = re.sub(r"github\.event_name == 'pull_request'", "True", expr)
    expr = re.sub(r"github\.event_name != 'pull_request'", "False", expr)
    expr = re.sub(
        r"github\.event_name == '(\w+)'",
        lambda m: repr(m.group(1) == "pull_request"),
        expr,
    )
    expr = re.sub(
        r"github\.event_name != '(\w+)'",
        lambda m: repr(m.group(1) != "pull_request"),
        expr,
    )
    expr = expr.replace("||", " or ").replace("&&", " and ")
    try:
        return not bool(eval(expr, {"__builtins__": {}}, {}))
    except Exception as exc:
        raise AssertionError(f"cannot parse if: {if_clause!r}: {exc}") from exc

errors = []

for job_name, job_def in jobs.items():
    if_clause = job_def.get("if")
    if not if_clause:
        continue
    for match in LABEL_CONTAINS.finditer(if_clause):
        label = match.group(1)
        if label not in label_skips:
            errors.append(
                f"{job_name}: if: references label {label!r} but pr_label_skips has no entry"
            )
            continue
        if job_name not in label_skips[label]:
            errors.append(
                f"{job_name}: if: skips on label {label!r} but not listed under pr_label_skips"
            )

for label, job_list in label_skips.items():
    for job in job_list:
        job_def = jobs.get(job)
        if not job_def:
            errors.append(f"{job}: missing from ci.yml")
            continue
        if_clause = job_def.get("if")
        if not if_clause:
            errors.append(f"{job}: no if: gate but listed under pr_label_skips[{label!r}]")
            continue
        if f"'{label}'" not in if_clause:
            errors.append(
                f"{job}: if: gate does not reference label {label!r}"
            )
            continue
        if not structurally_label_skipped(if_clause, label):
            errors.append(
                f"{job}: if: gate does not structurally skip when label {label!r} is present"
            )

if errors:
    print("pr_label_skips / ci.yml if: parity failures:", file=sys.stderr)
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)
print("pr_label_skips parity ok")
PY
pass "pr_label_skips matches ci.yml if: gates"

echo "All router tests passed."
