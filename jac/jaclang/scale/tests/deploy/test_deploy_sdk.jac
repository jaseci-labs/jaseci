import os;
import tempfile;
import unittest.mock;

import from jaclang.scale.sdk { DeploySpec, ProgressEvent, ScaleClient }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_target {
    KubernetesTarget
}
import from jaclang.scale.deploy.target.kubernetes.microservice.target {
    KubernetesMicroserviceTarget
}
import from jaclang.scale.deploy.target.kubernetes.microservice.manifest_builder {
    MicroserviceManifestBuilder
}


def _make_app_dir -> str {
    tmp = tempfile.mkdtemp();
    for name in ("main.jac", "svc_a.jac") {
        with open(os.path.join(tmp, name), "w") as f {
            f.write('with entry { print("hi"); }\n');
        }
    }
    return tmp;
}


def _sdk_spec(app_dir: str) -> DeploySpec {
    return DeploySpec(
        app_name="sdk-app",
        namespace="sdk-ns",
        source=app_dir,
        secrets={"API_KEY": "sk-1"},
        env={"MY_FLAG": "on"},
        replicas=2,
        resources={"cpu_request": "250m", "memory_limit": "1Gi"},
        microservices={"routes": {"svc_a": "/a"}},
        kube_context="paas-cluster",
        labels={"jachammer.io/project": "demo"},
        extra={
            "bundle_storage_class": "efs-sc",
            "mongodb_enabled": False,
            "redis_enabled": False
        }
    );
}


def _fake_injector -> unittest.mock.MagicMock {
    injector = unittest.mock.MagicMock();
    injector._object_key = "bundle-key";
    injector.extra_manifests.return_value = [];
    return injector;
}


def _identity_mutate(spec: dict[str, any], image: str) -> dict[str, any] {
    return spec;
}


def _start_offline_patches {
    binary_injector = unittest.mock.MagicMock();
    binary_injector.return_value.mutate_pod_spec.side_effect = _identity_mutate;
    unittest.mock.patch(
        "jaclang.scale.injector.binary.resolve_pod_base_image",
        return_value="python:3.12-slim"
    ).start();
    unittest.mock.patch(
        "jaclang.scale.injector.binary_injector.select_injector",
        return_value=(_fake_injector(), "tc-key")
    ).start();
    unittest.mock.patch(
        "jaclang.scale.injector.binary_injector.BinaryInjector", binary_injector
    ).start();
    unittest.mock.patch(
        "builtins.input", side_effect=AssertionError("the SDK must never prompt")
    ).start();
    unittest.mock.patch.object(
        MicroserviceManifestBuilder, "_build_client_bundle"
    ).start();
    unittest.mock.patch("jaclang.scale.sdk.client._ensure_deploy_tooling").start();
    unittest.mock.patch("jaclang.scale.sdk.client._require_deploy_tooling").start();
}


test "spec produces a full kubernetes config with no jac.toml involved" {
    spec = _sdk_spec("/does/not/matter");
    cfg = spec.to_target_config();
    assert cfg["app_name"] == "sdk-app";
    assert cfg["namespace"] == "sdk-ns";
    assert cfg["mongodb_enabled"] is False;
    assert cfg["redis_enabled"] is False;
    assert cfg["cpu_request"] == "250m";
    assert cfg["memory_limit"] == "1Gi";
    assert cfg["min_replicas"] == 2;
    assert cfg["kube_context"] == "paas-cluster";
    assert cfg["labels"] == {"jachammer.io/project": "demo"};
    assert cfg["bundle_storage_class"] == "efs-sc";
}


test "auto target mirrors the CLI: microservice only when routes declared" {
    assert DeploySpec(app_name="a").resolved_target() == "kubernetes";
    assert DeploySpec(
        app_name="a", microservices={"routes": {"svc_a": "/a"}}
    ).resolved_target()
        == "kubernetes-microservice";
    assert DeploySpec(app_name="a", microservices={"enabled": True}).resolved_target()
        == "kubernetes-microservice";
    assert DeploySpec(app_name="a", target="kubernetes-microservice").resolved_target()
        == "kubernetes-microservice";
}


