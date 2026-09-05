"""RC fixture: the tail call's ARGUMENT is an owned local of the caller —
reordered releases must not free the value being handed off."""
def tc_consume(n: int, s: str) -> int {
    if n == 0 {
        return len(s);
    }
    fresh: str = s + "";
    return tc_consume(n - 1, fresh);
}

def tc_handoff_drive(iters: int, depth: int) -> int {
    acc: int = 0;
    i: int = 0;
    while i < iters {
        acc = acc + tc_consume(depth, "abc");
        i = i + 1;
    }
    return acc;
}
