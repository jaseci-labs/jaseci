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
import from opcode_meta {
    OP_CACHE,
    OP_RESUME,
    OP_LOAD_BUILD_CLASS,
    OP_LOAD_LOCALS,
    OP_NOT_TAKEN,
    OP_POP_TOP,
    OP_PUSH_EXC_INFO,
    OP_PUSH_NULL,
    OP_RETURN_VALUE,
    OP_BINARY_SLICE,
    OP_BUILD_SLICE,
    OP_STORE_SUBSCR,
    OP_UNARY_NOT,
    OP_WITH_EXCEPT_START,
    OP_BINARY_OP,
    OP_BUILD_LIST,
    OP_BUILD_MAP,
    OP_BUILD_TUPLE,
    OP_CALL,
    OP_CALL_KW,
    OP_COMPARE_OP,
    OP_COPY,
    OP_COPY_FREE_VARS,
    OP_END_FOR,
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
    OP_STORE_DEREF,
    OP_STORE_FAST,
    OP_DELETE_FAST,
    OP_STORE_NAME,
    OP_STORE_GLOBAL,
    OP_DELETE_GLOBAL,
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
    OP_LOAD_FAST_AND_CLEAR,
    OP_SEND,
    OP_END_SEND,
    OP_GET_YIELD_FROM_ITER,
    OP_GET_AWAITABLE,
    OP_CLEANUP_THROW,
    OP_DELETE_NAME,
    OP_UNARY_NEGATIVE,
    OP_UNARY_INVERT,
    OP_UNPACK_SEQUENCE,
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
# Opcode numbers and cache metadata: opcode_meta.jac (PLAN.md P0.1).

# The dispatchers below are thin adapters over the object model's virtual
# slots: they exist only so the ceval reads naturally. Behavior selection is
# the method call (self's vtable), never a tag comparison.
def py_truth(value: PyObj) -> bool {
    return value.tp_bool();
}
