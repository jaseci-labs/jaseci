impl scale_stack_installed -> bool {
    import importlib.util;
    try {
        return importlib.util.find_spec('jaclang.scale') is not None;
    } except Exception {
        return False;
    }
}

impl scale_stack_configured -> bool {
    if not scale_stack_installed() {
        return False;
    }
    try {
        import from jaclang.scale.plugin { scale_runtime_configured }
    } except ImportError as e {
        raise scale_stack_unavailable('jaclang.scale.plugin', e);
    }
    return scale_runtime_configured();
}

def _configured_owner(project_dir: (str | None)) -> str {
    import from jaclang.project.config { get_config, get_config_for_dir }
    config = get_config_for_dir(project_dir) if project_dir else get_config();
    if config is None {
        return '';
    }
    return str(config.serve.identity or '').strip().lower();
}

impl identity_setting(project_dir: (str | None) = None) -> str {
    setting = os.environ.get(IDENTITY_BACKEND_ENV, '').strip().lower();
    source = IDENTITY_BACKEND_ENV;
    if not setting {
        setting = _configured_owner(project_dir);
        source = 'jac.toml [serve] identity';
    }
    if setting in KNOWN_IDENTITY_OWNERS or setting in ('', AUTO_IDENTITY) {
        return setting;
    }
    accepted = ', '.join(repr(name) for name in IDENTITY_SETTINGS);
    raise ValueError(
        f"{source} = {setting!r} does not name an identity owner. Accepted "
        f"values are {accepted}. Which stack owns /user/* decides which "
        'database the credentials live in, so there is no safe value to guess '
        'here.'
    );
}

impl identity_owner(project_dir: (str | None) = None) -> str {
    setting = identity_setting(project_dir);
    if setting in KNOWN_IDENTITY_OWNERS {
        return setting;
    }
    return SCALE_IDENTITY if scale_stack_configured() else CORE_IDENTITY;
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
