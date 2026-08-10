import logging;
import threading;
import jaclang.runtimelib.serving.client as sv_http;
import from logging.handlers { MemoryHandler }
import from jaclang.runtimelib { sv_client }
import from jaclang.scale.plugin { JacScalePlugin }
import from jaclang.scale.runtime.rpc.breaker {
    _BREAKER_TRIP_THRESHOLD,
    _breaker_force_cooldown_elapsed,
    _breaker_force_probe_lease_expired,
    _breaker_peek,
    _breaker_reset,
    breaker_record_failure,
    breaker_record_success,
    breaker_should_skip
}
import from jaclang.scale.runtime.rpc.rpc { _SV_MAX_ATTEMPTS }


def _install_failing_transport(entry_point: str, calls: list) -> any {
    import from jaclang.runtimelib.serving.client { ClientConnectionError }
    original = getattr(sv_http, entry_point);

    def fake(*args: any, **kwargs: any) -> any {
        calls.append((args, kwargs));
        raise ClientConnectionError(detail="connection refused");
    }
    setattr(sv_http, entry_point, fake);
    return original;
}

def _install_json_transport(payload: any, calls: list) -> any {
    original = sv_http.post_stream_aware_sync;

    def fake(*args: any, **kwargs: any) -> tuple[str, any] {
        calls.append((args, kwargs));
        return ('json', payload);
    }
    sv_http.post_stream_aware_sync = fake;
    return original;
}

def _trip_breaker(provider: str) {
    for _ in range(_BREAKER_TRIP_THRESHOLD) {
        breaker_record_failure(provider);
    }
}

def _capture_breaker_logs(fn: any) -> list[str] {
    import from jaclang.scale.runtime.rpc.breaker { _logger }
    capture = MemoryHandler(1000);
    previous_level = _logger.level;
    _logger.addHandler(capture);
    _logger.setLevel(logging.INFO);
    try {
        fn();
        return [r.getMessage() for r in capture.buffer];
    } finally {
        _logger.setLevel(previous_level);
        _logger.removeHandler(capture);
    }
}


test "breaker trips OPEN after N consecutive transport failures and fails fast" {
    mod = "breaker_open_test";
    _breaker_reset(mod);

    _trip_breaker(mod);
    assert breaker_should_skip(mod);

    raised_msg = "";
    try {
        JacScalePlugin.sv_service_call(mod, "anything", {});
    } except RuntimeError as e {
        raised_msg = str(e);
    }
    assert "open circuit breaker" in raised_msg;

    _breaker_reset(mod);
}


test "breaker success recorder resets failure count" {
    mod = "breaker_reset_test";
    _breaker_reset(mod);

    for _ in range(_BREAKER_TRIP_THRESHOLD - 1) {
        breaker_record_failure(mod);
    }
    assert not breaker_should_skip(mod);

    breaker_record_success(mod);

    for _ in range(_BREAKER_TRIP_THRESHOLD - 1) {
        breaker_record_failure(mod);
    }
    assert not breaker_should_skip(mod);

    _breaker_reset(mod);
}


test "probe success closes the breaker" {
    mod = "breaker_probe_success_test";
    _breaker_reset(mod);

    _trip_breaker(mod);
    assert breaker_should_skip(mod);

    _breaker_force_cooldown_elapsed(mod);
    assert not breaker_should_skip(mod);
    st = _breaker_peek(mod);
    assert st is not None and st["state"] == "PROBING";

    breaker_record_success(mod);
    st = _breaker_peek(mod);
    assert st is not None and st["state"] == "CLOSED";
    assert st["fails"] == 0;

    _breaker_reset(mod);
}


test "probe failure re-opens the breaker with a fresh cooldown" {
    import time;

    mod = "breaker_probe_reopen_test";
    _breaker_reset(mod);

    _trip_breaker(mod);
    assert breaker_should_skip(mod);

    _breaker_force_cooldown_elapsed(mod);
    assert not breaker_should_skip(mod);
    st = _breaker_peek(mod);
    assert st is not None and st["state"] == "PROBING";

    before = time.time();
    breaker_record_failure(mod);
    after = time.time();

    st = _breaker_peek(mod);
    assert st is not None and st["state"] == "OPEN";
    assert before <= st["opened_at"] <= after;

    assert breaker_should_skip(mod);

    _breaker_reset(mod);
}


test "only one caller is admitted while a probe is in flight" {
    mod = "breaker_single_probe_test";
    _breaker_reset(mod);

    _trip_breaker(mod);
    _breaker_force_cooldown_elapsed(mod);

    assert not breaker_should_skip(mod) , "the first caller after cooldown must probe";
    for _ in range(5) {
        assert breaker_should_skip(mod) , (
            "callers arriving during a probe must still be shed"
        );
    }

    st = _breaker_peek(mod);
    assert st is not None and st["state"] == "PROBING";

    _breaker_reset(mod);
}


test "concurrent callers after cooldown admit exactly one probe" {
    mod = "breaker_concurrent_probe_test";
    _breaker_reset(mod);

    _trip_breaker(mod);
    _breaker_force_cooldown_elapsed(mod);

    thread_count = 16;
    gate = threading.Barrier(thread_count);
    admitted: list[bool] = [];
    admitted_lock = threading.Lock();

    def race {
        gate.wait();
        skipped = breaker_should_skip(mod);
        if not skipped {
            with admitted_lock {
                admitted.append(True);
            }
        }
    }

    workers = [threading.Thread(target=race) for _ in range(thread_count)];
    for w in workers {
        w.start();
    }
    for w in workers {
        w.join();
    }

    assert len(admitted) == 1 , (
        f"expected a single half-open probe, {len(admitted)} callers were admitted"
    );

    _breaker_reset(mod);
}


