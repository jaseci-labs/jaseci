"""The jac0 seed tier and the full compiler agree on the object-spatial subset.

`jaclang/jac0.py` lowers node/edge/walker declarations, `+>:T:+>`, `[x ->:T:->]`,
`spawn`, `visit`, `disengage`, `del` and `can f with T entry|exit` onto
`jaclang.jac0core.osp0`, which reaches the same runtime statics the full
compiler's codegen targets. This fixture exercises every construct in that
subset under both compilers and compares what they compute.
"""

import os;
import sys;
import types;
import from jaclang.jac0 { compile_jac }
import from tests.compiler.fixtures.jac0_osp_subset { run as full_run }


def _jac0_run -> tuple[int, list[str], int, int, int, int, int] {
    path = os.path.join(os.path.dirname(__file__), "fixtures", "jac0_osp_subset.jac");
    with open(path, encoding="utf-8") as f {
        src = f.read();
    }
    py = compile_jac(src, path);
    mod = types.ModuleType("jac0_osp_subset_seed");
    mod.__file__ = path;
    sys.modules[mod.__name__] = mod;
    try {
        exec(compile(py, path, "exec"), mod.__dict__);
        return mod.run();
    } finally {
        sys.modules.pop(mod.__name__, None);
    }
}


test "jac0 lowers the object-spatial seed subset to the full compiler's semantics" {
    expected = (
        6,
        ["enter:top", "enter:a", "enter:b", "exit:b", "exit:a", "exit:top", "done"],
        2,
        1,
        2,
        2,
        1,

    );
    assert full_run() == expected;
    assert _jac0_run() == expected;
}


test "jac0 refuses object-spatial forms outside the seed subset" {
    for src in [
        "def f(a: any, b: any, c: any) { a ++> b ++> c; }",
        "def f(a: any) -> list { return [a ->:T:-> (?x == 1)]; }",

    ] {
        failed = False;
        try {
            compile_jac(src, "probe.jac");
        } except Exception {
            failed = True;
        }
        assert failed , src;
    }
}
