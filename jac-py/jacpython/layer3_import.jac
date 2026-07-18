# Layer 3 harness (jac-py/PLAN.md Layer 3 -- "real unittest boots un-proxied").
#
# The milestone that proves the interpreter is real: instead of proxying the
# import closure to the host (Layer 2's shim, or PyHostProxy), jacpython runs the
# ACTUAL CPython source of each pure-Python module as bytecode inside its own
# ceval. `import_native` (pyc_first.jac) recurses through IMPORT_NAME, pulling the
# whole dependency closure in-VM; only C-extension / built-in / frozen modules
# (no .py source) stay host-proxied. When real `unittest` boots this way and runs
# a real test file end to end, Layer 3 is met.
#
# This file drives that bottom-up: leaf modules first (proving the mechanism),
# climbing toward the unittest closure, fixing each ceval/object gap it surfaces.
import from pyc_first {
    PyObj, PyModule, PyStr, PyInt,
    import_native, set_layer3_active, clear_sys3_modules, py_attr, to_host,
    is_error, py_invoke, exec_code, unmarshal, host_compile_marshal
}
import from objects { PyError }

# Import a module natively (proxy-free where source exists) and return it.
def layer3_import(name: str) -> PyObj {
    set_layer3_active(True);
    return import_native(name);
}

def layer3_reset() -> None {
    clear_sys3_modules();
    set_layer3_active(True);
}

# Import a module and return "" on success or "Type: message" on the first error
# encountered anywhere in its closure. Used to burn down the unittest closure.
def layer3_probe(name: str) -> str {
    layer3_reset();
    mod = import_native(name);
    if is_error(mod) {
        exc = (mod as PyError).exception;
        return exc.type_name + ": " + exc.message;
    }
    if not isinstance(mod, PyModule) {
        return "not-native: got a proxy for " + name;
    }
    return "";
}

# ---------------- tests ----------------

test "layer3: a leaf pure-Python module (keyword) boots in-VM proxy-free" {
    layer3_reset();
    mod = layer3_import("keyword");
    assert not is_error(mod);
    # keyword is a native PyModule (ran in-VM), not a PyHostProxy.
    assert isinstance(mod, PyModule);
    # keyword.kwlist is the real list of Python keywords, built by its own code.
    kwlist = py_attr(mod, "kwlist");
    assert not is_error(kwlist);
    host_kwlist = to_host(kwlist);
    assert len(host_kwlist) > 30;
    assert "if" in host_kwlist;
    assert "class" in host_kwlist;
    # keyword.iskeyword('if') is True -- a real in-VM function call.
    iskeyword = py_attr(mod, "iskeyword");
    assert not is_error(iskeyword);
    yes = py_invoke(iskeyword, [PyStr(t="str", val="if")], {});
    assert to_host(yes) == True;
    no = py_invoke(iskeyword, [PyStr(t="str", val="banana")], {});
    assert to_host(no) == False;
}


test "layer3: a package (collections) and its transitive deps boot in-VM" {
    # collections is the deepest proxy-free boot in the closure: a package whose
    # __init__ subclasses builtins, builds closures (recursive_repr decorator),
    # and imports operator/reprlib/keyword -- each of which also runs in-VM. This
    # exercised the STORE_GLOBAL opcode, the merged-localsplus cell layout, native
    # getattr, and host-proxy identity. A native PyModule (not a proxy) proves it.
    layer3_reset();
    mod = import_native("collections");
    assert not is_error(mod);
    assert isinstance(mod, PyModule);
    attrs = (mod as PyModule).attrs;
    # Its own classes/functions are present, built by its own bytecode.
    assert "OrderedDict" in attrs;
    assert "defaultdict" in attrs;
    assert "namedtuple" in attrs;
    assert "deque" in attrs;
    # A transitively-imported pure-Python dependency is ALSO native, not proxied.
    op = import_native("operator");
    assert isinstance(op, PyModule);
    types_mod = import_native("types");
    assert isinstance(types_mod, PyModule);
    reprlib_mod = import_native("reprlib");
    assert isinstance(reprlib_mod, PyModule);
}

