"""AndroidTarget implementation — compile compose model, emit Gradle project, assemble APK."""
import os;
import shutil;
import subprocess;
import from pathlib { Path }
import from typing { Optional }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.runtime { JacRuntime as Jac }

# ---------------------------------------------------------------------------
# HMR dev server (Chunk 1): in-process HTTP server the on-device JacDevHostActivity
# polls. Serves a manifest (version + dex path) and the merged classes.dex.
# Runs bound to 0.0.0.0 so the device reaches it via `adb reverse`.
# `state` is a mutable dict {version, dex_path} the watch loop updates.
# ---------------------------------------------------------------------------
def _jac_dev_handler_cls(state: dict) -> any {
    import from http.server { BaseHTTPRequestHandler }
    import from json { dumps }

    def do_get(handler: any) -> None {
        raw_path = handler.path.split("?")[0];
        if raw_path == "/_jac/dev/modules/manifest.json" {
            body = dumps({
                "version": str(state.get("version", "")),
                "path": "/_jac/dev/modules/android/classes.dex"
            }).encode("utf-8");
            handler.send_response(200);
            handler.send_header("Content-Type", "application/json");
            handler.send_header("Content-Length", str(len(body)));
            handler.send_header("Cache-Control", "no-store");
            handler.end_headers();
            handler.wfile.write(body);
        } elif raw_path == "/_jac/dev/modules/android/classes.dex" {
            dex_path = state.get("dex_path");
            data: bytes = b"";
            if dex_path and Path(str(dex_path)).is_file() {
                data = Path(str(dex_path)).read_bytes();
            }
            if not data {
                handler.send_response(404);
                handler.send_header("Cache-Control", "no-store");
                handler.end_headers();
                return;
            }
            handler.send_response(200);
            handler.send_header("Content-Type", "application/octet-stream");
            handler.send_header("Content-Length", str(len(data)));
            handler.send_header("Cache-Control", "no-store");
            handler.end_headers();
            handler.wfile.write(data);
        } else {
            handler.send_response(404);
            handler.send_header("Cache-Control", "no-store");
            handler.end_headers();
        }
    }

    # Silence BaseHTTPRequestHandler's per-request stderr logging (the device
    # polls every 300ms, which would flood the console otherwise).
    def silent_log(handler: any, fmt: any, *args: any) { }

    # Build the request-handler class dynamically so the per-request method can
    # close over the live `state` dict (avoids subclassing BaseHTTPRequestHandler
    # from Jac).
    return type(
        "JacDevHandler",
        (BaseHTTPRequestHandler,),
        {
            "do_GET": do_get,
            # HTTP/1.0 closes the connection after each response. Android's
            # OkHttp pools HTTP/1.1 connections and trips over keep-alive reuse
            # against this lightweight server ("unexpected end of stream").
            # Close-per-request is correct for a 300ms localhost dev poll.
            "protocol_version": "HTTP/1.0",
            "log_message": silent_log
        }
    );
}

def _jac_start_dev_server(port: int, state: dict) -> any {
    import from http.server { ThreadingHTTPServer }
    import from threading { Thread }

    handler_cls = _jac_dev_handler_cls(state);
    httpd = ThreadingHTTPServer(("0.0.0.0", port), handler_cls);
    thread = Thread(target=httpd.serve_forever, daemon=True);
    thread.start();
    return httpd;
}


impl AndroidTarget._android_dir(project_dir: Path) -> Path {
    return project_dir / "apps" / "android";
}

impl AndroidTarget._load_android_cfg(project_dir: Path) -> dict {
    try {
        import from jaclang.project.config { JacConfig }
        cfg = JacConfig.load(project_dir / "jac.toml");
        android_cfg = cfg.get_section("client.android");
        if not android_cfg {
            client = cfg.get_section("client") or {};
            android_cfg = client.get("android") if isinstance(client, dict) else {};
        }
        if not isinstance(android_cfg, dict) {
            android_cfg = {};
        }
        return android_cfg;
    } except Exception {
        return {};
    }
}

