import os;
import from pathlib { Path }

glob PAGES_DIR_NAME: str = "pages";

def pages_dir_in(project_root: Path) -> Path {
    return Path(project_root) / PAGES_DIR_NAME;
}

def has_pages_dir(project_root: Path) -> bool {
    pages = pages_dir_in(project_root);
    return pages.exists() and pages.is_dir();
}

def is_pages_routing_entry(mod_path: str) -> bool {
    if not mod_path {
        return False;
    }
    try {
        import from jaclang.project.config { get_config_for_dir }
        cfg = get_config_for_dir(os.path.dirname(os.path.abspath(mod_path)));
    } except ImportError {
        return False;
    }
    if not cfg or cfg.project_root is None {
        return False;
    }
    proj_root = Path(str(cfg.project_root));
    entry_point = cfg.project.entry_point or "main.jac";
    try {
        if Path(mod_path).resolve() != (proj_root / entry_point).resolve() {
            return False;
        }
    } except OSError {
        return False;
    }
    return has_pages_dir(proj_root);
}
