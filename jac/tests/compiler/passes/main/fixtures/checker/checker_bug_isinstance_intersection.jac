"""isinstance narrowing keeps the declared type as a constraint."""

obj Carrier {
    has label: str = "c";
}

obj Marker {
    has weight: int = 0;
}

obj CarrierSub(Carrier) {
    has extra: int = 0;
}

# `Carrier` and `Marker` are unrelated, so a value that is both is a value of
# a synthesized subclass of the two: every member of either side is reachable.
def unrelated_keeps_both(x: (Carrier | None)) -> int {
    if isinstance(x, Marker) {
        return x.weight + len(x.label);
    }
    return 0;
}

# When the two are related by subclassing the more specific one wins, with no
# synthesized class in the way.
def related_narrows_to_subclass(x: (Carrier | None)) -> int {
    if isinstance(x, CarrierSub) {
        return x.extra + len(x.label);
    }
    return 0;
}

# Primitives have distinct instance layouts, so no class can derive from two of
# them; the unrelated member drops instead of being intersected.
def primitives_do_not_intersect(x: (int | str)) -> int {
    if isinstance(x, str) {
        return len(x);
    }
    return x + 1;
}

def tuple_form_keeps_both(x: (Carrier | None)) -> int {
    if isinstance(x, (Marker, CarrierSub)) {
        return len(x.label);
    }
    return 0;
}
