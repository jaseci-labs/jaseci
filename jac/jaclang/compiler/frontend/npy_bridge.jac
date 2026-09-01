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

One-time ctypes is used to construct the types; steady-state scalar field
access never crosses ctypes. The per-access ctypes that remains in the
non-scalar accessors is scheduled for replacement by backend-generated
native descriptors (#8818).
"""

import ctypes;
import json;
import os;
import types as pytypes;
import from ctypes {
    POINTER,
    Structure,
    c_char_p,
    c_int,
    c_ssize_t,
    c_uint,
    c_void_p,
    cast,
    py_object,
    string_at
}

# -- CPython construction surface (typeslots.h / structmember.h) ------------
glob Py_tp_members: int = 72;
glob Py_TPFLAGS_BASETYPE: int = 1024;

glob T_LONGLONG: int = 17;
glob T_BOOL: int = 14;
glob T_DOUBLE: int = 4;
glob T_OBJECT: int = 6;  # NULL reads as None -- every jac ref field is nullable-at-rest
glob T_PYSSIZET: int = 19;
glob READONLY: int = 1;

glob HDR_DICT_OFF: int = 16;

# ctypes.Structure subclasses built dynamically: the bridge is bootstrap
# plumbing, so these tiny mirror structs skip the archetype machinery.
glob PyType_Slot: any = `type(
         'PyType_Slot',
         (Structure, ),
         {'_fields_': [('slot', c_int), ('pfunc', c_void_p)]}
     );
glob PyType_Spec: any = `type(
         'PyType_Spec',
         (Structure, ),
         {
             '_fields_': [
                 ('name', c_char_p),
                 ('basicsize', c_int),
                 ('itemsize', c_int),
                 ('flags', c_uint),
                 ('slots', POINTER(PyType_Slot)),

             ]
         }
     );
glob PyMemberDef: any = `type(
         'PyMemberDef',
         (Structure, ),
         {
             '_fields_': [
                 ('name', c_char_p),
                 ('type', c_int),
                 ('offset', c_ssize_t),
                 ('flags', c_int),
                 ('doc', c_char_p),

             ]
         }
     );


def _stable_tag(name: str) -> int {
    h = 14695981039346656037;
    for b in name.encode() {
        h = ((h ^ b) * 1099511628211) & 18446744073709551615;
    }
    return h & 9007199254740991;
}


def _addr(o: any) -> int {
    return id(o);
}


"""Resolve an enum class named in the layout sidecar: most live in
frontend.constant, the lexer's TokenKind in parser.tokens."""
def _enum_class(name: str) -> any {
    import jaclang.compiler.frontend.constant as constant;
    cls = getattr(constant, name, None);
    if cls is None {
        import jaclang.compiler.frontend.parser.tokens as tokens;
        cls = getattr(tokens, name);
    }
    return cls;
}


"""Native enum slots follow the backend's per-enum convention: int-valued
enums store the member VALUE, string-valued enums store the ORDINAL
(na_ir_gen/enums.impl.jac)."""
def _enum_decode(cls: any, raw: int) -> any {
    if isinstance(next(iter(cls)).value, int) {
        return cls(raw);
    }
    return `list(cls)[raw];
}


def _enum_encode(cls: any, member: any) -> int {
    if isinstance(member.value, int) {
        return int(member.value);
    }
    return `list(cls).index(member);
}


def _generic_get_dict(nd: any) -> any {
    api = ctypes.pythonapi;
    api.PyObject_GenericGetDict.restype = py_object;
    api.PyObject_GenericGetDict.argtypes = [py_object, c_void_p];
    return api.PyObject_GenericGetDict(nd, None);
}


# Root base for native types: contributes no storage, only the __dict__
# descriptor FromSpec types otherwise lack (cached_property and vars()
# want it), backed by CPython's own generic dict access. Built via type()
# because __slots__/__dict__ must land verbatim in the class namespace.
glob NpyBase: any = `type(
         'NpyBase',
         (object, ),
         {'__slots__': (), '__dict__': property(_generic_get_dict)}
     );


"""A mutable view over a jac native list of node pointers. Elements are
PyObject-headed nodes, so reads come back as the objects themselves."""
class NativeList {
    def init(self: NativeList, lib: any, ptr: int) -> None {
        self._lib = lib;
        self._ptr = ptr or 0;
    }

    def __len__(self: NativeList) -> int {
        if not self._ptr {
            return 0;
        }
        return self._lib.npy_list_len(self._ptr);
    }

    def __getitem__(self: NativeList, i: any) -> any {
        n = len(self);
        if isinstance(i, slice) {
            (start, stop, step) = i.indices(n);
            return [self[j] for j in range(start, stop, step)];
        }
        if i < 0 {
            i += n;
        }
        if i < 0 or i >= n {
            raise IndexError(i);
        }
        return cast(self._lib.npy_list_get(self._ptr, i), py_object).value;
    }

    def __iter__(self: NativeList) -> any {
        for j in range(len(self)) {
            yield self[j];
        }
    }

    def __bool__(self: NativeList) -> bool {
        return len(self) > 0;
    }

    def append(self: NativeList, v: any) -> None {
        if not self._ptr {
            raise ValueError("append to an unset native list field");
        }
        self._lib.npy_list_append(self._ptr, _addr(v));
    }
}


"""One loaded frontend lib + its constructed type universe."""
class NpyBridge {
    def init(self: NpyBridge, lib_path: str) -> None {
        self.lib = ctypes.PyDLL(lib_path);
        layout_path = lib_path + ".layout.json";
        with open(layout_path) as f {
            self.layout = json.load(f)["classes"];
        }
        self._keep = [];  # ctypes structures that must outlive the types
        self.types = {};
        self.kind_of_type = {};
        self._twins = {};
        self._bind();
    }

    # -- lib call surface --------------------------------------------------
    def _bind(self: NpyBridge) -> None {
        L = self.lib;
        L.npy_register_kind.argtypes = [
            ctypes.c_int64,
            c_void_p,
            ctypes.c_int64,
            ctypes.c_int64,
            ctypes.c_int64
        ];
        L.npy_register_kind.restype = ctypes.c_int64;
        L.npy_alloc.argtypes = [ctypes.c_int64];
        L.npy_alloc.restype = c_void_p;
        L.npy_adj.argtypes = [ctypes.c_int64] * 3;
        L.npy_adj.restype = py_object;
        L.npy_conn.argtypes = [ctypes.c_int64] * 3;
        L.npy_conn.restype = ctypes.c_int64;
        L.npy_disconn.argtypes = [ctypes.c_int64] * 4;
        L.npy_disconn.restype = ctypes.c_int64;
        L.npy_role_clear.argtypes = [ctypes.c_int64] * 3;
        L.npy_role_clear.restype = ctypes.c_int64;
        L.np_err_count.argtypes = [];
        L.np_err_count.restype = ctypes.c_int64;
        L.np_lex_errs.argtypes = [];
        L.np_lex_errs.restype = ctypes.c_int64;
        for name in ("np_diags", "np_lexdiags", "np_comments") {
            fn = getattr(L, name);
            fn.argtypes = [];
            fn.restype = py_object;
        }
        L.np_parse.restype = py_object;
        L.jac_str_new.argtypes = [c_char_p, ctypes.c_int64];
        L.jac_str_new.restype = c_void_p;
        L.npy_list_len.argtypes = [ctypes.c_int64];
        L.npy_list_len.restype = ctypes.c_int64;
        L.npy_list_get.argtypes = [ctypes.c_int64] * 2;
        L.npy_list_get.restype = c_void_p;
        L.npy_list_append.argtypes = [ctypes.c_int64] * 2;
        L.npy_list_append.restype = ctypes.c_int64;
        L.npy_list_new.argtypes = [];
        L.npy_list_new.restype = c_void_p;
    }

    """Call an export taking two jac-str args (each a {p, p, len} triple)."""
    def _call_str2(self: NpyBridge, name: str, a: str, b: str) -> any {
        fn = getattr(self.lib, name);
        ab = a.encode();
        bb = b.encode();
        pa = self.lib.jac_str_new(ab, len(ab));
        pb = self.lib.jac_str_new(bb, len(bb));
        return fn(
            c_void_p(pa),
            c_void_p(pa),
            ctypes.c_int64(len(ab)),
            c_void_p(pb),
            c_void_p(pb),
            ctypes.c_int64(len(bb))
        );
    }

    def parse(self: NpyBridge, source: str, path: str) -> any {
        return self._call_str2("np_parse", source, path);
    }

    def weave(self: NpyBridge, main_mod: any, a_src: str, a_path: str) -> int {
        fn = self.lib.np_weave;
        fn.restype = ctypes.c_int64;
        ab = a_src.encode();
        bb = a_path.encode();
        pa = self.lib.jac_str_new(ab, len(ab));
        pb = self.lib.jac_str_new(bb, len(bb));
        return fn(
            c_void_p(_addr(main_mod)),
            c_void_p(pa),
            c_void_p(pa),
            ctypes.c_int64(len(ab)),
            c_void_p(pb),
            c_void_p(pb),
            ctypes.c_int64(len(bb))
        );
    }

    def role_shape(self: NpyBridge, nd: any, role_name: str) -> int {
        fn = self.lib.np_role_shape;
        fn.restype = ctypes.c_int64;
        rb = role_name.encode();
        pr = self.lib.jac_str_new(rb, len(rb));
        return fn(
            c_void_p(_addr(nd)), c_void_p(pr), c_void_p(pr), ctypes.c_int64(len(rb))
        );
    }

    # -- type construction -------------------------------------------------
    """Rebind this source module's unitree classes to native types.

    Called from the meta-importer as each scope module finishes
    executing, before anything imports names out of it."""
    def adopt_module(self: NpyBridge, module: any) -> None {
        mod_name = getattr(module, "__name__", "");
        for name in `list(vars(module)) {
            twin = getattr(module, name);
            if (
                isinstance(twin, `type)
                and name in self.layout
                and getattr(twin, "__module__", "") == mod_name
            ) {
                # Only classes this module DECLARES: re-exported imports
                # (e.g. the runtime's TreeWalker) must keep their identity.
                self._twins.setdefault(name, twin);
            }
        }
        for name in `list(vars(module)) {
            twin = getattr(module, name);
            if (
                name in self.layout
                and isinstance(twin, `type)
                and self._twins.get(name) is twin
            ) {
                setattr(module, name, self._type_for(name));
            }
        }
    }

    def _type_for(self: NpyBridge, name: str) -> any {
        t = self.types.get(name);
        if t is not None {
            return t;
        }
        twin: any = self._twins[name];
        bases = [];
        for anc in twin.__bases__ {
            if (
                anc.__name__ in self.layout
                and anc.__name__ != name
                and self._twins.get(anc.__name__) is anc
            ) {
                # Identity check: a runtime class sharing a name with a laid-
                # out unitree class (e.g. Archetype) must not become a base.
                bases.append(self._type_for(anc.__name__));
            }
        }
        if not bases {
            for anc in twin.__mro__[1:] {
                if (
                    anc.__name__ in self.layout
                    and anc.__name__ != name
                    and self._twins.get(anc.__name__) is anc
                ) {
                    bases.append(self._type_for(anc.__name__));
                    break;
                }
            }
        }
        t = self._build_type(name, twin, bases);
        self.types[name] = t;
        info = self.layout[name];
        self.kind_of_type[t] = _stable_tag(name);
        self.lib.npy_register_kind(
            _stable_tag(name),
            c_void_p(_addr(t)),
            info["size"],
            info["tag"] or 0,
            info["tag_offset"]
        );
        return t;
    }

    def _build_type(self: NpyBridge, name: str, twin: any, bases_in: list) -> any {
        info = self.layout[name];
        fields: dict[str, dict[str, any]] = info["fields"];

        members: list[tuple] = [];
        for (fname, f) in fields.items() {
            code = f["code"];
            off = f["offset"];
            if code == "int" {
                members.append((fname.encode(), T_LONGLONG, off, 0));
            } elif code == "bool" {
                members.append((fname.encode(), T_BOOL, off, 0));
            } elif code == "float" {
                members.append((fname.encode(), T_DOUBLE, off, 0));
            } elif code == "obj" {
                members.append((fname.encode(), T_OBJECT, off, 0));
            } elif code == "enum" {
                members.append((b"__npy_raw_" + fname.encode(), T_LONGLONG, off, 0));
            }
        }
        members.append((b"__dictoffset__", T_PYSSIZET, HDR_DICT_OFF, READONLY));

        marr = (PyMemberDef * (len(members) + 1))();
        for i in range(len(members)) {
            (nm, ty, off, fl) = members[i];
            marr[i] = PyMemberDef(nm, ty, off, fl, None);
        }
        self._keep.append(marr);

        slots = (PyType_Slot * 3)();
        slots[0] = PyType_Slot(Py_tp_members, cast(marr, c_void_p));
        slots[1] = PyType_Slot(0, None);
        self._keep.append(slots);

        tname = ("jaclang.native." + name).encode();
        self._keep.append(tname);
        # Only chain roots declare CPython storage; every derived type
        # inherits, so all native types share their root as solid base and
        # multiple inheritance can never conflict. True instance sizes are
        # the native allocator's business, and the member tables address
        # fields by explicit offset regardless of tp_basicsize.
        basicsize = 0 if bases_in else info["size"];
        spec = PyType_Spec(tname, basicsize, 0, Py_TPFLAGS_BASETYPE, slots);
        self._keep.append(spec);

        pythonapi = ctypes.pythonapi;
        pythonapi.PyType_FromSpecWithBases.restype = py_object;
        pythonapi.PyType_FromSpecWithBases.argtypes = [POINTER(PyType_Spec), py_object];
        bases = tuple(bases_in) if bases_in else (NpyBase, );
        t: any = pythonapi.PyType_FromSpecWithBases(ctypes.byref(spec), bases);

        t.__npy_native__ = True;
        t.__npy_twin__ = twin;
        self._flatten_twin(t, twin, fields);
        self._install_field_props(t, fields);
        self._install_natlist_props(t, fields);
        self._install_overlay_props(t, fields);
        for _f in fields {
            self._alias_mangled(t, _f);
        }
        self._install_role_props(t, name, fields);
        self._install_parent(t);
        self._install_anchorless_overrides(t, name);
        self._install_new(t);
        return t;
    }

    """A zero-arg super() in twin bytecode resolves through the function's
    __class__ cell, which points at the twin. Native instances are not twin
    subclasses, so the cell is rebound to the native counterpart of the
    defining class -- the native MRO mirrors the twin MRO, so super()
    chains identically."""
    def _rebind_class_cell(self: NpyBridge, fn: any, owner_native: any) -> any {
        code = getattr(fn, "__code__", None);
        if code is None or "__class__" not in code.co_freevars {
            return fn;
        }
        idx = code.co_freevars.index("__class__");
        closure = `list(fn.__closure__);
        closure[idx] = pytypes.CellType(owner_native);
        out = pytypes.FunctionType(
            code, fn.__globals__, fn.__name__, fn.__defaults__, tuple(closure)
        );
        out.__kwdefaults__ = fn.__kwdefaults__;
        out.__dict__.update(fn.__dict__);
        return out;
    }

    def _flatten_member(self: NpyBridge, v: any, owner_native: any) -> any {
        if isinstance(v, pytypes.FunctionType) {
            return self._rebind_class_cell(v, owner_native);
        }
        if isinstance(v, (classmethod, staticmethod)) {
            return `type(v)(self._rebind_class_cell(v.__func__, owner_native));
        }
        if isinstance(v, property) {
            return property(
                v.fget and self._rebind_class_cell(v.fget, owner_native),
                v.fset and self._rebind_class_cell(v.fset, owner_native),
                v.fdel and self._rebind_class_cell(v.fdel, owner_native)
            );
        }
        return v;
    }

    """Every method/property the twins define, flattened base-first so
    overrides land last. Python functions bind to any instance, so the
    twins' bytecode runs unchanged over native storage; __class__ cells
    are rebound so super() works."""
    def _flatten_twin(self: NpyBridge, t: any, twin: any, fields: dict) -> None {
        skip_names = {
            "__dict__",
            "__weakref__",
            "__module__",
            "__qualname__",
            "__slots__",
            "__dictoffset__",
            "__basicsize__",
            "__new__",
            # Class-creation hooks must not be flattened: every jac-generated
            # subclass lists the runtime archetype base (Walker/Node/...)
            # explicitly, so Archetype.__init_subclass__ is already in its
            # MRO; a flattened copy on the native type would run it a second
            # time, and the second dataclass pass strips factory defaults.
            "__init_subclass__",
            "__set_name__",

        };
        # Classes the native type already inherits from must not be
        # flattened either: their methods arrive through the MRO. typing
        # machinery (Generic) is C-guarded against foreign types; generic
        # twins get an erasure __class_getitem__ below instead.
        inherited = set(t.__mro__);
        is_generic = False;
        for cls in reversed(twin.__mro__) {
            if cls is object or cls in inherited {
                continue;
            }
            if cls.__module__ == "typing" {
                is_generic = True;
                continue;
            }
            owner_native: any = t;
            if (
                cls is not twin
                and cls.__name__ in self.layout
                and self._twins.get(cls.__name__) is cls
            ) {
                owner_native = self._type_for(cls.__name__);
            }
            for (k, v) in vars(cls).items() {
                if k in skip_names {
                    continue;
                }
                if (
                    k in fields
                    and not callable(v)
                    and not isinstance(v, (property, classmethod, staticmethod))
                ) {
                    # A dataclass field default is a plain class attribute;
                    # copying it would shadow the native member descriptor.
                    continue;
                }
                try {
                    setattr(t, k, self._flatten_member(v, owner_native));
                } except (TypeError, AttributeError) { }
            }
        }
        if is_generic {
            # Runtime type params are erased: SubTag[Token] constructs a
            # plain SubTag, exactly what subscripted twin calls need.
            def _erasure_getitem(cls: any, _item: any) -> any {
                return cls;
            }
            t.__class_getitem__ = classmethod(_erasure_getitem);
        }
    }

    """Twin bytecode reaches a __-prefixed field through its compile-time
    mangled name (_DeclaringClass__field); alias the accessor under every
    MRO class's mangling so whichever twin method reads it resolves."""
    def _alias_mangled(self: NpyBridge, t: any, fname: str) -> None {
        if not (fname.startswith("__") and not fname.endswith("__")) {
            return;
        }
        descr = t.__dict__.get(fname);
        if descr is None {
            return;
        }
        for cls in t.__npy_twin__.__mro__ {
            if cls is object {
                continue;
            }
            try {
                setattr(t, f"_{cls.__name__}{fname}", descr);
            } except (TypeError, AttributeError) { }
        }
    }

    # Each installer below builds its closures inside a per-field call so
    # every captured offset/tag is frozen (jac closures late-bind loop
    # variables exactly as Python's do).
    def _install_optenum_prop(
        self: NpyBridge, t: any, fname: str, off: int, ecls: any
    ) -> None {
        def oeget(nd: any) -> any {
            a = _addr(nd) + off;
            if not cast(a, POINTER(ctypes.c_uint8))[0] {
                return None;
            }
            raw = cast(a + 8, POINTER(ctypes.c_int64))[0];
            return _enum_decode(ecls, raw);
        }
        def oeset(nd: any, value: any) -> None {
            a = _addr(nd) + off;
            if value is None {
                cast(a, POINTER(ctypes.c_uint8))[0] = 0;
                return;
            }
            cast(a, POINTER(ctypes.c_uint8))[0] = 1;
            cast(a + 8, POINTER(ctypes.c_int64))[0] = (
                _enum_encode(ecls, value) if isinstance(value, ecls) else int(value)
            );
        }
        setattr(t, fname, property(oeget, oeset));
    }

    """A jac string field is one pointer to a NUL-terminated, RC-managed
    buffer (confirmed by memory probe)."""
    def _install_str_prop(self: NpyBridge, t: any, fname: str, off: int) -> None {
        lib = self.lib;
        def sget(nd: any) -> str {
            data = cast(_addr(nd) + off, POINTER(c_void_p))[0];
            if not data {
                return "";
            }
            return string_at(data).decode();
        }
        def sset(nd: any, value: any) -> None {
            b = (value or "").encode();
            p = lib.jac_str_new(b, len(b));
            cast(_addr(nd) + off, POINTER(c_void_p))[0] = p;
        }
        setattr(t, fname, property(sget, sset));
    }

    """An optional node ref is {flag: i8, ptr}: present iff the flag byte
    is set; the target is itself a PyObject."""
    def _install_optref_prop(self: NpyBridge, t: any, fname: str, off: int) -> None {
        def oget(nd: any) -> any {
            a = _addr(nd) + off;
            flag = cast(a, POINTER(ctypes.c_uint8))[0];
            if not flag {
                return None;
            }
            ptr = cast(a + 8, POINTER(c_void_p))[0];
            return cast(ptr, py_object).value if ptr else None;
        }
        def oset(nd: any, value: any) -> None {
            a = _addr(nd) + off;
            if value is None {
                cast(a, POINTER(ctypes.c_uint8))[0] = 0;
                cast(a + 8, POINTER(c_void_p))[0] = None;
            } else {
                cast(a, POINTER(ctypes.c_uint8))[0] = 1;
                cast(a + 8, POINTER(c_void_p))[0] = _addr(value);
            }
        }
        setattr(t, fname, property(oget, oset));
    }

    def _install_enum_prop(
        self: NpyBridge, t: any, fname: str, enum_name: str
    ) -> None {
        raw_attr = "__npy_raw_" + fname;
        def eget(nd: any) -> any {
            return _enum_decode(_enum_class(enum_name), getattr(nd, raw_attr));
        }
        def eset(nd: any, value: any) -> None {
            cls = _enum_class(enum_name);
            if isinstance(value, cls) {
                setattr(nd, raw_attr, _enum_encode(cls, value));
            } else {
                setattr(nd, raw_attr, int(value));
            }
        }
        setattr(t, fname, property(eget, eset));
    }

    def _install_field_props(
        self: NpyBridge, t: any, fields: dict[str, dict[str, any]]
    ) -> None {
        import dataclasses;
        import re as _re;
        _dcf: dict[str, str] = {};
        try {
            for f in dataclasses.fields(t.__npy_twin__) {
                _dcf[f.name] = str(f.`type);
            }
        } except TypeError { }
        for (fname, f) in fields.items() {
            code = f["code"];
            off = f["offset"];
            if code == "opaque" {
                # An optional enum lowers to a {flag, ordinal} pair the
                # layout can't name; the twin's annotation can.
                _ann = _dcf.get(fname, "");
                _m = _re.fullmatch(r"\(?\s*(\w+)\s*\|\s*None\s*\)?", _ann);
                if _m {
                    import jaclang.compiler.frontend.constant as _const;
                    _ecls = getattr(_const, _m.group(1), None);
                    if isinstance(_ecls, `type) {
                        self._install_optenum_prop(t, fname, off, _ecls);
                        continue;
                    }
                }
            }
            if code == "str" {
                self._install_str_prop(t, fname, off);
            } elif code == "optref" and f["aux"] not in self.layout {
                # The optional's payload is not a PyObject (a native dict or
                # erased aggregate): Python-side use of such fields is pure
                # scratch, so they live in the instance dict instead.
                continue;
            } elif code == "optref" {
                self._install_optref_prop(t, fname, off);
            } elif code == "enum" {
                self._install_enum_prop(t, fname, f["aux"]);
            }
        }
    }

    def _install_natlist_prop(self: NpyBridge, t: any, fname: str, off: int) -> None {
        lib = self.lib;
        def lget(nd: any) -> any {
            ptr = cast(_addr(nd) + off, POINTER(c_void_p))[0];
            return NativeList(lib, ptr);
        }
        def lset(nd: any, value: any) -> None {
            if isinstance(value, NativeList) {
                cast(_addr(nd) + off, POINTER(c_void_p))[0] = value._ptr;
                return;
            }
            ptr = lib.npy_list_new();
            for v in value or () {
                lib.npy_list_append(ptr, _addr(v));
            }
            cast(_addr(nd) + off, POINTER(c_void_p))[0] = ptr;
        }
        setattr(t, fname, property(lget, lset));
    }

    def _install_natlist_props(
        self: NpyBridge, t: any, fields: dict[str, dict[str, any]]
    ) -> None {
        for (fname, f) in fields.items() {
            if f["code"] == "natlist" {
                self._install_natlist_prop(t, fname, f["offset"]);
            }
        }
    }

    def _const_spec(self: NpyBridge, v: any) -> any {
        def _spec -> any {
            return v;
        }
        return _spec;
    }

    def _none_spec(self: NpyBridge) -> any {
        def _spec -> any {
            return None;
        }
        return _spec;
    }

    """Fields whose native storage Python has no view over (native dicts,
    foreign pointers, non-object optionals) are plain instance attributes:
    tp_dictoffset gives every node generic attribute storage, and a
    __getattr__ seeds the twin's dataclass default on first read. Mangled
    names alias the same defaults."""
    def _install_overlay_props(
        self: NpyBridge, t: any, fields: dict[str, dict[str, any]]
    ) -> None {
        import dataclasses;
        twin: any = t.__npy_twin__;
        dc_fields: dict[str, any] = {};
        try {
            for f in dataclasses.fields(twin) {
                dc_fields[f.name] = f;
            }
        } except TypeError { }
        defaults: dict[str, any] = {};
        for (fname, f) in fields.items() {
            if f["code"] not in ("ptr", "opaque")
                and not (f["code"] == "optref" and f["aux"] not in self.layout) {
                continue;
            }
            dcf = dc_fields.get(fname);
            if dcf is not None and dcf.default_factory is not dataclasses.MISSING {
                spec = dcf.default_factory;
            } elif dcf is not None and dcf.`default is not dataclasses.MISSING {
                spec = self._const_spec(dcf.`default);
            } else {
                # Same rule the store-era schema settled on: a nullable
                # annotation means None is the meaningful unset state, and
                # only non-nullable containers seed fresh-empty.
                ann = str(dcf.`type) if dcf is not None else "";
                parts = [x.strip(" ()") for x in ann.split("|")];
                bare = ann.lstrip("(").strip();
                if "None" in parts {
                    spec = self._none_spec();
                } elif bare.startswith("dict") {
                    spec = `dict;
                } elif bare.startswith("list") {
                    spec = `list;
                } elif bare.startswith("set") {
                    spec = `set;
                } else {
                    spec = self._none_spec();
                }
            }
            defaults[fname] = spec;
            if fname.startswith("__") and not fname.endswith("__") {
                for cls in twin.__mro__ {
                    if cls is not object {
                        defaults[f"_{cls.__name__}{fname}"] = spec;
                    }
                }
            }
        }
        if not defaults {
            return;
        }
        def __getattr__(nd: any, attr: str) -> any {
            spec = defaults.get(attr);
            if spec is None {
                tn = repr(`type(nd).__name__);
                an = repr(attr);
                raise AttributeError(f"{tn} object has no attribute {an}");
            }
            val = spec();
            setattr(nd, attr, val);
            return val;
        }
        t.__getattr__ = __getattr__;
    }

    def _roles(self: NpyBridge) -> dict {
        import from jaclang.compiler.frontend.npy_roles { ROLE_FIELDS }
        return ROLE_FIELDS;
    }

    def _make_std_setter(self: NpyBridge, tag: int) -> any {
        lib = self.lib;
        def sset(nd: any, value: any) -> None {
            lib.npy_role_clear(_addr(nd), 2, tag);
            if value is not None {
                lib.npy_conn(_addr(nd), _addr(value), tag);
            }
        }
        return sset;
    }

    def _make_parent_scope_setter(self: NpyBridge, child_tag: int) -> any {
        lib = self.lib;
        parent_tag = _stable_tag("ScopeParent");
        def pset(nd: any, value: any) -> None {
            lib.npy_role_clear(_addr(nd), 1, child_tag);
            lib.npy_role_clear(_addr(nd), 2, parent_tag);
            if value is not None {
                lib.npy_conn(_addr(nd), _addr(value), parent_tag);
            }
        }
        return pset;
    }

    """Python-object values (TypeBase and friends) cannot be kernel edges;
    the instance dict is their storage and holds the strong reference."""
    def _install_py_value_prop(
        self: NpyBridge, t: any, fname: str, many: bool
    ) -> None {
        key = "__npy_" + fname;
        def vget(nd: any) -> any {
            v = nd.__dict__.get(key);
            if v is None and many {
                return [];
            }
            return v;
        }
        def vset(nd: any, value: any) -> None {
            nd.__dict__[key] = value;
        }
        setattr(t, fname, property(vget, vset));
    }

    """The linked ImplDef stands in for a decl's body until one is written
    directly (roles.impl.jac ground truth)."""
    def _install_impl_body_prop(
        self: NpyBridge, t: any, fname: str, body_tag: int, role: str
    ) -> None {
        lib = self.lib;
        bridge_self = self;
        implof_tag = _stable_tag("ImplOf");
        def bget(nd: any) -> any {
            impls = lib.npy_adj(_addr(nd), implof_tag, 2);
            if impls {
                return impls[0];
            }
            found = lib.npy_adj(_addr(nd), body_tag, 2);
            s = bridge_self.role_shape(nd, role);
            if s == 2 {
                return found;
            }
            if s == 1 {
                return found[0] if found else None;
            }
            return None;
        }
        setattr(t, fname, property(bget));
    }

    def _install_main_mod_prop(self: NpyBridge, t: any, fname: str, tag: int) -> None {
        lib = self.lib;
        def mget(nd: any) -> any {
            found = lib.npy_adj(_addr(nd), tag, 2);
            if not found {
                return None;
            }
            return None if found[0].stub_only else found[0];
        }
        def mset(nd: any, value: any) -> None {
            lib.npy_role_clear(_addr(nd), 2, tag);
            if value is None {
                import jaclang.compiler.frontend.unitree as _uni;
                value = _uni.Module.make_stub();
            }
            lib.npy_conn(_addr(nd), _addr(value), tag);
        }
        setattr(t, fname, property(mget, mset));
    }

    def _install_parent_scope_prop(
        self: NpyBridge, t: any, fname: str, child_tag: int
    ) -> None {
        lib = self.lib;
        parent_tag = _stable_tag("ScopeParent");
        def psget(nd: any) -> any {
            found = lib.npy_adj(_addr(nd), child_tag, 1);
            if found {
                return found[-1];
            }
            owners = lib.npy_adj(_addr(nd), parent_tag, 2);
            return owners[-1] if owners else None;
        }
        setattr(t, fname, property(psget, self._make_parent_scope_setter(child_tag)));
    }

    def _install_role_std_prop(
        self: NpyBridge,
        t: any,
        fname: str,
        tag: int,
        direction: int,
        kind: str,
        role: str,
        setter_shape: (str | None)
    ) -> None {
        lib = self.lib;
        bridge_self = self;
        def rget(nd: any) -> any {
            found = lib.npy_adj(_addr(nd), tag, direction);
            if kind == "many" {
                return found;
            }
            if kind == "one" {
                return found[0];
            }
            if kind == "opt" {
                return found[0] if found else None;
            }
            s = bridge_self.role_shape(nd, role);
            if s == 2 {
                return found;
            }
            if s == 1 {
                return found[0] if found else None;
            }
            return None;
        }
        # Setters only where the store path has one (ROLE_SETTERS); every
        # other role field is getter-only there.
        if setter_shape is not None {
            setattr(t, fname, property(rget, self._make_std_setter(tag)));
        } else {
            setattr(t, fname, property(rget));
        }
    }

    def _install_role_props(
        self: NpyBridge, t: any, name: str, fields: dict[str, dict[str, any]]
    ) -> None {
        import from jaclang.compiler.frontend.npy_roles { ROLE_SETTERS }
        # A slot-backed field on this class wins over a role getter an MRO
        # ancestor contributes under the same name.
        seen = set(fields);
        cls_names = [name];
        for b in t.__npy_twin__.__mro__ {
            cls_names.append(b.__name__);
        }
        for cls_name in cls_names {
            for (fname, spec) in self._roles().get(cls_name, {}).items() {
                if fname in seen {
                    continue;
                }
                seen.add(fname);
                (role, direction, kind) = spec;
                tag = _stable_tag(role);
                if kind == "complex" {
                    # Twin property stays flattened; its edge refs run
                    # through the runtime graph seam.
                    continue;
                }
                if kind == "parent" {
                    # Hand-installed by _install_parent on every type.
                    continue;
                }
                setter_shape = ROLE_SETTERS.get(cls_name, {}).get(fname);
                if kind in ("py_value", "py_value_many") {
                    self._install_py_value_prop(t, fname, kind == "py_value_many");
                } elif kind == "impl_body" {
                    self._install_impl_body_prop(t, fname, tag, role);
                } elif kind == "main_mod" {
                    self._install_main_mod_prop(t, fname, tag);
                } elif kind == "parent_scope" {
                    self._install_parent_scope_prop(t, fname, tag);
                } else {
                    self._install_role_std_prop(
                        t, fname, tag, direction, kind, role, setter_shape
                    );
                }
            }
        }
    }

    """parent is the one hand-written adjacency getter: last Kid-in holder,
    else last Role-in holder, else the _ctx_parent slot."""
    def _install_parent(self: NpyBridge, t: any) -> None {
        lib = self.lib;
        kid_tag = _stable_tag("Kid");
        role_tag = _stable_tag("Role");
        def pget(nd: any) -> any {
            found = lib.npy_adj(_addr(nd), kid_tag, 1);
            if found {
                return found[-1];
            }
            holders = lib.npy_adj(_addr(nd), role_tag, 1);
            if holders {
                return holders[-1];
            }
            return getattr(nd, "_ctx_parent", None);
        }
        setattr(t, "parent", property(pget));
    }

    """Twin methods that introspect Python edge anchors have no anchors to
    read on kernel-backed nodes; the graph-op equivalents replace them
    (desk-checked: _drop_primary is on the sym-insert path, replace_kid on
    tooling paths)."""
    def _install_anchorless_overrides(self: NpyBridge, t: any, name: str) -> None {
        lib = self.lib;
        if name == "UniScopeNode" {
            sp_tag = _stable_tag("ScopePrimary");
            def _drop_primary(nd: any, sym: any) -> None {
                lib.npy_disconn(_addr(nd), _addr(sym), 2, sp_tag);
            }
            t._drop_primary = _drop_primary;
        }
        if name == "UniNode" {
            def replace_kid(nd: any, old: any, new: any) -> any {
                import jaclang.compiler.frontend.roles as roles_mod;
                for rname in dir(roles_mod) {
                    rcls = getattr(roles_mod, rname);
                    if not isinstance(rcls, `type) {
                        continue;
                    }
                    rtag = _stable_tag(rname);
                    peers = lib.npy_adj(_addr(nd), rtag, 2);
                    if any(p is old for p in peers) {
                        lib.npy_disconn(_addr(nd), _addr(old), 2, rtag);
                        lib.npy_conn(_addr(nd), _addr(new), rtag);
                    }
                }
                nd.set_kids([new if k is old else k for k in nd.kid], pos_update=False);
                return nd;
            }
            t.replace_kid = replace_kid;
        }
    }

    def _install_new(self: NpyBridge, t: any) -> None {
        lib = self.lib;
        bridge_self = self;
        def __new__(cls: any, *args: any, **kwargs: any) -> any {
            k = bridge_self.kind_of_type.get(cls);
            if k is None {
                # A Python-defined subclass of a native type (pass walkers
                # extending TreeWalker, stubcat's CatModule extending
                # Module). Inherited field properties write the ancestor's
                # struct offsets, and Python appends its own storage
                # (managed weakref pre-header, tail slots) at the declared
                # basicsize -- the chain root's, far short of the real
                # struct. Widen this subclass's tp_basicsize to the
                # ancestor's true struct size once, then let object.__new__
                # allocate a proper (pre-headered, GC-tracked, zeroed) heap
                # instance; stamp the immortal refcount and OSP tag the
                # kernel expects of a node it may hold an address to.
                info = None;
                for anc in cls.__mro__[1:] {
                    if bridge_self.kind_of_type.get(anc) is not None {
                        info = bridge_self.layout.get(anc.__name__);
                        break;
                    }
                }
                if info is None {
                    return object.__new__(cls);
                }
                if cls.__basicsize__ < info["size"] {
                    cast(id(cls) + 32, POINTER(c_ssize_t))[0] = info["size"];
                    if cls.__basicsize__ != info["size"] {
                        raise RuntimeError(f"tp_basicsize poke failed for {repr(cls)}");
                    }
                }
                inst = object.__new__(cls);
                addr = id(inst);
                cast(addr, POINTER(ctypes.c_uint64))[0] = 3221225472;
                if info["tag"] {
                    cast(addr + info["tag_offset"], POINTER(ctypes.c_int64))[0] = (
                        info["tag"]
                    );
                }
                return inst;
            }
            ptr = lib.npy_alloc(k);
            return cast(ptr, py_object).value;
        }
        t.__new__ = staticmethod(__new__);
    }

    # -- graph seam for pass-side edge expressions -------------------------
    def connect(self: NpyBridge, left: any, right: any, edge_cls: any) -> any {
        tag = _stable_tag(edge_cls.__name__);
        lefts = left if isinstance(left, `list) else [left];
        rights = right if isinstance(right, `list) else [right];
        for l in lefts {
            for r in rights {
                self.lib.npy_conn(_addr(l), _addr(r), tag);
            }
        }
        return right;
    }

    def hop(self: NpyBridge, origin: any, direction: int, edge_cls: any) -> list {
        tag = _stable_tag(edge_cls.__name__) if edge_cls is not None else 0;
        d = 2 if direction == 2 else (1 if direction == 1 else 3);
        if d == 3 {
            return (
                `list(self.lib.npy_adj(_addr(origin), tag, 2))
                + `list(self.lib.npy_adj(_addr(origin), tag, 1))
            );
        }
        return self.lib.npy_adj(_addr(origin), tag, d);
    }

    def clear_edges(
        self: NpyBridge, origin: any, direction: int, edge_cls: any
    ) -> bool {
        tag = _stable_tag(edge_cls.__name__);
        if direction in (2, 3) {
            self.lib.npy_role_clear(_addr(origin), 2, tag);
        }
        if direction in (1, 3) {
            self.lib.npy_role_clear(_addr(origin), 1, tag);
        }
        return True;
    }

    def disconnect(
        self: NpyBridge, left: any, right: any, direction: int, edge_cls: any
    ) -> bool {
        tag = _stable_tag(edge_cls.__name__) if edge_cls is not None else 0;
        return bool(self.lib.npy_disconn(_addr(left), _addr(right), direction, tag));
    }
}


# Jac has no global-rebind statement; the singleton lives in a one-slot
# mutable cell (same pattern as npy_unit's NpState holder).
glob _BRIDGE_CELL: list = [];


def bridge -> (NpyBridge | None) {
    return _BRIDGE_CELL[0] if _BRIDGE_CELL else None;
}


def is_native(o: any) -> bool {
    return getattr(`type(o), "__npy_native__", False);
}


def ensure_loaded -> (NpyBridge | None) {
    if _BRIDGE_CELL {
        return _BRIDGE_CELL[0];
    }
    path = os.environ.get("JAC_FRONTEND_LIB", "");
    if not path or not os.path.exists(path) {
        return None;
    }
    if not os.path.exists(path + ".layout.json") {
        return None;
    }
    b = NpyBridge(path);
    _BRIDGE_CELL.append(b);
    return b;
}


# Modules whose classes are rebound as they finish executing.
glob ADOPTED_MODULES: tuple = (
         "jaclang.compiler.frontend.unitree",
         "jaclang.compiler.frontend.srcloc",
         "jaclang.compiler.frontend.parser.tokens",
         "jaclang.compiler.frontend.relations",

     );


"""Meta-importer hook: rebind a just-executed scope module's classes."""
def on_module_exec(module: any) -> None {
    b = ensure_loaded();
    if b is None {
        return;
    }
    if getattr(module, "__name__", "") in ADOPTED_MODULES {
        b.adopt_module(module);
    }
}
