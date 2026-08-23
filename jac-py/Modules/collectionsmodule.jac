# c2jac: 6 best-effort sites lowered with known infidelities (behavior/hole sites quarantine their containing function; module-scope holes remain as `__c_unsupported__`):
#   L10 [W4201] cast to `size_t_ull` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L10 [W4201] cast to `size_t_ull` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L17 [W4201] cast to `size_t_ull` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L17 [W4201] cast to `size_t_ull` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L161 [W4201] cast to `size_t_ull` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L161 [W4201] cast to `size_t_ull` elided — representation-changing conversion (truncation/narrowing/discard) not applied

def c_idiv(a: int, b: int) -> int {
    q = a // b;
    return q + (1 if (a % b != 0) and ((a < 0) != (b < 0)) else 0);
}

def c_imod(a: int, b: int) -> int {
    return a - c_idiv(a, b) * b;
}

glob Py_ssize_t = int;
glob size_t_ull = int;


def deque_valid_index(i: int, limit: int) -> int {
    return (i < limit);
}


def deque_needs_trim(maxlen: int, size: int) -> int {
    return (maxlen < size);
}


def deque_norm_start(start: int, size: int) -> int {
    if (start < 0) {
        start += size;
        if (start < 0) {
            start = 0;
        }
    }

    return start;
}


def deque_norm_stop(stop: int, size: int) -> int {
    if (stop < 0) {
        stop += size;
        if (stop < 0) {
            stop = 0;
        }
    }

    if (stop > size) {
        stop = size;
    }
    return stop;
}


def deque_norm_pair(start: int, stop: int) -> int {
    if (start > stop) {
        start = stop;
    }
    return start;
}


def deque_rotate_delta(n: int, len: int) -> int {
    halflen: int = len >> 1;
    if ((n > halflen) or (n < -halflen)) {
        n = c_imod(n, len);
        if (n > halflen) {
            n -= len;
        } elif (n < -halflen) {
            n += len;
        }
    }

    return n;
}


def deque_block_no(i: int, leftindex: int) -> int {
    pos: int = i + leftindex;
    return c_idiv(pos, 64);
}

def deque_block_off(i: int, leftindex: int) -> int {
    pos: int = i + leftindex;
    return c_imod(pos, 64);
}


def deque_blocks_from_right(leftindex: int, size: int, blockno: int) -> int {
    lastpos: int = (leftindex + size) - 1;
    return (c_idiv(lastpos, 64) - blockno);
}


def deque_locate_from_left(index: int, size: int) -> int {
    return (index < (size >> 1));
}


def deque_ass_locate_from_left(index: int, len: int) -> int {
    halflen: int = (len + 1) >> 1;
    return (index <= halflen);
}


def deque_insert_path(index: int, n: int) -> int {
    if (index >= n) {
        return 0;
    }
    if ((index <= -n) or (index == 0)) {
        return 1;
    }
    if (index < 0) {
        return 3;
    }
    return 2;
}


def deque_repeat_cap(n: int, size: int, maxlen: int) -> int {
    top: int = (maxlen + size) - 1;
    if ((maxlen >= 0) and ((n * size) > maxlen)) {
        n = c_idiv(top, size);
    }
    return n;
}


def deque_repeat_one_cap(n: int, maxlen: int) -> int {
    if ((maxlen >= 0) and (n > maxlen)) {
        n = maxlen;
    }
    return n;
}


def deque_repeat_overflows(size: int, n: int) -> int {
    return (size > c_idiv(9223372036854775807, n));
}


def deque_sizeof_blocks(leftindex: int, size: int) -> int {
    span: int = ((leftindex + size) + 64) - 1;
    return c_idiv(span, 64);
}
