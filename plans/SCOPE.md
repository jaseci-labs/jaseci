# SCOPE -- turning the single-process PLAN into actionable work

> **Relationship to `PLAN.md`:** `PLAN.md` is normative: it defines the target
> architecture, invariants, interfaces, and Phase 0-7 migration, with optional
> Phase 8 persistence. This document is the reality-checked execution scope: the
> dependency graph, near-term gates, open decisions, and ready work.

Status: Phase 0-7 orchestration recut landed at source level (PTY native-build smoke deferred)
Last revised: 2026-07-19

---

## 1. Reality check -- target vs. code today

The product already has the topology the revised plan keeps:

```text
jac ai --tui
  -> execve(bin/jac-ai-tui)
  -> one native Jac process
       ├── native tty renderer
       └── one embedded CPython / managed Jac agent
```

There is no renderer subprocess in the shipped path. The refactor deepens the
in-process modules without changing that deployment topology.

| Current fact | Verified evidence | Target change |
|---|---|---|
| Native calls managed `setup`/`poll`/`send`/`stop` directly | `ai_tui/embed_agent.jac`, `ai_tui_na/host_embed.na.jac` | Keep direct in-process calls behind `EmbedRuntime` and `EmbedSessionClient` |
| CPython refs and GIL operations leak into transport/loop concerns | `EmbedPyTransport` stores callable refs as `int`; `transport.na.jac` performs `PyEval_SaveThread`/`RestoreThread` | **Closed in Phase 4:** only `embed_runtime.na.jac` imports jacpyembed; transport is tty-only |
| Status schema has drifted | managed host emits `stopping`; native state recognizes only idle/running | **Closed (Item 5):** manifest-generated bridge schema; native `parse_tui_status` maps starting/quiescing/disposed/failed |
| Native inserts an optimistic user row | `state.na.jac` uses pending `id=-1` adoption | Keep editor text pending until a command receipt accepts it; host emits the only user row |
| Agent lifecycle state is module-global | `embed_agent.jac` globals `_q`, `_stop`, `_stub`, `_thread` | **Closed (Item 1):** `AgentSession` owns non-daemon turn thread via `ui_prepare_turn`/`ui_run_turn`; feed thread tracked in `_workers` |
| Shutdown restores tty too late | current host calls `stop()`, unconditionally `Py_Finalize()`, then `tty_close()`; managed stop only attempts a two-second daemon-thread join | **Closed (Items 1/4):** terminal-first quit; `ui_stop` before adapter dispose; `finalize_if_safe` gated on worker join |
| Bridge schema is duplicated | `ipc_schema.jac` and `ipc_schema.na.jac`, guarded by mirror tests | **Closed (Item 5):** `bridge_schema.manifest.json` + `gen_bridge_schema.py` generate both code spaces |
| Bridge framing is positional/stringly | `_frame_blob`, `L:<n>`, `key:value`, native frame parser | Complete typed JSON values per embed call; no stream framing |
| Renderer composition is monolithic | `screen.na.jac` plus state-specific helpers | **Closed (Item 4):** production runs `InteractiveApp → Tui → ProcessTerminal`; `tui_loop.na.jac` deleted |
| Source/development launch can lazily build the host | `run_tui_embed` calls `_ensure_embed_host`; missing/stale artifacts invoke `build_embed.sh` | Keep explicit lazy build for development if useful, but packaged release contains a fresh host and starts offline without compilation/source lookup |
| PTY semantics are under-qualified | no established `pexpect`/`openpty` lifecycle suite in `jac/tests/` | Characterization harness exists (opt-in); native `build_embed.sh` blocked by pre-existing LLVM IR failure - PTY smoke deferred |
| Session/event sequencing is contradictory | projector assigned seq before coalescing; native ignored batch epoch/seq | **Closed (Items 2/3):** `SessionEventDispatcher` serializes projector+queue; native batch validation + snapshot part preservation |
| Tests overstate cutover via source-string guards | phase5/6/7 assert `"X" in src` | **Closed (Item 6):** behavior selftests (`selftest_session_dispatch`, `selftest_interactive_app`) + import-and-call; ≤5 structural guards remain |

### What the revised plan no longer asks for

The following work from the prior scope is retired:

