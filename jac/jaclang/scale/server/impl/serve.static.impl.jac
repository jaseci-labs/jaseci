import mimetypes;
import from pathlib { Path }
import from jaclang.server.serving.datatypes { HTMLResponse, JSONResponse, Response }
import from jaclang.server.serving.endpoint {
    APIParameter,
    HTTPMethod,
    JEndPoint,
    ParameterType
}
import from jaclang.runtime.runtime { JacRuntime as Jac }
import from jaclang.server.server { JsonValue }
import from jaclang.cli.console { console }

impl JacAPIServerStatic.serve_static_file(file_path: str) -> Response {
    try {
        import from jaclang.project.config { find_project_root }
        base_path_dir = Path(bp_dir)
            if (bp_dir := Jac.get_context().base_path_dir or Jac.get_base_path_dir())
            else Path.cwd();
        project_root_result = find_project_root(base_path_dir);
        if project_root_result {
            (base_path, _) = project_root_result;
        } else {
            base_path = base_path_dir;
        }
        file_name = Path(file_path).name;

        client_build_dist_file = base_path / '.jac' / 'client' / 'dist' / file_path;
        client_build_dist_file_simple = base_path
            / '.jac'
            / 'client'
            / 'dist'
            / file_name;

        dist_file = base_path / 'dist' / file_path;
        dist_file_simple = base_path / 'dist' / file_name;

        assets_file = base_path / 'assets' / file_path;
        assets_file_simple = base_path / 'assets' / file_name;
        if file_name.endswith('.css') {
            if client_build_dist_file.exists() {
                css_content = client_build_dist_file.read_text(encoding='utf-8');
                return Response(content=css_content, media_type='text/css');
            } elif client_build_dist_file_simple.exists() {
                css_content = client_build_dist_file_simple.read_text(encoding='utf-8');
                return Response(content=css_content, media_type='text/css');
            } elif dist_file.exists() {
                css_content = dist_file.read_text(encoding='utf-8');
                return Response(content=css_content, media_type='text/css');
            } elif dist_file_simple.exists() {
                css_content = dist_file_simple.read_text(encoding='utf-8');
                return Response(content=css_content, media_type='text/css');
            } elif assets_file.exists() {
                css_content = assets_file.read_text(encoding='utf-8');
                return Response(content=css_content, media_type='text/css');
            } elif assets_file_simple.exists() {
                css_content = assets_file_simple.read_text(encoding='utf-8');
                return Response(content=css_content, media_type='text/css');
            } else {
                return Response(
                    status_code=404,
                    content='CSS file not found',
                    media_type='text/plain'
                );
            }
        }
        for candidate_file in [
            client_build_dist_file,
            client_build_dist_file_simple,
            dist_file,
            dist_file_simple,
            assets_file,
            assets_file_simple
        ] {
            if (candidate_file.exists() and candidate_file.is_file()) {
                file_content = candidate_file.read_bytes();
                (content_type, _) = mimetypes.guess_type(str(candidate_file));
                if (content_type is None) {
                    content_type = 'application/octet-stream';
                }
                return Response(content=file_content, media_type=content_type);
            }
        }
        return Response(
            status_code=404, content='Static file not found', media_type='text/plain'
        );
    } except Exception as exc {
        return Response(status_code=500);
    }
}

impl JacAPIServerStatic.register_static_file_endpoint -> None {
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/static/{file_path:path}',
            callback=self.serve_static_file,
            parameters=[
                APIParameter(
                    name='file_path',
                    data_type='string',
                    required=True,
                    default_value=None,
                    description='Path of the static file to serve',
                    kind=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['Static Files'],
            summary='Serve static files',
            description='Endpoint to serve static files from the server.'
        )
    );
}

impl JacAPIServerStatic.register_client_js_endpoint -> None {
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/static/client.js',
            callback=self.serve_client_js_callback(),
            parameters=[],
            response_model=None,
            tags=['Static Files'],
            summary='Serve client.js',
            description='Endpoint to serve the client-side JavaScript file.'
        )
    );
}

