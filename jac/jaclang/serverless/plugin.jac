"""jac-serverless bootstrap.

Registers providers that swap graph persistence and identity storage onto a
Postgres-compatible database (e.g. Supabase) whenever a database URL is
configured. Both providers return None when serverless mode is not
configured, so registration is always safe and changes nothing by default.
"""
import logging;
import from jaclang { JacRuntimeInterface as Jac }
import from jaclang.serverless.config { resolve_database_url, serverless_enabled }

glob logger = logging.getLogger(__name__),
     _bootstrapped: list = [];


def _base_path_of(config: (dict | None)) -> (str | None) {
    if isinstance(config, dict) {
        return config.get('base_path') or config.get('target_path');
    }
    return None;
}


def _memory_provider(config: (dict | None)) -> any {
    base_path = _base_path_of(config);
    if not serverless_enabled(base_path) {
        return None;
    }
    url = resolve_database_url(base_path);
    if not url {
        return None;
    }
    import from jaclang.serverless.postgres_memory { PostgresMemory }
    logger.debug("jac-serverless: using Postgres persistence");
    return PostgresMemory(url=url);
}


def _identity_provider(config: (dict | None)) -> any {
    base_path = _base_path_of(config);
    if not serverless_enabled(base_path) {
        return None;
    }
    url = resolve_database_url(base_path);
    if not url {
        return None;
    }
    import from jaclang.serverless.postgres_identity { PostgresIdentityStorage }
    logger.debug("jac-serverless: using Postgres identity storage");
    return PostgresIdentityStorage(db_path='', url=url);
}


def bootstrap_serverless -> None {
    if _bootstrapped {
        return;
    }
    _bootstrapped.append(True);
    Jac.set_persistent_memory_provider(_memory_provider);
    try {
        import from jaclang.scale.identity.identity_storage {
            set_identity_storage_provider
        }
        set_identity_storage_provider(_identity_provider);
    } except ImportError as e {
        logger.debug(f"jac-serverless: identity hook unavailable: {e}");
    }
}
