"""`LayoutPass._acyclic_walk` cannot see a field's type, so it answers "cyclic".

The walk colours each layout while recursing through its fields' types, and it
reaches a field's type like this:

    var = finfo.decl_node;
    tb = var?.type if var is not None else None;
    if tb is None {
        result = 2;      # 2 means "cyclic"
        break;
    }

`decl_node` holds the `HasVar` the field was declared by. `HasVar` derives
from `AstSymbolNode` and `AstTypedVarNode`, and neither declares `type` --
only `Expr` does. So `var?.type` degrades to None for every field that has a
declaration node at all, the loop breaks on the first one, and `is_acyclic`
comes out False for every layout with fields. The type expression the walk
wants is `var.type_tag.tag`, whose stamped `.type` is the `TypeBase` that has
`mangle()`.

This is the two remaining module-level checker errors in `layout_pass` --
`Type "NoneType" has no attribute "mangle"` and the `<Unknown>` assignment
behind it. Every other error in the pass cleared; these two are the checker
correctly refusing to type a read that never had an answer.

The fix is deliberately not made here, and the reason is scope rather than
difficulty. `is_acyclic` feeds the cycle collector: today it is stuck on the
conservative answer, and correcting it turns cycle collection off for layouts
the walk decides are acyclic. That is a runtime memory-management change, it
needs the SCC colouring and `_expand_type_keys`' key round-trip validated
against real archetypes first, and getting it wrong frees early rather than
merely leaking. It belongs with the ownership/rc work, not with a pass-seal
burn-down.

What this test does is stop the read from being invisible. It pins the
attribute's absence -- which is the whole cause, and is a one-line fact -- so
the day `HasVar` grows a `type` (or the walk is pointed at `type_tag.tag`)
this fails and says what to reconsider.
"""

import jaclang.jac0core.unitree as uni;


"""Whether a node type declares a has-field of the given name, anywhere in its MRO.

The slot is a per-instance field, so it is absent from the class itself; the
declaration shows up in `__annotations__` of whichever ancestor declares it.
"""
def _declares(node_type: type, field: str) -> bool {
    for cls in node_type.__mro__ {
        if field in getattr(cls, '__annotations__', {}) {
            return True;
        }
    }
    return False;
}


test "HasVar carries no type slot, which is why the acyclicity walk gives up" {
    assert not _declares(uni.HasVar, 'type') , (
        "HasVar declares a 'type' field now. LayoutPass._acyclic_walk reads "
        "`var?.type` off it and has been getting None for every field, so "
        "every layout came out cyclic. Re-check that walk: it may now be "
        "live for the first time, and it gates the cycle collector"
    );
    assert _declares(uni.Expr, 'type') , (
        "Expr lost its stamped type slot; the walk's intended target is "
        "`var.type_tag.tag.type`, which is an Expr"
    );
    assert _declares(uni.HasVar, 'type_tag') , (
        "HasVar lost type_tag, which is where its declared type expression "
        "actually lives"
    );
}
