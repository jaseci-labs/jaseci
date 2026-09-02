"""`@restspec` routes must answer the same way in dev as they do when served.

A `@restspec(method=GET, path="/install.sh")` function claims a literal HTTP
path. `jac run --serve` answers it with the function's payload; `jac run --dev`
answered it with the SPA HTML shell, because the Vite dev proxy forwards a
fixed list of prefixes (`/walker`, `/function`, `/user`, ...) and everything
else falls through to Vite's SPA fallback. Hitting the same path on the API
port did not help: the core server's GET catch-all rendered the SPA there too,
and in dev that render kicks off a cold production client build inline in the
request thread, so the request never gets a response head at all.

Pinned here: the paths `@restspec` claims are declared to the dev proxy, the
core server answers them itself with the declared media type and no envelope,
and a dev-mode SPA fallback never blocks on a production bundle build.
"""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

import from jaclang.testing.testing { JacTestClient }


"""Reach an API by name so this suite compiles against a build that lacks it
and fails on the assertion instead of at import."""
def _call(target: any, name: str, *args: any, **kwargs: any) -> any {
    member = getattr(target, name, None);
    assert member is not None , f"{type(target).__name__} has no '{name}'";
    return member(*args, **kwargs);
}


"""A project skeleton the Vite bundler is willing to configure."""
def _min_project(project_dir: str) -> Path {
    Path(os.path.join(project_dir, "jac.toml")).write_text(
        '[project]\nname = "restspec-dev-test"\nversion = "1.0.0"\n', encoding="utf-8"
    );
    entry_file = Path(project_dir) / ".jac" / "client" / "build" / "main.js";
    entry_file.parent.mkdir(parents=True, exist_ok=True);
    entry_file.write_text("// entry", encoding="utf-8");
    return entry_file;
}


"""An app whose only public surface is two GET @restspec functions -- the
shape the jaclang.org site uses for /install.sh and /llms.txt."""
def _restspec_app(project_dir: str) -> str {
    app = os.path.join(project_dir, "app.jac");
    Path(app).write_text(
        'import from http { HTTPMethod }\n'
        '\n'
        '@restspec(\n'
        '    method=HTTPMethod.GET,\n'
        '    path="/install.sh",\n'
        '    produces="text/x-shellscript",\n'
        '    envelope=False\n'
        ')\n'
        'def:pub install_sh -> str {\n'
        '    return "#!/usr/bin/env bash\\necho jac\\n";\n'
        '}\n'
        '\n'
        '@restspec(method=HTTPMethod.GET, path="/llms.txt", produces="text/plain")\n'
        'def:pub llms_txt -> str {\n'
        '    return "jac docs";\n'
        '}\n',
        encoding="utf-8"
    );
    return app;
}


test "the dev vite config proxies the paths @restspec claims" {
    import from jaclang.client.vite_bundler { ViteBundler }

    with TemporaryDirectory() as tmp {
        entry_file = _min_project(tmp);
        bundler = ViteBundler(Path(tmp));
        config_path = _call(
            bundler,
            "create_vite_config",
            entry_file,
            is_dev=True,
            api_port=8123,
            api_paths=["/install.sh", "/llms.txt"]
        );
        text = config_path.read_text(encoding="utf-8");
        assert '"/install.sh"' in text , (
            f"declared restspec paths must reach the dev proxy table; got:\n{text}"
        );
        assert '"/llms.txt"' in text , (
            f"declared restspec paths must reach the dev proxy table; got:\n{text}"
        );
        assert "http://localhost:8123" in text , (
            "the restspec proxy entries must target the api port"
        );
    }
}


test "the server reports the api paths a module declares" {
    with TemporaryDirectory() as tmp {
        app = _restspec_app(tmp);
        client = JacTestClient.from_file(app, base_path=tmp);
        try {
            paths = _call(client.server.introspector, "declared_api_paths");
        } finally {
            client.close();
        }
        assert "/install.sh" in paths , (
            f"the introspector must report @restspec paths; got {paths}"
        );
        assert "/llms.txt" in paths , (
            f"the introspector must report @restspec paths; got {paths}"
        );
    }
}


test "the core server answers a GET @restspec path with its own payload" {
    with TemporaryDirectory() as tmp {
        app = _restspec_app(tmp);
        client = JacTestClient.from_file(app, base_path=tmp);
        try {
            response = client.get("/install.sh");
            body = response.text;
            content_type = response.headers.get("content-type", "");
            status = response.status_code;
        } finally {
            client.close();
        }
        assert status == 200 , f"GET /install.sh should serve the function; got {status}";
        assert "#!/usr/bin/env bash" in body , (
            f"GET /install.sh must return the function's payload, not a shell; got {body[:200]!r}"
        );
        assert "<!DOCTYPE html>" not in body , (
            "GET /install.sh must not fall through to the SPA catch-all"
        );
        assert "text/x-shellscript" in content_type , (
            f"the declared media type must be honored; got {content_type!r}"
        );
    }
}


test "an enveloped GET @restspec path still returns the transport envelope" {
    with TemporaryDirectory() as tmp {
        app = _restspec_app(tmp);
        client = JacTestClient.from_file(app, base_path=tmp);
        try {
            response = client.get("/llms.txt");
            status = response.status_code;
            body = response.text;
        } finally {
            client.close();
        }
        assert status == 200 , f"GET /llms.txt should serve the function; got {status}";
        assert "jac docs" in body , (
            f"GET /llms.txt must return the function's payload; got {body[:200]!r}"
        );
    }
}
