"""Channel identity for PgStore LISTEN/NOTIFY (#8046).

notify() and listen() must agree on what a channel *is*. They used to
disagree: listen() ran LISTEN on a sanitized identifier (every non-ident
character folded to '_') while notify() published the raw string through
pg_notify, so any channel carrying a ':' namespace separator lost every
message, and a listener on 'cache:invalidate' was woken by the logically
distinct 'cache_invalidate'. Both failures were completely silent.

These tests pin the contract from both sides: a channel name is delivered
to exactly the listeners that asked for that exact name, whatever bytes it
contains, including names longer than the 63-byte limit Postgres puts on a
channel identifier.
"""

import time;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtimelib.pgembed { PgRuntime }
import from jaclang.runtimelib.session { shared_pg_data_dir, project_db_name }
import from jaclang.runtimelib.store { PgStore }

glob _LONG_STEM = 'cache:' + ('x' * 70) + ':';


def _pair(td: str) -> tuple {
    # Publisher and subscriber on separate connections: the same path a
    # second pod takes, and it makes delivery push-driven rather than
    # waiting out the listen loop's idle poll.
    target = str(Path(td) / 'app.jac');
    rt = PgRuntime(data_dir=shared_pg_data_dir(), database=project_db_name(td, target));
    info = rt.ensure();
    return (
        PgStore(conninfo=info, ensure_cb=rt.ensure),
        PgStore(conninfo=info, ensure_cb=rt.ensure)
    );
}


def _settle {
    # The listen loop parks in select() with the LISTEN already registered;
    # give the thread a moment to reach it before publishing.
    time.sleep(0.5);
}


def _wait_for(box: list, want: int, seconds: float = 10.0) {
    deadline = time.monotonic() + seconds;
    while len(box) < want and time.monotonic() < deadline {
        time.sleep(0.05);
    }
}


test "notify reaches a listener on a channel with a namespace separator" {
    with TemporaryDirectory() as td {
        (sub, pub) = _pair(td);
        got: list[str] = [];
        try {
            sub.listen(
                'cache:invalidate', lambda (payload: str) { got.append(payload); }
            );
            _settle();
            pub.notify('cache:invalidate', 'A');
            _wait_for(got, 1);
        } finally {
            sub.close();
            pub.close();
        }
        assert got == ['A'] , (
            "notify('cache:invalidate') never reached its own listener, got "
            f"{got}: notify and listen disagree on the channel identifier"
        );
    }
}


test "channels that sanitize alike never cross-deliver" {
    with TemporaryDirectory() as td {
        (sub, pub) = _pair(td);
        colon: list[str] = [];
        plain: list[str] = [];
        try {
            sub.listen(
                'cache:invalidate', lambda (payload: str) { colon.append(payload); }
            );
            sub.listen(
                'cache_invalidate', lambda (payload: str) { plain.append(payload); }
            );
            _settle();
            pub.notify('cache_invalidate', 'B');
            _wait_for(plain, 1);
            # Let any stray cross-delivery land before counting.
            time.sleep(0.5);
        } finally {
            sub.close();
            pub.close();
        }
        assert plain == ['B'] , f"the 'cache_invalidate' listener missed its own message, got {plain}";
        assert colon == [] , (
            "the 'cache:invalidate' listener received traffic published to the "
            f"logically distinct 'cache_invalidate' channel: {colon}"
        );
    }
}


test "both directions of a namespaced pair stay separated" {
    with TemporaryDirectory() as td {
        (sub, pub) = _pair(td);
        colon: list[str] = [];
        plain: list[str] = [];
        try {
            sub.listen(
                'cache:invalidate', lambda (payload: str) { colon.append(payload); }
            );
            sub.listen(
                'cache_invalidate', lambda (payload: str) { plain.append(payload); }
            );
            _settle();
            pub.notify('cache:invalidate', 'A');
            pub.notify('cache_invalidate', 'B');
            _wait_for(colon, 1);
            _wait_for(plain, 1);
            time.sleep(0.5);
        } finally {
            sub.close();
            pub.close();
        }
        assert colon == ['A'] , f"expected only 'A' on 'cache:invalidate', got {colon}";
        assert plain == ['B'] , f"expected only 'B' on 'cache_invalidate', got {plain}";
    }
}


test "channel names past the postgres identifier limit round trip intact" {
    with TemporaryDirectory() as td {
        (sub, pub) = _pair(td);
        one = _LONG_STEM + 'one';
        two = _LONG_STEM + 'two';
        got_one: list[str] = [];
        got_two: list[str] = [];
        try {
            sub.listen(one, lambda (payload: str) { got_one.append(payload); });
            sub.listen(two, lambda (payload: str) { got_two.append(payload); });
            _settle();
            pub.notify(two, 'long-two');
            _wait_for(got_two, 1);
            time.sleep(0.5);
        } finally {
            sub.close();
            pub.close();
        }
        assert got_two == ['long-two'] , (
            f"a channel name of {len(two)} bytes lost its message, got {got_two}:"
            " over-long names must still map to one stable listen identifier"
        );
        assert got_one == [] , (
            "two channel names sharing their first 63 bytes cross-delivered: "
            f"{got_one}"
        );
    }
}
