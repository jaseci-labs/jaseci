"""Sealing wave 6: capability_check_pass reaches IR, and what the last seam is.

Same harness as waves 1, 2, 4 and 5 -- `na_census_begin` plus
`force_codespace='native'`, exactly what `seal_native_artifacts` runs -- and
the same two-way discipline: this file fails if the closure gains a member,
if IR stops being produced, or if the seam set moves in either direction.

`capability_check_pass` is not sealed here. It is measured, and the
measurement is the deliverable: wave 5 recorded it as "no IR, 7 blocking
errors, 7 own seams behind them", and every one of those seven errors is
gone. The pass produces native IR for the first time, and the seams behind
that wall are now countable rather than hypothetical.

What cleared, and how:

  - Two bare `tuple` return annotations got their element types.
    #8203 landed static tuple *fields*; a bare `tuple` return still erases,
    and it erased the violation list, its partition, and the `.values()` walk
    over the demotable map along with them.
  - `String.lit_value` is `str | bytes`, so the three f-string spec readers
    narrow to `str` and refuse a bytes spec rather than returning one through
    a `str | None` signature.
  - `item.path` is None-checked before `len()`, and the JS-method walk
    narrows its parent through `isinstance` instead of through a bool it
    stored first.
  - `isinstance(nd, NATIVE_REJECT_NODES)` narrowed the node to *the table's
    own tuple type*, which is a wrong narrow rather than a missing one. The
    checker reads a named tuple of classes as the alternatives it holds now;
    that fix is `test_isinstance_tuple_glob.jac`.

And the two own seams that cleared with it: the fatal-violation report is
typed through its `list()` copy so the emit arguments are not Unknown, the
emit splits on the optional help text because an optional cannot cross the
Python-base boundary `Transform.emit` sits behind, and the two
`viols_reported` flags moved off `UniNode.gen` onto `Module` -- `gen`'s
getter is a standing seam, so every read behind it was one too.

## The one that remains, and what it waits on

Four of the five cleared at once, and one fact did it: `jac0core/codeinfo.jac`
joined the closure. The pre-scan used to refuse it for
`import from typing { Any }`; that import is a hard error in the language now
(E1122), codeinfo spells those four annotations `any`, and
`scan_native_blockers` answers `''`. `classify_native_import` reads
codeinfo's compile-time import table and `base_expr_is_erased` reads its
erased-base table, so both resolve; `name_in_type_position` was a pure
cascade of the second and went with it.

The old three-item clearing list is spent. Item 1, `BaseTransform.prog:
JacProgram`, was cleared by the pass rim (#8288) rather than by widening --
`transform.jac` is a closure member here now, which is the proof. Items 2 and
3 were both `CLIENT_RUNTIME_SOURCE_PATHS`, a bare `tuple` of ragged rows that
would not lower under either annotation; it is a flat `list[str]` of
"/"-joined relative paths now, rejoined at its one use site.

`ClientCapabilityCheckPass.transform` cleared too, which the wave-5 reading
did not predict: it was filed as a pass-tier crossing, but
`module_codegen_pass` joins the closure alongside codeinfo, so the call to
`client_capability_violations` inlines instead of crossing an artifact
boundary.

That leaves `native_capability_violations`, and it is the real pass-tier
crossing: it calls `ModuleCodegenPass.iter_context_stmts` through the pass
tier rather than through the closure. The callee has been fixed since this
wave -- `module_codegen_pass` went from six own seams to zero and its whole
waiver tuple is deleted -- so this one clears when the crossing is linked,
not when anything is repaired. Capability is one linked crossing away from
sealing.

That is why this file pins `module_codegen_pass`'s zero separately below.
"""

import os;
import pytest;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_census_begin, na_census_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { _jaclang_image, native_artifact_for }

glob PKG_PATH = Path(jaclang.__file__).parent,
     CAPABILITY: str = "compiler/passes/main/capability_check_pass.jac",
     MODULE_CODEGEN: str = "jac0core/passes/module_codegen_pass.jac";

