# P3.2a — list core algorithms (richcompare, repr).
#
# c2jac-assisted from ``jac-py/tools/p3_object_core/corpus/listobject_core.c``
# (lift: ``jac-py/Objects/_lifted/listobject_core.jac``).
import from objects {
    PyObj,
    PyList,
    PyStr,
    is_error,
    expect_str,
}

# Thin wrapper kept for callers that import by name (the ``compare_fn``
# parameter is obsolete): the implementation lives on the PyList.tp_richcompare
# slot in objects.jac, which runs element compares through the full protocol.
def list_richcompare(op: int, vl: PyList, wl: PyList, compare_fn: any) -> PyObj {
    return vl.tp_richcompare(op, wl);
}

# CPython ``list_repr_impl``: strong ref per element, re-fetch length each step.
# Cycle guard (Py_ReprEnter/Py_ReprLeave contract): a list already mid-repr
# prints as [...] when re-encountered (self-referential lists).
glob list_repr_active: list[PyList] = [];

def list_repr(v: PyList, repr_elem: any) -> PyObj {
    for seen in list_repr_active {
        if seen is v {
            return PyStr(t="str", val="[...]");
        }
    }
    list_repr_active.append(v);
    res = _list_repr_walk(v, repr_elem);
    list_repr_active.pop();
    return res;
}

def _list_repr_walk(v: PyList, repr_elem: any) -> PyObj {
    if len(v.items) == 0 {
        return PyStr(t="str", val="[]");
    }
    out = "[";
    i = 0;
    while i < len(v.items) {
        if i > 0 {
            out = out + ", ";
        }
        item = v.items[i];
        piece = repr_elem(item);
        if is_error(piece) {
            return piece;
        }
        out = out + expect_str(piece);
        i = i + 1;
    }
    return PyStr(t="str", val=out + "]");
}
