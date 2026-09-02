"""The declared [scale.kubernetes] HPA bounds must reach the rendered autoscaler.

min_replicas, max_replicas, cpu_utilization_target and memory_utilization_target
are documented keys, carried correctly onto KubernetesConfig, and were then
ignored: the manifest builder re-defaulted them from literals, so every deploy
got min 1 / max 3 / cpu 50 / memory 80 regardless of jac.toml. These drive the
real manifest builder end to end and pin the layering: a per-service hpa key
beats the config-level bound, and the config-level bound beats the built-in
default."""

import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
    ManifestBuilder,
    ScalingMode
}
import from jaclang.scale.config.app_config { AppConfig }


def _autoscaler(k8s_config: KubernetesConfig, services: dict) -> dict {
    import tempfile;
    import from pathlib { Path }
    with tempfile.TemporaryDirectory() as project {
        for name in list(services.keys()) + ["main"] {
            (Path(project) / f"{name}.jac").write_text("");
        }
        builder = ManifestBuilder(
            k8s_config=k8s_config,
            microservices_config={
                "routes": {name: f"/{name}" for name in services},
                "services": services
            },
            dry_run=True
        );
        bundle = builder.generate_manifests(
            AppConfig(code_folder=project, app_name="shop"), ""
        );
        scaling = bundle["scaling"]["api"];
        assert scaling["mode"] == ScalingMode.METRIC;
        return dict(scaling["autoscaler"]);
    }
}


test "declared config bounds reach the autoscaler" {
    auto = _autoscaler(
        KubernetesConfig(
            app_name="shop",
            namespace="shop-ns",
            bundle_storage_class="standard",
            min_replicas=3,
            max_replicas=5,
            cpu_utilization_target=40,
            memory_utilization_target=70
        ),
        {"api": {"file": "api.jac"}}
    );
    assert auto["min"] == 3;
    assert auto["max"] == 5;
    assert auto["cpu_target"] == 40;
    assert auto["memory_target"] == 70;
}


test "a per-service hpa key still beats the config-level bound" {
    auto = _autoscaler(
        KubernetesConfig(
            app_name="shop",
            namespace="shop-ns",
            bundle_storage_class="standard",
            min_replicas=3,
            max_replicas=5,
            cpu_utilization_target=40
        ),
        {"api": {"file": "api.jac", "hpa": {"min": 2, "max": 9}}}
    );
    assert auto["min"] == 2;
    assert auto["max"] == 9;
    assert auto["cpu_target"] == 40;
}


test "nothing configured keeps the built-in defaults" {
    auto = _autoscaler(
        KubernetesConfig(
            app_name="shop", namespace="shop-ns", bundle_storage_class="standard"
        ),
        {"api": {"file": "api.jac"}}
    );
    assert auto["min"] == 1;
    assert auto["max"] == 3;
    assert auto["cpu_target"] == 50;
    assert auto["memory_target"] == 80;
}
