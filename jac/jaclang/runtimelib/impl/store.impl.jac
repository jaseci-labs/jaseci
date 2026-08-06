glob _PENDING = 'pg-persistence: pending implementation (epic #7945)';


impl ConnInfo.dsn -> str {
    if self.unix_socket_dir {
        return (
            f"host={self.unix_socket_dir} user={self.user} " f"dbname={self.database}"
        );
    }
    return (
        f"host={self.host} port={self.port} user={self.user} " f"dbname={self.database}"
    );
}


impl PgStore.postinit -> None {
    self._conn = None;
    self._listen_conn = None;
    self._lock = threading.RLock();
    self._server_version = None;
    self._in_txn = False;
}


impl PgStore.is_available -> bool {
    raise NotImplementedError(_PENDING);
}

impl PgStore.server_version -> int {
    raise NotImplementedError(_PENDING);
}

impl PgStore.ensure_schema(promotions: dict[str, list[str]]) -> None {
    raise NotImplementedError(_PENDING);
}

impl PgStore.begin(serializable: bool = True) -> None {
    raise NotImplementedError(_PENDING);
}

impl PgStore.commit -> None {
    raise NotImplementedError(_PENDING);
}

impl PgStore.rollback -> None {
    raise NotImplementedError(_PENDING);
}

impl PgStore.in_txn -> bool {
    return self._in_txn;
}

impl PgStore.load(ids: list[UUID]) -> dict[UUID, AnchorRow] {
    raise NotImplementedError(_PENDING);
}

impl PgStore.upsert(rows: list[AnchorRow]) -> None {
    raise NotImplementedError(_PENDING);
}

impl PgStore.delete(ids: list[UUID]) -> None {
    raise NotImplementedError(_PENDING);
}

impl PgStore.existing(ids: list[UUID]) -> set[UUID] {
    raise NotImplementedError(_PENDING);
}

impl PgStore.root_ids -> list[UUID] {
    raise NotImplementedError(_PENDING);
}

impl PgStore.rows(sql: str, params: (list | tuple)) -> list[tuple] {
    raise NotImplementedError(_PENDING);
}

impl PgStore.kv_get(key: str) -> (str | None) {
    raise NotImplementedError(_PENDING);
}

impl PgStore.kv_put(key: str, value: str) -> None {
    raise NotImplementedError(_PENDING);
}

impl PgStore.kv_delete(key: str) -> None {
    raise NotImplementedError(_PENDING);
}

impl PgStore.notify(channel: str, payload: str) -> None {
    raise NotImplementedError(_PENDING);
}

impl PgStore.listen(channel: str, callback: Any) -> None {
    raise NotImplementedError(_PENDING);
}

impl PgStore.close -> None {
    raise NotImplementedError(_PENDING);
}

impl PgStore._ensure_conn -> Any {
    raise NotImplementedError(_PENDING);
}

impl PgStore._ddl(promotions: dict[str, list[str]]) -> list[str] {
    raise NotImplementedError(_PENDING);
}

impl PgStore._property_graph_ddl -> list[str] {
    raise NotImplementedError(_PENDING);
}