impl AndroidTarget._resolve_android_avd(project_dir: Path) -> str {
    env_avd = os.environ.get("JAC_ANDROID_AVD", "").strip();
    if env_avd {
        return env_avd;
    }
    avd = self._load_android_cfg(project_dir).get("avd");
    if avd {
        return str(avd).strip();
    }
    return "";
}

impl AndroidTarget._ensure_adb(project_dir: Path) -> str {
    import from jaclang.runtimelib.client.mobile_dev_host { ensure_adb_device }
    return ensure_adb_device(self._resolve_android_avd(project_dir));
}

impl AndroidTarget._resolve_package_name(project_dir: Path) -> str {
    cfg = self._load_android_cfg(project_dir);
    pkg = cfg.get("package") or cfg.get("application_id");
    if pkg {
        return str(pkg);
    }
    return "dev.jac.generated";
}

impl AndroidTarget._resolve_type_check(project_dir: Path) -> bool {
    # P0 #3: type checking is opt-in via [client.android] type_check = true.
    # Defaults to false because the idiomatic 24.dp / x.len Kotlin-isms (which
    # jac_to_kotlin lowers specially) are not valid Jac yet — Jac has no
    # extension properties. Projects written in valid Jac can opt in to catch
    # typo'd modifier names / wrong primitive args before Gradle.
    if self._load_android_cfg(project_dir).get("type_check") {
        return True;
    }
    return False;
}

impl AndroidTarget.setup(project_dir: Path) -> None {
    android_dir = self._android_dir(project_dir);
    console.print(
        f"\n🤖 Setting up Android (Compose) target at {android_dir}", style="bold"
    );
    android_dir.mkdir(parents=True, exist_ok=True);

    jac_toml = project_dir / "jac.toml";
    if jac_toml.exists() {
        text = jac_toml.read_text(encoding="utf-8");
        if "[client.android]" not in text {
            with jac_toml.open("a", encoding="utf-8") as f {
                f.write(
                    "\n[client.android]\n"
                    'package = "dev.jac.generated"\n'
                    'app_name = "Jac App"\n'
                );
            }
        }
        if 'framework' in text and 'compose' not in text {
            console.print(
                "  Tip: set [client] framework = \"compose\" for Android codegen.",
                style="muted"
            );
        }
    }

    for (tool, hint) in [
        ("java", "JDK 17+"),
        ("adb", "Android platform-tools")
    ] {
        if not shutil.which(tool) {
            console.warning(f"  {tool} not found on PATH ({hint}).");
        }
    }
    if not os.environ.get("ANDROID_HOME") and not os.environ.get("ANDROID_SDK_ROOT") {
        console.warning(
            "  ANDROID_HOME / ANDROID_SDK_ROOT not set — Gradle may fail to find the SDK."
        );
    }
    console.success(f"  Android target ready at {android_dir}");
}

impl AndroidTarget._attach_interop_manifest(model: any, mod: any) -> None {
    if model is None or mod is None {
        return;
    }
    gen = getattr(mod, "gen", None);
    if gen is None {
        return;
    }
    manifest = getattr(gen, "interop_manifest", None);
    if manifest is None {
        return;
    }
    if model.intent.interop_manifest is None {
        model.intent.interop_manifest = manifest;
    } else {
        self._merge_interop_manifest(model.intent.interop_manifest, manifest);
    }
}

impl AndroidTarget._merge_interop_manifest(into: any, src: any) -> None {
    if into is None or src is None or into is src {
        return;
    }
    for attr in ("boundary_types", "walker_access", "bindings", "endpoint_effects") {
        dst_map = getattr(into, attr, None);
        src_map = getattr(src, attr, None);
        if isinstance(dst_map, dict) and isinstance(src_map, dict) {
            dst_map.update(src_map);
        }
    }
}

