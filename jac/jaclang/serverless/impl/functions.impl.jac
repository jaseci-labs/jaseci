impl ServerlessFunction._ensure_client -> JacTestClient {
    if self._client is None {
        entry_dir = os.path.dirname(self.entry_file);
        self._client = JacTestClient.from_file(self.entry_file, base_path=entry_dir);
        logger.info(f"jac-serverless: cold start for {self.entry_file}");
    }
    return self._client;
}


impl ServerlessFunction.invoke(
    method: str, path: str, headers: (dict | None) = None, body: (dict | None) = None
) -> TestResponse {
    client = self._ensure_client();
    return client.request(method.upper(), path, json=body, headers=headers or {});
}


impl ServerlessFunction.exposes(path: str) -> bool {
    if not self.only {
        return True;
    }
    clean = path.split("?")[0].rstrip("/");
    if clean in ("", "/healthz") {
        return True;
    }
    if self.only == "auth" {
        return clean.startswith("/user/");
    }
    if ":" in self.only {
        (kind, target) = self.only.split(":", 1);
        prefix = f"/{kind}/{target}";
        return clean == prefix or clean.startswith(prefix + "/");
    }
    return False;
}


impl ServerlessFunction.list_functions -> list {
    client = self._ensure_client();
    client._ensure_initialized();
    server = client._server;
    server.introspector.load();
    rows: list = [];
    for wname in sorted(server.get_walkers().keys()) {
        rows.append(
            {
                "name": wname,
                "kind": "walker",
                "route": f"/walker/{wname}",
                "auth": bool(server.introspector.is_auth_required_for_walker(wname))
            }
        );
    }
    for fname in sorted(server.get_functions().keys()) {
        rows.append(
            {
                "name": fname,
                "kind": "function",
                "route": f"/function/{fname}",
                "auth": bool(server.introspector.is_auth_required_for_function(fname))
            }
        );
    }
    return rows;
}


impl ServerlessFunction.handle_event(event: dict) -> dict {
    req = parse_event(event);
    if not self.exposes(req["path"]) {
        return {
            "statusCode": 403,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(
                {
                    "ok": False,
                    "error": {
                        "code": "NOT_EXPOSED",
                        "message": f"this serverless function only exposes {self.only}"
                    }
                }
            )
        };
    }
    if req["method"].upper() == "OPTIONS" {
        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, POST, PUT, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization"
            },
            "body": ""
        };
    }
    try {
        response = self.invoke(
            req["method"], req["path"], headers=req["headers"], body=req["body"]
        );
    } except Exception as e {
        logger.exception("jac-serverless: unhandled error");
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(
                {"ok": False, "error": {"code": "INTERNAL", "message": str(e)}}
            )
        };
    }
    out_headers = dict(response.headers or {});
    out_headers.setdefault("Content-Type", "application/json");
    out_headers["Access-Control-Allow-Origin"] = "*";
    return {
        "statusCode": response.status_code,
        "headers": out_headers,
        "body": response.text
    };
}
