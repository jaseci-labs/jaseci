# COLLECTIONS.ABC import pins (runtime stdlib-submodule resolution).
#
# Surface under test: import_native's missing-module fallback -- CPython checks
# sys.modules BEFORE any path finder, and imports the parent package first, so
# a package body can register a submodule alias at exec time that exists
# nowhere on disk. CPython 3.14 removed Lib/collections/abc.py:
# collections/__init__.py does
#     _sys.modules['collections.abc'] = _collections_abc
# so `import collections.abc` resolves through that registry entry. The VM's
# filesystem descent (_jac_module_info) can never find such a module; the fix
# honors a pre-registered host sys.modules entry (and binds it as the parent's
# attribute) instead of raising ModuleNotFoundError.
#
# Ground truth recorded from host CPython 3.14.6:
#   - import collections.abc / from collections import abc both succeed and
#     expose the ABC surface (Mapping, Callable, ...)
#   - isinstance({}, collections.abc.Mapping) is True; int is not a Callable
#   - plain `import abc` keeps working alongside the alias
#   - a genuinely absent DOTTED module reports its PARENT first
#     ("No module named 'nosuchpkg_xyz'"), byte-exact with CPython
#
# Known delta (pre-existing on clean tip, unrelated to import resolution):
# isinstance(<native builtin>, collections.abc.Callable) is False -- the VM's
# PyNativeBuiltin len does not cross to a host object ABCMeta recognizes as
# registered. VM callables (lambdas/user functions) answer correctly; the pin
# below asserts those.

import from objects {
    PyError,
    is_error,
}
import from pyc_first {
    PyObj,
    PyStr,
    exec_code,
    unmarshal,
    host_compile_marshal,
    set_layer3_active,
    clear_sys3_modules,
    to_host,
}


def cabc_reset() {
    # Same clean-VM discipline as layer3_import: real source runs in-VM, no
    # harness shims in the way.
    clear_sys3_modules();
    set_layer3_active(True);
}

def cabc_run(source: str) -> dict[str, PyObj] {
    cabc_reset();
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(source)), [], g);
    assert not is_error(outcome), _cabc_err(outcome);
    return g;
}

def _cabc_err(outcome: PyObj) -> str {
    if isinstance(outcome, PyError) {
        exc = (outcome as PyError).exception;
        return exc.type_name + ": " + exc.message;
    }
    return "non-error failure";
}


test "cabc pins: import collections.abc resolves through the sys.modules alias" {
    g = cabc_run(
        "import collections.abc\n"
        "ok = isinstance({}, collections.abc.Mapping)\n"
    );
    assert to_host(g["ok"]) == True;
}

test "cabc pins: import collections.abc works before any import collections" {
    # Parent-first order: importing the package body must give it the chance
    # to register the alias before the submodule lookup fires.
    g = cabc_run("import collections.abc\nok = hasattr(collections.abc, 'Mapping')\n");
    assert to_host(g["ok"]) == True;
}

test "cabc pins: from collections import abc exposes the ABC surface" {
    g = cabc_run(
        "from collections import abc\n"
        "ok = isinstance({'a': 1}, abc.Mapping) and isinstance((1,), abc.Sequence)\n"
    );
    assert to_host(g["ok"]) == True;
}

test "cabc pins: collections.abc.Callable discriminates callables" {
    g = cabc_run(
        "import collections.abc\n"
        "yes = isinstance(lambda x: x, collections.abc.Callable)\n"
        "def fn(): pass\n"
        "yes2 = isinstance(fn, collections.abc.Callable)\n"
        "no = isinstance(3, collections.abc.Callable)\n"
    );
    assert to_host(g["yes"]) == True;
    assert to_host(g["yes2"]) == True;
    assert to_host(g["no"]) == False;
}

test "cabc pins: plain import abc still works beside the alias" {
    # The `abc` module (ABC/ABCMeta) is distinct from collections.abc
    # (_collections_abc); both must keep importing.
    g = cabc_run(
        "import abc\n"
        "import collections.abc\n"
        "has_abc_base = hasattr(abc, 'ABC')\n"
        "is_map = isinstance({}, collections.abc.Mapping)\n"
    );
    assert to_host(g["has_abc_base"]) == True;
    assert to_host(g["is_map"]) == True;
}

test "cabc pins: genuinely missing submodules keep the CPython error text" {
    cabc_reset();
    src = (
        "try:\n"
        "    import nosuchpkg_xyz.sub\n"
        "except ModuleNotFoundError as e:\n"
        "    R = type(e).__name__ + ': ' + str(e)\n"
    );
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome), _cabc_err(outcome);
    got = to_host(g["R"]);
    # CPython reports the PARENT of a dotted name when the parent itself is
    # missing (import_native now imports the parent before declaring the
    # submodule missing, mirroring _find_and_load).
    assert got == "ModuleNotFoundError: No module named 'nosuchpkg_xyz'", str(got);
}
