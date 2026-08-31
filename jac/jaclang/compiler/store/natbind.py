"""ctypes bindings over the native front-end library (issue #8789 Phase 4).

The native unit (lexer + parser + unitree + generated query/field wrappers +
the np_* entry) exports only ``def:pub`` free functions; this module is the
Python side of that surface. Conventions established by the boundary recon:

- ints/bools/enums cross as c_int64; node pointers as c_void_p (nodes are
  RC-immortal, so held pointers never dangle and retain/release are no-ops);
- a str return arrives in registers as the {root, data} pair (the third
  register, len, is unreachable through libffi; payloads are NUL-terminated
  at len, so ``string_at(data)`` recovers the value) and carries +1 the
  caller owns -- release ``root``;
- a str argument is built with jac_str_new and passed as the (p, p, len)
  triple, released by the caller afterward;
- adjacency queries return an owned native list handle, iterated through the
  exported ql_len/ql_get pair and then released;
- a node's class is its OSP type tag (i64 at ptr+8), the same
  ``stable_osp_tag(class name)`` Python can compute.

Native-backed view handles are the struct pointer with bit 62 set, keeping
them disjoint from record-store handles in the shared ``_ts`` slot.
"""

from __future__ import annotations

import ctypes

from jaclang.compiler.store.natbind_table import TABLE

NP_TAG = 1 << 62

_i64 = ctypes.c_int64
_vp = ctypes.c_void_p


def _stable_tag(name: str) -> int:
    h = 14695981039346656037
    for b in name.encode():
        h = ((h ^ b) * 1099511628211) & 0xFFFFFFFFFFFFFFFF
    return h & 9007199254740991


class _StrRet(ctypes.Structure):
    _fields_ = [("root", ctypes.c_void_p), ("data", ctypes.c_void_p)]


class _OptRet(ctypes.Structure):
    """A (T | None) return: JacOpt {flag, payload} in the RAX:RDX pair.

    The flag eightbyte carries uninitialized high bits -- only its low byte
    answers present/absent.
    """

    _fields_ = [("flag", ctypes.c_uint64), ("payload", ctypes.c_void_p)]