- renderer child executable and parent supervisor;
- anonymous-pipe JSONL RPC;
- pipe fragmentation, partial-write, heartbeat, and process handshake logic;
- child environment filtering and protocol-only stdout;
- parent terminal guardian for renderer crashes;
- process-mode feature flag/default migration;
- deletion of `libjacpyembed` or the embedded runtime;
- claims that native/managed failures are fault-isolated.

D3 (pipe partial I/O) is therefore archived as non-gating. A process split may
be reconsidered only from measured product failure evidence after the fused
lifecycle has been qualified.

---

## 2. Critical-path dependency graph

```text
Phase 0 -- characterize + settle D2/embed ownership
    │
    ▼
Phase 1 -- fix current fused correctness
    │       stopping · acceptance · no id=-1 · terminal-first quit
    ▼
Phase 2 -- typed session/projector/bridge models + fakes
    │
    ▼
Phase 3 -- instance-owned AgentSessionRuntime/TuiSessionAdapter
    │
    ▼
Phase 4 -- narrow EmbedRuntime/EmbedSessionClient cutover
    │                                  │
    │                         Phase 5 -- Pi-style native TUI modules
    │                                  │
    └──────────────────┬───────────────┘
                       ▼
Phase 6 -- fused lifecycle qualification + legacy bridge deletion
                       │
                       ▼
Phase 7 -- offline packaged release

Phase 8 -- optional JSONL sessions, enabled only by separate product review
          (depends on Phase 3 ownership, not on Phase 5 UI composition)
```

Scheduling notes:

- Phase 1 may begin after Phase 0 has captured baseline behavior.
- Phase 2's managed models/projector and native fixture decoder can proceed in
  parallel after bridge shapes are agreed.
- Phase 3 should land before the production embed cutover so the new adapter is
  not built around module-global state.
- Phase 5 extraction can begin after D2 selects dispatch and Phase 2 provides a
  fake `SessionClient`; it can overlap Phases 3-4 with one writer per file area.
- Phase 6 is the destructive gate: do not delete legacy framing or fallback
  until both the new embed seam and modular TUI pass PTY integration.
- Phase 8 is not on the release critical path.

---

## 3. Phase 0 gate -- detailed scope

Phase 0 establishes evidence. It does not change the production topology or
silently bless current behavior.

### 3.1 Preserve the working baseline

Before implementation:

- record all modified and untracked files;
- distinguish pre-existing work from Phase work;
- do not auto-shelve or rewrite unrelated changes;
- record the exact command and artifact used for the current TUI launch;
- capture the current native host and `libjacpyembed` build identity.

At this revision the repository already contains modified TUI/bridge files and
untracked planning artifacts. They must be treated as user work, not reset.

### 3.2 PTY characterization

Establish deadline-bounded scenarios for:

```text
boot
prompt acceptance and streaming
busy/rejected prompt
stop
stop then immediate submit
reset
normal quit
idle and active Ctrl+C
resize and input burst
SIGTERM / SIGHUP
provider exception / hang
startup or embed-bind failure
tty EOF / hangup
```

For each recoverable exit record:

- exit status;
- canonical/raw mode and echo;
- alternate screen, cursor, mouse, and bracketed-paste state;
- whether managed workers remain alive;
- whether interpreter finalization occurred or was safely skipped;
- last lifecycle milestones written to the redacted debug sink.

`SIGKILL` can be characterized, but terminal restoration is not a gate because
the killed fused process cannot execute cleanup.

### 3.3 Semantic traces and width baseline

Capture current event traces for:

- authoritative user message;
- answer/reasoning streaming;
- tool start/update/end and error;
- images;
- model/settings/file-resource changes;
- stop, reset, provider error, and settlement.

Add display-cell-width checks independent of existing golden expectations.
Classify goldens as valid or invalid before regeneration; do not preserve an
invalid row merely because it is currently checked in.

### 3.4 Performance baseline

Measure:

- startup time;
- p50/p95 local key-to-paint;
- streaming paints and bytes per token;
- idle CPU;
- steady-state and ten-minute-stream RSS;
- queue depth under a synthetic event burst.

The target remains one long-lived TUI process with one embedded CPython; tool
subprocesses are excluded from idle topology measurements.

### 3.5 Architecture probes

#### D1 / D4 -- shared JSON: resolved

D1 is **PASS qualified** and D4 is **NO API addition required**.

Required bridge constraints:

- managed encoding uses `ensure_ascii=False`;
- native array construction uses `list[any]` plus `.append()`;
- cross-code-space fixtures cover Unicode, nested values, every tagged variant,
  and malformed input.

