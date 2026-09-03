"""Tests for the native error gate (issue #7239).

A native module that accumulates codegen-time errors (E5092 and
friends) must not publish any artifact: no llvm ir, no jit engine, no
python bytecode, and no .jir cache entry. Importing such a module must
fail loudly with the real diagnostics, and the check path must surface
the same errors `jac run` would (check/run parity).

Before the gate landed, the first compile printed the errors but cached
the poisoned artifact anyway, so every later run executed silently with
holes in the code (exit 0, zero diagnostics).
"""

import from tests.support { native_force_opts }
import os;
import tempfile;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.jir { get_module_cache_path }
import from jaclang.runtime.runtime { JacRuntime }

# `eval` of a runtime string can never be lowered on the na pathway: it
# would need an embedded interpreter inside the AOT-compiled binary. The
# E5092 fires deep inside NaIRGenPass codegen and, crucially, is NOT caught
# by the up-front capability blacklist -- that makes it the exact "drift"
# class of error the gate exists for. (An earlier version leaned on
# for-loop tuple destructuring, but #7238 later lowered that construct
# natively -- exactly the kind of drift this test guards against. A
# fundamentally dynamic construct like `eval` is drift-proof.)
glob BAD_NA_SOURCE: str = (
         "def probe() -> None {\n"
         "    eval(\"1 + 1\");\n"
         "}\n"
         "\n"
         "with entry {\n"
         "    probe();\n"
         "}\n"
     ),
     GOOD_NA_SOURCE: str = (
         "def answer() -> int {\n"
         "    return 42;\n"
         "}\n"
         "\n"
         "with entry {\n"
         "    print(answer());\n"
         "}\n"
     ),
     # A lambda parameter/return with no `: T` / `-> T` at all (issue
     # #7139). Every *named* function/method parameter without one is
     # already rejected by `ast_validation_pass` (E0052) -- but
     # `enter_param_var` explicitly exempts a `FuncSignature` whose parent
     # is a `LambdaExpr`. The type evaluator then infers the parameter's
     # type from context instead (here: from the `Callable[[str], str]`
     # slot `f` is passed into) and stamps it onto `param.type` -- or
     # refuses with E1119 if nothing can be inferred. Likewise the return
     # type is inferred onto the lambda expression's own semantic type
     # (`FunctionType.return_type`) from its body.
     #
     # Native codegen's own `_codegen_lambda` looked only at `type_tag`
     # (the syntactic annotation) for both, defaulting straight to `i64`
     # whenever it was absent -- even though the evaluator had already
     # resolved a real type (`str` here) that `_resolve_jac_type`/
     # `_lower_type` know how to lower correctly. A `str` argument's
     # pointer would silently be laid out as `i64` in the lambda's own
     # signature, with no diagnostic at all (E1119 does not fire, since
     # inference *did* succeed).
     UNTYPED_LAMBDA_INFERRED_SOURCE: str = (
         "def call_str(f: Callable[[str], str]) -> str {\n"
         "    return f(\"hello\");\n"
         "}\n"
         "\n"
         "with entry {\n"
         "    print(call_str(lambda (x) { x; }));\n"
         "}\n"
     );

"""Write a module source into a fresh temp dir; return its path."""
def write_module(name: str, source: str) -> str {
    tmpdir = tempfile.mkdtemp();
    src_path = os.path.join(tmpdir, name);
    with open(src_path, "w") as fh {
        fh.write(source);
    }
    return src_path;
}

"""Return True if the program emitted at least one alert with the given code."""
def has_error_code(prog: JacProgram, code: str) -> bool {
    for alrt in prog.errors_had {
        if alrt.code is not None and alrt.code.code == code {
            return True;
        }
    }
    return False;
}

"""Format errors for assertion messages."""
def fmt_errors(prog: JacProgram) -> str {
    return str([str(e) for e in prog.errors_had]);
}

