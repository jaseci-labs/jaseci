import os;
import from .client_kind_paths { mobui_enforced_in }

def _config_for(mod_path: str) -> any {
    try {
        import from jaclang.project.config { get_config_for_dir }
        return get_config_for_dir(os.path.dirname(os.path.abspath(mod_path)));
    } except ImportError {
        return None;
    }
}

def _app_context(mod_path: str) -> tuple[str, (str | None)] {
    cfg = _config_for(mod_path);
    if not cfg or cfg.project_root is None {
        return ("web", None);
    }
    root = str(cfg.project_root);
    app = cfg.app_for_path(os.path.abspath(mod_path));
    if app is None {
        return ("web", root);
    }
    return (app.client_kind or "web", app.root_dir(root) or root);
}

def resolve_client_kind(mod_path: str) -> str {
    return _app_context(mod_path)[0];
}

def resolve_client_kind_context(
    mod_path: str, explicit_kind: str = "web", explicit_root: (str | None) = None
) -> tuple[str, (str | None)] {
    if explicit_kind != "web" {
        root = explicit_root;
        if root is None {
            (_, root) = _app_context(mod_path);
        }
        return (explicit_kind, root);
    }
    return _app_context(mod_path);
}

def mobui_enforced_for(
    mod_path: str, explicit_kind: str = "web", explicit_root: (str | None) = None
) -> bool {
    (kind, root) = resolve_client_kind_context(
        mod_path, explicit_kind, explicit_root
    );
    return mobui_enforced_in(mod_path, kind, root);
}
