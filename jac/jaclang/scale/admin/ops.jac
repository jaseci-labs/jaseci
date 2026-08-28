import from jaclang.server.serving.datatypes { Request }
import from jaclang.server.serving.datatypes { JSONResponse }
import from jaclang.server.serving.endpoint { HTTPMethod, JEndPoint }
import from jaclang.scale.server.native_server { NativeJServer }

obj JacAPIServerOps {
    has server: (NativeJServer | None) = None;

    def require_admin_json(Authorization: str | None) -> (JSONResponse | None);
    def register_ops_endpoints -> None;
}
