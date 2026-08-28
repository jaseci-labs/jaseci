"""Native `signal` floor (Mechanism F over libc, POSIX host only).

Constants (`SIGINT`, `SIGTERM`, `SIGHUP`, `SIGWINCH`, ...) plus
`signal(sig, handler)` / `getsignal(sig)`.

DELIVERED SEMANTICS -- the one big divergence: CPython invokes a Python
handler between bytecodes. The native pathway has no interpreter loop to
return to, and a general Jac callback running on the C signal stack is
not allocation-safe, so a handler installation here records the event in
a per-signum counter (async-signal-safe: two integer writes) and the
host loop drains it with `pending(sig)` / `consume(sig)`:

    signal.signal(signal.SIGWINCH, my_handler);   # registers intent
    if signal.consume(signal.SIGWINCH) > 0 {      # host loop, each tick
        my_handler(...);
    }

Passing `signal.SIG_DFL` / `signal.SIG_IGN` installs the raw C constants.
`getsignal` answers what THIS module last installed for `sig`
(SIG_DFL/SIG_IGN/the handler object, or None when untouched) -- it does
not read kernel state.

Supported signals are the fixed POSIX set below; other numbers install
the dispatcher too but their constants must be supplied by the caller.
"""
import from _signal_native {
    install_dispatcher,
    install_raw,
    count_for,
    take_count,
    raise_to_self,
    last_signal
}

glob SIGHUP: int = 1,
     SIGINT: int = 2,
     SIGQUIT: int = 3,
     SIGILL: int = 4,
     SIGABRT: int = 6,
     SIGFPE: int = 8,
     SIGKILL: int = 9,
     SIGSEGV: int = 11,
     SIGPIPE: int = 13,
     SIGALRM: int = 14,
     SIGTERM: int = 15,
     SIGUSR1: int = 10,
     SIGUSR2: int = 12,
     SIGCHLD: int = 17,
     SIGCONT: int = 18,
     SIGSTOP: int = 19,
     SIGTSTP: int = 20,
     SIGTTIN: int = 21,
     SIGTTOU: int = 22,
     SIGWINCH: int = 28;

glob SIG_DFL: int = 0,
     SIG_IGN: int = 1;

glob _installed_dfl_ign: dict[int, int] = {};
glob _installed_handlers: dict[int, any] = {};


def:pub signal(signum: int, handler: any) -> any {
    prev: any = getsignal(signum);
    if handler == SIG_DFL or handler == SIG_IGN {
        if not install_raw(signum, handler) {
            raise ValueError("signal() failed");
        }
        _installed_dfl_ign[signum] = handler;
        return prev;
    }
    # a Jac callable (or anything else): register it and install the
    # async-signal-safe counter dispatcher
    if not install_dispatcher(signum) {
        raise ValueError("signal() failed");
    }
    _installed_handlers[signum] = handler;
    return prev;
}


def:pub getsignal(signum: int) -> any {
    if signum in _installed_handlers {
        return _installed_handlers[signum];
    }
    if signum in _installed_dfl_ign {
        return _installed_dfl_ign[signum];
    }
    return None;
}


"""Deliveries recorded since the last drain."""
def:pub pending(signum: int) -> int {
    return count_for(signum);
}


"""Drain and return the delivery count (host-loop poll)."""
def:pub consume(signum: int) -> int {
    return take_count(signum);
}


"""Test helper: send `signum` to this process."""
def:pub send_self(signum: int) {
    if not raise_to_self(signum) {
        raise ValueError("kill() failed");
    }
}
