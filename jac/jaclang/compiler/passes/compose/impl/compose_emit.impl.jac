"""ComposeEmit — ComposeModule → Gradle Android project on disk."""
import from pathlib { Path }
import from jaclang.compiler.passes.compose.compose_model { ComposeModule }
import from jaclang.compiler.passes.ecmascript.intent.model { IntentComponent }
import from jaclang.compiler.passes.compose.gradle_scaffold {
    build_gradle_scaffold,
    package_to_path,
    emit_jac_design,
    ensure_gradle_wrapper,
    escape_kotlin
}
import from jaclang.compiler.passes.compose.rpc_client { emit_jac_client }
import from jaclang.compiler.passes.compose.compose_native_emit { ComposeNativeEmitter }
import from jaclang.compiler.passes.compose.reactive_compose { ReactiveComposeEmitter }

impl normalize_route_segment(segment: str) -> str {
    if not segment {
        return "";
    }
    words: list[str] = [];
    current = "";
    for ch in segment {
        if ch.isalnum() {
            current += ch;
        } elif current {
            words.append(current);
            current = "";
        }
    }
    if current {
        words.append(current);
    }
    if not words {
        return "Route";
    }
    return "".join([w[0].upper() + w[1:] if w else "" for w in words]);
}

impl route_to_screen_name(path: str) -> str {
    if not path or path == "/" {
        return "HomeScreen";
    }
    parts = [p for p in path.strip("/").split("/") if p];
    if not parts {
        return "HomeScreen";
    }
    return "".join([normalize_route_segment(p) for p in parts]) + "Screen";
}

impl component_screen_name(comp_name: str) -> str {
    if not comp_name {
        return "HomeScreen";
    }
    if comp_name.endswith("Screen") {
        return comp_name;
    }
    return f"{comp_name}Screen";
}

def _screen_imports -> str {
    # Open-vocabulary import surface. The emitter lowers any capitalized tag to
    # a near-identity composable call (compose_native_emit._emit_element), so the
    # imports must cover the whole standard Compose surface, not a hand-listed
    # subset — otherwise off-list widgets (Slider, AlertDialog, DropdownMenu, …)
    # emit fine but fail to compile. Wildcarding the Compose packages makes the
    # entire Material3 + foundation vocabulary resolve with zero per-widget work.
    #
    # Safe against Kotlin star-import collisions: we pull material3 only (never
    # androidx.compose.material, its twin), and the foundation/ui subpackages
    # below have disjoint simple-name sets. Non-Compose symbols stay explicit.
    return """import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.lazy.grid.*
import androidx.compose.foundation.shape.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.text.font.*
import androidx.compose.ui.unit.*
import androidx.compose.ui.platform.LocalContext
import androidx.activity.compose.BackHandler
import android.content.Intent
import android.net.Uri
import kotlinx.coroutines.launch
""";
}

def _section_registry_stub -> str {
    return """
class JacSectionRegistry {
    val positions = mutableMapOf<String, Int>()
}

private data class JacRouteEntry(val path: String, val fragment: String?)
""";
}

impl ComposeEmit.emit_jac_app -> str {
    routes = list(self.model.intent.routes);
    paths: list[str] = [];
    path_to_screen: dict[str, str] = {};
    if routes {
        for r in routes {
            paths.append(r.path);
            path_to_screen[r.path] = r.screen_name or route_to_screen_name(r.path);
        }
    } else {
        for comp in self.model.intent.components.values() {
            if comp.route_path {
                paths.append(comp.route_path);
                path_to_screen[comp.route_path] = route_to_screen_name(comp.route_path);
            } elif comp.is_screen {
                paths.append("/");
                path_to_screen["/"] = route_to_screen_name("/");
            }
        }
    }
    if not paths {
        paths = ["/"];
        path_to_screen["/"] = route_to_screen_name("/");
    }

    when_arms: list[str] = [];
    for path in paths {
        screen = path_to_screen.get(path) or route_to_screen_name(path);
        when_arms.append(
            f'                    "{escape_kotlin(path)}" -> Box(modifier = Modifier.fillMaxSize().verticalScroll(scrollState)) {{ '
            f"{screen}(viewportWidth, scrollState, sectionRegistry, ::navigate, ::goBack, ::openExternal) }}"
        );
    }
    first_screen = path_to_screen.get(paths[0]) or route_to_screen_name(paths[0]);
    when_arms.append(
        f"                    else -> Box(modifier = Modifier.fillMaxSize().verticalScroll(scrollState)) {{ "
        f"{first_screen}(viewportWidth, scrollState, sectionRegistry, ::navigate, ::goBack, ::openExternal) }}"
    );
    arms = "\n".join(when_arms);

