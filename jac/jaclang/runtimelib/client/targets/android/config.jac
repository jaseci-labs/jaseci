import from pathlib { Path }

def load_android_cfg(project_dir: Path) -> dict {
    try {
        import from jaclang.project.config { JacConfig }
        cfg = JacConfig.load(project_dir / "jac.toml");
        android_cfg = cfg.get_section("client.android");
        if not android_cfg {
            client = cfg.get_section("client") or {};
            android_cfg = client.get("android") if isinstance(client, dict) else {};
        }
        if not isinstance(android_cfg, dict) {
            android_cfg = {};
        }
        return android_cfg;
    } except Exception {
        return {};
    }
}

def load_client_cfg(project_dir: Path) -> dict {
    try {
        import from jaclang.project.config { JacConfig }
        cfg = JacConfig.load(project_dir / "jac.toml");
        client = cfg.get_section("client") or {};
        return client if isinstance(client, dict) else {};
    } except Exception {
        return {};
    }
}

def resolve_package_name(project_dir: Path) -> str {
    cfg = load_android_cfg(project_dir);
    pkg = cfg.get("package") or cfg.get("application_id");
    if pkg {
        return str(pkg);
    }
    return "dev.jac.generated";
}

def resolve_type_check(project_dir: Path) -> bool {
    val = load_android_cfg(project_dir).get("type_check");
    if val is None {
        return True;
    }
    return bool(val);
}

glob _SV_DEPLOY_VALUES: tuple[str, ...] = ("remote", "device", "local-first");

def resolve_sv_deploy(project_dir: Path) -> str {
    try {
        import from jaclang.project.config { JacConfig }
        cfg = JacConfig.load(project_dir / "jac.toml");
        sv = cfg.get_section("sv") or {};
        deploy = sv.get("deploy") if isinstance(sv, dict) else None;
        if deploy is None {
            return "remote";
        }
        val = str(deploy).strip();
        if val in _SV_DEPLOY_VALUES {
            return val;
        }
        allowed = ", ".join(_SV_DEPLOY_VALUES);
        raise RuntimeError(
            f"Invalid [sv].deploy = {deploy!r}; allowed: {allowed}"
        );
    } except RuntimeError {
        raise;
    } except Exception {
        return "remote";
    }
}

def resolve_sv_sync_url(project_dir: Path) -> (str | None) {
    try {
        import from jaclang.project.config { JacConfig }
        cfg = JacConfig.load(project_dir / "jac.toml");
        sv = cfg.get_section("sv") or {};
        sync = sv.get("sync") if isinstance(sv, dict) else None;
        if sync is None {
            return None;
        }
        s = str(sync).strip();
        return s if s else None;
    } except Exception {
        return None;
    }
}

def apply_android_cfg_to_model(model: any, project_dir: Path) {
    model.intent.package_name = resolve_package_name(project_dir);
    model.intent.sv_deploy = resolve_sv_deploy(project_dir);
    model.intent.sv_sync_url = resolve_sv_sync_url(project_dir);
    android_cfg = load_android_cfg(project_dir);
    if android_cfg.get("app_name") {
        model.intent.app_name = str(android_cfg["app_name"]);
    }
    if android_cfg.get("backend_url") {
        model.intent.backend_url = str(android_cfg["backend_url"]);
    }
}

def resolve_gradle_dependencies(project_dir: Path) -> list[str] {
    try {
        import from jaclang.project.config { JacConfig }
        cfg = JacConfig.load(project_dir / "jac.toml");
        gradle = cfg.plugin_dependencies.get("gradle", {});
        if not isinstance(gradle, dict) {
            return [];
        }
        deps: list[str] = [];
        for (key, coord) in gradle.items() {
            if key == "dev" or not isinstance(coord, str) or not coord.strip() {
                continue;
            }
            deps.append(coord.strip());
        }
        return deps;
    } except Exception {
        return [];
    }
}
