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
# - TracebackException.format() returns a list of strings, not a generator
#   (CPython's generator feeds an _ExceptionPrintContext that flattens frame
#   lines into one stream anyway; the list holds exactly those items).
# - TracebackException.format() omits the PEP 657 caret range markers
#   (~~~~^^^) under resolved source lines: they require column-precise
#   end_lineno/end_offset positions the guest PyTraceback chain does not
#   carry (the same degradation as the native uncaught-display path).
# - TracebackException.exc_type returns the type NAME string. CPython 3.13+
#   stores the class behind a deprecated property that emits a DeprecationWarning
#   and returns it; guest type objects are name-keyed so the string is the
#   faithful capture here (exc_type_str is congruent).
# - TracebackException keeps .value/.tb references (convenience surface the
#   CPython class deliberately drops -- its docstring promises "no references
#   are held"); rendering behavior is unaffected.
# - TracebackException.capture_locals is accepted and ignored; limit= applies
#   to stack frames but skips the repetition collapse on the limited path.
# - format_exc is not provided yet.

import from objects {
    PyObj,
    PyStr,
    PyInt,
    PyList,
    PyBool,
    PyNoneType,
    py_error,
    py_none,
    PyTraceback,
    PyCode,
    PyException,
    is_error,
}
import from exceptions_core { _obj_to_str }
import from tb_render {
    _tb_linecache_getline,
    _tb_stderr_write,
    _tb_frame_text,
    _tb_chain_exc,
    _tb_suppress_context,
    tb_format,
    tb_format_stack,
    tb_exception_only,
    _TB_CAUSE_MESSAGE,
    _TB_CONTEXT_MESSAGE,
}
import from exceptions_core { baseexception_str }

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

# ---- TracebackException ----------------------------------------------------
#
# A captured snapshot of one exception ready for rendering (Lib/traceback.py
# class of the same name). Construction walks the guest exception chain ONCE
# and copies everything format needs onto TBExcObj instances -- cause/context
# become sub-snapshots honoring compact/suppress_context with identity-based
# cycle dropping (the _seen set), so later mutation of the live exceptions
# cannot change what a format() call renders.

def _kw_truthy(v: PyObj) -> bool {
    if isinstance(v, PyNoneType) {
        return False;
    }
    if isinstance(v, PyBool) {
        return (v as PyBool).val;
    }
    if isinstance(v, PyInt) {
        return (v as PyInt).val != 0;
    }
    return True;
}

# Stack capture shared by construction: frame units (each ending in a
# newline, one string per frame with the source line embedded -- the
# StackSummary.format item shape) plus FrameSummary-shaped objects.
# Unlimited stacks render through tb_render's tb_format_stack so the
# repetition collapse stays byte-identical with the interpreter, then get
# re-split into per-frame units (a marker line is its own unit, matching
# CPython appending the marker as a separate item); a limit= path renders
# the truncated frames directly.
def _tbe_split_units(text: str) -> list[str] {
    units: list[str] = [];
    cur = "";
    for piece in text.splitlines() {
        ln = piece + "\n";
        if piece.startswith("  [Previous line repeated") {
            if cur != "" {
                units.append(cur);
                cur = "";
            }
            units.append(ln);
        } elif piece.startswith("  File \"") {
            if cur != "" {
                units.append(cur);
            }
            cur = ln;
        } else {
            cur = cur + ln;
        }
    }
    if cur != "" {
        units.append(cur);
    }
    return units;
}

def _tbe_capture_stack(tb: any, limit: any) -> tuple[list[str], list[PyObj]] {
    (codes, linenos) = _tb_collect(tb);
    (codes, linenos) = _tb_apply_limit(codes, linenos, limit);
    frames: list[PyObj] = [];
    for i in range(len(codes)) {
        frames.append(
            TBFrameSummaryObj(
                t="frame_summary",
                fs_filename=codes[i].filename,
                fs_name=codes[i].name,
                fs_lineno=linenos[i],
            )
        );
    }
    text = "";
    if isinstance(limit, PyNoneType) {
        text = tb_format_stack(tb);
    } else {
        for i in range(len(codes)) {
            text = text + _tb_frame_text(codes[i].filename, linenos[i], codes[i].name);
        }
    }
    lines: list[str] = [];
    if text != "" {
        lines = _tbe_split_units(text);
    }
    return (lines, frames);
}

