"""NEGATIVE fixture: a return-call inside try must NOT become musttail —
the exception frame must stay armed while the callee runs so its raise
is caught by the enclosing except."""
def tc_boom(n: int) -> int {
    if n == 0 {
        raise ValueError("deep");
    }
    return tc_boom(n - 1);
}

def tc_guarded -> int {
    try {
        return tc_boom(200);
    } except Exception as e {
        return -1;
    }
}
