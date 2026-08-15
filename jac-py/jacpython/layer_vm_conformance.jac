# Phase 6 independent VM conformance (INTEGRATION_PLAN.md proof leg B).
#
# Runs CPython-produced PyCode on jacpython's ceval and compares runtime behavior
# with host CPython. One fixture per opcode in the band-2 compiler emission set,
# plus semantic categories (exceptions, calls, closures, control flow).
#
# Test harness only: host_oracle produces PyCode; product_compile must not import
# this module.

import from objects {
    PyObj,
    PyCode,
    PyInt,
    PyError,
    is_error,
}
import from host_oracle { host_compile_marshal }
import from product_compile { compile_source }
import from pyc_first { unmarshal, exec_code, to_host }

::py::
def _vm_host_exec(setup_src, body_src, mode="exec"):
    ns = {"__builtins__": __builtins__}
    if setup_src:
        exec(compile(setup_src, "<vm-host-setup>", "exec"), ns)
    if mode == "eval":
        ns["result"] = eval(compile(body_src, "<vm-host-body>", "eval"), ns)
    else:
        exec(compile(body_src, "<vm-host-body>", "exec"), ns)
    return ns


def _vm_host_equal(a, b):
    try:
        if a != a and b != b:
            return True
        return bool(a == b)
    except BaseException:
        return False


def _vm_host_raises(setup_src, body_src):
    ns = {"__builtins__": __builtins__}
    if setup_src:
        exec(compile(setup_src, "<vm-host-setup>", "exec"), ns)
    try:
        exec(compile(body_src, "<vm-host-body>", "exec"), ns)
        return None
    except BaseException as exc:
        return type(exc).__name__, str(exc)
::py::

def host_result_key(
    setup: str, body: str, mode: str, key: str
) -> any {
    ns = _vm_host_exec(setup, body, mode) as dict;
    return ns[key];
}

def host_raises(setup: str, body: str) -> tuple[str, str] | None {
    raw = _vm_host_raises(setup, body);
    if raw is None {
        return None;
    }
    pair = raw as tuple;
    return (pair[0] as str, pair[1] as str);
}

def jac_run_oracle(
    setup: str, body: str, mode: str, ns: dict[str, PyObj]
) -> PyObj {
    if setup != "" {
        setup_co = unmarshal(host_compile_marshal(setup, "<vm-setup>", "exec", 0));
        out = exec_code(setup_co, [], ns);
        if is_error(out) {
            return out;
        }
    }
    body_co = unmarshal(
        host_compile_marshal(body, "<vm-body>", mode, 0)
    );
    return exec_code(body_co, [], ns);
}

def assert_vm_value_matches_host(
    setup: str, body: str, mode: str, key: str
) {
    ns: dict[str, PyObj] = {};
    out = jac_run_oracle(setup, body, mode, ns);
    assert not is_error(out);
    host_val = host_result_key(setup, body, mode, key);
    jac_val = ns[key];
    assert _vm_host_equal(to_host(jac_val), host_val) as bool;
}

# ---------------- per-opcode fixtures (band-2 emission set) ----------------

# vm-opcode: OP_RESUME
test "vm: RESUME starts module execution" {
    assert_vm_value_matches_host("", "pass\nresult = 0\n", "exec", "result");
}

# vm-opcode: OP_RETURN_VALUE
test "vm: RETURN_VALUE binds module result" {
    assert_vm_value_matches_host("", "result = 1\n", "exec", "result");
}

# vm-opcode: OP_LOAD_CONST
test "vm: LOAD_CONST loads large literal" {
    assert_vm_value_matches_host("", "result = 1000\n", "exec", "result");
}

# vm-opcode: OP_LOAD_SMALL_INT
test "vm: LOAD_SMALL_INT loads tiny literal" {
    assert_vm_value_matches_host("", "result = 3\n", "exec", "result");
}

# vm-opcode: OP_LOAD_NAME
test "vm: LOAD_NAME reads local binding" {
    assert_vm_value_matches_host("x = 9\n", "result = x\n", "exec", "result");
}

