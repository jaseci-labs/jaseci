import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
    build_bootstrap_init_container
}
import from jaclang.scale.deploy.target.kubernetes.venv_cache {
    venv_cache_key,
    is_cache_eligible
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


# ===== venv cache eligibility =====
# Only a digest-pinned image can safely participate in the shared cache: a
# mutable tag (python:3.12-slim, a jaseci/jaclang:dev/experimental-N build
# whose digest lookup failed, or an operator-configured custom image) can
# point at a different interpreter tomorrow under the same name, and the
# cache key has no other way to see that. is_cache_eligible is the one gate
# every consumer (the bootstrap script below, and any future one) must
# consult instead of re-deriving this rule.

test "is_cache_eligible requires a resolved digest" {
    assert is_cache_eligible("jaseci/jaclang@sha256:" + "a" * 64);
    assert not is_cache_eligible("jaseci/jaclang:dev");
    assert not is_cache_eligible("python:3.12-slim");
    assert not is_cache_eligible("");
}


# ===== venv persistence across pod restarts =====
# /app is an emptyDir, wiped every pod boot, so jac install rebuilds the
# venv from scratch on every scale-to-zero wake even though the dependency
# set is unchanged. The bootstrap script's job is only to call
# `jac scale venv-cache-restore`/`venv-cache-publish` in the right order
# around `jac install`, and only when the image is cache-eligible; the
# restore/publish/evict mechanics themselves are real functions exercised
# directly, with real concurrency, in test_venv_cache.jac -- not
# re-verified here by reading generated shell text.

test "bootstrap calls venv-cache-restore before install and venv-cache-publish after, only for a digest-pinned image" {
    specs = ["requests>=2.28.0"];
    pinned_image = "jaseci/jaclang@sha256:" + "b" * 64;
    ctr = build_bootstrap_init_container(
        KubernetesConfig(), pinned_image, resolved_specs=specs
    );
    script = str(ctr["args"][0]);
    assert "jac scale venv-cache-restore" in script;
    assert "jac scale venv-cache-publish" in script;
    assert script.index("venv-cache-restore") < script.index("jac install");
    assert script.index("venv-cache-publish") > script.index("jac install");
    assert "chmod 0777" not in script.split("jac install")[1];
}

test "bootstrap threads the pinned image into jac install's marker hash" {
    # venv_cache_key gates restore on (specs, base_image); _venv_deps_hash
    # gates the plain `jac install` skip on the marker it writes. Without
    # this, a venv restored under one image keeps a marker that only ever
    # hashed specs, so a later image change with the same specs would read
    # as "not stale" and skip install against the wrong interpreter. Only
    # matters on the cache-eligible path: a fresh install every boot (the
    # mutable-tag case below) can never see a marker from another image.
    specs = ["requests>=2.28.0"];
    pinned_image = "jaseci/jaclang@sha256:" + "b" * 64;
    ctr = build_bootstrap_init_container(
        KubernetesConfig(), pinned_image, resolved_specs=specs
    );
    script = str(ctr["args"][0]);
    assert f'JAC_VENV_CACHE_IMAGE_ID="{pinned_image}"' in script;
    assert (script.index("JAC_VENV_CACHE_IMAGE_ID") < script.index("jac install"));
}

test "bootstrap skips the venv cache entirely for a mutable-tag image" {
    specs = ["requests>=2.28.0"];
    ctr = build_bootstrap_init_container(
        KubernetesConfig(), "python:3.12-slim", resolved_specs=specs
    );
    script = str(ctr["args"][0]);
    assert "venv-cache-restore" not in script;
    assert "venv-cache-publish" not in script;
    assert "JAC_VENV_CACHE_IMAGE_ID" not in script;
}
