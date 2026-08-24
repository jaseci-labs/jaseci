# Converted CPython protocol-suite coverage: differential replay pins.
#
# Source corpus: reference/cpython/Lib/test/{test_operator,test_index,
# test_contains,test_named_expressions}.py -- behavioral assertions only
# (unittest scaffolding, import_fresh_module dual-module machinery,
# pickling/signature/docstring introspection, and NEVER_EQ/support shims
# re-expressed locally).
#
# Mechanism (test_conv_numeric.jac idiom, unchanged):
# each case is a (setup, expr) pair. The wrapper
#     <setup>
#     try:
#         r = (<expr>)
#     except BaseException as e:
#         r = type(e).__name__ + ': ' + str(e)
# is compiled by the host-oracle CPython (JACPYTHON_CPYTHON-pinned 3.14 via
# host_compile_marshal), then `r` is computed TWICE -- once by jacpython's
# ceval (exec_code over the unmarshaled PyCode) and once by a batched eval
# under the same pinned host interpreter -- and the two outcome strings
# (repr of the value, or "Type: message") must match byte-exact.
#
# Scope note: behaviors that currently diverge between ceval and the pinned
# host are NOT pinned here (they would fail byte-exact comparison); they are
# documented as findings in ~/notes/lane-m-conv-protocols.md with exact
# repros. Divergence clusters excluded from this file: the operator-module
# shims for truth/attrgetter/methodcaller/iadd-family/length_hint,
# containment fallback to __getitem__-iteration, and __index__ consumption
# by hex/oct/bin, str repeat, slice-with-index-objects, and slice.indices.

import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, to_host }
import from objects { PyObj, PyStr, PyError, is_error }

import os;
import shutil;
import subprocess;
import json;

# Host side of the differential: read a JSON array of wrapped sources, exec
# each, print a JSON array of outcome strings. Mirrors _vm_outcome exactly.
glob _HOST_DRIVER = (
    "import sys, json\n"
    "out = []\n"
    "for s in json.loads(sys.stdin.read()):\n"
    "    ns = {'__name__': '__main__'}\n"
    "    try:\n"
    "        exec(compile(s, '<conv>', 'exec'), ns)\n"
    "        res = repr(ns.get('r'))\n"
    "    except BaseException as e:\n"
    "        res = type(e).__name__ + ': ' + str(e)\n"
    "    out.append(res)\n"
    "print(json.dumps(out))\n"
);

def _cpython_exe() -> str {
    env = os.environ.get("JACPYTHON_CPYTHON");
    if env {
        return env;
    }
    found = shutil.which("python3.14");
    if found {
        return found;
    }
    return "python3";
}

def _wrap(setup: str, expr: str) -> str {
    return setup + "\ntry:\n    r = (" + expr + ")\n"
        + "except BaseException as e:\n"
        + "    r = type(e).__name__ + ': ' + str(e)\n";
}

def _vm_outcome(src: str) -> str {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<conv_protocols>", "exec")), [], ns
    );
    if is_error(outcome) {
        exc = (outcome as PyError).exception;
        return exc.type_name + ": " + exc.message;
    }
    return repr(to_host(ns["r"]));
}

def _host_outcomes(srcs: list[str]) -> list[str] {
    proc = subprocess.run(
        [_cpython_exe(), "-c", _HOST_DRIVER],
        input=json.dumps(srcs), capture_output=True, text=True, check=True
    );
    return json.loads(proc.stdout);
}

# Differential core: every (setup, expr) pair must produce the identical
# outcome string on ceval and on the pinned host CPython.
def diff_cases(cases: list[list[str]]) {
    srcs: list[str] = [];
    for c in cases {
        srcs.append(_wrap(c[0], c[1]));
    }
    host = _host_outcomes(srcs);
    assert len(host) == len(cases), "host driver lost cases";
    i = 0;
    while i < len(cases) {
        got = _vm_outcome(srcs[i]);
        assert got == host[i],
            "case: " + cases[i][1] + "\n  vm   = " + got + "\n  host = "
            + host[i];
        i = i + 1;
    }
}

# ---- stem: test_operator.py -------------------------------------------------

