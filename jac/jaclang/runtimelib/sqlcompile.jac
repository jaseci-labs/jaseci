"""GraphQuery -> SQL compiler: whole traversals in one round trip.

The #7855 GraphQuery IR is the front-end; this module is the back-end that
replaces the per-hop planner loop. A query compiles to a plan of segments:
each segment is one SQL statement walking as many consecutive hops as are
fully pushable (typed edge/node dispatch, QPred comparisons on promoted
columns or JSONB); a hop carrying a non-pushable predicate ends its segment
and contributes a residual filter evaluated in Python on materialized
anchors before the next segment continues from the surviving frontier.

All SQL executes on the Session's open transaction, after the read barrier,
so uncommitted local mutations are visible by construction.
"""

import logging;
import from typing { Any }
import from uuid { UUID }

import from jaclang.jac0core.graph_query { GraphQuery, QHop, QPred }

glob logger = logging.getLogger(__name__),
     __all__ = ['CompiledPlan', 'PlanSegment', 'compile_query'];


obj PlanSegment {
    """One executable step: SQL over >=1 consecutive hops, then residuals."""
    has sql: str = '',
        params: list = [],
        hop_span: int = 1,
        want_edges: bool = False,
        residual_hop: (QHop | None) = None;
}


obj CompiledPlan {
    has segments: list[PlanSegment] = [],
        slc: (Any | None) = None,
        from_visit: bool = False;
}


def compile_query(
    q: GraphQuery, promotions: dict[str, list[str]], edges: bool = False
) -> CompiledPlan;

def pushable(pred: QPred) -> bool;

def pred_sql(
    alias: str, pred: QPred, params: list, promotions: dict[str, list[str]]
) -> str;
