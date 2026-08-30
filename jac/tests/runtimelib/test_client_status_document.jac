"""One status document, one renderer, across every dev-loop channel.

`.jac-dev-status.json` (written by a Vite plugin, holding a `.js` module id)
and `.jac-build-error.json` (written by the hot reloader, holding free text)
are gone. Both are replaced by `.jac/client/.jac-status.json`, whose payload is
`{"status": ..., "diagnostics": [...]}` -- the same shape `/__build_status`
returns on the core and the scale server, and the same diagnostic value the
`/cl/__error__` endpoint logs.
"""

import asyncio;
import io;
import json;
import logging;
import uuid;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.server.hmr { HotReloader, get_build_status }
import from jaclang.server.watcher { JacFileWatcher }
import from jaclang.testing.testing { JacTestClient }

glob FIXTURES = str(Path(__file__).parent / "fixtures");

def _as_any(v: any) -> any {
    return v;
}

def _reloader(base: Path) -> HotReloader {
    watcher = JacFileWatcher(watch_paths=[str(base)], _debounce_ms=50);
    return HotReloader(base_path=str(base), module_name="app", watcher=watcher);
}

test "a real client compile failure becomes a located diagnostic" {
    with TemporaryDirectory() as tmpdir {
        proj = Path(tmpdir) / f"project_{uuid.uuid4().hex[:8]}";
        (proj / ".jac" / "client" / "compiled").mkdir(parents=True);
        app = proj / "app.jac";
        app.write_text("def app() -> any {\n    return <div UNCLOSED;\n}\n");
        reloader = _reloader(proj);
        reloader._recompile_client_code(str(app));

        status = reloader.build_status();
        assert set(status.keys()) == {"status", "diagnostics"} , status;
        assert status["status"] == "error";
        diags = status["diagnostics"];
        assert len(diags) >= 1 , diags;
        first = diags[0];
        assert first["file"].endswith("app.jac") , first["file"];
        assert first["line"] > 0 , first;
        assert first["code"] , "a compile diagnostic must carry the compiler's code";
        assert first["channel"] == "jac" , first["channel"];
        assert "-->" in first["rendered"] , first["rendered"];

        # The status document is the only file written, and it carries the value.
        client_dir = proj / ".jac" / "client";
        doc = client_dir / ".jac-status.json";
        assert doc.exists() , ".jac-status.json was not written";
        stored = json.loads(doc.read_text());
        assert stored["status"] == "error";
        assert stored["diagnostics"][0]["file"].endswith("app.jac");
        assert not (client_dir / ".jac-build-error.json").exists() ,
            ".jac-build-error.json must no longer be written";
        assert not (client_dir / ".jac-dev-status.json").exists() ,
            ".jac-dev-status.json must no longer be written";

        # Recovery empties the document.
        app.write_text("def app() -> any {\n    return <div>ok</div>;\n}\n");
        reloader._recompile_client_code(str(app));
        reloader.record_ok();
        assert reloader.build_status() == {"status": "ok", "diagnostics": []};
        assert not doc.exists() , "a healthy build must leave no status document";
    }
}

test "the hot reloader ignores the retired status files entirely" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        client_dir = proj / ".jac" / "client";
        client_dir.mkdir(parents=True);
        # Every retired file, holding an error each. None may be read.
        (client_dir / ".jac-dev-status.json").write_text(
            json.dumps(
                {"vite": {"message": "stale vite error", "file": ""}, "client": None}
            )
        );
        (client_dir / ".jac-build-error.json").write_text(
            json.dumps({"file": "app.jac", "message": "stale jac error"})
        );
        (client_dir / ".jac-client-events.json").write_text(
            json.dumps({"vite": {"message": "stale event"}, "client": None})
        );
        reloader = _reloader(proj);
        assert reloader.build_status() == {"status": "ok", "diagnostics": []};
    }
}

