# FIXME - TASK.md implementation review

> **Status (2026-08-22): superseded.** This was a point-in-time review of the P2/P3 state.
> All **Critical** and **High** findings below are resolved - native str/int/float/bytes hash
> (`pyhash.jac`), `PyBool.tp_richcompare` + `NotImplemented` sentinel (`objects.jac`),
> cross-type ordering `TypeError`, native reprs, getplatform libtest wiring, manifest drift
> CI check, wave-4 pystricmp reclass/stem gates. Verify against TODO.md "Also done" rather
> than this file.
>
> Still open (intentional, per reference-leaf policy):
>
> - **M6** - `long_add`/`x_add`/`long_compare` digit paths in `longobject.jac` are unwired
>   (bignum ops use Jac `PyInt.val`). Wire or narrow TASK claims to hash-only.
> - **M7** - dict open-addressing helpers in `dictobject.jac` are c2jac reference leaves,
>   not used by the runtime hashkey dict. Integrate when moving to real open-addressing.
> - **L7** - empty `tp_name` placeholder differs from CPython (align with heap types).
>
> Also fixed after this review: oracle_tests path rot in all wave manifests (now validated
> by `tools/p2_conformance_waves_gate.py`), tautological gate asserts in
> `run_conformance.jac` / `test_p3_object_core_gate.jac`, orphaned
> `test_p2_facade_parity.jac` (wired into CI), per-wave lift/gate script consolidation.

Review date: 2026-08-20  
Scope: all code landed or present locally for slices marked complete in `TASK.md` (P2 waves 2–4, P3.0–P3.2b, libtest bridge, CI gates).  
Method: static review of staged/lifted modules, `jacpython/*` runtime, gate scripts, manifests, and CI wiring; cross-checked against CPython semantics and wave 2/3 patterns.

Gates currently pass locally for wave 4 and P3 lift artifacts, but several **semantic bugs** and **false-green gate patterns** are documented below.

---

## Summary

| Severity | Count | Tracks |
|----------|------:|--------|
| Critical | 3 | P3 runtime (hash, bool compare) |
| High | 7 | P3 runtime, libtest, conformance gates |
| Medium | 12 | P2 wave 4, P3 stubs, gates, docs |
| Low | 10 | polish, doc drift, test hygiene |

**Top priority:** fix `PyObject_Hash` / `hash()` routing, `PyBool` richcompare, and unorderable cross-type compares before expanding P3 Layer-1 replay baselines.

---

## Critical - P3 runtime semantics

### 1. `hash()` uses FNV digest of hashkeys for most types

**File:** `jac-py/jacpython/abstract_protocol.jac` (`PyObject_Hash`, `_hashkey_digest`)

`py_hash` in `ceval.jac` correctly routes `PyInt` → `long_hash_obj`, `PyBytes` → `bytes_hash_obj`, tuples → `tuple_hash`, sets → `set_hash_obj`. Everything else falls through to `PyObject_Hash`, which hashes the `tp_hashkey()` string with FNV-1a instead of CPython algorithms.

**Impact:** `hash('a')`, `hash(1.5)`, `hash(('a',))`, `hash((1.5,))` diverge from CPython. Layer-0/1 gates do not probe these cases.

**Fix:** Add native `str_hash`, `float_hash`; make `PyObject_Hash` a dispatcher to type-specific helpers, not `_hashkey_digest`.

---

### 2. `hash(-1)` rule broken inside containers

**File:** `jac-py/jacpython/abstract_protocol.jac` (`_hashkey_digest` `n:` path)

For `n:` keys, `_hashkey_digest` returns `int(hk[2:])` directly. `long_hash` in `longobject.jac` correctly maps `-1 → -2`, and `py_hash(PyInt)` uses that path - so bare `hash(-1)` works. But `tuple_hash` calls `PyObject_Hash` on each element, so **`hash((-1,))` is wrong**.

**Fix:** Share `long_hash` / `-1 → -2` in one place; call it from both `long_hash_obj` and `PyObject_Hash` for numeric hashkeys.

