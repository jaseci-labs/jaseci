"""Index promotion must actually reach the query, and reach it usably.

Two defects made `[scale.database] indexes` a no-op. The promoted column was
never referenced -- `_pred_cond` emitted the raw jsonb path, and Postgres does
not substitute a generated column for its own defining expression. And the
column was `text` under a partial `WHERE arch_type = '<Arch>'` predicate, which
sorts numbers lexically and cannot be matched against the subtype-aware
arch_type test `compile_query` actually emits.

The column is now `jsonb` over `props->'archetype'->'<field>'` -- the same type
and the same expression the compiler already compares against -- indexed
without a predicate so subtypes are covered. These tests pin all three: the
column's shape, the index's usability, and the compiler naming it.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtime.graph_query { GraphQuery, QHop, QPred }
import from jaclang.server.session { runtime_for_base }
import from jaclang.data.sqlcompile { compile_query }
import from jaclang.data.store { PgStore }

node PMsg {
    has body: str = "",
        at: int = 0,
        seq: int = 0;
}

edge PPosted {}

glob PROMOS: dict[str, list[str]] = {"PMsg": ["at", "seq"]};


def _store(tmpdir: str) -> PgStore {
    lease = runtime_for_base(tmpdir, str(Path(tmpdir) / "pd_app.jac"));
    rt = lease.runtime;
    store = PgStore(
        conninfo=rt.ensure(), ensure_cb=rt.ensure, promotions=PROMOS, auto_schema=True
    );
    store.rows("SELECT 1", {});
    store.ensure_schema(PROMOS);
    return store;
}


test "a promoted field becomes a jsonb column over the compared expression" {
    with TemporaryDirectory() as td {
        store = _store(td);
        try {
            rows = store.rows(
                "SELECT data_type, is_generated FROM information_schema.columns "
                "WHERE table_name = 'anchors' AND column_name = :c",
                {"c": "g_pmsg_at"}
            );
            assert rows , "promotion did not create a column for PMsg.at";
            assert str(rows[0][0]) == "jsonb" , (
                f"promoted column must be jsonb so it matches the comparison the "
                f"compiler emits; got {rows[0][0]}"
            );
            assert str(rows[0][1]) == "ALWAYS" , rows[0][1];
        } finally {
            store.close();
        }
    }
}


test "the promoted index carries no arch_type predicate" {
    with TemporaryDirectory() as td {
        store = _store(td);
        try {
            rows = store.rows(
                "SELECT indexdef FROM pg_indexes "
                "WHERE tablename = 'anchors' AND indexname = :n",
                {"n": "idx_g_pmsg_at"}
            );
            assert rows , "promotion did not create an index for PMsg.at";
            ddl = str(rows[0][0]);
            assert " WHERE " not in ddl , (
                f"a partial index cannot be matched against the subtype-aware "
                f"arch_type test compile_query emits: {ddl}"
            );
        } finally {
            store.close();
        }
    }
}


test "compile_query names the promoted column instead of the jsonb path" {
    q = GraphQuery(
        [], hops=[QHop(dir=2, nd=PMsg, preds=[QPred(field="at", op="==", value=7)])]
    );
    cq = compile_query(q, 1, promotions=PROMOS);
    assert "g_pmsg_at" in cq.sql , (
        f"promoted column not referenced; the index stays unreachable: {cq.sql}"
    );
    assert "props->'archetype'->'at'" not in cq.sql , cq.sql;
    assert not cq.residual , cq.residual;
}


test "an unpromoted field still compiles, via the jsonb path" {
    q = GraphQuery(
        [], hops=[QHop(dir=2, nd=PMsg, preds=[QPred(field="body", op="==", value="x")])]
    );
    cq = compile_query(q, 1, promotions=PROMOS);
    assert "props->'archetype'->'body'" in cq.sql , cq.sql;
    assert not cq.residual , cq.residual;
}


test "a composite key of field names against scalars constructs" {
    p = QPred(field=("at", "seq"), op="<", value=(5, 10));
    assert p.field == ("at", "seq");
    assert p.value == (5, 10);
}


test "a composite key rejects an arity mismatch" {
    raised = False;
    try {
        _ = QPred(field=("at", "seq"), op="<", value=(5, ));
    } except TypeError {
        raised = True;
    }
    assert raised , "arity mismatch must not construct";
}


test "a composite key rejects a non-scalar element" {
    raised = False;
    try {
        _ = QPred(field=("at", "seq"), op="<", value=(5, [1, 2]));
    } except TypeError {
        raised = True;
    }
    assert raised , "a non-scalar key element must not construct";
}


test "a composite key rejects an operator it cannot order by" {
    raised = False;
    try {
        _ = QPred(field=("at", "seq"), op="in", value=(5, 10));
    } except ValueError {
        raised = True;
    }
    assert raised , "'in' has no row-comparison meaning";
}


test "a composite key matches lexicographically in object space" {
    p = QPred(field=("at", "seq"), op="<", value=(5, 10));
    assert p.matches((5, 9));
    assert not p.matches((5, 10));
    assert not p.matches((6, 0));
    assert p.matches((4, 999));
}


test "a promoted composite key compiles to a row comparison" {
    q = GraphQuery(
        [],
        hops=[
            QHop(
                dir=2,
                nd=PMsg,
                preds=[QPred(field=("at", "seq"), op="<", value=(5, 10))]
            )
        ]
    );
    cq = compile_query(q, 1, promotions=PROMOS);
    assert "(n1.g_pmsg_at, n1.g_pmsg_seq) <" in cq.sql , cq.sql;
    assert not cq.residual , cq.residual;
}


test "an unpromoted composite key still compiles, via the jsonb path" {
    q = GraphQuery(
        [],
        hops=[
            QHop(
                dir=2,
                nd=PMsg,
                preds=[QPred(field=("at", "body"), op="<", value=(5, "x"))]
            )
        ]
    );
    cq = compile_query(q, 1, promotions=PROMOS);
    assert not cq.residual , (
        f"correctness must not depend on whether an index was declared: "
        f"{cq.residual}"
    );
    assert "n1.g_pmsg_at" in cq.sql , cq.sql;
    assert "props->'archetype'->'body'" in cq.sql , cq.sql;
}
