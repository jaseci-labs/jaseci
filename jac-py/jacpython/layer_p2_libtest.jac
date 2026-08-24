# P2 wave-4 JacPython libtest harness (TODO.md Libtest on JacPython).
#
# Runs embedded Lib/test-style Python snippets inside jacpython's ceval with
# shim modules backed by ``jacpython/*.jac`` facades (mirrors staged Modules ports).
# This is the product-path leg: host CPython smoke stays in libtest_runner; staged ``jac run``
# differential stays separate; this path exercises ``import platform`` (etc.)
# through register_shim_module + exec_code.

import from objects { PyObj, PyStr, PyError, PyList, PyInt, PyBool, is_error, py_none, py_error, }
import from getplatform { Py_GetPlatform }
import from _bisectmodule {
    _p2_bisect_right,
    _p2_bisect_left,
    _p2_insort,
    _p2_insort_left,
}
import from _heapqmodule { _p2_heappush, _p2_heappop, _p2_heapify, }
import from _jsonmodule { dumps, loads }
import from _warningsmodule {
    warnings_module_attrs,
    _p2_warn_state_reset,
}
import from ceval { _sys3_forget, set_layer3_active, }
import from _collectionsmodule {
    _p2_deque,
    _p2_defaultdict,
}
import from _collections_pylib {
    _p2_counter,
    _p2_namedtuple,
    _p2_ordereddict,
}
import from _statmodule {
    _p2_S_ISDIR,
    _p2_S_ISCHR,
    _p2_S_ISBLK,
    _p2_S_ISREG,
    _p2_S_ISFIFO,
    _p2_S_ISLNK,
    _p2_S_ISSOCK,
    _p2_S_IMODE,
    _p2_S_IFMT,
    _p2_filemode,
    S_IFDIR,
    S_IFCHR,
    S_IFBLK,
    S_IFREG,
    S_IFIFO,
    S_IFLNK,
    S_IFSOCK,
}
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
def _p2_json_kwarg(kwargs: dict[str, PyObj], name: str) -> PyObj {
    if name in kwargs {
        return kwargs[name];
    }
    return py_none();
}

def _p2_json_kwbool(kwargs: dict[str, PyObj], name: str, dflt: bool) -> bool {
    if name not in kwargs {
        return dflt;
    }
    val = kwargs[name];
    if isinstance(val, PyBool) {
        return val.val;
    }
    if isinstance(val, PyInt) {
        return val.val != 0;
    }
    return dflt;
}

# Native raises do not cross the tp_call boundary as guest-catchable
# exceptions; the established shim contract is returning py_error objects
# (ceval turns those into raised guest exceptions), so catch and convert.
# JSONDecodeError surfaces as ValueError -- its Lib/json base class.
obj P2LibtestJsonDumpsFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "dumps expected at least 1 argument, got 0");
        }
        try {
            encoded = dumps(
            to_host(args[0]),
            _p2_json_kwbool(kwargs, "skipkeys", False),
            _p2_json_kwbool(kwargs, "ensure_ascii", True),
            _p2_json_kwbool(kwargs, "check_circular", True),
            _p2_json_kwbool(kwargs, "allow_nan", True),
            to_host(_p2_json_kwarg(kwargs, "indent")),
            to_host(_p2_json_kwarg(kwargs, "separators")),
            to_host(_p2_json_kwarg(kwargs, "default")),
            _p2_json_kwbool(kwargs, "sort_keys", False),
        );
            return PyStr(t="str", val=encoded);
        } except ValueError as e {
            return py_error("ValueError", str(e));
        } except TypeError as e {
            return py_error("TypeError", str(e));
        }
    }
}

obj P2LibtestJsonLoadsFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "loads expected at least 1 argument, got 0");
        }
        try {
            decoded = loads(
                to_host(args[0]),
                to_host(_p2_json_kwarg(kwargs, "object_hook")),
                to_host(_p2_json_kwarg(kwargs, "parse_float")),
                to_host(_p2_json_kwarg(kwargs, "parse_int")),
                to_host(_p2_json_kwarg(kwargs, "parse_constant")),
                to_host(_p2_json_kwarg(kwargs, "object_pairs_hook")),
            );
        } except ValueError as e {
            return py_error("ValueError", str(e));
        } except TypeError as e {
            return py_error("TypeError", str(e));
        }
        return from_host(decoded);
    }
}

