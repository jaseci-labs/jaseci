"""T4 fixture: mutual recursion through INDIRECT calls — each frame loads
the other function into a local and tail-calls through the pointer. Deep
depth requires the indirect musttail (closure/fn-ptr convention)."""
def tc_even_i(n: int) -> int {
    if n == 0 { return 1; }
    f = tc_odd_i;
    return f(n - 1);
}
def tc_odd_i(n: int) -> int {
    if n == 0 { return 0; }
    f = tc_even_i;
    return f(n - 1);
}
def tc_indirect_drive(n: int) -> int {
    return tc_even_i(n);
}
