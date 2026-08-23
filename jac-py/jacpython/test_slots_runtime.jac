# __slots__ runtime-enforcement pins (TODO item 51).
#
# Class creation records slots layout state on PyClass; instance attribute
# reads/writes/deletes route through PyMemberDescr data descriptors with
# host-exact error surfaces. Every rule below was probed side-by-side
# against CPython 3.14 before pinning (see jac-py/tools/SPEC_ITEM_51.md).
#
# Idiom: host_compile_marshal -> unmarshal -> exec_code runs each snippet on
# ceval only, so a test that expects a raise asserts on the returned error
# object's type_name/message rather than catching in-process.

import from objects { PyObj, PyStr, PyError, PyException, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code }

def _fresh_ns -> dict[str, PyObj] {
    return {"__name__": PyStr(t="str", val="__main__")};
}

def vm_exec_in(ns: dict[str, PyObj], src: str) {
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<slots_runtime>", "exec")), [], ns
    );
    assert not is_error(outcome);
}

# Eval/exec `src` and return the raw outcome so a test can pin the raised
# exception itself.
def vm_try(src: str) -> PyObj {
    return exec_code(
        unmarshal(host_compile_marshal(src, "<slots_runtime>", "exec")),
        [],
        _fresh_ns()
    );
}

def err_type(outcome: PyObj) -> str {
    assert isinstance(outcome, PyError);
    return ((outcome as PyError).exception as PyException).type_name;
}

def err_msg(outcome: PyObj) -> str {
    assert isinstance(outcome, PyError);
    return ((outcome as PyError).exception as PyException).message;
}

test "slots: out-of-slots write raises the two-clause AttributeError" {
    outcome = vm_try(
        "class C:\n"
        "    __slots__ = ('x',)\n"
        "c = C()\n"
        "c.z = 3\n"
    );
    assert err_type(outcome) == "AttributeError";
    assert err_msg(outcome)
        == "'C' object has no attribute 'z' and no __dict__ for setting new attributes";
}

test "slots: __dict__ is suppressed and its read names the class" {
    outcome = vm_try(
        "class C:\n"
        "    __slots__ = ('x',)\n"
        "c = C()\n"
        "assert not hasattr(c, '__dict__')\n"
        "c.__dict__\n"
    );
    assert err_type(outcome) == "AttributeError";
    assert err_msg(outcome) == "'C' object has no attribute '__dict__'";
}

test "slots: declared slot round-trips through the member descriptor" {
    ns = _fresh_ns();
    vm_exec_in(
        ns,
        "class C:\n"
        "    __slots__ = ('x',)\n"
        "c = C()\n"
        "c.x = 5\n"
        "assert c.x == 5\n"
        "md = C.__dict__['x']\n"
        "assert md.__get__(c) == 5\n"
        "md.__set__(c, 7)\n"
        "assert c.x == 7\n"
        "md.__delete__(c)\n"
        "assert not hasattr(c, 'x')\n",
    );
}

test "slots: unset-slot reads and deletes carry the host surfaces" {
    outcome = vm_try(
        "class C:\n"
        "    __slots__ = ('x',)\n"
        "C().x\n"
    );
    assert err_type(outcome) == "AttributeError";
    assert err_msg(outcome) == "'C' object has no attribute 'x'";

    # Deleting an empty slot reports the bare member name (CPython quirk).
    outcome = vm_try(
        "class U:\n"
        "    __slots__ = ('u',)\n"
        "del U().u\n"
    );
    assert err_type(outcome) == "AttributeError";
    assert err_msg(outcome) == "u";

    # Deleting an undeclared name reuses the two-clause no-dict message.
    outcome = vm_try(
        "class C:\n"
        "    __slots__ = ('x',)\n"
        "del C().zz\n"
    );
    assert err_type(outcome) == "AttributeError";
    assert err_msg(outcome)
        == "'C' object has no attribute 'zz' and no __dict__ for setting new attributes";
}

test "slots: member descriptor identity surface on the class" {
    ns = _fresh_ns();
    vm_exec_in(
        ns,
        "class C:\n"
        "    __slots__ = ('x',)\n"
        "assert str(C.__dict__['x']) == \"<member 'x' of 'C' objects>\"\n"
        "assert getattr(C, 'x').__name__ == 'x'\n"
        "assert C.__dict__['x'].__qualname__ == 'C.x'\n",
    );
}

test "slots: string form declares exactly one slot" {
    ns = _fresh_ns();
    vm_exec_in(
        ns,
        "class S:\n"
        "    __slots__ = 'q'\n"
        "s = S()\n"
        "s.q = 1\n"
        "assert s.q == 1\n"
        "assert S.__slots__ == 'q'\n",
    );
    outcome = vm_try(
        "class S:\n"
        "    __slots__ = 'q'\n"
        "S().p = 1\n"
    );
    assert err_type(outcome) == "AttributeError";
    assert err_msg(outcome)
        == "'S' object has no attribute 'p' and no __dict__ for setting new attributes";
}

