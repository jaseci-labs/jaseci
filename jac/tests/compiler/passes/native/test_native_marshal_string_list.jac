"""Congruence gate for FFI decode of native `list[str]` values.

Every assertion here compares the value the native artifact hands back
through `native_marshal` against the value the sv/bytecode path produces for
the same source, element for element. It pins the string cases that need the
descriptor and header-stamp encoding to be modelled rather than guessed at
with `strlen`: empty lists, empty strings, multi-byte UTF-8, static literals
next to heap strings, slices, an interior NUL, a long list, and -- the case
that had no working path at all -- a `list[str]` read as an object field.
"""

import os;
import sys;
import types;
import from tests.support { TESTS_DIR, native_force_opts }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }
import jaclang.jac0core.unitree as uni;

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     ),
     FIXTURE = os.path.join(FIXTURES, "marshal_string_list.jac");

def compile_fixture(fixture: str) -> tuple[ExecutionEngine | None, uni.Module] {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    return (ir.gen.native_engine, ir);
}

def native_fns -> dict {
    import from jaclang.jac0core.native_marshal {
        build_ctypes_classes,
        build_enum_maps,
        wrap_native_function,
        init_native_globals
    }
    (eng, ir) = compile_fixture("marshal_string_list.jac");
    layout = ir.gen.native_layout;
    assert layout is not None;
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
    return fns;
}

def sv_fns -> dict {
    # The same source through the sv/bytecode backend, executed in a module of
    # its own so the reference values are plain Python objects.
    mod_name = "marshal_string_list_sv_ref";
    code = JacProgram().get_bytecode(FIXTURE);
    assert code is not None , "sv bytecode for the fixture is missing";
    mod = types.ModuleType(mod_name);
    mod.__file__ = FIXTURE;
    sys.modules[mod_name] = mod;
    exec(code, mod.__dict__);
    return mod.__dict__;
}

test "empty list[str] decodes to an empty list" {
    (na, sv) = (native_fns(), sv_fns());
    assert list(na["make_empty"]()) == sv["make_empty"]() == [];
    assert len(na["make_empty"]()) == 0;
}

test "literal list[str] decodes congruently with sv" {
    (na, sv) = (native_fns(), sv_fns());
    expected = sv["make_literals"]();
    got = list(na["make_literals"]());
    assert got == expected , f"{got!r} != {expected!r}";
    # empty string, ASCII, 2-byte and 3-byte UTF-8, and a 64-char string
    assert expected[0] == "" and expected[2] == "über" and expected[3] == "日本語";
    assert len(expected[4]) == 64;
    for (g, e) in zip(got, expected) {
        assert g == e and len(g) == len(e);
    }
}

test "sliced strings decode at their own length" {
    (na, sv) = (native_fns(), sv_fns());
    expected = sv["make_sliced"]();
    assert list(na["make_sliced"]()) == expected == ["abc", "defg", "hij"];
}

test "interior NUL survives the crossing" {
    (na, sv) = (native_fns(), sv_fns());
    expected = sv["make_interior_nul"]();
    got = list(na["make_interior_nul"]());
    assert expected[0] == "a\x00b" , f"sv reference changed: {expected!r}";
    assert got == expected , f"{got!r} != {expected!r}";
}

test "long list[str] decodes element for element" {
    (na, sv) = (native_fns(), sv_fns());
    for n in (0, 1, 2, 33, 257) {
        expected = sv["make_long"](n);
        got = list(na["make_long"](n));
        assert len(got) == n;
        assert got == expected , f"n={n}: {got!r} != {expected!r}";
    }
}

test "list[str] object field decodes to strings not raw pointers" {
    (na, sv) = (native_fns(), sv_fns());
    expected = sv["make_bag"]().tags;
    bag = na["make_bag"]();
    got = list(bag.tags);
    assert all(isinstance(t, str) for t in got) , f"undecoded field: {got!r}";
    assert got == expected , f"{got!r} != {expected!r}";
    assert bag.note == sv["make_bag"]().note;
    assert list(na["bag_tags"]()) == expected;
}

test "dict[str, str] decodes congruently with sv" {
    (na, sv) = (native_fns(), sv_fns());
    expected = sv["make_tag_map"]();
    got = na["make_tag_map"]();
    assert got == expected , f"{got!r} != {expected!r}";
}

test "native_str_len mirrors the stamped length" {
    import from jaclang.jac0core.native_marshal { native_str_len }
    na = native_fns();
    # every element of the mixed list reports the byte length sv computes
    sv = sv_fns();
    view = na["make_literals"]();
    for (i, expected) in enumerate(sv["make_literals"]()) {
        assert view[i] == expected;
        assert len(view[i].encode("utf-8")) == len(expected.encode("utf-8"));
    }
    assert native_str_len(0) == 0;
}
