"""Tests for the Compose Android Gradle scaffold — locks in the HMR module split.

The 2-module dev layout (base :app host + :hot app code) is what makes
DexClassLoader hot-swap possible, so the file routing it produces is a
regression-sensitive contract. These tests assert it without touching Gradle,
the SDK, or a device.
"""
import from jaclang.compiler.passes.compose.gradle_scaffold { build_gradle_scaffold }
import from jaclang.runtimelib.client.targets.android.config {
    resolve_sv_deploy,
    resolve_sv_sync_url
}
import from pathlib { Path }
import tempfile;

test "resolve_sv_deploy defaults to remote and validates deploy dial" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp);
        assert resolve_sv_deploy(project_dir) == "remote";
        (project_dir / "jac.toml").write_text(
            '[sv]\ndeploy = "device"\n', encoding="utf-8"
        );
        assert resolve_sv_deploy(project_dir) == "device";
        (project_dir / "jac.toml").write_text(
            '[sv]\ndeploy = "local-first"\nsync = "https://example.test/"\n',
            encoding="utf-8"
        );
        assert resolve_sv_deploy(project_dir) == "local-first";
        assert resolve_sv_sync_url(project_dir) == "https://example.test/";
        (project_dir / "jac.toml").write_text(
            '[sv]\ndeploy = "bogus"\n', encoding="utf-8"
        );
        raised = False;
        try {
            resolve_sv_deploy(project_dir);
        } except RuntimeError {
            raised = True;
        }
        assert raised;
    }
}

test "dev scaffold splits host into :app and app code into :hot" {
    files = build_gradle_scaffold(
        "dev.jac.myapp", "My App", "http://10.0.2.2:8000", ["/"], dev=True
    );

    # Two modules are declared.
    assert ":hot" in files["settings.gradle.kts"];
    assert "hot/build.gradle.kts" in files;
    assert "hot/src/main/AndroidManifest.xml" in files;

    # The polling host lives in the BASE (:app) and is its launcher.
    assert "app/src/main/java/dev/jac/myapp/JacDevHostActivity.kt" in files;
    manifest = files["app/src/main/AndroidManifest.xml"];
    assert "JacDevHostActivity" in manifest;
    # Dev builds must expose exactly one launcher — the HMR host, not MainActivity.
    assert manifest.count("android.intent.category.LAUNCHER") == 1;
    assert "JacDevHostActivity" in manifest.split("LAUNCHER")[0];

    # All app code — infra, the mount entry — lives in :hot so a hot dex can
    # carry ONLY app classes (Compose stays in the parent/base).
    assert "hot/src/main/java/dev/jac/myapp/JacDevEntry.kt" in files;
    assert "hot/src/main/java/dev/jac/myapp/JacRouting.kt" in files;
    assert "hot/src/main/java/dev/jac/myapp/JacTheme.kt" in files;
}

test "release scaffold is single-module with no :hot" {
    files = build_gradle_scaffold("dev.jac.myapp", "A", "", ["/"], dev=False);

    # No second module.
    assert ":hot" not in files["settings.gradle.kts"];
    has_hot = False;
    for k in files {
        if k.startswith("hot/") {
            has_hot = True;
        }
    }
    assert not has_hot;

    # Infra returns to the single :app source set; the dev host is absent.
    assert "app/src/main/java/dev/jac/myapp/MainActivity.kt" in files;
    assert "app/src/main/java/dev/jac/myapp/JacRouting.kt" in files;
    assert "JacDevHostActivity" not in files["app/src/main/AndroidManifest.xml"];
}

test "dev host manifest has the jacDevServer intent surface" {
    # The host reads the dev-server URL from the `jacDevServer` extra at launch;
    # the scaffolded Kotlin (JacDevHostActivity.resolveEndpoint) depends on this
    # contract, so pin the extra name here.
    files = build_gradle_scaffold("dev.jac.myapp", "A", "", ["/"], dev=True);
    host_kt = files["app/src/main/java/dev/jac/myapp/JacDevHostActivity.kt"];
    assert "jacDevServer" in host_kt;
    assert "DexClassLoader" in host_kt;
    assert "/_jac/dev/modules/manifest.json" in host_kt;
}

test "gradle scaffold emits extra dependencies from jac.toml coordinates" {
    files = build_gradle_scaffold(
        "dev.jac.myapp",
        "A",
        "",
        ["/"],
        dev=False,
        gradle_deps=["io.coil-kt:coil-compose:2.7.0"]
    );
    gradle = files["app/build.gradle.kts"];
    assert 'implementation("io.coil-kt:coil-compose:2.7.0")' in gradle;
}

test "device deploy scaffold omits JacEnvironment backend URL" {
    files = build_gradle_scaffold(
        "dev.jac.myapp", "A", "http://10.0.2.2:8000", ["/"], sv_deploy="device"
    );
    has_env = False;
    for k in files {
        if "JacEnvironment.kt" in k {
            has_env = True;
        }
    }
    assert not has_env;

    # Remote deploy still carries it — the RPC client reads BACKEND_URL.
    remote = build_gradle_scaffold("dev.jac.myapp", "A", "http://x", ["/"]);
    has_env = False;
    for k in remote {
        if "JacEnvironment.kt" in k {
            has_env = True;
        }
    }
    assert has_env;
}