impl AndroidTarget._synthesize_routes_from_screens(model: any) -> None {
    import from jaclang.compiler.passes.ecmascript.intent.model { IntentRoute }
    import from jaclang.compiler.passes.compose.compose_emit {
        route_to_screen_name,
        component_screen_name
    }

    if model.intent.routes {
        return;
    }
    seen_paths: set[str] = set();
    for (cname, comp) in model.intent.components.items() {
        path = comp.route_path;
        is_home = cname in ("app", "App", "__root__");
        if not (comp.is_screen or path or (is_home and model.compose_view_for(cname) is not None)) {
            continue;
        }
        if not path {
            path = "/";
        }
        if path in seen_paths {
            continue;
        }
        seen_paths.add(path);
        sname = (
            "HomeScreen"
            if path == "/" or is_home
            else route_to_screen_name(path)
        );
        if not sname {
            sname = component_screen_name(cname);
        }
        model.intent.routes.append(
            IntentRoute(path=path, screen_name=sname, component=cname)
        );
        comp.is_screen = True;
        comp.route_path = path;
    }
}

impl AndroidTarget._compile_page_into_model(
    page_file: Path, program: any, model: any = None
) -> any {
    import from jaclang.compiler.passes.compose.compose_gen_pass { run_compose_gen_pass }
    import from jaclang.jac0core.compile_options { CompileOptions }

    page_mod = program.compile(
        str(page_file),
        options=CompileOptions(type_check=getattr(self, "_type_check", False))
    );
    if not page_mod {
        return None;
    }
    page_model = run_compose_gen_pass(page_mod, program);
    if model is not None {
        model.merge_from(page_model);
    }
    return page_mod;
}

impl AndroidTarget._populate_compose_routes(
    model: any, project_dir: Path, program: any
) -> None {
    import from jaclang.compiler.passes.ecmascript.intent.model { IntentRoute }
    import from jaclang.compiler.passes.compose.compose_emit { route_to_screen_name }
    import from jaclang.runtimelib.client.route_scanner {
        RouteScanner,
        resolve_route_exports
    }

    if model is None {
        return;
    }

    scanner = RouteScanner(
        project_root=project_dir, route_exports_of=resolve_route_exports
    );
    if not scanner.has_pages_dir() {
        self._synthesize_routes_from_screens(model);
        return;
    }

    routes = scanner.scan();
    if not routes and not scanner.get_layouts() {
        self._synthesize_routes_from_screens(model);
        return;
    }

    model.intent.routes = [];
    seen_paths: set[str] = set();
    for route in routes {
        page_mod = self._compile_page_into_model(route.file_path, program, model);
        self._attach_interop_manifest(model, page_mod);

        export_name = route.source_export;
        if export_name and export_name in model.intent.components {
            comp = model.intent.components[export_name];
            comp.is_screen = True;
            comp.route_path = route.path;
        }

        if route.path in seen_paths {
            continue;
        }
        seen_paths.add(route.path);
        sname = (
            "HomeScreen" if route.path == "/" else route_to_screen_name(route.path)
        );
        model.intent.routes.append(
            IntentRoute(
                path=route.path, screen_name=sname, component=export_name
            )
        );
    }

    if not model.intent.routes {
        self._synthesize_routes_from_screens(model);
    }
}

