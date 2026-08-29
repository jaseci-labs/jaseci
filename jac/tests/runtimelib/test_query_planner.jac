"""Planner E2E: engine execution in id space, overlay read-your-writes,
winner verification, and the cost invariant (L3 fetches == |result|)."""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID }
import from jaclang.runtime.archetype { EdgeAnchor, NodeAnchor, Root }
import from jaclang.runtime.graph_query { GraphQuery, QHop, QPred }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.data.store { PgStore }
import from jaclang.data.query_planner { resolve_query, resolve_query_count }

def _as_any(v: any) -> any {
    return v;
}

node PA {
    has val: int = 0;
}

node PB {
    has tag: str = "";
}

edge PRel {
    has w: int = 0;
}


obj _QueryCountingStore(PgStore) {
    has rows_calls: int = 0;

    def rows(sql: str, params: dict) -> list[tuple] {
        self.rows_calls += 1;
        return super.rows(sql, params);
    }
}


def _make_ctx(tmpdir: str) -> ExecutionContext {
    target = str(Path(tmpdir) / "qp_app.jac");
    return ExecutionContext(base_path_dir=tmpdir, full_target_path=target);
}


"""root -PRel-> PA(1), PA(2), PA(3); PA(2) -PRel-> PB('leaf')."""
def _seed(ctx: ExecutionContext) -> UUID {
    ranch = Root().__jac__;
    ranch.persistent = True;
    ctx.mem.put(ranch);
    pas: list = [];
    for i in [1, 2, 3] {
        nanch = PA(val=i).__jac__;
        nanch.persistent = True;
        eanch = EdgeAnchor(
            archetype=_as_any(PRel(w=i)),
            source=ranch,
            target=nanch,
            is_undirected=False
        );
        eanch.persistent = True;
        ranch.edges.append(eanch);
        nanch.edges.append(eanch);
        ctx.mem.put(nanch);
        ctx.mem.put(eanch);
        pas.append(nanch);
    }
    banch = PB(tag="leaf").__jac__;
    banch.persistent = True;
    e2 = EdgeAnchor(
        archetype=_as_any(PRel(w=9)), source=pas[1], target=banch, is_undirected=False
    );
    e2.persistent = True;
    pas[1].edges.append(e2);
    banch.edges.append(e2);
    ctx.mem.put(banch);
    ctx.mem.put(e2);
    return ranch.ensure_id();
}


