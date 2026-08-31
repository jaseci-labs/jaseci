import hashlib;
import io;
import json;
import shutil;
import tarfile;

import from pathlib { Path }
import from jaclang.jac0core.cachefs {
    atomic_publish_dir, lock_path, pid_tmp, store_dir, unlock
}
import from jaclang.jac0core.sealed {
    MANIFEST_NAME,
    register_image,
    image_for_bundle_dir
}
import from jaclang.dist.jab_vendor { activate_vendored }

glob JAB_SUFFIX: str = ".jab";

def is_jab(path: str) -> bool {
    return path.lower().endswith(JAB_SUFFIX);
}

def materialize_jab(jab_path: str) -> Path {
    return _materialize_jab_data(Path(jab_path).read_bytes(), jab_path);
}

def materialize_jab_bytes(data: bytes) -> Path {
    return _materialize_jab_data(data, "<app image>");
}

def _materialize_jab_data(data: bytes, label: str) -> Path {
    digest = hashlib.sha256(data).hexdigest();
    apps_dir = store_dir("apps");
    dest = apps_dir / digest[:20];
    manifest_path = dest / "_precompiled" / MANIFEST_NAME;
    if not manifest_path.is_file() {
        handle = lock_path(apps_dir / f".{digest}.lock");
        try {
            if not manifest_path.is_file() {
                _extract_jab(data, label, dest);
            }
        } finally {
            unlock(handle);
        }
    }
    bundle_dir = str(dest / "_precompiled");
    if image_for_bundle_dir(bundle_dir) is None
        and register_image(bundle_dir) is None {
        raise RuntimeError(f"{label}: sealed manifest failed to load");
    }

    activate_vendored(dest);
    return dest;
}

def _extract_jab(data: bytes, label: str, dest: Path) {
    tmp = pid_tmp(dest);
    shutil.rmtree(tmp, ignore_errors=True);
    tmp.mkdir(parents=True, exist_ok=True);
    try {
        with tarfile.open(fileobj=io.BytesIO(data), mode="r:*") as tf {
            tf.extractall(tmp, filter="data");
        }
        if not (tmp / "_precompiled" / MANIFEST_NAME).is_file() {
            raise RuntimeError(f"{label} is not a jab: no sealed manifest inside");
        }
        shutil.rmtree(dest, ignore_errors=True);
        atomic_publish_dir(tmp, dest);
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

def jab_app_meta(img_root: Path) -> dict[str, any] {
    raw = json.loads(
        (img_root / "_precompiled" / MANIFEST_NAME).read_text(encoding="utf-8")
    );
    meta = raw if isinstance(raw, dict) else {};
    return {
        "kind": meta.get("kind", ""),
        "capabilities": meta.get("capabilities") or [],
        "entry": meta.get("entry") or {},
        "package": meta.get("package", "")
    };
}
