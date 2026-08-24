"""Fixture: Final immutability enforcement."""
import from typing { Final }
import from checker_final_source { SHARED_RATE }

# An imported name keeps the Final of the binding it came from, so rebinding it
# in this module is a write. `jac fmt` spells a module-level rebind as `glob`.
glob SHARED_RATE = 3.0;  # <-- Error (imported Final rebound)

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

# Setting a no-default Final in init is a scope rule, not a count, so repeated,
# branched, and looped init writes are all legal. Pyright agrees.
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

# The emitted code writes the enclosing binding, not a fresh one, so a Final
# name used as a loop variable is a write rather than a shadow.
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

# A `self.x: Final[T] = ...` declaration is the declaring assignment, so only a
# later write to the same attribute is an error.
obj Cache {
    has dir: str;

    def postinit {
        self.base: Final[str] = self.dir + "/base";  # OK: declaring assignment
    }

    def relocate(d: str) {
        self.base = d;  # <-- Error (Final attribute written outside its declaration)
    }
}

# Every binding form writes the enclosing name, so each one is a write.
def rebinding_forms(items: list[int], path: str) {
    tail: Final[list[int]] = [];
    handle: Final[str] = "h";
    err: Final[str] = "e";
    (head, *tail) = items;  # <-- Error (starred unpacking target)
    with open(path) as handle {  # <-- Error (with-as target)
        print(head, handle);
    }
    try {
        raise ValueError("x");
    } except Exception as err {  # <-- Error (except-as target)
        print(err);
    }
}

# Bare `Final` infers the declared type from the initializer. It lives in a
# function so it is a local: at entry level `jac fmt` rewrites it to a glob.
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
