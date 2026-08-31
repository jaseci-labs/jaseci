"""Schema installer for the native unitree store (issue #8789, full break).

Runs once, at the end of ``unitree.jac``'s module execution — before any parse
can create a node — and converts every IR archetype in place:

- every plain dataclass field whose annotation provably maps to a store slot
  (int, bool, str, IntEnum, or a nullable ref to another IR archetype) is
  replaced by a property reading and writing the node's arena record; fields
  the classifier cannot prove store-safe (unions, lists, dicts, ``any``,
  CodeLocInfo, CodeGenTarget...) stay instance-resident, which is the declared
  fallback for object-shaped state;
- a ``__new__`` installed on the archetype roots allocates the record and
  registers the view in the identity table before ``__init__`` runs, so the
  generated and hand-written inits write through the properties untouched;
- structural and annotation edge classes get ekind ids registered with the
  store and the adjacency provider, and the classes are marked
  ``__jac_store__`` so the runtime seam routes their graph ops.

Ref slots encode ``None`` as 0 and a handle as ``handle + 1``. Enum slots
store ``.value`` and reconstruct through the enum class. Token's payload
fields are the parser-frozen mask; every other slot is pass-writable.
"""

from __future__ import annotations

import dataclasses
from enum import IntEnum

_installed = False

# Populated by install_schema: kind id -> archetype class, and per-class
# default factories for instance-resident fields (dataclass defaults), which
# lazily-materialized views are served through UniNode.__getattr__.
CLS_OF_KIND: dict[int, type] = {}
_RESIDENT_DEFAULTS: dict[type, dict] = {}
_MISSING = object()
NP_TAG = 1 << 62


def _natlib():
    import jaclang.compiler.store.host as host

    return host.frontend_lib()


def materialize_view(handle: int, host) -> object:
    """Create (or fetch) the Python view for a store/native handle.

    Views created here bypass __init__ entirely: payload reads go through the
    installed slot properties, and instance-resident fields are served by the
    __getattr__ defaults until a pass writes them.
    """
    view = host.view_of(handle)
    if view is not None:
        return view
    kind = host.node_kind(handle)
    cls = CLS_OF_KIND.get(kind)
    if cls is None:
        raise RuntimeError(f"jacstore: unknown node kind {kind}")
    obj = object.__new__(cls)
    d = obj.__dict__
    d["_ts"] = handle
    d["_kd"] = kind
    host.set_view(handle, obj)
    return obj


def _resident_default(cls: type, name: str):
    per = _RESIDENT_DEFAULTS.get(cls)
    if per is None:
        return _MISSING
    spec = per.get(name, _MISSING)
    if spec is _MISSING:
        return _MISSING
    kind, payload = spec
    if kind == "factory":
        return payload()
    return payload


def _install_getattr(root: type) -> None:
    def __getattr__(self, name):  # noqa: N807
        val = _resident_default(type(self), name)
        if val is _MISSING:
            raise AttributeError(
                f"{type(self).__name__!r} object has no attribute {name!r}"
            )
        self.__dict__[name] = val
        return val

    root.__getattr__ = __getattr__


def _classify(ann: str, namespace: dict, registry: dict):
    """Return (kind, extra) for an annotation string, or None if the field
    must stay instance-resident. kind in {'int','bool','str','enum','ref'}."""
    text = ann.strip()
    while text.startswith("(") and text.endswith(")"):
        text = text[1:-1].strip()
    parts = [p.strip() for p in text.split("|")]
    nullable = False
    if "None" in parts:
        nullable = True
        parts = [p for p in parts if p != "None"]
    if len(parts) != 1:
        return None
    name = parts[0]
    if name == "str":
        return ("str", nullable)
    if nullable:
        target = namespace.get(name)
        if isinstance(target, type) and target in registry:
            return ("ref", True)
        return None
    if name == "int":
        return ("int", None)
    if name == "bool":
        return ("bool", None)
    target = namespace.get(name)
    if target is None:
        return None
    if isinstance(target, type) and issubclass(target, IntEnum):
        return ("enum", target)
    if isinstance(target, type) and target in registry:
        return ("ref", False)
    return None


