"""PyAST build pass tests – migrated from test_pyast_build_pass.py.

Tests that Python source files are correctly converted to Jac AST via
the PyastBuildPass, and that specific conversions (docstrings, f-strings)
are handled properly.
"""

import ast as py_ast;
import inspect;
import os;
import sys;
import tempfile;
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.compiler.passes.main.pyast_load_pass { PyastBuildPass }
import from jaclang.jac0core.helpers { pascal_to_snake }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.jac0core.unitree { PythonModuleAst, Source }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures"
     );

def read_fixture(name: str) -> str {
    with open(os.path.join(FIXTURES, name)) as f {
        return f.read();
    }
}

test "synced to latest py ast" {
    # Python 3.14 moved the unparser to `_ast_unparse` and binds
    # `ast._Unparser` lazily on the first `unparse()` call; trigger that so the
    # introspection works on 3.13 and 3.14+ alike.
    py_ast.unparse(py_ast.parse(""));
    unparser_cls = py_ast._Unparser;
    visit_methods = (
        [
            method
            for method in dir(unparser_cls)
            if method.startswith("visit_")
        ]
        + list(unparser_cls.binop.keys())
        + list(unparser_cls.unop.keys())
        + list(unparser_cls.boolops.keys())
        + list(unparser_cls.cmpops.keys())
    );
    node_names = [
        pascal_to_snake(method.replace("visit_", "")) for method in visit_methods
    ];
    pass_func_names = [];
    for (name, value) in inspect.getmembers(PyastBuildPass) {
        if name.startswith("proc_") and inspect.isfunction(value) {
            pass_func_names.append(name.replace("proc_", ""));
        }
    }
    # Handlers for ast nodes introduced in a newer Python than the one running
    # this test are forward-compatible, not stale -- exempt them from the
    # "extra handler" direction. (e.g. interactive + PEP 750 t-strings are 3.14.)
    forward_compat = {"interactive", "template_str", "interpolation"};
    for name in pass_func_names {
        if name in forward_compat {
            continue;
        }
        assert name in node_names , f"Pass func {name} not in py_ast nodes";
    }
    for name in node_names {
        assert name in pass_func_names , f"py_ast node {name} not in pass funcs";
    }
}

test "str2doc" {
    with open(os.path.join(FIXTURES, "str2doc.py")) as f {
        file_source = f.read();
    }
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source), orig_src=Source(file_source, "str2doc.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse();
    assert '"""This is a test function."""\ndef foo()' in code;
    # \n and \t must remain as escape sequences, not real control characters
    assert '"""hello\\nworld"""' in code;
    assert '"""line1\\ttabbed"""' in code;
}

test "fstring triple quotes" {
    with open(os.path.join(FIXTURES, "py2jac_fstrings.py")) as f {
        file_source = f.read();
    }
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source),
            orig_src=Source(file_source, "py2jac_fstrings.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse();
    assert 'f"""Hello\n{name}"""' in code;
    assert "f'''Hello\n{name}'''''''" not in code;
    assert 'f"""Hello\n{name}"""""""' not in code;
}

"""Test that escape sequences are preserved when converting Python to Jac."""
test "py2jac escape sequences" {
    with open(os.path.join(FIXTURES, "py2jac_escape_sequences.py")) as f {
        file_source = f.read();
    }
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source),
            orig_src=Source(file_source, "py2jac_escape_sequences.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse();

    # No actual ESC character (0x1b) should leak into output
    assert chr(0x1b) not in code;

    # Hex/octal/standard escapes preserved
    assert "\\x1b[31m" in code and "\\x1b[0m" in code;
    assert "\\x1b[32m" in code or "\\033[32m" in code;
    assert "\\n" in code and "\\t" in code;

    # F-strings, raw strings, triple-quoted
    assert "f\"\\x1b[" in code or "f'\\x1b[" in code;
    assert 'r"\\x1b[31m' in code or "r'\\x1b[31m" in code;
    assert 'f"""Hello {name}' in code or "f'''Hello {name}" in code;

    # Backslashes, quotes, unicode, braces, hash
    assert "path\\\\to\\\\file" in code;
    assert "\\u0041" in code or "A" in code;
    assert "{{literal braces}}" in code;
    assert "# not a comment" in code;
    assert "\\x00" in code;
}

