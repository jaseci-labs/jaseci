"""Sub-arena partition + reabsorb (#7857 Phase D).

`r.partition()` yields an owned child handle; a child's death reabsorbs
its chunks and dtor log into the parent (drops fire once, at the
parent's death, child entries first), and a parent dying before its
children defers teardown to the last reabsorb (zombie parent). Output is
byte-identical across gc modes.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures", "region_partition.jac"
     ),
     MODE_FLAGS = {
         "none": ["--gc", "none"],
         "rc": ["--gc", "rc"],
         "cycles": ["--gc", "cycles"]
     };

test "partition reabsorb and zombie teardown across gc modes" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"part_{mode}");
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
        lines = outs["rc"].split("\n");
        _mid = lines.index("mid");
        _head = lines[:_mid];
        assert _head[:3] == ["0", "1", "2"] , outs["rc"];
        assert sorted(_head[3:]) == ["drop 0", "drop 1", "drop 2"] , outs["rc"];
        _tail = lines[_mid + 1:];
        assert _tail[:3] == ["8", "9", "before-c-drop"] , outs["rc"];
        assert _tail[3:5] == ["drop 9", "drop 8"] , outs["rc"];
        assert _tail[5:] == ["end", ""] , outs["rc"];
        assert outs["none"] == outs["rc"] , outs["none"];
        assert outs["cycles"] == outs["rc"] , outs["cycles"];
    }
}