---

### 3. `True == 1` is asymmetric (bool lacks richcompare)

**File:** `jac-py/jacpython/objects.jac` (`PyBool` has no `tp_richcompare`)

`PyBool` inherits default `PyObj.tp_richcompare`, which compares type tags (`"bool" == "int"` → `False`). `PyInt.tp_richcompare` handles `PyBool`, so `1 == True` works but **`True == 1` returns False**.

Root cause: `PyObject_RichCompare` treats any non-error bool result as final; it does not implement CPython's `NotImplemented` reflection protocol when the left operand "answers" with `False`.

**Fix:** Add `PyBool.tp_richcompare` delegating to int comparison; long-term, add a `NotImplemented` sentinel so `False` from a mismatched left compare triggers reflected compare.

---

## High

### P3 runtime

| # | File | Issue | Fix |
|---|------|-------|-----|
| H1 | `abstract_protocol.jac` + `objects.jac` | Cross-type ordering (`1 < 'a'`) returns `False` instead of `TypeError`. Operand slots return `PyBool(False)` rather than deferring. | Return a not-implemented sentinel (or error) from mismatched ordered compares; teach `PyObject_RichCompare` / `py_compare` to reflect before bool coercion. |
| H2 | `bytesobject.jac` | `bytes_hash_obj` delegates to host `hash(bytes(data))` via `::py::`. Passes replay in-process but not standalone JacPython. | Port `Py_HashBuffer` / SipHash or gate as explicit bootstrap-only shim. |
| H3 | `ceval.jac` (`py_repr`) | Native repr for tuple/list/dict/bytes/exception/class; **str/int/float fall through to `host_convert(..., 2)`**. | Add native `str_repr`, `int_repr`, `float_repr` before host fallback. |

### P2 libtest / conformance

| # | File | Issue | Fix |
|---|------|-------|-----|
| H4 | `jac-py/jacpython/layer_p2_libtest.jac` | Comments claim shims are "backed by staged `jac-py/Modules/*.jac` ports", but `p2_libtest_reset()` hardcodes `"linux"` / `"Linux"` / `"x86_64"` via `::py::` - never calls `Py_GetPlatform()` from `getplatform.jac`. | Wire shim from staged port or update docs to "stub pending staged wiring". |
| H5 | `jac/tests/jacpy/libtest_runner.jac` | `can_run_jacpython_libtest()` requires `Modules/{stem}.jac` to exist, but the JacPython path never loads that file. | Load staged module into shim or drop the staged-file gate. |
| H6 | `jac-py/tools/p2_conformance_gate.py` | `test_libtest_modules_record_jacpython_results` uses `skipTest` when `jacpython_results` absent; only asserts `failed == 0` (all-skipped modules pass). | Require `jacpython_results`; assert `passed >= 1` for capable libtest modules (`getplatform`). |
| H7 | `.github/workflows/ci.yml` | `run_conformance.jac` regenerates manifest in CI workspace; nothing verifies **checked-in** `conformance_manifest.json` matches generated output. | Add `git diff --exit-code jac-py/tests/conformance_manifest.json` after harness step. |

---

## Medium

### P2 wave 4

| # | File | Issue | Fix |
|---|------|-------|-----|
| M1 | `jac-py/Modules/pystricmp.jac` | Hand-staged loop uses `len(p1) > 0` / `len(p2) > 0`. C uses NUL termination (`*p1 && *p2`). Embedded `chr(0)` in Jac strings would keep looping while C stops. Lifted copy uses correct `(ord(p1[0]) if p1 else 0)` pattern. | Align staged oracle with lifted/C semantics (same as `pystrcmp.jac` wave 1). |
| M2 | `jac-py/tests/test_p2_wave4_staged_sync.jac` | Single test; no manifest stem enumeration, no `hand` module existence check, no hand-module note validation (weaker than wave 2/3). | Port two-test pattern from `test_p2_wave2_staged_sync.jac`. |
| M3 | `jac-py/tools/p2_conformance_wave4_gate.py` | Only checks module **count** vs corpus; wave 2/3 also verify `seen_stems == expected_stems`. | Add stem-set cross-check from `p2_conformance_wave2_gate.py`. |
| M4 | `jac-py/tests/test_p2_wave4_module_oracles.jac` | One happy-path oracle per module; no negative/boundary cases (`""`, non-match, `factorial(0)`, ctype out-of-range). | Add boundary oracles or document minimal coverage intent. |
| M5 | `pystricmp.jac` staged vs lifted | Permanent drift: manifest marks `hand`; lifted byte-sync gate never covers it. Manifest note cites "c2jac empty-string truthiness hangs" but fresh lift is tier-B-clean and wave 1 `pystrcmp.jac` uses truthiness loop successfully. | Reclassify as `lift` after verification, or update note with real rationale. |

