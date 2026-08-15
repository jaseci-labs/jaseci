"""The intersection must not over-narrow: the negative edge still subtracts."""

obj Carrier {
    has label: str = "c";
}

obj Marker {
    has weight: int = 0;
}

# `Marker` is subtracted from `Carrier | None` on the false edge, so what is
# left is `Carrier | None` and `.label` is still missing from NoneType.
def negative_edge_keeps_declared(x: (Carrier | None)) -> str {
    if isinstance(x, Marker) {
        return "m";
    }
    return x.label;
}

# The synthesized class is not a licence to reach members neither side has.
def no_invented_members(x: (Carrier | None)) {
    if isinstance(x, Marker) {
        print(x.missing);
    }
}
