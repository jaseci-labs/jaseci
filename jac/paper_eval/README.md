# GraphMend Paper Reproduction Harness

Reproduces the **break-elimination** and **output-correctness** claims of the
GraphMend paper (Table 2's fix-rate column + the "bit-identical FP32" result) on
real Hugging Face models. **CPU-reproducible** -- no GPU required.

For each model it runs the forward pass through a counting backend in two
isolated subprocesses (GraphMend off, then on) and reports breaks before/after
and whether the output fingerprint is unchanged.

## What this does and does not reproduce

| Paper claim | Here? |
|---|---|
| Graph breaks eliminated / fix rate (Table 2) | ✅ yes (CPU) |
| Output bit-identical (FP32) | ✅ yes (CPU) |
| Cold-start speedup (up to 26×) | ❌ needs NVIDIA GPU |
| Steady-state forward speedup (1.05–1.39×) | ❌ needs NVIDIA GPU |
| Throughput (up to 15%) | ❌ needs NVIDIA GPU |

The speedup rows are hardware-bound (paper used RTX 3090 / A40 / H100) and are
out of scope for this CPU harness.

## Requirements

- The **repo** `jaclang` must be the one imported (this branch's source, *not*
  any pip-installed `jaclang`, which predates GraphMend). Run with
  `PYTHONPATH=<repo>/jac`.
- `torch==2.12`, `transformers==4.52.4` (the paper's pinned versions).

## Run

```bash
cd jac
PYTHONPATH=$PWD python -m paper_eval.run_eval                 # offline models (default)
PYTHONPATH=$PWD python -m paper_eval.run_eval t5-small biogpt # a subset
PYTHONPATH=$PWD python -m paper_eval.run_eval MoLFormer-XL-both10pct  # opt-in, needs network
```

Example output:

```
model                        breaks_before breaks_after  fixed output_ok
------------------------------------------------------------------------
t5-small                                 3            0   100%       yes
biogpt                                   2            0   100%       yes
blenderbot-400M-distill                  3            0   100%       yes
opus-mt-fr-en                            3            0   100%       yes
PegasusForCausalLM                       2            0   100%       yes
Phi-4-mini-instruct                      5            0   100%       yes
------------------------------------------------------------------------
TOTAL                                   18            0   100% (eliminated 18/18)
```

## Transform coverage

Which rule actually does the work differs per model, and it is worth knowing
which ones a run exercises:

| Model | Rule exercised |
|---|---|
| t5-small, blenderbot, PegasusForCausalLM, biogpt, opus-mt-fr-en | `[Defer]` (logger deferral) |
| Phi-4-mini-instruct | **`[Where]`** (+ `[Defer]`) |
| MoLFormer-XL-both10pct (opt-in) | **`[Trap]`** |

Phi-4-mini is the paper's Figure 3 worked example and the only registry entry
that exercises the predicated control-flow rewrite. Its 5 breaks match Table 2.

`[Trap]` is covered by **MoLFormer-XL**, the paper's own validation-guard model,
which reproduces its Table 2 row exactly (5 breaks, VG (5), 100% fixed):

```bash
PYTHONPATH=$PWD python -m paper_eval.run_eval MoLFormer-XL-both10pct
#   MoLFormer-XL-both10pct   5   0   100%   yes
```

It is **opt-in** and skipped by a bare `run_eval`, because unlike every other
entry it needs network access and `trust_remote_code`. Two things about it are
worth knowing before trusting a result:

- **The revision is pinned** to `7b12d946c181`. The 2026-07 "Fix deprecated
  code" commit retargeted the model at a newer transformers (it imports
  `transformers.masking_utils`, absent in the paper's pinned 4.52.4), so `main`
  does not import at all under the paper's environment.
- **Scope it as `transformers_modules`, not by model name.** Hub remote code is
  loaded from a cache directory and lands under the `transformers_modules.*`
  namespace, so that is the prefix `--graphmend-scope` has to name.

  This works because jaclang hooks the **source loader** as well as
  `sys.meta_path`. transformers loads remote code with
  `spec_from_file_location` + `exec_module`, which never consults a meta-path
  finder, so `JacMetaImporter` alone would silently transform nothing (the row
  reads 5 -> 5 while appearing to work). `install_graphmend_loader_hook` in
  `jaclang/meta_importer.py` intercepts `SourceFileLoader.get_code` instead,
  which every such path still goes through. Compiling from source there also
  sidesteps `__pycache__`, so a `.pyc` written by an earlier non-GraphMend run
  is never served to a `--graphmend` run.

`[Trap]` is additionally verified on in-package source by
`test_trap_lowers_a_real_transformers_validation_guard`, which lowers VITS's
`if not (discriminant >= 0).all(): raise RuntimeError(...)`
(`_rational_quadratic_spline`, on the real inference path with `reverse=True`).
VITS is not a registry entry: it carries ~22 breaks from unrelated causes
(dynamic shapes in the vocoder) and that guard sits in a region already eager,
so lowering it correctly changes the graph count by zero -- a row would read
"22 -> 22, 0% fixed" and misrepresent a transform that worked. Note also that
all of transformers 4.52.4 contains exactly one `torch.equal`, in a loss
function rather than a guard, so the in-package evidence has to come from the
tensor-bool guard form.

To confirm which rule fired, look for the markers GraphMend leaves in the
generated bytecode: `__gm_cond_<n>` (a `[Where]`/`[Cond]` branch rewrite),
`__jac_log_emit__` / `__jac_flush_se_buffer__` (`[Defer]`), and
`__jac_tensor_eq_assert__` (`[Trap]`).

## How GraphMend is applied

The runner sets `program._graphmend_enabled = True` and
`program._graphmend_scope = [<model's transformers submodule>]` **before**
importing the model, so the model's `.py` modeling code is routed through the
GraphMend pipeline (same mechanism as
`jac run model.py --graphmend --graphmend-scope transformers.models.<x>`).

Two interception points cover this, and both are needed:

- `JacMetaImporter` on `sys.meta_path`, for ordinary imports.
- a hook on `SourceFileLoader.get_code`, for imports that build a spec directly
  and so never consult `sys.meta_path` -- Hugging Face `trust_remote_code`
  models being the motivating case. Both are inert unless `--graphmend` is
  active with a scope that names the module, and `torch`/`jaclang` are always
  excluded so interception can never break PyTorch or the compiler itself.

## Notes / faithful-but-scoped caveats

- **Small configs vs full models.** To keep the harness fast and download-free,
  `registry.py` builds each model from a *small* config (a few layers, random
  weights). Graph breaks are structural (code paths), so the fix-rate and
  correctness results are valid, but the *absolute* break count can be lower
  than the paper's (which uses the full pretrained models). To match the paper's
  exact per-model counts, swap a builder to `AutoModel.from_pretrained(<id>)`
  with the paper's inputs (needs network + disk).
- **Correctness comparison.** The runner fixes `torch.manual_seed(0)` so the
  off/on runs get identical weights; the output tensor (`logits` /
  `last_hidden_state`) is SHA-256 fingerprinted and compared.
- **Adding models.** Add a `_build()` returning `(model, inputs)` and a registry
  entry with the model's `transformers.models.<x>` scope. The remaining paper
  models (whisper, bart, Florence-2, grounding-dino, etc.) follow the same
  pattern; some need model-specific inputs (e.g. whisper takes
  `input_features`).
- **Scope the module the break is actually in, not just the model package.**
  A break site often lives in a *shared* top-level transformers module rather
  than under `transformers.models.<x>`. Phi-4-mini is the case in point: its
  data-dependent branch is `longrope_frequency_update` in
  `transformers/modeling_rope_utils.py`, so a scope of
  `["transformers.models.phi3"]` alone transforms nothing there -- the model
  still reports breaks fixed (by `[Defer]` elsewhere) and the `[Where]` rewrite
  silently never runs. Its entry scopes both modules. When adding a model, check
  where the break site really lives before trusting a green row.
- **Enabling the code path matters too.** Phi-4-mini only takes the LongRoPE
  branch when `rope_scaling.type == "longrope"` is set on the config; with the
  default rope settings the DC break does not exist and the row would pass
  vacuously.
