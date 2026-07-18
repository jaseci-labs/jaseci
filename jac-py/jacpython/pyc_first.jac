# C3 bootstrap (jac-py/PLAN.md P3 / TODO.md C3): pyc-first.
#
# Thesis: jacpython's object core + ceval can run real programs that TODAY's
# CPython compiled. So we bypass the entire front end (tokenizer -> parser ->
# symtable -> compile) by feeding host-compiled, marshalled code objects
# straight into the ceval. This decouples execution from compilation and gives
# us a free dual-interpreter oracle (the same .pyc run by CPython and jacpython).
#
# This file is the minimal vertical slice that proves it: a small PyObj model,
# a CPython 3.14 marshal reader, and a tiny ceval covering host-compiled
# arithmetic, list/string/sequence operations, and direct function calls
# (LOAD_FAST_BORROW*, LOAD_SMALL_INT, BINARY_OP, MAKE_FUNCTION, CALL,
# RETURN_VALUE, STORE_NAME/LOAD_NAME, ...).
#
# This slice now covers the core object-model and ceval seams needed by ordinary
# Python programs: attributes, host imports, jumps/iteration, exception-table
# unwinding, cells/freevars, and positional/keyword calls.  The transport is
# still CPython 3.14.6-specific; the front end and the full object protocol are
# intentionally outside this bootstrap module.

# ---------------- host bridge ----------------
import marshal;

::py::
def _jac_host_import(name, fromlist):
    import importlib
    try:
        if fromlist:
            return (True, importlib.import_module(name))
        return (True, importlib.import_module(name.split(".")[0]))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_host_getattr(value, name):
    try:
        return (True, getattr(value, name))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_host_setattr(value, name, field):
    try:
        setattr(value, name, field)
        return (True, None)
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_host_call(fn, args, kwargs):
    try:
        return (True, fn(*args, **kwargs))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_host_getitem(value, index):
    try:
        return (True, value[index])
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_host_len(value):
    try:
        return (True, len(value))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_is_object_type(value):
    # True iff value is exactly the builtin `object` type. object.__new__(cls) is
    # the canonical plain-instance constructor (functools._PlaceholderType, any
    # singleton). Other types' __new__ stays host-routed so namedtuple's
    # tuple.__new__(HostClass, ...) is unaffected.
    return value is object

def _jac_is_type_type(value):
    # True iff value is exactly the builtin `type`. A user class listing `type`
    # among its bases is a metaclass; super().__new__ inside its __new__ must
    # build a class object (type.__new__), not a plain instance.
    return value is type

def _jac_host_hashkey(value):
    # Bucket a proxied host object by its host hash so it can be a dict/set key
    # (type-keyed dispatch tables in functools/copyreg/typing/contextlib). Equal
    # host objects share a hash, hence a bucket; the dict layer confirms a bucket
    # hit with a real == (PyHostProxy needs_eq_confirm). '' means unhashable.
    try:
        return "host:" + str(hash(value))
    except BaseException:
        return ""

def _jac_host_contains(member, container):
    try:
        return (True, member in container)
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_is_notimpl(v):
    return v is NotImplemented

def _jac_host_iter(value):
    try:
        return (True, list(value))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_host_builtin(name):
    import builtins
    try:
        return (True, getattr(builtins, name))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_host_type_name(value):
    return type(value).__name__

def _jac_host_delattr(host_obj, name):
    try:
        delattr(host_obj, name)
        return (True, None)
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_wrap_classmethod(host_fn):
    return classmethod(host_fn)

def _jac_wrap_staticmethod(host_fn):
    return staticmethod(host_fn)

def _jac_wrap_property(fget, fset, fdel):
    return property(fget, fset, fdel)

# Track B (builtin subclassing) host helpers.
_JAC_BUILTIN_BASES = (
    "int", "str", "float", "bool", "list", "dict",
    "tuple", "set", "frozenset", "bytes", "object",
)

def _jac_builtin_base_name(host_val):
    # If host_val is one of the subclassable builtin TYPES, return its name.
    import builtins
    if isinstance(host_val, type):
        n = getattr(host_val, "__name__", "")
        if n in _JAC_BUILTIN_BASES:
            return n
    return ""

def _jac_construct_builtin(name, raw_args):
    import builtins
    t = getattr(builtins, name)
    try:
        if raw_args:
            return (True, t(*raw_args))
        return (True, t())
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_builtin_new(name, host_cls, raw_args):
    # builtin.__new__(host_cls, *raw_args): the host builtin constructor over a
    # HOST class (namedtuple's dynamic tuple subclass). Keeps the host subclass
    # instance intact instead of collapsing it to a native value.
    import builtins
    t = getattr(builtins, name)
    try:
        return (True, t.__new__(host_cls, *raw_args))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_builtin_new_slot(name):
    import builtins
    if name == "" or name == "object":
        return object.__new__
    return getattr(builtins, name).__new__

def _jac_isinstance_of_builtin(host_val, name):
    # True iff host_val is an instance of the named builtin type.
    import builtins
    t = getattr(builtins, name, None)
    if t is None:
        return False
    return isinstance(host_val, t)

def _jac_host_isinstance(host_obj, host_type):
    try:
        return isinstance(host_obj, host_type)
    except BaseException:
        return False

def _jac_is_exception_type(host_val):
    # True iff host_val is a class deriving from BaseException (used to recognize
    # a user class like `class Exc(Exception)` whose host base proxy is here).
    return isinstance(host_val, type) and issubclass(host_val, BaseException)

def _jac_host_issubclass(host_cls, host_type):
    try:
        return issubclass(host_cls, host_type)
    except BaseException:
        return False

def _jac_host_format(value, spec):
    try:
        return (True, format(value, spec))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_host_binop(kind, a, b):
    import operator
    _NB = {
        0: operator.add, 1: operator.and_, 2: operator.floordiv,
        3: operator.lshift, 4: operator.matmul, 5: operator.mul,
        6: operator.mod, 7: operator.or_, 8: operator.pow,
        9: operator.rshift, 10: operator.sub, 11: operator.truediv,
        12: operator.xor,
    }
    fn = _NB.get(kind)
    if fn is None:
        return (False, "TypeError", "unsupported binary op " + str(kind))
    try:
        return (True, fn(a, b))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_host_convert(value, conv):
    try:
        if conv == 2:
            return (True, repr(value))
        if conv == 3:
            return (True, ascii(value))
        return (True, str(value))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_module_info(absname):
    # Layer 3 module locator: resolve a fully-qualified module name to its source.
    # Returns (status, source, is_pkg, origin):
    #   "py"      -> pure-Python module; `source` is its text, run in-VM proxy-free
    #   "native"  -> built-in / frozen / C extension (no .py); caller host-proxies it
    #   "missing" -> no such module (ModuleNotFoundError)
    # find_spec locates the file the same way CPython's import system does; it may
    # host-import parent packages purely to read their __path__ (never the module
    # itself), which is fine -- only the .py bytes cross back for in-VM execution.
    import importlib.util as _u
    try:
        spec = _u.find_spec(absname)
    except BaseException:
        return ("missing", "", False, "")
    if spec is None:
        return ("missing", "", False, "")
    origin = spec.origin or ""
    is_pkg = spec.submodule_search_locations is not None
    if origin.endswith(".py"):
        try:
            with open(origin, "r", encoding="utf-8") as fh:
                return ("py", fh.read(), is_pkg, origin)
        except OSError:
            return ("native", "", is_pkg, origin)
    return ("native", "", is_pkg, origin)

def _jac_star_names(host_val):
    # `from proxied_module import *` name set: __all__ if defined, else every
    # public (non-underscore) attribute -- CPython's import_all_from rule.
    try:
        alln = getattr(host_val, "__all__", None)
        if alln is not None:
            return (True, [str(n) for n in alln])
        return (True, [n for n in dir(host_val) if not n.startswith("_")])
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_make_host_trampoline(native_fn):
    # Native-callable -> host round-trip. When a native PyFunction crosses the
    # host boundary (to_host), it can't become None -- host machinery that wraps
    # or invokes it (type(name, bases, ns) installing a native __repr__, a
    # classmethod/property over a native function, functools.partial, a callback
    # handed to a proxied C module) needs a REAL callable. Return a host closure
    # that marshals host args back into PyObjs, runs the function in jacpython's
    # own ceval via tp_call, and marshals the result back out. A raised PyError
    # is re-raised as the matching host exception so host control flow sees it.
    import builtins as _b
    def _trampoline(*args, **kwargs):
        pyargs = [from_host(a) for a in args]
        pykwargs = {}
        for k in kwargs:
            pykwargs[k] = from_host(kwargs[k])
        result = native_fn.tp_call(pyargs, pykwargs)
        if isinstance(result, PyError):
            exc = result.exception
            etype = getattr(_b, exc.type_name, None)
            if etype is None or not isinstance(etype, type):
                etype = RuntimeError
            raise etype(exc.message)
        return to_host(result)
    # Present as the wrapped function so introspection (functools.wraps,
    # type()'s method registration, repr) sees the right identity. Keep a
    # back-pointer so a round-trip (from_host of this trampoline) recovers the
    # native function instead of re-wrapping it as an opaque proxy.
    try:
        _trampoline.__name__ = native_fn.name
        _trampoline.__qualname__ = native_fn.code.qualname
        doc = native_fn._func_doc()
        _trampoline.__doc__ = doc.val if isinstance(doc, PyStr) else None
        _trampoline.__jac_native__ = native_fn
    except BaseException:
        pass
    return _trampoline

def _jac_recover_native(raw):
    # If raw is a trampoline we minted, hand back the native function it wraps
    # so a host->native round-trip collapses instead of nesting proxies. Read the
    # marker from the object's OWN __dict__, not via getattr: a bound method
    # delegates attribute access to its __func__, so getattr(bound_method,
    # '__jac_native__') would unwrap it to the UNBOUND native function and lose
    # the receiver -- exactly what breaks `instance.method()`.
    import types as _types
    if not isinstance(raw, _types.FunctionType):
        return None
    return raw.__dict__.get("__jac_native__")

_JAC_EXACT_BUILTINS = (
    int, float, str, bytes, tuple, list, dict, set, frozenset, bool,
)

def _jac_is_builtin_subclass_instance(raw):
    # True iff raw is an instance of a container/scalar builtin whose type is a
    # PROPER SUBCLASS (namedtuple, IntEnum, a user `class X(list)` built on the
    # host, ...). Such an instance must stay a PyHostProxy: converting it to a
    # native PyTuple/PyList/PyInt would discard its real type and its own
    # attributes/descriptors (namedtuple field access, enum .name/.value).
    t = type(raw)
    if t in _JAC_EXACT_BUILTINS:
        return False
    return isinstance(raw, _JAC_EXACT_BUILTINS)
::py::



# ---------------- object model ----------------
glob ADD_MARSHAL: list[int] = [
         227,
         2,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         2,
         0,
         0,
         0,
         3,
         0,
         0,
         0,
         243,
         18,
         0,
         0,
         0,
         128,
         0,
         87,
         1,
         44,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         35,
         0,
         41,
         1,
         78,
         169,
         0,
         41,
         2,
         218,
         1,
         97,
         218,
         1,
         98,
         115,
         2,
         0,
         0,
         0,
         38,
         38,
         218,
         5,
         60,
         65,
         68,
         68,
         62,
         218,
         3,
         97,
         100,
         100,
         114,
         6,
         0,
         0,
         0,
         1,
         0,
         0,
         0,
         115,
         9,
         0,
         0,
         0,
         128,
         0,
         216,
         11,
         12,
         141,
         53,
         128,
         76,
         243,
         0,
         0,
         0,
         0
     ],
     MUL_MARSHAL: list[int] = [
         227,
         2,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         2,
         0,
         0,
         0,
         3,
         0,
         0,
         0,
         243,
         18,
         0,
         0,
         0,
         128,
         0,
         87,
         1,
         44,
         5,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         35,
         0,
         41,
         1,
         78,
         169,
         0,
         41,
         2,
         218,
         1,
         97,
         218,
         1,
         98,
         115,
         2,
         0,
         0,
         0,
         38,
         38,
         218,
         5,
         60,
         77,
         85,
         76,
         62,
         218,
         3,
         109,
         117,
         108,
         114,
         6,
         0,
         0,
         0,
         1,
         0,
         0,
         0,
         115,
         9,
         0,
         0,
         0,
         128,
         0,
         216,
         11,
         12,
         141,
         53,
         128,
         76,
         243,
         0,
         0,
         0,
         0
     ],
     MOD_MARSHAL: list[int] = [
         227,
         2,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         2,
         0,
         0,
         0,
         3,
         0,
         0,
         0,
         243,
         18,
         0,
         0,
         0,
         128,
         0,
         87,
         1,
         44,
         6,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         35,
         0,
         41,
         1,
         78,
         169,
         0,
         41,
         2,
         218,
         1,
         97,
         218,
         1,
         98,
         115,
         2,
         0,
         0,
         0,
         38,
         38,
         218,
         5,
         60,
         77,
         79,
         68,
         62,
         218,
         3,
         109,
         111,
         100,
         114,
         6,
         0,
         0,
         0,
         1,
         0,
         0,
         0,
         115,
         9,
         0,
         0,
         0,
         128,
         0,
         216,
         11,
         12,
         141,
         53,
         128,
         76,
         243,
         0,
         0,
         0,
         0
     ],
     SCALE_MARSHAL: list[int] = [
         227,
         1,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         2,
         0,
         0,
         0,
         3,
         0,
         0,
         0,
         243,
         20,
         0,
         0,
         0,
         128,
         0,
         86,
         0,
         94,
         10,
         44,
         5,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         35,
         0,
         41,
         1,
         233,
         10,
         0,
         0,
         0,
         169,
         0,
         41,
         1,
         218,
         1,
         97,
         115,
         1,
         0,
         0,
         0,
         38,
         218,
         7,
         60,
         83,
         67,
         65,
         76,
         69,
         62,
         218,
         5,
         115,
         99,
         97,
         108,
         101,
         114,
         6,
         0,
         0,
         0,
         1,
         0,
         0,
         0,
         115,
         11,
         0,
         0,
         0,
         128,
         0,
         216,
         11,
         12,
         136,
         114,
         141,
         54,
         128,
         77,
         243,
         0,
         0,
         0,
         0
     ],
     YMODULE_MARSHAL: list[int] = [
         227,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         1,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         243,
         10,
         0,
         0,
         0,
         128,
         0,
         94,
         43,
         116,
         0,
         82,
         1,
         35,
         0,
         41,
         2,
         233,
         6,
         0,
         0,
         0,
         78,
         41,
         1,
         218,
         1,
         121,
         169,
         0,
         243,
         0,
         0,
         0,
         0,
         218,
         9,
         60,
         89,
         77,
         79,
         68,
         85,
         76,
         69,
         62,
         218,
         8,
         60,
         109,
         111,
         100,
         117,
         108,
         101,
         62,
         114,
         7,
         0,
         0,
         0,
         1,
         0,
         0,
         0,
         115,
         10,
         0,
         0,
         0,
         240,
         3,
         1,
         1,
         1,
         216,
         4,
         13,
         130,
         1,
         114,
         5,
         0,
         0,
         0
     ];

# The object core -- the PyObj data-type hierarchy, value/container slots, and
# pure helpers -- lives in the na-clean leaf `objects.jac`. This module (the
# ceval + host bridge + marshal transport) imports it and adds the callable/
# heap/proxy types that OVERRIDE the call/attr slots (cross-module inheritance),
# because those slots re-enter the interpreter or the host and so cannot live in
# the acyclic leaf. See PLAN.md §4 (module-boundary constraint).
import from objects {
    PyObj,
    PyInt,
    PyStr,
    PyBytes,
    PyFloat,
    PyBool,
    PyNoneType,
    PyComplex,
    PySlice,
    PyTuple,
    PyList,
    PyCode,
    PyCell,
    PyDict,
    PyDictIter,
    PySet,
    PyExceptionType,
    PyException,
    PyError,
    PyIter,
    PyHandler,
    bytes_value,
    tuple_value,
    str_value,
    str_values,
    int_values,
    expect_int,
    expect_str,
    expect_float,
    expect_bool,
    list_value,
    concat_items,
    find_name,
    py_none,
    py_error,
    py_exception_type,
    dict_key_repr,
    is_error
}

# The proxy archetype (PLAN.md §5, TODO.md Layer 1): wraps a host object and
# routes every slot across the substrate boundary. Born here on the same slot
# mechanism as PyUserObj so bootstrap-time module proxying (import re -> host
# re wrapped in a PyHostProxy) has its socket from day one, not bolted on later.
# Native module object for Layer 2 shim imports (unittest, test.support).
# Installed via register_shim_module so IMPORT_NAME resolves proxy-free.
obj PyModule(PyObj) {
    has name: str,
        attrs: dict[str, PyObj] = {};

    def tp_getattro(attr: str) -> PyObj {
        if attr in self.attrs {
            return self.attrs[attr];
        }
        if attr == "__dict__" {
            return dict_from_str_map(self.attrs);
        }
        return py_error("AttributeError", attr);
    }

    def tp_setattro(attr: str, value: PyObj) -> PyObj {
        self.attrs[attr] = value;
        return py_none();
    }
}

# Layer 2 shim registry: name -> PyModule. Checked before host import.
glob shim_modules: dict[str, PyObj] = {};

def register_shim_module(name: str, module: PyObj) -> None {
    shim_modules[name] = module;
}

def clear_shim_modules() -> None {
    shim_modules = {};
}

def shim_module_get(name: str) -> PyObj {
    if name in shim_modules {
        return shim_modules[name];
    }
    return py_error("ImportError", "shim module '" + name + "' is not installed");
}

# ---------------- Layer 3: real un-proxied module import ---------------------
# (jac-py/PLAN.md Layer 3 -- "real unittest boots un-proxied".) When
# layer3_active is set, IMPORT_NAME resolves a module by running its actual
# CPython source as bytecode INSIDE jacpython's own ceval, building a native
# PyModule from the resulting namespace -- rather than wrapping the host module
# in a PyHostProxy. C-extension / built-in / frozen modules (no .py source) stay
# host-proxied; every pure-Python module in the closure executes proxy-free. The
# recursion through IMPORT_NAME pulls the whole dependency closure in-VM. This is
# the milestone that proves the interpreter is real: unittest exercises classes,
# descriptors, exceptions, comprehensions, and the full language surface.

glob sys3_modules: dict[str, PyObj] = {};
# Modules deliberately kept host-proxied even though pure-Python source exists,
# because they rely on VM features not yet native (custom metaclasses: enum's
# EnumType drives __prepare__/__new__/__iter__). Proxying a metaclass-heavy leaf
# is the same pragmatic line drawn for C extensions -- it keeps the rest of the
# closure (unittest's own code) running proxy-free. Revisit when metaclasses land.
glob layer3_force_host: list[str] = ["enum"];
# One-slot holder rather than a bare `glob layer3_active: bool` -- a scalar glob
# rebound inside a function is scoped local and never persists (see PLAN/memory);
# a list mutated in place does. Read via layer3_is_active() on the IMPORT_NAME path.
glob layer3_flag: list[bool] = [False];

def set_layer3_active(flag: bool) -> None {
    layer3_flag[0] = flag;
}

def layer3_is_active() -> bool {
    return layer3_flag[0];
}

def clear_sys3_modules() -> None {
    sys3_modules = {};
}

# Drop one key from the module cache (used to un-register a module whose in-VM
# execution raised, so a retry re-runs it instead of seeing a half-built shell).
def _sys3_forget(name: str) -> None {
    if name in sys3_modules {
        del sys3_modules[name];
    }
}

def _last_component(dotted: str) -> str {
    parts = dotted.split(".");
    return parts[len(parts) - 1];
}

def _parent_package(dotted: str) -> str {
    parts = dotted.split(".");
    if len(parts) <= 1 {
        return "";
    }
    out = parts[0];
    i = 1;
    while i < len(parts) - 1 {
        out = out + "." + parts[i];
        i = i + 1;
    }
    return out;
}

# Resolve a (possibly relative) import to its absolute module name. `level` is the
# IMPORT_NAME dot-count: 0 = absolute, 1 = current package, 2 = its parent, ...
def _resolve_relative(current_package: str, name: str, level: int) -> str {
    if level == 0 {
        return name;
    }
    parts = current_package.split(".");
    drop = level - 1;
    keep = len(parts) - drop;
    if keep < 0 {
        keep = 0;
    }
    base = "";
    i = 0;
    while i < keep {
        if base == "" {
            base = parts[i];
        } else {
            base = base + "." + parts[i];
        }
        i = i + 1;
    }
    if name == "" {
        return base;
    }
    if base == "" {
        return name;
    }
    return base + "." + name;
}

# Import one fully-qualified module natively, caching it in sys3_modules. Parent
# packages import first (and the submodule is bound as an attribute on its
# parent, per CPython). Pure-Python source runs in-VM; anything else is proxied.
def import_native(absname: str) -> PyObj {
    if absname in sys3_modules {
        return sys3_modules[absname];
    }
    if absname in shim_modules {
        return shim_modules[absname];
    }
    if absname in layer3_force_host {
        star2: list[PyObj] = [PyStr(t="str", val="*")];
        forced = host_import(absname, PyList(t="list", items=star2));
        if is_error(forced) {
            return forced;
        }
        sys3_modules[absname] = forced;
        return forced;
    }
    info = _jac_module_info(absname);
    status = str(info[0]);
    if status == "missing" {
        return py_error("ModuleNotFoundError", "No module named '" + absname + "'");
    }
    if status == "native" {
        # C extension / built-in / frozen: no source to run in-VM. Proxy the real
        # host module (fromlist truthy so importlib returns the named submodule,
        # not just the top package).
        star: list[PyObj] = [PyStr(t="str", val="*")];
        proxy = host_import(absname, PyList(t="list", items=star));
        if is_error(proxy) {
            return proxy;
        }
        sys3_modules[absname] = proxy;
        return proxy;
    }
    source = str(info[1]);
    is_pkg = info[2] as bool;
    origin = str(info[3]);
    parent = _parent_package(absname);
    if parent != "" {
        pmod = import_native(parent);
        if is_error(pmod) {
            return pmod;
        }
    }
    pkg_name = parent;
    if is_pkg {
        pkg_name = absname;
    }
    modglobals: dict[str, PyObj] = {
        "__name__": PyStr(t="str", val=absname),
        "__package__": PyStr(t="str", val=pkg_name),
        "__file__": PyStr(t="str", val=origin),
        "__doc__": py_none(),
    };
    module = PyModule(t="module", name=absname, attrs=modglobals);
    # Register the (still-executing) module before running its body so a circular
    # import mid-closure resolves to this partial module instead of re-entering.
    sys3_modules[absname] = module;
    outcome = exec_code(unmarshal(host_compile_marshal(source)), [], modglobals);
    if is_error(outcome) {
        _sys3_forget(absname);
        return outcome;
    }
    # attrs aliases modglobals (same dict), so STORE_NAME writes are already live.
    if parent != "" and isinstance(sys3_modules[parent], PyModule) {
        (sys3_modules[parent] as PyModule).attrs[_last_component(absname)] = module;
    }
    return module;
}

# The public names `from module import *` binds: a native PyModule's __all__ (or
# its non-underscore keys); a proxied module's __all__/dir() via the host.
def import_star_names(module: PyObj) -> list[str] {
    if isinstance(module, PyModule) {
        attrs = (module as PyModule).attrs;
        if "__all__" in attrs {
            # __all__ is commonly a list literal (not only a tuple); read either.
            allobj = attrs["__all__"];
            items: list[PyObj] = [];
            if isinstance(allobj, PyList) {
                items = (allobj as PyList).items;
            } else {
                items = tuple_value(allobj);
            }
            allnames: list[str] = [];
            for it in items {
                allnames.append(str_value(it));
            }
            return allnames;
        }
        out: list[str] = [];
        for k in attrs {
            if not k.startswith("_") {
                out.append(k);
            }
        }
        return out;
    }
    result = _jac_star_names(to_host(module));
    if host_result_ok(result) {
        names: list[str] = [];
        for n in result[1] {
            names.append(str(n));
        }
        return names;
    }
    return [];
}

# INTRINSIC_IMPORT_STAR: bind every exported name of `module` into `globals`.
def import_star_into(module: PyObj, globals: dict[str, PyObj]) -> PyObj {
    for nm in import_star_names(module) {
        val = py_attr(module, nm);
        if is_error(val) {
            return val;
        }
        globals[nm] = val;
    }
    return py_none();
}

# IMPORT_NAME entry point under Layer 3. Mirrors CPython's __import__ contract:
# with no fromlist, `import a.b.c` binds and returns the TOP package `a`; with a
# fromlist, returns the named module and ensures each requested submodule exists.
def py_import_name(
    name: str, fromlist: PyObj, level: int, globals: dict[str, PyObj]
) -> PyObj {
    current_package = "";
    if "__package__" in globals {
        pkg = globals["__package__"];
        if isinstance(pkg, PyStr) {
            current_package = (pkg as PyStr).val;
        }
    }
    if current_package == "" and "__name__" in globals {
        nm = globals["__name__"];
        if isinstance(nm, PyStr) {
            current_package = (nm as PyStr).val;
        }
    }
    absname = _resolve_relative(current_package, name, level);
    mod = import_native(absname);
    if is_error(mod) {
        return mod;
    }
    has_fromlist = False;
    from_names: list[str] = [];
    if fromlist.t != "none" {
        from_names = str_values(fromlist);
        if len(from_names) > 0 {
            has_fromlist = True;
        }
    }
    if not has_fromlist {
        if level == 0 and "." in absname {
            # `import a.b.c` returns the top package a (STORE_NAME binds `a`).
            top = absname.split(".")[0];
            return import_native(top);
        }
        return mod;
    }
    # `from pkg import x, y`: x/y may be submodules that aren't imported yet. Try
    # to import each as a submodule; a plain attribute (not a module) simply
    # isn't found here and is resolved later by IMPORT_FROM off `mod`.
    for item in from_names {
        if item == "*" {
            continue;
        }
        existing = py_attr(mod, item);
        if is_error(existing) {
            sub = import_native(absname + "." + item);
            # A ModuleNotFoundError just means `item` is a plain attribute, not a
            # submodule -- IMPORT_FROM resolves it off `mod`. Any other error is a
            # real failure importing the submodule and must propagate.
            if is_error(sub)
            and (sub as PyError).exception.type_name != "ModuleNotFoundError" {
                return sub;
            }
        }
    }
    return mod;
}