test "layer3: leaf modules across the unittest closure boot proxy-free" {
    # Each returns a native PyModule (ran its real CPython source in-VM), not a
    # host proxy -- the concrete proxy-free surface achieved so far.
    for name in ["keyword", "operator", "token", "reprlib", "types", "collections"] {
        layer3_reset();
        mod = import_native(name);
        assert not is_error(mod);
        assert isinstance(mod, PyModule);
    }
}

test "layer3: param that is also a cellvar keeps its slot (closure correctness)" {
    # Regression for the merged-localsplus cell layout: a parameter captured by an
    # inner function shares the cellvar region with sibling local-cells; the wrong
    # index math swapped them. Every decorator/closure in the closure depends on
    # this. `param` must read PRM, `local` must read LOC.
    layer3_reset();
    src = "def outer(param):\n"
    "    local = 'LOC'\n"
    "    def inner():\n"
    "        return (param, local)\n"
    "    return inner\n"
    "r = outer('PRM')()\n"
    "a = r[0]\n"
    "b = r[1]\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert to_host(g["a"]) == "PRM";
    assert to_host(g["b"]) == "LOC";
}

test "layer3: STORE_GLOBAL writes module globals from inside a function" {
    layer3_reset();
    src = "flag = 0\n"
    "def setflag():\n"
    "    global flag\n"
    "    flag = 42\n"
    "setflag()\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert to_host(g["flag"]) == 42;
}

test "layer3: from-import-star binds a module's public names" {
    layer3_reset();
    src = "from operator import *\n"
    "s = add(3, 4)\n"
    "p = mul(3, 4)\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m"), "__package__": PyStr(t="str", val="")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["s"]) == 7;
    assert to_host(g["p"]) == 12;
}

test "layer3: *args / **kwargs collection binds surplus positional and keyword args" {
    # exec_code_frame lays out the [params][*args][**kwargs] localsplus region the
    # way CPython does: surplus positionals gather into the *args tuple, and
    # keywords that don't name a parameter flow into the **kwargs dict. Every
    # `def f(self, /, **kwds)` in the stdlib closure (namedtuple._replace, dozens
    # of dunder shims) depends on this.
    layer3_reset();
    src = "def f(a, *args, **kw):\n"
    "    return (a, args, sorted(kw.items()))\n"
    "r = f(1, 2, 3, x=4, y=5)\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["r"]) == (1, (2, 3), [("x", 4), ("y", 5)]);
}

test "layer3: a host builtin-subclass instance keeps its type across from_host" {
    # A host instance whose type is a proper subclass of a builtin (here a
    # tuple subclass) must not be flattened into a native PyTuple by from_host --
    # that would erase its real type and descriptors. It stays a proxy, so
    # `type(x).__name__` is the subclass and instance-specific attributes survive.
    layer3_reset();
    src = "T = type('T', (tuple,), {'tag': 'mine'})\n"
    "x = tuple.__new__(T, (1, 2))\n"
    "tn = type(x).__name__\n"
    "tg = x.tag\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["tn"]) == "T";
    assert to_host(g["tg"]) == "mine";
}

