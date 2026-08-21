## Already moved (don’t re-do)

Compare protocol (`NotImplemented`, cross-type `TypeError`, `True == 1`), hash `(-1,)`, Layer-1 probes, CI manifest drift, libtest stdout helper — those were the high-leverage Layer-1 honesty fixes.

---

## Tier 1 — Do first (biggest correctness + unlocks more tests)

### 1. Native `repr()` for str / int / float (FIXME H3)

**Why:** `repr()` is everywhere — errors, containers, dict keys, replay diffs. Today str/int/float still fall through to `host_convert` in `py_repr`, so standalone JacPython and differential tests can lie.

**Effect:** One slice, touches one dispatch path, immediately improves every container repr and exception path you already ported natively.

**Scope:** `str_repr`, `int_repr`, `float_repr` in the object modules + wire in `ceval.jac` before host fallback. Smaller than full hash port.

---

### 2. Wire `getplatform` into the libtest shim (FIXME H4/H5)

**Why:** Docs/comments say libtest is “staged-module backed,” but `p2_libtest_reset()` hardcodes `"linux"` / `"x86_64"`. Conformance can look green while JacPython never runs the staged port.

**Effect:** Makes P2 libtest **honest** for a module you already have staged. Low LOC, high trust in CI.

**Scope:** Load `Modules/getplatform.jac` (or call `Py_GetPlatform()`) from `layer_p2_libtest.jac`; align `can_run_jacpython_libtest` with what actually runs.

---

### 3. Investigate Layer-0 `test_int` ratchet (114 vs 119)

**Why:** P3 corpus gate is the main anti-regression lock. A 5-count drop with 0 failures usually means **skipped or harvest drift**, not random breakage — but the gate will fail on push until resolved.

**Effect:** Unblocks CI truth for the whole P3 track before adding more baselines.

**Scope:** Likely manifest update or fix a replay/harvest regression from recent compare changes — quick diagnostic, not a new feature.

---

## Tier 2 — High value, more work (standalone JacPython)

### 4. Native str/float `hash()` (FIXME Critical #1, partial)

**Why:** Still host-backed in `hash_dispatch.jac`. Layer-1 stability tests pass, but **`hash('a')`, `hash(1.5)`, mixed containers** diverge in standalone runs and any test that compares exact hash values.

**Effect:** Closes the biggest remaining **semantic** gap for builtins; prerequisite for trusting set/frozenset/dict tests that depend on element hashes without host.

**Scope:** Port `unicode_hash` + `_Py_HashDouble` (or a corpus extract + oracle). Bigger than repr, but the FIXME “recommended fix order #1” for a reason.

**Not yet:** bytes SipHash — same class of problem, but you explicitly deferred secret parity; do str/float first since they unblock more tests with less crypto baggage.

---

### 5. Runtime parity in `test_p3_object_core_gate` (FIXME M11)

**Why:** Today the gate checks **lifted artifact density**, not whether `jacpython/*.jac` behavior matches CPython. You can lift clean code that never runs correctly.

**Effect:** Turns P3 gates from “we have files” to “the runtime works” — compounding value on every future object slice.

**Scope:** Per-stem smoke tests (hash/repr/compare) wired to manifest, similar to Layer-1 probes but automated in the gate.

---

## Tier 3 — Correctness hygiene (prevent silent wrong code)

### 6. P2 wave 4 — `pystricmp` NUL semantics + stronger gates (FIXME M1–M5)

**Why:** Staged oracle uses `len(p1) > 0` instead of NUL termination; wave 4 gates are weaker than wave 2/3 (stem sets, boundary oracles).

**Effect:** Stops **permanent staged/lifted drift** and catches wrong C semantics before it spreads.

**Scope:** Small fix in `pystricmp.jac` + port two-test staged-sync pattern from wave 2. Good “one PR each” work.

---

### 7. Set subset compare with element `==` (FIXME M9)

**Why:** `_set_is_subset` uses hashkey membership only, not `PyObject_RichCompareBool`. Wrong for user objects with custom equality.

**Effect:** Matters once user-class sets/frozensets show up in corpus; lower urgency until then.

---

## Tier 4 — Explicitly later (your deferred list)

| Item | Why wait |
|------|----------|
| **bytes host hash / SipHash** | Needs hash secret + bootstrap policy; do after str/float hash pattern exists |
| **bisect/heapq JacPython** | Need module implementation + shim wiring first; manifest skips are correct today |
| **Full Objects/ lift, heap types (P5)** | Multi-slice, not incremental trust wins |

---

## Practical “next 3 PRs” I’d recommend

1. **Native str/int/float repr** — fast, broad blast radius  
2. **getplatform libtest wiring + gate honesty** — CI trust, small diff  
3. **Layer-0 `test_int` ratchet fix** — unblock green P3 gate, then add M11 runtime checks  

After that: **str/float native hash**, then **P3 runtime gate (M11)**, then **wave 4 hygiene**.

If you want one axis to optimize for:

- **User-visible correctness** → repr, then str/float hash  
- **CI honesty** → getplatform, test_int ratchet, M11 gate  
- **Port hygiene** → wave 4 NUL/stem gates  
