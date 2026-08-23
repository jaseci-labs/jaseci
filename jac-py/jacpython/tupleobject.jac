# P3.2a — tuple core algorithms (xxHash + richcompare).
#
# c2jac-assisted from ``jac-py/tools/p3_object_core/corpus/tupleobject_core.c``
# (lift: ``jac-py/Objects/_lifted/tupleobject_core.jac``).
import from objects { PyObj, PyTuple, PyInt, is_error, _signed_hash, }
import from pyhash { xx_hash_mix, _PyHASH_XXPRIME_5, }
import from hash_dispatch { hash_element, }

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

# Thin wrapper kept for callers that import by name: the implementation lives
# on the PyTuple.tp_richcompare slot in objects.jac (the leaf owns container
# value equality so set/dict element confirmation can dispatch through it).
def tuple_richcompare(op: int, vl: PyTuple, wl: PyTuple) -> PyObj {
    return vl.tp_richcompare(op, wl);
}
