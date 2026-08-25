"""Native seal baselines for every sealing wave, measured from one table.

Each root below is measured exactly the way `seal_native_artifacts` measures
it, and three things are pinned per root -- the discipline
`test_unitree_seal_baseline.jac` set:

  1. **Closure membership** is exact. A new member beyond the recorded set
     means a module-level import changed and has to reach zero un-waived
     seams before the root can keep sealing.
  2. **The root produces native IR.** A zero-seam census without IR means
     "not reached", not "clean".
  3. **The seam set matches `NATIVE_SEAL_DEMOTION_WAIVERS` two-way.** An
     un-waived seam fails (it would ship as an `abort()` stub), and a waiver
     that stops matching a real seam fails too, so the table can only shrink
     honestly.

`test_sealed_seam_reachability.jac` proves the other half for every waiver:
no waived name is reachable through native-internal calls from the root's
live entry surface, so each stub ships dead.

These five checks were previously seven near-identical files
(`test_pass_seal_wave1..5,7_baseline.jac`) that differed only in their root
and closure data -- waves 2 and 4 were byte-identical once the data globs were
stripped. The data is now `WAVE_CLOSURES` and the checks run once per
(wave, root) row. `test_pass_seal_wave6_baseline.jac` stays separate: it
records a refusal, not a baseline. The wave-specific invariants that a few
waves carry beyond the five follow the parametrized suites below.

Wave 7's file measured its roots under a `WAVE6_CLOSURES` glob and named its
tests "wave-6"; the roots are keyed "wave-7" here, matching the file they
came from.
"""

import from pathlib { Path }
import from jaclang.testing.test { parametrize }
import from jaclang.dist.precompile_bytecode {
    NATIVE_SEAL_CLOSURE,
    NATIVE_SEAL_ROOTS,
    seal_waiver_names
}
import from tests.compiler.backends.native.seal_support {
    PKG_PATH,
    _root_coverage,
    _seams_by_key
}