obj PyHostProxy(PyObj) {
    has val: any;

    def tp_getattro(name: str) -> PyObj {
        # object.__new__ builds a plain in-VM instance (so a user class's __new__
        # that calls it produces a PyUserObj, not a host object). Narrow to the
        # exact `object` type; every other type's __new__ stays host-routed.
        if name == "__new__" and _jac_is_object_type(self.val) {
            return PyNativeNew(t="native_new", base_name="object");
        }
        # A subclassable builtin's __new__ (str.__new__, int.__new__, ...) builds a
        # native subclass instance boxing that value, so `str.__new__(EnumCls, v)`
        # (enum member creation for a str/int mixin) yields a PyUserObj tagged with
        # the native class -- not a host str.__new__(None) on a lost to_host class.
        if name == "__new__" {
            builtin_name: str = str(_jac_builtin_base_name(self.val));
            if builtin_name != "" {
                return PyNativeNew(t="native_new", base_name=builtin_name);
            }
        }
        return host_getattr(self, name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        return host_setattr(self, name, value);
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return py_call_host(self, args, kwargs);
    }

    def tp_hashkey -> str {
        return _jac_host_hashkey(self.val);
    }

    def mp_subscript(index: PyObj) -> PyObj {
        return host_getitem(self, index);
    }

    def tp_iter -> PyObj {
        return host_iter(self);
    }
}

obj PyClass(PyObj) {
    has name: str,
        attrs: dict[str, PyObj],
        bases: list[PyObj] = [],
        native_base: str = "",
        # The type OF this class (its metaclass). None means the default `type`.
        # A user metaclass (EnumType, ABCMeta) is recorded here by type.__new__ so
        # `class Sub(Base)` can re-derive it from a base and re-run the protocol.
        metaclass: any = None;

    # Attribute lookup walks the MRO (self first, then bases) so an inherited
    # method/attr is visible on a subclass. Instance access binds via PyUserObj.
    def tp_getattro(name: str) -> PyObj {
        found = class_lookup_attr(self, name);
        if not is_error(found) {
            # Class-level access: a classmethod binds this class, a staticmethod
            # unwraps, a property object is returned as-is (no instance to invoke).
            return descriptor_get(found, py_none(), self);
        }
        # Standard type dunders CPython always answers: a missing docstring is
        # None, and __name__/__qualname__ report the class name.
        if name == "__doc__" {
            return py_none();
        }
        if name == "__name__" or name == "__qualname__" {
            return PyStr(t="str", val=self.name);
        }
        if name == "__dict__" {
            return dict_from_str_map(self.attrs);
        }
        if name == "__mro__" {
            mro_items: list[PyObj] = [];
            for klass in class_mro(self) {
                mro_items.append(klass);
            }
            return PyTuple(t="tuple", items=mro_items);
        }
        if name == "__bases__" {
            return PyTuple(t="tuple", items=self.bases);
        }
        if name == "__base__" {
            if len(self.bases) > 0 {
                return self.bases[0];
            }
            return py_none();
        }
        # A class with no user __new__ inherits object.__new__ (or the builtin base
        # constructor). Attribute access -- unlike class_lookup_attr, which drives
        # construction -- exposes it so `Cls.__new__` reads and compares (enum's
        # _find_new_ tests target against object.__new__/Enum.__new__).
        if name == "__new__" {
            base = self.native_base;
            if base == "" or base == "type" {
                base = "object";
            }
            return PyNativeNew(t="native_new", base_name=base);
        }
        # A method defined on the metaclass (EnumType._add_member_, __call__) is
        # accessible on the class itself, bound to it -- the class is an instance
        # of its metaclass.
        meta_found = self._meta_dunder(name);
        if not is_error(meta_found) {
            return meta_found;
        }
        return py_error("AttributeError", name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        self.attrs[name] = value;
        return py_none();
    }

    # A class is hashable by identity (type-keyed dispatch tables, base_chain sets
    # in enum's _find_data_type_). Distinct classes get distinct buckets.
    def tp_hashkey -> str {
        return "obj:" + str(id(self));
    }

    # A metaclass instance dunder: looked up on the class's metaclass MRO and bound
    # to this class. `for m in EnumColor` dispatches EnumType.__iter__(cls); the
    # same channel serves __getitem__/__contains__/__len__ on a class.
    def _meta_dunder(name: str) -> PyObj {
        if self.metaclass is not None and isinstance(self.metaclass, PyClass) {
            found = class_lookup_attr(self.metaclass as PyClass, name);
            if not is_error(found) {
                return bind_attribute(found, self);
            }
        }
        return py_error("AttributeError", name);
    }

    def tp_iter -> PyObj {
        it = self._meta_dunder("__iter__");
        if is_error(it) {
            return py_error("TypeError", "object is not iterable");
        }
        return it.tp_call([], {});
    }

    def mp_subscript(index: PyObj) -> PyObj {
        gi = self._meta_dunder("__getitem__");
        if is_error(gi) {
            return py_error("TypeError", "object is not subscriptable");
        }
        return gi.tp_call([index], {});
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        # A python-level __new__ (common on builtin subclasses that control their
        # boxed value, e.g. re._constants._NamedIntConstant) governs construction:
        # call __new__(cls, *args) and use its return value. __init__ then runs
        # only if __new__ returned an instance of this class (CPython's rule).
        user_new = class_lookup_attr(self, "__new__");
        if not is_error(user_new) and isinstance(user_new, PyFunction) {
            new_args: list[PyObj] = [self];
            for a in args {
                new_args.append(a);
            }
            made = py_invoke(user_new, new_args, kwargs);
            if is_error(made) {
                return made;
            }
            if isinstance(made, PyUserObj)
                and instance_of_class(made as PyUserObj, self) {
                init2 = class_lookup_attr(self, "__init__");
                if not is_error(init2) and isinstance(init2, PyFunction) {
                    ir = bind_attribute(init2, made).tp_call(args, kwargs);
                    if ir.t == "error" {
                        return ir;
                    }
                }
            }
            return made;
        }
        # A subclass of a builtin (native_base != "") boxes the underlying value.
        # An immutable base (int/str/...) takes its value at __new__ time from the
        # args. A mutable base (dict/list/set) WITH a user __init__ is created empty
        # -- __init__ (which typically calls super().__init__(...)) fills it -- so
        # `class D(dict): def __init__(self, name): super().__init__()` boxes an
        # empty dict, not dict(name). Without a user __init__ the args fill it
        # directly (MyList([1,2,3])).
        init = class_lookup_attr(self, "__init__");
        has_user_init = not is_error(init);
        boxed: PyObj = py_none();
        if self.native_base != "" {
            box_args = args;
            if has_user_init and is_mutable_base(self.native_base) {
                box_args = [];
            }
            boxed = construct_native_base(self.native_base, box_args);
            if is_error(boxed) {
                return boxed;
            }
        }
        instance = PyUserObj(t="instance", cls=self, attrs={}, base=boxed);
        if has_user_init {
            initialized = bind_attribute(init, instance).tp_call(args, kwargs);
            if initialized.t == "error" {
                return initialized;
            }
        }
        return instance;
    }
}

# The generic heap-type object (PLAN.md §5): one archetype for every user
# class instance; its slots resolve through instance/class dict lookup rather
# than a per-type vtable -- exactly the static-vs-heap line CPython draws.
obj PyUserObj(PyObj) {
    has cls: PyClass,
        attrs: dict[str, PyObj],
        base: any = None;

    # The boxed builtin value (int/str/...) for a builtin subclass, or a
    # PyNoneType sentinel for a plain user class. _has_base tells them apart.
    def _has_base -> bool {
        return self.base is not None and not isinstance(self.base, PyNoneType);
    }

    def _base_obj -> PyObj {
        return self.base as PyObj;
    }

    def tp_getattro(name: str) -> PyObj {
        # A property is a data descriptor: it wins over the instance dict, so
        # `o.v` runs the getter even after `o.v = ...` routed through the setter.
        classattr = class_lookup_attr(self.cls, name);
        if isinstance(classattr, PyProperty) {
            return descriptor_get(classattr, self, self.cls);
        }
        if name in self.attrs {
            return bind_attribute(self.attrs[name], self);
        }
        found = classattr;
        if not is_error(found) {
            # Instance access: bind a method, invoke a property getter, unwrap a
            # staticmethod, or bind a classmethod to the instance's class.
            return descriptor_get(found, self, self.cls);
        }
        # Fall through to the boxed builtin value's own attributes/methods
        # (str.upper on a str subclass, etc.).
        if self._has_base() {
            return py_attr(self._base_obj(), name);
        }
        # A plain instance's __dict__ is its own attribute namespace (an explicit
        # `self.__dict__ = ...` assignment, handled above, wins over this).
        if name == "__dict__" {
            return dict_from_str_map(self.attrs);
        }
        return py_error("AttributeError", name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        # A property with a setter is a data descriptor: assignment routes through
        # fset instead of writing the instance dict.
        classattr = class_lookup_attr(self.cls, name);
        if isinstance(classattr, PyProperty) {
            p = classattr as PyProperty;
            if p.fset is not None {
                res = py_invoke(p.fset as PyObj, [self, value], {});
                if is_error(res) {
                    return res;
                }
                return py_none();
            }
            return py_error("AttributeError", "can't set attribute '" + name + "'");
        }
        self.attrs[name] = value;
        return py_none();
    }

    # ---- boxed-builtin slot delegation (subclass of int/str/list/...) --------
    # When the class dict doesn't override a slot, a builtin subclass behaves as
    # its boxed value: MyInt(5)+1 == 6, MyInt(5) is a valid dict key, etc. The
    # right operand is unwrapped too so MyInt(5)+MyInt(1) works.
    def nb_binop(kind: int, other: PyObj) -> PyObj {
        return user_binop(kind, self, other);
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        return user_compare(kind, self, other);
    }

    def to_index -> PyObj {
        # A builtin-int subclass instance (re._constants._NamedIntConstant, an
        # IntEnum member, ...) indexes as its boxed int.
        if self._has_base() {
            return self._base_obj().to_index();
        }
        return py_error("TypeError", "object cannot be interpreted as an integer");
    }

    def tp_hashkey -> str {
        if self._has_base() {
            return self._base_obj().tp_hashkey();
        }
        # A user-defined __hash__ keys the object by value (shares the numeric
        # "n:" namespace so hash()-equal objects bucket together); otherwise a
        # plain user object hashes by identity, distinct per object.
        if user_has_dunder(self, "__hash__") {
            h = call_user_dunder(self, "__hash__", []);
            if isinstance(h, PyInt) {
                return "n:" + str((h as PyInt).val);
            }
        }
        return "obj:" + str(id(self));
    }

    def tp_bool -> bool {
        if self._has_base() {
            return self._base_obj().tp_bool();
        }
        return True;
    }

    def tp_iter -> PyObj {
        # A user-defined __iter__ returns the iterator (driven by FOR_ITER/SEND
        # via its __next__); fall back to a boxed builtin base, else not iterable.
        if user_has_dunder(self, "__iter__") {
            return call_user_dunder(self, "__iter__", []);
        }
        if self._has_base() {
            return self._base_obj().tp_iter();
        }
        return py_error("TypeError", "object is not iterable");
    }

    def mp_subscript(index: PyObj) -> PyObj {
        if user_has_dunder(self, "__getitem__") {
            return call_user_dunder(self, "__getitem__", [index]);
        }
        if self._has_base() {
            return self._base_obj().mp_subscript(index);
        }
        return py_error("TypeError", "object is not subscriptable");
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        if user_has_dunder(self, "__setitem__") {
            r = call_user_dunder(self, "__setitem__", [index, value]);
            if is_error(r) {
                return r;
            }
            return py_none();
        }
        if self._has_base() {
            return self._base_obj().mp_ass_subscript(index, value);
        }
        return py_error("TypeError", "object does not support item assignment");
    }

    def mp_del_subscript(index: PyObj) -> PyObj {
        if user_has_dunder(self, "__delitem__") {
            r = call_user_dunder(self, "__delitem__", [index]);
            if is_error(r) {
                return r;
            }
            return py_none();
        }
        if self._has_base() {
            return self._base_obj().mp_del_subscript(index);
        }
        return py_error("TypeError", "object does not support item deletion");
    }
}

obj PyBoundMethod(PyObj) {
    has function: PyObj,
        receiver: PyObj;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        call_args: list[PyObj] = [self.receiver];
        call_args.extend(args);
        return self.function.tp_call(call_args, kwargs);
    }

    # A bound method exposes __func__/__self__ and otherwise forwards attribute
    # reads (__name__, __qualname__, __doc__) to the underlying function.
    def tp_getattro(name: str) -> PyObj {
        if name == "__func__" {
            return self.function;
        }
        if name == "__self__" {
            return self.receiver;
        }
        return py_attr(self.function, name);
    }
}

obj PyBuildClass(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return py_build_class(args, kwargs);
    }
}

# ---------------- native descriptors: classmethod / staticmethod / property ----
# These are pervasive across the stdlib closure (enum, typing, abc, dataclasses).
# Each is a descriptor: attribute lookup on a class/instance resolves it through
# descriptor_get, which binds the class (classmethod), unwraps (staticmethod), or
# invokes the getter (property).
obj PyClassMethod(PyObj) {
    has func: PyObj;

    # `__func__` exposes the wrapped function (namedtuple rewrites
    # `_make.__func__.__qualname__`; functools/abc read it too).
    def tp_getattro(name: str) -> PyObj {
        if name == "__func__" {
            return self.func;
        }
        return py_attr(self.func, name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        return self.func.tp_setattro(name, value);
    }
}

obj PyStaticMethod(PyObj) {
    has func: PyObj;

    def tp_getattro(name: str) -> PyObj {
        if name == "__func__" {
            return self.func;
        }
        return py_attr(self.func, name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        return self.func.tp_setattro(name, value);
    }
}

obj PyProperty(PyObj) {
    has fget: any = None,
        fset: any = None,
        fdel: any = None;

    # `@x.setter` / `.getter` / `.deleter` each yield a modifier that rebuilds the
    # property with one accessor replaced.
    def tp_getattro(name: str) -> PyObj {
        if name == "setter" {
            return PyPropModifier(t="propmod", prop=self, which="set");
        }
        if name == "getter" {
            return PyPropModifier(t="propmod", prop=self, which="get");
        }
        if name == "deleter" {
            return PyPropModifier(t="propmod", prop=self, which="del");
        }
        if name == "fget" {
            return self.fget if self.fget is not None else py_none();
        }
        return py_error("AttributeError", name);
    }
}

obj PyPropModifier(PyObj) {
    has prop: PyProperty,
        which: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        fn = args[0];
        p = self.prop;
        if self.which == "set" {
            return PyProperty(t="property", fget=p.fget, fset=fn, fdel=p.fdel);
        }
        if self.which == "del" {
            return PyProperty(t="property", fget=p.fget, fset=p.fset, fdel=fn);
        }
        return PyProperty(t="property", fget=fn, fset=p.fset, fdel=p.fdel);
    }
}

# object.__init__ / a builtin's default __init__: accepts any args, does nothing.
# Reached when `inst.__init__(*args)` runs on an object whose class defines no
# __init__ (enum calls enum_member.__init__(*args) unconditionally).
obj PyNoOpInit(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return py_none();
    }
}

obj PyClassMethodCtor(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "classmethod expected 1 argument");
        }
        return PyClassMethod(t="classmethod", func=args[0]);
    }
}

obj PyStaticMethodCtor(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "staticmethod expected 1 argument");
        }
        return PyStaticMethod(t="staticmethod", func=args[0]);
    }
}

obj PyPropertyCtor(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        fget: PyObj = py_none();
        fset: PyObj = py_none();
        fdel: PyObj = py_none();
        if len(args) >= 1 { fget = args[0]; }
        if len(args) >= 2 { fset = args[1]; }
        if len(args) >= 3 { fdel = args[2]; }
        if "fget" in kwargs { fget = kwargs["fget"]; }
        if "fset" in kwargs { fset = kwargs["fset"]; }
        if "fdel" in kwargs { fdel = kwargs["fdel"]; }
        return PyProperty(
            t="property",
            fget=fget if not isinstance(fget, PyNoneType) else None,
            fset=fset if not isinstance(fset, PyNoneType) else None,
            fdel=fdel if not isinstance(fdel, PyNoneType) else None
        );
    }
}

# The descriptor protocol for attribute access. `instance` is the object the
# attribute was fetched from (None for class-level access); `owner` is the class
# that supplied the attribute. Plain functions bind to a real instance and stay
# unbound on class access; the native descriptors do their own binding.
def descriptor_get(value: PyObj, instance: PyObj, owner: PyObj) -> PyObj {
    if isinstance(value, PyClassMethod) {
        return PyBoundMethod(
            t="bound_method", function=(value as PyClassMethod).func, receiver=owner
        );
    }
    if isinstance(value, PyStaticMethod) {
        return (value as PyStaticMethod).func;
    }
    if isinstance(value, PyProperty) {
        prop = value as PyProperty;
        if not isinstance(instance, PyNoneType) {
            if prop.fget is None {
                return py_error("AttributeError", "unreadable attribute");
            }
            return py_invoke(prop.fget as PyObj, [instance], {});
        }
        return value;
    }
    if value.t == "function" and not isinstance(instance, PyNoneType) {
        return PyBoundMethod(t="bound_method", function=value, receiver=instance);
    }
    return value;
}

