import io;
import unittest.mock as mock;
import from contextlib { redirect_stdout }
import from typing { Any, cast }
import from pathlib { Path }
import from jaclang.scale.runtime.cli.plan { print_plan }
import from jaclang.scale.runtime.cli.diagnostics {
    Diagnostic,
    PlanValidator,
    has_errors,
    _cpu_to_millicores,
    _mem_to_bytes
}
import jaclang.scale.runtime.cli.plan as plan_mod;
import from jaclang.scale.config.config_loader { get_scale_config, reset_scale_config }


def _validate(
    bundle: dict, ms_cfg: dict, svc_configs: dict, autoscaler_engine: str = "hpa"
) -> list {
    return PlanValidator(
        bundle=bundle,
        ms_cfg=ms_cfg,
        svc_configs=svc_configs,
        autoscaler_engine=autoscaler_engine
    ).run();
}


obj _StubConfig {
    has namespace: str = "test-ns";
}


obj _StubTarget {
    has _bundle: dict[str, Any] = {},
        k8s_config: _StubConfig postinit;

    def postinit {
        self.k8s_config = _StubConfig();
    }

    def generate_manifests(app_config: Any) -> dict[str, Any] {
        return self._bundle;
    }
}


def _make_app_config -> Any {
    import types;
    return types.SimpleNamespace(code_folder=".", file_name="main.jac");
}


def _dep(
    image: str | None = "a:v1", requests: dict | None = None, limits: dict | None = None
) -> dict {
    container: dict = {};
    if image is not None {
        container["image"] = image;
    }
    if requests or limits {
        resources: dict = {};
        if requests {
            resources["requests"] = requests;
        }
        if limits {
            resources["limits"] = limits;
        }
        container["resources"] = resources;
    }
    return {"spec": {"template": {"spec": {"containers": [container]}}}};
}


def _seed_ms_config(ms_toml: str) -> str {
    # Write a real jac.toml holding the requested [scale.microservices] config
    # and point get_scale_config() at it, so Plan._load_ms_cfg() runs for real.
    import tempfile;
    project_dir = tempfile.mkdtemp(prefix="jac-plan-test-");
    toml_body = (
        "[project]\nname = \"plan-test\"\nentry-point = \"main.jac\"\n" + ms_toml
    );
    (Path(project_dir) / "jac.toml").write_text(toml_body);
    reset_scale_config();
    get_scale_config(project_dir=Path(project_dir));
    return project_dir;
}


def _teardown_ms_config(project_dir: str) {
    import shutil;
    reset_scale_config();
    shutil.rmtree(project_dir, ignore_errors=True);
}


def _run_plan(
    bundle: dict[str, Any],
    show_yaml: bool = False,
    ms_cfg_pair: tuple | None = None,
    ms_toml: str | None = None
) -> tuple {
    target = _StubTarget(_bundle=bundle);
    buf = io.StringIO();
    diagnostics: list = [];
    if ms_toml is not None {
        project_dir = _seed_ms_config(ms_toml);
        try {
            with redirect_stdout(buf) {
                (_, diagnostics) = print_plan(
                    target, _make_app_config(), show_yaml=show_yaml
                );
            }
        } finally {
            _teardown_ms_config(project_dir);
        }
        return (buf.getvalue(), diagnostics);
    }
    cfg_pair = ms_cfg_pair if ms_cfg_pair is not None else ({}, {});
    with redirect_stdout(buf) {
        with mock.patch.object(plan_mod.Plan, "_load_ms_cfg", return_value=cfg_pair) {
            (_, diagnostics) = print_plan(
                target, _make_app_config(), show_yaml=show_yaml
            );
        }
    }
    return (buf.getvalue(), diagnostics);
}


test "cpu parser: valid millicore + core forms, invalid -> None" {
    assert _cpu_to_millicores("500m") == 500;
    assert _cpu_to_millicores("1") == 1000;
    assert _cpu_to_millicores("2.5") == 2500;
    assert _cpu_to_millicores(None) is None;
    assert _cpu_to_millicores("garbage") is None;
}


test "mem parser: Mi/Gi binary, M decimal, bare int; rejects 'MB' and garbage" {
    assert _mem_to_bytes("128Mi") == 128 * 1024 ** 2;
    assert _mem_to_bytes("1Gi") == 1024 ** 3;
    assert _mem_to_bytes("500M") == 500 * 1000 ** 2;
    assert _mem_to_bytes("12345") == 12345;
    assert _mem_to_bytes("500MB") is None;
    assert _mem_to_bytes(None) is None;
}


