"""A direct field store through a mixin-typed reference, checked by value (#8086).

Fields are numbered in MRO order, so a mixin's field sits at a different slot
in every class that reaches it through a different linearization. A store
compiled at the static base's single index therefore lands on a neighbouring
field in any class whose linearization disagrees -- `mixin_field_store.jac`
puts `code` at index 1, 4 and 5 across its three concrete classes.

Nothing about that failure is loud: the write succeeds and the object stays
well-formed, so "did it compile" answers yes either way. Every assertion here
is a value read back through the *concrete* class -- `code` itself, plus the
sum of every other field, which is a per-class constant that only moves when a
store strays -- and every function is additionally compared against the
sv/bytecode result of the same fixture, the parity idiom `union_slot_ops` uses.

`store_via_setter` routes the same write through a dispatched setter on the
mixin. That was the workaround shape (`ContextAwareNode.set_code_context`)
while direct polymorphic stores were broken; keeping both here pins that they
now agree, which is what makes the workaround safe to delete.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_force_opts }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.jac0core.codeinfo {
    get_effective_default_codespace_override,
    set_effective_default_codespace
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     ),
     FIXTURE = "mixin_field_store.jac",
     ALL_FNS = [
         "store_direct",
         "store_then_read_through_base",
         "store_through_param",
         "store_through_list_elem",
         "list_others_untouched",
         "aug_store_direct",
         "store_via_setter",
         "direct_matches_setter"
     ],
     PICKS = [0, 1, 2],
     # Sum of every field but `code`, per concrete class: First 30+9+40,
     # Later 20+21+22+9+41, Deep 30+20+21+22+9+42.
     NEIGHBOURS = [79, 113, 144],
     _ENGINE_MEMO: list = [];

"""Compile the fixture natively once and hand back its JIT engine."""
def _engine -> object {
    if _ENGINE_MEMO {
        return _ENGINE_MEMO[0];
    }
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, FIXTURE)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {FIXTURE}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {FIXTURE}";
    _ENGINE_MEMO.append(eng);
    return eng;
}


"""ctypes handle for an (int) -> int function in the JIT engine."""
def _get(name: str) -> object {
    addr = _engine().get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr);
}


"""Import the same fixture through the sv/bytecode pathway."""
def _sv_module -> object {
    prev = get_effective_default_codespace_override();
    set_effective_default_codespace("server");
    try {
        mods = JacRuntime.jac_import(
            target=FIXTURE[:-4], base_path=FIXTURES, reload_module=True
        );
    } finally {
        set_effective_default_codespace(prev);
    }
    assert mods , "sv import of the fixture produced no module";
    return mods[0];
}


test "a direct store through a base-typed local lands in the right slot" {
    f = _get("store_direct");
    for pick in PICKS {
        want = 777 * 10000 + NEIGHBOURS[pick];
        assert f(pick) == want , (
            f"class {pick}: got {f(pick)}, want {want} -- the low four digits are "
            "the sum of every field but `code`, so a changed tail means the store "
            "hit a neighbour, and a changed head means `code` never got the value"
        );
    }
}


test "the base-typed reference reads back what it just stored" {
    f = _get("store_then_read_through_base");
    for pick in PICKS {
        assert f(pick) == 777 , (
            f"class {pick}: a read at the same static index the store used must "
            f"still see 777, got {f(pick)}"
        );
    }
}


test "a store through a base-typed parameter dispatches on the argument" {
    f = _get("store_through_param");
    for pick in PICKS {
        want = 555 * 10000 + NEIGHBOURS[pick];
        assert f(pick) == want , f"class {pick}: got {f(pick)}, want {want}";
    }
}


test "a store through a base-typed list element hits only that element" {
    f = _get("store_through_list_elem");
    others = _get("list_others_untouched");
    for pick in PICKS {
        want = 777 * 10000 + NEIGHBOURS[pick];
        assert f(pick) == want , f"class {pick}: got {f(pick)}, want {want}";
        assert others(pick) == 2 , (
            f"class {pick}: the two untargeted elements must keep `code` at its "
            f"default 1, sum 2, got {others(pick)}"
        );
    }
}


test "an augmented assign reads and writes the same polymorphic slot" {
    f = _get("aug_store_direct");
    for pick in PICKS {
        want = 301 * 10000 + NEIGHBOURS[pick];
        assert f(pick) == want , (
            f"class {pick}: `code += 300` over the default 1 must be 301, "
            f"got {f(pick) // 10000}"
        );
    }
}


test "the direct store agrees with the dispatched setter it replaces" {
    setter = _get("store_via_setter");
    same = _get("direct_matches_setter");
    for pick in PICKS {
        want = 777 * 10000 + NEIGHBOURS[pick];
        assert setter(pick) == want , (
            f"class {pick}: the dispatched setter itself is wrong, got {setter(pick)}"
        );
        assert same(pick) == 1 , (
            f"class {pick}: the direct store and the dispatched setter disagree, "
            "so the shim is still doing work the plain assignment cannot"
        );
    }
}


test "every store route agrees with the sv result" {
    sv = _sv_module();
    for name in ALL_FNS {
        na_fn = _get(name);
        sv_fn = getattr(sv, name);
        for pick in PICKS {
            assert na_fn(pick) == sv_fn(pick) , (
                f"{name}({pick}): native {na_fn(pick)} != sv {sv_fn(pick)}"
            );
        }
    }
}