"""Implicit string concat across a backslash line-continuation must emit valid Jac (#6928)."""
test "py2jac line continuation string concat" {
    with open(os.path.join(FIXTURES, "py2jac_line_continuation.py")) as f {
        file_source = f.read();
    }
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source),
            orig_src=Source(file_source, "py2jac_line_continuation.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse(
        requires_format=False
    );

    # The source `\` line-continuation must not leak into the emitted Jac: a
    # backslash immediately followed by a newline is only valid *inside* a string
    # literal, and this fixture deliberately has none of those.
    assert "\\\n" not in code , f"Stray line-continuation leaked into:\n{code}";

    # The emitted Jac must round-trip: re-parsing it produces no errors. This is
    # the layer where the leaked `\` surfaced as "Unexpected character: '\'".
    prog = JacProgram.jac_str_formatter(
        source_str=code, file_path="py2jac_line_continuation.py", auto_lint=False
    );
    assert len(prog.errors_had) == 0 , (
        f"Re-parse errors: {[str(e) for e in prog.errors_had]}\ncode:\n{code}"
    );

    # The folded literals survive as adjacent Jac strings with escapes intact.
    formatted = prog.mod.main.gen.jac;
    assert '"abc" "def"' in formatted , f"Expected folded concat in:\n{formatted}";
    assert "line two\\n" in formatted , f"Expected preserved \\n escape in:\n{formatted}";
}

"""Test BinOp chain flattening and mixed-precedence grouping."""
test "py2jac binop operator precedence" {
    with open(os.path.join(FIXTURES, "py2jac_binop.py")) as f {
        file_source = f.read();
    }
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source), orig_src=Source(file_source, "py2jac_binop.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse();

    assert "((a + b) + c)" not in code , f"Same-op chain not flattened in: {code}";
    assert "((a - b) - c)" not in code , f"Same-op chain not flattened in: {code}";
    assert "a + b + c" in code , f"Expected flat add chain in: {code}";
    assert "a - b - c" in code , f"Expected flat sub chain in: {code}";
    assert "w - title_len - 2 // 2" not in code , f"Mixed-precedence bug in: {code}";
    assert "(w - title_len - 2) // 2" in code , f"Expected correct floor-div grouping in: {code}";
    assert "(w - title_len - 1) // 2" in code , f"Expected correct floor-div grouping in: {code}";
}

"""Complex number literals must emit complex(re, im) instead of ICE."""
test "py2jac complex literals" {
    file_source = read_fixture("py2jac_complex.py");
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source), orig_src=Source(file_source, "py2jac_complex.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse();

    assert "complex(0, 1)" in code , f"Expected bare 1j as complex(0, 1) in:\n{code}";
    assert "complex(0, 2)" in code , f"Expected 2.0j conversion in:\n{code}";
    assert "complex(1, 2)" in code , f"Expected 1+2j as complex(1, 2) in:\n{code}";
    assert "complex(-1, -2)" in code , f"Expected -1-2j as complex(-1, -2) in:\n{code}";
    assert "complex(3, 0)" in code , f"Expected 3+0j as complex(3, 0) in:\n{code}";
    assert "complex(1, 2)" in code , f"Expected 2j+1 as complex(1, 2) in:\n{code}";
    assert "complex(4, 2)" in code , f"Expected 1+2j+3 as complex(4, 2) in:\n{code}";
    assert "complex(-1, 2)" in code , f"Expected 2j-1 as complex(-1, 2) in:\n{code}";
    assert "complex(0, 2) + 1" not in code , (
        f"Reversed complex add must fold, got native-broken binop in:\n{code}"
    );
    assert "complex(1, 2) + 3" not in code , (
        f"Nested complex add must fold, got native-broken binop in:\n{code}"
    );

    prog = JacProgram.jac_str_formatter(
        source_str=code, file_path="py2jac_complex.py", auto_lint=False
    );
    assert len(prog.errors_had) == 0 , (
        f"Re-parse errors: {[str(e) for e in prog.errors_had]}\ncode:\n{code}"
    );
}

