"""Gateway dispatch of app-declared routes (`@restspec(path=...)`) at the root."""

import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}
import from jaclang.scale.runtime.gateway.microservice_gateway { MicroserviceGateway }
import from jaclang.scale.runtime.gateway.route_table {
    ServiceRouteTable,
    literal_prefix
}


"""Stand in for a jac backend: an OpenAPI doc plus the paths it advertises."""
def _serve_backend(paths: dict) -> tuple {
    import http.server;
    import json;
    import threading;

    spec = json.dumps(
        {
            "openapi": "3.0.2",
            "info": {"title": "backend", "version": "1.0.0"},
            "paths": {p: {"get": {}, "post": {}} for p in paths}
        }
    ).encode();

    def _respond(handler_self: any) {
        if handler_self.path == "/openapi.json" {
            body = spec;
        } else {
            hit = paths.get(handler_self.path.split("?")[0]);
            if hit is None {
                handler_self.send_response(404);
                handler_self.send_header("Content-Length", "0");
                handler_self.end_headers();
                return;
            }
            body = json.dumps(hit).encode();
        }
        handler_self.send_response(200);
        handler_self.send_header("Content-Type", "application/json");
        handler_self.send_header("Content-Length", str(len(body)));
        handler_self.end_headers();
        handler_self.wfile.write(body);
    }

    def _log_quiet(handler_self: any, fmt: str, *args: any) { }

    handler_cls = type(
        "_BackendHandler",
        (http.server.BaseHTTPRequestHandler, ),
        {"do_GET": _respond, "do_POST": _respond, "log_message": _log_quiet}
    );
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler_cls);
    threading.Thread(target=srv.serve_forever, daemon=True).start();
    return (srv, srv.server_address[1]);
}


def _gateway_for(port: int, prefix: str = "/main") -> MicroserviceGateway {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="main",
            file="main.jac",
            prefix=prefix,
            port=port,
            url=f"http://127.0.0.1:{port}",
            status=ServiceStatus.HEALTHY
        )
    );
    gw = MicroserviceGateway(registry=reg);
    gw.setup();
    return gw;
}


test "a root-level @restspec route reaches the backend that declares it" {
    (srv, port) = _serve_backend(
        {"/api/auth/config": {"sso": ["google"]}, "/custom/walker": {"ok": True}}
    );
    gw = _gateway_for(port);

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    try {
        resp = client.get("/api/auth/config");
        assert resp.status_code == 200 , (
            f"the backend declares GET /api/auth/config, so the gateway must "
            f"forward it instead of treating it as a missing static asset; got "
            f"{resp.status_code}"
        );
        assert resp.json() == {"sso": ["google"]};

        custom = client.get("/custom/walker");
        assert custom.status_code == 200 , (
            f"@restspec paths are arbitrary - /custom/walker must route on the "
            f"same declaration, not on a hardcoded segment allowlist; got "
            f"{custom.status_code}"
        );
    } finally {
        srv.shutdown();
    }
}


test "a declared route wins over the SPA shell for a browser navigation" {
    import tempfile;
    import from pathlib { Path }

    (srv, port) = _serve_backend({"/api/auth/config": {"sso": []}});
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "index.html").write_text("<html>spa-shell</html>");

    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="main",
            file="main.jac",
            prefix="/main",
            port=port,
            url=f"http://127.0.0.1:{port}",
            status=ServiceStatus.HEALTHY
        )
    );
    gw = MicroserviceGateway(registry=reg, client_dist_dir=tmp);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    try {
        resp = client.get("/api/auth/config", headers={"Accept": "text/html"});
        assert resp.status_code == 200;
        assert "spa-shell" not in resp.text , (
            "a path a service declares belongs to that service, even when the "
            "browser would accept the SPA shell"
        );

        spa = client.get("/dashboard", headers={"Accept": "text/html"});
        assert spa.status_code == 200;
        assert "spa-shell" in spa.text , (
            "client-side routes no service declares still fall back to the SPA"
        );
    } finally {
        srv.shutdown();
        import shutil;
        shutil.rmtree(tmp);
    }
}