glob _OP_SETUP = "import operator\n";

test "conv/operator: comparison function truth tables and arity errors" {
    diff_cases([
        [_OP_SETUP, "operator.lt(1, 2)"],
        [_OP_SETUP, "operator.lt(1, 0)"],
        [_OP_SETUP, "repr(operator.lt(1, 0.0))"],
        [_OP_SETUP, "repr(operator.lt(1, 1.0))"],
        [_OP_SETUP, "operator.le(1, 1)"],
        [_OP_SETUP, "repr(operator.le(1, 1.0))"],
        [_OP_SETUP, "repr(operator.eq(1, 1.0))"],
        [_OP_SETUP, "repr(operator.eq(1, 2))"],
        [_OP_SETUP, "repr(operator.ne(1, 1.0))"],
        [_OP_SETUP, "repr(operator.ge(1, 2.0))"],
        [_OP_SETUP, "repr(operator.gt(1, 0))"],
        [_OP_SETUP, "repr(operator.gt(1, 1.0))"],
        [_OP_SETUP, "operator.lt()"],
        [_OP_SETUP, "operator.gt(1)"],
        [_OP_SETUP, "operator.lt(1j, 2j)"],
        [_OP_SETUP, "repr(operator.eq(None, None))"],
    ]);
}

test "conv/operator: truth/not_/is family on plain values" {
    diff_cases([
        [_OP_SETUP, "repr(operator.truth(5))"],
        [_OP_SETUP, "repr(operator.truth([0]))"],
        [_OP_SETUP, "repr(operator.truth(0))"],
        [_OP_SETUP, "repr(operator.truth([]))"],
        [_OP_SETUP, "repr(operator.not_(5))"],
        [_OP_SETUP, "repr(operator.not_([]))"],
        [_OP_SETUP + "a = b = 'xyzpdq'\nc = a[:3] + b[3:]\n", "(operator.is_(a, b), operator.is_(a, c))"],
        [_OP_SETUP + "a = b = 'xyzpdq'\nc = a[:3] + b[3:]\n", "(operator.is_not(a, b), operator.is_not(a, c))"],
        [_OP_SETUP, "operator.is_()"],
        [_OP_SETUP, "(operator.is_none('xyzpdq'), operator.is_none(''), operator.is_none(None))"],
        [_OP_SETUP, "(operator.is_not_none('xyzpdq'), operator.is_not_none(''), operator.is_not_none(None))"],
        [_OP_SETUP, "operator.is_none()"],
    ]);
}

test "conv/operator: arithmetic/bitwise/unary functions and arity errors" {
    diff_cases([
        [_OP_SETUP, "operator.abs(-1)"],
        [_OP_SETUP, "operator.abs(None)"],
        [_OP_SETUP, "operator.add(3, 4)"],
        [_OP_SETUP, "operator.add(None, None)"],
        [_OP_SETUP, "operator.sub(5, 2)"],
        [_OP_SETUP, "operator.mul(5, 2)"],
        [_OP_SETUP, "operator.truediv(5, 2)"],
        [_OP_SETUP, "operator.floordiv(5, 2)"],
        [_OP_SETUP, "operator.floordiv(5)"],
        [_OP_SETUP, "operator.mod(5, 2)"],
        [_OP_SETUP, "operator.mod(None, 42)"],
        [_OP_SETUP, "operator.pow(3, 5)"],
        [_OP_SETUP, "operator.pow(1)"],
        [_OP_SETUP, "operator.pow(1, 2, 3)"],
        [_OP_SETUP, "operator.lshift(5, 1)"],
        [_OP_SETUP, "operator.lshift(5, 0)"],
        [_OP_SETUP, "operator.lshift(2, -1)"],
        [_OP_SETUP, "operator.rshift(5, 1)"],
        [_OP_SETUP, "operator.rshift(2, -1)"],
        [_OP_SETUP, "operator.invert(4)"],
        [_OP_SETUP, "operator.inv(4)"],
        [_OP_SETUP, "operator.invert(None)"],
        [_OP_SETUP, "(operator.neg(5), operator.neg(-5), operator.neg(0))"],
        [_OP_SETUP, "operator.neg(None)"],
        [_OP_SETUP, "(operator.pos(5), operator.pos(-5), operator.pos(0))"],
        [_OP_SETUP, "operator.pos(None)"],
        [_OP_SETUP, "hex(operator.and_(0xf, 0xa))"],
        [_OP_SETUP, "hex(operator.or_(0xa, 0x5))"],
        [_OP_SETUP, "hex(operator.xor(0xb, 0xc))"],
        [_OP_SETUP, "operator.and_(None, None)"],
    ]);
}

