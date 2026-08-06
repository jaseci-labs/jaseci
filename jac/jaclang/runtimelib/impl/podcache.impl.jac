impl PodCache.postinit -> None {
    self._rows = OrderedDict();
    self._lock = threading.RLock();
    self.hits = 0;
    self.misses = 0;
}


impl PodCache.get(id: UUID, version: int) -> (Any | None) {
    with self._lock {
        entry = self._rows.get(id);
        if entry is None or entry[0] != version {
            self.misses += 1;
            return None;
        }
        self._rows.move_to_end(id);
        self.hits += 1;
        return entry[1];
    }
}


impl PodCache.put(id: UUID, version: int, payload: Any) -> None {
    with self._lock {
        self._rows[id] = (version, payload);
        self._rows.move_to_end(id);
        while len(self._rows) > self.capacity {
            self._rows.popitem(last=False);
        }
    }
}


impl PodCache.invalidate(id: UUID) -> None {
    with self._lock {
        self._rows.pop(id, None);
    }
}


impl PodCache.invalidate_payload(payload: str) -> None {
    for part in payload.split(',') {
        token = part.strip();
        if not token {
            continue;
        }
        try {
            self.invalidate(UUID(token));
        } except ValueError {
            logger.debug(f"PodCache: ignoring malformed invalidation {token!r}");
        }
    }
}


impl PodCache.clear -> None {
    with self._lock {
        self._rows.clear();
    }
}