    # HMR route persistence (dev only): survive a DexClassLoader swap by restoring
    # the last route from SharedPreferences. It lives entirely in the hot module
    # — SharedPreferences is app storage, so it persists across dex reloads
    # (unlike a classloader-bound static, which a new classloader would reset).
    # Release keeps the simple startPath path.
    if self.dev {
        context_init = (
            "    val context = LocalContext.current\n"
            '    val hmr = context.getSharedPreferences("jac-hmr", android.content.Context.MODE_PRIVATE)\n'
            '    val restoredPath = hmr.getString("path", null)?.takeIf { JacRoutes.paths.contains(it) }\n'
            "    val initialPath = restoredPath ?: (if (JacRoutes.paths.contains(startPath)) startPath else JacRoutes.initialPath)\n"
        );
        persist_effect = (
            "    LaunchedEffect(currentEntry.path) {\n"
            '        hmr.edit().putString("path", currentEntry.path).apply()\n'
            "    }\n"
        );
    } else {
        context_init = (
            "    val context = LocalContext.current\n"
            "    val initialPath = if (JacRoutes.paths.contains(startPath)) startPath else JacRoutes.initialPath\n"
        );
        persist_effect = "";
    }

    return f"""
@Composable
fun JacApp(startPath: String = JacRoutes.initialPath, startFragment: String? = null, navigationRequest: Int = 0) {{
{context_init}    val initialFragment = startFragment?.takeIf {{ JacRoutes.sections[initialPath]?.contains(it) == true }}
    var currentEntry by remember {{ mutableStateOf(JacRouteEntry(initialPath, initialFragment)) }}
    var externalUrl by remember {{ mutableStateOf<String?>(null) }}
    val backStack = remember {{ mutableStateListOf<JacRouteEntry>() }}
    val scrollState = rememberScrollState()
    val sectionRegistry = remember(currentEntry.path) {{ JacSectionRegistry() }}
    fun navigate(operation: String, target: String, fragment: String?) {{
        val path = target.ifEmpty {{ currentEntry.path }}
        if (!JacRoutes.paths.contains(path)) {{
            return
        }}
        val destination = JacRouteEntry(path, fragment?.takeIf {{ JacRoutes.sections[path]?.contains(it) == true }})
        if (destination == currentEntry) {{
            return
        }}
        if (operation == "replace") {{
            currentEntry = destination
        }} else {{
            backStack.add(currentEntry)
            currentEntry = destination
        }}
    }}
    fun goBack() {{
        if (externalUrl != null) {{
            externalUrl = null
        }} else if (backStack.isNotEmpty()) {{
            currentEntry = backStack.removeAt(backStack.lastIndex)
        }} else if (currentEntry.path != JacRoutes.initialPath || currentEntry.fragment != null) {{
            currentEntry = JacRouteEntry(JacRoutes.initialPath, null)
        }}
    }}
    fun openExternal(mode: String, target: String) {{
        if (mode == "webview") {{
            externalUrl = target
        }} else {{
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(target)))
        }}
    }}
    LaunchedEffect(navigationRequest) {{
        navigate("replace", initialPath, initialFragment)
    }}
{persist_effect}    LaunchedEffect(currentEntry.path) {{
        scrollState.scrollTo(0)
    }}
    BackHandler(enabled = true) {{
        goBack()
    }}
    Box(modifier = Modifier.fillMaxSize().background(JacDesign.background)) {{
        BoxWithConstraints(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.TopStart) {{
            val viewportWidth = maxWidth
            when (currentEntry.path) {{
{arms}
            }}
        }}
    }}
}}
""";
}

def _emit_screen_fun(name: str, prelude: str, body: str) -> str {
    return f"""
@Composable
fun {name}(viewportWidth: Dp, scrollState: ScrollState, sectionRegistry: JacSectionRegistry, navigate: (String, String, String?) -> Unit, goBack: () -> Unit, openExternal: (String, String) -> Unit) {{
{prelude}{body}
}}
""";
}

def _merge_prelude(react_prelude: str, needs_scope: bool, body: str = "") -> str {
    if body and ("JacClient" in body or "scope.launch" in body) {
        needs_scope = True;
    }
    if needs_scope and "rememberCoroutineScope()" not in react_prelude {
        return "    val scope = rememberCoroutineScope()\n" + react_prelude;
    }
    return react_prelude;
}

