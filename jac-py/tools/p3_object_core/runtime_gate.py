"""P3 object-core runtime parity driver (TODO.md item 5 / FIXME M11).

Runs ``layer0_replay_p3_runtime_gate.jac`` via ``jac run`` so Layer-1 replay
probes execute on a clean ceval slate.
"""

from __future__ import annotations

import os
import subprocess
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
GATE_JAC = REPO_ROOT / "jac-py" / "jacpython" / "layer0_replay_p3_runtime_gate.jac"
JAC_BIN = REPO_ROOT / ".venv" / "bin" / "jac"


class P3RuntimeGate(unittest.TestCase):
    def test_runtime_probes_match_cpython(self) -> None:
        env = os.environ.copy()
        jac_src = REPO_ROOT / "jac"
        existing = env.get("PYTHONPATH", "")
        if str(jac_src) not in existing.split(os.pathsep):
            env["PYTHONPATH"] = (
                str(jac_src) if not existing else f"{jac_src}{os.pathsep}{existing}"
            )
        env["JAC_DEV_SOURCE"] = str(jac_src)
        cpython = env.get("JACPYTHON_CPYTHON")
        if not cpython:
            self.skipTest("JACPYTHON_CPYTHON not set")
        proc = subprocess.run(
            [str(JAC_BIN), "run", str(GATE_JAC)],
            cwd=REPO_ROOT,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
        detail = (proc.stderr or proc.stdout or "jac run failed").strip()
        self.assertEqual(
            proc.returncode,
            0,
            msg=detail,
        )
        self.assertIn("P3 runtime probes: all stems OK", proc.stdout)


if __name__ == "__main__":
    unittest.main()
