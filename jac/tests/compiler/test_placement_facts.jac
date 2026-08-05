"""Tests for the placement facts API, the single placement query surface."""

import os;
import tempfile;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.placement_facts {
    client_only_paths,
    discover_spaces,
    emits_server_code,
    is_client_only,
    module_spaces,
    project_root_of,
    require_project_root,
    toolchain_native_by_policy
}

glob FIXTURE_DIR = os.path.join(
         JAC_ROOT, "tests", "compiler", "fixtures", "codespace"
     );


def _fixture(name: str) -> str {
    return os.path.join(FIXTURE_DIR, name);
}


test "a markerless inferred client module rolls up client-only" {
    prog = JacProgram();
    mod = prog.compile(_fixture("infer_client_app.jac"), no_cgen=True);
    assert module_spaces(mod) == {"client"};
    assert is_client_only(mod);
    assert not emits_server_code(mod);
}


test "a mixed module emits server code and is never client-only" {
    prog = JacProgram();
    mod = prog.compile(_fixture("infer_three_spaces.jac"), no_cgen=True);
    spaces = module_spaces(mod);
    assert "client" in spaces;
    assert "server" in spaces;
    assert emits_server_code(mod);
    assert not is_client_only(mod);
}


test "an empty or unreadable module defaults to server" {
    assert module_spaces(None) == {"server"};
    facts = discover_spaces([_fixture("does_not_exist.jac")]);
    assert facts[os.path.abspath(_fixture("does_not_exist.jac"))] == {"server"};
}


test "discover_spaces batches paths and client_only_paths filters them" {
    paths = [_fixture("infer_client_app.jac"), _fixture("infer_three_spaces.jac")];
    facts = discover_spaces(paths);
    assert facts[os.path.abspath(paths[0])] == {"client"};
    assert "server" in facts[os.path.abspath(paths[1])];
    assert client_only_paths(paths) == {os.path.abspath(paths[0])};
}


test "require_project_root is loud where project_root_of is soft" {
    d = tempfile.mkdtemp(prefix="jac-no-project-");
    outside = os.path.join(d, "orphan.jac");
    assert project_root_of(outside) is None;
    caught = False;
    try {
        require_project_root(outside);
    } except ValueError {
        caught = True;
    }
    assert caught;
}


test "sealed images persist placement and expose it without re-derivation" {
    import json;
    import from jaclang.jac0core.placement_facts { sealed_spaces_for }
    import from jaclang.jac0core.sealed { SealedImage, MANIFEST_FORMAT }
    d = tempfile.mkdtemp(prefix="jac-sealed-facts-");
    pre = os.path.join(d, "_precompiled");
    os.makedirs(pre);
    manifest = {
        "format": MANIFEST_FORMAT,
        "package": "app",
        "python_tag": "cpython-312",
        "modules": {"svc.jac": {"module": "app.svc", "jir": "svc.jir"}},
        "placement": {"svc.jac": ["server"], "ui/page.jac": ["client"]}
    };
    with open(os.path.join(pre, "MANIFEST.json"), "w") as f {
        json.dump(manifest, f);
    }
    assert sealed_spaces_for(os.path.join(d, "svc.jac")) == {"server"};
    assert sealed_spaces_for(os.path.join(d, "ui", "page.jac")) == {"client"};
    assert sealed_spaces_for(os.path.join(d, "unknown.jac")) is None;
    import from pathlib { Path }
    img = SealedImage(Path(pre), manifest);
    assert img.placement == {"svc.jac": ["server"], "ui/page.jac": ["client"]};
    old = SealedImage(Path(pre), {"format": 4, "package": "app", "modules": {}});
    assert old.placement == {};
}


test "toolchain native policy matches na_stdlib and desktop native trees" {
    pkg = os.path.join(JAC_ROOT, "jaclang");
    na = os.path.join(pkg, "runtimelib", "na_stdlib", "_bz2_native.jac");
    assert toolchain_native_by_policy(pkg, na);
    other = os.path.join(pkg, "utils", "precompile_bytecode.jac");
    assert not toolchain_native_by_policy(pkg, other);
}
