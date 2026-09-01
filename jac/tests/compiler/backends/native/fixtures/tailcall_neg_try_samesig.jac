"""Regression fixture: a try-enclosed tail call whose prototype MATCHES the
caller. The original neg_try fixture only differed in signature, so the
prototype-mismatch predicate masked a missing try guard — the armed setjmp
frame lives in the caller's stack frame, and a musttail here would let a
raising callee longjmp into reused stack."""
def tc_boom_same(n: int) -> int {
    if n == 0 {
        raise ValueError("boom");
    }
    return tc_boom_same(n - 1);
}
def tc_guarded_same(n: int) -> int {
    try {
        return tc_boom_same(n);
    } except Exception {
        return -1;
    }
}
