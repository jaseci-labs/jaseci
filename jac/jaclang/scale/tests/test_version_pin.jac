import json;
import tempfile;
import unittest.mock;
import jaclang.scale.injector.binary as binary_mod;
import from jaclang.scale.injector.binary {
    _exact_of,
    _resolve_target_version,
    generation_mismatch
}
import from jaclang.cli.manifest_route { resolve_cli_version }
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.target { KubernetesTarget }
import from jaclang.project.config { JacConfig }
import from pathlib { Path }

glob REPO: str = "jaseci-labs/jac";


def _project(toml: str) -> str {
    d = tempfile.mkdtemp();
    (Path(d) / "jac.toml").write_text(toml, encoding="utf-8");
    return d;
}


def _release_meta(names: list[str]) -> bytes {
    assets = [
        {"name": n, "browser_download_url": f"https://dl.test/{n}"} for n in names
    ];
    return json.dumps({"assets": assets}).encode("utf-8");
}


test "exact pins (== or bare) are detected; ranges and junk are not" {
    assert _exact_of("==0.34.3") == "0.34.3";
    assert _exact_of("0.34.3") == "0.34.3";
    assert _exact_of(">=0.34.3") == "";
    assert _exact_of(">=0.34,<0.35") == "";
    assert _exact_of("~=0.34.3") == "";
    assert _exact_of("==0.34.*") == "";
    assert _exact_of("") == "";
    assert _exact_of("not-a-version") == "";
}


test "an exact pin resolves without listing releases" {
    with unittest.mock.patch.object(
        binary_mod,
        "_list_release_versions",
        side_effect=AssertionError("should not list releases for an exact pin")
    ) {
        assert _resolve_target_version(REPO, "==0.34.3") == "0.34.3";
        assert _resolve_target_version(REPO, "0.34.3") == "0.34.3";
    }
    assert _resolve_target_version(REPO, "") == "";
}


test "a range picks the newest published release that satisfies it" {
    `pub = ["0.33.0", "0.34.1", "0.34.2", "0.34.3", "0.35.0"];
    with unittest.mock.patch.object(
        binary_mod, "_list_release_versions", return_value=`pub
    ) {
        assert _resolve_target_version(REPO, ">=0.34,<0.35") == "0.34.3";
        assert _resolve_target_version(REPO, "<=0.34.2") == "0.34.2";
        assert _resolve_target_version(REPO, "~=0.34.1") == "0.34.3";
        assert _resolve_target_version(REPO, ">=1.0") == "";
    }
}


test "a malformed spec resolves to '' (no target)" {
    with unittest.mock.patch.object(
        binary_mod, "_list_release_versions", return_value=["0.34.3"]
    ) {
        assert _resolve_target_version(REPO, ">=>=bad") == "";
    }
}


test "no pin, or a non-stable channel, resolves to latest" {
    d = _project('[project]\nname = "x"\nversion = "0.1.0"\n');
    assert binary_mod.resolve_deploy_version(d, "stable") == "";
    # dev/local/experimental ship their own binary and ignore the pin.
    p = _project(
        '[project]\nname = "x"\nversion = "0.1.0"\njac-version = "==0.34.2"\n'
    );
    assert binary_mod.resolve_deploy_version(p, "dev") == "";
}


test "a declared pin matching no release aborts the deploy" {
    d = _project('[project]\nname = "x"\nversion = "0.1.0"\njac-version = ">=99.0"\n');
    with unittest.mock.patch.object(
        binary_mod, "_list_release_versions", return_value=["0.34.3"]
    ) {
        raised = False;
        try {
            binary_mod.resolve_deploy_version(d, "stable");
        } except RuntimeError {
            raised = True;
        }
        assert raised;
    }
}


test "the admin console uses the same release tag as the pinned binary" {
    meta = _release_meta(
        ["jac-0.34.2-admin-dist.tar.gz", "jac-0.34.2-admin-dist.tar.gz.sha256"]
    );
    with unittest.mock.patch.object(
        binary_mod, "_http_get_bytes", return_value=meta
    ) as fetch {
        (dist, sha) = binary_mod._admin_dist_urls("stable", "0.34.2");
        assert "releases/tags/v0.34.2" in fetch.call_args[0][0];
        assert dist.endswith("jac-0.34.2-admin-dist.tar.gz");
        assert sha == dist + ".sha256";
    }
}


