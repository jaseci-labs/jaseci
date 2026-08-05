import from types { SimpleNamespace }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
    GATEWAY_NAME,
    ManifestBuilder
}
import from jaclang.scale.deploy.target.kubernetes.target { KubernetesTarget }

glob READINESS_GATE_LABEL: str = "elbv2.k8s.aws/pod-readiness-gate-inject";


def _alb_config(app: str = "standup") -> KubernetesConfig {
    return KubernetesConfig(
        app_name=app,
        namespace=f"jb-{app}",
        domain=f"{app}.example.com",
        shared_ingress=True,
        shared_ingress_class="alb"
    );
}


def _nginx_config(app: str = "standup") -> KubernetesConfig {
    return KubernetesConfig(app_name=app, namespace=f"jb-{app}");
}


def _builder(cfg: KubernetesConfig) -> ManifestBuilder {
    return ManifestBuilder(k8s_config=cfg, microservices_config={});
}


obj FakeCoreV1 {
    has ns_labels: dict = {},
        patches: list = [];

    def read_namespace(name: str) -> any {
        return SimpleNamespace(
            metadata=SimpleNamespace(name=name, labels=dict(self.ns_labels))
        );
    }

    def patch_namespace(name: str, body: dict) {
        self.patches.append(body);
        self.ns_labels.update(body.get("metadata", {}).get("labels", {}));
    }
}


# The ALB routes to pod IPs it health-checks itself, so k8s readiness alone is
# not routability: without the readiness gate the Deployment kills the old pod
# while the ALB is still health-checking the new target, and the target group
# goes briefly empty on every redeploy.
test "an ALB shared-ingress deploy labels the namespace for readiness gates" {
    core_v1 = FakeCoreV1();
    target = KubernetesTarget(config=_alb_config(), microservices_config={});

    target.ensure_alb_readiness_gates(core_v1, "jb-standup");

    assert core_v1.ns_labels.get(READINESS_GATE_LABEL) == "enabled" , f"namespace labels after deploy: {core_v1.ns_labels}";
}


test "an already-labeled namespace is not patched again" {
    core_v1 = FakeCoreV1(ns_labels={READINESS_GATE_LABEL: "enabled"});
    target = KubernetesTarget(config=_alb_config(), microservices_config={});

    target.ensure_alb_readiness_gates(core_v1, "jb-standup");

    assert core_v1.patches == [] , f"expected no patch on a labeled namespace, got {core_v1.patches}";
}


test "a non-ALB ingress class leaves the namespace alone" {
    core_v1 = FakeCoreV1();
    target = KubernetesTarget(config=_nginx_config(), microservices_config={});

    target.ensure_alb_readiness_gates(core_v1, "jb-standup");

    assert core_v1.patches == [] and READINESS_GATE_LABEL not in core_v1.ns_labels , f"nginx-class deploy must not touch namespace labels: {core_v1.ns_labels}";
}


test "readiness-gate labeling failure never fails the deploy" {
    obj BrokenCoreV1 {
        def read_namespace(name: str) -> any {
            raise RuntimeError("apiserver unavailable");
        }
    }
    target = KubernetesTarget(config=_alb_config(), microservices_config={});
    target.ensure_alb_readiness_gates(BrokenCoreV1(), "jb-standup");
}


# The other half of the gap: after replacement the old pod died at ~15s while
# the ALB was still shifting new requests off its deregistering IP target.
test "ALB pods outlive target deregistration" {
    builder = _builder(_alb_config());
    spec = builder._build_pod_spec(GATEWAY_NAME, "img");

    sleep_cmd = spec["containers"][0]["lifecycle"]["preStop"]["exec"]["command"][-1];
    sleep_s = int(sleep_cmd.split()[-1]);
    grace = int(spec["terminationGracePeriodSeconds"]);

    assert sleep_s >= 20 , f"ALB path needs a preStop long enough to drain the target, got {sleep_s}s";
    assert grace > sleep_s , f"grace ({grace}s) must exceed the preStop sleep ({sleep_s}s)";
}


test "non-ALB pods keep the short drain" {
    builder = _builder(_nginx_config());
    spec = builder._build_pod_spec(GATEWAY_NAME, "img");

    sleep_cmd = spec["containers"][0]["lifecycle"]["preStop"]["exec"]["command"][-1];
    sleep_s = int(sleep_cmd.split()[-1]);

    assert sleep_s == 5 , f"endpoint-routed pods should keep the 5s cushion, got {sleep_s}s";
    assert int(spec["terminationGracePeriodSeconds"]) == 15;
}
