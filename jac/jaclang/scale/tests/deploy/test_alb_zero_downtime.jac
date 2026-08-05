import atexit;
import os;
import tempfile;
import unittest;
import from uuid { uuid4 }
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder { ManifestBuilder }
import from jaclang.scale.deploy.target.kubernetes.target { KubernetesTarget }

glob READINESS_GATE_LABEL: str = "elbv2.k8s.aws/pod-readiness-gate-inject",
     _shared: dict = {};


# One real k3s apiserver (testcontainers) shared by the whole file, torn down
# at exit - the same real-infra pattern as tests/data/test_occ_replay.jac.
def _require_cluster {
    if "cluster" in _shared {
        return;
    }
    if "error" in _shared {
        raise unittest.SkipTest(_shared["error"]);
    }
    try {
        import from testcontainers.community.k3s { K3SContainer }
        container = K3SContainer();
        container.start();
        atexit.register(container.stop);
        kubeconfig = tempfile.NamedTemporaryFile(
            mode="w", suffix=".kubeconfig", delete=False
        );
        kubeconfig.write(container.config_yaml());
        kubeconfig.close();
        os.environ["KUBECONFIG"] = kubeconfig.name;
        _shared["cluster"] = container;
    } except Exception as e {
        _shared["error"] = (
            f"real k3s cluster unavailable ({e}); this suite needs docker "
            f"and testcontainers"
        );
        raise unittest.SkipTest(_shared["error"]);
    }
}


def _config(namespace: str, shared_ingress_class: str = "") -> KubernetesConfig {
    if shared_ingress_class {
        return KubernetesConfig(
            app_name="standup",
            namespace=namespace,
            domain="standup.example.com",
            shared_ingress=True,
            shared_ingress_class=shared_ingress_class
        );
    }
    return KubernetesConfig(app_name="standup", namespace=namespace);
}


# Drive the real deploy plumbing end to end against the live apiserver:
# namespace ensure, the readiness-gate step, Service + Deployment apply, and
# the superseded-Deployment sweep. Nothing is faked or patched.
def _deploy_through_apply(cfg: KubernetesConfig) {
    target = KubernetesTarget(config=cfg, microservices_config={});
    builder = ManifestBuilder(k8s_config=cfg, microservices_config={});
    specs = builder.generate_service_pod_specs(
        AppConfig(code_folder="/apps/standup", file_name="main.jac"), "img"
    );
    bundle: dict[str, any] = {
        "deployments": {
            name: builder._build_deployment_manifest(name, spec)
            for (name, spec) in specs.items()
        },
        "services": {
            name: builder._build_service_manifest(name) for name in specs.keys()
        },
        "pod_specs": specs
    };
    target.apply_manifests(bundle);
}


def _live_namespace_labels(namespace: str) -> dict {
    import from kubernetes { client }
    ns = client.CoreV1Api().read_namespace(name=namespace);
    return dict(ns.metadata.labels or {});
}


def _live_deployments(namespace: str) -> list {
    import from kubernetes { client }
    api = client.AppsV1Api();
    serializer = client.ApiClient();
    return [
        serializer.sanitize_for_serialization(d)
        for d in api.list_namespaced_deployment(namespace=namespace).items
    ];
}


def _drain_of(dep: dict) -> tuple {
    pod = dep["spec"]["template"]["spec"];
    sleep_cmd: str = str(
        pod["containers"][0]["lifecycle"]["preStop"]["exec"]["command"][-1]
    );
    return (int(sleep_cmd.split()[-1]), int(pod["terminationGracePeriodSeconds"]));
}


def _fresh_ns(prefix: str) -> str {
    return f"{prefix}-{uuid4().hex[:8]}";
}


# The ALB routes to pod IPs it health-checks itself, so k8s readiness alone is
# not routability: without the readiness gate the Deployment retires the old
# pod while the ALB is still health-checking the new target, and the target
# group goes briefly empty on every redeploy.
test "an ALB shared-ingress deploy labels the namespace for readiness gates" {
    _require_cluster();
    ns = _fresh_ns("alb-gate");

    _deploy_through_apply(_config(ns, "alb"));

    labels = _live_namespace_labels(ns);
    assert labels.get(READINESS_GATE_LABEL) == "enabled" , f"namespace labels after deploy: {labels}";
}


# The other half of the gap: after replacement the old pod died at ~15s while
# the ALB was still shifting new requests off its deregistering IP target.
test "every Deployment an ALB deploy applies outlives target deregistration" {
    _require_cluster();
    ns = _fresh_ns("alb-drain");

    _deploy_through_apply(_config(ns, "alb"));

    deployments = _live_deployments(ns);
    assert len(deployments) >= 2;
    for dep in deployments {
        (sleep_s, grace) = _drain_of(dep);
        name = dep["metadata"]["name"];
        assert sleep_s >= 20 , f"{name}: ALB path needs a preStop long enough to drain the "
        f"target, got {sleep_s}s";
        assert grace > sleep_s , f"{name}: grace ({grace}s) must exceed the preStop sleep "
        f"({sleep_s}s)";
    }
}


test "a non-ALB deploy leaves the namespace alone and keeps the short drain" {
    _require_cluster();
    ns = _fresh_ns("nginx");

    _deploy_through_apply(_config(ns));

    labels = _live_namespace_labels(ns);
    assert READINESS_GATE_LABEL not in labels , f"endpoint-routed deploy must not touch namespace labels: {labels}";
    deployments = _live_deployments(ns);
    assert len(deployments) >= 2;
    for dep in deployments {
        (sleep_s, grace) = _drain_of(dep);
        assert (sleep_s, grace) == (5, 15) , f"{dep['metadata'][
            'name'
        ]}: endpoint-routed pods should keep the "
        f"5s/15s drain, got {sleep_s}s/{grace}s";
    }
}


test "a second deploy does not re-patch an already-labeled namespace" {
    _require_cluster();
    ns = _fresh_ns("alb-idem");
    cfg = _config(ns, "alb");

    _deploy_through_apply(cfg);
    first = _live_namespace_labels(ns);
    _deploy_through_apply(cfg);
    second = _live_namespace_labels(ns);

    assert first.get(READINESS_GATE_LABEL) == "enabled";
    assert second == first , f"redeploy changed namespace labels: {first} -> {second}";
}
