import from pathlib { Path }

def _read_shadcn_config(config: any) -> any;

def _registry_dir -> any;

def load_registry -> dict;

def parse_style_css(style_name: str) -> dict;

def resolve_component(source: str, resolution_map: dict) -> str;

def resolve_single_component(component_name: str, style: str) -> dict;

def _resolve_peer_deps(requested: list, registry_data: dict, existing: set) -> list;

def _is_ui_dir(path: Path) -> bool;

def _resolve_ui_dir(project_root: Path, shadcn_config: any) -> Path;

def _module_of(project_root: Path, path: Path) -> str;

def _resolve_utils(project_root: Path, ui_dir: Path, shadcn_config: any) -> tuple;

def _retarget_utils_import(
    content: str, ui_dir: Path, project_root: Path, utils_mod: str
) -> str;

def _update_npm_deps(config: any, npm_deps: dict) -> None;

def add_shadcn_components(config: any, component_names: list) -> bool;

def remove_shadcn_components(config: any, component_names: list) -> bool;
