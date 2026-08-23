/* Header-free extract: array growth/overflow guard kernels.
 *
 * Source: CPython 3.14.6 Modules/arraymodule.c (pinned reference).
 * Slices: the PY_SSIZE_T_MAX overflow ladders guarding array_concat,
 * array_repeat, array_do_extend, and array_inplace_repeat, plus the
 * negative-repeat clamps. Wave 14 covered typecode tables, resize
 * policy, index/slice clamps, iterator advance; these slices are the
 * disjoint concatenation/repetition sizing guards.
 *
 * The PyObject glue (newarrayobject allocation, _PyBytes_Repeat
 * memmove, PyErr_NoMemory paths) stays in the product facade
 * (jac-py/jacpython/arrayobject.jac); guards return 1 when the C impl
 * would proceed and 0 where it raises MemoryError, so they can be
 * differentially lifted and ratcheted by c2jac.
 */

typedef long Py_ssize_t; /* LP64, mirrors jacport.h */

#define PY_SSIZE_T_MAX ((Py_ssize_t)9223372036854775807L)

/* array_concat guard: a->ob_descr must match too (TypeError at the call
 * site); this is only the size overflow test. Returns 1 to proceed. */
int
array_concat_size_ok(Py_ssize_t size_a, Py_ssize_t size_b)
{
    return !(size_a > PY_SSIZE_T_MAX - size_b);
}

/* array_repeat negative clamp: n < 0 behaves as n == 0. */
Py_ssize_t
array_repeat_clamp_count(Py_ssize_t n)
{
    if (n < 0) {
        n = 0;
    }
    return n;
}

/* array_repeat guard: (array_length != 0) && (n > PY_SSIZE_T_MAX /
 * array_length) -> MemoryError. Returns 1 to proceed. */
int
array_repeat_size_ok(Py_ssize_t array_length, Py_ssize_t n)
{
    if ((array_length != 0) && (n > PY_SSIZE_T_MAX / array_length)) {
        return 0;
    }
    return 1;
}

/* array_do_extend guard ladder (shared by extend/inplace_concat):
 * self size + bb size overflow, or byte-size overflow through itemsize.
 * Returns 1 to proceed. */
int
array_do_extend_size_ok(Py_ssize_t self_size, Py_ssize_t bb_size,
                        int itemsize)
{
    if ((self_size > PY_SSIZE_T_MAX - bb_size) ||
        ((self_size + bb_size) > PY_SSIZE_T_MAX / itemsize)) {
        return 0;
    }
    return 1;
}

/* array_inplace_repeat guard ladder: only entered when
 * array_size > 0 && n != 1 in the C impl; that gate is kept explicit
 * here so the call site ordering stays verbatim. Returns 1 to proceed,
 * 0 where the C raises MemoryError. */
int
array_inplace_repeat_size_ok(int itemsize, Py_ssize_t array_size,
                             Py_ssize_t n)
{
    if (n < 0) {
        n = 0;
    }
    if ((itemsize != 0) &&
        (array_size > PY_SSIZE_T_MAX / itemsize)) {
        return 0;
    }
    {
        Py_ssize_t size = array_size * itemsize;
        if (n > 0 && size > PY_SSIZE_T_MAX / n) {
            return 0;
        }
    }
    return 1;
}

/* Byte count moved by _PyBytes_Repeat after a repeat: oldbytes = len *
 * itemsize, newbytes = oldbytes * n. Split out because both repeat
 * paths compute it identically once the guards above passed. */
Py_ssize_t
array_repeat_byte_count(Py_ssize_t array_length, int itemsize, Py_ssize_t n)
{
    Py_ssize_t oldbytes = array_length * itemsize;
    return oldbytes * n;
}
