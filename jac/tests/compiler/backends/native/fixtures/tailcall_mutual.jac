"""Tail-call fixture: mutual recursion — the interpreter-handler shape."""
def tc_is_even(n: int) -> int {
    if n == 0 {
        return 1;
    }
    return tc_is_odd(n - 1);
}

def tc_is_odd(n: int) -> int {
    if n == 0 {
        return 0;
    }
    return tc_is_even(n - 1);
}
