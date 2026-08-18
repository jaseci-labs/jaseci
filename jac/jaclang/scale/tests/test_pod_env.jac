import os;
import json;
import unittest.mock as mock;
import from pathlib { Path }
import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
    ManifestBuilder,
    GATEWAY_NAME
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.deploy.target.kubernetes.runtime_resolver {
    build_k8s_registry,
    K8sRuntimeServiceResolver
}
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry
}
import from jaclang.runtimelib.sv_client { peer_url_env_key }


glob _K8S_E2E_FIXTURE: Path = Path(__file__).parent / "fixtures" / "k8s_e2e",
     _DISCOVERED_ROUTES: dict[str, str] = {
         "cart_app": "/cart",
         "orders_app": "/orders",
         "products_app": "/products",
         "main": "/__main__"
     };


# A declared [scale.microservices.routes] table (#7772) is the authoritative
# service cut: every key becomes its own pod. Driven through the real builder via
# a real microservices_config, not a patched _ms_cfg / _build_*_pod_spec.
test "generate_service_pod_specs builds one pod per declared route" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    declared = {
        "routes": {
            "products_app": "/products",
            "orders_app": "/orders",
            "cart_app": "/cart"
        }
    };
    builder = ManifestBuilder(
        k8s_config=cfg, project_dir=str(_K8S_E2E_FIXTURE), microservices_config=declared
    );
    app_cfg = AppConfig(code_folder=str(_K8S_E2E_FIXTURE), app_name="jac-shop");

    specs = builder.generate_service_pod_specs(app_cfg, "img");

    assert set(specs.keys())
        == {"products_app", "orders_app", "cart_app", "main", GATEWAY_NAME};
    orders_env = {
        e["name"]: e["value"] for e in specs["orders_app"]["containers"][0]["env"]
    };
    assert json.loads(orders_env["JAC_SV_ROUTES"]) == _DISCOVERED_ROUTES;
}


test "an app with no declared routes deploys as one service plus the gateway" {
    cfg = KubernetesConfig(app_name="littlex", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg, microservices_config={"routes": {}});
    app_cfg = AppConfig(code_folder="/apps/littlex", file_name="main.jac");

    specs = builder.generate_service_pod_specs(app_cfg, "img");

    # named after the app, not its entry file: main.jac must not turn every
    # monolith into a "main" service.
    assert set(specs.keys()) == {"littlex", GATEWAY_NAME};
    assert builder.microservices_config["routes"] == {"littlex": "/littlex"};
    env = {e["name"]: e["value"] for e in specs["littlex"]["containers"][0]["env"]};
    assert env["JAC_SV_NAME"] == "littlex";
    assert env["JAC_SV_FILE"] == "main.jac";
}


test "a solo app whose name shadows a builtin route is rejected" {
    cfg = KubernetesConfig(app_name="admin", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg, microservices_config={"routes": {}});
    app_cfg = AppConfig(code_folder="/apps/admin", file_name="main.jac");

    raised = False;
    try {
        builder.generate_service_pod_specs(app_cfg, "img");
    } except ValueError as e {
        raised = True;
        assert "builtin" in str(e);
    }
    assert raised , "expected the reserved-name guard to fire";
}


test "every generated deployment rolls with surge, never delete-and-recreate" {
    cfg = KubernetesConfig(app_name="littlex", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg);
    for name in ["littlex", GATEWAY_NAME] {
        manifest = builder._build_deployment_manifest(name, {});
        strategy = manifest["spec"]["strategy"];
        assert strategy["type"] == "RollingUpdate";
        assert strategy["rollingUpdate"] == {"maxSurge": 1, "maxUnavailable": 0};
    }
}


test "build_env omits JAC_SV_ROUTES when no routes are declared" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg, microservices_config={"routes": {}});

    env = builder._build_env("orders_app", {});

    assert "JAC_SV_ROUTES" not in {e["name"] for e in env};
}

test "build_env injects K8S_APP_NAME and K8S_NAMESPACE from k8s_config" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    builder = ManifestBuilder(k8s_config=cfg);

    env = builder._build_env("orders", {});

    pairs = {entry["name"]: entry["value"] for entry in env};
    assert pairs.get("JAC_SV_NAME") == "orders";
    assert pairs.get("K8S_APP_NAME") == "jac-shop";
    assert pairs.get("K8S_NAMESPACE") == "jac-shop-dev";
}


