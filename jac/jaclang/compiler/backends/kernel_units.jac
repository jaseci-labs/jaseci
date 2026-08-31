import os;

glob OSP_CORE_PARTS: list[str] = [
         "runtime/osp_kernel.jac",
         "runtime/osp_graph.jac"
     ],
     FMT_KERNEL_PARTS: list[str] = ["compiler/backends/fmt_kernel.jac"];

def _jaclang_dir -> str {
    import jaclang;
    return os.path.dirname(str(jaclang.__file__));
}

def _units_dir -> str {
    import from jaclang.jac0core.cachefs { store_dir }
    return str(store_dir("kernels"));
}

def unit_source(parts: list[str]) -> str {
    texts: list[str] = [];
    base = _jaclang_dir();
    for part in parts {
        with open(os.path.join(base, part.replace("/", os.sep)), "r") as f {
            texts.append(f.read());
        }
    }
    return "\n\n".join(texts);
}

glob _RETIRED_UNITS: set[str] = set();

def _retire_superseded_artifacts(name: str, keep: str) {
    import glob as _g;
    import time;
    import from jaclang.compiler.driver.jir { generation_ttl_seconds }
    if name in _RETIRED_UNITS {
        return;
    }
    _RETIRED_UNITS.add(name);
    ttl = generation_ttl_seconds();
    if ttl <= 0.0 {
        return;
    }
    cutoff = time.time() - ttl;
    live = f"{name}.{keep}.";
    for path in _g.`glob(os.path.join(_units_dir(), f"{name}.*")) {
        base = os.path.basename(path);
        if base.startswith(live) {
            continue;
        }
        try {
            if os.path.getmtime(path) < cutoff {
                os.remove(path);
            }
        } except OSError {
            ;
        }
    }
}

def kernel_unit_path(name: str, parts: list[str]) -> str {
    import hashlib;
    import from jaclang.jac0core.cachefs { atomic_publish }
    source = unit_source(parts);
    digest = hashlib.sha256(source.encode()).hexdigest()[:16];
    path = os.path.join(_units_dir(), f"{name}.{digest}.jac");
    if not os.path.exists(path) {
        atomic_publish(path, source.encode());
    }
    _retire_superseded_artifacts(name, digest);
    return path;
}

def osp_core_unit_path(variant: str) -> str {
    return kernel_unit_path(f"osp_core_{variant}", OSP_CORE_PARTS);
}

def fmt_kernel_unit_path(variant: str) -> str {
    return kernel_unit_path(f"fmt_kernel_{variant}", FMT_KERNEL_PARTS);
}

def _artifact_key(unit_path: str, fingerprint: str) -> str {
    import hashlib;
    import from importlib.metadata { version as pkg_version }
    import from jaclang.compiler.driver.jir { running_compiler_digest }
    try {
        jac_ver = pkg_version('jaclang');
    } except Exception {
        jac_ver = "0.0.0";
    }
    h = hashlib.sha256();
    h.update(jac_ver.encode());
    h.update(running_compiler_digest().encode());
    with open(unit_path, "rb") as f {
        h.update(f.read());
    }
    h.update(fingerprint.encode());
    return h.hexdigest()[:16];
}

def unit_artifact_path(unit_path: str, kind: str, fingerprint: str) -> str {
    stem = os.path.splitext(os.path.basename(unit_path))[0];
    key = _artifact_key(unit_path, fingerprint);
    return os.path.join(_units_dir(), f"{stem}.{key}.{kind}");
}

def load_unit_artifact(unit_path: str, kind: str, fingerprint: str) -> (str | None) {
    try {
        with open(unit_artifact_path(unit_path, kind, fingerprint), "r") as f {
            return f.read();
        }
    } except Exception {
        return None;
    }
}

def store_unit_artifact(unit_path: str, kind: str, fingerprint: str, text: str) {
    import glob as _g;
    import from jaclang.jac0core.cachefs { atomic_publish }
    path = unit_artifact_path(unit_path, kind, fingerprint);
    stem = os.path.splitext(os.path.basename(unit_path))[0];
    for stale in _g.`glob(os.path.join(_units_dir(), f"{stem}.*.{kind}")) {
        if stale != path {
            try {
                os.remove(stale);
            } except Exception {
                ;
            }
        }
    }
    try {
        with open(path, "r") as f {
            if f.read() == text {
                return;
            }
        }
    } except Exception {
        ;
    }
    atomic_publish(path, text.encode());
}

def es_pass_fingerprint -> str {
    import glob as _g;
    import hashlib;
    es_dir = os.path.join(_jaclang_dir(), *"compiler/backends/es".split("/"));
    h = hashlib.sha256();
    for pat in ["*.jac", os.path.join("impl", "*.jac")] {
        for p in sorted(_g.`glob(os.path.join(es_dir, pat))) {
            try {
                with open(p, "rb") as f {
                    h.update(f.read());
                }
            } except Exception {
                ;
            }
        }
    }
    return h.hexdigest()[:8];
}
