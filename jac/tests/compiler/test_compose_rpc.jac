"""Tests for typed RPC emission — JacBackend seam from InteropManifest."""
import from jaclang.compiler.passes.compose.rpc_client {
    emit_jac_client,
    emit_sv_backend
}
import from jaclang.jac0core.codeinfo { BoundaryTypeInfo, InteropManifest }
import from pathlib { Path }
import tempfile;

def _greet_manifest() -> InteropManifest {
    manifest = InteropManifest();
    manifest.walker_access = {"greet": False};
    manifest.boundary_types = {
        "GreetRequest": BoundaryTypeInfo(
            name="GreetRequest",
            kind="walker",
            fields=[("name", "str")],
            field_defaults={"name": "friend"}
        ),
        "GreetResponse": BoundaryTypeInfo(
            name="GreetResponse",
            kind="obj",
            fields=[("reports", "list[str]")],
            field_defaults={"reports": []}
        )
    };
    return manifest;
}

test "emit_jac_client includes request fields from boundary_types" {
    code = emit_jac_client("dev.jac.test", _greet_manifest());
    assert "@Serializable" in code;
    assert "data class GreetRequest" in code;
    assert "val name: String" in code;
    assert "interface JacBackend" in code;
    assert "class RemoteBackend" in code;
    assert 'suspend fun greet(req: GreetRequest' in code;
}

test "emit_sv_backend emits split backend files for remote deploy" {
    files = emit_sv_backend("dev.jac.test", _greet_manifest(), "remote", None);
    assert "JacBoundary.kt" in files;
    assert "JacBackend.kt" in files;
    assert "RemoteBackend.kt" in files;
    assert "JacBackendInit.kt" in files;
    assert "interface JacBackend" in files["JacBackend.kt"];
    assert "object JacBackends" in files["JacBackend.kt"];
    assert "lateinit var current" in files["JacBackend.kt"];
    assert "class RemoteBackend" in files["RemoteBackend.kt"];
    assert "JacBackends.current = RemoteBackend()" in files["JacBackendInit.kt"];
    assert "data class GreetRequest" in files["JacBoundary.kt"];
}

test "emit_sv_backend falls back to remote for local-first deploy with warning path" {
    files = emit_sv_backend("dev.jac.test", _greet_manifest(), "local-first", None);
    assert "RemoteBackend.kt" in files;
    assert "DeviceBackend.kt" not in files;
}

test "emit_sv_backend emits DeviceBackend for device deploy" {
    files = emit_sv_backend("dev.jac.test", _greet_manifest(), "device", None);
    assert "DeviceBackend.kt" in files;
    assert "RemoteBackend.kt" not in files;
    assert "class DeviceBackend" in files["DeviceBackend.kt"];
}

test "renamed walker field changes generated GreetRequest" {
    manifest_old = InteropManifest();
    manifest_old.walker_access = {"greet": False};
    manifest_old.boundary_types = {
        "GreetRequest": BoundaryTypeInfo(
            name="GreetRequest",
            kind="walker",
            fields=[("name", "str")],
            field_defaults={"name": "friend"}
        ),
        "GreetResponse": BoundaryTypeInfo(
            name="GreetResponse",
            kind="obj",
            fields=[("reports", "list[str]")],
            field_defaults={"reports": []}
        )
    };
    manifest_new = InteropManifest();
    manifest_new.walker_access = {"greet": False};
    manifest_new.boundary_types = {
        "GreetRequest": BoundaryTypeInfo(
            name="GreetRequest",
            kind="walker",
            fields=[("username", "str")],
            field_defaults={"username": "friend"}
        ),
        "GreetResponse": BoundaryTypeInfo(
            name="GreetResponse",
            kind="obj",
            fields=[("reports", "list[str]")],
            field_defaults={"reports": []}
        )
    };
    old_code = emit_jac_client("dev.jac.test", manifest_old);
    new_code = emit_jac_client("dev.jac.test", manifest_new);
    assert "val name: String" in old_code;
    assert "val username: String" in new_code;
    assert "val name: String" not in new_code;
    assert "val username: String" not in old_code;
}
