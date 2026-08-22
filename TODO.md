## Already moved (don’t re-do)

Compare protocol (`NotImplemented`, cross-type `TypeError`, `True == 1`), hash `(-1,)`, Layer-1 probes, CI manifest drift, libtest stdout helper - those were the high-leverage Layer-1 honesty fixes.

**Also done on this branch:** native str/int/float `repr()` (ceval dispatch), P3 runtime parity probes (M11), `PySlice` + `PyComplex` imports in `marshal_reader.jac` (Layer-0 `test_int` 119 + `test_str` 345), getplatform libtest wiring, native str/float/bytes `hash()` in `pyhash.jac`, standalone SipHash secret (`PYTHONHASHSEED` / LCG / `os.urandom`, no ctypes), P2 wave-4 `pystricmp` lift sync + stronger gates, set subset/`isdisjoint` element-`==` (M9), bisect/heapq JacPython libtest shims, P5 `type_ready` wired into class construction, bulk Objects/ c2jac waves (P3.1c-P3.2e, 44 manifest stems), native ``PyRange`` deepen (len/contains/index/==/attrs), native ``PyByteArray`` deepen (slice/concat/mutate/bytes==), native str/bytes method surface (`PyStrMethod` / `PyBytesMethod` + deepened unicode/ctype/bytes_methods leaves), native gen `gi_running`/`gi_suspended`/`gi_frame` + close probes, native ``PyMemoryView`` + `memoryview()`, native `enumerate`/`reversed`, native `weakref` shim module, `PyIter` host-boundary drain, ``__slots__`` layout + member descriptors (`type_slots.jac` + `finalize_class_slots` / `PyMemberDescr` type-dict install), Band 5 ``__slots__`` codegen oracles, deepened odict/structseq leaf helpers.

---

## Tier 1 - Do first (biggest correctness + unlocks more tests)

### 1. ~~Native `repr()` for str / int / float (FIXME H3)~~ ✓

**Done:** `str_repr`, `int_repr`, `float_repr` wired in `ceval.jac` before host fallback.

---

### 2. ~~Wire `getplatform` into the libtest shim (FIXME H4/H5)~~ ✓

**Done:** `platform.platform()` → `Py_GetPlatform()` from `jacpython/getplatform.jac`; `system`/`machine` shims query host CPython (outside getplatform port). `can_run_jacpython_libtest` documents facade vs staged oracle split.

---

### 3. ~~Investigate Layer-0 `test_int` ratchet (114 vs 119)~~ ✓

**Root cause:** `marshal_reader.jac` called `PySlice(...)` in `read_slice()` without importing `PySlice`.

**Fix:** add `PySlice` to `marshal_reader.jac` imports. Gate reports `test_int passed=119`.

---

### 3b. ~~Layer-0 `test_str` complex-format ratchet (341 vs 345)~~ ✓

**Root cause:** `read_complex()` built `PyComplex(...)` without importing `PyComplex`.

**Fix:** add `PyComplex` to `marshal_reader.jac` imports. Gate reports `test_str passed=345`; full P3 Layer-0/1 ratchet green.

---

## Tier 2 - High value, more work (standalone JacPython)

### 4. ~~Native str/float/bytes `hash()` (FIXME Critical #1)~~ ✓

**Done:** SipHash13 + `_Py_HashDouble` ported to pure Jac in `pyhash.jac`. SipHash keys from process-local `PYTHONHASHSEED` bootstrap (LCG / zero / `os.urandom`). `bytes_hash_data` routes `bytesobject.jac` through the same machinery; Layer-1 bytes hash probe passes.

---

### 5. ~~Runtime parity in `test_p3_object_core_gate` (FIXME M11)~~ ✓

**Done:** `layer0_replay_p3_runtime_gate.jac` + manifest `runtime_probe` entries.

---

## Tier 3 - Correctness hygiene (prevent silent wrong code)

### 6. ~~P2 wave 4 - `pystricmp` NUL semantics + stronger gates (FIXME M1-M5)~~ ✓

**Done:** `pystricmp` reclassified `lift` in wave-4 manifest; staged oracle byte-synced to lifted corpus (NUL-terminated loop). Wave-4 staged-sync gate now mirrors wave 2/3 (manifest enumeration + lift byte-match). Added boundary oracles: empty strings, prefix mismatch.

---

### 7. ~~Set subset compare with element `==` (FIXME M9)~~ ✓

**Done:** `_set_contains_elem` + `_obj_eq_bool` in `objects.jac`; `_pyset_richcompare_na`, `set_lookup`, `isdisjoint`, and `in`/`__contains__` route through element `==`. Regression in `pyc_first.jac` (identity-keyed `AlwaysEq` user objects).

