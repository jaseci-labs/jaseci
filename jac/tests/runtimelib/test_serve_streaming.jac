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
         'def:pub item_jid -> str {\n'
         '    return jid([root-->][?:Item][0]);\n'
         '}\n'
         'def:pub stream_by_jid(node_id: str) -> Generator[dict, None, None] {\n'
         '    yield {"found": jobj(node_id) is not None};\n'
         '}\n'
         'def stream_private -> Generator[dict, None, None] {\n'
         '    yield {"count": len([root-->][?:Item])};\n'
         '}\n'
     ),
     ASYNC_STREAM_APP: str = (
         'import asyncio;\n'
         'import from typing { AsyncGenerator }\n'
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
         'async def:pub count_async_streamed -> AsyncGenerator[dict, None] {\n'
         '    yield {"count": len([root-->][?:Item])};\n'
         '    await asyncio.sleep(0);\n'
         '    root ++> Item(v=42);\n'
         '    yield {"count": len([root-->][?:Item])};\n'
         '}\n'
     ),
     FAILING_STREAM_APP: str = (
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

"""Pushing the caller's context is what puts the caller's principal in front of
the access checks, so a streamed body must see only the caller's graph: another
user's stream counts zero, and a foreign node looked up by jid resolves to
nothing, for a second registered user and for the guest root alike."""
test "a streamed body sees only the caller's graph" {
    with TemporaryDirectory() as tmp {
        app = Path(tmp) / "stream_root_app.jac";
        app.write_text(ROOT_STREAM_APP);
        client = JacTestClient.from_file(str(app), base_path=tmp);
        try {
            assert client.register_user("stream_owner", "pw12345").ok;
            seeded = client.post("/function/seed", json={});
            assert seeded.status_code == 200 , f"seed failed: {seeded.text}";
            node_id = client.post("/function/item_jid", json={}).json()["data"][
                "result"
            ];
            owner_stream = client.post("/function/count_streamed", json={});
            assert 'data: {"count": 1}' in owner_stream.text , f"owner: {owner_stream.text}";
            owner_ref = client.post(
                "/function/stream_by_jid", json={"node_id": node_id}
            );
            assert 'data: {"found": true}' in owner_ref.text , f"owner by jid: {owner_ref.text}";

            client.clear_auth();
            assert client.register_user("stream_other", "pw12345").ok;
            other = client.post("/function/count_streamed", json={});
            assert other.status_code == 200 , f"other user: {other.text}";
            assert 'data: {"count": 0}' in other.text , f"other user saw a foreign graph: {other.text}";
            assert 'data: {"count": 1}' not in other.text , f"other user saw a foreign graph: {other.text}";
            other_ref = client.post(
                "/function/stream_by_jid", json={"node_id": node_id}
            );
            assert 'data: {"found": false}' in other_ref.text , f"other user read a foreign node by jid: {other_ref.text}";

            client.clear_auth();
            guest = client.post("/function/count_streamed", json={});
            assert guest.status_code == 200 , f"guest: {guest.text}";
            assert 'data: {"count": 0}' in guest.text , f"guest saw a foreign graph: {guest.text}";
            guest_ref = client.post(
                "/function/stream_by_jid", json={"node_id": node_id}
            );
            assert 'data: {"found": false}' in guest_ref.text , f"guest read a foreign node by jid: {guest_ref.text}";
        } finally {
            client.close();
        }
    }
}

test "a non-public streaming function without a token is refused before any bytes" {
    with TemporaryDirectory() as tmp {
        app = Path(tmp) / "stream_root_app.jac";
        app.write_text(ROOT_STREAM_APP);
        client = JacTestClient.from_file(str(app), base_path=tmp);
        try {
            refused = client.post("/function/stream_private", json={});
            assert refused.status_code == 401 , f"expected 401, got {refused.status_code}: {refused.text}";
            assert "data:" not in refused.text , f"bytes were streamed to an unauthenticated caller: {refused.text}";
            assert "text/event-stream" not in refused.headers.get("Content-Type", "");

            assert client.register_user("stream_member", "pw12345").ok;
            client.post("/function/seed", json={});
            allowed = client.post("/function/stream_private", json={});
            assert allowed.status_code == 200 , f"authenticated stream: {allowed.text}";
            assert 'data: {"count": 1}' in allowed.text , f"got: {allowed.text}";
            assert "event: end" in allowed.text;
        } finally {
            client.close();
        }
    }
}

"""An `async def:pub` generator takes the async wrapper: each pull runs under
the caller's context on the loop, and the stream's writes commit when it is
exhausted, the same contract as the threaded sync wrapper."""
test "async generator streams under the caller's root and commits on completion" {
    with TemporaryDirectory() as tmp {
        app = Path(tmp) / "async_stream_app.jac";
        app.write_text(ASYNC_STREAM_APP);
        client = JacTestClient.from_file(str(app), base_path=tmp);
        try {
            seeded = client.post("/function/seed", json={});
            assert seeded.status_code == 200 , f"seed failed: {seeded.text}";
            streamed = client.post("/function/count_async_streamed", json={});
            assert streamed.status_code == 200 , f"async stream: {streamed.text}";
            assert "text/event-stream" in streamed.headers.get("Content-Type", "");
            assert 'data: {"count": 1}' in streamed.text , f"got: {streamed.text}";
            assert 'data: {"count": 2}' in streamed.text , f"got: {streamed.text}";
            assert 'data: {"count": 0}' not in streamed.text , f"got: {streamed.text}";
            assert "event: end" in streamed.text , f"got: {streamed.text}";
            after = client.post("/function/count_direct", json={});
            assert after.json()["data"]["result"] == 2 , f"async stream's write was not committed: {after.text}";
        } finally {
            client.close();
        }
    }
}
