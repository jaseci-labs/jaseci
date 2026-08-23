# Product-path facade for _struct (wave 13): pack/unpack/calcsize over
# struct format strings.
# Staged ``jac-py/Modules/structmodule.{c,jac}`` remain the wave-13 c2jac
# corpus oracle pair (staging=lift); this module carries the runtime truth.
# Semantics mirror CPython 3.14 ``Modules/_struct.c`` on an LP64
# little-endian host, verified against the pinned host stdlib.
#
# Byte-order prefixes: '@' native order/size/alignment (default), '=' host
# order with standard sizes, '<' little-endian, '>' / '!' big-endian.
#
# Error mapping: CPython raises ``struct.error`` (an Exception subclass) for
# pack/unpack semantic failures; this facade declares ``struct.error`` in the
# bridge-table module-exception registry (exceptions_core.jac) at import, so
# boundary matching/minting sees the real hierarchy. TypeError/OverflowError
# keep their builtin types exactly.

# ---------------------------------------------------------------------------
# Exact power-of-two float scaling (every step multiplies/divides by a
# power of two, so it is lossless; used by the IEEE-754 bit converters).
def _scale_pow2(v: float, k: int) -> float {
    while k >= 62 {
        v = v * 4611686018427387904.0;
        k = k - 62;
    }
    while k <= -62 {
        v = v / 4611686018427387904.0;
        k = k + 62;
    }
    while k >= 1 {
        v = v * 2.0;
        k = k - 1;
    }
    while k <= -1 {
        v = v / 2.0;
        k = k + 1;
    }
    return v;
}

# Decompose |x| (finite, nonzero) into M * 2^E with M the exact 53-bit
# significand in [2^52, 2^53). Halving/doubling only touches exponents,
# like _PyHASH _frexp; m * 2^53 is then integral by construction.
def _decompose(x: float) -> tuple[int, int] {
    e = 0;
    m: float = x;
    while m >= 1.0 {
        m = m * 0.5;
        e = e + 1;
    }
    while m < 0.5 {
        m = m * 2.0;
        e = e - 1;
    }
    return (int(m * 9007199254740992.0), e - 53);
}

def _is_neg_float(x: float) -> bool {
    if x < 0.0 {
        return True;
    }
    if x == 0.0 {
        return str(x)[0] == "-";
    }
    return False;
}

# ------------------------- IEEE-754 double <-> bits ------------------------
def _f64_bits(x: float) -> int {
    neg = _is_neg_float(x);
    if x != x {
        if neg {
            return 0xFFF8000000000000;
        }
        return 0x7FF8000000000000;
    }
    sign = 0x8000000000000000 if neg else 0;
    if x == 0.0 {
        return sign;
    }
    ax: float = x;
    if neg {
        ax = -ax;
    }
    if ax == float("inf") {
        return sign | 0x7FF0000000000000;
    }
    (m, e) = _decompose(ax);
    be = e + 1075;
    if be >= 2047 {
        return sign | 0x7FF0000000000000;
    }
    if be < 1 {
        # Subnormal: value is exactly representable, low bits are zero.
        return sign | (m >> (1 - be));
    }
    return sign | (be << 52) | (m - 4503599627370496);
}

def _bits_f64(bits: int) -> float {
    be = (bits >> 52) & 0x7FF;
    mant = bits & 0xFFFFFFFFFFFFF;
    if be == 2047 {
        if mant == 0 {
            return float("-inf") if (bits >> 63) & 1 else float("inf");
        }
        return float("nan");
    }
    v: float;
    if be == 0 {
        v = _scale_pow2(float(mant), -1074);
    } else {
        v = _scale_pow2(float(mant + 4503599627370496), be - 1075);
    }
    if (bits >> 63) & 1 {
        return -v;
    }
    return v;
}

