"""GraphQuery -> SQL compiler: whole traversals in one round trip.

The #7855 GraphQuery IR is the front-end; this module is the back-end that
replaces the per-hop planner loop. A query compiles to one SQL statement
joining the anchors table once per hop — edge dispatch, node dispatch,
predicate filters (jsonb-typed, so numbers compare numerically), only-id
narrowing, and deterministic edge-id ordering all execute inside the
Session's open transaction, after the read barrier, so uncommitted local
mutations are visible by construction.

Every QPred value is a SCALAR (or list of scalars) by IR contract, so every
hop is pushable; compile_query still reports `residual` hops defensively —
a hop whose predicate value defies SQL encoding is left for Python
evaluation on the materialized frontier.
"""

import logging;
import from typing { Any }
import from uuid { UUID }

import from jaclang.jac0core.graph_query { GraphQuery, QHop, QPred }

glob logger = logging.getLogger(__name__),
     __all__ = ['CompiledQuery', 'compile_query'];


obj CompiledQuery {
    """One SQL statement resolving the whole hop chain.

    Row shape: (final_node_id, last_edge_id) — ordered by the edge-id chain
    for determinism. `residual` maps hop index -> preds to re-check in
    Python (normally empty).
    """
    has sql: str = '',
        params: dict = {},
        residual: dict[int, list[QPred]] = {};
}


def compile_query(q: GraphQuery, upto: int) -> CompiledQuery;
