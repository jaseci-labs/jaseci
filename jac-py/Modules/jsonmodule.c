/* Header-free extract: _json scanner/encoder kernels.
 *
 * Source: CPython 3.14.6 Modules/_json.c (pinned reference).
 * Slices: whitespace/S_CHAR classification, ascii_escape_unichar escape
 * emission (incl. UTF-16 surrogate pairs), escape size pass,
 * scanstring_unicode string-scan state machine (all escape forms,
 * strict control-character rejection, \uXXXX surrogate-pair joining
 * with backtrack), _match_number_unicode number grammar state machine
 * (leading-zero rule, fraction, optional exponent with backtrack),
 * and the bounds-exact constant matchers from scan_once_unicode.
 *
 * The PyObject glue (scanner/encoder types, memo dicts, parse hooks,
 * PyLong/PyFloat construction, UnicodeWriter) stays in the product
 * facade (jac-py/jacpython/_jsonmodule.jac); these kernels carry the
 * index/control state machines verbatim so they can be differentially
 * lifted and ratcheted by c2jac.
 *
 * Text is modeled as UCS4 code-point arrays (PyUnicode kind-agnostic
 * read); escaped output is a byte (UCS1) buffer, mirroring the C
 * encoder's 1-byte output strings. Error paths return negative status
 * codes plus the exact raise_errmsg position through err_pos so the
 * facade can raise byte-identical JSONDecodeError messages. Bail
 * ladders from the C source are expressed as direct status returns to
 * stay within c2jac's faithful lowering subset (no goto/label sites).
 */

typedef long Py_ssize_t; /* LP64, mirrors jacport.h */
typedef unsigned int Py_UCS4;
typedef unsigned char Py_UCS1;

/* PY_SSIZE_T_MAX on LP64, written as a plain literal. */
#define PY_SSIZE_T_MAX ((Py_ssize_t)9223372036854775807L)

#define JSON_MAX_UNICODE 0x10FFFF

/* scanstring status codes; facade maps each to its exact message. */
#define JSON_SCAN_OK 0
#define JSON_SCAN_ERR_CONTROL (-1)     /* "Invalid control character at" */
#define JSON_SCAN_ERR_UNTERMINATED (-2) /* "Unterminated string starting at" */
#define JSON_SCAN_ERR_ESCAPE (-3)      /* "Invalid \\escape" */
#define JSON_SCAN_ERR_UESCAPE (-4)     /* "Invalid \\uXXXX escape" */
#define JSON_SCAN_ERR_BOUNDS (-5)      /* "end is out of bounds" */
#define JSON_SCAN_ERR_OVERFLOW (-6)    /* output buffer too small */

/* IS_WHITESPACE(c): space, tab, newline, carriage return. */
static int
json_is_whitespace(Py_UCS4 c)
{
    return (c == ' ') || (c == '\t') || (c == '\n') || (c == '\r');
}

/* S_CHAR(c): characters emitted verbatim by the ASCII encoder. */
static int
json_s_char(Py_UCS4 c)
{
    return (c >= ' ' && c <= '~' && c != '\\' && c != '"');
}

static int
json_is_digit(Py_UCS4 c)
{
    return c >= '0' && c <= '9';
}

static int
json_is_hexdigit(Py_UCS4 digit)
{
    if ((digit >= '0' && digit <= '9') || (digit >= 'a' && digit <= 'f') ||
        (digit >= 'A' && digit <= 'F'))
        return 1;
    return 0;
}

static int
json_hex_value(Py_UCS4 digit)
{
    if (digit >= '0' && digit <= '9')
        return (int)(digit - '0');
    if (digit >= 'a' && digit <= 'f')
        return (int)(digit - 'a') + 10;
    if (digit >= 'A' && digit <= 'F')
        return (int)(digit - 'A') + 10;
    return -1;
}

/* Size contributed to the ASCII-escaped form: verbatim, two-byte
 * short escape, \uXXXX, or surrogate pair \uXXXX\uXXXX. */