impl AndroidTarget._compile_compose_modules(
    entry_file: Path, project_dir: Path
) -> tuple {
    console.print("  Compiling Jac modules (ComposeGenPass → ComposeModule)...", style="muted");
    import from jaclang.project.config { get_config }
    import from jaclang.compiler.passes.compose.compose_gen_pass { run_compose_gen_pass }
    import from jaclang.jac0core.compiler { get_inference_sched }
    import from jaclang.jac0core.compile_options { CompileOptions }

    program = Jac.program;
    self._type_check = self._resolve_type_check(project_dir);
    mod = program.compile(
        str(entry_file), options=CompileOptions(type_check=self._type_check)
    );
    if not mod {
        raise RuntimeError(f"Failed to compile entry module: {entry_file}");
    }

    if id(mod) not in getattr(program, "_inferred_mods", set()) {
        sched = get_inference_sched();
        if sched {
            program.run_schedule(mod, sched);
            if not hasattr(program, "_inferred_mods") {
                program._inferred_mods = set();
            }
            program._inferred_mods.add(id(mod));
        }
    }

    model = run_compose_gen_pass(mod, program);
    if hasattr(mod, "gen") {
        mod.gen.compose_model = model;
    }

    self._attach_interop_manifest(model, mod);
    self._populate_compose_routes(model, project_dir, program);

    n_comp = len(model.intent.components);
    n_routes = len(model.intent.routes);
    n_walkers = 0;
    if model.intent.interop_manifest is not None {
        access = getattr(model.intent.interop_manifest, "walker_access", {}) or {};
        n_walkers = len(access);
    }
    console.print(
        f"  ✔ Compose model recorded ({n_comp} components, {n_routes} routes"
        + (f", {n_walkers} walkers" if n_walkers else "")
        + ")",
        style="success"
    );
    return (model, mod);
}

impl AndroidTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    import from jaclang.compiler.passes.compose.compose_emit { ComposeEmit }
    import from jaclang.compiler.passes.compose.compose_model { ComposeModule }

    android_dir = self._android_dir(project_dir);
    android_dir.mkdir(parents=True, exist_ok=True);

    (model, _mod) = self._compile_compose_modules(entry_file, project_dir);
    if model is None {
        model = ComposeModule();
    }
    model.intent.package_name = self._resolve_package_name(project_dir);

    android_cfg = self._load_android_cfg(project_dir);
    if android_cfg.get("app_name") {
        model.intent.app_name = str(android_cfg["app_name"]);
    }
    if android_cfg.get("backend_url") {
        model.intent.backend_url = str(android_cfg["backend_url"]);
    }

    console.print(f"  Emitting Compose project → {android_dir}", style="muted");
    emitter = ComposeEmit(model=model, out_dir=android_dir);
    written = emitter.write();
    console.print(f"  ✔ Wrote {len(written)} files", style="success");

    release = False;
    try {
        import from jaclang.project.config { JacConfig }
        android_cfg = JacConfig.load(project_dir / "jac.toml").get_section(
            "client.android"
        ) or {};
        release = bool(android_cfg.get("release", False));
    } except Exception { }

    apk = self._run_gradle_assemble(android_dir, release=release);
    console.success(f"  APK ready: {apk}");
    return apk;
}

impl AndroidTarget._run_gradle_assemble(
    android_dir: Path, release: bool = False, task: str = ""
) -> Path {
    gradlew = android_dir / ("gradlew.bat" if os.name == "nt" else "gradlew");
    if not gradlew.exists() {
        gradle = shutil.which("gradle");
        if not gradle {
            raise RuntimeError(
                f"gradlew not found at {gradlew} and `gradle` is not on PATH. "
                "Install Gradle or run `gradle wrapper` inside apps/android/."
            );
        }
        console.print("  Generating Gradle wrapper...", style="muted");
        subprocess.run(
            [gradle, "wrapper", "--gradle-version", "8.13"],
            cwd=android_dir,
            check=True
        );
    }
    if os.name != "nt" {
        try {
            os.chmod(gradlew, 0o755);
        } except Exception { }
    }

    task = task if task else ("assembleRelease" if release else "assembleDebug");
    gradle_args = [str(gradlew), task, "--build-cache"];
    console.print(f"  Running gradle: {' '.join(gradle_args)}", style="muted");
    subprocess.run(
        gradle_args,
        cwd=android_dir,
        check=True,
        capture_output=False
    );

    variant = "release" if release else "debug";
    preferred = android_dir / "app" / "build" / "outputs" / "apk" / variant;
    candidates = [];
    if preferred.exists() {
        candidates = [f for f in preferred.rglob("*.apk") if f.is_file()];
    }
    if not candidates {
        outputs = android_dir / "app" / "build" / "outputs";
        if outputs.exists() {
            candidates = [f for f in outputs.rglob("*.apk") if f.is_file()];
        }
    }
    if not candidates {
        raise RuntimeError(
            "Gradle succeeded but no APK found under "
            f"{android_dir / 'app' / 'build' / 'outputs'}"
        );
    }
    best = candidates[0];
    for cand in candidates {
        if cand.stat().st_mtime > best.stat().st_mtime {
            best = cand;
        }
    }
    return best;
}

