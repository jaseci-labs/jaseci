# Native traceback module surface over the guest PyTraceback chain.
#
# A to_host arm for PyTraceback cannot work: host types.TracebackType needs a
# REAL host frame object and guest frames have no host counterpart. Instead the
# module is served natively -- extract/format/print walk the guest chain
# directly and reuse tb_render's linecache-backed frame formatting so the text
# degrades exactly like the interpreter (missing source -> line omitted).
#
# Divergences from Lib/traceback.py (documented, v1):
# - extract_tb returns a plain list of FrameSummary-shaped objects, not a
#   StackSummary list subclass (isinstance checks against traceback classes
#   fail; attribute access and iteration are congruent).
# - walk_tb returns a list, not a generator.
# - file= on print_* accepts only None (stderr); other files raise TypeError.
# - TracebackException / format_exc are not provided yet.

import from objects {
    PyObj,
    PyStr,
    PyInt,
    PyList,
    PyNoneType,
    py_error,
    py_none,
    PyTraceback,
    PyCode,
    PyException,
    is_error,
}
import from tb_render { _tb_linecache_getline, _tb_stderr_write, _tb_frame_text, tb_format }

# Walk a guest tb chain into parallel (frame_code, lineno) columns.
def _tb_collect(tb: any) -> tuple[list[PyCode], list[int]] {
    codes: list[PyCode] = [];
    linenos: list[int] = [];
    cur = tb;
    while cur is not None and isinstance(cur, PyTraceback) {
        tbe = cur as PyTraceback;
        if isinstance(tbe.code, PyCode) {
            codes.append(tbe.code as PyCode);
            linenos.append(tbe.tb_lineno);
        }
        cur = tbe.tb_next;
    }
    return (codes, linenos);
}

def _tb_apply_limit(codes: list[PyCode], linenos: list[int], limit: any) -> tuple[list[PyCode], list[int]] {
    if isinstance(limit, PyInt) {
        n = (limit as PyInt).val;
        if n < 0 {
            keep = -n;
            if keep < len(codes) {
                codes = codes[len(codes) - keep:];
                linenos = linenos[len(linenos) - keep:];
            }
        } else {
            if n < len(codes) {
                codes = codes[:n];
                linenos = linenos[:n];
            }
        }
    }
    return (codes, linenos);
}

# FrameSummary-shaped native object: attribute-congruent with Lib/traceback.py.
obj TBFrameSummaryObj(PyObj) {
    has fs_filename: str,
        fs_name: str,
        fs_lineno: int;

    def tp_getattro(name2: str) -> PyObj {
        if name2 == "filename" {
            return PyStr(t="str", val=self.fs_filename);
        }
        if name2 == "name" {
            return PyStr(t="str", val=self.fs_name);
        }
        if name2 == "lineno" {
            return PyInt(t="int", val=self.fs_lineno);
        }
        if name2 == "line" {
            text = _tb_linecache_getline(self.fs_filename, self.fs_lineno).strip();
            if text == "" {
                return py_none();
            }
            return PyStr(t="str", val=text);
        }
        return py_error("AttributeError", "'" + "FrameSummary" + "' object has no attribute '" + name2 + "'");
    }
}

obj TBExtractFn(PyObj) {
    # extract_tb(tb, limit=None) -> list[FrameSummary]
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "extract_tb expected at least 1 argument, got 0");
        }
        limit = py_none();
        if len(args) > 1 {
            limit = args[1];
        }
        (codes, linenos) = _tb_collect(args[0]);
        (codes, linenos) = _tb_apply_limit(codes, linenos, limit);
        out: list[PyObj] = [];
        for i in range(len(codes)) {
            out.append(
                TBFrameSummaryObj(
                    t="frame_summary",
                    fs_filename=codes[i].filename,
                    fs_name=codes[i].name,
                    fs_lineno=linenos[i],
                )
            );
        }
        return PyList(t="list", items=out);
    }
}

