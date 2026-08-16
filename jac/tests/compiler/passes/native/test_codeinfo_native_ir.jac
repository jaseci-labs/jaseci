"""`codeinfo` reaches the native backend, and what still stops short (#8201).

`codeinfo.jac` declares the whole codegen data model -- `CodeGenTarget`,
`InteropManifest`, the native layout records -- and 47 of its has-fields
default through `dataclasses.field(default_factory=...)`. `dataclasses` was
in no native import vocabulary, so a module-scope import with no owning
callable made the module fatally un-lowerable: no IR at all, so nothing that
reads a `CodeGenTarget` field could ever lower either.

`field` is now a compile-time declaration-site marker, the same shape `cast`
and `TypeAlias` already had: admitted per name in `NATIVE_COMPTIME_STDLIB`
and erased where it is written, at the has-field default. Four other
module-fatal constructs had to clear with it, since a fatal one hides the
rest: two `object`-typed parameters whose attributes the checker refused, a
`relpath` return that widened to `bytes`, and two `ContextVar` globs whose
inferred type arguments a type-erased generic archetype cannot carry (the
defaults moved to the read sites, which is what CPython's `ContextVar.get`
means anyway).

What this test pins is the measured result: `codeinfo` produces IR and every
remaining refusal is a per-callable seam, so the module ships. Each seam is
filesystem, config or Python-codegen machinery, none of it the data model.

**What it does not do, measured rather than assumed.** The nine
`interop_manifest` seams in `boundary_analysis_pass` do not clear yet. They
read `self.ir_in.gen.interop_manifest`, and `UniNode.gen`'s getter imports
`CodeGenTarget` from `codeinfo` at run time; for that call to lower,
`codeinfo` has to be *inferred* native, not merely compilable as a forced
root. `scan_native_blockers` still answers `unresolved import 'typing'` for
it -- `Any` is not in the compile-time vocabulary and is used as a real
annotation, not a type-only name. Forcing that gate open was measured on
this base and is a regression, not progress: `codeinfo` then joins
`unitree`'s closure, which grows from three modules to sixteen and stops
producing IR, and `unitree` is a member of every sealed closure there is.
That is wave work, and `test_unitree_seal_census.jac` is the guard that
catches it. This change is deliberately closure-neutral for every sealed
root.
"""

import pytest;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_census_begin, na_census_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { native_artifact_for }

glob PKG_PATH = Path(jaclang.__file__).parent,
     CODEINFO: str = "jac0core/codeinfo.jac";

"""codeinfo's exact native closure, as package-relative paths."""
glob CODEINFO_CLOSURE: tuple = (
         "jac0core/codeinfo.jac",
         "jac0core/constant.jac",
         "jac0core/srcloc.jac",
         "jac0core/unitree.jac",
         "runtimelib/na_stdlib/_hashlib_native.jac",
         "runtimelib/na_stdlib/contextvars.jac",
         "runtimelib/na_stdlib/hashlib.jac"
     );

"""codeinfo's own seams: filesystem, config and Python-codegen machinery."""
glob CODEINFO_SEAMS: tuple = (
         "CodeGenTarget.doc_ir.__get__",
         "_func_layout_to_dict",
         "_inferred_native_path",
         "effective_default_codespace",
         "effective_native_closure_cap",
         "install_native_static_init",
         "is_bundled_native_module",
         "is_client_by_location",
         "is_native_by_location",
         "native_layout_to_dict",
         "native_stdlib_root",
         "native_wasm_stem",
         "resolve_native_module"
     );

glob _CENSUS_MEMO: dict[(str, tuple)] = {};

"""Compile one root the way seal_native_artifacts does, up to the census."""
def _root_census(rel: str) -> tuple {
    if native_artifact_for("jaclang." + rel[:-4].replace("/", ".")) is not None {
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

"""The seam names one closure member reported, sorted."""
def _seam_names(census: dict, member: str) -> tuple {
    names: list[str] = [];
    for (path, rec) in census.items() {
        where = Path(path).resolve().relative_to(PKG_PATH.resolve()).as_posix();
        if where != member {
            continue;
        }
        for seam in (rec["seams"] or []) {
            (name, sep, _why) = str(seam).partition(": ");
            names.append(name if sep else str(seam));
        }
    }
    return tuple(sorted(names));
}


test "codeinfo compiles clean and produces native IR" {
    (_census, has_ir, errors) = _root_census(CODEINFO);
    assert not errors , (
        "codeinfo must reach the backend with nothing fatal left; a "
        f"module-scope refusal hides every other one: {errors[:5]}"
    );
    assert has_ir , (
        "no LLVM IR for codeinfo -- the compile aborted before codegen, so "
        "a zero-error census would mean 'not reached', not 'clean'"
    );
}


test "codeinfo's native closure is exactly the measured set" {
    (census, _has_ir, _errors) = _root_census(CODEINFO);
    seen = tuple(
        sorted(
            Path(p).resolve().relative_to(PKG_PATH.resolve()).as_posix() for p in census
        )
    );
    assert seen == CODEINFO_CLOSURE , (
        f"codeinfo's native closure changed: {seen} != {CODEINFO_CLOSURE}"
    );
}


test "every codeinfo refusal is a per-callable seam, and only these" {
    (census, _has_ir, _errors) = _root_census(CODEINFO);
    seen = _seam_names(census, CODEINFO);
    assert seen == CODEINFO_SEAMS , (
        "codeinfo's seam set moved. A new name means the data model grew a "
        "refusal the backend cannot lower; a missing one means a seam "
        f"cleared and this table should shrink: {seen} != {CODEINFO_SEAMS}"
    );
}


test "no codeinfo refusal names the declaration-site field marker" {
    (census, _has_ir, errors) = _root_census(CODEINFO);
    for text in [*errors, *_seam_names(census, CODEINFO)] {
        assert "dataclasses" not in text , (
            "`dataclasses.field` is a compile-time declaration the has-field "
            f"default consumes; nothing may refuse it again: {text}"
        );
    }
}
