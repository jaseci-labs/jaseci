import time;
import asyncio;
import logging;
import mimetypes;
import from datetime { datetime }
import from pathlib { Path }
import json;
import from jaclang.server.serving.datatypes { Request }
import from jaclang.server.serving.openapi { register_docs_endpoints }
import from jaclang.server.serving.middleware {
    cors_middleware,
    custom_headers_middleware
}
import from jaclang.server.serving.datatypes {
    HTMLResponse,
    JSONResponse,
    RedirectResponse,
    Response
}
import from jaclang.scale.server.native_server { NativeJServer }
import from jaclang.server.serving.endpoint {
    APIParameter,
    HTTPMethod,
    JEndPoint,
    ParameterType,
    WSEndPoint
}
import from jaclang.runtime.runtime { JacRuntime as Jac }
import from jaclang.server.serving.static_assets { AssetRoot }
import from jaclang.server.server { JacAPIServer as JServer }
import from jaclang.server.server { UserManager as CoreUserManager }
import from jaclang.server.server { JsonValue }
import from jaclang.server.transport { TransportResponse, Meta }
import from jaclang.scale.shared.utils { _extract_path_param_names }
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale.webhook.webhook { ApiKeyManager, WebhookUtils }
import from jaclang.scale.observability.metrics { MetricsCollector }
import from jaclang.scale.events.broker { EventStreamBroker }
import from jaclang.scale.websocket.websocket {
    WebSocketConnectionManager,
    ConnectionContext,
    _ws_stream_result
}
import from jaclang.scale.websocket.backplane { build_backplane }
import from jaclang.scale.websocket.protocol {
    HEARTBEAT_SECONDS,
    HEARTBEAT_MISSED_ALLOWED,
    SEND_TIMEOUT_SECONDS,
    AUTH_HANDSHAKE_TIMEOUT_SECONDS,
    ws_error_frame,
    ws_pre_accept_auth,
    ws_reject_pre_accept,
    ws_authenticate,
    ws_heartbeat_loop,
    ws_reject_auth,
    ws_reject_registration,
    ws_receive_frame,
    ws_handle_control,
    ws_execute_target
}
import from typing { AsyncGenerator }
import from inspect { isgenerator }
import from jaclang.server.serving.datatypes { StreamingResponse }
import from jaclang.cli.console { console }
import from jaclang.cli.banners { JAC_DISCORD_URL }
import from jaclang.server.serving.ws { WebSocket }
import from jaclang.server.serving.datatypes { WebSocketDisconnect }
import from jaclang.scale.admin.admin_portal { JacAPIServerAdmin }
import from jaclang.scale.admin.llm_telemetry { JacAPIServerLLMTelemetry }
import from jaclang.scale.admin.workloads { JacAPIServerWorkloads }
import from jaclang.scale.admin.logs { JacAPIServerLogs }
import from jaclang.scale.admin.traces { JacAPIServerTraces }
import from jaclang.scale.admin.ops { JacAPIServerOps }
import from jaclang.scale.admin.deploy_health { JacAPIServerDeployHealth }
import from jaclang.scale.admin.network { JacAPIServerNetwork }
import from jaclang.scale.admin.podenv { JacAPIServerPodEnv }
import from jaclang.scale.scheduler.scheduler { JacScaleScheduler, TriggerSpec }
import from jaclang.runtime.builtin { ScheduleTrigger }
import from jaclang.compiler.frontend.constant { Constants as Con }
import traceback;
import from urllib.parse { quote }
import from jaclang.scale.shared.utils {
    authenticate_or_fail,
    is_safe_loopback_redirect
}
import from jaclang.scale.identity.auth_models {
    RegisterRequest,
    LoginRequest,
    FirebaseTokenRequest,
    UpdatePasswordRequest,
    AddIdentityRequest,
    VerifyIdentityRequest,
    SendVerificationRequest,
    ForgotPasswordRequest,
    ResetPasswordRequest,
    UpdateProfileRequest,
    UpdateProfileResponse,
    MeResponse
}
import from jaclang.scale.scheduler.scheduler_models {
    CreateJobRequest,
    UpdateJobRequest
}
import from jaclang.scale.emailer.emailer { Emailer }

