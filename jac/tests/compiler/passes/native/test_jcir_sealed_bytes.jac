"""Sealed-native JCIR bytes equal Python-lane JCIR bytes (epic #8201 phase C2).

`test_jcir_container_canary.jac` proves the container is byte stable and
the crossing lossless, but both lanes there are the same Python-lane
emitter. This closes that honest limit: it builds the real
`jcir_gen_pass` artifact with the real seal, presents it to the runtime
the way a sealed image does, and compares the bytes the **sealed
emitter** produces against the bytes the **source lane** produces for
the same modules.

No bespoke ctypes entry is needed. The pass-serving binder is already
the crossing: once `native_artifact_for` reports an artifact for
`jaclang.jac0core.passes.jcir_gen_pass`, constructing `JcirGenPass`
binds it and its methods run inside the artifact, so `ir_bytes()` is the
entry surface. That is the same production path
`test_sealed_pass_serving.jac` exercises for the annex pass, which is
why this file borrows its harness rather than inventing one.

The comparison is on the container bytes, which is the artifact the
cutover ships on. Where a mismatch is found the code objects are also
compared field by field, never by marshal bytes (internals section 10),
so the failure names a field rather than an offset.

The corpus is the one the cutover requirements name: comments,
diagnostics, string-named tests, and circular includes.
"""

import ast as pyast;
import json;
import os;
import shutil;
import tempfile;
import types;
import pytest;
import jaclang;
import jaclang.jac0core.parser.frontend as frontend;
import jaclang.jac0core.sealed as sealed;
import jaclang.jac0core.unitree as uni;
import from builtins { compile as pycompile }
import from pathlib { Path }
import from jaclang.jac0core.codegen_shim { transcribe }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.passes.pass_serve { _BIND_KEEP }
import from jaclang.jac0core.passes.transform {
    _NATIVE_PASS_TIER_MEMO,
    _NATIVE_SERVED_PASSES
}
import from jaclang.jac0core.passes.jcir_gen_pass { JcirGenPass }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.utils.precompile_bytecode { seal_native_artifacts }

glob PKG_PATH = Path(jaclang.__file__).parent,
     JCIR_MODULE: str = "jaclang.jac0core.passes.jcir_gen_pass",
     SEAL_MODULES: tuple = (
         "jac0core/unitree.jac",
         "jac0core/passes/jcir_gen_pass.jac"
     ),
     _BUILD_MEMO: list = [];

glob CORPUS: tuple = (
         (
             "comments",
             "\"\"\"Doc.\"\"\"\n# leading\nglob seeded: int = 1;\n\n"
                 + "def widen(n: int) -> int {\n    total = n + seeded;  # tail\n"
                 + "    return total;\n}\n\nwith entry { widened = widen(2); }\n",
             "sealed_comments.jac"
         ),
         (
             "string-named tests",
             "def triple(x: int) -> int {\n    return x * 3;\n}\n\n"
                 + "test \"a named test with 'quotes'\" { assert triple(3) == 9; }\n",
             "sealed_tests.jac"
         ),
         (
             "diagnostics",
             "def tail(n: int) -> int {\n    return n;\n    stranded = n + 1;\n}\n"
                 + "\nwith entry { kept = tail(4); }\n",
             "sealed_diags.jac"
         ),
         (
             "circular include a",
             "import from circular_b { beta }\n\ndef alpha(n: int) -> int {\n"
                 + "    return n + 1;\n}\n\nwith entry { a_result = alpha(1); }\n",
             "circular_a.jac"
         ),
         (
             "circular include b",
             "import from circular_a { alpha }\n\ndef beta(n: int) -> int {\n"
                 + "    return n + 2;\n}\n\nwith entry { b_result = beta(1); }\n",
             "circular_b.jac"
         )
     );

"""True when this runtime already serves jcir from its own native seal."""
def native_true_image -> bool {
    return sealed.native_artifact_for(JCIR_MODULE) is not None;
}

"""Build the jcir artifact once for the whole file; (tmpdir, artifacts)."""
def _built -> tuple {
    if native_true_image() {
        pytest.skip(
            "this runtime already serves jcir from its own native seal, so "
            "both sides of the comparison would be the sealed lane"
        );
    }
    if _BUILD_MEMO {
        return _BUILD_MEMO[0];
    }
    tmp = tempfile.mkdtemp(prefix="jac_jcir_bytes_");
    arts = seal_native_artifacts(PKG_PATH, Path(tmp), modules=SEAL_MODULES);
    assert arts is not None , (
        "the seal refused; the sealed-versus-source comparison needs an "
        "artifact. If the jcir root was refused, this file is the thing "
        "that should have caught it"
    );
    assert JCIR_MODULE in arts , (
        f"the seal produced no artifact for {JCIR_MODULE}: {sorted(arts)}"
    );
    result = (tmp, arts, );
    _BUILD_MEMO.append(result);
    return result;
}

def _artifact_resolver(tmp: str, arts: dict) -> any {
    def _resolve(fullname: str) -> (tuple | None) {
        entry = arts.get(fullname);
        if entry is None {
            return None;
        }
        lib_path = os.path.join(tmp, entry["lib"]);
        layout = json.loads(
            Path(os.path.join(tmp, entry["layout"])).read_text(encoding="utf-8")
        );
        return (lib_path, layout, );
    }
    return _resolve;
}

