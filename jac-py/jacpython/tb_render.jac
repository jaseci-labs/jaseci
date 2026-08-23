# Host-exact uncaught-exception traceback rendering (the PyErr_Display path).
#
# Renders CPython-shaped traceback text over the guest PyException/PyTraceback
# structures that recover_exception builds during propagation:
#   - "Traceback (most recent call last):" header + `File/line/in` frame lines
#     with source text resolved through linecache (a miss degrades exactly like
#     the interpreter: the source line is omitted, never guessed);
#   - the "Type: value" error tail via baseexception_str;
#   - __cause__/__context__ chaining blocks ("The above exception was the
#     direct cause..." / "During handling of the above exception...") with
#     cycle suppression and __suppress_context__ honoring;
#   - the "[Previous line repeated N more times]" collapse for runs of
#     identical (file, lineno, name) frames, Lib/traceback.py semantics.
#
# Pure jac except two host shims (linecache lookup, stderr write), mirroring
# how ceval.jac bridges the host. Exception groups are out of scope.

import from objects {
    PyObj,
    PyError,
    PyException,
    PyTraceback,
    PyCode,
    PyStr,
    PyInt,
    PyFloat,
    PyBytes,
    PyBool,
}
import from exceptions_core { baseexception_str, _obj_to_str }
import from strobject { str_repr }
import from longobject { int_repr }
import from floatobject { float_repr }
import from bytesobject { bytes_repr }

::py::
def _tb_linecache_getline(filename, lineno):
    # CPython's display path resolves source text through linecache; a miss
    # (synthetic filename like "<f>", unreadable file) returns "" and the
    # source line is then omitted -- the exact interpreter degradation.
    import linecache
    return linecache.getline(filename, lineno)

def _tb_stderr_write(text):
    import sys
    sys.stderr.write(text)
    sys.stderr.flush()
::py::


# Lib/traceback.py StackSummary._RECURSIVE_CUTOFF (also hardcoded in
# traceback.c): within a run of consecutive identical frames this many are
# shown before collapsing into a repetition marker.
glob _TB_RECURSIVE_CUTOFF: int = 3;

glob _TB_CAUSE_MESSAGE: str = (
         "\nThe above exception was the direct cause of the following exception:\n\n"
     );

glob _TB_CONTEXT_MESSAGE: str = (
         "\nDuring handling of the above exception, another exception occurred:\n\n"
     );

# One rendered stack entry: header line always, source line only when
# linecache resolves one (FrameSummary.line strips; format re-indents 4).
def _tb_frame_text(filename: str, lineno: int, name: str) -> str {
    out = '  File "' + filename + '", line ' + str(lineno) + ", in " + name + "\n";
    text = _tb_linecache_getline(filename, lineno).strip();
    if text != "" {
        out = out + "    " + text + "\n";
    }
    return out;
}

def _tb_repetition_marker(extra: int) -> str {
    plural = "s";
    if extra == 1 {
        plural = "";
    }
    return ("  [Previous line repeated " + str(extra) + " more time" + plural + "]\n");
}

# StackSummary.format over a tb chain (head = outermost frame, tb_next walks
# toward the raise point -- recover_exception's prepend cadence). Runs of the
# same (filename, lineno, name) show _TB_RECURSIVE_CUTOFF entries, then a
# marker counts the remainder.
def tb_format_stack(tb: any) -> str {
    filenames: list[str] = [];
    linenos: list[int] = [];
    names: list[str] = [];
    cur = tb;
    while cur is not None and isinstance(cur, PyTraceback) {
        tbe = cur as PyTraceback;
        code = tbe.code;
        if isinstance(code, PyCode) {
            filenames.append(code.filename);
            linenos.append(tbe.tb_lineno);
            names.append(code.name);
        }
        cur = tbe.tb_next;
    }
    if len(filenames) == 0 {
        return "";
    }
    lines: list[str] = [];
    have_last = False;
    last_file = "";
    last_line = -1;
    last_name = "";
    count = 0;
    i = 0;
    while i < len(filenames) {
        if (
            not have_last
            or filenames[i] != last_file
            or linenos[i] != last_line
            or names[i] != last_name
        ) {
            if have_last and count > _TB_RECURSIVE_CUTOFF {
                lines.append(_tb_repetition_marker(count - _TB_RECURSIVE_CUTOFF));
            }
            have_last = True;
            last_file = filenames[i];
            last_line = linenos[i];
            last_name = names[i];
            count = 0;
        }
        count += 1;
        if count <= _TB_RECURSIVE_CUTOFF {
            lines.append(_tb_frame_text(filenames[i], linenos[i], names[i]));
        }
        i += 1;
    }
    if count > _TB_RECURSIVE_CUTOFF {
        lines.append(_tb_repetition_marker(count - _TB_RECURSIVE_CUTOFF));
    }
    return "".join(lines);
}

