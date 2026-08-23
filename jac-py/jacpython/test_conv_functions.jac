# Function/closure/lambda/decorator semantics converted from CPython
# Lib/test/test_decorators.py (the snapshot has no test_functions.py,
# test_closure.py, or test_lambda.py; their classic cases are folded into
# these pins). Two idioms:
#   - layer1_replay_source differential unittest pins for calling/closure
#     semantics (both legs run identical harvested source);
#   - direct ceval execution (vm_exec) for decorator-application behavior --
#     the layer-1 harvester's statement segments start at `def`, so decorator
#     lines are invisible to it and any pin depending on them would be vacuous
#     or honestly skipped.
# Dropped after probing: annotations-as-objects (`__annotations__` is not
# exposed on native functions yet); cell introspection via `__closure__`
# (unsupported attribute -- co_freevars + nonlocal mutation stand in).

import from layer0_replay_harness {
    ReplayResult,
    layer1_replay_source,
}
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }
import from objects { PyObj, PyStr, is_error }

def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<conv_functions>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_str(ns: dict[str, PyObj], name: str) -> str {
    return str(to_host(ns[name]));
}

# ---------------- defaults / argument passing ----------------

test "functions: default args evaluate once and share mutable defaults" {
    src = "class TestDefaultsOnce(unittest.TestCase):\n"
    "    def test_shared_default(self):\n"
    "        def f(x, acc=[]):\n"
    "            acc.append(x)\n"
    "            return acc\n"
    "        self.assertIs(f(1), f(2))\n"
    "        self.assertEqual(f(3), [1, 2, 3])\n"
    "    def test_def_time_evaluation(self):\n"
    "        n = 10\n"
    "        def g(a=n):\n"
    "            return a\n"
    "        n = 99\n"
    "        self.assertEqual(g(), 10)\n";
    result = layer1_replay_source(src);
    assert result.passed == 2;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "functions: *args/**kwargs round-trip through forwarding calls" {
    src = "class TestArgsKwargs(unittest.TestCase):\n"
    "    def test_round_trip(self):\n"
    "        def f(*args, **kwargs):\n"
    "            return (args, kwargs)\n"
    "        a, k = f(1, 'x', z=3)\n"
    "        self.assertEqual(a, (1, 'x'))\n"
    "        self.assertEqual(k, {'z': 3})\n"
    "    def test_forwarding(self):\n"
    "        def inner(*args, **kw):\n"
    "            return (args, kw)\n"
    "        def outer(*args, **kw):\n"
    "            return inner(*args, **kw)\n"
    "        self.assertEqual(outer(5, q=6), ((5,), {'q': 6}))\n";
    result = layer1_replay_source(src);
    assert result.passed == 2;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "functions: keyword-only args reject positional overflow" {
    src = "class TestKwOnly(unittest.TestCase):\n"
    "    def test_kwonly(self):\n"
    "        def f(a, *, b=2):\n"
    "            return (a, b)\n"
    "        self.assertEqual(f(1), (1, 2))\n"
    "        self.assertEqual(f(1, b=9), (1, 9))\n"
    "        with self.assertRaises(TypeError):\n"
    "            f(1, 9)\n";
    result = layer1_replay_source(src);
    assert result.passed == 1;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

# ---------------- closures ----------------

test "functions: closures over loop vars bind late unless pinned" {
    src = "class TestLoopClosure(unittest.TestCase):\n"
    "    def test_late_binding(self):\n"
    "        fs = []\n"
    "        for i in range(3):\n"
    "            fs.append(lambda: i)\n"
    "        self.assertEqual([f() for f in fs], [2, 2, 2])\n"
    "    def test_default_pins(self):\n"
    "        fs = []\n"
    "        for i in range(3):\n"
    "            fs.append(lambda i=i: i)\n"
    "        self.assertEqual([f() for f in fs], [0, 1, 2])\n";
    result = layer1_replay_source(src);
    assert result.passed == 2;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "functions: sibling closures share one mutable cell" {
    # Cell/free identity without __closure__: get/inc close over the SAME
    # cell, so nonlocal mutation is visible through the reader.
    src = "class TestCellIdentity(unittest.TestCase):\n"
    "    def test_shared_cell(self):\n"
    "        def outer():\n"
    "            x = 10\n"
    "            def get():\n"
    "                return x\n"
    "            def inc():\n"
    "                nonlocal x\n"
    "                x = x + 1\n"
    "            return (get, inc)\n"
    "        get, inc = outer()\n"
    "        self.assertEqual(get(), 10)\n"
    "        inc()\n"
    "        self.assertEqual(get(), 11)\n"
    "        self.assertEqual(get.__code__.co_freevars, ('x',))\n";
    result = layer1_replay_source(src);
    assert result.passed == 1;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

# ---------------- function metadata ----------------

test "functions: __name__/__qualname__/docstring visible on nested defs" {
    src = "class TestMeta(unittest.TestCase):\n"
    "    def test_meta(self):\n"
    "        def outer():\n"
    "            def inner():\n"
    "                'doc here'\n"
    "            return inner\n"
    "        i = outer()\n"
    "        self.assertEqual(i.__name__, 'inner')\n"
    "        self.assertEqual(i.__qualname__, 'outer.<locals>.inner')\n"
    "        self.assertEqual(i.__doc__, 'doc here')\n";
    result = layer1_replay_source(src);
    assert result.passed == 1;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

# ---------------- recursion / errors / lambdas ----------------

test "functions: recursion through the enclosing name works" {
    src = "class TestRecursion(unittest.TestCase):\n"
    "    def test_fib(self):\n"
    "        def fib(n):\n"
    "            return n if n < 2 else fib(n-1) + fib(n-2)\n"
    "        self.assertEqual(fib(10), 55)\n";
    result = layer1_replay_source(src);
    assert result.passed == 1;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "functions: reading an unassigned local raises UnboundLocalError" {
    src = "class TestUnboundLocal(unittest.TestCase):\n"
    "    def test_unbound(self):\n"
    "        def f():\n"
    "            return y\n"
    "        with self.assertRaises(UnboundLocalError):\n"
    "            f()\n";
    result = layer1_replay_source(src);
    assert result.passed == 1;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "lambdas: call semantics, star args, closure capture" {
    src = "class TestLambda(unittest.TestCase):\n"
    "    def test_basic_and_star(self):\n"
    "        self.assertEqual((lambda x: x+1)(4), 5)\n"
    "        l = lambda *a, **k: (a, k)\n"
    "        self.assertEqual(l(1, b=2), ((1,), {'b': 2}))\n"
    "    def test_closure_capture(self):\n"
    "        n = 7\n"
    "        f = lambda: n\n"
    "        self.assertEqual(f(), 7)\n";
    result = layer1_replay_source(src);
    assert result.passed == 2;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

# ---------------- decorators (direct ceval: see file header) ----------------

test "decorators: stacked function decorators apply bottom-up" {
    ns = vm_exec(
        "log = []\n"
        "\n"
        "def a(f):\n"
        "    log.append('a:' + f.__name__)\n"
        "    return f\n"
        "\n"
        "def b(f):\n"
        "    log.append('b:' + f.__name__)\n"
        "    return f\n"
        "\n"
        "@a\n"
        "@b\n"
        "def foo():\n"
        "    return 42\n"
        "\n"
        "out = '|'.join(log) + ':' + str(foo())\n"
    );
    assert vm_str(ns, "out") == "b:foo|a:foo:42";
}

test "decorators: argful factory binds its arguments onto the function" {
    # Mirrors CPython test_decorators.py::test_argforms/test_dotted.
    ns = vm_exec(
        "def attrs(**kw):\n"
        "    def deco(fn):\n"
        "        for k in kw:\n"
        "            setattr(fn, k, kw[k])\n"
        "        return fn\n"
        "    return deco\n"
        "\n"
        "@attrs(a=1, xyz='haha')\n"
        "def f():\n"
        "    return 42\n"
        "\n"
        "out = str(f()) + ':' + str(f.a) + ':' + f.xyz\n"
    );
    assert vm_str(ns, "out") == "42:1:haha";
}

test "decorators: name rebinds to the decorator's return value" {
    # Mirrors CPython test_decorators.py::test_order's replacement semantics.
    ns = vm_exec(
        "def callnum(num):\n"
        "    def deco(func):\n"
        "        return lambda: num\n"
        "    return deco\n"
        "\n"
        "@callnum(2)\n"
        "@callnum(1)\n"
        "def foo():\n"
        "    return 42\n"
        "\n"
        "out = foo()\n"
    );
    assert to_host(ns["out"]) == 2;
}
