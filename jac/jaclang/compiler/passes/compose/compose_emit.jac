"""Orchestrator: IntentModule → Android project directory on disk."""
import from pathlib { Path }
import from jaclang.compiler.passes.ecmascript.intent.model { IntentModule }

obj ComposeEmit {
    has model: IntentModule,
        out_dir: Path,
        dev: bool = False;

    def write -> list[Path];
    def emit_screens -> str;
    def emit_jac_app -> str;
}

def route_to_screen_name(path: str) -> str;
def component_screen_name(comp_name: str) -> str;
