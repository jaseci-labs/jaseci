"""A generic function over a borrowed list returning an element (#8984 A5)."""

obj Box { has v: int = 0; }

def first[T](xs: &list[T]) -> T { return xs[0]; }

def run -> int {
    xs: list[own Box] = [];
    xs.append(Box(v=7));
    return first(&xs).v;
}

with entry { print(run()); }
