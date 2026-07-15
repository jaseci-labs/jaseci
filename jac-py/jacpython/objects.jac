# jacpython object core -- the na-clean leaf (jac-py/PLAN.md §5, §4 module note).
#
# This module is the acyclic base of the runtime: the PyObj hierarchy's DATA
# types and their value/container slots, plus pure helpers. It has NO imports,
# NO host calls, and NO eval -- so it is native-compilable (T7). The callable/
# heap/proxy types (PyFunction/PyClass/PyUserObj/PyHostProxy) live in the ceval
# module and OVERRIDE these slots via cross-module inheritance; the marshal
# reader and ceval import FROM here. Jac forbids import cycles, so anything that
# reaches the host or re-enters the interpreter must stay out of this file.
#
# Behavior dispatches through virtual slot methods (CPython's tp_*/nb_*/sq_*/mp_*
# tables as overridable methods -> na vtable, no function-pointer indirection).
# The `t` tag is a tp_name label (isinstance / exception matching), NOT a
# behavior selector -- selection is virtual dispatch on the receiver.
obj PyObj {
    has t: str;

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        return py_error("TypeError", "unsupported operand types");
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        if kind == 2 {
            return PyBool(t="bool", val=self.t == other.t);
        }
        if kind == 3 {
            return PyBool(t="bool", val=self.t != other.t);
        }
        return PyBool(t="bool", val=False);
    }

    def mp_subscript(index: PyObj) -> PyObj {
        return py_error("TypeError", "object is not subscriptable");
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        return py_error("TypeError", "object does not support item assignment");
    }

    def tp_iter -> PyObj {
        return py_error("TypeError", "object is not iterable");
    }

    def tp_bool -> bool {
        return True;
    }

    def tp_getattro(name: str) -> PyObj {
        return py_error("AttributeError", name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        return py_error("AttributeError", name);
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return py_error("TypeError", "object is not callable");
    }
}

obj PyInt(PyObj) {
    has val: int;

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        if other.t != "int" {
            return py_error("TypeError", "unsupported operand types");
        }
        b = (other as PyInt).val;
        a = self.val;
        if kind == 0 {
            return PyInt(t="int", val=a + b);
        }
        if kind == 5 {
            return PyInt(t="int", val=a * b);
        }
        if kind == 6 {
            if b == 0 {
                return py_error("ZeroDivisionError", "integer modulo by zero");
            }
            return PyInt(t="int", val=a % b);
        }
        if kind == 10 {
            return PyInt(t="int", val=a - b);
        }
        if kind == 1 {
            return PyInt(t="int", val=a & b);
        }
        if kind == 2 {
            if b == 0 {
                return py_error(
                    "ZeroDivisionError", "integer division or modulo by zero"
                );
            }
            return PyInt(t="int", val=a // b);
        }
        if kind == 7 {
            return PyInt(t="int", val=a | b);
        }
        if kind == 11 {
            return PyInt(t="int", val=a ^ b);
        }
        if kind == 3 {
            return PyInt(t="int", val=a << b);
        }
        if kind == 9 {
            return PyInt(t="int", val=a >> b);
        }
        if kind == 8 {
            return PyInt(t="int", val=a ** b);
        }
        return py_error("TypeError", "unsupported operand types");
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        if other.t != "int" {
            if kind == 2 {
                return PyBool(t="bool", val=False);
            }
            if kind == 3 {
                return PyBool(t="bool", val=True);
            }
            return PyBool(t="bool", val=False);
        }
        a = self.val;
        b = (other as PyInt).val;
        if kind == 0 {
            return PyBool(t="bool", val=a < b);
        }
        if kind == 1 {
            return PyBool(t="bool", val=a <= b);
        }
        if kind == 2 {
            return PyBool(t="bool", val=a == b);
        }
        if kind == 3 {
            return PyBool(t="bool", val=a != b);
        }
        if kind == 4 {
            return PyBool(t="bool", val=a > b);
        }
        if kind == 5 {
            return PyBool(t="bool", val=a >= b);
        }
        return PyBool(t="bool", val=False);
    }

    def tp_bool -> bool {
        return self.val != 0;
    }
    # int is its own real part / numerator; imag is 0, denominator is 1.
    def tp_getattro(name: str) -> PyObj {
        if name == "real" or name == "numerator" {
            return PyInt(t="int", val=self.val);
        }
        if name == "imag" {
            return PyInt(t="int", val=0);
        }
        if name == "denominator" {
            return PyInt(t="int", val=1);
        }
        return py_error("AttributeError", name);
    }
}