def _emit_screen_body(
    comp: (IntentComponent | None), native_em: ComposeNativeEmitter, model: ComposeModule
) -> str {
    if comp is None {
        return "    Column(modifier = Modifier.fillMaxSize()) {\n    }";
    }
    view = model.compose_view_for(comp.name);
    if view is not None {
        return native_em.emit_view(view);
    }
    # P0 #2: the Compose framework has a single code path — native compose_view.
    # DOM/Tailwind IR (comp.view) is explicitly unsupported; record a diagnostic
    # so the fail-fast gate rejects it instead of silently emitting a lossy stub.
    if comp.view is not None {
        model.intent.add_diagnostic(
            f"component '{comp.name}' uses DOM IR (view), which the Compose "
            "framework does not support — use Compose primitives "
            "(Column, Text, Button, …)"
        );
    }
    return "    Column(modifier = Modifier.fillMaxSize()) {\n    }";
}

impl ComposeEmit.emit_screens -> str {
    pkg = self.model.intent.package_name;
    native_em = ComposeNativeEmitter();
    react_em = ReactiveComposeEmitter();

    screens: list[str] = [];
    seen: set[str] = set();

    for route in self.model.intent.routes {
        sname = route.screen_name or route_to_screen_name(route.path);
        if sname in seen {
            continue;
        }
        seen.add(sname);
        comp = None;
        if route.component and route.component in self.model.intent.components {
            comp = self.model.intent.components[route.component];
        }
        prelude = react_em.emit_prelude(comp) if comp else "";
        body = _emit_screen_body(comp, native_em, self.model);
        prelude = _merge_prelude(
            prelude,
            native_em.needs_coroutine_scope,
            body
        );
        screens.append(_emit_screen_fun(sname, prelude, body));
    }

    for (cname, comp) in self.model.intent.components.items() {
        sname: (str | None) = (
            component_screen_name(cname) if comp.is_screen else None
        );
        if comp.route_path {
            sname = route_to_screen_name(comp.route_path);
        } elif comp.is_screen {
            sname = component_screen_name(cname);
        } else {
            continue;
        }
        if sname is None or sname in seen {
            continue;
        }
        seen.add(sname);
        prelude = react_em.emit_prelude(comp);
        body = _emit_screen_body(comp, native_em, self.model);
        prelude = _merge_prelude(
            prelude,
            native_em.needs_coroutine_scope,
            body
        );
        screens.append(_emit_screen_fun(sname, prelude, body));
    }

    if not screens {
        for (cname, comp) in self.model.intent.components.items() {
            # Only native compose_view is a valid screen source now (P0 #2).
            if self.model.compose_view_for(cname) is None {
                continue;
            }
            sname = "HomeScreen" if cname in ("app", "__root__", "App") else component_screen_name(cname);
            if sname in seen {
                continue;
            }
            seen.add(sname);
            prelude = react_em.emit_prelude(comp);
            body = _emit_screen_body(comp, native_em, self.model);
            prelude = _merge_prelude(
                prelude,
                native_em.needs_coroutine_scope,
                body
            );
            screens.append(_emit_screen_fun(sname, prelude, body));
        }
    }

    if not screens {
        screens.append(
            _emit_screen_fun(
                "HomeScreen",
                "",
                "    Column(modifier = Modifier.fillMaxSize()) {\n"
                "        Text(text = \"Jac Compose\")\n"
                "    }"
            )
        );
    }

    for diag in native_em.diagnostics {
        self.model.intent.add_diagnostic(diag);
    }

    design = emit_jac_design();
    app = self.emit_jac_app();
    return (
        f"package {pkg}\n\n"
        + _screen_imports()
        + "\n"
        + design
        + "\n"
        + _section_registry_stub()
        + "\n"
        + app
        + "\n"
        + "\n".join(screens)
    );
}

def _prune_stale_kotlin(out: Path, java_root: str, keep: set[str]) -> int {
    # Delete generated .kt files under the package dir that this build no
    # longer emits. Scoped to the generated package directory only — never
    # touches Gradle build outputs, the wrapper, or resources. Returns the
    # number of files removed.
    pkg_dir = out / java_root;
    if not pkg_dir.is_dir() {
        return 0;
    }
    removed = 0;
    for path in pkg_dir.rglob("*.kt") {
        try {
            rel = path.relative_to(out).as_posix();
        } except Exception {
            continue;
        }
        if rel in keep {
            continue;
        }
        try {
            path.unlink();
            removed += 1;
        } except Exception {
            ;
        }
    }
    return removed;
}

