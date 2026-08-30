"""Tests for the transient GTI used by TTG planning."""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID }
import from jaclang.runtime.archetype { EdgeAnchor, NodeAnchor, Root }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.runtime.topology_index { TopologyIndex }
import from jaclang.runtime.ttg { JacTTGGenerator }


node GTIProfile {
    has name: str = "";
}

node GTISpecialProfile(GTIProfile) {}

node GTITweet {
    has text: str = "";

    def root_profiles -> list[GTIProfile] {
        return [root-->[?:GTIProfile]];
    }
}

edge GTIFollow {}

edge GTIStrongFollow(GTIFollow) {}

edge GTIPost {}


walker GTITraverse {
    can step_profile with GTIProfile entry {
        visit [-->[?:GTIProfile]];
        visit [-->[?:GTITweet]];
    }
}


walker GTIMultiHopTraverse {
    can step_profile with GTIProfile entry {
        visit [->:GTIFollow:->[?:GTIProfile]->:GTIPost:->[?:GTITweet]];
    }
}


walker GTIRootSourceMethodTraverse {
    can step_profile with GTIProfile entry {
        visit [->:GTIPost:->[?:GTITweet]];
    }

    can step_tweet with GTITweet entry {
        here.root_profiles();
    }
}


def _as_any(v: any) -> any {
    return v;
}


def _ctx(td: str) -> ExecutionContext {
    return ExecutionContext(
        base_path_dir=td, full_target_path=str(Path(td) / "gti_app.jac")
    );
}


def _root(ctx: ExecutionContext) -> NodeAnchor {
    ranch = Root().__jac__;
    ranch.ensure_id();
    ranch.persistent = True;
    setattr(ranch, "root", ranch.id);
    ctx.mem.put(ranch);
    return ranch;
}


def _owned_node(ctx: ExecutionContext, owner: NodeAnchor, arch: any) -> NodeAnchor {
    anch = arch.__jac__;
    anch.ensure_id();
    anch.persistent = True;
    setattr(anch, "root", owner.id);
    ctx.mem.put(anch);
    return anch;
}


def _connect(
    ctx: ExecutionContext, source: NodeAnchor, target: NodeAnchor, arch: any
) -> EdgeAnchor {
    eanch = EdgeAnchor(
        archetype=arch, source=source, target=target, is_undirected=False
    );
    eanch.ensure_id();
    eanch.persistent = True;
    eanch.`root = source.`root;
    source.edges.append(eanch);
    target.edges.append(eanch);
    ctx.mem.put(eanch);
    return eanch;
}


def _seed_cross_root(ctx: ExecutionContext) -> tuple[UUID, UUID, UUID, UUID, UUID] {
    alice_root = _root(ctx);
    bob_root = _root(ctx);
    alice = _owned_node(ctx, alice_root, GTIProfile(name="alice"));
    bob = _owned_node(ctx, bob_root, GTISpecialProfile(name="bob"));
    tweet = _owned_node(ctx, bob_root, GTITweet(text="hi"));
    _connect(ctx, alice, bob, _as_any(GTIStrongFollow()));
    _connect(ctx, bob, tweet, _as_any(GTIPost()));
    return (
        alice_root.ensure_id(),
        bob_root.ensure_id(),
        alice.ensure_id(),
        bob.ensure_id(),
        tweet.ensure_id()
    );
}


test "topology index resolves chains with type ancestry" {
    root_id = UUID("00000000-0000-0000-0000-000000000001");
    alice_id = UUID("00000000-0000-0000-0000-000000000101");
    bob_id = UUID("00000000-0000-0000-0000-000000000102");
    tweet_id = UUID("00000000-0000-0000-0000-000000000103");
    follow_id = UUID("00000000-0000-0000-0000-000000000201");
    post_id = UUID("00000000-0000-0000-0000-000000000202");

    idx = TopologyIndex();
    idx.add_node(alice_id, "GTIProfile", ["GTIProfile"], root_id);
    idx.add_node(
        bob_id, "GTISpecialProfile", ["GTISpecialProfile", "GTIProfile"], root_id
    );
    idx.add_node(tweet_id, "GTITweet", ["GTITweet"], root_id);
    idx.add_edge(
        follow_id,
        alice_id,
        bob_id,
        "GTIStrongFollow",
        ["GTIStrongFollow", "GTIFollow"]
    );
    idx.add_edge(post_id, bob_id, tweet_id, "GTIPost", ["GTIPost"]);

    assert idx.resolve_chain(
        [alice_id],
        [("GTIFollow", "GTIProfile", 2), ("GTIPost", "GTITweet", 2)],
        10
    ) == [tweet_id];
}


