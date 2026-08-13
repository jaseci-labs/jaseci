"""Peer URL overrides: what jac-scale injects is what the registry reads.

In Kubernetes mode every peer URL used to be derived from the route name, so the
`JAC_SV_<PEER>_URL` env the manifest builder injects into every pod was dead. A
platform could not point a pod set at alternate service names without editing
jac-scale-owned objects.

The round-trip test is the regression guard for the key format. `k8s_safe_name`
lowercases and maps "_" to "-", so a resolver that derived the env key from the
safe name would miss every route whose name contains an underscore and silently
fall back to the derived URL, which is indistinguishable from the old bug.

Real builders and real environment variables throughout.
"""

import os;
import from pathlib { Path }
import from jaclang.runtimelib.sv_client { peer_url_env_key }
import from jaclang.scale.deploy.target.kubernetes.runtime_resolver {
    build_k8s_registry
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
    ManifestBuilder
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.config.app_config { AppConfig }


glob _FIXTURE: Path = Path(str(__file__)).parent / "fixtures" / "k8s_e2e",
     _ROUTES: dict[str, str] = {"orders_app": "/orders", "cart_app": "/cart"},
     _NS: str = "shop",
     _PORT: int = 8000,
     _ORDERS_DERIVED: str =
         "http://orders-app-service.shop.svc.cluster.local:8000",
     _CART_DERIVED: str = "http://cart-app-service.shop.svc.cluster.local:8000";


def _managed_keys -> list[str] {
    keys = [peer_url_env_key(name) for name in _ROUTES.keys()];
    keys.append("POD_NAMESPACE");
    return keys;
}


def _snapshot -> dict[str, str | None] {
    return {key: os.environ.get(key) for key in _managed_keys()};
}


def _restore(saved: dict[str, str | None]) {
    for (key, value) in saved.items() {
        if value is None {
            os.environ.pop(key, None);
        } else {
            os.environ[key] = value;
        }
    }
}


def _isolate {
    for name in _ROUTES.keys() {
        os.environ.pop(peer_url_env_key(name), None);
    }
    os.environ["POD_NAMESPACE"] = _NS;
}


test "a peer with no override resolves by naming convention" {
    saved = _snapshot();
    try {
        _isolate();

        registry = build_k8s_registry(_ROUTES, _PORT);

        assert registry["orders_app"] == _ORDERS_DERIVED , (
            f"expected the convention-derived URL, got {registry['orders_app']}"
        );
        assert registry["cart_app"] == _CART_DERIVED;
    } finally {
        _restore(saved);
    }
}


test "an override wins for its own peer and leaves the others derived" {
    saved = _snapshot();
    try {
        _isolate();
        standby = "http://orders-app-standby-service.shop.svc.cluster.local:8000";
        os.environ[peer_url_env_key("orders_app")] = standby;

        registry = build_k8s_registry(_ROUTES, _PORT);

        assert registry["orders_app"] == standby , (
            "the injected override must win over the derived URL"
        );
        assert registry["cart_app"] == _CART_DERIVED , (
            "an override for one peer must not affect another"
        );
    } finally {
        _restore(saved);
    }
}


# A pod that was never given an override, and one whose override was blanked,
# must behave identically. Otherwise clearing a value would break routing
# instead of restoring the default.
test "a blank override falls back to the derived URL" {
    saved = _snapshot();
    try {
        _isolate();
        os.environ[peer_url_env_key("orders_app")] = "   ";

        registry = build_k8s_registry(_ROUTES, _PORT);

        assert registry["orders_app"] == _ORDERS_DERIVED;
    } finally {
        _restore(saved);
    }
}


# The regression guard, and the reason the key format is defined in one place.
# The literal is asserted rather than derived from peer_url_env_key, so a change
# to that helper fails here instead of silently moving both sides together. A
# resolver keying off k8s_safe_name would look for JAC_SV_ORDERS-APP_URL, miss,
# and fall back to the derived URL, which looks exactly like the bug being fixed.
# Hence the override below is a value the derivation cannot produce.
test "the key the manifest builder injects is the key the registry reads" {
    saved = _snapshot();
    try {
        _isolate();
        cfg = KubernetesConfig(
            app_name="jac-shop", namespace=_NS, container_port=_PORT
        );
        builder = ManifestBuilder(
            k8s_config=cfg,
            project_dir=str(_FIXTURE),
            microservices_config={"routes": dict(_ROUTES)}
        );
        app_cfg = AppConfig(code_folder=str(_FIXTURE), app_name="jac-shop");

        specs = builder.generate_service_pod_specs(app_cfg, "img");
        cart_env = {
            entry["name"]: entry["value"]
            for entry in specs["cart_app"]["containers"][0]["env"]
        };

        assert "JAC_SV_ORDERS_APP_URL" in cart_env , (
            "the builder no longer injects the underscore-preserving key; "
            f"it wrote {sorted(cart_env.keys())}"
        );

        standby = "http://orders-app-standby-service.shop.svc.cluster.local:8000";
        os.environ["JAC_SV_ORDERS_APP_URL"] = standby;
        registry = build_k8s_registry(_ROUTES, _PORT);

        assert registry["orders_app"] == standby , (
            "the registry did not read the key the builder wrote, so the "
            f"override was ignored and it resolved {registry['orders_app']}"
        );
    } finally {
        _restore(saved);
    }
}


# Reading the env must be a no-op for existing deployments. That holds only
# while the injector and the resolver agree on namespace and port, so assert it
# rather than assuming it.
test "the injected default equals the derived URL under matching config" {
    saved = _snapshot();
    try {
        _isolate();
        cfg = KubernetesConfig(
            app_name="jac-shop", namespace=_NS, container_port=_PORT
        );
        builder = ManifestBuilder(
            k8s_config=cfg,
            project_dir=str(_FIXTURE),
            microservices_config={"routes": dict(_ROUTES)}
        );
        app_cfg = AppConfig(code_folder=str(_FIXTURE), app_name="jac-shop");

        specs = builder.generate_service_pod_specs(app_cfg, "img");
        cart_env = {
            entry["name"]: entry["value"]
            for entry in specs["cart_app"]["containers"][0]["env"]
        };

        assert cart_env[peer_url_env_key("orders_app")] == _ORDERS_DERIVED , (
            "injected and derived URLs diverged, so reading the env would "
            "change behavior for existing pods"
        );
    } finally {
        _restore(saved);
    }
}