#### D2 -- native polymorphism: pending

Probe:

- heterogeneous component collection;
- overridden render/input dispatch;
- mutation and invalidation;
- repeated rendering;
- focus replacement;
- removal and destruction.

Pass selects a Pi-like `Component` interface. Any lifecycle/dispatch failure
selects explicit tagged `ComponentNode` dispatch behind the same conceptual TUI
interface. Opaque pointer tricks are forbidden.

#### E1 -- embed ownership/lifecycle: pending

Characterize the current fused adapter through:

- successful boot/bind/dispose;
- failure after each partial startup milestone;
- Python exception during every callable;
- returned-string ownership after reference release;
- native idle polling while managed worker makes progress;
- repeated `release()`/shutdown;
- disposal timeout with safe `Py_Finalize` suppression.

Outcome:

- if native Jac can reliably enforce the ownership rules, implement
  `EmbedRuntime` in `.na.jac`;
- otherwise place a narrow first-party C/Zig lifecycle shim behind the same
  `EmbedRuntime` interface;
- either result stays in one OS process and does not change callers.

#### D3 -- pipe partial I/O: retired

No pipe exists in the target architecture. Keep any existing notes as historical
architecture evidence; do not spend Phase 0 time building this probe.

### Phase 0 exit gate

- every characterization test has a wall-clock deadline;
- supported behavior has a trace, semantic test, or explicit exception;
- width validity is known independently of goldens;
- performance baseline is reproducible;
- D2 dispatch is decided by an executable probe;
- embed resource/worker/GIL ownership is inventoried;
- E1 selects native-only adapter implementation or the narrow lifecycle shim.

---

## 4. Condensed per-phase gates

| Phase | Exit gate |
|---|---|
| 0 | Baseline captured; D2 decided; E1 selects enforceable embed ownership implementation |
| 1 | Rejected/busy prompt creates no user row; accepted prompt creates exactly one; `stopping` is typed; tty restores before cleanup waits |
| 2 | Every current event maps or fails loudly; Unicode bridge fixtures pass; malformed value cannot partially mutate state; gap/overflow requests one snapshot; `agent_settled` is exactly-once |
| 3 | Sequential sessions share no ledger/queue/model/subscription/cancellation state; disposal joins or reports timeout; replacement recreates cwd services |
| 4 | Full TUI flow works through `EmbedSessionClient`; only `EmbedRuntime` imports CPython/GIL symbols; returned values are owned; queue and memory stay bounded |
| 5 | Generic TUI imports no agent/embed code; reducer owns mutation; injected-input focus tests pass; every visible row obeys width invariants |
| 6 | Recoverable PTY exits restore terminal; worker/finalization checks pass; no `_frame_blob`, positional parser, mirrored schema, module-global adapter state, or `id=-1` row remains in production |
| 7 | Linux/macOS release suites pass where supported; offline clean-home launch performs no compilation; one long-lived fused TUI process is observed; performance budget is reviewed |
| 8 | Separately reviewed persistence/privacy/migration gates pass; not required for Phase 7 |

---

## 5. Decision log

| ID | Decision | Status | Consequence |
|---|---|---|---|
| T1 | Product topology | **Resolved: single-process** | Keep `execve` + native host + embedded CPython; no renderer child |
| D1 | Shared dual-code-space bridge schema | **PASS qualified** | Use complete JSON values with raw UTF-8 constraints |
| D2 | `Component` virtual dispatch vs. tagged `ComponentNode` | **Resolved: virtual Component** | Phase 5 uses `override def` components |
| D3 | Pipe partial I/O implementation | **Retired** | No process transport, so no probe or dependency |
| D4 | Add public native JSON `loads`/`dumps` | **Resolved: no** | Already public since #6950 |
| E1 | `.na.jac` embed lifecycle vs. narrow C/Zig shim | **Resolved: `.na.jac` EmbedRuntime** | Shim only if later ownership failures are measured |
| P1 | File-backed session persistence | **Deferred product decision** | Use `SessionManager.in_memory()` through core cutover |

---

## 6. Ready-to-start work after Phase 0-4

Completed:

1. ~~Phase 0~~ → `plans/phase0/` + D2/E1 probes
2. ~~Phase 1 correctness~~ → stopping, pending submit, no `id=-1`, terminal-first quit
3. ~~Phase 2 typed models~~ → `bridge_schema`, `session_models`, `UiEventProjector`,
   `TuiEventQueue`, legacy normalizer, `test_ai_tui_phase2.jac`
