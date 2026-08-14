"""Granular native-lowering demotion (epic #8201).

A capability violation used to refuse whole-module native codegen: one
dynamic construct anywhere meant zero per-method seam data, so nothing
in the module could seal. These tests pin the granular contract: a
violation demotes its smallest owning unit. An archetype method, an
event ability, or a free function becomes a seam exactly like a
NaIRGenPass-time demotion -- recorded in the census with a reason that
names the construct, shipped as an abort stub if sealed, waiver-eligible
through `seal_demotion_report` -- while every sibling still lowers.
Module-level constructs with no owning callable (a module-level Python
import feeding a glob initializer) keep the whole-module refusal, and
the diagnostic names the construct.
"""

import os;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_census_begin, na_census_end }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

"""Forced-native options that skip the IR cache so the census always runs."""
def _granular_opts -> CompileOptions {
    return CompileOptions(
        type_check=False,
        force_codespace='native',
        force_target_program=True,
        no_ir_cache=True
    );
}

"""Compile a fixture under the census; return (program, module, census)."""
def _compile_with_census(fixture: str) -> tuple {
    prog = JacProgram();
    na_census_begin();
    try {
        ir = prog.compile(
            file_path=os.path.join(FIXTURES, fixture), options=_granular_opts()
        );
    } finally {
        census = na_census_end();
    }
    return (prog, ir, census);
}

"""The census seam list recorded for a fixture path."""
def _seams_of(census: dict, fixture: str) -> list[str] {
    rec = census.get(os.path.realpath(os.path.join(FIXTURES, fixture)));
    if rec is None {
        return [];
    }
    return [str(s) for s in (rec.get("seams") or [])];
}

test "a method's capability violation demotes only that method" {
    (prog, ir, census) = _compile_with_census("granular_method_seam.jac");
    errors = [str(e) for e in prog.errors_had];
    assert not prog.errors_had , (
        f"a method-owned violation must demote, not fail the module: {errors}"
    );
    assert ir.gen.llvm_ir is not None , (
        "the module must keep its LLVM IR when only one method demotes"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "Calc.good" in layout.methods , (
        f"clean sibling method was lost: {list(layout.methods)}"
    );
    assert "Calc.bad" not in layout.methods , (
        "the violating method must be demoted out of the native layout"
    );
    seams = _seams_of(census, "granular_method_seam.jac");
    bad_seams = [
        s
        for s in seams
        if s.startswith("Calc.bad: ")
    ];
    assert len(bad_seams) == 1 , (
        f"expected exactly one census seam for Calc.bad, got: {seams}"
    );
    assert "collections" in bad_seams[0] , (
        f"the seam reason must name the blocking construct: {bad_seams[0]}"
    );
}

test "a free function's capability violation demotes only that function" {
    (prog, ir, census) = _compile_with_census("granular_freefn_seam.jac");
    errors = [str(e) for e in prog.errors_had];
    assert not prog.errors_had , (
        f"a function-owned violation must demote, not fail the module: {errors}"
    );
    assert ir.gen.llvm_ir is not None , (
        "the module must keep its LLVM IR when only one function demotes"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "clean" in layout.functions , (
        f"clean sibling function was lost: {list(layout.functions)}"
    );
    assert "pyonly" not in layout.functions , (
        "the violating function must be demoted out of the native layout"
    );
    seams = _seams_of(census, "granular_freefn_seam.jac");
    fn_seams = [
        s
        for s in seams
        if s.startswith("pyonly: ")
    ];
    assert len(fn_seams) == 1 , (
        f"expected exactly one census seam for pyonly, got: {seams}"
    );
    assert "collections" in fn_seams[0] , (
        f"the seam reason must name the blocking construct: {fn_seams[0]}"
    );
}

test "an event ability's capability violation demotes only that ability" {
    (prog, ir, census) = _compile_with_census("granular_event_seam.jac");
    errors = [str(e) for e in prog.errors_had];
    assert not prog.errors_had , (
        f"an ability-owned violation must demote, not fail the module: {errors}"
    );
    assert ir.gen.llvm_ir is not None , (
        "the module must keep its LLVM IR when only one ability demotes"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "W.done" in layout.methods , (
        f"clean sibling ability was lost: {list(layout.methods)}"
    );
    assert "W.go" not in layout.methods , (
        "the violating ability must be demoted out of the native layout"
    );
    seams = _seams_of(census, "granular_event_seam.jac");
    go_seams = [
        s
        for s in seams
        if s.startswith("W.go: ")
    ];
    assert len(go_seams) == 1 , (
        f"expected exactly one census seam for W.go, got: {seams}"
    );
    assert "tag" in go_seams[0] , (
        f"the seam reason must name the blocked attribute: {go_seams[0]}"
    );
}

test "a module-level violation stays module-fatal and names the construct" {
    (prog, ir, census) = _compile_with_census("granular_module_fatal.jac");
    codes = [
        alrt.code.code
        for alrt in prog.errors_had
        if alrt.code is not None
    ];
    assert "E5090" in codes , (
        f"a violation with no owning callable must keep the E5090 refusal, "
        f"got: {[str(e) for e in prog.errors_had]}"
    );
    named = any("collections" in str(e) for e in prog.errors_had);
    assert named , (
        f"the module-fatal diagnostic must name the construct: {[
            str(e) for e in prog.errors_had
        ]}"
    );
    assert ir.gen.llvm_ir is None , (
        "a module-fatal violation must withhold the LLVM IR"
    );
    assert not _seams_of(census, "granular_module_fatal.jac") , (
        "a refused module must not also record granular seams"
    );
}

test "granular seams are waiver-eligible through seal_demotion_report" {
    import from jaclang.utils.precompile_bytecode { seal_demotion_report }
    (_prog, _ir, census) = _compile_with_census("granular_method_seam.jac");
    rel = "granular_method_seam.jac";
    (err, _waived, _stale) = seal_demotion_report(rel, census);
    assert "granular_method_seam.jac::Calc.bad" in err , (
        f"an un-waived granular seam must refuse to seal: {err}"
    );
    waivers = {rel: ("granular_method_seam.jac::Calc.bad", )};
    (err2, waived2, stale2) = seal_demotion_report(rel, census, waivers=waivers);
    assert err2 == "" , f"a waived granular seam must seal: {err2}";
    assert "granular_method_seam.jac::Calc.bad" in waived2 , (
        f"the waiver must be reported as consumed: {waived2}"
    );
    assert not stale2 , f"the waiver must not read as stale: {stale2}";
}
