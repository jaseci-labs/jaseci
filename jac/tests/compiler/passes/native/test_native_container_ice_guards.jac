"""Two emitter crashes in container lowering: one fixed, one turned into a seam.

An ICE is a bug even where the construct is unsupported. The contract is a
clean diagnostic or a seam, never a `TypeError` out of the IR builder. Both
faults below raised one, and both are reached from ordinary compiler code.

The first is a real fix. `dict.keys()` / `dict.values()` name their result list
`ptr` -- the flavor whose element type is canonically `i8*` -- but handed the
helper emitter the dict's *own* pointer type. Where the `ptr` helpers already
existed, the append argument did not match the list being appended to and the
builder raised; where they did not, the run would have minted a second,
incompatible layout under the same name, which is the worse of the two
outcomes because it does not raise. `rc_facts_pass._stamp_move_in` reaches this
through `list(_use_map.values())` over a `dict[int, uni.NameAtom]`.

The second is a refusal, not a fix, and the distinction is deliberate.
`[p for p in (items or [])]` -- `ownership_check_pass._partition_sugar_reason`
and three of its neighbours -- puts an empty list literal on the right of `or`
with no destination to take an element flavor from. It picks one, differs from
the operand on its left, and the two unify at an erased `i8*`; the
comprehension then cannot tell which list layout to read it as, and raised.

Supplying the flavor from the left operand was tried and rejected. It makes
this shape compile, but a sibling shape (an optional list produced by a
ternary and held in a local) then lowers to code that faults at run time
rather than refusing -- trading a loud compile-time crash for a silent
miscompile, which is strictly worse. The representation of an optional list
across a branch is the real defect there, and it is not this change's to fix,
so the comprehension refuses when the collection is element-erased and says
why.

Since #8206 that refusal is granular: the diagnostic is owned by the callable
holding the comprehension, so it demotes `compr_over_or` alone to a seam and
the rest of the module still lowers. `compr over or is a clean seam` pins
exactly that -- one seam, named for its owner, naming what could not be
recovered, and no module-level failure. When the representation is fixed, that
test is the one to flip.
"""

import ctypes;
import os;
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_census_begin, na_census_end }
import from jaclang.jac0core.program { JacProgram }
import from tests.support { JAC_ROOT, native_force_opts }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "native", "fixtures"
     ),
     _ENGINE: list = [];


"""JIT the fixture once; return its execution engine."""
def engine -> object {
    if _ENGINE {
        return _ENGINE[0];
    }
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "container_ice_guards.jac"),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    eng = ir.gen.native_engine;
    assert eng is not None , "no native engine for the container fixture";
    _ENGINE.append(eng);
    return eng;
}


"""Call a zero-argument fixture function returning an i64."""
def call(name: str) -> int {
    addr = engine().get_function_address(name);
    assert addr != 0 , f"'{name}' is absent from the JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64)(addr)();
}


test "dict values of archetypes reach a list intact" {
    assert call("dict_values_count") == 2 , (
        f"expected 2 values, got {call('dict_values_count')}"
    );
    assert call("dict_values_ptr") == 7 , (
        f"reading .n back off the values list gave {call('dict_values_ptr')}, "
        "expected 7 -- the list slots do not hold usable pointers"
    );
}


test "dict keys of strings reach a list intact" {
    assert call("dict_keys_str") == 5 , (
        f"total key length {call('dict_keys_str')}, expected 5"
    );
}


test "values taken from a dict keep their identity" {
    assert call("dict_values_then_dedup") == 1 , (
        f"one object stored twice gave {call('dict_values_then_dedup')} ids, "
        "expected 1 -- the values list is handing back copies or garbage"
    );
}


test "a tuple-keyed set dedups by value" {
    assert call("tuple_keyed_set") == 2 , (
        f"expected 2 distinct tuple keys, got {call('tuple_keyed_set')}"
    );
}


test "compr over or is a clean seam" {
    prog = JacProgram();
    na_census_begin();
    try {
        prog.compile(
            file_path=os.path.join(FIXTURES, "compr_or_erased.jac"),
            options=CompileOptions(
                type_check=False,
                force_codespace='native',
                force_target_program=True,
                no_ir_cache=True
            )
        );
    } finally {
        census = na_census_end();
    }
    rec = census.get(os.path.realpath(os.path.join(FIXTURES, "compr_or_erased.jac")));
    seams = [str(s) for s in ((rec.get("seams") or []) if rec is not None else [])];
    owned = [
        s
        for s in seams
        if s.startswith("compr_over_or: ")
    ];
    assert len(owned) == 1 , (
        f"expected exactly one seam for compr_over_or, got: {seams}"
    );
    assert "element-erased" in owned[0] , (
        f"the seam must name what could not be recovered: {owned[0]}"
    );
    assert not prog.errors_had , (
        "an un-lowerable comprehension is one callable's seam, not a module "
        f"failure: {[str(e) for e in prog.errors_had]}"
    );
}
