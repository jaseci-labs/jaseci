# yield-from StopIteration-value unwind pins.
#
# Differential vs host CPython 3.14.7: a sub-iterator that ends by RAISING
# StopIteration(value) -- a custom __next__, a user StopIteration subclass,
# or an explicit guest raise -- must propagate its payload into the
# delegating frame's return path (genobject.c unpacks StopIteration.value at
# SEND exhaustion), not just generator `return` (PyGenStop) exhaustion.
#
# Regression context: PyExceptionType.tp_call and user_exception_view left
# the .value slot empty for raised instances, so `ret = (yield from it)`
# observed None whenever the sub-iterator exhausted via raise instead of
# generator return.
import from objects { PyObj, PyStr, is_error }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }

def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<probe>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_str(ns: dict[str, PyObj], name: str) -> str {
    return str(to_host(ns[name]));
}

test "yield-from value: custom __next__ raising StopIteration(42)" {
    # Host oracle: ret == 42 (test_yield_from.py::test_custom_iterator_return).
    ns = vm_exec(
        "class MyIter:\n"
        "    def __iter__(self):\n"
        "        return self\n"
        "    def __next__(self):\n"
        "        raise StopIteration(42)\n"
        "def gen():\n"
        "    ret = (yield from MyIter())\n"
        "    r.append(ret)\n"
        "r = []\n"
        "list(gen())\n"
    );
    got = vm_str(ns, "r");
    assert got == "[42]", got;
}

test "yield-from value: tuple and exception payloads" {
    # Host oracle: [(2,), StopIteration(3)] (PEP380 test_generator_return_value
    # payloads driven through a custom iterator).
    ns = vm_exec(
        "class Done:\n"
        "    def __init__(self, v):\n"
        "        self.v = v\n"
        "    def __iter__(self):\n"
        "        return self\n"
        "    def __next__(self):\n"
        "        raise StopIteration(self.v)\n"
        "def gen(v):\n"
        "    r.append((yield from Done(v)))\n"
        "r = []\n"
        "list(gen((2,)))\n"
        "list(gen(StopIteration(3)))\n"
    );
    got = vm_str(ns, "r");
    assert got == "[(2,), StopIteration(3)]", got;
}

test "yield-from value: nested delegation chain" {
    # Host oracle: mid sees 7; outer drives 1, 2, then StopIteration(None).
    ns = vm_exec(
        "def inner():\n"
        "    yield 1\n"
        "    return 7\n"
        "def mid():\n"
        "    v = (yield from inner())\n"
        "    m.append(v)\n"
        "    yield 2\n"
        "def outer():\n"
        "    yield from mid()\n"
        "m = []\n"
        "o = []\n"
        "it = outer()\n"
        "o.append(next(it))\n"
        "o.append(next(it))\n"
        "try:\n"
        "    next(it)\n"
        "except StopIteration as si:\n"
        "    o.append(si.value)\n"
    );
    got = vm_str(ns, "m") + "|" + vm_str(ns, "o");
    assert got == "[7]|[1, 2, None]", got;
}

test "yield-from value: user StopIteration subclass payload" {
    # Host oracle: E('a').value == 'a'; delegator receives 'a'.
    ns = vm_exec(
        "class E(StopIteration):\n"
        "    pass\n"
        "class It:\n"
        "    def __iter__(self):\n"
        "        return self\n"
        "    def __next__(self):\n"
        "        raise E('a')\n"
        "def gen():\n"
        "    r.append((yield from It()))\n"
        "r = []\n"
        "list(gen())\n"
    );
    got = vm_str(ns, "r");
    assert got == "['a']", got;
}

test "yield-from value: explicit guest raise surface" {
    # Host oracle: ['StopIteration(42)', [42], 42] -- repr/args/value all live.
    ns = vm_exec(
        "try:\n"
        "    raise StopIteration(42)\n"
        "except StopIteration as si:\n"
        "    r = [repr(si), list(si.args), si.value]\n"
    );
    got = vm_str(ns, "r");
    assert got == "['StopIteration(42)', [42], 42]", got;
}

test "yield-from value: multi-arg raise takes first" {
    # Host oracle: StopIteration(1, 2).value is 1; str stays '(1, 2)'.
    ns = vm_exec(
        "class It:\n"
        "    def __iter__(self):\n"
        "        return self\n"
        "    def __next__(self):\n"
        "        raise StopIteration(1, 2)\n"
        "def gen():\n"
        "    r.append((yield from It()))\n"
        "r = []\n"
        "list(gen())\n"
    );
    got = vm_str(ns, "r");
    assert got == "[1]", got;
}

test "yield-from value: argless exhaustion stays None" {
    # Host oracle: plain exhaustion -> ret None; bare StopIteration().value None.
    ns = vm_exec(
        "class It:\n"
        "    def __iter__(self):\n"
        "        return self\n"
        "    def __next__(self):\n"
        "        raise StopIteration()\n"
        "def gen():\n"
        "    r.append((yield from It()))\n"
        "r = []\n"
        "list(gen())\n"
        "try:\n"
        "    raise StopIteration()\n"
        "except StopIteration as si:\n"
        "    v = [repr(si), list(si.args), si.value]\n"
    );
    got = vm_str(ns, "r") + "|" + vm_str(ns, "v");
    assert got == "[None]|['StopIteration()', [], None]", got;
}

test "yield-from value: close paths unchanged" {
    # Host oracle (PEP380 test_delegating_close shape): GeneratorExit unwinds
    # both frames; no StopIteration value leaks into the close path.
    ns = vm_exec(
        "trace = []\n"
        "def g2():\n"
        "    try:\n"
        "        trace.append('s2')\n"
        "        yield 'a'\n"
        "        yield 'b'\n"
        "    finally:\n"
        "        trace.append('f2')\n"
        "def g1():\n"
        "    try:\n"
        "        trace.append('s1')\n"
        "        yield from g2()\n"
        "    finally:\n"
        "        trace.append('f1')\n"
        "g = g1()\n"
        "trace.append(next(g))\n"
        "trace.append(g.close())\n"
    );
    got = vm_str(ns, "trace");
    assert got == "['s1', 's2', 'a', 'f2', 'f1', None]", got;
}