int
json_escape_char_size(Py_UCS4 c)
{
    if (json_s_char(c))
        return 1;
    switch (c) {
    case '\\': case '"': case '\b': case '\f':
    case '\n': case '\r': case '\t':
        return 2;
    default:
        return c >= 0x10000 ? 12 : 6;
    }
}

static Py_UCS4
json_high_surrogate(Py_UCS4 c)
{
    return 0xD800 + ((c - 0x10000) >> 10);
}

static Py_UCS4
json_low_surrogate(Py_UCS4 c)
{
    return 0xDC00 + ((c - 0x10000) & 0x3FF);
}

static int
json_is_high_surrogate(Py_UCS4 c)
{
    return c >= 0xD800 && c <= 0xDBFF;
}

static int
json_is_low_surrogate(Py_UCS4 c)
{
    return c >= 0xDC00 && c <= 0xDFFF;
}

static Py_UCS4
json_join_surrogates(Py_UCS4 h, Py_UCS4 l)
{
    return 0x10000 + (((h - 0xD800) << 10) | (l - 0xDC00));
}

/* ascii_escape_unichar(): emit one escaped unit into output at chars,
 * which must have room for at least 12 bytes. Returns the new offset.
 * The hex-digit table is inlined as arithmetic, matching Py_hexdigits
 * ordering exactly. */
Py_ssize_t
json_ascii_escape_unichar(Py_UCS4 c, Py_UCS1 *output, Py_ssize_t chars)
{
    output[chars++] = '\\';
    switch (c) {
    case '\\': output[chars++] = '\\'; break;
    case '"': output[chars++] = '"'; break;
    case '\b': output[chars++] = 'b'; break;
    case '\f': output[chars++] = 'f'; break;
    case '\n': output[chars++] = 'n'; break;
    case '\r': output[chars++] = 'r'; break;
    case '\t': output[chars++] = 't'; break;
    default:
        if (c >= 0x10000) {
            /* UTF-16 surrogate pair */
            Py_UCS4 v = json_high_surrogate(c);
            output[chars++] = 'u';
            output[chars++] = (Py_UCS1)((v >> 12) & 0xf);
            output[chars++] = (Py_UCS1)((v >> 8) & 0xf);
            output[chars++] = (Py_UCS1)((v >> 4) & 0xf);
            output[chars++] = (Py_UCS1)(v & 0xf);
            c = json_low_surrogate(c);
            output[chars++] = '\\';
        }
        output[chars++] = 'u';
        output[chars++] = (Py_UCS1)((c >> 12) & 0xf);
        output[chars++] = (Py_UCS1)((c >> 8) & 0xf);
        output[chars++] = (Py_UCS1)((c >> 4) & 0xf);
        output[chars++] = (Py_UCS1)(c & 0xf);
    }
    return chars;
}

/* Size pass of ascii_escape_unicode(): total escaped length including
 * the surrounding quotes, or -1 on overflow. */
Py_ssize_t
json_ascii_escape_size(const Py_UCS4 *buf, Py_ssize_t len)
{
    Py_ssize_t i;
    Py_ssize_t output_size;
    output_size = 2;
    for (i = 0; i < len; i++) {
        Py_ssize_t d = (Py_ssize_t)json_escape_char_size(buf[i]);
        if (output_size > PY_SSIZE_T_MAX - d)
            return -1;
        output_size += d;
    }
    return output_size;
}

/* Fill pass of ascii_escape_unicode(): write quotes + escaped body
 * into output (sized by json_ascii_escape_size). Returns bytes used. */
Py_ssize_t
json_ascii_escape_fill(const Py_UCS4 *buf, Py_ssize_t len, Py_UCS1 *output)
{
    Py_ssize_t i;
    Py_ssize_t chars = 0;
    output[chars++] = '"';
    for (i = 0; i < len; i++) {
        Py_UCS4 c = buf[i];
        if (json_s_char(c))
            output[chars++] = (Py_UCS1)c;
        else
            chars = json_ascii_escape_unichar(c, output, chars);
    }
    output[chars++] = '"';
    return chars;
}

