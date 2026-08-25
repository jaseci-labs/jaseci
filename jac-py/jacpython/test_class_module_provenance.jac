# Class __module__ provenance through the NATIVE type-creation path.
#
# CPython type_new derives cls.__module__ from the namespace's own entry,
# falling back to the invoking frame's globals. jacpython's builder
# (PyNativeNew('type').tp_call -> type_new -> make_pyclass_from_map) runs on
# paths where neither exists -- a metaclass __prepare__ mapping like enum's
# _EnumDict carries no seeded entry, and tp_call dispatch has no frame to
# consult -- so make_pyclass_from_map inherits from the nearest base carrying
# a real __module__, else reuses the defining-context name seeded as
# __name__. These pins guard that fallback chain: enum's bootstrap extend
# guard compares base provenance, and reprs degrade to '<class Name>'
# (<class 'ceval.P'>-style leaks) without it.

import from objects { PyObj, PyStr, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }

def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="enum")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<mod-provenance>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_str(ns: dict[str, PyObj], name: str) -> str {
    return str(to_host(ns[name]));
}

test "native type_new inherits __module__ from the nearest base carrying one" {
    # A metaclass whose __new__ delegates to super().__new__ reaches
    # PyNativeNew('type').tp_call -> type_new with a caller-built namespace
    # that has no __module__; the base chain must supply it.
    ns = vm_exec(
        "class Meta(type):\n"
        "    def __new__(mcls, name, bases, ns):\n"
        "        return super().__new__(mcls, name, bases, ns)\n"
        "class Base:\n"
        "    pass\n"
        "M = Meta('M', (Base,), {'X': 1})\n"
        "r = M.__module__\n"
        "rr = repr(M)\n"
    );
    assert vm_str(ns, "r") == "enum", vm_str(ns, "r");
    assert vm_str(ns, "rr") == "<class 'enum.M'>", vm_str(ns, "rr");
}

test "native type_new reuses the defining-context name when no base has one" {
    # With no provenance anywhere in the base chain, the class-body frame's
    # seeded __name__ (the defining module) fills in -- matching what CPython
    # derives from its frame globals.
    ns = vm_exec(
        "class Meta(type):\n"
        "    def __new__(mcls, name, bases, ns):\n"
        "        return super().__new__(mcls, name, bases, ns)\n"
        "M = Meta('M', (), {'__name__': 'enum', 'X': 1})\n"
        "r = M.__module__\n"
        "rr = repr(M)\n"
    );
    assert vm_str(ns, "r") == "enum", vm_str(ns, "r");
    assert vm_str(ns, "rr") == "<class 'enum.M'>", vm_str(ns, "rr");
}

test "native type_new reads calling-frame globals with no other provenance" {
    # A caller-built namespace with no __module__/__name__ and no base chain:
    # type_new must consult the invoking frame's globals, exactly like CPython
    # -- never leak the runtime module name ('ceval').
    ns = vm_exec(
        "class Meta(type):\n"
        "    def __new__(mcls, name, bases, ns):\n"
        "        return super().__new__(mcls, name, bases, ns)\n"
        "N = Meta('N', (), {'X': 1})\n"
        "r = N.__module__\n"
        "rr = repr(N)\n"
    );
    assert vm_str(ns, "r") == "enum", vm_str(ns, "r");
    assert vm_str(ns, "rr") == "<class 'enum.N'>", vm_str(ns, "rr");
}