obj PyFunction(PyObj) {
    has code: PyCode,
        globals: dict[str, PyObj],
        name: str,
        defaults: list[PyObj] = [],
        kwdefaults: dict[str, PyObj] = {},
        closure: list[PyCell] = [],
        # The function's writable __dict__ + overridable dunders. functools.wraps
        # / update_wrapper copy __module__/__name__/__qualname__/__doc__ and set
        # __wrapped__ here, so decorators (pervasive in the unittest closure) work.
        attrs: dict[str, PyObj] = {};

    def _func_doc -> PyObj {
        if len(self.code.consts) > 0 and isinstance(self.code.consts[0], PyStr) {
            return self.code.consts[0];
        }
        return py_none();
    }

    def tp_getattro(name: str) -> PyObj {
        if name in self.attrs {
            return self.attrs[name];
        }
        if name == "__name__" {
            return PyStr(t="str", val=self.name);
        }
        if name == "__qualname__" {
            return PyStr(t="str", val=self.code.qualname);
        }
        if name == "__doc__" {
            return self._func_doc();
        }
        if name == "__module__" {
            if "__name__" in self.globals {
                return self.globals["__name__"];
            }
            return py_none();
        }
        if name == "__defaults__" {
            if len(self.defaults) == 0 {
                return py_none();
            }
            return PyTuple(t="tuple", items=self.defaults);
        }
        if name == "__code__" {
            return self.code;
        }
        if name == "__dict__" {
            # functools.wraps / update_wrapper reads and updates a function's
            # __dict__ (WRAPPER_UPDATES). Snapshot of the writable attr map.
            return dict_from_str_map(self.attrs);
        }
        if name == "__wrapped__" {
            return py_error("AttributeError", name);
        }
        return py_error("AttributeError", name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        self.attrs[name] = value;
        return py_none();
    }

    # Functions are hashable by identity (enum keys candidate __new__ callables in
    # a set; dispatch tables key on functions).
    def tp_hashkey -> str {
        return "obj:" + str(id(self));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return exec_code_frame(
            self.code,
            args,
            kwargs,
            self.globals,
            {},
            self.closure,
            self.defaults,
            self.kwdefaults
        );
    }
}

def host_result_ok(result: any) -> bool {
    return result[0] == True;
}

def from_host(raw: any) -> PyObj {
    if raw is None {
        return py_none();
    }
    # A host instance whose type is a PROPER subclass of a builtin container/
    # scalar (namedtuple, IntEnum, a host-built `class X(list)`) must not be
    # flattened into a native PyTuple/PyList/PyInt -- that would erase its real
    # type and its own descriptors. Keep it as a proxy so p.x / .name / repr all
    # route back to the host object. (A trampoline we minted is recovered first.)
    if _jac_is_builtin_subclass_instance(raw) {
        recovered = _jac_recover_native(raw);
        if recovered is not None {
            return recovered;
        }
        return PyHostProxy(t="host", val=raw);
    }
    if isinstance(raw, bool) {
        return PyBool(t="bool", val=raw);
    }
    if isinstance(raw, int) {
        return PyInt(t="int", val=raw);
    }
    if isinstance(raw, float) {
        return PyFloat(t="float", val=raw);
    }
    if isinstance(raw, str) {
        return PyStr(t="str", val=raw);
    }
    if isinstance(raw, bytes) {
        values: list[int] = [];
        for item in raw {
            values.append(item);
        }
        return PyBytes(t="bytes", val=values);
    }
    if isinstance(raw, range) {
        values: list[PyObj] = [];
        for item in raw {
            values.append(PyInt(t="int", val=item));
        }
        return PyList(t="list", items=values);
    }
    if isinstance(raw, list) {
        values: list[PyObj] = [];
        for item in raw {
            values.append(from_host(item));
        }
        return PyList(t="list", items=values);
    }
    if isinstance(raw, tuple) {
        values: list[PyObj] = [];
        for item in raw {
            values.append(from_host(item));
        }
        return PyTuple(t="tuple", items=values);
    }
    if isinstance(raw, dict) {
        # Native PyDict now keys on the hash-key protocol, so any hashable key
        # (int, tuple, float, ...) lands natively. A key whose from_host wrapper
        # is unhashable (e.g. an opaque host object) keeps the whole dict opaque
        # as a PyHostProxy -- it round-trips through to_host unchanged.
        native = PyDict(t="dict", items={});
        for key in raw {
            keyobj = from_host(key);
            if keyobj.tp_hashkey() == "" {
                return PyHostProxy(t="host", val=raw);
            }
            native.dict_set(keyobj, from_host(raw[key]));
        }
        return native;
    }
    if isinstance(raw, frozenset) {
        fs = PySet(t="frozenset", items={}, frozen=True);
        for member in raw {
            memberobj = from_host(member);
            if memberobj.tp_hashkey() == "" {
                return PyHostProxy(t="host", val=raw);
            }
            fs.set_add(memberobj);
        }
        return fs;
    }
    if isinstance(raw, set) {
        ns = PySet(t="set", items={}, frozen=False);
        for member in raw {
            memberobj = from_host(member);
            if memberobj.tp_hashkey() == "" {
                return PyHostProxy(t="host", val=raw);
            }
            ns.set_add(memberobj);
        }
        return ns;
    }
    # A host trampoline coming back home (e.g. a native __new__ that host type()
    # stored, then handed back on class construction) recovers its original
    # native function rather than nesting host->native->host indirection.
    recovered = _jac_recover_native(raw);
    if recovered is not None {
        return recovered;
    }
    return PyHostProxy(t="host", val=raw);
}

def to_host(value: PyObj) -> any {
    match value {
        case PyNoneType():
            return None;

        case PyBool():
            return value.val;

        case PyInt():
            return value.val;

        case PyFloat():
            return value.val;

        case PyComplex():
            return complex(value.real, value.imag);

        case PyStr():
            return value.val;

        case PyBytes():
            return bytes(value.val);

        case PyTuple():
            result: list[any] = [];
            for item in value.items {
                result.append(to_host(item));
            }
            return tuple(result);

        case PyList():
            result: list[any] = [];
            for item in value.items {
                result.append(to_host(item));
            }
            return result;

        case PyDict():
            result: dict[any, any] = {};
            for hk in value.items {
                entry = value.items[hk];
                result[to_host(entry.key)] = to_host(entry.value);
            }
            return result;

        case PySet():
            members: list[any] = [];
            for member in value.set_members() {
                members.append(to_host(member));
            }
            if value.frozen {
                return frozenset(members);
            }
            return set(members);

        case PySlice():
            return slice(
                to_host(value.start), to_host(value.stop), to_host(value.step)
            );

        case PyFunction():
            # A native function crossing to the host becomes a trampoline that
            # calls back into ceval (see _jac_make_host_trampoline). This is what
            # lets host type()/classmethod/property/functools wrap and later
            # invoke jacpython functions -- the round-trip that unblocks
            # namedtuple's dynamic class creation and decorator machinery.
            return _jac_make_host_trampoline(value);

        case PyNativeNew():
            # object.__new__ / tuple.__new__ crossing to the host (namedtuple binds
            # `_tuple_new = tuple.__new__`) becomes the real host builtin __new__.
            return _jac_builtin_new_slot(value.base_name);

        case PyClassMethod():
            # A native classmethod handed to host type()/a host class becomes a
            # real host classmethod over the wrapped function's trampoline, so
            # `Cls.cmeth(...)` dispatched by the host binds the class correctly.
            return _jac_wrap_classmethod(to_host(value.func));

        case PyStaticMethod():
            return _jac_wrap_staticmethod(to_host(value.func));

        case PyProperty():
            fget = to_host(value.fget as PyObj) if value.fget is not None else None;
            fset = to_host(value.fset as PyObj) if value.fset is not None else None;
            fdel = to_host(value.fdel as PyObj) if value.fdel is not None else None;
            return _jac_wrap_property(fget, fset, fdel);

        case PyHostProxy():
            return value.val;

        case PyUserObj():
            # A builtin subclass reaching the host boundary (len/print/format)
            # presents as its boxed value; a plain user object has no host form.
            if value._has_base() {
                return to_host(value._base_obj());
            }
            return None;

        case PyGenerator():
            # A native genexpr reaching the host boundary (list(gen)/tuple(gen)/
            # sum(gen)/...) is drained through the real suspend/resume machinery
            # into a host list, which every iterable-consuming builtin accepts.
            drained = gen_drain(value);
            return to_host(drained);

        case PyDictView():
            # Rebuild a real host dict and hand back the matching live view, so
            # both iteration (list()/sorted()/set()) AND repr round-trip: repr of
            # the result is `dict_keys([...])`/`dict_values([...])`/`dict_items([
            # ...])`, not a bare list. Order follows the dict's insertion order.
            hd: dict[any, any] = {};
            for hk in value.d.items {
                entry = value.d.items[hk];
                hd[to_host(entry.key)] = to_host(entry.value);
            }
            if value.mode == "values" {
                return hd.values();
            }
            if value.mode == "items" {
                return hd.items();
            }
            return hd.keys();

    }
    return None;
}

def host_builtin(name: str) -> PyObj {
    if name == "Exception"
    or name == "BaseException"
    or name == "ValueError"
    or name == "TypeError"
    or name == "KeyError"
    or name == "IndexError"
    or name == "AttributeError"
    or name == "NameError"
    or name == "ZeroDivisionError"
    or name == "ImportError"
    or name == "StopIteration"
    or name == "StopAsyncIteration"
    or name == "GeneratorExit"
    or name == "RuntimeError" {
        return py_exception_type(name);
    }
    # next()/iter() are handled natively so a native generator or iterator is
    # driven one step in-VM instead of being drained across the host boundary.
    # id() is native so it reports stable object identity (consistent with `is`)
    # rather than the host id of a throwaway to_host value. len() reads a native
    # container's own size (and dispatches __len__) instead of counting a
    # to_host copy, which drops plain user objects held as members/keys.
    # getattr/setattr/hasattr must be native: they route through py_attr so a
    # native object's own attributes (a PyFunction's __module__, a PyModule's
    # members, a user class's descriptors) are seen, instead of host getattr on
    # a lossy to_host copy. This is load-bearing for the import closure, where
    # decorators (functools.wraps, reprlib.recursive_repr) copy dunders via
    # getattr(fn, '__module__').
    if name == "next" or name == "iter" or name == "id"
    or name == "len"
    or name == "isinstance" or name == "issubclass"
    or name == "getattr" or name == "setattr" or name == "hasattr"
    or name == "delattr"
    or name == "globals" {
        # globals() must be native: it returns a LIVE view of the running frame's
        # module namespace, so `globals().update({...})` / `globals()[k] = v`
        # (module init idioms, e.g. re._constants) bind real module globals that a
        # later LOAD_GLOBAL can see. The call site in run_frame supplies the ns.
        return PyNativeBuiltin(t="native_builtin", name=name);
    }
    # classmethod/staticmethod/property are native descriptors so a method decorated
    # with them is resolved in-VM (bound to the class, unwrapped, or invoked as a
    # getter) instead of being frozen into an uncallable host wrapper. Pervasive in
    # enum/abc/typing/dataclasses.
    if name == "classmethod" {
        return PyClassMethodCtor(t="classmethod_ctor");
    }
    if name == "staticmethod" {
        return PyStaticMethodCtor(t="staticmethod_ctor");
    }
    if name == "property" {
        return PyPropertyCtor(t="property_ctor");
    }
    result = _jac_host_builtin(name);
    if host_result_ok(result) {
        return PyHostProxy(t="host", val=result[1]);
    }
    return py_error(str(result[1]), str(result[2]));
}

def host_import(name: str, fromlist: PyObj) -> PyObj {
    if name in shim_modules {
        return shim_modules[name];
    }
    result = _jac_host_import(name, to_host(fromlist));
    if host_result_ok(result) {
        return PyHostProxy(t="host", val=result[1]);
    }
    return py_error(str(result[1]), str(result[2]));
}

# f-string / format machinery. Formatting is delegated to host CPython's
# format()/repr()/ascii() during bootstrap -- the __format__ / __str__ protocols
# are not natively ported yet, and routing here keeps objects.jac na-clean.
def host_format(value: PyObj, spec: str) -> PyObj {
    result = _jac_host_format(to_host(value), spec);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return py_error(str(result[1]), str(result[2]));
}

def host_convert(value: PyObj, conv: int) -> PyObj {
    result = _jac_host_convert(to_host(value), conv);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return py_error(str(result[1]), str(result[2]));
}

def host_getattr(value: PyObj, name: str) -> PyObj {
    result = _jac_host_getattr(to_host(value), name);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return py_error(str(result[1]), str(result[2]));
}

def host_getitem(value: PyObj, index: PyObj) -> PyObj {
    result = _jac_host_getitem(to_host(value), to_host(index));
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return py_error(str(result[1]), str(result[2]));
}

def host_setattr(value: PyObj, name: str, field: PyObj) -> PyObj {
    result = _jac_host_setattr(to_host(value), name, to_host(field));
    if host_result_ok(result) {
        return py_none();
    }
    return py_error(str(result[1]), str(result[2]));
}

# ---------------- byte helpers ----------------
def bytes_to_str(bs: list[int]) -> str {
    s = "";
    for b in bs {
        s = s + chr(b);
    }
    return s;
}

# Decode a UTF-8 byte sequence (marshal TYPE_UNICODE/TYPE_INTERNED payloads) into
# a str of real codepoints. bytes_to_str is Latin-1 (one codepoint per byte) and
# is correct only for the ASCII subset; multi-byte chars (e.g. Devanagari digits)
# need this. Continuation/overlong validation is intentionally minimal: marshal
# streams come from CPython's own encoder, so the input is always well-formed.
def utf8_bytes_to_str(bs: list[int]) -> str {
    s = "";
    n = len(bs);
    i = 0;
    while i < n {
        b0 = bs[i];
        cp = 0;
        width = 1;
        if b0 < 0x80 {
            cp = b0;
        } elif (b0 & 0xE0) == 0xC0 {
            cp = b0 & 0x1F;
            width = 2;
        } elif (b0 & 0xF0) == 0xE0 {
            cp = b0 & 0x0F;
            width = 3;
        } else {
            cp = b0 & 0x07;
            width = 4;
        }
        k = 1;
        while k < width {
            cp = (cp << 6) | (bs[i + k] & 0x3F);
            k = k + 1;
        }
        s = s + chr(cp);
        i = i + width;
    }
    return s;
}

# IEEE754 double from 8 little-endian bytes (used if a float const appears).
def bytes_to_double(bs: list[int]) -> float {
    v = 0;
    i = 0;
    while i < 8 {
        v = v | (bs[i] << (8 * i));
        i = i + 1;
    }
    sign = (v >> 63) & 1;
    exp = (v >> 52) & 0x7FF;
    frac = v & 0xFFFFFFFFFFFFF;
    if exp == 0 {
        if frac == 0 {
            if sign == 1 {
                return -0.0;
            } else {
                return 0.0;
            }
        }
        return (1 - 2 * sign) * (frac / (2 ** 52)) * (2 ** (-1022));
    }
    if exp == 0x7FF {
        # exp all-ones: infinity (frac 0) or NaN. Build them by overflow /
        # inf-minus-inf -- `0.0 / 0.0` raises ZeroDivisionError in Jac.
        huge = 1e300 * 1e300;
        if frac == 0 {
            if sign == 1 {
                return -huge;
            } else {
                return huge;
            }
        }
        return huge - huge;
    }
    mant = 1.0 + frac / (2.0 ** 52.0);
    return (1 - 2 * sign) * mant * (2.0 ** (exp - 1023));
}

# ---------------- marshal reader ----------------
obj Reader {
    has data: list[int],
        pos: int,
        refs: list[PyObj];

    def r_byte -> int {
        b = self.data[self.pos];
        self.pos = self.pos + 1;
        return b & 0xFF;
    }

    def r_short -> int {
        lo = self.r_byte();
        hi = self.r_byte();
        return lo | (hi << 8);
    }

    def r_long -> int {
        b0 = self.r_byte();
        b1 = self.r_byte();
        b2 = self.r_byte();
        b3 = self.r_byte();
        x = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
        if x >= 0x80000000 {
            x = x - 0x100000000;
        }
        return x;
    }

    def r_double -> float {
        bs: list[int] = [];
        k = 0;
        while k < 8 {
            bs.append(self.r_byte());
            k = k + 1;
        }
        return bytes_to_double(bs);
    }

    def r_object -> PyObj {
        code = self.r_byte();
        flag = code & 0x80;
        type_code = code & 0x7F;
        if flag != 0 {
            ref_index: int = len(self.refs);
            self.refs.append(py_none());
            o = self.read_type(type_code);
            self.refs[ref_index] = o;
        } else {
            o = self.read_type(type_code);
        }
        return o;
    }

    def read_type(type: int) -> PyObj {
        if type == 48 {
            return py_none();
        } elif type == 78 {
            return py_none();
        } elif type == 70 {
            return PyBool(t="bool", val=False);
        } elif type == 84 {
            return PyBool(t="bool", val=True);
        } elif type == 46 {
            return PyNoneType(t="ellipsis");
        } elif type == 105 {
            return PyInt(t="int", val=self.r_long());
        } elif type == 108 {
            return self.read_long();
        } elif type == 103 {
            return PyFloat(t="float", val=self.r_double());
        } elif type == 121 {
            return self.read_complex();
        } elif type == 115 {
            return self.read_bytes();
        } elif type == 97 {
            return self.read_ascii(False);
        } elif type == 122 {
            return self.read_ascii(True);
        } elif type == 65 {
            return self.read_ascii(False);
        } elif type == 90 {
            return self.read_ascii(True);
        } elif type == 117 {
            return self.read_utf8();
        } elif type == 116 {
            return self.read_utf8();
        } elif type == 40 {
            return self.read_tuple(False);
        } elif type == 41 {
            return self.read_tuple(True);
        } elif type == 91 {
            return self.read_list();
        } elif type == 99 {
            return self.read_code();
        } elif type == 114 {
            return self.refs[self.r_long()];
        } elif type == 58 {
            return self.read_slice();
        } elif type == 60 {
            return self.read_set(False);
        } elif type == 62 {
            return self.read_set(True);
        } else {
            return py_none();
        }
    }

    # TYPE_SET ('<' == 60) / TYPE_FROZENSET ('>' == 62): r_long count then N
    # members, materialized as a native PySet under the hash-key protocol.
    def read_set(frozen: bool) -> PyObj {
        n = self.r_long();
        name = "set";
        if frozen {
            name = "frozenset";
        }
        result = PySet(t=name, items={}, frozen=frozen);
        i = 0;
        while i < n {
            result.set_add(self.r_object());
            i = i + 1;
        }
        return result;
    }

    # TYPE_SLICE (':' == 58): three marshaled objects -- start, stop, step.
    def read_slice -> PyObj {
        start = self.r_object();
        stop = self.r_object();
        step = self.r_object();
        return PySlice(t="slice", start=start, stop=stop, step=step);
    }

    # CPython 3.14 big-int: n = r_long (signed count); digit_size=2 layout ->
    # marshal_ratio 15-bit shorts per 30-bit digit, LSB-first, little-endian.
    def read_long -> PyObj {
        n = self.r_long();
        if n == 0 {
            return PyInt(t="int", val=0);
        }
        sign = 1;
        if n < 0 {
            sign = -1;
            n = -n;
        }
        ratio = 2;
        size = 1 + (n - 1) // ratio;
        shorts_in_top = 1 + ((n - 1) % ratio);
        result = 0;
        base = 1;
        i = 0;
        while i < size - 1 {
            d = 0;
            j = 0;
            while j < ratio {
                s = self.r_short() & 0x7FFF;
                d = d + (s << (15 * j));
                j = j + 1;
            }
            result = result + d * base;
            base = base * (1 << 30);
            i = i + 1;
        }
        d = 0;
        j = 0;
        while j < shorts_in_top {
            s = self.r_short() & 0x7FFF;
            d = d + (s << (15 * j));
            j = j + 1;
        }
        result = result + d * base;
        return PyInt(t="int", val=result * sign);
    }

    def read_bytes -> PyObj {
        n = self.r_long();
        bs: list[int] = [];
        k = 0;
        while k < n {
            bs.append(self.r_byte());
            k = k + 1;
        }
        return PyBytes(t="bytes", val=bs);
    }

    def read_ascii(short: bool) -> PyObj {
        n = 0;
        if short {
            n = self.r_byte();
        } else {
            n = self.r_long();
        }
        bs: list[int] = [];
        k = 0;
        while k < n {
            bs.append(self.r_byte());
            k = k + 1;
        }
        return PyStr(t="str", val=bytes_to_str(bs));
    }

    def read_utf8 -> PyObj {
        n = self.r_long();
        bs: list[int] = [];
        k = 0;
        while k < n {
            bs.append(self.r_byte());
            k = k + 1;
        }
        return PyStr(t="str", val=utf8_bytes_to_str(bs));
    }

    def read_tuple(small: bool) -> PyObj {
        n = 0;
        if small {
            n = self.r_byte();
        } else {
            n = self.r_long();
        }
        items: list[PyObj] = [];
        k = 0;
        while k < n {
            items.append(self.r_object());
            k = k + 1;
        }
        return PyTuple(t="tuple", items=items);
    }

    def read_list -> PyObj {
        n = self.r_long();
        items: list[PyObj] = [];
        k = 0;
        while k < n {
            items.append(self.r_object());
            k = k + 1;
        }
        return PyList(t="list", items=items);
    }

    def read_complex -> PyObj {
        re = self.r_double();
        im = self.r_double();
        return PyComplex(t="complex", real=re, imag=im);
    }

    def read_code -> PyObj {
        argcount = self.r_long();
        posonly = self.r_long();
        kwonly = self.r_long();
        stacksize = self.r_long();
        flags = self.r_long();
        code = self.r_object();
        consts_t = self.r_object();
        names_t = self.r_object();
        lpnames_t = self.r_object();
        lpkinds_t = self.r_object();
        filename = self.r_object();
        name = self.r_object();
        qualname = self.r_object();
        firstlineno = self.r_long();
        linetable = self.r_object();
        exceptiontable = self.r_object();

        co_code: list[int] = bytes_value(code);
        consts: list[PyObj] = tuple_value(consts_t);
        names: list[str] = str_values(names_t);
        lpnames: list[str] = str_values(lpnames_t);
        lpkinds: list[int] = bytes_value(lpkinds_t);
        varnames: list[str] = [];
        cellvars: list[str] = [];
        freevars: list[str] = [];
        i = 0;
        while i < len(lpnames) {
            kind = 0;
            if i < len(lpkinds) {
                kind = lpkinds[i];
            }
            # CPython's locals-plus kinds are bit flags, not a 0/1/2 enum:
            # local=0x20, cell=0x40, free=0x80. A cell parameter carries both
            # the local and cell bits and belongs in both views.
            if (kind & 0x20) != 0 {
                varnames.append(lpnames[i]);
            }
            if (kind & 0x40) != 0 {
                cellvars.append(lpnames[i]);
            }
            if (kind & 0x80) != 0 {
                freevars.append(lpnames[i]);
            }
            i = i + 1;
        }
        fn: str = str_value(filename);
        nm: str = str_value(name);
        qn: str = str_value(qualname);
        lt: list[int] = bytes_value(linetable);
        et: list[int] = bytes_value(exceptiontable);
        return PyCode(
            t="code",
            argcount=argcount,
            posonlyargcount=posonly,
            kwonlyargcount=kwonly,
            stacksize=stacksize,
            flags=flags,
            co_code=co_code,
            consts=consts,
            names=names,
            varnames=varnames,
            cellvars=cellvars,
            freevars=freevars,
            filename=fn,
            name=nm,
            qualname=qn,
            firstlineno=firstlineno,
            linetable=lt,
            exceptiontable=et,
        );
    }
}

def unmarshal(data: list[int]) -> PyObj {
    r = Reader(data=data, pos=0, refs=[]);
    return r.r_object();
}

# Bootstrap transport: the host compiler produces the code object and marshal
# carries it across the boundary as ordinary bytes. The cast is only at the
# Python interop boundary; the Jac reader remains typed on list[int].
def host_compile_marshal(source: str) -> list[int] {
    raw = marshal.dumps(compile(source, "<jacpython-host>", "exec"));
    return raw as list[int];
}

# ---------------- ceval ----------------

# CPython 3.14 opcode numbers.  The VM deliberately keeps these explicit: the
# bootstrap transport is pinned to one CPython release until the front end can
# provide a versioned opcode table.
glob OP_CACHE: int = 0,
     OP_RESUME: int = 128,
     OP_LOAD_BUILD_CLASS: int = 21,
     OP_LOAD_LOCALS: int = 22,
     OP_NOT_TAKEN: int = 28,
     OP_POP_TOP: int = 31,
     OP_PUSH_EXC_INFO: int = 32,
     OP_PUSH_NULL: int = 33,
     OP_RETURN_VALUE: int = 35,
     OP_BINARY_SLICE: int = 1,
     OP_BUILD_SLICE: int = 49,
     OP_STORE_SUBSCR: int = 38,
     OP_UNARY_NOT: int = 42,
     OP_WITH_EXCEPT_START: int = 43,
     OP_BINARY_OP: int = 44,
     OP_BUILD_LIST: int = 46,
     OP_BUILD_MAP: int = 47,
     OP_BUILD_TUPLE: int = 51,
     OP_CALL: int = 52,
     OP_CALL_KW: int = 55,
     OP_COMPARE_OP: int = 56,
     OP_COPY: int = 59,
     OP_COPY_FREE_VARS: int = 60,
     OP_END_FOR: int = 9,
     OP_GET_ITER: int = 16,
     OP_IMPORT_FROM: int = 72,
     OP_IMPORT_NAME: int = 73,
     OP_IS_OP: int = 74,
     OP_JUMP_BACKWARD: int = 75,
     OP_JUMP_BACKWARD_NO_INTERRUPT: int = 76,
     OP_JUMP_FORWARD: int = 77,
     OP_LIST_APPEND: int = 78,
     OP_SET_ADD: int = 107,
     OP_LIST_EXTEND: int = 79,
     OP_LOAD_ATTR: int = 80,
     OP_LOAD_SUPER_ATTR: int = 96,
     OP_LOAD_CONST: int = 82,
     OP_LOAD_DEREF: int = 83,
     OP_LOAD_CLOSURE: int = 261,
     OP_LOAD_FAST: int = 84,
     OP_LOAD_FAST_BORROW: int = 86,
     OP_LOAD_FAST_BORROW_2: int = 87,
     OP_LOAD_FAST_LOAD_FAST: int = 89,
     OP_LOAD_GLOBAL: int = 92,
     OP_LOAD_NAME: int = 93,
     OP_LOAD_SMALL_INT: int = 94,
     OP_LOAD_SPECIAL: int = 95,
     OP_MAKE_CELL: int = 97,
     OP_MAKE_FUNCTION: int = 23,
     OP_POP_JUMP_IF_FALSE: int = 100,
     OP_POP_JUMP_IF_NONE: int = 101,
     OP_POP_JUMP_IF_NOT_NONE: int = 102,
     OP_POP_JUMP_IF_TRUE: int = 103,
     OP_RAISE_VARARGS: int = 104,
     OP_RERAISE: int = 105,
     OP_SET_FUNCTION_ATTRIBUTE: int = 108,
     OP_STORE_ATTR: int = 110,
     OP_DELETE_ATTR: int = 61,
     OP_STORE_DEREF: int = 111,
     OP_STORE_FAST: int = 112,
     OP_DELETE_FAST: int = 63,
     OP_STORE_NAME: int = 116,
     OP_STORE_GLOBAL: int = 115,
     OP_DELETE_GLOBAL: int = 64,
     OP_SWAP: int = 117,
     OP_CHECK_EXC_MATCH: int = 6,
     OP_POP_EXCEPT: int = 29,
     OP_BUILD_SET: int = 48,
     OP_SET_UPDATE: int = 109,
     OP_CONVERT_VALUE: int = 58,
     OP_FORMAT_SIMPLE: int = 12,
     OP_FORMAT_WITH_SPEC: int = 13,
     OP_BUILD_STRING: int = 50,
     OP_RETURN_GENERATOR: int = 34,
     OP_YIELD_VALUE: int = 120,
     OP_STORE_FAST_LOAD_FAST: int = 113,
     OP_TO_BOOL: int = 39,
     OP_CONTAINS_OP: int = 57,
     OP_LOAD_COMMON_CONSTANT: int = 81,
     OP_CALL_INTRINSIC_1: int = 53,
     OP_LOAD_FAST_AND_CLEAR: int = 85,
     OP_SEND: int = 106,
     OP_END_SEND: int = 10,
     OP_GET_YIELD_FROM_ITER: int = 19,
     OP_GET_AWAITABLE: int = 71,
     OP_CLEANUP_THROW: int = 7,
     OP_DELETE_NAME: int = 65,
     OP_UNARY_NEGATIVE: int = 41,
     OP_UNARY_INVERT: int = 40,
     OP_UNPACK_SEQUENCE: int = 119,
     OP_DELETE_SUBSCR: int = 8,
     OP_MAP_ADD: int = 98,
     OP_DICT_MERGE: int = 66,
     OP_DICT_UPDATE: int = 67,
     OP_STORE_FAST_STORE_FAST: int = 114,
     OP_EXTENDED_ARG: int = 69,
     OP_CALL_FUNCTION_EX: int = 4,
     OP_NOP: int = 27;

# Inline caches occupy real code units in 3.14.  Returning the number of cache
# units lets jumps target byte offsets without ever decoding cache payloads.
def opcode_cache_count(op: int) -> int {
    if op == OP_BINARY_OP {
        return 5;
    }
    if op == OP_CALL or op == OP_CALL_KW {
        return 3;
    }
    if op == OP_COMPARE_OP {
        return 1;
    }
    if op == OP_FOR_ITER {
        return 1;
    }
    if op == OP_SEND {
        return 1;
    }
    # JUMP_BACKWARD carries a counter cache; the NO_INTERRUPT variant does not.
    if op == OP_JUMP_BACKWARD {
        return 1;
    }
    if op == OP_LOAD_ATTR {
        return 8;
    }
    if op == OP_STORE_ATTR {
        return 4;
    }
    if op == OP_LOAD_GLOBAL {
        return 4;
    }
    if op == OP_POP_JUMP_IF_FALSE
    or op == OP_POP_JUMP_IF_TRUE
    or op == OP_POP_JUMP_IF_NONE
    or op == OP_POP_JUMP_IF_NOT_NONE {
        return 1;
    }
    if op == OP_STORE_SUBSCR {
        return 1;
    }
    if op == OP_TO_BOOL {
        return 3;
    }
    if op == OP_CONTAINS_OP {
        return 1;
    }
    return 0;
}

# FOR_ITER is the one opcode whose name is useful in several helpers.
glob OP_FOR_ITER: int = 70,
     OP_POP_ITER: int = 30;

# The dispatchers below are thin adapters over the object model's virtual
# slots: they exist only so the ceval reads naturally. Behavior selection is
# the method call (self's vtable), never a tag comparison.
def py_truth(value: PyObj) -> bool {
    return value.tp_bool();
}

# A key/value that is NOT a builtin (a user object or a host proxy) can carry a
# custom __eq__, so the hashkey-bucket match must be confirmed with a real
# comparison. Between two builtins the hashkey protocol already IS value equality
# (numeric collapse included), so the confirming eq is skipped -- the fast path.
def _needs_eq_confirm(o: PyObj) -> bool {
    return isinstance(o, PyUserObj) or isinstance(o, PyHostProxy);
}

# CPython dict equality: equal length, and every key of `a` maps in `b` to an
# equal value. The key lookup and the value compare both go through py_compare,
# so an element __eq__ that raises (e.g. dict test_eq's BadCmp) propagates rather
# than being silently answered by the hashkey model. Returns a PyBool or a
# PyError (a raised element comparison).
def dict_equal(a: PyDict, b: PyDict) -> PyObj {
    if len(a.items) != len(b.items) {
        return PyBool(t="bool", val=False);
    }
    for hk in a.items {
        ak = a.items[hk].key;
        av = a.items[hk].value;
        if not (hk in b.items) {
            return PyBool(t="bool", val=False);
        }
        bk = b.items[hk].key;
        bv = b.items[hk].value;
        if _needs_eq_confirm(ak) or _needs_eq_confirm(bk) {
            keq = py_compare(2, bk, ak);
            if is_error(keq) {
                return keq;
            }
            if not py_truth(keq) {
                return PyBool(t="bool", val=False);
            }
        }
        veq = py_compare(2, av, bv);
        if is_error(veq) {
            return veq;
        }
        if not py_truth(veq) {
            return PyBool(t="bool", val=False);
        }
    }
    return PyBool(t="bool", val=True);
}

def dict_richcompare(kind: int, a: PyDict, b: PyDict) -> PyObj {
    if kind != 2 and kind != 3 {
        return py_error(
            "TypeError", "'<' not supported between instances of 'dict' and 'dict'"
        );
    }
    eq = dict_equal(a, b);
    if is_error(eq) {
        return eq;
    }
    if kind == 2 {
        return eq;
    }
    return PyBool(t="bool", val=not py_truth(eq));
}

def py_compare(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    if isinstance(lhs, PyUserObj) or isinstance(rhs, PyUserObj) {
        return user_compare(kind, lhs, rhs);
    }
    # A dict view on either side compares set-like (keys/items), invoking element
    # __eq__: {1:1}.keys() == {1}, and d1.items() == d2.items() propagating a raise.
    if isinstance(lhs, PyDictView) or isinstance(rhs, PyDictView) {
        return dictview_richcompare(kind, lhs, rhs);
    }
    if isinstance(lhs, PyDict) and isinstance(rhs, PyDict) {
        return dict_richcompare(kind, lhs as PyDict, rhs as PyDict);
    }
    return lhs.tp_richcompare(kind, rhs);
}

# Native nb_binop covers the ported fast paths (int/str Gap #2 %-format, tuple/
# list concat, ...). Operand/format combos not yet ported (str % with %f/%i or
# multiple args, str * int, ...) fall back across the substrate to host CPython
# when both operands are host-backed. Purely additive: only a native error
# triggers the fallback, so ported semantics always win.
def host_binop(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    result = _jac_host_binop(kind, to_host(lhs), to_host(rhs));
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return py_error(str(result[1]), str(result[2]));
}

def _host_representable(t: str) -> bool {
    # Native PySet is fully to_host-representable, so a mixed native-set / host
    # operand binop (e.g. dict.keys() | {2}) can still fall back to the host.
    # Native set | set never reaches here -- PySet.nb_binop answers it directly.
    return _is_host_backed(t) or t == "host" or t == "set" or t == "frozenset";
}

# Object identity for `is` / `id()`. None and booleans are true singletons in
# CPython, and small ints [-5, 256] are cached, so for these three identity is
# deterministically value-equality -- we answer them by value and match CPython
# without interning every construction site (which the na-clean leaf can't hold
# a persistent singleton for anyway). Every other object uses real Jac reference
# identity: fresh containers/strings/big-ints are `is`-equal only when aliased.
def _small_int_cached(v: int) -> bool {
    return v >= -5 and v <= 256;
}

def py_identity(a: PyObj, b: PyObj) -> bool {
    if isinstance(a, PyNoneType) or isinstance(b, PyNoneType) {
        return isinstance(a, PyNoneType) and isinstance(b, PyNoneType);
    }
    if isinstance(a, PyBool) and isinstance(b, PyBool) {
        return (a as PyBool).val == (b as PyBool).val;
    }
    if isinstance(a, PyInt) and isinstance(b, PyInt) {
        av = (a as PyInt).val;
        bv = (b as PyInt).val;
        if av == bv and _small_int_cached(av) {
            return True;
        }
        return a is b;
    }
    # Two proxies to the SAME host object are the same object: `type(x) is str`
    # (str being a host-type proxy, type(x) another) must hold, or CPython idioms
    # like namedtuple's `type(name) is not str` field-name check spuriously fail.
    if isinstance(a, PyHostProxy) and isinstance(b, PyHostProxy) {
        return (a as PyHostProxy).val is (b as PyHostProxy).val;
    }
    return a is b;
}

# id(): stable per-object integer. For the cached-immutable classes above, return
# a synthetic id in a reserved low band so `id(x) == id(y)` iff `x is y` stays
# consistent with py_identity; every other object reports its Jac reference id.
def py_id(o: PyObj) -> int {
    if isinstance(o, PyNoneType) {
        return 1;
    }
    if isinstance(o, PyBool) {
        if (o as PyBool).val {
            return 3;
        }
        return 2;
    }
    if isinstance(o, PyInt) {
        v = (o as PyInt).val;
        if _small_int_cached(v) {
            return 1000 + v;
        }
    }
    # A proxy's identity is its underlying host object's identity (consistent
    # with py_identity treating same-host-object proxies as one object).
    if isinstance(o, PyHostProxy) {
        return id((o as PyHostProxy).val);
    }
    return id(o);
}

# A dunder returned NotImplemented (only a host proxy can wrap the singleton).
def is_notimplemented(o: PyObj) -> bool {
    if isinstance(o, PyHostProxy) {
        return _jac_is_notimpl((o as PyHostProxy).val) as bool;
    }
    return False;
}

# ---- user-class operator overloading (__add__/__eq__/... dispatch) ---------
# The native nb_binop/tp_richcompare slots only know builtin types; a plain user
# class defines operators as `__add__`/`__eq__`/... methods in its class dict.
# These helpers implement CPython's binary-operator protocol (normal slot, then
# reflected slot, then TypeError) over the MRO for PyUserObj operands.

# NB_ binop kind -> dunder name ("" if the kind has no overload slot).
def binop_dunder(kind: int) -> str {
    names = [
        "__add__", "__and__", "__floordiv__", "__lshift__", "__matmul__",
        "__mul__", "__mod__", "__or__", "__pow__", "__rshift__",
        "__sub__", "__truediv__", "__xor__"
    ];
    if kind >= 0 and kind < len(names) {
        return names[kind];
    }
    return "";
}

# Reflected counterpart (__radd__/__rmul__/...) for the same kind.
def binop_rdunder(kind: int) -> str {
    names = [
        "__radd__", "__rand__", "__rfloordiv__", "__rlshift__", "__rmatmul__",
        "__rmul__", "__rmod__", "__ror__", "__rpow__", "__rrshift__",
        "__rsub__", "__rtruediv__", "__rxor__"
    ];
    if kind >= 0 and kind < len(names) {
        return names[kind];
    }
    return "";
}

# Rich-compare kind (0<,1<=,2==,3!=,4>,5>=) -> dunder name.
def compare_dunder(kind: int) -> str {
    names = ["__lt__", "__le__", "__eq__", "__ne__", "__gt__", "__ge__"];
    if kind >= 0 and kind < len(names) {
        return names[kind];
    }
    return "";
}

# Reflected comparison kind: < <-> >, <= <-> >=, ==/!= are self-reflected.
def compare_swap(kind: int) -> int {
    swap = [4, 5, 2, 3, 0, 1];
    if kind >= 0 and kind < len(swap) {
        return swap[kind];
    }
    return kind;
}

def user_has_dunder(u: PyUserObj, name: str) -> bool {
    return not is_error(class_lookup_attr(u.cls, name));
}

# Bind the MRO-resolved dunder to the receiver and call it with `args`. The
# result -- a value, a raised exception (PyError), or NotImplemented -- is
# returned verbatim for the protocol layer to interpret.
def call_user_dunder(u: PyUserObj, name: str, args: list[PyObj]) -> PyObj {
    method = class_lookup_attr(u.cls, name);
    return bind_attribute(method, u).tp_call(args, {});
}

# CPython binary-operator protocol for PyUserObj operands: try lhs.__op__(rhs),
# then the reflected rhs.__rop__(lhs); a builtin-subclass operand with no user
# override delegates to its boxed value; otherwise TypeError. A raised exception
# from a dunder propagates immediately (it is not NotImplemented).
def user_binop(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    name = binop_dunder(kind);
    if isinstance(lhs, PyUserObj) {
        lu = lhs as PyUserObj;
        if name != "" and user_has_dunder(lu, name) {
            res = call_user_dunder(lu, name, [rhs]);
            if not is_notimplemented(res) {
                return res;
            }
        }
    }
    rname = binop_rdunder(kind);
    if isinstance(rhs, PyUserObj) {
        ru = rhs as PyUserObj;
        if rname != "" and user_has_dunder(ru, rname) {
            res = call_user_dunder(ru, rname, [lhs]);
            if not is_notimplemented(res) {
                return res;
            }
        }
    }
    # No user override matched: a builtin subclass acts as its boxed value.
    if isinstance(lhs, PyUserObj) and (lhs as PyUserObj)._has_base() {
        r = (lhs as PyUserObj)._base_obj().nb_binop(kind, unwrap_base(rhs));
        if not is_error(r) {
            return r;
        }
    }
    if isinstance(rhs, PyUserObj) and (rhs as PyUserObj)._has_base() {
        r = unwrap_base(lhs).nb_binop(kind, (rhs as PyUserObj)._base_obj());
        if not is_error(r) {
            return r;
        }
    }
    return py_error("TypeError", "unsupported operand type(s)");
}

# CPython rich-comparison protocol for PyUserObj operands. Same shape as
# user_binop, plus the == / != identity fallback when neither side overrides.
def user_compare(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    name = compare_dunder(kind);
    if isinstance(lhs, PyUserObj) and not (lhs as PyUserObj)._has_base() {
        lu = lhs as PyUserObj;
        if name != "" and user_has_dunder(lu, name) {
            res = call_user_dunder(lu, name, [rhs]);
            if not is_notimplemented(res) {
                return res;
            }
        }
    }
    rname = compare_dunder(compare_swap(kind));
    if isinstance(rhs, PyUserObj) and not (rhs as PyUserObj)._has_base() {
        ru = rhs as PyUserObj;
        if rname != "" and user_has_dunder(ru, rname) {
            res = call_user_dunder(ru, rname, [lhs]);
            if not is_notimplemented(res) {
                return res;
            }
        }
    }
    if isinstance(lhs, PyUserObj) and (lhs as PyUserObj)._has_base() {
        return (lhs as PyUserObj)._base_obj().tp_richcompare(kind, unwrap_base(rhs));
    }
    if isinstance(rhs, PyUserObj) and (rhs as PyUserObj)._has_base() {
        return unwrap_base(lhs).tp_richcompare(kind, (rhs as PyUserObj)._base_obj());
    }
    if kind == 2 {
        return PyBool(t="bool", val=lhs is rhs);
    }
    if kind == 3 {
        return PyBool(t="bool", val=lhs is not rhs);
    }
    return py_error("TypeError", "unorderable types");
}

def py_binop(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    # NB_INPLACE_* (13..25) reduce to their base binop (0..12). jacpython values
    # are immutable at this layer, so `x += y` is `x = x + y` -- the trailing
    # STORE rebinds the name, matching CPython's immutable-type fallback.
    if kind >= 13 and kind <= 25 {
        kind = kind - 13;
    }
    # A user-class operand routes through the operator-overload protocol first.
    if isinstance(lhs, PyUserObj) or isinstance(rhs, PyUserObj) {
        return user_binop(kind, lhs, rhs);
    }
    # A dict view on either side does set algebra (| & - ^) yielding a PySet,
    # e.g. {1:1}.keys() | {2} and {2} | {1:1}.items().
    if isinstance(lhs, PyDictView) or isinstance(rhs, PyDictView) {
        return dictview_binop(kind, lhs, rhs);
    }
    result = lhs.nb_binop(kind, rhs);
    if is_error(result) {
        # A builtin-subclass operand the other side's slot didn't recognize
        # (e.g. 1 + MyInt(5), where int.nb_binop rejects the "instance" tag):
        # retry with both operands unwrapped to their boxed values.
        ul = unwrap_base(lhs);
        ur = unwrap_base(rhs);
        if not (ul is lhs) or not (ur is rhs) {
            result = ul.nb_binop(kind, ur);
        }
    }
    if is_error(result) and _host_representable(lhs.t) and _host_representable(rhs.t) {
        return host_binop(kind, lhs, rhs);
    }
    return result;
}

def py_subscript(container: PyObj, index: PyObj) -> PyObj {
    return container.mp_subscript(index);
}

# Membership test (CONTAINS_OP). Native sets/dicts answer via the hash-key
# protocol; other container shapes route through the host so `in` stays
# consistent for opaque proxies during bootstrap.
def py_contains(container: PyObj, member: PyObj) -> PyObj {
    if isinstance(container, PyDictView) {
        return view_contains(container as PyDictView, member);
    }
    if isinstance(container, PySet) {
        return PyBool(t="bool", val=(container as PySet).set_contains(member));
    }
    if isinstance(container, PyDict) {
        return PyBool(t="bool", val=(container as PyDict).dict_contains(member));
    }
    result = _jac_host_contains(to_host(member), to_host(container));
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return py_error(str(result[1]), str(result[2]));
}

def py_store_subscript(container: PyObj, index: PyObj, value: PyObj) -> PyObj {
    return container.mp_ass_subscript(index, value);
}

def py_delete_subscript(container: PyObj, index: PyObj) -> PyObj {
    return container.mp_del_subscript(index);
}

# DICT_UPDATE/DICT_MERGE source view: yields the str-keyed pairs to merge into
# the target dict. Native PyDict is returned directly; a host-backed mapping
# (PyHostProxy) is converted via from_host, which lands as a PyDict when its
# keys are strings. Non-mapping / non-str-key sources produce an empty view.
def pydict_from_str_map(m: dict[str, PyObj]) -> PyDict {
    # Wrap an inherently str-keyed implementation map (frame locals / class
    # namespace) into a PyDict with PyStr keys under the hash-key protocol.
    d = PyDict(t="dict", items={});
    for name in m {
        d.dict_set(PyStr(t="str", val=name), m[name]);
    }
    return d;
}

def dict_merge_pairs(source: PyObj) -> PyDict {
    if isinstance(source, PyDict) {
        return source as PyDict;
    }
    if isinstance(source, PyHostProxy) {
        converted = from_host((source as PyHostProxy).val);
        if isinstance(converted, PyDict) {
            return converted as PyDict;
        }
    }
    return PyDict(t="dict", items={});
}

# UNARY_NEGATIVE (-x). int/bool negate to int (-True == -1), float to float; any
# other operand is a TypeError, matching CPython's nb_negative == NULL path.
def py_negative(value: PyObj) -> PyObj {
    if isinstance(value, PyBool) {
        v = 0;
        if (value as PyBool).val {
            v = 1;
        }
        return PyInt(t="int", val=-v);
    }
    if isinstance(value, PyInt) {
        return PyInt(t="int", val=-(value as PyInt).val);
    }
    if isinstance(value, PyFloat) {
        return PyFloat(t="float", val=-(value as PyFloat).val);
    }
    return py_error("TypeError", "bad operand type for unary -");
}

# UNARY_INVERT (~x). Defined only for ints/bools: ~x == -x - 1.
def py_invert(value: PyObj) -> PyObj {
    if isinstance(value, PyBool) {
        v = 0;
        if (value as PyBool).val {
            v = 1;
        }
        return PyInt(t="int", val=-v - 1);
    }
    if isinstance(value, PyInt) {
        return PyInt(t="int", val=-(value as PyInt).val - 1);
    }
    return py_error("TypeError", "bad operand type for unary ~");
}

def append_to_list(target: PyObj, iterable: PyObj) {
    target_list = target as PyList;
    if iterable.t == "list" {
        target_list.items.extend(list_value(iterable));
    } elif iterable.t == "tuple" {
        target_list.items.extend(tuple_value(iterable));
    } elif iterable.t == "str" {
        for ch in str_value(iterable) {
            target_list.items.append(PyStr(t="str", val=ch));
        }
    }
}

# Native scalar/container tags whose method surface is not yet ported. During
# bootstrap their attribute lookups fall back across the substrate boundary to
# host CPython (host_getattr returns a bound method, which from_host wraps as a
# callable PyHostProxy). This is the object-core-clean seam: the fallback lives
# here in pyc_first (host-allowed), never in the na-clean objects.jac, so e.g.
# 'abc'.upper() / {}.copy() / dict().keys() work before their native ports land.
def _is_host_backed(t: str) -> bool {
    return t == "str"
    or t == "bytes"
    or t == "int"
    or t == "bool"
    or t == "float"
    or t == "list"
    or t == "tuple"
    or t == "dict"
    or t == "complex";
}

def py_attr(value: PyObj, name: str) -> PyObj {
    result = value.tp_getattro(name);
    # A native dict's keys()/values()/items() are bound zero-arg constructors of
    # a live, set-like PyDictView (not host proxies), so view comparison / set
    # algebra can invoke element __eq__ and iteration carries the mutation guard.
    if is_error(result) and isinstance(value, PyDict)
    and (name == "keys" or name == "values" or name == "items") {
        return PyDictViewCtor(t="view_ctor", d=value as PyDict, mode=name);
    }
    # Native mutating/accessor dict methods, so a dict-subclass mutation lands in
    # real storage rather than a to_host copy.
    if is_error(result) and isinstance(value, PyDict) and is_dict_method(name) {
        return PyDictMethod(t="dict_method", target=value as PyDict, name=name);
    }
    # Native list methods, so `lst.append(x)` mutates the real list, not a copy.
    if is_error(result) and isinstance(value, PyList) and is_list_method(name) {
        return PyListMethod(t="list_method", target=value as PyList, name=name);
    }
    if is_error(result) and isinstance(value, PySet)
    and is_set_method(name, (value as PySet).frozen) {
        return PySetMethod(t="set_method", target=value as PySet, name=name);
    }
    if is_error(result) and _is_host_backed(value.t) {
        return host_getattr(value, name);
    }
    # `.__new__` on any object with no override is object.__new__ (inherited), so
    # None.__new__ / instance.__new__ resolve instead of raising -- enum compares
    # candidate constructors against object.__new__.
    if is_error(result) and name == "__new__" {
        return PyNativeNew(t="native_new", base_name="object");
    }
    # `.__init__` with no user override is object.__init__ (a no-op accepting any
    # args), so inst.__init__(*args) resolves rather than raising.
    if is_error(result) and name == "__init__" {
        return PyNoOpInit(t="noop_init");
    }
    return result;
}

def bind_attribute(value: PyObj, receiver: PyObj) -> PyObj {
    # Explicit bind (a looked-up __init__/__new__/__prepare__ against a known
    # receiver). Routes through the descriptor protocol so a classmethod binds its
    # class and a staticmethod unwraps, not just a plain function.
    if isinstance(value, PyClassMethod) or isinstance(value, PyStaticMethod) {
        return descriptor_get(value, receiver, receiver);
    }
    if value.t == "function" {
        return PyBoundMethod(t="bound_method", function=value, receiver=receiver);
    }
    return value;
}

def py_set_attr(value: PyObj, name: str, field: PyObj) -> PyObj {
    return value.tp_setattro(name, field);
}

# `del obj.name` / delattr(obj, name). Native objects delete from their own
# writable attribute map; anything else falls back to the host.
def py_del_attr(value: PyObj, name: str) -> PyObj {
    if isinstance(value, PyClass) {
        c = value as PyClass;
        if name in c.attrs {
            del c.attrs[name];
            return py_none();
        }
        return py_error("AttributeError", name);
    }
    if isinstance(value, PyUserObj) {
        u = value as PyUserObj;
        if name in u.attrs {
            del u.attrs[name];
            return py_none();
        }
        return py_error("AttributeError", name);
    }
    if isinstance(value, PyModule) {
        m = value as PyModule;
        if name in m.attrs {
            del m.attrs[name];
            return py_none();
        }
        return py_error("AttributeError", name);
    }
    if isinstance(value, PyFunction) {
        f = value as PyFunction;
        if name in f.attrs {
            del f.attrs[name];
            return py_none();
        }
        return py_error("AttributeError", name);
    }
    result = _jac_host_delattr(to_host(value), name);
    if host_result_ok(result) {
        return py_none();
    }
    return py_error(str(result[1]), str(result[2]));
}

def py_iter(value: PyObj) -> PyObj {
    return value.tp_iter();
}

# len() computed in-VM from a native container's own storage so a native
# list/tuple/str/bytes/dict/set -- and especially one holding plain user
# objects -- reports its size directly instead of round-tripping through
# to_host (where a plain PyUserObj collapses to None and the count is lost).
# A builtin subclass measures its boxed value; a user class dispatches __len__.
# Build a native PyDict from a str-keyed attribute map. Used to answer __dict__
# on native functions/classes/instances/modules. NOTE: this is a snapshot -- it
# reads the live attrs but mutations to the returned dict do not write back.
# Enough for the stdlib closure's dominant pattern (functools.wraps /
# update_wrapper, whose `__dict__.update(...)` source is normally empty), and for
# introspection; a fully live mapping-proxy is a later refinement.
def dict_from_str_map(m: dict[str, PyObj]) -> PyDict {
    d = PyDict(t="dict", items={});
    for k in m {
        d.dict_set(PyStr(t="str", val=k), m[k]);
    }
    return d;
}

def py_len(value: PyObj) -> PyObj {
    if isinstance(value, PyStr) {
        return PyInt(t="int", val=len((value as PyStr).val));
    }
    if isinstance(value, PyBytes) {
        return PyInt(t="int", val=len((value as PyBytes).val));
    }
    if isinstance(value, PyTuple) {
        return PyInt(t="int", val=len((value as PyTuple).items));
    }
    if isinstance(value, PyList) {
        return PyInt(t="int", val=len((value as PyList).items));
    }
    if isinstance(value, PyDict) {
        return PyInt(t="int", val=len((value as PyDict).items));
    }
    if isinstance(value, PySet) {
        return PyInt(t="int", val=len((value as PySet).items));
    }
    if isinstance(value, PyDictView) {
        return PyInt(t="int", val=len((value as PyDictView).d.items));
    }
    if isinstance(value, PyUserObj) {
        u = value as PyUserObj;
        if user_has_dunder(u, "__len__") {
            res = call_user_dunder(u, "__len__", []);
            if is_error(res) {
                return res;
            }
            if isinstance(res, PyInt) {
                return res;
            }
            return py_error("TypeError", "'__len__' should return an integer");
        }
        if u._has_base() {
            return py_len(u._base_obj());
        }
    }
    if isinstance(value, PyHostProxy) {
        # A proxied host object (e.g. a namedtuple instance produced by
        # tuple.__new__, or any C-extension container) answers len() on the host.
        result = _jac_host_len(to_host(value));
        if host_result_ok(result) {
            return from_host(result[1]);
        }
        return py_error(str(result[1]), str(result[2]));
    }
    return py_error(
        "TypeError", "object of type '" + value.t + "' has no len()"
    );
}

# Materialize a host iterable (range, dict-view, map/filter object, ...) into a
# native PyIter so GET_ITER/FOR_ITER drive it without a host round-trip per step.
def host_iter(value: PyHostProxy) -> PyObj {
    result = _jac_host_iter(value.val);
    if host_result_ok(result) {
        items: list[PyObj] = [];
        for item in result[1] {
            items.append(from_host(item));
        }
        return PyIter(t="iter", items=items, index=0);
    }
    return py_error(str(result[1]), str(result[2]));
}

# The PyObj yielded by a dict iterator at its current position: the key (keys),
# the value (values), or a (key, value) PyTuple (items). The caller has already
# confirmed the iterator is not stale, so the hashkey is still present.
def dictiter_yield(di: PyDictIter) -> PyObj {
    hk = di.keys[di.index];
    entry = di.d.items[hk];
    if di.mode == "values" {
        return entry.value;
    }
    if di.mode == "items" {
        return PyTuple(t="tuple", items=[entry.key, entry.value]);
    }
    return entry.key;
}

def dictiter_error -> PyObj {
    return py_error("RuntimeError", "dictionary changed size during iteration");
}

def find_cell(cells: list[PyCell], names: list[str], name: str) -> PyCell | None {
    i = find_name(names, name);
    if i >= 0 and i < len(cells) {
        return cells[i];
    }
    return None;
}

# CPython 3.11+ indexes LOAD_FAST / *_DEREF / MAKE_CELL into a single merged
# "localsplus" array laid out as [varnames(nlocals)] [cellvars-not-already-a-var]
# [freevars]. A cell variable that is ALSO an argument keeps its varname slot
# (it is NOT duplicated in the appended region) -- so the appended region holds
# only the non-arg cellvars, then the freevars. resolve_cell maps a merged index
# to its PyCell (or None for a plain local). Getting this layout wrong swaps a
# parameter-cell with a sibling local-cell (breaks every closure/decorator).
def resolve_cell(
    co: PyCode, arg: int, cells: list[PyCell], closure: list[PyCell]
) -> PyCell | None {
    nl = len(co.varnames);
    if arg < nl {
        pos = find_name(co.cellvars, co.varnames[arg]);
        if pos >= 0 and pos < len(cells) {
            return cells[pos];
        }
        return None;
    }
    j = arg - nl;
    # Walk the non-arg cellvars in cellvar order; the j-th is this slot.
    seen = 0;
    ci = 0;
    while ci < len(co.cellvars) {
        if find_name(co.varnames, co.cellvars[ci]) < 0 {
            if seen == j and ci < len(cells) {
                return cells[ci];
            }
            seen = seen + 1;
        }
        ci = ci + 1;
    }
    # Past the non-arg cellvars lies the freevar region (the closure cells).
    free_index = j - seen;
    if free_index >= 0 and free_index < len(closure) {
        return closure[free_index];
    }
    return None;
}

def fast_value(
    co: PyCode, arg: int, fast: list[PyObj], cells: list[PyCell], closure: list[PyCell]
) -> PyObj {
    # A cell slot (an arg-cell in the varname region, or any appended cell/free
    # slot) yields the CELL OBJECT -- that is how LOAD_FAST/LOAD_CLOSURE fetch a
    # cell to seed an inner function's closure. A plain local yields its value.
    cell = resolve_cell(co, arg, cells, closure);
    if cell is not None {
        return cell as PyObj;
    }
    if arg < len(fast) {
        return fast[arg];
    }
    return py_error("UnboundLocalError", "local variable is not set");
}

def deref_cell(
    co: PyCode, arg: int, fast: list[PyObj], cells: list[PyCell], closure: list[PyCell]
) -> PyCell | None {
    return resolve_cell(co, arg, cells, closure);
}

def read_varint(data: list[int], pos: int) -> tuple[int, int] {
    value = 0;
    current = 0;
    while pos < len(data) {
        current = data[pos] & 0xFF;
        pos = pos + 1;
        value = (value << 6) | (current & 63);
        if (current & 64) == 0 {
            return (value, pos);
        }
    }
    return (value, pos);
}

def find_handler(co: PyCode, offset: int) -> PyHandler | None {
    data = co.exceptiontable;
    pos = 0;
    while pos < len(data) {
        start_read = read_varint(data, pos);
        start = start_read[0] * 2;
        pos = start_read[1];
        length_read = read_varint(data, pos);
        end = start + length_read[0] * 2;
        pos = length_read[1];
        target_read = read_varint(data, pos);
        target = target_read[0] * 2;
        pos = target_read[1];
        depth_read = read_varint(data, pos);
        depth = depth_read[0] >> 1;
        lasti = (depth_read[0] & 1) != 0;
        pos = depth_read[1];
        if offset >= start and offset < end {
            return PyHandler(
                t="handler",
                start=start,
                end=end,
                target=target,
                depth=depth,
                lasti=lasti
            );
        }
    }
    return None;
}

def recover_exception(
    co: PyCode, value: PyObj, offset: int, stack: list[PyObj]
) -> int {
    if value.t != "error" {
        return -1;
    }
    handler = find_handler(co, offset);
    if handler is None {
        return -1;
    }
    error = value as PyError;
    while len(stack) > handler.depth {
        stack.pop();
    }
    if handler.lasti {
        stack.append(PyInt(t="int", val=offset));
    }
    stack.append(error.exception);
    return handler.target;
}

def exception_matches(value: PyObj, target: PyObj) -> bool {
    if value.t != "exception" {
        return False;
    }
    exception = value as PyException;
    # A user exception class target (except Exc): match by the raised instance's
    # MRO if we kept the instance, else by class name.
    if isinstance(target, PyClass) {
        raw = exception.raw;
        if raw is not None and isinstance(raw, PyUserObj) {
            for klass in class_mro((raw as PyUserObj).cls) {
                if klass is (target as PyClass) {
                    return True;
                }
            }
        }
        return (target as PyClass).name == exception.type_name;
    }
    target_name: str = "";
    if target.t == "exception_type" {
        target_name = (target as PyExceptionType).name;
    } elif target.t == "host" {
        target_name = _jac_host_type_name((target as PyHostProxy).val) as str;
    }
    if target_name == "BaseException" or target_name == "Exception" {
        return True;
    }
    return target_name == exception.type_name;
}

# True iff `cls` (a user class) derives from a builtin exception -- i.e. one of
# its MRO classes lists a host BaseException-subclass proxy among its bases.
# `class Exc(Exception)` has native_base "" (Exception is not a subclassable
# builtin layout), so we detect it through the recorded host base, not the layout.
def class_is_exception(cls: PyClass) -> bool {
    for klass in class_mro(cls) {
        for base in klass.bases {
            # Builtin exceptions resolve to a native PyExceptionType (Exception,
            # ValueError, ...); a not-yet-native one arrives as a host proxy.
            if isinstance(base, PyExceptionType) {
                return True;
            }
            if isinstance(base, PyHostProxy)
            and bool(_jac_is_exception_type((base as PyHostProxy).val)) {
                return True;
            }
        }
    }
    return False;
}

def py_raise_value(value: PyObj) -> PyObj {
    if value.t == "exception" {
        return PyError(t="error", exception=value as PyException);
    }
    if value.t == "exception_type" {
        typ = value as PyExceptionType;
        return PyError(
            t="error",
            exception=PyException(t="exception", type_name=typ.name, message="")
        );
    }
    # A raised user exception instance (class Exc(Exception); raise Exc()) surfaces
    # as a PyException tagged with the user class name, keeping the instance in
    # `raw` so `except <UserClass>` can match it by MRO.
    if isinstance(value, PyUserObj) {
        u = value as PyUserObj;
        if class_is_exception(u.cls) {
            return PyError(
                t="error",
                exception=PyException(
                    t="exception", type_name=u.cls.name, message="", raw=value
                )
            );
        }
    }
    # A raised exception CLASS (raise Exc) auto-instantiates, then re-raises.
    if isinstance(value, PyClass) and class_is_exception(value as PyClass) {
        instance = (value as PyClass).tp_call([], {});
        if is_error(instance) {
            return instance;
        }
        return py_raise_value(instance);
    }
    return py_error("TypeError", "exceptions must derive from BaseException");
}

def py_call_host(
    fn: PyHostProxy, args: list[PyObj], kwargs: dict[str, PyObj]
) -> PyObj {
    raw_args: list[any] = [];
    for item in args {
        raw_args.append(to_host(item));
    }
    raw_kwargs: dict[str, any] = {};
    for key in kwargs {
        raw_kwargs[key] = to_host(kwargs[key]);
    }
    result = _jac_host_call(fn.val, raw_args, raw_kwargs);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return py_error(str(result[1]), str(result[2]));
}

def py_invoke(fn: PyObj, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    # A pending error flowing into a call site propagates unchanged; every real
    # callable resolves through its tp_call slot (function/class/bound method/
    # exception type/host proxy/build-class), never a tag switch.
    if fn.t == "error" {
        return fn;
    }
    return fn.tp_call(args, kwargs);
}

# ---------------- Track B: builtin subclassing support -----------------------

# Depth-first MRO over PyClass bases (dedup by identity). Single inheritance +
# one builtin base -- the common case -- linearizes correctly; deeper diamonds
# get a valid-but-not-strict-C3 order, sufficient for attribute lookup.
def class_mro(cls: PyClass) -> list[PyClass] {
    result: list[PyClass] = [cls];
    for base in cls.bases {
        if isinstance(base, PyClass) {
            for ancestor in class_mro(base as PyClass) {
                if not (ancestor in result) {
                    result.append(ancestor);
                }
            }
        }
    }
    return result;
}

def class_lookup_attr(cls: PyClass, name: str) -> PyObj {
    for klass in class_mro(cls) {
        if name in klass.attrs {
            return klass.attrs[name];
        }
    }
    return py_error("AttributeError", name);
}

# super().name lookup: search the instance's MRO starting AFTER the defining
# class (zero-arg super semantics). defining_cls comes from the __class__ cell;
# if it isn't a PyClass, fall back to the instance's own class.
# `builtin.__new__(cls, *box_args)` reached through super() from a subclass's
# own __new__ (e.g. re._constants._NamedIntConstant, IntEnum members). The first
# arg is the class to instantiate; the rest box the builtin base. Returns a
# PyUserObj tagged with that class so the subclass's identity and attributes
# (a .name set right after) survive -- exactly the value/ref line Track B draws.
obj PyNativeNew(PyObj) {
    has base_name: str;

    # Value identity by base_name so every object.__new__ producer compares equal
    # (enum's _find_new_ does `target in {object.__new__, ...}`).
    def tp_hashkey -> str {
        return "nativenew:" + self.base_name;
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        same = isinstance(other, PyNativeNew)
            and self.base_name == (other as PyNativeNew).base_name;
        if kind == 2 {
            return PyBool(t="bool", val=same);
        }
        if kind == 3 {
            return PyBool(t="bool", val=not same);
        }
        return py_error("TypeError", "unsupported comparison");
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) == 0 {
            return py_error("TypeError", "__new__() takes a class argument");
        }
        target_cls = args[0];
        # type.__new__(mcls, name, bases, namespace): the class factory reached by
        # super().__new__ inside a metaclass __new__. Builds a PyClass tagged with
        # mcls as its metaclass so a subclass re-runs the same protocol.
        if self.base_name == "type" {
            return type_new(args);
        }
        # object.__new__(cls): a plain instance, no boxed builtin value. This is
        # the super().__new__(cls) / object.__new__(cls) path of a class whose
        # only base is object (functools._PlaceholderType, most user classes).
        if self.base_name == "object" {
            if isinstance(target_cls, PyClass) {
                return PyUserObj(
                    t="instance", cls=target_cls as PyClass, attrs={}, base=py_none()
                );
            }
            return py_error("TypeError", "object.__new__ requires a class");
        }
        box_args: list[PyObj] = [];
        j = 1;
        while j < len(args) {
            box_args.append(args[j]);
            j = j + 1;
        }
        # builtin.__new__ over a HOST class (namedtuple's dynamic tuple subclass)
        # stays host-side so the host subclass instance is preserved.
        if isinstance(target_cls, PyHostProxy) {
            raw_box: list[any] = [];
            for a in box_args {
                raw_box.append(to_host(a));
            }
            hres = _jac_builtin_new(
                self.base_name, (target_cls as PyHostProxy).val, raw_box
            );
            if host_result_ok(hres) {
                return from_host(hres[1]);
            }
            return py_error(str(hres[1]), str(hres[2]));
        }
        boxed = construct_native_base(self.base_name, box_args);
        if is_error(boxed) {
            return boxed;
        }
        if isinstance(target_cls, PyClass) {
            return PyUserObj(
                t="instance", cls=target_cls as PyClass, attrs={}, base=boxed
            );
        }
        # Called with the exact builtin type (not a user subclass): plain value.
        return boxed;
    }
}

