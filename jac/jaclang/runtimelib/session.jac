"""Session: per-request graph workspace over one Store transaction.

The Session replaces the l1/l2/l3 TieredMemory + ChangeSet stack. It keeps a
Python identity map (one live anchor object per id) and write-buffers dirty
anchors, but truth lives in the Store transaction: every graph read flushes
pending writes first (read barrier), so traversals inside a request observe
uncommitted attaches, detaches, and destroys natively (fixes the #7937 class).

Store resolution: an injected Store wins; otherwise a base path gets the
embedded Postgres runtime (JAC_DB_URL points at an external server instead);
no base path means a purely in-memory session (volatile semantics).

Request lifecycle: run_request() opens a SERIALIZABLE transaction, runs the
walker/entry body, commits, and re-runs the body on serialization conflict.
Callbacks registered via on_commit() fire exactly once, after a successful
commit — the sanctioned home for external side effects under retry.
"""

import logging;
import os;
import from collections.abc { Callable, Generator, Iterable }
import from typing { Any }
import from uuid { UUID }

import from jaclang.jac0core.archetype { Anchor, EdgeAnchor, NodeAnchor, Root }
import from jaclang.runtimelib.store { AnchorRow, ConnInfo, PgStore, Store }

glob logger = logging.getLogger(__name__),
     MAX_RETRIES = 5,
     __all__ = ['Session', 'promotions_for', 'conninfo_from_url'];


def promotions_for(base_path: (str | None)) -> dict[str, list[str]];
def conninfo_from_url(url: str) -> ConnInfo;


obj Session {
    """Implements the Memory facade the runtime calls (put/get/delete/commit/
    get_mem/get_roots/...), backed by identity map + Store transaction."""
    has store: (Store | None) = None,
        base_path: (str | None) = None,
        target_path: (str | None) = None,
        __mem__: dict[UUID, Anchor] postinit,
        _dirty: set[UUID] postinit,
        _deleted: set[UUID] postinit,
        _flushed_hash: dict[UUID, int] postinit,
        _on_commit: list[Callable] postinit,
        _runtime: (Any | None) postinit;

    def postinit -> None;
    # -- Memory facade (contract the runtime already depends on) --
    def is_available -> bool;
    def get(id: UUID) -> (Anchor | None);
    def put(anchor: Anchor) -> None;
    def delete(id: UUID) -> None;
    def close -> None;
    def `has(id: UUID) -> bool;
    def query(
        filter: (Callable[[Anchor], bool] | None) = None
    ) -> Generator[Anchor, None, None];

    def get_roots -> Generator[Root, None, None];
    def find(
        ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> Generator[Anchor, None, None];

    def find_one(
        ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
    ) -> (Anchor | None);

    def commit(anchor: (Anchor | None) = None) -> None;
    def abort -> None;
    def get_mem -> dict[UUID, Anchor];
    def batch_get(ids: list[UUID]) -> dict[UUID, Anchor];
    def quarantine_ref(referrer: (Anchor | None), stub: Anchor) -> None;
    def is_recoverable_quarantine(id: UUID) -> bool;
    async def aget(id: UUID) -> (Anchor | None);
    async def aput(anchor: Anchor) -> None;
    async def adelete(id: UUID) -> None;
    async def ahas(id: UUID) -> bool;
    async def acommit(anchor: (Anchor | None) = None) -> None;
    # -- transaction lifecycle --
    def run_request(body: Callable) -> Any;
    def on_commit(callback: Callable) -> None;
    def flush(full: bool = False) -> None;
    def read_barrier -> None;
    # -- internals --
    def _ensure_txn -> None;
    def _materialize(row: AnchorRow) -> (Anchor | None);
    def _serialize(anchor: Anchor) -> AnchorRow;
    def _fire_on_commit -> None;
    def _evict_uncommitted -> None;
}
