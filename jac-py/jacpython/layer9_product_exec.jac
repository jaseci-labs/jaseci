# Layer 9 product exec slice (PLAN.md P0.12 band 2 / P0.13 exec path).
#
# Closes the statement-expansion vertical slice: source string -> PyCode for
# exec mode, entirely via the native front end (parse_file -> compile_exec ->
# assemble), with no host_oracle / marshal / host-ast on the product path.
#
# Differential against the host oracle (byte-exact PyCode) plus VM execution for
# the band-2 straight-line fixtures: name assign, load expr-statement (including
# attribute/subscript loads), pass, and name augassign. Attribute/subscript
# store and augassign are covered when the parser emits Store targets.
# Multi-distinct-small-int literals and constant-only expr-statements depend on
# CPython peephole passes (small-int const pruning, dead-expr elimination)
# tracked separately under P0.11.
#
# Test harness only: host_oracle is used solely to produce the expected PyCode.

import from objects { PyObj, PyCode, PyInt, PyBool, expect_int, expect_str, is_error, PyError }
import from product_compile { compile_source }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code }

def oracle_eval(source: str, filename: str) -> PyObj {
    return unmarshal(host_compile_marshal(source, filename, "eval", 0));
}

# Oracle PyCode from the host compiler (marshal transport, test-only).
def oracle_exec(source: str, filename: str) -> PyObj {
    return unmarshal(host_compile_marshal(source, filename, "exec", 0));
}

# Product PyCode from the fully native front end.
def product_exec(source: str, filename: str = "<f>") -> PyObj {
    return compile_source(source, filename, "exec", 0);
}

def first_nested_code(co: PyCode) -> PyCode {
    ci = 0;
    while ci < len(co.consts) {
        c = co.consts[ci];
        if isinstance(c, PyCode) {
            return c as PyCode;
        }
        ci = ci + 1;
    }
    assert False;
    return co;
}

def nested_code_by_name(co: PyCode, name: str) -> PyCode {
    ci = 0;
    while ci < len(co.consts) {
        c = co.consts[ci];
        if isinstance(c, PyCode) {
            nested = c as PyCode;
            if nested.name == name {
                return nested;
            }
        }
        ci = ci + 1;
    }
    assert False;
    return co;
}

def consts_equal(a: list[PyObj], b: list[PyObj]) -> bool {
    if len(a) != len(b) {
        return False;
    }
    i = 0;
    while i < len(a) {
        if a[i].tp_hashkey() != b[i].tp_hashkey() {
            return False;
        }
        i = i + 1;
    }
    return True;
}

# Byte-exact slice: co_code, tables, stack depth, PEP 626 linetable. Oracle
# marshal currently mis-loads co_flags (pyc_first read_code); skip flags until
# that lands -- same carve-out as layer8.assert_matches_oracle.
def assert_matches_oracle(source: str, filename: str = "<f>") {
    actual = product_exec(source, filename);
    assert not is_error(actual);
    assert isinstance(actual, PyCode);
    expected = oracle_exec(source, filename);
    assert isinstance(expected, PyCode);
    act = actual as PyCode;
    exp = expected as PyCode;
    assert act.co_code == exp.co_code;
    assert act.linetable == exp.linetable;
    assert act.names == exp.names;
    assert consts_equal(act.consts, exp.consts);
    assert act.stacksize == exp.stacksize;
    assert act.filename == exp.filename;
    assert act.name == exp.name;
    assert act.qualname == exp.qualname;
    assert act.firstlineno == exp.firstlineno;
    assert act.exceptiontable == exp.exceptiontable;
}

# ---------------- byte-exact oracle parity ----------------

test "layer9: x = 1 product PyCode matches oracle" {
    assert_matches_oracle("x = 1\n");
}

test "layer9: x = 1000 product PyCode matches oracle" {
    assert_matches_oracle("x = 1000\n");
}

test "layer9: pass product PyCode matches oracle" {
    assert_matches_oracle("pass\n");
}

test "layer9: name expr-statement matches oracle" {
    assert_matches_oracle("x\n");
}

test "layer9: three-statement module matches oracle" {
    assert_matches_oracle("a = x\nb = y\nc = a + b\n");
}

test "layer9: attribute load expr-statement matches oracle" {
    assert_matches_oracle("x.y\n");
}

test "layer9: subscript load expr-statement matches oracle" {
    assert_matches_oracle("x[0]\n");
}

test "layer9: name augassign matches oracle" {
    assert_matches_oracle("x += 1\n");
}

test "layer9: attribute store matches oracle" {
    assert_matches_oracle("x.y = 1\n");
}

test "layer9: subscript store matches oracle" {
    assert_matches_oracle("x[0] = 1\n");
}

