"""`Any` is an annotation the native lane erases, like `ClassVar` beside it.

Nothing here needs `typing` at run time: `Any` appears only where a type is
written, and the native lane already lowers such a module when it is forced.
What it could not do is *infer* one native, because the pre-scan's
compile-time import vocabulary did not admit the name.

The glob is here on purpose. A `TypeAlias`-annotated glob is a declaration
the backend must skip; an `Any`-annotated one is an ordinary global that has
to survive, which is why `Any` belongs beside `ClassVar` rather than beside
`TypeAlias`.
"""

import from typing { Any }

glob TAGGED: Any = 7;


obj Holder {
    has payload: Any = 0,
        count: int = 0;
}


def stash(h: Holder, v: Any) -> int {
    h.payload = v;
    h.count += 1;
    return h.count;
}


def total(h: Holder) -> int {
    return h.count + TAGGED;
}
