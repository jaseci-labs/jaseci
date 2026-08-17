"""RED: constructing over a Python-side base whose postinit runs is hollow.

Pinning the defect of #8301 before it is fixed. The native lane lowers
the construction to a `_pyb_instantiate` bridge whose result is
immediately dropped; the Python base's `__post_init__` then runs on that
discarded shadow, where neither the subclass's native slots nor its
method overrides exist. The subsequent field read comes back as the
slot's declared default, and nothing is diagnosed.

Both lanes are compared because a hollow object is still well typed and
still compiles: only the value catches it.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_force_opts }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.jac0core.codeinfo {
    get_effective_default_codespace_override,
    set_effective_default_codespace
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     ),
     GEN = "pyb_hollow_gen_main.jac",
     PLAIN = "pyb_hollow_plain_main.jac";


def _compiled(fixture: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    diags = [
        d.pretty_print()
        for d in (prog.errors_had or [])
    ];
    return (ir, diags, );
}


def _native_read_back(fixture: str) -> int {
    (ir, _diags) = _compiled(fixture);
    eng = ir.gen.native_engine;
    assert eng is not None , f"no native engine for {fixture}";
    addr = eng.get_function_address("read_back");
    assert addr != 0 , f"read_back was not emitted for {fixture}";
    return ctypes.CFUNCTYPE(ctypes.c_int64)(addr)();
}


def _sv_read_back(fixture: str) -> int {
    prev = get_effective_default_codespace_override();
    set_effective_default_codespace("server");
    try {
        mods = JacRuntime.jac_import(
            target=fixture[:-4], base_path=FIXTURES, reload_module=True
        );
    } finally {
        set_effective_default_codespace(prev);
    }
    assert mods , f"sv import of {fixture} produced no module";
    return mods[0].read_back();
}


test "RED: the generic pass-shaped chain reads back its declared default" {
    assert _sv_read_back(GEN) == 103 , "the sv lane runs the override";
    assert _native_read_back(GEN) == 5 , (
        "if this now answers 103 the construction was fixed; if it "
        "refuses, the refusal landed and this file should assert it"
    );
}


test "RED: the non-generic control is hollow too, so genericity is not it" {
    assert _sv_read_back(PLAIN) == 103 , "the sv lane runs the override";
    assert _native_read_back(PLAIN) == 5 , (
        "the same wrong answer with no type parameter anywhere"
    );
}


test "RED: neither hollow construction says anything at all" {
    for fixture in (GEN, PLAIN, ) {
        (_ir, diags) = _compiled(fixture);
        assert not diags , (
            f"{fixture} now diagnoses its hollow construction: {diags}"
        );
    }
}
