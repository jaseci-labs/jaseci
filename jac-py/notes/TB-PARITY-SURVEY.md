# TB-PARITY-SURVEY: native traceback shim vs CPython 3.14 traceback module

Survey of `jac-py/jacpython/tracebackmodule.jac` (+ `format_exc` wiring in
`ceval.jac`) against CPython 3.14.6 `Lib/traceback.py`. READ-ONLY survey; no
product files touched.

## 1. Host surface (python3 3.14, public names)

```
BUILTIN_EXCEPTION_LIMIT, FrameSummary, StackSummary, TracebackException,
clear_frames, extract_stack, extract_tb, format_exc, format_exception,
format_exception_only, format_list, format_stack, format_tb, print_exc,
print_exception, print_last, print_list, print_stack, print_tb, walk_stack,
walk_tb
```

(`codeop`, `collections`, `io`, `itertools`, `keyword`, `linecache`, `sys`,
`textwrap`, `tokenize`, `warnings`, `suppress` are incidental module imports in
Lib/traceback.py -- not API targets.)

## 2. Shim surface (actual, verified)

`traceback_module_attrs()` provides: `extract_tb`, `format_tb`, `print_tb`,
`format_exception`, `walk_tb`. `ceval.jac:1707` and `:4584` additionally
register `format_exc` (`tb_format_exc`, backed by guest handled-exception state

+ `format_exception_text`). **Total: 6 of 21 public names.**

## 3. Missing-name table

Usage classes from `grep -c "traceback.<name>(" reference/cpython/Lib/*.py`
(CPython 3.14.6) plus ecosystem knowledge (logging/pytest/ipython/sentry-sdk).

| Name | Usage class | Lib calls | Impl cost | Wrapper vs new machinery |
|---|---|---|---|---|
| `print_exc`            | high   | 29 (22 files) | S | wrapper over exc_info + format_exception_text +_tb_stderr_write |
| `print_exception`      | high   | 18            | S/M | wrapper over format_exception_text; arg-shape handling (1-arg vs legacy 3-arg) |
| `format_exception_only`| medium | 28            | M | new small renderer (exception-only text; not derivable from tb_format without fragile splitting) |
| `extract_stack`        | medium | 8             | M | new machinery: needs guest frame-chain walk (walk_stack equivalent) |
| `print_stack`          | medium | 11            | M | wrapper over extract_stack once it exists |
| `format_stack`         | low-med| 4             | M | wrapper over extract_stack |
| `FrameSummary` (class attr) | medium | 6 | M | expose existing TBFrameSummaryObj as module attr; isinstance-matchable needs real class object |
| `StackSummary`         | medium | 0 in Lib; heavy ecosystem (ipython, sentry-sdk, rich) | L | new machinery: list subclass w/ `.extract()`, `.format()`, `.from_file()` |
| `print_list`           | rare   | 2             | S | wrapper over format_tb output + stderr write |
| `format_list`          | rare   | 3             | S | wrapper over format_tb pieces |
| `clear_frames`         | rare   | 2             | S/M | new machinery: must clear frame f_locals/f_trace on every tb frame |
| `walk_stack`           | rare   | 8             | M | new machinery: generator over frames above caller; depends on frame-chain access |
| `print_last`           | rare   | 1             | S | wrapper over print_exception(sys.last_exc); deprecated upstream |
| `BUILTIN_EXCEPTION_LIMIT` | rare| 0             | S | constant: sys.tracebacklimit or 1000 |

Skipped per instructions: `TracebackException` (concurrent lane). Overlap note:
that lane should reuse `format_exception_text` and `_tb_frame_text`; a future
TracebackException.stack would want StackSummary (table above), so coordinate.

## 4. Top-3 missing-by-usage recommendations

### 1. `print_exc(limit=None, file=None)` -- cost S, pure wrapper

Highest ecosystem frequency (scripts, logging fallbacks, REPL helpers).
Sketch:

```jac
obj TBPrintExcFn(PyObj) {
    def tp_call(args, kwargs) -> PyObj {
        # reuse the exact path ceval.jac:9831 uses for tb_format_exc:
        e = <guest handled exception / sys.exc_info state>;
        if is_error(e) or isinstance(e, PyNoneType) { return py_none(); }
        text = format_exception_text(e);
        _tb_stderr_write(text);   # file= stays None-only, matching v1 divergence
        return py_none();
    }
}
```

~30 lines; zero new machinery. Register alongside `format_exc` at both ceval.jac
sites.

### 2. `print_exception(exc, /, value, tb, limit=None)` -- cost S/M, wrapper

Same body as print_exc but takes the exception explicitly:
`format_exception_text(args[0])` then write. Only wrinkle is accepting (and
ignoring with a documented divergence) the legacy `(etype, value, tb)` shape.
Unblocks unittest-style reporters that print a captured exception.

### 3. `format_exception_only(exc, /, value)` -- cost M, small new renderer

28 call sites in Lib despite only 6 files -- densest per-consumer usage
(logging, doctest, unittest assert helpers). Cannot be sliced off `tb_format`
output reliably (header/stack interleaving). Needs ~50 lines of new rendering
machinery: `f"{type.__qualname__}"` (+ module prefix when
`__module__ != "builtins"`), message via `tp_str`, newline termination;
defer SyntaxError multi-line special-casing to a follow-up.

## 5. Class-surface gaps (noted, not top-3)

+ **FrameSummary**: `TBFrameSummaryObj` is attribute-congruent
  (filename/name/lineno/line) but exists only as an internal tag
  (`t="frame_summary"`); `isinstance(x, traceback.FrameSummary)` cannot work
  and the name is absent from the attrs dict. Exposing the obj as a module
  attribute fixes dir()/docs but isinstance-matchability requires the runtime's
  class-object story for native objs.
+ **StackSummary**: absent entirely. extract_tb returns plain PyList, so
  `.extract()`/`.format()` classmethods and list-subclass identity are missing.
  This is the largest true gap (L cost) and gates ecosystem tools
  (ipython/rich/sentry-style formatters).
+ Documented divergences already in the shim header remain: walk_tb returns
  list (not generator), file= None-only on print_*.
