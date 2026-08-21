# c2jac: 2 best-effort sites lowered with known infidelities (behavior/hole sites quarantine their containing function; module-scope holes remain as `__c_unsupported__`):
#   L574 [W4201] cast to `char` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L574 [W4201] cast to `char` elided — representation-changing conversion (truncation/narrowing/discard) not applied

glob ptrdiff_t = int;
glob size_t = int;
glob ssize_t = int;
glob intptr_t = int;
glob uintptr_t = int;

glob int8_t = int;
glob uint8_t = int;
glob int16_t = int;
glob uint16_t = int;
glob int32_t = int;
glob uint32_t = int;
glob int64_t = int;
glob uint64_t = int;

glob intmax_t = int;
glob uintmax_t = int;

glob int_least8_t = int;
glob uint_least8_t = int;
glob int_least16_t = int;
glob uint_least16_t = int;
glob int_least32_t = int;
glob uint_least32_t = int;
glob int_least64_t = int;
glob uint_least64_t = int;

glob int_fast8_t = int;
glob uint_fast8_t = int;
glob int_fast16_t = int;
glob uint_fast16_t = int;
glob int_fast32_t = int;
glob uint_fast32_t = int;
glob int_fast64_t = int;
glob uint_fast64_t = int;
glob Py_ssize_t = int;
glob Py_hash_t = int;

@__jac_value__
obj PyVarObject {
    has ob_base: PyObject = PyObject();
    has ob_size: int = 0;
}

glob digit = int;
glob stwodigits = int;
glob sdigit = int;
glob _Pyuintptr_t = int;
glob Py_uhash_t = int;


@__jac_value__
obj lenfunc {
    def call() -> int {
        ;
    }
}
@__jac_value__
obj unaryfunc {
    def call() -> PyObj {
        ;
    }
}
@__jac_value__
obj binaryfunc {
    def call() -> PyObj {
        ;
    }
}
@__jac_value__
obj inquiry {
    def call() -> int {
        ;
    }
}
@__jac_value__
obj vectorcallfunc {
    def call() -> PyObj {
        ;
    }
}
@__jac_value__
obj hashfunc {
    def call() -> int {
        ;
    }
}
@__jac_value__
obj richcmpfunc {
    def call() -> PyObj {
        ;
    }
}
@__jac_value__
obj getiterfunc {
    def call() -> PyObj {
        ;
    }
}
@__jac_value__
obj iternextfunc {
    def call() -> PyObj {
        ;
    }
}
@__jac_value__
obj ssizeargfunc {
    def call() -> PyObj {
        ;
    }
}

@__jac_value__
obj PySequenceMethods {
    has sq_length: lenfunc = lenfunc();
    has sq_item: ssizeargfunc = ssizeargfunc();
    has sq_contains: inquiry = inquiry();
}

@__jac_value__
obj PyNumberMethods {
    has nb_add: binaryfunc = binaryfunc();
    has nb_subtract: binaryfunc = binaryfunc();
    has nb_multiply: binaryfunc = binaryfunc();
    has nb_remainder: binaryfunc = binaryfunc();
    has nb_divmod: binaryfunc = binaryfunc();
    has nb_power: binaryfunc = binaryfunc();
    has nb_negative: binaryfunc = binaryfunc();
    has nb_positive: binaryfunc = binaryfunc();
    has nb_absolute: binaryfunc = binaryfunc();
    has nb_bool: inquiry = inquiry();
    has nb_invert: unaryfunc = unaryfunc();
    has nb_lshift: binaryfunc = binaryfunc();
    has nb_rshift: binaryfunc = binaryfunc();
    has nb_and: binaryfunc = binaryfunc();
    has nb_xor: binaryfunc = binaryfunc();
    has nb_or: binaryfunc = binaryfunc();
}

@__jac_value__
obj PyObject {
    has ob_type: PyTypeObject = PyTypeObject();
}

