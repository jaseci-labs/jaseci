# Product-path facade for array (wave 14): typecodes, construction, access,
# mutation, byte/file bridges, iterators.
#
# Staged ``jac-py/Modules/arraymodule.{c,jac}`` remain the wave-14 c2jac
# corpus oracle pair (staging=lift); this module carries the runtime truth.
# Semantics mirror CPython 3.14 ``Modules/arraymodule.c`` with the LP64
# descriptor table ('l'/'L' are 8 bytes, 'u' is wchar_t == 4).
#
# Storage model: one bytearray of native (little-endian) two's-complement /
# IEEE-754 bytes, exactly mirroring ob_item. Every read/write goes through
# per-typecode pack/unpack so frombytes/tobytes/buffer_info stay byte-faithful.
#
# Error messages are pinned against the host oracle (CPython 3.14 array):
# OverflowError texts differ per typecode and are reproduced verbatim.


# ---------------------------------------------------------------------------
# Descriptor table (mirrors struct arraydescr descriptors[] on LP64)
# ---------------------------------------------------------------------------

def _tc_table() -> str {
    return "bBuwhHiIlLqQfd";
}

def _tc_index(tc: str) -> int {
    table = _tc_table();
    i: int = 0;
    while i < len(table) {
        if table[i] == tc {
            return i;
        }
        i += 1;
    }
    return -1;
}

def _tc_itemsize(idx: int) -> int {
    # b B u w h H i I l L q Q f d
    sizes: list[int] = [1, 1, 4, 4, 2, 2, 4, 4, 8, 8, 8, 8, 4, 8];
    return sizes[idx];
}

# Signed integral typecodes: 'b','h','i','l','q'. Everything else stores
# unsigned ints ('B','H','I','L','Q'), UCS4 chars ('u','w') or floats ('f','d').
def _tc_is_signed_int(tc: str) -> bool {
    return tc == "b" or tc == "h" or tc == "i" or tc == "l" or tc == "q";
}

def _tc_is_unsigned_int(tc: str) -> bool {
    return tc == "B" or tc == "H" or tc == "I" or tc == "L" or tc == "Q";
}

def _tc_is_int(tc: str) -> bool {
    return _tc_is_signed_int(tc) or _tc_is_unsigned_int(tc);
}

def _tc_is_char(tc: str) -> bool {
    return tc == "u" or tc == "w";
}

def _tc_is_float(tc: str) -> bool {
    return tc == "f" or tc == "d";
}


# ---------------------------------------------------------------------------
# IEEE-754 bit conversion (needed for byte-faithful 'f'/'d' storage).
# Double path parses float.hex() (exact, handles denormals/inf/nan);
# float32 path rounds the double bit pattern to nearest-even.
# ---------------------------------------------------------------------------

def _f64_bits(x: float) -> int {
    s = x.hex();
    neg: bool = s.startswith("-");
    body = s;
    if neg {
        body = s[1:len(s)];
    }
    if body == "nan" {
        return 0x7ff8000000000000;
    }
    if body == "inf" {
        return 0x7ff0000000000000 | (_sign_shift64(neg));
    }
    # Normal/denormal form: [-]0x<hex>.<hex>p<dec-exp>
    parts = body.split("p");
    mant_part = parts[0];
    exp_part = int(parts[1]);
    digits = mant_part[2:len(mant_part)];
    halves = digits.split(".");
    int_d = halves[0];
    frac_d = halves[1];
    m_str = int_d + frac_d;
    mant = int(m_str, 16);
    k: int = len(frac_d);
    e: int = exp_part - 4 * k;
    if mant == 0 {
        return _sign_shift64(neg);
    }
    if int_d == "0" {
        # Denormal double: value = mant * 2^e with e >= -1074 and
        # mant * 2^(e + 1074) an exact integer (the encoded fraction).
        return (mant << (e + 1074)) | _sign_shift64(neg);
    }
    # Normalize mant into [2^52, 2^53) keeping value = mant * 2^e.
    while mant < 4503599627370496 {
        mant = mant * 2;
        e -= 1;
    }
    while mant >= 9007199254740992 {
        mant = mant >> 1;
        e += 1;
    }
    # Normalized value = 1.f * 2^(e + 52): the hidden bit sits at bit 52.
    frac = mant - 4503599627370496;
    return (((e + 1075) << 52) | frac) | _sign_shift64(neg);
}

