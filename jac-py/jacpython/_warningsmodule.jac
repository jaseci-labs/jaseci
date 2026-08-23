# Product-path facade for the warnings stdlib surface (native Jac).
# Semantics mirror CPython 3.14 ``Lib/warnings.py`` / ``Python/_warnings.c``:
# the filter action matrix (error/ignore/always/once/default/module),
# per-location dedup registries with version invalidation, once-registry keyed
# on (text, category), ``catch_warnings(record=True)`` recording WarningMessage
# instances, and the byte-exact ``file:line: Category: message`` display.
#
# Position attribution follows CPython's own warn -> warn_explicit protocol:
# warn() resolves the caller position for ``stacklevel``, then funnels into the
# same explicit-location pipeline. CPython reads sys._getframe(stacklevel);
# jacpython's ceval does not expose live frames yet, so the position arrives
# through _p2_warn_position_provider -- a dispatcher that knows the calling
# frame (ceval call-site wiring) installs it via _p2_warn_set_position_provider.
# Until wired, warn() lands on CPython's own out-of-frames fallback
# ("<sys>", line 0); warn_explicit callers always carry exact positions.
#
# Warning-category matching reuses the exception-hierarchy table from
# exceptions_core so filter categories behave exactly like guest ``except``
# matching (PendingDeprecationWarning derives from Warning directly, etc.).

import from objects {
    PyObj,
    PyStr,
    PyInt,
    PyBool,
    PyList,
    PyTuple,
    PyExceptionType,
    PyException,
    py_none,
    py_error,
    py_exception_type,
    expect_str,
    is_error,
}
import from exceptions_core { exc_name_matches, _obj_to_str }

import sys as _host_sys;

glob _WARN_ACTIONS: list[str] = [
    "error",
    "ignore",
    "always",
    "once",
    "default",
    "module",
];

# Filter entries are (action, category-name | None, module-prefix | None).
# First match wins; None matches everything (CPython's regex-free subset --
# simplefilter/filterwarnings never install message or lineno constraints).
glob _warn_filters: list = [];
# Per-module location registries: module -> {(text, category, lineno): 1}.
# Versioned like CPython's __warningregistry__ so a filters change (which
# bumps the version) invalidates every remembered location.
glob _warn_registries: dict = {};
glob _warn_once_registry: dict = {};
glob _warn_filters_version: int = 1;
# While inside catch_warnings(record=True): the guest-visible record list that
# receives one PyWarnMessageRecord per shown warning.
glob _warn_record_target: any = None;
# Display sink override: fn(formatted_text: str). None writes to real stderr,
# exactly like CPython's sys.stderr write.
glob _warn_display_sink: any = None;
# Caller-position provider: fn(stacklevel: int) -> (filename, lineno, module)
# or None when no frame information is available at that depth.
glob _warn_position_provider: any = None;

def _p2_warn_default_filters() -> list {
    # CPython _setup_defaults order (first match wins, so the module-scoped
    # __main__ default must precede the global ignores).
    return [
        ("default", "DeprecationWarning", "__main__"),
        ("ignore", "DeprecationWarning", None),
        ("ignore", "PendingDeprecationWarning", None),
        ("ignore", "ImportWarning", None),
        ("ignore", "ResourceWarning", None),
    ];
}

def _p2_warn_state_reset {
    # Fresh-interpreter warning state for a new snippet/harness run; sink and
    # position provider are harness wiring, not warning state, and survive.
    _warn_filters.clear();
    for item in _p2_warn_default_filters() {
        _warn_filters.append(item);
    }
    _warn_once_registry.clear();
    _warn_registries.clear();
    _warn_record_target = None;
    _p2_warn_filters_mutated();
}

def _p2_warn_filters_mutated {
    _warn_filters_version = _warn_filters_version + 1;
}

def _p2_resetwarnings {
    # CPython resetwarnings(): drop every filter (defaults are NOT restored);
    # unmatched warnings then fall through to the "default" action.
    _warn_filters.clear();
    _p2_warn_filters_mutated();
}

def _p2_action_is_valid(action: str) -> bool {
    for known in _WARN_ACTIONS {
        if action == known {
            return True;
        }
    }
    return False;
}

# Shared tail of simplefilter/filterwarnings: insert at the FRONT (CPython
# _add_filter with append=0), replacing an identical entry first.
def _p2_apply_filter_front(action: str, category_name: str | None, module: str | None) {
    filter = (action, category_name, module);
    if filter in _warn_filters {
        _warn_filters.remove(filter);
    }
    _warn_filters.insert(0, filter);
    _p2_warn_filters_mutated();
}