test "raw client events arrive on the callback and are classified once" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        client_dir = proj / ".jac" / "client";
        (client_dir / "compiled").mkdir(parents=True);
        reloader = _reloader(proj);
        # The plugin forwards RAW payloads only; the Jac process classifies.
        reloader.record_client_event(
            "client",
            {
                "type": "SyntaxError",
                "message": "The requested module '/.vite/deps/left-pad.js?v=1' "
                    "does not provide an export named 'Nope'",
                "stack": "",
                "source": "",
                "phase": "load"
            }
        );
        status = reloader.build_status();
        assert status["status"] == "error";
        diag = status["diagnostics"][0];
        assert diag["code"] == "E7001" , diag;
        assert diag["channel"] == "browser" , diag;
        # Nothing on disk maps it, so the diagnostic must say so and still
        # name an owner rather than an empty file field.
        assert diag["file"] != "" , diag;
        assert diag["unmapped_reason"] != "" , diag;
        # Classification happened on arrival: the status document is already
        # written, and no transport file is left behind.
        assert (client_dir / ".jac-status.json").exists();
        assert not (client_dir / ".jac-client-events.json").exists();
        # The browser's clean-load beacon clears the browser slots.
        reloader.record_client_event("ready", None);
        assert reloader.build_status() == {"status": "ok", "diagnostics": []};
    }
}

test "event slots rank vite over browser, and a jac failure over both" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        (proj / ".jac" / "client" / "compiled").mkdir(parents=True);
        reloader = _reloader(proj);
        reloader.record_client_event(
            "vite",
            {
                "message": 'Failed to resolve import "totally-missing-pkg"',
                "id": "compiled/pages/index.js",
                "plugin": "vite:import-analysis"
            }
        );
        reloader.record_client_event(
            "client", {"message": "load broke", "source": "", "phase": "load"}
        );
        assert reloader.build_status()["diagnostics"][0]["channel"] == "vite";
        reloader.record_error("app.jac", "syntax");
        assert reloader.build_status()["diagnostics"][0]["channel"] == "jac";
        reloader.record_ok();
        assert reloader.build_status()["diagnostics"][0]["channel"] == "vite";
        # A null payload clears the slot the plugin sent it for.
        reloader.record_client_event("vite", None);
        assert reloader.build_status()["diagnostics"][0]["channel"] == "browser";
        reloader.record_client_event("ready", None);
        assert reloader.build_status() == {"status": "ok", "diagnostics": []};
    }
}

test "a post-load runtime event is reported without breaking the build" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        (proj / ".jac" / "client" / "compiled").mkdir(parents=True);
        reloader = _reloader(proj);
        reloader.record_client_event(
            "runtime",
            {"type": "TypeError", "message": "x is not a function", "phase": ""}
        );
        # Reported to the terminal, but the build is not broken by it.
        assert reloader.build_status() == {"status": "ok", "diagnostics": []};
    }
}

test "get_build_status reports the new shape when no reloader is running" {
    assert get_build_status() == {"status": "unavailable", "diagnostics": []};
}

test "the core /__build_status route serves the status document shape" {
    with TemporaryDirectory() as tmp {
        client = JacTestClient.from_file(
            str((Path(FIXTURES) / "serve_api.jac").resolve()), base_path=str(tmp)
        );
        reloader = _reloader(Path(tmp));
        try {
            reloader.start();
            resp = client.get("/__build_status");
            assert resp.ok , resp.status_code;
            body = _as_any(resp.data);
            assert body == {"status": "ok", "diagnostics": []} , body;
            reloader.record_error("app.jac", "boom", line=3, column=5);
            body = _as_any(client.get("/__build_status").data);
            assert body["status"] == "error" , body;
            assert len(body["diagnostics"]) == 1 , body;
            diag = body["diagnostics"][0];
            assert diag["file"] == "app.jac" , diag;
            assert diag["line"] == 3 and diag["column"] == 5 , diag;
            assert diag["rendered"].startswith("error[") , diag["rendered"];
        } finally {
            reloader.stop();
            client.close();
        }
    }
}

obj _CapturedServer {
    has endpoints: list = [];

    def add_endpoint(ep: any) -> None {
        self.endpoints.append(ep);
    }
}

obj _CoreStub {
    has server: any;
}