test "spec validation rejects bad input with clear errors" {
    cases = {
        "bad target": (DeploySpec(app_name="a", target="ecs"), "target must be"),
        "bad resources": (
            DeploySpec(app_name="a", resources={"gpu": "1"}),
            "unsupported key"
        ),
        "bad replicas": (DeploySpec(app_name="a", replicas=0), "replicas must be")
    };
    for (label, case) in cases.items() {
        (spec, expected) = case;
        error = "";
        try {
            spec.resolved_target();
            spec.to_target_config();
        } except ValueError as e {
            error = str(e);
        }
        assert expected in error , f"{label}: expected {expected!r} in {error!r}";
    }

    error = "";
    try {
        DeploySpec(app_name="a").resolve_entry();
    } except ValueError as e {
        error = str(e);
    }
    assert "source is required" in error;
}


test "deploy wires spec into the bundle and streams typed events" {
    app_dir = _make_app_dir();
    spec = _sdk_spec(app_dir);
    events: list[ProgressEvent] = [];

    try {
        _start_offline_patches();
        applied = unittest.mock.patch.object(
            KubernetesMicroserviceTarget, "apply_manifests"
        ).start();
        unittest.mock.patch.object(
            KubernetesMicroserviceTarget, "_wait_for_fleet_rollout"
        ).start();
        unittest.mock.patch.object(
            KubernetesMicroserviceTarget, "_deploy_observability"
        ).start();
        unittest.mock.patch.object(
            KubernetesMicroserviceTarget,
            "get_service_url",
            return_value="http://gateway.sdk-ns.example"
        ).start();
        result = ScaleClient().deploy(spec, on_event=events.append);
    } finally {
        unittest.mock.patch.stopall();
    }

    assert result.success , result.message;
    assert result.service_url == "http://gateway.sdk-ns.example";
    applied.assert_called_once();

    bundle = result.details;
    assert sorted(bundle["deployments"].keys()) == ["__gateway__", "svc_a"];
    gateway = bundle["deployments"]["__gateway__"];
    assert gateway["spec"]["replicas"] == 2;
    for manifest in (
        gateway,
        bundle["deployments"]["svc_a"],
        bundle["services"]["__gateway__"]
    ) {
        assert manifest["metadata"]["labels"]["jachammer.io/project"] == "demo";
        assert manifest["metadata"]["labels"]["managed"] == "jac-scale";
    }

    assert bundle["user_secret"]["stringData"] == {"API_KEY": "sk-1"};

    container = bundle["pod_specs"]["__gateway__"]["containers"][0];
    env_by_name = {e["name"]: e.get("value") for e in container["env"]};
    assert env_by_name["MY_FLAG"] == "on";
    env_from: list = container["envFrom"];
    assert {"secretRef": {"name": "sdk-app-secrets"}} in env_from;

    phase_steps = [(e.phase, e.status) for e in events];
    assert phase_steps[0] == ("deploy", "start");
    assert phase_steps[-1] == ("deploy", "ok");
    for phase in ("provision", "bundle", "apply", "rollout") {
        assert (phase, "start") in phase_steps , f"missing {phase} start";
        assert (phase, "ok") in phase_steps , f"missing {phase} ok";
    }
    assert events[-1].detail["service_url"] == "http://gateway.sdk-ns.example";
    assert any(e.phase == "log" for e in events) , "log lines should stream too";
}


test "preview returns the manifest bundle without touching a cluster" {
    app_dir = _make_app_dir();
    spec = _sdk_spec(app_dir);

    try {
        _start_offline_patches();
        applied = unittest.mock.patch.object(
            KubernetesMicroserviceTarget, "apply_manifests"
        ).start();
        loaded = unittest.mock.patch.object(
            KubernetesMicroserviceTarget, "_load_kube_config"
        ).start();
        bundle = ScaleClient().preview(spec);
    } finally {
        unittest.mock.patch.stopall();
    }

    assert sorted(bundle["deployments"].keys()) == ["__gateway__", "svc_a"];
    services: dict = bundle["services"];
    assert "__gateway__" in services;
    applied.assert_not_called();
    loaded.assert_not_called();
}


test "destroy is non-interactive and forwards the component" {
    try {
        _start_offline_patches();
        destroyed = unittest.mock.patch.object(KubernetesTarget, "destroy").start();
        ScaleClient().destroy("sdk-app", "sdk-ns");
    } finally {
        unittest.mock.patch.stopall();
    }
    destroyed.assert_called_once_with("sdk-app", "");
}
