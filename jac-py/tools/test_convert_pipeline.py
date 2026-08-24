"""Unit tests for the D2 conversion pipeline tools (convert_suite/diff_runner).

Covers the mechanical rewrite vocabulary, quarantine decisions, host-oracle
parsing, and pytest-output classification with small inline fixtures.
"""

from __future__ import annotations

import ast
import json
import sys
import textwrap
import unittest
from pathlib import Path

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

import convert_suite as cs
import diff_runner as dr


MINI_TEST_FILE = '''\
import copy
import unittest
from test import support


def _helper(x):
    return x + 1


class TestMini(unittest.TestCase):
    def test_equal(self):
        x = copy.copy([1, 2])
        self.assertEqual(x, [1, 2])

    def test_raises_ctx(self):
        with self.assertRaises(TypeError):
            int("zzz")

    def test_raises_call(self):
        self.assertRaises(TypeError, int, "zzz")

    def test_unsupported_attr(self):
        self.assertEqual(self.some_fixture, 3)

    def test_skip(self):
        self.skipTest("not on this VM")

    def test_support_user(self):
        support.run_unittest(TestMini)

    @unittest.skip("reason")
    def test_decorated(self):
        pass

    def test_unresolved(self):
        self.assertEqual(_nowhere(), 1)

    def test_helper_ok(self):
        self.assertEqual(_helper(1), 2)


@unittest.skip("whole class")
class TestSkipped(unittest.TestCase):
    def test_nothing(self):
        pass
'''


class ExtractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tree = ast.parse(MINI_TEST_FILE)
        cls.extraction = cs.extract_tests(cls.tree, MINI_TEST_FILE)

    def pinned_idents(self) -> set[str]:
        return {p.ident for p in self.extraction.pinned}

    def quarantined_reasons(self) -> dict[str, str]:
        return {q.ident: q.reason for q in self.extraction.quarantined}

    def test_pinned_set(self):
        self.assertEqual(
            self.pinned_idents(),
            {"TestMini.test_equal", "TestMini.test_raises_ctx",
             "TestMini.test_raises_call", "TestMini.test_helper_ok"},
        )

    def test_quarantine_reasons(self):
        reasons = self.quarantined_reasons()
        self.assertEqual(reasons["TestMini.test_unsupported_attr"], "uses-self.some_fixture")
        self.assertEqual(reasons["TestMini.test_skip"], "self.skipTest")
        self.assertTrue(reasons["TestMini.test_support_user"].startswith("unresolved-name:"))
        self.assertTrue(reasons["TestMini.test_decorated"].startswith("decorator:"))
        self.assertTrue(reasons["TestMini.test_unresolved"].startswith("unresolved-name:"))
        self.assertTrue(reasons["TestSkipped.test_nothing"].startswith("decorator:"))

    def test_prelude_pruned_per_snippet(self):
        pin = next(p for p in self.extraction.pinned if p.ident == "TestMini.test_helper_ok")
        # `import copy` is unused by this test and must be pruned.
        self.assertNotIn("copy", pin.snippet.split("_t")[0])

    def test_pinned_snippets_compile_as_python(self):
        for pin in self.extraction.pinned:
            compile(pin.snippet, pin.ident, "exec")


