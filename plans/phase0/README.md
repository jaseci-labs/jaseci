# Phase 0 status

Completed 2026-07-14 as part of the fused-host `PLAN.md` cutover.

| Deliverable | Location | Result |
|---|---|---|
| Baseline inventory | `BASELINE.md` | recorded |
| Embed ownership | `inventory/embed_ownership.md` | recorded |
| PTY harness | `pty/harness.py` | characterization only; opt-in via `JAC_AI_TUI_PTY_HARNESS=1` |
| Event traces | `traces/README.md` | current vs target documented |
| Width classification | `width/` | probe PASS; emoji=1 cell noted |
| Perf method | `perf/BASELINE.md` | method documented |
| D2 Component dispatch | `../probes/_probe_component_d2.na.jac` | **PASS → virtual Component** |
| E1 Embed ownership | `../probes/_probe_embed_e1.jac` | **PASS → `.na.jac` EmbedRuntime** |

Phase 1 correctness (stopping, pending submit, no `id=-1`, terminal-first quit)
landed in the same change set; see `plans/SCOPE.md` decision log.
