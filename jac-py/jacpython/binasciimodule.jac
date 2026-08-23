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
