"""Process-shared Postgres access for scale side services.

Request Sessions each own a transactional PgStore connection; side services
(state KV, websocket backplane, event streams, schedulers) share ONE
autocommit PgStore per process, resolved here. URL resolution order:
JAC_DB_URL env, then [plugins.scale.database] url from config, then the
project's embedded server.
"""

import logging;
import os;
import threading;
import from typing { Any }

glob logger = logging.getLogger(__name__),
     _lock = threading.Lock(),
     _holder: dict[str, Any] = {},
     __all__ = ['scale_db_url', 'shared_store'];


def scale_db_url -> (str | None) {
    url = os.environ.get('JAC_DB_URL', '');
    if url {
        return url;
    }
    try {
        import from jaclang.scale.config.plugin_config { get_scale_config }
        cfg = get_scale_config().get_database_config();
        got = cfg.get('url') or cfg.get('postgres_url');
        return str(got) if got else None;
    } except Exception {
        return None;
    }
}


def shared_store -> (Any | None) {
    """One autocommit PgStore per process, or None when no db is reachable."""
    with _lock {
        if 'store' in _holder {
            return _holder['store'];
        }
        store: Any = None;
        try {
            import from jaclang.runtimelib.session { conninfo_from_url }
            import from jaclang.runtimelib.store { PgStore }
            url = scale_db_url();
            if url {
                store = PgStore(conninfo=conninfo_from_url(url));
            } else {
                import from jaclang.jac0core.runtime { JacRuntime }
                import from jaclang.runtimelib.pgembed { PgRuntime }
                base = JacRuntime.get_base_path_dir();
                if base {
                    import from jaclang.runtimelib.utils { get_name }
                    name = get_name(
                        target_path=JacRuntime.get_full_target_path()
                    ) or 'main';
                    rt = PgRuntime(
                        data_dir=os.path.join(
                            os.environ.get('JAC_DATA_PATH') or base,
                            '.jac', 'data', f"{name}-pg"
                        )
                    );
                    store = PgStore(conninfo=rt.ensure());
                }
            }
            if store is not None {
                store.ensure_schema({});
            }
        } except Exception as e {
            logger.warning(f"scale shared store unavailable: {e}");
            store = None;
        }
        _holder['store'] = store;
        return store;
    }
}
