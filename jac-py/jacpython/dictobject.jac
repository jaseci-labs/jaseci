# P3.2a — dict core algorithms (open-addressing probe + richcompare).
#
# c2jac-assisted from ``jac-py/tools/p3_object_core/corpus/dictobject_core.c``
# (lift: ``jac-py/Objects/_lifted/dictobject_core.jac``).
#
# Runtime dicts use hashkey-backed ``dict[str, DictEntry]`` in ``objects.jac``.
# Open-addressing helpers below are c2jac reference for a future native table.
import from objects { PyObj, PyDict, PyBool, PyStr, is_error, py_error, expect_str, _object_is_true, Py_EQ, Py_NE, }
import from abstract_protocol {
    PyObject_RichCompareBool,
}
glob PERTURB_SHIFT: int = 5,
     DKIX_EMPTY: int = -1,
     DKIX_ERROR: int = -3;


def dictkeys_get_index(indices: list[int], i: int) -> int {
    return indices[i];
}

def dictkeys_set_index(indices: list[int], i: int, ix: int) {
    indices[i] = ix;
}

# CPython probe recurrence: ``j = (5*j + 1 + perturb) mod 2**i`` with
# ``perturb >>= PERTURB_SHIFT`` each step (``dictobject.c`` comment block).
def dict_probe_step(i: int, perturb: int, mask: int) -> tuple[int, int] {
    perturb = perturb >> PERTURB_SHIFT;
    i = mask & (i * 5 + perturb + 1);
    return (i, perturb);
}

def dict_initial_index(hash: int, mask: int) -> int {
    return hash & mask;
}

# Simulate ``find_empty_slot`` over a fixed index table (``ix >= 0`` = occupied).
def dict_find_empty_slot(hash: int, mask: int, indices: list[int]) -> int {
    i = dict_initial_index(hash, mask);
    ix = indices[i];
    perturb = hash;
    while ix >= 0 {
        (i, perturb) = dict_probe_step(i, perturb, mask);
        ix = indices[i];
    }
    return i;
}

# ``lookdict_index`` — find hash-table slot holding entry index ``index``.
def lookdict_index(indices: list[int], mask: int, hashval: int, index: int) -> int {
    perturb = hashval;
    i = hashval & mask;
    while True {
        ix = dictkeys_get_index(indices, i);
        if ix == index {
            return i;
        }
        if ix == DKIX_EMPTY {
            return DKIX_EMPTY;
        }
        (i, perturb) = dict_probe_step(i, perturb, mask);
    }
}

# Generic open-addressing lookup on a simplified combined-table model.
def dictkeys_generic_lookup(
    indices: list[int],
    entries: list[tuple[int, PyObj, PyObj]],
    mask: int,
    key: PyObj,
    hashval: int,
) -> int {
    perturb = hashval;
    i = hashval & mask;
    while True {
        ix = dictkeys_get_index(indices, i);
        if ix >= 0 {
            (entry_hash, entry_key, _entry_val) = entries[ix];
            if entry_key is key {
                return ix;
            }
            if entry_hash == hashval {
                cmp = PyObject_RichCompareBool(entry_key, key, Py_EQ);
                if cmp < 0 {
                    return DKIX_ERROR;
                }
                if cmp != 0 {
                    return ix;
                }
            }
        } elif ix == DKIX_EMPTY {
            return DKIX_EMPTY;
        }
        (i, perturb) = dict_probe_step(i, perturb, mask);
    }
}

# CPython dict equality adapted to PyDict hashkey buckets (``dict_equal_lock_held``).
# ``compare_fn`` is ``py_compare`` from ceval (element-wise dispatch + user slots).
def dict_equal(a: PyDict, b: PyDict, compare_fn: any) -> PyObj {
    if len(a.items) != len(b.items) {
        return PyBool(t="bool", val=False);
    }
    for hk in a.items {
        ak = a.items[hk].key;
        av = a.items[hk].value;
        if not (hk in b.items) {
            return PyBool(t="bool", val=False);
        }
        bk = b.items[hk].key;
        bv = b.items[hk].value;
        if ak is not bk {
            keq = compare_fn(Py_EQ, ak, bk);
            if is_error(keq) {
                return keq;
            }
            if not _object_is_true(keq) {
                return PyBool(t="bool", val=False);
            }
        }
        if av is not bv {
            veq = compare_fn(Py_EQ, av, bv);
            if is_error(veq) {
                return veq;
            }
            if not _object_is_true(veq) {
                return PyBool(t="bool", val=False);
            }
        }
    }
    return PyBool(t="bool", val=True);
}

def dict_richcompare(op: int, a: PyDict, b: PyDict, compare_fn: any) -> PyObj {
    if op != Py_EQ and op != Py_NE {
        return py_error(
            "TypeError", "'<' not supported between instances of 'dict' and 'dict'"
        );
    }
    eq = dict_equal(a, b, compare_fn);
    if is_error(eq) {
        return eq;
    }
    if op == Py_EQ {
        return eq;
    }
    return PyBool(t="bool", val=not _object_is_true(eq));
}

# CPython ``dict_repr_lock_held`` — insertion-order walk with strong refs.
def dict_repr(d: PyDict, repr_elem: any) -> PyObj {
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
