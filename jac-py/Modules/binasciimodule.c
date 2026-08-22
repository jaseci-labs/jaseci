/* Header-free extract: binascii core conversion kernels.
 *
 * Source: CPython 3.14.6 Modules/binascii.c (pinned reference).
 * Slices: hex digit valuation (_PyLong_DigitValue semantics), b2a_hex
 * separator scheduling, base64 alphabet tables with the RFC 3548/4648
 * strict-mode decode state machine, b2a_base64 partial-group tail,
 * uu length-byte framing, CRC-CCITT and CRC-32 per-byte update steps,
 * quoted-printable hex-digit emission.
 *
 * The PyObject glue (module state, Error/Incomplete exceptions,
 * ascii_buffer conversion, _PyBytesWriter plumbing) stays in the product
 * facade (jac-py/jacpython/binasciimodule.jac); these kernels carry the
 * integer control-state machines verbatim so they can be differentially
 * lifted and ratcheted by c2jac.
 */

typedef long Py_ssize_t; /* LP64, mirrors jacport.h */

/* ---------------------------------------------------------------------------
 * Hex (a2b_hex/unhexlify, b2a_hex/hexlify)
 */

/* Valuation of one hex digit character, mirroring _PyLong_DigitValue
 * (Python/pyport.h): '0'..'9' -> 0..9, 'a'..'f'/'A'..'F' -> 10..15,
 * anything else -> 16 (the C checks `>= 16`). */
int
pylong_digit_value(int c)
{
    if ('0' <= c && c <= '9') {
        return c - '0';
    }
    if ('a' <= c && c <= 'f') {
        return c - 'a' + 10;
    }
    if ('A' <= c && c <= 'F') {
        return c - 'A' + 10;
    }
    return 16;
}

/* Combined a2b_hex digit pair: returns the decoded byte value or
 * -1 when either character is not a hex digit (the facade raises
 * "Non-hexadecimal digit found"). */
int
binascii_hex_pair(int top_char, int bot_char)
{
    int top = pylong_digit_value(top_char);
    int bot = pylong_digit_value(bot_char);
    if (top >= 16 || bot >= 16) {
        return -1;
    }
    return (top << 4) + bot;
}

/* |bytes_per_sep| as unsigned magnitude (mirrors _Py_ABS_CAST). */
Py_ssize_t
abs_bytes_per_sep_kernel(int bytes_per_sep_group)
{
    Py_ssize_t b = bytes_per_sep_group;
    if (b < 0) {
        return -b;
    }
    return b;
}

/* Output length of _Py_strhex_impl: two hex digits per byte plus one
 * separator per complete chunk when grouping is active. */
Py_ssize_t
strhex_result_len(Py_ssize_t arglen, int bytes_per_sep_group)
{
    Py_ssize_t resultlen = 0;
    if (bytes_per_sep_group && arglen > 0) {
        resultlen = (arglen - 1) / abs_bytes_per_sep_kernel(bytes_per_sep_group);
    }
    return resultlen + arglen * 2;
}

/* Number of complete chunk+separator periods (the `chunks` variable in
 * _Py_strhex_impl); zero when grouping is disabled or degenerate. */
Py_ssize_t
strhex_chunk_count(Py_ssize_t arglen, int bytes_per_sep_group)
{
    if (bytes_per_sep_group == 0) {
        return 0;
    }
    if (abs_bytes_per_sep_kernel(bytes_per_sep_group) >= arglen) {
        return 0; /* C disables grouping when abs(bps) >= arglen */
    }
    if (arglen == 0) {
        return 0;
    }
    return (arglen - 1) / abs_bytes_per_sep_kernel(bytes_per_sep_group);
}

/* ---------------------------------------------------------------------------
 * base64 (a2b_base64/b2a_base64)
 */

