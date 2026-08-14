import os;
import tempfile;
import from starlette.requests { Request }
import from jaclang.scale.runtime.gateway.microservice_gateway { MicroserviceGateway }
import from jaclang.scale.runtime.gateway.service_registry { ServiceRegistry }


def _get_request -> Request {
    return Request({"type": "http", "method": "GET", "headers": []});
}


def _make_gateway(
    project_root: str, shadow_mount: str, dist: str
) -> MicroserviceGateway {
    gw = MicroserviceGateway(registry=ServiceRegistry());
    gw.base_path = project_root;
    gw.client_dist_dir = dist;
    gw.static_mounts = [{"url_prefix": "static", "local_path": shadow_mount}];
    return gw;
}


test "project /static asset resolves even when a static mount claims the prefix" {
    project_root = tempfile.mkdtemp();
    os.makedirs(os.path.join(project_root, "assets"), exist_ok=True);
    with open(os.path.join(project_root, "assets", "logo.svg"), "w") as f {
        f.write("<svg></svg>");
    }

    shadow_mount = tempfile.mkdtemp();
    empty_dist = tempfile.mkdtemp();

    gw = _make_gateway(project_root, shadow_mount, empty_dist);
    # assets/logo.svg is served at /static/logo.svg (exact relative path); the old
    # /static/assets/logo.svg only ever resolved via basename flattening, which the
    # shared resolver removes (I5). #7020's intent — a static mount claiming the
    # prefix must not shadow a real project asset — is unchanged.
    resp = gw.handle_static(_get_request(), "/static/logo.svg");

    assert resp is not None , "a /static/* project asset must still resolve when a static mount "
    "claims the 'static' prefix but lacks the file (#7020)";
    assert resp.status_code == 200;
}


test "a genuinely missing /static asset still 404s (no false-positive serving)" {
    project_root = tempfile.mkdtemp();
    os.makedirs(os.path.join(project_root, "assets"), exist_ok=True);
    shadow_mount = tempfile.mkdtemp();
    empty_dist = tempfile.mkdtemp();

    gw = _make_gateway(project_root, shadow_mount, empty_dist);
    resp = gw.handle_static(_get_request(), "/static/assets/does-not-exist.svg");

    assert resp is None , "a missing asset must not be served by the fallback path";
}


test "public/ asset is served at the web root like vite and next serve it (#8124)" {
    project_root = tempfile.mkdtemp();
    brand_dir = os.path.join(project_root, "public", "brand");
    os.makedirs(brand_dir, exist_ok=True);
    with open(os.path.join(brand_dir, "logo.png"), "wb") as f {
        f.write(b"PNG_DATA");
    }
    empty_dist = tempfile.mkdtemp();

    gw = MicroserviceGateway(registry=ServiceRegistry());
    gw.base_path = project_root;
    gw.client_dist_dir = empty_dist;

    import from jaclang.runtimelib.serving.datatypes { URL }
    req = Request(method="GET", url=URL(path="/brand/logo.png"));
    resp = gw.handle_static(req, "/brand/logo.png");

    assert resp is not None , "public/brand/logo.png must be reachable at /brand/logo.png (the amplify bug #6876)";
    assert resp.status_code == 200;
    assert resp.body_bytes() == b"PNG_DATA";
}
