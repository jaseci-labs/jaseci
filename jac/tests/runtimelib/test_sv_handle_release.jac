"""Destroying a graph-connected node must release its sv-store handle.

`osp_graph_sv._mint` pins every registered anchor in the process-global
`_obj_of_h` table. `sv_forget_by_id` used to leave that entry in place, so a
node destroyed through the compiled-jac `del` lowering (which calls
`JacPersistence.destroy`) kept its anchor — and through `anchor.archetype`,
the node object itself — alive against every gc pass. These tests pin the
release: after destroy, the weakref dies, the handle slot is recycled, and a
re-minted handle is not aliased to the dead anchor.
"""

import jaclang.runtime.osp_graph_sv as _sv;
import from gc { collect }
import from weakref { ref }
import from jaclang.runtime.runtime { JacRuntimeInterface }

node LeakNode {
    has tag: str = "";
}


test "destroying a connected node releases its anchor against gc" {
    n = LeakNode(tag="doomed");
    JacRuntimeInterface.connect(JacRuntimeInterface.root(), n);
    w = ref(n);
    h = _sv.handle_of(n.__jac__);
    assert w() is not None;

    JacRuntimeInterface.destroy([n]);
    collect();

    assert w() is None , "destroyed node survived gc: sv handle still pins it";
    assert _sv.obj_of(h) is None , "handle slot was not released on forget";
}

test "forgetting releases the handle for reuse without aliasing" {
    n = LeakNode(tag="forgotten");
    JacRuntimeInterface.connect(JacRuntimeInterface.root(), n);
    anch = n.__jac__;
    h = _sv.handle_of(anch);
    JacRuntimeInterface.destroy([n]);

    fresh = LeakNode(tag="fresh").__jac__;
    h2 = _sv.handle_of(fresh);

    assert h2 != h or _sv.obj_of(h) is fresh , "recycled handle aliased a dead anchor";
    assert _sv.obj_of(h2) is fresh;
}