def _p2_simplefilter(action: str, category_name: str | None) {
    _p2_apply_filter_front(action, category_name, None);
}

def _p2_filterwarnings(action: str, category_name: str | None) {
    _p2_apply_filter_front(action, category_name, None);
}

def _p2_warn_registry_for(module: str) -> dict {
    reg = _warn_registries.get(module);
    if reg is None {
        reg = {};
        _warn_registries[module] = reg;
    }
    if reg.get("version") != _warn_filters_version {
        reg.clear();
        reg["version"] = _warn_filters_version;
    }
    return reg;
}

# CPython warn_explicit decision core over names. Returns "error", "suppress"
# or "show"; the emit step lives in _p2_warn_emit.
def _p2_warn_decide(text: str, category: str, filename: str, lineno: int, module: str) -> str {
    reg = _p2_warn_registry_for(module);
    key = (text, category, lineno);
    if reg.get(key) {
        return "suppress";
    }
    action = "default";
    for item in _warn_filters {
        cat = item[1];
        mod = item[2];
        if cat is not None and not exc_name_matches(category, cat) {
            continue;
        }
        if mod is not None and not module.startswith(mod) {
            continue;
        }
        action = item[0];
        break;
    }
    if action == "ignore" {
        return "suppress";
    }
    if action == "error" {
        return "error";
    }
    if action == "once" {
        # CPython registers the per-module key too, then checks the global
        # once-registry keyed WITHOUT lineno.
        reg[key] = 1;
        oncekey = (text, category);
        if _warn_once_registry.get(oncekey) {
            return "suppress";
        }
        _warn_once_registry[oncekey] = 1;
    } elif action == "always" {
        # CPython: no registry writes; every occurrence shows.
    } elif action == "module" {
        # Once per module regardless of line: the lineno-0 altkey suppresses
        # every later location after the first show.
        reg[key] = 1;
        altkey = (text, category, 0);
        if reg.get(altkey) {
            return "suppress";
        }
        reg[altkey] = 1;
    } elif action == "default" {
        reg[key] = 1;
    }
    return "show";
}

# Byte-exact CPython _formatwarnmsg_impl for the no-source case (msg.line is
# only appended when truthy -- an empty line contributes nothing).
def _p2_formatwarning(message_text: str, category_name: str, filename: str, lineno: int, line: str | None) -> str {
    s = filename + ":" + str(lineno) + ": " + category_name + ": " + message_text + "\n";
    if line is not None and line != "" {
        s = s + "  " + line.strip() + "\n";
    }
    return s;
}

def _p2_warn_emit(text: str, category: str, filename: str, lineno: int, instance: PyObj | None) {
    if _warn_record_target is not None {
        rec_message = instance;
        if rec_message is None {
            # CPython materializes the instance (category(message)) before
            # recording; args carries the text so repr() reads Name('text').
            rec_args: list[PyObj] = [PyStr(t="str", val=text)];
            rec_message = PyException(
                t="exception",
                type_name=category,
                message=text,
                args=rec_args,
            );
        }
        (_warn_record_target as PyList).items.append(
            PyWarnMessageRecord(
                t="warning_message",
                message=rec_message,
                category=category,
                filename=filename,
                lineno=lineno,
            )
        );
        return;
    }
    formatted = _p2_formatwarning(text, category, filename, lineno, None);
    if _warn_display_sink is not None {
        sink: any = _warn_display_sink;
        sink(formatted);
    } else {
        _host_sys.stderr.write(formatted);
    }
}

def _p2_warn_dispatch(
    text: str,
    category: str,
    filename: str,
    lineno: int,
    module: str,
    instance: PyObj | None
) -> PyObj {
    outcome = _p2_warn_decide(text, category, filename, lineno, module);
    if outcome == "suppress" {
        return py_none();
    }
    if outcome == "error" {
        # CPython raises the warning instance itself: type UserWarning-like,
        # str() is the message text -- exactly py_error's shape.
        return py_error(category, text);
    }
    _p2_warn_emit(text, category, filename, lineno, instance);
    return py_none();
}

def _p2_warn_caller_position(stacklevel: int) -> tuple | None {
    if _warn_position_provider is not None {
        provider: any = _warn_position_provider;
        got = provider(stacklevel);
        if got is not None {
            return got;
        }
    }
    return None;
}

