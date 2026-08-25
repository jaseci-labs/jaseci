"""The pass-serving binder: sealed means served, proven end to end.

These tests build the REAL fused artifact (#8707) with the real seal, then
present it to the runtime exactly the way a sealed image does, by patching
`native_artifact_for` / `native_served_modules`, the seams the binder
reads in production.

Three claims, each the runtime half of a manifest claim:

  1. **Binding serves.** First construction of a sealed pass binds the
     fused artifact ONCE (dlopen, `__jac_shared_init`, full advertised
     method surface, live `jac_str_new`), registers every served pass in
     `_NATIVE_SERVED_PASSES`, and construction
     proceeds; a real compile through the pipeline then works.
  2. **The native-execution proof.** `mat_merge_probe` parses a main and
     an annex source natively and runs the compiled
     `merge_annex_into` over the native trees inside the
     artifact; the materialized module carries the annex's statements
     (their `loc.mod_path` is the annex path), and the bytecode lane,
     computed independently, unparses identically. The bytecode merge
     never ran on the native result: the only code between the two
     parses and the woven module was the artifact's.
  3. **A broken artifact refuses.** A manifest entry whose library
     cannot bind raises at construction, naming the module.
  4. **Unregistered still refuses.** The tripwire's own refusal stands
     when the binder has nothing to bind for a module the image claims
     (`test_sealed_pass_tier.jac` pins that message; here the binder is
     given artifacts and must not launder an unbindable one).
"""

