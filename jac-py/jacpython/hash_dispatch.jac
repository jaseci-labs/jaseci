# P3 — user-facing ``hash()`` dispatch for builtin ``PyObj`` types.
#
# ``tp_hashkey()`` + FNV (``abstract_protocol.PyObject_Hash``) is the internal
# dict/set key protocol only. ``hash()`` and container hashes (tuple/set lanes)
# must route through CPython algorithms (``long_hash``, native str/float hash,
# ``bytes_hash``, etc.).
import from objects { PyObj, PyInt, PyStr, PyFloat, PyBool, PyBytes, PySlice, PyNoneType, is_error, _signed_hash, }
import from abstract_protocol { PyObject_HashNotImplemented, _hashkey_digest, }
import from pyhash { xx_hash_mix, _PyHASH_XXPRIME_5, _U64, }
import from longobject { long_hash_obj, long_hash, }
import from bytesobject { bytes_hash_obj, }
import from strobject { str_hash_obj, }
import from floatobject { float_hash_obj, }

# CPython 3.12+ gives None a deterministic pointer-derived hash (constant
# across builds), so slices with None bounds hash identically to the host.
glob _PYHASH_NONE: int = 4238894112;

# CPython ``slice_hash`` (sliceobject.c, 3.12+): xxHash mix over the
# start/stop/step lane hashes -- no length term -- with -1 mapped to 1546275796.
def slice_hash(sl: PySlice) -> PyObj {
    acc = _PyHASH_XXPRIME_5;
    parts: list[PyObj] = [sl.start, sl.stop, sl.step];
    for part in parts {
        if isinstance(part, PyNoneType) {
            lane = _PYHASH_NONE;
        } else {
            h = hash_element(part);
            if is_error(h) {
                return h;
            }
            lane = (h as PyInt).val;
        }
        acc = xx_hash_mix(acc, lane);
    }
    if acc == _U64 {
        acc = 1546275796;
    }
    return PyInt(t="int", val=_signed_hash(acc));
}

# Element hash for tuple/set lanes and ``py_hash`` fallback (not tuples/sets).
def hash_element(v: PyObj) -> PyObj {
    if isinstance(v, PyInt) {
        return long_hash_obj(v as PyInt);
    }
    if isinstance(v, PyBool) {
        if (v as PyBool).val {
            return PyInt(t="int", val=long_hash(1));
        }
        return PyInt(t="int", val=long_hash(0));
    }
    if isinstance(v, PyStr) {
        return str_hash_obj(v as PyStr);
    }
    if isinstance(v, PyFloat) {
        return float_hash_obj(v as PyFloat);
    }
    if isinstance(v, PyBytes) {
        return bytes_hash_obj(v as PyBytes);
    }
    if isinstance(v, PySlice) {
        return slice_hash(v as PySlice);
    }
    hk = v.tp_hashkey();
    if hk == "" {
        return PyObject_HashNotImplemented(v);
    }
    return PyInt(t="int", val=_hashkey_digest(hk));
}
