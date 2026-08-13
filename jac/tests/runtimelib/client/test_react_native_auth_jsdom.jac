"""jsdom behavioral test for `AuthGuard` on the react-native backend.

react-native shares the web `AuthGuard` contract but has its own implementation
(`client/impl/client_runtime_native.impl.jac`), including a token-priming gate:
`SecureStore` is async, so the guard renders nothing until the cached token is
primed. That extra state made it the backend most likely to drift, and like the
web one it had no executable coverage of the children path.

The real compiled native runtime + core are mounted here with React under jsdom;
only the platform packages the runtime imports (`react-native`,
`@react-navigation/*`, `expo-*`) are replaced by stubs, the same way jsdom
stands in for a browser. Navigation itself -- the native route table,
`NavigationContainer` wiring -- is exercised by the react-native target's own
tests, not here; what this pins is the branch the fix changed:

  logged in  + children  -> the children render (this is the regression)
  logged in  + none      -> the `<Outlet/>` fallback, which renders nothing here
                            and must not crash
  logged out + children  -> the protected children do NOT render

Integration test: real `bun install` of react + jsdom, so it runs only when
`JAC_CLIENT_INTEGRATION` is set (mirrors `test_react_state_semantics.jac`).
"""

import json;
import os;
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
import from jaclang.runtimelib.client.bun_installer { get_bun }

glob _CLIENT_DIR = Path(__file__).parent.parent.parent.parent
         / "jaclang"
         / "runtimelib"
         / "client",
     # Only what the guard's own path needs; the react-native / expo packages
     # are stubbed (they are Metro-only source and cannot load in node).
     _DEPS: dict[str, str] = {
         "jsdom": "^24.0.0",
         "react": "^18.2.0",
         "react-dom": "^18.2.0",
         "react-error-boundary": "^5.0.0",
         "zod": "^4.3.6"
     },
     # Bare specifier -> stub module the harness writes. `expo-secure-store` is
     # the load-bearing one: the guard's priming gate reads the token through it,
     # so the stub is a real async key-value store rather than a no-op.
     _PLATFORM_STUBS: dict[str, str] = {
         "react-native": """
// Host-tag stand-ins: jsdom renders unknown elements fine, so the native tree
// is still inspectable by `data-testid`.
export const View = "rn-view";
export const Text = "rn-text";
export const Pressable = "rn-pressable";
export const TextInput = "rn-textinput";
export const Image = "rn-image";
export const Linking = { openURL: async () => {} };
""",
         "@react-navigation/native": """
export const NavigationContainer = (props) => props.children ?? null;
export const CommonActions = { navigate: (...a) => ({ type: "NAVIGATE", payload: a }) };
export const __jacNavigations = [];
export const useNavigation = () => ({
  navigate: (...a) => __jacNavigations.push(a),
  dispatch: (...a) => __jacNavigations.push(a),
  goBack: () => {},
});
export const useRoute = () => ({ name: "", params: {} });
""",
         "@react-navigation/native-stack": """
export const createNativeStackNavigator = () => ({
  Navigator: (props) => props.children ?? null,
  Screen: () => null,
});
""",
         "expo-secure-store": """
const store = new Map();
export const getItemAsync = async (k) => (store.has(k) ? store.get(k) : null);
export const setItemAsync = async (k, v) => { store.set(k, v); };
export const deleteItemAsync = async (k) => { store.delete(k); };
// Test seam: put a token in place before the runtime primes its cache.
export const __seed = (k, v) => { store.set(k, v); };
""",
         "expo-constants": """
export default { expoConfig: { extra: {} }, manifest: { extra: {} } };
""",
         "react-hook-form": """
export const useForm = () => ({});
""",
         "@hookform/resolvers/zod": """
export const zodResolver = () => () => ({ values: {}, errors: {} });
"""
     },
     # Mount the guard three ways under jsdom. Each scenario is a fresh process,
     # so the priming globals (`__jacNativeTokenPrimed__`) start clean.
     # A plain (non-f) string so JS `${}` / `{}` need no escaping.
     _HARNESS: str = """
import { JSDOM } from "jsdom";

const [scenario] = process.argv.slice(2);
const loggedIn = scenario !== "loggedOut";

const dom = new JSDOM(
  '<!DOCTYPE html><html><body><div id="__jac_root"></div></body></html>',
  { url: "http://localhost/", pretendToBeVisual: true }
);
const { window } = dom;
globalThis.window = window;
for (const k of [
  "document", "navigator", "HTMLElement", "Element", "SVGElement", "Node",
  "Text", "Comment", "DocumentFragment", "Event", "CustomEvent", "MouseEvent",
  "KeyboardEvent", "getComputedStyle", "DOMParser", "localStorage",
]) {
  if (window[k] === undefined) continue;
  try { globalThis[k] = window[k]; } catch {}
}
globalThis.requestAnimationFrame =
  window.requestAnimationFrame || ((cb) => setTimeout(() => cb(Date.now()), 0));
globalThis.cancelAnimationFrame = window.cancelAnimationFrame || clearTimeout;
globalThis.IS_REACT_ACT_ENVIRONMENT = false;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const failures = [];
const check = (label, ok, detail) => {
  console.log(`${ok ? "PASS" : "FAIL"}  [${scenario}] ${label}${detail ? "  -- " + detail : ""}`);
  if (!ok) failures.push(label);
};
const present = (testid) => !!document.querySelector(`[data-testid="${testid}"]`);
const finish = () => {
  console.log(`\\n[${scenario}] ${failures.length ? "FAILED" : "OK"}: ${failures.length} failure(s)` +
    (failures.length ? `: ${failures.join(", ")}` : ""));
  process.exit(failures.length ? 1 : 0);
};

let React, createRoot, SecureStore, runtime;
try {
  React = await import("react");
  ({ createRoot } = await import("react-dom/client"));
  SecureStore = await import("./expo-secure-store.js");
  // Seed BEFORE importing the runtime: `__jacWirePlatformAdapters` kicks off
  // the token prime as a side effect of wiring.
  if (loggedIn) SecureStore.__seed("jac_token", "test-token");
  runtime = await import("./client_runtime_native.js");
} catch (e) {
  check("native runtime imports under jsdom", false, String((e && e.stack) || e));
  finish();
}

const { AuthGuard, __jacWirePlatformAdapters } = runtime;
__jacWirePlatformAdapters();

const protectedChild = React.createElement(
  "div", { "data-testid": "protected" }, "protected"
);
// `withChildren` is the documented wrapper form; the bare element is the
// pathless-parent-route form that must keep falling back to `<Outlet/>`.
const tree = scenario === "loggedInNoChildren"
  ? React.createElement(AuthGuard, { redirect: "/signin" })
  : React.createElement(AuthGuard, { redirect: "/signin" }, protectedChild);

const mount = document.getElementById("__jac_root");
try {
  createRoot(mount).render(tree);
} catch (e) {
  check("AuthGuard mounts without throwing", false, String((e && e.stack) || e));
  finish();
}
// The guard renders nothing until the async SecureStore prime resolves and
// flips its `ready` state, so give the effect a couple of macrotasks.
await sleep(200);

if (scenario === "loggedIn") {
  check("renders its children when logged in", present("protected"),
    `html=${mount.innerHTML}`);
} else if (scenario === "loggedInNoChildren") {
  check("falls back to <Outlet/> (renders nothing, no crash)",
    mount.innerHTML === "", `html=${mount.innerHTML}`);
} else {
  check("does not render its children when logged out", !present("protected"),
    `html=${mount.innerHTML}`);
}
finish();
""";

