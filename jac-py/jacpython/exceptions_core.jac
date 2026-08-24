# P3.2a — exception matching + BaseException str/repr.
#
# c2jac-assisted from ``jac-py/tools/p3_object_core/corpus/exceptions_core.c``
# (lift: ``jac-py/Objects/_lifted/exceptions_core.jac``).
import from objects {
    PyObj,
    PyException,
    PyExceptionType,
    PyStr,
    PyInt,
    PyBool,
    PyNoneType,
    PyBytes,
    PyTuple,
    expect_str,
    exc_is_subclass_of,
    is_error,
}

# The builtin hierarchy table (EXC_PARENT) lives canonically in objects.jac;
# this module reads it via the import above instead of keeping its own copy.

def _exc_parent_of(name: str) -> str {
    # Parent lookup across the builtin hierarchy AND the module-exception
    # registry; a dotted name falls back to its short form so a qualified
    # registry entry ("json.JSONDecodeError") chains like its builtin parent.
    if name in EXC_PARENT {
        return EXC_PARENT[name];
    }
    if name in _MODULE_EXC_BASE {
        return _MODULE_EXC_BASE[name];
    }
    if "." in name {
        parts = name.split(".");
        short = parts[len(parts) - 1];
        if short in EXC_PARENT {
            return EXC_PARENT[short];
        }
        if short in _MODULE_EXC_BASE {
            return _MODULE_EXC_BASE[short];
        }
    }
    return "";
}

def _exc_is_subclass(exc_name: str, base_name: str) -> bool {
    if exc_name == base_name {
        return True;
    }
    cur = exc_name;
    while True {
        nxt = _exc_parent_of(cur);
        if nxt == "" {
            # Last resort: "pkg.Name" IS "Name" (registry short-form alias).
            if "." in cur and base_name == _exc_short_name(cur) {
                return True;
            }
            return False;
        }
        cur = nxt;
        if cur == base_name {
            return True;
        }
    }
}

# ---------------- module-exception registry --------------------------------
# Facade modules declare their exception types here AT IMPORT
# (register_module_exception("struct.error", "Exception")), replacing the old
# bare getattr(builtins, name) boundary lookups. The registry drives:
#   - guest-side matching: exc_name_matches walks these parent links;
#   - host-side materialization: host_exception mints a cached host subclass
#     of the REGISTERED BASE (JSONDecodeError subclasses ValueError, not a
#     generic Exception); unknown names fail loudly instead of degrading.
glob _MODULE_EXC_BASE: dict[str, str] = {};

def _exc_short_name(qualified: str) -> str {
    parts = qualified.split(".");
    return parts[len(parts) - 1];
}

def register_module_exception(qualified: str, base: str) {
    _MODULE_EXC_BASE[qualified] = base;
    # Short-form alias when unambiguous, so a guest raising/catching the SHORT
    # display name (CPython: type(struct.error()).__name__ == "error") matches
    # the same hierarchy.
    short = _exc_short_name(qualified);
    if short != qualified
        and not (short in EXC_PARENT)
        and not (short in _MODULE_EXC_BASE) {
        _MODULE_EXC_BASE[short] = base;
    }
}

# Nearest registered builtin base for a qualified module-exception name;
# "" when the name is not registered.
def registered_exc_base(qualified: str) -> str {
    if qualified in _MODULE_EXC_BASE {
        return _MODULE_EXC_BASE[qualified];
    }
    return "";
}

# CPython ``PyErr_GivenExceptionMatches`` name-level matching with
# BaseException / Exception special cases from ceval. Subclass walks come from
# the canonical EXC_PARENT table in objects.jac.
def exc_name_matches(err_name: str, target_name: str) -> bool {
    if target_name == "BaseException" {
        return True;
    }
    if target_name == "Exception" {
        if err_name == "GeneratorExit"
            or err_name == "KeyboardInterrupt"
            or err_name == "SystemExit" {
            return False;
        }
        return True;
    }
    if exc_is_subclass_of(err_name, target_name) {
        return True;
    }
    return err_name == target_name;
}

def _obj_to_str(value: PyObj) -> str {
    if isinstance(value, PyStr) {
        return (value as PyStr).val;
    }
    if isinstance(value, PyInt) {
        return str((value as PyInt).val);
    }
    if isinstance(value, PyBool) {
        if (value as PyBool).val {
            return "True";
        }
        return "False";
    }
    return expect_str(value);
}

def _repr_obj(value: PyObj, repr_fn: any) -> str {
    res = repr_fn(value);
    if is_error(res) {
        return "<unrepresentable>";
    }
    return expect_str(res);
}

