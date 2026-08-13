# P0.10 compiler slice tests (PLAN.md): hand-built AST -> codegen -> assembler.
#
# Differential against the host oracle (byte-exact PyCode) plus VM execution for
# expression fixtures: -x, a*b+c, f(x,1), x<y<z, 1+1.
#
# Test harness only: may import host_oracle for expected PyCode bytes.

import from objects { PyObj, PyCode, PyInt, PyBool, expect_int, is_error }
import from ast_nodes {
    expr,
    stmt,
    Constant,
    Name,
    BinOp,
    UnaryOp,
    Call,
    Compare,
    Assign,
    Return,
    Lt,
    Load,
    Store,
    Add,
    Mult,
    USub,
}
import from compiler_codegen { compile_eval, compile_exec }
import from assembler { assemble }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code }

def oracle_eval(source: str, filename: str) -> PyObj {
    return unmarshal(host_compile_marshal(source, filename, "eval", 0));
}

def oracle_exec(source: str, filename: str) -> PyObj {
    return unmarshal(host_compile_marshal(source, filename, "exec", 0));
}

def compile_handbuilt(e: expr, filename: str = "<f>") -> PyCode {
    u = compile_eval(e, filename, "<module>", 1);
    assert u.diag is None;
    return assemble(u);
}

def compile_handbuilt_exec(body: list[stmt], filename: str = "<f>") -> PyCode {
    u = compile_exec(body, filename, "<module>", 1);
    assert u.diag is None;
    return assemble(u);
}

def ast_chained_assign -> list[stmt] {
    x = Name(
        id="x",
        ctx=Store(),
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=1
    );
    y = Name(
        id="y",
        ctx=Store(),
        lineno=1,
        col_offset=4,
        end_lineno=1,
        end_col_offset=5
    );
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=1,
        col_offset=8,
        end_lineno=1,
        end_col_offset=9
    );
    return [
        Assign(
            targets=[x, y],
            value=one,
            type_comment=None,
            lineno=1,
            col_offset=0,
            end_lineno=1,
            end_col_offset=9
        )
    ];
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

def assert_matches_oracle(e: expr, source: str, filename: str = "<f>") -> None {
    actual = compile_handbuilt(e, filename);
    expected = oracle_eval(source, filename);
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    # Byte-exact slice: co_code, tables, stack depth, PEP 626 linetable. Oracle
    # marshal currently mis-loads co_flags (pyc_first read_code); skip flags
    # until that lands.
    assert actual.co_code == exp.co_code;
    assert actual.linetable == exp.linetable;
    assert actual.names == exp.names;
    assert consts_equal(actual.consts, exp.consts);
    assert actual.stacksize == exp.stacksize;
    assert actual.filename == exp.filename;
    assert actual.name == exp.name;
    assert actual.qualname == exp.qualname;
    assert actual.firstlineno == exp.firstlineno;
    assert actual.exceptiontable == exp.exceptiontable;
}

# AST trees with CPython 3.14-exact source spans (verified via co_positions).

def ast_neg_x -> expr {
    x = Name(
        id="x",
        ctx=Load(),
        lineno=1,
        col_offset=1,
        end_lineno=1,
        end_col_offset=2
    );
    return UnaryOp(
        op=USub(),
        operand=x,
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=2
    );
}

def ast_add_mul -> expr {
    a = Name(
        id="a",
        ctx=Load(),
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=1
    );
    b = Name(
        id="b",
        ctx=Load(),
        lineno=1,
        col_offset=2,
        end_lineno=1,
        end_col_offset=3
    );
    c = Name(
        id="c",
        ctx=Load(),
        lineno=1,
        col_offset=4,
        end_lineno=1,
        end_col_offset=5
    );
    prod = BinOp(
        left=a,
        op=Mult(),
        right=b,
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=3
    );
    return BinOp(
        left=prod,
        op=Add(),
        right=c,
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=5
    );
}

def ast_call_fx1 -> expr {
    f = Name(
        id="f",
        ctx=Load(),
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=1
    );
    x = Name(
        id="x",
        ctx=Load(),
        lineno=1,
        col_offset=2,
        end_lineno=1,
        end_col_offset=3
    );
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=1,
        col_offset=4,
        end_lineno=1,
        end_col_offset=5
    );
    return Call(
        func=f,
        args=[x, one],
        keywords=[],
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=6
    );
}

def ast_cmp_chain -> expr {
    x = Name(
        id="x",
        ctx=Load(),
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=1
    );
    y = Name(
        id="y",
        ctx=Load(),
        lineno=1,
        col_offset=2,
        end_lineno=1,
        end_col_offset=3
    );
    z = Name(
        id="z",
        ctx=Load(),
        lineno=1,
        col_offset=4,
        end_lineno=1,
        end_col_offset=5
    );
    return Compare(
        left=x,
        ops=[Lt(), Lt()],
        comparators=[y, z],
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=5
    );
}