"""Skip unless the client toolchain integration flag is set."""
def _require_client_integration {
    if not os.environ.get("JAC_CLIENT_INTEGRATION") {
        pytest.skip(
            "react-native AuthGuard jsdom test does a real bun install; "
            "set JAC_CLIENT_INTEGRATION=1 to run"
        );
    }
}

"""Compile a `.jac` to JS with the React backend; type errors are non-fatal."""
def _compile_react(path: Path) -> str {
    prog = JacProgram();
    # type_check=True so typed builtin calls (e.g. `len(list)`) lower to their JS
    # forms, matching the production bundler pipeline.
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

"""Point every stubbed platform specifier at the flat sibling the harness
writes -- the same rewrite the other jsdom suites apply to `@jac/runtime`,
extended to the Metro-only packages node cannot load."""
def _wire_platform_stubs(js: str) -> str {
    for spec in _PLATFORM_STUBS.keys() {
        flat = spec.replace("@", "").replace("/", "_");
        for q in ['"', "'"] {
            js = js.replace(f"{q}{spec}{q}", f"{q}./{flat}.js{q}");
        }
    }
    # The tag map is a real module, but it lands flat in the work dir.
    return js.replace(
        '"./targets/react_native/html_tag_map.js"', '"./html_tag_map.js"'
    );
}

"""Emit `html_tag_map.js` the way `JacClientCompiler.compile_runtime_utils`
does: the tag lists are plain (non-`:pub`) globs, so the bundler re-exports them
from the Python module rather than from the compiled `.jac`."""
def _render_html_tag_map -> str {
    import json;
    import importlib;
    htm = importlib.import_module(
        "jaclang.runtimelib.client.targets.react_native.html_tag_map"
    );
    out = "";
    for const_name in sorted(dir(htm)) {
        vals = getattr(htm, const_name, None);
        if const_name.startswith("RN_") and isinstance(vals, list) {
            out += f"export const {const_name} = {json.dumps(vals)};\n";
        }
    }
    return out;
}

test "react-native AuthGuard renders children, falls back to Outlet, guards when out" {
    _require_client_integration();
    bun = get_bun();
    if bun is None {
        pytest.skip("bun is required but could not be located/installed");
    }

    modules = {
        "client_runtime_native.js": _CLIENT_DIR / "client_runtime_native.jac",
        "client_runtime_core.js": _CLIENT_DIR / "client_runtime_core.jac"
    };

    with TemporaryDirectory() as tmp {
        work = Path(tmp);
        for (name, src) in modules.items() {
            (work / name).write_text(
                _wire_platform_stubs(_compile_react(src)), encoding="utf-8"
            );
        }
        (work / "html_tag_map.js").write_text(_render_html_tag_map(), encoding="utf-8");
        for (spec, body) in _PLATFORM_STUBS.items() {
            flat = spec.replace("@", "").replace("/", "_");
            (work / f"{flat}.js").write_text(body, encoding="utf-8");
        }
        (work / "harness.mjs").write_text(_HARNESS, encoding="utf-8");
        (work / "package.json").write_text(
            json.dumps(
                {
                    "name": "react-native-authguard-jsdom-test",
                    "private": True,
                    "type": "module",
                    "dependencies": _DEPS
                }
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
        node_bin = shutil.which("node");
        for scenario in ["loggedIn", "loggedInNoChildren", "loggedOut"] {
            if node_bin {
                cmd = [node_bin, str(work / "harness.mjs"), scenario];
            } else {
                cmd = [bun, "run", str(work / "harness.mjs"), scenario];
            }
            run = subprocess.run(
                cmd, cwd=str(work), capture_output=True, text=True, timeout=120
            );
            detail = (run.stdout or "") + "\n" + (run.stderr or "");
            assert run.returncode == 0 , (
                f"native AuthGuard harness [{scenario}] failed "
                f"(exit {run.returncode}):\n{detail}"
            );
        }
    }
}
