"""Why `Any` will never be in the compile-time import vocabulary, and codeinfo's clearing.

This file used to pin a refusal and a three-item clearing list: `typing`'s
compile-time vocabulary admitted `TypeVar`, `cast`, `TypeAlias` and
`ClassVar` but not `Any`, so `import from typing { Any }` answered
`unresolved import 'typing'` and `jac0core/codeinfo.jac` -- whose only typing
import that was -- fell out of native inference. Three seams in
`capability_check_pass` were that one fact, and the list said what admitting
`Any` would cost.

The question is closed now, and not by admitting the name. `Any` is not
importable from `typing` at all: E1122 refuses every shape that binds it,
because jac has its own `any` and will not carry an aliased twin. A name the
language rejects can never reach the pre-scan, so there is nothing for the
vocabulary to decide. The first test below pins that -- the vocabulary must
keep refusing `Any`, now for a reason that cannot change back.

`codeinfo` spells its four annotations `any` and imports nothing from
`typing`, so the import-shaped blocker is gone. The deliberate hold that
replaced the accident is gone too: B4 (#8323) emptied
`PLACEMENT_INFERENCE_HELD` after answering what it priced --
`test_codeinfo_census.jac` carries the 19-member closure, the 21 arriving
seams are waived by name in `NATIVE_SEAL_DEMOTION_WAIVERS`, and
`test_unitree_seal_census.jac` pins the sealed root that absorbs them. The
third test below now guards the emptiness: a module held again must bring
its reason and its census with it.

The clearing list, and where each item stands:

  1. `BaseTransform.prog: JacProgram`. The field had no native layout, so it
     was module-fatal for every closure member behind it. #8288's pass rim
     stamps `prog` on the instance at construction and the declaration is
     gone -- not widened to `any`, which would have been wrong twice over
     (only eleven passes shadowed it, so the rest would have silently lost
     every `self.prog.*` check). `jac0core/passes/transform.jac` is a member
     of codeinfo's closure now, which is the measurement that says so.

  2 and 3. `codeinfo`'s `CLIENT_RUNTIME_SOURCE_PATHS` glob, which was a bare
     `tuple` whose element type did not lower, and would not lower annotated
     either: its rows were ragged -- two, three and six strings -- so a
     nested tuple annotation became one heterogeneous literal struct and
     storing it into a `%List.ptr` was a type mismatch. The shape had to
     change, and it did: a flat `list[str]` of "/"-joined relative paths,
     rejoined with `os.sep` at its one use site.

So the list is spent as a list: nothing on it blocks anything any more. The
single named hold that replaced it is spent too, and its prediction held
exactly: with the entry empty, four of `capability_check_pass`'s five seams
cleared -- three because it reads `codeinfo`'s tables in-unit, and
`ClientCapabilityCheckPass.transform` because `module_codegen_pass` joined
alongside. `test_pass_seal_wave6_census.jac` carries the measurement.

The last test keeps the half of the old reasoning that outlived the rest.
`ModuleCodegenPass.is_erased_type_decl` reads the *marker* set
(`NATIVE_ERASED_TYPE_MARKERS`, `TypeAlias`) to decide which globs are
compile-time declarations the backend skips. An `any`-annotated glob is not
one: it is an ordinary global whose value has to reach the binary, and
classifying it as a declaration would drop it silently. That is the trap
`ClassVar` was lifted out of in #8278, and it holds for the lowercase
keyword exactly as it would have for the name.
"""

import os;
import from jaclang.jac0core.codeinfo { native_erased_import_names }
import from jaclang.jac0core.parser { parse as rd_parse }
import from jaclang.jac0core.placement { scan_native_blockers }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.passes.module_codegen_pass { ModuleCodegenPass }
import from jaclang.jac0core.unitree { Assignment, GlobalVars }
import from tests.support { TESTS_DIR }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     ),
     FIXTURE: str = "erased_any_annotation.jac";


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


test "the typing vocabulary refuses Any, and no module can ask it to" {
    assert not native_erased_import_names("typing", ["Any"]) , (
        "'Any' is in the compile-time import vocabulary. It must not be: "
        "E1122 refuses every import that binds the name, so admitting it "
        "here would describe a module the language cannot accept"
    );
    assert native_erased_import_names("typing", ["ClassVar", "cast"]) , (
        "the names that were already admitted must stay admitted"
    );
}


test "a module annotated with the any keyword needs no import to infer native" {
    (reason, _deps) = scan_native_blockers(_parse(FIXTURE), FIXTURES, allow_pub=True);
    assert reason == "" , (
        f"the pre-scan refused an any-annotated module with {reason!r}. The "
        "lowercase keyword is a builtin: it binds no import, so there is "
        "nothing here for the scan to resolve"
    );
}


test "the inference hold table is empty, and emptying it was answered" {
    import from jaclang.jac0core.placement { PLACEMENT_INFERENCE_HELD }
    assert not PLACEMENT_INFERENCE_HELD , (
        "a module is held out of native inference again: "
        f"{PLACEMENT_INFERENCE_HELD!r}. A hold is a deliberate debt with a "
        "named reason and a census that prices it -- codeinfo's was carried "
        "here until B4 (#8323) answered its 21-seam closure; a new one "
        "needs the same treatment, not just this assertion flipped back"
    );
}


test "an any-annotated glob is not a compile-time declaration" {
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
            assert not ModuleCodegenPass.is_erased_type_decl(assign) , (
                "the any-annotated glob was classified as a compile-time "
                "declaration, so its value would never be emitted"
            );
        }
    }
    assert found , "the fixture no longer declares a glob to check";
}
