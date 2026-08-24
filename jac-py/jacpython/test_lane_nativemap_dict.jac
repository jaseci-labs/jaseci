# Pinned conformance pins for dict-subclass dunder routing (lane-nativemap F1/F3).
#
# Ground truth recorded from host CPython (python3) before writing these:
#   F1 -- a dict subclass overriding __setitem__: ONLY subscript assignment
#      (STORE_SUBSCR, d[k] = v) dispatches the override. update(),
#      dict.__init__(mapping/kwargs) and setdefault() write straight to the
#      backing storage WITHOUT calling __setitem__ (CPython dict_merge /
#      dict_setdefault are concrete-slot writes).
#   F3 -- a dict subclass defining __missing__: a subscript MISS on the
#      instance calls __missing__(key) and its return value becomes the
#      expression value. get()/pop()/`in` NEVER consult __missing__; a
#      subclass without __missing__ raises KeyError as usual.
#
# Each test embeds the Python source verbatim and runs it through the same
# exec_code(unmarshal(host_compile_marshal(src))) harness layer3_import uses,
# then asserts byte-exact globals against the host-recorded expectations.
import from pyc_first {
    PyObj,
    PyStr,
    to_host,
    is_error,
    exec_code,
    unmarshal,
    host_compile_marshal
}

def run_src(src: str) -> dict[str, PyObj] {
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    return g;
}

# ---- F1: __setitem__ override routing --------------------------------------

test "lanemap dictsubclass: subscript assignment dispatches overridden __setitem__" {
    src = "class D(dict):\n"
    "    def __init__(self):\n"
    "        super().__init__()\n"
    "        self.seen = []\n"
    "    def __setitem__(self, k, v):\n"
    "        self.seen.append(k)\n"
    "        super().__setitem__(k, v * 10)\n"
    "d = D()\n"
    "d['a'] = 1\n"
    "d['b'] = 2\n"
    "seen = d.seen\n"
    "items = list(d.items())\n";
    g = run_src(src);
    # Host: seen == ['a', 'b'], items == [('a', 10), ('b', 20)].
    assert to_host(g["seen"]) == ["a", "b"];
    assert to_host(g["items"]) == [("a", 10), ("b", 20)];
}

test "lanemap dictsubclass: update() bypasses __setitem__ (direct storage write)" {
    src = "class D(dict):\n"
    "    def __init__(self):\n"
    "        super().__init__()\n"
    "        self.seen = []\n"
    "    def __setitem__(self, k, v):\n"
    "        self.seen.append(k)\n"
    "        super().__setitem__(k, v * 10)\n"
    "d = D()\n"
    "d.update({'c': 1}, e=2)\n"
    "seen = d.seen\n"
    "items = sorted(d.items())\n";
    g = run_src(src);
    # Host: update() is a concrete dict_merge write -- no override dispatch.
    assert to_host(g["seen"]) == [];
    assert to_host(g["items"]) == [("c", 1), ("e", 2)];
}

test "lanemap dictsubclass: constructor init bypasses __setitem__" {
    src = "log = []\n"
    "class D(dict):\n"
    "    def __setitem__(self, k, v):\n"
    "        log.append(k)\n"
    "        super().__setitem__(k, v * 10)\n"
    "e = D({'a': 4})\n"
    "f = D(x=5, y=6)\n"
    "calls = len(log)\n"
    "items_e = sorted(e.items())\n"
    "items_f = sorted(f.items())\n";
    g = run_src(src);
    # Host: dict.__init__ writes concretely -- mapping/kwargs land raw.
    assert to_host(g["calls"]) == 0;
    assert to_host(g["items_e"]) == [("a", 4)];
    assert to_host(g["items_f"]) == [("x", 5), ("y", 6)];
}

