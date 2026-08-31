import os;
import from jaclang.compiler.driver.jir {
    HEADER_SIZE,
    SEC_BYTECODE,
    SEC_INTEROP,
    SEC_LLVM_IR,
    SEC_MTIR,
    SEC_NATIVE_OBJ,
    SEC_PLACEMENT,
    SECTIONS_MAGIC,
    get_module_cache_path,
    is_module_cache_valid,
    read_bytecode_only,
    read_sections
}

impl ArtifactStore.load(full_target: str, program: JacProgram) -> (bytes | None) {
    cache_path = get_module_cache_path(full_target);
    if not is_module_cache_valid(full_target, cache_path) {
        return None;
    }
    try {
        jir_data = cache_path.read_bytes();
        bc = read_bytecode_only(jir_data);
        if bc is None {
            cache_path.unlink(missing_ok=True);
            program.invalidate_module(full_target);
            return None;
        }
        magic_bytes: any = SECTIONS_MAGIC;
        sec_pos = jir_data.find(magic_bytes, HEADER_SIZE);
        _had_native_secs = False;
        if sec_pos >= 0 {
            secs = read_sections(jir_data, sec_pos + len(magic_bytes));
            self.compiler._restore_sections(full_target, program, secs);
            _had_native_secs = SEC_NATIVE_OBJ in secs or SEC_LLVM_IR in secs;
        }
        if (
            _had_native_secs
            and full_target not in program.hub.artifacts
            and not self.compiler.selfhost.is_selfhost(program)
        ) {
            import logging;
            logging.getLogger(__name__).warning(
                f"Cached native sections for {full_target} could "
                f"not be restored; recompiling."
            );
            cache_path.unlink(missing_ok=True);
            return None;
        }
        return bc;
    } except Exception {
        return None;
    }
}

impl ArtifactStore.persist(
    full_target: str, mod: uni.Module, program: JacProgram
) -> None {
    try {
        if is_module_cache_valid(full_target, get_module_cache_path(full_target)) {
            return;
        }
    } except Exception {
        return;
    }
    cache_bc = mod.gen.py_bytecode;
    if cache_bc is None or mod.parse_failed {
        return;
    }
    try {
        import pickle;
        import json;
        import zlib;
        sections: dict[int, bytes] = {};
        sections[SEC_BYTECODE] = cache_bc;
        if program.mtir_map {
            sections[SEC_MTIR] = pickle.dumps(
                program.mtir_map, int(pickle.HIGHEST_PROTOCOL)
            );
        }

        native_bc = mod.gen.native_bitcode;
        if native_bc is not None {
            import struct as _struct;
            import jaclang.compiler.backends.native.llvm.binding as _llvm;
            triple_text = _llvm.get_default_triple();
            assert isinstance(triple_text, str);
            triple = triple_text.encode('utf-8');
            hdr = _struct.pack('<H', len(triple)) + triple;
            sections[SEC_NATIVE_OBJ] = hdr + native_bc;
        } else {
            llvm_ir = mod.gen.llvm_ir;
            if llvm_ir is not None {
                sections[SEC_LLVM_IR] = zlib.compress(str(llvm_ir).encode('utf-8'), 6);
            }
        }
        interop_dict = self.compiler._build_interop_dict(mod);
        if interop_dict {
            sections[SEC_INTEROP] = json.dumps(interop_dict).encode('utf-8');
        }
        try {
            import from jaclang.compiler.placement.placement {
                get_module_summary,
                summary_to_bytes
            }
            sections[SEC_PLACEMENT] = summary_to_bytes(
                get_module_summary(mod, program)
            );
        } except Exception {
            ;
        }
        import from jaclang.compiler.driver.jir {
            SEC_CTDEPS,
            ct_deps_section,
            write_module_cache
        }
        if mod.ct_file_deps {
            sections[SEC_CTDEPS] = ct_deps_section(mod.ct_file_deps);
        }
        write_module_cache(full_target, cache_bc, extra_sections=sections);
    } except Exception {
        ;
    }
}

impl ArtifactStore.evict_slim(
    full_target: str, result: (uni.Module | None), collect: bool = True
) -> None {
    if os.environ.get("JAC_NO_UNIT_EVICT") {
        return;
    }
    internal = self.compiler.selfhost.program;
    if result is not None and result.gen.native_engine is not None {
        import from jaclang.compiler.frontend.codeinfo { CodeGenTarget }
        slim = CodeGenTarget();
        slim.native_engine = result.gen.native_engine;
        slim.native_layout = result.gen.native_layout;
        slim.interop_py_funcs = result.gen.interop_py_funcs;
        slim._interop_callbacks = result.gen._interop_callbacks;
        slim.interop_manifest = result.gen.interop_manifest;
        internal.hub.artifacts[full_target] = slim;
    }
    internal.release_compile_closure(collect=collect);
}