"""py2jac complex output must run in the server (Python) codespace.

Qualifying the constructor as `builtins.complex` only works where the native
backend pattern-matches the name; `builtins` is not defined in the Python
codespace, so the generated code crashed at runtime with NameError. This test
imports and executes the converted module to guard against that regression.
"""
test "py2jac complex literals run in server codespace" {
    file_source = read_fixture("py2jac_complex.py");
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source), orig_src=Source(file_source, "py2jac_complex.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse();

    tmp = tempfile.mkdtemp();
    mod_name = "py2jac_complex_rt";
    open(os.path.join(tmp, f"{mod_name}.jac"), "w").write(code);
    JacRuntime.jac_import(target=mod_name, base_path=tmp);
    mod = sys.modules[mod_name];

    assert mod.bare_j() == complex(0, 1) , f"bare_j: {mod.bare_j()}";
    assert mod.bare_float_j() == complex(0, 2) , f"bare_float_j: {mod.bare_float_j()}";
    assert mod.add_complex() == complex(1, 2) , f"add_complex: {mod.add_complex()}";
    assert mod.negative_complex() == complex(-1, -2) , (
        f"negative_complex: {mod.negative_complex()}"
    );
    assert mod.complex_real_only() == complex(3, 0) , (
        f"complex_real_only: {mod.complex_real_only()}"
    );
    assert mod.reversed_add_complex() == complex(1, 2) , (
        f"reversed_add_complex: {mod.reversed_add_complex()}"
    );
    assert mod.nested_add_complex() == complex(4, 2) , (
        f"nested_add_complex: {mod.nested_add_complex()}"
    );
    assert mod.reversed_sub_complex() == complex(-1, 2) , (
        f"reversed_sub_complex: {mod.reversed_sub_complex()}"
    );
}

"""None constants must emit NULL token, not NONETYPE."""
test "py2jac null constant" {
    source = "def f() -> None:\n    return None\n";
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(source), orig_src=Source(source, "py2jac_null.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse();
    assert "return None" in code , f"Expected None literal in:\n{code}";
    prog = JacProgram.jac_str_formatter(
        source_str=code, file_path="py2jac_null.py", auto_lint=False
    );
    assert len(prog.errors_had) == 0 , (
        f"Re-parse errors: {[str(e) for e in prog.errors_had]}\ncode:\n{code}"
    );
}

"""Complex py2jac output must lower to native without E1055 overload errors."""
test "py2jac complex literals native lowering" {
    import pytest;
    import from jaclang.jac0core.compile_options { CompileOptions }
    import from jaclang.jac0core.compiler { native_pipeline_available }
    (pipeline_ok, pipeline_reason) = native_pipeline_available();
    if not pipeline_ok {
        pytest.skip(pipeline_reason);
    }
    file_source = read_fixture("py2jac_complex.py");
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source), orig_src=Source(file_source, "py2jac_complex.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse();
    prog = JacProgram();
    mod = prog.compile(
        file_path="py2jac_complex.jac",
        use_str=code,
        options=CompileOptions(
            type_check=False,
            force_codespace='native',
            force_target_program=True,
            skip_native_engine=True
        )
    );
    assert not prog.errors_had , (
        f"Native lowering errors: {[e.pretty_print() for e in prog.errors_had]}\n"
        f"code:\n{code}"
    );
    assert mod.gen.llvm_ir is not None , (
        "Expected native IR for folded complex literals"
    );
}

"""Adjacent f-strings folded by Python must emit valid Jac f-strings."""
test "py2jac fstring adjacent multiline" {
    file_source = read_fixture("py2jac_fstring_adjacent_multiline.py");
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source),
            orig_src=Source(file_source, "py2jac_fstring_adjacent_multiline.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse(
        requires_format=False
    );

    assert 'f"A' not in code or 'f"Welcome aboard"' in code , (
        f"Mangled adjacent f-string quotes in:\n{code}"
    );
    assert 'f"B' not in code , f"Leaked f-string prefix in:\n{code}";

    prog = JacProgram.jac_str_formatter(
        source_str=code,
        file_path="py2jac_fstring_adjacent_multiline.py",
        auto_lint=False
    );
    assert len(prog.errors_had) == 0 , (
        f"Re-parse errors: {[str(e) for e in prog.errors_had]}\ncode:\n{code}"
    );

    formatted = prog.mod.main.gen.jac;
    assert "Welcome aboard" in formatted , (
        f"Expected folded f-string content in:\n{formatted}"
    );
}

