import from pathlib { Path }

def jac_dev_handler_cls(state: dict) -> any {
    import from http.server { BaseHTTPRequestHandler }
    import from json { dumps }

    def do_get(handler: any) -> None {
        raw_path = handler.path.split("?")[0];
        if raw_path == "/_jac/dev/modules/manifest.json" {
            body = dumps(
                {
                    "version": str(state.get("version", "")),
                    "path": "/_jac/dev/modules/android/classes.dex"
                }
            ).encode(
                "utf-8"
            );
            handler.send_response(200);
            handler.send_header("Content-Type", "application/json");
            handler.send_header("Content-Length", str(len(body)));
            handler.send_header("Cache-Control", "no-store");
            handler.end_headers();
            handler.wfile.write(body);
        } elif raw_path == "/_jac/dev/modules/android/classes.dex" {
            dex_path = state.get("dex_path");
            data: bytes = b"";
            if dex_path and Path(str(dex_path)).is_file() {
                data = Path(str(dex_path)).read_bytes();
            }
            if not data {
                handler.send_response(404);
                handler.send_header("Cache-Control", "no-store");
                handler.end_headers();
                return;
            }
            handler.send_response(200);
            handler.send_header("Content-Type", "application/octet-stream");
            handler.send_header("Content-Length", str(len(data)));
            handler.send_header("Cache-Control", "no-store");
            handler.end_headers();
            handler.wfile.write(data);
        } else {
            handler.send_response(404);
            handler.send_header("Cache-Control", "no-store");
            handler.end_headers();
        }
    }

    def silent_log(handler: any, fmt: any, *args: any) { }

    return type(
        "JacDevHandler",
        (BaseHTTPRequestHandler, ),
        {"do_GET": do_get, "protocol_version": "HTTP/1.0", "log_message": silent_log}
    );
}

def start_jac_dev_server(port: int, state: dict) -> any {
    import from http.server { ThreadingHTTPServer }
    import from threading { Thread }

    handler_cls = jac_dev_handler_cls(state);
    httpd = ThreadingHTTPServer(("0.0.0.0", port), handler_cls);
    thread = Thread(target=httpd.serve_forever, daemon=True);
    thread.start();
    return httpd;
}
