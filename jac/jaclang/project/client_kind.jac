import os;

def _config_for(mod_path: str) -> any {
    try {
        import from pathlib { Path }
        import from jaclang.project.config { get_config_for_path }
        return get_config_for_path(Path(os.path.dirname(os.path.abspath(mod_path))));
    } except ImportError {
        return None;
    }
}

def resolve_client_kind_context(
    mod_path: str, explicit_kind: str = "web", explicit_root: (str | None) = None
) -> tuple[str, (str | None)] {
    if explicit_kind != "web" {
        proj_root = explicit_root;
        if proj_root is None {
            cfg = _config_for(mod_path);
            if cfg and cfg.project_root {
                proj_root = str(cfg.project_root);
            }
        }
        return (explicit_kind, proj_root);
    }
    cfg = _config_for(mod_path);
    if not cfg or cfg.project_root is None {
        return ("web", None);
    }
    return (cfg.project.client_kind or "web", str(cfg.project_root));
}

def mobui_module_exempt(mod_path: str, project_root: (str | None)) -> bool {
    if not project_root {
        return True;
    }
    real_mod = os.path.normcase(os.path.realpath(mod_path));
    real_root = os.path.normcase(os.path.realpath(project_root));
    return not real_mod.startswith(real_root + os.sep);
}

def mobui_enforced_for(
    mod_path: str, explicit_kind: str = "web", explicit_root: (str | None) = None
) -> bool {
    (kind, proj_root) = resolve_client_kind_context(
        mod_path, explicit_kind, explicit_root
    );
    if kind != "mobui" {
        return False;
    }
    return not mobui_module_exempt(mod_path, proj_root);
}

obj ClientSurface {
    # Resolved-once description of a module's client rendering surface. Selected
    # during compilation and consulted by BOTH the type checker's ambient-vocabulary
    # gates and the ES backend selection so the two can never disagree. `framework`
    # names the ES/codegen backend ("react" | "preact" | "solid" | "compose");
    # `is_compose`/`is_mobui` gate target-specific checking.
    has framework: str = "react",
        kind: str = "web",
        project_root: (str | None) = None,
        is_compose: bool = False,
        is_mobui: bool = False;
}

def resolve_client_surface(
    mod_path: str,
    framework_override: str = "",
    explicit_kind: str = "web",
    explicit_root: (str | None) = None,
) -> ClientSurface {
    # Single, authoritative resolution of a module's client surface. An active
    # target threads its framework through CompileOptions.client_framework
    # (`framework_override`); that wins so the checker and the ES backend cannot
    # diverge on an in-memory page compile. With no override we fall back to the
    # per-module disk config (`[client] framework`) for standalone checking / LSP.
    (kind, proj_root) = resolve_client_kind_context(
        mod_path, explicit_kind, explicit_root
    );
    override = framework_override or "";
    if override == "compose" {
        framework = "compose";
        is_compose = True;
    } elif override {
        framework = override;
        # A non-compose target override still consults disk config for the compose
        # gate, matching the checker's historical fallback behaviour.
        is_compose = compose_enforced_for(mod_path);
    } else {
        cfg = _config_for(mod_path);
        framework = (cfg.client.framework if (cfg and cfg.client) else "") or "react";
        is_compose = compose_enforced_for(mod_path);
    }
    is_mobui = mobui_enforced_for(mod_path, explicit_kind, explicit_root);
    return ClientSurface(
        framework=framework,
        kind=kind,
        project_root=proj_root,
        is_compose=is_compose,
        is_mobui=is_mobui,
    );
}

def compose_enforced_for(mod_path: str) -> bool {
    # True when `mod_path` belongs to a project whose client framework is Compose
    # (`[client] framework = "compose"`). This is the single, config-driven signal
    # that a module is an Android/Compose client surface — the checker gates the
    # Compose ambient vocabulary (widgets/modifiers/consts/.dp extensions) on it so
    # a plain React `.cl.jac` never sees Compose names. Mirrors mobui_enforced_for:
    # a module physically outside the project root is exempt.
    cfg = _config_for(mod_path);
    if not cfg or cfg.project_root is None {
        return False;
    }
    framework = (cfg.client.framework if cfg.client else "") or "";
    if framework != "compose" {
        return False;
    }
    if not mod_path {
        return False;
    }
    real_mod = os.path.normcase(os.path.realpath(mod_path));
    real_root = os.path.normcase(os.path.realpath(str(cfg.project_root)));
    return real_mod == real_root or real_mod.startswith(real_root + os.sep);
}
