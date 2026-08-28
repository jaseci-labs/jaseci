"""Fixture: clib obj with Callable[[...], ret] fn-pointer field."""

import from c {
    obj _SigAction {
        has handler: Callable[[i32], None];
        has flags: i32;
    }
}