/* scanstring_unicode() kernel. Reads the JSON string starting after
 * the opening quote (end), decoding escapes into out (capacity
 * out_cap). On success returns the decoded length, sets *next_end_ptr
 * to the index after the closing quote. On failure returns a negative
 * JSON_SCAN_* status and sets *err_pos to the exact raise_errmsg
 * position (and *next_end_ptr to -1), mirroring the C bail paths. */
Py_ssize_t
json_scanstring(const Py_UCS4 *buf, Py_ssize_t len, Py_ssize_t end,
                int strict, Py_UCS4 *out, Py_ssize_t out_cap,
                Py_ssize_t *next_end_ptr, Py_ssize_t *err_pos)
{
    Py_ssize_t begin = end - 1;
    Py_ssize_t next;
    Py_ssize_t chars = 0;

    if (end < 0 || len < end) {
        *err_pos = 0;
        *next_end_ptr = -1;
        return JSON_SCAN_ERR_BOUNDS;
    }
    while (1) {
        Py_UCS4 c = 0;
        /* Find the end of the string or the next escape */
        {
            Py_UCS4 d = 0;
            for (next = end; next < len; next++) {
                d = buf[next];
                if (d == '"' || d == '\\')
                    break;
                if (d <= 0x1f && strict) {
                    /* "Invalid control character at" */
                    *err_pos = next;
                    *next_end_ptr = -1;
                    return JSON_SCAN_ERR_CONTROL;
                }
            }
            c = d;
        }

        if (c == '"') {
            /* close quote; flush pending chunk below via copy loop */
        }
        else if (c != '\\') {
            /* "Unterminated string starting at" (position: begin) */
            *err_pos = begin;
            *next_end_ptr = -1;
            return JSON_SCAN_ERR_UNTERMINATED;
        }

        /* Pick up this chunk if it's not zero length */
        if (next != end) {
            Py_ssize_t k;
            if (chars + (next - end) > out_cap) {
                *err_pos = 0;
                *next_end_ptr = -1;
                return JSON_SCAN_ERR_OVERFLOW;
            }
            for (k = end; k < next; k++)
                out[chars++] = buf[k];
        }
        next++;
        if (c == '"') {
            *next_end_ptr = next;
            return chars;
        }
        if (next == len) {
            /* "Unterminated string starting at" (position: begin) */
            *err_pos = begin;
            *next_end_ptr = -1;
            return JSON_SCAN_ERR_UNTERMINATED;
        }
        c = buf[next];
        if (c != 'u') {
            /* Non-unicode backslash escapes */
            end = next + 1;
            switch (c) {
            case '"': break;
            case '\\': break;
            case '/': break;
            case 'b': c = '\b'; break;
            case 'f': c = '\f'; break;
            case 'n': c = '\n'; break;
            case 'r': c = '\r'; break;
            case 't': c = '\t'; break;
            default: c = 0;
            }
            if (c == 0) {
                /* "Invalid \\escape" (position of the backslash) */
                *err_pos = end - 2;
                *next_end_ptr = -1;
                return JSON_SCAN_ERR_ESCAPE;
            }
        }
        else {
            Py_UCS4 c2;
            Py_ssize_t uesc_end;
            c = 0;
            next++;
            uesc_end = next + 4;
            end = uesc_end;
            if (uesc_end >= len) {
                /* "Invalid \\uXXXX escape" (position of the 'u') */
                *err_pos = next - 1;
                *next_end_ptr = -1;
                return JSON_SCAN_ERR_UESCAPE;
            }
            /* Decode 4 hex digits */
            for (; next < uesc_end; next++) {
                int hv = json_hex_value(buf[next]);
                if (hv < 0) {
                    *err_pos = uesc_end - 5;
                    *next_end_ptr = -1;
                    return JSON_SCAN_ERR_UESCAPE;
                }
                c = (c << 4) | (Py_UCS4)hv;
            }
            /* Surrogate pair */
            if (json_is_high_surrogate(c) && uesc_end + 6 < len &&
                buf[next] == '\\' && buf[next + 1] == 'u') {
                next += 2;
                uesc_end += 6;
                end = uesc_end;
                c2 = 0;
                for (; next < uesc_end; next++) {
                    int hv = json_hex_value(buf[next]);
                    if (hv < 0) {
                        *err_pos = uesc_end - 5;
                        *next_end_ptr = -1;
                        return JSON_SCAN_ERR_UESCAPE;
                    }
                    c2 = (c2 << 4) | (Py_UCS4)hv;
                }
                if (json_is_low_surrogate(c2))
                    c = json_join_surrogates(c, c2);
                else {
                    uesc_end -= 6;
                    end = uesc_end;
                }
            }
        }
        if (chars + 1 > out_cap) {
            *err_pos = 0;
            *next_end_ptr = -1;
            return JSON_SCAN_ERR_OVERFLOW;
        }
        out[chars++] = c;
    }

    /* Unreachable: every path returns inside the loop. */
    *err_pos = 0;
    *next_end_ptr = -1;
    return JSON_SCAN_ERR_OVERFLOW;
}

