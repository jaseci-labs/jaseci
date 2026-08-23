# Bytes richcompare + slice hash regressions (TODO.md adversarial items 27+31).
#
# Item 27: ``bytesobject.jac`` referenced Py_LT..Py_GE without importing them,
# so EVERY guest bytes comparison died with NameError("name 'Py_EQ' is not
# defined") -- an internal VM symbol surfacing through the guest error channel.
# Behavior note: guest try/except blocks that accidentally caught that leaked
# NameError around bytes comparisons now see normal comparison semantics.
#
# Item 31: ``slice_hash`` (CPython 3.12+, sliceobject.c) was missing; hash()
# raised TypeError "unhashable type: 'slice'". Implemented in hash_dispatch.jac
# over the shared pyhash xxHash mixer; lane values are seed-independent
# (int constants + None's deterministic 3.12+ hash), so the pins below match
# host CPython exactly across processes.

import from objects { PyObj, PyStr, PyError, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }

# Eval `src` (eval-mode) on ceval; fails the test on raise.
def vm_eval(src: str) -> PyObj {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<bytes_slice_reg>", "eval")), [], ns
    );
    assert not is_error(outcome);
    return outcome;
}

test "bytes equality compares by value" {
    assert to_host(vm_eval("b'a' == b'a'")) as bool;
    assert not (to_host(vm_eval("b'a' == b'b'")) as bool);
    assert to_host(vm_eval("b'ab' != b'aa'")) as bool;
    assert to_host(vm_eval("bytes() == bytes()")) as bool;
}

test "bytes ordering is lexicographic" {
    assert to_host(vm_eval("b'a' < b'b'")) as bool;
    assert to_host(vm_eval("b'abc' <= b'abc'")) as bool;
    assert to_host(vm_eval("b'b' > b'a'")) as bool;
    assert to_host(vm_eval("b'ab' >= b'ab'")) as bool;
    # Length tiebreak after equal prefix (CPython bytes_richcompare).
    assert to_host(vm_eval("b'ab' < b'abc'")) as bool;
    assert to_host(vm_eval("b'' < b'\x00'")) as bool;
}

test "bytes vs str never raises" {
    # Cross-type == / != are plain False / True (NotImplemented -> identity).
    assert not (to_host(vm_eval('b"abc" == "abc"')) as bool);
    assert to_host(vm_eval('b"abc" != "abc"')) as bool;
}

test "hash of slices matches host CPython" {
    assert to_host(vm_eval("hash(slice(1, 7, 2))")) == 953413329778528042;
    assert to_host(vm_eval("hash(slice(None, None, None))")) == 4032618106351268893;
    assert to_host(vm_eval("hash(slice(-10, -2, -3))")) == -2759356318579902834;
    assert to_host(vm_eval("hash(slice(2 ** 70, 2 ** 80))")) == 4586374248881676819;
}
