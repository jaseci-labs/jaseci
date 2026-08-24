# P3.2a — dict core algorithms (richcompare / equality on hashkey buckets).
#
# c2jac-assisted from ``jac-py/tools/p3_object_core/corpus/dictobject_core.c``
# (lift: ``jac-py/Objects/_lifted/dictobject_core.jac``).
#
# Runtime dicts use hashkey-backed ``dict[str, DictEntry]`` in ``objects.jac``;
# CPython's open-addressing table is not modeled. The c2jac reference lives in
# ``Objects/_lifted/dictobject_core.jac`` if a native table lands later.
import from objects { PyObj, PyDict, PyStr, is_error, py_error, expect_str, Py_EQ, Py_NE, }

# Thin wrappers kept for callers that import by name (the ``compare_fn``
# parameter is obsolete): the implementation lives on the PyDict.tp_richcompare
# slot / PyDict.dict_equal in objects.jac, which run key/value compares through
# the full protocol.
def dict_equal(a: PyDict, b: PyDict) -> PyObj {
    return a.dict_equal(b);
}

def dict_richcompare(op: int, a: PyDict, b: PyDict, compare_fn: any) -> PyObj {
    # Direct callers (py_compare's dict branch) need the ordering TypeError
    # raised here -- the tp_richcompare slot itself defers non-EQ/NE ops.
    if op != Py_EQ and op != Py_NE {
        return py_error(
            "TypeError", "'<' not supported between instances of 'dict' and 'dict'"
        );
    }
    return a.tp_richcompare(op, b);
}

# CPython ``dict_repr_lock_held`` — insertion-order walk with strong refs.
#
# Cycle guard (Py_ReprEnter/Py_ReprLeave contract): a dict already mid-repr
# prints as {...} when re-encountered, so self-referential dicts repr like
# CPython instead of blowing the stack.
glob dict_repr_active: list[PyDict] = [];

def dict_repr(d: PyDict, repr_elem: any) -> PyObj {
    for seen in dict_repr_active {
        if seen is d {
            return PyStr(t="str", val="{...}");
        }
    }
    dict_repr_active.append(d);
    res = _dict_repr_walk(d, repr_elem);
    dict_repr_active.pop();
    return res;
}

def _dict_repr_walk(d: PyDict, repr_elem: any) -> PyObj {
    if len(d.items) == 0 {
        return PyStr(t="str", val="{}");
    }
    out = "{";
    first = True;
    for hk in d.items {
        `entry = d.items[hk];
        if not first {
            out = out + ", ";
        }
        first = False;
        kpiece = repr_elem(`entry.key);
        if is_error(kpiece) {
            return kpiece;
        }
        vpiece = repr_elem(`entry.value);
        if is_error(vpiece) {
            return vpiece;
        }
        out = out + expect_str(kpiece) + ": " + expect_str(vpiece);
    }
    return PyStr(t="str", val=out + "}");
}