# Normalize (message_or_category, category) into [text, category_name,
# instance-or-None]. Returns a PyError on validation failure, otherwise a
# PyTuple of three items. Mirrors CPython warn(): a Warning instance carries
# its own class and str(); a str message defaults to UserWarning; anything
# else stringifies; non-warning categories are TypeErrors.
def _p2_warn_normalize(msg_obj: PyObj, cat_obj: PyObj) -> PyObj {
    category_name = "";
    instance: PyObj | None = None;
    if isinstance(msg_obj, PyException) {
        # str(Warning-instance) is its first arg (baseexception_str shape).
        text = (msg_obj as PyException).message;
        category_name = (msg_obj as PyException).type_name;
        instance = msg_obj;
    } else {
        if isinstance(cat_obj, PyExceptionType) {
            category_name = (cat_obj as PyExceptionType).name;
        } elif isinstance(cat_obj, PyStr) {
            category_name = (cat_obj as PyStr).val;
        } elif cat_obj.t == "none" {
            category_name = "UserWarning";
        } else {
            # Bare builtin names (e.g. DeprecationWarning without a module
            # qualifier) resolve to host-proxied classes; read __name__ off
            # whatever object arrived and validate the hierarchy below.
            name_res = cat_obj.tp_getattro("__name__");
            if is_error(name_res) {
                return py_error(
                    "TypeError",
                    "category must be a Warning subclass, not '" + cat_obj.t
                        + "'"
                );
            }
            category_name = expect_str(name_res);
        }
        if not exc_name_matches(category_name, "Warning") {
            return py_error(
                "TypeError",
                "category must be a Warning subclass, not '" + category_name + "'"
            );
        }
        if isinstance(msg_obj, PyStr) {
            text = (msg_obj as PyStr).val;
        } else {
            # CPython applies str() to arbitrary non-Warning messages.
            text = _obj_to_str(msg_obj);
        }
    }
    parts: list[PyObj] = [];
    parts.append(PyStr(t="str", val=text));
    parts.append(PyStr(t="str", val=category_name));
    if instance is None {
        parts.append(py_none());
    } else {
        parts.append(instance);
    }
    return PyTuple(t="tuple", items=parts);
}

def _p2_warn_set_position_provider(fn: any) {
    _warn_position_provider = fn;
}

def _p2_warn_set_display_sink(fn: any) {
    _warn_display_sink = fn;
}

# ---------------- PyObj bridges (registered as the warnings shim module) ----

obj PyWarningsWarnFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error(
                "TypeError", "warn required argument 'message' (pos 1) missing"
            );
        }
        msg_obj = args[0];
        cat_obj: PyObj = py_none();
        if len(args) > 1 {
            cat_obj = args[1];
        }
        kw_cat = kwargs.get("category");
        if kw_cat is not None {
            cat_obj = kw_cat;
        }
        sl = 1;
        sl_obj: PyObj | None = None;
        if len(args) > 2 {
            sl_obj = args[2];
        }
        kw_sl = kwargs.get("stacklevel");
        if kw_sl is not None {
            sl_obj = kw_sl;
        }
        if sl_obj is not None {
            if not isinstance(sl_obj, PyInt) {
                return py_error("TypeError", "integer argument expected, got "
                    + sl_obj.t);
            }
            sl = (sl_obj as PyInt).val;
            # stacklevel <= 0 has no guest frames to skip (CPython would read
            # warnings.py internals); attribute to the immediate caller.
            if sl < 1 {
                sl = 1;
            }
        }
        norm = _p2_warn_normalize(msg_obj, cat_obj);
        if is_error(norm) {
            return norm;
        }
        parts = (norm as PyTuple).items;
        pos: any = _p2_warn_caller_position(sl);
        if pos is None {
            # CPython's ValueError fallback: globals of sys itself.
            pos = ("<sys>", 0, "<sys>");
        }
        instance: PyObj | None = None;
        if parts[2].t != "none" {
            instance = parts[2];
        }
        return _p2_warn_dispatch(
            (parts[0] as PyStr).val,
            (parts[1] as PyStr).val,
            pos[0],
            pos[1],
            pos[2],
            instance,
        );
    }
}

obj PyWarningsWarnExplicitFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 4 {
            return py_error(
                "TypeError",
                "warn_explicit expected message, category, filename, lineno"
            );
        }
        norm = _p2_warn_normalize(args[0], args[1]);
        if is_error(norm) {
            return norm;
        }
        parts = (norm as PyTuple).items;
        if not isinstance(args[2], PyStr) or not isinstance(args[3], PyInt) {
            return py_error("TypeError", "filename must be str, lineno int");
        }
        filename = (args[2] as PyStr).val;
        lineno = (args[3] as PyInt).val;
        module = "";
        if len(args) > 4 and isinstance(args[4], PyStr) {
            module = (args[4] as PyStr).val;
        } else {
            # CPython: module defaults to filename minus a trailing ".py".
            module = filename;
            if module.endswith(".py") {
                module = module[: len(module) - 3];
            }
            if module == "" {
                module = "<unknown>";
            }
        }
        instance: PyObj | None = None;
        if parts[2].t != "none" {
            instance = parts[2];
        }
        return _p2_warn_dispatch(
            (parts[0] as PyStr).val,
            (parts[1] as PyStr).val,
            filename,
            lineno,
            module,
            instance,
        );
    }
}

obj PyWarningsSimpleFilterFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 or not isinstance(args[0], PyStr) {
            return py_error("TypeError", "simplefilter expected action str");
        }
        action = (args[0] as PyStr).val;
        if not _p2_action_is_valid(action) {
            return py_error("_OptionError", "invalid action '" + action + "'");
        }
        category_name = _p2_optional_category(args, kwargs);
        if category_name is None {
            return py_error(
                "TypeError", "category must be a Warning subclass"
            );
        }
        _p2_simplefilter(action, category_name);
        return py_none();
    }
}

obj PyWarningsFilterwarningsFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 or not isinstance(args[0], PyStr) {
            return py_error("TypeError", "filterwarnings expected action str");
        }
        action = (args[0] as PyStr).val;
        if not _p2_action_is_valid(action) {
            return py_error("_OptionError", "invalid action '" + action + "'");
        }
        category_name = _p2_optional_category(args, kwargs);
        if category_name is None {
            return py_error(
                "TypeError", "category must be a Warning subclass"
            );
        }
        _p2_filterwarnings(action, category_name);
        return py_none();
    }
}

# Optional second positional or category= kwarg naming a warning class;
# defaults to "Warning". Returns None (sentinel) on a bad category object.
def _p2_optional_category(args: list[PyObj], kwargs: dict[str, PyObj]) -> str | None {
    cat_obj: PyObj | None = None;
    if len(args) > 1 {
        cat_obj = args[1];
    }
    kw_cat = kwargs.get("category");
    if kw_cat is not None {
        cat_obj = kw_cat;
    }
    if cat_obj is None or cat_obj.t == "none" {
        return "Warning";
    }
    if isinstance(cat_obj, PyExceptionType) {
        name = (cat_obj as PyExceptionType).name;
        if exc_name_matches(name, "Warning") {
            return name;
        }
        return None;
    }
    # Host-proxied builtin warning classes carry __name__.
    name_res = cat_obj.tp_getattro("__name__");
    if is_error(name_res) {
        return None;
    }
    name = expect_str(name_res);
    if exc_name_matches(name, "Warning") {
        return name;
    }
    return None;
}

obj PyWarningsResetwarningsFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        _p2_resetwarnings();
        return py_none();
    }
}

obj PyWarningsFormatwarningFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 4 {
            return py_error(
                "TypeError",
                "formatwarning expected message, category, filename, lineno"
            );
        }
        norm = _p2_warn_normalize(args[0], args[1]);
        if is_error(norm) {
            return norm;
        }
        parts = (norm as PyTuple).items;
        if not isinstance(args[2], PyStr) or not isinstance(args[3], PyInt) {
            return py_error("TypeError", "filename must be str, lineno int");
        }
        line: str | None = None;
        if len(args) > 4 and isinstance(args[4], PyStr) {
            line = (args[4] as PyStr).val;
        }
        return PyStr(
            t="str",
            val=_p2_formatwarning(
                (parts[0] as PyStr).val,
                (parts[1] as PyStr).val,
                (args[2] as PyStr).val,
                (args[3] as PyInt).val,
                line,
            ),
        );
    }
}

# One recorded warning inside catch_warnings(record=True). Attribute surface
# mirrors CPython WarningMessage; `.message` stays the warning INSTANCE and
# `.category` a real exception type so `w.category.__name__` reads naturally.
obj PyWarnMessageRecord(PyObj) {
    has message: PyObj,
        category: str,
        filename: str,
        lineno: int;

    def tp_getattro(name2: str) -> PyObj {
        if name2 == "message" {
            return self.message;
        }
        if name2 == "category" {
            return py_exception_type(self.category);
        }
        if name2 == "filename" {
            return PyStr(t="str", val=self.filename);
        }
        if name2 == "lineno" {
            return PyInt(t="int", val=self.lineno);
        }
        if name2 == "file" or name2 == "line" or name2 == "source" {
            return py_none();
        }
        if name2 == "__str__" or name2 == "__repr__" {
            return PyWarnMessageStrFn(t="function", parent=self);
        }
        return py_error("AttributeError", name2);
    }
}

