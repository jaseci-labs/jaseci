import from jaclang.compiler.passes.compose.gradle_scaffold { escape_kotlin }

impl walker_to_pascal(walker_name: str) -> str {
    parts = [
        p
        for p in walker_name.split('_')
        if p
    ];
    if not parts {
        return walker_name;
    }
    return ''.join([p[0].upper() + p[1:] if p else '' for p in parts]);
}

impl kotlin_default_literal(jac_type: str, value: any) -> (str | None) {
    if value is None {
        return None;
    }
    base = jac_type.strip();
    if base.endswith('| None') or base.endswith('|None') {
        base = base.split('|')[0].strip();
    }
    if base == 'str' {
        return f'"{escape_kotlin(str(value))}"';
    } elif base == 'int' {
        return str(int(value));
    } elif base == 'float' {
        return str(float(value));
    } elif base == 'bool' {
        return 'true' if value else 'false';
    } elif base.startswith('list[') {
        if value == [] or value == () {
            return 'emptyList()';
        }
    }
    return None;
}

impl RpcClientEmitter.jac_type_to_kotlin(jac_type: str) -> str {
    raw = jac_type.strip();
    if not raw {
        return 'Any';
    }
    if raw.endswith('| None') or raw.endswith('|None') {
        inner = raw.split('|')[0].strip();
        return f"{self.jac_type_to_kotlin(inner)}?";
    }
    if raw.startswith('list[') and raw.endswith(']') {
        inner = raw[5:-1].strip();
        return f"List<{self.jac_type_to_kotlin(inner)}>";
    }
    if raw.startswith('dict[') and raw.endswith(']') {
        inner = raw[5:-1];
        comma = inner.find(',');
        if comma >= 0 {
            k = inner[0:comma].strip();
            v = inner[comma + 1:].strip();
            return (
                f"Map<{self.jac_type_to_kotlin(k)}, " f"{self.jac_type_to_kotlin(v)}>"
            );
        }
        return "Map<String, Any>";
    }
    mapping: dict[str, str] = {
        'str': 'String',
        'int': 'Int',
        'float': 'Double',
        'bool': 'Boolean',
        'bytes': 'ByteArray',
        'Any': 'Any'
    };
    if raw in mapping {
        return mapping[raw];
    }
    return raw;
}

def _emit_enum_class(info: any) -> str {
    lines: list[str] = ['@Serializable', f"enum class {info.name} {{"];
    members = getattr(info, 'enum_members', []) or [];
    for (idx, (member_name, _val)) in enumerate(members) {
        suffix = ',' if idx < len(members) - 1 else '';
        lines.append(f"    {member_name}{suffix}");
    }
    lines.append('}');
    return '\n'.join(lines);
}

def _emit_data_class(class_name: str, info: any, emitter: RpcClientEmitter) -> str {
    kind = getattr(info, 'kind', 'obj');
    if kind == 'enum' {
        return _emit_enum_class(info);
    }
    fields: list[tuple[str, str]] = getattr(info, 'fields', []) or [];
    defaults = getattr(info, 'field_defaults', {}) or {};
    if not fields {
        return f"@Serializable\nclass {class_name}\n";
    }
    params: list[str] = [];
    for (fname, ftype) in fields {
        if ftype in ('JsonElement?', 'JsonElement') {
            kt = 'JsonElement?';
        } else {
            kt = emitter.jac_type_to_kotlin(ftype);
        }
        default_lit = kotlin_default_literal(ftype, defaults.get(fname));
        if default_lit is not None {
            params.append(f"val {fname}: {kt} = {default_lit}");
        } elif kt.endswith('?') {
            params.append(f"val {fname}: {kt} = null");
        } else {
            params.append(f"val {fname}: {kt}");
        }
    }
    body = ',\n    '.join(params);
    return f"@Serializable\ndata class {class_name}(\n    {body}\n)\n";
}

def _collect_nested_types(info: any, boundary_types: dict, collected: set[str]) {
    for nt in getattr(info, 'nested_types', []) or [] {
        if nt and nt not in collected and nt in boundary_types {
            collected.add(nt);
            _collect_nested_types(boundary_types[nt], boundary_types, collected);
        }
    }
}

def _is_pub_walker(manifest: any, walker_name: str) -> bool {
    access: dict[str, bool] = getattr(manifest, 'walker_access', {}) or {};

    return not access.get(walker_name, True);
}

