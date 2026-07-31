#!/usr/bin/env bash
# Real-cluster e2e for the programmatic deploy SDK (jaclang.scale.sdk).
#
# Deploys examples/sdk-deploy through ScaleClient (deploy.jac driver) instead
# of `jac start --scale`, then proves the deploy is real: typed progress
# events reached the caller, pods roll out, DeploySpec.env and
# DeploySpec.secrets reach the service pod (asserted through the greeter's
# response), platform labels are stamped on the manifests, status/url work,
# and destroy tears everything down without ever prompting.
#
# Requires a reachable cluster (kind/minikube/microk8s) on the current
# kubeconfig context and the scale deploy deps installed for `jac`.

set -euo pipefail

# This script lives at jac/jaclang/scale/tests/deploy/, so the repo root is
# five levels up.
REPO_ROOT="$(cd "$(dirname "$0")/../../../../.." && pwd)"
EXAMPLE_DIR="${REPO_ROOT}/jac/jaclang/scale/examples/sdk-deploy"
if [ ! -f "${EXAMPLE_DIR}/deploy.jac" ]; then
    echo "FAIL: ${EXAMPLE_DIR}/deploy.jac not found" >&2
    exit 1
fi

export SDK_DEPLOY_NAMESPACE="${SDK_DEPLOY_NAMESPACE:-jac-sdk-e2e}"
export SDK_DEPLOY_APP_NAME="${SDK_DEPLOY_APP_NAME:-sdk-greeter}"
export SDK_DEPLOY_GREETING="${SDK_DEPLOY_GREETING:-howdy}"
export SDK_DEPLOY_SECRET="${SDK_DEPLOY_SECRET:-sdk-e2e-secret}"
NAMESPACE="${SDK_DEPLOY_NAMESPACE}"

CLUSTER_TYPE="${CLUSTER_TYPE:-kind}"
case "${CLUSTER_TYPE}" in
    microk8s) export SDK_DEPLOY_STORAGE_CLASS="${SDK_DEPLOY_STORAGE_CLASS-microk8s-hostpath}" ;;
    minikube) export SDK_DEPLOY_STORAGE_CLASS="${SDK_DEPLOY_STORAGE_CLASS-standard}" ;;
    kind)     export SDK_DEPLOY_STORAGE_CLASS="${SDK_DEPLOY_STORAGE_CLASS-jac-sdk-rwx}" ;;
    *)        export SDK_DEPLOY_STORAGE_CLASS="${SDK_DEPLOY_STORAGE_CLASS-}" ;;
esac

ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-600s}"
DELETE_TIMEOUT="${DELETE_TIMEOUT:-300s}"
GATEWAY_LOCAL_PORT="${GATEWAY_LOCAL_PORT:-18300}"

if [ -z "${JAC_SCALE_BINARY_PATH:-}" ]; then
    echo "WARN: JAC_SCALE_BINARY_PATH is unset; pods will bootstrap from a published release binary instead of the code under test."
fi

PORT_FORWARD_PID=""
cleanup() {
    rc="${1:-0}"
    echo "=== cleanup (rc=${rc}) ==="
    if [ -n "${PORT_FORWARD_PID}" ]; then
        kill "${PORT_FORWARD_PID}" 2>/dev/null || true
    fi
    if [ "${rc}" != "0" ] && [ "${E2E_KEEP_NS_ON_FAIL:-1}" = "1" ]; then
        echo "=== e2e failed (rc=${rc}); KEEPING namespace '${NAMESPACE}' for inspection (set E2E_KEEP_NS_ON_FAIL=0 to force cleanup) ==="
        return
    fi
    kubectl delete namespace "${NAMESPACE}" --ignore-not-found --timeout="${DELETE_TIMEOUT}" || true
    if [ "${CLUSTER_TYPE}" = "kind" ]; then
        kubectl delete pv jac-sdk-rwx-bundle-pv --ignore-not-found 2>/dev/null || true
    fi
}
trap 'cleanup "$?"' EXIT

dump_state() {
    kubectl get pods -n "${NAMESPACE}" -o wide || true
    kubectl get events -n "${NAMESPACE}" --sort-by=.lastTimestamp || true
    for pod in $(kubectl get pods -n "${NAMESPACE}" -o name 2>/dev/null); do
        kubectl logs -n "${NAMESPACE}" "${pod}" --all-containers=true --tail=120 || true
    done
}

_T0=$(date +%s)
_t() { echo "[TIMING +$(( $(date +%s) - _T0 ))s] $1"; }

