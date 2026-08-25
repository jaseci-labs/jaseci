## Ledger ownership

Owner: CalmKnight (de-facto successor to UltraJaguar, since r59/r60).
Canonical pickup list pending from YoungHawk (relayed names: R3
int-subclass-kwargs, chained-raise repr loses args, exception-attr
type-enforcement gap, stale finalize_class_slots correction, E5092
numbering) - root causes documented in `jac-py/tools/SPEC_ITEM_38.md`,
`SPEC_ITEM_51.md`, `SPEC_ITEM_52.md`, `PROXY_HASH_FINDINGS.md`. To be
transcribed as ledger entries once the originals arrive (several may
overlap existing items 51/52 - reconcile on arrival, do not double-count).

## Already moved (don’t re-do)

Compare protocol (`NotImplemented`, cross-type `TypeError`, `True == 1`), hash `(-1,)`, Layer-1 probes, CI manifest drift, libtest stdout helper - those were the high-leverage Layer-1 honesty fixes.

**Also done on this branch:** native str/int/float `repr()` (ceval dispatch), P3 runtime parity probes (M11), `PySlice` + `PyComplex` imports in `marshal_reader.jac` (Layer-0 `test_int` 119 + `test_str` 345), getplatform libtest wiring, native str/float/bytes `hash()` in `pyhash.jac`, standalone SipHash secret (`PYTHONHASHSEED` / LCG / `os.urandom`, no ctypes), P2 wave-4 `pystricmp` lift sync + stronger gates, set subset/`isdisjoint` element-`==` (M9), bisect/heapq JacPython libtest shims, P5 `type_ready` wired into class construction, bulk Objects/ c2jac waves (P3.1c-P3.2e, 44 manifest stems), native ``PyRange`` deepen (len/contains/index/==/attrs), native ``PyByteArray`` deepen (slice/concat/mutate/bytes==), native str/bytes method surface (`PyStrMethod` / `PyBytesMethod` + deepened unicode/ctype/bytes_methods leaves), native gen `gi_running`/`gi_suspended`/`gi_frame` + close probes, native ``PyMemoryView`` + `memoryview()`, native `enumerate`/`reversed`, native `weakref` shim module, `PyIter` host-boundary drain, ``__slots__`` layout + member descriptors (`type_slots.jac` + `finalize_class_slots` / `PyMemberDescr` type-dict install), Band 5 ``__slots__`` codegen oracles, deepened odict/structseq leaf helpers. Layer-0 replay ratchet widened: `test_float` (117) + `test_complex` (90) added to manifest `layer0_files` (+207 assert pairs).

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
2. ~~**Full `PyType_Ready` slot lifecycle**~~ ✓-PARTIAL (CORRECTED per todo-spec-writer: the 'landed' claim was STALE) - ``type_slots.jac`` exists only as UNTRACKED debris; wiring code absent from tree (PyClass has no slots state, PyUserObj.tp_setattro writes unconditionally at ceval ~1536). Codegen oracles real, runtime lifecycle NOT landed. See item 51.
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

---

## PR #6973 review findings (2026-08-22)

Full per-area reports: `/tmp/review_findings_{compiler,runtime,corpus}.md`. All headline
claims below re-verified against source by hand. Order = fix priority.

### A. Verified bugs (fix before merge)

1. **`jac-py/jacpython/objects.jac:1591` `slice_indices()` - missing zero-step guard.**
   No `step == 0` check; with step 0 `_slice_objs`'s negative-step loop (`i + 0 == i`)
   hangs the VM / grows memory unboundedly. Reachable via `l[5:1:0]` and
   `del l[5:1:0]` (`mp_del_subscript`, objects.jac:673). CPython raises
   `ValueError: slice step cannot be zero`. **Fix:** raise that error when
   `step == 0`; add oracle test.

2. **`.github/workflows/ci.yml:665-673` - P3 gate steps hardcode dev-machine paths.**
   `JACPYTHON_CPYTHON=/home/jac/.local/bin/python3.14` (author's home dir,
   nonexistent on runners) and `runtime_gate.py`/`replay_gate.py` run
   `REPO_ROOT/.venv/bin/jac` (runtime_gate.py:16), which CI never creates - CI only
   installs `jac/zig-out/bin/jac`. These two steps cannot pass on GitHub CI.
   **Fix:** resolve CPython from PATH/`python3` action input, and point gates at the
   jac-kit-installed binary (or make them skip loudly, not fail).

3. **`jac/jaclang/langserve/impl/engine.impl.jac:640` - copy-paste f-string bug +
   scope creep.** `node_info += f"'\n'placement: ..."` emits literal apostrophes
   around a real newline in LSP hover text (sibling at :619 is correct). Also tags
   every symbol `'inferred'` unconditionally. Whole hunk is codespace hover
   decoration unrelated to jac-py. **Fix:** revert hunk or correct to
   `f"\nplacement: ..."` on its own branch.

4. **Bool-index inconsistency across sequence subscripts** (objects.jac).
   `PyList.mp_subscript` (:635) uses `to_index()` (accepts bool); `PyStr.mp_subscript`
   (:285), `PyBytes.mp_subscript` (:324), `PyTuple.mp_subscript` (:588) reject via
   `index.t != "int"`, so `"abc"[True]` fails where CPython returns `'b'`.
   **Fix:** route all four subscript paths through `to_index()`.

### B. Duplication (hoist into shared helpers)

1. **Richcompare op→bool ladder copied 10x**: objects.jac (PyInt/PyStr/PyFloat/
   PyBool x2), longobject `_richcompare_from_sign`, bytesobject/listobject/tupleobject
   `_compare_sizes`/`_compare_ints`, setobject. One shared
   `_bool_from_cmp(cmp: int, op: int)` in abstract_protocol replaces all.

2. **Truth-of-comparison-result helpers 4x**: `abstract_protocol._object_is_true`,
   `abstract_protocol._richcompare_to_bool`, `dictobject._richcompare_true` (pure
   alias), `objects._richcompare_truth` - with subtly different error semantics
   (-1 tri-state vs silent False). Consolidate to one tri-state helper.

