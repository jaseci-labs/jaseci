"""Embedded Postgres supervisor: zero-config engine from laptop to pod.

Resolution order for server binaries (first hit wins):
  1. JAC_PG_DIST — path to an unpacked postgres distribution (or a tarball)
  2. a postgres on PATH whose major matches the pin
  3. auto-download of the io.zonky.test portable binaries from Maven Central
     (sha256-verified, cached under ~/.cache/jac/pg/dist)

The pinned major is PG_MAJOR (19); JAC_PG_VERSION overrides. If the pinned
major is unavailable from every source, the newest available major is used
with a warning — zero-config must not break during the 19-beta window.

Local mode: initdb + unix-socket server in the session dir, one per data dir,
started lazily and reused across runs. Pod mode (`jac db serve`): foreground
TCP server on PGDATA=/var/lib/jac/pgdata with SIGTERM translated to fast
shutdown and pg_isready-compatible health.
"""

import logging;
import os;
import shutil;
import signal;
import subprocess;
import threading;
import from typing { Any }

import from jaclang.runtimelib.store { ConnInfo }

glob logger = logging.getLogger(__name__),
     PG_MAJOR = 19,
     ZONKY_BASE = (
         'https://repo1.maven.org/maven2/io/zonky/test/postgres/'
         'embedded-postgres-binaries-'
     ),
     __all__ = ['PgRuntime', 'PG_MAJOR'];


obj PgRuntime {
    """Owns one postgres server process for one data directory."""
    has data_dir: str,
        port: int = 0,
        tcp: bool = False,
        superuser: str = 'jac',
        _bin_dir: (str | None) postinit,
        _proc: (Any | None) postinit,
        _lock: threading.RLock postinit;

    def postinit -> None;
    def ensure -> ConnInfo;
    def serve -> int;
    def stop -> None;
    def is_running -> bool;
    def _resolve_binaries -> str;
    def _resolve_from_env -> (str | None);
    def _resolve_from_path -> (str | None);
    def _resolve_from_zonky -> (str | None);
    def _download_zonky(major: int) -> (str | None);
    def _initdb_if_needed(bin_dir: str) -> None;
    def _start(bin_dir: str) -> ConnInfo;
    def _wait_ready(conninfo: ConnInfo, timeout: float = 30.0) -> None;
}