# -------------------------- IEEE-754 single <-> bits -----------------------
# Round-to-nearest-even right shift of an exact integer significand.
def _round_shift(m: int, shift: int) -> int {
    if shift <= 0 {
        return m << (-shift);
    }
    q = m >> shift;
    r = m & ((1 << shift) - 1);
    half = 1 << (shift - 1);
    if r > half or (r == half and (q & 1)) {
        q = q + 1;
    }
    return q;
}

def _f32_bits(x: float) -> int {
    neg = _is_neg_float(x);
    if x != x {
        if neg {
            return 0xFFC00000;
        }
        return 0x7FC00000;
    }
    sign = 0x80000000 if neg else 0;
    if x == 0.0 {
        return sign;
    }
    ax: float = x;
    if neg {
        ax = -ax;
    }
    if ax == float("inf") {
        return sign | 0x7F800000;
    }
    (m, e) = _decompose(ax);
    be = e + 179;  # f32: F24 = round(M / 2^29), value = F24 * 2^(be-150)
    if be >= 255 {
        raise OverflowError("float too large to pack with f format");
    }
    q = _round_shift(m, 29);
    if q == 16777216 {
        q = 8388608;
        be = be + 1;
        if be >= 255 {
            raise OverflowError("float too large to pack with f format");
        }
    }
    if be < 1 {
        # Subnormal: Fs = round(M * 2^(E+149)); shift = -(E+149) = 30-be.
        q = _round_shift(m, 30 - be);
        if q == 16777216 {
            # Rounding carried into the smallest normal.
            be = 1;
            return sign | (be << 23) | (q - 8388608);
        }
        return sign | q;
    }
    return sign | (be << 23) | (q - 8388608);
}

def _bits_f32(bits: int) -> float {
    be = (bits >> 23) & 0xFF;
    mant = bits & 0x7FFFFF;
    if be == 255 {
        if mant == 0 {
            return float("-inf") if (bits >> 31) & 1 else float("inf");
        }
        return float("nan");
    }
    v: float;
    if be == 0 {
        v = _scale_pow2(float(mant), -149);
    } else {
        v = _scale_pow2(float(mant + 8388608), be - 150);
    }
    if (bits >> 31) & 1 {
        return -v;
    }
    return v;
}

# --------------------------- IEEE-754 half <-> bits ------------------------
def _f16_bits(x: float) -> int {
    neg = _is_neg_float(x);
    if x != x {
        if neg {
            return 0xFE00;
        }
        return 0x7E00;
    }
    sign = 0x8000 if neg else 0;
    if x == 0.0 {
        return sign;
    }
    ax: float = x;
    if neg {
        ax = -ax;
    }
    if ax == float("inf") {
        return sign | 0x7C00;
    }
    (m, e) = _decompose(ax);
    be = e + 67;  # f16: F11 = round(M / 2^42), value = F11 * 2^(be-25)
    if be >= 31 {
        raise OverflowError("float too large to pack with e format");
    }
    q = _round_shift(m, 42);
    if q == 2048 {
        q = 1024;
        be = be + 1;
        if be >= 31 {
            raise OverflowError("float too large to pack with e format");
        }
    }
    if be < 1 {
        # Subnormal: Fs = round(M * 2^(E+24)); shift = -(E+24) = 43-be.
        q = _round_shift(m, 43 - be);
        if q == 2048 {
            be = 1;
            return sign | (be << 10) | (q - 1024);
        }
        return sign | q;
    }
    return sign | (be << 10) | (q - 1024);
}

def _bits_f16(bits: int) -> float {
    be = (bits >> 10) & 0x1F;
    mant = bits & 0x3FF;
    if be == 31 {
        if mant == 0 {
            return float("-inf") if (bits >> 15) & 1 else float("inf");
        }
        return float("nan");
    }
    v: float;
    if be == 0 {
        v = _scale_pow2(float(mant), -24);
    } else {
        v = _scale_pow2(float(mant + 1024), be - 25);
    }
    if (bits >> 15) & 1 {
        return -v;
    }
    return v;
}

# ---------------------------------------------------------------------------
# Format tables. Native sizes/alignments are the LP64 little-endian host's
# (sizeof(long)=8 etc.), mirroring native_table[] in Modules/_struct.c.

