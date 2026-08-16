"""Sealing wave 2: three more compiler passes join the native seal.

Same discipline as `test_pass_seal_wave1_census.jac`: each root is
measured exactly the way `seal_native_artifacts` measures it, and three
things are pinned per root -- exact closure membership, native IR
production, and the seam set two-way against
`NATIVE_SEAL_DEMOTION_WAIVERS`.

The wave-2 roots and what cleared them:

  - `sem_def_match_pass` was wave 1's stop-the-line refusal: its live
    `connect_sems` dispatches `Token.lit_value` through the vtable, and
    the `String`/`MultiString` decoders were eval-bound stubs. #8251 made
    jac decode its own string literals, the decoders lower, and the
    refusal pin in `test_sealed_seam_reachability.jac` fired exactly as
    designed. Zero own seams.
  - `ast_validation_pass` reached zero own seams through typed
    accumulators and type-driven rewrites (`_scope_declares_state` and
    `_returns_jsx` take the `(Ability | ImplDef)` the caller guarantees
    instead of probing dynamic attributes; the jsx-slot helpers take
    `list[UniNode]`).
  - `semantic_analysis_pass`: the inherited forwarding static gave way to
    the direct `UniNode.get_all_sub_nodes` call, and typed accumulators
    cleared the rest. One waiver remains.

The one remaining waiver: `Transform.ice` raises through Python
diagnostics machinery, and `SemanticAnalysisPass.enter_has_var` (its one
caller here) is a visitor method the Python traversal dispatches into,
never called natively inside the artifact; the layout registration routes
its Python callers to bytecode. It clears when `ice` construction lowers
or when the internal-error guard moves behind the emit-as-data path.

Measured and REFUSED this wave, honestly:

  - `boundary_analysis_pass`: ~23 own seams that are driver coupling, not
    backend gaps -- it constructs `JacCompiler`, reads files
    (`read_file_with_encoding`, jacignore), resolves native modules, and
    reads `prog` state, all reachable from `enter_import` on any
    import-bearing input. It needs the #8242-style redesign (the driver
    hands data) before it can seal; waivers cannot launder driver seams.
  - `sym_tab_build_pass`: its census is one waiver-class seam after
    #8241/#8253 cleared the hoist-era union gaps and two checker
    escalations got honest narrows, but the reachability walk caught a
    real abort path: live `exit_module_path` reads `Import.is_jac`,
    whose implementation chains into `__jac_detected` and
    `ModulePath.resolve_relative_path`, the waived filesystem
    import-resolution family. Sealed, that aborts on the first plain
    import. It seals when import detection becomes driver-stamped data
    on the Import node (the #8242 `absorbed_mod` pattern); the
    self-clearing pin lives in `test_sealed_seam_reachability.jac`.
  - `decl_impl_match_pass`: its `transform` chain reaches `id()`-keyed
    dedup (`_report_bare_redecls`), the Python-side `ext_registry` annex
    predicate, and untyped `name_of` link walks -- all natively reachable
    from `transform`, so not waiver-eligible. Three small preps clear it:
    identity-free E2026 dedup, a native-clean annex-suffix predicate (the
    `annex_weave` pattern), and typed link accumulators.

The measurement is a source-lane one: under a sealed jaclang image the
census reads the image's trust boundary instead of each unit's own
coupling, so `_root_census` skips there (both gates below).
"""

import os;
import pytest;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_census_begin, na_census_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { _jaclang_image, native_artifact_for }
import from jaclang.utils.precompile_bytecode {
    NATIVE_SEAL_CLOSURE,
    NATIVE_SEAL_ROOTS,
    seal_waiver_names
}

glob PKG_PATH = Path(jaclang.__file__).parent,
     WAVE2_ROOTS: tuple = (
         "jac0core/passes/ast_validation_pass.jac",
         "jac0core/passes/semantic_analysis_pass.jac",
         "compiler/passes/main/sem_def_match_pass.jac"
     );

"""Each root's exact native closure, as package-relative paths."""
glob WAVE2_CLOSURES: dict[(str, tuple)] = {
         "jac0core/passes/ast_validation_pass.jac": (
             "jac0core/constant.jac",
             "jac0core/diagnostics.jac",
             "jac0core/passes/ast_validation_pass.jac",
             "jac0core/srcloc.jac",
             "jac0core/unitree.jac",
             "runtimelib/na_stdlib/keyword.jac"
         ),
         "jac0core/passes/semantic_analysis_pass.jac": (
             "jac0core/constant.jac",
             "jac0core/diagnostics.jac",
             "jac0core/passes/semantic_analysis_pass.jac",
             "jac0core/srcloc.jac",
             "jac0core/unitree.jac"
         ),
         "compiler/passes/main/sem_def_match_pass.jac": (
             "compiler/passes/main/sem_def_match_pass.jac",
             "jac0core/constant.jac",
             "jac0core/srcloc.jac",
             "jac0core/unitree.jac"
         )
     };

