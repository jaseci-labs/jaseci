"""Native codegen driven by the compile-options object (#7871 workstream G).

The RC debug trace gate (#7854) must respond to CompileOptions.rc_debug_codegen
with no env var involved; flipping a codegen option must re-key the native
import IR cache instead of serving a stale artifact; and a cached dep whose
stamped options fingerprint disagrees with the current build is a hard E5027,
never a silent mixed-options link.
"""

import glob;
import json;
import os;
import shutil;
import tempfile;
import uuid;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.jir { get_native_cache_dir }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");


def _write_pair(tmp: str, dep_stem: str) -> str {
    salt = uuid.uuid4().hex;
    with open(os.path.join(tmp, f"{dep_stem}.jac"), "w") as f {
        f.write(
            "glob SALT: str = '" + salt + "';\n" + "def fn() -> int { return 41; }\n"
        );
    }
    main_path = os.path.join(tmp, f"main_{dep_stem}.jac");
    with open(main_path, "w") as f {
        f.write(
            f"import {dep_stem};\n" "def:pub use_fn -> int { return "
                + dep_stem
                + ".fn() + 1; }\n" "with entry {}\n"
        );
    }
    return main_path;
}


def _aot_opts(rc_debug: bool) -> CompileOptions {
    return CompileOptions(
        aot_mode=True,
        type_check=False,
        default_codespace='native',
        force_target_program=True,
        na_gc_mode='cycles',
        rc_debug_codegen=rc_debug
    );
}


def _compile_main(main_path: str, rc_debug: bool) -> JacProgram {
    prog = JacProgram();
    prog.compile(file_path=main_path, options=_aot_opts(rc_debug));
    return prog;
}


def _dep_cache_files(tmp: str, dep_stem: str, ext: str) -> list[str] {
    cache_dir = str(get_native_cache_dir(os.path.join(tmp, f"{dep_stem}.jac")));
    return sorted(glob.glob(os.path.join(cache_dir, f"{dep_stem}.*.{ext}")));
}


test "rc debug trace gate is driven by the options object, not env" {
    saved = os.environ.pop("JAC_RC_DEBUG_CODEGEN", None);
    try {
        for gate_on in [False, True] {
            with tempfile.TemporaryDirectory() as tmp {
                src = os.path.join(tmp, "rc_debug_trace.jac");
                shutil.copyfile(os.path.join(FIXTURES, "rc_debug_trace.jac"), src);
                prog = JacProgram();
                ir_mod = prog.compile(
                    file_path=src,
                    options=CompileOptions(
                        aot_mode=True,
                        skip_native_engine=True,
                        type_check=False,
                        default_codespace='native',
                        force_target_program=True,
                        na_gc_mode='cycles',
                        rc_debug_codegen=gate_on
                    )
                );
                assert not prog.errors_had , (
                    f"compile errors: {[str(e) for e in prog.errors_had]}"
                );
                assert ir_mod.gen.llvm_ir is not None;
                ir_text = str(ir_mod.gen.llvm_ir);
                if gate_on {
                    assert "RC MALLOC" in ir_text , (
                        "options-object gate ON compiled the trace out"
                    );
                } else {
                    assert "RC MALLOC" not in ir_text , (
                        "options-object gate OFF still compiled the trace in"
                    );
                }
            }
        }
    } finally {
        if saved is not None {
            os.environ["JAC_RC_DEBUG_CODEGEN"] = saved;
        }
    }
}

test "flipping a codegen option re-keys the native import cache" {
    dep_stem = "g_optdep_rekey_7871";
    with tempfile.TemporaryDirectory() as tmp {
        main_path = _write_pair(tmp, dep_stem);
        prog_a = _compile_main(main_path, False);
        assert not prog_a.errors_had , (
            f"option-A compile errors: {[str(e) for e in prog_a.errors_had]}"
        );
        files_a = _dep_cache_files(tmp, dep_stem, "ir_cache");
        assert len(files_a) == 1 , f"expected one dep artifact, got {files_a}";
        prog_b = _compile_main(main_path, True);
        assert not prog_b.errors_had , (
            f"option-B compile errors: {[str(e) for e in prog_b.errors_had]}"
        );
        files_b = _dep_cache_files(tmp, dep_stem, "ir_cache");
        assert len(files_b) == 1;
        assert os.path.basename(files_a[0]) != os.path.basename(files_b[0]) , (
            "option flip reused the same native cache artifact"
        );
        metas = _dep_cache_files(tmp, dep_stem, "ir_meta");
        assert len(metas) == 1;
        with open(metas[0], "r") as f {
            meta = json.loads(f.read());
        }
        expected_fp = _aot_opts(True).codegen_fingerprint();
        assert meta.get("options_fingerprint") == expected_fp , (
            f"meta stamp {meta.get('options_fingerprint')} != {expected_fp}"
        );
    }
}

test "a fingerprint-mismatched cached dep is a hard E5027, never linked" {
    dep_stem = "g_optdep_mixed_7871";
    with tempfile.TemporaryDirectory() as tmp {
        main_path = _write_pair(tmp, dep_stem);
        prog_a = _compile_main(main_path, False);
        assert not prog_a.errors_had , (
            f"seed compile errors: {[str(e) for e in prog_a.errors_had]}"
        );
        metas = _dep_cache_files(tmp, dep_stem, "ir_meta");
        assert len(metas) == 1;
        with open(metas[0], "r") as f {
            meta = json.loads(f.read());
        }
        meta["options_fingerprint"] = "0000deadfp00";
        with open(metas[0], "w") as f {
            f.write(json.dumps(meta));
        }
        prog_b = _compile_main(main_path, False);
        codes = [(e.code.code if e.code else "") for e in prog_b.errors_had];
        assert "E5027" in codes , (
            f"expected E5027 on mixed-options cache hit, got {codes}"
        );
    }
}