test "na codegen errors withhold the native artifact" {
    src = write_module("gate_bad.jac", BAD_NA_SOURCE);
    prog = JacProgram();
    mod = prog.compile(file_path=src, options=native_force_opts());
    assert has_error_code(prog, "E5092") , (
        f"Expected E5092 from native codegen, got: {fmt_errors(prog)}"
    );
    assert mod.gen.llvm_ir is None , (
        "a module with native codegen errors must not publish llvm ir"
    );
    assert mod.gen.native_engine is None , (
        "a module with native codegen errors must not publish a jit engine"
    );
}

test "inferred module that cannot lower natively demotes to working bytecode" {
    # With the .na.jac marker retired, an importable module has no way to
    # *mandate* native: preference-driven inference demotes on lowering
    # failure and the server bytecode must be complete, never a poisoned
    # half-native artifact. (The loud error gate lives on the forced path --
    # see "na codegen errors withhold the native artifact".)
    src = write_module("gate_bad.jac", BAD_NA_SOURCE);
    bc = JacProgram().get_bytecode(src);
    assert bc is not None , (
        "an inferred module whose native codegen errors must demote to a "
        "complete server bytecode, not fail"
    );
}

test "import of a natively-unlowerable module demotes and succeeds" {
    # Marker-era pin was "import fails loudly": with placement inferred, the
    # import instead lands on the server fallback and must succeed.
    src = write_module("gate_bad_import.jac", BAD_NA_SOURCE);
    mod: any = JacRuntime.jac_import(
        target="gate_bad_import", base_path=os.path.dirname(src)
    );
    assert mod is not None , "demoted module must import cleanly";
}

test "check-path compile surfaces native codegen errors (check/run parity)" {
    src = write_module("gate_bad_check.jac", BAD_NA_SOURCE);
    prog = JacProgram();
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    prog.compile(
        file_path=src,
        options=CompileOptions(
            no_cgen=True,
            native_parity=True,
            force_codespace="native",
            force_target_program=True
        )
    );
    assert has_error_code(prog, "E5092") , (
        f"`jac check` path must report the same native errors `jac run` "
        f"does, got: {fmt_errors(prog)}"
    );
    seen: set = set();
    for alrt in prog.errors_had {
        key = (
            alrt.code.code if alrt.code is not None else "",
            alrt.loc.first_line,
            alrt.loc.col_start,
            alrt.msg
        );
        assert key not in seen , f"duplicate diagnostic reported: {alrt}";
        seen.add(key);
    }
}

test "clean na module still publishes artifacts and caches" {
    src = write_module("gate_good.jac", GOOD_NA_SOURCE);
    prog = JacProgram();
    mod = prog.compile(file_path=src, options=native_force_opts());
    assert not prog.errors_had , f"unexpected errors: {fmt_errors(prog)}";
    assert mod.gen.llvm_ir is not None , ("clean na module must still publish llvm ir");
    bc = JacProgram().get_bytecode(src);
    assert bc is not None , "clean na module must still produce bytecode";
    assert os.path.exists(get_module_cache_path(src)) , (
        "clean na module must still be written to the jir cache"
    );
}

test "untyped lambda param/return use the inferred type, not silent i64 (#7139)" {
    import re;
    src = write_module(
        "gate_untyped_lambda_inferred.jac", UNTYPED_LAMBDA_INFERRED_SOURCE
    );
    prog = JacProgram();
    mod = prog.compile(file_path=src, options=native_force_opts());
    assert not prog.errors_had , (
        "a lambda parameter whose type is inferred from context must "
        f"compile clean, got: {fmt_errors(prog)}"
    );
    assert mod.gen.llvm_ir is not None , (
        "a clean na module must still publish llvm ir"
    );
    txt = str(mod.gen.llvm_ir);
    lambda_lines = [
        ln
        for ln in txt.splitlines()
        if re.search(r"define.*__jac_lambda", ln)
    ];
    assert len(lambda_lines) == 1 , (
        f"expected exactly one lambda definition, got: {lambda_lines}"
    );
    assert "i64" not in lambda_lines[0] , (
        "a lambda parameter/return type inferred as `str` from its "
        "Callable[[str], str] call site must lower to its real native "
        "type, not the untyped-signature i64 default, got: "
        f"{lambda_lines[0]}"
    );
}