glob WAVE_CLOSURES: dict = {
         "wave-1": {
             "compiler/backends/py/module_codegen_pass.jac": (
                 "compiler/backends/py/module_codegen_pass.jac",
                 "compiler/frontend/codeinfo.jac",
                 "compiler/frontend/constant.jac",
                 "compiler/frontend/diagnostic_utils.jac",
                 "compiler/frontend/diagnostics.jac",
                 "compiler/frontend/helpers.jac",
                 "compiler/frontend/srcloc.jac",
                 "compiler/frontend/unitree.jac",
                 "compiler/passes/pass_rim.jac",
                 "compiler/passes/pass_serve.jac",
                 "compiler/passes/transform.jac",
                 "compiler/passes/uni_pass.jac",
                 "compiler/type_registry.jac",
                 "compiler/types/type_utils.jac",
                 "compiler/types/types.jac",
                 "runtime/na_stdlib/_hashlib_native.jac",
                 "runtime/na_stdlib/contextvars.jac",
                 "runtime/na_stdlib/fnmatch.jac",
                 "runtime/na_stdlib/hashlib.jac",
                 "runtime/na_stdlib/logging.jac",
                 "runtime/na_stdlib/pathlib.jac",
                 "runtime/scalars.jac"
             ),
             "compiler/passes/uni_pass.jac": (
                 "compiler/backends/py/module_codegen_pass.jac",
                 "compiler/frontend/codeinfo.jac",
                 "compiler/frontend/constant.jac",
                 "compiler/frontend/diagnostic_utils.jac",
                 "compiler/frontend/diagnostics.jac",
                 "compiler/frontend/helpers.jac",
                 "compiler/frontend/srcloc.jac",
                 "compiler/frontend/unitree.jac",
                 "compiler/passes/pass_rim.jac",
                 "compiler/passes/pass_serve.jac",
                 "compiler/passes/transform.jac",
                 "compiler/passes/uni_pass.jac",
                 "compiler/type_registry.jac",
                 "compiler/types/type_utils.jac",
                 "compiler/types/types.jac",
                 "runtime/na_stdlib/_hashlib_native.jac",
                 "runtime/na_stdlib/contextvars.jac",
                 "runtime/na_stdlib/fnmatch.jac",
                 "runtime/na_stdlib/hashlib.jac",
                 "runtime/na_stdlib/logging.jac",
                 "runtime/na_stdlib/pathlib.jac",
                 "runtime/scalars.jac"
             ),
             "compiler/passes/endpoint_effect_pass.jac": (
                 "compiler/backends/py/module_codegen_pass.jac",
                 "compiler/frontend/codeinfo.jac",
                 "compiler/frontend/constant.jac",
                 "compiler/frontend/diagnostic_utils.jac",
                 "compiler/frontend/diagnostics.jac",
                 "compiler/frontend/helpers.jac",
                 "compiler/frontend/srcloc.jac",
                 "compiler/frontend/unitree.jac",
                 "compiler/passes/endpoint_effect_pass.jac",
                 "compiler/passes/pass_rim.jac",
                 "compiler/passes/pass_serve.jac",
                 "compiler/passes/transform.jac",
                 "compiler/passes/uni_pass.jac",
                 "compiler/type_registry.jac",
                 "compiler/types/type_utils.jac",
                 "compiler/types/types.jac",
                 "runtime/na_stdlib/_hashlib_native.jac",
                 "runtime/na_stdlib/contextvars.jac",
                 "runtime/na_stdlib/fnmatch.jac",
                 "runtime/na_stdlib/hashlib.jac",
                 "runtime/na_stdlib/logging.jac",
                 "runtime/na_stdlib/pathlib.jac",
                 "runtime/scalars.jac"
             )
         },
         "wave-2": {
             "compiler/passes/ast_validation_pass.jac": (
                 "compiler/backends/py/module_codegen_pass.jac",
                 "compiler/frontend/codeinfo.jac",
                 "compiler/frontend/constant.jac",
                 "compiler/frontend/diagnostic_utils.jac",
                 "compiler/frontend/diagnostics.jac",
                 "compiler/frontend/helpers.jac",
                 "compiler/frontend/srcloc.jac",
                 "compiler/frontend/unitree.jac",
                 "compiler/passes/ast_validation_pass.jac",
                 "compiler/passes/pass_rim.jac",
                 "compiler/passes/pass_serve.jac",
                 "compiler/passes/transform.jac",
                 "compiler/passes/uni_pass.jac",
                 "compiler/type_registry.jac",
                 "compiler/types/type_utils.jac",
                 "compiler/types/types.jac",
                 "runtime/na_stdlib/_hashlib_native.jac",
                 "runtime/na_stdlib/contextvars.jac",
                 "runtime/na_stdlib/fnmatch.jac",
                 "runtime/na_stdlib/hashlib.jac",
                 "runtime/na_stdlib/keyword.jac",
                 "runtime/na_stdlib/logging.jac",
                 "runtime/na_stdlib/pathlib.jac",
                 "runtime/scalars.jac"
             ),
             "compiler/passes/semantic_analysis_pass.jac": (
                 "compiler/backends/py/module_codegen_pass.jac",
                 "compiler/frontend/codeinfo.jac",
                 "compiler/frontend/constant.jac",
                 "compiler/frontend/diagnostic_utils.jac",
                 "compiler/frontend/diagnostics.jac",
                 "compiler/frontend/helpers.jac",
                 "compiler/frontend/srcloc.jac",
                 "compiler/frontend/unitree.jac",
                 "compiler/passes/pass_rim.jac",
                 "compiler/passes/pass_serve.jac",
                 "compiler/passes/semantic_analysis_pass.jac",
                 "compiler/passes/transform.jac",
                 "compiler/passes/uni_pass.jac",
                 "compiler/type_registry.jac",
                 "compiler/types/type_utils.jac",
                 "compiler/types/types.jac",
                 "runtime/na_stdlib/_hashlib_native.jac",
                 "runtime/na_stdlib/contextvars.jac",
                 "runtime/na_stdlib/fnmatch.jac",
                 "runtime/na_stdlib/hashlib.jac",
                 "runtime/na_stdlib/logging.jac",
                 "runtime/na_stdlib/pathlib.jac",
                 "runtime/scalars.jac"
             ),
             "compiler/passes/sem_def_match_pass.jac": (
                 "compiler/backends/py/module_codegen_pass.jac",
                 "compiler/frontend/codeinfo.jac",
                 "compiler/frontend/constant.jac",
                 "compiler/frontend/diagnostic_utils.jac",
                 "compiler/frontend/diagnostics.jac",
                 "compiler/frontend/helpers.jac",
                 "compiler/frontend/srcloc.jac",
                 "compiler/frontend/unitree.jac",
                 "compiler/passes/pass_rim.jac",
                 "compiler/passes/pass_serve.jac",
                 "compiler/passes/sem_def_match_pass.jac",
                 "compiler/passes/transform.jac",
                 "compiler/passes/uni_pass.jac",
                 "compiler/type_registry.jac",
                 "compiler/types/type_utils.jac",
                 "compiler/types/types.jac",
                 "runtime/na_stdlib/_hashlib_native.jac",
                 "runtime/na_stdlib/contextvars.jac",
                 "runtime/na_stdlib/fnmatch.jac",
                 "runtime/na_stdlib/hashlib.jac",
                 "runtime/na_stdlib/logging.jac",
                 "runtime/na_stdlib/pathlib.jac",
                 "runtime/scalars.jac"
             )
         },
         "wave-3": {
             "compiler/passes/rc_facts_pass.jac": (
                 "compiler/backends/py/module_codegen_pass.jac",
                 "compiler/expr_keys.jac",
                 "compiler/frontend/codeinfo.jac",
                 "compiler/frontend/constant.jac",
                 "compiler/frontend/diagnostic_utils.jac",
                 "compiler/frontend/diagnostics.jac",
                 "compiler/frontend/helpers.jac",
                 "compiler/frontend/srcloc.jac",
                 "compiler/frontend/unitree.jac",
                 "compiler/passes/dataflow.jac",
                 "compiler/passes/pass_rim.jac",
                 "compiler/passes/pass_serve.jac",
                 "compiler/passes/rc_facts_pass.jac",
                 "compiler/passes/transform.jac",
                 "compiler/passes/uni_pass.jac",
                 "compiler/type_registry.jac",
                 "compiler/types/type_utils.jac",
                 "compiler/types/types.jac",
                 "runtime/na_stdlib/_hashlib_native.jac",
                 "runtime/na_stdlib/contextvars.jac",
                 "runtime/na_stdlib/fnmatch.jac",
                 "runtime/na_stdlib/hashlib.jac",
                 "runtime/na_stdlib/logging.jac",
                 "runtime/na_stdlib/pathlib.jac",
                 "runtime/scalars.jac"
             )
         },
         "wave-4": {
             "compiler/passes/sym_tab_build_pass.jac": (
                 "compiler/backends/py/module_codegen_pass.jac",
                 "compiler/frontend/codeinfo.jac",
                 "compiler/frontend/constant.jac",
                 "compiler/frontend/diagnostic_utils.jac",
                 "compiler/frontend/diagnostics.jac",
                 "compiler/frontend/helpers.jac",
                 "compiler/frontend/srcloc.jac",
                 "compiler/frontend/unitree.jac",
                 "compiler/passes/pass_rim.jac",
                 "compiler/passes/pass_serve.jac",
                 "compiler/passes/sym_tab_build_pass.jac",
                 "compiler/passes/transform.jac",
                 "compiler/passes/uni_pass.jac",
                 "compiler/type_registry.jac",
                 "compiler/types/type_utils.jac",
                 "compiler/types/types.jac",
                 "runtime/na_stdlib/_hashlib_native.jac",
                 "runtime/na_stdlib/contextvars.jac",
                 "runtime/na_stdlib/fnmatch.jac",
                 "runtime/na_stdlib/hashlib.jac",
                 "runtime/na_stdlib/logging.jac",
                 "runtime/na_stdlib/pathlib.jac",
                 "runtime/scalars.jac"
             ),
             "compiler/passes/decl_impl_match_pass.jac": (
                 "compiler/backends/py/module_codegen_pass.jac",
                 "compiler/frontend/codeinfo.jac",
                 "compiler/frontend/constant.jac",
                 "compiler/frontend/diagnostic_utils.jac",
                 "compiler/frontend/diagnostics.jac",
                 "compiler/frontend/helpers.jac",
                 "compiler/frontend/srcloc.jac",
                 "compiler/frontend/unitree.jac",
                 "compiler/passes/decl_impl_match_pass.jac",
                 "compiler/passes/pass_rim.jac",
                 "compiler/passes/pass_serve.jac",
                 "compiler/passes/transform.jac",
                 "compiler/passes/uni_pass.jac",
                 "compiler/type_registry.jac",
                 "compiler/types/type_utils.jac",
                 "compiler/types/types.jac",
                 "runtime/na_stdlib/_hashlib_native.jac",
                 "runtime/na_stdlib/contextvars.jac",
                 "runtime/na_stdlib/fnmatch.jac",
                 "runtime/na_stdlib/hashlib.jac",
                 "runtime/na_stdlib/logging.jac",
                 "runtime/na_stdlib/pathlib.jac",
                 "runtime/scalars.jac"
             )
         },
         "wave-5": {
             "compiler/passes/jsx_intrinsic_guard_pass.jac": (
                 "client/targets/react_native/html_tag_map.jac",
                 "compiler/backends/py/module_codegen_pass.jac",
                 "compiler/frontend/codeinfo.jac",
                 "compiler/frontend/constant.jac",
                 "compiler/frontend/diagnostic_utils.jac",
                 "compiler/frontend/diagnostics.jac",
                 "compiler/frontend/helpers.jac",
                 "compiler/frontend/srcloc.jac",
                 "compiler/frontend/unitree.jac",
                 "compiler/passes/jsx_intrinsic_guard_pass.jac",
                 "compiler/passes/pass_rim.jac",
                 "compiler/passes/pass_serve.jac",
                 "compiler/passes/transform.jac",
                 "compiler/passes/uni_pass.jac",
                 "compiler/type_registry.jac",
                 "compiler/types/type_utils.jac",
                 "compiler/types/types.jac",
                 "project/client_kind_paths.jac",
                 "runtime/na_stdlib/_hashlib_native.jac",
                 "runtime/na_stdlib/contextvars.jac",
                 "runtime/na_stdlib/fnmatch.jac",
                 "runtime/na_stdlib/hashlib.jac",
                 "runtime/na_stdlib/logging.jac",
                 "runtime/na_stdlib/pathlib.jac",
                 "runtime/scalars.jac"
             ),
             "compiler/passes/access_check_pass.jac": (
                 "compiler/backends/py/module_codegen_pass.jac",
                 "compiler/frontend/codeinfo.jac",
                 "compiler/frontend/constant.jac",
                 "compiler/frontend/diagnostic_utils.jac",
                 "compiler/frontend/diagnostics.jac",
                 "compiler/frontend/helpers.jac",
                 "compiler/frontend/srcloc.jac",
                 "compiler/frontend/unitree.jac",
                 "compiler/passes/access_check_pass.jac",
                 "compiler/passes/pass_rim.jac",
                 "compiler/passes/pass_serve.jac",
                 "compiler/passes/transform.jac",
                 "compiler/passes/uni_pass.jac",
                 "compiler/type_registry.jac",
                 "compiler/types/type_utils.jac",
                 "compiler/types/types.jac",
                 "runtime/na_stdlib/_hashlib_native.jac",
                 "runtime/na_stdlib/contextvars.jac",
                 "runtime/na_stdlib/fnmatch.jac",
                 "runtime/na_stdlib/hashlib.jac",
                 "runtime/na_stdlib/logging.jac",
                 "runtime/na_stdlib/pathlib.jac",
                 "runtime/scalars.jac"
             )
         },
         "wave-7": {
             "compiler/passes/cfg_build_pass.jac": (
                 "compiler/backends/py/module_codegen_pass.jac",
                 "compiler/expr_keys.jac",
                 "compiler/frontend/codeinfo.jac",
                 "compiler/frontend/constant.jac",
                 "compiler/frontend/diagnostic_utils.jac",
                 "compiler/frontend/diagnostics.jac",
                 "compiler/frontend/helpers.jac",
                 "compiler/frontend/srcloc.jac",
                 "compiler/frontend/unitree.jac",
                 "compiler/passes/cfg_build_pass.jac",
                 "compiler/passes/pass_rim.jac",
                 "compiler/passes/pass_serve.jac",
                 "compiler/passes/transform.jac",
                 "compiler/passes/uni_pass.jac",
                 "compiler/type_registry.jac",
                 "compiler/types/type_utils.jac",
                 "compiler/types/types.jac",
                 "runtime/na_stdlib/_hashlib_native.jac",
                 "runtime/na_stdlib/contextvars.jac",
                 "runtime/na_stdlib/fnmatch.jac",
                 "runtime/na_stdlib/hashlib.jac",
                 "runtime/na_stdlib/logging.jac",
                 "runtime/na_stdlib/pathlib.jac",
                 "runtime/scalars.jac"
             )
         }
     },
     REFUSED_OWN_SEAMS: dict = {
         "compiler/passes/static_analysis_pass.jac": 6,
         "compiler/passes/ownership_check_pass.jac": 13
     };

