# STORE_SLICE + CHECK_EG_MATCH dispatch pins (live-bug fix lane).
#
# Both opcodes were emitted by the jacpython compiler but had no run_frame
# dispatch arm -- `l[a:b] = x` and except* matching died with SystemError.
#
# Pins:
#   - STORE_SLICE end-to-end through guest source on ceval: list resize
#     assign, empty-range shrink, iterable (generator) value drain, extended
#     step form (BUILD_SLICE + STORE_SUBSCR), slice delete, tuple immutability
#     error, and user-class __setitem__ receiving a slice key.
#   - CHECK_EG_MATCH primitives against the python3 oracle (CPython
#     _PyEval_ExceptionGroupMatch / _PyEval_CheckExceptStarTypeValid): group
#     split, all-match, nested groups, naked-exception wrap, no-match, None
#     exc, and except* target validation errors.
# Full except* (PREP_RERAISE_STAR recombination) is a separate lane and is
# intentionally not pinned here.

import from objects { PyObj, PyStr, PyList, PyException, PyExceptionType, py_none, is_error, PyError }
import from ceval { exception_group_split, eg_validate_star_target, eg_is_group, eg_members, eg_message }
import from pyc_first { unmarshal, exec_code, to_host }
import from host_oracle { host_compile_marshal }


def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<probe>", "exec")), [], ns
    );
    assert not is_error(outcome), "guest source failed";
    return ns;
}

def vm_str(ns: dict[str, PyObj], name: str) -> str {
    return str(to_host(ns[name]));
}

def vm_err(src: str) -> str {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<probe>", "exec")), [], ns
    );
    assert is_error(outcome), "guest source unexpectedly succeeded";
    return (outcome as PyError).exception.type_name;
}


# ---------------- STORE_SLICE ----------------

test "slice assign resizes list (STORE_SLICE)" {
    ns = vm_exec(
        "l = [1, 2, 3, 4, 5]\n"
        "l[1:3] = [9]\n"
    );
    assert vm_str(ns, "l") == "[1, 9, 4, 5]", vm_str(ns, "l");
}

test "slice assign with variable bounds and empty value" {
    ns = vm_exec(
        "l = [1, 2, 3, 4, 5]\n"
        "a = 1\n"
        "b = 4\n"
        "l[a:b] = []\n"
    );
    assert vm_str(ns, "l") == "[1, 5]", vm_str(ns, "l");
}

test "slice assign drains an iterable (generator) value" {
    ns = vm_exec(
        "def gen():\n"
        "    yield 42\n"
        "l = [0, 1]\n"
        "l[0:1] = gen()\n"
    );
    assert vm_str(ns, "l") == "[42, 1]", vm_str(ns, "l");
}

test "user class __setitem__ receives a slice key" {
    ns = vm_exec(
        "seen = None\n"
        "class Box:\n"
        "    def __setitem__(self, k, v):\n"
        "        global seen\n"
        "        seen = (type(k).__name__, v)\n"
        "bx = Box()\n"
        "bx[1:3] = [7, 8]\n"
    );
    assert vm_str(ns, "seen") == "('slice', [7, 8])", vm_str(ns, "seen");
}

test "extended-step slice assign still works (BUILD_SLICE + STORE_SUBSCR)" {
    ns = vm_exec(
        "l = [0, 1, 2, 3, 4]\n"
        "l[0:4:2] = [7, 8]\n"
    );
    assert vm_str(ns, "l") == "[7, 1, 8, 3, 4]", vm_str(ns, "l");
}

test "slice delete removes the range" {
    ns = vm_exec(
        "l = [1, 2, 3, 4, 5]\n"
        "del l[1:3]\n"
    );
    assert vm_str(ns, "l") == "[1, 4, 5]", vm_str(ns, "l");
}

test "tuple rejects slice assignment with TypeError" {
    got = vm_err(
        "t = (1, 2, 3)\n"
        "t[0:1] = [9]\n"
    );
    assert got == "TypeError", got;
}


# ---------------- CHECK_EG_MATCH primitives ----------------

# Leaf exception shaped exactly like a raised builtin: PyException with
# type_name + message (what py_raise_value produces for raise ValueError('v')).
def leaf(name: str, msg: str) -> PyObj {
    return PyException(t="exception", type_name=name, message=msg);
}

