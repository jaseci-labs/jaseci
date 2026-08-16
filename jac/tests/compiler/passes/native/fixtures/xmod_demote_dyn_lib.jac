"""Fixture: a dependency seam only the backend's emitter discovers.

`from_code` invokes `Hue` as a constructor, the S5 shape (`TypeFlags(...)`):
no AST-level capability check refuses it, so the demotion verdict exists
only after NaIRGenPass lowers the dependency. `double` must stay native.
"""

enum Hue {
    RED = 1,
    GREEN = 2
}

def from_code(x: int) -> int {
    h = Hue(x);
    return x if h is not None else 0;
}

def double(x: int) -> int {
    return x * 2;
}

with entry {
    print(double(3));
}