"""Every (wave, root) pair in WAVE_CLOSURES, sorted for a stable test order."""
def _root_rows -> list {
    rows: list = [];
    for wave in sorted(WAVE_CLOSURES.keys()) {
        for rel in sorted(WAVE_CLOSURES[wave].keys()) {
            rows.append((wave, rel, ));
        }
    }
    return rows;
}

def _row_id(row: tuple) -> str {
    (wave, rel) = row;
    return f"{wave}:{rel[:-4].replace('/', '.')}";
}

def _registered_test(row: tuple) {
    (wave, rel) = row;
    assert rel in NATIVE_SEAL_ROOTS , (
        f"{rel} is not in NATIVE_SEAL_ROOTS; this coverage would gate nothing "
        "at seal time"
    );
    for member in WAVE_CLOSURES[wave][rel] {
        assert member in NATIVE_SEAL_CLOSURE , (
            f"{rel} pulls {member} into its native unit but "
            "NATIVE_SEAL_CLOSURE does not account for it"
        );
    }
}

def _closure_exact_test(row: tuple) {
    (wave, rel) = row;
    (coverage, _has_ir, errors) = _root_coverage(rel);
    assert not errors , (
        f"{rel} compile errors (closure below is 'not reached', not 'clean'): "
        f"{errors[:5]}"
    );
    seen = tuple(
        sorted(
            Path(p).resolve().relative_to(PKG_PATH.resolve()).as_posix()
            for p in coverage
        )
    );
    assert seen == WAVE_CLOSURES[wave][rel] , (
        f"{rel}: native closure changed: {seen} != {WAVE_CLOSURES[wave][rel]}. "
        "A new member has to reach zero un-waived seams before this root can "
        "keep sealing."
    );
}