obj PyStr(PyObj) {
    has val: str;

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        if kind == 0 and other.t == "str" {
            return PyStr(t="str", val=self.val + (other as PyStr).val);
        }
        if kind == 6 {
            return str_mod_format(self.val, other);
        }
        return py_error("TypeError", "unsupported operand types");
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        if other.t != "str" {
            if kind == 2 {
                return PyBool(t="bool", val=False);
            }
            if kind == 3 {
                return PyBool(t="bool", val=True);
            }
            return PyBool(t="bool", val=False);
        }
        a = self.val;
        b = (other as PyStr).val;
        if kind == 0 {
            return PyBool(t="bool", val=a < b);
        }
        if kind == 1 {
            return PyBool(t="bool", val=a <= b);
        }
        if kind == 2 {
            return PyBool(t="bool", val=a == b);
        }
        if kind == 3 {
            return PyBool(t="bool", val=a != b);
        }
        if kind == 4 {
            return PyBool(t="bool", val=a > b);
        }
        if kind == 5 {
            return PyBool(t="bool", val=a >= b);
        }
        return PyBool(t="bool", val=False);
    }

    def mp_subscript(index: PyObj) -> PyObj {
        if isinstance(index, PySlice) {
            return PyStr(t="str", val=_slice_str(self.val, index as PySlice));
        }
        if index.t != "int" {
            return py_error("TypeError", "index must be an integer");
        }
        i = (index as PyInt).val;
        text = self.val;
        if i < 0 {
            i = len(text) + i;
        }
        if i >= 0 and i < len(text) {
            return PyStr(t="str", val=text[i]);
        }
        return py_error("IndexError", "string index out of range");
    }

    def tp_iter -> PyObj {
        chars: list[PyObj] = [];
        for ch in self.val {
            chars.append(PyStr(t="str", val=ch));
        }
        return PyIter(t="iter", items=chars, index=0);
    }

    def tp_bool -> bool {
        return len(self.val) != 0;
    }
}

obj PyBytes(PyObj) {
    has val: list[int];

    def mp_subscript(index: PyObj) -> PyObj {
        if isinstance(index, PySlice) {
            return PyBytes(t="bytes", val=_slice_ints(self.val, index as PySlice));
        }
        if index.t != "int" {
            return py_error("TypeError", "index must be an integer");
        }
        i = (index as PyInt).val;
        vals = self.val;
        if i < 0 {
            i = len(vals) + i;
        }
        if i >= 0 and i < len(vals) {
            return PyInt(t="int", val=vals[i]);
        }
        return py_error("IndexError", "index out of range");
    }

    def tp_bool -> bool {
        return len(self.val) != 0;
    }
}

obj PyFloat(PyObj) {
    has val: float;

    def tp_bool -> bool {
        return self.val != 0.0;
    }
}

obj PyBool(PyObj) {
    has val: bool;

    def tp_bool -> bool {
        return self.val;
    }
    # bool is an int subclass: real/numerator are int 0 or 1 (not bool), imag 0.
    def tp_getattro(name: str) -> PyObj {
        v = 0;
        if self.val {
            v = 1;
        }
        if name == "real" or name == "numerator" {
            return PyInt(t="int", val=v);
        }
        if name == "imag" {
            return PyInt(t="int", val=0);
        }
        if name == "denominator" {
            return PyInt(t="int", val=1);
        }
        return py_error("AttributeError", name);
    }
}

obj PyNoneType(PyObj) {
    def tp_bool -> bool {
        return False;
    }
}

obj PyComplex(PyObj) {
    has real: float,
        imag: float;
}

obj PySlice(PyObj) {
    has start: PyObj,
        stop: PyObj,
        step: PyObj;
}

