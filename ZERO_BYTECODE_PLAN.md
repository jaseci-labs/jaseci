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
| `jac/examples/chess/chess.jac` | 87,364,761 | `zb_chess_run_baseline.txt` (exit 0, Draws: 1) |
| `jac/examples/littleX/social_graph.jac` | 75,992,624 | compile-only |
| `jac/jaclang/jac0core/unitree.jac` (as input) | *pending* | compile-only |

**Per-merge gate:** targeted suites green (`JAC_TEST_JOBS=8`, named files) ·
corpus compiles clean and chess runs identically · trend non-increasing ·
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
- [ ] Rung 2 — **in flight** (`zbl/rung2-transform`): `prog` off `BaseTransform`; tripwire to the rim; `transform.jac` census → 0; fused-pipeline.md §11.1 corrected
- [ ] Rung 3: fused root sealed with two passes executing natively — **first trend-line drop**
- [ ] Rung 4: rim switches on a *written* fusible predicate; real modules route through the crossing; scope becomes a reported percentage
- [ ] Rung 5: JCFX compile-facts container; annex/absorb rewritten as source-crossings
- [ ] Rung 6: fusible predicate → everything (needs M2 complete)
- [ ] Rung 7: deletion accounting; per-node dispatch machinery removed — M4's trigger

## M2 — The type system and analysis cluster seal (typesys bucket → 0)

### Evaluator + type_checker (`zbl/evaluator-seal`) — **in flight**
- [ ] `[MultiString]` field-declaration refusal cleared (mechanism named)
- [ ] `dict[tuple, TypeBase | NoneType]` field-declaration refusal cleared
- [ ] First true census of `type_evaluator.jac` (measurable since #8299)
- [ ] Census meter typesys bucket mapping verified/corrected
- [ ] Handshake mechanism decided on evidence (one closure vs stamped boundary)
- [ ] type_evaluator + type_checker seal (or honest refusal, mechanisms named)

### cfg (`zbl/cfg-seal`) — **in flight**
- [ ] any-elem truthiness emitter bug fixed (invalid `icmp ne i8*` IR → truth protocol)
- [ ] `expr_keys.jac` hoist verified in cfg's paths
- [ ] cfg_build census + seal attempt (seal or honest refusal)

### Analysis cluster (`zbl/analysis-cluster`) — **in flight**
- [ ] rc_facts: 14 id()-keyed stamp seams lowered/re-keyed/stamped
- [ ] static_analysis: live couplings → stamp-and-consume
- [ ] ownership: redesign map (60 seams → families × mechanisms)
- [ ] ownership: first separable family landed
- [ ] dataflow rides as closure member of its consumers (doctrine)

### Gate 2 (`gate2-capability-seal`) — **in flight**
- [ ] Pre-scan refusal of `import from typing { Any }` root-caused and fixed
- [ ] capability_check: checker escalations + bare-tuple returns cleared; seal attempt
- [ ] layout_pass: 11 blockers + 23 seams burned down by family
- [ ] mtir_gen: closure reached; first census
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

## When GitHub returns

- [ ] Verify pushed states vs local (outage half-writes)
- [ ] Push `zb-local`; open as the #8288 mega branch/PR; draft #8240 shadow retired
- [ ] CI re-proves the arc (full matrix + pooled seal)
- [ ] #8313 macOS leg resumed (crash-report capture step)
- [ ] **The mega merge — maintainer's click**

## Parked

- #8313: macos-aarch64 SIGABRT in `access_check` dylib init (fails loudly + legibly now)
- #8308/#8309/#8310: filed, scheduled inside M3/M2 rungs

---

## Trend log

| Date | Merge | chess trend | littleX trend | Δ |
|---|---|---|---|---|
| 2026-08-17 | baseline (`cf477bf5e`) | 87,364,761 | 75,992,624 | — |
