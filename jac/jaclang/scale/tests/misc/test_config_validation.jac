import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.config.validation {
    validate_scale_config,
    warn_unknown_scale_keys
}
import from jaclang.scale.config.plugin_config { JacScalePluginConfig }
import from jaclang.scale.config.config_loader {
    JacScaleConfig,
    get_scale_config,
    reset_scale_config
}

def _collect_default_mismatches(
    options: dict[str, any], defaults: dict[str, any], path: str, bad: list[str]
) -> None {
    for (key, dval) in defaults.items() {
        spec = options.get(key);
        if not isinstance(spec, dict) {
            continue;
        }
        if isinstance(dval, dict) {
            nested = spec.get("nested");
            if isinstance(nested, dict) {
                _collect_default_mismatches(nested, dval, f"{path}.{key}", bad);
            }
            continue;
        }
        if "default" in spec and spec.get("default") != dval {
            bad.append(
                f"{path}.{key}: schema={spec.get('default')!r} runtime={dval!r}"
            );
        }
    }
}

test "unknown section is flagged with a suggestion" {
    msgs = validate_scale_config({"microservice": {"routes": {}}});
    assert len(msgs) == 1 , f"expected 1 finding, got {msgs}";
    assert "microservice" in msgs[0] , msgs[0];
    assert "did you mean 'microservices'" in msgs[0] , msgs[0];
}

test "unknown nested key is flagged with a suggestion" {
    msgs = validate_scale_config({"kubernetes": {"cpu_limits": "1000m"}});
    assert len(msgs) == 1 , f"expected 1 finding, got {msgs}";
    assert "scale.kubernetes" in msgs[0] , msgs[0];
    assert "did you mean 'cpu_limit'" in msgs[0] , msgs[0];
}

test "per-service unknown key is flagged" {
    msgs = validate_scale_config(
        {"microservices": {"services": {"myapp": {"cpu_limits": "2000m"}}}}
    );
    assert len(msgs) == 1 , f"expected 1 finding, got {msgs}";
    assert "scale.microservices.services.myapp" in msgs[0] , msgs[0];
    assert "did you mean 'cpu_limit'" in msgs[0] , msgs[0];
}

test "open dict sections accept arbitrary keys" {
    cfg = {
        "secrets": {"MY_API_KEY": "${MY_API_KEY}"},
        "kubernetes": {"labels": {"team": "core"}},
        "microservices": {
            "routes": {"billing": "/billing"},
            "services": {
                "billing": {
                    "env": {"LOG_LEVEL": "DEBUG"},
                    "deployment_overlay": {"spec": {"replicas": 2}},
                    "hpa": {
                        "behavior": {
                            "scaleDown": {"stabilizationWindowSeconds": 600}
                        }
                    }
                }
            }
        }
    };
    msgs = validate_scale_config(cfg);
    assert msgs == [] , f"expected no findings, got {msgs}";
}

test "valid config produces no findings" {
    cfg = {
        "jwt": {"secret": "s", "algorithm": "HS256", "exp_delta_days": 7},
        "server": {"port": 8080, "docs_enabled": False},
        "kubernetes": {"namespace": "prod", "cpu_limit": "1000m"},
        "fat_bundle": True,
        "seal_timeout": 120
    };
    assert validate_scale_config(cfg) == [];
}

test "non-dict section values do not crash the validator" {
    msgs = validate_scale_config({"jwt": "not-a-table", "bogus": 1});
    assert len(msgs) == 1 , f"expected only the bogus finding, got {msgs}";
    assert "bogus" in msgs[0] , msgs[0];
}

test "empty or missing config is fine" {
    assert validate_scale_config({}) == [];
    assert validate_scale_config(None) == [];
}

test "every default config key is declared in the schema" {
    defaults = JacScaleConfig().get_default_config();
    msgs = validate_scale_config(defaults);
    assert msgs == [] , f"defaults drifted from schema: {msgs}";
}

