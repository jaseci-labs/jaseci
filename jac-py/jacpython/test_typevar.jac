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

# ---- lane-typevar-depth: lazy bound/constraints/default surface ----
#
# Host oracle (CPython 3.14.7 typevarobject.c):
# - Creating a TypeVar with a forward-ref bound never evaluates it; only
#   __bound__ / evaluate_bound() force evaluation (NameError propagates
#   uncached on retry).
# - evaluate_bound/evaluate_constraints/evaluate_default are getsets exposing
#   the hidden zero-arg evaluators themselves (None when absent).
# - has_default() is syntactic: True iff a default= was given, never forcing
#   default evaluation.
#
# Adaptations vs the original lane pins: absent __default__ answers the
# typing.NoDefault sentinel (host-correct on this tree), and getset presence
# is pinned in-VM with `is None` rather than bridging function objects.

test "bounded alias parameter keeps __bound__ lazy and exact" {
    ns = vm_exec(
        "type B[U: int] = list[U]\n"
        "tv = B.__type_params__[0]\n"
        "bnd = str(tv.__bound__)\n"
        "via_fn = str(tv.evaluate_bound())\n"
        "again = str(tv.__bound__)\n"
    );
    assert vm_str(ns, "bnd") == "<class 'int'>";
    assert vm_str(ns, "via_fn") == "<class 'int'>";
    assert vm_str(ns, "again") == "<class 'int'>";
}

test "forward-ref bound does not raise at creation" {
    msg = vm_raise_message(
        "type D[F: undefined_fwd] = list[F]\n"
        "ok = 1\n"
    );
    assert msg == "";
}

test "evaluating an unresolvable forward-ref bound raises NameError uncached" {
    msg = vm_raise_message(
        "type D[F: undefined_fwd] = list[F]\n"
        "D.__type_params__[0].__bound__\n"
    );
    assert msg == "name 'undefined_fwd' is not defined";
    msg2 = vm_raise_message(
        "type D[F: undefined_fwd] = list[F]\n"
        "D.__type_params__[0].evaluate_bound()\n"
    );
    assert msg2 == "name 'undefined_fwd' is not defined";
}

test "constrained alias parameter exposes tuple constraints lazily" {
    ns = vm_exec(
        "type C[W: (int, str)] = list[W]\n"
        "tv = C.__type_params__[0]\n"
        "cons = str(tv.__constraints__)\n"
        "n = len(tv.__constraints__)\n"
        "via_fn = str(tv.evaluate_constraints())\n"
    );
    assert vm_str(ns, "cons") == "(<class 'int'>, <class 'str'>)";
    assert to_host(ns["n"]) == 2;
    assert vm_str(ns, "via_fn") == "(<class 'int'>, <class 'str'>)";
}

test "evaluate getsets are None exactly when the slot is absent" {
    ns = vm_exec(
        "type A[T] = list[T]\n"
        "type B[U: int] = list[U]\n"
        "ta = A.__type_params__[0]\n"
        "tb = B.__type_params__[0]\n"
        "plain_b = ta.evaluate_bound is None\n"
        "plain_c = ta.evaluate_constraints is None\n"
        "plain_d = ta.evaluate_default is None\n"
        "bnd_b = tb.evaluate_bound is None\n"
    );
    assert vm_bool(ns, "plain_b");
    assert vm_bool(ns, "plain_c");
    assert vm_bool(ns, "plain_d");
    assert not vm_bool(ns, "bnd_b");
}

test "has_default is False without default and True with one" {
    ns = vm_exec(
        "type A[T] = list[T]\n"
        "type E[G: int = str] = list[G]\n"
        "type H[J = dict] = list[J]\n"
        "no_d = A.__type_params__[0].has_default()\n"
        "dflt = E.__type_params__[0].has_default()\n"
        "only_d = H.__type_params__[0].has_default()\n"
    );
    assert not vm_bool(ns, "no_d");
    assert vm_bool(ns, "dflt");
    assert vm_bool(ns, "only_d");
}

test "has_default rejects arguments with CPython's exact TypeError text" {
    msg = vm_raise_message(
        "type A[T] = list[T]\n"
        "A.__type_params__[0].has_default(1)\n"
    );
    assert msg == "TypeVar.has_default() takes no arguments (1 given)";
    msg2 = vm_raise_message(
        "type A[T] = list[T]\n"
        "A.__type_params__[0].has_default(x=1)\n"
    );
    assert msg2 == "TypeVar.has_default() takes no keyword arguments";
}

test "default slot evaluates lazily and keeps arm-5 object identity" {
    ns = vm_exec(
        "type E[G: int = str] = list[G]\n"
        "tv = E.__type_params__[0]\n"
        "d = str(tv.__default__)\n"
        "via_fn = str(tv.evaluate_default())\n"
        "again = str(tv.__default__)\n"
        "hd = tv.has_default()\n"
        "same = E.__type_params__[0] is tv\n"
    );
    assert vm_str(ns, "d") == "<class 'str'>";
    assert vm_str(ns, "via_fn") == "<class 'str'>";
    assert vm_str(ns, "again") == "<class 'str'>";
    assert vm_bool(ns, "hd");
    # Arm 5 mutates the TypeVar IN PLACE (typevarobject.c Py_XSETREF), so the
    # parameter stored in __type_params__ IS the defaulted object.
    assert vm_bool(ns, "same");
}

test "implicit parameter still pins absent slots after the lazy extension" {
    ns = vm_exec(
        "type A[T] = list[T]\n"
        "tv = A.__type_params__[0]\n"
        "bnd = tv.__bound__ is None\n"
        "cons = tv.__constraints__ == ()\n"
        "df = str(tv.__default__)\n"
        "r = repr(tv)\n"
    );
    assert vm_bool(ns, "bnd");
    assert vm_bool(ns, "cons");
    # PEP 696 host oracle: an absent default is typing.NoDefault, not None.
    assert vm_str(ns, "df") == "typing.NoDefault";
    assert vm_str(ns, "r") == "T";
}