class RewriteBehaviorTests(unittest.TestCase):
    """Rendered snippets must preserve unittest assertion semantics."""

    def _render(self, body_src: str) -> tuple[str, bool]:
        stmts = ast.parse(textwrap.dedent(body_src)).body
        rewritten, needs_re = cs.rewrite_block(stmts)
        return cs.render_snippet(rewritten, [], needs_re), needs_re

    def run_snippet(self, snippet: str) -> list:
        captured: list = []
        env = {"print": lambda *a, **k: captured.append(a)}
        exec(snippet, env)  # noqa: S102 - fixture
        return captured

    def outcome(self, body_src: str) -> str:
        snippet, _ = self._render(body_src)
        out = self.run_snippet(snippet)
        return " ".join(str(a) for a in out[-1])

    def test_assert_equal_pass_and_fail(self):
        self.assertEqual(self.outcome("self.assertEqual(1+1, 2)"), "ok")
        failed = self.outcome("self.assertEqual(1, 2)")
        self.assertTrue(failed.startswith(cs._ORACLE_EXC), failed)
        self.assertIn("AssertionError", failed)

    def test_assert_vocabulary_passes(self):
        for body in (
            "assertIn_check()".replace("assertIn_check()", "self.assertNotIn('z', 'abc')"),
            "self.assertIsInstance([], list)",
            "self.assertAlmostEqual(0.1 + 0.2, 0.3)",
            "self.assertCountEqual([3, 1, 2], [2, 3, 1])",
            "self.assertIsNone(None)",
            "self.assertIsNotNone(0)",
            "self.assertTrue(1)",
            "self.assertFalse(0)",
        ):
            self.assertEqual(self.outcome(body), "ok", body)

    def test_plain_statements_pass_through(self):
        src = (
            "acc = []\n"
            "for i in range(3):\n"
            "    acc.append(i * 2)\n"
            "if len(acc) == 3:\n"
            "    acc.append(99)\n"
            "try:\n"
            "    {}['k']\n"
            "except KeyError:\n"
            "    pass\n"
            "self.assertEqual(acc, [0, 2, 4, 99])"
        )
        self.assertEqual(self.outcome(src), "ok")

    def test_assert_raises_both_forms(self):
        self.assertEqual(
            self.outcome(
                "with self.assertRaises(ValueError):\n    int('x')"
            ),
            "ok",
        )
        missing = self.outcome(
            "with self.assertRaises(ValueError):\n    pass"
        )
        self.assertIn("AssertionError", missing)
        self.assertIn("did not raise", missing)
        self.assertEqual(
            self.outcome("self.assertRaises(KeyError, {}.pop, 'k')"), "ok"
        )

    def test_assert_raises_regex_needs_re(self):
        snippet, needs_re = self._render(
            "with self.assertRaisesRegex(ValueError, 'bad'):\n"
            "    raise ValueError('a bad thing')"
        )
        self.assertTrue(needs_re)
        self.assertEqual(self.run_snippet(snippet)[-1], ("ok",))

    def test_fail_becomes_raise(self):
        failed = self.outcome("self.fail('nope')")
        self.assertIn("AssertionError", failed)
        self.assertIn("nope", failed)


class OracleParseTests(unittest.TestCase):
    def test_ok_marker(self):
        # render a passing snippet end-to-end and check the marker contract
        stmts = ast.parse("self.assertEqual(1, 1)").body
        rewritten, _ = cs.rewrite_block(stmts)
        snippet = cs.render_snippet(rewritten, [], False)
        import subprocess

        proc = subprocess.run(
            [sys.executable, "-c", snippet], capture_output=True, text=True
        )
        lines = proc.stdout.strip().splitlines()
        self.assertEqual(lines[-1], "ok")

    def test_exc_marker_parse(self):
        stmts = ast.parse("raise ValueError('boom\\nline2')").body
        rewritten, _ = cs.rewrite_block(stmts)
        snippet = cs.render_snippet(rewritten, [], False)
        import subprocess

        proc = subprocess.run(
            [sys.executable, "-c", snippet], capture_output=True, text=True
        )
        lines = proc.stdout.strip().splitlines()
        self.assertTrue(lines[-1].startswith(cs._ORACLE_EXC))
        payload = lines[-1][len(cs._ORACLE_EXC):]
        exc_type, _, literal = payload.partition(" ")
        self.assertEqual(exc_type, "ValueError")
        self.assertEqual(ast.literal_eval(literal), "boom\nline2")


class ClassifierTests(unittest.TestCase):
    PINS = [
        {"ident": "Mod.test_a", "snippet": "..."},
        {"ident": "Mod.test_b", "snippet": "..."},
        {"ident": "Mod.test_c", "snippet": "..."},
    ]

    def test_pass_fail_split(self):
        marks = [
            ("PASS", "Mod.test_a", ""),
            ("FAIL", "Mod.test_b", "GOT<ValueError: nope>"),
        ]
        results = dr.classify(marks, self.PINS, timed_out=False)
        self.assertEqual(results["Mod.test_b"]["classification"], "GUEST-WRONG-OUTPUT")
        self.assertEqual(results["Mod.test_b"]["detail"], "GOT<ValueError: nope>")
        self.assertNotIn("Mod.test_a", results)
        # test_c never reported and VM did not finish -> VM-CRASH
        self.assertEqual(results["Mod.test_c"]["classification"], "VM-CRASH")

    def test_run_marker_is_guest_wrong_output(self):
        results = dr.classify([("FAIL", "Mod.test_a", "RUN<TypeError: boom>")], self.PINS, False)
        self.assertEqual(results["Mod.test_a"]["classification"], "GUEST-WRONG-OUTPUT")
        self.assertEqual(results["Mod.test_a"]["detail"], "RUN<TypeError: boom>")

    def test_timeout_classification(self):
        results = dr.classify([], self.PINS, timed_out=True)
        self.assertTrue(all(r["classification"] == "TIMEOUT" for r in results.values()))

    def test_alldone_means_no_crash(self):
        marks = [
            ("PASS", "Mod.test_a", ""),
            ("PASS", "Mod.test_b", ""),
            ("PASS", "Mod.test_c", ""),
            ("ALLDONE", "", ""),
        ]
        self.assertEqual(dr.classify(marks, self.PINS, timed_out=False), {})

    def test_harness_embeds_all_pins(self):
        text = dr.build_harness(self.PINS)
        self.assertIn("import from layer_p2_libtest", text)
        self.assertIn('_mark("Mod.test_a"', text)
        self.assertIn("MARK ALLDONE", text)


