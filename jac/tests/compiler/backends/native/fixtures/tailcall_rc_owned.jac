"""RC fixture: the recursive fn owns a fresh heap value that is NOT an
argument of the tail-shaped call. v1 may skip TCO or release before the
musttail — either way: no leak, no premature free. tc_owned_drive loops
so a per-call leak is measurable via IR retain/release balance and
behavior stays checkable at safe depth."""
def tc_owned(n: int) -> int {
    if n == 0 { return 0; }
    junk: str = "x" + str(n);
    if len(junk) < 0 { return -1; }
    return tc_owned(n - 1);
}
def tc_owned_drive(iters: int, depth: int) -> int {
    acc: int = 0;
    i: int = 0;
    while i < iters {
        acc = acc + tc_owned(depth);
        i = i + 1;
    }
    return acc;
}
