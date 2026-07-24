# results/paper-canonical/

The ONE artifact set the paper is built from (STEPS.md Phase A, item 5).

Contents (populated by the result-producing pipeline -- Phase A item 4):

- `env.json` -- frozen revision + environment manifest
  (`python ../../scripts/capture_env.py -o env.json`).
- `raw/` -- raw per-invocation timings. **Medians are never the only retained
  observation** (item 6): every row keeps session id, round, order, raw total
  time, per-call time, digest, pid, warm-up status, exit status.
- `aggregate/` -- aggregated JSON + plot data, generated from `raw/` by committed
  analysis scripts.
- `logs/` -- full stdout/stderr of every producing run.

Acceptance criterion (item 5): a reviewer can verify that every table value in
`paper.tex` was produced by a script from these files, not copied by hand.
Until the pipeline exists, this directory is a placeholder.

> Build gate: `env.json` must report `git_dirty: false`. A dirty worktree is not
> a frozen revision and is rejected by `capture_env.py` (exit code 2).
