"""The process's state backend: shared through Postgres, or in-process.

`shared` says whether more than one process must agree on the state (N
workers, N replicas, a fleet behind a gateway). When it does, the backend
is the project database; there is no silent fallback to process memory,
because per-process limits and locks in a fleet are exactly the bugs the
shared backend exists to prevent.
"""
import logging;
import os;
import from jaclang.scale.state.state_backend { StateBackend, InProcessStateBackend }
import from jaclang.server.shared_store { shared_store, shared_store_failure }
import from jaclang.scale.state.pg_state_backend { PgStateBackend }

glob logger = logging.getLogger(__name__),
     _backend_holder: dict[str, StateBackend] = {};


def _after_fork_in_child {
    _backend_holder.clear();
}


with entry {
    if hasattr(os, 'register_at_fork') {
        os.register_at_fork(after_in_child=_after_fork_in_child);
    }
}


def in_fleet -> bool {
    return bool(os.environ.get('KUBERNETES_SERVICE_HOST', '').strip())
        or os.environ.get('JAC_SV_SIBLING') == '1';
}


def get_state_backend(shared: bool = False) -> StateBackend {
    backend = _backend_holder.get("default");
    if backend is not None {
        return backend;
    }
    if shared or in_fleet() {
        store = shared_store();
        if store is None {
            raise RuntimeError(
                "shared state needs a reachable database "
                f"({shared_store_failure() or 'no database resolved'}); rate limits "
                "and locks cannot be kept per process across a fleet"
            );
        }
        backend = PgStateBackend(store=store);
    } else {
        backend = InProcessStateBackend();
    }
    _backend_holder["default"] = backend;
    return backend;
}
