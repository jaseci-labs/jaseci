import os;
import time;
import from uuid { UUID }

glob _REGISTRY: dict[str, Projection] = {},
     _DEF_TTL: float = float(os.environ.get('JAC_PROJECTION_TTL', '10.0')),
     _DEF_CAP: int = int(os.environ.get('JAC_PROJECTION_WARM_CAP', '512')),
     _ENABLED: bool = os.environ.get('JAC_PROJECTION', '1').lower()
         not in ('0', 'false', 'off'),
     __all__ = ['Projection', 'get_projection', 'evict_everywhere', 'clear_all'];


obj Projection {
    has pages: dict[UUID, dict] = {},
        summaries: dict[UUID, tuple] = {},
        stamps: dict[UUID, float] = {},
        ttl_s: float = _DEF_TTL,
        warm_cap: int = _DEF_CAP,
        hits: int = 0,
        faults: int = 0;

    def fresh_page(id: UUID) -> (dict | None);
    def summary_of(id: UUID) -> (tuple | None);
    def absorb(pages: dict[UUID, dict]) -> None;
    def evict(id: UUID) -> None;
    def clear -> None;
}


def get_projection(key: str) -> Projection;


def evict_everywhere(id: UUID) -> None;


def clear_all -> None;


def projection_enabled -> bool;
