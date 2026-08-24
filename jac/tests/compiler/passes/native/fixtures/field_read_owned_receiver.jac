obj Tok {
    has k: int = 0;
}

obj Stream {
    has toks: list[Tok] = [];

    def current -> Tok;
}

# Returns a borrowed element, so the return retains it to hand the caller an
# owned reference -- the shape `Parser.current()` uses over `self.tokens`.
impl Stream.current -> Tok {
    return self.toks[0];
}

# `s.current().k` reads a field off that owned result and then drops it on the
# floor: a method call would have passed the receiver as an argument and the
# call machinery would free it, but a field read only indexes into it. Without
# a release here the element's refcount climbs once per read and neither it nor
# the stream that owns it is ever freed.
def run_reads(n: int) -> int {
    total = 0;
    i = 0;
    while i < n {
        s = Stream(toks=[Tok(k=1)]);
        total = total + s.current().k;
        i = i + 1;
    }
    return total;
}
