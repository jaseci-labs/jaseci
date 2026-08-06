glob _PENDING = 'pg-persistence: pending implementation (epic #7945)';


impl Session.postinit -> None {
    self.__mem__ = {};
    self._dirty = set();
    self._deleted = set();
    self._on_commit = [];
    self._retrying = False;
}


impl Session.is_available -> bool {
    return True;
}

impl Session.get(id: UUID) -> (Anchor | None) {
    raise NotImplementedError(_PENDING);
}

impl Session.put(anchor: Anchor) -> None {
    raise NotImplementedError(_PENDING);
}

impl Session.delete(id: UUID) -> None {
    raise NotImplementedError(_PENDING);
}

impl Session.close -> None {
    raise NotImplementedError(_PENDING);
}

impl Session.`has(id: UUID) -> bool {
    raise NotImplementedError(_PENDING);
}

impl Session.query(
    filter: (Callable[[Anchor], bool] | None) = None
) -> Generator[Anchor, None, None] {
    raise NotImplementedError(_PENDING);
}

impl Session.get_roots -> Generator[Root, None, None] {
    raise NotImplementedError(_PENDING);
}

impl Session.find(
    ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
) -> Generator[Anchor, None, None] {
    raise NotImplementedError(_PENDING);
}

impl Session.find_one(
    ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
) -> (Anchor | None) {
    raise NotImplementedError(_PENDING);
}

impl Session.commit(anchor: (Anchor | None) = None) -> None {
    raise NotImplementedError(_PENDING);
}

impl Session.abort -> None {
    raise NotImplementedError(_PENDING);
}

impl Session.get_mem -> dict[UUID, Anchor] {
    return self.__mem__;
}

impl Session.batch_get(ids: list[UUID]) -> dict[UUID, Anchor] {
    raise NotImplementedError(_PENDING);
}

impl Session.aget(id: UUID) -> (Anchor | None) {
    return self.get(id);
}

impl Session.aput(anchor: Anchor) -> None {
    self.put(anchor);
}

impl Session.adelete(id: UUID) -> None {
    self.delete(id);
}

impl Session.ahas(id: UUID) -> bool {
    return self.`has(id);
}

impl Session.acommit(anchor: (Anchor | None) = None) -> None {
    self.commit(anchor);
}

impl Session.run_request(body: Callable[[], Any]) -> Any {
    raise NotImplementedError(_PENDING);
}

impl Session.on_commit(callback: Callable) -> None {
    self._on_commit.append(callback);
}

impl Session.flush -> None {
    raise NotImplementedError(_PENDING);
}

impl Session.read_barrier -> None {
    raise NotImplementedError(_PENDING);
}

impl Session._materialize(row: AnchorRow) -> Anchor {
    raise NotImplementedError(_PENDING);
}

impl Session._serialize(anchor: Anchor) -> AnchorRow {
    raise NotImplementedError(_PENDING);
}

impl Session._collect_dirty -> list[AnchorRow] {
    raise NotImplementedError(_PENDING);
}

impl Session._fire_on_commit -> None {
    fired = self._on_commit;
    self._on_commit = [];
    for cb in fired {
        try {
            cb();
        } except Exception as e {
            logger.warning(f"on_commit callback failed: {type(e).__name__}: {e}");
        }
    }
}
