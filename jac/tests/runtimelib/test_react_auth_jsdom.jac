"""jsdom behavioral tests for `AuthGuard` on the React (web) backend.

`AuthGuard` had no React test at all: the only executable coverage lived in
`test_solid_jsdom.jac`, and Solid is the one backend whose implementation was
already children-aware. That gap is what let two defects ship --
`AuthGuard` discarding its JSX children (blank protected page in manual
routing) and `[client.routing] auth_redirect` being dropped by the generated
entry -- so this suite pins the guard's render contract for React.

Crucially it asserts the LOGGED-IN render, not just the logged-out redirect: a
guard that renders nothing blocks anonymous users perfectly well, so a
redirect-only test passes on both broken implementations.

  Manual routing (`_MANUAL_HARNESS`, `fixtures/react_auth/manual_routing_app.jac`)
    /wrapped         guard wrapping a page as a route `element` -> page renders
    /nested          guard as a pathless PARENT route -> child route renders
    /layout-guarded  layout wrapping `<Outlet/>` in the guard -> child renders
    /bare            guard with neither children nor child routes -> no crash
    ...each in both auth states; logged out must land on `/login`.

Deliberately not here: the generated entry's calling convention (pinned by
`test_react_backend.jac`) and react-native's matching signature (by
`test_client_runtime_parity.jac`) -- both ungated, neither needs a bun install.

Integration test: real `bun install` of react + react-router + jsdom, so it runs
only when `JAC_CLIENT_INTEGRATION` is set (mirrors `test_react_state_semantics.jac`).
"""

import json;
import os;
import re;
import shutil;
import subprocess;
import pytest;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.ecmascript { EsastGenPass }
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.compiler.passes.ecmascript.backends.react { ReactBackend }
import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
import from jaclang.runtimelib.client_surface { with_runtime_globals }
import from jaclang.runtimelib.runtime_source { resolve_client_runtime_cl_path }
import from jaclang.runtimelib.client.bun_installer { get_bun }

