# JacPython roadmap (TODO)

Two independent tracks:

- **Native compiler bands** (Bands 3–9): see `PROGRESS.md`.
- **c2jac module porting** (`jac-py/PLAN.md` §7): P1 → P2 → P3 → full tree below.

---

## 1. P1 — c2jac proving loop (~1–2 focused weeks) — **COMPLETE**

Prove `c2jac → differential oracle → Tier-B burndown` on real CPython module excerpts,
not toy fixtures alone.

**Exit criteria** (`jac-py/PLAN.md` §7): rotatingtree staged; 5–6 module corpus with
Tier-B density below 15%; loop is CI-gated.

**Slices landed** (committed through `988e0b6b5`):

- [x] **1a** — Stage `rotatingtree` under `jac-py/Modules/`; module oracle
- [x] **1b** — P1 corpus harness (`lift_p1_corpus.py`, manifest, baseline ratchet)
- [x] **1c** — `NULL` → Jac `None` idiom (`cast_load_pass`)
- [x] **1d** — `REFCOUNT_ELIDE` + `ERR_RETURN` idioms
- [x] **1e** — PyObj typing, fn-ptr callbacks, include-path stubs (`Python.h`)
- [x] **1f** — Five-module corpus checked in (`_lifted/p1_corpus_slice1b/*.jac`);
  CI: `test_p1_corpus_gate.py`, `test_p1_corpus_density.jac`, rotatingtree oracle

**Metrics:** P1 baseline `tier_b_total = 4` (~0.77% density on six files).

---

## 2. P2 — proving wave: leaf modules (~1–2 months?) — **wave 1 COMPLETE**; **waves 2–3 landed locally**

Port ~10 self-contained `Modules/*.c` leaf extracts; gate each with differential oracles
and partial Lib/test; stand up T8 AI cleanup MVP.

**Wave 1 exit criteria met** (committed):

- [x] **10 staged modules** — `jac-py/Modules/` (P1 six + P2 four: `getplatform`,
  `getcompiler`, `getcopyright`, `pyfpe`)
- [x] **Differential oracles** — 11 tests in `test_p2_module_oracles.jac` +
  `test_rotatingtree_oracle.jac`
- [x] **P2 corpus lift + ratchet** — baseline `tier_b_total = 0` on wave 1 lifted tree
- [x] **Dual-pipeline policy**, T6 conformance skeleton, partial Lib/test, T8 MVP, CI wiring

**Wave 2 landed locally** (Aug 20 2026):

- [x] **4 staged modules** — `_stat`, `_opcode`, `math_gcd`, `pystrnicmp` under `jac-py/Modules/`
- [x] **Corpus + lift** — `p2_corpus_wave2/`, `lift_p2_corpus_wave2.py`, `_lifted/p2_corpus_wave2/`
- [x] **Oracles** — 6 differential tests in `test_p2_wave2_module_oracles.jac`
- [x] **Gates** — staged sync, density ratchet, `p2_conformance_wave2_gate.py`, CI steps
- [x] **Hand-staged** — `_stat` (octal literal W4210), `_opcode` (designated init W4209)
- [x] **Tier-B baseline** — `tier_b_total = 0` (~0% density on lifted tree after burn-down)

**Wave 3 landed locally** (Aug 20 2026):

- [x] **4 staged modules** — `math_count_bits`, `math_lcm_long`, `strhex_byte`, `pyctype_digit` under `jac-py/Modules/`
- [x] **Corpus + lift** — `p2_corpus_wave3/`, `lift_p2_corpus_wave3.py`, `_lifted/p2_corpus_wave3/`
- [x] **Oracles** — 4 differential tests in `test_p2_wave3_module_oracles.jac`
- [x] **Gates** — staged sync, density ratchet, `p2_conformance_wave3_gate.py`, CI steps
- [x] **All lift-staged** — three modules match fresh lift; `strhex_byte` **hand** (W4201 string-table); `tier_b_total = 0` after burn-down

**Known gaps / next within P2:**

