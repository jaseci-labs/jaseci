"""A comprehension over an `or`-defaulted optional list.

`[p for p in (items or [])]` is `ownership_check_pass._partition_sugar_reason`
and three of its neighbours. The empty literal on the right has no destination
to take an element flavor from, so it picks one, differs from the operand on
its left, and the two unify at an erased `i8*`. The comprehension then has a
pointer it cannot tell a list layout from.

This must refuse, and refuse cleanly. It used to raise a `TypeError` out of the
IR builder instead.
"""

obj Nd {
    has n: int = 1;
}


def compr_over_or(items: list[Nd] | None) -> int {
    picked = [p for p in (items or [])];
    return len(picked);
}