# vm-opcode: OP_LOAD_GLOBAL
test "vm: LOAD_GLOBAL reads function global" {
    setup = "x = 9\n";
    body = "def f():\n    global x\n    return x\nresult = f()\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_BINARY_OP
test "vm: BINARY_OP adds bound names" {
    assert_vm_value_matches_host(
        "x = 2\ny = 3\n", "result = x + y\n", "exec", "result"
    );
}

# vm-opcode: OP_UNARY_NEGATIVE
test "vm: UNARY_NEGATIVE negates" {
    assert_vm_value_matches_host("x = 5\n", "result = -x\n", "exec", "result");
}

# vm-opcode: OP_UNARY_INVERT
test "vm: UNARY_INVERT inverts bits" {
    assert_vm_value_matches_host("x = 5\n", "result = ~x\n", "exec", "result");
}

# vm-opcode: OP_UNARY_NOT
test "vm: UNARY_NOT coerces truthiness" {
    assert_vm_value_matches_host("x = 0\n", "result = not x\n", "exec", "result");
}

# vm-opcode: OP_PUSH_NULL
test "vm: PUSH_NULL precedes call" {
    assert_vm_value_matches_host("", "result = len([1])\n", "exec", "result");
}

# vm-opcode: OP_CALL
test "vm: CALL invokes callable" {
    assert_vm_value_matches_host("", "result = len([1, 2, 3])\n", "exec", "result");
}

# vm-opcode: OP_COMPARE_OP
test "vm: COMPARE_OP orders values" {
    assert_vm_value_matches_host("", "result = 1 < 2\n", "exec", "result");
}

# vm-opcode: OP_POP_TOP
test "vm: POP_TOP discards expr-statement value" {
    assert_vm_value_matches_host("x = 1\n", "x\nresult = 0\n", "exec", "result");
}

# vm-opcode: OP_STORE_NAME
test "vm: STORE_NAME binds global" {
    assert_vm_value_matches_host("", "x = 7\nresult = x\n", "exec", "result");
}

# vm-opcode: OP_STORE_ATTR
test "vm: STORE_ATTR writes attribute" {
    setup = "class Box:\n    pass\nbox = Box()\n";
    body = "box.x = 11\nresult = box.x\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_STORE_SUBSCR
test "vm: STORE_SUBSCR writes element" {
    setup = "seq = [10, 20, 30]\n";
    body = "seq[1] = 99\nresult = seq[1]\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_LOAD_ATTR
test "vm: LOAD_ATTR reads attribute" {
    setup = "class Box:\n    pass\nbox = Box()\nbox.x = 4\n";
    body = "result = box.x\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_DELETE_NAME
test "vm: DELETE_NAME removes binding" {
    setup = "x = 0\n";
    body = "x = 1\ndel x\nresult = 0\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_DELETE_ATTR
test "vm: DELETE_ATTR removes attribute" {
    setup = "class Box:\n    pass\nbox = Box()\nbox.x = 1\n";
    body = "del box.x\nresult = 0\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_DELETE_SUBSCR
test "vm: DELETE_SUBSCR removes element" {
    setup = "seq = [1, 2, 3]\n";
    body = "del seq[0]\nresult = len(seq)\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_POP_JUMP_IF_FALSE
test "vm: POP_JUMP_IF_FALSE selects else branch" {
    assert_vm_value_matches_host(
        "x = 0\n",
        "if x:\n    result = 1\nelse:\n    result = 2\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_POP_JUMP_IF_TRUE
test "vm: POP_JUMP_IF_TRUE short-circuits or" {
    assert_vm_value_matches_host(
        "x = 0\ny = 2\n", "result = x or y\n", "exec", "result"
    );
}

# vm-opcode-compiler: OP_JUMP_FORWARD
test "vm: JUMP_FORWARD from native codegen matches host behavior" {
    setup = "";
    body = "a = x < y < z\nresult = 0\n";
    ns: dict[str, PyObj] = {
        "x": PyInt(t="int", val=1),
        "y": PyInt(t="int", val=2),
        "z": PyInt(t="int", val=3),
    };
    co = compile_source(body, "<jf>", "exec", 0);
    assert not is_error(co);
    assert isinstance(co, PyCode);
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    host_ns = _vm_host_exec("x = 1\ny = 2\nz = 3\n", body, "exec") as dict;
    host_val = host_ns["a"];
    assert _vm_host_equal(to_host(ns["a"]), host_val) as bool;
}

# vm-opcode: OP_COPY
test "vm: COPY preserves chained assignment RHS" {
    assert_vm_value_matches_host("", "x = y = 42\nresult = x + y\n", "exec", "result");
}

# vm-opcode: OP_SWAP
test "vm: SWAP supports chained comparison" {
    assert_vm_value_matches_host(
        "a = 1\nb = 2\nc = 3\n",
        "result = (a < b < c)\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_TO_BOOL
test "vm: TO_BOOL drives conditional branch" {
    assert_vm_value_matches_host(
        "x = 1\n",
        "if x:\n    result = 1\nelse:\n    result = 0\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_GET_ITER
test "vm: GET_ITER drives for-loop iteration" {
    assert_vm_value_matches_host(
        "",
        "total = 0\nfor i in range(3):\n    total += i\nresult = total\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_FOR_ITER
test "vm: FOR_ITER advances for-loop" {
    assert_vm_value_matches_host(
        "",
        "total = 0\nfor i in range(3):\n    total += i\nresult = total\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_END_FOR
test "vm: END_FOR completes for-loop" {
    assert_vm_value_matches_host(
        "",
        "total = 0\nfor i in range(3):\n    total += i\nresult = total\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_JUMP_BACKWARD
test "vm: JUMP_BACKWARD drives while-loop" {
    assert_vm_value_matches_host(
        "",
        "i = 0\nwhile i < 3:\n    i += 1\nresult = i\n",
        "exec",
        "result",
    );
}

# ---------------- semantic categories ----------------

test "vm: namespace mutation matches host for multi-assign" {
    setup = "";
    body = "a = 1\nb = a + 2\n";
    ns: dict[str, PyObj] = {};
    out = jac_run_oracle(setup, body, "exec", ns);
    assert not is_error(out);
    host_ns = _vm_host_exec(setup, body, "exec") as dict;
    assert _vm_host_equal(to_host(ns["a"]), host_ns["a"]) as bool;
    assert _vm_host_equal(to_host(ns["b"]), host_ns["b"]) as bool;
}

test "vm: exception type and handler result match host" {
    setup = "";
    body = (
        "try:\n"
        "    1 // 0\n"
        "except ZeroDivisionError:\n"
        "    result = 99\n"
    );
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

test "vm: raised exception message matches host" {
    setup = "";
    body = "raise ValueError('bad')\n";
    host_exc = host_raises(setup, body);
    assert host_exc is not None;
    ns: dict[str, PyObj] = {};
    out = jac_run_oracle(setup, body, "exec", ns);
    assert is_error(out);
    err = out as PyError;
    assert err.exception.type_name == "ValueError";
    assert err.exception.message == (host_exc[1] as str);
}

test "vm: function call and return match host" {
    setup = "";
    body = "def f():\n    return 42\nresult = f()\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

test "vm: closure cell reads match host" {
    setup = "";
    body = (
        "def outer():\n"
        "    x = 7\n"
        "    def inner():\n"
        "        return x\n"
        "    return inner()\n"
        "result = outer()\n"
    );
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

test "vm: branch and loop accumulation match host" {
    setup = "";
    body = (
        "total = 0\n"
        "for i in range(3):\n"
        "    total = total + i\n"
        "result = total\n"
    );
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

test "vm: generator suspension and resumption match host" {
    setup = "";
    body = (
        "def gen():\n"
        "    yield 1\n"
        "    yield 2\n"
        "g = gen()\n"
        "result = next(g) + next(g)\n"
    );
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

test "vm: while loop break matches host" {
    setup = "";
    body = (
        "i = 0\n"
        "while True:\n"
        "    i = i + 1\n"
        "    if i == 3:\n"
        "        break\n"
        "result = i\n"
    );
    assert_vm_value_matches_host(setup, body, "exec", "result");
}
