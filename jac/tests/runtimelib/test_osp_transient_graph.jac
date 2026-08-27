"""Transient OSP graphs cost what their topology costs (#8743).

A `node` that is never connected to a root and never reaches a store is an
in-memory data structure, and building one has no business paying for
persistence. Three distinct taxes used to make that false, and each test below
pins one of them shut:

  A. `osp_graph`'s node table hashed its keys as `(k >> 4) ^ (k >> 16)`, which
     is a fine hash for 16-byte-aligned native addresses and a catastrophic one
     for the dense integer handles the bytecode and JS drivers mint: it
     discards the low four bits, so sixteen consecutive handles share a bucket,
     the resulting home buckets are contiguous, and linear probing merges them
     into one run. Insert cost was ~n/2 probes -- quadratic graph build.

  B. Every anchor eagerly minted a `uuid4()` and a `Permission` with two
     `Access` objects, and the sv driver keyed its registries by `str(id)`.
     None of that is needed until an anchor touches a root or a store, and it
     dominated the ~2.2 KB an edge used to cost.

  C. `[-->]` on a rootless, storeless graph ran the persistence query planner:
     every hop round-tripped its anchors through UUID keys and consulted the
     ACL, for a graph that has neither an owner nor a backing table.

The timing tests compare a *ratio* -- per-op cost at n against per-op cost at
8n, or against the kernel primitive the operation should be compiling down to
-- so they measure algorithmic shape rather than machine speed, in the style of
`dict_hash_scaling`. The bounds are deliberately loose: the behavior they
exclude is off by an order of magnitude, not by a few percent.
"""

import time;
import tracemalloc;
import jaclang.runtime.osp_graph as _g;
import jaclang.runtime.osp_graph_sv as _sv;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtime.archetype { Anchor }
import from jaclang.runtime.osp_graph_sv { handle_of, sv_live_edges }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.runtime.runtime { JacRuntime }

node TNode {
    has a: int = 0;
}

edge TRel {
    has w: int = 0;
}

def _chain(n: int) -> list[TNode] {
    nodes: list[TNode] = [];
    i = 0;
    while i < n {
        nodes.append(TNode(a=i));
        i += 1;
    }
    return nodes;
}

"""Wire a pre-built list of nodes into a chain; returns seconds per connect."""
def _connect(nodes: list[TNode]) -> float {
    n = len(nodes);
    t0 = time.perf_counter();
    i = 0;
    while i < n - 1 {
        nodes[i] +>:TRel(w=i):+> nodes[i + 1];
        i += 1;
    }
    return (time.perf_counter() - t0) / float(n - 1);
}

"""Walk every node's out-edges once; returns seconds per hop."""
def _hop(nodes: list[TNode]) -> float {
    n = len(nodes);
    t0 = time.perf_counter();
    seen = 0;
    for nd in nodes {
        seen += len([nd -->]);
    }
    dt = time.perf_counter() - t0;
    assert seen == n - 1 , f"chain of {n} yielded {seen} hops";
    return dt / float(n);
}

"""The kernel adjacency walk `[-->]` should be compiling down to."""
def _kernel_hop(nodes: list[TNode]) -> float {
    n = len(nodes);
    anchors = [nd.__jac__ for nd in nodes];
    t0 = time.perf_counter();
    seen = 0;
    for a in anchors {
        seen += len(sv_live_edges(a, 2, None, False));
    }
    dt = time.perf_counter() - t0;
    assert seen == n - 1 , f"kernel walk of {n} yielded {seen} hops";
    return dt / float(n);
}

def _ratio(small: float, big: float) -> float {
    return big / small if small > 0.0 else 1000000.0;
}

# ---------------------------------------------------------------------------
# A. The node table hashes dense handles as well as it hashes pointers.
# ---------------------------------------------------------------------------
test "the node-table hash scatters dense handles instead of clustering them" {
    for cap in [1024, 4096, 65536] {
        m = cap - 1;
        load = (cap * 3) // 4;
        seen: set[int] = set();
        k = 1;
        while k <= load {
            seen.add(_g._hslot(k, m));
            k += 1;
        }
        assert len(seen) == load , (
            f"cap={cap}: {load} consecutive handles landed in only "
            f"{len(seen)} buckets; the sv and JS drivers mint handles densely, "
            "so a hash that drops their low bits turns every insert into a "
            "walk down one merged probe run"
        );
    }
}

test "aligned addresses still scatter after the dense-handle fix" {
    # The native driver keys the same table by 16-byte-aligned struct
    # addresses. Whatever fixes dense handles must not regress those.
    m = 65535;
    base = 0x7f0000000000;
    seen: set[int] = set();
    i = 0;
    while i < 24576 {
        seen.add(_g._hslot(base + i * 48, m));
        i += 1;
    }
    assert len(seen) > 20000 , (
        f"24576 aligned addresses collapsed into {len(seen)} buckets"
    );
}

