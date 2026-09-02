#!/usr/bin/env python3
"""Convert a legacy Jac Mongo archive into a Jac Postgres seed dump.

The converter is intentionally dependency-free on the Python side. It uses
MongoDB tools to restore/export the archive, writes a plain Postgres SQL dump,
and can optionally load that SQL into a Postgres instance and re-dump it with
`pg_dump -Fc`.

Typical LittleX5 usage with Docker containers:

    python scripts/mongo_archive_to_pgdump.py \
        --archive ~/Space/jaseci_env/jaseci_external_tools/littlex5/backup.dump \
        --mongo-tools-container mongodb \
        --postgres-container postgres \
        --stream-load \
        --output-pgdump ~/Space/jaseci_env/jaseci_external_tools/littlex5/backup.pgdump
"""

from __future__ import annotations

import argparse
import base64
import copy
import hashlib
import json
import os
import sqlite3
import subprocess
import sys
import time
import uuid
from collections.abc import Iterable, Iterator
from contextlib import contextmanager
from dataclasses import dataclass, field
from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path
from typing import Any


ANCHOR_COLUMNS = (
    "id",
    "kind",
    "arch_type",
    "arch_module",
    "fingerprint",
    "root_id",
    "src",
    "dst",
    "undirected",
    "props",
    "format_version",
    "version",
    "updated_at",
)

LEGACY_CORE_MODULE_ALIASES = {
    "jaclang.jac0core.archetype": "jaclang.runtime.archetype",
}

SCRYPT_N = 16384
SCRYPT_R = 8
SCRYPT_P = 1
SCRYPT_DKLEN = 64
SCRYPT_SALT_BYTES = 16
SCRYPT_MAXMEM = 48 * 1024 * 1024


@dataclass
class ConvertStats:
    anchors: int = 0
    node_anchors: int = 0
    edge_anchors: int = 0
    users: int = 0
    identity_lookups: int = 0
    sso_lookups: int = 0
    graph_types: set[tuple[str, str]] = field(default_factory=set)


def log(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


def die(message: str) -> None:
    raise SystemExit(f"error: {message}")


def run(
    cmd: list[str],
    *,
    stdin_path: Path | None = None,
    stdout_path: Path | None = None,
    check: bool = True,
) -> subprocess.CompletedProcess[bytes]:
    log("+ " + " ".join(cmd))
    stdin = None
    stdout = None
    try:
        if stdin_path is not None:
            stdin = stdin_path.open("rb")
        if stdout_path is not None:
            stdout = stdout_path.open("wb")
        proc = subprocess.run(cmd, stdin=stdin, stdout=stdout, check=False)
    finally:
        if stdin is not None:
            stdin.close()
        if stdout is not None:
            stdout.close()
    if check and proc.returncode != 0:
        die(f"command failed with exit code {proc.returncode}: {' '.join(cmd)}")
    return proc


def docker_exec(container: str, *cmd: str, stdin: bool = False) -> list[str]:
    base = ["docker", "exec"]
    if stdin:
        base.append("-i")
    return [*base, container, *cmd]


def mongo_cmd(args: argparse.Namespace, tool: str, *, stdin: bool = False) -> list[str]:
    if args.mongo_tools_container:
        return docker_exec(args.mongo_tools_container, tool, stdin=stdin)
    return [tool]


def restore_mongo_archive(args: argparse.Namespace) -> None:
    if args.skip_restore:
        log(f"Skipping archive restore; reading Mongo database {args.restore_db!r}.")
        return

    archive = Path(args.archive).expanduser()
    if not archive.exists():
        die(f"archive not found: {archive}")

    ns_includes = [f"{args.source_db}._anchors"]
    if args.include_users:
        ns_includes.append(f"{args.source_db}.users")

    cmd = [
        *mongo_cmd(args, "mongorestore", stdin=bool(args.mongo_tools_container)),
        "--drop",
        f"--nsFrom={args.source_db}.*",
        f"--nsTo={args.restore_db}.*",
        *[f"--nsInclude={name}" for name in ns_includes],
    ]
    if args.mongo_tools_container:
        cmd.append("--archive")
        run(cmd, stdin_path=archive)
    else:
        cmd.append(f"--archive={archive}")
        run(cmd)


def drop_mongo_database(args: argparse.Namespace) -> None:
    if args.skip_restore or args.keep_restored:
        return
    script = f"db.getSiblingDB({json.dumps(args.restore_db)}).dropDatabase()"
    cmd = [
        *mongo_cmd(args, "mongosh"),
        "--quiet",
        "--eval",
        script,
    ]
    run(cmd, check=False)


def mongoexport_cmd(
    args: argparse.Namespace,
    collection: str,
    *,
    limit: int | None = None,
) -> list[str]:
    cmd = [
        *mongo_cmd(args, "mongoexport"),
        "--quiet",
        "--uri",
        args.mongo_uri,
        "--db",
        args.restore_db,
        "--collection",
        collection,
        "--type=json",
    ]
    if limit:
        cmd.extend(["--limit", str(limit)])
    return cmd


def iter_mongo_collection(
    args: argparse.Namespace,
    collection: str,
    *,
    limit: int | None = None,
) -> Iterator[dict[str, Any]]:
    cmd = mongoexport_cmd(args, collection, limit=limit)
    log("+ " + " ".join(cmd))
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=None,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1024 * 1024,
    )
    assert proc.stdout is not None
    try:
        for line_no, line in enumerate(proc.stdout, start=1):
            text = line.strip()
            if not text:
                continue
            try:
                raw = json.loads(text)
            except json.JSONDecodeError as exc:
                die(f"bad JSON from mongoexport {collection} line {line_no}: {exc}")
            if isinstance(raw, dict):
                yield normalize_mongo_json(raw)
            else:
                die(f"mongoexport {collection} line {line_no} was not an object")
    finally:
        if proc.stdout is not None:
            proc.stdout.close()
    rc = proc.wait()
    if rc != 0:
        die(f"mongoexport failed for {collection} with exit code {rc}")


