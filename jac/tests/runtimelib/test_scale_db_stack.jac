"""The scale db stack: pooled wire connections and read-only unit profiling.

Two mechanisms pinned here. First, `PgStore.close()` parks its wire
connections in a process-wide pool (jaclang.data.pgpool) keyed by conninfo,
so the per-request store churn of the scale serving path stops paying a TCP
connect + SCRAM handshake per request; parked connections come back
sanitized (no open transaction, no LISTEN state). Second, a unit of work
that declares a key runs optimistically at `REPEATABLE READ READ ONLY`
until the process observes it write; the first write raises `ReadOnlyRetry`
(the OCC loop re-runs the request), records the key as a writer, and every
later unit under that key runs at SERIALIZABLE from the start.
"""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { uuid4 }
import from jaclang.server.session { Session, unit_writes_recorded }
import from jaclang.runtime.exceptions { ReadOnlyRetry }
import from jaclang.data.store { PgStore, Store, TxnIsolation }
import from jaclang.data.pgpool { drain_all, pool_stats }


def _mk_session(td: str) -> Session {
    return Session(base_path=td, target_path=str(Path(td) / 'app.jac'));
}


def _store(s: Session) -> Store {
    st = s.store;
    assert st is not None;
    return st;
}


def _sireads(s: Session) -> int {
    r = _store(s).rows(
        "SELECT count(*) FROM pg_locks"
        " WHERE mode = 'SIReadLock' AND pid = pg_backend_pid()",
        {}
    );
    return int(r[0][0]);
}


test "ro units: a keyed unit with no writes runs on the read tier" {
    with TemporaryDirectory() as td {
        s = _mk_session(td);
        try {
            s.unit_enter('walker:test.ro_probe');
            try {
                s.read_barrier();
                assert _store(s).txn_isolation() is TxnIsolation.SNAPSHOT_READ_ONLY , (
                    'a keyed unit never seen writing must open the read tier, '
                    f"got {_store(s).txn_isolation()}"
                );
                s.batch_get([uuid4(), uuid4()]);
                assert _sireads(s) == 0 , (
                    f"read-only unit took {_sireads(s)} SIReadLocks, expected 0"
                );
            } finally {
                s.unit_exit();
            }
            assert not _store(s).in_txn();
        } finally {
            s.close();
        }
    }
}


test "ro units: an unkeyed unit keeps SERIALIZABLE" {
    with TemporaryDirectory() as td {
        s = _mk_session(td);
        try {
            s.unit_enter();
            try {
                s.read_barrier();
                assert _store(s).txn_isolation() is TxnIsolation.SERIALIZABLE;
            } finally {
                s.unit_exit();
            }
        } finally {
            s.close();
        }
    }
}


test "ro units: the first write raises ReadOnlyRetry and records the key" {
    key = 'walker:test.turncoat_writer';
    with TemporaryDirectory() as td {
        s = _mk_session(td);
        try {
            s.unit_enter(key);
            raised = False;
            try {
                s.read_barrier();
                assert _store(s).txn_isolation() is TxnIsolation.SNAPSHOT_READ_ONLY;
                s.delete(uuid4());
                try {
                    s.read_barrier();
                } except ReadOnlyRetry {
                    raised = True;
                }
            } finally {
                s.unit_exit();
            }
            assert raised , (
                'a write inside a read-tier unit must raise ReadOnlyRetry so '
                'the OCC loop re-runs the request at SERIALIZABLE'
            );
            assert unit_writes_recorded(key) , (
                'the writing unit key must be recorded so later runs skip the '
                'read tier'
            );
            assert not _store(s).in_txn() , (
                'the aborted read snapshot must not stay open'
            );
            s.abort();
            s.unit_enter(key);
            try {
                s.read_barrier();
                assert _store(s).txn_isolation() is TxnIsolation.SERIALIZABLE , (
                    'a recorded writer must run at SERIALIZABLE from the start'
                );
            } finally {
                s.unit_exit();
            }
        } finally {
            s.close();
        }
    }
}


test "pool: closing a store parks its connection for the next store" {
    with TemporaryDirectory() as td {
        drain_all();
        s = _mk_session(td);
        st = _store(s);
        st.rows('SELECT 1', {});
        first = getattr(st, '_conn');
        assert first is not None;
        info = getattr(st, 'conninfo');
        s.close();
        assert sum(pool_stats().values()) >= 1 , (
            'close must park the healthy wire connection, not discard it'
        );
        st2 = PgStore(conninfo=info);
        st2.rows('SELECT 1', {});
        assert getattr(st2, '_conn') is first , (
            'the next store for the same conninfo must reuse the parked '
            'connection instead of dialing'
        );
        st2.close();
        drain_all();
    }
}


test "pool: a parked connection comes back with no open transaction" {
    with TemporaryDirectory() as td {
        drain_all();
        s = _mk_session(td);
        st = _store(s);
        st.begin(TxnIsolation.SERIALIZABLE);
        st.rows('SELECT 1', {});
        first = getattr(st, '_conn');
        info = getattr(st, 'conninfo');
        st.close();
        st2 = PgStore(conninfo=info);
        got = st2.rows("SELECT current_setting('transaction_isolation')", {});
        assert getattr(st2, '_conn') is first;
        assert not st2.in_txn();
        assert str(got[0][0]) in ('read committed', 'default') , (
            f"parked connection kept transaction state: {got[0][0]}"
        );
        st2.close();
        s.close();
        drain_all();
    }
}


test "pool: JAC_DB_POOL=0 disables parking" {
    with TemporaryDirectory() as td {
        drain_all();
        os.environ['JAC_DB_POOL'] = '0';
        try {
            s = _mk_session(td);
            st = _store(s);
            st.rows('SELECT 1', {});
            s.close();
            assert sum(pool_stats().values()) == 0 , (
                'with pooling disabled, close must not park connections'
            );
        } finally {
            os.environ.pop('JAC_DB_POOL', None);
        }
    }
}
