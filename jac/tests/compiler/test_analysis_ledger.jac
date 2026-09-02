"""The analysis ledger never inherits marks across module identities.

`AnalysisCaches.analyses_run` is keyed by `id(module)`. A pooled `jac check`
worker keeps one program alive across hundreds of files and releases each
file's compile closure in between, so CPython hands freed addresses to later
modules. A stale "TypeOf" mark under a reused id would make the compiler skip
that module's whole analysis schedule. Entries therefore carry a weak
reference to their module, a lookup under a reused id is a miss, and closure
release purges dead entries.
"""
import gc;
import os;
import tempfile;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }

glob SRC: str = "def area(r: float) -> float { return 3.14 * r * r; }\n";

obj Marker {}

def _write(dirname: str) -> str {
    path = os.path.join(dirname, "ledger_probe.jac");
    with open(path, "w", encoding="utf-8") as f {
        f.write(SRC);
    }
    return path;
}

test "a reused object id never inherits a dead module's analysis marks" {
    prog = JacProgram();
    collided = False;
    for _ in range(50) {
        first = Marker();
        prog.analysis.ledger_of(first).add("TypeOf");
        dead_id = id(first);
        del first;
        gc.collect();
        second = Marker();
        if id(second) == dead_id {
            collided = True;
            assert prog.analysis.provided_of(second) == set() , (
                "a fresh object inherited the dead module's marks"
            );
            assert "TypeOf" not in prog.analysis.ledger_of(second);
        }
        del second;
    }
    assert collided , "CPython never reused the address, so the guard was not exercised";
}

test "release_compile_closure purges ledger entries of freed modules" {
    with tempfile.TemporaryDirectory() as d {
        prog = JacProgram();
        mod = prog.compile(file_path=_write(d), options=CompileOptions(no_cgen=True));
        assert "TypeOf" in prog.analysis.provided_of(mod);
        dead_id = id(mod);
        del mod;
        prog.release_compile_closure();
        dead = [
            key
            for (key, ent) in prog.analysis.analyses_run.items()
            if ent[0]() is None
        ];
        assert not dead , f"stale ledger entries survived release: {dead}";
        stale = prog.analysis.analyses_run.get(dead_id);
        assert stale is None or stale[0]() is not None;
    }
}

test "the next item after a release runs its own analysis schedule" {
    with tempfile.TemporaryDirectory() as d {
        first_path = _write(d);
        second_path = os.path.join(d, "ledger_probe_two.jac");
        with open(second_path, "w", encoding="utf-8") as f {
            f.write("def twice(n: int) -> int { return n * 2; }\n");
        }
        prog = JacProgram();
        opts = CompileOptions(no_cgen=True, force_target_program=True);
        first = prog.compile(file_path=first_path, options=opts);
        assert "TypeOf" in prog.analysis.provided_of(first);
        runs_after_first = sum(prog.analysis.pass_runs.values());
        prog.release_compile_closure();
        second = prog.compile(file_path=second_path, options=opts);
        assert "TypeOf" in prog.analysis.provided_of(second);
        assert sum(prog.analysis.pass_runs.values()) > runs_after_first , (
            "the second item skipped its analysis schedule"
        );
    }
}
