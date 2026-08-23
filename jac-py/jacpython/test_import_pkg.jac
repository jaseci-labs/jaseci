# Guest package-import pins (Layer 3 import system).
#
# The VM's finder walks sys.path in order for packages (__init__.py +
# submodules) instead of asking importlib.util.find_spec, which would execute
# parent-package bodies on the HOST and leak host-side module objects into a
# namespace the VM must own. Each probe runs a guest source through exec_code
# with Layer 3 active against a throwaway package tree, and every observable
# (values, module identity, error type AND message text) is pinned byte-exact
# against CPython behavior verified with python3 on the identical tree.
#
# Covered here: absolute submodule imports, submodule attr binding on the
# parent (importlib semantics), __name__/__package__/__file__ seeding,
# relative forms (`from .sib import x`, `from ..pkg import y`), level-based
# resolution vs __package__, circular packages resolving to the partial
# module, __all__-driven star imports, and the canonical error texts:
#   "No module named 'X'"
#   "No module named 'X'; 'Y' is not a package"
#   "attempted relative import with no known parent package"
#   "attempted relative import beyond top-level package"
#   "cannot import name 'x' from 'Y' (<origin>)"
import os;
import pathlib;
import shutil;
import sys;
import tempfile;
import from pyc_first { clear_sys3_modules, set_layer3_active, to_host }
import from ceval { exec_code, unmarshal, host_compile_marshal }
import from objects { PyObj, PyError, PyStr, is_error }

glob _pkg_roots: list[str] = [];

def _write_file(base: str, rel: str, content: str) {
    p = base + "/" + rel;
    d = p.rsplit("/", 1)[0];
    if not os.path.isdir(d) {
        os.makedirs(d);
    }
    pathlib.Path(p).write_text(content);
}

# Build the shared fixture tree once per process:
#   <base>/
#     outer/__init__.py       OUT = "outer-init"
#     outer/apkg/__init__.py  VAL = "a-init"
#     outer/apkg/sub.py       WHO, hello()
#     outer/apkg/deep.py      from .sub import hello -> X
#     outer/bpkg/__init__.py  NAME
#     outer/bpkg/helper.py    from ..apkg import sub -> REF
#     circ/__init__.py        from . import cmod
#     circ/cmod.py            import circ.other; OTHER_OK
#     circ/other.py           Y = 1
#     starall.py              __all__ = ["PUBLIC_ONLY"]; HIDDEN; PUBLIC_ONLY
def _ensure_pkg_root -> str {
    if len(_pkg_roots) > 0 {
        return _pkg_roots[0];
    }
    base = tempfile.mkdtemp(prefix="jac_import_pkg_");
    _write_file(base, "outer/__init__.py", "OUT = \"outer-init\"\n");
    _write_file(base, "outer/apkg/__init__.py", "VAL = \"a-init\"\n");
    _write_file(
        base,
        "outer/apkg/sub.py",
        "WHO = \"apkg.sub\"\n"
        "def hello():\n"
        "    return \"hi-from-sub\"\n",
    );
    _write_file(
        base,
        "outer/apkg/deep.py",
        "from .sub import hello\n"
        "X = hello()\n",
    );
    _write_file(base, "outer/bpkg/__init__.py", "NAME = \"bpkg\"\n");
    _write_file(
        base,
        "outer/bpkg/helper.py",
        "from ..apkg import sub\n"
        "REF = sub.WHO\n",
    );
    _write_file(base, "circ/__init__.py", "from . import cmod\n");
    _write_file(
        base,
        "circ/cmod.py",
        "import circ.other\n"
        "OTHER_OK = hasattr(circ.other, \"Y\")\n",
    );
    _write_file(base, "circ/other.py", "Y = 1\n");
    _write_file(
        base,
        "starall.py",
        "__all__ = [\"PUBLIC_ONLY\"]\n"
        "HIDDEN = 1\n"
        "PUBLIC_ONLY = 2\n",
    );
    _pkg_roots.append(base);
    return base;
}

def _cleanup_pkg_roots {
    for r in _pkg_roots {
        shutil.rmtree(r, ignore_errors=True);
    }
    _pkg_roots.clear();
}

# Run a guest source with Layer 3 active and only __name__ seeded (script
# semantics). Returns ("ok", R-value) or ("err", "<Type>: <message>").
def _run_guest(src: str) -> tuple {
    clear_sys3_modules();
    set_layer3_active(True);
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    return _run_guest_in(src, g);
}

# Same, but with an explicit seeding dict (e.g. __package__ for module-context
# relative-import probes).
def _run_guest_in(src: str, g: dict[str, PyObj]) -> tuple {
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    if is_error(outcome) {
        exc = (outcome as PyError).exception;
        return ("err", exc.type_name + ": " + exc.message);
    }
    if "R" not in g {
        return ("err", "probe produced no R");
    }
    return ("ok", to_host(g["R"]));
}

test "importpkg: absolute submodule import, attr binding, identity, dunder seeds" {
    # `import outer.apkg.sub` must bind `sub` onto the parent module object
    # (importlib semantics), seed __name__/__package__/__file__, and serve the
    # SAME object on a repeated import (once-per-process cache).
    base = _ensure_pkg_root();
    sys.path.insert(0, base);
    res = _run_guest(
        "import outer.apkg.sub\n"
        "import outer.apkg.sub as again\n"
        "R = [outer.apkg.sub.WHO, outer.apkg.VAL, outer.apkg.sub is again,\n"
        "     outer.apkg.__name__, outer.apkg.__package__,\n"
        "     outer.apkg.sub.__name__, outer.apkg.sub.__package__,\n"
        "     outer.apkg.sub.__file__.endswith('sub.py')]\n"
    );
    sys.path.pop(0);
    assert res[0] == "ok", str(res[1]);
    assert res[1] == [
        "apkg.sub",
        "a-init",
        True,
        "outer.apkg",
        "outer.apkg",
        "outer.apkg.sub",
        "outer.apkg",
        True,
    ], str(res[1]);
}