@__jac_value__
obj PyTypeObject {
    has ob_base: PyObject = PyObject();
    has ob_size: int = 0;
    has tp_name: str = str();
    has tp_basicsize: int = 0;
    has tp_itemsize: int = 0;
    has tp_dealloc: object = object();
    has tp_repr: unaryfunc = unaryfunc();
    has tp_as_number: PyNumberMethods = PyNumberMethods();
    has tp_as_sequence: PySequenceMethods = PySequenceMethods();
    has tp_hash: hashfunc = hashfunc();
    has tp_richcompare: richcmpfunc = richcmpfunc();
    has tp_iter: getiterfunc = getiterfunc();
    has tp_iternext: iternextfunc = iternextfunc();
    has tp_flags: int = 0;
    has tp_doc: str = str();
    has tp_base: PyTypeObject = PyTypeObject();
    has tp_vectorcall: vectorcallfunc = vectorcallfunc();
}

@__jac_value__
obj _PyLongValue {
    has lv_tag: int = 0;
    has ob_digit: list = list();
}

@__jac_value__
obj PyLongObject {
    has ob_base: PyObject = PyObject();
    has long_value: _PyLongValue = _PyLongValue();
}


glob Py_UCS1 = int;

@__jac_value__
obj PyBytesObject {
    has ob_base: PyObject = PyObject();
    has ob_size: int = 0;
    has ob_hash: int = 0;
    has ob_sval: list = list();
}


def set_ob_shash(a: PyBytesObject, hash: int) -> None {
    a.ob_hash = hash;
}

def get_ob_shash(a: PyBytesObject) -> int {
    return a.ob_hash;
}

glob size_t = int;
glob __builtin_va_list = int;
glob __gnuc_va_list = int;
glob va_list = int;
glob __int8_t = int;
glob __uint8_t = int;
glob __int16_t = int;
glob __uint16_t = int;
glob __int_least16_t = int;
glob __uint_least16_t = int;
glob __int32_t = int;
glob __uint32_t = int;
glob __int64_t = int;
glob __uint64_t = int;
glob __int_least32_t = int;
glob __uint_least32_t = int;
glob __s8 = int;
glob __u8 = int;
glob __s16 = int;
glob __u16 = int;
glob __s32 = int;
glob __u32 = int;
glob __s64 = int;
glob __u64 = int;
glob _LOCK_T = int;
glob _LOCK_RECURSIVE_T = int;
glob _off_t = int;
glob __dev_t = int;
glob __uid_t = int;
glob __gid_t = int;
glob _off64_t = int;
glob _fpos_t = int;
glob _ssize_t = int;
glob wint_t = int;
glob _mbstate_t = int;
glob _flock_t = int;
glob _iconv_t = int;
glob __ULong = int;
glob __FILE = int;
glob ptrdiff_t = int;
glob wchar_t = int;
glob char16_t = int;
glob char32_t = int;
glob __off_t = int;
glob __pid_t = int;
glob __loff_t = int;
glob u_char = int;
glob u_short = int;
glob u_int = int;
glob u_long = int;
glob ushort = int;
glob uint = int;
glob clock_t = int;
glob time_t = int;
glob daddr_t = int;
glob caddr_t = int;
glob ino_t = int;
glob off_t = int;
glob dev_t = int;
glob uid_t = int;
glob gid_t = int;
glob pid_t = int;
glob key_t = int;
glob ssize_t = int;
glob mode_t = int;
glob nlink_t = int;
glob fd_mask = int;
glob _types_fd_set = int;
glob clockid_t = int;
glob timer_t = int;
glob useconds_t = int;
glob suseconds_t = int;
glob FILE = int;
glob fpos_t = int;
glob cookie_read_function_t = int;
glob cookie_write_function_t = int;
glob cookie_seek_function_t = int;
glob cookie_close_function_t = int;
glob cookie_io_functions_t = int;
glob div_t = int;
glob ldiv_t = int;
glob lldiv_t = int;
glob sigset_t = int;
glob __sigset_t = int;
glob _sig_func_ptr = int;
glob sig_atomic_t = int;
glob __tzrule_type = int;
glob __tzinfo_type = int;
glob mbstate_t = int;
glob sem_t = int;
glob pthread_t = int;
glob pthread_attr_t = int;
glob pthread_mutex_t = int;
glob pthread_mutexattr_t = int;
glob pthread_cond_t = int;
glob pthread_condattr_t = int;
glob pthread_key_t = int;
glob pthread_once_t = int;
glob pthread_rwlock_t = int;
glob pthread_rwlockattr_t = int;
glob pthread_spinlock_t = int;
glob pthread_barrier_t = int;
glob pthread_barrierattr_t = int;
glob jmp_buf = int;
glob rlim_t = int;
glob sa_family_t = int;
glob sigjmp_buf = int;
glob stack_t = int;
glob siginfo_t = int;
glob z_stream = int;

