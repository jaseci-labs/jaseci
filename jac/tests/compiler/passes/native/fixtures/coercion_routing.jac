"""Coercion routing at the three unrouted native seams (N2).

`_coerce_type` already implements optional wrapping and checked
unwrapping, but only local stores and decorated calls routed through it.
This fixture pins the three seams that did not:

1. method call arguments, in both directions (a plain value into a
   `T | None` parameter, and a narrowed `T | None` value into a `T`
   parameter);
2. method receivers, i.e. the idiomatic
   `x: list[int] | None = None; x = []; x.append(1);` shape;
3. tuple-unpack assignment stores, where a target's declared type needs a
   wrap or an unwrap.

Every function returns an int so the native result can be compared
against the same source run through the sv/bytecode pathway.
"""

obj Sink {
    has base: int = 0;

    def take_opt(v: int | None) -> int {
        if v is None {
            return -1;
        }
        return self.base + v;
    }

    def take_plain(v: int) -> int {
        return self.base + v * 2;
    }
}

def arg_wrap(n: int) -> int {
    s = Sink(base=10);
    return s.take_opt(n);
}

def arg_wrap_none -> int {
    s = Sink(base=10);
    return s.take_opt(None);
}

def arg_unwrap(n: int) -> int {
    s = Sink(base=10);
    o: int | None = None;
    if n > 0 {
        o = n;
    }
    if o is None {
        return -1;
    }
    return s.take_plain(o);
}

def arg_unwrap_container(flag: int) -> int {
    src: list[int] | None = None;
    if flag > 0 {
        src = [4, 5, 6];
    }
    out: list[int] = [1];
    if src is None {
        return len(out);
    }
    out.extend(src);
    return len(out) * 100 + out[1] * 10 + out[3];
}

def opt_list_receiver(n: int) -> int {
    x: list[int] | None = None;
    x = [];
    x.append(1);
    x.append(n);
    if x is None {
        return -1;
    }
    y: list[int] = x;
    return len(y) * 100 + y[0] * 10 + y[1];
}

def opt_list_receiver_guarded(flag: int) -> int {
    x: list[int] | None = None;
    if flag > 0 {
        x = [];
    }
    if x is None {
        return -1;
    }
    x.append(7);
    x.append(flag);
    y: list[int] = x;
    return y[0] * 10 + y[1];
}

def unpack_wrap(n: int) -> int {
    a: int | None = None;
    b: int | None = None;
    (a, b) = (n, n + 1);
    if a is None or b is None {
        return -1;
    }
    return a * 10 + b;
}

def unpack_unwrap(n: int) -> int {
    a: int | None = n;
    b: int | None = n + 1;
    if a is None or b is None {
        return -1;
    }
    p: int = 0;
    q: int = 0;
    (p, q) = (a, b);
    return p * 10 + q;
}
