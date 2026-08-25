"""Element-wise tuple comparison across the element kinds that lower
differently: ints in a machine word, bools in an i1, floats in a double, and
strings through the runtime compare."""

def bool_gt(n: int) -> int {
    a: tuple[bool, int] = (True, 1);
    b: tuple[bool, int] = (False, 9);
    return 1 if a > b else 0;
}

def bool_lt(n: int) -> int {
    a: tuple[bool, int] = (True, 1);
    b: tuple[bool, int] = (False, 9);
    return 1 if b < a else 0;
}

def bool_eq(n: int) -> int {
    a: tuple[bool, int] = (True, 1);
    b: tuple[bool, int] = (False, 9);
    return 1 if a == b else 0;
}

def int_lt(n: int) -> int {
    a: tuple[int, str] = (1, "b");
    b: tuple[int, str] = (2, "a");
    return 1 if a < b else 0;
}

def str_lt(n: int) -> int {
    a: tuple[str, str] = ("a", "b");
    b: tuple[str, str] = ("a", "c");
    return 1 if a < b else 0;
}

def float_gt(n: int) -> int {
    a: tuple[float, int] = (1.5, 3);
    b: tuple[float, int] = (0.5, 9);
    return 1 if a > b else 0;
}