test "schema defaults agree with runtime defaults" {
    bad: list[str] = [];
    _collect_default_mismatches(
        JacScalePluginConfig.get_config_schema().get("options", {}),
        JacScaleConfig().get_default_config(),
        "scale",
        bad
    );
    assert bad == [] , f"schema/defaults disagree: {bad}";
}

test "warn does not raise outside strict mode" {
    os.environ.pop("JAC_SCALE_CONFIG_STRICT", None);
    warn_unknown_scale_keys({"microservice": {}});
}

test "strict env raises on unknown keys" {
    os.environ["JAC_SCALE_CONFIG_STRICT"] = "1";
    try {
        raised = False;
        try {
            warn_unknown_scale_keys({"microservice": {}});
        } except ValueError as e {
            raised = True;
            assert "microservice" in str(e) , str(e);
        }
        assert raised , "expected ValueError in strict mode";
    } finally {
        os.environ.pop("JAC_SCALE_CONFIG_STRICT", None);
    }
}

test "strict env ignores a clean config" {
    os.environ["JAC_SCALE_CONFIG_STRICT"] = "1";
    try {
        warn_unknown_scale_keys({"server": {"port": 9000}});
    } finally {
        os.environ.pop("JAC_SCALE_CONFIG_STRICT", None);
    }
}

test "factory validates the on-disk jac.toml" {
    d = tempfile.mkdtemp();
    (Path(d) / "jac.toml").write_text(
        "[project]\nname = \"demo\"\n\n[scale.microservice]\nroutes = {}\n"
    );
    os.environ["JAC_SCALE_CONFIG_STRICT"] = "1";
    reset_scale_config();
    try {
        raised = False;
        try {
            get_scale_config(Path(d));
        } except ValueError as e {
            raised = True;
            assert "microservice" in str(e) , str(e);
        }
        assert raised , "expected strict validation to fire from the factory";
    } finally {
        os.environ.pop("JAC_SCALE_CONFIG_STRICT", None);
        reset_scale_config();
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "platform-injected and capability-intent keys are recognized" {
    cfg = {
        "database": {"backend": "postgres"},
        "storage": {"backend": "postgres", "type": "sv"},
        "deploy": {"target": "kubernetes"},
        "tracing": {"enabled": True},
        "scheduler": {"enabled": True}
    };
    msgs = validate_scale_config(cfg);
    assert msgs == [] , f"expected no findings, got {msgs}";
}

test "documented microservices boot and client keys are recognized" {
    cfg = {
        "microservices": {
            "boot_health_timeout": 60.0,
            "boot_max_wait": 120,
            "health_monitor_interval": 10.0,
            "client": {
                "entry": "client/main.jac",
                "static_mounts": [
                    {"url_prefix": "/assets", "local_path": "public"}
                ]
            }
        }
    };
    msgs = validate_scale_config(cfg);
    assert msgs == [] , f"expected no findings, got {msgs}";
}

test "a declared plugin deploy target owns its section" {
    cfg = {
        "deploy": {"target": "fly"},
        "fly": {"app_name": "demo", "region": "fra"}
    };
    msgs = validate_scale_config(cfg);
    assert msgs == [] , f"expected no findings, got {msgs}";

    without_decl = validate_scale_config({"fly": {"app_name": "demo"}});
    assert len(without_decl) == 1 , f"expected 1 finding, got {without_decl}";
}

test "normalizer passes documented boot and static-mount keys through" {
    import from jaclang.scale.config.config_loader { normalize_microservices_config }
    normalized = normalize_microservices_config(
        {
            "boot_max_wait": 120,
            "client": {
                "entry": "client/main.jac",
                "static_mounts": [
                    {"url_prefix": "/assets", "local_path": "public"}
                ]
            }
        },
        env_routes_fallback=False
    );
    assert normalized.get("boot_max_wait") == 120 , normalized;
    assert "boot_health_timeout" not in normalized , normalized;
    mounts = normalized["client"]["static_mounts"];
    assert mounts == [{"url_prefix": "/assets", "local_path": "public"}] , mounts;
}
