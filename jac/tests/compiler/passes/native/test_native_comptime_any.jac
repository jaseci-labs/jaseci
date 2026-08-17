"""Why `Any` is still not in the compile-time import vocabulary, measured.

`scan_native_blockers` decides whether a module can be *inferred* native, and
it clears an import only when every name it binds is one the native lane
erases -- `NATIVE_COMPTIME_STDLIB` is that vocabulary. `typing` lists
`TypeVar`, `ParamSpec`, `TypeVarTuple`, `cast`, `TypeAlias` and `ClassVar`,
but not `Any`, so `import from typing { Any }` answers
`unresolved import 'typing'` and the module falls out of native inference.

`jac0core/codeinfo.jac` is the module that costs. Its only typing import is
`Any`, in four has-field annotations, and it compiles natively as a forced
root with zero errors -- so the backend reaches it fine. What it cannot do is
join another module's closure, and three seams in `capability_check_pass`
(`classify_native_import`, `base_expr_is_erased`, and `name_in_type_position`
behind it) are exactly that: they read codeinfo's compile-time import table
and its erased-base table, and neither name resolves from a closure codeinfo
is not in.

`test_codeinfo_census.jac` recorded that forcing this gate open is a
regression rather than progress. That still holds on this base, and the
measurement is now specific rather than diffuse. Admitting `Any`:

  - `unitree`'s closure goes 11 -> 20 members and it stops producing IR, with
    41 module-level errors. `unitree` is a member of every sealed closure
    there is, so this is the loudest possible failure.
  - The 41 are two distinct causes, repeated. Removing both leaves exactly
    one error, which is the third.

The clearing list, all three measured on this base:

  1. `jac0core/passes/transform.jac`, the `BaseTransform.prog: JacProgram`
     has-field. Admitting `Any` makes `codeinfo` inferrable, which makes
     `transform.jac` inferrable (it imports `CodeLocInfo` from codeinfo), and
     `transform.jac` then joins closures carrying a field whose type is the
     driver object. `JacProgram` has no native layout, so the declaration is
     module-fatal for every closure member that follows it. This is the
     `Transform.prog` wall #8274 names, and #8288's M2 clears it by stamping
     driver facts on `Module` -- not by widening the field to `any`. Widening
     is measurably wrong here for a second reason: only eleven passes shadow
     `prog` with `any`, so the rest inherit the typed one and would silently
     lose every `self.prog.*` check.

  2. `jac0core/codeinfo.jac`, the `CLIENT_RUNTIME_SOURCE_PATHS: tuple` glob.
     A bare `tuple` element type does not lower.

  3. The same glob again, once it is annotated. Its rows are ragged -- two,
     three and six strings -- so a nested tuple annotation lowers as one
     heterogeneous literal struct, and storing that into a `%List.ptr` is a
     type mismatch the emitter reports as a failed native module compile. The
     shape has to change, not just the annotation.

This test pins the refusal so it clears itself: the first assertion fails the
moment `Any` is admitted, which is the point at which items 1 through 3 have
to be answered and this file rewritten into the fix's coverage. The fixture
beside it is the module that becomes admissible then.

The place `Any` belongs when that day comes is `NATIVE_COMPTIME_ANNOTATIONS`,
beside `ClassVar`, and not `NATIVE_COMPTIME_TYPE_MARKERS` beside `TypeAlias`.
That split is load-bearing and is why the two frozensets exist:
`ModuleCodegenPass.is_type_alias_decl` reads the *marker* set to decide which
globs are compile-time declarations the backend must skip. A
`TypeAlias`-annotated glob is one; an `Any`-annotated glob is an ordinary
global whose value has to reach the binary. The last test below pins that
distinction against the fixture's own `Any`-annotated glob, so it holds
whichever set `Any` eventually lands in.
"""

import os;
import from jaclang.jac0core.codeinfo { native_comptime_import_names }
import from jaclang.jac0core.parser { parse as rd_parse }
import from jaclang.jac0core.placement { scan_native_blockers }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.passes.module_codegen_pass { ModuleCodegenPass }
import from jaclang.jac0core.unitree { Assignment, GlobalVars }
import from tests.support { TESTS_DIR }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     ),
     FIXTURE: str = "comptime_any_annotation.jac";


"""Parse a fixture and return its module."""
def _parse(fixture: str) -> object {
    path = os.path.join(FIXTURES, fixture);
    with open(path, encoding='utf-8') as fh {
        src = fh.read();
    }
    (mod, had_err) = rd_parse(src, path, prog=JacProgram());
    assert not had_err , f"{fixture} did not parse";
    return mod;
}


test "the typing vocabulary still refuses Any, and the pre-scan with it" {
    assert not native_comptime_import_names("typing", ["Any"]) , (
        "'Any' is in the compile-time import vocabulary now -- then "
        "codeinfo is inferrable, transform.jac joins every closure carrying "
        "BaseTransform.prog: JacProgram, and CLIENT_RUNTIME_SOURCE_PATHS "
        "needs a lowerable shape. Answer those three and rewrite this file "
        "as the fix's coverage; see the module docstring for the measurement"
    );
    assert native_comptime_import_names("typing", ["ClassVar", "cast"]) , (
        "the names that were already admitted must stay admitted"
    );
    (reason, _deps) = scan_native_blockers(_parse(FIXTURE), FIXTURES, allow_pub=True);
    assert reason == "unresolved import 'typing'" , (
        f"the pre-scan's verdict on an Any-only module changed to {reason!r}; "
        "the refusal above and this one are the same fact and move together"
    );
}


test "an Any-annotated glob is not a compile-time declaration" {
    # The half of the eventual fix that is already decided. `TypeAlias` marks
    # a glob the backend skips; `Any` must not, because TAGGED holds a real
    # value that has to reach the binary. Putting `Any` in the marker set
    # would drop every such glob silently -- the trap `ClassVar` was lifted
    # out of in #8278.
    mod = _parse(FIXTURE);
    found = False;
    for stmt in mod.body {
        if not isinstance(stmt, GlobalVars) {
            continue;
        }
        for assign in stmt.assignments {
            if not isinstance(assign, Assignment) {
                continue;
            }
            found = True;
            assert not ModuleCodegenPass.is_comptime_type_decl(assign) , (
                "the Any-annotated glob was classified as a compile-time "
                "declaration, so its value would never be emitted"
            );
        }
    }
    assert found , "the fixture no longer declares a glob to check";
}
