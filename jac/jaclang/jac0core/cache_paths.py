"""Single source of truth for jac's global on-disk cache root.

Pure Python with no jac dependencies, so it is importable during bootstrap —
before the jac0core ``.jac`` modules have been transpiled. Both the bootstrap
bytecode cache (``meta_importer``) and the JIR module cache
(``jaclang.jac0core.jir``) derive their directories from here, so the
platform-resolution logic lives in exactly one place.

This module owns only the genuinely global, config-independent directories.
The per-module cache locations (``jir/modules/`` and its ``native/`` subdir)
are project-aware and therefore resolved in ``jaclang.jac0core.jir`` via
``get_module_cache_path``/``get_native_cache_dir(source_path)``, which fall
back to the project's ``.jac/cache`` when inside a project.

Platform roots:
    Linux:   ~/.cache/jac/jir/             ($XDG_CACHE_HOME honored)
    macOS:   ~/Library/Caches/jac/jir/
    Windows: %LOCALAPPDATA%/jac/cache/jir/
"""

import os
import sys
from pathlib import Path


def get_jir_cache_dir() -> Path:
    """Return the platform-appropriate global cache directory for JIR files."""
    if sys.platform == "win32":
        base = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
        return base / "jac" / "cache" / "jir"
    elif sys.platform == "darwin":
        return Path.home() / "Library" / "Caches" / "jac" / "jir"
    else:
        xdg = os.environ.get("XDG_CACHE_HOME")
        base = Path(xdg) if xdg else (Path.home() / ".cache")
        return base / "jac" / "jir"


def get_bootstrap_cache_dir() -> Path:
    """Global cache dir for marshalled jac0core bootstrap bytecode."""
    return get_jir_cache_dir() / "bootstrap"


# jaclang package root (parent of jac0core/).  Pure-Python so jir.jac and
# meta_importer can consult it before jac0core is transpiled.
_JACLANG_PKG_DIR = str(Path(__file__).resolve().parent.parent)
_JAC0CORE_DIR = str(Path(__file__).resolve().parent)

# Known jaclang subpackages.  Used for structural matching so eligibility
# works when the checkout compiler reads checkout paths while cache_paths.py
# lives in the sealed runtime bundle (test-compiler's binary lane).
_JACLANG_SUBPACKAGES = frozenset(
    {
        "byllm",
        "cli",
        "compiler",
        "jac0core",
        "langserve",
        "lsp",
        "project",
        "publish",
        "runtimelib",
        "scale",
        "tests",
        "utils",
        "vendor",
    }
)


def _is_under_jaclang_tree(resolved: Path) -> bool:
    parts = resolved.parts
    for i, part in enumerate(parts):
        if (
            part == "jaclang"
            and i + 1 < len(parts)
            and parts[i + 1] in _JACLANG_SUBPACKAGES
        ):
            return True
    return False


def is_bootstrap_jac_path(source_path: str) -> bool:
    """True for jac0-tier .jac sources compiled by jac0 during bootstrap."""
    resolved = Path(source_path).resolve()
    if resolved.suffix != ".jac":
        return False
    parts = resolved.parts
    for i, part in enumerate(parts):
        if part == "jac0core" and i > 0 and parts[i - 1] == "jaclang":
            return True
    resolved_str = str(resolved)
    return resolved_str.startswith(_JAC0CORE_DIR + os.sep)


def is_jac_lazy_eligible(source_path: str) -> bool:
    """True when a .jac module may use lazy chunked JIR (user deps only).

    Excludes jac0core bootstrap modules and the jaclang self-hosting tree so
    enabling JAC_LAZY_JAC globally does not cascade lazy hydration across the
    ~165 interdependent compiler modules (which OOMs under memory pressure).
    """
    resolved = Path(source_path).resolve()
    resolved_str = str(resolved)
    if not resolved_str.endswith(".jac") or resolved_str.endswith(".na.jac"):
        return False
    if is_bootstrap_jac_path(resolved_str):
        return False
    if _is_under_jaclang_tree(resolved):
        return False
    if resolved_str.startswith(_JACLANG_PKG_DIR + os.sep):
        return False
    return True


def get_app_cache_dir() -> Path:
    """Global cache dir for materialized app bundles (.jab), content-keyed."""
    return get_jir_cache_dir().parent / "apps"