def _sign_shift64(neg: bool) -> int {
    # Sign bit as an unsigned 64-bit pattern component.
    if neg {
        return 9223372036854775808;
    }
    return 0;
}

def _bits_f64(bits: int) -> float {
    expf = (bits >> 52) & 0x7ff;
    frac = bits & 4503599627370495;
    neg = (bits >> 63) == 1;
    if expf == 2047 {
        if frac == 0 {
            v = float("inf");
        } else {
            v = float.fromhex("nan");
        }
    } elif expf == 0 {
        v = frac * 2 ** -1074;
    } else {
        v = (frac + 4503599627370496) * 2 ** (expf - 1075);
    }
    if neg {
        return -v;
    }
    return v;
}

# Round-to-nearest-even right shift of a non-negative int.
def _rshift_round_even(m: int, shift: int) -> int {
    if shift <= 0 {
        return m << (-shift);
    }
    q = m >> shift;
    r = m - (q << shift);
    half = 1 << (shift - 1);
    if r > half or (r == half and (q % 2) == 1) {
        q += 1;
    }
    return q;
}

def _f32_bits(x: float) -> int {
    if x != x {
        return 0x7fc00000;
    }
    b64 = _f64_bits(x);
    neg = b64 < 0;
    ub = b64;
    if neg {
        ub = -b64;
    }
    expf = (ub >> 52) & 0x7ff;
    frac64 = ub & 4503599627370495;
    if expf == 2047 {
        if frac64 == 0 {
            return 0x7f800000 | ((ub >> 63) << 31);
        }
        return 0x7fc00000;
    }
    if expf == 0 {
        mant = frac64;
        e = -1074;
    } else {
        mant = frac64 + 4503599627370496;
        e = expf - 1075;
    }
    if mant == 0 {
        return (ub >> 63) << 31;
    }
    # Here value = mant * 2^e with mant in [2^52, 2^53), so the unbiased
    # binary exponent is E = e + 52 and float32 normals need E >= -126.
    if e >= -178 {
        # Normal float32: round mantissa to 24 significant bits.
        n = _rshift_round_even(mant, 29);
        if n >= 16777216 {
            n = n >> 1;
            e += 1;
        }
        if e + 179 >= 255 {
            return 0x7f800000 | ((ub >> 63) << 31);
        }
        return (((e + 179) << 23) | (n - 8388608)) | ((ub >> 63) << 31);
    }
    # Subnormal float32 (or underflow to zero): grid step 2^-149,
    # n2 = mant * 2^(e + 149).
    n2 = _rshift_round_even(mant, -e - 149);
    if n2 >= 16777216 {
        # Rounded up into the smallest normal.
        return (1 << 23) | ((ub >> 63) << 31);
    }
    return (n2 << 0) | ((ub >> 63) << 31);
}

def _bits_f32(bits: int) -> float {
    expf = (bits >> 23) & 0xff;
    frac = bits & 8388607;
    neg = (bits >> 31) == 1;
    ub = bits;
    if expf == 255 {
        if frac == 0 {
            v = float("inf");
        } else {
            v = float.fromhex("nan");
        }
    } elif expf == 0 {
        v = frac * 2 ** -149;
    } else {
        v = (frac + 8388608) * 2 ** (expf - 150);
    }
    if neg {
        return -v;
    }
    return v;
}


# ---------------------------------------------------------------------------
# Item pack/unpack (little-endian native order, mirrors memcpy of C types)
# ---------------------------------------------------------------------------

def _pack_int(v: int, itemsize: int, signed: bool) -> bytes {
    return v.to_bytes(itemsize, "little", signed=signed);
}

def _unpack_int(chunk: bytearray, signed: bool) -> int {
    return int.from_bytes(chunk, "little", signed=signed);
}

