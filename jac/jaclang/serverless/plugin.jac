"""jac-serverless bootstrap.

Self-contained activation for the serverless platform. When a Postgres
compatible database URL (e.g. Supabase) is configured, graph persistence and
identity storage move onto that database so the app itself is stateless.
Nothing outside this package is modified: graph persistence uses the core
set_persistent_memory_provider hook, and identity storage is swapped by
wrapping the scale user manager's postinit from here at load time. With no
serverless configuration every hook is a no-op.
"""
import logging;
import from jaclang { JacRuntimeInterface as Jac }
import from jaclang.serverless.config { resolve_database_url, serverless_enabled }

glob logger = logging.getLogger(__name__),
     _bootstrapped: list = [],
     _orig_um_postinit: list = [];


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


def _patched_um_postinit(self: any) -> None {
    _orig_um_postinit[0](self);
    base_path = getattr(self, 'base_path', None);
    if not serverless_enabled(base_path) {
        return;
    }
    url = resolve_database_url(base_path);
    if not url {
        return;
    }
    import from jaclang.serverless.postgres_identity { PostgresIdentityStorage }
    self._identity_storage = PostgresIdentityStorage(db_path='', url=url);
    logger.debug("jac-serverless: using Postgres identity storage");
}


def _install_identity_swap -> None {
    try {
        import from jaclang.scale.identity.user_manager { JacScaleUserManager }
    } except ImportError as e {
        logger.debug(f"jac-serverless: identity swap unavailable: {e}");
        return;
    }
    if getattr(JacScaleUserManager, '_jac_serverless_swapped', False) {
        return;
    }
    _orig_um_postinit.append(JacScaleUserManager.postinit);
    JacScaleUserManager.postinit = _patched_um_postinit;
    JacScaleUserManager._jac_serverless_swapped = True;
}


def bootstrap_serverless -> None {
    if _bootstrapped {
        return;
    }
    _bootstrapped.append(True);
    Jac.set_persistent_memory_provider(_memory_provider);
    if serverless_enabled(None) {
        try {
            _install_identity_swap();
        } except Exception as e {
            logger.debug(f"jac-serverless: identity swap failed: {e}");
        }
    }
}
