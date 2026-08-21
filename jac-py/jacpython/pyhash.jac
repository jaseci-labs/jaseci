# P3.2a — CPython hash algorithms (``Py_HashBuffer`` / ``_Py_HashDouble``).
#
# String hashing uses SipHash13 with the embedding interpreter's ``_Py_HashSecret``
# (process-local, matches host ``hash(str)``). Float hashing is fully algorithmic.
import from objects {
    PyFloat,
}

::py::
import ctypes
import math

U64 = 0xFFFFFFFFFFFFFFFF
PyHASH_MODULUS = (1 << 61) - 1
PyHASH_BITS = 61
PyHASH_INF = 314159


class _SipHashKeys(ctypes.Structure):
    _fields_ = [("k0", ctypes.c_uint64), ("k1", ctypes.c_uint64)]


class _HashSecretUnion(ctypes.Union):
    _fields_ = [("uc", ctypes.c_ubyte * 24), ("siphash", _SipHashKeys)]


_secret = _HashSecretUnion.in_dll(ctypes.CDLL(None), "_Py_HashSecret")
_SIPHASH_K0 = int(_secret.siphash.k0)
_SIPHASH_K1 = int(_secret.siphash.k1)


def _u64(x: int) -> int:
    return int(x) & U64


def _pyhash_t(x: int) -> int:
    x = _u64(x)
    if x >= 0x8000000000000000:
        return x - 0x10000000000000000
    return x


def _rotl64(x: int, b: int) -> int:
    x = _u64(x)
    return _u64((x << b) | (x >> (64 - b)))


def _half_round(a, b, c, d, s, t):
    a = _u64(a + b)
    c = _u64(c + d)
    b = _u64(_rotl64(b, s) ^ a)
    d = _u64(_rotl64(d, t) ^ c)
    a = _rotl64(a, 32)
    return a, b, c, d


def _single_round(v0, v1, v2, v3):
    v0, v1, v2, v3 = _half_round(v0, v1, v2, v3, 13, 16)
    v2, v1, v0, v3 = _half_round(v2, v1, v0, v3, 17, 21)
    return v0, v1, v2, v3


def _le64_from_bytes(data: list[int], off: int) -> int:
    x = 0
    for j in range(8):
        x |= data[off + j] << (8 * j)
    return _u64(x)


def _le64_from_tail(data: list[int], off: int, rem: int) -> int:
    x = 0
    for j in range(rem):
        x |= data[off + j] << (8 * j)
    return _u64(x)


def _siphash13(k0: int, k1: int, data: list[int]) -> int:
    src_sz = len(data)
    b = _u64(src_sz << 56)
    off = 0
    remain = src_sz
    v0 = _u64(k0 ^ 0x736F6D6570736575)
    v1 = _u64(k1 ^ 0x646F72616E646F6D)
    v2 = _u64(k0 ^ 0x6C7967656E657261)
    v3 = _u64(k1 ^ 0x7465646279746573)
    while remain >= 8:
        mi = _le64_from_bytes(data, off)
        off += 8
        remain -= 8
        v3 = _u64(v3 ^ mi)
        v0, v1, v2, v3 = _single_round(v0, v1, v2, v3)
        v0 = _u64(v0 ^ mi)
    t = _le64_from_tail(data, off, remain)
    b = _u64(b | t)
    v3 = _u64(v3 ^ b)
    v0, v1, v2, v3 = _single_round(v0, v1, v2, v3)
    v0 = _u64(v0 ^ b)
    v2 = _u64(v2 ^ 0xFF)
    v0, v1, v2, v3 = _single_round(v0, v1, v2, v3)
    v0, v1, v2, v3 = _single_round(v0, v1, v2, v3)
    v0, v1, v2, v3 = _single_round(v0, v1, v2, v3)
    return _pyhash_t(_u64((v0 ^ v1) ^ (v2 ^ v3)))


def _unicode_hash_payload(s: str) -> list[int]:
    if not s:
        return []
    m = max(ord(c) for c in s)
    if m < 256:
        return [ord(c) for c in s]
    if m <= 0xFFFF:
        return list(s.encode("utf-16-le"))
    return list(s.encode("utf-32-le"))


def _hash_buffer(data: list[int]) -> int:
    if len(data) == 0:
        return 0
    x = _siphash13(_SIPHASH_K0, _SIPHASH_K1, data)
    if x == -1:
        return -2
    return x


def _hash_pointer(ptr: int) -> int:
    x = _u64(ptr)
    x = _u64((x >> 4) | (x << 60))
    if x == -1:
        return -2
    return x


def _hash_double(v: float) -> int:
    if not math.isfinite(v):
        if math.isinf(v):
            return PyHASH_INF if v > 0.0 else -PyHASH_INF
        return 0
    m, e = math.frexp(v)
    sign = 1
    if m < 0.0:
        sign = -1
        m = -m
    x = 0
    while m:
        x = ((x << 28) & PyHASH_MODULUS) | (x >> (PyHASH_BITS - 28))
        m *= 268435456.0
        e -= 28
        y = int(m)
        m -= y
        x += y
        if x >= PyHASH_MODULUS:
            x -= PyHASH_MODULUS
    if e >= 0:
        e = e % PyHASH_BITS
    else:
        e = PyHASH_BITS - 1 - ((-1 - e) % PyHASH_BITS)
    x = ((x << e) & PyHASH_MODULUS) | (x >> (PyHASH_BITS - e))
    x = x * sign
    if x == -1:
        return -2
    return x


def _py_str_hash_text(s: str) -> int:
    return _hash_buffer(_unicode_hash_payload(s))


def _py_float_hash_value(ptr: int, val: float) -> int:
    if val != val:
        return _hash_pointer(ptr)
    return _hash_double(val)
::py::


def str_hash_text(s: str) -> int {
    return int(_py_str_hash_text(s));
}

def float_hash_value(v: PyFloat) -> int {
    return int(_py_float_hash_value(id(v), v.val));
}