provision_kind_rwx_storage() {
    # kind's local-path StorageClass is RWO-only; a static hostPath PV (own
    # name/path, so it cannot collide with the microservice e2e's PV)
    # satisfies the RWX bundle PVC on single-node kind.
    echo "=== provisioning RWX hostPath storage for kind (class=${SDK_DEPLOY_STORAGE_CLASS}) ==="
    kubectl delete pv jac-sdk-rwx-bundle-pv --ignore-not-found >/dev/null 2>&1 || true
    kubectl apply -f - <<YAML
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${SDK_DEPLOY_STORAGE_CLASS}
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: Immediate
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: jac-sdk-rwx-bundle-pv
  labels:
    managed: jac-scale-e2e
spec:
  capacity:
    storage: 20Gi
  accessModes: ["ReadWriteMany"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ${SDK_DEPLOY_STORAGE_CLASS}
  hostPath:
    path: /var/jac-sdk-rwx-bundle
    type: DirectoryOrCreate
YAML
    kubectl -n "${NAMESPACE}" delete pod jac-sdk-rwx-perms --ignore-not-found >/dev/null 2>&1 || true
    kubectl -n "${NAMESPACE}" apply -f - <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: jac-sdk-rwx-perms
spec:
  restartPolicy: Never
  securityContext:
    runAsUser: 0
  containers:
    - name: fix
      image: busybox:1.36
      command: ["sh", "-c", "chmod 0777 /host && echo perms-fixed"]
      volumeMounts:
        - { name: host, mountPath: /host }
  volumes:
    - name: host
      hostPath:
        path: /var/jac-sdk-rwx-bundle
        type: DirectoryOrCreate
YAML
    if ! kubectl -n "${NAMESPACE}" wait --for=jsonpath='{.status.phase}'=Succeeded \
            pod/jac-sdk-rwx-perms --timeout=90s; then
        echo "FAIL: could not open up the RWX hostPath dir for non-root pods"
        kubectl -n "${NAMESPACE}" logs jac-sdk-rwx-perms || true
        exit 1
    fi
    kubectl -n "${NAMESPACE}" delete pod jac-sdk-rwx-perms --ignore-not-found >/dev/null 2>&1 || true
}

_t "prep start"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
if [ "${CLUSTER_TYPE}" = "kind" ]; then
    provision_kind_rwx_storage
fi

_t "SDK deploy start"
echo "=== deploy programmatically via ScaleClient (deploy.jac driver) ==="
DEPLOY_LOG="$(mktemp)"
# </dev/null: any interactive prompt in the SDK path is an instant failure
# instead of a hang.
if ! (cd "${EXAMPLE_DIR}" && jac run deploy.jac deploy </dev/null 2>&1 | tee "${DEPLOY_LOG}"); then
    echo "FAIL: SDK deploy errored" >&2
    dump_state
    rm -f "${DEPLOY_LOG}"
    exit 1
fi

echo "=== assert the typed event stream reached the caller ==="
for marker in "[deploy:start]" "[provision:ok]" "[bundle:ok]" "[apply:ok]" "[rollout:ok]" "[deploy:ok]" "DEPLOY_OK"; do
    if ! grep -qF "${marker}" "${DEPLOY_LOG}"; then
        echo "FAIL: expected event marker '${marker}' missing from the deploy output" >&2
        cat "${DEPLOY_LOG}" >&2
        rm -f "${DEPLOY_LOG}"
        exit 1
    fi
done
rm -f "${DEPLOY_LOG}"
echo "  all phase events streamed"

_t "deploy applied; waiting pods"
echo "=== wait for pods Ready ==="
for dep in $(kubectl get deployments -n "${NAMESPACE}" -l managed=jac-scale -o name); do
    echo "  waiting on ${dep}..."
    if ! kubectl rollout status "${dep}" -n "${NAMESPACE}" --timeout="${ROLLOUT_TIMEOUT}"; then
        echo "FAIL: rollout for ${dep} did not complete" >&2
        dump_state
        exit 1
    fi
done

_t "pods Ready"
echo "=== assert DeploySpec.labels stamped on the generated manifests ==="
for res in deployment/gateway-deployment deployment/greeter-deployment service/gateway-service; do
    LABEL=$(kubectl get "${res}" -n "${NAMESPACE}" -o jsonpath='{.metadata.labels.jac-scale\.example}')
    if [ "${LABEL}" != "sdk-deploy" ]; then
        echo "FAIL: ${res} missing the platform label (jac-scale.example='${LABEL}')" >&2
        exit 1
    fi
done
echo "  labels stamped"

echo "=== port-forward gateway + /health ==="
kubectl port-forward -n "${NAMESPACE}" svc/gateway-service "${GATEWAY_LOCAL_PORT}:8000" >/dev/null 2>&1 &
PORT_FORWARD_PID=$!
sleep 2
if ! curl -fsS "http://localhost:${GATEWAY_LOCAL_PORT}/health" >/dev/null; then
    echo "FAIL: gateway /health did not return 200" >&2
    dump_state
    exit 1
fi
echo "  /health OK"

_t "health OK"
echo "=== journey: register/login, then greet through the /greeter route ==="
GW_URL="http://localhost:${GATEWAY_LOCAL_PORT}"
E2E_EMAIL="sdk-e2e@example.com"
REG_BODY="{\"identities\":[{\"type\":\"email\",\"value\":\"${E2E_EMAIL}\"}],\"credential\":{\"type\":\"password\",\"password\":\"pw12345678\"}}"
LOGIN_BODY="{\"identity\":{\"type\":\"email\",\"value\":\"${E2E_EMAIL}\"},\"credential\":{\"type\":\"password\",\"password\":\"pw12345678\"}}"
REG_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${GW_URL}/user/register" \
    -H 'content-type: application/json' -d "${REG_BODY}")
case "${REG_CODE}" in
    200 | 201 | 409) : ;;
    *) echo "FAIL: /user/register returned ${REG_CODE}" >&2; dump_state; exit 1 ;;