def _has_ir_test(row: tuple) {
    (_wave, rel) = row;
    (_coverage, has_ir, _errors) = _root_coverage(rel);
    assert has_ir , (
        f"no LLVM IR for {rel} -- the compile aborted before codegen, so a "
        "zero-seam coverage would mean 'not reached', not 'clean'"
    );
}

def _no_unwaived_seam_test(row: tuple) {
    (_wave, rel) = row;
    seams = _seams_by_key(rel);
    (allowed, _bare) = seal_waiver_names(rel);
    unexpected = sorted(
        k
        for k in seams
        if k not in allowed
    );
    assert not unexpected , (
        f"{len(unexpected)} un-waived seam(s) in {rel}'s sealed closure:\n"
        + "\n".join(f"  {k}: {seams[k]}" for k in unexpected)
    );
}

def _no_stale_waiver_test(row: tuple) {
    (_wave, rel) = row;
    seams = _seams_by_key(rel);
    (allowed, _bare) = seal_waiver_names(rel);
    stale = sorted(
        k
        for k in allowed
        if k not in seams
    );
    assert not stale , (
        f"{rel} waives seams that no longer demote -- drop them:\n"
        + "\n".join(f"  {k}" for k in stale)
    );
}

with entry {
    parametrize(
        "seal root is registered", _root_rows(), _registered_test, id_fn=_row_id
    );
    parametrize(
        "seal root closure is exact", _root_rows(), _closure_exact_test, id_fn=_row_id
    );
    parametrize("seal root produces IR", _root_rows(), _has_ir_test, id_fn=_row_id);
    parametrize(
        "seal root has no un-waived seam",
        _root_rows(),
        _no_unwaived_seam_test,
        id_fn=_row_id
    );
    parametrize(
        "seal root has no stale waiver",
        _root_rows(),
        _no_stale_waiver_test,
        id_fn=_row_id
    );
}

