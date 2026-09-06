import hashlib;
import json;
import os;
import sys;
import jaclang.compiler.backends.native.llvm.binding as llvm;
import type from jaclang.compiler.backends.native.llvm.binding {
    ExecutionEngine,
    ModuleRef,
    TargetMachine
}
import from jaclang.compiler.driver.compile_options {
    CompileOptions,
    NATIVE_LINK_MODE_BITCODE,
    NATIVE_LINK_MODE_OBJECTS,
    env_na_debug
}
import from jaclang.compiler.driver.native_iface {
    NativeIface,
    layout_digest as layout_digest_of,
    merge_class_layouts
}
import from jaclang.compiler.backends.native.link_glue {
    ENTRY_SYMBOL,
    GlueSpec,
    GlueUnit,
    REGION_DIED_HOOK,
    SHARED_INIT_SYMBOL,
    STR_NEW_SYMBOL,
    init_object_codegen,
    link_glue_ir
}
import from jaclang.compiler.backends.native.na_compile_pass {
    NATIVE_CODE_MODEL,
    NATIVE_RELOC_MODEL,
    jit_load_clib,
    optimize_unit
}
import from jaclang.compiler.backends.native.linker_common {
    clib_needed_libs,
    clib_symbol_lib_map,
    collect_floor_archives,
    collect_musl_static
}
import from jaclang.compiler.frontend.codeinfo {
    install_native_static_init,
    kernel_unit_path
}
import type from jaclang.compiler.driver.program { JacProgram }

glob PLAN_DIGEST_FORMAT: int = 1;

enum ArtifactKind {
    EXECUTABLE = "executable",
    SHARED = "shared",
    WASM = "wasm",
    JIT = "jit"
}

class LinkPlanError(RuntimeError) {}

class SymbolCollision(LinkPlanError) {
    def init(self: SymbolCollision, symbol: str, first: str, second: str) {
        self.symbol = symbol;
        self.first = first;
        self.second = second;
        RuntimeError.__init__(
            self,
            f"symbol collision: '{symbol}' is defined in both {first} and {second}"
        );
    }
}

def check_pub_collisions(units: list[LinkUnit]) {
    owners: dict[str, str] = {};
    for u in units {
        for sym in u.iface.pub_symbols() {
            first = owners.get(sym);
            if first is not None and first != u.path {
                raise SymbolCollision(sym, first, u.path);
            }
            owners[sym] = u.path;
        }
    }
}

obj LinkUnit {
    has path: str,
        prefix: str,
        iface: NativeIface,
        digest: str,
        modkey: str = "",
        is_root: bool = False;
}

obj LinkInputs {
    has objects: list[bytes] = [],
        archive_members: list[bytes] = [],
        crt_objects: list[bytes] = [],
        needed_libs: list[str] = [],
        symbol_lib_map: dict[str, str] = {},
        export_symbols: list[str] = [],
        init_funcs: list[str] = [],
        static_musl: bool = False;
}

obj LinkResult {
    has output_path: str,
        plan_digest: str,
        layout_digest: str,
        sha256: str,
        classes: dict = {},
        units: list[str] = [];
}