# super().<dunder>(...) inside a builtin-subclass method (dict/list/... subclass)
# resolves to the boxed base's own slot -- e.g. _EnumDict(dict).__setitem__ calling
# super().__setitem__(k, v) mutates the underlying dict. Bound to the instance's
# boxed value at lookup time, so the call site applies only the operands.
obj PyBuiltinSuperMethod(PyObj) {
    has base: PyObj,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        n = self.name;
        b = self.base;
        if n == "__init__" {
            # super().__init__(...) on a mutable base. Empty (the common case, e.g.
            # EnumDict) is a no-op; a mapping argument fills the boxed dict.
            if len(args) == 0 {
                return py_none();
            }
            if isinstance(b, PyDict) and isinstance(args[0], PyDict) {
                src = args[0] as PyDict;
                for keyobj in src.dict_keys() {
                    (b as PyDict).dict_set(keyobj, src.mp_subscript(keyobj));
                }
                return py_none();
            }
            return py_none();
        }
        if n == "__setitem__" {
            return b.mp_ass_subscript(args[0], args[1]);
        }
        if n == "__getitem__" {
            return b.mp_subscript(args[0]);
        }
        if n == "__delitem__" {
            return b.mp_del_subscript(args[0]);
        }
        if n == "__len__" {
            return py_len(b);
        }
        if n == "__iter__" {
            return b.tp_iter();
        }
        if n == "__contains__" {
            return py_contains(b, args[0]);
        }
        return py_error("AttributeError", n);
    }
}

# True iff `inst` is an instance of `cls` (walks the instance class's MRO).
def instance_of_class(inst: PyUserObj, cls: PyClass) -> bool {
    for klass in class_mro(inst.cls) {
        if klass is cls {
            return True;
        }
    }
    return False;
}

def super_lookup(defining_cls: PyObj, instance: PyObj, name: str) -> PyObj {
    # `instance` is a real instance for a normal super().method(), but a CLASS
    # for super(Cls, cls).__new__(...) inside a __new__. Resolve which class's
    # MRO to walk from either shape.
    walk_cls = py_none();
    if isinstance(instance, PyUserObj) {
        walk_cls = (instance as PyUserObj).cls;
    } elif isinstance(instance, PyClass) {
        walk_cls = instance;
    } else {
        return py_error("AttributeError", name);
    }
    start: PyClass = walk_cls as PyClass;
    if isinstance(defining_cls, PyClass) {
        start = defining_cls as PyClass;
    }
    mro = class_mro(walk_cls as PyClass);
    past = False;
    for klass in mro {
        if past and name in klass.attrs {
            return klass.attrs[name];
        }
        if klass is start {
            past = True;
        }
    }
    # No python ancestor defines it. A super().<dunder>() on a boxed-builtin
    # subclass (dict/list/... subclass calling super().__setitem__ etc.) delegates
    # to the base value's own slot.
    if name != "__new__" and isinstance(instance, PyUserObj) {
        inst = instance as PyUserObj;
        if inst._has_base() {
            return PyBuiltinSuperMethod(
                t="builtin_super", base=inst._base_obj(), name=name
            );
        }
    }
    # No python ancestor defines it. super().__new__ resolves to the base
    # constructor: a builtin (int.__new__, str.__new__, ...) when the chain boxes
    # one, else object.__new__ (a plain instance of the class).
    if name == "__new__" {
        base = start.native_base;
        for klass in mro {
            if klass.native_base != "" {
                base = klass.native_base;
            }
        }
        if base == "" {
            base = "object";
        }
        return PyNativeNew(t="native_new", base_name=base);
    }
    return py_error("AttributeError", name);
}

# Box a builtin subclass instance by running the builtin constructor over the
# call args (int("5") -> 5, list(x) -> [...]). Errors propagate.
def construct_native_base(name: str, args: list[PyObj]) -> PyObj {
    raw_args: list[any] = [];
    for a in args {
        raw_args.append(to_host(a));
    }
    result = _jac_construct_builtin(name, raw_args);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return py_error(str(result[1]), str(result[2]));
}

# For operator delegation: a builtin subclass on either operand acts as its
# boxed value (MyInt(5) + MyInt(1) -> 5 + 1).
def unwrap_base(o: PyObj) -> PyObj {
    if isinstance(o, PyUserObj) {
        u = o as PyUserObj;
        if u._has_base() {
            return u._base_obj();
        }
    }
    return o;
}

# True iff `obj` counts as an instance of the builtin named `name`, honoring
# builtin-subclass boxing and the bool<:int relationship.
def obj_is_builtin(ob: PyObj, name: str) -> bool {
    if name == "object" {
        return True;
    }
    if isinstance(ob, PyUserObj) {
        u = ob as PyUserObj;
        for klass in class_mro(u.cls) {
            if klass.native_base == name {
                return True;
            }
        }
        if u._has_base() {
            return obj_is_builtin(u._base_obj(), name);
        }
        return False;
    }
    if ob.t == name {
        return True;
    }
    if name == "int" and ob.t == "bool" {
        return True;
    }
    return False;
}

def py_isinstance(ob: PyObj, typ: PyObj) -> bool {
    if isinstance(typ, PyTuple) {
        for t in (typ as PyTuple).items {
            if py_isinstance(ob, t) {
                return True;
            }
        }
        return False;
    }
    if isinstance(typ, PyClass) {
        if isinstance(ob, PyUserObj) {
            for klass in class_mro((ob as PyUserObj).cls) {
                if klass is (typ as PyClass) {
                    return True;
                }
            }
        }
        # isinstance(SomeClass, Meta): a class is an instance of its metaclass, so
        # walk the class's metaclass MRO (isinstance(Enum, EnumType) is True).
        if isinstance(ob, PyClass) {
            meta = (ob as PyClass).metaclass;
            if meta is not None and isinstance(meta, PyClass) {
                for klass in class_mro(meta as PyClass) {
                    if klass is (typ as PyClass) {
                        return True;
                    }
                }
            }
        }
        return False;
    }
    if isinstance(typ, PyHostProxy) {
        host_type = (typ as PyHostProxy).val;
        name: str = str(_jac_builtin_base_name(host_type));
        if name != "" {
            return obj_is_builtin(ob, name);
        }
        return bool(_jac_host_isinstance(to_host(ob), host_type));
    }
    return False;
}

def py_issubclass(cls: PyObj, typ: PyObj) -> bool {
    if isinstance(typ, PyTuple) {
        for t in (typ as PyTuple).items {
            if py_issubclass(cls, t) {
                return True;
            }
        }
        return False;
    }
    if isinstance(cls, PyClass) {
        c = cls as PyClass;
        if isinstance(typ, PyClass) {
            for klass in class_mro(c) {
                if klass is (typ as PyClass) {
                    return True;
                }
            }
            return False;
        }
        if isinstance(typ, PyHostProxy) {
            name: str = str(_jac_builtin_base_name((typ as PyHostProxy).val));
            if name == "object" {
                return True;
            }
            if name != "" {
                for klass in class_mro(c) {
                    if klass.native_base == name {
                        return True;
                    }
                }
            }
            return False;
        }
        return False;
    }
    if isinstance(cls, PyHostProxy) and isinstance(typ, PyHostProxy) {
        return bool(_jac_host_issubclass(
            (cls as PyHostProxy).val, (typ as PyHostProxy).val
        ));
    }
    return False;
}

# The builtin ancestor (if any) that dictates a class's instance layout, plus the
# `type` marker for a metaclass. Inherited from a user base's own native_base when
# subclassing a subclass; read off a host builtin/`type` base directly.
# The subclassable builtins whose instances are filled by __init__ rather than
# frozen at __new__ time. A user __init__ on such a subclass creates an empty base
# and fills it (usually via super().__init__).
def is_mutable_base(name: str) -> bool {
    return name == "dict" or name == "list" or name == "set";
}

def compute_native_base(bases: list[PyObj]) -> str {
    native_base = "";
    for base in bases {
        if isinstance(base, PyClass) {
            inherited = (base as PyClass).native_base;
            if inherited != "" {
                native_base = inherited;
            }
        } elif isinstance(base, PyHostProxy) {
            hostval = (base as PyHostProxy).val;
            if _jac_is_type_type(hostval) {
                # `class Meta(type)` -- a metaclass. super().__new__ builds classes.
                native_base = "type";
            } else {
                builtin_name: str = str(_jac_builtin_base_name(hostval));
                if builtin_name != "" and builtin_name != "object" {
                    native_base = builtin_name;
                }
            }
        }
    }
    return native_base;
}

# Box a PyClass from a resolved name/bases/namespace. `meta` is the metaclass that
# produced it (None = the default `type`), recorded so a later subclass can
# re-derive and re-run the metaclass protocol.
def make_pyclass_from_map(
    class_name: str, bases: list[PyObj],
    namespace: dict[str, PyObj], meta: any
) -> PyClass {
    return PyClass(
        t="class",
        name=class_name,
        attrs=namespace,
        bases=bases,
        native_base=compute_native_base(bases),
        metaclass=meta
    );
}

# type.__new__(mcls, name, bases, namespace): build a class object. Serves both
# the metaclass super().__new__ path and a bare 3-arg type(name, bases, ns) call.
def type_new(args: list[PyObj]) -> PyObj {
    if len(args) < 4 {
        return py_error("TypeError", "type.__new__() takes name, bases, dict");
    }
    mcls = args[0];
    class_name = expect_str(args[1]);
    bases: list[PyObj] = [];
    bases_obj = args[2];
    if isinstance(bases_obj, PyTuple) {
        bases = (bases_obj as PyTuple).items;
    } elif isinstance(bases_obj, PyList) {
        bases = (bases_obj as PyList).items;
    }
    namespace = extract_namespace(args[3]);
    cls = make_pyclass_from_map(class_name, bases, namespace, mcls);
    ordered: list[str] = [];
    for k in namespace {
        ordered.append(k);
    }
    return apply_set_name_hooks(cls, ordered);
}

# After a class is built, type.__new__ calls __set_name__(cls, name) on every
# namespace value that defines it, in definition order (PEP 487). This drives
# enum member creation: each _proto_member's __set_name__ builds the real member
# and registers it on the class. Returns the class, or the first hook's error.
def apply_set_name_hooks(cls: PyClass, ordered_names: list[str]) -> PyObj {
    for name in ordered_names {
        if name in cls.attrs {
            value = cls.attrs[name];
            if isinstance(value, PyUserObj)
                and user_has_dunder(value as PyUserObj, "__set_name__") {
                res = call_user_dunder(
                    value as PyUserObj, "__set_name__",
                    [cls, PyStr(t="str", val=name)]
                );
                if is_error(res) {
                    return res;
                }
            }
        }
    }
    return cls;
}

# Read a PyDict whose keys are all strings (a class namespace) into a jac str map.
def pydict_to_str_map(d: PyDict) -> dict[str, PyObj] {
    m: dict[str, PyObj] = {};
    for keyobj in d.dict_keys() {
        val = d.mp_subscript(keyobj);
        m[expect_str(keyobj)] = val;
    }
    return m;
}

# The class namespace as a str map, whether the metaclass __prepare__ returned a
# plain dict or a custom mapping (a dict-subclass like enum's _EnumDict, which
# boxes a real dict). A mapping's own tracking attributes stay on the object; the
# stored member/method entries live in the boxed dict.
def extract_namespace(ns_obj: PyObj) -> dict[str, PyObj] {
    if isinstance(ns_obj, PyDict) {
        return pydict_to_str_map(ns_obj as PyDict);
    }
    if isinstance(ns_obj, PyUserObj) {
        u = ns_obj as PyUserObj;
        if u._has_base() and isinstance(u._base_obj(), PyDict) {
            return pydict_to_str_map(u._base_obj() as PyDict);
        }
    }
    return {};
}

# The metaclass of a base object (its `type`), or None. Only PyClass bases carry a
# recorded metaclass; a host base (object/type/builtins) resolves to the default.
def metaclass_of(base: PyObj) -> any {
    if isinstance(base, PyClass) {
        m = (base as PyClass).metaclass;
        if m is not None and isinstance(m, PyClass) {
            return m;
        }
    }
    return None;
}

# Pick the class's metaclass: the most-derived of an explicit `metaclass=` kwarg
# and every base's own metaclass (CPython's winner rule). Returns None for the
# default `type` path. An explicit `metaclass=type` (host proxy) stays default.
def resolve_metaclass(kwargs: dict[str, PyObj], bases: list[PyObj]) -> any {
    winner: any = None;
    if "metaclass" in kwargs {
        m = kwargs["metaclass"];
        if isinstance(m, PyClass) {
            winner = m;
        }
    }
    for base in bases {
        bm = metaclass_of(base);
        if isinstance(bm, PyClass) {
            if winner is None {
                winner = bm;
            } elif py_issubclass(bm as PyObj, winner as PyObj) {
                winner = bm;
            }
        }
    }
    return winner;
}

def py_build_class(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    if len(args) < 2 {
        return py_error("TypeError", "__build_class__ needs a body and name");
    }
    body = args[0] as PyFunction;
    class_name = expect_str(args[1]);
    # args[2:] are the base objects.
    bases: list[PyObj] = [];
    j = 2;
    while j < len(args) {
        bases.append(args[j]);
        j = j + 1;
    }
    # Class keyword args other than `metaclass` are forwarded to __prepare__ and
    # the metaclass call (e.g. __init_subclass__ kwargs).
    class_kwds: dict[str, PyObj] = {};
    for k in kwargs {
        if k != "metaclass" {
            class_kwds[k] = kwargs[k];
        }
    }
    metaclass = resolve_metaclass(kwargs, bases);
    # A user metaclass (EnumType, ABCMeta): run the full protocol -- __prepare__
    # for the body namespace, then call the metaclass as the class factory.
    if isinstance(metaclass, PyClass) {
        return build_class_via_metaclass(
            metaclass as PyClass, class_name, bases, body, class_kwds
        );
    }
    # Default `type`: execute the body into a plain namespace and box a PyClass.
    namespace: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    body_result = exec_code_frame(
        body.code, [], {}, body.globals, namespace, body.closure, [], {}
    );
    if body_result.t == "error" {
        return body_result;
    }
    cls = make_pyclass_from_map(class_name, bases, namespace, None);
    ordered: list[str] = [];
    for k in namespace {
        ordered.append(k);
    }
    return apply_set_name_hooks(cls, ordered);
}

# The custom-metaclass class-creation protocol: metaclass.__prepare__ produces the
# body namespace, the body runs into it, then the metaclass is called as
# (name, bases, namespace, **kwds) -- its __new__/__init__ build and finish the
# class. Only a plain-dict namespace is supported; a custom mapping (enum's
# _EnumDict) as a live body namespace is a later refinement.
def build_class_via_metaclass(
    metaclass: PyClass, class_name: str, bases: list[PyObj],
    body: PyFunction, class_kwds: dict[str, PyObj]
) -> PyObj {
    bases_tuple = PyTuple(t="tuple", items=bases);
    prepared: PyObj = py_none();
    prep = class_lookup_attr(metaclass, "__prepare__");
    if not is_error(prep) {
        prep_args: list[PyObj] = [PyStr(t="str", val=class_name), bases_tuple];
        prepared = py_invoke(bind_attribute(prep, metaclass), prep_args, class_kwds);
        if is_error(prepared) {
            return prepared;
        }
    }
    # A custom mapping namespace (enum's _EnumDict, a dict subclass): run the body
    # into a plain ordered map, then replay each binding through the mapping's
    # __setitem__ so its member-tracking side effects fire in source order. The
    # mapping itself is handed to the metaclass as the classdict.
    if isinstance(prepared, PyUserObj) {
        namespace: dict[str, PyObj] = {};
        body_result = exec_code_frame(
            body.code, [], {}, body.globals, namespace, body.closure, [], {}
        );
        if body_result.t == "error" {
            return body_result;
        }
        mapping = prepared as PyUserObj;
        if user_has_dunder(mapping, "__setitem__") {
            for k in namespace {
                res = call_user_dunder(
                    mapping, "__setitem__", [PyStr(t="str", val=k), namespace[k]]
                );
                if is_error(res) {
                    return res;
                }
            }
        }
        call_args: list[PyObj] = [
            PyStr(t="str", val=class_name), bases_tuple, prepared
        ];
        return py_invoke(metaclass, call_args, class_kwds);
    }
    # A plain-dict (or absent) namespace: seed, run the body, box a real dict.
    namespace2: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    if isinstance(prepared, PyDict) {
        prep_map = pydict_to_str_map(prepared as PyDict);
        for pk in prep_map {
            namespace2[pk] = prep_map[pk];
        }
    }
    body_result2 = exec_code_frame(
        body.code, [], {}, body.globals, namespace2, body.closure, [], {}
    );
    if body_result2.t == "error" {
        return body_result2;
    }
    ns_dict = dict_from_str_map(namespace2);
    call_args2: list[PyObj] = [
        PyStr(t="str", val=class_name), bases_tuple, ns_dict
    ];
    return py_invoke(metaclass, call_args2, class_kwds);
}

def make_function_from_stack(stack: list[PyObj], globals: dict[str, PyObj]) -> PyObj {
    if len(stack) == 0 {
        return py_error("RuntimeError", "MAKE_FUNCTION stack underflow");
    }
    code_obj = stack.pop();
    if code_obj.t != "code" {
        return py_error("TypeError", "MAKE_FUNCTION needs code");
    }
    code = code_obj as PyCode;
    return PyFunction(t="function", code=code, globals=globals, name=code.name);
}