obj _FmtDef {
    has ch: str = "",
        size: int = 0,
        align: int = 0;
}

def _table_for(endian: str) -> list[_FmtDef] {
    if endian != "@" {
        # Standard sizes, no alignment ('<', '>', '=', '!').
        t: list[_FmtDef] = [];
        std_rows: list[tuple] = [
            ("x", 1), ("b", 1), ("B", 1), ("c", 1), ("s", 1), ("p", 1),
            ("h", 2), ("H", 2), ("i", 4), ("I", 4), ("l", 4), ("L", 4),
            ("q", 8), ("Q", 8), ("?", 1), ("e", 2), ("f", 4), ("d", 8),
            ("F", 8), ("D", 16),
        ];
        for row in std_rows {
            t.append(_FmtDef(ch=row[0], size=row[1], align=0));
        }
        return t;
    }
    nt: list[_FmtDef] = [];
    native_rows: list[tuple] = [
        ("x", 1, 0), ("b", 1, 0), ("B", 1, 0), ("c", 1, 0), ("s", 1, 0),
        ("p", 1, 0), ("h", 2, 2), ("H", 2, 2), ("i", 4, 4), ("I", 4, 4),
        ("l", 8, 8), ("L", 8, 8), ("n", 8, 8), ("N", 8, 8), ("q", 8, 8),
        ("Q", 8, 8), ("?", 1, 1), ("e", 2, 2), ("f", 4, 4), ("d", 8, 8),
        ("F", 8, 4), ("D", 16, 8), ("P", 8, 8),
    ];
    for row in native_rows {
        nt.append(_FmtDef(ch=row[0], size=row[1], align=row[2]));
    }
    return nt;
}

def _find_entry(table: list[_FmtDef], c: str) -> _FmtDef | None {
    for e in table {
        if e.ch == c {
            return e;
        }
    }
    return None;
}

# ---------------------------------------------------------------------------
# Compiled format.

obj _Code {
    has ch: str = "",
        offset: int = 0,
        size: int = 0,
        repeat: int = 1;
}

glob _WHITESPACE: list = [" ", "\t", "\n", "\r", "\v", "\f"];

def _range_bounds(size: int, unsigned: bool) -> tuple[int, int] {
    if unsigned {
        if size >= 8 {
            return (0, 18446744073709551615);
        }
        return (0, (1 << (size * 8)) - 1);
    }
    if size >= 8 {
        return (-9223372036854775808, 9223372036854775807);
    }
    lim = 1 << (size * 8 - 1);
    return (-lim, lim - 1);
}

def _struct_error(msg: str) {
    raise Exception(msg);
}

def _align_size(size: int, c: str, e: _FmtDef) -> int {
    if e.ch == c and e.align > 0 and size > 0 {
        extra = (e.align - 1) - (size - 1) % e.align;
        size = size + extra;
    }
    return size;
}

def _type_name(v: any) -> str {
    try {
        return type(v).__name__;
    } except Exception {
        return type(v).__name__;
    }
}

