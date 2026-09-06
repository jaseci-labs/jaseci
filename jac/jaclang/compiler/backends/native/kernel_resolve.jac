import json;
import os;
import sys;
import from dataclasses { field }
import from jaclang.compiler.driver.compile_options {
    CompileOptions,
    NATIVE_LINK_MODE_BITCODE
}

glob KERNEL_LIB_ENV: str = "JAC_COMPILER_LIB",
     STUBCAT_BUILDING_ENV: str = "JAC_STUBCAT_BUILDING",
     KERNEL_OFF_VALUES: tuple[str, ...] = ("none", "off", "disabled", "0"),
     LAYOUT_SIDECAR_SUFFIX: str = ".layout.json";

obj ResolvedKernel {
    has lib_path: str,
        layout: dict,
        source: str,
        plan_digest: str = "";
}

class KernelUnavailable(RuntimeError) {}

def kernel_lib_name -> str {
    if sys.platform == "darwin" {
        return "libjac_compiler.dylib";
    }
    if sys.platform.startswith("win") {
        return "jac_compiler.dll";
    }
    return "libjac_compiler.so";
}

def source_tree_kernel_path -> str {
    import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }
    return os.path.join(jaclang_pkg_root(), "compiler", kernel_lib_name());
}

def read_sidecar(lib_path: str) -> (dict | None) {
    data: any = None;
    try {
        with open(lib_path + LAYOUT_SIDECAR_SUFFIX, "r", encoding="utf-8") as f {
            data = json.load(f);
        }
    } except Exception {
        return None;
    }
    if not isinstance(data, dict) or not isinstance(data.get("classes"), dict) {
        return None;
    }
    return data;
}

def _from_explicit(path: str) -> ResolvedKernel {
    sidecar = read_sidecar(path);
    if not os.path.isfile(path) or sidecar is None {
        raise KernelUnavailable(
            f"{KERNEL_LIB_ENV}={path} does not name a kernel lib with its "
            f"{LAYOUT_SIDECAR_SUFFIX} sidecar"
        );
    }
    return ResolvedKernel(
        lib_path=path,
        layout=sidecar["classes"],
        source="explicit",
        plan_digest=str(sidecar.get("plan_digest", ""))
    );
}

def _from_sealed_image -> (ResolvedKernel | None) {
    import from jaclang.jac0core { sealed }
    image = sealed._jaclang_image();
    if image is None {
        return None;
    }
    record = image.native_artifact();
    if record is None {
        raise KernelUnavailable(
            "sealed jaclang image carries no native compiler kernel; the image "
            "is immutable, so rebuild the payload"
        );
    }
    lib_path = str(image.pkg_dir / record["path"]);
    sidecar = read_sidecar(lib_path);
    if not os.path.isfile(lib_path) or sidecar is None {
        raise KernelUnavailable(
            f"sealed jaclang image names kernel {lib_path} but it or its "
            f"{LAYOUT_SIDECAR_SUFFIX} sidecar is missing"
        );
    }
    import hashlib;
    with open(lib_path, "rb") as f {
        digest = hashlib.sha256(f.read()).hexdigest();
    }
    if digest != record.get("sha256") {
        raise KernelUnavailable(
            f"sealed kernel {lib_path} does not match its manifest sha256"
        );
    }
    if str(sidecar.get("plan_digest", "")) != str(record.get("plan_digest", "")) {
        raise KernelUnavailable(
            f"sealed kernel {lib_path}: sidecar plan digest disagrees with the manifest"
        );
    }
    return ResolvedKernel(
        lib_path=lib_path,
        layout=sidecar["classes"],
        source="sealed",
        plan_digest=str(record.get("plan_digest", ""))
    );
}

def _toolchain_available -> bool {
    try {
        import from jaclang.compiler.driver.schedules { native_pipeline_available }
        (ok, _why) = native_pipeline_available();
        return bool(ok);
    } except Exception {
        return False;
    }
}

def kernel_options -> CompileOptions {
    """The kernel runs in this process, so it is always the host's: a cross
    target set for the artifacts being built never reaches the kernel's
    units, its source key or its plan.""";
    return CompileOptions(
        aot_mode=True,
        default_codespace="native",
        force_target_program=True,
        native_unit=True,
        skip_native_engine=True,
        native_target="",
        na_gc_mode="cycles",
        nogc_enforce_modules=[],
        nogc_grandfathered=[],
        rc_debug_codegen=False,
        native_debug=False,
        opt_level=2,
        dump_ir_path="",
        debug_ir=False,
        rc_stats=False,
        nogc_debug=False
    );
}