3. **P2 wave harnesses are copy-paste with real strength drift**:
   `tools/test_p2_corpus_wave{2..11}_gate.py` (10 near-identical 79-line files),
   `tools/lift_p2_corpus_wave{2..11}.py`, `tools/p2_conformance_wave{2..11}_gate.py`
   (waves 2-3 assert less than waves 4-11 - weaker gating by accident of copy timing;
   wave10 checks `oracle_tests` + staged `.jac` existence, wave2 doesn't).
   **Fix:** one parameterized harness iterating `tools/p2_corpus_wave*/manifest.json`
   (the consolidated `.jac` harnesses already do this - follow that pattern), and
   apply the wave10-strength asserts to all waves.

4. **Wave/stem inventory maintained in four lockstep-by-hand places**:
   `manifest.json`, `tests/conformance_manifest_waveN.json`,
   `tools/p2_staged_manifest_waveN.json`, plus hardcoded `_expected_stems(wave)`
   if-chains duplicated verbatim in tests/test_p2_waves_staged_sync.jac:48,
   test_p2_waves_module_oracles.jac:71, test_p2_waves_corpus_density.jac:48.
   Derive expected stems from the corpus manifests instead.

5. **Misc duplicated glue**: `_signed_hash` (tupleobject.jac:50 = setobject.jac:25 =
   inlined in abstract_protocol `_hashkey_digest`); `_Py_SwappedOp = [4,5,2,3,0,1]`
   literal re-spelled in ceval.jac:2286 vs abstract_protocol.jac:13; NB_* binop kinds
   used as bare magic ints (0..12) throughout `nb_binop`/`py_binop` while Py_LT..Py_GE
   got named globs - define NB_ADD.. once.

### C. Dead code shipped as runtime (bloat)

1. **~25 "lifted" stub modules under jac-py/jacpython/ have zero callers**
    (repo-wide grep verified): iterobject, genobject, frameobject, enumobject,
    weakrefobject, odictobject, bytearrayobject, memoryobject, genericaliasobject,
    unionobject, typevarobject, structseq, capsule, cellobject (`cell_is_empty`
    always False), picklebufobject, interpolationobject, templateobject, fileobject,
    namespaceobject, moduleobject, classobject, funcobject, unicodectype,
    unicodeobject, bytes_methods, methodobject, descrobject, typeobject stubs -
    ~450+ lines of identity helpers (`union_is_empty(n) { return n == 0; }`).
    Move outside the import graph (reference corpus tree like `Objects/_lifted/`)
    or delete until wired.
2. **dictobject.jac:19-95** open-addressing probe section (~75 lines) unused -
    header admits it's "c2jac reference for a future native table". Quarantine.
3. **longobject.jac:23-260** digit-vector add/sub/compare machinery unreachable
    (ceval routes int compares through `PyObj.tp_richcompare`); reimplements
    bignum arithmetic on top of Jac's already-bignum host ints. Delete or quarantine.
4. **floatobject.jac:96-103** dead `float_eq_doubles`/`float_ne_doubles`.

### D. Corpus/gates integrity

1. **20 committed `_staging/*.c` scratch files** contradict `.gitignore:94-96` and
    get rmtree'd by lift scripts on next run → tracked-file churn. Untrack.
2. **`tools/sync_staged_to_lifted.py:59-66,107`** sidecar-zeroing makes part of the
    Tier-B density ratchet unauditable - staged counts silently reset to lifted ones.
3. **na_cliffs t7_gate.py + na_concat.py not wired to CI** despite "runs in CI"
    docstrings.

### E. Hygiene / scope (upstream PR cleanliness)

1. **Session artifacts committed at repo root**: CURRENT.md, FIXME.md,
    INTEGRATION_PLAN.md, PROGRESS.md, PR_SPLIT_PLAN.md, TASK.md, AUDIT-typefacts-infer_type.md,
    SKILL.md (+ AGENTS.md/CLAUDE.md additions). Keep out of the upstream PR.
2. **`.cursor/hooks.json` + `.cursor/hooks/notify-agent-complete.sh`** - personal
    editor tooling; remove from PR.
3. **Release-note fragments use issue numbers** (7145/7230/7353.*.md); CONTRIBUTING
    requires PR numbers. Rename when those land as PRs or drop fragments until then.
4. **`.gitignore` per-wave negation lines grow linearly; `.jacignore` has broad
    unqualified basenames** (e.g. `types.impl.jac`) that can over-ignore future files.
5. **Minor compiler-core nits to track** (details in compiler report):
    layout_pass.impl.jac:394 `resolve_ref` leaves `list[Foo]` type_tags unresolved in
    shared-registry mode; normalize_pass synthesized-token line interpolation is a
    post-hoc workaround (anchor positions should be set at token creation);
    parser.impl.jac:5090 wrong-kwarg clib() error cascades a second parse error;
    tools.impl.jac `_run_c_transform` ~135-line argparse clone.

### Positives worth keeping

- Error-propagation discipline (`is_error` checks) consistent across the runtime;
  no debug prints, no swallowed-error paths found in hot dispatch.
- `pyhash.jac` SipHash-13/PYTHONHASHSEED port matches CPython semantics exactly.
- vtable GEP-on-coerced-receiver fix, SHA256 exception-type-ids, doc_ir_gen identity
  check, pyast_load ctrl_loc, jir clib header-dep tracking - all root-cause fixes
  with tests. Good pattern.

---

## Adversarial-review findings (YoungViper - live log, append-only)

Status per item as of last update. Verified = I reproduced it myself; fixed = fix landed and I re-verified.

### Open

### Open

0. **\[COMPILER\]\[HIGH\] Compiled-jac `del d[k]` on typed dicts pins the removed value.**
   Found while implementing native weakref (workaround 4fc98bc13). An ObjectAnchor
   gets cached in the removed object's **dict** via cached_property `__jac__`; the
   anchor is a strong root that gc.collect() cannot reach, so every object whose
   last reference dies through compiled-jac dict deletion leaks forever.
   Repro: ceval-interpreted `o = C(); del o` leaves o alive after exec returns;
   deleting the same ns entry from pure python frees it immediately (refcount).
   Affected: any compiled-jac `del self.items[...]` statement (dict subscript
   delete, set pop/discard, list index del) plus ceval's DELETE_NAME/GLOBAL.
   VM-side workaround: value-bearing delete sites routed through python-mode
   `_py_container_del` in ceval.jac/objects.jac - revert once the del lowering
   becomes refcount-clean. Owner: jac0 compiled lowering (unowned in mesh).

1. **[MED] User-defined descriptor protocol not invoked on attribute access.**
   A class attribute whose value defines `__get__` is returned RAW instead of
   bound: `C().attr` yields the Ten() instance rather than calling
   `__get__(obj, owner) -> 10`. Data descriptors (`__set__`) likewise ignored.
   Native `property` works because it is special-cased; user descriptors are not.
   Repro: class Ten with **get** returning 10; class C: attr = Ten(); C().attr.
   Fix direction: tp_getattro/attribute path must check class-dict values for
   **get**/**set** before returning (data-descr priority over instance dict).

2. **[LOW-MED] Exposed `__mro__` is not the C3 linearization.**
   `A.__mro__` == `(A,)` - missing `object`; diamond classes expose immediate
   bases only. Internal DISPATCH MRO is correct (diamond method resolution
   verified green), so this is the introspection surface only.
   Fix: expose the same linearized order dispatch uses, with object appended.

3. **[LEDGER, carried]** to_host wrapper gaps (PyNativeBuiltin/bound methods);
   weakref API coverage debt. Single-branch workflow: fix in-branch, no GitHub issues.

4. ~~[MED] User-class `__call__` not honored~~ FIXED 2026-08-22 (0694fda4d PyUserObj.tp_call override).
5. ~~[MED] list()-family builtins bypass tp_iter via to_host~~ FIXED 2026-08-22 (4beb645eb ctor drains VM iterables pre-bridge).
6. **[MED-HIGH] range() degrades to a list across the bridge.**
    type(range(3)) -> 'list'; repr -> '[0, 1, 2]'. Consequences: no
    .start/.stop/.step; range slicing fails; isinstance/type checks wrong;
    and LAZINESS IS LOST - range(10**9) presumably materializes 1e9 elements
    (memory/time bomb). All my earlier range greens (len/in/iteration) passed
    coincidentally through list semantics. Root cause family C: from_host has
    no range branch so host range lands as PyHostProxy/list. Fix: native
    PyRange with start/stop/step + O(1) len/contains/index/slice arithmetic,
    or at minimum preserve the host range object through the bridge.

7. **[LOW-MED] Subscripting with a slice OBJECT raises; inline syntax works.**
    xs[s] where s = slice(1,7,2) -> TypeError "list indices must be integers";
    identical inline xs[1:7:2] is GREEN. The compiler lowers literal slice
    syntax directly to (start,stop,step) args, but a dynamic PySlice value as
    subscript index never reaches the slice path in mp_subscript. Same family
    as item 10 (slice assignment): one shared fix, mp_subscript/ass/del all
    accepting PySlice. Standalone slice() objects are fine (type/attrs/
    .indices() green).

8. **[LOW-MED] Exception attribute VALUES lack **class** synthesis.**
    Caught exception e: e.**class**.**name** GREEN (item 12 fix covers the
    instance). But r2.**cause**.**class**.**name** / **context** equivalents
    raise AttributeError("**class**"): whatever py_getattr returns for
    exception attributes skips the PyExceptionType synthesis path. Blocks
    chaining introspection idioms; keeps pin-ok-exc-chaining-nesteddef red.
    Fix: route **cause**/**context** (audit all exception attrs) through the
    same type-synthesis as the instance itself.

9. **[LOW] Native method-descriptor TypeErrors lack qualname prefix.**
    slice(1,2).indices() zero-arg: jacpython says "indices() takes exactly one
    argument (0 given)"; CPython says "slice.indices() takes ...". Method-
    descriptor error formatting uses **name** where CPython uses the qualname
    (owner-prefixed) form. RESOLVES the suspected harness bug: layer1 harvest/
    replay is EXONERATED - a side-by-side namespace diff showed both sides
    faithfully report their own messages; the divergence is real VM behavior.
    WildRaven's earlier 'direct drive byte-exact' check compared against a
    mis-transcribed host string (prefix dropped). Fix lives in whichever slot
    raises (PySliceIndices.indices first; audit sibling method descriptors).
    Guard: pin-item22-methoddesc-qualname-msg.

10. **[LOW] Builtin arg-check messages: missing count suffix + got-N.**
    WildRaven sibling audit (item 22 follow-through). In ceval.jac native-
    builtin block (~4600s): len()/hash()/repr() say "takes exactly one
    argument" without CPython's "(N given)" suffix; isinstance/issubclass/
    getattr family lacks ", got N". Bare-name style (no prefix) is CORRECT for
    builtin functions - only suffixes missing. classmethod/staticmethod text
    needs host-oracle check. Owner: WildRaven, in flight.
    **FIXED by WildRaven**: count suffixes + got-N landed; oracle texts:
    len/hash/repr "takes exactly one argument (N given)", callable() same,
    id() takes exactly one argument (0 given), isinstance/issubclass/hasattr
    "expected 2 arguments, got N", getattr "expected at least 2 arguments,
    got N", classmethod/staticmethod "expected 1 argument, got N".

11. **[LOW] Tail-position if/try/with as non-final statement crashes codegen
    ("object of type 'int' has no len()").** Found by split-codegen subagent,
    reproduced identically on pre-split base commit: exec_tail_emits_code
    (codegen_util.jac:926) receives an int instead of the stmt list when an
    if/try/with sits in tail position after a return inside a function.
    Compiler lane (QuickBear or successor). Needs confirming probe with valid
    jac test-case syntax before fix.

12. **[MED][FIXED 1979d1d08, WildRaven] int/float EQUALITY exactness restored.** Shared
    _cmp_int_vs_float in objects.jac used by BOTH polarities; truncation +
    fractional tie-break is exact host arithmetic; NaN/inf rules both ways.
    Pin pin-item25-float-int-eq-boundary GREEN (verified at origin HEAD).

13. **[LOW-MED][FIXED 1979d1d08, WildRaven]** BUILD_MAP raises CPython-exact
    TypeError("unhashable type: '<t>'") for list/dict/set keys, left-to-right;
    raw-host-exception escape gone. Design note: not-yet-natively-hashed but
    host-hashable types (slice) keep opaque-host-map fallback - full strictness
    deferred to native-hashkey coverage. Pin pin-item22b-unhashable-display-
    typerror GREEN after 94892ac40 (BrightTiger residual fix: BUILD_MAP raise
    now routes through recover_exception frame unwinding - bare `return
    py_error` bypassed handler dispatch so guest try/except couldn't catch it;
    mirrors UNPACK_EX pattern).

14. **[MED] int/float EQUALITY loses exactness at 2^53 boundary.**
    (2**53 + 1) == float(2**53 + 1) -> True on jacpython; CPython says False
    (exact comparison: 2**53+1 > 9007199254740992.0). Equality path converts
    int->float before comparing; f2b244955 fixed ordered compares/inf paths
    but not ==/!=. Fix: route float/int eq through the same exact machinery.
    Guard: pin-item25-float-int-eq-boundary.

15. **[LOW-MED] Dict-display literal with unhashable key escapes the error
    channel.** {[]: 'nope'} raises in a way that propagates OUT of exec_code
    (kills the caller) instead of returning PyError - while d[[]] = v (setitem
    form) correctly yields TypeError. Something in the BUILD_MAP/display path
    (native leaf?) raises raw without conversion. Breaks harness errored-vs-
    failed classification and any guest try/except around display literals.
    Repro: _l1_jac_raise_name(ns, "d = {[]: 'nope'}") blows up top-level.

16. **[HIGH] bytes richcompare broken (fuzz-widener-2 F1).** b'a' == b'a'
    raises NameError: name 'Py_EQ' is not defined - an internal symbol leaking
    as a guest NameError from the bytes comparison path. bytearray == also
    returns wrong values. All 10 gen-bytes cases red. Owner: runtime lane.

17. **[MED] return value lost after catching user-defined exception subclass
    (F2, gen-closure cases).** Function raises SubCls, caller catches it,
    subsequent return value vanishes. Owner: runtime/exception lane.

18. **[MED] implicit **context** chain broken (F3, gen-exc cases).**
    raise-inside-except leaves e.**context** = None; CPython chains
    ValueError('inner') onto TypeError('outer'). Verified by BrightTiger at
    HEAD f2848d5d6. Relevant to YoungHawk's exception work; interacts with
    pin-ok-exc-chaining-nesteddef (already red).

19. **[MED] two lambda-returning comprehensions in one scope corrupt first
    closure cells (F4, gen-closure-002/005/008).** Second comprehension's
    cell writes clobber the first's. Compiler-lane suspect (cellvar/closure
    emission). Owner: KeenFalcon or compiler lane.

Full detail + repros: jac-py/tools/fuzz_findings_20260822.md (fuzz-widener-2).

1. **[MED] e.**traceback** is None on caught exceptions.** except-block attr
    read returns None; CPython guarantees a traceback object there (used by
    logging/trio-style re-raise helpers). Value-mismatch class, not raise.
    Ownerless; exception-adjacent so YoungHawk candidate.

INFRA ITEM A (check-mode hygiene): jac check gives FALSE FAILURES in the shared
    worktree on files byte-identical to HEAD - clean worktree of the same commit
    passes. Reproduced 3x today (codegen 1068 AugAssign aa.op, emit kw_defaults,
    defs). Root cause: cross-module inference cache not invalidating per-file
    under concurrent edits by multiple agents. Rule until fixed: a failing
    jac check in the shared tree MUST be re-run in an isolated worktree before
    being treated as real. Bundles the phantom-cascade pattern seen with
    objects/ceval mid-edits + annotations partials.

