import ctypes;
import os;
import threading;
import from pathlib { Path }

glob ABI_VERSION: int = 3;

obj StoreHost {
    has status: int = 0,
        backend: int = 0,
        lib: any = None,
        twin: any = None,
        tls: any = None,
        loose: int = -1,
        views: dict[int, dict[int, any]] = {},
        strs: dict[int, dict[int, str]] = {},
        f_intern: any = None,
        f_intern_get: any = None,
        f_adj: any = None,
        f_adj_payloads: any = None,
        n_copy_slots: any = None,
        n_kind_register: any = None,
        n_ekind_register: any = None,
        n_arena_new: any = None,
        n_arena_freeze: any = None,
        n_arena_frozen: any = None,
        n_arena_drop: any = None,
        n_node_new: any = None,
        n_node_kind: any = None,
        n_slot_get: any = None,
        n_slot_set: any = None,
        n_edge_add: any = None,
        n_adj_clear: any = None,
        n_subtree_copy: any = None;
}

glob _H: StoreHost = StoreHost();

def _find_lib -> any {
    override = os.environ.get("JAC_STORE_LIB");
    if override {
        if override.lower() in ("none", "off", "disabled") {
            return None;
        }
        return Path(override);
    }
    import from jaclang.jac0core.sealed { _jaclang_image }
    image = _jaclang_image();
    if image is None {
        return None;
    }
    native = (image.manifest or {}).get("native") or {};
    store = native.get("store") or {};
    lib_rel = store.get("lib");
    if not lib_rel {
        return None;
    }
    cand = image.jir_dir / lib_rel;
    return cand if cand.exists() else None;
}

def _bind_native(lib_path: any) -> bool {
    try {
        lib = ctypes.PyDLL(str(lib_path));
        lib.njs_abi_version.restype = ctypes.c_int64;
        if lib.njs_abi_version() != ABI_VERSION {
            return False;
        }
    } except OSError {
        return False;
    }
    i64 = ctypes.c_int64;
    sigs = [
        ("n_kind_register", "njs_kind_register", 5),
        ("n_ekind_register", "njs_ekind_register", 2),
        ("n_arena_new", "njs_arena_new", 0),
        ("n_arena_freeze", "njs_arena_freeze", 1),
        ("n_arena_frozen", "njs_arena_frozen", 1),
        ("n_arena_drop", "njs_arena_drop", 1),
        ("n_node_new", "njs_node_new", 2),
        ("n_node_kind", "njs_node_kind", 1),
        ("n_slot_get", "njs_slot_get", 2),
        ("n_slot_set", "njs_slot_set", 3),
        ("n_edge_add", "njs_edge_add", 4),
        ("n_adj_clear", "njs_adj_clear", 3),
        ("n_subtree_copy", "njs_subtree_copy", 2),
        ("n_copy_slots", "njs_copy_slots", 2),
    ];
    for (attr, sym, argc) in sigs {
        fn = getattr(lib, sym);
        fn.argtypes = [i64] * argc;
        fn.restype = i64;
        setattr(_H, attr, fn);
    }
    pyo = ctypes.py_object;
    pyfn = ctypes.PYFUNCTYPE(pyo, pyo, pyo);
    _H.f_intern = pyfn(("pyapi_intern", lib));
    _H.f_intern_get = pyfn(("pyapi_intern_get", lib));
    _H.f_adj = pyfn(("pyapi_adj", lib));
    _H.f_adj_payloads = pyfn(("pyapi_adj_payloads", lib));
    _H.lib = lib;
    _H.backend = 1;
    return True;
}

def _bind_twin -> None {
    import jaclang.compiler.store.unitree_store as tw;
    _H.twin = tw;
    _H.n_kind_register = tw.js_kind_register;
    _H.n_ekind_register = tw.js_ekind_register;
    _H.n_arena_new = tw.js_arena_new;
    _H.n_arena_freeze = tw.js_arena_freeze;
    _H.n_arena_frozen = tw.js_arena_frozen;
    _H.n_arena_drop = tw.js_arena_drop;
    _H.n_node_new = tw.js_node_new;
    _H.n_node_kind = tw.js_node_kind;
    _H.n_slot_get = tw.js_slot_get;
    _H.n_slot_set = tw.js_slot_set;
    _H.n_edge_add = tw.js_edge_add;
    _H.n_adj_clear = tw.js_adj_clear;
    _H.n_subtree_copy = tw.js_subtree_copy;
    _H.n_copy_slots = tw.js_copy_slots;
    _H.backend = 2;
}

def ensure_loaded -> None {
    if _H.status != 0 {
        return;
    }
    _H.status = 1;
    if not os.environ.get("JAC_NO_NATIVE_STORE") {
        lib_path = _find_lib();
        if lib_path is not None and _bind_native(lib_path) {
            return;
        }
    }
    _bind_twin();
}

def backend_name -> str {
    ensure_loaded();
    return "native" if _H.backend == 1 else "bytecode";
}

def register_kind(
    kind: int, nslots: int, frozen_mask: int, str_mask: int, ref_mask: int
) -> None {
    _H.n_kind_register(kind, nslots, frozen_mask, str_mask, ref_mask);
}