test "dry-run contract: print_plan must NOT call deploy / apply_manifests" {
    target = cast(any, _StubTarget(_bundle={"deployments": {"x": {}}, "services": {}}));
    target.deploy = mock.MagicMock(
        side_effect=AssertionError("deploy must NOT be called")
    );
    target.apply_manifests = mock.MagicMock(
        side_effect=AssertionError("apply_manifests must NOT be called")
    );
    with redirect_stdout(io.StringIO()) {
        with mock.patch.object(plan_mod.Plan, "_load_ms_cfg", return_value=({}, {})) {
            print_plan(target, _make_app_config());
        }
    }
    target.deploy.assert_not_called();
    target.apply_manifests.assert_not_called();
}


test "--show-yaml gate: YAML hidden by default, dumped on opt-in" {
    bundle: dict[str, Any] = {
        "deployments": {
            "a": {
                "apiVersion": "apps/v1",
                "kind": "Deployment",
                "metadata": {"name": "a-deployment"},
                "spec": {"replicas": 1}
            }
        }
    };
    (off, _) = _run_plan(bundle, show_yaml=False);
    assert "kind: Deployment" not in off;
    assert "--show-yaml" in off;
    (on, _) = _run_plan(bundle, show_yaml=True);
    assert "--- YAML (would be applied) ---" in on;
    assert "kind: Deployment" in on;
}


test "render smoke: realistic bundle prints every section" {
    bundle: dict[str, Any] = {
        "deployments": {
            "api": _dep(
                image="api:v1", requests={"cpu": "100m"}, limits={"cpu": "500m"}
            ),
            "__gateway__": _dep(image="gateway:v1")
        },
        "services": {"api": {}, "__gateway__": {}},
        "scaling": {
            "api": {
                "mode": "metric",
                "scale_target_name": "api-deployment",
                "service_name": "api-service",
                "autoscaler": {"min": 2, "max": 10, "cpu_target": 70},
                "http_activation": {}
            }
        },
        "pdbs": {"api": {"spec": {"maxUnavailable": 1}}},
        "ingress": {
            "spec": {"rules": [{"host": "shop.example.com", "http": {"paths": []}}]}
        },
        "user_secret": {
            "metadata": {"name": "app-secrets"},
            "data": {"k1": "...", "k2": "..."}
        }
    };
    ms_cfg = (
        {
            "routes": {"api": "/api"},
            "rate_limit": {"enabled": True, "requests_per_minute": 120}
        },
        {}
    );
    (out, _) = _run_plan(bundle, ms_cfg_pair=ms_cfg);
    assert "jac scale plan: dry-run" in out;
    assert "Microservices" in out;
    assert "api" in out;
    assert "HPA: 2 -> 10 @ 70% CPU" in out;
    assert "maxUnavailable=1" in out;
    assert "Ingress" in out and "shop.example.com" in out;
    assert "Cluster-wide" in out and "120/min" in out;
    assert "app-secrets" in out and "2 keys" in out;
    assert "Totals" in out;
}


def _rate_limit_toml(enabled: str, extra: str = "") -> str {
    return (
        "[scale.microservices.routes]\napi = \"/api\"\n"
        "\n[scale.microservices.rate_limit]\n" + f"enabled = {enabled}\nper_ip_rpm = 120\nper_user_rpm = 30\n" + extra
    );
}


test "a disabled rate limit renders no rate-limit line" {
    (out, _) = _run_plan(
        {"deployments": {"api": _dep()}, "services": {"api": {}}},
        ms_toml=_rate_limit_toml("false")
    );
    assert "rate_limit:" not in out , f"disabled limit rendered a line:\n{out}";
    assert "120/min" not in out;
}


test "render: an http_activation service shows scale-to-zero and counts in Totals" {
    bundle: dict[str, Any] = {
        "deployments": {"llm": _dep(image="llm:v1")},
        "services": {"llm": {}},
        "scaling": {
            "llm": {
                "mode": "http_activation",
                "scale_target_name": "llm-deployment",
                "service_name": "llm-service",
                "autoscaler": {},
                "http_activation": {
                    "enabled": True,
                    "min_replicas": 0,
                    "max_replicas": 5,
                    "concurrency_target": 10
                }
            }
        },
        "pdbs": {}
    };
    ms_toml = "[scale.microservices.routes]\nllm = \"/llm\"\n";
    (out, _) = _run_plan(bundle, ms_toml=ms_toml);
    assert "HTTP activation: 0 -> 5 on concurrency=10" in out;
    assert "scale-to-zero via KEDA HTTP Add-on" in out;
    assert "1 HTTP activation" in out;
    # The metric-autoscaler HPA line must NOT appear for an activation service.
    assert "HPA:" not in out;
}


test "validate: reserved name __gateway__ as a microservice -> error" {
    diags = _validate({"deployments": {}}, {"routes": {"__gateway__": "/x"}}, {});
    assert any(d.severity == "error" and "reserved" in d.message for d in diags);
}


