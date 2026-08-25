"""Shared measurement harness for the native seal baselines.

`test_pass_seal_baselines.jac` and `test_pass_seal_wave6_baseline.jac` both
measure a pass root exactly the way `seal_native_artifacts` measures it -- same
`CompileOptions`, same coverage. That measurement used to be copied into each
of the seven per-wave files along with `_root_module_name`, `_root_coverage`
and `_seams_by_key`; it lives here once instead.

`_root_coverage` memoizes per root, so a root measured by several tests is
compiled once per process. The memo is safe here because the result is inert
data -- a coverage mapping, a bool and a list of error strings -- not a JIT
engine with mutable module state.
"""

import from pathlib { Path }
import jaclang;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.na_coverage { na_coverage_begin, na_coverage_end }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.jac0core.sealed { _jaclang_image, native_artifact_for }

glob PKG_PATH = Path(jaclang.__file__).parent,
     _COVERAGE_MEMO: dict[(str, tuple)] = {};

"""Module name for a package-relative root path."""
def _root_module_name(rel: str) -> str {
    return "jaclang." + rel[:-4].replace("/", ".");
}

"""Measure one root's native coverage: (coverage, has_ir, errors)."""
def _root_coverage(rel: str) -> tuple {
    if _jaclang_image() is not None {
        testskip(
            "this runtime is a sealed jaclang image; a source coverage here "
            "measures the image's trust boundary, not the unit's own seams"
        );
    }
    if native_artifact_for(_root_module_name(rel)) is not None {
        testskip(
            f"{rel} is served from this runtime's native seal; the coverage "
            "gated the build via seal_demotion_report"
        );
    }
    if rel in _COVERAGE_MEMO {
        return _COVERAGE_MEMO[rel];
    }
    prog = JacProgram();
    na_coverage_begin();
    try {
        ir = prog.compile(
            file_path=str(PKG_PATH / rel),
            options=CompileOptions(
                aot_mode=True,
                force_codespace='native',
                force_target_program=True,
                na_gc_mode='cycles',
                no_ir_cache=True
            )
        );
    } finally {
        coverage = na_coverage_end();
    }
    has_ir = ir is not None and ir.gen.llvm_ir is not None;
    errors = [str(e) for e in prog.errors_had];
    result = (coverage, has_ir, errors, );
    _COVERAGE_MEMO[rel] = result;
    return result;
}

"""Every seam in a root's closure, keyed `member::name`, valued by the reason."""
def _seams_by_key(rel: str) -> dict[(str, str)] {
    (coverage, _has_ir, _errors) = _root_coverage(rel);
    found: dict[(str, str)] = {};
    for (path, rec) in sorted(coverage.items()) {
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

"""The bare seam names one closure member contributes to a root's coverage."""
def _own_seams(rel: str, member: str) -> set[str] {
    (coverage, _has_ir, _errors) = _root_coverage(rel);
    found: set[str] = set();
    for (path, rec) in coverage.items() {
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
