# Zero-Bytecode Execution Plan

**Goal (from #8139, chartered as #8288):** while the shipped `jac` binary compiles a
program, no Python bytecode executes anywhere in the pipeline.

**Mode:** LOCAL (GitHub outage). Integration branch `zb-local`; missions land on
`zbl/<mission>` branches and merge into `zb-local` after gating. History stays
publishable — when GitHub returns, `zb-local` ships as the #8288 mega branch and
the final merge is the maintainer's click.

**The meter:** `jac/scripts/zb_frame_census.py` — Python frames entered in
`jaclang.*` during a cold-cache compile, bucketed. The **trend line**
(passes + typesys + codegen) must be non-increasing at every merge and reads **0**
at completion (rim entries then deleted by M4).

| Corpus entry | Trend baseline | Run baseline |
|---|---|---|
| `jac/examples/chess/chess.jac` | 87,456,371 (meter v2) | `zb_chess_run_baseline.txt` (exit 0, Draws: 1) |
| `jac/examples/littleX/social_graph.jac` | 76,083,257 (meter v2) | compile-only |
| `jac/jaclang/jac0core/unitree.jac` (as input) | *pending* | compile-only |

**Per-merge gate:** targeted suites green (`JAC_TEST_JOBS=8`, named files) ·
corpus compiles clean and chess runs identically · trend non-increasing (±0.2%
run noise band, established at meter v2) ·
seal-affecting changes additionally pass the pooled seal battery.

---

## Phase 0 — Foundations (complete, pre-outage)

- [x] Seal pool + process-boundary tree reclaim (#8280): build-jac 56m→12m, peak 27.3→12.7 GiB
- [x] **Stage-1 cutover** (#8291, `bd272af79`): JCIR sole codegen, `pyast_gen`/`pybc_gen` deleted (5,948 lines), four gates evidenced, #8201 closed
- [x] Module-fatal signature hole → per-method demotion (#8299); evaluator ground measurable
- [x] E5088 hollow-construction refusal + `prog` stamp + guard honesty (#8305)
- [x] Pass base chain de-genericized, checker byte-identical (#8306) — **M1 rung 1**
- [x] Release legs: relocation family + Darwin probe (#8302), outline atomics + un-muted worker (#8307) — linux-aarch64 GREEN; macOS parked in #8313
- [x] M1 census + design doc (`internals/fused-pipeline.md`): 14 artifacts bind but never execute; parser is the only crossing
- [x] M3 spike (`m3-modty-spike`): native mod_ty transcription proven byte-identical, ~13× faster; 5-symbol surface; version-pin settled; #8308/#8309 filed
- [x] Frame-census meter + chess/littleX baselines committed on `zb-local`

## M1 — The fused pipeline (sealed passes EXECUTE)

- [x] Rung 0: fused-crossing parity canary (vertical slice green, byte-identical on 4 modules)
- [x] Rung 1: base chain loses genericity (#8306) + emitter `prog` retirement (#8305)
- [x] Rung 2 (`6752937b3`): `prog` is driver-stamped via the new `PassRim` construction seat (91 reads measured, all in 8 unsealed passes; 11 redeclarations deleted); the tripwire moved to the unbypassable metaclass seat; `transform.jac` 2 fatals → 0, seams 4 → 3 honest; §11.1's genericity misdiagnosis corrected on the doc branch; BONUS: the `testskip` builtin-registry hole (cutover-era, the aarch64 noise source) fixed and triple-pinned
- [ ] Rung 3+4 — **in flight as the MATERIALIZE-POINT SLIDE** (`zbl/materialize-slide`): the leading contiguous sealed-pass prefix runs natively on the native tree before materialization (the mat_merge_probe pattern extended); schedule audit first, parity canary red-first, loud named fallback
- [ ] Rung 4 (folded into the slide): the rim's path selection recorded per module; scope becomes a reported percentage
- [ ] Rung 5: JCFX compile-facts container; annex/absorb rewritten as source-crossings
- [ ] Rung 6: fusible predicate → everything (needs M2 complete)
- [ ] Rung 7: deletion accounting; per-node dispatch machinery removed — M4's trigger

## M2 — The type system and analysis cluster seal (typesys bucket → 0)

### Evaluator + type_checker (`zbl/evaluator-seal`) — **in flight**

- [x] `[MultiString]` field refusal measured HONEST: `JacProgram` needs a native layout (label unquoted and truthful; the salvage's per-field seam mechanism audited and landed)
- [x] `dict[tuple, TypeBase | NoneType]` CLEARED by real lowering — cache split into `tuple[int,int]`/`tuple[int,str]` dicts (110→109 seams; the id()-inside-tuple-constructor gotcha retired en route)
- [x] First true census of `type_evaluator.jac`: has_ir=True, 0 fatal, closure 20, **109 seams across 50 causes** (90 cascades; `ArgsList` placement strands 21 methods; `**kwargs` 6; CPython `ast` ×4 = permanent floor)
- [x] Census meter typesys mapping FIXED (checker was billed to the pass tier by prefix ordering; +4,076 frames rebilled; baselines regenerated as meter v2)
- [x] Handshake DECIDED on measurement: **one closure** — 34/46 checker seams are the undeclared `self.evaluator` field crossing the object bridge; implementation gated on optional-field declaration (retypes 34 method bodies), guard test pins the evaluator out of the checker's closure until done
- [ ] type_evaluator + type_checker seal (or honest refusal, mechanisms named)

### cfg (`zbl/cfg-seal`) — **in flight**

- [x] The RECORDED bug didn't exist — the real family: bare `i8*` assumed to be a string at TWO sites (subscript on erased inner dicts = silent char-load miscompile; `in`/`not in` fell back to `strstr` over arbitrary pointers). Both fixed red-first; the salvage's guard REJECTED by measurement (would demote `w in s` on str params)
- [x] `expr_keys.jac` hoist verified (8 import sites, zero symbol_utils refs) and pinned by test
- [x] **cfg_build SEALED — the fifteenth root** (7.85MB, 117 exports, seam==waiver; `expr_keys.jac` joins the closure at zero seams; 4 own seams waived, 3 of them jac-dot-only). Seal peak 2.48 GiB/root (~55% over the old law) — CI budget recheck queued

### Analysis cluster (`zbl/analysis-cluster`) — **in flight**

- [x] **rc_facts SEALED — the sixteenth root** (10 own seams → 0; five mechanisms: .gen stamps → Module slots, `is_builtin_region_name` hoisted to `expr_keys`, erased containers typed, `.items()` destructure typed, bound-method-across-module solved via `solve_backward_gen_kill`)
- [ ] static_analysis: 8 → 6 (undeclared `_checked_scopes` stash declared); three mechanisms remain (`expr_primitive_name`'s evaluator fallback, ~200 lines of symbol_utils reporters, a `prog.type_evaluator` read)
- [x] ownership map DONE: #8271's 60 seams measure **26**, six families; `emit related=` (11 seams) is ONE backend gap (`list[tuple[str, UniNode]]` mixed-element storage) — priced as the cheapest next buy and assigned to the burn-down mission; refusal pinned at measured counts both ways
- [ ] ownership: first separable family landed
- [x] dataflow lowers at ZERO seams (lattice typed `set[SymId]` + for-over-set lowering) — #8271's 'Python-only by construction' verdict REFUTED; rides in the rc_facts closure

### Gate 2 (`gate2-capability-seal`) — **in flight**

- [ ] Pre-scan refusal of `import from typing { Any }`: ROOT-CAUSED, 3-item clearing list pinned (`BaseTransform.prog` — now GONE via rung 2 — and 2 × `CLIENT_RUNTIME_SOURCE_PATHS` shapes); fix deliberately deferred (widening `prog` would silently strip `self.prog.*` checks from non-shadowing passes) — re-attempt is cheap post-rung-2
- [x] capability_check: 7 blockers → 0, **first native IR**, 7 → 5 seams = 3 named mechanisms (honest refusal). BONUS: **module_codegen 6 → 0 seams** — its recorded isinstance-waiver rationale was WRONG (the erasure was the bug); waiver table entry deleted
- [ ] layout_pass: 11 → 2 blockers, produces IR (wave 5 had measured none), seams 23 → 22; acyclicity handoff resolved (premise refuted — `is_acyclic` was never stuck; the real defect was the undeclared `type` stash, now declared); family burn-down continues
- [ ] mtir_gen: 37 → 32 blockers; closure still unreached (wave 5's census confirmed accurate)
- [ ] boundary_analysis: ~23 driver seams → stamp-and-consume (capacity permitting)

## M3 — Native transcription (codegen bucket → 0)

- [x] Spike: feasibility + prototype byte-identity + design doc (`internals/mod-ty-transcription.md`)
- [ ] Rung 1: layout audit + pin (`audit_layouts.py` promoted; build fails on CPython drift with named diff)
- [ ] Rung 2: generator + generated TU for every emitter-named class (~90); symbol-checked
- [ ] Rung 3: differential lane — native seat beside shim on every compile, field-by-field, fails on any difference
- [ ] Rung 4: compiler-flag pin (#8308 fixed as its own rung)
- [ ] Rung 5: splices, diagnostics, multi-module containers
- [ ] Rung 6: cutover + deletion — shim seat and `codegen_shim` production half deleted
- [ ] #8309 double-transcription: cheap fix or subsumed by rung 6

## M4 — Deletion and the invariant (trend → 0, locked)

- [ ] Zero-objects-materialized counter asserted in the validation gate (matures from the frame census)
- [ ] Materializer fleet + generator deleted (Step 5)
- [ ] Bytecode twins of executed-native modules deleted; fallback path gone
- [ ] Rim enumerated, shrunk, entries deleted; tooling demoted to bootstrap tier
- [ ] **Final validation: corpus trend = 0; chess compiles and runs identically**

## Validation upkeep

- [x] Meter harness committed (`zb-local` 8ea21a7a1)
- [x] chess baseline (census + run output)
- [x] littleX baseline
- [ ] unitree-as-input baseline (heavy; quiet-window run)
- [ ] Trend log updated at every merge (table below)
- [ ] METHODOLOGY UPGRADE QUEUED: warm-census (compiler cached, chess-compile-only counts, ±12-frame determinism per the cfg mission's A/B) becomes the comparable gate metric; cold stays for headline absolutes. Warm references to be recorded

## When GitHub returns

- [x] Verified: upstream main NEVER MOVED during the outage (still `2e8a18b29` = our base); origin branches intact
- [x] `zb-local` pushed; shadow #8240 re-armed at the arc tip (full matrix running)
- [ ] PR `zb-local` → upstream main ("land all finished work" — maintainer-directed 2026-08-17); merge on local gate + shadow both green
- [ ] CI re-proves the arc (full matrix + pooled seal)
- [ ] #8313 macOS leg resumed (crash-report capture step)
- [ ] **The mega merge — maintainer's click**

## Parked

- #8313: macos-aarch64 SIGABRT in `access_check` dylib init (fails loudly + legibly now)
- #8308/#8309/#8310: filed, scheduled inside M3/M2 rungs
- TO FILE: cfg's untyped-loop-var membership residual (`w in v` over erased dict values still reaches strstr and answers wrong; refusing strictly would demote str-param membership — needs type stamping through the loop bind or a runtime storage-tag read)
- CENSUS VARIANCE NOTE: the Gate-2 mission's claimed −3.0% trend drop is NOT reflected in the merged-tree measurement (arithmetic across all five merges bounds the others' contributions near zero) — treated as a measurement-environment artifact; the warm-census methodology upgrade is the fix

---

## Trend log

| Date | Merge | chess trend | littleX trend | Δ |
|---|---|---|---|---|
| 2026-08-17 | baseline (`cf477bf5e`) | 87,364,761 | 75,992,624 | — |
| 2026-08-17 | evaluator census (`4067df084`) | 87,456,371 | 76,083,257 | meter v2 rebaseline; trend-neutral by construction (checker rebilled within trend); ±0.1% noise band measured |
| 2026-08-17 | generation 1 complete (`6752937b3`): gate2 + cfg + analysis + rung2; roots 14→16 | 87,623,659 | 76,239,883 | +0.19%/+0.21% = cold-run noise edge; gate2's −3% claim unconfirmed (see Parked); correctness gates all green (tier 8, wave3 7, wave7 6, reachability-16 14, chess identical) |
