"""Store: the single durable source of truth for the Jac graph.

One Postgres database (embedded locally, provisioned at scale) holds nodes,
edges, shared KV state, and quarantine records. Every Session owns exactly one
Store transaction at a time; all graph reads and writes happen inside it, so
read-your-writes, aborts, and conflict detection are the engine's job — the
runtime never simulates them (epic #7945).
"""

import logging;
import os;
import threading;
import from collections.abc { Generator, Iterable }
import from typing { Any }
import from uuid { UUID }

import from jaclang.jac0core.archetype { Anchor, NodeAnchor, Root }

glob logger = logging.getLogger(__name__),
     SCHEMA_VERSION = 1,
     __all__ = ['AnchorRow', 'Store', 'PgStore', 'ConnInfo', 'SCHEMA_VERSION'];


obj ConnInfo {
    """Where and how to reach a Postgres server."""
    has host: str = '',
        port: int = 5432,
        user: str = 'jac',
        password: str = '',
        database: str = 'jac',
        unix_socket_dir: (str | None) = None;

    def dsn -> str;
}


obj AnchorRow {
    """Wire/row form of one anchor: identity + payload + snapshot version.

    `version` is the row's xmin at read time: the cache may serve `props`
    for an id only when the version observed inside the current transaction
    matches (cache short-circuits hydration, never truth).
    """
    has id: UUID,
        kind: str,
        arch_type: str,
        arch_module: str,
        root_id: (UUID | None),
        props: dict,
        src: (UUID | None) = None,
        dst: (UUID | None) = None,
        undirected: bool = False,
        version: int = 0;
}


obj Store {
    """Narrow engine contract. Implementations own connections and DDL.

    All row-level methods run inside the currently open transaction; callers
    (the Session) own transaction lifecycle via begin/commit/rollback.
    """
    def is_available -> bool abst;

    def server_version -> int abst;
    def ensure_schema(promotions: dict[str, list[str]]) -> None abst;
    def begin(serializable: bool = True) -> None abst;
    def commit -> None abst;
    def rollback -> None abst;
    def in_txn -> bool abst;
    def load(ids: list[UUID]) -> dict[UUID, AnchorRow] abst;
    def upsert(rows: list[AnchorRow]) -> None abst;
    def delete(ids: list[UUID]) -> None abst;
    def existing(ids: list[UUID]) -> set[UUID] abst;
    def root_ids -> list[UUID] abst;
    def rows(sql: str, params: (list | tuple)) -> list[tuple] abst;
    def kv_get(key: str) -> (str | None) abst;
    def kv_put(key: str, value: str) -> None abst;
    def kv_delete(key: str) -> None abst;
    def notify(channel: str, payload: str) -> None abst;
    def close -> None abst;
}


obj PgStore(Store) {
    """Postgres implementation over the vendored pure-python wire driver.

    Two connection lanes: the transactional lane owned by begin/commit, and a
    dedicated autocommit lane for LISTEN (notifications bypass transaction-mode
    pooling by design).
    """
    has conninfo: ConnInfo,
        _conn: (Any | None) postinit,
        _listen_conn: (Any | None) postinit,
        _lock: threading.RLock postinit,
        _server_version: (int | None) postinit,
        _in_txn: bool postinit;

    def postinit -> None;
    def is_available -> bool;
    def server_version -> int;
    def ensure_schema(promotions: dict[str, list[str]]) -> None;
    def begin(serializable: bool = True) -> None;
    def commit -> None;
    def rollback -> None;
    def in_txn -> bool;
    def load(ids: list[UUID]) -> dict[UUID, AnchorRow];
    def upsert(rows: list[AnchorRow]) -> None;
    def delete(ids: list[UUID]) -> None;
    def existing(ids: list[UUID]) -> set[UUID];
    def root_ids -> list[UUID];
    def rows(sql: str, params: (list | tuple)) -> list[tuple];
    def kv_get(key: str) -> (str | None);
    def kv_put(key: str, value: str) -> None;
    def kv_delete(key: str) -> None;
    def notify(channel: str, payload: str) -> None;
    def listen(channel: str, callback: Any) -> None;
    def close -> None;
    def _ensure_conn -> Any;
    def _ddl(promotions: dict[str, list[str]]) -> list[str];
    def _property_graph_ddl -> list[str];
}