def _pack_char(s: str) -> bytes {
    return ord(s).to_bytes(4, "little", signed=True);
}

def _unpack_char(chunk: bytearray) -> str {
    cp = int.from_bytes(chunk, "little", signed=False);
    return chr(cp);
}

def _pack_float(v: float, tc: str) -> bytes {
    bits: int;
    if tc == "d" {
        bits = _f64_bits(v);
    } else {
        bits = _f32_bits(v);
    }
    size: int = 8;
    if tc == "f" {
        size = 4;
    }
    # Bit patterns are unsigned 32/64-bit values; pack unsigned LE.
    return bits.to_bytes(size, "little", signed=False);
}

def _unpack_float(chunk: bytearray, tc: str) -> float {
    bits = int.from_bytes(chunk, "little", signed=False);
    if tc == "d" {
        return _bits_f64(bits);
    }
    return _bits_f32(bits);
}


# ---------------------------------------------------------------------------
# Item validation (host-oracle error strings)
# ---------------------------------------------------------------------------

def _type_name(v: any) -> str {
    if isinstance(v, bool) {
        return "bool";
    }
    if isinstance(v, int) {
        return "int";
    }
    if isinstance(v, float) {
        return "float";
    }
    if isinstance(v, str) {
        return "str";
    }
    if isinstance(v, list) {
        return "list";
    }
    if isinstance(v, bytes) {
        return "bytes";
    }
    if v is None {
        return "NoneType";
    }
    return "object";
}

def _require_int(v: any) -> int {
    if isinstance(v, float) {
        raise TypeError("'float' object cannot be interpreted as an integer");
    }
    if not isinstance(v, int) {
        raise TypeError("'" + _type_name(v) + "' object cannot be interpreted as an integer");
    }
    return v;
}

def _overflow(tc: str, v: int) {
    # Per-typecode OverflowError texts, pinned to CPython 3.14.
    if tc == "b" {
        if v < -128 {
            raise OverflowError("signed char is less than minimum");
        }
        raise OverflowError("signed char is greater than maximum");
    }
    if tc == "B" {
        if v < 0 {
            raise OverflowError("unsigned byte integer is less than minimum");
        }
        raise OverflowError("unsigned byte integer is greater than maximum");
    }
    if tc == "h" {
        if v < -32768 {
            raise OverflowError("signed short integer is less than minimum");
        }
        raise OverflowError("signed short integer is greater than maximum");
    }
    if tc == "H" {
        if v < 0 {
            raise OverflowError("unsigned short is less than minimum");
        }
        raise OverflowError("unsigned short is greater than maximum");
    }
    if tc == "i" {
        if v < -2147483648 {
            raise OverflowError("signed integer is less than minimum");
        }
        raise OverflowError("signed integer is greater than maximum");
    }
    if tc == "I" {
        if v < 0 {
            raise OverflowError("can't convert negative value to unsigned int");
        }
        raise OverflowError("unsigned int is greater than maximum");
    }
    if tc == "l" {
        raise OverflowError("Python int too large to convert to C long");
    }
    if tc == "L" {
        if v < 0 {
            raise OverflowError("can't convert negative value to unsigned int");
        }
        raise OverflowError("Python int too large to convert to C unsigned long");
    }
    raise OverflowError("int too big to convert");
}

def _checked_int_item(tc: str, v: any) -> int {
    iv = _require_int(v);
    if tc == "b" {
        if iv < -128 or iv > 127 {
            _overflow(tc, iv);
        }
    } elif tc == "B" {
        if iv < 0 or iv > 255 {
            _overflow(tc, iv);
        }
    } elif tc == "h" {
        if iv < -32768 or iv > 32767 {
            _overflow(tc, iv);
        }
    } elif tc == "H" {
        if iv < 0 or iv > 65535 {
            _overflow(tc, iv);
        }
    } elif tc == "i" {
        if iv < -2147483648 or iv > 2147483647 {
            _overflow(tc, iv);
        }
    } elif tc == "I" {
        if iv < 0 or iv > 4294967295 {
            _overflow(tc, iv);
        }
    } elif tc == "l" {
        if iv < -9223372036854775808 or iv > 9223372036854775807 {
            _overflow(tc, iv);
        }
    } elif tc == "L" {
        if iv < 0 or iv > 18446744073709551615 {
            _overflow(tc, iv);
        }
    } elif tc == "q" {
        if iv < -9223372036854775808 or iv > 9223372036854775807 {
            _overflow(tc, iv);
        }
    } else {
        # 'Q'
        if iv < 0 or iv > 18446744073709551615 {
            _overflow(tc, iv);
        }
    }
    return iv;
}

