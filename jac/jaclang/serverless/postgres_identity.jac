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
    def _update_fields(user_id: str, fields: dict[str, any]) -> bool;
}


# requires_password_reset is an Integer column; Postgres refuses Python bools
# in integer columns while sqlite quietly coerces them
def coerce_identity_row(doc: dict[str, any]) -> dict[str, any] {
    out = dict(doc);
    if isinstance(out.get('requires_password_reset'), bool) {
        out['requires_password_reset'] = int(out['requires_password_reset']);
    }
    return out;
}
