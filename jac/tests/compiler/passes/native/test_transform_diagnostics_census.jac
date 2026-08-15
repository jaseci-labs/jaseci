"""Diagnostics census: the Transform unit owns no emission seam.

`Transform.emit` used to append every alert to `prog.errors_had` through the
`JacProgram` Python handle, and `Transform._is_suppressed` re-read project
config on each emission. Both are reachable on every diagnostic any pass
raises, so as native seams they were unwaivable: a sealed pass would abort on
its first emit. The redesign makes emission pure data accumulation -- alerts
land on the pass-local `errors_had` / `warnings_had` lists, suppression is a
lookup against the pre-resolved `DiagnosticPolicy` data object, and the
Python driver (`run_pass`) delivers to the program ledger after the pass body
finishes.

This census compiles `transform.jac` natively, the same measurement
`test_pass_driver_seam_census.jac` takes for the pass units, and pins that
the emission path stays seam-free: none of its callables demote, and none of
the module's residual native errors touch them. Callables off the emission
path that reach real Python machinery (console rendering, the cancel-token
handle, `RuntimeError` construction in `ice`, and the constructor's generic
load plus `super` dispatch) remain legal per-callable seams and are waived
one at a time. What is left module-fatal is the foreign class-typed field on
the pass declaration, pinned here so the sealing lane sees exactly what
remains.

The measurement is a source-lane one. Under a sealed jaclang image every
method of an imported jaclang-internal archetype is untrusted by design, so
the census would read the image's trust boundary rather than the emission
path's own coupling; `_census` skips there.
"""

import os;
import pytest;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_census_begin, na_census_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { _jaclang_image, native_artifact_for }

glob TRANSFORM_JAC = str(
         Path(jaclang.__file__).parent / "jac0core" / "passes" / "transform.jac"
     );

"""The emission path: every callable a single `self.emit(...)` can reach.

A seam on any of these is reachable on every diagnostic of every pass, so it
can never be waived.
"""
glob EMISSION_PATH: tuple = (
         "Transform.emit",
         "Transform._is_suppressed",
         "DiagnosticPolicy.is_suppressed",
         "DiagnosticPolicy._inline_suppressed",
         "Alert.postinit"
     );

"""Waived per-callable seams: real Python machinery off the emission path."""
glob TRANSFORM_SEAM_WAIVERS: dict[(str, str)] = {
         "Alert.as_log": (
             "console rendering: ANSI color attribute access; presentation "
             "stays Python-side and only Python drivers call it."
         ),
         "Alert.pretty_print": (
             "console rendering: builds on `as_log` and the ANSI palette; "
             "presentation stays Python-side."
         ),
         "BaseTransform.is_canceled": (
             "backend gap: dynamic `is_set()` on the threading.Event handle "
             "in `cancel_token`."
         ),
         "Transform.ice": (
             "backend gap: constructs the `RuntimeError` it returns for the "
             "caller to raise."
         ),
         "Transform.__post_init__": (
             "backend gap in the constructor: postinit's generic field load "
             "and its `super` dispatch. Runs once per pass construction, "
             "which the Python driver performs anyway, so it is off the "
             "emission path. #8244 gave the constructor its own violations, "
             "so these demote the callable instead of the module."
         )
     };

"""Module-fatal backend gaps (not demotable, not emission): the foreign
`JacProgram`-typed field on the pass declaration. Keyed by the construct the
diagnostic names."""
glob KNOWN_CONSTRUCTOR_GAPS: tuple = ("'JacProgram'", );

glob _CENSUS_MEMO: list = [];

