glob _PENDING = 'pg-persistence: pending implementation (epic #7945)';


impl PgRuntime.postinit -> None {
    self._bin_dir = None;
    self._proc = None;
    self._lock = threading.RLock();
}


impl PgRuntime.ensure -> ConnInfo {
    raise NotImplementedError(_PENDING);
}

impl PgRuntime.serve -> int {
    raise NotImplementedError(_PENDING);
}

impl PgRuntime.stop -> None {
    raise NotImplementedError(_PENDING);
}

impl PgRuntime.is_running -> bool {
    raise NotImplementedError(_PENDING);
}

impl PgRuntime._resolve_binaries -> str {
    raise NotImplementedError(_PENDING);
}

impl PgRuntime._resolve_from_env -> (str | None) {
    raise NotImplementedError(_PENDING);
}

impl PgRuntime._resolve_from_path -> (str | None) {
    raise NotImplementedError(_PENDING);
}

impl PgRuntime._resolve_from_zonky -> (str | None) {
    raise NotImplementedError(_PENDING);
}

impl PgRuntime._download_zonky(major: int) -> (str | None) {
    raise NotImplementedError(_PENDING);
}

impl PgRuntime._initdb_if_needed(bin_dir: str) -> None {
    raise NotImplementedError(_PENDING);
}

impl PgRuntime._start(bin_dir: str) -> ConnInfo {
    raise NotImplementedError(_PENDING);
}

impl PgRuntime._wait_ready(conninfo: ConnInfo, timeout: float = 30.0) -> None {
    raise NotImplementedError(_PENDING);
}