test "a pinned console without a published checksum aborts" {
    meta = _release_meta(["jac-0.34.2-admin-dist.tar.gz"]);
    with unittest.mock.patch.object(binary_mod, "_http_get_bytes", return_value=meta) {
        raised = False;
        try {
            binary_mod._admin_dist_urls("stable", "0.34.2");
        } except RuntimeError {
            raised = True;
        }
        assert raised;
    }
}


test "resolve_deploy_version lists releases once per deploy" {
    d = _project(
        '[project]\nname = "x"\nversion = "0.1.0"\njac-version = ">=0.34,<0.35"\n'
    );
    with unittest.mock.patch.object(
        binary_mod, "_list_release_versions", return_value=["0.34.2"]
    ) as listing {
        assert binary_mod.resolve_deploy_version(d, "stable") == "0.34.2";
        # Every later consumer (console, base image) reuses the memo, so a
        # release publishing mid-deploy cannot split them across release sets.
        assert binary_mod.resolve_deploy_version(d, "stable") == "0.34.2";
        assert listing.call_count == 1;
    }
}


test "an edited pin re-resolves instead of serving a stale memo" {
    d = _project(
        '[project]\nname = "x"\nversion = "0.1.0"\njac-version = ">=0.34,<0.35"\n'
    );
    with unittest.mock.patch.object(
        binary_mod, "_list_release_versions", return_value=["0.34.2"]
    ) {
        assert binary_mod.resolve_deploy_version(d, "stable") == "0.34.2";
    }
    # Editing the pin changes the jac.toml content, so a redeploy in the same
    # process must not serve the stale 0.34.2 from the memo.
    (Path(d) / "jac.toml").write_text(
        '[project]\nname = "x"\nversion = "0.1.0"\njac-version = ">=0.35,<0.36"\n',
        encoding="utf-8"
    );
    with unittest.mock.patch.object(
        binary_mod, "_list_release_versions", return_value=["0.35.1"]
    ) {
        assert binary_mod.resolve_deploy_version(d, "stable") == "0.35.1";
    }
}


test "the pin is discovered from an ancestor jac.toml (nested entry)" {
    proj = _project(
        '[project]\nname = "x"\nversion = "0.1.0"\njac-version = "==0.34.2"\n'
    );
    sub = Path(proj) / "apps" / "web";
    sub.mkdir(parents=True);
    # A deploy whose code_folder is the nested entry dir still finds the project
    # pin instead of silently deploying latest.
    assert binary_mod.resolve_deploy_version(str(sub), "stable") == "0.34.2";
}


test "a deploy boundary re-resolves a range after a new release publishes" {
    d = _project(
        '[project]\nname = "x"\nversion = "0.1.0"\njac-version = ">=0.34,<0.36"\n'
    );
    with unittest.mock.patch.object(
        binary_mod, "_list_release_versions", return_value=["0.34.2"]
    ) {
        assert binary_mod.resolve_deploy_version(d, "stable") == "0.34.2";
    }
    # A newer matching release publishes. The memo holds the old result within
    # the deploy, but the next deploy's reset picks up the new one.
    with unittest.mock.patch.object(
        binary_mod, "_list_release_versions", return_value=["0.34.2", "0.35.9"]
    ) {
        assert binary_mod.resolve_deploy_version(d, "stable") == "0.34.2";
        binary_mod.reset_deploy_version_cache();
        assert binary_mod.resolve_deploy_version(d, "stable") == "0.35.9";
    }
}


test "the base image uses the same resolver as the pinned binary" {
    d = _project(
        '[project]\nname = "x"\nversion = "0.1.0"\njac-version = ">=0.34,<0.35"\n'
    );
    with unittest.mock.patch.object(
        binary_mod, "resolve_deploy_version", return_value="0.34.2"
    ) {
        with unittest.mock.patch.object(
            binary_mod, "_http_get_bytes", return_value=b"{}"
        ) {
            assert binary_mod.resolve_pod_base_image(d, "") == "jaseci/jaclang:0.34.2";
        }
    }
    # An unresolvable pin aborts the image resolution too -- no silent `latest`.
    with unittest.mock.patch.object(
        binary_mod, "resolve_deploy_version", side_effect=RuntimeError("no match")
    ) {
        raised = False;
        try {
            binary_mod.resolve_pod_base_image(d, "");
        } except RuntimeError {
            raised = True;
        }
        assert raised;
    }
}


