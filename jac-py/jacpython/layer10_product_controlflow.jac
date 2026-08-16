# Layer 10 product control-flow slice (PLAN.md P0.12 band 3).
#
# Source -> PyCode for if / while / for via native compile_exec, byte-exact
# against the host oracle plus VM execution smoke tests.

import from objects { PyObj, PyCode, PyInt, PyTuple, expect_int, is_error }
import from product_compile { compile_source }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code }

def oracle_exec(source: str, filename: str) -> PyObj {
    return unmarshal(host_compile_marshal(source, filename, "exec", 0));
}

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

test "layer10: if without else matches oracle" {
    assert_matches_oracle("if x: a = 1\n");
}

test "layer10: if with else matches oracle" {
    assert_matches_oracle("if x: a = 1\nelse: a = 2\n");
}

test "layer10: if then following stmt matches oracle" {
    assert_matches_oracle("if x: a = 1\nz = 2\n");
}

test "layer10: while loop matches oracle" {
    assert_matches_oracle("while x: pass\n");
}

test "layer10: while with body matches oracle" {
    assert_matches_oracle("while x: y = 1\n");
}

test "layer10: while indented body matches oracle" {
    assert_matches_oracle("while x:\n    y = 1\n");
}

test "layer10: for loop matches oracle" {
    assert_matches_oracle("for x in y: pass\n");
}

test "layer10: for with body matches oracle" {
    assert_matches_oracle("for x in y: z = 1\n");
}

test "layer10: for indented body matches oracle" {
    assert_matches_oracle("for x in y:\n    z = 1\n");
}

test "layer10: while break matches oracle" {
    assert_matches_oracle("while x: break\n");
}

test "layer10: while continue matches oracle" {
    assert_matches_oracle("while x: continue\n");
}

test "layer10: for continue matches oracle" {
    assert_matches_oracle("for x in y: continue\n");
}

test "layer10: while body break matches oracle" {
    assert_matches_oracle("while x:\n    break\n");
}

test "layer10: nested if then following stmt matches oracle" {
    assert_matches_oracle("if x:\n    if y: a = 1\nb = 2\n");
}

test "layer10: while else then following stmt matches oracle" {
    assert_matches_oracle("while x: pass\nelse: z = 1\na = 2\n");
}

test "layer10: for else then following stmt matches oracle" {
    assert_matches_oracle("for x in y: pass\nelse: z = 1\na = 2\n");
}

test "layer10: list comprehension assign matches oracle" {
    assert_matches_oracle("result = [x for x in y]\n");
}

test "layer10: list comprehension filter with nontrivial expr matches oracle" {
    assert_matches_oracle("result = [x for x in y if x + 1 > 0]\n");
}

test "layer10: dict comprehension assign matches oracle" {
    assert_matches_oracle("result = {c: c + c for c in z}\n");
}

test "layer10: dict comprehension filter matches oracle" {
    assert_matches_oracle("result = {x: x + 1 for x in y if x > 0}\n");
}

test "layer10: dict comprehension tuple target matches oracle" {
    assert_matches_oracle("result = {k: v for k, v in pairs}\n");
}

test "layer10: set comprehension assign matches oracle" {
    assert_matches_oracle("result = {x for x in y}\n");
}

test "layer10: set comprehension filter matches oracle" {
    assert_matches_oracle("result = {x for x in y if x > 0}\n");
}

# ---------------- VM execution ----------------

test "layer10: while loop executes in ceval" {
    co = product_exec("while x: x = 0\n");
    ns: dict[str, PyObj] = {"x": PyInt(t="int", val=1)};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["x"]) == 0;
}

test "layer10: for loop executes in ceval" {
    co = product_exec("total = 0\nfor x in y:\n    total = total + x\n");
    assert not is_error(co);
    assert isinstance(co, PyCode);
    ns: dict[str, PyObj] = {
        "y": PyTuple(
            t="tuple",
            items=[
                PyInt(t="int", val=1),
                PyInt(t="int", val=2),
                PyInt(t="int", val=3),

            ],
        ),
        "total": PyInt(t="int", val=0),

    };
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["total"]) == 6;
}
