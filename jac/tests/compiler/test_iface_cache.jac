"""The analysis cache serves warm work; recompute happens only on a miss.

Acceptance shape of jaseci-labs/jac#8836, asserted through the pass and
cache-event counters rather than timing: a warm no-edit check replays
persisted diagnostics with zero passes; dependency ingestion hydrates
from SEC_IFACE without touching the dep's source pipeline; a body-only
dep edit recompiles the dep but does not cascade (interface hash
cutoff); an interface edit does cascade; JAC_REBUILD recomputes and
rewrites with identical results; verify mode recomputes what was served
and fails loudly when the cache lies.

Every test builds its own throwaway project in a tempdir, whose cache
lands in <srcdir>/.jac/cache, so tests are isolated from each other and
from the user's real cache.
"""

import json;
import os;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.jir {
    HEADER_SIZE,
    SEC_BYTECODE,
    SEC_DEPS,
    SEC_DIAG,
    SEC_IFACE,
    SECTIONS_MAGIC,
    compiler_source_digest,
    get_module_cache_path,
    parse_header,
    read_section_bytes,
    read_sections,
    write_module_cache,
    write_precompiled_jir,
    _manifest_compiler_digest
}

glob DEP_V1: str = "def f() -> int { return 1; }\n",
     DEP_V1_BODY_EDIT: str = "def f() -> int { return 2; }\n",
     DEP_V2_SIGNATURE: str = "def f(x: int) -> int { return x; }\n",
     MAIN_SRC: str = "import from depmod { f }\n\nwith entry { print(f()); }\n";

def _project(dep_body: str = "") -> tuple[str, str] {
    tmp = tempfile.mkdtemp();
    dep = os.path.join(tmp, "depmod.jac");
    with open(dep, "w") as fh {
        fh.write(dep_body or DEP_V1);
    }
    main = os.path.join(tmp, "mainmod.jac");
    with open(main, "w") as fh {
        fh.write(MAIN_SRC);
    }
    return (os.path.realpath(main), os.path.realpath(dep), );
}

def _check_opts -> CompileOptions {
    return CompileOptions(
        no_cgen=True, native_parity=True, force_target_program=True, iface_ok=True
    );
}

def _check(main: str) -> tuple[JacProgram, list[str]] {
    prog = JacProgram();
    prog.compile(main, options=_check_opts());
    rendered = sorted(
        [a.pretty_print() for a in prog.errors_had]
            + [a.pretty_print() for a in prog.warnings_had]
    );
    return (prog, rendered, );
}

def _rewrite(path: str, content: str) {
    import time;
    with open(path, "w") as fh {
        fh.write(content);
    }
    future = time.time() + 2.0;
    os.utime(path, (future, future));
}

test "a checked module persists interface, deps, and diagnostics sections" {
    (main, dep) = _project();
    (prog, _diags) = _check(main);
    main_jir = get_module_cache_path(main);
    dep_jir = get_module_cache_path(dep);
    assert main_jir.exists() , "the checked module wrote no cache JIR";
    assert dep_jir.exists() , "the dependency wrote no cache JIR";
    main_data = main_jir.read_bytes();
    assert read_section_bytes(main_data, SEC_IFACE) is not None , "no SEC_IFACE";
    assert read_section_bytes(main_data, SEC_DIAG) is not None , "no SEC_DIAG";
    deps_raw = read_section_bytes(main_data, SEC_DEPS);
    assert deps_raw is not None , "no SEC_DEPS";
    assert dep.encode() in deps_raw , "SEC_DEPS does not record the dependency";
    dep_iface = read_section_bytes(dep_jir.read_bytes(), SEC_IFACE);
    assert dep_iface is not None , "the dependency persisted no interface";
}

test "a warm no-edit check replays diagnostics and runs zero passes" {
    (main, dep) = _project();
    (cold_prog, cold_diags) = _check(main);
    assert cold_prog.analysis.pass_runs , "the cold run should have run passes";
    (warm_prog, warm_diags) = _check(main);
    events = warm_prog.analysis.cache_events;
    assert events.get("analysis_replay", 0) == 1 , (
        f"warm check did not replay (events: {events})"
    );
    assert not warm_prog.analysis.pass_runs , (
        f"warm no-edit check ran passes: {sorted(warm_prog.analysis.pass_runs)}"
    );
    assert warm_diags == cold_diags , "warm diagnostics diverge from cold";
}

