"""Apply/observe/teardown driver for the KEDA gateway target-correlation e2e
(keda_gateway_correlation_real_e2e.sh). Talks to whatever cluster the current
kubeconfig/in-cluster context points at -- no mocking, this exercises the
real KEDAAutoscaler.apply/get_runtime_status and the real
KubernetesAutoscalerObserver against a real ScaledObject, KEDA-generated
HPA, and Deployment.

Reproduces jac-scale's actual gateway/microservice deploy shape (see
target.jac:_autoscaler_spec and manifest_builder.jac:k8s_safe_name):
scale_target_name is the Deployment's own resource name
("<app>-deployment"), which also becomes the app label KEDA propagates onto
the ScaledObject/HPA it manages -- while the Deployment itself is labeled
with the bare app name, since that label doubles as its pod selector. Before
a0e5c2213 the observer correlated all three resource kinds by that `app`
label, so the ScaledObject/HPA (labelled "<app>-deployment") and the
Deployment (labelled "<app>") never joined into one _target_cache slot.

    jac run keda_gateway_correlation_verify.jac apply
    jac run keda_gateway_correlation_verify.jac observe
    jac run keda_gateway_correlation_verify.jac teardown

Target namespace/name are read from env vars so the orchestrating shell
script controls them without editing this file.
"""
import os;
import sys;
import time;
import from jaclang.scale._optdeps.kubernetes {
    client,
    config as k8s_config,
    ConfigException
}
import from jaclang.scale.deploy.autoscale.keda_autoscaler { KEDAAutoscaler }
import from jaclang.scale.deploy.autoscale.autoscaler { AutoscalerSpec, Trigger }
import from jaclang.scale.deploy.autoscale.kubernetes_observer {
    KubernetesAutoscalerObserver
}
import from jaclang.scale.observability.standard_logger { StandardLogger }

glob NAMESPACE: str = os.environ.get(
         "KEDA_GW_CORR_E2E_NAMESPACE", "jac-gw-corr-e2e"
     ),
     APP_NAME: str = os.environ.get("KEDA_GW_CORR_E2E_APP", "gateway"),
     DEPLOYMENT_NAME: str = f"{APP_NAME}-deployment",
     OBSERVE_TIMEOUT: int = int(
         os.environ.get("KEDA_GW_CORR_E2E_OBSERVE_TIMEOUT", "60")
     );

def load_config {
    # any: sidesteps a checker false positive on _optdeps' guarded import (NoneType inferred from its ImportError fallback branch).
    kube_config: any = k8s_config;
    try {
        kube_config.load_kube_config();
    } except ConfigException {
        kube_config.load_incluster_config();
    }
}

def build_deployment_manifest -> dict[str, any] {
    return {
        "apiVersion": "apps/v1",
        "kind": "Deployment",
        "metadata": {
            "name": DEPLOYMENT_NAME,
            "namespace": NAMESPACE,
            "labels": {"app": APP_NAME, "managed": "jac-scale"}
        },
        "spec": {
            "replicas": 1,
            "selector": {"matchLabels": {"app": APP_NAME}},
            "template": {
                "metadata": {"labels": {"app": APP_NAME, "managed": "jac-scale"}},
                "spec": {
                    "containers": [
                        {
                            "name": APP_NAME,
                            "image": "registry.k8s.io/pause:3.9",
                            "resources": {"requests": {"cpu": "10m", "memory": "16Mi"}}
                        }
                    ]
                }
            }
        }
    };
}

def apply_target {
    load_config();
    core: any = client.CoreV1Api();
    apps: any = client.AppsV1Api();

    try {
        core.create_namespace(
            {"metadata": {"name": NAMESPACE, "labels": {"managed": "jac-scale"}}}
        );
    } except Exception as e {
        print(f"namespace create: {e}");
    }

    apps.create_namespaced_deployment(
        namespace=NAMESPACE, body=build_deployment_manifest()
    );
    print(f"created Deployment/{DEPLOYMENT_NAME} (app label={APP_NAME})");

    autoscaler = KEDAAutoscaler(logger=StandardLogger());
    spec = AutoscalerSpec(
        scale_target_name=DEPLOYMENT_NAME,
        namespace=NAMESPACE,
        min_replicas=1,
        max_replicas=2,
        app_name=APP_NAME,
        triggers=[Trigger(type="cpu", metadata={"averageUtilization": "50"})]
    );
    ok = autoscaler.apply(spec);
    if not ok {
        print("KEDAAutoscaler.apply returned False");
        sys.`exit(1);
    }
    print(
        f"KEDAAutoscaler.apply -> {ok}, ScaledObject/{autoscaler.resource_name_for(
            APP_NAME
        )}"
    );
}

def observe_and_assert {
    load_config();

    observer = KubernetesAutoscalerObserver(logger=StandardLogger());
    observer.start();
    observer.watch_namespace(NAMESPACE);

    key = f"{NAMESPACE}::{DEPLOYMENT_NAME}";
    deadline = time.monotonic() + float(OBSERVE_TIMEOUT);
    all_keys: list[str] = [];
    full_slot: dict[str, any] = {};
    while time.monotonic() < deadline {
        with observer._lock {
            all_keys = list(observer._target_cache.keys());
            full_slot = dict(observer._target_cache.get(key, {}));
        }
        if (
            full_slot.get("scaled_object") is not None
            and full_slot.get("hpa") is not None
            and full_slot.get("deployment") is not None
        ) {
            break;
        }
        time.sleep(1.0);
    }
    observer.stop(drain=True);

    print(f"_target_cache keys: {all_keys}");
    print(
        f"slot for '{key}': "
        f"scaled_object={'set' if full_slot.get('scaled_object') else 'None'}, "
        f"hpa={'set' if full_slot.get('hpa') else 'None'}, "
        f"deployment={'set' if full_slot.get('deployment') else 'None'}"
    );

    correlated = (
        len(all_keys) == 1
        and full_slot.get("scaled_object") is not None
        and full_slot.get("hpa") is not None
        and full_slot.get("deployment") is not None
    );
    if not correlated {
        print(
            "FAIL: expected exactly one fully populated _target_cache slot "
            f"for the real target; got {len(all_keys)} slot(s): {all_keys}"
        );
        sys.`exit(1);
    }
    print(
        "PASS: one fully populated _target_cache slot -- scaled_object, hpa, "
        "and deployment all joined under the same key."
    );
}

def teardown {
    load_config();
    autoscaler = KEDAAutoscaler(logger=StandardLogger());
    try {
        autoscaler.destroy(APP_NAME, NAMESPACE);
    } except Exception as e {
        print(f"destroy: {e}");
    }
    core: any = client.CoreV1Api();
    try {
        core.delete_namespace(NAMESPACE);
    } except Exception as e {
        print(f"namespace delete: {e}");
    }
    print("teardown -> done");
}

with entry {
    if len(sys.argv) < 2 or sys.argv[1] not in ("apply", "observe", "teardown") {
        print(
            "usage: jac run keda_gateway_correlation_verify.jac "
            "[apply|observe|teardown]"
        );
        sys.`exit(1);
    }
}

glob action = sys.argv[1];

with entry {
    if action == "apply" {
        apply_target();
    } elif action == "observe" {
        observe_and_assert();
    } else {
        teardown();
    }
}
