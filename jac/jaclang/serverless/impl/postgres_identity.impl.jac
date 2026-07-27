import from sqlalchemy.dialects.postgresql { insert as pg_insert }
import from jaclang.serverless.config {
    missing_driver_hint,
    normalize_postgres_url
}
import from jaclang.serverless.postgres_memory { shared_postgres_engine }


impl PostgresIdentityStorage.postinit -> None {
    # let the parent define the tables against a throwaway in-memory sqlite
    # engine, then swap in the shared Postgres engine and create the schema
    self.db_path = ":memory:";
    super.postinit();
    throwaway = self._engine;
    self.url = normalize_postgres_url(self.url);
    try {
        self._engine = shared_postgres_engine(self.url);
    } except ModuleNotFoundError as e {
        raise ModuleNotFoundError(f"{missing_driver_hint()} ({e})");
    }
    try {
        self.ensure_indexes();
    } except Exception as e {
        raise RuntimeError(
            "jac-serverless: cannot create identity tables on the configured "
            f"Postgres database. Underlying error: {e}"
        );
    } finally {
        try {
            throwaway.dispose();
        } except Exception { }
    }
}


impl PostgresIdentityStorage._update_fields(
    user_id: str, fields: dict[str, any]
) -> bool {
    return super._update_fields(user_id, coerce_identity_row(fields));
}


impl PostgresIdentityStorage._store_user(user_doc: dict[str, any]) -> None {
    user_id = user_doc['user_id'];
    id_rows: list[dict[str, str]] = [];
    sso_rows: list[dict[str, str]] = [];
    for identity in user_doc.get('identities', []) {
        if identity.get('type') == 'sso' and identity.get('provider') {
            sso_rows.append(
                {
                    'provider': identity['provider'],
                    'external_id': identity.get('external_id', ''),
                    'user_id': user_id
                }
            );
        } elif identity.get('value_normalized') {
            id_rows.append(
                {'value_normalized': identity['value_normalized'], 'user_id': user_id}
            );
        }
    }
    with self._engine.begin() as conn {
        conn.execute(self._table.insert().values(**coerce_identity_row(user_doc)));
        if id_rows {
            conn.execute(
                pg_insert(self._identity_lookups).on_conflict_do_nothing(), id_rows
            );
        }
        if sso_rows {
            conn.execute(
                pg_insert(self._sso_lookups).on_conflict_do_nothing(), sso_rows
            );
        }
    }
}