# CPython ``BaseException_str`` (+ VM ``message`` fallback for ``py_error``).
# ``repr_fn`` (py_repr) enables CPython ``KeyError_str``: a single-arg
# KeyError strs as REPR of its payload (str(KeyError('k')) == "'k'") --
# callers without a repr fn fall back to plain BaseException_str.
def baseexception_str(exc: PyException, repr_fn: any = None) -> PyStr {
    # Per-type __str__ slots (CPython ``OSError_str``, ``SyntaxError_str``,
    # ``Unicode*Error_str``, ``KeyError_str``) take precedence over generic
    # ``BaseException_str`` exactly as the C slots do. "" means no override
    # applies (or no repr fn is available for the %R forms) and we fall
    # through to the generic shape below.
    if repr_fn is not None {
        s = typed_exc_str(exc, repr_fn);
        if s != "" {
            return PyStr(t="str", val=s);
        }
    }
    if len(exc.args) == 0 {
        if exc.message != "" {
            return PyStr(t="str", val=exc.message);
        }
        return PyStr(t="str", val="");
    }
    if len(exc.args) == 1 {
        return PyStr(t="str", val=_obj_to_str(exc.args[0]));
    }
    parts: list[str] = [];
    for item in exc.args {
        parts.append(_obj_to_str(item));
    }
    inner = ", ".join(parts);
    return PyStr(t="str", val="(" + inner + ")");
}

# CPython ``BaseException_repr`` (single-arg ``%R`` uses ``repr`` of the arg).
# ``repr_fn`` is ``py_repr`` from ceval (full native/host repr dispatch).
def baseexception_repr(exc: PyException, repr_fn: any) -> PyStr {
    name = exc.type_name;
    if len(exc.args) == 0 {
        return PyStr(t="str", val=name + "()");
    }
    if len(exc.args) == 1 {
        return PyStr(t="str", val=name + "(" + _repr_obj(exc.args[0], repr_fn) + ")",);
    }
    parts: list[str] = [];
    for item in exc.args {
        parts.append(_repr_obj(item, repr_fn));
    }
    inner = ", ".join(parts);
    return PyStr(t="str", val=name + "(" + inner + ")");
}

# ``PyErr_GivenExceptionMatches`` for native ``PyException`` vs exception types.
def py_err_given_exception_matches(err: PyException, exc: PyObj) -> bool {
    if isinstance(exc, PyTuple) {
        for item in (exc as PyTuple).items {
            if py_err_given_exception_matches(err, item) {
                return True;
            }
        }
        return False;
    }
    if exc.t == "exception_type" {
        return exc_name_matches(err.type_name, (exc as PyExceptionType).name);
    }
    return False;
}


def _field_int(fields: dict[str, PyObj], key: str) -> int {
    if key in fields {
        v = fields[key];
        if isinstance(v, PyInt) {
            return (v as PyInt).val;
        }
    }
    return -1;
}

def _field_present(fields: dict[str, PyObj], key: str) -> bool {
    return key in fields and not isinstance(fields[key], PyNoneType);
}

def _hex_padded(v: int, width: int) -> str {
    out = "";
    x = v;
    while x > 0 {
        out = "0123456789abcdef"[x % 16] + out;
        x = x // 16;
    }
    while len(out) < width {
        out = "0" + out;
    }
    return out;
}

def _safe_field_str(fields: dict[str, PyObj], key: str) -> str {
    if key in fields {
        v = fields[key];
        if isinstance(v, PyStr) {
            return (v as PyStr).val;
        }
    }
    return "";
}

def _seq_char_at(fields: dict[str, PyObj], index: int) -> int {
    if "object" not in fields or index < 0 {
        return -1;
    }
    seq = fields["object"];
    if isinstance(seq, PyStr) {
        s = (seq as PyStr).val;
        if index < len(s) {
            return ord(s[index]);
        }
    }
    return -1;
}

def keyerror_str(exc_args: list[PyObj], repr_fn: any) -> str {
    if len(exc_args) == 1 {
        return _repr_obj(exc_args[0], repr_fn);
    }
    if len(exc_args) > 1 {
        parts: list[str] = [];
        for item in exc_args {
            parts.append(_repr_obj(item, repr_fn));
        }
        return "(" + ", ".join(parts) + ")";
    }
    return "";
}

def oserror_smart_str(fields: dict[str, PyObj], repr_fn: any) -> str {
    if not _field_present(fields, "errno") or not _field_present(fields, "strerror") {
        return "";
    }
    errno = _field_int(fields, "errno");
    if errno < 0 {
        return "";
    }
    # CPython formats strerror with %s -- only filenames take %r.
    serr = _obj_to_str(fields["strerror"]);
    prefix = "[Errno " + str(errno) + "] " + serr;
    if not _field_present(fields, "filename") {
        return prefix;
    }
    fname_res = repr_fn(fields["filename"]);
    if is_error(fname_res) {
        return prefix;
    }
    fname = expect_str(fname_res);
    if _field_present(fields, "filename2") {
        # CPython takes the two-file form only when filename2 != filename.
        f2 = "";
        f2_res = repr_fn(fields["filename2"]);
        if not is_error(f2_res) {
            f2 = expect_str(f2_res);
        }
        if f2 != fname {
            return prefix + ": " + fname + " -> " + f2;
        }
    }
    return prefix + ": " + fname;
}

