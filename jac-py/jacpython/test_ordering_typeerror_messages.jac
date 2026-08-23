# Cross-type ordering TypeError message fidelity (TODO.md item 43).
#
# CPython raises "'<operator>' not supported between instances of 'T1' and
# 'T2'" when an ordering comparison falls through every slot; jacpython used
# to raise a generic "unorderable types". The user_binop fallback mirrors
# CPython's "unsupported operand type(s) for <op>: 'T1' and 'T2'". These
# fixtures pin the exact host wording with real runtime type names.
#
# == and != NEVER raise this: they fall back to identity (False/True).

import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }
import from objects { PyObj, PyStr, is_error }

# Exec `src` on ceval with fresh module globals; fails the test on raise.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<ordering_typeerror>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_str(expr: str) -> str {
    ns = vm_exec(
        "try:\n"
        "    r = " + expr + "\n"
        "except TypeError as e:\n"
        "    r = 'TypeError: ' + str(e)\n"
    );
    return to_host(ns["r"]) as str;
}

test "int < str raises CPython-exact message" {
    assert vm_str("1 < 'a'")
        == "TypeError: '<' not supported between instances of 'int' and 'str'";
}

test "int > tuple raises CPython-exact message" {
    assert vm_str("1 > (1, 2)")
        == "TypeError: '>' not supported between instances of 'int' and 'tuple'";
}

test "list <= int raises CPython-exact message" {
    assert vm_str("[1] <= 2")
        == "TypeError: '<=' not supported between instances of 'list' and 'int'";
}

test "None >= float raises CPython-exact message" {
    assert vm_str("None >= 3.5")
        == "TypeError: '>=' not supported between instances of 'NoneType' and 'float'";
}

test "user class instances print class name in ordering error" {
    ns = vm_exec(
        "class A:\n"
        "    pass\n"
        "try:\n"
        "    r = A() < A()\n"
        "except TypeError as e:\n"
        "    r = 'TypeError: ' + str(e)\n"
    );
    assert to_host(ns["r"]) as str
        == "TypeError: '<' not supported between instances of 'A' and 'A'";
}

test "user binop without dunders prints operator and type names" {
    ns = vm_exec(
        "class A:\n"
        "    pass\n"
        "try:\n"
        "    r = A() + 1\n"
        "except TypeError as e:\n"
        "    r = 'TypeError: ' + str(e)\n"
    );
    assert to_host(ns["r"]) as str
        == "TypeError: unsupported operand type(s) for +: 'A' and 'int'";
}

test "eq and ne never raise unorderable TypeError" {
    ns = vm_exec("eq = 1 == 'a'\nne = 1 != 'a'\n");
    assert (to_host(ns["eq"]) as bool) is False;
    assert (to_host(ns["ne"]) as bool) is True;
}
