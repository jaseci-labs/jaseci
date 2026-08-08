"""Minimal PostgreSQL wire-protocol (v3) client — exactly the surface the
Store needs, nothing else (epic #7945).

Design constraints that keep this small:
  - Text mode everywhere. Every Store/compiler parameter is explicitly CAST
    in its SQL, so parameters ship as text and results decode by OID for
    only the scalar types we read (bool, ints, floats); everything else is
    returned as str and parsed by the caller (jsonb via json.loads, uuids
    via UUID()).
  - One statement per run() (the Store's contract), extended query protocol
    (Parse/Bind/Describe/Execute/Sync) with named :param placeholders.
  - Auth: trust, cleartext, MD5, and SCRAM-SHA-256 (no channel binding) —
    what embedded servers and provisioned pods actually use.
  - LISTEN/NOTIFY: NotificationResponse messages land in `notifications`
    as (pid, channel, payload), drained by the Store's listener loop.

Errors raise PgWireError with the server's error-field dict as args[0]
({'C': sqlstate, 'M': message, ...}) — the shape the Session's
serialization-conflict detection already consumes.
"""

import base64;
import hashlib;
import hmac;
import logging;
import secrets as _pysecrets;
import socket;
import struct;
import from collections { deque }
import from typing { Any }

glob logger = logging.getLogger(__name__),
     PROTOCOL_VERSION = 196608,
     __all__ = ['PgWireConnection', 'PgWireError'];


# args[0] is the server error-field dict ({'C': sqlstate, 'M': message, ...}).
class PgWireError(Exception) {}


def _encode_param(v: any) -> (bytes | None);
def _array_literal(vals: any) -> str;
def _decode_value(oid: int, raw: bytes) -> any;
def _named_to_positional(sql: str, params: dict) -> tuple[str, list];


obj PgWireConnection {
    has user: str,
        host: (str | None) = None,
        port: int = 5432,
        unix_sock: (str | None) = None,
        database: str = 'postgres',
        password: (str | None) = None,
        timeout: (float | None) = None,
        application_name: str = 'jac',
        notifications: deque postinit,
        parameters: dict[str, str] postinit,
        _sock: (Any | None) postinit,
        _closed: bool postinit;

    def postinit -> None;
    def run(sql: str, **params: any) -> list;
    def close -> None;
    def _connect_socket -> None;
    def _startup -> None;
    def _authenticate(code: int, payload: bytes) -> None;
    def _scram_auth(payload: bytes) -> None;
    def _send(msg_type: str, payload: bytes) -> None;
    def _read_message -> tuple[str, bytes];
    def _read_exact(n: int) -> bytes;
    def _pump_ready -> None;
    def _handle_async(msg_type: str, payload: bytes) -> bool;
}
