"""Process-scoped index projection (#7855 phase 4): warm-path parity with
the engine, cost invariant under warming, read-your-writes precedence,
own-write eviction, the cross-pod staleness window with bus delivery and
the fresh-level bypass, and the TTL backstop."""

import time;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID }
import from jaclang.jac0core.archetype { EdgeAnchor, NodeAnchor, Root }
import from jaclang.jac0core.graph_query { GraphQuery, QHop, QPred }
import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.runtimelib.projection { _REGISTRY, Projection }
import from jaclang.runtimelib.query_planner { resolve_query }

node VA {
    has val: int = 0;
}

node VB {
    has tag: str = "";
}

edge VRel {
    has w: int = 0;
}


def _make_ctx(tmpdir: str) -> ExecutionContext {
    target = str(Path(tmpdir) / "proj_app.jac");
    return ExecutionContext(base_path_dir=tmpdir, full_target_path=target);
}


def _seed(ctx: ExecutionContext) -> UUID {
    ranch = Root().__jac__;
    ranch.persistent = True;
    ctx.mem.put(ranch);
    for i in [1, 2, 3] {
        nanch = VA(val=i).__jac__;
        nanch.persistent = True;
        eanch = EdgeAnchor(
            archetype=VRel(w=i), source=ranch, target=nanch, is_undirected=False
        );
        eanch.persistent = True;
        ranch.edges.append(eanch);
        nanch.edges.append(eanch);
        ctx.mem.put(nanch);
        ctx.mem.put(eanch);
    }
    banch = VB(tag="x").__jac__;
    banch.persistent = True;
    be = EdgeAnchor(
        archetype=VRel(w=9), source=ranch, target=banch, is_undirected=False
    );
    be.persistent = True;
    ranch.edges.append(be);
    banch.edges.append(be);
    ctx.mem.put(banch);
    ctx.mem.put(be);
    return ranch.id;
}


def _proj_for(tmpdir: str) -> (Projection | None) {
    for (k, v) in _REGISTRY.items() {
        if tmpdir in k {
            return v;
        }
    }
    return None;
}


def _q(origin: any, val: int, level: str = 'default') -> list {
    return resolve_query(
        JacRuntime.exec_ctx.mem,
        GraphQuery(
            origin,
            hops=[QHop(dir=2, nd=VA, preds=[QPred(field="val", op="==", value=val)])],
            level=level
        )
    );
}


test "warm parity: pages answer the second request, invariant intact" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx1 = _make_ctx(td);
        JacRuntime.exec_ctx = ctx1;
        root_id: UUID;
        try {
            root_id = _seed(ctx1);
            ctx1.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx1.close();
        }
        # Request 1: cold -- engine resolves, projection warms.
        ctx2 = _make_ctx(td);
        JacRuntime.exec_ctx = ctx2;
        cold_hits: list = [];
        try {
            ranch = ctx2.mem.get(root_id);
            cold_hits = _q(ranch.archetype, 2);
            assert len(cold_hits) == 1 and cold_hits[0].archetype.val == 2;
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
        proj = _proj_for(td);
        assert proj is not None , "projection must exist after a cold query";
        assert len(proj.pages) > 0 , "cold query must warm the frontier";
        # Request 2: fresh context, pages resolve locally, same answer,
        # exactly |result| deserializations.
        ctx3 = _make_ctx(td);
        JacRuntime.exec_ctx = ctx3;
        try {
            ranch = ctx3.mem.get(root_id);
            h0 = proj.hits;
            ctx3.mem.reset_l3_fetch_count();
            warm_hits = _q(ranch.archetype, 2);
            assert len(warm_hits) == 1 and warm_hits[0].archetype.val == 2;
            assert proj.hits > h0 , "warm request must be served from pages";
            fetches = ctx3.mem.get_l3_fetch_count();
            assert fetches == 1 , (
                f"cost invariant under warming: expected 1 fetch, got {fetches}"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx3.close();
        }
    }
}


