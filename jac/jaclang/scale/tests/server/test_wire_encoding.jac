"""gzip negotiation is a policy step in the serving transport.

The bytes of a response only exist inside `ServingServer._write_response`, so
that is where `Content-Encoding` is decided, for `jac serve`, scale services,
and both gateways alike. These tests speak raw HTTP to an in-process server
and check the contract on the wire: what is compressed, what is left alone,
which headers travel with it, and that a streamed frame is not held back until
the generator ends.
"""

import asyncio;
import gzip;
import http.client;
import json;
import time;
import zlib;
import from jaclang.server.serving.app { ServingApp }
import from jaclang.server.serving.datatypes {
    JSONResponse,
    Response,
    StreamingResponse
}
import from jaclang.server.serving.encoding {
    EncodingPolicy,
    accepts_gzip,
    is_compressible_type,
    nginx_gzip_types
}
import from jaclang.server.serving.endpoint { HTTPMethod, JEndPoint }
import from jaclang.server.serving.server { ServingServer }


glob ROWS: list[dict] = [
         {"id": i, "title": f"task {i}", "status": "open", "owner": "someone"}
         for i in range(200)
     ],
     ROWS_JSON: bytes = json.dumps(ROWS).encode("utf-8"),
     GZIP: dict[str, str] = {"Accept-Encoding": "gzip"};


def _app -> ServingApp {
    def big -> Response {
        return JSONResponse(content=ROWS);
    }

    def small -> Response {
        return JSONResponse(content={"ok": True});
    }

    def no_transform -> Response {
        return Response(
            content=ROWS_JSON,
            media_type="application/json",
            headers={"Cache-Control": "no-transform"}
        );
    }

    def pre_encoded -> Response {
        return Response(
            content=gzip.compress(ROWS_JSON, mtime=0),
            media_type="application/json",
            headers={"Content-Encoding": "gzip"}
        );
    }

    def vary_origin -> Response {
        return JSONResponse(content=ROWS, headers={"Vary": "Origin"});
    }

    def own_length -> Response {
        return Response(
            content=ROWS_JSON,
            media_type="application/json",
            headers={"Content-Length": str(len(ROWS_JSON))}
        );
    }

    def png -> Response {
        return Response(content=b"\x89PNG" * 1000, media_type="image/png");
    }

    def sse -> Response {
        async def frames -> any {
            yield "data: first\n\n";
            await asyncio.sleep(0.8);
            yield "data: second\n\n";
        }
        return StreamingResponse(frames(), media_type="text/event-stream");
    }

    def stream_big -> Response {
        async def chunks -> any {
            for _ in range(16) {
                yield b"x" * 4096;
            }
        }
        return StreamingResponse(chunks(), media_type="text/plain");
    }

    def stream_sync -> Response {
        def chunks -> any {
            for i in range(50) {
                yield f"line {i}\n";
            }
        }
        return StreamingResponse(chunks(), media_type="text/plain");
    }
    app = ServingApp();
    for (path, cb) in [
        ("/big", big),
        ("/small", small),
        ("/no-transform", no_transform),
        ("/pre-encoded", pre_encoded),
        ("/vary", vary_origin),
        ("/own-length", own_length),
        ("/png", png),
        ("/sse", sse),
        ("/stream-big", stream_big),
        ("/stream-sync", stream_sync)
    ] {
        app.add_endpoint(JEndPoint(method=HTTPMethod.GET, path=path, callback=cb));
    }
    return app;
}


def _serve(policy: EncodingPolicy | None = None) -> ServingServer {
    server = ServingServer(
        app=_app(), host="127.0.0.1", port=0, encoding=policy or EncodingPolicy()
    );
    server.serve_background();
    assert server.bound_port , "test server did not bind";
    return server;
}


"""(status, {lower-name: value}, [(lower-name, value)...], body)."""
def _raw(
    port: int, path: str, headers: dict[str, str] | None = None, method: str = "GET"
) -> tuple {
    conn = http.client.HTTPConnection("127.0.0.1", port, timeout=10);
    conn.request(method, path, headers=headers or {});
    resp = conn.getresponse();
    body = resp.read();
    pairs = [(k.lower(), v) for (k, v) in resp.getheaders()];
    conn.close();
    return (resp.status, dict(pairs), pairs, body);
}


def _count(pairs: list, name: str) -> int {
    return len(
        [
            1
            for (k, _v) in pairs
            if k == name
        ]
    );
}


test "a JSON body over min_bytes is gzipped when the client accepts it" {
    server = _serve();
    try {
        (status, headers, pairs, body) = _raw(server.bound_port, "/big", GZIP);
        assert status == 200;
        assert headers.get("content-encoding") == "gzip" , headers;
        assert headers.get("vary") == "Accept-Encoding" , headers;
        assert gzip.decompress(body) == ROWS_JSON;
        assert len(body) < len(ROWS_JSON) // 4;
        assert headers.get("content-length") == str(len(body));
        assert _count(pairs, "content-length") == 1;
    } finally {
        server.request_stop();
    }
}


