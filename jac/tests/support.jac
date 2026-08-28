"""Shared path anchor for the test suite.

Tests must not assume the editable-install layout (`jaclang.__file__` sitting
next to the repo `tests/`): under the single `jac` binary, jaclang lives in the
sealed runtime cache, not beside the tests. This module resolves the repo root
from its OWN location inside `tests/`, so every test imports one stable anchor
instead of re-deriving it with a `Path(__file__).resolve().parents` walk.

Imported as `from tests.support`, which resolves identically under the single
`jac` binary and a source checkout (same mechanism as `tests.fixtures_list`).
"""

import ctypes;
import os;

import from pathlib { Path }

# `tests/`: the directory holding this file.
glob TESTS_DIR: str = str(Path(__file__).resolve().parent),
     # Repo root (the `jac/` dir): the parent of `tests/`.
     JAC_ROOT: str = str(Path(__file__).resolve().parent.parent);

# Checked-in fixtures for the graphmend compiler-pass tests.
glob GRAPHMEND_FIXTURES: str = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "fixtures", "graphmend"
     );

"""Compile a source file with the given options and program (each defaulted
when omitted) and return its generated Python source and bytecode."""
def graphmend_compile_opts(
    path: str, opts: any = None, prog: any = None
) -> tuple[str, any] {
    import ast;
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.driver.program { JacProgram }
    use_opts = CompileOptions() if opts is None else opts;
    use_prog: JacProgram = JacProgram() if prog is None else prog;
    mod = use_prog.compile(file_path=path, options=use_opts);
    pa = mod.gen.py_ast;
    mod_ast: any = pa[0] if isinstance(pa, list) else pa;
    return (ast.unparse(mod_ast), mod.gen.py_bytecode);
}

"""Compile a source file under the given graphmend setting and return its
generated Python source."""
def graphmend_compile_path(path: str, gm: bool) -> str {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    (src, _bc) = graphmend_compile_opts(path, CompileOptions(graphmend=gm));
    return src;
}

"""Compile a checked-in graphmend .jac fixture and return its generated
Python source."""
def graphmend_pysrc(name: str, gm: bool) -> str {
    return graphmend_compile_path(os.path.join(GRAPHMEND_FIXTURES, name), gm);
}

"""Compile a graphmend fixture with the transforms on and list the detection
tags recorded on the compiled module's facts."""
def graphmend_break_kinds(name: str) -> list {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.driver.program { JacProgram }
    mod = JacProgram().compile(
        file_path=os.path.join(GRAPHMEND_FIXTURES, name),
        options=CompileOptions(graphmend=True)
    );
    facts = mod.gen.graphmend_facts;
    if facts is None {
        return [];
    }
    return [k.value for k in facts.breaks.values()];
}

"""True when the code object (or any nested one) references the symbol."""
def code_mentions_symbol(code: any, symbol: str) -> bool {
    if symbol in code.co_names {
        return True;
    }
    for const in code.co_consts {
        if hasattr(const, "co_names") and code_mentions_symbol(const, symbol) {
            return True;
        }
    }
    return False;
}

"""CompileOptions that force a fixture into the native codespace.

The retired .na.jac marker used to do this from the filename; tests that
compile a fixture and expect a JIT engine now state the mandate explicitly.
Forced placement keeps lowering failures loud (no server demotion), exactly
like the old suffix.
"""
def native_force_opts -> any {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    return CompileOptions(force_codespace='native', force_target_program=True);
}


class JacStrABI(ctypes.Structure) {
    has _fields_: list[tuple[str, type]] = [
        ("root", ctypes.c_void_p),
        ("data", ctypes.c_void_p)
    ];
}

