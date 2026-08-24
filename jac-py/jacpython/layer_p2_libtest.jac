# P2 wave-4 JacPython libtest harness (TODO.md Libtest on JacPython).
#
# Runs embedded Lib/test-style Python snippets inside jacpython's ceval with
# shim modules backed by ``jacpython/*.jac`` facades (mirrors staged Modules ports).
# This is the product-path leg: host CPython smoke stays in libtest_runner; staged ``jac run``
# differential stays separate; this path exercises ``import platform`` (etc.)
# through register_shim_module + exec_code.

import from objects { PyObj, PyStr, PyError, PyList, PyInt, PyBool, PyDict, is_error, py_none, py_error, }
import from getplatform { Py_GetPlatform }
import from _bisectmodule {
    _p2_bisect_right,
    _p2_bisect_left,
    _p2_insort,
    _p2_insort_left,
}
import from _warningsmodule {
    warnings_module_attrs,
    _p2_warn_state_reset,
}
import from ceval { _sys3_forget, set_layer3_active, to_host, _jac_host_import, _jac_host_getattr, _jac_host_call, py_repr, py_compare, py_slot_truth, }
import from _opcodemodule {
    _p2_stack_effect,
    _p2_is_valid,
    _p2_has_arg,
    _p2_has_const,
    _p2_has_name,
    _p2_has_jump,
    _p2_has_free,
    _p2_has_local,
    _p2_has_exc,
}
import from opcode_meta {
    OP_POP_TOP,
    OP_LOAD_CONST,
    OP_LOAD_FAST,
    OP_LOAD_DEREF,
    OP_JUMP_FORWARD,
    OP_FOR_ITER,
    OP_SETUP_FINALLY,
}
import from pyc_first {
    PyModule,
    register_shim_module,
    clear_shim_modules,
    host_compile_marshal,
    unmarshal,
    exec_code,
    to_host,
    from_host,
}
import from objects { PyDict, PyTuple }
import from ceval { py_attr, py_set_attr }
import from _functoolsmodule {
    P2_MISSING,
    P2_WRAPPER_ASSIGNMENTS,
    _p2_reduce,
    _p2_partial,
    _p2_lru_cache,
    _p2_cmp_to_key,
}

def _p2_wrap_snippet(source: str) -> str {
    return (
        "_libtest_lines = []\n"
        "def print(*args, **kwargs):\n"
        "    sep = kwargs.get('sep', ' ')\n"
        "    _libtest_lines.append(sep.join(str(a) for a in args))\n"
        + source
        + "\n"
    );
}

# ``platform.system`` / ``platform.machine`` are outside the getplatform port;
# seed shims from host CPython so libtest sees real strings on any OS.
import platform as _host_platform;

def _p2_libtest_host_system() -> str {
    return _host_platform.system();
}

def _p2_libtest_host_machine() -> str {
    return _host_platform.machine();
}



obj P2LibtestPlatformFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return PyStr(t="str", val=Py_GetPlatform());
    }
}

# Minimal stdlib ``platform`` shims for libtest snippets (not in getplatform port).
obj P2LibtestSystemFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return PyStr(t="str", val=_p2_libtest_host_system());
    }
}

obj P2LibtestMachineFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return PyStr(t="str", val=_p2_libtest_host_machine());
    }
}

def _p2_sync_pylist_from_host(py_list: PyList, host_list: any) -> None {
    new_items: list[PyObj] = [];
    for item in host_list {
        new_items.append(from_host(item));
    }
    py_list.items = new_items;
}

def _p2_optional_int_arg(args: list[PyObj], idx: int, `default: int) -> int {
    if len(args) > idx and isinstance(args[idx], PyInt) {
        return (args[idx] as PyInt).val;
    }
    return `default;
}