impl AndroidTarget.dev(
    entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
) -> None {
    import from jaclang.compiler.passes.compose.compose_emit { ComposeEmit }
    import from jaclang.compiler.passes.compose.compose_model { ComposeModule }

    android_dir = self._android_dir(project_dir);
    android_dir.mkdir(parents=True, exist_ok=True);

    (model, _mod) = self._compile_compose_modules(entry_file, project_dir);
    if model is None {
        model = ComposeModule();
    }
    model.intent.package_name = self._resolve_package_name(project_dir);
    try {
        import from jaclang.project.config { JacConfig }
        android_cfg = JacConfig.load(project_dir / "jac.toml").get_section(
            "client.android"
        ) or {};
        if android_cfg.get("app_name") {
            model.intent.app_name = str(android_cfg["app_name"]);
        }
        if android_cfg.get("backend_url") {
            model.intent.backend_url = str(android_cfg["backend_url"]);
        }
    } except Exception { }

    console.print(
        "  Emitting Compose DEV project (base :app host + :hot module)...",
        style="muted"
    );
    emitter = ComposeEmit(model=model, out_dir=android_dir, dev=True);
    emitter.write();

    # 1. Base host APK — built and installed ONCE.
    base_apk = self._run_gradle_assemble(android_dir, task=":app:assembleDebug");
    console.success(f"  Base host APK: {base_apk}");

    # 2. Install base + adb reverse + launch the polling host at the dev server.
    self._adb_reverse_launch(base_apk, project_dir, port);

    # 3. Initial hot module dex (infra + screens + JacDevEntry).
    (version, dex_path) = self._build_hot_dex(android_dir, model.intent.package_name);
    state: dict = {"version": version, "dex_path": str(dex_path)};
    console.success(f"  Hot module v{version}: {dex_path}");

    # 4. Dev server (manifest + classes.dex) the device polls.
    httpd = _jac_start_dev_server(port, state);
    console.print(
        f"  Dev server on http://0.0.0.0:{port} (manifest + classes.dex)",
        style="success"
    );
    console.print(
        "  HMR ready — editing .cl.jac hot-swaps without reinstall. Ctrl+C to stop.",
        style="bold"
    );

    # 5. Watch .cl.jac → re-emit → rebuild hot dex → bump version (server serves it).
    self._watch_hot_reload(entry_file, project_dir, android_dir, model.intent.package_name, state);
}

impl AndroidTarget._adb_reverse_launch(
    apk_path: Path, project_dir: Path, port: int
) -> None {
    try {
        adb = self._ensure_adb(project_dir);
    } except RuntimeError as e {
        console.warning(f"  {e}");
        console.warning(
            f"  Install {apk_path} manually, then: "
            f"adb reverse tcp:{port} tcp:{port} && "
            f"adb shell am start -n <pkg>/.JacDevHostActivity "
            f"--es jacDevServer http://localhost:{port}"
        );
        return;
    }
    pkg = self._resolve_package_name(project_dir);
    console.print(f"  adb install -r {apk_path}", style="muted");
    subprocess.run([adb, "install", "-r", str(apk_path)], check=True);
    console.print(f"  adb reverse tcp:{port} tcp:{port}", style="muted");
    subprocess.run(
        [adb, "reverse", f"tcp:{port}", f"tcp:{port}"], check=True
    );
    console.print(f"  Launching {pkg}/.JacDevHostActivity", style="muted");
    subprocess.run(
        [
            adb, "shell", "am", "start", "-n",
            f"{pkg}/.JacDevHostActivity",
            "--es", "jacDevServer", f"http://localhost:{port}"
        ],
        check=False,
        capture_output=True
    );
}

