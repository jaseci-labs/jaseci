"""Step-4 gate of the fat-descriptor migration (#7870): under managed
modes a string slice is a zero-copy view -- a descriptor whose data
points into the parent with the root retained -- with no per-slice
allocation; headerless builds keep the copying slice until the
derivation-subset rules land. Behavior byte-identical across modes."""

import os;
import re;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures", "str_slice_views.jac"
     ),
     MODE_FLAGS = {
         "none": ["--enforce-nogc", "--gc", "none", "--assert-no-rc"],
         "rc": ["--gc", "rc"],
         "cycles": ["--gc", "cycles"]
     };

def _probe_fn_ir(gc_mode: str, enforce: bool) -> str {
    prog = JacProgram();
    ir = prog.compile(
        file_path=FIXTURE,
        options=CompileOptions(
            aot_mode=True, type_check=True, na_gc_mode=gc_mode, nogc_enforce_all=enforce
        )
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    text = str(ir.gen.llvm_ir);
    m = re.search(r'define[^\n]*@"?probe"?\([^\n]*\n(.*?)\n\}', text, re.DOTALL);
    assert m , "probe fn not found in IR";
    return m.group(1);
}

test "managed slices are allocation-free views" {
    body = _probe_fn_ir("rc", False);
    assert "s.view" in body , "no view construction in managed slice";
    assert "__rc_alloc" not in body , "managed slice still allocates";
}

test "slice-view output is byte-identical across gc modes" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"zc_{mode}");
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
        }
        assert outs["rc"].endswith("end\n") , outs["rc"];
        assert outs["none"] == outs["rc"] , f"{outs['none']} vs {outs['rc']}";
        assert outs["cycles"] == outs["rc"] , outs["cycles"];
    }
}
