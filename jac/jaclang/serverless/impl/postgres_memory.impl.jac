import json;
import threading;
import from uuid { UUID }
import from sqlalchemy {
    Column,
    Integer,
    MetaData,
    String,
    Table,
    Text,
    select,
    text
}
import from jaclang.jac0core.archetype { Anchor }
import from jaclang.runtimelib.changeset { snapshot_field_hashes }
import from jaclang.runtimelib.serializer { Serializer }
import from jaclang.serverless.config {
    missing_driver_hint,
    normalize_postgres_url
}

glob _schema_ready: set[str] = set();


impl PostgresMemory.postinit -> None {
    self.url = normalize_postgres_url(self.url);
    self.__mem__ = {};
    self.__lock__ = threading.RLock();
    metadata = MetaData();
    # column set must match SqlAlchemyMemory's "anchors" table
    self._anchors = Table(
        "anchors",
        metadata,
        Column("id", String(64), primary_key=True),
        Column("type", String(64), nullable=False),
        Column("arch_module", Text),
        Column("arch_type", Text),
        Column("fingerprint", Text),
        Column("data", Text, nullable=False),
        Column("format_version", Integer, nullable=False, default=1),
        Column("updated_at", Text)
    );
    try {
        self._engine = shared_postgres_engine(self.url);
    } except ModuleNotFoundError as e {
        raise ModuleNotFoundError(f"{missing_driver_hint()} ({e})");
    }
    if self.url not in _schema_ready {
        try {
            metadata.create_all(self._engine, checkfirst=True);
        } except Exception as e {
            raise RuntimeError(
                "jac-serverless: cannot reach the configured Postgres database. "
                "Check SUPABASE_DB_URL / DATABASE_URL / [serverless].database_url "
                f"and network or SSL settings. Underlying error: {e}"
            );
        }
        _schema_ready.add(self.url);
    }
}


impl PostgresMemory.is_available -> bool {
    if self._engine is None {
        return False;
    }
    try {
        with self._engine.connect() as conn {
            conn.execute(text("SELECT 1"));
        }
        return True;
    } except Exception {
        return False;
    }
}


impl PostgresMemory.close -> None {
    # the engine is process-shared; per-context close only drops local state
    self.__mem__.clear();
}


impl PostgresMemory.batch_get(ids: list[UUID]) -> dict[UUID, Anchor] {
    result: dict[UUID, Anchor] = {};
    missing: list[str] = [];
    for id in ids {
        anchor = self.__mem__.get(id);
        if anchor is not None {
            result[id] = anchor;
        } else {
            missing.append(str(id));
        }
    }
    if not missing {
        return result;
    }
    tbl = self._anchors;
    with self._engine.connect() as conn {
        rows = conn.execute(
            select(tbl.c.id, tbl.c.data).where(tbl.c.id.in_(missing))
        ).fetchall();
    }
    for (rid, data) in rows {
        try {
            anchor = Serializer.deserialize(json.loads(data));
        } except Exception as e {
            logger.warning(f"PostgresMemory: failed to deserialize anchor {rid}: {e}");
            continue;
        }
        if anchor is None {
            continue;
        }
        uid = UUID(rid);
        self.__mem__[uid] = anchor;
        snapshot_field_hashes(anchor);
        result[uid] = anchor;
    }
    return result;
}
