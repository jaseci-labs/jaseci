obj Val {
    has n: int = 0;
}

obj Box {
    has _v: Val = Val(n=1);

    has v: Val { getter; }
}

# A property read is a call, and the accessor's own return already retained the
# borrowed field to hand the caller an owned reference. Retaining it again at
# the read site trades the receiver leak for a value leak.
impl Box.v.getter -> Val {
    return self._v;
}

def mk -> Box {
    return Box();
}

def run_props(n: int) -> int {
    total = 0;
    i = 0;
    while i < n {
        total = total + mk().v.n;
        i = i + 1;
    }
    return total;
}
