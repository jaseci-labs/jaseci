/* Header-free extract: _collections deque integer kernels.
 *
 * Source: CPython 3.14.6 Modules/_collectionsmodule.c (pinned reference).
 * Slices: valid_index single-compare bounds check, NEEDS_TRIM unsigned
 * maxlen test, deque_index start/stop normalization ladder, _deque_rotate
 * step reduction (halflen wraparound), block-locate div/mod arithmetic
 * shared by deque_item/deque_ass_item, insert() path selection, inplace
 * repeat maxlen caps, and __sizeof__ block counting.
 *
 * The PyObject glue (block-linked storage, iterators, defaultdict,
 * tuplegetter, module state) stays in the product facade
 * (jac-py/jacpython/_collectionsmodule.jac); these kernels carry the
 * integer control-state machines verbatim so they can be differentially
 * lifted and ratcheted by c2jac.
 */

typedef long Py_ssize_t; /* LP64, mirrors jacport.h */
typedef unsigned long long size_t_ull; /* (size_t) cast stand-in */

#define BLOCKLEN 64

/* valid_index(): single unsigned compare for 0 <= i < limit. */
int
deque_valid_index(Py_ssize_t i, Py_ssize_t limit)
{
    return (size_t_ull)i < (size_t_ull)limit;
}

/* NEEDS_TRIM(): true whenever 0 <= maxlen < size (single unsigned test). */
int
deque_needs_trim(Py_ssize_t maxlen, Py_ssize_t size)
{
    return (size_t_ull)maxlen < (size_t_ull)size;
}

/* deque_index_impl() prologue, phase 1: negative-start clamp. */
Py_ssize_t
deque_norm_start(Py_ssize_t start, Py_ssize_t size)
{
    if (start < 0) {
        start += size;
        if (start < 0)
            start = 0;
    }
    return start;
}

/* deque_index_impl() prologue, phase 2: negative-stop clamp + upper bound. */
Py_ssize_t
deque_norm_stop(Py_ssize_t stop, Py_ssize_t size)
{
    if (stop < 0) {
        stop += size;
        if (stop < 0)
            stop = 0;
    }
    if (stop > size)
        stop = size;
    return stop;
}

/* deque_index_impl() prologue, phase 3: start/stop coupling. */
Py_ssize_t
deque_norm_pair(Py_ssize_t start, Py_ssize_t stop)
{
    if (start > stop)
        start = stop;
    return start;
}

/* _deque_rotate() step reduction: fold |n| into (-halflen, halflen]. */
/* NOTE: the reduction uses `n = n % len` rather than `n %= len` so the
 * modulo reaches the leaf-binary truncating-division lowering (C semantics:
 * quotient/remainder truncate toward zero for negative n). */
Py_ssize_t
deque_rotate_delta(Py_ssize_t n, Py_ssize_t len)
{
    Py_ssize_t halflen = len >> 1;
    if (n > halflen || n < -halflen) {
        n = n % len;
        if (n > halflen)
            n -= len;
        else if (n < -halflen)
            n += len;
    }
    return n;
}

/* deque_item_lock_held()/deque_ass_item_lock_held() block locate:
 * logical position i maps to block number (i + leftindex) / BLOCKLEN
 * with in-block offset (i + leftindex) % BLOCKLEN. */
/* The locate arithmetic keeps operands in leaf ID/constant position (plain
 * signed division on provably non-negative values), matching how the C
 * unsigned-cast idiom behaves on every representable deque state. */
Py_ssize_t
deque_block_no(Py_ssize_t i, Py_ssize_t leftindex)
{
    Py_ssize_t pos = i + leftindex;
    return pos / BLOCKLEN;
}

Py_ssize_t
deque_block_off(Py_ssize_t i, Py_ssize_t leftindex)
{
    Py_ssize_t pos = i + leftindex;
    return pos % BLOCKLEN;
}

/* Right-side walk distance for the second half of a locate:
 * blocks to step backwards from rightblock. */
Py_ssize_t
deque_blocks_from_right(Py_ssize_t leftindex, Py_ssize_t size,
                        Py_ssize_t blockno)
{
    Py_ssize_t lastpos = leftindex + size - 1;
    return lastpos / BLOCKLEN - blockno;
}

/* deque_item_lock_held() walk-direction choice: scan from the left when
 * the index sits in the first half of the deque. */
int
deque_locate_from_left(Py_ssize_t index, Py_ssize_t size)
{
    return index < (size >> 1);
}

/* deque_ass_item_lock_held() walk-direction choice: note the <= and the
 * (len+1)>>1 halflen, both distinct from deque_item's < and len>>1. */
int
deque_ass_locate_from_left(Py_ssize_t index, Py_ssize_t len)
{
    Py_ssize_t halflen = (len + 1) >> 1;
    return index <= halflen;
}

/* deque_insert_impl() path selection.
 * 0: plain append (index >= n), 1: appendleft (index <= -n or 0),
 * 2: rotate(-index) + appendleft + rotate(index) for 0 < index,
 * 3: rotate(-index) + append + rotate(index) for index < 0. */
int
deque_insert_path(Py_ssize_t index, Py_ssize_t n)
{
    if (index >= n)
        return 0;
    if (index <= -n || index == 0)
        return 1;
    if (index < 0)
        return 3;
    return 2;
}

/* deque_inplace_repeat_lock_held(), general case: reduce repetitions so
 * n * size stays within maxlen. */
Py_ssize_t
deque_repeat_cap(Py_ssize_t n, Py_ssize_t size, Py_ssize_t maxlen)
{
    Py_ssize_t top = maxlen + size - 1;
    if (maxlen >= 0 && n * size > maxlen)
        n = top / size;
    return n;
}

/* deque_inplace_repeat_lock_held(), single-element fast path cap. */
Py_ssize_t
deque_repeat_one_cap(Py_ssize_t n, Py_ssize_t maxlen)
{
    if (maxlen >= 0 && n > maxlen)
        n = maxlen;
    return n;
}

/* deque_inplace_repeat_lock_held() overflow guard:
 * size > PY_SSIZE_T_MAX / n means the repeat cannot allocate. */
int
deque_repeat_overflows(Py_ssize_t size, Py_ssize_t n)
{
    return (size_t_ull)size > 0x7fffffffffffffffULL / (size_t_ull)n;
}

/* deque___sizeof___impl(): number of whole blocks spanned. */
Py_ssize_t
deque_sizeof_blocks(Py_ssize_t leftindex, Py_ssize_t size)
{
    Py_ssize_t span = leftindex + size + BLOCKLEN - 1;
    return span / BLOCKLEN;
}