test "connecting a transient chain stays flat as the graph grows" {
    _connect(_chain(500));
    small = _connect(_chain(2000));
    big = _connect(_chain(16000));
    r = _ratio(small, big);
    assert r < 4.0 , (
        f"per-connect cost grew {r:.1f}x when the graph grew 8x "
        f"({small * 1e6:.1f}us -> {big * 1e6:.1f}us per edge); connect must be "
        "flat in the size of the graph"
    );
}

test "the node table counts occupancy instead of storing one zero per key" {
    _connect(_chain(2000));
    assert len(_g._nt_cnt) == 1 , (
        f"_nt_cnt holds {len(_g._nt_cnt)} cells; occupancy is a count, not a "
        "list whose length happens to be the count"
    );
    live = 0;
    for k in _g._nt_key {
        if k != 0 {
            live += 1;
        }
    }
    assert _g._nt_cnt[0] == live , (
        f"occupancy counter says {_g._nt_cnt[0]}, table holds {live} keys"
    );
}

# ---------------------------------------------------------------------------
# A'. Disconnect resolves an edge by handle rather than scanning every row.
# ---------------------------------------------------------------------------
def _detach(nodes: list[TNode]) -> float {
    edges: list = [];
    for nd in nodes {
        for e in [edge nd -->] {
            edges.append(e);
        }
    }
    t0 = time.perf_counter();
    for e in edges {
        del e;
    }
    dt = time.perf_counter() - t0;
    return dt / float(len(edges));
}

test "detaching an edge is flat in the number of edge rows ever allocated" {
    warm = _chain(500);
    _connect(warm);
    _detach(warm);
    small_nodes = _chain(2000);
    _connect(small_nodes);
    small = _detach(small_nodes);
    big_nodes = _chain(16000);
    _connect(big_nodes);
    big = _detach(big_nodes);
    r = _ratio(small, big);
    assert r < 4.0 , (
        f"per-detach cost grew {r:.1f}x when the graph grew 8x "
        f"({small * 1e6:.1f}us -> {big * 1e6:.1f}us per edge); an edge must be "
        "found by its handle, not by scanning the row table"
    );
}

# ---------------------------------------------------------------------------
# B. A transient anchor is identity plus topology, nothing else.
# ---------------------------------------------------------------------------
def _edge_anchors(nodes: list[TNode]) -> list[Anchor] {
    out: list[Anchor] = [];
    for nd in nodes {
        for e in sv_live_edges(nd.__jac__, 2, None, True) {
            out.append(e);
        }
    }
    return out;
}

test "a never-persisted anchor is exactly its archetype and its topology" {
    nodes = _chain(64);
    _connect(nodes);
    for nd in nodes {
        a = nd.__jac__;
        assert a.id is None , (
            "a rootless, storeless node anchor minted a uuid; identity is "
            "what persistence needs, and this graph never reaches a store"
        );
        assert a.access is None , (
            "a transient node anchor allocated a Permission; an anchor nobody "
            "has granted anything has nothing to say about access"
        );
        assert set(a.__dict__.keys()) == {"archetype", "edges"} , (
            f"a transient node anchor carries {sorted(a.__dict__.keys())}; "
            "everything but the archetype and its edges is persistence "
            "machinery and must stay unallocated until persistence needs it"
        );
    }
    edges = _edge_anchors(nodes);
    assert len(edges) == 63 , f"expected 63 edge anchors, saw {len(edges)}";
    for e in edges {
        assert e.id is None , "connecting minted a uuid for a transient edge";
        assert e.access is None , (
            "a transient edge anchor allocated a Permission"
        );
        assert set(e.__dict__.keys())
            == {"archetype", "source", "target", "is_undirected"} , (
            f"a transient edge anchor carries {sorted(e.__dict__.keys())}"
        );
    }
}

test "traversing a transient graph mints nothing" {
    nodes = _chain(64);
    _connect(nodes);
    _hop(nodes);
    for nd in nodes {
        assert nd.__jac__.id is None , (
            "a hop over a rootless graph minted an anchor uuid; the traversal "
            "must not round-trip anchors through store keys"
        );
    }
    for e in _edge_anchors(nodes) {
        assert e.id is None , "a hop minted an edge anchor uuid";
    }
}

test "transient anchors compare and hash by identity while they have no id" {
    a = TNode(a=1).__jac__;
    b = TNode(a=1).__jac__;
    assert a == a and not (a == b) , "identity fallback must distinguish anchors";
    assert len({a, b}) == 2 , "two id-less anchors collapsed in a set";
    assert hash(a) == hash(a) , "identity hash is not stable";
}