glob _jwt_config = get_scale_config().get_jwt_config(),
     _sso_config = get_scale_config().get_sso_config(),
     JWT_SECRET = _jwt_config['secret'],
     JWT_ALGORITHM = _jwt_config['algorithm'],
     JWT_EXP_DELTA_DAYS = _jwt_config['exp_delta_days'],
     SSO_HOST = _sso_config['host'],
     logger = logging.getLogger(__name__);

import from jaclang.server.net { PORT_RETRY_LIMIT, find_available_port }

def _get_network_ips -> list[str];

def _resolve_sso_client_redirect(requested: str | None, configured: str) -> str;

obj JacAPIServerParts {
    has _hmr_pending: bool = False,
        _hot_reloader: any | None = None,
        _api_key_manager: ApiKeyManager | None = None,
        _metrics: MetricsCollector | None = None,
        _ws_manager: WebSocketConnectionManager | None = None,
        _broker: EventStreamBroker | None = None,
        _emailer: Emailer | None = None;

    def register_auth_endpoints -> None abst;
    def get_api_key_manager -> ApiKeyManager abst;
    def setup_emailer -> Emailer | None abst;
    def get_emailer -> Emailer | None abst;
    def register_walkers_endpoints -> None abst;
    def register_functions_endpoints -> None abst;
    def register_webhook_endpoints -> None abst;
    def register_websocket_endpoints -> None abst;
    def register_scheduler_endpoints -> None abst;
    def register_static_file_endpoint -> None abst;
    def register_client_js_endpoint -> None abst;
    def register_page_endpoint -> None abst;
    def register_root_asset_endpoint -> None abst;
    def register_graph_endpoint -> None abst;
    def register_admin_endpoints -> None abst;
    def validate_admin_token(Authorization: str | None) -> (str | None) abst;
    def register_deploy_health_endpoints -> None abst;
    def register_llm_telemetry_endpoints -> None abst;
    def register_logs_endpoints -> None abst;
    def register_network_endpoints -> None abst;
    def register_ops_endpoints -> None abst;
    def register_podenv_endpoints -> None abst;
    def register_traces_endpoints -> None abst;
    def register_workloads_endpoints -> None abst;
}


obj JacAPIServerAuth(JacAPIServerParts) {
    def register_auth_endpoints -> None;
    def register_register_endpoint -> None;
    def register_login_endpoint -> None;
    def register_refresh_token_endpoint -> None;
    def register_update_password_endpoint -> None;
    def register_add_identity_endpoint -> None;
    def register_send_verification_endpoint -> None;
    def register_verify_identity_endpoint -> None;
    def register_forgot_password_endpoint -> None;
    def register_reset_password_endpoint -> None;
    def register_me_endpoint -> None;
    def register_update_me_endpoint -> None;
    def register_sso_endpoints -> None;
    def _create_sso_callback_wrapper -> Callable[..., (Response | TransportResponse)];
    def register_firebase_token_endpoint -> None;
    def get_api_key_manager -> ApiKeyManager;
    def create_api_key(
        name: str,
        expiry_days: int | None = None,
        Authorization: str | None = None,
        allowed_walkers: list[str] | None = None
    ) -> TransportResponse;

    def list_api_keys(Authorization: str | None = None) -> TransportResponse;
    def revoke_api_key(
        api_key_id: str, Authorization: str | None = None
    ) -> TransportResponse;

    def register_api_key_endpoints -> None;
}

obj JacAPIServerHost(JacAPIServerParts, JServer) {}


obj JacAPIServerEmailer(JacAPIServerHost) {
    def setup_emailer -> Emailer | None;
    def get_emailer -> Emailer | None;
}

