"""The reason a shared store failed must survive the boundary (issue #8166).

`shared_store` used to wrap everything in `except Exception -> return None`, so a
database that was resolved, reachable and merely failed during schema DDL became
indistinguishable from no database being configured at all. Downstream, the user
manager reconstructed a cause it never verified and told the operator that no
`[scale.database]` url / `JAC_DB_URL` had resolved, for a URL that was set and
valid. These tests pin the failure reason to the failure.
"""

import os;
import unittest.mock;
import pytest;
import jaclang.scale.persistence.pg as pgmod;
import from jaclang.runtimelib.store { PgStore }
import from jaclang.scale.identity.user_manager { JacScaleUserManager }

glob _URL = "postgresql://jac:sekret@db.internal:5432/jacapp";


"""Run *body* with a resolvable JAC_DB_URL and a scrubbed store cache."""
def _with_db_url(body: any) -> any {
    saved = dict(pgmod._holder);
    try {
        with unittest.mock.patch.dict(os.environ, {"JAC_DB_URL": _URL}) {
            pgmod._holder.clear();
            return body();
        }
    } finally {
        pgmod._holder.clear();
        pgmod._holder.update(saved);
    }
}


test "a store that fails to prepare records why, instead of just None" {
    boom = RuntimeError("schema ddl exploded");

    def body {
        with unittest.mock.patch.object(
            PgStore, "ensure_schema_once", side_effect=boom
        ) {
            store = pgmod.shared_store();
        }
        assert store is None , "the store came back despite failing to prepare";
        assert pgmod.shared_store_error() is boom , (
            "shared_store destroyed the reason it failed; the caller can only "
            "guess, and it guesses 'no url configured'"
        );
    }
    _with_db_url(body);
}


test "the reported target never carries the password" {
    def body {
        masked = pgmod.masked_db_url();
        assert "sekret" not in masked , f"the password leaked into {masked}";
        assert "db.internal:5432/jacapp" in masked , (
            f"the operator cannot tell which database failed: {masked}"
        );
    }
    _with_db_url(body);
}


test "a resolved database that failed is not reported as a missing url" {
    boom = RuntimeError("connection refused at db.internal:5432");
    with unittest.mock.patch(
        "jaclang.scale.persistence.pg.shared_store", return_value=None
    ) {
        with unittest.mock.patch(
            "jaclang.scale.persistence.pg.shared_store_error", return_value=boom
        ) {
            with unittest.mock.patch(
                "jaclang.scale.persistence.pg.masked_db_url",
                return_value="postgresql://***@db.internal:5432/jacapp"
            ) {
                with pytest.raises(RuntimeError) as exc {
                    JacScaleUserManager(base_path=".");
                }
            }
        }
    }
    msg = str(exc.value);
    assert "connection refused at db.internal:5432" in msg , (
        f"the real failure never reached the operator: {msg}"
    );
    assert "db.internal:5432/jacapp" in msg , (
        f"the message does not name the database that failed: {msg}"
    );
    assert "no [scale.database] url" not in msg , (
        f"a resolved database is still reported as an unset url: {msg}"
    );
    assert exc.value.__cause__ is boom , "the underlying error is not chained";
    assert "Postgres" in msg;
    assert "credential store" in msg;
}


test "a genuinely missing url is still reported as a missing url" {
    with unittest.mock.patch(
        "jaclang.scale.persistence.pg.shared_store", return_value=None
    ) {
        with unittest.mock.patch(
            "jaclang.scale.persistence.pg.shared_store_error", return_value=None
        ) {
            with unittest.mock.patch(
                "jaclang.scale.persistence.pg.masked_db_url", return_value=""
            ) {
                with pytest.raises(RuntimeError) as exc {
                    JacScaleUserManager(base_path=".");
                }
            }
        }
    }
    msg = str(exc.value);
    assert "no [scale.database] url" in msg , msg;
    assert "Postgres" in msg;
    assert "credential store" in msg;
}
