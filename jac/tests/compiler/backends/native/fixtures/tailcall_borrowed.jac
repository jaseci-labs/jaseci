"""Tail-call fixture: a borrowed RC param (str) rides through the tail
calls, like VM handlers threading frame state. tc_walk_drive gives the
test an i64-only ABI."""
def tc_walk(n: int, tag: str) -> int {
    if n == 0 { return len(tag); }
    return tc_walk(n - 1, tag);
}
def tc_walk_drive(n: int) -> int {
    return tc_walk(n, "tick");
}