test "an abandoned probe is reclaimed once its lease expires" {
    mod = "breaker_probe_lease_test";
    _breaker_reset(mod);

    _trip_breaker(mod);
    _breaker_force_cooldown_elapsed(mod);
    assert not breaker_should_skip(mod);
    assert breaker_should_skip(mod);

    _breaker_force_probe_lease_expired(mod);
    assert not breaker_should_skip(mod) , (
        "a probe that never reported must not wedge the breaker"
    );
    st = _breaker_peek(mod);
    assert st is not None and st["state"] == "PROBING";

    _breaker_reset(mod);
}


test "failures recorded while OPEN do not extend the cooldown" {
    mod = "breaker_cooldown_extend_test";
    _breaker_reset(mod);

    _trip_breaker(mod);
    opened_at = _breaker_peek(mod)["opened_at"];

    for _ in range(_BREAKER_TRIP_THRESHOLD) {
        breaker_record_failure(mod);
    }

    assert _breaker_peek(mod)["opened_at"] == opened_at;

    _breaker_reset(mod);
}


test "every failed RPC attempt counts as one breaker failure" {
    mod = "breaker_per_attempt_test";
    _breaker_reset(mod);
    calls: list = [];
    original_post = _install_failing_transport("post_stream_aware_sync", calls);

    try {
        sv_client.register(mod, "http://demo.invalid");
        raised_msg = "";
        try {
            JacScalePlugin.sv_service_call(mod, "ping", {});
        } except RuntimeError as e {
            raised_msg = str(e);
        }

        assert len(calls) == _SV_MAX_ATTEMPTS;
        assert f"failed after {_SV_MAX_ATTEMPTS} attempts" in raised_msg;
        st = _breaker_peek(mod);
        assert st is not None and st["fails"] == _SV_MAX_ATTEMPTS , (
            f"expected one breaker failure per attempt, got {st}"
        );
    } finally {
        sv_http.post_stream_aware_sync = original_post;
        sv_client.unregister(mod);
        _breaker_reset(mod);
    }
}


test "every failed walker attempt counts as one breaker failure" {
    mod = "breaker_walker_per_attempt_test";
    _breaker_reset(mod);
    calls: list = [];
    original_request = _install_failing_transport("request_sync", calls);

    try {
        sv_client.register(mod, "http://demo.invalid");
        try {
            JacScalePlugin.sv_walker_call(mod, "Spawner", {}, None);
        } except RuntimeError {
            ;
        }

        assert len(calls) == _SV_MAX_ATTEMPTS;
        st = _breaker_peek(mod);
        assert st is not None and st["fails"] == _SV_MAX_ATTEMPTS , (
            f"expected one breaker failure per attempt, got {st}"
        );
    } finally {
        sv_http.request_sync = original_request;
        sv_client.unregister(mod);
        _breaker_reset(mod);
    }
}


test "a call that trips the breaker abandons its remaining retries" {
    mod = "breaker_abandon_retries_test";
    _breaker_reset(mod);
    calls: list = [];
    original_post = _install_failing_transport("post_stream_aware_sync", calls);

    def attempt_call -> str {
        try {
            JacScalePlugin.sv_service_call(mod, "ping", {});
        } except RuntimeError as e {
            return str(e);
        }
        return "";
    }

    try {
        sv_client.register(mod, "http://demo.invalid");

        attempt_call();
        second_msg = attempt_call();

        assert breaker_should_skip(mod) , (
            "the breaker must open once failed attempts reach the threshold"
        );
        assert len(calls) == _BREAKER_TRIP_THRESHOLD , (
            f"no attempt may be sent after the breaker opens, sent {len(calls)}"
        );
        assert "failed after 2 attempts" in second_msg;

        third_msg = attempt_call();
        assert "open circuit breaker" in third_msg;
        assert len(calls) == _BREAKER_TRIP_THRESHOLD;
    } finally {
        sv_http.post_stream_aware_sync = original_post;
        sv_client.unregister(mod);
        _breaker_reset(mod);
    }
}


test "application error envelope does NOT trip the breaker" {
    mod = "breaker_app_err_test";
    _breaker_reset(mod);
    calls: list = [];
    original_post = _install_json_transport(
        {"ok": False, "error": {"code": "X", "message": "nope"}}, calls
    );

    try {
        sv_client.register(mod, "http://demo.invalid");
        for _ in range(_BREAKER_TRIP_THRESHOLD) {
            try {
                JacScalePlugin.sv_service_call(mod, "fail", {});
            } except RuntimeError {
                ;
            }
        }

        assert len(calls) == _BREAKER_TRIP_THRESHOLD;
        assert not breaker_should_skip(mod);
    } finally {
        sv_http.post_stream_aware_sync = original_post;
        sv_client.unregister(mod);
        _breaker_reset(mod);
    }
}


test "breaker state transitions are logged" {
    mod = "breaker_transition_log_test";
    _breaker_reset(mod);

    def drive {
        _trip_breaker(mod);
        _breaker_force_cooldown_elapsed(mod);
        breaker_should_skip(mod);
        breaker_record_success(mod);
    }

    messages = _capture_breaker_logs(drive);

    for state in ["OPEN", "PROBING", "CLOSED"] {
        matched = [
            m
            for m in messages
            if m.startswith(f"circuit breaker {state} ")
        ];
        assert len(matched) == 1 , f"expected one {state} transition log, got {messages}";
        assert mod in matched[0];
    }

    _breaker_reset(mod);
}