test "conv/operator: builtin sequence functions (concat/getitem/delitem/setitem)" {
    diff_cases([
        [_OP_SETUP, "operator.concat('py', 'thon')"],
        [_OP_SETUP, "operator.concat([1, 2], [3, 4])"],
        [_OP_SETUP, "operator.concat(13, 29)"],
        [_OP_SETUP, "operator.concat(None, None)"],
        [_OP_SETUP, "operator.getitem(range(10), 2)"],
        [_OP_SETUP, "operator.getitem(range(10), None)"],
                [_OP_SETUP + "a = [4, 3, 2, 1]\n", "operator.delitem(a)"],
        [_OP_SETUP + "a = [4, 3, 2, 1]\n", "operator.delitem(a, None)"],
                        [_OP_SETUP + "a = list(range(3))\n", "operator.setitem(a, 4, 2)"],
        [_OP_SETUP + "a = list(range(3))\n", "operator.setitem(a)"],
        [_OP_SETUP, "[5, 6] * 2"],
        [_OP_SETUP, "'ab' * 3"],
    ]);
}

test "conv/operator: countOf/indexOf/contains over builtins" {
    diff_cases([
        [_OP_SETUP + "nan = float('nan')\n", "operator.countOf([nan, nan, 21], nan)"],
        [_OP_SETUP, "operator.countOf([{1: 0}, 1, {1: 0}, 2], {1: 0})"],
        [_OP_SETUP, "operator.countOf([1, 2, 1, 3, 1, 4], 5)"],
        [_OP_SETUP, "operator.countOf(None, None)"],
        [_OP_SETUP + "nan = float('nan')\n", "operator.indexOf([nan, nan, 21], nan)"],
        [_OP_SETUP, "operator.indexOf([{1: 0}, 1, {1: 0}, 2], {1: 0})"],
        [_OP_SETUP, "operator.indexOf([4, 3, 2, 1], 0)"],
        [_OP_SETUP + "it = iter('leave the iterator at exactly the position after the match')\n", "(operator.indexOf(it, 'a'), next(it))"],
        [_OP_SETUP, "operator.indexOf(None, None)"],
        [_OP_SETUP, "repr(operator.contains(range(4), 2))"],
        [_OP_SETUP, "repr(operator.contains(range(4), 5))"],
        [_OP_SETUP, "operator.contains(None, None)"],
    ]);
}

test "conv/operator: itemgetter (ints, keys, slices, multi, error paths)" {
    diff_cases([
        [_OP_SETUP, "operator.itemgetter(2)('ABCDE')"],
        [_OP_SETUP + "f = operator.itemgetter(2)\n", "(f(), f('ABCDE', 3))"],
        [_OP_SETUP, "operator.itemgetter(10)('ABCDE')"],
        [_OP_SETUP, "operator.itemgetter('key')({'key': 'val'})"],
        [_OP_SETUP, "operator.itemgetter('name')('ABCDE')"],
        [_OP_SETUP + "data = list(map(str, range(20)))\n", "operator.itemgetter(2, 10, 5)(data)"],
        [_OP_SETUP, "operator.itemgetter(-1)(tuple('abcde'))"],
        [_OP_SETUP, "operator.itemgetter(slice(2, 4))(tuple('abcde'))"],
        [_OP_SETUP, "operator.itemgetter(0)(range(100, 200))"],
        [_OP_SETUP + "inventory = [('apple', 3), ('banana', 2), ('pear', 5), ('orange', 1)]\n", "sorted(inventory, key=operator.itemgetter(1))"],
        [_OP_SETUP, "operator.itemgetter()"],
    ]);
}

