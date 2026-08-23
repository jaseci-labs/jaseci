# Product-path facade for binascii (wave 16): hexadecimal, RFC 3548/4648
# base64, uuencode, quoted-printable, CRC-CCITT/CRC-32.
#
# Staged ``jac-py/Modules/binasciimodule.{c,jac}`` remain the wave-16 c2jac
# corpus oracle pair (staging=lift); this module carries the runtime truth.
# Semantics mirror CPython 3.14 ``Modules/binascii.c`` on the pinned host,
# verified against the host stdlib ``binascii`` at authoring time.
#
# The hqx family (a2b_hqx/b2a_hqx/rlecode_hqx/rledecode_hqx) was removed
# in Python 3.13 and is intentionally absent from the 3.14 surface.
#
# Error mapping: CPython raises ``binascii.Error`` (a ValueError subclass)
# and ``binascii.Incomplete``; new exception types are unsupported from
# facades, so this module raises plain ``Exception`` with byte-exact
# messages. Builtin TypeError/ValueError keep their builtin types exactly.
#
# Buffer inputs follow the ascii_buffer converter: ``str`` must be pure
# ASCII ("string argument should contain only ASCII characters"), anything
# else needs a buffer protocol ("argument should be bytes, buffer or ASCII
# string, not '<type>'").


def _binascii_error(msg: str) {
    raise Exception(msg);
}


def _type_name(v: any) -> str {
    return type(v).__name__;
}


# ascii_buffer_converter equivalent: normalize to a list of byte ints.
def _ascii_buffer(arg: any) -> list[int] {
    if isinstance(arg, str) {
        s = arg as str;
        out: list[int] = [];
        for ch in s {
            o = ord(ch);
            if o > 127 {
                raise ValueError(
                    "string argument should contain only ASCII characters");
            }
            out.append(o);
        }
        return out;
    }
    # Duck-typed bytes-like: bytes, bytearray, memoryview all expose len()
    # plus integer indexing into 0..255.
    try {
        n = len(arg);
    } except Exception {
        raise TypeError(
            "argument should be bytes, buffer or ASCII string, not '"
            + _type_name(arg) + "'");
    }
    out2: list[int] = [];
    for k in range(n) {
        item = arg[k];
        if item < 0 or item > 255 {
            raise TypeError(
                "argument should be bytes, buffer or ASCII string, not '"
                + _type_name(arg) + "'");
        }
        out2.append(item as int);
    }
    return out2;
}


# ---------------------------------------------------------------------------
# Hexadecimal: hexlify/b2a_hex, unhexlify/a2b_hex
#

def _hex_digits() -> str {
    return "0123456789abcdef";
}

# Digit valuation mirroring _PyLong_DigitValue: 0..15 for hex digits,
# >= 16 otherwise.
def _digit_value(c: int) -> int {
    if c >= 48 and c <= 57 {  # '0'..'9'
        return c - 48;
    }
    if c >= 97 and c <= 102 {  # 'a'..'f'
        return c - 87;
    }
    if c >= 65 and c <= 70 {  # 'A'..'F'
        return c - 55;
    }
    return 16;
}

# Resolve the optional separator byte of _Py_strhex_with_sep; returns -1
# when no separator is requested (bytes can hold any value, so a real
# sentinel is needed).
def _sep_char(sep: any) -> int {
    if sep is None {
        return -1;
    }
    n = len(sep);  # TypeError propagates verbatim for types without len()
    if n != 1 {
        raise ValueError("sep must be length 1.");
    }
    if isinstance(sep, str) {
        o = ord((sep as str)[0]);
        if o > 127 {
            raise ValueError("sep must be ASCII.");
        }
        return o;
    }
    if isinstance(sep, bytes) or isinstance(sep, bytearray) {
        return (sep as any)[0] as int;
    }
    raise TypeError("sep must be str or bytes.");
}

def _append_hex_pair(out: list[int], digits: str, b: int) {
    out.append(ord(digits[b >> 4]));
    out.append(ord(digits[b & 0x0F]));
}

