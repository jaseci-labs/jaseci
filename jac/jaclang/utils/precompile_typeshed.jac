import hashlib;
import json;
import os;
import shutil;
import sys;
import from pathlib { Path }

import from jaclang.cli.console { console }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.jir_passes { JirWriter }
import from jaclang.jac0core.jir {
    FORMAT_VERSION,
    SEC_MODKEY,
    compute_module_key,
    jir_matches_source
}
import from jaclang.compiler.type_system.typeshed_image {
    MANIFEST_NAME,
    MANIFEST_FORMAT,
    KIND,
    python_tag,
    stub_fullname,
    sealed_stub_skipped
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


def reuse_stub(pyi_path: str, fullname: str, jir_dir: Path, modules: dict) -> bool {
    jir_rel = fullname + ".jir";
    jir_path = jir_dir / jir_rel;
    if not jir_path.is_file() {
        return False;
    }
    try {
        existing = jir_path.read_bytes();
    } except Exception {
        return False;
    }
    if not jir_matches_source(existing, pyi_path) {
        return False;
    }
    modules[fullname] = {
        "jir": jir_rel,
        "sha256": hashlib.sha256(existing).hexdigest()
    };
    return True;
}


def emit_stub(
    program: JacProgram, pyi_path: str, fullname: str, jir_dir: Path, modules: dict
) -> bool {
    try {
        mod = program.compile(file_path=pyi_path, symtab_ir_only=True);
        if mod is None {
            raise RuntimeError(f"no IR for {pyi_path}");
        }
        mod.stub_only = True;
        mod_key = compute_module_key(pyi_path);
        data = JirWriter().write_module(
            mod, sections={SEC_MODKEY: mod_key.encode("utf-8")}
        );
    } except Exception as e {
        console.error(f"FAIL {fullname}: {e}");
        return False;
    }
    jir_rel = fullname + ".jir";
    (jir_dir / jir_rel).write_bytes(data);
    modules[fullname] = {"jir": jir_rel, "sha256": hashlib.sha256(data).hexdigest()};
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
    out_path = Path(out_dir);
    if out_path.is_dir() {
        for stale_dir in sorted(out_path.iterdir()) {
            if stale_dir.is_dir() and stale_dir.name != pyver {
                shutil.rmtree(stale_dir, ignore_errors=True);
            }
        }
    }
    jir_dir = out_path / pyver;
    jir_dir.mkdir(parents=True, exist_ok=True);

    program = JacProgram();
    modules: dict = {};
    compiled = 0;
    reused = 0;
    failed = 0;

    stdlib_pyis = find_pyi_files(stdlib_dir);
    if limit > 0 {
        stdlib_pyis = stdlib_pyis[:limit];
    }
    local_pyis: list[tuple[str, str]] = [];
    for d in local_dirs {
        for pyi in find_pyi_files(d) {
            local_pyis.append((pyi, Path(pyi).stem));
        }
    }
    expected: set[str] = {
        stub_fullname(stdlib_dir, pyi) + ".jir"
        for pyi in stdlib_pyis
        if not sealed_stub_skipped(stub_fullname(stdlib_dir, pyi))
    };
    for (_, fullname) in local_pyis {
        expected.add(fullname + ".jir");
    }
    for old_jir in sorted(jir_dir.rglob("*.jir")) {
        if str(old_jir.relative_to(jir_dir)) not in expected {
            old_jir.unlink();
        }
    }

    total = len(stdlib_pyis) + len(local_pyis);
    done = 0;

    for pyi in stdlib_pyis {
        fullname = stub_fullname(stdlib_dir, pyi);
        if sealed_stub_skipped(fullname) {
            continue;
        }
        done += 1;
        label = fullname[:60].ljust(60);
        sys.stderr.write(f"\r  [{done}/{total}] {label}");
        sys.stderr.flush();
        if reuse_stub(pyi, fullname, jir_dir, modules) {
            reused += 1;
            continue;
        }
        if emit_stub(program, pyi, fullname, jir_dir, modules) {
            compiled += 1;
        } else {
            failed += 1;
        }
        program.release_compile_closure();
    }

    for (pyi, fullname) in local_pyis {
        done += 1;
        label = fullname[:60].ljust(60);
        sys.stderr.write(f"\r  [{done}/{total}] {label}");
        sys.stderr.flush();
        if reuse_stub(pyi, fullname, jir_dir, modules) {
            reused += 1;
            continue;
        }
        if emit_stub(program, pyi, fullname, jir_dir, modules) {
            compiled += 1;
        } else {
            failed += 1;
        }
        program.release_compile_closure();
    }

    sys.stderr.write("\n");
    sys.stderr.flush();

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
        f"typeshed bundle: {compiled} compiled, {reused} reused, {failed} failed, "
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