4. ~~Phase 3 instance ownership~~ → `AgentRun` rename, `SessionManager.in_memory()`,
   `AgentSession` / `AgentSessionRuntime`, `TuiSessionAdapter`, embed facade,
   `test_ai_tui_phase3.jac`
5. ~~Phase 4 embed seam~~ → `EmbedRuntime` / `EmbedSessionClient`, typed
   start/submit/poll/snapshot/dispose bridge, GIL ownership concentrated,
   `finalize_if_safe` skip-on-timeout, `test_ai_tui_phase4.jac`
6. ~~Phase 5 Pi-style TUI~~ → `tui/` + `components/` (virtual `Component`,
   ProcessTerminal, frame width validation), reducer + focus routing,
   `InteractiveApp`, import-purity gate, `test_ai_tui_phase5.jac`
7. ~~Phase 6 lifecycle + legacy deletion~~ → `session_dispatch.na.jac`,
   acceptance-before-mutation, no `_frame_blob`/CmdQueue round-trip in embed path,
   `test_ai_tui_phase6.jac`
8. ~~Phase 7 offline packaged release~~ → fused `jac-ai-tui` boot gates,
   `test_ai_tui_phase7.jac`

Completed (this revision):

1. Session effects seam: `session_dispatch.na.jac` + `selftest_session_client.na.jac`
2. `EmbedSessionClient` typed submit/settle; legacy `_dispatch_legacy_cmd` removed
3. `AgentSession._try_legacy_send()` acceptance-before-mutation for non-stub prompts

Next:

1. Performance budget review (`plans/phase0/perf/BASELINE.md`)

D1/D4 need no more probing. D3 should not be implemented.

### dlopen dev path (not shipped)

The ctypes in-process experiment (`JAC_AI_TUI_BACKEND=inprocess`) is a
development-only alternate topology documented in
`plans/experiments/in-process-flip.md`. It is **not** the packaged `execve`
product path.

| Surface | Shipped embed (`execve` → `host_embed`) | dlopen dev (`inprocess`) |
|---|---|---|
| Loop owner | native `tui_loop` + `EmbedSessionClient` | Python `run_tui_in_process` |
| Session seam | typed `apply_effects_rt` → `session.submit_*` | `PythonSessionBridge.submit_*` |
| Native→host cmds | none (no CmdQueue round-trip) | `CmdQueue` string verbs via `tui_next_command` |
| Verb dispatch | n/a | `PythonSessionBridge.dispatch_legacy_cmd` maps `SEND:`/`STOP:`/… to typed submit |

`host_dlopen.na.jac` and `python_session_bridge.dispatch_legacy_cmd` intentionally
retain the `cmd_queue` string bridge for the ctypes renderer. Removing it is a
dlopen-experiment follow-up, not a Phase 6/7 release gate.

### PTY harness (characterization, not structural gate)

`plans/phase0/pty/harness.py` records deadline-bounded terminal scenarios and
writes JSON under `plans/phase0/pty/results/`. It qualifies recoverable exits
when run manually or via opt-in CI (`JAC_AI_TUI_PTY_HARNESS=1`).

Structural tests (`test_ai_tui_phase*.jac`, native selftests, bridge/unit suites)
do **not** depend on PTY harness success. Signal/EOF scenarios are
characterize-only; segfaults on a given platform are tracked evidence, not
suite blockers.

### Phase 8 persistence (deferred)

File-backed JSONL sessions, branch UI, compaction, and retention policy remain
**out of scope** for the Phase 7 release. `SessionManager.in_memory()` is the
production default until a separate product review approves persistence,
privacy, and migration gates (see `PLAN.md` Phase 8). No Phase 8 implementation
work is scheduled on the release critical path.

---

## 7. Scope controls

Do not pull these into the core cutover:

- renderer subprocess or remote transport;
- automatic restart after fatal native/interpreter failure;
- durable sessions, branch UI, compaction UI, or retention policy;
- general retirement of `libjacpyembed` or desktop embedding;
- native execution of extension code;
- speculative zero-copy shared mutable event structures;
- broad renderer cache redesign without profiling evidence.

The core release is complete at Phase 7 with in-memory sessions if all fused
correctness, lifecycle, TUI, packaging, and performance gates pass.
