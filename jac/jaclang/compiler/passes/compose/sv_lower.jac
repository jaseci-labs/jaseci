import jaclang.jac0core.unitree as uni;

obj SvLowerResult {
    has files: dict[str, str] = {},
        node_names: list[str] = [],
        diagnostics: list[str] = [];
}

def emit_jacgraph_templates(package_name: str) -> dict[str, str];
def run_sv_lower(mod: uni.Module, manifest: any, package_name: str) -> SvLowerResult;
