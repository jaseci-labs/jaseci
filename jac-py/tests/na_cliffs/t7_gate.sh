#!/usr/bin/env bash
# T7 na-clean compile gate (local). Each cliff fixture must nacompile through
# capability-check + IR-gen + object-emit with no E5090 and no ICE. The final
# static-musl link is expected to fail locally (env, not code) -- reaching
# "Object code emitted" is the pass condition here. Full link+run is the CI leg.
#
# Usage: PYTHONPATH=jac .venv/bin/python ... is wrapped below; run from repo root:
#   bash jac-py/tests/na_cliffs/t7_gate.sh
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2
PY="${JACPY:-.venv/bin/python}"
fail=0
for f in jac-py/tests/na_cliffs/cliff_*.na.jac; do
    out=$(PYTHONPATH=jac "$PY" -m jaclang nacompile "$f" -o /tmp/t7_$(basename "$f").o 2>&1)
    if echo "$out" | grep -q "E5090"; then
        echo "FAIL (E5090 native-incompatible): $f"; fail=1
    elif echo "$out" | grep -qiE "Traceback|Assertion|Internal error|panic"; then
        echo "FAIL (compiler ICE): $f"; fail=1
    elif echo "$out" | grep -q "Object code emitted"; then
        echo "PASS (object emitted): $f"
    else
        echo "UNKNOWN (no object emit, no E5090 -- inspect): $f"; fail=1
    fi
done
exit $fail
