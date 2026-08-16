"""A flat archetype whose own module gives it no vtable slot.

Nothing here subclasses `Anchor` and nothing names it in an `isinstance`, so
`LayoutPass` lays it out with `depth` at slot 0. A consumer subclass needs a
vtable of its own, which would have to sit at slot 0 too, and no assignment
satisfies both units at once.
"""

obj Anchor {
    has depth: int = 0;
}

def make_anchor(d: int) -> Anchor {
    return Anchor(depth=d);
}