test "build_env keeps per-service overrides but never shadows the K8S_* vars" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    builder = ManifestBuilder(k8s_config=cfg);

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


test "the gateway pod never rebuilds the client at boot" {
    # The deploy builds the client bundle on the host and fails fast when
    # that build fails; the pod serves what shipped and must not retry.
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg);
    with mock.patch.object(builder, "_client_entry", return_value="main.jac") {
        entry = builder._pod_entrypoint();
    }
    args = entry["args"][0];
    assert "jac build" not in args;
    assert "exec jac scale gateway" in args;
}


test "no client entry means no client build in the gateway entrypoint" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg);
    with mock.patch.object(builder, "_client_entry", return_value="") {
        entry = builder._pod_entrypoint();
    }
    assert "jac build" not in entry["args"][0];
}


test "a single-file full-stack app still gets its client bundle built" {
    import tempfile;
    import os;
    with tempfile.TemporaryDirectory() as tmp {
        with open(os.path.join(tmp, "jac.toml"), "w") as f {
            f.write("[project]\nname = \"todo-app\"\n\n[client]\n");
        }
        cfg = KubernetesConfig(app_name="todo-app", namespace="ns");
        builder = ManifestBuilder(k8s_config=cfg, project_dir=tmp);
        assert builder._has_client_source();
        assert builder._client_entry() == "main.jac";
    }
}


# Peer URL resolution. jac-scale injects a JAC_SV_<PEER>_URL for every peer, so
# the registry must read it rather than deriving every URL from the route name.
# The env key keeps the raw route name while Kubernetes names are RFC1123-safe,
# so orders_app injects JAC_SV_ORDERS_APP_URL beside an orders-app-service; a
# reader keyed off the safe name would miss and fall back to the derived URL.

glob _PEER_ROUTES: dict[str, str] = {"orders_app": "/orders", "cart_app": "/cart"},
     _PEER_NS: str = "shop",
     _PEER_PORT: int = 8000,
     _ORDERS_DERIVED: str = "http://orders-app-service.shop.svc.cluster.local:8000",
     _CART_DERIVED: str = "http://cart-app-service.shop.svc.cluster.local:8000";


def _peer_env_snapshot -> dict[str, str | None] {
    keys = [peer_url_env_key(name) for name in _PEER_ROUTES.keys()];
    keys.append("POD_NAMESPACE");
    return {key: os.environ.get(key) for key in keys};
}


def _peer_env_restore(saved: dict[str, str | None]) {
    for (key, value) in saved.items() {
        if value is None {
            os.environ.pop(key, None);
        } else {
            os.environ[key] = value;
        }
    }
}


def _peer_env_isolate {
    for name in _PEER_ROUTES.keys() {
        os.environ.pop(peer_url_env_key(name), None);
    }
    os.environ["POD_NAMESPACE"] = _PEER_NS;
}


def _peer_builder -> ManifestBuilder {
    cfg = KubernetesConfig(
        app_name="jac-shop", namespace=_PEER_NS, container_port=_PEER_PORT
    );
    return ManifestBuilder(
        k8s_config=cfg,
        project_dir=str(_K8S_E2E_FIXTURE),
        microservices_config={"routes": dict(_PEER_ROUTES)}
    );
}


def _peer_env_of(svc_name: str) -> dict[str, str] {
    app_cfg = AppConfig(code_folder=str(_K8S_E2E_FIXTURE), app_name="jac-shop");
    specs = _peer_builder().generate_service_pod_specs(app_cfg, "img");
    return {
        entry["name"]: entry["value"]
        for entry in specs[svc_name]["containers"][0]["env"]
    };
}


test "a peer with no override resolves by naming convention" {
    saved = _peer_env_snapshot();
    try {
        _peer_env_isolate();

        registry = build_k8s_registry(_PEER_ROUTES, _PEER_PORT);

        assert registry["orders_app"] == _ORDERS_DERIVED , (
            f"expected the derived URL, got {registry['orders_app']}"
        );
        assert registry["cart_app"] == _CART_DERIVED;
    } finally {
        _peer_env_restore(saved);
    }
}