test "a pinned console failure aborts; unpinned stays soft" {
    d = _project('[project]\nname = "x"\nversion = "0.1.0"\n');
    with unittest.mock.patch.object(
        binary_mod, "download_admin_dist", side_effect=RuntimeError("checksum mismatch")
    ) {
        raised = False;
        try {
            binary_mod.stage_admin_dist(d, "stable", "0.34.2");
        } except RuntimeError {
            raised = True;
        }
        assert raised;
        # Unpinned keeps the warn-and-continue behavior.
        assert binary_mod.stage_admin_dist(d, "stable") == False;
    }
}


test "a pinned release with no console asset is skipped, not fatal" {
    meta = _release_meta(["jac-0.30.0-linux-x86_64", "jac-0.30.0-linux-x86_64.sha256"]);
    with unittest.mock.patch.object(binary_mod, "_http_get_bytes", return_value=meta) {
        assert binary_mod.download_admin_dist("stable", "0.30.0") is None;
    }
}


test "a pinned no-console release clears a previously staged console" {
    import from urllib.error { HTTPError }
    d = _project('[project]\nname = "x"\nversion = "0.1.0"\n');
    stale = Path(d) / ".jac" / "admin";
    stale.mkdir(parents=True);
    (stale / "index.html").write_text("stale", encoding="utf-8");
    with unittest.mock.patch.object(
        binary_mod,
        "_http_get_bytes",
        return_value=_release_meta(["jac-0.30.0-linux-x86_64"])
    ) {
        # Pinned: the stale console from an earlier deploy must not ship.
        assert binary_mod.stage_admin_dist(d, "stable", "0.30.0") == False;
        assert not stale.exists();
    }
    with unittest.mock.patch.object(
        binary_mod,
        "_http_get_bytes",
        side_effect=HTTPError("url", 404, "Not Found", None, None)
    ) {
        # Unpinned keeps whatever was staged before.
        (stale).mkdir(parents=True);
        (stale / "index.html").write_text("stale", encoding="utf-8");
        assert binary_mod.stage_admin_dist(d, "stable") == False;
        assert stale.exists();
    }
}


test "config round-trips the stamped jac-version pin" {
    toml = '[project]\nname = "x"\nversion = "0.1.0"\njac-version = "==0.34.3"\n';
    cfg = JacConfig.from_toml_str(toml);
    assert cfg.project.jac_version == "==0.34.3";
}


test "the preflight refuses a pin that names no published release" {
    # An exact pin short-circuits resolve_deploy_version, so only the release
    # record reveals the typo.
    import from urllib.error { HTTPError }
    d = _project(
        '[project]\nname = "x"\nversion = "0.1.0"\njac-version = "==0.34.99"\n'
    );
    def _absent(url: str) -> bytes {
        raise HTTPError(url, 404, "Not Found", {}, None);
    }
    with unittest.mock.patch.object(binary_mod, "_http_get_bytes", _absent) {
        raised = False;
        try {
            binary_mod.preflight_pod_runtime(d, "stable", "x86_64");
        } except RuntimeError {
            raised = True;
        }
        assert raised;
    }
}


test "the preflight needs the pod binary and the host sealing binary" {
    # Since jac#7989 a deploy may also fetch a host-platform build of the same
    # version to seal the .jab, so a release missing either one cannot deploy.
    # The pod arch is chosen to DIFFER from the host arch: on a linux host
    # whose arch matches the pod's, the two required asset names collapse into
    # one and neither "missing" leg can trip.
    d = _project(
        '[project]\nname = "x"\nversion = "0.1.0"\njac-version = "==0.34.3"\n'
    );
    pod_arch = "aarch64" if binary_mod.host_arch() == "x86_64" else "x86_64";
    pod = f"jac-0.34.3-linux-{pod_arch}";
    host = f"jac-0.34.3-{binary_mod.host_seal_platform()}-{binary_mod.host_arch()}";
    assert pod != host;
    for names in [[pod], [host]] {
        with unittest.mock.patch.object(
            binary_mod, "_http_get_bytes", return_value=_release_meta(names)
        ) {
            raised = False;
            try {
                binary_mod.preflight_pod_runtime(d, "stable", pod_arch);
            } except RuntimeError {
                raised = True;
            }
            assert raised;
        }
    }
    with unittest.mock.patch.object(
        binary_mod, "_http_get_bytes", return_value=_release_meta([pod, host])
    ) {
        assert binary_mod.preflight_pod_runtime(d, "stable", pod_arch) == "0.34.3";
    }
}