- [x] **Tier-B burn-down (wave 2)** — 15 sites on fresh lift (`_stat` 8, `_opcode` 4, `pystrnicmp` 3); hand sync + T8 W4201 rules; baseline `tier_b_total = 0`
- [x] **Tier-B burn-down (wave 3)** — 4 sites on fresh lift (`strhex_byte` W4201 string-table); hand sync; baseline `tier_b_total = 0`
- [x] **Libtest on JacPython** — `layer_p2_libtest.jac` runs embedded snippets via ceval + shim modules (`platform` backed by staged `getplatform`); wired in `libtest_runner.jac` / conformance manifest (`jacpython_results`)
- [x] **Wave 4 modules** — `pystricmp`, `pyctype_space`, `pyctype_alpha`, `math_factorial_small` under `jac-py/Modules/`; corpus in `p2_corpus_wave4/`; oracles + CI gates

---

## 3. P3 — object core (~many months) — **spike DONE; c2jac port NOT started**

Hand-written §5 skeleton + bootstrap bridge are live in `jac-py/jacpython/objects.jac`
(na-clean leaf, T7) and `pyc_first.jac` (marshal + ceval + host fallbacks). Layer-0
replay is green on the core corpus (`test_int`/`test_bool`/`test_str`/`test_dict`/
`test_list`/`test_tuple`). The ~170k LOC `Objects/` + `Python/` core is **not** being
machine-ported yet — c2jac drafts still need clinic2jac, idiom pack, and conformance
burndown per file.

Spec: `jac-py/PLAN.md` §5 (re-hosting rules), §7 P3; gate harness:
`jac-py/tests/test_p3_object_core_gate.jac` + `jac-py/tools/p3_object_core/manifest.json`
(Layer-0 corpus replay ratchet lands in P3.1a — `layer0_replay.jac` + CI wiring).

**P3 exit (unchanged from PLAN):** differential conformance on
`test_int`/`test_dict`/`test_list`/`test_str`(subset)/`test_tuple`/`test_set` via the
Layer-0/1 harness — not via full interpreter import.

### Completed slices (landed in jac-py history; do not re-derive)

- [x] **P3.0a — §5 re-hosting spike (`objects.jac`).** PyObj hierarchy + virtual slots
  (`nb_binop`, `mp_subscript`, `tp_iter`, `tp_hashkey`, …); data types
  (int/str/bytes/float/bool/None/complex/slice/tuple/list/dict/set/exception);
  pure helpers; **T7 na-clean** (`jac-py/tests/na_cliffs/t7_gate.py`).
  *Exit: `1+1`, `"a"+"b"`, `[1,2][0]`, `{"k":1}["k"]` replay green; leaf nacompiles.*
- [x] **P3.0b — Bootstrap bridge (`pyc_first.jac`).** CPython 3.14.6 marshal reader,
  ceval subset, host fallbacks for unported protocol surface; acyclic import from
  `objects.jac` only (PLAN §4 module-boundary constraint validated).
  *Exit: host `compile` → marshal → jacpython ceval oracle for arithmetic/sequence/call.*
- [x] **P3.0c — Layer-0 replay harness (`layer0_replay.jac`).** Harvest
  `assertEqual` pairs from real `Lib/test/test_*.py`, replay self-contained exprs
  without unittest/importlib. Core corpus at Layer 0: **119/50/345/20/9/9** passed,
  0 failed/err on int/bool/str/dict/list/tuple (counts ratcheted in P3 manifest).
- [x] **P3.0d — Bootstrap gap burndown (P3.1 prep, still bootstrap-layer).** UTF-8
  marshal, `%`-format, slice/memoryview, f-strings, generators, hash-key protocol,
  container semantics, operator overloading — all in `pyc_first`/`objects` split per
  na-clean rule. *Exit: original four P3.1 Layer-0 gaps closed (PLAN §7 progress block).*

### Next slices (actionable; one PR each)

- [x] **P3.1a — P3 conformance manifest + CI ratchet.** Checked-in Layer-0 baseline per
  `Lib/test/test_*.py` in `p3_object_core/manifest.json`; corpus replay gate in
  `layer0_replay.jac`; `test_p3_object_core_gate.jac` + full `layer0_replay.jac` wired
  into `jac-py-gates` CI; playbook §P3 in `jac-py/PORTING_PLAYBOOK.md`.
  *Exit: PR cannot silently drop int/bool/str/dict/list/tuple Layer-0 counts.*