test "layer3: namedtuple's dynamic class boots in-VM (native<->host trampoline)" {
    # The named sub-milestone: collections.namedtuple builds a class at runtime
    # via host type(name, bases, ns) whose namespace holds NATIVE functions
    # (__new__ from eval, _make/_asdict/__repr__), then wraps some as
    # classmethod. to_host(PyFunction) hands each a host trampoline that calls
    # back into ceval, and from_host preserves the resulting tuple-subclass
    # instances. Field access, repr, _asdict, _make, ==, indexing, len, and
    # unpacking all run proxy-free end to end.
    layer3_reset();
    src = "from collections import namedtuple\n"
    "Point = namedtuple('Point', ['x', 'y'])\n"
    "p = Point(1, 2)\n"
    "tn = type(p).__name__\n"
    "a = p.x\n"
    "b = p.y\n"
    "s = str(p)\n"
    "d = p._asdict()\n"
    "m = Point._make([3, 4])\n"
    "ms = str(m)\n"
    "eq = (p == Point(1, 2))\n"
    "idx = p[0]\n"
    "cnt = len(p)\n"
    "ux, uy = p\n"
    "fields = p._fields\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["tn"]) == "Point";
    assert to_host(g["a"]) == 1;
    assert to_host(g["b"]) == 2;
    assert to_host(g["s"]) == "Point(x=1, y=2)";
    assert to_host(g["d"]) == {"x": 1, "y": 2};
    assert to_host(g["ms"]) == "Point(x=3, y=4)";
    assert to_host(g["eq"]) == True;
    assert to_host(g["idx"]) == 1;
    assert to_host(g["cnt"]) == 2;
    assert to_host(g["ux"]) == 1;
    assert to_host(g["uy"]) == 2;
    assert to_host(g["fields"]) == ("x", "y");
}

test "layer3: native objects expose __dict__ (functions, classes, instances, modules)" {
    # __dict__ backs introspection and functools.wraps/update_wrapper. It reads the
    # object's writable attribute map (a snapshot; live-mapping is a later refinement).
    layer3_reset();
    src = "def f(): pass\n"
    "f.tag = 7\n"
    "fd = f.__dict__['tag']\n"
    "class C:\n"
    "    cvar = 5\n"
    "cd = 'cvar' in C.__dict__\n"
    "o = C()\n"
    "o.iv = 9\n"
    "od = o.__dict__['iv']\n"
    "import operator\n"
    "md = 'add' in operator.__dict__\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m"), "__package__": PyStr(t="str", val="")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["fd"]) == 7;
    assert to_host(g["cd"]) == True;
    assert to_host(g["od"]) == 9;
    assert to_host(g["md"]) == True;
}

test "layer3: functools and contextlib boot in-VM (wraps / __dict__ / type-keyed dispatch)" {
    # functools trips on @wraps(reduce) needing wrapper.__dict__; contextlib on
    # the same closure machinery. Both now boot proxy-free, proving __dict__ plus
    # the hashable-proxy and trampoline work compose into a real module load.
    layer3_reset();
    fmod = import_native("functools");
    assert not is_error(fmod);
    assert isinstance(fmod, PyModule);
    assert "reduce" in (fmod as PyModule).attrs;
    assert "wraps" in (fmod as PyModule).attrs;
    assert "lru_cache" in (fmod as PyModule).attrs;
    cmod = import_native("contextlib");
    assert isinstance(cmod, PyModule);
    assert "contextmanager" in (cmod as PyModule).attrs;
}

test "layer3: a proxied host object (a type) is usable as a dict/set key" {
    # Type-keyed dispatch tables are everywhere in the stdlib closure
    # (functools.singledispatch, copyreg, typing, contextlib). A PyHostProxy now
    # buckets by its host hash so it can key a native dict/set; the dict layer
    # confirms a bucket hit with a real ==, so distinct classes stay distinct.
    layer3_reset();
    src = "X = type('X', (), {})\n"
    "Y = type('Y', (), {})\n"
    "d = {int: 'i', str: 's', X: 'x'}\n"
    "by_type = d[str]\n"
    "by_cls = d[X]\n"
    "x_in = X in d\n"
    "y_in = Y in d\n"
    "s = {X, Y}\n"
    "s_has = X in s\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["by_type"]) == "s";
    assert to_host(g["by_cls"]) == "x";
    assert to_host(g["x_in"]) == True;
    assert to_host(g["y_in"]) == False;
    assert to_host(g["s_has"]) == True;
}

test "layer3: namedtuple with defaults instantiates with omitted trailing fields" {
    layer3_reset();
    src = "from collections import namedtuple\n"
    "C = namedtuple('C', ['a', 'b', 'c'], defaults=[10, 20])\n"
    "x = C(1)\n"
    "s = str(x)\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["s"]) == "C(a=1, b=10, c=20)";
}
