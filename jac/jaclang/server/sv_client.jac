import os;
import from jaclang.server.bridge {
    BridgeError,
    BridgeUnavailable,
    bridge_error_for_status,
    bridge_error_from
}

glob BRIDGE_TOKEN_ENV: str = "JAC_BRIDGE_TOKEN",
     _registry: dict[str, str] = {},
     _routes: dict[str, str] = {},
     _test_clients: dict[str, any] = {},
     _local_providers: dict[str, any] = {},
     _consumer_providers: dict[str, list[str]] = {},
     _bearer_token: list[str] = [];

def headless_start_args(entry_file: str, port: int) -> list[str] {
    return ["run", "--serve", "--port", str(port), "--no-client", entry_file];
}

def register(app: str, url: str, route: str = "") {
    _registry[app] = url.rstrip("/");
    if route {
        _routes[app] = route;
    }
}

def unregister(app: str) {
    _registry.pop(app, None);
    _routes.pop(app, None);
}

def register_local(app: str, module: any) {
    _local_providers[app] = module;
}

def unregister_local(app: str) {
    _local_providers.pop(app, None);
}

def is_local(app: str) -> bool {
    return app in _local_providers;
}

def register_test_client(app: str, client: any) {
    _test_clients[app] = client;
}

def clear_test_clients {
    _test_clients.clear();
}

def clear_local_providers {
    _local_providers.clear();
}

def set_bearer_token(token: str) {
    _bearer_token.clear();
    if token {
        _bearer_token.append(token);
    }
}

def bearer_token -> str {
    if _bearer_token {
        return _bearer_token[0];
    }
    return os.environ.get(BRIDGE_TOKEN_ENV, "").strip();
}

def auth_headers -> dict[str, str] {
    token = bearer_token();
    if not token {
        return {};
    }
    return {"Authorization": f"Bearer {token}"};
}

def _declare_consumer_provider(consumer_app: str, provider_app: str, route: str = "") {
    if consumer_app not in _consumer_providers {
        _consumer_providers[consumer_app] = [];
    }
    if provider_app not in _consumer_providers[consumer_app] {
        _consumer_providers[consumer_app].append(provider_app);
    }
    if route and provider_app not in _routes {
        _routes[provider_app] = route;
    }
}

def get_consumer_providers(consumer_app: str) -> list[str] {
    return list(_consumer_providers.get(consumer_app, []));
}

def clear_consumer_providers {
    _consumer_providers.clear();
}

def provider_route(app: str) -> str {
    return _routes.get(app, "");
}

def peer_url_env_key(app: str) -> str {
    safe = "".join(ch if ch.isalnum() else "_" for ch in app);
    return f"JAC_APP_{safe.upper()}_URL";
}

def peer_route_env_key(app: str) -> str {
    return peer_url_env_key(app)[:-4] + "_ROUTE";
}

def peer_url_from_env(app: str) -> str {
    return os.environ.get(peer_url_env_key(app), "").strip();
}

def _unavailable(app: str, name: str = "") -> BridgeUnavailable {
    return BridgeUnavailable(
        app=app,
        name=name,
        detail=f"app '{app}' is not registered; set {peer_url_env_key(app)} "
            + "or call sv_client.register()"
    );
}

def resolve_url(app: str) -> str {
    base = _registry.get(app, "");
    if not base {
        env_url = peer_url_from_env(app);
        if not env_url {
            raise _unavailable(app);
        }
        register(app, env_url, os.environ.get(peer_route_env_key(app), "").strip());
        base = _registry[app];
    }
    route = _routes.get(app, "");
    if route and not base.endswith(route) {
        return base + route;
    }
    return base;
}

def _ensure_available(app: str, name: str = "") -> None {
    if app in _local_providers or app in _test_clients or app in _registry {
        return;
    }
    env_url = peer_url_from_env(app);
    if env_url {
        register(app, env_url, os.environ.get(peer_route_env_key(app), "").strip());
        return;
    }
    raise _unavailable(app, name);
}

def _scale_transport -> any {
    import from jaclang.runtime.runtime { _scale_provider }
    provider = _scale_provider();
    if provider is not None and provider.sv_transport_available() {
        return provider;
    }
    return None;
}

def _unwrap_envelope(data: any, app: str, name: str) -> any {
    if isinstance(data, dict) and data.get("ok") {
        return data.get("data");
    }
    err = (data.get("error") if isinstance(data, dict) else None) or {};
    msg = err.get("message") if isinstance(err, dict) else str(err);
    raise BridgeError(app=app, name=name, detail=str(msg or "unknown error"));
}