test "conv/operator: iconcat text and call()" {
    diff_cases([
        [_OP_SETUP, "operator.iconcat(1, 0.5)"],
        [_OP_SETUP, "operator.iconcat([1], [2])"],
        [_OP_SETUP + "def func(*args, **kwargs):\n    return args, kwargs\n", "(operator.call(func), operator.call(func, 0, 1))"],
        [_OP_SETUP, "operator.length_hint([], 2)"],
    ]);
}

# ---- stem: test_index.py ----------------------------------------------------

glob _IDX_SETUP = (
    "import operator\n"
    "class newstyle:\n"
    "    def __index__(self):\n"
    "        return self.ind\n"
);

test "conv/index: operator.index basics, wrappers, subclass override" {
    diff_cases([
        ["import operator\n", "(operator.index(0), operator.index(1), operator.index(True), operator.index(False))"],
        [_IDX_SETUP, "(6 .__index__(), -7 .__index__(), True.__index__(), False.__index__())"],
        ["import operator\n", "(2**100).__index__()"],
        [
            _IDX_SETUP +
            "class MyInt(int):\n"
            "    def __index__(self):\n"
            "        return int(str(self)) + 1\n"
            "my_int = MyInt(7)\n",
            "(my_int.__index__(), operator.index(my_int))"
        ],
        [_IDX_SETUP, "operator.index(1.5)"],
        [_IDX_SETUP, "operator.index(None)"],
    ]);
}

test "conv/index: __index__ in getitem, repeat, range" {
    diff_cases([
        [_IDX_SETUP + "seq = [0, 10, 20, 30, 40, 50]\no = newstyle()\no.ind = -2\nn = newstyle()\nn.ind = 2\n", "(seq[n], seq[o])"],
        [_IDX_SETUP + "seq = 'this is a test'\nn = newstyle()\nn.ind = 2\n", "seq[n]"],
        [_IDX_SETUP + "lst = [6, 4]\no = newstyle()\no.ind = 2\nn = newstyle()\nn.ind = 3\nlst *= o\nlst *= n\n", "lst"],
        [_IDX_SETUP + "n = newstyle()\nn.ind = 5\n", "range(1, 20)[n]"],
    ]);
}

test "conv/index: overflow and large-index semantics" {
    diff_cases([
        [_IDX_SETUP + "pos = 2**100\nneg = -pos\n", "(pos.__index__() == pos, neg.__index__() == neg)"],
        [_IDX_SETUP, "'a' * 2**100"],
        [_IDX_SETUP, "'a' * -(2**100)"],
        [_IDX_SETUP, "b'ab' * 2**64"],
        [
            _IDX_SETUP +
            "class GetItem:\n"
            "    def __len__(self):\n"
            "        raise AssertionError('__len__ should not be invoked')\n"
            "    def __getitem__(self, key):\n"
            "        return key\n"
            "pos = 2**100\nneg = -pos\ng = GetItem()\n",
            "(g[pos], g[neg])"
        ],
        [_IDX_SETUP, "(slice(-(2**100), 2**100).indices(2**63 - 1), slice(-(2**100), 2**100, 1).indices(2**63 - 1))"],
    ]);
}

# ---- stem: test_contains.py -------------------------------------------------

glob _CONT_SETUP = (
    "class base_set:\n"
    "    def __init__(self, el):\n"
    "        self.el = el\n"
    "class myset(base_set):\n"
    "    def __contains__(self, el):\n"
    "        return self.el == el\n"
);

test "conv/contains: custom __contains__ and builtin containers" {
    diff_cases([
        [_CONT_SETUP, "(1 in myset(1), 0 in myset(1))"],
        [_CONT_SETUP, "repr(0 in myset(1))"],
        [_CONT_SETUP, "repr('c' in 'abc')"],
        [_CONT_SETUP, "repr('d' in 'abc')"],
        [_CONT_SETUP, "('' in '', '' in 'abc')"],
        [_CONT_SETUP, "None in 'abc'"],
        [_CONT_SETUP, "repr(1 in [1, 2])"],
        [_CONT_SETUP, "repr(3 in {1: 'a'})"],
        [_CONT_SETUP, "repr(1 in range(10))"],
        [_CONT_SETUP, "repr('a' in b'abc')"],
        [_CONT_SETUP, "repr(b'a' in b'abc')"],
    ]);
}