test "validate: duplicate route paths -> error" {
    diags = _validate(
        {"deployments": {"a": _dep(), "b": _dep()}},
        {"routes": {"a": "/api", "b": "/api"}},
        {}
    );
    assert any(d.severity == "error" and "claimed by both" in d.message for d in diags);
}


test "validate: HPA bounds (min < 1, min > max, cpu_target out of 1-100)" {
    cfgs = {
        "a": {"hpa": {"min": 5, "max": 2, "cpu_target": 150}, "cpu_request": "100m"}
    };
    diags = _validate(
        {"deployments": {"a": _dep(requests={"cpu": "100m"})}},
        {"routes": {"a": "/a"}},
        cfgs
    );
    msgs = [
        d.message
        for d in diags
        if d.severity == "error"
    ];
    assert any("min (5) > max (2)" in m for m in msgs);
    assert any("cpu_target=150" in m for m in msgs);
}


def _keda_dry_run_plan(hpa_toml: str, engine: str = "keda") -> tuple[int, str] {
    # Real `jac start --scale --dry-run` subprocess against a real project,
    # no cluster and no network (test_dry_run_purity.jac holds that
    # contract) -- same shape as test_dry_run_plan_rate_limit.jac. Unlike
    # _validate() above, this drives Plan.from_target for real, so it
    # actually exercises the plumbing that reads autoscaler_engine off the
    # target and threads it into PlanValidator, not a hand-supplied string.
    import os;
    import shutil;
    import subprocess;
    import tempfile;
    import from jaclang.scale.runtime.context.util { jac_executable }
    project_dir = Path(tempfile.mkdtemp(prefix="jac-plan-keda-"));
    (project_dir / "jac.toml").write_text(
        '[project]\n'
        'name = "plankeda"\n'
        'entry-point = "main.jac"\n'
        '\n'
        '[scale.kubernetes]\n'
        'app_name = "plankeda"\n'
        'namespace = "plankeda"\n'
        # Without a storage class the RWX bundle PVC raises before the plan
        # is rendered (see test_dry_run_plan_rate_limit.jac).
        'bundle_storage_class = "standard"\n' + f'autoscaler_engine = "{engine}"\n' + '\n'
        '[scale.microservices.routes]\n'
        'orders = "/orders"\n'
        '\n' + hpa_toml,
        encoding="utf-8"
    );
    (project_dir / "main.jac").write_text("with entry {}\n", encoding="utf-8");
    (project_dir / "orders.jac").write_text("with entry {}\n", encoding="utf-8");
    env = os.environ.copy();
    for key in ["JAC_SV_SIBLING", "JAC_SV_NAME", "JAC_SV_ROUTES"] {
        env.pop(key, None);
    }
    try {
        result = subprocess.run(
            [jac_executable(), "start", "main.jac", "--scale", "--dry-run"],
            capture_output=True,
            text=True,
            cwd=str(project_dir),
            env=env,
            timeout=300
        );
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }
    return (result.returncode, result.stdout + result.stderr);
}


test "dry run: KEDA min=0 with a real trigger is a clean plan" {
    (rc, out) = _keda_dry_run_plan(
        '[scale.microservices.services.orders.hpa]\n'
        'min = 0\n'
        'max = 5\n'
        '\n[[scale.microservices.services.orders.triggers]]\n'
        'type = "cron"\n'
    );
    assert rc == 0 , f"dry run exited {rc}, expected a clean plan:\n{out}";
    assert "HPA min=0" not in out , (
        f"a real non-cpu/memory trigger under keda must not be flagged:\n{out}"
    );
}


test "dry run: HPA min=0 errors under the plain HPA engine, with no trigger at all, and with a cpu-only trigger" {
    (rc, out) = _keda_dry_run_plan(
        '[scale.microservices.services.orders.hpa]\nmin = 0\nmax = 5\n', engine="hpa"
    );
    assert rc == 2 , f"the plain HPA engine cannot scale to zero: rc={rc}\n{out}";
    assert "HPA min=0" in out , f"expected the HPA min=0 error, got:\n{out}";

    (rc, out) = _keda_dry_run_plan(
        '[scale.microservices.services.orders.hpa]\nmin = 0\nmax = 5\n'
    );
    assert rc == 2 , f"keda with no trigger at all cannot scale to zero: rc={rc}\n{out}";
    assert "HPA min=0" in out , f"expected the HPA min=0 error, got:\n{out}";

    (rc, out) = _keda_dry_run_plan(
        '[scale.microservices.services.orders.hpa]\n'
        'min = 0\n'
        'max = 5\n'
        '\n[[scale.microservices.services.orders.triggers]]\n'
        'type = "cpu"\n'
    );
    assert rc == 2 , f"a cpu-only trigger can never reach zero: rc={rc}\n{out}";
    assert "HPA min=0" in out , f"expected the HPA min=0 error, got:\n{out}";
}


