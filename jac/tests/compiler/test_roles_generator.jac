"""The generated role accessors and constructors stay current.

`scripts/gen_roles.py` derives `unitree.impl/roles.impl.jac` from the node
declarations in `unitree.jac` and the slot table in `roles.jac`; a change to
either without regenerating leaves accessors that read the wrong edges.
"""

import os;
import subprocess;
import sys;
import from tests.support { JAC_ROOT }


test "roles.impl.jac matches scripts/gen_roles.py" {
    script = os.path.join(os.path.dirname(JAC_ROOT), "scripts", "gen_roles.py");
    if not os.path.isfile(script) {
        testskip("repo checkout only: scripts/gen_roles.py not present");
    }
    proc = subprocess.run(
        [sys.executable, "-I", script, "--check"], capture_output=True, text=True, timeout=120,
    );
    assert proc.returncode == 0 , (
        f"gen_roles.py --check failed (exit {proc.returncode}):\n{proc.stdout}\n{proc.stderr}"
    );
}
