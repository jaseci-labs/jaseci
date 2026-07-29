"""Native unit selftests for ai_tui_na primitives (width, keys, editor, etc.).

Builds and runs the PASS/FAIL harness binaries under ai_tui_na/bin/. Mirrors
reference/pi/packages/tui/test/* unit coverage at the Jac native layer.

Skipped when the libjacpyembed shim is absent (Python-only CI).
"""

import pytest;
import jac.tests.cli.tui_selftest_harness as harness;


def _skip_unless_shim(na_dir) {
    if not harness.shim_path(harness.repo_root(na_dir)).is_file() {
        pytest.skip("libjacpyembed shim not built (run zig build in jac/)");
    }
}


test "native width primitives selftest passes" {
    na_dir = harness.na_dir();
    _skip_unless_shim(na_dir);
    harness.ensure_unit_selftests(na_dir);
    harness.assert_selftest_passes(na_dir, "selftest_width");
}


test "native key parsing selftest passes" {
    na_dir = harness.na_dir();
    _skip_unless_shim(na_dir);
    harness.ensure_unit_selftests(na_dir);
    harness.assert_selftest_passes(na_dir, "selftest_keys");
}


test "native editor selftest passes" {
    na_dir = harness.na_dir();
    _skip_unless_shim(na_dir);
    harness.ensure_unit_selftests(na_dir);
    harness.assert_selftest_passes(na_dir, "selftest_editor");
}


test "native markdown selftest passes" {
    na_dir = harness.na_dir();
    _skip_unless_shim(na_dir);
    harness.ensure_unit_selftests(na_dir);
    harness.assert_selftest_passes(na_dir, "selftest_markdown");
}


test "native overlay selftest passes" {
    na_dir = harness.na_dir();
    _skip_unless_shim(na_dir);
    harness.ensure_unit_selftests(na_dir);
    harness.assert_selftest_passes(na_dir, "selftest_overlay");
}


test "native autocomplete selftest passes" {
    na_dir = harness.na_dir();
    _skip_unless_shim(na_dir);
    harness.ensure_unit_selftests(na_dir);
    harness.assert_selftest_passes(na_dir, "selftest_autocomplete");
}


test "native diff renderer selftest passes" {
    na_dir = harness.na_dir();
    _skip_unless_shim(na_dir);
    harness.ensure_unit_selftests(na_dir);
    harness.assert_selftest_passes(na_dir, "selftest_diff");
}


test "native self-pipe wake selftest passes" {
    na_dir = harness.na_dir();
    _skip_unless_shim(na_dir);
    harness.ensure_selftest(na_dir, "selftest_wake");
    harness.assert_selftest_passes(na_dir, "selftest_wake");
}