obj PyTuple(PyObj) {
    has items: list[PyObj];

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        if kind == 0 and other.t == "tuple" {
            return PyTuple(
                t="tuple", items=concat_items(self.items, (other as PyTuple).items)
            );
        }
        return py_error("TypeError", "unsupported operand types");
    }

    def mp_subscript(index: PyObj) -> PyObj {
        if isinstance(index, PySlice) {
            return PyTuple(t="tuple", items=_slice_objs(self.items, index as PySlice));
        }
        if index.t != "int" {
            return py_error("TypeError", "index must be an integer");
        }
        i = (index as PyInt).val;
        if i < 0 {
            i = len(self.items) + i;
        }
        if i >= 0 and i < len(self.items) {
            return self.items[i];
        }
        return py_error("IndexError", "tuple index out of range");
    }

    def tp_iter -> PyObj {
        return PyIter(t="iter", items=self.items, index=0);
    }

    def tp_bool -> bool {
        return len(self.items) != 0;
    }
}

obj PyList(PyObj) {
    has items: list[PyObj];

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        if kind == 0 and other.t == "list" {
            return PyList(
                t="list", items=concat_items(self.items, (other as PyList).items)
            );
        }
        return py_error("TypeError", "unsupported operand types");
    }

    def mp_subscript(index: PyObj) -> PyObj {
        if isinstance(index, PySlice) {
            return PyList(t="list", items=_slice_objs(self.items, index as PySlice));
        }
        if index.t != "int" {
            return py_error("TypeError", "index must be an integer");
        }
        i = (index as PyInt).val;
        if i < 0 {
            i = len(self.items) + i;
        }
        if i >= 0 and i < len(self.items) {
            return self.items[i];
        }
        return py_error("IndexError", "list index out of range");
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        if index.t != "int" {
            return py_error("TypeError", "list indices must be integers");
        }
        i = (index as PyInt).val;
        if i < 0 {
            i = len(self.items) + i;
        }
        if i >= 0 and i < len(self.items) {
            self.items[i] = value;
            return py_none();
        }
        return py_error("IndexError", "list assignment index out of range");
    }

    def tp_iter -> PyObj {
        return PyIter(t="iter", items=self.items, index=0);
    }

    def tp_bool -> bool {
        return len(self.items) != 0;
    }
}

obj PyCode(PyObj) {
    has argcount: int,
        posonlyargcount: int,
        kwonlyargcount: int,
        stacksize: int,
        flags: int,
        co_code: list[int],
        consts: list[PyObj],
        names: list[str],
        varnames: list[str],
        cellvars: list[str],
        freevars: list[str],
        filename: str,
        name: str,
        qualname: str,
        firstlineno: int,
        linetable: list[int],
        exceptiontable: list[int];
}

obj PyCell(PyObj) {
    has val: PyObj;
}

obj PyDict(PyObj) {
    has items: dict[str, PyObj];

    def mp_subscript(index: PyObj) -> PyObj {
        key = expect_str(index);
        if key in self.items {
            return self.items[key];
        }
        return py_error("KeyError", key);
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        self.items[expect_str(index)] = value;
        return py_none();
    }

    # NOTE: dict host-method attr access (get/keys/values/items) is deliberately
    # NOT here -- it required a host_getattr call, which would make this na-clean
    # leaf depend on the host bridge (an import cycle) for a bootstrap-only,
    # untested convenience. If needed it belongs in the ceval/bootstrap layer.
    def tp_getattro(name: str) -> PyObj {
        if name in self.items {
            return self.items[name];
        }
        return py_error("AttributeError", name);
    }

    def tp_bool -> bool {
        return len(self.items) != 0;
    }
}

obj PyExceptionType(PyObj) {
    has name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        message = "";
        if len(args) > 0 {
            message = expect_str(args[0]);
        }
        return PyException(t="exception", type_name=self.name, message=message);
    }
}

obj PyException(PyObj) {
    has type_name: str,
        message: str,
        raw: any = None,
        # StopIteration payload: `return x` in a generator surfaces as
        # StopIteration(x); .send()/next() carry the value here.
        value: any = None;
}

obj PyError(PyObj) {
    has exception: PyException,
        lasti: int = -1;
}

obj PyIter(PyObj) {
    has items: list[PyObj],
        index: int;
}

obj PyHandler(PyObj) {
    has start: int,
        end: int,
        target: int,
        depth: int,
        lasti: bool;
}

# ---------------- pure helpers (na-clean: isinstance/as, no MatchArch) ----------------
def bytes_value(o: PyObj) -> list[int] {
    if isinstance(o, PyBytes) {
        return (o as PyBytes).val;
    }
    return [];
}