"""Single-line adjacent f-strings with mixed quotes must not mangle output."""
test "py2jac fstring adjacent singleline" {
    file_source = read_fixture("py2jac_fstring_adjacent_singleline.py");
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source),
            orig_src=Source(file_source, "py2jac_fstring_adjacent_singleline.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse(
        requires_format=False
    );

    assert 'f"""A\' f"B"""' not in code , f"Mangled single-line f-string in:\n{code}";

    prog = JacProgram.jac_str_formatter(
        source_str=code,
        file_path="py2jac_fstring_adjacent_singleline.py",
        auto_lint=False
    );
    assert len(prog.errors_had) == 0 , (
        f"Re-parse errors: {[str(e) for e in prog.errors_had]}\ncode:\n{code}"
    );

    formatted = prog.mod.main.gen.jac;
    assert "AB" in formatted , f"Expected folded 'AB' in:\n{formatted}";
}

"""Immediately-invoked lambda expressions must parenthesize the call target."""
test "py2jac lambda iife" {
    file_source = read_fixture("py2jac_lambda_iife.py");
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source),
            orig_src=Source(file_source, "py2jac_lambda_iife.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse(
        requires_format=False
    );

    assert "lambda (x: Any) { (x + 1); }(10)" not in code , (
        f"Unparenthesized lambda call target in:\n{code}"
    );
    assert "(lambda (x: Any) { (x + 1); })(10)" in code , (
        f"Expected parenthesized lambda IIFE in:\n{code}"
    );

    prog = JacProgram.jac_str_formatter(
        source_str=code, file_path="py2jac_lambda_iife.py", auto_lint=False
    );
    assert len(prog.errors_had) == 0 , (
        f"Re-parse errors: {[str(e) for e in prog.errors_had]}\ncode:\n{code}"
    );
}

"""Hash inside an f-string must survive the formatter intact (not escaped to \\#).

A regression that re-adds `#` -> `\\#` escaping in unitree.fstring_escape_interior
still re-parses cleanly (it is a wrong *value*, not a syntax error), so the
zero-error round-trip used elsewhere does NOT guard it. Inspect the formatted
text directly.
"""
test "py2jac fstring hash survives formatter" {
    file_source = read_fixture("py2jac_fstring_hash.py");
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source),
            orig_src=Source(file_source, "py2jac_fstring_hash.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse();

    prog = JacProgram.jac_str_formatter(
        source_str=code, file_path="py2jac_fstring_hash.py", auto_lint=False
    );
    assert len(prog.errors_had) == 0 , (
        f"Re-parse errors: {[str(e) for e in prog.errors_had]}\ncode:\n{code}"
    );

    formatted = prog.mod.main.gen.jac;
    assert "a # b" in formatted , (
        f"Hash inside f-string must survive formatting in:\n{formatted}"
    );
    assert "\\#" not in formatted , (
        f"Hash must not be escaped to backslash-hash in:\n{formatted}"
    );
}

