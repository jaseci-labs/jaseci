# jac-py module porting playbook (P2)

Short loop for staging CPython `Modules/*.c` leaf ports under `jac-py/Modules/`.

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
| `tests/run_conformance.jac` | Runs embedded Lib/test-style Python snippets on host CPython; writes `tests/conformance_manifest.json` |
| `tests/test_p2_libtest_partial.jac` | Jac tests for bisect/heapq/platform algorithm parity on host CPython |
| `tools/p2_conformance_gate.py` | CI gate: all ten P2 modules have `status: gated` in the manifest |

Gate types in the manifest:

- **oracle** - no stdlib mirror or hand-edited staged lift (`rotatingtree`, `pystrcmp`, `mysnprintf`, `getbuildinfo`, `getcompiler`, `getcopyright`, `pyfpe`); correctness via cc vs jac differential tests
- **libtest** - partial `Lib/test` snippets run on **host CPython** only (algorithm smoke, not a differential Jac port); lifted C remains oracle-gated. Re-point at JacPython-imported modules once the native importer can load these ports.

Regenerate manifest: `jac test jac-py/tests/run_conformance.jac` (writes `conformance_manifest.json` during collection; fails if libtest snippets fail on host CPython)

P2 exit ratchet: every module in `conformance_manifest.json` must stay `"gated"`; libtest modules must keep `libtest_results[*].failed == 0`.

## T8 AI cleanup (MVP)

1. **Queue** - `python jac-py/tools/t8_tier_b_queue.py --emit-queue /tmp/t8.json jac-py/Modules/_lifted/.../project.c2jac.report.json`
2. **Patch** - fix Tier-B sites (idiom pack, hand edit, or LLM loop); re-lift or edit sidecars so `tier_b_total` drops.
3. **Accept** - `python jac-py/tools/t8_accept.py --report-before <before> --report-after <after> [--metrics-out metrics.json]`

Acceptance (PLAN §6.8): P2 module oracles pass (`test_p2_module_oracles.jac`, `test_rotatingtree_oracle.jac`), libtest partial suite passes (`test_p2_libtest_partial.jac`), conformance manifest gate passes (`p2_conformance_gate.py`), and `tier_b_total` in the after report is ≤ before (ideally lower). Metrics JSON: `{sites_before, sites_after, sites_fixed, tests_passed, timestamp}`.

Dry-run (acceptance tests + baseline vs current `tier_b_total`, no patch): `python jac-py/tools/t8_tier_b_queue.py --metrics jac-py/Modules/_lifted/.../project.c2jac.report.json`

Unit tests: `python3 -m unittest jac-py/tools/test_t8_accept.py`