def _census -> tuple {
    if _jaclang_image() is not None {
        pytest.skip(
            "this runtime is a sealed jaclang image, so na_ir_gen_pass "
            "untrusts every method of an imported jaclang-internal archetype "
            "that the image's layout does not carry; a source census here "
            "measures that trust boundary instead of the emission path's own "
            "coupling, which is what this file pins"
        );
    }
    if native_artifact_for("jaclang.jac0core.passes.transform") is not None {
        pytest.skip(
            "transform.jac is served from this runtime's native seal; the "
            "census gated the build via seal_demotion_report"
        );
    }
    if _CENSUS_MEMO {
        return _CENSUS_MEMO[0];
    }
    prog = JacProgram();
    na_census_begin();
    try {
        ir = prog.compile(
            file_path=TRANSFORM_JAC,
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
    result = (census, ir, prog, );
    _CENSUS_MEMO.append(result);
    return result;
}

"""Seams the census recorded inside transform.jac itself, keyed by callable."""
def _own_seams -> dict[(str, str)] {
    (census, _ir, _prog) = _census();
    rec = census.get(os.path.realpath(TRANSFORM_JAC));
    assert rec is not None , (
        "transform.jac never entered the native census -- the measurement " "is vacuous"
    );
    assert rec["outcome"] == "native" , (
        f"transform.jac did not stay native ({rec['outcome']}: "
        f"{rec['detail']}); per-seam data below would be incomplete"
    );
    found: dict[(str, str)] = {};
    for seam in (rec["seams"] or []) {
        (name, sep, why) = str(seam).partition(": ");
        found[name if sep else str(seam)] = why if sep else "";
    }
    return found;
}

"""The unit's own native errors, as message strings."""
def _own_errors -> list[str] {
    (_census_map, _ir, prog) = _census();
    return [
        str(e)
        for e in prog.errors_had
        if "transform" in os.path.normpath(e.loc.mod_path)
    ];
}


test "the emission path owns no seam" {
    seams = _own_seams();
    offenders = sorted(
        f"{name}: {why}"
        for (name, why) in seams.items()
        if name in EMISSION_PATH
    );
    assert not offenders , (
        f"{len(offenders)} seam(s) on the always-reachable emission path -- "
        "emit must stay pure data accumulation, with delivery and config "
        "reads owned by the Python driver:\n"
        + "\n".join(f"  {s}" for s in offenders)
    );
}


test "no native error touches the emission path" {
    touched = [
        e
        for e in _own_errors()
        if any(
            marker in e
            for marker in (
                "'emit'",
                "'_is_suppressed'",
                "'is_suppressed'",
                "'_inline_suppressed'",
                "'prog.errors_had'",
                "'errors_had'"
            )
        )
    ];
    assert not touched , (
        "native errors name the emission path -- it regressed from pure "
        "data accumulation:\n"
        + "\n".join(f"  {e}" for e in touched)
    );
}


test "remaining seams are exactly the waived off-path callables" {
    seams = _own_seams();
    unexpected = sorted(
        k
        for k in seams
        if k not in TRANSFORM_SEAM_WAIVERS
    );
    assert not unexpected , (
        f"{len(unexpected)} un-waived seam(s) in the transform unit:\n"
        + "\n".join(f"  {k}: {seams[k]}" for k in unexpected)
    );
    stale = sorted(
        k
        for k in TRANSFORM_SEAM_WAIVERS
        if k not in seams
    );
    assert not stale , (
        "waived transform seams that no longer demote -- drop them:\n"
        + "\n".join(f"  {k}: {TRANSFORM_SEAM_WAIVERS[k]}" for k in stale)
    );
}


test "residual native errors are exactly the known constructor gaps" {
    errs = _own_errors();
    unexpected = [
        e
        for e in errs
        if not any(marker in e for marker in KNOWN_CONSTRUCTOR_GAPS)
    ];
    assert not unexpected , (
        f"{len(unexpected)} native error(s) beyond the known constructor " "gaps:\n"
        + "\n".join(f"  {e}" for e in unexpected)
    );
    assert len(errs) == len(KNOWN_CONSTRUCTOR_GAPS) , (
        f"constructor-gap inventory drifted (expected "
        f"{len(KNOWN_CONSTRUCTOR_GAPS)}, got {len(errs)}) -- update "
        "KNOWN_CONSTRUCTOR_GAPS so the sealing lane sees what is left:\n"
        + "\n".join(f"  {e}" for e in errs)
    );
}
