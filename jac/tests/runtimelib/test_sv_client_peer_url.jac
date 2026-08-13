"""Peer URL resolution: the env contract and its precedence.

`peer_url_env_key` is the single definition of the variable name that carries a
peer's URL. Writers (the k8s manifest builder, the local process manager) and
readers share it, so the key format is asserted here as a literal rather than
through the helper.

A value that is present but blank now reads as absent. Returning an empty URL
only moves the failure to the first request, where it is far harder to place.
"""

import os;
import from jaclang.runtimelib.sv_client {
    peer_url_env_key,
    peer_url_from_env,
    resolve_url,
    register,
    unregister,
    _ensure_available
}


glob _MOD: str = "peer_url_probe";


def _is_registered(module_name: str) -> bool {
    import from jaclang.runtimelib.sv_client { _registry }
    return module_name in _registry;
}


def _snapshot -> str | None {
    return os.environ.get(peer_url_env_key(_MOD));
}


def _restore(saved: str | None) {
    if saved is None {
        os.environ.pop(peer_url_env_key(_MOD), None);
    } else {
        os.environ[peer_url_env_key(_MOD)] = saved;
    }
    unregister(_MOD);
}


# Kubernetes object names are RFC1123-safe, so a peer named orders_app is served
# by orders-app-service. The env key keeps the raw name, and a reader that
# rebuilt it from the Kubernetes name would look up the wrong variable.
test "the env key keeps the raw module name" {
    assert peer_url_env_key("orders_app") == "JAC_SV_ORDERS_APP_URL";
    assert peer_url_env_key("main") == "JAC_SV_MAIN_URL";
}


test "an unset, blank or whitespace value all read as absent" {
    saved = _snapshot();
    try {
        os.environ.pop(peer_url_env_key(_MOD), None);
        assert peer_url_from_env(_MOD) == "";

        os.environ[peer_url_env_key(_MOD)] = "";
        assert peer_url_from_env(_MOD) == "";

        os.environ[peer_url_env_key(_MOD)] = "   ";
        assert peer_url_from_env(_MOD) == "";

        os.environ[peer_url_env_key(_MOD)] = " http://peer.invalid ";
        assert peer_url_from_env(_MOD) == "http://peer.invalid";
    } finally {
        _restore(saved);
    }
}


test "an in-process registration wins over the env" {
    saved = _snapshot();
    try {
        os.environ[peer_url_env_key(_MOD)] = "http://from-env.invalid";
        register(_MOD, "http://from-registry.invalid");

        assert resolve_url(_MOD) == "http://from-registry.invalid";
    } finally {
        _restore(saved);
    }
}


test "the env is used when nothing is registered" {
    saved = _snapshot();
    try {
        unregister(_MOD);
        os.environ[peer_url_env_key(_MOD)] = "http://from-env.invalid";

        assert resolve_url(_MOD) == "http://from-env.invalid";
    } finally {
        _restore(saved);
    }
}


# Previously any value counted as present, so a blank one resolved to "" and the
# caller failed later with no indication of where the empty URL came from.
test "a blank env value raises instead of resolving to an empty URL" {
    saved = _snapshot();
    try {
        unregister(_MOD);
        os.environ[peer_url_env_key(_MOD)] = "";

        raised = "";
        try {
            resolve_url(_MOD);
        } except RuntimeError as err {
            raised = str(err);
        }

        assert raised , "a blank override resolved instead of raising";
        assert peer_url_env_key(_MOD) in raised , (
            f"the error should name the variable to set, got: {raised}"
        );
    } finally {
        _restore(saved);
    }
}


# _ensure_available registers what it resolves. A blank value must not become a
# registration, or every later lookup would return the empty URL from cache.
test "a blank env value is never registered" {
    saved = _snapshot();
    try {
        unregister(_MOD);
        os.environ[peer_url_env_key(_MOD)] = "  ";

        try {
            _ensure_available(_MOD);
        } except Exception {
            ;
        }

        assert not _is_registered(_MOD) , (
            "a blank override was cached as a registration"
        );
    } finally {
        _restore(saved);
    }
}
