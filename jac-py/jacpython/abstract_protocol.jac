# P3.1e — PyObject_* protocol helpers (comparison / iter / hash).
#
# c2jac-assisted from ``jac-py/tools/p3_object_core/corpus/abstract_protocol.c``
# (lift: ``jac-py/Objects/_lifted/abstract_protocol.jac``). Runtime uses Jac
# virtual slots on ``PyObj`` instead of C ``tp_*`` function pointers.
import from objects { PyObj, PyBool, PyInt, is_error, py_error, PY_NOT_IMPLEMENTED, }

glob _Py_SwappedOp: list[int] = [4, 5, 2, 3, 0, 1];

# CPython Py_LT..Py_GE
glob Py_LT: int = 0,
     Py_LE: int = 1,
     Py_EQ: int = 2,
     Py_NE: int = 3,
     Py_GT: int = 4,
     Py_GE: int = 5;


def _object_is_true(res: PyObj) -> bool {
    if is_error(res) {
        return False;
    }
    if isinstance(res, PyBool) {
        return (res as PyBool).val;
    }
    if res.t == "none" {
        return False;
    }
    if res.t == "int" {
        return (res as PyInt).val != 0;
    }
    return True;
}

def _richcompare_to_bool(res: PyObj) -> int {
    if is_error(res) {
        return -1;
    }
    if _object_is_true(res) {
        return 1;
    }
    return 0;
}

# ``PyObject_RichCompare`` for native ``PyObj`` operands: left slot, reflected
# right slot, then identity fallback for ``==`` / ``!=`` only.
def PyObject_RichCompare(v: PyObj, w: PyObj, op: int) -> PyObj {
    res = v.tp_richcompare(op, w);
    if is_error(res) {
        return res;
    }
    if res is not PY_NOT_IMPLEMENTED {
        return res;
    }
    swapped = _Py_SwappedOp[op];
    res = w.tp_richcompare(swapped, v);
    if is_error(res) {
        return res;
    }
    if res is not PY_NOT_IMPLEMENTED {
        return res;
    }
    if op == Py_EQ {
        return PyBool(t="bool", val=v is w);
    }
    if op == Py_NE {
        return PyBool(t="bool", val=v is not w);
    }
    return py_error("TypeError", "unorderable types");
}

# Integer tri-state: 1 true, 0 false, -1 error (matches C API).
def PyObject_RichCompareBool(v: PyObj, w: PyObj, op: int) -> int {
    if v is w {
        if op == Py_EQ {
            return 1;
        }
        if op == Py_NE {
            return 0;
        }
    }
    res = PyObject_RichCompare(v, w, op);
    return _richcompare_to_bool(res);
}

# Deterministic digest of ``tp_hashkey()`` for dict/set keying only — not the
# user-facing ``hash()`` int (see ``hash_dispatch.hash_element`` / ``py_hash``).
def _hashkey_digest(hk: str) -> int {
    if hk.startswith("n:") {
        v = int(hk[2:]);
        if v == -1 {
            return -2;
        }
        return v;
    }
    h = 1469598103934665603;
    i = 0;
    while i < len(hk) {
        h = h ^ ord(hk[i]);
        h = (h * 1099511628211) & 0xFFFFFFFFFFFFFFFF;
        i = i + 1;
    }
    if h >= 0x8000000000000000 {
        h = h - 0x10000000000000000;
    }
    return h;
}

def PyObject_HashNotImplemented(v: PyObj) -> PyObj {
    return py_error("TypeError", "unhashable type: '" + v.t + "'");
}

def PyObject_Hash(v: PyObj) -> PyObj {
    hk = v.tp_hashkey();
    if hk == "" {
        return PyObject_HashNotImplemented(v);
    }
    return PyInt(t="int", val=_hashkey_digest(hk));
}

# ``abstract.c`` iterator surface: ``tp_iter`` + iterator-type check.
def PyIter_Check(value: PyObj) -> bool {
    return value.t == "iter" or value.t == "generator" or value.t == "dictiter";
}

def PyObject_GetIter(o: PyObj) -> PyObj {
    res = o.tp_iter();
    if is_error(res) {
        return res;
    }
    if not PyIter_Check(res) {
        return py_error(
            "TypeError", "iter() returned non-iterator of type '" + res.t + "'"
        );
    }
    return res;
}
