"""Field access through a secondary-base-narrowed reference (issue #8163).

Archetype layouts are flattened: a derived class inlines every ancestor field
in MRO order, so a field declared on a *secondary* base sits at a different
slot in the derived struct than in that base's own struct. Reading it off a
reference whose static type is the base therefore has to pick the slot from
the runtime class, not from the base layout.

The shape here mirrors `Assignment(AstTypedVarNode, EnumBlockStmt,
CodeBlockStmt)` in the compiler's own tree, which is where this was found: the
base index for `flagged` names the `tag` pointer inside `Item`, so a wrong
offset reads that pointer's low byte and the answer flips with whether `tag`
happens to be set -- the same per-instance drift that dropped commas from
impl-based enum bodies in the sealed native parser.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_force_opts }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

"""Compile a .jac fixture and return the JIT engine plus the compiled module."""
def compile_native(fixture: str) -> tuple[ExecutionEngine, uni.Module] {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, ir);
}

"""Get a ctypes-callable function from the JIT engine."""
def get_func(eng: object, name: str, restype: type | None, *argtypes: type) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

test "secondary-base field read is independent of the neighbouring pointer" {
    (eng, _) = compile_native("secondary_base_field.jac");
    f = get_func(eng, "read_narrowed", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 0 , "flagged=False must read False when tag is None";
    assert f(1) == 0 , "flagged=False must read False when tag is set (base index names tag)";
    assert f(2) == 1 , "flagged=True must read True when tag is None";
    assert f(3) == 1 , "flagged=True must read True when tag is set";
    assert f(4) == 1 , "the base class itself must still read its own slot";
}

test "secondary-base field read in a separate statement resolves the same slot" {
    (eng, _) = compile_native("secondary_base_field.jac");
    f = get_func(eng, "read_direct", ctypes.c_int64, ctypes.c_int64);
    assert [f(k) for k in range(5)] == [0, 0, 1, 1, 1] , (
        "a narrowed read outside the isinstance condition must agree with the inline one"
    );
}

test "secondary-base field write lands on the field, not the neighbour" {
    (eng, _) = compile_native("secondary_base_field.jac");
    f = get_func(eng, "write_narrowed", ctypes.c_int64, ctypes.c_int64);
    assert [f(k) for k in range(5)] == [1, 1, 1, 1, 1] , (
        "a store through the narrowed reference must be visible through the concrete type"
    );
}

test "a secondary-base write does not clobber a neighbouring field" {
    (eng, _) = compile_native("secondary_base_field.jac");
    f = get_func(eng, "tag_intact", ctypes.c_int64, ctypes.c_int64);
    assert [f(k) for k in range(5)] == [0, 1, 0, 1, 0] , (
        "storing `flagged` through the base must leave the `tag` pointer alone"
    );
}
