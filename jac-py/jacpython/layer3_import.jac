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
