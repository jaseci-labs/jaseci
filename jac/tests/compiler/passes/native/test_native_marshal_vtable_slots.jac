"""The marshaller mirrors slots no `has` names (#8084).

`LayoutPass._build_layout` seeds `current_idx` with a vtable pointer slot for
any class that has a parent, is a parent, or is an `isinstance` target, and
with a second slot for an OSP archetype's type tag. Neither belongs to a
`has`, so the first named field of such a class carries `index == 1` or
`index == 2`. `build_ctypes_classes` appended only the named fields, so every
one of them landed a slot (or two) low and read its neighbour's bytes -- a
well-typed wrong value, never an error.

Both halves are pinned: the offsets the mirror actually produces, and the
values a Python caller reads back through it.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_force_opts }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.native_marshal {
    build_ctypes_classes,
    build_enum_maps,
    wrap_native_function
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     ),
     _MEMO: list = [];

"""Byte offset a ctypes mirror gives a named field."""
def field_offset(cls: type, name: str) -> int {
    return getattr(cls, name).offset;
}

"""Compile the fixture once; hand back its layout, ctypes mirrors and wrappers."""
def slots_fixture -> tuple[dict, dict, uni.Module] {
    if _MEMO {
        return _MEMO[0];
    }
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, "marshal_vtable_slots.jac")),
        options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
    layout = ir.gen.native_layout;
    assert layout is not None , "no native layout exported";
    classes = build_ctypes_classes(layout);
    enum_maps = build_enum_maps(layout, {});
    fns: dict = {};
    for (fname, func_layout) in layout.functions.items() {
        wrapper = wrap_native_function(
            ir.gen.native_engine, func_layout, classes, enum_maps, {}, layout=layout
        );
        if wrapper is not None {
            fns[fname] = wrapper;
        }
    }
    result = (fns, classes, ir, );
    _MEMO.append(result);
    return result;
}


test "a class without a vtable starts at slot 0" {
    (_fns, classes, ir) = slots_fixture();
    fields = ir.gen.native_layout.structs["Plain"].fields;
    assert fields[0].index == 0 , (
        f"'Plain' should need no vtable slot, got index {fields[0].index}"
    );
    assert ctypes.sizeof(classes["Plain"]) == 16 , "two i64 fields, no filler";
}


test "a vtabled class reserves one slot ahead of its first field" {
    (_fns, classes, ir) = slots_fixture();
    for name in ("Base", "Derived") {
        sl = ir.gen.native_layout.structs[name];
        assert sl.has_vtable , f"'{name}' should carry a vtable";
        assert sl.fields[0].index == 1 , (
            f"'{name}' first field should sit in slot 1, got {sl.fields[0].index}"
        );
        for f in sl.fields {
            got = field_offset(classes[name], f.name);
            assert got == f.index * 8 , (
                f"'{name}.{f.name}' mirrors at byte {got}, layout slot "
                f"{f.index} puts it at {f.index * 8}"
            );
        }
    }
}


test "an OSP archetype reserves a second slot for its type tag" {
    (_fns, classes, ir) = slots_fixture();
    sl = ir.gen.native_layout.structs["Tagged"];
    assert sl.fields[0].index == 2 , (
        f"'Tagged' first field should sit in slot 2 (vtable + type tag), got "
        f"{sl.fields[0].index}"
    );
    assert field_offset(classes["Tagged"], "n") == 16 , (
        "the type tag slot is not mirrored"
    );
}


test "fields of a vtabled class read back by value, not one slot low" {
    (fns, _classes, _ir) = slots_fixture();
    base = fns["make_base"]();
    assert (base.x, base.y) == (1, 2) , (
        f"Base read back as ({base.x}, {base.y}); a one-slot shift reads the "
        "vtable pointer as `x`"
    );
    derived = fns["make_derived"]();
    assert (derived.x, derived.y, derived.z) == (1, 2, 3) , (
        f"Derived read back as ({derived.x}, {derived.y}, {derived.z})"
    );
    plain = fns["make_plain"]();
    assert (plain.a, plain.b) == (11, 22) , "the un-vtabled control still reads";
}
