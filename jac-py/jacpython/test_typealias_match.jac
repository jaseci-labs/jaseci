# CALL_INTRINSIC_1(INTRINSIC_TYPEALIAS) + MATCH_CLASS match-self pins (lane B).
#
# Each fixture executes Python source on jacpython's ceval via host-compiled
# marshal and asserts CPython-oracle outcomes:
#
# - PEP 695 `type X = v`: the intrinsic builds a lazily-evaluating alias
#   object -- repr is the bare name, __name__/__type_params__ mirror CPython's
#   TypeAliasType, and __value__ runs the hidden value function exactly once,
#   on first access (never at declaration).
# - MATCH_CLASS scalar case (CPython _PyEval_MatchClass): a class whose type
#   carries _Py_TPFLAGS_MATCH_SELF (int, str, list, ...) and no __match_args__
#   binds the WHOLE subject to a single capture, rejects >1 positional
#   sub-patterns with CPython's TypeError text, silently fails keyword
#   sub-patterns, and leaves regular user-class patterns untouched.

import from host_oracle { host_compile_marshal }
import from pyc_first { exec_code, unmarshal, to_host }
import from objects { PyObj, PyStr, PyError, is_error }

# Exec `src` on ceval with fresh module globals; fails the test on raise.
def vm_exec(src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<typealias_match>", "exec")), [], ns
    );
    assert not is_error(outcome);
    return ns;
}

def vm_str(ns: dict[str, PyObj], name: str) -> str {
    return str(to_host(ns[name]));
}

def vm_bool(ns: dict[str, PyObj], name: str) -> bool {
    return to_host(ns[name]) as bool;
}

# Exec `src` and return the raised exception message ("" if none).
def vm_raise_message(src: str) -> str {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(
        unmarshal(host_compile_marshal(src, "<typealias_raise>", "exec")), [], ns
    );
    if is_error(outcome) {
        return ((outcome as PyError).exception.message);
    }
    return "";
}

# ---------------- TYPEALIAS ----------------

test "type alias evaluates lazily on first __value__ access and caches" {
    ns = vm_exec(
        "log = []\n"
        "def mk():\n"
        "    log.append('ev')\n"
        "    return 42\n"
        "type A = mk()\n"
        "untouched = log == []\n"      # nothing ran at declaration
        "first = A.__value__\n"
        "evaluated_once = log == ['ev']\n"
        "second = A.__value__\n"
        "cached = log == ['ev']\n"     # second access did not re-run mk()
    );
    assert vm_bool(ns, "untouched");
    assert to_host(ns["first"]) == 42;
    assert vm_bool(ns, "evaluated_once");
    assert to_host(ns["second"]) == 42;
    assert vm_bool(ns, "cached");
}

test "type alias repr shows the bare name and mirrors TypeAliasType attrs" {
    ns = vm_exec(
        "type MyAlias = int\n"
        "r = repr(MyAlias)\n"
        "nm = MyAlias.__name__\n"
        "same_value = MyAlias.__value__ is int\n"
        "params = MyAlias.__type_params__\n"
    );
    assert vm_str(ns, "r") == "MyAlias";
    assert vm_str(ns, "nm") == "MyAlias";
    assert vm_bool(ns, "same_value");
    assert to_host(ns["params"]) == ();
}

test "type alias value resolves names at access time through globals" {
    ns = vm_exec(
        "base = 'resolved'\n"
        "type B = base\n"
        "v1 = B.__value__\n"
        "base = 'changed'\n"
        "v2 = B.__value__\n"           # cached: still the first resolution
        "fresh = []\n"
    );
    assert vm_str(ns, "v1") == "resolved";
    assert vm_str(ns, "v2") == "resolved";
}

test "type alias errors propagate uncached from __value__" {
    msg = vm_raise_message(
        "type Bad = undefined_name\n"
        "try:\n"
        "    Bad.__value__\n"
        "except NameError:\n"
        "    pass\n"
        "Bad.__value__\n"              # re-raises on retry instead of caching ""
    );
    assert msg == "name 'undefined_name' is not defined";
}

# ---------------- MATCH_CLASS match-self ----------------

test "scalar class pattern binds the whole subject" {
    ns = vm_exec(
        "def f(x):\n"
        "    match x:\n"
        "        case int(v):\n"
        "            return ('int', v)\n"
        "    return None\n"
        "hit = f(5)\n"
        "miss = f('no')\n"
    );
    assert to_host(ns["hit"]) == ("int", 5);
    assert to_host(ns["miss"]) is None;
}

test "str scalar pattern captures the subject itself" {
    ns = vm_exec(
        "def h(x):\n"
        "    match x:\n"
        "        case str(s):\n"
        "            return s\n"
        "    return None\n"
        "got = h('hello')\n"
        "nope = h(3)\n"
    );
    assert to_host(ns["got"]) == "hello";
    assert to_host(ns["nope"]) is None;
}

test "builtin subclass instance matches the scalar base and binds wholly" {
    ns = vm_exec(
        "class MyInt(int):\n"
        "    pass\n"
        "def f(x):\n"
        "    match x:\n"
        "        case int(v):\n"
        "            return ('int', v)\n"
        "    return None\n"
        "got = f(MyInt(7))\n"
    );
    assert to_host(ns["got"]) == ("int", 7);
}

test "container builtins also match self (list, dict)" {
    ns = vm_exec(
        "def pick(x):\n"
        "    match x:\n"
        "        case list(v):\n"
        "            return ('list', v)\n"
        "        case dict(d):\n"
        "            return ('dict', d)\n"
        "    return None\n"
        "lres = pick([1, 2])\n"
        "dres = pick({'a': 1})\n"
    );
    assert to_host(ns["lres"]) == ("list", [1, 2]);
    assert to_host(ns["dres"]) == ("dict", {"a": 1});
}

test "two positional sub-patterns on a match-self class raise CPython's TypeError" {
    msg = vm_raise_message(
        "def g(x):\n"
        "    match x:\n"
        "        case int(a, b):\n"
        "            return (a, b)\n"
        "g(5)\n"
    );
    assert msg == "int() accepts 1 positional sub-pattern (2 given)";
}

test "keyword sub-pattern on a match-self class silently fails to match" {
    # int has no attribute y: the kw extraction yields None -> no match,
    # exactly like CPython's kwargs loop after the match-self shortcut.
    ns = vm_exec(
        "def g(x):\n"
        "    match x:\n"
        "        case int(y=1):\n"
        "            return 'kw'\n"
        "    return None\n"
        "got = g(5)\n"
    );
    assert to_host(ns["got"]) is None;
}

test "user classes with __match_args__ keep attribute extraction" {
    ns = vm_exec(
        "class Point:\n"
        "    __match_args__ = ('x', 'y')\n"
        "    def __init__(self, x, y):\n"
        "        self.x = x\n"
        "        self.y = y\n"
        "p = Point(3, 4)\n"
        "match p:\n"
        "    case Point(px, py):\n"
        "        got = (px, py)\n"
    );
    assert to_host(ns["got"]) == (3, 4);
}