obj P2LibtestCollectionsCtor(PyObj) {
    # Builds a native collections object and hands the VM a proxy around it;
    # every subsequent method/subscript/repr routes back through the facade.
    has kind: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if self.kind == "deque" {
            iterable: any = None;
            if len(args) > 0 and args[0].t != "none" {
                iterable = to_host(args[0]);
            }
            maxlen: any = None;
            if "maxlen" in kwargs and kwargs["maxlen"].t != "none" {
                maxlen = to_host(kwargs["maxlen"]);
            }
            return from_host(_p2_deque(iterable, maxlen));
        }
        if self.kind == "defaultdict" {
            factory: any = None;
            if len(args) > 0 and args[0].t != "none" {
                factory = to_host(args[0]);
            }
            initial: any = None;
            if len(args) > 1 {
                initial = to_host(args[1]);
            }
            return from_host(_p2_defaultdict(factory, initial));
        }
        if self.kind == "Counter" or self.kind == "OrderedDict" {
            initial: any = None;
            if len(args) > 0 and args[0].t != "none" {
                initial = to_host(args[0]);
            }
            # Keyword counts/entries share the mapping-update path.
            kw: dict[str, any] = {};
            for k in kwargs.keys() {
                kw[k] = to_host(kwargs[k]);
            }
            if self.kind == "Counter" {
                built: any = _p2_counter(initial);
                if len(kw) > 0 {
                    built.update(kw);
                }
            } else {
                built = _p2_ordereddict(initial);
                if len(kw) > 0 {
                    built.update(kw);
                }
            }
            return from_host(built);
        }
        # namedtuple(typename, field_names, rename=..., defaults=...)
        typename = to_host(args[0]);
        field_names = to_host(args[1]);
        rename: bool = False;
        defaults: any = None;
        if "rename" in kwargs and kwargs["rename"].t == "bool" {
            rename = (kwargs["rename"] as PyBool).val;
        }
        if "defaults" in kwargs and kwargs["defaults"].t != "none" {
            defaults = to_host(kwargs["defaults"]);
        }
        return from_host(
            _p2_namedtuple(typename, field_names, rename, defaults));
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

obj P2LibtestHeappushFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 2 {
            return py_error("TypeError", "missing arguments");
        }
        heap = args[0] as PyList;
        item = args[1];
        host_heap = to_host(heap);
        _p2_heappush(host_heap, to_host(item));
        _p2_sync_pylist_from_host(heap, host_heap);
        return py_none();
    }
}

obj P2LibtestHeappopFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "missing arguments");
        }
        heap = args[0] as PyList;
        host_heap = to_host(heap);
        got = _p2_heappop(host_heap);
        _p2_sync_pylist_from_host(heap, host_heap);
        return from_host(got);
    }
}

obj P2LibtestHeapifyFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "missing arguments");
        }
        heap = args[0] as PyList;
        host_heap = to_host(heap);
        _p2_heapify(host_heap);
        _p2_sync_pylist_from_host(heap, host_heap);
        return py_none();
    }
}

def _p2_single_int_arg(args: list[PyObj]) -> PyObj {
    if len(args) != 1 or not isinstance(args[0], PyInt) {
        return py_error("TypeError", "expected exactly one int argument");
    }
    return args[0];
}

obj P2StatSIsDirFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        arg: PyObj = _p2_single_int_arg(args);
        if is_error(arg) { return arg; }
        got: bool = _p2_S_ISDIR((arg as PyInt).val);
        return PyBool(t="bool", val=got);
    }
}

obj P2StatSIsChrFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        arg: PyObj = _p2_single_int_arg(args);
        if is_error(arg) { return arg; }
        got: bool = _p2_S_ISCHR((arg as PyInt).val);
        return PyBool(t="bool", val=got);
    }
}

obj P2StatSIsBlkFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        arg: PyObj = _p2_single_int_arg(args);
        if is_error(arg) { return arg; }
        got: bool = _p2_S_ISBLK((arg as PyInt).val);
        return PyBool(t="bool", val=got);
    }
}