# json shim plumbing: keyword defaults are all "absent == default" safe
# because every dumps()/loads() kwarg maps None (and absence) to the same
# Lib/json default.
# Native raises do not cross the tp_call boundary as guest-catchable
# exceptions; the established shim contract is returning py_error objects
# (ceval turns those into raised guest exceptions), so catch and convert.
# JSONDecodeError surfaces as ValueError -- its Lib/json base class.
# ---------------- test.support shim -----------------------------------------
# Converted Lib/test pins import helper names from test.support; p2_libtest_reset
# registers a minimal module covering what converted suites actually use.

obj P2SupportSortdictFn(PyObj) {
    # CPython test/support/__init__.py sortdict: "Like repr(dict), but in
    # sorted order." Sorts by key (real comparisons, so unorderable key
    # mixes raise TypeError like CPython), formats each pair %r: %r.
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "sortdict expected at least 1 argument, got 0");
        }
        d = args[0];
        if not isinstance(d, PyDict) {
            return py_error("TypeError", "sortdict expected a dict");
        }
        keys: list[PyObj] = [];
        vals: list[PyObj] = [];
        for hk in (d as PyDict).items {
            ent = (d as PyDict).items[hk];
            keys.append(ent.key);
            vals.append(ent.value);
        }
        # Insertion sort by key; pin dicts are tiny. kind 0 = less-than
        # (same arm min()/max() use), truth via py_slot_truth.
        i = 1;
        while i < len(keys) {
            k = keys[i];
            v = vals[i];
            j = i - 1;
            while j >= 0 {
                lt = py_compare(0, k, keys[j]);
                if is_error(lt) {
                    return lt;
                }
                truth = py_slot_truth(lt);
                if is_error(truth) {
                    return truth;
                }
                if not ((truth as PyBool).val) {
                    break;
                }
                keys[j + 1] = keys[j];
                vals[j + 1] = vals[j];
                j -= 1;
            }
            keys[j + 1] = k;
            vals[j + 1] = v;
            i += 1;
        }
        out = "{";
        idx = 0;
        while idx < len(keys) {
            kr = py_repr(keys[idx]);
            if is_error(kr) {
                return kr;
            }
            vr = py_repr(vals[idx]);
            if is_error(vr) {
                return vr;
            }
            if idx > 0 {
                out = out + ", ";
            }
            out = out + (kr as PyStr).val + ": " + (vr as PyStr).val;
            idx += 1;
        }
        return PyStr(t="str", val=out + "}");
    }
}

obj P2LibtestBisectRightFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 2 {
            return py_error("TypeError", "missing arguments");
        }
        data = args[0] as PyList;
        item = args[1];
        lo = _p2_optional_int_arg(args, 2, 0);
        hi = _p2_optional_int_arg(args, 3, -1);
        host_data = to_host(data);
        host_item = to_host(item);
        if hi < 0 {
            got = _p2_bisect_right(host_data, host_item, lo);
        } else {
            got = _p2_bisect_right(host_data, host_item, lo, hi);
        }
        return PyInt(t="int", val=got);
    }
}

obj P2LibtestBisectLeftFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 2 {
            return py_error("TypeError", "missing arguments");
        }
        data = args[0] as PyList;
        item = args[1];
        lo = _p2_optional_int_arg(args, 2, 0);
        hi = _p2_optional_int_arg(args, 3, -1);
        host_data = to_host(data);
        host_item = to_host(item);
        if hi < 0 {
            got = _p2_bisect_left(host_data, host_item, lo);
        } else {
            got = _p2_bisect_left(host_data, host_item, lo, hi);
        }
        return PyInt(t="int", val=got);
    }
}

obj P2LibtestInsortFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 2 {
            return py_error("TypeError", "missing arguments");
        }
        data = args[0] as PyList;
        item = args[1];
        lo = _p2_optional_int_arg(args, 2, 0);
        hi = _p2_optional_int_arg(args, 3, -1);
        host_data = to_host(data);
        host_item = to_host(item);
        if hi < 0 {
            _p2_insort(host_data, host_item, lo);
        } else {
            _p2_insort(host_data, host_item, lo, hi);
        }
        _p2_sync_pylist_from_host(data, host_data);
        return py_none();
    }
}

