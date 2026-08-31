"""Request bodies reach handlers as a stream, not as a pre-buffered blob.

The serving core used to read every byte of a request into memory before it
routed anything, so a proxy handler could only ever forward a complete copy.
The body is now handed over as an async chunk stream that the endpoint layer
materialises on demand, which keeps pure forwarders at a constant footprint
while ordinary endpoints still see request.body exactly as before.
"""

import asyncio;
import socket;
import from jaclang.server.serving.app { ServingApp }
import from jaclang.server.serving.datatypes { HTTPError, Request, Response }
import from jaclang.server.serving.endpoint { HTTPMethod, JEndPoint }
import from jaclang.server.serving.server { ServingServer }


def _echo_size(request: Request) -> Response {
    return Response(content=str(len(request.body)), media_type="text/plain");
}


def _build_app -> ServingApp {
    app = ServingApp();
    app.add_endpoint(
        JEndPoint(method=HTTPMethod.POST, path="/sink", callback=_echo_size)
    );
    return app;
}


def _content_length(head: str) -> int {
    for line in head.split("\r\n") {
        if line.lower().startswith("content-length:") {
            return int(line.split(":", 1)[1].strip());
        }
    }
    return 0;
}


def _read_response(sock: any) -> str {
    received = b"";
    while b"\r\n\r\n" not in received {
        part = sock.recv(65536);
        if not part {
            break;
        }
        received += part;
    }
    (head, _, rest) = received.partition(b"\r\n\r\n");
    length = _content_length(head.decode("latin-1"));
    while len(rest) < length {
        part = sock.recv(65536);
        if not part {
            break;
        }
        rest += part;
    }
    return (head + b"\r\n\r\n" + rest).decode("latin-1");
}


def _exchange(port: int, blob: bytes) -> str {
    sock = socket.create_connection(("127.0.0.1", port), timeout=10);
    try {
        sock.sendall(blob);
        return _read_response(sock);
    } finally {
        sock.close();
    }
}


def _post(body: bytes) -> bytes {
    head = (
        f"POST /sink HTTP/1.1\r\nHost: x\r\nContent-Length: {len(body)}\r\n\r\n"
    ).encode(
        "latin-1"
    );
    return head + body;
}


test "a middleware sees an unread stream while the endpoint still sees bytes" {
    seen: dict[str, any] = {};
    app = _build_app();

    async def observe(request: Request, call_next: object) -> Response {
        next_fn: any = call_next;
        seen["buffered"] = len(request.body);
        seen["streaming"] = request.stream is not None;
        return await next_fn(request);
    }
    app.add_middleware(observe);
    server = ServingServer(app=app, host="127.0.0.1", port=0);
    stop = server.serve_background();
    try {
        reply = _exchange(server.bound_port, _post(b"z" * 4096));
    } finally {
        stop();
    }
    assert "200 OK" in reply;
    assert reply.endswith("4096") , reply;
    assert seen["streaming"] , "body was buffered before the endpoint layer";
    assert seen["buffered"] == 0;
}


test "a chunked upload is reassembled for the endpoint" {
    app = _build_app();
    server = ServingServer(app=app, host="127.0.0.1", port=0);
    stop = server.serve_background();
    try {
        frames = b"";
        for _ in range(4) {
            frames += b"400\r\n" + b"q" * 1024 + b"\r\n";
        }
        blob = (
            b"POST /sink HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n"
            + frames
            + b"0\r\n\r\n"
        );
        reply = _exchange(server.bound_port, blob);
    } finally {
        stop();
    }
    assert "200 OK" in reply;
    assert reply.endswith("4096") , reply;
}


test "an oversized Content-Length is refused before the body is read" {
    app = _build_app();
    server = ServingServer(app=app, host="127.0.0.1", port=0, max_body_bytes=1024);
    stop = server.serve_background();
    try {
        blob = b"POST /sink HTTP/1.1\r\nHost: x\r\nContent-Length: 999999\r\n\r\n";
        reply = _exchange(server.bound_port, blob);
    } finally {
        stop();
    }
    assert "413 Payload Too Large" in reply , reply;
}


test "a chunked body that outgrows the cap is refused mid-stream" {
    app = _build_app();
    server = ServingServer(app=app, host="127.0.0.1", port=0, max_body_bytes=1024);
    stop = server.serve_background();
    try {
        blob = (
            b"POST /sink HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n"
            + b"800\r\n"
            + b"q" * 2048
            + b"\r\n0\r\n\r\n"
        );
        reply = _exchange(server.bound_port, blob);
    } finally {
        stop();
    }
    assert "413" in reply , reply;
}


test "a body that stops short of its declared length is a client error" {
    app = _build_app();
    server = ServingServer(app=app, host="127.0.0.1", port=0);
    stop = server.serve_background();
    try {
        sock = socket.create_connection(("127.0.0.1", server.bound_port), timeout=10);
        try {
            sock.sendall(_post(b"z" * 4096)[:-2048]);
            sock.shutdown(socket.SHUT_WR);
            reply = _read_response(sock);
        } finally {
            sock.close();
        }
    } finally {
        stop();
    }
    assert "400 Bad Request" in reply , reply;
}


