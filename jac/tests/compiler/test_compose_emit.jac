"""Tests for ComposeEmit.emit_jac_app — locks in HMR route persistence.

On a DexClassLoader hot-swap, JacApp is re-mounted and would reset to the
initial route. The dev emit restores the last route from SharedPreferences and
persists it on every navigation, so a code swap keeps the user on their current
screen. These tests call emit_jac_app directly on a minimal model (no Gradle,
no device) to pin the emitted Kotlin contract.
"""
import from jaclang.compiler.passes.compose.compose_model { ComposeModule }
import from jaclang.compiler.passes.ecmascript.intent.model {
    IntentRoute,
    IntentComponent
}
import from jaclang.compiler.passes.ecmascript.view_ir {
    ViewElement,
    HostTag
}
import from jaclang.compiler.passes.compose.compose_emit { ComposeEmit }
import from pathlib { Path }
import tempfile;

test "dev emit_jac_app restores and persists the route" {
    model = ComposeModule();
    model.intent.package_name = "dev.jac.t";
    model.intent.routes = [
        IntentRoute(path="/", screen_name="HomeScreen", component="app")
    ];
    code = ComposeEmit(model=model, out_dir=Path("/tmp"), dev=True).emit_jac_app();

    # Restore: read the last path from the HMR prefs and validate it.
    assert 'getSharedPreferences("jac-hmr"' in code;
    assert "restoredPath" in code;
    assert 'hmr.getString("path", null)' in code;

    # Persist: a LaunchedEffect writes the current path whenever it changes.
    assert 'putString("path", currentEntry.path)' in code;
}

test "release emit_jac_app has no HMR persistence" {
    model = ComposeModule();
    model.intent.package_name = "dev.jac.t";
    model.intent.routes = [
        IntentRoute(path="/", screen_name="HomeScreen", component="app")
    ];
    code = ComposeEmit(model=model, out_dir=Path("/tmp"), dev=False).emit_jac_app();

    # Release must not read/write the HMR prefs — keeps the startPath path.
    assert "getSharedPreferences" not in code;
    assert "restoredPath" not in code;
    assert "val initialPath = if (JacRoutes.paths.contains(startPath))" in code;
}

# P0 #2 — DOM/Tailwind IR is rejected: the Compose framework has one code path
# (native compose_view). A component lowering only DOM IR must record a
# diagnostic, never silently emit a lossy Box stub.
test "DOM IR (comp.view) records a diagnostic, not a silent stub" {
    with tempfile.TemporaryDirectory() as tmp {
        model = ComposeModule();
        model.intent.package_name = "dev.jac.t";
        comp = IntentComponent(name="app", is_screen=True, route_path="/");
        comp.view = ViewElement(
            tag=HostTag(name="div", jac_node=None),
            attrs=[],
            children=[],
            jac_node=None
        );
        model.intent.components["app"] = comp;
        model.intent.routes = [
            IntentRoute(path="/", screen_name="HomeScreen", component="app")
        ];
        ComposeEmit(model=model, out_dir=Path(tmp)).emit_screens();
        joined = "\n".join(model.intent.diagnostics);
        assert "DOM IR" in joined;
        assert "app" in joined;
    }
}

# P0 #1 — fail-fast: any codegen diagnostic aborts the emit before Gradle ever
# sees a broken/empty-screen project. write() raises and writes no Kotlin.
test "write() raises on diagnostics and writes no Kotlin sources" {
    with tempfile.TemporaryDirectory() as tmp {
        model = ComposeModule();
        model.intent.package_name = "dev.jac.t";
        comp = IntentComponent(name="app", is_screen=True, route_path="/");
        comp.view = ViewElement(
            tag=HostTag(name="div", jac_node=None),
            attrs=[],
            children=[],
            jac_node=None
        );
        model.intent.components["app"] = comp;
        model.intent.routes = [
            IntentRoute(path="/", screen_name="HomeScreen", component="app")
        ];
        out = Path(tmp) / "android";
        raised = False;
        try {
            ComposeEmit(model=model, out_dir=out).write();
        } except RuntimeError {
            raised = True;
        }
        assert raised;
        # The fail-fast gate runs before the Kotlin write loop, so no .kt is
        # emitted for the rejected screen.
        kt_files = [p for p in out.rglob("*.kt")] if out.is_dir() else [];
        assert all("Screens.kt" != p.name for p in kt_files);
    }
}

test "write() succeeds with no diagnostics on a clean native model" {
    # Sanity check that the fail-fast gate does not fire for valid native IR.
    src = '''
def:pub app -> Composable {
    return <Column>
        <Text>"ok"</Text>
    </Column>;
}
''';
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / "app.cl.jac";
        path.write_text(src, encoding="utf-8");
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        import from jaclang.compiler.passes.compose.compose_gen_pass { run_compose_gen_pass }
        program = Jac.program;
        mod = program.compile(str(path));
        model = run_compose_gen_pass(mod, program);
        model.intent.package_name = "dev.jac.t";
        out = Path(tmp) / "android";
        raised = False;
        try {
            ComposeEmit(model=model, out_dir=out).write();
        } except Exception {
            raised = True;
        }
        assert not raised;
        assert not model.intent.diagnostics;
        assert (out / "app" / "src" / "main" / "java").is_dir();
    }
}
