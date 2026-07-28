"""jac-serverless functions runtime.

Runs a Jac application as a serverless function: the app is booted once per
container (cold start) through the core in-process gateway, and each incoming
event (AWS Lambda function URL / API Gateway HTTP event, or a plain request
dict) is dispatched straight to the walker/auth endpoints without any web
server. Combined with the Postgres/Supabase persistence layer, the function is
fully stateless: kill it, cold start it, the graph and users are all in the
managed database.
"""
import json;
import logging;
import os;
import from jaclang.runtimelib.testing { JacTestClient, TestResponse }

glob logger = logging.getLogger(__name__),
     ENTRY_ENV = "JAC_SERVERLESS_ENTRY",
     ONLY_ENV = "JAC_SERVERLESS_FUNCTION",
     _function_cache: dict[str, any] = {};


obj ServerlessFunction {
    has entry_file: str,
        only: str = "",
        _client: (JacTestClient | None) = None;

    def _ensure_client -> JacTestClient;
    def invoke(
        method: str,
        path: str,
        headers: (dict | None) = None,
        body: (dict | None) = None
    ) -> TestResponse;

    def exposes(path: str) -> bool;
    def handle_event(event: dict) -> dict;
    def list_functions -> list;
}


def resolve_entry(entry_file: (str | None) = None) -> str {
    target = entry_file or os.environ.get(ENTRY_ENV) or "main.jac";
    return os.path.abspath(target);
}


def get_function(entry_file: (str | None) = None) -> ServerlessFunction {
    resolved = resolve_entry(entry_file);
    restriction = os.environ.get(ONLY_ENV, "");
    key = f"{resolved}#{restriction}";
    fn = _function_cache.get(key);
    if fn is None {
        fn = ServerlessFunction(entry_file=resolved, only=restriction);
        _function_cache[key] = fn;
    }
    return fn;
}


def parse_event(event: dict) -> dict {
    # API Gateway v2 / Lambda function URL
    req_ctx = event.get("requestContext") or {};
    http_ctx = req_ctx.get("http") or {};
    method = http_ctx.get("method") or event.get("httpMethod") or "GET";
    path = event.get("rawPath") or event.get("path") or "/";
    headers = {
        str(k): str(v)
        for (k, v) in (event.get("headers") or {}).items()
    };
    raw_body = event.get("body");
    if raw_body and event.get("isBase64Encoded") {
        import base64;
        raw_body = base64.b64decode(raw_body).decode("utf-8", "replace");
    }
    body: (dict | None) = None;
    if raw_body {
        try {
            body = json.loads(raw_body);
        } except Exception {
            body = None;
        }
    }
    query = event.get("rawQueryString") or "";
    if query {
        path = f"{path}?{query}";
    }
    return {"method": method, "path": path, "headers": headers, "body": body};
}


def lambda_handler(event: dict, context: any = None) -> dict {
    return get_function().handle_event(event);
}