- [x] **P3.1b — Layer-1 corpus baseline.** Gate + manifest for `layer1_replay_source` on
  `test_set.py`, `test_generators.py`, and method-body asserts in `test_list`/`test_tuple`;
  honest skip/failure baselines in `p3_object_core/manifest.json`; CI via
  `tools/p3_object_core/replay_gate.py` + `layer0_replay_p3_gate.jac` (`jac run`).
  *Exit: manifest lists Layer-1 counts; gate green at baseline; no new failures.*
- [x] **P3.1c — First c2jac `Objects/` extract (single file).** `boolobject.c` lifted to
  `jac-py/Objects/_lifted/boolobject.jac` (tier-B baseline 9, density ~4.4%); manifest
  `status`/`staging` `lift`; gate in `test_p3_object_core_gate.jac` + `lift_p3_objects.py`.
  Oracle vs hand path in `objects.jac` deferred to P3.1c follow-up; TRAP-doc gate satisfies exit.
  *Exit: one Objects file lifts with Tier-B density ≤15%; oracle or TRAP-doc gate green.*
- [x] **P3.1d — clinic2jac spike (T3, one clinic block).** `bool_new` clinic fixture →
  `jac-py/Objects/_clinic/bool_new.jac` via `tools/clinic2jac.py` (libclinic Jac backend);
  typed `bool_new_impl` + converter glue + docstring glob; `test_clinic2jac.py` + CI check.
  *Exit: one clinic block → typed Jac `def` + converter glue; fixture test in Tools/.*
- [x] **P3.1e — `abstract.c` protocol subset.** c2jac corpus extract
  (`tools/p3_object_core/corpus/abstract_protocol.c`) →
  `Objects/_lifted/abstract_protocol.jac` (tier-B baseline 1, ~0.3% density);
  na-clean runtime in `jacpython/abstract_protocol.jac` (`PyObject_GetIter`,
  `PyObject_RichCompareBool`, `PyObject_Hash`); native `hash()`/`iter()` wired
  in `pyc_first.jac`; Layer-1 protocol regression in `layer0_replay.jac`.
  *Exit: chosen helper subset oracle-tested; no new host binop fallbacks for that subset.*
- [x] **P3.2a (tupleobject) — tuple hash/richcompare/repr.** c2jac corpus extract
  (`tools/p3_object_core/corpus/tupleobject_core.c`) →
  `Objects/_lifted/tupleobject_core.jac` (tier-B baseline 10, ~4% density);
  na-clean runtime in `jacpython/tupleobject.jac` (CPython xxHash ``tuple_hash``,
  ``tuple_richcompare``); native ``hash()``/``repr()``/tuple compare wired in
  ``pyc_first.jac``; Layer-1 tuple regression in ``layer0_replay.jac``.
  *Exit: Layer-0/1 counts for tuple tests do not regress.*
- [x] **P3.2a (longobject) — digit arithmetic + hash.** c2jac corpus extract
  (`tools/p3_object_core/corpus/longobject_core.c`) →
  `Objects/_lifted/longobject_core.jac` (tier-B baseline 29, ~5.6% density);
  na-clean runtime in `jacpython/longobject.jac` (``v_iadd``/``v_isub``,
  ``x_add``/``x_sub``, ``long_compare``, CPython ``long_hash``); native
  ``hash(int)`` wired in ``pyc_first.jac``; Layer-1 int regression in
  ``layer0_replay.jac``.
  *Exit: Layer-0/1 counts for int tests do not regress.*
- [x] **P3.2a (listobject) — list richcompare/repr.** c2jac corpus extract
  (`tools/p3_object_core/corpus/listobject_core.c`) →
  `Objects/_lifted/listobject_core.jac` (tier-B baseline 3, ~0.8% density);
  na-clean runtime in `jacpython/listobject.jac` (CPython ``list_richcompare``,
  ``list_repr``); native ``repr()``/list compare wired in ``pyc_first.jac``; Layer-1 list
  regression in ``layer0_replay.jac``.
  *Exit: Layer-0/1 counts for list tests do not regress.*
- [x] **P3.2a (bytesobject) — bytes hash/richcompare/repr.** c2jac corpus extract
  (`tools/p3_object_core/corpus/bytesobject_core.c`) →
  `Objects/_lifted/bytesobject_core.jac` (tier-B baseline 2, ~0.4% density);
  na-clean runtime in `jacpython/bytesobject.jac` (CPython ``bytes_hash`` via
  host ``Py_HashBuffer`` parity, ``bytes_richcompare``, ``bytes_repr``); native
  ``hash()``/``repr()``/bytes compare wired in ``pyc_first.jac``; Layer-1 bytes
  regression in ``layer0_replay.jac``.
  *Exit: Layer-0/1 bytes repr/hash/compare tests do not regress.*
