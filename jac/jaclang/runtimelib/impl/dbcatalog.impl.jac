import os;
import platform;

def _registry_ddl -> str {
    return f"""
        CREATE TABLE IF NOT EXISTS {REGISTRY_TABLE} (
            database     text PRIMARY KEY,
            kind         text NOT NULL DEFAULT '{DbKind.PROJECT.value}',
            owner_path   text NOT NULL DEFAULT '',
            host         text NOT NULL DEFAULT '',
            pid          integer NOT NULL DEFAULT 0,
            created_at   timestamptz NOT NULL DEFAULT now(),
            last_used_at timestamptz NOT NULL DEFAULT now()
        )
        """;
}


impl this_host -> str {
    return platform.node() or '';
}


impl is_jac_database(database: str) -> bool {
    if not database.startswith(DB_PREFIX) or len(database) <= len(DB_PREFIX) {
        return False;
    }
    for ch in database {
        if not (ch.isalnum() or ch == '_') {
            return False;
        }
    }
    return True;
}


impl sqlstate_of(err: Exception) -> str {
    for arg in getattr(err, 'args', ()) {
        if isinstance(arg, dict) {
            return str(arg.get('C') or '');
        }
    }
    return '';
}


impl holds_no_data(info: ConnInfo, database: str) -> bool {
    import from jaclang.jac0core.constant { Constants as Con }
    import from jaclang.vendor.pgload { connect }
    try {
        conn: Any = connect(
            info.user,
            host=info.host,
            port=info.port,
            unix_socket_dir=info.unix_socket_dir,
            database=database,
            password=info.password or None
        );
    } except Exception as e {
        logger.warning(f"could not inspect {database}: {e}");
        return False;
    }
    try {
        rows = conn.run(
            'SELECT count(*) FROM anchors WHERE id::text <> :sysroot',
            sysroot=str(Con.SUPER_ROOT_UUID)
        );
        return int(rows[0][0]) == 0;
    } except Exception as e {
        if sqlstate_of(e) == '42P01' {
            return True;
        }
        logger.warning(f"could not inspect {database}: {e}");
        return False;
    } finally {
        conn.close();
    }
}


impl admin_conninfo(info: ConnInfo) -> ConnInfo {
    return ConnInfo(
        host=info.host,
        port=info.port,
        user=info.user,
        password=info.password,
        database=MAINTENANCE_DB,
        unix_socket_dir=info.unix_socket_dir
    );
}


impl connect_admin(info: ConnInfo) -> Any {
    import from jaclang.vendor.pgload { connect }
    admin = admin_conninfo(info);
    return connect(
        admin.user,
        host=admin.host,
        port=admin.port,
        unix_socket_dir=admin.unix_socket_dir,
        database=admin.database,
        password=admin.password or None
    );
}


impl ensure_registry(conn: Any) -> bool {
    try {
        conn.run(_registry_ddl());
        return True;
    } except Exception as e {
        logger.debug(f"database registry unavailable: {e}");
        return False;
    }
}


impl record_database(conn: Any, database: str, kind: DbKind, owner_path: str) -> None {
    if not is_jac_database(database) {
        return;
    }
    sql = f"""
        INSERT INTO {REGISTRY_TABLE}
            (database, kind, owner_path, host, pid)
        VALUES (:db, :kind, :owner, :host, :pid)
        ON CONFLICT (database) DO UPDATE SET
            last_used_at = now(),
            kind = excluded.kind,
            host = excluded.host,
            pid = excluded.pid,
            owner_path = CASE
                WHEN excluded.owner_path <> '' THEN excluded.owner_path
                ELSE {REGISTRY_TABLE}.owner_path
            END
        """;
    params = {
        'db': database,
        'kind': str(kind.value),
        'owner': owner_path,
        'host': this_host(),
        'pid': os.getpid()
    };
    try {
        conn.run(sql, **params);
        return;
    } except Exception as e {
        logger.debug(f"{REGISTRY_TABLE} not writable yet ({e}); creating it");
    }
    if not ensure_registry(conn) {
        return;
    }
    try {
        conn.run(sql, **params);
    } except Exception as e {
        logger.debug(f"could not record {database} in {REGISTRY_TABLE}: {e}");
    }
}


