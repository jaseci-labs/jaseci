"""The PyObject-unitree installer (#8789).

Loads the natively compiled front end (``JAC_FRONTEND_LIB``), reads the
layout sidecar the compiler emitted next to it, and builds one CPython type
per unitree class over the native struct layout:

- scalar fields become ``tp_members`` rows reading the struct slots in
  place -- interpreter-speed access, no FFI per read;
- jac-string and enum fields become properties over the raw slots;
- role-backed fields become properties that make one native adjacency call
  per read (``npy_adj``) and get back a list of nodes that already ARE
  Python objects;
- every method and property of the bytecode twin classes is flattened onto
  the native types, whose base chain mirrors the jac hierarchy so
  ``isinstance`` works throughout;
- ``__new__`` allocates through ``npy_alloc``, so nodes that passes create
  land in the same native arena as parser output;
- the source modules' class names are rebound to the native types at module
  exec time (meta-importer hook), before any importer binds them.

One-time ctypes is used to construct the types; steady-state field access
never crosses ctypes.
"""

from __future__ import annotations

import ctypes
import json
import os
from ctypes import (
    CFUNCTYPE,
    POINTER,
    Structure,
    c_char_p,
    c_int,
    c_ssize_t,
    c_uint,
    c_ulonglong,
    c_void_p,
    cast,
    py_object,
    string_at,
)

# -- CPython construction surface (typeslots.h / structmember.h) ------------
Py_tp_base = 48
Py_tp_bases = 49
Py_tp_members = 72
Py_tp_getset = 73
Py_TPFLAGS_BASETYPE = 1 << 10

T_LONGLONG = 17
T_BOOL = 14
T_DOUBLE = 4
T_OBJECT = 6  # NULL reads as None -- every jac ref field is nullable-at-rest
T_PYSSIZET = 19
READONLY = 1

HDR_REFCNT_OFF = 0
HDR_TYPE_OFF = 8
HDR_DICT_OFF = 16


class PyType_Slot(Structure):
    _fields_ = [("slot", c_int), ("pfunc", c_void_p)]


class PyType_Spec(Structure):
    _fields_ = [
        ("name", c_char_p),
        ("basicsize", c_int),
        ("itemsize", c_int),
        ("flags", c_uint),
        ("slots", POINTER(PyType_Slot)),
    ]


class PyMemberDef(Structure):
    _fields_ = [
        ("name", c_char_p),
        ("type", c_int),
        ("offset", c_ssize_t),
        ("flags", c_int),
        ("doc", c_char_p),
    ]


def _stable_tag(name: str) -> int:
    h = 14695981039346656037
    for b in name.encode():
        h = ((h ^ b) * 1099511628211) & 0xFFFFFFFFFFFFFFFF
    return h & 9007199254740991


def _addr(obj) -> int:
    return id(obj)


def _generic_get_dict(self):
    api = ctypes.pythonapi
    api.PyObject_GenericGetDict.restype = py_object
    api.PyObject_GenericGetDict.argtypes = [py_object, c_void_p]
    return api.PyObject_GenericGetDict(self, None)


class NpyBase:
    """Root base for native types: contributes no storage, only the
    __dict__ descriptor FromSpec types otherwise lack (cached_property
    and vars() want it), backed by CPython's own generic dict access."""

    __slots__ = ()
    __dict__ = property(_generic_get_dict)


class NativeList:
    """A mutable view over a jac native list of node pointers. Elements are
    PyObject-headed nodes, so reads come back as the objects themselves."""

    __slots__ = ("_lib", "_ptr")

    def __init__(self, lib, ptr) -> None:
        self._lib = lib
        self._ptr = ptr or 0

    def __len__(self) -> int:
        if not self._ptr:
            return 0
        return self._lib.npy_list_len(self._ptr)

    def __getitem__(self, i):
        n = len(self)
        if isinstance(i, slice):
            return [self[j] for j in range(*i.indices(n))]
        if i < 0:
            i += n
        if not 0 <= i < n:
            raise IndexError(i)
        return cast(self._lib.npy_list_get(self._ptr, i), py_object).value

    def __iter__(self):
        for i in range(len(self)):
            yield self[i]

    def __bool__(self) -> bool:
        return len(self) > 0

    def append(self, v) -> None:
        if not self._ptr:
            raise ValueError("append to an unset native list field")
        self._lib.npy_list_append(self._ptr, _addr(v))