obj _StructObj {
    # fmt is the normalized format string as given (byte-order prefix kept,
    # interior whitespace preserved); endian carries the selected prefix.
    has fmt: str = "",
        endian: str = "@",
        codes: list = [],
        size: int = 0,
        count: int = 0;

    def __repr__ -> str {
        return "Struct(" + repr(self.fmt) + ")";
    }

    def __iter__ -> any {
        # Struct instances are not iterable in CPython either.
        raise TypeError("iter() returned non-iterator of type '_StructObj'");
    }

    def _entry_size(c: str) -> int {
        ent = _find_entry(_table_for(self.endian), c);
        if ent is None {
            _struct_error("bad char in struct format");
        }
        return (ent as _FmtDef).size;
    }

    # ---- packing guts -------------------------------------------------
    def _pack_into_list(args: list, buf: list, base: int) {
        i = 0;
        little = self.endian != ">" and self.endian != "!";
        for code in self.codes {
            cd = code as _Code;
            off = base + cd.offset;
            reps = cd.repeat;
            for _j in range(reps) {
                if i >= len(args) {
                    _struct_error(
                        "pack expected " + str(self.count)
                        + " items for packing (got " + str(len(args)) + ")");
                }
                v: any = args[i];
                i = i + 1;
                self._pack_value(cd, v, buf, off, little);
                off = off + cd.size;
            }
        }
        if len(args) != self.count {
            _struct_error(
                "pack expected " + str(self.count)
                + " items for packing (got " + str(len(args)) + ")");
        }
    }

    def _pack_value(cd: _Code, v: any, buf: list, off: int, little: bool) {
        c = cd.ch;
        if c == "s" or c == "p" or c == "c" {
            src_ok = isinstance(v, bytes) or isinstance(v, bytearray);
            if not src_ok {
                if c == "c" {
                    _struct_error(
                        "char format requires a bytes object of length 1");
                }
                _struct_error(
                    "argument for '" + c + "' must be a bytes object");
            }
            data = _buffer_bytes(v);
            if c == "c" {
                if len(data) != 1 {
                    _struct_error(
                        "char format requires a bytes object of length 1");
                }
                buf[off] = data[0];
            } elif c == "s" {
                n = len(data);
                if n > cd.size {
                    n = cd.size;
                }
                for k in range(n) {
                    buf[off + k] = data[k];
                }
            } else {
                # 'p': count byte + up to size-1 data bytes, count <= 255.
                n = len(data);
                if cd.size == 0 {
                    n = 0;
                } elif n > cd.size - 1 {
                    n = cd.size - 1;
                }
                for k in range(n) {
                    buf[off + 1 + k] = data[k];
                }
                if n > 255 {
                    n = 255;
                }
                buf[off] = n;
            }
            return;
        }
        if c == "?" {
            buf[off] = 1 if v else 0;
            return;
        }
        if c == "f" or c == "d" or c == "e" {
            if not (isinstance(v, float) or isinstance(v, int)) {
                _struct_error("required argument is not a float");
            }
            fv = float(v);
            fv = float(v);
            bits = _f64_bits(fv) if c == "d" else (
                _f32_bits(fv) if c == "f" else _f16_bits(fv));
            nbytes = 8 if c == "d" else (4 if c == "f" else 2);
            _write_int_bits(buf, off, nbytes, bits, little);
            return;
        }
        if c == "F" or c == "D" {
            # Complex codes: two floats/doubles, real first. Accept any
            # object exposing real/imag (complex at minimum).
            if isinstance(v, complex) {
                re_v = (v as complex).real;
                im_v = (v as complex).imag;
            } else {
                try {
                    re_v = v.real;
                    im_v = v.imag;
                } except Exception {
                    _struct_error("required argument is not a complex");
                }
            }
            half = cd.size // 2;
            bits_re = _f64_bits(float(re_v)) if c == "D" else _f32_bits(
                float(re_v));
            bits_im = _f64_bits(float(im_v)) if c == "D" else _f32_bits(
                float(im_v));
            _write_int_bits(buf, off, half, bits_re, little);
            _write_int_bits(buf, off + half, half, bits_im, little);
            return;
        }
        # Integer codes: b B h H i I l L n N q Q P
        iv = _to_int(v);
        unsigned = c in ("B", "H", "I", "L", "N", "Q", "P");
        (lo, hi) = _range_bounds(cd.size, unsigned);
        if iv < lo or iv > hi {
            _struct_error(
                "'" + c + "' format requires " + str(lo)
                + " <= number <= " + str(hi));
        }
        _write_int_bits(buf, off, cd.size, iv, little);
    }

    # ---- unpacking guts -----------------------------------------------
    def _unpack_from_list(data: list[int], base: int) -> tuple {
        out: list = [];
        little = self.endian != ">" and self.endian != "!";
        for code in self.codes {
            cd = code as _Code;
            off = base + cd.offset;
            reps = cd.repeat;
            for _j in range(reps) {
                c = cd.ch;
                if c == "s" {
                    out.append(bytes(data[off:off + cd.size]));
                } elif c == "p" {
                    n = 0 if cd.size == 0 else data[off];
                    if n >= cd.size {
                        n = cd.size - 1;
                    }
                    if n < 0 {
                        n = 0;
                    }
                    out.append(bytes(data[off + 1:off + 1 + n]));
                } elif c == "c" {
                    out.append(bytes([data[off]]));
                } elif c == "?" {
                    out.append(data[off] != 0);
                } elif c == "f" or c == "d" or c == "e" {
                    bits = _read_int_bits(data, off, cd.size, little);
                    if c == "d" {
                        out.append(_bits_f64(bits));
                    } elif c == "f" {
                        out.append(_bits_f32(bits));
                    } else {
                        out.append(_bits_f16(bits));
                    }
                } elif c == "F" or c == "D" {
                    half = cd.size // 2;
                    bits_re = _read_int_bits(data, off, half, little);
                    bits_im = _read_int_bits(data, off + half, half, little);
                    if c == "D" {
                        out.append(complex(_bits_f64(bits_re),
                                           _bits_f64(bits_im)));
                    } else {
                        out.append(complex(_bits_f32(bits_re),
                                           _bits_f32(bits_im)));
                    }
                } else {
                    unsigned = c in ("B", "H", "I", "L", "N", "Q", "P");
                    val = _read_int_bits(data, off, cd.size, little);
                    if not unsigned {
                        nbits = cd.size * 8;
                        signbit = 1 << (nbits - 1);
                        if val & signbit {
                            val = val - (1 << nbits);
                        }
                    }
                    out.append(val);
                }
                off = off + cd.size;
            }
        }
        return tuple(out);
    }

    # ---- public API ----------------------------------------------------
    def pack(*args: list) -> bytes {
        buf: list[int] = [0] * self.size;
        self._pack_into_list(args, buf, 0);
        return bytes(buf);
    }

    def unpack(buffer: any) -> tuple {
        data = _buffer_bytes(buffer);
        if len(data) != self.size {
            _struct_error(
                "unpack requires a buffer of " + str(self.size) + " bytes");
        }
        return self._unpack_from_list(data, 0);
    }

    def unpack_from(buffer: any, offset: int = 0) -> tuple {
        data = _buffer_bytes(buffer);
        blen = len(data);
        if offset < 0 {
            if offset + self.size > 0 {
                _struct_error(
                    "not enough data to unpack " + str(self.size)
                    + " bytes at offset " + str(offset));
            }
            if offset + blen < 0 {
                _struct_error(
                    "offset " + str(offset) + " out of range for "
                    + str(blen) + "-byte buffer");
            }
            offset = offset + blen;
        }
        if blen - offset < self.size {
            _struct_error(
                "unpack_from requires a buffer of at least "
                + str(self.size + offset) + " bytes for unpacking "
                + str(self.size) + " bytes at offset " + str(offset)
                + " (actual buffer size is " + str(blen) + ")");
        }
        return self._unpack_from_list(data, offset);
    }

    def iter_unpack(buffer: any) -> any {
        data = _buffer_bytes(buffer);
        if self.size == 0 {
            _struct_error(
                "cannot iteratively unpack with a struct of length 0");
        }
        if len(data) % self.size != 0 {
            _struct_error(
                "iterative unpacking requires a buffer of a multiple of "
                + str(self.size) + " bytes");
        }
        return _UnpackIter(so=self, data=data, index=0);
    }

    def pack_into(buffer: any, offset: int, *args: list) {
        if not isinstance(buffer, bytearray) {
            raise TypeError(
                "pack_into() requires a writable bytes-like object, not "
                + _type_name(buffer));
        }
        blen = len(buffer);
        if offset < 0 {
            if offset + self.size > 0 {
                _struct_error(
                    "no space to pack " + str(self.size)
                    + " bytes at offset " + str(offset));
            }
            if offset + blen < 0 {
                _struct_error(
                    "offset " + str(offset) + " out of range for "
                    + str(blen) + "-byte buffer");
            }
            offset = offset + blen;
        }
        if blen - offset < self.size {
            _struct_error(
                "pack_into requires a buffer of at least "
                + str(self.size + offset) + " bytes for packing "
                + str(self.size) + " bytes at offset " + str(offset)
                + " (actual buffer size is " + str(blen) + ")");
        }
        staging: list[int] = [0] * self.size;
        self._pack_into_list(args, staging, 0);
        for k in range(self.size) {
            buffer[offset + k] = staging[k];
        }
    }
}

