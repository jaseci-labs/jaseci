"""Server-Sent Events streaming for generator-returning `def:pub` endpoints.

A `def:pub` function whose result is a generator (e.g. `-> Iterator[dict]`, the
shape used by `jac ai --ui`'s `agent_stream`) is a stream, not a single value.
The JSON transport cannot encode a generator -- it raised "Object of type
generator is not JSON serializable" -- so the base server must instead emit each
yielded item as a canonical `data: {json}\n\n` SSE frame, terminated by
`event: end`. This guards that path end to end through JacTestClient (no socket).
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtimelib.testing { JacTestClient }

glob ROOT_STREAM_APP: str = (
         'import from typing { Generator }\n'
         'node Item {\n'
         '    has v: int = 0;\n'
         '}\n'
         'def:pub seed -> int {\n'
         '    root ++> Item(v=1);\n'
         '    return len([root-->][?:Item]);\n'
         '}\n'
         'def:pub count_direct -> int {\n'
         '    return len([root-->][?:Item]);\n'
         '}\n'
         'def:pub count_streamed -> Generator[dict, None, None] {\n'
         '    yield {"count": len([root-->][?:Item])};\n'
         '    yield {"count": len([root-->][?:Item])};\n'
         '}\n'
         'def:pub write_streamed -> Generator[dict, None, None] {\n'
         '    yield {"phase": "start"};\n'
         '    root ++> Item(v=99);\n'
         '    yield {"phase": "wrote"};\n'
         '}\n'
         'def count_gen -> Generator[dict, None, None] {\n'
         '    yield {"count": len([root-->][?:Item])};\n'
         '}\n'
         'walker:pub CountStream {\n'
         '    can go with Root entry {\n'
         '        report count_gen();\n'
         '    }\n'
         '}\n'
     );

glob FAILING_STREAM_APP: str = (
         'import from typing { Generator }\n'
         'def:pub failing_stream -> Generator[dict, None, None] {\n'
         '    yield {"n": 0};\n'
         '    raise RuntimeError("boom after first item");\n'
         '}\n'
     );

test "streamed generator reads the caller's graph, not an empty root" {
    with TemporaryDirectory() as tmp {
        app = Path(tmp) / "stream_root_app.jac";
        app.write_text(ROOT_STREAM_APP);
        client = JacTestClient.from_file(str(app), base_path=tmp);
        try {
            seeded = client.post("/function/seed", json={});
            assert seeded.status_code == 200 , f"seed failed: {seeded.text}";
            direct = client.post("/function/count_direct", json={});
            assert direct.json()["data"]["result"] == 1 , f"direct: {direct.text}";
            streamed = client.post("/function/count_streamed", json={});
            assert streamed.status_code == 200 , f"stream: {streamed.text}";
            assert "text/event-stream" in streamed.headers.get("Content-Type", "");
            assert 'data: {"count": 1}' in streamed.text , f"got: {streamed.text}";
            assert 'data: {"count": 0}' not in streamed.text , f"got: {streamed.text}";
            assert "event: end" in streamed.text;
        } finally {
            client.close();
        }
    }
}

test "writes made after a yield are committed when the stream completes" {
    with TemporaryDirectory() as tmp {
        app = Path(tmp) / "stream_root_app.jac";
        app.write_text(ROOT_STREAM_APP);
        client = JacTestClient.from_file(str(app), base_path=tmp);
        try {
            client.post("/function/seed", json={});
            wrote = client.post("/function/write_streamed", json={});
            assert wrote.status_code == 200 , f"write stream: {wrote.text}";
            assert "event: end" in wrote.text , f"got: {wrote.text}";
            after = client.post("/function/count_direct", json={});
            assert after.json()["data"]["result"] == 2 , f"after: {after.text}";
        } finally {
            client.close();
        }
    }
}

test "walker reporting a generator streams under the caller's root" {
    with TemporaryDirectory() as tmp {
        app = Path(tmp) / "stream_root_app.jac";
        app.write_text(ROOT_STREAM_APP);
        client = JacTestClient.from_file(str(app), base_path=tmp);
        try {
            client.post("/function/seed", json={});
            streamed = client.post("/walker/CountStream", json={});
            assert streamed.status_code == 200 , f"walker stream: {streamed.text}";
            assert "text/event-stream" in streamed.headers.get("Content-Type", "");
            assert 'data: {"count": 1}' in streamed.text , f"got: {streamed.text}";
            assert "event: end" in streamed.text;
        } finally {
            client.close();
        }
    }
}

test "a producer that fails after a yield surfaces a framed error, not a dropped stream" {
    with TemporaryDirectory() as tmp {
        app = Path(tmp) / "failing_stream_app.jac";
        app.write_text(FAILING_STREAM_APP);
        client = JacTestClient.from_file(str(app), base_path=tmp);
        try {
            resp = client.post("/function/failing_stream", json={});
            assert resp.status_code == 200 , f"failing stream: {resp.text}";
            assert 'data: {"n": 0}' in resp.text , f"got: {resp.text}";
            assert "event: error" in resp.text , f"got: {resp.text}";
            assert '"error_type": "RuntimeError"' in resp.text , f"got: {resp.text}";
            assert "boom after first item" in resp.text , f"got: {resp.text}";
            assert "event: end" not in resp.text , f"got: {resp.text}";
        } finally {
            client.close();
        }
    }
}

test "function returning an iterator streams as SSE instead of crashing" {
    with TemporaryDirectory() as tmp {
        app = Path(tmp) / "stream_app.jac";
        app.write_text(
            'import from typing { Iterator }\n'
            'def:pub stream_numbers -> Iterator[dict] {\n'
            '    for i in range(3) {\n'
            '        yield {"n": i};\n'
            '    }\n'
            '}\n'
        );
        client = JacTestClient.from_file(str(app), base_path=tmp);
        try {
            resp = client.post("/function/stream_numbers", json={});
            # Streamed, not JSON-enveloped: SSE content type + per-item frames.
            assert resp.status_code == 200 , f"status {resp.status_code}: {resp.text}";
            assert "text/event-stream" in resp.headers.get("Content-Type", "");
            assert 'data: {"n": 0}' in resp.text;
            assert 'data: {"n": 1}' in resp.text;
            assert 'data: {"n": 2}' in resp.text;
            # Clean terminator, and crucially NOT the pre-fix crash.
            assert "event: end" in resp.text;
            assert "not JSON serializable" not in resp.text;
        } finally {
            client.close();
        }
    }
}
