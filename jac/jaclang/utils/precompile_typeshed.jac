"""Build a sealed typeshed bundle from vendored .pyi stubs.

The type-checker analogue of ``utils/precompile_bytecode.jac``: compiles the
vendored typeshed stdlib stubs plus the local core stubs to module IR
(``symtab_ir_only``, ``stub_only``), writes each as a whole-module ``.jir`` via
``JirWriter``, and emits a ``MANIFEST.json`` keyed by stub fullname. The result
is loaded at type-evaluator startup by
``compiler/type_system/typeshed_image.jac`` and resolved by name with no
per-load source re-hash -- see that module for the manifest schema.

Usage::

    jac run utils/precompile_typeshed.jac <out-dir>
        [--stdlib=PATH] [--local=PATH] [--pin=PATH] [--limit=N] [--debug-src]

``--limit`` caps the stdlib stubs processed (for quick smoke runs).
"""

import hashlib;
import json;
import os;
import sys;
import from pathlib { Path }

import from jaclang.cli.console { console }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.jir_passes { JirWriter }
import from jaclang.jac0core.jir { FORMAT_VERSION }
import from jaclang.compiler.type_system.typeshed_image {
    MANIFEST_NAME,
    MANIFEST_FORMAT,
    KIND,
    python_tag
}


def stub_fullname(base_dir: str, pyi_path: str) -> str {
    rel = Path(pyi_path).relative_to(base_dir);
    parts = list(rel.with_suffix("").parts);
    if parts and parts[-1] == "__init__" {
        parts = parts[:-1];
    }
    return ".".join(parts);
}


def find_pyi_files(d: str) -> list[str] {
    result: list[str] = [];
    base = Path(d);
    if not base.is_dir() {
        return result;
    }
    for p in sorted(base.rglob("*.pyi")) {
        if p.is_file() {
            result.append(str(p));
        }
    }
    return result;
}


def compile_stub_ir(program: JacProgram, pyi_path: str) -> bytes {
    mod = program.compile(file_path=pyi_path, symtab_ir_only=True);
    if mod is None {
        raise RuntimeError(f"no IR for {pyi_path}");
    }
    mod.stub_only = True;
    return JirWriter().write_module(mod);
}


def emit_stub(
    program: JacProgram,
    pyi_path: str,
    fullname: str,
    jir_dir: Path,
    modules: dict
) -> bool {
    try {
        data = compile_stub_ir(program, pyi_path);
    } except Exception as e {
        console.error(f"FAIL {fullname}: {e}");
        return False;
    }
    jir_rel = fullname + ".jir";
    (jir_dir / jir_rel).write_bytes(data);
    modules[fullname] = {
        "jir": jir_rel,
        "sha256": hashlib.sha256(data).hexdigest()
    };
    return True;
}


def build_typeshed_bundle(
    stdlib_dir: str,
    local_dirs: list[str],
    out_dir: str,
    typeshed_pin: str,
    limit: int = 0
) -> int {
    import from importlib.metadata { version as pkg_version }
    try {
        jac_ver = pkg_version("jaclang");
    } except Exception {
        jac_ver = "0.0.0";
    }

    pyver = python_tag();
    jir_dir = Path(out_dir) / pyver;
    jir_dir.mkdir(parents=True, exist_ok=True);

    program = JacProgram();
    modules: dict = {};
    compiled = 0;
    failed = 0;

    stdlib_pyis = find_pyi_files(stdlib_dir);
    if limit > 0 {
        stdlib_pyis = stdlib_pyis[:limit];
    }
    for pyi in stdlib_pyis {
        fullname = stub_fullname(stdlib_dir, pyi);
        if emit_stub(program, pyi, fullname, jir_dir, modules) {
            compiled += 1;
        } else {
            failed += 1;
        }
        program.release_compile_closure();
    }

    for d in local_dirs {
        for pyi in find_pyi_files(d) {
            fullname = Path(pyi).stem;
            if emit_stub(program, pyi, fullname, jir_dir, modules) {
                compiled += 1;
            } else {
                failed += 1;
            }
            program.release_compile_closure();
        }
    }

    manifest = {
        "format": MANIFEST_FORMAT,
        "kind": KIND,
        "python_tag": pyver,
        "jir_format_version": FORMAT_VERSION,
        "jaclang_version": jac_ver,
        "typeshed_pin": typeshed_pin,
        "modules": modules
    };
    (Path(out_dir) / MANIFEST_NAME).write_text(
        json.dumps(manifest, sort_keys=True, indent=1) + "\n", encoding="utf-8"
    );
    console.print(
        f"typeshed bundle: {compiled} compiled, {failed} failed, "
        + f"{len(modules)} modules -> {out_dir}"
    );
    return 0 if failed == 0 else 1;
}


with entry:__main__ {
    args = sys.argv[1:];
    out_dir: (str | None) = None;
    stdlib_dir: (str | None) = None;
    local_dir: (str | None) = None;
    pin_path: (str | None) = None;
    limit = 0;
    for a in args {
        if a.startswith("--stdlib=") {
            stdlib_dir = a[len("--stdlib="):];
        } elif a.startswith("--local=") {
            local_dir = a[len("--local="):];
        } elif a.startswith("--pin=") {
            pin_path = a[len("--pin="):];
        } elif a.startswith("--limit=") {
            limit = int(a[len("--limit="):]);
        } elif not a.startswith("--") {
            out_dir = a;
        }
    }

    pkg_dir = Path(__file__ as str).resolve().parent.parent;
    if stdlib_dir is None {
        stdlib_dir = str(pkg_dir / "vendor" / "typeshed" / "stdlib");
    }
    local_dirs: list[str] = [];
    if local_dir is not None {
        local_dirs.append(local_dir as str);
    } else {
        local_dirs.append(str(pkg_dir / "compiler" / "type_system"));
    }
    if pin_path is None {
        pin_path = str(pkg_dir / "vendor" / "typeshed" / "PIN");
    }
    if out_dir is None {
        console.error(
            "usage: jac run utils/precompile_typeshed.jac <out-dir> "
            + "[--stdlib=PATH] [--local=PATH] [--pin=PATH] [--limit=N]"
        );
        sys.exit(2);
    }

    typeshed_pin = "";
    try {
        typeshed_pin = Path(pin_path as str).read_text(encoding="utf-8").strip();
    } except Exception {
        console.error(f"warning: could not read typeshed PIN at {pin_path}");
    }

    sys.exit(
        build_typeshed_bundle(
            stdlib_dir as str, local_dirs, out_dir as str, typeshed_pin, limit
        )
    );
}
