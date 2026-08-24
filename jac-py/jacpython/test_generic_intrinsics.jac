# CALL_INTRINSIC_2 family + CALL_INTRINSIC_1 arg 10 pins (lane J follow-on).
#
# Each fixture executes Python source on jacpython's ceval via host-compiled
# marshal and asserts CPython-oracle outcomes for full PEP 695 generic
# function/class definitions:
#
# - CALL_INTRINSIC_2 arg 2 (TYPEVAR_WITH_BOUND): builds the TypeVar from
#   (name, lazy-bound-evaluator); __bound__ evaluates once on first access
#   and caches (identity-stable), None when absent.
# - CALL_INTRINSIC_2 arg 3 (TYPEVAR_WITH_CONSTRAINTS): same shape;
#   __constraints__ evaluates to the tuple, () when absent.
# - CALL_INTRINSIC_2 arg 4 (SET_FUNCTION_TYPE_PARAMS): stores the parameter
#   tuple on the function object as __type_params__.
# - CALL_INTRINSIC_2 arg 5 (SET_TYPEPARAM_DEFAULT): lazy default evaluated on
#   first __default__ access; typing.NoDefault (repr 'typing.NoDefault') when
#   absent.
# - CALL_INTRINSIC_1 arg 10 (INTRINSIC_SUBSCRIPT_GENERIC): implicit class base
#   Generic[T, ...]; py_build_class resolves it through __mro_entries__
#   (update_bases port) so the MRO reads (C, typing.Generic, object) and the
#   original bases land in __orig_bases__ AFTER the body runs.
#
# Expected strings were taken from CPython 3.14 (host oracle).

import from host_oracle { host_compile_marshal }
import from pyc_first { exec_code, unmarshal, to_host }
import from objects { PyObj, PyStr, PyError, is_error }

# Exec `src` on ceval with fresh module globals; fails the test on raise.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<generic>", "exec")), [], ns
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
        unmarshal(host_compile_marshal(src, "<generic_raise>", "exec")), [], ns
    );
    if is_error(outcome) {
        return ((outcome as PyError).exception.message);
    }
    return "";
}

test "generic function pins its type parameters" {
    ns = vm_exec(
        "def f[T, U](x: T, y: U):\n"
        "    return y\n"
        "names = [p.__name__ for p in f.__type_params__]\n"
        "r = repr(f.__type_params__[0])\n"
        "count = len(f.__type_params__)\n"
    );
    assert vm_str(ns, "names") == "['T', 'U']";
    assert vm_str(ns, "r") == "T";
    assert to_host(ns["count"]) == 2;
}

test "bounded parameter evaluates its bound lazily and caches" {
    ns = vm_exec(
        "def g[T: int](x):\n"
        "    return x\n"
        "tv = g.__type_params__[0]\n"
        "bnd = tv.__bound__ is int\n"
        "again = tv.__bound__ is tv.__bound__\n"
    );
    assert vm_bool(ns, "bnd");
    assert vm_bool(ns, "again");
}

test "unbounded parameter answers a None bound" {
    ns = vm_exec(
        "def f[T](x):\n"
        "    return x\n"
        "bnd = f.__type_params__[0].__bound__ is None\n"
    );
    assert vm_bool(ns, "bnd");
}

test "constrained parameter evaluates its constraints" {
    ns = vm_exec(
        "def h[T: (int, str)](x):\n"
        "    return x\n"
        "tv = h.__type_params__[0]\n"
        "cons = tv.__constraints__ == (int, str)\n"
        "empty = type('X', (), {}).__name__\n"
    );
    assert vm_bool(ns, "cons");
    assert vm_str(ns, "empty") == "X";  # sanity: module still live
}

test "parameter default evaluates lazily; absence is NoDefault" {
    ns = vm_exec(
        "def d[T = int]():\n"
        "    pass\n"
        "class C[S]:\n"
        "    pass\n"
        "dflt = d.__type_params__[0].__default__ is int\n"
        "nodef = repr(C.__type_params__[0].__default__)\n"
    );
    assert vm_bool(ns, "dflt");
    assert vm_str(ns, "nodef") == "typing.NoDefault";
}

test "generic function still calls normally" {
    ns = vm_exec(
        "def f[T](x):\n"
        "    return x\n"
        "a = f(3)\n"
        "s = f('hi')\n"
    );
    assert to_host(ns["a"]) == 3;
    assert vm_str(ns, "s") == "hi";
}

test "generic class resolves Generic into its MRO and orig bases" {
    ns = vm_exec(
        "class C[T]:\n"
        "    pass\n"
        "mro = repr(C.__mro__)\n"
        "ob = repr(C.__orig_bases__[0])\n"
        "oargs = C.__orig_bases__[0].__args__ == (C.__type_params__[0],)\n"
        "tpname = C.__type_params__[0].__name__\n"
        "bases = len(C.__bases__)\n"
    );
    # Host 3.14: (<class '__main__.C'>, <class 'typing.Generic'>, <class 'object'>)
    assert (
        vm_str(ns, "mro")
        == "(<class '__main__.C'>, <class 'typing.Generic'>, <class 'object'>)"
    );
    assert vm_str(ns, "ob") == "typing.Generic[T]";
    assert vm_bool(ns, "oargs");
    assert vm_str(ns, "tpname") == "T";
    assert to_host(ns["bases"]) == 1;
}

test "generic class instantiates and dispatches methods" {
    ns = vm_exec(
        "class Box[T]:\n"
        "    def get(self, x: T):\n"
        "        return x\n"
        "v = Box().get(41)\n"
        "w = v + 1\n"
    );
    assert to_host(ns["w"]) == 42;
}

test "generic class body sees its parameters through the closure" {
    ns = vm_exec(
        "class P[T]:\n"
        "    tp = T.__name__\n"
        "val = P.tp\n"
    );
    assert vm_str(ns, "val") == "T";
}