def _walker_request_info(manifest: any, walker_name: str, pascal: str) -> any {
    import from jaclang.jac0core.codeinfo { BoundaryTypeInfo }
    boundary_types = getattr(manifest, 'boundary_types', {}) or {};
    request_name = f"{pascal}Request";
    if request_name in boundary_types {
        return boundary_types[request_name];
    }
    if walker_name in boundary_types {
        info = boundary_types[walker_name];

        return BoundaryTypeInfo(
            name=request_name,
            kind=getattr(info, 'kind', 'walker') or 'walker',
            fields=list(getattr(info, 'fields', []) or []),
            field_defaults=dict(getattr(info, 'field_defaults', {}) or {}),
            enum_members=list(getattr(info, 'enum_members', []) or []),
            nested_types=list(getattr(info, 'nested_types', []) or [])
        );
    }
    bindings = getattr(manifest, 'bindings', {}) or {};
    binding = bindings.get(walker_name);
    if binding {
        fields: list[tuple[str, str]] = [];
        names = getattr(binding, 'param_names', []) or [];
        types = getattr(binding, 'param_types', []) or [];
        for (idx, pname) in enumerate(names) {
            ptype = types[idx] if idx < len(types) else 'Any';
            fields.append((pname, ptype));
        }
        return BoundaryTypeInfo(name=request_name, kind='walker', fields=fields);
    }
    return BoundaryTypeInfo(name=request_name, kind='walker', fields=[]);
}

def _walker_response_info(manifest: any, pascal: str) -> any {
    boundary_types = getattr(manifest, 'boundary_types', {}) or {};
    response_name = f"{pascal}Response";
    if response_name in boundary_types {
        return boundary_types[response_name];
    }
    if pascal in boundary_types {
        return boundary_types[pascal];
    }
    import from jaclang.jac0core.codeinfo { BoundaryTypeInfo }

    return BoundaryTypeInfo(
        name=response_name,
        kind='obj',
        fields=[('reports', 'list[str]')],
        field_defaults={'reports': []}
    );
}

def _collect_pub_walker_names(manifest: any) -> list[str] {
    walker_names: list[str] = [];
    if manifest is None {
        return walker_names;
    }
    access: dict[str, bool] = getattr(manifest, 'walker_access', {}) or {};
    bindings: dict[str, any] = getattr(manifest, 'bindings', {}) or {};
    seen: set[str] = set();
    for name in access.keys() {
        if _is_pub_walker(manifest, name) and name not in seen {
            walker_names.append(name);
            seen.add(name);
        }
    }
    for name in bindings.keys() {
        binding = bindings[name];
        if getattr(binding, 'kind', '') == 'walker' and name not in seen {
            if _is_pub_walker(manifest, name) {
                walker_names.append(name);
                seen.add(name);
            }
        }
    }
    return walker_names;
}

def _collect_boundary_type_blocks(
    manifest: any, walker_names: list[str], emitter: RpcClientEmitter
) -> str {
    boundary_types: dict = {};
    if manifest is not None {
        boundary_types = dict(getattr(manifest, 'boundary_types', {}) or {});
    }

    type_names: set[str] = set();
    type_infos: dict = {};
    for wname in walker_names {
        pascal = walker_to_pascal(wname);
        req = _walker_request_info(manifest, wname, pascal);
        res = _walker_response_info(manifest, pascal);
        type_names.add(req.name);
        type_names.add(res.name);
        type_infos[req.name] = req;
        type_infos[res.name] = res;
        _collect_nested_types(req, boundary_types, type_names);
        _collect_nested_types(res, boundary_types, type_names);
    }

    type_blocks: list[str] = [];
    emitted: set[str] = set();
    for tname in sorted(type_names) {
        if tname in emitted {
            continue;
        }
        info = type_infos.get(tname) or boundary_types.get(tname);
        if info is None {
            if tname.endswith('Response') {
                import from jaclang.jac0core.codeinfo { BoundaryTypeInfo }
                info = BoundaryTypeInfo(
                    name=tname,
                    kind='obj',
                    fields=[('reports', 'list[str]')],
                    field_defaults={'reports': []}
                );
            } else {
                continue;
            }
        }
        type_blocks.append(_emit_data_class(tname, info, emitter));
        emitted.add(tname);
    }
    return '\n\n'.join(type_blocks);
}

def _emit_boundary_types(package_name: str, manifest: any) -> str {
    emitter = RpcClientEmitter(package_name=package_name);
    walker_names = _collect_pub_walker_names(manifest);
    types_src = _collect_boundary_type_blocks(manifest, walker_names, emitter);
    return f"""package {package_name}

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement

{types_src}
""";
}