test "dependency ingestion hydrates from the interface, not the source" {
    (main, dep) = _project();
    _check(main);
    prog = JacProgram();
    mod = prog.load_dependency_module(dep);
    events = prog.analysis.cache_events;
    assert events.get("dep_hydrate", 0) == 1 , (
        f"the dependency was not hydrated (events: {events})"
    );
    assert "SymTabBuildPass" not in prog.analysis.pass_runs , (
        "hydrating a dependency ran its frontend"
    );
    assert mod.stub_only , "a hydrated dependency should be interface-only";
    assert "f" in mod.names_in_scope , "the hydrated interface lost a symbol";
}

test "a body-only dependency edit does not cascade to the importer" {
    (main, dep) = _project();
    (_cold, cold_diags) = _check(main);
    _rewrite(dep, DEP_V1_BODY_EDIT);
    (warm_prog, warm_diags) = _check(main);
    events = warm_prog.analysis.cache_events;
    assert events.get("dep_miss_compile", 0) >= 1 , (
        "the edited dependency was not recompiled"
    );
    assert events.get("analysis_replay", 0) == 1 , (
        f"a body-only dep edit cascaded into the importer (events: {events})"
    );
    assert "TypeCheckPass" not in warm_prog.analysis.pass_runs , (
        "a body-only dep edit re-analyzed the importer"
    );
    assert warm_diags == cold_diags , "diagnostics changed on a body-only edit";
}

test "an interface edit re-analyzes the importer" {
    (main, dep) = _project();
    (_cold, cold_diags) = _check(main);
    assert not cold_diags , f"expected a clean cold check, got {cold_diags}";
    _rewrite(dep, DEP_V2_SIGNATURE);
    (warm_prog, _warm_diags) = _check(main);
    events = warm_prog.analysis.cache_events;
    assert events.get("analysis_replay", 0) == 0 , (
        "a signature change was served from the stale analysis cache"
    );
    assert "TypeCheckPass" in warm_prog.analysis.pass_runs , (
        "the importer was not re-analyzed after a signature change"
    );
    assert len(warm_prog.errors_had) > 0 , (
        "the arity error from the signature change was not reported"
    );
}

test "JAC_REBUILD recomputes, rewrites, and matches the cold results" {
    (main, dep) = _project();
    (_cold, cold_diags) = _check(main);
    prior = os.environ.get("JAC_REBUILD");
    os.environ["JAC_REBUILD"] = "1";
    try {
        (rebuild_prog, rebuild_diags) = _check(main);
    } finally {
        if prior is None {
            del os.environ["JAC_REBUILD"];
        } else {
            os.environ["JAC_REBUILD"] = prior;
        }
    }
    events = rebuild_prog.analysis.cache_events;
    assert events.get("analysis_replay", 0) == 0 , (
        "JAC_REBUILD still served from the analysis cache"
    );
    assert rebuild_prog.analysis.pass_runs , "JAC_REBUILD ran no passes";
    assert rebuild_diags == cold_diags , "JAC_REBUILD changed the results";
    (warm_prog, _d) = _check(main);
    assert warm_prog.analysis.cache_events.get("analysis_replay", 0) == 1 , (
        "the rebuild did not leave a hydratable cache behind"
    );
}

test "bytecode and analysis sections share one merged cache JIR" {
    (main, _dep) = _project();
    _check(main);
    wrote = write_module_cache(main, b"fake-bytecode");
    assert wrote , "the merge write was refused";
    data = get_module_cache_path(main).read_bytes();
    assert read_section_bytes(data, SEC_BYTECODE) == b"fake-bytecode";
    assert read_section_bytes(data, SEC_IFACE) is not None , (
        "writing bytecode dropped the analysis sections"
    );
    assert read_section_bytes(data, SEC_DIAG) is not None , (
        "writing bytecode dropped the diagnostics section"
    );
}

test "verify mode accepts an honest cache and rejects a corrupted one" {
    (main, dep) = _project();
    _check(main);
    prior = os.environ.get("JAC_IFACE_VERIFY");
    os.environ["JAC_IFACE_VERIFY"] = "1";
    try {
        (honest_prog, _d) = _check(main);
        assert honest_prog.analysis.cache_events.get("analysis_replay", 0) == 1 , (
            "verify mode must still serve from the cache"
        );

        cache_path = get_module_cache_path(main);
        data = cache_path.read_bytes();
        header = parse_header(data[:HEADER_SIZE]);
        assert header is not None;
        magic: any = SECTIONS_MAGIC;
        pos = data.find(magic, HEADER_SIZE);
        secs = read_sections(data, pos + len(magic));
        payload = json.loads(secs[SEC_DIAG].decode("utf-8"));
        for prof in payload["profiles"].values() {
            prof["errors"].append(
                {
                    "msg": "planted divergence",
                    "code": None,
                    "help": None,
                    "span": [main, 1, 1, 0, 0, 0, 0, "", 0, 0],
                    "related": []
                }
            );
        }
        secs[SEC_DIAG] = json.dumps(payload).encode("utf-8");
        cache_path.write_bytes(write_precompiled_jir(None, "", header.flags, secs));
        caught = False;
        try {
            _check(main);
        } except RuntimeError {
            caught = True;
        }
        assert caught , "verify mode accepted diagnostics the compiler never made";
    } finally {
        if prior is None {
            del os.environ["JAC_IFACE_VERIFY"];
        } else {
            os.environ["JAC_IFACE_VERIFY"] = prior;
        }
    }
}

