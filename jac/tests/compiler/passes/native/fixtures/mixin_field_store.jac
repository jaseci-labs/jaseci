"""A direct field *store* through a reference typed as a non-primary base.

`Ctx` is the mixin shape `ContextAwareNode` has in unitree: a small base
carrying one field, mixed into classes that reach it through different
linearizations. Field slots are assigned in MRO order, so `code` lands at a
different index in every concrete class -- 1 in `First`, 4 in `Later`, 5 in
`Deep` -- while a reference narrowed only to `Ctx` knows just `Ctx`'s own
index. A store compiled at that one static index therefore writes a
*neighbouring* field on two of the three classes.

The failure is silent: the store succeeds, the object is well-formed, and
only the values are wrong. So nothing here asks "did it compile". Every
function reads back by value: `code` through the concrete class (so the
read uses the concrete index, not the one the store used), and the sum of
every *other* field, which is a constant per class and only moves if the
store landed in the wrong slot. The store values are chosen to differ from
every default, so a mis-slotted write cannot coincide with what it replaced.

Four store routes are covered, all through a `Ctx`-typed reference: a plain
local, a base-typed parameter, an element of a `list[Ctx]`, and an
augmented assign (which is a read and a store at the same slot). A
dispatched setter on the mixin -- the `set_code_context` workaround idiom --
is included so the direct store can be checked against it.
"""

obj Root {
    has tag: int = 9;
}


obj Ctx(Root) {
    has code: int = 1;

    def set_code(v: int) -> None;
}


obj Wide(Root) {
    has w0: int = 20,
        w1: int = 21,
        w2: int = 22;
}


obj Narrow(Root) {
    has n0: int = 30;
}


# MRO [First, Ctx, Narrow, Root]: `code` at the same index Ctx itself uses.
obj First(Ctx, Narrow) {
    has own_a: int = 40;
}


# MRO [Later, Wide, Ctx, Root]: three of Wide's fields sit ahead of `code`.
obj Later(Wide, Ctx) {
    has own_b: int = 41;
}


# MRO [Deep, Narrow, Wide, Ctx, Root]: four fields ahead of `code`.
obj Deep(Narrow, Wide, Ctx) {
    has own_c: int = 42;
}


"""The workaround idiom: the mixin owns the write, so the body specializes."""
impl Ctx.set_code(v: int) -> None {
    self.code = v;
}


"""Hand back a concrete class behind a reference the caller only sees as Ctx."""
def make(pick: int) -> Ctx {
    if pick == 0 {
        return First();
    }
    if pick == 1 {
        return Later();
    }
    return Deep();
}


"""Read `code` back at the *concrete* class's own index."""
def probe_code(c: Ctx) -> int {
    if isinstance(c, First) {
        return c.code;
    }
    if isinstance(c, Later) {
        return c.code;
    }
    if isinstance(c, Deep) {
        return c.code;
    }
    return -1;
}


"""Sum every field but `code`: a constant per class unless a store strays."""
def probe_neighbours(c: Ctx) -> int {
    if isinstance(c, First) {
        return c.n0 + c.tag + c.own_a;
    }
    if isinstance(c, Later) {
        return c.w0 + c.w1 + c.w2 + c.tag + c.own_b;
    }
    if isinstance(c, Deep) {
        return c.n0 + c.w0 + c.w1 + c.w2 + c.tag + c.own_c;
    }
    return -1;
}


"""Both halves in one number: the stored value and the neighbour checksum."""
def fingerprint(c: Ctx) -> int {
    return probe_code(c) * 10000 + probe_neighbours(c);
}


"""The shape the shim replaced: a store straight through the base-typed local."""
def store_direct(pick: int) -> int {
    c = make(pick);
    c.code = 777;
    return fingerprint(c);
}


"""The same store, read back through the base-typed reference that wrote it."""
def store_then_read_through_base(pick: int) -> int {
    c = make(pick);
    c.code = 777;
    return c.code;
}


"""A store through a base-typed parameter, one call frame away from the class."""
def bump(c: Ctx) {
    c.code = 555;
}


def store_through_param(pick: int) -> int {
    c = make(pick);
    bump(c);
    return fingerprint(c);
}


"""A store through a `list[Ctx]` element: the receiver is a subscript read."""
def store_through_list_elem(pick: int) -> int {
    items: list[Ctx] = [First(), Later(), Deep()];
    items[pick].code = 777;
    return fingerprint(items[pick]);
}


"""The elements the list store did not target keep their default `code`."""
def list_others_untouched(pick: int) -> int {
    items: list[Ctx] = [First(), Later(), Deep()];
    items[pick].code = 777;
    total = 0;
    for i in range(3) {
        if i != pick {
            total = total + probe_code(items[i]);
        }
    }
    return total;
}


"""An augmented assign: a read and a store against the same polymorphic slot."""
def aug_store_direct(pick: int) -> int {
    c = make(pick);
    c.code += 300;
    return fingerprint(c);
}


"""The dispatched-setter route, for comparison against the direct store."""
def store_via_setter(pick: int) -> int {
    c = make(pick);
    c.set_code(777);
    return fingerprint(c);
}


"""Direct store and dispatched setter must agree slot for slot."""
def direct_matches_setter(pick: int) -> int {
    return 1 if store_direct(pick) == store_via_setter(pick) else 0;
}
