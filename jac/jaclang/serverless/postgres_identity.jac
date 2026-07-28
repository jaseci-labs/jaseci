import from jaclang.scale.identity.identity_storage { SqliteIdentityStorage }

obj PostgresIdentityStorage(SqliteIdentityStorage) {
    has url: str = "";

    def postinit -> None;
    def _store_user(user_doc: dict[str, any]) -> None;
    def _update_fields(user_id: str, fields: dict[str, any]) -> bool;
}


def coerce_identity_row(doc: dict[str, any]) -> dict[str, any] {
    out = dict(doc);
    if isinstance(out.get('requires_password_reset'), bool) {
        out['requires_password_reset'] = int(out['requires_password_reset']);
    }
    return out;
}
