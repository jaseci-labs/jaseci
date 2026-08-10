"""Benchmark stub lazy-JIR after stub_only chunking restore."""

import os;
import struct;
import time;
import from jaclang.compiler.type_system.type_evaluator { _stub_module_memo }
import from jaclang.jac0core.jir {
    FLAG_CHUNKED,
    FORMAT_VERSION,
    HEADER_FMT,
    HEADER_SIZE,
    get_module_cache_path,
}
import from jaclang.jac0core.jir_passes { JirReader, JirWriter }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.langserve.engine { JacLangServer }
import from jaclang.lsp { uris }
import from jaclang.lsp.server { Workspace }
import from tests.support { JAC_ROOT }

glob BUILTINS = os.path.join(
         JAC_ROOT, "jaclang", "vendor", "typeshed", "stdlib", "builtins.pyi"
     ),
     TYPING = os.path.join(
         JAC_ROOT, "jaclang", "vendor", "typeshed", "stdlib", "typing.pyi"
     ),
     CLIENT = os.path.join(
         JAC_ROOT, "tests", "langserve", "fixtures", "any_goto_def_tests.jac"
     ),
     FIXTURE_DIR = os.path.join(JAC_ROOT, "tests", "langserve", "fixtures");

def _jir_flags(blob: bytes) -> int {
    (_, _, _, _, _, _, _, _, flags) = struct.unpack(HEADER_FMT, blob[:HEADER_SIZE]);
    return flags;
}

def _unlink(path: str) {
    cp = get_module_cache_path(path);
    if cp.exists() {
        cp.unlink();
    }
}

def _warm_chunked_cache(stub: str) {
    past = time.time() - 2;
    os.utime(stub, (past, past));
    _unlink(stub);
    JacProgram().load_dependency_module(stub);
}

def _read_cache_bytes(path: str) -> bytes {
    cp = get_module_cache_path(path);
    with open(str(cp), "rb") as f {
        return f.read();
    }
}

def _bench_stub_read(stub: str, label: str) -> dict {
    _warm_chunked_cache(stub);
    blob = _read_cache_bytes(stub);
    flags = _jir_flags(blob);
    writer = JirWriter();
    writer.write_module(JacProgram().load_dependency_module(stub), sections={});
    total = len(writer._nodes);

    # Full hydrate (main-style: materialize entire tree)
    os.environ["JAC_LAZY_JIR"] = "0";
    t0 = time.perf_counter();
    full_reader = JirReader(_source_path=stub);
    full_reader.read_module(blob);
    full_ms = (time.perf_counter() - t0) * 1000.0;
    full_nodes = full_reader.hydrated_node_count;

    # Lazy eager tier only
    os.environ["JAC_LAZY_JIR"] = "1";
    t0 = time.perf_counter();
    lazy_reader = JirReader(_source_path=stub);
    lazy_reader.read_module(blob);
    lazy_ms = (time.perf_counter() - t0) * 1000.0;
    eager_nodes = lazy_reader.hydrated_node_count;

    return {
        "label": label,
        "chunked": bool(flags & FLAG_CHUNKED),
        "total_nodes": total,
        "full_nodes": full_nodes,
        "eager_nodes": eager_nodes,
        "node_reduction_pct": round(
            100.0 * (1.0 - eager_nodes / full_nodes), 2
        ) if full_nodes else 0.0,
        "full_read_ms": round(full_ms, 2),
        "lazy_read_ms": round(lazy_ms, 2),
        "read_speedup_x": round(full_ms / lazy_ms, 2) if lazy_ms > 0 else None,
    };
}

obj LspCounters {
    has compile_calls: int = 0,
        jir_reads: int = 0,
        jir_nodes: int = 0;
}

def _bench_lsp() -> dict {
    for stub in (BUILTINS, TYPING) {
        _unlink(stub);
    }
    _stub_module_memo.clear();

    counters = LspCounters();
    orig_compile = JacProgram.compile;
    orig_load = JacProgram.load_dependency_module;
    orig_read = JirReader.read_module;

    def counting_compile(
        self: JacProgram,
        file_path: str,
        use_str: (str | None) = None,
        no_cgen: bool = False,
        type_check: bool = False,
        symtab_ir_only: bool = False,
        cancel_token: object = None,
        options: object = None
    ) -> object {
        counters.compile_calls += 1 if file_path.endswith(".pyi") else 0;
        return orig_compile(
            self,
            file_path,
            use_str=use_str,
            no_cgen=no_cgen,
            type_check=type_check,
            symtab_ir_only=symtab_ir_only,
            cancel_token=cancel_token,
            options=options
        );
    }

    def counting_load(
        self: JacProgram,
        source_path: str,
        importer_path: (str | None) = None,
        use_str: (str | None) = None
    ) -> object {
        return orig_load(
            self, source_path, importer_path=importer_path, use_str=use_str
        );
    }

    def counting_read(self: JirReader, data: bytes) -> object {
        mod = orig_read(self, data);
        if mod is not None {
            counters.jir_reads += 1;
            counters.jir_nodes += self.hydrated_node_count;
        }
        return mod;
    }

    def run_once(counters: LspCounters) -> tuple[float, int, int, int] {
        counters.compile_calls = 0;
        counters.jir_reads = 0;
        counters.jir_nodes = 0;
        t0 = time.perf_counter();
        lsp = JacLangServer();
        lsp.lsp._workspace = Workspace(root_uri=uris.from_fs_path(FIXTURE_DIR));
        lsp.type_check_file(uris.from_fs_path(CLIENT));
        ms = (time.perf_counter() - t0) * 1000.0;
        return (
            ms,
            counters.compile_calls,
            counters.jir_reads,
            counters.jir_nodes
        );
    }

    cold_counters = counters;
    JacProgram.compile = counting_compile;
    JacProgram.load_dependency_module = counting_load;
    JirReader.read_module = counting_read;

    (cold_ms, cold_comp, _, _) = run_once(cold_counters);
    _stub_module_memo.clear();
    (warm_ms, warm_comp, warm_reads, warm_nodes) = run_once(cold_counters);

    JacProgram.compile = orig_compile;
    JacProgram.load_dependency_module = orig_load;
    JirReader.read_module = orig_read;

    return {
        "cold_ms": round(cold_ms, 1),
        "warm_ms": round(warm_ms, 1),
        "cold_pyi_compiles": cold_comp,
        "warm_pyi_compiles": warm_comp,
        "warm_jir_reads": warm_reads,
        "warm_jir_hydrated_nodes": warm_nodes,
        "warm_speedup_x": round(cold_ms / warm_ms, 2) if warm_ms else None,
    };
}

with entry {
    if not os.path.isfile(BUILTINS) {
        print("typeshed missing");
    } else {
        print("FORMAT_VERSION=" + str(FORMAT_VERSION));
        print("builtins=" + str(_bench_stub_read(BUILTINS, "builtins")));
        print("typing=" + str(_bench_stub_read(TYPING, "typing")));
        # LSP bench omitted — run via perf gate test separately
    }
}
