"""Accessor fields resolve through `NativeStructView.__getattr__` (#8092).

#8074 removed accessor-only fields' data slots, so the Python-side bridge
cannot find them in the struct layout: before this fix every read below
raised `AttributeError: 'Part' has no field 'doubled'`. The bridge now
routes such reads through the emitted `Cls.field.__get__` body and marshals
the result exactly as a data field of that type would, so every assertion
here checks a value, not a mechanism. `label` pins virtual dispatch: the
view is statically `Tagged`, the runtime class is `Renamed`, and the
override must run.
"""

import os;
import from tests.support { TESTS_DIR, native_force_opts }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }
import jaclang.jac0core.unitree as uni;

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     ),
     _MEMO: list = [];

def accessor_fns -> dict {
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
        file_path=str(os.path.join(FIXTURES, "marshal_accessors.jac")),
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
            eng, func_layout, ct_classes, enum_maps, {}, layout=layout
        );
        if wrapper is not None {
            fns[fname] = wrapper;
        }
    }
    _MEMO.append(fns);
    return fns;
}

test "accessor with no backing slot reads by value through the bridge" {
    fns = accessor_fns();
    p = fns["make_part"](9);
    assert p.doubled == 18 , "the getter runs over the live head";
    assert fns["make_part"](0).doubled == 0 , "not a stale slot";
}

test "accessor over a backing slot reads the backing slot" {
    fns = accessor_fns();
    p = fns["make_part"](9);
    assert p.width == 3 , "width returns _width's default";
}

test "str-returning accessor decodes to a python str" {
    fns = accessor_fns();
    p = fns["make_part"](9);
    assert p.title == "part:gear";
}

test "optional accessor marshals value and None" {
    fns = accessor_fns();
    assert fns["make_part"](9).nick == "gear";
    assert fns["make_part"](0).nick is None;
}

test "archetype-returning accessor marshals to a struct view" {
    fns = accessor_fns();
    p = fns["make_part"](9);
    o = p.origin;
    assert (o.x, o.y) == (4, 9);
    assert p.origin is o , "repeated reads dedup through the view memo";
}

test "assigning an accessor field runs the setter body" {
    fns = accessor_fns();
    p = fns["make_part"](9);
    p.width = 4;
    assert p._width == 40 , "the setter multiplies by ten before storing";
    assert p.width == 40 , "the read-back goes through the getter";
}

test "an overridden accessor dispatches on the runtime class" {
    fns = accessor_fns();
    assert fns["make_tagged"](0).label == 101 , "Tagged.label.getter";
    assert fns["make_tagged"](1).label == 102 , "Renamed.label.getter overrides it";
}

test "unknown-name reads keep the AttributeError shape; stores annotate" {
    fns = accessor_fns();
    p = fns["make_part"](9);
    try {
        p.no_such_field;
        assert False , "expected AttributeError";
    } except AttributeError as e {
        assert "'Part' has no field 'no_such_field'" in str(e);
    }
    # A name the native layout never carried is Python-side annotation
    # state: the store lands on the view's overlay instead of raising.
    p.no_such_field = 1;
    assert p._py_overlay.get("no_such_field") == 1;
}

test "real data fields still read around the accessors" {
    fns = accessor_fns();
    p = fns["make_part"](9);
    assert (p.head, p.tail) == (9, 11) , "no slot shift from the properties";
    assert p.name == "gear";
}
