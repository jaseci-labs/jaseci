#!/usr/bin/env bash
# Real-cluster e2e for KubernetesAutoscalerObserver target correlation on
# jac-scale's actual gateway/microservice deploy shape.
#
# Creates a real Deployment named "<app>-deployment" (labelled app=<app>,
# since that label doubles as its pod selector) and applies a real
# KEDA ScaledObject targeting it via the real KEDAAutoscaler.apply(), the
# same code path target.jac:_autoscaler_spec drives for every jac-scale
# service. Then runs the real KubernetesAutoscalerObserver and asserts its
# _target_cache has exactly one fully populated slot for that target.
#
# Before a0e5c2213 this failed: the observer correlated all three resource
# kinds by the `app` label, and KEDA's own generated HPA/ScaledObject carry
# "<app>-deployment" there while the Deployment itself carries the bare
# "<app>" -- so the join could never complete for jac-scale's own primary
# deploy shape. Requires KEDA core already installed on the target cluster
# (this script does not install it).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../../.." && pwd)"
DRIVER="${REPO_ROOT}/jac/jaclang/scale/tests/deploy/keda_gateway_correlation_verify.jac"
if [ ! -f "${DRIVER}" ]; then
    echo "FAIL: driver script not found at ${DRIVER}" >&2
    exit 1
fi

export KEDA_GW_CORR_E2E_NAMESPACE="${KEDA_GW_CORR_E2E_NAMESPACE:-jac-gw-corr-e2e}"
export KEDA_GW_CORR_E2E_APP="${KEDA_GW_CORR_E2E_APP:-gateway}"
export KEDA_GW_CORR_E2E_OBSERVE_TIMEOUT="${KEDA_GW_CORR_E2E_OBSERVE_TIMEOUT:-60}"
NAMESPACE="${KEDA_GW_CORR_E2E_NAMESPACE}"
DEPLOYMENT="${KEDA_GW_CORR_E2E_APP}-deployment"
DELETE_TIMEOUT="${DELETE_TIMEOUT:-120}"

echo "=== preflight: KEDA core CRDs ==="
if ! kubectl get crd scaledobjects.keda.sh >/dev/null 2>&1; then
    echo "FAIL: scaledobjects.keda.sh CRD not found on cluster." >&2
    echo "Install KEDA core first, e.g.:" >&2
    echo "  helm repo add kedacore https://kedacore.github.io/charts && helm repo update" >&2
    echo "  helm install keda kedacore/keda -n keda --create-namespace --wait" >&2
    exit 1
fi

dump_state() {
    echo "--- diagnostics (namespace=${NAMESPACE}) ---"
    kubectl get deployment,scaledobject,hpa -n "${NAMESPACE}" -o wide || true
    kubectl describe deployment "${DEPLOYMENT}" -n "${NAMESPACE}" || true
    kubectl describe scaledobject -n "${NAMESPACE}" || true
    kubectl get events -n "${NAMESPACE}" --sort-by=.lastTimestamp || true
}

cleanup() {
    rc="${1:-0}"
    echo "=== cleanup (rc=${rc}) ==="
    if [ "${rc}" != "0" ] && [ "${E2E_KEEP_NS_ON_FAIL:-1}" = "1" ]; then
        echo "=== e2e failed (rc=${rc}); KEEPING namespace '${NAMESPACE}' for inspection (set E2E_KEEP_NS_ON_FAIL=0 to force cleanup) ==="
        return
    fi
    (cd "${REPO_ROOT}/jac" && jac run "${DRIVER}" teardown) || true
    kubectl delete namespace "${NAMESPACE}" --ignore-not-found --timeout="${DELETE_TIMEOUT}s" || true
}
trap 'cleanup "$?"' EXIT

_T0=$(date +%s)
_t() { echo "[TIMING +$(( $(date +%s) - _T0 ))s] $1"; }

_t "apply target (Deployment + ScaledObject) start"
echo "=== apply the real Deployment + ScaledObject via KEDAAutoscaler.apply ==="
if ! (cd "${REPO_ROOT}/jac" && jac run "${DRIVER}" apply); then
    echo "FAIL: apply errored" >&2
    dump_state
    exit 1
fi

_t "wait for KEDA to generate the HPA"
echo "=== confirm KEDA generated its HPA for the ScaledObject ==="
elapsed=0
while [ "${elapsed}" -lt 60 ]; do
    if kubectl get hpa -n "${NAMESPACE}" -o jsonpath='{.items[0].metadata.name}' >/dev/null 2>&1; then
        break
    fi
    sleep 2
    elapsed=$(( elapsed + 2 ))
done
kubectl get deployment,scaledobject,hpa -n "${NAMESPACE}" -o wide || true

_t "observe and assert correlation"
echo "=== run the real KubernetesAutoscalerObserver and assert one joined _target_cache slot ==="
if ! (cd "${REPO_ROOT}/jac" && jac run "${DRIVER}" observe); then
    echo "FAIL: target correlation did not hold -- see output above" >&2
    dump_state
    exit 1
fi

_t "ALL DONE"
echo "=== KEDA gateway correlation REAL e2e PASSED ==="
