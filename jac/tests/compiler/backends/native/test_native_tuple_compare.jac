"""Tuple comparison picks its per-element instruction from the checker type.

Element-wise `==` and the lexicographic `<`/`>` chain used to choose between
`icmp`, `fcmp` and the runtime string compare by reading the *lowered* element
off the LLVM struct. Two element kinds share one lowered shape, so that read
could not tell them apart: a `bool` lowers to an `i1`, which is an `IntType`
exactly like an `int`, and it went down the signed-compare arm. In a one-bit
signed integer `True` is -1, so `(True, 1) > (False, 9)` answered False and
`(False, 9) < (True, 1)` answered False with it -- both the opposite of the
Python result, silently and with no diagnostic.

Reading the element's kind off the tuple's own `TypeBase` separates them: a
bool compares unsigned, an int and an enum signed, a float through `fcmp`, and
everything else through the string compare. Every case is checked against the
sv/bytecode result of the same fixture rather than against a hand-written
expectation, so the two lanes have to agree about the answer rather than about
the instruction.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_force_opts }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.compiler.frontend.codeinfo {
    get_effective_default_codespace_override,
    set_effective_default_codespace
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "tuple_compare.jac",
     CASES = ["bool_gt", "bool_lt", "bool_eq", "int_lt", "str_lt", "float_gt"],
     _MEMO: list = [];

"""The fixture compiled once through the native lane."""
def _engine -> any {
    if _MEMO {
        return _MEMO[0];
    }
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, FIXTURE)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {FIXTURE}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {FIXTURE}";
    _MEMO.append(eng);
    return eng;
}

"""ctypes handle for an (int) -> int function in the JIT engine."""
def _get(name: str) -> any {
    addr = _engine().get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr);
}

"""The same fixture through the sv/bytecode pathway."""
def _sv_module -> any {
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

test "tuple comparison agrees with the sv lane for every element kind" {
    mod = _sv_module();
    for fn_name in CASES {
        sv = getattr(mod, fn_name);
        assert _get(fn_name)(0) == sv(0) , (
            f"native '{fn_name}' disagrees with the sv lane; a bool element "
            "compared as a signed i1 is the way this goes wrong silently"
        );
    }
}
