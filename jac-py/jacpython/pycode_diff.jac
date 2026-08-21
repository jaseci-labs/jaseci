# PyCode structural differ and normalized disassembly (PLAN.md P0.2).
#
# Recursively compares jacpython PyCode objects field-by-field and reports the
# first divergence with a path (e.g. consts[2].co_code[14]). Also emits a
# normalized instruction listing so bytecode failures identify the first
# differing opcode rather than a raw byte mismatch.

import from objects {
    PyObj,
    PyCode,
    PyInt,
    PyStr,
    PyBytes,
    PyTuple,
    PyList,
    PyFloat,
    PyBool,
    PyNoneType,
    PyComplex,
    bytes_value,
    str_value,
    expect_int,
    is_error,
    py_error,
}
import from opcode_meta {
    OP_CACHE,
    OP_EXTENDED_ARG,
    OP_RESUME,
    OP_NOT_TAKEN,
    OP_NOP,
    OP_RETURN_VALUE,
    OP_LOAD_CONST,
    OP_LOAD_FAST,
    OP_STORE_FAST,
    OP_BINARY_OP,
    OP_COMPARE_OP,
    OP_CALL,
    OP_MAKE_FUNCTION,
    opcode_cache_count,
    instruction_width,
}

obj PyCodeDiff {
    has ok: bool,
        path: str,
        message: str;
}

def diff_ok -> PyCodeDiff {
    return PyCodeDiff(ok=True, path="", message="");
}

def diff_fail(path: str, message: str) -> PyCodeDiff {
    return PyCodeDiff(ok=False, path=path, message=message);
}

def _append_path(base: str, part: str) -> str {
    if base == "" {
        return part;
    }
    return base + "." + part;
}

def const_repr(c: PyObj) -> str {
    if isinstance(c, PyInt) {
        return "int(" + str((c as PyInt).val) + ")";
    }
    if isinstance(c, PyStr) {
        return "str(...)";
    }
    if isinstance(c, PyFloat) {
        return "float(" + str((c as PyFloat).val) + ")";
    }
    if isinstance(c, PyBool) {
        if (c as PyBool).val {
            return "True";
        }
        return "False";
    }
    if isinstance(c, PyNoneType) {
        return "None";
    }
    if isinstance(c, PyCode) {
        return "<code " + (c as PyCode).name + ">";
    }
    if isinstance(c, PyTuple) {
        return "tuple(len=" + str(len((c as PyTuple).items)) + ")";
    }
    if isinstance(c, PyList) {
        return "list(len=" + str(len((c as PyList).items)) + ")";
    }
    if isinstance(c, PyBytes) {
        return "bytes(len=" + str(len(bytes_value(c))) + ")";
    }
    if isinstance(c, PyComplex) {
        co = c as PyComplex;
        return "complex(" + str(co.real) + "," + str(co.imag) + ")";
    }
    return "<" + c.t + ">";
}

def compare_const(a: PyObj, b: PyObj, path: str) -> PyCodeDiff {
    if isinstance(a, PyCode) and isinstance(b, PyCode) {
        return pycode_diff(a as PyCode, b as PyCode, path);
    }
    if a.t != b.t {
        return diff_fail(path, "type mismatch: " + a.t + " vs " + b.t);
    }
    if isinstance(a, PyInt) {
        if (a as PyInt).val != (b as PyInt).val {
            return diff_fail(
                path,
                "int mismatch: "
                    + str((a as PyInt).val)
                    + " vs "
                    + str((b as PyInt).val)
            );
        }
        return diff_ok();
    }
    if isinstance(a, PyStr) {
        if str_value(a) != str_value(b) {
            return diff_fail(path, "str mismatch");
        }
        return diff_ok();
    }
    if isinstance(a, PyFloat) {
        av = (a as PyFloat).val;
        bv = (b as PyFloat).val;
        if av != av and bv != bv {
            return diff_ok();
        }
        if av != bv {
            return diff_fail(path, "float mismatch: " + str(av) + " vs " + str(bv));
        }
        return diff_ok();
    }
    if isinstance(a, PyBool) {
        if (a as PyBool).val != (b as PyBool).val {
            return diff_fail(path, "bool mismatch");
        }
        return diff_ok();
    }
    if isinstance(a, PyNoneType) {
        return diff_ok();
    }
    if isinstance(a, PyTuple) {
        at = (a as PyTuple).items;
        bt = (b as PyTuple).items;
        if len(at) != len(bt) {
            return diff_fail(path, "tuple length mismatch");
        }
        i = 0;
        while i < len(at) {
            d = compare_const(at[i], bt[i], _append_path(path, "[" + str(i) + "]"));
            if not d.ok {
                return d;
            }
            i = i + 1;
        }
        return diff_ok();
    }
    if isinstance(a, PyBytes) {
        ab = bytes_value(a);
        bb = bytes_value(b);
        if len(ab) != len(bb) {
            return diff_fail(path, "bytes length mismatch");
        }
        i = 0;
        while i < len(ab) {
            if ab[i] != bb[i] {
                return diff_fail(path, "bytes[" + str(i) + "] mismatch");
            }
            i = i + 1;
        }
        return diff_ok();
    }
    return diff_fail(path, "unsupported const type " + a.t);
}