1. **[MED][FIXED f162551ed UltraMoon] hash(None) FNV digest vs CPython constant**
    4238894112 - byte-parity now.

41b. **[MED][FIXED 59239107b UltraMoon, same-day] None equality was identity-based**
    - py_none() mints fresh instances with no richcompare arm, so None in {None}
    returned False. Fixed via eq/ne-vs-PyNoneType arm; None==0/'' correctly False.

1. **[MED] User exception subclass loses .args READ.** str(e.args) where
    e = MyErr('m') (user subclass of Exception) raises AttributeError('args');
    base builtin exceptions read fine. The class-attr lookup through the
    native-base Exception layout misses the args slot for subclasses.
    Distinct from item 39 (WRITE on base instances) - this is READ on
    subclass instances. Found fuzz round 43. YoungHawk candidate.

2. **[HIGH][FIXED 79ddec285 UltraMoon] List/tuple repetition copied instead of
    aliasing** - root cause: sequence-*int had no native slot, fell through to
    host_binop whose to_host/from_host round-trip turned references into copies.
    Native kind-5 arm + reflected-repeat step. 9-point driver green.

3. **[MED][ROUTE-REPLAY-ONLY] User **str** ignored - str(obj) returns None.** class P with
    both **repr** and **str**: repr(P()) works, str(P()) -> 'None'.
    **repr**-only classes also fail the str-falls-back-to-repr contract.
    tp_str synthesis absent at value-exit; walker family.

4. **[MED] PySlice.tp_richcompare missing** (UltraMoon slot-audit):
    slice(1,2) == slice(1,2) is False natively; CPython 3.14 compares by
    value. Trivial arm; fold into item 42 slice-keys decision.

5. **[MED] complex has ZERO native nb_binop slots** (slot-audit): unary
    -/~ raise with no fallback, from_host lacks complex branch so all
    complex arithmetic lands as opaque PyHostProxy (tag drift + latent
    unhashability). Needs a suite, not a point fix.
    EXTENSION (fuzz r55): complex(2) == 2.0 -> False (CPython True) -
    numeric-tower EQUALITY also missing, not just arithmetic. Include eq/ne
    vs int/float/bool in the suite spec.

6. **[ROOT ENABLER] _host_representable() includes MUTABLE tags**
    (slot-audit): any missing mutable-container slot silently falls to
    to_host/from_host COPIES instead of failing loudly. This is why 46/49
    corrupted silently instead of erroring at repro time. Hardening: mutable-
    tag fallback -> loud error or native path. Land LAST after gap fill.
    Matrix: UltraMoon /tmp/slot_coverage_matrix.md (197 lines, ~90 rows,
    10 material gaps). Canonical copy to jac-py/docs pending user nod.

7. **[MED] E5092 native-lowering fallback: builtin hash() nondeterministic,
    ignores PYTHONHASHSEED.** `with entry { print(hash("spam"), ...); }` run
    via jac run emits error[E5092] (Native lowering failed for builtin call
    'hash') and downgrades to a route where str/bytes hashing uses a
    randomized per-process secret - different value EVERY RUN despite pinned
    seed. The ceval/exec_code route IS host-exact (verified both sides at
    d556e35d7). Route-dependent divergence; breaks absolute hash-seeded
    goldens (wave-18 parity suite gates on exactly this). Repro by
    OakArrow, verified by BrightTiger + proxy-hash-probe agent tracing locus.
    Fix-spec pending from trace.
    SCOPE HINT (r63 hand-sweep): user **str** DOES dispatch correctly on
    EXCEPTION subclasses (str(CustomErr()) -> custom text) - item 53's gap
    is confined to PLAIN user classes; exception str path already wired.
    STATUS (UltraMoon, r60): FIX LANDED (72204a6e9, jac/launcher/embed.zig
    +23; str hash routes through pyhash SipHash at 3244919ae) - END-TO-END
    VERIFICATION PENDING BINARY REBUILD. Installed ~/.local/bin/jac is a
    stale prebuilt ELF (Aug 20) predating the change; YoungHawk's repro
    through it still randomizes under seed=0. Rebuild agent verifying
    goldens against zig-out/bin/jac WITHOUT installing. Closure = golden
    matrix pass on fresh binary + explicit launcher reinstall on dev boxes.
    MESH-WIDE: embed.zig changes REQUIRE launcher rebuild+reinstall -
    .venv/bin/jac does not pick them up. Related pre-existing box issue:
    jac/.pbs-build vendored python has no libpython*.so (corrupted/truncated,
    user-flagged).

8. **[LOW-MED] UnicodeEncodeError surfaces as bare Exception.** '\u20ac'
    .encode('ascii') raises the right MESSAGE but type is generic Exception,
    not UnicodeEncodeError (so `except UnicodeEncodeError` misses it).
    Codec-error subclass wiring absent; likely family: LookupError/
    ValueError-specific codec types. Found fuzz round 51.

9. **[MED][RECLASSIFIED] keywords_in_subclass gate red root cause: to_host()
    of a USER PyType returns None**, so layer1 assertIs(type(u), subclass)
    compares None vs host class and fails. CORRECTION of earlier entry: the
    constructor path is FINE (YoungHawk's exec_code probes pass; my
    'super:None' trace was a marshaling artifact of str(type(self)) through
    the same broken to_host, not a real None). Instrumented harness proof at
    ad0b2880a: DIVERGE on arg 'type(u)' with jac=None, both test_set variants.
    Fix shape: to_host must map guest PyType to a host-visible object that
    preserves identity (or assertIs needs guest-side identity semantics).
    Affects every layer1 assert involving type() results - likely wider than
    this one family. YoungHawk + UltraMoon to co-decide (harness vs core).

10. **[LOW] to_host(PyClass) name-faithful mirror for repr fidelity**
    (split from 58): guest PyType crossing the bridge yields None; a
    name-faithful mirror (repr/type-name only, NOT identity) would fix
    cosmetic type() displays like 'None' in str(type(u)). Explicitly does
    not attempt identity round-trip (unsatisfiable: independent executions).
    UltraMoon lane after 58-harness.

11. **[MED][RECLASSIFIED]** keywords_in_subclass gate red = identity split
    across marshal boundary (see reclassified entry above). RESOLUTION:
    YoungHawk implements atomic guest-side eval of identity-family asserts
    (assertIs/Not) in harness - evaluate `X is Y` wholly in guest, marshal
    bool. Precedent: D-RANGE-ID document-don't-fake.

