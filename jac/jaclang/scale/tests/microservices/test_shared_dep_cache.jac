import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
    build_bootstrap_init_container,
    venv_cache_key
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.injector.pvc_injector {
    BUNDLE_MOUNT_PATH,
    BUNDLE_VOLUME_NAME
}


test "bootstrap points the pip cache at the shared bundle PVC, best-effort" {
    ctr = build_bootstrap_init_container(KubernetesConfig(), "python:3.12-slim");
    script = str(ctr["args"][0]);
    assert f"PIP_CACHE_DIR={BUNDLE_MOUNT_PATH}/.cache/pip" in script;
    # bun's cache is deliberately NOT shared: thousands of tiny files are
    # pathological on EFS/NFS; it stays on the pod-local disk.
    assert "BUN_INSTALL_CACHE_DIR" not in script;
    # mkdir-guarded (unwritable PVC degrades to plain installs), size-bounded.
    assert script.index("if mkdir") < script.index("PIP_CACHE_DIR");
    assert "du -sm" in script;
    assert script.index("PIP_CACHE_DIR") < script.index("jac install");
    mounts = [m["name"] for m in ctr["volumeMounts"]];
    assert BUNDLE_VOLUME_NAME in mounts;
}

test "shared pip cache is opened cross-uid, probed, with pod-local fallback" {
    ctr = build_bootstrap_init_container(KubernetesConfig(), "python:3.12-slim");
    script = str(ctr["args"][0]);
    cache = f"{BUNDLE_MOUNT_PATH}/.cache";
    # The creator opens the dirs so pods running other uids can still write.
    assert f"chmod 0777 {cache} {cache}/pip" in script;
    # A pod that cannot write the shared dir must not export it: pip would
    # silently disable caching and rebuild sdists on every boot. It gets a
    # pod-local cache instead.
    assert f"if touch {cache}/pip/.writable" in script;
    assert "export PIP_CACHE_DIR=/tmp/jac-pip-cache" in script;
    # The wipe-and-rewarm path re-opens the recreated dir too.
    assert script.count("chmod 0777") == 2;
}


# ===== venv cache key =====
# The dependency set alone determines whether a cached venv is reusable --
# not the whole sealed bundle (which also includes app source and would
# invalidate on every code change, defeating the point). Mirrors the
# package.json-hash choice client_deps_stale already made on the npm side.

test "venv_cache_key is deterministic and spec-order independent" {
    a = venv_cache_key(["requests>=2.28.0", "flask~=3.0"]);
    b = venv_cache_key(["flask~=3.0", "requests>=2.28.0"]);
    assert a == b;
}

test "venv_cache_key changes when a spec changes" {
    a = venv_cache_key(["requests>=2.28.0"]);
    b = venv_cache_key(["requests>=2.29.0"]);
    assert a != b;
}


# ===== venv persistence across pod restarts =====
# /app is an emptyDir, wiped every pod boot, so jac install rebuilds the
# venv from scratch on every scale-to-zero wake even though the dependency
# set is unchanged. These two only cover the bootstrap script's mechanical
# copy in/copy out -- the actual install/skip *decision* is
# _venv_deps_stale's job (test_dependencies.jac), not re-verified here.

test "bootstrap restores a cached venv from the bundle PVC before jac install" {
    specs = ["requests>=2.28.0"];
    ctr = build_bootstrap_init_container(
        KubernetesConfig(), "python:3.12-slim", resolved_specs=specs
    );
    script = str(ctr["args"][0]);
    cache_dir = f"{BUNDLE_MOUNT_PATH}/.cache/venv/{venv_cache_key(specs)}";
    assert cache_dir in script;
    assert script.index(cache_dir) < script.index("jac install");
}

test "bootstrap persists the venv to the bundle PVC cache after jac install" {
    specs = ["requests>=2.28.0"];
    ctr = build_bootstrap_init_container(
        KubernetesConfig(), "python:3.12-slim", resolved_specs=specs
    );
    script = str(ctr["args"][0]);
    cache_dir = f"{BUNDLE_MOUNT_PATH}/.cache/venv/{venv_cache_key(specs)}";
    # A later occurrence of the same path after "jac install" is the
    # write-back; rindex catches it regardless of how many times the
    # restore step above also references the path.
    assert script.rindex(cache_dir) > script.index("jac install");
}
