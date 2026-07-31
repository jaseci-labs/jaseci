"""Per-hop resolver tests — pins down behavior that's specific to the
per-hop fold structure introduced by `jaclang.runtimelib.resolver`.

These complement `test_topology_e2e.jac` (which guards execute_path-level
parity) by exercising the resolver's per-hop entry points directly and by
locking down the bail boundary that future PRs will widen."""

import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.project.config { JacConfig, set_config }
import from jaclang.runtimelib.resolver { resolve_path_anchors }
import from jaclang.jac0core.archetype {
    ObjectSpatialPath,
    ObjectSpatialDestination,
    EdgeDir
}
import from jaclang.runtimelib.query_utils {
    _filter_has_predicates,
    _dest_has_node_predicates,
    _dest_node_type_name
}


node R1Hop {
    has val: int = 0;
}

node R2Hop {
    has val: int = 0;
}

node R3Hop {
    has val: int = 0;
}

edge Hop1 {}
edge Hop2 {}
edge Hop3 {}


test "3-hop type-filtered chain resolves via the per-hop fold" {
    # A purely type-filtered 3-hop chain must walk all three hops on the
    # index and return the leaf set correctly. This is the happy-path the
    # per-hop fold replaces today's `plan_chain` set-narrowing branch with.
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    try {
        r = root;
        # root -> R1Hop -> R2Hop -> R3Hop  (5 leaves)
        for i in range(5) {
            a = R1Hop(val=i);
            r +>:Hop1:+> a;
            b = R2Hop(val=i * 10);
            a +>:Hop2:+> b;
            b +>:Hop3:+> R3Hop(val=i * 100);
        }
        leaves = [r->:Hop1:->->:Hop2:->->:Hop3:->[?:R3Hop]];
        assert len(leaves) == 5 , f"expected 5 leaves, got {len(leaves)}";
        assert sorted([n.val for n in leaves]) == [0, 100, 200, 300, 400];
    } finally {
        ctx.close();
        set_config(JacConfig());
    }
}


test "single-hop slice on last hop applies ordered+sliced result" {
    # Single-hop with a slice exercises `resolve_hop`'s ordered branch — the
    # last hop receives a non-None `slc` and `resolve_chain_ordered` is the
    # only path that produces it. Pins down the use_ordered branch in
    # resolve_path_anchors.
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    try {
        r = root;
        for i in range(20) {
            r +>:Hop1:+> R1Hop(val=i);
        }
        sliced = [r->:Hop1:->[?:R1Hop]][0:5];
        assert len(sliced) == 5 , f"expected slice of 5, got {len(sliced)}";
        # Canonical edge-insertion order means the first 5 are vals 0..4.
        assert sorted([n.val for n in sliced]) == [0, 1, 2, 3, 4];
    } finally {
        ctx.close();
        set_config(JacConfig());
    }
}


test "predicate on non-final hop resolves via per-hop walk fallback" {
    # The core promise of the per-hop fold: an awkward hop (predicate filter
    # that the index can't apply) falls back to `_hop_via_walk` locally,
    # while the *other* hops still use the index. No global bail.
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    try {
        r = root;
        for i in range(10) {
            a = R1Hop(val=i);
            r +>:Hop1:+> a;
            a +>:Hop2:+> R2Hop(val=i * 10);
        }
        # `n.val > 5` introduces LOAD_ATTR + COMPARE_OP — this hop walks; the
        # second hop still uses the index.
        pred_filter = lambda (n: any) { isinstance(n, R1Hop) and n.val > 5; };
        path = ObjectSpatialPath(
            [r],
            [
                ObjectSpatialDestination(EdgeDir.OUT, None, pred_filter),
                ObjectSpatialDestination(EdgeDir.OUT)
            ]
        );
        ctx_mem = JacRuntime.get_context().mem;
        anchors = resolve_path_anchors(ctx_mem, path);
        vals = sorted([a.archetype.val for a in anchors]);
        assert vals == [60, 70, 80, 90] , (
            f"resolver must handle predicate-on-non-final-hop via per-hop "
            f"walk fallback, got {vals!r}"
        );
        # End-to-end via `refs()` produces the same answer.
        leaves = [r->:Hop1:->[?:R1Hop, val>5]->:Hop2:->[?:R2Hop]];
        assert sorted([n.val for n in leaves]) == [60, 70, 80, 90];
    } finally {
        ctx.close();
        set_config(JacConfig());
    }
}


test "a post-filter keeps its destination off the index fast path" {
    # The fast path may only run when it can see every filter, so a trailing
    # post-filter must be visible as structure rather than recovered from
    # bytecode, and the type filter beside it must stay introspectable.
    type_filter = lambda (n: any) { isinstance(n, R1Hop); };
    pred_filter = lambda (n: any) { n.val > 5; };
    composed = lambda (n: any) { type_filter(n) and pred_filter(n); };

    assert not _filter_has_predicates(type_filter) , "type filter has no predicates";
    assert _filter_has_predicates(pred_filter) , "field comparison is a predicate";
    assert _filter_has_predicates(composed) , (
        "a filter wrapping other filters hides them and must be assumed to "
        "carry predicates"
    );

    dest = ObjectSpatialDestination(EdgeDir.OUT, None, type_filter);
    assert not _dest_has_node_predicates(dest) , "type-only destination is indexable";
    dest.add_node_post_filter(pred_filter);
    assert _dest_has_node_predicates(dest) , "post-filter must block the fast path";
    assert _dest_node_type_name(dest) == 'R1Hop' , (
        "the type filter must stay introspectable once a post-filter is added"
    );

    # `[-->][?:T]` arrives as a bare post-filter. It is a type filter, not a
    # predicate, so it must keep the index fast path and its narrowing type.
    chained = ObjectSpatialDestination(EdgeDir.OUT);
    chained.add_node_post_filter(type_filter);
    assert not _dest_has_node_predicates(chained) , (
        "a post-filter carrying only a type must stay on the index fast path"
    );
    assert _dest_node_type_name(chained) == 'R1Hop' , (
        "a post-filter's type must still narrow the index"
    );
}


test "a destination post-filter is applied to the resolved result" {
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    try {
        r = root;
        for i in range(10) {
            r +>:Hop1:+> R1Hop(val=i);
        }
        dest = ObjectSpatialDestination(
            EdgeDir.OUT, None, lambda (n: any) { isinstance(n, R1Hop); }
        );
        dest.add_node_post_filter(lambda (n: any) { n.val > 5; });
        anchors = resolve_path_anchors(
            JacRuntime.get_context().mem, ObjectSpatialPath([r], [dest])
        );
        vals = sorted([a.archetype.val for a in anchors]);
        assert vals == [6, 7, 8, 9] , (
            f"resolver must apply the destination post-filter, got {vals!r}"
        );
    } finally {
        ctx.close();
        set_config(JacConfig());
    }
}
