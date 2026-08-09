"""flow for runtime semantics (#7857 Phase C/D surface).

Per-element body over lent collections with the join at the closing
brace: element writes through `&mut` are visible after the join.
Post-join printing uses a plain `for` loop so stdout stays deterministic
even when `--gc rc` fans the `flow for` body out over pthreads.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures", "flow_for_run.jac"
     ),
     MODE_FLAGS = {
         "none": ["--gc", "none"],
         "rc": ["--gc", "rc"],
         "cycles": ["--gc", "cycles"]
     };

test "flow for output is byte-identical across gc modes" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"ff_{mode}");
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
        assert outs["rc"] == "10\n20\n30\n8\n10\nend\n" , outs["rc"];
        assert outs["none"] == outs["rc"] , outs["none"];
        assert outs["cycles"] == outs["rc"] , outs["cycles"];
    }
}