obj TBFormatTbFn(PyObj) {
    # format_tb(tb, limit=None) -> list[str]; joined output is byte-identical
    # to the interpreter's File/line/in block (repetition collapse included).
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "format_tb expected at least 1 argument, got 0");
        }
        limit = py_none();
        if len(args) > 1 {
            limit = args[1];
        }
        (codes, linenos) = _tb_collect(args[0]);
        (codes, linenos) = _tb_apply_limit(codes, linenos, limit);
        text = "";
        for i in range(len(codes)) {
            text = text + _tb_frame_text(codes[i].filename, linenos[i], codes[i].name);
        }
        lines: list[PyObj] = [];
        for piece in text.splitlines() {
            lines.append(PyStr(t="str", val=piece + "\n"));
        }
        return PyList(t="list", items=lines);
    }
}

obj TBPrintTbFn(PyObj) {
    # print_tb(tb, limit=None, file=None): only the default stream is served.
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 or len(args) > 3 {
            return py_error("TypeError", "print_tb() takes no keyword arguments");
        }
        if len(args) == 3 and not isinstance(args[2], PyNoneType) {
            return py_error("TypeError", "print_tb(): non-default file= not supported");
        }
        limit = py_none();
        if len(args) > 1 {
            limit = args[1];
        }
        (codes, linenos) = _tb_collect(args[0]);
        (codes, linenos) = _tb_apply_limit(codes, linenos, limit);
        text = "";
        for i in range(len(codes)) {
            text = text + _tb_frame_text(codes[i].filename, linenos[i], codes[i].name);
        }
        _tb_stderr_write(text);
        return py_none();
    }
}

# Shared formatter for format_exception/format_exc: native exceptions render
# through tb_format (full cause/context chain); user instances fall back to
# stack-only rendering off their __traceback__.
def format_exception_text(exc: PyObj) -> PyObj {
    if isinstance(exc, PyException) {
        text = tb_format(exc as PyException, None);
        return PyStr(t="str", val=text);
    }
    got_tb = exc.tp_getattro("__traceback__");
    if is_error(got_tb) or isinstance(got_tb, PyNoneType) {
        return PyStr(t="str", val="Traceback (most recent call last):\n");
    }
    (codes, linenos) = _tb_collect(got_tb);
    text = "Traceback (most recent call last):\n";
    for i in range(len(codes)) {
        text = text + _tb_frame_text(codes[i].filename, linenos[i], codes[i].name);
    }
    return PyStr(t="str", val=text);
}

obj TBFmtExcFn(PyObj) {
    # format_exception(exc, /, value, tb, limit=None): 3.14 one-arg form over
    # the full cause/context chain via tb_render's tb_format. Native exception
    # structs carry .traceback; user-defined instances fall back to their
    # __traceback__ attribute plus a stack-only rendering.
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "format_exception expected at least 1 argument, got 0");
        }
        exc = args[0];
        return PyList(t="list", items=[format_exception_text(exc)]);
    }
}

obj TBWalkFn(PyObj) {
    # walk_tb(tb): list of frames (divergence: CPython returns a generator).
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "walk_tb expected at least 1 argument, got 0");
        }
        frames: list[PyObj] = [];
        cur = args[0];
        while cur is not None and isinstance(cur, PyTraceback) {
            tbe = cur as PyTraceback;
            fr = tbe.tp_getattro("tb_frame");
            if not is_error(fr) {
                frames.append(fr);
            }
            cur = tbe.tb_next;
        }
        return PyList(t="list", items=frames);
    }
}

def traceback_module_attrs -> dict[str, PyObj] {
    return {
        "extract_tb": TBExtractFn(t="function"),
        "format_tb": TBFormatTbFn(t="function"),
        "print_tb": TBPrintTbFn(t="function"),
        "format_exception": TBFmtExcFn(t="function"),
        "walk_tb": TBWalkFn(t="function"),
    };
}