test "importpkg: relative sibling import and parent-level ..pkg form" {
    # deep.py uses `from .sub import hello`; helper.py climbs one level with
    # `from ..apkg import sub`. Both resolve against __package__.
    base = _ensure_pkg_root();
    sys.path.insert(0, base);
    deep = _run_guest("import outer.apkg.deep\nR = outer.apkg.deep.X\n");
    helper = _run_guest("import outer.bpkg.helper\nR = outer.bpkg.helper.REF\n");
    sys.path.pop(0);
    assert deep[0] == "ok", str(deep[1]);
    assert deep[1] == "hi-from-sub", str(deep[1]);
    assert helper[0] == "ok", str(helper[1]);
    assert helper[1] == "apkg.sub", str(helper[1]);
}

test "importpkg: circular package resolves to the partial module" {
    # circ/__init__ imports cmod mid-body; cmod re-imports circ and must see
    # the partially-initialized cached entry rather than re-entering.
    base = _ensure_pkg_root();
    sys.path.insert(0, base);
    res = _run_guest("import circ\nR = circ.cmod.OTHER_OK\n");
    sys.path.pop(0);
    assert res[0] == "ok", str(res[1]);
    assert res[1] == True, str(res[1]);
}

test "importpkg: star import honors __all__" {
    base = _ensure_pkg_root();
    sys.path.insert(0, base);
    res = _run_guest(
        "from starall import *\n"
        "try:\n"
        "    HIDDEN\n"
        "    leaked = '/HIDDEN_LEAKED'\n"
        "except NameError:\n"
        "    leaked = ''\n"
        "R = PUBLIC_ONLY == 2 and not leaked\n"
    );
    sys.path.pop(0);
    assert res[0] == "ok", str(res[1]);
    assert res[1] == True, str(res[1]);
}

test "importpkg: ModuleNotFoundError texts match CPython byte-for-byte" {
    base = _ensure_pkg_root();
    sys.path.insert(0, base);
    missing = _run_guest(
        "try:\n"
        "    import nosuchmod_xyz\n"
        "except ModuleNotFoundError as e:\n"
        "    R = str(type(e).__name__) + ': ' + str(e)\n"
    );
    child = _run_guest(
        "try:\n"
        "    import outer.apkg.nosuch\n"
        "except ModuleNotFoundError as e:\n"
        "    R = str(type(e).__name__) + ': ' + str(e)\n"
    );
    notpkg = _run_guest(
        "try:\n"
        "    import starall.nope\n"
        "except ModuleNotFoundError as e:\n"
        "    R = str(type(e).__name__) + ': ' + str(e)\n"
    );
    sys.path.pop(0);
    assert missing == (
        "ok", "ModuleNotFoundError: No module named 'nosuchmod_xyz'"
    ), str(missing[1]);
    assert child == (
        "ok", "ModuleNotFoundError: No module named 'outer.apkg.nosuch'"
    ), str(child[1]);
    assert notpkg == (
        "ok",
        "ModuleNotFoundError: No module named 'starall.nope'; 'starall' is not a package",
    ), str(notpkg[1]);
}

test "importpkg: relative-import ImportErrors match CPython byte-for-byte" {
    base = _ensure_pkg_root();
    sys.path.insert(0, base);
    # A bare script has no parent package: level>=1 must fail canonically...
    noparent = _run_guest(
        "try:\n"
        "    from . import x\n"
        "except ImportError as e:\n"
        "    R = str(type(e).__name__) + ': ' + str(e)\n"
    );
    # ...and so must climbing past the top of its real package.
    g: dict[str, PyObj] = {
        "__name__": PyStr(t="str", val="outer.bpkg.helper"),
        "__package__": PyStr(t="str", val="outer.bpkg"),
    };
    beyond = _run_guest_in(
        "try:\n"
        "    from ...apkg import x\n"
        "except ImportError as e:\n"
        "    R = str(type(e).__name__) + ': ' + str(e)\n",
        g,
    );
    sys.path.pop(0);
    assert noparent == (
        "ok",
        "ImportError: attempted relative import with no known parent package",
    ), str(noparent[1]);
    assert beyond == (
        "ok",
        "ImportError: attempted relative import beyond top-level package",
    ), str(beyond[1]);
}

test "importpkg: IMPORT_FROM failure raises the canonical cannot-import-name" {
    base = _ensure_pkg_root();
    sys.path.insert(0, base);
    g: dict[str, PyObj] = {
        "__name__": PyStr(t="str", val="outer.bpkg.helper"),
        "__package__": PyStr(t="str", val="outer.bpkg"),
    };
    res = _run_guest_in(
        "try:\n"
        "    from ..apkg import nonexistent\n"
        "except ImportError as e:\n"
        "    R = str(type(e).__name__) + ': ' + str(e)\n",
        g,
    );
    sys.path.pop(0);
    assert res[0] == "ok", str(res[1]);
    prefix = "ImportError: cannot import name 'nonexistent' from 'outer.apkg' (";
    suffix = "/outer/apkg/__init__.py)";
    assert res[1][:len(prefix)] == prefix, str(res[1]);
    assert res[1][len(res[1]) - len(suffix):] == suffix, str(res[1]);
}
