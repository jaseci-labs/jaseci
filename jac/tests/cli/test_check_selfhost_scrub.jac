"""Cross-file type-memo scrub regression guard (#8828).

A `jac check` worker reuses one JacProgram for every file it serves, and every
dependency the self-host cache owns is retained in the process-global self-host
hub across files. The `.type` memos written onto those retained modules by one
file's evaluator are unsound for the next file's evaluator: a diagnosed
UnknownType memo is returned forever once written, and a ModuleType memo can
point at a module object the hub has since replaced. Randomly scheduled file
orderings then produce phantom E1032/E1053/E1099 errors in files a change never
touched, which vanish on rerun.

The fix scrubs the self-host program's type memos at the end of every check
job. This test redirects the self-host root at a throwaway fixture tree, runs
real check jobs through `_check_file_job`, and asserts that dependency modules
are retained (the leak surface exists) while their type memos are not.
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
     FX_D: str = (
         "import from fx.b { get_a }\n\n"
         + "def probe -> str {\n    v = get_a();\n"
         + "    return v.label if v else \"\";\n}\n"
     ),
     FX_E: str = (
         "import from fx.a { get_b }\n\n"
         + "def probe2 -> int {\n    v = get_b();\n"
         + "    return v.n if v else 0;\n}\n"
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

def _count_memos(mod: object) -> int {
    count = 0;
    stack = [mod];
    while stack {
        nd = stack.pop();
        for attr in ("type", "narrowed_type", "coerce_to") {
            if getattr(nd, attr, None) is not None {
                count += 1;
            }
        }
        for kid in getattr(nd, "kid", []) {
            stack.append(kid);
        }
    }
    return count;
}

test "check jobs leave no type memos on retained self-host dependencies" {
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
        "d.jac": FX_D,
        "e.jac": FX_E
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
        r1 = _run_job(os.path.join(fx, "d.jac"));
        assert r1["success"] , f"d.jac should check clean: {r1['errors']}";

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
        leaked = 0;
        for m in retained.values() {
            leaked += _count_memos(m);
        }
        assert leaked == 0 , (
            f"{leaked} type memo(s) survived a check job on retained "
            + "self-host modules; stale memos poison later files (#8828)"
        );

        r2 = _run_job(os.path.join(fx, "e.jac"));
        assert r2["success"] , f"e.jac should check clean: {r2['errors']}";
    } finally {
        sh._jaclang_root = real_root;
        os.chdir(old_cwd);
        shutil.rmtree(fx_root, ignore_errors=True);
    }
}