- [x] **P3.2a (exceptions) — BaseException str/repr + except match.** c2jac corpus
  extract (`tools/p3_object_core/corpus/exceptions_core.c`) →
  `Objects/_lifted/exceptions_core.jac` (tier-B baseline 0, ~0% density);
  na-clean runtime in `jacpython/exceptions_core.jac` (``baseexception_str``,
  ``baseexception_repr``, ``exc_name_matches``, ``py_err_given_exception_matches``);
  native ``str()``/``repr()``/``isinstance()``/``except`` matching wired in
  ``pyc_first.jac``; Layer-1 exception regression in ``layer0_replay.jac``.
  *Exit: exception isinstance/str Layer-1 replay does not regress.*
- [x] **P3.2a (dictobject) — open addressing + richcompare/repr.** c2jac corpus extract
  (`tools/p3_object_core/corpus/dictobject_core.c`) →
  `Objects/_lifted/dictobject_core.jac` (tier-B baseline 15, ~3.2% density);
  na-clean runtime in `jacpython/dictobject.jac` (probe helpers, ``dict_equal``,
  ``dict_richcompare``, ``dict_repr``); native dict ``==``/``!=``/``repr()`` wired
  in ``pyc_first.jac``; Layer-1 dict regression in ``layer0_replay.jac``.
  *Exit: Layer-0/1 dict equality/key-collision/repr tests do not regress.*
- [x] **P3.2a (setobject) — frozenset hash + richcompare.** c2jac corpus extract
  (`tools/p3_object_core/corpus/setobject_core.c`) →
  `Objects/_lifted/setobject_core.jac` (tier-B baseline 9, ~2.3% density);
  na-clean runtime in `jacpython/setobject.jac` (CPython ``frozenset_hash_impl``,
  ``set_richcompare``); native ``hash(frozenset)``/set compare wired in
  ``pyc_first.jac``; Layer-1 set regression in ``layer0_replay.jac``.
  *Exit: Layer-0/1 set hash/equality tests do not regress.*
- [x] **P3.2a (typeobject) — name/repr/hash helpers + ready stub.** c2jac corpus
  extract (`tools/p3_object_core/corpus/typeobject_core.c`) →
  `Objects/_lifted/typeobject_core.jac` (tier-B baseline 1, ~0.5% density);
  na-clean runtime in `jacpython/typeobject.jac` (``_PyType_Name``,
  ``type_repr``, ``type_richcompare``, ``PyType_Ready`` stub); native
  ``repr(class)``/class compare wired in ``pyc_first.jac``; Layer-1 type
  regression in ``layer0_replay.jac``. Heap-type creation deferred (P5).
  *Exit: type repr/identity/isinstance Layer-1 tests do not regress.*
- [x] **P3.2b — Module split (`ceval.jac`).** Extract callable/heap/proxy/eval from
  monolithic `pyc_first.jac` into `jacpython/ceval.jac` (~7.4k LOC) + acyclic
  `marshal_reader.jac` (~472 LOC); slim `pyc_first.jac` (~1.9k) re-exports public
  API; `ceval_slice.jac` thin re-export; `objects.jac` unchanged na-clean leaf;
  `p3_import_cycle_gate.py` + CI wired; `p4_import_gate.py` allowlist documents
  `ceval.jac` as product ceval module.
  *Exit: gate tests + pyc_first self-tests green; import-cycle gate PASS; T7 unchanged.*

### Explicitly deferred (not P3.0/P3.1 scope)

- Full mechanical lift of all 45 `Objects/*.c` files
- `unicodeobject.c` four-representation port (UTF-8-native `PyStr` is the v1 rule)
- Heap-type creation / full `typeobject.c` (P5)
- Native `len()` on plain `PyUserObj` containers (host boundary bug — separate branch)

---

## 4. Full tree (469 `.c` + 2138 `.py` via py2jac)

- Mechanical bulk lift of all `.c` might be days of compute + weeks of triage
- Making that output correct is the multi-year port, not the batch job itself