obj P2StatSIsRegFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        arg: PyObj = _p2_single_int_arg(args);
        if is_error(arg) { return arg; }
        got: bool = _p2_S_ISREG((arg as PyInt).val);
        return PyBool(t="bool", val=got);
    }
}

obj P2StatSIsFifoFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        arg: PyObj = _p2_single_int_arg(args);
        if is_error(arg) { return arg; }
        got: bool = _p2_S_ISFIFO((arg as PyInt).val);
        return PyBool(t="bool", val=got);
    }
}

obj P2StatSIsLnkFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        arg: PyObj = _p2_single_int_arg(args);
        if is_error(arg) { return arg; }
        got: bool = _p2_S_ISLNK((arg as PyInt).val);
        return PyBool(t="bool", val=got);
    }
}

obj P2StatSIsSockFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        arg: PyObj = _p2_single_int_arg(args);
        if is_error(arg) { return arg; }
        got: bool = _p2_S_ISSOCK((arg as PyInt).val);
        return PyBool(t="bool", val=got);
    }
}

obj P2StatSImodeFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        arg: PyObj = _p2_single_int_arg(args);
        if is_error(arg) { return arg; }
        got: int = _p2_S_IMODE((arg as PyInt).val);
        return PyInt(t="int", val=got);
    }
}

obj P2StatSIfmtFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        arg: PyObj = _p2_single_int_arg(args);
        if is_error(arg) { return arg; }
        got: int = _p2_S_IFMT((arg as PyInt).val);
        return PyInt(t="int", val=got);
    }
}

obj P2StatFilemodeFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        arg: PyObj = _p2_single_int_arg(args);
        if is_error(arg) { return arg; }
        got: str = _p2_filemode((arg as PyInt).val);
        return PyStr(t="str", val=got);
    }
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

obj P2LibReduceFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error("TypeError", "reduce() takes no keyword arguments");
        }
        if len(args) < 2 {
            return py_error(
                "TypeError",
                "reduce expected at least 2 arguments, got " + str(len(args)),
            );
        }
        if len(args) > 3 {
            return py_error(
                "TypeError",
                "reduce expected at most 3 arguments, got " + str(len(args)),
            );
        }
        fn_h: any = to_host(args[0]);
        seq_h: any = to_host(args[1]);
        try {
            if len(args) == 3 {
                got: any = _p2_reduce(fn_h, seq_h, to_host(args[2]));
            } else {
                got = _p2_reduce(fn_h, seq_h);
            }
        } except TypeError as e {
            return py_error("TypeError", str(e));
        }
        return from_host(got);
    }
}

obj P2LibPartialFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) == 0 {
            return py_error("TypeError", "partial expected at least 1 argument, got 0");
        }
        pos_h: list = [];
        for i in range(1, len(args)) {
            pos_h.append(to_host(args[i]));
        }
        kw_h: dict = {};
        for key in kwargs {
            kw_h[key] = to_host(kwargs[key]);
        }
        made = _p2_partial(to_host(args[0]), tuple(pos_h), kw_h);
        return from_host(made);
    }
}

obj P2LibLruCacheFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        typed_h: any = False;
        if "typed" in kwargs {
            tv: PyObj = kwargs["typed"];
            typed_h = to_host(tv);
        }
        if len(args) == 1 {
            # Single positional: function (apply now) or maxsize (decorator).
            made = _p2_lru_cache(to_host(args[0]), typed_h);
            return from_host(made);
        }
        maxsize_h: any = 128;
        if len(args) == 2 {
            maxsize_h = to_host(args[0]);
        } elif "maxsize" in kwargs {
            maxsize_h = to_host(kwargs["maxsize"]);
        }
        deco = _p2_lru_cache(maxsize_h, typed_h);
        return from_host(deco);
    }
}

obj P2LibCmpToKeyFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 1 {
            return py_error("TypeError", "cmp_to_key expected exactly 1 argument");
        }
        made = _p2_cmp_to_key(to_host(args[0]));
        return from_host(made);
    }
}

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

