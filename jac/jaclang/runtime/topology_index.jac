"""Transient topology index used by TTG planning.

This index is intentionally session-local. It is rebuilt from committed rows
and is never serialized onto root anchors.
"""

import from uuid { UUID }

glob __all__ = [
         'TopologyEdge',
         'TopologyIndex',
         'warm_topology_for_nodes'
     ];


obj TopologyEdge {
    has id: UUID,
        src: UUID,
        dst: UUID,
        edge_type: str = "",
        undirected: bool = False;
}


obj TopologyIndex {
    has node_types: dict[UUID, str] = {},
        node_owners: dict[UUID, UUID] = {},
        type_ancestors: dict[str, set[str]] = {},
        out_by_src: dict[UUID, list[TopologyEdge]] = {},
        in_by_dst: dict[UUID, list[TopologyEdge]] = {},
        edge_ids: set[UUID] = set(),
        loaded_roots: set[UUID] = set();

    def clear -> None;
    def add_type(type_name: str, ancestors: list[str]) -> None;
    def add_node(
        node_id: UUID,
        type_name: str,
        ancestors: list[str],
        owner_root: (UUID | None) = None
    ) -> None;

    def add_edge(
        edge_id: UUID,
        src: UUID,
        dst: UUID,
        edge_type: str,
        ancestors: list[str],
        undirected: bool = False
    ) -> None;

    def mark_roots_loaded(root_ids: list[UUID]) -> None;
    def has_root(root_id: UUID) -> bool;
    def node_type(node_id: UUID) -> (str | None);
    def owner_root_for(node_id: UUID) -> (UUID | None);
    def resolve_chain(
        origin_ids: list[UUID],
        chain: list[tuple[str | None, str | None, int]],
        limit: int = 0
    ) -> list[UUID];
    def __len__ -> int;
}


def warm_topology_for_nodes(mem: any, node_ids: list[UUID]) -> TopologyIndex;
