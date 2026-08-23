import from jaclang.runtimelib.serving.datatypes { Request }
import from jaclang.runtimelib.serving.datatypes { JSONResponse }
import from jaclang.runtimelib.serving.endpoint { HTTPMethod, JEndPoint }
import from jaclang.scale.server.native_server { NativeJServer }

obj JacAPIServerPodEnv {
    has server: (NativeJServer | None) = None;

    def require_admin_json(Authorization: str | None) -> (JSONResponse | None);
    def register_podenv_endpoints -> None;
}
