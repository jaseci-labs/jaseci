#!/usr/bin/env bash
# A PR that touches jac/jaclang/scale/** must say how it was validated.
#
# TESTING.md section 4 asks for three things in the PR body: the suites run,
# by file, with counts; what was exercised by hand and where; and what was
# NOT run, stated plainly. This check looks for a "Validation" heading and a
# "not run" statement. Seeded as a warning; #8896 phase 5 makes it fail.
#
# Env: PR_BODY (the pull request description). Changed files come from the
# same diff logic as check-release-notes.sh.
set -euo pipefail

if [ -n "${PRE_COMMIT_FROM_REF:-}" ] && [ -n "${PRE_COMMIT_TO_REF:-}" ]; then
    CHANGED_FILES=$(git diff --name-only "$PRE_COMMIT_FROM_REF"..."$PRE_COMMIT_TO_REF" 2>/dev/null || true)
elif [ "${CI:-}" = "true" ]; then
    MERGE_BASE=$(git merge-base origin/main HEAD 2>/dev/null || echo "")
    if [ -z "$MERGE_BASE" ]; then
        git fetch --depth=200 origin main >/dev/null 2>&1 || true
        MERGE_BASE=$(git merge-base origin/main HEAD 2>/dev/null || echo "")
    fi
    CHANGED_FILES=$(git diff --name-only "$MERGE_BASE"...HEAD 2>/dev/null || true)
else
    CHANGED_FILES=$(git diff --cached --name-only 2>/dev/null || true)
fi

SCALE_TOUCHED=$(printf '%s\n' "$CHANGED_FILES" | grep -E '^jac/jaclang/scale/' || true)
if [ -z "$SCALE_TOUCHED" ]; then
    echo "No jac/jaclang/scale changes; validation section not required."
    exit 0
fi

BODY="${PR_BODY:-}"
if [ -z "$BODY" ]; then
    echo "::warning::No PR body available to check for a validation section."
    exit 0
fi

MISSING=()
if ! printf '%s\n' "$BODY" | grep -qiE '^#+[[:space:]]*validation'; then
    MISSING+=("a '## Validation' heading (suites run by file with counts, and what was exercised by hand)")
fi
if ! printf '%s\n' "$BODY" | grep -qiE 'not run|did not run|was not run|nothing else (was )?run'; then
    MISSING+=("a plain statement of what was NOT run")
fi

if [ ${#MISSING[@]} -eq 0 ]; then
    echo "Validation section present for a scale change."
    exit 0
fi

echo "::warning::This PR changes jac/jaclang/scale but its description is missing:"
for m in "${MISSING[@]}"; do
    echo "::warning::  - $m"
done
echo "::warning::See jac/jaclang/scale/tests/TESTING.md section 4. This becomes a failure in #8896 phase 5."
exit 0
