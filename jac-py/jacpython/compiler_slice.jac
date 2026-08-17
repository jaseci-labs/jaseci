# P0.10 compiler slice tests (PLAN.md): hand-built AST -> codegen -> assembler.
#
# Differential against the host oracle (byte-exact PyCode) plus VM execution for
# expression fixtures: -x, a*b+c, f(x,1), x<y<z, 1+1.
#
# Test harness only: may import host_oracle for expected PyCode bytes.

import from objects { PyObj, PyCode, PyInt, PyBool, expect_int, expect_str, is_error }
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
    BoolOp,
    And,
    Attribute,
    Subscript,
    FunctionDef,
    arguments,
    arg,
    Lt,
    Load,
    Store,
    Add,
    Mult,
    USub,
}
import from parser { parse_file }
import from ast_nodes { Module }
import from compiler_codegen { compile_eval, compile_exec }
import from flowgraph { verify_cfg }
import from assembler { assemble }
import from compiler_validate { validate_module_body }
import from compiler_symtable { build_module_symtable }
import from compiler_diagnostics { compiler_diag_kind, compiler_diag_message }
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
    return assemble(verify_cfg(u));
}

def compile_parsed_exec(source: str, filename: str = "<f>") -> PyCode {
    m = parse_file(source, filename);
    assert m is not None;
    body = (m as Module).body;
    vr = validate_module_body(body);
    assert vr.diag is None;
    sr = build_module_symtable(body);
    assert sr.diag is None;
    u = compile_exec(body, filename, "<module>", 1, sr.top);
    assert u.diag is None;
    return assemble(verify_cfg(u));
}