def kernel_plan(prog: any = None, mode: str = "") -> any {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.native_scope { kernel_root_path }
    import from jaclang.compiler.backends.native.link_plan { build_link_plan }
    program = prog if prog is not None else JacProgram();
    options = kernel_options();
    return build_link_plan(
        program, [kernel_root_path()], options, mode=mode, native_unit=True
    );
}

def build_kernel(dst: str, prog: any = None, log: any = None) -> any {
    import from jaclang.compiler.backends.native.link_plan {
        ArtifactKind,
        link_artifact
    }
    import from jaclang.compiler.driver.nativecache { UNIT_ISOLATE_ENV }
    os.environ[UNIT_ISOLATE_ENV] = "1";
    with _StoreParserSpan() {
        plan = kernel_plan(prog, mode=NATIVE_LINK_MODE_BITCODE);
        os.makedirs(os.path.dirname(os.path.abspath(dst)) or ".", exist_ok=True);
        return link_artifact(plan, dst, ArtifactKind.SHARED, log=log);
    }
}

class _KernelLock {
    def init(self: _KernelLock, path: str) {
        self.path = path + ".lock";
        self.handle: any = None;
    }

    def acquire(self: _KernelLock) {
        os.makedirs(os.path.dirname(self.path) or ".", exist_ok=True);
        self.handle = open(self.path, "a+");
        if sys.platform.startswith("win") {
            import msvcrt;
            msvcrt.locking(self.handle.fileno(), msvcrt.LK_LOCK, 1);
        } else {
            import fcntl;
            fcntl.flock(self.handle.fileno(), fcntl.LOCK_EX);
        }
    }

    def release(self: _KernelLock) {
        if self.handle is None {
            return;
        }
        try {
            if sys.platform.startswith("win") {
                import msvcrt;
                msvcrt.locking(self.handle.fileno(), msvcrt.LK_UNLCK, 1);
            } else {
                import fcntl;
                fcntl.flock(self.handle.fileno(), fcntl.LOCK_UN);
            }
        } finally {
            self.handle.close();
            self.handle = None;
        }
    }
}

class _StoreParserSpan {
    def init(self: _StoreParserSpan) {
        self.prev = None;
    }

    def __enter__(self: _StoreParserSpan) -> _StoreParserSpan {
        self.prev: (str | None) = os.environ.get(KERNEL_LIB_ENV);
        os.environ[KERNEL_LIB_ENV] = "off";
        return self;
    }

    def __exit__(self: _StoreParserSpan, exc_type: any, exc: any, tb: any) -> bool {
        if self.prev is None {
            os.environ.pop(KERNEL_LIB_ENV, None);
        } else {
            os.environ[KERNEL_LIB_ENV] = str(self.prev);
        }
        return False;
    }
}

def _from_source_tree -> (ResolvedKernel | None) {
    if not _toolchain_available() {
        return None;
    }
    lib_path = source_tree_kernel_path();
    found = _accept_in_tree(lib_path);
    if found is not None {
        return found;
    }
    import from jaclang.compiler.driver.nativecache { UNIT_CHILD_DEPTH_ENV }
    if os.environ.get(UNIT_CHILD_DEPTH_ENV, "") {
        """A unit compile child parses with the store parser rather than
        derive a kernel from inside a link plan; the plan that spawned it
        has a kernel or is the kernel build itself.""";
        return None;
    }
    try {
        return _derive_in_tree(lib_path);
    } except KernelUnavailable {
        raise;
    } except Exception as e {
        sys.stderr.write(
            f"jac: the native compiler kernel could not be derived "
            f"({type(e).__name__}: {e}); parsing with the store parser. "
            "Run `jac precompile ./jac --seal` to see the full diagnostics.\n"
        );
        return None;
    }
}

def _sidecar_matches_sources(sidecar: dict) -> bool {
    import from jaclang.compiler.backends.native.link_plan {
        sidecar_unit_paths,
        units_source_key
    }
    units = sidecar_unit_paths(sidecar);
    recorded = str(sidecar.get("source_key", ""));
    if not units or not recorded {
        return False;
    }
    return units_source_key(units, kernel_options()) == recorded;
}

def _accept_in_tree(lib_path: str) -> (ResolvedKernel | None) {
    sidecar = read_sidecar(lib_path);
    if sidecar is None or not os.path.isfile(lib_path) {
        return None;
    }
    if not _sidecar_matches_sources(sidecar) {
        return None;
    }
    return ResolvedKernel(
        lib_path=lib_path,
        layout=sidecar["classes"],
        source="tree",
        plan_digest=str(sidecar.get("plan_digest", ""))
    );
}

