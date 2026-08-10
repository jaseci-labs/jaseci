import from jaclang.scale.runtime.routing {
    guard_route_name,
    is_reserved,
    resolve_routes,
    GATEWAY_API_SEGMENTS,
    GATEWAY_WELLKNOWN_SEGMENTS,
    GATEWAY_CLIENT_SEGMENT
}
import from jaclang.scale.runtime.gateway.dispatch { is_gateway_owned }


test "a service named cl is rejected instead of silently shadowed" {
    caught = False;
    try {
        guard_route_name("cl");
    } except ValueError {
        caught = True;
    }
    assert caught;
}


test "the _app suffix does not evade the reserved guard" {
    caught = False;
    try {
        guard_route_name("cl_app");
    } except ValueError {
        caught = True;
    }
    assert caught;
}


test "every gateway-owned segment is reserved as a route name" {
    for seg in GATEWAY_API_SEGMENTS {
        assert is_reserved(seg);
    }
    for seg in GATEWAY_WELLKNOWN_SEGMENTS {
        assert is_reserved(seg);
    }
    assert is_reserved(GATEWAY_CLIENT_SEGMENT);
}


test "a user-supplied prefix under a gateway segment is rejected" {
    caught = False;
    try {
        resolve_routes({"routes": {"myapp": "/admin"}});
    } except ValueError {
        caught = True;
    }
    assert caught;
}


test "a nested prefix under a gateway segment is rejected" {
    caught = False;
    try {
        resolve_routes({"routes": {"myapp": "user/panel"}});
    } except ValueError {
        caught = True;
    }
    assert caught;
}


test "two services resolving to the same prefix are rejected" {
    caught = False;
    try {
        resolve_routes({"routes": {"a": "/shop", "b": "shop"}});
    } except ValueError {
        caught = True;
    }
    assert caught;
}


test "valid routes still resolve with derived and normalized prefixes" {
    routes = resolve_routes({"routes": {"orders": "", "billing": "pay"}});
    assert routes == {"orders": "/orders", "billing": "/pay"};
}


test "the dispatch tables derive from the same source the guard reads" {
    assert is_gateway_owned("/healthz/ready");
    assert is_gateway_owned("/openapi.json");
    assert is_gateway_owned("/user/login");
}
