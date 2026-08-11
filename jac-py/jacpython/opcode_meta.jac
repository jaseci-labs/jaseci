# CPython 3.14.6 opcode / code-object metadata (PLAN.md P0.1).
#
# Single version-pinned source for opcode numbers, inline-cache unit counts,
# binary-operator ids, comparison ids, and code-object flags. The VM
# (pyc_first.jac), assembler (future), and layer-4 oracle import FROM here so
# metadata cannot drift across modules.
#
# Ground truth: reference/cpython tag v3.14.6
#   Include/opcode_ids.h
#   Include/opcode.h          (NB_*)
#   Include/cpython/code.h    (CO_*)
#   Include/internal/pycore_opcode_metadata.h (_PyOpcode_Caches)
#
# na-clean leaf: no imports, no host calls.

# ---------------- instruction opcodes (opcode_ids.h) ----------------
glob OP_CACHE: int = 0,
     OP_BINARY_SLICE: int = 1,
     OP_BUILD_TEMPLATE: int = 2,
     OP_CALL_FUNCTION_EX: int = 4,
     OP_CHECK_EXC_MATCH: int = 6,
     OP_CLEANUP_THROW: int = 7,
     OP_DELETE_SUBSCR: int = 8,
     OP_END_FOR: int = 9,
     OP_END_SEND: int = 10,
     OP_FORMAT_SIMPLE: int = 12,
     OP_FORMAT_WITH_SPEC: int = 13,
     OP_GET_ITER: int = 16,
     OP_GET_YIELD_FROM_ITER: int = 19,
     OP_LOAD_BUILD_CLASS: int = 21,
     OP_LOAD_LOCALS: int = 22,
     OP_MAKE_FUNCTION: int = 23,
     OP_NOP: int = 27,
     OP_NOT_TAKEN: int = 28,
     OP_POP_EXCEPT: int = 29,
     OP_POP_ITER: int = 30,
     OP_POP_TOP: int = 31,
     OP_PUSH_EXC_INFO: int = 32,
     OP_PUSH_NULL: int = 33,
     OP_RETURN_GENERATOR: int = 34,
     OP_RETURN_VALUE: int = 35,
     OP_STORE_SUBSCR: int = 38,
     OP_TO_BOOL: int = 39,
     OP_UNARY_INVERT: int = 40,
     OP_UNARY_NEGATIVE: int = 41,
     OP_UNARY_NOT: int = 42,
     OP_WITH_EXCEPT_START: int = 43,
     OP_BINARY_OP: int = 44,
     OP_BUILD_LIST: int = 46,
     OP_BUILD_MAP: int = 47,
     OP_BUILD_SET: int = 48,
     OP_BUILD_SLICE: int = 49,
     OP_BUILD_STRING: int = 50,
     OP_BUILD_TUPLE: int = 51,
     OP_CALL: int = 52,
     OP_CALL_INTRINSIC_1: int = 53,
     OP_COMPARE_OP: int = 56,
     OP_CONTAINS_OP: int = 57,
     OP_CONVERT_VALUE: int = 58,
     OP_COPY: int = 59,
     OP_COPY_FREE_VARS: int = 60,
     OP_DELETE_ATTR: int = 61,
     OP_DELETE_FAST: int = 63,
     OP_DELETE_GLOBAL: int = 64,
     OP_DELETE_NAME: int = 65,
     OP_DICT_MERGE: int = 66,
     OP_DICT_UPDATE: int = 67,
     OP_EXTENDED_ARG: int = 69,
     OP_FOR_ITER: int = 70,
     OP_GET_AWAITABLE: int = 71,
     OP_IMPORT_FROM: int = 72,
     OP_IMPORT_NAME: int = 73,
     OP_IS_OP: int = 74,
     OP_JUMP_BACKWARD: int = 75,
     OP_JUMP_BACKWARD_NO_INTERRUPT: int = 76,
     OP_JUMP_FORWARD: int = 77,
     OP_LIST_APPEND: int = 78,
     OP_LIST_EXTEND: int = 79,
     OP_LOAD_ATTR: int = 80,
     OP_LOAD_COMMON_CONSTANT: int = 81,
     OP_LOAD_CONST: int = 82,
     OP_LOAD_DEREF: int = 83,
     OP_LOAD_FAST: int = 84,
     OP_LOAD_FAST_AND_CLEAR: int = 85,
     OP_LOAD_FAST_BORROW: int = 86,
     OP_LOAD_FAST_BORROW_2: int = 87,
     OP_LOAD_FAST_LOAD_FAST: int = 89,
     OP_LOAD_GLOBAL: int = 92,
     OP_LOAD_NAME: int = 93,
     OP_LOAD_SMALL_INT: int = 94,
     OP_LOAD_SPECIAL: int = 95,
     OP_LOAD_SUPER_ATTR: int = 96,
     OP_MAKE_CELL: int = 97,
     OP_MAP_ADD: int = 98,
     OP_POP_JUMP_IF_FALSE: int = 100,
     OP_POP_JUMP_IF_NONE: int = 101,
     OP_POP_JUMP_IF_NOT_NONE: int = 102,
     OP_POP_JUMP_IF_TRUE: int = 103,
     OP_RAISE_VARARGS: int = 104,
     OP_RERAISE: int = 105,
     OP_SEND: int = 106,
     OP_SET_ADD: int = 107,
     OP_SET_FUNCTION_ATTRIBUTE: int = 108,
     OP_SET_UPDATE: int = 109,
     OP_STORE_ATTR: int = 110,
     OP_STORE_DEREF: int = 111,
     OP_STORE_FAST: int = 112,
     OP_STORE_FAST_LOAD_FAST: int = 113,
     OP_STORE_FAST_STORE_FAST: int = 114,
     OP_STORE_GLOBAL: int = 115,
     OP_STORE_NAME: int = 116,
     OP_SWAP: int = 117,
     OP_UNPACK_SEQUENCE: int = 119,
     OP_YIELD_VALUE: int = 120,
     OP_RESUME: int = 128,
     OP_LOAD_CLOSURE: int = 261,
     OP_CALL_KW: int = 55;