def compile_handbuilt_exec(body: list[stmt], filename: str = "<f>") -> PyCode {
    vr = validate_module_body(body);
    assert vr.diag is None;
    sr = build_module_symtable(body);
    assert sr.diag is None;
    u = compile_exec(body, filename, "<module>", 1, sr.top);
    assert u.diag is None;
    return assemble(verify_cfg(u));
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

def ast_chained_assign -> list[stmt] {
    x = Name(
        id="x", ctx=Store(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    y = Name(
        id="y", ctx=Store(), lineno=1, col_offset=4, end_lineno=1, end_col_offset=5
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

def ast_chained_compare_assign_false -> list[stmt] {
    a = Name(
        id="a", ctx=Store(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=1,
        col_offset=4,
        end_lineno=1,
        end_col_offset=5
    );
    five = Constant(
        value=PyInt(t="int", val=5),
        kind=None,
        lineno=1,
        col_offset=8,
        end_lineno=1,
        end_col_offset=9
    );
    three = Constant(
        value=PyInt(t="int", val=3),
        kind=None,
        lineno=1,
        col_offset=12,
        end_lineno=1,
        end_col_offset=13
    );
    cmp = Compare(
        left=one,
        ops=[Lt(), Lt()],
        comparators=[five, three],
        lineno=1,
        col_offset=4,
        end_lineno=1,
        end_col_offset=13
    );
    return [
        Assign(
            targets=[a],
            value=cmp,
            type_comment=None,
            lineno=1,
            col_offset=0,
            end_lineno=1,
            end_col_offset=13
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

def assert_matches_oracle(e: expr, source: str, filename: str = "<f>") {
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
        id="x", ctx=Load(), lineno=1, col_offset=1, end_lineno=1, end_col_offset=2
    );
    return UnaryOp(
        op=USub(), operand=x, lineno=1, col_offset=0, end_lineno=1, end_col_offset=2
    );
}

def ast_add_mul -> expr {
    a = Name(
        id="a", ctx=Load(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    b = Name(
        id="b", ctx=Load(), lineno=1, col_offset=2, end_lineno=1, end_col_offset=3
    );
    c = Name(
        id="c", ctx=Load(), lineno=1, col_offset=4, end_lineno=1, end_col_offset=5
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
        id="f", ctx=Load(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    x = Name(
        id="x", ctx=Load(), lineno=1, col_offset=2, end_lineno=1, end_col_offset=3
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
        id="x", ctx=Load(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    y = Name(
        id="y", ctx=Load(), lineno=1, col_offset=2, end_lineno=1, end_col_offset=3
    );
    z = Name(
        id="z", ctx=Load(), lineno=1, col_offset=4, end_lineno=1, end_col_offset=5
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

def ast_cmp_in_call -> expr {
    f = Name(
        id="f", ctx=Load(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    return Call(
        func=f,
        args=[ast_cmp_chain()],
        keywords=[],
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=10
    );
}

def ast_cmp_and_q -> expr {
    q = Name(
        id="q", ctx=Load(), lineno=1, col_offset=13, end_lineno=1, end_col_offset=14
    );
    return BoolOp(
        op=And(),
        values=[ast_cmp_chain(), q],
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=14
    );
}

def ast_chained_side_effect_assign -> list[stmt] {
    x = Name(
        id="x", ctx=Store(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    y = Name(
        id="y", ctx=Store(), lineno=1, col_offset=4, end_lineno=1, end_col_offset=5
    );
    rhs = Call(
        func=Name(
            id="side_effect",
            ctx=Load(),
            lineno=1,
            col_offset=8,
            end_lineno=1,
            end_col_offset=19
        ),
        args=[],
        keywords=[],
        lineno=1,
        col_offset=8,
        end_lineno=1,
        end_col_offset=21
    );
    return [
        Assign(
            targets=[x, y],
            value=rhs,
            type_comment=None,
            lineno=1,
            col_offset=0,
            end_lineno=1,
            end_col_offset=21
        )
    ];
}

def ast_chained_attr_subscript_assign -> list[stmt] {
    obj_ref = Name(
        id="obj", ctx=Load(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=3
    );
    attr_tgt = Attribute(
        value=obj_ref,
        attr="x",
        ctx=Store(),
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=5
    );
    seq = Name(
        id="seq", ctx=Load(), lineno=1, col_offset=8, end_lineno=1, end_col_offset=11
    );
    index_call = Call(
        func=Name(
            id="index",
            ctx=Load(),
            lineno=1,
            col_offset=12,
            end_lineno=1,
            end_col_offset=17
        ),
        args=[],
        keywords=[],
        lineno=1,
        col_offset=12,
        end_lineno=1,
        end_col_offset=19
    );
    sub_tgt = Subscript(
        value=seq,
        slice=index_call,
        ctx=Store(),
        lineno=1,
        col_offset=8,
        end_lineno=1,
        end_col_offset=20
    );
    value_call = Call(
        func=Name(
            id="value",
            ctx=Load(),
            lineno=1,
            col_offset=23,
            end_lineno=1,
            end_col_offset=28
        ),
        args=[],
        keywords=[],
        lineno=1,
        col_offset=23,
        end_lineno=1,
        end_col_offset=30
    );
    return [
        Assign(
            targets=[attr_tgt, sub_tgt],
            value=value_call,
            type_comment=None,
            lineno=1,
            col_offset=0,
            end_lineno=1,
            end_col_offset=30
        )
    ];
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

test "compiler_slice: f(x<y<z) matches oracle PyCode" {
    actual = compile_handbuilt(ast_cmp_in_call());
    expected = oracle_eval("f(x<y<z)", "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: (x<y<z) and q matches oracle PyCode" {
    actual = compile_handbuilt(ast_cmp_and_q());
    expected = oracle_eval("(x < y < z) and q", "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
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

test "compiler_slice: x = y = side_effect() matches oracle PyCode" {
    actual = compile_handbuilt_exec(ast_chained_side_effect_assign());
    expected = oracle_exec("x = y = side_effect()\n", "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: side_effect chained assignment evaluates RHS once" {
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
    co = compile_handbuilt_exec(ast_chained_side_effect_assign());
    outcome = exec_code(co, [], ns);
    assert not is_error(outcome);
    assert expect_int(ns["x"]) == 42;
    assert expect_int(ns["y"]) == 42;
    assert expect_int(ns["count"]) == 1;
}

test "compiler_slice: obj.x = seq[index()] = value() matches oracle PyCode" {
    actual = compile_handbuilt_exec(ast_chained_attr_subscript_assign());
    expected = oracle_exec("obj.x = seq[index()] = value()\n", "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: chained compare assign false short-circuit executes" {
    co = compile_handbuilt_exec(ast_chained_compare_assign_false());
    ns: dict[str, PyObj] = {};
    outcome = exec_code(co, [], ns);
    assert not is_error(outcome);
    assert "a" in ns;
    assert isinstance(ns["a"], PyBool);
    assert not (ns["a"] as PyBool).val;
}

test "compiler_slice: module return rejected by validation" {
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=1,
        col_offset=7,
        end_lineno=1,
        end_col_offset=8
    );
    vr = validate_module_body(
        [Return(value=one, lineno=1, col_offset=0, end_lineno=1, end_col_offset=8)]
    );
    assert vr.diag is not None;
    assert compiler_diag_kind(vr.diag) == "SyntaxError";
    assert compiler_diag_message(vr.diag) == "'return' outside function";
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
            "def f(x, y):\n    return x * 10 + y\n", "<setup>", "exec", 0
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

def ast_band4_fn_call -> list[stmt] {
    xarg = arg(
        arg="x",
        annotation=None,
        type_comment=None,
        lineno=1,
        col_offset=5,
        end_lineno=1,
        end_col_offset=6
    );
    xload = Name(
        id="x", ctx=Load(), lineno=2, col_offset=11, end_lineno=2, end_col_offset=12
    );
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=2,
        col_offset=15,
        end_lineno=2,
        end_col_offset=16
    );
    fbody = [
        Return(
            value=BinOp(
                left=xload,
                op=Add(),
                right=one,
                lineno=2,
                col_offset=11,
                end_lineno=2,
                end_col_offset=16
            ),
            lineno=2,
            col_offset=4,
            end_lineno=2,
            end_col_offset=16
        ),

    ];
    fdef = FunctionDef(
        name="f",
        args=arguments(
            posonlyargs=[],
            args=[xarg],
            vararg=None,
            kwonlyargs=[],
            kw_defaults=[],
            kwarg=None,
            defaults=[]
        ),
        body=fbody,
        decorator_list=[],
        returns=None,
        type_comment=None,
        type_params=[],
        lineno=1,
        col_offset=0,
        end_lineno=2,
        end_col_offset=16
    );
    result = Name(
        id="result", ctx=Store(), lineno=4, col_offset=0, end_lineno=4, end_col_offset=6
    );
    fload = Name(
        id="f", ctx=Load(), lineno=4, col_offset=9, end_lineno=4, end_col_offset=10
    );
    two = Constant(
        value=PyInt(t="int", val=2),
        kind=None,
        lineno=4,
        col_offset=11,
        end_lineno=4,
        end_col_offset=12
    );
    return [
        fdef,
        Assign(
            targets=[result],
            value=Call(
                func=fload,
                args=[two],
                keywords=[],
                lineno=4,
                col_offset=9,
                end_lineno=4,
                end_col_offset=13
            ),
            type_comment=None,
            lineno=4,
            col_offset=0,
            end_lineno=4,
            end_col_offset=13
        ),

    ];
}

test "compiler_slice: band4 def f(x) return x+1 call matches oracle" {
    src = "def f(x):\n    return x + 1\n\nresult = f(2)\n";
    actual = compile_handbuilt_exec(ast_band4_fn_call());
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    fn = actual.consts[0] as PyCode;
    exp_fn = exp.consts[0] as PyCode;
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 1;
    assert fn.varnames == ["x"];
    assert fn.flags == 3;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band4 parsed source executes in ceval" {
    src = "def f(x):\n    return x + 1\n\nresult = f(2)\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "compiler_slice: band4 def f(x) return x+1 call executes in ceval" {
    co = compile_handbuilt_exec(ast_band4_fn_call());
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "compiler_slice: band4 recursive fact parsed matches oracle nested co_code" {
    src = (
        "def fact(n):\n"
            + "    if n <= 1:\n"
            + "        return 1\n"
            + "    return n * fact(n - 1)\n\n"
            + "result = fact(5)\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    fn = actual.consts[0] as PyCode;
    exp_fn = exp.consts[0] as PyCode;
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 1;
    assert fn.varnames == ["n"];
    assert fn.flags == 3;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band4 recursive fact parsed executes in ceval" {
    src = (
        "def fact(n):\n"
            + "    if n <= 1:\n"
            + "        return 1\n"
            + "    return n * fact(n - 1)\n\n"
            + "result = fact(5)\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 120;
}

# ---------------- Band 4: lambdas slice ----------------

test "compiler_slice: band4 lambda assign parsed matches oracle nested co_code" {
    src = "f = lambda x: x + 1\nresult = f(2)\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    fn = actual.consts[0] as PyCode;
    exp_fn = exp.consts[0] as PyCode;
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 1;
    assert fn.varnames == ["x"];
    assert fn.flags == 3;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band4 lambda assign parsed executes in ceval" {
    src = "f = lambda x: x + 1\nresult = f(2)\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "compiler_slice: band4 inline lambda call parsed executes in ceval" {
    src = "result = (lambda x: x + 1)(2)\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

# ---------------- Band 4: closures slice ----------------

test "compiler_slice: band4 closure parsed matches oracle nested inner co_code" {
    src = (
        "def outer(x):\n"
            + "    def inner():\n"
            + "        return x\n"
            + "    return inner()\n\n"
            + "result = outer(42)\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    outer = actual.consts[0] as PyCode;
    exp_outer = exp.consts[0] as PyCode;
    inner = outer.consts[0] as PyCode;
    exp_inner = exp_outer.consts[0] as PyCode;
    assert inner.co_code == exp_inner.co_code;
    assert inner.stacksize == exp_inner.stacksize;
    assert len(inner.freevars) == 1;
    assert inner.freevars[0] == "x";
    assert len(outer.cellvars) == 1;
    assert outer.cellvars[0] == "x";
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band4 closure parsed executes in ceval" {
    src = (
        "def outer(x):\n"
            + "    def inner():\n"
            + "        return x\n"
            + "    return inner()\n\n"
            + "result = outer(42)\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 42;
}

test "compiler_slice: band4 lambda closure parsed executes in ceval" {
    src = "def outer(x):\n    return lambda: x\n\nresult = outer(7)()\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 7;
}

# ---------------- Band 4: default arguments slice ----------------

test "compiler_slice: parse default args ast" {
    src0 = "def f(x):\n    return x + 1\n\nresult = f(2)\n";
    m0 = parse_file(src0, "<f>");
    assert m0 is not None;
    assert len((m0 as Module).body) == 2;
    src1 = "def f(x, y=10):\n    return x + y\n\nresult = f(2)\n";
    m1 = parse_file(src1, "<f>");
    assert m1 is not None;
    assert len((m1 as Module).body) == 2;
    fd = (m1 as Module).body[0] as FunctionDef;
    assert len(fd.args.defaults) == 1;
    assert len(fd.args.args) == 2;
}

test "compiler_slice: band4 default args parsed matches oracle nested f co_code" {
    src = "def f(x, y=10):\n    return x + y\n\nresult = f(2)\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    fn = first_nested_code(actual);
    exp_fn = first_nested_code(exp);
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 2;
    assert fn.varnames == ["x", "y"];
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band4 default args parsed executes in ceval" {
    src = "def f(x, y=10):\n    return x + y\n\nresult = f(2)\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 12;
}

test "compiler_slice: band4 default args explicit call executes in ceval" {
    src = "def f(x, y=10):\n    return x + y\n\nresult = f(2, 3)\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 5;
}

test "compiler_slice: band4 lambda default args parsed executes in ceval" {
    src = "g = lambda x, y=1: x + y\nresult = g(2)\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

# ---------------- Band 4: *args / **kwargs / kw-only slice ----------------

test "compiler_slice: parse varargs ast" {
    src = "def f(a, *args):\n    return a + len(args)\n\nresult = f(1, 2, 3)\n";
    m = parse_file(src, "<f>");
    assert m is not None;
    fd = (m as Module).body[0] as FunctionDef;
    assert fd.args.vararg is not None;
    assert (fd.args.vararg as arg).arg == "args";
    assert len(fd.args.args) == 1;
}

test "compiler_slice: band4 varargs parsed matches oracle nested f co_code" {
    src = "def f(a, *args):\n    return a + len(args)\n\nresult = f(1, 2, 3)\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    fn = first_nested_code(actual);
    exp_fn = first_nested_code(exp);
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 1;
    assert fn.kwonlyargcount == 0;
    assert fn.varnames == ["a", "args"];
    assert (fn.flags & 4) != 0;
}

test "compiler_slice: band4 varargs parsed executes in ceval" {
    src = "def f(a, *args):\n    return a + len(args)\n\nresult = f(1, 2, 3)\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "compiler_slice: band4 varkw parsed matches oracle co_code" {
    src = "def f(a, **kwargs):\n    return a + len(kwargs)\n\nresult = f(1, b=2, c=3)\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    assert actual.co_code == (expected as PyCode).co_code;
    assert actual.stacksize == (expected as PyCode).stacksize;
}

test "compiler_slice: band4 varkw parsed executes in ceval" {
    src = "def f(a, **kwargs):\n    return a + len(kwargs)\n\nresult = f(1, b=2, c=3)\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "compiler_slice: band4 kwonly default parsed matches oracle nested f co_code" {
    src = "def f(a, *, b=10):\n    return a + b\n\nresult = f(2)\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    fn = first_nested_code(actual);
    exp_fn = first_nested_code(exp);
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 1;
    assert fn.kwonlyargcount == 1;
    assert fn.varnames == ["a", "b"];
}

test "compiler_slice: band4 kwonly default parsed executes in ceval" {
    src = "def f(a, *, b=10):\n    return a + b\n\nresult = f(2)\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 12;
}

test "compiler_slice: band4 varargs kwonly default parsed executes in ceval" {
    src = "def f(a, *args, b=1):\n    return a + len(args) + b\n\nresult = f(1, 2, 3)\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 4;
}

# ---------------- Band 4: decorators slice ----------------

test "compiler_slice: band4 decorator parse attaches decorator_list" {
    src = (
        "def deco(fn):\n"
            + "    return fn\n\n"
            + "@deco\n"
            + "def f(x):\n"
            + "    return x + 1\n\n"
            + "result = f(2)\n"
    );
    m = parse_file(src, "<f>");
    assert m is not None;
    fd = (m as Module).body[1] as FunctionDef;
    assert len(fd.decorator_list) == 1;
    dec = fd.decorator_list[0] as Name;
    assert dec.id == "deco";
}

test "compiler_slice: band4 decorator parsed matches oracle co_code" {
    src = (
        "def deco(fn):\n"
            + "    return fn\n\n"
            + "@deco\n"
            + "def f(x):\n"
            + "    return x + 1\n\n"
            + "result = f(2)\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
    fn = nested_code_by_name(actual, "f");
    exp_fn = nested_code_by_name(exp, "f");
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 1;
    assert fn.varnames == ["x"];
}

test "compiler_slice: band4 decorator parsed executes in ceval" {
    src = (
        "def deco(fn):\n"
            + "    return fn\n\n"
            + "@deco\n"
            + "def f(x):\n"
            + "    return x + 1\n\n"
            + "result = f(2)\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "compiler_slice: band4 multiple decorators parsed executes in ceval" {
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
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

# ---------------- Band 5: empty class slice ----------------

test "compiler_slice: band5 empty class parsed matches oracle co_code" {
    src = "class C:\n    pass\n\nresult = C.__name__\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
    nested = nested_code_by_name(actual, "C");
    exp_nested = nested_code_by_name(exp, "C");
    assert nested.co_code == exp_nested.co_code;
    assert nested.stacksize == exp_nested.stacksize;
    assert nested.argcount == 0;
}

test "compiler_slice: band5 empty class parsed executes in ceval" {
    src = "class C:\n    pass\n\nresult = C.__name__\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_str(ns["result"]) == "C";
}

# CPython 3.14.6 co_code for `class C: def m(self): return 1` body (with __classdict__).
glob BAND5_CLASS_C_CO_CODE: list[int] = [
    97, 0, 128, 0, 93, 0, 116, 1, 82, 0, 116, 2, 94, 1, 116, 3, 22, 0, 111, 0,
    82, 1, 23, 0, 116, 4, 82, 2, 116, 5, 86, 0, 116, 6, 82, 3, 35, 0,
];

test "compiler_slice: band5 class method parsed matches oracle co_code" {
    src = (
        "class C:\n"
            + "    def m(self):\n"
            + "        return 1\n\n"
            + "result = C().m()\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
    nested = nested_code_by_name(actual, "C");
    exp_nested = nested_code_by_name(exp, "C");
    assert nested.co_code == BAND5_CLASS_C_CO_CODE;
    assert nested.stacksize == exp_nested.stacksize;
    assert nested.cellvars == ["__classdict__"];
    method = nested_code_by_name(nested, "m");
    exp_method = nested_code_by_name(exp_nested, "m");
    assert method.co_code == exp_method.co_code;
    assert method.argcount == 1;
    assert method.varnames == ["self"];
}

test "compiler_slice: band5 class method parsed executes in ceval" {
    src = (
        "class C:\n"
            + "    def m(self):\n"
            + "        return 1\n\n"
            + "result = C().m()\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 1;
}