static const unsigned char table_a2b_base64[256] = {
    255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255,
    255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255,
    255,255,255,255, 255,255,255,255, 255,255,255, 62, 255,255,255, 63,
     52, 53, 54, 55,  56, 57, 58, 59,  60, 61,255,255, 255,  0,255,255,
    255,  0,  1,  2,   3,  4,  5,  6,   7,  8,  9, 10,  11, 12, 13, 14,
     15, 16, 17, 18,  19, 20, 21, 22,  23, 24, 25,255, 255,255,255,255,
    255, 26, 27, 28,  29, 30, 31, 32,  33, 34, 35, 36,  37, 38, 39, 40,
     41, 42, 43, 44,  45, 46, 47, 48,  49, 50, 51,255, 255,255,255,255,
    255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255,
    255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255,
    255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255,
    255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255,
    255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255,
    255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255,
    255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255,
    255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255
};

static const unsigned char table_b2a_base64[64] = {
    'A','B','C','D','E','F','G','H','I','J','K','L','M',
    'N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
    'a','b','c','d','e','f','g','h','i','j','k','l','m',
    'n','o','p','q','r','s','t','u','v','w','x','y','z',
    '0','1','2','3','4','5','6','7','8','9','+','/'
};

/* Actions for one a2b_base64 loop step. The three *_ERROR codes map onto
 * the PyErr_SetString sites of the C loop; the caller supplies the exact
 * message (including the "Leading"/"Excess" pad disambiguation, which the
 * C selects from quad_pos/i before entering the shared error path). */
#define B64_EMIT          0
#define B64_SKIP          1
#define B64_BREAK         2  /* strict mode: '=' at quad_pos 1 breaks the loop */
#define B64_PAD_ERROR     3
#define B64_NONALPHA_ERROR 4
#define B64_EXCESSDATA_ERROR 5
#define B64_DISCPAD_ERROR 6

typedef struct b64_step {
    Py_ssize_t quad_pos;   /* updated quad position within the 4-char group */
    unsigned int leftchar; /* accumulated bits not yet flushed */
    int pads;              /* consecutive '=' seen (reset on data) */
    int action;            /* B64_* code above */
    int out;               /* decoded byte (0..255) when action == B64_EMIT;
                            * carried as int so no char truncation occurs */
} b64_step;

/* One main-loop iteration of binascii_a2b_base64_impl with error raising
 * factored out; state transitions are verbatim. */
b64_step
binascii_a2b_base64_step(Py_ssize_t quad_pos, unsigned int leftchar, int pads,
                         unsigned char raw, int strict_mode)
{
    b64_step r;
    unsigned char this_ch;
    r.quad_pos = quad_pos;
    r.leftchar = leftchar;
    r.pads = pads;
    r.action = B64_SKIP;
    r.out = 0;
    this_ch = raw;

    if (this_ch == '=') {
        r.pads = pads + 1;
        if (quad_pos >= 2 && quad_pos + (r.pads) <= 4) {
            return r; /* skip: valid trailing pad */
        }
        if (!strict_mode) {
            return r; /* RFC 4648 §3.3: excess pad MAY be ignored */
        }
        if (quad_pos == 1) {
            r.action = B64_BREAK; /* C breaks; final validation reports */
            return r;
        }
        r.action = B64_PAD_ERROR;
        return r;
    }

    this_ch = table_a2b_base64[raw];
    if (this_ch >= 64) {
        if (strict_mode) {
            r.action = B64_NONALPHA_ERROR;
            return r;
        }
        return r; /* ignore non-alphabet byte */
    }
    if (r.pads && strict_mode) {
        r.action = (quad_pos + r.pads == 4) ? B64_EXCESSDATA_ERROR
                                            : B64_DISCPAD_ERROR;
        return r;
    }
    r.pads = 0;

    if (quad_pos == 0) {
        r.quad_pos = 1;
        r.leftchar = this_ch;
    }
    else if (quad_pos == 1) {
        r.quad_pos = 2;
        r.out = ((leftchar << 2) | (this_ch >> 4)) & 0xFF;
        r.leftchar = this_ch & 0x0f;
        r.action = B64_EMIT;
    }
    else if (quad_pos == 2) {
        r.quad_pos = 3;
        r.out = ((leftchar << 4) | (this_ch >> 2)) & 0xFF;
        r.leftchar = this_ch & 0x03;
        r.action = B64_EMIT;
    }
    else {
        r.quad_pos = 0;
        r.out = ((leftchar << 6) | this_ch) & 0xFF;
        r.leftchar = 0;
        r.action = B64_EMIT;
    }
    return r;
}