def _http_call(app: str, fn: str, kwargs: dict) -> any {
    import from jaclang.server.serving.client { post_stream_aware_sync }
    import from jaclang.server.serving.sse { consume_sse_events }
    label = f"{app}.{fn}";
    headers = auth_headers();
    if app in _test_clients {
        client = _test_clients[app];
        resp = client.post(f"/function/{fn}", json=kwargs, headers=headers);
        ct = str(resp.headers.get("Content-Type") or "");
        if ct.startswith("text/event-stream") {
            return consume_sse_events(str(resp.text).splitlines(), label);
        }
        data = resp.json();
    } else {
        (kind, payload) = post_stream_aware_sync(
            f"{resolve_url(app)}/function/{fn}",
            json_body=kwargs,
            headers=headers,
            label=label
        );
        if kind == "sse" {
            return payload;
        }
        data = payload;
    }
    envelope = _unwrap_envelope(data, app, fn);
    if isinstance(envelope, dict) and ("result" in envelope) {
        return envelope["result"];
    }
    return envelope;
}

def _rehydrate_walker(envelope: any, stub_cls: any) -> any {
    result_dict = envelope.get("result") if isinstance(envelope, dict) else None;
    reports = envelope.get("reports") if isinstance(envelope, dict) else None;
    instance = stub_cls._from_wire(result_dict)
        if (stub_cls is not None and result_dict is not None)
        else result_dict;
    if instance is None and stub_cls is not None {
        instance = stub_cls._from_wire({});
    }
    if instance is not None and reports is not None {
        try {
            instance.reports = reports;
        } except Exception {}
    }
    return instance;
}

def _http_spawn(app: str, walker_name: str, kwargs: dict, stub_cls: any) -> any {
    import from jaclang.server.serving.client { request_sync }
    headers = auth_headers();
    if app in _test_clients {
        client = _test_clients[app];
        data = client.post(
            f"/walker/{walker_name}", json=kwargs, headers=headers
        ).json();
    } else {
        resp = request_sync(
            "POST",
            f"{resolve_url(app)}/walker/{walker_name}",
            headers=headers,
            json_body=kwargs
        );
        if resp.status_code >= 400 {
            raise bridge_error_for_status(
                resp.status_code, app, walker_name, resp.text()
            );
        }
        data = resp.json();
    }
    return _rehydrate_walker(_unwrap_envelope(data, app, walker_name) or {}, stub_cls);
}

async def _await_if_needed(value: any) -> any {
    import inspect;
    if inspect.isawaitable(value) {
        return await value;
    }
    return value;
}

async def _local_call(app: str, fn: str, kwargs: dict) -> any {
    module = _local_providers[app];
    target = getattr(module, fn, None);
    if target is None or not callable(target) {
        raise BridgeError(app=app, name=fn, detail=f"no function '{fn}'", status=404);
    }
    return await _await_if_needed(target(**kwargs));
}

async def _local_spawn(app: str, walker_name: str, kwargs: dict) -> any {
    import jaclang;
    module = _local_providers[app];
    walker_cls = getattr(module, walker_name, None);
    if walker_cls is None or not isinstance(walker_cls, type) {
        raise BridgeError(
            app=app, name=walker_name, detail=f"no walker '{walker_name}'", status=404
        );
    }
    instance = walker_cls(**kwargs);
    result = await _await_if_needed(
        jaclang.JacRuntime.`spawn(instance, jaclang.JacRuntime.root())
    );
    walked = result if result is not None else instance;
    if not hasattr(walked, "reports") {
        try {
            walked.reports = [];
        } except Exception {}
    }
    return walked;
}

async def call(app: str, fn: str, kwargs: dict) -> any {
    try {
        if app in _local_providers {
            return await _local_call(app, fn, kwargs);
        }
        _ensure_available(app, fn);
        transport = _scale_transport();
        if transport is not None and app not in _test_clients {
            return transport.sv_service_call(app, fn, kwargs);
        }
        return _http_call(app, fn, kwargs);
    } except Exception as e {
        raise bridge_error_from(e, app, fn);
    }
}

async def spawn_walker(app: str, walker_name: str, kwargs: dict, stub_cls: any) -> any {
    try {
        if app in _local_providers {
            return await _local_spawn(app, walker_name, kwargs);
        }
        _ensure_available(app, walker_name);
        transport = _scale_transport();
        if transport is not None and app not in _test_clients {
            return transport.sv_walker_call(app, walker_name, kwargs, stub_cls);
        }
        return _http_spawn(app, walker_name, kwargs, stub_cls);
    } except Exception as e {
        raise bridge_error_from(e, app, walker_name);
    }
}

def spawn_deferred(
    app: str, walker_name: str, kwargs: dict, idempotency_key: str = ""
) -> str {
    import from jaclang.server.outbox { enqueue }
    return enqueue(app, walker_name, kwargs, idempotency_key);
}

def ensure_all(apps: list[str]) -> None {
    for app in apps {
        _ensure_available(app);
    }
}