# ---------------- generator frame machinery (PLAN.md §5, P5) ----------------
# CPython implements a generator as a suspended frame; jacpython mirrors that.
# PyFrame captures the resumable eval state (stack/fast/cells/ip). YIELD_VALUE
# saves it and hands a PyYield up to run_frame's caller; PyGenerator drives the
# frame forward one yield at a time. PyGenStop is the "frame returned normally"
# (StopIteration) sentinel that distinguishes exhaustion from a real raise.
obj PyFrame(PyObj) {
    has co: PyCode,
        fast: list[PyObj],
        assigned: list[bool],
        cells: list[PyCell],
        closure: list[PyCell],
        stack: list[PyObj],
        globals: dict[str, PyObj],
        locals: dict[str, PyObj],
        ip: int = 0,
        # True when suspended inside `yield from` (YIELD_VALUE oparg 1). A throw
        # is then delegated into the sub-iterator via the SEND loop rather than
        # injected at the outer suspend point.
        yf: bool = False,
        # A pending exception to throw into the current yield-from sub-iterator,
        # consumed by the next SEND instead of a normal send.
        pending_throw: any = None,
        # True once the frame's locals/stack have been released (gen.close() or
        # gi_frame.clear()); guards against running __del__ finalizers twice.
        cleared: bool = False;
}

obj PyYield(PyObj) {
    has val: PyObj;
}

# next()/iter() as native callables (host_builtin routes these here) so they
# drive a native generator/iterator in-VM rather than draining it to a host list.
obj PyNativeBuiltin(PyObj) {
    has name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if self.name == "id" {
            if len(args) == 0 {
                return py_error("TypeError", "id expected 1 argument");
            }
            return PyInt(t="int", val=py_id(args[0]));
        }
        if self.name == "len" {
            if len(args) != 1 {
                return py_error(
                    "TypeError", "len() takes exactly one argument"
                );
            }
            return py_len(args[0]);
        }
        if self.name == "isinstance" {
            if len(args) < 2 {
                return py_error("TypeError", "isinstance expected 2 arguments");
            }
            return PyBool(t="bool", val=py_isinstance(args[0], args[1]));
        }
        if self.name == "issubclass" {
            if len(args) < 2 {
                return py_error("TypeError", "issubclass expected 2 arguments");
            }
            return PyBool(t="bool", val=py_issubclass(args[0], args[1]));
        }
        if self.name == "getattr" {
            # getattr(obj, name[, default]): native attribute access, honoring a
            # 3rd-arg default on AttributeError (CPython only swallows that one).
            if len(args) < 2 {
                return py_error("TypeError", "getattr expected at least 2 arguments");
            }
            attr = py_attr(args[0], expect_str(args[1]));
            if is_error(attr) and len(args) >= 3
            and (attr as PyError).exception.type_name == "AttributeError" {
                return args[2];
            }
            return attr;
        }
        if self.name == "hasattr" {
            if len(args) < 2 {
                return py_error("TypeError", "hasattr expected 2 arguments");
            }
            probe = py_attr(args[0], expect_str(args[1]));
            return PyBool(t="bool", val=not is_error(probe));
        }
        if self.name == "setattr" {
            if len(args) < 3 {
                return py_error("TypeError", "setattr expected 3 arguments");
            }
            return py_set_attr(args[0], expect_str(args[1]), args[2]);
        }
        if self.name == "delattr" {
            if len(args) < 2 {
                return py_error("TypeError", "delattr expected 2 arguments");
            }
            return py_del_attr(args[0], expect_str(args[1]));
        }
        if self.name == "iter" {
            if len(args) == 0 {
                return py_error("TypeError", "iter expected at least 1 argument");
            }
            result = py_iter(args[0]);
            if is_error(result) {
                # Types without a native tp_iter (dict views, etc.) iterate on
                # the host, materialized into a native PyIter.
                return host_iter(PyHostProxy(t="host", val=to_host(args[0])));
            }
            return result;
        }
        # next(iterator[, default])
        if len(args) == 0 {
            return py_error("TypeError", "next expected at least 1 argument");
        }
        step = send_into(args[0], py_none());
        if step.t == "genstop" {
            if len(args) > 1 {
                return args[1];
            }
            return stop_iteration(py_none());
        }
        return step;
    }
}

# A live view of a running frame's globals (`dict[str, PyObj]`, held by
# reference). globals() returns one so module init idioms that MUTATE the module
# namespace -- globals().update({...}), globals()[name] = value -- bind real
# globals a later LOAD_GLOBAL/LOAD_NAME resolves. A snapshot dict would silently
# drop those writes (re._constants._makecodes builds its OPCODES this way).
obj PyGlobalsProxy(PyObj) {
    has ns: dict[str, PyObj];

    def mp_subscript(index: PyObj) -> PyObj {
        key = expect_str(index);
        if key in self.ns {
            return self.ns[key];
        }
        return py_error("KeyError", key);
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        self.ns[expect_str(index)] = value;
        return py_none();
    }

    # Iterating globals() yields its keys (module code does
    # `[n for n in globals() if ...]` to compute __all__).
    def tp_iter -> PyObj {
        keys: list[PyObj] = [];
        for k in self.ns {
            keys.append(PyStr(t="str", val=k));
        }
        return PyIter(t="iter", items=keys, index=0);
    }

    def tp_getattro(name: str) -> PyObj {
        if name == "update" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="update");
        }
        if name == "get" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="get");
        }
        if name == "keys" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="keys");
        }
        if name == "values" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="values");
        }
        if name == "items" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="items");
        }
        if name == "setdefault" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="setdefault");
        }
        return py_error("AttributeError", name);
    }
}

# The bound dict-method objects a PyGlobalsProxy hands out. Kept minimal to the
# surface module-init code exercises; each mutates/reads the shared ns directly.
obj PyNsMethod(PyObj) {
    has ns: dict[str, PyObj],
        op: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if self.op == "update" {
            if len(args) > 0 {
                src = args[0];
                pairs: PyObj = py_none();
                if isinstance(src, PyDict) {
                    pairs = src;
                } else {
                    pairs = from_host(to_host(src));
                }
                if isinstance(pairs, PyDict) {
                    smap = (pairs as PyDict).dict_str_map();
                    for k in smap {
                        self.ns[k] = smap[k];
                    }
                }
            }
            for kw in kwargs {
                self.ns[kw] = kwargs[kw];
            }
            return py_none();
        }
        if self.op == "get" {
            if len(args) > 0 {
                key = expect_str(args[0]);
                if key in self.ns {
                    return self.ns[key];
                }
            }
            if len(args) > 1 {
                return args[1];
            }
            return py_none();
        }
        if self.op == "setdefault" {
            if len(args) > 0 {
                key = expect_str(args[0]);
                if key in self.ns {
                    return self.ns[key];
                }
                fallback = py_none();
                if len(args) > 1 {
                    fallback = args[1];
                }
                self.ns[key] = fallback;
                return fallback;
            }
            return py_none();
        }
        if self.op == "keys" {
            out: list[PyObj] = [];
            for k in self.ns {
                out.append(PyStr(t="str", val=k));
            }
            return PyList(t="list", items=out);
        }
        if self.op == "values" {
            vout: list[PyObj] = [];
            for k in self.ns {
                vout.append(self.ns[k]);
            }
            return PyList(t="list", items=vout);
        }
        if self.op == "items" {
            iout: list[PyObj] = [];
            for k in self.ns {
                pair: list[PyObj] = [PyStr(t="str", val=k), self.ns[k]];
                iout.append(PyTuple(t="tuple", items=pair));
            }
            return PyList(t="list", items=iout);
        }
        return py_error("TypeError", "unsupported namespace op");
    }
}

# ---- native set methods (.pop/.difference/.union/... ) --------------------
# PySet is a native (na-clean leaf) container, so its methods can't route to the
# host the way str/list/dict do -- to_host would round-trip and lose identity.
# The method surface lives here (host-adjacent: arbitrary-iterable args are
# drained through py_iter/host_iter), wrapping the leaf's value-based set algebra.

# Materialize any iterable arg into a PyList of its members, or return a PyError
# if it is not iterable (this is the TypeError set().difference(123) must raise).
def members_of(arg: PyObj) -> PyObj {
    if isinstance(arg, PySet) {
        return PyList(t="list", items=(arg as PySet).set_members());
    }
    if isinstance(arg, PyList) {
        return arg;
    }
    it = py_iter(arg);
    if is_error(it) {
        it = host_iter(PyHostProxy(t="host", val=to_host(arg)));
        if is_error(it) {
            return it;
        }
    }
    out: list[PyObj] = [];
    while True {
        step = send_into(it, py_none());
        if step.t == "genstop" {
            break;
        }
        if is_error(step) {
            return step;
        }
        out.append(step);
    }
    return PyList(t="list", items=out);
}

def set_from_members(members: list[PyObj], frozen: bool) -> PyObj {
    tag = "set";
    if frozen {
        tag = "frozenset";
    }
    s = PySet(t=tag, items={}, frozen=frozen);
    for m in members {
        r = s.set_add(m);
        if is_error(r) {
            return r;
        }
    }
    return s;
}

# Build a fresh PySet from one iterable arg (used to coerce a .difference([...])
# operand into set algebra). Propagates the not-iterable TypeError.
def coerce_set(arg: PyObj) -> PyObj {
    om = members_of(arg);
    if is_error(om) {
        return om;
    }
    return set_from_members((om as PyList).items, False);
}

def is_set_method(name: str, frozen: bool) -> bool {
    shared = name == "copy"
    or name == "union"
    or name == "intersection"
    or name == "difference"
    or name == "symmetric_difference"
    or name == "issubset"
    or name == "issuperset"
    or name == "isdisjoint"
    or name == "__contains__";
    if shared {
        return True;
    }
    if frozen {
        return False;
    }
    return name == "add"
    or name == "discard"
    or name == "remove"
    or name == "pop"
    or name == "clear"
    or name == "update"
    or name == "difference_update"
    or name == "intersection_update"
    or name == "symmetric_difference_update";
}

obj PySetMethod(PyObj) {
    has target: PySet,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        n = self.name;
        s = self.target;
        if n == "__contains__" {
            if len(args) < 1 {
                return py_error("TypeError", "__contains__ expected 1 argument");
            }
            return PyBool(t="bool", val=s.set_contains(args[0]));
        }
        # --- no-arg mutating / accessor methods ---
        if n == "pop" {
            return s.set_pop();
        }
        if n == "copy" {
            return s.set_copy();
        }
        if n == "clear" {
            return s.set_clear();
        }
        if n == "add" {
            if len(args) < 1 {
                return py_error("TypeError", "add expected 1 argument");
            }
            return s.set_add(args[0]);
        }
        if n == "discard" {
            if len(args) < 1 {
                return py_error("TypeError", "discard expected 1 argument");
            }
            return s.set_discard(args[0]);
        }
        if n == "remove" {
            if len(args) < 1 {
                return py_error("TypeError", "remove expected 1 argument");
            }
            if not s.set_contains(args[0]) {
                return py_error("KeyError", dict_key_repr(args[0]));
            }
            return s.set_discard(args[0]);
        }
        # --- single-iterable-arg predicates ---
        if n == "issubset" or n == "issuperset" or n == "isdisjoint" {
            if len(args) < 1 {
                return py_error("TypeError", n + " expected 1 argument");
            }
            other = coerce_set(args[0]);
            if is_error(other) {
                return other;
            }
            os = other as PySet;
            if n == "issubset" {
                return s.tp_richcompare(1, os);
            }
            if n == "issuperset" {
                return s.tp_richcompare(5, os);
            }
            # isdisjoint: no shared member.
            for hk in s.items {
                if hk in os.items {
                    return PyBool(t="bool", val=False);
                }
            }
            return PyBool(t="bool", val=True);
        }
        # --- *others set-algebra (non-mutating) ---
        if n == "union" or n == "intersection" or n == "difference"
        or n == "symmetric_difference" {
            kind = 7;
            if n == "intersection" {
                kind = 1;
            } elif n == "difference" {
                kind = 10;
            } elif n == "symmetric_difference" {
                kind = 12;
            }
            acc = s.set_copy();
            for a in args {
                other = coerce_set(a);
                if is_error(other) {
                    return other;
                }
                acc = acc.nb_binop(kind, other as PySet);
                if is_error(acc) {
                    return acc;
                }
            }
            return acc;
        }
        # --- *others mutating updates ---
        if n == "update" or n == "difference_update"
        or n == "intersection_update" or n == "symmetric_difference_update" {
            kind = 7;
            if n == "difference_update" {
                kind = 10;
            } elif n == "intersection_update" {
                kind = 1;
            } elif n == "symmetric_difference_update" {
                kind = 12;
            }
            acc = s.set_copy();
            for a in args {
                other = coerce_set(a);
                if is_error(other) {
                    return other;
                }
                acc = acc.nb_binop(kind, other as PySet);
                if is_error(acc) {
                    return acc;
                }
            }
            # Write the result back into the receiver's storage in place.
            s.items = (acc as PySet).items;
            return py_none();
        }
        return py_error("AttributeError", n);
    }
}

# Native mutating/accessor list methods. Without these, `lst.append(x)` routes to
# host_getattr on a to_host COPY of the list -- the mutation is lost. Load-bearing
# for any code that builds a list by `.append` (enum's EnumDict._member_names
# tracking, most stdlib), not just comprehensions (which use LIST_APPEND).
def is_list_method(name: str) -> bool {
    return name == "append" or name == "extend" or name == "insert"
        or name == "pop" or name == "remove" or name == "clear"
        or name == "index" or name == "count" or name == "reverse"
        or name == "copy";
}

# Materialize the elements of a native iterable argument (list/tuple/set/iter).
def iterable_items(src: PyObj) -> list[PyObj] {
    if isinstance(src, PyList) {
        return (src as PyList).items;
    }
    if isinstance(src, PyTuple) {
        return (src as PyTuple).items;
    }
    if isinstance(src, PySet) {
        return (src as PySet).set_members();
    }
    if isinstance(src, PyIter) {
        return (src as PyIter).items;
    }
    it = py_iter(src);
    if isinstance(it, PyIter) {
        return (it as PyIter).items;
    }
    return [];
}

obj PyListMethod(PyObj) {
    has target: PyList,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        n = self.name;
        lst = self.target;
        if n == "append" {
            lst.items.append(args[0]);
            return py_none();
        }
        if n == "extend" {
            for x in iterable_items(args[0]) {
                lst.items.append(x);
            }
            return py_none();
        }
        if n == "insert" {
            i = (args[0].to_index() as PyInt).val;
            if i < 0 {
                i = len(lst.items) + i;
            }
            if i < 0 {
                i = 0;
            }
            if i > len(lst.items) {
                i = len(lst.items);
            }
            rebuilt: list[PyObj] = [];
            j = 0;
            while j < len(lst.items) {
                if j == i {
                    rebuilt.append(args[1]);
                }
                rebuilt.append(lst.items[j]);
                j = j + 1;
            }
            if i >= len(lst.items) {
                rebuilt.append(args[1]);
            }
            lst.items = rebuilt;
            return py_none();
        }
        if n == "pop" {
            if len(lst.items) == 0 {
                return py_error("IndexError", "pop from empty list");
            }
            i = len(lst.items) - 1;
            if len(args) >= 1 {
                i = (args[0].to_index() as PyInt).val;
                if i < 0 {
                    i = len(lst.items) + i;
                }
            }
            if i < 0 or i >= len(lst.items) {
                return py_error("IndexError", "pop index out of range");
            }
            v = lst.items[i];
            kept: list[PyObj] = [];
            j = 0;
            while j < len(lst.items) {
                if j != i {
                    kept.append(lst.items[j]);
                }
                j = j + 1;
            }
            lst.items = kept;
            return v;
        }
        if n == "remove" {
            j = 0;
            while j < len(lst.items) {
                if list_elem_eq(lst.items[j], args[0]) {
                    kept2: list[PyObj] = [];
                    k = 0;
                    while k < len(lst.items) {
                        if k != j {
                            kept2.append(lst.items[k]);
                        }
                        k = k + 1;
                    }
                    lst.items = kept2;
                    return py_none();
                }
                j = j + 1;
            }
            return py_error("ValueError", "list.remove(x): x not in list");
        }
        if n == "clear" {
            lst.items = [];
            return py_none();
        }
        if n == "index" {
            j = 0;
            while j < len(lst.items) {
                if list_elem_eq(lst.items[j], args[0]) {
                    return PyInt(t="int", val=j);
                }
                j = j + 1;
            }
            return py_error("ValueError", "not in list");
        }
        if n == "count" {
            c = 0;
            for x in lst.items {
                if list_elem_eq(x, args[0]) {
                    c = c + 1;
                }
            }
            return PyInt(t="int", val=c);
        }
        if n == "reverse" {
            rev: list[PyObj] = [];
            j = len(lst.items) - 1;
            while j >= 0 {
                rev.append(lst.items[j]);
                j = j - 1;
            }
            lst.items = rev;
            return py_none();
        }
        if n == "copy" {
            dup: list[PyObj] = [];
            for x in lst.items {
                dup.append(x);
            }
            return PyList(t="list", items=dup);
        }
        return py_error("AttributeError", n);
    }
}

# Element equality for list membership (remove/index/count): a real __eq__ so a
# user object or boxed value compares by value, not identity.
def list_elem_eq(a: PyObj, b: PyObj) -> bool {
    res = py_compare(2, a, b);
    if isinstance(res, PyBool) {
        return (res as PyBool).val;
    }
    return False;
}

# The native mutating/accessor dict methods. keys()/values()/items() are served
# separately by PyDictViewCtor; these must be native too so that a mutation on a
# dict subclass instance (enum's EnumDict.setdefault/pop) hits the real storage
# instead of a throwaway to_host copy.
def is_dict_method(name: str) -> bool {
    return name == "get" or name == "setdefault" or name == "pop"
        or name == "popitem" or name == "update" or name == "clear"
        or name == "copy" or name == "__contains__" or name == "__getitem__"
        or name == "__setitem__" or name == "__delitem__";
}

obj PyDictMethod(PyObj) {
    has target: PyDict,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        n = self.name;
        d = self.target;
        if n == "get" {
            if d.dict_contains(args[0]) {
                return d.mp_subscript(args[0]);
            }
            return args[1] if len(args) >= 2 else py_none();
        }
        if n == "setdefault" {
            if d.dict_contains(args[0]) {
                return d.mp_subscript(args[0]);
            }
            default = args[1] if len(args) >= 2 else py_none();
            r = d.mp_ass_subscript(args[0], default);
            if is_error(r) {
                return r;
            }
            return default;
        }
        if n == "pop" {
            if d.dict_contains(args[0]) {
                v = d.mp_subscript(args[0]);
                d.mp_del_subscript(args[0]);
                return v;
            }
            if len(args) >= 2 {
                return args[1];
            }
            return py_error("KeyError", dict_key_repr(args[0]));
        }
        if n == "popitem" {
            for keyobj in d.dict_keys() {
                v = d.mp_subscript(keyobj);
                d.mp_del_subscript(keyobj);
                return PyTuple(t="tuple", items=[keyobj, v]);
            }
            return py_error("KeyError", "popitem(): dictionary is empty");
        }
        if n == "clear" {
            for keyobj in d.dict_keys() {
                d.mp_del_subscript(keyobj);
            }
            return py_none();
        }
        if n == "copy" {
            nd = PyDict(t="dict", items={});
            for keyobj in d.dict_keys() {
                nd.dict_set(keyobj, d.mp_subscript(keyobj));
            }
            return nd;
        }
        if n == "update" {
            if len(args) >= 1 {
                src = args[0];
                if isinstance(src, PyDict) {
                    sd = src as PyDict;
                    for keyobj in sd.dict_keys() {
                        d.dict_set(keyobj, sd.mp_subscript(keyobj));
                    }
                } elif isinstance(src, PyUserObj)
                    and (src as PyUserObj)._has_base()
                    and isinstance((src as PyUserObj)._base_obj(), PyDict) {
                    sd = (src as PyUserObj)._base_obj() as PyDict;
                    for keyobj in sd.dict_keys() {
                        d.dict_set(keyobj, sd.mp_subscript(keyobj));
                    }
                } else {
                    # An iterable of (key, value) pairs.
                    pairs: list[PyObj] = [];
                    if isinstance(src, PyList) {
                        pairs = (src as PyList).items;
                    } elif isinstance(src, PyTuple) {
                        pairs = (src as PyTuple).items;
                    } else {
                        seq = py_iter(src);
                        if is_error(seq) {
                            return seq;
                        }
                        if isinstance(seq, PyIter) {
                            pairs = (seq as PyIter).items;
                        }
                    }
                    for pair in pairs {
                        if isinstance(pair, PyTuple) {
                            pt = (pair as PyTuple).items;
                            if len(pt) == 2 {
                                d.dict_set(pt[0], pt[1]);
                            }
                        }
                    }
                }
            }
            for k in kwargs {
                d.dict_set(PyStr(t="str", val=k), kwargs[k]);
            }
            return py_none();
        }
        if n == "__contains__" {
            return PyBool(t="bool", val=d.dict_contains(args[0]));
        }
        if n == "__getitem__" {
            return d.mp_subscript(args[0]);
        }
        if n == "__setitem__" {
            return d.mp_ass_subscript(args[0], args[1]);
        }
        if n == "__delitem__" {
            return d.mp_del_subscript(args[0]);
        }
        return py_error("AttributeError", n);
    }
}

# ---- native dict views (.keys()/.values()/.items()) -----------------------
# CPython dict views are lazy, set-like windows on a live dict. Native ones let
# view comparison / set operations invoke element __eq__ (so a raising element
# comparison propagates, unlike the by-hashkey set model) and let view iteration
# carry the dict's mutation guard. keys/items are set-like; values is not.

# Sentinel returned by dict_lookup_value when a key is absent (None is a valid
# stored value, so it can't double as the not-found marker).
obj PyAbsent(PyObj) {}

# Membership test for a key, confirming a hashkey-bucket hit with a real eq when
# either side carries a custom __eq__. Returns PyBool or a PyError (raising eq).
def dict_haskey(d: PyDict, key: PyObj) -> PyObj {
    hk = key.tp_hashkey();
    if hk == "" {
        return py_error("TypeError", "unhashable type");
    }
    if not (hk in d.items) {
        return PyBool(t="bool", val=False);
    }
    stored = d.items[hk].key;
    if _needs_eq_confirm(stored) or _needs_eq_confirm(key) {
        keq = py_compare(2, stored, key);
        if is_error(keq) {
            return keq;
        }
        return PyBool(t="bool", val=py_truth(keq));
    }
    return PyBool(t="bool", val=True);
}

# The stored value for a key, a PyAbsent sentinel if not present, or a PyError.
def dict_lookup_value(d: PyDict, key: PyObj) -> PyObj {
    hk = key.tp_hashkey();
    if hk == "" {
        return py_error("TypeError", "unhashable type");
    }
    if not (hk in d.items) {
        return PyAbsent(t="absent");
    }
    stored = d.items[hk].key;
    if _needs_eq_confirm(stored) or _needs_eq_confirm(key) {
        keq = py_compare(2, stored, key);
        if is_error(keq) {
            return keq;
        }
        if not py_truth(keq) {
            return PyAbsent(t="absent");
        }
    }
    return d.items[hk].value;
}

# The bound method object d.keys / d.values / d.items resolves to; calling it
# builds the view (matching CPython, where `d.keys` is a builtin method and
# `d.keys()` is the view).
obj PyDictViewCtor(PyObj) {
    has d: PyDict,
        mode: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return PyDictView(t="dictview_obj", d=self.d, mode=self.mode);
    }
}

obj PyDictView(PyObj) {
    has d: PyDict,
        mode: str;

    def tp_iter -> PyObj {
        return self.d.dict_iter(self.mode);
    }

    def tp_bool -> bool {
        return len(self.d.items) != 0;
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        return dictview_richcompare(kind, self, other);
    }

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        return dictview_binop(kind, self, other);
    }
}

# The view's elements as PyObjs: keys, values, or (key, value) tuples.
def dictview_elements(view: PyDictView) -> list[PyObj] {
    out: list[PyObj] = [];
    for hk in view.d.items {
        entry = view.d.items[hk];
        if view.mode == "values" {
            out.append(entry.value);
        } elif view.mode == "items" {
            out.append(PyTuple(t="tuple", items=[entry.key, entry.value]));
        } else {
            out.append(entry.key);
        }
    }
    return out;
}

# Element-wise containment that invokes __eq__ where CPython does: a keys/values
# element by comparison, an items (k, v) pair by key lookup + value compare.
def view_contains(view: PyDictView, elem: PyObj) -> PyObj {
    if view.mode == "keys" {
        return dict_haskey(view.d, elem);
    }
    if view.mode == "items" {
        if not isinstance(elem, PyTuple) {
            return PyBool(t="bool", val=False);
        }
        pair = elem as PyTuple;
        if len(pair.items) != 2 {
            return PyBool(t="bool", val=False);
        }
        look = dict_lookup_value(view.d, pair.items[0]);
        if is_error(look) {
            return look;
        }
        if look.t == "absent" {
            return PyBool(t="bool", val=False);
        }
        return py_compare(2, pair.items[1], look);
    }
    # values view: linear scan, comparing each stored value.
    for hk in view.d.items {
        c = py_compare(2, view.d.items[hk].value, elem);
        if is_error(c) {
            return c;
        }
        if py_truth(c) {
            return PyBool(t="bool", val=True);
        }
    }
    return PyBool(t="bool", val=False);
}

# Elements of any set-like operand (view / native set / dict[keys]).
def setlike_elements(o: PyObj) -> list[PyObj] {
    if isinstance(o, PyDictView) {
        return dictview_elements(o as PyDictView);
    }
    if isinstance(o, PySet) {
        return (o as PySet).set_members();
    }
    if isinstance(o, PyDict) {
        return (o as PyDict).dict_keys();
    }
    return [];
}

def setlike_count(o: PyObj) -> int {
    if isinstance(o, PyDictView) {
        return len((o as PyDictView).d.items);
    }
    if isinstance(o, PySet) {
        return len((o as PySet).items);
    }
    if isinstance(o, PyDict) {
        return len((o as PyDict).items);
    }
    return len(setlike_elements(o));
}

# elem in a set-like container, routing to the eq-invoking path per container.
def setlike_contains(container: PyObj, elem: PyObj) -> PyObj {
    if isinstance(container, PyDictView) {
        return view_contains(container as PyDictView, elem);
    }
    if isinstance(container, PySet) {
        return PyBool(t="bool", val=(container as PySet).set_contains(elem));
    }
    if isinstance(container, PyDict) {
        return dict_haskey(container as PyDict, elem);
    }
    return py_contains(container, elem);
}

# True iff every element of x is contained in y (PyBool), or a PyError if an
# element comparison raised. The subset primitive under set-like comparison.
def all_contained(x: PyObj, y: PyObj) -> PyObj {
    for e in setlike_elements(x) {
        c = setlike_contains(y, e);
        if is_error(c) {
            return c;
        }
        if not py_truth(c) {
            return PyBool(t="bool", val=False);
        }
    }
    return PyBool(t="bool", val=True);
}

# CPython dict-view set comparison (==, !=, <, <=, >, >=). Both operands are
# treated as sets; an element __eq__ raised mid-comparison propagates.
def dictview_richcompare(kind: int, a: PyObj, b: PyObj) -> PyObj {
    la = setlike_count(a);
    lb = setlike_count(b);
    if kind == 2 {
        if la != lb {
            return PyBool(t="bool", val=False);
        }
        return all_contained(a, b);
    }
    if kind == 3 {
        if la != lb {
            return PyBool(t="bool", val=True);
        }
        r = all_contained(a, b);
        if is_error(r) {
            return r;
        }
        return PyBool(t="bool", val=not py_truth(r));
    }
    if kind == 1 {
        return all_contained(a, b);
    }
    if kind == 5 {
        return all_contained(b, a);
    }
    if kind == 0 {
        if not (la < lb) {
            return PyBool(t="bool", val=False);
        }
        return all_contained(a, b);
    }
    if kind == 4 {
        if not (la > lb) {
            return PyBool(t="bool", val=False);
        }
        return all_contained(b, a);
    }
    return py_error("TypeError", "unorderable types");
}

# Coerce a set-op operand to a PySet: a view materializes its elements, a set
# passes through, anything else is drained as an iterable (propagating the
# not-iterable TypeError).
def to_set_like(o: PyObj) -> PyObj {
    if isinstance(o, PySet) {
        return o;
    }
    if isinstance(o, PyDictView) {
        return set_from_members(dictview_elements(o as PyDictView), False);
    }
    return coerce_set(o);
}

# Dict-view set algebra (| & - ^) with a view on either side, producing a PySet.
def dictview_binop(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    ls = to_set_like(lhs);
    if is_error(ls) {
        return ls;
    }
    rs = to_set_like(rhs);
    if is_error(rs) {
        return rs;
    }
    return (ls as PySet).nb_binop(kind, rs as PySet);
}

# A frame that ran to RETURN_VALUE. `val` is the generator's return value, which
# `yield from` yields as the sub-expression result and .send()/next() surface as
# StopIteration(val).
obj PyGenStop(PyObj) {
    has val: PyObj;
}

obj PyGenerator(PyObj) {
    has frame: PyFrame,
        started: bool = False,
        finished: bool = False;

    def tp_iter -> PyObj {
        return self;
    }

    # gen.send / gen.throw / gen.close / gen.__next__ resolve to native bound
    # driver methods; every other attribute is a real AttributeError.
    def tp_getattro(name: str) -> PyObj {
        if name == "send" or name == "throw" or name == "close" or name == "__next__" {
            return PyGenMethod(t="gen_method", gen=self, kind=name);
        }
        if name == "gi_frame" {
            return PyGenFrame(t="genframe", gen=self);
        }
        return py_error("AttributeError", name);
    }
}

# A bound generator driver (gen.send/throw/close/__next__). Calling it drives the
# suspended frame and raises StopIteration on exhaustion, matching CPython's
# generator method surface (unlike FOR_ITER, which swallows the StopIteration).
obj PyGenMethod(PyObj) {
    has gen: PyGenerator,
        kind: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if self.kind == "throw" {
            thrown = py_none();
            if len(args) > 0 {
                thrown = args[0];
            }
            return gen_throw(self.gen, thrown);
        }
        if self.kind == "close" {
            return gen_close(self.gen);
        }
        sent = py_none();
        if self.kind == "send" and len(args) > 0 {
            sent = args[0];
        }
        return gen_send(self.gen, sent);
    }
}

# Resume `gen` with `sent` (the value YIELD_VALUE produces on wake; None for
# plain iteration). Returns the yielded PyObj on a yield, a PyGenStop on normal
# return (exhaustion), or a propagating error object on a raise.
def gen_resume(gen: PyGenerator, sent: PyObj) -> PyObj {
    if gen.finished {
        return PyGenStop(t="genstop", val=py_none());
    }
    if gen.started {
        # YIELD_VALUE popped its operand when it suspended; the resume value
        # takes its place on the stack (the trailing POP_TOP discards it in a
        # genexpr; `x = yield` would bind it in a full generator).
        gen.frame.stack.append(sent);
    }
    gen.started = True;
    result = run_frame(gen.frame);
    return finish_gen_result(gen, result);
}

# Common tail for every generator re-entry (resume/send/throw): translate the
# raw run_frame outcome into the yielded value | PyGenStop(return value) | error
# shape that all generator drivers speak.
def finish_gen_result(gen: PyGenerator, result: PyObj) -> PyObj {
    if is_error(result) {
        gen.finished = True;
        return result;
    }
    if result.t == "yield" {
        return (result as PyYield).val;
    }
    gen.finished = True;
    return PyGenStop(t="genstop", val=result);
}

# gen.send(v): resume with v, returning the next yielded value or raising
# StopIteration(return_value) on exhaustion. A just-started generator only
# accepts None (CPython raises TypeError otherwise).
def gen_send(gen: PyGenerator, sent: PyObj) -> PyObj {
    if not gen.started and not gen.finished and sent.t != "none" {
        return py_error(
            "TypeError", "can't send non-None value to a just-started generator"
        );
    }
    result = gen_resume(gen, sent);
    if result.t == "genstop" {
        return stop_iteration((result as PyGenStop).val);
    }
    return result;
}

# StopIteration carrying the generator's return value as its .value payload.
def stop_iteration(value: PyObj) -> PyObj {
    return PyError(
        t="error",
        exception=PyException(
            t="exception", type_name="StopIteration", message="", value=value
        ),
    );
}

# Coerce a thrown operand (exception instance, exception type, or already-raised
# error) into a PyError for injection at the suspend point.
def as_error(value: PyObj) -> PyObj {
    if value.t == "error" {
        return value;
    }
    return py_raise_value(value);
}