glob FIXTURES = str(Path(__file__).parent / "fixtures" / "react_auth"),
     # Mirrors `_default_client_deps("react")` runtime deps; jsdom is test-only.
     _DEPS: dict[str, str] = {
         "jsdom": "^24.0.0",
         "react": "^18.2.0",
         "react-dom": "^18.2.0",
         "react-router-dom": "^6.22.0",
         "react-error-boundary": "^5.0.0",
         "@tanstack/react-form": "^1.33.0",
         "zod": "^4.3.6"
     },
     # Shared jsdom bootstrap: build a DOM AT THE SCENARIO'S URL (BrowserRouter
     # reads `window.location`), seed/clear the `jac_token` `jacIsLoggedIn()`
     # reads, and publish the browser globals react-dom needs. `mountId` differs
     # per harness, so each one prepends its own `const mountId = ...`.
     # A plain (non-f) string so JS `${}` / `{}` need no escaping.
     _JSDOM_BOOT: str = """
import { JSDOM } from "jsdom";

const [startUrl, authState] = process.argv.slice(2);
const loggedIn = authState === "loggedIn";
const tag = `[${startUrl} ${authState}]`;

const dom = new JSDOM(
  `<!DOCTYPE html><html><body><div id="${mountId}"></div></body></html>`,
  { url: "http://localhost" + startUrl, pretendToBeVisual: true }
);
const { window } = dom;
globalThis.window = window;
for (const k of [
  "document", "navigator", "HTMLElement", "Element", "SVGElement", "Node",
  "Text", "Comment", "DocumentFragment", "Event", "CustomEvent", "MouseEvent",
  "KeyboardEvent", "getComputedStyle", "DOMParser", "localStorage", "history",
  "location",
]) {
  if (window[k] === undefined) continue;
  try { globalThis[k] = window[k]; } catch {}
}
globalThis.requestAnimationFrame =
  window.requestAnimationFrame || ((cb) => setTimeout(() => cb(Date.now()), 0));
globalThis.cancelAnimationFrame = window.cancelAnimationFrame || clearTimeout;
globalThis.IS_REACT_ACT_ENVIRONMENT = false;

if (loggedIn) window.localStorage.setItem("jac_token", "test-token");
else window.localStorage.removeItem("jac_token");

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const failures = [];
const check = (label, ok, detail) => {
  console.log(`${ok ? "PASS" : "FAIL"}  ${tag} ${label}${detail ? "  -- " + detail : ""}`);
  if (!ok) failures.push(label);
};
const present = (testid) => !!document.querySelector(`[data-testid="${testid}"]`);
const finish = () => {
  console.log(`\\n${tag} ${failures.length ? "FAILED" : "OK"}: ${failures.length} failure(s)` +
    (failures.length ? `: ${failures.join(", ")}` : ""));
  process.exit(failures.length ? 1 : 0);
};

/* Assert one scenario's expectation row against the mounted DOM. */
const assertExpectation = (expect, html) => {
  for (const id of expect.present) {
    check(`renders [data-testid="${id}"]`, present(id), `html=${html()}`);
  }
  for (const id of expect.absent) {
    check(`does not render [data-testid="${id}"]`, !present(id), `html=${html()}`);
  }
  check(`settles at ${expect.path}`, window.location.pathname === expect.path,
    `got: ${window.location.pathname}`);
};
""",
     # Manual-routing harness: mount the fixture app directly (no generated
     # entry) and assert the guard's four shapes in both auth states. `chrome`
     # is outside `<Routes>`, so "guard rendered nothing" stays distinguishable
     # from "the app never mounted" -- which is exactly the failure mode of the
     # children bug: a mounted app with an empty route slot.
     _MANUAL_HARNESS: str = "const mountId = \"__jac_root\";\n"
         + _JSDOM_BOOT
         + """
const EXPECT = {
  // The documented wrapper form. Logged in, the wrapped page must render; a
  // guard that ignores its children renders an empty `<Outlet/>` here instead.
  "/wrapped|loggedIn": { present: ["chrome", "dashboard"], absent: ["login"], path: "/wrapped" },
  "/wrapped|loggedOut": { present: ["chrome", "login"], absent: ["dashboard"], path: "/login" },
  // Guard as a pathless parent route: no children, so the `<Outlet/>` fallback
  // must still resolve the matched child route.
  "/nested|loggedIn": { present: ["chrome", "nested"], absent: ["login"], path: "/nested" },
  "/nested|loggedOut": { present: ["chrome", "login"], absent: ["nested"], path: "/login" },
  // The file-based `(auth)/layout.jac` shape: children ARE present (the user's
  // own `<Outlet/>`), and resolve to the same matched child route.
  "/layout-guarded|loggedIn": { present: ["chrome", "dashboard"], absent: ["login"], path: "/layout-guarded" },
  "/layout-guarded|loggedOut": { present: ["chrome", "login"], absent: ["dashboard"], path: "/login" },
  // Neither children nor child routes: renders nothing, must not crash.
  "/bare|loggedIn": { present: ["chrome"], absent: ["dashboard", "nested", "login"], path: "/bare" },
  "/bare|loggedOut": { present: ["chrome", "login"], absent: ["dashboard"], path: "/login" },
};

let React, createRoot, app;
try {
  React = await import("react");
  ({ createRoot } = await import("react-dom/client"));
  ({ app } = await import("./component.js"));
} catch (e) {
  check("runtime modules import under jsdom", false, String((e && e.stack) || e));
  finish();
}

const mount = document.getElementById(mountId);
try {
  createRoot(mount).render(React.createElement(app));
} catch (e) {
  check("render() mounts without throwing", false, String((e && e.stack) || e));
  finish();
}
await sleep(150);

const expect = EXPECT[`${startUrl}|${authState}`];
if (!expect) {
  check(`known scenario ${startUrl}|${authState}`, false, "no expectation row");
  finish();
}
assertExpectation(expect, () => mount.innerHTML);
finish();
""";

"""Skip unless the client toolchain integration flag is set."""
def _require_client_integration {
    if not os.environ.get("JAC_CLIENT_INTEGRATION") {
        pytest.skip(
            "React AuthGuard jsdom test does a real bun install; "
            "set JAC_CLIENT_INTEGRATION=1 to run"
        );
    }
}

"""Compile a `.jac` to JS with the React backend; type errors are non-fatal."""
def _compile_react(path: str) -> str {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(path), options=CompileOptions(type_check=True, no_cgen=True)
    );
    fatal = [
        e
        for e in prog.errors_had
        if not issubclass(e.from_pass, TypeCheckPass)
    ];
    assert not fatal , f"compile errors in {path}: {[str(e) for e in fatal]}";
    es_pass = EsastGenPass(ir_in=ir, prog=prog, backend=ReactBackend());
    return es_to_js(es_pass.ir_out.gen.es_ast);
}