/* Post-loop verdict of binascii_a2b_base64_impl: 0 = accept, 1 = the
 * "cannot be 1 more than a multiple of 4" error, 2 = "Incorrect padding". */
int
binascii_a2b_base64_finish(Py_ssize_t quad_pos, int pads)
{
    if (quad_pos == 1) {
        return 1;
    }
    if (quad_pos != 0 && quad_pos + pads < 4) {
        return 2;
    }
    return 0;
}

/* Data-character count reported by the len-1 error message:
 * `(bin_data - bin_data_start) / 3 * 4 + 1` where the difference is the
 * number of decoded bytes emitted so far. */
Py_ssize_t
binascii_b64_len1_count(Py_ssize_t nbytes_emitted)
{
    return nbytes_emitted / 3 * 4 + 1;
}

/* b2a_base64 partial-group tail: returns the table index for the final
 * significant character, or -1 when the input was a multiple of 3 bytes.
 * Pad-character count follows from the leftover bit count (2 -> "==",
 * 4 -> "="). */
int
binascii_b2a_base64_tail(int leftbits, unsigned int leftchar)
{
    if (leftbits == 2) {
        return (int)(leftchar & 3) << 4;
    }
    if (leftbits == 4) {
        return (int)(leftchar & 0x0f) << 2;
    }
    return -1;
}

/* ---------------------------------------------------------------------------
 * uuencode (a2b_uu/b2a_uu)
 */

/* Length byte emitted by b2a_uu: '`' when encoding empty data with
 * backtick=True, else ' ' + bin_len. */
int
binascii_b2a_uu_lench(int bin_len, int backtick)
{
    if (backtick && !bin_len) {
        return '`';
    }
    return ' ' + bin_len;
}

/* Binary length declared by the first byte of an a2b_uu line. */
int
binascii_a2b_uu_binlen(int lench)
{
    return (lench - ' ') & 077;
}

/* Classification of one character inside an a2b_uu data run:
 * kind 0 = newline/whitespace (contributes a zero sextet), kind 1 =
 * illegal character ("Illegal char"), kind 2 = legal data sextet. */
typedef struct uu_char_class {
    int kind;
    int sixbits;
} uu_char_class;

uu_char_class
binascii_a2b_uu_class(int this_ch)
{
    uu_char_class r;
    r.kind = 2;
    r.sixbits = 0;
    if (this_ch == '\n' || this_ch == '\r') {
        r.kind = 0;
        return r;
    }
    if (this_ch < ' ' || this_ch > (' ' + 64)) {
        r.kind = 1;
        return r;
    }
    r.sixbits = (this_ch - ' ') & 077;
    return r;
}

/* Trailing-garbage check after the data run: legal padding characters
 * are ' ', '`' (space+64) and CR/LF. Returns 1 when garbage is present. */
int
binascii_a2b_uu_trailing_garbage(int this_ch)
{
    if (this_ch != ' ' && this_ch != ' ' + 64 &&
        this_ch != '\n' && this_ch != '\r') {
        return 1;
    }
    return 0;
}

/* ---------------------------------------------------------------------------
 * CRC (crc_hqx/crc32)
 */