test "an override wins for its own peer and leaves the others derived" {
    saved = _peer_env_snapshot();
    try {
        _peer_env_isolate();
        standby = "http://orders-app-standby-service.shop.svc.cluster.local:8000";
        os.environ[peer_url_env_key("orders_app")] = standby;

        registry = build_k8s_registry(_PEER_ROUTES, _PEER_PORT);

        assert registry["orders_app"] == standby;
        assert registry["cart_app"] == _CART_DERIVED , (
            "an override for one peer must not affect another"
        );
    } finally {
        _peer_env_restore(saved);
    }
}


# A pod never given an override and one whose override was blanked must behave
# the same, or clearing a value would break routing instead of restoring it.
test "a blank override falls back to the derived URL" {
    saved = _peer_env_snapshot();
    try {
        _peer_env_isolate();
        os.environ[peer_url_env_key("orders_app")] = "   ";

        registry = build_k8s_registry(_PEER_ROUTES, _PEER_PORT);

        assert registry["orders_app"] == _ORDERS_DERIVED;
    } finally {
        _peer_env_restore(saved);
    }
}


# The literal is asserted rather than derived from peer_url_env_key, so a change
# to that helper fails here instead of moving both sides together. The override
# is a value the derivation cannot produce, so reading the wrong key shows up as
# a failure rather than an accidental match.
test "the key the builder injects is the key the registry reads" {
    saved = _peer_env_snapshot();
    try {
        _peer_env_isolate();
        cart_env = _peer_env_of("cart_app");

        assert "JAC_SV_ORDERS_APP_URL" in cart_env , (
            "the builder no longer injects the underscore-preserving key; "
            f"it wrote {sorted(cart_env.keys())}"
        );

        standby = "http://orders-app-standby-service.shop.svc.cluster.local:8000";
        os.environ["JAC_SV_ORDERS_APP_URL"] = standby;
        registry = build_k8s_registry(_PEER_ROUTES, _PEER_PORT);

        assert registry["orders_app"] == standby , (
            "the registry did not read the key the builder wrote, so it "
            f"resolved {registry['orders_app']}"
        );
    } finally {
        _peer_env_restore(saved);
    }
}


# Reading the env must be a no-op for existing deployments, which holds only
# while the injector and the resolver agree on namespace and port.
test "the injected default equals the derived URL under matching config" {
    saved = _peer_env_snapshot();
    try {
        _peer_env_isolate();

        cart_env = _peer_env_of("cart_app");

        assert cart_env[peer_url_env_key("orders_app")] == _ORDERS_DERIVED , (
            "injected and derived URLs diverged, so reading the env would "
            "change behavior for existing pods"
        );
    } finally {
        _peer_env_restore(saved);
    }
}


# K8sRuntimeServiceResolver.url_for is the other k8s resolution site. It is
# dormant today, but it must not become the one path that bypasses an override
# once the admin ops that construct it are wired up.
def _peer_resolver -> K8sRuntimeServiceResolver {
    return K8sRuntimeServiceResolver(
        registry=ServiceRegistry(), namespace=_PEER_NS, port=_PEER_PORT
    );
}


test "url_for uses the override when one is set" {
    saved = _peer_env_snapshot();
    try {
        _peer_env_isolate();
        standby = "http://orders-app-standby-service.shop.svc.cluster.local:8000";
        os.environ[peer_url_env_key("orders_app")] = standby;

        entry = ServiceEntry(
            name="orders_app", file="orders_app.jac", prefix="/orders"
        );

        assert _peer_resolver().url_for(entry) == standby;
    } finally {
        _peer_env_restore(saved);
    }
}


test "url_for derives when no override is set" {
    saved = _peer_env_snapshot();
    try {
        _peer_env_isolate();

        entry = ServiceEntry(
            name="orders_app", file="orders_app.jac", prefix="/orders"
        );

        assert _peer_resolver().url_for(entry) == _ORDERS_DERIVED;
    } finally {
        _peer_env_restore(saved);
    }
}
