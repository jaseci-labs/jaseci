"""Multi-statement lambda used as a `has` field default on an obj archetype.

Obj/node `has` defaults lower through ``field(factory=...)``. Multi-statement
bodies must hoist the helper ``def`` into the class body and capture the
function object at class-definition time (not via a deferred name lookup).
"""

obj Formatter {
    has fmt: type = lambda (s: str) -> str {
        up = s.upper();
        up + "!"
    };

    def apply(msg: str) -> str {
        return self.fmt(msg);
    }
}

node Shouter {
    has fmt: type = lambda (s: str) -> str {
        up = s.upper();
        up + "!"
    };
}

with entry {
    f = Formatter();
    print(f.apply("hi"));
    n = Shouter();
    print(n.fmt("bye"));
}
