"""Tests for sv_lower — on-device walker/node lowering (Phase 2)."""
import from jaclang.compiler.passes.compose.sv_lower {
    run_sv_lower,
    emit_jacgraph_templates
}
import from jaclang.compiler.passes.compose.rpc_client { emit_sv_backend }
import from jaclang.jac0core.codeinfo { BoundaryTypeInfo, InteropManifest }
import from pathlib { Path }
import tempfile;

def _todo_manifest() -> InteropManifest {
    manifest = InteropManifest();
    manifest.walker_access = {"add_todo": False, "list_todos": False, "clear": False};
    manifest.boundary_types = {
        "AddTodoRequest": BoundaryTypeInfo(
            name="AddTodoRequest",
            kind="walker",
            fields=[("title", "str")],
            field_defaults={}
        ),
        "AddTodoResponse": BoundaryTypeInfo(
            name="AddTodoResponse",
            kind="obj",
            fields=[("reports", "list[str]")],
            field_defaults={"reports": []}
        ),
        "ListTodosRequest": BoundaryTypeInfo(
            name="ListTodosRequest", kind="walker", fields=[]
        ),
        "ListTodosResponse": BoundaryTypeInfo(
            name="ListTodosResponse",
            kind="obj",
            fields=[("reports", "list[str]")],
            field_defaults={"reports": []}
        ),
        "ClearRequest": BoundaryTypeInfo(name="ClearRequest", kind="walker", fields=[]),
        "ClearResponse": BoundaryTypeInfo(
            name="ClearResponse",
            kind="obj",
            fields=[("reports", "list[str]")],
            field_defaults={"reports": []}
        )
    };
    return manifest;
}

glob _TODO_SV_SRC: str = """
node Todo {
    has title: str;
}

walker:pub add_todo {
    has title: str;

    can add with Root entry {
        new_todo = here ++> Todo(title=self.title);
        report new_todo.title;
    }
}

walker:pub list_todos {
    can list with Root entry {
        for t in [root-->][?:Todo] {
            report t.title;
        }
    }
}

walker:pub clear {
    can clear_all with Root entry {
        for t in [root-->][?:Todo] {
            del t;
        }
    }
}
""";

test "run_sv_lower emits Todo node and walker classes" {
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "sv.jac";
        path.write_text(_TODO_SV_SRC, encoding="utf-8");
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.jac0core.compile_options { CompileOptions }
        program = Jac.program;
        mod = program.compile(
            str(path), options=CompileOptions(no_cgen=True, type_check=False)
        );
        result = run_sv_lower(mod, _todo_manifest(), "dev.jac.test");
        assert not result.diagnostics , f"unexpected diagnostics: {result.diagnostics}";
        assert "SvNodes.kt" in result.files;
        src = result.files["SvNodes.kt"];
        assert "class Todo" in src;
        assert "class AddTodo" in src;
        assert "override fun onRootEntry" in src;
        assert "JacGraph.spawnNode" in src or "JacGraph.connect" in src;
        assert "JacGraph.neighbors" in src;
        assert "JacGraph.delete" in src;
    }
}

test "emit_sv_backend device emits DeviceBackend without RemoteBackend" {
    files = emit_sv_backend("dev.jac.test", _todo_manifest(), "device", None, ["Todo"]);
    assert "DeviceBackend.kt" in files;
    assert "RemoteBackend.kt" not in files;
    assert "class DeviceBackend" in files["DeviceBackend.kt"];
    assert "spawnOn" in files["DeviceBackend.kt"];
    assert "JacBackends.current = DeviceBackend()" in files["JacBackendInit.kt"];
    assert "JacGraph.init" in files["JacBackendInit.kt"];
    # Node serializers register eagerly in install(), before JacGraph.init loads.
    init_kt = files["JacBackendInit.kt"];
    reg = init_kt.index("registerNodeSubclass");
    assert "JacGraph.init" in init_kt[reg:];
}

test "emit_jacgraph_templates includes graph runtime" {
    files = emit_jacgraph_templates("dev.jac.test");
    assert "JacGraph.kt" in files;
    assert "object JacGraph" in files["JacGraph.kt"];
    assert "jac_graph.json" in files["JacGraph.kt"];
    assert "JacGraphSerializers.kt" in files;
    assert "registerNodeSubclass" in files["JacGraphSerializers.kt"];
    assert "abstract class Walker" in files["Walker.kt"];
}

test "run_sv_lower registers node types for graph persistence" {
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "sv.jac";
        path.write_text(_TODO_SV_SRC, encoding="utf-8");
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.jac0core.compile_options { CompileOptions }
        program = Jac.program;
        mod = program.compile(
            str(path), options=CompileOptions(no_cgen=True, type_check=False)
        );
        result = run_sv_lower(mod, _todo_manifest(), "dev.jac.test");
        assert result.node_names == ["Todo"];
        src = result.files["SvNodes.kt"];
        # Registration happens eagerly in JacBackendInit, not lazily in SvNodes.kt.
        assert "registerNodeSubclass" not in src;
    }
}

test "sv_lower rejects inbound edge references" {
    src = _TODO_SV_SRC.replace("[root-->][?:Todo]", "[root<--][?:Todo]");
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "bad.jac";
        path.write_text(src, encoding="utf-8");
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.jac0core.compile_options { CompileOptions }
        program = Jac.program;
        mod = program.compile(
            str(path), options=CompileOptions(no_cgen=True, type_check=False)
        );
        result = run_sv_lower(mod, _todo_manifest(), "dev.jac.test");
        assert any(
            "outbound" in d or "not supported" in d for d in result.diagnostics
        ) , f"expected inbound-edge diagnostic, got {result.diagnostics}";
    }
}
