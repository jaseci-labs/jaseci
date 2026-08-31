import os;

obj NativeScopeEntry {
    has module: str,
        strict: bool = False;
}

glob NATIVE_SCOPE: tuple[NativeScopeEntry, ...] = (
    NativeScopeEntry(module="jaclang.compiler.store.pyapi", strict=True),
    NativeScopeEntry(module="jaclang.compiler.store.unitree_store", strict=True),
    NativeScopeEntry(module="jaclang.compiler.frontend.constant", strict=True),
    NativeScopeEntry(module="jaclang.compiler.frontend.srcloc", strict=True),
    NativeScopeEntry(module="jaclang.compiler.frontend.roles", strict=True),
    NativeScopeEntry(module="jaclang.compiler.frontend.relations", strict=True),
    NativeScopeEntry(module="jaclang.compiler.frontend.unitree", strict=True),
    NativeScopeEntry(module="jaclang.compiler.frontend.parser.tokens", strict=True),
    NativeScopeEntry(module="jaclang.compiler.frontend.parser.lexer", strict=True),
    NativeScopeEntry(module="jaclang.compiler.frontend.parser.parser", strict=True),
    NativeScopeEntry(
        module="jaclang.compiler.frontend.parser.native_queries", strict=True
    ),
    NativeScopeEntry(
        module="jaclang.compiler.frontend.parser.native_fields", strict=True
    ),
    NativeScopeEntry(
        module="jaclang.compiler.frontend.parser.native_entry", strict=True
    ),
);

glob _SCOPE_SUFFIX_CACHE: list = [],
     _SCOPE_ACTIVE: list = [];

def activate_scope_lowering -> None {
    if _SCOPE_ACTIVE {
        return;
    }
    _SCOPE_ACTIVE.append(1);
    try {
        import from jaclang.runtime.runtime { JacRuntime }
        sh = JacRuntime.get_selfhost();
        prog = sh.peek_program();
        if prog is not None {
            hub = prog.mod.hub;
            for k in list(hub.keys()) {
                if in_native_scope_path(k) {
                    del hub[k] ;
                }
            }
        }
    } except Exception {
        ;
    }
}

def scope_lowering_active -> bool {
    return len(_SCOPE_ACTIVE) > 0;
}

def native_scope_path_suffixes -> list[str] {
    if not _SCOPE_SUFFIX_CACHE {
        for e in NATIVE_SCOPE {
            rel = e.module.replace("jaclang.", "", 1).replace(".", "/") + ".jac";
            _SCOPE_SUFFIX_CACHE.append("jaclang/" + rel);
        }
    }
    return _SCOPE_SUFFIX_CACHE;
}

def in_native_scope_path(mod_path: str) -> bool {
    if not mod_path {
        return False;
    }
    p = mod_path.replace(os.sep, "/");
    for suf in native_scope_path_suffixes() {
        if p.endswith(suf) {
            return True;
        }
    }
    return False;
}