obj LinkPlan {
    has prog: JacProgram,
        options: CompileOptions,
        roots: list[str],
        units: list[LinkUnit],
        mode: str,
        triple: str;

    def unit(path: str) -> (LinkUnit | None) {
        real = os.path.realpath(path);
        for u in self.units {
            if u.path == real {
                return u;
            }
        }
        return None;
    }

    def root_unit -> LinkUnit {
        for u in self.units {
            if u.is_root {
                return u;
            }
        }
        raise LinkPlanError("link plan has no root_u unit");
    }

    def root_index -> int {
        for (i, u) in enumerate(self.units) {
            if u.is_root {
                return i;
            }
        }
        return -1;
    }

    def init_symbols -> list[str] {
        return [
            u.iface.init_symbol
            for u in self.units
            if u.iface.init_symbol
        ];
    }

    def plan_digest -> str {
        h = hashlib.sha256();
        h.update(f"plan-format={PLAN_DIGEST_FORMAT}".encode());
        h.update(self.mode.encode());
        h.update(self.triple.encode());
        h.update(self.options.codegen_identity().encode());
        import from jaclang.compiler.driver.jir { running_compiler_digest }
        h.update(running_compiler_digest().encode());
        for u in self.units {
            h.update(u.path.encode());
            h.update(u.modkey.encode());
            h.update(u.digest.encode());
        }
        return h.hexdigest();
    }

    def merged_layout -> dict {
        return merge_class_layouts([u.iface for u in self.units]);
    }

    def layout_digest -> str {
        return layout_digest_of(self.merged_layout());
    }

    def demoted_symbols -> list[str] {
        out: list[str] = [];
        for u in self.units {
            for name in u.iface.demoted {
                out.append(f"{os.path.basename(u.path)}:{name}");
            }
        }
        return sorted(out);
    }

    def clib_paths -> list[str] {
        out: list[str] = [];
        for u in self.units {
            for p in u.iface.clib_paths {
                if p not in out {
                    out.append(p);
                }
            }
        }
        return out;
    }

    def clib_symbol_lib -> dict[str, str] {
        out: dict[str, str] = {};
        for u in self.units {
            for (sym, lib) in u.iface.clib_symbol_lib.items() {
                out.setdefault(sym, lib);
            }
        }
        return out;
    }

    def pub_exports -> list[str] {
        out: list[str] = [];
        for u in self.units {
            for sym in u.iface.pub_symbols() {
                if sym not in out {
                    out.append(sym);
                }
            }
        }
        return out;
    }

    def has_unit(rel: str) -> bool {
        want = os.path.realpath(kernel_unit_path(rel));
        return any(u.path == want for u in self.units);
    }

    def glue_spec(kind: ArtifactKind, platform: str, static_musl: bool) -> GlueSpec {
        units: list[GlueUnit] = [];
        str_new_supplied = any(STR_NEW_SYMBOL in u.iface.exports for u in self.units);
        hook_supplied = any(REGION_DIED_HOOK in u.iface.exports for u in self.units);
        for u in self.units {
            exports = u.iface.exports;
            probe = exports.get("__jac_rt_probe");
            units.append(
                GlueUnit(
                    prefix=u.prefix,
                    init_symbol=u.iface.init_symbol,
                    entry_symbol=u.iface.entry_symbol,
                    probe=probe.symbol if probe is not None else "",
                    retain="jac_retain" in exports,
                    release="jac_release" in exports,
                    str_new=str_new_supplied
                )
            );
        }
        is_elf = platform == "elf";
        return GlueSpec(
            units=units,
            root_index=self.root_index(),
            shared=(kind == ArtifactKind.SHARED),
            platform=platform if kind != ArtifactKind.JIT else "jit",
            static_musl=static_musl,
            triple=self.triple,
            clib_paths=self.clib_paths(),
            needs_atexit_shim=(
                is_elf and (kind == ArtifactKind.SHARED or not static_musl)
            ),
            needs_region_hook=not hook_supplied
        );
    }
}

def _platform_of(triple: str) -> str {
    tl = triple.lower();
    if ("windows" in tl) or ("msvc" in tl) or ("mingw" in tl) {
        return "pe";
    }
    if ("darwin" in tl) or ("apple" in tl) or ("macos" in tl) {
        return "macho";
    }
    if "wasm" in tl {
        return "wasm";
    }
    return "elf";
}

