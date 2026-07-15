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

def _jac_host_builtin(name):
    import builtins
    try:
        return (True, getattr(builtins, name))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_host_type_name(value):
    return type(value).__name__

def _jac_host_format(value, spec):
    try:
        return (True, format(value, spec))
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
    list_value,
    concat_items,
    find_name,
    py_none,
    py_error,
    py_exception_type,
    is_error
}

# The proxy archetype (PLAN.md §5, TODO.md Layer 1): wraps a host object and
# routes every slot across the substrate boundary. Born here on the same slot
# mechanism as PyUserObj so bootstrap-time module proxying (import re -> host
# re wrapped in a PyHostProxy) has its socket from day one, not bolted on later.
obj PyHostProxy(PyObj) {
    has val: any;

    def tp_getattro(name: str) -> PyObj {
        return host_getattr(self, name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        return host_setattr(self, name, value);
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return py_call_host(self, args, kwargs);
    }

    def mp_subscript(index: PyObj) -> PyObj {
        return host_getitem(self, index);
    }
}

obj PyClass(PyObj) {
    has name: str,
        attrs: dict[str, PyObj];

    def tp_getattro(name: str) -> PyObj {
        if name in self.attrs {
            return self.attrs[name];
        }
        return py_error("AttributeError", name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        self.attrs[name] = value;
        return py_none();
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        instance = PyUserObj(t="instance", cls=self, attrs={});
        if "__init__" in self.attrs {
            initialized = bind_attribute(self.attrs["__init__"], instance).tp_call(
                args, kwargs
            );
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
        attrs: dict[str, PyObj];

    def tp_getattro(name: str) -> PyObj {
        if name in self.attrs {
            return bind_attribute(self.attrs[name], self);
        }
        if name in self.cls.attrs {
            return bind_attribute(self.cls.attrs[name], self);
        }
        return py_error("AttributeError", name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        self.attrs[name] = value;
        return py_none();
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
}

obj PyBuildClass(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return py_build_class(args);
    }
}

obj PyFunction(PyObj) {
    has code: PyCode,
        globals: dict[str, PyObj],
        name: str,
        defaults: list[PyObj] = [],
        kwdefaults: dict[str, PyObj] = {},
        closure: list[PyCell] = [];

    def tp_getattro(name: str) -> PyObj {
        if name == "__name__" {
            return PyStr(t="str", val=self.name);
        }
        return py_error("AttributeError", name);
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
        values: dict[str, PyObj] = {};
        for key in raw {
            values[str(key)] = from_host(raw[key]);
        }
        return PyDict(t="dict", items=values);
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
            result: dict[str, any] = {};
            for key in value.items {
                result[key] = to_host(value.items[key]);
            }
            return result;

        case PySlice():
            return slice(to_host(value.start), to_host(value.stop), to_host(value.step));

        case PyHostProxy():
            return value.val;

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
    or name == "ImportError" {
        return py_exception_type(name);
    }
    result = _jac_host_builtin(name);
    if host_result_ok(result) {
        return PyHostProxy(t="host", val=result[1]);
    }
    return py_error(str(result[1]), str(result[2]));
}

def host_import(name: str, fromlist: PyObj) -> PyObj {
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
        if frac == 0 {
            if sign == 1 {
                return -1e300 * 1e300;
            } else {
                return 1e300 * 1e300;
            }
        }
        return 0.0 / 0.0;
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
        } else {
            return py_none();
        }
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
     OP_LIST_EXTEND: int = 79,
     OP_LOAD_ATTR: int = 80,
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
     OP_STORE_DEREF: int = 111,
     OP_STORE_FAST: int = 112,
     OP_STORE_NAME: int = 116,
     OP_SWAP: int = 117,
     OP_CHECK_EXC_MATCH: int = 6,
     OP_POP_EXCEPT: int = 29,
     OP_CONVERT_VALUE: int = 58,
     OP_FORMAT_SIMPLE: int = 12,
     OP_FORMAT_WITH_SPEC: int = 13,
     OP_BUILD_STRING: int = 50,
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
    if op == OP_JUMP_BACKWARD or op == OP_JUMP_BACKWARD_NO_INTERRUPT {
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

def py_compare(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    return lhs.tp_richcompare(kind, rhs);
}

def py_binop(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    return lhs.nb_binop(kind, rhs);
}

def py_subscript(container: PyObj, index: PyObj) -> PyObj {
    return container.mp_subscript(index);
}

def py_store_subscript(container: PyObj, index: PyObj, value: PyObj) -> PyObj {
    return container.mp_ass_subscript(index, value);
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
    return t == "str" or t == "bytes" or t == "int" or t == "bool"
        or t == "float" or t == "list" or t == "tuple" or t == "dict"
        or t == "complex";
}

def py_attr(value: PyObj, name: str) -> PyObj {
    result = value.tp_getattro(name);
    if is_error(result) and _is_host_backed(value.t) {
        return host_getattr(value, name);
    }
    return result;
}

def bind_attribute(value: PyObj, receiver: PyObj) -> PyObj {
    if value.t == "function" {
        return PyBoundMethod(t="bound_method", function=value, receiver=receiver);
    }
    return value;
}

def py_set_attr(value: PyObj, name: str, field: PyObj) -> PyObj {
    return value.tp_setattro(name, field);
}

def py_iter(value: PyObj) -> PyObj {
    return value.tp_iter();
}

def find_cell(cells: list[PyCell], names: list[str], name: str) -> PyCell | None {
    i = find_name(names, name);
    if i >= 0 and i < len(cells) {
        return cells[i];
    }
    return None;
}

def fast_value(co: PyCode, arg: int, fast: list[PyObj], cells: list[PyCell]) -> PyObj {
    if arg < len(co.varnames) {
        return fast[arg];
    }
    cell_index = arg - len(co.varnames);
    if cell_index >= 0 and cell_index < len(cells) {
        return cells[cell_index].val;
    }
    return py_error("UnboundLocalError", "local variable is not set");
}

def deref_cell(
    co: PyCode, arg: int, fast: list[PyObj], cells: list[PyCell], closure: list[PyCell]
) -> PyCell | None {
    if arg < len(co.varnames) and co.varnames[arg] in co.cellvars {
        return find_cell(cells, co.cellvars, co.varnames[arg]);
    }
    cell_index = arg - len(co.varnames);
    if cell_index >= 0 and cell_index < len(cells) {
        return cells[cell_index];
    }
    free_index = arg - len(co.varnames);
    if free_index >= 0 and free_index < len(closure) {
        return closure[free_index];
    }
    return None;
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

def py_build_class(args: list[PyObj]) -> PyObj {
    if len(args) < 2 {
        return py_error("TypeError", "__build_class__ needs a body and name");
    }
    body = args[0] as PyFunction;
    class_name = expect_str(args[1]);
    namespace: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    body_result = exec_code_frame(
        body.code, [], {}, body.globals, namespace, body.closure, [], {}
    );
    if body_result.t == "error" {
        return body_result;
    }
    return PyClass(t="class", name=class_name, attrs=namespace);
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
    i = 0;
    while i < len(args) and i < positional_count {
        fast[i] = args[i];
        assigned[i] = True;
        i = i + 1;
    }
    if len(args) > positional_count and (co.flags & 4) == 0 {
        return py_error("TypeError", "too many positional arguments");
    }
    i = 0;
    while i < len(kwargs) {
        # Dict iteration is stable, but the key is obtained through a small list
        # to keep this path independent of Python's dict view types.
        i = i + 1;
    }
    for key in kwargs {
        index = find_name(co.varnames, key);
        if index < 0 or index >= len(fast) {
            return py_error("TypeError", "unexpected keyword argument " + key);
        }
        if index < co.posonlyargcount {
            return py_error("TypeError", "positional-only argument passed by name");
        }
        if assigned[index] {
            return py_error("TypeError", "multiple values for argument " + key);
        }
        fast[index] = kwargs[key];
        assigned[index] = True;
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
    stack: list[PyObj] = [];
    code = co.co_code;
    ip = 0;
    while ip < len(code) {
        offset = ip;
        op = code[ip];
        arg = code[ip + 1];
        ip = ip + 2 + 2 * opcode_cache_count(op);
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
            fast_result = fast_value(co, arg, fast, cells);
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
        if op == OP_LOAD_FAST_BORROW_2 or op == OP_LOAD_FAST_LOAD_FAST {
            first = arg // 16;
            second = arg % 16;
            first_result = fast_value(co, first, fast, cells);
            second_result = fast_value(co, second, fast, cells);
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
            stack.append(PyDict(t="dict", items=locals));
            continue;
        }
        if op == OP_STORE_NAME {
            locals[co.names[arg]] = stack.pop();
            continue;
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
                function.kwdefaults = (attribute as PyDict).items;
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
            values: dict[str, PyObj] = {};
            j = 0;
            while j < arg {
                key = expect_str(popped[j * 2]);
                values[key] = popped[j * 2 + 1];
                j = j + 1;
            }
            stack.append(PyDict(t="dict", items=values));
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
        if op == OP_GET_ITER {
            iterable = py_iter(stack.pop());
            if is_error(iterable) {
                return iterable;
            }
            stack.append(iterable);
            continue;
        }
        if op == OP_FOR_ITER {
            iterator = stack[len(stack) - 1] as PyIter;
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
            same = lhs.t == rhs.t;
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
            result = py_subscript(container, PySlice(t="slice", start=start, stop=stop, step=py_none()));
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
            if arg == 3 { slice_step = stack.pop(); }
            slice_stop = stack.pop();
            slice_start = stack.pop();
            stack.append(PySlice(t="slice", start=slice_start, stop=slice_stop, step=slice_step));
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
        if op == OP_IMPORT_NAME {
            fromlist = stack.pop();
            stack.pop();
            result = host_import(co.names[arg], fromlist);
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
            stack.pop();
            if len(stack) == 0 {
                return py_error("RuntimeError", "CALL stack underflow");
            }
            fn = stack.pop();
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
        if op == OP_PUSH_EXC_INFO {
            if len(stack) > 0 {
                exception = stack.pop();
                stack.append(py_none());
                stack.append(exception);
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
            continue;
        }
        if op == OP_RAISE_VARARGS {
            raised = py_none();
            if arg > 0 {
                raised = stack.pop();
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
            top = len(stack) - 1;
            other = top - arg;
            temporary = stack[top];
            stack[top] = stack[other];
            stack[other] = temporary;
            continue;
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
        print("pyc_first: unsupported opcode " + str(op));
        return py_none();
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
