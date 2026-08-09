"""Flow-sensitive optional narrowing in the native backend.

After a test that proves an optional is non-None, uses of that value on the
proven path must see the narrowed type -- exactly like the sv/bytecode
backend. `list[int] | None` (pointer payload) and `int | None` (scalar
payload) lower differently, so both are pinned here, along with the
`is None` early-return guard, the `is not None` positive branch, if/else,
plain truthiness, `!= None`, an early `continue`, an early `raise`, and
`isinstance` narrowing of a boxed union.

The functions from `redundant_guard` down are the negative half. A rebind and
a loop back-edge both re-widen the value, so the tag must still be read there;
None must never be read as a payload. A redundant `is None` on an
already-proven value must still compile to a tag read rather than a comparison
against the bare payload -- for a float payload that comparison becomes
`fcmp une x, 0.0` and calls a non-zero float None. Truthiness of an
already-proven container must stay `len > 0`.
"""

def make(n: int) -> list[int] | None {
    if n <= 0 {
        return None;
    }
    out: list[int] = [];
    i = 0;
    while i < n {
        out.append(i * 2);
        i += 1;
    }
    return out;
}

def pick(n: int) -> int | None {
    if n > 0 {
        return n * 3;
    }
    return None;
}

def ptr_guard_is_none(n: int) -> int {
    ids = make(n);
    if ids is None {
        return -1;
    }
    return len(ids);
}

def ptr_is_not_none(n: int) -> int {
    ids = make(n);
    if ids is not None {
        return ids[0] + len(ids);
    }
    return -1;
}

def ptr_if_else(n: int) -> int {
    ids = make(n);
    out = 0;
    if ids is None {
        out = -1;
    } else {
        out = len(ids) * 10;
    }
    return out;
}

def ptr_truthy(n: int) -> int {
    ids = make(n);
    if ids {
        return len(ids) + 100;
    }
    return -1;
}

def ptr_ne_none(n: int) -> int {
    ids = make(n);
    if ids != None {
        return len(ids) + 200;
    }
    return -1;
}

def scalar_guard(n: int) -> int {
    v = pick(n);
    if v is None {
        return -1;
    }
    return v + 1;
}

def scalar_continue_guard(n: int) -> int {
    total = 0;
    i = 0;
    while i < n {
        v = pick(i - 1);
        i += 1;
        if v is None {
            continue;
        }
        total += v;
    }
    return total;
}

def scalar_raise_guard(n: int) -> int {
    v = pick(n);
    if v is None {
        raise ValueError("no value");
    }
    return v + 2;
}

def iso_any(k: int) -> int {
    x: any = 0;
    if k > 0 {
        x = k * 4;
    } else {
        x = "nope";
    }
    if isinstance(x, int) {
        return x + 1;
    }
    return -1;
}

def rebind_widens(n: int) -> int {
    v = pick(n);
    if v is None {
        return -1;
    }
    first = v;
    v = pick(n - 5);
    if v is None {
        return first;
    }
    return first + v;
}

def pick_zero(n: int) -> int | None {
    if n > 0 {
        return 0;
    }
    return None;
}

def redundant_guard(n: int) -> int {
    v = pick(n);
    if v is None {
        return -1;
    }
    if v is None {
        return -2;
    }
    return v + 3;
}

def zero_payload_redundant_guard(n: int) -> int {
    v = pick_zero(n);
    if v is None {
        return -1;
    }
    if v is None {
        return -2;
    }
    return v + 7;
}

def pick_float(n: int) -> float | None {
    if n > 0 {
        return n * 1.5;
    }
    return None;
}

def float_none_test_value(n: int) -> int {
    x = pick_float(n);
    if x is None {
        return -1;
    }
    still_none = x is None;
    if still_none {
        return -2;
    }
    return n + 9;
}

def zero_payload_none_test_value(n: int) -> int {
    v = pick_zero(n);
    if v is None {
        return -1;
    }
    still_none = v is None;
    if still_none {
        return -2;
    }
    return v + 9;
}

def truthy_after_guard(n: int) -> int {
    ids = make(n);
    if ids is None {
        return -1;
    }
    if ids {
        return len(ids);
    }
    return -2;
}

def loop_rewiden(n: int) -> int {
    total = 0;
    i = 0;
    while i < 4 {
        v = pick(n - i);
        if v is None {
            total = total - 1;
        } else {
            total = total + v;
        }
        i += 1;
    }
    return total;
}