glob int8_t = int;
glob uint8_t = int;
glob int16_t = int;
glob uint16_t = int;
glob int32_t = int;
glob uint32_t = int;
glob int64_t = int;
glob uint64_t = int;

glob int_least8_t = int;
glob uint_least8_t = int;
glob int_least16_t = int;
glob uint_least16_t = int;
glob int_least32_t = int;
glob uint_least32_t = int;
glob int_least64_t = int;
glob uint_least64_t = int;

glob int_fast8_t = int;
glob uint_fast8_t = int;
glob int_fast16_t = int;
glob uint_fast16_t = int;
glob int_fast32_t = int;
glob uint_fast32_t = int;
glob int_fast64_t = int;
glob uint_fast64_t = int;

glob intptr_t = int;
glob uintptr_t = int;

glob intmax_t = int;
glob uintmax_t = int;

glob `bool = int;

glob MirEGLNativeWindowType = object;
glob MirEGLNativeDisplayType = object;

glob xcb_window_t = int;
glob xcb_visualid_t = int;

glob DIR = object;

glob __socklen_t = int;
glob socklen_t = int;
glob __kernel_sa_family_t = int;

glob atomic_bool = int;
glob atomic_char = int;
glob atomic_schar = int;
glob atomic_uchar = int;
glob atomic_short = int;
glob atomic_ushort = int;
glob atomic_int = int;
glob atomic_uint = int;
glob atomic_long = int;
glob atomic_ulong = int;
glob atomic_llong = int;
glob atomic_ullong = int;
glob atomic_char16_t = int;
glob atomic_char32_t = int;
glob atomic_wchar_t = int;
glob atomic_int_least8_t = int;
glob atomic_uint_least8_t = int;
glob atomic_int_least16_t = int;
glob atomic_uint_least16_t = int;
glob atomic_int_least32_t = int;
glob atomic_uint_least32_t = int;
glob atomic_int_least64_t = int;
glob atomic_uint_least64_t = int;
glob atomic_int_fast8_t = int;
glob atomic_uint_fast8_t = int;
glob atomic_int_fast16_t = int;
glob atomic_uint_fast16_t = int;
glob atomic_int_fast32_t = int;
glob atomic_uint_fast32_t = int;
glob atomic_int_fast64_t = int;
glob atomic_uint_fast64_t = int;
glob atomic_intptr_t = int;
glob atomic_uintptr_t = int;
glob atomic_size_t = int;
glob atomic_ptrdiff_t = int;
glob atomic_intmax_t = int;
glob atomic_uintmax_t = int;
@__jac_value__
obj atomic_flag {
    has _Value: atomic_bool = atomic_bool();
}

glob memory_order = int;

def bytes_compare_eq(a: PyBytesObject, b: PyBytesObject) -> int {
    cmp: int = 0;
    len: int = 0;

    len = a.ob_size;
    if (b.ob_size != len) {
        return 0;
    }

    if (a.ob_sval[0] != b.ob_sval[0]) {
        return 0;
    }

    cmp = memcmp(a.ob_sval, b.ob_sval, len);
    return (cmp == 0);
}

def _Py_bytes_contains(`str: str, len: int, arg: PyObj) -> int {
    ival: int = PyNumber_AsSsize_t(arg, 0);
    if ((ival == -1) and PyErr_Occurred()) {
        PyErr_Clear();
        return -1;
    }

    if ((ival < 0) or (ival >= 256)) {
        raise ValueError("byte must be in range(0, 256)");
    }

    return (memchr(`str, ival, len) != 0);
}

def bytes_contains(`self: PyObj, arg: PyObj) -> int {
    a: PyBytesObject = `self;
    return _Py_bytes_contains(a.ob_sval, a.ob_size, arg);
}

def bytes_richcompare(aa: PyObj, bb: PyObj, op: int) -> PyObj {
    if not ((aa.ob_type == PyBytes_Type) and (bb.ob_type == PyBytes_Type)) {
        return Py_NotImplemented;
    }

    a: PyBytesObject = aa;
    b: PyBytesObject = bb;
    if (a == b) {
        if op == 2 or op == 1 or op == 5 {
            return Py_True;
        } elif op == 3 or op == 0 or op == 4 {
            return Py_False;
        } else {
            PyErr_BadInternalCall();
            return 0;
        }
    } elif ((op == 2) or (op == 3)) {
        eq: int = bytes_compare_eq(a, b);
        eq ^= op == 3;
        return PyBool_FromLong(eq);
    } else {
        len_a: int = a.ob_size;
        len_b: int = b.ob_size;
        min_len: int = len_a if (len_a < len_b) else len_b;
        c: int = 0;
        if (min_len > 0) {
            c = a.ob_sval - b.ob_sval;
            if (c == 0) {
                c = memcmp(a.ob_sval, b.ob_sval, min_len);
            }
        } else {
            c = 0;
        }
        if (c != 0) {
            while True {
                if op == 2 {
                    if (c == 0) {
                        return Py_True;
                    }
                    return Py_False;
                } elif op == 3 {
                    if (c != 0) {
                        return Py_True;
                    }
                    return Py_False;
                } elif op == 0 {
                    if (c < 0) {
                        return Py_True;
                    }
                    return Py_False;
                } elif op == 4 {
                    if (c > 0) {
                        return Py_True;
                    }
                    return Py_False;
                } elif op == 1 {
                    if (c <= 0) {
                        return Py_True;
                    }
                    return Py_False;
                } elif op == 5 {
                    if (c >= 0) {
                        return Py_True;
                    }
                    return Py_False;
                } else {
                    PyErr_BadInternalCall();
                    return 0;
                }
                if not 0 {
                    break;
                }
            }
        }
        while True {
            if op == 2 {
                if (len_a == len_b) {
                    return Py_True;
                }
                return Py_False;
            } elif op == 3 {
                if (len_a != len_b) {
                    return Py_True;
                }
                return Py_False;
            } elif op == 0 {
                if (len_a < len_b) {
                    return Py_True;
                }
                return Py_False;
            } elif op == 4 {
                if (len_a > len_b) {
                    return Py_True;
                }
                return Py_False;
            } elif op == 1 {
                if (len_a <= len_b) {
                    return Py_True;
                }
                return Py_False;
            } elif op == 5 {
                if (len_a >= len_b) {
                    return Py_True;
                }
                return Py_False;
            } else {
                PyErr_BadInternalCall();
                return 0;
            }
            if not 0 {
                break;
            }
        }
    }
}

def bytes_hash(`self: PyObj) -> int {
    a: PyBytesObject = `self;
    hash: int = get_ob_shash(a);
    if (hash == -1) {
        hash = Py_HashBuffer(a.ob_sval, a.ob_size);
        set_ob_shash(a, hash);
    }

    return hash;
}
