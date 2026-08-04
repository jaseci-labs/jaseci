import logging;
import os;
import from typing { cast }
import from uuid { UUID }
import from jaclang.jac0core.archetype { Anchor, EdgeAnchor, NodeAnchor }
import from jaclang.jac0core.graph_query { GraphQuery, QHop, QPred }
import from jaclang.runtimelib.memory { Memory }

glob logger = logging.getLogger(__name__),
     __all__ = ['resolve_query', 'resolve_query_edges', 'resolve_query_prefix'];


obj _View {
    has fresh: list[EdgeAnchor] = [],
        detached: set[UUID] = set(),
        live_nodes: dict[UUID, NodeAnchor] = {},
        live_edges: dict[UUID, EdgeAnchor] = {},
        probed: set[UUID] = set(),
        proj: any = None,
        epred_ok: set[UUID] = set();
}


def _projection_for(mem: Memory) -> any;


def _page_rows(
    view: _View, nid: UUID, page: dict, hop: QHop
) -> (list[tuple[UUID, UUID]] | None);


def _heal_sweep(
    mem: Memory, view: _View, nanch: NodeAnchor, engine_eids: set[UUID]
) -> None;


def _trace_enabled -> bool;


def _build_view(mem: Memory, q: GraphQuery) -> _View;


def _edge_alive(ea: EdgeAnchor) -> bool;


def _live_row(ea: EdgeAnchor, cur: set[UUID], hop: QHop) -> (tuple[UUID, UUID] | None);


def _node_pred_keep(
    mem: Memory, view: _View, ids: list[UUID], preds: list[QPred]
) -> list[UUID];


def _edge_pred_keep(
    mem: Memory, view: _View, rows: list[tuple[UUID, UUID]], epreds: list[QPred]
) -> list[tuple[UUID, UUID]];


def _hop_once(
    mem: Memory, view: _View, cur: list[UUID], hop: QHop, hop_idx: int
) -> list[UUID];


def _resolve_ids(mem: Memory, view: _View, q: GraphQuery, upto: int) -> list[UUID];


def _materialize(mem: Memory, view: _View, ids: list[UUID]) -> list[Anchor];


def _verify_last_hop(anchor: Anchor, hop: QHop) -> bool;


def resolve_query_prefix(mem: Memory, q: GraphQuery, upto: int) -> list[UUID];


def resolve_query(mem: Memory, q: GraphQuery) -> list[Anchor];


def resolve_query_edges(mem: Memory, q: GraphQuery) -> list[Anchor];
