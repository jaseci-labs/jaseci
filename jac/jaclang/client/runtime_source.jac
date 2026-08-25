import os;

def client_runtime_cl_basename(framework: str = "", module: any = None) -> str {
    import from jaclang.compiler.backends.es.backends.registry {
        resolve_framework_backend,
        resolve_module_backend
    }
    backend = resolve_framework_backend(framework)
        if framework
        else resolve_module_backend(module);
    return backend.runtime_source_basename();
}

def resolve_client_runtime_cl_path(framework: str = "", module: any = None) -> str {
    import jaclang.client as _client_pkg;
    runtime_dir = os.path.dirname(str(_client_pkg.__file__));
    return os.path.join(runtime_dir, client_runtime_cl_basename(framework, module));
}
