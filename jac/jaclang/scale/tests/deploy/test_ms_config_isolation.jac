import unittest.mock;
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
    ManifestBuilder,
    k8s_safe_name
}
import jaclang.scale.deploy.target.kubernetes.manifest_builder as builder_mod;

# What an embedding host (a jac-scale app that deploys other apps in-process)
# has loaded process-globally while it deploys a guest app.
glob _HOST_CONFIG: dict = {
         "routes": {"builder_sv": "/builder"},
         "shared_volumes": [
             {
                 "name": "${SHARED_DATA_PVC}",
                 "mount_path": "/app/.jachome",
                 "services": ["builder_sv"],
                 "size": "10Gi",
                 "access_mode": "ReadWriteMany",
                 "storage_class": "efs-sc"
             }
         ]
     };


def _host_scale_config -> any {
    cfg = unittest.mock.MagicMock();
    cfg.get_microservices_config.return_value = _HOST_CONFIG;
    return cfg;
}


test "a guest app that declares no microservices config gets none of the host's" {
    builder = ManifestBuilder(
        k8s_config=KubernetesConfig(app_name="standup", namespace="jb-standup"),
        microservices_config={}
    );

    with unittest.mock.patch.object(
        builder_mod, "get_scale_config", _host_scale_config
    ) {
        resolved = builder._ms_cfg();
    }

    assert resolved.get("shared_volumes", []) == [] , f"guest inherited the host's shared_volumes: {resolved.get(
        'shared_volumes'
    )}";
    assert resolved.get("routes", {}) == {} , f"guest inherited the host's routes: {resolved.get(
        'routes'
    )}";
}


test "a guest app's manifest bundle carries no PVC from the host's config" {
    builder = ManifestBuilder(
        k8s_config=KubernetesConfig(app_name="standup", namespace="jb-standup"),
        microservices_config={}
    );

    with unittest.mock.patch.object(
        builder_mod, "get_scale_config", _host_scale_config
    ) {
        pvcs = builder._build_shared_pvc_manifests();
    }

    assert pvcs == {} , f"host shared_volumes leaked into the guest bundle: {pvcs}";
}


test "an omitted microservices config still falls back to the loaded one" {
    builder = ManifestBuilder(
        k8s_config=KubernetesConfig(app_name="standup", namespace="jb-standup")
    );

    with unittest.mock.patch.object(
        builder_mod, "get_scale_config", _host_scale_config
    ) {
        resolved = builder._ms_cfg();
    }

    assert resolved.get("routes", {}) == {"builder_sv": "/builder"};
}


test "a caller-supplied config does not take routes from JAC_SV_ROUTES" {
    builder = ManifestBuilder(
        k8s_config=KubernetesConfig(app_name="standup", namespace="jb-standup"),
        microservices_config={}
    );

    with unittest.mock.patch.dict(
        "os.environ", {"JAC_SV_ROUTES": '{"builder_sv": "/builder"}'}
    ) {
        with unittest.mock.patch.object(
            builder_mod, "get_scale_config", _host_scale_config
        ) {
            resolved = builder._ms_cfg();
        }
    }

    assert resolved.get("routes", {}) == {} , f"guest inherited the host's routes via env: {resolved.get(
        'routes'
    )}";
}


test "k8s_safe_name only ever yields an RFC 1123 name" {
    import re;
    rfc1123 = re.compile(r"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$");
    for raw in [
        "shared_data_pvc",
        "Orders_App",
        "-leading",
        "trailing-",
        "vol!name",
        "a" * 300,
        "under__scores"
    ] {
        safe = k8s_safe_name(raw);
        assert rfc1123.match(safe) , f"{raw!r} produced non-RFC-1123 name {safe!r}";
        assert len(safe) <= 253 , f"{raw!r} produced a {len(safe)}-char name";
    }
}


# An unresolved placeholder is an operator error, not a name to be cleaned up:
# sanitizing "${SHARED_DATA_PVC}" to "shared-data-pvc" would quietly provision a
# volume nobody asked for.
test "k8s_safe_name refuses an unresolved env placeholder" {
    raised = False;
    try {
        k8s_safe_name("${SHARED_DATA_PVC}");
    } except ValueError as e {
        raised = True;
        assert "SHARED_DATA_PVC" in str(e);
        assert "placeholder" in str(e);
    }
    assert raised , "expected an unresolved placeholder to raise";
}


test "k8s_safe_name rejects a name with nothing usable left" {
    raised = False;
    try {
        k8s_safe_name("!!!");
    } except ValueError as e {
        raised = True;
        assert "!!!" in str(e);
    }
    assert raised , "expected a name with no usable characters to raise";
}


test "the gateway keeps its reserved short name" {
    import from jaclang.scale.deploy.target.kubernetes.manifest_builder { GATEWAY_NAME }
    assert k8s_safe_name(GATEWAY_NAME) == "gateway";
}