class FrontendLib:
    def __init__(self, path: str) -> None:
        self.lib = ctypes.PyDLL(path)
        self._fns: dict = {}
        self._field_maps: dict = {}
        self._tag2cls: dict = {}
        try:
            rel = self.lib.jac_release
            rel.argtypes = [_vp]
            rel.restype = None
            self._release = rel
        except AttributeError:
            # The unit's IR named its release machinery differently, so the
            # jac_release wrapper was not injected (tracked upstream). Nodes
            # are immortal; only per-read strings and query lists leak.
            self._release = lambda p: None
        self.lib.jac_str_new.argtypes = [_vp, _i64]
        self.lib.jac_str_new.restype = _vp

    # -- low-level conventions -------------------------------------------
    def _fn(self, name: str, argspec: str, ret: str):
        hit = self._fns.get(name)
        if hit is not None:
            return hit
        fn = getattr(self.lib, name)
        argtypes: list = []
        for a in argspec:
            if a == "p":
                argtypes.append(_vp)
            elif a == "i":
                argtypes.append(_i64)
            elif a == "s":
                argtypes.extend([_vp, _vp, _i64])
        fn.argtypes = argtypes
        fn.restype = {"i": _i64, "p": _vp, "s": _StrRet, "n": None}[ret]
        self._fns[name] = fn
        return fn

    def _mk_str(self, s: str):
        b = s.encode()
        p = self.lib.jac_str_new(b, len(b))
        return p, (p, p, len(b))

    def _take_str(self, r: _StrRet) -> str:
        out = ctypes.string_at(r.data).decode() if r.data else ""
        if r.root:
            self._release(r.root)
        return out

    def call_str_args(self, name: str, argspec: str, ret: str, *args):
        """Call with mixed args; 's'-typed args given as python str."""
        fn = self._fn(name, argspec, ret)
        flat: list = []
        owned: list = []
        for spec, val in zip(argspec, args):
            if spec == "s":
                p, triple = self._mk_str(val)
                owned.append(p)
                flat.extend(triple)
            else:
                flat.append(val)
        try:
            out = fn(*flat)
        finally:
            for p in owned:
                self._release(p)
        if ret == "s":
            return self._take_str(out)
        return out

    # -- node identity ----------------------------------------------------
    def tag_of(self, ptr: int) -> int:
        return ctypes.cast(ptr + 8, ctypes.POINTER(_i64)).contents.value

    def cls_of_ptr(self, ptr: int):
        tag = self.tag_of(ptr)
        cls = self._tag2cls.get(tag)
        if cls is None:
            from jaclang.compiler.store.schema import CLS_OF_KIND

            for c in CLS_OF_KIND.values():
                self._tag2cls[_stable_tag(c.__name__)] = c
            cls = self._tag2cls.get(tag)
        return cls

    # -- field access ------------------------------------------------------
    def _field_spec(self, cls: type, field: str):
        per = self._field_maps.get(cls)
        if per is None:
            per = {}
            for base in cls.__mro__:
                spec = TABLE.get(base.__name__)
                if not spec:
                    continue
                for fname, info in spec.items():
                    if fname not in per:
                        per[fname] = (base.__name__, info)
            self._field_maps[cls] = per
        return per.get(field)

    def read_field(self, cls: type, field: str, ptr: int):
        spec = self._field_spec(cls, field)
        if spec is None:
            raise AttributeError(f"{cls.__name__}.{field}: no native binding")
        owner, (kind, nullable, ename) = spec
        g = f"nf_g_{owner}_{field}"
        if kind == "str":
            if nullable:
                has = self.call_str_args(f"nf_h_{owner}_{field}", "p", "i", ptr)
                if not has:
                    return None
            return self.call_str_args(g, "p", "s", ptr)
        if kind == "ref":
            has = self.call_str_args(f"nf_h_{owner}_{field}", "p", "i", ptr)
            if not has:
                return None
            peer = self.call_str_args(g, "p", "p", ptr)
            return self.materialize(peer)
        v = self.call_str_args(g, "p", "i", ptr)
        if kind == "bool":
            return v != 0
        if kind == "enum":
            import jaclang.compiler.frontend.constant as constant

            return getattr(constant, ename)(v)
        return v

    def write_field(self, cls: type, field: str, ptr: int, value) -> None:
        spec = self._field_spec(cls, field)
        if spec is None:
            raise AttributeError(f"{cls.__name__}.{field}: no native binding")
        owner, (kind, nullable, ename) = spec
        s = f"nf_s_{owner}_{field}"
        if kind == "str":
            self.call_str_args(s, "ps", "i", ptr, value if value is not None else "")
            return
        if kind == "ref":
            raise RuntimeError(
                f"jacstore: ref field {cls.__name__}.{field} is read-only on "
                "native trees"
            )
        if kind == "bool":
            v = 1 if value else 0
        elif kind == "enum":
            v = int(getattr(value, "value", value))
        else:
            v = int(value)
        self.call_str_args(s, "pi", "i", ptr, v)

    def role_shape(self, ptr: int, role_name: str) -> int:
        """Read a native node's _role_shapes entry: 0 none, 1 one, 2 many."""
        return self.call_str_args("np_role_shape", "ps", "i", ptr, role_name)

    def sym_category(self, ptr: int) -> str:
        """Read a native NameAtom's _sym_category value ('' when unbound)."""
        return self.call_str_args("np_sym_category", "p", "s", ptr)

    def subtag_tag(self, ptr: int):
        """Read a native SubTag's tag node (generic field, so untabled)."""
        fn = self._fns.get("np_subtag_tag")
        if fn is None:
            fn = self.lib.np_subtag_tag
            fn.argtypes = [_vp]
            fn.restype = _OptRet
            self._fns["np_subtag_tag"] = fn
        r = fn(ptr)
        if (r.flag & 0xFF) and r.payload:
            return self.materialize(r.payload)
        return None

    # -- adjacency ---------------------------------------------------------
    def adj(self, role_name: str, ptr: int, direction: int) -> list[int]:
        sym = ("qo_" if direction == 0 else "qi_") + role_name
        handle = self.call_str_args(sym, "p", "p", ptr)
        if not handle:
            return []
        try:
            n = self.call_str_args("ql_len", "p", "i", handle)
            return [
                self.call_str_args("ql_get", "pi", "p", handle, i)
                for i in range(n)
            ]
        finally:
            self._release(handle)

    # -- views -------------------------------------------------------------
    def materialize(self, ptr: int):
        import jaclang.compiler.store.host as host
        import jaclang.compiler.store.schema as schema

        h = ptr | NP_TAG
        hit = host.view_of(h)
        if hit is not None:
            return hit
        cls = self.cls_of_ptr(ptr)
        if cls is None:
            raise RuntimeError(f"jacstore: unknown native node tag at {ptr:#x}")
        obj = object.__new__(cls)
        d = obj.__dict__
        d["_ts"] = h
        d["_kd"] = -1
        host.set_view(h, obj)
        return obj

    # -- parse entry -------------------------------------------------------
    def parse(self, source: str, path: str) -> int:
        return self.call_str_args("np_parse", "ss", "p", source, path)

    def weave(self, root_ptr: int, a_src: str, a_path: str) -> int:
        return self.call_str_args("np_weave", "pss", "i", root_ptr, a_src, a_path)

    def entry_int(self, name: str, *args) -> int:
        return self.call_str_args(name, "i" * len(args), "i", *args)

    def entry_str(self, name: str, *args) -> str:
        return self.call_str_args(name, "i" * len(args), "s", *args)
