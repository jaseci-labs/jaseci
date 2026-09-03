import from collections { OrderedDict }

glob IDEMPOTENCY_LRU_SIZE: int = 4096,
     _idempotency_seen: OrderedDict = OrderedDict();


def idempotency_lookup(key: str) -> any {
    if not key or key not in _idempotency_seen {
        return None;
    }
    _idempotency_seen.move_to_end(key);
    return _idempotency_seen[key];
}


def idempotency_remember(key: str, response: any) -> None {
    if not key {
        return;
    }
    _idempotency_seen[key] = response;
    _idempotency_seen.move_to_end(key);
    while len(_idempotency_seen) > IDEMPOTENCY_LRU_SIZE {
        _idempotency_seen.popitem(last=False);
    }
}


def idempotency_clear -> None {
    _idempotency_seen.clear();
}


obj BridgeError(Exception) {
    has app: str = "",
        name: str = "",
        detail: str = "",
        status: int = 0;

    def __str__ -> str {
        label = f"{self.app}.{self.name}" if self.name else self.app;
        return f"bridge to '{label}' failed: {self.detail or 'unknown error'}";
    }
}

obj BridgeUnavailable(BridgeError) {}

obj BridgeTimeout(BridgeError) {}

obj BridgeRejected(BridgeError) {}


def bridge_error_for_status(
    status: int, app: str, name: str, detail: str
) -> BridgeError {
    if 400 <= status < 500 {
        return BridgeRejected(app=app, name=name, detail=detail, status=status);
    }
    return BridgeError(app=app, name=name, detail=detail, status=status);
}


def bridge_error_from(exc: Exception, app: str, name: str) -> BridgeError {
    if isinstance(exc, BridgeError) {
        return exc;
    }
    import asyncio;
    import socket;
    import from jaclang.server.serving.client {
        ClientConnectionError,
        ClientReadTimeout,
        ClientRequestNotSent
    }
    detail = str(exc) or exc.__class__.__name__;
    if isinstance(
        exc, (ClientReadTimeout, asyncio.TimeoutError, socket.timeout, TimeoutError)
    ) {
        return BridgeTimeout(app=app, name=name, detail=detail);
    }
    if isinstance(exc, ClientRequestNotSent) {
        return BridgeUnavailable(app=app, name=name, detail=detail);
    }
    if isinstance(exc, ClientConnectionError) {
        status = exc.status_code or 0;
        if status {
            return bridge_error_for_status(status, app, name, detail);
        }
        return BridgeUnavailable(app=app, name=name, detail=detail);
    }
    if isinstance(exc, (ConnectionError, OSError)) {
        return BridgeUnavailable(app=app, name=name, detail=detail);
    }
    return BridgeError(app=app, name=name, detail=detail);
}