test "cold engine query: preds, slice, and fetches == |result|" {
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
            assert isinstance(ranch, NodeAnchor) and ranch.archetype is not None;
            ctx2.mem.reset_fetch_count();

            q = GraphQuery(
                ranch.archetype,
                hops=[QHop(dir=2, nd=PA, preds=[QPred(field="val", op="==", value=2)])]
            );
            hits = resolve_query(ctx2.mem, q);
            assert len(hits) == 1;
            assert _as_any(hits[0]).archetype.val == 2;
            fetches = ctx2.mem.get_fetch_count();
            assert fetches == 1 , (
                f"cost invariant: expected 1 L3 fetch (the winner), got {fetches}"
            );

            two = resolve_query(
                ctx2.mem,
                GraphQuery(
                    ranch.archetype, hops=[QHop(dir=2, nd=PA)], slc=slice(0, 2, None)
                )
            );
            assert len(two) == 2;
            assert [_as_any(a).archetype.val for a in two] == [1, 2];

            chain = resolve_query(
                ctx2.mem,
                GraphQuery(
                    ranch.archetype,
                    hops=[
                        QHop(dir=2, nd=PA),
                        QHop(
                            dir=2,
                            nd=PB,
                            preds=[QPred(field="tag", op="==", value="leaf")]
                        )
                    ]
                )
            );
            assert len(chain) == 1;
            assert _as_any(chain[0]).archetype.tag == "leaf";
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "overlay: uncommitted writes are visible, both directions" {
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
            assert isinstance(ranch, NodeAnchor);

            # Fresh, uncommitted node+edge must appear (engine knows nothing).
            fresh = PA(val=99).__jac__;
            fresh.persistent = True;
            fe = EdgeAnchor(
                archetype=_as_any(PRel(w=0)),
                source=ranch,
                target=fresh,
                is_undirected=False
            );
            fe.persistent = True;
            ranch.edges.append(fe);
            fresh.edges.append(fe);
            ctx2.mem.put(fresh);
            ctx2.mem.put(fe);

            got = resolve_query(
                ctx2.mem,
                GraphQuery(
                    ranch.archetype,
                    hops=[
                        QHop(
                            dir=2, nd=PA, preds=[QPred(field="val", op="==", value=99)]
                        )
                    ]
                )
            );
            assert len(got) == 1 , "uncommitted edge must be visible (RYW)";

            # Dirty field write on a resident node: new value matches, old
            # value must not (the engine's committed row says val == 1).
            one = resolve_query(
                ctx2.mem,
                GraphQuery(
                    ranch.archetype,
                    hops=[
                        QHop(dir=2, nd=PA, preds=[QPred(field="val", op="==", value=1)])
                    ]
                )
            );
            assert len(one) == 1;
            _as_any(one[0]).archetype.val = 42;

            after = resolve_query(
                ctx2.mem,
                GraphQuery(
                    ranch.archetype,
                    hops=[
                        QHop(
                            dir=2, nd=PA, preds=[QPred(field="val", op="==", value=42)]
                        )
                    ]
                )
            );
            assert len(after) == 1 , "dirty field write must be visible (RYW)";
            stale = resolve_query(
                ctx2.mem,
                GraphQuery(
                    ranch.archetype,
                    hops=[
                        QHop(dir=2, nd=PA, preds=[QPred(field="val", op="==", value=1)])
                    ]
                )
            );
            assert len(stale) == 0 , "the committed value must no longer match";

            # Detaching a persisted edge suppresses its engine row.
            two_anchor = resolve_query(
                ctx2.mem,
                GraphQuery(
                    ranch.archetype,
                    hops=[
                        QHop(dir=2, nd=PA, preds=[QPred(field="val", op="==", value=2)])
                    ]
                )
            )[0];
            victim: (EdgeAnchor | None) = None;
            for stub in ranch.edges {
                loaded = ctx2.mem.get(stub.ensure_id());
                if isinstance(loaded, EdgeAnchor)
                    and loaded.is_populated()
                    and loaded.target.id == two_anchor.id {
                    victim = loaded;
                }
            }
            assert victim is not None;
            victim.detach();
            gone = resolve_query(
                ctx2.mem,
                GraphQuery(
                    ranch.archetype,
                    hops=[
                        QHop(dir=2, nd=PA, preds=[QPred(field="val", op="==", value=2)])
                    ]
                )
            );
            assert len(gone) == 0 , "detached edge must suppress its engine row";
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "session memoizes repeated pushdown query results and invalidates on write" {
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
            assert isinstance(ranch, NodeAnchor) and ranch.archetype is not None;
            base = ctx2.mem.store;
            assert isinstance(base, PgStore);
            counting = _QueryCountingStore(
                conninfo=base.conninfo,
                promotions=base.promotions,
                auto_schema=True
            );
            base.close();
            ctx2.mem.store = counting;

            q = GraphQuery(ranch.archetype, hops=[QHop(dir=2, nd=PA)]);
            first = resolve_query(ctx2.mem, q);
            assert len(first) == 3;
            rows_after_first = counting.rows_calls;
            assert rows_after_first == 1 , (
                f"expected first graph query to issue one SQL statement, got "
                f"{rows_after_first}"
            );

            second = resolve_query(ctx2.mem, q);
            assert len(second) == 3;
            assert counting.rows_calls == rows_after_first , (
                "repeating the same pushdown query in one session should hit "
                "the query-result memo"
            );

            fresh = PA(val=99).__jac__;
            fresh.persistent = True;
            fe = EdgeAnchor(
                archetype=_as_any(PRel(w=0)),
                source=ranch,
                target=fresh,
                is_undirected=False
            );
            fe.persistent = True;
            ranch.edges.append(fe);
            fresh.edges.append(fe);
            ctx2.mem.put(fresh);
            ctx2.mem.put(fe);

            before_invalidated_query = counting.rows_calls;
            third = resolve_query(ctx2.mem, q);
            assert len(third) == 4;
            assert counting.rows_calls == before_invalidated_query + 1 , (
                "query-result memo must be invalidated after graph writes"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "runtime uses warmed topology index for simple graph resolves" {
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
            assert isinstance(ranch, NodeAnchor) and ranch.archetype is not None;
            base = ctx2.mem.store;
            assert isinstance(base, PgStore);
            counting = _QueryCountingStore(
                conninfo=base.conninfo,
                promotions=base.promotions,
                auto_schema=True
            );
            base.close();
            ctx2.mem.store = counting;

            assert ctx2.user_root is not None;
            idx = ctx2.mem.warm_topology_for_nodes([root_id]);
            assert idx.node_type(root_id) == "Root";
            assert idx.owner_root_for(root_id) == root_id;
            assert idx.has_root(root_id);
            assert ctx2.mem._topology_index is not None;
            after_warm = counting.rows_calls;
            assert after_warm == 1;

            q = GraphQuery(ranch.archetype, hops=[QHop(dir=2, nd=PA)]);
            hits = resolve_query(ctx2.mem, q);
            assert len(hits) == 3;
            assert counting.rows_calls == after_warm , (
                f"warmed topology should answer simple graph resolves without SQL "
                f"(after_warm={after_warm}, rows={counting.rows_calls})"
            );

            assert resolve_query_count(ctx2.mem, q) == 3;
            assert counting.rows_calls == after_warm , (
                "warmed topology should answer simple graph counts without SQL"
            );

            visit_q = GraphQuery(ranch.archetype, hops=[QHop(dir=2, nd=PA)]);
            visit_q.`visit();
            visit_hits = resolve_query(ctx2.mem, visit_q);
            assert len(visit_hits) == 3;
            assert counting.rows_calls == after_warm , (
                "warmed topology should answer node visit queries without SQL"
            );

            pred_q = GraphQuery(
                ranch.archetype,
                hops=[QHop(dir=2, nd=PA, preds=[QPred(field="val", op="==", value=2)])]
            );
            pred_hits = resolve_query(ctx2.mem, pred_q);
            assert len(pred_hits) == 1;
            assert counting.rows_calls == after_warm , (
                "warmed topology should evaluate node predicates without SQL"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}