def _emit_backend_interface(
    package_name: str, manifest: any, walker_names: list[str]
) -> str {
    iface_methods: list[str] = [];
    for wname in sorted(walker_names) {
        pascal = walker_to_pascal(wname);
        req_name = f"{pascal}Request";
        res_name = f"{pascal}Response";
        iface_methods.append(
            f"    suspend fun {wname}(req: {req_name}, nodeId: String? = null): "
            f"{res_name}"
        );
    }
    methods_src = '\n'.join(iface_methods);
    return f"""package {package_name}

interface JacBackend {{
{methods_src}
}}

object JacBackends {{
    lateinit var current: JacBackend
}}
""";
}

def _emit_jac_http(package_name: str) -> str {
    import os;
    import jaclang;
    tpl_dir = os.path.join(
        os.path.dirname(jaclang.__file__),
        "compiler",
        "passes",
        "compose",
        "gradle_templates",
        "jacgraph"
    );
    with open(os.path.join(tpl_dir, "JacHttp.kt"), encoding="utf-8") as f {
        return f.read().replace("{{package}}", package_name);
    }
}

def _emit_remote_backend(
    package_name: str, manifest: any, walker_names: list[str]
) -> str {
    walker_methods: list[str] = [];
    for wname in sorted(walker_names) {
        pascal = walker_to_pascal(wname);
        req_name = f"{pascal}Request";
        res_name = f"{pascal}Response";
        walker_methods.append(
            f"    override suspend fun {wname}(req: {req_name}, nodeId: String?): "
            f'{res_name} = call("{escape_kotlin(wname)}", req, nodeId)'
        );
    }
    methods_src = '\n'.join(walker_methods);

    return f"""package {package_name}

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.jsonObject

class RemoteBackend(
    var baseUrl: String = JacEnvironment.BACKEND_URL,
    var token: String? = null,
) : JacBackend {{
    suspend inline fun <reified Req, reified Res> call(
        walker: String,
        req: Req,
        nodeId: String? = null
    ): Res = withContext(Dispatchers.IO) {{
        val suffix = nodeId?.let {{ "/$it" }} ?: ""
        val url = baseUrl + "/walker/" + walker + suffix
        val (code, body) = JacHttp.postJson(url, req, token)
        if (code == 401) {{
            token = null
        }}
        if (code !in 200..299) {{
            throw RuntimeException("RemoteBackend HTTP $code: $body")
        }}
        val data = JacHttp.json.parseToJsonElement(body).jsonObject["data"]
            ?: throw RuntimeException("RemoteBackend: missing data field")
        JacHttp.json.decodeFromJsonElement<Res>(data)
    }}

{methods_src}
}}
""";
}

def _device_init_reg_lines(node_names: list[str]) -> str {
    reg_lines = "\n".join(
        f"        JacGraphSerializers.registerNodeSubclass("
        f"{name}::class, {name}.serializer())" for name in node_names
    );
    if reg_lines {
        reg_lines += "\n";
    }
    return reg_lines;
}

def _emit_jac_backend_init(
    package_name: str,
    deploy: str,
    node_names: list[str] = [],
    sync_url: (str | None) = None
) -> str {
    reg_lines = _device_init_reg_lines(node_names);
    if deploy == "device" {
        return f"""package {package_name}

import android.content.Context

object JacBackendInit {{
    fun install(context: Context? = null) {{
{reg_lines}        context?.let {{ JacGraph.init(it) }}
        JacBackends.current = DeviceBackend()
    }}
}}
""";
    }
    if deploy == "local-first" {
        sync_lit = escape_kotlin(sync_url or "");
        return f"""package {package_name}

import android.content.Context

object JacBackendInit {{
    fun install(context: Context? = null) {{
{reg_lines}        context?.let {{ ctx ->
            JacGraph.init(ctx)
            JacSync.init(ctx, "{sync_lit}")
            JacSync.schedulePeriodicSync(ctx)
        }}
        JacBackends.current = LocalFirstBackend()
    }}
}}
""";
    }
    return f"""package {package_name}

import android.content.Context

object JacBackendInit {{
    fun install(context: Context? = null) {{
        JacBackends.current = RemoteBackend()
    }}
}}
""";
}