obj JacAPIServerCore(JacAPIServerHost) {
    def postinit -> None;
    def _make_user_manager -> CoreUserManager;
    def start(
        dev: bool = False,
        no_client: bool = False,
        on_ready: Callable[..., None] | None = None
    ) -> None;

    def _configure_openapi_security -> None;
    def _print_startup_banner(dev: bool, no_client: bool) -> None;
    def register_health_endpoint -> None;
    def register_build_status_endpoint -> None;
    def _register_client_error_endpoint -> None;
    def enable_hmr(hot_reloader: any) -> None;
    def _register_endpoints -> None;
    def _refresh_dev_endpoints -> None;
    def _setup_scheduler -> None;
    def _setup_events -> None;
    def _create_admin_metrics_handler(
        original_handler: Callable[..., any]
    ) -> Callable[..., any];
}

obj JacAPIServerEndpoints(JacAPIServerHost) {
    def register_walkers_endpoints -> None;
    def create_walker_callback(
        walker_name: str, has_node_param: bool = False
    ) -> Callable[..., (TransportResponse | StreamingResponse)];

    def create_walker_parameters(
        walker_name: str, invoke_on_root: bool, method: HTTPMethod = HTTPMethod.POST
    ) -> list[APIParameter];

    def register_functions_endpoints -> None;
    def create_function_callback(
        func_name: str
    ) -> Callable[..., (TransportResponse | StreamingResponse)];

    def create_function_parameters(
        func_name: str, method: HTTPMethod = HTTPMethod.POST
    ) -> list[APIParameter];

    def get_walker_protocol(walker_name: str) -> str;
    def get_function_protocol(func_name: str) -> str;
    def register_webhook_endpoints -> None;
    def create_webhook_callback(walker_name: str) -> Callable[..., TransportResponse];
    def create_webhook_parameters(walker_name: str) -> list[APIParameter];
    def get_ws_manager -> WebSocketConnectionManager;
    def _create_websocket_target_handler(
        target_kind: str,
        target_name: str,
        target: any,
        requires_auth: bool,
        execute: Callable
    ) -> Callable;

    def create_websocket_handler(walker_name: str) -> Callable;
    def create_websocket_function_handler(func_name: str) -> Callable;
    def register_websocket_endpoints -> None;
}

obj JacAPIServerScheduler(JacAPIServerHost) {
    def register_scheduler_endpoints -> None;
    def create_job_callback -> Callable[..., TransportResponse];
    def list_jobs_callback -> Callable[..., TransportResponse];
    def get_job_callback -> Callable[..., TransportResponse];
    def update_job_callback -> Callable[..., TransportResponse];
    def delete_job_callback -> Callable[..., TransportResponse];
}

obj JacAPIServerStatic(JacAPIServerHost) {
    has _asset_table: list[AssetRoot] | None = None;

    def asset_base_path -> Path;
    def _get_asset_table -> list[AssetRoot];
    def serve_static_file(file_path: str) -> Response;
    def register_static_file_endpoint -> None;
    def serve_client_js_callback -> Callable[..., Response];
    def register_client_js_endpoint -> None;
    def render_page_callback -> Callable[..., HTMLResponse];
    def render_base_route_callback(app_name: str) -> Callable[..., HTMLResponse];
    def register_page_endpoint -> None;
    def serve_root_asset(file_path: str) -> Response;
    def register_root_asset_endpoint -> None;
    def register_graph_endpoint -> None;
    def serve_graph_page -> HTMLResponse;
    def graph_data(Authorization: (str | None) = None) -> JSONResponse;
}

obj JacAPIServer(JacAPIServerCore, JacAPIServerAuth, JacAPIServerEndpoints, JacAPIServerStatic, JacAPIServerAdmin, JacAPIServerLLMTelemetry, JacAPIServerWorkloads, JacAPIServerLogs, JacAPIServerTraces, JacAPIServerOps, JacAPIServerDeployHealth, JacAPIServerNetwork, JacAPIServerPodEnv, JacAPIServerScheduler, JacAPIServerEmailer, JServer) {
    has _hmr_pending: bool = False,
        _hot_reloader: any | None = None,
        _api_key_manager: ApiKeyManager | None = None,
        _metrics: MetricsCollector | None = None,
        _ws_manager: WebSocketConnectionManager | None = None,
        _broker: EventStreamBroker | None = None,
        _emailer: Emailer | None = None;
}
