"""Marshalled-view reads over runtime-class-canonical views (#8093).

Views re-key to their runtime class from the rc header's class-name stamp,
so one native node behind two declared types is one view -- the identity
every per-node Python-side state (the foreign overlay) rides on. The rest
of this suite pins the read surfaces Python-side consumers hit on such
views: demoted accessors fall back to the declared Python property,
foreign slots live on the overlay, list fields keep their element hints
through optional and union annotations, an opaque generic slot resolves
its object through the same class stamp, and a field named `items` is a
field, not a mapping helper.
"""

import os;
import from tests.support { TESTS_DIR, native_force_opts }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     ),
     _MEMO: list = [];

obj TwinBase {
    has tag: int = 0;
    has double_tag: int { getter; }
}

impl TwinBase.double_tag.getter -> int {
    return self.tag * 2;
}

obj TwinSub(TwinBase) {}

def view_fns -> dict {
    import from jaclang.jac0core.native_marshal {
        build_ctypes_classes,
        build_enum_maps,
        wrap_native_function,
        init_native_globals
    }
    if _MEMO {
        return _MEMO[0];
    }
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, "marshal_views.jac")),
        options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
    eng = ir.gen.native_engine;
    layout = ir.gen.native_layout;
    assert eng is not None and layout is not None;
    init_native_globals(eng, ir.gen.interop_manifest);
    ct_classes = build_ctypes_classes(layout);
    enum_maps = build_enum_maps(layout, {});
    fns: dict = {};
    for (fname, func_layout) in layout.functions.items() {
        wrapper = wrap_native_function(
            eng,
            func_layout,
            ct_classes,
            enum_maps,
            {"BaseN": TwinBase, "SubN": TwinSub},
            layout=layout
        );
        if wrapper is not None {
            fns[fname] = wrapper;
        }
    }
    _MEMO.append(fns);
    return fns;
}

test "two declared types of one node are one view" {
    fns = view_fns();
    h = fns["make_holder"]();
    assert h.as_base is h.as_sub , (
        "views are canonical per pointer across declared types"
    );
    assert h.as_base.kind == 2 , "and carry the runtime class";
}

test "a demoted accessor falls back to the declared python property" {
    fns = view_fns();
    h = fns["make_holder"]();
    assert h.as_base.double_tag == h.as_base.tag * 2 , (
        "the property body runs over the view"
    );
}

test "foreign scratch state rides the canonical view" {
    fns = view_fns();
    b = fns["make_box"]();
    assert b.scratch is None , "an unset foreign slot reads None";
    marker = object();
    b.scratch = marker;
    assert b.scratch is marker , "the overlay store round-trips";
}

test "optional list fields keep their element hints" {
    fns = view_fns();
    b = fns["make_bag"]();
    pads = b.opt_pads;
    assert len(pads) == 2;
    assert pads[0].note == 5 , "elements marshal as views, not bare pointers";
}

test "union-element list fields keep their element hints" {
    fns = view_fns();
    b = fns["make_bag"]();
    mixed = b.mixed;
    assert len(mixed) == 2;
    assert mixed[0].tag == 1 , "a BaseN element reads its fields";
    assert mixed[1].note == 5 , "a Pad element re-keys to its runtime class";
}

test "an opaque generic slot resolves its object" {
    fns = view_fns();
    bx = fns["make_box"]();
    held = bx.held;
    assert not isinstance(held, str) , "an object is not decoded as text";
    assert held.note == 5;
}

test "a field named items is a field" {
    fns = view_fns();
    c = fns["make_crate"]();
    assert len(c.items) == c.n , "the node field wins, not a mapping helper";
    assert c.items[0].note == 5;
}
