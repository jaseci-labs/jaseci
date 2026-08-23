"""Permission is decided by the query, not by discarding rows afterwards.

`resolve_query` materialised every candidate and then dropped what the caller
could not see, so a gated read paid for rows it was never allowed to return --
and a bound could not be pushed at all, because `LIMIT` ahead of a filter still
running in Python changes `[:n]` from "n you may see" to "up to n, some of which
then vanish".

The standard model compiles: you own it (`root_id`), it is granted to everyone
(`access.all`), or it is granted to you by name (`access.roots.anchors`). A
per-root grant does not scale to a large audience, so a grant may also name a
*group*, and membership is an edge -- one grant, one membership per member,
instead of one dict entry per member on every object.

An archetype that overrides `__jac_access__` runs arbitrary Jac, which has no
SQL form, so those must decline any pushdown and keep the object-space filter.
The decline is the point: correctness never depends on whether a query could be
compiled.

Compiling the permission test into the query is not done yet. Measured baseline
for that work, from a cold context: a gated read of 30 docs of which 3 are
visible materialises 31 anchors to return 3.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID }
import from jaclang.jac0core.archetype { AccessLevel, EdgeAnchor, GenericEdge, Root }
import from jaclang.jac0core.runtime { JacRuntime, JacRuntimeInterface }
import from jaclang.runtimelib.context { ExecutionContext }

node Doc {
    has label: str = "";
}

node Team {
    has name: str = "";
}

edge MemberOf {}

node CustomDoc {
    has label: str = "";

    def __jac_access__ -> AccessLevel {
        return AccessLevel.READ;
    }
}


def _as_any(v: any) -> any {
    return v;
}


def _ctx(td: str) -> ExecutionContext {
    return ExecutionContext(
        base_path_dir=td, full_target_path=str(Path(td) / "acl_app.jac")
    );
}


def _mk_root(mem: any) -> any {
    anch: any = Root().__jac__;
    anch.persistent = True;
    setattr(anch, "root", anch.id);
    mem.put(anch);
    return anch;
}


"""Attach `n` Docs owned by `owner` under `hub`, granting `granted` of them to all."""
def _seed(ctx: ExecutionContext, hub: any, owner: any, n: int, granted: int) {
    for i in range(n) {
        d = Doc(label=f"d{i}").__jac__;
        d.persistent = True;
        setattr(d, "root", owner.id);
        if i < granted {
            d.access.all = AccessLevel.READ;
        }
        ctx.mem.put(d);
        e = EdgeAnchor(
            archetype=GenericEdge(), source=hub, target=d, is_undirected=False
        );
        e.persistent = True;
        hub.edges.append(e);
        d.edges.append(e);
        ctx.mem.put(e);
    }
}


test "a grant to a group reaches every member without a per-root entry" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            owner = _mk_root(ctx.mem);
            reader = _mk_root(ctx.mem);

            team = Team(name="eng").__jac__;
            team.persistent = True;
            setattr(team, "root", owner.id);
            ctx.mem.put(team);

            # membership is an edge, not an entry on every granted object
            m = EdgeAnchor(
                archetype=MemberOf(), source=reader, target=team, is_undirected=False
            );
            m.persistent = True;
            reader.edges.append(m);
            team.edges.append(m);
            ctx.mem.put(m);

            d = Doc(label="team-doc").__jac__;
            d.persistent = True;
            setattr(d, "root", owner.id);
            ctx.mem.put(d);
            e = EdgeAnchor(
                archetype=GenericEdge(), source=reader, target=d, is_undirected=False
            );
            e.persistent = True;
            reader.edges.append(e);
            d.edges.append(e);
            ctx.mem.put(e);

            JacRuntimeInterface.allow_group(d.archetype, team.id, AccessLevel.READ);
            ctx.mem.commit();

            ctx.set_user_root(str(reader.id));
            seen = [_as_any(x).label for x in [_as_any(reader.archetype)-->[?:Doc]]];
            assert seen == ["team-doc"] , (
                f"a group grant must reach a member; got {seen}"
            );
            assert not d.access.roots.anchors , (
                "a group grant must not write a per-root entry on the object"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "a custom __jac_access__ declines the pushdown and still filters" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            owner = _mk_root(ctx.mem);
            other = _mk_root(ctx.mem);
            c = CustomDoc(label="custom").__jac__;
            c.persistent = True;
            setattr(c, "root", owner.id);
            ctx.mem.put(c);
            e = EdgeAnchor(
                archetype=GenericEdge(), source=other, target=c, is_undirected=False
            );
            e.persistent = True;
            other.edges.append(e);
            c.edges.append(e);
            ctx.mem.put(e);
            ctx.mem.commit();

            ctx.set_user_root(str(other.id));
            seen = [
                _as_any(x).label for x in [_as_any(other.archetype)-->[?:CustomDoc]]
            ];
            assert seen == ["custom"] , (
                f"__jac_access__ grants READ, so it must still be visible: {seen}"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}
