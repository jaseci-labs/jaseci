"""Open streams are a declared resource.

Every open stream, sync or async, pins a connection and a request context for
its whole life, and one from a synchronous producer also holds a dedicated
worker thread, so the number open at once must have a ceiling.
`[serve] max_concurrent_streams` is that ceiling: streams under it run side by
side and each completes on its own; a request past it is refused before any
bytes are streamed with a typed 503 `stream_limit`, and the slot comes back the
moment an open stream ends. A negative ceiling is a misconfiguration and falls
back to the default with a warning rather than silently removing the limit.
"""

import json;
import logging;
import socket;
import threading;
import time;
import urllib.error;
import urllib.request;
import from logging.handlers { MemoryHandler }
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.project.config { get_config }
import from jaclang.runtimelib.server { _stream_limit }
import from jaclang.runtimelib.serving.server { ServingServer }
import from jaclang.runtimelib.testing { JacTestClient }

glob TAGGED_STREAM_APP: str = (
         'import time;\n'
         'import from typing { Generator }\n'
         'def:pub tagged_stream(tag: str, count: int = 5) -> Generator[dict, None, None] {\n'
         '    for i in range(count) {\n'
         '        yield {"tag": tag, "n": i};\n'
         '        time.sleep(0.05);\n'
         '    }\n'
         '}\n'
     );