test "builder warms owner topology from seed nodes across roots" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx1 = _ctx(td);
        JacRuntime.exec_ctx = ctx1;
        ids: tuple[UUID, UUID, UUID, UUID, UUID];
        try {
            ids = _seed_cross_root(ctx1);
            ctx1.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx1.close();
        }

        ctx2 = _ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            (alice_root_id, bob_root_id, alice_id, bob_id, tweet_id) = ids;
            idx = ctx2.mem.warm_topology_for_nodes([alice_id]);
            assert isinstance(idx, TopologyIndex);
            assert idx.has_root(alice_root_id);
            assert not idx.has_root(bob_root_id);
            assert idx.owner_root_for(bob_id) == bob_root_id;
            assert idx.resolve_chain(
                [alice_id], [("GTIFollow", "GTIProfile", 2)], 10
            ) == [bob_id];
            assert idx.resolve_chain(
                [alice_id],
                [("GTIFollow", "GTIProfile", 2), ("GTIPost", "GTITweet", 2)],
                10
            ) == [];

            idx = ctx2.mem.warm_topology_for_nodes([bob_id]);
            assert idx.has_root(bob_root_id);
            assert idx.resolve_chain(
                [alice_id],
                [("GTIFollow", "GTIProfile", 2), ("GTIPost", "GTITweet", 2)],
                10
            ) == [tweet_id];
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "filtered hop warm indexes only matching frontier adjacency" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx1 = _ctx(td);
        JacRuntime.exec_ctx = ctx1;
        ids: tuple[UUID, UUID, UUID, UUID, UUID];
        try {
            ids = _seed_cross_root(ctx1);
            ctx1.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx1.close();
        }

        ctx2 = _ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            (alice_root_id, bob_root_id, alice_id, bob_id, tweet_id) = ids;
            idx = ctx2.mem.warm_topology_for_hop(
                [alice_id], "GTIPost", "GTITweet", 2
            );
            assert isinstance(idx, TopologyIndex);
            assert not idx.has_root(alice_root_id);
            assert idx.node_type(alice_id) == "GTIProfile";
            assert idx.resolve_chain(
                [alice_id], [("GTIFollow", "GTIProfile", 2)], 10
            ) == [];

            idx = ctx2.mem.warm_topology_for_hop(
                [alice_id], "GTIFollow", "GTIProfile", 2
            );
            assert not idx.has_root(alice_root_id);
            assert not idx.has_root(bob_root_id);
            assert idx.owner_root_for(bob_id) == bob_root_id;
            assert idx.resolve_chain(
                [alice_id], [("GTIFollow", "GTIProfile", 2)], 10
            ) == [bob_id];
            assert idx.resolve_chain(
                [alice_id],
                [("GTIFollow", "GTIProfile", 2), ("GTIPost", "GTITweet", 2)],
                10
            ) == [];

            idx = ctx2.mem.warm_topology_for_hop([bob_id], "GTIPost", "GTITweet", 2);
            assert idx.resolve_chain(
                [alice_id],
                [("GTIFollow", "GTIProfile", 2), ("GTIPost", "GTITweet", 2)],
                10
            ) == [tweet_id];
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "TTG uses warmed topology to continue across owner roots" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx1 = _ctx(td);
        JacRuntime.exec_ctx = ctx1;
        ids: tuple[UUID, UUID, UUID, UUID, UUID];
        try {
            ids = _seed_cross_root(ctx1);
            ctx1.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx1.close();
        }

        ctx2 = _ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            (alice_root_id, bob_root_id, alice_id, bob_id, tweet_id) = ids;
            alice = ctx2.mem.get(alice_id);
            assert isinstance(alice, NodeAnchor);
            plan = JacTTGGenerator.get_ttg_prefetch_list(
                GTITraverse(), alice, ctx2.mem, max_length=10
            );
            assert bob_id in plan , plan;
            assert tweet_id in plan , plan;
            assert alice_root_id in plan , plan;
            assert bob_root_id in plan , plan;
            assert len(plan) <= 10 , plan;
            assert plan.index(alice_id) < plan.index(alice_root_id) , plan;
            assert plan.index(bob_id) < plan.index(bob_root_id) , plan;

            limited = JacTTGGenerator.get_ttg_prefetch_list(
                GTITraverse(), alice, ctx2.mem, max_length=4
            );
            assert len(limited) == 4 , limited;
            assert alice_id in limited , limited;
            assert alice_root_id in limited , limited;
            assert bob_id in limited , limited;
            assert bob_root_id in limited , limited;
            assert tweet_id not in limited , limited;
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "TTG specialized SQL lowers a multi-hop visit chain" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx1 = _ctx(td);
        JacRuntime.exec_ctx = ctx1;
        ids: tuple[UUID, UUID, UUID, UUID, UUID];
        try {
            ids = _seed_cross_root(ctx1);
            ctx1.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx1.close();
        }

        ctx2 = _ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            (alice_root_id, bob_root_id, alice_id, bob_id, tweet_id) = ids;
            alice = ctx2.mem.get(alice_id);
            assert isinstance(alice, NodeAnchor);
            plan = JacTTGGenerator.get_ttg_prefetch_list(
                GTIMultiHopTraverse(), alice, ctx2.mem, max_length=10
            );
            assert alice_id in plan , plan;
            assert alice_root_id in plan , plan;
            assert tweet_id in plan , plan;
            assert bob_root_id in plan , plan;
            assert bob_id not in plan , plan;
            idx = ctx2.mem.__topology_index__;
            assert isinstance(idx, TopologyIndex);
            assert idx.resolve_chain(
                [alice_id],
                [("GTIFollow", "GTIProfile", 2), ("GTIPost", "GTITweet", 2)],
                10
            ) == [tweet_id];
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}


