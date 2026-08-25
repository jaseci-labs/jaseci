import from jaclang.server.serving.datatypes { Request }
import from jaclang.server.serving.datatypes { JSONResponse }
import from jaclang.server.serving.endpoint {
    HTTPMethod,
    JEndPoint,
    APIParameter,
    ParameterType
}
import from jaclang.scale.server.native_server { NativeJServer }

obj JacAPIServerTraces {
    has server: (NativeJServer | None) = None;

    def require_admin_json(Authorization: str | None) -> (JSONResponse | None);
    def register_traces_endpoints -> None;
}
