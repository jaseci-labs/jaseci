obj NativeScopeEntry {
    has module: str,
        strict: bool = False;
}

glob NATIVE_SCOPE: tuple[NativeScopeEntry, ...] = (
    NativeScopeEntry(module="jaclang.compiler.store.pyapi", strict=True),
    NativeScopeEntry(module="jaclang.compiler.store.unitree_store", strict=True),
);
