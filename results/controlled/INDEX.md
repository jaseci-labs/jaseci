# Controlled re-capture dataset -- 2026-07-24/25 (CANONICAL)

Interopbench captures under a **pinned CPU governor** (`performance`) **and
disabled turbo** (`intel_pstate/no_turbo=1`), replacing the quarantined
n5/n7/n30 captures (which ran on `powersave` + turbo-on, unpinned -- the root
cause of the contradictions; see `results/archive/`).

## Why this exists

Diagnosis (see memory `interopbench-slope-contradiction-rootcause`): the
contradictions were **uncontrolled-CPU-frequency artifacts**, not a toolchain
bug and not commit `367a786cc` (exonerated). The sweep "two attractors"
(88 & 185 ns/work) were turbo vs base clock on the same Python loop.

Two knobs, two fixes: **pinning the governor** fixed the *comparisons* (call vs
cb agree); **disabling turbo** fixed the *absolutes* (no thermal droop over the
8-min sweep, so slopes/intercepts stop drifting).

## Conditions

| field | value |
|---|---|
| governor | `performance` (all 16 cores) |
| turbo | **disabled** (`no_turbo=1`) |
| affinity | 0-15 (not pinned per-process) |
| git sha | `8495b2ad5` (benchmark tree sha256 `43e8f7357...` -- **identical** to `367a786cc`; benchmark code frozen/unchanged) |
| tree | code clean; only the result artifacts below are uncommitted at capture |
| jac | 0.34.1 dev mode (in-repo compiler source) |
| clock check | `direct` path 385us (turbo) -> 805us (no-turbo) = 2.09x = the boost ratio |
| full provenance | `env.json` |

## Files

| file | what | result |
|---|---|---|
| `env.json` | capture_env.py provenance | governor=performance, **turbo=off**, sha=8495b2ad5, benchmark_tree_sha256 unchanged |
| `sweep_perf_n20.json` | sweep, governor pinned, **turbo ON** (superseded) | resolved call-vs-cb contradiction but absolutes still drift (thermal) |
| `sweep_noturbo_n20.json` | sweep, governor pinned + **turbo OFF** (canonical) | all crossing slopes converge to **212-217 ns/work**; intercepts positive |
| `xruntime_perf_small_n20.json` | svc_split/feed, turbo ON, single run (superseded) | 376x / 270x, but n=1 (no reproducibility shown) |
| `xruntime_noturbo_small_n20_rep{1,2,3}.json` | svc_split/feed, turbo OFF, 3 reps (canonical) | svc_split **369x** (CV 3.7%), feed **243x** (CV 3.0%) |

## Headlines (canonical)

1. **Sweep contradiction resolved.** Under no-turbo every boundary-crossing
   slope collapses onto ~212-217 ns/work:

   | variant | perf (turbo on) | **no-turbo** |
   |---|---|---|
   | iop_call.free | 165 | **217** |
   | iop_cb.free | 163 | **212** |
   | iop_cb.bridge | 246 (noisy) | **213** |
   | sym.sv_local | 212 | **212** |
   | sym.na_to_sv | 179 | **214** |
   | sym.na_local | 4.6 | **5.0** |
   | sym.sv_to_na | 5.0 | **5.1** |

   The pair that read 87-vs-182 (n5) and 185-vs-88 (n30) now agree within ~2%.
   The one path still noisy under turbo (`iop_cb.bridge`, 246) falls into line
   at 213 once thermal drift is removed.

2. **Placement penalty ~42x (the real effect).** Work on the server/interpreted
   side costs ~213 ns/unit; native-side ~5 ns/unit. 214 / 5.1 = **42x**. Crisp,
   physical, reproducible.

3. **The "5.4 us callback fixed cost" is retracted.** Under turbo the fits gave
   nonsense negative intercepts (`iop_cb.bridge` -8682, `iop_call.free` -1222)
   -- an artifact of the clock drooping over the sweep (early points fast, late
   slow, line tilts up, intercept goes negative). Under no-turbo all intercepts
   are positive and small (~130-5000 ns), and **variant-dependent** -- there is
   no single clean fixed-crossing constant; it is a few us but not "5.4".

4. **Cross-runtime ratios reproducible (3 reps).**

   | cell | rep1 | rep2 | rep3 | mean | run-to-run CV |
   |---|---|---|---|---|---|
   | svc_split | 384x | 351x | 373x | **369x** | 3.7% |
   | feed | 252x | 235x | 241x | **243x** | 3.0% |

   All jitter lives in the RPC *numerator* (189-309 ms, loopback/node
   scheduling); the `direct` baseline is rock-solid (CV 0.2-0.3%, ~805 us every
   run). The RPC/direct ratio survives it, stable to ~+/-4%. The earlier
   single-run caveat is discharged.

## Scope of claims

Portable claims are the **ratios** and the **ns-slopes-at-recorded-clock**.
Absolutes (805 us direct, 212 ns/work) are specific to this CPU
(Ultra 7 255H) at pinned base clock / no-turbo. The RPC numerator carries
intrinsic loopback+scheduler jitter that no governor setting removes -- that is
real system noise, characterized (CV ~3%), not a defect.

## Prior caveats -- disposition

1. ~~Thermal drift in absolutes~~ -> **fixed** (turbo disabled; slopes stable).
2. ~~`iop_cb.bridge` noisy (246, unstable intercept)~~ -> **fixed** (213,
   positive intercept under no-turbo).
3. ~~xruntime is a single run~~ -> **fixed** (3 reps; CV ~3%).
4. ~~Dirty tree (paper/notes/probe)~~ -> committed in `8495b2ad5`; only result
   artifacts are uncommitted at capture time.