test "each refused analysis root still measures its recorded seam count" {
    for (rel, expected) in sorted(REFUSED_OWN_SEAMS.items()) {
        assert rel not in NATIVE_SEAL_ROOTS , (
            f"{rel} is sealed now -- move it out of REFUSED_OWN_SEAMS and "
            "give it a closure and a waiver set above"
        );
        seams = _seams_by_key(rel);
        mine = sorted(
            k
            for k in seams
            if k.startswith(rel + "::")
        );
        assert len(mine) == expected , (
            f"{rel}: {len(mine)} own seams, recorded {expected}. If this "
            "dropped, collect the progress and lower the number; if it "
            "rose, the new seams are:\n"
            + "\n".join(f"  {k}: {seams[k]}" for k in mine)
        );
    }
}

test "the rc-facts solver keeps its stamps off the codegen target" {
    # `codeinfo.jac` is in no pass's native closure, so a `Module.gen`
    # field store is a store into a module this artifact cannot host --
    # it demoted `_stamp_last_use`, `_stamp_move_in` and
    # `_stamp_anon_regions` for exactly that reason. The facts live in
    # `Module` slots now; a re-introduced `.gen.` stamp would demote the
    # stamping method again.
    src = (PKG_PATH / "compiler/passes/rc_facts_pass.jac").read_text(encoding='utf-8');
    src += (PKG_PATH / "compiler/passes/impl/rc_facts_pass.impl.jac").read_text(
        encoding='utf-8'
    );
    for token in (
        "gen.anon_region_close",
        "gen.anon_region_locals",
        "gen.anon_region_open",
        "gen.rc_last_use",
        "gen.rc_move_in",
        "symbol_utils"
    ) {
        assert token not in src , (
            f"rc_facts_pass reaches '{token}' again; that is the coupling "
            "this wave removed, and it demotes the reading method out of the "
            "sealed artifact"
        );
    }
}

