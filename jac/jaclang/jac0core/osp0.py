"""The object-spatial surface the jac0 seed tier lowers to.

jac0 rewrites `node`/`edge`/`walker` declarations, `+>:T:+>`, `[x ->:T:->]`,
`spawn`, `visit`, `disengage`, `del` and `can f with T entry|exit` into calls
on this module. Every helper reaches the same `JacRuntimeInterface` statics
the full compiler's codegen targets, so a seed module and a full-compiler
module share one kernel and one semantics. The runtime is imported lazily:
the seed tier's own modules (the unitree, the parser) define archetypes at
import time, before the runtime package is importable without cycles.

Seed-tier graphs are transient compiler graphs. A field-less directed edge is
a light edge: an entry in the anchors' per-type adjacency (`out_light` /
`in_light`), no edge object, no kernel row, no context. `refs0` reads that
adjacency directly; only edges that carry fields (or attribute assignment at
connect time) become EdgeAnchors in `edges`.
"""

from __future__ import annotations

from typing import Any, Callable

from jaclang.runtime.archetype import (
    _edge_subtypes as _SUBTYPES,
    EdgeAnchor,
    EdgeArchetype as Edge,
    GenericEdge,
    NodeArchetype as Node,
    WalkerArchetype as Walker,
    edge_subtypes,
    is_light_edge_type,
    light_clear_matching,
    light_connect,
    light_edge_views,
    light_in,
    light_out,
)

__all__ = [
    "Node",
    "Edge",
    "Walker",
    "connect0",
    "disconnect0",
    "refs0",
    "hop0",
    "clear0",
    "spawn0",
    "visit0",
    "disengage0",
    "destroy0",
    "on_entry",
    "on_exit",
    "set_trigger",
]

_ARCH = (Node, Edge, Walker)


def _rt() -> Any:
    from jaclang.runtime.runtime import JacRuntimeInterface

    return JacRuntimeInterface


def connect0(
    left: Any,
    right: Any,
    edge: Any = None,
    conn_assign: tuple[tuple, tuple] | None = None,
) -> Any:
    """Connect in the anchor adjacency: no kernel row, no handle, no context.

    A light edge type (no fields, no attribute assignment) is recorded as an
    adjacency entry on both anchors. Anything else is an EdgeAnchor in the two
    anchors' edge lists. Nothing here pins an anchor in a registry, so a
    released module is collectable.
    """
    lefts = left if isinstance(left, list) else [left]
    rights = right if isinstance(right, list) else [right]
    ct = edge or GenericEdge
    cls = ct if isinstance(ct, type) else type(ct)
    light = conn_assign is None and is_light_edge_type(cls)
    for l_arch in lefts:
        src = l_arch.__jac__
        for r_arch in rights:
            tgt = r_arch.__jac__
            if light and not (src.persistent or tgt.persistent):
                light_connect(src, cls, tgt)
                continue
            e = ct() if isinstance(ct, type) else ct
            e.__jac__ = EdgeAnchor(archetype=e, source=src, target=tgt, is_undirected=False)
            src.edges.append(e.__jac__)
            tgt.edges.append(e.__jac__)
            if is_light_edge_type(cls):
                src.mixed = True
                tgt.mixed = True
            if conn_assign:
                for fld, val in zip(conn_assign[0], conn_assign[1], strict=False):
                    setattr(e, fld, val)
    return right


def disconnect0(left: Any, right: Any, dir: int = 2) -> bool:
    from jaclang.compiler.frontend.constant import EdgeDir

    return _rt().disconnect(left=left, right=right, dir=EdgeDir(dir))


def _pred_ok(arch: Any, preds: tuple | None) -> bool:
    if not preds:
        return True
    for name, op, value in preds:
        cur = getattr(arch, name, None)
        if op == "==":
            if not (cur == value):
                return False
        elif op == "!=":
            if not (cur != value):
                return False
        elif op == "<":
            if not (cur < value):
                return False
        elif op == "<=":
            if not (cur <= value):
                return False
        elif op == ">":
            if not (cur > value):
                return False
        elif op == ">=":
            if not (cur >= value):
                return False
        else:
            raise ValueError(f"unsupported edge predicate operator {op!r}")
    return True


def _light_hits(
    me: Any,
    edge: Any,
    outgoing: bool,
    edges_only: bool,
    tgt_anchor: Any,
    out: list,
    seen: set,
) -> None:
    if edges_only:
        for ea in light_edge_views(me, edge, outgoing):
            other = ea.target if outgoing else ea.source
            if tgt_anchor is not None and other is not tgt_anchor:
                continue
            out.append(ea.archetype)
        return
    for arch in light_out(me, edge) if outgoing else light_in(me, edge):
        if tgt_anchor is not None and arch.__jac__ is not tgt_anchor:
            continue
        k = id(arch)
        if k in seen:
            continue
        seen.add(k)
        out.append(arch)