test "read-your-writes beats warm pages; own writes evict" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx1 = _make_ctx(td);
        JacRuntime.exec_ctx = ctx1;
        root_id: UUID;
        try {
            root_id = _seed(ctx1);
            ctx1.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx1.close();
        }
        ctx2 = _make_ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            ranch = ctx2.mem.get(root_id);
            _q(ranch.archetype, 2);

            # Dirty a resident winner: warm pages must not shadow the live
            # value in either direction.
            winner = _q(ranch.archetype, 2)[0];
            winner.archetype.val = 42;
            assert len(_q(ranch.archetype, 42)) == 1 , "live value visible";
            assert len(_q(ranch.archetype, 2)) == 0 , "stale value gone";

            # New committed edge: own-write eviction refreshes the page.
            fresh = VA(val=77).__jac__;
            fresh.persistent = True;
            fe = EdgeAnchor(
                archetype=VRel(w=1), source=ranch, target=fresh, is_undirected=False
            );
            fe.persistent = True;
            ranch.edges.append(fe);
            fresh.edges.append(fe);
            ctx2.mem.put(fresh);
            ctx2.mem.put(fe);
            ctx2.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
        proj = _proj_for(td);
        assert root_id not in proj.pages , "own write must evict the page";
        ctx3 = _make_ctx(td);
        JacRuntime.exec_ctx = ctx3;
        try {
            ranch = ctx3.mem.get(root_id);
            assert len(_q(ranch.archetype, 77)) == 1 , (
                "post-eviction refetch must see the committed edge"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx3.close();
        }
    }
}


test "cross-pod staleness window: stale visible, bus heals, fresh bypasses" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx1 = _make_ctx(td);
        JacRuntime.exec_ctx = ctx1;
        root_id: UUID;
        try {
            root_id = _seed(ctx1);
            ctx1.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx1.close();
        }
        # Warm "pod B", snapshot its pages, then write on "pod A".
        ctx2 = _make_ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            ranch = ctx2.mem.get(root_id);
            _q(ranch.archetype, 2);
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
        proj = _proj_for(td);
        saved_pages = dict(proj.pages);
        ctx3 = _make_ctx(td);
        JacRuntime.exec_ctx = ctx3;
        try {
            ranch = ctx3.mem.get(root_id);
            two = _q(ranch.archetype, 2)[0];
            two.archetype.val = 999;
            ctx3.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx3.close();
        }
        # Pod B missed the bus: restore its pre-write pages (the real
        # deployment shape -- separate processes, undelivered eviction).
        proj.absorb(saved_pages);
        ctx4 = _make_ctx(td);
        JacRuntime.exec_ctx = ctx4;
        try {
            ranch = ctx4.mem.get(root_id);
            # Documented eventual window: default-level reads may serve the
            # committed-but-unevicted past...
            stale = _q(ranch.archetype, 2);
            assert len(stale) == 0 , (
                "stale-row admit must self-heal at winner verification"
            );
            # ...while fresh-level reads bypass the projection entirely.
            assert len(_q(ranch.archetype, 999, level='fresh')) == 1;
            # Bus delivery: per-anchor eviction restores default-level truth.
            for pid in list(proj.pages.keys()) {
                proj.evict(pid);
            }
            assert len(_q(ranch.archetype, 999)) == 1;
        } finally {
            JacRuntime.exec_ctx = old;
            ctx4.close();
        }
    }
}


test "ttl backstop expires completeness marks" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx1 = _make_ctx(td);
        JacRuntime.exec_ctx = ctx1;
        root_id: UUID;
        try {
            root_id = _seed(ctx1);
            ctx1.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx1.close();
        }
        ctx2 = _make_ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            ranch = ctx2.mem.get(root_id);
            _q(ranch.archetype, 2);
            proj = _proj_for(td);
            assert root_id in proj.pages;
            proj.ttl_s = 0.05;
            time.sleep(0.1);
            assert proj.fresh_page(root_id) is None , ("expired mark must not serve");
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}