def _make_property(name: str, kind: str, extra, idx_by_kind: dict, host):
    if kind == "str":
        nullable = bool(extra)

        def sget(self):
            h = self._ts
            if h & NP_TAG:
                return _natlib().read_field(type(self), name, h & ~NP_TAG)
            raw = host.slot_get(h, idx_by_kind[self._kd])
            if raw == 0:
                return None if nullable else ""
            return host.sid_str(h >> 40, raw - 1)

        def sset(self, value):
            h = self._ts
            if h & NP_TAG:
                _natlib().write_field(type(self), name, h & ~NP_TAG, value)
                return
            if value is None:
                host.slot_set(h, idx_by_kind[self._kd], 0)
                return
            host.slot_set(
                h, idx_by_kind[self._kd],
                host.intern(h >> 40, value) + 1,
            )

        return property(sget, sset)
    if kind == "bool":

        def bget(self):
            h = self._ts
            if h & NP_TAG:
                return _natlib().read_field(type(self), name, h & ~NP_TAG)
            return host.slot_get(h, idx_by_kind[self._kd]) != 0

        def bset(self, value):
            h = self._ts
            if h & NP_TAG:
                _natlib().write_field(type(self), name, h & ~NP_TAG, value)
                return
            host.slot_set(h, idx_by_kind[self._kd], 1 if value else 0)

        return property(bget, bset)
    if kind == "enum":
        enum_cls = extra

        def eget(self):
            h = self._ts
            if h & NP_TAG:
                return _natlib().read_field(type(self), name, h & ~NP_TAG)
            return enum_cls(host.slot_get(h, idx_by_kind[self._kd]))

        def eset(self, value):
            h = self._ts
            if h & NP_TAG:
                _natlib().write_field(type(self), name, h & ~NP_TAG, value)
                return
            host.slot_set(
                h, idx_by_kind[self._kd],
                value.value if isinstance(value, enum_cls) else int(value),
            )

        return property(eget, eset)
    if kind == "ref":

        def rget(self):
            h = self._ts
            if h & NP_TAG:
                d = self.__dict__
                if name in d:
                    return d[name]
                return _natlib().read_field(type(self), name, h & ~NP_TAG)
            v = host.slot_get(h, idx_by_kind[self._kd])
            return host.view_of(v - 1) if v else None

        def rset(self, value):
            h = self._ts
            if h & NP_TAG:
                # Native ref slots hold native pointers; a Python-side rebind
                # (which may target a record node) lives in the view overlay
                # and wins on later reads.
                self.__dict__[name] = value
                return
            host.slot_set(
                h, idx_by_kind[self._kd],
                0 if value is None else value._ts + 1,
            )

        return property(rget, rset)

    def iget(self):
        h = self._ts
        if h & NP_TAG:
            return _natlib().read_field(type(self), name, h & ~NP_TAG)
        return host.slot_get(h, idx_by_kind[self._kd])

    def iset(self, value):
        h = self._ts
        if h & NP_TAG:
            _natlib().write_field(type(self), name, h & ~NP_TAG, value)
            return
        host.slot_set(h, idx_by_kind[self._kd], int(value))

    return property(iget, iset)


def _subclass_tree(cls, out):
    out.append(cls)
    for sub in cls.__subclasses__():
        _subclass_tree(sub, out)
    return out


