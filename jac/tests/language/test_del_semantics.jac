"""`del` semantics, per issue #8756.

Three layers: the fixture that pins every `del` form's graph and container
effect, a differential harness that replays the Python-legal forms through
CPython and asserts Jac agrees, and the backend-parity checks.
"""

import io;
import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { JAC_ROOT }

glob FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures"),
     DEL_SEMANTICS = os.path.join(FIXTURES, "del_semantics.jac");

"""Run a .jac file in a subprocess and return (stdout, stderr, returncode)."""
def run_jac_file(path: str) -> tuple[str, str, int] {
    result = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", path],
        capture_output=True,
        text=True,
        cwd=JAC_ROOT
    );
    return (result.stdout, result.stderr, result.returncode);
}

"""Write `src` to a temp .jac file, run it, and return (stdout, stderr, rc)."""
def run_jac_src(src: str) -> tuple[str, str, int] {
    fd_path = tempfile.mkstemp(suffix=".jac", prefix="del_sem_");
    os.close(fd_path[0]);
    path = fd_path[1];
    try {
        with open(path, "w") as f {
            f.write(src);
        }
        return run_jac_file(path);
    } finally {
        os.unlink(path);
    }
}

test "del semantics fixture" {
    (out, err, rc) = run_jac_file(DEL_SEMANTICS);
    assert rc == 0 , f"fixture failed:\n{err}";
    assert "del semantics: all cases ok" in out , out;
}

# ---------------------------------------------------------------------------
# Differential harness: every Python-legal `del` form must observably agree
# with CPython. The body of each case is one source text shared verbatim by
# both languages; only the import prelude and the `with entry` wrapper differ.
# ---------------------------------------------------------------------------
obj DelCase {
    has name: str,
        body: str,
        probe: str,
        py_prelude: str = "",
        jac_prelude: str = "",
        # Non-empty while Jac still disagrees with CPython on this case. DS0
        # pins the disagreement so the fix shows up as a diff here; the entry
        # is deleted by the tracker item that closes it.
        today: str = "";
}

glob NS_PY = "from types import SimpleNamespace",
     NS_JAC = "import from types { SimpleNamespace }";

glob DEL_CASES: list[DelCase] = [
         DelCase(
             name="dict delitem",
             body='d = {"k": 1, "j": 2};\ndel d["k"];',
             probe="sorted(d.items())"
         ),
         DelCase(name="list delitem", body="L = [1, 2, 3];\ndel L[0];", probe="L"),
         # DS3: native lowers `del L[i:j]` to a single `del_at(i)`.
         DelCase(
             name="list slice",
             body="L = [1, 2, 3];\ndel L[0:2];",
             probe="L",
             today="[2, 3]\n"
         ),
         # DS3: native drops `del L[::2]` on the floor.
         DelCase(
             name="list strided slice",
             body="L = [1, 2, 3, 4, 5];\ndel L[::2];",
             probe="L",
             today="[1, 2, 3, 4, 5]\n"
         ),
         DelCase(
             name="nested delitem", body="L = [[1, 2, 3]];\ndel L[0][1];", probe="L"
         ),
         DelCase(
             name="delattr",
             body="o = SimpleNamespace(x=1, y=2);\ndel o.x;",
             probe="sorted(vars(o).items())",
             py_prelude=NS_PY,
             jac_prelude=NS_JAC
         ),
         DelCase(
             name="tuple target",
             body="a = 1;\nb = 2;\ndel (a, b);",
             probe='("a" in globals(), "b" in globals())'
         ),
         DelCase(
             name="list target",
             body="a = 1;\nb = 2;\ndel [a, b];",
             probe='("a" in globals(), "b" in globals())'
         ),
         DelCase(name="bare name", body="x = 1;\ndel x;", probe='"x" in globals()'),
         # DS3: native has no arm for a tuple target, so the statement vanishes.
         DelCase(
             name="single element tuple target",
             body='d = {"k": 1, "j": 2};\ndel (d["k"], );',
             probe="sorted(d.items())",
             today="[('k', 1), ('j', 2)]\n"
         ),
         DelCase(
             name="mixed comma targets",
             body='o = SimpleNamespace(x=1, y=2);\nd = {"k": 1, "j": 2};\na = 1;\n'
             'del o.x, d["k"], a;',
             probe='(sorted(vars(o).items()), sorted(d.items()), "a" in globals())',
             py_prelude=NS_PY,
             jac_prelude=NS_JAC
         ),
         DelCase(
             name="mixed list target",
             body='o = SimpleNamespace(x=1, y=2);\nd = {"k": 1, "j": 2};\n'
             'del [d["k"], o.x];',
             probe="(sorted(vars(o).items()), sorted(d.items()))",
             py_prelude=NS_PY,
             jac_prelude=NS_JAC
         )
     ];

"""Run a snippet through CPython and return its stdout."""
def run_py_src(src: str) -> str {
    old = sys.stdout;
    buf = io.StringIO();
    sys.stdout = buf;
    try {
        exec(compile(src, "<del_case>", "exec"), {});
    } finally {
        sys.stdout = old;
    }
    return buf.getvalue();
}

test "del agrees with CPython on every Python-legal target" {
    for dc in DEL_CASES {
        py_src = f"{dc.py_prelude}\n{dc.body}\nprint({dc.probe})\n";
        jac_src = f"{dc.jac_prelude}\nwith entry {{\n{dc.body}\n"
        f"print({dc.probe});\n}}\n";
        expected = run_py_src(py_src);
        (out, err, rc) = run_jac_src(jac_src);
        assert rc == 0 , f"[{dc.name}] jac run failed:\n{jac_src}\n{err}";
        if dc.today {
            assert out == dc.today , f"[{dc.name}] jac {out!r} != pinned {dc.today!r}\n{jac_src}";
            assert out != expected , f"[{dc.name}] now agrees; drop today";
            continue;
        }
        assert out == expected , f"[{dc.name}] jac {out!r} != cpython {expected!r}\n{jac_src}";
    }
}

# ---------------------------------------------------------------------------
# Front-end diagnostics: a malformed `del` target is caught with a location and
# a fix hint, instead of surfacing as E5043 from bytecode generation with the
# module's first line as its span.
# ---------------------------------------------------------------------------
glob BAD_TARGETS = os.path.join(FIXTURES, "del_bad_targets.jac");

"""Run `jac check` on a .jac file and return its combined output."""
def run_jac_check(path: str) -> str {
    result = subprocess.run(
        [sys.executable, "-m", "jaclang", "check", path],
        capture_output=True,
        text=True,
        cwd=JAC_ROOT
    );
    return result.stdout + result.stderr;
}

test "malformed del targets are rejected by the front end" {
    out = run_jac_check(BAD_TARGETS);
    assert out.count("error[E0083]") == 5 , out;
    assert "E5043" not in out , out;
    assert "Cannot delete a literal" in out , out;
    assert "Cannot delete an empty target list" in out , out;
    assert "Cannot delete a null-safe access" in out , out;
}

test "a del value target that can never be a graph object warns" {
    out = run_jac_check(BAD_TARGETS);
    assert out.count("warning[W1053]") == 1 , out;
    assert "destroys nothing" in out , out;
}

test "well formed del statements never reach E5043" {
    out = run_jac_check(DEL_SEMANTICS);
    assert "E5043" not in out , out;
    assert "E0083" not in out , out;
}
