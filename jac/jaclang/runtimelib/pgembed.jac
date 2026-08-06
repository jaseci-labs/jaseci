"""Embedded Postgres supervisor: zero-config engine from laptop to pod.

Resolution order for server binaries (first hit wins):
  1. JAC_PG_DIST — path to an unpacked postgres distribution (bin/postgres)
  2. a postgres on PATH whose major matches the pin
  3. auto-download of the io.zonky.test portable binaries from Maven Central
     (checksum-verified, cached under ~/.cache/jac/pg/dist)

The pinned major is PG_MAJOR (19); JAC_PG_VERSION overrides. If the pinned
major is unavailable from every source, the newest available major is used
with a warning — zero-config must not break during the 19-beta window.

Local mode: initdb + unix-socket-only server inside the data dir, started
lazily via pg_ctl and reused across runs (stop with `jac db stop`). Pod mode
(`jac db serve`): foreground TCP server with SIGTERM translated to fast
shutdown and pg_isready-compatible health.
"""

import hashlib;
import logging;
import os;
import platform;
import shutil;
import signal;
import subprocess;
import tarfile;
import threading;
import time;
import urllib.request;
import zipfile;
import from pathlib { Path }
import from typing { Any }

import from jaclang.runtimelib.store { ConnInfo }

glob logger = logging.getLogger(__name__),
     PG_MAJOR = 19,
     SOCK_PORT = 5432,
     ZONKY_BASE = (
         'https://repo1.maven.org/maven2/io/zonky/test/postgres/'
         'embedded-postgres-binaries-'
     ),
     __all__ = ['PgRuntime', 'PG_MAJOR', 'pinned_major', 'dist_cache_dir'];


def pinned_major -> int;
def dist_cache_dir -> str;


obj PgRuntime {
    """Owns one postgres server for one data directory."""
    has data_dir: str,
        port: int = 0,
        tcp: bool = False,
        superuser: str = 'jac',
        database: str = 'jac',
        _bin_dir: (str | None) postinit,
        _proc: (Any | None) postinit,
        _lock: threading.RLock postinit;

    def postinit -> None;
    def ensure -> ConnInfo;
    def serve -> int;
    def stop -> None;
    def is_running -> bool;
    def conninfo -> ConnInfo;
    def _sock_dir -> str;
    def _resolve_binaries -> str;
    def _resolve_from_env -> (str | None);
    def _resolve_from_path -> (str | None);
    def _resolve_from_zonky -> (str | None);
    def _download_zonky(major: int) -> (str | None);
    def _zonky_versions -> list[str];
    def _initdb_if_needed(bin_dir: str) -> None;
    def _start(bin_dir: str) -> None;
    def _wait_ready(timeout: float = 60.0) -> None;
    def _ensure_database -> None;
}