test "TTG extractor skips explicit non-current edge-ref origins" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx1 = _ctx(td);
        JacRuntime.exec_ctx = ctx1;
        ids: tuple[UUID, UUID, UUID, UUID, UUID];
        try {
            alice_root = _root(ctx1);
            bob_root = _root(ctx1);
            alice = _owned_node(ctx1, alice_root, GTIProfile(name="alice"));
            bob = _owned_node(ctx1, bob_root, GTIProfile(name="bob"));
            tweet = _owned_node(ctx1, alice_root, GTITweet(text="hi"));
            _connect(ctx1, alice, tweet, _as_any(GTIPost()));
            _connect(ctx1, tweet, bob, _as_any(GTIFollow()));
            ids = (
                alice_root.ensure_id(),
                bob_root.ensure_id(),
                alice.ensure_id(),
                bob.ensure_id(),
                tweet.ensure_id()
            );
            ctx1.mem.commit();
        } finally {
            JacRuntime.exec_ctx = old;
            ctx1.close();
        }

        ctx2 = _ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            (alice_root_id, bob_root_id, alice_id, bob_id, tweet_id) = ids;
            loaded = ctx2.mem.get(alice_id);
            assert isinstance(loaded, NodeAnchor);
            plan = JacTTGGenerator.get_ttg_prefetch_list(
                GTIRootSourceMethodTraverse(), loaded, ctx2.mem, max_length=10
            );
            assert alice_id in plan , plan;
            assert alice_root_id in plan , plan;
            assert tweet_id in plan , plan;
            assert bob_id not in plan , plan;
            assert bob_root_id not in plan , plan;
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}
