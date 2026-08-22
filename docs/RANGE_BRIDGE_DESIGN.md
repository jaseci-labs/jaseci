# Item 19 - native PyRange across the bridge (DESIGN, pre-implementation)

Status: DESIGN-FIRST per Runtime fix lane handoff brief. No runtime edits until
sign-off. Author: YoungHawk (VM runtime fix lane). Reviewers: UltraJaguar
(BrightTiger continuity - verification half + design judgment), IronArrow
(integrator fresh-eyes pass). GoldLion successor not yet spawned; walker-lane
sign-off pending.

## Problem

`range()` in guest code loses identity and laziness at TWO bridge-first call
sites (root-cause family C):

1. Construction: `range(...)` resolves through `host_builtin("range")` → a
   `PyHostProxy` wrapping the host range type → `py_call_host` → `_jac_host_call`
   → the returned host range crosses `from_host`, which materializes it:
   `ceval.jac:1741` (`isinstance(raw, range)` branch drains every element into
   a `PyList`). Consequences today:
   - `type(range(3)) == list`; no `.start/.stop/.step`
   - slicing a range fails; isinstance/type checks wrong
   - **laziness lost**: `range(10**9)` materializes 1e9 PyInt objects
     (memory/time bomb); all earlier "green" range probes passed coincidentally
     through list semantics.
2. Bridging in: any host-produced range object takes the same materializing
   `from_host` arm.

Evidence pin: `pin-item19-range-identity` (RED) - expects `type(r).__name__
== 'range'`, `(r.start, r.stop, r.step) == (2, 20, 3)`,
`r[2:8:2] == range(8, 14, 6)`.

## Target design

**Option A (recommended): native `PyRange` heap type + bridge arms both ways.**
Option B (minimum viable: keep host ranges as opaque `PyHostProxy`) rejected -
it fixes identity but keeps every operation on the host bridge (slow, breaks
user-dunder interop, leaves laziness at the mercy of host round-trips) and does
nothing for guest-constructed ranges.

### New types

`obj PyRange(PyObj)` with `has start: int, stop: int, step: int`, colocated
with the other VM-native wrapper types in `ceval.jac` (precedent: `PyIter`,
`PyGenerator`, `PyHostProxy` all live there; leaf container value types live in
objects.jac - range is a virtual/heap type, not a value container).

`obj PyRangeIter(PyObj)` - lightweight cursor (`cur: int, remaining: int,
step: int`); each `tp_iter()` on the range returns a FRESH cursor (ranges are
re-iterable). Drives through `send_into`'s existing tail branch ("any other
iterator: drive through its own **next** surface") by answering `__next__` via
`tp_getattro`, OR gets an explicit `send_into` arm - implementation detail,
decided by which reads cleaner at the call site; behavior identical.

**Leaf math reuse (zero duplication):** the lifted CPython arithmetic already
exists in `jac-py/jacpython/rangeobject.jac` - `get_len_of_range`,
`range_contains_longs`, `range_equals_longs` (from
Objects/_lifted/rangeobject_core.jac). PyRange slots call these directly.

### Slot table

| Slot | Behavior |
|---|---|
| ctor | Intercept exact builtin `range` in `py_call_host` via `_jac_builtin_base_name(fn.val) == "range"` - same pattern as the landed list() fix (4beb645eb). Args validated with `to_index` (int subclasses like `_NamedIntConstant` unwrap); ANY non-int arg falls through to the host call so error messages stay byte-exact CPython ("range() integer end argument expected..."). Arity 1/2/3; arity 0 or >3 falls through to host for the exact TypeError. |
| tp_iter | fresh PyRangeIter cursor |
| len | `get_len_of_range(start, stop, step)` - O(1) |
| contains | int fast path: `range_contains_longs`; non-int operand: item-by-item comparison fallback (CPython semantics: `1.0 in range(2)` is True, `'a' in range(2)` is False) |
| mp_subscript | int index with negative wrap + IndexError on OOB; PySlice index → new PyRange via O(1) slice arithmetic |
| tp_richcompare | eq/ne via `range_equals_longs`; everything else PY_NOT_IMPLEMENTED |
| repr | `range(stop)` when start==0 and step==1, else `range(a, b)` / `range(a, b, s)` |
| bool | `len > 0` |
| tp_getattro | `.start/.stop/.step` (read-only; setattro raises AttributeError) |

### Bridge arms (the family-C fix)

- `from_host`: REPLACE the materializing `ceval.jac:1741` branch -
  `isinstance(raw, range)` → `PyRange(raw.start, raw.stop, raw.step)`
  (attribute reads off the host object; still O(1)).
- `to_host`: add `case PyRange(): return range(value.start, value.stop,
  value.step)` to the conversion match - host consumers (sorted, json.dumps of
  a bridged range, etc.) see a real range.

## Phasing (each phase independently landable + verifiable)

### Phase 1 - core (fixes the pin)

PyRange + PyRangeIter, ctor interception, from_host/to_host arms, slots:
iter/len/contains/int-index/eq/repr/bool/start-stop-step.
Falsifiable checks:

1. `pin-item19-range-identity` GREEN (identity + attrs + slice)
2. Laziness sentinel GREEN: `it = iter(range(10**9)); next(it) == 0` completes
   in bounded time/memory; `list(zip(range(10**9), 'abc'))` has len 3
3. Full pinned corpus: NO movement except documented (range previously
   materialized as PyList everywhere - `for i in range(n)` loops across the
   stdlib closure now iterate a PyRangeIter; FOR_ITER path shape unchanged)

### Phase 2 - surface completion

Slice arithmetic returning PyRange (`r[2:8:2] == range(8,14,6)` is actually
pin-covered - if trivially reachable in phase 1, fold it in), `.index()/
.count()`, hash/hashkey (dict-key support: new `"r:"` prefix family alongside
"n:"/"obj:"/"host:", value-hashed like CPython's range hash).

## Risks / invariants

- **Blast radius**: every lifted `for i in range(n)` loop changes iterator type.
  Mitigation: corpus re-run is the gate; iteration protocol path identical.
- **INVARIANT (UltraJaguar)**: BUILD_MAP block ~6832-6900 and
  recover_exception invariant must survive untouched.
- **Sequencing**: ceval.jac held by UltraMoon's del-leak-fix-2 (TODO adv item 0);
  implementation lands only after they release. Their work may also touch the
  `_py_container_del` routing near my edit sites - rebase carefully.
- Shared-tree hygiene: surgical staging, commit within minutes of verify.

## Non-goals

- No caching/materialization tier for huge ranges.
- No range subclassing support beyond `to_index` unwrapping of boxed ints.
- Not touching compiler_codegen/emit/annotations (QuickBear lane).

## Open questions for reviewers

1. UltraJaguar as combined design-judgment + verification sign-off acceptable,
   or hold for a GoldLion successor?
2. Hash/dict-key support: phase 1 or phase 2? (CPython parity says eventually;
   corpus pressure says defer.)
3. PyRangeIter via explicit `send_into` arm vs `__next__`-through-getattro tail
   branch - reviewer preference on which reads better?