def _reset_serving_state {
    _NATIVE_PASS_TIER_MEMO.clear();
    _NATIVE_SERVED_PASSES.clear();
    _BIND_KEEP.clear();
    frontend._NATIVE_PARSE_MEMO.clear();
}

"""Container bytes plus the shim tree, for one source, in this runtime."""
def _emit(src: str, path: str) -> tuple {
    prog = JacProgram();
    mod = prog.compile(
        use_str=src,
        file_path=path,
        options=CompileOptions(
            force_codespace="server",
            skip_native_engine=True,
            no_ir_cache=True,
            suppress_codes=["E5092"]
        )
    );
    assert len(prog.errors_had) == 0 , str([str(e) for e in prog.errors_had]);
    blob = JcirGenPass(ir_in=mod, prog=prog).ir_bytes();
    (mods, _diags) = transcribe(blob);
    assert len(mods) == 1;
    return (blob, mods[0][1], );
}

glob _CODE_FIELDS: tuple = (
         "co_name",
         "co_qualname",
         "co_filename",
         "co_firstlineno",
         "co_argcount",
         "co_posonlyargcount",
         "co_kwonlyargcount",
         "co_nlocals",
         "co_stacksize",
         "co_flags",
         "co_code",
         "co_names",
         "co_varnames",
         "co_freevars",
         "co_cellvars",
         "co_linetable",
         "co_exceptiontable"
     );

"""Field-by-field code comparison, recursive through co_consts."""
def code_field_diffs(a: any, b: any, at: str, out: list[str]) -> list[str] {
    for attr in _CODE_FIELDS {
        av = getattr(a, attr, None);
        bv = getattr(b, attr, None);
        if av != bv {
            out.append(f"{at}.{attr}: source {av!r} vs sealed {bv!r}");
        }
    }
    if len(a.co_consts) != len(b.co_consts) {
        out.append(f"{at}.co_consts length {len(a.co_consts)} vs {len(b.co_consts)}");
        return out;
    }
    for (i, (x, y)) in enumerate(zip(a.co_consts, b.co_consts)) {
        if (isinstance(x, types.CodeType) and isinstance(y, types.CodeType)) {
            code_field_diffs(x, y, f"{at}.consts[{i}]", out);
        } elif (x != y or type(x) is not type(y)) {
            out.append(f"{at}.consts[{i}]: source {x!r} vs sealed {y!r}");
        }
    }
    return out;
}


test "the sealed emitter is actually bound and serving" {
    (tmp, arts) = _built();
    real_for = sealed.native_artifact_for;
    real_names = sealed.native_artifact_names;
    _reset_serving_state();
    sealed.native_artifact_for = _artifact_resolver(tmp, arts);
    sealed.native_artifact_names = lambda { list(arts.keys()); };
    try {
        _emit("with entry { probe = 1; }", "bind_probe.jac");
        assert JCIR_MODULE in _NATIVE_SERVED_PASSES , (
            "the emitter ran without the binder registering it, so a byte "
            "comparison below would be source lane against source lane and "
            "would pass for the wrong reason"
        );
    } finally {
        sealed.native_artifact_for = real_for;
        sealed.native_artifact_names = real_names;
        _reset_serving_state();
    }
}


test "sealed-native container bytes equal Python-lane container bytes" {
    (tmp, arts) = _built();
    source_side: dict[(str, tuple)] = {};
    for (label, src, path) in CORPUS {
        source_side[label] = _emit(src, path);
    }
    real_for = sealed.native_artifact_for;
    real_names = sealed.native_artifact_names;
    _reset_serving_state();
    sealed.native_artifact_for = _artifact_resolver(tmp, arts);
    sealed.native_artifact_names = lambda { list(arts.keys()); };
    failures: list[str] = [];
    try {
        assert JCIR_MODULE in arts;
        for (label, src, path) in CORPUS {
            (sealed_blob, sealed_tree) = _emit(src, path);
            (source_blob, source_tree) = source_side[label];
            if sealed_blob == source_blob {
                continue;
            }
            detail = (
                f"{label} ({path}): sealed {len(sealed_blob)} bytes vs source "
                f"{len(source_blob)} bytes"
            );
            i = 0;
            n = min(len(sealed_blob), len(source_blob));
            while (i < n and sealed_blob[i] == source_blob[i]) {
                i += 1;
            }
            detail += f", first difference at offset {i}";
            diffs = code_field_diffs(
                pycompile(source_tree, path, "exec"),
                pycompile(sealed_tree, path, "exec"),
                "<module>",
                []
            );
            if diffs {
                detail += "\n    " + "\n    ".join(diffs[:8]);
            } else {
                detail += (
                    " (the code objects agree field for field, so the "
                    "divergence is in the container encoding, not the recipe)"
                );
            }
            failures.append(detail);
        }
    } finally {
        sealed.native_artifact_for = real_for;
        sealed.native_artifact_names = real_names;
        _reset_serving_state();
    }
    assert not failures , (
        f"{len(failures)} corpus module(s) produced different JCIR bytes "
        "under the sealed emitter than under the source lane. The container "
        "is what crosses the boundary, so the two lanes have to agree on it "
        "exactly:\n  " + "\n  ".join(failures)
    );
}