# Recursive chain walk: build the TBExcObj snapshot for one exception plus its
# cause/context. `seen` carries every exception visited on this walk; a chained
# exception already seen is dropped silently (CPython's id-not-in-_seen rule).
# Returns py_none() when the chain arm must stay unset.
def _tbe_capture(exc: PyObj, tb: any, limit: any, compact: bool,
    seen: list[PyObj]) -> PyObj {
    seen.append(exc);

    exc_type_name = "";
    final = "";
    suppress = False;
    cause_obj: PyObj | None = None;
    context_obj: PyObj | None = None;

    if isinstance(exc, PyException) {
        e = exc as PyException;
        exc_type_name = e.type_name;
        final = tb_exception_only(e, None, None);
        suppress = _tb_suppress_context(e);

        cand = _tb_chain_exc(e.cause);
        if cand is not None and not _seen_has(seen, cand as PyObj) {
            sub = _tbe_capture(
                cand as PyObj, (cand as PyException).traceback, limit, compact, seen
            );
            if not is_error(sub) {
                cause_obj = sub;
            }
        }

        # CPython's need_context: with compact=True an implicit context is
        # dropped whenever an explicit cause exists or suppression is set.
        need_context = True;
        if compact {
            need_context = cause_obj is None and not suppress;
        }
        cctx = _tb_chain_exc(e.context);
        if cctx is not None and need_context and not _seen_has(seen, cctx as PyObj) {
            sub2 = _tbe_capture(
                cctx as PyObj, (cctx as PyException).traceback, limit, compact, seen
            );
            if not is_error(sub2) {
                context_obj = sub2;
            }
        }
    } else {
        # User-instance fallback (raw instance not wrapped as PyException):
        # mirror format_exception_text's attribute-driven degradation.
        cls = exc.tp_getattro("__class__");
        if not is_error(cls) {
            nm = cls.tp_getattro("__name__");
            if not is_error(nm) and isinstance(nm, PyStr) {
                exc_type_name = (nm as PyStr).val;
            }
        }
        valuestr = _obj_to_str(exc, None);
        if valuestr == "" {
            final = exc_type_name + "\n";
        } else {
            final = exc_type_name + ": " + valuestr + "\n";
        }
        sup_attr = exc.tp_getattro("__suppress_context__");
        if not is_error(sup_attr) {
            suppress = _kw_truthy(sup_attr);
        }
        cause_attr = exc.tp_getattro("__cause__");
        if not is_error(cause_attr) and not isinstance(cause_attr, PyNoneType) {
            sub3 = _tbe_capture(
                cause_attr, _attr_tb(cause_attr), limit, compact, seen
            );
            if not is_error(sub3) {
                cause_obj = sub3;
            }
        }
        ctx_attr = exc.tp_getattro("__context__");
        need_ctx2 = True;
        if compact {
            need_ctx2 = cause_obj is None and not suppress;
        }
        if (
            not is_error(ctx_attr)
            and not isinstance(ctx_attr, PyNoneType)
            and need_ctx2
        ) {
            sub4 = _tbe_capture(
                ctx_attr, _attr_tb(ctx_attr), limit, compact, seen
            );
            if not is_error(sub4) {
                context_obj = sub4;
            }
        }
    }

    (lines, frames) = _tbe_capture_stack(tb, limit);
    return TBExcObj(
        t="traceback_exception",
        te_exc_type=exc_type_name,
        te_value=exc,
        te_tb=tb,
        te_cause=cause_obj,
        te_context=context_obj,
        te_suppress=suppress,
        te_stack_lines=lines,
        te_frames=frames,
        te_final=final,
        te_compact=compact,
    );
}

def _seen_has(seen: list[PyObj], target: PyObj) -> bool {
    for item in seen {
        if item is target {
            return True;
        }
    }
    return False;
}

def _attr_tb(exc: PyObj) -> any {
    got = exc.tp_getattro("__traceback__");
    if is_error(got) or isinstance(got, PyNoneType) {
        return None;
    }
    return got;
}

def _tbe_construct(exc: PyObj, tb: any, kwargs: dict[str, PyObj]) -> PyObj {
    limit = py_none();
    compact = False;
    for k in kwargs {
        if k == "limit" {
            limit = kwargs[k];
        } elif k == "compact" {
            compact = _kw_truthy(kwargs[k]);
        } elif k != "capture_locals" {
            # capture_locals is accepted for signature compatibility; locals
            # are never captured.
            return py_error(
                "TypeError",
                "TracebackException() got an unexpected keyword argument '" + k + "'",
            );
        }
    }
    out = _tbe_capture(exc, tb, limit, compact, []);
    if is_error(out) {
        return out;
    }
    # Apply explicit value=/tb= overrides after the chain walk so the captured
    # RENDERING always comes from the real exception while the convenience
    # attributes reflect what the caller passed.
    snap = out as TBExcObj;
    if "value" in kwargs {
        snap.te_value = kwargs["value"];
    }
    if "tb" in kwargs {
        snap.te_tb = kwargs["tb"];
    }
    return out;
}

