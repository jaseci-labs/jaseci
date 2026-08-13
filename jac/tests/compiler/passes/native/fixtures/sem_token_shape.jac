"""`NameAtom.sem_token`'s shape, reduced to the two things that block it.

Both halves are read back by value, because both have a failure mode that a
seam count cannot see.

An enum member's value is derived from the *syntax* of its initialiser, so a
member written `1 << 0` has no value at all. For a Jac `enum` that silently
becomes `0` -- `CLASS`, `ENUM` and `NAMESPACE` all answer `0`, and no
diagnostic says so -- while a class-form enum (`class M(IntFlag)`, which is
what `JacSemTokenModifier` is) drops the member from its layout entirely and
the read refuses with E5092. `NAMESPACE` and `PARAM` are literals so they
lower today; every other member here is a constant expression, and the ones
below collide with a literal member's value when the fold is missing.

`__class__.__name__` needs the *runtime* class of its receiver. That works
off a receiver whose static type names one archetype (`known_*` below), and
does not work when the static type names none -- `sem_token` reads
`type(self.type).__name__` where `self.type` is `TypeBase | None`, a class
reached through a typing-only import that no native unit holds a struct for.
An `any` slot is the same open receiver in one file.

`sem_token_of` puts both in the shape the real accessor has, including the
`tuple[A, B] | None` return: an absent answer is `None`, and a present one is
a tuple of one member from each enum.

Refs #8039, #8052
"""

import from enum { IntFlag }

enum TokKind: int { NAMESPACE = 0, CLASS = 1 << 1, ENUM = (1 << 1) | 1, PARAM = 7 }

class TokMod(IntFlag) {
    with entry {
        DECLARATION = 1 << 0;
        DEFINITION = 1 << 1;
        READONLY = 1 << 2;
        LITERAL_ONE = 1;
    }
}

obj Node {
    has n: int = 3;
}

obj Leaf(Node) {
    has l: int = 4;
}

obj Branch(Node) {
    has b: int = 5;
}

"""An `any` slot: the receiver's static type names no archetype at all."""
obj Holder {
    has held: any = None;
}


"""A Jac `enum` whose members are constant expressions."""
def kind_of(pick: int) -> int {
    if pick == 0 {
        return TokKind.NAMESPACE;
    }
    if pick == 1 {
        return TokKind.CLASS;
    }
    if pick == 2 {
        return TokKind.ENUM;
    }
    return TokKind.PARAM;
}


"""A class-form enum (`IntFlag`) whose members are constant expressions."""
def mod_of(pick: int) -> int {
    if pick == 0 {
        return TokMod.DECLARATION;
    }
    if pick == 1 {
        return TokMod.DEFINITION;
    }
    if pick == 2 {
        return TokMod.READONLY;
    }
    return TokMod.LITERAL_ONE;
}


"""The two enums combined, the way a `sem_token` return does."""
def kind_and_mod(pick: int) -> int {
    return kind_of(pick) * 100 + mod_of(pick);
}


"""Fill the open slot: 1 -> Leaf, 2 -> Branch, anything else -> Node."""
def _fill(pick: int) -> Holder {
    h = Holder();
    if pick == 1 {
        h.held = Leaf();
    } elif pick == 2 {
        h.held = Branch();
    } else {
        h.held = Node();
    }
    return h;
}


"""`type(x).__name__` where `x`'s static type names no archetype."""
def open_name(pick: int) -> str {
    return type(_fill(pick).held).__name__;
}


def _rank(name: str) -> int {
    if name == "Leaf" {
        return 1;
    }
    if name == "Branch" {
        return 2;
    }
    if name == "Node" {
        return 3;
    }
    return 0;
}


def open_name_rank(pick: int) -> int {
    return _rank(open_name(pick));
}


"""The `__class__` spelling of the same open read."""
def open_dunder_rank(pick: int) -> int {
    return _rank(_fill(pick).held.__class__.__name__);
}


"""The control: a receiver whose static type does name an archetype.

This lowers today, through the class-name constant in vtable slot 0, and has
to keep answering the runtime class rather than the declared one.
"""
def known_name_rank(pick: int) -> int {
    n: Node = Node();
    if pick == 1 {
        n = Leaf();
    } elif pick == 2 {
        n = Branch();
    }
    return _rank(n.__class__.__name__);
}


"""Both halves at once, in `NameAtom.sem_token`'s exact shape.

An open-receiver class-name read selects a member from each enum, and the
pair comes back as `tuple[A, B] | None`.
"""
def sem_token_of(pick: int) -> (tuple[(TokKind, TokMod)] | None) {
    if pick == 0 {
        return None;
    }
    name = type(_fill(pick).held).__name__;
    if name == "Leaf" {
        return (TokKind.CLASS, TokMod.DECLARATION);
    }
    if name == "Branch" {
        return (TokKind.ENUM, TokMod.DEFINITION);
    }
    return (TokKind.PARAM, TokMod.READONLY);
}


"""Decode the option and both members of the tuple back to one int."""
def sem_token_rank(pick: int) -> int {
    tok = sem_token_of(pick);
    if tok is None {
        return -1;
    }
    return tok[0] * 100 + tok[1];
}
