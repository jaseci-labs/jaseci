"""The pass base chain is monomorphic, and its constructor lowers (#8288 M1).

`BaseTransform[T_in, T_out]` and `Transform[T: UniNode, R: UniNode]` were
generic, and a slot typed by a class type parameter lowers to a bare
erased pointer carrying no class. `BaseTransform.postinit` reads exactly
such a slot -- `self.ir_out = self.timed_transform(ir_in=self.ir_in)` --
so `Transform.__post_init__` demoted, and a pass constructed natively
could not have run its transform even if construction had otherwise
worked. That is the M1 ladder's rung 1, and this file is its acceptance.

The parameters bought nothing to lose. Thirty-nine subclasses
instantiate them, thirty-eight at `Module -> Module`, and the
thirty-ninth (`PyastBuildPass`, at `PythonModuleAst`) is an `EmptyToken`
and therefore a `UniNode` like the rest. Ten already redeclared `ir_in`
concretely. `run_pass` takes `(type, any)` and returns `any`, so the
driver never saw them either.

What replaces them is one concrete redeclaration at `ModuleCodegenPass`,
the seat every `UniPass` descends from. That is what keeps the checker
whole: its diagnostics over the pass sources are unchanged, which is the
measurement the base classes' typing was there to protect.

Pinned here: the chain carries no type parameters, and the constructor
lowers. The seams that remain on the unit are inventoried once, in
`test_transform_diagnostics_census.jac`, which pins them two-way with
the mechanism that clears each -- so a constructor that demoted again
would fail there as an un-waived seam and fail here by name.

And pinned here too, because this is the file that owns the question: what
a pass *construction* inside a native root does now. Section 11.1 of
`internals/fused-pipeline.md` measured it as a discarded
`_pyb_instantiate` bridge after which the field read answered the field's
declared default -- the pass did not run and nothing said so. Then it
refused, with E5088, because the base modules were not in the root's
closure. Now it lowers: the base chain links, and the last two tests in
this file pin that, together with the seam that is next -- the traversal
methods still refuse on stores to slots they inherit.
"""

import os;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_census_begin, na_census_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { _jaclang_image, native_artifact_for }

glob PASSES_DIR = Path(jaclang.__file__).parent / "jac0core" / "passes",
     TRANSFORM_UNIT = "jaclang.jac0core.passes.transform",
     CTOR_PROBE = (
         Path(jaclang.__file__).parent
         / "compiler"
         / "tests"
         / "fixtures"
         / "native_pass_ctor_probe.jac"
     ),
     _MEMO: list = [],
     _PROBE_MEMO: list = [];

