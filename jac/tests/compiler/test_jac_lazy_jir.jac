"""Tests for scoped lazy .jac JIR (part 5): eligibility, dep-only chunking, cascade."""

import os;
import struct;
import tempfile;
import pytest;
import from jaclang.jac0core.cache_paths {
    is_bootstrap_jac_path,
    is_jac_lazy_eligible,
}
import from jaclang.jac0core.jir { FLAG_CHUNKED, HEADER_FMT, HEADER_SIZE }
import from jaclang.jac0core.jir_passes { JirReader, JirWriter }
import from jaclang.jac0core.program { JacProgram }
import from tests.support { JAC_ROOT, TESTS_DIR }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "fixtures", "jac_lazy_dep", "lib.jac"
     );

def _jir_flags(blob: bytes) -> int {
    (_, _, _, _, _, _, _, _, flags) = struct.unpack(HEADER_FMT, blob[:HEADER_SIZE]);
    return flags;
}

def _env_restore(prev: dict) {
    for (k, v) in prev.items() {
        if v is None {
            os.environ.pop(k, None);
        } else {
            os.environ[k] = v;
        }
    }
}

def _save_env(*keys: str) -> dict {
    out: dict = {};
    for k in keys {
        out[k] = os.environ.get(k);
    }
    return out;
}

test "jac lazy eligibility excludes bootstrap and jaclang self-hosting" {
    jir_jac = os.path.join(JAC_ROOT, "jaclang", "jac0core", "jir.jac");
    unitree = os.path.join(JAC_ROOT, "jaclang", "jac0core", "unitree.jac");
    assert is_bootstrap_jac_path(jir_jac);
    assert not is_jac_lazy_eligible(jir_jac);
    assert not is_jac_lazy_eligible(unitree);
    assert is_jac_lazy_eligible(FIXTURE);
}

test "jaclang-shaped user path stays eligible without jac0core marker" {
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, "jaclang", "compiler", "plugin.jac");
        os.makedirs(os.path.dirname(path), exist_ok=True);
        with open(path, "w", encoding="utf-8") as f {
            f.write("def ping -> int { return 1; }\n");
        }
        assert is_jac_lazy_eligible(path);
    }
}

test "jaclang internal dep cache is not chunked even with JAC_LAZY_JAC" {
    # Self-hosting modules must stay on the full-hydrate path.
    internal = os.path.join(JAC_ROOT, "jaclang", "jac0core", "constant.jac");
    if not os.path.isfile(internal) {
        pytest.skip("constant.jac missing");
    }
    prev = _save_env("JAC_LAZY_JAC", "JAC_LAZY_JIR");
    try {
        os.environ["JAC_LAZY_JAC"] = "1";
        os.environ["JAC_LAZY_JIR"] = "1";
        prog = JacProgram();
        mod = prog.load_dependency_module(internal);
        writer = JirWriter();
        blob = writer.write_module(mod, sections={}, jac_lazy_dep=True);
        assert (_jir_flags(blob) & FLAG_CHUNKED) == 0 , (
            "jaclang internal module must not use chunked .jac layout"
        );
    } finally {
        _env_restore(prev);
    }
}

test "user dep cache chunks under JAC_LAZY_JAC with lazy parity" {
    if not os.path.isfile(FIXTURE) {
        pytest.skip("fixture missing");
    }
    prev = _save_env("JAC_LAZY_JAC", "JAC_LAZY_JIR");
    try {
        os.environ["JAC_LAZY_JAC"] = "1";
        os.environ["JAC_LAZY_JIR"] = "1";
        prog = JacProgram();
        mod = prog.load_dependency_module(FIXTURE);
        writer = JirWriter();
        blob = writer.write_module(mod, sections={}, jac_lazy_dep=True);
        total = len(writer._nodes);
        assert (_jir_flags(blob) & FLAG_CHUNKED) != 0 , (
            "eligible user dep must write chunked layout"
        );

        os.environ["JAC_LAZY_JIR"] = "0";
        full_reader = JirReader(_source_path=FIXTURE);
        full_mod = full_reader.read_module(blob);
        assert full_mod is not None;
        ref_syms = sorted(full_mod.names_in_scope.keys());

        os.environ["JAC_LAZY_JIR"] = "1";
        lazy_reader = JirReader(_source_path=FIXTURE);
        lazy_mod = lazy_reader.read_module(blob);
        assert lazy_mod is not None;
        eager = lazy_reader.hydrated_node_count;
        assert eager < total // 4 , (
            "lazy eager tier should be well under full module ("
            + str(eager)
            + " / "
            + str(total)
            + ")"
        );
        assert sorted(lazy_mod.names_in_scope.keys()) == ref_syms;

        # Touch one class body: hydrates its chunk only.
        target = None;
        for (nm, sym) in full_mod.names_in_scope.items() {
            if type(sym.decl.name_of).__name__ == "Archetype" {
                target = nm;
                break;
            }
        }
        assert target is not None;
        before = lazy_reader.hydrated_node_count;
        lazy_arch = lazy_mod.names_in_scope[target].decl.name_of;
        _ = lazy_arch.names_in_scope.keys();
        assert lazy_reader.hydrated_node_count > before;
        assert lazy_reader.hydrated_node_count < total;
    } finally {
        _env_restore(prev);
    }
}