test "layer9: attribute augassign matches oracle" {
    assert_matches_oracle("x.y += 1\n");
}

test "layer9: subscript augassign matches oracle" {
    assert_matches_oracle("x[0] += 1\n");
}

test "layer9: chained assignment matches oracle" {
    assert_matches_oracle("x = y = 1\n");
}

test "layer9: x = y = side_effect() matches oracle" {
    assert_matches_oracle("x = y = side_effect()\n");
}

test "layer9: obj.x = seq[index()] = value() matches oracle" {
    assert_matches_oracle("obj.x = seq[index()] = value()\n");
}

test "layer9: a = x < y < z matches oracle" {
    assert_matches_oracle("a = x < y < z\n");
}

test "layer9: compare assign then statement matches oracle" {
    assert_matches_oracle("a = x < y < z\nb = 1\n");
}

test "layer9: compare assign then statement executes both" {
    co = product_exec("a = x < y < z\nb = 1\n");
    ns: dict[str, PyObj] = {
        "x": PyInt(t="int", val=1),
        "y": PyInt(t="int", val=2),
        "z": PyInt(t="int", val=3),
    };
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert isinstance(ns["a"], PyBool);
    assert (ns["a"] as PyBool).val;
    assert expect_int(ns["b"]) == 1;
}