"""Seams the native census recorded inside transform.jac, keyed by method."""
def _transform_seams -> dict[(str, str)] {
    if _jaclang_image() is not None {
        testskip(
            "this runtime is a sealed jaclang image, so the census would "
            "read the image's trust boundary rather than this unit's own "
            "coupling"
        );
    }
    if native_artifact_for(TRANSFORM_UNIT) is not None {
        testskip("transform is served from this runtime's native seal");
    }
    if _MEMO {
        return _MEMO[0];
    }
    path = str(PASSES_DIR / "transform.jac");
    prog = JacProgram();
    na_census_begin();
    try {
        ir = prog.compile(
            file_path=path,
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
    assert ir is not None , "transform.jac produced no module";
    rec = census.get(os.path.realpath(path));
    assert rec is not None , "transform.jac never entered the native census";
    assert rec["outcome"] == "native" , (
        f"transform.jac did not stay native ({rec['outcome']}: {rec['detail']})"
    );
    found: dict[(str, str)] = {};
    for seam in (rec["seams"] or []) {
        (name, sep, why) = str(seam).partition(": ");
        found[name if sep else str(seam)] = why if sep else "";
    }
    # The unit exports no LLVM IR and no layout of its own -- it is in no
    # closure, which is section 11.1's symptom rather than its disease --
    # so the census record is the whole measurement. It is guarded against
    # vacuity from the other side: the seam set is pinned both ways below,
    # and an unreached compile would empty it and fail on the stale half.
    assert found , (
        "the census recorded no seam at all for transform.jac, which on "
        "this unit means the compile was never reached rather than that it "
        "is clean"
    );
    _MEMO.append(found);
    return found;
}


test "the pass base chain declares no type parameters" {
    text = (PASSES_DIR / "transform.jac").read_text(encoding="utf-8");
    # The base is `PassRim` rather than `ABC` since rung 2 moved the program
    # handle and the tier check to the driver rim; what this pins is the
    # absence of type parameters, so it matches the head of the declaration
    # and requires the bracket to stay gone.
    assert "obj BaseTransform(PassRim)" in text , (
        "BaseTransform took type parameters again, or stopped inheriting "
        "the rim; a slot typed by a class type parameter lowers to an "
        "erased pointer and takes the constructor down with it"
    );
    assert "obj Transform(BaseTransform)" in text , (
        "Transform took type parameters again"
    );
}


test "the pass constructor lowers natively" {
    seams = _transform_seams();
    assert "Transform.__post_init__" not in seams , (
        "the pass constructor demoted again: "
        + seams.get("Transform.__post_init__", "")
        + ". Until it lowers, a natively constructed pass is a hollow "
        "object whose transform never ran, which is the whole of M1 rung 1"
    );
}


"""Compile the constructor probe as a native root; (seams, closure)."""
def _ctor_probe -> tuple {
    if _jaclang_image() is not None {
        testskip("a sealed image measures its trust boundary, not this");
    }
    if _PROBE_MEMO {
        return _PROBE_MEMO[0];
    }
    prog = JacProgram();
    na_census_begin();
    try {
        prog.compile(
            file_path=str(CTOR_PROBE),
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
    rec = census.get(os.path.realpath(str(CTOR_PROBE)));
    assert rec is not None and rec["outcome"] == "native" , (
        "the constructor probe never compiled as a native root, so nothing "
        "below is a measurement"
    );
    seams: dict[(str, str)] = {};
    for seam in (rec["seams"] or []) {
        (name, sep, why) = str(seam).partition(": ");
        seams[name if sep else str(seam)] = why if sep else "";
    }
    closure = sorted(
        os.path.relpath(p, os.path.dirname(os.path.realpath(jaclang.__file__)))
        for p in census
    );
    result = (seams, closure, );
    _PROBE_MEMO.append(result);
    return result;
}


"""The base chain links, and a pass construction inside a native root lowers.

This test used to pin the opposite. Section 11.1 of
`internals/fused-pipeline.md` measured the construction as a silent
`_pyb_instantiate` bridge whose result was discarded; #8305 turned that into
E5088, #8306 and rung 2 emptied the unit of everything un-lowerable, and
what was left was a refusal whose reason was the closure: an
`import from ... { UniPass }` inside a native root pulled in none of
`uni_pass.jac`, `module_codegen_pass.jac` or `transform.jac`, so
`UniPass.postinit` would have run on a Python shadow.

The cause was one import. A native root's walk filters candidates through
`native_default_path_ok`, the placement pre-scan, run over the candidate and
every transitive `.jac` dependency, all-or-nothing. `transform.jac` asked
`codeinfo.jac` for `CodeLocInfo` -- a symbol `srcloc.jac` declares and
`codeinfo` merely re-exports -- and `codeinfo.jac` scans dirty on its own
`import from typing { Any }`. Retargeting the import to the declaring module
took `codeinfo.jac` out of the chain's closure, and all three base modules
now pass the scan and link.

So E5088 is gone here because its precondition is gone, which is the remedy
its own help text names. What the probe pins now is that state, both ways:
the construction lowers with no seam at all, and the three base modules are
in the closure. If either half regresses, the walk stopped reaching the base
chain again and the first place to look is a re-export import.
"""
test "constructing a pass in a native root lowers, with the base chain linked" {
    (seams, closure) = _ctor_probe();
    why = seams.get("probe_construct", "");
    assert not why , (
        f"constructing a pass inside a native root demoted again: {why}. If "
        "this is E5088, the base chain fell out of the root's closure -- "
        f"check for a re-export import (closure was {closure})"
    );
    for base in (
        "jac0core/passes/transform.jac",
        "jac0core/passes/uni_pass.jac",
        "jac0core/passes/module_codegen_pass.jac"
    ) {
        assert base in closure , (
            f"{base} left the native root's closure. The construction may "
            "still lower by accident; the base chain linking is the thing "
            "this test exists to hold"
        );
    }
    assert "jac0core/codeinfo.jac" not in closure , (
        "codeinfo.jac is back in the pass base chain's closure. It scans "
        "dirty on `import from typing { Any }`, so it does not merely cost "
        "compile time -- it takes the whole chain out of the walk. Whatever "
        "re-export pulled it in should ask the declaring module instead"
    );
}


"""The traversal seam cleared, and the waiver table says so.

This test used to pin the opposite: `UniPass.transform`, `UniPass.traverse`
and `UniPass.__post_init__` as waived seams -- stores to `ir_out` and
`cur_node`, slots inherited from `BaseTransform`, and a
`super.__post_init__` call. The inherited-slot fix (#8320: `extended_mro`
continuing truncated linearizations, keyed by declaring-module provenance)
cleared all three, and the payout commit dropped their waivers. What
remains waived on `uni_pass.jac` is a different family entirely: the two
`type[T]`-generic statics.

Pinned both ways so a regression names itself: the cleared three must stay
out of the waiver table (a re-appearance means inherited-slot access broke
again and the fused prefix is re-blocked), and the generic statics must
stay in it until generic statics lower. The mechanism itself is measured in
`test_inherited_slot_adoption.jac`.
"""
test "the traversal seams stay cleared, and the generic statics stay named" {
    (seams, _closure) = _ctor_probe();
    _ = seams;
    import from jaclang.utils.precompile_bytecode { _UNI_PASS_SEAM_WAIVERS }
    for gone in (
        "jac0core/passes/uni_pass.jac::UniPass.transform",
        "jac0core/passes/uni_pass.jac::UniPass.traverse",
        "jac0core/passes/uni_pass.jac::UniPass.__post_init__"
    ) {
        assert gone not in _UNI_PASS_SEAM_WAIVERS , (
            f"{gone} is waived again. The inherited-slot fix cleared it; a "
            "returning waiver means a natively constructed pass lost its "
            "traversal again, which re-blocks the fused prefix -- fix the "
            "slot access rather than re-waiving it"
        );
    }
    for kept in (
        "jac0core/passes/uni_pass.jac::UniPass.get_all_sub_nodes",
        "jac0core/passes/uni_pass.jac::UniPass.find_parent_of_type"
    ) {
        assert kept in _UNI_PASS_SEAM_WAIVERS , (
            f"{kept} is no longer waived. If generic statics lower now, "
            "collect the payout and say so; if the waiver merely moved, it "
            "has to be findable here"
        );
    }
}
