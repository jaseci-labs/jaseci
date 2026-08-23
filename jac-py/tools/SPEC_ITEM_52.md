# FIX SPEC -- TODO Item 52 (LOW-MED): UnicodeEncodeError surfaces as bare Exception (type identity)

**Status:** spec only, NOT started.
**Files needed:** `jac-py/jacpython/ceval.jac` (primary: host_exception,
py_type_of/to_host bridge, py_call_host) and `jac-py/jacpython/objects.jac`
(PyException field addition, OPTIONAL -- see Option A).
**RESERVED-FILE FLAG: ceval.jac is RESERVED → QUEUE THIS FIX, do not start.**
objects.jac is owned by another agent TODAY but generally cycles free; if the
chosen option needs a PyException field, either wait for it to cycle or scope
the fix into ceval.jac only (Option C).

## Minimal repro

```python
try:
    '\u20ac'.encode('ascii')
    r = 'no-error'
except UnicodeEncodeError as e:
    r = type(e).__name__   # guest: 'Exception';  CPython: 'UnicodeEncodeError'
```

## Current guest behavior (probed on this tree)

| surface | guest | CPython 3.14.6 pinned oracle |
|---|---|---|
| uncaught `PyError.type_name` | `UnicodeEncodeError` | UnicodeEncodeError |
| uncaught message | `'ascii' codec can't encode character '\u20ac' in position 0: ordinal not in range(128)` | identical |
| `except UnicodeEncodeError:` | MATCHES (name table works) | matches |
| `except ValueError:` | matches | matches |
| `type(e).__name__` inside except | **`Exception`** (BUG) | `UnicodeEncodeError` |
| `raise UnicodeEncodeError('bad')` | **TypeError: function takes exactly 5 arguments (1 given)** | TypeError about required args (encoding, object, start, end, reason) |
| `'\u20ac'.encode()` default utf-8 | OK, `b'\xe2\x82\xac'` | same |

So the TODO's "except misses it" is imprecise: matching WORKS; what breaks is
the exception's TYPE OBJECT surface (`type(e)`, and anything dispatching on it)
plus VM-side construction.

## Root cause (exact chain)

1. Host-call marshaling is CORRECT: `str.encode` resolves through
   `_is_host_backed("str")` -> host_getattr bound method ->
   `py_call_host` (ceval.jac:4085); `_jac_host_call` (ceval.jac:32) catches the
   live BaseException and flattens to `(False, "UnicodeEncodeError", str(exc))`;
   tail of py_call_host (ceval.jac:~4134-4138) builds
   `py_error("UnicodeEncodeError", msg)`. Type name + message preserved.
2. Catch binding preserves it too: `recover_exception` (ceval.jac:3942) pushes
   `error.exception` (the `PyException`, type_name intact);
   `exception_matches` (ceval.jac:3963) matches by name via
   `exc_name_matches` / `_EXC_PARENT` in exceptions_core.jac (UnicodeEncodeError
   -> UnicodeError -> ValueError). Hence probes pass.
3. THE BUG -- type-object reconstruction collapses to Exception:
   `type(e)` runs `py_type_of` (ceval.jac:2338); a bare PyException falls
   through every isinstance branch to
   `from_host(_jac_host_type(to_host(o)))`. In `to_host`, `case PyException()`
   (ceval.jac:2189) routes to `host_exception(exc)` (ceval.jac:2374), which
   rebuilds a REAL host exception via `_jac_construct_builtin(type_name,
   [message])`. `builtins.UnicodeEncodeError` requires exactly FIVE args
   (encoding, object, start, end, reason) -- construction raises TypeError,
   `_jac_construct_builtin` swallows it and returns `(False, ...)`, and
   `host_exception` falls back to `_jac_construct_builtin("Exception", ...)`.
   Result: `type(e).__name__ == "Exception"`.
   The same reconstruction path explains the 5-arg failure for
   `raise UnicodeEncodeError(...)` from guest code.
   Note `e.__class__.__name__` is CORRECT ("UnicodeEncodeError") because
   `PyException.tp_getattro("__class__")` (objects.jac:~1660) answers
   `py_exception_type(self.type_name)` directly -- two divergent surfaces for
   the same object.

The codec family (UnicodeDecodeError / UnicodeTranslateError, same 1-to-5-arg
ctor mismatch) plus any builtin exception whose ctor rejects `[message]` shares
this bug shape. Found fuzz round 51.

## Fix options

**Option A (recommended): keep the original host exception instance.**
`_jac_host_call` has the live BaseException in hand before flattening. Thread
it out (e.g. extend the tuple or stash it) so `py_call_host` can attach the raw
host exception to the PyException -- reuse the existing `raw: any` field
(objects.jac:1628, already used to preserve user-exception instances) holding a
host proxy of the BaseException -- and make `host_exception`/`to_host` prefer
`raw` when present instead of reconstructing. Then `type(e)`, str/repr,
`e.args`, re-raise are all exact, with zero parsing.
Costs: touches objects.jac (cycles free) OR keep `raw` usage as-is if host
proxies are acceptable values there -- verify `exception_matches`' use of `raw`
(`isinstance(raw, PyUserObj)` guard) tolerates a proxy.

**Option B (ceval.jac-only, no objects.jac): family-aware builder.**
In `host_exception`, when `_jac_construct_builtin(type_name, args)` fails and
type_name is in the codec family, synthesize the correct 5-arg form:
`UnicodeEncodeError(enc, obj, start, end, reason)` requires structured fields we
flattened away at step 1 -- so ALSO extend `_jac_host_call`'s error tuple to
carry the exception ARGS (`exc.args`), not just `str(exc)`. This stays inside
ceval.jac but re-implements per-family ctor knowledge -- more brittle than A.

**Option C: guest-side encode/decode ports** (native PyStrMethod encode).
Long-term clean but large; unnecessary for this bug since the message already
matches byte-for-byte. Not recommended now.

Recommendation: Option A. It fixes `type(e).__name__`, future re-raise
fidelity, and `e.args` parity for EVERY host-raised builtin exception whose
ctor is not `(message)`-shaped (OSError variants, ImportError, ...) -- one
mechanism, no family tables.

## Risks

- `raw` currently holds a PyUserObj for user exceptions; adding host-proxy
  values changes `exception_matches`/tp_getattro delegation paths -- audit both
  readers before landing.
- Exceptions crossing the host boundary twice (guest catch -> host callback ->
  guest) must unwrap idempotently (from_host already recovers proxies).
- Keep the fallback chain: if raw is absent (VM-raised errors), today's
  reconstruct-or-Exception behavior must remain.

## Acceptance probes

1. Repro above: `r == 'UnicodeEncodeError'`.
2. Uncaught type_name/message unchanged (byte-exact vs oracle).
3. `b'\xff'.decode('ascii')` -> `type(e).__name__ == 'UnicodeDecodeError'`.
4. User exception classes (`class E(Exception)`) unchanged.
