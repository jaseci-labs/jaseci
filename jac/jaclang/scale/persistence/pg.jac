import logging;
import os;
import threading;
glob logger = logging.getLogger(__name__),
     _lock = threading.Lock(),
     _holder: dict[str, any] = {},
     NO_DATABASE_RESOLVED = (
         'no [scale.database] url / JAC_DB_URL resolved and the embedded '
         'server could not be provisioned'
     ),
     _DOCS_DDL = (
         'CREATE TABLE IF NOT EXISTS jac_docs ('
         'collection text NOT NULL, '
         'id text NOT NULL, '
         'doc jsonb NOT NULL, '
         'PRIMARY KEY (collection, id))'
     ),
     __all__ = [
         'scale_db_url',
         'shared_store',
         'shared_store_failure',
         'open_docs_store',
         'NO_DATABASE_RESOLVED'
     ];


def open_docs_store -> (any | None) {
    store = shared_store();
    if store is None {
        return None;
    }
    store.rows(_DOCS_DDL, {});
    return store;
}


def scale_db_url -> (str | None) {
    url = os.environ.get('JAC_DB_URL', '');
    if url {
        return url;
    }
    try {
        import from jaclang.scale.config.config_loader { get_scale_config }
        cfg = get_scale_config().get_database_config();
        got = cfg.get('url') or cfg.get('postgres_url');
        return str(got) if got else None;
    } except Exception as e {
        logger.debug(f"[scale.database] url unreadable: {e}");
        return None;
    }
}


"""Where the resolved url came from, for a message an operator can act on."""
def _url_source -> str {
    return ('JAC_DB_URL' if os.environ.get('JAC_DB_URL') else '[scale.database] url');
}


"""Name a store's database without leaking the password from its url."""
def _store_target(store: any) -> str {
    try {
        info = store.conninfo;
        where = info.unix_socket_dir or info.host or '?';
        return f"{where}:{info.port}/{info.database}";
    } except Exception {
        return 'the resolved database';
    }
}


"""Record why the shared store is unavailable, and keep it retryable.

The reason is what every caller renders, so it has to name the stage that
failed rather than collapse to "no database". Nothing is committed under
the holder key: a store that failed once must be attempted again, or a
single bad moment at boot outlives the outage that caused it.
"""
def _fail(reason: str) {
    if _holder.get('failure') == reason {
        # Retryable means re-attempted, which means re-reported; say the same
        # thing twice at warning and a polled health probe becomes the log.
        logger.debug(f"scale shared store still unavailable: {reason}");
    } else {
        logger.warning(f"scale shared store unavailable: {reason}");
    }
    _holder.pop('key', None);
    _holder.pop('store', None);
    _holder['failure'] = reason;
}


"""Why the last shared_store() attempt failed, or None if it did not."""
def shared_store_failure -> (str | None) {
    got = _holder.get('failure');
    return str(got) if got else None;
}


def shared_store -> (any | None) {
    with _lock {
        import from jaclang.jac0core.runtime { JacRuntime }
        url = scale_db_url();
        key = url
            or (
                f"{JacRuntime.get_base_path_dir() or ''}"
                f"::{JacRuntime.get_full_target_path() or ''}"
            );
        if _holder.get('key') == key and 'store' in _holder {
            return _holder['store'];
        }
        old_store: any = _holder.pop('store', None);
        if old_store is not None {
            try {
                old_store.close();
            } except Exception { }
        }
        store: (any | None) = None;
        reset = False;
        stage = 'resolve';
        source = _url_source() if url else 'the embedded server';
        try {
            import from jaclang.runtimelib.session { conninfo_from_url, promotions_for }
            import from jaclang.runtimelib.store { PgStore }
            promotions = promotions_for(JacRuntime.get_base_path_dir());
            if url {
                store = PgStore(conninfo=conninfo_from_url(url), promotions=promotions);
            } else {
                import from jaclang.runtimelib.session { runtime_for_base }
                base = JacRuntime.get_base_path_dir();
                if base {
                    stage = 'provision';
                    lease = runtime_for_base(base, JacRuntime.get_full_target_path());
                    rt = lease.runtime;
                    store = PgStore(
                        conninfo=rt.ensure(), ensure_cb=rt.ensure, promotions=promotions
                    );
                    reset = lease.reset;
                }
            }
            if store is None {
                _fail(NO_DATABASE_RESOLVED);
                return None;
            }
            # Connect before touching the schema, so a server that is not
            # there is never reported as a schema problem and vice versa.
            stage = 'connect';
            store.rows('SELECT 1', {});
            stage = 'schema';
            store.ensure_schema_once(promotions);
            if reset {
                store.reset_data();
            }
        } except Exception as e {
            if store is not None {
                try {
                    store.close();
                } except Exception { }
            }
            _fail(_failure_reason(stage, source, store, e));
            return None;
        }
        _holder['key'] = key;
        _holder['store'] = store;
        _holder.pop('failure', None);
        return store;
    }
}


"""Turn the stage that failed into a sentence that points at the fix."""
def _failure_reason(stage: str, source: str, store: any, e: Exception) -> str {
    cause = f"{type(e).__name__}: {e}";
    if stage == 'provision' {
        return f"the embedded Postgres server could not be provisioned ({cause})";
    }
    if stage == 'resolve' {
        return f"the store named by {source} could not be built ({cause})";
    }
    where = _store_target(store);
    if stage == 'schema' {
        return (
            f"connected to {where} but the shared schema could not be set up"
            f" ({cause})"
        );
    }
    return f"cannot reach {where}, resolved from {source} ({cause})";
}