def refs0(
    origin: Any,
    dir: int,
    edge: Any = None,
    edges_only: bool = False,
    preds: tuple | None = None,
    target: Any = None,
) -> list:
    """One hop over the anchors' adjacency, without the persistence planner.

    dir: 1 = in, 2 = out, 3 = any. `edge` filters by edge class (subclasses
    included), `preds` are (attr, op, value) edge-attribute predicates and
    `target` restricts the far end to one node. Light edges are read from the
    per-type adjacency (a predicate can never match a field-less edge, so a
    query with `preds` skips them); EdgeAnchors are scanned. Results keep
    connection order within each tier, deduplicated.
    """
    origins = origin if isinstance(origin, list) else [origin]
    out: list = []
    seen: set = set()
    tgt_anchor = target.__jac__ if target is not None else None
    for o in origins:
        me = o.__jac__
        if not preds:
            if dir != 1 and me.out_light:
                _light_hits(me, edge, True, edges_only, tgt_anchor, out, seen)
            if dir != 2 and me.in_light:
                _light_hits(me, edge, False, edges_only, tgt_anchor, out, seen)
        for ea in me.edges:
            arch = ea.archetype
            if edge is not None and not isinstance(arch, edge):
                continue
            if ea.source is me:
                if dir == 1 and not ea.is_undirected:
                    continue
                other = ea.target
            elif ea.target is me:
                if dir == 2 and not ea.is_undirected:
                    continue
                other = ea.source
            else:
                continue
            if tgt_anchor is not None and other is not tgt_anchor:
                continue
            if not _pred_ok(arch, preds):
                continue
            item = arch if edges_only else other.archetype
            if id(item) in seen:
                continue
            seen.add(id(item))
            out.append(item)
    return out


def hop0(origin: Any, dir: int, edge: Any = None, edges_only: bool = False) -> list:
    """The simple hop: one origin, one direction, one edge class, no filters.

    jac0 lowers `[x ->:T:->]` / `[x <-:T:<-]` / `[x -->]` here when the hop
    carries no predicate, node filter or chain. A light edge class can only
    live in the light tier of a transient node, so a typed light hop is one
    dict lookup even on a node that also holds EdgeAnchors of other types;
    an untyped hop, a heavy type or a persistent origin takes `refs0`.
    Returns a fresh, order-preserving, deduplicated list.
    """
    if isinstance(origin, list):
        return refs0(origin, dir, edge, edges_only)
    me = origin.__jac__
    if me.edges and (
        edge is None or me.persistent or me.mixed or not is_light_edge_type(edge)
    ):
        return refs0(origin, dir, edge, edges_only)
    if edges_only:
        out: list = []
        if dir != 1:
            out.extend(ea.archetype for ea in light_edge_views(me, edge, True))
        if dir != 2:
            out.extend(ea.archetype for ea in light_edge_views(me, edge, False))
        return out
    if edge is None or len(_SUBTYPES.get(edge) or edge_subtypes(edge)) != 1:
        if dir == 2:
            found = light_out(me, edge)
        elif dir == 1:
            found = light_in(me, edge)
        else:
            found = light_out(me, edge) + light_in(me, edge)
    else:
        # exact class, no subclasses: the common case, no helper frames
        found = []
        if dir != 1:
            d = me.out_light
            lst = d.get(edge) if d else None
            if lst:
                found = lst if dir == 2 else list(lst)
        if dir != 2:
            d = me.in_light
            lst = d.get(edge) if d else None
            if lst:
                hits = [a for a in (r() for r in lst) if a is not None]
                found = hits if dir == 1 else found + hits
    if len(found) < 2:
        return list(found)
    return list(dict.fromkeys(found))


def clear0(origin: Any, dir: int, edge: Any = None) -> bool:
    """`del [edge x ->:T:->];`: drop every edge of the set without building it.

    Light edges are popped from the adjacency by class; EdgeAnchors of the
    set are detached one by one (destroyed, if persistent).
    """
    origins = origin if isinstance(origin, list) else [origin]
    hit = False
    for o in origins:
        me = o.__jac__
        if dir != 1 and light_clear_matching(me, edge, True):
            hit = True
        if dir != 2 and light_clear_matching(me, edge, False):
            hit = True
        for ea in list(me.edges):
            if edge is not None and not isinstance(ea.archetype, edge):
                continue
            if dir == 2 and not (ea.source is me or ea.is_undirected):
                continue
            if dir == 1 and not (ea.target is me or ea.is_undirected):
                continue
            destroy0(ea.archetype)
            hit = True
    return hit


def spawn0(op1: Any, op2: Any) -> Any:
    return _rt().spawn(op1, op2)


def visit0(walker: Any, expr: Any, insert_loc: int = -1) -> bool:
    return _rt().visit(walker, expr, insert_loc)


def disengage0(walker: Any) -> bool:
    return _rt().disengage(walker)


def destroy0(obj: Any) -> None:
    if isinstance(obj, list):
        # an edge set from `del [edge ...]`; a plain `del d[k]` also lands
        # here with whatever the subscript held, so only edges are consumed
        for item in obj:
            if isinstance(item, Edge):
                destroy0(item)
        return
    if isinstance(obj, Edge):
        anchor = obj.__jac__
        if anchor.light or not anchor.persistent:
            anchor.detach()
            return
    if isinstance(obj, _ARCH):
        _rt().destroy(obj)


def on_entry(func: Callable) -> Callable:
    setattr(func, "__jac_entry", True)
    return func


def on_exit(func: Callable) -> Callable:
    setattr(func, "__jac_exit", True)
    return func


def set_trigger(trigger_thunk: Callable) -> Callable[[Callable], Callable]:
    def deco(func: Callable) -> Callable:
        setattr(func, "__jac_trigger__", trigger_thunk)
        return func

    return deco
