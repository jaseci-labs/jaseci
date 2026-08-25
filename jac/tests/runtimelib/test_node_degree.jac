"""A node must not carry its own adjacency list.

`NodeAnchor.__getstate__` wrote `state['edges']` into the serialized props, so
a node's row grew with its degree -- 20k edges measured at 782 kB in one jsonb
column, which puts a 10M-edge node past Postgres's 1 GB per-field ceiling. The
list was stored twice over: `load_full` ignores the props copy and derives
adjacency from the edge rows' own src/dst, which is the authoritative source.

These tests pin that a node's stored size is independent of its degree, that
adjacency still resolves from the edge rows, and that the round trip is lossless.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID }
import from jaclang.runtime.archetype { EdgeAnchor, NodeAnchor, Root }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.runtime.context { ExecutionContext }

def _as_any(v: any) -> any {
    return v;
}

node DHub {
    has name: str = "";
}

node DLeaf {
    has n: int = 0;
}

edge DLink {}


def _make_ctx(tmpdir: str) -> ExecutionContext {
    return ExecutionContext(
        base_path_dir=tmpdir, full_target_path=str(Path(tmpdir) / "deg_app.jac")
    );
}


"""Attach `count` leaves to a fresh hub; return the hub's id."""
def _fan(ctx: ExecutionContext, count: int) -> UUID {
    ranch = Root().__jac__;
    ranch.persistent = True;
    ctx.mem.put(ranch);
    hub = DHub(name="hub").__jac__;
    hub.persistent = True;
    ctx.mem.put(hub);
    for i in range(count) {
        leaf = DLeaf(n=i).__jac__;
        leaf.persistent = True;
        link = EdgeAnchor(
            archetype=_as_any(DLink()), source=hub, target=leaf, is_undirected=False
        );
        link.persistent = True;
        hub.edges.append(link);
        leaf.edges.append(link);
        ctx.mem.put(leaf);
        ctx.mem.put(link);
    }
    return hub.id;
}


def _props_bytes(ctx: ExecutionContext, node_id: UUID) -> int {
    store = ctx.mem.store;
    assert store is not None;
    rows = store.rows(
        "SELECT pg_column_size(props) FROM anchors WHERE id = CAST(:i AS uuid)",
        {"i": str(node_id)}
    );
    return int(rows[0][0]);
}


def _fan_and_measure(td: str, count: int) -> tuple[int, int] {
    old = JacRuntime.exec_ctx;
    ctx = _make_ctx(td);
    JacRuntime.exec_ctx = ctx;
    try {
        hub_id = _fan(ctx, count);
        ctx.mem.commit();
        return (_props_bytes(ctx, hub_id), count);
    } finally {
        JacRuntime.exec_ctx = old;
        ctx.close();
    }
}


test "a node's stored size does not grow with its degree" {
    with TemporaryDirectory() as td_small {
        (small, _) = _fan_and_measure(td_small, 8);
        with TemporaryDirectory() as td_big {
            (big, _) = _fan_and_measure(td_big, 800);
            growth = big - small;
            assert growth < 256 , (
                f"node props grew by {growth} bytes between degree 8 and degree "
                f"800 -- adjacency is still stored inside the node"
            );
        }
    }
}


test "adjacency still resolves from the edge rows after a cold reload" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx1 = _make_ctx(td);
        JacRuntime.exec_ctx = ctx1;
        hub_id: UUID;
        try {
            hub_id = _fan(ctx1, 12);
            ctx1.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx1.close();
        }
        ctx2 = _make_ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            hub = ctx2.mem.get(hub_id);
            assert isinstance(hub, NodeAnchor);
            assert len(hub.edges) == 12 , (
                f"cold reload lost adjacency: {len(hub.edges)} edges, expected 12"
            );
            seen = set();
            for e in hub.edges {
                assert isinstance(e, EdgeAnchor);
                seen.add(e.id);
            }
            assert len(seen) == 12 , f"adjacency has duplicates: {len(seen)}";
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "the stored props carry no edges key at all" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _make_ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            hub_id = _fan(ctx, 5);
            ctx.mem.commit();
            store = ctx.mem.store;
            assert store is not None;
            rows = store.rows(
                "SELECT props ? 'edges' FROM anchors WHERE id = CAST(:i AS uuid)",
                {"i": str(hub_id)}
            );
            assert not bool(rows[0][0]) , (
                "node props still carry an 'edges' key; adjacency belongs to the "
                "edge rows, which are its authoritative source"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}
