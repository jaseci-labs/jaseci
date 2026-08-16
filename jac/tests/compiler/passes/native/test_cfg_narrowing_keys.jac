"""The narrowing-key walk that CFGBuildPass calls is native-clean (#8201).

`collect_narrowing_symbols` and `collect_assigned_symbols` used to live in
`jaclang/compiler/symbol_utils.jac`, which imports the Python-side compiler
infrastructure. CFGBuildPass reaches them from `enter_node` and from every
branch visitor, so seven of the pass's eleven own seams were one family: a
live, unwaivable call into a Python-only module. The bodies now live in
`jaclang/compiler/expr_keys.jac`, whose only imports are `unitree` and
`constant`; `symbol_utils` re-exports them so its other consumers are
unchanged.

Two things are pinned here, the same discipline the wave census tests keep:

  1. `expr_keys` compiles natively, produces IR and has zero seams. A
     zero-seam census without IR would mean "not reached", not "clean", so
     both halves are asserted. If someone adds a Python-side import to
     `expr_keys`, this fails before CFGBuildPass silently grows the family
     back.
  2. No seam of `cfg_build_pass` names either function. The census is the
     measurement that matters: the reason string is what a sealed build
     would turn into an `abort()` stub.

The residue is left honest rather than asserted away. `cfg_build_pass` still
carries four own seams: `_find_next_cfg_stmt_after` reads `parent?.body` on a
base-typed `UniNode` (no common base declares `body`, so the backend has no
static offset), and `CoalesceBBPass.enter_node`, `CoalesceBBPass._node_label`
and `cfg_dot_from_file` are the dot-graph tooling family, reachable only from
`jac tool` through `lang_tools`.
"""

import pytest;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_census_begin, na_census_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { native_artifact_for }

glob PKG_PATH = Path(jaclang.__file__).parent,
     CFG_ROOT: str = "compiler/passes/main/cfg_build_pass.jac",
     KEYS_MOD: str = "compiler/expr_keys.jac",
     HOISTED: tuple = ("collect_narrowing_symbols", "collect_assigned_symbols");

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

"""The census record for one package-relative module in a root's closure."""
def _record_for(rel: str, member: str) -> (dict | None) {
    (census, _has_ir, _errors) = _root_census(rel);
    for (path, rec) in census.items() {
        where = Path(path).resolve().relative_to(PKG_PATH.resolve()).as_posix();
        if where == member {
            return rec;
        }
    }
    return None;
}


test "the cfg root compiles clean and produces native IR" {
    (_census, has_ir, errors) = _root_census(CFG_ROOT);
    assert not errors , (
        f"{CFG_ROOT} compile errors (a census below would be 'not reached', "
        f"not 'clean'): {errors[:5]}"
    );
    assert has_ir , (
        f"no LLVM IR for {CFG_ROOT} -- the compile aborted before codegen"
    );
}


test "expr_keys joins the cfg closure and lowers with no seams" {
    rec = _record_for(CFG_ROOT, KEYS_MOD);
    assert rec is not None , (
        f"{KEYS_MOD} is not in {CFG_ROOT}'s native closure; CFGBuildPass no "
        "longer reaches the hoisted narrowing walk, or it reaches it through "
        "a module that does not lower"
    );
    assert rec["outcome"] == "native" , (
        f"{KEYS_MOD} did not lower natively: [{rec['code']}] {rec['detail']}"
    );
    seams = rec["seams"] or [];
    assert not seams , (
        f"{KEYS_MOD} grew native seams, so CFGBuildPass would demote again: " f"{seams}"
    );
}


test "no cfg seam names the hoisted narrowing walk" {
    rec = _record_for(CFG_ROOT, CFG_ROOT);
    assert rec is not None , f"{CFG_ROOT} is missing from its own census";
    offenders: list[str] = [];
    for seam in (rec["seams"] or []) {
        for name in HOISTED {
            if name in str(seam) {
                offenders.append(str(seam));
            }
        }
    }
    assert not offenders , (
        "a cfg seam still names the hoisted narrowing walk, so the family "
        f"came back through a Python-side module: {offenders}"
    );
}