import json;
import os;
import shutil;
import tempfile;
import jaclang;
import jaclang.compiler.frontend.parser.frontend as frontend;
import jaclang.jac0core.sealed as sealed;
import jaclang.compiler.frontend.unitree as uni;
import from pathlib { Path }
import from jaclang.compiler.frontend.parser.lexer { tokenize_full }
import from jaclang.compiler.frontend.parser.parser { Parser }
import from jaclang.compiler.passes.annex_weave { merge_annex_into }
import from jaclang.compiler.passes.ast_validation_pass { ASTValidationPass }
import from jaclang.compiler.passes.pass_serve { _BIND_KEEP }
import from jaclang.compiler.passes.pass_rim {
    _NATIVE_PASS_TIER_MEMO,
    _NATIVE_SERVED_PASSES
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.tools.unparse_pass { unparse_node }
import from jaclang.dist.precompile_bytecode { seal_native_artifacts }

glob PKG_PATH = Path(jaclang.__file__).parent,
     TIER_MODULE: str = "jaclang.compiler.passes.ast_validation_pass",
     MAT_MODULE: str = "jaclang.compiler.native_materialize",
     _BUILD_MEMO: list = [];

"""Build the fused artifact once for the whole file; (tmpdir, record)."""
def _built -> tuple {
    if native_true_image() {
        testskip(
            "this runtime already serves from its own native seal; the "
            "binder ran for real at first pass construction"
        );
    }
    if _BUILD_MEMO {
        return _BUILD_MEMO[0];
    }
    # A shared, persistent seal cache instead of a throwaway tempdir: the
    # seal's single-record index reuses an artifact whose compiler digest,
    # source closure, and waiver table are unchanged (sha-verified, load
    # canary re-run), so across these suites -- and across runs -- the fused
    # build happens once instead of once per file.
    tmp = str(Path(os.path.expanduser("~/.cache/jac/seal-tests")));
    Path(tmp).mkdir(parents=True, exist_ok=True);
    record = seal_native_artifacts(PKG_PATH, Path(tmp));
    assert record is not None and record.get("artifact") , (
        "the seal refused; serving tests need the fused artifact"
    );
    result = (tmp, record, );
    _BUILD_MEMO.append(result);
    return result;
}

def native_true_image -> bool {
    return sealed.native_artifact_for(TIER_MODULE) is not None;
}

def _artifact_resolver(tmp: str, record: dict) -> any {
    `entry = record["artifact"];
    modules = set(record["modules"]);
    memo: list = [];
    def _resolve(fullname: str) -> (tuple | None) {
        if fullname not in modules {
            return None;
        }
        if not memo {
            lib_path = os.path.join(tmp, `entry["lib"]);
            layout = json.loads(
                Path(os.path.join(tmp, `entry["layout"])).read_text(encoding="utf-8")
            );
            memo.append((lib_path, layout, ));
        }
        return memo[0];
    }
    return _resolve;
}

def _reset_serving_state {
    _NATIVE_PASS_TIER_MEMO.clear();
    _NATIVE_SERVED_PASSES.clear();
    _BIND_KEEP.clear();
    frontend._NATIVE_PARSE_MEMO.clear();
}

def _run_tier_pass -> any {
    return ASTValidationPass(ir_in=uni.Module.make_stub());
}


test "binding serves a sealed pass and a real compile runs" {
    (tmp, record) = _built();
    real_for = sealed.native_artifact_for;
    real_names = sealed.native_served_modules;
    _reset_serving_state();
    sealed.native_artifact_for = _artifact_resolver(tmp, record);
    sealed.native_served_modules = lambda { sorted(record["modules"]); };
    try {
        inst = _run_tier_pass();
        assert isinstance(inst.ir_out, uni.Module) , "the tier vehicle pass did not run";
        assert TIER_MODULE in _NATIVE_SERVED_PASSES , (
            "construction succeeded without the binder registering the module"
        );
        prog = JacProgram();
        src = "def probe_fn -> int { return 41 + 1; }";
        mod = prog.compile(file_path="__serving_smoke__.jac", use_str=src);
        assert mod is not None and not prog.errors_had , (
            f"sealed-lane compile failed: {[str(e) for e in prog.errors_had][:3]}"
        );
    } finally {
        sealed.native_artifact_for = real_for;
        sealed.native_served_modules = real_names;
        _reset_serving_state();
    }
}


test "the merge probe proves the annex method body executed natively" {
    (tmp, record) = _built();
    real_for = sealed.native_artifact_for;
    real_names = sealed.native_served_modules;
    _reset_serving_state();
    sealed.native_artifact_for = _artifact_resolver(tmp, record);
    sealed.native_served_modules = lambda { sorted(record["modules"]); };
    try {
        np = frontend._native_parse();
        assert np is not None , "the temp materializer artifact did not bind";
        nl = chr(10);
        main_src = nl.join(
            [
                "obj Crate {",
                "    has load: int = 0;",
                "    def fill(n: int) -> int;",
                "}"
            ]
        );
        annex_src = nl.join(
            [
                "impl Crate.fill(n: int) -> int {",
                "    self.load += n;",
                "    return self.load;",
                "}"
            ]
        );
        main_path = "__serve_proof__.jac";
        annex_path = "__serve_proof__.impl.jac";
        (merged, m_errs, a_errs) = np.merge_probe(
            main_src, main_path, annex_src, annex_path
        );
        assert m_errs == 0 and a_errs == 0 , f"probe parses errored {m_errs}/{a_errs}";
        woven = [
            stmt
            for stmt in merged.body
            if stmt.loc.mod_path == annex_path
        ];
        assert woven , (
            "no statement in the woven module comes from the annex source; "
            "the native merge_annex_into did not execute"
        );
        (mt, _mc, _mld, _mle) = tokenize_full(main_src, main_path);
        py_main = Parser(tokens=mt, file_path=main_path, source_code=main_src).parse();
        (at, _ac, _ald, _ale) = tokenize_full(annex_src, annex_path);
        py_annex = Parser(
            tokens=at, file_path=annex_path, source_code=annex_src
        ).parse();
        merge_annex_into(py_main, py_annex);
        assert unparse_node(merged) == unparse_node(py_main) , (
            "the natively woven module and the bytecode-lane merge diverged"
        );
        assert len(merged.body) == len(py_main.body) , (
            f"woven body lengths diverged ({len(merged.body)} vs "
            f"{len(py_main.body)})"
        );
    } finally {
        sealed.native_artifact_for = real_for;
        sealed.native_served_modules = real_names;
        _reset_serving_state();
    }
}


test "a sealed pass whose artifact cannot bind refuses construction" {
    (tmp, record) = _built();
    real_for = sealed.native_artifact_for;
    real_names = sealed.native_served_modules;
    _reset_serving_state();
    good_resolve = _artifact_resolver(tmp, record);
    broken_entry = dict(record["artifact"]);
    broken_entry["lib"] = "native/definitely/not/there.so";
    def _broken_resolve(fullname: str) -> (tuple | None) {
        if fullname == TIER_MODULE {
            return (os.path.join(tmp, broken_entry["lib"]), {}, );
        }
        return good_resolve(fullname);
    }
    sealed.native_artifact_for = _broken_resolve;
    sealed.native_served_modules = lambda { sorted(record["modules"]); };
    try {
        with testraises(RuntimeError, `match=TIER_MODULE) {
            _run_tier_pass();
        }
        assert TIER_MODULE not in _NATIVE_SERVED_PASSES , (
            "a failed bind still registered the module as served"
        );
    } finally {
        sealed.native_artifact_for = real_for;
        sealed.native_served_modules = real_names;
        _reset_serving_state();
    }
}
