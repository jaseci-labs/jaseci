"""T5 fixture: the accumulator idiom `return base if done else self(...)` —
the else arm is a tail position and must musttail; the then arm returns a
plain value in its own branch."""
def tc_tern(n: int, acc: int) -> int {
    return acc if n == 0 else tc_tern(n - 1, acc + n);
}
def tc_tern_drive(n: int) -> int {
    return tc_tern(n, 0);
}
