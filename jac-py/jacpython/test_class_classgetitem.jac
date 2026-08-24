# User-class subscription pins (lane box-subscript).
#
# Each fixture executes Python source on jacpython's ceval via host-compiled
# marshal and asserts CPython-oracle outcomes for `Cls[...]` where Cls is a
# user-defined class:
#
# - A class whose MRO carries no __class_getitem__ raises CPython's exact
#   miss text: "type '<name>' is not subscriptable" (type_subscript in
#   typeobject.c -- note the "type '...'" prefix, unlike instance misses).
# - An explicit __class_getitem__ def dispatches, bound to the class, with
#   the subscript value passed through verbatim (slices/tuples included).
# - __class_getitem__ resolves through the MRO (inherited from a base) and
#   a subclass override shadows the inherited one.
# - A custom metaclass __getitem__ outranks the class's __class_getitem__
#   (slot_tp_subscript on the metaclass intercepts first). NOT integration-
#   pinned yet: every construction combining a metaclass with a
#   __class_getitem__ hits PRE-EXISTING gaps in the metaclass lane --
#   (a) class creation under a custom metaclass bridges to the host, so a
#       body containing `def` dies on the __classcell__ bridge ('cell' has
#       policy BridgePolicy.FAIL), and bases die on ('class' STANDIN);
#   (b) post-creation setattr lands in VM attrs only, so the host class
#       never sees __class_getitem__ and subscription misses.
#   Both reproduce without this lane's diff. Re-pin once metaclass bridging
#   round-trips VM attrs.
#
# Expected strings were taken from CPython 3.14 (host oracle).

import from host_oracle { host_compile_marshal }
import from pyc_first { exec_code, unmarshal, to_host }
import from objects { PyObj, PyStr, PyError, is_error }

# Exec `src` on ceval with fresh module globals; fails the test on raise.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<class_getitem>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_str(ns: dict[str, PyObj], name: str) -> str {
    return str(to_host(ns[name]));
}

# Exec `src` and return the raised exception message ("" if none).
def vm_raise_message(src: str) -> str {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<class_getitem_raise>", "exec")),
        [],
        ns,
    );
    if is_error(outcome) {
        return ((outcome as PyError).exception.message);
    }
    return "";
}

test "plain class miss raises CPython's exact subscript error" {
    msg = vm_raise_message(
        "class Box:\n"
        "    pass\n"
        "Box[int]\n"
    );
    # Host: TypeError: type 'Box' is not subscriptable
    assert msg == "type 'Box' is not subscriptable";
}

test "explicit __class_getitem__ dispatches bound to the class" {
    ns = vm_exec(
        "class WithCGI:\n"
        "    def __class_getitem__(cls, item):\n"
        "        return (cls.__name__, item)\n"
        "r = WithCGI[int]\n"
    );
    assert vm_str(ns, "r") == "('WithCGI', <class 'int'>)";
}

test "subscript value passes through verbatim (slice + tuple)" {
    ns = vm_exec(
        "class SliceCGI:\n"
        "    def __class_getitem__(cls, item):\n"
        "        return repr(item)\n"
        "r = SliceCGI[1:2, int]\n"
    );
    assert vm_str(ns, "r") == "(slice(1, 2, None), <class 'int'>)";
}

test "__class_getitem__ resolves through the MRO" {
    ns = vm_exec(
        "class Base:\n"
        "    def __class_getitem__(cls, item):\n"
        "        return 'inh:' + cls.__name__\n"
        "class Child(Base):\n"
        "    pass\n"
        "r = Child[float]\n"
    );
    assert vm_str(ns, "r") == "inh:Child";
}

test "subclass override shadows inherited __class_getitem__" {
    ns = vm_exec(
        "class Base:\n"
        "    def __class_getitem__(cls, item):\n"
        "        return 'inh'\n"
        "class Over(Base):\n"
        "    def __class_getitem__(cls, item):\n"
        "        return 'over'\n"
        "r = Over[int]\n"
    );
    assert vm_str(ns, "r") == "over";
}