def native_str_func(eng: any, name: str, restype: type | None, *argtypes: type) -> any {
    # descriptor-ABI JIT getter shared by native tests: a c_char_p
    # spelling means a Jac str (the by-value {root, data, len}
    # descriptor); LLVM decomposes the by-value param into three scalar
    # slots, so str args pass as (root, data, len) built via
    # jac_str_new, and str returns read back as a two-pointer pair with
    # the payload NUL-bounded at data
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    real_res: any = JacStrABI if restype == ctypes.c_char_p else restype;
    str_slots: list = [];
    real_args: list = [];
    for a in argtypes {
        if a == ctypes.c_char_p {
            str_slots.append(True);
            real_args.append(ctypes.c_void_p);
            real_args.append(ctypes.c_void_p);
            real_args.append(ctypes.c_int64);
        } else {
            str_slots.append(False);
            real_args.append(a);
        }
    }
    raw = ctypes.CFUNCTYPE(real_res, *real_args)(addr);
    sn_addr = 0;
    for sn in ("jac_str_new", "__jac_str_new") {
        try {
            sn_addr = eng.get_function_address(sn);
        } except Exception {
            sn_addr = 0;
        }
        if sn_addr {
            break;
        }
    }
    mkstr = (
        ctypes.CFUNCTYPE(ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int64)(sn_addr)
            if sn_addr
            else None
    );
    def _call(*args: any) -> any {
        c_args: list = [];
        _keep: list = [];
        for (a, is_str) in zip(args, str_slots) {
            if is_str {
                b = a.encode("utf-8") if isinstance(a, str) else a;
                if mkstr is not None {
                    p = mkstr(b, len(b));
                } else {
                    _buf = ctypes.create_string_buffer(b);
                    _keep.append(_buf);
                    p = ctypes.cast(_buf, ctypes.c_void_p).value;
                }
                c_args.append(p);
                c_args.append(p);
                c_args.append(len(b));
            } else {
                c_args.append(a);
            }
        }
        r = raw(*c_args);
        if real_res is JacStrABI {
            if not r.data {
                return b"";
            }
            return ctypes.string_at(r.data);
        }
        return r;
    }
    return _call;
}


"""Fetch an object's persisted state by id from a compiled Jac program.

Runs under the system context (no user root), so access checks always pass.
Previously lived in `tests/conftest.py`, which existed only for pytest.
"""
def get_object(filename: str, id: str, main: bool = True) -> dict[(str, any)] {
    import from jaclang.cli.commands.cli_helpers { proc_file }
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    (base, mod, mach) = proc_file(filename);
    try {
        Jac.jac_import(
            target=mod, base_path=base, override_name=("__main__" if main else None)
        );
        found = Jac.get_object(id);
        if not found {
            raise ValueError(f"Object with id {id} not found.");
        }
        return found.__jac__.__getstate__();
    } finally {
        mach.close();
    }
}


# The native pass fixtures directory: the default corpus for `compile_native`.
glob NATIVE_FIXTURES: str = str(
         Path(__file__).resolve().parent
             / "compiler"
             / "backends"
             / "native"
             / "fixtures"
     );

"""Compile a .jac fixture into the native codespace and return (engine, module).

`fixture_dir` defaults to the native pass fixtures directory, which is where
all but one caller looks; pass it explicitly for a fixture that lives
elsewhere. The engine is NOT cached across calls -- a JIT engine owns the
module's mutable globals, so handing the same one to two tests would let the
first test's writes reach the second. Tests that want a fixture compiled once
should assert against it once, in a single test.
"""
def compile_native(fixture: str, fixture_dir: str = "") -> tuple {
    import from jaclang.compiler.driver.program { JacProgram }
    base = fixture_dir or NATIVE_FIXTURES;
    prog = JacProgram();
    ir = prog.compile(file_path=str(Path(base) / fixture), options=native_force_opts());
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, ir);
}

"""Get a ctypes-callable function from a JIT engine."""
def get_func(eng: any, name: str, restype: type | None, *argtypes: type) -> any {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

"""Return True if the program emitted at least one alert with the given code."""
def has_error_code(prog: any, code: str) -> bool {
    for alrt in prog.errors_had {
        if alrt.code is not None and alrt.code.code == code {
            return True;
        }
    }
    return False;
}