# gen.throw(exc): resume the generator as though `exc` were raised at the point
# where it last suspended, so a try/except surrounding the yield can catch it.
def gen_throw(gen: PyGenerator, thrown: PyObj) -> PyObj {
    err = as_error(thrown);
    if err.t != "error" {
        return err;
    }
    if not gen.started or gen.finished {
        # Nothing suspended to resume into: the exception propagates directly.
        gen.finished = True;
        return err;
    }
    frame = gen.frame;
    if frame.yf {
        # Suspended inside `yield from`: delegate the throw into the sub-iterator
        # by re-running the SEND loop in throw mode. SEND's existing yield /
        # exhaustion / error handling then completes or unwinds the yield-from.
        frame.pending_throw = err;
        frame.stack.append(py_none());  # sent-value placeholder SEND reads below
        return finish_gen_result(gen, run_frame(frame));
    }
    # frame.ip sits one instruction past YIELD_VALUE; the handler lookup wants
    # the yield's own offset (YIELD_VALUE has no inline cache, so -2 bytes).
    offset = frame.ip - 2;
    target = recover_exception(frame.co, err, offset, frame.stack);
    if target < 0 {
        gen.finished = True;
        return err;
    }
    frame.ip = target;
    result = run_frame(frame);
    return finish_gen_result(gen, result);
}

# Throw `err` into a yield-from sub-iterator (the SEND-in-throw-mode step).
# Returns the same yielded-value | PyGenStop | error shape as send_into.
def send_throw_into(receiver: PyObj, err: PyObj) -> PyObj {
    if receiver.t == "generator" or receiver.t == "coroutine" {
        return gen_throw(receiver as PyGenerator, err);
    }
    # A non-generator sub-iterator with a .throw() gets it; otherwise the
    # exception simply propagates at the delegation point.
    thrower = py_attr(receiver, "throw");
    if is_error(thrower) {
        return err;
    }
    result = py_invoke(thrower, [(err as PyError).exception], {});
    if is_error(result) {
        exc = (result as PyError).exception;
        if exc.type_name == "StopIteration" {
            payload = py_none();
            if exc.value is not None {
                payload = exc.value as PyObj;
            }
            return PyGenStop(t="genstop", val=payload);
        }
        return result;
    }
    return result;
}

# Release a frame's held references (fast locals, evaluation stack, cell
# contents) and run __del__ finalizers on any user object thereby dropped. This
# models CPython's frame teardown on gen.close()/gi_frame.clear(): a local whose
# last reference lived in the frame is finalized. We approximate "last reference"
# by the common case the generator machinery guarantees -- an argument passed
# straight into the generator call is reachable only through its frame -- since
# jacpython does not carry Python-level refcounts. Idempotent via frame.cleared.
def frame_clear(frame: PyFrame) -> None {
    if frame.cleared {
        return;
    }
    frame.cleared = True;
    held: list[PyObj] = [];
    idx = 0;
    while idx < len(frame.fast) {
        if idx < len(frame.assigned) and frame.assigned[idx] {
            held.append(frame.fast[idx]);
        }
        idx = idx + 1;
    }
    for item in frame.stack {
        held.append(item);
    }
    for cell in frame.cells {
        held.append(cell.val);
    }
    for name in frame.locals {
        held.append(frame.locals[name]);
    }
    frame.fast = [];
    frame.stack = [];
    frame.locals = {};
    for obj in held {
        if isinstance(obj, PyUserObj) and user_has_dunder(obj as PyUserObj, "__del__") {
            _ = call_user_dunder(obj as PyUserObj, "__del__", []);
        }
    }
}

# A generator's gi_frame surface: only .clear() is modeled (the frame-teardown
# entry point CPython exposes), which releases the suspended frame's locals and
# finalizes any user object dropped -- then marks the generator exhausted.
obj PyGenFrame(PyObj) {
    has gen: PyGenerator;

    def tp_getattro(name: str) -> PyObj {
        if name == "clear" {
            return PyGenFrameClear(t="genframe_clear", gen=self.gen);
        }
        return py_error("AttributeError", name);
    }
}

obj PyGenFrameClear(PyObj) {
    has gen: PyGenerator;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        frame_clear(self.gen.frame);
        self.gen.finished = True;
        return py_none();
    }
}

# Native copy.copy / copy.deepcopy. Generators (and coroutines) are uncopyable in
# CPython -- no __copy__/__reduce_ex__ support, so copy raises TypeError -- and a
# native generator can't cross to_host as a live generator anyway (it would drain
# to a list, spuriously succeeding). Every other value delegates to host copy.
obj PyCopyFn(PyObj) {
    has deep: bool;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "copy expected at least 1 argument");
        }
        if isinstance(args[0], PyGenerator) {
            return py_error("TypeError", "cannot pickle 'generator' object");
        }
        mod = host_import("copy", py_none());
        if is_error(mod) {
            return mod;
        }
        fnname = "copy";
        if self.deep {
            fnname = "deepcopy";
        }
        fn = mod.tp_getattro(fnname);
        if is_error(fn) {
            return fn;
        }
        return py_invoke(fn, args, kwargs);
    }
}

# The native `copy` module, seeded into a Layer-1 namespace so a test that does
# copy.copy(gen) sees CPython's TypeError natively (the host proxy would drain).
def build_copy_module() -> PyObj {
    return PyModule(
        t="module",
        name="copy",
        attrs={
            "copy": PyCopyFn(t="copy_fn", deep=False),
            "deepcopy": PyCopyFn(t="copy_fn", deep=True),
        },
    );
}

# gen.close(): throw GeneratorExit in. Swallowing it (StopIteration or letting
# GeneratorExit propagate) is a clean close; yielding again is a RuntimeError.
def gen_close(gen: PyGenerator) -> PyObj {
    if gen.finished or not gen.started {
        gen.finished = True;
        frame_clear(gen.frame);
        return py_none();
    }
    exit = PyException(t="exception", type_name="GeneratorExit", message="");
    result = gen_throw(gen, exit);
    gen.finished = True;
    frame_clear(gen.frame);
    if result.t == "genstop" {
        # The generator caught GeneratorExit and returned; close() surfaces that
        # return value (None if it just fell off the end). (CPython 3.13+.)
        return (result as PyGenStop).val;
    }
    if is_error(result) {
        if (result as PyError).exception.type_name == "GeneratorExit" {
            return py_none();
        }
        return result;
    }
    return py_error("RuntimeError", "generator ignored GeneratorExit");
}

# Drive one step of a yield-from sub-iterator (SEND). Returns the yielded value,
# a PyGenStop(return value) on exhaustion, or a propagating error.
def send_into(receiver: PyObj, sent: PyObj) -> PyObj {
    # A native coroutine drives through the identical suspend/resume machinery as
    # a generator -- `await` lowers to the same SEND loop `yield from` uses.
    if receiver.t == "generator" or receiver.t == "coroutine" {
        return gen_resume(receiver as PyGenerator, sent);
    }
    if receiver.t == "iter" {
        it = receiver as PyIter;
        if sent.t != "none" {
            return py_error("AttributeError", "send");
        }
        if it.index < len(it.items) {
            item = it.items[it.index];
            it.index = it.index + 1;
            return item;
        }
        return PyGenStop(t="genstop", val=py_none());
    }
    if receiver.t == "dictiter" {
        di = receiver as PyDictIter;
        if sent.t != "none" {
            return py_error("AttributeError", "send");
        }
        if di.dictiter_stale() {
            return dictiter_error();
        }
        if di.index < len(di.keys) {
            item = dictiter_yield(di);
            di.index = di.index + 1;
            return item;
        }
        return PyGenStop(t="genstop", val=py_none());
    }
    # Any other iterator: drive it through its own send/__next__ surface.
    method_name = "send";
    if sent.t == "none" {
        method_name = "__next__";
    }
    driver = py_attr(receiver, method_name);
    if is_error(driver) {
        return driver;
    }
    call_args: list[PyObj] = [];
    if method_name == "send" {
        call_args.append(sent);
    }
    result = py_invoke(driver, call_args, {});
    if is_error(result) {
        exc = (result as PyError).exception;
        if exc.type_name == "StopIteration" {
            payload = py_none();
            if exc.value is not None {
                payload = exc.value as PyObj;
            }
            return PyGenStop(t="genstop", val=payload);
        }
        return result;
    }
    return result;
}

# Drain a generator to exhaustion through the real suspend/resume machinery and
# return the yielded PyObjs as a list. Used at the host boundary (to_host) so
# list()/tuple()/sum()/... consume a native genexpr without an eager-eval shim.
def gen_drain(gen: PyGenerator) -> PyObj {
    items: list[PyObj] = [];
    while True {
        nxt = gen_resume(gen, py_none());
        if nxt.t == "genstop" {
            return PyList(t="list", items=items);
        }
        if is_error(nxt) {
            return nxt;
        }
        items.append(nxt);
    }
    return PyList(t="list", items=items);
}

def exec_code_frame(
    co: PyCode,
    args: list[PyObj],
    kwargs: dict[str, PyObj],
    globals: dict[str, PyObj],
    locals: dict[str, PyObj],
    closure: list[PyCell],
    defaults: list[PyObj],
    kwdefaults: dict[str, PyObj],
) -> PyObj {
    fast: list[PyObj] = [];
    assigned: list[bool] = [];
    i = 0;
    while i < len(co.varnames) {
        fast.append(py_none());
        assigned.append(False);
        i = i + 1;
    }
    positional_count = co.argcount;
    has_varargs = (co.flags & 4) != 0;
    has_varkw = (co.flags & 8) != 0;
    # Named-parameter slots occupy [0 .. argcount + kwonlyargcount); the *args and
    # **kwargs slots (when present) follow, in that order (CPython's localsplus
    # layout). Keywords that don't name a parameter belong in **kwargs.
    param_slots = positional_count + co.kwonlyargcount;
    i = 0;
    while i < len(args) and i < positional_count {
        fast[i] = args[i];
        assigned[i] = True;
        i = i + 1;
    }
    if has_varargs {
        # Surplus positionals gather into the *args tuple slot.
        extra: list[PyObj] = [];
        j = positional_count;
        while j < len(args) {
            extra.append(args[j]);
            j = j + 1;
        }
        fast[param_slots] = PyTuple(t="tuple", items=extra);
        assigned[param_slots] = True;
    } elif len(args) > positional_count {
        return py_error("TypeError", "too many positional arguments");
    }
    varkw_slot = -1;
    if has_varkw {
        varkw_slot = param_slots;
        if has_varargs {
            varkw_slot = varkw_slot + 1;
        }
        fast[varkw_slot] = PyDict(t="dict", items={});
        assigned[varkw_slot] = True;
    }
    for key in kwargs {
        index = find_name(co.varnames, key);
        # A keyword binds a named parameter only if it lands in the parameter
        # region and isn't positional-only; otherwise it flows into **kwargs (or
        # is an error when the function has none).
        is_param = index >= 0 and index < param_slots and index >= co.posonlyargcount;
        if is_param and assigned[index] {
            return py_error("TypeError", "multiple values for argument " + key);
        }
        if is_param {
            fast[index] = kwargs[key];
            assigned[index] = True;
        } elif has_varkw {
            (fast[varkw_slot] as PyDict).dict_set(
                PyStr(t="str", val=key), kwargs[key]
            );
        } elif index >= 0 and index < co.posonlyargcount {
            return py_error("TypeError", "positional-only argument passed by name");
        } else {
            return py_error("TypeError", "unexpected keyword argument " + key);
        }
    }
    i = 0;
    while i < positional_count {
        if not assigned[i] {
            default_index = i - (positional_count - len(defaults));
            if default_index >= 0 and default_index < len(defaults) {
                fast[i] = defaults[default_index];
                assigned[i] = True;
            }
        }
        if not assigned[i] {
            return py_error("TypeError", "missing required argument");
        }
        i = i + 1;
    }
    i = 0;
    while i < co.kwonlyargcount {
        index = positional_count + i;
        if not assigned[index] {
            key = co.varnames[index];
            if key in kwdefaults {
                fast[index] = kwdefaults[key];
                assigned[index] = True;
            }
        }
        if not assigned[index] {
            return py_error("TypeError", "missing required keyword argument");
        }
        i = i + 1;
    }

    cells: list[PyCell] = [];
    for name in co.cellvars {
        fast_index = find_name(co.varnames, name);
        value = py_none();
        if fast_index >= 0 {
            value = fast[fast_index];
        }
        cells.append(PyCell(t="cell", val=value));
    }
    frame = PyFrame(
        t="frame",
        co=co,
        fast=fast,
        assigned=assigned,
        cells=cells,
        closure=closure,
        stack=[],
        globals=globals,
        locals=locals,
        ip=0,
    );
    # A generator-flagged code object does not run on call: it returns a
    # generator wrapping the (unstarted) frame; execution begins on first resume.
    # CO_COROUTINE (0x80) is the async-def analogue -- the same suspendable frame,
    # tagged "coroutine" so type(coro).__name__ and the await/SEND driver treat it
    # as an awaitable (not a for-iterable) while reusing gen_resume/send_into.
    if (co.flags & 128) != 0 {
        return PyGenerator(t="coroutine", frame=frame, started=False, finished=False);
    }
    if (co.flags & 32) != 0 {
        return PyGenerator(t="generator", frame=frame, started=False, finished=False);
    }
    return run_frame(frame);
}

