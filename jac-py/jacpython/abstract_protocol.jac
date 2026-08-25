# P3.1e — PyObject_* protocol helpers (hash / iter).
#
# c2jac-assisted from ``jac-py/tools/p3_object_core/corpus/abstract_protocol.c``
# (lift: ``jac-py/Objects/_lifted/abstract_protocol.jac``). Runtime uses Jac
# virtual slots on ``PyObj`` instead of C ``tp_*`` function pointers.
#
# The comparison half (PyObject_RichCompare / PyObject_RichCompareBool /
# _base_type_name / py_ordering_type_error) lives in objects.jac next to the
# tp_richcompare slots it drives -- container value equality must run element
# compares through that protocol, and Jac forbids import cycles.
import from objects {
    PyObj,
    PyInt,
    is_error,
    hashkey_str,
    py_error,
    _signed_hash,
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
    return _signed_hash(h);
}

def PyObject_HashNotImplemented(v: PyObj) -> PyObj {
    return py_error("TypeError", "unhashable type: '" + v.tp_type_name() + "'");
}

def PyObject_Hash(v: PyObj) -> PyObj {
    hkr = v.tp_hashkey();
    if is_error(hkr) {
        return PyObject_HashNotImplemented(v);
    }
    return PyInt(t="int", val=_hashkey_digest(hashkey_str(hkr)));
}

# ``abstract.c`` iterator surface: ``tp_iter`` + iterator-type check.
def PyIter_Check(value: PyObj) -> bool {
    return value.t == "iter" or value.t == "generator" or value.t == "dictiter"
        or value.t == "rangeiter" or value.t == "seqiter";
}

def PyObject_GetIter(o: PyObj) -> PyObj {
    # CPython: iter() over an ITERATOR returns it unchanged (no tp_iter
    # required). Without this, already-created iterators (rangeiter, seqiter,
    # calliter, generators) fail with "'X' object is not iterable" at every
    # consumer that calls iter() defensively.
    if PyIter_Check(o) {
        return o;
    }
    res = o.tp_iter();
    if is_error(res) {
        # Host-exact wording: CPython quotes the operand's type name in the
        # non-iterable TypeError ("'int' object is not iterable"). Upgrade
        # nameless slot fallbacks centrally so EVERY iter() consumer inherits
        # the wording (set/list displays, unpacking, builtins), instead of
        # each call site patching its own message.
        if (res as PyError).exception.message == "object is not iterable" {
            return py_error(
                "TypeError", "'" + o.tp_type_name() + "' object is not iterable"
            );
        }
        return res;
    }
    if not PyIter_Check(res) {
        return py_error(
            "TypeError", "iter() returned non-iterator of type '" + res.t + "'"
        );
    }
    return res;
}
