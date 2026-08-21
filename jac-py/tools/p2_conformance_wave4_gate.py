"""P2 wave-4 conformance manifest gate."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_MANIFEST = _REPO / "jac-py" / "tests" / "conformance_manifest_wave4.json"
_CORPUS = _HERE / "p2_corpus_wave4" / "manifest.json"
_STAGED = _HERE / "p2_staged_manifest_wave4.json"

_ALLOWED_GATE_TYPES = frozenset({"oracle", "libtest", "deferred"})


class P2ConformanceWave4GateTests(unittest.TestCase):
    def test_manifest_module_count_matches_corpus(self) -> None:
        manifest = json.loads(_MANIFEST.read_text(encoding="utf-8"))
        corpus = json.loads(_CORPUS.read_text(encoding="utf-8"))
        self.assertEqual(manifest["module_count"], len(corpus["files"]))
        self.assertEqual(len(manifest["modules"]), len(corpus["files"]))

    def test_manifest_stems_match_corpus(self) -> None:
        manifest = json.loads(_MANIFEST.read_text(encoding="utf-8"))
        corpus = json.loads(_CORPUS.read_text(encoding="utf-8"))
        manifest_stems = {row["stem"] for row in manifest["modules"]}
        corpus_stems = {row["stem"] for row in corpus["files"]}
        self.assertEqual(manifest_stems, corpus_stems)

    def test_staged_manifest_covers_corpus(self) -> None:
        staged = json.loads(_STAGED.read_text(encoding="utf-8"))
        corpus = json.loads(_CORPUS.read_text(encoding="utf-8"))
        staged_stems = {row["stem"] for row in staged["modules"]}
        corpus_stems = {row["stem"] for row in corpus["files"]}
        self.assertEqual(staged_stems, corpus_stems)

    def test_all_modules_gated(self) -> None:
        manifest = json.loads(_MANIFEST.read_text(encoding="utf-8"))
        for row in manifest["modules"]:
            self.assertEqual(row.get("status"), "gated", row)
            self.assertIn(row.get("gate_type"), _ALLOWED_GATE_TYPES, row)
            self.assertTrue(row.get("oracle_tests"), f"{row['stem']}: missing oracle_tests")

    def test_oracle_modules_have_staged_jac(self) -> None:
        manifest = json.loads(_MANIFEST.read_text(encoding="utf-8"))
        modules_dir = _REPO / "jac-py" / "Modules"
        for row in manifest["modules"]:
            if row.get("gate_type") != "oracle":
                continue
            path = modules_dir / f"{row['stem']}.jac"
            self.assertTrue(path.is_file(), f"missing staged oracle {path}")


if __name__ == "__main__":
    unittest.main()