static const unsigned short crctab_hqx[256] = {
    0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50a5, 0x60c6, 0x70e7,
    0x8108, 0x9129, 0xa14a, 0xb16b, 0xc18c, 0xd1ad, 0xe1ce, 0xf1ef,
    0x1231, 0x0210, 0x3273, 0x2252, 0x52b5, 0x4294, 0x72f7, 0x62d6,
    0x9339, 0x8318, 0xb37b, 0xa35a, 0xd3bd, 0xc39c, 0xf3ff, 0xe3de,
    0x2462, 0x3443, 0x0420, 0x1401, 0x64e6, 0x74c7, 0x44a4, 0x5485,
    0xa56a, 0xb54b, 0x8528, 0x9509, 0xe5ee, 0xf5cf, 0xc5ac, 0xd58d,
    0x3653, 0x2672, 0x1611, 0x0630, 0x76d7, 0x66f6, 0x5695, 0x46b4,
    0xb75b, 0xa77a, 0x9719, 0x8738, 0xf7df, 0xe7fe, 0xd79d, 0xc7bc,
    0x48c4, 0x58e5, 0x6886, 0x78a7, 0x0840, 0x1861, 0x2802, 0x3823,
    0xc9cc, 0xd9ed, 0xe98e, 0xf9af, 0x8948, 0x9969, 0xa90a, 0xb92b,
    0x5af5, 0x4ad4, 0x7ab7, 0x6a96, 0x1a71, 0x0a50, 0x3a33, 0x2a12,
    0xdbfd, 0xcbdc, 0xfbbf, 0xeb9e, 0x9b79, 0x8b58, 0xbb3b, 0xab1a,
    0x6ca6, 0x7c87, 0x4ce4, 0x5cc5, 0x2c22, 0x3c03, 0x0c60, 0x1c41,
    0xedae, 0xfd8f, 0xcdec, 0xddcd, 0xad2a, 0xbd0b, 0x8d68, 0x9d49,
    0x7e97, 0x6eb6, 0x5ed5, 0x4ef4, 0x3e13, 0x2e32, 0x1e51, 0x0e70,
    0xff9f, 0xefbe, 0xdfdd, 0xcffc, 0xbf1b, 0xaf3a, 0x9f59, 0x8f78,
    0x9188, 0x81a9, 0xb1ca, 0xa1eb, 0xd10c, 0xc12d, 0xf14e, 0xe16f,
    0x1080, 0x00a1, 0x30c2, 0x20e3, 0x5004, 0x4025, 0x7046, 0x6067,
    0x83b9, 0x9398, 0xa3fb, 0xb3da, 0xc33d, 0xd31c, 0xe37f, 0xf35e,
    0x02b1, 0x1290, 0x22f3, 0x32d2, 0x4235, 0x5214, 0x6277, 0x7256,
    0xb5ea, 0xa5cb, 0x95a8, 0x8589, 0xf56e, 0xe54f, 0xd52c, 0xc50d,
    0x34e2, 0x24c3, 0x14a0, 0x0481, 0x7466, 0x6447, 0x5424, 0x4405,
    0xa7db, 0xb7fa, 0x8799, 0x97b8, 0xe75f, 0xf77e, 0xc71d, 0xd73c,
    0x26d3, 0x36f2, 0x0691, 0x16b0, 0x6657, 0x7676, 0x4615, 0x5634,
    0xd94c, 0xc96d, 0xf90e, 0xe92f, 0x99c8, 0x89e9, 0xb98a, 0xa9ab,
    0x5844, 0x4865, 0x7806, 0x6827, 0x18c0, 0x08e1, 0x3882, 0x28a3,
    0xcb7d, 0xdb5c, 0xeb3f, 0xfb1e, 0x8bf9, 0x9bd8, 0xabbb, 0xbb9a,
    0x4a75, 0x5a54, 0x6a37, 0x7a16, 0x0af1, 0x1ad0, 0x2ab3, 0x3a92,
    0xfd2e, 0xed0f, 0xdd6c, 0xcd4d, 0xbdaa, 0xad8b, 0x9de8, 0x8dc9,
    0x7c26, 0x6c07, 0x5c64, 0x4c45, 0x3ca2, 0x2c83, 0x1ce0, 0x0cc1,
    0xef1f, 0xff3e, 0xcf5d, 0xdf7c, 0xaf9b, 0xbfba, 0x8fd9, 0x9ff8,
    0x6e17, 0x7e36, 0x4e55, 0x5e74, 0x2e93, 0x3eb2, 0x0ed1, 0x1ef0
};

/* One CRC-CCITT byte step (crc_hqx inner statement); the incoming crc is
 * masked to 16 bits exactly like the `crc &= 0xffff` preamble. */
unsigned int
binascii_crc_hqx_byte(unsigned int crc, unsigned char byte)
{
    crc &= 0xffff;
    return ((crc << 8) & 0xff00) ^ crctab_hqx[(crc >> 8) ^ byte];
}

