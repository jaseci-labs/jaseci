"""Native seal census for the fused unit (#8707).

The per-wave baselines used to pin one closure table per sealed root;
under the fused seal there is one native unit, so there is one census:

  1. **Closure membership is exact.** The fused unit's measured closure
     must equal `NATIVE_SEAL_CLOSURE` (minus the generated materializer,
     which exists only inside a seal run -- the census compiles the
     source-lane stand-in root from `seal_support`). A new member means a
     module-level import changed and has to reach zero un-waived seams
     before the seal can keep building; `NATIVE_SEAL_CLOSURE` is the pin
     that makes that a reviewed change instead of a drive-by.
  2. **The unit produces native IR.** A zero-seam census without IR means
     "not reached", not "clean".

The two-way seam-vs-waiver check for the fused unit lives in
`test_sealed_demotion_audit.jac`; reachability of every waived name lives
in `test_sealed_seam_reachability.jac`. The wave-specific source-coupling
invariants that outlive the wave tables follow below unchanged: they pin
refactors (driver-stamped facts, the expr_keys hoist, the rc-facts slot
moves) whose regression would re-demote methods out of the sealed unit.
"""

import from pathlib { Path }
import from jaclang.dist.precompile_bytecode {
    NATIVE_SEAL_CLOSURE,
    NATIVE_SEAL_MATERIALIZE_ROOT,
    NATIVE_SEAL_SERVED_MODULES
}
import from tests.compiler.backends.native.seal_support {
    AUDIT_ROOT_REL,
    PKG_PATH,
    _root_coverage,
    write_audit_seal_root
}

glob REFUSED_OWN_SEAMS: dict = {
         "compiler/passes/static_analysis_pass.jac": 6,
         "compiler/passes/ownership_check_pass.jac": 14
     };

"""Measure the fused stand-in root's coverage; (coverage, has_ir, errors)."""
def _fused_coverage -> tuple {
    write_audit_seal_root();
    try {
        return _root_coverage(AUDIT_ROOT_REL);
    } finally {
        (PKG_PATH / AUDIT_ROOT_REL).unlink(missing_ok=True);
    }
}


test "every served module is accounted in the fused closure pin" {
    for rel in NATIVE_SEAL_SERVED_MODULES {
        if rel == NATIVE_SEAL_MATERIALIZE_ROOT {
            continue;
        }
        assert rel in NATIVE_SEAL_CLOSURE , (
            f"the fused root serves {rel} but NATIVE_SEAL_CLOSURE does not "
            "account for it"
        );
    }
}


test "the fused closure census is exact" {
    (coverage, _has_ir, errors) = _fused_coverage();
    assert not errors , (
        "fused stand-in compile errors (closure below is 'not reached', "
        f"not 'clean'): {errors[:5]}"
    );
    seen = sorted(
        rel
        for rel in (
            Path(p).resolve().relative_to(PKG_PATH.resolve()).as_posix()
            for p in coverage
        )
        if rel != AUDIT_ROOT_REL
    );
    expected = sorted(
        rel
        for rel in NATIVE_SEAL_CLOSURE
        if rel != NATIVE_SEAL_MATERIALIZE_ROOT
    );
    assert seen == expected , (
        "the fused native closure changed:\n"
        f"  gained: {sorted(set(seen) - set(expected))}\n"
        f"  lost:   {sorted(set(expected) - set(seen))}\n"
        "A new member has to reach zero un-waived seams before the seal can "
        "keep building; update NATIVE_SEAL_CLOSURE in the same change."
    );
}


test "the fused unit produces IR" {
    (_coverage, has_ir, _errors) = _fused_coverage();
    assert has_ir , (
        "no LLVM IR for the fused stand-in -- the compile aborted before "
        "codegen, so a zero-seam coverage would mean 'not reached', not "
        "'clean'"
    );
}


test "each refused analysis pass still measures its recorded seam count" {
    import from tests.compiler.backends.native.seal_support { _seams_by_key }
    for (rel, expected) in sorted(REFUSED_OWN_SEAMS.items()) {
        assert rel not in NATIVE_SEAL_SERVED_MODULES , (
            f"{rel} is served now -- move it out of REFUSED_OWN_SEAMS and "
            "account for its waivers in the fused table"
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
    # `codeinfo.jac`'s `Module.gen` is the host-side codegen target; a
    # `.gen.` field store from the solver demoted `_stamp_last_use`,
    # `_stamp_move_in` and `_stamp_anon_regions` out of the sealed unit.
    # The facts live in `Module` slots now; a re-introduced `.gen.` stamp
    # would demote the stamping method again.
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


test "neither wave-5 pass reaches its driver's facts on its own" {
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