obj _UnpackIter {
    # Yields one tuple per struct-sized record, then StopIteration; mirrors
    # unpackiter_iternext (T7 na-clean forbids yield).
    has so: any = None,
        data: list[int] = [],
        index: int = 0;

    def __iter__ -> any {
        return self;
    }

    def __next__ -> tuple {
        if self.so is None or self.index >= len(self.data) {
            self.so = None;
            raise StopIteration();
        }
        res = (self.so as _StructObj)._unpack_from_list(self.data, self.index);
        self.index = self.index + (self.so as _StructObj).size;
        return res;
    }

    def __length_hint__ -> int {
        if self.so is None {
            return 0;
        }
        return (len(self.data) - self.index) // (self.so as _StructObj).size;
    }
}

# ---------------------------------------------------------------------------
# Value coercion helpers.

def _to_int(v: any) -> int {
    if isinstance(v, int) {
        return v as int;
    }
    try {
        return v.__index__() as int;
    } except Exception {
        _struct_error("required argument is not an integer");
    }
    return 0;
}

def _write_int_bits(buf: list, off: int, nbytes: int, val: int, little: bool) {
    if val < 0 {
        val = val + (1 << (nbytes * 8));
    }
    for k in range(nbytes) {
        b = val & 0xFF;
        if little {
            buf[off + k] = b;
        } else {
            buf[off + nbytes - 1 - k] = b;
        }
        val = val >> 8;
    }
}

