"""`**` spread into a callee's `**kwargs` sink, lowered natively.

The sink dict is built at compile time: literal keywords are inserted
directly and each spread operand is merged in with an index loop over the
source dict, so no runtime name-to-slot binding is needed. Encoding below
lets a single i64 return prove both the arity and the actual keys.
"""

def sink(base: int, **kw: int) -> int {
    total = base + len(kw) * 100;
    if "p" in kw {
        total += 1000;
    }
    if "q" in kw {
        total += 2000;
    }
    if "r" in kw {
        total += 4000;
    }
    return total;
}

def forward_all(base: int, **kw: int) -> int {
    return sink(base, **kw);
}

def call_literal_kwargs(n: int) -> int {
    return sink(n, p=1, q=2);
}

def call_forwarded(n: int) -> int {
    return forward_all(n, p=1, r=3);
}

def call_spread_dict(n: int) -> int {
    d: dict[str, int] = {"p": 1, "q": 2, "r": 3};
    return sink(n, **d);
}

def call_spread_plus_literal(n: int) -> int {
    d: dict[str, int] = {"r": 3};
    return sink(n, q=2, **d);
}

def call_spread_empty(n: int) -> int {
    d: dict[str, int] = {};
    return sink(n, **d);
}
