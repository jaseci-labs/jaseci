/* Header-free extract: array core control kernels.
 *
 * Source: CPython 3.14.6 Modules/arraymodule.c (pinned reference).
 * Slices: typecode descriptor lookup, resize over-allocation policy,
 * negative-index normalization, slice-bound clamping, iterator advance,
 * and insert/remove memmove sizing.
 *
 * The PyObject protocol glue (getitem/setitem dispatch, frombytes/tobytes,
 * Argument Clinic surfaces) stays in the product facade
 * (jac-py/jacpython/arrayobject.jac); these kernels carry the integer
 * control-state machines verbatim so they can be differentially lifted
 * and ratcheted by c2jac.
 */

typedef long Py_ssize_t; /* LP64, mirrors jacport.h */

/* Descriptor table (LP64 host): typecode -> (itemsize, is_int_signed).
 * Mirrors the static const struct arraydescr descriptors[] scan in
 * arraymodule.c: 'u' is sizeof(wchar_t) == 4, 'l'/'L' are sizeof(long)
 * == 8, 'w' is sizeof(Py_UCS4) == 4. Returns the table index or -1 for
 * an unknown typecode (array_new raises ValueError). */
static const int array_itemsize_table[14] = {
    /* b  B  u  w  h  H  i  I  l  L  q  Q  f  d */
       1, 1, 4, 4, 2, 2, 4, 4, 8, 8, 8, 8, 4, 8
};

static const char array_typecode_table[14] = {
    'b', 'B', 'u', 'w', 'h', 'H', 'i', 'I', 'l', 'L', 'q', 'Q', 'f', 'd'
};

/* Signedness of the integer typecodes ('b','h','i','l','q'); unsigned or
 * non-integral typecodes report 0. Index validity is the caller's duty. */
static const char array_signed_table[14] = {
    1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0
};

int
array_typecode_index(char c)
{
    int i;
    for (i = 0; i < 14; i++) {
        if (array_typecode_table[i] == c) {
            return i;
        }
    }
    return -1;
}

int
array_typecode_itemsize(int idx)
{
    return array_itemsize_table[idx];
}

int
array_typecode_signed(int idx)
{
    return array_signed_table[idx];
}

/* array_resize bypass path: when the current overallocation already covers
 * newsize (and we are within 16 slots of it), realloc is skipped entirely.
 * Mirrors the early return in array_resize. Returns 1 to reuse, 0 to grow. */
int
array_resize_reuse(int allocated, Py_ssize_t size, Py_ssize_t newsize)
{
    if (allocated >= newsize && size < newsize + 16 && allocated > 0) {
        return 1;
    }
    return 0;
}

/* Over-allocation formula from array_resize. The pattern is
 * 0, 4, 8, 16, 25, 34, 46, ... -- milder than list's ~1/8 growth because
 * arrays are presumed memory-critical. `size` is Py_SIZE(self) BEFORE the
 * resize, exactly as the C reads it. */
Py_ssize_t
array_grow_capacity(Py_ssize_t size, Py_ssize_t newsize)
{
    return (newsize >> 4) + (size < 8 ? 3 : 7) + newsize;
}

/* Negative-index normalization shared by array_subscr/array_ass_subscript:
 * i += Py_SIZE(self) for negatives; bounds checking happens separately in
 * array_item (IndexError "array index out of range"). */
Py_ssize_t
array_norm_index(Py_ssize_t i, Py_ssize_t n)
{
    if (i < 0) {
        i += n;
    }
    return i;
}

/* Bounds predicate used after normalization (mirrors array_item). */
int
array_index_ok(Py_ssize_t i, Py_ssize_t n)
{
    return i >= 0 && i < n;
}

/* array_slice boundary clamping. The C mutates ilow then ihigh in order;
 * split into two kernels so the ordering stays explicit at call sites. */
Py_ssize_t
array_slice_clamp_low(Py_ssize_t ilow, Py_ssize_t n)
{
    if (ilow < 0) {
        return 0;
    }
    if (ilow > n) {
        return n;
    }
    return ilow;
}

Py_ssize_t
array_slice_clamp_high(Py_ssize_t ihigh, Py_ssize_t ilow, Py_ssize_t n)
{
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

/* arrayiter_next control kernel: returns the item index to fetch and bumps
 * the cursor, or -1 once the iterator is exhausted (ao released). */
Py_ssize_t
arrayiter_advance(Py_ssize_t index, Py_ssize_t size)
{
    if (index < size) {
        return index;
    }
    return -1;
}

/* Element count moved by memmove on insert at `where` (array_insert) and
 * on slice deletion of d elements (array_ass_subscript shift-back). */
Py_ssize_t
array_move_count(Py_ssize_t n, Py_ssize_t where)
{
    return n - where;
}
