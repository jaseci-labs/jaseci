import from c { def memcpy(dst: bytes, src: int, n: u64) -> int;  }
import from c { def PyLong_AsLongLong(o: int) -> int;  }
import from c { def PyLong_FromLongLong(v: int) -> int;  }
import from c { def PyUnicode_AsUTF8AndSize(o: int, size_out: bytes) -> int;  }
import from c { def PyUnicode_FromStringAndSize(s: bytes, n: int) -> int;  }
import from c { def PyTuple_GetItem(t: int, i: int) -> int;  }
import from c { def PyList_New(n: int) -> int;  }
import from c { def PyList_SetItem(l: int, i: int, v: int) -> int;  }
import from c { def PyEval_GetBuiltins -> int;  }
import from c { def PyDict_GetItemString(d: int, key: str) -> int;  }
import from c { def PyErr_SetString(exc: int, msg: str) -> None;  }

import from jaclang.compiler.store.unitree_store {
    js_abi_version,
    js_kind_register,
    js_ekind_register,
    js_arena_new,
    js_arena_freeze,
    js_arena_frozen,
    js_arena_drop,
    js_node_new,
    js_node_kind,
    js_slot_get,
    js_slot_set,
    js_edge_add,
    js_adj_clear,
    js_subtree_copy,
    js_copy_slots,
    js_intern_bytes,
    js_intern_get_bytes,
    js_adj,
    js_adj_payloads
}

def:pub njs_abi_version -> int {
    return js_abi_version();
}

def:pub njs_kind_register(
    kind: int, nslots: int, frozen_mask: int, str_mask: int, ref_mask: int
) -> int {
    return js_kind_register(kind, nslots, frozen_mask, str_mask, ref_mask);
}

def:pub njs_ekind_register(ekind: int, is_struct: int) -> int {
    return js_ekind_register(ekind, is_struct);
}

def:pub njs_arena_new -> int {
    return js_arena_new();
}

def:pub njs_arena_freeze(a: int) -> int {
    return js_arena_freeze(a);
}

def:pub njs_arena_frozen(a: int) -> int {
    return js_arena_frozen(a);
}

def:pub njs_arena_drop(a: int) -> int {
    return js_arena_drop(a);
}

def:pub njs_node_new(a: int, kind: int) -> int {
    return js_node_new(a, kind);
}

def:pub njs_node_kind(h: int) -> int {
    return js_node_kind(h);
}

def:pub njs_slot_get(h: int, i: int) -> int {
    return js_slot_get(h, i);
}

def:pub njs_slot_set(h: int, i: int, v: int) -> int {
    return js_slot_set(h, i, v);
}

def:pub njs_edge_add(src: int, dst: int, ekind: int, payload_sid: int) -> int {
    return js_edge_add(src, dst, ekind, payload_sid);
}

def:pub njs_adj_clear(h: int, ekind: int, direction: int) -> int {
    return js_adj_clear(h, ekind, direction);
}

def:pub njs_subtree_copy(h: int, dst_arena: int) -> int {
    return js_subtree_copy(h, dst_arena);
}

def:pub njs_copy_slots(src: int, dst: int) -> int {
    return js_copy_slots(src, dst);
}

def _raise(msg: str) -> int {
    exc = PyDict_GetItemString(PyEval_GetBuiltins(), "RuntimeError");
    PyErr_SetString(exc, msg);
    return 0;
}

def _obj_to_bytes(o: int) -> bytes | None {
    out8 = b"\x00" * 8;
    ptr = PyUnicode_AsUTF8AndSize(o, out8);
    if ptr == 0 {
        return None;
    }
    n = int.from_bytes(out8, "little");
    buf = b"\x00" * n;
    if n > 0 {
        memcpy(buf, ptr, u64(n));
    }
    return buf;
}

def:pub pyapi_intern(slf: int, args: int) -> int {
    arena = PyLong_AsLongLong(PyTuple_GetItem(args, 0));
    buf = _obj_to_bytes(PyTuple_GetItem(args, 1));
    if buf is None {
        return 0;
    }
    sid = js_intern_bytes(arena, buf);
    if sid < 0 {
        return _raise("jacstore: intern into dead arena");
    }
    return PyLong_FromLongLong(sid);
}

def:pub pyapi_intern_get(slf: int, args: int) -> int {
    arena = PyLong_AsLongLong(PyTuple_GetItem(args, 0));
    sid = PyLong_AsLongLong(PyTuple_GetItem(args, 1));
    buf = js_intern_get_bytes(arena, sid);
    return PyUnicode_FromStringAndSize(buf, len(buf));
}

def _box_list(vals: list[int]) -> int {
    n = len(vals);
    pl = PyList_New(n);
    if pl == 0 {
        return 0;
    }
    i = 0;
    while i < n {
        PyList_SetItem(pl, i, PyLong_FromLongLong(vals[i]));
        i += 1;
    }
    return pl;
}

def:pub pyapi_adj(slf: int, args: int) -> int {
    h = PyLong_AsLongLong(PyTuple_GetItem(args, 0));
    ekind = PyLong_AsLongLong(PyTuple_GetItem(args, 1));
    direction = PyLong_AsLongLong(PyTuple_GetItem(args, 2));
    return _box_list(js_adj(h, ekind, direction));
}

def:pub pyapi_adj_payloads(slf: int, args: int) -> int {
    h = PyLong_AsLongLong(PyTuple_GetItem(args, 0));
    ekind = PyLong_AsLongLong(PyTuple_GetItem(args, 1));
    return _box_list(js_adj_payloads(h, ekind));
}