static const unsigned int crc_32_tab[256] = {
0x00000000U, 0x77073096U, 0xee0e612cU, 0x990951baU, 0x076dc419U,
0x706af48fU, 0xe963a535U, 0x9e6495a3U, 0x0edb8832U, 0x79dcb8a4U,
0xe0d5e91eU, 0x97d2d988U, 0x09b64c2bU, 0x7eb17cbdU, 0xe7b82d07U,
0x90bf1d91U, 0x1db71064U, 0x6ab020f2U, 0xf3b97148U, 0x84be41deU,
0x1adad47dU, 0x6ddde4ebU, 0xf4d4b551U, 0x83d385c7U, 0x136c9856U,
0x646ba8c0U, 0xfd62f97aU, 0x8a65c9ecU, 0x14015c4fU, 0x63066cd9U,
0xfa0f3d63U, 0x8d080df5U, 0x3b6e20c8U, 0x4c69105eU, 0xd56041e4U,
0xa2677172U, 0x3c03e4d1U, 0x4b04d447U, 0xd20d85fdU, 0xa50ab56bU,
0x35b5a8faU, 0x42b2986cU, 0xdbbbc9d6U, 0xacbcf940U, 0x32d86ce3U,
0x45df5c75U, 0xdcd60dcfU, 0xabd13d59U, 0x26d930acU, 0x51de003aU,
0xc8d75180U, 0xbfd06116U, 0x21b4f4b5U, 0x56b3c423U, 0xcfba9599U,
0xb8bda50fU, 0x2802b89eU, 0x5f058808U, 0xc60cd9b2U, 0xb10be924U,
0x2f6f7c87U, 0x58684c11U, 0xc1611dabU, 0xb6662d3dU, 0x76dc4190U,
0x01db7106U, 0x98d220bcU, 0xefd5102aU, 0x71b18589U, 0x06b6b51fU,
0x9fbfe4a5U, 0xe8b8d433U, 0x7807c9a2U, 0x0f00f934U, 0x9609a88eU,
0xe10e9818U, 0x7f6a0dbbU, 0x086d3d2dU, 0x91646c97U, 0xe6635c01U,
0x6b6b51f4U, 0x1c6c6162U, 0x856530d8U, 0xf262004eU, 0x6c0695edU,
0x1b01a57bU, 0x8208f4c1U, 0xf50fc457U, 0x65b0d9c6U, 0x12b7e950U,
0x8bbeb8eaU, 0xfcb9887cU, 0x62dd1ddfU, 0x15da2d49U, 0x8cd37cf3U,
0xfbd44c65U, 0x4db26158U, 0x3ab551ceU, 0xa3bc0074U, 0xd4bb30e2U,
0x4adfa541U, 0x3dd895d7U, 0xa4d1c46dU, 0xd3d6f4fbU, 0x4369e96aU,
0x346ed9fcU, 0xad678846U, 0xda60b8d0U, 0x44042d73U, 0x33031de5U,
0xaa0a4c5fU, 0xdd0d7cc9U, 0x5005713cU, 0x270241aaU, 0xbe0b1010U,
0xc90c2086U, 0x5768b525U, 0x206f85b3U, 0xb966d409U, 0xce61e49fU,
0x5edef90eU, 0x29d9c998U, 0xb0d09822U, 0xc7d7a8b4U, 0x59b33d17U,
0x2eb40d81U, 0xb7bd5c3bU, 0xc0ba6cadU, 0xedb88320U, 0x9abfb3b6U,
0x03b6e20cU, 0x74b1d29aU, 0xead54739U, 0x9dd277afU, 0x04db2615U,
0x73dc1683U, 0xe3630b12U, 0x94643b84U, 0x0d6d6a3eU, 0x7a6a5aa8U,
0xe40ecf0bU, 0x9309ff9dU, 0x0a00ae27U, 0x7d079eb1U, 0xf00f9344U,
0x8708a3d2U, 0x1e01f268U, 0x6906c2feU, 0xf762575dU, 0x806567cbU,
0x196c3671U, 0x6e6b06e7U, 0xfed41b76U, 0x89d32be0U, 0x10da7a5aU,
0x67dd4accU, 0xf9b9df6fU, 0x8ebeeff9U, 0x17b7be43U, 0x60b08ed5U,
0xd6d6a3e8U, 0xa1d1937eU, 0x38d8c2c4U, 0x4fdff252U, 0xd1bb67f1U,
0xa6bc5767U, 0x3fb506ddU, 0x48b2364bU, 0xd80d2bdaU, 0xaf0a1b4cU,
0x36034af6U, 0x41047a60U, 0xdf60efc3U, 0xa867df55U, 0x316e8eefU,
0x4669be79U, 0xcb61b38cU, 0xbc66831aU, 0x256fd2a0U, 0x5268e236U,
0xcc0c7795U, 0xbb0b4703U, 0x220216b9U, 0x5505262fU, 0xc5ba3bbeU,
0xb2bd0b28U, 0x2bb45a92U, 0x5cb36a04U, 0xc2d7ffa7U, 0xb5d0cf31U,
0x2cd99e8bU, 0x5bdeae1dU, 0x9b64c2b0U, 0xec63f226U, 0x756aa39cU,
0x026d930aU, 0x9c0906a9U, 0xeb0e363fU, 0x72076785U, 0x05005713U,
0x95bf4a82U, 0xe2b87a14U, 0x7bb12baeU, 0x0cb61b38U, 0x92d28e9bU,
0xe5d5be0dU, 0x7cdcefb7U, 0x0bdbdf21U, 0x86d3d2d4U, 0xf1d4e242U,
0x68ddb3f8U, 0x1fda836eU, 0x81be16cdU, 0xf6b9265bU, 0x6fb077e1U,
0x18b74777U, 0x88085ae6U, 0xff0f6a70U, 0x66063bcaU, 0x11010b5cU,
0x8f659effU, 0xf862ae69U, 0x616bffd3U, 0x166ccf45U, 0xa00ae278U,
0xd70dd2eeU, 0x4e048354U, 0x3903b3c2U, 0xa7672661U, 0xd06016f7U,
0x4969474dU, 0x3e6e77dbU, 0xaed16a4aU, 0xd9d65adcU, 0x40df0b66U,
0x37d83bf0U, 0xa9bcae53U, 0xdebb9ec5U, 0x47b2cf7fU, 0x30b5ffe9U,
0xbdbdf21cU, 0xcabac28aU, 0x53b39330U, 0x24b4a3a6U, 0xbad03605U,
0xcdd70693U, 0x54de5729U, 0x23d967bfU, 0xb3667a2eU, 0xc4614ab8U,
0x5d681b02U, 0x2a6f2b94U, 0xb40bbe37U, 0xc30c8ea1U, 0x5a05df1bU,
0x2d02ef8dU
};

