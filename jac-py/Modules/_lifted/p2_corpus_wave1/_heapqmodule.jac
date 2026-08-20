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
obj unaryfunc {
    def call() -> PyObj {
        ;
    }
}
@__jac_value__
obj richcmpfunc {
    def call() -> int {
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
    has sq_item: ssizeargfunc = ssizeargfunc();
}

@__jac_value__
obj PyTypeObject {
    has tp_name: str = str();
    has tp_as_sequence: PySequenceMethods = PySequenceMethods();
    has tp_richcompare: richcmpfunc = richcmpfunc();
}

@__jac_value__
obj PyListObject {
    has ob_base: PyObject = PyObject();
    has ob_size: int = 0;
    has ob_item: object = object();
}

@__jac_value__
obj PyObject {
    has ob_type: PyTypeObject = PyTypeObject();
}

glob PyObj = PyObject;


glob PyExc_IndexError: PyObj = PyObj();
glob PyExc_RuntimeError: PyObj = PyObj();

def siftdown(heap: PyListObject, startpos: int, pos: int) -> int {
    newitem: PyObj = PyObj();
    parent: PyObj = PyObj();
    arr: object = object();
    parentpos: int = 0;
    size: int = 0;
    cmp: int = 0;

    size = heap.ob_size;
    if (pos >= size) {
        raise IndexError("index out of range");
    }

    arr = heap.ob_item;
    newitem = arr[pos];
    while (pos > startpos) {
        parentpos = (pos - 1) >> 1;
        parent = arr[parentpos];
        ;
        ;
        cmp = PyObject_RichCompareBool(newitem, parent, 0);
        ;
        ;
        if (cmp < 0) {
            return -1;
        }
        if (size != heap.ob_size) {
            raise RuntimeError("list changed size during iteration");
        }

        if (cmp == 0) {
            break;
        }
        arr = heap.ob_item;
        arr[pos] = parent;
        arr[parentpos] = newitem;
        pos = parentpos;
    }

    return 0;
}

def heap_siftdown(heap: PyObj, startpos: int, pos: int) -> int {
    return siftdown(heap, startpos, pos);
}