obj TBExcCtorFn(PyObj) {
    # TracebackException(exc, /, *, value=None, tb=None, limit=None,
    # compact=False, capture_locals=False) -- the one-arg + kwargs form. The
    # legacy 3-positional shape (exc_type, exc_value, exc_traceback) from the
    # pinned Lib source routes through the same capture with exc=args[1].
    def tp_getattro(name2: str) -> PyObj {
        if name2 == "from_exception" {
            return TBFromExcFn(t="function");
        }
        return py_error(
            "AttributeError",
            "type object 'TracebackException' has no attribute '" + name2 + "'",
        );
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error(
                "TypeError", "TracebackException expected at least 1 argument, got 0"
            );
        }
        if len(args) > 3 {
            return py_error(
                "TypeError",
                "TracebackException() takes at most 3 positional arguments"
            );
        }
        if len(args) == 1 {
            # One-arg + kwargs form.
            exc = args[0];
            if not _is_exc_like(exc) {
                return py_error(
                    "TypeError", "Expected BaseException instance, got " + exc.t
                );
            }
            return _tbe_construct(exc, _attr_tb(exc), kwargs);
        }
        # Legacy pinned-Lib form: (exc_type_or_none, exc_value, exc_traceback).
        exc = args[1];
        if not _is_exc_like(exc) {
            return py_error(
                "TypeError", "Expected BaseException instance, got " + exc.t
            );
        }
        tb = args[2];
        if isinstance(tb, PyNoneType) {
            tb = None;
        }
        return _tbe_construct(exc, tb, kwargs);
    }
}

obj TBFromExcFn(PyObj) {
    # TracebackException.from_exception(exc, **kwargs): same capture, exc taken
    # directly (classmethod surface).
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error(
                "TypeError", "from_exception expected at least 1 argument, got 0"
            );
        }
        exc = args[0];
        if not _is_exc_like(exc) {
            return py_error(
                "TypeError", "Expected BaseException instance, got " + exc.t
            );
        }
        return _tbe_construct(exc, _attr_tb(exc), kwargs);
    }
}

def _is_exc_like(o: PyObj) -> bool {
    if isinstance(o, PyException) {
        return True;
    }
    return not is_error(o.tp_getattro("__traceback__"));
}

# Shared list renderer behind .format() and .print(): oldest chain block first,
# chaining messages emitted before their block, exactly like walking CPython's
# _ExceptionPrintContext output in reverse.
def _tbe_format_list(te: TBExcObj, chain: bool) -> list[PyObj] {
    msgs: list[str] = [];
    excs: list[TBExcObj] = [];
    cur: TBExcObj | None = te;
    while cur is not None {
        msg = "";
        nxt: TBExcObj | None = None;
        if cur.te_cause is not None {
            msg = _TB_CAUSE_MESSAGE;
            nxt = cur.te_cause as TBExcObj;
        } elif cur.te_context is not None and not cur.te_suppress {
            msg = _TB_CONTEXT_MESSAGE;
            nxt = cur.te_context as TBExcObj;
        }
        if chain {
            msgs.append(msg);
            excs.append(cur);
        }
        cur = nxt;
    }
    items: list[PyObj] = [];
    idx = len(excs);
    while idx > 0 {
        idx -= 1;
        if msgs[idx] != "" {
            items.append(PyStr(t="str", val=msgs[idx]));
        }
        e = excs[idx];
        if len(e.te_stack_lines) > 0 {
            items.append(PyStr(t="str", val="Traceback (most recent call last):\n"));
            for ln in e.te_stack_lines {
                items.append(PyStr(t="str", val=ln));
            }
        }
        items.append(PyStr(t="str", val=e.te_final));
    }
    return items;
}

obj TBExcFormatFn(PyObj) {
    has te: any;

    # format(chain=True): returns a LIST of newline-terminated strings
    # (divergence: CPython yields a generator).
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) > 0 {
            return py_error("TypeError", "format() takes no positional arguments");
        }
        chain = True;
        if "chain" in kwargs {
            chain = _kw_truthy(kwargs["chain"]);
        }
        for k in kwargs {
            if k != "chain" {
                return py_error(
                    "TypeError",
                    "format() got an unexpected keyword argument '" + k + "'",
                );
            }
        }
        return PyList(t="list", items=_tbe_format_list(self.te as TBExcObj, chain));
    }
}