def build_link_plan(
    prog: JacProgram,
    roots: list[str],
    options: (CompileOptions | None) = None,
    mode: str = "",
    native_unit: bool = False
) -> LinkPlan {
    opts = options if options is not None else CompileOptions();
    if native_unit and not opts.native_unit {
        opts = opts.clone_for_native_import();
        opts.native_unit = True;
    }
    link_mode = mode or (opts.native_link_mode or NATIVE_LINK_MODE_OBJECTS);
    triple = opts.effective_triple();
    if _platform_of(triple) in ("pe", "wasm") {
        link_mode = NATIVE_LINK_MODE_BITCODE;
    }
    registry = prog.native_units();
    real_roots = [os.path.realpath(r) for r in roots];
    units: dict[str, LinkUnit] = {};
    edges: dict[str, list[str]] = {};
    order: list[str] = [];

    def walk_unit(path: str, stack: list[str]) -> None {
        if path in units {
            return;
        }
        if path in stack {
            return;
        }
        for dep in registry.known_native_deps(path, opts.native_unit) {
            walk_unit(dep, stack + [path]);
        }
        errs_before = len(prog.errors_had);
        ent = registry.ensure(path, compile_on_miss=False, options=opts);
        if ent is None and os.path.isfile(path) {
            ent = registry.compile_unit_detached(path, opts);
        }
        if ent is None {
            why = [
                e.pretty_print().split("\n")[0] for e in prog.errors_had[errs_before:]
            ][:5];
            crashed = registry.failures.get(path);
            if crashed {
                why.append(crashed);
            }
            detail = ("; ".join(why)) if why else "no diagnostic was recorded";
            raise LinkPlanError(
                f"{path} is not a native unit for this codegen identity, or "
                f"failed to lower ({detail})"
            );
        }
        import from jaclang.compiler.driver.jir { module_cache_key }
        try {
            modkey = module_cache_key(path);
        } except OSError {
            """A root compiled from a string has no file; its interface
            digest is the only identity the plan can give it.""";
            modkey = ent.digest;
        }
        units[path] = LinkUnit(
            path=path,
            prefix=ent.iface.prefix,
            iface=ent.iface,
            digest=ent.digest,
            modkey=modkey,
            is_root=(path in real_roots)
        );
        deps = sorted(os.path.realpath(d) for d in ent.iface.deps);
        edges[path] = deps;
        for dep in deps {
            walk_unit(dep, stack + [path]);
        }
        order.append(path);
    }

    for root_u in real_roots {
        walk_unit(root_u, []);
    }

    for _round in range(6) {
        unsettled: dict[str, str] = {};
        for (path, deps) in edges.items() {
            recorded_for = dict(registry.recorded_native_deps(path));
            for dep in deps {
                live = units.get(dep);
                if live is None {
                    continue;
                }
                recorded = recorded_for.get(dep, "");
                if not recorded {
                    unsettled[path] = f"compiled while {dep} was still building";
                } elif recorded != live.digest {
                    unsettled[path] = (
                        f"compiled against {dep} at {recorded[:12]}, now {live.digest[:12]}"
                    );
                }
            }
        }
        if not unsettled {
            break;
        }
        if env_na_debug() {
            sys.stderr.write(
                f"[link plan] round {_round + 1}: {len(unsettled)} unit(s) unsettled\n"
                    + "".join(
                        f"  {os.path.basename(p)}: {why}\n"
                        for (p, why) in sorted(unsettled.items())
                    )
            );
        }
        if _round == 5 {
            raise LinkPlanError(
                "native interface disagreement did not settle: "
                    + "; ".join(f"{p}: {why}" for (p, why) in sorted(unsettled.items()))
            );
        }
        for path in sorted(unsettled.keys()) {
            registry.forget(path);
            try {
                prog.invalidate_module(path);
            } except Exception {}
            ent = registry.compile_unit_detached(path, opts);
            if ent is None {
                raise LinkPlanError(
                    f"{path} failed to lower against its dependencies "
                    f"({registry.failures.get(path) or 'no diagnostic was recorded'})"
                );
            }
            units[path].iface = ent.iface;
            units[path].digest = ent.digest;
            units[path].prefix = ent.iface.prefix;
        }
    }

    ordered = [units[p] for p in order];
    ordered.sort(key=lambda (u: LinkUnit) { (1 if u.is_root else 0, ); });
    check_pub_collisions(ordered);
    return LinkPlan(
        prog=prog,
        options=opts,
        roots=real_roots,
        units=ordered,
        mode=link_mode,
        triple=triple
    );
}

def _target_machine(plan: LinkPlan, kind: ArtifactKind) -> TargetMachine {
    init_object_codegen();
    target_ovr = plan.options.native_target or "";
    target = (
        llvm.Target.from_triple(target_ovr)
            if target_ovr
            else llvm.Target.from_default_triple()
    );
    assert isinstance(target, llvm.Target);
    opt = 0 if plan.options.native_debug else 2;
    if kind == ArtifactKind.JIT {
        tm = target.create_target_machine(opt=opt, jit=True);
    } else {
        tm = target.create_target_machine(
            opt=opt, reloc=NATIVE_RELOC_MODEL, codemodel=NATIVE_CODE_MODEL
        );
    }
    assert isinstance(tm, llvm.TargetMachine);
    return tm;
}

def _glue_module(
    plan: LinkPlan, spec: GlueSpec, tm: (TargetMachine | None) = None
) -> tuple[ModuleRef, list[str]] {
    if tm is not None and not spec.data_layout {
        spec.data_layout = str(tm.target_data);
    }
    (ir_text, exports) = link_glue_ir(spec);
    mod = llvm.parse_assembly(ir_text);
    mod.verify();
    return (mod, exports);
}

