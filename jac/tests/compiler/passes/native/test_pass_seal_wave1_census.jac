"""Sealing wave 1: four compiler passes join the native seal.

Each root below is measured exactly the way `seal_native_artifacts`
measures it (same `CompileOptions`, same census), and three things are
pinned per root, the same discipline `test_unitree_seal_census.jac` set:

  1. **Closure membership** is exact. Every root drags `constant`,
     `srcloc` and `unitree` into its native unit and nothing else; the
     `Transform`/`UniPass` base chain deliberately stays Python-side
     (cross-module trust), so a new closure member means a module-level
     import changed and has to reach zero seams before the root can keep
     sealing.
  2. **The root produces native IR.** A zero-seam census without IR means
     "not reached", not "clean".
  3. **The seam set matches `NATIVE_SEAL_DEMOTION_WAIVERS` two-way.** An
     un-waived seam fails (it would ship as an `abort()` stub), and a
     waiver that stops matching a real seam fails too, so the table can
     only shrink honestly.

Every waiver names what blocks it and what clears it:

  - `unitree`'s fifteen seams recur in every closure and are documented in
    `test_unitree_seal_census.jac`; each pass root's waiver tuple extends
    `_UNITREE_SEAM_WAIVERS` rather than restating them.
  - `EndpointEffectPass.enter_ability` / `.enter_archetype` are
    Python-only: they write endpoint classifications through
    `UniNode.gen` into the `InteropManifest`, Python-only codegen state
    (the same family as unitree's waived `UniNode.gen.__get__`). They
    clear when endpoint effects are emitted as data the driver collects,
    the #86 diagnostics-as-data pattern.
  - `ModuleCodegenPass.iter_context_stmts` hits one backend gap:
    `isinstance` over an element-erased sequence element (`module.body`
    reaches it as a bare `Sequence`). `iter_module_imports`,
    `iter_nested_imports`, `has_native_context_stmts`,
    `shared_archetypes_for_context` and `client_capability_violations`
    are pure call-cascades of that one method. All six clear together
    when the native backend lowers `isinstance` over erased operands,
    the unlanded remainder of the #8214 family.
  - `UniPass.get_all_sub_nodes` / `.find_parent_of_type` are `type[T]`
    TypeVar-generic statics that only forward to the same-named `UniNode`
    methods; the backend cannot lower a TypeVar-bound signature. They
    clear when generic statics lower, or when the forwarding shims are
    retired in favor of the `UniNode` methods they wrap.

`test_sealed_seam_reachability.jac` proves the other half for every
waiver: no waived name is reachable through native-internal calls from
the root's live entry surface, so each stub ships dead. Reachable
Python callers are routed by the layout registration, which never binds
a demoted method.

`sem_def_match_pass.jac` was measured for this wave (zero own seams, IR,
the same four-module closure) and refused: its live `connect_sems`
dispatches `Token.lit_value` through the vtable, and the
`String`/`MultiString` decoders are eval-bound Python-only stubs, so a
sealed build would abort on the first real semdef. The refusal and its
self-clearing condition are pinned in `test_sealed_seam_reachability.jac`.
"""

import os;
import pytest;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_census_begin, na_census_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { native_artifact_for }
import from jaclang.utils.precompile_bytecode {
    NATIVE_SEAL_CLOSURE,
    NATIVE_SEAL_ROOTS,
    seal_waiver_names
}

glob PKG_PATH = Path(jaclang.__file__).parent,
     WAVE1_ROOTS: tuple = (
         "jac0core/passes/annex_pass.jac",
         "jac0core/passes/module_codegen_pass.jac",
         "jac0core/passes/uni_pass.jac",
         "jac0core/passes/endpoint_effect_pass.jac"
     );

"""Each root's exact native closure, as package-relative paths."""
glob WAVE1_CLOSURES: dict[(str, tuple)] = {
         "jac0core/passes/annex_pass.jac": (
             "jac0core/constant.jac",
             "jac0core/passes/annex_pass.jac",
             "jac0core/passes/annex_weave.jac",
             "jac0core/srcloc.jac",
             "jac0core/unitree.jac"
         ),
         "jac0core/passes/module_codegen_pass.jac": (
             "jac0core/constant.jac",
             "jac0core/passes/module_codegen_pass.jac",
             "jac0core/srcloc.jac",
             "jac0core/unitree.jac"
         ),
         "jac0core/passes/uni_pass.jac": (
             "jac0core/constant.jac",
             "jac0core/passes/uni_pass.jac",
             "jac0core/srcloc.jac",
             "jac0core/unitree.jac"
         ),
         "jac0core/passes/endpoint_effect_pass.jac": (
             "jac0core/constant.jac",
             "jac0core/passes/endpoint_effect_pass.jac",
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


test "every wave-1 root is registered for the seal" {
    for rel in WAVE1_ROOTS {
        assert rel in NATIVE_SEAL_ROOTS , (
            f"{rel} is not in NATIVE_SEAL_ROOTS; this census would gate "
            "nothing at seal time"
        );
        for member in WAVE1_CLOSURES[rel] {
            assert member in NATIVE_SEAL_CLOSURE , (
                f"{rel} pulls {member} into its native unit but "
                "NATIVE_SEAL_CLOSURE does not account for it"
            );
        }
    }
}


test "each root's native closure is exactly the measured set" {
    for rel in WAVE1_ROOTS {
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
        assert seen == WAVE1_CLOSURES[rel] , (
            f"{rel}: native closure changed: {seen} != {WAVE1_CLOSURES[rel]}. "
            "A new member has to reach zero un-waived seams before this root "
            "can keep sealing."
        );
    }
}


test "each root's closure produces native IR" {
    for rel in WAVE1_ROOTS {
        (_census, has_ir, _errors) = _root_census(rel);
        assert has_ir , (
            f"no LLVM IR for {rel} -- the compile aborted before codegen, so "
            "a zero-seam census would mean 'not reached', not 'clean'"
        );
    }
}


test "no un-waived seam in any wave-1 closure" {
    for rel in WAVE1_ROOTS {
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


test "every wave-1 seam waiver still matches a real seam" {
    for rel in WAVE1_ROOTS {
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