def normalize_mongo_json(value: Any) -> Any:
    """Turn Mongo extended JSON wrappers into ordinary JSON values."""
    if isinstance(value, list):
        return [normalize_mongo_json(item) for item in value]
    if not isinstance(value, dict):
        return value

    if set(value) == {"$oid"}:
        return value["$oid"]
    if set(value) == {"$uuid"}:
        return value["$uuid"]
    if set(value) == {"$numberInt"}:
        return int(value["$numberInt"])
    if set(value) == {"$numberLong"}:
        return int(value["$numberLong"])
    if set(value) == {"$numberDouble"}:
        return float(value["$numberDouble"])
    if set(value) == {"$date"}:
        raw = value["$date"]
        if isinstance(raw, dict) and "$numberLong" in raw:
            millis = int(raw["$numberLong"])
            return datetime.fromtimestamp(millis / 1000, tz=timezone.utc).isoformat()
        return normalize_mongo_json(raw)
    if "$binary" in value and len(value) == 1:
        return value["$binary"]

    return {key: normalize_mongo_json(item) for key, item in value.items()}


def rewrite_legacy_core_modules(value: Any) -> Any:
    if isinstance(value, list):
        return [rewrite_legacy_core_modules(item) for item in value]
    if not isinstance(value, dict):
        return value

    rewritten = {
        key: rewrite_legacy_core_modules(item) for key, item in value.items()
    }
    module_name = rewritten.get("__module__")
    if isinstance(module_name, str) and module_name in LEGACY_CORE_MODULE_ALIASES:
        rewritten["__module__"] = LEGACY_CORE_MODULE_ALIASES[module_name]
    return rewritten


def rewrite_legacy_core_module_name(module_name: Any) -> Any:
    if isinstance(module_name, str):
        return LEGACY_CORE_MODULE_ALIASES.get(module_name, module_name)
    return module_name


def as_uuid_text(value: Any) -> str | None:
    if value in (None, ""):
        return None
    text = str(value)
    try:
        return str(uuid.UUID(text))
    except ValueError:
        if len(text) == 32:
            try:
                return str(uuid.UUID(hex=text))
            except ValueError:
                return None
        return None


