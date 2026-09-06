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
    mod = prog.compile(file_path=top, options=opts);
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    assert mod.gen.native_iface is not None;
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
    for t in toolchain {
        assert plan.units.index(plan.unit(t))
            < plan.units.index(plan.unit(os.path.join(root_dir, "base.jac"))) , f"{t} is a dependency of every unit and must come first";
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
    assert registry2.object_for(str(left), _opts()) != obj_before , "left's object must be rebuilt";
    assert registry2.object_for(os.path.join(root_dir, "base.jac"), _opts())
        == base_obj_before , "base is untouched";
    for u in plan2.units {
        prev = plan.unit(u.path);
        assert prev is not None and prev.digest == u.digest , f"{u.path} interface moved on a body edit";
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
    stale = dict(registry.recorded_deps.get(top) or {});
    assert stale , "top must have recorded its dependencies";
    victim = sorted(stale.keys())[0];
    stale[victim] = "0" * 64;
    registry.recorded_deps[top] = stale;
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
