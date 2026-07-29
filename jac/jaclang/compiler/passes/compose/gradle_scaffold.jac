"""Gradle project scaffold and boilerplate Kotlin for Compose Android emit."""
import from pathlib { Path }

obj GradleScaffold {
    has package_name: str = "dev.jac.generated",
        app_name: str = "Jac App",
        backend_url: str = "",
        routes: list[str] = [],
        dev: bool = False;

    def generate -> dict[str, str];
}

def build_gradle_scaffold(
    package_name: str,
    app_name: str,
    backend_url: str,
    routes: list[str],
    dev: bool = False
) -> dict[str, str];

def package_to_path(package_name: str) -> str;
def android_color_literal(hex: str) -> str;
def escape_kotlin(value: str) -> str;
def escape_android_xml(value: str) -> str;
def emit_jac_design -> str;
def ensure_gradle_wrapper(android_dir: Path) -> None;