def as_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.lower() in {"1", "true", "t", "yes", "y", "on"}
    return bool(value)


def timestamp_text(value: Any) -> str:
    if not value:
        return datetime.now(timezone.utc).isoformat()
    return str(value)


def json_text(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), sort_keys=False)


def b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


@lru_cache(maxsize=128)
def migration_scrypt_hash(password: str) -> str:
    """Generate a Jac-compatible scrypt hash for benchmark/user reset imports."""
    salt = hashlib.sha256(f"jac-pg-migration:{password}".encode("utf-8")).digest()[
        :SCRYPT_SALT_BYTES
    ]
    digest = hashlib.scrypt(
        password.encode("utf-8"),
        salt=salt,
        n=SCRYPT_N,
        r=SCRYPT_R,
        p=SCRYPT_P,
        dklen=SCRYPT_DKLEN,
        maxmem=SCRYPT_MAXMEM,
    )
    return (
        f"scrypt${SCRYPT_N}${SCRYPT_R}${SCRYPT_P}"
        f"${b64url_encode(salt)}${b64url_encode(digest)}"
    )


def copy_escape(value: Any) -> str:
    if value is None:
        return r"\N"
    if isinstance(value, bool):
        return "true" if value else "false"
    text = str(value)
    return (
        text.replace("\\", "\\\\")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )


def write_copy_row(out: Any, values: Iterable[Any]) -> None:
    out.write("\t".join(copy_escape(value) for value in values))
    out.write("\n")


def infer_arch(data: dict[str, Any], doc: dict[str, Any]) -> tuple[str, str]:
    arch = data.get("archetype")
    if not isinstance(arch, dict):
        arch = {}
    arch_type = doc.get("arch_type") or arch.get("__type__") or ""
    arch_module = rewrite_legacy_core_module_name(
        doc.get("arch_module") or arch.get("__module__") or ""
    )
    return str(arch_type or ""), str(arch_module or "")


def transform_anchor(doc: dict[str, Any]) -> tuple[list[Any], str | None]:
    data = doc.get("data")
    if not isinstance(data, dict):
        data = {}
    data = rewrite_legacy_core_modules(data)

    raw_id = doc.get("_id") or data.get("id")
    anchor_id = as_uuid_text(raw_id)
    if anchor_id is None:
        raise ValueError(f"anchor has invalid id: {raw_id!r}")

    kind = str(doc.get("type") or data.get("__type__") or "Anchor")
    arch_type, arch_module = infer_arch(data, doc)
    root_id = as_uuid_text(data.get("root") or doc.get("root_id"))

    is_edge = kind == "EdgeAnchor" or data.get("__type__") == "EdgeAnchor"
    src = None
    dst = None
    if is_edge:
        src = as_uuid_text(data.get("source") or data.get("src"))
        dst = as_uuid_text(data.get("target") or data.get("dst"))

    row = [
        anchor_id,
        kind,
        arch_type,
        arch_module,
        str(doc.get("fingerprint") or data.get("fingerprint") or ""),
        root_id,
        src,
        dst,
        as_bool(data.get("is_undirected", data.get("undirected", doc.get("undirected", False)))),
        json_text(data),
        int(doc.get("format_version") or data.get("format_version") or 1),
        int(doc.get("version") or data.get("version") or 0),
        timestamp_text(doc.get("updated_at") or data.get("updated_at")),
    ]
    return row, arch_type or None