# ---------------- binary-operator ids (opcode.h NB_*) ----------------
glob NB_ADD: int = 0,
     NB_AND: int = 1,
     NB_FLOOR_DIVIDE: int = 2,
     NB_LSHIFT: int = 3,
     NB_MATRIX_MULTIPLY: int = 4,
     NB_MULTIPLY: int = 5,
     NB_REMAINDER: int = 6,
     NB_OR: int = 7,
     NB_POWER: int = 8,
     NB_RSHIFT: int = 9,
     NB_SUBTRACT: int = 10,
     NB_TRUE_DIVIDE: int = 11,
     NB_XOR: int = 12,
     NB_INPLACE_ADD: int = 13,
     NB_INPLACE_AND: int = 14,
     NB_INPLACE_FLOOR_DIVIDE: int = 15,
     NB_INPLACE_LSHIFT: int = 16,
     NB_INPLACE_MATRIX_MULTIPLY: int = 17,
     NB_INPLACE_MULTIPLY: int = 18,
     NB_INPLACE_REMAINDER: int = 19,
     NB_INPLACE_OR: int = 20,
     NB_INPLACE_POWER: int = 21,
     NB_INPLACE_RSHIFT: int = 22,
     NB_INPLACE_SUBTRACT: int = 23,
     NB_INPLACE_TRUE_DIVIDE: int = 24,
     NB_INPLACE_XOR: int = 25,
     NB_SUBSCR: int = 26,
     NB_OPARG_LAST: int = 26;

# ---------------- rich-compare kinds (cmp_op tuple order) ----------------
glob CMP_LT: int = 0,
     CMP_LE: int = 1,
     CMP_EQ: int = 2,
     CMP_NE: int = 3,
     CMP_GT: int = 4,
     CMP_GE: int = 5;

# ---------------- code-object flags (code.h CO_*) ----------------
glob CO_OPTIMIZED: int = 1,
     CO_NEWLOCALS: int = 2,
     CO_VARARGS: int = 4,
     CO_VARKEYWORDS: int = 8,
     CO_NESTED: int = 16,
     CO_GENERATOR: int = 32,
     CO_COROUTINE: int = 128,
     CO_ITERABLE_COROUTINE: int = 256,
     CO_ASYNC_GENERATOR: int = 512,
     CO_FUTURE_DIVISION: int = 131072,
     CO_FUTURE_ABSOLUTE_IMPORT: int = 262144,
     CO_HAS_DOCSTRING: int = 67108864,
     CO_METHOD: int = 134217728;

# CPython locals-plus kind bit flags (marshal reader / symtable contract).
glob LP_LOCAL: int = 32,
     LP_CELL: int = 64,
     LP_FREE: int = 128;

# Inline-cache unit counts (_PyOpcode_Caches, 3.14.6). Each CACHE slot is one
# two-byte code unit (opcode OP_CACHE + arg). Jump targets and handler ranges
# count in code units, not bytes.
def opcode_cache_count(op: int) -> int {
    if op == OP_TO_BOOL {
        return 3;
    }
    if op == OP_STORE_SUBSCR {
        return 1;
    }
    if op == OP_SEND {
        return 1;
    }
    if op == OP_UNPACK_SEQUENCE {
        return 1;
    }
    if op == OP_STORE_ATTR {
        return 4;
    }
    if op == OP_LOAD_GLOBAL {
        return 4;
    }
    if op == OP_LOAD_SUPER_ATTR {
        return 1;
    }
    if op == OP_LOAD_ATTR {
        return 9;
    }
    if op == OP_COMPARE_OP {
        return 1;
    }
    if op == OP_CONTAINS_OP {
        return 1;
    }
    if op == OP_JUMP_BACKWARD {
        return 1;
    }
    if op == OP_POP_JUMP_IF_TRUE
    or op == OP_POP_JUMP_IF_FALSE
    or op == OP_POP_JUMP_IF_NONE
    or op == OP_POP_JUMP_IF_NOT_NONE {
        return 1;
    }
    if op == OP_FOR_ITER {
        return 1;
    }
    if op == OP_CALL or op == OP_CALL_KW {
        return 3;
    }
    if op == OP_BINARY_OP {
        return 5;
    }
    return 0;
}

# Instruction width in code units: opcode+arg (2) plus cache padding.
def instruction_width(op: int) -> int {
    return 2 + opcode_cache_count(op);
}

# Advance ip past one instruction (including EXTENDED_ARG prefix chain).
def next_instruction_ip(code: list[int], ip: int) -> int {
    ext = 0;
    while ip < len(code) {
        op = code[ip];
        arg = code[ip + 1];
        arg = arg | (ext << 8);
        ext = 0;
        if op == OP_EXTENDED_ARG {
            ext = arg;
            ip = ip + 2;
            continue;
        }
        return ip + instruction_width(op);
    }
    return ip;
}