class ManifestTests(unittest.TestCase):
    def test_manifest_entry_roundtrip(self, tmp=None):
        import tempfile

        with tempfile.TemporaryDirectory() as td:
            old_manifest = cs._MANIFEST
            old_tests_dir = cs._TESTS_DIR
            try:
                cs._TESTS_DIR = Path(td)
                cs._MANIFEST = Path(td) / "conformance_manifest_convpipe.json"
                outdir = Path(td) / "conv_x"
                outdir.mkdir()
                path = cs.write_manifest_entry("x", outdir, "conv_x_pins.jac", 5)
                doc = json.loads(path.read_text())
                self.assertEqual(doc["modules"][0]["stem"], "x")
                self.assertEqual(doc["modules"][0]["status"], "converted")
                # idempotent update on re-run
                cs.write_manifest_entry("x", outdir, "conv_x_pins.jac", 6)
                doc = json.loads(path.read_text())
                self.assertEqual(len(doc["modules"]), 1)
            finally:
                cs._MANIFEST = old_manifest
                cs._TESTS_DIR = old_tests_dir


class DoctestExtractionTests(unittest.TestCase):
    """Module-level doctest strings (test_genexps style) become runnable pins."""

    MODULE = '''\
import doctest
import unittest


class Tool:
    def double(self, x):
        return x * 2


tool = Tool()


doctests = """
    >>> tool.double(21)
    42
    >>> print('hello world')
    hello world
    >>> 1 +
    Traceback (most recent call last):
        ...
    SyntaxError: invalid syntax
    >>> list((i * i for i in [*range(3)]))
    [0, 1, 4]
    >>> a, *rest = range(4)
    >>> a, rest
    (0, [1, 2, 3])
    >>> tool.double(2) == 4
    True
    >>> tool.double(1.5)
    3.0
    >>> repr(tool)
    '<test_mini.Tool object at 0x123>'
"""


def load_tests(loader, tests, pattern):
    tests.addTest(doctest.DocTestSuite())
    return tests
'''

    @classmethod
    def setUpClass(cls):
        tree = ast.parse(cls.MODULE)
        cls.extraction = cs.extract_module_doctests(tree, cls.MODULE, "__main__", "mini")

    def test_pin_extracted(self):
        self.assertEqual([p.ident for p in self.extraction.pinned], ["mini.doctests:doctests"])

    def test_snippet_compiles_and_passes_on_host(self):
        pin = self.extraction.pinned[0]
        compile(pin.snippet, pin.ident, "exec")  # module-level: must be valid
        captured = []
        env = {"print": lambda *a, **k: captured.append(a), "__name__": "__main__"}
        exec(pin.snippet, env)  # noqa: S102 - fixture
        self.assertTrue(captured and str(captured[-1][0]) == cs._ORACLE_OK)

    def test_failing_output_quarantined_by_host_oracle_path(self):
        # The module-qualified expectation is unpinnable in a standalone snippet.
        reasons = {q.ident: q.reason for q in self.extraction.quarantined}
        self.assertIn("mini.doctests:doctests.ex8", reasons)
        self.assertEqual(reasons["mini.doctests:doctests.ex8"], "doctest-module-qualified-expected")

    def test_prelude_pruned_to_referenced_names(self):
        pin = self.extraction.pinned[0]
        self.assertIn("tool = Tool()", pin.snippet)
        self.assertNotIn("import doctest", pin.snippet)
        self.assertNotIn("import unittest", pin.snippet)
        self.assertNotIn("load_tests", pin.snippet)

    def test_helpers_present_once(self):
        pin = self.extraction.pinned[0]
        self.assertEqual(pin.snippet.count("def _d_check"), 1)

    def test_no_sources_yields_empty(self):
        tree = ast.parse("x = 1\n")
        result = cs.extract_module_doctests(tree, "x = 1\n", "__main__", "none")
        self.assertEqual(result.pinned, [])
        self.assertEqual(result.quarantined, [])


if __name__ == "__main__":
    unittest.main()
