# jac-py module porting playbook (P2 + P3 gates)

Short loop for staging CPython `Modules/*.c` leaf ports under `jac-py/Modules/`.
Object-core conformance (P3) uses a separate Layer-0 replay ratchet; see **§P3** below.

## Loop

1. **Pick a leaf** - prefer header-free or stub-include extracts (see `tools/p1_corpus/includes/`).
2. **Lift** - `jac tool c2jac path/to/module.c -o jac-py/Modules/module.jac` (add `-I` for stubs).
3. **Stage** - keep paired `module.c` + `module.jac` in `jac-py/Modules/`.
4. **Oracle** - add a differential test in `jac-py/tests/` (`cc` on `.c` vs `jac run` on fresh lift; int-line protocol in `lift_oracle.jac`).
5. **Tier-B queue** - `python jac-py/tools/t8_tier_b_queue.py jac-py/Modules/_lifted/.../project.c2jac.report.json`
6. **Burn down** - fix Tier-B sites (idiom pack or hand edit); accept only if oracle/libtest/conformance green and `tier_b_total` drops.
7. **Ratchet** - corpus baseline in `tools/p2_corpus/baseline/`; CI blocks regressions.

## Corpus waves

| Wave | Manifest | Modules | Gate |
|------|-----------|---------|------|
| P1 | `tools/p1_corpus/manifest.json` | 6 (c2jac proving) | `test_p1_corpus_gate.py` |
| P2 | `tools/p2_corpus/manifest.json` | 10 (P1 six + four Python/*.c extracts) | `test_p2_corpus_gate.py` |

Lift entire wave: `python jac-py/tools/lift_p2_corpus.py`

## Staged modules (P2 wave 1)

Ten files in `jac-py/Modules/`:

- `rotatingtree`, `pystrcmp`, `mysnprintf`, `getbuildinfo`, `_bisectmodule`, `_heapqmodule` (from P1 fixtures)
- `getplatform`, `getcompiler`, `getcopyright`, `pyfpe` (P2 header-free extracts)

Differential oracles: `test_rotatingtree_oracle.jac`, `test_p2_module_oracles.jac` (ten module ports; staged `.jac` where hand-edited or PyObj-stubbed).

## Dual pipeline - staged oracle vs lifted corpus

Two trees hold `.jac` for the same ten modules:

| Tree | Path | Role |
|------|------|------|
| **Staged oracle** | `jac-py/Modules/{stem}.jac` | Runtime + differential-test truth; may include hand edits and PyObj stubs |
| **Lifted corpus** | `jac-py/Modules/_lifted/p2_corpus_wave1/{stem}.jac` | Fresh c2jac output + T8 tier-B metrics input |

Policy is recorded in `tools/p2_staged_manifest.json` (`staging`: `lift` | `hand`):

- **`lift`** - staged file must match committed `_lifted` byte-for-byte. Drift means re-lift (`lift_p2_corpus.py`) or accidental edit.
- **`hand`** - staged oracle intentionally differs from fresh lift (`getbuildinfo`, `_bisectmodule`, `_heapqmodule`, `mysnprintf`). Exempt from equality gate; manifest `note` documents sync after burn-down.

**Fresh-lift unsafe path (`getbuildinfo`):** A naive c2jac lift of `getbuildinfo.c` still emits Tier-B sites (e.g. W4201 `char` casts) and lacks hand fixes (`_uchar`, byte-buffer `c_strcpy`/`c_strcat`) needed for correct differential behavior. Until the idiom pack absorbs those patterns, treat **`jac-py/Modules/getbuildinfo.jac` (hand-staged oracle) as canonical** for oracle tests and runtime truth, not the fresh `_lifted` output. T8 burn-down and density metrics run on `_lifted`; after staged oracle edits pass tests, sync with `sync_staged_to_lifted.py` before re-measuring. Do not point `assert_lift_matches_c` at fresh lift for this module (see `test_p2_module_oracles.jac`: staged oracle only).

**Drift gate:** `jac test jac-py/tests/test_p2_staged_sync.jac`

**Sync hand oracle → lifted** (after tier-B burn-down on staged file, before density re-measure):

```bash
python jac-py/tools/sync_staged_to_lifted.py          # all hand modules
python jac-py/tools/sync_staged_to_lifted.py --stem getbuildinfo
python jac-py/tools/sync_staged_to_lifted.py --dry-run
```

Workflow: edit staged oracle → oracle tests green → tier-B burn-down on staged → `sync_staged_to_lifted.py` → re-run `t8_tier_b_queue.py` / density ratchet on updated `_lifted` tree.

## T6 - conformance harness (P2 skeleton)

| Artifact | Role |
|----------|------|
| `jac/tests/jacpy/libtest_runner.jac` | Shared host + staged-Jac differential libtest runner |
| `tests/run_conformance.jac` | Runs host libtest snippets and staged Jac differential legs; writes `tests/conformance_manifest.json` |
| `tests/test_p2_libtest_partial.jac` | Jac tests for bisect/heapq/platform (host CPython + staged Modules/*.jac differential) |
| `tools/p2_conformance_gate.py` | CI gate: all ten P2 modules have `status: gated` in the manifest |

Gate types in the manifest:

- **oracle** - no stdlib mirror or hand-edited staged lift (`rotatingtree`, `pystrcmp`, `mysnprintf`, `getbuildinfo`, `getcompiler`, `getcopyright`, `pyfpe`); correctness via cc vs jac differential tests
- **libtest** - partial `Lib/test` snippets on **host CPython** (stdlib algorithm smoke) plus optional **staged Jac differential** via `tests.jacpy.libtest_runner` (`jac run` on `Modules/*.jac` when `JACPY_LIBTEST_JAC_DIFF` is enabled). Full JacPython native import of these ports remains future work.

**Jac differential vs host-only smoke:** `tests.jacpy.libtest_runner` always runs the host CPython leg (`expect_stdout`, default `"ok"`). The Jac differential leg is separate: it composes `Modules/{stem}.jac` + mock preamble + `jac_entry` (same pattern as `lift_oracle.jac` / `test_p2_module_oracles.jac`), then checks stdout against `jac_expect_stdout` when set, else falls back to `expect_stdout`. Disable differential collection with `JACPY_LIBTEST_JAC_DIFF=0` (host smoke only).

Regenerate manifest: `jac test jac-py/tests/run_conformance.jac` (writes `conformance_manifest.json` during collection; fails if host libtest or jac differential legs fail)

P2 exit ratchet: every module in `conformance_manifest.json` must stay `"gated"`; libtest modules must keep `libtest_results[*].failed == 0` and `jac_differential_results[*].failed == 0` when present.

## T8 AI cleanup (MVP)

1. **Queue** - `python jac-py/tools/t8_tier_b_queue.py --emit-queue /tmp/t8.json jac-py/Modules/_lifted/.../project.c2jac.report.json`
2. **Patch** - `python jac-py/tools/t8_driver.py <report> --patcher rule|mock|manual`: automated loop over the queue; `rule` applies known W4201/W4207 fallbacks, `mock` drops sidecar sites only (CI loop smoke, no LLM), `manual` prints prompt payloads.
3. **Accept** - `python jac-py/tools/t8_accept.py --report-before <before> --report-after <after> [--metrics-out metrics.json]`

Acceptance (PLAN §6.8): P2 module oracles pass (`test_p2_module_oracles.jac`, `test_rotatingtree_oracle.jac`), libtest partial suite passes (`test_p2_libtest_partial.jac`), conformance manifest gate passes (`p2_conformance_gate.py`), and `tier_b_total` in the after report is ≤ before (ideally lower). Metrics JSON: `{sites_before, sites_after, sites_fixed, tests_passed, timestamp}`.

Dry-run (acceptance tests + baseline vs current `tier_b_total`, no patch): `python jac-py/tools/t8_tier_b_queue.py --metrics jac-py/Modules/_lifted/.../project.c2jac.report.json`

Unit tests: `python3 -m unittest jac-py/tools/test_t8_accept.py jac-py/tools/test_t8_driver.py`

## P3 - object-core Layer-0 conformance (P3.1a+)

| Artifact | Role |
|----------|------|
| `tools/p3_object_core/manifest.json` | Checked-in passed/failed/errored baselines for int/bool/str/dict/list/tuple Layer-0 replay |
| `tests/test_p3_object_core_gate.jac` | Manifest shape + pending P3.1b/P3.1c slots |
| `jacpython/layer0_replay.jac` | Harvests self-contained `assertEqual` pairs from `Lib/test/test_*.py`; P3 test `"p3: Layer-0 corpus meets manifest baselines"` ratchets counts |

CI (`jac-py-gates` job, after P2 steps):

```bash
jac test jac-py/tests/test_p3_object_core_gate.jac
jac test jac-py/jacpython/layer0_replay.jac
```

Requires pinned CPython reference (`fetch_cpython_reference.py`, same step as other jac-py gates). **T7** (`jac-py/tests/na_cliffs/t7_gate.py`) stays independent: it gates na-clean emission on `objects.jac`, not Lib/test replay counts.

P3.1b will extend the manifest with Layer-1 baselines (`layer1_replay_source`); P3.1c stages first `Objects/` c2jac extract under `Objects/_lifted/`.
