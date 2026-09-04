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
}

test "bootstrap sets JAC_VENV_CACHE_DIR, JAC_VENV_DIR and JAC_VENV_CACHE_ROOT via the container's structured env, not shell text" {
    # Regression test: these were previously built from one f-string meant
    # to emit two separate quoted assignments
    # (`JAC_VENV_CACHE_DIR="X" JAC_VENV_DIR="Y" cmd`). A POSIX shell does
    # not merge assignment-prefix words like that at runtime - each would
    # become its own environment variable correctly if the script text
    # actually contained two quoted assignments. It didn't: the bug was at
    # jac's f-string *compile* time, where two quoted `{}` interpolations
    # in one f-string collapsed into a single quoted blob, so the
    # generated container args already held the corrupted, merged text
    # before any shell ever ran it (confirmed via `kubectl get pod -o
    # json` against the manifest itself, not `describe`'s text rendering,
    # on a real deploy). Same defect class broke #7198's PVC seed. restore()'s
    # first line is `if not os.path.isdir(venv_dir): return`, so an empty
    # JAC_VENV_DIR made every restore call a silent no-op - same for
    # publish() against an empty JAC_VENV_CACHE_DIR. The tests above only
    # ever checked substring presence and ordering in the generated shell
    # text, which stayed true either way and caught neither bug.
    #
    # The fix moves these off shell text entirely: they're static once
    # resolved, so they're set via the container's own `env` list (the
    # same mechanism the sibling service container already uses), which
    # Kubernetes applies directly with no shell parsing step to corrupt.
    # This checks the structured value, not string content - the class of
    # bug this guards against can't reproduce in a field that was never
    # shell text to begin with.
    specs = ["requests>=2.28.0"];
    pinned_image = "jaseci/jaclang@sha256:" + "b" * 64;
    expected_cache_dir = f"{BUNDLE_MOUNT_PATH}/.cache/venv/{venv_cache_key(
        specs, pinned_image
    )}";
    expected_venv_dir = "/app/.jac/venv";
    expected_cache_root = f"{BUNDLE_MOUNT_PATH}/.cache/venv";
    ctr = build_bootstrap_init_container(
        KubernetesConfig(), pinned_image, resolved_specs=specs
    );
    env: list[dict[str, str]] = ctr.get("env", []);
    assert {"name": "JAC_VENV_CACHE_DIR", "value": expected_cache_dir} in env;
    assert {"name": "JAC_VENV_DIR", "value": expected_venv_dir} in env;
    assert {"name": "JAC_VENV_CACHE_ROOT", "value": expected_cache_root} in env;
    # Each name appears exactly once - no leftover duplicate from the old
    # two-writes-of-the-same-vars shape (once before restore, again before
    # publish).
    names = [e["name"] for e in env];
    assert names.count("JAC_VENV_CACHE_DIR") == 1;
    assert names.count("JAC_VENV_DIR") == 1;
    # And the script itself is now just the commands to run - no env
    # assignment text of any kind for these variables.
    script = str(ctr["args"][0]);
    assert "JAC_VENV_CACHE_DIR=" not in script;
    assert "JAC_VENV_DIR=" not in script;
    assert "JAC_VENV_CACHE_ROOT=" not in script;
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
    env: list[dict[str, str]] = ctr.get("env", []);
    assert {"name": "JAC_VENV_CACHE_IMAGE_ID", "value": pinned_image} in env;
}

test "bootstrap skips the venv cache entirely for a mutable-tag image" {
    specs = ["requests>=2.28.0"];
    ctr = build_bootstrap_init_container(
        KubernetesConfig(), "python:3.12-slim", resolved_specs=specs
    );
    script = str(ctr["args"][0]);
    assert "venv-cache-restore" not in script;
    assert "venv-cache-publish" not in script;
    assert "env" not in ctr;
}
