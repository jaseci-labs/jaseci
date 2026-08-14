"""Client-disconnect errors must not escape the connection handler.

When a client reloads, navigates away, or closes the tab mid-response, the
socket drops while the server is still reading or writing. The serving core's
connection handler absorbs ConnectionError/IncompleteReadError quietly; a
routine disconnect must never take down the server or poison the accept loop.

This drives the real asyncio server: a peer connects, sends a partial request,
and hangs up abruptly (RST via SO_LINGER 0). The server must keep answering
subsequent requests as if nothing happened.
"""

import json;
import socket;
import struct;
import time;
import urllib.request;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang { JacRuntime as Jac }
import from jaclang.runtimelib.serving.app { ServingApp }
import from jaclang.runtimelib.serving.endpoint { HTTPMethod, JEndPoint }
import from jaclang.runtimelib.serving.server { ServingServer }
import from jaclang.runtimelib.testing { JacTestClient }

def _ping -> dict {
    return {"ok": True};
}

def _recv_until(sock: any, marker: bytes, deadline_s: float = 5.0) -> bytes {
    buf = b"";
    end = time.monotonic() + deadline_s;
    while marker not in buf and time.monotonic() < end {
        try {
            chunk = sock.recv(4096);
        } except socket.timeout {
            continue;
        }
        if not chunk {
            break;
        }
        buf += chunk;
    }
    return buf;
}

test "mid-stream disconnect releases the stream and the server keeps serving" {
    with TemporaryDirectory() as tmp {
        app_file = Path(tmp) / "disconnect_stream_app.jac";
        app_file.write_text(
            'import time;\n'
            'import from typing { Generator }\n'
            'def:pub slow_stream -> Generator[dict, None, None] {\n'
            '    for i in range(20) {\n'
            '        yield {"n": i};\n'
            '        time.sleep(0.05);\n'
            '    }\n'
            '}\n'
        );
        client = JacTestClient.from_file(str(app_file), base_path=tmp);
        try {
            warm = client.post("/function/slow_stream", json={});
            assert warm.status_code == 200 , f"warmup failed: {warm.text}";
            session = Jac.get_context().mem;
            baseline_units = session._active_units;
            server = ServingServer(app=client._app, host='127.0.0.1', port=0);
            stop = server.serve_background();
            try {
                sock = socket.create_connection(
                    ('127.0.0.1', server.bound_port), timeout=5
                );
                sock.settimeout(1.0);
                sock.setsockopt(
                    socket.SOL_SOCKET, socket.SO_LINGER, struct.pack('ii', 1, 0)
                );
                sock.sendall(
                    b"POST /function/slow_stream HTTP/1.1\r\n"
                    b"Host: x\r\n"
                    b"Content-Type: application/json\r\n"
                    b"Content-Length: 2\r\n\r\n{}"
                );
                head = _recv_until(sock, b'"n": 0');
                assert b'"n": 0' in head , f"no first SSE chunk: {head}";
                sock.close();
                deadline = time.monotonic() + 5.0;
                while session._active_units > baseline_units
                    and time.monotonic() < deadline {
                    time.sleep(0.05);
                }
                assert session._active_units == baseline_units , "stream unit still held after client disconnect";
                resp = urllib.request.urlopen(
                    f"http://127.0.0.1:{server.bound_port}/healthz", timeout=5
                );
                assert resp.status == 200 , "server stopped serving after disconnect";
                again = client.post("/function/slow_stream", json={});
                assert again.status_code == 200 , f"stream broken: {again.text}";
                assert 'data: {"n": 0}' in again.text;
                assert "event: end" in again.text;
            } finally {
                stop();
            }
        } finally {
            client.close();
        }
    }
}

test "abrupt client disconnects are absorbed by the connection handler" {
    app = ServingApp();
    app.add_endpoint(JEndPoint(method=HTTPMethod.GET, path='/ping', callback=_ping));
    server = ServingServer(app=app, host='127.0.0.1', port=0);
    stop = server.serve_background();
    try {
        for _ in range(3) {
            sock = socket.create_connection(
                ('127.0.0.1', server.bound_port), timeout=5
            );
            sock.setsockopt(
                socket.SOL_SOCKET, socket.SO_LINGER, struct.pack('ii', 1, 0)
            );
            sock.sendall(b"GET /ping HTTP/1.1\r\nHost: x\r\nConte");
            sock.close();
        }
        resp = urllib.request.urlopen(
            f"http://127.0.0.1:{server.bound_port}/ping", timeout=5
        );
        body = json.loads(resp.read());
        assert resp.status == 200;
        assert body == {"ok": True} , "server stopped serving after client disconnects";
    } finally {
        stop();
    }
}