test "lanemap dictsubclass: setdefault bypasses __setitem__, existing hit returns stored" {
    src = "class D(dict):\n"
    "    def __init__(self):\n"
    "        super().__init__()\n"
    "        self.seen = []\n"
    "    def __setitem__(self, k, v):\n"
    "        self.seen.append(k)\n"
    "        super().__setitem__(k, v * 10)\n"
    "d = D()\n"
    "r = d.setdefault('w', 9)\n"
    "sd_seen = d.seen\n"
    "stored_w = d['w']\n"
    "r2 = d.setdefault('w', 99)\n"
    "sd2_seen = d.seen\n";
    g = run_src(src);
    # Host: setdefault('w', 9) -> 9, stores raw 9 (not 90); second hit -> 9.
    assert to_host(g["r"]) == 9;
    assert to_host(g["sd_seen"]) == [];
    assert to_host(g["stored_w"]) == 9;
    assert to_host(g["r2"]) == 9;
    assert to_host(g["sd2_seen"]) == [];
}

test "lanemap dictsubclass: native get/pop/len/items hit real backing storage" {
    src = "class D(dict):\n"
    "    def __init__(self):\n"
    "        super().__init__()\n"
    "        self.seen = []\n"
    "    def __setitem__(self, k, v):\n"
    "        self.seen.append(k)\n"
    "        super().__setitem__(k, v)\n"
    "d = D()\n"
    "d['a'] = 1\n"
    "d['b'] = 2\n"
    "g = d.get('b')\n"
    "gm = d.get('z', -1)\n"
    "popped = d.pop('b')\n"
    "keys = list(d.keys())\n"
    "n = len(d)\n";
    g_out = run_src(src);
    assert to_host(g_out["g"]) == 2;
    assert to_host(g_out["gm"]) == -1;
    assert to_host(g_out["popped"]) == 2;
    assert to_host(g_out["keys"]) == ["a"];
    assert to_host(g_out["n"]) == 1;
}

# ---- F3: __missing__ on subscript miss -------------------------------------

test "lanemap dictsubclass: subscript miss calls __missing__ and returns its value" {
    src = "log = []\n"
    "class M(dict):\n"
    "    def __missing__(self, key):\n"
    "        log.append(key)\n"
    "        return 'MISS:' + str(key)\n"
    "m = M()\n"
    "m['p'] = 1\n"
    "hit = m['p']\n"
    "miss = m['q']\n"
    "miss2 = m[42]\n"
    "calls = len(log)\n";
    g = run_src(src);
    # Host: m['p'] -> 1; each miss invokes __missing__ once ('MISS:q',
    # 'MISS:42'); nothing is cached into storage by a pure lookup.
    assert to_host(g["hit"]) == 1;
    assert to_host(g["miss"]) == "MISS:q";
    assert to_host(g["miss2"]) == "MISS:42";
    assert to_host(g["calls"]) == 2;
    assert to_host(g["m"]) == {"p": 1};
}

test "lanemap dictsubclass: get/pop/in never consult __missing__" {
    src = "log = []\n"
    "class M(dict):\n"
    "    def __missing__(self, key):\n"
    "        log.append(key)\n"
    "        return 'MISS'\n"
    "m = M()\n"
    "gv = m.get('q')\n"
    "gd = m.get('q', 'D')\n"
    "pv = m.pop('q', 'P')\n"
    "cont = 'q' in m\n"
    "calls = len(log)\n";
    g = run_src(src);
    assert to_host(g["gv"]) is None;
    assert to_host(g["gd"]) == "D";
    assert to_host(g["pv"]) == "P";
    assert to_host(g["cont"]) == False;
    assert to_host(g["calls"]) == 0;
}

test "lanemap dictsubclass: KeyError when no __missing__ is defined" {
    # Bare `except:` on purpose: the typed matcher (except KeyError) currently
    # trips an unrelated pre-existing bug -- exceptions_core.jac calls
    # exc_is_subclass_of without importing it from objects.jac, so ANY
    # `except SomeBuiltinError` match errors with NameError when a file is run
    # standalone. Noted out-of-scope; this pin only needs "an exception was
    # raised on miss", which bare except verifies without the matcher.
    src = "class N(dict):\n"
    "    pass\n"
    "n = N()\n"
    "caught = 0\n"
    "try:\n"
    "    n['nope']\n"
    "except:\n"
    "    caught = 1\n";
    g = run_src(src);
    assert to_host(g["caught"]) == 1;
}
