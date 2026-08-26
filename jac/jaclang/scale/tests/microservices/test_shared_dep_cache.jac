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
# The base image is part of the key too: compiled wheels in a venv are
# ABI-specific to the Python build they were installed against, so a venv
# cached under one image is not safe to reuse under a different one even
# when the declared specs haven't changed.

test "venv_cache_key is deterministic and spec-order independent" {
    a = venv_cache_key(["requests>=2.28.0", "flask~=3.0"], "python:3.12-slim");
    b = venv_cache_key(["flask~=3.0", "requests>=2.28.0"], "python:3.12-slim");
    assert a == b;
}

test "venv_cache_key changes when a spec changes" {
    a = venv_cache_key(["requests>=2.28.0"], "python:3.12-slim");
    b = venv_cache_key(["requests>=2.29.0"], "python:3.12-slim");
    assert a != b;
}

test "venv_cache_key changes when the base image changes" {
    # A python_image bump (version or OS base) with unchanged specs must
    # never collide with the old image's cached venv -- the old venv's
    # compiled extensions would not match the new interpreter's ABI.
    a = venv_cache_key(["requests>=2.28.0"], "python:3.11-slim");
    b = venv_cache_key(["requests>=2.28.0"], "python:3.12-slim");
    assert a != b;
}


# ===== venv persistence across pod restarts =====
# /app is an emptyDir, wiped every pod boot, so jac install rebuilds the
# venv from scratch on every scale-to-zero wake even though the dependency
# set is unchanged. These only cover the bootstrap script's mechanical copy
# in/copy out -- the actual install/skip *decision* is _venv_deps_stale's
# job (test_dependencies.jac), not re-verified here.

test "bootstrap restores a cached venv from the bundle PVC before jac install" {
    specs = ["requests>=2.28.0"];
    base_image = "python:3.12-slim";
    ctr = build_bootstrap_init_container(
        KubernetesConfig(), base_image, resolved_specs=specs
    );
    script = str(ctr["args"][0]);
    cache_dir = f"{BUNDLE_MOUNT_PATH}/.cache/venv/{venv_cache_key(specs, base_image)}";
    assert cache_dir in script;
    assert script.index(cache_dir) < script.index("jac install");
}

test "bootstrap persists the venv to the bundle PVC cache after jac install" {
    specs = ["requests>=2.28.0"];
    base_image = "python:3.12-slim";
    ctr = build_bootstrap_init_container(
        KubernetesConfig(), base_image, resolved_specs=specs
    );
    script = str(ctr["args"][0]);
    cache_dir = f"{BUNDLE_MOUNT_PATH}/.cache/venv/{venv_cache_key(specs, base_image)}";
    # A later occurrence of the same path after "jac install" is the
    # write-back; rindex catches it regardless of how many times the
    # restore step above also references the path.
    assert script.rindex(cache_dir) > script.index("jac install");
}

test "bootstrap persists the venv atomically, never deletes the live cache path in place" {
    # Scale-to-zero's own point is bursty cold starts: several pods can be
    # persisting to the same cache key at once. A sibling pod's restore, or
    # the next wake, must never observe cache_dir mid-write -- an in-place
    # `rm -rf` of the live path is exactly the window where a reader sees
    # neither the old venv nor the new one. If a corrupted partial copy is
    # what a reader lands on, and it happens to still carry a valid marker,
    # _venv_deps_stale would wrongly call it fresh and skip reinstalling
    # a genuinely broken venv -- worse than no caching at all.
    specs = ["requests>=2.28.0"];
    base_image = "python:3.12-slim";
    ctr = build_bootstrap_init_container(
        KubernetesConfig(), base_image, resolved_specs=specs
    );
    script = str(ctr["args"][0]);
    cache_dir = f"{BUNDLE_MOUNT_PATH}/.cache/venv/{venv_cache_key(specs, base_image)}";
    assert f'rm -rf "{cache_dir}"' not in script;
    # The write-back must land in one atomic rename: the operation that
    # most recently touches the final occurrence of cache_dir must be a
    # move into place, not a direct copy onto the live path.
    last_idx = script.rindex(cache_dir);
    last_mv = script.rfind("mv ", 0, last_idx);
    last_cp = script.rfind("cp -a", 0, last_idx);
    assert last_mv != -1;
    assert last_mv > last_cp;
}

test "venv cache is size-bounded like the pip cache, not left to grow without limit" {
    # The pip cache (15 lines above this one in the generated script) caps
    # itself at 512MB and wipes-and-rewarms past that. Every unique
    # (base_image, specs) pair otherwise gets a permanent directory under
    # .cache/venv that nothing else in this codebase ever cleans up --
    # reap_superseded_deployments only reaps stale Deployment objects, not
    # PVC content. Left unbounded, this grows across every dependency bump
    # and image upgrade over an app's lifetime, on the same PVC that stores
    # the actual deployable bundles.
    specs = ["requests>=2.28.0"];
    base_image = "python:3.12-slim";
    ctr = build_bootstrap_init_container(
        KubernetesConfig(), base_image, resolved_specs=specs
    );
    script = str(ctr["args"][0]);
    assert script.count("du -sm") == 2;
    venv_cache_root = f"{BUNDLE_MOUNT_PATH}/.cache/venv";
    last_du = script.rindex("du -sm");
    assert venv_cache_root in script[last_du:last_du + len(venv_cache_root) + 20];
}

test "venv cache write path is opened cross-uid like the pip cache" {
    # Without an explicit chmod, whichever pod's UID first creates
    # .cache/venv leaves it at that UID's default permissions. A later pod
    # running under a different UID (a different python_image, or an image
    # whose default user changed) then fails to mkdir/cp its own
    # hash-keyed subdir -- silently, swallowed by 2>/dev/null -- and
    # permanently degrades to "no caching, full install every wake" with
    # no visible signal. The pip cache right next to this one already
    # solves exactly this.
    specs = ["requests>=2.28.0"];
    base_image = "python:3.12-slim";
    ctr = build_bootstrap_init_container(
        KubernetesConfig(), base_image, resolved_specs=specs
    );
    script = str(ctr["args"][0]);
    venv_cache_root = f"{BUNDLE_MOUNT_PATH}/.cache/venv";
    assert f"chmod 0777 {venv_cache_root}" in script;
}