test "the same body is identity when the client does not ask, and still varies" {
    server = _serve();
    try {
        (status, headers, _pairs, body) = _raw(server.bound_port, "/big");
        assert status == 200;
        assert "content-encoding" not in headers , headers;
        assert headers.get("vary") == "Accept-Encoding" , (
            "a shared cache must key on Accept-Encoding for the identity answer "
            f"too, or it hands a gzip body to an identity client: {headers}"
        );
        assert body == ROWS_JSON;
    } finally {
        server.request_stop();
    }
}


test "gzip;q=0 is a refusal, not a request" {
    server = _serve();
    try {
        (_s, headers, _p, body) = _raw(
            server.bound_port, "/big", {"Accept-Encoding": "gzip;q=0, identity"}
        );
        assert "content-encoding" not in headers , headers;
        assert body == ROWS_JSON;
    } finally {
        server.request_stop();
    }
}


test "a body under min_bytes goes out as-is" {
    server = _serve();
    try {
        (_s, headers, _p, body) = _raw(server.bound_port, "/small", GZIP);
        assert "content-encoding" not in headers , headers;
        assert json.loads(body) == {"ok": True};
        assert headers.get("vary") == "Accept-Encoding";
    } finally {
        server.request_stop();
    }
}


test "HEAD is never compressed" {
    server = _serve();
    try {
        (status, headers, _p, body) = _raw(
            server.bound_port, "/big", GZIP, method="HEAD"
        );
        assert status == 200;
        assert "content-encoding" not in headers , headers;
        assert headers.get("content-length") == str(len(ROWS_JSON));
        assert body == b"";
    } finally {
        server.request_stop();
    }
}


test "Cache-Control: no-transform is honored" {
    server = _serve();
    try {
        (_s, headers, _p, body) = _raw(server.bound_port, "/no-transform", GZIP);
        assert "content-encoding" not in headers , headers;
        assert body == ROWS_JSON;
    } finally {
        server.request_stop();
    }
}


test "a body that already carries Content-Encoding passes through untouched" {
    server = _serve();
    try {
        (_s, headers, pairs, body) = _raw(server.bound_port, "/pre-encoded", GZIP);
        assert headers.get("content-encoding") == "gzip";
        assert _count(pairs, "content-encoding") == 1 , pairs;
        assert body == gzip.compress(ROWS_JSON, mtime=0) , (
            "a proxied upstream gzip body must not be compressed a second time"
        );
        assert "vary" not in headers , (
            f"the transport made no encoding decision here: {headers}"
        );
    } finally {
        server.request_stop();
    }
}


test "Vary merges with the handler's own value instead of replacing it" {
    server = _serve();
    try {
        (_s, headers, pairs, _b) = _raw(server.bound_port, "/vary", GZIP);
        assert _count(pairs, "vary") == 1 , pairs;
        assert headers.get("vary") == "Origin, Accept-Encoding" , headers;
    } finally {
        server.request_stop();
    }
}


test "a handler's own Content-Length is replaced, not sent twice" {
    server = _serve();
    try {
        (_s, headers, pairs, body) = _raw(server.bound_port, "/own-length", GZIP);
        assert headers.get("content-encoding") == "gzip";
        assert _count(pairs, "content-length") == 1 , (
            f"the stale uncompressed length must not go out as a second line: {pairs}"
        );
        assert headers.get("content-length") == str(len(body));
        assert gzip.decompress(body) == ROWS_JSON;
    } finally {
        server.request_stop();
    }
}


test "a non-text media type is not touched and carries no Vary" {
    server = _serve();
    try {
        (_s, headers, _p, body) = _raw(server.bound_port, "/png", GZIP);
        assert "content-encoding" not in headers , headers;
        assert "vary" not in headers , headers;
        assert body == b"\x89PNG" * 1000;
    } finally {
        server.request_stop();
    }
}


test "an SSE frame reaches the client before the generator finishes" {
    server = _serve();
    try {
        conn = http.client.HTTPConnection("127.0.0.1", server.bound_port, timeout=10);
        started = time.monotonic();
        conn.request("GET", "/sse", headers=GZIP);
        resp = conn.getresponse();
        assert resp.status == 200;
        assert resp.getheader("Content-Encoding") == "gzip";
        assert resp.getheader("Transfer-Encoding") == "chunked";
        inflater = zlib.decompressobj(31);
        text = "";
        while "data: first" not in text {
            piece = resp.read1(65536);
            assert piece , "stream ended before the first frame arrived";
            text += inflater.decompress(piece).decode("utf-8");
        }
        first_frame_at = time.monotonic() - started;
        assert first_frame_at < 0.5 , (
            f"the first frame took {first_frame_at:.2f}s: the compressor held it "
            f"back until the generator finished"
        );
        assert "data: second" not in text;
        text += inflater.decompress(resp.read()).decode("utf-8");
        text += inflater.flush().decode("utf-8");
        conn.close();
        assert text == "data: first\n\ndata: second\n\n" , text;
    } finally {
        server.request_stop();
    }
}


