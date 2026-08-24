# Zero-arg super() over BUILTIN-SUBCLASS bases -- differential pins vs CPython.
#
# Lane scope: edge cases of zero-arg super() beyond the plain user-class chain
# covered by test_class_cell.jac. Every expected string below was recorded from
# the host interpreter (python3) BEFORE being pinned here.
#
# Covers:
#   - methods of classes whose bases are builtin types (dict/list/str/tuple/
#     Exception) calling super().<m>() including dunder delegation through
#     PyBuiltinSuperMethod onto the boxed base value
#   - multi-level chains that mix user classes over a builtin root
#     (dict -> D -> E, Exception -> A -> B)
#   - zero-arg super() outside __init__: arbitrary methods, classmethods,
#     property getters
#   - super() inside nested defs (closures) within methods -- the inner frame
#     derefs the same live __class__ cell
#   - error shapes: bare super() at module/function scope, missing attribute
#     above a base-less class

import from objects { PyObj, PyCode, PyError, is_error }
import from product_compile { compile_source }
import from pyc_first { exec_code, to_host }


def run_src(src: str) -> str {
    # Native compile + VM execute; repr of module global `r`, or
    # "Type: message" when the VM raised.
    co = compile_source(src, "<super-builtin>", "exec", 0);
    if is_error(co) {
        e = co as PyError;
        return "CompileError: " + str(e.exception.message);
    }
    ns: dict[str, PyObj] = {};
    outcome = exec_code(co as PyCode, [], ns);
    if is_error(outcome) {
        e2 = outcome as PyError;
        return str(e2.exception.type_name) + ": " + str(e2.exception.message);
    }
    if "r" in ns {
        return repr(to_host(ns["r"]));
    }
    return "";
}

# ---- builtin-base method overrides ----

test "super().get on a dict subclass override" {
    assert run_src(
        "class D(dict):\n"
        + "    def get(self, k):\n"
        + "        return 'got:' + str(super().get(k))\n"
        + "r = D(a=1).get('a')\n"
    ) == "'got:1'";
}

test "super().__setitem__ on a dict subclass mutates the boxed base" {
    assert run_src(
        "class D(dict):\n"
        + "    def __setitem__(self, k, v):\n"
        + "        super().__setitem__(k, v * 2)\n"
        + "d = D()\n"
        + "d['x'] = 21\n"
        + "r = d['x']\n"
    ) == "42";
}

test "super().append on a list subclass mutates the boxed base" {
    assert run_src(
        "class L(list):\n"
        + "    def append(self, x):\n"
        + "        super().append(x * 10)\n"
        + "l = L()\n"
        + "l.append(3)\n"
        + "l.append(4)\n"
        + "r = l\n"
    ) == "[30, 40]";
}

test "super().upper() inside a str subclass method" {
    assert run_src(
        "class S(str):\n"
        + "    def loud(self):\n"
        + "        return super().upper() + '!'\n"
        + "r = S('abc').loud()\n"
    ) == "'ABC!'";
}

test "super().__getitem__ on a list subclass" {
    assert run_src(
        "class L(list):\n"
        + "    def __getitem__(self, i):\n"
        + "        return ('wrapped', super().__getitem__(i))\n"
        + "r = L([1, 2])[1]\n"
    ) == "('wrapped', 2)";
}

test "super().__getitem__ on a str subclass" {
    assert run_src(
        "class S(str):\n"
        + "    def __getitem__(self, i):\n"
        + "        return ('S', super().__getitem__(i))\n"
        + "r = S('abc')[0]\n"
    ) == "('S', 'a')";
}

test "super().__contains__ on a dict subclass extends membership" {
    assert run_src(
        "class D(dict):\n"
        + "    def __contains__(self, k):\n"
        + "        return super().__contains__(k) or k == '*'\n"
        + "d = D(a=1)\n"
        + "r = [('a' in d), ('*' in d), ('z' in d)]\n"
    ) == "[True, True, False]";
}

test "super().__len__ on a tuple subclass (immutable base)" {
    assert run_src(
        "class T(tuple):\n"
        + "    def double_len(self):\n"
        + "        return super().__len__() * 2\n"
        + "r = T([1, 2, 3]).double_len()\n"
    ) == "6";
}

test "super().keys() iteration on a dict subclass" {
    assert run_src(
        "class D(dict):\n"
        + "    def keys_upper(self):\n"
        + "        return sorted(super().keys())\n"
        + "r = D(b=1, a=2).keys_upper()\n"
    ) == "['a', 'b']";
}

# ---- __init__ delegation ----

test "super().__init__(kw) in a dict subclass __init__" {
    assert run_src(
        "class D(dict):\n"
        + "    def __init__(self, **kw):\n"
        + "        super().__init__(kw)\n"
        + "        self.tag = 'T'\n"
        + "d = D(a=1)\n"
        + "r = [d.get('a'), d.tag]\n"
    ) == "[1, 'T']";
}

test "super().__init__(it) in a list subclass __init__" {
    assert run_src(
        "class L(list):\n"
        + "    def __init__(self, it):\n"
        + "        super().__init__(it)\n"
        + "        self.marked = True\n"
        + "l = L([1, 2])\n"
        + "r = [list(l), l.marked]\n"
    ) == "[[1, 2], True]";
}