test "neither wave-5 root reaches its driver's facts on its own" {
    # The seal is only honest if the passes read the stamped slots
    # instead of recomputing them: a re-introduced `get_config`,
    # `find_jac_project_root` or `resolve_client_kind_context` call
    # would demote the reading method again, and a `**kwargs` forward
    # into `emit` would demote every emit site.
    for (rel, banned) in (
        (
            "compiler/passes/jsx_intrinsic_guard_pass.jac",
            ("resolve_client_kind_context", "self.prog")
        ),
        (
            "compiler/passes/access_check_pass.jac",
            ("get_config", "find_jac_project_root", "**kwargs")
        )
    ) {
        src = (PKG_PATH / rel).read_text(encoding='utf-8');
        annex = PKG_PATH
            / rel.replace("/main/", "/main/impl/").replace(".jac", ".impl.jac");
        if annex.exists() {
            src += annex.read_text(encoding='utf-8');
        }
        for token in banned {
            assert token not in src , (
                f"{rel} reads '{token}' again; that is the driver coupling "
                "this wave removed, and it demotes the reading method out "
                "of the sealed artifact"
            );
        }
    }
}

test "the cfg narrowing keys come from the native-clean hoist" {
    src = (PKG_PATH / "compiler/passes/impl/cfg_build_pass.impl.jac").read_text();
    assert "jaclang.compiler.expr_keys" in src , (
        "cfg_build must read its narrowing/assigned key helpers from "
        "compiler/expr_keys.jac; that hoist is what keeps symbol_utils and "
        "the type evaluator out of this closure"
    );
    assert "symbol_utils" not in src , (
        "a symbol_utils import in cfg_build re-couples the pass to the "
        "analysis cluster and this closure stops being sealable"
    );
}
