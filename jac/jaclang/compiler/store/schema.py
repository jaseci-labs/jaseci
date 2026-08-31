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
            raw = host.slot_get(self._ts, idx_by_kind[self._kd])
            if raw == 0:
                return None if nullable else ""
            return host.sid_str(self._ts >> 40, raw - 1)

        def sset(self, value):
            if value is None:
                host.slot_set(self._ts, idx_by_kind[self._kd], 0)
                return
            host.slot_set(
                self._ts, idx_by_kind[self._kd],
                host.intern(self._ts >> 40, value) + 1,
            )

        return property(sget, sset)
    if kind == "bool":

        def bget(self):
            return host.slot_get(self._ts, idx_by_kind[self._kd]) != 0

        def bset(self, value):
            host.slot_set(self._ts, idx_by_kind[self._kd], 1 if value else 0)

        return property(bget, bset)
    if kind == "enum":
        enum_cls = extra

        def eget(self):
            return enum_cls(host.slot_get(self._ts, idx_by_kind[self._kd]))

        def eset(self, value):
            host.slot_set(
                self._ts, idx_by_kind[self._kd],
                value.value if isinstance(value, enum_cls) else int(value),
            )

        return property(eget, eset)
    if kind == "ref":

        def rget(self):
            v = host.slot_get(self._ts, idx_by_kind[self._kd])
            return host.view_of(v - 1) if v else None

        def rset(self, value):
            host.slot_set(
                self._ts, idx_by_kind[self._kd],
                0 if value is None else value._ts + 1,
            )

        return property(rget, rset)

    def iget(self):
        return host.slot_get(self._ts, idx_by_kind[self._kd])

    def iset(self, value):
        host.slot_set(self._ts, idx_by_kind[self._kd], int(value))

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