def whole_program_module(
    plan: LinkPlan, spec: GlueSpec
) -> tuple[ModuleRef, list[str]] {
    registry = plan.prog.native_units();
    merged: (ModuleRef | None) = None;
    for u in plan.units {
        bc = registry.bitcode_for(u.path, plan.options);
        if bc is None {
            raise LinkPlanError(f"no bitcode for native unit {u.path}");
        }
        unit_mod = llvm.parse_bitcode(bc);
        assert isinstance(unit_mod, llvm.ModuleRef);
        if merged is None {
            merged = unit_mod;
        } else {
            merged.link_in(unit_mod);
        }
    }
    if merged is None {
        raise LinkPlanError("link plan holds no units");
    }
    (glue, exports) = _glue_module(plan, spec);
    merged.link_in(glue);
    merged.verify();
    return (merged, exports);
}

def unit_objects(
    plan: LinkPlan, spec: GlueSpec, tm: TargetMachine
) -> tuple[list[bytes], list[str]] {
    registry = plan.prog.native_units();
    objs: list[bytes] = [];
    root_u = plan.root_unit();
    ordered = [root_u]
        + [
            u
            for u in plan.units
            if u is not root_u
        ];
    for u in ordered {
        object_bytes = registry.object_for(u.path, plan.options);
        if object_bytes is None {
            raise LinkPlanError(f"no object for native unit {u.path}");
        }
        objs.append(object_bytes);
    }
    (glue_mod, exports) = _glue_module(plan, spec, tm);
    glue_obj = tm.emit_object(glue_mod);
    assert isinstance(glue_obj, bytes);
    objs.append(glue_obj);
    return (objs, exports);
}

def optimize_whole_program(
    plan: LinkPlan, merged: ModuleRef, kind: ArtifactKind, tm: TargetMachine
) -> None {
    opt_level = 0 if plan.options.native_debug else int(plan.options.opt_level or 0);
    if opt_level <= 0 {
        return;
    }
    pto = llvm.create_pipeline_tuning_options(speed_level=opt_level);
    pb = llvm.create_pass_builder(tm, pto);
    assert isinstance(pb, llvm.PassBuilder);
    mpm = pb.getModulePassManager();
    assert isinstance(mpm, llvm.ModulePassManager);
    if kind == ArtifactKind.EXECUTABLE {
        mpm.add_internalize_pass();
    }
    mpm.run(merged, pb);
}

def plan_objects(
    plan: LinkPlan, spec: GlueSpec, kind: ArtifactKind, tm: TargetMachine
) -> tuple[list[bytes], list[str]] {
    if plan.mode == NATIVE_LINK_MODE_OBJECTS {
        return unit_objects(plan, spec, tm);
    }
    (merged, exports) = whole_program_module(plan, spec);
    optimize_whole_program(plan, merged, kind, tm);
    dump_path = plan.options.dump_ir_path or "";
    if dump_path {
        with open(dump_path, "w") as df {
            df.write(str(merged));
        }
    }
    object_bytes = tm.emit_object(merged);
    assert isinstance(object_bytes, bytes);
    return ([object_bytes], exports);
}

def units_source_key(paths: list[str], options: CompileOptions) -> str {
    import from jaclang.compiler.driver.jir {
        module_cache_key,
        running_compiler_digest
    }
    h = hashlib.sha256();
    h.update(running_compiler_digest().encode("utf-8"));
    h.update(options.codegen_identity().encode("utf-8"));
    h.update(options.effective_triple().encode("utf-8"));
    for path in sorted(os.path.realpath(p) for p in paths) {
        h.update(path.encode("utf-8"));
        try {
            h.update(module_cache_key(path).encode("utf-8"));
        } except OSError {
            h.update(b"missing");
        }
    }
    return h.hexdigest();
}

def _write_sidecar(
    plan: LinkPlan, output_path: str, plan_digest: str
) -> tuple[dict, str] {
    classes = plan.merged_layout();
    ldigest = layout_digest_of(classes);
    unit_paths = [u.path for u in plan.units];
    sidecar = {
        "classes": classes,
        "plan_digest": plan_digest,
        "layout_digest": ldigest,
        "units": unit_paths,
        "source_key": units_source_key(unit_paths, plan.options)
    };
    with open(output_path + ".layout.json", "w", encoding="utf-8") as lf {
        lf.write(json.dumps(sidecar, sort_keys=True));
    }
    return (classes, ldigest);
}