impl JacAPIServerStatic.serve_client_js_callback -> Callable[..., Response] {
    def callback -> Response {
        try {
            return Response(
                content=Jac.get_client_js(self.introspector),
                media_type='application/javascript'
            );
        } except RuntimeError as exc {
            return Response(content=str(exc), status_code=503, media_type='text/plain');
        }
    }
    return callback;
}

def _sibling_app_dist(config: any, name: str) -> (Path | None) {
    import from jaclang.project.kinds { kind_spec }
    if config is None or not config.is_workspace {
        return None;
    }
    app = config.app(name);
    if app is None {
        return None;
    }
    served = config.app_for_path(Jac.get_full_target_path() or "");
    if served is not None and served.name == app.name {
        return None;
    }
    spec = kind_spec(config.resolved_kind(app));
    if not (app.client or (spec is not None and spec.client_target)) {
        return None;
    }
    root_dir = str(config.project_root) if config.project_root else "";
    if not root_dir {
        return None;
    }
    dist = Path(root_dir) / 'dist' / app.name;
    return dist if (dist / 'index.html').is_file() else None;
}


def _sibling_app_file(dist: Path, rel: str) -> Response {
    candidate = (dist / rel) if rel else (dist / 'index.html');
    try {
        resolved = candidate.resolve();
        inside = resolved == dist.resolve() or dist.resolve() in resolved.parents;
    } except Exception {
        inside = False;
    }
    if not (inside and candidate.is_file()) {
        candidate = dist / 'index.html';
    }
    (content_type, _) = mimetypes.guess_type(str(candidate));
    return Response(
        content=candidate.read_bytes(),
        media_type=content_type or 'application/octet-stream'
    );
}


impl JacAPIServerStatic.register_page_endpoint -> None {
    import from jaclang.project.config { get_config }
    config = get_config();
    root_app = self.introspector.resolve_root_app();

    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/cl/{page_name}',
            callback=self.render_page_callback(),
            parameters=[
                APIParameter(
                    name='page_name',
                    data_type='string',
                    required=True,
                    default_value=None,
                    description='Name of the page to render',
                    kind=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['Pages'],
            summary='Render a page',
            description='Endpoint to render and retrieve a specific page by name at /cl/{name}, or a sibling app bundle at /cl/<app>/.'
        )
    );

    if config is not None and config.is_workspace {
        def _sibling_asset(app_name: str, file_path: str) -> Response {
            dist = _sibling_app_dist(config, app_name);
            if dist is None {
                return Response(
                    status_code=404, content='Not found', media_type='text/plain'
                );
            }
            return _sibling_app_file(dist, file_path);
        }
        self.server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.GET,
                path='/cl/{app_name}/{file_path:path}',
                callback=_sibling_asset,
                parameters=[
                    APIParameter(
                        name='app_name',
                        data_type='string',
                        required=True,
                        default_value=None,
                        description='Sibling app whose bundle lives at dist/<app>/',
                        kind=ParameterType.PATH
                    ),
                    APIParameter(
                        name='file_path',
                        data_type='string',
                        required=True,
                        default_value=None,
                        description='Path inside the sibling app bundle',
                        kind=ParameterType.PATH
                    )
                ],
                response_model=None,
                tags=['Pages'],
                summary='Serve a sibling app bundle',
                description='Serves a workspace sibling client app from dist/<app>/ at /cl/<app>/.'
            )
        );
    }

    if root_app {
        self.server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.GET,
                path='/',
                callback=self.render_base_route_callback(root_app),
                parameters=[],
                response_model=None,
                tags=['Pages'],
                summary='Served app',
                description=f'Serves the {root_app} client app at the root path.'
            )
        );
    }
}

impl JacAPIServerStatic.render_page_callback -> Callable[..., Response] {
    import from jaclang.project.config { get_config }
    config = get_config();

