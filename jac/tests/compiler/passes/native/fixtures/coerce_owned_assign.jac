obj Nd {
    has v: int = 0;
}

# `nxt` is unannotated, so it infers as a boxed element list; `stack = nxt` then
# needs a flavor coercion, and that coercion MINTS a fresh owned list. The
# assignment's retain guard must test the coerced value rather than the
# pre-coercion one, or the fresh list is retained once more than it is released
# and neither it nor anything it holds is ever freed.
def run_coerced(n: int) -> int {
    total = 0;
    i = 0;
    while i < n {
        stack = [Nd(v=i)];
        nxt = [];
        nxt.append(Nd(v=i));
        stack = nxt;
        total = total + len(stack);
        i = i + 1;
    }
    return total;
}