test "a chunked body drops the Content-Length that contradicts it" {
    seen: dict[str, any] = {};

    def echo_declared(request: Request) -> Response {
        seen["declared"] = request.headers.get("Content-Length");
        return Response(content=str(len(request.body)), media_type="text/plain");
    }
    app = ServingApp();
    app.add_endpoint(
        JEndPoint(method=HTTPMethod.POST, path="/sink", callback=echo_declared)
    );
    server = ServingServer(app=app, host="127.0.0.1", port=0);
    stop = server.serve_background();
    try {
        blob = (
            b"POST /sink HTTP/1.1\r\nHost: x\r\n"
            + b"Content-Length: 8\r\nTransfer-Encoding: chunked\r\n\r\n"
            + b"400\r\n"
            + b"q" * 1024
            + b"\r\n0\r\n\r\n"
        );
        reply = _exchange(server.bound_port, blob);
    } finally {
        stop();
    }
    assert "200 OK" in reply , reply;
    assert reply.endswith("1024") , reply;
    assert seen["declared"] is None , "a stale Content-Length reached the handler";
}


test "an endpoint that cannot reach a downstream still answers 500" {
    def refuse(request: Request) -> Response {
        raise ConnectionRefusedError("downstream is down");
    }
    app = ServingApp();
    app.add_endpoint(JEndPoint(method=HTTPMethod.GET, path="/call", callback=refuse));
    server = ServingServer(app=app, host="127.0.0.1", port=0);
    stop = server.serve_background();
    try {
        blob = b"GET /call HTTP/1.1\r\nHost: x\r\n\r\n";
        reply = _exchange(server.bound_port, blob);
    } finally {
        stop();
    }
    assert "500" in reply , reply;
    assert "ConnectionRefusedError" in reply , reply;
}


test "a body that failed once stays failed and keeps the connection closed" {
    async def failing -> any {
        yield b"partial";
        raise HTTPError(status_code=413, detail="Payload Too Large");
    }

    async def scenario -> dict {
        request = Request(method="POST");
        request.stream = failing();
        first = "";
        try {
            await request.load_body();
        } except HTTPError as he {
            first = str(he.status_code);
        }
        second = "";
        try {
            await request.load_body();
        } except HTTPError as he {
            second = str(he.status_code);
        }
        return {"first": first, "second": second, "unread": request.body_unread()};
    }
    loop = asyncio.new_event_loop();
    try {
        result: dict = loop.run_until_complete(scenario());
    } finally {
        loop.close();
    }
    assert result["first"] == "413" , result;
    assert result["second"] != "" , "a second read silently returned an empty body";
    assert result["unread"] , "a failed body was treated as fully read";
}


test "a request that never finishes its declared body does not pin a connection" {
    app = _build_app();
    server = ServingServer(app=app, host="127.0.0.1", port=0, body_timeout=0.4);
    stop = server.serve_background();
    try {
        sock = socket.create_connection(("127.0.0.1", server.bound_port), timeout=10);
        try {
            sock.sendall(
                b"POST /sink HTTP/1.1\r\nHost: x\r\nContent-Length: 4096\r\n\r\n"
            );
            sock.sendall(b"z" * 8);
            sock.settimeout(10);
            leftover = b"";
            while True {
                part = sock.recv(65536);
                if not part {
                    break;
                }
                leftover += part;
            }
        } finally {
            sock.close();
        }
    } finally {
        stop();
    }
    assert b"500" not in leftover , leftover;
}


test "a body that failed cannot be forwarded as an empty one" {
    async def failing -> any {
        yield b"partial";
        raise HTTPError(status_code=413, detail="Payload Too Large");
    }

    async def scenario -> dict {
        request = Request(method="POST");
        request.stream = failing();
        try {
            await request.load_body();
        } except HTTPError {
            ;
        }
        status = 0;
        try {
            request.body_source();
        } except HTTPError as he {
            status = he.status_code;
        }
        return {"status": status};
    }
    loop = asyncio.new_event_loop();
    try {
        result: dict = loop.run_until_complete(scenario());
    } finally {
        loop.close();
    }
    assert result["status"] == 400 , "a failed body was handed out as a source";
}


test "json() materialises a streamed body instead of reporting nothing" {
    async def parts -> any {
        yield b'{"a":';
        yield b" 1}";
    }

    async def scenario -> any {
        request = Request(method="POST");
        request.stream = parts();
        return await request.json();
    }
    loop = asyncio.new_event_loop();
    try {
        parsed = loop.run_until_complete(scenario());
    } finally {
        loop.close();
    }
    assert parsed == {"a": 1} , parsed;
}


test "keep-alive survives back-to-back requests that carry bodies" {
    app = _build_app();
    server = ServingServer(app=app, host="127.0.0.1", port=0);
    stop = server.serve_background();
    replies: list[str] = [];
    try {
        sock = socket.create_connection(("127.0.0.1", server.bound_port), timeout=10);
        try {
            for size in (16, 32, 64) {
                sock.sendall(_post(b"a" * size));
                replies.append(_read_response(sock));
            }
        } finally {
            sock.close();
        }
    } finally {
        stop();
    }
    assert all(["200 OK" in reply for reply in replies]) , replies;
    assert [reply.split("\r\n\r\n")[1] for reply in replies] == ["16", "32", "64"];
}
