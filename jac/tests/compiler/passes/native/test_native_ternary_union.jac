"""Congruence tests for mixed-representation ternaries.

The native backend lowers `a if cond else b` to a phi over the two branch
values. When the branches lower to different representations (a list
pointer against an i64) the phi is invalid IR and the module never
compiles, which is why POLY handoffs in the parser had to be spelled as an
`any`-typed local plus an if/else assignment instead of the ternary.

The conditional-expression result now runs through the same
representation-unification rule declared multi-member unions use. These
tests assert the native result equals the sv/bytecode result of the same
fixture for every shape (shared lowering, all-pointer, genuinely mixed,
ternary as a call argument, nested ternary), and that the two shapes that
already lowered did not start paying for a jacval box.
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
     FIXTURE = "ternary_union.jac",
     FLAGS = [0, 1, 2, 3];


"""Compile the fixture natively and return (engine, module)."""
def _compile(fixture: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine for {fixture}";
    return (eng, ir);
}


"""ctypes handle for an (int) -> int function in the JIT engine."""
def _get(eng: object, name: str) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr);
}


"""Import the same fixture through the sv/bytecode pathway.

The default codespace is pinned to `server` for the import so the reference
values come from the bytecode backend no matter what the markerless
placement inference would otherwise decide.
"""
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


"""LLVM IR text of a single `define ... @name(` function body."""
def _fn_body(txt: str, name: str) -> str {
    marker = "@\"" + name + "\"(";
    start = txt.find("define ");
    while start != -1 {
        end = txt.find("\n}", start);
        if end == -1 {
            break;
        }
        block = txt[start:end + 2];
        header_end = block.find("\n");
        header = block[:header_end] if header_end != -1 else block;
        if marker in header {
            return block;
        }
        start = txt.find("define ", end);
    }
    return "";
}


test "ternary congruence: every shape matches the sv/bytecode result" {
    (eng, _) = _compile(FIXTURE);
    sv = _sv_module();
    for name in ["same_rep", "all_ptr", "mixed_rep", "call_arg", "nested"] {
        na_fn = _get(eng, name);
        sv_fn = getattr(sv, name);
        for flag in FLAGS {
            assert na_fn(flag) == sv_fn(flag) , (
                f"{name}({flag}): native {na_fn(flag)} != sv {sv_fn(flag)}"
            );
        }
    }
}


test "ternary: a genuinely mixed pointer/i64 pair round-trips its payload" {
    (eng, _) = _compile(FIXTURE);
    mixed_rep = _get(eng, "mixed_rep");
    call_arg = _get(eng, "call_arg");
    nested = _get(eng, "nested");

    # The int arm arrives as itself; the list arm as the negated length, so
    # a boxed value that lost its payload or its tag cannot pass.
    assert mixed_rep(1) == -3 , "list arm of a pointer/i64 ternary";
    assert mixed_rep(0) == 7 , "int arm of a pointer/i64 ternary";
    assert call_arg(1) == -4 , "list arm of a ternary passed as a call argument";
    assert call_arg(0) == 9 , "int arm of a ternary passed as a call argument";
    assert nested(2) == -3 , "outer arm of a nested ternary";
    assert nested(1) == -2 , "inner pointer arm of a nested ternary";
    assert nested(0) == 5 , "inner int arm of a nested ternary";
}


test "ternary: a shared lowering and an all-pointer pair never box" {
    (_, ir) = _compile(FIXTURE);
    txt = str(ir.gen.llvm_ir);

    same_rep = _fn_body(txt, "same_rep");
    all_ptr = _fn_body(txt, "all_ptr");
    assert same_rep , "same_rep was not emitted";
    assert all_ptr , "all_ptr was not emitted";

    # Two int branches keep the i64 phi they have always had.
    assert "phi  i64 " in same_rep , (
        "an int/int ternary must still phi on i64, not on a boxed value"
    );
    assert "jacval" not in same_rep , (
        "an int/int ternary started boxing to jacval -- the unification rule "
        "must be free on branches that already share a lowering"
    );

    # Two list branches keep the first member's pointer layout.
    assert "jacval" not in all_ptr , (
        "an all-pointer ternary started boxing to jacval -- an all-pointer "
        "union keeps the first member's layout"
    );
}
