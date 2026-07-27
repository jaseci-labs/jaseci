"""Integration tests for the Postgres/Supabase backends.

Run with a disposable Postgres database:
    JAC_SERVERLESS_TEST_DB=postgresql://user:pass@localhost:5432/db jac test ...
Skipped when JAC_SERVERLESS_TEST_DB is unset.
"""
import os;
import pytest;
import uuid;

glob TEST_DB = os.environ.get("JAC_SERVERLESS_TEST_DB");


def _require_db -> str {
    if not TEST_DB {
        pytest.skip("set JAC_SERVERLESS_TEST_DB to run Postgres integration tests");
    }
    return str(TEST_DB);
}


test "postgres memory connects and shares one engine per url" {
    url = _require_db();
    import from jaclang.serverless.postgres_memory { PostgresMemory }
    m1 = PostgresMemory(url=url);
    m2 = PostgresMemory(url=url);
    assert m1.is_available();
    assert m1._engine is m2._engine;
    m1.close();
    assert m2.is_available();
}


test "identity create, authenticate, and password-reset flag on postgres" {
    url = _require_db();
    import from jaclang.serverless.postgres_identity { PostgresIdentityStorage }
    storage = PostgresIdentityStorage(db_path="", url=url);
    uname = f"it_{uuid.uuid4().hex[:10]}";
    created = storage.create_user(
        [{"type": "username", "value": uname}],
        {"type": "password", "password": "pw123456"}
    );
    assert created.get("user_id");
    assert storage.authenticate(uname, "wrong-password") is None;
    auth = storage.authenticate(uname, "pw123456");
    assert auth is not None;

    # bool flags must be coerced for Postgres integer columns
    assert storage.update_user_fields(
        created["user_id"], {"requires_password_reset": True}
    );
    user = storage.get_user_by_id(created["user_id"]);
    assert user is not None;
    assert user["requires_password_reset"];
    found = storage.find_user_by_identity(uname);
    assert found is not None and found["user_id"] == created["user_id"];
}


test "memory and identity share one connection pool" {
    url = _require_db();
    import from jaclang.serverless.postgres_memory {
        PostgresMemory,
        shared_postgres_engine
    }
    import from jaclang.serverless.config { normalize_postgres_url }
    import from jaclang.serverless.postgres_identity { PostgresIdentityStorage }
    memory = PostgresMemory(url=url);
    storage = PostgresIdentityStorage(db_path="", url=url);
    assert memory._engine is storage._engine;
    assert memory._engine is shared_postgres_engine(normalize_postgres_url(url));
}