def _require_real(v: any) -> float {
    if isinstance(v, int) {
        return float(v);
    }
    if not isinstance(v, float) {
        raise TypeError("must be real number, not " + _type_name(v));
    }
    return v;
}

def _checked_float_item(tc: str, v: any) -> float {
    return _require_real(v);
}

def _checked_char_item(v: any) -> str {
    if not isinstance(v, str) {
        raise TypeError("array item must be a unicode character, not " + _type_name(v));
    }
    if len(v) != 1 {
        raise TypeError("array item must be a unicode character, not a string of length " + str(len(v)));
    }
    return v;
}


# ---------------------------------------------------------------------------
# Array archetype
# ---------------------------------------------------------------------------

obj Array {
    has typecode: str = "b",
        itemsize: int = 1,
        data: bytearray = bytearray();


    def _n_items -> int {
        return len(self.data) // self.itemsize;
    }

    def _chunk(i: int) -> bytearray {
        base = i * self.itemsize;
        return self.data[base:base + self.itemsize];
    }

    def _unpack_at(i: int) -> any {
        chunk = self._chunk(i);
        tc = self.typecode;
        if _tc_is_int(tc) {
            return _unpack_int(chunk, _tc_is_signed_int(tc));
        }
        if _tc_is_char(tc) {
            return _unpack_char(chunk);
        }
        return _unpack_float(chunk, tc);
    }

    def _append_value(v: any) {
        self.data += self._pack_item(v);
    }

    def __iter__ -> ArrayIter {
        it = ArrayIter();
        it.arr = self;
        it.idx = 0;
        return it;
    }

    def __len__ -> int {
        return self._n_items();
    }

    def __getitem__(item: any) -> any {
        if isinstance(item, int) {
            i = item;
            if i < 0 {
                i += self._n_items();
            }
            if i < 0 or i >= self._n_items() {
                raise IndexError("array index out of range");
            }
            return self._unpack_at(i);
        }
        if isinstance(item, slice) {
            start: int;
            stop: int;
            step: int;
            bounds = item.indices(self._n_items());
            start = bounds[0];
            stop = bounds[1];
            step = bounds[2];
            out = _p2_array(self.typecode);
            if step > 0 {
                i = start;
                while i < stop {
                    out._append_value(self._unpack_at(i));
                    i += step;
                }
            } else {
                i = start;
                while i > stop {
                    out._append_value(self._unpack_at(i));
                    i += step;
                }
            }
            return out;
        }
        raise TypeError("array indices must be integers or slices, not " + _type_name(item));
    }

    def __setitem__(item: any, v: any) {
        if isinstance(item, slice) {
            self._ass_slice(item, v);
            return;
        }
        iv = _require_int(item);
        i = iv;
        if i < 0 {
            i += self._n_items();
        }
        if i < 0 or i >= self._n_items() {
            raise IndexError("array assignment index out of range");
        }
        packed = self._pack_item(v);
        base = i * self.itemsize;
        self.data[base:base + self.itemsize] = packed;
    }

    def _ass_slice(item: slice, v: any) {
        if not isinstance(v, Array) {
            raise TypeError('can only assign array (not "' + _type_name(v) + '") to array slice');
        }
        src: Array = v;
        if src.typecode != self.typecode {
            # CPython requires matching typecodes for slice assignment.
            raise TypeError("bad argument type for built-in operation");
        }
        n = self._n_items();
        bounds = item.indices(n);
        start: int = bounds[0];
        stop: int = bounds[1];
        step: int = bounds[2];
        if step == 1 {
            head = self.data[0:start * self.itemsize];
            tail = self.data[stop * self.itemsize:len(self.data)];
            self.data = bytearray(head) + bytearray(src.data) + bytearray(tail);
            return;
        }
        # Extended-slice assignment requires matching lengths (like CPython).
        dst_count: int = 0;
        if step > 0 {
            j = start;
            while j < stop {
                dst_count += 1;
                j += step;
            }
        } else {
            j = start;
            while j > stop {
                dst_count += 1;
                j += step;
            }
        }
        if dst_count != len(src) {
            raise ValueError("attempt to assign array of size " + str(len(src)) + " to extended slice of size " + str(dst_count));
        }
        si: int = 0;
        j = start;
        while (step > 0 and j < stop) or (step < 0 and j > stop) {
            packed_src: Array = src;
            packed_val = packed_src._chunk(si);
            base = j * self.itemsize;
            self.data[base:base + self.itemsize] = packed_val;
            si += 1;
            j += step;
        }
    }

    def __delitem__(item: any) {
        if isinstance(item, slice) {
            bounds = item.indices(self._n_items());
            start: int = bounds[0];
            stop: int = bounds[1];
            step: int = bounds[2];
            if step == 1 {
                head = self.data[0:start * self.itemsize];
                tail = self.data[stop * self.itemsize:len(self.data)];
                self.data = bytearray(head) + bytearray(tail);
                return;
            }
            # Collect indices to delete, then rebuild without them.
            doomed: list[int] = [];
            j = start;
            while (step > 0 and j < stop) or (step < 0 and j > stop) {
                doomed.append(j);
                j += step;
            }
            keep: bytearray = bytearray();
            k: int = 0;
            n = self._n_items();
            dead: int = 0;
            while k < n {
                if dead < len(doomed) and doomed[dead] == k {
                    dead += 1;
                } else {
                    keep += self._chunk(k);
                }
                k += 1;
            }
            self.data = keep;
            return;
        }
        i = _require_int(item);
        if i < 0 {
            i += self._n_items();
        }
        if i < 0 or i >= self._n_items() {
            raise IndexError("array index out of range");
        }
        base = i * self.itemsize;
        head = self.data[0:base];
        tail = self.data[base + self.itemsize:len(self.data)];
        self.data = bytearray(head) + bytearray(tail);
    }

    def append(v: any) {
        self._append_value(v);
    }

    def insert(i: any, v: any) {
        n = self._n_items();
        idx = _require_int(i);
        if idx < 0 {
            idx += n;
        }
        if idx < 0 {
            idx = 0;
        }
        if idx > n {
            idx = n;
        }
        packed = self._pack_item(v);
        base = idx * self.itemsize;
        self.data[base:base] = packed;
    }

    def pop(i: any = None) -> any {
        n = self._n_items();
        if n == 0 {
            raise IndexError("pop from empty array");
        }
        idx: int;
        if i is None {
            idx = n - 1;
        } else {
            idx = _require_int(i);
            if idx < 0 {
                idx += n;
            }
            if idx < 0 or idx >= n {
                raise IndexError("pop index out of range");
            }
        }
        item = self._unpack_at(idx);
        self.__delitem__(idx);
        return item;
    }

    def remove(v: any) {
        i: int = 0;
        n = self._n_items();
        while i < n {
            if _items_equal(self._unpack_at(i), v) {
                self.__delitem__(i);
                return;
            }
            i += 1;
        }
        raise ValueError("array.remove(x): x not in array");
    }

    def index(v: any, start: any = None, stop: any = None) -> int {
        n = self._n_items();
        lo: int = 0;
        hi: int = n;
        if start is not None {
            lo = _require_int(start);
            if lo < 0 {
                lo += n;
                if lo < 0 {
                    lo = 0;
                }
            }
        }
        if stop is not None {
            hi = _require_int(stop);
            if hi < 0 {
                hi += n;
                if hi < 0 {
                    hi = 0;
                }
            }
        }
        i: int = lo;
        while i < hi and i < n {
            if _items_equal(self._unpack_at(i), v) {
                return i;
            }
            i += 1;
        }
        raise ValueError("array.index(x): x not in array");
    }

    def count(v: any) -> int {
        total: int = 0;
        i: int = 0;
        n = self._n_items();
        while i < n {
            if _items_equal(self._unpack_at(i), v) {
                total += 1;
            }
            i += 1;
        }
        return total;
    }

    def reverse() {
        n = self._n_items();
        lo: int = 0;
        hi: int = n - 1;
        while lo < hi {
            tmp = bytearray(self._chunk(lo));
            base_lo = lo * self.itemsize;
            base_hi = hi * self.itemsize;
            self.data[base_lo:base_lo + self.itemsize] = self._chunk(hi);
            self.data[base_hi:base_hi + self.itemsize] = tmp;
            lo += 1;
            hi -= 1;
        }
    }

    def clear() {
        self.data = bytearray();
    }

    def extend(other: any) {
        if isinstance(other, Array) {
            oa: Array = other;
            if oa.typecode != self.typecode {
                raise TypeError("can only extend with array of same kind");
            }
            # Copy first: extending from self must see a stable source
            # (mirrors CPython's memcpy-overlap-safe extend).
            self.data += bytearray(oa.data);
            return;
        }
        # Materialize so extend(self) / mutating iterables stay safe.
        items = list(other);
        for v in items {
            self._append_value(v);
        }
    }

    def __add__(other: any) -> any {
        if not isinstance(other, Array) {
            raise TypeError('can only append array (not "' + _type_name(other) + '") to array');
        }
        oa: Array = other;
        if oa.typecode != self.typecode {
            raise TypeError("bad argument type for built-in operation");
        }
        out = _p2_array(self.typecode, self);
        out.data += oa.data;
        return out;
    }

    def __iadd__(other: any) -> any {
        if not isinstance(other, Array) {
            raise TypeError('can only extend array with array (not "' + _type_name(other) + '")');
        }
        oa: Array = other;
        if oa.typecode != self.typecode {
            raise TypeError("can only extend with array of same kind");
        }
        self.data += oa.data;
        return self;
    }

    def __mul__(n: any) -> any {
        cnt = _require_int(n);
        out = _p2_array(self.typecode);
        k: int = 0;
        while k < cnt {
            out.data += self.data;
            k += 1;
        }
        return out;
    }

    def __rmul__(n: any) -> any {
        return self.__mul__(n);
    }

    def _pack_item(v: any) -> bytes {
        tc = self.typecode;
        if _tc_is_int(tc) {
            return _pack_int(_checked_int_item(tc, v), self.itemsize, _tc_is_signed_int(tc));
        }
        if _tc_is_char(tc) {
            return _pack_char(_checked_char_item(v));
        }
        return _pack_float(_checked_float_item(tc, v), tc);
    }

    def __repr__ -> str {
        prefix = "array('" + self.typecode + "'";
        if self._n_items() == 0 {
            return prefix + ")";
        }
        if _tc_is_char(self.typecode) {
            # Char arrays repr as one quoted string: array('u', 'ab').
            text = "";
            i: int = 0;
            while i < self._n_items() {
                text += self._unpack_at(i);
                i += 1;
            }
            return prefix + ", '" + text + "')";
        }
        parts: list[str] = [];
        i = 0;
        while i < self._n_items() {
            parts.append(_format_item(self._unpack_at(i), self.typecode));
            i += 1;
        }
        return prefix + ", [" + ", ".join(parts) + "])";
    }

    def __eq__(other: any) -> any {
        if not isinstance(other, Array) {
            return False;
        }
        oa: Array = other;
        if len(oa) != len(self) {
            return False;
        }
        i: int = 0;
        while i < len(self) {
            if not _items_equal(self._unpack_at(i), oa._unpack_at(i)) {
                return False;
            }
            i += 1;
        }
        return True;
    }

    def __lt__(other: any) -> any {
        return self._rich_order(other, "<");
    }

    def __le__(other: any) -> any {
        return self._rich_order(other, "<=");
    }

    def __gt__(other: any) -> any {
        return self._rich_order(other, ">");
    }

    def __ge__(other: any) -> any {
        return self._rich_order(other, ">=");
    }

    def _rich_order(other: any, op: str) -> any {
        if not isinstance(other, Array) {
            raise TypeError("'<' not supported between instances of 'array.array' and '" + _type_name(other) + "'");
        }
        oa: Array = other;
        i: int = 0;
        while i < len(self) and i < len(oa) {
            a = self._unpack_at(i);
            b = oa._unpack_at(i);
            if not _items_equal(a, b) {
                return _apply_order(a, b, op);
            }
            i += 1;
        }
        return _apply_order(len(self), len(oa), op);
    }
}