def run_frame(frame: PyFrame) -> PyObj {
    co = frame.co;
    fast = frame.fast;
    assigned = frame.assigned;
    cells = frame.cells;
    closure = frame.closure;
    stack = frame.stack;
    globals = frame.globals;
    locals = frame.locals;
    code = co.co_code;
    ip = frame.ip;
    ext_arg = 0;
    # The stack of exceptions currently being handled (one entry per active except
    # block). A bare `raise` re-raises the top; PUSH_EXC_INFO pushes on handler
    # entry, POP_EXCEPT pops on handler exit. Frame-local: a bare raise across a
    # generator yield boundary is not modeled (vanishingly rare).
    exc_handling: list[PyObj] = [];
    while ip < len(code) {
        offset = ip;
        op = code[ip];
        arg = code[ip + 1];
        ip = ip + 2 + 2 * opcode_cache_count(op);
        # EXTENDED_ARG carries the high bits of the FOLLOWING instruction's oparg
        # (up to four may chain). Fold any accumulated prefix into this arg, then
        # either stash it (this op IS the prefix) or clear it for the real op.
        arg = arg | (ext_arg << 8);
        ext_arg = 0;
        if op == OP_EXTENDED_ARG {
            ext_arg = arg;
            continue;
        }
        if op == OP_CACHE or op == OP_NOT_TAKEN or op == OP_NOP or op == OP_RESUME {
            continue;
        }
        if op == OP_LOAD_CONST {
            stack.append(co.consts[arg]);
            continue;
        }
        if op == OP_LOAD_SMALL_INT {
            # oparg is an unsigned int in [0, 256); it is ALWAYS non-negative
            # (CPython emits LOAD_CONST for negative literals). Do NOT sign-extend
            # -- doing so mis-decoded 128..255 as negatives.
            stack.append(PyInt(t="int", val=arg));
            continue;
        }
        if op == OP_LOAD_FAST or op == OP_LOAD_FAST_BORROW {
            fast_result = fast_value(co, arg, fast, cells, closure);
            if is_error(fast_result) {
                return fast_result;
            }
            stack.append(fast_result);
            continue;
        }
        if op == OP_STORE_FAST {
            if arg < len(fast) {
                fast[arg] = stack.pop();
                assigned[arg] = True;
                continue;
            }
            return py_error("UnboundLocalError", "invalid local variable");
        }
        if op == OP_DELETE_FAST {
            # `del local`: unbind the fast slot. A later LOAD_FAST raises
            # UnboundLocalError (the assigned flag gates that).
            if arg < len(fast) {
                fast[arg] = py_none();
                assigned[arg] = False;
                continue;
            }
            return py_error("UnboundLocalError", "invalid local variable");
        }
        if op == OP_LOAD_FAST_AND_CLEAR {
            # Inlined comprehensions save the loop var's outer binding here and
            # clear the slot; a STORE_FAST at the tail restores it. NULL (an
            # unbound slot) is modeled with the None placeholder.
            if arg < len(fast) and assigned[arg] {
                stack.append(fast[arg]);
            } else {
                stack.append(py_none());
            }
            if arg < len(fast) {
                fast[arg] = py_none();
                assigned[arg] = False;
            }
            continue;
        }
        if op == OP_STORE_FAST_LOAD_FAST {
            store_index = arg // 16;
            load_index = arg % 16;
            if store_index >= len(fast) {
                return py_error("UnboundLocalError", "invalid local variable");
            }
            fast[store_index] = stack.pop();
            assigned[store_index] = True;
            load_result = fast_value(co, load_index, fast, cells, closure);
            if is_error(load_result) {
                return load_result;
            }
            stack.append(load_result);
            continue;
        }
        if op == OP_STORE_FAST_STORE_FAST {
            # Packed two-register store: TOS -> reg(arg>>4), TOS1 -> reg(arg&15).
            first_index = arg // 16;
            second_index = arg % 16;
            if first_index >= len(fast) or second_index >= len(fast) {
                return py_error("UnboundLocalError", "invalid local variable");
            }
            fast[first_index] = stack.pop();
            assigned[first_index] = True;
            fast[second_index] = stack.pop();
            assigned[second_index] = True;
            continue;
        }
        if op == OP_LOAD_FAST_BORROW_2 or op == OP_LOAD_FAST_LOAD_FAST {
            first = arg // 16;
            second = arg % 16;
            first_result = fast_value(co, first, fast, cells, closure);
            second_result = fast_value(co, second, fast, cells, closure);
            if is_error(first_result) {
                return first_result;
            }
            if is_error(second_result) {
                return second_result;
            }
            stack.append(first_result);
            stack.append(second_result);
            continue;
        }
        if op == OP_LOAD_GLOBAL {
            name_index = arg // 2;
            if name_index >= len(co.names) {
                return py_error("NameError", "invalid global name");
            }
            name = co.names[name_index];
            value = py_none();
            if name in globals {
                value = globals[name];
            } else {
                value = host_builtin(name);
            }
            if is_error(value) {
                target = recover_exception(co, value, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return value;
            }
            stack.append(value);
            if (arg & 1) != 0 {
                stack.append(py_none());
            }
            continue;
        }
        if op == OP_LOAD_NAME {
            name = co.names[arg];
            value = py_none();
            if name in locals {
                value = locals[name];
            } elif name in globals {
                value = globals[name];
            } else {
                value = host_builtin(name);
            }
            if is_error(value) {
                target = recover_exception(co, value, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return value;
            }
            stack.append(value);
            continue;
        }
        if op == OP_LOAD_DEREF {
            cell = deref_cell(co, arg, fast, cells, closure);
            if cell is None {
                return py_error("NameError", "free variable is not set");
            }
            stack.append(cell.val);
            continue;
        }
        if op == OP_LOAD_CLOSURE {
            cell = deref_cell(co, arg, fast, cells, closure);
            if cell is None {
                return py_error("NameError", "free variable is not set");
            }
            stack.append(cell);
            continue;
        }
        if op == OP_STORE_DEREF {
            value = stack.pop();
            cell = deref_cell(co, arg, fast, cells, closure);
            if cell is None {
                return py_error("NameError", "free variable is not set");
            }
            cell.val = value;
            continue;
        }
        if op == OP_MAKE_CELL {
            continue;
        }
        if op == OP_COPY_FREE_VARS {
            continue;
        }
        if op == OP_LOAD_LOCALS {
            stack.append(pydict_from_str_map(locals));
            continue;
        }
        if op == OP_STORE_NAME {
            locals[co.names[arg]] = stack.pop();
            continue;
        }
        if op == OP_STORE_GLOBAL {
            # `global x; x = ...` inside a function -- write straight to the
            # module globals, bypassing the frame's fast/locals.
            globals[co.names[arg]] = stack.pop();
            continue;
        }
        if op == OP_DELETE_GLOBAL {
            gdel_name = co.names[arg];
            if gdel_name in globals {
                del globals[gdel_name];
                continue;
            }
            gdeleted = py_error(
                "NameError", "name '" + gdel_name + "' is not defined"
            );
            target = recover_exception(co, gdeleted, offset, stack);
            if target >= 0 {
                ip = target;
                continue;
            }
            return gdeleted;
        }
        if op == OP_DELETE_NAME {
            del_name = co.names[arg];
            if del_name in locals {
                del locals[del_name];
                continue;
            }
            deleted = py_error("NameError", "name '" + del_name + "' is not defined");
            target = recover_exception(co, deleted, offset, stack);
            if target >= 0 {
                ip = target;
                continue;
            }
            return deleted;
        }
        if op == OP_LOAD_BUILD_CLASS {
            stack.append(PyBuildClass(t="build_class"));
            continue;
        }
        if op == OP_MAKE_FUNCTION {
            function = make_function_from_stack(stack, globals);
            if is_error(function) {
                return function;
            }
            stack.append(function);
            continue;
        }
        if op == OP_SET_FUNCTION_ATTRIBUTE {
            function = stack.pop() as PyFunction;
            attribute = stack.pop();
            if arg == 1 and attribute.t == "tuple" {
                function.defaults = tuple_value(attribute);
            } elif arg == 2 and attribute.t == "dict" {
                function.kwdefaults = (attribute as PyDict).dict_str_map();
            } elif arg == 8 and attribute.t == "tuple" {
                function.closure = [];
                closure_index = 0;
                for item in tuple_value(attribute) {
                    if item.t == "cell" {
                        function.closure.append(item as PyCell);
                    } elif closure_index < len(function.code.freevars) {
                        outer_cell = find_cell(
                            cells, co.cellvars, function.code.freevars[closure_index]
                        );
                        if outer_cell is not None {
                            function.closure.append(outer_cell);
                        } else {
                            function.closure.append(PyCell(t="cell", val=item));
                        }
                    } else {
                        function.closure.append(PyCell(t="cell", val=item));
                    }
                    closure_index = closure_index + 1;
                }
            }
            stack.append(function);
            continue;
        }
        if op == OP_BUILD_LIST {
            values: list[PyObj] = [];
            while len(values) < arg {
                values.insert(0, stack.pop());
            }
            stack.append(PyList(t="list", items=values));
            continue;
        }
        if op == OP_BUILD_TUPLE {
            values: list[PyObj] = [];
            while len(values) < arg {
                values.insert(0, stack.pop());
            }
            stack.append(PyTuple(t="tuple", items=values));
            continue;
        }
        if op == OP_BUILD_MAP {
            # key0,val0,key1,val1,... are pushed in source order; popping walks
            # them backwards, so buffer and replay forward to preserve insertion
            # order (dict iteration / .values() / .items() are order-sensitive).
            popped: list[PyObj] = [];
            j = 0;
            while j < arg * 2 {
                popped.insert(0, stack.pop());
                j = j + 1;
            }
            # Any hashable key lands in the native PyDict (hash-key protocol).
            # An unhashable key would raise TypeError in real Python; keep the
            # literal opaque on the host rather than raising during bootstrap.
            any_unhashable = False;
            j = 0;
            while j < arg {
                if popped[j * 2].tp_hashkey() == "" {
                    any_unhashable = True;
                }
                j = j + 1;
            }
            if any_unhashable {
                host_map: dict[any, any] = {};
                j = 0;
                while j < arg {
                    host_map[to_host(popped[j * 2])] = to_host(popped[j * 2 + 1]);
                    j = j + 1;
                }
                stack.append(PyHostProxy(t="host", val=host_map));
                continue;
            }
            native_map = PyDict(t="dict", items={});
            j = 0;
            while j < arg {
                native_map.dict_set(popped[j * 2], popped[j * 2 + 1]);
                j = j + 1;
            }
            stack.append(native_map);
            continue;
        }
        if op == OP_BUILD_SET {
            # Native PySet via the hash-key protocol; set algebra (|, &, -, ^) and
            # membership then run natively (PySet.nb_binop / set_contains).
            members: list[PyObj] = [];
            while len(members) < arg {
                members.insert(0, stack.pop());
            }
            native_set = PySet(t="set", items={}, frozen=False);
            set_err: PyObj = py_none();
            had_set_err = False;
            for member in members {
                set_err = native_set.set_add(member);
                if is_error(set_err) {
                    had_set_err = True;
                    break;
                }
            }
            if had_set_err {
                target = recover_exception(co, set_err, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return set_err;
            }
            stack.append(native_set);
            continue;
        }
        if op == OP_SET_UPDATE {
            iterable = stack.pop();
            target_index = len(stack) - arg;
            target_set: PySet = stack[target_index] as PySet;
            for hostel in to_host(iterable) {
                target_set.set_add(from_host(hostel));
            }
            continue;
        }
        if op == OP_CONVERT_VALUE {
            value = stack.pop();
            result = host_convert(value, arg);
            if is_error(result) {
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_FORMAT_SIMPLE {
            value = stack.pop();
            result = host_format(value, "");
            if is_error(result) {
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_FORMAT_WITH_SPEC {
            spec = stack.pop();
            value = stack.pop();
            result = host_format(value, expect_str(spec));
            if is_error(result) {
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_BUILD_STRING {
            parts: list[PyObj] = [];
            while len(parts) < arg {
                parts.insert(0, stack.pop());
            }
            joined = "";
            for part in parts {
                joined = joined + expect_str(part);
            }
            stack.append(PyStr(t="str", val=joined));
            continue;
        }
        if op == OP_LIST_EXTEND {
            # After popping the iterable, the target list sits at STACK[-arg]
            # (CPython extends STACK[-arg-1] pre-pop). The prior `-1-arg` form
            # only worked for a bare list literal, where a negative index still
            # landed on the list; with a callable+NULL below (e.g. len([...]))
            # it addressed the NULL instead.
            iterable = stack.pop();
            target_index = len(stack) - arg;
            append_to_list(stack[target_index], iterable);
            continue;
        }
        if op == OP_LIST_APPEND {
            value = stack.pop();
            target_index = len(stack) - arg;
            (stack[target_index] as PyList).items.append(value);
            continue;
        }
        if op == OP_SET_ADD {
            # set comprehension step: value=TOS, target set at STACK[-arg].
            set_member: PyObj = stack.pop();
            target_index = len(stack) - arg;
            (stack[target_index] as PySet).set_add(set_member);
            continue;
        }
        if op == OP_MAP_ADD {
            # dict comprehension step: value=TOS, key=TOS1, target dict at
            # STACK[-arg] after the two pops (mirrors LIST_APPEND's addressing).
            map_value: PyObj = stack.pop();
            map_key: PyObj = stack.pop();
            target_index = len(stack) - arg;
            (stack[target_index] as PyDict).dict_set(map_key, map_value);
            continue;
        }
        if op == OP_DICT_UPDATE {
            # {**a, **b}: merge source (TOS) into the dict at STACK[-arg-1];
            # duplicate keys are overwritten (last wins), no error.
            update_source: PyObj = stack.pop();
            target_index = len(stack) - arg;
            update_target = stack[target_index] as PyDict;
            update_pairs = dict_merge_pairs(update_source);
            ukeys = update_pairs.dict_keys();
            uvals = update_pairs.dict_values();
            uj = 0;
            while uj < len(ukeys) {
                update_target.dict_set(ukeys[uj], uvals[uj]);
                uj = uj + 1;
            }
            continue;
        }
        if op == OP_DICT_MERGE {
            # f(**kw): merge source (TOS) into the kwargs dict at STACK[-arg-1].
            # Unlike DICT_UPDATE, a duplicate key is a TypeError (a keyword passed
            # more than once). Keyword keys are always strings.
            merge_source: PyObj = stack.pop();
            # Stack effect (CPython): (callable, unused, unused, dict,
            # unused[oparg-1], update). After popping `update`, the target dict
            # sits `oparg` slots below the top.
            target_index = len(stack) - arg;
            merge_target = stack[target_index] as PyDict;
            merge_pairs = dict_merge_pairs(merge_source);
            mkeys = merge_pairs.dict_keys();
            mvals = merge_pairs.dict_values();
            dup_key = "";
            has_dup = False;
            mj = 0;
            while mj < len(mkeys) {
                if merge_target.dict_contains(mkeys[mj]) {
                    dup_key = expect_str(mkeys[mj]);
                    has_dup = True;
                } else {
                    merge_target.dict_set(mkeys[mj], mvals[mj]);
                }
                mj = mj + 1;
            }
            if has_dup {
                merge_err = py_error(
                    "TypeError",
                    "got multiple values for keyword argument '" + dup_key + "'",
                );
                target = recover_exception(co, merge_err, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return merge_err;
            }
            continue;
        }
        if op == OP_UNPACK_SEQUENCE {
            seq = stack.pop();
            it = py_iter(seq);
            if is_error(it) {
                target = recover_exception(co, it, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return it;
            }
            unpacked: list[PyObj] = [];
            if isinstance(it, PyIter) {
                unpacked = (it as PyIter).items;
            } elif it.t == "generator" {
                while True {
                    nxt = gen_resume(it as PyGenerator, py_none());
                    if is_error(nxt) {
                        return nxt;
                    }
                    if nxt.t == "genstop" {
                        break;
                    }
                    unpacked.append(nxt);
                }
            }
            unpack_err: PyObj = py_none();
            if len(unpacked) < arg {
                unpack_err = py_error(
                    "ValueError",
                    "not enough values to unpack (expected "
                    + str(arg)
                    + ", got "
                    + str(len(unpacked))
                    + ")",
                );
            } elif len(unpacked) > arg {
                unpack_err = py_error(
                    "ValueError",
                    "too many values to unpack (expected " + str(arg) + ")",
                );
            }
            if is_error(unpack_err) {
                target = recover_exception(co, unpack_err, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return unpack_err;
            }
            # Push in reverse so the first element lands on top of the stack for
            # the successive STORE ops (CPython's UNPACK_SEQUENCE ordering).
            k = arg - 1;
            while k >= 0 {
                stack.append(unpacked[k]);
                k = k - 1;
            }
            continue;
        }
        if op == OP_GET_ITER {
            iterable = py_iter(stack.pop());
            if is_error(iterable) {
                target = recover_exception(co, iterable, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return iterable;
            }
            stack.append(iterable);
            continue;
        }
        if op == OP_GET_YIELD_FROM_ITER {
            # `yield from`: a generator (or coroutine) is already its own
            # iterator and is left in place so send()/throw() reach it directly;
            # anything else is turned into an iterator like GET_ITER.
            top = stack[len(stack) - 1];
            if top.t == "generator" {
                continue;
            }
            iterable = py_iter(stack.pop());
            if is_error(iterable) {
                target = recover_exception(co, iterable, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return iterable;
            }
            stack.append(iterable);
            continue;
        }
        if op == OP_GET_AWAITABLE {
            # `await x`: resolve x to the iterator the following SEND loop drives.
            # A native coroutine is its own awaitable (coroutine.__await__ returns
            # self), so it is left in place -- identical to a generator under
            # GET_YIELD_FROM_ITER. Anything else needs a real __await__ we don't
            # port yet.
            top = stack[len(stack) - 1];
            if top.t == "coroutine" or top.t == "generator" {
                continue;
            }
            awaitable = py_error(
                "TypeError", "object can't be used in 'await' expression"
            );
            target = recover_exception(co, awaitable, offset, stack);
            if target >= 0 {
                ip = target;
                continue;
            }
            return awaitable;
        }
        if op == OP_SEND {
            # yield-from step. Stack: [..., receiver, sent]. Drive the receiver
            # one step; on a yield replace `sent` with the yielded value and fall
            # through to YIELD_VALUE (re-suspending the outer generator); on
            # exhaustion replace `sent` with the sub-iterator's return value and
            # jump past the loop to END_SEND.
            sent = stack[len(stack) - 1];
            receiver = stack[len(stack) - 2];
            if frame.pending_throw is not None {
                thrown_err = frame.pending_throw as PyObj;
                frame.pending_throw = None;
                step = send_throw_into(receiver, thrown_err);
            } else {
                step = send_into(receiver, sent);
            }
            if is_error(step) {
                target = recover_exception(co, step, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return step;
            }
            if step.t == "genstop" {
                stack[len(stack) - 1] = (step as PyGenStop).val;
                ip = ip + 2 * arg;
            } else {
                stack[len(stack) - 1] = step;
            }
            continue;
        }
        if op == OP_END_SEND {
            # (receiver, value -- value): drop the exhausted sub-iterator, keep
            # its return value as the yield-from expression result.
            value = stack.pop();
            stack.pop();
            stack.append(value);
            continue;
        }
        if op == OP_CLEANUP_THROW {
            # Reached when an exception thrown into a yield-from lands here. Stack:
            # [sub_iter, last_sent, exc]. A StopIteration means the sub-iterator
            # finished handling the throw: unwind to (None, value) and loop to
            # END_SEND. Any other exception re-raises out of the outer generator.
            exc = stack.pop();
            stack.pop();
            stack.pop();
            exc_name = "";
            if exc.t == "exception" {
                exc_name = (exc as PyException).type_name;
            }
            if exc_name == "StopIteration" {
                payload = py_none();
                if (exc as PyException).value is not None {
                    payload = (exc as PyException).value as PyObj;
                }
                stack.append(py_none());
                stack.append(payload);
                continue;
            }
            reraised = py_raise_value(exc);
            target = recover_exception(co, reraised, offset, stack);
            if target >= 0 {
                ip = target;
                continue;
            }
            return reraised;
        }
        if op == OP_FOR_ITER {
            top = stack[len(stack) - 1];
            if top.t == "dictiter" {
                di = top as PyDictIter;
                if di.dictiter_stale() {
                    nxt = dictiter_error();
                    target = recover_exception(co, nxt, offset, stack);
                    if target >= 0 {
                        ip = target;
                    } else {
                        return nxt;
                    }
                } elif di.index < len(di.keys) {
                    stack.append(dictiter_yield(di));
                    di.index = di.index + 1;
                } else {
                    stack.pop();
                    ip = ip + 2 * arg;
                }
                continue;
            }
            if top.t == "generator" {
                nxt = gen_resume(top as PyGenerator, py_none());
                if nxt.t == "genstop" {
                    stack.pop();
                    ip = ip + 2 * arg;
                } elif is_error(nxt) {
                    target = recover_exception(co, nxt, offset, stack);
                    if target >= 0 {
                        ip = target;
                    } else {
                        return nxt;
                    }
                } else {
                    stack.append(nxt);
                }
                continue;
            }
            iterator = top as PyIter;
            if iterator.index < len(iterator.items) {
                stack.append(iterator.items[iterator.index]);
                iterator.index = iterator.index + 1;
            } else {
                stack.pop();
                ip = ip + 2 * arg;
            }
            continue;
        }
        if op == OP_END_FOR or op == OP_POP_ITER {
            continue;
        }
        if op == OP_JUMP_FORWARD {
            ip = ip + 2 * arg;
            continue;
        }
        if op == OP_JUMP_BACKWARD or op == OP_JUMP_BACKWARD_NO_INTERRUPT {
            ip = ip - 2 * arg;
            continue;
        }
        if op == OP_POP_JUMP_IF_FALSE
        or op == OP_POP_JUMP_IF_TRUE
        or op == OP_POP_JUMP_IF_NONE
        or op == OP_POP_JUMP_IF_NOT_NONE {
            condition = stack.pop();
            jump = False;
            if op == OP_POP_JUMP_IF_FALSE {
                jump = not py_truth(condition);
            } elif op == OP_POP_JUMP_IF_TRUE {
                jump = py_truth(condition);
            } elif op == OP_POP_JUMP_IF_NONE {
                jump = condition.t == "none";
            } else {
                jump = condition.t != "none";
            }
            if jump {
                ip = ip + 2 * arg;
            }
            continue;
        }
        if op == OP_COMPARE_OP {
            rhs = stack.pop();
            lhs = stack.pop();
            result = py_compare(arg >> 5, lhs, rhs);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_IS_OP {
            rhs = stack.pop();
            lhs = stack.pop();
            same = py_identity(lhs, rhs);
            if arg == 1 {
                same = not same;
            }
            stack.append(PyBool(t="bool", val=same));
            continue;
        }
        if op == OP_UNARY_NOT {
            stack.append(PyBool(t="bool", val=not py_truth(stack.pop())));
            continue;
        }
        if op == OP_UNARY_NEGATIVE {
            result = py_negative(stack.pop());
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_UNARY_INVERT {
            result = py_invert(stack.pop());
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_BINARY_OP {
            rhs = stack.pop();
            lhs = stack.pop();
            result = py_subscript(lhs, rhs) if arg == 26 else py_binop(arg, lhs, rhs);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_BINARY_SLICE {
            # container[start:stop] -- step is always None for this opcode.
            stop = stack.pop();
            start = stack.pop();
            container = stack.pop();
            result = py_subscript(
                container, PySlice(t="slice", start=start, stop=stop, step=py_none())
            );
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_BUILD_SLICE {
            # oparg is 2 (start:stop) or 3 (start:stop:step); operands on stack.
            slice_step: PyObj = py_none();
            if arg == 3 {
                slice_step = stack.pop();
            }
            slice_stop = stack.pop();
            slice_start = stack.pop();
            stack.append(
                PySlice(t="slice", start=slice_start, stop=slice_stop, step=slice_step)
            );
            continue;
        }
        if op == OP_LOAD_ATTR {
            owner = stack.pop();
            name = co.names[arg // 2];
            result = py_attr(owner, name);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            if (arg & 1) != 0 {
                stack.append(result);
                stack.append(py_none());
            } else {
                stack.append(result);
            }
            continue;
        }
        if op == OP_LOAD_SUPER_ATTR {
            # Stack (top-down): self, class(__class__ cell), global super. arg
            # encodes name>>2, bit0 = method-call form, bit1 = two-arg super.
            super_self = stack.pop();
            super_class = stack.pop();
            super_global = stack.pop();
            super_name = co.names[arg >> 2];
            result = super_lookup(super_class, super_self, super_name);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            bound = bind_attribute(result, super_self);
            if (arg & 1) != 0 {
                stack.append(bound);
                stack.append(py_none());
            } else {
                stack.append(bound);
            }
            continue;
        }
        if op == OP_STORE_ATTR {
            owner = stack.pop();
            field = stack.pop();
            result = py_set_attr(owner, co.names[arg], field);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            continue;
        }
        if op == OP_DELETE_ATTR {
            owner = stack.pop();
            result = py_del_attr(owner, co.names[arg]);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            continue;
        }
        if op == OP_STORE_SUBSCR {
            stored_index: PyObj = stack.pop();
            owner = stack.pop();
            stored_value: PyObj = stack.pop();
            result = py_store_subscript(owner, stored_index, stored_value);
            if is_error(result) {
                return result;
            }
            continue;
        }
        if op == OP_DELETE_SUBSCR {
            deleted_index: PyObj = stack.pop();
            owner = stack.pop();
            result = py_delete_subscript(owner, deleted_index);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            continue;
        }
        if op == OP_IMPORT_NAME {
            fromlist = stack.pop();
            level_obj = stack.pop();
            result: PyObj = py_none();
            if layer3_is_active() {
                import_level = 0;
                if isinstance(level_obj, PyInt) {
                    import_level = (level_obj as PyInt).val;
                }
                result = py_import_name(
                    co.names[arg], fromlist, import_level, globals
                );
            } else {
                result = host_import(co.names[arg], fromlist);
            }
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_IMPORT_FROM {
            module = stack[len(stack) - 1];
            result = py_attr(module, co.names[arg]);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_PUSH_NULL {
            stack.append(py_none());
            continue;
        }
        if op == OP_CALL or op == OP_CALL_KW {
            keyword_names: list[str] = [];
            call_count = arg;
            if op == OP_CALL_KW {
                names_obj = stack.pop();
                keyword_names = str_values(names_obj);
            }
            call_args: list[PyObj] = [];
            while len(call_args) < call_count {
                call_args.insert(0, stack.pop());
            }
            kwargs_for_call: dict[str, PyObj] = {};
            positional_count_for_call = call_count - len(keyword_names);
            while len(keyword_names) > 0 {
                key = keyword_names.pop();
                kwargs_for_call[key] = call_args.pop();
            }
            if len(stack) == 0 {
                return py_error("RuntimeError", "CALL stack underflow");
            }
            self_or_null = stack.pop();
            if len(stack) == 0 {
                return py_error("RuntimeError", "CALL stack underflow");
            }
            fn = stack.pop();
            # globals() binds to THIS frame's namespace (a live view), which only
            # the ceval holds -- resolve it here rather than in PyNativeBuiltin.
            if fn.t == "native_builtin"
                and (fn as PyNativeBuiltin).name == "globals" {
                stack.append(PyGlobalsProxy(t="globals", ns=globals));
                continue;
            }
            # CPython's CALL convention carries a `self_or_null` slot below the
            # args. NULL (a plain call after PUSH_NULL, modeled here as None) is
            # dropped; a real value (a bound self, or a genexpr's `.0` iterator
            # under `CALL 0`) is prepended as the first positional argument.
            if self_or_null.t != "none" {
                call_args.insert(0, self_or_null);
            }
            result = py_invoke(fn, call_args, kwargs_for_call);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_CALL_FUNCTION_EX {
            # f(*args, **kwargs). Stack (bottom->top): func, self_or_null,
            # callargs (a materialized iterable), kwargs (a mapping or NULL). The
            # oparg is unused in 3.14: a NULL kwargs slot (PUSH_NULL) means no
            # keywords.
            kwargs_obj = stack.pop();
            callargs_obj = stack.pop();
            self_or_null_ex = stack.pop();
            fn_ex = stack.pop();
            ex_args_list = members_of(callargs_obj);
            if is_error(ex_args_list) {
                return ex_args_list;
            }
            ex_call_args: list[PyObj] = (ex_args_list as PyList).items;
            if self_or_null_ex.t != "none" {
                ex_call_args.insert(0, self_or_null_ex);
            }
            ex_kwargs: dict[str, PyObj] = {};
            if isinstance(kwargs_obj, PyDict) {
                ex_kwargs = (kwargs_obj as PyDict).dict_str_map();
            } elif kwargs_obj.t != "none" {
                # A non-dict, non-NULL mapping (e.g. a proxied host mapping):
                # normalize through from_host(to_host(...)) into a PyDict.
                coerced = from_host(to_host(kwargs_obj));
                if isinstance(coerced, PyDict) {
                    ex_kwargs = (coerced as PyDict).dict_str_map();
                }
            }
            ex_result = py_invoke(fn_ex, ex_call_args, ex_kwargs);
            if is_error(ex_result) {
                target = recover_exception(co, ex_result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return ex_result;
            }
            stack.append(ex_result);
            continue;
        }
        if op == OP_PUSH_EXC_INFO {
            if len(stack) > 0 {
                exception = stack.pop();
                stack.append(py_none());
                stack.append(exception);
                # Mark this exception as the one being handled (for bare `raise`).
                exc_handling.append(exception);
            }
            continue;
        }
        if op == OP_CHECK_EXC_MATCH {
            match_type: PyObj = stack.pop();
            exception = stack[len(stack) - 1];
            stack.append(
                PyBool(t="bool", val=exception_matches(exception, match_type))
            );
            continue;
        }
        if op == OP_POP_EXCEPT {
            if len(stack) > 0 {
                stack.pop();
            }
            if len(exc_handling) > 0 {
                exc_handling.pop();
            }
            continue;
        }
        if op == OP_RAISE_VARARGS {
            # arg: 0 = re-raise, 1 = raise exc, 2 = raise exc from cause. For the
            # `from` form the cause is on top, the exception below it; the cause is
            # popped and (for now) discarded -- what matters is raising `exc`.
            raised = py_none();
            if arg == 2 {
                stack.pop();
                raised = stack.pop();
            } elif arg == 1 {
                raised = stack.pop();
            } elif len(exc_handling) > 0 {
                # Bare `raise`: re-raise the exception currently being handled.
                raised = exc_handling[len(exc_handling) - 1];
            }
            result = py_raise_value(raised);
            target = recover_exception(co, result, offset, stack);
            if target >= 0 {
                ip = target;
                continue;
            }
            return result;
        }
        if op == OP_RERAISE {
            raised = stack[len(stack) - 1];
            result = py_raise_value(raised);
            target = recover_exception(co, result, offset, stack);
            if target >= 0 {
                ip = target;
                continue;
            }
            return result;
        }
        if op == OP_COPY {
            stack.append(stack[len(stack) - arg]);
            continue;
        }
        if op == OP_SWAP {
            # SWAP(i) exchanges TOS with the item i positions down (stack[-i],
            # index len-i). TOS itself is position 1.
            swap_top = len(stack) - 1;
            swap_other = len(stack) - arg;
            swapped: PyObj = stack[swap_top];
            stack[swap_top] = stack[swap_other];
            stack[swap_other] = swapped;
            continue;
        }
        if op == OP_LOAD_SPECIAL {
            # LOAD_SPECIAL macro (_INSERT_NULL + _LOAD_SPECIAL): pop the context
            # manager, look up __enter__/__exit__, push [func, self_or_null] for
            # the CALL convention (method descriptors keep the owner as self).
            if len(stack) < 1 {
                return py_error("RuntimeError", "LOAD_SPECIAL stack underflow");
            }
            owner = stack.pop();
            spec_name = "__enter__";
            if arg == 1 {
                spec_name = "__exit__";
            } elif arg == 2 {
                spec_name = "__aenter__";
            } elif arg == 3 {
                spec_name = "__aexit__";
            }
            method = py_attr(owner, spec_name);
            if is_error(method) {
                target = recover_exception(co, method, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return method;
            }
            if isinstance(method, PyBoundMethod) {
                stack.append((method as PyBoundMethod).function);
                stack.append(py_none());
            } else {
                stack.append(method);
                stack.append(owner);
            }
            continue;
        }
        if op == OP_WITH_EXCEPT_START {
            # WITH_EXCEPT_START: call the context manager's __exit__ with the
            # active exception info and push its truthy suppress flag.
            if len(stack) < 5 {
                return py_error("RuntimeError", "WITH_EXCEPT_START stack underflow");
            }
            val = stack[len(stack) - 1];
            exit_self = stack[len(stack) - 4];
            exit_func = stack[len(stack) - 5];
            exc_type: PyObj = py_none();
            if val.t == "exception" {
                exc_type = py_exception_type((val as PyException).type_name);
            }
            exit_args: list[PyObj] = [exc_type, val, py_none()];
            exit_result: PyObj = py_none();
            if exit_self.t != "none" {
                exit_result = bind_attribute(exit_func, exit_self).tp_call(
                    exit_args, {}
                );
            } else {
                exit_result = py_invoke(exit_func, exit_args, {});
            }
            if is_error(exit_result) {
                target = recover_exception(co, exit_result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return exit_result;
            }
            stack.append(exit_result);
            continue;
        }
        if op == OP_RETURN_GENERATOR {
            # The generator object already exists (created at call time). Push a
            # placeholder standing in for it; the following POP_TOP discards it.
            stack.append(py_none());
            continue;
        }
        if op == OP_YIELD_VALUE {
            # Suspend: pop the yielded value, freeze the resume point, and hand
            # the value up to gen_resume. run_frame re-enters here from ip.
            # oparg 1 marks a yield-from delegation, so a later throw knows to
            # route into the sub-iterator rather than inject at this point.
            value = stack.pop();
            frame.ip = ip;
            frame.yf = arg == 1;
            return PyYield(t="yield", val=value);
        }
        if op == OP_TO_BOOL {
            condition = stack.pop();
            stack.append(PyBool(t="bool", val=py_truth(condition)));
            continue;
        }
        if op == OP_CONTAINS_OP {
            container = stack.pop();
            member = stack.pop();
            contained = py_contains(container, member);
            if is_error(contained) {
                target = recover_exception(co, contained, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return contained;
            }
            present = py_truth(contained);
            if arg == 1 {
                present = not present;
            }
            stack.append(PyBool(t="bool", val=present));
            continue;
        }
        if op == OP_LOAD_COMMON_CONSTANT {
            # _common_constants: [AssertionError, NotImplementedError, tuple,
            # all, any]. Resolved through host_builtin so an identity check like
            # `tuple is <common tuple>` (the tuple()/frozenset() genexpr fast
            # path) sees the same host-proxy tag on both sides.
            common_name = "tuple";
            if arg == 0 {
                common_name = "AssertionError";
            } elif arg == 1 {
                common_name = "NotImplementedError";
            } elif arg == 3 {
                common_name = "all";
            } elif arg == 4 {
                common_name = "any";
            }
            stack.append(host_builtin(common_name));
            continue;
        }
        if op == OP_CALL_INTRINSIC_1 {
            operand = stack.pop();
            if arg == 6 {
                # INTRINSIC_LIST_TO_TUPLE: the tuple()-of-genexpr fast path
                # builds a list, then converts it in place.
                stack.append(PyTuple(t="tuple", items=(operand as PyList).items));
                continue;
            }
            if arg == 3 {
                # INTRINSIC_STOPITERATION_ERROR (PEP 479): the pending exception
                # is on the stack. A StopIteration escaping a generator body is
                # converted to RuntimeError; everything else passes through. The
                # following RERAISE propagates whatever we push back.
                exc_name = "";
                if operand.t == "exception" {
                    exc_name = (operand as PyException).type_name;
                }
                if exc_name == "StopIteration" or exc_name == "StopAsyncIteration" {
                    stack.append(
                        PyException(
                            t="exception",
                            type_name="RuntimeError",
                            message="generator raised " + exc_name,
                        )
                    );
                } else {
                    stack.append(operand);
                }
                continue;
            }
            if arg == 5 {
                # INTRINSIC_UNARY_POSITIVE
                stack.append(operand);
                continue;
            }
            if arg == 2 {
                # INTRINSIC_IMPORT_STAR: `from module import *` binds the module's
                # exported names into the current globals. (Layer 3 only.)
                star_out = import_star_into(operand, globals);
                if is_error(star_out) {
                    target = recover_exception(co, star_out, offset, stack);
                    if target >= 0 {
                        ip = target;
                        continue;
                    }
                    return star_out;
                }
                # CPython pushes None for the following POP_TOP.
                stack.append(py_none());
                continue;
            }
            return py_error("SystemError", "unsupported CALL_INTRINSIC_1 " + str(arg));
        }
        if op == OP_RETURN_VALUE {
            if len(stack) == 0 {
                return py_none();
            }
            return stack.pop();
        }
        if op == OP_POP_TOP {
            if len(stack) > 0 {
                stack.pop();
            }
            continue;
        }
        return py_error("SystemError", "unsupported opcode " + str(op));
    }
    return py_none();
}

def exec_code(co: PyObj, args: list[PyObj], globals: dict[str, PyObj]) -> PyObj {
    match co {
        case PyCode():
            return exec_code_frame(co, args, {}, globals, globals, [], [], {});

    }
    return py_error("TypeError", "expected code object");
}

def exec_module(co: PyObj) -> dict[str, PyObj] {
    globals: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    exec_code(co, [], globals);
    return globals;
}


# ---------------- fixtures (real CPython 3.14.6 marshal output) ----------------
# Produced by: marshal.dumps(compile(src, '', 'exec').co_consts[0]) for funcs,
# or marshal.dumps(compile(src, '', 'exec')) for the module.

# ---------------- tests ----------------
def run_source(source: str) -> dict[str, PyObj] {
    return exec_module(unmarshal(host_compile_marshal(source)));
}

test "pyc-first: attributes and imports" {
    imported = run_source(
        "import math\nfrom math import sqrt\nresult = math.floor(sqrt(81))\n"
    );
    assert expect_int(imported["result"]) == 9;

    classes = run_source(
        "class Box:\n"
        "    def __init__(self, value): self.value = value\n"
        "    def get(self): return self.value\n"
        "box = Box(7)\n"
        "result = box.value + box.get()\n"
    );
    assert expect_int(classes["result"]) == 14;
}

test "pyc-first: control flow and iteration" {
    branch = run_source(
        "def choose(x):\n"
        "    if x > 3:\n"
        "        return x * 2\n"
        "    return x - 1\n"
        "result = choose(4)\n"
    );
    assert expect_int(branch["result"]) == 8;

    loop = run_source(
        "total = 0\n"
        "for i in range(5):\n"
        "    total = total + i\n"
        "result = total\n"
    );
    assert expect_int(loop["result"]) == 10;

    while_loop = run_source(
        "i = 0\n" "while i < 4:\n" "    i = i + 1\n" "result = i\n"
    );
    assert expect_int(while_loop["result"]) == 4;

    mapping = run_source("values = {'answer': 42}\nresult = values['answer']\n");
    assert expect_int(mapping["result"]) == 42;
}

test "pyc-first: exception table unwinding" {
    result = run_source(
        "def safe(x):\n"
        "    try:\n"
        "        return 10 // x\n"
        "    except ZeroDivisionError:\n"
        "        return 99\n"
        "result = safe(0)\n"
    );
    assert expect_int(result["result"]) == 99;

    multiple = run_source(
        "try:\n"
        "    1 // 0\n"
        "except ValueError:\n"
        "    result = 1\n"
        "except ZeroDivisionError:\n"
        "    result = 2\n"
    );
    assert expect_int(multiple["result"]) == 2;

    raised = run_source(
        "try:\n"
        "    raise ValueError('bad')\n"
        "except ValueError as error:\n"
        "    result = 3\n"
    );
    assert expect_int(raised["result"]) == 3;
}

test "pyc-first: closure cells" {
    result = run_source(
        "def make_adder(x):\n"
        "    def add(y):\n"
        "        return x + y\n"
        "    return add\n"
        "result = make_adder(7)(5)\n"
    );
    assert expect_int(result["result"]) == 12;

    counter = run_source(
        "def make_counter():\n"
        "    value = 0\n"
        "    def increment():\n"
        "        nonlocal value\n"
        "        value = value + 1\n"
        "        return value\n"
        "    return increment\n"
        "counter = make_counter()\n"
        "counter()\n"
        "result = counter()\n"
    );
    assert expect_int(counter["result"]) == 2;
}

test "pyc-first: keyword calls and defaults" {
    result = run_source(
        "def greet(name, punctuation='!'):\n"
        "    return name + punctuation\n"
        "result = greet(punctuation='?', name='hi')\n"
    );
    assert expect_str(result["result"]) == "hi?";
}

test "pyc-first: real CPython 3.14 marshal -> jacpython ceval" {
    add_co = unmarshal(ADD_MARSHAL);
    assert add_co.t == "code";
    add_args: list[PyObj] = [PyInt(t="int", val=2), PyInt(t="int", val=3)];
    add_res = exec_code(add_co, add_args, {});
    assert add_res.t == "int";
    assert expect_int(add_res) == 5;

    mul_co = unmarshal(MUL_MARSHAL);
    mul_res = exec_code(mul_co, [PyInt(t="int", val=4), PyInt(t="int", val=5)], {});
    assert expect_int(mul_res) == 20;

    mod_co = unmarshal(MOD_MARSHAL);
    mod_res = exec_code(mod_co, [PyInt(t="int", val=17), PyInt(t="int", val=5)], {});
    assert expect_int(mod_res) == 2;

    scale_co = unmarshal(SCALE_MARSHAL);
    scale_res = exec_code(scale_co, [PyInt(t="int", val=5)], {});
    assert expect_int(scale_res) == 50;

    ym_co = unmarshal(YMODULE_MARSHAL);
    globals = exec_module(ym_co);
    assert "y" in globals;
    assert expect_int(globals["y"]) == 43;

    # The source boundary is real host compile -> marshal -> Jac unmarshal;
    # this is deliberately not another embedded byte fixture.
    source = "numbers = [4, 5, 6]\nanswer = numbers[1] + 2\nword = 'a' + 'b'\n";
    source_co = unmarshal(host_compile_marshal(source));
    source_globals = exec_module(source_co);
    assert expect_int(source_globals["answer"]) == 7;
    assert expect_str(source_globals["word"]) == "ab";
    assert expect_int(
        py_subscript(source_globals["numbers"], PyInt(t="int", val=1))
    ) == 5;

    function_source = "def add(a, b):\n    return a + b\nresult = add(2, 3)\n";
    function_co = unmarshal(host_compile_marshal(function_source));
    function_globals = exec_module(function_co);
    assert expect_int(function_globals["result"]) == 5;
}

test "pyc-first: augmented assignment (NB_INPLACE_* binops) matches base ops" {
    # BINARY_OP opargs 13..25 are the in-place operators; jacpython folds them to
    # their base binop (x += y == x = x + y) since these values are immutable.
    ops = run_source(
        "a = 10\na += 5\n"
        "b = 10\nb -= 3\n"
        "c = 4\nc *= 3\n"
        "d = 17\nd %= 5\n"
        "e = 20\ne //= 6\n"
        "f = 2\nf **= 5\n"
        "g = 6\ng &= 3\n"
        "h = 5\nh |= 2\n"
        "i = 5\ni ^= 1\n"
        "j = 1\nj <<= 4\n"
        "k = 'ab'\nk += 'cd'\n"
    );
    assert expect_int(ops["a"]) == 15;
    assert expect_int(ops["b"]) == 7;
    assert expect_int(ops["c"]) == 12;
    assert expect_int(ops["d"]) == 2;
    assert expect_int(ops["e"]) == 3;
    assert expect_int(ops["f"]) == 32;
    assert expect_int(ops["g"]) == 2;
    assert expect_int(ops["h"]) == 7;
    assert expect_int(ops["i"]) == 4;
    assert expect_int(ops["j"]) == 16;
    assert expect_str(ops["k"]) == "abcd";
}

test "pyc-first: true divide, xor, unary neg/invert on non-constant int operands" {
    # Non-constant operands defeat the compiler's constant folding, so these hit
    # the native PyInt.nb_binop / unary slots. True divide (oparg 11) must yield a
    # float even when it divides evenly; XOR is a distinct oparg (12).
    ops = run_source(
        "a = 6\nb = 2\n"
        "q_even = a / b\n"
        "c = 7\nq_frac = c / b\n"
        "x = 6\ny = 3\nz = x ^ y\n"
        "n = 5\nneg = -n\ninv = ~n\n"
    );
    assert ops["q_even"].t == "float";
    assert expect_float(ops["q_even"]) == 3.0;
    assert expect_float(ops["q_frac"]) == 3.5;
    assert ops["z"].t == "int";
    assert expect_int(ops["z"]) == 5;
    assert expect_int(ops["neg"]) == -5;
    assert expect_int(ops["inv"]) == -6;

    # int / 0 raises ZeroDivisionError natively rather than returning a bogus int.
    zdiv = PyInt(t="int", val=1).nb_binop(11, PyInt(t="int", val=0));
    assert is_error(zdiv);

    # A negative shift count is a ValueError, not a native crash (oparg 3 = <<).
    negshift = PyInt(t="int", val=1).nb_binop(3, PyInt(t="int", val=-1));
    assert is_error(negshift);

    # test_augassign::testBasic verbatim: the trailing `x /= 2` on int 6 must
    # produce float 3.0 (this is the case the true-divide/XOR oparg swap broke).
    basic = run_source(
        "x = 2\nx += 1\nx *= 2\nx **= 2\nx -= 8\nx //= 5\n"
        "x %= 3\nx &= 2\nx |= 5\nx ^= 1\nx /= 2\n"
    );
    assert basic["x"].t == "float";
    assert expect_float(basic["x"]) == 3.0;
}

test "pyc-first: UNPACK_SEQUENCE, DELETE_SUBSCR, MAP_ADD, DICT_UPDATE opcodes" {
    # Sequence unpacking from tuple, list, and string.
    un = run_source(
        "ta, tb = (10, 20)\n"
        "la, lb, lc = [1, 2, 3]\n"
        "s1, s2 = 'hi'\n"
    );
    assert expect_int(un["ta"]) == 10;
    assert expect_int(un["tb"]) == 20;
    assert expect_int(un["la"]) == 1;
    assert expect_int(un["lc"]) == 3;
    assert expect_str(un["s1"]) == "h";
    assert expect_str(un["s2"]) == "i";

    # del on dict and list; the deleted keys/indices are gone afterward.
    dl = run_source(
        "d = {'x': 1, 'y': 2}\ndel d['x']\n"
        "has_x = 'x' in d\nkept = d['y']\n"
        "L = [1, 2, 3]\ndel L[1]\nl0 = L[0]\nl1 = L[1]\n"
    );
    assert expect_bool(dl["has_x"]) == False;
    assert expect_int(dl["kept"]) == 2;
    assert expect_int(dl["l0"]) == 1;
    assert expect_int(dl["l1"]) == 3;

    # dict comprehension (MAP_ADD + STORE_FAST_STORE_FAST) with str keys, which
    # the str-keyed native PyDict supports.
    dc = run_source("m = {c: c + c for c in ['a', 'b']}\nma = m['a']\nmb = m['b']\n");
    assert expect_str(dc["ma"]) == "aa";
    assert expect_str(dc["mb"]) == "bb";

    # {**a, **b} dict-display merge (DICT_UPDATE); later mapping wins on overlap.
    mg = run_source(
        "merged = {**{'a': 1, 'b': 2}, **{'b': 3, 'c': 4}}\n"
        "va = merged['a']\nvb = merged['b']\nvc = merged['c']\n"
    );
    assert expect_int(mg["va"]) == 1;
    assert expect_int(mg["vb"]) == 3;
    assert expect_int(mg["vc"]) == 4;
}

test "pyc-first: PyFloat nb_binop/tp_richcompare drive natively" {
    # Arithmetic promotes int/bool operands to float and routes through the
    # native PyFloat.nb_binop slot (not the host fallback).
    ops = run_source(
        "add = 1.5 + 2\n"
        "sub = 5.0 - 1.5\n"
        "mul = 2.5 * 4\n"
        "div = 7.0 / 2\n"
        "flr = 7.5 // 2.0\n"
        "mod = 7.5 % 2.0\n"
        "pw = 2.0 ** 3\n"
        "mixed = 1.5 + True\n"
    );
    assert expect_float(ops["add"]) == 3.5;
    assert expect_float(ops["sub"]) == 3.5;
    assert expect_float(ops["mul"]) == 10.0;
    assert expect_float(ops["div"]) == 3.5;
    assert expect_float(ops["flr"]) == 3.0;
    assert expect_float(ops["mod"]) == 1.5;
    assert expect_float(ops["pw"]) == 8.0;
    assert expect_float(ops["mixed"]) == 2.5;

    # Ordered comparisons -- previously the tag-comparing default gave wrong
    # answers for float-on-left.
    cmps = run_source(
        "lt = 1.5 < 2.5\n"
        "gt = 1.5 > 2.5\n"
        "eq = 2.5 == 2.5\n"
        "le = 2.0 <= 2\n"
        "mixed_eq = 3.0 == 3\n"
    );
    assert expect_bool(cmps["lt"]) == True;
    assert expect_bool(cmps["gt"]) == False;
    assert expect_bool(cmps["eq"]) == True;
    assert expect_bool(cmps["le"]) == True;
    assert expect_bool(cmps["mixed_eq"]) == True;

    # NaN: every comparison but != is False; != is True.
    nans = run_source(
        "n = float('nan')\n"
        "self_eq = n == n\n"
        "self_ne = n != n\n"
        "self_lt = n < n\n"
    );
    assert expect_bool(nans["self_eq"]) == False;
    assert expect_bool(nans["self_ne"]) == True;
    assert expect_bool(nans["self_lt"]) == False;

    # Division by zero raises rather than falling through to host.
    zdiv = PyFloat(t="float", val=1.0).nb_binop(11, PyFloat(t="float", val=0.0));
    assert is_error(zdiv);
}

test "pyc-first: PyInt tp_richcompare handles float/bool right operand" {
    # int-on-left, float-on-right: previously the tag-mismatch default returned
    # a bogus bool. Now int promotes to float and compares correctly.
    cmps = run_source(
        "lt = 1 < 2.5\n"
        "gt = 5 > 2.5\n"
        "ge = 3 >= 3.0\n"
        "le = 2 <= 2.5\n"
        "eqf = 3 == 3.0\n"
        "nef = 3 != 3.5\n"
    );
    assert expect_bool(cmps["lt"]) == True;
    assert expect_bool(cmps["gt"]) == True;
    assert expect_bool(cmps["ge"]) == True;
    assert expect_bool(cmps["le"]) == True;
    assert expect_bool(cmps["eqf"]) == True;
    assert expect_bool(cmps["nef"]) == True;

    # int vs bool (bool is an int subclass -- compare by numeric value).
    bools = run_source(
        "eqt = 1 == True\n"
        "eqf0 = 0 == False\n"
        "gtb = 2 > True\n"
        "ltb = 0 < True\n"
    );
    assert expect_bool(bools["eqt"]) == True;
    assert expect_bool(bools["eqf0"]) == True;
    assert expect_bool(bools["gtb"]) == True;
    assert expect_bool(bools["ltb"]) == True;

    # int vs NaN on the right: only != is True.
    nans = run_source(
        "n = float('nan')\n"
        "eqn = 1 == n\n"
        "nen = 1 != n\n"
        "ltn = 1 < n\n"
    );
    assert expect_bool(nans["eqn"]) == False;
    assert expect_bool(nans["nen"]) == True;
    assert expect_bool(nans["ltn"]) == False;
}

test "pyc-first: DELETE_NAME unbinds a module global" {
    deleted = run_source("x = 5\ndel x\nresult = 1\n");
    assert expect_int(deleted["result"]) == 1;
    assert not ("x" in deleted);
}

test "pyc-first: value-keyed dicts via the hash-key protocol (H2)" {
    # int / float / bool keys with Python's numeric collapse: 1, 1.0 and True
    # all address the same slot, so the last write wins and len stays 2.
    numk = run_source(
        "d = {1: 'a', 2: 'b'}\n"
        "d[1.0] = 'c'\n"
        "d[True] = 'd'\n"
        "one = d[1]\ntwo = d[2]\nsize = len(d)\n"
    );
    assert expect_str(numk["one"]) == "d";
    assert expect_str(numk["two"]) == "b";
    assert expect_int(numk["size"]) == 2;

    # tuple keys (recursive, length-framed hashkey), including a nested tuple.
    tupk = run_source(
        "d = {(1, 2): 'x', (3, (4, 5)): 'y'}\n"
        "a = d[(1, 2)]\nb = d[(3, (4, 5))]\nhas = (1, 2) in d\n"
    );
    assert expect_str(tupk["a"]) == "x";
    assert expect_str(tupk["b"]) == "y";
    assert expect_bool(tupk["has"]) == True;

    # int-keyed dict comprehension -- previously fell back to an opaque host map.
    comp = run_source(
        "sq = {n: n * n for n in range(4)}\n"
        "s0 = sq[0]\ns3 = sq[3]\nn = len(sq)\n"
    );
    assert expect_int(comp["s0"]) == 0;
    assert expect_int(comp["s3"]) == 9;
    assert expect_int(comp["n"]) == 4;

    # del with a non-str key; float/int collapse means del d[2.0] removes key 2.
    deld = run_source(
        "d = {1: 'a', 2: 'b', 3: 'c'}\ndel d[2.0]\n"
        "has2 = 2 in d\nkept = d[3]\n"
    );
    assert expect_bool(deld["has2"]) == False;
    assert expect_str(deld["kept"]) == "c";

    # str "1" and int 1 are distinct keys (prefix disambiguation), no collision.
    mix = run_source(
        "d = {'1': 'str-one', 1: 'int-one'}\n"
        "s = d['1']\ni = d[1]\nn = len(d)\n"
    );
    assert expect_str(mix["s"]) == "str-one";
    assert expect_str(mix["i"]) == "int-one";
    assert expect_int(mix["n"]) == 2;

    # A missing non-str key raises KeyError, not a silent wrong value.
    miss = run_source("d = {1: 'a'}\nout = 0\ntry:\n    d[9]\nexcept KeyError:\n    out = 1\n");
    assert expect_int(miss["out"]) == 1;

    # An unhashable key (list) is a TypeError at the slot, not a mis-key.
    unh = PyDict(t="dict", items={}).mp_ass_subscript(
        PyList(t="list", items=[]), PyStr(t="str", val="v")
    );
    assert is_error(unh);
}

test "pyc-first: native sets via the hash-key protocol (H3)" {
    # Membership + numeric collapse: 2.0 and True find the same slots as 2 / 1.
    mem = run_source(
        "s = {1, 2, 3}\n"
        "a = 2.0 in s\nb = True in s\nc = 4 in s\nn = len(s)\n"
    );
    assert expect_bool(mem["a"]) == True;
    assert expect_bool(mem["b"]) == True;
    assert expect_bool(mem["c"]) == False;
    assert expect_int(mem["n"]) == 3;

    # Set algebra runs natively (PySet.nb_binop). Compare sizes to dodge
    # element-order noise across the boundary.
    ops = run_source(
        "u = len({1, 2, 3} | {3, 4})\n"
        "i = len({1, 2, 3} & {2, 3, 4})\n"
        "d = len({1, 2, 3} - {2})\n"
        "x = len({1, 2, 3} ^ {2, 3, 4})\n"
    );
    assert expect_int(ops["u"]) == 4;
    assert expect_int(ops["i"]) == 2;
    assert expect_int(ops["d"]) == 2;
    assert expect_int(ops["x"]) == 2;

    # Subset / equality comparisons.
    cmp = run_source(
        "sub = {1, 2} <= {1, 2, 3}\n"
        "eq = {1, 2} == {2, 1}\n"
        "psub = {1, 2} < {1, 2}\n"
        "sup = {1, 2, 3} > {1, 2}\n"
    );
    assert expect_bool(cmp["sub"]) == True;
    assert expect_bool(cmp["eq"]) == True;
    assert expect_bool(cmp["psub"]) == False;
    assert expect_bool(cmp["sup"]) == True;

    # Set comprehension dedupes value-equal members (1 and 1.0 collapse).
    comp = run_source("s = {n % 3 for n in range(10)}\nn = len(s)\n");
    assert expect_int(comp["n"]) == 3;

    # frozenset is hashable and order-independent as a dict key.
    fz = run_source(
        "d = {frozenset({1, 2}): 'x'}\n"
        "hit = d[frozenset({2, 1})]\nmem = frozenset({1, 2}) in d\n"
    );
    assert expect_str(fz["hit"]) == "x";
    assert expect_bool(fz["mem"]) == True;

    # A mutable set is unhashable.
    unh = PySet(t="set", items={}, frozen=False).tp_hashkey();
    assert unh == "";
}

test "pyc-first: builtin subclassing (Track B)" {
    # Subclass of int: operator + hashkey delegation to the boxed value, plus a
    # method override, and isinstance/issubclass across the builtin ancestor.
    mi = run_source(
        "class MyInt(int):\n"
        "    def double(self):\n"
        "        return self * 2\n"
        "x = MyInt(5)\n"
        "add = x + 1\n"
        "radd = 1 + x\n"
        "dbl = x.double()\n"
        "isi = isinstance(x, int)\n"
        "iso = isinstance(x, object)\n"
        "iss = isinstance(x, str)\n"
        "sub = issubclass(MyInt, int)\n"
        "d = {x: 'five'}\nkeyed = d[5]\n"
    );
    assert expect_int(mi["add"]) == 6;
    assert expect_int(mi["radd"]) == 6;
    assert expect_int(mi["dbl"]) == 10;
    assert expect_bool(mi["isi"]) == True;
    assert expect_bool(mi["iso"]) == True;
    assert expect_bool(mi["iss"]) == False;
    assert expect_bool(mi["sub"]) == True;
    assert expect_str(mi["keyed"]) == "five";

    # Subclass of str: base-method delegation (upper) + operator (concat).
    ms = run_source(
        "class MyStr(str):\n    pass\n"
        "m = MyStr('hi')\nup = m.upper()\ncat = m + '!'\n"
        "iss = isinstance(m, str)\n"
    );
    assert expect_str(ms["up"]) == "HI";
    assert expect_str(ms["cat"]) == "hi!";
    assert expect_bool(ms["iss"]) == True;

    # Plain user-class hierarchy: method override + inherited attr + super().
    uc = run_source(
        "class Animal:\n"
        "    def __init__(self, n):\n"
        "        self.n = n\n"
        "    def speak(self):\n"
        "        return self.n\n"
        "class Dog(Animal):\n"
        "    def __init__(self, n, breed):\n"
        "        super().__init__(n)\n"
        "        self.breed = breed\n"
        "    def speak(self):\n"
        "        return super().speak() + ' woof'\n"
        "d = Dog('rex', 'lab')\n"
        "name = d.n\nbreed = d.breed\nsound = d.speak()\n"
        "isa = isinstance(d, Animal)\nisd = isinstance(d, Dog)\n"
        "sub = issubclass(Dog, Animal)\n"
    );
    assert expect_str(uc["name"]) == "rex";
    assert expect_str(uc["breed"]) == "lab";
    assert expect_str(uc["sound"]) == "rex woof";
    assert expect_bool(uc["isa"]) == True;
    assert expect_bool(uc["isd"]) == True;
    assert expect_bool(uc["sub"]) == True;
}

test "pyc-first: user-class operator overloading (__add__/__eq__/... dispatch)" {
    # A plain user class defines operators as dunder methods; nb_binop /
    # tp_richcompare route through the MRO (normal slot, then reflected) instead
    # of only the builtin native slots.
    ops = run_source(
        "class V:\n"
        "    def __init__(self, x):\n"
        "        self.x = x\n"
        "    def __add__(self, o):\n"
        "        return V(self.x + o.x)\n"
        "    def __mul__(self, k):\n"
        "        return V(self.x * k)\n"
        "    def __eq__(self, o):\n"
        "        return self.x == o.x\n"
        "    def __lt__(self, o):\n"
        "        return self.x < o.x\n"
        "add = (V(3) + V(4)).x\n"
        "mul = (V(5) * 3).x\n"
        "eq = (V(5) == V(5))\n"
        "ne = (V(5) != V(6))\n"
        "lt = (V(1) < V(2))\n"
        "gt = (V(3) < V(2))\n"
    );
    assert expect_int(ops["add"]) == 7;
    assert expect_int(ops["mul"]) == 15;
    assert expect_bool(ops["eq"]) == True;
    assert expect_bool(ops["ne"]) == True;
    assert expect_bool(ops["lt"]) == True;
    assert expect_bool(ops["gt"]) == False;

    # Reflected slot: a builtin left operand with no matching native path falls
    # to the user right operand's __radd__ / __rmul__.
    refl = run_source(
        "class R:\n"
        "    def __radd__(self, o):\n"
        "        return o + 100\n"
        "    def __rmul__(self, o):\n"
        "        return o * 10\n"
        "a = 1 + R()\n"
        "b = 5 * R()\n"
    );
    assert expect_int(refl["a"]) == 101;
    assert expect_int(refl["b"]) == 50;

    # __add__ returning NotImplemented yields to the other operand's __radd__.
    ni = run_source(
        "class A:\n"
        "    def __add__(self, o):\n"
        "        return NotImplemented\n"
        "class B:\n"
        "    def __radd__(self, o):\n"
        "        return 77\n"
        "w = A() + B()\n"
    );
    assert expect_int(ni["w"]) == 77;

    # A user-defined __hash__ (+ __eq__) makes an instance a value-keyed dict key
    # and set member; a plain user object keys by identity. Verified through the
    # fully native mp_subscript / set_contains paths (no host round-trip).
    hk = run_source(
        "class H:\n"
        "    def __init__(self, k):\n"
        "        self.k = k\n"
        "    def __hash__(self):\n"
        "        return self.k\n"
        "    def __eq__(self, o):\n"
        "        return self.k == o.k\n"
        "d = {H(1): 'one', H(2): 'two'}\n"
        "v1 = d[H(1)]\nv2 = d[H(2)]\n"
        "s = {H(1), H(2)}\n"
        "hit = H(1) in s\nmiss = H(3) in s\n"
    );
    assert expect_str(hk["v1"]) == "one";
    assert expect_str(hk["v2"]) == "two";
    assert expect_bool(hk["hit"]) == True;
    assert expect_bool(hk["miss"]) == False;

    # An exception raised inside a comparison dunder propagates (it is not
    # swallowed as NotImplemented) -- the substrate the corpus's raising-__eq__
    # cases build on.
    raising = run_source(
        "class Bad:\n"
        "    def __eq__(self, o):\n"
        "        raise ValueError('boom')\n"
        "hit = 0\n"
        "try:\n"
        "    Bad() == Bad()\n"
        "except ValueError:\n"
        "    hit = 1\n"
    );
    assert expect_int(raising["hit"]) == 1;
}

test "pyc-first: len() reads native container size in-VM (no to_host drain)" {
    # len() over the native container types is measured from their own storage.
    sizes = run_source(
        "a = len('hello')\n"
        "b = len(b'ab')\n"
        "c = len((1, 2, 3))\n"
        "d = len([1, 2])\n"
        "e = len({'x': 1, 'y': 2})\n"
        "f = len({1, 2, 3, 3})\n"
    );
    assert expect_int(sizes["a"]) == 5;
    assert expect_int(sizes["b"]) == 2;
    assert expect_int(sizes["c"]) == 3;
    assert expect_int(sizes["d"]) == 2;
    assert expect_int(sizes["e"]) == 2;
    assert expect_int(sizes["f"]) == 3;

    # The regression: a native set/list/dict of PLAIN user objects. Each member
    # to_host-es to None, so counting a host copy loses them; the native path
    # reads the real member count. __hash__/__eq__ make them distinct set/key
    # members without collapsing.
    plain = run_source(
        "class P:\n"
        "    def __init__(self, k):\n"
        "        self.k = k\n"
        "    def __hash__(self):\n"
        "        return self.k\n"
        "    def __eq__(self, o):\n"
        "        return self.k == o.k\n"
        "s = len({P(1), P(2), P(3)})\n"
        "l = len([P(1), P(1), P(1)])\n"
        "d = len({P(1): 'a', P(2): 'b'})\n"
    );
    assert expect_int(plain["s"]) == 3;
    assert expect_int(plain["l"]) == 3;
    assert expect_int(plain["d"]) == 2;

    # A user class with __len__ dispatches to it; truthiness of the count works.
    dunder = run_source(
        "class Box:\n"
        "    def __init__(self, n):\n"
        "        self.n = n\n"
        "    def __len__(self):\n"
        "        return self.n\n"
        "z = len(Box(7))\n"
    );
    assert expect_int(dunder["z"]) == 7;

    # A user object with no __len__ raises TypeError (recoverable).
    err = run_source(
        "class Bare:\n"
        "    pass\n"
        "hit = 0\n"
        "try:\n"
        "    len(Bare())\n"
        "except TypeError:\n"
        "    hit = 1\n"
    );
    assert expect_int(err["hit"]) == 1;
}

test "pyc-first: object identity -- is / id (Track I)" {
    # None/bool singletons + small-int cache match CPython; mutable containers
    # and big ints use real reference identity. Previously IS_OP compared type
    # tags, so [] is [] wrongly returned True.
    ident = run_source(
        "n = None is None\n"
        "t = True is True\n"
        "f = False is False\n"
        "tf = True is False\n"
        "k1 = 200\nk2 = 56\nc256 = 256\nsi = (k1 + k2) is c256\n"
        "b1 = 1000\nb2 = 1\nc1001 = 1001\nbi = (b1 + b2) is c1001\n"
        "el = [] is []\n"
        "nn = None is not None\n"
    );
    assert expect_bool(ident["n"]) == True;
    assert expect_bool(ident["t"]) == True;
    assert expect_bool(ident["f"]) == True;
    assert expect_bool(ident["tf"]) == False;
    assert expect_bool(ident["si"]) == True;
    assert expect_bool(ident["bi"]) == False;
    assert expect_bool(ident["el"]) == False;
    assert expect_bool(ident["nn"]) == False;

    # Aliasing: an object is identical to itself, distinct from an equal literal.
    alias = run_source(
        "a = [1, 2]\nb = a\nsame = a is b\nc = [1, 2]\ndiff = a is c\n"
    );
    assert expect_bool(alias["same"]) == True;
    assert expect_bool(alias["diff"]) == False;

    # id() is stable, singleton-consistent, and distinct for distinct live objects.
    ids = run_source(
        "x = [1]\nself_id = id(x) == id(x)\n"
        "none_id = id(None) == id(None)\n"
        "small_id = id(5) == id(5)\n"
        "p = [1]\nq = [2]\ndistinct = id(p) != id(q)\n"
    );
    assert expect_bool(ids["self_id"]) == True;
    assert expect_bool(ids["none_id"]) == True;
    assert expect_bool(ids["small_id"]) == True;
    assert expect_bool(ids["distinct"]) == True;
}

test "pyc-first: hash() builtin + float.__hash__ collapse (H4)" {
    # The user-facing hash() int (distinct from the internal tp_hashkey string)
    # resolves through the host-builtin fallback with Python's collapse:
    # hash(1) == hash(1.0) == hash(True). float.__hash__ and tuple hashing work.
    h = run_source(
        "collapse = hash(1) == hash(1.0) == hash(True)\n"
        "fh = (2.0).__hash__() == hash(2)\n"
        "th = hash((1, 2)) == hash((1, 2))\n"
    );
    assert expect_bool(h["collapse"]) == True;
    assert expect_bool(h["fh"]) == True;
    assert expect_bool(h["th"]) == True;
}

test "pyc-first: full generator functions (def + yield) drive natively" {
    # A CO_GENERATOR-flagged def returns a generator on call; the body only runs
    # on resume. Plain iteration (list/sum) drains through gen_drain.
    simple = run_source(
        "def g():\n"
        "    yield 1\n"
        "    yield 2\n"
        "    yield 3\n"
        "result = list(g())\n"
        "total = sum(g())\n"
    );
    assert expect_int(py_subscript(simple["result"], PyInt(t="int", val=0))) == 1;
    assert expect_int(py_subscript(simple["result"], PyInt(t="int", val=2))) == 3;
    assert expect_int(simple["total"]) == 6;
}

test "pyc-first: generator .send() round-trips values through the yield" {
    # `v = yield total` binds the sent value; a just-started generator is primed
    # with send(None). Each send resumes at the suspended yield.
    accum = run_source(
        "def accumulate():\n"
        "    total = 0\n"
        "    while True:\n"
        "        v = yield total\n"
        "        total = total + v\n"
        "gen = accumulate()\n"
        "first = gen.send(None)\n"
        "a = gen.send(10)\n"
        "b = gen.send(5)\n"
    );
    assert expect_int(accum["first"]) == 0;
    assert expect_int(accum["a"]) == 10;
    assert expect_int(accum["b"]) == 15;
}

test "pyc-first: next() drives one step and honors a StopIteration default" {
    stepped = run_source(
        "def two():\n"
        "    yield 1\n"
        "    yield 2\n"
        "gen = two()\n"
        "a = next(gen)\n"
        "b = next(gen)\n"
        "c = next(gen, 99)\n"
    );
    assert expect_int(stepped["a"]) == 1;
    assert expect_int(stepped["b"]) == 2;
    assert expect_int(stepped["c"]) == 99;
}

test "pyc-first: yield from delegates and captures the sub-generator return" {
    # SEND / END_SEND / GET_YIELD_FROM_ITER: `yield from inner()` re-yields each
    # of inner's values and binds inner's `return` as the yield-from result.
    delegated = run_source(
        "def inner():\n"
        "    yield 1\n"
        "    yield 2\n"
        "    return 3\n"
        "def outer():\n"
        "    r = yield from inner()\n"
        "    yield r\n"
        "result = list(outer())\n"
    );
    assert expect_int(py_subscript(delegated["result"], PyInt(t="int", val=0))) == 1;
    assert expect_int(py_subscript(delegated["result"], PyInt(t="int", val=1))) == 2;
    assert expect_int(py_subscript(delegated["result"], PyInt(t="int", val=2))) == 3;
}

test "pyc-first: yield from a plain (native) iterable re-yields its items" {
    delegated = run_source(
        "def outer():\n" "    yield from [10, 20, 30]\n" "result = list(outer())\n"
    );
    assert expect_int(py_subscript(delegated["result"], PyInt(t="int", val=0))) == 10;
    assert expect_int(py_subscript(delegated["result"], PyInt(t="int", val=2))) == 30;
}

test "pyc-first: gen.throw() raises at the suspend point for the body to catch" {
    caught = run_source(
        "def catcher():\n"
        "    try:\n"
        "        yield 1\n"
        "    except ValueError:\n"
        "        yield 2\n"
        "    yield 3\n"
        "gen = catcher()\n"
        "a = next(gen)\n"
        "b = gen.throw(ValueError)\n"
        "c = next(gen)\n"
    );
    assert expect_int(caught["a"]) == 1;
    assert expect_int(caught["b"]) == 2;
    assert expect_int(caught["c"]) == 3;
}

test "pyc-first: send() and throw() thread through yield from into the sub" {
    # Values sent into the delegating generator reach the sub-generator's yields,
    # and its return becomes the yield-from result.
    threaded = run_source(
        "def inner():\n"
        "    a = yield 1\n"
        "    b = yield a + 1\n"
        "    return b\n"
        "def outer():\n"
        "    r = yield from inner()\n"
        "    yield r\n"
        "gen = outer()\n"
        "x = next(gen)\n"
        "y = gen.send(10)\n"
        "z = gen.send(20)\n"
    );
    assert expect_int(threaded["x"]) == 1;
    assert expect_int(threaded["y"]) == 11;
    assert expect_int(threaded["z"]) == 20;

    # A throw is delegated into the sub-generator, which catches it.
    caught = run_source(
        "def inner():\n"
        "    try:\n"
        "        yield 1\n"
        "    except ValueError:\n"
        "        yield 2\n"
        "    yield 3\n"
        "def outer():\n"
        "    yield from inner()\n"
        "gen = outer()\n"
        "a = next(gen)\n"
        "b = gen.throw(ValueError)\n"
        "c = next(gen)\n"
    );
    assert expect_int(caught["a"]) == 1;
    assert expect_int(caught["b"]) == 2;
    assert expect_int(caught["c"]) == 3;
}

test "pyc-first: gen.close() finalizes; further next() reports exhaustion" {
    closed = run_source(
        "def g():\n"
        "    yield 1\n"
        "    yield 2\n"
        "gen = g()\n"
        "a = next(gen)\n"
        "gen.close()\n"
        "c = next(gen, -1)\n"
    );
    assert expect_int(closed["a"]) == 1;
    assert expect_int(closed["c"]) == -1;

    # A generator that catches GeneratorExit and returns a value: close()
    # surfaces that value (CPython 3.13+), and a second close() returns None.
    returning = run_source(
        "def f():\n"
        "    try:\n"
        "        yield\n"
        "    except GeneratorExit:\n"
        "        return 7\n"
        "gen = f()\n"
        "gen.send(None)\n"
        "first = gen.close()\n"
        "second = gen.close()\n"
    );
    assert expect_int(returning["first"]) == 7;
    assert returning["second"].t == "none";
}

test "pyc-first: async def / await drives a coroutine through the SEND path" {
    # A CO_COROUTINE-flagged def returns a coroutine on call; the body only runs
    # on drive. `await inner()` lowers to GET_AWAITABLE + the same SEND loop
    # `yield from` uses, so awaiting a native coroutine completes synchronously.
    outs = run_source(
        "async def inner():\n"
        "    return 42\n"
        "async def main():\n"
        "    x = await inner()\n"
        "    return x + 1\n"
        "c = main()\n"
    );
    coro = outs["c"];
    assert coro.t == "coroutine";
    # Driving a coroutine to completion raises StopIteration(return value), the
    # same protocol asyncio's event loop reads to collect a coroutine's result.
    done = gen_send(coro as PyGenerator, py_none());
    assert is_error(done);
    finished = (done as PyError).exception;
    assert finished.type_name == "StopIteration";
    assert expect_int(finished.value as PyObj) == 43;

    # await chains: main -> b -> a, each awaiting the next. The nested SEND loops
    # thread the returned values back up through END_SEND.
    chain = run_source(
        "async def a():\n"
        "    return 10\n"
        "async def b():\n"
        "    r = await a()\n"
        "    return r * 2\n"
        "async def main():\n"
        "    return await b()\n"
        "c = main()\n"
    );
    chained = gen_send(chain["c"] as PyGenerator, py_none());
    assert is_error(chained);
    assert expect_int((chained as PyError).exception.value as PyObj) == 20;
}

test "pyc-first: dict equality invokes element __eq__ (container compare, Track a)" {
    # dict richcompare walks keys/values through py_compare, so a user element's
    # __eq__ runs (and a raise propagates) instead of the by-hashkey model
    # silently answering. Value-level inequality is now detected, not tag-matched.
    basics = run_source(
        "a = ({1: 2} == {1: 2})\n"
        "b = ({1: 2} == {1: 3})\n"
        "c = ({1: 2} == {2: 2})\n"
        "d = ({1: 1} == {1: 1, 2: 2})\n"
        "e = ({1: 2} != {1: 3})\n"
        "f = ({} == {})\n"
    );
    assert expect_bool(basics["a"]) == True;
    assert expect_bool(basics["b"]) == False;
    assert expect_bool(basics["c"]) == False;
    assert expect_bool(basics["d"]) == False;
    assert expect_bool(basics["e"]) == True;
    assert expect_bool(basics["f"]) == True;

    # test_dict.test_eq verbatim: BadCmp hashes to 1 (colliding with int 1) and
    # its __eq__ raises, so `{BadCmp(): 1} == {1: 1}` must raise, not compare equal.
    raised = run_source(
        "class Exc(Exception): pass\n"
        "class BadCmp:\n"
        "    def __eq__(self, other): raise Exc()\n"
        "    def __hash__(self): return 1\n"
        "hit = 0\n"
        "try:\n"
        "    {BadCmp(): 1} == {1: 1}\n"
        "except Exc:\n"
        "    hit = 1\n"
    );
    assert expect_int(raised["hit"]) == 1;
}

test "pyc-first: user-defined exception classes raise and match (except UserExc)" {
    # `class Exc(Exception)` instances raise as an exception tagged with the class
    # name and match `except Exc` / `except Exception` by MRO; a raised class
    # auto-instantiates; a sibling except does not catch.
    caught = run_source(
        "class Exc(Exception): pass\n"
        "class MyErr(ValueError): pass\n"
        "a = b = c = d = 0\n"
        "try:\n"
        "    raise Exc()\n"
        "except Exc:\n"
        "    a = 1\n"
        "try:\n"
        "    raise MyErr()\n"
        "except Exception:\n"
        "    b = 1\n"
        "try:\n"
        "    raise Exc\n"
        "except Exc:\n"
        "    c = 1\n"
        "class A(Exception): pass\n"
        "class B(Exception): pass\n"
        "try:\n"
        "    try:\n"
        "        raise A()\n"
        "    except B:\n"
        "        d = 9\n"
        "except A:\n"
        "    d = 1\n"
    );
    assert expect_int(caught["a"]) == 1;
    assert expect_int(caught["b"]) == 1;
    assert expect_int(caught["c"]) == 1;
    assert expect_int(caught["d"]) == 1;
}

test "pyc-first: set literal first-value-wins + native .pop()/methods (Track d/e)" {
    # {1, 1.0, True} collapses to one member and KEEPS the first (int 1) it saw.
    lit = run_source(
        "s = {1, 1.0, True}\n"
        "n = len(s)\n"
        "popped = s.pop()\n"
        "kind = type(popped).__name__\n"
    );
    assert expect_int(lit["n"]) == 1;
    assert expect_str(lit["kind"]) == "int";

    # Native set algebra methods over arbitrary iterables.
    methods = run_source(
        "a = str(sorted({1, 2, 3}.difference([2])))\n"
        "b = str(sorted({1, 2}.union([3, 4])))\n"
        "c = str(sorted({1, 2, 3}.intersection([2, 3, 4])))\n"
        "d = {1, 2}.issubset([1, 2, 3])\n"
        "e = {1, 2}.isdisjoint([3, 4])\n"
        "s = {1, 2}\n"
        "s.update([3])\n"
        "f = str(sorted(s))\n"
    );
    assert expect_str(methods["a"]) == "[1, 3]";
    assert expect_str(methods["b"]) == "[1, 2, 3, 4]";
    assert expect_str(methods["c"]) == "[2, 3]";
    assert expect_bool(methods["d"]) == True;
    assert expect_bool(methods["e"]) == True;
    assert expect_str(methods["f"]) == "[1, 2, 3]";

    # test_set.test_issue_37219: a non-iterable difference arg is a TypeError.
    err = run_source(
        "h1 = h2 = 0\n"
        "try:\n"
        "    set().difference(123)\n"
        "except TypeError:\n"
        "    h1 = 1\n"
        "try:\n"
        "    set().difference_update(123)\n"
        "except TypeError:\n"
        "    h2 = 1\n"
    );
    assert expect_int(err["h1"]) == 1;
    assert expect_int(err["h2"]) == 1;
}

test "pyc-first: dict mutation during iteration raises RuntimeError (Track b)" {
    # A size change OR a net-zero delete+reinsert bumps the dict version, which
    # the native iterator snapshots and checks -- both raise, matching CPython.
    insert = run_source(
        "d = {}\n"
        "d[1] = 1\n"
        "hit = 0\n"
        "try:\n"
        "    for i in d:\n"
        "        d[i + 1] = 1\n"
        "except RuntimeError:\n"
        "    hit = 1\n"
    );
    assert expect_int(insert["hit"]) == 1;

    reinsert = run_source(
        "d = {}\n"
        "d[0] = 0\n"
        "hit = 0\n"
        "try:\n"
        "    for i in d:\n"
        "        del d[0]\n"
        "        d[0] = 0\n"
        "except RuntimeError:\n"
        "    hit = 1\n"
    );
    assert expect_int(reinsert["hit"]) == 1;

    # A clean iteration (no mutation) still runs to completion.
    clean = run_source(
        "d = {1: 10, 2: 20, 3: 30}\n"
        "total = 0\n"
        "for k in d:\n"
        "    total = total + k\n"
    );
    assert expect_int(clean["total"]) == 6;
}

test "pyc-first: native dict views -- set ops + element-eq compare (Track c)" {
    # keys()/items() are set-like: comparison and | & - ^ against sets/views work.
    mixed = run_source(
        "a = ({1: 1}.keys() == {1})\n"
        "b = ({1} == {1: 1}.keys())\n"
        "c = str(sorted({1: 1}.keys() | {2}))\n"
        "d = str(sorted({2} | {1: 1}.keys()))\n"
        "e = ({1: 1}.items() == {(1, 1)})\n"
        "k1 = {1: 1, 2: 2}.keys()\n"
        "k2 = {1: 1, 2: 2, 3: 3}.keys()\n"
        "f = str(sorted(k2 - k1))\n"
        "g = str(sorted(k1 & k2))\n"
    );
    assert expect_bool(mixed["a"]) == True;
    assert expect_bool(mixed["b"]) == True;
    assert expect_str(mixed["c"]) == "[1, 2]";
    assert expect_str(mixed["d"]) == "[1, 2]";
    assert expect_bool(mixed["e"]) == True;
    assert expect_str(mixed["f"]) == "[3]";
    assert expect_str(mixed["g"]) == "[1, 2]";

    # test_dict.test_errors_in_view_containment_check: an items-view comparison
    # looks up keys and compares values, so a raising element __eq__ propagates.
    raising = run_source(
        "class C:\n"
        "    def __eq__(self, other): raise RuntimeError\n"
        "d1 = {1: C()}\n"
        "d2 = {1: C()}\n"
        "eqh = neh = leh = 0\n"
        "try:\n"
        "    d1.items() == d2.items()\n"
        "except RuntimeError:\n"
        "    eqh = 1\n"
        "try:\n"
        "    d1.items() != d2.items()\n"
        "except RuntimeError:\n"
        "    neh = 1\n"
        "try:\n"
        "    d1.items() <= d2.items()\n"
        "except RuntimeError:\n"
        "    leh = 1\n"
    );
    assert expect_int(raising["eqh"]) == 1;
    assert expect_int(raising["neh"]) == 1;
    assert expect_int(raising["leh"]) == 1;

    # Mutation while iterating a values()/items() view also raises.
    mut = run_source(
        "d = {}\n"
        "d[0] = 0\n"
        "hit = 0\n"
        "try:\n"
        "    for i in d.items():\n"
        "        del d[0]\n"
        "        d[0] = 0\n"
        "except RuntimeError:\n"
        "    hit = 1\n"
    );
    assert expect_int(mut["hit"]) == 1;
}