test "super().__init__(msg) in an Exception subclass __init__" {
    assert run_src(
        "class MyErr(Exception):\n"
        + "    def __init__(self, msg):\n"
        + "        super().__init__(msg)\n"
        + "        self.extra = 'x'\n"
        + "r = ''\n"
        + "try:\n"
        + "    raise MyErr('bad')\n"
        + "except MyErr as e:\n"
        + "    r = [e.args[0], e.extra]\n"
    ) == "['bad', 'x']";
}

# ---- multi-level chains over a builtin root ----

test "two-level user chain rooted at dict" {
    assert run_src(
        "class D(dict):\n"
        + "    def get(self, k):\n"
        + "        return ['D', super().get(k)]\n"
        + "class E(D):\n"
        + "    def get(self, k):\n"
        + "        return ['E', super().get(k)]\n"
        + "r = E(a=5).get('a')\n"
    ) == "['E', ['D', 5]]";
}

test "two-level user chain rooted at Exception walks super().args" {
    assert run_src(
        "class A(Exception):\n"
        + "    def msg(self):\n"
        + "        return 'A:' + str(super().args)\n"
        + "class B(A):\n"
        + "    def msg(self):\n"
        + "        return 'B<' + super().msg()\n"
        + "try:\n"
        + "    raise B('x')\n"
        + "except B as e:\n"
        + "    r = e.msg()\n"
    ) == "\"B<A:('x',)\"";
}

# ---- zero-arg super() outside __init__ ----

test "zero-arg super() in a plain method using super().__len__" {
    assert run_src(
        "class D(dict):\n"
        + "    def size(self):\n"
        + "        return len(self) + super().__len__()\n"
        + "r = D(x=1, y=2).size()\n"
    ) == "4";
}

test "classmethod zero-arg super() chain over a dict base" {
    assert run_src(
        "class B(dict):\n"
        + "    @classmethod\n"
        + "    def tag(cls):\n"
        + "        return 'B:' + cls.__name__\n"
        + "class D(B):\n"
        + "    @classmethod\n"
        + "    def tag(cls):\n"
        + "        return 'D>' + super().tag()\n"
        + "r = D.tag()\n"
    ) == "'D>B:D'";
}

test "property getter zero-arg super() over a dict-subclass base" {
    assert run_src(
        "class D(dict):\n"
        + "    @property\n"
        + "    def size2(self):\n"
        + "        return len(self)\n"
        + "class E(D):\n"
        + "    @property\n"
        + "    def size2(self):\n"
        + "        return 'E:' + str(super().size2)\n"
        + "r = E(a=1, b=2).size2\n"
    ) == "'E:2'";
}

test "Exception subclass reading super().args outside __init__" {
    assert run_src(
        "class MyErr(ValueError):\n"
        + "    def describe(self):\n"
        + "        return str(super().args) + '/' + type(self).__name__\n"
        + "try:\n"
        + "    raise MyErr('boom', 42)\n"
        + "except MyErr as e:\n"
        + "    r = e.describe()\n"
    ) == "\"('boom', 42)/MyErr\"";
}

# ---- closures / nested defs sharing the __class__ cell ----

test "nested def inside a method derefs the same __class__ cell" {
    assert run_src(
        "class A:\n"
        + "    def who(self):\n"
        + "        return 'A'\n"
        + "class B(A):\n"
        + "    def who(self):\n"
        + "        def inner(self):\n"
        + "            return super().who()\n"
        + "        return 'B+' + inner(self)\n"
        + "r = B().who()\n"
    ) == "'B+A'";
}

# ---- error cases ----

test "bare super() at module level raises RuntimeError" {
    assert run_src(
        "r = ''\n"
        + "try:\n"
        + "    super()\n"
        + "except RuntimeError as e:\n"
        + "    r = 'RuntimeError: ' + str(e)\n"
    ) == "'RuntimeError: super(): no arguments'";
}

test "bare super() in a module-scope function raises RuntimeError" {
    assert run_src(
        "def f():\n"
        + "    try:\n"
        + "        super()\n"
        + "    except RuntimeError as e:\n"
        + "        return 'RuntimeError: ' + str(e)\n"
        + "r = f()\n"
    ) == "'RuntimeError: super(): no arguments'";
}

test "super() in a base-less class with no ancestor attr gives AttributeError" {
    assert run_src(
        "class A:\n"
        + "    def m(self):\n"
        + "        return super().m()\n"
        + "try:\n"
        + "    A().m()\n"
        + "except AttributeError as e:\n"
        + "    r = 'AttributeError: ' + str(e)\n"
    ) == "\"AttributeError: 'super' object has no attribute 'm'\"";
}

test "super().__repr__ exists above a base-less class (object)" {
    assert run_src(
        "class A:\n"
        + "    def m(self):\n"
        + "        return super().__repr__()\n"
        + "r = ''\n"
        + "try:\n"
        + "    A().m()\n"
        + "    r = 'ok'\n"
        + "except AttributeError:\n"
        + "    r = 'AttributeError'\n"
    ) == "'ok'";
}

test "two-arg super(D, self) still resolves on a builtin base" {
    assert run_src(
        "class D(dict):\n"
        + "    def get(self, k):\n"
        + "        return super(D, self).get(k)\n"
        + "r = D(a=9).get('a')\n"
    ) == "9";
}