# CPython WarningMessage.__repr__: '<WarningMessage {str}>'; __str__ renders
# "{message : %r, category : %r, filename : %r, lineno : %s, line : %r}".
obj PyWarnMessageStrFn(PyObj) {
    has parent: PyWarnMessageRecord;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        msg_repr = _p2_warning_instance_repr(self.parent.message);
        line_repr = "None";
        return PyStr(
            t="str",
            val="<WarningMessage {message : " + msg_repr
                + ", category : '" + self.parent.category
                + "', filename : " + repr(self.parent.filename)
                + ", lineno : " + str(self.parent.lineno)
                + ", line : " + line_repr + "}>",
        );
    }
}

# repr of a warning instance: Name('text') with a single str payload,
# bare Name() when constructed without arguments.
def _p2_warning_instance_repr(instance: PyObj) -> str {
    if isinstance(instance, PyException) {
        exc = instance as PyException;
        if len(exc.args) == 0 {
            return exc.type_name + "()";
        }
        return exc.type_name + "(" + repr(exc.message) + ")";
    }
    return repr(expect_str(instance));
}

# catch_warnings(record=False): snapshots filters on enter, restores them on
# exit; record=True additionally installs a fresh record list (returned as
# the `as` binding) and forces the "always" action, like CPython.
obj PyWarningsCatchCtx(PyObj) {
    has record_flag: bool,
        prev_filters: any = None,
        prev_record_target: any = None;

    def tp_getattro(name2: str) -> PyObj {
        if name2 == "__enter__" {
            return PyWarningsCatchEnter(t="function", parent=self);
        }
        if name2 == "__exit__" {
            return PyWarningsCatchExit(t="function", parent=self);
        }
        return py_error("AttributeError", name2);
    }
}

obj PyWarningsCatchEnter(PyObj) {
    has parent: PyWarningsCatchCtx;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        ctx = self.parent;
        ctx.prev_filters = list(_warn_filters);
        ctx.prev_record_target = _warn_record_target;
        if ctx.record_flag {
            records = PyList(t="list", items=[]);
            _warn_record_target = records;
            _p2_simplefilter("always", "Warning");
            return records;
        }
        return py_none();
    }
}

obj PyWarningsCatchExit(PyObj) {
    has parent: PyWarningsCatchCtx;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        ctx = self.parent;
        if ctx.prev_filters is not None {
            _warn_filters = ctx.prev_filters;
        }
        _warn_record_target = ctx.prev_record_target;
        _p2_warn_filters_mutated();
        # Never suppress: exceptions raised inside the with-body propagate.
        return PyBool(t="bool", val=False);
    }
}

obj PyWarningsCatchFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        record_flag = False;
        kw_record = kwargs.get("record");
        if kw_record is not None and isinstance(kw_record, PyBool) {
            record_flag = (kw_record as PyBool).val;
        }
        return PyWarningsCatchCtx(t="catch_warnings", record_flag=record_flag);
    }
}

# Shim-module attribute table consumed by layer_p2_libtest registration.
def warnings_module_attrs() -> dict[str, PyObj] {
    attrs: dict[str, PyObj] = {
        "warn": PyWarningsWarnFn(t="function"),
        "warn_explicit": PyWarningsWarnExplicitFn(t="function"),
        "simplefilter": PyWarningsSimpleFilterFn(t="function"),
        "filterwarnings": PyWarningsFilterwarningsFn(t="function"),
        "resetwarnings": PyWarningsResetwarningsFn(t="function"),
        "formatwarning": PyWarningsFormatwarningFn(t="function"),
        "catch_warnings": PyWarningsCatchFn(t="function"),
    };
    for cls in [
        "Warning",
        "UserWarning",
        "DeprecationWarning",
        "PendingDeprecationWarning",
        "RuntimeWarning",
        "SyntaxWarning",
        "ImportWarning",
        "FutureWarning",
        "UnicodeWarning",
        "BytesWarning",
        "ResourceWarning",
        "EncodingWarning",
    ] {
        attrs[cls] = py_exception_type(cls);
    }
    return attrs;
}