---

## Tier 4 - Explicitly later (your deferred list)

### 8. ~~bytes native hash / SipHash secret policy~~ ✓

**Done:** `bytes_hash_data` in `pyhash.jac`; `bytesobject.jac` uses SipHash13 via shared process-local secret bootstrap (same seam as str hash). Removed host `::py::` delegate.

---

### 9. ~~bisect/heapq JacPython~~ ✓

**Done:** `jacpython/_bisectmodule.jac` + `_heapqmodule.jac` facades; `layer_p2_libtest.jac` registers `bisect`/`heapq` stdlib shims; four libtest snippets marked `jacpython_capable`; conformance ratchet extended to `_bisectmodule` + `_heapqmodule`.

---

### 10. ~~Full Objects/ lift, heap types (P5)~~ ✓

**Done:**

- **P5 heap types:** `type_ready()` wired into `make_pyclass_from_map`; `PyClass.tp_flags` records READY state; `enum` removed from `layer3_force_host` force-proxy list.
- **Bulk Objects/ c2jac waves:** curated corpus → `Objects/_lifted/` → `jacpython/*.jac` → probes for **44** `c2jac_objects_wave` stems (P3.1c-P3.2e). Includes prior cores (bool/slice/abstract/tuple/long/type/exceptions/bytes/list/dict/set) plus method/descr (P3.2b) and remaining Objects stems (float/complex/range/enum/cell/func/iter/class, code/module/weakref/bytearray/memory/frame/gen/odict, union/namespace/capsule/structseq/file/call/bytes_methods/picklebuf/genericalias/typevar/interpolation/template/object/unicodectype/unicode). Gate: `test_p3_object_core_gate.jac` lift ratchets + M11 runtime probes.

**Still deferred (not Tier 4 bar):** deep algorithm ports beyond curated helpers (full unicode, timsort, real GC weakref, etc.).

---

## Next up (post-TODO)

1. ~~**Deepen Objects cores**~~ ✓ - native range/bytearray/str-bytes methods; gen/frame attrs; memoryview; enumerate/reversed; weakref shim; PyIter drain; odict/structseq leaf helpers (see Tier 4 / Also done).
2. ~~**Full `PyType_Ready` slot lifecycle**~~ ✓ - ``type_slots.jac`` + ``finalize_class_slots`` layout; ``PyMemberDescr`` type-dict install; instance ``__dict__`` omits slot members; Band 5 ``__slots__`` codegen oracles (`compiler_slice` / `layer9`).
3. ~~**Standalone SipHash secret**~~ ✓ - `pyhash.jac` boots keys from `PYTHONHASHSEED` (CPython LCG / zero / `os.urandom`); no embedding `_Py_HashSecret` ctypes shim

Post-TODO queue is clear of the three axes above. Further work is opportunistic deepen / Band 6+.

### Parked (do not block Band 10)

- **Band 10 `CALL_FUNCTION_EX`** - codegen + `compiler_slice` / `layer9` / VM fixtures landed
  this session (`BAND10_SLICE_LEARNINGS.md`). Ship without waiting on the parser.
- **Parser: trailing `**` after named kw** - native PEG drops `**d` in `g(a=1, **d)` /
  `g(*a, b=1, **d)`. Workaround: `g(**d, a=1)`. **Upstream:**
  [jaseci-labs/jac#8473](https://github.com/jaseci-labs/jac/issues/8473). Fix on a
  **separate parser branch** only; do not mix into heapq / Band 10 / deepen PRs.

### Suggested parallel workstreams (distinct file ownership)

1. ~~**Finish heapq/bisect product path**~~ ✓ - native jacpython facades (`_p2_*`, no `::py::`); Modules stay C-API hand oracles; staged-sync + facade parity gates.
2. ~~**Parser #8473**~~ ✓ - trailing `**` after named kwargs (`pa_join_sequences`); merged onto `jac-python`.
3. ~~**P2 leaf deepen / `_stat` / `_opcode` facades**~~ ✓ - native `jacpython/_statmodule.jac` + `_opcodemodule.jac`; libtest shims + facade parity; `opcode_meta2jac` emits `OPCODE_HAS_*` classifiers.
4. ~~**Compiler deferral slice: try/except/finally multi-handler**~~ ✓ - `visit_try_except_finally` chains N handlers (typed/bare), else, finally; nested try in body/handler publishes extents + inline enclosing epilogues; oracle-parity gates in `compiler_slice` / `layer9` (247 + 188). Except-as binding in the finally path remains deferred.