glob _CENSUS_MEMO: dict[(str, tuple)] = {};

"""A root's dotted module name, for the sealed-runtime skip gate."""
def _root_module_name(rel: str) -> str {
    return "jaclang." + rel[:-4].replace("/", ".");
}

"""Compile one root the way seal_native_artifacts does, up to the census."""
def _root_census(rel: str) -> tuple {
    if _jaclang_image() is not None {
        pytest.skip(
            "this runtime is a sealed jaclang image; a source census here "
            "measures the image's trust boundary, not the unit's own seams"
        );
    }
    if native_artifact_for(_root_module_name(rel)) is not None {
        pytest.skip(
            f"{rel} is served from this runtime's native seal; the census "
            "gated the build via seal_demotion_report"
        );
    }
    if rel in _CENSUS_MEMO {
        return _CENSUS_MEMO[rel];
    }
    prog = JacProgram();
    na_census_begin();
    try {
        ir = prog.compile(
            file_path=str(PKG_PATH / rel),
            options=CompileOptions(
                aot_mode=True,
                type_check=False,
                force_codespace='native',
                force_target_program=True,
                na_gc_mode='cycles',
                no_ir_cache=True
            )
        );
    } finally {
        census = na_census_end();
    }
    has_ir = ir is not None and ir.gen.llvm_ir is not None;
    errors = [str(e) for e in prog.errors_had];
    result = (census, has_ir, errors, );
    _CENSUS_MEMO[rel] = result;
    return result;
}

"""Census seams as `<pkg-rel module>::<Type>.<method>` -> reason."""
def _seams_by_key(rel: str) -> dict[(str, str)] {
    (census, _has_ir, _errors) = _root_census(rel);
    found: dict[(str, str)] = {};
    for (path, rec) in sorted(census.items()) {
        where = Path(path).resolve().relative_to(PKG_PATH.resolve()).as_posix();
        for seam in (rec["seams"] or []) {
            (name, sep, why) = str(seam).partition(": ");
            found[f"{where}::{name if sep else str(seam)}"] = why if sep else "";
        }
        if rec["outcome"] == "demoted" {
            found[f"{where}::<module>"] = f"[{rec['code']}] {rec['detail']}";
        }
    }
    return found;
}


test "every wave-2 root is registered for the seal" {
    for rel in WAVE2_ROOTS {
        assert rel in NATIVE_SEAL_ROOTS , (
            f"{rel} is not in NATIVE_SEAL_ROOTS; this census would gate "
            "nothing at seal time"
        );
        for member in WAVE2_CLOSURES[rel] {
            assert member in NATIVE_SEAL_CLOSURE , (
                f"{rel} pulls {member} into its native unit but "
                "NATIVE_SEAL_CLOSURE does not account for it"
            );
        }
    }
}


test "each wave-2 root's native closure is exactly the measured set" {
    for rel in WAVE2_ROOTS {
        (census, _has_ir, errors) = _root_census(rel);
        assert not errors , (
            f"{rel} compile errors (closure below is 'not reached', not "
            f"'clean'): {errors[:5]}"
        );
        seen = tuple(
            sorted(
                Path(p).resolve().relative_to(PKG_PATH.resolve()).as_posix()
                for p in census
            )
        );
        assert seen == WAVE2_CLOSURES[rel] , (
            f"{rel}: native closure changed: {seen} != {WAVE2_CLOSURES[rel]}. "
            "A new member has to reach zero un-waived seams before this root "
            "can keep sealing."
        );
    }
}


test "each wave-2 root's closure produces native IR" {
    for rel in WAVE2_ROOTS {
        (_census, has_ir, _errors) = _root_census(rel);
        assert has_ir , (
            f"no LLVM IR for {rel} -- the compile aborted before codegen, so "
            "a zero-seam census would mean 'not reached', not 'clean'"
        );
    }
}


test "no un-waived seam in any wave-2 closure" {
    for rel in WAVE2_ROOTS {
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
}


test "every wave-2 seam waiver still matches a real seam" {
    for rel in WAVE2_ROOTS {
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
}
