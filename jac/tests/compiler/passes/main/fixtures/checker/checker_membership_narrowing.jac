"""Membership (`in`/`not in`) and string-literal (`==`/`!=`) narrowing fixture."""

def test_membership_in_tuple(ak: str | None) -> str {
    return ak if ak in ("node", "walker") else "obj";
}

def test_membership_not_in_tuple(ak: str | None) -> str {
    return "obj" if ak not in ("node", "walker") else ak;
}

def test_membership_in_list(ak: str | None) -> str {
    return ak if ak in ["node", "walker"] else "obj";
}

def test_membership_not_in_list(ak: str | None) -> str {
    return "obj" if ak not in ["node", "walker"] else ak;
}

def test_membership_in_tuple_int(n: int | None) -> int {
    return n if n in (1, 2, 3) else 0;
}

def test_membership_in_tuple_float(f: float | None) -> float {
    return f if f in (1.5, 2.5) else 0.0;
}

def test_membership_in_tuple_bool(b: bool | None) -> bool {
    return b if b in (True, False) else False;
}

def test_string_literal_eq(v: str | None) -> str {
    r: str = "obj";
    if v == "node" {
        r = v;
    }
    return r;
}

def test_string_literal_ne(v: str | None) -> str {
    r: str = "obj";
    if v != "node" {
        r = "obj";
    } else {
        r = v;
    }
    return r;
}

# An f-string evaluates to bare `str`, not a literal, so it never narrows.
def test_error_fstring_is_not_a_literal(v: str | None, x: str) -> str {
    if v != f"no{x}e" {
        return v;  # <-- Error: an f-string is not a literal, v is still str | None
    }
    return "eq";
}

# A literal only excludes itself, so `str` survives every negative direction.
def test_error_ne_keeps_the_base_member(v: str | None) -> str {
    if v != "node" {
        return v;  # <-- Error: != only rules out "node", v is still str | None
    }
    return "eq";
}

def test_error_not_in_keeps_the_base_member(ak: str | None) -> str {
    if ak not in ("node", "walker") {
        return ak;  # <-- Error: not in only rules out the literals, ak is still str | None
    }
    return "in";
}

def test_error_int_ne_keeps_the_base_member(n: int | None) -> int {
    if n != 5 {
        return n;  # <-- Error: != only rules out 5, n is still int | None
    }
    return 5;
}

# A union of literals is narrowed by the negative direction, because a literal
# member is the one thing a literal exclusion covers.
def test_literal_union_ne(k: Literal["node", "walker"]) -> str {
    if k != "node" {
        w: Literal["walker"] = k;
        return w;
    }
    return "node";
}

def test_literal_union_not_in(k: Literal["a", "b", "c"]) -> str {
    if k not in ("a", "b") {
        c: Literal["c"] = k;
        return c;
    }
    return "ab";
}

def test_error_membership_non_literal_element(ak: str | None, other: str) -> str {
    return ak if ak in (other, "walker") else "obj";  # <-- Error: tuple has a non-literal element, no narrowing possible
}

def test_error_membership_false_branch_unnarrowed(ak: str | None) -> str {
    if ak in ("node", "walker") {
        return "matched";
    }
    return ak;  # <-- Error: `in` only narrows the true branch, ak is still str | None here
}
