"""Regression tests for issue 12(a): which identity stack owns /user/*.

The owner must be a pure function of configuration. It must never depend on
whether an optional import happened to succeed at boot: the two stacks keep
credentials in different stores (core: sqlite .jac/data/main.db, scale:
Postgres), so a silent flip strands every account created before it.
"""

import os;
import sys;
import from unittest.mock { patch }
import from jaclang { JacRuntime as Jac }
import from jaclang.server.identity_owner {
    CORE_IDENTITY,
    IDENTITY_BACKEND_ENV,
    SCALE_IDENTITY,
    identity_owner,
    scale_stack_installed
}

glob CORE_SERVER_MODULE: str = "jaclang.server.server",
     SCALE_SERVER_MODULE: str = "jaclang.scale.server.serve";


"""Point the configured owner at `value`, returning the previous setting."""
def _set_backend(value: str | None) -> str | None {
    previous = os.environ.get(IDENTITY_BACKEND_ENV);
    if value is None {
        os.environ.pop(IDENTITY_BACKEND_ENV, None);
    } else {
        os.environ[IDENTITY_BACKEND_ENV] = value;
    }
    return previous;
}


"""Put the configured owner back the way `_set_backend` found it."""
def _restore_backend(previous: str | None) {
    _set_backend(previous);
}


test "an unconfigured project resolves to the scale identity in this tree" {
    previous = _set_backend(None);
    try {
        assert scale_stack_installed() is True;
        assert identity_owner() == SCALE_IDENTITY;
        assert Jac.get_api_server_class().__module__ == SCALE_SERVER_MODULE;
    } finally {
        _restore_backend(previous);
    }
}


test "configuration alone can hand /user/* to the core identity" {
    previous = _set_backend(CORE_IDENTITY);
    try {
        assert identity_owner() == CORE_IDENTITY;
        assert Jac.get_api_server_class().__module__ == CORE_SERVER_MODULE;
    } finally {
        _restore_backend(previous);
    }
}


test "an explicit scale setting keeps the scale identity" {
    previous = _set_backend(SCALE_IDENTITY);
    try {
        assert identity_owner() == SCALE_IDENTITY;
        assert Jac.get_api_server_class().__module__ == SCALE_SERVER_MODULE;
    } finally {
        _restore_backend(previous);
    }
}


test "a broken scale import fails loudly instead of changing the owner" {
    previous = _set_backend(SCALE_IDENTITY);
    try {
        # A None entry in sys.modules is how CPython spells "this import
        # fails"; any real failure inside the scale serve import graph (a
        # compile error, a half-written cache entry, a missing dependency)
        # reaches the boot path the same way.
        with patch.dict(sys.modules, {SCALE_SERVER_MODULE: None}) {
            with testraises(RuntimeError) as exc {
                Jac.get_api_server_class();
            }
            message = str(exc.value);
            assert SCALE_SERVER_MODULE in message;
            assert "identity" in message.lower();
        }
    } finally {
        _restore_backend(previous);
    }
}
