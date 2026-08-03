import logging;
import os;
import from uuid { UUID }
import from jaclang.jac0core.archetype { Anchor, EdgeAnchor, NodeAnchor }
import from jaclang.jac0core.graph_query { GraphQuery, QHop, QPred }
import from jaclang.runtimelib.memory { Memory }

glob logger = logging.getLogger(__name__),
     __all__ = ['resolve_query', 'resolve_query_edges', 'resolve_query_prefix'];


obj _Overlay {
    has fresh: list[EdgeAnchor] = [],
        fresh_ids: set[UUID] = set(),
        detached: set[UUID] = set();
}


def _trace_enabled -> bool;


def _build_overlay(mem: Memory) -> _Overlay;


def _edge_alive(ea: EdgeAnchor) -> bool;


def _live_row(ea: EdgeAnchor, cur: set[UUID], hop: QHop) -> (tuple[UUID, UUID] | None);


def _node_pred_keep(mem: Memory, ids: list[UUID], preds: list[QPred]) -> list[UUID];


def _edge_pred_keep(
    mem: Memory, rows: list[tuple[UUID, UUID]], overlay: _Overlay, epreds: list[QPred]
) -> list[tuple[UUID, UUID]];


def _hop_once(
    mem: Memory, overlay: _Overlay, cur: list[UUID], hop: QHop, hop_idx: int
) -> list[UUID];


def _materialize(mem: Memory, ids: list[UUID]) -> list[Anchor];


def _verify_last_hop(anchor: Anchor, hop: QHop) -> bool;


def resolve_query_prefix(mem: Memory, q: GraphQuery, upto: int) -> list[UUID];


def resolve_query(mem: Memory, q: GraphQuery) -> list[Anchor];


def resolve_query_edges(mem: Memory, q: GraphQuery) -> list[Anchor];
