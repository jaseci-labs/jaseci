import from typing { get_args, get_origin }
import from jaclang.runtimelib.serving.app { ServingApp }
import from jaclang.runtimelib.serving.datatypes { HTMLResponse }
import from jaclang.runtimelib.serving.endpoint {
    APIParameter,
    HTTPMethod,
    JEndPoint,
    ParameterType
}


glob _NAME_SCHEMAS: dict[str, dict[str, str]] = {
         'str': {'type': 'string'},
         'string': {'type': 'string'},
         'int': {'type': 'integer'},
         'integer': {'type': 'integer'},
         'float': {'type': 'number'},
         'number': {'type': 'number'},
         'bool': {'type': 'boolean'},
         'boolean': {'type': 'boolean'},
         'list': {'type': 'array'},
         'array': {'type': 'array'},
         'dict': {'type': 'object'},
         'object': {'type': 'object'}
     };


def _schema_for_type(target: any) -> dict[str, any] {
    if target is None {
        return {};
    }
    if isinstance(target, str) {
        return dict(_NAME_SCHEMAS.get(target.lower(), {}));
    }
    origin = get_origin(target);
    if origin is list {
        args = get_args(target);
        items = _schema_for_type(args[0]) if args else {};
        return {'type': 'array', 'items': items};
    }
    if origin is dict {
        return {'type': 'object'};
    }
    if target is str {
        return {'type': 'string'};
    }
    if target is int {
        return {'type': 'integer'};
    }
    if target is float {
        return {'type': 'number'};
    }
    if target is bool {
        return {'type': 'boolean'};
    }
    if isinstance(target, type) {
        return {'type': 'object', 'title': target.__name__};
    }
    return {};
}

def _param_schema(param: APIParameter) -> dict[str, any] {
    if param.type_obj is not None {
        return _schema_for_type(param.type_obj);
    }
    return _schema_for_type(param.data_type);
}

def _openapi_path(path: str) -> str {
    return path if path.startswith('/') else f"/{path}";
}

def build_openapi(app: ServingApp) -> dict[str, any] {
    if app.openapi_cache is not None {
        return app.openapi_cache;
    }
    paths: dict[str, any] = {};
    for ep in app.router.all_endpoints() {
        if not ep.include_in_schema {
            continue;
        }
        method = str(ep.method.value)
            if isinstance(ep.method, HTTPMethod)
            else str(ep.method);
        entry: dict[str, any] = {
            'responses': {str(ep.status_code or 200): {'description': 'Success'}}
        };
        if ep.summary {
            entry['summary'] = ep.summary;
        }
        if ep.description {
            entry['description'] = ep.description;
        }
        if ep.tags {
            entry['tags'] = list(ep.tags);
        }
        params_out: list[dict] = [];
        body_props: dict[str, any] = {};
        body_required: list[str] = [];
        has_file = False;
        for param in (ep.parameters or []) {
            kind = param.kind;
            if kind
                in (ParameterType.QUERY, ParameterType.PATH, ParameterType.HEADER) {
                location = str(kind.value);
                params_out.append(
                    {
                        'name': param.name,
                        'in': location,
                        'required': param.required or kind == ParameterType.PATH,
                        'schema': _param_schema(param),
                        'description': param.description or ''
                    }
                );
            } elif kind == ParameterType.FILE {
                has_file = True;
                body_props[param.name] = {'type': 'string', 'format': 'binary'};
                if param.required {
                    body_required.append(param.name);
                }
            } else {
                body_props[param.name] = _param_schema(param);
                if param.required {
                    body_required.append(param.name);
                }
            }
        }
        if params_out {
            entry['parameters'] = params_out;
        }
        if body_props {
            schema: dict[str, any] = {'type': 'object', 'properties': body_props};
            if body_required {
                schema['required'] = body_required;
            }
            content_type = 'multipart/form-data' if has_file else 'application/json';
            entry['requestBody'] = {
                'content': {content_type: {'schema': schema}},
                'required': bool(body_required)
            };
        }
        if ep.requires_auth {
            entry['security'] = [{'BearerAuth': []}];
        }
        norm_path = _openapi_path(ep.path);
        bucket = paths.setdefault(norm_path, {});
        bucket[method.lower()] = entry;
    }
    spec: dict[str, any] = {
        'openapi': '3.1.0',
        'info': {'title': app.title, 'version': app.version},
        'paths': paths
    };
    if app.openapi_security {
        spec['components'] = {'securitySchemes': dict(app.openapi_security)};
    } else {
        spec['components'] = {
            'securitySchemes': {'BearerAuth': {'type': 'http', 'scheme': 'bearer'}}
        };
    }
    app.openapi_cache = spec;
    return spec;
}

def swagger_ui_html(openapi_url: str, title: str) -> str {
    return (
        '<!DOCTYPE html>\n<html>\n<head>\n'
        f'<title>{title} - Swagger UI</title>\n'
        '<meta charset="utf-8"/>\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        '<link rel="stylesheet" '
        'href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui.css">\n'
        '</head>\n<body>\n<div id="swagger-ui"></div>\n'
        '<script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/'
        'swagger-ui-bundle.js"></script>\n'
        '<script>\n'
        'SwaggerUIBundle({\n'
        f'    url: "{openapi_url}",\n'
        '    dom_id: "#swagger-ui",\n'
        '    presets: [SwaggerUIBundle.presets.apis],\n'
        '    layout: "BaseLayout"\n'
        '});\n'
        '</script>\n</body>\n</html>'
    );
}

def register_docs_endpoints(app: ServingApp) {
    if app.openapi_url {
        def _openapi_callback -> dict[str, any] {
            return build_openapi(app);
        }
        app.add_endpoint(
            JEndPoint(
                method=HTTPMethod.GET,
                path=app.openapi_url,
                callback=_openapi_callback,
                include_in_schema=False,
                forward_undeclared_query_params=False
            )
        );
    }
    if app.docs_url and app.openapi_url {
        def _docs_callback -> HTMLResponse {
            return HTMLResponse(content=swagger_ui_html(app.openapi_url, app.title));
        }
        app.add_endpoint(
            JEndPoint(
                method=HTTPMethod.GET,
                path=app.docs_url,
                callback=_docs_callback,
                include_in_schema=False,
                forward_undeclared_query_params=False
            )
        );
    }
}
