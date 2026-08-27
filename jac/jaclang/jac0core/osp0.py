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
    return _rt().connect(left=left, right=right, edge=edge, conn_assign=conn_assign)


def disconnect0(left: Any, right: Any, dir: int = 2) -> bool:
    from jaclang.compiler.frontend.constant import EdgeDir

    return _rt().disconnect(left=left, right=right, dir=EdgeDir(dir))


def refs0(origin: Any, dir: int, edge: Any = None, edges_only: bool = False) -> list:
    from jaclang.runtime.graph_query import GraphQuery, QHop

    return _rt().refs(
        GraphQuery(origin, hops=[QHop(dir=dir, edge=edge)], edges_only=edges_only)
    )


def spawn0(op1: Any, op2: Any) -> Any:
    return _rt().spawn(op1, op2)


def visit0(walker: Any, expr: Any) -> bool:
    return _rt().visit(walker, expr)


def disengage0(walker: Any) -> bool:
    return _rt().disengage(walker)


def destroy0(obj: Any) -> None:
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