test "a transient edge costs hundreds of bytes, not thousands" {
    n = 3001;
    _connect(_chain(500));
    nodes = _chain(n);
    tracemalloc.start();
    try {
        before = tracemalloc.get_traced_memory()[0];
        _connect(nodes);
        after = tracemalloc.get_traced_memory()[0];
    } finally {
        tracemalloc.stop();
    }
    per_edge = float(after - before) / float(n - 1);
    # ~1.1 KB measured, and what is left is the data itself plus the kernel's
    # own slots: the edge archetype, the three anchors, seven row-array slots,
    # the node and edge index entries and the handle registry. The ~750 bytes
    # of uuids, uuid strings and Permission objects an edge used to add on top
    # of that are gone. The cap leaves room for allocator and dict-growth
    # noise while staying far below the old ~2.2 KB.
    assert per_edge < 1400.0 , (
        f"a transient edge costs {per_edge:.0f} bytes; uuids, permissions and "
        "id-keyed registries are persistence machinery and must not be "
        "allocated for a graph that has no root and no store"
    );
}

# ---------------------------------------------------------------------------
# C. A transient hop reads the kernel adjacency, not the query planner.
# ---------------------------------------------------------------------------
test "a transient hop costs about what the kernel adjacency walk costs" {
    warm = _chain(500);
    _connect(warm);
    _hop(warm);
    _kernel_hop(warm);
    nodes = _chain(4000);
    _connect(nodes);
    kernel = _kernel_hop(nodes);
    hop = _hop(nodes);
    r = _ratio(kernel, hop);
    assert r < 3.0 , (
        f"[-->] on a rootless graph cost {hop * 1e6:.1f}us per hop against "
        f"{kernel * 1e6:.1f}us for the kernel adjacency walk it should be "
        f"compiling to ({r:.1f}x); the planner and the ACL have nothing to "
        "decide for a graph with no owner and no backing table"
    );
}

test "a transient traversal records no optimistic-concurrency reads" {
    orig_ctx = JacRuntime.exec_ctx;
    with TemporaryDirectory() as proj {
        try {
            ctx = ExecutionContext(
                base_path_dir=proj,
                full_target_path=str(Path(proj) / "occ_probe.jac")
            );
            JacRuntime.exec_ctx = ctx;
            before = len(ctx.read_versions);
            nodes = _chain(32);
            _connect(nodes);
            _hop(nodes);
            assert len(ctx.read_versions) == before , (
                "hopping over transient anchors registered them in the "
                "context's OCC read set; there is no stored version to guard"
            );
            ctx.close();
        } finally {
            JacRuntime.exec_ctx = orig_ctx;
        }
    }
}

# ---------------------------------------------------------------------------
# The identity a transient anchor does not have must appear the moment
# persistence needs it, and survive the round trip.
# ---------------------------------------------------------------------------
node RtNode {
    has label: str = "";
}

edge RtRel {
    has w: int = 0;
}

def _transcript(origin: any) -> list {
    out: list = [];
    for n in [origin --> ] {
        if isinstance(n, RtNode) {
            out.append(n.label);
            for m in [n ->:RtRel:-> ] {
                out.append(f"{n.label}>{m.label}:{len([m --> ])}");
            }
        }
    }
    return sorted(out);
}

test "an id minted at store attach survives the round trip" {
    with TemporaryDirectory() as proj {
        target = str(Path(proj) / "attach_app.jac");
        orig_ctx = JacRuntime.exec_ctx;
        try {
            ctx_a = ExecutionContext(base_path_dir=proj, full_target_path=target);
            JacRuntime.exec_ctx = ctx_a;
            # Build the whole shape transiently first: no root, no store.
            a = RtNode(label="a");
            b = RtNode(label="b");
            c = RtNode(label="c");
            a +>:RtRel(w=1):+> b;
            b +>:RtRel(w=2):+> c;
            assert a.__jac__.id is None , "a transient build minted an id";
            assert b.__jac__.id is None , "a transient build minted an id";
            # Attaching to the root is what makes identity necessary.
            root ++> a;
            for anch in [a.__jac__, b.__jac__, c.__jac__] {
                assert anch.id is not None , (
                    "attaching a transient subgraph to the root left an "
                    "anchor without the identity the store needs"
                );
            }
            live = _transcript(root);
            assert live == ["a", "a>b:1"] , f"unexpected live transcript: {live}";
            ctx_a.close();

            ctx_b = ExecutionContext(base_path_dir=proj, full_target_path=target);
            JacRuntime.exec_ctx = ctx_b;
            reloaded = _transcript(root);
            assert reloaded == live , (
                f"reload transcript {reloaded} != live transcript {live}"
            );
            ctx_b.close();
        } finally {
            JacRuntime.exec_ctx = orig_ctx;
        }
    }
}
