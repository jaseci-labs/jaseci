/* Header-free extract: _struct core format/pack/unpack kernels.
 *
 * Source: CPython 3.14.6 Modules/_struct.c (pinned reference).
 * Slices: byte-order table selection, format-code lookup,
 * native alignment, total-size/repeat-count preparation pass,
 * two's-complement little/big-endian pack with range validation,
 * sign-extending unpack, 's'/'p' byte-string fill rules.
 *
 * The PyObject glue (module state, Struct type, buffer protocol,
 * exceptions, float bit-packing from Python/floatobject.c) stays in
 * the product facade (jac-py/jacpython/_structmodule.jac); these
 * kernels carry the integer control-state machines verbatim so they
 * can be differentially lifted and ratcheted by c2jac.
 */

typedef long Py_ssize_t; /* LP64, mirrors jacport.h */

/* PY_SSIZE_T_MAX on LP64. Written as a plain literal so the c2jac
 * W4201 cast-elision idiom cannot change its value. */
#define PY_SSIZE_T_MAX ((Py_ssize_t)9223372036854775807L)

#define STRUCT_MAXCACHE 100

/* One format-code descriptor (subset of _formatdef without the
 * function pointers: pack/unpack dispatch is table-free here). */
struct struct_formatdef {
    char format;
    Py_ssize_t size;      /* bytes written/consumed */
    Py_ssize_t alignment; /* native mode only; 0 = none */
};

/* Native table for an LP64 little-endian host (x86-64/aarch64 Linux):
 * sizeof(short)=2 sizeof(int)=4 sizeof(long)=8 sizeof(size_t)=8
 * sizeof(long long)=8 sizeof(_Bool)=1 sizeof(float)=4
 * sizeof(double)=8 sizeof(void*)=8. Mirrors native_table[] in
 * Modules/_struct.c. */
static const struct struct_formatdef struct_native_table[] = {
    {'x', 1, 0},
    {'b', 1, 0},
    {'B', 1, 0},
    {'c', 1, 0},
    {'s', 1, 0},
    {'p', 1, 0},
    {'h', 2, 2},
    {'H', 2, 2},
    {'i', 4, 4},
    {'I', 4, 4},
    {'l', 8, 8}, /* LP64: native long is 8 bytes */
    {'L', 8, 8},
    {'n', 8, 8},
    {'N', 8, 8},
    {'q', 8, 8},
    {'Q', 8, 8},
    {'?', 1, 1},
    {'e', 2, 2},
    {'f', 4, 4},
    {'d', 8, 8},
    {'P', 8, 8},
    {0, 0, 0}
};

/* Standard-size table (no alignment). On a little-endian host '=' and
 * '<' share this table exactly like lilendian_table[] in
 * Modules/_struct.c after init_endian_tables() swaps in native pack
 * implementations for matching sizes. */
static const struct struct_formatdef struct_lilendian_table[] = {
    {'x', 1, 0},
    {'b', 1, 0},
    {'B', 1, 0},
    {'c', 1, 0},
    {'s', 1, 0},
    {'p', 1, 0},
    {'h', 2, 0},
    {'H', 2, 0},
    {'i', 4, 0},
    {'I', 4, 0},
    {'l', 4, 0},
    {'L', 4, 0},
    {'q', 8, 0},
    {'Q', 8, 0},
    {'?', 1, 0},
    {'e', 2, 0},
    {'f', 4, 0},
    {'d', 8, 0},
    {0, 0, 0}
};

/* Big-endian table: same standard sizes, consumed MSB-first by the
 * bu_* kernels below (mirrors bigendian_table[]). */
static const struct struct_formatdef struct_bigendian_table[] = {
    {'x', 1, 0},
    {'b', 1, 0},
    {'B', 1, 0},
    {'c', 1, 0},
    {'s', 1, 0},
    {'p', 1, 0},
    {'h', 2, 0},
    {'H', 2, 0},
    {'i', 4, 0},
    {'I', 4, 0},
    {'l', 4, 0},
    {'L', 4, 0},
    {'q', 8, 0},
    {'Q', 8, 0},
    {'?', 1, 0},
    {'e', 2, 0},
    {'f', 4, 0},
    {'d', 8, 0},
    {0, 0, 0}
};

/* whichtable(): select the descriptor table from the optional leading
 * byte-order character and advance past it. Mirrors whichtable() --
 * '@' or no prefix selects native; '<' little-endian; '>' and '!'
 * big-endian; '=' host order with standard sizes. */
const struct struct_formatdef *
struct_whichtable(const char **pfmt)
{
    const char *fmt = (*pfmt)++;
    switch (*fmt) {
    case '<':
        return struct_lilendian_table;
    case '>':
    case '!':
        return struct_bigendian_table;
    case '=': /* host is little-endian */
        return struct_lilendian_table;
    default:
        --*pfmt; /* back out of pointer increment */
        /* _Py_FALLTHROUGH */
    case '@':
        return struct_native_table;
    }
}

