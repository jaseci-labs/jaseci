"""The gateway in local microservice mode must still serve the web app.

A web-app project's entry module is a service like any other -- it just
happens to be the one that answers at the project root: the landing page,
`/cl/<page>`, `[serve] base_route_app`, the SPA shell for a client route, and
the generated `/static/client.js`. Before this, the gateway had no idea any
service played that role: `/` and `/docs/...` 404'd, and `/cl/app` was raced
across every service in registration order. These tests pin that the app
service owns the project root, and that no page request fans out.
"""

import tempfile;
import from jaclang.server.serving.app { ServingApp }
import from jaclang.server.serving.datatypes { JSONResponse, Request, Response }
import from jaclang.server.serving.server { ServingServer }
import from jaclang.scale.runtime.gateway.microservice_gateway { MicroserviceGateway }
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceEntry,
    ServiceRegistry,
    ServiceStatus
}
import from jaclang.testing.testkit { ServingTestClient }


"""Serve a marker backend that names itself in every response body."""
def _spawn_stub(
    name: str, spec_paths: list[str], seen: list[str], ready: list[bool]
) -> tuple {
    app = ServingApp(title=name);

    async def marker(request: Request, call_next: object) -> Response {
        path: str = request.url.path;
        seen.append(f"{name} {path}");
        if path == "/openapi.json" {
            if not ready[0] {
                return Response(content="not ready", status_code=404);
            }
            return JSONResponse(
                content={
                    "openapi": "3.0.2",
                    "paths": {p: {"get": {"responses": {}}} for p in spec_paths}
                }
            );
        }
        if path in ("/healthz", "/health") {
            return JSONResponse(content={"status": "healthy"});
        }
        return Response(content=f"{name} {path}", media_type="text/plain");
    }
    app.add_middleware(marker);
    server = ServingServer(app=app, host="127.0.0.1", port=0);
    server.serve_background();
    assert server.bound_port , f"stub service {name} did not bind a port";
    return (server, server.bound_port);
}


obj Fleet {
    has gateway: MicroserviceGateway,
        client: ServingTestClient,
        app_seen: list[str],
        peer_seen: list[str],
        peer: ServiceEntry,
        peer_ready: list[bool],
        _servers: list[any];

    def close {
        for srv in self._servers {
            srv.request_stop();
        }
    }
}


"""A two-service fleet: a peer service and the project's app service.

The peer registers first on purpose -- a gateway that guesses by asking
services in order would hand it the app's pages.
"""
def _fleet(
    peer_ready: bool = True, peer_status: ServiceStatus = ServiceStatus.HEALTHY
) -> Fleet {
    app_seen: list[str] = [];
    peer_seen: list[str] = [];
    peer_flag: list[bool] = [peer_ready];
    (peer_srv, peer_port) = _spawn_stub(
        "social_graph", ["/api/orders"], peer_seen, peer_flag
    );
    (app_srv, app_port) = _spawn_stub("main", ["/walker/ping"], app_seen, [True]);

    reg = ServiceRegistry();
    peer = ServiceEntry(
        name="social_graph",
        file="socialize/social_graph.jac",
        prefix="/social_graph",
        port=peer_port,
        url=f"http://127.0.0.1:{peer_port}",
        status=peer_status
    );
    reg.register(peer);
    reg.register(
        ServiceEntry(
            name="main",
            file="main.jac",
            prefix="/__main__",
            port=app_port,
            url=f"http://127.0.0.1:{app_port}",
            status=ServiceStatus.HEALTHY,
            is_app=True,
            serves_client=True
        )
    );

    gw = MicroserviceGateway(
        registry=reg, client_dist_dir=tempfile.mkdtemp(), base_path=tempfile.mkdtemp()
    );
    gw.setup();
    return Fleet(
        gateway=gw,
        client=ServingTestClient(gw.app),
        app_seen=app_seen,
        peer_seen=peer_seen,
        peer=peer,
        peer_ready=peer_flag,
        _servers=[peer_srv, app_srv]
    );
}


test "the landing page reaches the app service instead of 404ing" {
    fleet = _fleet();
    try {
        resp = fleet.client.get("/", headers={"Accept": "text/html"});
        assert resp.status_code == 200 , (
            f"a web-app in microservice mode must still have a landing page; "
            f"got {resp.status_code}"
        );
        assert resp.text == "main /" , (
            f"the app service answers the project root (that is where "
            f"[serve] base_route_app is honored); got {resp.text!r}"
        );
    } finally {
        fleet.close();
    }
}


test "a client page goes to the app service, not to whichever service answers first" {
    fleet = _fleet();
    try {
        resp = fleet.client.get("/cl/app");
        assert resp.status_code == 200;
        assert resp.text == "main /cl/app" , (
            f"/cl/<page> belongs to the app service; got {resp.text!r}"
        );
        assert "/cl/app" not in " ".join(fleet.peer_seen) , (
            "page requests must not be raced across every service - a service "
            "that is still compiling hangs the page"
        );
    } finally {
        fleet.close();
    }
}


test "a client-side route falls back to the app service's SPA shell" {
    fleet = _fleet();
    try {
        resp = fleet.client.get(
            "/docs/getting-started", headers={"Accept": "text/html"}
        );
        assert resp.status_code == 200;
        assert resp.text == "main /docs/getting-started" , (
            f"an unclaimed page path is the app's client route; got {resp.text!r}"
        );
    } finally {
        fleet.close();
    }
}


test "the generated client bundle is served by the app service" {
    fleet = _fleet();
    try {
        resp = fleet.client.get("/static/client.js");
        assert resp.status_code == 200;
        assert resp.text == "main /static/client.js" , (
            f"/static/client.js is generated by the server, not a file on "
            f"disk, so the gateway must forward it; got {resp.text!r}"
        );
    } finally {
        fleet.close();
    }
}


test "a peer service still owns the routes it declares" {
    fleet = _fleet();
    try {
        resp = fleet.client.get("/api/orders");
        assert resp.status_code == 200;
        assert resp.text == "social_graph /api/orders" , (
            f"a declared root route beats the app fallback; got {resp.text!r}"
        );
        prefixed = fleet.client.get("/social_graph/anything");
        assert prefixed.status_code == 200;
        assert prefixed.text == "social_graph /anything";
    } finally {
        fleet.close();
    }
}


test "routes of a service that was still starting are learned once it is healthy" {
    fleet = _fleet(peer_ready=False, peer_status=ServiceStatus.STARTING);
    try {
        first = fleet.client.get("/api/orders");
        assert first.text == "main /api/orders" , (
            "while the peer cannot publish a spec its routes are unknown, so "
            "the app service answers"
        );

        fleet.peer_ready[0] = True;
        fleet.peer.status = ServiceStatus.HEALTHY;

        second = fleet.client.get("/api/orders");
        assert second.text == "social_graph /api/orders" , (
            f"the gateway must re-ask a service that was still starting when "
            f"it first answered; got {second.text!r}"
        );
    } finally {
        fleet.close();
    }
}
