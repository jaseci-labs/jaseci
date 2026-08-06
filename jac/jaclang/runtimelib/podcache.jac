"""Per-pod cache: payload hydration only, never truth.

Cross-request LRU of deserialized anchor payloads keyed by id. Correctness
invariant (epic #7945): topology, existence, and row versions always come
from the Session's transaction snapshot; the cache is consulted only when
the version observed inside the transaction matches the cached row's
version. LISTEN/NOTIFY on the invalidation channel is eviction-only —
a lost or late notification can never produce a stale read, only a refetch.
"""

import logging;
import threading;
import from collections { OrderedDict }
import from typing { Any }
import from uuid { UUID }

glob logger = logging.getLogger(__name__),
     INVALIDATION_CHANNEL = 'jac_anchor_inval',
     DEFAULT_CAPACITY = 4096,
     __all__ = ['PodCache', 'INVALIDATION_CHANNEL'];


obj PodCache {
    has capacity: int = DEFAULT_CAPACITY,
        _rows: OrderedDict postinit,
        _lock: threading.RLock postinit,
        hits: int postinit,
        misses: int postinit;

    def postinit -> None;
    def get(id: UUID, version: int) -> (Any | None);
    def put(id: UUID, version: int, payload: Any) -> None;
    def invalidate(id: UUID) -> None;
    def invalidate_payload(payload: str) -> None;
    def clear -> None;
}