def syntax_error_str(exc: PyException) -> str {
    fields = exc.type_fields;
    msg_v = fields.get("msg");
    msg = "";
    if msg_v is not None and not isinstance(msg_v, PyNoneType) {
        msg = _obj_to_str(msg_v);
    } elif len(exc.args) > 0 {
        msg = _obj_to_str(exc.args[0]);
    }
    has_file = _field_present(fields, "filename");
    has_line = _field_present(fields, "lineno");
    show_file = _field_present(fields, "print_file_and_line")
        or (has_file and has_line);
    suffix = "";
    if show_file and has_file {
        suffix = _obj_to_str(fields["filename"]);
        if has_line {
            suffix = suffix + ", line " + str(_field_int(fields, "lineno"));
        }
    } elif has_line {
        suffix = "line " + str(_field_int(fields, "lineno"));
    } else {
        return msg;
    }
    return msg + " (" + suffix + ")";
}

def typed_exc_str(exc: PyException, repr_fn: any) -> str {
    # A user subclass instance (class MyErr(KeyError)) carries its resolved
    # builtin ancestor in `family`; dispatch on that so inherited __str__
    # semantics apply exactly like CPython's inherited slots.
    tname = exc.type_name;
    if exc.family != "" {
        tname = exc.family;
    }
    if exc_is_subclass_of(tname, "UnicodeDecodeError") {
        s = unicode_decode_error_str(exc);
        if s != "" {
            return s;
        }
    }
    if exc_is_subclass_of(tname, "UnicodeEncodeError") {
        s = unicode_encode_error_str(exc);
        if s != "" {
            return s;
        }
    }
    if exc_is_subclass_of(tname, "UnicodeTranslateError") {
        s = unicode_translate_error_str(exc);
        if s != "" {
            return s;
        }
    }
    if exc_is_subclass_of(tname, "OSError") {
        s = oserror_smart_str(exc.type_fields, repr_fn);
        if s != "" {
            return s;
        }
    }
    if exc_is_subclass_of(tname, "SyntaxError") {
        return syntax_error_str(exc);
    }
    if exc_is_subclass_of(tname, "KeyError") {
        return keyerror_str(exc.args, repr_fn);
    }
    return "";
}

def unicode_decode_error_str(exc: PyException) -> str {
    fields = exc.type_fields;
    enc = _safe_field_str(fields, "encoding");
    reason = _safe_field_str(fields, "reason");
    start = _field_int(fields, "start");
    byte_val = -1;
    if "object" in fields and start >= 0 {
        seq = fields["object"];
        # Native bytes carry their data as a list[int]-like payload; host bytes
        # instances arrive only through the proxy path, where the host-computed
        # message takes precedence before this renderer is ever reached.
        if isinstance(seq, PyBytes) {
            data = (seq as PyBytes).val;
            if start < len(data) {
                byte_val = data[start];
            }
        }
    }
    if enc == "" or byte_val < 0 {
        return "";
    }
    return "'" + enc + "' codec can't decode byte 0x" + _hex_padded(byte_val, 2)
        + " in position " + str(start) + ": " + reason;
}

def unicode_encode_error_str(exc: PyException) -> str {
    fields = exc.type_fields;
    enc = _safe_field_str(fields, "encoding");
    reason = _safe_field_str(fields, "reason");
    start = _field_int(fields, "start");
    cp = _seq_char_at(fields, start);
    if enc == "" or cp < 0 {
        return "";
    }
    esc = "\\u";
    width = 4;
    if cp > 0xffff {
        esc = "\\U";
        width = 8;
    }
    return "'" + enc + "' codec can't encode character " + esc
        + _hex_padded(cp, width)
        + " in position " + str(start) + ": " + reason;
}

def unicode_translate_error_str(exc: PyException) -> str {
    fields = exc.type_fields;
    reason = _safe_field_str(fields, "reason");
    start = _field_int(fields, "start");
    cp = _seq_char_at(fields, start);
    if cp < 0 {
        return "";
    }
    esc = "\\u";
    width = 4;
    if cp > 0xffff {
        esc = "\\U";
        width = 8;
    }
    return "can't translate character " + esc + _hex_padded(cp, width)
        + " in position " + str(start) + ": " + reason;
}
