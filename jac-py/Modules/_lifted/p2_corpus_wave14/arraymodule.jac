glob Py_ssize_t = int;

glob array_itemsize_table: list[int] = [1, 1, 4, 4, 2, 2, 4, 4, 8, 8, 8, 8, 4, 8];

glob array_typecode_table: list[int] = [
         98,
         66,
         117,
         119,
         104,
         72,
         105,
         73,
         108,
         76,
         113,
         81,
         102,
         100
     ];

glob array_signed_table: list[int] = [1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0];

def array_typecode_index(c: int) -> int {
    i: int = 0;
    for i = 0 while i < 14 with i += 1 {
        if (array_typecode_table[i] == c) {
            return i;
        }
    }

    return -1;
}

def array_typecode_itemsize(idx: int) -> int {
    return array_itemsize_table[idx];
}

def array_typecode_signed(idx: int) -> int {
    return array_signed_table[idx];
}


def array_resize_reuse(allocated: int, size: int, newsize: int) -> int {
    if (((allocated >= newsize) and (size < (newsize + 16))) and (allocated > 0)) {
        return 1;
    }

    return 0;
}


def array_grow_capacity(size: int, newsize: int) -> int {
    return (((newsize >> 4) + 3 if (size < 8) else 7) + newsize);
}


def array_norm_index(i: int, n: int) -> int {
    if (i < 0) {
        i += n;
    }

    return i;
}


def array_index_ok(i: int, n: int) -> int {
    return ((i >= 0) and (i < n));
}


def array_slice_clamp_low(ilow: int, n: int) -> int {
    if (ilow < 0) {
        return 0;
    }

    if (ilow > n) {
        return n;
    }

    return ilow;
}

def array_slice_clamp_high(ihigh: int, ilow: int, n: int) -> int {
    if (ihigh < 0) {
        ihigh = 0;
    }

    if (ihigh < ilow) {
        return ilow;
    }

    if (ihigh > n) {
        return n;
    }

    return ihigh;
}


def arrayiter_advance(index: int, size: int) -> int {
    if (index < size) {
        return index;
    }

    return -1;
}


def array_move_count(n: int, where: int) -> int {
    return (n - where);
}
