"""Typeshed gate: missing vendored stubs must fail loudly, never silently.

Pins the contract behind #8533: in dev-source mode over a plain source
checkout, the gitignored `vendor/typeshed/stdlib` stubs could be absent, and
the old inference-schedule builder answered with an empty schedule that every
caller read as "nothing to do". Result: zero semantic type diagnostics, while
the released binary (which always bundles the stubs) rejected the same code.

The contract now is:

- Type checking sits unconditionally on the critical path of every
  compilation; there is no silent empty-schedule fallback.
- When the vendored typeshed stubs are missing, building the analysis
  schedule raises `TypeshedUnavailableError` with remediation guidance,
  before any module can compile.
- End-to-end parity control: the issue's exact repro (`return "a" + 1` from a
  `str` function) reports a type error through the library API.

Note: the first cold run of this file bootstraps the dev-source toolchain and
can take a minute or two compiling the import graph; subsequent runs are fast.
"""

import from unittest { mock }
import jaclang.compiler.driver.schedules as compiler_mod;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

def check_src(src: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path="ts_gate_src.jac", use_str=src, options=CompileOptions(no_cgen=True)
    );
    return [str(e) for e in prog.errors_had];
}

test "missing typeshed stubs fail loudly when building the analysis schedule" {
    # Direct regression pin for #8533: with the stubs unavailable, the gate
    # must raise -- never return an empty schedule that callers treat as
    # "nothing to check".
    raised = None;
    with mock.patch.object(
        compiler_mod, "typeshed_stubs_available", lambda -> bool { return False; }
    ) {
        try {
            compiler_mod.get_analysis_sched();
        } except compiler_mod.TypeshedUnavailableError as e {
            raised = e;
        }
    }
    assert raised is not None , raised;
    assert "fetch-typeshed" in str(raised) , raised;
}

test "gate passes when the vendored stubs are present" {
    # Documents that CI's fetched-stub environment satisfies the gate. If the
    # stubs were ever missing here, every checker test fails loudly instead --
    # which is exactly the intended contract.
    assert compiler_mod.typeshed_stubs_available();
    compiler_mod.require_typeshed_stubs();
}

test "control: issue repro reports type errors through the library API" {
    src = "def bad -> str {\n" "    return \"a\" + 1;\n" "}\n";
    errors = check_src(src);
    assert any(("E1055" in e) or ("__add__" in e) for e in errors) , errors;
}
