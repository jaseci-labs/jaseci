"""The gateway's rate limiter reaches the shared state backend.

get_state_backend's shared branch had exactly one caller, and that caller
gated it on a 'scale_enabled' key no loader ever emitted, so PgStateBackend
was unreachable in any deploy: every replica kept its own token buckets and
a fleet of N replicas enforced N times the configured limit, silently. The
loud fallback line inside the factory could never fire either, because the
branch that logs it was never entered. The gateway now asks for shared
state explicitly. Pinned here: the factory answers PgStateBackend when the
shared store is reachable, falls back in-process when it is not, and two
limiters over one store consume one budget the way two pods must."""

import os;
import jaclang.scale.state.factory as factory_mod;
import jaclang.scale.persistence.pg as pg_mod;
import from jaclang.scale.state.factory { get_state_backend }
import from jaclang.scale.state.pg_state_backend { PgStateBackend }
import from jaclang.scale.state.state_backend { InProcessStateBackend }
import from jaclang.scale.runtime.middleware.rate_limit { StateBackendRateLimiter }

glob _DEAD_URL = 'postgresql://jac:jac@127.0.0.1:1/jac';


def _fresh_backend(shared: bool) -> any {
    factory_mod._backend_holder.clear();
    return get_state_backend(shared);
}


test "without shared state the factory answers in-process" {
    backend = _fresh_backend(False);
    assert isinstance(backend, InProcessStateBackend);
}


test "an unreachable store falls back in-process instead of failing the boot" {
    old = os.environ.get("JAC_DB_URL");
    pg_mod._holder.clear();
    os.environ["JAC_DB_URL"] = _DEAD_URL;
    try {
        backend = _fresh_backend(True);
        assert isinstance(backend, InProcessStateBackend);
    } finally {
        if old is None {
            os.environ.pop("JAC_DB_URL", None);
        } else {
            os.environ["JAC_DB_URL"] = old;
        }
        pg_mod._holder.clear();
        factory_mod._backend_holder.clear();
    }
}


test "with shared state and a reachable store the factory answers pg" {
    backend = _fresh_backend(True);
    assert isinstance(backend, PgStateBackend);
}


test "two limiters over one store consume one budget" {
    store = pg_mod.shared_store();
    assert store is not None , (
        'these tests need the embedded store; the previous test already built it'
    );
    pod_a = StateBackendRateLimiter(
        backend=PgStateBackend(store=store), rate_per_sec=0.001, capacity=2.0
    );
    pod_b = StateBackendRateLimiter(
        backend=PgStateBackend(store=store), rate_per_sec=0.001, capacity=2.0
    );
    (a1, _) = pod_a.consume("fleet-ip");
    (b1, _) = pod_b.consume("fleet-ip");
    (a2, _) = pod_a.consume("fleet-ip");
    assert a1 and b1;
    assert not a2;
    factory_mod._backend_holder.clear();
}
