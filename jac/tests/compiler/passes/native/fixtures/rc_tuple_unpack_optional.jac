"""Tuple-unpack ownership when an optional crosses the store (PR #7982).

Routing the unpack store through `_coerce_type` made two shapes compile
that previously raised at codegen, so their refcount accounting needs a
guard. `_codegen_tuple_unpack` gates its retain and its old-value release
on `retain_fields` (false for a value tuple) and on the target alloca
being a raw pointer, both decided before the coercion:

  - `unpack_into_optional` binds borrowed fields of a boxed tuple into
    `Res | None` locals. It takes neither the retain nor the old-release,
    which is the correct move accounting here: releasing a tuple box does
    not decrement its fields, and scope exit releases each payload once.
    A future change that adds a retain on this path without also changing
    the box release would leak both objects.
  - `unpack_optional_into_plain` overwrites two `Res` locals from optional
    elements of a value tuple. The two overwritten originals are not
    released. `unpack_plain_into_plain` is the same shape with no optional
    anywhere and leaks identically, which is what pins the leak on the
    pre-existing `retain_fields = not is_value` rule for value tuples
    rather than on the optional coercion.

`def drop` bumps a module glob so the tests count destructions exactly
instead of reading freed memory.
"""

glob dropped = 0;

obj Res {
    has tag: int = 0;

    def drop {
        dropped += 1;
    }
}

def make_pair(a: int, b: int) -> tuple[Res, Res] {
    return (Res(tag=a), Res(tag=b));
}

def maybe_res(tag: int) -> Res | None {
    if tag > 0 {
        return Res(tag=tag);
    }
    return None;
}

def unpack_into_optional(a: int, b: int) -> int {
    x: Res | None = None;
    y: Res | None = None;
    (x, y) = make_pair(a, b);
    if x is None or y is None {
        return -1;
    }
    return x.tag * 10 + y.tag;
}

def unpack_optional_into_plain(a: int, b: int) -> int {
    oa = maybe_res(a);
    ob = maybe_res(b);
    if oa is None or ob is None {
        return -1;
    }
    p: Res = Res(tag=0);
    q: Res = Res(tag=0);
    (p, q) = (oa, ob);
    return p.tag * 10 + q.tag;
}

def unpack_plain_into_plain(a: int, b: int) -> int {
    ra = Res(tag=a);
    rb = Res(tag=b);
    p: Res = Res(tag=0);
    q: Res = Res(tag=0);
    (p, q) = (ra, rb);
    return p.tag * 10 + q.tag;
}

def drop_count -> int {
    return dropped;
}