def tuple_value(o: PyObj) -> list[PyObj] {
    if isinstance(o, PyTuple) {
        return (o as PyTuple).items;
    }
    return [];
}

def str_value(o: PyObj) -> str {
    if isinstance(o, PyStr) {
        return (o as PyStr).val;
    }
    return "";
}

def str_values(o: PyObj) -> list[str] {
    result: list[str] = [];
    for it in tuple_value(o) {
        result.append(str_value(it));
    }
    return result;
}

def int_values(o: PyObj) -> list[int] {
    result: list[int] = [];
    for it in tuple_value(o) {
        if isinstance(it, PyInt) {
            result.append((it as PyInt).val);
        }
    }
    return result;
}

def expect_int(o: PyObj) -> int {
    if isinstance(o, PyInt) {
        return (o as PyInt).val;
    }
    return 0;
}

def expect_str(o: PyObj) -> str {
    if isinstance(o, PyStr) {
        return (o as PyStr).val;
    }
    return "";
}

def list_value(o: PyObj) -> list[PyObj] {
    if isinstance(o, PyList) {
        return (o as PyList).items;
    }
    return [];
}

def concat_items(left: list[PyObj], right: list[PyObj]) -> list[PyObj] {
    result: list[PyObj] = [];
    result.extend(left);
    result.extend(right);
    return result;
}

def find_name(names: list[str], name: str) -> int {
    i = 0;
    while i < len(names) {
        if names[i] == name {
            return i;
        }
        i = i + 1;
    }
    return -1;
}

def py_none -> PyObj {
    return PyNoneType(t="none");
}

def py_error(type_name: str, message: str) -> PyObj {
    return PyError(
        t="error",
        exception=PyException(t="exception", type_name=type_name, message=message),
    );
}

def py_exception_type(name: str) -> PyObj {
    return PyExceptionType(t="exception_type", name=name);
}

def is_error(value: PyObj) -> bool {
    return value.t == "error";
}

# ---------------- slicing (CPython PySlice_AdjustIndices) ----------------
def _adjust_index(i: int, length: int, neg: bool) -> int {
    if i < 0 {
        i = i + length;
        if i < 0 {
            if neg {
                i = -1;
            } else {
                i = 0;
            }
        }
    } elif i >= length {
        if neg {
            i = length - 1;
        } else {
            i = length;
        }
    }
    return i;
}

# Resolve a PySlice against a sequence of `length` into concrete
# [start, stop, step], applying CPython's negative-index and clamping rules.
def slice_indices(sl: PySlice, length: int) -> list[int] {
    step = 1;
    if not isinstance(sl.step, PyNoneType) {
        step = expect_int(sl.step);
    }
    neg = step < 0;
    start = 0;
    if isinstance(sl.start, PyNoneType) {
        if neg {
            start = length - 1;
        } else {
            start = 0;
        }
    } else {
        start = _adjust_index(expect_int(sl.start), length, neg);
    }
    stop = 0;
    if isinstance(sl.stop, PyNoneType) {
        if neg {
            stop = -1;
        } else {
            stop = length;
        }
    } else {
        stop = _adjust_index(expect_int(sl.stop), length, neg);
    }
    return [start, stop, step];
}

def _slice_objs(items: list[PyObj], sl: PySlice) -> list[PyObj] {
    b = slice_indices(sl, len(items));
    i = b[0];
    stop = b[1];
    step = b[2];
    out: list[PyObj] = [];
    if step > 0 {
        while i < stop {
            out.append(items[i]);
            i = i + step;
        }
    } else {
        while i > stop {
            out.append(items[i]);
            i = i + step;
        }
    }
    return out;
}

def _slice_ints(vals: list[int], sl: PySlice) -> list[int] {
    b = slice_indices(sl, len(vals));
    i = b[0];
    stop = b[1];
    step = b[2];
    out: list[int] = [];
    if step > 0 {
        while i < stop {
            out.append(vals[i]);
            i = i + step;
        }
    } else {
        while i > stop {
            out.append(vals[i]);
            i = i + step;
        }
    }
    return out;
}