"""Point the shim's dotted core import at a flat sibling (mirrors the bundler)."""
def _rewrite_core_specifier(runtime_js: str) -> str {
    m = re.search(r"""["'](\.[^"']*client_runtime_core\.js)["']""", runtime_js);
    if m {
        return runtime_js.replace(m.group(1), "./client_runtime_core.js");
    }
    return runtime_js;
}

"""Rewrite every `@jac/runtime` specifier to the flat sibling the harness writes
(`./jac_runtime.js`) -- mirrors how the bundler resolves the virtual module."""
def _wire_jac_runtime(js: str) -> str {
    for q in ['"', "'"] {
        js = js.replace(f"{q}@jac/runtime{q}", f"{q}./jac_runtime.js{q}");
    }
    return js;
}

"""Compile a page/layout/app `.jac`, prepend its `@jac/runtime` globals (the bare
`__jacJsx` the compiler emits), and wire the runtime specifier."""
def _compile_page(path: str, backend: any) -> str {
    return _wire_jac_runtime(with_runtime_globals(_compile_react(path), backend));
}

"""Emit the compiled `@jac/runtime` shim + its core into the work dir."""
def _write_runtime(work: Path) {
    runtime_path = resolve_client_runtime_cl_path("react");
    (work / "jac_runtime.js").write_text(
        _rewrite_core_specifier(_compile_react(runtime_path)), encoding="utf-8"
    );
    (work / "client_runtime_core.js").write_text(
        _compile_react(str(Path(runtime_path).parent / "client_runtime_core.jac")),
        encoding="utf-8"
    );
}

"""`bun install` the shared dep set into `work`."""
def _bun_install(bun: str, work: Path, name: str) {
    (work / "package.json").write_text(
        json.dumps(
            {"name": name, "private": True, "type": "module", "dependencies": _DEPS}
        ),
        encoding="utf-8"
    );
    install = subprocess.run(
        [bun, "install"], cwd=str(work), capture_output=True, text=True, timeout=300
    );
    assert install.returncode == 0 , (
        f"bun install failed (exit {install.returncode}):\n"
        f"{install.stdout}\n{install.stderr}"
    );
}

"""Run the harness once per scenario in a fresh process, so each starts at its
own URL and auth state with a clean module graph (the entry renders on import)."""
def _run_scenarios(bun: str, work: Path, scenarios: list, label: str) {
    node_bin = shutil.which("node");
    for sc in scenarios {
        if node_bin {
            cmd = [node_bin, str(work / "harness.mjs"), sc[0], sc[1]];
        } else {
            cmd = [bun, "run", str(work / "harness.mjs"), sc[0], sc[1]];
        }
        run = subprocess.run(
            cmd, cwd=str(work), capture_output=True, text=True, timeout=120
        );
        detail = (run.stdout or "") + "\n" + (run.stderr or "");
        assert run.returncode == 0 , (
            f"{label} harness {sc} failed (exit {run.returncode}):\n{detail}"
        );
    }
}

test "react AuthGuard renders children, child routes, and nothing -- in jsdom" {
    _require_client_integration();
    bun = get_bun();
    if bun is None {
        pytest.skip("bun is required but could not be located/installed");
    }

    backend = ReactBackend();
    component_js = _compile_page(
        os.path.join(FIXTURES, "manual_routing_app.jac"), backend
    );

    with TemporaryDirectory() as tmp {
        work = Path(tmp);
        (work / "component.js").write_text(component_js, encoding="utf-8");
        _write_runtime(work);
        (work / "harness.mjs").write_text(_MANUAL_HARNESS, encoding="utf-8");
        _bun_install(bun, work, "react-authguard-jsdom-test");
        _run_scenarios(
            bun,
            work,
            [
                ["/wrapped", "loggedIn"],
                ["/wrapped", "loggedOut"],
                ["/nested", "loggedIn"],
                ["/nested", "loggedOut"],
                ["/layout-guarded", "loggedIn"],
                ["/layout-guarded", "loggedOut"],
                ["/bare", "loggedIn"],
                ["/bare", "loggedOut"]
            ],
            "manual-routing"
        );
    }
}
