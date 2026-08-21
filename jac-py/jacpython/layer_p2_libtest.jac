# P2 wave-4 JacPython libtest harness (TODO.md Libtest on JacPython).
#
# Runs embedded Lib/test-style Python snippets inside jacpython's ceval with
# shim modules backed by ``jacpython/*.jac`` facades (mirrors staged Modules ports).
# This is the product-path leg: host CPython smoke stays in libtest_runner; staged ``jac run``
# differential stays separate; this path exercises ``import platform`` (etc.)
# through register_shim_module + exec_code.

import from objects { PyObj, PyStr, PyError, is_error, py_none }
import from getplatform { Py_GetPlatform }
import from pyc_first {
    PyModule,
    register_shim_module,
    clear_shim_modules,
    host_compile_marshal,
    unmarshal,
    exec_code,
    to_host,
}

::py::
def _p2_wrap_snippet(source: str) -> str {
    return (
        "_libtest_lines = []\n"
        "def print(*args, **kwargs):\n"
        "    sep = kwargs.get('sep', ' ')\n"
        "    _libtest_lines.append(sep.join(str(a) for a in args))\n"
        + source
        + "\n"
    )
::py::


obj P2LibtestPlatformFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return PyStr(t="str", val=Py_GetPlatform());
    }
}

# Minimal stdlib ``platform`` shims for libtest snippets (not in getplatform port).
obj P2LibtestSystemFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return PyStr(t="str", val="Linux");
    }
}

obj P2LibtestMachineFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return PyStr(t="str", val="x86_64");
    }
}

def p2_libtest_reset() -> None {
    clear_shim_modules();
    platform_attrs: dict[str, PyObj] = {
        "platform": P2LibtestPlatformFn(t="function"),
        "system": P2LibtestSystemFn(t="function"),
        "machine": P2LibtestMachineFn(t="function"),
    };
    register_shim_module(
        "platform",
        PyModule(t="module", name="platform", attrs=platform_attrs)
    );
}


def p2_libtest_run_snippet(source: str) -> tuple[bool, str] {
    p2_libtest_reset();
    wrapped = _p2_wrap_snippet(source);
    co = unmarshal(host_compile_marshal(wrapped));
    if is_error(co) {
        return (False, "compile failed");
    }
    globals: dict[str, PyObj] = {
        "__name__": PyStr(t="str", val="__main__"),
    };
    outcome = exec_code(co, [], globals);
    if is_error(outcome) {
        exc = (outcome as PyError).exception;
        return (False, exc.type_name + ": " + exc.message);
    }
    if "_libtest_lines" not in globals {
        return (False, "missing _libtest_lines capture");
    }
    lines_obj = globals["_libtest_lines"];
    host_lines = to_host(lines_obj);
    if not isinstance(host_lines, list) {
        return (False, "print capture is not a list");
    }
    if len(host_lines) == 0 {
        return (False, "no printed output");
    }
    return (True, str(host_lines[len(host_lines) - 1]).strip());
}


def p2_libtest_expect_ok(source: str, expect_stdout: str = "ok") -> tuple[bool, str] {
    (ok, detail) = p2_libtest_run_snippet(source);
    if not ok {
        return (False, detail);
    }
    if detail != expect_stdout {
        return (
            False,
            f"expected stdout {expect_stdout!r}, got {detail!r}"
        );
    }
    return (True, detail);
}


test "layer_p2_libtest: platform_basic snippet prints ok on JacPython" {
    snippet = (
        "import platform\n"
        "plat = platform.platform()\n"
        "assert isinstance(plat, str) and len(plat) > 0\n"
        "assert platform.platform() == platform.platform()\n"
        "assert isinstance(platform.system(), str)\n"
        "assert isinstance(platform.machine(), str)\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}
