"""Comparing an optional to an int literal must not erase the int arm.

`if x == 0` rules out one *value* on the false branch, not the whole `int` arm
of `int | None`. Narrowing excluded union members by shared class identity, and
an int literal's type shares `int`'s identity, so `x` collapsed to `NoneType`
after any `== <int literal>` guard and every later guard reasoned from that.
A `str` literal did not collapse its arm, so the two are pinned side by side.

The collapse is silent on its own, because a too-narrow type stays assignable
wherever the correct wider one is. It shows in the type the checker names, so
each fail_ function reports one assignment error either way and the test reads
the reported type rather than the count.

The last two ok_ functions are the shape this was found through, a guard on a
recursive walker's depth. They report nothing with or without the fix, because
the collapsed arm reaches the ternary as Never and Never returns cleanly; they
are here as shape coverage and start discriminating once an operator reads the
narrowed type directly.
"""

def fail_eq_int_literal_names_full_union(x: int | None) -> int {
    if x == 0 {
        return 0;
    }
    return x;
}

def fail_ne_int_literal_names_full_union(x: int | None) -> int {
    if x != 0 {
        return x;
    }
    return 0;
}

def ok_eq_str_literal_already_names_full_union(s: str | None) -> int {
    if s == "" {
        return 0;
    }
    return s;
}

def ok_is_none_still_narrows(x: int | None) -> int {
    if x is None {
        return 0;
    }
    return x;
}

def ok_eq_literal_then_none_guard(x: int | None) -> int {
    if x == 0 {
        return 0;
    }
    if x is None {
        return -1;
    }
    return x;
}

def ok_eq_literal_then_ternary_guard(depth: int | None) -> int {
    if depth == 0 {
        return 0;
    }
    return 0 if (depth is None) else depth;
}

def ok_eq_literal_in_or_chain(depth: int | None, stop: bool) -> int {
    if (stop or (depth == 0)) {
        return 0;
    }
    return 0 if (depth is None) else depth;
}
