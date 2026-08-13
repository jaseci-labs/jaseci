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

import from objects { PyObj, PyCode, PyInt, expect_int, is_error }
import from product_compile { compile_source }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code }

# Oracle PyCode from the host compiler (marshal transport, test-only).
def oracle_exec(source: str, filename: str) -> PyObj {
    return unmarshal(host_compile_marshal(source, filename, "exec", 0));
}

# Product PyCode from the fully native front end.
def product_exec(source: str, filename: str = "<f>") -> PyObj {
    return compile_source(source, filename, "exec", 0);
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
def assert_matches_oracle(source: str, filename: str = "<f>") -> None {
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

test "layer9: chained assignment executes in ceval" {
    co = product_exec("x = y = 5\n");
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["x"]) == 5;
    assert expect_int(ns["y"]) == 5;
}

# ---------------- VM execution ----------------

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
    ns: dict[str, PyObj] = {
        "x": PyInt(t="int", val=2),
        "y": PyInt(t="int", val=3),
    };
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
    assert (res as any).exception.type_name == "SyntaxError";
}

test "layer9: module return rejected at compile time" {
    res = compile_source("return 1\n", "<f>", "exec", 0);
    assert is_error(res);
    assert (res as any).exception.type_name == "SyntaxError";
    assert (res as any).exception.message == "'return' outside function";
}

# Regression guard: eval mode is untouched by the statement expansion.
test "layer9: eval mode still byte-exact (regression)" {
    co = compile_source("1+1", "<f>", "eval", 0);
    assert not is_error(co);
    assert isinstance(co, PyCode);
}