test "static assets keep winning over a service's declared routes" {
    import tempfile;
    import from pathlib { Path }

    (srv, port) = _serve_backend({"/assets/app.js": {"from": "backend"}});
    tmp = tempfile.mkdtemp();
    assets = Path(tmp) / "assets";
    assets.mkdir();
    (assets / "app.js").write_text("var fromDisk = 1;");

    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="main",
            file="main.jac",
            prefix="/main",
            port=port,
            url=f"http://127.0.0.1:{port}",
            status=ServiceStatus.HEALTHY
        )
    );
    gw = MicroserviceGateway(registry=reg, client_dist_dir=tmp);
    gw.setup();

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    try {
        resp = client.get("/assets/app.js");
        assert resp.status_code == 200;
        assert "fromDisk" in resp.text , (
            "a real file in the client bundle is the gateway's to serve"
        );
    } finally {
        srv.shutdown();
        import shutil;
        shutil.rmtree(tmp);
    }
}


test "a path no service declares still 404s instead of fanning out" {
    (srv, port) = _serve_backend({"/api/auth/config": {}});
    gw = _gateway_for(port);

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    try {
        resp = client.get("/api/nope");
        assert resp.status_code == 404;
        assert resp.json()["error"]["code"] == "NOT_FOUND";
    } finally {
        srv.shutdown();
    }
}


test "the route table matches templated paths on their literal head" {
    table = ServiceRouteTable();
    table.learn("orders", ["/api/orders/{order_id}", "/api/orders"]);

    assert table.owner("/api/orders") == "orders";
    assert table.owner("/api/orders/42") == "orders";
    assert table.owner("/api/ordersXX") == "" , (
        "prefix matching must respect segment boundaries"
    );
    assert table.owner("/api") == "";
}


test "literal_prefix stops at the first templated segment" {
    assert literal_prefix("/api/auth/config") == "/api/auth/config";
    assert literal_prefix("/api/items/{item_id}/tags") == "/api/items";
    assert literal_prefix("/{full_path:path}") == "" , (
        "a catch-all template must not let a service claim every path"
    );
    assert literal_prefix("/") == "";
}


test "relearning a service replaces the routes it previously claimed" {
    table = ServiceRouteTable();
    table.learn("main", ["/api/old"]);
    assert table.owner("/api/old") == "main";

    table.learn("main", ["/api/new"]);
    assert table.owner("/api/new") == "main";
    assert table.owner("/api/old") == "" , (
        "a redeployed service must not keep owning routes it dropped"
    );
}


test "a service cannot claim back the paths the gateway answers itself" {
    table = ServiceRouteTable();
    table.learn(
        "main",
        [
            "/user/login",
            "/user/register",
            "/user/me",
            "/admin/users",
            "/admin",
            "/healthz",
            "/openapi.json",
            "/api/auth/config"
        ]
    );

    for owned in ["/user/login", "/user/me", "/admin/users", "/healthz"] {
        assert table.owner(owned) == "" , (
            f"every jac backend advertises {owned} in its own OpenAPI; letting "
            f"it own the path would take gateway identity and admin away"
        );
    }
    assert table.owner("/api/auth/config") == "main";
}


test "learning a real spec keeps gateway-owned paths out of the table" {
    (srv, port) = _serve_backend(
        {
            "/user/login": {"from": "backend"},
            "/admin/users": {"from": "backend"},
            "/healthz": {"from": "backend"},
            "/api/ping": {"ok": True}
        }
    );
    gw = _gateway_for(port);

    import from fastapi.testclient { TestClient }
    client = TestClient(gw.app);
    try {
        assert client.get("/api/ping").status_code == 200;
        assert gw.route_table.owner("/api/ping") == "main" , (
            "the /api/ping request must have populated the table"
        );

        for owned in ["/user/login", "/admin/users", "/healthz"] {
            assert gw.route_table.owner(owned) == "" , (
                f"every jac backend publishes {owned} in its own OpenAPI - the "
                f"gateway must not hand its own surface to a service"
            );
        }
    } finally {
        srv.shutdown();
    }
}


test "the first service to claim a path keeps it, and the clash is reported" {
    table = ServiceRouteTable();
    table.learn("orders", ["/api/shared"]);
    clashes = table.learn("cart", ["/api/shared", "/api/cart"]);

    assert table.owner("/api/shared") == "orders";
    assert table.owner("/api/cart") == "cart";
    assert clashes == ["/api/shared"];
}
