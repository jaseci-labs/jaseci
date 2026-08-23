# P3.2a — set core algorithms (frozenset hash + richcompare).
#
# c2jac-assisted from ``jac-py/tools/p3_object_core/corpus/setobject_core.c``
# (lift: ``jac-py/Objects/_lifted/setobject_core.jac``).
import from objects { PyObj, PySet, PyInt, is_error, _signed_hash, }
import from hash_dispatch { hash_element, }
import from abstract_protocol {
    PyObject_HashNotImplemented,
}

glob _PySet_MASK: int = 0xFFFFFFFFFFFFFFFF;


def _shuffle_bits(h: int) -> int {
    return (((h ^ 89869747) ^ ((h << 16) & _PySet_MASK)) * 3644798167) & _PySet_MASK;
}

# CPython ``frozenset_hash_impl`` — member XOR path (order-independent; matches
# host frozenset hash for active entries without dummy slots).
def frozenset_hash_impl(s: PySet) -> PyObj {
    acc = 0;
    for hk in s.items {
        lane_obj = hash_element(s.items[hk]);
        if is_error(lane_obj) {
            return lane_obj;
        }
        lane = (lane_obj as PyInt).val;
        acc = (acc ^ _shuffle_bits(lane & _PySet_MASK)) & _PySet_MASK;
    }
    size = len(s.items);
    acc = (acc ^ (((size + 1) * 1927868237) & _PySet_MASK)) & _PySet_MASK;
    acc = (acc ^ ((acc >> 11) ^ (acc >> 25))) & _PySet_MASK;
    acc = (acc * 69069 + 907133923) & _PySet_MASK;
    if acc == _PySet_MASK {
        acc = 590923713;
    }
    return PyInt(t="int", val=_signed_hash(acc));
}

def set_hash_obj(s: PySet) -> PyObj {
    if not s.frozen {
        return PyObject_HashNotImplemented(s);
    }
    return frozenset_hash_impl(s);
}

# CPython ``set_richcompare`` for two any-set operands. Thin wrapper kept for
# callers that import by name: the implementation lives on the PySet.
# tp_richcompare slot in objects.jac (subset algebra over element ``==``).
def set_richcompare(op: int, v: PySet, w: PySet) -> PyObj {
    return v.tp_richcompare(op, w);
}
