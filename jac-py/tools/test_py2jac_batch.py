"""Unit tests for T5 py2jac batch mode (jac-py/PLAN.md §6.5)."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from py2jac_batch import (
    build_module_index,
    default_converter,
    discover_files,
    extract_deps,
    module_of,
    order_files,
    run_batch,
)


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _statuses(report: dict) -> dict[str, str]:
    return {row["source"]: row["status"] for row in report["files"]}


class TestModuleIndex(unittest.TestCase):
    def test_module_names(self) -> None:
        self.assertEqual(module_of(Path("a/b/mod.py")), "a.b.mod")
        self.assertEqual(module_of(Path("a/b/__init__.py")), "a.b")
        self.assertEqual(module_of(Path("top.py")), "top")

    def test_index(self) -> None:
        idx = build_module_index([Path("pkg/__init__.py"), Path("pkg/m.py")])
        self.assertEqual(set(idx), {"pkg", "pkg.m"})


class TestImportGraph(unittest.TestCase):
    def test_absolute_import_edges(self) -> None:
        root = Path(tempfile.mkdtemp())
        _write(root / "pkg" / "__init__.py", "")
        _write(root / "pkg" / "a.py", "from pkg.b import THING\n")
        _write(root / "pkg" / "b.py", "THING: int = 1\n")
        files = discover_files(root, [], [], [])
        index = {
            k: root / v
            for k, v in build_module_index(
                [f.relative_to(root) for f in files]
            ).items()
        }
        a = root / "pkg" / "a.py"
        self.assertEqual(
            extract_deps(a, index, "pkg.a"),
            [root / "pkg" / "__init__.py", root / "pkg" / "b.py"],
        )

    def test_relative_import_edges(self) -> None:
        root = Path(tempfile.mkdtemp())
        _write(root / "pkg" / "__init__.py", "")
        _write(root / "pkg" / "a.py", "from . import b\n")
        _write(root / "pkg" / "b.py", "X: int = 1\n")
        _write(root / "pkg" / "c.py", "from .b import X\n")
        files = discover_files(root, [], [], [])
        index = {
            k: root / v
            for k, v in build_module_index(
                [f.relative_to(root) for f in files]
            ).items()
        }
        a = root / "pkg" / "a.py"
        c = root / "pkg" / "c.py"
        self.assertIn(root / "pkg" / "b.py", extract_deps(a, index, "pkg.a"))
        self.assertIn(root / "pkg" / "b.py", extract_deps(c, index, "pkg.c"))

    def test_chain_edges(self) -> None:
        root = Path(tempfile.mkdtemp())
        _write(root / "c.py", "VALUE: int = 3\n")
        _write(root / "b.py", "from c import VALUE\nX: int = VALUE + 1\n")
        _write(root / "a.py", "import b\nY: int = b.X + 1\n")
        files = discover_files(root, [], [], [])
        index = {k: root / v for k, v in build_module_index(
            [f.relative_to(root) for f in files]
        ).items()}
        deps = {
            f: extract_deps(f, index, module_of(f.relative_to(root)))
            for f in files
        }
        a, b, c = root / "a.py", root / "b.py", root / "c.py"
        self.assertEqual(deps[a], [b])
        self.assertEqual(deps[b], [c])
        self.assertEqual(deps[c], [])

        groups = order_files(files, deps)
        flat = [f.name for g in groups for f in g]
        self.assertEqual(sorted(flat), ["a.py", "b.py", "c.py"])
        pos = {name: i for i, name in enumerate(flat)}
        self.assertLess(pos["c.py"], pos["b.py"])
        self.assertLess(pos["b.py"], pos["a.py"])

    def test_cycle_is_one_scc(self) -> None:
        root = Path(tempfile.mkdtemp())
        _write(root / "p.py", "import q\nA: int = 1\n")
        _write(root / "q.py", "import p\nB: int = 2\n")
        files = discover_files(root, [], [], [])
        index = {
            k: root / v
            for k, v in build_module_index(
                [f.relative_to(root) for f in files]
            ).items()
        }
        deps = {
            f: extract_deps(f, index, module_of(f.relative_to(root)))
            for f in files
        }
        groups = order_files(files, deps)
        self.assertEqual(len(groups), 1)
        self.assertEqual({f.name for f in groups[0]}, {"p.py", "q.py"})


class TestDiscoverFilters(unittest.TestCase):
    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())
        _write(self.root / "keep.py", "x: int = 1\n")
        _write(self.root / "skip_me.py", "y: int = 2\n")
        _write(self.root / "__pycache__" / "junk.py", "z: int = 3\n")
        _write(self.root / "sub" / "deep.py", "w: int = 4\n")

    def test_exclude_pattern(self) -> None:
        files = discover_files(self.root, [], ["skip_me.py"], [])
        names = {f.name for f in files}
        self.assertIn("keep.py", names)
        self.assertNotIn("skip_me.py", names)
        self.assertNotIn("junk.py", names)

    def test_include_pattern(self) -> None:
        files = discover_files(self.root, ["sub/*"], [], [])
        self.assertEqual([f.name for f in files], ["deep.py"])

    def test_module_filter_pulls_submodules(self) -> None:
        _write(self.root / "pkg" / "__init__.py", "")
        _write(self.root / "pkg" / "inner.py", "")
        files = discover_files(self.root, [], [], ["pkg"])
        rels = {f.relative_to(self.root).as_posix() for f in files}
        self.assertEqual(rels, {"pkg/__init__.py", "pkg/inner.py"})

    def test_unknown_module_exits(self) -> None:
        with self.assertRaises(SystemExit):
            discover_files(self.root, [], [], ["nope"])


class TestBatchEndToEnd(unittest.TestCase):
    """Really invoke `jac tool py2jac`; few tiny files to stay fast."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.jac = _HERE.parent.parent / ".venv" / "bin" / "jac"
        if not cls.jac.is_file():
            raise unittest.SkipTest(f"jac binary not found at {cls.jac}")
        cls.out_dir = Path(tempfile.mkdtemp())

    def _run(self, root: Path, out: Path, **kw) -> dict:
        return run_batch(input_root=root, output_root=out, jac_bin=self.jac, **kw)

    def test_chain_conversion_and_layout_mirror(self) -> None:
        root = Path(tempfile.mkdtemp())
        _write(root / "lib" / "c.py", "VALUE: int = 3\n")
        _write(root / "lib" / "b.py", "from c import VALUE\nX: int = VALUE + 1\n")
        out = self.out_dir / "chain_out"
        report = self._run(root, out)
        self.assertEqual(report["counts"], {"ok": 2, "failed": 0,
                                            "skipped-dependency": 0})
        self.assertEqual(_statuses(report),
                         {"lib/b.py": "ok", "lib/c.py": "ok"})
        self.assertTrue((out / "lib" / "c.jac").is_file())
        self.assertTrue((out / "lib" / "b.jac").is_file())
        c_text = (out / "lib" / "c.jac").read_text(encoding="utf-8")
        self.assertIn("VALUE", c_text)
        self.assertNotIn("def ", c_text)

    def test_syntax_error_quarantine_and_transitive_skip(self) -> None:
        root = Path(tempfile.mkdtemp())
        _write(root / "bad.py", "def broken(:\n")
        _write(root / "user.py", "import bad\nZ: int = 1\n")
        _write(root / "lonely.py", "Q: int = 7\n")
        out = self.out_dir / "quar_out"
        report = self._run(root, out)
        statuses = _statuses(report)
        self.assertEqual(statuses["bad.py"], "failed")
        self.assertEqual(statuses["user.py"], "skipped-dependency")
        self.assertEqual(statuses["lonely.py"], "ok")
        bad_row = next(r for r in report["files"] if r["source"] == "bad.py")
        self.assertIn("invalid syntax", bad_row["error"])
        self.assertFalse((out / "bad.jac").exists())
        self.assertFalse((out / "user.jac").exists())
        self.assertTrue((out / "lonely.jac").is_file())

        quarantine_path = out / "py2jac_batch.quarantine.json"
        quarantine = json.loads(quarantine_path.read_text(encoding="utf-8"))
        q_sources = {row["source"]: row["status"] for row in quarantine["files"]}
        self.assertEqual(q_sources["bad.py"], "failed")
        self.assertEqual(q_sources["user.py"], "skipped-dependency")
        self.assertNotIn("lonely.py", q_sources)
        self.assertEqual(quarantine["counts"]["failed"], 1)
        self.assertEqual(quarantine["counts"]["skipped-dependency"], 1)

    def test_cycle_converts_together(self) -> None:
        root = Path(tempfile.mkdtemp())
        _write(root / "p.py", "import q\nA: int = 1\n")
        _write(root / "q.py", "import p\nB: int = 2\n")
        out = self.out_dir / "cycle_out"
        report = self._run(root, out)
        self.assertEqual(report["counts"]["ok"], 2)
        self.assertTrue((out / "p.jac").is_file())
        self.assertTrue((out / "q.jac").is_file())

    def test_failing_member_of_cycle_skips_sibling(self) -> None:
        root = Path(tempfile.mkdtemp())
        _write(root / "p.py", "def broken(:\n")
        _write(root / "q.py", "import p\nB: int = 2\n")
        out = self.out_dir / "cycle_fail_out"
        report = self._run(root, out)
        statuses = _statuses(report)
        self.assertEqual(statuses["p.py"], "failed")
        self.assertEqual(statuses["q.py"], "skipped-dependency")

    def test_idempotent_rerun_same_report_shape(self) -> None:
        root = Path(tempfile.mkdtemp())
        _write(root / "m1.py", "V: int = 5\n")
        _write(root / "m2.py", "from m1 import V\nW: int = V * 2\n")
        out = self.out_dir / "idem_out"
        rep1 = self._run(root, out)
        snap1 = {
            p.relative_to(out).as_posix(): p.read_bytes()
            for p in sorted(out.rglob("*"))
            if p.is_file() and p.suffix == ".jac"
        }
        rep2 = self._run(root, out)
        snap2 = {
            p.relative_to(out).as_posix(): p.read_bytes()
            for p in sorted(out.rglob("*"))
            if p.is_file() and p.suffix == ".jac"
        }
        self.assertEqual(snap1, snap2)
        self.assertEqual(rep1["files"], rep2["files"])
        self.assertFalse(any(r.get("cached") for r in rep2["files"]))

    def test_incremental_skips_unchanged_reconverts_changed(self) -> None:
        root = Path(tempfile.mkdtemp())
        _write(root / "m1.py", "V: int = 5\n")
        _write(root / "broken.py", "def broken(:\n")
        out = self.out_dir / "inc_out"
        rep1 = self._run(root, out, incremental=True)
        self.assertEqual(rep1["counts"]["ok"], 1)
        mtime_before = (out / "m1.jac").stat().st_mtime_ns

        rep2 = self._run(root, out, incremental=True)
        self.assertTrue(all(r.get("cached") for r in rep2["files"]
                            if r["source"] == "m1.py"))
        self.assertEqual((out / "m1.jac").stat().st_mtime_ns, mtime_before)
        self.assertEqual(rep2["counts"]["failed"], 1)

        _write(root / "m1.py", "V: int = 6\n")
        rep3 = self._run(root, out, incremental=True)
        m1_row = next(r for r in rep3["files"] if r["source"] == "m1.py")
        self.assertFalse(m1_row.get("cached", False))
        self.assertIn("6", (out / "m1.jac").read_text(encoding="utf-8"))

    def test_incremental_recovers_deleted_output(self) -> None:
        root = Path(tempfile.mkdtemp())
        _write(root / "solo.py", "K: int = 9\n")
        out = self.out_dir / "recov_out"
        self._run(root, out, incremental=True)
        (out / "solo.jac").unlink()
        rep = self._run(root, out, incremental=True)
        solo_row = next(r for r in rep["files"] if r["source"] == "solo.py")
        self.assertFalse(solo_row.get("cached", False))
        self.assertTrue((out / "solo.jac").is_file())


class TestConverterContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.jac = _HERE.parent.parent / ".venv" / "bin" / "jac"
        if not cls.jac.is_file():
            raise unittest.SkipTest(f"jac binary not found at {cls.jac}")

    def test_success_returns_code(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            src = Path(td) / "ok.py"
            _write(src, "N: int = 1\n")
            code, err = default_converter(self.jac)(src)
            self.assertIsNone(err)
            self.assertIn("entry", code)

    def test_failure_returns_error(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            src = Path(td) / "nope.py"
            _write(src, "syntax error here(\n")
            code, err = default_converter(self.jac)(src)
            self.assertIsNone(code)
            self.assertTrue(err)


if __name__ == "__main__":
    unittest.main()
