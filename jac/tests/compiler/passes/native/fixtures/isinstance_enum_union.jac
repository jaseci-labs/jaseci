"""`isinstance` against an enum class over a union operand.

Enum members box as ints, so they carry jacval tag 0, and the check lowers to
a tag compare exactly when the union gives the named enum sole ownership of
that tag. `Access | AccessNode | None` does -- an object is tag 6 and None is
tag 8 -- and so does `Access | bool`, since bool is tag 7. The union where it
does not lives in `isinstance_enum_tag_clash.jac`.

`Access` is deliberately string-valued: the boxed representation is the
ordinal either way, and the compiler's own `SymbolAccess` is a string enum.
"""

enum Access { PRIVATE = 'private', PUBLIC = 'public', PROTECTED = 'protected' }

obj AccessNode {
    has access_type: Access = Access.PROTECTED;
}

def chk_enum(pick: int) -> bool {
    spec: (Access | AccessNode | None) = None;
    if pick == 1 {
        spec = Access.PUBLIC;
    } elif pick == 2 {
        spec = AccessNode();
    }
    return isinstance(spec, Access);
}

def chk_node(pick: int) -> bool {
    spec: (Access | AccessNode | None) = None;
    if pick == 1 {
        spec = Access.PUBLIC;
    } elif pick == 2 {
        spec = AccessNode();
    }
    return isinstance(spec, AccessNode);
}

"""`UniScopeNode.insert`'s shape: an access spec that is either an already
resolved member, a node carrying one, or absent."""
def resolve_access(pick: int) -> int {
    spec: (Access | AccessNode | None) = None;
    if pick == 1 {
        spec = Access.PUBLIC;
    } elif pick == 2 {
        spec = AccessNode();
    }
    resolved: Access = Access.PRIVATE;
    if isinstance(spec, Access) {
        resolved = spec;
    } elif isinstance(spec, AccessNode) {
        resolved = spec.access_type;
    }
    if resolved == Access.PRIVATE {
        return 0;
    }
    if resolved == Access.PUBLIC {
        return 1;
    }
    return 2;
}

"""bool owns tag 7, so the enum still owns tag 0 alone and the tag compare
has to separate them by tag rather than by value."""
def chk_enum_over_bool(pick: int) -> bool {
    spec: (Access | bool) = False;
    if pick == 1 {
        spec = Access.PUBLIC;
    } elif pick == 2 {
        spec = True;
    }
    return isinstance(spec, Access);
}