test "the scale /__build_status route serves the same status document shape" {
    import from jaclang.scale.server.serve { JacAPIServerCore }
    with TemporaryDirectory() as tmp {
        stub = _CoreStub(server=_CapturedServer());
        JacAPIServerCore.register_build_status_endpoint(stub);
        assert len(stub.server.endpoints) == 1;
        ep = stub.server.endpoints[0];
        assert ep.path == "/__build_status";
        body = asyncio.run(ep.callback());
        assert body == {"status": "unavailable", "diagnostics": []} , body;
        reloader = _reloader(Path(tmp));
        try {
            reloader.start();
            reloader.record_error("main.jac", "boom");
            body = asyncio.run(ep.callback());
            assert body["status"] == "error" , body;
            assert body["diagnostics"][0]["file"] == "main.jac" , body;
        } finally {
            reloader.stop();
        }
    }
}

test "the /cl/__error__ endpoint logs a rendered diagnostic with a Jac location" {
    import from jaclang.client.source_mapping { _error_rate_limiter }
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        compiled = proj / ".jac" / "client" / "compiled";
        compiled.mkdir(parents=True);
        src = proj / "app.jac";
        src.write_text(
            "def:pub app() -> any {\n    marker = 1;\n    return marker;\n}\n"
        );
        # A minimal compiled artifact plus a segment map, standing in for a
        # client build: the endpoint must resolve the frame through it.
        (compiled / "app.js").write_text(
            f"/* Source: {src} */\nfunction app() {{\n  let marker = 1;\n"
            "  return marker;\n}\nexport {app};\n"
        );
        (compiled / "app.js.map").write_text(
            json.dumps(
                {
                    "version": 3,
                    "file": "app.js",
                    "sources": [str(src)],
                    "names": ["marker"],
                    "mappings": ";;EACIA"
                }
            )
        );
        buf = io.StringIO();
        sink = logging.StreamHandler(buf);
        logger = logging.getLogger("jaclang.client_errors");
        logger.addHandler(sink);
        _error_rate_limiter._seen = {};
        _error_rate_limiter._count = 0;
        client = JacTestClient.from_file(
            str((Path(FIXTURES) / "serve_api.jac").resolve()), base_path=str(proj)
        );
        try {
            resp = client.post(
                "/cl/__error__",
                json={
                    "message": "marker is not a function",
                    "stack": "TypeError: marker is not a function\n"
                        "    at app (http://localhost:8000/compiled/app.js:3:4)",
                    "url": "http://localhost:8000/",
                    "source": "http://localhost:8000/compiled/app.js"
                }
            );
            assert resp.ok , resp.status_code;
            sink.flush();
            logged = buf.getvalue();
            assert "error[E7003]" in logged , logged;
            assert "--> app.jac:2" in logged , logged;
        } finally {
            logger.removeHandler(sink);
            client.close();
        }
    }
}


obj _FakeStream {
    has lines: list[str] = [],
        _at: int = 0;

    def readline -> str {
        if self._at >= len(self.lines) {
            return "";
        }
        self._at += 1;
        return self.lines[self._at - 1];
    }
}

obj _FakeProc {
    has stdout: any;
}

obj _FakeOut {
    has written: list[str] = [];

    def write(text: str) -> None {
        self.written.append(text);
    }

    def flush -> None { }
}

obj _FakeSys {
    has stdout: any;
}

test "a tagged stdout line reaches the callback and is never echoed" {
    import json;
    import threading;
    import from jaclang.client.vite_bundler {
        ViteBundler,
        _forward_vite_output,
        CLIENT_EVENT_PREFIX
    }
    with TemporaryDirectory() as tmp {
        seen: list = [];
        bundler = ViteBundler(Path(tmp));
        bundler.on_client_event = lambda (slot: str, payload: any) {
            seen.append((slot, payload));
        };
        tagged = CLIENT_EVENT_PREFIX + json.dumps(
            {"slot": "vite", "payload": {"message": "boom", "id": "compiled/x.js"}}
        ) + "\n";
        stream = _FakeStream(
            lines=[
                "  VITE v5.0.0  ready in 120 ms\n",
                tagged,
                "some ordinary vite chatter\n"
            ]
        );
        out = _FakeOut();
        _forward_vite_output(
            _FakeProc(stdout=stream),
            threading.Event(),
            _FakeSys(stdout=out),
            [],
            bundler._dispatch_client_event
        );
        assert seen == [("vite", {"message": "boom", "id": "compiled/x.js"})] , seen;
        echoed = "".join(out.written);
        assert CLIENT_EVENT_PREFIX not in echoed , echoed;
        assert "ordinary vite chatter" in echoed , echoed;
    }
}