test "ineligible source path full-hydrates a chunked .jac cache" {
    if not os.path.isfile(FIXTURE) {
        pytest.skip("fixture missing");
    }
    prev = _save_env("JAC_LAZY_JAC", "JAC_LAZY_JIR");
    try {
        os.environ["JAC_LAZY_JAC"] = "1";
        os.environ["JAC_LAZY_JIR"] = "1";
        prog = JacProgram();
        mod = prog.load_dependency_module(FIXTURE);
        writer = JirWriter();
        blob = writer.write_module(mod, sections={}, jac_lazy_dep=True);
        total = len(writer._nodes);
        assert (_jir_flags(blob) & FLAG_CHUNKED) != 0;

        # Same chunked bytes, but reader treats jaclang paths as ineligible.
        internal_path = os.path.join(JAC_ROOT, "jaclang", "jac0core", "constant.jac");
        reader = JirReader(_source_path=internal_path);
        full = reader.read_module(blob);
        assert full is not None;
        assert reader.hydrated_node_count == total , (
            "ineligible path must full-hydrate even when JAC_LAZY_JAC is on"
        );
    } finally {
        _env_restore(prev);
    }
}

test "temp user module outside jaclang is eligible" {
    prev = _save_env("JAC_LAZY_JAC");
    try {
        os.environ["JAC_LAZY_JAC"] = "1";
        with tempfile.TemporaryDirectory() as tmp {
            path = os.path.join(tmp, "sample.jac");
            with open(path, "w", encoding="utf-8") as f {
                f.write(
                    "class Widget {\n"
                        + "    has n: int = 0;\n"
                        + "    can inc -> int { return self.n + 1; }\n"
                        + "}\n"
                );
            }
            assert is_jac_lazy_eligible(path);
            prog = JacProgram();
            mod = prog.load_dependency_module(path);
            blob = JirWriter().write_module(mod, sections={}, jac_lazy_dep=True);
            assert (_jir_flags(blob) & FLAG_CHUNKED) != 0;
        }
    } finally {
        _env_restore(prev);
    }
}

test "chunked stub contextmanager generic apply type-checks cleanly" {
    import os;
    import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
    import from jaclang.jac0core.compile_options { CompileOptions }
    import from jaclang.jac0core.jir { get_module_cache_path }

    fixture = os.path.join(
        JAC_ROOT,
        "tests",
        "compiler",
        "passes",
        "main",
        "fixtures",
        "checker",
        "checker_contextmanager_generic_apply.jac"
    );
    ctxlib = os.path.join(
        JAC_ROOT, "jaclang", "vendor", "typeshed", "stdlib", "contextlib.pyi"
    );
    te_stub = os.path.join(
        JAC_ROOT, "jaclang", "vendor", "typeshed", "stdlib", "typing_extensions.pyi",
    );
    typing_stub = os.path.join(
        JAC_ROOT, "jaclang", "vendor", "typeshed", "stdlib", "typing.pyi"
    );
    if not os.path.isfile(fixture) {
        pytest.skip("fixture missing");
    }
    prev = _save_env("JAC_LAZY_JIR");
    try {
        os.environ["JAC_LAZY_JIR"] = "1";
        for path in (fixture, ctxlib, te_stub, typing_stub) {
            cp = get_module_cache_path(path);
            if cp.exists() {
                cp.unlink();
            }
        }
        program = JacProgram();
        mod = program.compile(
            fixture,
            options=CompileOptions(type_check=False, default_codespace='server')
        );
        TypeCheckPass(ir_in=mod, prog=program);
        assert program.errors_had == [] , (
            "lazy chunked contextlib must not break @contextmanager typing: "
            + str([str(e) for e in program.errors_had])
        );
    } finally {
        _env_restore(prev);
    }
}

test "chunked stub version-guarded datetime.UTC resolves" {
    import os;
    import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
    import from jaclang.jac0core.compile_options { CompileOptions }
    import from jaclang.jac0core.jir { get_module_cache_path }

    fixture = os.path.join(
        JAC_ROOT,
        "tests",
        "compiler",
        "passes",
        "main",
        "fixtures",
        "checker",
        "checker_bug_version_guard_stub_symbol.jac"
    );
    dt_stub = os.path.join(
        JAC_ROOT, "jaclang", "vendor", "typeshed", "stdlib", "datetime.pyi"
    );
    te_stub = os.path.join(
        JAC_ROOT, "jaclang", "vendor", "typeshed", "stdlib", "typing_extensions.pyi",
    );
    typing_stub = os.path.join(
        JAC_ROOT, "jaclang", "vendor", "typeshed", "stdlib", "typing.pyi"
    );
    if not os.path.isfile(fixture) {
        pytest.skip("fixture missing");
    }
    prev = _save_env("JAC_LAZY_JIR");
    try {
        os.environ["JAC_LAZY_JIR"] = "1";
        for path in (fixture, dt_stub) {
            cp = get_module_cache_path(path);
            if cp.exists() {
                cp.unlink();
            }
        }
        program = JacProgram();
        mod = program.compile(
            fixture,
            options=CompileOptions(type_check=False, default_codespace='server')
        );
        TypeCheckPass(ir_in=mod, prog=program);
        unresolved = [
            w
            for w in program.warnings_had
            if "could not be resolved" in str(w)
        ];
        assert unresolved == [] , (
            "lazy chunked datetime stub must resolve version-guarded UTC: "
            + str([str(w) for w in unresolved])
        );
    } finally {
        _env_restore(prev);
    }
}