def ast_one_plus_one -> expr {
    one_a = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=1
    );
    one_b = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=1,
        col_offset=2,
        end_lineno=1,
        end_col_offset=3
    );
    return BinOp(
        left=one_a,
        op=Add(),
        right=one_b,
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=3
    );
}

# ---------------- byte-exact oracle parity ----------------

test "compiler_slice: -x matches oracle PyCode" {
    assert_matches_oracle(ast_neg_x(), "-x");
}

test "compiler_slice: a*b+c matches oracle PyCode" {
    assert_matches_oracle(ast_add_mul(), "a*b+c");
}

test "compiler_slice: f(x,1) matches oracle PyCode" {
    assert_matches_oracle(ast_call_fx1(), "f(x,1)");
}

test "compiler_slice: x<y<z matches oracle PyCode" {
    assert_matches_oracle(ast_cmp_chain(), "x<y<z");
}

test "compiler_slice: 1+1 matches oracle PyCode" {
    assert_matches_oracle(ast_one_plus_one(), "1+1");
}

test "compiler_slice: x = y = 1 matches oracle PyCode" {
    actual = compile_handbuilt_exec(ast_chained_assign());
    expected = oracle_exec("x = y = 1\n", "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: module return sets compile diagnostic" {
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=1,
        col_offset=7,
        end_lineno=1,
        end_col_offset=8
    );
    u = compile_exec(
        [Return(value=one, lineno=1, col_offset=0, end_lineno=1, end_col_offset=8)],
        "<f>",
        "<module>",
        1
    );
    assert u.diag is not None;
    assert is_error(u.diag);
    assert (u.diag as any).exception.message == "'return' outside function";
}

# ---------------- VM execution ----------------

test "compiler_slice: -x executes in ceval" {
    co = compile_handbuilt(ast_neg_x());
    ns: dict[str, PyObj] = {"x": PyInt(t="int", val=7)};
    outcome = exec_code(co, [], ns);
    assert not is_error(outcome);
    assert isinstance(outcome, PyInt);
    assert expect_int(outcome) == -7;
}

test "compiler_slice: a*b+c executes in ceval" {
    co = compile_handbuilt(ast_add_mul());
    ns: dict[str, PyObj] = {
        "a": PyInt(t="int", val=2),
        "b": PyInt(t="int", val=3),
        "c": PyInt(t="int", val=4),
    };
    outcome = exec_code(co, [], ns);
    assert not is_error(outcome);
    assert isinstance(outcome, PyInt);
    assert expect_int(outcome) == 10;
}

test "compiler_slice: f(x,1) executes in ceval" {
    setup = unmarshal(
        host_compile_marshal(
            "def f(x, y):\n    return x * 10 + y\n",
            "<setup>",
            "exec",
            0
        )
    );
    ns: dict[str, PyObj] = {};
    setup_out = exec_code(setup, [], ns);
    assert not is_error(setup_out);
    ns["x"] = PyInt(t="int", val=3);
    co = compile_handbuilt(ast_call_fx1());
    outcome = exec_code(co, [], ns);
    assert not is_error(outcome);
    assert isinstance(outcome, PyInt);
    assert expect_int(outcome) == 31;
}

test "compiler_slice: x<y<z executes in ceval (true chain)" {
    co = compile_handbuilt(ast_cmp_chain());
    ns: dict[str, PyObj] = {
        "x": PyInt(t="int", val=1),
        "y": PyInt(t="int", val=2),
        "z": PyInt(t="int", val=3),
    };
    outcome = exec_code(co, [], ns);
    assert not is_error(outcome);
    assert isinstance(outcome, PyBool);
    assert (outcome as PyBool).val;
}

test "compiler_slice: x<y<z executes in ceval (short-circuit false)" {
    co = compile_handbuilt(ast_cmp_chain());
    ns: dict[str, PyObj] = {
        "x": PyInt(t="int", val=1),
        "y": PyInt(t="int", val=5),
        "z": PyInt(t="int", val=3),
    };
    outcome = exec_code(co, [], ns);
    assert not is_error(outcome);
    assert isinstance(outcome, PyBool);
    assert not (outcome as PyBool).val;
}

test "compiler_slice: 1+1 executes in ceval" {
    co = compile_handbuilt(ast_one_plus_one());
    outcome = exec_code(co, [], {});
    assert not is_error(outcome);
    assert isinstance(outcome, PyInt);
    assert expect_int(outcome) == 2;
}
