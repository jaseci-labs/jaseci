"""P3 object-core Layer-0/1 corpus ratchet driver (TODO.md P3.1a/P3.1b).

Runs ``layer0_replay_p3_gate.jac`` via ``jac run`` so corpus counts are taken on
a clean ceval slate (``jac test`` would collect pyc_first.jac's regression tests
through the replay harness import graph first).
"""

from __future__ import annotations

import os
import subprocess
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
GATE_JAC = REPO_ROOT / "jac-py" / "jacpython" / "layer0_replay_p3_gate.jac"
JAC_BIN = REPO_ROOT / ".venv" / "bin" / "jac"


class P3ReplayGate(unittest.TestCase):
    def test_layer0_layer1_corpus_ratchet(self) -> None:
        env = os.environ.copy()
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
        self.assertIn("P3 corpus ratchet: Layer-0/1 baselines OK", proc.stdout)


if __name__ == "__main__":
    unittest.main()
