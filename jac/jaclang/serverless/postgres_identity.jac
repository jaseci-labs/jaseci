"""Postgres/Supabase identity storage for jac-serverless.

Reuses the SQLAlchemy table definitions and query logic of the scale SQLite
identity storage, pointed at the shared Postgres engine instead of a local
file. Only the engine construction and conflict-ignoring inserts differ.
"""
import from jaclang.scale.identity.identity_storage { SqliteIdentityStorage }

obj PostgresIdentityStorage(SqliteIdentityStorage) {
    has url: str = "";

    def postinit -> None;
    def _store_user(user_doc: dict[str, any]) -> None;
}