### P3 runtime / gates

| # | File | Issue | Fix |
|---|------|-------|-----|
| M6 | `longobject.jac` + `ceval.jac` | TASK marks digit add/compare/hash done; `ceval.jac` only imports `long_hash_obj`. `long_add`, `x_add`, `long_compare` are dead code; bignum ops use Jac `PyInt.val`. | Wire digit paths or narrow TASK claims to "hash only". |
| M7 | `dictobject.jac` | Open-addressing helpers (`dict_probe_step`, `dictkeys_generic_lookup`, …) ported but **unused**. Runtime dicts use hashkey-backed `dict[str, DictEntry]`. | Document as c2jac reference only, or integrate when moving to real open-addressing. |
| M8 | `typeobject.jac` | `type_ready` / `type_hash_unimplemented` never called from `ceval.jac`. TASK marks `PyType_Ready` stub done. | Wire into type construction or mark deferred in manifest. |
| M9 | `setobject.jac` | `_set_is_subset` uses hashkey membership only, not element `==`. | For full parity, confirm buckets with `PyObject_RichCompareBool` like CPython. |
| M10 | `layer0_replay.jac` + `manifest.json` | Layer-1 P3.2a tests are synthetic mini-classes; under-test str/float hash, bool/int equality, `-1` in tuples, cross-type TypeError. | Add replay probes for failing cases listed under Critical/High. |
| M11 | `test_p3_object_core_gate.jac` | Gate validates lifted `_lifted/*.jac` tier-B density only, not runtime `jacpython/*.jac` correctness. | Add runtime parity checks per stem. |
| M12 | `jac-py/tests/run_conformance.jac` | `assert_jacpython_zero_failures()` skips when key absent; never requires non-zero `passed`. | Align with H6 gate fixes. |

### Documentation

| # | File | Issue |
|---|------|-------|
| M13 | `TASK.md` §3 header (L72–78) | Still says "c2jac port NOT started" while P3.1c–P3.2b slices below are checked complete. |
| M14 | `jac-py/PORTING_PLAYBOOK.md` | Documents wave 2/3 staging; no wave 4 `pystricmp` hand-staging policy. |
| M15 | `p3_object_core/manifest.json` `status: "lift"` | Means c2jac artifact exists, not that lifted code executes at runtime (hand-written `jacpython/*.jac` is separate). |

---

## Low

