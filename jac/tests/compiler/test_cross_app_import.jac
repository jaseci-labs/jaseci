"""The one cross-app import rule (#8823).

Every import is classified once by `classify_cross_app_import` over the
workspace's app facts: LOCAL (same app or shared), CLIENT_BRIDGE (client code
reaching server-placed elements), SERVICE_BRIDGE (server/native code reaching
elements owned by another serving app) and NATIVE_BIND (a client-native edge
recorded in the interop manifest). The fixture under fixtures/apps is a five-app
workspace: a dir-rooted web-app, a file-rooted social service, a cli app and a
pair of mutually-importing services that close an app cycle.
"""

import os;
import from tests.support { JAC_ROOT }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.boundary_classify {
    CrossAppKind,
    classify_cross_app_import,
    import_crosses_apps,
    import_provider_app,
    import_provider_route,
    is_client_boundary_import
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.codeinfo {
    InteropBinding,
    InteropContext,
    InteropManifest
}

glob APPS_DIR = os.path.join(JAC_ROOT, "tests", "compiler", "fixtures", "apps");

def fixture(*parts: str) -> str {
    return os.path.join(APPS_DIR, *parts);
}

def compile_fixture(path: str, cgen: bool = False) -> tuple {
    prog = JacProgram();
    mod = prog.compile(path, no_cgen=not cgen);
    return (prog, mod);
}

def import_of(mod: uni.Module, stem: str) -> uni.Import {
    for imp in mod.get_all_sub_nodes(uni.Import) {
        if imp.from_loc is not None and imp.from_loc.base_module_name == stem {
            return imp;
        }
    }
    raise AssertionError(f"no import of '{stem}' in {mod.loc.mod_path}");
}

def codes(prog: JacProgram) -> list[str] {
    return [
        e.code.code
        for e in prog.errors_had
        if e.code is not None
    ];
}

test "same-app import is LOCAL" {
    (prog, mod) = compile_fixture(fixture("web", "main.jac"));
    imp = import_of(mod, "helpers");
    assert classify_cross_app_import(imp, None) == CrossAppKind.LOCAL;
    assert not imp.is_service_import;
    assert not import_crosses_apps(imp);
    assert import_provider_app(imp) is None;
}

test "server-context import of another serving app is SERVICE_BRIDGE" {
    (prog, mod) = compile_fixture(fixture("web", "main.jac"));
    imp = import_of(mod, "social_app");
    assert classify_cross_app_import(imp, None) == CrossAppKind.SERVICE_BRIDGE;
    assert imp.is_service_import , (
        "Import.is_service_import is the SERVICE_BRIDGE verdict"
    );
    assert import_provider_app(imp) == "social";
    assert import_provider_route(imp) == "/api/social";
    assert not is_client_boundary_import(imp);
    manifest = mod.gen.interop_manifest;
    assert ("web", "social") in manifest.app_edges , (
        f"consumer->provider edge must be recorded; got {manifest.app_edges}"
    );
    assert manifest.provider_routes.get("social") == "/api/social";
    greet = manifest.bindings.get("greet");
    assert greet is not None and greet.provider_app == "social";
    walker_binding = manifest.bindings.get("Greet");
    assert walker_binding is not None and walker_binding.kind == "walker" , (
        "a plain (non-:pub) walker bridges like any archetype"
    );
    assert "E5106" not in codes(prog) , f"{[str(e) for e in prog.errors_had]}";
    assert "E5104" not in codes(prog);
}

test "SERVICE_BRIDGE stubs are typed-async and keyed by the owner app" {
    (prog, mod) = compile_fixture(fixture("web", "main.jac"), cgen=True);
    py = mod.gen.py;
    assert "async def greet(" in py , py;
    assert "await __jac_sv_client.call('social', 'greet'" in py , py;
    assert "__jac_provider_app__ = 'social'" in py , py;
    assert "spawn_walker('social', 'Greet', kwargs, cls)" in py , py;
    assert "def _deferred(cls, **kwargs)" in py , py;
    assert "spawn_deferred('social', 'Greet', kwargs)" in py , py;
    assert "_declare_consumer_provider('web', 'social', '/api/social')" in py , py;
    assert "Greet._deferred(name='z')" in py , (
        "an un-awaited statement-level spawn lowers to deferred delivery; got:\n" + py
    );
    assert "__jac_provider_module__" not in py;
}

test "cli app importing a service walker is a SERVICE_BRIDGE consumer" {
    (prog, mod) = compile_fixture(fixture("cli_app.jac"), cgen=True);
    imp = import_of(mod, "social_app");
    assert classify_cross_app_import(imp, None) == CrossAppKind.SERVICE_BRIDGE;
    assert ("cli", "social") in mod.gen.interop_manifest.app_edges;
    assert "spawn_walker('social', 'Greet'" in mod.gen.py;
    assert "E5106" not in codes(prog) , f"{[str(e) for e in prog.errors_had]}";
}

test "client-context import of server-placed elements is CLIENT_BRIDGE" {
    (prog, mod) = compile_fixture(fixture("web", "panel.jac"), cgen=True);
    imp = import_of(mod, "social_app");
    assert classify_cross_app_import(imp, None) == CrossAppKind.CLIENT_BRIDGE;
    assert is_client_boundary_import(imp);
    assert not imp.is_service_import;
    js = mod.gen.js;
    assert '__jacCallFunction("greet"' in js , js;
    assert '"route": "/api/social"' in js or "route: \"/api/social\"" in js , (
        "cross-app client stubs carry the provider route; got:\n" + js
    );
    assert ("web", "social") in mod.gen.interop_manifest.app_edges;
}

test "NATIVE_BIND wins for a client import recorded as a client-native edge" {
    (prog, mod) = compile_fixture(fixture("web", "panel.jac"));
    imp = import_of(mod, "social_app");
    resolved = imp.from_loc.resolve_relative_path();
    manifest = InteropManifest();
    manifest.bindings["greet"] = InteropBinding(
        name="greet",
        source_context=InteropContext.NATIVE,
        callers={InteropContext.CLIENT},
        source_module=resolved
    );
    assert classify_cross_app_import(imp, manifest) == CrossAppKind.NATIVE_BIND;
}

test "bridging to a non-pub def of another app is E5106" {
    (prog, mod) = compile_fixture(fixture("web", "bad_bridge.jac"));
    found = codes(prog);
    assert "E5106" in found , (
        f"expected E5106, got {[str(e) for e in prog.errors_had]}"
    );
    assert "E5082" not in found , "cross-app dead bindings report E5106, not E5082";
}

test "app dependency cycle is E5104" {
    (prog, mod) = compile_fixture(fixture("cycle_a.jac"));
    found = codes(prog);
    assert "E5104" in found , (
        f"expected E5104, got {[str(e) for e in prog.errors_had]}"
    );
    msg = [
        str(e)
        for e in prog.errors_had
        if e.code is not None and e.code.code == "E5104"
    ][0];
    assert "cycle_a" in msg and "cycle_b" in msg , msg;
}

test "missing await on a SERVICE_BRIDGE stub is E1042" {
    (prog, mod) = compile_fixture(fixture("web", "no_await.jac"));
    found = codes(prog);
    assert "E1042" in found , (
        f"expected E1042, got {[str(e) for e in prog.errors_had]}"
    );
}
