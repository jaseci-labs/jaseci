"""Sealing wave 3: the reference-count fact solver joins the native seal.

Same discipline as `test_pass_seal_wave4_census.jac` and
`test_pass_seal_wave5_census.jac`: the root is measured exactly the way
`seal_native_artifacts` measures it, and three things are pinned --
exact closure membership, native IR production, and the seam set two-way
against `NATIVE_SEAL_DEMOTION_WAIVERS`.

The wave-3 census (#8271) refused all five analysis-cluster roots.
`rc_facts_pass` was refused at fourteen own seams whose named mechanism
was "`id()`-keyed identity stamps ... the `id()` builtin still does not
lower in these shapes, plus `rc_last_use`/`rc_move_in` field stamps and
dict/list literal shapes". Every clause of that refusal is now
discharged, and the shapes behind them were four distinct backend gaps,
not one:

  - `id()` refused a value wearing the `{i8 tag, T*}` optional jacket,
    which is what every `NameAtom.sym` read is. The emitter unwraps a
    pointer payload now, so the four identity stamps key natively.
  - `dataflow.jac`, the module `_solve_liveness` delegates to, typed its
    lattice element as a bare `set`. An erased element has no native
    storage, so both solvers demoted and cascaded back into this pass.
    The element is `set[SymId]` now and the module has no seams of its
    own -- and a set became iterable natively so that typing it was a
    gain rather than a trade.
  - `rc_last_use`, `rc_move_in` and the three `anon_region_*` stamps are
    `CodeGenTarget` fields, and `codeinfo.jac` is not in any pass's
    native closure. They are `Module` slots now, which is the same
    stamped-fact discipline wave 5 used in the other direction, and the
    native emitter reads the slot.
  - `is_builtin_region_name` was a pure unitree predicate marooned in
    `symbol_utils.jac`, whose own imports reach `jac0core/compiler.jac`.
    Calling it would have traded one seam for that whole module, so it
    is hoisted to the leaf `expr_keys.jac` -- and typed, since an
    `object` parameter is erased and does not lower either.

`dataflow.jac` stays a closure member rather than a root of its own:
with two functions it would be an artifact of pure plumbing.

The measurement is a source-lane one: under a sealed jaclang image the
census reads the image's trust boundary instead of each unit's own
coupling, so `_root_census` skips there (both gates below).
"""

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
     WAVE3_ROOTS: tuple = ("compiler/passes/main/rc_facts_pass.jac", );

"""Each root's exact native closure, as package-relative paths."""
glob WAVE3_CLOSURES: dict[(str, tuple)] = {
         "compiler/passes/main/rc_facts_pass.jac": (
             "compiler/expr_keys.jac",
             "compiler/passes/main/dataflow.jac",
             "compiler/passes/main/rc_facts_pass.jac",
             "compiler/type_registry.jac",
             "compiler/type_system/type_utils.jac",
             "compiler/type_system/types.jac",
             "jac0core/constant.jac",
             "jac0core/helpers.jac",
             "jac0core/srcloc.jac",
             "jac0core/unitree.jac",
             "runtimelib/na_stdlib/_hashlib_native.jac",
             "runtimelib/na_stdlib/fnmatch.jac",
             "runtimelib/na_stdlib/hashlib.jac",
             "runtimelib/na_stdlib/pathlib.jac"
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


test "every wave-3 root is registered for the seal" {
    for rel in WAVE3_ROOTS {
        assert rel in NATIVE_SEAL_ROOTS , (
            f"{rel} is not in NATIVE_SEAL_ROOTS; this census would gate "
            "nothing at seal time"
        );
        for member in WAVE3_CLOSURES[rel] {
            assert member in NATIVE_SEAL_CLOSURE , (
                f"{rel} pulls {member} into its native unit but "
                "NATIVE_SEAL_CLOSURE does not account for it"
            );
        }
    }
}


test "each wave-3 root's native closure is exactly the measured set" {
    for rel in WAVE3_ROOTS {
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
        assert seen == WAVE3_CLOSURES[rel] , (
            f"{rel}: native closure changed: {seen} != {WAVE3_CLOSURES[rel]}. "
            "A new member has to reach zero un-waived seams before this root "
            "can keep sealing."
        );
    }
}


test "each wave-3 root's closure produces native IR" {
    for rel in WAVE3_ROOTS {
        (_census, has_ir, _errors) = _root_census(rel);
        assert has_ir , (
            f"no LLVM IR for {rel} -- the compile aborted before codegen, so "
            "a zero-seam census would mean 'not reached', not 'clean'"
        );
    }
}


test "no un-waived seam in any wave-3 closure" {
    for rel in WAVE3_ROOTS {
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


test "every wave-3 seam waiver still matches a real seam" {
    for rel in WAVE3_ROOTS {
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


test "the rc-facts solver keeps its stamps off the codegen target" {
    # `codeinfo.jac` is in no pass's native closure, so a `Module.gen`
    # field store is a store into a module this artifact cannot host --
    # it demoted `_stamp_last_use`, `_stamp_move_in` and
    # `_stamp_anon_regions` for exactly that reason. The facts live in
    # `Module` slots now; a re-introduced `.gen.` stamp would demote the
    # stamping method again.
    src = (PKG_PATH / "compiler/passes/main/rc_facts_pass.jac").read_text(
        encoding='utf-8'
    );
    src += (PKG_PATH / "compiler/passes/main/impl/rc_facts_pass.impl.jac").read_text(
        encoding='utf-8'
    );
    for token in (
        "gen.rc_last_use",
        "gen.rc_move_in",
        "gen.anon_region_open",
        "gen.anon_region_close",
        "gen.anon_region_locals",
        "symbol_utils"
    ) {
        assert token not in src , (
            f"rc_facts_pass reaches '{token}' again; that is the coupling "
            "this wave removed, and it demotes the reading method out of the "
            "sealed artifact"
        );
    }
}
