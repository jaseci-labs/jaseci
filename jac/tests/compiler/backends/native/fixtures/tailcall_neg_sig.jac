"""NEGATIVE fixture: post-call coercion / different lowered return type —
musttail requires identical caller/callee signatures."""
def tc_makes(n: int) -> str {
    if n == 0 {
        return "abc";
    }
    return tc_makes(n - 1);
}

def tc_sig_caller(n: int) -> int {
    return len(tc_makes(n));
}
