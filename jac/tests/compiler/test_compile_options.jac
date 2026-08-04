"""Compile-options identity and boundary tests (#7871 workstream G).

CompileOptions is the single authority for codegen-affecting build options:
env vars are read once at options construction, the codegen fingerprint is
part of artifact identity (folded into the JIR module key), and no compiler
pass reads os.environ directly (source-scan gate below).
"""

import os;
import re;
import tempfile;
import from pathlib { Path }
import from jaclang.jac0core.compile_options {
    CompileOptions,
    effective_codegen_fingerprint,
    link_fingerprint_mismatches
}
import from jaclang.jac0core.jir { compute_module_key }


def _pinned_opts(**overrides: any) -> CompileOptions {
    base: dict = {
        "na_gc_mode": "cycles",
        "nogc_enforce_all": False,
        "nogc_cli_target": "",
        "nogc_enforce_modules": [],
        "nogc_grandfathered": [],
        "rc_debug_codegen": False,
        "native_target": "",
        "native_debug": False,
        "opt_level": 2
    };
    base.update(overrides);
    return CompileOptions(**base);
}


test "identical codegen options produce an identical fingerprint" {
    assert _pinned_opts().codegen_fingerprint() == _pinned_opts().codegen_fingerprint();
}

test "every codegen option flip changes the fingerprint" {
    base_fp = _pinned_opts().codegen_fingerprint();
    flips: list = [
        _pinned_opts(na_gc_mode="none"),
        _pinned_opts(na_gc_mode="rc"),
        _pinned_opts(nogc_enforce_all=True),
        _pinned_opts(nogc_cli_target="mainmod"),
        _pinned_opts(nogc_enforce_modules=["svc*"]),
        _pinned_opts(nogc_grandfathered=["legacy*"]),
        _pinned_opts(rc_debug_codegen=True),
        _pinned_opts(native_target="wasm32-unknown-unknown"),
        _pinned_opts(native_debug=True),
        _pinned_opts(opt_level=0)
    ];
    seen: set = {base_fp};
    for flipped in flips {
        fp = flipped.codegen_fingerprint();
        assert fp != base_fp , (
            f"flip did not change fingerprint: {flipped.codegen_identity()}"
        );
        seen.add(fp);
    }
    assert len(seen) == len(flips) + 1 , "fingerprint collision between flips";
}

test "diagnostic-only options do not enter the fingerprint" {
    base_fp = _pinned_opts().codegen_fingerprint();
    diag = _pinned_opts(
        dump_ir_path="/tmp/out.ll", debug_ir=True, rc_stats=True, nogc_debug=True
    );
    assert diag.codegen_fingerprint() == base_fp;
}

test "clone_for_native_import carries the full codegen identity" {
    parent = _pinned_opts(
        na_gc_mode="rc",
        rc_debug_codegen=True,
        native_target="x86_64-unknown-linux-gnu",
        native_debug=True,
        opt_level=1,
        nogc_enforce_modules=["svc*"],
        nogc_grandfathered=["legacy*"]
    );
    child = parent.clone_for_native_import();
    assert child.skip_native_engine and child.aot_mode;
    parent_id = parent.codegen_identity();
    child_id = child.codegen_identity();
    parent_tail = parent_id.split("nogc_mods=")[1];
    child_tail = child_id.split("nogc_mods=")[1];
    assert parent_tail == child_tail;
    assert parent_id.split(";")[0] == child_id.split(";")[0];
}

test "link_fingerprint_mismatches names every non-matching participant" {
    current = _pinned_opts().codegen_fingerprint();
    other = _pinned_opts(na_gc_mode="none").codegen_fingerprint();
    got = link_fingerprint_mismatches(
        [("a.jac", current), ("b.jac", other), ("c.jac", "")], current
    );
    assert got == ["b.jac", "c.jac"];
    assert link_fingerprint_mismatches([("a.jac", current)], current) == [];
}

test "env overrides enter the options object at construction" {
    saved = os.environ.pop("JAC_RC_DEBUG_CODEGEN", None);
    try {
        assert CompileOptions().rc_debug_codegen == False;
        os.environ["JAC_RC_DEBUG_CODEGEN"] = "1";
        assert CompileOptions().rc_debug_codegen == True;
        assert CompileOptions(rc_debug_codegen=False).rc_debug_codegen == False;
    } finally {
        if saved is None {
            os.environ.pop("JAC_RC_DEBUG_CODEGEN", None);
        } else {
            os.environ["JAC_RC_DEBUG_CODEGEN"] = saved;
        }
    }
}