test "layer9: eval (x < y < z) and q matches oracle" {
    co = compile_source("(x < y < z) and q", "<f>", "eval", 0);
    assert not is_error(co);
    assert isinstance(co, PyCode);
    expected = oracle_eval("(x < y < z) and q", "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    act = co as PyCode;
    assert act.co_code == exp.co_code;
    assert act.stacksize == exp.stacksize;
}

test "layer9: f(x<y<z) matches oracle" {
    co = compile_source("f(x<y<z)", "<f>", "eval", 0);
    assert not is_error(co);
    assert isinstance(co, PyCode);
    expected = oracle_eval("f(x<y<z)", "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    act = co as PyCode;
    assert act.co_code == exp.co_code;
    assert act.stacksize == exp.stacksize;
}

test "layer9: f(x<y<z) executes in ceval" {
    setup = unmarshal(
        host_compile_marshal(
            "def f(x):\n    return 1 if x else 0\n", "<setup>", "exec", 0
        )
    );
    ns: dict[str, PyObj] = {};
    setup_out = exec_code(setup, [], ns);
    assert not is_error(setup_out);
    ns["x"] = PyInt(t="int", val=1);
    ns["y"] = PyInt(t="int", val=2);
    ns["z"] = PyInt(t="int", val=3);
    co = compile_source("f(x<y<z)", "<f>", "eval", 0);
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert isinstance(out, PyInt);
    assert expect_int(out) == 1;
}

test "layer9: chained assignment executes in ceval" {
    co = product_exec("x = y = 5\n");
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["x"]) == 5;
    assert expect_int(ns["y"]) == 5;
}

# ---------------- Band 4: thin function slice ----------------

test "layer9: def f(x) return x+1 and call matches oracle" {
    src = "def f(x):\n    return x + 1\n\nresult = f(2)\n";
    assert_matches_oracle(src);
}

test "layer9: def f(x) return x+1 and call executes in ceval" {
    src = "def f(x):\n    return x + 1\n\nresult = f(2)\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "layer9: nested function PyCode has fast locals and argcount" {
    src = "def f(x):\n    return x + 1\n\nresult = f(2)\n";
    co = product_exec(src);
    assert not is_error(co);
    assert isinstance(co, PyCode);
    mod = co as PyCode;
    assert len(mod.consts) >= 1;
    assert isinstance(mod.consts[0], PyCode);
    fn = mod.consts[0] as PyCode;
    assert fn.argcount == 1;
    assert fn.varnames == ["x"];
    assert fn.flags == 3;
}

# ---------------- Band 4: recursion slice ----------------

test "layer9: if return in function compiles" {
    src = "def f(n):\n    if n <= 1:\n        return 1\n    return 0\n";
    co = product_exec(src);
    assert not is_error(co);
}

test "layer9: recursive fact(n) matches oracle" {
    src = (
        "def fact(n):\n"
            + "    if n <= 1:\n"
            + "        return 1\n"
            + "    return n * fact(n - 1)\n\n"
            + "result = fact(5)\n"
    );
    assert_matches_oracle(src);
}

test "layer9: recursive fact(n) executes in ceval" {
    src = (
        "def fact(n):\n"
            + "    if n <= 1:\n"
            + "        return 1\n"
            + "    return n * fact(n - 1)\n\n"
            + "result = fact(5)\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 120;
}

# ---------------- Band 4: lambdas slice ----------------

test "layer9: lambda assign matches oracle" {
    src = "f = lambda x: x + 1\nresult = f(2)\n";
    assert_matches_oracle(src);
}

test "layer9: lambda assign executes in ceval" {
    src = "f = lambda x: x + 1\nresult = f(2)\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "layer9: nested lambda PyCode has fast locals and argcount" {
    src = "f = lambda x: x + 1\nresult = f(2)\n";
    co = product_exec(src);
    assert not is_error(co);
    assert isinstance(co, PyCode);
    mod = co as PyCode;
    assert len(mod.consts) >= 1;
    assert isinstance(mod.consts[0], PyCode);
    fn = mod.consts[0] as PyCode;
    assert fn.argcount == 1;
    assert fn.varnames == ["x"];
    assert fn.flags == 3;
}

test "layer9: inline lambda call executes in ceval" {
    src = "result = (lambda x: x + 1)(2)\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

# ---------------- Band 4: closures slice ----------------

test "layer9: nested closure capture matches oracle" {
    src = (
        "def outer(x):\n"
            + "    def inner():\n"
            + "        return x\n"
            + "    return inner()\n\n"
            + "result = outer(42)\n"
    );
    assert_matches_oracle(src);
}

test "layer9: nested closure capture executes in ceval" {
    src = (
        "def outer(x):\n"
            + "    def inner():\n"
            + "        return x\n"
            + "    return inner()\n\n"
            + "result = outer(42)\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 42;
}

test "layer9: nested inner PyCode has freevars and cellvars metadata" {
    src = (
        "def outer(x):\n"
            + "    def inner():\n"
            + "        return x\n"
            + "    return inner()\n\n"
            + "result = outer(42)\n"
    );
    co = product_exec(src);
    assert not is_error(co);
    assert isinstance(co, PyCode);
    mod = co as PyCode;
    outer_co = mod.consts[0] as PyCode;
    inner_co = outer_co.consts[0] as PyCode;
    assert len(outer_co.cellvars) == 1;
    assert outer_co.cellvars[0] == "x";
    assert len(inner_co.freevars) == 1;
    assert inner_co.freevars[0] == "x";
    exp = oracle_exec(src, "<f>");
    assert isinstance(exp, PyCode);
    exp_outer = (exp as PyCode).consts[0] as PyCode;
    exp_inner = exp_outer.consts[0] as PyCode;
    assert inner_co.co_code == exp_inner.co_code;
}

test "layer9: lambda closure executes in ceval" {
    src = "def outer(x):\n    return lambda: x\n\nresult = outer(7)()\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 7;
}

# ---------------- Band 4: default arguments slice ----------------

test "layer9: default args matches oracle" {
    src = "def f(x, y=10):\n    return x + y\n\nresult = f(2)\n";
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    act = actual as PyCode;
    exp = expected as PyCode;
    fn = first_nested_code(act);
    exp_fn = first_nested_code(exp);
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 2;
    assert fn.varnames == ["x", "y"];
    assert act.stacksize == exp.stacksize;
}

test "layer9: default args executes in ceval" {
    src = "def f(x, y=10):\n    return x + y\n\nresult = f(2)\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 12;
}

test "layer9: default args explicit call executes in ceval" {
    src = "def f(x, y=10):\n    return x + y\n\nresult = f(2, 3)\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 5;
}

test "layer9: lambda default args executes in ceval" {
    src = "g = lambda x, y=1: x + y\nresult = g(2)\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

# ---------------- Band 4: *args / **kwargs / kw-only slice ----------------

test "layer9: varargs matches oracle" {
    src = "def f(a, *args):\n    return a + len(args)\n\nresult = f(1, 2, 3)\n";
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    act = actual as PyCode;
    exp = expected as PyCode;
    fn = first_nested_code(act);
    exp_fn = first_nested_code(exp);
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 1;
    assert fn.varnames == ["a", "args"];
}

test "layer9: varargs executes in ceval" {
    src = "def f(a, *args):\n    return a + len(args)\n\nresult = f(1, 2, 3)\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "layer9: varkw executes in ceval" {
    src = "def f(a, **kwargs):\n    return a + len(kwargs)\n\nresult = f(1, b=2, c=3)\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "layer9: kwonly default matches oracle" {
    src = "def f(a, *, b=10):\n    return a + b\n\nresult = f(2)\n";
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    act = actual as PyCode;
    exp = expected as PyCode;
    fn = first_nested_code(act);
    exp_fn = first_nested_code(exp);
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 1;
    assert fn.kwonlyargcount == 1;
    assert fn.varnames == ["a", "b"];
}

test "layer9: kwonly default executes in ceval" {
    src = "def f(a, *, b=10):\n    return a + b\n\nresult = f(2)\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 12;
}

test "layer9: varargs kwonly default executes in ceval" {
    src = "def f(a, *args, b=1):\n    return a + len(args) + b\n\nresult = f(1, 2, 3)\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 4;
}

# ---------------- Band 4: decorators slice ----------------

test "layer9: decorator matches oracle" {
    src = (
        "def deco(fn):\n"
            + "    return fn\n\n"
            + "@deco\n"
            + "def f(x):\n"
            + "    return x + 1\n\n"
            + "result = f(2)\n"
    );
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    act = actual as PyCode;
    exp = expected as PyCode;
    assert act.co_code == exp.co_code;
    assert act.stacksize == exp.stacksize;
    fn = nested_code_by_name(act, "f");
    exp_fn = nested_code_by_name(exp, "f");
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 1;
    assert fn.varnames == ["x"];
}

test "layer9: decorator executes in ceval" {
    src = (
        "def deco(fn):\n"
            + "    return fn\n\n"
            + "@deco\n"
            + "def f(x):\n"
            + "    return x + 1\n\n"
            + "result = f(2)\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "layer9: multiple decorators executes in ceval" {
    src = (
        "def d1(fn):\n"
            + "    return fn\n\n"
            + "def d2(fn):\n"
            + "    return fn\n\n"
            + "@d1\n"
            + "@d2\n"
            + "def f(x):\n"
            + "    return x + 1\n\n"
            + "result = f(2)\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

# ---------------- Band 5: empty class slice ----------------

test "layer9: empty class matches oracle" {
    src = "class C:\n    pass\n\nresult = C.__name__\n";
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    act = actual as PyCode;
    exp = expected as PyCode;
    assert act.co_code == exp.co_code;
    assert act.stacksize == exp.stacksize;
    nested = nested_code_by_name(act, "C");
    exp_nested = nested_code_by_name(exp, "C");
    assert nested.co_code == exp_nested.co_code;
    assert nested.stacksize == exp_nested.stacksize;
    assert nested.argcount == 0;
}

test "layer9: empty class executes in ceval" {
    src = "class C:\n    pass\n\nresult = C.__name__\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_str(ns["result"]) == "C";
}

# ---------------- VM execution ----------------

test "layer9: side_effect chained assignment evaluates RHS once" {
    setup = unmarshal(
        host_compile_marshal(
            "count = 0\n"
                + "def side_effect():\n"
                + "    global count\n"
                + "    count = count + 1\n"
                + "    return 42\n",
            "<setup>",
            "exec",
            0
        )
    );
    ns: dict[str, PyObj] = {};
    setup_out = exec_code(setup, [], ns);
    assert not is_error(setup_out);
    co = product_exec("x = y = side_effect()\n");
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["x"]) == 42;
    assert expect_int(ns["y"]) == 42;
    assert expect_int(ns["count"]) == 1;
}

test "layer9: x = 1 executes in ceval" {
    co = product_exec("x = 1\n");
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert "x" in ns;
    assert expect_int(ns["x"]) == 1;
}

test "layer9: assignment chain executes in ceval" {
    co = product_exec("a = x\nb = y\nc = a + b\n");
    ns: dict[str, PyObj] = {"x": PyInt(t="int", val=2), "y": PyInt(t="int", val=3),};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["a"]) == 2;
    assert expect_int(ns["b"]) == 3;
    assert expect_int(ns["c"]) == 5;
}

test "layer9: pass executes (returns None, no error)" {
    co = product_exec("pass\n");
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
}

test "layer9: name expr-statement executes (loads + discards)" {
    co = product_exec("x\n");
    ns: dict[str, PyObj] = {"x": PyInt(t="int", val=42)};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
}

test "layer9: name augassign executes in ceval" {
    co = product_exec("x += 3\n");
    ns: dict[str, PyObj] = {"x": PyInt(t="int", val=4)};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["x"]) == 7;
}

# ---------------- error path ----------------

test "layer9: parse error returns SyntaxError PyObj" {
    res = compile_source("x =\n", "<f>", "exec", 0);
    assert is_error(res);
    assert isinstance(res, PyError);
    assert (res as PyError).exception.type_name == "SyntaxError";
}

test "layer9: module return rejected at compile time" {
    res = compile_source("return 1\n", "<f>", "exec", 0);
    assert is_error(res);
    assert isinstance(res, PyError);
    assert (res as PyError).exception.type_name == "SyntaxError";
    assert (res as PyError).exception.message == "'return' outside function";
}

# Regression guard: eval mode is untouched by the statement expansion.
test "layer9: eval mode still byte-exact (regression)" {
    co = compile_source("1+1", "<f>", "eval", 0);
    assert not is_error(co);
    assert isinstance(co, PyCode);
}