obj TBExcPrintFn(PyObj) {
    has te: any;

    # print(*, file=None): only the default stream (stderr) is served, matching
    # print_tb's v1 constraint.
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) > 0 {
            return py_error("TypeError", "print() takes no positional arguments");
        }
        for k in kwargs {
            if k == "file" and isinstance(kwargs[k], PyNoneType) {
                continue;
            }
            if k == "file" {
                return py_error("TypeError", "print(): non-default file= not supported");
            }
            return py_error(
                "TypeError",
                "print() got an unexpected keyword argument '" + k + "'",
            );
        }
        text = "";
        for piece in _tbe_format_list(self.te as TBExcObj, True) {
            text = text + (piece as PyStr).val;
        }
        _tb_stderr_write(text);
        return py_none();
    }
}

obj TBExcObj(PyObj) {
    has te_exc_type: str,
        te_value: any,
        te_tb: any,
        te_cause: any,
        te_context: any,
        te_suppress: bool = False,
        te_stack_lines: list[str] = [],
        te_frames: list[PyObj] = [],
        te_final: str = "",
        te_compact: bool = False;

    def tp_getattro(name2: str) -> PyObj {
        if name2 == "exc_type" or name2 == "exc_type_str" {
            return PyStr(t="str", val=self.te_exc_type);
        }
        if name2 == "__suppress_context__" {
            return PyBool(t="bool", val=self.te_suppress);
        }
        if name2 == "__cause__" {
            if self.te_cause is not None {
                return self.te_cause as PyObj;
            }
            return py_none();
        }
        if name2 == "__context__" {
            if self.te_context is not None {
                return self.te_context as PyObj;
            }
            return py_none();
        }
        if name2 == "value" {
            if self.te_value is not None {
                return self.te_value as PyObj;
            }
            return py_none();
        }
        if name2 == "tb" {
            if self.te_tb is not None {
                return self.te_tb as PyObj;
            }
            return py_none();
        }
        if name2 == "stack" {
            items: list[PyObj] = [];
            items.extend(self.te_frames);
            return PyList(t="list", items=items);
        }
        if name2 == "format" {
            return TBExcFormatFn(t="tbe_format_fn", te=self);
        }
        if name2 == "print" {
            return TBExcPrintFn(t="tbe_print_fn", te=self);
        }
        return py_error(
            "AttributeError",
            "'TracebackException' object has no attribute '" + name2 + "'",
        );
    }
}

# exception-only text: "Type: message\n" (message omitted when empty), the
# tail CPython appends after the stack block. Native exceptions use the
# per-type __str__ slots; user instances delegate to their own tp_str.
def _tb_exception_only_text(exc: PyObj) -> PyStr {
    # CPython _format_exception_only: "TypeName" or "TypeName: <str(value)>" --
    # the type prefix ALWAYS leads; str(value) may itself be empty (KeyError()).
    tname = "";
    body = "";
    if isinstance(exc, PyException) {
        e = exc as PyException;
        tname = e.type_name;
        body = baseexception_str(e, None, None).val;
        if body == tname {
            body = "";
        }
    } else {
        # user-defined exception instances: v1 renders type-less body only
        sr = exc.tp_str();
        if not is_error(sr) and isinstance(sr, PyStr) {
            body = (sr as PyStr).val;
        }
    }
    if body == "" {
        return PyStr(t="str", val=tname + "\n");
    }
    return PyStr(t="str", val=tname + ": " + body + "\n");
}

# Write text to a guest file-like via its BOUND write callable, or stderr.
# The caller resolves target.write through ceval helpers -- importing them
# here would create an import cycle with ceval.jac.
def tb_write_bound(write_callable: PyObj, text: str) -> PyObj {
    if isinstance(write_callable, PyNoneType) {
        _tb_stderr_write(text);
        return py_none();
    }
    return py_invoke(write_callable, [PyStr(t="str", val=text)], {});
}

obj TBFmtExcOnlyFn(PyObj) {
    # format_exception_only(exc[, value]): 1-arg 3.14 form plus legacy shape;
    # returns the single-element list CPython uses.
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "format_exception_only expected at least 1 argument");
        }
        exc = args[len(args) - 1];
        if len(args) >= 2 and not isinstance(args[0], PyException) {
            # legacy (etype, value[, tb]) form: render VALUE, not etype
            exc = args[1];
        }
        return PyList(t="list", items=[_tb_exception_only_text(exc)]);
    }
}

def traceback_module_attrs -> dict[str, PyObj] {
    return {
        "extract_tb": TBExtractFn(t="function"),
        "format_tb": TBFormatTbFn(t="function"),
        "print_tb": TBPrintTbFn(t="function"),
        "format_exception": TBFmtExcFn(t="function"),
        "walk_tb": TBWalkFn(t="function"),
        "format_exception_only": TBFmtExcOnlyFn(t="function"),
        "TracebackException": TBExcCtorFn(t="type"),
    };
}