# Group shaped exactly like PyExceptionType.tp_call stores one:
# args == [message, members-list] (see eg_members/eg_message).
def grp(msg: str, members: list[PyObj]) -> PyObj {
    inner: list[PyObj] = [];
    inner.extend(members);
    stored: list[PyObj] = [
        PyStr(t="str", val=msg),
        PyList(t="list", items=inner),
    ];
    return PyException(t="exception", type_name="ExceptionGroup", message="", args=stored);
}

def vtype -> PyObj {
    return PyExceptionType(t="exception_type", name="ValueError");
}

def ttype -> PyObj {
    return PyExceptionType(t="exception_type", name="TypeError");
}

# Split result rendered "(rest|match)" for compact assertions. Rendered in-VM
# (not via to_host): the host bridge turns PyException into real host
# exceptions whose repr abbreviates groups ("m (3 sub-exceptions)").
def describe_exc(e: PyObj) -> str {
    if e.t == "none" {
        return "None";
    }
    x = e as PyException;
    if eg_is_group(e) {
        members = eg_members(e);
        parts: list[str] = [];
        for m in (members as PyList).items {
            parts.append(describe_exc(m));
        }
        return "EG('" + eg_message(e) + "',[" + ",".join(parts) + "])";
    }
    return x.type_name + "('" + x.message + "')";
}

def split_str(exc: PyObj, target: PyObj) -> str {
    pair = exception_group_split(exc, target);
    return "(" + describe_exc(pair[0]) + " | " + describe_exc(pair[1]) + ")";
}

test "group split partitions matching leaves" {
    # Host oracle: eg.split(ValueError) over [VE(1), TE(2), VE(3)] ->
    # match=EG([VE(1), VE(3)]), rest=EG([TE(2)]); primitive returns (rest, match).
    eg = grp("m", [leaf("ValueError", "1"), leaf("TypeError", "2"), leaf("ValueError", "3")]);
    got = split_str(eg, vtype());
    assert got == "(EG('m',[TypeError('2')]) | EG('m',[ValueError('1'),ValueError('3')]))", got;
}

test "all-match split yields None rest" {
    eg = grp("m", [leaf("ValueError", "1"), leaf("ValueError", "2")]);
    got = split_str(eg, vtype());
    assert got == "(None | EG('m',[ValueError('1'),ValueError('2')]))", got;
}

test "nested group split rebuilds subgroups" {
    # Host oracle: nested.split(ValueError) keeps the inner group shape on
    # both halves.
    nested = grp("n", [
        grp("inner", [leaf("ValueError", "1"), leaf("TypeError", "2")]),
        leaf("ValueError", "3"),
    ]);
    got = split_str(nested, vtype());
    assert got == "(EG('n',[EG('inner',[TypeError('2')])]) | "
        + "EG('n',[EG('inner',[ValueError('1')]),ValueError('3')]))", got;
}

test "full match wraps a naked exception" {
    ve = leaf("ValueError", "n");
    got = split_str(ve, vtype());
    assert got == "(None | EG('',[ValueError('n')]))", got;
}

test "no match returns (exc, None)" {
    te = leaf("TypeError", "t");
    got = split_str(te, vtype());
    assert got == "(TypeError('t') | None)", got;
}

test "no active exception splits to (None, None)" {
    pair = exception_group_split(py_none(), vtype());
    assert pair[0].t == "none" and pair[1].t == "none";
}

test "except* target validation rejects ExceptionGroup and non-exceptions" {
    bad_eg = eg_validate_star_target(PyExceptionType(t="exception_type", name="BaseExceptionGroup"));
    assert is_error(bad_eg) and (bad_eg as PyError).exception.type_name == "TypeError",
        str((bad_eg as PyError).exception.message);
    bad_plain = eg_validate_star_target(PyStr(t="str", val="not-a-class"));
    assert is_error(bad_plain) and (bad_plain as PyError).exception.type_name == "TypeError",
        str((bad_plain as PyError).exception.message);
    ok_target = eg_validate_star_target(vtype());
    assert not is_error(ok_target);
}
