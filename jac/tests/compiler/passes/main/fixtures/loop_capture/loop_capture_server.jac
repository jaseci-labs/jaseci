"""Fixture: the same capture shape in server code (#8168).

Python's late-binding closure is documented behaviour there and the emitted
code matches it, so W6009 -- a client-codespace diagnostic about a divergence
the author cannot see -- must not fire on this module.
"""

def collect(items: list[str]) -> list {
    out: list = [];
    for s in items {
        label = s.upper();
        out.append(lambda { print(label); });
    }
    return out;
}

with entry {
    print(len(collect(["a", "b"])));
}
