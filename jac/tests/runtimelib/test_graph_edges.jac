"""Storage-owned graph index: graph_edges/graph_types maintained inside
SqliteMemory.apply(ChangeSet), auto-reindex on open, and hop_ids engine
execution in id space."""

import os;
import sqlite3;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.jac0core.archetype { EdgeAnchor, GenericEdge, NodeAnchor, Root }
import from jaclang.jac0core.graph_query { QHop, QPred }
import from jaclang.runtimelib.changeset { ChangeSet }
import from jaclang.runtimelib.memory { SqliteMemory }


node GA {
    has val: int = 0;
}

node GA2(GA) {}

node GB {
    has tag: str = "";
}

edge Rel {
    has w: int = 0;
}


"""root --Rel(w)--> each payload node; returns (root_anchor, node_anchors)."""
def _build(payloads: list) -> tuple {
    ranch = Root().__jac__;
    ranch.persistent = True;
    anchors: list = [];
    for (arch, w) in payloads {
        nanch = arch.__jac__;
        nanch.persistent = True;
        eanch = EdgeAnchor(
            archetype=Rel(w=w), source=ranch, target=nanch, is_undirected=False
        );
        eanch.persistent = True;
        ranch.edges.append(eanch);
        nanch.edges.append(eanch);
        anchors.append((nanch, eanch));
    }
    return (ranch, anchors);
}


def _apply_all(db_path: str, ranch: NodeAnchor, anchors: list) {
    cs = ChangeSet();
    cs.record_create(ranch);
    for (nanch, eanch) in anchors {
        cs.record_create(nanch);
        cs.record_create(eanch);
    }
    mem = SqliteMemory(path=db_path);
    rep = mem.apply(cs);
    assert rep.ok() , f"apply failed: {rep.failed}";
    mem.close();
}


test "apply maintains graph_edges and graph_types" {
    with TemporaryDirectory() as td {
        db = str(Path(td) / "g.db");
        (ranch, anchors) = _build([(GA(val=1), 1), (GB(tag="x"), 2)]);
        _apply_all(db, ranch, anchors);
        raw = sqlite3.connect(db);
        rows = raw.execute(
            "SELECT src, dst, edge_type, undirected FROM graph_edges ORDER BY rowid"
        ).fetchall();
        assert len(rows) == 2 , f"expected 2 edge rows, got {rows}";
        assert rows[0][0] == str(ranch.id);
        assert rows[0][2] == 'Rel';
        tpairs = set(
            raw.execute("SELECT type_name, ancestor FROM graph_types").fetchall()
        );
        assert ('GA', 'GA') in tpairs;
        assert ('Rel', 'Rel') in tpairs;
        raw.close();
    }
}


test "edge and node deletes purge graph_edges" {
    with TemporaryDirectory() as td {
        db = str(Path(td) / "g.db");
        (ranch, anchors) = _build([(GA(val=1), 1), (GA(val=2), 2)]);
        _apply_all(db, ranch, anchors);
        (n1, e1) = anchors[0];
        cs = ChangeSet();
        cs.record_delete(e1);
        mem = SqliteMemory(path=db);
        assert mem.apply(cs).ok();
        mem.close();
        raw = sqlite3.connect(db);
        left = raw.execute("SELECT edge_id FROM graph_edges").fetchall();
        assert len(left) == 1 and left[0][0] != str(e1.id);
        raw.close();
        (n2, e2) = anchors[1];
        cs2 = ChangeSet();
        cs2.record_delete(n2);
        mem2 = SqliteMemory(path=db);
        assert mem2.apply(cs2).ok();
        mem2.close();
        raw2 = sqlite3.connect(db);
        assert raw2.execute("SELECT COUNT(*) FROM graph_edges").fetchone()[0] == 0;
        raw2.close();
    }
}


