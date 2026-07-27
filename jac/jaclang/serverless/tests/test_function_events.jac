"""End-to-end test of the serverless function runtime on a fixture app.

Uses the default file-backed persistence (no external database needed); the
Postgres path is covered by test_postgres_integration.jac.
"""
import json;
import os;
import shutil;
import tempfile;
import from jaclang.serverless.functions { ServerlessFunction }

glob FIXTURE = os.path.join(os.path.dirname(__file__), "fixtures", "pingpong");


def _make_event(
    method: str, path: str, body: (dict | None) = None
) -> dict {
    return {
        "version": "2.0",
        "rawPath": path,
        "headers": {"content-type": "application/json"},
        "requestContext": {"http": {"method": method, "path": path}},
        "body": json.dumps(body) if body is not None else None,
        "isBase64Encoded": False
    };
}


test "a walker serves as a serverless function" {
    with tempfile.TemporaryDirectory() as tmp {
        app_dir = os.path.join(tmp, "pingpong");
        shutil.copytree(FIXTURE, app_dir);
        fn = ServerlessFunction(entry_file=os.path.join(app_dir, "main.jac"));

        health = fn.handle_event(_make_event("GET", "/healthz"));
        assert health["statusCode"] == 200;

        result = fn.handle_event(
            _make_event("POST", "/walker/ping", {"msg": "hello"})
        );
        assert result["statusCode"] == 200;
        payload = json.loads(result["body"]);
        assert payload["ok"];
        assert "hello" in json.dumps(payload["data"]);

        missing = fn.handle_event(_make_event("POST", "/walker/nope", {}));
        assert missing["statusCode"] >= 400;

        preflight = fn.handle_event(_make_event("OPTIONS", "/walker/ping"));
        assert preflight["statusCode"] == 200;
        assert preflight["headers"]["Access-Control-Allow-Origin"] == "*";
    }
}