obj P2LibtestInsortLeftFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 2 {
            return py_error("TypeError", "missing arguments");
        }
        data = args[0] as PyList;
        item = args[1];
        lo = _p2_optional_int_arg(args, 2, 0);
        hi = _p2_optional_int_arg(args, 3, -1);
        host_data = to_host(data);
        host_item = to_host(item);
        if hi < 0 {
            _p2_insort_left(host_data, host_item, lo);
        } else {
            _p2_insort_left(host_data, host_item, lo, hi);
        }
        _p2_sync_pylist_from_host(data, host_data);
        return py_none();
    }
}

def _p2_single_int_arg(args: list[PyObj]) -> PyObj {
    if len(args) != 1 or not isinstance(args[0], PyInt) {
        return py_error("TypeError", "expected exactly one int argument");
    }
    return args[0];
}

# ---- wave 20: functools facade shims ---------------------------------------
# reduce / partial / lru_cache / cmp_to_key are value-in/callable-out: they
# cross the host boundary through to_host/from_host (native functions become
# trampolines both ways with identity recovery). wraps and update_wrapper
# mutate native objects, so they run natively over PyObj via
# py_attr/py_set_attr. total_ordering stays gated by the parity suite only:
# filling in derived dunders needs a receiver-binding synthetic callable,
# which the VM cannot mint yet (call_user_dunder binds only real functions).
# The itertools facade is likewise parity-suite-gated only: its lazy (often
# infinite) iterators cannot survive GET_ITER's eager host drain.

