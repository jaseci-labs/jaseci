# CALL_INTRINSIC_1(INTRINSIC_TYPEVAR) pins (lane J).
#
# Each fixture executes Python source on jacpython's ceval via host-compiled
# marshal and asserts CPython-oracle outcomes for PEP 695 type parameters:
#
# - The intrinsic builds a TypeVar stand-in from just the parameter name:
#   __name__ mirrors the parameter, __bound__ is None, __constraints__ is the
#   empty tuple (bounds/constraints wrap via CALL_INTRINSIC_2 arms).
# - Implicit PEP 695 parameters carry module 'typing' with inferred variance,
#   so repr()/str() print the bare name ('T', not '~T').
# - Unknown attributes raise CPython's exact AttributeError text.
#
# Fixtures carry parameters through generic aliases (`type A[V] = ...`) --
# the only PEP 695 construct whose full pipeline is live here. Function- and
# class-scoped parameters build the SAME TypeVar objects through this arm but
# additionally need CALL_INTRINSIC_2 (SET_FUNCTION_TYPE_PARAMS /
# TYPEVAR_WITH_BOUND / _WITH_CONSTRAINTS) and CALL_INTRINSIC_1 arg 10
# (SUBSCRIPT_GENERIC), which are separate follow-ups.

import from host_oracle { host_compile_marshal }
import from pyc_first { exec_code, unmarshal, to_host }
import from objects { PyObj, PyStr, PyError, is_error }

# Exec `src` on ceval with fresh module globals; fails the test on raise.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<typevar>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_str(ns: dict[str, PyObj], name: str) -> str {
    return str(to_host(ns[name]));
}

def vm_bool(ns: dict[str, PyObj], name: str) -> bool {
    return to_host(ns[name]) as bool;
}

# Exec `src` and return the raised exception message ("" if none).
def vm_raise_message(src: str) -> str {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<typevar_raise>", "exec")), [], ns
    );
    if is_error(outcome) {
        return ((outcome as PyError).exception.message);
    }
    return "";
}

test "alias parameter builds a named unbounded TypeVar" {
    ns = vm_exec(
        "type A[T] = list[T]\n"
        "tv = A.__type_params__[0]\n"
        "nm = tv.__name__\n"
        "r = repr(tv)\n"
        "s = str(tv)\n"
        "bnd = tv.__bound__ is None\n"
        "cons = tv.__constraints__ == ()\n"
        "mod = tv.__module__\n"
        "iv = tv.__infer_variance__\n"
    );
    assert vm_str(ns, "nm") == "T";
    assert vm_str(ns, "r") == "T";
    assert vm_str(ns, "s") == "T";
    assert vm_bool(ns, "bnd");
    assert vm_bool(ns, "cons");
    assert vm_str(ns, "mod") == "typing";
    assert vm_bool(ns, "iv");
}

test "multiple alias parameters build distinct named TypeVars" {
    ns = vm_exec(
        "type M[P, Q] = dict[P, Q]\n"
        "names = [p.__name__ for p in M.__type_params__]\n"
        "count = len(M.__type_params__)\n"
        "reprs = [repr(p) for p in M.__type_params__]\n"
    );
    assert vm_str(ns, "names") == "['P', 'Q']";
    assert to_host(ns["count"]) == 2;
    assert vm_str(ns, "reprs") == "['P', 'Q']";
}

test "unparameterized alias has empty type params" {
    ns = vm_exec(
        "type B = int\n"
        "count = len(B.__type_params__)\n"
    );
    assert to_host(ns["count"]) == 0;
}

test "TypeVar flows through the alias value into annotations-shaped use" {
    ns = vm_exec(
        "type Pair[X] = tuple[X, X]\n"
        "tv = Pair.__type_params__[0]\n"
        "nm = tv.__name__\n"
        "r = repr(tv)\n"
    );
    assert vm_str(ns, "nm") == "X";
    assert vm_str(ns, "r") == "X";
}

test "unknown attribute raises CPython's exact AttributeError text" {
    msg = vm_raise_message(
        "type A[T] = list[T]\n"
        "A.__type_params__[0].nonexistent\n"
    );
    assert msg == "'typing.TypeVar' object has no attribute 'nonexistent'";
}
