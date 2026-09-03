import sys;
import from jaclang.server.bridge {
    BridgeError,
    BridgeRejected,
    BridgeTimeout,
    BridgeUnavailable
}

glob EXIT_OK: int = 0,
     EXIT_FAILURE: int = 1,
     EXIT_USAGE: int = 2,
     EXIT_UNAVAILABLE: int = 3,
     EXIT_TIMEOUT: int = 4,
     EXIT_REJECTED: int = 5;

glob START_HINT: str = "hint: start the site with `jac run web`";

def warn(text: str) -> None {
    print(text, file=sys.stderr);
}

def _suffix(detail: str) -> str {
    return " (" + detail + ")" if detail else "";
}

def explain_bridge_error(e: BridgeError) -> int {
    where = e.app + "." + e.name;
    if isinstance(e, BridgeUnavailable) {
        warn("jacorg: " + where + " is not reachable" + _suffix(e.detail));
        warn(START_HINT);
        return EXIT_UNAVAILABLE;
    }
    if isinstance(e, BridgeTimeout) {
        warn("jacorg: " + where + " timed out" + _suffix(e.detail));
        return EXIT_TIMEOUT;
    }
    if isinstance(e, BridgeRejected) {
        warn("jacorg: " + where + " rejected the call" + _suffix(e.detail));
        warn("hint: the site wants a signed-in identity for this command");
        return EXIT_REJECTED;
    }
    warn("jacorg: " + where + " failed" + _suffix(e.detail));
    return EXIT_FAILURE;
}

def field_of(raw: object, name: str) -> object {
    if isinstance(raw, dict) {
        return raw.get(name);
    }
    return getattr(raw, name, None);
}

def str_field(raw: object, name: str) -> str {
    v = field_of(raw, name);
    return "" if v is None else str(v);
}

def int_field(raw: object, name: str) -> int {
    v = field_of(raw, name);
    return v if isinstance(v, int) else 0;
}

def list_field(raw: object, name: str) -> list[object] {
    v = field_of(raw, name);
    return list(v) if isinstance(v, list) else [];
}
