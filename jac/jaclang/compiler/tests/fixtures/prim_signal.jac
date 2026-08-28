"""Bundled native `signal` cross-backend equivalence fixture (Mechanism F).

`import signal` binds CPython on sv and `na_stdlib/signal.jac` on na (when the
native floor lowers). ES/JS opts out (POSIX-only).

SEMANTIC DIVERGENCE (handler delivery): CPython runs the Python handler between
bytecodes when the signal arrives. The native floor records deliveries in a
per-signum counter (async-signal-safe); the host loop drains via
`pending(sig)` / `consume(sig)`. This fixture compares scalar constants and
SIG_IGN installation, then checks delivery via a direct handler hit count on sv
and `consume(SIGUSR2) > 0` on na after `send_self`.
"""

import os;
import signal;

glob _handler_box: list[int] = [0];


def _on_usr2(sig: int, frame: any) -> None {
    _handler_box[0] = _handler_box[0] + 1;
}


def signal_py -> dict {
    ign_ok: int = 0;
    signal.signal(signal.SIGUSR1, signal.SIG_IGN);
    if signal.getsignal(signal.SIGUSR1) == signal.SIG_IGN {
        ign_ok = 1;
    }

    _handler_box[0] = 0;
    signal.signal(signal.SIGUSR2, _on_usr2);
    os.kill(os.getpid(), signal.SIGUSR2);
    handler_hit: int = 1 if _handler_box[0] > 0 else 0;
    signal.signal(signal.SIGUSR2, signal.SIG_DFL);

    return {
        "SIGINT": signal.SIGINT,
        "SIGTERM": signal.SIGTERM,
        "SIG_DFL": signal.SIG_DFL,
        "SIG_IGN": signal.SIG_IGN,
        "ign_ok": ign_ok,
        "handler_hit": handler_hit
    };
}


def signal_cl -> dict {
    return {};
}


def _noop(sig: int) -> None { }


def signal_na -> dict[str, any] {
    ign_ok: int = 0;
    signal.signal(signal.SIGUSR1, signal.SIG_IGN);
    if signal.getsignal(signal.SIGUSR1) == signal.SIG_IGN {
        ign_ok = 1;
    }

    signal.signal(signal.SIGUSR2, _noop);
    signal.send_self(signal.SIGUSR2);
    pending_n: int = signal.consume(signal.SIGUSR2);
    handler_hit: int = 1 if pending_n > 0 else 0;
    signal.signal(signal.SIGUSR2, signal.SIG_DFL);

    return {
        "SIGINT": signal.SIGINT,
        "SIGTERM": signal.SIGTERM,
        "SIG_DFL": signal.SIG_DFL,
        "SIG_IGN": signal.SIG_IGN,
        "ign_ok": ign_ok,
        "handler_hit": handler_hit
    };
}