    def callback(page_name: str, **kwargs: JsonValue) -> Response {
        sibling = _sibling_app_dist(config, page_name);
        if sibling is not None {
            return _sibling_app_file(sibling, '');
        }
        try {
            render_payload = self.introspector.render_page(
                page_name, kwargs, Con.GUEST.value
            );
            return HTMLResponse(content=render_payload['html']);
        } except ValueError as exc {
            return HTMLResponse(content=f"<h1>404 Not Found</h1>", status_code=404);
        } except RuntimeError as exc {
            console.print(f"Error rendering page '{page_name}': {exc}");
            return HTMLResponse(
                content=f"<h1>503 Service Unavailable</h1>", status_code=503
            );
        }
    }
    return callback;
}

impl JacAPIServerStatic.render_base_route_callback(
    app_name: str
) -> Callable[..., HTMLResponse] {
    def callback(**kwargs: JsonValue) -> HTMLResponse {
        try {
            render_payload = self.introspector.render_page(
                app_name, kwargs, Con.GUEST.value
            );
            return HTMLResponse(
                content=render_payload['html'],
                status_code=self.introspector.spa_fallback_status('/')
            );
        } except ValueError as exc {
            return HTMLResponse(content=f"<h1>404 Not Found</h1>", status_code=404);
        } except RuntimeError as exc {
            console.print(f"Error rendering base route app '{app_name}': {exc}");
            return HTMLResponse(
                content=f"<h1>503 Service Unavailable</h1>", status_code=503
            );
        }
    }
    return callback;
}

impl JacAPIServerStatic.serve_root_asset(file_path: str) -> Response {
    allowed_extensions = {
        '.png',
        '.jpg',
        '.jpeg',
        '.gif',
        '.webp',
        '.svg',
        '.ico',
        '.woff',
        '.woff2',
        '.ttf',
        '.otf',
        '.eot',
        '.mp4',
        '.webm',
        '.mp3',
        '.wav',
        '.css',
        '.js',
        '.json',
        '.pdf',
        '.txt',
        '.xml'
    };
    file_ext = Path(file_path).suffix.lower();
    import from jaclang.project.config { get_config }
    config = get_config();
    if file_path.startswith('cl/') {
        parts = file_path[3:].split('/', 1);
        sibling = _sibling_app_dist(config, parts[0]);
        if sibling is not None {
            return _sibling_app_file(sibling, parts[1] if len(parts) > 1 else '');
        }
    }
    api_prefixes = ('cl/', 'walker/', 'function/', 'user/', 'static/');
    if (not file_ext or (file_ext not in allowed_extensions)) {
        root_app = self.introspector.resolve_root_app();
        if (not file_ext and root_app and not file_path.startswith(api_prefixes)) {
            try {
                render_payload = self.introspector.render_page(
                    root_app, {}, Con.GUEST.value
                );
                return HTMLResponse(
                    content=render_payload['html'],
                    status_code=self.introspector.spa_fallback_status(file_path)
                );
            } except ValueError {
                return HTMLResponse(content="<h1>404 Not Found</h1>", status_code=404);
            } except RuntimeError {
                return HTMLResponse(
                    content="<h1>503 Service Unavailable</h1>", status_code=503
                );
            }
        }
        return Response(status_code=404, content='Not found', media_type='text/plain');
    }
    if file_path.startswith(api_prefixes) {
        return Response(status_code=404, content='Not found', media_type='text/plain');
    }

    import from jaclang.project.config { find_project_root }
    base_path_dir = Path(bp_dir)
        if (bp_dir := Jac.get_context().base_path_dir or Jac.get_base_path_dir())
        else Path.cwd();
    project_root_result = find_project_root(base_path_dir);
    if project_root_result {
        (base_path, _) = project_root_result;
    } else {
        base_path = base_path_dir;
    }
    file_name = Path(file_path).name;

    candidates = [
        base_path / 'dist' / file_path,
        base_path / 'dist' / file_name,
        base_path / 'assets' / file_path,
        base_path / 'assets' / file_name,
        base_path / 'public' / file_path,
        base_path / 'src' / file_path,
        base_path / 'src' / file_name,
        (base_path / file_path),
        base_path / '.jac' / 'client' / 'dist' / file_path,
        base_path / '.jac' / 'client' / 'dist' / file_name
    ];

