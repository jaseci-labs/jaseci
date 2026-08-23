# P3.2a — tuple core algorithms (xxHash + richcompare).
#
# c2jac-assisted from ``jac-py/tools/p3_object_core/corpus/tupleobject_core.c``
# (lift: ``jac-py/Objects/_lifted/tupleobject_core.jac``).
import from objects { PyObj, PyTuple, PyBool, PyInt, is_error, _cmp3, _bool_from_cmp, _signed_hash, Py_EQ, Py_NE, }
import from pyhash { xx_hash_mix, _PyHASH_XXPRIME_5, }
import from hash_dispatch { hash_element, }
import from abstract_protocol {
    PyObject_RichCompare,
    PyObject_RichCompareBool,
}

glob _PyTuple_MASK: int = 0xFFFFFFFFFFFFFFFF;

# CPython ``tuple_hash`` (xxHash-style lane mixing from ``tupleobject.c``;
# the constants/rotate live in ``pyhash.xx_hash_mix``).
def tuple_hash(v: PyTuple) -> PyObj {
    acc = _PyHASH_XXPRIME_5;
    tlen = len(v.items);
    i = 0;
    while i < tlen {
        lane_obj = hash_element(v.items[i]);
        if is_error(lane_obj) {
            return lane_obj;
        }
        acc = xx_hash_mix(acc, (lane_obj as PyInt).val);
        i = i + 1;
    }
    acc = (acc + (tlen ^ (_PyHASH_XXPRIME_5 ^ 3527539))) & _PyTuple_MASK;
    if acc == _PyTuple_MASK {
        acc = 1546275796;
    }
    return PyInt(t="int", val=_signed_hash(acc));
}

# CPython ``tuple_richcompare`` — no EQ/NE early-out on length mismatch.
def tuple_richcompare(op: int, vl: PyTuple, wl: PyTuple) -> PyObj {
    vlen = len(vl.items);
    wlen = len(wl.items);
    i = 0;
    while i < vlen and i < wlen {
        k = PyObject_RichCompareBool(vl.items[i], wl.items[i], Py_EQ);
        if k < 0 {
            return PyObject_RichCompare(vl.items[i], wl.items[i], Py_EQ);
        }
        if k == 0 {
            break;
        }
        i = i + 1;
    }
    if i >= vlen or i >= wlen {
        return _bool_from_cmp(_cmp3(vlen, wlen), op);
    }
    if op == Py_EQ {
        return PyBool(t="bool", val=False);
    }
    if op == Py_NE {
        return PyBool(t="bool", val=True);
    }
    return PyObject_RichCompare(vl.items[i], wl.items[i], op);
}
