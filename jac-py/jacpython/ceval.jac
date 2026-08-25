# ceval + host bridge (jac-py/PLAN.md §4 module-boundary constraint).
# Callable/heap/proxy types, Layer 3 import, py_* dispatch, exec_code_frame/run_frame,
# generator machinery, Track B builtin subclassing, native set/dict methods.
# Imports the na-clean leaf (objects.jac + object-type modules) but NOT pyc_first.

# ---------------- host bridge ----------------
import marshal;

::py::
def _jac_host_error(exc):
    # Failed-bridge result carrying the ORIGINAL host exception object in slot
    # 3. Existing consumers only read slots 0..2 (host_result_ok plus the
    # type-name/message strings), so the extra slot is transparent to them --
    # but the guest-side converter (host_result_error below) can now preserve
    # the exception's identity, args, __cause__/__context__ chain, and
    # traceback instead of re-synthesizing a bare etype(message).
    return (False, type(exc).__name__, str(exc), exc)

def _jac_host_import(name, fromlist):
    import importlib
    try:
        if fromlist:
            return (True, importlib.import_module(name))
        return (True, importlib.import_module(name.split(".")[0]))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_getattr(value, name):
    try:
        return (True, getattr(value, name))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_setattr(value, name, field):
    try:
        setattr(value, name, field)
        return (True, None)
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_call(fn, args, kwargs):
    try:
        return (True, fn(*args, **kwargs), None, None)
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_dir(value):
    # Exact host dir() for values with a faithful host representation (host
    # proxies, native scalars/containers): CPython's own enumeration, so the
    # name list is byte-exact with the host interpreter.
    try:
        return (True, [str(n) for n in dir(value)])
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_type_surface(kind):
    # Unsorted __dict__ keys of a HOST type surface -- the static half of
    # CPython's dir() merge_class_dict walk (object/type/BaseException/...).
    import builtins
    import types
    try:
        target = None
        if kind == "object":
            target = builtins.object
        elif kind == "type":
            target = builtins.type
        elif kind == "function":
            target = types.FunctionType
        elif kind == "method":
            target = types.MethodType
        else:
            target = getattr(builtins, kind, None)
        if target is None:
            raise TypeError("unknown type surface '" + kind + "'")
        return (True, [str(n) for n in vars(target)])
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_type_attr(kind, name):
    # getattr on the HOST type for `kind` -- the inherited slot-wrapper surface
    # a guest class exposes through CPython's metaclass channel (type(C).__mro__
    # reaches object, whose type dict carries every slot wrapper). Companion to
    # _jac_host_type_surface, which enumerates this dict for dir(); this fetches
    # one entry's live value so `Cls.__repr__` returns the byte-exact host
    # wrapper object pprint-style dispatch tables key on.
    import builtins
    import types
    try:
        if kind == "object":
            target = builtins.object
        elif kind == "type":
            target = builtins.type
        elif kind == "function":
            target = types.FunctionType
        elif kind == "method":
            target = types.MethodType
        else:
            target = getattr(builtins, kind, None)
        if target is None:
            raise TypeError("unknown type surface '" + kind + "'")
        return (True, getattr(target, name))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_is_callable(value):
    return callable(value)

def _jac_host_getitem(value, index):
    try:
        return (True, value[index])
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_len(value):
    try:
        return (True, len(value))
    except BaseException as exc:
        return _jac_host_error(exc)

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

def _jac_is_super_type(value):
    # True iff value is exactly the builtin `super` type. Zero-arg super() at a
    # generic call site must raise CPython's frame-without-cell error instead of
    # letting the host super introspect the jaclang interpreter's own frame.
    import builtins
    return value is builtins.super

def _jac_is_range_type(value):
    # True iff value is exactly the builtin `range` type. The py_call_host ctor
    # interception must match ONLY the exact builtin -- never a subclass -- so
    # this mirrors _jac_is_object_type/_jac_is_type_type rather than routing
    # through _jac_builtin_base_name (whose membership list feeds Track B
    # subclass machinery that range must NOT join).
    return value is range

def _jac_conversion_ctor_kind(value):
    # Which conversion constructor ("int"/"float"/"bool"/"str") value is, or "".
    # Identity against the exact host builtins -- the same mechanism-level
    # idiom as _jac_is_object_type/_jac_is_range_type -- because the tp_call
    # fast path below must match ONLY the real constructors: name matching
    # (_jac_builtin_base_name) would also catch a user-defined class merely
    # named "int", and that class's instances must take their own call path.
    import builtins
    if value is builtins.int:
        return "int"
    if value is builtins.float:
        return "float"
    if value is builtins.bool:
        return "bool"
    if value is builtins.str:
        return "str"
    return ""

def _jac_is_builtin_func(value, name):
    # True iff value is EXACTLY the builtin function `name` (repr/format/print).
    # Identity, never name matching: a user-defined callable merely named
    # "repr" must keep its own call path.
    import builtins
    return value is getattr(builtins, name, None)

def _jac_is_complex_type(value):
    # True iff value is EXACTLY the builtin `complex` type -- the tp_call
    # interception must match only the real constructor, never a user class
    # merely named "complex" (same identity idiom as _jac_conversion_ctor_kind).
    import builtins
    return value is builtins.complex

def _jac_host_hashkey(value) -> str:
    # Bucket a proxied host object by its host hash so it can be a dict/set key
    # (type-keyed dispatch tables in functools/copyreg/typing/contextlib). Equal
    # host objects share a hash, hence a bucket; the dict layer confirms a bucket
    # hit with a real == (PyHostProxy needs_eq_confirm). "" means unhashable --
    # tp_hashkey turns it into the explicit PyError marker.
    try:
        return "host:" + str(hash(value))
    except BaseException:
        return ""

def _jac_host_contains(member, container):
    try:
        return (True, member in container)
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_is_notimpl(v):
    return v is NotImplemented

def _jac_host_iter(value):
    try:
        return (True, list(value))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_builtin(name):
    import builtins
    try:
        return (True, getattr(builtins, name))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_code_marshal(co):
    # A HOST code object (compile()/types.CodeType crossing the bridge as a
    # proxy) marshalled into the transport form unmarshal() turns back into a
    # native PyCode -- the exec() builtin's route for host-built code objects.
    import marshal
    try:
        return (True, marshal.dumps(co))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_source_marshal(source):
    # exec(str)/exec(bytes) source compiled on the host into the transport
    # form (native statement-mode compile is Phase C). Errors -- SyntaxError
    # above all -- come back through the tuple protocol so the guest raises a
    # CATCHABLE exception, matching CPython's exec('for = 1') contract.
    import marshal
    try:
        return (True, marshal.dumps(compile(source, "<string>", "exec")))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_type_name(value):
    return type(value).__name__

def _jac_host_id(value):
    return id(value)

def _jac_host_type(value):
    # type(value) for a host object -- the fallback for py_type_of when the
    # argument has no in-VM class (a proxied host value, or a native scalar whose
    # to_host round-trips cleanly to int/str/float/...).
    return type(value)

def _jac_host_delattr(host_obj, name):
    try:
        delattr(host_obj, name)
        return (True, None)
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_exc_chain_to_host(value):
    # __cause__/__context__ stored on a guest PyException arrive as PyException
    # value-structs; convert them to their host form before attaching to the
    # re-raised host exception. Non-exception values pass through unchanged.
    if isinstance(value, PyException):
        return host_exception(value)
    return value

def _jac_reraise_pyerror(err):
    # Surface a guest PyError to HOST control flow with maximal fidelity:
    # import-style callers of the VM must see module-body failures, never a
    # silently discarded error. The carried PyException already holds
    # everything CPython's import machinery would observe, so no synthesis:
    #   - a host-proxied exception instance keeps its ORIGINAL host object in
    #     `raw` -- raise it directly (identity/args/chaining/traceback intact);
    #   - anything else converts through host_exception, which preserves type
    #     name and the full args tuple (user Exception subclasses mint a cached
    #     same-name host subclass, the same degradation to_host uses).
    # Explicit (__cause__) and implicit (__context__) chains are re-attached so
    # `raise ... from ...` inside a module body survives the boundary.
    exc = err.exception
    raw = exc.raw
    if raw is not None and isinstance(raw, PyHostProxy):
        raise raw.val
    built = host_exception(exc)
    cause = _jac_exc_chain_to_host(exc.cause)
    if cause is not None:
        setattr(built, "__cause__", cause)
    context = _jac_exc_chain_to_host(exc.context)
    if context is not None:
        setattr(built, "__context__", context)
    raise built

def _jac_wrap_classmethod(host_fn):
    return classmethod(host_fn)

def _jac_wrap_staticmethod(host_fn):
    return staticmethod(host_fn)

def _jac_wrap_property(fget, fset, fdel):
    return property(fget, fset, fdel)

def _jac_wrap_mappingproxy(d):
    import types
    return types.MappingProxyType(d)

# Track B (builtin subclassing) host helpers.
_JAC_BUILTIN_BASES = (
    "int", "str", "float", "bool", "list", "dict",
    "tuple", "set", "frozenset", "bytes", "object",
)

def _jac_builtin_base_name(host_val) -> str:
    # If host_val is one of the subclassable builtin TYPES, return its name.
    import builtins
    if isinstance(host_val, type):
        n = getattr(host_val, "__name__", "")
        if n in _JAC_BUILTIN_BASES:
            return n
    return ""

def _jac_construct_builtin(name, raw_args):
    import builtins
    # Unknown names (a user Exception subclass) must degrade gracefully -- the
    # callers fall back to a base type instead of crashing the boundary.
    t = getattr(builtins, name, None)
    if t is None:
        return (False, "AttributeError", "module 'builtins' has no attribute '" + name + "'")
    try:
        if raw_args:
            return (True, t(*raw_args))
        return (True, t())
    except BaseException as exc:
        return _jac_host_error(exc)

# Dynamic host Exception subclass for a USER/module exception name, cached per
# name so repeated crossings keep one host class (stable repr/isinstance).
_JAC_USER_EXC_TYPES = {}
def _jac_make_exception_type(name):
    import builtins
    t = _JAC_USER_EXC_TYPES.get(name)
    if t is None:
        t = type(name, (getattr(builtins, "Exception"),), {})
        _JAC_USER_EXC_TYPES[name] = t
    return t

# Registry-aware materialization for MODULE exceptions: a registered qualified
# name (struct.error, json.JSONDecodeError, ...) mints a cached host subclass
# of its DECLARED BASE -- json.JSONDecodeError subclasses ValueError, so guest
# `except ValueError` and host isinstance both see the real hierarchy. The
# host class presents the SHORT name (CPython repr shape: struct.error shows
# as "error('...')"). Resolution order: exact builtin -> registered base ->
# generic same-name Exception subclass.
_JAC_MODULE_EXC_TYPES = {}
def _jac_make_module_exc_type(qname, base_name):
    import builtins
    short = qname.rsplit(".", 1)[-1]
    t = _JAC_MODULE_EXC_TYPES.get(qname)
    if t is None:
        base = None
        if base_name:
            bt = getattr(builtins, base_name, None)
            if isinstance(bt, type) and issubclass(bt, BaseException):
                base = bt
        if base is None:
            base = _jac_make_exception_type(short)
        t = type(short, (base,), {})
        _JAC_MODULE_EXC_TYPES[qname] = t
    return t

def _jac_instantiate_registered_exception(qname, raw_args):
    # Checked resolution (no bare getattr): builtin first, then the module
    # registry's declared base. Instantiation never raises past this boundary.
    import builtins
    t = getattr(builtins, qname, None)
    if not (isinstance(t, type) and issubclass(t, BaseException)):
        t = _jac_make_module_exc_type(qname, registered_exc_base(qname))
    try:
        if raw_args:
            return (True, t(*raw_args))
        return (True, t())
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_builtin_new(name, host_cls, raw_args):
    # builtin.__new__(host_cls, *raw_args): the host builtin constructor over a
    # HOST class (namedtuple's dynamic tuple subclass). Keeps the host subclass
    # instance intact instead of collapsing it to a native value.
    import builtins
    t = getattr(builtins, name)
    try:
        return (True, t.__new__(host_cls, *raw_args))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_builtin_new_slot(name):
    import builtins
    if name == "" or name == "object":
        return object.__new__
    return getattr(builtins, name).__new__

def _jac_isinstance_of_builtin(host_val, name) -> bool:
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

def _jac_type_has_flag(host_obj, flag_bit) -> bool:
    # Accepts BOTH shapes: a host INSTANCE (SEQUENCE/MAPPING checks inspect the
    # subject's type) and a host CLASS itself (MATCH_SELF checks inspect the
    # match pattern's own tp_flags -- type(cls).__flags__ would wrongly read
    # the metaclass).
    try:
        cls = host_obj if isinstance(host_obj, type) else type(host_obj)
        return bool(cls.__flags__ & flag_bit)
    except BaseException:
        return False

def _jac_host_pattern_name(host_val):
    # Name quoted by the MATCH_CLASS TypeError messages. A class-pattern proxy
    # wraps the HOST CLASS itself (int, str, ...), whose name is its own --
    # type(host_val).__name__ would quote the metaclass ('type') instead.
    try:
        return host_val.__name__ if isinstance(host_val, type) else type(host_val).__name__
    except BaseException:
        return "?"

def _jac_host_type_name(host_obj):
    try:
        return type(host_obj).__name__
    except BaseException:
        return "?"

def _jac_is_exception_type(host_val):
    # True iff host_val is a class deriving from BaseException (used to recognize
    # a user class like `class Exc(Exception)` whose host base proxy is here).
    return isinstance(host_val, type) and issubclass(host_val, BaseException)

def _jac_host_exception_instance(raw):
  # True with (type_name, message, args) when raw is a raised host BaseException
  # instance. Args carries the FULL constructor tuple (BaseException.args) so a
  # host-proxied exception raised through the VM keeps its arguments -- a single
  # `message` string alone made repr(e.__cause__) lose args. getattr with a
  # default cannot raise on a BaseException, so no guard is needed.
    if isinstance(raw, BaseException):
        exc_args = [from_host(a) for a in getattr(raw, "args", ())]
        return (True, type(raw).__name__, str(raw), exc_args)
    return (False, "", "", [])

def _jac_host_issubclass(host_cls, host_type) -> bool:
    try:
        return issubclass(host_cls, host_type)
    except BaseException:
        return False

def _jac_host_class_name(value):
    # The class's own __name__ (for an except-target that is an exception CLASS),
    # falling back to type(value).__name__ for a non-class value.
    return getattr(value, "__name__", None) or type(value).__name__

def _jac_exc_name_subclass(target_name, exc_name):
    # True iff a builtin exception named exc_name is target_name or a subclass of
    # it -- e.g. FileNotFoundError is-a OSError, ValueError is-a Exception. Both
    # names are resolved against builtins; user/native names not found there fall
    # back to the exact-name compare done by the caller (returns False here).
    try:
        t = getattr(builtins, target_name, None)
        e = getattr(builtins, exc_name, None)
        if (isinstance(t, type) and isinstance(e, type)
                and issubclass(t, BaseException)):
            return issubclass(e, t)
        return False
    except BaseException:
        return False

def _jac_host_format(value, spec):
    try:
        return (True, format(value, spec))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_unbound_method_info(value):
    # (True, owner_type_name, method_name) when value is an unbound builtin
    # method descriptor of a container type mirrored natively (list/dict/set).
    try:
        objclass = getattr(value, "__objclass__", None)
        if objclass is None:
            return (False, "", "")
        name = getattr(value, "__name__", "")
        if objclass in (list, dict, set):
            return (True, objclass.__name__, name)
        return (False, "", "")
    except BaseException:
        return (False, "", "")

def _jac_bound_method_type():
    # CPython: a bound method of a Python function is exactly `method`.
    class _M:
        def m(self):
            return None
    return type(_M().m)

def _jac_list_iterator_type():
    # Native PyIter mirrors list iteration; use the host list_iterator type.
    return type(iter([]))

def _jac_seq_iterator_type():
    # CPython's plain sequence iterator (PySeqIter_Type) has no reachable
    # builtin name; synthesize it from a __getitem__-only class.
    class _S:
        def __getitem__(self, i):
            raise IndexError
    return type(iter(_S()))

def _jac_builtin_function_or_method_type():
    import builtins
    # CPython: type(len) is builtin_function_or_method; grab the type object
    # itself so isinstance/name checks on native callables answer correctly.
    return type(builtins.len)

def _jac_generator_type():
    import types
    return types.GeneratorType

def _jac_coroutine_type():
    import types
    return types.CoroutineType

def _jac_async_generator_type():
    import types
    return types.AsyncGeneratorType

def _jac_host_same_object(a, b):
    return a is b

def _jac_host_eq(a, b):
    try:
        return (True, bool(a == b))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_richcompare(kind, a, b):
    import operator
    _CMP = {0: operator.lt, 1: operator.le, 2: operator.eq,
            3: operator.ne, 4: operator.gt, 5: operator.ge}
    try:
        return (True, bool(_CMP[kind](a, b)))
    except BaseException as exc:
        return _jac_host_error(exc)

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
        return _jac_host_error(exc)

def _jac_host_convert(value, conv):
    try:
        if conv == 2:
            return (True, repr(value))
        if conv == 3:
            return (True, ascii(value))
        return (True, str(value))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_module_info(absname):
    # Layer 3 module locator: resolve a fully-qualified module name to its source
    # by walking sys.path in order -- no importlib.util.find_spec, which would
    # import parent packages on the host (executing their bodies there) and leak
    # host-side module objects into the very namespace the VM must own.
    # Returns (status, source, is_pkg, origin, detail):
    #   "py"          -> pure-Python module/package; `source` is its text, run
    #                    in-VM proxy-free
    #   "native"      -> built-in / frozen / C extension / namespace package:
    #                    nothing to run in-VM; caller host-proxies it
    #   "missing"     -> ModuleNotFoundError("No module named '<absname>'")
    #   "not-package" -> ModuleNotFoundError(detail) where detail is CPython's
    #                    "No module named '<abs>'; '<parent>' is not a package"
    import os
    import sys
    import _imp
    import importlib.machinery as machinery
    parts = absname.split(".")
    if _imp.is_builtin(parts[0]):
        return ("native", "", False, "", "")
    # Frozen-but-with-source modules (abc, _collections_abc are frozen into the
    # 3.10+ bootstrap): CPython prefers the frozen copy for STARTUP, but our
    # guest must boot the REAL Lib source -- a host-proxied frozen module hands
    # back host class objects (ABCMeta as PyHostProxy), which class_mro then
    # excludes (non-PyClass bases are not MRO nodes), collapsing every
    # metaclass chain built on them: `class P(metaclass=_PM(ABCMeta))` lost its
    # entire ancestry and `import typing` died in _ProtocolMeta.__init__.
    # Unfreeze-by-name so the sys.path walk below finds Lib/abc.py and boots it
    # in-VM. Extend the set only with a fresh conv-pipe diff pass.
    if _imp.is_frozen(parts[0]) and parts[0] != "abc":
        return ("native", "", False, "", "")

    def locate(base_dir, part):
        # One directory scan: regular package > plain module > extension >
        # namespace portion. Returns (kind, payload) or None.
        pkg_dir = os.path.join(base_dir, part)
        init_py = os.path.join(pkg_dir, "__init__.py")
        if os.path.isfile(init_py):
            return ("pkg", pkg_dir)
        mod_py = os.path.join(base_dir, part + ".py")
        if os.path.isfile(mod_py):
            return ("py", mod_py)
        for suf in machinery.EXTENSION_SUFFIXES:
            ext = os.path.join(base_dir, part + suf)
            if os.path.isfile(ext):
                return ("ext", ext)
        if os.path.isdir(pkg_dir):
            return ("ns", pkg_dir)
        return None

    def read_source(path):
        try:
            with open(path, "r", encoding="utf-8") as fh:
                return fh.read()
        except OSError:
            return None

    def finish(kind, payload):
        if kind == "pkg":
            src = read_source(os.path.join(payload, "__init__.py"))
            if src is not None:
                return ("py", src, True, os.path.join(payload, "__init__.py"), "")
            return ("native", "", True, payload, "")
        if kind == "py":
            src = read_source(payload)
            if src is not None:
                return ("py", src, False, payload, "")
            return ("native", "", False, payload, "")
        return ("native", "", False, "", "")

    # Top-level scan: first regular hit across sys.path wins; the first
    # namespace portion is remembered in case no regular hit exists anywhere
    # (CPython's namespace-package rule).
    top = None
    ns_portion = None
    for entry in sys.path:
        d = entry or os.getcwd()
        if not os.path.isdir(d):
            continue
        hit = locate(d, parts[0])
        if hit is None:
            continue
        if hit[0] == "ns":
            if ns_portion is None:
                ns_portion = hit[1]
        elif top is None:
            top = hit
    if top is None:
        # Namespace packages have no body to run in-VM; hand them to the host
        # importer, which resolves their full __path__ the same way.
        if ns_portion is not None:
            return ("native", "", True, ns_portion, "")
        return ("missing", "", False, "", "")
    if len(parts) == 1:
        return finish(top[0], top[1])
    # Descend through subpackages. A non-package parent anywhere along the chain
    # yields CPython's "... is not a package" variant.
    loc = top
    depth = 1
    while depth < len(parts):
        if loc[0] != "pkg":
            return (
                "not-package", "", False, "",
                "No module named '" + absname + "'; '"
                    + ".".join(parts[:depth]) + "' is not a package",
            )
        nxt = locate(loc[1], parts[depth])
        if nxt is None:
            return ("missing", "", False, "", "")
        loc = nxt
        depth = depth + 1
    return finish(loc[0], loc[1])

def _jac_sys_modules_lookup(absname):
    # sys.modules-first rule (CPython _find_and_load checks the registry before
    # every path finder): a module body can register a submodule ALIAS at exec
    # time that exists nowhere on disk. CPython 3.14 removed Lib/collections/
    # abc.py; collections/__init__.py does
    #     _sys.modules['collections.abc'] = _collections_abc
    # so `import collections.abc` resolves through the registry, not a file.
    # Returns ("hit", module) / ("absent", "") / ("error", type, message).
    import sys
    try:
        mod = sys.modules.get(absname)
    except BaseException as exc:
        return _jac_host_error(exc)
    if mod is None:
        return ("absent", "")
    return ("hit", mod)

def _jac_star_names(host_val):
    # `from proxied_module import *` name set: __all__ if defined, else every
    # public (non-underscore) attribute -- CPython's import_all_from rule.
    try:
        alln = getattr(host_val, "__all__", None)
        if alln is not None:
            return (True, [str(n) for n in alln])
        return (True, [n for n in dir(host_val) if not n.startswith("_")])
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_dir_names(value):
    # Every attribute name on a host module (full dir(), not the __all__/
    # public-only view _jac_star_names serves for star-imports). The stdlib
    # delegation registry snapshots the complete surface so underscored API
    # (re._compile, datetime's C internals) stays reachable, matching dir()
    # on a real host module.
    try:
        return (True, [n for n in dir(value)])
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_make_live_ns_view(proxy):
    # Live host view over a guest namespace (PyGlobalsProxy crossing to
    # host-delegated code): CPython hands the LIVE module dict, so reads route
    # through mp_subscript (KeyError-faithful) and writes through
    # mp_ass_subscript -- host-side mutations land in the guest ns and guest
    # writes stay visible to the host. A Mapping (not a dict subclass)
    # because the storage is the Jac name->PyObj table, not a host dict;
    # documented deltas: no del support (the proxy has no delete protocol)
    # and isinstance(x, dict) is False.
    import collections.abc
    class _LiveNsView(collections.abc.Mapping):
        def __getitem__(self, k):
            r = proxy.mp_subscript(PyStr(t="str", val=k))
            if isinstance(r, PyError):
                raise KeyError(k)
            return to_host(r)
        def __setitem__(self, k, v):
            proxy.mp_ass_subscript(PyStr(t="str", val=k), from_host(v))
        def __contains__(self, k):
            return isinstance(k, str) and k in proxy.ns
        def __iter__(self):
            return iter(list(proxy.ns.keys()))
        def __len__(self):
            return len(proxy.ns)
        def __repr__(self):
            return repr(dict(self))
        get = collections.abc.Mapping.get
    return _LiveNsView()

def _jac_make_live_list(pylist):
    # Live host view over a guest PyList crossing to host code (fp-e87c live-
    # view cluster): reads route through mp_subscript, writes through
    # mp_ass_subscript / the raw items table -- host mutations land in the
    # guest list and guest appends stay visible to the host. A MutableSequence
    # (not a list subclass) because the storage is the Jac PyObj items table,
    # not a host list; documented deltas: isinstance(x, list) is False, ==
    # against a real list falls back to identity (Sequence defines no __eq__),
    # and __iter__ walks by index through mp_subscript so it reflects appends
    # made during iteration instead of snapshotting.
    import collections.abc
    class _LiveListView(collections.abc.MutableSequence):
        def __getitem__(self, i):
            r = pylist.mp_subscript(from_host(i))
            if isinstance(r, PyError):
                _jac_reraise_pyerror(r)
            return to_host(r)
        def __setitem__(self, i, v):
            r = pylist.mp_ass_subscript(from_host(i), from_host(v))
            if isinstance(r, PyError):
                _jac_reraise_pyerror(r)
        def __delitem__(self, i):
            # PyList carries mp_del_subscript, so del works here (unlike the ns
            # view, whose proxy has no delete protocol).
            r = pylist.mp_del_subscript(from_host(i))
            if isinstance(r, PyError):
                _jac_reraise_pyerror(r)
        def __len__(self):
            return len(pylist.items)
        def __iter__(self):
            i = 0
            while True:
                r = pylist.mp_subscript(PyInt(t="int", val=i))
                if isinstance(r, PyError):
                    return
                yield to_host(r)
                i = i + 1
        def insert(self, i, v):
            # CPython list.insert clamps out-of-range positions; do the same on
            # the backing table (MutableSequence.append routes through here).
            n = len(pylist.items)
            if i < 0:
                i = max(0, n + i)
            else:
                i = min(i, n)
            pylist.items.insert(i, from_host(v))
        def __repr__(self):
            return repr([x for x in self])
    return _LiveListView()

def _jac_make_live_dict(pydict):
    # Live host view over a guest PyDict: same contract as _jac_make_live_list.
    # Errors re-raise through _jac_reraise_pyerror so KeyError/IndexError carry
    # the exact guest type+args (KeyError('k'), "unhashable type") instead of a
    # resynthesized message. __contains__/get inherit from MutableMapping, whose
    # try-getitem shape propagates TypeError for unhashable keys like CPython.
    import collections.abc
    class _LiveDictView(collections.abc.MutableMapping):
        def __getitem__(self, k):
            r = pydict.mp_subscript(from_host(k))
            if isinstance(r, PyError):
                _jac_reraise_pyerror(r)
            return to_host(r)
        def __setitem__(self, k, v):
            r = pydict.mp_ass_subscript(from_host(k), from_host(v))
            if isinstance(r, PyError):
                _jac_reraise_pyerror(r)
        def __delitem__(self, k):
            r = pydict.mp_del_subscript(from_host(k))
            if isinstance(r, PyError):
                _jac_reraise_pyerror(r)
        def __iter__(self):
            return iter([to_host(k) for k in pydict.dict_keys()])
        def __len__(self):
            return len(pydict.items)
        def __repr__(self):
            return repr(dict(self))
    return _LiveDictView()

def _jac_make_live_set(pyset):
    # Live host view over a guest MUTABLE PySet (frozensets never cross here --
    # the dispatcher refuses them): MutableSet's add/discard/contains surface.
    import collections.abc
    class _LiveSetView(collections.abc.MutableSet):
        def __contains__(self, v):
            return pyset.set_contains(from_host(v))
        def __iter__(self):
            return iter([to_host(m) for m in pyset.set_members()])
        def __len__(self):
            return len(pyset.items)
        def add(self, v):
            r = pyset.set_add(from_host(v))
            if isinstance(r, PyError):
                _jac_reraise_pyerror(r)
        def discard(self, v):
            r = pyset.set_discard(from_host(v))
            if isinstance(r, PyError):
                _jac_reraise_pyerror(r)
        def __repr__(self):
            return repr(set(self))
    return _LiveSetView()

def _jac_make_host_trampoline(native_fn):
    # Native-callable -> host round-trip. When a native PyFunction crosses the
    # host boundary (to_host), it can't become None -- host machinery that wraps
    # or invokes it (type(name, bases, ns) installing a native __repr__, a
    # classmethod/property over a native function, functools.partial, a callback
    # handed to a proxied C module) needs a REAL callable. Return a host closure
    # that marshals host args back into PyObjs, runs the function in jacpython's
    # own ceval via tp_call, and marshals the result back out. A raised PyError
    # is re-raised with its original object/args/chaining intact so host
    # control flow sees it.
    def _trampoline(*args, **kwargs):
        pyargs = [from_host(a) for a in args]
        pykwargs = {}
        for k in kwargs:
            pykwargs[k] = from_host(kwargs[k])
        result = native_fn.tp_call(pyargs, pykwargs)
        if isinstance(result, PyError):
            _jac_reraise_pyerror(result)
        return to_host(result)
    # Present as the wrapped function so introspection (functools.wraps,
    # type()'s method registration, repr) sees the right identity. Keep a
    # back-pointer so a round-trip (from_host of this trampoline) recovers the
    # native function instead of re-wrapping it as an opaque proxy.
    try:
        _trampoline.__name__ = native_fn.name
        # PyFunction carries code/_func_doc; other callables (PyNativeBuiltin,
        # bound/method wrappers) only carry .name.
        if hasattr(native_fn, "code"):
            _trampoline.__qualname__ = native_fn.code.qualname
            doc = native_fn._func_doc()
            _trampoline.__doc__ = doc.val if isinstance(doc, PyStr) else None
        else:
            _trampoline.__qualname__ = native_fn.name
        _trampoline.__jac_native__ = native_fn
    except BaseException:
        pass
    return _trampoline

def _jac_make_weakref(target):
    # Host weakref over the RAW jacpython object. PyUserObj/PyClass/native
    # wrappers are ordinary CPython objects, so the host weakref tracks their
    # exact refcount lifetime: when the last strong reference dies, ref()
    # returns None with no extra bookkeeping. Returns None on TypeError.
    import weakref
    try:
        return weakref.ref(target)
    except TypeError:
        return None

def _jac_weakref_deref(wr):
    return wr()

def _jac_dbg_dead_check_simple(r):
    # Minimal: alive or dead, no walking.
    import sys
    wr = getattr(r, "wr")
    return wr() is None

def _jac_recover_native(raw) -> PyObj | None:
    # If raw is a trampoline we minted, hand back the native function it wraps
    # so a host->native round-trip collapses instead of nesting proxies. Read the
    # marker from the object's OWN __dict__, not via getattr: a bound method
    # delegates attribute access to its __func__, so getattr(bound_method,
    # '__jac_native__') would unwrap it to the UNBOUND native function and lose
    # the receiver -- exactly what breaks `instance.method()`.
    import types as _types
    if isinstance(raw, _types.FunctionType):
        return raw.__dict__.get("__jac_native__")
    d = getattr(raw, "__dict__", None)
    if isinstance(d, dict):
        coro = d.get("__jac_native_coroutine__")
        if coro is not None:
            return coro
    return None

# ---- typed-boundary stand-ins and lazy iterators ---------------------------
# Bridge-table support (see to_host_policy in this file):
#
# STANDIN: a guest PyClass or plain PyUserObj crossing to the host gets a
# NAME-FAITHFUL cached host stand-in -- never None. The minted host class
# carries the guest class's name and bases; instances keep a back-reference so
# from_host recovers the ORIGINAL guest object (identity round-trip) and so
# guest-defined __str__/__repr__ run through the VM.
#
# LAZY_ITER: a native iterator/generator crossing to the host becomes a lazy
# host iterator that pulls ONE step per __next__ through the same tp_iternext
# helpers FOR_ITER uses. Position stays SHARED with the guest object, so host
# consumption no longer drains/consumes the underlying iterator silently.

_JAC_CLASS_STANDINS = {}   # id(guest_cls) -> [weakref.ref(cls), host_class]
_JAC_USER_STANDINS = {}    # id(user_obj) -> [weakref.ref(obj), standin_instance]

_JAC_ITER_DONE = object()  # sentinel for iter(callable, sentinel)


def _jac_notimpl_value():
    # VALUE_COPY for the native richcompare-deferral sentinel: the host sees the
    # real NotImplemented singleton (previously a silent None fallthrough).
    return NotImplemented


def _jac_standin_bases(cls):
    # Resolve guest base declarations to host classes for type() minting.
    # Unresolvable bases are skipped; if nothing resolves, `object` is used.
    import builtins
    import weakref
    bases = []
    for b in cls.bases:
        hb = None
        if isinstance(b, PyClass):
            hb = _jac_standin_class(b)
        elif isinstance(b, PyExceptionType):
            t = getattr(builtins, b.name, None)
            if isinstance(t, type) and issubclass(t, BaseException):
                hb = t
        elif isinstance(b, PyHostProxy) and isinstance(b.val, type):
            hb = b.val
        if hb is not None and hb not in bases and hb is not object:
            bases.append(hb)
    if not bases:
        return (object,)
    try:
        probe = type("_probe", tuple(bases), {})
    except TypeError:
        return (bases[0],)
    return tuple(bases)


def _jac_standin_dunder(dunder_name, vm_fn):
    # Host method that replays a guest dunder through the VM on the ORIGINAL
    # user object recovered from the stand-in's back-reference.
    def _meth(self, *args):
        u = getattr(self, "_jac_guest_", None)
        if u is None:
            raise RuntimeError(
                "bridge-table: stand-in lost its guest back-reference"
            )
        res = vm_fn(u)
        if isinstance(res, PyError):
            _jac_reraise_pyerror(res)
        return to_host(res)
    _meth.__name__ = dunder_name
    return _meth


def _jac_standin_class(cls):
    # The cached name-faithful host class for a guest PyClass.
    import weakref
    key = id(cls)
    ent = _JAC_CLASS_STANDINS.get(key)
    if ent is not None and ent[0]() is cls:
        return ent[1]
    ns = {}
    r = class_lookup_attr(cls, "__repr__")
    if not is_error(r):
        ns["__repr__"] = _jac_standin_dunder("__repr__", py_repr)
    s = class_lookup_attr(cls, "__str__")
    if not is_error(s):
        ns["__str__"] = _jac_standin_dunder("__str__", py_str)
    if class_has_abc_meta(cls):
        _jac_install_abc_trampolines()
        host_cls = _JacABCMeta(cls.name, _jac_standin_bases(cls), ns)
    else:
        host_cls = type(cls.name, _jac_standin_bases(cls), ns)
    host_cls._jac_guest_cls_ = cls
    _JAC_CLASS_STANDINS[key] = [weakref.ref(cls), host_cls]
    return host_cls


def _jac_user_standin(u):
    # The cached name-faithful host instance for a plain guest PyUserObj.
    import weakref
    key = id(u)
    ent = _JAC_USER_STANDINS.get(key)
    if ent is not None and ent[0]() is u:
        return ent[1]
    host_cls = _jac_standin_class(u.cls)
    inst = host_cls.__new__(host_cls)
    # Strong back-reference: while the host holds the stand-in, the guest
    # object stays alive and recoverable (identity round-trip).
    inst._jac_guest_ = u
    _JAC_USER_STANDINS[key] = [weakref.ref(u), inst]
    return inst


class _JacABCMeta(type):
    # Metaclass for standins of guest classes whose metaclass chain derives
    # from in-VM ABCMeta. Host C ABCMeta.__subclasscheck__ cannot traverse a
    # guest PyClass MRO (returns False even for direct ancestry), which killed
    # typing._ProtocolMeta.__new__ (issubclass(base, Generic) gate). These
    # overrides recover the guest objects and run the test in ceval; when
    # either side is not recoverable (pure host type like int) they fall back
    # to plain type semantics.
    def __subclasscheck__(cls, other):
        g = cls.__dict__.get("_jac_guest_cls_")
        gother = _jac_recover_guest(other)
        if g is None or gother is None:
            return super().__subclasscheck__(other)
        fn = _JAC_ABC_TRAMPOLINES[0]
        return bool(fn(g, gother))

    def __instancecheck__(cls, instance):
        g = cls.__dict__.get("_jac_guest_cls_")
        ginst = _jac_recover_guest(instance)
        if g is None or ginst is None:
            return super().__instancecheck__(instance)
        fn = _JAC_ABC_TRAMPOLINES[1]
        return bool(fn(ginst, g))


# [guest-issubclass trampoline, guest-isinstance trampoline] -- filled lazily
# by _jac_install_abc_trampolines on first ABC standin mint.
_JAC_ABC_TRAMPOLINES = [None, None]


def _jac_install_abc_trampolines():
    if _JAC_ABC_TRAMPOLINES[0] is None:
        _JAC_ABC_TRAMPOLINES[0] = _jac_make_host_trampoline(
            PyNativeBuiltin(t="native_builtin", name="issubclass")
        )
        _JAC_ABC_TRAMPOLINES[1] = _jac_make_host_trampoline(
            PyNativeBuiltin(t="native_builtin", name="isinstance")
        )


def _jac_standin_mro_covers(guest_cls, host_typ):
    # True iff any node of the guest class's MRO, once minted as a host
    # standin, is host_typ or subclasses it. Lets issubclass(instance-of-guest,
    # HOST-PROXIED type) answer through real host semantics instead of the
    # builtin-name fallback (which only knows int/str/list/...).
    try:
        mro = class_mro(guest_cls)
    except BaseException:
        return False
    for k in mro:
        try:
            hk = _jac_standin_class(k)
            if hk is host_typ or issubclass(hk, host_typ):
                return True
        except BaseException:
            continue
    return False


def _jac_hostproxy_val_is_type(val):
    # Returns the raw value if it is a host type, else "" (sentinel usable
    # from native callers without optional returns).
    import types as _types
    if isinstance(val, type):
        return val
    return ""


def _jac_recover_guest(raw):
    # from_host hook: a stand-in crossing BACK yields the original guest object
    # (class or instance). Cheaply gated on the marker living in __dict__/type.
    if isinstance(raw, type):
        g = raw.__dict__.get("_jac_guest_cls_")
        if g is not None:
            return g
        return None
    d = getattr(raw, "__dict__", None)
    if d is not None:
        return d.get("_jac_guest_")
    return None


def _jac_make_host_iterator(value):
    # LAZY_ITER policy: one host iterator pulling single steps out of the
    # native iterator/generator via the shared tp_iternext helpers, so guest
    # and host observe the SAME position and neither side silently drains it.
    def _next():
        step = send_into(value, py_none())
        if isinstance(step, PyGenStop):
            raise StopIteration
        if isinstance(step, PyError):
            exc = step.exception
            if exc_name_matches(exc.type_name, "StopIteration"):
                raise StopIteration
            _jac_reraise_pyerror(step)
        return to_host(step)
    return iter(_next, _JAC_ITER_DONE)

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

def _jac_host_val_is_type(val):
    return isinstance(val, type)


def _jac_host_type_mro(val):
    return type(val).mro(val)[:-1]


def _jac_host_val_is_object_type(val):
    return val is object


def _jac_host_val_same(a, b):
    return a is b


def _jac_drive_native(gen_obj, method_name, args):
    # Call a PyGenMethod driver (send/throw/close/...) on the native PyGenerator
    # and translate the outcome to HOST control flow: a yielded value converts
    # through to_host; normal completion (PyGenStop, e.g. a throw the guest
    # caught and returned from) re-raises StopIteration with the return value;
    # an explicit StopIteration error carries the coroutine's result payload;
    # any other guest error re-raises with its original object/args/chaining.
    m = gen_obj.tp_getattro(method_name)
    result = m.tp_call(args, {})
    if isinstance(result, PyError):
        exc = result.exception
        if exc.type_name == "StopIteration":
            raise StopIteration(to_host(exc.value))
        _jac_reraise_pyerror(result)
    if hasattr(result, "t") and result.t == "genstop":
        raise StopIteration(to_host(result.val))
    return to_host(result)


def _jac_host_exc_instance(exc):
    # Normalize throw() input to an exception INSTANCE, CPython-style: an
    # exception class is instantiated with no args; (exc, value) legacy forms
    # collapse to their first member.
    if isinstance(exc, BaseException):
        return exc
    if isinstance(exc, type) and issubclass(exc, BaseException):
        return exc()
    if isinstance(exc, tuple) and len(exc) > 0:
        return _jac_host_exc_instance(exc[0])
    raise TypeError("exceptions must derive from BaseException")


class coroutine:
    # Host face of a jacpython-native coroutine. Presents the real CPython
    # coroutine surface -- send/throw/close/__await__, type name `coroutine` --
    # so host asyncio (Task, Runner.run, ensure_future all gate on
    # asyncio.iscoroutine) drives it natively. Every drive marshals into frame
    # resumption on the guest side (gen_send/gen_throw/gen_close); nothing is
    # drained or copied.
    def __init__(self, gen_obj):
        self.__jac_native_coroutine__ = gen_obj

    def __repr__(self):
        native = self.__jac_native_coroutine__
        qual = ""
        try:
            qual = str(native.frame.co.qualname)
        except BaseException:
            pass
        return f"<coroutine object {qual}>"

    def send(self, value=None):
        try:
            started = bool(self.__jac_native_coroutine__.started)
        except BaseException:
            started = True
        if not started and value is not None:
            raise TypeError(
                "can't send non-None value to a just-started coroutine"
            )
        return _jac_drive_native(
            self.__jac_native_coroutine__, "send", [from_host(value)]
        )

    def throw(self, exc, value=None, tb=None):
        return _jac_drive_native(
            self.__jac_native_coroutine__,
            "throw",
            [from_host(_jac_host_exc_instance(exc))],
        )

    def close(self):
        try:
            return _jac_drive_native(
                self.__jac_native_coroutine__, "close", []
            )
        except StopIteration:
            return None

    def __await__(self):
        # Coroutine-protocol iterator: yield each suspended value up to the
        # driver, resume with what comes back, return StopIteration.value.
        sent = None
        while True:
            try:
                yielded = self.send(sent)
            except StopIteration as e:
                return e.value
            sent = yield yielded


try:
    import collections.abc as _cabc

    _cabc.Coroutine.register(coroutine)
except BaseException:
    pass


def _jac_make_guest_coroutine(gen_obj):
    return coroutine(gen_obj)


def _jac_host_resolve_awaitable(raw):
    # GET_AWAITABLE's host half (CPython semantics): an object with a native
    # coroutine/generator send/throw surface is driven directly; anything else
    # must expose __await__(), which is CALLED and must return an iterator.
    # Returns (ok, drivable, msg): ok=1 -> drive `drivable`; ok=0 -> raise
    # TypeError(msg), already composed byte-exact.
    import types as _types
    bad = f"object {type(raw).__name__} can't be used in 'await' expression"
    if isinstance(raw, (_types.CoroutineType, _types.GeneratorType)):
        return (1, raw, "")
    aw = getattr(type(raw), "__await__", None)
    if aw is None:
        return (0, None, bad)
    try:
        it = raw.__await__()
    except BaseException as exc:
        return (0, None, str(exc))
    try:
        iter(it)
    except BaseException:
        return (0, None,
            f"__await__() returned non-iterator of type '{type(it).__name__}'")
    return (1, it, "")


def _jac_make_guest_async_generator(agen_obj):
    # Host face of a native async generator: __aiter__/__anext__/aclose with
    # real awaitables, so host `async for` and contextlib.aclosing drive it.
    agen = agen_obj

    class _JacGuestANext:
        def __init__(self, step_fn):
            self._step = step_fn

        def __await__(self):
            # Drive one guest step at a time; suspend on guest yields so host
            # awaits inside the generator body propagate to the driver, and
            # forward throws raised by the driver into the guest frame.
            sent = None
            pending_throw = None
            while True:
                if pending_throw is not None:
                    thrown, pending_throw = pending_throw, None
                    outcome = self._step("throw", thrown)
                else:
                    outcome = self._step("send", sent)
                kind = outcome[0]
                if kind == "item":
                    return outcome[1]
                if kind == "done":
                    raise StopAsyncIteration(outcome[1])
                try:
                    sent = yield outcome[1]
                except BaseException as exc:
                    pending_throw = exc

    class _JacGuestAsyncGenerator:
        def __init__(self, gen_obj):
            self.__jac_native_coroutine__ = gen_obj

        def __repr__(self):
            return "<async_generator object>"

        def __aiter__(self):
            return self

        def __anext__(self):
            return _JacGuestANext(self._drive_anext)

        def aclose(self):
            return _JacGuestANext(self._drive_aclose)

        def _drive_anext(self, mode, payload):
            if mode == "throw":
                err = gen_throw(agen, from_host(payload))
            else:
                err = gen_send(agen, from_host(payload))
            if isinstance(err, PyError):
                exc = err.exception
                if exc.type_name == "StopIteration":
                    return ("done", to_host(exc.value))
                _jac_reraise_pyerror(err)
            if hasattr(err, "t") and err.t == "genstop":
                return ("done", None)
            if isinstance(err, PyAsyncGenWrappedValue):
                # A wrapped yield is the async-gen ITEM: this anext awaitable
                # completes with it (CPython async_generator_asend semantics).
                return ("item", to_host(err.val))
            return ("yield", to_host(err))

        def _drive_aclose(self, mode, payload):
            result = gen_close(agen)
            if isinstance(result, PyError):
                _jac_reraise_pyerror(result)
            return ("done", None)

    return _JacGuestAsyncGenerator(agen)
::py::



import from marshal_reader { unmarshal, bytes_to_str }

# Bootstrap transport duplicate (pyc_first.jac keeps the canonical copy for re-export).
def host_compile_marshal(source: str) -> list[int] {
    raw = marshal.dumps(compile(source, "<jacpython-host>", "exec"));
    return raw as list[int];
}

# The object core -- the PyObj data-type hierarchy, value/container slots, and
# pure helpers -- lives in the na-clean leaf `objects.jac`. This module (the
# ceval + host bridge + marshal transport) imports it and adds the callable/
# heap/proxy types that OVERRIDE the call/attr slots (cross-module inheritance),
# because those slots re-enter the interpreter or the host and so cannot live in
# the acyclic leaf. See PLAN.md §4 (module-boundary constraint).
import from hash_dispatch { hash_element, }
import from objects {
    Py_EQ,
    Py_LE,
    Py_GE,
    PyObject_RichCompare,
    PyObject_RichCompareBool,
    py_ordering_type_error,
    _base_type_name,
    _uint_to_str,
}
import from abstract_protocol {
    PyObject_GetIter,
    PyIter_Check,
    PyObject_Hash,
    PyObject_HashNotImplemented,
}
import from rangeobject { get_len_of_range, range_contains_longs, range_equals_longs, }
import from type_slots {
    type_slots_attr_allowed,
    type_slots_mangle,
    type_slots_member_repr,
    type_slots_merge_names,
    type_slots_has_dict,
    type_slots_in_dict_view,
}
import from tupleobject { tuple_hash, tuple_richcompare, }
import from longobject { long_hash_obj, int_repr, }
import from setobject { set_hash_obj, set_richcompare, }
import from typeobject {
    type_repr,
    type_richcompare,
    type_richcompare_same,
    type_tp_name,
    type_ready,
    Py_TPFLAGS_READY,
}
import from bytesobject { bytes_hash_obj, bytes_richcompare, bytes_repr, }
import from strobject { str_repr, }
import from floatobject { float_repr, }
import from complexobject { complex_repr_text, complex_parse_text, }
import from listobject { list_richcompare, list_repr, }
import from dictobject { dict_richcompare, dict_repr, }
import from exceptions_core {
    exc_name_matches,
    baseexception_str,
    baseexception_repr,
    prep_reraise_star,
    registered_exc_base,
}
import from objects { exc_is_subclass_of }
import from tb_render { tb_display_error, }
import from tracebackmodule { traceback_module_attrs, format_exception_text, tb_write_bound, _tb_shim_type_tags }
import from objects {
    _zero_step_error,
    DictEntry,
    _unhashable_error,
    slice_indices,
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
    PyTypeAlias,
    PyTypeVar,
    PyDict,
    PyDictIter,
    PySet,
    PySeqIter,
    PyExceptionType,
    PyExcGroup,
    PyException,
    PyError,
    PyTraceback,
    PyIter,
    PyCallableIter,
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
    py_error_with_args,
    py_exception_type,
    PyNotImplementedSentinel,
    is_builtin_exception_name,
    dict_key_repr,
    _pyobj_repr,
    _repr_unicode_escape,
    str_mod_format,
    is_error,
    hashkey_str,
    PY_NOT_IMPLEMENTED
}
import from opcode_meta {
    OP_CACHE,
    OP_RESUME,
    OP_LOAD_BUILD_CLASS,
    OP_LOAD_LOCALS,
    OP_LOAD_FROM_DICT_OR_DEREF,
    OP_LOAD_FROM_DICT_OR_GLOBALS,
    OP_NOT_TAKEN,
    OP_SETUP_ANNOTATIONS,
    OP_POP_TOP,
    OP_PUSH_EXC_INFO,
    OP_PUSH_NULL,
    OP_RETURN_VALUE,
    OP_BINARY_SLICE,
    OP_BUILD_SLICE,
    OP_STORE_SLICE,
    OP_CHECK_EG_MATCH,
    OP_STORE_SUBSCR,
    OP_UNARY_NOT,
    OP_WITH_EXCEPT_START,
    OP_BINARY_OP,
    NB_REMAINDER,
    NB_AND,
    NB_INPLACE_ADD,
    NB_INPLACE_AND,
    NB_INPLACE_MULTIPLY,
    NB_INPLACE_OR,
    NB_INPLACE_SUBTRACT,
    NB_INPLACE_XOR,
    NB_MULTIPLY,
    NB_OR,
    NB_SUBTRACT,
    NB_XOR,
    OP_BUILD_LIST,
    OP_BUILD_MAP,
    OP_BUILD_TUPLE,
    OP_CALL,
    OP_CALL_KW,
    OP_COMPARE_OP,
    OP_COPY,
    OP_COPY_FREE_VARS,
    OP_END_FOR,
    OP_END_ASYNC_FOR,
    OP_GET_AITER,
    OP_GET_ANEXT,
    OP_GET_ITER,
    OP_IMPORT_FROM,
    OP_IMPORT_NAME,
    OP_IS_OP,
    OP_JUMP_BACKWARD,
    OP_JUMP_BACKWARD_NO_INTERRUPT,
    OP_JUMP_FORWARD,
    OP_LIST_APPEND,
    OP_SET_ADD,
    OP_LIST_EXTEND,
    OP_LOAD_ATTR,
    OP_LOAD_SUPER_ATTR,
    OP_LOAD_CONST,
    OP_LOAD_DEREF,
    OP_LOAD_CLOSURE,
    OP_LOAD_FAST,
    OP_LOAD_FAST_BORROW,
    OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW,
    OP_LOAD_FAST_CHECK,
    OP_LOAD_FAST_LOAD_FAST,
    OP_LOAD_GLOBAL,
    OP_LOAD_NAME,
    OP_LOAD_SMALL_INT,
    OP_LOAD_SPECIAL,
    OP_MAKE_CELL,
    OP_MAKE_FUNCTION,
    OP_POP_JUMP_IF_FALSE,
    OP_POP_JUMP_IF_NONE,
    OP_POP_JUMP_IF_NOT_NONE,
    OP_POP_JUMP_IF_TRUE,
    OP_RAISE_VARARGS,
    OP_RERAISE,
    OP_SET_FUNCTION_ATTRIBUTE,
    OP_STORE_ATTR,
    OP_DELETE_ATTR,
    OP_DELETE_DEREF,
    OP_STORE_DEREF,
    OP_STORE_FAST,
    OP_DELETE_FAST,
    OP_STORE_NAME,
    OP_STORE_GLOBAL,
    OP_DELETE_GLOBAL,
    OP_DELETE_NAME,
    OP_SWAP,
    OP_CHECK_EXC_MATCH,
    OP_POP_EXCEPT,
    OP_BUILD_SET,
    OP_SET_UPDATE,
    OP_CONVERT_VALUE,
    OP_FORMAT_SIMPLE,
    OP_FORMAT_WITH_SPEC,
    OP_BUILD_STRING,
    OP_RETURN_GENERATOR,
    OP_YIELD_VALUE,
    OP_STORE_FAST_LOAD_FAST,
    OP_TO_BOOL,
    OP_CONTAINS_OP,
    OP_LOAD_COMMON_CONSTANT,
    OP_CALL_INTRINSIC_1,
    OP_CALL_INTRINSIC_2,
    OP_LOAD_FAST_AND_CLEAR,
    OP_SEND,
    OP_END_SEND,
    OP_GET_YIELD_FROM_ITER,
    OP_GET_AWAITABLE,
    OP_CLEANUP_THROW,
    OP_UNARY_NEGATIVE,
    OP_UNARY_INVERT,
    OP_UNPACK_SEQUENCE,
    OP_UNPACK_EX,
    OP_GET_LEN,
    OP_MATCH_SEQUENCE,
    OP_MATCH_MAPPING,
    OP_MATCH_KEYS,
    OP_MATCH_CLASS,
    OP_DELETE_SUBSCR,
    OP_MAP_ADD,
    OP_DICT_MERGE,
    OP_DICT_UPDATE,
    OP_STORE_FAST_STORE_FAST,
    OP_EXTENDED_ARG,
    OP_CALL_FUNCTION_EX,
    OP_NOP,
    OP_FOR_ITER,
    OP_POP_ITER,
    opcode_cache_count,
}

def dict_from_str_map(m: dict[str, PyObj]) -> PyDict {
    # Wrap an inherently str-keyed implementation map (frame locals / class
    # namespace / __dict__) into a PyDict with PyStr keys under the hash-key
    # protocol.
    d = PyDict(t="dict", items={});
    for k in m {
        d.dict_set(PyStr(t="str", val=k), m[k]);
    }
    return d;
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

def register_shim_module(name: str, module: PyObj) {
    shim_modules[name] = module;
}

def clear_shim_modules {
    shim_modules = {};
}

def shim_module_get(name: str) -> PyObj {
    if name in shim_modules {
        return shim_modules[name];
    }
    return py_error("ImportError", "shim module '" + name + "' is not installed");
}

# ---------------- stdlib delegation registry ---------------------------------
# Principled stdlib DELEGATION: pure-C / heavy CPython modules are best served
# by the host interpreter rather than ported or run in-VM. A guest
# ``import <mod>`` / ``from <mod> import ...`` whose module has no NATIVE
# facade (shim_modules) resolves through this single registry instead of the
# ad-hoc per-call-site host proxies used before: the host module is imported
# once, its full dir() surface is snapshotted into a native PyModule (scalars
# converted natively, callables/classes left as transparent host proxies),
# and __name__ carries the full dotted module name.
#
# Precedence: native facades win automatically -- every resolution site checks
# shim_modules BEFORE this registry, so landing e.g. a native ``re`` facade
# later needs no registry edit; deletion of the entry re-activates delegation.
#
# Policy "full": snapshot the whole dir() surface minus non-value module
# machinery (__loader__/__spec__/__path__/__builtins__ never round-trip
# meaningfully); synthesized __name__ always wins over the host's copy.
glob delegate_modules: dict[str, str] = {
    "re": "full",
    "datetime": "full",
    "hashlib": "full",
    "base64": "full",
    "zlib": "full",
    "binascii": "full",
    "uuid": "full",
};

# sys.modules semantics: one delegated PyModule per name, identity-stable
# across repeated imports in guest code.
glob delegate_cache: dict[str, PyObj] = {};

def register_delegate_module(name: str, policy: str) {
    if policy != "full" {
        raise ValueError("unknown delegation policy: " + policy);
    }
    delegate_modules[name] = policy;
}

def clear_delegate_modules {
    delegate_modules = {};
    delegate_cache = {};
}

# Build (or fetch cached) the native PyModule standing in for host module
# `name`. Raises through py_error exactly like host_import when the HOST
# import itself fails (ModuleNotFoundError etc. cross faithfully).
def delegated_module(name: str) -> PyObj {
    if name in delegate_cache {
        return delegate_cache[name];
    }
    star: list[PyObj] = [PyStr(t="str", val="*")];
    result = _jac_host_import(name, to_host(PyList(t="list", items=star)));
    if not ((result[0] as bool)) {
        return py_error(str(result[1]), str(result[2]));
    }
    raw = result[1];
    names_res = _jac_dir_names(raw);
    if not ((names_res[0] as bool)) {
        return py_error(str(names_res[1]), str(names_res[2]));
    }
    attrs: dict[str, PyObj] = {};
    for attr_name in names_res[1] {
        if attr_name == "__loader__" or attr_name == "__spec__"
            or attr_name == "__path__" or attr_name == "__builtins__"
            or attr_name == "__name__" {
            continue;
        }
        got = _jac_host_getattr(raw, attr_name);
        if not ((got[0] as bool)) {
            # A lazy attribute that refuses getattr is simply absent from the
            # snapshot; the guest sees our AttributeError, mirroring a failed
            # host access without poisoning the whole import.
            continue;
        }
        attrs[attr_name] = from_host(got[1]);
    }
    attrs["__name__"] = PyStr(t="str", val=name);
    mod = PyModule(t="module", name=name, attrs=attrs);
    delegate_cache[name] = mod;
    return mod;
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

glob sys3_modules: dict[str, PyObj] = {},
     layer3_force_host: list[str] = [],
     layer3_flag: list[bool] = [False];

# Modules deliberately kept host-proxied even though pure-Python source exists,
# because they rely on VM features not yet native (custom metaclasses: enum's
# EnumType drives __prepare__/__new__/__iter__). Proxying a metaclass-heavy leaf
# is the same pragmatic line drawn for C extensions -- it keeps the rest of the
# closure (unittest's own code) running proxy-free. Revisit when metaclasses land.

# One-slot holder rather than a bare `glob layer3_active: bool` -- a scalar glob
# rebound inside a function is scoped local and never persists (see PLAN/memory);
# a list mutated in place does. Read via layer3_is_active() on the IMPORT_NAME path.
def set_layer3_active(flag: bool) {
    layer3_flag[0] = flag;
}

def layer3_is_active -> bool {
    return layer3_flag[0];
}

def clear_sys3_modules {
    sys3_modules = {};
}

# Drop one key from the module cache (used to un-register a module whose in-VM
# execution raised, so a retry re-runs it instead of seeing a half-built shell).
def _sys3_forget(name: str) {
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
    if absname == "weakref" and not ("weakref" in shim_modules) {
        # Register before the module-info lookup: weakref.py is pure-Python
        # stdlib and would otherwise be executed in-VM against C internals.
        shim_modules["weakref"] = build_weakref_module();
    }
    if absname == "heapq" and not ("heapq" in shim_modules) {
        # heapq.py is pure Python but served from the host it mutates a COPY
        # of every guest list (heappush/heapify silently no-op). The native
        # shim operates on live PyList storage instead.
        shim_modules["heapq"] = build_heapq_module();
    }
    if absname == "sys" and not ("sys" in shim_modules) {
        # Serve a delegate snapshot with exception-state OVERRIDDEN: the host sys
        # sees only host exception state, never guest frames. Snapshot failure
        # falls through to plain delegation (no worse than before).
        sysmod = delegated_module("sys");
        if not is_error(sysmod) {
            (sysmod as PyModule).attrs["exc_info"] = PyNativeBuiltin(
                t="native_builtin", name="exc_info"
            );
            (sysmod as PyModule).attrs["exception"] = PyNativeBuiltin(
                t="native_builtin", name="exception"
            );
            (sysmod as PyModule).attrs["intern"] = PyNativeBuiltin(
                t="native_builtin", name="intern"
            );
            (sysmod as PyModule).attrs["__jac_marker__"] = PyStr(t="str", val="installed");
            shim_modules["sys"] = sysmod;
        }
    }
    if absname == "traceback" and not ("traceback" in shim_modules) {
        # The host traceback module is unreachable: every API takes tb objects
        # and a native PyTraceback has no to_host arm (host TracebackType needs
        # real host frames). Serve the native chain-walking surface instead.
        tbmod = PyModule(t="module", name="traceback", attrs=traceback_module_attrs());
        (tbmod as PyModule).attrs["format_exc"] = PyNativeBuiltin(
            t="native_builtin", name="tb_format_exc"
        );
        (tbmod as PyModule).attrs["print_exc"] = PyNativeBuiltin(
            t="native_builtin", name="tb_print_exc"
        );
        (tbmod as PyModule).attrs["print_exception"] = PyNativeBuiltin(
            t="native_builtin", name="tb_print_exc_legacy"
        );
        # Shim type markers: make exposed classes isinstance-matchable
        # (ratified exception/tb-surface scope; hot-path guard lives in
        # py_isinstance keyed on one t compare).
        tagmap = _tb_shim_type_tags();
        for tname in tagmap {
            raw_ctor = (tbmod as PyModule).attrs[tname];
            (tbmod as PyModule).attrs[tname] = ShimTypeMarker(
                t="shim_type_marker",
                tag=(tagmap[tname] as PyStr).val,
                ctor=raw_ctor,
            );
        }

        shim_modules["traceback"] = tbmod;
    }
    if absname in sys3_modules {
        return sys3_modules[absname];
    }
    if absname in shim_modules {
        return shim_modules[absname];
    }
    if absname in delegate_modules {
        # Delegation precedes the module-info lookup: a pure-Python delegatee
        # (re, uuid) must NOT be executed in-VM, and a C module must not take
        # the generic host-proxy path -- both resolve to the same snapshot.
        mod = delegated_module(absname);
        if is_error(mod) {
            return mod;
        }
        sys3_modules[absname] = mod;
        return mod;
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
        # CPython imports the parent package BEFORE resolving the submodule,
        # then consults sys.modules before any finder: a package body may have
        # registered the submodule as a registry alias at exec time (see
        # _jac_sys_modules_lookup -- collections.abc on 3.14 has no file).
        if "." in absname {
            pmod = import_native(_parent_package(absname));
            if is_error(pmod) {
                return pmod;
            }
        } else {
            pmod = py_none();
        }
        looked = _jac_sys_modules_lookup(absname);
        looked_status = str(looked[0]);
        if looked_status == "error" {
            return py_error(str(looked[1]), str(looked[2]));
        }
        if looked_status == "hit" {
            alias = PyHostProxy(t="host", val=looked[1]);
            if "." in absname {
                bound = py_set_attr(
                    pmod, _last_component(absname), alias as PyObj
                );
                if is_error(bound) {
                    return bound;
                }
            }
            sys3_modules[absname] = alias;
            return alias;
        }
        return py_error("ModuleNotFoundError", "No module named '" + absname + "'");
    }
    if status == "not-package" {
        return py_error("ModuleNotFoundError", str(info[4]));
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
    if absname == "types" {
        # The real types.py runs in-VM, but its coroutine() fast path needs host
        # FunctionType/CodeType identity, which native PyFunction lacks -- its
        # fallback wrapper then hands back plain generators that GET_AWAITABLE
        # must reject. Serve CPython's fast-path semantics natively instead.
        (module as PyModule).attrs["coroutine"] = PyTypesCoroutine(
            t="types_coroutine"
        );
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
    # CPython's import_name package-derivation rule: an explicit string
    # __package__ wins verbatim (even empty -- no fallback); otherwise the
    # parent of __name__ ("a.b.m" -> "a.b"); a dotless name has no parent.
    # Relative imports with no parent at all raise "attempted relative import
    # with no known parent package"; climbing past the top raises
    # "attempted relative import beyond top-level package".
    current_package = "";
    saw_package_str = False;
    if "__package__" in globals {
        pkg = globals["__package__"];
        if isinstance(pkg, PyStr) {
            current_package = (pkg as PyStr).val;
            saw_package_str = True;
        }
    }
    if not saw_package_str and "__name__" in globals {
        nm = globals["__name__"];
        if isinstance(nm, PyStr) {
            current_package = _parent_package((nm as PyStr).val);
        }
    }
    if level > 0 {
        if current_package == "" {
            return py_error(
                "ImportError", "attempted relative import with no known parent package"
            );
        }
        bits = current_package.split(".");
        if len(bits) < level {
            return py_error(
                "ImportError", "attempted relative import beyond top-level package"
            );
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

    # Proxies follow the wrapped host object's identity/equality so dict/set
    # bucketing by tp_hashkey (the host hash) stays consistent: same host
    # object -> equal; distinct host objects defer to host ==. Non-proxy
    # operands defer to the caller's fallback (PY_NOT_IMPLEMENTED).
    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        if kind != 2 and kind != 3 {
            return PY_NOT_IMPLEMENTED;
        }
        if isinstance(other, PyHostProxy) {
            mine = self.val;
            theirs = (other as PyHostProxy).val;
            if _jac_host_same_object(mine, theirs) {
                return PyBool(t="bool", val=kind == 2);
            }
            res = _jac_host_eq(mine, theirs);
            if not ((res[0] as bool)) {
                return host_result_error(res);
            }
            if (res[1] as bool) {
                return PyBool(t="bool", val=True);
            }
            return PY_NOT_IMPLEMENTED;
        }
        return PY_NOT_IMPLEMENTED;
    }

    def tp_getattro(name: str) -> PyObj {
        # object.__new__ builds a plain in-VM instance (so a user class's __new__
        # that calls it produces a PyUserObj, not a host object). Narrow to the
        # exact `object` type; every other type's __new__ stays host-routed.
        if name == "__new__" and _jac_is_object_type(self.val) {
            return PyNativeNew(t="native_new", base_name="object");
        }
        # Unbound object.__getattribute__/__setattr__/__delattr__: the canonical
        # delegation target inside user overrides (object.__setattr__(self, n,
        # v)). A host proxy would see to_host(instance) == None; route through
        # PyObjectAttrSlot instead, which runs the default protocol in-VM.
        if _jac_is_object_type(self.val)
            and (name == "__getattribute__" or name == "__setattr__"
                or name == "__delattr__") {
            return PyObjectAttrSlot(t="obj_attr_slot", op=name);
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
        # `type(x)` (one positional arg) must be answered in-VM: a native user
        # instance's type is its own PyClass, not host type(to_host(x)) -- which
        # was NoneType because to_host of a plain user object is None. The 3-arg
        # `type(name, bases, ns)` class constructor and every real metaclass call
        # stay host-routed. `type` is the exact builtin here, never a subclass.
        if len(args) == 1 and len(kwargs) == 0 and bool(_jac_is_type_type(self.val)) {
            return py_type_of(args[0]);
        }
        # 3-arg type(name, bases, ns): reject __mro_entries__ / non-class bases
        # with CPython's messages BEFORE host routing (the host would see standin
        # proxies and raise a different error than the guest-visible truth).
        if len(args) == 3 and len(kwargs) == 0 and bool(_jac_is_type_type(self.val)) {
            raw_bases: list[PyObj] = [];
            if isinstance(args[1], PyTuple) {
                for tb in (args[1] as PyTuple).items {
                    raw_bases.append(tb);
                }
            } elif isinstance(args[1], PyList) {
                for tb in (args[1] as PyList).items {
                    raw_bases.append(tb);
                }
            }
            rejected = _jac_validate_type_bases(raw_bases);
            if rejected is not None {
                return rejected;
            }
        }
        # Zero-arg super() at a GENERIC call site (the proxy wraps the host
        # super TYPE): the compiler lowers every cell-backed super().attr to
        # LOAD_SUPER_ATTR, so this is exactly CPython's frame-without-cell case
        # -- raise its error instead of letting the host super introspect the
        # jaclang interpreter's own Python frame.
        if len(args) == 0 and len(kwargs) == 0 and bool(_jac_is_super_type(self.val)) {
            return py_error("RuntimeError", "super(): no arguments");
        }
        # The conversion constructors int()/float()/bool()/str() over a NATIVE
        # operand answer through the implicit slot machinery instead of crossing
        # the bridge: to_host of a plain user object is None, so the host
        # constructor saw nothing (bool(obj) was literally False; int(obj),
        # float(obj) raised; str(obj) yielded 'None'). Each native operand found
        # converts ITSELF (never args[0]).
        #
        # EXCEPTION -- explicit-base int(x, base): every operand must cross,
        # so builtin-mixin instances (an Enum-style str/int subclass) unwrap
        # to their boxed base value and the host constructor parses with the
        # FULL argument list. Hijacking the native operand alone dropped the
        # base (int(str_sub('ff'), 16) failed as "base 10"). A plain user
        # instance stays opaque; the host then reports CPython's own "can't
        # convert non-string with explicit base" TypeError.
        ckind = str(_jac_conversion_ctor_kind(self.val));
        if ckind == "int" and (len(args) >= 2 or len(kwargs) > 0) {
            unwrapped: list[PyObj] = [];
            for a in args {
                if isinstance(a, PyUserObj) and (a as PyUserObj)._has_base() {
                    unwrapped.append((a as PyUserObj)._base_obj());
                } else {
                    unwrapped.append(a);
                }
            }
            return py_call_host(self, unwrapped, kwargs);
        }
        if len(args) >= 1 and ckind != "" {
            for a in args {
                if isinstance(a, PyUserObj) {
                    if ckind == "bool" {
                        return py_slot_truth(a);
                    }
                    if ckind == "int" {
                        return py_convert_int(a);
                    }
                    if ckind == "str" {
                        return py_str(a);
                    }
                    return py_convert_float(a);
                }
            }
        }
        # The complex() constructor over native operands answers in-VM
        # (string parsing, numeric promotion); shapes without a native
        # answer fall back to the host call below, byte-exact.
        if len(args) <= 2 and bool(_jac_is_complex_type(self.val)) {
            cres = py_convert_complex(args);
            if not is_notimplemented(cres) {
                return cres;
            }
        }
        return py_call_host(self, args, kwargs);
    }

    def tp_hashkey -> PyObj {
        hks = _jac_host_hashkey(self.val);
        if hks == "" {
            return py_error("TypeError", "unhashable type");
        }
        return PyStr(t="str", val=hks);
    }

    def mp_subscript(index: PyObj) -> PyObj {
        return host_getitem(self, index);
    }

    def tp_iter -> PyObj {
        return host_iter(self);
    }
}

# ---------------- native range (TODO item 19) --------------------------------
# Heap-type wrapper over the lifted leaf math in rangeobject.jac: identity and
# O(1) len/contains/index/slice arithmetic instead of materializing elements
# across the bridge. Design: docs/RANGE_BRIDGE_DESIGN.md.
obj PyRange(PyObj) {
    has start: int,
        stop: int,
        step: int;

    def length -> int {
        return get_len_of_range(self.start, self.stop, self.step);
    }

    def tp_getattro(name: str) -> PyObj {
        if name == "start" {
            return PyInt(t="int", val=self.start);
        }
        if name == "stop" {
            return PyInt(t="int", val=self.stop);
        }
        if name == "step" {
            return PyInt(t="int", val=self.step);
        }
        if name == "index" or name == "count" {
            return PyRangeMethod(t="range_method", target=self, name=name);
        }
        return py_error("AttributeError", name);
    }

    # CPython range_hash: hash of the None-stub triple (len, start, step).
    # Computed via the real lifted tuple/int hash machinery so VALUES are
    # byte-parity with the host ratchet, not just equivalence classes.
    # hash(None) is process-stable in CPython (4238894112); substituting an
    # int of that value keeps every lane's hash identical to the real triple.
    def tp_hashkey -> PyObj {
        n = self.length();
        triple: list[PyObj] = [PyInt(t="int", val=n)];
        if n == 0 {
            triple.append(PyInt(t="int", val=4238894112));
            triple.append(PyInt(t="int", val=4238894112));
        } else {
            triple.append(PyInt(t="int", val=self.start));
            if n == 1 {
                triple.append(PyInt(t="int", val=4238894112));
            } else {
                triple.append(PyInt(t="int", val=self.step));
            }
        }
        th = tuple_hash(PyTuple(t="tuple", items=triple));
        if is_error(th) {
            return th;
        }
        # Already-signed numeric digest: the "n:" namespace passes it through
        # verbatim (see _hashkey_digest).
        return PyStr(t="str", val="n:" + str((th as PyInt).val));
    }

    def tp_iter -> PyObj {
        # Fresh cursor per iteration: ranges are re-iterable.
        return PyRangeIter(
            t="rangeiter", cur=self.start, remaining=self.length(), step=self.step
        );
    }

    def tp_bool -> bool {
        return self.length() > 0;
    }

    def mp_subscript(index: PyObj) -> PyObj {
        if isinstance(index, PySlice) {
            err = _zero_step_error(index as PySlice);
            if is_error(err) {
                return err;
            }
            b = slice_indices(index as PySlice, self.length());
            count = get_len_of_range(b[0], b[1], b[2]);
            new_start = self.start + b[0] * self.step;
            new_step = self.step * b[2];
            return PyRange(
                t="range",
                start=new_start,
                stop=new_start + count * new_step,
                step=new_step,
            );
        }
        idx_obj = index.to_index();
        if is_error(idx_obj) {
            return py_error(
                "TypeError",
                "range indices must be integers or slices, not '" + index.t + "'",
            );
        }
        i = (idx_obj as PyInt).val;
        n = self.length();
        if i < 0 {
            i = n + i;
        }
        if i >= 0 and i < n {
            return PyInt(t="int", val=self.start + i * self.step);
        }
        return py_error("IndexError", "range object index out of range");
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        # CPython range_richcompare: eq/ne via length-normalized comparison
        # (range(0,10,3) == range(0,12,3)); ordering is NotImplemented.
        if kind == 2 or kind == 3 {
            if isinstance(other, PyRange) {
                og = other as PyRange;
                same = range_equals_longs(
                    self.start, self.stop, self.step, og.start, og.stop, og.step
                );
                return PyBool(t="bool", val=same == (kind == 2));
            }
            return PY_NOT_IMPLEMENTED;
        }
        return PY_NOT_IMPLEMENTED;
    }
}

# One-shot cursor over a PyRange: arithmetic per step, no materialization.
# Driven by the explicit send_into arm (design Q3: hot-loop path).
obj PyRangeIter(PyObj) {
    has cur: int,
        remaining: int,
        step: int;
}

# Owner-prefixed method-descriptor arg errors, byte-matching CPython's
# descriptor wording: `set.add() takes exactly one argument (2 given)`,
# `dict.keys() takes no arguments (1 given)`, and the kwargs refusal form.
def meth_takes_one(owner: str, name: str, n: int) -> PyObj {
    return py_error(
        "TypeError",
        owner + "." + name + "() takes exactly one argument (" + str(n) + " given)",
    );
}

def meth_takes_none(owner: str, name: str, n: int) -> PyObj {
    return py_error(
        "TypeError", owner + "." + name + "() takes no arguments (" + str(n) + " given)"
    );
}

def meth_no_kwargs(owner: str, name: str) -> PyObj {
    return py_error("TypeError", owner + "." + name + "() takes no keyword arguments");
}

# Bound .index()/.count() methods over a PyRange (CPython range_index/
# range_count): exact-int needles take O(1) arithmetic from the lifted leaf;
# everything else scans with real == (_PySequence_IterSearch semantics).
obj PyRangeMethod(PyObj) {
    has target: PyRange,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return meth_no_kwargs("range", self.name);
        }
        if len(args) != 1 {
            return meth_takes_one("range", self.name, len(args));
        }
        rg = self.target;
        value = args[0];
        is_int = isinstance(value, PyInt) or isinstance(value, PyBool);
        if self.name == "count" {
            if is_int {
                v = (value as PyInt).val;
                hit = range_contains_longs(rg.start, rg.stop, rg.step, v);
                return PyInt(t="int", val=1 if hit else 0);
            }
            hits = 0;
            cursor = rg.tp_iter();
            while True {
                scan_step = send_into(cursor, py_none());
                if scan_step.t == "genstop" {
                    return PyInt(t="int", val=hits);
                }
                cmp = py_compare(2, value, scan_step);
                if is_error(cmp) {
                    return cmp;
                }
                if cmp.tp_bool() {
                    hits = hits + 1;
                }
            }
        }
        # .index(value)
        if is_int {
            v = (value as PyInt).val;
            if range_contains_longs(rg.start, rg.stop, rg.step, v) {
                pos = (v - rg.start) // rg.step;
                return PyInt(t="int", val=pos);
            }
            return py_error("ValueError", "range.index(x): x not in range");
        }
        cursor = rg.tp_iter();
        position = 0;
        while True {
            scan_step2 = send_into(cursor, py_none());
            if scan_step2.t == "genstop" {
                break;
            }
            cmp = py_compare(2, value, scan_step2);
            if is_error(cmp) {
                return cmp;
            }
            if cmp.tp_bool() {
                return PyInt(t="int", val=position);
            }
            position = position + 1;
        }
        return py_error("ValueError", "sequence.index(x): x not in sequence");
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
        metaclass: any = None,
        # ``PyType_Ready`` lifecycle flags (P5 heap types).
        tp_flags: int = 0,
        # __slots__ layout state (CPython type_new_set_attrs / type_ready setdict):
        # slot_members is the MERGED member list (own mangled members first, then
        # inherited), slots_declared gates enforcement (a late `Cls.__slots__ =
        # ...` assignment must stay inert), and instance_has_dict follows the
        # CPython inheritance rule -- no declaration means a dict; with one, only
        # an explicit `__dict__` entry or a dict-bearing base keeps the dict.
        # Defaults keep every non-slotted construction site permissive.
        slot_members: list[str] = [],
        slots_declared: bool = False,
        instance_has_dict: bool = True;

    # Attribute lookup walks the MRO (self first, then bases) so an inherited
    # method/attr is visible on a subclass. Instance access binds via PyUserObj.
    def tp_getattro(name: str) -> PyObj {
        # A class's __name__ is its own name, NOT whatever the body namespace left
        # behind: the class-body frame seeds `__name__` to the module name (correct
        # inside the body), and that entry leaks into attrs. Answer from self.name
        # before the attribute lookup so `Cls.__name__` isn't the module. (__module__
        # legitimately IS that seeded module name, so it stays an attrs lookup.)
        if name == "__name__" {
            return PyStr(t="str", val=self.name);
        }
        if name == "__class__" {
            # CPython: a class's __class__ IS its metaclass (type when none).
            if self.metaclass is not None {
                return self.metaclass as PyObj;
            }
            return host_builtin("type");
        }
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
            return PyTuple(t="tuple", items=class_full_mro(self));
        }
        if name == "mro" {
            return PyClassMroMethod(t="class_mro", cls=self);
        }
        if name == "__bases__" {
            # CPython type_ready seeds a baseless class with (object,).
            if len(self.bases) > 0 {
                return PyTuple(t="tuple", items=self.bases);
            }
            return PyTuple(t="tuple", items=[host_builtin("object")]);
        }
        if name == "__base__" {
            if len(self.bases) > 0 {
                return self.bases[0];
            }
            return host_builtin("object");
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
        # Inherited slot-wrapper surface: CPython serves `Cls.__repr__` through
        # the metaclass channel -- type(Cls).__mro__ reaches object, whose type
        # dict carries every slot wrapper. Guest classes store no such entries
        # in attrs, so walk the MRO's native-base surfaces first (a dict
        # subclass inherits dict.__repr__'s wrapper) and finish on object's.
        for klass in class_mro(self) {
            nb = klass.native_base;
            if nb != "" {
                r = _jac_host_type_attr(nb, name);
                if host_result_ok(r) {
                    return from_host(r[1]);
                }
            }
        }
        obj_r = _jac_host_type_attr("object", name);
        if host_result_ok(obj_r) {
            return from_host(obj_r[1]);
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
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    # Classes compare by identity: `ReprEnum in (Enum,)` must be False so enum's
    # ReprEnum-mixin check doesn't misfire on distinct classes.
    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        return type_richcompare(kind, self as PyObj, other);
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
        # A custom metaclass __getitem__ outranks __class_getitem__: CPython
        # installs slot_tp_subscript on the metaclass, which intercepts before
        # type_subscript ever consults the class MRO.
        gi = self._meta_dunder("__getitem__");
        if not is_error(gi) {
            return gi.tp_call([index], {});
        }
        # type_subscript fallback: resolve __class_getitem__ on this class's own
        # MRO (an explicit def or one inherited from Generic / an ABC base) and
        # bind it to the class -- Cls[...] is sugar for
        # Cls.__class_getitem__(index).
        cgi = class_lookup_attr(self, "__class_getitem__");
        if not is_error(cgi) and isinstance(cgi, PyNoneType) {
            # CPython type_subscript: __class_getitem__ = None means the class
            # explicitly opted out -- fall through to the not-subscriptable
            # error naming this class.
            cgi = py_error("AttributeError", "__class_getitem__");
        }
        if not is_error(cgi) {
            return bind_attribute(cgi, self).tp_call([index], {});
        }
        return py_error(
            "TypeError", "type '" + self.name + "' is not subscriptable"
        );
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        # A python-level __new__ (common on builtin subclasses that control their
        # boxed value, e.g. re._constants._NamedIntConstant) governs construction:
        # call __new__(cls, *args) and use its return value. __init__ then runs
        # only if __new__ returned an instance of this class (CPython's rule).
        # NOTE the two shapes __new__ takes from guest namespaces: since the
        # type_new_staticmethod replication above, guest-stored __new__ is a
        # PyStaticMethod wrapping the real function; CPython's type_call looks
        # through the descriptor to the underlying function.
        user_new = class_lookup_attr(self, "__new__");
        new_fn: any = py_none();
        has_user_new = False;
        if not is_error(user_new) {
            cand: any = user_new;
            if isinstance(user_new, PyStaticMethod) {
                cand = (user_new as PyStaticMethod).func;
            }
            if isinstance(cand, PyFunction) {
                new_fn = cand;
                has_user_new = True;
            }
        }
        if has_user_new {
            new_args: list[PyObj] = [self];
            for a in args {
                new_args.append(a);
            }
            made = py_invoke(new_fn as PyFunction, new_args, kwargs);
            if is_error(made) {
                return made;
            }
            # CPython type_call runs __init__ iff isinstance(obj, cls). Two
            # shapes qualify: an ordinary PyUserObj instance, AND the class
            # object itself on the class-creation path (type.__new__ returns a
            # PyClass tagged with THIS metaclass -- skipping its __init__ here
            # silently drops _ProtocolMeta-style bodies).
            made_is_meta_inst = False;
            if isinstance(made, PyUserObj)
                and instance_of_class(made as PyUserObj, self) {
                made_is_meta_inst = True;
            }
            if isinstance(made, PyClass)
                and (made as PyClass).metaclass is self {
                made_is_meta_inst = True;
            }
            if made_is_meta_inst {
                init2 = class_lookup_attr(self, "__init__");
                if not is_error(init2) and isinstance(init2, PyFunction) {
                    ir = bind_attribute(init2, made).tp_call(args, kwargs);
                    if ir.t == "error" {
                        return ir;
                    }
                } elif self.native_base == "set" and len(kwargs) > 0 {
                    # No user __init__: CPython's type_call still runs the
                    # MRO-resolved initializer -- set.__init__, which rejects
                    # keywords (`subclass_with_new(x, newarg=3)` must raise).
                    # list/tuple/frozenset resolve leniently here (their slot
                    # inheritance drops excess args); dict consumed **kwds at
                    # __new__ time.
                    return py_error(
                        "TypeError", "set() takes no keyword arguments"
                    );
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
            if not has_user_init and len(kwargs) > 0
                and self.native_base != "dict" {
                # With no user __init__ the MRO-resolved initializer is the
                # builtin base's own -- it rejects keywords exactly as the bare
                # constructor does (`Sub(sequence=())` must TypeError).
                return py_error(
                    "TypeError", self.native_base + "() takes no keyword arguments"
                );
            }
            box_args = args;
            if has_user_init and is_mutable_base(self.native_base) {
                box_args = [];
            }
            boxed = construct_native_base(self.native_base, box_args);
            if is_error(boxed) {
                return boxed;
            }
            if not has_user_init and self.native_base == "dict"
                and len(kwargs) > 0 {
                # dict is the one base whose constructor consumes **kwds.
                upd = PyDictMethod(
                    t="dict_method", target=(boxed as PyDict), name="update"
                ).tp_call([], kwargs);
                if upd.t == "error" {
                    return upd;
                }
            }
        }
        instance = PyUserObj(t="instance", cls=self, attrs={}, base=boxed);
        if class_is_exception(self) {
            # CPython's BaseException_new records the constructor args on the
            # instance BEFORE __init__ runs, so a user __init__ that never calls
            # super().__init__ still leaves e.args == constructor args.
            arg_items: list[PyObj] = [];
            arg_items.extend(args);
            instance.attrs["args"] = PyTuple(t="tuple", items=arg_items);
        }
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
        base: any = None,
        # Live instance-``__dict__`` view (PyInstanceDict) minted on first
        # access and kept identity-stable -- CPython returns the SAME dict
        # object every time. attrs_version mirrors attribute mutations into
        # the view so reads through it stay current.
        dict_cache: any = None,
        attrs_version: int = 0;

    # The boxed builtin value (int/str/...) for a builtin subclass, or a
    # PyNoneType sentinel for a plain user class. _has_base tells them apart.
    def _has_base -> bool {
        return self.base is not None and not isinstance(self.base, PyNoneType);
    }

    def _base_obj -> PyObj {
        return self.base as PyObj;
    }

    def tp_getattro(name: str) -> PyObj {
        # CPython slot_tp_getattro: the MRO-resolved __getattribute__ IS the get
        # protocol -- it wraps EVERYTHING (properties, instance dict, __class__,
        # the boxed base). The lookup is a raw class-dict walk (never an
        # attribute access), so resolving the override cannot re-enter it.
        attr_override = class_lookup_attr(self.cls, "__getattribute__");
        if not is_error(attr_override) {
            res = bind_attribute(attr_override, self as PyObj).tp_call(
                [PyStr(t="str", val=name)], {}
            );
        } else {
            res = default_user_getattro(self, name);
        }
        # slot_tp_getattr: an AttributeError from the get protocol (user
        # override or default) falls back to a type-level __getattr__.
        if is_error(res)
            and isinstance(res, PyError)
            and (res as PyError).exception.type_name == "AttributeError" {
            fallback = class_lookup_attr(self.cls, "__getattr__");
            if not is_error(fallback) {
                return bind_attribute(fallback, self as PyObj).tp_call(
                    [PyStr(t="str", val=name)], {}
                );
            }
        }
        return res;
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        # Mirror of tp_getattro for writes: a type-level __setattr__ intercepts
        # every assignment BEFORE data-descriptor checks (slot_tp_setattro).
        attr_override = class_lookup_attr(self.cls, "__setattr__");
        if not is_error(attr_override) {
            return bind_attribute(attr_override, self as PyObj).tp_call(
                [PyStr(t="str", val=name), value], {}
            );
        }
        return default_user_setattro(self, name, value);
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
        # A user-defined __index__ IS the index slot (operator.index()).
        if user_has_dunder(self, "__index__") {
            res = call_user_dunder(self, "__index__", []);
            if is_error(res) {
                return res;
            }
            if isinstance(res, PyBool) {
                return PyInt(t="int", val=1 if (res as PyBool).val else 0);
            }
            if isinstance(res, PyInt) {
                return res;
            }
            return py_error(
                "TypeError", "__index__ returned non-int of type '" + res.t + "'"
            );
        }
        # A builtin-int subclass instance (re._constants._NamedIntConstant, an
        # IntEnum member, ...) indexes as its boxed int.
        if self._has_base() {
            return self._base_obj().to_index();
        }
        return py_error("TypeError", "object cannot be interpreted as an integer");
    }

    def tp_hashkey -> PyObj {
        # CPython slot machinery (Objects/typeobject.c): inherit_slots (~8372)
        # copies tp_richcompare AND tp_hash together from the first MRO base
        # only while this class overrides neither; otherwise a still-NULL
        # tp_hash is resolved by type_ready_set_hash (~8773), which injects
        # tp_dict["__hash__"] = None (update_one_slot ~11655 maps that None to
        # PyObject_HashNotImplemented). Net rule, reproduced here without the
        # dict mutation: walk the MRO; the NEAREST class dict defining either
        # name decides.
        if mro_hash_blocked(self) {
            return py_error("TypeError", "unhashable type");
        }
        # A user-defined __hash__ keys the object by value; routing through
        # py_hash keeps raised/non-int returns byte-exact with hash() itself
        # (slot_tp_hash, typeobject.c ~10295).
        if user_has_dunder(self, "__hash__") {
            h = py_hash(self as PyObj);
            if is_error(h) {
                return h;
            }
            return PyStr(t="str", val="n:" + str((h as PyInt).val));
        }
        if self._has_base() {
            return self._base_obj().tp_hashkey();
        }
        # Default object.__hash__: identity-keyed, distinct per object.
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    # CPython ``tp_name``: error messages quote the real class name, not the
    # internal "instance" tag (e.g. "cannot use 'AlwaysEq' as a set element").
    def tp_type_name -> str {
        return self.cls.name;
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

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        # A user-defined __call__ makes the instance callable: bind the MRO-
        # resolved dunder to the instance and invoke it. A raised exception
        # propagates verbatim (same path as every other dunder slot); no result
        # check -- any object __call__ returns is the call's value.
        if user_has_dunder(self, "__call__") {
            method = class_lookup_attr(self.cls, "__call__");
            return bind_attribute(method, self).tp_call(args, kwargs);
        }
        if self._has_base() {
            return self._base_obj().tp_call(args, kwargs);
        }
        return py_error("TypeError", "object is not callable");
    }

    def mp_subscript(index: PyObj) -> PyObj {
        if user_has_dunder(self, "__getitem__") {
            return call_user_dunder(self, "__getitem__", [index]);
        }
        if self._has_base() {
            base = self._base_obj();
            # A builtin-dict base with no __getitem__ override IS
            # ``dict.__getitem__`` -- route the miss through the type-level
            # __missing__ consult (defaultdict / user subclasses).
            if isinstance(base, PyDict) {
                return dict_subscript_missing(self, base as PyDict, index);
            }
            return base.mp_subscript(index);
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
            # Route through public dispatch so builtin-subclass storage shares
            # the slice-assignment iterable normalization (a boxed list receives
            # values of its own Python type, not just native PyList).
            return py_store_subscript(self._base_obj(), index, value);
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

# The DEFAULT attribute protocol for a generic instance -- what
# object.__getattribute__/__setattr__/__delattr__ do in CPython. Factored out of
# PyUserObj so the slot dispatch AND the exposed object.__*attr__ slot wrappers
# (PyObjectAttrSlot) share one implementation: calling through the wrapper runs
# the default protocol directly, which is exactly CPython's recursion guard for
# a user __getattribute__/__setattr__ delegating via
# object.__getattribute__(self, n) / super().__setattr__(n, v).
def default_user_getattro(u: PyUserObj, name: str) -> PyObj {
    # A property is a data descriptor: it wins over the instance dict, so
    # `o.v` runs the getter even after `o.v = ...` routed through the setter.
    classattr = class_lookup_attr(u.cls, name);
    if isinstance(classattr, PyProperty) {
        return descriptor_get(classattr, u, u.cls);
    }
    # A slot member descriptor is likewise a data descriptor: reads go through
    # it (host-exact unset-slot error) rather than a raw instance-dict peek.
    if isinstance(classattr, PyMemberDescr) {
        return (classattr as PyMemberDescr)._get(u);
    }
    if name in u.attrs {
        return bind_attribute(u.attrs[name], u);
    }
    found = classattr;
    if not is_error(found) {
        # Instance access: bind a method, invoke a property getter, unwrap a
        # staticmethod, or bind a classmethod to the instance's class.
        return descriptor_get(found, u, u.cls);
    }
    # __dict__ exists ONLY when the class layout says so (a slotted class with
    # no explicit __dict__ entry and no dict-bearing base has none -- host:
    # AttributeError 'C' object has no attribute '__dict__'). Checked BEFORE
    # the boxed-base fallthrough so the error names the subclass, not the base.
    if name == "__dict__" {
        return user_instance_dict(u);
    }
    # Fall through to the boxed builtin value's own attributes/methods
    # (str.upper on a str subclass, etc.).
    if u._has_base() {
        return py_attr(u._base_obj(), name);
    }
    # Identity dunder: every object's __class__ resolves to its type object
    # (CPython object.__class__ descriptor). Needed for e.__class__.__name__
    # on caught exceptions and isinstance-style idioms.
    if name == "__class__" {
        return u.cls;
    }
    # object's attribute-protocol methods are real attributes of every
    # instance (hasattr(inst, '__getattribute__') is True); expose them as
    # bound slot wrappers over the generic attribute dispatch.
    if name == "__getattribute__" or name == "__setattr__"
        or name == "__delattr__" {
        return PyObjectAttrSlot(t="obj_attr_slot", target=u as PyObj, op=name);
    }
    return py_error("AttributeError", name);
}

def default_user_setattro(u: PyUserObj, name: str, value: PyObj) -> PyObj {
    # A property with a setter is a data descriptor: assignment routes through
    # fset instead of writing the instance dict.
    classattr = class_lookup_attr(u.cls, name);
    if isinstance(classattr, PyProperty) {
        p = classattr as PyProperty;
        if p.fset is not None {
            res = py_invoke(p.fset as PyObj, [u as PyObj, value], {});
            if is_error(res) {
                return res;
            }
            return py_none();
        }
        return py_error("AttributeError", "can't set attribute '" + name + "'");
    }
    # A slot member descriptor takes the write (data-descriptor priority).
    if isinstance(classattr, PyMemberDescr) {
        return (classattr as PyMemberDescr)._set(u, value);
    }
    # __slots__ enforcement: a declared-slot class with no instance dict only
    # accepts its member names -- anything else is the host's two-clause error
    # (the same text delattr produces; CPython shares the no-dict path).
    if u.cls.slots_declared and not u.cls.instance_has_dict
        and not type_slots_attr_allowed(name, False, u.cls.slot_members) {
        return py_error(
            "AttributeError",
            "'" + u.cls.name + "' object has no attribute '" + name
                + "' and no __dict__ for setting new attributes",
        );
    }
    u.attrs[name] = value;
    # Keep the live __dict__ view current (identity-stable mirror).
    if u.dict_cache is not None
        and type_slots_in_dict_view(name, u.cls.slot_members) {
        d = u.dict_cache as PyDict;
        (d as PyInstanceDict).view_set(name, value);
    }
    return py_none();
}

def default_user_delattro(u: PyUserObj, name: str) -> PyObj {
    # A property with a deleter is a data descriptor: deletion routes through
    # fdel instead of removing an instance-dict entry (mirror of the setter
    # branch in default_user_setattro).
    classattr = class_lookup_attr(u.cls, name);
    if isinstance(classattr, PyProperty) {
        p = classattr as PyProperty;
        if p.fdel is not None {
            res = py_invoke(p.fdel as PyObj, [u as PyObj], {});
            if is_error(res) {
                return res;
            }
            return py_none();
        }
        return py_error("AttributeError", "can't delete attribute '" + name + "'");
    }
    # A slot member descriptor takes the delete (empty slot reports the bare
    # member name via _del).
    if isinstance(classattr, PyMemberDescr) {
        return (classattr as PyMemberDescr)._del(u);
    }
    # Same no-dict gate as writes: deleting an undeclared name on a slotted,
    # dict-less instance raises the host's two-clause AttributeError.
    if u.cls.slots_declared and not u.cls.instance_has_dict
        and not type_slots_attr_allowed(name, False, u.cls.slot_members) {
        return py_error(
            "AttributeError",
            "'" + u.cls.name + "' object has no attribute '" + name
                + "' and no __dict__ for setting new attributes",
        );
    }
    if name in u.attrs {
        del u.attrs[name];
        if u.dict_cache is not None
            and type_slots_in_dict_view(name, u.cls.slot_members) {
            (u.dict_cache as PyInstanceDict).view_del(name);
        }
        return py_none();
    }
    return py_error("AttributeError", name);
}

# The live instance ``__dict__``: a real dict (subclass of PyDict) whose items
# mirror the owner's attribute map, so CPython's identity/write-through/
# reflection triangle holds -- ``o.__dict__ is o.__dict__``, writes through a
# fetched reference are visible as attributes and vice versa. Slot member
# names stay OUT of the view (CPython keeps d.a out of d.__dict__ even with
# __slots__ = ('a', '__dict__')); writes of those names land in an overlay so
# they iterate in the view while attribute reads still hit the member
# descriptor first.
obj PyInstanceDict(PyDict) {
    # ``owner`` is typed ``any`` because a non-default field cannot follow the
    # inherited defaulted ``version`` field.
    has owner: any = None,
        overlay: dict[str, PyObj] = {};

    # Single mutation entry for mirrored attribute writes. Items live under
    # the SAME hash-key namespace as every other PyDict ("s:"-prefixed for
    # str keys), so inherited lookups/iteration see them.
    def view_set(name: str, value: PyObj) {
        hk = hashkey_str((PyStr(t="str", val=name)).tp_hashkey());
        self.items[hk] = DictEntry(key=PyStr(t="str", val=name), value=value);
        self.version = self.version + 1;
    }

    # Single removal entry for mirrored attribute deletes.
    def view_del(name: str) {
        del self.items[hashkey_str((PyStr(t="str", val=name)).tp_hashkey())];
        self.version = self.version + 1;
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        hkr = index.tp_hashkey();
        if is_error(hkr) {
            return _unhashable_error("a dict key", index);
        }
        if isinstance(index, PyStr) {
            name = (index as PyStr).val;
            owner_u = self.owner as PyUserObj;
            if name in owner_u.cls.slot_members {
                self.overlay[name] = value;
            } else {
                owner_u.attrs[name] = value;
            }
            self.view_set(name, value);
            return py_none();
        }
        # Non-string key: a pure dict entry, invisible to the attribute
        # protocol (CPython stores it in the instance dict the same way).
        self.items[hashkey_str(hkr)] = DictEntry(key=index, value=value);
        self.version = self.version + 1;
        return py_none();
    }

    def mp_del_subscript(index: PyObj) -> PyObj {
        hkr = index.tp_hashkey();
        if is_error(hkr) {
            return _unhashable_error("a dict key", index);
        }
        if isinstance(index, PyStr) {
            name = (index as PyStr).val;
            owner_u = self.owner as PyUserObj;
            if name in self.overlay {
                del self.overlay[name];
                self.view_del(name);
                return py_none();
            }
            if name in owner_u.attrs {
                del owner_u.attrs[name];
                self.view_del(name);
                return py_none();
            }
            return py_error("KeyError", dict_key_repr(index));
        }
        hk = hashkey_str(hkr);
        if hk in self.items {
            del self.items[hk];
            self.version = self.version + 1;
            return py_none();
        }
        return py_error("KeyError", dict_key_repr(index));
    }
}

def user_instance_dict(u: PyUserObj) -> PyObj {
    if not u.cls.instance_has_dict {
        return py_error(
            "AttributeError",
            "'" + u.cls.name + "' object has no attribute '__dict__'",
        );
    }
    if u.dict_cache is not None {
        return u.dict_cache as PyObj;
    }
    d = PyInstanceDict(t="dict", owner=u, items={});
    for k in u.attrs {
        if type_slots_in_dict_view(k, u.cls.slot_members) {
            (d as PyInstanceDict).view_set(k, u.attrs[k]);
        }
    }
    u.dict_cache = d;
    return d as PyObj;
}

# CPython mappingproxy: a read-only view over a dict (class __dict__,
# ``Field.metadata``, module surfaces). Reads and iteration delegate to the
# wrapped dict; every mutation entry raises the host's two-clause TypeError.
obj PyMappingProxy(PyObj) {
    has target: PyDict;

    def mp_subscript(index: PyObj) -> PyObj {
        return self.target.mp_subscript(index);
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        return py_error(
            "TypeError", "'mappingproxy' object does not support item assignment"
        );
    }

    def mp_del_subscript(index: PyObj) -> PyObj {
        return py_error(
            "TypeError", "'mappingproxy' object does not support item deletion"
        );
    }

    def tp_getattro(name: str) -> PyObj {
        # Read-only method surface: mapping-style accessors delegate to the
        # wrapped dict's native methods; keys/values/items construct live
        # set-like views exactly as a plain dict does.
        if name == "keys" or name == "values" or name == "items" {
            return PyDictViewCtor(
                t="view_ctor", d=self.target, mode=name
            );
        }
        if name == "get" or name == "copy" or name == "__contains__"
            or name == "__getitem__" {
            return PyDictMethod(
                t="dict_method", target=self.target, name=name
            );
        }
        return py_error("AttributeError", name);
    }
}

# type.mro() as a bound method on a class: the C3 linearization with the
# terminal object appended -- the same list __mro__ displays. A class-dict
# `mro` entry shadows this via the attrs-first lookup in tp_getattro, matching
# CPython's overridable type.mro.
obj PyClassMroMethod(PyObj) {
    has cls: PyClass;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error("TypeError", "mro() takes no keyword arguments");
        }
        if len(args) > 0 {
            return py_error(
                "TypeError",
                self.cls.name + ".mro() takes no arguments (" + str(len(args)) + " given)",
            );
        }
        return PyList(t="list", items=class_full_mro(self.cls));
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

# typing._GenericAlias(Generic, params) stand-in -- the implicit PEP 695 class
# base produced by CALL_INTRINSIC_1 arg 10 (INTRINSIC_SUBSCRIPT_GENERIC).
# Data-only: attribute answers (__origin__/__args__/__parameters__), the repr,
# and the __mro_entries__ hook live in ceval (py_attr / py_repr) because the
# origin is typing_generic_class() below and resolution re-enters execution.
obj PyGenericAlias(PyObj) {
    has params: PyObj;
}

# Bound __mro_entries__ callable for PyGenericAlias: CPython's _GenericAlias
# method returns a tuple of replacement bases when __build_class__ invokes it
# (bltinmodule.c update_bases); ours resolves to Generic itself.
obj PyGenericMroEntries(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return PyTuple(t="tuple", items=[typing_generic_class()]);
    }
}

# typing.NoDefault sentinel (PEP 696): a type parameter without an explicit
# default answers __default__ with this immortal singleton.
obj PyNoDefault(PyObj) {
}

glob _no_default_singleton: any = None;

def no_default_sentinel() -> PyObj {
    if _no_default_singleton is None {
        _no_default_singleton = PyNoDefault(t="nodefault");
    }
    return _no_default_singleton;
}

glob _generic_class_cache: any = None;

# Native stand-in for typing.Generic: the base that implicit PEP 695 class
# parameters resolve to through __mro_entries__, so a generic class's MRO
# reads (C, Generic, object) like CPython's. Cached -- every generic class
# shares this one base object, so identity comparisons hold.
def typing_generic_class() -> PyClass {
    if _generic_class_cache is None {
        _generic_class_cache = PyClass(
            t="class",
            name="Generic",
            attrs={
                "__module__": PyStr(t="str", val="typing"),
                "__qualname__": PyStr(t="str", val="Generic"),
            },
        );
    }
    return _generic_class_cache as PyClass;
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

    # Identity hash: CPython property objects are set/dict-key legal.
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

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
        if name == "fset" {
            return self.fset if self.fset is not None else py_none();
        }
        if name == "fdel" {
            return self.fdel if self.fdel is not None else py_none();
        }
        # CPython property.__doc__: the getter's docstring (None when absent);
        # derived lazily so @x.setter chains keep the original doc for free.
        if name == "__doc__" {
            if self.fget is not None {
                doc = py_attr(self.fget as PyObj, "__doc__");
                if not is_error(doc) {
                    return doc;
                }
            }
            return py_none();
        }
        # ABC machinery reads this on every attribute walk of an abstract
        # base -- absent answers False unless any accessor declares itself
        # abstract (CPython property_init / prop_get___isabstractmethod__).
        if name == "__isabstractmethod__" {
            for acc in [self.fget, self.fset, self.fdel] {
                if acc is not None {
                    mark = py_attr(acc as PyObj, "__isabstractmethod__");
                    if not is_error(mark)
                        and isinstance(mark, PyBool)
                        and (mark as PyBool).val {
                        return mark;
                    }
                }
            }
            return PyBool(t="bool", val=False);
        }
        # The descriptor protocol surface itself: property.__get__/__set__/
        # __delete__ are real attributes in CPython (C.v.__get__(inst) runs the
        # accessor directly).
        if name == "__get__" or name == "__set__" or name == "__delete__" {
            return PyPropAccess(t="prop_access", prop=self, op=name);
        }
        # A property object is itself an object: its attribute protocol answers
        # through the same bound slot wrapper instances get.
        if name == "__getattribute__" {
            return PyObjectAttrSlot(t="obj_attr_slot", target=self as PyObj, op=name);
        }
        return py_error("AttributeError", name);
    }
}

# The bound property.__get__/__set__/__delete__ accessors (descriptor-protocol
# parity: the same operations implicit attribute dispatch uses, invocable by
# hand as CPython's slot wrappers are).
obj PyPropAccess(PyObj) {
    has prop: PyProperty,
        op: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        p = self.prop;
        if self.op == "__get__" {
            if len(args) < 1 {
                return py_error(
                    "TypeError",
                    "__get__ expected at least 1 argument, got " + str(len(args)),
                );
            }
            if isinstance(args[0], PyNoneType) {
                # obj.__get__(None, owner): class-level access returns the
                # property object itself.
                return p as PyObj;
            }
            if p.fget is None {
                return py_error("AttributeError", "property has no getter");
            }
            return py_invoke(p.fget as PyObj, [args[0]], {});
        }
        if self.op == "__set__" {
            if len(args) < 2 {
                return py_error(
                    "TypeError", "__set__ expected 2 arguments, got " + str(len(args))
                );
            }
            if p.fset is None {
                return py_error("AttributeError", "property has no setter");
            }
            return py_invoke(p.fset as PyObj, [args[0], args[1]], {});
        }
        if len(args) < 1 {
            return py_error(
                "TypeError",
                "__delete__ expected at least 1 argument, got " + str(len(args)),
            );
        }
        if p.fdel is None {
            return py_error("AttributeError", "property has no deleter");
        }
        return py_invoke(p.fdel as PyObj, [args[0]], {});
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

# Bound object.__getattribute__/__setattr__/__delattr__ over a native instance:
# the generic attribute protocol exposed AS attributes, exactly as CPython's
# slot wrappers are (hasattr(inst, '__getattribute__') is True). With target
# None it is the UNBOUND wrapper (object.__setattr__ read off the type); the
# receiver then comes from the first call argument. On a PyUserObj receiver it
# runs default_user_* directly -- the wrapper IS object.__*attr__, so a user
# override delegating through it must not re-enter itself.
obj PyObjectAttrSlot(PyObj) {
    has op: str,
        target: any = None;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        recv: PyObj;
        rest: list[PyObj] = [];
        if self.target is None {
            if len(args) < 1 {
                return py_error(
                    "TypeError", "unbound attribute slot needs an instance"
                );
            }
            recv = args[0];
            for i in range(1, len(args)) {
                rest.append(args[i]);
            }
        } else {
            recv = self.target as PyObj;
            rest.extend(args);
        }
        if self.op == "__getattribute__" {
            if len(rest) != 1 {
                return py_error(
                    "TypeError",
                    "__getattribute__ expected 1 argument, got " + str(len(rest)),
                );
            }
            name = expect_str(rest[0]);
            if isinstance(recv, PyUserObj) {
                return default_user_getattro(recv as PyUserObj, name);
            }
            return py_attr(recv, name);
        }
        if self.op == "__setattr__" {
            if len(rest) != 2 {
                return py_error(
                    "TypeError",
                    "__setattr__ expected 2 arguments, got " + str(len(rest)),
                );
            }
            name2 = expect_str(rest[0]);
            if isinstance(recv, PyUserObj) {
                return default_user_setattro(recv as PyUserObj, name2, rest[1]);
            }
            return py_set_attr(recv, name2, rest[1]);
        }
        if len(rest) != 1 {
            return py_error(
                "TypeError",
                "__delattr__ expected 1 argument, got " + str(len(rest)),
            );
        }
        name3 = expect_str(rest[0]);
        if isinstance(recv, PyUserObj) {
            return default_user_delattro(recv as PyUserObj, name3);
        }
        return py_del_attr(recv, name3);
    }
}

obj PyClassMethodCtor(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error(
                "TypeError", "classmethod expected 1 argument, got " + str(len(args))
            );
        }
        return PyClassMethod(t="classmethod", func=args[0]);
    }
}

obj PyStaticMethodCtor(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error(
                "TypeError", "staticmethod expected 1 argument, got " + str(len(args))
            );
        }
        return PyStaticMethod(t="staticmethod", func=args[0]);
    }
}

obj PyPropertyCtor(PyObj) {
    # Identity hash (CPython: builtin_function_or_method-style objects hash by
    # id) -- property/property-constructor objects live in sets and dict keys
    # across the stdlib (codec registries, ABC caches).
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        fget: PyObj = py_none();
        fset: PyObj = py_none();
        fdel: PyObj = py_none();
        if len(args) >= 1 {
            fget = args[0];
        }
        if len(args) >= 2 {
            fset = args[1];
        }
        if len(args) >= 3 {
            fdel = args[2];
        }
        if "fget" in kwargs {
            fget = kwargs["fget"];
        }
        if "fset" in kwargs {
            fset = kwargs["fset"];
        }
        if "fdel" in kwargs {
            fdel = kwargs["fdel"];
        }
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
# The ``__slots__`` member descriptor (CPython PyMemberDescr for T_OBJECT_EX
# slots): one per OWN declared slot, installed on the class at creation. It is a
# data descriptor -- reads/writes/deletes route through _get/_set/_del with the
# host-exact error surfaces -- and its storage lives on the instance attribute
# map under the (mangled) member name, filtered out of __dict__ views.
obj PyMemberDescr(PyObj) {
    has member: str,
        owner: str;

    def tp_getattro(name: str) -> PyObj {
        if name == "__name__" {
            return PyStr(t="str", val=self.member);
        }
        if name == "__qualname__" {
            return PyStr(t="str", val=self.owner + "." + self.member);
        }
        # The descriptor protocol surface itself: member.__get__/__set__/
        # __delete__ are invocable by hand in CPython (bound slot wrappers).
        if name == "__get__" or name == "__set__" or name == "__delete__" {
            return PyMemberAccess(t="member_access", descr=self, op=name);
        }
        return py_error("AttributeError", name);
    }

    def tp_str -> PyObj {
        return PyStr(
            t="str", val=type_slots_member_repr(self.member, self.owner)
        );
    }

    # slot-member read: unset raises the generic getattro message (host:
    # `'C' object has no attribute 'x'`).
    def _get(u: PyUserObj) -> PyObj {
        if self.member in u.attrs {
            return u.attrs[self.member];
        }
        return py_error(
            "AttributeError",
            "'" + self.owner + "' object has no attribute '" + self.member + "'",
        );
    }

    def _set(u: PyUserObj, value: PyObj) -> PyObj {
        u.attrs[self.member] = value;
        return py_none();
    }

    # Deleting an empty slot reports the bare member name (host:
    # `AttributeError: x`), unlike every other attr error.
    def _del(u: PyUserObj) -> PyObj {
        if self.member in u.attrs {
            del u.attrs[self.member];
            return py_none();
        }
        return py_error("AttributeError", self.member);
    }
}

# The bound member.__get__/__set__/__delete__ accessors (same descriptor-
# protocol parity pattern as PyPropAccess for property).
obj PyMemberAccess(PyObj) {
    has descr: PyMemberDescr,
        op: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        d = self.descr;
        if self.op == "__get__" {
            # (obj, owner); obj=None answers the descriptor itself.
            if len(args) < 1 or not isinstance(args[0], PyUserObj) {
                return d;
            }
            return d._get(args[0] as PyUserObj);
        }
        if self.op == "__set__" {
            if len(args) < 2 or not isinstance(args[0], PyUserObj) {
                return py_error(
                    "TypeError",
                    "__set__ takes (instance, value) -- descriptor '"
                        + d.member + "' of '" + d.owner + "' objects",
                );
            }
            return d._set(args[0] as PyUserObj, args[1]);
        }
        if len(args) < 1 or not isinstance(args[0], PyUserObj) {
            return py_error(
                "TypeError",
                "__delete__ takes (instance) -- descriptor '"
                    + d.member + "' of '" + d.owner + "' objects",
            );
        }
        return d._del(args[0] as PyUserObj);
    }
}

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
        attrs: dict[str, PyObj] = {},
        # Identity-stable live views minted on first read; invalidated by
        # explicit reassignment.
        kw_live: any = None,
        attr_dict_live: any = None;

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
            # An explicit f.__defaults__ assignment lands in attrs (checked
            # above); this branch serves the MAKE_FUNCTION-built table.
            if len(self.defaults) == 0 {
                return py_none();
            }
            return PyTuple(t="tuple", items=self.defaults);
        }
        if name == "__kwdefaults__" {
            # CPython: None when no keyword-only default exists; otherwise the
            # SAME live dict every read, whose mutations affect later calls.
            if len(self.kwdefaults) == 0 {
                return py_none();
            }
            if self.kw_live is not None {
                return self.kw_live as PyObj;
            }
            d = PyFuncKwDefaults(t="dict", owner=self, items={});
            for k in self.kwdefaults {
                hk = hashkey_str((PyStr(t="str", val=k)).tp_hashkey());
                d.items[hk] = DictEntry(
                    key=PyStr(t="str", val=k), value=self.kwdefaults[k]
                );
            }
            self.kw_live = d;
            return d as PyObj;
        }
        if name == "__closure__" {
            # CPython: None for functions without free variables, else a tuple
            # of cells (introspection surface used by inspect and functools).
            if len(self.closure) == 0 {
                return py_none();
            }
            return PyTuple(t="tuple", items=self.closure);
        }
        if name == "__code__" {
            return self.code;
        }
        if name == "__dict__" {
            # functools.wraps / update_wrapper reads and UPDATES a function's
            # __dict__ (WRAPPER_UPDATES), so the snapshot-per-read copy lost
            # every update -- CPython hands out the live attribute dict.
            # Fixed-surface names (__name__, __code__, ...) stay out of the
            # view exactly as they are absent from CPython's func_dict.
            if self.attr_dict_live is not None {
                return self.attr_dict_live as PyObj;
            }
            d = PyFuncDictView(t="dict", owner=self, items={});
            for k in self.attrs {
                if not func_attr_is_fixed(k) {
                    hk = hashkey_str((PyStr(t="str", val=k)).tp_hashkey());
                    d.items[hk] = DictEntry(
                        key=PyStr(t="str", val=k), value=self.attrs[k]
                    );
                }
            }
            self.attr_dict_live = d;
            return d as PyObj;
        }
        if name == "__wrapped__" {
            return py_error("AttributeError", name);
        }
        return py_error("AttributeError", name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        if name == "__kwdefaults__" {
            # Rebind: the call path resolves through attrs from now on, so the
            # old live view would go stale -- drop it.
            self.kw_live = None;
        }
        self.attrs[name] = value;
        # Dynamic attributes join the live __dict__ view; fixed-surface names
        # never appear in it (CPython keeps them on the type).
        if self.attr_dict_live is not None and not func_attr_is_fixed(name) {
            (self.attr_dict_live as PyFuncDictView).view_set(name, value);
        }
        return py_none();
    }

    # Effective default tables for THIS call: an explicit __defaults__ /
    # __kwdefaults__ attribute assignment overrides the MAKE_FUNCTION tables
    # (CPython binds those attributes to the call machinery).
    def _effective_defaults -> list[PyObj] {
        if "__defaults__" in self.attrs {
            v = self.attrs["__defaults__"];
            if v is not None and isinstance(v, PyTuple) {
                return (v as PyTuple).items;
            }
            return [];
        }
        return self.defaults;
    }

    def _effective_kwdefaults -> dict[str, PyObj] {
        if "__kwdefaults__" in self.attrs {
            v = self.attrs["__kwdefaults__"];
            if v is not None and isinstance(v, PyDict) {
                return (v as PyDict).dict_str_map();
            }
            return {};
        }
        return self.kwdefaults;
    }
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return exec_code_frame(
            self.code,
            args,
            kwargs,
            self.globals,
            {},
            self.closure,
            self._effective_defaults(),
            self._effective_kwdefaults()
        );
    }
}

def host_result_ok(result: any) -> bool {
    return result[0] == True;
}

# Function fixed-surface names: never visible in f.__dict__ (CPython stores
# them as type-level descriptors, not dict entries).
def func_attr_is_fixed(name: str) -> bool {
    return name in {
        "__name__", "__qualname__", "__doc__", "__module__",
        "__defaults__", "__kwdefaults__", "__code__", "__globals__",
        "__closure__", "__builtins__", "__dict__", "__wrapped__"
    };
}

# Live ``f.__dict__`` view: mutations write through to the function attribute
# map (minus the fixed surface) and attribute assignments reflect into it.
obj PyFuncDictView(PyDict) {
    # ``owner`` is typed ``any`` because a non-default field cannot follow the
    # inherited defaulted ``version`` field.
    has owner: any = None;

    def view_set(name: str, value: PyObj) {
        hk = hashkey_str((PyStr(t="str", val=name)).tp_hashkey());
        self.items[hk] = DictEntry(key=PyStr(t="str", val=name), value=value);
        self.version = self.version + 1;
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        hkr = index.tp_hashkey();
        if is_error(hkr) {
            return _unhashable_error("a dict key", index);
        }
        hk = hashkey_str(hkr);
        if isinstance(index, PyStr) {
            name = (index as PyStr).val;
            self.items[hk] = DictEntry(key=index, value=value);
            self.version = self.version + 1;
            if not func_attr_is_fixed(name) {
                (self.owner as PyFunction).attrs[name] = value;
            }
            return py_none();
        }
        self.items[hk] = DictEntry(key=index, value=value);
        self.version = self.version + 1;
        return py_none();
    }

    def mp_del_subscript(index: PyObj) -> PyObj {
        hkr = index.tp_hashkey();
        if is_error(hkr) {
            return _unhashable_error("a dict key", index);
        }
        hk = hashkey_str(hkr);
        if isinstance(index, PyStr) {
            name = (index as PyStr).val;
            owner_f = self.owner as PyFunction;
            if name in owner_f.attrs {
                del owner_f.attrs[name];
                del self.items[hk];
                self.version = self.version + 1;
                return py_none();
            }
        }
        if hk in self.items {
            del self.items[hk];
            self.version = self.version + 1;
            return py_none();
        }
        return py_error("KeyError", dict_key_repr(index));
    }
}

# Live ``__kwdefaults__`` view for a PyFunction: a real dict whose mutations
# write straight through to the function's kw-default table (CPython hands
# out the borrowed internal dict; later calls observe every change).
obj PyFuncKwDefaults(PyDict) {
    # ``owner`` is typed ``any`` because a non-default field cannot follow the
    # inherited defaulted ``version`` field.
    has owner: any = None;

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        hkr = index.tp_hashkey();
        if is_error(hkr) {
            return _unhashable_error("a dict key", index);
        }
        hk = hashkey_str(hkr);
        if isinstance(index, PyStr) {
            name = (index as PyStr).val;
            (self.owner as PyFunction).kwdefaults[name] = value;
        } else {
            return py_error(
                "TypeError", "keywords must be strings"
            );
        }
        self.items[hk] = DictEntry(key=index, value=value);
        self.version = self.version + 1;
        return py_none();
    }

    def mp_del_subscript(index: PyObj) -> PyObj {
        hkr = index.tp_hashkey();
        if is_error(hkr) {
            return _unhashable_error("a dict key", index);
        }
        hk = hashkey_str(hkr);
        if isinstance(index, PyStr) {
            name = (index as PyStr).val;
            owner_f = self.owner as PyFunction;
            if name in owner_f.kwdefaults {
                del owner_f.kwdefaults[name];
                del self.items[hk];
                self.version = self.version + 1;
                return py_none();
            }
        } elif hk in self.items {
            del self.items[hk];
            self.version = self.version + 1;
            return py_none();
        }
        return py_error("KeyError", dict_key_repr(index));
    }
}
# Cycle guard for from_host container conversion (host marshal/pickle can
# hand back SELF-REFERENTIAL structures, e.g. marshal.loads(b'[<R>]')). Keyed
# on host id(); list/dict/set placeholders are registered BEFORE filling so
# re-entry returns the same guest container (identity preserved); tuples are
# immutable so a re-entrant reference degrades to a host proxy instead of
# recursing forever.
glob _from_host_memo: dict[int, PyObj] = {};

# Process-wide mirror of the per-frame exc_handling stack: the exception
# currently being handled, for sys.exc_info()/traceback.format_exc(). Pushed at
# OP_PUSH_EXC_INFO, popped at OP_POP_EXCEPT. Divergence vs CPython: a generator
# suspended inside an except block keeps its entry visible to unrelated frames
# until it resumes/pops (single-threaded VM approximation).
glob _handled_exc_stack: list[PyObj] = [];

def current_handled_exc() -> PyObj {
    if len(_handled_exc_stack) == 0 {
        return py_none();
    }
    return _handled_exc_stack[len(_handled_exc_stack) - 1];
}

# Explicit opt-in live bridge (fp-e87c ContextVar cluster): consumers that need
# WRITE-THROUGH container crossing -- guest mutations visible to host code and
# vice versa -- call this INSTEAD of the default snapshot to_host arms. The
# default MUTABLE_COPY policy for plain list/dict/set stays untouched (existing
# consumers rely on snapshot isolation); live views are minted only through
# this explicit path. Returns None for anything not a live-viewable mutable
# container (frozenset included) so callers can fall back to to_host.
def live_container_bridge(value: PyObj) -> any {
    match value {
        case PyList():
            return _jac_make_live_list(value);
        case PyDict():
            return _jac_make_live_dict(value);
        case PySet():
            if not (value as PySet).frozen {
                return _jac_make_live_set(value as PySet);
            }
    }
    return None;
}

# Identity-counting removal of one occurrence per item: generator suspend must
# deactivate exactly ITS handler entries so unrelated frames stop seeing them
# (CPython exc_info is dynamic; the global stack is a single-threaded mirror).
def _handled_stack_remove_each(items: list[PyObj]) -> None {
    for it in items {
        idx = -1;
        i = 0;
        while i < len(_handled_exc_stack) {
            if py_identity(_handled_exc_stack[i], it) {
                idx = i;
                break;
            }
            i = i + 1;
        }
        if idx >= 0 {
            _handled_exc_stack = _handled_exc_stack[:idx] + _handled_exc_stack[idx + 1:];
        }
    }
}

def _handled_stack_append_each(items: list[PyObj]) -> None {
    for it in items {
        _handled_exc_stack.append(it);
    }
}

def from_host(raw: any) -> PyObj {
    if raw is None {
        return py_none();
    }
    # STANDIN round-trip: a host stand-in crossing back recovers the ORIGINAL
    # guest class/instance (identity preserved). The helper self-gates on
    # type/__dict__ presence so scalar/container fast paths stay cheap.
    g = _jac_recover_guest(raw);
    if g is not None {
        return g as PyObj;
    }
    # A host instance whose type is a PROPER subclass of a builtin container/
    # scalar (namedtuple, IntEnum, a host-built `class X(list)`) must not be
    # flattened into a native PyTuple/PyList/PyInt -- that would erase its real
    # type and its own descriptors. Keep it as a proxy so p.x / .name / repr all
    # route back to the host object. (A trampoline we minted is recovered first.)
    if _jac_is_builtin_subclass_instance(raw) {
        recovered = _jac_recover_native(raw);
        if recovered is not None {
            return recovered as PyObj;
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
        byte_values: list[int] = [];
        for item in raw {
            byte_values.append(item);
        }
        return PyBytes(t="bytes", val=byte_values);
    }
    if isinstance(raw, range) {
        # Native PyRange preserves identity AND laziness (TODO item 19): no
        # element drain -- start/stop/step carry all the information.
        return PyRange(t="range", start=raw.start, stop=raw.stop, step=raw.step);
    }
    if isinstance(raw, slice) {
        # A dynamic host slice (slice(1, 7, 2) built by bridged guest code)
        # materializes as a native PySlice: the subscript slots' slice branches
        # key on isinstance(PySlice), and a PyHostProxy here would make xs[s]
        # raise "list indices must be integers" while inline xs[1:7:2] works.
        return PySlice(
            t="slice",
            start=from_host(raw.start),
            stop=from_host(raw.stop),
            step=from_host(raw.step),
        );
    }
    if isinstance(raw, list) {
        memo_key = _jac_host_id(raw);
        if memo_key in _from_host_memo {
            return _from_host_memo[memo_key];
        }
        placeholder = PyList(t="list", items=[]);
        _from_host_memo[memo_key] = placeholder;
        for item in raw {
            (placeholder as PyList).items.append(from_host(item));
        }
        _from_host_memo.pop(memo_key);
        return placeholder;
    }
    if isinstance(raw, tuple) {
        memo_key = _jac_host_id(raw);
        if memo_key in _from_host_memo {
            # Immutable: a cycle through this tuple cannot be patched up
            # post-construction; degrade the re-entrant reference to a proxy.
            return PyHostProxy(t="host", val=raw);
        }
        _from_host_memo[memo_key] = PyNoneType(t="none");
        tuple_values: list[PyObj] = [];
        for item in raw {
            tuple_values.append(from_host(item));
        }
        _from_host_memo.pop(memo_key);
        return PyTuple(t="tuple", items=tuple_values);
    }
    if isinstance(raw, dict) {
        # Native PyDict now keys on the hash-key protocol, so any hashable key
        # (int, tuple, float, ...) lands natively. A key whose from_host wrapper
        # is unhashable (e.g. an opaque host object) keeps the whole dict opaque
        # as a PyHostProxy -- it round-trips through to_host unchanged.
        memo_key = _jac_host_id(raw);
        if memo_key in _from_host_memo {
            return _from_host_memo[memo_key];
        }
        native = PyDict(t="dict", items={});
        _from_host_memo[memo_key] = native;
        for key in raw {
            keyobj = from_host(key);
            if is_error(keyobj.tp_hashkey()) {
                _from_host_memo.pop(memo_key);
                return PyHostProxy(t="host", val=raw);
            }
            native.dict_set(keyobj, from_host(raw[key]));
        }
        _from_host_memo.pop(memo_key);
        return native;
    }
    if isinstance(raw, frozenset) {
        fs = PySet(t="frozenset", items={}, frozen=True);
        for member in raw {
            memberobj = from_host(member);
            if is_error(memberobj.tp_hashkey()) {
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
            if is_error(memberobj.tp_hashkey()) {
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
        return recovered as PyObj;
    }
    return PyHostProxy(t="host", val=raw);
}

# ================= typed guest<->host boundary table ========================
# ONE authoritative policy per native type tag. Every crossing decision lives
# here; ad-hoc match+fallthrough in to_host/_host_representable is gone. An
# unknown tag FAILS LOUDLY (RuntimeError naming the tag) -- it can never again
# silently degrade to None at the boundary.
#
# Policies:
#   VALUE_COPY   immutable scalar copied by value both ways (lossless)
#   DEEP_COPY    immutable aggregate deep-copied (tuple/frozenset/slice/range)
#   MUTABLE_COPY declared divergence: mutable container deep-copied; mutations
#                on either side DO NOT propagate (documented, greppable)
#   VIEW_COPY    dict view rebuilt as a live host view over a copied dict
#   TRAMPOLINE   callable becomes a host trampoline calling back into ceval
#   LAZY_ITER    iterator/generator becomes a LAZY host iterator sharing
#                position with the guest object (no silent draining/consuming)
#   STANDIN      name-faithful cached host stand-in (classes, plain user
#                objects); round-trips back to the original guest object
#   EXCEPTION    exception materializes as a real host BaseException via the
#                module-exception registry (exceptions_core.jac)
#   PROXY        opaque host-backed proxy passthrough (PyHostProxy)
#   FAIL         no host representation: loud RuntimeError naming the tag
enum BridgePolicy {
    VALUE_COPY,
    DEEP_COPY,
    MUTABLE_COPY,
    VIEW_COPY,
    TRAMPOLINE,
    LAZY_ITER,
    STANDIN,
    EXCEPTION,
    PROXY,
    FAIL,
}

def to_host_policy(tag: str) -> BridgePolicy {
    if tag == "none"
        or tag == "bool"
        or tag == "int"
        or tag == "float"
        or tag == "complex"
        or tag == "str"
        or tag == "bytes"
        or tag == "notimplemented" {
        return BridgePolicy.VALUE_COPY;
    }
    if tag == "tuple" or tag == "frozenset" or tag == "slice" or tag == "range" {
        return BridgePolicy.DEEP_COPY;
    }
    if tag == "list" or tag == "dict" or tag == "set" {
        return BridgePolicy.MUTABLE_COPY;
    }
    if tag == "mappingproxy" {
        return BridgePolicy.DEEP_COPY;
    }
    if tag == "dictview_obj" or tag == "globals" {
        return BridgePolicy.VIEW_COPY;
    }
    if tag == "function"
        or tag == "native_builtin"
        or tag == "bound_method"
        or tag == "gen_method"
        or tag == "list_method"
        or tag == "dict_method"
        or tag == "set_method"
        or tag == "native_new"
        or tag == "classmethod"
        or tag == "staticmethod"
        or tag == "classmethod_ctor"
        or tag == "staticmethod_ctor"
        or tag == "property_ctor"
        or tag == "property" {
        return BridgePolicy.TRAMPOLINE;
    }
    if tag == "iter"
        or tag == "seqiter"
        or tag == "rangeiter"
        or tag == "dictiter"
        or tag == "calliter"
        or tag == "generator" {
        return BridgePolicy.LAZY_ITER;
    }
    if tag == "class" or tag == "instance" {
        return BridgePolicy.STANDIN;
    }
    if tag == "exception" {
        return BridgePolicy.EXCEPTION;
    }
    if tag == "host" {
        return BridgePolicy.PROXY;
    }
    return BridgePolicy.FAIL;
}

def to_host(value: PyObj) -> any {
    # Table gate FIRST: an unknown tag fails loudly before any conversion runs.
    # A tag WITH policy but missing conversion arm below also fails loudly.
    policy = to_host_policy(value.t);
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
            tuple_items: list[any] = [];
            for item in value.items {
                tuple_items.append(to_host(item));
            }
            return tuple(tuple_items);

        case PyList():
            list_items: list[any] = [];
            for item in value.items {
                list_items.append(to_host(item));
            }
            return list_items;

        case PyDict():
            dict_items: dict[any, any] = {};
            for hk in value.items {
                `entry = value.items[hk];
                dict_items[to_host(`entry.key)] = to_host(`entry.value);
            }
            return dict_items;

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

        case PyRange():
            # A real host range, so host consumers see the reference type. Note:
            # a NEW host object per crossing -- identity does not round-trip
            # (accepted deviation D-RANGE-ID, docs/RANGE_BRIDGE_DESIGN.md).
            return range(value.start, value.stop, value.step);

        case PyFunction():
            # A native function crossing to the host becomes a trampoline that
            # calls back into ceval (see _jac_make_host_trampoline). This is what
            # lets host type()/classmethod/property/functools wrap and later
            # invoke jacpython functions -- the round-trip that unblocks
            # namedtuple's dynamic class creation and decorator machinery.
            return _jac_make_host_trampoline(value);

        case PyNativeBuiltin():
            # NB: Jac match has NO grouped/stacked case labels -- `case A():
            # case B(): body` gives ONLY B the body and silently drops A.
            # Each callable kind therefore carries its own (shared) arm.
            return _jac_make_host_trampoline(value);

        case PyBoundMethod():
            return _jac_make_host_trampoline(value);

        case PyGenMethod():
            # Native builtins/bound methods crossing to the host become
            # trampolines too (same round-trip as PyFunction): host code can
            # call them and from_host recovers the native via __jac_native__.
            return _jac_make_host_trampoline(value);

        case PyListMethod():
            return _jac_make_host_trampoline(value);

        case PyDictMethod():
            return _jac_make_host_trampoline(value);

        case PySetMethod():
            return _jac_make_host_trampoline(value);

        case PyStrMethod():
            return _jac_make_host_trampoline(value);

        case PyClassMethodCtor():
            # The classmethod/staticmethod/property builtin objects themselves
            # crossing to the host: trampoline replays their tp_call so the
            # host sees working descriptor factories.
            return _jac_make_host_trampoline(value);

        case PyStaticMethodCtor():
            return _jac_make_host_trampoline(value);

        case PyPropertyCtor():
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

        case PyMappingProxy():
            # Host mappingproxy over a converted copy of the wrapped dict:
            # read-only view semantics survive the boundary.
            return _jac_wrap_mappingproxy(to_host(value.target));

        case PyIter():
            # LAZY_ITER: a lazy host iterator sharing position with the guest
            # object -- no silent draining, and partial host consumption leaves
            # the remaining items for the guest (CPython iterator semantics).
            # One arm per iterator kind: seqiter/rangeiter/dictiter/calliter
            # are distinct obj types, and grouped labels would drop them all
            # but the last (see note at PyNativeBuiltin).
            return _jac_make_host_iterator(value);

        case PySeqIter():
            return _jac_make_host_iterator(value);

        case PyRangeIter():
            return _jac_make_host_iterator(value);

        case PyDictIter():
            return _jac_make_host_iterator(value);

        case PyCallableIter():
            return _jac_make_host_iterator(value);

        case PyClass():
            # STANDIN for the guest class object itself: a cached name-faithful
            # host class whose back-reference recovers the original on
            # round-trip (json/type()/isinstance machinery see a real type).
            return _jac_standin_class(value);

        case PyHostProxy():
            return value.val;

        case PyException():
            # A caught exception crossing to the host (str(e)/repr(e)/type(e), or
            # handed to host logging/warnings) becomes a REAL host exception
            # instance carrying the same args -- previously this fell through to
            # None, so str(e) was "None" and type(e) was NoneType.
            return host_exception(value);

        case PyClass():
            # STANDIN: the guest class itself crossing to the host gets its
            # cached name-faithful stand-in (same "class" policy-table entry
            # as instances; from_host recovers the original via
            # _jac_guest_cls_, so identity round-trips).
            return _jac_standin_class(value);

        case PyUserObj():
            # A builtin subclass reaching the host boundary (len/print/format)
            # presents as its boxed value; an exception-derived user instance
            # presents as a REAL host BaseException carrying its args -- so
            # str(e)/print(e) match CPython instead of degrading to None. Any
            # other plain user object gets a NAME-FAITHFUL cached host stand-in
            # whose back-reference recovers the original on round-trip.
            if value._has_base() {
                return to_host(value._base_obj());
            }
            if class_is_exception(value.cls) {
                return host_exception(user_exception_view(value));
            }
            return _jac_user_standin(value);

        case PyGenerator():
            if value.t == "coroutine" {
                # A guest coroutine crossing to the host becomes a REAL host
                # awaitable (send/throw/close/__await__, asyncio.iscoroutine
                # true) that marshals each drive into frame resumption -- never
                # drained: a coroutine is consumed by its own driver.
                return _jac_make_guest_coroutine(value);
            }
            if value.t == "async_generator" {
                return _jac_make_guest_async_generator(value);
            }
            # LAZY_ITER: a plain generator/genexpr crossing to the host is
            # driven ONE step per host __next__ through the real suspend/resume
            # machinery -- laziness preserved, no silent drain, shared
            # consumption position (islice-then-next keeps working).
            return _jac_make_host_iterator(value);


        case PyGlobalsProxy():
            # globals() crossing to host-delegated code stays LIVE: a snapshot
            # would silently drop host-side writes and guest-side visibility
            # (CPython passes the real module dict). See _jac_make_live_ns_view.
            return _jac_make_live_ns_view(value);

        case PyDictView():
            # Rebuild a real host dict and hand back the matching live view, so
            # both iteration (list()/sorted()/set()) AND repr round-trip: repr of
            # the result is `dict_keys([...])`/`dict_values([...])`/`dict_items([
            # ...])`, not a bare list. Order follows the dict's insertion order.
            hd: dict[any, any] = {};
            for hk in value.d.items {
                `entry = value.d.items[hk];
                hd[to_host(`entry.key)] = to_host(`entry.value);
            }
            if value.mode == "values" {
                return hd.values();
            }
            if value.mode == "items" {
                return hd.items();
            }
            return hd.keys();

        case PyNotImplementedSentinel():
            return _jac_notimpl_value();

    }
    # Unreachable for every tag with a table policy and a matching arm above;
    # both gaps fail LOUDLY here instead of degrading to None -- except the
    # TRAMPOLINE family's long tail: native module functions are dozens of
    # small wrapper objs tagged t="function"/"native_builtin" (PyWarningsWarnFn
    # & co) that no per-class case above can enumerate. Their policy already
    # declares the crossing semantics, so mint the same tp_call-backing
    # trampoline the dedicated arms use. Non-callable stragglers surface their
    # PyError at INVOCATION time (trampoline re-raises), not at crossing time.
    if policy == BridgePolicy.TRAMPOLINE {
        return _jac_make_host_trampoline(value);
    }
    raise RuntimeError(
        "bridge-table: type '"
        + value.t
        + "' has policy "
        + str(policy)
        + " but no to_host conversion arm"
    );
}

# Guest->host ARGUMENT channel (py_call_host, host binops, constructors, ...):
# a FAIL-policy operand surfaces as a guest-visible TypeError -- CPython also
# raises TypeError for unrepresentable arguments -- instead of unwinding the
# VM. Returns the host value, or a PyError the caller must propagate.
def to_host_coerce(value: PyObj) -> tuple[bool, any] {
    try {
        return (True, to_host(value));
    } except RuntimeError as e {
        return (False, py_error("TypeError", str(e)));
    }
}

# Host-boundary error conversion: the host shims report failures as
# (False, type_name, message[, live_exception]). When the live instance is
# present, keep it in `raw` with its full args tuple and host-computed str so a
# caught exception exposes real fields (e.errno, e.filename, ...) and byte-exact
# __str__ -- identical to how py_raise_value treats raised host exceptions.
def host_result_error(result: any) -> PyObj {
    if len(result) > 3 and result[3] is not None {
        inst = _jac_host_exception_instance(result[3]);
        if bool(inst[0]) {
            return PyError(
                t="error",
                exception=PyException(
                    t="exception",
                    type_name=str(result[1]),
                    message=str(inst[2]),
                    args=inst[3],
                    raw=PyHostProxy(t="host", val=result[3]),
                ),
            );
        }
    }
    return py_error(str(result[1]), str(result[2]));
}

def host_builtin(name: str) -> PyObj {
    # Identity memo: native builtins are singletons (CPython's builtin tables
    # hold one object per name). Minting a fresh wrapper per lookup breaks
    # identity idioms -- {property: 1}[property], `len is len`, etc.
    if name in native_builtin_cache {
        return native_builtin_cache[name] as PyObj;
    }
    built = _mint_host_builtin(name);
    if not is_error(built) {
        native_builtin_cache[name] = built;
    }
    return built;
}

glob native_builtin_cache: dict[str, PyObj] = {};

def _mint_host_builtin(name: str) -> PyObj {
    # The FULL builtin exception tree resolves to native PyExceptionType
    # markers: construction then runs the typed constructors (OSError
    # errno/strerror/filename forms, ImportError name/path, SyntaxError info,
    # Unicode*Error fields) with attributes served from type_fields, instead of
    # collapsing through a lossy host-proxy round-trip. Host-RAISED errors
    # still arrive with their live instance in `raw` (byte-exact str via the
    # boundary), and except-matching/isinstance/issubclass work across both
    # shapes through the shared name hierarchy.
    if is_builtin_exception_name(name) {
        return py_exception_type(name);
    }
    # next()/iter() are handled natively so a native generator or iterator is
    # driven one step in-VM instead of being drained across the host boundary.
    # sorted()/max()/min() are native so key=/reverse=/default= reach VM
    # callables: routed through the host, a key function (a PyFunction) cannot
    # cross the substrate boundary and was silently dropped.
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
    # dir() is native so it enumerates the NATIVE object surface (a PyUserObj's
    # class chain / a PyModule's namespace) instead of host dir() on a lossy
    # to_host copy -- and the no-arg form reads the CALLING frame's locals,
    # which only the ceval call site can see.
    # exec() is native so the namespace dicts stay LIVE: routed through the
    # host, they cross by copy and every top-level binding the executed code
    # makes (def/class/assignment) is lost before control returns.
    if name == "exec"
        or name == "next"
        or name == "iter"
        or name == "id"
        or name == "len"
        or name == "repr"
        or name == "hash"
        or name == "callable"
        or name == "isinstance"
        or name == "issubclass"
        or name == "getattr"
        or name == "setattr"
        or name == "hasattr"
        or name == "delattr"
        or name == "globals"
        or name == "sorted"
        or name == "max"
        or name == "min"
        or name == "dir"
        or name == "vars"
        or name == "anext"
        or name == "aiter" {
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
    return host_result_error(result);
}

def host_import(name: str, fromlist: PyObj) -> PyObj {
    if name == "weakref" and not ("weakref" in shim_modules) {
        # The host module's ref() sees to_host conversions (plain objects ->
        # None), so serve our identity-faithful shim instead.
        shim_modules["weakref"] = build_weakref_module();
    }
    if name == "heapq" and not ("heapq" in shim_modules) {
        # Same copy-mutation hazard as import_native: host heapq mutates a
        # copy of any guest list argument.
        shim_modules["heapq"] = build_heapq_module();
    }
    if name == "types" and not ("types" in shim_modules) {
        # The host types.coroutine cannot mark VM-native functions (it mutates
        # host code objects our PyFunction does not share), so its fallback
        # wrapper hands GET_AWAITABLE plain generators -- which must be
        # rejected. Serve a facade over the real module with the fast-path
        # semantics implemented natively. The layer3 boot path instead runs
        # the real types.py in-VM and overrides just the coroutine attribute.
        shim_modules["types"] = build_types_facade();
    }
    if name == "sys" and not ("sys" in shim_modules) {
        # Mirror of the import_native site: exception-state attrs must read
        # GUEST state.
        sysmod = delegated_module("sys");
        if not is_error(sysmod) {
            (sysmod as PyModule).attrs["exc_info"] = PyNativeBuiltin(
                t="native_builtin", name="exc_info"
            );
            (sysmod as PyModule).attrs["exception"] = PyNativeBuiltin(
                t="native_builtin", name="exception"
            );
            (sysmod as PyModule).attrs["intern"] = PyNativeBuiltin(
                t="native_builtin", name="intern"
            );
            (sysmod as PyModule).attrs["__jac_marker__"] = PyStr(t="str", val="installed");
            shim_modules["sys"] = sysmod;
        }
    }
    if name == "traceback" and not ("traceback" in shim_modules) {
        # Same rationale as the import_native site above: host traceback APIs
        # cannot accept native PyTraceback across the bridge.
        tbmod = PyModule(t="module", name="traceback", attrs=traceback_module_attrs());
        (tbmod as PyModule).attrs["format_exc"] = PyNativeBuiltin(
            t="native_builtin", name="tb_format_exc"
        );
        (tbmod as PyModule).attrs["print_exc"] = PyNativeBuiltin(
            t="native_builtin", name="tb_print_exc"
        );
        (tbmod as PyModule).attrs["print_exception"] = PyNativeBuiltin(
            t="native_builtin", name="tb_print_exc_legacy"
        );
        # Shim type markers: make exposed classes isinstance-matchable
        # (ratified exception/tb-surface scope; hot-path guard lives in
        # py_isinstance keyed on one t compare).
        tagmap = _tb_shim_type_tags();
        for tname in tagmap {
            raw_ctor = (tbmod as PyModule).attrs[tname];
            (tbmod as PyModule).attrs[tname] = ShimTypeMarker(
                t="shim_type_marker",
                tag=(tagmap[tname] as PyStr).val,
                ctor=raw_ctor,
            );
        }
        shim_modules["traceback"] = tbmod;
    }
    if name in shim_modules {
        return shim_modules[name];
    }
    if name in delegate_modules {
        return delegated_module(name);
    }
    result = _jac_host_import(name, to_host(fromlist));
    if host_result_ok(result) {
        return PyHostProxy(t="host", val=result[1]);
    }
    return host_result_error(result);
}

# LOAD_GLOBAL/LOAD_NAME fallthrough after locals/globals: builtins resolve
# here. A miss must surface as CPython's NameError, not the AttributeError the
# host getattr inside _jac_host_builtin would raise.
def load_name_fallback(name: str) -> PyObj {
    value = host_builtin(name);
    if is_error(value) {
        return py_error("NameError", "name '" + name + "' is not defined");
    }
    return value;
}

# type(obj): the object's type. A native user instance answers with its own
# PyClass; a class answers with its metaclass (or the host `type` for the default);
# everything else (scalars, proxied host values) round-trips through host type().
def py_type_of(o: PyObj) -> PyObj {
    if isinstance(o, PyUserObj) {
        return (o as PyUserObj).cls as PyObj;
    }
    if isinstance(o, PyClass) {
        m = (o as PyClass).metaclass;
        if m is not None and isinstance(m, PyClass) {
            return m as PyObj;
        }
        return host_builtin("type");
    }
    # CANONICAL exception type identity: type(ValueError("x")) must BE the
    # ValueError marker guests compare against (sys.exc_info()[0] is ValueError,
    # identity-keyed dispatch tables). The to_host fallthrough below would mint
    # a fresh host-type proxy -- right __name__, wrong identity.
    if isinstance(o, PyException) {
        e = o as PyException;
        if e.raw is not None and isinstance(e.raw, PyUserObj) {
            return (e.raw as PyUserObj).cls as PyObj;
        }
        return host_builtin(e.type_name);
    }
    # Native callable wrappers have no faithful host object (to_host drops
    # them), so answer with the matching HOST callable type instead of NoneType
    # via the to_host fallthrough. CPython distinguishes builtin_function_or_
    # method (builtins/bound builtins), method (bound user functions), and the
    # concrete iterator types.
    if isinstance(o, PyNativeBuiltin) or isinstance(o, PyListMethod)
        or isinstance(o, PyDictMethod) or isinstance(o, PySetMethod)
        or isinstance(o, PyStrMethod) {
        return from_host(_jac_builtin_function_or_method_type());
    }
    if isinstance(o, PyBoundMethod) or isinstance(o, PyGenMethod) {
        return from_host(_jac_bound_method_type());
    }
    if isinstance(o, PyIter) {
        return from_host(_jac_list_iterator_type());
    }
    if isinstance(o, PySeqIter) {
        # CPython: iter() over a __getitem__-only object is the plain
        # `iterator` type (PySeqIter_Type), not list_iterator.
        return from_host(_jac_seq_iterator_type());
    }
    if isinstance(o, PyGenerator) {
        # The three suspendable frame wrappers map to their real host types;
        # the to_host fallthrough would DRAIN them into a list ("list").
        gen = o as PyGenerator;
        if gen.t == "coroutine" {
            return from_host(_jac_coroutine_type());
        }
        if gen.t == "async_generator" {
            return from_host(_jac_async_generator_type());
        }
        return from_host(_jac_generator_type());
    }
    ho_r = to_host_coerce(o);
    ho = ho_r[1];
    if not ((ho_r[0] as bool)) {
        # A FAIL-tag operand has no host type answer at all (VM-internal tag);
        # degrade to `object` rather than the old lie of NoneType. Unreachable
        # for every tag guests can hold as a first-class value.
        return from_host(_jac_host_type(object()));
    }
    return from_host(_jac_host_type(ho));
}

# Build a real host exception instance from a native PyException, so the host's
# own str()/repr()/type()/isinstance machinery drives it. Uses the recorded args
# (falling back to `message` for VM-raised errors, which carry no args tuple). A
# non-builtin type_name (a user Exception subclass) can't be reconstructed as a
# host type, so it degrades to a plain Exception carrying the message -- enough
# for str()/repr(); `except <UserClass>` matching stays native (exception_matches
# uses the raw PyUserObj's MRO, never this host form).
def host_exception(exc: PyException) -> any {
    # An exception VIEW backed by an actual host instance (a host error that
    # crossed into the VM and is now crossing back out) presents the ORIGINAL
    # object -- identity/args/chaining/traceback all stay intact.
    if exc.raw is not None and isinstance(exc.raw, PyHostProxy) {
        return exc.raw.val;
    }
    raw_args: list[any] = [];
    for a in exc.args {
        raw_args.append(to_host(a));
    }
    if len(raw_args) == 0 and exc.message != "" {
        raw_args.append(exc.message);
    }
    built = _jac_construct_builtin(exc.type_name, raw_args);
    if bool(built[0]) {
        return built[1];
    }
    # Registry-aware materialization: registered module exceptions mint a
    # cached host subclass of their DECLARED BASE; user exception names mint a
    # cached same-name Exception subclass. A name that survives neither the
    # builtin lookup nor minting FAILS LOUDLY -- the boundary never degrades a
    # caught exception to a generic Exception() (which erased its hierarchy).
    maker_result = _jac_instantiate_registered_exception(exc.type_name, raw_args);
    if bool(maker_result[0]) {
        return maker_result[1];
    }
    raise RuntimeError(
        "bridge-table: no host exception type for '" + exc.type_name + "'"
    );
}

# f-string / format() machinery. The __format__ / __str__ protocols resolve
# NATIVELY for user instances (to_host of a plain user object is None -- the
# host bridge would answer on a lost value); everything else stays delegated
# to host CPython's format()/repr()/ascii(), which keeps objects.jac na-clean.
def host_format(value: PyObj, spec: str) -> PyObj {
    if isinstance(value, PyUserObj) {
        u = value as PyUserObj;
        # An explicit __format__ receives the raw spec (empty included) and its
        # result must be str; a raised exception propagates verbatim.
        if user_has_dunder(u, "__format__") {
            res = call_user_dunder(u, "__format__", [PyStr(t="str", val=spec)]);
            if is_error(res) {
                return res;
            }
            if isinstance(res, PyStr) {
                return res;
            }
            return py_error(
                "TypeError",
                "__format__ must return a str, not " + _slot_result_type_name(res),
            );
        }
        # object.__format__: empty spec delegates exactly like str(); a non-
        # empty spec is CPython's TypeError verbatim.
        if spec != "" {
            return py_error(
                "TypeError",
                "unsupported format string passed to " + u.cls.name + ".__format__",
            );
        }
        return py_str(value);
    }
    hv_r = to_host_coerce(value);
    hv = hv_r[1];
    if not ((hv_r[0] as bool)) {
        return hv_r[1] as PyObj;
    }
    result = _jac_host_format(hv, spec);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return host_result_error(result);
}

def host_convert(value: PyObj, conv: int) -> PyObj {
    # str()/repr() over a native user instance answer in-VM (see host_format);
    # ascii() keeps the host path (its non-ASCII escaping is not ported).
    if isinstance(value, PyUserObj) {
        if conv == 1 {
            return py_str(value);
        }
        if conv == 2 {
            return py_repr(value);
        }
    }
    # A member descriptor converts to its repr form on BOTH str() and repr()
    # (host: str(C.__dict__['x']) == repr(C.__dict__['x'])).
    if isinstance(value, PyMemberDescr) {
        return py_repr(value);
    }
    hv_r = to_host_coerce(value);
    if not ((hv_r[0] as bool)) {
        return hv_r[1] as PyObj;
    }
    result = _jac_host_convert(hv_r[1], conv);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return host_result_error(result);
}

def host_getattr(value: PyObj, name: str) -> PyObj {
    hv_r = to_host_coerce(value);
    hv = hv_r[1];
    if not ((hv_r[0] as bool)) {
        return hv_r[1] as PyObj;
    }
    result = _jac_host_getattr(hv, name);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return host_result_error(result);
}

def host_getitem(value: PyObj, index: PyObj) -> PyObj {
    hv_r = to_host_coerce(value);
    hv = hv_r[1];
    if not ((hv_r[0] as bool)) {
        return hv_r[1] as PyObj;
    }
    hi_r = to_host_coerce(index);
    hi = hi_r[1];
    if not ((hi_r[0] as bool)) {
        return hi_r[1] as PyObj;
    }
    result = _jac_host_getitem(hv, hi);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return host_result_error(result);
}

def host_setattr(value: PyObj, name: str, field: PyObj) -> PyObj {
    hv_r = to_host_coerce(value);
    hv = hv_r[1];
    if not ((hv_r[0] as bool)) {
        return hv_r[1] as PyObj;
    }
    hf_r = to_host_coerce(field);
    hf = hf_r[1];
    if not ((hf_r[0] as bool)) {
        return hf_r[1] as PyObj;
    }
    result = _jac_host_setattr(hv, name, hf);
    if host_result_ok(result) {
        return py_none();
    }
    return host_result_error(result);
}


# ---------------- ceval ----------------
# Opcode numbers and cache metadata: opcode_meta.jac (PLAN.md P0.1).

# ---------------- implicit type-slot machinery ------------------------------
# CPython fills each type's slots (tp_bool/sq_contains/nb_int/nb_float/tp_hash)
# from dunder presence when the heap type is created. jacpython's heap types
# (PyClass/PyUserObj) have no frozen vtable to patch: the same protocols resolve
# through MRO dunder lookup AT DISPATCH, funneled through the helpers below so
# every entry point -- branch truthiness, bool(), `in`, hash()/dict-keying,
# int()/float() -- shares one set of semantics.

# Truthiness slot (nb_bool + sq_length; CPython PyObject_IsTrue): __bool__,
# then __len__, then a boxed builtin base's own truthiness, then True.
def py_slot_truth(value: PyObj) -> PyObj {
    if isinstance(value, PyUserObj) {
        u = value as PyUserObj;
        if user_has_dunder(u, "__bool__") {
            res = call_user_dunder(u, "__bool__", []);
            if is_error(res) {
                return res;
            }
            if isinstance(res, PyBool) {
                return res;
            }
            return py_error("TypeError", "__bool__ should return bool");
        }
        if user_has_dunder(u, "__len__") {
            ln = py_len(value);
            if is_error(ln) {
                return ln;
            }
            return PyBool(t="bool", val=(ln as PyInt).val != 0);
        }
        if u._has_base() {
            return py_slot_truth(u._base_obj());
        }
        return PyBool(t="bool", val=True);
    }
    # A read-only mapping view is truthy iff its dict is (len-based).
    if isinstance(value, PyMappingProxy) {
        ln = py_len((value as PyMappingProxy).target as PyObj);
        if is_error(ln) {
            return ln;
        }
        return PyBool(t="bool", val=(ln as PyInt).val != 0);
    }
    return PyBool(t="bool", val=value.tp_bool());
}

# True iff the boxed builtin base supplies its own number slot that a heap
# subclass inherits wholesale (CPython typeobject.c inherit_special copies
# tp_as_number; update_one_slot resolves __int__/__float__ wrappers from the
# base's tp_dict): int/bool carry long's slots, float carries its own. Such an
# inherited slot PREEMPTS a user-defined __index__ -- PyNumber_Long/
# PyNumber_Float consult nb_index only when nb_int/nb_float is absent -- while
# non-number bases (str/list/dict, ...) do not.
def boxed_number_base(u: PyUserObj) -> bool {
    if not u._has_base() {
        return False;
    }
    b = u._base_obj();
    return isinstance(b, PyInt) or isinstance(b, PyBool) or isinstance(b, PyFloat);
}

# int(x) conversion slot (nb_int over dunders): __int__ first, then an
# inherited builtin number slot, then the index slot; nothing applicable is
# CPython's TypeError.
def py_convert_int(x: PyObj) -> PyObj {
    if isinstance(x, PyUserObj) {
        u = x as PyUserObj;
        # CPython abstract.c PyNumber_Long: once nb_int exists its result and
        # its exceptions are final -- __index__ is tried only when nb_int is
        # absent entirely.
        if user_has_dunder(u, "__int__") {
            res = call_user_dunder(u, "__int__", []);
            if is_error(res) {
                return res;
            }
            if isinstance(res, PyBool) {
                return PyInt(t="int", val=1 if (res as PyBool).val else 0);
            }
            if isinstance(res, PyInt) {
                return res;
            }
            return py_error(
                "TypeError", "__int__ returned non-int (type " + res.t + ")"
            );
        }
        # A builtin number base's own slot is inherited by the subclass.
        if boxed_number_base(u) {
            return py_convert_int(u._base_obj());
        }
        # No nb_int anywhere in the hierarchy: nb_index next; its exceptions
        # and non-int reports propagate verbatim (PyNumber_Index).
        if user_has_dunder(u, "__index__") {
            return (u as PyObj).to_index();
        }
        # Remaining bases convert on their own terms (str/bytes parsing, ...);
        # none applicable is CPython's final TypeError.
        if u._has_base() {
            return py_convert_int(u._base_obj());
        }
        return py_error(
            "TypeError",
            "int() argument must be a string, a bytes-like object or a real number, not '"
                + u.cls.name + "'",
        );
    }
    return py_host_convert("int", x);
}

# float(x) conversion slot (nb_float over dunders): __float__ first, then an
# inherited builtin number slot, then the index slot; nothing applicable is
# CPython's TypeError.
# Native complex() constructor over native operands (PyHostProxy.tp_call
# interception). PY_NOT_IMPLEMENTED marks shapes with no native answer --
# bytes, kwargs, user/host objects, the both-imag-parts deprecation combo --
# so the caller falls through to the host call and keeps CPython's exact
# behavior including its TypeErrors.
def _complex_arg_parts(x: PyObj) -> tuple[bool, float, float] {
    if isinstance(x, PyComplex) {
        c = x as PyComplex;
        return (True, c.real, c.imag);
    }
    if isinstance(x, PyFloat) {
        return (True, (x as PyFloat).val, 0.0);
    }
    if isinstance(x, PyInt) {
        return (True, float((x as PyInt).val), 0.0);
    }
    if isinstance(x, PyBool) {
        if (x as PyBool).val {
            return (True, 1.0, 0.0);
        }
        return (True, 0.0, 0.0);
    }
    return (False, 0.0, 0.0);
}

def py_convert_complex(args: list[PyObj]) -> PyObj {
    n = len(args);
    if n > 2 {
        return py_error(
            "TypeError",
            "complex() takes at most 2 arguments (" + str(n) + " given)",
        );
    }
    if n == 0 {
        return PyComplex(t="complex", real=0.0, imag=0.0);
    }
    a = args[0];
    if isinstance(a, PyStr) {
        if n == 2 {
            return py_error(
                "TypeError", "complex() argument 'real' must be a real number, not str"
            );
        }
        (ok, err, re, im) = complex_parse_text((a as PyStr).val);
        if not ok {
            return py_error("ValueError", err);
        }
        return PyComplex(t="complex", real=re, imag=im);
    }
    (ok1, r1, i1) = _complex_arg_parts(a);
    if not ok1 {
        return PY_NOT_IMPLEMENTED;
    }
    if n == 1 {
        # A complex argument is copied whole; reals get a FRESH +0 imaginary
        # (complex(-0.0) == -0+0j -- the sign does NOT propagate).
        if isinstance(a, PyComplex) {
            c = a as PyComplex;
            return PyComplex(t="complex", real=c.real, imag=c.imag);
        }
        return PyComplex(t="complex", real=r1, imag=0.0);
    }
    (ok2, r2, i2) = _complex_arg_parts(args[1]);
    if not ok2 {
        return PY_NOT_IMPLEMENTED;
    }
    # Two-arg forms preserve signed zeros exactly like CPython: real x real
    # copies both parts verbatim (complex(3, -0.0) == 3-0j), while a complex
    # first arg adds the second operand to its imaginary part
    # (complex(1+2j, 3) == 1+5j). Two imaginary parts are the deprecated
    # combo and stay host-routed.
    if i1 != 0.0 and i2 != 0.0 {
        return PY_NOT_IMPLEMENTED;
    }
    if isinstance(a, PyComplex) {
        return PyComplex(t="complex", real=r1, imag=i1 + r2);
    }
    return PyComplex(t="complex", real=r1, imag=r2);
}

def py_convert_float(x: PyObj) -> PyObj {
    if isinstance(x, PyUserObj) {
        u = x as PyUserObj;
        # CPython abstract.c PyNumber_Float: once nb_float exists its result and
        # exceptions are final -- nb_index is tried only when nb_float is
        # absent entirely.
        if user_has_dunder(u, "__float__") {
            res = call_user_dunder(u, "__float__", []);
            if is_error(res) {
                return res;
            }
            if isinstance(res, PyFloat) {
                return res;
            }
            return py_error(
                "TypeError",
                u.cls.name + ".__float__ returned non-float (type " + res.t + ")"
            );
        }
        # A builtin number base's own slot is inherited by the subclass.
        if boxed_number_base(u) {
            return py_convert_float(u._base_obj());
        }
        # No nb_float anywhere in the hierarchy: nb_index next; its exceptions
        # and non-int reports propagate verbatim (PyNumber_Index).
        if user_has_dunder(u, "__index__") {
            idx = (u as PyObj).to_index();
            if is_error(idx) {
                return idx;
            }
            return PyFloat(t="float", val=float((idx as PyInt).val));
        }
        # Remaining bases convert on their own terms (str parsing, ...); none
        # applicable is CPython's final TypeError (PyNumber_Float falls back to
        # PyFloat_FromString, which the host constructor path reproduces).
        if u._has_base() {
            return py_convert_float(u._base_obj());
        }
        return py_error(
            "TypeError",
            "float() argument must be a string or a real number, not '"
                + u.cls.name + "'",
        );
    }
    # Plain int: guard the host conversion so oversized ints raise the
    # guest-exact OverflowError instead of an escaping host error.
    if isinstance(x, PyInt) {
        try {
            return PyFloat(t="float", val=float((x as PyInt).val));
        } except OverflowError {
            return py_error("OverflowError", "int too large to convert to float");
        }
    }
    return py_host_convert("float", x);
}

# The host constructor of `name` over a value with no native slot answer
# (str/bytes parsing, float truncation, opaque proxies). Exact legacy behavior.
def py_host_convert(name: str, x: PyObj) -> PyObj {
    result = _jac_host_builtin(name);
    if host_result_ok(result) {
        fn = PyHostProxy(t="host", val=result[1]);
        return fn.tp_call([x], {});
    }
    return host_result_error(result);
}

# A key/value that is NOT a builtin (a user object or a host proxy) can carry a
# custom __eq__, so the hashkey-bucket match must be confirmed with a real
# comparison. Between two builtins the hashkey protocol already IS value equality
# (numeric collapse included), so the confirming eq is skipped -- the fast path.
def _needs_eq_confirm(o: PyObj) -> bool {
    return isinstance(o, PyUserObj) or isinstance(o, PyHostProxy);
}

# CPython tuple_repr: trailing comma for length-1 tuples.
def tuple_repr(v: PyTuple) -> PyObj {
    if len(v.items) == 0 {
        return PyStr(t="str", val="()");
    }
    out = "(";
    i = 0;
    while i < len(v.items) {
        if i > 0 {
            out = out + ", ";
        }
        piece = py_repr(v.items[i]);
        if is_error(piece) {
            return piece;
        }
        out = out + (piece as PyStr).val;
        i = i + 1;
    }
    if len(v.items) == 1 {
        out = out + ",";
    }
    return PyStr(t="str", val=out + ")");
}

# ---------------- tp_str/tp_repr/tp_format slots -----------------------------
# Same implicit-slot convention as py_slot_truth/py_convert_int: heap types
# have no frozen vtable, so __str__/__repr__/__format__ resolve through MRO
# dunder lookup AT DISPATCH (never instance getattribute), before any to_host
# bridging -- a plain user object marshals as None, so the host would answer
# 'None' or raise on a lost value.

# CPython type name of a slot RESULT for the __str__/__repr__ non-string TypeErrors.
def _slot_result_type_name(v: PyObj) -> str {
    if isinstance(v, PyUserObj) {
        return (v as PyUserObj).cls.name;
    }
    if isinstance(v, PyClass) {
        return (v as PyClass).name;
    }
    return _base_type_name(v);
}

# True iff a str-% argument carries a native user instance whose %s/%r piece
# needs slot dispatch (scalar-only args stay on the lifted fast path). One level
# of tuple/dict nesting is scanned; deeper nesting remains a residual.
def mod_args_need_user_slots(args: PyObj) -> bool {
    if isinstance(args, PyUserObj) {
        return True;
    }
    if isinstance(args, PyTuple) {
        for item in (args as PyTuple).items {
            if isinstance(item, PyUserObj) {
                return True;
            }
        }
        return False;
    }
    if isinstance(args, PyDict) {
        for hk in (args as PyDict).items {
            pair = (args as PyDict).items[hk];
            if isinstance(pair.value, PyUserObj) {
                return True;
            }
        }
    }
    return False;
}

# CPython object.__repr__: '<module.Class object at 0x..>' (bare class name when
# no __module__), address = lowercase hex of id(), byte-exact vs the host.
def default_obj_repr_text(u: PyUserObj) -> str {
    mod = "";
    if "__module__" in u.cls.attrs {
        m = u.cls.attrs["__module__"];
        if isinstance(m, PyStr) {
            mod = (m as PyStr).val;
        }
    }
    return "<" + type_tp_name(u.cls.name, mod) + " object at 0x"
        + _uint_to_str(py_id(u as PyObj), 16, "0123456789abcdef") + ">";
}

# The repr slot: explicit __repr__, then a boxed builtin base's own repr,
# then the default identity form.
def user_repr_slot(u: PyUserObj) -> PyObj {
    if user_has_dunder(u, "__repr__") {
        res = call_user_dunder(u, "__repr__", []);
        if is_error(res) {
            return res;
        }
        if isinstance(res, PyStr) {
            return res;
        }
        return py_error(
            "TypeError",
            "__repr__ returned non-string (type '" + _slot_result_type_name(res)
                + "')",
        );
    }
    # A builtin-exception ancestor contributes ITS repr slot even though
    # Exception is not a boxed-layout native base (native_base stays ""), so
    # route through the same view the raise path wraps raised instances in.
    # CPython heap subclasses of Exception inherit BaseException's tp_repr.
    if class_is_exception(u.cls) {
        return baseexception_repr(user_exception_view(u), py_repr);
    }
    if u._has_base() {
        return py_repr(u._base_obj());
    }
    return PyStr(t="str", val=default_obj_repr_text(u));
}

# The str slot: explicit __str__, else the type's repr slot (object.__str__ IS
# object.__repr__ in CPython, including the default identity form).
def user_str_slot(u: PyUserObj) -> PyObj {
    if user_has_dunder(u, "__str__") {
        res = call_user_dunder(u, "__str__", []);
        if is_error(res) {
            return res;
        }
        if isinstance(res, PyStr) {
            return res;
        }
        return py_error(
            "TypeError",
            "__str__ returned non-string (type '" + _slot_result_type_name(res)
                + "')",
        );
    }
    # A boxed builtin base contributes ITS str slot (str.__str__ returns the
    # value itself: str(SS('ab')) == 'ab', not repr); only object.__str__ -- the
    # no-base case -- collapses to the repr form above.
    if u._has_base() {
        return py_str(u._base_obj());
    }
    # Same inherited-slot rule for str: BaseException_str (+ the per-type forms
    # like KeyError repr-of-payload) applies pre-raise too.
    if class_is_exception(u.cls) {
        return baseexception_str(user_exception_view(u), py_repr, py_str);
    }
    return user_repr_slot(u);
}

# Native str(): exceptions read their args natively, user instances through the
# str slot; every other shape has a faithful host form and delegates so the
# bytes stay exact CPython.
def py_str(value: PyObj) -> PyObj {
    if isinstance(value, PyException) {
        exc = value as PyException;
        # Host-raised instance (raw is a PyHostProxy): byte-exact str straight
        # from the live object. A PyUserObj raw (guest user exception) keeps
        # the native dispatch below.
        if isinstance(exc.raw, PyHostProxy) {
            return host_convert(exc.raw as PyObj, 1);
        }
        # A raised guest user exception keeps its live instance in `raw`; an
        # explicit __str__ on the class overrides the inherited BaseException
        # slots (CPython MRO lookup), so dispatch through the user slot.
        if isinstance(exc.raw, PyUserObj)
            and user_has_dunder(exc.raw as PyUserObj, "__str__") {
            return user_str_slot(exc.raw as PyUserObj);
        }
        return baseexception_str(exc, py_repr, py_str);
    }
    if isinstance(value, PyUserObj) {
        return user_str_slot(value as PyUserObj);
    }
    # TypeVar has no __str__ of its own; object.__str__ falls back to tp_repr,
    # so str(T) == 'T' byte-exact. Same for the generic-alias stand-in and the
    # NoDefault sentinel.
    if isinstance(value, PyTypeVar)
        or isinstance(value, PyGenericAlias)
        or isinstance(value, PyNoDefault) {
        return py_repr(value);
    }
    if isinstance(value, PyComplex) {
        # CPython complex_str IS complex_repr (same paren rules as repr).
        return PyStr(t="str", val=complex_repr_text(value as PyComplex));
    }
    # A member descriptor's str is its repr (host: str(C.__dict__['x']) ==
    # "<member 'x' of 'C' objects>").
    if isinstance(value, PyMemberDescr) {
        return py_repr(value);
    }
    # Containers have no tp_str in CPython: str == repr, answered in-VM so
    # self-referential structures hit the repr cycle guards instead of
    # recursing unbounded inside to_host conversion.
    if isinstance(value, PyDict) or isinstance(value, PyList)
        or isinstance(value, PyTuple) or isinstance(value, PyMappingProxy) {
        return py_repr(value);
    }
    return host_convert(value, 1);
}

# Native repr(): scalars, containers, class + user __repr__ in-VM; remainder
# falls back to host_convert(..., 2).
def py_obj_is_type(value: PyObj) -> bool {
    if isinstance(value, PyClass) {
        return True;
    }
    if isinstance(value, PyHostProxy) {
        return bool(_jac_host_val_is_type((value as PyHostProxy).val));
    }
    return False;
}

def py_type_same(a: PyObj, b: PyObj) -> bool {
    if a is b {
        return True;
    }
    if isinstance(a, PyHostProxy) and isinstance(b, PyHostProxy) {
        return (a as PyHostProxy).val is (b as PyHostProxy).val;
    }
    return False;
}

def py_repr(value: PyObj) -> PyObj {
    if isinstance(value, PyException) {
        exc = value as PyException;
        # Same override rule as py_str: an explicit __repr__ on a raised guest
        # user exception's class beats the inherited BaseException repr slot.
        if isinstance(exc.raw, PyUserObj)
            and user_has_dunder(exc.raw as PyUserObj, "__repr__") {
            return user_repr_slot(exc.raw as PyUserObj);
        }
        return baseexception_repr(value as PyException, py_repr);
    }
    if isinstance(value, PyRange) {
        rg = value as PyRange;
        # CPython range_repr: ALWAYS two-arg when step==1 -- there is no
        # stop-only form (host oracle: repr(range(5)) == 'range(0, 5)').
        if rg.step == 1 {
            return PyStr(
                t="str",
                val="range(" + str(rg.start) + ", " + str(rg.stop) + ")",
            );
        }
        return PyStr(
            t="str",
            val="range("
                + str(rg.start)
                + ", "
                + str(rg.stop)
                + ", "
                + str(rg.step)
                + ")",
        );
    }
    # CPython TypeAliasType_repr prints the bare alias name (repr(type X = int
    # alias) == 'X'), never a qualified or angled form.
    if isinstance(value, PyTypeAlias) {
        return PyStr(t="str", val=(value as PyTypeAlias).name);
    }
    # CPython typing.TypeVar.__repr__ for implicit PEP 695 parameters prints
    # the bare name (module 'typing'); '~T' belongs to explicitly-constructed
    # TypeVars outside typing.
    if isinstance(value, PyTypeVar) {
        return PyStr(t="str", val=(value as PyTypeVar).name);
    }
    # CPython _GenericAlias.__repr__ for the implicit generic base prints
    # 'typing.Generic[T, ...]'; str falls back to the same (no __str__).
    if isinstance(value, PyGenericAlias) {
        parts: list[str] = [];
        for gp in ((value as PyGenericAlias).params as PyTuple).items {
            r = py_repr(gp);
            if is_error(r) {
                return r;
            }
            parts.append((r as PyStr).val);
        }
        return PyStr(t="str", val="typing.Generic[" + ", ".join(parts) + "]");
    }
    # typing.NoDefault: repr and str are both 'typing.NoDefault'.
    if isinstance(value, PyNoDefault) {
        return PyStr(t="str", val="typing.NoDefault");
    }
    if isinstance(value, PyTuple) {
        return tuple_repr(value as PyTuple);
    }
    if isinstance(value, PyList) {
        return list_repr(value as PyList, py_repr);
    }
    if isinstance(value, PyBytes) {
        return bytes_repr(value as PyBytes);
    }
    if isinstance(value, PyDict) {
        return dict_repr(value as PyDict, py_repr);
    }
    if isinstance(value, PyMappingProxy) {
        inner = dict_repr((value as PyMappingProxy).target, py_repr);
        return PyStr(t="str", val="mappingproxy(" + str_value(inner) + ")");
    }
    if isinstance(value, PyClass) {
        c = value as PyClass;
        mod = "";
        if "__module__" in c.attrs {
            m = c.attrs["__module__"];
            if isinstance(m, PyStr) {
                mod = (m as PyStr).val;
            }
        } elif "__name__" in c.attrs {
            m = c.attrs["__name__"];
            if isinstance(m, PyStr) {
                mod = (m as PyStr).val;
            }
        }
        return type_repr(type_tp_name(c.name, mod));
    }
    if isinstance(value, PyMemberDescr) {
        m = value as PyMemberDescr;
        return PyStr(
            t="str", val=type_slots_member_repr(m.member, m.owner)
        );
    }
    if isinstance(value, PyStr) {
        return str_repr(value as PyStr);
    }
    if isinstance(value, PyInt) {
        return int_repr(value as PyInt);
    }
    if isinstance(value, PyFloat) {
        return float_repr(value as PyFloat);
    }
    if isinstance(value, PyComplex) {
        # CPython complex_str IS complex_repr; built in-VM for paren rules.
        return PyStr(t="str", val=complex_repr_text(value as PyComplex));
    }
    if isinstance(value, PyBool) or isinstance(value, PyNoneType) {
        return PyStr(t="str", val=_pyobj_repr(value));
    }
    if isinstance(value, PyUserObj) {
        return user_repr_slot(value as PyUserObj);
    }
    # Native bound-method/builtin wrappers have no faithful host form (to_host
    # drops them to None, which would repr as 'None'), so synthesize the
    # CPython-style repr minus the embedded address.
    if isinstance(value, PyListMethod) {
        return PyStr(t="str", val="<built-in method " + (value as PyListMethod).name + " of list object>");
    }
    if isinstance(value, PyStrMethod) {
        return PyStr(t="str", val="<built-in method " + (value as PyStrMethod).name + " of str object>");
    }
    if isinstance(value, PyDictMethod) {
        return PyStr(t="str", val="<built-in method " + (value as PyDictMethod).name + " of dict object>");
    }
    if isinstance(value, PySetMethod) {
        return PyStr(t="str", val="<built-in method " + (value as PySetMethod).name + " of set object>");
    }
    if isinstance(value, PyNativeBuiltin) {
        return PyStr(t="str", val="<built-in function " + (value as PyNativeBuiltin).name + ">");
    }
    if isinstance(value, PyIter) {
        # repr is observational: it must NOT route through to_host, whose drain
        # would exhaust the iterator as a side effect.
        return PyStr(t="str", val="<iterator object>");
    }
    result = host_convert(value, 2);
    if is_error(result) {
        return result;
    }
    return result;
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
    if isinstance(lhs, PyMappingProxy) {
        lhs = (lhs as PyMappingProxy).target;
    }
    if isinstance(rhs, PyMappingProxy) {
        rhs = (rhs as PyMappingProxy).target;
    }
    if isinstance(lhs, PyDict) and isinstance(rhs, PyDict) {
        return dict_richcompare(kind, lhs as PyDict, rhs as PyDict, py_compare);
    }
    if isinstance(lhs, PyList) and isinstance(rhs, PyList) {
        return list_richcompare(kind, lhs as PyList, rhs as PyList, py_compare);
    }
    if isinstance(lhs, PyTuple) and isinstance(rhs, PyTuple) {
        return tuple_richcompare(kind, lhs as PyTuple, rhs as PyTuple);
    }
    if isinstance(lhs, PyBytes) and isinstance(rhs, PyBytes) {
        return bytes_richcompare(kind, lhs as PyBytes, rhs as PyBytes);
    }
    # Native bytes vs a host-proxied bytes-like (bytearray): CPython makes
    # them mutually comparable; the generic fallthrough degrades to identity
    # for == and TypeError for ordering (item 27 bytearray half).
    if isinstance(lhs, PyBytes) != isinstance(rhs, PyBytes)
        and (isinstance(lhs, PyHostProxy) or isinstance(rhs, PyHostProxy)) {
        hl_r = to_host_coerce(lhs);
        hl = hl_r[1];
        if not ((hl_r[0] as bool)) {
            return hl_r[1] as PyObj;
        }
        hr_r = to_host_coerce(rhs);
        hr = hr_r[1];
        if not ((hr_r[0] as bool)) {
            return hr_r[1] as PyObj;
        }
        res = _jac_host_richcompare(kind, hl, hr);
        if not ((res[0] as bool)) {
            return host_result_error(res);
        }
        return PyBool(t="bool", val=res[1] as bool);
    }
    # Proxy-vs-proxy ORDERING (bytearray < bytearray, ...): tp_richcompare
    # handles only eq/ne (identity fast path + host eq defer), so ordering
    # would fall to NotImplemented -> TypeError where CPython compares the
    # host values. Unorderable host types surface the host TypeError verbatim.
    if (
        isinstance(lhs, PyHostProxy) and isinstance(rhs, PyHostProxy)
        and (kind == 0 or kind == 1 or kind == 4 or kind == 5)
    ) {
        res = _jac_host_richcompare(kind, lhs.val, rhs.val);
        if not ((res[0] as bool)) {
            return host_result_error(res);
        }
        return PyBool(t="bool", val=res[1] as bool);
    }
    if isinstance(lhs, PySet) and isinstance(rhs, PySet) {
        return set_richcompare(kind, lhs as PySet, rhs as PySet);
    }
    if py_obj_is_type(lhs) and py_obj_is_type(rhs) {
        return type_richcompare_same(kind, py_type_same(lhs, rhs));
    }
    return PyObject_RichCompare(lhs, rhs, kind);
}

# Native nb_binop covers the ported fast paths (int/str Gap #2 %-format, tuple/
# list concat, ...). Operand/format combos not yet ported (str % with %f/%i or
# multiple args, str * int, ...) fall back across the substrate to host CPython
# when both operands are host-backed. Purely additive: only a native error
# triggers the fallback, so ported semantics always win.
def host_binop(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    hl_r = to_host_coerce(lhs);
    hl = hl_r[1];
    if not ((hl_r[0] as bool)) {
        return hl_r[1] as PyObj;
    }
    hr_r = to_host_coerce(rhs);
    hr = hr_r[1];
    if not ((hr_r[0] as bool)) {
        return hr_r[1] as PyObj;
    }
    result = _jac_host_binop(kind, hl, hr);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return host_result_error(result);
}

def _host_representable(t: str) -> bool {
    # Table query: a tag is host-representable iff the boundary table gives it
    # any policy other than FAIL. Native PySet/PyList/... are MUTABLE_COPY
    # (declared divergence), so mixed native/host operand binops can still fall
    # back to the host; PyClass/PyUserObj are STANDIN (name-faithful stand-ins).
    return to_host_policy(t) != BridgePolicy.FAIL;
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

# A dunder returned NotImplemented (native sentinel or host singleton proxy).
def is_notimplemented(o: PyObj) -> bool {
    if o is PY_NOT_IMPLEMENTED {
        return True;
    }
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
        "__add__",
        "__and__",
        "__floordiv__",
        "__lshift__",
        "__matmul__",
        "__mul__",
        "__mod__",
        "__or__",
        "__pow__",
        "__rshift__",
        "__sub__",
        "__truediv__",
        "__xor__"
    ];
    if kind >= 0 and kind < len(names) {
        return names[kind];
    }
    return "";
}

# Reflected counterpart (__radd__/__rmul__/...) for the same kind.
def binop_rdunder(kind: int) -> str {
    names = [
        "__radd__",
        "__rand__",
        "__rfloordiv__",
        "__rlshift__",
        "__rmatmul__",
        "__rmul__",
        "__rmod__",
        "__ror__",
        "__rpow__",
        "__rrshift__",
        "__rsub__",
        "__rtruediv__",
        "__rxor__"
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

# CPython operator subclass priority: when `type(rhs)` is a PROPER subclass of
# `type(lhs)` and overrides the reflected slot (`rname`), the reflected call is
# tried BEFORE the left operand's forward slot. True iff that reordering applies.
def rhs_reflected_priority(lhs: PyObj, rhs: PyObj, rname: str) -> bool {
    if rname == "" {
        return False;
    }
    if not (isinstance(lhs, PyUserObj) and isinstance(rhs, PyUserObj)) {
        return False;
    }
    lcls = (lhs as PyUserObj).cls;
    rcls = (rhs as PyUserObj).cls;
    if lcls is rcls {
        return False;
    }
    # rhs's class must be a proper subclass of lhs's class (it already differs).
    if not instance_of_class(rhs as PyUserObj, lcls) {
        return False;
    }
    return user_has_dunder(rhs as PyUserObj, rname);
}

# Bind the MRO-resolved dunder to the receiver and call it with `args`. The
# result -- a value, a raised exception (PyError), or NotImplemented -- is
# returned verbatim for the protocol layer to interpret.
def call_user_dunder(u: PyUserObj, name: str, args: list[PyObj]) -> PyObj {
    method = class_lookup_attr(u.cls, name);
    return bind_attribute(method, u).tp_call(args, {});
}

# CPython ``dict_subscript`` consults a type-level ``__missing__``: when the
# lookup on a dict whose TYPE is a subclass misses, ``dict.__getitem__`` calls
# the MRO-resolved ``__missing__(key)`` and returns its value instead of
# raising KeyError (this is defaultdict's mechanism). Only the subscript slot
# does this -- get()/pop()/``in`` never invoke ``__missing__``. A user-defined
# ``__getitem__`` replaces the slot wholesale, so callers that dispatched an
# override never reach here. An unhashable key fails before lookup (TypeError),
# so only a genuine KeyError miss falls back.
def dict_subscript_missing(owner: PyUserObj, d: PyDict, index: PyObj) -> PyObj {
    res = d.mp_subscript(index);
    if not is_error(res) {
        return res;
    }
    err = res as PyError;
    if err.exception.type_name != "KeyError" {
        return res;
    }
    missing = class_lookup_attr(owner.cls, "__missing__");
    if is_error(missing) {
        return res;
    }
    return bind_attribute(missing, owner).tp_call([index], {});
}

# CPython binary-operator protocol for PyUserObj operands: try lhs.__op__(rhs),
# then the reflected rhs.__rop__(lhs); a builtin-subclass operand with no user
# override delegates to its boxed value; otherwise TypeError. A raised exception
# from a dunder propagates immediately (it is not NotImplemented).
def user_binop(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    name = binop_dunder(kind);
    rname = binop_rdunder(kind);
    # Subclass reflected priority: A() + B() where B(A) overrides __radd__ runs
    # B.__radd__ first (CPython rule).
    if rhs_reflected_priority(lhs, rhs, rname) {
        res = call_user_dunder(rhs as PyUserObj, rname, [lhs]);
        if not is_notimplemented(res) {
            return res;
        }
    }
    if isinstance(lhs, PyUserObj) {
        lu = lhs as PyUserObj;
        if name != "" and user_has_dunder(lu, name) {
            res = call_user_dunder(lu, name, [rhs]);
            if not is_notimplemented(res) {
                return res;
            }
        }
    }
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
    # NB_* kind -> operator symbol, same order as binop_dunder's name table.
    symbols = ["+", "&", "//", "<<", "@", "*", "%", "|", "**", ">>", "-", "/", "^"];
    op = symbols[kind] if kind >= 0 and kind < len(symbols) else "?";
    return py_error(
        "TypeError",
        "unsupported operand type(s) for " + op + ": '"
            + _compare_type_name(lhs) + "' and '" + _compare_type_name(rhs) + "'"
    );
}

# Instance -> CPython type name for protocol error messages. Wraps the
# builtin tag map in abstract_protocol with the operand kinds only ceval
# knows about: user class instances print their class name, dict views
# print dict_keys / dict_values / dict_items.
def _compare_type_name(v: PyObj) -> str {
    if isinstance(v, PyUserObj) {
        return (v as PyUserObj).cls.name;
    }
    if isinstance(v, PyDictView) {
        return "dict_" + (v as PyDictView).mode;
    }
    return _base_type_name(v);
}

# CPython rich-comparison protocol for PyUserObj operands. Same shape as
# user_binop, plus the == / != identity fallback when neither side overrides.
def user_compare(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    name = compare_dunder(kind);
    rname = compare_dunder(compare_swap(kind));
    # Subclass reflected priority: rhs's reflected comparison runs first when
    # type(rhs) is a proper subclass of type(lhs) and overrides it.
    if rhs_reflected_priority(lhs, rhs, rname) {
        res = call_user_dunder(rhs as PyUserObj, rname, [lhs]);
        if not is_notimplemented(res) {
            return res;
        }
    }
    # A builtin subclass's OWN comparison dunder wins (class MyInt(int) that
    # overrides __eq__), mirroring user_binop -- user_has_dunder only finds it
    # when the user class actually defines it, so an unoverridden subclass still
    # falls through to the boxed-value comparison below.
    if isinstance(lhs, PyUserObj) {
        lu = lhs as PyUserObj;
        if name != "" and user_has_dunder(lu, name) {
            res = call_user_dunder(lu, name, [rhs]);
            if not is_notimplemented(res) {
                return res;
            }
        }
    }
    if isinstance(rhs, PyUserObj) {
        ru = rhs as PyUserObj;
        if rname != "" and user_has_dunder(ru, rname) {
            res = call_user_dunder(ru, rname, [lhs]);
            if not is_notimplemented(res) {
                return res;
            }
        }
    }
    if isinstance(lhs, PyUserObj) and (lhs as PyUserObj)._has_base() {
        res = (lhs as PyUserObj)._base_obj().tp_richcompare(kind, unwrap_base(rhs));
        if not is_notimplemented(res) {
            return res;
        }
    }
    if isinstance(rhs, PyUserObj) and (rhs as PyUserObj)._has_base() {
        res = unwrap_base(lhs).tp_richcompare(kind, (rhs as PyUserObj)._base_obj());
        if not is_notimplemented(res) {
            return res;
        }
    }
    if kind == 2 {
        return PyBool(t="bool", val=lhs is rhs);
    }
    if kind == 3 {
        # CPython object.__ne__: when either side defines __eq__ (and neither
        # defined __ne__ -- both were tried above), != is the negated result
        # of the full == protocol, not an identity test. Recursing with kind 2
        # reuses reflected priority, builtin-subclass slots, and the base
        # tp_richcompare chain; a NotImplemented from __eq__ still lands on
        # that chain's identity fallback before negation.
        eq_lhs = False;
        eq_rhs = False;
        if isinstance(lhs, PyUserObj) {
            eq_lhs = user_has_dunder(lhs as PyUserObj, "__eq__");
        }
        if isinstance(rhs, PyUserObj) {
            eq_rhs = user_has_dunder(rhs as PyUserObj, "__eq__");
        }
        if eq_lhs or eq_rhs {
            res = user_compare(2, lhs, rhs);
            if is_error(res) {
                return res;
            }
            truth = py_slot_truth(res);
            if is_error(truth) {
                return truth;
            }
            return PyBool(t="bool", val=not (truth as PyBool).val);
        }
        return PyBool(t="bool", val=lhs is not rhs);
    }
    return py_ordering_type_error(kind, lhs, rhs, _compare_type_name);
}

# ---------------- NB_INPLACE_* : mutate-and-return-self protocol ----------------

# list.__iadd__ / list.__imul__ (CPython listobject.c list_inplace_concat /
# list_inplace_repeat): mutate `lst` storage and return it, so every alias
# observes the update and the trailing STORE_FAST re-binds the SAME object.
def list_inplace_binop(lst: PyList, kind: int, rhs: PyObj) -> PyObj {
    if kind == NB_INPLACE_ADD {
        # Extend semantics: any iterable is accepted (unlike __add__, which
        # only concatenates lists).
        drained = iter_drain(rhs);
        if is_error(drained) {
            return drained;
        }
        for x in (drained as PyList).items {
            lst.items.append(x);
        }
        return lst;
    }
    if kind == NB_INPLACE_MULTIPLY {
        idx = rhs.to_index();
        if is_error(idx) {
            return py_error(
                "TypeError",
                "can't multiply sequence by non-int of type '" + rhs.t + "'",
            );
        }
        n = (idx as PyInt).val;
        repeated: list[PyObj] = [];
        while n > 0 {
            repeated.extend(lst.items);
            n = n - 1;
        }
        lst.items = repeated;
        return lst;
    }
    return PY_NOT_IMPLEMENTED;
}

# set |= &= -= ^= (CPython setobject.c set_ior/iand/isub/ixor): mutate `s`
# storage and return it. Frozen sets decline (no in-place slots) -- py_binop
# then folds to the base binop, producing a NEW frozenset on rebind, which is
# exactly CPython's legal `fs |= {x}` behavior.
def set_inplace_binop(s: PySet, kind: int, rhs: PyObj) -> PyObj {
    if s.frozen {
        return PY_NOT_IMPLEMENTED;
    }
    if kind != NB_INPLACE_OR and kind != NB_INPLACE_AND
        and kind != NB_INPLACE_SUBTRACT and kind != NB_INPLACE_XOR {
        return PY_NOT_IMPLEMENTED;
    }
    # All four arms consume any iterable (set_update-family semantics); drain
    # up front so failed iteration raises before self mutates.
    drained = iter_drain(rhs);
    if is_error(drained) {
        return drained;
    }
    elems = (drained as PyList).items;
    if kind == NB_INPLACE_OR {
        for x in elems {
            err = s.set_add(x);
            if is_error(err) {
                return err;
            }
        }
        return s;
    }
    # Hash incoming elements before touching self: an unhashable member raises
    # with self still untouched.
    other_hks: list[str] = [];
    for x in elems {
        hkr = x.tp_hashkey();
        if is_error(hkr) {
            return py_error("TypeError", "unhashable type: '" + x.t + "'");
        }
        other_hks.append(hashkey_str(hkr));
    }
    rebuilt: dict[str, PyObj] = {};
    if kind == NB_INPLACE_AND {
        # intersection_update keeps self elements present in other.
        for hk in s.items {
            if hk in other_hks {
                rebuilt[hk] = s.items[hk];
            }
        }
    } elif kind == NB_INPLACE_SUBTRACT {
        for hk in s.items {
            if not (hk in other_hks) {
                rebuilt[hk] = s.items[hk];
            }
        }
    } else {
        # symmetric_difference_update: keep self-only members, add other-only
        # ones (first occurrence wins on duplicates within other).
        for hk in s.items {
            if not (hk in other_hks) {
                rebuilt[hk] = s.items[hk];
            }
        }
        i = 0;
        while i < len(other_hks) {
            hk = other_hks[i];
            if not (hk in s.items) and not (hk in rebuilt) {
                rebuilt[hk] = elems[i];
            }
            i = i + 1;
        }
    }
    s.items = rebuilt;
    return s;
}

# The BINARY_OP in-place arm (opcode.h NB_INPLACE_* 13..25). Mutable native
# containers expose CPython-style in-place slots that MUTATE the receiver and
# return it -- aliases observe the update (`a = b = []; a += [x]` keeps
# `a is b` True). Everything else returns PY_NOT_IMPLEMENTED and py_binop
# folds the kind to its base binop (immutable fallback: str/bytes/int/tuple
# legitimately rebind).
def py_inplace_binop(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    if isinstance(lhs, PyList) {
        return list_inplace_binop(lhs as PyList, kind, rhs);
    }
    if isinstance(lhs, PySet) {
        return set_inplace_binop(lhs as PySet, kind, rhs);
    }
    return PY_NOT_IMPLEMENTED;
}

def py_binop(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    # NB_INPLACE_* (13..25): try the receiver's in-place slot first; when it
    # declines (immutables, frozen sets), reduce to the base binop (0..12) so
    # `x += y` is `x = x + y` and the trailing STORE rebinds -- CPython's
    # immutable-type fallback.
    if kind >= NB_INPLACE_ADD and kind <= NB_INPLACE_XOR {
        inplace = py_inplace_binop(kind, lhs, rhs);
        if not is_notimplemented(inplace) {
            return inplace;
        }
        kind = kind - NB_INPLACE_ADD;
    }
    # A user-class operand routes through the operator-overload protocol first.
    # EXCEPT str %-format over a native operand carrying user instances: CPython
    # calls str.__mod__ FIRST -- %s/%r stringify through the operand's own
    # __str__/__repr__ slots -- and never falls back to __rmod__ past its real
    # TypeError ('%d' % X() raises even when X defines __rmod__). The result,
    # success or error, propagates; scalar-only args keep the lifted fast path
    # with its host-bridge error fallback below.
    if kind == NB_REMAINDER and isinstance(lhs, PyStr)
        and mod_args_need_user_slots(rhs) {
        return str_mod_format((lhs as PyStr).val, rhs, py_str, py_repr);
    }
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
    if is_error(result) and kind == NB_MULTIPLY and isinstance(rhs, PyList) {
        # Reflected sequence repeat: 3 * [x] -- int.__mul__ declines, so
        # CPython falls through to list.__rmul__ (sq_repeat). Must stay
        # native: the host fallback would to_host() each element and break
        # reference aliasing ([[0]]*3 must share one inner list).
        return rhs.nb_binop(NB_MULTIPLY, lhs);
    }
    if is_error(result) and kind == NB_MULTIPLY and isinstance(rhs, PyTuple) {
        return rhs.nb_binop(NB_MULTIPLY, lhs);
    }
    if is_error(result) and isinstance(rhs, PyComplex) {
        # Reflected complex tower (2 - 1j, 6 / (3+0j), 2 ** (3+0j)): CPython's
        # int/float slots decline a complex operand and the complex r-slot
        # promotes. Numeric errors stay native; PY_NOT_IMPLEMENTED falls
        # through to the host fallback below for byte-exact messages.
        lhs_real = lhs.t == "int" or lhs.t == "float" or lhs.t == "bool";
        if lhs_real {
            rres = (rhs as PyComplex)._reflected_binop(kind, lhs);
            if not is_error(rres) and not is_notimplemented(rres) {
                return rres;
            }
            if is_error(rres) {
                terr = (rres as PyError).exception.type_name;
                if terr == "ZeroDivisionError" or terr == "OverflowError" {
                    return rres;
                }
            }
        }
    }
    if is_error(result) and _host_representable(lhs.t) and _host_representable(rhs.t) {
        # Fall back when native slots are incomplete (TypeError, ValueError from
        # partial str %-format, ...). Operational numeric errors must stay native
        # so exception messages match CPython in-VM (e.g. str(e) after `1 // 0`).
        err = result as PyError;
        tn = err.exception.type_name;
        if tn != "ZeroDivisionError" and tn != "OverflowError" {
            return host_binop(kind, lhs, rhs);
        }
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
    if isinstance(container, PyRange) {
        rg = container as PyRange;
        # Exact-int needles (incl. bool, per CPython's int-instance check) take
        # the O(1) arithmetic path from the lifted leaf.
        if isinstance(member, PyInt) or isinstance(member, PyBool) {
            v = (member as PyInt).val;
            return PyBool(
                t="bool", val=range_contains_longs(rg.start, rg.stop, rg.step, v)
            );
        }
        # Non-int needles scan item by item with real == (CPython's
        # _PySequence_IterSearch fallback); same O(n) behavior as CPython.
        cursor = rg.tp_iter();
        while True {
            scan_step = send_into(cursor, py_none());
            if scan_step.t == "genstop" {
                return PyBool(t="bool", val=False);
            }
            cmp = py_compare(2, member, scan_step);
            if is_error(cmp) {
                return cmp;
            }
            if cmp.tp_bool() {
                return PyBool(t="bool", val=True);
            }
        }
    }
    if isinstance(container, PyDictView) {
        return view_contains(container as PyDictView, member);
    }
    if isinstance(container, PySet) {
        return (container as PySet).set_lookup(member);
    }
    if isinstance(container, PyDict) {
        return PyBool(t="bool", val=(container as PyDict).dict_contains(member));
    }
    # Native tuple/list membership compares elements with a real == in-VM. Routing
    # through the host collapses every native class/instance to None (to_host), so
    # `SomeClass in (OtherClass,)` would wrongly match; keep it native.
    if isinstance(container, PyTuple) or isinstance(container, PyList) {
        elems: list[PyObj] = [];
        if isinstance(container, PyTuple) {
            elems = (container as PyTuple).items;
        } else {
            elems = (container as PyList).items;
        }
        for item in elems {
            cmp = py_compare(2, member, item);
            if is_error(cmp) {
                return cmp;
            }
            if cmp.tp_bool() {
                return PyBool(t="bool", val=True);
            }
        }
        return PyBool(t="bool", val=False);
    }
    # Implicit sq_contains slot on user classes: __contains__ wins; without it
    # CPython's default sq_contains iterates with real ==; neither available
    # is the TypeError.
    if isinstance(container, PyUserObj) {
        u = container as PyUserObj;
        if user_has_dunder(u, "__contains__") {
            hit = call_user_dunder(u, "__contains__", [member]);
            if is_error(hit) {
                return hit;
            }
            truth = py_slot_truth(hit);
            if is_error(truth) {
                return truth;
            }
            return truth;
        }
        cursor = (u as PyObj).tp_iter();
        if is_error(cursor) {
            return py_error(
                "TypeError", "argument of type '" + u.cls.name + "' is not iterable"
            );
        }
        while True {
            scan = send_into(cursor, py_none());
            if scan.t == "genstop" {
                return PyBool(t="bool", val=False);
            }
            if is_error(scan) {
                return scan;
            }
            cmp2 = py_compare(2, member, scan);
            if is_error(cmp2) {
                return cmp2;
            }
            found = py_slot_truth(cmp2);
            if is_error(found) {
                return found;
            }
            if (found as PyBool).val {
                return PyBool(t="bool", val=True);
            }
        }
    }
    hm_r = to_host_coerce(member);
    hm = hm_r[1];
    if not ((hm_r[0] as bool)) {
        return hm_r[1] as PyObj;
    }
    hc_r = to_host_coerce(container);
    hc = hc_r[1];
    if not ((hc_r[0] as bool)) {
        return hc_r[1] as PyObj;
    }
    result = _jac_host_contains(hm, hc);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return host_result_error(result);
}

def py_store_subscript(container: PyObj, index: PyObj, value: PyObj) -> PyObj {
    # Slice assignment accepts ANY iterable as its value; CPython runs it
    # through PySequence_Fast before list_ass_subscript. members_of() is that
    # conversion (py_iter-first, host fallback), so user generators/iterables
    # drain in-VM instead of dying inside the na-clean leaf slot.
    if isinstance(container, PyList) and isinstance(index, PySlice) {
        seq = members_of(value);
        if is_error(seq) {
            return seq;
        }
        return container.mp_ass_subscript(index, seq);
    }
    return container.mp_ass_subscript(index, value);
}

def py_delete_subscript(container: PyObj, index: PyObj) -> PyObj {
    return container.mp_del_subscript(index);
}

# DICT_UPDATE/DICT_MERGE source view: validate the merge source against
# CPython's mapping protocol (ceval.c TARGET(DICT_UPDATE)/TARGET(DICT_MERGE))
# and yield its pairs. Accepted sources: native PyDict, a host-backed mapping
# whose from_host conversion lands as PyDict, or a user object exposing both
# keys() and __getitem__ (drained through the dunder protocol). Anything else
# is rejected exactly where CPython rejects it:
#   - DICT_UPDATE ({**x}): TypeError "'<type>' object is not a mapping"
#   - DICT_MERGE (f(**x)): TypeError "argument after ** must be a mapping,
#     not <type>" -- host additionally prefixes the caller qualname, which the
#     VM omits (house style for call-site errors, see fast-bind messages).
# Returns the pair source as a PyObj holding a PyDict, or an unraised error.
def dict_mapping_pairs(source: PyObj, kwargs_call: bool) -> PyObj {
    if isinstance(source, PyDict) {
        return source;
    }
    if isinstance(source, PyHostProxy) {
        converted = from_host((source as PyHostProxy).val);
        if isinstance(converted, PyDict) {
            return converted;
        }
    }
    if isinstance(source, PyUserObj) {
        u = source as PyUserObj;
        if user_has_dunder(u, "keys") and user_has_dunder(u, "__getitem__") {
            keys_res = call_user_dunder(u, "keys", []);
            if is_error(keys_res) {
                return keys_res;
            }
            # LAZY drain over the keys() result (CPython PyMapping_Keys
            # semantics): d.keys() views carry staleness, so a mapping whose
            # underlying storage mutates mid-merge raises RuntimeError during
            # this loop exactly like host (test_dict doctests exc62/65). An
            # eager snapshot here would silently hide that mutation.
            kit = py_iter(keys_res);
            out = PyDict(t="dict", items={});
            while True {
                k = send_into(kit, py_none());
                if k.t == "genstop" {
                    break;
                }
                if is_error(k) {
                    return k;
                }
                v = call_user_dunder(u, "__getitem__", [k]);
                if is_error(v) {
                    return v;
                }
                out.dict_set(k, v);
            }
            return out;
        }
        # Mapping-subclass fallback: user classes inheriting from host-ABC
        # stand-ins (collections.abc Mapping/MutableMapping) have no visible
        # inherited keys() -- class_mro-based dunder lookup skips host-proxy
        # bases -- but CPython still merges such objects because instances
        # are an iterable of their keys. Drive __iter__ LAZILY so a mapping
        # mutating storage mid-iteration raises RuntimeError during the
        # drain exactly like CPython (test_dict doctests exc62/65); an
        # eager members_of() snapshot would hide that.
        if user_has_dunder(u, "__iter__") and user_has_dunder(u, "__getitem__") {
            it = call_user_dunder(u, "__iter__", []);
            if is_error(it) {
                return it;
            }
            iter_out = PyDict(t="dict", items={});
            while True {
                step = send_into(it, py_none());
                if step.t == "genstop" {
                    break;
                }
                if is_error(step) {
                    return step;
                }
                v = call_user_dunder(u, "__getitem__", [step]);
                if is_error(v) {
                    return v;
                }
                iter_out.dict_set(step, v);
            }
            return iter_out;
        }
    }
    tname = _compare_type_name(source);
    if kwargs_call {
        return py_error("TypeError", "argument after ** must be a mapping, not " + tname);
    }
    return py_error("TypeError", "'" + tname + "' object is not a mapping");
}

# UNARY_NEGATIVE (-x). int/bool negate to int (-True == -1), float to float,
# complex negates both parts; any other operand is a TypeError, matching
# CPython's nb_negative == NULL path.
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
    if isinstance(value, PyComplex) {
        c = value as PyComplex;
        return PyComplex(t="complex", real=-c.real, imag=-c.imag);
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

def append_to_list(target: PyObj, iterable: PyObj) -> PyObj {
    target_list = target as PyList;
    if iterable.t == "list" {
        target_list.items.extend(list_value(iterable));
        return py_none();
    } elif iterable.t == "tuple" {
        target_list.items.extend(tuple_value(iterable));
        return py_none();
    } elif iterable.t == "str" {
        for ch in str_value(iterable) {
            target_list.items.append(PyStr(t="str", val=ch));
        }
        return py_none();
    }
    # CPython's LIST_EXTEND accepts ANY iterable (range/dict/set/generators
    # included); the old shape dispatch silently produced an empty extend for
    # every other kind. Fall back to a generic iterator drain and propagate
    # the TypeError for non-iterables.
    drained = iter_drain(iterable);
    if is_error(drained) {
        return drained;
    }
    target_list.items.extend((drained as PyList).items);
    return py_none();
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

# PEP 695 lazy alias evaluation (CPython TypeAliasType.__value__ /
# evaluate_value): run the hidden value function once at format 0, cache the
# result, and serve every later access from the cache. Errors propagate
# uncached, so a retry re-evaluates (and re-raises) exactly like a fresh call.
def typealias_value(ta: PyTypeAlias) -> PyObj {
    if ta.computed {
        return ta.cached_value;
    }
    res = py_invoke(ta.value_fn, [PyInt(t="int", val=0)], {});
    if is_error(res) {
        return res;
    }
    ta.computed = True;
    ta.cached_value = res;
    return res;
}

# PEP 695 lazy bound/constraints/default resolution (CALL_INTRINSIC_2 arms
# 2/3/5): the evaluator runs once through py_invoke and its value caches on
# the TypeVar, mirroring CPython typevarobject.c getsets. Absent evaluators
# answer the CPython defaults: None / the empty tuple / NoDefault.
def typevar_bound_value(tv: PyTypeVar) -> PyObj {
    if tv.bound_resolved {
        return tv.cached_bound;
    }
    res = py_none();
    if tv.evaluate_bound.t != "none" {
        res = py_invoke(tv.evaluate_bound, [], {});
        if is_error(res) {
            return res;
        }
    }
    tv.cached_bound = res;
    tv.bound_resolved = True;
    return res;
}

def typevar_constraints_value(tv: PyTypeVar) -> PyObj {
    if tv.constraints_resolved {
        return tv.cached_constraints;
    }
    res = PyTuple(t="tuple", items=[]);
    if tv.evaluate_constraints.t != "none" {
        res = py_invoke(tv.evaluate_constraints, [], {});
        if is_error(res) {
            return res;
        }
    }
    tv.cached_constraints = res;
    tv.constraints_resolved = True;
    return res;
}

def typevar_default_value(tv: PyTypeVar) -> PyObj {
    if tv.default_resolved {
        return tv.cached_default;
    }
    res = no_default_sentinel() as PyObj;
    if tv.evaluate_default.t != "none" {
        res = py_invoke(tv.evaluate_default, [], {});
        if is_error(res) {
            return res;
        }
    }
    tv.cached_default = res;
    tv.default_resolved = True;
    return res;
}

def py_attr(value: PyObj, name: str) -> PyObj {
    # The alias's lazy __value__ re-enters the interpreter (it runs the hidden
    # value function), so it is served here rather than in the na-clean obj's
    # tp_getattro -- see typealias_value.
    if isinstance(value, PyTypeAlias) and name == "__value__" {
        return typealias_value(value as PyTypeAlias);
    }
    # Same seam for the TypeVar's lazy __bound__/__constraints__/__default__
    # (PEP 749 const-evaluators installed by CALL_INTRINSIC_2) -- see
    # typevar_bound_value and siblings.
    if isinstance(value, PyTypeVar) {
        if name == "__bound__" {
            return typevar_bound_value(value as PyTypeVar);
        }
        if name == "__constraints__" {
            return typevar_constraints_value(value as PyTypeVar);
        }
        if name == "__default__" {
            return typevar_default_value(value as PyTypeVar);
        }
        # has_default() is syntactic (PEP 696: never forces evaluation) but
        # needs a callable wrapper built on this side of the substrate
        # boundary, like the dict/list/set method wrappers below.
        if name == "has_default" {
            return PyTypeVarMethod(t="typevar_method", tv=value as PyTypeVar, name=name);
        }
    }
    # typing.Generic[T, ...] stand-ins answer origin/args/parameters plus the
    # __mro_entries__ hook that __build_class__ resolves (update_bases port in
    # py_build_class).
    if isinstance(value, PyGenericAlias) {
        ga = value as PyGenericAlias;
        if name == "__origin__" {
            return typing_generic_class();
        }
        if name == "__args__" or name == "__parameters__" {
            return ga.params;
        }
        if name == "__mro_entries__" {
            return PyGenericMroEntries(t="generic_mro_entries");
        }
    }
    result = value.tp_getattro(name);
    # A native dict's keys()/values()/items() are bound zero-arg constructors of
    # a live, set-like PyDictView (not host proxies), so view comparison / set
    # algebra can invoke element __eq__ and iteration carries the mutation guard.
    if is_error(result)
        and isinstance(value, PyDict)
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
    if is_error(result)
        and isinstance(value, PySet)
        and is_set_method(name, (value as PySet).frozen) {
        return PySetMethod(t="set_method", target=value as PySet, name=name);
    }
    # Native str methods: a bound PyStrMethod keeps instance calls in-VM instead
    # of crossing the substrate boundary for every 'x'.upper() (same seam as the
    # dict/list/set arms above; unported names still fall through to the host).
    if is_error(result) and isinstance(value, PyStr) and is_str_method(name) {
        return PyStrMethod(t="str_method", target=value as PyStr, name=name);
    }
    # ExceptionGroup split/subgroup kernel (PEP 654): bound native methods so
    # partitioning runs on live guest objects rather than host copies.
    if is_error(result) and isinstance(value, PyException) and name == "add_note" {
        return PyAddNoteMethod(t="add_note_method", target=value as PyException);
    }
    if is_error(result) and isinstance(value, PyExcGroup)
        and (name == "split" or name == "subgroup") {
        return PyExcGroupMethod(
            t="egroup_method", target=value as PyExcGroup, name=name
        );
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
        # slot_tp_setattro dispatches deletion through the type-level
        # __delattr__ when the MRO defines one, before any default handling.
        attr_override = class_lookup_attr(u.cls, "__delattr__");
        if not is_error(attr_override) {
            return bind_attribute(attr_override, u as PyObj).tp_call(
                [PyStr(t="str", val=name)], {}
            );
        }
        return default_user_delattro(u, name);
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
    hv_r = to_host_coerce(value);
    hv = hv_r[1];
    if not ((hv_r[0] as bool)) {
        return hv_r[1] as PyObj;
    }
    result = _jac_host_delattr(hv, name);
    if host_result_ok(result) {
        return py_none();
    }
    return host_result_error(result);
}

# One step of the iter(callable, sentinel) callable-iterator: invoke the
# callable with no args; a result equal to the sentinel ends the iteration
# (permanently -- a later next keeps returning StopIteration). Comparison
# uses the full == protocol; errors propagate.
def calliter_next(it: PyCallableIter) -> PyObj {
    if it.exhausted {
        return PyGenStop(t="genstop", val=py_none());
    }
    res = (it.fn as PyObj).tp_call([], {});
    if is_error(res) {
        # CPython calliter_iternext: a callable raising StopIteration (or a
        # subclass) ends this step -- the error is cleared and tp_iternext
        # returns NULL, so FOR_ITER pops the loop instead of propagating.
        # Exhaustion is NOT latched: each next() retries the callable.
        if error_is_stopiteration(res) {
            return PyGenStop(t="genstop", val=py_none());
        }
        return res;
    }
    eq = py_compare(2, res, it.sentinel);
    if is_error(eq) {
        return eq;
    }
    truth = py_slot_truth(eq);
    if is_error(truth) {
        return truth;
    }
    if (truth as PyBool).val {
        it.exhausted = True;
        return PyGenStop(t="genstop", val=py_none());
    }
    return res;
}

# One step of the old-style sequence iterator (CPython sq_iterator): fetch
# seq[index], incrementing; IndexError (matched by type, like
# PyErr_ExceptionMatches) ends the iteration permanently. Any other error
# propagates -- notably KeyError does NOT stop a sequence iterator.
def seqiter_next(it: PySeqIter) -> PyObj {
    res = it.seq.mp_subscript(PyInt(t="int", val=it.index));
    if is_error(res) {
        if error_is_indexerror(res) {
            it.index = -1;
            return PyGenStop(t="genstop", val=py_none());
        }
        return res;
    }
    it.index = it.index + 1;
    return res;
}

# True iff an iteration step failed with IndexError or a subclass -- the
# only exception that stops a sequence iterator (CPython
# PyErr_ExceptionMatches(PyExc_IndexError) in sq_iterator).
def error_is_indexerror(err: PyObj) -> bool {
    if err.t != "error" {
        return False;
    }
    exc = (err as PyError).exception;
    if exc_name_matches(exc.type_name, "IndexError") {
        return True;
    }
    raw = exc.raw;
    if raw is not None and isinstance(raw, PyUserObj) {
        for klass in class_mro((raw as PyUserObj).cls) {
            for base in klass.bases {
                if isinstance(base, PyExceptionType)
                    and (base as PyExceptionType).name == "IndexError" {
                    return True;
                }
            }
        }
    }
    return False;
}

def py_iter(value: PyObj) -> PyObj {
    # A callable-iterator (two-arg iter) is its own iterator.
    if isinstance(value, PyCallableIter) {
        return value;
    }
    # A read-only mapping view iterates exactly like its dict.
    if isinstance(value, PyMappingProxy) {
        return py_iter((value as PyMappingProxy).target as PyObj);
    }
    if isinstance(value, PyUserObj) {
        u = value as PyUserObj;
        if user_has_dunder(u, "__iter__") {
            res = call_user_dunder(u, "__iter__", []);
            if is_error(res) {
                return res;
            }
            # A plain object returned by __iter__ that defines __next__ IS an
            # iterator (the self-returning class-iterator idiom): CPython fills
            # tp_iternext from __next__, so PyIter_Check accepts it.
            if not PyIter_Check(res)
                and not (
                    isinstance(res, PyUserObj)
                    and user_has_dunder(res as PyUserObj, "__next__")
                ) {
                return py_error(
                    "TypeError", "iter() returned non-iterator of type '" + res.t + "'"
                );
            }
            return res;
        }
        if u._has_base() {
            return PyObject_GetIter(u._base_obj());
        }
        # Old-style sequence protocol: __getitem__ without __iter__ synthesizes
        # a CPython sequence iterator (successive seq[i] until IndexError).
        # Checked after the boxed-base fallback so a builtin subclass keeps its
        # inherited tp_iter, matching CPython's slot order.
        if user_has_dunder(u, "__getitem__") {
            return PySeqIter(t="seqiter", seq=u as PyObj);
        }
    }
    return PyObject_GetIter(value);
}

# The __eq__/__hash__ MRO decision of CPython's slot machinery, shared by
# hash() and the hash-key protocol so they can never disagree. True iff the
# nearest class dict in the MRO defining either name makes instances
# unhashable: a callable __hash__ wins; an explicit `__hash__ = None` (or the
# marker type_ready_set_hash would inject for __eq__-without-__hash__, which
# shadows every ancestor's explicit __hash__) blocks.
def mro_hash_blocked(u: PyUserObj) -> bool {
    for klass in class_mro(u.cls) {
        if "__hash__" in klass.attrs {
            return isinstance(klass.attrs["__hash__"], PyNoneType);
        }
        if "__eq__" in klass.attrs {
            return True;
        }
    }
    return False;
}

# Native ``hash()`` for ported builtins and user ``__hash__``; no host fallback.
def py_hash(value: PyObj) -> PyObj {
    if isinstance(value, PyUserObj) {
        u = value as PyUserObj;
        # The MRO pair decision gates everything: it beats both a plain
        # user_has_dunder("__hash__") hit (an ancestor's __hash__ does not
        # rescue a subclass whose body defines only __eq__) and the boxed
        # builtin base delegation (an int subclass defining __eq__ is
        # unhashable despite int's own hashing).
        if mro_hash_blocked(u) {
            return py_error("TypeError", "unhashable type: '" + u.cls.name + "'");
        }
        if user_has_dunder(u, "__hash__") {
            h = call_user_dunder(u, "__hash__", []);
            if is_error(h) {
                return h;
            }
            if isinstance(h, PyBool) {
                h = PyInt(t="int", val=1 if (h as PyBool).val else 0);
            }
            if isinstance(h, PyInt) {
                return h;
            }
            # slot_tp_hash (typeobject.c ~10318) message, byte-exact.
            return py_error("TypeError", "__hash__ method should return an integer");
        }
        if u._has_base() {
            return py_hash(u._base_obj());
        }
        # Default tp_hash: object.__hash__ (the identity-keyed digest), or the
        # __eq__-without-__hash__ unhashable rule -- both owned by tp_hashkey,
        # so hash() and dict/set keying cannot disagree.
        hkr = u.tp_hashkey();
        if is_error(hkr) {
            return py_error("TypeError", "unhashable type: '" + u.cls.name + "'");
        }
        return PyObject_Hash(value);
    }
    if isinstance(value, PyTuple) {
        return tuple_hash(value as PyTuple);
    }
    if isinstance(value, PyInt) {
        return long_hash_obj(value as PyInt);
    }
    if isinstance(value, PyBytes) {
        return bytes_hash_obj(value as PyBytes);
    }
    if isinstance(value, PySet) {
        return set_hash_obj(value as PySet);
    }
    return hash_element(value);
}

def py_aiter_has_anext(value: PyObj) -> bool {
    if isinstance(value, PyUserObj) {
        return user_has_dunder(value as PyUserObj, "__anext__");
    }
    return not is_error(py_attr(value, "__anext__"));
}

# `async for`: call __aiter__ and verify the result exposes __anext__.
def py_aiter(value: PyObj) -> PyObj {
    if isinstance(value, PyUserObj)
        and user_has_dunder(value as PyUserObj, "__aiter__") {
        result = call_user_dunder(value as PyUserObj, "__aiter__", []);
    } else {
        method = py_attr(value, "__aiter__");
        if is_error(method) {
            return method;
        }
        result = py_invoke(method, [], {});
    }
    if is_error(result) {
        return result;
    }
    if not py_aiter_has_anext(result) {
        type_label = result.t;
        if isinstance(result, PyUserObj) {
            type_label = (result as PyUserObj).cls.name;
        }
        return py_error(
            "TypeError",
            "'async for' received an object from __aiter__ that does not implement __anext__: "
                + type_label
        );
    }
    return result;
}

# Resolve a value to the iterator GET_AWAITABLE / SEND drive (native coroutine,
# generator, native async-gen driver, or host awaitable). A plain generator is
# only admitted when its code carries CO_ITERABLE_COROUTINE -- the
# types.coroutine contract; unmarked generators are rejected exactly as
# CPython's GET_AWAITABLE).
def py_get_awaitable(value: PyObj) -> PyObj {
    if value.t == "coroutine" {
        return value;
    }
    if value.t == "generator" {
        gen = value as PyGenerator;
        if (gen.frame.co.flags & 256) != 0 {
            return value;
        }
        return py_error("TypeError", "'generator' object can't be awaited");
    }
    if value.t == "agen_asend" or value.t == "agen_athrow" {
        return value;
    }
    if value.t == "async_generator" {
        return py_error("TypeError", "object async_generator can't be used in 'await' expression");
    }
    if isinstance(value, PyHostProxy) {
        hp = value as PyHostProxy;
        resolved = _jac_host_resolve_awaitable(hp.val);
        if bool(resolved[0]) {
            # Directly drivable (native coroutine/generator send surface) or
            # already resolved through __await__(): keep the proxy; SEND drives
            # it via its own send/throw attribute surface.
            return PyHostProxy(t="host", val=resolved[1]);
        }
        return py_error("TypeError", str(resolved[2]));
    }
    return py_error("TypeError", "object can't be used in 'await' expression");
}

# `async for` loop step: call __anext__ on the async iterator and wrap the result
# as an awaitable for the following SEND loop.
def py_anext(aiter: PyObj) -> PyObj {
    if isinstance(aiter, PyUserObj)
        and user_has_dunder(aiter as PyUserObj, "__anext__") {
        result = call_user_dunder(aiter as PyUserObj, "__anext__", []);
    } else {
        method = py_attr(aiter, "__anext__");
        if is_error(method) {
            return method;
        }
        result = py_invoke(method, [], {});
    }
    if is_error(result) {
        return result;
    }
    return py_get_awaitable(result);
}

def py_len(value: PyObj) -> PyObj {
    if isinstance(value, PyRange) {
        return PyInt(t="int", val=(value as PyRange).length());
    }
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
    if isinstance(value, PyMappingProxy) {
        return py_len((value as PyMappingProxy).target as PyObj);
    }
    if isinstance(value, PyUserObj) {
        u = value as PyUserObj;
        if user_has_dunder(u, "__len__") {
            res = call_user_dunder(u, "__len__", []);
            if is_error(res) {
                return res;
            }
            if isinstance(res, PyBool) {
                # bool IS an int subclass in CPython: True/False are valid lens.
                res = PyInt(t="int", val=1 if (res as PyBool).val else 0);
            }
            if isinstance(res, PyInt) {
                if (res as PyInt).val < 0 {
                    return py_error("ValueError", "__len__() should return >= 0");
                }
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
        hv_r = to_host_coerce(value);
        hv = hv_r[1];
        if not ((hv_r[0] as bool)) {
            return hv_r[1] as PyObj;
        }
        result = _jac_host_len(hv);
        if host_result_ok(result) {
            return from_host(result[1]);
        }
        return host_result_error(result);
    }
    return py_error("TypeError", "object of type '" + value.t + "' has no len()");
}

# CPython tp_flags bits (Include/object.h) used by MATCH_* opcodes.
glob _TPFLAGS_SEQUENCE: int = 32,
     _TPFLAGS_MAPPING: int = 64,
     _TPFLAGS_MATCH_SELF: int = 4194304,
     _match_keys_dummy: PyObj = py_none();

def match_keys_dummy -> PyObj {
    if _match_keys_dummy.t == "none" {
        built = _jac_construct_builtin("object", []);
        if host_result_ok(built) {
            _match_keys_dummy = from_host(built[1]);
        }
    }
    return _match_keys_dummy;
}

def py_type_has_sequence_flag(value: PyObj) -> bool {
    if value.t == "list" or value.t == "tuple" {
        return True;
    }
    if value.t == "str" or value.t == "bytes" {
        return False;
    }
    if isinstance(value, PyUserObj) {
        return obj_is_builtin(value, "list") or obj_is_builtin(value, "tuple");
    }
    if isinstance(value, PyHostProxy) {
        host_val = (value as PyHostProxy).val;
        if _jac_isinstance_of_builtin(host_val, "str")
            or _jac_isinstance_of_builtin(host_val, "bytes") {
            return False;
        }
        if _jac_type_has_flag(host_val, _TPFLAGS_SEQUENCE) {
            return True;
        }
        return (_jac_isinstance_of_builtin(host_val, "list")
            or _jac_isinstance_of_builtin(host_val, "tuple")) as bool;
    }
    return False;
}

def py_type_has_mapping_flag(value: PyObj) -> bool {
    if value.t == "dict" {
        return True;
    }
    if isinstance(value, PyUserObj) {
        return obj_is_builtin(value, "dict");
    }
    if isinstance(value, PyHostProxy) {
        host_val = (value as PyHostProxy).val;
        if _jac_type_has_flag(host_val, _TPFLAGS_MAPPING) {
            return True;
        }
        return _jac_isinstance_of_builtin(host_val, "dict") as bool;
    }
    return False;
}

def py_type_has_match_self_flag(type_obj: PyObj) -> bool {
    if isinstance(type_obj, PyHostProxy) {
        return _jac_type_has_flag((type_obj as PyHostProxy).val, _TPFLAGS_MATCH_SELF) as bool;
    }
    return False;
}

def match_class_type_name(type_obj: PyObj) -> str {
    if isinstance(type_obj, PyClass) {
        return (type_obj as PyClass).name;
    }
    # A host class pattern wraps the class itself; _jac_host_pattern_name
    # quotes its own name (not the metaclass's) like CPython's tp_name.
    if isinstance(type_obj, PyHostProxy) {
        return str(_jac_host_pattern_name((type_obj as PyHostProxy).val));
    }
    return "?";
}

def py_match_attr_optional(value: PyObj, name: str) -> PyObj {
    attr = py_attr(value, name);
    if is_error(attr) {
        if isinstance(attr, PyError)
            and (attr as PyError).exception.type_name == "AttributeError" {
            return py_none();
        }
        return attr;
    }
    return attr;
}

def py_match_type_attr_optional(type_obj: PyObj, name: str) -> PyObj {
    if isinstance(type_obj, PyClass) {
        found = class_lookup_attr(type_obj as PyClass, name);
        if not is_error(found) {
            return found;
        }
        if isinstance(found, PyError)
            and (found as PyError).exception.type_name == "AttributeError" {
            return py_none();
        }
        return found;
    }
    return py_match_attr_optional(type_obj, name);
}

def py_match_class_attr(
    subject: PyObj, type_obj: PyObj, name: PyObj, seen: PySet
) -> PyObj {
    if not isinstance(name, PyStr) {
        return py_error(
            "TypeError", "__match_args__ elements must be strings (got " + name.t + ")",
        );
    }
    if seen.set_contains(name) {
        return py_error(
            "TypeError",
            match_class_type_name(type_obj)
                + "() got multiple sub-patterns for attribute "
                + dict_key_repr(name),
        );
    }
    seen.set_add(name);
    attr = py_match_attr_optional(subject, (name as PyStr).val);
    if is_error(attr) {
        return attr;
    }
    if attr.t == "none" {
        return py_none();
    }
    return attr;
}

def py_match_keys(map_obj: PyObj, keys: PyObj) -> PyObj {
    if not isinstance(keys, PyTuple) {
        return py_error("TypeError", "MATCH_KEYS keys must be a tuple");
    }
    key_items = (keys as PyTuple).items;
    nkeys = len(key_items);
    if nkeys == 0 {
        return PyTuple(t="tuple", items=[]);
    }
    get_m = py_attr(map_obj, "get");
    if is_error(get_m) {
        return get_m;
    }
    dummy = match_keys_dummy();
    seen = PySet(t="set", items={}, frozen=False);
    values: list[PyObj] = [];
    ki = 0;
    while ki < nkeys {
        key = key_items[ki];
        if seen.set_contains(key) {
            return py_error(
                "ValueError",
                "mapping pattern checks duplicate key (" + dict_key_repr(key) + ")",
            );
        }
        seen.set_add(key);
        val = py_invoke(get_m, [key, dummy], {});
        if is_error(val) {
            return val;
        }
        if val is dummy {
            return py_none();
        }
        values.append(val);
        ki = ki + 1;
    }
    return PyTuple(t="tuple", items=values);
}

def py_match_class(
    subject: PyObj, type_obj: PyObj, nargs: int, kw_names: PyObj
) -> PyObj {
    if not isinstance(type_obj, PyClass) and not isinstance(type_obj, PyHostProxy) {
        return py_error("TypeError", "called match pattern must be a class");
    }
    if not isinstance(kw_names, PyTuple) {
        return py_error("TypeError", "MATCH_CLASS names must be a tuple");
    }
    if not py_isinstance(subject, type_obj) {
        return py_none();
    }
    seen = PySet(t="set", items={}, frozen=False);
    attrs_list: list[PyObj] = [];
    if nargs > 0 {
        match_args_obj = py_match_type_attr_optional(type_obj, "__match_args__");
        if is_error(match_args_obj) {
            return match_args_obj;
        }
        match_self = 0;
        match_args: PyTuple;
        if match_args_obj.t == "none" {
            match_args = PyTuple(t="tuple", items=[]);
            if py_type_has_match_self_flag(type_obj) {
                match_self = 1;
            }
        } else {
            if not isinstance(match_args_obj, PyTuple) {
                got = match_args_obj.t;
                if isinstance(match_args_obj, PyHostProxy) {
                    got = str(_jac_host_type_name((match_args_obj as PyHostProxy).val));
                }
                return py_error(
                    "TypeError",
                    match_class_type_name(type_obj)
                        + ".__match_args__ must be a tuple (got "
                        + got
                        + ")",
                );
            }
            match_args = match_args_obj as PyTuple;
        }
        allowed = len(match_args.items);
        if match_self {
            allowed = 1;
        }
        if allowed < nargs {
            plural = "s";
            if allowed == 1 {
                plural = "";
            }
            return py_error(
                "TypeError",
                match_class_type_name(type_obj)
                    + "() accepts "
                    + str(allowed)
                    + " positional sub-pattern"
                    + plural
                    + " ("
                    + str(nargs)
                    + " given)",
            );
        }
        if match_self {
            attrs_list.append(subject);
        } else {
            pi = 0;
            while pi < nargs {
                name = match_args.items[pi];
                attr = py_match_class_attr(subject, type_obj, name, seen);
                if is_error(attr) {
                    return attr;
                }
                if attr.t == "none" {
                    return py_none();
                }
                attrs_list.append(attr);
                pi = pi + 1;
            }
        }
    }
    kw_tuple = kw_names as PyTuple;
    ki = 0;
    while ki < len(kw_tuple.items) {
        name = kw_tuple.items[ki];
        attr = py_match_class_attr(subject, type_obj, name, seen);
        if is_error(attr) {
            return attr;
        }
        if attr.t == "none" {
            return py_none();
        }
        attrs_list.append(attr);
        ki = ki + 1;
    }
    return PyTuple(t="tuple", items=attrs_list);
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
    return host_result_error(result);
}

# The PyObj yielded by a dict iterator at its current position: the key (keys),
# the value (values), or a (key, value) PyTuple (items). The caller has already
# confirmed the iterator is not stale, so the hashkey is still present.
def dictiter_yield(di: PyDictIter) -> PyObj {
    hk = di.keys[di.index];
    `entry = di.d.items[hk];
    if di.mode == "values" {
        return `entry.value;
    }
    if di.mode == "items" {
        return PyTuple(t="tuple", items=[`entry.key, `entry.value]);
    }
    return `entry.key;
}

def dictiter_error -> PyObj {
    return py_error("RuntimeError", "dictionary changed size during iteration");
}

# CPython 3.11+ indexes LOAD_FAST / *_DEREF / MAKE_CELL into a single merged
# "localsplus" array laid out as [varnames(nlocals)] [cellvars-not-already-a-var]
# [freevars]. This VM mirrors that with ONE physical array (frame.fast): entries
# hold a plain value OR a PyCell -- cells live IN their slots, seeded at frame
# setup and extended mid-frame by OP_MAKE_CELL (inlined comprehensions), which
# is what makes per-execution fresh comprehension cells possible. resolve_cell
# reads the slot directly; there is deliberately NO static name->cell map (a
# static map pins one cell per name per frame, clobbering cells captured by
# earlier comprehension runs).
def resolve_cell(fast: list[PyObj], arg: int) -> PyCell | None {
    if arg < len(fast) and isinstance(fast[arg], PyCell) {
        return fast[arg] as PyCell;
    }
    return None;
}

# Name of merged-localsplus slot `arg`: [varnames] [cellvars not shadowing a
# varname, in cellvar order] [freevars] -- the layout frame setup builds.
def localsplus_name(co: PyCode, arg: int) -> str {
    nv = len(co.varnames);
    if arg < nv {
        return co.varnames[arg];
    }
    off = nv;
    ci = 0;
    while ci < len(co.cellvars) {
        if find_name(co.varnames, co.cellvars[ci]) < 0 {
            if arg == off {
                return co.cellvars[ci];
            }
            off = off + 1;
        }
        ci = ci + 1;
    }
    return co.freevars[arg - off];
}

# CPython _PyEval_FormatExcUnbound (Python/ceval.c): a localsplus index below
# the free region is an UnboundLocalError; at or above it, the free-variable
# NameError. Message text byte-exact with the host.
def format_exc_unbound(co: PyCode, arg: int) -> PyObj {
    lpname = localsplus_name(co, arg);
    ncell = 0;
    ci = 0;
    while ci < len(co.cellvars) {
        if find_name(co.varnames, co.cellvars[ci]) < 0 {
            ncell = ncell + 1;
        }
        ci = ci + 1;
    }
    if arg < len(co.varnames) + ncell {
        return py_error(
            "UnboundLocalError",
            "cannot access local variable '" + lpname + "' where it is not associated with a value",
        );
    }
    return py_error(
        "NameError",
        "cannot access free variable '" + lpname + "' where it is not associated with a value in enclosing scope",
    );
}

def fast_value(co: PyCode, arg: int, fast: list[PyObj]) -> PyObj {
    # A converted (cell) slot yields the CELL OBJECT -- that is how LOAD_FAST /
    # LOAD_FAST_BORROW fetch a live cell to seed an inner function's closure
    # (CPython's GETLOCAL returns whatever lives in the slot). A plain local
    # yields its value.
    if arg < len(fast) {
        return fast[arg];
    }
    return py_error("UnboundLocalError", "local variable is not set");
}

def fast_value_check(
    co: PyCode,
    arg: int,
    fast: list[PyObj],
    assigned: list[bool],
) -> PyObj {
    # LOAD_FAST_CHECK: like LOAD_FAST but raises UnboundLocalError when the
    # plain-local slot was never STORE_FAST-bound (CPython 3.14+ null check).
    # Converted (cell) slots are always bound.
    if arg >= len(fast) {
        return py_error("UnboundLocalError", "local variable is not set");
    }
    if isinstance(fast[arg], PyCell) {
        return fast[arg];
    }
    if arg < len(assigned) and not assigned[arg] {
        vname = "?";
        if arg < len(co.varnames) {
            vname = co.varnames[arg];
        }
        return py_error(
            "UnboundLocalError",
            "cannot access local variable '"
                + vname
                + "' where it is not associated with a value",
        );
    }
    return fast[arg];
}

# Signed varint (zigzag-style: bit 0 is the sign) used by linetable line deltas.
def read_svarint(data: list[int], pos: int) -> tuple[int, int] {
    (uval, npos) = read_varint(data, pos);
    if uval % 2 == 1 {
        return (-(uval >> 1), npos);
    }
    return ((uval >> 1), npos);
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

# Line number for a bytecode offset, decoded from the PEP 626 location table
# (same format the assembler emits and host marshal delivers; entry layout per
# CPython advance_with_locations in Objects/codeobject.c: first byte carries a
# 128 start bit, kind in bits 3-6, run length in bits 0-2).
def pycode_lineno(co: PyCode, offset: int) -> int {
    line = co.firstlineno;
    table = co.linetable;
    pos = 0;
    span_start = 0;
    while pos < len(table) {
        first = table[pos];
        if (first & 128) == 0 {
            # Not an entry start byte: corrupt table, stop with best-known line.
            break;
        }
        kind = (first >> 3) & 15;
        units = (first & 7) + 1;
        pos = pos + 1;
        span_end = span_start + units * 2;
        # NONE entries carry no location; keep the last known line so a raise
        # inside an unlocated region still reports something sane.
        if kind != 15 {
            if kind == 14 {
                # LONG: signed line delta + three varints (endline delta, cols).
                dec = read_svarint(table, pos);
                line = line + dec[0];
                pos = dec[1];
                dec = read_varint(table, pos);
                pos = dec[1];
                dec = read_varint(table, pos);
                pos = dec[1];
                dec = read_varint(table, pos);
                pos = dec[1];
            } elif kind == 13 {
                # NO_COLUMNS: signed line delta only.
                dec = read_svarint(table, pos);
                line = line + dec[0];
                pos = dec[1];
            } elif kind >= 10 {
                # ONE_LINE0..2: fixed line deltas, two raw column bytes.
                line = line + (kind - 10);
                pos = pos + 2;
            } else {
                # SHORT0..9: same line, one raw column-pair byte.
                pos = pos + 1;
            }
            if offset >= span_start and offset < span_end {
                return line;
            }
        }
        span_start = span_end;
    }
    return line;
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
    # Traceback growth (CPython generic `error` label): every ERROR EVENT --
    # a failing opcode or RAISE_VARARGS 1/2 -- prepends exactly one entry per
    # frame before handler search, so e.__traceback__ heads at the catching
    # frame and tb_next walks toward the raise point. Reraises are NOT error
    # events: RERAISE and bare RAISE_VARARGS 0 jump straight to
    # exception_unwind in CPython, adding no entry -- those paths must go
    # through dispatch_exception below instead.
    error = value as PyError;
    prev = error.exception.traceback;
    error.exception.traceback = PyTraceback(
        t="traceback",
        tb_next=prev,
        code=co,
        tb_lineno=pycode_lineno(co, offset),
        tb_lasti=offset
    );
    return dispatch_exception(co, value, offset, offset, stack);
}

# Handler search + stack handoff WITHOUT traceback growth. This is CPython's
# exception_unwind: locate the covering exception-table entry (at `offset`,
# the faulting/reraising instruction), trim the value stack to its depth, push
# lasti (when flagged; `lasti_offset` lets re-raises push the RESTORED lasti,
# matching CPython's instr_ptr restore) and the exception, and jump.
def dispatch_exception(
    co: PyCode,
    value: PyObj,
    offset: int,
    lasti_offset: int,
    stack: list[PyObj]
) -> int {
    handler = find_handler(co, offset);
    if handler is None {
        return -1;
    }
    error = value as PyError;
    while len(stack) > handler.depth {
        stack.pop();
    }
    if handler.lasti {
        stack.append(PyInt(t="int", val=lasti_offset));
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
    if target.t == "tuple" {
        # `except (A, B):` - CPython's CHECK_EXC_MATCH delegates to
        # PyErr_GivenExceptionMatches, which iterates tuple targets.
        for item in (target as PyTuple).items {
            if exception_matches(value, item) {
                return True;
            }
        }
        return False;
    }
    target_name: str = "";
    if target.t == "exception_type" {
        target_name = (target as PyExceptionType).name;
    } elif target.t == "host" {
        # The except-target is a host exception CLASS; read its own __name__, not
        # type(cls).__name__ (which is "type" and never matches).
        target_name = _jac_host_class_name((target as PyHostProxy).val) as str;
    }
    if target_name == "" {
        return False;
    }
    # A raised USER exception instance matches builtin targets through its real
    # MRO: class MyErr(KeyError) must satisfy `except KeyError` even though the
    # name-level tree has no MyErr entry. Walk the MRO classes and their bases,
    # which carry the native/host exception-type markers recorded at class
    # creation.
    raw = exception.raw;
    if raw is not None and isinstance(raw, PyUserObj) {
        for klass in class_mro((raw as PyUserObj).cls) {
            if klass.name == target_name {
                return True;
            }
            for base in klass.bases {
                # Transitive name-level match so a user subclass of a builtin
                # subclass (MyErr(KeyError)) satisfies broader targets
                # (`except LookupError`); inclusive of exact equality.
                if isinstance(base, PyExceptionType)
                    and exc_is_subclass_of(
                        (base as PyExceptionType).name, target_name
                    ) {
                    return True;
                }
                if isinstance(base, PyHostProxy)
                    and (_jac_host_class_name((base as PyHostProxy).val) as str)
                        == target_name {
                    return True;
                }
            }
        }
    }
    return exc_name_matches(exception.type_name, target_name);
}

# True iff a raised error IS StopIteration or a SUBCLASS of it -- CPython's
# FOR_ITER / tp_iternext exhaustion contract matches by type
# (PyErr_ExceptionMatches), never by exact type-name equality. Covers builtin
# name-chain subclasses via exc_name_matches and guest classes whose bases
# reach the native StopIteration type.
def error_is_stopiteration(err: PyObj) -> bool {
    if err.t != "error" {
        return False;
    }
    exc = (err as PyError).exception;
    if exc_name_matches(exc.type_name, "StopIteration") {
        return True;
    }
    raw = exc.raw;
    if raw is not None and isinstance(raw, PyUserObj) {
        for klass in class_mro((raw as PyUserObj).cls) {
            for base in klass.bases {
                if isinstance(base, PyExceptionType)
                    and (base as PyExceptionType).name == "StopIteration" {
                    return True;
                }
            }
        }
    }
    return False;
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

# ---------------- except* primitives (CHECK_EG_MATCH) ----------------

# True iff a builtin exception-family name sits under BaseExceptionGroup.
# The plain parent walk misses PEP 654's polymorphism -- EXC_PARENT records
# ExceptionGroup under Exception, not under BaseExceptionGroup -- so the
# ExceptionGroup branch is checked explicitly.
def exc_is_eg_family(name: str) -> bool {
    return exc_is_subclass_of(name, "BaseExceptionGroup")
        or exc_is_subclass_of(name, "ExceptionGroup");
}

# Builtin exception-family name behind a caught-class target: PyExceptionType
# for builtin names, host class for delegated ones, and the nearest builtin
# PyExceptionType base for user classes (class MyErr(KeyError) -> "KeyError").
# "" marks a target that is not an exception class at all.
def eg_target_family(target: PyObj) -> str {
    if isinstance(target, PyExceptionType) {
        return (target as PyExceptionType).name;
    }
    if isinstance(target, PyHostProxy)
        and bool(_jac_is_exception_type((target as PyHostProxy).val)) {
        return _jac_host_class_name((target as PyHostProxy).val) as str;
    }
    if isinstance(target, PyClass) {
        for klass in class_mro(target as PyClass) {
            for base in klass.bases {
                if isinstance(base, PyExceptionType) {
                    return (base as PyExceptionType).name;
                }
                if isinstance(base, PyHostProxy)
                    and bool(_jac_is_exception_type((base as PyHostProxy).val)) {
                    return _jac_host_class_name((base as PyHostProxy).val) as str;
                }
            }
        }
    }
    return "";
}

# _PyEval_CheckExceptStarTypeValid: every except* target must be an exception
# class (tuple members included), and none may be an ExceptionGroup subclass
# (CPython's CANNOT_EXCEPT_STAR_EG TypeError). Returns py_none() when valid.
def eg_validate_star_target(target: PyObj) -> PyObj {
    if target.t == "tuple" {
        for item in (target as PyTuple).items {
            invalid = eg_validate_star_target(item);
            if is_error(invalid) {
                return invalid;
            }
        }
        return py_none();
    }
    family = eg_target_family(target);
    if family == "" {
        return py_error(
            "TypeError",
            "catching classes that do not inherit from BaseException is not allowed"
        );
    }
    if exc_is_eg_family(family) {
        return py_error(
            "TypeError",
            "catching ExceptionGroup with except* is not allowed. Use except instead."
        );
    }
    return py_none();
}

# True iff a raised instance is an ExceptionGroup (BaseExceptionGroup family).
# User subclasses carry their builtin ancestor in `family` -- type_name alone
# would hide class MyGrp(ExceptionGroup) from the check.
def eg_is_group(exc: PyObj) -> bool {
    if exc.t != "exception" {
        return False;
    }
    e = exc as PyException;
    if exc_is_eg_family(e.type_name) {
        return True;
    }
    return e.family != "" and exc_is_eg_family(e.family);
}

# Leaf builtin-family name for the all-Exception rule below: user leaves
# resolve through their recorded family, builtin leaves through type_name.
def eg_leaf_family(exc: PyObj) -> str {
    e = exc as PyException;
    return e.family if e.family != "" else e.type_name;
}

# The group's member sequence, as stored by PyExceptionType.tp_call at
# construction time: args == [message, members]. Only list/tuple members are
# recognized; anything else is a malformed instance and surfaces as SystemError.
def eg_members(exc: PyObj) -> PyObj {
    args = (exc as PyException).args;
    if len(args) >= 2 {
        seq = args[1];
        if isinstance(seq, PyList) {
            return seq;
        }
        if isinstance(seq, PyTuple) {
            items: list[PyObj] = [];
            items.extend((seq as PyTuple).items);
            return PyList(t="list", items=items);
        }
    }
    return py_error("SystemError", "malformed ExceptionGroup instance");
}

# The group's message: args[0] per the tp_call layout above; falls back to the
# message field for groups built by other paths.
def eg_message(exc: PyObj) -> str {
    args = (exc as PyException).args;
    if len(args) > 0 and isinstance(args[0], PyStr) {
        return (args[0] as PyStr).val;
    }
    return (exc as PyException).message;
}

# All-Exception scan over a rebuilt member list: ExceptionGroup may only wrap
# Exception leaves; any BaseException leaf forces BaseExceptionGroup.
def eg_all_exception(members: PyList) -> bool {
    for m in members.items {
        if eg_is_group(m) {
            sub = eg_members(m);
            if is_error(sub) or not eg_all_exception(sub as PyList) {
                return False;
            }
        } elif not exc_is_subclass_of(eg_leaf_family(m), "Exception") {
            return False;
        }
    }
    return True;
}

# Rebuild an ExceptionGroup around surviving members, mirroring the
# PyExceptionType.tp_call storage layout so eg_members/eg_message round-trip.
# Derived-group narrowing (PEP 654 derive()) stays out of scope: rebuilt
# subgroups use the plain Exception/BaseExceptionGroup split fallback.
def eg_build(message: str, members: list[PyObj]) -> PyObj {
    if len(members) == 0 {
        return py_none();
    }
    inner: list[PyObj] = [];
    inner.extend(members);
    name = "BaseExceptionGroup";
    if eg_all_exception(PyList(t="list", items=inner)) {
        name = "ExceptionGroup";
    }
    stored_args: list[PyObj] = [
        PyStr(t="str", val=message),
        PyList(t="list", items=inner),
    ];
    excs_copy: list[PyObj] = [];
    excs_copy.extend(members);
    # Construct the typed group object so rebuilt groups carry the full
    # member surface (.message/.exceptions), same as tp_call construction.
    return PyExcGroup(
        t="exception", type_name=name, message=message,
        args=stored_args, excs=excs_copy
    );
}


# _PyEval_ExceptionGroupMatch primitive: returns (rest, match). A full match
# yields (None, group-or-wrapped-exc); an EG partial match yields the split
# pair (either half may be None); no match yields (exc, None). Both None means
# there was no active exception.
# ---------------- P3 split/subgroup kernel (PEP 654) ----------------
# Port of Objects/exception_groups.c: check_subgroup condition validation and
# subgroup_split_recursive partitioning. Conditions are exception types,
# tuples of them, None (matches everything), or a callable applied per leaf.
# Type matching routes through the family-string matcher, so an unhashable
# metaclass type stays a valid condition (no hashing on this path).

obj PyAddNoteMethod(PyObj) {
    has target: PyException;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 1 or not isinstance(args[0], PyStr) {
            return py_error("TypeError", "add_note() argument must be a str");
        }
        note = args[0];
        existing = self.target.type_fields.get("__notes__");
        notes: list[PyObj] = [];
        if existing is not None and isinstance(existing, PyList) {
            notes.extend((existing as PyList).items);
        }
        notes.append(note);
        self.target.type_fields["__notes__"] = PyList(t="list", items=notes);
        return py_none();
    }
}

obj PyExcGroupMethod(PyObj) {
    has target: PyExcGroup,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 1 {
            return py_error(
                "TypeError",
                self.name + "() takes exactly one argument ("
                + str(len(args)) + " given)"
            );
        }
        if self.name == "split" {
            return eg_split_entry(self.target, args[0]);
        }
        return eg_subgroup_entry(self.target, args[0]);
    }
}

def eg_condition_error() -> PyObj {
    return py_error(
        "TypeError",
        "expected an exception type, a tuple of exception types, or a "
        "callable (other than a class)"
    );
}

# "" = invalid; "all" = None; "match" = type/tuple-of-types; "pred" = callable.
def eg_condition_kind(cond: PyObj) -> str {
    if cond.t == "none" {
        return "all";
    }
    if cond.t == "tuple" {
        for item in (cond as PyTuple).items {
            if eg_target_family(item) == "" and not isinstance(item, PyClass) {
                return "";
            }
        }
        return "match";
    }
    if eg_target_family(cond) != "" {
        return "match";
    }
    # Guest-defined classes carry no builtin family at the root; their name
    # matches leaves through eg_cond_match without crossing the host bridge
    # (an unhashable metaclass must never be hashed or to_host'ed here).
    if isinstance(cond, PyClass) {
        return "match";
    }
    if isinstance(cond, PyFunction) or isinstance(cond, PyNativeBuiltin) {
        return "pred";
    }
    return "";
}

# Leaf-vs-condition match for kind == "match": guest classes compare by name /
# family subclass chains (no hashing); builtin types and tuples delegate to
# the standard matcher.
def eg_cond_match(leaf: PyObj, cond: PyObj) -> bool {
    if isinstance(cond, PyClass) {
        lf = eg_leaf_family(leaf);
        cname = (cond as PyClass).name;
        return lf == cname or exc_is_subclass_of(lf, cname);
    }
    # Builtin/host-proxy types match through family strings -- never through
    # the host bridge, so an unhashable metaclass type stays valid.
    cf = eg_target_family(cond);
    if cf != "" {
        lf = eg_leaf_family(leaf);
        return lf == cf or exc_is_subclass_of(lf, cf);
    }
    return exception_matches(leaf, cond);
}

# subgroup_split_recursive: partitions the group's members into (match, rest)
# group halves sharing the original message; nested groups are rebuilt (never
# reused), empty halves collapse to None, leaves keep identity. Third slot
# carries an error instead when condition evaluation raises.
def eg_split_rec(gexc: PyObj, kind: str, cond: PyObj) -> tuple[PyObj, PyObj, PyObj] {
    m_items: list[PyObj] = [];
    r_items: list[PyObj] = [];
    members = eg_members(gexc);
    if is_error(members) {
        return (py_none(), py_none(), members);
    }
    for m in (members as PyList).items {
        matched = False;
        if eg_is_group(m) {
            triple = eg_split_rec(m, kind, cond);
            if is_error(triple[2]) {
                return (py_none(), py_none(), triple[2]);
            }
            if triple[0].t != "none" {
                m_items.append(triple[0]);
            }
            if triple[1].t != "none" {
                r_items.append(triple[1]);
            }
            continue;
        }
        if kind == "all" {
            matched = true;
        } elif kind == "match" {
            matched = eg_cond_match(m, cond);
        } else {
            rv = py_invoke(cond, [m], {});
            if is_error(rv) {
                return (py_none(), py_none(), rv);
            }
            matched = rv.tp_bool();
        }
        if matched {
            m_items.append(m);
        } else {
            r_items.append(m);
        }
    }
    msg = eg_message(gexc);
    return (eg_build(msg, m_items), eg_build(msg, r_items), py_none());
}

# split_recursive tail: derived partitions inherit the original group's
# __context__/__cause__ when set (CPython SetContext/SetCause).
def eg_copy_chain(orig: PyObj, derived: PyObj) -> None {
    o = orig as PyException;
    d = derived as PyException;
    if o.context is not None {
        d.context = o.context;
    }
    if o.cause is not None {
        d.cause = o.cause;
    }
}

def eg_split_entry(exc: PyObj, cond: PyObj) -> PyObj {
    kind = eg_condition_kind(cond);
    if kind == "" {
        return eg_condition_error();
    }
    triple = eg_split_rec(exc, kind, cond);
    if is_error(triple[2]) {
        return triple[2];
    }
    if triple[0].t == "exception" {
        eg_copy_chain(exc, triple[0]);
    }
    if triple[1].t == "exception" {
        eg_copy_chain(exc, triple[1]);
    }
    items: list[PyObj] = [triple[0], triple[1]];
    return PyTuple(t="tuple", items=items);
}

def eg_subgroup_entry(exc: PyObj, cond: PyObj) -> PyObj {
    kind = eg_condition_kind(cond);
    if kind == "" {
        return eg_condition_error();
    }
    triple = eg_split_rec(exc, kind, cond);
    if is_error(triple[2]) {
        return triple[2];
    }
    if triple[0].t == "exception" {
        eg_copy_chain(exc, triple[0]);
    }
    return triple[0];
}


def exception_group_split(exc: PyObj, target: PyObj) -> tuple[PyObj, PyObj] {
    if exc.t == "none" {
        return (py_none(), py_none());
    }
    if exception_matches(exc, target) {
        matched_whole: PyObj = exc;
        if not eg_is_group(exc) {
            # Naked exception: CPython wraps it in ExceptionGroup('', [exc])
            # with the current traceback attached; traceback plumbing lands
            # with the PREP_RERAISE_STAR lane.
            matched_whole = eg_build("", [exc]);
        }
        return (py_none(), matched_whole);
    }
    if eg_is_group(exc) {
        members_obj = eg_members(exc);
        if is_error(members_obj) {
            return (members_obj, py_none());
        }
        matched: list[PyObj] = [];
        unmatched: list[PyObj] = [];
        msg = eg_message(exc);
        for m in (members_obj as PyList).items {
            if eg_is_group(m) {
                sub = exception_group_split(m, target);
                if is_error(sub[0]) {
                    return sub;
                }
                if sub[1].t != "none" {
                    matched.append(sub[1]);
                }
                if sub[0].t != "none" {
                    unmatched.append(sub[0]);
                }
            } elif exception_matches(m, target) {
                matched.append(m);
            } else {
                unmatched.append(m);
            }
        }
        return (eg_build(msg, unmatched), eg_build(msg, matched));
    }
    return (exc, py_none());
}

# BaseException attribute view of a USER exception instance: CPython records
# args at construction time (BaseException_new) and its tp_str/tp_repr read
# that slot, so a subclass without custom __str__/__repr__ presents exactly
# like its builtin base. The wrapper borrows the class name + stored args.
def user_exception_view(u: PyUserObj) -> PyException {
    exc_args: list[PyObj] = [];
    stored = u.attrs.get("args");
    if isinstance(stored, PyTuple) {
        exc_args.extend((stored as PyTuple).items);
    }
    # Resolve the nearest builtin exception ancestor (class MyErr(KeyError) ->
    # "KeyError") so per-type __str__/attribute semantics inherited from the
    # builtin base apply to the wrapper view exactly like CPython's slots.
    family: str = "";
    for klass in class_mro(u.cls) {
        for base in klass.bases {
            if isinstance(base, PyExceptionType) {
                family = (base as PyExceptionType).name;
            } elif isinstance(base, PyHostProxy)
                and bool(_jac_is_exception_type((base as PyHostProxy).val)) {
                family = _jac_host_class_name((base as PyHostProxy).val) as str;
            }
        }
        if family != "" {
            break;
        }
    }
    return PyException(
        t="exception", type_name=u.cls.name, message="", args=exc_args,
        family=family, value=stopiter_value_from_args(family, u.cls.name, exc_args)
    );
}

# CPython stopiteration_init: a StopIteration instance (or subclass instance)
# records args[0] as .value at construction. User subclasses raise through the
# PyUserObj wrapper view, so derive the payload there too -- yield-from
# unwinding reads exc.value off this view.
def stopiter_value_from_args(family: str, name: str, args: list[PyObj]) -> PyObj {
    if name == "StopIteration" or family == "StopIteration"
        or exc_is_subclass_of(name, "StopIteration")
        or (family != "" and exc_is_subclass_of(family, "StopIteration")) {
        if len(args) > 0 {
            return args[0];
        }
    }
    return py_none();
}

# True iff a raised exception IS StopIteration or derives from it -- the
# exhaustion test every yield-from unwinding performs (genobject.c uses
# PyErr_ExceptionMatches(PyExc_StopIteration)). Builtin names resolve through
# the name-level tree; user subclasses through the wrapper view's family.
def exc_is_stopiter(exc: PyException) -> bool {
    return exc_name_matches(exc.type_name, "StopIteration")
        or (exc.family != "" and exc_name_matches(exc.family, "StopIteration"));
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
    # `raw` so `except <UserClass>` can match it by MRO. The wrapper's args mirror
    # the args the instance recorded at construction time (PyClass.tp_call stores
    # them for exception-derived classes, matching CPython's BaseException_new),
    # so str(e)/repr(e)/e.args on a caught user exception see real arguments.
    if isinstance(value, PyUserObj) {
        u = value as PyUserObj;
        if class_is_exception(u.cls) {
            view = user_exception_view(u);
            # Keep the instance so `except <UserClass>` can match by MRO.
            view.raw = value;
            return PyError(t="error", exception=view);
        }
    }
    # A raised exception CLASS (raise Exc) auto-instantiates, then re-raises.
    if isinstance(value, PyClass) and class_is_exception(value as PyClass) {
        instance = (value as PyClass).tp_call([], {});
        if is_error(instance) {
            return instance;
        }
        # CPython do_raise contract: calling the class must yield a real
        # BaseException INSTANCE (a subclass instance passes -- MRO-aware).
        # A broken __new__ that returns the class itself (or an unrelated
        # object) must TypeError here; recursing on the same input would
        # loop forever (gen.throw(E) VM-crash fingerprint).
        if isinstance(instance, PyClass)
            or (isinstance(instance, PyUserObj)
                and not instance_of_class(instance as PyUserObj, value as PyClass)) {
            return py_error(
                "TypeError", "should have returned an instance of BaseException"
            );
        }
        return py_raise_value(instance);
    }
    if isinstance(value, PyHostProxy) {
        raw = (value as PyHostProxy).val;
        if bool(_jac_is_exception_type(raw)) {
            return PyError(
                t="error",
                exception=PyException(
                    t="exception", type_name=str(_jac_host_class_name(raw)), message=""
                )
            );
        }
        inst = _jac_host_exception_instance(raw);
        if bool(inst[0]) {
            return PyError(
                t="error",
                exception=PyException(
                    t="exception",
                    type_name=str(inst[1]),
                    message=str(inst[2]),
                    args=inst[3],
                    raw=value
                )
            );
        }
    }
    return py_error("TypeError", "exceptions must derive from BaseException");
}

def py_call_host(
    fn: PyHostProxy, args: list[PyObj], kwargs: dict[str, PyObj]
) -> PyObj {
    # An unbound builtin-method descriptor called with a NATIVE container as
    # receiver (list.append(lst, x), dict.get(d, k)) must operate on the real
    # native storage: marshaling through to_host hands the host a COPY, so the
    # call would silently no-op for mutators. Dispatch natively instead.
    info = _jac_host_unbound_method_info(fn.val);
    if bool(info[0]) and len(args) > 0 {
        owner = str(info[1]);
        meth = str(info[2]);
        recv = args[0];
        rest: list[PyObj] = [];
        i = 1;
        while i < len(args) {
            rest.append(args[i]);
            i = i + 1;
        }
        if owner == "list" and isinstance(recv, PyList) and is_list_method(meth) {
            return PyListMethod(t="list_method", target=(recv as PyList), name=meth).tp_call(rest, kwargs);
        }
        if owner == "dict" and isinstance(recv, PyDict) and is_dict_method(meth) {
            return PyDictMethod(t="dict_method", target=(recv as PyDict), name=meth).tp_call(rest, kwargs);
        }
        if owner == "set" and isinstance(recv, PySet) and is_set_method(meth, (recv as PySet).frozen) {
            return PySetMethod(t="set_method", target=(recv as PySet), name=meth).tp_call(rest, kwargs);
        }
    }
    # The `list` constructor consults iteration IN-VM before any bridge attempt:
    # to_host drops plain user objects (a generator/user iterable marshals as
    # None and host list(None) fails with the misleading 'NoneType' error while
    # iter(same object) works -- family-C bridge-first call site). py_iter sees
    # tp_iter/__iter__/boxed bases; on error fall through to the host call,
    # which stays authoritative for host-only iterables (dict views) and raises
    # the exact CPython TypeError for non-iterables.
    if len(args) == 1 and len(kwargs) == 0 and _jac_builtin_base_name(fn.val) == "list" {
        it = py_iter(args[0]);
        if not is_error(it) {
            return drain_to_list(it);
        }
    }
    # The `range` constructor builds a native PyRange in-VM: identity + laziness
    # (TODO item 19). Args must each be int-like (to_index unwraps bool and
    # boxed-int subclasses); ANY other arg shape -- non-int args, wrong arity,
    # keyword args, step == 0 -- falls through to the host call so error
    # messages stay byte-exact CPython.
    if len(kwargs) == 0 and _jac_is_range_type(fn.val)
        and (len(args) > 0 and len(args) < 4) {
        vals: list[int] = [];
        all_int = True;
        for a in args {
            iv = a.to_index();
            if is_error(iv) or not isinstance(iv, PyInt) {
                all_int = False;
                break;
            }
            vals.append((iv as PyInt).val);
        }
        if all_int {
            if len(args) == 1 {
                return PyRange(t="range", start=0, stop=vals[0], step=1);
            }
            if len(args) == 2 {
                return PyRange(t="range", start=vals[0], stop=vals[1], step=1);
            }
            if vals[2] != 0 {
                return PyRange(t="range", start=vals[0], stop=vals[1], step=vals[2]);
            }
        }
    }
    # repr()/format()/print() stringify their NATIVE operands in-VM BEFORE any
    # bridge attempt -- same family-C call-site rule as the list ctor above:
    # to_host of a plain user object is None, so the host builtin would answer
    # repr(None)/format(None, spec)/print(None) on a lost value. Anything that
    # is not a single native operand (arity errors, non-str format specs,
    # keyword-only shapes) falls through to the host call so error messages
    # stay byte-exact CPython.
    if len(kwargs) == 0 and len(args) == 1 and _jac_is_builtin_func(fn.val, "repr") {
        return py_repr(args[0]);
    }
    if len(kwargs) == 0 and len(args) == 1 and _jac_is_builtin_func(fn.val, "str") {
        return py_str(args[0]);
    }
    if len(kwargs) == 0 and len(args) >= 1 and len(args) <= 2
        and _jac_is_builtin_func(fn.val, "format")
        and (len(args) == 1 or isinstance(args[1], PyStr)) {
        spec = "";
        if len(args) == 2 {
            spec = (args[1] as PyStr).val;
        }
        return host_format(args[0], spec);
    }
    if _jac_is_builtin_func(fn.val, "print") {
        # print() applies str() to every positional argument natively
        # (PyObject_Str semantics); sep/end/file/flush kwargs pass through.
        printed: list[PyObj] = [];
        for item in args {
            s = py_str(item);
            if is_error(s) {
                return s;
            }
            printed.append(s);
        }
        args = printed;
    }
    raw_args: list[any] = [];
    for item in args {
        hi_r = to_host_coerce(item);
        hi = hi_r[1];
        if not ((hi_r[0] as bool)) {
            return hi_r[1] as PyObj;
        }
        raw_args.append(hi);
    }
    raw_kwargs: dict[str, any] = {};
    for key in kwargs {
        hk_r = to_host_coerce(kwargs[key]);
        hk = hk_r[1];
        if not ((hk_r[0] as bool)) {
            return hk_r[1] as PyObj;
        }
        raw_kwargs[key] = hk;
    }
    result = _jac_host_call(fn.val, raw_args, raw_kwargs);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return host_result_error(result);
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

# callable(): mirrors the tp_call slot presence. User instances are callable
# iff their MRO resolves __call__ (or they box a callable builtin base);
# host proxies delegate the probe to the wrapped value.
def obj_is_callable(x: PyObj) -> bool {
    if isinstance(x, (PyFunction, PyNativeBuiltin, PyClass, PyExceptionType,
                      PyBoundMethod, PyClassMethodCtor, PyStaticMethodCtor,
                      PyListMethod, PyDictMethod, PySetMethod, PyRangeMethod,
                      PyNsMethod, PyGenMethod, PyBuiltinSuperMethod, PyStrMethod)) {
        return True;
    }
    if isinstance(x, PyUserObj) {
        u = x as PyUserObj;
        if user_has_dunder(x, "__call__") {
            return True;
        }
        if u._has_base() {
            return obj_is_callable(u._base_obj());
        }
        return False;
    }
    if isinstance(x, PyHostProxy) {
        return (_jac_host_is_callable((x as PyHostProxy).val)) as bool;
    }
    return False;
}

# ---------------- Track B: builtin subclassing support -----------------------

# True iff the class's metaclass chain derives from an in-VM ABCMeta: any
# metaclass ancestor defines BOTH register and __subclasshook__ (the Lib/abc.py
# ABCMeta surface). Gates ABC-aware standin minting -- host C
# ABCMeta.__subclasscheck__ cannot see guest MROs, so such standins need the
# native check (_JacABCMeta).
def class_has_abc_meta(cls: PyClass) -> bool {
    meta = cls.metaclass;
    if meta is None or not isinstance(meta, PyClass) {
        return False;
    }
    for klass in class_mro(meta as PyClass) {
        if "register" in (klass as PyClass).attrs
            and "__subclasshook__" in (klass as PyClass).attrs {
            return True;
        }
    }
    return False;
}

# C3 linearization: L[C] = C + merge(L[B1], ..., L[Bn], [B1, ..., Bn]). This gives
# the strict CPython MRO -- a diamond D(B, C) with B,C : A resolves [D, B, C, A],
# so an attribute on both A and C picks C, not A. An inconsistent hierarchy (no
# valid linearization) degrades to the partial order computed so far rather than
# looping. Only PyClass bases participate; a native/host base is not a node here.
def class_mro(cls: PyClass) -> list[PyClass] {
    seqs: list[list[PyClass]] = [];
    direct: list[PyClass] = [];
    for base in cls.bases {
        if isinstance(base, PyClass) {
            seqs.append(class_mro(base as PyClass));
            direct.append(base as PyClass);
        }
    }
    if len(direct) > 0 {
        seqs.append(direct);
    }
    result: list[PyClass] = [cls];
    for klass in c3_merge(seqs) {
        result.append(klass);
    }
    return result;
}

# The full CPython MRO: class_mro's linearization plus the terminal object.
# class_mro stops at the last user class, but CPython's __mro__/mro() end with
# object -- appended here as the same host-object proxy the guest sees for the
# global name `object`, so display matches isinstance/issubclass semantics
# (both answer True for that proxy via obj_is_builtin).
#
# Host-type bases (__mro_entries__ replacements like `dict`, or explicit host
# base classes) participate in the linearization as opaque nodes: each expands
# to its own host MRO chain (minus the terminal object), and a shared
# PyObj-level C3 merge orders everything.
def class_full_mro(cls: PyClass) -> list[PyObj] {
    seqs: list[list[PyObj]] = [];
    direct: list[PyObj] = [];
    has_host_base = False;
    for base in cls.bases {
        if isinstance(base, PyClass) {
            # Bare linearization only -- the terminal object is appended once,
            # globally, after the merged order.
            sub: list[PyObj] = [];
            for k in class_mro(base as PyClass) {
                sub.append(k);
            }
            seqs.append(sub);
            direct.append(base);
        } elif isinstance(base, PyHostProxy)
            and _jac_host_val_is_type((base as PyHostProxy).val) {
            has_host_base = True;
            seqs.append(host_type_mro_chain(base));
            direct.append(base);
        }
        # Non-class non-host bases cannot appear post-update_build_class_bases.
    }
    if len(direct) > 0 {
        seqs.append(direct);
    }
    result: list[PyObj] = [cls];
    if has_host_base {
        for klass in c3_merge_objs(seqs) {
            result.append(klass);
        }
    } else {
        # Pure guest-class chain: reuse the established PyClass merge.
        pc_seqs: list[list[PyClass]] = [];
        for s in seqs {
            row: list[PyClass] = [];
            for x in s {
                if isinstance(x, PyClass) {
                    row.append(x as PyClass);
                }
            }
            pc_seqs.append(row);
        }
        for klass in c3_merge(pc_seqs) {
            result.append(klass);
        }
    }
    result.append(host_builtin("object"));
    return result;
}

# The MRO contribution of a host type base: the type itself plus its host
# ancestors, excluding the terminal object (appended once globally).
def host_type_mro_chain(base: PyObj) -> list[PyObj] {
    raw = (base as PyHostProxy).val;
    chain: list[PyObj] = [];
    for t in _jac_host_type_mro(raw) {
        if _jac_host_val_is_object_type(t) {
            continue;
        }
        chain.append(PyHostProxy(t="host", val=t));
    }
    return chain;
}

# Merge step of C3: repeatedly take the head of some sequence that appears in no
# other sequence's tail, append it, and strip it from every head. Stops when all
# sequences drain (success) or no valid head exists (inconsistent -> partial).
def c3_merge(seqs: list[list[PyClass]]) -> list[PyClass] {
    work: list[list[PyClass]] = [];
    for s in seqs {
        row: list[PyClass] = [];
        for x in s {
            row.append(x);
        }
        work.append(row);
    }
    result: list[PyClass] = [];
    while True {
        live: list[list[PyClass]] = [];
        for s in work {
            if len(s) > 0 {
                live.append(s);
            }
        }
        if len(live) == 0 {
            return result;
        }
        chosen: PyClass | None = None;
        for s in live {
            head = s[0];
            in_tail = False;
            for other in live {
                k = 1;
                while k < len(other) {
                    if other[k] is head {
                        in_tail = True;
                    }
                    k = k + 1;
                }
            }
            if not in_tail {
                chosen = head;
                break;
            }
        }
        if chosen is None {
            return result;
        }
        result.append(chosen);
        for s in live {
            if len(s) > 0 and s[0] is chosen {
                s.pop(0);
            }
        }
        work = live;
    }
    return result;
}

# C3 over mixed nodes (guest PyClass + host-type proxies). Same algorithm as
# c3_merge at PyObj identity; host proxies compare by underlying type via `is`
# on the raw value so repeated ancestors dedupe correctly.
def c3_merge_objs(seqs: list[list[PyObj]]) -> list[PyObj] {
    work: list[list[PyObj]] = [];
    for s in seqs {
        row: list[PyObj] = [];
        for x in s {
            row.append(x);
        }
        work.append(row);
    }
    result: list[PyObj] = [];
    while True {
        live: list[list[PyObj]] = [];
        for s in work {
            if len(s) > 0 {
                live.append(s);
            }
        }
        if len(live) == 0 {
            return result;
        }
        chosen: PyObj | None = None;
        for s in live {
            head = s[0];
            in_tail = False;
            for other in live {
                k = 1;
                while k < len(other) {
                    if _jac_mro_node_is(other[k], head) {
                        in_tail = True;
                    }
                    k = k + 1;
                }
            }
            if not in_tail {
                chosen = head;
                break;
            }
        }
        if chosen is None {
            # Inconsistent merge (host/guest cycles cannot occur): stop at the
            # longest consistent prefix, like the PyClass merge does.
            return result;
        }
        result.append(chosen);
        for s in live {
            if len(s) > 0 and _jac_mro_node_is(s[0], chosen) {
                s.pop(0);
            }
        }
        work = live;
    }
    return result;
}

def _jac_mro_node_is(a: PyObj, b: PyObj) -> bool {
    if a is b {
        return True;
    }
    if isinstance(a, PyHostProxy) and isinstance(b, PyHostProxy) {
        raw_a = (a as PyHostProxy).val;
        raw_b = (b as PyHostProxy).val;
        return _jac_host_val_same(raw_a, raw_b);
    }
    return False;
}

def class_lookup_attr(cls: PyClass, name: str) -> PyObj {
    for klass in class_mro(cls) {
        if name in klass.attrs {
            return klass.attrs[name];
        }
    }
    return py_error("AttributeError", name);
}

# ---------------- dir(): CPython attribute enumeration -----------------------

# CPython's dir(obj) for a non-module object is a sorted union of __dict__ keys
# across obj's type MRO (for instances) or the class's own MRO (for classes),
# plus the instance's own __dict__ when present. Two native gaps need filling
# to stay byte-exact with the host: the terminal `object` (and any boxed
# builtin base like int/Exception) contributes its HOST type-dict surface, and
# a dict-bearing user class's own dict carries synthesized `__dict__` /
# `__weakref__` descriptors the VM never stores in attrs.
def py_dir_add_surface(names: dict[str, bool], kind: str) -> PyObj {
    surface = _jac_host_type_surface(kind);
    if host_result_ok(surface) {
        for k in (surface[1] as list[str]) {
            names[k] = True;
        }
        return py_none();
    }
    return host_result_error(surface);
}

def py_dir_add_class(names: dict[str, bool], cls: PyClass) -> PyObj {
    # Namespace entries CPython's type.__new__ never lets reach the class dict:
    # __name__/__qualname__ are stripped at class creation (answered via slot
    # access instead), and __classdictcell__ is this VM's internal anchor for
    # method-scope class references. Emitting them would diverge from host
    # dir(cls)/dir(instance).
    skip_names: dict[str, bool] = {"__name__": True, "__qualname__": True, "__classdictcell__": True};
    for klass in class_mro(cls) {
        for k in klass.attrs.keys() {
            if k not in skip_names {
                names[k] = True;
            }
        }
        # A dict-bearing heap class owns __dict__/__weakref__ member
        # descriptors in CPython; the VM models them implicitly.
        if klass.instance_has_dict {
            names["__dict__"] = True;
            names["__weakref__"] = True;
        }
    }
    if cls.native_base != "" {
        err = py_dir_add_surface(names, cls.native_base);
        if is_error(err) {
            return err;
        }
    }
    return py_dir_add_surface(names, "object");
}

def py_dir_sorted(names: dict[str, bool]) -> PyObj {
    items: list[PyObj] = [];
    for k in names {
        items.append(PyStr(t="str", val=k));
    }
    return builtin_sorted_min_max(
        "sorted", [PyList(t="list", items=items)], {}
    );
}

# dir(arg): one argument. Order mirrors CPython builtin_dir -- a type-level
# __dir__ override wins, then modules answer from their namespace, then the
# generic MRO/__dict__ union. Host-backed values (proxies and faithful native
# scalars/containers) defer to the host interpreter so their name lists are
# byte-exact by construction.
def py_dir(arg: PyObj) -> PyObj {
    # __dir__ override lookup: on the INSTANCE's class, or on a CLASS's
    # metaclass (a body-defined __dir__ serves instances of that class, never
    # the class itself). The result is iterated exactly like CPython -- a
    # non-iterable result surfaces the iteration TypeError unchanged.
    owner: PyClass | None = None;
    if isinstance(arg, PyUserObj) {
        owner = (arg as PyUserObj).cls;
    } elif isinstance(arg, PyClass) {
        mc = (arg as PyClass).metaclass;
        if isinstance(mc, PyClass) {
            owner = mc as PyClass;
        }
    }
    if owner is not None {
        d = class_lookup_attr(owner, "__dir__");
        if not is_error(d) {
            res = bind_attribute(d, arg).tp_call([], {});
            if is_error(res) {
                return res;
            }
            items = members_of(res);
            if is_error(items) {
                return items;
            }
            return builtin_sorted_min_max("sorted", [items], {});
        }
    }
    if isinstance(arg, PyModule) {
        names: dict[str, bool] = {};
        for k in (arg as PyModule).attrs.keys() {
            names[k] = True;
        }
        return py_dir_sorted(names);
    }
    if isinstance(arg, PyHostProxy) {
        r = _jac_host_dir((arg as PyHostProxy).val);
        if host_result_ok(r) {
            strs: list[PyObj] = [];
            for n in (r[1] as list[str]) {
                strs.append(PyStr(t="str", val=n));
            }
            return PyList(t="list", items=strs);
        }
        return host_result_error(r);
    }
    # Native scalars/containers marshal faithfully across the bridge, so the
    # host's own dir() IS the correct enumeration (dir([1]) == host dir of a
    # real list). User objects/classes must NOT cross here -- to_host loses
    # them -- they fall through to the native walks below.
    tag = arg.t;
    if tag == "none" or tag == "bool" or tag == "int" or tag == "float"
        or tag == "complex" or tag == "str" or tag == "bytes" or tag == "tuple"
        or tag == "list" or tag == "dict" or tag == "set" or tag == "frozenset"
        or tag == "slice" or tag == "range" or tag == "notimplemented"
        or tag == "dictview_obj" {
        h_r = to_host_coerce(arg);
        if not ((h_r[0] as bool)) {
            return h_r[1] as PyObj;
        }
        hd = _jac_host_dir(h_r[1]);
        if host_result_ok(hd) {
            strs2: list[PyObj] = [];
            for n2 in (hd[1] as list[str]) {
                strs2.append(PyStr(t="str", val=n2));
            }
            return PyList(t="list", items=strs2);
        }
        return host_result_error(hd);
    }
    if isinstance(arg, PyException) {
        names_exc: dict[str, bool] = {};
        err_exc = py_dir_add_surface(names_exc, "BaseException");
        if is_error(err_exc) {
            return err_exc;
        }
        return py_dir_sorted(names_exc);
    }
    if isinstance(arg, PyClass) {
        names_cls: dict[str, bool] = {};
        err_cls = py_dir_add_class(names_cls, arg as PyClass);
        if is_error(err_cls) {
            return err_cls;
        }
        return py_dir_sorted(names_cls);
    }
    if isinstance(arg, PyUserObj) {
        u = arg as PyUserObj;
        names_u: dict[str, bool] = {};
        for k in u.attrs.keys() {
            names_u[k] = True;
        }
        err_u = py_dir_add_class(names_u, u.cls);
        if is_error(err_u) {
            return err_u;
        }
        return py_dir_sorted(names_u);
    }
    if isinstance(arg, PyFunction) {
        f = arg as PyFunction;
        names_f: dict[str, bool] = {};
        for k in f.attrs.keys() {
            names_f[k] = True;
        }
        err_f = py_dir_add_surface(names_f, "function");
        if is_error(err_f) {
            return err_f;
        }
        return py_dir_sorted(names_f);
    }
    # Unknown native shape: only the shared object surface is knowable.
    names_obj: dict[str, bool] = {};
    err_obj = py_dir_add_surface(names_obj, "object");
    if is_error(err_obj) {
        return err_obj;
    }
    return py_dir_sorted(names_obj);
}

# super().name lookup: search the instance's MRO starting AFTER the defining
# class (zero-arg super semantics). defining_cls comes from the __class__ cell;
# if it isn't a PyClass, fall back to the instance's own class.
# `builtin.__new__(cls, *box_args)` reached through super() from a subclass's
# own __new__ (e.g. re._constants._NamedIntConstant, IntEnum members). The first
# arg is the class to instantiate; the rest box the builtin base. Returns a
# PyUserObj tagged with that class so the subclass's identity and attributes
# (a .name set right after) survive -- exactly the value/ref line Track B draws.
# super().__init__/__str__/__repr__ inside a user exception subclass's method.
# Exception is not a boxed-layout native base (native_base stays ""), so there
# is no boxed value to delegate to -- these run BaseException's own slot
# semantics directly over the live instance, exactly like CPython's inherited
# BaseException slots.
obj PyExcSuperSlot(PyObj) {
    has target: PyObj,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        u = self.target as PyUserObj;
        if self.name == "__init__" {
            # CPython BaseException_init: replaces args wholesale.
            if len(kwargs) > 0 {
                return py_error(
                    "TypeError", "__init__() takes no keyword arguments"
                );
            }
            stored: list[PyObj] = [];
            stored.extend(args);
            u.attrs["args"] = PyTuple(t="tuple", items=stored);
            return py_none();
        }
        view = user_exception_view(u);
        if self.name == "__str__" {
            return baseexception_str(view, py_repr, py_str);
        }
        if self.name == "__repr__" {
            return baseexception_repr(view, py_repr);
        }
        return py_error("AttributeError", self.name);
    }
}

obj PyNativeNew(PyObj) {
    has base_name: str;

    # Value identity by base_name so every object.__new__ producer compares equal
    # (enum's _find_new_ does `target in {object.__new__, ...}`).
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="nativenew:" + self.base_name);
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
            return host_result_error(hres);
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

# super().<name> delegation when no python ancestor defines <name>: inside a
# builtin-subclass method (dict/list/... subclass) the boxed base's own slots
# answer -- e.g. _EnumDict(dict).__setitem__ calling super().__setitem__(k, v)
# mutates the underlying dict -- and a BASE-LESS class falls through to the
# object surface (object.__repr__/__str__/__init__). Bound to the instance at
# lookup time, so the call site applies only the operands.
obj PyBuiltinSuperMethod(PyObj) {
    # The boxed base value, or the PyNoneType sentinel for a base-less class.
    has base: PyObj,
        name: str,
        # The subclass instance this super() binding came from. __getitem__ on
        # a boxed dict base must consult the OWNER's type-level __missing__ on
        # a miss (CPython dict.__getitem__ does), which needs the instance's
        # class -- not just the boxed storage; the base-less object surface
        # builds object.__repr__ from it.
        owner: PyObj = py_none();

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        n = self.name;
        b = self.base;
        boxed = not isinstance(b, PyNoneType);
        if not boxed {
            # object-surface fallback (MRO exhausted above a base-less class).
            if n == "__repr__" {
                return PyStr(t="str", val=default_obj_repr_text(self.owner as PyUserObj));
            }
            if n == "__str__" {
                # object.__str__ IS object.__repr__ (the identity form).
                return PyStr(t="str", val=default_obj_repr_text(self.owner as PyUserObj));
            }
            if n == "__init__" {
                if len(args) == 0 {
                    return py_none();
                }
                return py_error(
                    "TypeError",
                    "object.__init__() takes exactly one argument (the instance to initialize)"
                );
            }
            return py_error(
                "AttributeError", "'super' object has no attribute '" + n + "'"
            );
        }
        if n == "__init__" {
            # super().__init__(...) on a boxed builtin base runs the base's OWN
            # initializer over the live boxed storage -- in CPython terms the
            # MRO-resolved __init__ IS set_init/list_init/dict_init. Immutable
            # bases have no initializer of their own (tuple/frozenset/str/int
            # inherit object.__init__), so their args are ignored. The box is
            # mutated IN PLACE -- never marshaled through to_host (a copy would
            # silently no-op for mutators).
            if len(args) == 0 {
                return py_none();
            }
            if isinstance(b, PyList) {
                lst = b as PyList;
                if len(kwargs) > 0 {
                    return py_error(
                        "TypeError", "list() takes no keyword arguments"
                    );
                }
                if len(args) > 1 {
                    return py_error(
                        "TypeError", "list() takes at most one argument"
                    );
                }
                lst.items = [];
                return PyListMethod(
                    t="list_method", target=lst, name="extend"
                ).tp_call([args[0]], {});
            }
            if isinstance(b, PySet) {
                s = b as PySet;
                if len(kwargs) > 0 {
                    return py_error(
                        "TypeError", "set() takes no keyword arguments"
                    );
                }
                if len(args) > 1 {
                    return py_error(
                        "TypeError", "set() takes at most one argument"
                    );
                }
                s.set_clear();
                return PySetMethod(
                    t="set_method", target=s, name="update"
                ).tp_call(args, {});
            }
            if isinstance(b, PyDict) {
                return PyDictMethod(
                    t="dict_method", target=(b as PyDict), name="update"
                ).tp_call(args, kwargs);
            }
            return py_none();
        }
        if n == "__setitem__" {
            # Route through the public dispatch (not the raw slot) so slice
            # assignment shares the iterable-value normalization above.
            return py_store_subscript(b, args[0], args[1]);
        }
        if n == "__getitem__" {
            if isinstance(b, PyDict) and isinstance(self.owner, PyUserObj)
                and not user_has_dunder(self.owner as PyUserObj, "__getitem__") {
                return dict_subscript_missing(
                    self.owner as PyUserObj, b as PyDict, args[0]
                );
            }
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
        if n == "__repr__" {
            # The base type's own repr of the live boxed storage.
            return py_repr(b);
        }
        if n == "__str__" {
            return py_str(b);
        }
        # Everything else resolves onto the boxed base through the standard
        # attribute surface -- the same per-type dispatch (dict/list/set/str
        # methods, live view constructors, host fallback for unported names)
        # any base value presents outside super(). No name table here.
        res = py_attr(b, n);
        if is_error(res) {
            return res;
        }
        return res.tp_call(args, kwargs);
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
        if past {
            # CPython type.__init__ after creation is arg validation + no-op;
            # guest classes are already built when a metaclass __init__ chains
            # super().__init__. The native `type` surface carries no attrs, so
            # serve the no-op arm here instead of falling through to
            # AttributeError (Lib/typing.py _ProtocolMeta.__init__ depends on
            # this exact chain).
            if name == "__init__" and klass.native_base == "type" {
                return PyNoOpInit(t="noop_init");
            }
            if name in klass.attrs {
                return klass.attrs[name];
            }
        }
        if klass is start {
            past = True;
        }
    }
        # A CLASS receiver means we are inside a metaclass body chaining
        # super().__init__ during creation: class_mro nodes end at the newest
        # guest class (implicit object/type roots are not class_mro nodes), so
        # the walk found nothing. CPython's terminal there is type.__init__ --
        # arg-validation + no-op over the already-built class.
        if name == "__init__" and isinstance(instance, PyClass) {
            return PyNoOpInit(t="noop_init");
        }
    # No python ancestor defines it. A super().<dunder>() on a boxed-builtin
    # subclass (dict/list/... subclass calling super().__setitem__ etc.) delegates
    # to the base value's own slot.
    if name != "__new__" and isinstance(instance, PyUserObj) {
        inst = instance as PyUserObj;
        # object.__getattribute__/__setattr__/__delattr__ close every MRO: a
        # super().<attr-protocol>() delegation resolves to the DEFAULT protocol
        # -- never a re-dispatch through the override that called super(). This
        # is the recursion guard inside user __setattr__/__delattr__/
        # __getattribute__ implementations.
        if name == "__getattribute__" or name == "__setattr__"
            or name == "__delattr__" {
            return PyObjectAttrSlot(t="obj_attr_slot", target=inst as PyObj, op=name);
        }
        if inst._has_base() {
            return PyBuiltinSuperMethod(
                t="builtin_super",
                base=inst._base_obj(),
                name=name,
                owner=instance
            );
        }
        # Exception-derived user classes have no boxed builtin layout: the
        # BaseException surface answers instead. CPython gives them
        # BaseException.__init__/__str__/__repr__ via slot inheritance -- serve
        # those over the live instance.
        if class_is_exception(inst.cls) {
            if name == "args" {
                stored = inst.attrs.get("args");
                if isinstance(stored, PyTuple) {
                    return stored;
                }
                return PyTuple(t="tuple", items=[]);
            }
            if name == "__init__" or name == "__str__" or name == "__repr__" {
                return PyExcSuperSlot(
                    t="exc_super_slot", target=inst as PyObj, name=name
                );
            }
        }
        # Base-less class: the walk exhausted every python ancestor including
        # the implicit object root, so the object surface answers.
        return PyBuiltinSuperMethod(
            t="builtin_super", base=py_none(), name=name, owner=instance
        );
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
    return py_error(
        "AttributeError", "'super' object has no attribute '" + name + "'"
    );
}

# Box a builtin subclass instance by running the builtin constructor over the
# call args (int("5") -> 5, list(x) -> [...]). Errors propagate.
def construct_native_base(name: str, args: list[PyObj]) -> PyObj {
    raw_args: list[any] = [];
    for a in args {
        ha_r = to_host_coerce(a);
        ha = ha_r[1];
        if not ((ha_r[0] as bool)) {
            return ha_r[1] as PyObj;
        }
        raw_args.append(ha);
    }
    result = _jac_construct_builtin(name, raw_args);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return host_result_error(result);
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
    # Shim type-marker fast path: one t compare on miss, exact tag match on
    # hit (ratified exception/tb-surface scope; generic across future shims).
    if typ.t == "shim_type_marker" {
        return ob.t == ((typ as ShimTypeMarker).tag);
    }
    if isinstance(ob, PyException) {
        if typ.t == "exception_type" {
            return exc_name_matches(
                (ob as PyException).type_name, (typ as PyExceptionType).name
            );
        }
        if isinstance(typ, PyHostProxy) {
            host_type = (typ as PyHostProxy).val;
            if bool(_jac_is_exception_type(host_type)) {
                tname = _jac_host_class_name(host_type) as str;
                return exc_name_matches((ob as PyException).type_name, tname);
            }
        }
        if isinstance(typ, PyClass) {
            return exc_name_matches(
                (ob as PyException).type_name, (typ as PyClass).name
            );
        }
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
        hob_r = to_host_coerce(ob);
        hob = hob_r[1];
        if not ((hob_r[0] as bool)) {
            return False;
        }
        return bool(_jac_host_isinstance(hob, host_type));
    }
    # A host-proxied exception INSTANCE tested against a native exception-type
    # marker: match through the shared name hierarchy (mirrors the proxy-target
    # branch above).
    if isinstance(ob, PyHostProxy) and typ.t == "exception_type" {
        inst = _jac_host_exception_instance((ob as PyHostProxy).val);
        if bool(inst[0]) {
            return exc_name_matches(str(inst[1]), (typ as PyExceptionType).name);
        }
        return False;
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
            # A host-proxied NON-builtin type (e.g. typing.Generic from the C
            # _typing accelerator) still participates: ask the host whether any
            # standin of the guest MRO subclasses it, before the builtin-name
            # fallback answers False.
            hv_r = _jac_hostproxy_val_is_type((typ as PyHostProxy).val);
            if hv_r != "" {
                covered = _jac_standin_mro_covers(c, hv_r);
                if covered {
                    return True;
                }
            }
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
        return bool(
            _jac_host_issubclass((cls as PyHostProxy).val, (typ as PyHostProxy).val)
        );
    }
    # Builtin exception types exist in two shapes -- native PyExceptionType
    # markers and host-proxied classes -- and subclass tests must cross the
    # split. Match by name through the shared EXC_PARENT hierarchy.
    cls_name: str = "";
    typ_name: str = "";
    if cls.t == "exception_type" {
        cls_name = (cls as PyExceptionType).name;
    } elif isinstance(cls, PyHostProxy)
        and bool(_jac_is_exception_type((cls as PyHostProxy).val)) {
        cls_name = _jac_host_class_name((cls as PyHostProxy).val) as str;
    }
    if typ.t == "exception_type" {
        typ_name = (typ as PyExceptionType).name;
    } elif isinstance(typ, PyHostProxy)
        and bool(_jac_is_exception_type((typ as PyHostProxy).val)) {
        typ_name = _jac_host_class_name((typ as PyHostProxy).val) as str;
    }
    if cls_name != "" and typ_name != "" {
        return exc_name_matches(cls_name, typ_name);
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
# __slots__ finalization for a freshly built class (CPython type_new_set_attrs
# + the dict/weakref inheritance rules in type_ready setdict). Returns either a
# PyError (conflict / malformed declaration -- class creation fails) or a
# PyTuple of [merged member names, declared?, instance-has-dict?].
#
# Host-exact behaviors pinned against CPython 3.14:
# - string form: __slots__ = "q" declares exactly one slot q;
# - non-iterable: TypeError "'int' object is not iterable";
# - non-string item: TypeError "__slots__ items must be strings, not 'int'";
# - slot vs class variable: ValueError "'v' in __slots__ conflicts with class
#   variable" (checked AFTER mangling, like the host);
# - private names mangle (`__p` -> `_M__p`) and install under the mangled key;
# - duplicate names are allowed (deduped); `__dict__`/`__weakref__` are layout
#   flags, not members;
# - instance dict survives only if listed or inherited from a base (a builtin
#   boxed base does NOT grant one once __slots__ is declared);
# - two bases each declaring non-empty members raise the host layout conflict.
def compute_class_slots(
    class_name: str, bases: list[PyObj], namespace: dict[str, PyObj]
) -> PyObj {
    if "__slots__" not in namespace {
        # No own declaration: the class keeps a permissive dict, but the
        # EFFECTIVE layout still carries every inherited slot member -- the
        # dict VIEW must keep hiding their storage (host: B(A) with A slotted
        # answers b.__dict__ == {'zz': 1} after b.zz = 1; b.a = 2, even though
        # both live on the same attribute map).
        return PyTuple(
            t="tuple",
            items=[
                PyList(
                    t="list",
                    items=[
                        PyStr(t="str", val=m)
                        for m in _inherited_slot_members(bases)
                    ],
                ),
                PyBool(t="bool", val=False),
                PyBool(t="bool", val=True),
            ],
        );
    }
    slots_obj = namespace["__slots__"];
    raw: list[str] = [];
    if isinstance(slots_obj, PyStr) {
        raw.append((slots_obj as PyStr).val);
    } elif isinstance(slots_obj, PyTuple) or isinstance(slots_obj, PyList) {
        items = (slots_obj as PyTuple).items
            if isinstance(slots_obj, PyTuple)
            else (slots_obj as PyList).items;
        for item in items {
            if not isinstance(item, PyStr) {
                return py_error(
                    "TypeError",
                    "__slots__ items must be strings, not '"
                        + _slot_item_type_name(item) + "'",
                );
            }
            raw.append((item as PyStr).val);
        }
    } else {
        return py_error(
            "TypeError",
            "'" + _slot_item_type_name(slots_obj) + "' object is not iterable",
        );
    }
    wants_dict = False;
    local: list[str] = [];
    seen: dict[str, bool] = {};
    for name in raw {
        if name == "__dict__" {
            wants_dict = True;
            continue;
        }
        if name == "__weakref__" {
            continue;
        }
        mangled = type_slots_mangle(name, class_name);
        # The conflict check runs on the MANGLED form: a slot named `__v` in a
        # body that also binds `_C__v` collides exactly as the host's does.
        if mangled in namespace {
            return py_error(
                "ValueError",
                "'" + mangled + "' in __slots__ conflicts with class variable",
            );
        }
        if mangled in seen {
            continue;
        }
        seen[mangled] = True;
        local.append(mangled);
    }
    # Merge inherited members and OR the base dict flags across all bases.
    inherited = _inherited_slot_members(bases);
    base_has_dict = False;
    nonempty_layout_bases = 0;
    for b in bases {
        if not isinstance(b, PyClass) {
            continue;
        }
        bc = b as PyClass;
        if bc.instance_has_dict {
            base_has_dict = True;
        }
        if len(bc.slot_members) > 0 {
            nonempty_layout_bases = nonempty_layout_bases + 1;
        }
    }
    if nonempty_layout_bases > 1 {
        return py_error(
            "TypeError", "multiple bases have instance lay-out conflict"
        );
    }
    merged = type_slots_merge_names(local, inherited);
    has_dict = type_slots_has_dict(True, wants_dict, base_has_dict);
    return PyTuple(
        t="tuple",
        items=[
            PyList(t="list", items=[PyStr(t="str", val=m) for m in merged]),
            PyBool(t="bool", val=True),
            PyBool(t="bool", val=has_dict),
        ],
    );
}

# Union of all PyClass bases' slot members, in MRO-ish declaration order
# (deduped): the inherited half of a subclass's effective slot layout.
def _inherited_slot_members(bases: list[PyObj]) -> list[str] {
    inherited: list[str] = [];
    for b in bases {
        if isinstance(b, PyClass) {
            inherited = type_slots_merge_names(
                [], inherited + (b as PyClass).slot_members
            );
        }
    }
    return inherited;
}

def _slot_item_type_name(v: PyObj) -> str {
    if isinstance(v, PyInt) {
        return "int";
    }
    if isinstance(v, PyFloat) {
        return "float";
    }
    if isinstance(v, PyNoneType) {
        return "NoneType";
    }
    return v.t;
}

def make_pyclass_from_map(
    class_name: str, bases: list[PyObj], namespace: dict[str, PyObj], meta: any
) -> PyObj {
    # CPython type_new_staticmethod (Objects/typeobject.c): a plain-function
    # __new__ in the namespace is stored as a STATICMETHOD so it never
    # instance-binds -- super().__new__(mcls, ...) must reach it unbound (the
    # receiver arrives as the explicit mcls argument). Without this, metaclass
    # chains double-bind through descriptor_get and die with 'too many
    # positional arguments' (Lib/typing.py _ProtocolMeta.__new__).
    if "__new__" in namespace and isinstance(namespace["__new__"], PyFunction) {
        namespace["__new__"] = PyStaticMethod(
            t="staticmethod", func=namespace["__new__"]
        );
    }
    flags = type_ready(0);
    if flags < 0 {
        flags = Py_TPFLAGS_READY;
    }
    slots_state = compute_class_slots(class_name, bases, namespace);
    if is_error(slots_state) {
        return slots_state;
    }
    state = (slots_state as PyTuple).items;
    members: list[str] = [];
    for mo in (state[0] as PyList).items {
        members.append((mo as PyStr).val);
    }
    declared = (state[1] as PyBool).val;
    has_dict = (state[2] as PyBool).val;
    cls = PyClass(
        t="class",
        name=class_name,
        attrs=namespace,
        bases=bases,
        native_base=compute_native_base(bases),
        metaclass=meta,
        tp_flags=flags,
        slot_members=members,
        slots_declared=declared,
        instance_has_dict=has_dict
    );
    # Install one member descriptor per OWN declared slot (inherited slots
    # already carry their defining class's descriptor and resolve via the MRO).
    # A body binding of the same name raised ValueError above, so nothing here
    # shadows an explicit namespace entry.
    inherited_set: dict[str, bool] = {};
    for b in bases {
        if isinstance(b, PyClass) {
            for im in (b as PyClass).slot_members {
                inherited_set[im] = True;
            }
        }
    }
    for m in members {
        if m not in namespace and m not in inherited_set {
            cls.attrs[m] = PyMemberDescr(t="member_descr", member=m, owner=class_name);
        }
    }
    return cls;
}

# type.__new__(mcls, name, bases, namespace): build a class object. Serves both
# the metaclass super().__new__ path and a bare 3-arg type(name, bases, ns) call.
# Shared 3-arg type(name, bases, ns) base validation: a non-class base that
# defines __mro_entries__ gets CPython's escape-hatch message; any other
# non-class base is rejected outright. Returns None when bases are acceptable.
def _jac_validate_type_bases(bases: list[PyObj]) -> PyObj | None {
    for tb in bases {
        if isinstance(tb, PyClass) {
            continue;
        }
        if isinstance(tb, PyHostProxy) and _jac_host_val_is_type((tb as PyHostProxy).val) {
            continue;
        }
        hook = py_attr(tb, "__mro_entries__");
        if not is_error(hook) {
            return py_error(
                "TypeError",
                "type() doesn't support MRO entry resolution; use types.new_class()"
            );
        }
        return py_error("TypeError", "all bases must be classes");
    }
    return None;
}

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
    # CPython type_new_impl: a bare 3-arg type() never resolves __mro_entries__.
    rejected = _jac_validate_type_bases(bases);
    if rejected is not None {
        return rejected;
    }
    made_cls = make_pyclass_from_map(class_name, bases, namespace, mcls);
    if is_error(made_cls) {
        return made_cls;
    }
    cls = made_cls as PyClass;
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
                    value as PyUserObj, "__set_name__", [cls, PyStr(t="str", val=name)]
                );
                if is_error(res) {
                    return res;
                }
            }
        }
    }
    return cls;
}

# PEP 487: after a subclass is built, its nearest base's __init_subclass__ is
# called with the new class (implicit classmethod) plus the class keyword args --
# `class Sub(Base, key=1)` runs Base.__init_subclass__(cls=Sub, key=1). Only a
# user base that actually defines it fires (the object default is a no-op); a
# base that stores it as a plain def takes the new class as its first argument.
def apply_init_subclass(cls: PyClass, kwds: dict[str, PyObj]) -> PyObj {
    for base in cls.bases {
        if isinstance(base, PyClass) {
            found = class_lookup_attr(base as PyClass, "__init_subclass__");
            if not is_error(found) and isinstance(found, PyFunction) {
                res = py_invoke(found, [cls], kwds);
                if is_error(res) {
                    return res;
                }
                return cls;
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

# Port of CPython bltinmodule.c update_bases: non-class bases may replace
# themselves through __mro_entries__ (typing.Generic[T], the implicit PEP 695
# class base, resolves to Generic this way) before the metaclass is derived
# from the bases. Each hook receives the ORIGINAL bases tuple and must return
# one; real classes (guest PyClass, host type proxies) never get looked up,
# matching the PyType_Check short-circuit in the host. Appends the resolved
# bases to `out`; returns a PyError when the protocol fails.
def update_build_class_bases(bases: list[PyObj], out: list[PyObj]) -> PyObj {
    new_bases: list[PyObj] = [];
    ub_j = 0;
    while ub_j < len(bases) {
        base = bases[ub_j];
        if isinstance(base, PyClass)
            or (isinstance(base, PyHostProxy)
                and _jac_host_val_is_type((base as PyHostProxy).val)) {
            new_bases.append(base);
            ub_j = ub_j + 1;
            continue;
        }
        entries = py_attr(base, "__mro_entries__");
        if is_error(entries) {
            if ((entries as PyError).exception.type_name != "AttributeError") {
                return entries;
            }
            new_bases.append(base);
            ub_j = ub_j + 1;
            continue;
        }
        repl = py_invoke(entries, [PyTuple(t="tuple", items=bases)], {});
        if is_error(repl) {
            return repl;
        }
        if not isinstance(repl, PyTuple) {
            return py_error("TypeError", "__mro_entries__ must return a tuple");
        }
        for rb in (repl as PyTuple).items {
            new_bases.append(rb);
        }
        ub_j = ub_j + 1;
    }
    for nb in new_bases {
        out.append(nb);
    }
    return py_none();
}

# True when the two base lists hold identical objects pairwise (CPython's
# `bases != orig_bases` identity check after update_bases).
def bases_are_same(a: list[PyObj], b: list[PyObj]) -> bool {
    if len(a) != len(b) {
        return False;
    }
    i = 0;
    while i < len(a) {
        if a[i] is not b[i] {
            return False;
        }
        i = i + 1;
    }
    return True;
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
    # CPython resolves __mro_entries__ replacements BEFORE deriving the
    # metaclass from the bases -- see update_build_class_bases.
    orig_base_list: list[PyObj] = [];
    for ob in bases {
        orig_base_list.append(ob);
    }
    resolved_base_list: list[PyObj] = [];
    ub_err = update_build_class_bases(bases, resolved_base_list);
    if is_error(ub_err) {
        return ub_err;
    }
    bases_changed = not bases_are_same(bases, resolved_base_list);
    bases = resolved_base_list;
    metaclass = resolve_metaclass(kwargs, bases);
    # A user metaclass (EnumType, ABCMeta): run the full protocol -- __prepare__
    # for the body namespace, then call the metaclass as the class factory.
    if isinstance(metaclass, PyClass) {
        return build_class_via_metaclass(
            metaclass as PyClass, class_name, bases, body, class_kwds,
            orig_base_list, bases_changed
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
    # CPython type.__new__ pops __classcell__ from the mapping so it never
    # becomes a class attribute; py_build_class seeds the returned cell itself.
    if "__classcell__" in namespace {
        del namespace["__classcell__"];
    }
    # CPython bltinmodule.c: when update_bases replaced any base, the original
    # bases land in the namespace as __orig_bases__ AFTER the body ran.
    if bases_changed {
        namespace["__orig_bases__"] = PyTuple(t="tuple", items=orig_base_list);
    }
    built_cls = make_pyclass_from_map(class_name, bases, namespace, None);
    if is_error(built_cls) {
        return built_cls;
    }
    cls = built_cls as PyClass;
    # CPython bltinmodule.c __build_class__: when the body declares a __class__
    # cellvar, the finished class object is written into that live cell (the
    # epilogue returned it) so methods' captured closures deref it for
    # zero-arg super().
    if isinstance(body_result, PyCell) {
        cc = body_result as PyCell;
        cc.val = cls;
        cc.filled = True;
    }
    ordered: list[str] = [];
    for k in namespace {
        ordered.append(k);
    }
    hooked = apply_set_name_hooks(cls, ordered);
    if is_error(hooked) {
        return hooked;
    }
    return apply_init_subclass(cls, class_kwds);
}

# The custom-metaclass class-creation protocol: metaclass.__prepare__ produces the
# body namespace, the body runs into it, then the metaclass is called as
# (name, bases, namespace, **kwds) -- its __new__/__init__ build and finish the
# class. Only a plain-dict namespace is supported; a custom mapping (enum's
# _EnumDict) as a live body namespace is a later refinement.
def build_class_via_metaclass(
    metaclass: PyClass,
    class_name: str,
    bases: list[PyObj],
    body: PyFunction,
    class_kwds: dict[str, PyObj],
    orig_bases: list[PyObj],
    bases_changed: bool
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
        # CPython __build_class__ stores the ORIGINAL bases in the classdict
        # (after the body ran) whenever update_bases replaced any -- visible to
        # the metaclass call and later as cls.__orig_bases__.
        if bases_changed {
            res_ob = call_user_dunder(
                mapping, "__setitem__",
                [PyStr(t="str", val="__orig_bases__"),
                    PyTuple(t="tuple", items=orig_bases)]
            );
            if is_error(res_ob) {
                return res_ob;
            }
        }
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
            PyStr(t="str", val=class_name),
            bases_tuple,
            prepared
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
    if bases_changed {
        namespace2["__orig_bases__"] = PyTuple(t="tuple", items=orig_bases);
    }
    body_result2 = exec_code_frame(
        body.code, [], {}, body.globals, namespace2, body.closure, [], {}
    );
    if body_result2.t == "error" {
        return body_result2;
    }
    if "__classcell__" in namespace2 {
        del namespace2["__classcell__"];
    }
    ns_dict = dict_from_str_map(namespace2);
    call_args2: list[PyObj] = [PyStr(t="str", val=class_name), bases_tuple, ns_dict];
    made = py_invoke(metaclass, call_args2, class_kwds);
    if not is_error(made) and isinstance(body_result2, PyCell) {
        # Same __classcell__ seeding as the default-type path: the metaclass's
        # returned class object goes into the body's live cell.
        cc2 = body_result2 as PyCell;
        cc2.val = made;
        cc2.filled = True;
    }
    return made;
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
# PyFrame captures the resumable eval state (stack/fast/ip). YIELD_VALUE
# saves it and hands a PyYield up to run_frame's caller; PyGenerator drives the
# frame forward one yield at a time. PyGenStop is the "frame returned normally"
# (StopIteration) sentinel that distinguishes exhaustion from a real raise.
obj PyFrame(PyObj) {
    has co: PyCode,
        # Merged localsplus: [varnames] [non-arg cellvar cells] [freevar cells].
        # Entries hold values or PyCell objects (see resolve_cell); OP_MAKE_CELL
        # converts more slots dynamically mid-frame.
        fast: list[PyObj],
        assigned: list[bool],
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
        cleared: bool = False,
        # Exception-handler stack captured at a YIELD_VALUE suspension and
        # restored when the generator resumes, so a bare `raise` inside an
        # except block that spans a yield re-raises the right exception
        # (CPython keeps this state in the frame's exc_info across suspends).
        exc_state: list[PyObj] | None = None;
}

obj PyYield(PyObj) {
    has val: PyObj;
}

# next()/iter() as native callables (host_builtin routes these here) so they
# drive a native generator/iterator in-VM rather than draining it to a host list.
# Native shim "type" marker (isinstance-matchable shim classes): wraps a
# constructor callable and carries the PyObj.t tag its instances carry.
# py_isinstance answers marker matches with a single value.t comparison --
# no getattr probes, no host bridge. Registered by module shims that expose
# real class-shaped surfaces (traceback.FrameSummary, TracebackException).
obj ShimTypeMarker(PyObj) {
    has tag: str,
        ctor: PyObj;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return (self.ctor as PyObj).tp_call(args, kwargs);
    }

    def tp_getattro(name2: str) -> PyObj {
        if name2 == "__jac_shim_tag__" {
            return PyStr(t="str", val=self.tag);
        }
        return (self.ctor as PyObj).tp_getattro(name2);
    }
}

obj PyNativeBuiltin(PyObj) {
    has name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {

        if self.name == "exc_info" {
            # sys.exc_info() over GUEST handled-exception state (host sys cannot
            # see guest frames). Returns (type, value, traceback); empty stack
            # yields CPython's (None, None, None).
            if len(_handled_exc_stack) == 0 {
                none3: list[PyObj] = [py_none(), py_none(), py_none()];
                return PyTuple(t="tuple", items=none3);
            }
            e = _handled_exc_stack[len(_handled_exc_stack) - 1];
            tbv = e.tp_getattro("__traceback__");
            if is_error(tbv) or isinstance(tbv, PyNoneType) {
                tbv = py_none();
            }
            # CANONICAL type identity: CPython guarantees sys.exc_info()[0] is
            # THE exception class object (exc_info()[0] is ValueError). Two
            # shapes carry it: user exceptions keep their defining PyClass in
            # raw; everything else resolves through the memoized builtin
            # registry so repeated calls return the SAME marker. py_type_of
            # would instead mint a fresh host-type proxy per call -- right
            # __name__, wrong identity.
            etype: PyObj;
            if e.raw is not None and isinstance(e.raw, PyUserObj) {
                etype = (e.raw as PyUserObj).cls as PyObj;
            } else {
                etype = host_builtin(e.type_name);
                if is_error(etype) {
                    etype = py_type_of(e);
                }
            }
            vals: list[PyObj] = [etype, e, tbv];
            return PyTuple(t="tuple", items=vals);
        }
        if self.name == "anext" {
            # anext(aiter[, default]): must stay NATIVE -- routed through the
            # host, a guest async generator crosses to its stand-in face and
            # the yielded item is lost (silently-None / not-an-async-
            # iterator). Returns the __anext__ awaitable; the caller's AWAIT
            # drives it. Divergence: with default=, CPython converts the
            # terminal StopIteration into the default -- that conversion needs
            # coroutine wrapping and is documented as absent for now.
            if len(args) < 1 or len(args) > 2 {
                return py_error(
                    "TypeError", "anext expected at least 1 argument, got " + str(len(args))
                );
            }
            result = py_anext(args[0]);
            if is_error(result) {
                if len(args) == 2 and exc_name_matches(
                    (result as PyError).exception.type_name, "StopAsyncIteration"
                ) {
                    return args[1];
                }
                return result;
            }
            return result;
        }
        if self.name == "aiter" {
            if len(args) != 1 {
                return py_error("TypeError", "aiter expected exactly 1 argument");
            }
            return py_aiter(args[0]);
        }
        if self.name == "exception" {
            # sys.exception() over GUEST handled-exception state: the most
            # recently caught exception, or None with no active handler. Must
            # agree with the exc_info branch above (same _handled_exc_stack).
            if len(_handled_exc_stack) == 0 {
                return py_none();
            }
            return _handled_exc_stack[len(_handled_exc_stack) - 1];
        }
        if self.name == "intern" {
            # sys.intern() must return its argument ITSELF (CPython identity
            # contract). The host bridge would round-trip a guest PyStr into a
            # fresh host string, breaking `intern(s) is s`; keep it in-VM.
            if len(args) != 1 {
                return py_error(
                    "TypeError",
                    "intern expected 1 argument, got " + str(len(args))
                );
            }
            if not isinstance(args[0], PyStr) {
                return py_error(
                    "TypeError", "intern() argument must be str, not " + args[0].tp_type_name()
                );
            }
            return args[0];
        }
        if self.name == "tb_format_exc" {
            e = current_handled_exc();
            if isinstance(e, PyNoneType) {
                return PyStr(t="str", val="NoneType: None\n");
            }
            return format_exception_text(e);
        }
        if self.name == "tb_print_exc" or self.name == "tb_print_exc_legacy" {
            # print_exc()/print_exception(): full-chain text to stderr or a
            # guest file-like. print_exc with no positional args reads the
            # CURRENTLY HANDLED exception; legacy form takes (etype, value, tb)
            # and renders value.
            target = py_none();
            for wkey in kwargs {
                if wkey == "file" {
                    target = kwargs[wkey];
                } else {
                    return py_error("TypeError", "unsupported keyword argument: " + wkey);
                }
            }
            no_pos = len(args) == 0;
            if self.name == "tb_print_exc" and len(args) > 0 and isinstance(args[0], PyNoneType) {
                no_pos = True;
            }
            if no_pos {
                e = current_handled_exc();
                if isinstance(e, PyNoneType) {
                    return py_error("RuntimeError", "No active exception to re-raise");
                }
                text = format_exception_text(e);
            }
            elif self.name == "tb_print_exc_legacy" and len(args) >= 2 {
                text = format_exception_text(args[1]);
            }
            else {
                text = format_exception_text(args[0]);
            }
            w = py_attr(target, "write");
            if is_error(w) {
                return w;
            }
            return py_invoke(w, [text], {});
        }
        if self.name == "sorted" or self.name == "max" or self.name == "min" {
            return builtin_sorted_min_max(self.name, args, kwargs);
        }
        if self.name == "super" {
            # Zero-arg super() at a GENERIC call site: the compiler lowers every
            # super().attr / super().m() inside a method with a __class__ cell
            # to LOAD_SUPER_ATTR, so a plain super() call here is exactly
            # CPython's frame-without-cell case (class body, module level,
            # function without the closure) -- same RuntimeError.
            if len(args) == 0 and len(kwargs) == 0 {
                return py_error("RuntimeError", "super(): no arguments");
            }
        }
        if self.name == "id" {
            if len(kwargs) > 0 {
                return py_error("TypeError", "id() takes no keyword arguments");
            }
            if len(args) != 1 {
                return py_error(
                    "TypeError", "id() takes exactly one argument (" + str(len(args)) + " given)"
                );
            }
            return PyInt(t="int", val=py_id(args[0]));
        }
        if self.name == "len" {
            if len(args) != 1 {
                return py_error(
                    "TypeError", "len() takes exactly one argument (" + str(len(args)) + " given)"
                );
            }
            return py_len(args[0]);
        }
        if self.name == "hash" {
            if len(args) != 1 {
                return py_error(
                    "TypeError", "hash() takes exactly one argument (" + str(len(args)) + " given)"
                );
            }
            return py_hash(args[0]);
        }
        if self.name == "repr" {
            if len(args) != 1 {
                return py_error(
                    "TypeError", "repr() takes exactly one argument (" + str(len(args)) + " given)"
                );
            }
            return py_repr(args[0]);
        }
        if self.name == "isinstance" {
            if len(args) != 2 {
                return py_error(
                    "TypeError",
                    "isinstance expected 2 arguments, got " + str(len(args)),
                );
            }
            return PyBool(t="bool", val=py_isinstance(args[0], args[1]));
        }
        if self.name == "issubclass" {
            if len(args) != 2 {
                return py_error(
                    "TypeError",
                    "issubclass expected 2 arguments, got " + str(len(args)),
                );
            }
            return PyBool(t="bool", val=py_issubclass(args[0], args[1]));
        }
        if self.name == "callable" {
            if len(args) != 1 {
                return py_error(
                    "TypeError",
                    "callable() takes exactly one argument (" + str(len(args)) + " given)",
                );
            }
            return PyBool(t="bool", val=obj_is_callable(args[0]));
        }
        if self.name == "getattr" {
            # getattr(obj, name[, default]): native attribute access, honoring a
            # 3rd-arg default on AttributeError (CPython only swallows that one).
            if len(args) < 2 {
                return py_error(
                    "TypeError",
                    "getattr expected at least 2 arguments, got " + str(len(args)),
                );
            }
            attr = py_attr(args[0], expect_str(args[1]));
            if is_error(attr)
                and len(args) >= 3
                and (attr as PyError).exception.type_name == "AttributeError" {
                return args[2];
            }
            return attr;
        }
        if self.name == "hasattr" {
            if len(args) != 2 {
                return py_error(
                    "TypeError",
                    "hasattr expected 2 arguments, got " + str(len(args)),
                );
            }
            probe = py_attr(args[0], expect_str(args[1]));
            return PyBool(t="bool", val=not is_error(probe));
        }
        if self.name == "setattr" {
            if len(args) != 3 {
                return py_error("TypeError", "setattr expected 3 arguments, got " + str(len(args)));
            }
            return py_set_attr(args[0], expect_str(args[1]), args[2]);
        }
        if self.name == "delattr" {
            if len(args) < 2 {
                return py_error("TypeError", "delattr expected 2 arguments");
            }
            return py_del_attr(args[0], expect_str(args[1]));
        }
        if self.name == "dir" {
            # dir(obj): CPython attribute enumeration over the NATIVE object
            # (see py_dir). The no-arg form is intercepted at the ceval CALL
            # site (it reads that frame's locals); reaching tp_call with zero
            # args means an indirect host-side callback, where CPython would
            # see the trampoline frame -- an empty local scope answers []
            # instead of leaking foreign frame names.
            if len(kwargs) > 0 {
                return py_error("TypeError", "dir() takes no keyword arguments");
            }
            if len(args) == 0 {
                return PyList(t="list", items=[]);
            }
            if len(args) > 1 {
                return py_error(
                    "TypeError", "dir expected at most 1 argument, got " + str(len(args))
                );
            }
            return py_dir(args[0]);
        }
        if self.name == "vars" {
            if len(kwargs) > 0 {
                return py_error("TypeError", "vars() takes no keyword arguments");
            }
            if len(args) == 0 {
                # No-arg vars() is locals(); like dir(), only the ceval CALL
                # site sees that frame -- an indirect call answers an empty
                # dict instead of leaking a foreign frame.
                return PyDict(t="dict", items={});
            }
            if len(args) > 1 {
                return py_error(
                    "TypeError", "vars expected at most 1 argument, got " + str(len(args))
                );
            }
            # A user instance answers with its LIVE __dict__ (identity-stable
            # view); routing through the host crossed as a stand-in and lost
            # every guest attribute behind the _jac_guest_ marker.
            o = args[0];
            if isinstance(o, PyUserObj) {
                return user_instance_dict(o as PyUserObj);
            }
            d = py_attr(o, "__dict__");
            if is_error(d)
                and (d as PyError).exception.type_name == "AttributeError" {
                return py_error(
                    "TypeError", "vars() argument must have __dict__ attribute"
                );
            }
            return d;
        }
        if self.name == "iter" {
            if len(args) == 0 {
                return py_error("TypeError", "iter expected at least 1 argument");
            }
            if len(args) >= 2 {
                # Two-arg form (CPython calliterobject). The callable check is
                # EAGER -- builtin_iter raises "iter(v, w): v must be callable"
                # at construction time, not on first next(). Iteration then
                # calls it with no args until the result equals the sentinel.
                if not obj_is_callable(args[0]) {
                    return py_error("TypeError", "iter(v, w): v must be callable");
                }
                return PyCallableIter(t="calliter", fn=args[0], sentinel=args[1]);
            }
            result = py_iter(args[0]);
            if is_error(result) and isinstance(args[0], PyHostProxy) {
                # Dict views and other host-only iterables still materialize once.
                return host_iter(args[0] as PyHostProxy);
            }
            return result;
        }
        # next(iterator[, default])
        if len(args) == 0 {
            return py_error("TypeError", "next expected at least 1 argument, got 0");
        }
        if len(args) > 2 {
            return py_error("TypeError", "next expected at most 2 arguments, got " + str(len(args)));
        }
        if args[0].t == "async_generator" {
            # PyAsyncGenObject has no tp_iternext; CPython rejects it in
            # builtin_next via PyIter_Check with this dedicated message.
            return py_error("TypeError", "'async_generator' object is not an iterator");
        }
        step = send_into(args[0], py_none());
        if step.t == "genstop" {
            if len(args) > 1 {
                return args[1];
            }
            # Forward the generator's return value as StopIteration.value
            # (CPython: next() exhaustion surfaces `return x` as .value).
            return stop_iteration((step as PyGenStop).val);
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
                    hsrc_r = to_host_coerce(src);
                    hsrc = hsrc_r[1];
                    if not ((hsrc_r[0] as bool)) {
                        return hsrc_r[1] as PyObj;
                    }
                    pairs = from_host(hsrc);
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

# Drain an iterator to exhaustion, collecting the yielded values into a FRESH
# PyList. The first error the iterator propagates is returned verbatim.
def drain_to_list(it: PyObj) -> PyObj {
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

# Materialize any iterable arg into a PyList of its members, or return a PyError
# if it is not iterable (this is the TypeError set().difference(123) must raise).
def members_of(arg: PyObj) -> PyObj {
    if isinstance(arg, PySet) {
        return PyList(t="list", items=(arg as PySet).set_members());
    }
    # A list arg needs no copy here: every consumer only READS the members
    # (set algebra). The list() ctor has its own path and always copies.
    if isinstance(arg, PyList) {
        return arg;
    }
    it = py_iter(arg);
    if is_error(it) {
        harg_r = to_host_coerce(arg);
        harg = harg_r[1];
        if not ((harg_r[0] as bool)) {
            return harg_r[1] as PyObj;
        }
        it = host_iter(PyHostProxy(t="host", val=harg));
        if is_error(it) {
            return it;
        }
    }
    return drain_to_list(it);
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
        # CPython's set method descriptors enforce arity up front (owner-prefixed
        # TypeErrors) instead of silently ignoring extras; only the *others
        # set-algebra families are variadic. update takes no kwargs either.
        variadic = n == "union"
            or n == "intersection"
            or n == "difference"
            or n == "update"
            or n == "difference_update"
            or n == "intersection_update"
            or n == "symmetric_difference_update";
        if len(kwargs) > 0 {
            return meth_no_kwargs("set", n);
        }
        if not variadic {
            if n == "pop" or n == "copy" or n == "clear" {
                if len(args) != 0 {
                    return meth_takes_none("set", n, len(args));
                }
            } elif len(args) != 1 {
                return meth_takes_one("set", n, len(args));
            }
        }
        if n == "__contains__" {
            return s.set_lookup(args[0]);
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
            return s.set_add(args[0]);
        }
        if n == "discard" {
            return s.set_discard(args[0]);
        }
        if n == "remove" {
            if not s.set_contains(args[0]) {
                return py_error("KeyError", dict_key_repr(args[0]));
            }
            return s.set_discard(args[0]);
        }
        # --- single-iterable-arg predicates ---
        if n == "issubset" or n == "issuperset" or n == "isdisjoint" {
            other = coerce_set(args[0]);
            if is_error(other) {
                return other;
            }
            os = other as PySet;
            if n == "issubset" {
                return set_richcompare(Py_LE, s, os);
            }
            if n == "issuperset" {
                return set_richcompare(Py_GE, s, os);
            }
            # isdisjoint: no shared member (element ``==``, not hashkey only).
            for hk in s.items {
                elem = s.items[hk];
                found = os.set_lookup(elem);
                if is_error(found) {
                    return found;
                }
                if (found as PyBool).val {
                    return PyBool(t="bool", val=False);
                }
            }
            return PyBool(t="bool", val=True);
        }
        # --- *others set-algebra (non-mutating) ---
        if n == "union"
            or n == "intersection"
            or n == "difference"
            or n == "symmetric_difference" {
            kind = NB_OR;
            if n == "intersection" {
                kind = NB_AND;
            } elif n == "difference" {
                kind = NB_SUBTRACT;
            } elif n == "symmetric_difference" {
                kind = NB_XOR;
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
        if n == "update"
            or n == "difference_update"
            or n == "intersection_update"
            or n == "symmetric_difference_update" {
            kind = NB_OR;
            if n == "difference_update" {
                kind = NB_SUBTRACT;
            } elif n == "intersection_update" {
                kind = NB_AND;
            } elif n == "symmetric_difference_update" {
                kind = NB_XOR;
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

# ---------------- native str methods ----------------
#
# The bound-method surface of boxed strings ('abc'.upper resolves to one of
# these), mirroring PyListMethod/PyDictMethod: dispatch runs entirely in-VM so
# lookups never round-trip a to_host COPY through host_getattr. Algorithms
# delegate to the underlying host string's own intrinsics after strict
# argument validation, so results (and the error messages below) stay
# byte-exact CPython -- including 3.14's lazy encode-error-handler lookup.
def is_str_method(name: str) -> bool {
    return name == "capitalize"
        or name == "casefold"
        or name == "center"
        or name == "count"
        or name == "encode"
        or name == "endswith"
        or name == "expandtabs"
        or name == "find"
        or name == "index"
        or name == "isalnum"
        or name == "isalpha"
        or name == "isascii"
        or name == "isdecimal"
        or name == "isdigit"
        or name == "isidentifier"
        or name == "islower"
        or name == "isnumeric"
        or name == "isprintable"
        or name == "isspace"
        or name == "istitle"
        or name == "isupper"
        or name == "join"
        or name == "ljust"
        or name == "lower"
        or name == "lstrip"
        or name == "maketrans"
        or name == "partition"
        or name == "removeprefix"
        or name == "removesuffix"
        or name == "replace"
        or name == "rfind"
        or name == "rindex"
        or name == "rjust"
        or name == "rpartition"
        or name == "rsplit"
        or name == "rstrip"
        or name == "split"
        or name == "splitlines"
        or name == "startswith"
        or name == "strip"
        or name == "swapcase"
        or name == "title"
        or name == "translate"
        or name == "upper"
        or name == "zfill";
}

obj PyStrMethod(PyObj) {
    has target: PyStr,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return str_method_call(self.target.val, self.name, args, kwargs);
    }
}

# Positional-or-keyword argument fetch. Absent arguments come back as the
# PY_NOT_IMPLEMENTED sentinel (never a legit method argument).
def _sm_arg(args: list[PyObj], kwargs: dict[str, PyObj], idx: int, kwname: str) -> PyObj {
    if idx < len(args) {
        return args[idx];
    }
    if kwname in kwargs {
        return kwargs[kwname];
    }
    return PY_NOT_IMPLEMENTED;
}

def _sm_absent(o: PyObj) -> bool {
    return o.t == "notimplemented";
}

# METH_NOARGS arity: ``str.upper() takes no arguments (1 given)`` /
# ``str.lower() takes no keyword arguments``.
def _sm_noargs(n: str, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    if len(kwargs) > 0 {
        return py_error("TypeError", "str." + n + "() takes no keyword arguments");
    }
    if len(args) > 0 {
        return py_error("TypeError", "str." + n + "() takes no arguments (" + str(len(args)) + " given)");
    }
    return py_none();
}

# Exactly-one-argument methods (join/partition/zfill/translate/maketrans arg1):
# ``str.join() takes exactly one argument (2 given)``.
def _sm_one_arg(n: str, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    total = len(args) + len(kwargs);
    if total != 1 {
        return py_error("TypeError", "str." + n + "() takes exactly one argument (" + str(total) + " given)");
    }
    if len(args) == 1 {
        return args[0];
    }
    for kv in kwargs {
        return kwargs[kv];
    }
    return PY_NOT_IMPLEMENTED;
}

# Plain __index__ context (width/maxsplit/count/tabsize):
# "'<T>' object cannot be interpreted as an integer".
def _sm_int(o: PyObj) -> PyObj {
    r = o.to_index();
    if is_error(r) {
        return py_error("TypeError", "'" + o.tp_type_name() + "' object cannot be interpreted as an integer");
    }
    return r;
}

# Slice-index context (start/end): None passes through, anything else must
# index -- "slice indices must be integers or None or have an __index__ method".
def _sm_slice_int(o: PyObj) -> PyObj {
    if isinstance(o, PyNoneType) {
        return o;
    }
    r = o.to_index();
    if is_error(r) {
        return py_error("TypeError", "slice indices must be integers or None or have an __index__ method");
    }
    return r;
}

# Drain any native iterable into elems for join(); True iff supported.
def _sm_iter_elems(src: PyObj, elems: list[PyObj]) -> bool {
    if isinstance(src, PyList) {
        for x in (src as PyList).items { elems.append(x); }
        return True;
    }
    if isinstance(src, PyTuple) {
        for x in tuple_value(src) { elems.append(x); }
        return True;
    }
    if isinstance(src, PySet) {
        for x in (src as PySet).set_members() { elems.append(x); }
        return True;
    }
    if isinstance(src, PyDict) {
        d = src as PyDict;
        for hk in d.items { elems.append(d.items[hk].key); }
        return True;
    }
    if isinstance(src, PyStr) {
        for ch in (src as PyStr).val { elems.append(PyStr(t="str", val=ch)); }
        return True;
    }
    if isinstance(src, PyIter) {
        it = src as PyIter;
        i = it.index;
        while i < len(it.items) { elems.append(it.items[i]); i = i + 1; }
        return True;
    }
    return False;
}

# str.encode with byte-exact UnicodeEncodeError construction. Codecs are
# matched against their alias tables, then every codepoint is pre-scanned so
# the host intrinsic only ever sees fully encodable input (its exceptions would
# otherwise escape the VM unconverted). Error handlers are validated lazily,
# matching CPython 3.14: an unknown handler raises LookupError only when an
# actual encoding error consults it.
def _sm_encode(s: str, encoding: str, errors: str) -> PyObj {
    enc = encoding.lower().replace("_", "-");
    limit = 1114111;
    canon = "utf-8";
    surrogates_only = False;
    if enc == "utf-8" or enc == "utf8" {
        surrogates_only = True;
    } elif enc == "ascii" or enc == "us-ascii" or enc == "us" or enc == "646" or enc == "ansi_x3.4-1968" or enc == "iso-ir-6" or enc == "iso646-us" or enc == "csascii" or enc == "cp367" or enc == "ibm367" {
        limit = 127;
        canon = "ascii";
    } elif enc == "latin-1" or enc == "latin1" or enc == "iso-8859-1" or enc == "iso8859-1" or enc == "l1" or enc == "8859-1" or enc == "cp819" or enc == "iso-ir-100" or enc == "latin" or enc == "cp28591" {
        limit = 255;
        canon = "latin-1";
    } else {
        return py_error("LookupError", "unknown encoding: " + encoding);
    }
    # Pre-scan for the first unencodable codepoint.
    bad_pos = -1;
    bad_cp = 0;
    i = 0;
    while i < len(s) {
        cp = ord(s[i]);
        viol = False;
        if surrogates_only {
            viol = cp >= 0xD800 and cp <= 0xDFFF;
        } else {
            viol = cp > limit;
        }
        if viol {
            bad_pos = i;
            bad_cp = cp;
            break;
        }
        i = i + 1;
    }
    out: list[int] = [];
    if bad_pos < 0 {
        bb = s.encode(encoding);
        for v in bb { out.append(v); }
        return PyBytes(t="bytes", val=out);
    }
    # An error was actually consulted: validate the handler now (3.14 semantics).
    h = errors.lower().replace("_", "-").replace(" ", "");
    known = h == "strict" or h == "ignore" or h == "replace"
        or h == "backslashreplace" or h == "xmlcharrefreplace";
    if not known {
        return py_error("LookupError", "unknown error handler name '" + errors + "'");
    }
    if h == "strict" {
        reason = "ordinal not in range(" + str(limit + 1) + ")";
        if surrogates_only {
            reason = "surrogates not allowed";
        }
        msg = "'" + canon + "' codec can't encode character '"
            + _repr_unicode_escape(bad_cp) + "' in position " + str(bad_pos) + ": " + reason;
        return py_error("UnicodeEncodeError", msg);
    }
    i = 0;
    while i < len(s) {
        ch = s[i];
        cp = ord(ch);
        viol = False;
        if surrogates_only {
            viol = cp >= 0xD800 and cp <= 0xDFFF;
        } else {
            viol = cp > limit;
        }
        if not viol {
            bb2 = ch.encode(encoding);
            for v in bb2 { out.append(v); }
        } elif h == "ignore" {
        } elif h == "replace" {
            out.append(63);
        } elif h == "backslashreplace" {
            esc = _repr_unicode_escape(cp);
            j = 0;
            while j < len(esc) { out.append(ord(esc[j])); j = j + 1; }
        } else {
            ref = "&#" + str(cp) + ";";
            j = 0;
            while j < len(ref) { out.append(ord(ref[j])); j = j + 1; }
        }
        i = i + 1;
    }
    return PyBytes(t="bytes", val=out);
}

# The full str method surface. `s` is the receiver's raw value.
def str_method_call(s: str, n: str, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    # ---- no-arg transforms ----
    if n == "upper" or n == "lower" or n == "capitalize" or n == "casefold"
        or n == "swapcase" or n == "title" {
        e = _sm_noargs(n, args, kwargs);
        if is_error(e) { return e; }
        r = s;
        if n == "upper" { r = s.upper(); }
        elif n == "lower" { r = s.lower(); }
        elif n == "capitalize" { r = s.capitalize(); }
        elif n == "casefold" { r = s.casefold(); }
        elif n == "swapcase" { r = s.swapcase(); }
        else { r = s.title(); }
        return PyStr(t="str", val=r);
    }
    # ---- no-arg predicates ----
    if n == "isalpha" or n == "isalnum" or n == "isascii" or n == "isdecimal"
        or n == "isdigit" or n == "isidentifier" or n == "islower"
        or n == "isnumeric" or n == "isprintable" or n == "isspace"
        or n == "istitle" or n == "isupper" {
        e = _sm_noargs(n, args, kwargs);
        if is_error(e) { return e; }
        b = False;
        if n == "isalpha" { b = s.isalpha(); }
        elif n == "isalnum" { b = s.isalnum(); }
        elif n == "isascii" { b = s.isascii(); }
        elif n == "isdecimal" { b = s.isdecimal(); }
        elif n == "isdigit" { b = s.isdigit(); }
        elif n == "isidentifier" { b = s.isidentifier(); }
        elif n == "islower" { b = s.islower(); }
        elif n == "isnumeric" { b = s.isnumeric(); }
        elif n == "isprintable" { b = s.isprintable(); }
        elif n == "isspace" { b = s.isspace(); }
        elif n == "istitle" { b = s.istitle(); }
        else { b = s.isupper(); }
        return PyBool(t="bool", val=b);
    }
    # ---- padding / alignment ----
    if n == "center" or n == "ljust" or n == "rjust" {
        wobj = _sm_arg(args, kwargs, 0, "width");
        if _sm_absent(wobj) {
            return py_error("TypeError", n + " expected at least 1 argument, got 0");
        }
        w = _sm_int(wobj);
        if is_error(w) { return w; }
        fill = " ";
        fobj = _sm_arg(args, kwargs, 1, "fillchar");
        if not _sm_absent(fobj) {
            if not isinstance(fobj, PyStr) {
                return py_error("TypeError", "The fill character must be a unicode character, not " + fobj.tp_type_name());
            }
            fill = (fobj as PyStr).val;
            if len(fill) != 1 {
                return py_error("TypeError", "The fill character must be exactly one character long");
            }
        }
        r = "";
        if n == "center" { r = s.center((w as PyInt).val, fill); }
        elif n == "ljust" { r = s.ljust((w as PyInt).val, fill); }
        else { r = s.rjust((w as PyInt).val, fill); }
        return PyStr(t="str", val=r);
    }
    if n == "zfill" {
        a = _sm_one_arg(n, args, kwargs);
        if is_error(a) { return a; }
        w = _sm_int(a);
        if is_error(w) { return w; }
        return PyStr(t="str", val=s.zfill((w as PyInt).val));
    }
    if n == "expandtabs" {
        if len(args) + len(kwargs) > 1 {
            return py_error("TypeError", "expandtabs() takes at most 1 argument (" + str(len(args) + len(kwargs)) + " given)");
        }
        tsize = 8;
        tobj = _sm_arg(args, kwargs, 0, "tabsize");
        if not _sm_absent(tobj) {
            ti = _sm_int(tobj);
            if is_error(ti) { return ti; }
            tsize = (ti as PyInt).val;
        }
        return PyStr(t="str", val=s.expandtabs(tsize));
    }
    # ---- strip family ----
    if n == "strip" or n == "lstrip" or n == "rstrip" {
        chars: any = None;
        cobj = _sm_arg(args, kwargs, 0, "chars");
        if not _sm_absent(cobj) {
            if not (isinstance(cobj, PyStr) or isinstance(cobj, PyNoneType)) {
                return py_error("TypeError", n + " arg must be None or str");
            }
            if isinstance(cobj, PyStr) { chars = (cobj as PyStr).val; }
        }
        r = "";
        if chars is None {
            if n == "strip" { r = s.strip(); }
            elif n == "lstrip" { r = s.lstrip(); }
            else { r = s.rstrip(); }
        } else {
            if n == "strip" { r = s.strip(chars); }
            elif n == "lstrip" { r = s.lstrip(chars); }
            else { r = s.rstrip(chars); }
        }
        return PyStr(t="str", val=r);
    }
    # ---- split family ----
    if n == "split" or n == "rsplit" {
        sep: any = None;
        sep_given = False;
        sobj = _sm_arg(args, kwargs, 0, "sep");
        if not _sm_absent(sobj) {
            if not (isinstance(sobj, PyStr) or isinstance(sobj, PyNoneType)) {
                return py_error("TypeError", "must be str or None, not " + sobj.tp_type_name());
            }
            if isinstance(sobj, PyStr) {
                sep = (sobj as PyStr).val;
                if len(sep) == 0 {
                    return py_error("ValueError", "empty separator");
                }
            }
            sep_given = True;
        }
        ms = -1;
        mobj = _sm_arg(args, kwargs, 1, "maxsplit");
        if not _sm_absent(mobj) {
            mi = _sm_int(mobj);
            if is_error(mi) { return mi; }
            ms = (mi as PyInt).val;
        }
        parts: list[str] = [];
        if not sep_given {
            if n == "split" { parts = s.split(None, ms); }
            else { parts = s.rsplit(None, ms); }
        } else {
            if n == "split" { parts = s.split(sep, ms); }
            else { parts = s.rsplit(sep, ms); }
        }
        items: list[PyObj] = [];
        for p in parts { items.append(PyStr(t="str", val=p)); }
        return PyList(t="list", items=items);
    }
    if n == "splitlines" {
        keep = False;
        kobj = _sm_arg(args, kwargs, 0, "keepends");
        if not _sm_absent(kobj) {
            kt = py_slot_truth(kobj);
            if is_error(kt) { return kt; }
            keep = (kt as PyBool).val;
        }
        parts: list[str] = [];
        if keep { parts = s.splitlines(True); } else { parts = s.splitlines(); }
        items: list[PyObj] = [];
        for p in parts { items.append(PyStr(t="str", val=p)); }
        return PyList(t="list", items=items);
    }
    # ---- partition ----
    if n == "partition" or n == "rpartition" {
        a = _sm_one_arg(n, args, kwargs);
        if is_error(a) { return a; }
        if not isinstance(a, PyStr) {
            return py_error("TypeError", "must be str, not " + a.tp_type_name());
        }
        sv = (a as PyStr).val;
        if len(sv) == 0 {
            return py_error("ValueError", "empty separator");
        }
        tup: tuple[str, str, str] = ("", "", "");
        if n == "partition" { tup = s.partition(sv); }
        else { tup = s.rpartition(sv); }
        items: list[PyObj] = [];
        for p in tup { items.append(PyStr(t="str", val=p)); }
        return PyTuple(t="tuple", items=items);
    }
    # ---- find family + count ----
    if n == "find" or n == "rfind" or n == "index" or n == "rindex" or n == "count" {
        sub = _sm_arg(args, kwargs, 0, "sub");
        if _sm_absent(sub) {
            return py_error("TypeError", n + " expected at least 1 argument, got 0");
        }
        if not isinstance(sub, PyStr) {
            return py_error("TypeError", n + "() argument 1 must be str, not " + sub.tp_type_name());
        }
        stv: any = None;
        env: any = None;
        sob = _sm_arg(args, kwargs, 1, "start");
        if not _sm_absent(sob) {
            si = _sm_slice_int(sob);
            if is_error(si) { return si; }
            stv = (si as PyInt).val;
        }
        eob = _sm_arg(args, kwargs, 2, "end");
        if not _sm_absent(eob) {
            ei = _sm_slice_int(eob);
            if is_error(ei) { return ei; }
            env = (ei as PyInt).val;
        }
        sv = (sub as PyStr).val;
        r = 0;
        if n == "rfind" or n == "rindex" { r = s.rfind(sv, stv, env); }
        elif n == "count" { r = s.count(sv, stv, env); }
        else { r = s.find(sv, stv, env); }
        if (n == "index" or n == "rindex") and r == -1 {
            return py_error("ValueError", "subsection not found");
        }
        return PyInt(t="int", val=r);
    }
    # ---- startswith / endswith ----
    if n == "startswith" or n == "endswith" {
        pfx = _sm_arg(args, kwargs, 0, n + "fix");
        if _sm_absent(pfx) {
            return py_error("TypeError", n + " expected at least 1 argument, got 0");
        }
        affs: any = None;
        if isinstance(pfx, PyStr) {
            affs = (pfx as PyStr).val;
        } elif isinstance(pfx, PyTuple) {
            ts: list[str] = [];
            for itp in tuple_value(pfx) {
                if not isinstance(itp, PyStr) {
                    return py_error("TypeError", "tuple for " + n + " must only contain str, not " + itp.tp_type_name());
                }
                ts.append((itp as PyStr).val);
            }
            affs = tuple(ts);
        } else {
            return py_error("TypeError", n + " first arg must be str or a tuple of str, not " + pfx.tp_type_name());
        }
        stv: any = None;
        env: any = None;
        sob = _sm_arg(args, kwargs, 1, "start");
        if not _sm_absent(sob) {
            si = _sm_slice_int(sob);
            if is_error(si) { return si; }
            stv = (si as PyInt).val;
        }
        eob = _sm_arg(args, kwargs, 2, "end");
        if not _sm_absent(eob) {
            ei = _sm_slice_int(eob);
            if is_error(ei) { return ei; }
            env = (ei as PyInt).val;
        }
        b = False;
        if n == "startswith" { b = s.startswith(affs, stv, env); }
        else { b = s.endswith(affs, stv, env); }
        return PyBool(t="bool", val=b);
    }
    # ---- replace ----
    if n == "replace" {
        oobj = _sm_arg(args, kwargs, 0, "old");
        nobj = _sm_arg(args, kwargs, 1, "new");
        if _sm_absent(oobj) or _sm_absent(nobj) {
            given = len(args) + len(kwargs);
            return py_error("TypeError", "replace() takes at least 2 positional arguments (" + str(given) + " given)");
        }
        if not isinstance(oobj, PyStr) {
            return py_error("TypeError", "replace() argument 1 must be str, not " + oobj.tp_type_name());
        }
        if not isinstance(nobj, PyStr) {
            return py_error("TypeError", "replace() argument 2 must be str, not " + nobj.tp_type_name());
        }
        cnt = -1;
        cobj = _sm_arg(args, kwargs, 2, "count");
        if not _sm_absent(cobj) {
            ci = _sm_int(cobj);
            if is_error(ci) { return ci; }
            cnt = (ci as PyInt).val;
        }
        return PyStr(t="str", val=s.replace((oobj as PyStr).val, (nobj as PyStr).val, cnt));
    }
    # ---- removeprefix / removesuffix ----
    if n == "removeprefix" or n == "removesuffix" {
        a = _sm_one_arg(n, args, kwargs);
        if is_error(a) { return a; }
        if not isinstance(a, PyStr) {
            return py_error("TypeError", n + "() argument must be str, not " + a.tp_type_name());
        }
        av = (a as PyStr).val;
        if n == "removeprefix" { return PyStr(t="str", val=s.removeprefix(av)); }
        return PyStr(t="str", val=s.removesuffix(av));
    }
    # ---- join ----
    if n == "join" {
        a = _sm_one_arg(n, args, kwargs);
        if is_error(a) { return a; }
        elems: list[PyObj] = [];
        if not _sm_iter_elems(a, elems) {
            itres = PyObject_GetIter(a);
            if is_error(itres) {
                return py_error("TypeError", "can only join an iterable");
            }
            drained = drain_to_list(itres);
            if is_error(drained) { return drained; }
            elems = (drained as PyList).items;
        }
        acc = "";
        i = 0;
        while i < len(elems) {
            el = elems[i];
            if not isinstance(el, PyStr) {
                return py_error("TypeError", "sequence item " + str(i) + ": expected str instance, " + el.tp_type_name() + " found");
            }
            if i > 0 { acc = acc + s; }
            acc = acc + (el as PyStr).val;
            i = i + 1;
        }
        return PyStr(t="str", val=acc);
    }
    # ---- translate ----
    if n == "translate" {
        table = _sm_one_arg(n, args, kwargs);
        if is_error(table) { return table; }
        out = "";
        i = 0;
        while i < len(s) {
            res = table.mp_subscript(PyInt(t="int", val=ord(s[i])));
            if is_error(res) {
                etn = (res as PyError).exception.type_name;
                if etn != "KeyError" {
                    if etn == "TypeError" {
                        return py_error("TypeError", "'" + table.tp_type_name() + "' object is not subscriptable");
                    }
                    return res;
                }
                out = out + s[i];
            } elif isinstance(res, PyNoneType) {
            } elif isinstance(res, PyStr) {
                out = out + (res as PyStr).val;
            } elif isinstance(res, PyInt) {
                cp = (res as PyInt).val;
                if cp < 0 or cp > 1114111 {
                    return py_error("ValueError", "character mapping must be in range(0x110000)");
                }
                out = out + chr(cp);
            } else {
                return py_error("TypeError", "character mapping must return integer, None or str");
            }
            i = i + 1;
        }
        return PyStr(t="str", val=out);
    }
    # ---- maketrans (staticmethod, reachable from instances too) ----
    if n == "maketrans" {
        if len(kwargs) > 0 {
            return py_error("TypeError", "str.maketrans() takes no keyword arguments");
        }
        if len(args) == 0 or len(args) > 3 {
            return py_error("TypeError", "maketrans expected at least 1 argument, got " + str(len(args)));
        }
        x = args[0];
        d = PyDict(t="dict", items={});
        if isinstance(x, PyStr) {
            if len(args) < 2 {
                return py_error("TypeError", "if you give only one argument to maketrans it must be a dict");
            }
            y = args[1];
            if not isinstance(y, PyStr) {
                return py_error("TypeError", "maketrans() argument 2 must be str, not " + y.tp_type_name());
            }
            xv = (x as PyStr).val;
            yv = (y as PyStr).val;
            if len(xv) != len(yv) {
                return py_error("ValueError", "the first two maketrans arguments must have equal length");
            }
            i = 0;
            while i < len(xv) {
                se = d.dict_set(PyInt(t="int", val=ord(xv[i])), PyInt(t="int", val=ord(yv[i])));
                if is_error(se) { return se; }
                i = i + 1;
            }
        } elif isinstance(x, PyDict) {
            if len(args) > 1 {
                return py_error("TypeError", "first maketrans argument must be a string if there is a second argument");
            }
            xd = x as PyDict;
            for hk in xd.items {
                ko = xd.items[hk].key;
                vo = xd.items[hk].value;
                nk: PyObj = ko;
                if isinstance(ko, PyStr) {
                    kv = (ko as PyStr).val;
                    if len(kv) != 1 {
                        return py_error("TypeError", "keys in translate table mustbe strings or integers");
                    }
                    nk = PyInt(t="int", val=ord(kv));
                } elif isinstance(ko, PyBool) {
                    bv = 0;
                    if (ko as PyBool).val { bv = 1; }
                    nk = PyInt(t="int", val=bv);
                } elif not isinstance(ko, PyInt) {
                    return py_error("TypeError", "keys in translate table mustbe strings or integers");
                }
                se = d.dict_set(nk, vo);
                if is_error(se) { return se; }
            }
        } else {
            return py_error("TypeError", "first maketrans argument must be a string if there is a second argument");
        }
        if len(args) == 3 {
            z = args[2];
            if not isinstance(z, PyStr) {
                return py_error("TypeError", "maketrans() argument 3 must be str, not " + z.tp_type_name());
            }
            zv = (z as PyStr).val;
            i = 0;
            while i < len(zv) {
                se = d.dict_set(PyInt(t="int", val=ord(zv[i])), py_none());
                if is_error(se) { return se; }
                i = i + 1;
            }
        }
        return d;
    }
    # ---- encode ----
    if n == "encode" {
        enc = "utf-8";
        errs = "strict";
        eobj = _sm_arg(args, kwargs, 0, "encoding");
        if not _sm_absent(eobj) {
            if not isinstance(eobj, PyStr) {
                return py_error("TypeError", "encode() argument 'encoding' must be str, not " + eobj.tp_type_name());
            }
            enc = (eobj as PyStr).val;
        }
        robj = _sm_arg(args, kwargs, 1, "errors");
        if not _sm_absent(robj) {
            if not isinstance(robj, PyStr) {
                return py_error("TypeError", "encode() argument 'errors' must be str, not " + robj.tp_type_name());
            }
            errs = (robj as PyStr).val;
        }
        return _sm_encode(s, enc, errs);
    }
    return py_error("AttributeError", n);
}

# Native mutating/accessor list methods. Without these, `lst.append(x)` routes to
# host_getattr on a to_host COPY of the list -- the mutation is lost. Load-bearing
# for any code that builds a list by `.append` (enum's EnumDict._member_names
# tracking, most stdlib), not just comprehensions (which use LIST_APPEND).
def is_list_method(name: str) -> bool {
    return name == "append"
        or name == "extend"
        or name == "insert"
        or name == "pop"
        or name == "remove"
        or name == "clear"
        or name == "index"
        or name == "count"
        or name == "reverse"
        or name == "sort"
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

# Materialize any iterable into a fresh list, propagating iteration errors.
def iter_drain(src: PyObj) -> PyObj {
    it = py_iter(src);
    if is_error(it) {
        return it;
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

# sorted()/max()/min(): natively served so key= (a VM callable) actually runs.
# sorted reuses list_sort_inplace's decorate-sort-undecorate machinery, so
# key=/reverse= behave exactly like list.sort(). max/min follow CPython: one
# positional iterable (with default= for emptiness) or several positionals,
# ties keep the first candidate, key failures and comparison failures raise.
def builtin_sorted_min_max(name: str, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    is_sorted = name == "sorted";
    key_fn = py_none();
    do_reverse = False;
    has_default = False;
    default_val = py_none();
    for kw in kwargs {
        if kw == "key" {
            key_fn = kwargs[kw];
        } elif is_sorted and kw == "reverse" {
            rev = py_slot_truth(kwargs[kw]);
            if is_error(rev) {
                return rev;
            }
            do_reverse = (rev as PyBool).val;
        } elif not is_sorted and kw == "default" {
            has_default = True;
            default_val = kwargs[kw];
        } else {
            return py_error("TypeError", "'" + kw + "' is an invalid keyword argument for " + name + "()");
        }
    }
    if is_sorted {
        # CPython's sorted is (iterable, /): both under- and over-calls report
        # the plain "expected 1 argument" clinic wording.
        if len(args) != 1 {
            return py_error("TypeError", name + " expected 1 argument, got " + str(len(args)));
        }
        drained = iter_drain(args[0]);
        if is_error(drained) {
            return drained;
        }
        out = drained as PyList;
        err = list_sort_inplace(out, key_fn, do_reverse);
        if is_error(err) {
            return err;
        }
        return out as PyObj;
    }
    if len(args) == 0 {
        return py_error("TypeError", name + " expected at least 1 argument, got 0");
    }
    candidates: list[PyObj] = [];
    if len(args) == 1 {
        drained = iter_drain(args[0]);
        if is_error(drained) {
            return drained;
        }
        candidates = (drained as PyList).items;
    } else {
        if has_default {
            return py_error("TypeError", "Cannot specify a default for " + name + "() with multiple positional arguments");
        }
        candidates = args;
    }
    best: PyObj | None = None;
    best_key: PyObj | None = None;
    for v in candidates {
        k = v;
        if not (key_fn.t == "none") {
            k = key_fn.tp_call([v], {});
            if is_error(k) {
                return k;
            }
        }
        take = best is None;
        if not take {
            if name == "max" {
                cmp = py_compare(0, best_key as PyObj, k);
            } else {
                cmp = py_compare(0, k, best_key as PyObj);
            }
            if is_error(cmp) {
                return cmp;
            }
            ctruth = py_slot_truth(cmp);
            if is_error(ctruth) {
                return ctruth;
            }
            take = (ctruth as PyBool).val;
        }
        if take {
            best = v;
            best_key = k;
        }
    }
    if best is None {
        if has_default {
            return default_val;
        }
        return py_error("ValueError", name + "() iterable argument is empty");
    }
    return best as PyObj;
}

# CPython list.sort(): stable merge sort driven by py_compare(<). key= uses
# decorate-sort-undecorate; reverse= flips the comparison (NOT the tie-break),
# so equal elements keep insertion order in both directions. Mutates lst in
# place; returns an error from a failing comparison, else None.
def list_sort_inplace(lst: PyList, key_fn: PyObj, do_reverse: bool) -> PyObj {
    n_count = len(lst.items);
    if n_count <= 1 {
        return py_none();
    }
    pairs: list[PyObj] = [];
    idx = 0;
    while idx < n_count {
        v = lst.items[idx];
        k = v;
        if not (key_fn.t == "none") {
            res = key_fn.tp_call([v], {});
            if is_error(res) {
                return res;
            }
            k = res;
        }
        pairs.append(PyTuple(t="tuple", items=[k, v]));
        idx = idx + 1;
    }
    width = 1;
    while width < n_count {
        merged: list[PyObj] = [];
        i = 0;
        while i < n_count {
            mid = i + width;
            hi = i + 2 * width;
            if mid > n_count {
                mid = n_count;
            }
            if hi > n_count {
                hi = n_count;
            }
            a = i;
            b = mid;
            while a < mid and b < hi {
                ka = ((pairs[a] as PyTuple).items[0]);
                kb = ((pairs[b] as PyTuple).items[0]);
                # Normal order takes b when kb < ka; reverse takes b when
                # ka < kb. Ties always take a, which is what keeps the sort
                # stable in both directions.
                if do_reverse {
                    lt = py_compare(0, ka, kb);
                } else {
                    lt = py_compare(0, kb, ka);
                }
                if is_error(lt) {
                    return lt;
                }
                if (lt as PyBool).val {
                    merged.append(pairs[b]);
                    b = b + 1;
                } else {
                    merged.append(pairs[a]);
                    a = a + 1;
                }
            }
            while a < mid {
                merged.append(pairs[a]);
                a = a + 1;
            }
            while b < hi {
                merged.append(pairs[b]);
                b = b + 1;
            }
            i = i + 2 * width;
        }
        pairs = merged;
        width = width * 2;
    }
    sorted_items: list[PyObj] = [];
    for p in pairs {
        sorted_items.append((p as PyTuple).items[1]);
    }
    lst.items = sorted_items;
    return py_none();
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
        if n == "sort" {
            if len(args) != 0 {
                return py_error("TypeError", "sort() takes no positional arguments");
            }
            key_fn = py_none();
            do_reverse = False;
            for kw in kwargs {
                if kw == "key" {
                    key_fn = kwargs[kw];
                } elif kw == "reverse" {
                    truth = py_slot_truth(kwargs[kw]);
                    if is_error(truth) {
                        return truth;
                    }
                    do_reverse = (truth as PyBool).val;
                } else {
                    return py_error("TypeError", "'" + kw + "' is an invalid keyword argument for sort()");
                }
            }
            return list_sort_inplace(lst, key_fn, do_reverse);
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
    return name == "get"
        or name == "setdefault"
        or name == "pop"
        or name == "popitem"
        or name == "update"
        or name == "clear"
        or name == "copy"
        or name == "__contains__"
        or name == "__getitem__"
        or name == "__setitem__"
        or name == "__delitem__";
}

obj PyDictMethod(PyObj) {
    has target: PyDict,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        n = self.name;
        d = self.target;
        # CPython method-descriptor arity contracts, byte-exact: fixed-arity
        # methods raise instead of ignoring extras; only update consumes **kwds.
        if n != "update" and len(kwargs) > 0 {
            return meth_no_kwargs("dict", n);
        }
        if n == "popitem" or n == "clear" or n == "copy" {
            if len(args) != 0 {
                return meth_takes_none("dict", n, len(args));
            }
        }
        if n == "__contains__" or n == "__getitem__" {
            if len(args) != 1 {
                return meth_takes_one("dict", n, len(args));
            }
        }
        if n == "__setitem__" and len(args) != 2 {
            return py_error("TypeError", "__setitem__ expected 2 arguments, got " + str(len(args)));
        }
        if n == "__delitem__" and len(args) != 1 {
            return py_error("TypeError", "expected 1 argument, got " + str(len(args)));
        }
        if n == "get" or n == "setdefault" or n == "pop" {
            if len(args) < 1 {
                return py_error("TypeError", n + " expected at least 1 argument, got 0");
            }
            if len(args) > 2 {
                return py_error("TypeError", n + " expected at most 2 arguments, got " + str(len(args)));
            }
        }
        if n == "update" and len(args) > 1 {
            return py_error("TypeError", "update expected at most 1 argument, got " + str(len(args)));
        }
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
            default_val = args[1] if len(args) >= 2 else py_none();
            r = d.mp_ass_subscript(args[0], default_val);
            if is_error(r) {
                return r;
            }
            return default_val;
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
            # LIFO: dict.popitem() returns the LAST inserted (key, value) pair,
            # not the first. dict_keys() yields insertion order, so take the tail.
            last_key: PyObj = py_none();
            has_key = False;
            for keyobj in d.dict_keys() {
                last_key = keyobj;
                has_key = True;
            }
            if has_key {
                v = d.mp_subscript(last_key);
                d.mp_del_subscript(last_key);
                return PyTuple(t="tuple", items=[last_key, v]);
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
    hkr = key.tp_hashkey();
    if is_error(hkr) {
        return py_error("TypeError", "unhashable type");
    }
    hk = hashkey_str(hkr);
    if not (hk in d.items) {
        return PyBool(t="bool", val=False);
    }
    stored = d.items[hk].key;
    if _needs_eq_confirm(stored) or _needs_eq_confirm(key) {
        keq = py_compare(2, stored, key);
        if is_error(keq) {
            return keq;
        }
        # py_slot_truth returns a PyBool on success -- hand it straight back.
        return py_slot_truth(keq);
    }
    return PyBool(t="bool", val=True);
}

# The stored value for a key, a PyAbsent sentinel if not present, or a PyError.
def dict_lookup_value(d: PyDict, key: PyObj) -> PyObj {
    hkr = key.tp_hashkey();
    if is_error(hkr) {
        return py_error("TypeError", "unhashable type");
    }
    hk = hashkey_str(hkr);
    if not (hk in d.items) {
        return PyAbsent(t="absent");
    }
    stored = d.items[hk].key;
    if _needs_eq_confirm(stored) or _needs_eq_confirm(key) {
        keq = py_compare(2, stored, key);
        if is_error(keq) {
            return keq;
        }
        truth = py_slot_truth(keq);
        if is_error(truth) {
            return truth;
        }
        if not (truth as PyBool).val {
            return PyAbsent(t="absent");
        }
    }
    return d.items[hk].value;
}

# The bound method object d.keys / d.values / d.items resolves to; calling it
# builds the view (matching CPython, where `d.keys` is a builtin method and
# `d.keys()` is the view).
# Bound has_default() on a PEP 695 TypeVar (PEP 696): zero-arg probe of
# whether a default was supplied at parameter creation -- purely syntactic,
# never forces default evaluation.
obj PyTypeVarMethod(PyObj) {
    has tv: PyTypeVar,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return meth_no_kwargs("TypeVar", self.name);
        }
        if len(args) != 0 {
            return meth_takes_none("TypeVar", self.name, len(args));
        }
        return PyBool(t="bool", val=self.tv.evaluate_default.t != "none");
    }
}

obj PyDictViewCtor(PyObj) {
    has d: PyDict,
        mode: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return meth_no_kwargs("dict", self.mode);
        }
        if len(args) != 0 {
            return meth_takes_none("dict", self.mode, len(args));
        }
        return PyDictView(t="dictview_obj", d=self.d, mode=self.mode);
    }
}

obj PyDictView(PyObj) {
    has d: PyDict,
        mode: str;

    def tp_type_name -> str {
        return "dict_" + self.mode;
    }

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
        `entry = view.d.items[hk];
        if view.mode == "values" {
            out.append(`entry.value);
        } elif view.mode == "items" {
            out.append(PyTuple(t="tuple", items=[`entry.key, `entry.value]));
        } else {
            out.append(`entry.key);
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
        ctruth = py_slot_truth(c);
        if is_error(ctruth) {
            return ctruth;
        }
        if (ctruth as PyBool).val {
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
        return (container as PySet).set_lookup(elem);
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
        ctruth = py_slot_truth(c);
        if is_error(ctruth) {
            return ctruth;
        }
        if not (ctruth as PyBool).val {
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
        truth = py_slot_truth(r);
        if is_error(truth) {
            return truth;
        }
        return PyBool(t="bool", val=not (truth as PyBool).val);
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
    return py_ordering_type_error(kind, a, b, _compare_type_name);
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

# INTRINSIC_ASYNC_GEN_WRAP's payload (generated_cases.c.h): every value an
# async generator yields is wrapped so the anext/asend driver can tell a
# yield from a return even though both cross the same resume machinery.
obj PyAsyncGenWrappedValue(PyObj) {
    has val: PyObj;
}

# The one-shot awaitable `ag.__anext__()` / `ag.asend(v)` returns. The SEND
# loop drives it through agen_asend_step like a native coroutine: a yield
# surfaces the UNWRAPPED value, exhaustion raises StopAsyncIteration.
obj PyAsyncGenASend(PyObj) {
    has gen: PyGenerator,
        value: PyObj,
        started: bool = False;
}

# The one-shot awaitable `ag.athrow(exc)` / `ag.aclose()` returns: on first
# drive it throws `err` into the generator at its suspend point. aclose=True
# runs the GeneratorExit close protocol (silent on clean exit, RuntimeError
# when the generator yields again).
obj PyAsyncGenAThrow(PyObj) {
    has gen: PyGenerator,
        err: PyObj,
        aclose: bool = False,
        started: bool = False;
}

# A bound async-generator driver (asend/athrow/aclose/__anext__/__aiter__).
# Each call returns a FRESH awaitable object (genobject.c's
# async_gen_asend/athrow_new); awaiting it drives the underlying frame.
obj PyAsyncGenMethod(PyObj) {
    has gen: PyGenerator,
        kind: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if self.kind == "anext" or self.kind == "__anext__" {
            return PyAsyncGenASend(t="agen_asend", gen=self.gen, value=py_none());
        }
        if self.kind == "asend" {
            if len(args) < 1 {
                return py_error("TypeError", "asend expected at least 1 argument");
            }
            return PyAsyncGenASend(t="agen_asend", gen=self.gen, value=args[0]);
        }
        if self.kind == "aclose" {
            return PyAsyncGenAThrow(
                t="agen_athrow", gen=self.gen, err=py_none(), aclose=True
            );
        }
        if self.kind == "__aiter__" {
            # PyAsyncGenObject.__aiter__ returns self, so `async for`
            # iterates the generator itself.
            return self.gen;
        }
        # athrow: an exception instance or type, coerced now so a bad operand
        # surfaces at call time. Multi-arg (type, value[, tb]) forms stay in
        # parity with the sync gen_throw surface.
        thrown = py_none();
        if len(args) > 0 {
            thrown = args[0];
        }
        err = as_error(thrown);
        if err.t != "error" {
            return err;
        }
        return PyAsyncGenAThrow(t="agen_athrow", gen=self.gen, err=err);
    }
}

obj PyGenerator(PyObj) {
    has frame: PyFrame,
        started: bool = False,
        finished: bool = False,
        running: bool = False,
        # __name__ / __qualname__ overrides (gen_set_name/gen_set_qualname write
        # the generator object, not the code). Empty string = fall back to the
        # code object's name, matching CPython's pre-assignment read path.
        gen_name: str = "",
        gen_qualname: str = "";

    def tp_iter -> PyObj {
        # An async generator is driven exclusively through __anext__/asend;
        # CPython gives it no tp_iter at all.
        if self.t == "async_generator" {
            return py_error("TypeError", "'async_generator' object is not iterable");
        }
        return self;
    }

    # gen.send / gen.throw / gen.close / gen.__next__ resolve to native bound
    # driver methods; every other attribute is a real AttributeError. An async
    # generator (CO_ASYNC_GENERATOR) presents the ag_* surface instead: its
    # drivers return awaitables, and the sync driver names are absent exactly
    # as CPython's PyAsyncGenObject lacks send/throw/close/__next__.
    def tp_getattro(name: str) -> PyObj {
        if self.t == "async_generator" {
            if name == "asend" or name == "athrow" or name == "aclose"
                or name == "__anext__" or name == "__aiter__" {
                return PyAsyncGenMethod(t="agen_method", gen=self, kind=name);
            }
            if name == "ag_frame" {
                return PyGenFrame(t="genframe", gen=self);
            }
            if name == "ag_running" {
                # True only while the frame is actively executing, like gi_running.
                return PyBool(t="bool", val=self.running);
            }
            return py_error(
                "AttributeError",
                "'async_generator' object has no attribute '" + name + "'",
            );
        }
        if name == "send" or name == "throw" or name == "close" or name == "__next__" {
            return PyGenMethod(t="gen_method", gen=self, kind=name);
        }
        if name == "gi_frame" or name == "ag_frame" {
            return PyGenFrame(t="genframe", gen=self);
        }
        if name == "gi_running" or name == "ag_running" {
            # True only while the generator's frame is actively executing;
            # observable from re-entrant access (the generator inspecting
            # itself through a callback), False while suspended/finished.
            return PyBool(t="bool", val=self.running);
        }
        if name == "gi_yieldfrom" {
            # The sub-iterator a `yield from` is currently delegating to, else
            # None (genobject.c gi_yieldfrom getter). At a YIELD_VALUE(oparg 1)
            # suspension the sent slot has been consumed by the yield, so the
            # delegating receiver is the stack top.
            if self.frame.yf and len(self.frame.stack) >= 1 {
                return self.frame.stack[len(self.frame.stack) - 1];
            }
            return py_none();
        }
        if name == "__name__" {
            gname = self.gen_name;
            if gname == "" {
                gname = self.frame.co.name;
            }
            return PyStr(t="str", val=gname);
        }
        if name == "__qualname__" {
            gqn = self.gen_qualname;
            if gqn == "" {
                gqn = self.frame.co.qualname;
            }
            return PyStr(t="str", val=gqn);
        }
        return py_error("AttributeError", name);
    }

    # Only __name__/__qualname__ are writable on a generator object; everything
    # else keeps raising AttributeError (CPython has no other settable members).
    def tp_setattro(name: str, value: PyObj) -> PyObj {
        if name != "__name__" and name != "__qualname__" {
            return py_error("AttributeError", name);
        }
        if not isinstance(value, PyStr) {
            label = "__qualname__";
            if name == "__name__" {
                label = "__name__";
            }
            return py_error("TypeError", label + " must be set to a string object");
        }
        if self.running {
            return py_error("ValueError", "generator already executing");
        }
        text = (value as PyStr).val;
        if name == "__name__" {
            self.gen_name = text;
        } else {
            self.gen_qualname = text;
        }
        return py_none();
    }
}

# A bound generator driver (gen.send/throw/close/__next__). Calling it drives the
# suspended frame and raises StopIteration on exhaustion, matching CPython's
# generator method surface (unlike FOR_ITER, which swallows the StopIteration).
obj PyGenMethod(PyObj) {
    has gen: PyGenerator,
        kind: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        # Method-name prefix in arity errors mirrors CPython's METH_DEF_NAME
        # bindings: "generator.send()", "coroutine.close()", ...
        label = self.gen.t;
        if len(kwargs) > 0 {
            return py_error("TypeError", label + "." + self.kind + "() takes no keyword arguments");
        }
        if self.kind == "throw" {
            if len(args) < 1 {
                return py_error("TypeError", "throw expected at least 1 argument, got 0");
            }
            if len(args) > 3 {
                return py_error(
                    "TypeError",
                    "throw expected at most 3 arguments, got " + str(len(args))
                );
            }
            thrown = normalize_throw_args(args);
            result = gen_throw(self.gen, thrown);
            # A generator that catches the injected exception and returns
            # normally exhausts like any other run: surface its return value as
            # StopIteration(return_value), not a bare sentinel (gen_send_ex).
            if result.t == "genstop" {
                return stop_iteration((result as PyGenStop).val);
            }
            return result;
        }
        if self.kind == "close" {
            if len(args) > 0 {
                return py_error(
                    "TypeError",
                    label + ".close() takes no arguments (" + str(len(args)) + " given)"
                );
            }
            return gen_close(self.gen);
        }
        if self.kind == "send" {
            if len(args) != 1 {
                return py_error(
                    "TypeError",
                    label + ".send() takes exactly one argument ("
                        + str(len(args)) + " given)"
                );
            }
            return gen_send(self.gen, args[0]);
        }
        # __next__: CPython's slot wrapper takes no arguments.
        if len(args) > 0 {
            return py_error(
                "TypeError",
                label + ".__next__() takes no arguments (" + str(len(args)) + " given)"
            );
        }
        return gen_send(self.gen, py_none());
    }
}

# Normalize gen.throw(a[, b[, c]]) operands into the error to inject, following
# CPython _gen_throw: instance with a separate value is rejected; a type is
# instantiated with the value; anything else is a TypeError naming its type.
# (The 2/3-arg form carries a DeprecationWarning upstream; the VM has no warning
# machinery yet, so only the behavior is mirrored here.)
def normalize_throw_args(args: list[PyObj]) -> PyObj {
    typ = args[0];
    val = py_none();
    if len(args) >= 2 {
        val = args[1];
    }
    if len(args) == 3 and args[2].t != "none" {
        return py_error("TypeError", "throw() third argument must be a traceback object");
    }
    if isinstance(typ, PyHostProxy) {
        # Host-proxied exception classes/instances (the non-layer3 builtin
        # surface). Same normalization order as CPython, decided over the raw
        # host object.
        raw = (typ as PyHostProxy).val;
        inst_info = _jac_host_exception_instance(raw);
        if inst_info[0] as bool {
            if val.t != "none" {
                return py_error("TypeError", "instance exception may not have a separate value");
            }
            return as_error(typ);
        }
        if bool(_jac_is_exception_type(raw)) {
            if val.t == "none" {
                return as_error(typ);
            }
            inst = typ.tp_call([val], {});
            if is_error(inst) {
                return inst;
            }
            return py_raise_value(inst);
        }
    }
    if typ.t == "exception"
        or (isinstance(typ, PyUserObj)
            and class_is_exception((typ as PyUserObj).cls)) {
        # Raising an instance: the value must be a dummy.
        if val.t != "none" {
            return py_error("TypeError", "instance exception may not have a separate value");
        }
        return as_error(typ);
    }
    if typ.t == "exception_type" {
        if val.t == "none" {
            return as_error(typ);
        }
        return PyError(
            t="error",
            exception=(typ as PyExceptionType).tp_call([val], {}) as PyException,
        );
    }
    if isinstance(typ, PyClass) and class_is_exception(typ as PyClass) {
        if val.t == "none" {
            return as_error(typ);
        }
        inst = (typ as PyClass).tp_call([val], {});
        if is_error(inst) {
            return inst;
        }
        return py_raise_value(inst);
    }
    # Not something you can throw.
    type_label = "object";
    tn = py_type_of(typ);
    if isinstance(tn, PyClass) {
        type_label = (tn as PyClass).name;
    } elif isinstance(tn, PyHostProxy) {
        nm = (tn as PyHostProxy).tp_getattro("__name__");
        if not is_error(nm) and isinstance(nm, PyStr) {
            type_label = (nm as PyStr).val;
        }
    }
    return py_error(
        "TypeError",
        "exceptions must be classes or instances deriving from BaseException, not "
            + type_label
    );
}

# Resume `gen` with `sent` (the value YIELD_VALUE produces on wake; None for
# plain iteration). Returns the yielded PyObj on a yield, a PyGenStop on normal
# return (exhaustion), or a propagating error object on a raise.
def gen_resume(gen: PyGenerator, sent: PyObj) -> PyObj {    if gen.running {
        # CPython: resuming a generator whose frame is already executing
        # (self-resume via a callback/trampoline) raises ValueError.
        return py_error("ValueError", "generator already executing");
    }
    if gen.finished {
        if gen.t == "coroutine" {
            # CPython coro_send: a finished coroutine cannot be driven again.
            return py_error("RuntimeError", "cannot reuse already awaited coroutine");
        }
        return PyGenStop(t="genstop", val=py_none());
    }
    if gen.started {
        # YIELD_VALUE popped its operand when it suspended; the resume value
        # takes its place on the stack (the trailing POP_TOP discards it in a
        # genexpr; `x = yield` would bind it in a full generator).
        gen.frame.stack.append(sent);
    }
    gen.started = True;
    gen.running = True;
    result = run_frame(gen.frame);
    return finish_gen_result(gen, result);
}

# Common tail for every generator re-entry (resume/send/throw): translate the
# raw run_frame outcome into the yielded value | PyGenStop(return value) | error
# shape that all generator drivers speak.
def finish_gen_result(gen: PyGenerator, result: PyObj) -> PyObj {
    gen.running = False;
    if is_error(result) {
        gen.finished = True;
        if gen.t == "async_generator"
            and ((result as PyError).exception).type_name == "StopAsyncIteration" {
            # genobject.c gen_send_ex2: StopAsyncIteration escaping an async
            # generator's body means the generator tried to end its own
            # iteration -- the RuntimeError analogue of PEP 479's StopIteration
            # guard for sync generators.
            return py_error("RuntimeError", "async generator raised StopAsyncIteration");
        }
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
# CPython gen_send_ex raises StopIteration(value), so the payload must also
# materialize through args -> .args / __str__ / __repr__ (StopIteration(42),
# not an argless StopIteration() hiding its payload in .value alone). A None
# payload (bare return / fall-off-end) stays argless exactly like the host:
# StopIteration(), args=(), .value=None.
def stop_iteration(value: PyObj) -> PyObj {
    if value.t == "none" {
        return PyError(
            t="error",
            exception=PyException(
                t="exception", type_name="StopIteration", message="", value=value
            ),
        );
    }
    return PyError(
        t="error",
        exception=PyException(
            t="exception",
            type_name="StopIteration",
            message="",
            args=[value],
            value=value
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
    if gen.running {
        return py_error("ValueError", "generator already executing");
    }
    err = as_error(thrown);
    if err.t != "error" {
        return err;
    }
    if gen.finished and gen.t == "coroutine" {
        # Same reuse guard as gen_resume: throwing into a finished coroutine
        # reports the re-await, not the injected exception (CPython coro throw).
        return py_error("RuntimeError", "cannot reuse already awaited coroutine");
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
        gen.running = True;
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
    gen.running = True;
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
        if exc_is_stopiter(exc) {
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
        # Converted (cell) slots release the cell's contents; plain slots release
        # their value when bound. Covers dynamically MAKE_CELL'd slots too.
        slot_entry = frame.fast[idx];
        if isinstance(slot_entry, PyCell) {
            held.append((slot_entry as PyCell).val);
        } elif idx < len(frame.assigned) and frame.assigned[idx] {
            held.append(slot_entry);
        }
        idx = idx + 1;
    }
    for item in frame.stack {
        held.append(item);
    }
    for name in frame.locals {
        held.append(frame.locals[name]);
    }
    if frame.exc_state is not None {
        # Abandoned (never-resumed/closed) generator: its suspended handler
        # entries were already removed at suspend time EXCEPT when cleared
        # mid-handling after a resume -- drain any residual copies.
        _handled_stack_remove_each(frame.exc_state as list[PyObj]);
    }
    frame.fast = [];
    frame.stack = [];
    frame.locals = {};
    for obj in held {
        if isinstance(obj, PyUserObj)
            and user_has_dunder(obj as PyUserObj, "__del__") {
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

    # Identity hash: same stdlib set/dict-key surface as the weakref shim.
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

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
# Native weakref module surface (shimmed over host weakref). CPython-faithful
# for objects whose RAW Python identity is the object itself (PyUserObj,
# PyClass, functions, generators): deref hands back the identical object, and
# death follows refcounting exactly. Boxed value types (int/str/list/...) are
# rejected up front because CPython makes them un-weakreferenceable, and host
# proxies are rejected because deref would mint a fresh proxy and break
# `r() is o` identity.
obj PyWeakRefFn(PyObj) {
    # Identity hash (CPython: builtin-style callables hash by id); copy.py's
    # module init stores these wrappers in hash-keyed dispatch structures.
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 1 {
            # callback= / weakref.ref(cls) forms unsupported by this surface.
            return py_error("TypeError", "weakref.ref expected 1 argument");
        }
        target = args[0];
        if isinstance(target, PyHostProxy) or isinstance(target, PyInt)
            or isinstance(target, PyFloat) or isinstance(target, PyBool)
            or isinstance(target, PyStr) or isinstance(target, PyBytes)
            or isinstance(target, PyTuple) or isinstance(target, PyList)
            or isinstance(target, PyDict) or isinstance(target, PySet)
            or isinstance(target, PyNoneType) {
            tname = "object";
            tn = py_type_of(target);
            if isinstance(tn, PyClass) {
                tname = (tn as PyClass).name;
            }
            return py_error("TypeError", "cannot create weak reference to '" + tname + "' object");
        }
        wr = _jac_make_weakref(target);
        if wr is None {
            return py_error("TypeError", "cannot create weak reference to 'object' object");
        }
        return PyWeakRef(t="weakref", wr=wr);
    }
}

obj PyWeakRef(PyObj) {
    has wr: any;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        raw = _jac_weakref_deref(self.wr);
        if raw is None {
            return py_none();
        }
        # The raw value IS the original PyObj: identity (`r() is o`) holds.
        return raw as PyObj;
    }
}

# Native types.coroutine fast path: mark a generator function's code object
# CO_ITERABLE_COROUTINE (0x100) in place, exactly like CPython mutates
# func.__code__, so GET_AWAITABLE accepts the generators it produces. Callables
# that are not native generator functions pass through unchanged (CPython would
# wrap their returned generators; the VM has no faithful equivalent yet).
obj PyTypesCoroutine(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 1 or len(kwargs) > 0 {
            return py_error("TypeError", "coroutine() expects a callable");
        }
        fn = args[0];
        if isinstance(fn, PyFunction) {
            co = (fn as PyFunction).code;
            if (co.flags & 0x180) == 0 and (co.flags & 32) != 0 {
                co.flags = co.flags | 256;
            }
        }
        return fn;
    }
}

# Facade over the real host `types` module for the proxy import path: every
# public member stays the same host object that direct proxying would serve,
# with coroutine swapped for the native implementation above.
def build_types_facade -> PyObj {
    star: list[PyObj] = [PyStr(t="str", val="*")];
    result = _jac_host_import("types", star);
    attrs: dict[str, PyObj] = {};
    if host_result_ok(result) {
        host_mod = result[1];
        names = _jac_star_names(host_mod);
        if host_result_ok(names) {
            for nm in names[1] {
                member = _jac_host_getattr(host_mod, nm);
                if host_result_ok(member) {
                    attrs[nm] = PyHostProxy(t="host", val=member[1]);
                }
            }
        }
    }
    attrs["coroutine"] = PyTypesCoroutine(t="types_coroutine");
    return PyModule(t="module", name="types", attrs=attrs);
}

def build_weakref_module -> PyObj {
    return PyModule(
        t="module",
        name="weakref",
        attrs={
            "ref": PyWeakRefFn(t="weakref_fn"),
        },
    );
}

# ---- heapq product-path shim ----------------------------------------------
# CPython's heapq.py is pure Python, but served from the host every guest list
# crosses as MUTABLE_COPY: heappush/heapify mutate the copy and the guest's
# heap never changes. These natives run the Lib/heapq.py algorithms over the
# LIVE PyList storage instead (Modules/_heapqmodule.c semantics).

# LT via the shared rich-compare dispatch: guest objects compare with full
# __lt__ semantics. Returns the comparison result or the error to propagate.
def _hq_lt(a: PyObj, b: PyObj) -> PyObj {
    return py_compare(0, a, b);
}

# Error-channel convention for the sift helpers: py_none() on success, any
# error result propagates upward unchanged.
def _hqsift_down(items: list[PyObj], startpos: int, pos: int) -> PyObj {
    newitem: PyObj = items[pos];
    while pos > startpos {
        parentpos = (pos - 1) >> 1;
        parent: PyObj = items[parentpos];
        c = _hq_lt(newitem, parent);
        if is_error(c) {
            return c;
        }
        if not ((c as PyBool).val) {
            break;
        }
        items[pos] = parent;
        pos = parentpos;
    }
    items[pos] = newitem;
    return py_none();
}

def _hqsift_up(items: list[PyObj], pos: int) -> PyObj {
    endpos = len(items);
    startpos = pos;
    newitem: PyObj = items[pos];
    childpos = 2 * pos + 1;
    while childpos < endpos {
        rightpos = childpos + 1;
        if rightpos < endpos {
            c = _hq_lt(items[childpos], items[rightpos]);
            if is_error(c) {
                return c;
            }
            if not ((c as PyBool).val) {
                childpos = rightpos;
            }
        }
        items[pos] = items[childpos];
        pos = childpos;
        childpos = 2 * pos + 1;
    }
    items[pos] = newitem;
    return _hqsift_down(items, startpos, pos);
}

# Shared arity/heap-type gate for all entry points.
def _hq_heap_arg(args: list[PyObj], n: int, fname: str) -> PyList | PyObj {
    if len(args) != n {
        return py_error(
            "TypeError", fname + " expected " + str(n) + " arguments, got " + str(len(args))
        );
    }
    h = args[0];
    if not isinstance(h, PyList) {
        return py_error("TypeError", "heap argument must be a list");
    }
    return h as PyList;
}

obj PyHeapqFn(PyObj) {
    has name: str;

    # Identity hash (builtin-style callable; stdlib stores these in sets).
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="obj:" + str(id(self)));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        n = self.name;
        if n == "heapify" {
            h_r = _hq_heap_arg(args, 1, "heapify");
            if not isinstance(h_r, PyList) {
                return h_r as PyObj;
            }
            items: list[PyObj] = (h_r as PyList).items;
            i = len(items) // 2;
            while i > 0 {
                i = i - 1;
                r = _hqsift_up(items, i);
                if is_error(r) {
                    return r;
                }
            }
            return py_none();
        }
        if n == "heappush" {
            h_r = _hq_heap_arg(args, 2, "heappush");
            if not isinstance(h_r, PyList) {
                return h_r as PyObj;
            }
            items2: list[PyObj] = (h_r as PyList).items;
            items2.append(args[1]);
            return _hqsift_down(items2, 0, len(items2) - 1);
        }
        if n == "heappop" {
            h_r = _hq_heap_arg(args, 1, "heappop");
            if not isinstance(h_r, PyList) {
                return h_r as PyObj;
            }
            items3: list[PyObj] = (h_r as PyList).items;
            lastelt: PyObj = items3[len(items3) - 1];
            items3.pop();
            if len(items3) > 0 {
                returnitem: PyObj = items3[0];
                items3[0] = lastelt;
                r = _hqsift_up(items3, 0);
                if is_error(r) {
                    return r;
                }
                return returnitem;
            }
            return lastelt;
        }
        if n == "heapreplace" {
            h_r = _hq_heap_arg(args, 2, "heapreplace");
            if not isinstance(h_r, PyList) {
                return h_r as PyObj;
            }
            items4: list[PyObj] = (h_r as PyList).items;
            if len(items4) == 0 {
                return py_error("IndexError", "index out of range");
            }
            returnitem2: PyObj = items4[0];
            items4[0] = args[1];
            r2 = _hqsift_up(items4, 0);
            if is_error(r2) {
                return r2;
            }
            return returnitem2;
        }
        if n == "heappushpop" {
            h_r = _hq_heap_arg(args, 2, "heappushpop");
            if not isinstance(h_r, PyList) {
                return h_r as PyObj;
            }
            items5: list[PyObj] = (h_r as PyList).items;
            item: PyObj = args[1];
            if len(items5) == 0 {
                return item;
            }
            c = _hq_lt(items5[0], item);
            if is_error(c) {
                return c;
            }
            if (c as PyBool).val {
                oldtop: PyObj = items5[0];
                items5[0] = item;
                r3 = _hqsift_up(items5, 0);
                if is_error(r3) {
                    return r3;
                }
                return oldtop;
            }
            return item;
        }
        return py_error("AttributeError", "module 'heapq' has no attribute '" + n + "'");
    }
}

def build_heapq_module -> PyObj {
    return PyModule(
        t="module",
        name="heapq",
        attrs={
            "heapify": PyHeapqFn(t="heapq_fn", name="heapify"),
            "heappush": PyHeapqFn(t="heapq_fn", name="heappush"),
            "heappop": PyHeapqFn(t="heapq_fn", name="heappop"),
            "heapreplace": PyHeapqFn(t="heapq_fn", name="heapreplace"),
            "heappushpop": PyHeapqFn(t="heapq_fn", name="heappushpop"),
        },
    );
}

def build_copy_module -> PyObj {
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
    gen_exit = PyException(t="exception", type_name="GeneratorExit", message="");
    result = gen_throw(gen, gen_exit);
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

# Drive one step of `await ag.__anext__()` / `await ag.asend(v)` (genobject.c
# async_gen_asend_send). The awaitable carries the resume value (None for
# __anext__, asend's operand otherwise); a yield unwraps to its payload,
# exhaustion becomes StopAsyncIteration, errors propagate.
def agen_asend_step(a: PyAsyncGenASend, sent: PyObj) -> PyObj {
    if a.started {
        return py_error("RuntimeError", "cannot reuse already awaited __anext__()/asend()");
    }
    a.started = True;
    gen = a.gen;
    if not gen.started and not gen.finished and a.value.t != "none" {
        return py_error(
            "TypeError", "can't send non-None value to a just-started async generator"
        );
    }
    result = gen_resume(gen, a.value);
    return agen_translate(result);
}

# Drive one step of `await ag.athrow(exc)` / `await ag.aclose()` (genobject.c
# async_gen_athrow_send). athrow: a caught exception followed by another yield
# surfaces that yield; a clean return raises StopAsyncIteration; throwing into
# an ALREADY-EXHAUSTED generator completes silently (CPython 3.14 quirk).
# aclose runs the GeneratorExit protocol and never raises on a clean exit.
def agen_athrow_step(a: PyAsyncGenAThrow, sent: PyObj) -> PyObj {
    if a.started {
        return py_error("RuntimeError", "cannot reuse already awaited aclose()/athrow()");
    }
    a.started = True;
    gen = a.gen;
    if a.aclose {
        if gen.finished or not gen.started {
            gen.finished = True;
            frame_clear(gen.frame);
            return PyGenStop(t="genstop", val=py_none());
        }
        gen_exit = PyException(t="exception", type_name="GeneratorExit", message="");
        result = gen_throw(gen, gen_exit);
        gen.finished = True;
        frame_clear(gen.frame);
        if is_error(result) {
            if ((result as PyError).exception).type_name == "GeneratorExit" {
                # GeneratorExit propagating out is a clean close.
                return PyGenStop(t="genstop", val=py_none());
            }
            return result;
        }
        if result.t == "async_wrapped" {
            return py_error("RuntimeError", "async generator ignored GeneratorExit");
        }
        # Caught GeneratorExit and returned: clean close, value dropped.
        return PyGenStop(t="genstop", val=py_none());
    }
    if gen.finished {
        # Nothing left to throw into; CPython drops the resume outcome.
        return PyGenStop(t="genstop", val=py_none());
    }
    result2 = gen_throw(gen, a.err);
    return agen_translate(result2);
}

# Shared translation of an async-generator resume outcome into the awaitable
# protocol. One drive IS one complete await: a yield finishes the asend/anext
# coroutine with the UNWRAPPED payload (PyGenStop makes the SEND loop treat it
# like a coroutine return), while normal exhaustion raises StopAsyncIteration.
def agen_translate(result: PyObj) -> PyObj {
    if is_error(result) {
        return result;
    }
    if result.t == "async_wrapped" {
        return PyGenStop(t="genstop", val=(result as PyAsyncGenWrappedValue).val);
    }
    return PyError(
        t="error",
        exception=PyException(t="exception", type_name="StopAsyncIteration", message=""),
    );
}

# Drive one step of a yield-from sub-iterator (SEND). Returns the yielded value,
# a PyGenStop(return value) on exhaustion, or a propagating error.
def send_into(receiver: PyObj, sent: PyObj) -> PyObj {
    # Async-generator awaitables (from __anext__/asend/athrow/aclose) drive
    # through their own step functions; the SEND loop awaits them like any
    # other awaitable.
    if receiver.t == "agen_asend" {
        return agen_asend_step(receiver as PyAsyncGenASend, sent);
    }
    if receiver.t == "agen_athrow" {
        return agen_athrow_step(receiver as PyAsyncGenAThrow, sent);
    }
    # A native coroutine drives through the identical suspend/resume machinery as
    # a generator -- `await` lowers to the same SEND loop `yield from` uses.
    if receiver.t == "generator" or receiver.t == "coroutine" {
        return gen_resume(receiver as PyGenerator, sent);
    }
    if receiver.t == "calliter" {
        # next(calliter) drives the callable-iterator; send() is not a
        # calliterobject method (CPython raises AttributeError).
        if sent.t != "none" {
            return py_error("AttributeError", "send");
        }
        return calliter_next(receiver as PyCallableIter);
    }
    if receiver.t == "seqiter" {
        # next(seqiter) drives the old-style sequence iterator; same no-send
        # rule as the callable-iterator.
        if sent.t != "none" {
            return py_error("AttributeError", "send");
        }
        return seqiter_next(receiver as PySeqIter);
    }
    if receiver.t == "rangeiter" {
        ri = receiver as PyRangeIter;
        if sent.t != "none" {
            return py_error("AttributeError", "send");
        }
        if ri.remaining > 0 {
            ritem = PyInt(t="int", val=ri.cur);
            ri.cur = ri.cur + ri.step;
            ri.remaining = ri.remaining - 1;
            return ritem;
        }
        return PyGenStop(t="genstop", val=py_none());
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
    # Any other iterator: drive it through its own send/__next__ surface. An
    # object exposing send() -- notably a host coroutine/proxy driven after
    # GET_AWAITABLE resolved it directly -- MUST be resumed with send(None);
    # only bare iterators without send fall back to __next__.
    method_name = "send";
    if py_attr(receiver, "send").t == "error" {
        method_name = "__next__";
    }
    if is_error(py_attr(receiver, method_name)) {
        return py_error("TypeError", "object can't be sent");
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
        if exc_is_stopiter(exc) {
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
    kwdefaults: dict[str, PyObj]
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
            (fast[varkw_slot] as PyDict).dict_set(PyStr(t="str", val=key), kwargs[key]);
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

    # Extend the varname region into the full merged localsplus: cellvars that
    # share a varname slot convert that slot in place to a cell wrapping the
    # already-bound argument/local value (the runtime effect of the prologue
    # MAKE_CELLs); remaining cellvars append their cells in cellvar order, then
    # the freevar (closure) cells append -- CPython's exact layout.
    ci = 0;
    while ci < len(co.cellvars) {
        fast_index = find_name(co.varnames, co.cellvars[ci]);
        if fast_index >= 0 {
            # In-place conversion of an already-bound varname slot (the runtime
            # effect of the prologue MAKE_CELLs): boundness carries over.
            fast[fast_index] = PyCell(t="cell", val=fast[fast_index], filled=assigned[fast_index]);
        } else {
            newcell = PyCell(t="cell", val=py_none());
            fast.append(newcell);
        }
        ci = ci + 1;
    }
    fi = 0;
    while fi < len(closure) {
        fast.append(closure[fi] as PyObj);
        fi = fi + 1;
    }
    # The bound-tracking flags cover the FULL merged localsplus (a cell-targeted
    # comprehension's tail STORE_FAST restore addresses appended slots too).
    while len(assigned) < len(fast) {
        assigned.append(False);
    }
    frame = PyFrame(
        t="frame",
        co=co,
        fast=fast,
        assigned=assigned,
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
    # CO_ASYNC_GENERATOR (0x200): `async def` with `yield`. Calling it creates a
    # LAZY async generator -- no frame execution until __anext__/asend/athrow/
    # aclose drive it through the agen_* awaitables (genobject.c
    # PyAsyncGenObject_New with an unstarted frame).
    if (co.flags & 512) != 0 {
        return PyGenerator(t="async_generator", frame=frame, started=False, finished=False);
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
    closure = frame.closure;
    stack = frame.stack;
    globals = frame.globals;
    locals = frame.locals;
    code = co.co_code;
    ip = frame.ip;
    ext_arg = 0;
    # The stack of exceptions currently being handled (one entry per active except
    # block). A bare `raise` re-raises the top; PUSH_EXCEPT_INFO pushes on handler
    # entry, POP_EXCEPT pops on handler exit. A generator suspended inside an
    # except block carries the stack across the yield via frame.exc_state, so a
    # bare raise after resuming still names the exception being handled.
    exc_handling: list[PyObj] = [];
    if frame.exc_state is not None {
        exc_handling = frame.exc_state as list[PyObj];
        _handled_stack_append_each(exc_handling);
    }
    # Polymorphic opcode scratch slots: handlers below store PyObj values (and
    # occasionally the narrower PyStr/PyException subtypes) here, so they are
    # declared once up front instead of being pinned to a first-use type.
    result: PyObj = py_none();
    exc: PyObj = py_none();
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
            fast_result = fast_value(co, arg, fast);
            if is_error(fast_result) {
                return fast_result;
            }
            stack.append(fast_result);
            continue;
        }
        if op == OP_LOAD_FAST_CHECK {
            fast_result = fast_value_check(co, arg, fast, assigned);
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
            # clear the slot; a STORE_FAST at the tail restores it. The saved
            # entry is the slot's contents WHOLESALE: for a converted (cell)
            # slot that is the old cell itself, so save/restore also undoes a
            # mid-frame MAKE_CELL exactly like CPython's GETLOCAL/SETLOCAL.
            # NULL (an unbound slot) is modeled with the None placeholder.
            if arg < len(fast) {
                stack.append(fast[arg]);
                fast[arg] = py_none();
            } else {
                stack.append(py_none());
            }
            if arg < len(assigned) {
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
            load_result = fast_value(co, load_index, fast);
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
        if op == OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW or op == OP_LOAD_FAST_LOAD_FAST {
            first = arg // 16;
            second = arg % 16;
            first_result = fast_value(co, first, fast);
            second_result = fast_value(co, second, fast);
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
                value = load_name_fallback(name);
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
                value = load_name_fallback(name);
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
            cell = resolve_cell(fast, arg);
            if cell is None {
                return py_error("NameError", "free variable is not set");
            }
            # An empty cell is distinct from a None binding: emptiness lives on
            # the shared cell object (CPython's cell-NULL check), not the slot.
            if not cell.filled {
                err = format_exc_unbound(co, arg);
                target = recover_exception(co, err, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return err;
            }
            stack.append(cell.val);
            continue;
        }
        if op == OP_LOAD_CLOSURE {
            cell = resolve_cell(fast, arg);
            if cell is None {
                return py_error("NameError", "free variable is not set");
            }
            stack.append(cell);
            continue;
        }
        if op == OP_LOAD_FROM_DICT_OR_DEREF {
            # CPython TARGET(LOAD_FROM_DICT_OR_DEREF) (generated_cases.c.h):
            # pop the mapping pushed by LOAD_LOCALS (class namespace), look up
            # the localsplus name; on a miss deref the cell in slot `arg`, and
            # raise the exact unbound error when that is empty too.
            mapping = stack.pop();
            lpname = localsplus_name(co, arg);
            keyname = PyStr(t="str", val=lpname);
            value = py_none();
            hit = False;
            if isinstance(mapping, PyDict) {
                dmap = mapping as PyDict;
                if dmap.dict_contains(keyname) {
                    value = dmap.mp_subscript(keyname);
                    hit = True;
                }
            } else {
                got = mapping.mp_subscript(keyname);
                if is_error(got) {
                    if ((got as PyError).exception.type_name != "KeyError") {
                        target = recover_exception(co, got, offset, stack);
                        if target >= 0 {
                            ip = target;
                            continue;
                        }
                        return got;
                    }
                } else {
                    value = got;
                    hit = True;
                }
            }
            if not hit {
                cell = resolve_cell(fast, arg);
                if cell is None or not cell.filled {
                    err = format_exc_unbound(co, arg);
                    target = recover_exception(co, err, offset, stack);
                    if target >= 0 {
                        ip = target;
                        continue;
                    }
                    return err;
                }
                value = cell.val;
            }
            stack.append(value);
            continue;
        }
        if op == OP_LOAD_FROM_DICT_OR_GLOBALS {
            # CPython TARGET(LOAD_FROM_DICT_OR_GLOBALS): pop the module-or-class
            # dict, look up co_names[arg]; on a miss fall back to globals then
            # builtins; still missing -> NAME_ERROR_MSG byte-exact.
            mapping = stack.pop();
            gname = co.names[arg];
            keyname = PyStr(t="str", val=gname);
            value = py_none();
            hit = False;
            if isinstance(mapping, PyDict) {
                dmap = mapping as PyDict;
                if dmap.dict_contains(keyname) {
                    value = dmap.mp_subscript(keyname);
                    hit = True;
                }
            } else {
                got = mapping.mp_subscript(keyname);
                if is_error(got) {
                    if ((got as PyError).exception.type_name != "KeyError") {
                        target = recover_exception(co, got, offset, stack);
                        if target >= 0 {
                            ip = target;
                            continue;
                        }
                        return got;
                    }
                } else {
                    value = got;
                    hit = True;
                }
            }
            if not hit {
                if gname in globals {
                    value = globals[gname];
                } else {
                    value = load_name_fallback(gname);
                    if is_error(value) {
                        target = recover_exception(co, value, offset, stack);
                        if target >= 0 {
                            ip = target;
                            continue;
                        }
                        return value;
                    }
                }
            }
            stack.append(value);
            continue;
        }
        if op == OP_STORE_DEREF {
            value = stack.pop();
            cell = resolve_cell(fast, arg);
            if cell is None {
                return py_error("NameError", "free variable is not set");
            }
            cell.val = value;
            cell.filled = True;
            continue;
        }
        if op == OP_DELETE_DEREF {
            # CPython TARGET(DELETE_DEREF): unset the shared cell so later
            # LOAD_DEREFs see the exact unbound error; deleting an already
            # empty cell is the same unbound error, not a silent no-op.
            cell = resolve_cell(fast, arg);
            if cell is None {
                return py_error("NameError", "free variable is not set");
            }
            if not cell.filled {
                err = format_exc_unbound(co, arg);
                target = recover_exception(co, err, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return err;
            }
            cell.val = py_none();
            cell.filled = False;
            continue;
        }
        if op == OP_MAKE_CELL {
            # Dynamic slot conversion (CPython _PyFrame_MakeAndSetCell): wrap
            # the slot's current value in a fresh cell. Subsequent *_DEREF ops
            # and closure captures go through that cell while plain *_FAST ops
            # keep addressing the slot wholesale -- which is also how a tail
            # STORE_FAST un-converts it after an inlined comprehension. Each
            # comprehension execution mints a NEW cell per loop var, so lambda
            # sets captured by earlier comprehensions keep their own cells.
            # Idempotent on already-converted slots (prologue MAKE_CELLs).
            if arg < len(fast) and not isinstance(fast[arg], PyCell) {
                # A None slot is the VM's unset placeholder (LOAD_FAST_AND_CLEAR
                # nulls the slot before comprehension conversions); anything else
                # was genuinely bound and stays readable through the cell.
                fast[arg] = PyCell(
                    t="cell",
                    val=fast[arg],
                    filled=(not isinstance(fast[arg], PyNoneType)),
                );
            }
            continue;
        }
        if op == OP_COPY_FREE_VARS {
            # No-op: frame setup already placed the closure cells in the
            # appended freevar region of the merged localsplus.
            continue;
        }
        if op == OP_LOAD_LOCALS {
            stack.append(dict_from_str_map(locals));
            continue;
        }
        if op == OP_SETUP_ANNOTATIONS {
            # CPython SETUP_ANNOTATIONS: bind an empty __annotations__ dict in
            # the frame namespace when absent (module/class annotation setup).
            if "__annotations__" not in locals {
                locals["__annotations__"] = PyDict(t="dict", items={});
            }
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
            gdeleted = py_error("NameError", "name '" + gdel_name + "' is not defined");
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
                # Closure seeding: elements are already live cells (captured via
                # LOAD_FAST_BORROW/LOAD_CLOSURE on converted localsplus slots);
                # any raw value gets boxed in a fresh cell.
                function.closure = [];
                for item in tuple_value(attribute) {
                    if item.t == "cell" {
                        function.closure.append(item as PyCell);
                    } else {
                        function.closure.append(PyCell(t="cell", val=item, filled=True));
                    }
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
                if is_error(popped[j * 2].tp_hashkey()) {
                    any_unhashable = True;
                }
                j = j + 1;
            }
            if any_unhashable {
                # CPython raises TypeError naming the offending key's type.
                # Known-unhashable natives must RAISE here, not degrade: the
                # old opaque-host-map fallback let the host dict's raw
                # exception ESCAPE exec_code's PyError channel (TODO item 26).
                # Shapes that are merely not-yet-natively-hashed (e.g. slice,
                # hashable in CPython) keep the opaque-host fallback so their
                # behavior is unchanged.
                bm_err: PyObj = py_none();
                j = 0;
                while j < arg {
                    keyobj = popped[j * 2];
                    if keyobj.t == "list" or keyobj.t == "dict" or keyobj.t == "set" {
                        bm_err = py_error(
                            "TypeError", "unhashable type: '" + keyobj.t + "'"
                        );
                        break;
                    }
                    j = j + 1;
                }
                if bm_err.t == "error" {
                    # Route through frame unwinding so guest try/except handlers
                    # can catch the display-literal raise (TODO item 26 residual:
                    # a bare return bypassed handler dispatch).
                    target = recover_exception(co, bm_err, offset, stack);
                    if target >= 0 {
                        ip = target;
                        continue;
                    }
                    return bm_err;
                }
                host_map: dict[any, any] = {};
                j = 0;
                while j < arg {
                    hk_r = to_host_coerce(popped[j * 2]);
                    hk = hk_r[1];
                    if not ((hk_r[0] as bool)) {
                        return hk_r[1] as PyObj;
                    }
                    hv2_r = to_host_coerce(popped[j * 2 + 1]);
                    hv2 = hv2_r[1];
                    if not ((hv2_r[0] as bool)) {
                        return hv2_r[1] as PyObj;
                    }
                    host_map[hk] = hv2;
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
            # Same discipline as LIST_EXTEND above: drain through the guest
            # iterator machinery so non-iterables raise a CATCHABLE TypeError
            # ('int' object is not iterable) instead of escaping host-side and
            # killing the VM mid-set-display ({1, *1, 0, 4}).
            iterable = stack.pop();
            target_index = len(stack) - arg;
            target_set: PySet = stack[target_index] as PySet;
            set_drained = iter_drain(iterable);
            if is_error(set_drained) {
                target = recover_exception(co, set_drained, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return set_drained;
            }
            for hostel in (set_drained as PyList).items {
                target_set.set_add(hostel);
            }
            continue;
        }
        if op == OP_CONVERT_VALUE {
            value = stack.pop();
            if isinstance(value, PyException) {
                exc = value as PyException;
                if arg == 2 {
                    result = baseexception_repr(exc, py_repr);
                } elif arg == 3 {
                    # CONVERT_VALUE oparg 3 is ascii() (1=str, 2=repr, 3=ascii
                    # in CPython 3.14 bytecode). The non-ASCII escaping half
                    # of ascii() stays host-only, so delegate -- the caught
                    # exception marshals to a REAL host instance
                    # (to_host -> host_exception), keeping repr content and
                    # byte-exact escaping. Treating 3 as a str form here made
                    # f"{e!a}" print the plain message (5967ea874 regression).
                    result = host_convert(value, 3);
                } else {
                    # Host-RAISED exceptions carry their live HOST instance in
                    # `raw` (a PyHostProxy): its host str is byte-exact by
                    # construction and beats any native reconstruction from
                    # (possibly lossy) args. Guest user-exception instances
                    # also keep their instance in `raw` (a PyUserObj) but the
                    # native per-type dispatch is authoritative there -- the
                    # host-side mirror class has no builtin __str__ ancestry.
                    if exc.raw is not None and isinstance(exc.raw, PyHostProxy) {
                        result = host_convert(exc.raw as PyObj, 1);
                    } else {
                        # str-form conversion stays native so the per-type __str__
                        # overrides (OSError smart forms, KeyError repr-form,
                        # SyntaxError suffixes) apply to natively constructed
                        # instances instead of a lossy host reconstruction.
                        result = baseexception_str(exc, py_repr, py_str);
                    }
                }
            } else {
                result = host_convert(value, arg);
            }
            if is_error(result) {
                # A guest __format__/__str__/__repr__ raising during conversion
                # must dispatch to a same-frame handler.
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
        if op == OP_FORMAT_SIMPLE {
            value = stack.pop();
            result = host_format(value, "");
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
        if op == OP_FORMAT_WITH_SPEC {
            spec = stack.pop();
            value = stack.pop();
            result = host_format(value, expect_str(spec));
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
            ext_res = append_to_list(stack[target_index], iterable);
            if is_error(ext_res) {
                target = recover_exception(co, ext_res, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return ext_res;
            }
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
            update_view = dict_mapping_pairs(update_source, False);
            if is_error(update_view) {
                target = recover_exception(co, update_view, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return update_view;
            }
            update_pairs = update_view as PyDict;
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
            # Unlike DICT_UPDATE, a non-str key is a TypeError ("keywords must
            # be strings") and a duplicate key is a TypeError (a keyword passed
            # more than once). Both fire at FIRST offending key in iteration
            # order, matching _PyDict_MergeEx's ordered override=2 walk.
            merge_source: PyObj = stack.pop();
            # Stack effect (CPython): (callable, unused, unused, dict,
            # unused[oparg-1], update). After popping `update`, the target dict
            # sits `oparg` slots below the top.
            target_index = len(stack) - arg;
            merge_target = stack[target_index] as PyDict;
            merge_view = dict_mapping_pairs(merge_source, True);
            if is_error(merge_view) {
                target = recover_exception(co, merge_view, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return merge_view;
            }
            merge_pairs = merge_view as PyDict;
            mkeys = merge_pairs.dict_keys();
            mvals = merge_pairs.dict_values();
            mj = 0;
            while mj < len(mkeys) {
                if not isinstance(mkeys[mj], PyStr) {
                    merge_err = py_error("TypeError", "keywords must be strings");
                    target = recover_exception(co, merge_err, offset, stack);
                    if target >= 0 {
                        ip = target;
                        mj = len(mkeys);
                        continue;
                    }
                    return merge_err;
                }
                if merge_target.dict_contains(mkeys[mj]) {
                    merge_err = py_error(
                        "TypeError",
                        "got multiple values for keyword argument '"
                            + expect_str(mkeys[mj]) + "'",
                    );
                    target = recover_exception(co, merge_err, offset, stack);
                    if target >= 0 {
                        ip = target;
                        mj = len(mkeys);
                        continue;
                    }
                    return merge_err;
                }
                merge_target.dict_set(mkeys[mj], mvals[mj]);
                mj = mj + 1;
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
            # Uniform drain across every iterator shape send_into serves
            # (materialized iters, generators/coroutines, calliter/seqiter/
            # rangeiter): the old shape-dispatch silently produced an empty
            # unpack for rangeiter/seqiter/calliter.
            unpacked: list[PyObj] = [];
            drain_failed = False;
            while True {
                nxt = send_into(it, py_none());
                if is_error(nxt) {
                    # Drain error (guest raise inside the iterator) must
                    # dispatch to a same-frame handler.
                    target = recover_exception(co, nxt, offset, stack);
                    if target >= 0 {
                        ip = target;
                        drain_failed = True;
                    } else {
                        return nxt;
                    }
                    break;
                }
                if nxt.t == "genstop" {
                    break;
                }
                unpacked.append(nxt);
            }
            if drain_failed {
                continue;
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
        if op == OP_UNPACK_EX {
            # oparg = before | (after << 8); a starred target captures the middle.
            before = arg % 256;
            after = arg // 256;
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
            # Uniform drain across every iterator shape send_into serves
            # (materialized iters, generators/coroutines, calliter/seqiter/
            # rangeiter): the old shape-dispatch silently produced an empty
            # unpack for rangeiter/seqiter/calliter.
            unpacked = [];
            drain_failed = False;
            while True {
                nxt = send_into(it, py_none());
                if is_error(nxt) {
                    # Same-frame dispatch for the drain error.
                    target = recover_exception(co, nxt, offset, stack);
                    if target >= 0 {
                        ip = target;
                        drain_failed = True;
                    } else {
                        return nxt;
                    }
                    break;
                }
                if nxt.t == "genstop" {
                    break;
                }
                unpacked.append(nxt);
            }
            if drain_failed {
                continue;
            }
            m = len(unpacked);
            if m < before + after {
                ex_err = py_error(
                    "ValueError",
                    "not enough values to unpack (expected at least "
                        + str(before + after)
                        + ", got "
                        + str(m)
                        + ")",
                );
                target = recover_exception(co, ex_err, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return ex_err;
            }
            # Stack top->bottom must be: head[0..before-1], middle-list,
            # tail[m-after..m-1]. Push tail deepest-first, then middle, then head.
            j = m - 1;
            while j >= m - after {
                stack.append(unpacked[j]);
                j = j - 1;
            }
            middle_items: list[PyObj] = [];
            mk = before;
            while mk < m - after {
                middle_items.append(unpacked[mk]);
                mk = mk + 1;
            }
            stack.append(PyList(t="list", items=middle_items));
            b = before - 1;
            while b >= 0 {
                stack.append(unpacked[b]);
                b = b - 1;
            }
            continue;
        }
        if op == OP_GET_LEN {
            len_obj = stack[len(stack) - 1];
            len_res = py_len(len_obj);
            if is_error(len_res) {
                target = recover_exception(co, len_res, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return len_res;
            }
            stack.append(len_res);
            continue;
        }
        if op == OP_MATCH_SEQUENCE {
            seq_subject = stack[len(stack) - 1];
            stack.append(PyBool(t="bool", val=py_type_has_sequence_flag(seq_subject)));
            continue;
        }
        if op == OP_MATCH_MAPPING {
            map_subject = stack[len(stack) - 1];
            stack.append(PyBool(t="bool", val=py_type_has_mapping_flag(map_subject)));
            continue;
        }
        if op == OP_MATCH_KEYS {
            mk_keys = stack[len(stack) - 1];
            mk_subject = stack[len(stack) - 2];
            mk_res = py_match_keys(mk_subject, mk_keys);
            if is_error(mk_res) {
                target = recover_exception(co, mk_res, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return mk_res;
            }
            stack.append(mk_res);
            continue;
        }
        if op == OP_MATCH_CLASS {
            mc_names = stack.pop();
            mc_type = stack.pop();
            mc_subject = stack.pop();
            mc_res = py_match_class(mc_subject, mc_type, arg, mc_names);
            if is_error(mc_res) {
                target = recover_exception(co, mc_res, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return mc_res;
            }
            stack.append(mc_res);
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
            top = stack[len(stack) - 1];
            awaitable = py_get_awaitable(top);
            if is_error(awaitable) {
                target = recover_exception(co, awaitable, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return awaitable;
            }
            stack[len(stack) - 1] = awaitable;
            continue;
        }
        if op == OP_GET_AITER {
            iterable = stack.pop();
            aiter = py_aiter(iterable);
            if is_error(aiter) {
                target = recover_exception(co, aiter, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return aiter;
            }
            stack.append(aiter);
            continue;
        }
        if op == OP_GET_ANEXT {
            aiter = stack[len(stack) - 1];
            awaitable = py_anext(aiter);
            if is_error(awaitable) {
                target = recover_exception(co, awaitable, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return awaitable;
            }
            stack.append(awaitable);
            continue;
        }
        if op == OP_END_ASYNC_FOR {
            # Async-for cleanup: [..., aiter, exc]. StopAsyncIteration ends the
            # loop (pop both, jump past the body); anything else re-raises.
            exc = stack.pop();
            stack.pop();
            exc_name = "";
            if exc.t == "exception" {
                exc_name = (exc as PyException).type_name;
            }
            if exc_name == "StopAsyncIteration" {
                continue;
            }
            reraised = py_raise_value(exc);
            # This is a RERAISE-class event (the error entry for main was
            # already appended when the awaited __anext__ failed): growing the
            # traceback here duplicated main's frame (main|main|agen vs host
            # main|agen). Route through dispatch like every other reraise.
            target = dispatch_exception(co, reraised, offset, offset, stack);
            if target >= 0 {
                ip = target;
                continue;
            }
            return reraised;
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
            # A StopIteration (or subclass) means the sub-iterator finished
            # handling the throw: unwind to (None, value) and loop to END_SEND.
            if exc_name == "StopIteration"
                or ((exc as PyException).family != ""
                and exc_name_matches((exc as PyException).family, "StopIteration")) {
                payload = py_none();
                if (exc as PyException).value is not None {
                    payload = (exc as PyException).value as PyObj;
                }
                stack.append(py_none());
                stack.append(payload);
                continue;
            }
            # Non-StopIteration: re-dispatch the exception out of the yield-from
            # (CPython CLEANUP_THROW -> exit_unwind). A re-dispatch is not an
            # error event, so no traceback entry is added here -- the entry for
            # this frame was already laid down at the failing SEND/error site;
            # grow-free handler search keeps the cadence at one per frame.
            reraised = py_raise_value(exc);
            target = dispatch_exception(co, reraised, offset, offset, stack);
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
            if top.t == "rangeiter" {
                nxt = send_into(top, py_none());
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
            if top.t == "calliter" {
                nxt = calliter_next(top as PyCallableIter);
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
            if top.t == "seqiter" {
                nxt = seqiter_next(top as PySeqIter);
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
            if isinstance(top, PyUserObj)
                and user_has_dunder(top as PyUserObj, "__next__") {
                # User-defined iterator (class-iterator idiom): FOR_ITER drives
                # tp_iternext == guest __next__; StopIteration pops the loop.
                nxt = call_user_dunder(top as PyUserObj, "__next__", []);
                if is_error(nxt) {
                    # tp_iternext contract: StopIteration OR ANY SUBCLASS ends
                    # the loop (matched by type, not exact name); anything else
                    # propagates through handler dispatch.
                    if error_is_stopiteration(nxt) {
                        stack.pop();
                        ip = ip + 2 * arg;
                    } else {
                        target = recover_exception(co, nxt, offset, stack);
                        if target >= 0 {
                            ip = target;
                        } else {
                            return nxt;
                        }
                    }
                } else {
                    stack.append(nxt);
                }
                continue;
            }
            # Generic tail: drive ANY remaining iterator shape through
            # send_into (native iters, dict/range iterators, user objects whose
            # __next__ only resolves through the full attribute path). The old
            # unconditional PyIter downcast VM-crashed on those user shapes.
            nxt = send_into(top, py_none());
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
            if op == OP_POP_JUMP_IF_FALSE or op == OP_POP_JUMP_IF_TRUE {
                # Implicit-truth slot with a real error channel: a raising
                # __bool__/__len__ propagates like CPython's PyObject_IsTrue.
                truth = py_slot_truth(condition);
                if is_error(truth) {
                    target = recover_exception(co, truth, offset, stack);
                    if target >= 0 {
                        ip = target;
                        continue;
                    }
                    return truth;
                }
                jump = (truth as PyBool).val;
                if op == OP_POP_JUMP_IF_FALSE {
                    jump = not jump;
                }
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
            operand = stack.pop();
            truth = py_slot_truth(operand);
            if is_error(truth) {
                target = recover_exception(co, truth, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return truth;
            }
            stack.append(PyBool(t="bool", val=not (truth as PyBool).val));
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
            # CPython super_getattro applies the descriptor protocol to what
            # the MRO walk found: a property getter fires against the live
            # instance, a function binds to it, a classmethod binds its class.
            bound = descriptor_get(result, super_self, super_self);
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
        if op == OP_STORE_SLICE {
            # container[start:stop] = value -- CPython _STORE_SLICE: the value
            # sits under (container, start, stop) on the stack and step is
            # always None (the stepped form lowers to BUILD_SLICE +
            # STORE_SUBSCR). Assignment runs through the same slot-based
            # protocol as STORE_SUBSCR with a slice key.
            slice_stop = stack.pop();
            slice_start = stack.pop();
            slice_container = stack.pop();
            slice_value = stack.pop();
            result = py_store_subscript(
                slice_container,
                PySlice(t="slice", start=slice_start, stop=slice_stop, step=py_none()),
                slice_value
            );
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
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
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
            result = py_none();
            if layer3_is_active() {
                import_level = 0;
                if isinstance(level_obj, PyInt) {
                    import_level = (level_obj as PyInt).val;
                }
                result = py_import_name(co.names[arg], fromlist, import_level, globals);
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
                # CPython's import_from converts a bare AttributeError into
                # "ImportError: cannot import name 'x' from 'mod' (__file__)"
                # -- every other error propagates unchanged.
                exc = (result as PyError).exception;
                if exc.type_name == "AttributeError" {
                    modname = "<unknown>";
                    nmobj = py_attr(module, "__name__");
                    if not is_error(nmobj) and isinstance(nmobj, PyStr) {
                        modname = (nmobj as PyStr).val;
                    }
                    origin = "";
                    fileobj = py_attr(module, "__file__");
                    if not is_error(fileobj) and isinstance(fileobj, PyStr) {
                        origin = (fileobj as PyStr).val;
                    }
                    if origin != "" {
                        result = py_error(
                            "ImportError",
                            "cannot import name '" + co.names[arg] + "' from '"
                                + modname + "' (" + origin + ")"
                        );
                    } else {
                        result = py_error(
                            "ImportError",
                            "cannot import name '" + co.names[arg] + "' from '"
                                + modname + "'"
                        );
                    }
                }
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
            if fn.t == "native_builtin" and (fn as PyNativeBuiltin).name == "globals" {
                stack.append(PyGlobalsProxy(t="globals", ns=globals));
                continue;
            }
            # No-arg dir() answers sorted locals of the CALLING frame -- CPython
            # reads f_locals of its caller, and only this site knows that frame
            # state. Module-level frames pass globals AS locals (exec_code_frame),
            # so a bare dir() at module top level lists module globals, exactly
            # like CPython. Bound localsplus slots join dict-locals keys; a cell
            # slot counts only while filled.
            if fn.t == "native_builtin" and (fn as PyNativeBuiltin).name == "dir"
                and self_or_null.t == "none" and len(call_args) == 0
                and len(kwargs_for_call) == 0 {
                local_names: dict[str, bool] = {};
                for k in locals {
                    local_names[k] = True;
                }
                si = 0;
                while si < len(fast) {
                    bound = False;
                    if isinstance(fast[si], PyCell) {
                        if ((fast[si] as PyCell).filled) {
                            bound = True;
                        }
                    } elif si < len(assigned) and assigned[si] {
                        bound = True;
                    }
                    if bound {
                        local_names[localsplus_name(co, si)] = True;
                    }
                    si = si + 1;
                }
                stack.append(py_dir_sorted(local_names));
                continue;
            }
            # exec() must run IN the VM against the LIVE namespace dicts -- see
            # builtin_exec below. Only this call site holds the running frame's
            # globals/locals for the one-argument form.
            if fn.t == "native_builtin" and (fn as PyNativeBuiltin).name == "exec" {
                result = builtin_exec(call_args, kwargs_for_call, globals, locals);
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
                # members_of TypeError (non-iterable *args) must dispatch to a
                # same-frame handler.
                target = recover_exception(co, ex_args_list, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
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
                hkw_r = to_host_coerce(kwargs_obj);
                hkw = hkw_r[1];
                if not ((hkw_r[0] as bool)) {
                    return hkw_r[1] as PyObj;
                }
                coerced = from_host(hkw);
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
                _handled_exc_stack.append(exception);
            }
            continue;
        }
        if op == OP_CHECK_EG_MATCH {
            # except* matching -- CPython CHECK_EG_MATCH: validate the caught
            # class (_PyEval_CheckExceptStarTypeValid), then split the active
            # exception against it (_PyEval_ExceptionGroupMatch). The stack
            # becomes (rest, match) with match on top; None means "nothing
            # matched". Setting the matched group as the handled exception
            # (SetHandledException) belongs to the PREP_RERAISE_STAR lane.
            eg_target = stack.pop();
            eg_exc = stack.pop();
            invalid = eg_validate_star_target(eg_target);
            if not is_error(invalid) {
                pair = exception_group_split(eg_exc, eg_target);
                if is_error(pair[0]) {
                    invalid = pair[0];
                } else {
                    stack.append(pair[0]);
                    stack.append(pair[1]);
                    continue;
                }
            }
            target = recover_exception(co, invalid, offset, stack);
            if target >= 0 {
                ip = target;
                continue;
            }
            return invalid;
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
            if len(_handled_exc_stack) > 0 {
                _handled_exc_stack.pop();
            }
            continue;
        }
        if op == OP_RAISE_VARARGS {
            # arg: 0 = re-raise, 1 = raise exc, 2 = raise exc from cause. For the
            # `from` form the cause is on top, the exception below it.
            raised = py_none();
            raise_cause: PyObj = py_none();
            if arg == 2 {
                raise_cause = stack.pop();
                raised = stack.pop();
            } elif arg == 1 {
                raised = stack.pop();
            } elif len(exc_handling) > 0 {
                # Bare `raise`: re-raise the exception currently being handled.
                raised = exc_handling[len(exc_handling) - 1];
            }
            if arg == 0 and raised.t == "none" {
                # CPython bare `raise` outside any handler is RuntimeError
                # (PyErr_GetReraised), not the generic not-an-exception TypeError.
                result = py_error("RuntimeError", "No active exception to re-raise");
            } else {
                result = py_raise_value(raised);
            }
            # Implicit chaining (CPython PyErr_SetObject): raising while another
            # exception is being handled records the handled one as the new
            # exception's __context__ -- unless the raised object IS that
            # exception (bare re-raise keeps its existing chain) or a context
            # is already recorded. Applies to `raise X from Y` too: cause and
            # context are independent fields there.
            if len(exc_handling) > 0 {
                handled_exc = exc_handling[len(exc_handling) - 1];
                if (
                    isinstance(result, PyError)
                    and not (handled_exc is raised)
                    and (result as PyError).exception.context is None
                ) {
                    if handled_exc.t == "exception" {
                        (result as PyError).exception.context = (
                            handled_exc as PyException
                        );
                    } elif isinstance(handled_exc, PyUserObj) {
                        (result as PyError).exception.context = handled_exc;
                    }
                }
            }
            # `raise X from Y`: record Y on the raised exception so e.__cause__
            # reads it back. `from None` carries no cause object but still sets
            # __suppress_context__ (CPython PyErr_SetCause semantics).
            if arg == 2 and isinstance(result, PyError) {
                if raise_cause.t != "none" {
                    cause_err = py_raise_value(raise_cause);
                    if isinstance(cause_err, PyError) {
                        cause_exc = (cause_err as PyError).exception;
                        (result as PyError).exception.cause = cause_exc;
                        # PyErr_SetCause: a real cause implies __suppress_context__.
                        (result as PyError).exception.suppress_context = PyBool(
                            t="bool", val=True
                        );
                    }
                } else {
                    (result as PyError).exception.suppress_context = PyBool(
                        t="bool", val=True
                    );
                }
            }
            # Bare `raise` (arg == 0) re-dispatches an existing exception:
            # CPython routes RAISE_VARARGS 0 straight to exception_unwind, so
            # no new traceback entry (dispatch_exception). A fresh raise
            # (arg 1/2) or the RuntimeError fallback for a bare raise with no
            # active exception is a real error event: recover_exception adds
            # the entry.
            if arg == 0 and raised.t != "none" {
                target = dispatch_exception(co, result, offset, offset, stack);
            } else {
                target = recover_exception(co, result, offset, stack);
            }
            if target >= 0 {
                ip = target;
                continue;
            }
            return result;
        }
        if op == OP_RERAISE {
            # CPython RERAISE: pop the exception (plus the saved lasti when
            # oparg != 0, restoring it as the attribution offset) and go
            # straight to exception_unwind -- a re-raise is not an error
            # event, so no traceback entry is added here. The exception table
            # is searched at the RERAISE's own offset, like CPython's
            # INSTR_OFFSET() in exception_unwind.
            raised = stack.pop();
            eff_offset = offset;
            if arg != 0 {
                saved_lasti = stack.pop();
                if isinstance(saved_lasti, PyInt) {
                    eff_offset = (saved_lasti as PyInt).val;
                }
            }
            result = py_raise_value(raised);
            target = dispatch_exception(co, result, offset, eff_offset, stack);
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
                bm = method as PyBoundMethod;
                stack.append(bm.function);
                stack.append(bm.receiver);
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
            frame.exc_state = exc_handling;
            # Suspend deactivates this frame's handler entries in the global
            # exc_info view (re-appended on resume); without this, an unrelated
            # frame reading sys.exc_info() sees the suspended gen's exception.
            _handled_stack_remove_each(exc_handling);
            return PyYield(t="yield", val=value);
        }
        if op == OP_TO_BOOL {
            condition = stack.pop();
            truth = py_slot_truth(condition);
            if is_error(truth) {
                target = recover_exception(co, truth, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return truth;
            }
            stack.append(truth);
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
            truth = py_slot_truth(contained);
            if is_error(truth) {
                target = recover_exception(co, truth, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return truth;
            }
            present = (truth as PyBool).val;
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
            if arg == 7 {
                # INTRINSIC_TYPEVAR (PEP 695 type parameter): operand is just
                # the parameter name string. Bounds/constraints never come
                # through here -- codegen wraps an unparameterized TypeVar via
                # CALL_INTRINSIC_2 TYPEVAR_WITH_BOUND/_WITH_CONSTRAINTS.
                if not isinstance(operand, PyStr) {
                    return py_error(
                        "SystemError", "CALL_INTRINSIC_1 TYPEVAR name must be a str"
                    );
                }
                stack.append(PyTypeVar(t="TypeVar", name=(operand as PyStr).val));
                continue;
            }
            if arg == 4 {
                # INTRINSIC_ASYNC_GEN_WRAP: CPython wraps each async-generator
                # yield in an AsyncGenWrappedValue so the anext/asend machinery
                # can tell yields from returns. The agen_* drivers unwrap it;
                # a wrapped value escaping any other path stays observable and
                # inert (same policy as CPython's opaque wrapper object).
                stack.append(PyAsyncGenWrappedValue(t="async_wrapped", val=operand));
                continue;
            }
            if arg == 11 {
                # INTRINSIC_TYPEALIAS (PEP 695 `type X = v`): operand is the
                # (name, type_params_or_None, lazy-value-fn) triple codegen
                # builds. Produce the lazily-evaluating alias object.
                if not isinstance(operand, PyTuple)
                    or len((operand as PyTuple).items) != 3 {
                    return py_error(
                        "SystemError", "malformed CALL_INTRINSIC_1 TYPEALIAS operand"
                    );
                }
                parts = (operand as PyTuple).items;
                if not isinstance(parts[0], PyStr) {
                    return py_error(
                        "SystemError", "CALL_INTRINSIC_1 TYPEALIAS name must be a str"
                    );
                }
                stack.append(PyTypeAlias(
                    t="TypeAliasType",
                    name=(parts[0] as PyStr).val,
                    type_params=parts[1],
                    value_fn=parts[2],
                ));
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
                if exc_name == "StopIteration" {
                    stack.append(
                        PyException(
                            t="exception",
                            type_name="RuntimeError",
                            message="generator raised StopIteration",
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
            if arg == 10 {
                # INTRINSIC_SUBSCRIPT_GENERIC (implicit PEP 695 class base):
                # operand is the type-parameter tuple; produce the
                # typing.Generic[T, ...] stand-in that py_build_class later
                # resolves through __mro_entries__ (update_build_class_bases).
                if not isinstance(operand, PyTuple) {
                    return py_error(
                        "SystemError",
                        "malformed CALL_INTRINSIC_1 SUBSCRIPT_GENERIC operand"
                    );
                }
                stack.append(PyGenericAlias(t="generic_alias", params=operand));
                continue;
            }
            return py_error("SystemError", "unsupported CALL_INTRINSIC_1 " + str(arg));
        }
        if op == OP_CALL_INTRINSIC_2 {
            rhs = stack.pop();
            lhs = stack.pop();
            if arg == 1 {
                # INTRINSIC_PREP_RERAISE_STAR: (orig, excs-list) -> the
                # exception to reraise at the tail of a lowered try/except*
                # block (None when everything was swallowed). Semantics live
                # in exceptions_core.prep_reraise_star (_PyExc_PrepReraiseStar
                # port); zero logic inline.
                rr_prep = prep_reraise_star(lhs, rhs);
                if is_error(rr_prep) {
                    return rr_prep;
                }
                stack.append(rr_prep);
                continue;
            }
            if arg == 2 {
                # INTRINSIC_TYPEVAR_WITH_BOUND: (name, lazy-bound-evaluator).
                # The bound stays unevaluated until first __bound__ access --
                # see typevar_bound_value in py_attr.
                if not isinstance(lhs, PyStr) {
                    return py_error(
                        "SystemError", "malformed CALL_INTRINSIC_2 TYPEVAR_WITH_BOUND operand"
                    );
                }
                stack.append(PyTypeVar(
                    t="TypeVar", name=(lhs as PyStr).val, evaluate_bound=rhs
                ));
                continue;
            }
            if arg == 3 {
                # INTRINSIC_TYPEVAR_WITH_CONSTRAINTS: (name, lazy-constraints).
                if not isinstance(lhs, PyStr) {
                    return py_error(
                        "SystemError",
                        "malformed CALL_INTRINSIC_2 TYPEVAR_WITH_CONSTRAINTS operand"
                    );
                }
                stack.append(PyTypeVar(
                    t="TypeVar", name=(lhs as PyStr).val, evaluate_constraints=rhs
                ));
                continue;
            }
            if arg == 4 {
                # INTRINSIC_SET_FUNCTION_TYPE_PARAMS: (function, params-tuple);
                # CPython stores func_typeparams and returns the function.
                if not isinstance(lhs, PyFunction) or not isinstance(rhs, PyTuple) {
                    return py_error(
                        "SystemError",
                        "malformed CALL_INTRINSIC_2 SET_FUNCTION_TYPE_PARAMS operands"
                    );
                }
                fn_tps = lhs as PyFunction;
                fn_tps.attrs["__type_params__"] = rhs;
                stack.append(fn_tps);
                continue;
            }
            if arg == 5 {
                # INTRINSIC_SET_TYPEPARAM_DEFAULT: (typeparam,
                # lazy-default-evaluator); evaluated on first __default__
                # access -- see typevar_default_value in py_attr.
                if not isinstance(lhs, PyTypeVar) {
                    return py_error(
                        "SystemError", "malformed CALL_INTRINSIC_2 SET_TYPEPARAM_DEFAULT operand"
                    );
                }
                tp_default = lhs as PyTypeVar;
                tp_default.evaluate_default = rhs;
                stack.append(tp_default);
                continue;
            }
            return py_error("SystemError", "unsupported CALL_INTRINSIC_2 " + str(arg));
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

# Sync a guest PyDict argument with the working map exec() ran against:
# every name the code bound (or rebound) lands in the caller's dict, and
# every name the code deleted is removed -- STORE_NAME must stay observable
# through the ORIGINAL object the caller passed.
def _sync_ns_back(d: PyDict, work: dict[str, PyObj]) -> PyObj {
    stale: list[PyObj] = [];
    for hk in d.items {
        key_obj = d.items[hk].key;
        if key_obj.t == "str" and not (expect_str(key_obj) in work) {
            stale.append(key_obj);
        }
    }
    for k in stale {
        del_err = d.mp_del_subscript(k);
        if is_error(del_err) {
            return del_err;
        }
    }
    for name in work {
        set_err = d.dict_set(PyStr(t="str", val=name), work[name]);
        if is_error(set_err) {
            return set_err;
        }
    }
    return py_none();
}

# Native builtin exec(source, globals=None, locals=None) -- port of
# bltinmodule.c builtin_exec_impl. The executed module-level MAKE_FUNCTION /
# STORE_NAME sequence binds top-level names through the frame's f_locals and
# f_globals, so those must be the caller's LIVE namespaces -- never copies on
# the host side of the bridge. Guest PyDict arguments run against an internal
# map seeded from the dict and synced back after the run (see _sync_ns_back);
# PyGlobalsProxy views (globals()) are live already. Known accepted delta:
# functions/classes defined by the exec'd code capture the working map as
# their __globals__, not the caller's dict object.
def builtin_exec(
    args: list[PyObj],
    kwargs: dict[str, PyObj],
    frame_globals: dict[str, PyObj],
    frame_locals: dict[str, PyObj]
) -> PyObj {
    if len(kwargs) > 0 {
        return py_error("TypeError", "exec() takes no keyword arguments");
    }
    if len(args) < 1 or len(args) > 3 {
        return py_error(
            "TypeError",
            "exec expected at least 1 argument, got " + str(len(args))
        );
    }
    # str/bytes source: compile through the same marshal transport the import
    # machinery uses (native statement-mode compile is Phase C) and normalize
    # to a PyCode before dispatch. A host SyntaxError surfaces as a catchable
    # guest exception, matching CPython's exec('for = 1') -> SyntaxError.
    if isinstance(args[0], PyStr) or isinstance(args[0], PyBytes) {
        src = "";
        if isinstance(args[0], PyStr) {
            src = (args[0] as PyStr).val;
        } else {
            src = bytes_to_str((args[0] as PyBytes).val);
        }
        packed_src = _jac_host_source_marshal(src);
        if not host_result_ok(packed_src) {
            return host_result_error(packed_src);
        }
        converted_src = unmarshal(packed_src[1] as list[int]);
        if is_error(converted_src) {
            # Surface load-time failures (e.g. opcode validation) verbatim.
            return converted_src;
        }
        if not isinstance(converted_src, PyCode) {
            return py_error("TypeError", "exec() argument 1 must be a code object");
        }
        args[0] = converted_src;
    }
    co: PyCode;
    match args[0] {
        case PyCode():
            co = args[0] as PyCode;
        case PyHostProxy():
            # compile()/types.CodeType built on the host arrive as proxies;
            # bring the code back through the marshal transport -- the same
            # route every oracle code object already travels.
            packed = _jac_host_code_marshal((args[0] as PyHostProxy).val);
            if not host_result_ok(packed) {
                return py_error("TypeError", "exec() argument 1 must be a code object");
            }
            converted = unmarshal(packed[1] as list[int]);
            if not isinstance(converted, PyCode) {
                return py_error("TypeError", "exec() argument 1 must be a code object");
            }
            co = converted as PyCode;
        case _:
            return py_error("TypeError", "exec() argument 1 must be a code object");
    }
    g_work: dict[str, PyObj] = frame_globals;
    g_copy = False;
    if len(args) >= 2 and not isinstance(args[1], PyNoneType) {
        if isinstance(args[1], PyDict) {
            g_work = (args[1] as PyDict).dict_str_map();
            g_copy = True;
        } elif isinstance(args[1], PyGlobalsProxy) {
            g_work = (args[1] as PyGlobalsProxy).ns;
        } else {
            return py_error(
                "TypeError",
                "exec() argument 2 must be a dict, not '"
                    + _compare_type_name(args[1]) + "'"
            );
        }
    }
    l_work: dict[str, PyObj] = g_work;
    l_copy = False;
    if len(args) == 3 and not isinstance(args[2], PyNoneType) {
        if isinstance(args[2], PyDict) {
            l_work = (args[2] as PyDict).dict_str_map();
            l_copy = True;
        } elif isinstance(args[2], PyGlobalsProxy) {
            l_work = (args[2] as PyGlobalsProxy).ns;
        } else {
            return py_error(
                "TypeError",
                "exec() argument 3 must be a dict, not '"
                    + _compare_type_name(args[2]) + "'"
            );
        }
    }
    outcome = exec_code_frame(co, [], {}, g_work, l_work, [], [], {});
    if is_error(outcome) {
        return outcome;
    }
    if g_copy {
        sync_g = _sync_ns_back(args[1] as PyDict, g_work);
        if is_error(sync_g) {
            return sync_g;
        }
    }
    if l_copy {
        sync_l = _sync_ns_back(args[2] as PyDict, l_work);
        if is_error(sync_l) {
            return sync_l;
        }
    }
    return py_none();
}

# Depth of exec_code invocations on the current host stack. Guest execution
# re-enters exec_code for synthesized operator/comprehension code objects
# (pyc_first), so the final-error traceback display must only fire at the
# OUTERMOST call -- where an error genuinely escapes the program -- never for
# inner errors a guest handler may still catch.
glob _tb_exec_depth: int = 0;

def exec_code(co: PyObj, args: list[PyObj], globals: dict[str, PyObj]) -> PyObj {
    match co {
        case PyCode():
            _tb_exec_depth += 1;
            try {
                outcome = exec_code_frame(co, args, {}, globals, globals, [], [], {});
            } finally {
                _tb_exec_depth -= 1;
            }
            if is_error(outcome) and _tb_exec_depth == 0 {
                # Final-error surfacing: render the guest traceback chain to
                # stderr shaped exactly like CPython's uncaught-exception path.
                tb_display_error(outcome, py_str);
            }
            return outcome;
    }
    return py_error("TypeError", "expected code object");
}

def exec_module(co: PyObj) -> dict[str, PyObj] {
    globals: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    outcome = exec_code(co, [], globals);
    # CPython import semantics: an exception raised by a module body propagates
    # to the importer. Discarding it here silently handed callers partial
    # globals on any failure.
    if is_error(outcome) {
        _jac_reraise_pyerror(outcome as PyError);
    }
    return globals;
}