def ddl_sql(drop_existing: bool) -> str:
    drops = ""
    if drop_existing:
        drops = """
DROP TABLE IF EXISTS sso_lookups CASCADE;
DROP TABLE IF EXISTS identity_lookups CASCADE;
DROP TABLE IF EXISTS identity_users CASCADE;
DROP TABLE IF EXISTS quarantine CASCADE;
DROP TABLE IF EXISTS kv_state CASCADE;
DROP TABLE IF EXISTS graph_types CASCADE;
DROP TABLE IF EXISTS anchors CASCADE;
"""

    return f"""\
SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

{drops}
CREATE TABLE IF NOT EXISTS anchors (
    id uuid PRIMARY KEY,
    kind text NOT NULL,
    arch_type text NOT NULL DEFAULT '',
    arch_module text NOT NULL DEFAULT '',
    fingerprint text NOT NULL DEFAULT '',
    root_id uuid,
    src uuid,
    dst uuid,
    undirected boolean NOT NULL DEFAULT false,
    props jsonb NOT NULL DEFAULT '{{}}'::jsonb,
    format_version integer NOT NULL DEFAULT 1,
    version bigint NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL DEFAULT now(),
    seq bigserial
);

CREATE TABLE IF NOT EXISTS graph_types (
    type_name text NOT NULL,
    ancestor text NOT NULL,
    PRIMARY KEY (type_name, ancestor)
);

CREATE TABLE IF NOT EXISTS kv_state (
    key text PRIMARY KEY,
    value text NOT NULL,
    expires_at timestamptz,
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS quarantine (
    missing_id uuid NOT NULL,
    referrer_id uuid,
    kind text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (missing_id, kind)
);

CREATE TABLE IF NOT EXISTS identity_users (
    user_id text PRIMARY KEY,
    doc jsonb NOT NULL
);

CREATE TABLE IF NOT EXISTS identity_lookups (
    value_normalized text PRIMARY KEY,
    user_id text NOT NULL
);

CREATE TABLE IF NOT EXISTS sso_lookups (
    provider text NOT NULL,
    external_id text NOT NULL,
    user_id text NOT NULL,
    PRIMARY KEY (provider, external_id)
);
"""


def write_anchor_copy(
    out: Any,
    args: argparse.Namespace,
    stats: ConvertStats,
) -> None:
    out.write(f"COPY anchors ({', '.join(ANCHOR_COLUMNS)}) FROM stdin;\n")
    for doc in iter_mongo_collection(args, "_anchors", limit=args.limit or None):
        try:
            row, arch_type = transform_anchor(doc)
        except Exception as exc:
            raw_id = doc.get("_id") or doc.get("data", {}).get("id")
            die(f"cannot convert anchor {raw_id!r}: {exc}")
        write_copy_row(out, row)
        stats.anchors += 1
        if row[1] == "NodeAnchor":
            stats.node_anchors += 1
        elif row[1] == "EdgeAnchor":
            stats.edge_anchors += 1
        if arch_type:
            stats.graph_types.add((arch_type, arch_type))
        if args.progress_every and stats.anchors % args.progress_every == 0:
            log(f"converted {stats.anchors:,} anchors")
    out.write("\\.\n\n")


def iter_users(args: argparse.Namespace) -> Iterator[dict[str, Any]]:
    if not args.include_users:
        return
    try:
        yield from iter_mongo_collection(args, "users", limit=None)
    except SystemExit:
        raise


def user_id_of(doc: dict[str, Any]) -> str | None:
    value = doc.get("user_id") or doc.get("_id")
    return str(value) if value else None


def password_reset_for_user(
    args: argparse.Namespace,
    user: dict[str, Any],
) -> str | None:
    username = username_of(user)
    if args.pg_reset_all_passwords is not None and username:
        return args.pg_reset_all_passwords
    if username is None:
        return None
    return args.pg_reset_password_map.get(username.lower())


def user_with_password_reset(
    args: argparse.Namespace,
    user: dict[str, Any],
) -> dict[str, Any]:
    password = password_reset_for_user(args, user)
    if password is None:
        return user

    updated = copy.deepcopy(user)
    credentials = updated.get("credentials")
    if not isinstance(credentials, list):
        credentials = []
        updated["credentials"] = credentials

    password_hash = migration_scrypt_hash(password)
    replaced = False
    for credential in credentials:
        if not isinstance(credential, dict):
            continue
        if credential.get("type") == "password":
            credential["password_hash"] = password_hash
            replaced = True

    if not replaced:
        credentials.append({"type": "password", "password_hash": password_hash})

    updated["requires_password_reset"] = False
    updated["updated_at"] = datetime.now(timezone.utc).isoformat()
    return updated


