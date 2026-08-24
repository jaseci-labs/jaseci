# dir() conformance pins (jacpython ceval builtin enumeration).
#
# Guest Python snippets run inside jacpython's ceval via
# host_compile_marshal + unmarshal + exec_code (same harness as
# test_del_liveness.jac -- deliberately NOT layer_p2_libtest, whose module
# graph has an unrelated in-flight breakage; see notes/lane-l-dir-fix.md).
#
# Before the native `dir` builtin, every call fell through to py_call_host ->
# _jac_host_call(fn, args, kwargs), whose trampoline frame has locals
# {args, fn, kwargs} -- so guest dir() returned ['args', 'fn', 'kwargs'] and
# dir(obj) answered host dir() of a lossy to_host copy.
#
# Byte-exactness is judged against THE SAME SUBSTRATE that runs ceval: the
# _pin_host_dir helper builds CPython-equivalent reference objects in the host
# interpreter of this very process and returns sorted(dir(...)). A hardcoded
# name list captured from a different interpreter build goes stale the moment
# either substrate moves (e.g. time.CLOCK_TAI exists in one 3.14 build but not
# another); differential equality cannot drift.

import from objects { PyObj, PyStr, PyError, PyDict, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }

::py::
def _pin_host_dir(kind):
    # Reference enumeration captured from the HOST interpreter running THIS
    # process: equivalent real Python objects, CPython's own dir().
    import builtins
    if kind == "instance" or kind == "class":
        class Foo:
            x = 1
            def meth(self): return 1
        target = Foo() if kind == "instance" else Foo
        return ",".join(sorted(dir(target)))
    if kind == "list":
        return ",".join(sorted(dir([1])))
    if kind == "module":
        import time
        return ",".join(sorted(dir(time)))
    raise ValueError(kind)

::py::

# Host-side reference lists are read once per run through the same bridge the
# VM itself uses; strings cross faithfully.
def pin_host_dir(kind: str) -> str {
    return _pin_host_dir(kind);
}

# Exec `src` on ceval with fresh module globals; fails the test on raise.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<dir_pins>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_str(ns: dict[str, PyObj], name: str) -> str {
    return to_host(ns[name]) as str;
}

test "dir: instance equals same-substrate host dir(instance), byte-exact" {
    ns = vm_exec(
        "class Foo:\n"
        "    x = 1\n"
        "    def meth(self): return 1\n"
        "f = Foo()\n"
        "out = ','.join(dir(f))\n"
    );
    assert vm_str(ns, "out") == pin_host_dir("instance"), (
        vm_str(ns, "out") + " != " + pin_host_dir("instance")
    );
}

test "dir: class equals same-substrate host dir(class), byte-exact" {
    ns = vm_exec(
        "class Foo:\n"
        "    x = 1\n"
        "    def meth(self): return 1\n"
        "out = ','.join(dir(Foo))\n"
    );
    assert vm_str(ns, "out") == pin_host_dir("class"), (
        vm_str(ns, "out") + " != " + pin_host_dir("class")
    );
}

test "dir: no-arg inside a function lists bound fast locals" {
    ns = vm_exec(
        "def g(a, b=2):\n"
        "    c = a + b\n"
        "    d = str(a)\n"
        "    return ','.join(dir())\n"
        "out = g(1)\n"
    );
    assert vm_str(ns, "out") == "a,b,c,d", vm_str(ns, "out");
}

test "dir: no-arg never leaks trampoline frame names" {
    # The original bug shape: ['args', 'fn', 'kwargs']. A fresh module frame
    # holds exactly one local -- __name__ (module locals ARE globals), so the
    # correct answer is that single name and nothing from any host frame.
    ns = vm_exec("out = repr(sorted(dir()))\n");
    assert vm_str(ns, "out") == "['__name__']", vm_str(ns, "out");
}

test "dir: module equals same-substrate host dir(module), byte-exact" {
    ns = vm_exec(
        "import time\n"
        "out = ','.join(dir(time))\n"
    );
    assert vm_str(ns, "out") == pin_host_dir("module"), (
        vm_str(ns, "out") + " != " + pin_host_dir("module")
    );
}

test "dir: user __dir__ override wins and result is sorted" {
    ns = vm_exec(
        "class DirOverride:\n"
        "    def __dir__(self):\n"
        "        return ['zeta', 'alpha']\n"
        "o = DirOverride()\n"
        "out = ','.join(dir(o))\n"
    );
    assert vm_str(ns, "out") == "alpha,zeta", vm_str(ns, "out");
}

test "star import: names land in the namespace so no-arg dir() sees them" {
    ns = vm_exec(
        "from math import *\n"
        "out = str('sqrt' in dir()) + ',' + str('pi' in dir())\n"
    );
    assert vm_str(ns, "out") == "True,True", vm_str(ns, "out");
}

test "dir: native container equals same-substrate host dir(list)" {
    ns = vm_exec("out = ','.join(dir([1]))\n");
    assert vm_str(ns, "out") == pin_host_dir("list"), (
        vm_str(ns, "out") + " != " + pin_host_dir("list")
    );
}
