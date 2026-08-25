# M9: sys.exc_info() Generator Precision -- Divergence Characterization and Fix Design

Diagnosis-only lane. Product files untouched. Evidence gathered on worktree
`conv/selfhost-six` @ 7f743e089 (ceval.jac `_handled_exc_stack` mirror).

## 1. Current mechanics

- Per-frame: `exc_handling: list[PyObj]` local in `run_frame`
  (ceval.jac ~13145). Saved to `frame.exc_state` at `OP_YIELD_VALUE`
  (~15166), restored at `run_frame` entry (~13146). Drives bare `raise`
  (~14977) and implicit `__context__` chaining (~14994).
- Process-global: `_handled_exc_stack` (~3959). Pushed at `OP_PUSH_EXC_INFO`
  (~14916), popped at `OP_POP_EXCEPT` (~14963). Read by `sys.exc_info()`
  (`PyNativeBuiltin("exc_info")`, ~9819) and `traceback.format_exc()`
  (`current_handled_exc()`).
- **The global stack is never touched at suspend/resume** -- that is the bug.

## 2. Divergence matrix (probed host python3.14 vs guest ceval)

Probes ran one snippet per fresh jac process via
`p2_libtest_run_snippet` (shared-process runs cross-contaminate because
leaked entries persist for the process lifetime -- itself evidence of the leak).

| Scenario | Host 3.14 | Guest @7f743e089 | Verdict |
|---|---|---|---|
| (a) gen suspended inside `except`; unrelated frame reads `sys.exc_info()` outside any handler | `(None, None, None)` | `(ValueError, 'gen-exc')` -- leaks | **DIVERGE** |
| (a2) caller inside its OWN handler while gen stays suspended | caller's own exc (`KeyError('main')`) | `KeyError('main')` | match (accidentally: stale entry sits *below* caller's) |
| (b) two interleaved gens, each suspended in its own handler; resumed alternately | g1 sees `e1`, g2 sees `e2` | g1 sees `e2`, g2 sees `e1` -- **each sees the other's exception** (stack `[e1,e2]`, both read wrong end) | **DIVERGE** |
| (c) `exc_info` inside the resumed generator after resume | own handler exc | own handler exc | match |
| (d) plain callee of a frame inside an `except` block | propagates caller's handled exc | propagates | match |
| (e) bare `raise` inside RESUMED generator (`frame.exc_state` path) | re-raises `orig` | re-raises `orig` | match |
| (f) exception ESCAPES the `except` body (re-raise outward), caught outside; later unrelated `exc_info` | `(None, None, None)` | `(None, None)`-clean | match |
| (g) `gen.close()` while suspended inside `except`; later `exc_info` | `(None, None, None)` | clean | match |

Why (f)/(g) already drain: CPython 3.14 compiles an abnormal exit from a
handler body to a cleanup target `COPY 3; POP_EXCEPT; RERAISE 1`
(exception-table range L4–L5 -> L7). Unwinding executes that `POP_EXCEPT`
opcode, so the guest's global pop happens even on escape paths. Confirmed by
disassembling the identical generator on host 3.14.

Root cause, precisely stated: **the only path that deactivates a frame's
handler without executing `OP_POP_EXCEPT` is `OP_YIELD_VALUE`.** The frame
keeps its `exc_handling` (correctly, for post-resume bare `raise`) but the
global mirror keeps the entries visible to every other frame until the
generator resumes or is closed/collected-with-close.

Secondary observation: abandoned generators (suspended, never resumed or
closed) leak entries for the whole process -- visible as cross-snippet
contamination when probes shared a process. `frame_clear()` does not touch the
global stack.

## 3. Fix options

### Option (i): call-site resolution (special-case `exc_info` in run_frame CALL dispatch, like `exec`/`globals`/`dir`)

Read the CURRENT frame's local `exc_handling` at the CALL site
(~14787 region pattern).

- Pro: no global state at all; suspended frames trivially invisible.
- Con 1: **breaks scenario (d)** -- a callee has empty `exc_handling` and would
  return `(None,None,None)` where host 3.14 propagates the caller's handled
  exception. Matching (d) requires walking the dynamic call chain, but ceval
  maintains no active-frame chain (run_frame recursion is implicit in Jac/host
  calls); building one is a much larger, riskier change.
- Con 2: aliased builtins (`ei = sys.exc_info; ei()`) bypass the CALL
  dispatch via `PyNativeBuiltin.tp_call` and would silently fall back to
  whatever global state no longer exists.

### Option (ii): drop/re-push the global entries at suspend/resume boundaries (RECOMMENDED)

