"""npm import handling in the cl test runner.

Client tests run under bun in a sealed temp dir with no `node_modules`, so
every non-relative import spec has to be rewritten to something bun can
resolve.  These cover that rewriting for modules that are not `@jac/runtime`:
the universal Proxy fallback, and the per-module mock overrides declared in
`[test.npm-stubs]` that take precedence over it.
"""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtimelib.cl_test_runner {
    module_is_client,
    run_cl_test_file,
    _mock_stub_name,
    _resolve_npm_mocks
}

glob FIXTURES = Path(__file__).parent / "fixtures";

test "a client test importing only an npm module runs under bun" {
    # Regression guard: npm stubbing used to sit inside the `@jac/runtime`
    # branch of _run_harness, so a client test with no backend import kept its
    # bare `fake-npm-pkg` spec and bun failed to resolve it.
    fixture = str(FIXTURES / "cl_npm" / "test_npm_only.jac");
    assert module_is_client(fixture) , f"{fixture} is not in the client codespace";

    results = run_cl_test_file(fixture);
    assert results , "cl test runner discovered no client tests";
    for res in results {
        assert res.ok , f"cl test {res.name} failed: {res.error}";
    }
}

test "mapped npm modules behave while unmapped ones keep the proxy" {
    # The mocks return values, record calls, and are written in both JS and
    # Jac; `unmapped-pkg` in the same file still falls through to the Proxy.
    fixture = str(FIXTURES / "cl_npm_mock" / "test_mocked.jac");
    results = run_cl_test_file(fixture);
    assert len(results) == 4 , f"expected 4 client tests, got {len(results)}";
    for res in results {
        assert res.ok , f"cl test {res.name} failed: {res.error}";
    }
}

test "npm stub overrides are read from the nearest jac.toml" {
    mocks = _resolve_npm_mocks(str(FIXTURES / "cl_npm_mock" / "test_mocked.jac"));
    assert sorted(mocks.keys()) == ["@fake/telemetry", "fake-editor"];
    for (spec, path) in mocks.items() {
        assert os.path.isabs(path) , f"{spec} resolved to a relative path: {path}";
        assert os.path.isfile(path) , f"{spec} resolved to a missing file: {path}";
    }
}

test "a project without npm stub overrides resolves to an empty map" {
    assert _resolve_npm_mocks(str(FIXTURES / "cl_npm" / "test_npm_only.jac")) == {};
    assert _resolve_npm_mocks(None) == {};
}

test "stub filenames are flat, prefixed, and collision-free per spec" {
    # The work dir is flat, so a spec has to sanitize to a name that cannot
    # collide with a staged dep or the runtime files written beside it.
    assert _mock_stub_name("vscode").startswith("__jac_mock_vscode_");
    assert _mock_stub_name("@scope/pkg").startswith("__jac_mock__scope_pkg_");
    assert _mock_stub_name("vscode") == _mock_stub_name("vscode");

    # Sanitizing alone would collapse these onto one filename, so the name
    # carries a digest of the spec it came from.
    assert _mock_stub_name("a/b/c") != _mock_stub_name("a_b_c");

    seen = set();
    for spec in ["vscode", "@scope/pkg", "lodash.merge", "a/b/c", "a_b_c"] {
        name = _mock_stub_name(spec);
        assert name.startswith("__jac_mock_") , f"{spec} -> {name}";
        assert name.endswith(".js") , f"{spec} -> {name}";
        assert name not in ("jac_runtime.js", "client_runtime_core.js");
        assert name not in seen , f"{spec} collided on {name}";
        seen.add(name);
    }
}

test "a mock path that does not exist fails with a message naming the spec" {
    with TemporaryDirectory() as td {
        Path(td, "jac.toml").write_text(
            '[project]\nname = "x"\n\n[test.npm-stubs]\n'
            'vscode = "mocks/missing.js"\n',
            encoding="utf-8"
        );
        entry = Path(td, "test_x.jac");
        entry.write_text('import from "vscode" { window }\n', encoding="utf-8");
        caught = "";
        try {
            _resolve_npm_mocks(str(entry));
        } except Exception as exc {
            caught = str(exc);
        }
        assert "vscode" in caught , f"error did not name the spec: {caught}";
        assert "missing.js" in caught , f"error did not name the path: {caught}";
        # The directory the path was resolved against is the actionable part:
        # it says *where* the runner looked.
        assert td in caught , f"error did not name the search dir: {caught}";
    }
}
