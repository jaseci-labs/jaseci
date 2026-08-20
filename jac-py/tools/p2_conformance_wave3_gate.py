"""P2 wave-3 conformance manifest gate."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_MANIFEST = _REPO / "jac-py" / "tests" / "conformance_manifest_wave3.json"
_CORPUS = _HERE / "p2_corpus_wave3" / "manifest.json"
_EXPECTED_COUNT = 4
_ALLOWED_GATE_TYPES = frozenset({"oracle", "libtest", "deferred"})


class P2ConformanceWave3GateTests(unittest.TestCase):
    def test_corpus_manifest_has_four_modules(self) -> None:
        corpus = json.loads(_CORPUS.read_text(encoding="utf-8"))
        self.assertEqual(len(corpus.get("files", [])), _EXPECTED_COUNT)

    def test_conformance_manifest_lists_four_gated_modules(self) -> None:
        manifest = json.loads(_MANIFEST.read_text(encoding="utf-8"))
        modules = manifest.get("modules", [])
        self.assertEqual(len(modules), _EXPECTED_COUNT, manifest)
        self.assertEqual(manifest.get("module_count"), _EXPECTED_COUNT)

        corpus = json.loads(_CORPUS.read_text(encoding="utf-8"))
        expected_stems = {row["stem"] for row in corpus["files"]}
        seen_stems: set[str] = set()

        for row in modules:
            stem = row["stem"]
            seen_stems.add(stem)
            self.assertIn(row.get("gate_type"), _ALLOWED_GATE_TYPES, stem)
            self.assertEqual(row.get("status"), "gated", stem)

        self.assertEqual(seen_stems, expected_stems)


if __name__ == "__main__":
    unittest.main()