/* getentry(): linear scan for the format character. Returns NULL when
 * unknown ("bad char in struct format" at the caller). */
const struct struct_formatdef *
struct_getentry(int c, const struct struct_formatdef *f)
{
    for (; f->format != '\0'; f++) {
        if (f->format == c) {
            return f;
        }
    }
    return NULL;
}

/* align(): round a running size up to the code's native alignment.
 * Only applies when scanning the native table; returns -1 on overflow.
 * Mirrors align() in Modules/_struct.c. */
Py_ssize_t
struct_align(Py_ssize_t size, char c, const struct struct_formatdef *e)
{
    Py_ssize_t extra;

    if (e->format == c) {
        if (e->alignment && size > 0) {
            extra = (e->alignment - 1) - (size - 1) % (e->alignment);
            if (extra > PY_SSIZE_T_MAX - size)
                return -1;
            size += extra;
        }
    }
    return size;
}

/* One compiled format code: what to pack/unpack where. Mirrors
 * formatcode minus the fmtdef pointer (the char is kept instead). */
struct struct_code {
    char fmtdef;
    Py_ssize_t offset;
    Py_ssize_t size;
    Py_ssize_t repeat;
};

/* prepare_s(): first pass over the format string. Fills codes[0..*ncodes]
 * (caller supplies space for at least 33 entries -- the most codes a
 * valid scan below overflow limits can emit is bounded by the format
 * length), plus the total byte size and the number of packable items.
 * Returns 0 on success, -1 on semantic error, -2 on size overflow.
 * Mirrors the two passes of prepare_s() collapsed into one: offsets are
 * identical between passes because the scan is deterministic. */
int
struct_prepare_s(const char *fmt,
                 struct struct_code *codes,
                 Py_ssize_t *out_ncodes,
                 Py_ssize_t *out_size,
                 Py_ssize_t *out_len)
{
    const struct struct_formatdef *f;
    const struct struct_formatdef *e;
    const char *s;
    char c;
    Py_ssize_t size, len, num, itemsize, ncodes;
    struct struct_code *code;

    f = struct_whichtable(&fmt);
    s = fmt;
    size = 0;
    len = 0;
    ncodes = 0;
    code = codes;
    while ((c = *s++) != '\0') {
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\v' || c == '\f')
            continue;
        if ('0' <= c && c <= '9') {
            num = c - '0';
            while ('0' <= (c = *s++) && c <= '9') {
                if (num >= PY_SSIZE_T_MAX / 10 && (
                        num > PY_SSIZE_T_MAX / 10 ||
                        (c - '0') > PY_SSIZE_T_MAX % 10))
                    return -2; /* overflow */
                num = num * 10 + (c - '0');
            }
            if (c == '\0') {
                return -1; /* repeat count given without format specifier */
            }
        }
        else
            num = 1;

        e = struct_getentry(c, f);
        if (e == NULL)
            return -1; /* bad char in struct format */

        switch (c) {
            case 's': /* fallthrough */
            case 'p':
                if (len == PY_SSIZE_T_MAX) {
                    return -2;
                }
                len++;
                ncodes++;
                break;
            case 'x':
                break;
            default:
                if (num > PY_SSIZE_T_MAX - len) {
                    return -2;
                }
                len += num;
                if (num) {
                    ncodes++;
                }
                break;
        }

        itemsize = e->size;
        size = struct_align(size, c, e);
        if (size == -1)
            return -2;

        if (num > (PY_SSIZE_T_MAX - size) / itemsize)
            return -2;
        size += num * itemsize;

        /* Second-pass code emission (offsets match the first pass). */
        if (c == 's' || c == 'p') {
            code->fmtdef = c;
            code->offset = size - num * itemsize;
            code->size = num;
            code->repeat = 1;
            code++;
        } else if (c != 'x' && num) {
            code->fmtdef = c;
            code->offset = size - num * itemsize;
            code->size = itemsize;
            code->repeat = num;
            code++;
        }
    }
    *out_ncodes = ncodes;
    *out_size = size;
    *out_len = len;
    return 0;
}

/* np_*-style native pack for one signed integer of `size` bytes into a
 * possibly-unaligned buffer (host little-endian): memcpy semantics. */
void
struct_np_pack(long long x, Py_ssize_t size, unsigned char *p)
{
    Py_ssize_t i;
    for (i = 0; i < size; i++) {
        p[i] = (unsigned char)(x & 0xffLL);
        x >>= 8;
    }
}

/* lp_int()/lp_uint() little-endian standard pack: LSB first. The value
 * must already be range-checked (see struct_range_check); negative x is
 * stored two's-complement via masking. */
