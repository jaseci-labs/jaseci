import os;

glob VALID_CLIENT_KINDS: list[str] = ["web", "mobui"],
     APP_TABLE_KEYS: tuple[str, ...] = (
         "kind",
         "path",
         "entry_point",
         "client",
         "client_kind",
         "platform",
         "route"
     );

obj AppConfig {
    has name: str,
        kind: str,
        path: str = "",
        entry_point: str = "",
        client: str = "",
        client_kind: str = "web",
        platform: str = "",
        route: str = "",
        overlays: dict[str, any] = {},
        implicit: bool = False;

    def root_dir(project_root: str) -> str;
    def entry_path(project_root: str) -> str;
    def is_file_rooted -> bool;
    def effective_route -> str;
    def effective_client -> str;
    def contains(project_root: str, abs_path: str) -> bool;
}

def validate_app_name(name: str) -> None;

def parse_apps(project_data: dict, apps_data: dict) -> dict[str, AppConfig];

def implicit_app(config: any) -> AppConfig;

def _norm_path(path: str) -> str;
