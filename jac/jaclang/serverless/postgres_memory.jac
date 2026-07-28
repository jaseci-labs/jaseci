import logging;
import threading;
import from uuid { UUID }
import from jaclang.jac0core.archetype { Anchor }
import from jaclang.runtimelib.storage.sqlalchemy_memory { SqlAlchemyMemory }

glob logger = logging.getLogger(__name__),
     _engine_cache: dict[str, any] = {},
     _engine_lock = threading.Lock();


def shared_postgres_engine(url: str) -> any {
    import from sqlalchemy { create_engine }
    with _engine_lock {
        engine = _engine_cache.get(url);
        if engine is None {
            engine = create_engine(
                url, future=True, pool_pre_ping=True, pool_recycle=300
            );
            _engine_cache[url] = engine;
        }
        return engine;
    }
}


def dispose_shared_engines {
    with _engine_lock {
        for engine in _engine_cache.values() {
            try {
                engine.dispose();
            } except Exception { }
        }
        _engine_cache.clear();
    }
}


obj PostgresMemory(SqlAlchemyMemory) {
    def postinit -> None;
    def is_available -> bool;
    def close -> None;
    def batch_get(ids: list[UUID]) -> dict[UUID, Anchor];
}