# Shared body of b2a_hex/hexlify (_Py_strhex_bytes_with_sep).
def _strhex_impl(data: any, sep: any, bytes_per_sep: int) -> bytes {
    buf = _ascii_buffer(data);
    arglen = len(buf);
    digits = _hex_digits();
    sc = _sep_char(sep);
    bps = bytes_per_sep;
    if sc < 0 {
        bps = 0;
    }
    abps = bps if bps > 0 else -bps;
    if abps >= arglen {
        # C disables grouping when abs(bytes_per_sep) >= arglen.
        bps = 0;
        abps = 0;
    }
    out: list[int] = [];

    if bps == 0 {
        for i in range(arglen) {
            _append_hex_pair(out, digits, buf[i]);
        }
        return bytes(out);
    }
    chunks = 0 if arglen == 0 else (arglen - 1) // abps;
    if bps < 0 {
        # Separators count from the left.
        i = 0;
        for _ in range(chunks) {
            for _ in range(abps) {
                _append_hex_pair(out, digits, buf[i]);
                i += 1;
            }
            out.append(sc);
        }
        while i < arglen {
            _append_hex_pair(out, digits, buf[i]);
            i += 1;
        }
    } else {
        # Separators count from the right: fill the output backwards.
        total = arglen * 2 + chunks;
        j = total - 1;
        i = arglen - 1;
        while j >= 0 {
            out.append(0);
            j -= 1;
        }
        j = total - 1;
        for _ in range(chunks) {
            for _ in range(abps) {
                b = buf[i];
                out[j] = ord(digits[b & 0x0F]);
                out[j - 1] = ord(digits[b >> 4]);
                j -= 2;
                i -= 1;
            }
            out[j] = sc;
            j -= 1;
        }
        while i >= 0 {
            b = buf[i];
            out[j] = ord(digits[b & 0x0F]);
            out[j - 1] = ord(digits[b >> 4]);
            j -= 2;
            i -= 1;
        }
    }
    return bytes(out);
}


# ---------------------------------------------------------------------------
# base64: a2b_base64/b2a_base64
#
# Decode mirrors the RFC 3548/4648 strict-mode state machine of
# binascii_a2b_base64_impl verbatim; encode mirrors b2a_base64_impl's
# 6-bit drain plus partial-group tail.
#

def _b64_alphabet() -> str {
    return "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
}

# table_a2b_base64 semantics: value 0..63 for alphabet characters, 255
# (unsigned-char wrap of -1) for anything else.
def _b64_value(raw: int) -> int {
    o = raw;
    if o >= 65 and o <= 90 {  # 'A'..'Z' -> 0..25
        return o - 65;
    }
    if o >= 97 and o <= 122 {  # 'a'..'z' -> 26..51
        return o - 71;
    }
    if o >= 48 and o <= 57 {  # '0'..'9' -> 52..61
        return o + 4;
    }
    if o == 43 {  # '+' -> 62
        return 62;
    }
    if o == 47 {  # '/' -> 63
        return 63;
    }
    return 255;
}

# ---------------------------------------------------------------------------
# uuencode: a2b_uu/b2a_uu
#