impl AndroidTarget._locate_android_tools() -> tuple {
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT");
    if not sdk {
        raise RuntimeError(
            "ANDROID_HOME / ANDROID_SDK_ROOT not set — needed for d8 + android.jar"
        );
    }
    sdk_path = Path(sdk);
    d8: Path = Path("");
    build_tools = sdk_path / "build-tools";
    if build_tools.is_dir() {
        versions = sorted([d.name for d in build_tools.iterdir() if d.is_dir()]);
        for v in reversed(versions) {
            cand = build_tools / v / "d8";
            if cand.is_file() {
                d8 = cand;
                break;
            }
        }
    }
    android_jar: Path = Path("");
    platforms = sdk_path / "platforms";
    if platforms.is_dir() {
        vers = sorted([
            d.name for d in platforms.iterdir()
            if d.is_dir() and d.name.startswith("android-")
        ]);
        for v in reversed(vers) {
            cand = platforms / v / "android.jar";
            if cand.is_file() {
                android_jar = cand;
                break;
            }
        }
    }
    if not str(d8) {
        raise RuntimeError(f"d8 not found under {build_tools}");
    }
    if not str(android_jar) {
        raise RuntimeError(f"android.jar not found under {platforms}");
    }
    return (d8, android_jar);
}

impl AndroidTarget._build_hot_dex(
    android_dir: Path, package_name: str
) -> tuple {
    import from hashlib { sha256 }

    gradlew = android_dir / ("gradlew.bat" if os.name == "nt" else "gradlew");
    # 1. Incremental Kotlin/Compose compile of the :hot module.
    console.print("  Compiling :hot (Kotlin/Compose)...", style="muted");
    subprocess.run(
        [str(gradlew), ":hot:compileDebugKotlin", "--build-cache"],
        cwd=str(android_dir),
        check=True,
        capture_output=False
    );

    # 2. Collect :hot's compiled .class outputs (Java + Kotlin).
    hot_build = android_dir / "hot" / "build";
    class_dirs = [
        hot_build / "intermediates" / "javac" / "debug" / "classes",
        hot_build / "tmp" / "kotlin-classes" / "debug"
    ];
    class_files: list[str] = [];
    for cd in class_dirs {
        if cd.is_dir() {
            for f in cd.rglob("*.class") {
                class_files.append(str(f));
            }
        }
    }
    if not class_files {
        raise RuntimeError(
            f":hot compiled but no .class found under {hot_build}"
        );
    }

    # 3. Content-addressed version over the compiled classes.
    hasher = sha256();
    for cf in sorted(class_files) {
        hasher.update(Path(cf).read_bytes());
    }
    version = hasher.hexdigest()[:16];

    # 4. d8 the hot program classes into a single merged classes.dex. Only the
    # app's own classes go in (Compose resolves parent-first from the base at
    # runtime), so the dex stays small and reloads fast — the small-dex/big-base approach.
    out_dir = android_dir / "build" / "jac-dev" / version;
    out_dir.mkdir(parents=True, exist_ok=True);
    dex_path = out_dir / "classes.dex";
    if not dex_path.is_file() {
        (d8, android_jar) = self._locate_android_tools();
        # Pass the class list via an @argfile so apps with many classes don't
        # overflow the OS argv limit (d8/R8 expand @file themselves).
        argfile = out_dir / "d8-inputs.txt";
        argfile.write_text("\n".join(class_files) + "\n", encoding="utf-8");
        d8_cmd = [
            str(d8), "--min-api", "26", "--lib", str(android_jar),
            "--output", str(out_dir), "@" + str(argfile)
        ];
        console.print(
            f"  d8 {len(class_files)} class(es) → classes.dex", style="muted"
        );
        subprocess.run(d8_cmd, check=True);
    }
    if not dex_path.is_file() {
        raise RuntimeError("d8 did not produce classes.dex");
    }
    return (version, dex_path);
}