impl ComposeEmit.write -> list[Path] {
    out = self.out_dir;
    out.mkdir(parents=True, exist_ok=True);

    routes: list[str] = [];
    for r in self.model.intent.routes {
        routes.append(r.path);
    }
    if not routes {
        for comp in self.model.intent.components.values() {
            if comp.route_path {
                routes.append(comp.route_path);
            }
        }
    }
    if not routes {
        routes = ["/"];
    }

    files = build_gradle_scaffold(
        self.model.intent.package_name,
        self.model.intent.app_name,
        self.model.intent.backend_url,
        routes,
        self.dev
    );

    pkg_path = package_to_path(self.model.intent.package_name);
    base_root = f"app/src/main/java/{pkg_path}";
    hot_root = f"hot/src/main/java/{pkg_path}";
    # In dev mode the screen/RPC sources live in the :hot module so they can be
    # dexed separately and DexClassLoader-swapped; in release they join the base.
    screens_root = hot_root if self.dev else base_root;
    # Emit the screen/RPC sources first — this runs every lowering pass and
    # populates self.model.intent.diagnostics (native view builder, jac_to_kotlin, …).
    screens_src = self.emit_screens();
    client_src = emit_jac_client(
        self.model.intent.package_name, self.model.intent.interop_manifest
    );
    # P0 #1 fail-fast gate: any diagnostic means the generated Kotlin would be
    # broken (unsupported construct, DOM IR, …). Abort before writing the
    # project so Gradle never assembles a broken / empty-screen APK.
    if self.model.intent.diagnostics {
        try {
            import from jaclang.cli.console { console }
            console.error("  Compose codegen failed with diagnostics:");
            for diag in self.model.intent.diagnostics {
                console.error(f"    - {diag}");
            }
        } except Exception {
            ;
        }
        raise RuntimeError(
            "Compose codegen produced diagnostics — refusing to emit a broken "
            "Android project. Fix the issues above (or use <Raw kotlin=\"…\"> "
            "for verbatim Kotlin where the surface is genuinely unsupported)."
        );
    }
    files[f"{screens_root}/Screens.kt"] = screens_src;
    files[f"{screens_root}/JacClient.kt"] = client_src;

    written: list[Path] = [];
    reused = 0;
    for (rel, content) in files.items() {
        path = out / rel;
        path.parent.mkdir(parents=True, exist_ok=True);
        # Content-aware emit: if an identical file already exists, leave it
        # untouched so its mtime is stable. Gradle's build cache and Kotlin's
        # incremental compiler then skip it — the gradle-cache win. Only .kt
        # and .kts/.xml/.properties inputs benefit from this, but comparing is
        # cheap and harmless for all.
        if path.is_file() {
            try {
                if path.read_text(encoding="utf-8") == content {
                    reused += 1;
                    written.append(path);
                    continue;
                }
            } except Exception {
                ;
            }
        }
        path.write_text(content, encoding="utf-8");
        written.append(path);
    }

    # Prune stale generated Kotlin sources we no longer emit, so Gradle never
    # sees orphan .kt files (which would force a full recompile / fail).
    keep = set(files.keys());
    pruned = _prune_stale_kotlin(out, base_root, keep);
    if self.dev {
        pruned += _prune_stale_kotlin(out, hot_root, keep);
    } else {
        # Release builds don't use the :hot module — remove an orphan hot/ dir
        # left from a prior `jac dev` so Gradle never sees a ghost module.
        orphan_hot = out / "hot";
        if orphan_hot.is_dir() {
            import shutil;
            try {
                shutil.rmtree(orphan_hot);
            } except Exception {
                ;
            }
        }
    }

    try {
        ensure_gradle_wrapper(out);
    } except Exception as e {
        # Wrapper generation is best-effort; AndroidTarget.build may retry.
        ;
    }

    try {
        import from jaclang.cli.console { console }
        if reused {
            console.print(
                f"  ✔ Wrote {len(written) - reused}, reused {reused} unchanged"
                + (f", pruned {pruned} stale" if pruned else "")
                + " (gradle cache)",
                style="muted"
            );
        }
    } except Exception {
        ;
    }
    return written;
}
