"""Module resolver utilities."""

from __future__ import annotations

import os
import site
import sys
from typing import Optional, Tuple


def get_jac_search_paths(base_path: Optional[str] = None) -> list[str]:
    """Construct a list of paths to search for Jac modules."""
    paths = []
    if base_path:
        paths.append(base_path)
    paths.append(os.getcwd())
    if "JACPATH" in os.environ:
        paths.extend(
            p.strip() for p in os.environ["JACPATH"].split(os.pathsep) if p.strip()
        )
    paths.extend(sys.path)
    site_pkgs = site.getsitepackages()
    if site_pkgs:
        paths.extend(site_pkgs)
    user_site = getattr(site, "getusersitepackages", None)
    if user_site:
        user_dir = user_site()
        if user_dir:
            paths.append(user_dir)
    return list(dict.fromkeys(filter(None, paths)))


def get_typeshed_paths() -> list[str]:
    """Return the typeshed stubs and stdlib directories if available."""
    # You may want to make this configurable or autodetect
    # Corrected base path calculation: removed one ".."
    base = os.path.join(
        os.path.dirname(__file__),  # jaclang/utils
        "..",  # jaclang
        "compiler",
        "jtyping",
        "typeshed",  # jaclang/compiler/jtyping/typeshed
    )
    base = os.path.abspath(base)
    stubs = os.path.join(base, "stubs")
    stdlib = os.path.join(base, "stdlib")
    paths = []
    if os.path.isdir(stubs):
        paths.append(stubs)
    if os.path.isdir(stdlib):
        paths.append(stdlib)
    return paths


def _candidate_from(base: str, parts: list[str]) -> Optional[Tuple[str, str]]:
    candidate = os.path.join(base, *parts)
    if os.path.isdir(candidate):
        if os.path.isfile(os.path.join(candidate, "__init__.jac")):
            return os.path.join(candidate, "__init__.jac"), "jac"
        if os.path.isfile(os.path.join(candidate, "__init__.py")):
            return os.path.join(candidate, "__init__.py"), "py"
    if os.path.isfile(candidate + ".jac"):
        return candidate + ".jac", "jac"
    if os.path.isfile(candidate + ".py"):
        return candidate + ".py", "py"
    return None


def _candidate_from_typeshed(base: str, parts: list[str]) -> Optional[Tuple[str, str]]:
    """Find .pyi files in typeshed, trying module.pyi then package/__init__.pyi."""
    if not parts: # Should generally not be empty for valid module targets
        return None

    # This is the path prefix for the module/package, e.g., os.path.join(base, "collections", "abc")
    candidate_prefix = os.path.join(base, *parts)

    # 1. Check for a direct module file (e.g., base/parts.pyi or base/package/module.pyi)
    # Example: parts=["collections", "abc"] -> candidate_prefix = base/collections/abc
    # module_file_pyi = base/collections/abc.pyi
    # Example: parts=["sys"] -> candidate_prefix = base/sys
    # module_file_pyi = base/sys.pyi
    module_file_pyi = candidate_prefix + ".pyi"
    if os.path.isfile(module_file_pyi):
        return module_file_pyi, "pyi"

    # 2. Check if the candidate_prefix itself is a directory (package)
    #    and look for __init__.pyi inside it.
    # Example: parts=["_typeshed"] -> candidate_prefix = base/_typeshed
    # init_pyi = base/_typeshed/__init__.pyi
    if os.path.isdir(candidate_prefix):
        init_pyi = os.path.join(candidate_prefix, "__init__.pyi")
        if os.path.isfile(init_pyi):
            return init_pyi, "pyi"

        # Heuristic for packages where stubs are in a subdirectory of the same name
        # e.g., parts = ["requests"], candidate_prefix = base/requests
        # checks base/requests/requests/__init__.pyi
        # This part of the original heuristic is preserved.
        if parts: # Ensure parts is not empty for parts[-1]
            inner_pkg_init_pyi = os.path.join(
                candidate_prefix, parts[-1], "__init__.pyi"
            )
            if os.path.isfile(inner_pkg_init_pyi):
                return inner_pkg_init_pyi, "pyi"

    return None


def resolve_module(target: str, base_path: str) -> Tuple[str, str]:
    """Resolve module path and infer language, prioritizing local Jac/Python modules before typeshed."""
    parts = target.split(".")
    level = 0
    while level < len(parts) and parts[level] == "":
        level += 1
    actual_parts = parts[level:]

    # 1. Search Jac/Python modules in local/configured search paths
    search_paths = get_jac_search_paths(os.path.dirname(base_path))
    for search_dir in search_paths:
        candidate_base_path = os.path.join(search_dir, *actual_parts)
        # Jac package (__init__.jac)
        init_jac = os.path.join(candidate_base_path, "__init__.jac")
        if os.path.isdir(candidate_base_path) and os.path.isfile(init_jac):
            return init_jac, "jac"
        # Jac module (.jac)
        module_jac = candidate_base_path + ".jac"
        if os.path.isfile(module_jac):
            return module_jac, "jac"
        # Python package (__init__.py)
        init_py = os.path.join(candidate_base_path, "__init__.py")
        if os.path.isdir(candidate_base_path) and os.path.isfile(init_py):
            return init_py, "py"
        # Python module (.py)
        module_py = candidate_base_path + ".py"
        if os.path.isfile(module_py):
            return module_py, "py"

    # 2. If not found, search typeshed for .pyi stubs
    typeshed_paths = get_typeshed_paths()
    if typeshed_paths:
        for typeshed_dir in typeshed_paths:
            res = _candidate_from_typeshed(typeshed_dir, actual_parts)
            if res:
                return res
        # If not found in any typeshed directory, return a stub .pyi path for type checking.
        stub_pyi_path = os.path.join(typeshed_paths[0], *actual_parts) + ".pyi"
        return stub_pyi_path, "pyi"

    # 3. If not found anywhere, fallback to nominal .pyi path in importing dir
    importing_dir = os.path.dirname(base_path)
    if not os.path.isdir(importing_dir):
        importing_dir = os.getcwd()
    nominal_pyi_path = os.path.join(importing_dir, *actual_parts) + ".pyi"
    return nominal_pyi_path, "py"


def infer_language(target: str, base_path: str) -> str:
    """Infer language for target relative to base path."""
    _, lang = resolve_module(target, base_path)
    return lang


def resolve_relative_path(target: str, base_path: str) -> str:
    """Resolve only the path component for a target."""
    path, _ = resolve_module(target, base_path)
    return path