def _post_stream(port: int, tag: str, count: int = 5) -> tuple {
    req = urllib.request.Request(
        f"http://127.0.0.1:{port}/function/tagged_stream",
        data=json.dumps({"tag": tag, "count": count}).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST"
    );
    try {
        resp = urllib.request.urlopen(req, timeout=10);
        return (resp.status, resp.read().decode("utf-8"));
    } except urllib.error.HTTPError as e {
        return (e.code, e.read().decode("utf-8"));
    }
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

def _hold_stream(port: int, tag: str, count: int) -> any {
    sock = socket.create_connection(('127.0.0.1', port), timeout=5);
    sock.settimeout(1.0);
    body = json.dumps({"tag": tag, "count": count}).encode("utf-8");
    sock.sendall(
        b"POST /function/tagged_stream HTTP/1.1\r\n"
        b"Host: x\r\n"
        b"Content-Type: application/json\r\n"
            + f"Content-Length: {len(body)}\r\n\r\n".encode("latin-1")
            + body
    );
    head = _recv_until(sock, b'"n": 0');
    assert b'"n": 0' in head , f"stream {tag} did not start: {head}";
    return sock;
}

test "concurrent streams run side by side and each completes on its own" {
    with TemporaryDirectory() as tmp {
        app_file = Path(tmp) / "tagged_stream_app.jac";
        app_file.write_text(TAGGED_STREAM_APP);
        client = JacTestClient.from_file(str(app_file), base_path=tmp);
        try {
            warm = client.post(
                "/function/tagged_stream", json={"tag": "warm", "count": 1}
            );
            assert warm.status_code == 200 , f"warmup failed: {warm.text}";
            server = ServingServer(app=client._app, host='127.0.0.1', port=0);
            stop = server.serve_background();
            try {
                results: dict = {};

                def _run(tag: str) {
                    results[tag] = _post_stream(server.bound_port, tag, 20);
                }
                threads = [
                    threading.Thread(target=_run, args=(tag, ))
                    for tag in ("a", "b", "c")
                ];
                started = time.monotonic();
                for t in threads {
                    t.start();
                }
                for t in threads {
                    t.join(timeout=15);
                }
                elapsed = time.monotonic() - started;
                for tag in ("a", "b", "c") {
                    (status, text) = results[tag];
                    assert status == 200 , f"stream {tag}: {status} {text}";
                    for i in range(20) {
                        assert f'data: {{"tag": "{tag}", "n": {i}}}' in text , f"stream {tag} missing item {i}: {text}";
                    }
                    others = [
                        o
                        for o in ("a", "b", "c")
                        if o != tag
                    ];
                    for o in others {
                        assert f'"tag": "{o}"' not in text , f"stream {tag} leaked items from {o}";
                    }
                    assert "event: end" in text , f"stream {tag} did not end cleanly: {text}";
                }
                assert elapsed < 2.0 , f"streams serialized behind each other: {elapsed:.2f}s";
            } finally {
                stop();
            }
        } finally {
            client.close();
        }
    }
}

test "a stream past max_concurrent_streams is refused with 503 stream_limit" {
    with TemporaryDirectory() as tmp {
        (Path(tmp) / "jac.toml").write_text("[serve]\nmax_concurrent_streams = 1\n");
        app_file = Path(tmp) / "tagged_stream_app.jac";
        app_file.write_text(TAGGED_STREAM_APP);
        client = JacTestClient.from_file(str(app_file), base_path=tmp);
        try {
            warm = client.post(
                "/function/tagged_stream", json={"tag": "warm", "count": 1}
            );
            assert warm.status_code == 200 , f"warmup failed: {warm.text}";
            cfg = get_config();
            assert cfg is not None and cfg.serve.max_concurrent_streams == 1 , "jac.toml [serve] max_concurrent_streams was not loaded";
            server = ServingServer(app=client._app, host='127.0.0.1', port=0);
            stop = server.serve_background();
            try {
                held = _hold_stream(server.bound_port, "held", 40);
                try {
                    (status, text) = _post_stream(server.bound_port, "over");
                    assert status == 503 , f"expected 503 past the cap, got {status}: {text}";
                    body = json.loads(text);
                    assert body["ok"] is False , text;
                    assert body["error"]["code"] == "STREAM_LIMIT" , text;
                    message: str = str(body["error"]["message"]);
                    assert "stream_limit" in message , text;
                    plain = client.post(
                        "/function/tagged_stream", json={"tag": "x", "count": 1}
                    );
                    assert plain.status_code == 503 , f"in-process path should also refuse: {plain.status_code} {plain.text}";
                } finally {
                    held.close();
                }
                deadline = time.monotonic() + 5.0;
                (status, text) = _post_stream(server.bound_port, "after");
                while status == 503 and time.monotonic() < deadline {
                    time.sleep(0.05);
                    (status, text) = _post_stream(server.bound_port, "after");
                }
                assert status == 200 , f"slot was not released after the held stream closed: {status} {text}";
                assert 'data: {"tag": "after", "n": 4}' in text , text;
                assert "event: end" in text , text;
            } finally {
                stop();
            }
        } finally {
            client.close();
        }
    }
}

test "a negative max_concurrent_streams falls back to the default with a warning" {
    with TemporaryDirectory() as tmp {
        (Path(tmp) / "jac.toml").write_text("[serve]\nmax_concurrent_streams = -1\n");
        app_file = Path(tmp) / "tagged_stream_app.jac";
        app_file.write_text(TAGGED_STREAM_APP);
        client = JacTestClient.from_file(str(app_file), base_path=tmp);
        try {
            warm = client.post(
                "/function/tagged_stream", json={"tag": "warm", "count": 1}
            );
            assert warm.status_code == 200 , f"warmup failed: {warm.text}";
            cfg = get_config();
            assert cfg is not None and cfg.serve.max_concurrent_streams == -1 , "jac.toml [serve] max_concurrent_streams was not loaded";
            capture = MemoryHandler(100);
            serve_logger = logging.getLogger("jaclang.serve");
            prior_disabled = serve_logger.disabled;
            prior_level = serve_logger.level;
            prior_global = logging.root.manager.disable;
            serve_logger.disabled = False;
            serve_logger.setLevel(logging.WARNING);
            logging.disable(logging.NOTSET);
            serve_logger.addHandler(capture);
            try {
                assert _stream_limit() == 1024 , "a negative ceiling must fall back to the default, not remove the limit";
            } finally {
                serve_logger.removeHandler(capture);
                serve_logger.disabled = prior_disabled;
                serve_logger.setLevel(prior_level);
                logging.disable(prior_global);
            }
            messages = [r.getMessage() for r in capture.buffer];
            assert any("max_concurrent_streams" in m and "-1" in m for m in messages) , f"no warning named the bad key: {messages}";
        } finally {
            client.close();
        }
    }
}