def _sha256_of(path: str) -> str {
    h = hashlib.sha256();
    with open(path, "rb") as f {
        h.update(f.read());
    }
    return h.hexdigest();
}

def link_artifact(
    plan: LinkPlan,
    output_path: str,
    kind: ArtifactKind,
    log: any = None,
    app_imports: (set | None) = None
) -> LinkResult {
    if kind == ArtifactKind.WASM {
        return link_wasm(plan, output_path, app_imports);
    }
    platform = _platform_of(plan.triple);
    is_macos = platform == "macho";
    is_windows = platform == "pe";
    shared = kind == ArtifactKind.SHARED;

    clib_paths = plan.clib_paths();
    clib_symbol_lib = plan.clib_symbol_lib();
    (archive_members, floor_handled) = collect_floor_archives(
        clib_paths, clib_symbol_lib, plan.triple, is_macos
    );
    if log is not None and archive_members {
        log(f"  Static-linking {len(archive_members)} floor archive member(s).");
    }
    needed_libs: list[str] = [];
    if is_windows {
        needed_libs = ["msvcrt.dll"];
    } elif is_macos {
        needed_libs = ["/usr/lib/libSystem.B.dylib"];
    }
    lib_norm = clib_needed_libs(needed_libs, clib_paths, floor_handled);
    is_linux_exec = (not shared) and platform == "elf";
    static_musl = is_linux_exec and (len(needed_libs) == 0);

    tm = _target_machine(plan, kind);
    spec = plan.glue_spec(kind, platform, static_musl);
    (objects, glue_exports) = plan_objects(plan, spec, kind, tm);

    inputs = LinkInputs(objects=objects, archive_members=archive_members);
    if shared {
        inputs.init_funcs = [SHARED_INIT_SYMBOL];
        for sym in plan.pub_exports() + glue_exports {
            if sym not in inputs.export_symbols {
                inputs.export_symbols.append(sym);
            }
        }
        if not inputs.export_symbols {
            raise LinkPlanError(
                "nothing to export from a shared library: no `:pub` functions "
                "or globals in the plan; mark exports with `def:pub` / `glob:pub`"
            );
        }
    }
    if (shared or (is_linux_exec and not static_musl)) and platform == "elf" {
        for lib in ("libc.so.6", "libm.so.6") {
            if lib not in needed_libs {
                needed_libs.append(lib);
            }
        }
    }
    inputs.needed_libs = needed_libs;
    inputs.symbol_lib_map = clib_symbol_lib_map(
        clib_symbol_lib, floor_handled, lib_norm, shared, is_macos
    );
    inputs.static_musl = static_musl;

    soname = os.path.basename(output_path);
    if is_windows {
        import from jaclang.compiler.backends.native.pe_linker { PeLinker }
        ok = PeLinker.link(
            objects=inputs.objects,
            output_path=output_path,
            needed_libs=inputs.needed_libs,
            symbol_lib_map=inputs.symbol_lib_map,
            shared=shared,
            export_symbols=inputs.export_symbols,
            init_funcs=inputs.init_funcs,
            soname=soname
        );
    } elif is_macos {
        import from jaclang.compiler.backends.native.macho_linker { MachOLinker }
        ok = MachOLinker.link(
            objects=inputs.objects,
            output_path=output_path,
            needed_libs=inputs.needed_libs,
            symbol_lib_map=inputs.symbol_lib_map,
            shared=shared,
            export_symbols=inputs.export_symbols,
            init_funcs=inputs.init_funcs,
            soname=soname,
            archive_members=inputs.archive_members
        );
    } else {
        import from jaclang.compiler.backends.native.elf_linker { ElfLinker }
        if static_musl {
            musl = collect_musl_static(inputs.objects, plan.triple);
            if musl is None {
                raise LinkPlanError(
                    "Static musl runtime not found. Expected a vendored musl "
                    "libc.a under .pbs-build/<arch>/musl/lib (run `zig build "
                    "vendor-musl`) or set JAC_NATIVE_MUSL_DIR."
                );
            }
            (musl_members, crt_objects) = musl;
            inputs.archive_members = inputs.archive_members + musl_members;
            inputs.crt_objects = crt_objects;
            if log is not None {
                log(
                    f"  Static-linking musl: {len(musl_members)} libc member(s) + "
                    f"{len(crt_objects)} crt object(s)."
                );
            }
        }
        ok = ElfLinker.link(
            objects=inputs.objects,
            output_path=output_path,
            needed_libs=inputs.needed_libs,
            crt_objects=inputs.crt_objects,
            shared=shared,
            export_symbols=inputs.export_symbols,
            init_funcs=inputs.init_funcs,
            soname=soname,
            archive_members=inputs.archive_members,
            static_link=static_musl
        );
    }
    if not ok {
        raise LinkPlanError(f"{platform} link failed: could not parse an object");
    }
    digest = plan.plan_digest();
    (classes, ldigest) = _write_sidecar(plan, output_path, digest);
    return LinkResult(
        output_path=output_path,
        plan_digest=digest,
        layout_digest=ldigest,
        sha256=_sha256_of(output_path),
        classes=classes,
        units=[u.path for u in plan.units]
    );
}

