#!/usr/bin/env bash
# Real-cluster e2e for destroy reclamation (#7968).
#
# Scenario A (owned namespace): jac-scale creates the namespace, so destroy
# reclaims it along with the postgres StatefulSet and every app PVC.
#
# Scenario B (adopted namespace): the namespace already existed, so destroy
# removes the app's own resources and leaves the namespace and any foreign
# workload in it untouched.
#
# Requires a reachable cluster (kind/minikube/microk8s/EKS) on the current
# kubeconfig context and the scale deploy deps installed for `jac`.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../../.." && pwd)"
DRIVER="${REPO_ROOT}/jac/jaclang/scale/tests/deploy/sdk_deploy_driver.jac"
APP_SRC="${REPO_ROOT}/jac/examples/todo_app"
if [ ! -f "${DRIVER}" ] || [ ! -f "${APP_SRC}/main.jac" ]; then
    echo "FAIL: driver or todo_app fixture not found" >&2
    exit 1
fi

OWNER_LABEL="jac-scale.jaseci.org/owned-by"
OWNED_NS="${OWNED_NS:-jac-destroy-owned}"
ADOPTED_NS="${ADOPTED_NS:-jac-destroy-adopted}"
APP="${DESTROY_E2E_APP_NAME:-destroy-todo}"
SENTINEL="foreign-workload"

CLUSTER_TYPE="${CLUSTER_TYPE:-kind}"
case "${CLUSTER_TYPE}" in
    microk8s) STORAGE_CLASS="${DESTROY_E2E_STORAGE_CLASS-microk8s-hostpath}" ;;
    minikube) STORAGE_CLASS="${DESTROY_E2E_STORAGE_CLASS-standard}" ;;
    kind)     STORAGE_CLASS="${DESTROY_E2E_STORAGE_CLASS-jac-destroy-rwx}" ;;
    *)        STORAGE_CLASS="${DESTROY_E2E_STORAGE_CLASS-}" ;;
esac

ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-600s}"
NS_DELETE_WAIT="${NS_DELETE_WAIT:-300}"
APP_DIR=""

if [ -z "${JAC_SCALE_BINARY_PATH:-}" ]; then
    echo "WARN: JAC_SCALE_BINARY_PATH is unset; pods will bootstrap from a published release binary instead of the code under test."
fi

cleanup() {
    rc="${1:-0}"
    echo "=== cleanup (rc=${rc}) ==="
    if [ -n "${APP_DIR}" ]; then
        rm -rf "${APP_DIR}"
    fi
    if [ "${rc}" != "0" ] && [ "${E2E_KEEP_NS_ON_FAIL:-1}" = "1" ]; then
        echo "=== e2e failed (rc=${rc}); KEEPING namespaces for inspection (set E2E_KEEP_NS_ON_FAIL=0 to force cleanup) ==="
        return
    fi
    kubectl delete namespace "${OWNED_NS}" "${ADOPTED_NS}" --ignore-not-found --timeout=300s || true
    if [ "${CLUSTER_TYPE}" = "kind" ]; then
        kubectl delete pv jac-destroy-rwx-bundle-pv --ignore-not-found 2>/dev/null || true
    fi
}
trap 'cleanup "$?"' EXIT

dump_state() {
    ns="$1"
    kubectl get all,pvc -n "${ns}" -o wide || true
    kubectl get events -n "${ns}" --sort-by=.lastTimestamp | tail -40 || true
}

# shellcheck source=../../scripts/e2e_lib.sh
source "${REPO_ROOT}/jac/jaclang/scale/scripts/e2e_lib.sh"
e2e_timing_init