def _slice_str(s: str, sl: PySlice) -> str {
    b = slice_indices(sl, len(s));
    i = b[0];
    stop = b[1];
    step = b[2];
    out = "";
    if step > 0 {
        while i < stop {
            out = out + s[i];
            i = i + step;
        }
    } else {
        while i > stop {
            out = out + s[i];
            i = i + step;
        }
    }
    return out;
}

# ---------------- str %-format (CPython PyUnicode_Format subset) ----------------
# na-clean: integer bases are built from digit tables (no host str()/hex()); the
# only intrinsic used is chr() for %c (primitives_native). Covers conversions
# d i u o x X c s r %; flags - + space 0 #; field width; precision; and both the
# tuple/single-value and %(key) mapping argument conventions.
def _digit_val(c: str) -> int {
    digits = "0123456789";
    j = 0;
    while j < 10 {
        if digits[j] == c {
            return j;
        }
        j = j + 1;
    }
    return -1;
}

def _is_digit(c: str) -> bool {
    return _digit_val(c) >= 0;
}

def _uint_to_str(n: int, base: int, digits: str) -> str {
    if n == 0 {
        return "0";
    }
    out = "";
    while n > 0 {
        out = digits[n % base] + out;
        n = n // base;
    }
    return out;
}

# Conversion flags packed into a bitmask: - + space 0 #.
glob F_MINUS: int = 1,
     F_PLUS: int = 2,
     F_SPACE: int = 4,
     F_ZERO: int = 8,
     F_HASH: int = 16;

def _fmt_int(
    val: int, base: int, digits: str, prefix: str, flags: int, prec: int, width: int
) -> str {
    neg = val < 0;
    mag = val;
    if neg {
        mag = -val;
    }
    body = _uint_to_str(mag, base, digits);
    if prec >= 0 {
        while len(body) < prec {
            body = "0" + body;
        }
    }
    sign = "";
    if neg {
        sign = "-";
    } elif (flags & F_PLUS) != 0 {
        sign = "+";
    } elif (flags & F_SPACE) != 0 {
        sign = " ";
    }
    pfx = "";
    if (flags & F_HASH) != 0 and mag != 0 {
        pfx = prefix;
    }
    # zero-fill goes between the sign/prefix and the digits, and only when there
    # is no explicit precision and the field is right-justified.
    if (flags & F_ZERO) != 0 and (flags & F_MINUS) == 0 and prec < 0 {
        total = len(sign) + len(pfx) + len(body);
        while total < width {
            body = "0" + body;
            total = total + 1;
        }
    }
    return sign + pfx + body;
}

def _int_of(o: PyObj) -> int {
    if isinstance(o, PyBool) {
        if (o as PyBool).val {
            return 1;
        }
        return 0;
    }
    if isinstance(o, PyInt) {
        return (o as PyInt).val;
    }
    return 0;
}

def _is_intlike(o: PyObj) -> bool {
    return isinstance(o, PyInt) or isinstance(o, PyBool);
}

def _pyobj_str(o: PyObj) -> str {
    if isinstance(o, PyStr) {
        return (o as PyStr).val;
    }
    if isinstance(o, PyBool) {
        if (o as PyBool).val {
            return "True";
        }
        return "False";
    }
    if isinstance(o, PyInt) {
        return _fmt_int((o as PyInt).val, 10, "0123456789", "", 0, -1, 0);
    }
    if isinstance(o, PyNoneType) {
        return "None";
    }
    return "<object>";
}

def _pyobj_repr(o: PyObj) -> str {
    if isinstance(o, PyStr) {
        return "'" + (o as PyStr).val + "'";
    }
    return _pyobj_str(o);
}

def _pad_spaces(s: str, width: int, left: bool) -> str {
    while len(s) < width {
        if left {
            s = s + " ";
        } else {
            s = " " + s;
        }
    }
    return s;
}

def _trunc(s: str, prec: int) -> str {
    if prec < 0 or len(s) <= prec {
        return s;
    }
    out = "";
    i = 0;
    while i < prec {
        out = out + s[i];
        i = i + 1;
    }
    return out;
}