def _read_int_bits(data: list[int], off: int, nbytes: int, little: bool) -> int {
    val = 0;
    for k in range(nbytes) {
        if little {
            val = val | (data[off + k] << (8 * k));
        } else {
            val = (val << 8) | data[off + k];
        }
    }
    return val;
}

def _buffer_bytes(buffer: any) -> list[int] {
    # Duck-typed bytes-like: bytes, bytearray, memoryview all expose len()
    # plus integer indexing into 0..255.
    if not (isinstance(buffer, bytes) or isinstance(buffer, bytearray)) {
        try {
            probe = len(buffer);
        } except Exception {
            raise TypeError(
                "a bytes-like object is required, not '" + _type_name(buffer)
                + "'");
        }
        if probe < 0 {
            raise TypeError("a bytes-like object is required");
        }
    }
    out: list[int] = [];
    for k in range(len(buffer)) {
        item = buffer[k];
        if item < 0 or item > 255 {
            raise TypeError("a bytes-like object is required");
        }
        out.append(item as int);
    }
    return out;
}

# ---------------------------------------------------------------------------
# Format-string compilation (prepare_s). Raises the same messages as
# CPython for malformed formats.

def compile(fmt_arg: any) -> _StructObj {
    fmt: str;
    if isinstance(fmt_arg, str) {
        fmt = fmt_arg as str;
        if "\x00" in fmt {
            _struct_error("embedded null character");
        }
    } elif isinstance(fmt_arg, bytes) or isinstance(fmt_arg, bytearray) {
        raw = _buffer_bytes(fmt_arg);
        for byte in raw {
            if byte == 0 {
                _struct_error("embedded null character");
            }
        }
        chars: list = [];
        for byte in raw {
            chars.append(chr(byte));
        }
        fmt = "".join(chars);
    } else {
        raise TypeError(
            "Struct() argument 1 must be a str or bytes object, not "
            + _type_name(fmt_arg));
    }

    endian = "@";
    body = fmt;
    if len(fmt) > 0 and ("<>!=@" .find(fmt[0]) >= 0) {
        endian = fmt[0];
        body = fmt[1:];
    }

    table = _table_for(endian);
    codes: list[_Code] = [];
    size = 0;
    count = 0;
    i = 0;
    blen = len(body);
    while i < blen {
        c = body[i];
        i = i + 1;
        found_ws = False;
        for ws in _WHITESPACE {
            if c == ws {
                found_ws = True;
                break;
            }
        }
        if found_ws {
            continue;
        }
        if "0" <= c and c <= "9" {
            num = ord(c) - 48;
            while i < blen and "0" <= body[i] and body[i] <= "9" {
                num = num * 10 + (ord(body[i]) - 48);
                i = i + 1;
            }
            if i >= blen {
                _struct_error("repeat count given without format specifier");
            }
            c = body[i];
            i = i + 1;
        } else {
            num = 1;
        }
        e = _find_entry(table, c);
        if e is None {
            _struct_error("bad char in struct format");
        }
        ent = e as _FmtDef;
        itemsize = ent.size;
        if endian == "@" {
            size = _align_size(size, c, ent);
        }
        if c == "s" or c == "p" {
            count = count + 1;
            codes.append(_Code(ch=c, offset=size, size=num, repeat=1));
            size = size + num;
        } elif c == "x" {
            size = size + num;
        } else {
            if num > 0 {
                count = count + num;
                codes.append(
                    _Code(ch=c, offset=size, size=itemsize, repeat=num));
            }
            size = size + num * itemsize;
        }
    }
    return _StructObj(
        fmt=fmt, endian=endian, codes=codes, size=size, count=count);
}

