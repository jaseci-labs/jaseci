impl ServerlessFunction._ensure_client -> JacTestClient {
    if self._client is None {
        entry_dir = os.path.dirname(self.entry_file);
        self._client = JacTestClient.from_file(self.entry_file, base_path=entry_dir);
        logger.info(f"jac-serverless: cold start for {self.entry_file}");
    }
    return self._client;
}


impl ServerlessFunction.invoke(
    method: str,
    path: str,
    headers: (dict | None) = None,
    body: (dict | None) = None
) -> TestResponse {
    client = self._ensure_client();
    return client.request(method.upper(), path, json=body, headers=headers or {});
}


impl ServerlessFunction.handle_event(event: dict) -> dict {
    req = parse_event(event);
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
