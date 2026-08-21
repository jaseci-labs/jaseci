# P3.2a — long core algorithms (digit vector ops, compare, hash).
#
# c2jac-assisted from ``jac-py/tools/p3_object_core/corpus/longobject_core.c``
# (lift: ``jac-py/Objects/_lifted/longobject_core.jac``).
#
# Runtime ``ceval`` uses ``PyInt.val`` for bignum ops; ``long_hash_obj`` is wired.
# Digit-vector helpers below are c2jac reference until Layer-1 replay needs them.
import from objects { PyObj, PyInt, PyStr, PyBool, is_error, }
import from abstract_protocol { Py_LT, Py_LE, Py_EQ, Py_NE, Py_GT, Py_GE, }

glob PyLong_SHIFT: int = 30,
     PyLong_MASK: int = 1073741823,
     PyLong_BASE: int = 1073741824,
     _PyHASH_BITS: int = 61,
     _PyHASH_MODULUS: int = 2305843009213693951;


def _digit_count(abs_v: int) -> int {
    if abs_v == 0 {
        return 0;
    }
    count = 0;
    tmp = abs_v;
    while tmp > 0 {
        count = count + 1;
        tmp = tmp >> PyLong_SHIFT;
    }
    return count;
}

def _abs_digits(value: int) -> list[int] {
    abs_v = value;
    if value < 0 {
        abs_v = -value;
    }
    digits: list[int] = [];
    if abs_v == 0 {
        digits.append(0);
        return digits;
    }
    tmp = abs_v;
    while tmp > 0 {
        digits.append(tmp & PyLong_MASK);
        tmp = tmp >> PyLong_SHIFT;
    }
    return digits;
}

def _digits_to_int(digits: list[int], negative: bool) -> int {
    result = 0;
    i = len(digits) - 1;
    while i >= 0 {
        result = (result << PyLong_SHIFT) + digits[i];
        i = i - 1;
    }
    if negative {
        return -result;
    }
    return result;
}

# ``v_iadd`` — in-place add digit vectors (LSD first).
def v_iadd(x: list[int], y: list[int]) -> int {
    m = len(x);
    n = len(y);
    carry = 0;
    i = 0;
    while i < n {
        carry = carry + x[i] + y[i];
        x[i] = carry & PyLong_MASK;
        carry = carry >> PyLong_SHIFT;
        i = i + 1;
    }
    while carry != 0 and i < m {
        carry = carry + x[i];
        x[i] = carry & PyLong_MASK;
        carry = carry >> PyLong_SHIFT;
        i = i + 1;
    }
    return carry;
}

# ``v_isub`` — in-place subtract digit vectors (LSD first).
def v_isub(x: list[int], y: list[int]) -> int {
    m = len(x);
    n = len(y);
    borrow = 0;
    i = 0;
    while i < n {
        borrow = x[i] - y[i] - borrow;
        x[i] = borrow & PyLong_MASK;
        borrow = borrow >> PyLong_SHIFT;
        borrow = borrow & 1;
        i = i + 1;
    }
    while borrow != 0 and i < m {
        borrow = x[i] - borrow;
        x[i] = borrow & PyLong_MASK;
        borrow = borrow >> PyLong_SHIFT;
        borrow = borrow & 1;
        i = i + 1;
    }
    return borrow;
}

# Absolute-value add on signed integers via digit vectors.
def x_add(a: int, b: int) -> int {
    da = _abs_digits(a);
    db = _abs_digits(b);
    size_a = len(da);
    size_b = len(db);
    if size_a < size_b {
        tmpd = da;
        da = db;
        db = tmpd;
        tmpn = size_a;
        size_a = size_b;
        size_b = tmpn;
    }
    z: list[int] = [];
    i = 0;
    while i < size_a + 1 {
        z.append(0);
        i = i + 1;
    }
    carry = 0;
    i = 0;
    while i < size_b {
        carry = carry + da[i] + db[i];
        z[i] = carry & PyLong_MASK;
        carry = carry >> PyLong_SHIFT;
        i = i + 1;
    }
    while i < size_a {
        carry = carry + da[i];
        z[i] = carry & PyLong_MASK;
        carry = carry >> PyLong_SHIFT;
        i = i + 1;
    }
    z[i] = carry;
    while len(z) > 1 and z[len(z) - 1] == 0 {
        z.pop();
    }
    return _digits_to_int(z, False);
}

