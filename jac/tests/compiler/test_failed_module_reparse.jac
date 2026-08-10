"""A module that fails to parse is compiled once, not once per import path.

A failed parse used to be dropped before it reached `program.mod.hub`, so every
path that reached it in one build -- import walk, type checker, placement
solver -- missed the cache, re-parsed, and appended another copy of its alerts
to `errors_had`. The importer is a client module because that is the shape that
pulls in those extra paths.

Duplication *across* builds (6 errors, then 12, then 18 as a dev server
reloads) is covered in tests/runtimelib/test_hmr.jac.
"""

import tempfile;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.program { JacProgram }

glob BROKEN_SRC = 'def broken_repro( -> {{{ SYNTAX ERROR\n',
     FIXED_SRC = 'def:pub broken_repro -> int {\n    return 7;\n}\n',
     CARD_SRC = (
         'import from .broken { broken_repro }\n\n'
         'def:pub card -> JsxElement {\n'
         '    return <div>{broken_repro()}</div>;\n}\n'
     );

# A fresh dir per measurement keeps the on-disk JIR cache cold; a warm one
# serves the failed module from disk and hides the duplication.
def _write_project(base: str) -> Path {
    proj = Path(base);
    proj.mkdir(parents=True, exist_ok=True);
    (proj / "jac.toml").write_text(
        '[project]\nname = "reparse"\nversion = "0.1.0"\n' 'entry-point = "card.jac"\n'
    );
    (proj / "broken.jac").write_text(BROKEN_SRC);
    (proj / "card.jac").write_text(CARD_SRC);
    return proj;
}

def _errors_for(target: str) -> int {
    with tempfile.TemporaryDirectory() as tmp {
        proj = _write_project(tmp);
        prog = JacProgram();
        try {
            prog.compile(str(proj / target));
        } except Exception {
            ;
        }
        return len(prog.errors_had);
    }
}

test "importing a broken module does not multiply its errors" {
    direct = _errors_for("broken.jac");
    assert direct > 1 , "fixture must recover into several alerts to be meaningful";
    via_importer = _errors_for("card.jac");
    assert via_importer == direct , f"client importer reported {via_importer} errors for a {direct}-error failure";
}

test "a recompile still reports its errors to a positional slice reader" {
    with tempfile.TemporaryDirectory() as tmp {
        proj = _write_project(tmp);
        broken = str((proj / "broken.jac").resolve());
        prog = JacProgram();
        try {
            prog.compile(broken);
        } except Exception {
            ;
        }
        # Callers like the client bundle mark the length, compile, then read
        # errors_had[mark:]. Evicting inside a compile empties that slice.
        mark = len(prog.errors_had);
        try {
            prog.compile(broken);
        } except Exception {
            ;
        }
        assert len(prog.errors_had[mark:]) > 0 , "a failed recompile must still surface errors to a mark-and-slice caller";
    }
}

test "a corrected module recompiles on a long-lived program" {
    with tempfile.TemporaryDirectory() as tmp {
        proj = _write_project(tmp);
        broken = proj / "broken.jac";
        prog = JacProgram();
        try {
            prog.compile(str(proj / "card.jac"));
        } except Exception {
            ;
        }
        assert len(prog.errors_had) > 0;
        # No mtime spacing needed: invalidate_module drops the _hub_cache_times
        # stamp, and the on-disk JIR key hashes content rather than mtime.
        broken.write_text(FIXED_SRC);
        prog.errors_had = [];
        prog.invalidate_module(str(broken.resolve()));
        prog.invalidate_module(str((proj / "card.jac").resolve()));
        prog.compile(str(proj / "card.jac"));
        assert len(prog.errors_had) == 0 , f"fixing the file must clear the recorded failure: {prog.errors_had}";
    }
}