def install_schema() -> None:
    global _installed
    if _installed:
        return
    _installed = True

    import jaclang.compiler.store.host as host
    import jaclang.compiler.store.provider as provider_mod
    import jaclang.compiler.frontend.unitree as uni
    import jaclang.compiler.frontend.roles as roles
    import jaclang.compiler.frontend.relations as relations
    import jaclang.compiler.frontend.constant as constant
    from jaclang.runtime.archetype import EdgeArchetype

    host.ensure_loaded()

    node_roots = [uni.UniNode, uni.Symbol, relations.Codespace]
    registry: dict[type, int] = {}
    ordered: list[type] = []
    for root in node_roots:
        for cls in _subclass_tree(root, []):
            if cls not in registry:
                registry[cls] = 0
                ordered.append(cls)
    for i, cls in enumerate(ordered):
        registry[cls] = i + 1
        CLS_OF_KIND[i + 1] = cls

    namespace: dict = {}
    namespace.update(vars(constant))
    namespace.update(vars(uni))
    namespace.update(vars(relations))

    # Token payload fields are the parser-frozen slot class.
    token_frozen = {
        "name", "value", "line_no", "end_line",
        "c_start", "c_end", "pos_start", "pos_end",
    }

    # (declaring class, field name) -> (kind, extra, idx_by_kind dict)
    converted: dict[tuple[type, str], tuple] = {}

    for cls in ordered:
        kind_id = registry[cls]
        if not dataclasses.is_dataclass(cls):
            host.register_kind(kind_id, 0, 0, 0, 0)
            continue
        nslots = 0
        frozen_mask = 0
        str_mask = 0
        ref_mask = 0
        is_token = issubclass(cls, uni.Token) if hasattr(uni, "Token") else False
        for f in dataclasses.fields(cls):
            info = None
            owner = None
            for base in cls.__mro__:
                if f.name in getattr(base, "__annotations__", {}):
                    owner = base
                    break
            if owner is None:
                continue
            key = (owner, f.name)
            if key in converted:
                info = converted[key]
            else:
                spec = _classify(str(f.type), namespace, registry)
                if spec is None:
                    continue
                info = (spec[0], spec[1], {})
                converted[key] = info
            idx = nslots
            nslots += 1
            info[2][kind_id] = idx
            if info[0] == "str":
                str_mask |= 1 << idx
            if info[0] == "ref":
                ref_mask |= 1 << idx
            if is_token and f.name in token_frozen:
                frozen_mask |= 1 << idx
        host.register_kind(kind_id, nslots, frozen_mask, str_mask, ref_mask)

    for (owner, fname), (kind, extra, idx_by_kind) in converted.items():
        setattr(owner, fname, _make_property(fname, kind, extra, idx_by_kind, host))

    converted_names = {fname for (_owner, fname) in converted.keys()}
    for cls in ordered:
        if not dataclasses.is_dataclass(cls):
            continue
        per: dict = {}
        for f in dataclasses.fields(cls):
            if f.name in converted_names:
                continue
            if f.default_factory is not dataclasses.MISSING:
                per[f.name] = ("factory", f.default_factory)
            elif f.default is not dataclasses.MISSING:
                per[f.name] = ("value", f.default)
            else:
                ann = str(f.type).lstrip("(").strip()
                if ann.startswith("list"):
                    per[f.name] = ("factory", list)
                elif ann.startswith("dict"):
                    per[f.name] = ("factory", dict)
                elif ann.startswith("set"):
                    per[f.name] = ("factory", set)
                else:
                    per[f.name] = ("value", None)
        _RESIDENT_DEFAULTS[cls] = per

    kind_of = dict(registry)

    def _new(cls, *args, **kwargs):
        obj = object.__new__(cls)
        k = kind_of.get(cls)
        if k is None:
            k = kind_of.get(cls.__mro__[1], 0)
        h = host.node_new(k)
        d = obj.__dict__
        d["_ts"] = h
        d["_kd"] = k
        host.set_view(h, obj)
        return obj

    for root in node_roots:
        root.__new__ = staticmethod(_new)
        _install_getattr(root)

    # loc is built by init from the node's token range and never crosses the
    # boundary as data; rebuild it lazily on first read for views that skipped
    # __init__. Record/bytecode nodes hit the __dict__ fast path their init
    # populated.
    from jaclang.compiler.frontend.srcloc import CodeLocInfo

    def _loc_get(self):
        d = self.__dict__
        v = d.get("loc")
        if v is None:
            first, last = self.resolve_tok_range()
            v = CodeLocInfo(first, last)
            d["loc"] = v
        return v

    def _loc_set(self, value):
        self.__dict__["loc"] = value

    uni.UniNode.loc = property(_loc_get, _loc_set)

    # Shaped-role getters consult _role_shapes, which native init wrote into
    # native memory; route the lookup through the exported reader for
    # native-backed views so "one"/"many"/"none" survive the boundary.
    _orig_role_shaped = uni.UniNode._role_shaped

    def _role_shaped(self, role, found):
        ts = self.__dict__.get("_ts", 0)
        if ts & NP_TAG:
            s = _natlib().role_shape(ts & ~NP_TAG, role.__name__)
            if s == 2:
                return found
            if s == 1:
                return found[0] if found else None
            return None
        return _orig_role_shaped(self, role, found)

    uni.UniNode._role_shaped = _role_shaped

    # _sym_category is a str-enum (no store slot); parse-time bindings live in
    # native memory. Serve them through the exported reader, letting a later
    # Python-side bind_sym overlay win via __dict__.
    from jaclang.compiler.frontend.constant import SymbolType

    def _sym_cat_get(self):
        d = self.__dict__
        if "_sym_category" in d:
            return d["_sym_category"]
        ts = d.get("_ts", 0)
        if ts & NP_TAG:
            v = _natlib().sym_category(ts & ~NP_TAG)
            if v:
                cat = SymbolType(v)
                d["_sym_category"] = cat
                return cat
        return None

    def _sym_cat_set(self, value):
        self.__dict__["_sym_category"] = value

    uni.NameAtom._sym_category = property(_sym_cat_get, _sym_cat_set)

    # SubTag.tag is a plain stored field whose generic annotation kept it out
    # of the slot table; bridge it through the exported reader with the same
    # __dict__-overlay-wins contract.
    def _tag_get(self):
        d = self.__dict__
        if "tag" in d:
            return d["tag"]
        ts = d.get("_ts", 0)
        if ts & NP_TAG:
            v = _natlib().subtag_tag(ts & ~NP_TAG)
            d["tag"] = v
            return v
        raise AttributeError("tag")

    def _tag_set(self, value):
        self.__dict__["tag"] = value

    uni.SubTag.tag = property(_tag_get, _tag_set)

    for cls in ordered:
        cls.__jac_store__ = True

    ekind = 0
    struct_roots = [roles.Kid, roles.Role, roles.ImplOf]
    seen_edges: set[type] = set()
    for root in struct_roots:
        for ecls in _subclass_tree(root, []):
            if ecls in seen_edges:
                continue
            seen_edges.add(ecls)
            ekind += 1
            provider_mod.register_edge(ecls, ekind, True)
    annotation_edges = [
        "SymOf", "Defines", "Uses", "InScope", "ScopePrimary", "ScopeOverload",
        "ScopeChild", "ScopeParent", "CfgSucc", "CfgTrue", "CfgFalse",
        "PlacedIn", "DecidedCodespace", "CalleeDecl", "Absorbs",
        "AttachedComment",
    ]
    for ename in annotation_edges:
        ecls = getattr(relations, ename, None)
        if ecls is None or not issubclass(ecls, EdgeArchetype):
            continue
        if ecls in seen_edges:
            continue
        seen_edges.add(ecls)
        ekind += 1
        provider_mod.register_edge(ecls, ekind, False)

    provider_mod.install()