test "the compiler digest manifest reproduces the full sweep exactly" {
    pkg = tempfile.mkdtemp();
    comp = Path(pkg) / "compiler";
    comp.mkdir();
    (comp / "a.jac").write_text("with entry { print(1); }\n");
    (comp / "b.py").write_text("x = 1\n");
    full = compiler_source_digest(pkg);
    assert _manifest_compiler_digest(pkg) == full , "manifest digest diverged";
    assert _manifest_compiler_digest(pkg) == full , "second (stat-only) run diverged";
    import time;
    (comp / "a.jac").write_text("with entry { print(2); }\n");
    future = time.time() + 2.0;
    os.utime(comp / "a.jac", (future, future));
    changed = compiler_source_digest(pkg);
    assert changed != full;
    assert _manifest_compiler_digest(pkg) == changed , (
        "manifest digest missed an edited file"
    );
}

test "a third-party Python dependency is fingerprinted, never compiled as a target" {
    # A byllm fixture imports litellm, and the sealed in-package lane died
    # on it: `.py` under site-packages counted as a cacheable dependency, so
    # a cache miss compiled it as an interface target, whose interface walk
    # loaded everything it imported, each of which missed and compiled in
    # turn -- 1,450 litellm modules and 14 GB on a 16 GB runner. Third-party
    # Python is opaque to the cutoff now, the way typeshed stubs are: its
    # row carries a content digest, no miss ever compiles it, and it is
    # never served or persisted as an interface target.
    import sys;
    import from jaclang.compiler.driver.jir { compute_stub_module_key }
    tmp = tempfile.mkdtemp();
    sp = os.path.join(tmp, "site-packages");
    pkg = os.path.join(sp, "thirdmod");
    os.makedirs(pkg);
    with open(os.path.join(pkg, "__init__.py"), "w") as fh {
        fh.write("from .sub import helper\n\n__all__ = ['helper']\n");
    }
    with open(os.path.join(pkg, "sub.py"), "w") as fh {
        fh.write("from .deep import base\n\ndef helper() -> int:\n    return base()\n");
    }
    with open(os.path.join(pkg, "deep.py"), "w") as fh {
        fh.write("def base() -> int:\n    return 7\n");
    }
    main = os.path.join(tmp, "usesthird.jac");
    with open(main, "w") as fh {
        fh.write(
            "import from thirdmod { helper }\n\nwith entry { print(helper()); }\n"
        );
    }
    main = os.path.realpath(main);
    init_py = os.path.realpath(os.path.join(pkg, "__init__.py"));
    sys.path.insert(0, sp);
    try {
        (prog, rendered) = _check(main);
        assert not prog.errors_had , f"the third-party import did not check clean: {rendered}";
        events = prog.analysis.cache_events;
        assert events.get("dep_miss_compile", 0) == 0 , (
            f"a site-packages module was compiled as a dependency target (events: {events})"
        );
        for name in ("__init__.py", "sub.py", "deep.py") {
            leaf = os.path.realpath(os.path.join(pkg, name));
            assert not get_module_cache_path(leaf).exists() , (
                f"{name} got its own cache entry; third-party Python must stay opaque"
            );
        }
        reg = prog.iface_registry();
        compiler = prog._get_compiler();
        assert not reg.eligible(compiler, init_py, _check_opts()) , "a site-packages module must never be served or persisted as an interface target";
        before = dict(reg.prog.analysis.cache_events);
        assert reg.ensure(init_py) is None , "ensure() must not manufacture an entry for third-party Python";
        assert reg.prog.analysis.cache_events.get("dep_miss_compile", 0)
            == before.get("dep_miss_compile", 0) , "ensure() compiled a site-packages module on a miss";
        assert not get_module_cache_path(init_py).exists() , "ensure() wrote a cache entry for third-party Python";
        reg.frame_push(main);
        try {
            reg.note_dep(init_py);
        } finally {
            reg.frame_pop();
        }
        rows = reg.direct_deps.get(main, {});
        assert rows.get(init_py) == compute_stub_module_key(init_py) , f"a third-party Python dependency is fingerprinted by content, like a stub (rows: {rows})";
    } finally {
        if sp in sys.path {
            sys.path.remove(sp);
        }
    }
}