def _b64_len1_error(nbytes_emitted: int) {
    _binascii_error(
        "Invalid base64-encoded string: number of data characters ("
        + str(nbytes_emitted // 3 * 4 + 1)
        + ") cannot be 1 more than a multiple of 4");
}

def a2b_base64(data: any, strict_mode: bool = False) -> bytes {
    buf = _ascii_buffer(data);
    ascii_len = len(buf);
    out: list[int] = [];
    quad_pos = 0;
    leftchar = 0;
    pads = 0;

    i = 0;
    while i < ascii_len {
        raw = buf[i];
        stop = False;
        if raw == 61 {  # '=' (BASE64_PAD)
            pads += 1;
            if quad_pos >= 2 and quad_pos + pads <= 4 {
                i += 1;
                continue;  # valid trailing pad
            }
            # RFC 4648 section 3.3: excess pad MAY be ignored.
            if not strict_mode {
                i += 1;
                continue;
            }
            if quad_pos == 1 {
                # C breaks here; the final validation reports the error.
                stop = True;
            } else {
                _binascii_error(
                    "Leading padding not allowed" if (quad_pos == 0 and i == 0)
                    else "Excess padding not allowed");
            }
        } else {
            this_ch = _b64_value(raw);
            if this_ch >= 64 {
                if strict_mode {
                    _binascii_error("Only base64 data is allowed");
                }
                i += 1;
                continue;  # ignore non-alphabet byte
            }
            if pads > 0 and strict_mode {
                _binascii_error(
                    "Excess data after padding" if quad_pos + pads == 4
                    else "Discontinuous padding not allowed");
            }
            pads = 0;
            if quad_pos == 0 {
                quad_pos = 1;
                leftchar = this_ch;
            } elif quad_pos == 1 {
                quad_pos = 2;
                out.append(((leftchar << 2) | (this_ch >> 4)) & 0xFF);
                leftchar = this_ch & 0x0F;
            } elif quad_pos == 2 {
                quad_pos = 3;
                out.append(((leftchar << 4) | (this_ch >> 2)) & 0xFF);
                leftchar = this_ch & 0x03;
            } else {
                quad_pos = 0;
                out.append(((leftchar << 6) | this_ch) & 0xFF);
                leftchar = 0;
            }
        }
        if stop {
            break;
        }
        i += 1;
    }

    if quad_pos == 1 {
        _b64_len1_error(len(out));
    }
    if quad_pos != 0 and quad_pos + pads < 4 {
        _binascii_error("Incorrect padding");
    }
    return bytes(out);
}

# BASE64_MAXBIN: ((PY_SSIZE_T_MAX - 3) / 2) on LP64.
glob _BASE64_MAXBIN: int = (9223372036854775807 - 3) // 2;

def b2a_base64(data: any, newline: bool = True) -> bytes {
    buf = _ascii_buffer(data);
    bin_len = len(buf);
    if bin_len > _BASE64_MAXBIN {
        _binascii_error("Too much data for base64 line");
    }
    table = _b64_alphabet();
    out: list[int] = [];
    leftchar = 0;
    leftbits = 0;
    for k in range(bin_len) {
        leftchar = ((leftchar << 8) | buf[k]) & 0xFFFFFFFF;
        leftbits += 8;
        while leftbits >= 6 {
            this_ch = (leftchar >> (leftbits - 6)) & 0x3F;
            leftbits -= 6;
            out.append(ord(table[this_ch]));
        }
    }
    if leftbits == 2 {
        out.append(ord(table[(leftchar & 3) << 4]));
        out.append(61);  # '='
        out.append(61);
    } elif leftbits == 4 {
        out.append(ord(table[(leftchar & 0x0F) << 2]));
        out.append(61);
    }
    if newline {
        out.append(10);  # courtesy newline
    }
    return bytes(out);
}


def hexlify(data: any, sep: any = None, bytes_per_sep: int = 1) -> bytes {
    return _strhex_impl(data, sep, bytes_per_sep);
}

def b2a_hex(data: any, sep: any = None, bytes_per_sep: int = 1) -> bytes {
    return _strhex_impl(data, sep, bytes_per_sep);
}

def a2b_hex(hexstr: any) -> bytes {
    buf = _ascii_buffer(hexstr);
    arglen = len(buf);
    if arglen % 2 {
        _binascii_error("Odd-length string");
    }
    out: list[int] = [];
    i = 0;
    while i < arglen {
        top = _digit_value(buf[i]);
        bot = _digit_value(buf[i + 1]);
        if top >= 16 or bot >= 16 {
            _binascii_error("Non-hexadecimal digit found");
        }
        out.append(((top << 4) + bot) & 0xFF);
        i += 2;
    }
    return bytes(out);
}

def unhexlify(hexstr: any) -> bytes {
    return a2b_hex(hexstr);
}


# ---------------------------------------------------------------------------
# uuencode: a2b_uu/b2a_uu
#

def a2b_uu(data: any) -> bytes {
    buf = _ascii_buffer(data);
    ascii_len = len(buf);
    if ascii_len == 0 {
        _binascii_error("Missing length byte");
    }
    # First byte: binary data length (in bytes). C's unsigned-char
    # arithmetic makes negative differences wrap within & 077.
    bin_len = (buf[0] - 32) % 64;
    if bin_len < 0 {
        bin_len += 64;
    }
    out: list[int] = [];
    leftchar = 0;
    leftbits = 0;
    i = 1;  # ascii_data cursor (after length byte)
    while bin_len > 0 {
        this_ch = buf[i] if i < ascii_len else 0;
        if this_ch == 10 or this_ch == 13 or i >= ascii_len {
            # Whitespace: some spaces got eaten at end-of-line.
            this_ch = 0;
        } elif this_ch < 32 or this_ch > 96 {  # ' ' .. ' '+64
            _binascii_error("Illegal char");
        } else {
            this_ch = (this_ch - 32) % 64;
        }
        leftchar = ((leftchar << 6) | this_ch) & 0xFFFF;
        leftbits += 6;
        if leftbits >= 8 {
            leftbits -= 8;
            out.append((leftchar >> leftbits) & 0xFF);
            leftchar &= (1 << leftbits) - 1;
            bin_len -= 1;
        }
        i += 1;
    }
    # Trailing bytes must be whitespace-only (' ' or '`' padding, CR/LF).
    j = i;
    while j < ascii_len {
        ch = buf[j];
        if ch != 32 and ch != 96 and ch != 10 and ch != 13 {
            _binascii_error("Trailing garbage");
        }
        j += 1;
    }
    return bytes(out);
}

def b2a_uu(data: any, backtick: bool = False) -> bytes {
    buf = _ascii_buffer(data);
    bin_len = len(buf);
    if bin_len > 45 {
        # The 45 is a limit that appears in all uuencodes.
        _binascii_error("At most 45 bytes at once");
    }
    out: list[int] = [];
    # Length byte ('`' encodes empty data in backtick mode).
    if backtick and not bin_len {
        out.append(96);  # '`'
    } else {
        out.append(32 + bin_len);
    }
    leftchar = 0;
    leftbits = 0;
    k = 0;
    while bin_len > 0 or leftbits != 0 {
        if bin_len > 0 {
            leftchar = (leftchar << 8) | buf[k];
        } else {
            leftchar <<= 8;  # padding
        }
        leftbits += 8;
        while leftbits >= 6 {
            this_ch = (leftchar >> (leftbits - 6)) & 0x3F;
            leftbits -= 6;
            if backtick and not this_ch {
                out.append(96);
            } else {
                out.append(this_ch + 32);
            }
        }
        bin_len -= 1;
        k += 1;
    }
    out.append(10);  # courtesy newline
    return bytes(out);
}


# ---------------------------------------------------------------------------
# quoted-printable: a2b_qp/b2a_qp
#

glob _QP_MAXLINESIZE: int = 76;

def _qp_hexdigit(v: int) -> int {
    digits = "0123456789ABCDEF";
    return ord(digits[v]);
}

def a2b_qp(data: any, header: bool = False) -> bytes {
    buf = _ascii_buffer(data);
    datalen = len(buf);
    out: list[int] = [];
    i = 0;
    while i < datalen {
        if buf[i] == 61 {  # '='
            i += 1;
            if i >= datalen {
                break;
            }
            if buf[i] == 10 or buf[i] == 13 {  # soft line break
                if buf[i] != 10 {
                    while i < datalen and buf[i] != 10 {
                        i += 1;
                    }
                }
                if i < datalen {
                    i += 1;
                }
            } elif buf[i] == 61 {  # broken case from broken python qp
                out.append(61);
                i += 1;
            } elif (
                i + 1 < datalen
                and _is_hex_digit(buf[i])
                and _is_hex_digit(buf[i + 1])
            ) {
                out.append(((_hex_val(buf[i]) << 4) + _hex_val(buf[i + 1])) & 0xFF);
                i += 2;
            } else {
                out.append(61);
            }
        } elif header and buf[i] == 95 {  # '_' -> ' '
            out.append(32);
            i += 1;
        } else {
            out.append(buf[i]);
            i += 1;
        }
    }
    return bytes(out);
}

def _is_hex_digit(c: int) -> bool {
    return (c >= 48 and c <= 57) or (c >= 65 and c <= 70) or (c >= 97 and c <= 102);
}

def _hex_val(c: int) -> int {
    if c <= 57 {
        return c - 48;
    }
    if c <= 70 {
        return c - 55;
    }
    return c - 87;
}

def b2a_qp(data: any, quotetabs: bool = False, istext: bool = True,
           header: bool = False) -> bytes {
    buf = _ascii_buffer(data);
    datalen = len(buf);

    # CRLF detection: a '\n' whose predecessor is '\r'.
    crlf = False;
    nl = _memchr(buf, 10);
    if nl > 0 and buf[nl - 1] == 13 {
        crlf = True;
    }

    # Sizing pass (verbatim predicates/order from binascii_b2a_qp_impl).
    odatalen = 0;
    linelen = 0;
    i = 0;
    while i < datalen {
        delta = 0;
        if _qp_needs_encode(buf, datalen, i, linelen, quotetabs, istext, header) {
            if linelen + 3 >= _QP_MAXLINESIZE {
                linelen = 0;
                delta += 3 if crlf else 2;
            }
            linelen += 3;
            delta += 3;
            i += 1;
        } elif istext and (
            buf[i] == 10 or (i + 1 < datalen and buf[i] == 13 and buf[i + 1] == 10)
        ) {
            linelen = 0;
            # Protect against whitespace on end of line.
            if i > 0 and (buf[i - 1] == 32 or buf[i - 1] == 9) {
                delta += 2;
            }
            delta += 2 if crlf else 1;
            if buf[i] == 13 {
                i += 2;
            } else {
                i += 1;
            }
        } else {
            if i + 1 != datalen and buf[i + 1] != 10 and linelen + 1 >= _QP_MAXLINESIZE {
                linelen = 0;
                delta += 3 if crlf else 2;
            }
            linelen += 1;
            delta += 1;
            i += 1;
        }
        odatalen += delta;
    }

    out: list[int] = [0] * odatalen;
    o = 0;
    linelen = 0;
    i = 0;
    while i < datalen {
        ch = buf[i];
        if _qp_needs_encode(buf, datalen, i, linelen, quotetabs, istext, header) {
            if linelen + 3 >= _QP_MAXLINESIZE {
                out[o] = 61;
                o += 1;
                if crlf {
                    out[o] = 13;
                    o += 1;
                }
                out[o] = 10;
                o += 1;
                linelen = 0;
            }
            out[o] = 61;
            out[o + 1] = _qp_hexdigit(ch // 16);
            out[o + 2] = _qp_hexdigit(ch % 16);
            o += 3;
            i += 1;
            linelen += 3;
        } elif istext and (
            ch == 10 or (i + 1 < datalen and ch == 13 and buf[i + 1] == 10)
        ) {
            linelen = 0;
            if o > 0 and (out[o - 1] == 32 or out[o - 1] == 9) {
                prev = out[o - 1];
                out[o - 1] = 61;
                out[o] = _qp_hexdigit(prev // 16);
                out[o + 1] = _qp_hexdigit(prev % 16);
                o += 2;
            }
            if crlf {
                out[o] = 13;
                o += 1;
            }
            out[o] = 10;
            o += 1;
            if ch == 13 {
                i += 2;
            } else {
                i += 1;
            }
        } else {
            if i + 1 != datalen and buf[i + 1] != 10 and linelen + 1 >= _QP_MAXLINESIZE {
                out[o] = 61;
                o += 1;
                if crlf {
                    out[o] = 13;
                    o += 1;
                }
                out[o] = 10;
                o += 1;
                linelen = 0;
            }
            linelen += 1;
            if header and ch == 32 {
                out[o] = 95;  # '_' encodes space in header mode
                o += 1;
            } else {
                out[o] = ch;
                o += 1;
            }
            i += 1;
        }
    }
    return bytes(out[:o]);
}

# First index of byte `v` in buf, or -1. (memchr stand-in)
def _memchr(buf: list[int], v: int) -> int {
    for k in range(len(buf)) {
        if buf[k] == v {
            return k;
        }
    }
    return -1;
}

# Shared need-encode predicate of both b2a_qp passes; order matches the C
# disjunction exactly so boundary behavior stays identical.
def _qp_needs_encode(buf: list[int], datalen: int, i: int, linelen: int,
                     quotetabs: bool, istext: bool, header: bool) -> bool {
    c = buf[i];
    if c > 126 {
        return True;
    }
    if c == 61 {  # '='
        return True;
    }
    if header and c == 95 {  # '_'
        return True;
    }
    if c == 46 and linelen == 0 and (
        i + 1 == datalen or buf[i + 1] == 10 or buf[i + 1] == 13 or buf[i + 1] == 0
    ) {
        return True;
    }
    if not istext and (c == 13 or c == 10) {
        return True;
    }
    if (c == 9 or c == 32) and i + 1 == datalen {
        return True;
    }
    if c < 33 and c != 13 and c != 10 and (quotetabs or (c != 9 and c != 32)) {
        return True;
    }
    return False;
}
