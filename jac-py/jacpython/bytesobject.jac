# P3.2a — bytes core algorithms (hash, richcompare, contains, repr).
#
# c2jac-assisted from ``jac-py/tools/p3_object_core/corpus/bytesobject_core.c``
# (lift: ``jac-py/Objects/_lifted/bytesobject_core.jac``).
import from objects { PyObj, PyBytes, PyInt, PyStr, PyBool, is_error, py_error, }
import from abstract_protocol { Py_LT, Py_LE, Py_EQ, Py_NE, Py_GT, Py_GE, }

::py::
def _cpython_bytes_hash(data: list) -> int:
    # ``Py_HashBuffer`` depends on process-local ``_Py_HashSecret``; delegate to
    # the embedding interpreter so Layer-1 replay matches host ``hash(bytes)``.
    if len(data) == 0:
        return 0
    return hash(bytes(data))
::py::



def _compare_ints(a: int, b: int, op: int) -> PyObj {
    if op == Py_LT {
        return PyBool(t="bool", val=a < b);
    }
    if op == Py_LE {
        return PyBool(t="bool", val=a <= b);
    }
    if op == Py_EQ {
        return PyBool(t="bool", val=a == b);
    }
    if op == Py_NE {
        return PyBool(t="bool", val=a != b);
    }
    if op == Py_GT {
        return PyBool(t="bool", val=a > b);
    }
    if op == Py_GE {
        return PyBool(t="bool", val=a >= b);
    }
    return PyBool(t="bool", val=False);
}

def _bytes_compare_eq(a: list[int], b: list[int]) -> bool {
    if len(a) != len(b) {
        return False;
    }
    if len(a) == 0 {
        return True;
    }
    if a[0] != b[0] {
        return False;
    }
    i = 0;
    while i < len(a) {
        if a[i] != b[i] {
            return False;
        }
        i = i + 1;
    }
    return True;
}

# CPython ``bytes_hash`` — ``Py_HashBuffer`` (host delegate for secret parity).
def bytes_hash_obj(v: PyBytes) -> PyObj {
    return PyInt(t="int", val=_cpython_bytes_hash(v.val));
}

# CPython ``bytes_richcompare`` (lexicographic; EQ/NE via ``bytes_compare_eq``).
def bytes_richcompare(op: int, a: PyBytes, b: PyBytes) -> PyObj {
    av = a.val;
    bv = b.val;
    if av is bv {
        if op == Py_EQ or op == Py_LE or op == Py_GE {
            return PyBool(t="bool", val=True);
        }
        return PyBool(t="bool", val=False);
    }
    if op == Py_EQ or op == Py_NE {
        eq = _bytes_compare_eq(av, bv);
        if op == Py_NE {
            eq = not eq;
        }
        return PyBool(t="bool", val=eq);
    }
    len_a = len(av);
    len_b = len(bv);
    min_len = len_a;
    if len_b < min_len {
        min_len = len_b;
    }
    c = 0;
    if min_len > 0 {
        c = av[0] - bv[0];
        if c == 0 {
            i = 0;
            while i < min_len {
                if av[i] != bv[i] {
                    c = av[i] - bv[i];
                    break;
                }
                i = i + 1;
            }
        }
    }
    if c != 0 {
        return _compare_ints(c, 0, op);
    }
    return _compare_ints(len_a, len_b, op);
}

# CPython ``_Py_bytes_contains`` — int subscript only (core slice scope).
def bytes_contains(data: list[int], needle: PyObj) -> PyObj {
    if needle.t != "int" {
        return py_error("TypeError", "an integer is required");
    }
    ival = (needle as PyInt).val;
    if ival < 0 or ival >= 256 {
        return py_error("ValueError", "byte must be in range(0, 256)");
    }
    i = 0;
    while i < len(data) {
        if data[i] == ival {
            return PyBool(t="bool", val=True);
        }
        i = i + 1;
    }
    return PyBool(t="bool", val=False);
}

def _repr_byte(ch: int) -> str {
    if ch == 92 {
        return "\\\\";
    }
    if ch == 9 {
        return "\\t";
    }
    if ch == 10 {
        return "\\n";
    }
    if ch == 13 {
        return "\\r";
    }
    if ch < 32 or ch >= 127 {
        hi = (ch >> 4) & 15;
        lo = ch & 15;
        return "\\x" + "0123456789abcdef"[hi] + "0123456789abcdef"[lo];
    }
    return chr(ch);
}

# CPython ``PyBytes_Repr`` (smart single quotes; ``b'...'`` form).
def bytes_repr(v: PyBytes) -> PyObj {
    data = v.val;
    if len(data) == 0 {
        return PyStr(t="str", val="b''");
    }
    squotes = 0;
    dquotes = 0;
    i = 0;
    while i < len(data) {
        if data[i] == 39 {
            squotes = squotes + 1;
        } elif data[i] == 34 {
            dquotes = dquotes + 1;
        }
        i = i + 1;
    }
    quote = 39;
    if squotes > 0 and dquotes == 0 {
        quote = 34;
    }
    out = "b";
    if quote == 39 {
        out = out + "'";
    } else {
        out = out + "\"";
    }
    i = 0;
    while i < len(data) {
        ch = data[i];
        if ch == quote {
            out = out + "\\";
            if quote == 39 {
                out = out + "'";
            } else {
                out = out + "\"";
            }
        } else {
            out = out + _repr_byte(ch);
        }
        i = i + 1;
    }
    if quote == 39 {
        out = out + "'";
    } else {
        out = out + "\"";
    }
    return PyStr(t="str", val=out);
}
