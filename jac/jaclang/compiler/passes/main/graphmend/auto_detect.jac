import ast as ast3;

def module_imports_torch(src: str, file_path: str) -> bool {
    if 'torch' not in src {
        return False;
    }
    if file_path.endswith('.py') {
        return _py_imports_torch(src);
    }
    return _jac_binds_torch(src, file_path);
}

def file_imports_torch(file_path: str) -> bool {
    import from jaclang.jac0core.jir { read_source_shared }
    try {
        src = read_source_shared(file_path);
        if src is None {
            return False;
        }
        return module_imports_torch(src, file_path);
    } except Exception {
        return False;
    }
}

def _is_torch_path(path: str) -> bool {
    return (path == 'torch') or path.startswith('torch.');
}

def _py_imports_torch(src: str) -> bool {
    try {
        tree = ast3.parse(src);
    } except (SyntaxError, ValueError) {
        return False;
    }
    for nd in ast3.walk(tree) {
        if isinstance(nd, ast3.Import) {
            for alias in nd.names {
                if _is_torch_path(alias.name) {
                    return True;
                }
            }
        } elif isinstance(nd, ast3.ImportFrom) {
            if (
                nd.level == 0 and (nd.module is not None) and _is_torch_path(nd.module)
            ) {
                return True;
            }
        }
    }
    return False;
}

def _jac_binds_torch(src: str, file_path: str) -> bool {
    import from jaclang.jac0core.parser { parse as rd_parse }
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.compiler.passes.main.graphmend.scope_facts {
        module_binds_torch
    }
    try {
        (mod, _had_error) = rd_parse(src, file_path, prog=JacProgram());
    } except Exception {
        return False;
    }
    return module_binds_torch(mod);
}