# Absolute-value subtract on signed integers via digit vectors.
def x_sub(a: int, b: int) -> int {
    da = _abs_digits(a);
    db = _abs_digits(b);
    size_a = len(da);
    size_b = len(db);
    sign = 1;
    if size_a < size_b {
        sign = -1;
        tmpd = da;
        da = db;
        db = tmpd;
        tmpn = size_a;
        size_a = size_b;
        size_b = tmpn;
    } elif size_a == size_b {
        i = size_a - 1;
        while i >= 0 and da[i] == db[i] {
            i = i - 1;
        }
        if i < 0 {
            return 0;
        }
        if da[i] < db[i] {
            sign = -1;
            tmpd = da;
            da = db;
            db = tmpd;
        }
        size_a = i + 1;
        size_b = i + 1;
    }
    z: list[int] = [];
    j = 0;
    while j < size_a {
        z.append(0);
        j = j + 1;
    }
    borrow = 0;
    i = 0;
    while i < size_b {
        borrow = da[i] - db[i] - borrow;
        z[i] = borrow & PyLong_MASK;
        borrow = borrow >> PyLong_SHIFT;
        borrow = borrow & 1;
        i = i + 1;
    }
    while i < size_a {
        borrow = da[i] - borrow;
        z[i] = borrow & PyLong_MASK;
        borrow = borrow >> PyLong_SHIFT;
        borrow = borrow & 1;
        i = i + 1;
    }
    while len(z) > 1 and z[len(z) - 1] == 0 {
        z.pop();
    }
    result = _digits_to_int(z, sign < 0);
    return result;
}

# Signed add using CPython sign/magnitude rules (``long_add`` fast path).
def long_add(a: int, b: int) -> int {
    if a >= 0 and b >= 0 {
        return x_add(a, b);
    }
    if a < 0 and b < 0 {
        return -x_add(-a, -b);
    }
    if a < 0 {
        return long_sub(b, a);
    }
    return long_sub(a, b);
}

def long_sub(a: int, b: int) -> int {
    if b < 0 {
        return long_add(a, -b);
    }
    if a < 0 {
        return -long_add(-a, b);
    }
    cmp = long_compare(a, b);
    if cmp == 0 {
        return 0;
    }
    if cmp > 0 {
        return x_sub(a, b);
    }
    return -x_sub(b, a);
}

# ``long_compare`` — tri-state signed magnitude compare.
def long_compare(a: int, b: int) -> int {
    if _digit_count(a if a >= 0 else -a) <= 1
        and _digit_count(b if b >= 0 else -b) <= 1 {
        if a < b {
            return -1;
        }
        if a > b {
            return 1;
        }
        return 0;
    }
    sign_a = 1;
    abs_a = a;
    if a < 0 {
        sign_a = -1;
        abs_a = -a;
    }
    sign_b = 1;
    abs_b = b;
    if b < 0 {
        sign_b = -1;
        abs_b = -b;
    }
    nda = _digit_count(abs_a);
    ndb = _digit_count(abs_b);
    if sign_a != sign_b {
        if sign_a < 0 {
            return -1;
        }
        return 1;
    }
    if nda != ndb {
        if sign_a < 0 {
            if nda > ndb {
                return -1;
            }
            return 1;
        }
        if nda > ndb {
            return 1;
        }
        return -1;
    }
    da = _abs_digits(a);
    db = _abs_digits(b);
    i = len(da) - 1;
    while i >= 0 {
        diff = da[i] - db[i];
        if diff != 0 {
            if sign_a < 0 {
                return -diff;
            }
            return diff;
        }
        i = i - 1;
    }
    return 0;
}

def _richcompare_from_sign(cmp: int, op: int) -> PyObj {
    if op == Py_LT {
        return PyBool(t="bool", val=cmp < 0);
    }
    if op == Py_LE {
        return PyBool(t="bool", val=cmp <= 0);
    }
    if op == Py_EQ {
        return PyBool(t="bool", val=cmp == 0);
    }
    if op == Py_NE {
        return PyBool(t="bool", val=cmp != 0);
    }
    if op == Py_GT {
        return PyBool(t="bool", val=cmp > 0);
    }
    if op == Py_GE {
        return PyBool(t="bool", val=cmp >= 0);
    }
    return PyBool(t="bool", val=False);
}

def long_richcompare(op: int, a: PyInt, b: PyInt) -> PyObj {
    av = a.val;
    bv = b.val;
    if av == bv {
        return _richcompare_from_sign(0, op);
    }
    cmp = long_compare(av, bv);
    return _richcompare_from_sign(cmp, op);
}

# CPython ``long_hash`` — compact fast path + digit rotation for bignums.
def long_hash(value: int) -> int {
    if _digit_count(value if value >= 0 else -value) <= 1 {
        if value == -1 {
            return -2;
        }
        return value;
    }
    abs_v = value;
    sign = 1;
    if value < 0 {
        sign = -1;
        abs_v = -value;
    }
    digits = _abs_digits(abs_v);
    x = 0;
    i = len(digits) - 1;
    while i >= 0 {
        x = ((x << PyLong_SHIFT) & _PyHASH_MODULUS)
            | (x >> (_PyHASH_BITS - PyLong_SHIFT));
        x = x + digits[i];
        if x >= _PyHASH_MODULUS {
            x = x - _PyHASH_MODULUS;
        }
        i = i - 1;
    }
    x = x * sign;
    if x == -1 {
        return -2;
    }
    return x;
}

def long_hash_obj(v: PyInt) -> PyObj {
    return PyInt(t="int", val=long_hash(v.val));
}

# CPython ``long_repr`` — decimal text (``str(int)`` form).
def int_repr(v: PyInt) -> PyObj {
    return PyStr(t="str", val=str(v.val));
}
