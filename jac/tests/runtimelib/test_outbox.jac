"""Outbox: durable deferred cross-app walker spawns (SPEC section 6).

Every test pins an explicit sqlite-backed OutboxStore in a temp dir via
use_store(), so nothing here touches the project's embedded Postgres. Delivery
is exercised two ways: by patching sv_client.spawn_walker directly (the seam
the outbox calls, independent of transport) and through
sv_client.register_test_client (the transport-level test hook)."""

import os;
import time;
import unittest.mock;
import from tempfile { TemporaryDirectory }
import from jaclang.server { sv_client }
import from jaclang.server.bridge { BridgeRejected, BridgeUnavailable }
import from jaclang.server.outbox {
    OutboxEntry,
    STATUS_DEAD,
    STATUS_DELIVERED,
    STATUS_PENDING,
    SqliteOutboxStore,
    backoff_seconds,
    cached_result,
    dead_letters,
    default_idempotency_key,
    deliver_pending,
    enqueue,
    remember_idempotency_key,
    seen_idempotency_key,
    start_worker,
    stop_worker,
    use_store,
    worker_running
}

def _entry(store: any, key: str) -> OutboxEntry {
    item = store.get_by_key(key);
    if item is None {
        raise AssertionError(f"no outbox entry for {key}");
    }
    return item;
}


obj _Recorder {
    has calls: list[dict] = [],
        fail_with: (Exception | None) = None;
}


def _fake_spawn(recorder: _Recorder) -> any {
    async def fake_spawn(
        app: str, `walker: str, kwargs: dict, stub_cls: any, idempotency_key: str = ""
    ) -> any {
        recorder.calls.append(
            {
                "app": app,
                "walker": `walker,
                "kwargs": kwargs,
                "idempotency_key": idempotency_key
            }
        );
        if recorder.fail_with is not None {
            raise recorder.fail_with;
        }
        return {"ok": True};
    }
    return fake_spawn;
}


def _make_due(store: SqliteOutboxStore, key: str) {
    item = _entry(store, key);
    assert item is not None;
    item.next_attempt_at = 0.0;
    store.update(item);
}


obj _StubResp {
    has payload: dict;

    def json -> any {
        return self.payload;
    }
}


obj _StubClient {
    has paths: list[str] = [],
        headers_seen: list[dict] = [];

    def post(path: str, json: any = None, headers: any = None) -> _StubResp {
        self.paths.append(path);
        self.headers_seen.append(dict(headers or {}));
        return _StubResp(payload={"ok": True, "data": {"result": {"greeting": "hi"}}});
    }
}