Keep `_handled_exc_stack` as the single source of truth for readers (both the
CALL fast-path and the `tp_call` fallback stay correct), but make it hold
exactly the union of ACTIVE frames' handler entries:

1. **Suspend** -- `OP_YIELD_VALUE` handler (~15155, before `return PyYield`):
   remove every entry of the current `exc_handling` from `_handled_exc_stack`.
   All entries in the list belong to this frame (fresh frames start empty;
   restored entries were dropped at the previous suspend), so removal is
   well-defined. Removal must be **by identity with occurrence counting**
   (the same exception instance can be handled in nested handlers, e.g. via
   `gen.throw(v)`), preserving the relative order of surviving entries:

   ```jac
   def handled_exc_drop(entries: list[PyObj]) {
       # Multiset-remove `entries` from _handled_exc_stack by identity,
       # keeping relative order of survivors.
       drops: dict[int, int] = {};          # id(obj) -> occurrences left
       for e in entries {
           k = id(e);
           if k in drops { drops[k] = drops[k] + 1; }
           else { drops[k] = 1; }
       }
       kept: list[PyObj] = [];
       for e in _handled_exc_stack {        # bottom-up scan preserves order
           k = id(e);
           if k in drops and drops[k] > 0 { drops[k] = drops[k] - 1; }
           else { kept.append(e); }
       }
       _handled_exc_stack = kept;           # glob rebind (or mutate in place)
   }
   ```

   Insert `handled_exc_drop(exc_handling);` immediately before the
   `return PyYield(...)` at ~15167 (`frame.exc_state = exc_handling;`
   stays as-is).

2. **Resume** -- `run_frame` entry (~13145):

   ```jac
   exc_handling: list[PyObj] = [];
   if frame.exc_state is not None {
       exc_handling = frame.exc_state as list[PyObj];
       for e in exc_handling {              # NEW: re-activate this frame's
           _handled_exc_stack.append(e);    # entries while it runs
       }
   }
   ```

3. **Abandonment** -- `frame_clear()` (~12516): if `frame.exc_state` is a
   non-empty list, `handled_exc_drop(...)` it, so `gen.close()` /
   `gi_frame.clear()` teardown cannot strand entries. (Today close() happens
   to drain via the L7 cleanup path; frame_clear covers the never-resumed
   case.)

Why correctness holds per scenario:

- (a) gen suspends -> its entries dropped -> unrelated reader sees none. FIXED.
- (b) g1 suspends (drops e1) before g2 enters (pushes e2): each active frame's
  entry is alone on top while it runs. Both reads correct. FIXED.
- (c) resume re-pushes before any guest code runs in the segment. Still correct.
- (d) caller stays ACTIVE across the call: its entries were never dropped.
  Propagation preserved -- this is what rules option (i) out.
- (e) bare `raise` reads local `exc_handling`, untouched by the global shuffle.
  Existing `test_conv_exceptions.jac` coverage unaffected.
- (f)/(g)/(normal exit) unchanged: `OP_POP_EXCEPT` and the L7 cleanup pop both
  the local and the global in lockstep, as today.

## 4. Risk notes

- **Dual-bookkeeping drift**: every future mutation of `exc_handling` must
  keep the global in lockstep. Audit shows exactly three touch points today
  (PUSH_EXC_INFO push, POP_EXCEPT pop, yield/resume transfer proposed here);
  RERAISE/unwind intentionally touches neither. Add a comment at the glob
  declaration pointing at all sites.
- **except\*** (`PREP_RERAISE_STAR`): CPython's `SetHandledException` is not
  mirrored into EITHER stack today -- a pre-existing gap orthogonal to this
  fix; do not expand scope.
- **Indirect/aliased `exc_info` calls**: remain correct under (ii) because
  `tp_call` reads the same global (this was a con of option (i)).
- **Generator dropped without close()**: entry survives until finalization.
  If the VM grows gen finalizers later, route them through `frame_clear` to
  inherit the cleanup for free.
- **Reentrancy guard**: `gen.running` prevents a suspended-in-except generator
  from being resumed twice concurrently, so drop/push pairs cannot interleave
  wrongly for the same frame.
- Test plan (new pins, one process per case or fresh interpreter state):
  scenarios (a), (b), (f), (g) above as layer-p2 snippets asserting exact
  triples; keep (d) and (e) as regression guards for the propagation and
  `exc_state` paths.

## Probe artifacts

Ephemeral probes lived in `jac-py/jacpython/m9_probe*.jac`, `m9_s_[a-g].jac`,
`m9_diag*.jac` and `/tmp/m9_probe.jac`, `/tmp/host_probe.py`; deleted after
diagnosis per lane constraints.
