"""Graph query resolution over the pg-native Session (epic #7945).

Two execution paths, split per origin:

- persistent origins with a Store: the whole hop chain compiles to one SQL
  statement (sqlcompile) executed on the Session's open transaction after
  the read barrier — uncommitted attaches, detaches, and destroys are
  visible because they are already IN the transaction, not simulated by an
  overlay.
- volatile origins (or storeless sessions): a direct walk of the live
  anchor objects. Mixed chains cannot exist: persistence cascades on
  attach, so a persistent frontier never reaches a volatile anchor.
"""

import logging;
import from typing { Any }
import from uuid { UUID }
import from jaclang.jac0core.archetype { Anchor, EdgeAnchor, NodeAnchor }
import from jaclang.jac0core.graph_query { GraphQuery, QHop, QPred }
import from jaclang.runtimelib.session { Session }
import from jaclang.runtimelib.sqlcompile { compile_query }

glob logger = logging.getLogger(__name__),
     __all__ = ['resolve_query', 'resolve_query_edges', 'resolve_query_prefix'];


def _origin_anchors(q: GraphQuery) -> list[Anchor];


def _sql_pairs(
    mem: Session, origin_ids: list[UUID], q: GraphQuery, upto: int
) -> list[tuple[(UUID | None), (UUID | None)]];


def _edge_pair_for(
    e: EdgeAnchor, cur: Anchor, hop: QHop
) -> (Anchor | None);


def _walk_memory(
    origins: list[Anchor], q: GraphQuery, upto: int
) -> list[tuple[Anchor, (EdgeAnchor | None)]];


def _hop_matches_node(anchor: Anchor, hop: QHop) -> bool;


def resolve_query_prefix(mem: Session, q: GraphQuery, upto: int) -> list[UUID];


def resolve_query(mem: Session, q: GraphQuery) -> list[Anchor];


def resolve_query_edges(mem: Session, q: GraphQuery) -> list[Anchor];
