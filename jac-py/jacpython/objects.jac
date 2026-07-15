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

    def nb_binop(kind: int, other: PyObj) -> PyObj { return py_error("TypeError", "unsupported operand types"); }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        if kind == 2 { return PyBool(t="bool", val=self.t == other.t); }
        if kind == 3 { return PyBool(t="bool", val=self.t != other.t); }
        return PyBool(t="bool", val=False);
    }

    def mp_subscript(index: PyObj) -> PyObj { return py_error("TypeError", "object is not subscriptable"); }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj { return py_error("TypeError", "object does not support item assignment"); }

    def tp_iter() -> PyObj { return py_error("TypeError", "object is not iterable"); }

    def tp_bool() -> bool { return True; }

    def tp_getattro(name: str) -> PyObj { return py_error("AttributeError", name); }

    def tp_setattro(name: str, value: PyObj) -> PyObj { return py_error("AttributeError", name); }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj { return py_error("TypeError", "object is not callable"); }
}

obj PyInt(PyObj) {
    has val: int;

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        if other.t != "int" { return py_error("TypeError", "unsupported operand types"); }
        b = (other as PyInt).val;
        a = self.val;
        if kind == 0 { return PyInt(t="int", val=a + b); }
        if kind == 5 { return PyInt(t="int", val=a * b); }
        if kind == 6 {
            if b == 0 { return py_error("ZeroDivisionError", "integer modulo by zero"); }
            return PyInt(t="int", val=a % b);
        }
        if kind == 10 { return PyInt(t="int", val=a - b); }
        if kind == 1 { return PyInt(t="int", val=a & b); }
        if kind == 2 {
            if b == 0 { return py_error("ZeroDivisionError", "integer division or modulo by zero"); }
            return PyInt(t="int", val=a // b);
        }
        if kind == 7 { return PyInt(t="int", val=a | b); }
        if kind == 11 { return PyInt(t="int", val=a ^ b); }
        if kind == 3 { return PyInt(t="int", val=a << b); }
        if kind == 9 { return PyInt(t="int", val=a >> b); }
        if kind == 8 { return PyInt(t="int", val=a ** b); }
        return py_error("TypeError", "unsupported operand types");
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        if other.t != "int" {
            if kind == 2 { return PyBool(t="bool", val=False); }
            if kind == 3 { return PyBool(t="bool", val=True); }
            return PyBool(t="bool", val=False);
        }
        a = self.val; b = (other as PyInt).val;
        if kind == 0 { return PyBool(t="bool", val=a < b); }
        if kind == 1 { return PyBool(t="bool", val=a <= b); }
        if kind == 2 { return PyBool(t="bool", val=a == b); }
        if kind == 3 { return PyBool(t="bool", val=a != b); }
        if kind == 4 { return PyBool(t="bool", val=a > b); }
        if kind == 5 { return PyBool(t="bool", val=a >= b); }
        return PyBool(t="bool", val=False);
    }

    def tp_bool() -> bool { return self.val != 0; }
}

obj PyStr(PyObj) {
    has val: str;

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        if kind == 0 and other.t == "str" { return PyStr(t="str", val=self.val + (other as PyStr).val); }
        return py_error("TypeError", "unsupported operand types");
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        if other.t != "str" {
            if kind == 2 { return PyBool(t="bool", val=False); }
            if kind == 3 { return PyBool(t="bool", val=True); }
            return PyBool(t="bool", val=False);
        }
        a = self.val; b = (other as PyStr).val;
        if kind == 0 { return PyBool(t="bool", val=a < b); }
        if kind == 1 { return PyBool(t="bool", val=a <= b); }
        if kind == 2 { return PyBool(t="bool", val=a == b); }
        if kind == 3 { return PyBool(t="bool", val=a != b); }
        if kind == 4 { return PyBool(t="bool", val=a > b); }
        if kind == 5 { return PyBool(t="bool", val=a >= b); }
        return PyBool(t="bool", val=False);
    }

    def mp_subscript(index: PyObj) -> PyObj {
        if index.t != "int" { return py_error("TypeError", "index must be an integer"); }
        i = (index as PyInt).val;
        text = self.val;
        if i < 0 { i = len(text) + i; }
        if i >= 0 and i < len(text) { return PyStr(t="str", val=text[i]); }
        return py_error("IndexError", "string index out of range");
    }

    def tp_iter() -> PyObj {
        chars: list[PyObj] = [];
        for ch in self.val { chars.append(PyStr(t="str", val=ch)); }
        return PyIter(t="iter", items=chars, index=0);
    }

    def tp_bool() -> bool { return len(self.val) != 0; }
}

obj PyBytes(PyObj) {
    has val: list[int];

    def mp_subscript(index: PyObj) -> PyObj {
        if index.t != "int" { return py_error("TypeError", "index must be an integer"); }
        i = (index as PyInt).val;
        vals = self.val;
        if i < 0 { i = len(vals) + i; }
        if i >= 0 and i < len(vals) { return PyInt(t="int", val=vals[i]); }
        return py_error("IndexError", "index out of range");
    }

    def tp_bool() -> bool { return len(self.val) != 0; }
}

obj PyFloat(PyObj) {
    has val: float;

    def tp_bool() -> bool { return self.val != 0.0; }
}

