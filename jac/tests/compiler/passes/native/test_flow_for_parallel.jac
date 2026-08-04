"""Parallel flow for in zero-RC enforced builds (#7857 Phase D).

An --assert-no-rc binary provably contains no refcount operations and no
OSP kernel, and the checker bans every unsound capture from a flow for
body -- so threads are unconditionally safe there. The enforced build
outlines the body, fans element ranges out over pthreads, and joins at
the closing brace; managed modes keep the sequential lowering. Post-join
state is deterministic (disjoint element writes), so output is
byte-identical across thread counts and across gc modes.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures", "flow_for_parallel.jac"
     ),
     EXPECTED = "81313683\nend\n",
     MODE_FLAGS = {
         "none": ["--enforce-nogc", "--gc", "none", "--assert-no-rc"],
         "rc": ["--gc", "rc"],
         "cycles": ["--gc", "cycles"]
     };

def _compile_ir(gc_mode: str, enforce: bool) -> str {
    prog = JacProgram();
    ir = prog.compile(
        file_path=FIXTURE,
        options=CompileOptions(
            aot_mode=True, type_check=True, na_gc_mode=gc_mode, nogc_enforce_all=enforce
        )
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    return str(ir.gen.llvm_ir);
}

test "enforced build fans out over pthreads, managed builds stay sequential" {
    enforced = _compile_ir("none", True);
    assert "pthread_create" in enforced , "no parallel fan-out in enforced build";
    assert "pthread_join" in enforced , "no join in enforced build";
    managed = _compile_ir("rc", False);
    assert "pthread_create" not in managed , "managed build must stay sequential";
}

test "output is byte-identical across gc modes and thread counts" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        bins: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"ffp_{mode}");
            res = subprocess.run(
                [sys.executable, "-m", "jaclang", "nacompile", FIXTURE]
                    + MODE_FLAGS[mode]
                    + ["-o", out_bin],
                capture_output=True,
                text=True
            );
            assert res.returncode == 0 , f"{mode}: {res.stderr}";
            ran = subprocess.run([out_bin], capture_output=True, text=True);
            assert ran.returncode == 0 , f"{mode}: {ran.stderr}";
            outs[mode] = ran.stdout;
            bins[mode] = out_bin;
        }
        assert outs["none"] == EXPECTED , outs["none"];
        assert outs["rc"] == EXPECTED , outs["rc"];
        assert outs["cycles"] == EXPECTED , outs["cycles"];
        for nthreads in ("1", "3", "16") {
            env = dict(os.environ);
            env["JAC_FLOW_THREADS"] = nthreads;
            ran = subprocess.run(
                [bins["none"]], capture_output=True, text=True, env=env
            );
            assert ran.returncode == 0 , f"threads={nthreads}: {ran.stderr}";
            assert ran.stdout == EXPECTED , f"threads={nthreads}: {ran.stdout}";
        }
    }
}
