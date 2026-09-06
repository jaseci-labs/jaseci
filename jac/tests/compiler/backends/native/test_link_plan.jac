"""The link plan over a five-module diamond (#8943).

`top` imports `left`, `right` and `extra`, which all import `base`; the
region arena joins by dependency edge like any toolchain unit. The plan
walks the native edges each unit's interface records, orders the units
dependencies first, and links their objects plus one synthesized glue
object. Touching a body rewrites one object and leaves every interface
alone; touching an interface moves the dependents' recorded digests, and a
unit whose recorded digests disagree with the plan is recompiled until they
agree. Two links from one cache are byte-identical, and the whole-program
mode produces the same executable behavior from the same cache.
"""

import hashlib;
import os;
import shutil;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.compile_options {
    CompileOptions,
    NATIVE_LINK_MODE_BITCODE,
    NATIVE_LINK_MODE_OBJECTS
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.backends.native.link_plan {
    ArtifactKind,
    build_link_plan,
    link_artifact
}
import from jaclang.compiler.frontend.codeinfo {
    is_kernel_unit_path,
    native_entry_name,
    native_glob_init_name
}

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures" / "link_diamond"),
     UNITS: list[str] = ["base.jac", "left.jac", "right.jac", "extra.jac", "top.jac"];

def _opts(mode: str = "") -> CompileOptions {
    return CompileOptions(
        aot_mode=True,
        default_codespace='native',
        force_target_program=True,
        skip_native_engine=True,
        native_link_mode=(mode or None)
    );
}

"""A private copy of the diamond, so edits never touch the fixtures."""
def _diamond_copy -> str {
    tmp = tempfile.mkdtemp(prefix="jac-diamond-");
    for name in UNITS {
        shutil.copy(os.path.join(FIXTURES, name), os.path.join(tmp, name));
    }
    return tmp;
}

def _plan_for(root_dir: str, mode: str = "") -> tuple[JacProgram, any] {
    prog = JacProgram();
    opts = _opts(mode);
    top = os.path.join(root_dir, "top.jac");
    prog.options = opts;
    return (prog, build_link_plan(prog, [top], opts, mode=mode));
}

def _can_link_host -> bool {
    return sys.platform.startswith("linux") or sys.platform == "darwin";
}

test "the plan holds every unit of the diamond, dependencies first" {
    root_dir = _diamond_copy();
    (prog, plan) = _plan_for(root_dir);
    toolchain = [
        u.path
        for u in plan.units
        if is_kernel_unit_path(u.path)
    ];
    names = [
        os.path.basename(u.path)
        for u in plan.units
        if not is_kernel_unit_path(u.path)
    ];
    assert sorted(names) == sorted(UNITS) , names;
    assert toolchain;
    for u in plan.units {
        for dep in u.iface.deps {
            assert plan.units.index(plan.unit(dep)) < plan.units.index(u) , f"{dep} must precede its consumer {u.path}";
        }
    }
    assert names[-1] == "top.jac" , "the root_dir comes last";
    assert names.index("base.jac") < names.index("left.jac");
    assert names.index("base.jac") < names.index("right.jac");
    assert names.index("base.jac") < names.index("extra.jac");
    assert plan.root_unit().path == os.path.realpath(os.path.join(root_dir, "top.jac"));
    inits = plan.init_symbols();
    assert native_glob_init_name(os.path.join(root_dir, "base.jac")) in inits;
    assert inits.index(native_glob_init_name(os.path.join(root_dir, "base.jac")))
        < inits.index(native_glob_init_name(os.path.join(root_dir, "left.jac")));
    assert inits[-1] == native_glob_init_name(os.path.join(root_dir, "top.jac"));
    assert plan.root_unit().iface.entry_symbol
        == native_entry_name(os.path.join(root_dir, "top.jac"));
    assert "diamond_abi_version" in plan.pub_exports();
}

test "a body edit rewrites one object and keeps every interface" {
    root_dir = _diamond_copy();
    (prog, plan) = _plan_for(root_dir);
    registry = prog.native_units();
    obj_before = registry.object_for(os.path.join(root_dir, "left.jac"), _opts());
    base_obj_before = registry.object_for(os.path.join(root_dir, "base.jac"), _opts());
    assert obj_before is not None and base_obj_before is not None;

    left = Path(root_dir) / "left.jac";
    left.write_text(left.read_text().replace("scale(p.sum(), 2)", "scale(p.sum(), 3)"));
    (prog2, plan2) = _plan_for(root_dir);
    registry2 = prog2.native_units();
    assert registry2.compiled_paths == [os.path.realpath(str(left))] , registry2.compiled_paths;
    assert registry2.object_for(str(left), _opts()) != obj_before , "left's object must be rebuilt";
    assert registry2.object_for(os.path.join(root_dir, "base.jac"), _opts())
        == base_obj_before , "base is untouched";
    for u in plan2.units {
        prev = plan.unit(u.path);
        assert prev is not None and prev.digest == u.digest , f"{u.path} interface moved on a body edit";
    }
}

test "a no-op build lowers no units and preserves the linked artifact" {
    if _can_link_host() {
        root_dir = _diamond_copy();
        (prog, plan) = _plan_for(root_dir);
        output = os.path.join(root_dir, "program");
        first = link_artifact(plan, output, ArtifactKind.EXECUTABLE);
        before = os.stat(output).st_mtime_ns;
        (warm_prog, warm_plan) = _plan_for(root_dir);
        assert warm_prog.native_units().compiled_paths == [] , warm_prog.native_units().compiled_paths;
        second = link_artifact(warm_plan, output, ArtifactKind.EXECUTABLE);
        assert second.reused;
        assert second.sha256 == first.sha256;
        assert os.stat(output).st_mtime_ns == before;
        assert warm_prog.analysis.cache_events.get("native_link", 0) == 0;
        assert warm_prog.analysis.cache_events.get("native_link_hit", 0) == 1;
        Path(output).write_bytes(b"corrupted");
        repaired = link_artifact(warm_plan, output, ArtifactKind.EXECUTABLE);
        assert not repaired.reused;
        assert repaired.sha256 == first.sha256;
    }
}

test "changing a default argument updates an unchanged caller's executable" {
    if _can_link_host() {
        root_dir = tempfile.mkdtemp(prefix="jac-default-link-");
        base = Path(root_dir) / "base.jac";
        base.write_text("def f(x: int = 1) -> int { return x; }");
        consumer = Path(root_dir) / "consumer.jac";
        consumer.write_text("import from base { f }\ndef g() -> int { return f(); }");
        top = Path(root_dir) / "top.jac";
        top.write_text("import from consumer { g }\nwith entry { print(g()); }");
        (prog, plan) = _plan_for(root_dir);
        output = os.path.join(root_dir, "program");
        link_artifact(plan, output, ArtifactKind.EXECUTABLE);
        base.write_text("def f(x: int = 2) -> int { return x; }");
        (updated_prog, updated_plan) = _plan_for(root_dir);
        link_artifact(updated_plan, output, ArtifactKind.EXECUTABLE);
        run = subprocess.run([output], capture_output=True, text=True);
        assert run.returncode == 0 , run.stderr;
        assert run.stdout.strip() == "2" , run.stdout;
        assert str(consumer.resolve()) in updated_prog.native_units().compiled_paths;
    }
}

test "bitcode builds emit objects on demand without lowering again" {
    root_dir = _diamond_copy();
    (prog, plan) = _plan_for(root_dir, NATIVE_LINK_MODE_BITCODE);
    registry = prog.native_units();
    unit_path = plan.root_unit().path;
    ent = registry.entries[unit_path];
    assert ent.bitcode is not None and ent.object_bytes is None;
    emitted_before = list(registry.compiled_paths);
    obj_bytes = registry.object_for(unit_path, _opts());
    assert obj_bytes is not None;
    assert registry.compiled_paths == emitted_before;
}

test "settlement refreshes edges and removes dependencies no longer reachable" {
    import from unittest.mock { patch }
    import from jaclang.compiler.driver.native_iface { NativeIface }
    scratch = Path(tempfile.mkdtemp(prefix="jac-plan-edges-"));
    paths: dict[str, str] = {};
    for name in ["top", "old", "new"] {
        path = scratch / (name + ".jac");
        path.write_text("def f -> int { return 1; }");
        paths[name] = str(path.resolve());
    }
    prog = JacProgram();
    opts = _opts();
    prog.options = opts;
    registry = prog.native_units();
    registry.record(paths["old"], NativeIface(module="old", prefix="old"), opts);
    replacement = registry.record(
        paths["new"], NativeIface(module="new", prefix="new"), opts
    );
    registry.record(
        paths["top"], NativeIface(module="top", prefix="top", deps=[paths["old"]]), opts
    );
    def recompile(path: str, options: CompileOptions) -> any {
        assert path == paths["top"];
        return registry.record(
            path,
            NativeIface(module="top", prefix="top", deps=[paths["new"]]),
            options,
            dep_digests={paths["new"]: replacement.digest}
        );
    }
    with patch.object(
        registry, "compile_unit_detached", side_effect=recompile
    ) as compile_unit {
        plan = build_link_plan(prog, [paths["top"]], opts);
        assert compile_unit.call_count == 1;
    }
    assert [u.path for u in plan.units] == [paths["new"], paths["top"]];
}

test "an imported generic body invalidates native code after a bytecode cache merge" {
    if _can_link_host() {
        import from jaclang.compiler.driver.jir {
            SEC_CTDEPS,
            SEC_NCTDEPS,
            get_module_cache_path,
            read_section_bytes,
            write_module_cache
        }
        scratch = Path(tempfile.mkdtemp(prefix="jac-generic-incremental-"));
        base = scratch / "base.jac";
        base.write_text("def pick[T](xs: list[T]) -> T { return xs[0]; }");
        top = scratch / "top.jac";
        top.write_text(
            "import from base { pick }\nwith entry { print(pick([1, 2])); }"
        );
        (prog, plan) = _plan_for(str(scratch));
        native_deps = read_section_bytes(
            get_module_cache_path(str(top)).read_bytes(), SEC_NCTDEPS
        );
        assert native_deps is not None;
        write_module_cache(str(top), None, extra_sections={SEC_CTDEPS: b""});
        assert read_section_bytes(
            get_module_cache_path(str(top)).read_bytes(), SEC_NCTDEPS
        )
            == native_deps;
        base.write_text("def pick[T](xs: list[T]) -> T { return xs[1]; }");
        (updated_prog, updated_plan) = _plan_for(str(scratch));
        assert str(top.resolve()) in updated_prog.native_units().compiled_paths;
        output = str(scratch / "program");
        link_artifact(updated_plan, output, ArtifactKind.EXECUTABLE);
        run = subprocess.run([output], capture_output=True, text=True);
        assert run.returncode == 0 , run.stderr;
        assert run.stdout.strip() == "2" , run.stdout;
    }
}

test "an interface edit moves the dependents' recorded digests" {
    root_dir = _diamond_copy();
    (prog, plan) = _plan_for(root_dir);
    base = Path(root_dir) / "base.jac";
    base_digest = plan.unit(str(base)).digest;
    base.write_text(
        base.read_text() + "\ndef newly_exported(v: int) -> int {\n    return v;\n}\n"
    );
    (prog2, plan2) = _plan_for(root_dir);
    assert plan2.unit(str(base)).digest != base_digest , "an export must move base's digest";
    for u in plan2.units {
        for (dep, recorded) in prog2.native_units().recorded_native_deps(u.path) {
            live = plan2.unit(dep);
            if live is not None {
                assert recorded == live.digest , f"{u.path} still records a stale digest for {dep}";
            }
        }
    }
}

test "a stale recorded dependency is recompiled until the plan agrees" {
    root_dir = _diamond_copy();
    (prog, plan) = _plan_for(root_dir);
    registry = prog.native_units();
    top = os.path.realpath(os.path.join(root_dir, "top.jac"));
    stale = dict(registry.entries[top].dep_digests);
    assert stale , "top must have recorded its dependencies";
    victim = sorted(stale.keys())[0];
    stale[victim] = "0" * 64;
    registry.entries[top].dep_digests = stale;
    plan2 = build_link_plan(prog, [top], _opts());
    recorded = dict(registry.recorded_native_deps(top));
    victim_unit = plan2.unit(victim);
    assert victim_unit is not None , victim;
    assert recorded.get(victim) == victim_unit.digest , recorded;
    for u in plan2.units {
        rows: list[tuple[str, str]] = registry.recorded_native_deps(u.path);
        for (dep, digest) in rows {
            live = plan2.unit(dep);
            assert live is None or live.digest == digest , f"{u.path} disagrees on {dep}";
        }
    }
}

test "two links from one cache are byte-identical" {
    if not _can_link_host() {
        assert True;
    } else {
        root_dir = _diamond_copy();
        (prog, plan) = _plan_for(root_dir);
        out_a = os.path.join(root_dir, "top_a");
        out_b = os.path.join(root_dir, "top_b");
        ra = link_artifact(plan, out_a, ArtifactKind.EXECUTABLE);
        rb = link_artifact(plan, out_b, ArtifactKind.EXECUTABLE);
        assert ra.plan_digest == rb.plan_digest;
        assert ra.sha256 == rb.sha256 , "the link must be deterministic";
        assert ra.layout_digest == rb.layout_digest;
        sidecar = Path(out_a + ".layout.json").read_text();
        assert ra.plan_digest in sidecar;
        run = subprocess.run([out_a], capture_output=True, text=True);
        assert run.returncode == 0 , run.stderr;
        assert run.stdout.strip() == "34" , run.stdout;
    }
}

test "objects mode and bitcode mode agree on the program" {
    if not _can_link_host() {
        assert True;
    } else {
        root_dir = _diamond_copy();
        (prog_o, plan_o) = _plan_for(root_dir, NATIVE_LINK_MODE_OBJECTS);
        (prog_b, plan_b) = _plan_for(root_dir, NATIVE_LINK_MODE_BITCODE);
        assert plan_o.mode == NATIVE_LINK_MODE_OBJECTS;
        assert plan_b.mode == NATIVE_LINK_MODE_BITCODE;
        out_o = os.path.join(root_dir, "top_objects");
        out_b = os.path.join(root_dir, "top_bitcode");
        link_artifact(plan_o, out_o, ArtifactKind.EXECUTABLE);
        link_artifact(plan_b, out_b, ArtifactKind.EXECUTABLE);
        for out in (out_o, out_b) {
            run = subprocess.run([out], capture_output=True, text=True);
            assert run.returncode == 0 , run.stderr;
            assert run.stdout.strip() == "34" , run.stdout;
        }
    }
}

test "a shared link exports only the C ABI" {
    if not _can_link_host() {
        assert True;
    } else {
        root_dir = _diamond_copy();
        prog = JacProgram();
        opts = _opts();
        base = os.path.join(root_dir, "base.jac");
        prog.compile(file_path=base, options=opts);
        plan = build_link_plan(prog, [base], opts);
        suffix = ".dylib" if sys.platform == "darwin" else ".so";
        out = os.path.join(root_dir, "libbase" + suffix);
        result = link_artifact(plan, out, ArtifactKind.SHARED);
        import ctypes;
        lib = ctypes.CDLL(out);
        assert lib.diamond_abi_version() == 1;
        assert hasattr(lib, "__jac_shared_init");
        assert hasattr(lib, "jac_retain") and hasattr(lib, "jac_release");
        assert result.sha256 == hashlib.sha256(Path(out).read_bytes()).hexdigest();
    }
}

test "shared retain and release helpers honor --gc none" {
    if _can_link_host() {
        import ctypes;
        import from jaclang.compiler.frontend.codeinfo {
            HDR_TOTAL,
            HDR_ALLOC_ID_OFF,
            HDR_MAGIC_SHIFT_BASE,
            HDR_RC_OFF
        }
        root_dir = _diamond_copy();
        prog = JacProgram();
        opts = _opts();
        opts.na_gc_mode = "none";
        base = os.path.join(root_dir, "base.jac");
        plan = build_link_plan(prog, [base], opts);
        suffix = ".dylib" if sys.platform == "darwin" else ".so";
        out = os.path.join(root_dir, "libbase" + suffix);
        link_artifact(plan, out, ArtifactKind.SHARED);
        lib = ctypes.CDLL(out);
        storage = ctypes.create_string_buffer(HDR_TOTAL + 8);
        ctypes.c_int64.from_buffer(storage, HDR_TOTAL + HDR_ALLOC_ID_OFF).value = HDR_MAGIC_SHIFT_BASE;
        count = ctypes.c_int64.from_buffer(storage, HDR_TOTAL + HDR_RC_OFF);
        count.value = 2;
        ptr = ctypes.addressof(storage) + HDR_TOTAL;
        for name in ("jac_retain", "jac_release") {
            helper = getattr(lib, name);
            helper.argtypes = [ctypes.c_void_p];
            helper.restype = None;
            helper(ptr);
            assert count.value == 2 , f"--gc none {name} changed the reference count";
        }
    }
}

test "the glue supplies the region-death hook only when no unit does" {
    import from jaclang.compiler.backends.native.link_glue {
        REGION_DIED_HOOK,
        link_glue_ir
    }
    root_dir = _diamond_copy();
    (prog, plan) = _plan_for(root_dir);
    spec = plan.glue_spec(ArtifactKind.JIT, "jit", False);
    assert spec.needs_region_hook;
    (glue_ir, _exports) = link_glue_ir(spec);
    assert f"define void @{REGION_DIED_HOOK}(" in glue_ir;

    graph = os.path.join(root_dir, "graph.jac");
    with open(graph, "w") as f {
        f.write(
            "node Cell { has v: int = 0; }\n"
            "walker Sum { has total: int = 0;\n"
            "    can add with Cell entry { self.total += here.v; visit [-->]; }\n"
            "}\n"
            "with entry { r = Cell(v=1); r ++> Cell(v=2); print(Sum() spawn r); }\n"
        );
    }
    gprog = JacProgram();
    opts = _opts();
    gprog.compile(file_path=graph, options=opts);
    assert not gprog.errors_had , [str(e) for e in gprog.errors_had];
    gplan = build_link_plan(gprog, [graph], opts);
    suppliers = [
        u.path
        for u in gplan.units
        if REGION_DIED_HOOK in u.iface.exports
    ];
    assert suppliers , [u.path for u in gplan.units];
    gspec = gplan.glue_spec(ArtifactKind.JIT, "jit", False);
    assert not gspec.needs_region_hook;
    (gglue_ir, _gexports) = link_glue_ir(gspec);
    assert REGION_DIED_HOOK not in gglue_ir;
}


test "the glue defines atexit wherever glibc would leave it unresolved" {
    import from jaclang.compiler.backends.native.link_glue { link_glue_ir }
    root_dir = _diamond_copy();
    (prog, plan) = _plan_for(root_dir);
    shim = "define hidden i32 @atexit(";
    dynamic_exec = plan.glue_spec(ArtifactKind.EXECUTABLE, "elf", False);
    assert dynamic_exec.needs_atexit_shim , (
        "a dynamically linked ELF executable resolves atexit itself"
    );
    assert shim in link_glue_ir(dynamic_exec)[0];
    shared = plan.glue_spec(ArtifactKind.SHARED, "elf", False);
    assert shared.needs_atexit_shim;
    static_exec = plan.glue_spec(ArtifactKind.EXECUTABLE, "elf", True);
    assert not static_exec.needs_atexit_shim , "musl's libc.a supplies atexit";
    assert shim not in link_glue_ir(static_exec)[0];
    macho = plan.glue_spec(ArtifactKind.EXECUTABLE, "macho", False);
    assert not macho.needs_atexit_shim;
    jit = plan.glue_spec(ArtifactKind.JIT, "jit", False);
    assert not jit.needs_atexit_shim;
}

test "a source string can settle after its dependency interface changes" {
    if not _can_link_host() {
        return;
    }
    with tempfile.TemporaryDirectory(prefix="jac-plan-source-") as tmp {
        dep = Path(tmp) / "dep.jac";
        dep.write_text("def answer -> int { return 7; }\n");
        path = str((Path(tmp) / "inline.jac").resolve());
        prog = JacProgram();
        opts = _opts();
        module = prog.compile(
            file_path=path,
            use_str="import from dep { answer }\nwith entry { print(answer()); }\n",
            options=opts
        );
        assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
        registry = prog.native_units();
        ent = registry.record_module(module, opts);
        assert ent is not None;
        ent.dep_digests[str(dep.resolve())] = "";
        plan = build_link_plan(prog, [path], opts);
        assert not os.path.exists(path);
        assert path in registry.compiled_paths;
        output = str(Path(tmp) / "inline-bin");
        link_artifact(plan, output, ArtifactKind.EXECUTABLE);
        result = subprocess.run([output], capture_output=True, text=True);
        assert result.returncode == 0 , result.stderr;
        assert result.stdout.strip() == "7";
    }
}

test "a unit retains prepared dependency interfaces when disk products are unavailable" {
    import from unittest.mock { patch }
    import from jaclang.compiler.driver.nativecache { NativeUnitRegistry }
    root_dir = _diamond_copy();
    (prog, plan) = _plan_for(root_dir);
    registry = prog.native_units();
    top = plan.root_unit().path;
    prior = dict(registry.entries[top].dep_digests);
    assert prior and all(prior.values());
    with patch.object(NativeUnitRegistry, "_module_jir", return_value=None) {
        ent = registry.compile_unit(top, _opts());
    }
    assert ent is not None , registry.failures;
    assert ent.dep_digests == prior;
}

test "an isolated unit retains prepared interfaces without disk lookup" {
    import from unittest.mock { patch }
    import jaclang.compiler.driver.nativecache as cache;
    import from jaclang.compiler.driver.nativecache {
        UNIT_CHILD_DEPTH_ENV,
        UNIT_ISOLATE_ENV
    }
    root_dir = _diamond_copy();
    (prog, plan) = _plan_for(root_dir);
    registry = prog.native_units();
    top = plan.root_unit().path;
    prior = dict(registry.entries[top].dep_digests);
    assert prior and all(prior.values());
    driver = cache._UNIT_CHILD_DRIVER.replace(
        "ent = reg.compile_unit(",
        "from jaclang.compiler.driver.nativecache import NativeUnitRegistry\n"
            + "NativeUnitRegistry._module_jir = lambda self, path: None\n"
            + "ent = reg.compile_unit("
    );
    with patch.object(cache, "_UNIT_CHILD_DRIVER", driver), patch.dict(
        os.environ, {UNIT_ISOLATE_ENV: "1", UNIT_CHILD_DEPTH_ENV: "0"}
    ) {
        ent = registry.compile_unit_detached(top, _opts());
    }
    assert ent is not None , registry.failures;
    assert ent.dep_digests == prior;
    assert prog.analysis.cache_events.get("native_unit_compile_detached", 0) > 0;
}

test "a transferred native record rejects a changed source" {
    root_dir = _diamond_copy();
    (prog, plan) = _plan_for(root_dir);
    path = plan.root_unit().path;
    record = prog.native_units().products_blob(path, _opts(), include_code=False);
    target = JacProgram().native_units();
    assert target.register_products_blob(path, record, _opts()) is not None;
    source = Path(path);
    source.write_text(source.read_text() + "\n# edit during transfer\n");
    assert target.register_products_blob(path, record, _opts()) is None;
}

test "object emission preserves the native record without an existing disk entry" {
    import from jaclang.compiler.driver.jir {
        get_module_cache_path,
        ct_deps_section,
        rebase_ct_deps_section
    }
    root_dir = _diamond_copy();
    (prog, plan) = _plan_for(root_dir, NATIVE_LINK_MODE_BITCODE);
    registry = prog.native_units();
    path = plan.root_unit().path;
    prior = registry.entries[path];
    prior.compile_deps_base = root_dir;
    prior.compile_deps = rebase_ct_deps_section(
        ct_deps_section([os.path.join(root_dir, "base.jac")]), root_dir
    );
    get_module_cache_path(path).unlink();
    assert registry.object_for(path, _opts()) is not None;
    warm = JacProgram().native_units().ensure(
        path, compile_on_miss=False, options=_opts()
    );
    assert warm is not None;
    assert warm.digest == prior.digest;
    assert warm.dep_digests == prior.dep_digests;
    assert warm.bitcode == prior.bitcode;
}