| # | File | Issue | Fix |
|---|------|-------|-----|
| L1 | `exceptions_core.jac` (`_repr_obj`) | Single-arg exception repr wraps `PyStr` as `' + val + '` instead of proper `repr()`. Breaks on quotes/escapes. | Route through `py_repr`. |
| L2 | `ceval.jac` vs `tupleobject.jac` | `tuple_repr` lives in `ceval.jac`, not `tupleobject.jac` (TASK implies object-module split). | Move or update TASK. |
| L3 | `objects.jac` | `PySet.hash_cache` declared, never used. | Implement or remove. |
| L4 | `objects.jac` + `setobject.jac` | Duplicate set richcompare (`PySet.tp_richcompare` vs `set_richcompare`). | Delegate or delete duplicate. |
| L5 | `listobject.jac`, `dictobject.jac` | `_obj_truth` treats `PyInt(0)` from user `__eq__` as true. | Mirror `_object_is_true` from `abstract_protocol.jac`. |
| L6 | `bytesobject.jac` | Non-int needle in `bytes_contains` raises `"unorderable types"`. | Match CPython containment message. |
| L7 | `typeobject.jac` | Empty `tp_name` → `"<class at 0x0>"`; CPython uses different placeholder. | Align when heap types land (P5). |
| L8 | `pyc_first.jac` | Stale comment that `hash()` uses host-builtin fallback; `ceval.py_hash` is native. | Update comment. |
| L9 | `p2_libtest_jacpython_bridge.py` | Writes `jac-py/jacpython/_libtest_snippet_run.jac` into product tree every run (untracked pollution). | Use tempfile or `.gitignore`. |
| L10 | `libtest_runner.jac` | JacPython leg uses `case.expect_stdout`; differential path uses `libtest_jac_expect_stdout()`. | Use shared helper. |

### Minor consistency

- `conformance_manifest_wave4.json` uses `"note"` per module; wave 1/2 use `"notes"`.
- `layer_p2_libtest.jac` uses `host_compile_marshal` (bootstrap) but is not listed in `p4_import_gate.py` transitional allowlist - harmless today (not a product module prefix), worth documenting.
- `platform_basic` libtest snippet uses weak asserts (`isinstance`, `len > 0`); JacPython stub always returns `"linux"` - not parity with host or staged `Py_GetPlatform()`.

---

## P2 wave 4 - confirmed correct

- Lift-staged modules (`pyctype_space`, `pyctype_alpha`, `math_factorial_small`): staged `.jac` matches `_lifted/p2_corpus_wave4/` byte-for-byte.
- Tier-B baseline: `tier_b_total = 0` on lifted tree.
- CI wiring (`.github/workflows/ci.yml` ~L687–700): lift gate → oracles → staged sync → conformance → density.
- C corpus extracts match `p2_corpus_wave4/corpus/*.c`.

---

## P3 - confirmed correct

- **Import graph (P3.2b):** `marshal_reader.jac` → `objects`; `ceval.jac` → object helpers + `objects`; slim `pyc_first.jac` re-exports - acyclic (`p3_import_cycle_gate.py` PASS).
- **Container compare/repr (native paths):** list/dict/bytes/tuple/set/exception helpers structurally match CPython for curated Layer-1 cases.
- **`long_hash_obj` / numeric collapse:** `hash(1) == hash(1.0) == hash(True)` works for bare ints.
- **Dict key collision:** `{1: 'a'; 1.0: 'b'}` → one entry, value `'b'` (hashkey model).

---

## Recommended fix order

1. **P3 hash unification** - native str/float hash; fix `n:` `-1 → -2` in `PyObject_Hash`; stop FNV-on-hashkey for user-visible `hash()`.
2. **P3 compare protocol** - `PyBool.tp_richcompare`; `NotImplemented` plumbing; `TypeError` on unorderable cross-type ordering.
3. **P3 repr / bytes hash** - native str/int/float repr; decide fate of bytes host hash shim.
4. **Gate honesty** - add Layer-1 replay probes for items 1–3; runtime checks in `test_p3_object_core_gate.jac`.
5. **P2 libtest** - wire `getplatform.jac` into shim or correct docs; harden conformance manifest CI drift check (H7).
6. **P2 wave 4 hygiene** - fix `pystricmp` NUL semantics; strengthen staged-sync and conformance stem gates; expand oracles.

---

## Out of scope (already tracked elsewhere)

- Full mechanical lift of all 45 `Objects/*.c` files (TASK deferred).
- Heap-type creation / full `typeobject.c` (P5).
- Native `len()` on plain `PyUserObj` containers (TASK separate branch).
- Band 8 star-sequence / match-or-capture codegen gaps (`PROGRESS.md`).
- PR #6973 integration / pre-commit.ci ERROR (`PROGRESS.md`, `PR_SPLIT_PLAN.md`).