def link_wasm(
    plan: LinkPlan, output_path: str, app_imports: (set | None) = None
) -> LinkResult {
    import from jaclang.compiler.backends.native.wasm_build { emit_wasm_from_ir }
    spec = plan.glue_spec(ArtifactKind.WASM, "wasm", False);
    (merged, _exports) = whole_program_module(plan, spec);
    imports: set[str] = set(app_imports or set());
    imports.update(plan.clib_symbol_lib().keys());
    wasm_bytes = emit_wasm_from_ir(str(merged), app_imports=imports);
    with open(output_path, "wb") as wf {
        wf.write(wasm_bytes);
    }
    digest = plan.plan_digest();
    (classes, ldigest) = _write_sidecar(plan, output_path, digest);
    return LinkResult(
        output_path=output_path,
        plan_digest=digest,
        layout_digest=ldigest,
        sha256=_sha256_of(output_path),
        classes=classes,
        units=[u.path for u in plan.units]
    );
}

def undefined_functions(mod: ModuleRef) -> list[str] {
    names: list[str] = [];
    mod_any: any = mod;
    for fn in mod_any.functions {
        if fn.is_declaration and not str(fn.name).startswith("llvm.") {
            names.append(str(fn.name));
        }
    }
    return sorted(names);
}

def jit_engine(plan: LinkPlan) -> ExecutionEngine {
    tm = _target_machine(plan, ArtifactKind.JIT);
    spec = plan.glue_spec(ArtifactKind.JIT, _platform_of(plan.triple), False);
    (merged, _exports) = whole_program_module(plan, spec);
    optimize_whole_program(plan, merged, ArtifactKind.JIT, tm);
    if env_na_debug() {
        sys.stderr.write(
            f"[jit] {len(plan.units)} unit(s), inits {plan.init_symbols()}, "
            f"undefined: {undefined_functions(merged)}\n"
        );
    }
    for lib_path in plan.clib_paths() {
        try {
            jit_load_clib(lib_path);
        } except Exception {}
    }
    engine = llvm.create_mcjit_compiler(merged, tm);
    assert isinstance(engine, llvm.ExecutionEngine);
    install_native_static_init(engine, plan.init_symbols());
    root_u = plan.root_unit();
    try {
        setattr(engine, "_jac_unit_path", root_u.path);
        setattr(engine, "_jac_native_iface", root_u.iface);
    } except Exception {}
    return engine;
}

def jit_engine_for_module(
    prog: JacProgram, module: any, options: CompileOptions
) -> (ExecutionEngine | None) {
    if not (module?.loc and module.loc.mod_path) {
        return None;
    }
    if module.gen.native_iface is not None {
        prog.native_units().record(
            module.loc.mod_path, module.gen.native_iface, options
        );
    }
    plan = build_link_plan(
        prog, [module.loc.mod_path], options, mode=NATIVE_LINK_MODE_BITCODE
    );
    return jit_engine(plan);
}

def jit_engine_for_cached(
    prog: JacProgram, path: str, options: CompileOptions
) -> (ExecutionEngine | None) {
    plan = build_link_plan(prog, [path], options, mode=NATIVE_LINK_MODE_BITCODE);
    return jit_engine(plan);
}