# Native update_wrapper over PyObj: copies WRAPPER_ASSIGNMENTS that exist on
# the wrapped object, merges __dict__, sets __wrapped__ last.
def _p2_lib_native_update_wrapper(wrapper: PyObj, wrapped: PyObj) -> PyObj {
    for attr in P2_WRAPPER_ASSIGNMENTS {
        v: PyObj = py_attr(wrapped, attr);
        if not is_error(v) {
            err: PyObj = py_set_attr(wrapper, attr, v);
            if is_error(err) {
                return err;
            }
        }
    }
    # updated=('__dict__',): function __dict__ reads are snapshots, so merge
    # by re-storing each entry through setattr rather than dict.update.
    src: PyObj = py_attr(wrapped, "__dict__");
    if not is_error(src) and isinstance(src, PyDict) {
        srcd: PyDict = src as PyDict;
        for hk in srcd.items {
            `entry = srcd.items[hk];
            kobj: PyObj = `entry.key;
            if isinstance(kobj, PyStr) {
                errk: PyObj = py_set_attr(
                    wrapper, (kobj as PyStr).val, `entry.value
                );
                if is_error(errk) {
                    return errk;
                }
            }
        }
    }
    # Set last so the __dict__ merge cannot copy a stale __wrapped__ through.
    err2: PyObj = py_set_attr(wrapper, "__wrapped__", wrapped);
    if is_error(err2) {
        return err2;
    }
    return wrapper;
}

obj P2LibWrapsDecorator(PyObj) {
    has wrapped: PyObj;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 1 {
            return py_error("TypeError", "wraps() expects one wrapper function");
        }
        return _p2_lib_native_update_wrapper(args[0], self.wrapped);
    }
}

def _p2_opcode_pred_result(fn: any, args: list[PyObj]) -> PyObj {
    arg: PyObj = _p2_single_int_arg(args);
    if is_error(arg) { return arg; }
    got: bool = fn((arg as PyInt).val);
    return PyBool(t="bool", val=got);
}

obj P2OpcodeIsValidFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _p2_opcode_pred_result(_p2_is_valid, args);
    }
}

obj P2OpcodeHasArgFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _p2_opcode_pred_result(_p2_has_arg, args);
    }
}

obj P2OpcodeHasConstFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _p2_opcode_pred_result(_p2_has_const, args);
    }
}

obj P2OpcodeHasNameFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _p2_opcode_pred_result(_p2_has_name, args);
    }
}

obj P2OpcodeHasJumpFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _p2_opcode_pred_result(_p2_has_jump, args);
    }
}

obj P2OpcodeHasFreeFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _p2_opcode_pred_result(_p2_has_free, args);
    }
}

obj P2OpcodeHasLocalFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _p2_opcode_pred_result(_p2_has_local, args);
    }
}

obj P2OpcodeHasExcFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _p2_opcode_pred_result(_p2_has_exc, args);
    }
}

obj P2OpcodeStackEffectFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 or not isinstance(args[0], PyInt) {
            return py_error("TypeError", "stack_effect expected opcode int");
        }
        op = (args[0] as PyInt).val;
        oparg: int | None = None;
        if len(args) > 1 and isinstance(args[1], PyInt) {
            oparg = (args[1] as PyInt).val;
        } elif len(args) > 1 and args[1].t != "none" {
            return py_error("TypeError", "stack_effect oparg must be int or None");
        }
        jump: int | None = None;
        if len(args) > 2 {
            j = args[2];
            if j.t == "bool" {
                if (j as PyBool).val {
                    jump = 1;
                } else {
                    jump = 0;
                }
            } elif j.t != "none" {
                return py_error(
                    "ValueError", "stack_effect: jump must be False, True or None"
                );
            }
        }
        got = _p2_stack_effect(op, oparg, jump);
        if got is None {
            return py_error("ValueError", "invalid opcode or oparg");
        }
        return PyInt(t="int", val=got);
    }
}

# ---------------- test.support.os_helper ------------------------------------
# Lib/test helper submodules execute against the HOST interpreter by design
# (real filesystem walks, sys.path surgery, subprocess spawns), so the helpers
# converted pins actually use are served natively over the host bridge instead
# of hand-porting their surface. Only names demanded by converted suites live
# here; anything else keeps failing with the same ModuleNotFoundError as before
# this shim existed.
obj P2OsHelperUnlinkFn(PyObj) {
    # os_helper.unlink: remove a file, suppressing FileNotFoundError.
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 1 {
            return py_error("TypeError", "unlink expected 1 argument, got " + str(len(args)));
        }
        os_mod_res = _jac_host_import("os", PyList(t="list", items=[PyStr(t="str", val="*")]));
        if not ((os_mod_res[0] as bool)) {
            return py_error(str(os_mod_res[1]), str(os_mod_res[2]));
        }
        unlink_res = _jac_host_getattr(os_mod_res[1], "unlink");
        if not ((unlink_res[0] as bool)) {
            return py_error(str(unlink_res[1]), str(unlink_res[2]));
        }
        res = _jac_host_call(unlink_res[1], [to_host(args[0])], {});
        if res[0] as bool {
            return py_none();
        }
        if str(res[1]) == "FileNotFoundError" {
            return py_none();
        }
        return py_error(str(res[1]), str(res[2]));
    }
}

obj P2OsHelperRmdirFn(PyObj) {
    # os_helper.rmdir: remove an empty directory, suppressing FileNotFoundError.
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 1 {
            return py_error("TypeError", "rmdir expected 1 argument, got " + str(len(args)));
        }
        os_mod_res = _jac_host_import("os", PyList(t="list", items=[PyStr(t="str", val="*")]));
        if not ((os_mod_res[0] as bool)) {
            return py_error(str(os_mod_res[1]), str(os_mod_res[2]));
        }
        rmdir_res = _jac_host_getattr(os_mod_res[1], "rmdir");
        if not ((rmdir_res[0] as bool)) {
            return py_error(str(rmdir_res[1]), str(rmdir_res[2]));
        }
        res = _jac_host_call(rmdir_res[1], [to_host(args[0])], {});
        if res[0] as bool {
            return py_none();
        }
        if str(res[1]) == "FileNotFoundError" {
            return py_none();
        }
        return py_error(str(res[1]), str(res[2]));
    }
}

obj P2OsHelperFakePathFn(PyObj) {
    # os_helper.FakePath: fspath-bearing path stand-in. Pins only ever hand the
    # instance to pure path functions, so serving the wrapped value itself is
    # oracle-equivalent for every current pin; any divergence still fails the
    # output-oracle gate rather than passing silently.
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 1 {
            return py_error("TypeError", "FakePath expected 1 argument, got " + str(len(args)));
        }
        return args[0];
    }
}

def p2_libtest_reset {
    clear_shim_modules();
    # Route IMPORT_NAME through py_import_name so the registered facades win;
    # with the flag down every snippet import would silently hit the HOST
    # stdlib instead of the shim under test.
    set_layer3_active(True);
    # A prior in-VM leg (e.g. unittest's support closure) may have cached the
    # HOST collections module in the sys3 cache, which import_native checks
    # before the shim registry -- drop it so the facade shim always wins.
    _sys3_forget("collections");
    platform_attrs: dict[str, PyObj] = {
        "platform": P2LibtestPlatformFn(t="function"),
        "system": P2LibtestSystemFn(t="function"),
        "machine": P2LibtestMachineFn(t="function"),

    };
    register_shim_module(
        "platform", PyModule(t="module", name="platform", attrs=platform_attrs)
    );
    bisect_right_fn = P2LibtestBisectRightFn(t="function");
    bisect_left_fn = P2LibtestBisectLeftFn(t="function");
    insort_fn = P2LibtestInsortFn(t="function");
    insort_left_fn = P2LibtestInsortLeftFn(t="function");
    bisect_attrs: dict[str, PyObj] = {
        "bisect_right": bisect_right_fn,
        "bisect_left": bisect_left_fn,
        "insort": insort_fn,
        "insort_left": insort_left_fn,
        "bisect": bisect_right_fn,
        "insort_right": insort_fn,
    };
    register_shim_module(
        "bisect", PyModule(t="module", name="bisect", attrs=bisect_attrs)
    );
    # test.support shim for converted Lib/test pins (descrtut etc.). Mirrors
    # install_layer2_shims' test package shape; extend attrs as conversions
    # demand more helpers.
    support_attrs: dict[str, PyObj] = {
        "sortdict": P2SupportSortdictFn(t="function"),
        # CPython test.support.is_wasi: platform gate; our targets are never WASI.
        "is_wasi": PyBool(t="bool", val=False),
    };
    support_mod = PyModule(t="module", name="test.support", attrs=support_attrs);
    os_helper_attrs: dict[str, PyObj] = {
        "unlink": P2OsHelperUnlinkFn(t="function"),
        "rmdir": P2OsHelperRmdirFn(t="function"),
        "FakePath": P2OsHelperFakePathFn(t="function"),
        "TESTFN": PyStr(t="str", val="@test"),
        # CPython os_helper.is_wasi: platform gate; our targets are never WASI.
        "is_wasi": PyBool(t="bool", val=False),
    };
    os_helper_mod = PyModule(t="module", name="test.support.os_helper", attrs=os_helper_attrs);
    register_shim_module("test.support.os_helper", os_helper_mod);
    support_attrs["os_helper"] = os_helper_mod;
    register_shim_module("test.support", support_mod);
    register_shim_module(
        "test", PyModule(t="module", name="test", attrs={"support": support_mod})
    );
    opcode_attrs: dict[str, PyObj] = {
        "stack_effect": P2OpcodeStackEffectFn(t="function"),
        "is_valid": P2OpcodeIsValidFn(t="function"),
        "has_arg": P2OpcodeHasArgFn(t="function"),
        "has_const": P2OpcodeHasConstFn(t="function"),
        "has_name": P2OpcodeHasNameFn(t="function"),
        "has_jump": P2OpcodeHasJumpFn(t="function"),
        "has_free": P2OpcodeHasFreeFn(t="function"),
        "has_local": P2OpcodeHasLocalFn(t="function"),
        "has_exc": P2OpcodeHasExcFn(t="function"),
        "POP_TOP": PyInt(t="int", val=OP_POP_TOP),
        "LOAD_CONST": PyInt(t="int", val=OP_LOAD_CONST),
        "LOAD_FAST": PyInt(t="int", val=OP_LOAD_FAST),
        "LOAD_DEREF": PyInt(t="int", val=OP_LOAD_DEREF),
        "JUMP_FORWARD": PyInt(t="int", val=OP_JUMP_FORWARD),
        "FOR_ITER": PyInt(t="int", val=OP_FOR_ITER),
        "SETUP_FINALLY": PyInt(t="int", val=OP_SETUP_FINALLY),
    };
    register_shim_module(
        "_opcode", PyModule(t="module", name="_opcode", attrs=opcode_attrs)
    );
    _p2_warn_state_reset();
    register_shim_module(
        "warnings",
        PyModule(t="module", name="warnings", attrs=warnings_module_attrs())
    );
}


def p2_libtest_run_snippet(source: str) -> tuple[bool, str] {
    p2_libtest_reset();
    wrapped = _p2_wrap_snippet(source);
    co = unmarshal(host_compile_marshal(wrapped));
    if is_error(co) {
        return (False, "compile failed");
    }
    globals: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__"),};
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
        return (False, f"expected stdout {expect_stdout!r}, got {detail!r}");
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

test "layer_p2_libtest: bisect_precomputed snippet prints ok on JacPython" {
    snippet = (
        "import bisect\n"
        "cases = [\n"
        "    (bisect.bisect_right, [], 1, 0),\n"
        "    (bisect.bisect_right, [1, 2, 3], 2, 2),\n"
        "    (bisect.bisect_left, [1, 1, 2, 2], 1.5, 2),\n"
        "    (bisect.bisect_left, [1, 2, 2, 3, 3, 3, 4, 4, 4, 4], 3, 3),\n"
        "]\n"
        "for func, data, elem, expected in cases:\n"
        "    got = func(data, elem)\n"
        "    assert got == expected, (func.__name__, data, elem, got, expected)\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

test "layer_p2_libtest: bisect_insort snippet prints ok on JacPython" {
    snippet = (
        "import bisect\n"
        "data = [1, 2, 3]\n"
        "bisect.insort(data, 2)\n"
        "assert data == [1, 2, 2, 3]\n"
        "bisect.insort_left(data, 2)\n"
        "assert data == [1, 2, 2, 2, 3]\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

test "layer_p2_libtest: opcode_stack_effect snippet prints ok on JacPython" {
    snippet = (
        "import _opcode\n"
        "POP_TOP = 31\n"
        "LOAD_CONST = 82\n"
        "LOAD_FAST = 84\n"
        "JUMP_FORWARD = 77\n"
        "FOR_ITER = 70\n"
        "SETUP_FINALLY = 264\n"
        "assert _opcode.is_valid(POP_TOP)\n"
        "assert not _opcode.is_valid(1000)\n"
        "assert _opcode.has_arg(LOAD_CONST)\n"
        "assert not _opcode.has_arg(POP_TOP)\n"
        "assert _opcode.has_const(LOAD_CONST)\n"
        "assert _opcode.has_local(LOAD_FAST)\n"
        "assert not _opcode.has_free(LOAD_FAST)\n"
        "assert _opcode.has_jump(JUMP_FORWARD)\n"
        "assert _opcode.has_exc(SETUP_FINALLY)\n"
        "assert _opcode.stack_effect(POP_TOP) == -1\n"
        "assert _opcode.stack_effect(FOR_ITER, 0) == 1\n"
        "assert _opcode.stack_effect(JUMP_FORWARD, 0) == 0\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