class NpyBridge:
    """One loaded frontend lib + its constructed type universe."""

    def __init__(self, lib_path: str) -> None:
        self.lib = ctypes.PyDLL(lib_path)
        layout_path = lib_path + ".layout.json"
        with open(layout_path) as f:
            self.layout = json.load(f)["classes"]
        self._keep: list = []  # ctypes structures that must outlive the types
        self.types: dict[str, type] = {}
        self.kind_of_type: dict[type, int] = {}
        self._twins: dict[str, type] = {}
        self._bind()
        self._role_map = None
        self._shape_cache: dict[str, int] = {}

    # -- lib call surface --------------------------------------------------
    def _bind(self) -> None:
        L = self.lib
        L.npy_register_kind.argtypes = [
            ctypes.c_int64, c_void_p, ctypes.c_int64, ctypes.c_int64,
            ctypes.c_int64,
        ]
        L.npy_register_kind.restype = ctypes.c_int64
        L.npy_alloc.argtypes = [ctypes.c_int64]
        L.npy_alloc.restype = c_void_p
        L.npy_adj.argtypes = [ctypes.c_int64] * 3
        L.npy_adj.restype = py_object
        L.npy_conn.argtypes = [ctypes.c_int64] * 3
        L.npy_conn.restype = ctypes.c_int64
        L.npy_disconn.argtypes = [ctypes.c_int64] * 4
        L.npy_disconn.restype = ctypes.c_int64
        L.npy_role_clear.argtypes = [ctypes.c_int64] * 3
        L.npy_role_clear.restype = ctypes.c_int64
        L.np_err_count.argtypes = []
        L.np_err_count.restype = ctypes.c_int64
        L.np_lex_errs.argtypes = []
        L.np_lex_errs.restype = ctypes.c_int64
        for name in ("np_diags", "np_lexdiags", "np_comments"):
            fn = getattr(L, name)
            fn.argtypes = []
            fn.restype = py_object
        L.np_parse.restype = py_object
        L.jac_str_new.argtypes = [c_char_p, ctypes.c_int64]
        L.jac_str_new.restype = c_void_p
        L.npy_list_len.argtypes = [ctypes.c_int64]
        L.npy_list_len.restype = ctypes.c_int64
        L.npy_list_get.argtypes = [ctypes.c_int64] * 2
        L.npy_list_get.restype = c_void_p
        L.npy_list_append.argtypes = [ctypes.c_int64] * 2
        L.npy_list_append.restype = ctypes.c_int64
        L.npy_list_new.argtypes = []
        L.npy_list_new.restype = c_void_p

    def _call_str2(self, name: str, a: str, b: str):
        """Call an export taking two jac-str args (each a {p, p, len} triple)."""
        fn = getattr(self.lib, name)
        ab, bb = a.encode(), b.encode()
        pa = self.lib.jac_str_new(ab, len(ab))
        pb = self.lib.jac_str_new(bb, len(bb))
        return fn(
            c_void_p(pa), c_void_p(pa), ctypes.c_int64(len(ab)),
            c_void_p(pb), c_void_p(pb), ctypes.c_int64(len(bb)),
        )

    def parse(self, source: str, path: str):
        return self._call_str2("np_parse", source, path)

    def weave(self, main_mod, a_src: str, a_path: str) -> int:
        fn = self.lib.np_weave
        fn.restype = ctypes.c_int64
        ab, bb = a_src.encode(), a_path.encode()
        pa = self.lib.jac_str_new(ab, len(ab))
        pb = self.lib.jac_str_new(bb, len(bb))
        return fn(
            c_void_p(_addr(main_mod)),
            c_void_p(pa), c_void_p(pa), ctypes.c_int64(len(ab)),
            c_void_p(pb), c_void_p(pb), ctypes.c_int64(len(bb)),
        )

    def role_shape(self, nd, role_name: str) -> int:
        fn = self.lib.np_role_shape
        fn.restype = ctypes.c_int64
        rb = role_name.encode()
        pr = self.lib.jac_str_new(rb, len(rb))
        return fn(
            c_void_p(_addr(nd)),
            c_void_p(pr), c_void_p(pr), ctypes.c_int64(len(rb)),
        )

    # -- type construction -------------------------------------------------
    def adopt_module(self, module) -> None:
        """Rebind this source module's unitree classes to native types.

        Called from the meta-importer as each scope module finishes
        executing, before anything imports names out of it.
        """
        mod_name = getattr(module, "__name__", "")
        for name in list(vars(module)):
            twin = getattr(module, name)
            if (
                isinstance(twin, type)
                and name in self.layout
                and getattr(twin, "__module__", "") == mod_name
            ):
                # Only classes this module DECLARES: re-exported imports
                # (e.g. the runtime's TreeWalker) must keep their identity.
                self._twins.setdefault(name, twin)
        for name in list(vars(module)):
            twin = getattr(module, name)
            if (
                name in self.layout
                and isinstance(twin, type)
                and self._twins.get(name) is twin
            ):
                setattr(module, name, self._type_for(name))

    def _type_for(self, name: str):
        t = self.types.get(name)
        if t is not None:
            return t
        twin = self._twins[name]
        bases: list[type] = []
        for anc in twin.__bases__:
            if (
                anc.__name__ in self.layout
                and anc.__name__ != name
                and self._twins.get(anc.__name__) is anc
            ):
                # Identity check: a runtime class sharing a name with a laid-
                # out unitree class (e.g. Archetype) must not become a base.
                bases.append(self._type_for(anc.__name__))
        if not bases:
            for anc in twin.__mro__[1:]:
                if (
                    anc.__name__ in self.layout
                    and anc.__name__ != name
                    and self._twins.get(anc.__name__) is anc
                ):
                    bases.append(self._type_for(anc.__name__))
                    break
        t = self._build_type(name, twin, bases)
        self.types[name] = t
        info = self.layout[name]
        self.kind_of_type[t] = _stable_tag(name)
        self.lib.npy_register_kind(
            _stable_tag(name),
            c_void_p(_addr(t)),
            info["size"],
            info["tag"] or 0,
            info["tag_offset"],
        )
        return t

    def _build_type(self, name: str, twin: type, bases_in):
        info = self.layout[name]
        fields = info["fields"]

        members = []
        for fname, f in fields.items():
            code, off = f["code"], f["offset"]
            if code == "int":
                members.append((fname.encode(), T_LONGLONG, off, 0))
            elif code == "bool":
                members.append((fname.encode(), T_BOOL, off, 0))
            elif code == "float":
                members.append((fname.encode(), T_DOUBLE, off, 0))
            elif code == "obj":
                members.append((fname.encode(), T_OBJECT, off, 0))
            elif code == "enum":
                members.append((b"__npy_raw_" + fname.encode(), T_LONGLONG, off, 0))
        members.append((b"__dictoffset__", T_PYSSIZET, HDR_DICT_OFF, READONLY))

        marr = (PyMemberDef * (len(members) + 1))()
        for i, (nm, ty, off, fl) in enumerate(members):
            marr[i] = PyMemberDef(nm, ty, off, fl, None)
        self._keep.append(marr)

        slots = (PyType_Slot * 3)()
        slots[0] = PyType_Slot(Py_tp_members, cast(marr, c_void_p))
        slots[1] = PyType_Slot(0, None)
        self._keep.append(slots)

        tname = ("jaclang.native." + name).encode()
        self._keep.append(tname)
        # Only chain roots declare CPython storage; every derived type
        # inherits, so all native types share their root as solid base and
        # multiple inheritance can never conflict. True instance sizes are
        # the native allocator's business, and the member tables address
        # fields by explicit offset regardless of tp_basicsize.
        basicsize = 0 if bases_in else info["size"]
        spec = PyType_Spec(
            tname, basicsize, 0, Py_TPFLAGS_BASETYPE, slots
        )
        self._keep.append(spec)

        pythonapi = ctypes.pythonapi
        pythonapi.PyType_FromSpecWithBases.restype = py_object
        pythonapi.PyType_FromSpecWithBases.argtypes = [
            POINTER(PyType_Spec), py_object,
        ]
        bases = tuple(bases_in) if bases_in else (NpyBase,)
        t = pythonapi.PyType_FromSpecWithBases(ctypes.byref(spec), bases)

        t.__npy_native__ = True
        t.__npy_twin__ = twin
        self._flatten_twin(t, twin, fields)
        self._install_field_props(t, name, fields)
        self._install_natlist_props(t, fields)
        self._install_overlay_props(t, name, fields)
        for _f in fields:
            self._alias_mangled(t, _f)
        self._install_role_props(t, name, fields)
        self._install_parent(t)
        self._install_anchorless_overrides(t, name)
        self._install_new(t, name)
        return t

    def _rebind_class_cell(self, fn, owner_native: type):
        """A zero-arg super() in twin bytecode resolves through the
        function's __class__ cell, which points at the twin. Native
        instances are not twin subclasses, so the cell is rebound to the
        native counterpart of the defining class -- the native MRO mirrors
        the twin MRO, so super() chains identically."""
        import types

        code = getattr(fn, "__code__", None)
        if code is None or "__class__" not in code.co_freevars:
            return fn
        idx = code.co_freevars.index("__class__")
        closure = list(fn.__closure__)
        closure[idx] = types.CellType(owner_native)
        out = types.FunctionType(
            code, fn.__globals__, fn.__name__, fn.__defaults__, tuple(closure)
        )
        out.__kwdefaults__ = fn.__kwdefaults__
        out.__dict__.update(fn.__dict__)
        return out

    def _flatten_member(self, v, owner_native: type):
        import types

        if isinstance(v, types.FunctionType):
            return self._rebind_class_cell(v, owner_native)
        if isinstance(v, (classmethod, staticmethod)):
            return type(v)(self._rebind_class_cell(v.__func__, owner_native))
        if isinstance(v, property):
            return property(
                v.fget and self._rebind_class_cell(v.fget, owner_native),
                v.fset and self._rebind_class_cell(v.fset, owner_native),
                v.fdel and self._rebind_class_cell(v.fdel, owner_native),
            )
        return v

    def _flatten_twin(self, t: type, twin: type, fields: dict) -> None:
        """Every method/property the twins define, flattened base-first so
        overrides land last. Python functions bind to any instance, so the
        twins' bytecode runs unchanged over native storage; __class__ cells
        are rebound so super() works."""
        skip = {
            "__dict__", "__weakref__", "__module__", "__qualname__",
            "__slots__", "__dictoffset__", "__basicsize__", "__new__",
            # Class-creation hooks must not be flattened: every jac-generated
            # subclass lists the runtime archetype base (Walker/Node/...)
            # explicitly, so Archetype.__init_subclass__ is already in its MRO;
            # a flattened copy on the native type would run it a second time,
            # and the second dataclass pass strips factory defaults.
            "__init_subclass__", "__set_name__",
        }
        # Classes the native type already inherits from must not be
        # flattened either — their methods arrive through the MRO.
        inherited = set(t.__mro__)
        for cls in reversed(twin.__mro__):
            if cls is object or cls in inherited:
                continue
            owner_native = t
            if (
                cls is not twin
                and cls.__name__ in self.layout
                and self._twins.get(cls.__name__) is cls
            ):
                owner_native = self._type_for(cls.__name__)
            for k, v in vars(cls).items():
                if k in skip:
                    continue
                if k in fields and not callable(v) and not isinstance(
                    v, (property, classmethod, staticmethod)
                ):
                    # A dataclass field default is a plain class attribute;
                    # copying it would shadow the native member descriptor.
                    continue
                try:
                    setattr(t, k, self._flatten_member(v, owner_native))
                except (TypeError, AttributeError):
                    pass

    def _alias_mangled(self, t: type, fname: str) -> None:
        """Twin bytecode reaches a __-prefixed field through its compile-time
        mangled name (_DeclaringClass__field); alias the accessor under every
        MRO class's mangling so whichever twin method reads it resolves."""
        if not (fname.startswith("__") and not fname.endswith("__")):
            return
        descr = t.__dict__.get(fname)
        if descr is None:
            return
        for cls in t.__npy_twin__.__mro__:
            if cls is object:
                continue
            try:
                setattr(t, f"_{cls.__name__}{fname}", descr)
            except (TypeError, AttributeError):
                pass

    def _install_field_props(self, t: type, name: str, fields: dict) -> None:
        import dataclasses
        import re as _re

        lib = self.lib
        try:
            _dcf = {f.name: str(f.type) for f in dataclasses.fields(t.__npy_twin__)}
        except TypeError:
            _dcf = {}
        for fname, f in fields.items():
            code, off = f["code"], f["offset"]
            if code == "opaque":
                # An optional enum lowers to a {flag, ordinal} pair the
                # layout can't name; the twin's annotation can.
                _ann = _dcf.get(fname, "")
                _m = _re.fullmatch(r"\(?\s*(\w+)\s*\|\s*None\s*\)?", _ann)
                if _m:
                    import jaclang.compiler.frontend.constant as _const

                    _ecls = getattr(_const, _m.group(1), None)
                    if isinstance(_ecls, type):

                        def oeget(self, _off=off, _ec=_ecls):
                            a = _addr(self) + _off
                            if not cast(a, POINTER(ctypes.c_uint8))[0]:
                                return None
                            raw = cast(a + 8, POINTER(ctypes.c_int64))[0]
                            return list(_ec)[raw]

                        def oeset(self, value, _off=off, _ec=_ecls):
                            a = _addr(self) + _off
                            if value is None:
                                cast(a, POINTER(ctypes.c_uint8))[0] = 0
                                return
                            cast(a, POINTER(ctypes.c_uint8))[0] = 1
                            cast(a + 8, POINTER(ctypes.c_int64))[0] = (
                                list(_ec).index(value)
                                if isinstance(value, _ec)
                                else int(value)
                            )

                        setattr(t, fname, property(oeget, oeset))
                        continue
            if code == "str":
                # A jac string field is one pointer to a NUL-terminated,
                # RC-managed buffer (confirmed by memory probe).

                def sget(self, _off=off):
                    data = cast(_addr(self) + _off, POINTER(c_void_p))[0]
                    if not data:
                        return ""
                    return string_at(data).decode()

                def sset(self, value, _off=off):
                    b = (value or "").encode()
                    p = lib.jac_str_new(b, len(b))
                    cast(_addr(self) + _off, POINTER(c_void_p))[0] = p

                setattr(t, fname, property(sget, sset))
            elif code == "optref" and f["aux"] not in self.layout:
                # The optional's payload is not a PyObject (a native dict or
                # erased aggregate): Python-side use of such fields is pure
                # scratch, so they live in the instance dict instead.
                continue
            elif code == "optref":
                # An optional node ref is {flag: i8, ptr}: present iff the
                # flag byte is set; the target is itself a PyObject.

                def oget(self, _off=off):
                    a = _addr(self) + _off
                    flag = cast(a, POINTER(ctypes.c_uint8))[0]
                    if not flag:
                        return None
                    ptr = cast(a + 8, POINTER(c_void_p))[0]
                    return cast(ptr, py_object).value if ptr else None

                def oset(self, value, _off=off):
                    a = _addr(self) + _off
                    if value is None:
                        cast(a, POINTER(ctypes.c_uint8))[0] = 0
                        cast(a + 8, POINTER(c_void_p))[0] = None
                    else:
                        cast(a, POINTER(ctypes.c_uint8))[0] = 1
                        cast(a + 8, POINTER(c_void_p))[0] = _addr(value)

                setattr(t, fname, property(oget, oset))
            elif code == "enum":
                enum_name = f["aux"]

                def eget(self, _f="__npy_raw_" + fname, _en=enum_name):
                    # Native enum slots hold the member ORDINAL.
                    import jaclang.compiler.frontend.constant as constant

                    return list(getattr(constant, _en))[getattr(self, _f)]

                def eset(self, value, _f="__npy_raw_" + fname, _en=enum_name):
                    import jaclang.compiler.frontend.constant as constant

                    cls = getattr(constant, _en)
                    if isinstance(value, cls):
                        setattr(self, _f, list(cls).index(value))
                    else:
                        setattr(self, _f, int(value))

                setattr(t, fname, property(eget, eset))

    def _install_natlist_props(self, t: type, fields: dict) -> None:
        lib = self.lib
        for fname, f in fields.items():
            if f["code"] != "natlist":
                continue

            def lget(self, _off=f["offset"]):
                ptr = cast(_addr(self) + _off, POINTER(c_void_p))[0]
                return NativeList(lib, ptr)

            def lset(self, value, _off=f["offset"]):
                if isinstance(value, NativeList):
                    cast(_addr(self) + _off, POINTER(c_void_p))[0] = value._ptr
                    return
                ptr = lib.npy_list_new()
                for v in value or ():
                    lib.npy_list_append(ptr, _addr(v))
                cast(_addr(self) + _off, POINTER(c_void_p))[0] = ptr

            setattr(t, fname, property(lget, lset))

    def _install_overlay_props(self, t: type, name: str, fields: dict) -> None:
        """Fields whose native storage Python has no view over (native
        dicts, foreign pointers, non-object optionals) are plain instance
        attributes: tp_dictoffset gives every node generic attribute
        storage, and a __getattr__ seeds the twin's dataclass default on
        first read. Mangled names alias the same defaults."""
        import dataclasses

        twin = t.__npy_twin__
        try:
            dc_fields = {f.name: f for f in dataclasses.fields(twin)}
        except TypeError:
            dc_fields = {}
        defaults: dict = {}
        for fname, f in fields.items():
            if f["code"] not in ("ptr", "opaque") and not (
                f["code"] == "optref" and f["aux"] not in self.layout
            ):
                continue
            dcf = dc_fields.get(fname)
            if dcf is not None and dcf.default_factory is not dataclasses.MISSING:
                spec = dcf.default_factory
            elif dcf is not None and dcf.default is not dataclasses.MISSING:
                spec = (lambda _v=dcf.default: _v)
            else:
                # Same rule the store-era schema settled on: a nullable
                # annotation means None is the meaningful unset state, and
                # only non-nullable containers seed fresh-empty.
                ann = str(dcf.type) if dcf is not None else ""
                parts = [x.strip(" ()") for x in ann.split("|")]
                if "None" in parts:
                    spec = (lambda: None)
                elif ann.lstrip("(").strip().startswith("dict"):
                    spec = dict
                elif ann.lstrip("(").strip().startswith("list"):
                    spec = list
                elif ann.lstrip("(").strip().startswith("set"):
                    spec = set
                else:
                    spec = (lambda: None)
            defaults[fname] = spec
            if fname.startswith("__") and not fname.endswith("__"):
                for cls in twin.__mro__:
                    if cls is not object:
                        defaults[f"_{cls.__name__}{fname}"] = spec

        if not defaults:
            return

        def __getattr__(self, attr, _d=defaults):
            spec = _d.get(attr)
            if spec is None:
                raise AttributeError(
                    f"{type(self).__name__!r} object has no attribute {attr!r}"
                )
            val = spec()
            setattr(self, attr, val)
            return val

        t.__getattr__ = __getattr__

    def _roles(self):
        if self._role_map is None:
            from jaclang.compiler.frontend.npy_roles import ROLE_FIELDS

            self._role_map = ROLE_FIELDS
        return self._role_map

    def _install_role_props(self, t: type, name: str, fields: dict) -> None:
        lib = self.lib
        bridge = self
        # A slot-backed field on this class wins over a role getter an MRO
        # ancestor contributes under the same name.
        seen: set[str] = set(fields)
        for cls_name in [name] + [b.__name__ for b in t.__npy_twin__.__mro__]:
            for fname, (role, direction, kind) in (
                self._roles().get(cls_name, {}).items()
            ):
                if fname in seen:
                    continue
                seen.add(fname)
                tag = _stable_tag(role)
                if kind == "complex":
                    continue

                def rget(self, _tag=tag, _dir=direction, _kind=kind, _role=role):
                    found = lib.npy_adj(_addr(self), _tag, _dir)
                    if _kind == "many":
                        return found
                    if _kind == "one":
                        return found[0]
                    if _kind == "opt":
                        return found[0] if found else None
                    s = bridge.role_shape(self, _role)
                    if s == 2:
                        return found
                    if s == 1:
                        return found[0] if found else None
                    return None

                def rset(self, value, _tag=tag, _role=role):
                    lib.npy_role_clear(_addr(self), 2, _tag)
                    items = value if isinstance(value, (list, tuple)) else (
                        [] if value is None else [value]
                    )
                    for v in items:
                        if v is not None:
                            lib.npy_conn(_addr(self), _addr(v), _tag)

                setattr(t, fname, property(rget, rset))

    _KID_TAG = None

    def _install_parent(self, t: type) -> None:
        """parent is the one hand-written adjacency getter: last Kid-in
        holder, else last Role-in holder, else the _ctx_parent slot."""
        lib = self.lib
        kid_tag = _stable_tag("Kid")
        role_tag = _stable_tag("Role")

        def pget(self):
            found = lib.npy_adj(_addr(self), kid_tag, 1)
            if found:
                return found[-1]
            holders = lib.npy_adj(_addr(self), role_tag, 1)
            if holders:
                return holders[-1]
            return getattr(self, "_ctx_parent", None)

        setattr(t, "parent", property(pget))

    def _install_anchorless_overrides(self, t: type, name: str) -> None:
        """Twin methods that introspect Python edge anchors have no anchors
        to read on kernel-backed nodes; the graph-op equivalents replace
        them (desk-checked: _drop_primary is on the sym-insert path,
        replace_kid on tooling paths)."""
        lib = self.lib
        if name == "UniScopeNode":
            sp_tag = _stable_tag("ScopePrimary")

            def _drop_primary(self, sym, _tag=sp_tag):
                lib.npy_disconn(_addr(self), _addr(sym), 2, _tag)

            t._drop_primary = _drop_primary
        if name == "UniNode":
            role_map = self._roles()

            def replace_kid(self, old, new):
                from jaclang.compiler.frontend import roles as roles_mod

                for rname in dir(roles_mod):
                    rcls = getattr(roles_mod, rname)
                    if not isinstance(rcls, type):
                        continue
                    rtag = _stable_tag(rname)
                    peers = lib.npy_adj(_addr(self), rtag, 2)
                    if any(p is old for p in peers):
                        lib.npy_disconn(_addr(self), _addr(old), 2, rtag)
                        lib.npy_conn(_addr(self), _addr(new), rtag)
                self.set_kids(
                    [new if k is old else k for k in self.kid], pos_update=False
                )
                return self

            t.replace_kid = replace_kid

    def _install_new(self, t: type, name: str) -> None:
        lib = self.lib
        kind = self.layout[name]["kind"]

        def __new__(cls, *args, **kwargs):
            k = self.kind_of_type.get(cls)
            if k is None:
                # A Python-defined subclass of a native type (pass walkers
                # extending TreeWalker): an ordinary heap instance -- the
                # layout-compatible struct region is zero-initialized and
                # native code never handles these.
                return object.__new__(cls)
            ptr = lib.npy_alloc(k)
            return cast(ptr, py_object).value

        t.__new__ = staticmethod(__new__)

    # -- graph seam for pass-side edge expressions -------------------------
    def connect(self, left, right, edge_cls, *_a) -> object:
        tag = _stable_tag(edge_cls.__name__)
        lefts = left if isinstance(left, list) else [left]
        rights = right if isinstance(right, list) else [right]
        for l in lefts:
            for r in rights:
                self.lib.npy_conn(_addr(l), _addr(r), tag)
        return right

    def hop(self, origin, direction: int, edge_cls) -> list:
        tag = _stable_tag(edge_cls.__name__) if edge_cls is not None else 0
        d = 2 if direction == 2 else (1 if direction == 1 else 3)
        if d == 3:
            return list(self.lib.npy_adj(_addr(origin), tag, 2)) + list(
                self.lib.npy_adj(_addr(origin), tag, 1)
            )
        return self.lib.npy_adj(_addr(origin), tag, d)

    def clear_edges(self, origin, direction: int, edge_cls) -> bool:
        tag = _stable_tag(edge_cls.__name__)
        if direction in (2, 3):
            self.lib.npy_role_clear(_addr(origin), 2, tag)
        if direction in (1, 3):
            self.lib.npy_role_clear(_addr(origin), 1, tag)
        return True

    def disconnect(self, left, right, direction: int, edge_cls) -> bool:
        tag = _stable_tag(edge_cls.__name__) if edge_cls is not None else 0
        return bool(
            self.lib.npy_disconn(_addr(left), _addr(right), direction, tag)
        )


_BRIDGE: NpyBridge | None = None


def bridge() -> NpyBridge | None:
    return _BRIDGE


def is_native(obj) -> bool:
    return getattr(type(obj), "__npy_native__", False)


def ensure_loaded() -> NpyBridge | None:
    global _BRIDGE
    if _BRIDGE is not None:
        return _BRIDGE
    path = os.environ.get("JAC_FRONTEND_LIB", "")
    if not path or not os.path.exists(path):
        return None
    if not os.path.exists(path + ".layout.json"):
        return None
    _BRIDGE = NpyBridge(path)
    return _BRIDGE


# Modules whose classes are rebound as they finish executing.
ADOPTED_MODULES = (
    "jaclang.compiler.frontend.unitree",
    "jaclang.compiler.frontend.srcloc",
    "jaclang.compiler.frontend.parser.tokens",
    "jaclang.compiler.frontend.relations",
)


def on_module_exec(module) -> None:
    """Meta-importer hook: rebind a just-executed scope module's classes."""
    b = ensure_loaded()
    if b is None:
        return
    if getattr(module, "__name__", "") in ADOPTED_MODULES:
        b.adopt_module(module)
