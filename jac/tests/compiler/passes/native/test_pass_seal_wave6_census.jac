"""Sealing wave 6: capability_check_pass reaches IR, and what the last five seams are.

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

## The five that remain, and what each one waits on

Three are one fact: `jac0core/codeinfo.jac` is not in the closure.
`scan_native_blockers` refuses it for `import from typing { Any }`, and
`test_native_comptime_any.jac` carries that measurement and its three-item
clearing list. `classify_native_import` reads codeinfo's compile-time import
table, `base_expr_is_erased` reads its erased-base table, and
`name_in_type_position` is a pure cascade of the second.

Two are the pass-tier boundary. `native_capability_violations` calls
`ModuleCodegenPass.iter_context_stmts` and `ClientCapabilityCheckPass`
calls `client_capability_violations`, and both of those now lower --
`module_codegen_pass` went from six own seams to zero in this wave, and its
whole waiver tuple is deleted. The scan admits it as a dependency of
capability, and it still does not join capability's closure: a sealed pass
root is its own artifact, so one pass calling another crosses an artifact
boundary rather than inlining it. These two clear when that crossing is
linked, not when the callee is fixed -- the callee is already fixed.

That is why this file pins `module_codegen_pass`'s zero separately below. It
is the half of the work that landed, and it is invisible from capability's
own census.
"""

import os;
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
         "jac0core/constant.jac",
         "jac0core/diagnostics.jac",
         "jac0core/helpers.jac",
         "jac0core/srcloc.jac",
         "jac0core/unitree.jac",
         "runtimelib/na_stdlib/_hashlib_native.jac",
         "runtimelib/na_stdlib/fnmatch.jac",
         "runtimelib/na_stdlib/hashlib.jac",
         "runtimelib/na_stdlib/pathlib.jac"
     );

"""capability's own five, each mapped to the mechanism that clears it."""
glob CAPABILITY_SEAMS: dict[(str, str)] = {
         "classify_native_import": "codeinfo not in closure: reads native_comptime_import_names",
         "base_expr_is_erased": "codeinfo not in closure: reads NATIVE_COMPTIME_BASES",
         "name_in_type_position": "cascade of base_expr_is_erased",
         "native_capability_violations": "pass-tier crossing: calls ModuleCodegenPass.iter_context_stmts",
         "ClientCapabilityCheckPass.transform": "pass-tier crossing: calls client_capability_violations"
     };

glob _CENSUS_MEMO: dict[(str, tuple)] = {};

"""A root's dotted module name, for the sealed-runtime skip gate."""
def _root_module_name(rel: str) -> str {
    return "jaclang." + rel[:-4].replace("/", ".");
}

"""Compile one root the way seal_native_artifacts does, up to the census."""
def _root_census(rel: str) -> tuple {
    if _jaclang_image() is not None {
        testskip(
            "this runtime is a sealed jaclang image; a source census here "
            "measures the image's trust boundary, not the unit's own seams"
        );
    }
    if native_artifact_for(_root_module_name(rel)) is not None {
        testskip(
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
