# Small-slot conformance pins (TODO items 54, 76, 44).
#
# Item 54: ``PySlice.tp_richcompare`` was missing, so slice(1, 2) ==
# slice(1, 2) fell through to the object identity test and answered False.
# CPython's slice_richcompare compares start/stop/step pairwise (eq/ne only;
# ordering is NotImplemented); hash() already existed from earlier work, so
# equal slices must now also interoperate as dict keys.
#
# Item 76: ``__mro__`` stopped at the last user class -- CPython appends the
# terminal object -- and type.mro() was absent entirely. Both now end at the
# same host-object proxy the guest sees for the global name `object`, keeping
# display aligned with isinstance/issubclass semantics.

import from objects { PyObj, PyStr, PyError, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }

def _fresh_ns -> dict[str, PyObj] {
    return {"__name__": PyStr(t="str", val="__main__")};
}

# Eval `src` (eval-mode) on ceval in `ns`; fails the test on raise.
def vm_eval_in(ns: dict[str, PyObj], src: str) -> PyObj {
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<small_slots>", "eval")), [], ns
    );
    assert not is_error(outcome);
    return outcome;
}

def vm_eval(src: str) -> PyObj {
    return vm_eval_in(_fresh_ns(), src);
}

# Run `src` (exec-mode); fails the test on raise.
def vm_exec_in(ns: dict[str, PyObj], src: str) {
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<small_slots>", "exec")), [], ns
    );
    assert not is_error(outcome);
}

# Eval/exec `src` and return the raw outcome (an error object on raise) so a
# test can pin the raised exception itself.
def vm_try_in(ns: dict[str, PyObj], src: str, mode: str) -> PyObj {
    return exec_code(
        unmarshal(host_compile_marshal(src, "<small_slots>", mode)), [], ns
    );
}

test "slice equality compares bounds by value" {
    assert to_host(vm_eval("slice(1, 2) == slice(1, 2)")) as bool;
    assert not (to_host(vm_eval("slice(1, 2) == slice(1, 3)")) as bool);
    assert to_host(vm_eval("slice(None, None, None) == slice(None, None, None)")) as bool;
    assert to_host(vm_eval("slice(2 ** 70, 2 ** 80) == slice(2 ** 70, 2 ** 80)")) as bool;
    # step participates: slice(1, 2, 3) != slice(1, 2, None)
    assert to_host(vm_eval("slice(1, 2, 3) != slice(1, 2, None)")) as bool;
}

test "slice vs non-slice defers to identity fallback" {
    assert not (to_host(vm_eval("slice(1, 2) == 5")) as bool);
    assert to_host(vm_eval("slice(1, 2) != 'x'")) as bool;
    assert to_host(vm_eval("(lambda s: s == s)(slice(1, 2))")) as bool;
}

test "equal slices stay valid dict keys alongside hash()" {
    ns = _fresh_ns();
    vm_exec_in(
        ns,
        "d = {slice(1, 2): 'a', slice(1, 3): 'b'}\n"
        "assert d[slice(1, 2)] == 'a'\n"
        "assert d[slice(1, 3)] == 'b'\n"
        "assert hash(slice(1, 7, 2)) == 953413329778528042\n",
    );
}

test "slice ordering is NotImplemented" {
    outcome = vm_try_in(_fresh_ns(), "slice(1, 2) < slice(1, 3)", "eval");
    assert isinstance(outcome, PyError);
    exc = (outcome as PyError).exception;
    assert exc.type_name == "TypeError";
    assert exc.message
        == "'<' not supported between instances of 'slice' and 'slice'";
}

# ---- item 76: terminal object in __mro__, plus the mro() method ------------

def class_ns(src: str) -> dict[str, PyObj] {
    ns = _fresh_ns();
    vm_exec_in(ns, src);
    return ns;
}

test "__mro__ ends at object and displays like CPython" {
    ns = class_ns("class B:\n    pass\n\nclass C(B):\n    pass\n");
    assert to_host(vm_eval_in(ns, "[c.__name__ for c in C.__mro__]"))
        == ["C", "B", "object"];
    assert (to_host(vm_eval_in(ns, "type(C.__mro__).__name__")) as str) == "tuple";
    assert to_host(vm_eval_in(ns, "C.__mro__[-1] is object")) as bool;
    assert (to_host(vm_eval_in(ns, "repr(C.__mro__)")) as str)
        == "(<class '__main__.C'>, <class '__main__.B'>, <class 'object'>)";
}

test "mro() returns the same list as list(__mro__)" {
    ns = class_ns("class B:\n    pass\n\nclass C(B):\n    pass\n");
    assert to_host(vm_eval_in(ns, "C.mro() == list(C.__mro__)")) as bool;
    assert to_host(vm_eval_in(ns, "[c.__name__ for c in C.mro()]"))
        == ["C", "B", "object"];
}

test "isinstance/issubclass agree with the displayed MRO" {
    ns = class_ns("class B:\n    pass\n\nclass C(B):\n    pass\n");
    assert to_host(vm_eval_in(ns, "isinstance(C(), object)")) as bool;
    assert to_host(vm_eval_in(ns, "issubclass(C, object)")) as bool;
}