def write_identity_copy(
    out: Any,
    args: argparse.Namespace,
    stats: ConvertStats,
) -> list[dict[str, Any]]:
    users = [user_with_password_reset(args, user) for user in iter_users(args)]
    if not users:
        return users

    out.write("COPY identity_users (user_id, doc) FROM stdin;\n")
    for user in users:
        user_id = user_id_of(user)
        if not user_id:
            continue
        write_copy_row(out, [user_id, json_text(user)])
        stats.users += 1
    out.write("\\.\n\n")

    out.write("COPY identity_lookups (value_normalized, user_id) FROM stdin;\n")
    seen_lookup: set[str] = set()
    for user in users:
        user_id = user_id_of(user)
        identities = user.get("identities")
        if not user_id or not isinstance(identities, list):
            continue
        for ident in identities:
            if not isinstance(ident, dict):
                continue
            value = ident.get("value_normalized") or ident.get("value_raw")
            if not value:
                continue
            key = str(value).lower()
            if key in seen_lookup:
                continue
            seen_lookup.add(key)
            write_copy_row(out, [key, user_id])
            stats.identity_lookups += 1
    out.write("\\.\n\n")

    out.write("COPY sso_lookups (provider, external_id, user_id) FROM stdin;\n")
    seen_sso: set[tuple[str, str]] = set()
    for user in users:
        user_id = user_id_of(user)
        identities = user.get("identities")
        if not user_id or not isinstance(identities, list):
            continue
        for ident in identities:
            if not isinstance(ident, dict):
                continue
            provider = ident.get("provider")
            external_id = ident.get("external_id")
            if not provider or not external_id:
                continue
            key = (str(provider), str(external_id))
            if key in seen_sso:
                continue
            seen_sso.add(key)
            write_copy_row(out, [key[0], key[1], user_id])
            stats.sso_lookups += 1
    out.write("\\.\n\n")
    return users


def write_graph_types_copy(out: Any, stats: ConvertStats) -> None:
    if not stats.graph_types:
        return
    out.write("COPY graph_types (type_name, ancestor) FROM stdin;\n")
    for type_name, ancestor in sorted(stats.graph_types):
        write_copy_row(out, [type_name, ancestor])
    out.write("\\.\n\n")


def write_indexes_sql(out: Any) -> None:
    out.write(
        """\
CREATE INDEX IF NOT EXISTS idx_anchors_src ON anchors (src, arch_type) WHERE src IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_anchors_dst ON anchors (dst, arch_type) WHERE dst IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_anchors_kind_type ON anchors (kind, arch_type);
CREATE INDEX IF NOT EXISTS idx_anchors_root ON anchors (root_id) WHERE root_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_identity_lookups_user ON identity_lookups (user_id);
ANALYZE anchors;
ANALYZE graph_types;
ANALYZE identity_users;
ANALYZE identity_lookups;
ANALYZE sso_lookups;
"""
    )


def write_sql_dump(args: argparse.Namespace) -> tuple[Path, ConvertStats, list[dict[str, Any]]]:
    output = Path(args.output_sql).expanduser()
    output.parent.mkdir(parents=True, exist_ok=True)

    stats = ConvertStats()
    log(f"Writing Postgres SQL dump to {output}")
    with output.open("w", encoding="utf-8", newline="\n") as out:
        out.write(ddl_sql(args.drop_existing))
        write_anchor_copy(out, args, stats)
        users = write_identity_copy(out, args, stats)
        write_graph_types_copy(out, stats)
        write_indexes_sql(out)

    return output, stats, users


def psql_load_cmd(args: argparse.Namespace, *, stdin: bool = True) -> list[str]:
    if args.postgres_container:
        return docker_exec(
            args.postgres_container,
            "psql",
            "-v",
            "ON_ERROR_STOP=1",
            "-U",
            args.pg_user,
            "-d",
            args.pg_db,
            stdin=stdin,
        )

    if not args.pg_url:
        die("--output-pgdump needs --postgres-container or --pg-url")
    return ["psql", "-v", "ON_ERROR_STOP=1", args.pg_url]


def load_sql_to_postgres(args: argparse.Namespace, sql_path: Path) -> None:
    cmd = psql_load_cmd(args, stdin=True)
    run(cmd, stdin_path=sql_path)


