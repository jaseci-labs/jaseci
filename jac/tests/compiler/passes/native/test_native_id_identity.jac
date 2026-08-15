"""`id()` names the identity a native value already has.

Two identity schemes in the compiler are built on it. `access_check_pass._is_subclass_of`
walks base classes with `visited: set[int]` keyed on `id(cur)`, and the
`SymId` scheme in `ownership_check_pass` / `rc_facts_pass` keys liveness and
move facts the same way. Both need one guarantee: distinct objects never
collide and the same object always answers the same.

Natively a value is either behind a pointer or is the word itself, and the two
get different answers because they are different things:

  - Pointer-backed (archetype, str, list, set, dict): the identity is the
    address. That is the same guarantee CPython gives, and it is what the
    visited-set patterns above are actually asking for.
  - Unboxed scalar (int, bool, float): there is no object to take the address
    of, so the identity is the value's own bits. Two equal scalars are one
    value natively, so they answer alike -- which is what an `id()`-keyed dedup
    wants of them, and what CPython's small-int interning does anyway.

Floats previously had no case at all and refused the whole compile; they now
take the bit pattern, which is the scalar rule applied to a wider word.

The scalar tests assert both halves deliberately -- equal scalars share an id
AND unequal ones do not -- so the rule is pinned rather than half-observed.
"""

import ctypes;
import os;
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
        file_path=os.path.join(FIXTURES, "id_identity.jac"), options=native_force_opts()
    );
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    eng = ir.gen.native_engine;
    assert eng is not None , "no native engine for the id fixture";
    _ENGINE.append(eng);
    return eng;
}


"""Call a zero-argument fixture function returning an i64."""
def call(name: str) -> int {
    addr = engine().get_function_address(name);
    assert addr != 0 , f"'{name}' is absent from the JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64)(addr)();
}


test "aliases of one archetype share an id" {
    assert call("id_alias") == 1 , "two names for one object gave different ids";
}


test "distinct archetypes do not share an id" {
    assert call("id_distinct") == 0 , (
        "two separately constructed objects collided -- an identity set keyed "
        "on id() would silently treat them as one"
    );
}


test "an archetype's id is stable across calls" {
    assert call("id_stable") == 1 , "id() gave a different answer the second time";
}


test "id keys an identity set" {
    assert call("id_dedup_set") == 2 , (
        f"expected 2 distinct ids, got {call('id_dedup_set')}"
    );
}


test "id drives a visited-set walk to termination" {
    assert call("id_bfs_visited") == 2 , (
        f"the visited-set walk took {call('id_bfs_visited')} steps, expected 2 "
        "-- this is the shape access_check_pass._is_subclass_of uses"
    );
}


test "aliased strings and lists share an id" {
    assert call("id_str_alias") == 1 , "aliased strings gave different ids";
    assert call("id_list_alias") == 1 , "aliased lists gave different ids";
}


test "equal ints share an id and unequal ints do not" {
    assert call("id_int_value") == 1 , "equal ints gave different ids";
    assert call("id_int_differs") == 0 , "unequal ints collided";
}


test "equal floats share an id and unequal floats do not" {
    assert call("id_float_stable") == 1 , "equal floats gave different ids";
    assert call("id_float_differs") == 0 , "unequal floats collided";
}
