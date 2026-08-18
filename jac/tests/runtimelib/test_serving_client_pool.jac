"""The native HTTP client keeps connections alive and reuses them.

Every proxied gateway call goes through `arequest`, so a client that opens a
fresh socket per request puts a TCP (and TLS) handshake in front of every hop."""

import asyncio;
import from jaclang.runtimelib.serving.client {
    ClientConnectionError,
    arequest,
    close_connection_pool,
    connection_pool
}


glob _RESPONSES: dict[str, bytes] = {
         "/hello": b"HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello",
         "/close": b"HTTP/1.1 200 OK\r\nContent-Length: 5\r\nConnection: close\r\n\r\nclose",
         "/chunked": b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n"
         b"5\r\nalpha\r\n4\r\nbeta\r\n0\r\n\r\n",
         "/nocontent": b"HTTP/1.1 204 No Content\r\n\r\n",
         "/overlong": b"HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhelloEXTRA"
     };


async def _read_request(reader: any) -> (str | None) {
    line: bytes = await reader.readline();
    if not line or line.strip() == b"" {
        return None;
    }
    parts = line.decode("latin-1").strip().split(" ");
    length: int = 0;
    while True {
        raw: bytes = await reader.readline();
        if raw in (b"\r\n", b"\n", b"") {
            break;
        }
        (name, _, value) = raw.decode("latin-1").strip().partition(":");
        if name.strip().lower() == "content-length" {
            length = int(value.strip());
        }
    }
    if length {
        await reader.readexactly(length);
    }
    return parts[1] if len(parts) > 1 else "/";
}


"""A keep-alive HTTP upstream that counts the connections it accepts."""
obj _ProbeUpstream {
    has connections: int = 0,
        port: int = 0,
        drop_next: bool = False,
        _server: any = None,
        _writers: list[any] = [];

    def base -> str {
        return f"http://127.0.0.1:{self.port}";
    }

    async def start {
        start_fn: any = asyncio.start_server;
        self._server = await start_fn(self._handle, host="127.0.0.1", port=0);
        self.port = self._server.sockets[0].getsockname()[1];
    }

    async def stop {
        self._server.close();
        try {
            await asyncio.wait_for(self._server.wait_closed(), timeout=5);
        } except asyncio.TimeoutError {
            ;
        }
    }

    def drop_connections {
        for writer in list(self._writers) {
            try {
                writer.transport.abort();
            } except Exception {
                ;
            }
        }
        self._writers = [];
    }

    async def _handle(reader: any, writer: any) {
        self.connections += 1;
        self._writers.append(writer);
        try {
            while True {
                path = await _read_request(reader);
                if path is None {
                    break;
                }
                if self.drop_next {
                    self.drop_next = False;
                    writer.transport.abort();
                    break;
                }
                writer.write(_RESPONSES.get(path, _RESPONSES["/hello"]));
                await writer.drain();
                if path == "/close" {
                    break;
                }
            }
        } except Exception {
            ;
        }
        try {
            writer.close();
        } except Exception {
            ;
        }
    }
}


def _run(coro: object) -> object {
    loop = asyncio.new_event_loop();
    try {
        return loop.run_until_complete(coro);
    } finally {
        loop.close();
    }
}


def _with_upstream(work: any) -> any {
    async def body -> any {
        upstream = _ProbeUpstream();
        await upstream.start();
        try {
            return await work(upstream);
        } finally {
            close_connection_pool();
            await upstream.stop();
        }
    }
    return _run(body());
}


test "sequential requests share a single pooled connection" {
    async def work(upstream: any) -> dict {
        bodies: list[str] = [];
        for _ in range(3) {
            resp = await arequest("GET", f"{upstream.base()}/hello");
            bodies.append(resp.text());
        }
        return {"bodies": bodies, "connections": upstream.connections};
    }
    result = _with_upstream(work);
    assert result["bodies"] == ["hello", "hello", "hello"];
    assert result["connections"] == 1;
}