test "conv/contains: self-membership and nonreflexive elements" {
    diff_cases([
        [_CONT_SETUP + "a = range(10)\n", "(repr(all(i in a for i in a)), repr(16 in a), repr(a in a))"],
        [_CONT_SETUP + "a = tuple(range(10))\n", "(repr(all(i in a for i in a)), repr(16 in a), repr(a in a))"],
        [_CONT_SETUP + "v = [float('nan'), 1, None, 'abc']\n", "repr(float('nan') in v)"],
        [
            _CONT_SETUP + "values = ['abc', 1, None]\nc = list(values)\neq = c == list(values)\n",
            "(repr(all(e in c for e in c)), eq)"
        ],
        [
            _CONT_SETUP + "values = ['abc', 1, None]\nc = tuple(values)\neq = c == tuple(values)\n",
            "(repr(all(e in c for e in c)), eq)"
        ],
        [
            _CONT_SETUP + "values = ['abc', 1, None]\nc = dict.fromkeys(values)\n",
            "repr(all(e in c for e in c))"
        ],
        [
            _CONT_SETUP + "values = ['abc', 1, None]\nc = set(values)\neq = c == set(values)\n",
            "(repr(all(e in c for e in c)), eq)"
        ],
        [
            _CONT_SETUP + "values = ['abc', 1, None]\nc = frozenset(values)\neq = c == frozenset(values)\n",
            "(repr(all(e in c for e in c)), eq)"
        ],
    ]);
}

# ---- stem: test_named_expressions.py ----------------------------------------

test "conv/namedexpr: assignment-expression basics (chained, tuples, conditions)" {
    diff_cases([
        ["", "a := 10"],
        ["(a := 10)\n", "a"],
        ["a = 20\n(a := a)\n", "a"],
        ["(total := 1 + 2)\n", "total"],
        ["(info := (1, 2, 3))\n", "info"],
        ["(x := 1, 2)\n", "x"],
        ["(z := (y := (x := 0)))\n", "(x, y, z)"],
        ["if spam := 'eggs':\n    out = spam\nelse:\n    out = None\n", "out"],
        ["if True and (spam := True):\n    out = spam\nelse:\n    out = None\n", "out"],
        ["if (match := 10) == 10:\n    out = match\nelse:\n    out = None\n", "out"],
        ["while a := False:\n    break\n", "a"],
        [
            "a = 9\nn = 2\nx = 3\nwhile a > (d := x // a**(n-1)):\n    a = ((n-1)*a + d) // n\n",
            "a"
        ],
        [
            "a = [1]\nelement = a[b := 0]\n",
            "(b, element)"
        ],
    ]);
}

test "conv/namedexpr: fib-dict comprehension and comprehension leakage" {
    diff_cases([
        [
            "a, b = 1, 2\nfib = {(c := a): (a := b) + (b := a + c) - b for __ in range(6)}\n",
            "fib"
        ],
        [
            "total = 0\npartial_sums = [total := total + v for v in range(5)]\n",
            "(partial_sums, total)"
        ],
        [
            "containsOne = any((lastNum := num) == 1 for num in [1, 2, 3])\n",
            "(containsOne, lastNum)"
        ],
        [
            "res = [[spam := i for i in range(3)] for j in range(2)]\n",
            "(res, spam)"
        ],
        [
            "b = 0\nres = [b := i + b for i in range(5)]\n",
            "(res, b)"
        ],
        [
            "res = [j := i for i in range(5)]\n",
            "(res, j)"
        ],
        [
            "res = [b := [a := 1 for i in range(2)] for j in range(2)]\n",
            "(res, a, b)"
        ],
        [
            "def spam(a):\n    return a\ninput_data = [1, 2, 3]\nres = [(x, y, x/y) for x in input_data if (y := spam(x)) > 0]\n",
            "(res, y)"
        ],
        [
            "def spam(a):\n    return a\nres = [[y := spam(x), x/y] for x in range(1, 5)]\n",
            "(res, y)"
        ],
    ]);
}

