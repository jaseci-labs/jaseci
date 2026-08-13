"""Project-aware npm resolution in the cl test runner.

Client tests run under bun in a temp dir with no `node_modules`, so every bare
specifier has to be given somewhere to resolve to.  Rather than rewriting the
generated JS, the runner resolves each spec through ordered tiers -- mock,
`@jac/*` virtual module, then a universal Proxy stub -- and materializes the
result as a generated `tsconfig.json` that bun honours natively.
"""

import json;
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtimelib.cl_test_runner {
    module_is_client,
    run_cl_test_file,
    _mock_sources_for,
    _render_tsconfig,
    _scan_import_specs
}

glob FIXTURES = Path(__file__).parent / "fixtures";

# ---------------------------------------------------------------- scanning

test "scanning finds specs and bindings in every static import form" {
    # The stub must declare the names taken from it -- bun statically checks
    # named exports, so a missed binding is a hard ESM error.
    src = 'import { widget } from "pkg-widget";\n'
        + 'import def from "pkg-default";\n'
        + 'import * as ns from "pkg-ns";\n'
        + 'import "pkg-side/theme.css";\n'
        + 'export { helper } from "pkg-reexport";\n'
        + 'import { near } from "./local.js";\n';

    uses = _scan_import_specs(src);
    assert sorted(uses.keys())
        == [
            "pkg-default",
            "pkg-ns",
            "pkg-reexport",
            "pkg-side/theme.css",
            "pkg-widget"
        ] , f"unexpected specs: {sorted(uses.keys())}";

    assert "widget" in uses["pkg-widget"]["named"];
    assert "helper" in uses["pkg-reexport"]["named"];
    assert uses["pkg-default"]["default"];
    assert not uses["pkg-ns"]["default"] , "a namespace import needs no default export";
    assert uses["pkg-side/theme.css"]["named"] == set();
}

# ------------------------------------------------------------- materializing

test "the generated tsconfig sets baseUrl and one explicit entry per spec" {
    # A bare "*" mapping makes bun silently no-op: exit 0, nothing executed.
    # Specs are enumerated from the scan, so no wildcard is ever needed.
    text = _render_tsconfig(
        {
            "vscode": "./__mocks__/vscode.js",
            "@scope/pkg": "./__mocks__/@scope/pkg.js",
            "react": "./__jac_npm_stub.js"
        }
    );
    doc = json.loads(text);
    opts = doc["compilerOptions"];
    assert opts["baseUrl"] == "." , "bun needs baseUrl alongside paths";
    assert opts["paths"]["vscode"] == ["./__mocks__/vscode.js"];
    assert opts["paths"]["@scope/pkg"] == ["./__mocks__/@scope/pkg.js"];
    assert "*" not in opts["paths"] , "a catch-all wildcard silently disables resolution";
}

# ------------------------------------------------------------- mock discovery

test "a mock is discovered by the __mocks__ convention with no config entry" {
    with TemporaryDirectory() as td {
        Path(td, "jac.toml").write_text('[project]\nname = "x"\n', encoding="utf-8");
        mocks = Path(td, "tests", "__mocks__", "@scope");
        mocks.mkdir(parents=True);
        Path(td, "tests", "__mocks__", "vscode.js").write_text("export const a=1;\n");
        (mocks / "pkg.jac").write_text("glob:pub A = 1;\n", encoding="utf-8");
        found = _mock_sources_for(str(Path(td, "test_x.jac")));
        assert sorted(found.keys()) == ["@scope/pkg", "vscode"] , f"got {found}";
        assert found["vscode"].endswith("tests/__mocks__/vscode.js");
        assert found["@scope/pkg"].endswith("tests/__mocks__/@scope/pkg.jac");
    }
}

test "an explicit [test.client.mocks] entry overrides the convention" {
    with TemporaryDirectory() as td {
        Path(td, "jac.toml").write_text(
            '[project]\nname = "x"\n\n[test.client.mocks]\n'
            'vscode = "doubles/editor.js"\n',
            encoding="utf-8"
        );
        Path(td, "tests", "__mocks__").mkdir(parents=True);
        Path(td, "tests", "__mocks__", "vscode.js").write_text("export const a=1;\n");
        Path(td, "doubles").mkdir();
        Path(td, "doubles", "editor.js").write_text("export const b=2;\n");
        found = _mock_sources_for(str(Path(td, "test_x.jac")));
        assert found["vscode"].endswith("doubles/editor.js") , f"got {found['vscode']}";
    }
}

test "a project with no mocks at all resolves to an empty map" {
    assert _mock_sources_for(str(FIXTURES / "cl_npm" / "test_npm_only.jac")) == {};
    assert _mock_sources_for(None) == {};
}

test "a configured mock path that does not exist names the spec and the search dir" {
    with TemporaryDirectory() as td {
        Path(td, "jac.toml").write_text(
            '[project]\nname = "x"\n\n[test.client.mocks]\n'
            'vscode = "doubles/missing.js"\n',
            encoding="utf-8"
        );
        caught = "";
        try {
            _mock_sources_for(str(Path(td, "test_x.jac")));
        } except Exception as exc {
            caught = str(exc);
        }
        assert "vscode" in caught , f"error did not name the spec: {caught}";
        assert "missing.js" in caught , f"error did not name the path: {caught}";
        assert td in caught , f"error did not name the search dir: {caught}";
    }
}

# --------------------------------------------------------------- end to end

test "a client test importing only an npm module runs under bun" {
    # Regression guard: npm handling used to sit inside the `@jac/runtime`
    # branch of _run_harness, so a test with no backend import never reached it.
    fixture = str(FIXTURES / "cl_npm" / "test_npm_only.jac");
    assert module_is_client(fixture) , f"{fixture} is not in the client codespace";
    results = run_cl_test_file(fixture);
    assert results , "cl test runner discovered no client tests";
    for res in results {
        assert res.ok , f"cl test {res.name} failed: {res.error}";
    }
}

test "mocked modules behave while unmapped ones keep the proxy" {
    fixture = str(FIXTURES / "cl_npm_mock" / "test_mocked.jac");
    results = run_cl_test_file(fixture);
    assert len(results) == 4 , f"expected 4 client tests, got {len(results)}";
    for res in results {
        assert res.ok , f"cl test {res.name} failed: {res.error}";
    }
}

test "a mock may itself re-export and side-effect import" {
    # Resolution is by tsconfig path, not by rewriting text, so import forms
    # the old regex never matched now resolve on their own.
    fixture = str(FIXTURES / "cl_npm_forms" / "test_forms.jac");
    results = run_cl_test_file(fixture);
    assert len(results) == 2 , f"expected 2 client tests, got {len(results)}";
    for res in results {
        assert res.ok , f"cl test {res.name} failed: {res.error}";
    }
}

test "__mocks__ modules are not collected as tests themselves" {
    import from jaclang.pytest_plugin { _is_excluded_support_dir }
    assert _is_excluded_support_dir(Path("/p/tests/__mocks__/vscode.jac"));
    assert _is_excluded_support_dir(Path("/p/tests/fixtures/thing.jac"));
    assert not _is_excluded_support_dir(Path("/p/tests/test_real.jac"));
}