test "a streamed body is compressed and reassembles" {
    server = _serve();
    try {
        (status, headers, _p, body) = _raw(server.bound_port, "/stream-big", GZIP);
        assert status == 200;
        assert headers.get("content-encoding") == "gzip";
        assert headers.get("transfer-encoding") == "chunked";
        assert "content-length" not in headers;
        assert len(body) < 4096 , f"16 x 4 KB of 'x' should collapse; got {len(body)}";
        assert gzip.decompress(body) == b"x" * 65536;
    } finally {
        server.request_stop();
    }
}


test "a sync generator stream is compressed too" {
    server = _serve();
    try {
        (_s, headers, _p, body) = _raw(server.bound_port, "/stream-sync", GZIP);
        assert headers.get("content-encoding") == "gzip";
        expected = "".join([f"line {i}\n" for i in range(50)]).encode("utf-8");
        assert gzip.decompress(body) == expected;
    } finally {
        server.request_stop();
    }
}


test "a stream goes out uncompressed when the client does not ask" {
    server = _serve();
    try {
        (_s, headers, _p, body) = _raw(server.bound_port, "/stream-big");
        assert "content-encoding" not in headers;
        assert body == b"x" * 65536;
    } finally {
        server.request_stop();
    }
}


test "a disabled policy answers identity even when asked" {
    server = _serve(EncodingPolicy(enabled=False));
    try {
        (_s, headers, _p, body) = _raw(server.bound_port, "/big", GZIP);
        assert "content-encoding" not in headers , headers;
        assert "vary" not in headers , headers;
        assert body == ROWS_JSON;
    } finally {
        server.request_stop();
    }
}


test "min_bytes is a real threshold" {
    server = _serve(EncodingPolicy(min_bytes=len(ROWS_JSON) + 1));
    try {
        (_s, headers, _p, body) = _raw(server.bound_port, "/big", GZIP);
        assert "content-encoding" not in headers , headers;
        assert body == ROWS_JSON;
    } finally {
        server.request_stop();
    }
}


test "Accept-Encoding parsing" {
    assert accepts_gzip("gzip");
    assert accepts_gzip("gzip, deflate, br");
    assert accepts_gzip("GZIP;q=0.5");
    assert accepts_gzip("*");
    assert accepts_gzip("br;q=1.0, gzip;q=0.8");
    assert not accepts_gzip("");
    assert not accepts_gzip("identity");
    assert not accepts_gzip("gzip;q=0");
    assert not accepts_gzip("gzip;q=0.0, br");
    assert not accepts_gzip("deflate, br");
}


test "compressible media types" {
    assert is_compressible_type("application/json");
    assert is_compressible_type("application/json; charset=utf-8");
    assert is_compressible_type("text/html; charset=utf-8");
    assert is_compressible_type("text/event-stream");
    assert is_compressible_type("text/javascript");
    assert is_compressible_type("application/javascript");
    assert is_compressible_type("image/svg+xml");
    assert is_compressible_type("application/wasm");
    assert is_compressible_type("application/manifest+json");
    assert not is_compressible_type("image/png");
    assert not is_compressible_type("application/octet-stream");
    assert not is_compressible_type("");
}


test "the policy an entry point builds comes from [serve.compression]" {
    import from jaclang.project.config { JacConfig, get_config, set_config }
    import from jaclang.server.serving.encoding { encoding_policy_from_project }
    before = get_config();
    try {
        set_config(
            JacConfig.from_toml_str(
                "\n[serve.compression]\nenabled = false\nmin_bytes = 9\nlevel = 7\n"
            )
        );
        policy = encoding_policy_from_project();
        assert policy.enabled is False;
        assert policy.min_bytes == 9;
        assert policy.level == 7;

        set_config(JacConfig.from_toml_str("\n[project]\nname = \"x\"\n"));
        default_policy = encoding_policy_from_project();
        assert default_policy.enabled is True;
        assert default_policy.min_bytes == 1024;
        assert default_policy.level == 4;
    } finally {
        set_config(before);
    }
}


test "the nginx type list is derived from the same table" {
    types = nginx_gzip_types().split(" ");
    for needed in [
        "text/javascript",
        "text/css",
        "application/json",
        "image/svg+xml",
        "application/wasm",
        "application/manifest+json"
    ] {
        assert needed in types , f"{needed} missing from {types}";
    }
    assert "text/html" not in types , (
        "nginx always compresses text/html and warns when it is listed twice"
    );
}
