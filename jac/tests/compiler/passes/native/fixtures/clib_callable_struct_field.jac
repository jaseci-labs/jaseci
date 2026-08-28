"""Clib struct field typed Callable[[i32], None] lowers as a C fn pointer."""

import from c {
    obj _SigAction {
        has handler: Callable[[i32], None];
        has flags: i32;
    }
}

def _on_signal(sig: i32) -> None { }

def install_dispatcher() -> bool {
    act: _SigAction = _SigAction();
    act.handler = _on_signal;
    return True;
}