impl forget_database(conn: Any, database: str) -> None {
    try {
        conn.run(f"DELETE FROM {REGISTRY_TABLE} WHERE database = :db", db=database);
    } except Exception as e {
        logger.debug(f"could not forget {database}: {e}");
    }
}


impl list_databases(conn: Any) -> list[DbRecord] {
    ensure_registry(conn);
    rows = conn.run(
        f"""
        SELECT d.datname,
               pg_database_size(d.datname),
               r.database IS NOT NULL,
               coalesce(r.kind, ''),
               coalesce(r.owner_path, ''),
               coalesce(r.host, ''),
               coalesce(r.pid, 0),
               coalesce(r.created_at::text, ''),
               coalesce(r.last_used_at::text, '')
        FROM pg_database d
        LEFT JOIN {REGISTRY_TABLE} r ON r.database = d.datname
        WHERE d.datname LIKE :pattern AND NOT d.datistemplate
        ORDER BY d.datname
        """,
        pattern=DB_PREFIX.replace('_', '\\_') + '%'
    )
        or [];
    out: list[DbRecord] = [];
    for row in rows {
        out.append(
            DbRecord(
                database=str(row[0]),
                size_bytes=int(row[1] or 0),
                recorded=bool(row[2]),
                kind=str(row[3] or ''),
                owner_path=str(row[4] or ''),
                host=str(row[5] or ''),
                pid=int(row[6] or 0),
                created_at=str(row[7] or ''),
                last_used_at=str(row[8] or '')
            )
        );
    }
    return out;
}


impl drop_database(conn: Any, database: str, force: bool = False) -> bool {
    assert is_jac_database(database) , (
        f"refusing to drop {database!r}: only jac-owned databases "
        f"(named {DB_PREFIX}*) can be dropped"
    );
    suffix = ' WITH (FORCE)' if force else '';
    try {
        conn.run(f'DROP DATABASE IF EXISTS "{database}"{suffix}');
    } except Exception as e {
        logger.debug(f"could not drop {database}: {e}");
        return False;
    }
    forget_database(conn, database);
    return True;
}


impl process_alive(host: str, pid: int) -> bool {
    if pid <= 0 {
        return False;
    }
    if host and host != this_host() {
        return True;
    }
    try {
        os.kill(pid, 0);
        return True;
    } except ProcessLookupError {
        return False;
    } except PermissionError {
        return True;
    } except OSError {
        return True;
    }
}


impl dead_scratch_databases(records: list[DbRecord]) -> list[str] {
    return [
        rec.database
        for rec in records
        if rec.is_scratch() and not process_alive(rec.host, rec.pid)
    ];
}


impl expired_databases(conn: Any, days: int, keep: str) -> list[str] {
    if days <= 0 {
        return [];
    }
    if not ensure_registry(conn) {
        return [];
    }
    rows = conn.run(
        f"""
        SELECT r.database FROM {REGISTRY_TABLE} r
        JOIN pg_database d ON d.datname = r.database
        WHERE r.last_used_at < now() - make_interval(days => :days)
          AND r.database <> :keep
        ORDER BY r.database
        """,
        days=days,
        keep=keep
    )
        or [];
    return [
        str(row[0])
        for row in rows
        if is_jac_database(str(row[0]))
    ];
}


impl DbRecord.is_scratch -> bool {
    return self.kind == DbKind.SCRATCH.value
        or self.database.startswith(SCRATCH_PREFIX);
}


impl DbRecord.is_orphaned -> bool {
    if not self.recorded or self.is_scratch() or not self.owner_path {
        return False;
    }
    return not os.path.isdir(self.owner_path);
}


impl DbRecord.state -> str {
    if self.is_scratch() {
        return 'scratch' if process_alive(self.host, self.pid) else 'dead scratch';
    }
    if not self.recorded {
        return 'unattributed';
    }
    if not self.owner_path {
        return 'unknown owner';
    }
    return 'orphaned' if self.is_orphaned() else 'live';
}
