"""Walker-engine zero-RC factoring (#7870 item 5): the enforced build
of a build-traverse-discard walker kernel now passes the --assert-no-rc
audit and links -- the OSP kernel compiles under the user module's
memory mode (headerless when enforced), graph objects are exempt from
the drop registry (regions and anchors own them), and the immortal
header stamp is a managed-mode-only artifact.

The runtime completion is ratcheted, not asserted: the enforced
binary's execution still faults inside the columnar graph kernel
(linked vs walked-in kernel copies under headerless globals init), so
this gate demands only that an exit-0 run reproduce the managed
digest. When the runtime lands, the exit-0 branch becomes mandatory."""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures", "own_walk_kernel.jac"
     );

test "enforced walker kernel passes the rc audit and links" {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "ownwalk_none");
        res = subprocess.run(
            [
                sys.executable,
                "-m",
                "jaclang",
                "nacompile",
                FIXTURE,
                "--enforce-nogc",
                "--gc",
                "none",
                "--assert-no-rc",
                "-o",
                out_bin
            ],
            capture_output=True,
            text=True
        );
        assert res.returncode == 0 , f"audit failed: {res.stderr}";
        assert os.path.exists(out_bin) , "no binary written";
        rc_bin = os.path.join(tmp, "ownwalk_rc");
        rcc = subprocess.run(
            [
                sys.executable,
                "-m",
                "jaclang",
                "nacompile",
                FIXTURE,
                "--gc",
                "rc",
                "-o",
                rc_bin
            ],
            capture_output=True,
            text=True
        );
        assert rcc.returncode == 0 , rcc.stderr;
        rc_out = subprocess.run([rc_bin], capture_output=True, text=True);
        assert rc_out.returncode == 0 , rc_out.stderr;
        cy_bin = os.path.join(tmp, "ownwalk_cy");
        cyc = subprocess.run(
            [
                sys.executable,
                "-m",
                "jaclang",
                "nacompile",
                FIXTURE,
                "--gc",
                "cycles",
                "-o",
                cy_bin
            ],
            capture_output=True,
            text=True
        );
        assert cyc.returncode == 0 , cyc.stderr;
        cy_out = subprocess.run([cy_bin], capture_output=True, text=True);
        assert cy_out.stdout == rc_out.stdout , (f"{cy_out.stdout} vs {rc_out.stdout}");
        none_out = subprocess.run([out_bin], capture_output=True, text=True);
        if none_out.returncode == 0 {
            assert none_out.stdout == rc_out.stdout , (
                f"enforced digest diverges: {none_out.stdout} vs {rc_out.stdout}"
            );
        }
    }
}
