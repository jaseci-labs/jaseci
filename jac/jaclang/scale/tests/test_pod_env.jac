import json;
import unittest.mock as mock;
import from pathlib { Path }
import from jaclang.scale.deploy.target.kubernetes.microservice.manifest_builder {
    MicroserviceManifestBuilder,
    GATEWAY_NAME
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.config.config_loader { get_scale_config, reset_scale_config }


glob _K8S_E2E_FIXTURE: Path = Path(__file__).parent / "fixtures" / "k8s_e2e",
     _DISCOVERED_ROUTES: dict[str, str] = {
         "cart_app": "/cart",
         "orders_app": "/orders",
         "products_app": "/products"
     };


# Routes the real discovery derives from the k8s_e2e fixture's `sv` graph.
# No [scale.microservices.routes] table exists; these come from `sv import`.
test "generate_service_pod_specs auto-discovers services when no routes declared" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = MicroserviceManifestBuilder(
        k8s_config=cfg, project_dir=str(_K8S_E2E_FIXTURE)
    );
    app_cfg = AppConfig(code_folder=str(_K8S_E2E_FIXTURE), app_name="jac-shop");

    specs = builder.generate_service_pod_specs(app_cfg, "img");

    assert "products_app" in specs;
    assert "orders_app" in specs;
    assert "cart_app" in specs;
    assert GATEWAY_NAME in specs;

    orders_env = specs["orders_app"]["containers"][0]["env"];
    pairs = {e["name"]: e["value"] for e in orders_env};
    assert json.loads(pairs["JAC_SV_ROUTES"]) == _DISCOVERED_ROUTES;
    assert pairs["JAC_SV_NAME"] == "orders_app";
    assert pairs["K8S_APP_NAME"] == "jac-shop";
    assert pairs["K8S_NAMESPACE"] == "ns";
}


test "build_env injects JAC_SV_ROUTES so pods get routes without a toml table" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = MicroserviceManifestBuilder(
        k8s_config=cfg, project_dir=str(_K8S_E2E_FIXTURE)
    );
    app_cfg = AppConfig(code_folder=str(_K8S_E2E_FIXTURE), app_name="jac-shop");
    # real discovery populates the builder's routes from the fixture sv graph
    builder.generate_service_pod_specs(app_cfg, "img");

    env = builder._build_env("orders_app", {});

    pairs = {e["name"]: e["value"] for e in env};
    assert "JAC_SV_ROUTES" in pairs;
    assert json.loads(pairs["JAC_SV_ROUTES"]) == _DISCOVERED_ROUTES;
}

test "build_env omits JAC_SV_ROUTES when there are no routes" {
    # The fixture's static toml declares no routes table; a builder fed that
    # real config (without running discovery) must inject no JAC_SV_ROUTES.
    reset_scale_config();
    ms_cfg = get_scale_config(_K8S_E2E_FIXTURE).get_microservices_config();
    reset_scale_config();
    assert ms_cfg["routes"] == {};

    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = MicroserviceManifestBuilder(k8s_config=cfg, microservices_config=ms_cfg);

    env = builder._build_env("orders_app", {});

    assert "JAC_SV_ROUTES" not in {e["name"] for e in env};
}

test "build_env injects K8S_APP_NAME and K8S_NAMESPACE from k8s_config" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    builder = MicroserviceManifestBuilder(k8s_config=cfg);

    env = builder._build_env("orders", {});

    pairs = {entry["name"]: entry["value"] for entry in env};
    assert pairs.get("JAC_SV_NAME") == "orders";
    assert pairs.get("K8S_APP_NAME") == "jac-shop";
    assert pairs.get("K8S_NAMESPACE") == "jac-shop-dev";
}


test "build_env keeps per-service overrides but never shadows the K8S_* vars" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    builder = MicroserviceManifestBuilder(k8s_config=cfg);

    env = builder._build_env(
        "orders", {"env": {"STRIPE_KEY": "sk_test", "K8S_APP_NAME": "evil"}}
    );

    names = [entry["name"] for entry in env];
    assert "STRIPE_KEY" in names;

    first_app_name = next(
        (
            e["value"]
            for e in env
            if e["name"] == "K8S_APP_NAME"
        ),
        None
    );
    assert first_app_name == "jac-shop";
}


test "gateway pod client-build fallback uses --client web, not the typecheck-gated full build" {
    # A bare `jac build` gates on the whole-project type-check, so a
    # type-error app silently shipped without its client and / served a 404.
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = MicroserviceManifestBuilder(k8s_config=cfg);
    with mock.patch.object(builder, "_client_entry", return_value="main.jac") {
        entry = builder._pod_entrypoint();
    }
    args = entry["args"][0];
    assert 'jac build "main.jac" --client web' in args;
    assert "[ ! -f .jac/client/dist/index.html ]" in args;
    assert 'jac build "main.jac" ||' not in args;
}


test "no client entry means no client build in the gateway entrypoint" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = MicroserviceManifestBuilder(k8s_config=cfg);
    with mock.patch.object(builder, "_client_entry", return_value="") {
        entry = builder._pod_entrypoint();
    }
    assert "jac build" not in entry["args"][0];
}
