import logging;
import from threading { Lock as _BreakerLock }

glob _BREAKER_TRIP_THRESHOLD: int = 5,
     _BREAKER_COOLDOWN_SECONDS: float = 30.0,
     _BREAKER_PROBE_LEASE_SECONDS: float = 30.0,
     _breaker_state: dict[str, dict] = {},
     _breaker_lock = _BreakerLock(),
     _logger = logging.getLogger(__name__);

def _closed_state -> dict {
    return {"state": "CLOSED", "fails": 0, "opened_at": 0.0, "probe_started_at": 0.0};
}

def _log_transition(provider: str, previous: str, current: str) {
    if previous == current {
        return;
    }
    if current == "OPEN" {
        _logger.warning(
            f"circuit breaker OPEN for '{provider}' (was {previous}): shedding calls "
                + f"for {_BREAKER_COOLDOWN_SECONDS}s"
        );
    } elif current == "PROBING" {
        _logger.info(
            f"circuit breaker PROBING '{provider}' (was {previous}): admitting a "
                + "single trial call"
        );
    } else {
        _logger.info(f"circuit breaker CLOSED for '{provider}' (was {previous})");
    }
}

def _lease_expired(st: dict, now: float) -> bool {
    return (now - st.get("probe_started_at", 0.0)) >= _BREAKER_PROBE_LEASE_SECONDS;
}

def _cooldown_elapsed(st: dict, now: float) -> bool {
    return (now - st.get("opened_at", 0.0)) >= _BREAKER_COOLDOWN_SECONDS;
}

def breaker_should_skip(provider: str) -> bool {
    import time;
    now = time.time();
    previous = "CLOSED";
    admitted = False;

    with _breaker_lock {
        st = _breaker_state.get(provider);
        if st is None {
            return False;
        }
        previous = st.get("state", "CLOSED");
        if previous == "CLOSED" {
            return False;
        }
        admitted = _cooldown_elapsed(st, now)
            if previous == "OPEN"
            else _lease_expired(st, now);
        if admitted {
            st["state"] = "PROBING";
            st["probe_started_at"] = now;
        }
    }

    if admitted {
        _log_transition(provider, previous, "PROBING");
    }
    return not admitted;
}

def breaker_record_success(provider: str) {
    previous = "CLOSED";
    with _breaker_lock {
        st = _breaker_state.get(provider);
        previous = st.get("state", "CLOSED") if st is not None else "CLOSED";
        _breaker_state[provider] = _closed_state();
    }
    _log_transition(provider, previous, "CLOSED");
}

def breaker_record_failure(provider: str) {
    import time;
    now = time.time();
    previous = "CLOSED";
    current = "CLOSED";

    with _breaker_lock {
        st = _breaker_state.get(provider) or _closed_state();
        previous = st.get("state", "CLOSED");
        if previous == "OPEN" {
            return;
        }
        current = previous;
        if previous == "PROBING" {
            current = "OPEN";
        } else {
            st["fails"] = st.get("fails", 0) + 1;
            if st["fails"] >= _BREAKER_TRIP_THRESHOLD {
                current = "OPEN";
            }
        }
        if current == "OPEN" {
            st["state"] = "OPEN";
            st["opened_at"] = now;
        }
        _breaker_state[provider] = st;
    }

    _log_transition(provider, previous, current);
}

def _breaker_reset(provider: str) {
    with _breaker_lock {
        if provider in _breaker_state {
            del _breaker_state[provider];
        }
    }
}

def _breaker_peek(provider: str) -> dict | None {
    with _breaker_lock {
        st = _breaker_state.get(provider);
        return dict(st) if st is not None else None;
    }
}

def _breaker_force_cooldown_elapsed(provider: str) {
    with _breaker_lock {
        st = _breaker_state.get(provider);
        if st is not None {
            st["opened_at"] = 0.0;
        }
    }
}

def _breaker_force_probe_lease_expired(provider: str) {
    with _breaker_lock {
        st = _breaker_state.get(provider);
        if st is not None {
            st["probe_started_at"] = 0.0;
        }
    }
}
