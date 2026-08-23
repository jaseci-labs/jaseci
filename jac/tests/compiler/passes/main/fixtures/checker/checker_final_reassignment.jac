"""Fixture: Final immutability enforcement (issue #7354)."""
import from typing { Final }

obj Config {
    has name: Final[str] = "a";
}

obj Point {
    has x: Final[int];

    def init(x: int) {
        self.x = x;  # OK: no-default Final set in init
    }
}

obj Late {
    has y: Final[int];

    def postinit {
        self.y = 5;  # OK: no-default Final set in postinit
    }
}

obj Tagged {
    has tag: Final[str] = "t";

    def init {
        self.tag = "u";  # <-- Error (Final with default reassigned in init)
    }
}

# Assigning a no-default Final in init is a scope rule, not a count. Repeated
# writes -- sequential, branched, or in a loop -- are all legal inside
# init/postinit, and only a Final that already has a default errors there.
# Pyright behaves identically: on the direct Python equivalent of Pair/Cond/
# LoopInit/Tagged below it reports exactly one diagnostic, on Tagged, in both
# basic and strict mode (verified against 1.1.411). Counting writes instead
# would need definite-assignment analysis the checker does not have, and would
# reject the legal Cond form where exactly one branch runs.
obj Pair {
    has a: Final[int];

    def init {
        self.a = 1;  # OK: init write
        self.a = 2;  # OK: init is not write-counted
    }
}

obj Cond {
    has v: Final[int];

    def init(flag: bool) {
        if flag {
            self.v = 1;  # OK
        } else {
            self.v = 2;  # OK
        }
    }
}

obj LoopInit {
    has w: Final[int];

    def init {
        for i in [1, 2, 3] {
            self.w = i;  # OK: still just an init write
        }
    }
}

# The symbol table gives a `for` target its own scope, but the emitted code
# writes the enclosing binding: after the loop the Final holds the last item.
# So a Final name used as a loop variable is a write, not a shadow.
def for_target_writes_final(items: list[int]) -> int {
    t: Final[int] = 1;
    total = t;
    for t in items {  # <-- Error (Final overwritten by the loop target)
        total += t;
    }
    return total;
}

# Only the initializer of the declaring archetype may set a no-default Final.
def init(self: Point) {
    self.x = 999;  # <-- Error (free function, not a method of Point)
}

obj Heir(Point) {
    def init {
        super.init(1);
        self.x = 999;  # <-- Error (subclass initializer, not the declaring one)
    }
}

# Bare `Final` (no subscript) infers the declared type from the initializer.
# This lives in a function so it is unambiguously a local: at `with entry`
# statement level the same line parses as a module global, and `jac fmt`
# rewrites it to `glob b: Final = 99;`.
def bare_final_infers -> int {
    b: Final = 99;  # OK: bare Final infers from value
    return b;
}

glob RATE: Final[float] = 1.5;

with entry {
    c = Config(name="custom");  # OK: constructor initialization
    print(c.name);  # OK: reading a Final attribute
    p = Point(3);
    print(p.x);

    y: Final[int] = 10;  # OK: declaring assignment
    print(y + bare_final_infers());

    c.name = "b";  # <-- Error (Final attribute reassigned)
    y = 2;  # <-- Error (Final local reassigned)
    y += 1;  # <-- Error (augmented assignment)
    (y, w) = (1, 2);  # <-- Error (unpacking into Final)
    del y;  # <-- Error (deleting a Final)
    RATE = 2.0;  # <-- Error (Final glob reassigned)
    print(w);
}
