"""FFI floor for the `signal` surface (Mechanism F over libc, POSIX host
only).

How Jac handlers become C signal handlers: glibc's `struct sigaction`
starts with the handler union -- a function pointer. A clib archetype
field annotated `Callable[[i32], None]` lowers to exactly that fn pointer,
and assigning a plain Jac def into it generates a C-callable trampoline
(the established clib-callback path). `sigaction(2)` receives the struct
by auto-materialized C pointer; the previous action lands in an opaque
`bytes` scratch buffer so no NULL pointer ever crosses the ABI.

glibc `struct sigaction` (x86-64/aarch64 LP64): handler@0 (8), sa_mask
128 bytes @8, sa_flags i32 @136, pad, sa_restorer @144 -- 152 bytes.
The libc wrapper supplies its own SA_RESTORER trampoline when called
without that flag, as it does for CPython.

The installed Jac dispatcher only records receipt (per-signum counter +
last-signum) -- it runs on the C signal stack, so it does none of the
allocation a general Jac callback would need. The surface layer exposes
the counters; delivery-to-Jackal-code semantics stay deliberately
poll-based (see `signal.jac`).
"""
# BSD/GNU `signal` takes the handler as a raw address-sized word, so the
# SIG_DFL (0) / SIG_IGN (1) constants install without any callback plumbing.
import from c {
    obj _SigAction {
        has handler: Callable[[i32], None];
        has mask0: i64,
            mask1: i64,
            mask2: i64,
            mask3: i64,
            mask4: i64,
            mask5: i64,
            mask6: i64,
            mask7: i64,
            mask8: i64,
            mask9: i64,
            mask10: i64,
            mask11: i64,
            mask12: i64,
            mask13: i64,
            mask14: i64,
            mask15: i64;
        has flags: i32;
        has restorer_pad: i64;
    }
}

import from c { def sigaction(signum: i32, act: _SigAction, old: bytes) -> i32;  }
import from c { def kill(pid: i32, sig: i32) -> i32;  }
import from c { def getpid() -> i32;  }
import from c { def bsd_signal(signum: i32, handler: i64) -> i64;  }

glob _SA_SIZE: int = 152;

# receipts: index by signum (0..31)
glob _counts: list[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

glob _last: int = -1;


def _on_signal(sig: i32) -> None {
    if sig >= 0 and sig < 32 {
        _counts[sig] = _counts[sig] + 1;
    }
    _last = sig;
}


def _fresh_action() -> _SigAction {
    act: _SigAction = _SigAction();
    return act;
}


def:pub install_dispatcher(signum: int) -> bool {
    # Install the floor dispatcher for `signum`. Returns success.
    act: _SigAction = _fresh_action();
    act.handler = _on_signal;
    old: bytes = b"\x00" * _SA_SIZE;
    return sigaction(signum, act, old) == 0;
}


def:pub install_raw(signum: int, handler_word: int) -> bool {
    # Install SIG_DFL (0) / SIG_IGN (1) via bsd_signal.
    rc: i64 = bsd_signal(signum, handler_word);
    return rc != -1;
}


def:pub count_for(signum: int) -> int {
    if signum < 0 or signum >= 32 {
        return 0;
    }
    return _counts[signum];
}


def:pub take_count(signum: int) -> int {
    if signum < 0 or signum >= 32 {
        return 0;
    }
    n: int = _counts[signum];
    _counts[signum] = 0;
    return n;
}


def:pub last_signal -> int {
    return _last;
}


def:pub raise_to_self(signum: int) -> bool {
    return kill(getpid(), signum) == 0;
}