def register_ekind(ekind: int, is_struct: int) -> None {
    _H.n_ekind_register(ekind, is_struct);
}

def _stack -> list {
    if _H.tls is None {
        _H.tls = threading.local();
    }
    s = getattr(_H.tls, "stack", None);
    if s is None {
        s = [];
        _H.tls.stack = s;
    }
    return s;
}

def current_arena -> int {
    ensure_loaded();
    s = _stack();
    if s {
        return s[-1][0];
    }
    if _H.loose < 0 {
        _H.loose = _H.n_arena_new();
    }
    return _H.loose;
}

def arena_begin(freeze_at_end: bool = True) -> int {
    ensure_loaded();
    a = _H.n_arena_new();
    _stack().append((a, freeze_at_end));
    return a;
}

def arena_end -> None {
    s = _stack();
    if not s {
        return;
    }
    (a, do_freeze) = s.pop();
    if do_freeze {
        _H.n_arena_freeze(a);
    }
}

def arena_freeze(a: int) -> None {
    ensure_loaded();
    _H.n_arena_freeze(a);
}

def arena_drop(a: int) -> None {
    ensure_loaded();
    if a < 0 or a == _H.loose {
        return;
    }
    _H.n_arena_drop(a);
    if a in _H.views {
        del _H.views[a];
    }
    if a in _H.strs {
        del _H.strs[a];
    }
}

def node_new(kind: int) -> int {
    return node_new_in(current_arena(), kind);
}

def node_new_in(a: int, kind: int) -> int {
    h = _H.n_node_new(a, kind);
    if h < 0 {
        raise RuntimeError("jacstore: node_new failed (frozen or dead arena)");
    }
    return h;
}

def node_kind(h: int) -> int {
    return _H.n_node_kind(h);
}

def slot_get(h: int, i: int) -> int {
    return _H.n_slot_get(h, i);
}

def slot_set(h: int, i: int, v: int) -> None {
    rc = _H.n_slot_set(h, i, v);
    if rc == 1 {
        raise RuntimeError("jacstore: write to frozen slot");
    }
    if rc == 2 {
        raise RuntimeError("jacstore: dead node handle");
    }
}

def intern(a: int, s: str) -> int {
    if _H.backend == 1 {
        return _H.f_intern(None, (a, s));
    }
    return _H.twin.js_intern_bytes(a, s.encode());
}

def sid_str(a: int, sid: int) -> str {
    cache = _H.strs.get(a);
    if cache is None {
        cache = {};
        _H.strs[a] = cache;
    }
    hit = cache.get(sid);
    if hit is not None {
        return hit;
    }
    if _H.backend == 1 {
        s = _H.f_intern_get(None, (a, sid));
    } else {
        s = _H.twin.js_intern_get_bytes(a, sid).decode();
    }
    cache[sid] = s;
    return s;
}

def slot_get_str(h: int, i: int) -> str {
    return sid_str(h >> 40, _H.n_slot_get(h, i));
}

def slot_set_str(h: int, i: int, s: str) -> None {
    slot_set(h, i, intern(h >> 40, s));
}

def edge_add(src: int, dst: int, ekind: int, payload_sid: int = -1) -> None {
    rc = _H.n_edge_add(src, dst, ekind, payload_sid);
    if rc == 1 {
        raise RuntimeError("jacstore: structure edge into frozen arena");
    }
    if rc == 2 {
        raise RuntimeError("jacstore: dead node handle");
    }
}

def adj(h: int, ekind: int, direction: int) -> list[int] {
    if _H.backend == 1 {
        return _H.f_adj(None, (h, ekind, direction));
    }
    return _H.twin.js_adj(h, ekind, direction);
}

def adj_payloads(h: int, ekind: int) -> list[int] {
    if _H.backend == 1 {
        return _H.f_adj_payloads(None, (h, ekind));
    }
    return _H.twin.js_adj_payloads(h, ekind);
}

def adj_clear(h: int, ekind: int, direction: int = 0) -> None {
    rc = _H.n_adj_clear(h, ekind, direction);
    if rc == 1 {
        raise RuntimeError("jacstore: structure clear on frozen arena");
    }
    if rc == 2 {
        raise RuntimeError("jacstore: dead node handle");
    }
}

def subtree_copy(h: int, dst_arena: int = -1) -> int {
    dst = dst_arena if dst_arena >= 0 else current_arena();
    nh = _H.n_subtree_copy(h, dst);
    if nh < 0 {
        raise RuntimeError("jacstore: subtree_copy failed");
    }
    return nh;
}

def copy_slots(src: int, dst: int) -> None {
    rc = _H.n_copy_slots(src, dst);
    if rc != 0 {
        raise RuntimeError("jacstore: copy_slots failed");
    }
}

def set_view(h: int, inst: any) -> None {
    a = h >> 40;
    per = _H.views.get(a);
    if per is None {
        per = {};
        _H.views[a] = per;
    }
    per[h] = inst;
}

def view_of(h: int) -> any {
    per = _H.views.get(h >> 40);
    if per is None {
        return None;
    }
    return per.get(h);
}