def _items_equal(a: any, b: any) -> bool {
    if isinstance(a, float) or isinstance(b, float) {
        fa: float = a;
        fb: float = b;
        return fa == fb;
    }
    return a == b;
}

def _apply_order(a: any, b: any, op: str) -> bool {
    # Same-typecode arrays hold homogeneous items, so compare within one
    # concrete type (int compares must stay exact past 2**53).
    if isinstance(a, str) {
        sa: str = a;
        sb: str = b;
        if op == "<" {
            return sa < sb;
        }
        if op == "<=" {
            return sa <= sb;
        }
        if op == ">" {
            return sa > sb;
        }
        return sa >= sb;
    }
    fa: float = a;
    fb: float = b;
    if op == "<" {
        return fa < fb;
    }
    if op == "<=" {
        return fa <= fb;
    }
    if op == ">" {
        return fa > fb;
    }
    return fa >= fb;
}

def _format_item(v: any, tc: str) -> str {
    if _tc_is_char(tc) {
        return "'" + v + "'";
    }
    return str(v);
}


obj ArrayIter {
    has arr: any = None,
        idx: int = 0;


    def __iter__ -> ArrayIter {
        return self;
    }

    def __next__ -> any {
        a: any = self.arr;
        if a is None or self.idx >= a.__len__() {
            self.arr = None;
            raise StopIteration();
        }
        item = a._unpack_at(self.idx);
        self.idx += 1;
        return item;
    }
}


