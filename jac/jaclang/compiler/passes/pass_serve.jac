import from jaclang.compiler.passes.pass_rim { _NATIVE_SERVED_PASSES }

glob _PASS_ARTIFACT_PREFIXES: tuple[str, str] = (
         "jaclang.compiler.passes.",
         "jaclang.compiler.backends."
     ),
     _BIND_KEEP: list[object] = [];

def _serve_error(fullname: str, reason: str) -> RuntimeError {
    return RuntimeError(
        f"sealed pass artifact for {fullname} could not be bound: {reason}. "
        "The image claims this pass module natively and refuses the "
        "bytecode tier; reinstall or rebuild the payload."
    );
}

def _bind_one(fullname: str) {
    import from jaclang.jac0core.sealed { native_artifact_for }
    found = native_artifact_for(fullname);
    if found is None {
        raise _serve_error(fullname, "the manifest names it but no image resolves it");
    }
    (lib_path, layout_dict) = found;
    import from jaclang.runtime.native_dylib { DylibEngine }
    try {
        eng = DylibEngine(lib_path);
        eng.initialize();
    } except Exception as open_exc {
        raise _serve_error(
            fullname, f"dlopen/init failed ({type(open_exc).__name__}: {open_exc})"
        );
    }
    advertised: set[str] = set((layout_dict.get("functions") or {}).keys());
    structs: dict[str, dict] = layout_dict.get("structs") or {};
    for sd in structs.values() {
        accessors: dict[str, dict[str, str]] = sd.get("accessors") or {};
        for kinds in accessors.values() {
            advertised.update(kinds.values());
        }
    }
    missing = sorted(
        m
        for m in advertised
        if eng.get_function_address(m) == 0
    );
    if missing {
        shown = ", ".join(missing[:6]);
        raise _serve_error(
            fullname,
            f"{len(missing)} advertised export(s) are not in the linked "
            f"artifact (first: {shown})"
        );
    }
    import ctypes;
    probe = eng.get_function_address("jac_str_new");
    if not probe {
        raise _serve_error(fullname, "jac_str_new is not exported");
    }
    made = ctypes.CFUNCTYPE(ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int64)(probe)(
        b"jac", 3
    );
    if not made {
        raise _serve_error(
            fullname, "jac_str_new returned NULL; the runtime is not live"
        );
    }
    _BIND_KEEP.append(eng);
    _NATIVE_SERVED_PASSES.add(fullname);
}

def bind_sealed_pass_artifacts {
    import from jaclang.jac0core.sealed { native_artifact_names }
    for fullname in sorted(native_artifact_names()) {
        if fullname in _NATIVE_SERVED_PASSES {
            continue;
        }
        if not any(fullname.startswith(p) for p in _PASS_ARTIFACT_PREFIXES) {
            continue;
        }
        _bind_one(fullname);
    }
}