test "a drained streaming response hands its connection back to the pool" {
    async def work(upstream: any) -> dict {
        streamed = await arequest("GET", f"{upstream.base()}/chunked", stream=True);
        collected = b"";
        async for chunk in streamed.aiter_raw() {
            collected += chunk;
        }
        await streamed.aclose();
        follow_up = await arequest("GET", f"{upstream.base()}/hello");
        return {
            "streamed": collected.decode("utf-8"),
            "follow_up": follow_up.text(),
            "connections": upstream.connections
        };
    }
    result = _with_upstream(work);
    assert result["streamed"] == "alphabeta";
    assert result["follow_up"] == "hello";
    assert result["connections"] == 1;
}


test "a bodiless response is not read past its head" {
    async def work(upstream: any) -> dict {
        resp = await arequest("GET", f"{upstream.base()}/nocontent");
        follow_up = await arequest("GET", f"{upstream.base()}/hello");
        return {
            "status": resp.status_code,
            "body": resp.body,
            "follow_up": follow_up.text(),
            "connections": upstream.connections
        };
    }
    result = _with_upstream(work);
    assert result["status"] == 204;
    assert result["body"] == b"";
    assert result["follow_up"] == "hello";
    assert result["connections"] == 1;
}


test "a response asking to close is not pooled" {
    async def work(upstream: any) -> dict {
        first = await arequest("GET", f"{upstream.base()}/close");
        second = await arequest("GET", f"{upstream.base()}/hello");
        return {
            "first": first.text(),
            "second": second.text(),
            "connections": upstream.connections
        };
    }
    result = _with_upstream(work);
    assert result["first"] == "close";
    assert result["second"] == "hello";
    assert result["connections"] == 2;
}


test "a pooled connection dropped by the upstream is replaced transparently" {
    async def work(upstream: any) -> dict {
        first = await arequest("GET", f"{upstream.base()}/hello");
        upstream.drop_connections();
        await asyncio.sleep(0.05);
        second = await arequest("GET", f"{upstream.base()}/hello");
        return {
            "first": first.text(),
            "second": second.text(),
            "connections": upstream.connections
        };
    }
    result = _with_upstream(work);
    assert result["first"] == "hello";
    assert result["second"] == "hello";
    assert result["connections"] == 2;
}


test "the pool bounds how many idle connections it keeps per host" {
    async def work(upstream: any) -> int {
        pool = connection_pool();
        pool.max_idle_per_host = 1;
        await asyncio.gather(
            *[arequest("GET", f"{upstream.base()}/hello") for _ in range(3)]
        );
        return pool.idle_count();
    }
    assert _with_upstream(work) == 1;
}


test "a response longer than its content length is not pooled" {
    async def work(upstream: any) -> dict {
        first = await arequest("GET", f"{upstream.base()}/overlong");
        second = await arequest("GET", f"{upstream.base()}/hello");
        return {
            "first": first.text(),
            "second": second.text(),
            "connections": upstream.connections
        };
    }
    result = _with_upstream(work);
    assert result["first"] == "hello";
    assert result["second"] == "hello";
    assert result["connections"] == 2;
}


test "an idempotent request is retried when its pooled connection dies" {
    async def work(upstream: any) -> dict {
        await arequest("GET", f"{upstream.base()}/hello");
        upstream.drop_next = True;
        retried = await arequest("GET", f"{upstream.base()}/hello");
        return {"retried": retried.text(), "connections": upstream.connections};
    }
    result = _with_upstream(work);
    assert result["retried"] == "hello";
    assert result["connections"] == 2;
}


test "a post is not replayed when its pooled connection dies" {
    async def work(upstream: any) -> dict {
        await arequest("GET", f"{upstream.base()}/hello");
        upstream.drop_next = True;
        failed = False;
        try {
            await arequest("POST", f"{upstream.base()}/hello", json_body={"n": 1});
        } except ClientConnectionError {
            failed = True;
        }
        return {"failed": failed, "connections": upstream.connections};
    }
    result = _with_upstream(work);
    assert result["failed"];
    assert result["connections"] == 1;
}