@contextmanager
def psql_stream(args: argparse.Namespace) -> Iterator[Any]:
    cmd = psql_load_cmd(args, stdin=True)
    log("+ " + " ".join(cmd))
    proc = subprocess.Popen(
        cmd,
        stdin=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="strict",
        bufsize=1024 * 1024,
    )
    assert proc.stdin is not None
    try:
        yield proc.stdin
    except BaseException:
        try:
            proc.stdin.close()
        except OSError:
            pass
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
        raise
    else:
        proc.stdin.close()
        rc = proc.wait()
        if rc != 0:
            die(f"psql failed with exit code {rc}: {' '.join(cmd)}")


def stream_sql_to_postgres(
    args: argparse.Namespace,
) -> tuple[ConvertStats, list[dict[str, Any]]]:
    stats = ConvertStats()
    log("Streaming converted SQL directly into Postgres")
    with psql_stream(args) as out:
        out.write(ddl_sql(args.drop_existing))
        write_anchor_copy(out, args, stats)
        users = write_identity_copy(out, args, stats)
        write_graph_types_copy(out, stats)
        write_indexes_sql(out)
    return stats, users


def dump_postgres(args: argparse.Namespace) -> None:
    output = Path(args.output_pgdump).expanduser()
    output.parent.mkdir(parents=True, exist_ok=True)

    if args.postgres_container:
        cmd = docker_exec(
            args.postgres_container,
            "pg_dump",
            "-U",
            args.pg_user,
            "-d",
            args.pg_db,
            "-Fc",
        )
        run(cmd, stdout_path=output)
        return

    if not args.pg_url:
        die("--output-pgdump needs --postgres-container or --pg-url")
    cmd = ["pg_dump", "-Fc", "-f", str(output), args.pg_url]
    run(cmd)


def username_of(user: dict[str, Any]) -> str | None:
    identities = user.get("identities")
    if not isinstance(identities, list):
        return None
    fallback = None
    for ident in identities:
        if not isinstance(ident, dict):
            continue
        value = ident.get("value_normalized") or ident.get("value_raw")
        if not value:
            continue
        if fallback is None:
            fallback = str(value)
        if ident.get("type") == "username":
            return str(value)
    return fallback


def root_id_of(user: dict[str, Any]) -> str | None:
    root_id = user.get("root_id")
    if not root_id:
        return None
    try:
        return uuid.UUID(str(root_id)).hex
    except ValueError:
        return str(root_id)


