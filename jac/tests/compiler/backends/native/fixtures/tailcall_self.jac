"""Tail-call fixture: self-recursion, scalars only (plan T1)."""
def tc_count(n: int, acc: int) -> int {
    if n == 0 { return acc; }
    return tc_count(n - 1, acc + 1);
}
