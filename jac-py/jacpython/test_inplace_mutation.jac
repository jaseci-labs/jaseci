# In-place operator mutation contract (TODO item 49).
#
# CPython's nb_inplace_* slots on mutable containers MUTATE the receiver and
# return it, so `a = b = []; a += [x]` keeps `a is b` True and `b` observes
# the update -- the trailing STORE_FAST re-binds the same object. jacpython
# used to fold NB_INPLACE_* (13..25) straight to their base binops, turning
# every augmented assignment into a rebinding concat/repeat and silently
# breaking container aliases.
#
# Immutable types (str/bytes/int/tuple/frozenset) have no in-place slots and
# legitimately rebind here; these fixtures pin that side of the contract too
# so the fold cannot be removed for them by accident.

import from host_oracle { host_compile_marshal }
import from pyc_first { exec_code, to_host, unmarshal }
import from objects { PyObj, PyStr, PyError, is_error }

# Exec `src` on ceval with fresh module globals; fails the test on raise.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<inplace_mutation>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_bool(ns: dict[str, PyObj], name: str) -> bool {
    return to_host(ns[name]) as bool;
}

test "list iadd mutates in place and preserves aliases" {
    ns = vm_exec(
        "a = b = [1]\n"
        "a += [2]\n"
        "same = a is b\n"
        "bval = list(b)\n"
    );
    assert vm_bool(ns, "same");
    assert to_host(ns["bval"]) == [1, 2];
}

test "list imul mutates in place and preserves aliases" {
    ns = vm_exec(
        "g = h = [3]\n"
        "g *= 2\n"
        "same = g is h\n"
        "hval = list(h)\n"
    );
    assert vm_bool(ns, "same");
    assert to_host(ns["hval"]) == [3, 3];
}

test "set inplace algebra mutates in place and preserves aliases" {
    ns = vm_exec(
        "c = d = {1}\n"
        "c |= {2}\n"
        "or_same = c is d\n"
        "or_val = set(d)\n"
        "e = f = {1, 2, 3}\n"
        "e &= {2, 3, 4}\n"
        "and_same = e is f\n"
        "and_val = set(f)\n"
        "i = j = {1, 2, 3}\n"
        "i -= {2}\n"
        "sub_same = i is j\n"
        "sub_val = set(j)\n"
        "k = l = {1, 2, 3}\n"
        "k ^= {2, 4}\n"
        "xor_same = k is l\n"
        "xor_val = set(l)\n"
    );
    assert vm_bool(ns, "or_same");
    assert to_host(ns["or_val"]) == {1, 2};
    assert vm_bool(ns, "and_same");
    assert to_host(ns["and_val"]) == {2, 3};
    assert vm_bool(ns, "sub_same");
    assert to_host(ns["sub_val"]) == {1, 3};
    assert vm_bool(ns, "xor_same");
    assert to_host(ns["xor_val"]) == {1, 3, 4};
}

test "frozenset ior rebinds instead of mutating" {
    # frozenset has no in-place slot: CPython folds to the base binop and
    # rebinds to a NEW frozenset -- legal and observable here.
    ns = vm_exec(
        "g = h = frozenset({1})\n"
        "g |= {2}\n"
        "rebound = g is not h\n"
        "gval = g == frozenset({1, 2})\n"
        "hval = h == frozenset({1})\n"
    );
    assert vm_bool(ns, "rebound");
    assert vm_bool(ns, "gval");
    assert vm_bool(ns, "hval");
}

test "immutable types still rebind under augmented assignment" {
    ns = vm_exec(
        "s1 = s2 = 'x'\n"
        "s1 += 'y'\n"
        "str_split = s1 is not s2\n"
        "t1 = t2 = (1, 2)\n"
        "t1 += (3,)\n"
        "tuple_split = t1 is not t2\n"
        "b1 = b2 = b'x'\n"
        "b1 += b'y'\n"
        "bytes_split = b1 is not b2\n"
        "n1 = n2 = 10\n"
        "n1 += 5\n"
        "int_split = n1 is not n2\n"
    );
    assert vm_bool(ns, "str_split");
    assert vm_bool(ns, "tuple_split");
    assert vm_bool(ns, "bytes_split");
    assert vm_bool(ns, "int_split");
}

test "inplace arms accept any iterable and reject invalid operands" {
    ns = vm_exec(
        "lst = [1]\n"
        "lst += (2, 3)\n"
        "from_tuple = lst == [1, 2, 3]\n"
        "chars = ['a']\n"
        "chars += 'bc'\n"
        "from_str = chars == ['a', 'b', 'c']\n"
        "empty = [7]\n"
        "alias = empty\n"
        "empty *= 0\n"
        "mul0_alias = empty is alias\n"
        "mul0_val = empty == []\n"
        "raised_ext = False\n"
        "try:\n"
        "    bad = [1]\n"
        "    bad += 5\n"
        "except TypeError:\n"
        "    raised_ext = True\n"
        "raised_mul = False\n"
        "try:\n"
        "    nm = [1]\n"
        "    nm *= 'x'\n"
        "except TypeError:\n"
        "    raised_mul = True\n"
        "raised_unhashable = False\n"
        "try:\n"
        "    uh = {1}\n"
        "    uh |= [[2]]\n"
        "except TypeError:\n"
        "    raised_unhashable = True\n"
    );
    assert vm_bool(ns, "from_tuple");
    assert vm_bool(ns, "from_str");
    assert vm_bool(ns, "mul0_alias");
    assert vm_bool(ns, "mul0_val");
    assert vm_bool(ns, "raised_ext");
    assert vm_bool(ns, "raised_mul");
    assert vm_bool(ns, "raised_unhashable");
}
