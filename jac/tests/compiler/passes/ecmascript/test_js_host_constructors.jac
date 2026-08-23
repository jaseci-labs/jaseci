"""Tests for bare JS host constructor calls in client code (issue #7651).

The lowering is type-driven: a bare client call whose callee resolves to an
instantiable class from js_globals.pyi emits a `new` expression. There is no
name list in the compiler to keep in sync -- adding a constructor means
declaring it in the stub.
"""

import os;
import tempfile;
import from tempfile { NamedTemporaryFile }
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "ecmascript", "fixtures"
     ),
     _test_tmp_dir: str = tempfile.mkdtemp(prefix="jac_test_js_host_ctor_");

def compile_fixture(fixture_name: str) -> JacProgram {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, fixture_name));
    return prog;
}

def compile_inline(code: str) -> JacProgram {
    prog = JacProgram();
    with NamedTemporaryFile(
        mode="w", suffix=".jac", delete=False, dir=_test_tmp_dir
    ) as f {
        f.write(code);
        f.flush();
        prog.compile(f.name);
    }
    return prog;
}

def compile_inline_to_js(code: str) -> str {
    prog = JacProgram();
    with NamedTemporaryFile(
        mode="w", suffix=".jac", delete=False, dir=_test_tmp_dir
    ) as f {
        f.write(code);
        f.flush();
        ir = prog.compile(f.name);
    }
    assert ir.gen.js and ir.gen.js.strip() , (
        "Production JS codegen produced no output; got no js"
    );
    return ir.gen.js;
}

def diagnostics_with_code(prog: JacProgram, code: str) -> list {
    found = [
        d
        for d in prog.errors_had
        if d.code is not None and d.code.code == code
    ];
    return found
        + [
            w
            for w in prog.warnings_had
            if w.code is not None and w.code.code == code
        ];
}

test "stubbed host constructors lower to new expressions via the type path" {
    js = compile_inline_to_js(
        'def:pub f() -> any {\n'
        '    enc = TextEncoder();\n'
        '    url = URL("https://example.com");\n'
        '    ws = WebSocket("ws://example.com");\n'
        '    promise = Promise(lambda (resolve: any, reject: any) {\n'
        '        resolve.call(None, "done");\n'
        '    });\n'
        '    return "hi";\n'
        "}\n"
    );
    assert "Reflect.construct" not in js , (
        "No host call may lower through Reflect.construct anymore; got:\n" + js
    );
    assert "new TextEncoder()" in js , (
        "TextEncoder() must lower to a new expression; got:\n" + js
    );
    assert 'new URL("https://example.com")' in js , (
        "URL(...) must lower to a new expression; got:\n" + js
    );
    assert 'new WebSocket("ws://example.com")' in js , (
        "WebSocket(...) must lower to a new expression; got:\n" + js
    );
    assert "new Promise(" in js , (
        "Promise(...) must lower to a new expression; got:\n" + js
    );
}

test "stubbed constructors are typed facts and emit no W6010 or E6010" {
    prog = compile_fixture("js_host_constructors.jac");
    assert len(diagnostics_with_code(prog, "W6010")) == 0 , (
        "Stubbed constructors must not warn W6010, got: "
        + str([str(w) for w in diagnostics_with_code(prog, "W6010")])
    );
    assert len(diagnostics_with_code(prog, "E6010")) == 0 , (
        "Stubbed constructors without kwargs must not error E6010"
    );
}

test "WebAssembly namespace stays a plain call and is not treated as a constructor" {
    prog = JacProgram();
    with NamedTemporaryFile(
        mode="w", suffix=".jac", delete=False, dir=_test_tmp_dir
    ) as f {
        f.write("def:pub f() -> any { return WebAssembly(); }\n");
        f.flush();
        ir_mod = prog.compile(f.name);
    }
    assert ir_mod is not None , "compile returned no module";
    warnings = diagnostics_with_code(prog, "W6010");
    assert len(warnings) == 0 , (
        "WebAssembly resolves in the stubs, so it must not warn W6010, got: "
        + str([str(w) for w in warnings])
    );
    js = ir_mod.gen.js or "";
    assert "new WebAssembly" not in js , (
        "The WebAssembly namespace is not constructible; got:\n" + js
    );
}

test "new(TextEncoder) does not emit W6010" {
    prog = compile_inline("def:pub f() -> any { return new(TextEncoder); }\n");
    warnings = diagnostics_with_code(prog, "W6010");
    assert len(warnings) == 0 , (
        "new(TextEncoder) must not warn W6010, got: " + str([str(w) for w in warnings])
    );
}

test "user-declared symbol shadowing a host name is not lowered as a constructor" {
    prog = JacProgram();
    with NamedTemporaryFile(
        mode="w", suffix=".jac", delete=False, dir=_test_tmp_dir
    ) as f {
        f.write(
            "def Date() -> any { return 1; }\n"
            "def:pub f() -> any { return Date(); }\n"
        );
        f.flush();
        ir_mod = prog.compile(f.name);
    }
    assert ir_mod is not None , "compile returned no module";
    warnings = diagnostics_with_code(prog, "W6010");
    assert len(warnings) == 0 , (
        "A user-defined Date() must not warn W6010, got: "
        + str([str(w) for w in warnings])
    );
    js = ir_mod.gen.js or "";
    assert "new Date" not in js , (
        "A user-defined Date() must stay a plain call; got:\n" + js
    );
}

test "callable builtins compile cleanly through the same type path" {
    prog = compile_inline(
        'def:pub f() -> any { n = Number("42"); s = String(n); b = BigInt("7"); return s; }\n'
    );
    assert len(diagnostics_with_code(prog, "W6010")) == 0 , (
        "Number/String/BigInt resolve to stub classes and must not warn W6010"
    );
    assert not prog.errors_had , (
        "Number/String/BigInt inline program must compile cleanly, got: "
        + str([str(e) for e in prog.errors_had])
    );
}

test "kwargs on an unresolved bare call report E6010" {
    # The WebSocket() call anchors client placement for the module (bare
    # `.jac` files are placed server-side unless they use a browser-seed
    # global); the predicate under test only fires in client context.
    prog = compile_inline(
        'def:pub k1() -> any {\n'
        '    w = WebSocket("ws://anchor");\n'
        '    x = Foo(a=1);\n'
        '    return x;\n'
        '}\n'
    );
    kw_errors = diagnostics_with_code(prog, "E6010");
    assert len(kw_errors) == 1 , (
        "A kwarg'd unresolved bare call must report E6010, got: "
        + str([str(e) for e in prog.errors_had])
    );
}

test "kwargs on a non-constructible host namespace report E6010 without W6010" {
    prog = compile_inline(
        'def:pub k2() -> any {\n'
        '    w = WebSocket("ws://anchor");\n'
        '    m = Math(min=1);\n'
        '    return m;\n'
        '}\n'
    );
    kw_errors = diagnostics_with_code(prog, "E6010");
    assert len(kw_errors) == 1 , (
        "A kwarg'd call on the Math namespace must report E6010, got: "
        + str([str(e) for e in prog.errors_had])
    );
    assert len(diagnostics_with_code(prog, "W6010")) == 0 , (
        "Math resolves in the stubs, so it must not warn W6010"
    );
}
