"""Inheriting a vtable-less imported archetype stays refused, not guessed.

`FlatKid` cannot both put its vtable pointer where a subclass reads it and
leave `depth` where `xmod_inherit_flat_lib` writes it, so the inherited read
is refused by name. `stays_clean` shares the module to prove the refusal is
this function's alone.
"""

import from xmod_inherit_flat_lib { Anchor, make_anchor }

obj FlatKid(Anchor) {
    has extra: int = 0;
}

def read_inherited -> int {
    k = FlatKid(extra=2);
    return k.depth;
}

def stays_clean(n: int) -> int {
    a = make_anchor(n);
    return a.depth + 1;
}
