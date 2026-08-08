import logging;
import from jaclang.runtimelib.serving.app { ServingApp }
import from jaclang.runtimelib.serving.endpoint { JEndPoint, WSEndPoint }
import from jaclang.runtimelib.serving.server {
    ACCESS_LOGGER_NAME,
    ServingServer
}


glob logger: logging.Logger = logging.getLogger(__name__);


class ConsoleLogHandler(logging.Handler) {
    def emit(self: ConsoleLogHandler, record: logging.LogRecord) {
        import from jaclang.cli.console { console }
        message = self.format(record);
        console.print(f"  {message}");
    }
}

class HealthCheckFilter(logging.Filter) {
    _SUPPRESSED = {
        '"GET /docs HTTP',
        '"GET / HTTP',
        '"GET /openapi.json HTTP',
        '"GET /health HTTP',
        '"GET /healthz'
    };

    def filter(self: HealthCheckFilter, record: logging.LogRecord) -> bool {
        msg = record.getMessage();
        for pat in self._SUPPRESSED {
            if pat in msg {
                return False;
            }
        }
        return True;
    }
}

def configure_access_logging(suppress_health_checks: bool = False) {
    console_handler = ConsoleLogHandler();
    console_handler.setFormatter(logging.Formatter("%(message)s"));
    if suppress_health_checks {
        console_handler.addFilter(HealthCheckFilter());
    }
    access_logger = logging.getLogger(ACCESS_LOGGER_NAME);
    access_logger.handlers = [console_handler];
    access_logger.setLevel(int(logging.INFO));
    access_logger.propagate = False;
}

obj NativeJServer {
    has app: ServingApp = ServingApp(title='Jac API', version='1.0.0'),
        user_manager: any = None,
        serving: any = None,
        _endpoints: list[JEndPoint] = [],
        _prebound_listen_socket: any = None;

    def set_user_manager(user_manager: any) {
        self.user_manager = user_manager;
    }

    def add_endpoint(endpoint: JEndPoint) {
        self._endpoints.append(endpoint);
        self.app.add_endpoint(endpoint);
    }

    def add_ws_endpoint(path: str, handler: any) {
        self.app.add_ws_endpoint(WSEndPoint(path=path, handler=handler));
    }

    def execute {}

    def run_server(
        host: str = '0.0.0.0',
        port: int = 8000,
        max_retries: int = 10,
        on_ready: any = None
    ) {
        import from jaclang.scale.config.config_loader { get_scale_config }
        import from jaclang.scale.runtime.lifecycle.drain {
            install_signal_drain
        }
        server_cfg = get_scale_config().get_server_config();
        configure_access_logging(
            suppress_health_checks=bool(
                server_cfg.get('suppress_health_check_logs', False)
            )
        );
        ms_cfg = get_scale_config().get_microservices_config();
        drain_timeout = float(ms_cfg.get("drain_timeout_seconds", 10));
        self.serving = ServingServer(
            app=self.app, host=host, port=port, drain_timeout=drain_timeout
        );
        install_signal_drain(self.serving, timeout_s=drain_timeout);
        self.serving.run(on_ready=on_ready, port_retries=max_retries);
    }

    def request_stop {
        if self.serving is not None {
            self.serving.request_stop();
        }
    }
}