test "a deploy is refused when the pin and the deployer differ by minor line" {
    # The pin selects the pod image and the seal; the deploying jac renders the
    # manifests and provisions the database. #8766: nothing compared the two, so
    # a 0.34 deployer stood up Mongo for an app pinned to a Postgres runtime and
    # said nothing. Patch drift is fine, a minor line is not.
    assert generation_mismatch("0.34.17", "0.34.15") == "";
    assert generation_mismatch("0.36.1", "0.36.1") == "";

    refusal = generation_mismatch("0.36.1", "0.34.15");
    assert "0.36.1" in refusal and "0.34.15" in refusal , (
        f"{refusal!a} must name both versions so the operator can act"
    );
    assert "0.34." in refusal , f"{refusal!a} must say what to pin instead";
    assert "mongo" not in refusal.lower() and "postgres" not in refusal.lower() , (
        f"{refusal!a} names a backend; a deployer only knows its own generation"
    );

    # Refusal runs both ways: a newer deployer cannot serve an older pin either.
    assert generation_mismatch("0.34.17", "0.36.1") != "";
    assert generation_mismatch("1.0.0", "0.36.1") != "";

    # An unpinned app, or a deployer that cannot name itself, is not refused.
    assert generation_mismatch("", "0.34.15") == "";
    assert generation_mismatch("0.36.1", "") == "";
}


test "the deploy refusal is keyed on the running jac, and never blocks itself" {
    # Composed on the real pin resolver, so this pins the wiring the deploy
    # calls: an app pinned to the running jac always deploys, an app a minor
    # line away never does, and anything the resolver cannot answer is left
    # for the preflight to report rather than refused here.
    running = resolve_cli_version().strip();
    (major, minor, _) = binary_mod._ver_key(running);

    same = _project(f'[project]\nname = "x"\njac-version = "=={running}"\n');
    assert binary_mod.deploy_generation_refusal(same, "stable") == "" , (
        "an app pinned to the deployer's own version must always deploy"
    );

    other = _project(
        f'[project]\nname = "x"\njac-version = "=={major}.{minor + 1}.0"\n'
    );
    assert binary_mod.deploy_generation_refusal(other, "stable") != "";

    # No pin, and a channel that ships its own binary, are both unconstrained.
    assert binary_mod.deploy_generation_refusal(
        _project('[project]\nname = "x"\n'), "stable"
    )
        == "";
    assert binary_mod.deploy_generation_refusal(other, "dev") == "";

    # A pin naming no published release is the preflight's error to raise, with
    # the message that tells the operator which releases exist.
    unmatched = _project('[project]\nname = "x"\njac-version = ">=99.0"\n');
    with unittest.mock.patch.object(
        binary_mod, "_list_release_versions", return_value=["0.34.3"]
    ) {
        assert binary_mod.deploy_generation_refusal(unmatched, "stable") == "";
    }
}


test "a cross-generation deploy is refused before the cluster is contacted" {
    # #8766: the pin picks the pod image, the deploying jac provisions the
    # store, and a mismatch used to deploy anyway. The refusal has to land
    # before _load_cluster_config, so it reaches an operator with no kubeconfig
    # and costs nothing to discover.
    running = resolve_cli_version().strip();
    (major, minor, _) = binary_mod._ver_key(running);
    pinned = f"{major}.{minor + 1}.0";
    code = _project(f'[project]\nname = "x"\njac-version = "=={pinned}"\n');

    cfg = KubernetesConfig.from_dict(
        KubernetesConfig, {"app_name": "x", "namespace": "default"}
    );
    result = KubernetesTarget(config=cfg, microservices_config={}).deploy(
        AppConfig(code_folder=code, file_name="main.jac")
    );

    assert result.success is False , "a cross-generation deploy must not proceed";
    assert pinned in result.message and running in result.message , (
        f"{result.message!a} must name both generations"
    );
}