impl AndroidTarget._collect_jac_sources(project_dir: Path) -> list {
    # Watch every Jac source — `.jac` also matches `.cl.jac`/`.impl.jac`/`.test.jac`.
    # Many projects put their UI in the entry `.jac` (not a `.cl.jac`), so watching
    # only `.cl.jac` would miss edits to the very file users edit most.
    result: list = [];
    for p in project_dir.rglob("*.jac") {
        s = str(p);
        if "node_modules" in s or "/.git/" in s or "apps/android" in s {
            continue;
        }
        result.append(p);
    }
    return result;
}

impl AndroidTarget._watch_hot_reload(
    entry_file: Path,
    project_dir: Path,
    android_dir: Path,
    package_name: str,
    state: dict
) -> None {
    import from time { sleep }
    import from jaclang.compiler.passes.compose.compose_emit { ComposeEmit }

    sources = self._collect_jac_sources(project_dir);
    mtimes: dict = {};
    for s in sources {
        try {
            mtimes[s] = s.stat().st_mtime;
        } except Exception { }
    }
    try {
        while True {
            sleep(0.5);
            changed: list = [];
            for s in self._collect_jac_sources(project_dir) {
                try {
                    m = s.stat().st_mtime;
                } except Exception {
                    continue;
                }
                if m != mtimes.get(s) {
                    mtimes[s] = m;
                    changed.append(s);
                }
            }
            if changed {
                console.print(
                    f"  ⚡ {len(changed)} .cl.jac changed — rebuilding hot module...",
                    style="muted"
                );
                try {
                    (model, _mod) = self._compile_compose_modules(
                        entry_file, project_dir
                    );
                    if model is not None {
                        model.intent.package_name = package_name;
                        emitter = ComposeEmit(
                            model=model, out_dir=android_dir, dev=True
                        );
                        emitter.write();
                    }
                    (version, dex_path) = self._build_hot_dex(
                        android_dir, package_name
                    );
                    state["version"] = version;
                    state["dex_path"] = str(dex_path);
                    console.success(f"  ⚡ Hot module swapped → v{version}");
                } except Exception as e {
                    console.warning(f"  hot rebuild failed: {e}");
                }
            }
        }
    } except KeyboardInterrupt {
        console.print("  dev server stopped.", style="muted");
    }
}

impl AndroidTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    apk = self.build(entry_file, project_dir);
    self._adb_install_launch(apk, project_dir);
}

impl AndroidTarget._adb_install_launch(apk_path: Path, project_dir: Path) -> None {
    try {
        adb = self._ensure_adb(project_dir);
    } except RuntimeError as e {
        console.warning(f"  {e}");
        console.warning(
            f"  Install manually: adb install -r {apk_path}"
        );
        return;
    }
    pkg = self._resolve_package_name(project_dir);
    console.print(f"  adb install -r {apk_path}", style="muted");
    subprocess.run([adb, "install", "-r", str(apk_path)], check=True);
    console.print(f"  Launching {pkg}", style="muted");
    subprocess.run(
        [
            adb,
            "shell",
            "monkey",
            "-p",
            pkg,
            "-c",
            "android.intent.category.LAUNCHER",
            "1"
        ],
        check=False,
        capture_output=True
    );
    console.success("App installed and launched.");
}