"""capability_check_pass's exact native closure, as package-relative paths."""
glob CAPABILITY_CLOSURE: tuple = (
         "compiler/passes/main/capability_check_pass.jac",
         "compiler/type_registry.jac",
         "compiler/type_system/type_utils.jac",
         "compiler/type_system/types.jac",
         "jac0core/codeinfo.jac",
         "jac0core/constant.jac",
         "jac0core/diagnostic_utils.jac",
         "jac0core/diagnostics.jac",
         "jac0core/helpers.jac",
         "jac0core/passes/module_codegen_pass.jac",
         "jac0core/passes/transform.jac",
         "jac0core/passes/uni_pass.jac",
         "jac0core/srcloc.jac",
         "jac0core/unitree.jac",
         "runtimelib/na_stdlib/_hashlib_native.jac",
         "runtimelib/na_stdlib/contextvars.jac",
         "runtimelib/na_stdlib/fnmatch.jac",
         "runtimelib/na_stdlib/hashlib.jac",
         "runtimelib/na_stdlib/logging.jac",
         "runtimelib/na_stdlib/pathlib.jac"
     );

"""capability's own one, mapped to the mechanism that clears it."""
glob CAPABILITY_SEAMS: dict[(str, str)] = {
         "native_capability_violations": "pass-tier crossing: calls ModuleCodegenPass.iter_context_stmts"
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

"""The bare seam names a given closure member contributes."""
def _own_seams(rel: str, member: str) -> set {
    (census, _has_ir, _errors) = _root_census(rel);
    found: set = set();
    for (path, rec) in census.items() {
        where = Path(path).resolve().relative_to(PKG_PATH.resolve()).as_posix();
        if where != member {
            continue;
        }
        for seam in (rec["seams"] or []) {
            (name, sep, _why) = str(seam).partition(": ");
            found.add(name if sep else str(seam));
        }
    }
    return found;
}


test "capability_check_pass compiles with no module-level errors" {
    (_census, _has_ir, errors) = _root_census(CAPABILITY);
    assert not errors , (
        "capability_check_pass had seven module-level errors before this "
        f"wave and must keep zero; got {len(errors)}: {errors[:5]}"
    );
}


test "capability_check_pass produces native IR" {
    (_census, has_ir, _errors) = _root_census(CAPABILITY);
    assert has_ir , (
        "no LLVM IR for capability_check_pass -- the compile aborted before "
        "codegen, so a seam count below would mean 'not reached', not "
        "'measured'"
    );
}


test "capability_check_pass's native closure is exactly the measured set" {
    (census, _has_ir, _errors) = _root_census(CAPABILITY);
    seen = tuple(
        sorted(
            Path(p).resolve().relative_to(PKG_PATH.resolve()).as_posix() for p in census
        )
    );
    assert seen == CAPABILITY_CLOSURE , (
        f"closure changed: {seen} != {CAPABILITY_CLOSURE}. If "
        "module_codegen_pass or codeinfo joined, two or three of the seams "
        "below should have cleared with it -- update both together"
    );
}


test "capability_check_pass's own seams are exactly the five named" {
    seen = _own_seams(CAPABILITY, CAPABILITY);
    expected = set(CAPABILITY_SEAMS.keys());
    assert seen == expected , (
        "capability_check_pass's own seam set moved.\n"
        + f"  gained: {sorted(seen - expected)}\n"
        + f"  lost:   {sorted(expected - seen)}\n"
        + "Each remaining seam names its clearing mechanism in "
        + "CAPABILITY_SEAMS; a loss means one landed and this table plus the "
        + "module docstring have to say so."
    );
}


test "module_codegen_pass carries no seams of its own" {
    # The half of this wave that capability's census cannot see. All six of
    # its former seams -- iter_context_stmts and the five cascades of it --
    # cleared when iter_woven_segments stopped erasing the statement type,
    # and `_MODULE_CODEGEN_SEAM_WAIVERS` is deleted. If this regresses, the
    # waiver tuple has to come back before the pass can seal again.
    seen = _own_seams(MODULE_CODEGEN, MODULE_CODEGEN);
    assert not seen , (
        f"module_codegen_pass demotes again: {sorted(seen)}. It reached zero "
        "own seams in this wave and its waiver tuple was deleted"
    );
}


test "module_codegen_pass compiles clean and produces IR" {
    (_census, has_ir, errors) = _root_census(MODULE_CODEGEN);
    assert not errors , f"module_codegen_pass errors: {errors[:5]}";
    assert has_ir , "no LLVM IR for module_codegen_pass";
}
