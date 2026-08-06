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


"""Engine-only hop: hop_rows for types/direction, filter_ids for preds --
the same composition the planner performs for non-resident ids."""
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