def compare_str_list(a: list[str], b: list[str], path: str) -> PyCodeDiff {
    if len(a) != len(b) {
        return diff_fail(
            path, "length mismatch: " + str(len(a)) + " vs " + str(len(b))
        );
    }
    i = 0;
    while i < len(a) {
        if a[i] != b[i] {
            return diff_fail(
                path + "[" + str(i) + "]", "name mismatch: " + a[i] + " vs " + b[i]
            );
        }
        i = i + 1;
    }
    return diff_ok();
}

def compare_int_list(a: list[int], b: list[int], path: str) -> PyCodeDiff {
    if len(a) != len(b) {
        return diff_fail(
            path, "length mismatch: " + str(len(a)) + " vs " + str(len(b))
        );
    }
    i = 0;
    while i < len(a) {
        if a[i] != b[i] {
            return diff_fail(
                path + "[" + str(i) + "]",
                "byte mismatch at " + str(i) + ": " + str(a[i]) + " vs " + str(b[i])
            );
        }
        i = i + 1;
    }
    return diff_ok();
}

def pycode_diff(expected: PyCode, actual: PyCode, path: str) -> PyCodeDiff {
    if expected.argcount != actual.argcount {
        return diff_fail(
            path + ".argcount", str(expected.argcount) + " vs " + str(actual.argcount)
        );
    }
    if expected.posonlyargcount != actual.posonlyargcount {
        return diff_fail(
            path + ".posonlyargcount",
            str(expected.posonlyargcount) + " vs " + str(actual.posonlyargcount)
        );
    }
    if expected.kwonlyargcount != actual.kwonlyargcount {
        return diff_fail(
            path + ".kwonlyargcount",
            str(expected.kwonlyargcount) + " vs " + str(actual.kwonlyargcount)
        );
    }
    if expected.stacksize != actual.stacksize {
        return diff_fail(
            path + ".stacksize",
            str(expected.stacksize) + " vs " + str(actual.stacksize)
        );
    }
    if expected.flags != actual.flags {
        return diff_fail(
            path + ".flags", str(expected.flags) + " vs " + str(actual.flags)
        );
    }
    if expected.filename != actual.filename {
        return diff_fail(
            path + ".filename", expected.filename + " vs " + actual.filename
        );
    }
    if expected.name != actual.name {
        return diff_fail(path + ".name", expected.name + " vs " + actual.name);
    }
    if expected.qualname != actual.qualname {
        return diff_fail(
            path + ".qualname", expected.qualname + " vs " + actual.qualname
        );
    }
    if expected.firstlineno != actual.firstlineno {
        return diff_fail(
            path + ".firstlineno",
            str(expected.firstlineno) + " vs " + str(actual.firstlineno)
        );
    }
    d = compare_int_list(expected.co_code, actual.co_code, path + ".co_code");
    if not d.ok {
        return d;
    }
    d = compare_str_list(expected.names, actual.names, path + ".names");
    if not d.ok {
        return d;
    }
    d = compare_str_list(expected.varnames, actual.varnames, path + ".varnames");
    if not d.ok {
        return d;
    }
    d = compare_str_list(expected.cellvars, actual.cellvars, path + ".cellvars");
    if not d.ok {
        return d;
    }
    d = compare_str_list(expected.freevars, actual.freevars, path + ".freevars");
    if not d.ok {
        return d;
    }
    d = compare_int_list(expected.linetable, actual.linetable, path + ".linetable");
    if not d.ok {
        return d;
    }
    d = compare_int_list(
        expected.exceptiontable, actual.exceptiontable, path + ".exceptiontable"
    );
    if not d.ok {
        return d;
    }
    if len(expected.consts) != len(actual.consts) {
        return diff_fail(
            path + ".consts",
            "length mismatch: "
                + str(len(expected.consts))
                + " vs "
                + str(len(actual.consts))
        );
    }
    i = 0;
    while i < len(expected.consts) {
        d = compare_const(
            expected.consts[i],
            actual.consts[i],
            _append_path(path, "consts[" + str(i) + "]")
        );
        if not d.ok {
            return d;
        }
        i = i + 1;
    }
    return diff_ok();
}