"""Overflowed imaginary literals (1e999j) must not crash; isfinite guard emits inf.

Without the math.isfinite guard in _numeric_literal, the imaginary part of
`1e999j` overflows to inf and `inf == int(inf)` raises OverflowError. Infinity
is spelled as an overflowing float literal (`1e309`) so it stays a compile-time
constant rather than a shadowable `float('inf')` call.
"""
test "py2jac complex inf imaginary" {
    file_source = read_fixture("py2jac_complex_inf.py");
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source),
            orig_src=Source(file_source, "py2jac_complex_inf.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse();

    assert "complex(0, 1e309)" in code , (
        f"Expected 1e999j to fold to complex(0, 1e309) in:\n{code}"
    );

    prog = JacProgram.jac_str_formatter(
        source_str=code, file_path="py2jac_complex_inf.py", auto_lint=False
    );
    assert len(prog.errors_had) == 0 , (
        f"Re-parse errors: {[str(e) for e in prog.errors_had]}\ncode:\n{code}"
    );
}

"""Overflowed plain float literals must emit 1e309, not the `inf` identifier.

The same non-finite guard covers plain floats: `1e309` is a Python float
constant (value inf), but `str(float('inf'))` is `"inf"`, which Jac lexes as a
name -- producing an undefined-name error instead of preserving the value.
"""
test "py2jac plain float inf" {
    file_source = read_fixture("py2jac_float_inf.py");
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source),
            orig_src=Source(file_source, "py2jac_float_inf.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse();

    assert "return 1e309" in code , f"Expected 1e309 literal in:\n{code}";
    assert "return -1e309" in code , f"Expected -1e309 literal in:\n{code}";
    assert "return inf" not in code , f"Bare `inf` identifier leaked in:\n{code}";

    prog = JacProgram.jac_str_formatter(
        source_str=code, file_path="py2jac_float_inf.py", auto_lint=False
    );
    assert len(prog.errors_had) == 0 , (
        f"Re-parse errors: {[str(e) for e in prog.errors_had]}\ncode:\n{code}"
    );

    tmp = tempfile.mkdtemp();
    mod_name = "py2jac_float_inf_rt";
    open(os.path.join(tmp, f"{mod_name}.jac"), "w").write(code);
    JacRuntime.jac_import(target=mod_name, base_path=tmp);
    mod = sys.modules[mod_name];
    assert mod.pos() == float("inf") , f"pos: {mod.pos()}";
    assert mod.neg() == float("-inf") , f"neg: {mod.neg()}";
}

"""A complex literal in a match value pattern must emit E5044.

`case 1 + 2j:` folds to a complex value; Jac has no complex literal syntax and
would parse `complex(1, 2)` as a class pattern, so proc_match_value emits E5044.
"""
test "py2jac match complex value emits E5044" {
    file_source = read_fixture("py2jac_match_complex.py");
    prog = JacProgram();
    PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source),
            orig_src=Source(file_source, "py2jac_match_complex.py")
        ),
        prog=prog
    );

    assert any(
        (e.code is not None and e.code.code == "E5044") for e in prog.errors_had
    ) , (
        f"Expected E5044 for complex match value; got "
        f"{[e.code.code if e.code else None for e in prog.errors_had]}"
    );
}

"""A ternary expression as a call target must be parenthesized.

Generalizes the lambda-IIFE fix: `(a if c else b)(10)` must parenthesize the
ternary, otherwise it re-parses as `a if c else b(10)` -- valid Jac that calls
`b` instead of the chosen branch. The same rule now covers every compound
expression kind (BinOp, BoolOp, Compare, Unary, Await) as a call target.
"""
test "py2jac ternary call target" {
    file_source = read_fixture("py2jac_ternary_call.py");
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source),
            orig_src=Source(file_source, "py2jac_ternary_call.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse(
        requires_format=False
    );

    assert "a if c else b(10)" not in code , (
        f"Unparenthesized ternary call target in:\n{code}"
    );
    assert "(a if c else b)(10)" in code , (
        f"Expected parenthesized ternary call target in:\n{code}"
    );

    prog = JacProgram.jac_str_formatter(
        source_str=code, file_path="py2jac_ternary_call.py", auto_lint=False
    );
    assert len(prog.errors_had) == 0 , (
        f"Re-parse errors: {[str(e) for e in prog.errors_had]}\ncode:\n{code}"
    );
}