test "slots: private names mangle like CPython type_new" {
    ns = _fresh_ns();
    vm_exec_in(
        ns,
        "class M:\n"
        "    __slots__ = ('__p',)\n"
        "m = M()\n"
        "m._M__p = 3\n"
        "assert m._M__p == 3\n"
        "assert '_M__p' in M.__dict__\n"
        "assert str(M.__dict__['_M__p']) == \"<member '_M__p' of 'M' objects>\"\n",
    );
}

test "slots: slot-less subclass regains a dict and inherits members" {
    ns = _fresh_ns();
    vm_exec_in(
        ns,
        "class A:\n"
        "    __slots__ = ('a',)\n"
        "class B(A):\n"
        "    pass\n"
        "b = B()\n"
        "b.zz = 1\n"
        "b.a = 2\n"
        "assert b.__dict__ == {'zz': 1}\n"
        "assert B.__slots__ == ('a',)\n",
    );
}

test "slots: explicit __dict__ entry keeps a dict but hides slot storage" {
    ns = _fresh_ns();
    vm_exec_in(
        ns,
        "class D:\n"
        "    __slots__ = ('d', '__dict__')\n"
        "d = D()\n"
        "d.d = 1\n"
        "d.other = 2\n"
        "assert d.__dict__ == {'other': 2}\n"
        "assert d.d == 1\n",
    );
}

test "slots: subclass slots merge with inherited ones" {
    ns = _fresh_ns();
    vm_exec_in(
        ns,
        "class P:\n"
        "    __slots__ = ('p',)\n"
        "class Q(P):\n"
        "    __slots__ = ('q',)\n"
        "qq = Q()\n"
        "qq.p = 1\n"
        "qq.q = 2\n"
        "assert qq.p + qq.q == 3\n"
        "assert Q.__slots__ == ('q',)\n",
    );
    outcome = vm_try(
        "class P:\n"
        "    __slots__ = ('p',)\n"
        "class Q(P):\n"
        "    __slots__ = ('q',)\n"
        "Q().r = 3\n"
    );
    assert err_type(outcome) == "AttributeError";
    assert err_msg(outcome)
        == "'Q' object has no attribute 'r' and no __dict__ for setting new attributes";
}

test "slots: builtin base with empty slots has neither attrs nor dict" {
    outcome = vm_try(
        "class I(int):\n"
        "    __slots__ = ()\n"
        "i = I(3)\n"
        "i.k = 1\n"
    );
    assert err_type(outcome) == "AttributeError";
    assert err_msg(outcome)
        == "'I' object has no attribute 'k' and no __dict__ for setting new attributes";

    outcome = vm_try(
        "class I(int):\n"
        "    __slots__ = ()\n"
        "I(3).__dict__\n"
    );
    assert err_type(outcome) == "AttributeError";
    assert err_msg(outcome) == "'I' object has no attribute '__dict__'";

    # Without a declaration the builtin subclass keeps its default dict.
    ns = _fresh_ns();
    vm_exec_in(
        ns,
        "class J(int):\n"
        "    pass\n"
        "j = J(4)\n"
        "j.k = 9\n"
        "assert j.__dict__ == {'k': 9}\n",
    );
}

test "slots: malformed declarations raise the host TypeErrors" {
    outcome = vm_try(
        "class Y:\n"
        "    __slots__ = 5\n"
    );
    assert err_type(outcome) == "TypeError";
    assert err_msg(outcome) == "'int' object is not iterable";

    outcome = vm_try(
        "class Z:\n"
        "    __slots__ = (5,)\n"
    );
    assert err_type(outcome) == "TypeError";
    assert err_msg(outcome) == "__slots__ items must be strings, not 'int'";
}

test "slots: slot vs class variable conflicts at creation time" {
    outcome = vm_try(
        "class X:\n"
        "    __slots__ = ('v',)\n"
        "    v = 1\n"
    );
    assert err_type(outcome) == "ValueError";
    assert err_msg(outcome) == "'v' in __slots__ conflicts with class variable";
}

test "slots: two nonempty-slot bases raise the layout conflict" {
    outcome = vm_try(
        "class E1:\n"
        "    __slots__ = ('e1',)\n"
        "class E2:\n"
        "    __slots__ = ('e2',)\n"
        "class F(E1, E2):\n"
        "    __slots__ = ()\n"
    );
    assert err_type(outcome) == "TypeError";
    assert err_msg(outcome) == "multiple bases have instance lay-out conflict";
}

test "slots: late Cls.__slots__ assignment stays inert" {
    outcome = vm_try(
        "class N:\n"
        "    __slots__ = ()\n"
        "N.__slots__ = ('later',)\n"
        "n = N()\n"
        "n.later = 1\n"
    );
    assert err_type(outcome) == "AttributeError";
    assert err_msg(outcome)
        == "'N' object has no attribute 'later' and no __dict__ for setting new attributes";
}

test "slots: non-slotted classes keep the permissive protocol" {
    ns = _fresh_ns();
    vm_exec_in(
        ns,
        "class Plain:\n"
        "    pass\n"
        "pl = Plain()\n"
        "pl.anything = 1\n"
        "assert hasattr(pl, '__dict__')\n"
        "assert pl.__dict__ == {'anything': 1}\n"
        "del pl.anything\n"
        "assert pl.__dict__ == {}\n",
    );
}