_t "prep start"
echo "=== stage a sanitized copy of jac/examples/todo_app ==="
APP_DIR="$(mktemp -d)/todo_app"
mkdir -p "${APP_DIR}"
cp "${APP_SRC}"/*.jac "${APP_DIR}/"
python3 - "${APP_SRC}/jac.toml" "${APP_DIR}/jac.toml" <<'PYEOF'
import sys

drop_sections = ("dev", "desktop")
out, skipping = [], False
with open(sys.argv[1]) as f:
    for line in f:
        stripped = line.strip()
        if stripped.startswith("["):
            section = stripped.strip("[]").split(".")[0]
            skipping = section in drop_sections
        if skipping or stripped.startswith("kind ="):
            continue
        out.append(line)
with open(sys.argv[2], "w") as f:
    f.writelines(out)
PYEOF

export SDK_DEPLOY_SOURCE="${APP_DIR}"
export SDK_DEPLOY_APP_NAME="${APP}"
export SDK_DEPLOY_STORAGE_CLASS="${STORAGE_CLASS}"

# The cluster-scoped StorageClass and PV are shared by both scenarios. The
# perms pod runs in 'default' so neither app namespace is created early:
# scenario A only holds if jac-scale is the one that creates its namespace.
if [ "${CLUSTER_TYPE}" = "kind" ]; then
    provision_kind_rwx_storage default "${STORAGE_CLASS}" \
        jac-destroy-rwx-bundle-pv /var/jac-destroy-rwx-bundle jac-destroy-rwx-perms
fi

deploy_app() {
    ns="$1"
    export SDK_DEPLOY_NAMESPACE="${ns}"
    if ! (cd "${REPO_ROOT}/jac" && jac run "${DRIVER}" deploy </dev/null 2>&1 | tail -25); then
        echo "FAIL: deploy into '${ns}' errored" >&2
        dump_state "${ns}"
        exit 1
    fi
    if ! kubectl rollout status "deployment/${APP}-deployment" -n "${ns}" \
            --timeout="${ROLLOUT_TIMEOUT}"; then
        echo "FAIL: app did not roll out in '${ns}'" >&2
        dump_state "${ns}"
        exit 1
    fi
}

destroy_app() {
    ns="$1"
    export SDK_DEPLOY_NAMESPACE="${ns}"
    if ! (cd "${REPO_ROOT}/jac" && jac run "${DRIVER}" destroy </dev/null 2>&1 | tail -20 | grep -q "DESTROY_OK"); then
        echo "FAIL: destroy in '${ns}' errored (or prompted)" >&2
        dump_state "${ns}"
        exit 1
    fi
}

require_absent() {
    ns="$1"; kind="$2"; name="$3"
    if kubectl get "${kind}" "${name}" -n "${ns}" >/dev/null 2>&1; then
        echo "FAIL: ${kind}/${name} still present in '${ns}' after destroy" >&2
        dump_state "${ns}"
        exit 1
    fi
}

######################## scenario A: owned namespace ########################
_t "scenario A start"
echo "=== scenario A: jac-scale creates the namespace, destroy must reclaim it ==="
kubectl delete namespace "${OWNED_NS}" --ignore-not-found --timeout=300s >/dev/null 2>&1 || true

deploy_app "${OWNED_NS}"

echo "=== assert jac-scale stamped namespace ownership at creation ==="
OWNER=$(kubectl get namespace "${OWNED_NS}" -o "jsonpath={.metadata.labels.${OWNER_LABEL//./\\.}}" 2>/dev/null || echo "")
if [ "${OWNER}" != "jac-scale" ]; then
    echo "FAIL: namespace '${OWNED_NS}' is not labelled as jac-scale owned (got '${OWNER}')" >&2
    dump_state "${OWNED_NS}"
    exit 1
fi

echo "=== assert the leaked-in-7968 resources actually exist before destroy ==="
if ! kubectl get statefulset "${APP}-postgres" -n "${OWNED_NS}" >/dev/null 2>&1; then
    echo "FAIL: postgres StatefulSet was never provisioned, so this run cannot prove reclamation" >&2
    dump_state "${OWNED_NS}"
    exit 1
fi
PVC_BEFORE=$(kubectl get pvc -n "${OWNED_NS}" --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "${PVC_BEFORE}" -lt 1 ]; then
    echo "FAIL: no PVCs bound before destroy, so this run cannot prove reclamation" >&2
    dump_state "${OWNED_NS}"
    exit 1
fi
echo "  postgres StatefulSet + ${PVC_BEFORE} PVC(s) present"

_t "scenario A deployed"
destroy_app "${OWNED_NS}"

echo "=== assert the namespace is fully gone ==="
WAITED=0
while [ "${WAITED}" -lt "${NS_DELETE_WAIT}" ]; do
    if ! kubectl get namespace "${OWNED_NS}" >/dev/null 2>&1; then
        break
    fi
    sleep 5
    WAITED=$(( WAITED + 5 ))
done
if kubectl get namespace "${OWNED_NS}" >/dev/null 2>&1; then
    echo "FAIL: namespace '${OWNED_NS}' still exists ${NS_DELETE_WAIT}s after destroy (#7968 regression)" >&2
    kubectl get namespace "${OWNED_NS}" -o yaml || true
    dump_state "${OWNED_NS}"
    exit 1
fi
echo "  namespace reclaimed, so postgres, redis-era companions and PVCs went with it"

echo "=== assert no PersistentVolume is left Bound to the destroyed app ==="
STRANDED=$(kubectl get pv -o json 2>/dev/null \
    | python3 -c "
import json, sys
pvs = json.load(sys.stdin).get('items', [])
bad = [
    p['metadata']['name'] for p in pvs
    if (p.get('spec', {}).get('claimRef') or {}).get('namespace') == '${OWNED_NS}'
    and p.get('status', {}).get('phase') == 'Bound'
]
print(' '.join(bad))
")
if [ -n "${STRANDED}" ]; then
    echo "FAIL: PersistentVolume(s) still Bound to the destroyed namespace: ${STRANDED}" >&2
    exit 1
fi
echo "  no stranded bound PVs"
_t "scenario A PASSED"

####################### scenario B: adopted namespace #######################
echo "=== scenario B: the namespace pre-exists, destroy must NOT delete it ==="
kubectl delete namespace "${ADOPTED_NS}" --ignore-not-found --timeout=300s >/dev/null 2>&1 || true
kubectl create namespace "${ADOPTED_NS}"
kubectl create configmap "${SENTINEL}" -n "${ADOPTED_NS}" --from-literal=owner=someone-else

deploy_app "${ADOPTED_NS}"

echo "=== assert an adopted namespace is not claimed as jac-scale owned ==="
ADOPTED_OWNER=$(kubectl get namespace "${ADOPTED_NS}" -o "jsonpath={.metadata.labels.${OWNER_LABEL//./\\.}}" 2>/dev/null || echo "")
if [ -n "${ADOPTED_OWNER}" ]; then
    echo "FAIL: pre-existing namespace '${ADOPTED_NS}' was claimed as owned ('${ADOPTED_OWNER}'); destroy would delete a namespace jac-scale did not create" >&2
    exit 1
fi
echo "  adopted namespace left unclaimed"

_t "scenario B deployed"
destroy_app "${ADOPTED_NS}"

echo "=== assert the namespace and the foreign workload survived ==="
if ! kubectl get namespace "${ADOPTED_NS}" >/dev/null 2>&1; then
    echo "FAIL: destroy deleted namespace '${ADOPTED_NS}', which jac-scale did not create" >&2
    exit 1
fi
if ! kubectl get configmap "${SENTINEL}" -n "${ADOPTED_NS}" >/dev/null 2>&1; then
    echo "FAIL: destroy removed the foreign ConfigMap '${SENTINEL}' it does not own" >&2
    exit 1
fi
echo "  namespace and foreign workload intact"

echo "=== assert the app's own resources were still reclaimed ==="
require_absent "${ADOPTED_NS}" statefulset "${APP}-postgres"
require_absent "${ADOPTED_NS}" deployment "${APP}-deployment"
LEFT_PVC=$(kubectl get pvc -n "${ADOPTED_NS}" -o name 2>/dev/null | grep -c "${APP}" || true)
if [ "${LEFT_PVC}" != "0" ]; then
    echo "FAIL: ${LEFT_PVC} app PVC(s) left behind in the adopted namespace" >&2
    kubectl get pvc -n "${ADOPTED_NS}" || true
    exit 1
fi
echo "  app workloads, postgres and PVCs all reclaimed"

_t "scenario B PASSED"
print_timing_report
echo "=== destroy reclamation REAL e2e PASSED ==="