obj P2LibUpdateWrapperFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 2 {
            return py_error("TypeError", "update_wrapper expected 2 arguments");
        }
        return _p2_lib_native_update_wrapper(args[0], args[1]);
    }
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

obj P2LibWrapsFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 1 {
            return py_error("TypeError", "wraps expected exactly 1 argument");
        }
        deco = P2LibWrapsDecorator(t="function", wrapped=args[0]);
        return deco;
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
    heapq_attrs: dict[str, PyObj] = {
        "heappush": P2LibtestHeappushFn(t="function"),
        "heappop": P2LibtestHeappopFn(t="function"),
        "heapify": P2LibtestHeapifyFn(t="function"),
    };
    register_shim_module(
        "heapq", PyModule(t="module", name="heapq", attrs=heapq_attrs)
    );
    json_attrs: dict[str, PyObj] = {
        "dumps": P2LibtestJsonDumpsFn(t="function"),
        "loads": P2LibtestJsonLoadsFn(t="function"),
    };
    register_shim_module(
        "json", PyModule(t="module", name="json", attrs=json_attrs)
    );
    collections_attrs: dict[str, PyObj] = {
        "deque": P2LibtestCollectionsCtor(t="function", kind="deque"),
        "defaultdict": P2LibtestCollectionsCtor(
            t="function", kind="defaultdict"
        ),
        "Counter": P2LibtestCollectionsCtor(t="function", kind="Counter"),
        "OrderedDict": P2LibtestCollectionsCtor(
            t="function", kind="OrderedDict"
        ),
        "namedtuple": P2LibtestCollectionsCtor(
            t="function", kind="namedtuple"
        ),
    };
    register_shim_module(
        "collections",
        PyModule(t="module", name="collections", attrs=collections_attrs),
    );
    stat_attrs: dict[str, PyObj] = {
        "S_ISDIR": P2StatSIsDirFn(t="function"),
        "S_ISCHR": P2StatSIsChrFn(t="function"),
        "S_ISBLK": P2StatSIsBlkFn(t="function"),
        "S_ISREG": P2StatSIsRegFn(t="function"),
        "S_ISFIFO": P2StatSIsFifoFn(t="function"),
        "S_ISLNK": P2StatSIsLnkFn(t="function"),
        "S_ISSOCK": P2StatSIsSockFn(t="function"),
        "S_IMODE": P2StatSImodeFn(t="function"),
        "S_IFMT": P2StatSIfmtFn(t="function"),
        "filemode": P2StatFilemodeFn(t="function"),
        "S_IFMT_": PyInt(t="int", val=0o170000),
        "S_IFDIR": PyInt(t="int", val=S_IFDIR),
        "S_IFCHR": PyInt(t="int", val=S_IFCHR),
        "S_IFBLK": PyInt(t="int", val=S_IFBLK),
        "S_IFREG": PyInt(t="int", val=S_IFREG),
        "S_IFIFO": PyInt(t="int", val=S_IFIFO),
        "S_IFLNK": PyInt(t="int", val=S_IFLNK),
        "S_IFSOCK": PyInt(t="int", val=S_IFSOCK),
    };
    register_shim_module(
        "stat", PyModule(t="module", name="stat", attrs=stat_attrs)
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
    functools_attrs: dict[str, PyObj] = {
        "reduce": P2LibReduceFn(t="function"),
        "partial": P2LibPartialFn(t="function"),
        "lru_cache": P2LibLruCacheFn(t="function"),
        "cmp_to_key": P2LibCmpToKeyFn(t="function"),
        "wraps": P2LibWrapsFn(t="function"),
        "update_wrapper": P2LibUpdateWrapperFn(t="function"),
    };
    register_shim_module(
        "functools", PyModule(t="module", name="functools", attrs=functools_attrs)
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

test "layer_p2_libtest: heapq_push_pop snippet prints ok on JacPython" {
    snippet = (
        "import heapq\n"
        "heap = []\n"
        "data = [3, 1, 4, 1, 5, 9, 2, 6]\n"
        "for x in data:\n"
        "    heapq.heappush(heap, x)\n"
        "out = []\n"
        "while heap:\n"
        "    out.append(heapq.heappop(heap))\n"
        "assert out == sorted(data)\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

test "layer_p2_libtest: heapq_heapify snippet prints ok on JacPython" {
    snippet = (
        "import heapq\n"
        "data = [3, 1, 4, 1, 5, 9, 2, 6]\n"
        "heapq.heapify(data)\n"
        "parent_ok = all(data[(i - 1) >> 1] <= data[i] for i in range(1, len(data)))\n"
        "assert parent_ok\n"
        "assert sorted(data) == [1, 1, 2, 3, 4, 5, 6, 9]\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

test "layer_p2_libtest: stat_filemode snippet prints ok on JacPython" {
    snippet = (
        "import stat\n"
        "assert stat.S_ISDIR(stat.S_IFDIR)\n"
        "assert stat.S_ISREG(stat.S_IFREG)\n"
        "assert not stat.S_ISREG(stat.S_IFDIR)\n"
        "assert stat.S_IMODE(0o100755) == 0o755\n"
        "assert stat.S_IFMT(0o100755) == stat.S_IFREG\n"
        "assert stat.filemode(0o100755) == '-rwxr-xr-x'\n"
        "dir_mode = stat.S_IFDIR | 0o640\n"
        "assert stat.filemode(dir_mode) == 'drw-r-----'\n"
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

test "layer_p2_libtest: functools_reduce snippet prints ok on JacPython" {
    snippet = (
        "import functools\n"
        "assert functools.reduce(lambda a, b: a + b, [1, 2, 3, 4]) == 10\n"
        "assert functools.reduce(lambda a, b: a + b, [], 7) == 7\n"
        "assert functools.reduce(lambda a, b: a if a > b else b, [3, 9, 2]) == 9\n"
        "try:\n"
        "    functools.reduce(lambda a, b: a + b, [])\n"
        "except TypeError as e:\n"
        "    assert str(e) == 'reduce() of empty iterable with no initial value', e\n"
        "else:\n"
        "    raise AssertionError('expected TypeError')\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

test "layer_p2_libtest: collections_deque snippet prints ok on JacPython" {
    snippet = (
        "import collections\n"
        "d = collections.deque([1, 2, 3], maxlen=3)\n"
        "d.append(4)\n"
        "assert list(d) == [2, 3, 4]\n"
        "d.appendleft(9)\n"
        "assert len(d) == 3 and d.maxlen == 3\n"
        "d.rotate(-1)\n"
        "assert d[0] == 2 and d[-1] == 9\n"
        "got = ''\n"
        "try:\n"
        "    d[99]\n"
        "except IndexError as e:\n"
        "    got = str(e)\n"
        "assert got == 'deque index out of range', got\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , "DBG:" + repr(detail);
}

test "layer_p2_libtest: collections_counter snippet prints ok on JacPython" {
    snippet = (
        "import collections\n"
        "c = collections.Counter('abracadabra')\n"
        "assert c['a'] == 5 and c['z'] == 0\n"
        "assert c.most_common(2) == [('a', 5), ('b', 2)]\n"
        "assert c.total() == 11\n"
        "c.update({'b': 1}, w=7)\n"
        "assert c['b'] == 3 and c['w'] == 7\n"
        "c.subtract('aaa')\n"
        "assert c['a'] == 2\n"
        "pos = +c\n"
        "assert pos['w'] == 7 and 'z' not in pos\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

test "layer_p2_libtest: functools_partial_lru snippet prints ok on JacPython" {
    snippet = (
        "import functools\n"
        "def add(a=0, b=0, c=0):\n"
        "    return a + b + c\n"
        "p = functools.partial(add, 1, b=2)\n"
        "assert p() == 3 and p(c=4) == 7\n"
        "pp = functools.partial(p, c=10)\n"
        "assert pp() == 13\n"
        "calls = []\n"
        "def g(x):\n"
        "    calls.append(x)\n"
        "    return x * 10\n"
        "cached = functools.lru_cache(maxsize=2)(g)\n"
        "for i in (1, 2, 1, 3, 1):\n"
        "    cached(i)\n"
        "assert calls == [1, 2, 3], calls\n"
        "info = cached.cache_info()\n"
        "assert str(info) == 'CacheInfo(hits=2, misses=3, maxsize=2, currsize=2)', info\n"
        "cached.cache_clear()\n"
        "assert str(cached.cache_info()) == 'CacheInfo(hits=0, misses=0, maxsize=2, currsize=0)'\n"
        "assert cached.cache_parameters() == {'maxsize': 2, 'typed': False}\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

test "layer_p2_libtest: collections_defaultdict snippet prints ok on JacPython" {
    snippet = (
        "import collections\n"
        "dd = collections.defaultdict(list)\n"
        "dd.update({'k': [1]})\n"
        "assert dd['k'] == [1]\n"
        "# A miss calls the factory and inserts the fresh default.\n"
        "assert dd['q'] == []\n"
        "assert len(dd) == 2 and dd.default_factory is list\n"
        "plain = collections.defaultdict()\n"
        "got = ''\n"
        "try:\n"
        "    plain['x']\n"
        "except KeyError as e:\n"
        "    got = str(e)\n"
        "assert got == \"'x'\", got\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

test "layer_p2_libtest: functools_cmp_to_key snippet prints ok on JacPython" {
    snippet = (
        "import functools\n"
        "K = functools.cmp_to_key(lambda x, y: (x > y) - (x < y))\n"
        "data = [3, 1, 4, 1, 5]\n"
        "assert sorted(data, key=K) == sorted(data)\n"
        "kd = functools.cmp_to_key(lambda x, y: y - x)\n"
        "assert sorted(data, key=kd) == sorted(data, reverse=True)\n"
        "assert K(2).obj == 2\n"
        "words = ['pear', 'fig', 'banana']\n"
        "by_len = functools.cmp_to_key(lambda x, y: len(x) - len(y))\n"
        "assert sorted(words, key=by_len) == ['fig', 'pear', 'banana']\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

test "layer_p2_libtest: collections_ordereddict snippet prints ok on JacPython" {
    snippet = (
        "import collections\n"
        "od = collections.OrderedDict([('a', 1), ('b', 2)])\n"
        "od.move_to_end('a')\n"
        "assert list(od.keys()) == ['b', 'a']\n"
        "assert od.popitem() == ('a', 1)\n"
        "o1 = collections.OrderedDict([('a', 1), ('b', 2)])\n"
        "o2 = collections.OrderedDict([('b', 2), ('a', 1)])\n"
        "assert list(o1.items()) != list(o2.items())\n"
        "assert list(o1.items()) == [('a', 1), ('b', 2)]\n"
        "assert repr(o1) == \"OrderedDict({'a': 1, 'b': 2})\"\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

test "layer_p2_libtest: functools_wraps_update_wrapper snippet prints ok on JacPython" {
    snippet = (
        "import functools\n"
        "def real(x):\n"
        "    'the real doc'\n"
        "    return x\n"
        "@functools.wraps(real)\n"
        "def wrapped(x):\n"
        "    return real(x)\n"
        "assert wrapped.__name__ == 'real', wrapped.__name__\n"
        "assert wrapped.__doc__ == 'the real doc'\n"
        "assert wrapped.__wrapped__ is real\n"
        "assert wrapped(41) == 41\n"
        "def donor(): pass\n"
        "donor.extra = 42\n"
        "def sink(): pass\n"
        "functools.update_wrapper(sink, donor)\n"
        "assert sink.extra == 42\n"
        "assert sink.__wrapped__ is donor\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

test "layer_p2_libtest: collections_namedtuple snippet prints ok on JacPython" {
    snippet = (
        "import collections\n"
        "P = collections.namedtuple('P', ['x', 'y'], defaults=[5])\n"
        "p = P(1)\n"
        "assert p.x == 1 and p.y == 5\n"
        "assert repr(p) == 'P(x=1, y=5)'\n"
        "assert p._asdict() == {'x': 1, 'y': 5}\n"
        "assert tuple(p) == (1, 5)\n"
        "R = collections.namedtuple('R', ['x', 'x'], rename=True)\n"
        "assert R._fields == ('x', '_1')\n"
        "Q = collections.namedtuple('Q', ['x', 'y'])\n"
        "assert Q._fields == ('x', 'y')\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}