def _emit_device_backend(
    package_name: str, manifest: any, walker_names: list[str]
) -> str {
    walker_methods: list[str] = [];
    for wname in sorted(walker_names) {
        pascal = walker_to_pascal(wname);
        req_name = f"{pascal}Request";
        res_name = f"{pascal}Response";
        wclass = pascal;
        walker_methods.append(
            f"    override suspend fun {wname}(req: {req_name}, nodeId: String?): "
            f"{res_name} {{\n"
            f"        val w = {wclass}("
                + ", ".join(
                    [
                        f"{fname} = req.{fname}"
                        for (fname, _) in (
                            getattr(
                                _walker_request_info(manifest, wname, pascal),
                                'fields',
                                []
                            )
                            or []
                        )
                    ]
                )
                + ")\n"
                f"        val reports = w.spawnOn(nodeId?.let {{ JacGraph.byId(it) }} "
                f"?: JacGraph.root)\n"
                f"        JacGraph.persist()\n"
                f"        return {res_name}(reports = reports.map {{ it?.toString() "
                f"?: \"\" }})\n"
                f"    }}"
        );
    }
    methods_src = '\n'.join(walker_methods);
    return f"""package {package_name}

class DeviceBackend : JacBackend {{
{methods_src}
}}
""";
}

def _emit_local_first_backend(
    package_name: str, manifest: any, walker_names: list[str]
) -> str {
    walker_methods: list[str] = [];
    for wname in sorted(walker_names) {
        pascal = walker_to_pascal(wname);
        req_name = f"{pascal}Request";
        res_name = f"{pascal}Response";
        walker_methods.append(
            f"    override suspend fun {wname}(req: {req_name}, nodeId: String?): "
            f"{res_name} {{\n"
            f"        val result = device.{wname}(req, nodeId)\n"
            f"        JacSync.requestSync()\n"
            f"        return result\n"
            f"    }}"
        );
    }
    methods_src = '\n'.join(walker_methods);
    return f"""package {package_name}

class LocalFirstBackend(
    private val device: DeviceBackend = DeviceBackend(),
) : JacBackend {{
{methods_src}
}}
""";
}

def _combine_sv_backend_sources(
    files: dict[str, str], package_name: str, exclude: set[str]
) -> str {
    imports: set[str] = set();
    bodies: list[str] = [];
    order = ["JacBoundary.kt", "JacBackend.kt", "JacHttp.kt", "RemoteBackend.kt"];
    for fname in order {
        if fname in exclude or fname not in files {
            continue;
        }
        src = files[fname];
        lines = src.split('\n');
        body_lines: list[str] = [];
        in_body = False;
        for line in lines {
            if not in_body {
                if line.startswith('import ') {
                    imports.add(line);
                } elif line.startswith('package ') {
                    ;
                } elif line.strip() {
                    in_body = True;
                    body_lines.append(line);
                }
            } else {
                body_lines.append(line);
            }
        }
        bodies.append('\n'.join(body_lines).strip());
    }
    imp_block = '\n'.join(sorted(imports));
    return (f"package {package_name}\n\n{imp_block}\n\n" + '\n\n'.join(bodies) + "\n");
}

impl emit_sv_backend(
    package_name: str,
    manifest: any,
    deploy: str,
    sync_url: (str | None),
    node_names: list[str] = []
) -> dict[str, str] {
    effective = deploy;
    if deploy == "local-first" and not sync_url {
        try {
            import from jaclang.cli.console { console }
            console.warning(
                "  sv deploy=local-first requires [sv].sync URL; sync worker will no-op"
            );
        } except Exception {
            ;
        }
    }
    walker_names = _collect_pub_walker_names(manifest);
    files: dict[str, str] = {
        "JacBoundary.kt": _emit_boundary_types(package_name, manifest),
        "JacBackend.kt": _emit_backend_interface(package_name, manifest, walker_names),
        "JacBackendInit.kt": _emit_jac_backend_init(
            package_name, effective, node_names, sync_url
        )
    };
    if effective == "device" {
        files["DeviceBackend.kt"] = _emit_device_backend(
            package_name, manifest, walker_names
        );
    } elif effective == "local-first" {
        files["DeviceBackend.kt"] = _emit_device_backend(
            package_name, manifest, walker_names
        );
        files["LocalFirstBackend.kt"] = _emit_local_first_backend(
            package_name, manifest, walker_names
        );
    } else {
        files["RemoteBackend.kt"] = _emit_remote_backend(
            package_name, manifest, walker_names
        );
        files["JacHttp.kt"] = _emit_jac_http(package_name);
    }
    return files;
}

def _emit_jac_client_body(package_name: str, manifest: any) -> str {
    files = emit_sv_backend(package_name, manifest, "remote", None);
    return _combine_sv_backend_sources(
        files, package_name, exclude={"JacBackendInit.kt"}
    );
}

impl RpcClientEmitter.emit(manifest: any) -> str {
    return emit_jac_client(self.package_name, manifest);
}

impl emit_jac_client(package_name: str, manifest: any) -> str {
    return _emit_jac_client_body(package_name, manifest);
}
