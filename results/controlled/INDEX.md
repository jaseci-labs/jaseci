# Controlled re-capture dataset -- 2026-07-24

First interopbench captures under a **pinned CPU governor** (`performance`),
replacing the quarantined n5/n7/n30 captures (which ran on `powersave` +
turbo-on, unpinned -- the root cause of the contradictions; see
`results/archive/`).

## Why this exists

Diagnosis (see memory `interopbench-slope-contradiction-rootcause`): the
contradictions were **uncontrolled-CPU-frequency artifacts**, not a toolchain
bug and not commit `367a786cc` (exonerated). The sweep "two attractors"
(88 & 185 ns/work) were turbo vs base clock on the same Python loop.

## Conditions

| field | value |
|---|---|
| governor | `performance` (all 16 cores) |
| turbo | on (NOT disabled -- see caveat) |
| affinity | 0-15 (not pinned per-process) |
| git sha | `367a786cc` (clean; benchmark code) |
| tree | dirty (untracked paper/notes/probe; `git_dirty_count=10`) |
| jac | 0.34.1 dev mode (in-repo compiler source) |
| full provenance | `env.json` |

## Files

| file | what | result |
|---|---|---|
| `env.json` | capture_env.py provenance | governor=performance, sha=367a786cc |
| `sweep_perf_n20.json` | iop_call/cb/symmetric multi-work sweep, n=20 | **iop_call.free 165 vs iop_cb.free 163 = 1.01x** (was 2.1x in both archives) -- contradiction resolved |
| `xruntime_perf_small_n20.json` | svc_split/feed, `small` (work=200,calls=20) matching archives, n=20 | svc_split **376x**, feed **270x** (archives: 135/515, 213/329) |
| `xruntime_perf_n20.json` | svc_split/feed, `default` config, n=20 | NOT comparable to archives (different size); kept for reference |

## Headline

The sweep contradiction is **resolved**: `iop_call.free` and `iop_cb.free`
(the pair that read 87-vs-182 in n5 and 185-vs-88 in n30) now agree within 1%.
Frequency non-determinism was the cause.

## Caveats (this dataset is controlled, not yet canonical)

1. **Thermal drift in absolutes.** Turbo is still on; the 8-min sweep let the
   clock droop under sustained load -- absolute slopes drifted up (~110 early
   → ~165-210 late). *Comparisons* stayed valid (call & cb tracked together);
   *absolutes* are not bit-for-bit reproducible. **Fix: disable turbo**
   (`echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo`) and re-run.
2. **`iop_cb.bridge` slope (246) is noisy** with an unstable intercept; the
   callback-crossing path needs more reps. The "callback fixed cost" came out
   negative -- reinforcing that the paper's "5.4 us" was a noisy-intercept
   artifact, not signal.
3. **xruntime ratios are a single run** (376x / 270x). Reproducibility across
   runs is not yet demonstrated; the RPC path's original 3.9x inflation between
   n7/n30 may have a non-frequency component (host adapter / scheduling) -- not
   pinned. Re-run x2-x3 to characterize.
4. **Dirty tree.** `git_dirty=true`. For canonical status, commit a clean
   anchor (benchmark code is already clean at `367a786cc`; only paper/notes
   are untracked) and re-emit `env.json`.

## To promote to canonical

- disable turbo, re-run sweep + xruntime (absolutes tighten);
- repeat xruntime 2-3x to confirm ratio stability;
- commit clean tree, regenerate env.json.
