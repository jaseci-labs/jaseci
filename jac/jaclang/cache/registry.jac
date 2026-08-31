import from jaclang.cache.store { CacheStore, PrunePolicy }


glob _STORES: dict[str, CacheStore] = {};


def register(store: CacheStore) -> CacheStore {
    existing = _STORES.get(store.name);
    if existing is not None {
        return existing;
    }
    _STORES[store.name] = store;
    return store;
}


def get_store(name: str) -> CacheStore {
    ensure_default_stores();
    store = _STORES.get(name);
    if store is None {
        raise KeyError(f"unknown cache store: {name}");
    }
    return store;
}


def all_stores -> list[CacheStore] {
    ensure_default_stores();
    return [_STORES[name] for name in sorted(_STORES.keys())];
}


def prune_all(force: bool = False) {
    for store in all_stores() {
        if force {
            store.prune();
        } else {
            store.maybe_prune();
        }
    }
}


def purge_all(include_exempt: bool = False) {
    for store in all_stores() {
        if store.prune_exempt and not include_exempt {
            continue;
        }
        store.purge();
    }
}


def ensure_default_stores {
    if _STORES {
        return;
    }
    day = 86400.0;
    register(CacheStore(
        name="modules",
        schema_version="jir-24",
        dir_entries=True,
        policy=PrunePolicy(ttl_seconds=14 * day)
    ));
    register(CacheStore(
        name="bootstrap",
        schema_version="jbc-1",
        policy=PrunePolicy(ttl_seconds=30 * day, max_entries=512)
    ));
    register(CacheStore(
        name="kernels",
        schema_version="v1",
        policy=PrunePolicy(ttl_seconds=14 * day)
    ));
    register(CacheStore(
        name="stubs",
        schema_version="stubcat-3",
        policy=PrunePolicy(ttl_seconds=60 * day, max_entries=32)
    ));
    register(CacheStore(
        name="runtimes",
        schema_version="jacbin-1",
        dir_entries=True,
        policy=PrunePolicy(ttl_seconds=60 * day)
    ));
    register(CacheStore(
        name="apps",
        schema_version="jab-8",
        dir_entries=True,
        policy=PrunePolicy(ttl_seconds=60 * day)
    ));
    register(CacheStore(
        name="bin",
        schema_version="v1",
        policy=PrunePolicy(ttl_seconds=60 * day)
    ));
    register(CacheStore(name="models", schema_version="v1", prune_exempt=True));
    register(CacheStore(
        name="browser",
        schema_version="v1",
        policy=PrunePolicy(ttl_seconds=30 * day)
    ));
    register(CacheStore(name="pg", schema_version="v1", dir_entries=True));
}


def project_modules_store(cache_dir: str) -> CacheStore {
    return CacheStore(
        name="modules",
        schema_version="jir-24",
        dir_entries=True,
        policy=PrunePolicy(ttl_seconds=14 * 86400.0),
        root_override=cache_dir
    );
}