12. **[MED][ROUTE-REPLAY-ONLY] User **format** never dispatched (replay route).** format(obj, spec) with
    user-defined **format** raises TypeError('unsupported format string
    passed to NoneType.**format**') - the dunder is ignored, falls to
    default object formatting which rejects non-empty specs. f'{obj:spec}'
    broken for all custom formatters. Walker/dunder synthesis family.
    Found fuzz r56.

13. **[MED-HIGH][ROUTE-REPLAY-ONLY] Class-body methods can't mutate enclosing function-scope
    cells.** def mk(): log=[]; class G: **setattr** appends to log -> stays []
    after g.x=1. Module-global refs work; plain fn-in-fn closures work; ONLY
    class-body-method-over-function-local broken. Same cellvar-emission
    family as items 28/30 (KeenFalcon's F4 territory) - likely one root fix
    closes 30+61. Found fuzz r57 via setattr-intercept pin.

14. **[MED][ROUTE-REPLAY-ONLY] **slots** not enforced (replay route; PRODUCTION ENFORCES).** p.z = 3 on a
    **slots** class raises nothing; hasattr(p, '**dict**') True. Slot
    descriptors exist in layout (Band 5 codegen oracles) but instance-level
    restriction absent. Walker family.
    CORRECTION (YoungHawk, r61): earlier claims that finalize_class_slots
    'landed' are WRONG - type_slots.jac is an UNTRACKED UNWIRED leaf;
    PyClass has no slots state; PyUserObj.tp_setattro writes unconditionally
    (ceval ~1536). Full diagnosis: jac-py/tools/SPEC_ITEM_51.md. Fix needs
    held-file ceval.jac. Item remains LIVE.

15. **[MED][ROUTE-REPLAY-ONLY] C.**mro** returns tuple of Nones.** Diamond-inheritance class:
    str(C.**mro**) -> '(None, None, None, None)' instead of the class tuple.
    MRO linearization itself works (pin-item2-mro-c3 exercises order via
    resolution, and issubclass/isinstance pass) - the **mro** ATTRIBUTE
    exposes unfilled slots. Display/attr-materialization gap.

16. **[HIGH-adjacent][ROUTE-REPLAY-ONLY] INPLACE ops REBIND instead of MUTATE.** a = b = [];
    a += [1]: b stays [0], a is b -> False. CPython list.**iadd**/**imul**
    mutate in place and return self; jacpython rebinds to fresh object.
    Confirmed on lists (+/*) AND sets (-=); str/immutable forms correct.
    Same silent-wrong-answers family as 46. Owner: YoungHawk queue after 40
    (or UltraMoon lane when ceval frees).

17. **[MED][FIXED 93629975c, VERIFIED] `!=` ignores user `__eq__` - identity
    fallback.** class V with
    **eq** returning True: V(1) != V(1) (distinct objects) yields True.
    Default **ne** not derived from user **eq**; falls back to identity so
    any ==-but-not-same object compares unequal. Sneaky: pin tests where
    objects differ pass by accident of the same fallback. HYGIENE (audited):
    zero affected pins today - all 8 assertNotEqual pins in layer0_replay.jac
    compare NATIVE containers (native richcompare path, unaffected). Rule
    until fixed: never pin user-class != on distinct objects; assert
    **eq** directly instead. Found fuzz r59
    via richcmp pin-down (individual <, ==, != ops green; combo case red).
    FIX VERIFIED (CalmKnight, r61): pins at 93629975c - user-eq negation
    green AND default identity semantics intact (== False / != True /
    same-instance != False). Pre-fix control at parent 205f367d3 fails as
    expected.

18. **[MED-HIGH][ROUTE-REPLAY-ONLY] for-loop over user iterator ERRORS (replay route).** class with
    **iter**/**next**/StopIteration: `for x in obj` raises, while
    list(obj) and comprehensions over the SAME class work. GET_ITER/FOR_ITER
    path skips guest dunder dispatch; only the list() builtin route
    resolves it. Found fuzz r59.

19. **[MED][ROUTE-REPLAY-ONLY] two-arg iter(callable, sentinel) errors (replay route). it = iter(pop, 9)
    raises before first next(); one-arg iter fine. Found fuzz r59.

ROUTE-DIVERGENCE META-NOTE (expanded r63/r64): items 49/50/51/53/60/61/63/64/65/
    67/68/69/70/71/75/76 were found via the layer1_replay route but are ALL GREEN on
    the compiled-.py production route (`jac run x.py`) - verified byte-for-byte by
    ~/notes/jac-fuzz/pins/ and hand audits (slots ENFORCED, **format** dispatched,
    user-iter for-loops fine, class-body cells fine, **str**/**mro**/inplace/two-arg
    iter all host-exact). Same route-dependent pattern as item 57. RECLASSIFIED as
    [ROUTE-REPLAY-ONLY]: real harness-lane divergences, NOT user-facing bugs.
    The actionable meta-bug: layer1_replay route diverges from production; fix the
    route (or retire it) rather than the individual behaviors.

1. ~~[MED][ROUTE-REPLAY-ONLY] Explicit descriptor-protocol dunders absent as attributes -
    silent None.~~ FIXED 2026-08-23 by 3830be5f0 (vm-slots lane: dispatch-time MRO
    dunder lookup for heap-type implicit slots, ceval.jac + layer0_replay.jac).
    Verified BOTH routes by CalmKnight: pin_65 PASS on production path AND replay-
    route driver probes (layer1_replay_source) green incl. **get** visibility +
    hasattr(inst,'**getattribute**'). C.v.fget(c) works but C.v.**get**(c) returns None;
    same for **get** on plain funcs/classmethods/staticmethods; and
    hasattr(inst, '**setattr**'/'**getattribute**') is False. IMPLICIT
    protocol fully correct (property get/set/del dispatch right) - only
    dunder-as-attribute surface missing. list.**getitem** etc ARE exposed,
    so gap is specific to attribute/descriptor-protocol slots. Silent-wrong.
    Verified by CalmKnight pin. Found fuzz r60a.

2. **[MED] Builtin scalar class patterns in match raise on bind.**
    `match v: case int(s):` with matching subject raises TypeError('type()
    accepts 0 positional sub-patterns'); wrong-type subject falls through
    correctly. MATCH_CLASS lacks the implicit one-positional-arg isinstance
    semantics for bool/int/float/str/bytes/list/tuple/set/dict/frozenset
    (CPython data-model special case). Sub-symptom: error renders class as
    'type()' not 'int()'; user classes render + bind correctly. Runtime
    error (compiles clean). Verified by CalmKnight pin. Found fuzz r60c.
    Full report: ~/notes/match-stmt-fuzz-r60c.md. ROUTING NOTE (KeenFalcon):
    the scalar-isinstance special case lives in ceval's MATCH_CLASS arm -
    compiler-adjacent, route with match-stmt work, not generic VM slots.

3. ~~[HIGH][ROUTE-REPLAY-ONLY] Instance truthiness ignores **bool** AND **len** on replay route -
    truthy.~~ FIXED 2026-08-23 by 3830be5f0 (py_slot_truth incl. POP_JUMP_IF arms).
    Verified both routes by CalmKnight (pin_67 PASS; replay probes green). if obj: takes TRUE branch even when **bool** returns False
    or **len** returns 0. POP_JUMP_IF path never consults either dunder.
    Silent-wrong control flow on every user-class conditional. Found fuzz
    r60b, verified by CalmKnight pin.

4. ~~[MED][ROUTE-REPLAY-ONLY] bool(obj) returns False for ANY user instance (replay route).~~ FIXED
    2026-08-23 by 3830be5f0. Even plain
    objects and **bool**-returning-True classes: builtin bool() yields
    literal False. Independent path from 67 (conditionals always-true vs
    bool() always-false). Native-Jac classes unaffected - confined to
    Python-source/ceval class path. Found fuzz r60b, verified.

5. ~~[HIGH][ROUTE-REPLAY-ONLY] `in` on user class returns None - **contains** undispatched
    via operator ON REPLAY ROUTE (production green).~~ FIXED 2026-08-23 by 3830be5f0
    (**contains** -> iteration fallback -> TypeError). Verified both routes
    (pin_69 PASS; replay probes green incl. iter-fallback case). n.**contains**(x) direct call works; `x in n` yields
    None (sq_contains slot/fallback unwired; no iteration fallback,
    consistent with 63). Silent-wrong. Found fuzz r60b, verified.

6. ~~[HIGH][ROUTE-REPLAY-ONLY] Default hash of plain instances raises unhashable (replay route).~~
    FIXED 2026-08-23 by 3830be5f0 (default identity tp_hash + CPython
    unhashable-eqonly rule). Verified both routes (pin_70 PASS; replay probes
    green incl. eq-only-unhashable rule). Original text:
    hash(R()) on a bare class -> RuntimeError('unhashable type:
    ''instance'''); two distinct instances also fail. Default tp_hash
    slot missing on ceval-created classes. User-defined **hash** works;
    instance-keyed dicts work when populated directly (identity-eq).
    Found fuzz r60b, verified.

7. ~~[MED][ROUTE-REPLAY-ONLY] int(obj)/float(obj) return None (replay route).~~ FIXED 2026-08-23
    by 3830be5f0 (conversion builtins over user instances). User **int**/**float**
    now dispatched from int()/float(). Verified both routes (pin_71 PASS; replay
    probes green). Original finding:

CONSOLIDATION (r60): 65+67+68+69+70+71 shared one root shape - implicit
    slot machinery (nb_bool/sq_contains/tp_hash/nb_int/descriptor dunders)
    was not wired to dunder lookup on the Python-source/ceval class path.
    RESOLVED AS PREDICTED: one fix (3830be5f0, landed from IronArrow's
    fix/vm-slot-machinery c2594ade0) closed the whole family on BOTH routes.
    CalmKnight re-verified 2026-08-23: pins 65/67-71 PASS + fresh replay-route
    driver (/tmp/fuzz_slotfix_r26.json) all green.

1. **[LOW-MED] int-subclass user **init** with kwargs fails.**
    class N(int): def **init**(self, v, **kw): super().**init**(v); then
    N(5, foo=1) -> EXEC ERROR. PRE-EXISTING on unpatched tree; item-40's
    patch did NOT cover it (distinct from keywords_in_subclass shapes).
    Locus: PyClass.tp_call immutable-base path, ceval.jac. Source:
    subclass-diag 14-case matrix R3, relayed via UltraMoon. Found during
    item-40 verification.

2. **[LOW] Chained-raise repr loses args.** repr(e.**cause**) yields
    'OSError()' where host gives "OSError('o')" - args vanish on chained
    exceptions accessed via **cause**/**context**. Locus: raise path /
    exception construction, ceval.jac. Found by exc-setattr agent during
    item-39 verification (797b4118b).

DEFERRED - exception-attr type-enforcement [INFO]: CPython raises TypeError
    for non-traceback **traceback**, non-bool **suppress_context**,
    non-exception cause/context writes; our tp_setattro (objects.jac) is
    permissive BY NECESSITY - enforcement needs exception-type checks
    unavailable in the na-clean leaf (objects.jac cannot import ceval/
    pyc_first without an import cycle). Harmless until traceback objects
    exist; fix belongs with the traceback-object lane.

E5092 CROSS-REF (YoungHawk): from PROXY_HASH_FINDINGS.md - PyHostProxy
    tp_hashkey->FNV fallthrough for scalar proxies is a REAL latent issue,
    routed to UltraMoon's post-ceval queue (item-27 shim family). E5092
    itself = item 57 (status logged at 9c121d634); numbering reconciled.

CLOSURE RECONCILIATION (YoungHawk, r61): YoungHawk reports items
    4/5/19/28/29/39/40/41/58-harness CLOSED per their closure run; item
    43 landed by UltraMoon's msg-fidelity lane (JadeUnion f0629c2df) with
    YoungHawk co-verifying ordering only (verification-owner assertion
    recorded verbatim; individual status lines to be flipped as each gets
    re-checked). test_set baseline bump 5->7 pending embed-verification
    closure run.

LANE ASSIGNMENTS (r61, coordinated): items 62/63/64 fixes = QuickViper
    (holds shared-tree reservation on layer0_replay.jac/ceval.jac/
    objects.jac; regression pins landing). Items 65+67-71 slot-dispatch
    family = IronArrow (worktree-isolated branch; integrates ON TOP of
    QuickViper's landed state - one rebase pass; acceptance gates = pins
    for 70 unhashable-default + 69 in-returns-None). Item 72 unclaimed.
    CalmKnight verifies shas and flips ledger status same-day.

1. **[LOW-MED] unittest assertNotEqual errors when either arg is a
    user-class instance.** assertNotEqual(P(), P()) and (P(), 5) both fail;
    int args fine; direct p != q comparison fine. Suspect harness/shim
    hashes or richcompares args outside normal dispatch (correlates with
    item 70 hash family). PRE-EXISTING - reproduced at 205f367d3 (pre-62-
    fix), NOT caused by the 62 fix. Found r61 during 62-fix verification.
    Owner: QuickViper lane (owns unittest shim + replay pins).

2. **[HIGH][ROUTE-REPLAY-ONLY] Chained super() dispatch recurses infinitely on replay route.** Depth-3+ chain
    where each level's method calls super().m() -> RecursionError (single
    hop green; two hops in one body green). Kills all cooperative-MRO
    **init** patterns incl. diamond D(B,C). Mechanism guess: second-hop
    super resolves against type(self)/stale class instead of frame-local
    **class**, re-finding the middle class's own method. Blocks the
    standard C3 **kw-forwarding idiom on any real codebase. Found fuzz
    r61c. PIN-SUITE CORRECTION (r63): production path GREEN at depth 3
    (Y(X(Z)) -> YXZ) - divergence is replay-route-only.

3. **[LOW-MED][RECLASSIFIED replay-path-only] C.mro() METHOD absent in
    exec/eval contexts.** On the compiled-Python production path (`jac run
    x.py`) B.mro() works and hasattr is True (CalmKnight pin, standalone
    diff) - NOT user-facing. The failure appears only via layer1 exec/eval
    (same artifact family as async leads). Keep as replay-coverage note.
    Original report: fuzz r61c.

4. **[HIGH] `raise ... from e` inside except block FAILS - cause leaks,
    new exception never raised.** Minimal: try: raise ValueError('v')
    except ValueError as e: raise RuntimeError('r') from e -> jacpython
    errors uncaught with the CAUSE'S message ('Error: v') instead of
    raising catchable RuntimeError('r'). Plain raise inside except is
    green; raise-from OUTSIDE except unknown. Same locus family as item
    73 (exception construction, ceval raise path) but distinct symptom:
    73 = repr loses args post-hoc; 77 = chained raise itself broken.
    Found fuzz r63 hand-sweep, verified by CalmKnight standalone diff.

ASYNC SURFACE VERDICT (fuzz r62a): compiled-Python path (`jac run x.py`) is
    10/10 GREEN vs CPython - asyncio.run/await-chains/gather/create_task/
    async-gen+async-for/exception-propagation/async-methods all byte-identical.
    Pre-scout leads from native-.jac probes REFUTED on production path.
    VM-REPLAY-PATH ONLY GAPS (layer1 harness, not user-facing; root causes
    identified for whoever extends replay coverage to async): (a) no
    PyObj-coroutine<->native-awaitable bridge - asyncio.run(guest_coro)
    errors 'awaitable required'; (b) CALL_INTRINSIC_1 opcode 4
    (INTRINSIC_ASYNC_GEN_WRAP) missing from ceval dispatch; (c) lossy
    to_host(coroutine)->[]. Evidence: /tmp/fuzz-r62a/diff/.

1. **[HIGH] Custom metaclass silently ignored.** class A(metaclass=Meta):
    compiles and runs, but Meta.**new**/**init** are NEVER invoked -
    type(A).**name** stays 'type', side effects lost (cls.tag assignment in
    Meta.**new** invisible). Breaks ABCMeta/Enum/ORM-class patterns
    wholesale, silently. Found fuzz r63 hand-sweep, verified by CalmKnight
    standalone diff (calls-log probe).

2. **[MED] Class keyword args not forwarded to **init_subclass**.**
    class C(Base, e='yes') with Base.**init_subclass**(cls, **kw): hook RUNS
    but kw arrives EMPTY -> cls.extra defaults instead of 'yes'. **set_name**
    IS green. Same locus family as item 38 (super().**init_subclass**
    recursion, spec-only) - one class-hook machinery fix likely covers both.
    Found fuzz r63 hand-sweep, verified by CalmKnight standalone diff.

EXCEPT-STAR RUNTIME NOTE (fuzz r58): ExceptionGroup construct/message/
    exceptions/nesting already GREEN; except* split execution ERRORED as
    expected - folds into item 47's ceval-dispatch family (CHECK_EG_MATCH
    machinery) when the VM arm lands.

LITERAL-BUG SET RETIRED (KeenFalcon 58b344f34): parser literal bugs 1-3
    (float/base-prefix/complex) were already fixed by 7c1ab5b35; bug 4
    (negative-int constant folding) fixed in compiler_emit + tokenizer with
    64 lines parity tests. All four closed.

1. **[MED] INTRINSIC_TYPEALIAS opcode undispatched in ceval** (band-11
    TypeAlias slice 0c5a15a61, byte-exact compiler side). `type X = int`
    compiles but runtime raises unsupported-opcode until VM arm lands.
    Owner: YoungHawk queue with LOAD_FROM_DICT_OR_GLOBALS + **annotate**
    descriptor work (PEP 649/695 runtime completion family).

2. **[HIGH] List/tuple repetition copies instead of aliasing.** [[0]]*3:
    rows[0] is rows[1] -> False on jacpython; CPython True (shallow repetition
    repeats references, never copies). rows[0].append(1) then shows [0] at
    rows[1]. Silently breaks matrix-init and shared-reference idioms.
    Suspect: BUILD_LIST-from-repeat path deep-copying element lists. Found in
    fuzz round 41. Ownerless; runtime lane urgent.

3. **[MED] Old-style **getitem** iteration protocol not implemented.**
    list(obj) where obj defines only **getitem** (+IndexError terminator)
    raises TypeError("'NoneType' object is not iterable") - py_iter returns
    None instead of synthesizing a sequence iterator. CPython: seq protocol
    fallback via tp_iter==NULL -> PySeqIter_New. Breaks legacy-style classes.

4. **[MED] User **len** ignored by bool().** bool(Full()) where **len**
    returns 2 gives False (default truthiness); CPython consults **len**.
    bool(Empty()) False is coincidentally right. Asymmetric with len() which
    presumably works. Family: slot synthesis at value-exit points (walker).

GIT HYGIENE RULE (formalized from tonight's incidents): silent git operations
    are the enemy. Stash cycles sweeping foreign files, checkout wiping reserved
    edits, worktree commits silently no-op'ing - same failure class. Protocol:
    after EVERY state-changing git op (commit/push/merge/checkout/worktree),
    VERIFY the ref actually moved (git log origin/..HEAD, git show --stat)
    before declaring done. Never trust the command's silence as success.

MESH-HYGIENE LESSONS (UltraMoon, tonight): (a) reservation transfers MUST
    steer all in-flight agents - del-leak agent wiped uncommitted ceval work
    via git checkout because ownership moved without notice; (b) jac check
    misses lowercase false/true literals in Jac default args - runtime-only
    NameError (bit harness line 664, fixtures: bool = false).
ITEM 0 STATUS: root cause deeper than documented - na-runtime over-retains
    below CPython refcounting on dict-subscript del / pop / popitem / del attr;
    routing-revert premise FALSE for those paths. Fix needs jac0core owner =
    user decision (host-compiler blast radius).

USER APPROVAL LOG: item 19 (native PyRange) given go-ahead; YoungHawk cleared
    to implement on ceval release. Items 28/30 assignment still open.

1. **[HIGH][FIXED 492264de5 UltraMoon] bytes richcompare** - REAL root cause:
    Py_LT..Py_GE imports missing from bytesobject.jac; the dispatch arm existed
    all along. All 10 gen-bytes pins flipped green in corpus window at
    3ebab8681 (156g/13r).
2. **[LOW][FIXED 3ebab8681 UltraMoon] slice hash** per sliceobject.c 3.12+,
    exact host-value match incl. huge-int bounds.
3. **[MED-HIGH][CLOSED a258dc7c] Native PyRange complete** - P1 gate-verified,
    P2 index/count/hash from rangeobject.c, residual huge-int hash closed via
    real lifted tuple_hash/xxHash machinery. test_range ratchet 28/0/0.

19-P2 RESIDUAL (from ratchet window @ 808647626): test_range now 26 passed /
    2 failed. Remaining: hash() on HUGE-INT ranges only -
    range(0, 2**100-1, 2) and range(2**200, 2**201-2**99, 2**100) diverge from
    oracle (guest -4721946697230212988 vs host -993334020012864492 for the
    first). Small-int hashes byte-correct. Likely bignum reduction step in the
    None-stub equivalence-class encoding. YoungHawk to close.

1. **[LOW-MED][FIXED, absorbed by band-11 walrus work] Constant-list-display
    packing.** Module-level a = [1] now emits RESUME/LOAD_SMALL_INT 1/
    BUILD_LIST 1/STORE_NAME - byte-exact vs oracle (re-probed at 34bbd0df9 by
    BrightTiger; the >=3 threshold fix in emit covered the 1-element shape).

2. **[GATE-RED, PRE-EXISTING] keywords_in_subclass across test_set/list/tuple
    - test_generators 2 errors.** Bisected by BrightTiker through tonight's
    entire window: red at db7e9edcb, d34b16c7e~1, ce4b400e0, 936df7898,
    91e4febef (pre-crash) AND 3ba4b1a1a (split commit this morning). NOT
    caused by PyRange/PyBytes/item-33 trio - UltraMoon's suspicion cleared;
    attribution now 'pre-existing user-class-subclass-instantiation family'
    confirmed by bisect. Owner: runtime lane, likely deep (class-call kwargs
    path through **init** / **new** dispatch). Blocks gate-green.

3. **[LOW-MED] Exception attribute reassignment raises AttributeError.**
    e.args = ('y',) -> AttributeError('args'); CPython allows args (and
    other BaseException attrs) reassignment. Read-only exception objects.
    Family: item 32 (**traceback** surface). Ownerless, YoungHawk candidate.

4. **[MED] super().**init_subclass**() recurses infinitely.** Class with
    **init_subclass**(cls, **kw) calling super().**init_subclass**() hits
    RecursionError - super() in that context re-binds to the defining method
    instead of object.**init_subclass**. Found via fuzz round 35
    (init-subclass-hook). Family: user-class super() dispatch.

5. **[MED][FIXED d34b16c7e BrightTiger] Iterating bytes raised TypeError
    object-is-not-iterable** - PyBytes was the only core sequence without
    tp_iter. Fixed: yields ints per CPython bytes_iterator semantics.
    Corpus unchanged at HEAD (145/24, no drift).

6. **[MED] Lone surrogates in .jac string literals crash emit** (FastYak via
    KeenFalcon). `return "\ud800";` passes jac check but jac run dies in
    jcir_gen_pass with utf-8 encode error - surrogates not allowed. Blocks
    json round-trip corpora entirely (json round-trips lone surrogates).
    Fix shape: surrogatepass handling in pyc/cache write or const-string
    encoding. Pre-existing; separate-branch material.

7. **[MED] e.**traceback** is None on caught exceptions** - see item 32
    entry above; renumbered here for owner queueing. Ownerless,
    exception-adjacent (YoungHawk candidate).

8. **[HIGH][FIXED e3eb69a80/b1fedc73b BrightTiger] except (A, B) tuple-form
    handler never matched** - exception_matches treated tuple targets as
    unmatchable (target_name stayed ""), so `except (TypeError, ValueError):`
    propagated every raise. Single-type handlers worked, masking the gap.
    Fix: recursive per-item match mirroring PyErr_GivenExceptionMatches.
    Corpus: gen-exc-003 + gen-exc-008 flipped green at HEAD.

9. **[LOW] hash(slice(...)) unsupported** (replay-widener-2, test_slice stem).
    CPython supports slice hash since 3.12. Ownerless.

ITEM 19 ADDENDUM (from replay-widener-2): test_range replay HANGS/OOMS
    (exit 124/137) - likely huge-int range pair spinning ceval. Folded into
    PyRange P1 acceptance: after native PyRange lands, test_range replay must
    COMPLETE. Item 27 evidence: bytes-vs-str richcompare also raises instead
    of NotImplemented->False - missing richcompare arm covers cross-type too.
    Harness-limit stems awaiting fixture/module-setup support: enumerate,
    hashlib, memoryview, setcomps. Known ownerless family:
    user-class-subclass-instantiation (test_set keywords_in_subclass, failed=2,
    predates today's debris).

INVARIANT (from item 26 residual, 94892ac40):

INVARIANT (from item 26 residual, 94892ac40): errors created INSIDE run_frame's
    own opcode body must route through recover_exception(co, err, offset, stack)
    before any bare return - a bare `return py_error(...)` bypasses handler
    dispatch and guest try/except cannot catch it. Errors returned from
    virtual-slot methods (slice assign/del etc.) are safe: they dispatch at the
    opcode boundary like called functions. Audited ~20 bare-return sites in
    run_frame: only BUILD_MAP was a genuine escape; the rest are defensive-
    unreachable or helper-dispatched.

Pattern note: user-class dunder support is piecemeal - consider one sweep that
routes ALL protocols through a common type-slot/dunder lookup instead of
per-protocol special cases.

1. ~~[LOW-MED] float('inf') compared with huge int raises~~ FIXED 2026-08-22 (f2b244955: exact +-inf/overflow handling on both comparison sides; 7-case matrix verified). `inf > 10 ** 400`
   errors on jacpython (likely OverflowError converting the int to float);
   CPython compares exactly and returns True - no conversion overflow allowed.

2. **~~[CODEGEN-PARITY] three byte-parity gaps~~ FIXED 2026-08-22.**
   All three landed and sentinel-flipped-to-parity in the literals differential
   suite (compiler_literals_slice.jac, 58/58):
   a. const-pool late interning: d3532d6b8
   b. constant-set frozenset lowering: a48ab5359
   c. bool-not jump folding: 46da75e83 (+ consumer wiring 903423308)

3. **[MED] List slice ASSIGNMENT broken both paths.** `xs[::2] = [7, 8]`
    raises TypeError("list indices must be integers") - STORE_SUBSCRIPT does
    not accept PySlice. Direct xs.**setitem**(slice(0,4,2), [7,8]) returns
    None but silently does NOT mutate (mp_ass_subscript slice branch missing/
    no-op). Asymmetric: slice READ (xs[::2]) and slice DELETE (del xs[1:3])
    both work. Same silent-noop family as the old unbound-method bug.
    Repro: xs=[0,0,0,0]; xs[::2]=[7,8] -> expect [7,0,8,0].

4. **~~[HARNESS] `_l1_flatten_seq` corrupts setup containing try/except~~ FIXED 2026-08-22 (85a1e4f98).**
    Try stays intact in setup source; nested checks harvested for post-hoc eval
    (never from handler bodies). Verified with 5-case unit battery.
    NOTE: layer0_replay_p3_gate has a PRE-EXISTING failure unrelated to the fix:
    test_set/test_keywords_in_subclass fails at every commit back through at least
    00c9ead4e - user-class subclass(set) instantiation family (cf. items 4/12/13).
    Needs an owner.

5. ~~[MED] `instance.__class__` AttributeError on user instances~~ FIXED 2026-08-22 (11fa28f58: PyUserObj + PyException + PyExceptionType surfaces; caught-handler idiom verified).

    a.**class** -> AttributeError("**class**") for any user-class instance;
    works for natives ([].**class** == list). dir(a) lists **class**, so the
    surface claims it but getattr misses it. Breaks common idiom
    e.**class**.**name** on caught exceptions too. Retroactively explains the
    round-8 call-bisect failure attributed to **call**. Fix: PyUserObj getattr
    resolves **class** to its class object (and audit sibling identity dunders:
    **dict**, **module** on instances).

6. ~~[LOW] callable() says False for user classes~~ FIXED 2026-08-22 (ecaa2132e: native callable() over tp_call slots). callable(C) where C is
    a plain user class returns False (CPython: True - classes instantiate).
    callable(fn) works. Part of the type-slot family: tp_call presence isn't
    consulted for user types.

7. ~~[LOW-MED] Generator return value lost on manual next() exhaustion~~ FIXED 2026-08-22 (7325306ec: next() forwards PyGenStop payload; also fixed latent ann_collect_stmts None-block crash).
    def g(): yield 1; return 99 - after consuming via next(), the terminal
    StopIteration has .value == None instead of 99. Asymmetric: yield from
    DOES forward the inner gen's return correctly (yieldfrom-return-value
    green), so the internal path carries it but the caller-facing
    StopIteration doesn't attach .value. Only affects explicit-iteration
    consumers (for loops ignore .value).

### Widened-differential findings (QuickBear, 2026-08-22 afternoon)

0b. **\[COMPILER\]\[HIGH\] f-strings do not interpolate at all.**
    `f'{a}+{b}'` compiles to a single LOAD_CONST of the literal text
    "{a}+{b}" -- runtime produces that literal instead of "1+2". Root cause:
    parser actions pa_joined_str / pa_formatted_value / pa_interpolation /
    pa_template_str (parser_actions.jac ~1717+) are stubs returning None, so
    JoinedStr never reaches codegen. Fix needs both sides: parse actions
    building JoinedStr/FormattedValue AST, plus emit lowering
    (FORMAT_SIMPLE=12 / BUILD_STRING=50 opcodes already exist with ceval
    support). Every f-string in every program is silently wrong until fixed.

0c. **\[CODEGEN\]\[HIGH\] for/else with break/continue miscompiles control flow.**
    Byte diff shows duplicated epilogues mid-stream and a JUMP_FORWARD 245
    past program end; runtime: `done=0; for...break; else: done=99; r=done`
    yields None instead of 0. while/else is byte-exact, so this is specific
    to FOR + break/continue + else interaction. Semantic correctness bug,
    not just parity.

3b. **\[CODEGEN-PARITY\]\[MED\] def with *args/**kw defaults: function-attribute
    operand ordering differs from host.** Function BODY bytes match; module
    frame emits defaults/kwdefaults consts in different intern order
    (ours LOAD_CONST 1,2 vs host 4,1). Same family as fixed item 9A but for
    MAKE_FUNCTION attribute wiring. Semantics-neutral.

3c. **\[CODEGEN-PARITY\]\[MED\] listcomp with if-filter byte-parity gap.**
    Compiles, runs, but bytes differ from host oracle. Needs isolation
    (comprehension inlining vs CPython's implicit function form).

## Runtime fix lane - HANDOFF BRIEF (for new worker agent)

You own VM RUNTIME fixes in jac-py/jacpython (ceval.jac/objects.jac family).
BrightTiger is reviewer/fuzzer - do NOT edit their files (_fuzz_smoke.jac,
_fuzz_introspect.jac, TODO.md live-log section); they verify your landings
against jac-py/tools/fuzz_corpus_pinned.json (26 pins) after each landing.
QuickBear owns compiler_codegen/compiler_emit/compiler_annotations - don't touch.

FIX ORDER (cheapest-green-first, per GoldLion review):

1. Item 4: add PyUserObj.tp_call override (ceval.jac ~1235 block) mirroring
   tp_iter EXACTLY: user_has_dunder(self,"**call**") -> bind_attribute to
   instance -> invoke; propagate dunder exceptions same path; no result check.
2. Item 5: rewire list() ctor to py_iter(arg)-first with host_iter fallback
   ONLY on error (copy members_of()'s pattern, ceval.jac ~4705). Audit every
   consumer in pin-item5-consumers-matrix: sorted/tuple/dict.fromkeys/sum/
   any/all/max/min/enumerate/zip + UNPACK/CALL_FUNCTION_EX (already green).
3. Item 19 (design first): range degrades to list across bridge (from_host has
   no range branch). Either native PyRange or preserve host range object.
   Discuss design with BrightTiger/GoldLion before landing.
4. Branch-closing sweep AFTER the above: **class**/**dict**/**module**
   synthesis (item 12), **getattr** tail hook (15), generic descriptors (1).
   GoldLion's two-flavor walker review governs this phase - send them the
   walker diff BEFORE merging anything.

DISCIPLINE:

- Shared tree: 2+ agents active. Stage surgically (git add <your paths only>);
  commit within minutes of verifying; NEVER git stash here.
- Re-grep dispatch lines on FRESH HEAD immediately before editing (file shifts
  under concurrent commits).
- Local gate: .venv/bin/jac check <file> (~5s). Never run long jac test suites.
- After each landing: report HEAD sha to BrightTiger for pin re-run.

### Root-cause synthesis (all findings collapse into 4 families)

**A. Incomplete dunder dispatch wiring** (items 1/4/5/12/13/15/17, +2 adjacent).
REVISED after code reading (was overstated as "no unified lookup"): the
machinery EXISTS - PyUserObj.tp_getattro walks the class MRO via
class_lookup_attr/descriptor_get/bind_attribute (ceval.jac ~1395);
user_has_dunder/call_user_dunder helpers exist (~2632); iter(g) correctly
consults tp_iter. Actual gaps are TWO kinds:
  (i) missing branches: no **getattr** tail hook after MRO miss; no **class**
      synthesis; descriptor_get handles PyProperty but not generic **get**;
  (ii) BRIDGE-FIRST CALL SITES: builtins push args across to_host BEFORE
      consulting local slots - list(g) does to_host(g)->None then "NoneType
      not iterable" while iter(g) works (same object, verified same session).
Fix = close branch gaps + make builtin call sites consult tp_* before
bridging. Consistent with GoldLion's walker-core review.

**B. Asymmetric slot coverage / half-wired features** (items 8/10/14/18).
Each feature implemented against whichever test exposed one half first:
sort has key= but sorted/max/min don't; slice read+del work but assign
doesn't; gen return carried internally but StopIteration.value empty;
property getter/setter without deleter. Fix = spec-driven completeness pass
over builtin signatures and slot triples (get/set/del), not item patches.

**C. Guest-host bridge marshaling ad hoc** (item 16, item 7, to_host ledger).
Unknown shapes fall back to WRONG defaults (coro -> list) or raise where
CPython compares exactly (inf vs bigint). Fix = typed conversion table at the
boundary with explicit unknown-type policy.

**D. Harness blind spots** (item 11 + coverage-map mis-claim lesson).
Differential testing cannot see identical-wrong-on-both-sides; harness rewrites
control flow. Mitigation already in place: pin corpus + sentinel pre-runs.

Meta-root-cause: bottom-up conformance (make each observed test pass) instead
of top-down architecture (slot table + single lookup). Explains why ~60 green
domains coexist with these gaps: lifted-from-bytecode areas are solid,
hand-dispatched areas hole exactly where no test looked. STRATEGY: unify,
don't patch - individual fixes leave holes reopening under future features.

**PIN STATUS @ HEAD post-item8-merge (199be79f3 + GoldLion pins)**: corpus 37.
Item-8 family fully green incl. default=-on-empty-only, multi-positional+key,
key-stability, key-raise-propagation (4 new GoldLion pins, all green first run).
Remaining reds: walker items (1 x3, 2, 15 x2), #21 chaining, consumer-matrix
(in flight), item19 (unowned). Earlier statuses below.

**PIN STATUS @ HEAD 276b1af4e** (WildRaven nit batch + list-subclass drain gap): 22 GREEN /
11 RED. New pin-slice-subclass-generator-assign GREEN on first run (gap fix works). All other reds unchanged/owned.
ATTRIBUTION NOTE: 276b1af4e carries WildRaven's code (objects.jac nits/E1053 + ceval PyUserObj forward reroute) under a docs-labeled message - concurrent committer absorbed staged edits mid-cycle (shared-tree hazard). Code authorship: WildRaven, slice lane. Content verified complete via git show; not rewriting shared history.
Harness note: WildRaven reported layer1 try/except replay mis-replaying zero-arg native-callable messages; NOT reproducible at this HEAD (probe returns byte-exact CPython message) - likely shadowed by their own indices() message fix; no action.

**PIN STATUS @ HEAD e1c668204** (post slice-family landing): 21 GREEN /
11 RED. Newly flipped: item10-slice-assign + item20-dynamic-slice-read-del
(WildRaven). Remaining reds all owned: item1 x3 + item2 + item15 x2 (walker),
item8 x2 (subagent), consumers-matrix (worker), item19 (unowned), chaining-
nesteddef (blocked on item21). Earlier status below.

**PIN STATUS @ HEAD 0694fda4d** (full 30-pin run post item-4 fix + 9A):
11 GREEN (item4 family x5, inverse sentinels x3, iter-half,
property-precedence, unpack-star) / 19 RED - every red maps to an open item,
zero unexplained drift (9A const-pool landing caused none, as predicted for
parity-only work). NOTE: pin-ok-exc-chaining-nesteddef is RED because its
asserts resolve r2.**cause**.**class**.**name** - blocked on item 12, not a
chaining regression; mislabeled 'ok-' at creation, will flip with item 12.

**PIN CORPUS FROZEN**: jac-py/tools/fuzz_corpus_pinned.json - 16 cases:
minimal repros for items 1/2/4/5/7/8/10/12/13/14 (red until fixed), descriptor
precedence + instance-dict-inverse sentinels (guard the sweep), and
healthy-behavior pins (exception chaining via nested-def) that must stay green.
Not wired into CI; run manually via _fuzz_smoke.jac. Delete _fuzz_smoke.jac +
_fuzz_introspect.jac before any upstream PR; the pin file itself should land.

1. **[MED] `__getattr__` fallback never implemented.** Proxy().zzz raises
    bare AttributeError('zzz') - type.**getattr** is never consulted on lookup
    failure. objects.jac has ZERO **getattr** references (grep-verified).
    Breaks lazy proxies/delegation idioms wholesale.
    CORRECTION: early coverage-map entry listed **getattr** green - that was
    WRONG (mis-attributed from an unharvested case). Coverage map corrected.

2. **[HIGH if async in scope] Coroutine/bridge integration broken.**
    (a) asyncio.run(vm_coro()) -> "An asyncio.Future, a coroutine or an
    awaitable is required": host event loop cannot recognize guest coroutines
    across the bridge. (b) type(coro_obj) returns PyHostProxy(val=list) -
    type() misreports coroutine objects as list (to_host wrapper gap family,
    cf. carried ledger item). hasattr(c,'send') True, so the object exists;
    identification/bridging is what fails.

3. **[MED] Exception class passed to **exit** lacks **name**.**
    with-protocol suppression itself works (return True suppresses, exit args
    flow), but reading et.**name** inside **exit** raises bare AttributeError
    ("**name**"). The raised-exception CLASS object crossing into user code is
    missing identity attrs - same family as item 12 (**class** synthesis).
    Repro: log.append(et.**name** if et else None) inside **exit**.

4. **[LOW-MED] property .deleter ignored.** del o.x on a property with
    @x.deleter raises AttributeError('x'); getter/setter both work (verified
    green separately). mp_del_subscript/del-attr path doesn't consult
    property fdel. Same asymmetry shape as slice-assign (item 10).

Note: module-level @class-decorators are UNTESTABLE by the layer1 harness
(module top-level code isn't replayed); function decorators in-method are
green. Class-decorator support needs pinning elsewhere.

1. **[MED-HIGH] range() degrades to a list across the bridge. UNOWNED -
   needs design-first owner: grep confirms NO native PyRange obj exists in the
   tree (the done-list "PyRange deepen" refers to host-adjacent helpers, not a
   native type), so this is new-type work, not a bridge arm. WildRaven declined
   folding it into the slice landing; correctly per handoff brief.**
    type(range(3)) -> 'list'; repr -> '[0, 1, 2]'. Consequences: no
    .start/.stop/.step; range slicing fails; isinstance/type checks wrong;
    and LAZINESS IS LOST - range(10**9) presumably materializes 1e9 elements
    (memory/time bomb). All my earlier range greens (len/in/iteration) passed
    coincidentally through list semantics. Root cause family C: from_host has
    no range branch so host range lands as PyHostProxy/list. Fix: native
    PyRange with start/stop/step + O(1) len/contains/index/slice arithmetic,
    or at minimum preserve the host range object through the bridge.

2. **[LOW-MED] Subscripting with a slice OBJECT raises; inline syntax works.**
    xs[s] where s = slice(1,7,2) -> TypeError "list indices must be integers";
    identical inline xs[1:7:2] is GREEN. The compiler lowers literal slice
    syntax directly to (start,stop,step) args, but a dynamic PySlice value as
    subscript index never reaches the slice path in mp_subscript. Same family
    as item 10 (slice assignment): one shared fix, mp_subscript/ass/del all
    accepting PySlice. Standalone slice() objects are fine (type/attrs/
    .indices() green).

3. **[LOW-MED] Exception attribute VALUES lack **class** synthesis.**
    Caught exception e: e.**class**.**name** GREEN (item 12 fix covers the
    instance). But r2.**cause**.**class**.**name** / **context** equivalents
    raise AttributeError("**class**"): whatever py_getattr returns for
    exception attributes skips the PyExceptionType synthesis path. Blocks
    chaining introspection idioms; keeps pin-ok-exc-chaining-nesteddef red.
    Fix: route **cause**/**context** (audit all exception attrs) through the
    same type-synthesis as the instance itself.

4. **[LOW] Native method-descriptor TypeErrors lack qualname prefix.**
    slice(1,2).indices() zero-arg: jacpython says "indices() takes exactly one
    argument (0 given)"; CPython says "slice.indices() takes ...". Method-
    descriptor error formatting uses **name** where CPython uses the qualname
    (owner-prefixed) form. RESOLVES the suspected harness bug: layer1 harvest/
    replay is EXONERATED - a side-by-side namespace diff showed both sides
    faithfully report their own messages; the divergence is real VM behavior.
    WildRaven's earlier 'direct drive byte-exact' check compared against a
    mis-transcribed host string (prefix dropped). Fix lives in whichever slot
    raises (PySliceIndices.indices first; audit sibling method descriptors).
    Guard: pin-item22-methoddesc-qualname-msg.

5. **[LOW] Builtin arg-check messages: missing count suffix + got-N.**
    WildRaven sibling audit (item 22 follow-through). In ceval.jac native-
    builtin block (~4600s): len()/hash()/repr() say "takes exactly one
    argument" without CPython's "(N given)" suffix; isinstance/issubclass/
    getattr family lacks ", got N". Bare-name style (no prefix) is CORRECT for
    builtin functions - only suffixes missing. classmethod/staticmethod text
    needs host-oracle check. Owner: WildRaven, in flight.
    **FIXED by WildRaven**: count suffixes + got-N landed; oracle texts:
    len/hash/repr "takes exactly one argument (N given)", callable() same,
    id() takes exactly one argument (0 given), isinstance/issubclass/hasattr
    "expected 2 arguments, got N", getattr "expected at least 2 arguments,
    got N", classmethod/staticmethod "expected 1 argument, got N".

6. **[LOW] Tail-position if/try/with as non-final statement crashes codegen
    ("object of type 'int' has no len()").** Found by split-codegen subagent,
    reproduced identically on pre-split base commit: exec_tail_emits_code
    (codegen_util.jac:926) receives an int instead of the stmt list when an
    if/try/with sits in tail position after a return inside a function.
    Compiler lane (QuickBear or successor). Needs confirming probe with valid
    jac test-case syntax before fix.

7. **[MED][FIXED 1979d1d08, WildRaven] int/float EQUALITY exactness restored.** Shared
    _cmp_int_vs_float in objects.jac used by BOTH polarities; truncation +
    fractional tie-break is exact host arithmetic; NaN/inf rules both ways.
    Pin pin-item25-float-int-eq-boundary GREEN (verified at origin HEAD).

8. **[LOW-MED][FIXED 1979d1d08, WildRaven]** BUILD_MAP raises CPython-exact
    TypeError("unhashable type: '<t>'") for list/dict/set keys, left-to-right;
    raw-host-exception escape gone. Design note: not-yet-natively-hashed but
    host-hashable types (slice) keep opaque-host-map fallback - full strictness
    deferred to native-hashkey coverage. Pin pin-item22b-unhashable-display-
    typerror GREEN after 94892ac40 (BrightTiger residual fix: BUILD_MAP raise
    now routes through recover_exception frame unwinding - bare `return
    py_error` bypassed handler dispatch so guest try/except couldn't catch it;
    mirrors UNPACK_EX pattern).

9. **[MED] int/float EQUALITY loses exactness at 2^53 boundary.**
    (2**53 + 1) == float(2**53 + 1) -> True on jacpython; CPython says False
    (exact comparison: 2**53+1 > 9007199254740992.0). Equality path converts
    int->float before comparing; f2b244955 fixed ordered compares/inf paths
    but not ==/!=. Fix: route float/int eq through the same exact machinery.
    Guard: pin-item25-float-int-eq-boundary.

10. **[LOW-MED] Dict-display literal with unhashable key escapes the error
    channel.** {[]: 'nope'} raises in a way that propagates OUT of exec_code
    (kills the caller) instead of returning PyError - while d[[]] = v (setitem
    form) correctly yields TypeError. Something in the BUILD_MAP/display path
    (native leaf?) raises raw without conversion. Breaks harness errored-vs-
    failed classification and any guest try/except around display literals.
    Repro: _l1_jac_raise_name(ns, "d = {[]: 'nope'}") blows up top-level.

11. **[HIGH] bytes richcompare broken (fuzz-widener-2 F1).** b'a' == b'a'
    raises NameError: name 'Py_EQ' is not defined - an internal symbol leaking
    as a guest NameError from the bytes comparison path. bytearray == also
    returns wrong values. All 10 gen-bytes cases red. Owner: runtime lane.

12. **[MED] return value lost after catching user-defined exception subclass
    (F2, gen-closure cases).** Function raises SubCls, caller catches it,
    subsequent return value vanishes. Owner: runtime/exception lane.

13. **[MED] implicit **context** chain broken (F3, gen-exc cases).**
    raise-inside-except leaves e.**context** = None; CPython chains
    ValueError('inner') onto TypeError('outer'). Verified by BrightTiger at
    HEAD f2848d5d6. Relevant to YoungHawk's exception work; interacts with
    pin-ok-exc-chaining-nesteddef (already red).

14. **[MED] two lambda-returning comprehensions in one scope corrupt first
    closure cells (F4, gen-closure-002/005/008).** Second comprehension's
    cell writes clobber the first's. Compiler-lane suspect (cellvar/closure
    emission). Owner: KeenFalcon or compiler lane.

Full detail + repros: jac-py/tools/fuzz_findings_20260822.md (fuzz-widener-2).

1. **[MED] e.**traceback** is None on caught exceptions.** except-block attr
    read returns None; CPython guarantees a traceback object there (used by
    logging/trio-style re-raise helpers). Value-mismatch class, not raise.
    Ownerless; exception-adjacent so YoungHawk candidate.

2. **[HIGH][FIXED 492264de5 UltraMoon] bytes richcompare** - REAL root cause:
    Py_LT..Py_GE imports missing from bytesobject.jac; the dispatch arm existed
    all along. All 10 gen-bytes pins flipped green in corpus window at
    3ebab8681 (156g/13r).
3. **[LOW][FIXED 3ebab8681 UltraMoon] slice hash** per sliceobject.c 3.12+,
    exact host-value match incl. huge-int bounds.
4. **[MED-HIGH][CLOSED a258dc7c] Native PyRange complete** - P1 gate-verified,
    P2 index/count/hash from rangeobject.c, residual huge-int hash closed via
    real lifted tuple_hash/xxHash machinery. test_range ratchet 28/0/0.

19-P2 RESIDUAL (from ratchet window @ 808647626): test_range now 26 passed /
    2 failed. Remaining: hash() on HUGE-INT ranges only -
    range(0, 2**100-1, 2) and range(2**200, 2**201-2**99, 2**100) diverge from
    oracle (guest -4721946697230212988 vs host -993334020012864492 for the
    first). Small-int hashes byte-correct. Likely bignum reduction step in the
    None-stub equivalence-class encoding. YoungHawk to close.

1. **[LOW-MED][FIXED, absorbed by band-11 walrus work] Constant-list-display
    packing.** Module-level a = [1] now emits RESUME/LOAD_SMALL_INT 1/
    BUILD_LIST 1/STORE_NAME - byte-exact vs oracle (re-probed at 34bbd0df9 by
    BrightTiger; the >=3 threshold fix in emit covered the 1-element shape).

2. **[GATE-RED, PRE-EXISTING] keywords_in_subclass across test_set/list/tuple
    - test_generators 2 errors.** Bisected by BrightTiker through tonight's
    entire window: red at db7e9edcb, d34b16c7e~1, ce4b400e0, 936df7898,
    91e4febef (pre-crash) AND 3ba4b1a1a (split commit this morning). NOT
    caused by PyRange/PyBytes/item-33 trio - UltraMoon's suspicion cleared;
    attribution now 'pre-existing user-class-subclass-instantiation family'
    confirmed by bisect. Owner: runtime lane, likely deep (class-call kwargs
    path through **init** / **new** dispatch). Blocks gate-green.

3. **[LOW-MED] Exception attribute reassignment raises AttributeError.**
    e.args = ('y',) -> AttributeError('args'); CPython allows args (and
    other BaseException attrs) reassignment. Read-only exception objects.
    Family: item 32 (**traceback** surface). Ownerless, YoungHawk candidate.

4. **[MED] super().**init_subclass**() recurses infinitely.** Class with
    **init_subclass**(cls, **kw) calling super().**init_subclass**() hits
    RecursionError - super() in that context re-binds to the defining method
    instead of object.**init_subclass**. Found via fuzz round 35
    (init-subclass-hook). Family: user-class super() dispatch.

5. **[MED][FIXED d34b16c7e BrightTiger] Iterating bytes raised TypeError
    object-is-not-iterable** - PyBytes was the only core sequence without
    tp_iter. Fixed: yields ints per CPython bytes_iterator semantics.
    Corpus unchanged at HEAD (145/24, no drift).

6. **[MED] Lone surrogates in .jac string literals crash emit** (FastYak via
    KeenFalcon). `return "\ud800";` passes jac check but jac run dies in
    jcir_gen_pass with utf-8 encode error - surrogates not allowed. Blocks
    json round-trip corpora entirely (json round-trips lone surrogates).
    Fix shape: surrogatepass handling in pyc/cache write or const-string
    encoding. Pre-existing; separate-branch material.

7. **[MED] e.**traceback** is None on caught exceptions** - see item 32
    entry above; renumbered here for owner queueing. Ownerless,
    exception-adjacent (YoungHawk candidate).

8. **[HIGH][FIXED e3eb69a80/b1fedc73b BrightTiger] except (A, B) tuple-form
    handler never matched** - exception_matches treated tuple targets as
    unmatchable (target_name stayed ""), so `except (TypeError, ValueError):`
    propagated every raise. Single-type handlers worked, masking the gap.
    Fix: recursive per-item match mirroring PyErr_GivenExceptionMatches.
    Corpus: gen-exc-003 + gen-exc-008 flipped green at HEAD.

9. **[LOW] hash(slice(...)) unsupported** (replay-widener-2, test_slice stem).
    CPython supports slice hash since 3.12. Ownerless.

ITEM 19 ADDENDUM (from replay-widener-2): test_range replay HANGS/OOMS
    (exit 124/137) - likely huge-int range pair spinning ceval. Folded into
    PyRange P1 acceptance: after native PyRange lands, test_range replay must
    COMPLETE. Item 27 evidence: bytes-vs-str richcompare also raises instead
    of NotImplemented->False - missing richcompare arm covers cross-type too.
    Harness-limit stems awaiting fixture/module-setup support: enumerate,
    hashlib, memoryview, setcomps. Known ownerless family:
    user-class-subclass-instantiation (test_set keywords_in_subclass, failed=2,
    predates today's debris).

INVARIANT (from item 26 residual, 94892ac40):

INVARIANT (from item 26 residual, 94892ac40): errors created INSIDE run_frame's
    own opcode body must route through recover_exception(co, err, offset, stack)
    before any bare return - a bare `return py_error(...)` bypasses handler
    dispatch and guest try/except cannot catch it. Errors returned from
    virtual-slot methods (slice assign/del etc.) are safe: they dispatch at the
    opcode boundary like called functions. Audited ~20 bare-return sites in
    run_frame: only BUILD_MAP was a genuine escape; the rest are defensive-
    unreachable or helper-dispatched.

Pattern note: user-class dunder support is piecemeal - consider one sweep that
routes ALL protocols through a common type-slot/dunder lookup instead of
per-protocol special cases.

1. **[MED] sorted()/max()/min() silently ignore key=.** sorted(['bbb','a','cc'],
   key=len) -> ['a','bbb','cc'] (lexicographic, key dropped); max(same, key=len)
   -> 'cc' (should be 'bbb'). Silent wrong answers, same severity family as the
   unbound-method silent no-op. Note list.sort(key=) DOES work (ae82851a0), so
   the decorate-sort-undecorate logic exists but isn't wired into these builtins.
   Fix: forward key=/reverse= from sorted/max/min to the same machinery; also
   audit any other builtin accepting key= (filter/map fine, but check
   itertools-style helpers if lifted).

### Fixed & verified

- [a13ba6a06] repr() drained native iterators → py_repr '<iterator object>' pre-to_host;
  verified repr observational (next(it) after repr yields 1). Also py_type_of host-type
  names for native wrappers (type(len) == 'builtin_function_or_method'); capsule
  abs() workaround removed; HARNESS A strict setup errors count ERRORED.
- [a13ba6a06] HARNESS C residual: _dedent_segment strips exactly base_col per
  continuation line; try/except/else setups replay green end-to-end (exc-else verified).
- [d5235d1d7] unbound builtin-method silent no-op - list.append/dict.get route to
  native wrappers; PyIter.tp_iter + to_host drain for host consumers.
- `list.sort()` missing entirely (silent no-op via host-copy mutation) - ae82851a0;
  my 99-case stateful corpus went 77/99 → 99/99 post-fix; stability-under-key verified.

- `list.sort()` missing entirely (silent no-op via host-copy mutation) - ae82851a0;
  my 99-case stateful corpus went 77/99 → 99/99 post-fix; stability-under-key verified.
- Undefined name raised AttributeError("module 'builtins' has no attribute") instead
  of NameError - ae82851a0, verified via assertRaises(NameError).
- Generator re-entrancy unguarded (would recurse run_frame on live frame) - 62e7018d1;
  bypass sweep confirmed all resume/throw paths funnel through guarded entries.
- HARNESS: 25/107 real probe methods never replayed - all "skips" were indentation-
  corruption artifacts from get_source_segment + single global dedent - 1d823f5d6;
  independently re-verified 107/107 passed / 0 skipped across all 44 stems.
- PyHostProxy eq/hash inconsistency - 1d823f5d6 option-2 implementation reviewed;
  identity fast-path + host-eq defer + error propagation all correct.

### Fuzz coverage map (all differential vs CPython, green)

richcompare chains/reflected priority · dict key collapse/order · bigint hash parity ·
floor/mod signs · gen yield/close/throw/yield-from/StopIteration→RuntimeError/reentrancy ·
exception hierarchy/tuple-match/nested-finally/return-in-finally/reraise/NameError ·
comprehension scoping (no-leak)/dict/set-comp/genexpr · f-strings/%-format/format() ·
with enter/exit/suppression · operator overloads (**add**/**radd**/**eq**/**hash**/
**len**/**bool**/**repr** fallback) · slice semantics · str methods ·
loop for/while-else + break · set algebra (- ^ <= <) · dict setdefault/update(kw) ·
bytes slice/concat/int-list · any/all over generators · enumerate/zip ·
closures + nonlocal counters · *args/**kwargs/keyword-only/default-eval-once ·
star-unpacking (a,*b, c) · dict views as sets · unbound builtin dispatch ·
chained comparisons · subscript augmented assignment · pow-mod/negative bitops/
~ · round/abs bigint · true-div semantics · nan equality · int() bases/whitespace ·
exception type fidelity (IndexError/KeyError/AttributeError) · math module attrs ·
unicode escapes/ord/chr · container repr nesting · ternary/boolop short-circuit ·
utf-8/ascii/latin-1 codecs · dict get/pop defaults/fromkeys · map/filter(None) ·
zip-shortest · list count/index/remove · chained/multi-target assignment ·
tuple swap + immutable augassign · global stmt · complex numbers (real/imag/
abs/conjugate/pow) · numeric-tower eq/hash/set-dedup · generator send/close/
throw/yield-from nesting · self-referential containers · format_map ·
nested/dict/set comprehensions · divmod negatives + banker's rounding ·
int.to_bytes/from_bytes · str.maketrans/translate/expandtabs/ljust/rjust ·
sum(start) incl. list concat · bool-as-int indexing · bytes.maketrans+delete.

Known harness limits when writing new probes: asserts must be direct statements of a
`test_*` method (no nesting inside try/with); avoid literal `self` tokens outside the
assert calls; assert args must be interpreter-independent or folded intra-expression;
host-baked literal expected values are stronger than self-comparisons.
HARNESS GOTCHA (r60c): a case whose body fails to parse/indent prints `ok ... passed: 0`

- ALWAYS check passed > 0, absence of FUZZFAIL proves nothing. Setup exceptions surface
only as `errors: ['test_case']` with no message; capture stderr via a standalone probe.
Also: driver hardcodes /tmp/fuzz_cases.json - concurrent agents must sed a unique path.
HARNESS SOUNDNESS (r61b): (1) L1 harvester STRIPS decorator lines on defs inside test
bodies -> @-on-def cases run UNDECORATED = vacuous greens; use standalone-diff instead.
(2) Hand-built layer1_run_setup probes WRAP functions in PyObj - binding semantics differ
from real execution; produced 3 false 'finds' (instance-attr fn binding, partial collision
TypeErrors, lru_cache method) all disproven by `python3 x.py` vs `jac run x.py` diff.
STANDALONE .py DIFFERENTIAL IS THE GOLD STANDARD. (3) Cross-leg identity asserts
(assertEqual(p.func, p)) can never match across interpreters - design around.

Infra: `/tmp/gen_fuzz.py`, `/tmp/gen_fuzz2.py` (corpus generators),
`jac-py/jacpython/_fuzz_smoke.jac` (driver, reads /tmp/fuzz_cases.json),
`jac-py/jacpython/_fuzz_introspect.jac` (direct namespace inspection).
Run: `JACPYTHON_CPYTHON=python3 .venv/bin/jac run jac-py/jacpython/_fuzz_smoke.jac`
(both .jac files are temp - delete before any upstream PR).
