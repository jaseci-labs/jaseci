"""[scale.kubernetes] has one place a default can live: the has-declaration.

Defaults used to be restated at five hops - the schema table, the loader's
get_default_config literal, the KubernetesConfig declaration, from_dict's
per-key config.get(key, literal), and again at each manifest consumer - so a
declared key could be dropped or re-defaulted at any hop and the result was
indistinguishable from the user never setting it. That produced #8401 (a
field missing from from_dict's hand enumeration), #8850 (the manifest builder
re-defaulting bounds it had been handed), and the drift the loader's own probe
defaults needed a test to police.

The converters now derive from fields(KubernetesConfig), so no hop can restate
a default. These tests hold the contract closed from both ends: every declared
field is either a schema-declared key or a documented loader-derived one, the
schema and the declaration agree on every default they share, and a value the
user writes survives the whole path to the rendered manifest.
"""

import tempfile;
import from pathlib { Path }
import from jaclang.comptime { fields }
import from jaclang.scale.config.config_loader { JacScaleConfig }
import from jaclang.scale.config.plugin_config { JacScalePluginConfig }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}

# Fields get_kubernetes_config assigns after loading, from [scale.monitoring],
# [scale.admin] and the system plugin deps. Declaring them under
# [scale.kubernetes] would validate a value that is then overwritten.
# app_name is exempted separately: the schema's None means "derive a slug from
# [project].name", while the declaration's 'jaseci' is the fallback when no
# project name is usable. Two questions, deliberately two answers.
glob _LOADER_DERIVED: set[str] = {
         "admin_username",
         "monitoring_enabled",
         "k8s_metrics_enabled",
         "prometheus_admin_password",
         "service_dependencies"
     },
     _DECLARED_ELSEWHERE: set[str] = {"app_name"};


def _k8s_schema_options -> dict[str, any] {
    return JacScalePluginConfig.get_config_schema()["options"]["kubernetes"]["nested"];
}


test "every declared field is a schema key or a documented derived one" {
    opts = _k8s_schema_options();
    undeclared: list[str] = [];
    for f in fields(KubernetesConfig) {
        if f.name in _LOADER_DERIVED {
            continue;
        }
        if f.name not in opts {
            undeclared.append(f.name);
        }
    }
    assert sorted(undeclared) == [] , (
        f"KubernetesConfig declares {sorted(undeclared)}, which [scale.kubernetes] "
        "never names, so a user setting one is warned it is unknown while the "
        "loader uses it"
    );
}


test "the schema and the declaration agree on every default they share" {
    opts = _k8s_schema_options();
    declared = KubernetesConfig();
    drift: list[str] = [];
    for f in fields(KubernetesConfig) {
        if f.name in _LOADER_DERIVED or f.name in _DECLARED_ELSEWHERE {
            continue;
        }
        spec = opts.get(f.name);
        if not isinstance(spec, dict) {
            continue;
        }
        if spec.get("default") != getattr(declared, f.name) {
            drift.append(
                f"{f.name}: schema={spec.get('default')!r} "
                f"declaration={getattr(declared, f.name)!r}"
            );
        }
    }
    assert sorted(drift) == [] , (
        "the schema documents a different default than the declaration applies, "
        f"so the documented value is a lie for: {sorted(drift)}"
    );
}


test "no key is dropped between to_dict and from_dict" {
    base = KubernetesConfig().to_dict();
    for f in fields(KubernetesConfig) {
        assert f.name in base , (f"to_dict omits the declared field '{f.name}'");
    }
    for (key, value) in base.items() {
        if key == "database_mode" {
            continue;
        }
        mutated: any = None;
        if isinstance(value, bool) {
            mutated = not value;
        } elif isinstance(value, int) {
            mutated = value + 1;
        } elif isinstance(value, str) {
            mutated = value + "x";
        } elif isinstance(value, dict) {
            mutated = {"probe": "probe"};
        } elif isinstance(value, list) {
            mutated = ["probe"];
        } else {
            continue;
        }
        src = dict(base);
        src[key] = mutated;
        out = KubernetesConfig.from_dict(KubernetesConfig, src).to_dict();
        assert out[key] == mutated , f"from_dict drops '{key}'";
    }
}


