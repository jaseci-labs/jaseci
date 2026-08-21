"""Bug #7261 follow-up: `x != "literal"` must not delete the whole class.

`==` against a literal narrows, so it is tempting to read `!=` as the mirror
image and subtract the compared type. It is not: a literal is one value, not a
class. `v != "node"` rules out the single string `"node"` and leaves every
other string standing, so `str | None` must stay `str | None` on the true
branch -- and equally on the false branch of `==`, which is the same branch
spelled the other way round.

Subtracting the class instead left `None`, and the checker then read a live
`str` as `None`: it accepted the assignments below, and native lowering
rejected what it had accepted (E5092, binding a void-typed value).

Every function here must report exactly one error. The narrowing that *does*
carry information -- where the members are literals themselves -- lives in
checker_literal_eq_narrowing.jac.
"""

def ne_str(v: str | None) -> None {
    if v != "node" {
        n: None = v;
    }
    return None;
}

def ne_int(v: int | None) -> None {
    if v != 5 {
        n: None = v;
    }
    return None;
}

def ne_float(v: float | None) -> None {
    if v != 1.5 {
        n: None = v;
    }
    return None;
}

def eq_str_else_branch(v: str | None) -> None {
    if v == "node" {
        return None;
    }
    n: None = v;
    return None;
}

def eq_int_else_branch(v: int | None) -> None {
    if v == 5 {
        return None;
    }
    n: None = v;
    return None;
}

def eq_float_else_branch(v: float | None) -> None {
    if v == 1.5 {
        return None;
    }
    n: None = v;
    return None;
}