/* One internal_crc32 byte step (Jim Ahlstrom table walk). The right
 * shift MUST zero-fill, which unsigned arithmetic guarantees here. */
unsigned int
binascii_crc32_byte(unsigned int crc, unsigned char byte)
{
    return crc_32_tab[(crc ^ byte) & 0xff] ^ (crc >> 8);
}

/* internal_crc32 preamble/postamble pair: `crc = ~crc` before the loop
 * and `(crc ^ 0xFFFFFFFF) & 0xffffffff` after. */
unsigned int
binascii_crc32_premask(unsigned int crc)
{
    return ~crc;
}

unsigned int
binascii_crc32_final(unsigned int crc)
{
    return (crc ^ 0xFFFFFFFFU) & 0xffffffffU;
}

/* ---------------------------------------------------------------------------
 * quoted-printable (b2a_qp)
 */

/* Uppercase hex-digit pair for one byte, mirroring the to_hex helper
 * ("0123456789ABCDEF"[v % 16] twice over v/16). Digits are carried as
 * ints so no representation-changing char truncation occurs on lift. */
typedef struct qp_hex_pair {
    int hi;
    int lo;
} qp_hex_pair;

qp_hex_pair
binascii_qp_to_hex(unsigned char ch)
{
    qp_hex_pair r;
    unsigned int uvalue = ch;
    r.lo = "0123456789ABCDEF"[uvalue % 16];
    uvalue = uvalue / 16;
    r.hi = "0123456789ABCDEF"[uvalue % 16];
    return r;
}