obj PyBool(PyObj) {
    has val: bool;

    def tp_bool() -> bool { return self.val; }
}

obj PyNoneType(PyObj) {
    def tp_bool() -> bool { return False; }
}

obj PyComplex(PyObj) {
    has real: float;
    has imag: float;
}

obj PyTuple(PyObj) {
    has items: list[PyObj];

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        if kind == 0 and other.t == "tuple" {
            return PyTuple(t="tuple", items=concat_items(self.items, (other as PyTuple).items));
        }
        return py_error("TypeError", "unsupported operand types");
    }

    def mp_subscript(index: PyObj) -> PyObj {
        if index.t != "int" { return py_error("TypeError", "index must be an integer"); }
        i = (index as PyInt).val;
        if i < 0 { i = len(self.items) + i; }
        if i >= 0 and i < len(self.items) { return self.items[i]; }
        return py_error("IndexError", "tuple index out of range");
    }

    def tp_iter() -> PyObj { return PyIter(t="iter", items=self.items, index=0); }

    def tp_bool() -> bool { return len(self.items) != 0; }
}

obj PyList(PyObj) {
    has items: list[PyObj];

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        if kind == 0 and other.t == "list" {
            return PyList(t="list", items=concat_items(self.items, (other as PyList).items));
        }
        return py_error("TypeError", "unsupported operand types");
    }

    def mp_subscript(index: PyObj) -> PyObj {
        if index.t != "int" { return py_error("TypeError", "index must be an integer"); }
        i = (index as PyInt).val;
        if i < 0 { i = len(self.items) + i; }
        if i >= 0 and i < len(self.items) { return self.items[i]; }
        return py_error("IndexError", "list index out of range");
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        if index.t != "int" { return py_error("TypeError", "list indices must be integers"); }
        i = (index as PyInt).val;
        if i < 0 { i = len(self.items) + i; }
        if i >= 0 and i < len(self.items) { self.items[i] = value; return py_none(); }
        return py_error("IndexError", "list assignment index out of range");
    }

    def tp_iter() -> PyObj { return PyIter(t="iter", items=self.items, index=0); }

    def tp_bool() -> bool { return len(self.items) != 0; }
}

obj PyCode(PyObj) {
    has argcount: int;
    has posonlyargcount: int;
    has kwonlyargcount: int;
    has stacksize: int;
    has flags: int;
    has co_code: list[int];
    has consts: list[PyObj];
    has names: list[str];
    has varnames: list[str];
    has cellvars: list[str];
    has freevars: list[str];
    has filename: str;
    has name: str;
    has qualname: str;
    has firstlineno: int;
    has linetable: list[int];
    has exceptiontable: list[int];
}

obj PyCell(PyObj) {
    has val: PyObj;
}

obj PyDict(PyObj) {
    has items: dict[str, PyObj];

    def mp_subscript(index: PyObj) -> PyObj {
        key = expect_str(index);
        if key in self.items { return self.items[key]; }
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
        if name in self.items { return self.items[name]; }
        return py_error("AttributeError", name);
    }

    def tp_bool() -> bool { return len(self.items) != 0; }
}

obj PyExceptionType(PyObj) {
    has name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        message = "";
        if len(args) > 0 { message = expect_str(args[0]); }
        return PyException(t="exception", type_name=self.name, message=message);
    }
}

obj PyException(PyObj) {
    has type_name: str;
    has message: str;
    has raw: any = None;
}

obj PyError(PyObj) {
    has exception: PyException;
    has lasti: int = -1;
}

obj PyIter(PyObj) {
    has items: list[PyObj];
    has index: int;
}

obj PyHandler(PyObj) {
    has start: int;
    has end: int;
    has target: int;
    has depth: int;
    has lasti: bool;
}

# ---------------- pure helpers (na-clean: isinstance/as, no MatchArch) ----------------

def bytes_value(o: PyObj) -> list[int] {
    if isinstance(o, PyBytes) { return (o as PyBytes).val; }
    return [];
}

def tuple_value(o: PyObj) -> list[PyObj] {
    if isinstance(o, PyTuple) { return (o as PyTuple).items; }
    return [];
}

def str_value(o: PyObj) -> str {
    if isinstance(o, PyStr) { return (o as PyStr).val; }
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
        if isinstance(it, PyInt) { result.append((it as PyInt).val); }
    }
    return result;
}

def expect_int(o: PyObj) -> int {
    if isinstance(o, PyInt) { return (o as PyInt).val; }
    return 0;
}

def expect_str(o: PyObj) -> str {
    if isinstance(o, PyStr) { return (o as PyStr).val; }
    return "";
}

def list_value(o: PyObj) -> list[PyObj] {
    if isinstance(o, PyList) { return (o as PyList).items; }
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
    while i < len(names) { if names[i] == name { return i; } i = i + 1; }
    return -1;
}

def py_none() -> PyObj { return PyNoneType(t="none"); }

def py_error(type_name: str, message: str) -> PyObj {
    return PyError(
        t="error",
        exception=PyException(t="exception", type_name=type_name, message=message),
    );
}

def py_exception_type(name: str) -> PyObj {
    return PyExceptionType(t="exception_type", name=name);
}

def is_error(value: PyObj) -> bool { return value.t == "error"; }