# _format_final_exc_line: an empty str() collapses to just the type name.
# KeyError overrides __str__ to repr() its single argument (exceptions.c
# KeyError_str); mirror that with the leaf repr helpers for scalars.
def tb_exception_only(exc: PyException) -> str {
    valuestr = baseexception_str(exc).val;
    if exc.type_name == "KeyError" and len(exc.args) == 1 {
        valuestr = _tb_keyerror_arg_repr(exc.args[0]);
    }
    if valuestr == "" {
        return exc.type_name + "\n";
    }
    return exc.type_name + ": " + valuestr + "\n";
}

def _tb_keyerror_arg_repr(arg: PyObj) -> str {
    if isinstance(arg, PyStr) {
        return (str_repr(arg as PyStr)).val;
    }
    if isinstance(arg, PyInt) {
        return (int_repr(arg as PyInt)).val;
    }
    if isinstance(arg, PyFloat) {
        return (float_repr(arg as PyFloat)).val;
    }
    if isinstance(arg, PyBytes) {
        return (bytes_repr(arg as PyBytes)).val;
    }
    if arg.t == "none" {
        return "None";
    }
    if isinstance(arg, PyBool) {
        if (arg as PyBool).val {
            return "True";
        }
        return "False";
    }
    # Non-scalar keys fall back to the default BaseException str; container
    # and object key reprs route through the ceval repr dispatch once the
    # display path consumes it directly.
    return _obj_to_str(arg);
}

def _tb_suppress_context(exc: PyException) -> bool {
    sup = exc.suppress_context;
    if sup is None {
        return False;
    }
    return isinstance(sup, PyBool) and (sup as PyBool).val;
}

def _tb_chain_exc(value: any) -> PyException | None {
    if value is None {
        return None;
    }
    if isinstance(value, PyException) {
        return value as PyException;
    }
    return None;
}

def _tb_seen_has(seen: list[PyException], target: PyException) -> bool {
    for item in seen {
        if item is target {
            return True;
        }
    }
    return False;
}

# TracebackException.format(chain=True) with cycle suppression: walk
# cause-then-context (honoring __suppress_context__), drop any chained
# exception already visited, emit blocks oldest-first separated by the
# chaining messages.
def tb_format(exc: PyException) -> str {
    msgs: list[str] = [];
    excs: list[PyException] = [];
    seen: list[PyException] = [];
    cur: PyException | None = exc;
    while cur is not None {
        seen.append(cur);
        msg = "";
        nxt = _tb_chain_exc(cur.cause);
        if nxt is not None {
            msg = _TB_CAUSE_MESSAGE;
        } else {
            cand = _tb_chain_exc(cur.context);
            if cand is not None and not _tb_suppress_context(cur) {
                msg = _TB_CONTEXT_MESSAGE;
                nxt = cand;
            }
        }
        if nxt is not None and _tb_seen_has(seen, nxt) {
            msg = "";
            nxt = None;
        }
        msgs.append(msg);
        excs.append(cur);
        cur = nxt;
    }
    out = "";
    idx = len(excs);
    while idx > 0 {
        idx -= 1;
        e = excs[idx];
        if msgs[idx] != "" {
            out += msgs[idx];
        }
        stack_text = tb_format_stack(e.traceback);
        if stack_text != "" {
            out += "Traceback (most recent call last):\n" + stack_text;
        }
        out += tb_exception_only(e);
    }
    return out;
}

# Final-surface entry: render an escaping PyError to host stderr exactly as
# the interpreter would display it uncaught.
def tb_display_error(outcome: PyObj) -> None {
    if not isinstance(outcome, PyError) {
        return;
    }
    _tb_stderr_write(tb_format((outcome as PyError).exception));
}
