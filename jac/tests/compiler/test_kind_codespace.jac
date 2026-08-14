"""Tests for kind-derived codespace: [project] kind feeds module placement (#8034).

A js-package project has no server, so every module compiles to the client
codespace by construction -- bare compiles (jac tool jac2js, check, langserve)
must agree with `jac build --as npm` instead of running full-stack inference
that silently drops evidence-free `pub` exports server-side.

The fixture is copied into a throwaway project per test: the kind under test
lives in a generated jac.toml beside it, and compiling it in place would
resolve the repo's own manifest instead.
"""

import os;
import shutil;
import tempfile;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.placement_pins { config_kind_space }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURE = os.path.join(
         JAC_ROOT, "tests", "compiler", "fixtures", "codespace", "kind_pub_exports.jac"
     );


def _project(tmpdir: str, kind: str) -> str {
    kind_line = f"kind = \"{kind}\"\n" if kind else "";
    with open(os.path.join(tmpdir, "jac.toml"), "w") as f {
        f.write("[project]\nname = \"probe\"\n" + kind_line);
    }
    return shutil.copy(FIXTURE, os.path.join(tmpdir, "lib.jac"));
}


test "js-package kind resolves to the client codespace" {
    with tempfile.TemporaryDirectory() as tmpdir {
        lib = _project(tmpdir, "js-package");
        assert config_kind_space(lib) == "client";
    }
}


test "kinds without a declared codespace resolve to nothing" {
    for kind in ["cli", "web-app", "", "not-a-kind"] {
        with tempfile.TemporaryDirectory() as tmpdir {
            assert config_kind_space(_project(tmpdir, kind)) == "";
        }
    }
}


test "js-package bare compile emits every pub export" {
    with tempfile.TemporaryDirectory() as tmpdir {
        lib = _project(tmpdir, "js-package");
        prog = JacProgram();
        mod = prog.compile(lib);
        assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
        js = mod.gen.js or "";
        assert "function activate" in js;
        assert "function deactivate" in js , (
            "evidence-free pub export must not be dropped in a serverless project"
        );
        assert "deactivate" in js.split("export")[-1];
        assert "__jacEndpointEffects__" not in js , (
            "a js-package project has no server to serve endpoints"
        );
    }
}


test "full-stack inference is unchanged for kinds with a server" {
    with tempfile.TemporaryDirectory() as tmpdir {
        lib = _project(tmpdir, "web-app");
        prog = JacProgram();
        mod = prog.compile(lib);
        assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
        js = mod.gen.js or "";
        assert "function activate" in js;
        assert "function deactivate" not in js , (
            "evidence-free pub in a full-stack project stays a server endpoint"
        );
    }
}