test "conv/namedexpr: walrus through call arguments (positional/keyword)" {
    diff_cases([
        [
            "def spam(a):\n    return a\nres = spam(b := 2)\n",
            "(res, b)"
        ],
        [
            "def spam(a):\n    return a\nres = spam((b := 2))\n",
            "(res, b)"
        ],
        [
            "def spam(a):\n    return a\nres = spam(a=(b := 2))\n",
            "(res, b)"
        ],
        [
            "def spam(a, b):\n    return a + b\nres = spam(c := 2, b=1)\n",
            "(res, c)"
        ],
        [
            "def spam(a, b):\n    return a + b\nres = spam((c := 2), b=1)\n",
            "(res, c)"
        ],
        [
            "def spam(a, b):\n    return a + b\nres = spam(b=(c := 2), a=1)\n",
            "(res, c)"
        ],
        [
            "def spam(a):\n    return a\ndef eggs(b):\n    return b * 2\nres = [spam(a := eggs(b := h)) for h in range(2)]\n",
            "(res, a, b)"
        ],
        [
            "def spam(a):\n    return a\ndef eggs(b):\n    return b * 2\nres = [spam(a := eggs(a := h)) for h in range(2)]\n",
            "(res, a)"
        ],
        [
            "length = len(lines := [1, 2])\n",
            "(length, lines)"
        ],
    ]);
}

test "conv/namedexpr: rebinding names around comprehensions (global/nonlocal)" {
    diff_cases([
        ["x = 1\nresult = [x := i for i in range(3) if (x := i) or not x]\n", "(result, x)"],
        ["result, x = (lambda x=1: ([x := i for i in range(3) if (x := i) or not x], x))()\n", "(result, x)"],
        ["x = 1\nresult = [x := i for i in range(3) if x or not x]\n", "(result, x)"],
        ["result, x = (lambda x=1: ([x := i for i in range(3) if x or not x], x))()\n", "(result, x)"],
        ["x = 1\nresult = [x for i in range(3) if (x := i) or not x]\n", "(result, x)"],
        ["result, x = (lambda x=1: ([x for i in range(3) if (x := i) or not x], x))()\n", "(result, x)"],
        ["x = 1\nresult = [j for i in range(3) if x or not x for j in range(3) if (x := i)][:-3]\n", "(result, x)"],
        ["result, x = (lambda x=1: ([j for i in range(3) if x or not x for j in range(3) if (x := i)][:-3], x))()\n", "(result, x)"],
        [
            "g = None\n"
            "sentinel = object()\n"
            "def f():\n"
            "    global g\n"
            "    [g := sentinel for _ in range(1)]\n"
            "f()\n",
            "g is sentinel"
        ],
        [
            "g = None\n"
            "sentinel = object()\n"
            "def f():\n"
            "    g_local = None\n"
            "    [g_local := sentinel for _ in range(1)]\n"
            "    return g_local\n"
            "r = f()\n",
            "(type(r).__name__, g)"
        ],
        [
            "sentinel = object()\n"
            "def f():\n"
            "    nv = None\n"
            "    def gg():\n"
            "        nonlocal nv\n"
            "        [nv := sentinel for _ in range(1)]\n"
            "    gg()\n"
            "    return nv\n"
            "r = f()\n",
            "type(r).__name__"
        ],
        [
            "sentinel = object()\n"
            "def f():\n"
            "    nv = None\n"
            "    def gg():\n"
            "        [nv := sentinel for _ in range(1)]\n"
            "        return nv\n"
            "    return (gg(), nv)\n"
            "r = f()\n",
            "(type(r[0]).__name__, r[1])"
        ],
        [
            "a = 1\nb = [1, 2, 3, 4]\nit = iter((c := i + a for i in b))\nr = [next(it) for _ in range(4)]\n",
            "(r, c)"
        ],
        [
            "def spam():\n    (a := 5)\nspam()\n",
            "a"
        ],
    ]);
}
