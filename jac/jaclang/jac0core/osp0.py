"""The object-spatial surface the jac0 seed tier lowers to.

jac0 rewrites `node`/`edge`/`walker` declarations, `+>:T:+>`, `[x ->:T:->]`,
`spawn`, `visit`, `disengage`, `del` and `can f with T entry|exit` into calls
on this module. Every helper reaches the same `JacRuntimeInterface` statics
the full compiler's codegen targets, so a seed module and a full-compiler
module share one kernel and one semantics. The runtime is imported lazily:
the seed tier's own modules (the unitree, the parser) define archetypes at
import time, before the runtime package is importable without cycles.
"""

from __future__ import annotations

from typing import Any, Callable

from jaclang.runtime.archetype import (
    EdgeArchetype as Edge,
    NodeArchetype as Node,
    WalkerArchetype as Walker,
)

__all__ = [
    "Node",
    "Edge",
    "Walker",
    "connect0",
    "disconnect0",
    "refs0",
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

    Seed-tier graphs are transient compiler graphs; their edges live only in
    the two anchors' edge lists, which is what `refs0` reads. Nothing here
    pins an anchor in a registry, so a released module is collectable.
    """
    from jaclang.runtime.archetype import EdgeAnchor, GenericEdge

    lefts = left if isinstance(left, list) else [left]
    rights = right if isinstance(right, list) else [right]
    ct = edge or GenericEdge
    for l_arch in lefts:
        src = l_arch.__jac__
        for r_arch in rights:
            tgt = r_arch.__jac__
            e = ct() if isinstance(ct, type) else ct
            e.__jac__ = EdgeAnchor(archetype=e, source=src, target=tgt, is_undirected=False)
            src.edges.append(e.__jac__)
            tgt.edges.append(e.__jac__)
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


def refs0(
    origin: Any,
    dir: int,
    edge: Any = None,
    edges_only: bool = False,
    preds: tuple | None = None,
    target: Any = None,
) -> list:
    """One hop over the kernel's adjacency, without the persistence planner.

    dir: 1 = in, 2 = out, 3 = any. `edge` filters by edge class (subclasses
    included), `preds` are (attr, op, value) edge-attribute predicates and
    `target` restricts the far end to one node. Results keep the order the
    edges were connected in, deduplicated. Origins may be a node or a list.
    """
    origins = origin if isinstance(origin, list) else [origin]
    out: list = []
    seen: set = set()
    tgt_anchor = target.__jac__ if target is not None else None
    for o in origins:
        me = o.__jac__
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


def spawn0(op1: Any, op2: Any) -> Any:
    return _rt().spawn(op1, op2)


def visit0(walker: Any, expr: Any, insert_loc: int = -1) -> bool:
    return _rt().visit(walker, expr, insert_loc)


def disengage0(walker: Any) -> bool:
    return _rt().disengage(walker)


def destroy0(obj: Any) -> None:
    if isinstance(obj, Edge):
        anchor = obj.__jac__
        if not anchor.persistent:
            anchor.source.remove_edge(anchor)
            anchor.target.remove_edge(anchor)
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
