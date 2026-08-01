"""Tests for AndroidTarget._resolve_type_check — the [client.android] gate.

Type checking defaults ON for the Compose target now that the checker
understands the idiomatic Kotlin-isms (.dp/.sp/.len extensions, Modifier
chains, Arrangement/Alignment/Color const namespaces). A project can still
opt out with `type_check = false`. These pin the tri-state: absent key -> on,
explicit true -> on, explicit false -> off.
"""
import os;
import tempfile;
import from pathlib { Path }
import from jaclang.runtimelib.client.targets.android_target { AndroidTarget }

def _project_with_toml(body: str) -> Path {
    d = Path(tempfile.mkdtemp(prefix="jac_test_android_tc_"));
    (d / "jac.toml").write_text(body);
    return d;
}

test "type checking defaults ON when jac.toml has no [client.android] section" {
    d = _project_with_toml("[project]\nname = \"demo\"\n");
    assert AndroidTarget()._resolve_type_check(d) == True;
}

test "type checking defaults ON when [client.android] omits type_check" {
    d = _project_with_toml("[client.android]\npackage = \"dev.jac.demo\"\n");
    assert AndroidTarget()._resolve_type_check(d) == True;
}

test "type_check = false opts a project out" {
    d = _project_with_toml("[client.android]\ntype_check = false\n");
    assert AndroidTarget()._resolve_type_check(d) == False;
}

test "type_check = true keeps checking on" {
    d = _project_with_toml("[client.android]\ntype_check = true\n");
    assert AndroidTarget()._resolve_type_check(d) == True;
}

test "a missing jac.toml still defaults ON" {
    d = Path(tempfile.mkdtemp(prefix="jac_test_android_tc_none_"));
    assert AndroidTarget()._resolve_type_check(d) == True;
}