esac
TOKEN=$(curl -fsS -X POST "${GW_URL}/user/login" -H 'content-type: application/json' \
    -d "${LOGIN_BODY}" \
    | python3 -c "import json, sys; print((json.load(sys.stdin).get('data') or {}).get('token', ''))")
if [ -z "${TOKEN}" ]; then echo "FAIL: /user/login returned no token" >&2; exit 1; fi

GREET=$(curl -fsS --max-time 20 --retry 5 --retry-delay 3 --retry-all-errors \
    -X POST "${GW_URL}/greeter/function/greet" \
    -H "Authorization: Bearer ${TOKEN}" -H 'content-type: application/json' \
    -d '{"name": "e2e"}' || true)
echo "  greet -> ${GREET}"
if ! printf '%s' "${GREET}" | grep -q "${SDK_DEPLOY_GREETING}, e2e!"; then
    echo "FAIL: DeploySpec.env did not reach the greeter pod (expected '${SDK_DEPLOY_GREETING}, e2e!')" >&2
    dump_state
    exit 1
fi
if ! printf '%s' "${GREET}" | python3 -c "import json, sys; d = json.load(sys.stdin); sys.exit(0 if ((d.get('data') or {}).get('result') or {}).get('secret_present') else 1)"; then
    echo "FAIL: DeploySpec.secrets did not reach the greeter pod (secret_present is false)" >&2
    dump_state
    exit 1
fi
echo "  env + secret reached the pod through the spec"

_t "journey OK"
echo "=== status + url through the SDK ==="
# grep '^{': first-run compiles print "Jac setup complete" lines around the payload.
STATUS_JSON=$(cd "${EXAMPLE_DIR}" && jac run deploy.jac status </dev/null | grep '^{' | tail -1)
if ! printf '%s' "${STATUS_JSON}" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
comps = {c.get('name'): c.get('status') for c in d.get('components', [])}
assert d.get('app_name') == '${SDK_DEPLOY_APP_NAME}', d
assert comps, d
sys.exit(0)
"; then
    echo "FAIL: SDK status() returned an unexpected payload: ${STATUS_JSON}" >&2
    exit 1
fi
echo "  status OK: ${STATUS_JSON}"
(cd "${EXAMPLE_DIR}" && jac run deploy.jac url </dev/null | tail -1 | sed 's/^/  url -> /') || true

_t "status OK"
echo "=== destroy through the SDK (must never prompt) ==="
if ! (cd "${EXAMPLE_DIR}" && jac run deploy.jac destroy </dev/null 2>&1 | tee /dev/stderr | grep -q "DESTROY_OK"); then
    echo "FAIL: SDK destroy errored (or prompted)" >&2
    exit 1
fi
DESTROY_WAIT=0
while [ "${DESTROY_WAIT}" -lt 120 ]; do
    LEFT=$(kubectl get deployments -n "${NAMESPACE}" -l managed=jac-scale --no-headers 2>/dev/null | wc -l | tr -d ' ')
    [ "${LEFT}" = "0" ] && break
    sleep 5
    DESTROY_WAIT=$(( DESTROY_WAIT + 5 ))
done
if [ "${LEFT}" != "0" ]; then
    echo "FAIL: ${LEFT} managed deployment(s) still present 120s after destroy" >&2
    dump_state
    exit 1
fi
echo "  fleet destroyed"

_t "ALL DONE"
echo "=== SDK programmatic deploy REAL e2e PASSED ==="