    for candidate_file in candidates {
        if (candidate_file.exists() and candidate_file.is_file()) {
            file_content = candidate_file.read_bytes();
            (content_type, _) = mimetypes.guess_type(str(candidate_file));
            if (content_type is None) {
                content_type = 'application/octet-stream';
            }
            headers = {'Cache-Control': 'public, max-age=31536000'};
            return Response(
                content=file_content, media_type=content_type, headers=headers
            );
        }
    }
    return Response(
        status_code=404,
        content=f"Asset not found: {file_path}",
        media_type='text/plain'
    );
}

impl JacAPIServerStatic.register_root_asset_endpoint -> None {
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/{file_path:path}',
            callback=self.serve_root_asset,
            parameters=[
                APIParameter(
                    name='file_path',
                    data_type='string',
                    required=True,
                    default_value=None,
                    description='Path to asset file (e.g., img.png, icons/logo.svg)',
                    kind=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['Static Files'],
            summary='Serve root-level assets',
            description='Endpoint to serve assets from root path with common extensions (.png, .jpg, .svg, etc.)'
        )
    );
}

impl JacAPIServerStatic.register_graph_endpoint -> None {
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/graph',
            callback=self.serve_graph_page,
            parameters=[],
            response_model=None,
            tags=['Graph Visualization'],
            summary='Graph Visualizer',
            description='Interactive graph visualization UI for exploring the backend graph'
        )
    );
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/graph/data',
            callback=self.graph_data,
            parameters=[
                APIParameter(
                    name='Authorization',
                    data_type='string',
                    required=False,
                    default_value=None,
                    description='Bearer JWT token (optional - falls back to public/guest graph if not provided)',
                    kind=ParameterType.HEADER
                )
            ],
            response_model=None,
            tags=['Graph Visualization'],
            summary='Graph Data',
            description='Returns graph data (nodes and edges) as JSON. With auth: returns user graph. Without auth: returns public graph (super root).'
        )
    );
}

impl JacAPIServerStatic.serve_graph_page -> HTMLResponse {
    import jaclang.scale;
    import from pathlib { Path }

    html_content = (
        Path(jaclang.scale.__file__).parent / 'templates' / 'graph.html'
    ).read_text(
        encoding='utf-8'
    );
    return HTMLResponse(content=html_content, status_code=200);
}


impl JacAPIServerStatic.graph_data(Authorization: (str | None) = None) -> JSONResponse {
    import from jaclang.runtime.graph_utils { collect_node_connections }

    token: (str | None) = None;
    if (
        Authorization
        and isinstance(Authorization, str)
        and Authorization.startswith('Bearer ')
    ) {
        token = Authorization[7:];
    }
    username = self.user_manager.validate_jwt_token(token) if token else None;

    username = username or Con.GUEST.value;

    root_id = self.user_manager.get_root_id(username);
    if not root_id {
        return JSONResponse(
            status_code=404,
            content={'error': 'Not found', 'message': 'User root not found'}
        );
    }
    ctx = Jac.get_context();
    ctx.set_user_root(root_id);
    try {
        user_root = ctx.get_root();
        visited_nodes: set = set();
        connections: set = set();
        edge_ids: set = set();
        nodes: list[dict] = [];
        edges: list[dict] = [];

        collect_node_connections(user_root, visited_nodes, connections, edge_ids);

        nodes.append({'id': Jac.object_ref(user_root), 'label': 'root'});
        for node_arch in visited_nodes {
            if (node_arch != user_root) {
                nodes.append(
                    {'id': Jac.object_ref(node_arch), 'label': repr(node_arch)}
                );
            }
        }
        for (_, source_node, target_node, edge_arch) in connections {
            edge_data: dict = {
                'from': Jac.object_ref(source_node),
                'to': Jac.object_ref(target_node)
            };
            if (repr(edge_arch) != 'GenericEdge()') {
                edge_data['label'] = repr(edge_arch);
            }
            edges.append(edge_data);
        }

        return JSONResponse(
            status_code=200, content={'version': '1.0', 'nodes': nodes, 'edges': edges}
        );
    } except Exception as e {
        return JSONResponse(
            status_code=500, content={'error': 'Internal error', 'message': str(e)}
        );
    }
}
