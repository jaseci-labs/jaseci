"""--show-yaml must print the autoscaler objects a deploy would apply. The
bundle carries autoscaler CONFIGS, not manifests; render_autoscaler_manifests
turns them into the same objects the apply path builds, from the same spec."""

import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.target { KubernetesTarget }
import from jaclang.scale.deploy.target.kubernetes.manifest_builder { ScalingMode }


test "hpa engine renders the HPA manifest the apply path would build" {
    target = KubernetesTarget(config=KubernetesConfig(app_name="t", namespace="t-ns"));
    bundle = {
        "scaling": {
            "api": {
                "mode": ScalingMode.METRIC,
                "autoscaler": {"min": 2, "max": 7, "cpu_target": 60}
            }
        }
    };
    manifests = target.render_autoscaler_manifests(bundle);
    assert len(manifests) == 1;
    m = manifests[0];
    assert m["kind"] == "HorizontalPodAutoscaler";
    assert m["metadata"]["namespace"] == "t-ns";
    assert m["spec"]["scaleTargetRef"]["name"] == "api-deployment";
    assert m["spec"]["minReplicas"] == 2;
    assert m["spec"]["maxReplicas"] == 7;
}


test "keda engine renders the ScaledObject body, not the name/body wrapper" {
    target = KubernetesTarget(
        config=KubernetesConfig(
            app_name="t", namespace="t-ns", autoscaler_engine="keda"
        )
    );
    bundle = {
        "scaling": {
            "api": {"mode": ScalingMode.METRIC, "autoscaler": {"min": 1, "max": 4}}
        }
    };
    manifests = target.render_autoscaler_manifests(bundle);
    assert len(manifests) == 1;
    m = manifests[0];
    assert m["kind"] == "ScaledObject";
    assert m["spec"]["scaleTargetRef"]["name"] == "api-deployment";
    assert m["spec"]["minReplicaCount"] == 1;
    assert m["spec"]["maxReplicaCount"] == 4;
}


test "a service scaled by http_activation renders no autoscaler manifest" {
    target = KubernetesTarget(config=KubernetesConfig(app_name="t", namespace="t-ns"));
    bundle = {
        "scaling": {
            "api": {"mode": ScalingMode.HTTP_ACTIVATION, "autoscaler": {}}
        }
    };
    assert target.render_autoscaler_manifests(bundle) == [];
}


test "a bundle with no scaling renders nothing" {
    target = KubernetesTarget(config=KubernetesConfig(app_name="t", namespace="t-ns"));
    assert target.render_autoscaler_manifests({"deployments": {}}) == [];
}
