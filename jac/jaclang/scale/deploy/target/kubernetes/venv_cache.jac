import os;
import shutil;
import tempfile;


def venv_cache_key(specs: list[str], base_image: str) -> str {
    import hashlib;
    return hashlib.sha256(
        (base_image + "\n" + "\n".join(sorted(specs))).encode()
    ).hexdigest();
}


def is_cache_eligible(base_image: str) -> bool {
    return "@sha256:" in base_image;
}


def restore(cache_dir: str, venv_dir: str) -> None {
    if not os.path.isdir(cache_dir) {
        return;
    }
    try {
        os.makedirs(os.path.dirname(venv_dir), exist_ok=True);
        shutil.copytree(cache_dir, venv_dir, dirs_exist_ok=True);
    } except Exception {
        _ = 0;
    }
}


glob _STAGING_PREFIX: str = ".tmp";


def publish(
    venv_dir: str, cache_dir: str, cache_root: str, max_root_mb: float = 2048
) -> None {
    if not os.path.isdir(venv_dir) {
        return;
    }
    try {
        os.makedirs(cache_root, mode=0o2775, exist_ok=True);
    } except Exception {
        return;
    }
    if os.path.exists(cache_dir) {
        _evict_if_needed(cache_root, max_root_mb, keep=cache_dir);
        return;
    }
    staging_dir: str | None = None;
    try {
        staging_dir = tempfile.mkdtemp(prefix=_STAGING_PREFIX, dir=cache_root);
        staged_venv = os.path.join(staging_dir, "venv");
        shutil.copytree(venv_dir, staged_venv);
        os.rename(staged_venv, cache_dir);
    } except Exception {
        _ = 0;
    } finally {
        if staging_dir and os.path.isdir(staging_dir) {
            shutil.rmtree(staging_dir, ignore_errors=True);
        }
    }
    _evict_if_needed(cache_root, max_root_mb, keep=cache_dir);
}


def _dir_size_mb(path: str) -> float {
    total = 0;
    for (dirpath, _dirnames, filenames) in os.walk(path) {
        for name in filenames {
            fp = os.path.join(dirpath, name);
            try {
                total += os.path.getsize(fp);
            } except OSError {
                _ = 0;
            }
        }
    }
    return total / (1024 * 1024);
}


def _evict_if_needed(cache_root: str, max_root_mb: float, keep: str) -> None {
    if _dir_size_mb(cache_root) <= max_root_mb {
        return;
    }
    keep_name = os.path.basename(keep.rstrip(os.sep));
    try {
        candidates: list[tuple[float, str]] = [
            (e.stat(follow_symlinks=False).st_mtime, e.path)
            for e in os.scandir(cache_root)
            if e.is_dir(follow_symlinks=False)
                and e.name != keep_name
                and not e.name.startswith(_STAGING_PREFIX)
        ];
    } except Exception {
        return;
    }
    candidates.sort();
    for (_mtime, stale_path) in candidates {
        if _dir_size_mb(cache_root) <= max_root_mb {
            return;
        }
        try {
            shutil.rmtree(stale_path);
        } except Exception {
            _ = 0;
        }
    }
}