/* _match_number_unicode() grammar kernel. Returns 0 for an integer
 * match, 1 for a float match, or -1 when no number starts at start
 * (the C scanner's raise_stop_iteration(start) path). Sets
 * *next_idx_ptr to the first index after the number. Numeric value
 * conversion (PyLong/PyFloat, parse_int/parse_float hooks) stays in
 * the facade. */
int
json_match_number(const Py_UCS4 *buf, Py_ssize_t len, Py_ssize_t start,
                  Py_ssize_t *next_idx_ptr)
{
    Py_ssize_t end_idx = len - 1;
    Py_ssize_t idx = start;
    int is_float = 0;

    /* read a sign if it's there, make sure it's not the end */
    if (idx <= end_idx && buf[idx] == '-') {
        idx++;
        if (idx > end_idx)
            return -1;
    }

    /* integer digits; a leading 0 stands alone */
    if (idx <= end_idx && buf[idx] >= '1' && buf[idx] <= '9') {
        idx++;
        while (idx <= end_idx && json_is_digit(buf[idx])) idx++;
    }
    else if (idx <= end_idx && buf[idx] == '0') {
        idx++;
    }
    else {
        return -1;
    }

    /* '.' must be followed by a digit */
    if (idx < end_idx && buf[idx] == '.' && json_is_digit(buf[idx + 1])) {
        is_float = 1;
        idx += 2;
        while (idx <= end_idx && json_is_digit(buf[idx])) idx++;
    }

    /* optional exponent; backtrack when it has no digits */
    if (idx < end_idx && (buf[idx] == 'e' || buf[idx] == 'E')) {
        Py_ssize_t e_start = idx;
        idx++;
        if (idx < end_idx && (buf[idx] == '-' || buf[idx] == '+')) idx++;
        while (idx <= end_idx && json_is_digit(buf[idx])) idx++;
        if (json_is_digit(buf[idx - 1]))
            is_float = 1;
        else
            idx = e_start;
    }

    *next_idx_ptr = idx;
    return is_float;
}

/* Bounds-exact constant prefix match used by scan_once_unicode():
 * matches only when every character fits, mirroring the per-constant
 * `idx + K < length` guards. Returns 1 on match, 0 otherwise. */
int
json_match_const(const Py_UCS4 *buf, Py_ssize_t len, Py_ssize_t idx,
                 const char *word, Py_ssize_t wlen)
{
    Py_ssize_t k;
    if (idx + wlen - 1 >= len)
        return 0;
    for (k = 0; k < wlen; k++) {
        if ((Py_UCS4)(unsigned char)word[k] != buf[idx + k])
            return 0;
    }
    return 1;
}