test "hop_ids narrows by type, subtype, and predicates in id space" {
    with TemporaryDirectory() as td {
        db = str(Path(td) / "g.db");
        (ranch, anchors) = _build(
            [(GA(val=1), 10), (GA(val=2), 20), (GA2(val=3), 30), (GB(tag="x"), 40)]
        );
        _apply_all(db, ranch, anchors);
        mem = SqliteMemory(path=db);
        src = [ranch.id];
        assert len(mem.hop_ids(src, QHop(dir=2))) == 4;
        assert len(mem.hop_ids(src, QHop(dir=2, nd=GA))) == 3;
        assert len(mem.hop_ids(src, QHop(dir=2, nd=GA2))) == 1;
        assert len(mem.hop_ids(src, QHop(dir=2, nd=GB))) == 1;
        hit = mem.hop_ids(
            src, QHop(dir=2, nd=GA, preds=[QPred(field="val", op="==", value=2)])
        );
        assert hit == [anchors[1][0].id];
        le = mem.hop_ids(
            src, QHop(dir=2, nd=GA, preds=[QPred(field="val", op="<=", value=2)])
        );
        assert len(le) == 2;
        inn = mem.hop_ids(
            src, QHop(dir=2, nd=GA, preds=[QPred(field="val", op="in", value=(1, 3))])
        );
        assert len(inn) == 2;
        epred = mem.hop_ids(
            src, QHop(dir=2, epreds=[QPred(field="w", op=">", value=25)])
        );
        assert len(epred) == 2;
        ordered = mem.hop_ids(src, QHop(dir=2), ordered=True);
        assert ordered == [a[0].id for a in anchors];
        rev = mem.hop_ids([anchors[0][0].id], QHop(dir=1));
        assert rev == [ranch.id];
        assert mem.hop_ids([anchors[0][0].id], QHop(dir=2)) == [];
        assert mem.hop_ids([anchors[0][0].id], QHop(dir=3)) == [ranch.id];
        mem.close();
    }
}


test "type-drifted ordering predicate is exact, never cross-type" {
    with TemporaryDirectory() as td {
        db = str(Path(td) / "g.db");
        (ranch, anchors) = _build([(GB(tag="zz"), 1)]);
        _apply_all(db, ranch, anchors);
        mem = SqliteMemory(path=db);
        # tag is text; a numeric ordering comparison must exclude it exactly
        # as Python's TypeError -> False would, not by SQLite type ordering.
        drift = mem.hop_ids(
            [ranch.id], QHop(dir=2, preds=[QPred(field="tag", op=">", value=5)])
        );
        assert drift == [];
        txt = mem.hop_ids(
            [ranch.id], QHop(dir=2, preds=[QPred(field="tag", op=">", value="aa")])
        );
        assert len(txt) == 1;
        mem.close();
    }
}


test "undirected edges traverse both ways" {
    with TemporaryDirectory() as td {
        db = str(Path(td) / "g.db");
        ranch = Root().__jac__;
        ranch.persistent = True;
        nanch = GA(val=7).__jac__;
        nanch.persistent = True;
        eanch = EdgeAnchor(
            archetype=GenericEdge(), source=ranch, target=nanch, is_undirected=True
        );
        ranch.edges.append(eanch);
        nanch.edges.append(eanch);
        cs = ChangeSet();
        cs.record_create(ranch);
        cs.record_create(nanch);
        cs.record_create(eanch);
        mem = SqliteMemory(path=db);
        assert mem.apply(cs).ok();
        # OUT from the *target* side crosses an undirected edge.
        assert mem.hop_ids([nanch.id], QHop(dir=2)) == [ranch.id];
        assert mem.hop_ids([ranch.id], QHop(dir=2)) == [nanch.id];
        mem.close();
    }
}


test "auto-reindex rebuilds graph_edges from committed anchors" {
    with TemporaryDirectory() as td {
        db = str(Path(td) / "g.db");
        (ranch, anchors) = _build([(GA(val=1), 1), (GA2(val=2), 2)]);
        _apply_all(db, ranch, anchors);
        # Simulate a pre-graph-index database: drop the derived tables.
        raw = sqlite3.connect(db);
        raw.execute("DROP TABLE graph_edges");
        raw.execute("DROP TABLE graph_types");
        raw.execute(
            "UPDATE schema_meta SET value = '1' WHERE key = 'db_format_version'"
        );
        raw.commit();
        raw.close();
        mem = SqliteMemory(path=db);
        got = mem.hop_ids([ranch.id], QHop(dir=2, nd=GA));
        assert len(got) == 2 , f"reindex should restore subtype rows, got {got}";
        mem.close();
        raw2 = sqlite3.connect(db);
        ver = raw2.execute(
            "SELECT value FROM schema_meta WHERE key = 'db_format_version'"
        ).fetchone()[0];
        assert ver == '2';
        raw2.close();
    }
}