def str_mod_format(fmt: str, args: PyObj) -> PyObj {
    argv: list[PyObj] = [];
    mapping = False;
    if isinstance(args, PyTuple) {
        argv = (args as PyTuple).items;
    } elif isinstance(args, PyDict) {
        mapping = True;
    } else {
        argv.append(args);
    }
    ai = 0;
    out = "";
    n = len(fmt);
    i = 0;
    while i < n {
        c = fmt[i];
        if c != "%" {
            out = out + c;
            i = i + 1;
            continue;
        }
        i = i + 1;
        if i >= n {
            return py_error("ValueError", "incomplete format");
        }
        if fmt[i] == "%" {
            out = out + "%";
            i = i + 1;
            continue;
        }
        key = "";
        haskey = False;
        if fmt[i] == "(" {
            i = i + 1;
            while i < n and fmt[i] != ")" {
                key = key + fmt[i];
                i = i + 1;
            }
            if i >= n {
                return py_error("ValueError", "incomplete format key");
            }
            i = i + 1;
            haskey = True;
        }
        flags = 0;
        while i < n {
            f = fmt[i];
            if f == "-" {
                flags = flags | F_MINUS;
                i = i + 1;
            } elif f == "+" {
                flags = flags | F_PLUS;
                i = i + 1;
            } elif f == " " {
                flags = flags | F_SPACE;
                i = i + 1;
            } elif f == "0" {
                flags = flags | F_ZERO;
                i = i + 1;
            } elif f == "#" {
                flags = flags | F_HASH;
                i = i + 1;
            } else {
                break;
            }
        }
        fminus = (flags & F_MINUS) != 0;
        width = 0;
        while i < n and _is_digit(fmt[i]) {
            width = width * 10 + _digit_val(fmt[i]);
            i = i + 1;
        }
        prec = -1;
        if i < n and fmt[i] == "." {
            i = i + 1;
            prec = 0;
            while i < n and _is_digit(fmt[i]) {
                prec = prec * 10 + _digit_val(fmt[i]);
                i = i + 1;
            }
        }
        while i < n and (fmt[i] == "l" or fmt[i] == "h" or fmt[i] == "L") {
            i = i + 1;
        }
        if i >= n {
            return py_error("ValueError", "incomplete format");
        }
        conv = fmt[i];
        i = i + 1;

        arg: PyObj = py_none();
        if haskey {
            if not mapping {
                return py_error("TypeError", "format requires a mapping");
            }
            d = (args as PyDict).items;
            if key in d {
                arg = d[key];
            } else {
                return py_error("KeyError", key);
            }
        } else {
            if ai >= len(argv) {
                return py_error("TypeError", "not enough arguments for format string");
            }
            arg = argv[ai];
            ai = ai + 1;
        }

        piece = "";
        if conv == "d" or conv == "i" or conv == "u" {
            if not _is_intlike(arg) {
                return py_error("TypeError", "%d format: a number is required");
            }
            piece = _fmt_int(_int_of(arg), 10, "0123456789", "", flags, prec, width);
        } elif conv == "x" {
            if not _is_intlike(arg) {
                return py_error("TypeError", "%x format: an integer is required");
            }
            piece = _fmt_int(
                _int_of(arg), 16, "0123456789abcdef", "0x", flags, prec, width
            );
        } elif conv == "X" {
            if not _is_intlike(arg) {
                return py_error("TypeError", "%X format: an integer is required");
            }
            piece = _fmt_int(
                _int_of(arg), 16, "0123456789ABCDEF", "0X", flags, prec, width
            );
        } elif conv == "o" {
            if not _is_intlike(arg) {
                return py_error("TypeError", "%o format: an integer is required");
            }
            piece = _fmt_int(_int_of(arg), 8, "01234567", "0o", flags, prec, width);
        } elif conv == "c" {
            if _is_intlike(arg) {
                piece = chr(_int_of(arg));
            } elif isinstance(arg, PyStr) {
                piece = (arg as PyStr).val;
            } else {
                return py_error("TypeError", "%c requires int or char");
            }
        } elif conv == "s" {
            piece = _trunc(_pyobj_str(arg), prec);
        } elif conv == "r" {
            piece = _trunc(_pyobj_repr(arg), prec);
        } else {
            return py_error("ValueError", "unsupported format character");
        }
        out = out + _pad_spaces(piece, width, fminus);
    }
    if (not mapping) and ai < len(argv) {
        return py_error(
            "TypeError", "not all arguments converted during string formatting"
        );
    }
    return PyStr(t="str", val=out);
}
