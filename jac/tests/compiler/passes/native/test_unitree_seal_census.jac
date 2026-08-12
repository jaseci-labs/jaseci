"""A0 gate: `unitree.jac` and its whole native closure lower with no seams.

`unitree` cannot join `NATIVE_SEAL_MODULES` until every module the native
compile drags in with it lowers in full: a seam in a sealed artifact ships as
an `abort()` stub, so one un-lowered method kills the process on first call.
The seal's own refusal (`seal_demotion_report`) reads the same census this
test reads, so this is the seal verdict without the link and the dlopen.

Two things are asserted, and the closure assertion is the load-bearing one.
The measurement the epic quotes covers `unitree.jac` alone; the modules it
pulls in were never measured, so "unitree seals when its own seams reach zero"
was unproven. Pinning the closure membership makes any new native dependency
(a module-level import replacing a typing-only or function-local one) a loud
failure here rather than a surprise at seal time.

Waivers are enumerated one seam at a time and name the issue that blocks each,
so the suite never degrades into a "fewer than N seams" threshold: an
un-waived seam fails, and a waiver that stops matching a real seam fails too.
"""

import os;
import pytest;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_census_begin, na_census_end }
import from jaclang.jac0core.program { JacProgram }

glob PKG_PATH = Path(jaclang.__file__).parent,
     UNITREE_SRC = PKG_PATH / "jac0core" / "unitree.jac";

"""Every module the native compile of `unitree.jac` puts in its closure.

`codeinfo`, `treeprinter` and `helpers` are deliberately absent: unitree reads
them through `import type` (typing-only) or through function-local imports, so
they never enter the native unit. `codeinfo` in particular *cannot*, because
`CodeGenTarget` carries LLVM binding and estree handles and imports `unitree`
back, which would make the unit circular.
"""
glob UNITREE_CLOSURE: tuple = ("constant.jac", "srcloc.jac", "unitree.jac"),
     # Seams that stay, each naming the issue that has to land before it goes.
     # Keyed `<module>::<Type>.<method>` exactly as `_seal_demotions` keys
     # them, so an entry reads the same as one in
     # `NATIVE_SEAL_DEMOTION_WAIVERS`.
     SEAM_WAIVERS: dict[(str, str)] = {};

glob _CENSUS_MEMO: list = [];

"""Compile `unitree.jac` the way `seal_native_artifacts` does, up to the census."""
def _unitree_census -> tuple[(dict, bool)] {
    if "/.cache/jac/rt/"
        in str(Path(jaclang.__file__).resolve()).replace(os.sep, "/") {
        pytest.skip(
            "sealed-payload runtime: the compiler's own sources are not the "
            "ones a payload build would seal"
        );
    }
    if _CENSUS_MEMO {
        return _CENSUS_MEMO[0];
    }
    prog = JacProgram();
    na_census_begin();
    try {
        ir = prog.compile(
            file_path=str(UNITREE_SRC),
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
    result = (census, ir is not None and ir.gen.llvm_ir is not None, );
    _CENSUS_MEMO.append(result);
    return result;
}

"""Census seams as `<module>::<Type>.<method>` -> reason."""
def _seams_by_key -> dict[(str, str)] {
    (census, _has_ir) = _unitree_census();
    found: dict[(str, str)] = {};
    for (path, rec) in sorted(census.items()) {
        where = os.path.basename(path);
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


test "unitree's native closure is exactly the measured set" {
    (census, _has_ir) = _unitree_census();
    seen = tuple(sorted({os.path.basename(p) for p in census}));
    assert seen == UNITREE_CLOSURE , (
        f"unitree's native closure changed: {seen} != {UNITREE_CLOSURE}. "
        "A new member has to reach zero seams too before unitree can seal."
    );
}


test "unitree's closure produces native IR" {
    (_census, has_ir) = _unitree_census();
    assert has_ir , (
        "no LLVM IR for unitree.jac -- the compile aborted before codegen, so "
        "a zero-seam census below would mean 'not reached', not 'clean'"
    );
}


test "no un-waived seam in unitree's closure" {
    seams = _seams_by_key();
    unexpected = sorted(
        k
        for k in seams
        if k not in SEAM_WAIVERS
    );
    assert not unexpected , (
        f"{len(unexpected)} un-waived seam(s) in unitree's sealed closure:\n"
        + "\n".join(f"  {k}: {seams[k]}" for k in unexpected)
    );
}


test "every seam waiver still matches a real seam" {
    seams = _seams_by_key();
    stale = sorted(
        k
        for k in SEAM_WAIVERS
        if k not in seams
    );
    assert not stale , (
        "waived seams that no longer demote -- drop them:\n"
        + "\n".join(f"  {k}: {SEAM_WAIVERS[k]}" for k in stale)
    );
}
