# ceval slice for na_concat native build (extracted from pyc_first.jac).
# Grows incrementally toward full ceval; see jac-py/PLAN.md §4.

import from objects {
    PyObj,
    PyInt,
    PyStr,
    PyDict,
    PyNoneType,
    py_none,
    py_error,
    is_error,
    expect_int,
}

# Snapshot __dict__ builder (from pyc_first.jac; depends only on objects leaf).
def dict_from_str_map(m: dict[str, PyObj]) -> PyDict {
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

obj PyNoOpInit(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return py_none();
    }
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
