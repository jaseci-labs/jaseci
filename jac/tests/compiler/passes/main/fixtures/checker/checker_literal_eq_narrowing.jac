"""Bug #7261: `x == "literal"` must narrow x, just as it does for int/float/bool.

`==`/`!=` against a literal narrows the left operand to that literal type
(`LITERAL_EQ`/`LITERAL_NE`). The rule fired for `int`, `float` and `bool`
literals but never for strings, because a string literal is not spelled as a
bare node: the parser always wraps it (even a lone `"node"`, and equally an
implicit concatenation or a parenthesized literal). Literal-ness is a property
of the operand's *type*, so it is read off the type rather than guessed from
the shape of the expression.

Every function here is sound narrowing, so this fixture must type-check with
zero errors.
"""

# ============================================================================
# The reported repro: a plain string literal
# ============================================================================

def eq_str(v: str | None) -> str {
    r: str = "obj";
    if v == "node" {
        r = v;
    }
    return r;
}

def ne_str(v: str | None) -> str {
    r: str = "other";
    if v != "node" {
        return r;
    }
    return v;
}

def eq_str_ternary(v: str | None) -> str {
    return v if v == "node" else "obj";
}

# ============================================================================
# The same literal, spelled differently
# ============================================================================

def eq_str_implicit_concat(v: str | None) -> str {
    r: str = "obj";
    if v == "no" "de" {
        r = v;
    }
    return r;
}

def eq_str_parenthesized(v: str | None) -> str {
    r: str = "obj";
    if v == ("node") {
        r = v;
    }
    return r;
}

# ============================================================================
# Baselines that already worked and must not regress
# ============================================================================

def eq_int(v: int | None) -> int {
    r: int = 0;
    if v == 5 {
        r = v;
    }
    return r;
}

def eq_float(v: float | None) -> float {
    r: float = 0.0;
    if v == 1.5 {
        r = v;
    }
    return r;
}

def eq_bool(v: bool | None) -> bool {
    r: bool = False;
    if v == True {
        r = v;
    }
    return r;
}

# ============================================================================
# A non-literal operand must not narrow: `v` may still be None in the body,
# so the assignment below has to stay an error-free no-op on `r`'s type.
# ============================================================================

def eq_non_literal(v: str | None, w: str) -> str {
    r: str = "obj";
    if v == w {
        r = "matched";
    }
    return r;
}

# ============================================================================
# `!=` narrows only where the members are literals themselves. Ruling out one
# value cannot rule out a whole class, so these are the cases where it does
# carry information: every remaining member is spelled out.
# ============================================================================

def ne_literal_union_to_none(v: Literal["a"] | None) -> None {
    if v != "a" {
        return v;
    }
    return None;
}

def ne_literal_union_keeps_sibling(v: Literal["a"] | Literal["b"] | None) -> str {
    if v == "a" {
        return v;
    }
    return "obj";
}

# ============================================================================
# Each of `==` and `!=` has one edge that narrows by matching rather than by
# subtracting, and that edge holds for every literal: reaching it proves the
# comparison succeeded, so the compared class is what the value is.
# ============================================================================

def ne_int_else_branch(v: int | None) -> int {
    if v != 5 {
        return 0;
    }
    return v;
}

def ne_str_else_branch(v: str | None) -> str {
    if v != "node" {
        return "obj";
    }
    return v;
}