# ---------------------------------------------------------------------------
# Module-level API with the compiled-format cache (MAXCACHE semantics:
# clear the whole cache when it reaches MAXCACHE entries).

glob _CACHE_MAX: int = 100;

glob _cache: dict = {};

def _cached(fmt: any) -> _StructObj {
    key: str;
    if isinstance(fmt, str) {
        key = fmt as str;
    } elif isinstance(fmt, bytes) or isinstance(fmt, bytearray) {
        chars: list = [];
        for byte in _buffer_bytes(fmt) {
            chars.append(chr(byte));
        }
        key = "".join(chars);
    } else {
        # Let compile() produce the canonical TypeError.
        return compile(fmt);
    }
    hit = _cache.get(key);
    if hit is not None {
        return hit as _StructObj;
    }
    s = compile(fmt);
    if len(_cache) >= _CACHE_MAX {
        _cache.clear();
    }
    _cache[key] = s;
    return s;
}

def calcsize(fmt: any) -> int {
    return (_cached(fmt) as _StructObj).size;
}

def pack(fmt: any, *vals: list) -> bytes {
    return (_cached(fmt) as _StructObj).pack(*vals);
}

def pack_into(fmt: any, buffer: any, offset: int, *vals: list) {
    (_cached(fmt) as _StructObj).pack_into(buffer, offset, *vals);
}

def unpack(fmt: any, buffer: any) -> tuple {
    return (_cached(fmt) as _StructObj).unpack(buffer);
}

def unpack_from(fmt: any, buffer: any, offset: int = 0) -> tuple {
    return (_cached(fmt) as _StructObj).unpack_from(buffer, offset);
}

def iter_unpack(fmt: any, buffer: any) -> any {
    return (_cached(fmt) as _StructObj).iter_unpack(buffer);
}

def _clearcache() {
    _cache.clear();
}

import from exceptions_core { register_module_exception }

with entry {
    # Module-exception declaration (bridge-table registry, exceptions_core):
    # declared AT IMPORT so boundary matching/minting knows this exception's
    # hierarchy without bare getattr(builtins, ...) lookups.
    register_module_exception("struct.error", "Exception");
}