test "an unwritten key resolves to the declaration, not to a hop's literal" {
    with tempfile.TemporaryDirectory() as project {
        (Path(project) / "jac.toml").write_text(
            '[project]\nname = "decl-app"\nversion = "0.0.1"\n'
        );
        k8s = JacScaleConfig(project_dir=Path(project)).get_kubernetes_config();
        declared = KubernetesConfig();
        for name in [
            "min_replicas",
            "max_replicas",
            "cpu_utilization_target",
            "memory_utilization_target",
            "readiness_initial_delay",
            "liveness_failure_threshold",
            "container_port"
        ] {
            assert k8s[name] == getattr(declared, name) , (
                f"{name} resolved to {k8s[name]!r}, not the declared "
                f"{getattr(declared, name)!r}"
            );
        }
    }
}


test "a written key survives the whole path" {
    with tempfile.TemporaryDirectory() as project {
        (Path(project) / "jac.toml").write_text(
            '[project]\n'
            'name = "decl-app"\n'
            'version = "0.0.1"\n'
            '\n'
            '[scale.kubernetes]\n'
            'min_replicas = 3\n'
            'max_replicas = 9\n'
            'cpu_utilization_target = 40\n'
            'liveness_failure_threshold = 12\n'
            '\n'
            '[scale.admin]\n'
            'username = "metrics-admin"\n'
        );
        k8s = JacScaleConfig(project_dir=Path(project)).get_kubernetes_config();
        assert k8s["min_replicas"] == 3;
        assert k8s["max_replicas"] == 9;
        assert k8s["cpu_utilization_target"] == 40;
        assert k8s["liveness_failure_threshold"] == 12;
        assert k8s["admin_username"] == "metrics-admin";
        assert k8s["app_name"] == "decl-app";
    }
}


test "a config that cannot be read fails loudly instead of deploying a monolith" {
    import from jaclang.scale.config.config_loader {
        get_scale_config,
        reset_scale_config
    }
    import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
        ManifestBuilder
    }
    reset_scale_config();
    with tempfile.TemporaryDirectory() as project {
        (Path(project) / "jac.toml").write_text(
            '[project]\n'
            'name = "broken-app"\n'
            'version = "0.0.1"\n'
            '\n'
            '[scale.microservices\n'
            'enabled = true\n'
        );
        try {
            get_scale_config(project_dir=Path(project));
            builder = ManifestBuilder(
                k8s_config=KubernetesConfig(
                    app_name="broken-app", namespace="broken-ns"
                )
            );
            raised = "";
            try {
                builder._service_config("api");
            } except Exception as e {
                raised = str(e);
            }
            assert raised != "" , (
                "an unreadable [scale.microservices] answered {} instead of "
                "raising, so the deploy would have proceeded on a topology "
                "the user never configured"
            );
            assert "jac.toml" in raised , (
                f"the failure {raised!a} does not name the file it could not read"
            );
            assert "scale.microservices" in raised , (
                f"the failure {raised!a} does not name the section"
            );
        } finally {
            reset_scale_config();
        }
    }
}


test "every microservices reader refuses rather than answering a default" {
    import from jaclang.scale.config.config_loader {
        get_scale_config,
        reset_scale_config
    }
    import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
        ManifestBuilder
    }
    reset_scale_config();
    with tempfile.TemporaryDirectory() as project {
        (Path(project) / "jac.toml").write_text(
            '[project]\nname = "broken-app"\n[scale.microservices\n'
        );
        try {
            get_scale_config(project_dir=Path(project));
            builder = ManifestBuilder(
                k8s_config=KubernetesConfig(
                    app_name="broken-app", namespace="broken-ns"
                )
            );
            answered: list[str] = [];
            try {
                builder._drain_timeout();
                answered.append("_drain_timeout");
            } except Exception {}
            try {
                builder._microservice_routes();
                answered.append("_microservice_routes");
            } except Exception {}
            try {
                builder._shared_volumes_config();
                answered.append("_shared_volumes_config");
            } except Exception {}
            try {
                builder._service_config("api");
                answered.append("_service_config");
            } except Exception {}
            assert sorted(answered) == [] , (
                f"{sorted(answered)} answered a default for a config that could "
                "not be read, which is indistinguishable from the user "
                "configuring nothing"
            );
        } finally {
            reset_scale_config();
        }
    }
}
