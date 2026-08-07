"""Stable materialization of jac0core kernel compilation units (#7963).

The portable kernels (osp_kernel + osp_graph as the one OSP unit; fmt_kernel)
are consumed several ways -- compiled to JS for the client bundle, walked
symtab-only for native IR generation, compiled to LLVM IR for native linking.
Each consumer previously copied the sources into a fresh tempdir per process,
which defeated any caching (a fresh path is a fresh identity, so every process
paid a cold kernel compile) and embedded ephemeral tempdir paths in native
debug metadata.

A unit instead materializes once per (name, content) at a stable path under
the jac cache root, and derived outputs (kernel JS, kernel LLVM IR) persist
beside it as content-keyed artifacts: the key hashes the jaclang version, the
unitree schema digest, the unit sources, and the consumer's own emitter
fingerprint, so staleness is impossible by construction -- editing a kernel
source or an emitter rebuilds, everything else is a warm read. Consumers that
compile one unit under different codegen options use distinct variant names so
each configuration keeps its own identity instead of thrashing one file.
"""

import os;

def _jac0core_dir -> str {
    import jaclang;
    return os.path.join(os.path.dirname(str(jaclang.__file__)), "jac0core");
}

def _units_dir -> str {
    import from jaclang.jac0core.cache_paths { get_jir_cache_dir }
    d = os.path.join(str(get_jir_cache_dir()), "kernel_units");
    os.makedirs(d, exist_ok=True);
    return d;
}

def unit_source(parts: list[str]) -> str {
    texts: list[str] = [];
    core = _jac0core_dir();
    for part in parts {
        with open(os.path.join(core, part), "r") as f {
            texts.append(f.read());
        }
    }
    return "\n\n".join(texts);
}

def _atomic_write(path: str, text: str) {
    tmp = f"{path}.{os.getpid()}.tmp";
    with open(tmp, "w") as f {
        f.write(text);
    }
    os.replace(tmp, path);
}

def kernel_unit_path(name: str, parts: list[str]) -> str {
    source = unit_source(parts);
    path = os.path.join(_units_dir(), f"{name}.jac");
    try {
        with open(path, "r") as f {
            if f.read() == source {
                return path;
            }
        }
    } except Exception {
        ;
    }
    _atomic_write(path, source);
    return path;
}

def osp_core_unit_path(variant: str) -> str {
    return kernel_unit_path(f"osp_core_{variant}", ["osp_kernel.jac", "osp_graph.jac"]);
}

def fmt_kernel_unit_path(variant: str) -> str {
    return kernel_unit_path(f"fmt_kernel_{variant}", ["fmt_kernel.jac"]);
}

def _artifact_key(parts: list[str], fingerprint: str) -> str {
    # Same trust basis as compute_module_key: jaclang version, the unitree
    # schema digest, the unit sources, plus the consumer's own fingerprint
    # (which hashes its emitter sources, so dev edits invalidate).
    import hashlib;
    import from importlib.metadata { version as pkg_version }
    import from jaclang.jac0core.jir { schema_digest }
    try {
        jac_ver = pkg_version('jaclang');
    } except Exception {
        jac_ver = "0.0.0";
    }
    h = hashlib.sha256();
    h.update(jac_ver.encode());
    h.update(schema_digest().encode());
    h.update(unit_source(parts).encode());
    h.update(fingerprint.encode());
    return h.hexdigest()[:16];
}

def unit_artifact_path(
    name: str, parts: list[str], kind: str, fingerprint: str
) -> str {
    key = _artifact_key(parts, fingerprint);
    return os.path.join(_units_dir(), f"{name}.{key}.{kind}");
}

def load_unit_artifact(
    name: str, parts: list[str], kind: str, fingerprint: str
) -> (str | None) {
    try {
        with open(unit_artifact_path(name, parts, kind, fingerprint), "r") as f {
            return f.read();
        }
    } except Exception {
        return None;
    }
}

def store_unit_artifact(
    name: str, parts: list[str], kind: str, fingerprint: str, text: str
) {
    import glob as _g;
    path = unit_artifact_path(name, parts, kind, fingerprint);
    for stale in _g.glob(os.path.join(_units_dir(), f"{name}.*.{kind}")) {
        if stale != path {
            try {
                os.remove(stale);
            } except Exception {
                ;
            }
        }
    }
    _atomic_write(path, text);
}

def es_pass_fingerprint -> str {
    # The ES analog of native_compiler_fingerprint: hash the ecmascript
    # emitter sources so editing the ES pass invalidates cached kernel JS.
    import glob as _g;
    import hashlib;
    es_dir = os.path.join(
        os.path.dirname(_jac0core_dir()), "compiler", "passes", "ecmascript"
    );
    h = hashlib.sha256();
    for pat in ["*.jac", os.path.join("impl", "*.jac")] {
        for p in sorted(_g.glob(os.path.join(es_dir, pat))) {
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