test "enqueue defaults the idempotency key and dedupes by it" {
    with TemporaryDirectory() as tmp {
        store = SqliteOutboxStore(path=os.path.join(tmp, "outbox.sqlite"));
        use_store(store);
        try {
            first = enqueue("scoring", "Greet", {"name": "ada", "n": 1});
            again = enqueue("scoring", "Greet", {"n": 1, "name": "ada"});
            other = enqueue("scoring", "Greet", {"name": "bob"});
            assert first == again;
            assert other != first;

            key = default_idempotency_key("scoring", "Greet", {"name": "ada", "n": 1});
            assert len(key) == 32;
            stored = _entry(store, key);
            assert stored is not None;
            assert stored.id == first;
            assert stored.app == "scoring";
            assert stored.`walker == "Greet";
            assert stored.kwargs == {"name": "ada", "n": 1};
            assert stored.status == STATUS_PENDING;
            assert stored.attempts == 0;
            assert stored.created_at > 0.0;

            explicit_a = enqueue("scoring", "Greet", {"name": "x"}, "req-42");
            explicit_b = enqueue("scoring", "Greet", {"name": "y"}, "req-42");
            assert explicit_a == explicit_b;
            assert len(store.list_pending(time.time() + 1.0, 100)) == 3;
        } finally {
            use_store(None);
        }
    }
}


test "backoff doubles per attempt and caps at five minutes" {
    assert backoff_seconds(0) == 1.0;
    assert backoff_seconds(1) == 1.0;
    assert backoff_seconds(2) == 2.0;
    assert backoff_seconds(3) == 4.0;
    assert backoff_seconds(8) == 128.0;
    assert backoff_seconds(9) == 256.0;
    assert backoff_seconds(10) == 300.0;
    assert backoff_seconds(40) == 300.0;
}


test "deliver_pending retries with backoff then dead-letters after max attempts" {
    with TemporaryDirectory() as tmp {
        store = SqliteOutboxStore(path=os.path.join(tmp, "outbox.sqlite"));
        use_store(store);
        recorder = _Recorder(fail_with=BridgeUnavailable(app="scoring", detail="down"));
        patcher: any = unittest.mock.patch.object(
            sv_client, "spawn_walker", _fake_spawn(recorder)
        );
        try {
            with patcher {
                key = default_idempotency_key("scoring", "Greet", {"name": "ada"});
                enqueue("scoring", "Greet", {"name": "ada"});
                before = time.time();
                assert deliver_pending(max_attempts=3) == 0;
                item = _entry(store, key);
                assert item is not None;
                assert item.status == STATUS_PENDING;
                assert item.attempts == 1;
                assert item.last_error.startswith("BridgeUnavailable");
                assert item.next_attempt_at >= before + backoff_seconds(1);
                assert deliver_pending(max_attempts=3) == 0;
                assert _entry(store, key).attempts == 1;
                _make_due(store, key);
                assert deliver_pending(max_attempts=3) == 0;
                item = _entry(store, key);
                assert item.attempts == 2;
                assert item.status == STATUS_PENDING;
                assert item.next_attempt_at >= before + backoff_seconds(2);
                _make_due(store, key);
                assert deliver_pending(max_attempts=3) == 0;
                item = _entry(store, key);
                assert item.attempts == 3;
                assert item.status == STATUS_DEAD;
                dead = dead_letters();
                assert [d.id for d in dead] == [item.id];
                assert len(recorder.calls) == 3;
                _make_due(store, key);
                assert deliver_pending(max_attempts=3) == 0;
                assert len(recorder.calls) == 3;
            }
        } finally {
            use_store(None);
        }
    }
}


test "a rejected bridge call dead-letters on the first attempt" {
    with TemporaryDirectory() as tmp {
        store = SqliteOutboxStore(path=os.path.join(tmp, "outbox.sqlite"));
        use_store(store);
        recorder = _Recorder(
            fail_with=BridgeRejected(
                app="scoring", name="Greet", detail="404", status=404
            )
        );
        patcher: any = unittest.mock.patch.object(
            sv_client, "spawn_walker", _fake_spawn(recorder)
        );
        try {
            with patcher {
                key = default_idempotency_key("scoring", "Greet", {});
                enqueue("scoring", "Greet", {});
                assert deliver_pending() == 0;
                item = _entry(store, key);
                assert item.status == STATUS_DEAD;
                assert item.attempts == 1;
                assert item.last_error.startswith("BridgeRejected");
            }
        } finally {
            use_store(None);
        }
    }
}


test "deliver_pending marks delivered and passes the idempotency key" {
    with TemporaryDirectory() as tmp {
        store = SqliteOutboxStore(path=os.path.join(tmp, "outbox.sqlite"));
        use_store(store);
        recorder = _Recorder();
        patcher: any = unittest.mock.patch.object(
            sv_client, "spawn_walker", _fake_spawn(recorder)
        );
        try {
            with patcher {
                enqueue("scoring", "Greet", {"name": "ada"});
                enqueue("scoring", "Greet", {"name": "bob"}, "explicit-key");
                assert deliver_pending() == 2;
                assert deliver_pending() == 0;
                keys = sorted(c["idempotency_key"] for c in recorder.calls);
                assert keys
                    == sorted(
                        [
                            default_idempotency_key(
                                "scoring", "Greet", {"name": "ada"}
                            ),
                            "explicit-key"
                        ]
                    );
                for c in recorder.calls {
                    assert c["app"] == "scoring";
                    assert c["walker"] == "Greet";
                }
                done = _entry(store, "explicit-key");
                assert done.status == STATUS_DELIVERED;
                assert done.attempts == 1;
                assert done.last_error == "";
                assert dead_letters() == [];
            }
        } finally {
            use_store(None);
        }
    }
}


test "delivery reaches a provider registered via sv_client.register_test_client" {
    with TemporaryDirectory() as tmp {
        store = SqliteOutboxStore(path=os.path.join(tmp, "outbox.sqlite"));
        use_store(store);
        client = _StubClient();
        sv_client.register_test_client("scoring", client);
        try {
            key = default_idempotency_key("scoring", "Greet", {"name": "ada"});
            enqueue("scoring", "Greet", {"name": "ada"});
            assert deliver_pending() == 1;
            assert client.paths == ["/walker/Greet"];
            assert len(client.headers_seen) == 1;
            assert _entry(store, key).status == STATUS_DELIVERED;
        } finally {
            sv_client._test_clients.pop("scoring", None);
            use_store(None);
        }
    }
}


test "receiver-side dedupe remembers keys with a ttl and caches the result" {
    with TemporaryDirectory() as tmp {
        store = SqliteOutboxStore(path=os.path.join(tmp, "outbox.sqlite"));
        use_store(store);
        try {
            assert not seen_idempotency_key("k1");
            assert cached_result("k1") is None;

            remember_idempotency_key("k1", ttl_s=60, result='{"ok":true}');
            assert seen_idempotency_key("k1");
            assert cached_result("k1") == '{"ok":true}';

            remember_idempotency_key("k2");
            assert seen_idempotency_key("k2");
            assert cached_result("k2") == "";

            remember_idempotency_key("k3", ttl_s=0);
            assert not seen_idempotency_key("k3");

            assert not seen_idempotency_key("");
            assert store.recall_key("k1", time.time()) == '{"ok":true}';
            assert store.recall_key("k1", time.time() + 61.0) is None;
        } finally {
            use_store(None);
        }
    }
}


test "start_worker is idempotent and the daemon thread delivers on its own" {
    with TemporaryDirectory() as tmp {
        store = SqliteOutboxStore(path=os.path.join(tmp, "outbox.sqlite"));
        use_store(store);
        recorder = _Recorder();
        patcher: any = unittest.mock.patch.object(
            sv_client, "spawn_walker", _fake_spawn(recorder)
        );
        try {
            with patcher {
                key = default_idempotency_key("scoring", "Greet", {"name": "ada"});
                enqueue("scoring", "Greet", {"name": "ada"});
                start_worker(interval_s=0.02);
                start_worker(interval_s=0.02);
                assert worker_running();
                deadline = time.time() + 5.0;
                while time.time() < deadline {
                    if _entry(store, key).status == STATUS_DELIVERED {
                        break;
                    }
                    time.sleep(0.02);
                }
                assert _entry(store, key).status == STATUS_DELIVERED;
                assert len(recorder.calls) == 1;
                stop_worker();
                assert not worker_running();
            }
        } finally {
            stop_worker();
            use_store(None);
        }
    }
}