def _bundled_kernel_path -> (str | None) {
    """The kernel the running kit carries, when this process's compiler is
    a rerouted checkout rather than that kit: the kit's sealed jaclang sits
    beside its interpreter.""";
    import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }
    site_pkg = os.path.join(os.path.dirname(sys.prefix), "site", "jaclang");
    if not os.path.isdir(os.path.join(site_pkg, "_precompiled")) {
        return None;
    }
    if os.path.realpath(site_pkg) == os.path.realpath(jaclang_pkg_root()) {
        return None;
    }
    try {
        import from jaclang.jac0core.sealed { load_image }
        image = load_image(os.path.join(site_pkg, "_precompiled"));
        if image is None {
            return None;
        }
        record = image.native_artifact();
    } except Exception {
        return None;
    }
    if not record {
        return None;
    }
    lib_path = os.path.join(site_pkg, str(record.get("path", "")));
    return lib_path if os.path.isfile(lib_path) else None;
}

def _adopt_bundled(lib_path: str) -> (ResolvedKernel | None) {
    """A checkout whose sources are the ones the kit was built from takes
    the kit's kernel instead of deriving its own: the sidecar's source key
    is the same compiler digest and unit keys the derivation would settle
    on. The copy lands beside the loader so later runs accept it in place.""";
    import shutil;
    bundled = _bundled_kernel_path();
    if bundled is None {
        return None;
    }
    sidecar = read_sidecar(bundled);
    if sidecar is None or not _sidecar_matches_sources(sidecar) {
        return None;
    }
    try {
        os.makedirs(os.path.dirname(lib_path) or ".", exist_ok=True);
        shutil.copyfile(bundled, lib_path + ".adopt");
        shutil.copyfile(
            bundled + LAYOUT_SIDECAR_SUFFIX, lib_path + LAYOUT_SIDECAR_SUFFIX + ".adopt"
        );
        os.replace(
            lib_path + LAYOUT_SIDECAR_SUFFIX + ".adopt",
            lib_path + LAYOUT_SIDECAR_SUFFIX
        );
        os.replace(lib_path + ".adopt", lib_path);
        shutil.copymode(bundled, lib_path);
    } except OSError {
        return None;
    }
    return _accept_in_tree(lib_path);
}

def _build_kernel_in_child(dst: str) {
    import subprocess;
    import from jaclang.compiler.driver.nativecache {
        child_compiler_argv,
        child_compiler_env
    }
    import from jaclang.compiler.driver.nativecache { UNIT_ISOLATE_ENV }
    env = child_compiler_env({KERNEL_LIB_ENV: "off", UNIT_ISOLATE_ENV: "1"});
    code = (
        "import sys\n"
        "sys.path.insert(0, sys.argv[-1])\n"
        "from jaclang.compiler.backends.native.kernel_resolve import build_kernel\n"
        "build_kernel(sys.argv[1], log=lambda m: sys.stderr.write(m + '\\n'))\n"
    );
    proc = subprocess.run(child_compiler_argv(code, [dst]), env=env);
    if proc.returncode != 0 {
        raise RuntimeError(f"kernel build exited with status {proc.returncode}");
    }
}

def _derive_in_tree(lib_path: str) -> (ResolvedKernel | None) {
    found = _accept_in_tree(lib_path);
    if found is not None {
        return found;
    }
    lock = _KernelLock(lib_path);
    lock.acquire();
    try {
        found = _accept_in_tree(lib_path) or _adopt_bundled(lib_path);
        if found is not None {
            return found;
        }
        import from jaclang.compiler.driver.pass_driver { setup_progress }
        setup_progress.on_kernel_build(lib_path);
        tmp = f"{lib_path}.{os.getpid()}.tmp";
        try {
            _build_kernel_in_child(tmp);
            os.replace(tmp + LAYOUT_SIDECAR_SUFFIX, lib_path + LAYOUT_SIDECAR_SUFFIX);
            os.replace(tmp, lib_path);
        } finally {
            for leftover in (tmp, tmp + LAYOUT_SIDECAR_SUFFIX) {
                try {
                    os.remove(leftover);
                } except OSError {}
            }
        }
        sidecar = read_sidecar(lib_path);
        if sidecar is None {
            raise RuntimeError("the kernel build left no layout sidecar");
        }
        return ResolvedKernel(
            lib_path=lib_path,
            layout=sidecar["classes"],
            source="tree",
            plan_digest=str(sidecar.get("plan_digest", ""))
        );
    } finally {
        lock.release();
    }
}

def resolve_kernel -> (ResolvedKernel | None) {
    if os.environ.get(STUBCAT_BUILDING_ENV) {
        return None;
    }
    lib_setting = os.environ.get(KERNEL_LIB_ENV, "");
    if lib_setting.strip().lower() in KERNEL_OFF_VALUES {
        return None;
    }
    if lib_setting {
        return _from_explicit(lib_setting);
    }
    sealed = _from_sealed_image();
    if sealed is not None {
        return sealed;
    }
    return _from_source_tree();
}
