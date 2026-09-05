"""The assembly's own middleware: request context, bearer auth, metrics.

Order matters and is fixed by `JacAPIServer._install_middleware`: a request
is authenticated first, then given a fresh execution context bound to the
caller's root, and only then reaches the router. Extensions add theirs on
the outside of these.
"""
import logging;
import time;
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.server.identity.user_manager { UserManager }
import from jaclang.server.serving.datatypes { JSONResponse, Request, Response }
import from jaclang.server.serving.drain { HEALTH_PATHS }
import from jaclang.server.transport { Meta, TransportResponse }

glob logger: logging.Logger = logging.getLogger('jaclang.serve');


def bearer_token(request: Request) -> (str | None) {
    authorization = request.headers.get('Authorization');
    if authorization and authorization.startswith('Bearer ') {
        return authorization[7:];
    }
    return None;
}


"""Resolve the bearer token to a user once per request, onto `request.state`."""
def jwt_middleware(user_manager: UserManager) -> Callable[..., any] {
    async def _middleware(request: Request, call_next: any) -> Response {
        username: (str | None) = None;
        user_root_id: (str | None) = None;
        token = bearer_token(request);
        if token {
            username = user_manager.validate_jwt_token(token);
            if username {
                user_root_id = user_manager.get_root_id(username);
            }
        }
        setattr(request.state, 'user_root_id', user_root_id);
        setattr(request.state, 'username', username);
        next_fn: any = call_next;
        return await next_fn(request);
    }
    return _middleware;
}


def _service_unavailable(detail: str) -> JSONResponse {
    resp = JSONResponse(
        status_code=503,
        content={
            'ok': False,
            'error': {'code': 'SERVICE_UNAVAILABLE', 'message': detail}
        }
    );
    resp.headers.set('Retry-After', '1');
    return resp;
}


"""Give every request a fresh execution context bound to its caller's root.

The context owns a session on the project's store for the life of the
request, so nothing leaks between callers and every worker resolves anchors
through the database rather than a process-wide cache."""
def request_context_middleware -> Callable[..., any] {
    async def _middleware(request: Request, call_next: any) -> Response {
        next_fn: any = call_next;
        if request.url.path in HEALTH_PATHS {
            return await next_fn(request);
        }
        try {
            ctx = JacRuntime.create_j_context(user_root=None);
        } except Exception as ctx_err {
            logger.error(
                f"request context unavailable for {request.url.path}: "
                f"{type(ctx_err).__name__}: {ctx_err}",
                exc_info=True
            );
            return _service_unavailable('unable to reach the database');
        }
        req_token = JacRuntime.push_request_context(ctx);
        user_id = getattr(request.state, 'user_root_id', None);
        bind_error: any = None;
        if user_id {
            ctx.mem.read_scope_enter();
            try {
                await ctx.aset_user_root(str(user_id));
            } except (ValueError, RuntimeError) as err {
                bind_error = err;
            } finally {
                ctx.mem.read_scope_exit();
            }
        }
        try {
            if bind_error is not None {
                logger.error(
                    f"refusing request for user_root_id {user_id}: "
                    f"{type(bind_error).__name__}: {bind_error}"
                );
                resp = JSONResponse(
                    status_code=401,
                    content={
                        'ok': False,
                        'error': {
                            'code': 'IDENTITY_UNRESOLVABLE',
                            'message': str(bind_error)
                        }
                    }
                );
                return resp;
            }
            return await next_fn(request);
        } finally {
            try {
                ctx.close();
            } except Exception as e {
                logger.warning(f"Failed to close request context: {e}", exc_info=True);
            } finally {
                JacRuntime.reset_request_context(req_token);
            }
        }
    }
    return _middleware;
}


"""Report request timing into an installed metrics hook."""
def metrics_middleware(metrics: any, exempt_path: str = '') -> Callable[..., any] {
    async def _middleware(request: Request, call_next: any) -> Response {
        next_fn: any = call_next;
        if exempt_path and request.url.path == exempt_path {
            return await next_fn(request);
        }
        metrics.request_started();
        started = time.perf_counter();
        status = 500;
        try {
            response = await next_fn(request);
            status = response.status_code;
            return response;
        } finally {
            metrics.record_request(
                request.method, request.url.path, status, time.perf_counter() - started
            );
            metrics.request_finished();
        }
    }
    return _middleware;
}


def unauthorized(message: str = 'Unauthorized') -> TransportResponse {
    return TransportResponse.fail(
        code='UNAUTHORIZED', message=message, meta=Meta(extra={'http_status': 401})
    );
}


"""The authenticated user id, or a 401 envelope when there is none."""
def require_user(request: Request) -> tuple[(str | None), (TransportResponse | None)] {
    username = getattr(request.state, 'username', None);
    if not username {
        return (None, unauthorized('Invalid or expired token'));
    }
    return (str(username), None);
}
