"""`id()` on native values, one case per value kind.

A native value is either behind a pointer or is the word itself. Pointer-backed
values have a real address, and that address is the identity. Unboxed scalars
have no object to point at, so the identity is the value's own bits -- two
equal scalars are indistinguishable natively, which is exactly what an
`id()`-keyed dedup wants of them.
"""


obj Node {
    has n: int = 1;
}


def id_alias -> int {
    a = Node(n=1);
    b = a;
    return 1 if id(a) == id(b) else 0;
}


def id_distinct -> int {
    a = Node(n=1);
    c = Node(n=1);
    return 1 if id(a) == id(c) else 0;
}


def id_stable -> int {
    a = Node(n=1);
    first = id(a);
    return 1 if first == id(a) else 0;
}


def id_dedup_set -> int {
    seen: set[int] = set();
    a = Node(n=1);
    b = Node(n=2);
    seen.add(id(a));
    seen.add(id(b));
    seen.add(id(a));
    return len(seen);
}


def id_bfs_visited -> int {
    visited: set[int] = set();
    queue = [Node(n=1), Node(n=2)];
    steps = 0;
    while queue {
        cur = queue.pop();
        if id(cur) in visited {
            continue;
        }
        visited.add(id(cur));
        steps += 1;
    }
    return steps;
}


def id_str_alias -> int {
    s = "hello";
    t = s;
    return 1 if id(s) == id(t) else 0;
}


def id_list_alias -> int {
    xs = [1, 2];
    ys = xs;
    return 1 if id(xs) == id(ys) else 0;
}


def id_int_value -> int {
    return 1 if id(7) == id(7) else 0;
}


def id_int_differs -> int {
    return 1 if id(7) == id(8) else 0;
}


def id_float_stable -> int {
    f = 1.5;
    return 1 if id(f) == id(f) else 0;
}


def id_float_differs -> int {
    return 1 if id(1.5) == id(2.5) else 0;
}
