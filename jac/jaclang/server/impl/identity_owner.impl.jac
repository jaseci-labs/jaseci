import logging;
import from pathlib { Path }

glob _logger = logging.getLogger(__name__),
     _warned_settings: set[str] = set();

impl scale_stack_installed -> bool {
    import importlib.util;
    try {
        return importlib.util.find_spec('jaclang.scale') is not None;
    } except Exception {
        return False;
    }
}

def _configured_owner(project_dir: (str | None)) -> str {
    try {
        import from jaclang.project.config { JacConfig }
        config = JacConfig.discover(Path(project_dir) if project_dir else None);
    } except Exception as e {
        _logger.debug(f"[serve] identity unreadable, resolving automatically: {e}");
        return '';
    }
    if config is None {
        return '';
    }
    return str(config.serve.identity or '').strip().lower();
}

impl identity_owner(project_dir: (str | None) = None) -> str {
    setting = os.environ.get(IDENTITY_BACKEND_ENV, '').strip().lower();
    source = IDENTITY_BACKEND_ENV;
    if not setting {
        setting = _configured_owner(project_dir);
        source = 'jac.toml [serve] identity';
    }
    if setting in KNOWN_IDENTITY_OWNERS {
        return setting;
    }
    if setting and setting != AUTO_IDENTITY and setting not in _warned_settings {
        _warned_settings.add(setting);
        _logger.warning(
            f"{source} = {setting!r} is not one of 'auto', "
            f"'{CORE_IDENTITY}', '{SCALE_IDENTITY}'; resolving automatically."
        );
    }
    return SCALE_IDENTITY if scale_stack_installed() else CORE_IDENTITY;
}

impl scale_stack_unavailable(module_name: str, error: any = None) -> RuntimeError {
    detail = f" ({type(error).__name__}: {error})" if error is not None else '';
    return RuntimeError(
        'the scale identity owns /user/* for this project, but '
        f"'{module_name}' could not be imported{detail}. Refusing to serve the "
        'identity endpoints from the core store instead: the two stacks keep '
        'credentials in different databases, so falling back would strand '
        'every account that already exists. Fix the import, or choose the core '
        "identity on purpose with [serve] identity = 'core' in jac.toml (or "
        f"{IDENTITY_BACKEND_ENV}={CORE_IDENTITY})."
    );
}
