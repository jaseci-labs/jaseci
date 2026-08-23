# c2jac: 6 best-effort sites lowered with known infidelities (behavior/hole sites quarantine their containing function; module-scope holes remain as `__c_unsupported__`):
#   L10 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L28 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L41 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L42 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L60 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L65 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied

def c_idiv(a: int, b: int) -> int {
    q = a // b;
    return q + (1 if (a % b != 0) and ((a < 0) != (b < 0)) else 0);
}

def c_imod(a: int, b: int) -> int {
    return a - c_idiv(a, b) * b;
}

glob Py_ssize_t = int;


def array_concat_size_ok(size_a: int, size_b: int) -> int {
    return not (size_a > (9223372036854775807 - size_b));
}


def array_repeat_clamp_count(n: int) -> int {
    if (n < 0) {
        n = 0;
    }

    return n;
}


def array_repeat_size_ok(array_length: int, n: int) -> int {
    if ((array_length != 0) and (n > c_idiv(9223372036854775807, array_length))) {
        return 0;
    }

    return 1;
}


def array_do_extend_size_ok(self_size: int, bb_size: int, itemsize: int) -> int {
    if (
        (self_size > (9223372036854775807 - bb_size))
        or ((self_size + bb_size) > c_idiv(9223372036854775807, itemsize))
    ) {
        return 0;
    }

    return 1;
}


def array_inplace_repeat_size_ok(itemsize: int, array_size: int, n: int) -> int {
    if (n < 0) {
        n = 0;
    }

    if ((itemsize != 0) and (array_size > c_idiv(9223372036854775807, itemsize))) {
        return 0;
    }

    size: int = array_size * itemsize;
    if ((n > 0) and (size > c_idiv(9223372036854775807, n))) {
        return 0;
    }

    return 1;
}


def array_repeat_byte_count(array_length: int, itemsize: int, n: int) -> int {
    oldbytes: int = array_length * itemsize;
    return (oldbytes * n);
}
