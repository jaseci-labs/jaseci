"""Cross-file diagnosed-Unknown memo scrub regression guard (#8828).

A `jac check` worker reuses one JacProgram per file, and every dependency the
self-host cache owns is retained in the process-global self-host hub across
files. A diagnosed UnknownType memo written onto a retained module during one
file's check (an unresolvable import, or a transient import-cycle stub) is
returned forever by the memo readers, so the next file inherits a failure
that was never its own. Randomly scheduled file orderings then produce
phantom errors in files a change never touched, which vanish on rerun.

The fix records every diagnosed-Unknown memo the evaluator writes and nulls
exactly those nodes at the end of the check job. This test redirects the
self-host root at a throwaway fixture tree containing a module with an
unresolvable import (a deterministic diagnosed-Unknown writer), runs a real
check job through `_check_file_job`, and asserts the retained dependency
modules carry no diagnosed-Unknown memos afterward, while healthy memos and
the retention surface itself remain.
"""

import os;
import shutil;
import tempfile;

glob FX_A: str = (
         "import from fx.b { BThing }\n\n"
         + "obj AThing {\n    has label: str = \"a\";\n}\n\n"
         + "def get_b -> (BThing | None) {\n    return None;\n}\n"
     ),
     FX_B: str = (
         "import from fx.a { AThing }\n\n"
         + "obj BThing {\n    has n: int = 5;\n}\n\n"
         + "def get_a -> (AThing | None) {\n    return None;\n}\n"
     ),
     FX_M1: str = (
         "import from fx.ghost { GThing }\n\n"
         + "def use_g -> (GThing | None) {\n    return None;\n}\n"
     ),
     FX_D1: str = (
         "import from fx.b { get_a }\n"
         + "import from fx.m1 { use_g }\n\n"
         + "def probe -> str {\n    v = get_a();\n    u = use_g();\n"
         + "    return v.label if v else \"\";\n}\n"
     );

def _run_job(path: str) -> dict {
    import from jaclang.cli.commands.analysis { _check_file_job }
    return _check_file_job(
        {
            "path": path,
            "collect": False,
            "opts": {
                "parse_only": False,
                "native_coverage": False,
                "placements": False,
                "suppress_codes": [],
                "ignore": []
            }
        }
    );
}

def _count_memos(mod: object) -> tuple[int, int] {
    import from jaclang.compiler.types.types { UnknownType }
    total = 0;
    poisoned = 0;
    stack = [mod];
    while stack {
        nd = stack.pop();
        t = nd?.type;
        if t is not None {
            total += 1;
            if isinstance(t, UnknownType) and t.is_diagnosed {
                poisoned += 1;
            }
        }
        for kid in getattr(nd, "kid", []) {
            stack.append(kid);
        }
    }
    return (total, poisoned);
}

test "a diagnosed-Unknown memo does not outlive the check job that wrote it" {
    import from jaclang.runtime.runtime { JacRuntime }
    if os.environ.get("JAC_NO_UNIT_EVICT") {
        return;
    }
    fx_root = tempfile.mkdtemp(prefix="jac_scrub_fx_");
    fx = os.path.join(fx_root, "fx");
    os.makedirs(fx);
    for (name, src) in {
        "a.jac": FX_A,
        "b.jac": FX_B,
        "m1.jac": FX_M1,
        "d1.jac": FX_D1
    }.items() {
        with open(os.path.join(fx, name), "w") as fh {
            fh.write(src);
        }
    }
    sh = JacRuntime.get_selfhost();
    real_root = sh.jaclang_root();
    old_cwd = os.getcwd();
    try {
        sh._jaclang_root = os.path.realpath(fx_root);
        os.chdir(fx_root);
        r1 = _run_job(os.path.join(fx, "d1.jac"));
        assert r1["success"] , f"d1.jac should check clean: {r1['errors']}";

        sp = sh.peek_program();
        assert sp is not None;
        retained = {
            p: m
            for (p, m) in sp.mod.hub.items()
            if (os.sep + "fx" + os.sep) in p
        };
        assert retained , (
            "fixture dependencies were not retained in the self-host hub; "
            + "the leak surface this test guards is gone, update the test"
        );
        poisoned_total = 0;
        for m in retained.values() {
            (_total, poisoned) = _count_memos(m);
            poisoned_total += poisoned;
        }
        assert poisoned_total == 0 , (
            f"{poisoned_total} diagnosed-Unknown memo(s) survived a check "
            + "job on retained self-host modules; they poison every later "
            + "file's verdict (#8828)"
        );

        r2 = _run_job(os.path.join(fx, "d1.jac"));
        assert r2["success"] , f"d1.jac recheck should stay clean: {r2['errors']}";
    } finally {
        sh._jaclang_root = real_root;
        os.chdir(old_cwd);
        shutil.rmtree(fx_root, ignore_errors=True);
    }
}