test "JIR module key changes when a codegen env flag flips" {
    saved_rc = os.environ.pop("JAC_RC_DEBUG_CODEGEN", None);
    saved_tgt = os.environ.pop("JAC_NATIVE_TARGET", None);
    try {
        with tempfile.TemporaryDirectory() as tmp {
            src = os.path.join(tmp, "modkey_probe.jac");
            with open(src, "w") as f {
                f.write("with entry { print(1); }\n");
            }
            base_key = compute_module_key(src);
            assert base_key == compute_module_key(src);
            os.environ["JAC_RC_DEBUG_CODEGEN"] = "1";
            rc_key = compute_module_key(src);
            os.environ.pop("JAC_RC_DEBUG_CODEGEN", None);
            os.environ["JAC_NATIVE_TARGET"] = "wasm32-unknown-unknown";
            tgt_key = compute_module_key(src);
            os.environ.pop("JAC_NATIVE_TARGET", None);
            assert rc_key != base_key , "JAC_RC_DEBUG_CODEGEN flip kept the key";
            assert tgt_key != base_key , "JAC_NATIVE_TARGET flip kept the key";
            assert compute_module_key(src) == base_key;
        }
    } finally {
        if saved_rc is not None {
            os.environ["JAC_RC_DEBUG_CODEGEN"] = saved_rc;
        }
        if saved_tgt is not None {
            os.environ["JAC_NATIVE_TARGET"] = saved_tgt;
        }
    }
}

test "effective fingerprint tracks the process env" {
    saved = os.environ.pop("JAC_RC_DEBUG_CODEGEN", None);
    try {
        base = effective_codegen_fingerprint();
        os.environ["JAC_RC_DEBUG_CODEGEN"] = "1";
        assert effective_codegen_fingerprint() != base;
    } finally {
        if saved is None {
            os.environ.pop("JAC_RC_DEBUG_CODEGEN", None);
        } else {
            os.environ["JAC_RC_DEBUG_CODEGEN"] = saved;
        }
    }
}

test "no compiler pass reads the environment directly" {
    import jaclang;
    passes_dir = os.path.join(
        os.path.dirname(os.path.abspath(jaclang.__file__)), "compiler", "passes"
    );
    assert os.path.isdir(passes_dir) , f"passes dir missing: {passes_dir}";
    patterns = [
        re.compile(r"\.environ"),
        re.compile(r"\bos\.getenv\s*\("),
        re.compile(r"import\s+from\s+os\s*\{[^}]*environ")
    ];
    offenders: list[str] = [];
    for (dirpath, _dirs, files) in os.walk(passes_dir) {
        for fname in files {
            if not (fname.endswith(".jac") or fname.endswith(".py")) {
                continue;
            }
            fpath = os.path.join(dirpath, fname);
            with open(fpath, "r", encoding="utf-8", errors="replace") as f {
                for (lineno, line) in enumerate(f, 1) {
                    for pat in patterns {
                        if pat.search(line) {
                            rel = os.path.relpath(fpath, passes_dir);
                            offenders.append(f"{rel}:{lineno}: {line.strip()}");
                        }
                    }
                }
            }
        }
    }
    assert not offenders , (
        "environment reads found under compiler/passes (options must enter "
        "through CompileOptions at the program boundary):\n"
        + "\n".join(offenders)
    );
}

test "no positional intrinsic name matching inside _codegen_call" {
    import jaclang;
    calls_impl = os.path.join(
        os.path.dirname(os.path.abspath(jaclang.__file__)),
        "compiler",
        "passes",
        "native",
        "na_ir_gen_pass.impl",
        "calls.impl.jac"
    );
    assert os.path.isfile(calls_impl) , f"calls impl missing: {calls_impl}";
    with open(calls_impl, "r", encoding="utf-8") as f {
        source = f.read();
    }
    assert "RC_INTRINSIC_NAMES" not in source , (
        "the RC intrinsic pre-classification name set must stay deleted; "
        "INTRINSIC_REGISTRY is the sole authority"
    );
    marker = "impl NaIRGenPass._codegen_call(";
    start = source.find(marker);
    assert start >= 0 , "_codegen_call impl not found";
    nxt = source.find("\nimpl ", start + len(marker));
    block = source[start:nxt] if nxt >= 0 else source[start:];
    assert block.count("INTRINSIC_REGISTRY.get(") == 1 , (
        "_codegen_call must consult the intrinsic registry through exactly "
        "one lookup"
    );
    cmp_pats = [
        re.compile(r"(==|!=|\bnot\s+in\b|\bin\b)\s*\(?\s*[\"']__"),
        re.compile(r"[\"']__\w+[\"']\s*(==|!=|\bnot\s+in\b|\bin\b)")
    ];
    offenders: list[str] = [];
    for (lineno, line) in enumerate(block.splitlines(), 1) {
        for pat in cmp_pats {
            if pat.search(line) {
                offenders.append(f"_codegen_call+{lineno}: {line.strip()}");
            }
        }
    }
    assert not offenders , (
        "string comparison against a reserved __ intrinsic name inside "
        "_codegen_call (intrinsics must dispatch through "
        "INTRINSIC_REGISTRY):\n"
        + "\n".join(offenders)
    );
}
