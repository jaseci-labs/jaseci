# Sequence repetition aliasing regression (TODO.md adversarial item 46).
#
# CPython's sequence repeat (list_repeat / tuple_repeat) duplicates element
# REFERENCES, never the elements: [[0]] * 3 yields three slots pointing at
# ONE inner list, so rows[0].append(1) is visible through rows[1] and rows[2]
# and rows[0] is rows[1] holds. jacpython used to route list/tuple * int
# through the host binop fallback, whose to_host() conversion materialized a
# fresh host copy of every element -- silently breaking the shared-row
# matrix-init idiom. These fixtures pin the reference-aliasing contract.

import from objects { PyObj, PyStr, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }

# Exec `src` on ceval with fresh module globals; fails the test on raise.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<repeat_aliasing>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_bool(ns: dict[str, PyObj], name: str) -> bool {
    return to_host(ns[name]) as bool;
}

test "list repetition aliases element references" {
    ns = vm_exec(
        "rows = [[0]] * 3\n"
        "same01 = rows[0] is rows[1]\n"
        "same02 = rows[0] is rows[2]\n"
        "rows[0].append(1)\n"
        "propagated = len(rows[1]) == 2 and len(rows[2]) == 2\n"
    );
    assert vm_bool(ns, "same01");
    assert vm_bool(ns, "same02");
    assert vm_bool(ns, "propagated");
}

test "tuple repetition aliases element references" {
    ns = vm_exec(
        "inner = [0]\n"
        "rows = (inner,) * 3\n"
        "same = rows[0] is rows[2]\n"
        "inner.append(1)\n"
        "propagated = len(rows[1]) == 2\n"
    );
    assert vm_bool(ns, "same");
    assert vm_bool(ns, "propagated");
}

test "reflected repetition aliases too" {
    ns = vm_exec(
        "rows = 3 * [[0]]\n"
        "same = rows[0] is rows[1]\n"
        "trows = 2 * ([0],)\n"
        "tsame = trows[0] is trows[1]\n"
    );
    assert vm_bool(ns, "same");
    assert vm_bool(ns, "tsame");
}

test "zero and negative multipliers yield empty sequences" {
    ns = vm_exec(
        "x = [0] * 0\n"
        "y = [0] * -3\n"
        "z = (0,) * -1\n"
        "ok = x == [] and y == [] and z == ()\n"
    );
    assert vm_bool(ns, "ok");
}

test "bool multiplier indexes as int" {
    ns = vm_exec(
        "one = [7] * True\n"
        "zero = [7] * False\n"
        "ok = one == [7] and zero == []\n"
    );
    assert vm_bool(ns, "ok");
}

test "literal and variable operands behave identically" {
    ns = vm_exec(
        "lit = [[0]] * 2\n"
        "row = [0]\n"
        "var = [row] * 2\n"
        "lit_same = lit[0] is lit[1]\n"
        "var_same = var[0] is row\n"
    );
    assert vm_bool(ns, "lit_same");
    assert vm_bool(ns, "var_same");
}

test "value-type repeats stay by value" {
    ns = vm_exec(
        "s = 'ab' * 3\n"
        "b = b'ab' * 2\n"
        "ok = s == 'ababab' and b == b'abab'\n"
    );
    assert vm_bool(ns, "ok");
}

test "non-int multiplier still raises TypeError" {
    ns = vm_exec(
        "try:\n"
        "    [1] * 'a'\n"
        "    caught = False\n"
        "except TypeError:\n"
        "    caught = True\n"
    );
    assert vm_bool(ns, "caught");
}