# ---------------------------------------------------------------------------
# Construction (mirrors array_new + extend/frombytes/fromunicode paths)
# ---------------------------------------------------------------------------

def _p2_array(typecode: any, initializer: any = None) -> Array {
    if not isinstance(typecode, str) {
        raise TypeError("array() argument 1 must be a unicode character, not " + _type_name(typecode));
    }
    if len(typecode) != 1 {
        raise TypeError("array() argument 1 must be a unicode character, not a string of length " + str(len(typecode)));
    }
    idx = _tc_index(typecode);
    if idx < 0 {
        raise ValueError("bad typecode (must be b, B, u, w, h, H, i, I, l, L, q, Q, f or d)");
    }
    a = Array();
    a.typecode = typecode;
    a.itemsize = _tc_itemsize(idx);
    a.data = bytearray();
    if initializer is None {
        return a;
    }
    if isinstance(initializer, bytes) or isinstance(initializer, bytearray) {
        _p2_array_frombytes(a, initializer);
        return a;
    }
    if isinstance(initializer, str) {
        if not _tc_is_char(a.typecode) {
            raise TypeError("cannot use a str to initialize an array with typecode '" + a.typecode + "'");
        }
        for ch in initializer {
            a._append_value(ch);
        }
        return a;
    }
    if isinstance(initializer, Array) {
        if initializer.typecode != a.typecode {
            raise TypeError("can only extend with array of same typecode");
        }
        a.data += initializer.data;
        return a;
    }
    for v in initializer {
        a._append_value(v);
    }
    return a;
}


def _p2_array_frombytes(a: Array, buf: any) {
    if len(buf) % a.itemsize != 0 {
        raise ValueError("bytes length not a multiple of item size");
    }
    a.data += bytearray(buf);
}