void
struct_lp_pack(long long x, Py_ssize_t size, unsigned char *p)
{
    Py_ssize_t i;
    for (i = 0; i < size; i++) {
        p[i] = (unsigned char)(x & 0xffLL);
        x >>= 8;
    }
}

/* bp_int()/bp_uint() big-endian standard pack: MSB first, mirroring the
 * do { q[--i] = ...; x >>= 8; } while loop in Modules/_struct.c. */
void
struct_bp_pack(long long x, Py_ssize_t size, unsigned char *p)
{
    Py_ssize_t i;
    i = size;
    do {
        p[--i] = (unsigned char)(x & 0xffLL);
        x >>= 8;
    } while (i > 0);
}

/* Range validation shared by all integer pack paths. Returns 0 when
 * `x` fits the signedness/width, -1 otherwise. For native width 8 this
 * is the full long long / unsigned long long domain; for standard sizes
 * it matches the RANGE_ERROR bounds in _struct.c:
 *   signed n-byte: -(1 << (n*8-1)) .. (1 << (n*8-1)) - 1
 *   unsigned n-byte: 0 .. (1 << (n*8)) - 1
 * `is_unsigned` selects the unsigned window (also used for H/I/L/Q). */
int
struct_range_check(long long x, Py_ssize_t size, int is_unsigned)
{
    if (is_unsigned) {
        if (x < 0)
            return -1;
        if (size >= 8)
            return 0; /* whole u64 domain */
        {
            unsigned long long maxint = 1ULL << (size * 8);
            if ((unsigned long long)x >= maxint)
                return -1;
        }
        return 0;
    }
    if (size >= 8)
        return 0; /* whole i64 domain */
    {
        long long limit = 1LL << (size * 8 - 1);
        if (x < -limit || x > limit - 1)
            return -1;
    }
    return 0;
}

/* nu_short/nu_int/... native unpack (little-endian host) and
 * lu_* standard little-endian unpack share this: assemble LSB-first,
 * then sign-extend from `size` bytes. */
long long
struct_unpack_le(const unsigned char *p, Py_ssize_t size, int is_signed)
{
    unsigned long long x = 0;
    Py_ssize_t i;
    for (i = 0; i < size; i++)
        x |= (unsigned long long)p[i] << (8 * i);
    if (is_signed && size < 8) {
        unsigned long long signbit = 1ULL << (size * 8 - 1);
        if (x & signbit)
            x = ~x + 1ULL; /* two's-complement negate */
    }
    return (long long)x;
}

/* bu_short/bu_int/bu_longlong big-endian unpack: MSB first, then the
 * xor-signbit trick from bu_* in _struct.c for sign extension. */
long long
struct_unpack_be(const unsigned char *p, Py_ssize_t size, int is_signed)
{
    unsigned long long x = 0;
    Py_ssize_t i = size;
    const unsigned char *bytes = p;
    do {
        x = (x << 8) | *bytes++;
    } while (--i > 0);
    if (is_signed && size < 8) {
        unsigned long long signbit = 1ULL << (size * 8 - 1);
        x = (x ^ signbit) - signbit;
    }
    return (long long)x;
}

/* 's' fill rule: copy min(n, code->size) source bytes; the destination
 * was zero-filled by the caller, so short strings pad right with NUL.
 * Returns the number of bytes copied. */
Py_ssize_t
struct_s_fill(const unsigned char *src, Py_ssize_t n,
              Py_ssize_t codesize, unsigned char *dst)
{
    Py_ssize_t k = n > codesize ? codesize : n;
    Py_ssize_t i;
    for (i = 0; i < k; i++)
        dst[i] = src[i];
    return k;
}

/* 'p' fill rule: count byte + up to codesize-1 data bytes, count capped
 * at 255. Mirrors the p branch of s_pack_internal. */
void
struct_p_fill(const unsigned char *src, Py_ssize_t n,
              Py_ssize_t codesize, unsigned char *dst)
{
    Py_ssize_t i;
    if (codesize == 0) {
        n = 0;
    }
    else if (n > (codesize - 1)) {
        n = codesize - 1;
    }
    for (i = 0; i < n; i++)
        dst[i + 1] = src[i];
    if (n > 255)
        n = 255;
    dst[0] = (unsigned char)n;
}

/* 'p' unpack rule: length = min(first byte, codesize-1); zero codesize
 * yields the empty string. Mirrors s_unpack_internal's p branch. */
Py_ssize_t
struct_p_span(const unsigned char *res, Py_ssize_t codesize)
{
    Py_ssize_t n;
    if (codesize == 0)
        return 0;
    n = res[0];
    if (n >= codesize)
        n = codesize - 1;
    return n;
}