test "validate: HPA enabled with no cpu_request -> warning" {
    diags = _validate(
        {"deployments": {"a": _dep()}},
        {"routes": {"a": "/a"}},
        {"a": {"hpa": {"min": 2, "max": 5, "cpu_target": 70}}}
    );
    assert any(
        d.severity == "warn" and "cpu_request is unset" in d.message for d in diags
    );
}


test "validate: PDB drain-deadlock (max_unavailable=0 + replicas=1) -> warning, no false positive on default" {
    dep = _dep(requests={"cpu": "100m"});
    dep["spec"]["replicas"] = 1;
    deadlock = _validate(
        {"deployments": {"a": dep}},
        {"routes": {"a": "/a"}},
        {"a": {"pdb": {"enabled": True, "max_unavailable": 0}, "cpu_request": "100m"}}
    );
    assert any(
        d.severity == "warn" and "drains will block" in d.message for d in deadlock
    );
    default_ok = _validate(
        {"deployments": {"a": dep}},
        {"routes": {"a": "/a"}},
        {
            "a": {
                "pdb": {"enabled": True, "max_unavailable": 1},
                "hpa": {"enabled": False},
                "cpu_request": "100m"
            }
        }
    );
    assert not any(
        d.severity == "warn" and "drains will block" in d.message for d in default_ok
    );
}


test "validate: request > limit (cpu and memory) -> error" {
    diags_cpu = _validate(
        {"deployments": {"a": _dep(requests={"cpu": "2"}, limits={"cpu": "500m"})}},
        {"routes": {"a": "/a"}},
        {}
    );
    assert any(
        d.severity == "error"
        and "cpu_request" in d.message
        and "cpu_limit" in d.message for d in diags_cpu
    );
    diags_mem = _validate(
        {
            "deployments": {
                "a": _dep(requests={"memory": "1Gi"}, limits={"memory": "256Mi"})
            }
        },
        {"routes": {"a": "/a"}},
        {}
    );
    assert any(
        d.severity == "error" and "memory_request" in d.message for d in diags_mem
    );
}


test "validate: invalid Kubernetes resource quantity ('500MB' not 'Mi') -> error" {
    diags = _validate(
        {"deployments": {"a": _dep(requests={"memory": "500MB"})}},
        {"routes": {"a": "/a"}},
        {}
    );
    assert any(
        d.severity == "error"
        and "memory_request" in d.message
        and "not a valid" in d.message for d in diags
    );
}


test "validate: no cpu_limit AND no memory_limit -> BestEffort warning" {
    diags = _validate(
        {"deployments": {"a": _dep(requests={"cpu": "100m"})}},
        {"routes": {"a": "/a"}},
        {}
    );
    assert any(d.severity == "warn" and "BestEffort" in d.message for d in diags);
}


test "validate: deployment with no container image -> error" {
    diags = _validate(
        {"deployments": {"a": _dep(image=None)}},
        {"routes": {"a": "/a"}},
        {"a": {"cpu_request": "100m", "cpu_limit": "500m"}}
    );
    assert any(
        d.severity == "error" and "no base image resolved" in d.message for d in diags
    );
}


test "validate: route declared with no generated Deployment -> error + skips downstream checks" {
    diags = _validate(
        {"deployments": {}}, {"routes": {"a": "/a"}}, {"a": {"cpu_request": "100m"}}
    );
    assert any(
        d.severity == "error" and "no generated Deployment" in d.message for d in diags
    );

    assert not any("cpu_request is unset" in d.message for d in diags);
    assert not any("no base image resolved" in d.message for d in diags);
}


test "validate: clean config returns no diagnostics (regression guard)" {
    diags = _validate(
        {
            "deployments": {
                "a": _dep(
                    requests={"cpu": "100m", "memory": "128Mi"},
                    limits={"cpu": "500m", "memory": "256Mi"}
                )
            }
        },
        {"routes": {"a": "/a"}},
        {
            "a": {
                "hpa": {"min": 2, "max": 10, "cpu_target": 70},
                "pdb": {"enabled": True, "max_unavailable": 1},
                "cpu_request": "100m",
                "cpu_limit": "500m",
                "memory_request": "128Mi",
                "memory_limit": "256Mi"
            }
        }
    );
    assert diags == [];
}


test "has_errors: True iff any diagnostic has severity='error'" {
    assert has_errors([]) is False;
    assert has_errors([Diagnostic(severity="warn", message="x")]) is False;
    assert has_errors(
        [
            Diagnostic(severity="warn", message="x"),
            Diagnostic(severity="error", message="y")
        ]
    ) is True;
}
