"""Genuinely un-inferable list element types (jac#7967 N5, honest-failure half).

`x = []; x.append(7); x.append("seven");` has no single element type, so the
checker widens it to `any` and the backend stores tagged `{tag, payload}`
values. That is a legitimate outcome -- what is not legitimate is comparing one
of those tagged elements against an unboxed value (here `Box.n`, a plain i64
field) and getting a wrong answer or invalid IR. Either both sides go through
the tagged representation, or the compile fails loudly.
"""

obj Box {
    has n: int = 0;
}

def mixed_elem_eq -> int {
    b = Box(n=7);
    x = [];
    x.append(7);
    x.append("seven");
    if x[0] == b.n {
        return 1;
    }
    return 0;
}

def mixed_elem_eq_miss -> int {
    b = Box(n=3);
    x = [];
    x.append(7);
    x.append("seven");
    if x[0] == b.n {
        return 1;
    }
    return 0;
}

def mixed_elem_ne -> int {
    b = Box(n=3);
    x = [];
    x.append(7);
    x.append("seven");
    if x[0] != b.n {
        return 1;
    }
    return 0;
}

def mixed_elem_lt -> int {
    b = Box(n=9);
    x = [];
    x.append(7);
    x.append("seven");
    if x[0] < b.n {
        return 1;
    }
    return 0;
}

def mixed_elem_str_eq -> int {
    x = [];
    x.append(7);
    x.append("seven");
    if x[1] == "seven" {
        return 1;
    }
    return 0;
}