def pycode_equal(a: PyCode, b: PyCode) -> bool {
    return pycode_diff(a, b, "code").ok;
}

def pycode_diff_message(a: PyCode, b: PyCode) -> str {
    d = pycode_diff(a, b, "code");
    if d.ok {
        return "";
    }
    return d.path + ": " + d.message;
}

def opcode_name(op: int) -> str {
    if op == OP_CACHE {
        return "CACHE";
    }
    if op == OP_RESUME {
        return "RESUME";
    }
    if op == OP_NOP {
        return "NOP";
    }
    if op == OP_NOT_TAKEN {
        return "NOT_TAKEN";
    }
    if op == OP_EXTENDED_ARG {
        return "EXTENDED_ARG";
    }
    if op == OP_RETURN_VALUE {
        return "RETURN_VALUE";
    }
    if op == OP_LOAD_CONST {
        return "LOAD_CONST";
    }
    if op == OP_LOAD_FAST {
        return "LOAD_FAST";
    }
    if op == OP_STORE_FAST {
        return "STORE_FAST";
    }
    if op == OP_BINARY_OP {
        return "BINARY_OP";
    }
    if op == OP_COMPARE_OP {
        return "COMPARE_OP";
    }
    if op == OP_CALL {
        return "CALL";
    }
    if op == OP_MAKE_FUNCTION {
        return "MAKE_FUNCTION";
    }
    return "OP_" + str(op);
}

# Normalized disassembly: one line per logical instruction at offset `ip`
# (code-unit index). Cache slots are folded into the parent instruction width.
def disassemble_lines(co: PyCode) -> list[str] {
    out: list[str] = [];
    code = co.co_code;
    ip = 0;
    ext_arg = 0;
    while ip < len(code) {
        if ip + 1 >= len(code) {
            out.append(str(ip) + " TRUNCATED");
            break;
        }
        start = ip;
        op = code[ip];
        arg = code[ip + 1];
        arg = arg | (ext_arg << 8);
        ext_arg = 0;
        if op == OP_EXTENDED_ARG {
            ext_arg = arg;
            ip = ip + 2;
            continue;
        }
        name = opcode_name(op);
        line = str(start) + " " + name + " " + str(arg);
        caches = opcode_cache_count(op);
        if caches > 0 {
            line = line + " (+cache " + str(caches) + ")";
        }
        out.append(line);
        ip = ip + instruction_width(op);
    }
    return out;
}

def dis_diff_first(expected: PyCode, actual: PyCode) -> str {
    el = disassemble_lines(expected);
    al = disassemble_lines(actual);
    n = len(el);
    if len(al) < n {
        n = len(al);
    }
    i = 0;
    while i < n {
        if el[i] != al[i] {
            return "instruction " + str(i) + ": " + el[i] + " vs " + al[i];
        }
        i = i + 1;
    }
    if len(el) != len(al) {
        return "instruction count: " + str(len(el)) + " vs " + str(len(al));
    }
    return "";
}