def write_builtin_sqlite_users(
    sqlite_path: str,
    users: list[dict[str, Any]],
    default_password: str,
) -> None:
    path = Path(sqlite_path).expanduser()
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    try:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                username TEXT PRIMARY KEY,
                password_hash TEXT NOT NULL,
                token TEXT UNIQUE NOT NULL,
                root_id TEXT NOT NULL
            )
            """
        )
        password_hash = hashlib.sha256(default_password.encode()).hexdigest()
        rows = []
        for user in users:
            username = username_of(user)
            root_id = root_id_of(user)
            if not username or not root_id:
                continue
            token = hashlib.sha256(f"{username}:{root_id}".encode()).hexdigest()
            rows.append((username, password_hash, token, root_id))
        conn.executemany(
            """
            INSERT OR REPLACE INTO users (username, password_hash, token, root_id)
            VALUES (?, ?, ?, ?)
            """,
            rows,
        )
        conn.commit()
    finally:
        conn.close()
    log(f"Wrote {len(rows):,} built-in server users to {path}")


def parse_pg_password_resets(raw_values: list[str]) -> dict[str, str]:
    resets: dict[str, str] = {}
    for raw in raw_values:
        if "=" not in raw:
            raise ValueError("--pg-reset-password must be USER=PASSWORD")
        username, password = raw.split("=", 1)
        username = username.strip().lower()
        if not username:
            raise ValueError("--pg-reset-password username cannot be empty")
        resets[username] = password
    return resets


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Convert a legacy Jac MongoDB archive into Postgres dump files."
    )
    parser.add_argument("--archive", help="Mongo archive produced by mongodump --archive")
    parser.add_argument("--source-db", default="jac_db", help="database name inside the Mongo archive")
    parser.add_argument(
        "--restore-db",
        default=f"jac_migrate_{os.getpid()}",
        help="temporary Mongo database used for restored/exported data",
    )
    parser.add_argument(
        "--skip-restore",
        action="store_true",
        help="export from --restore-db as-is instead of restoring --archive first",
    )
    parser.add_argument("--keep-restored", action="store_true", help="leave the temporary Mongo database")
    parser.add_argument("--mongo-uri", default="mongodb://localhost:27017")
    parser.add_argument(
        "--mongo-tools-container",
        help="Docker container that has mongorestore, mongoexport, and mongosh",
    )
    parser.add_argument(
        "--output-sql",
        default="backup.pg.sql",
        help="plain SQL dump to write before optional pg_dump conversion",
    )
    parser.add_argument(
        "--output-pgdump",
        help="optional custom-format dump to write with pg_dump -Fc after loading SQL",
    )
    parser.add_argument(
        "--stream-load",
        action="store_true",
        help="stream converted SQL directly into psql instead of writing/loading --output-sql",
    )
    parser.add_argument(
        "--postgres-container",
        help="Docker container that has psql and pg_dump and can reach the target DB",
    )
    parser.add_argument("--pg-user", default="jac")
    parser.add_argument("--pg-db", default="jac_db")
    parser.add_argument("--pg-url", help="local psql/pg_dump connection URL when not using a container")
    parser.add_argument("--limit", type=int, default=0, help="convert only N anchors for a smoke test")
    parser.add_argument("--progress-every", type=int, default=100_000)
    parser.add_argument("--no-users", dest="include_users", action="store_false")
    parser.add_argument("--no-drop-existing", dest="drop_existing", action="store_false")
    parser.add_argument(
        "--sqlite-users-out",
        help="optional SQLite user DB for the built-in Jac server auth layer",
    )
    parser.add_argument(
        "--sqlite-default-password",
        default="password",
        help="password assigned to users in --sqlite-users-out",
    )
    parser.add_argument(
        "--pg-reset-password",
        action="append",
        default=[],
        metavar="USER=PASSWORD",
        help=(
            "rewrite one migrated identity user's password credential to a "
            "Jac scrypt hash; can be passed multiple times"
        ),
    )
    parser.add_argument(
        "--pg-reset-all-passwords",
        metavar="PASSWORD",
        help=(
            "rewrite every migrated identity user's password credential to "
            "the same Jac scrypt hash; intended for local benchmark datasets"
        ),
    )
    parser.set_defaults(include_users=True, drop_existing=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if not args.skip_restore and not args.archive:
        parser.error("--archive is required unless --skip-restore is set")
    if args.limit < 0:
        parser.error("--limit must be >= 0")
    if args.stream_load and not args.output_pgdump:
        parser.error("--stream-load requires --output-pgdump")
    try:
        args.pg_reset_password_map = parse_pg_password_resets(args.pg_reset_password)
    except ValueError as exc:
        parser.error(str(exc))

    start = time.perf_counter()
    restored = False
    stats = ConvertStats()
    users: list[dict[str, Any]] = []
    try:
        restore_mongo_archive(args)
        restored = not args.skip_restore
        if args.stream_load:
            stats, users = stream_sql_to_postgres(args)
            dump_postgres(args)
        else:
            sql_path, stats, users = write_sql_dump(args)
            if args.output_pgdump:
                load_sql_to_postgres(args, sql_path)
                dump_postgres(args)
        if args.sqlite_users_out:
            write_builtin_sqlite_users(
                args.sqlite_users_out,
                users,
                args.sqlite_default_password,
            )
    finally:
        if restored:
            drop_mongo_database(args)

    elapsed = time.perf_counter() - start
    log(
        "done: "
        f"{stats.anchors:,} anchors "
        f"({stats.node_anchors:,} nodes, {stats.edge_anchors:,} edges), "
        f"{stats.users:,} users, "
        f"{len(stats.graph_types):,} graph types in {elapsed:.1f}s"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
