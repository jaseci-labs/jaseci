# Implementation Plan - TUI Orchestration Recut (Part 2)

## Goal

Complete the remaining architectural recut so `AgentSession` is the sole non-stub session owner, events flow through one serialized mailbox, native snapshot recovery preserves part semantics, production runs `InteractiveApp → Tui → ProcessTerminal`, bridge constants are generated from one manifest, and tests exercise behavior through the host seam rather than source-string guards.

## Current baseline (do not re-implement)

| Concern | Status |
|---------|--------|
| Wire seq after coalescing | Done - `event_queue.jac:99-107` |
| Batch epoch/seq validation | Done - `session_apply.na.jac:124-246` |
| Prompt send before ledger append | Done - `agent_session.jac:256-290` |
| Dispose order (`ui_stop` before adapter dispose) | Done - `embed_agent.jac:383-404` |
| Snapshot staging (no clear-before-validate) | Done - `session_apply.na.jac:279-308` |

---

## Dependency graph

```text
Item 1 (single owner)
  └─► Item 2 (serialized mailbox)
        └─► Item 3 (snapshot part equivalence)
              └─► Item 4 (InteractiveApp production cutover)
                    └─► Item 6 (behavior tests)

Item 5 (schema codegen) ── parallel with 1→2→3 chain ──► Item 6
```

**Execution order:** `1 → 2 → 3 → 4` (sequential, one writer); `5` in parallel; `6` last.

---

## Item 1 - Single real session owner

### Design decision

**AgentSession owns the provider turn thread; `ai_agent` exposes a threadless prepare API.**

Do **not** keep calling `ui_send()` from the embed path - it spawns an untracked daemon thread (`impl/ai_agent.impl.jac:2224-2238`). Instead:

1. Add **`ui_prepare_turn(text: str) -> bool`** in `ai_agent.jac` / `impl/ai_agent.impl.jac` that performs everything `ui_send` does **except** starting a thread: lock, busy check, `begin_turn()`, emit user on bus, `set_status("running")`, return `True`.
2. Add **`ui_finish_turn_cleanup()`** (or inline in worker finally) mirroring `_ui_turn_worker`'s post-`run_turn` idle/cancel handling (`impl/ai_agent.impl.jac:2215-2221`).
3. In **`AgentSession._submit_prompt`** (non-stub): replace `_try_legacy_send` with `_prepare_and_start_turn`:
   - Call `ui_prepare_turn(text)`; reject if false.
   - Spawn **`Thread(target=self._real_turn, args=(text,), daemon=False)`**, append to `_workers`.
4. **`_real_turn(text)`** calls `run_turn(text)` (already declared in `ai_agent.jac:364`), then `ui_finish_turn_cleanup()` in `finally`.
5. Keep **`_legacy_feed`** as the sole bus→mutation subscriber (unchanged role); remove duplicate lifecycle sync that races with feed where possible - after turn ownership moves, `_submit_prompt` should **not** double-emit `MUT_AGENT_START` / user rows that `_legacy_feed` will also produce from bus frames. **Emit ledger + bridge mutations from one side only:** prefer feed-driven mutations for non-stub; AgentSession only sets lifecycle gates and starts the owned turn thread.
6. **`dispose()`** path: call `ui_stop()` first (already in embed dispose), then join **all** `_workers` including turn thread; only then return `DisposeResult`. Turn thread must observe `self._stop` / `cancel_requested` and exit promptly when aborted.
7. Leave **`ui_send`** in place for non-TUI callers but document it as legacy; optionally make it call `ui_prepare_turn` + daemon thread for backward compat **outside** embed path only.

**Stub mode:** unchanged - stub turn thread already in `_workers`.

### Files

| Action | Path |
|--------|------|
| Edit | `jac/jaclang/cli/ai_agent.jac` - declare `ui_prepare_turn`, `ui_finish_turn_cleanup` |
| Edit | `jac/jaclang/cli/impl/ai_agent.impl.jac` - implement prepare/finish; refactor `ui_send` to use prepare + daemon (non-embed legacy) |
| Edit | `jac/jaclang/cli/ai_tui/core/agent_session.jac` - `_real_turn`, `_prepare_and_start_turn`, dedupe emissions, track turn thread |
| Edit | `jac/jaclang/cli/ai_tui/embed_agent.jac` - no logic change if dispose order already correct; verify `mark_workers_safe` reflects joined turn thread |
| Edit | `jac/jaclang/cli/ai_tui/python_session_bridge.jac` - same dispose contract as embed_agent |

### Subtasks

1. Implement `ui_prepare_turn` / `ui_finish_turn_cleanup` with unit-level parity to current `ui_send` / `_ui_turn_worker` (busy reject, begin_turn, user emit, running status, idle settle, cancel path).
2. Add `AgentSession._real_turn` non-daemon worker; wire `_submit_prompt` non-stub path.
3. Audit mutation duplication: run stub + real-turn integration mentally against `_legacy_feed` + `legacy_event_normalizer.jac`; remove redundant `_publish(MUT_MESSAGE_START user)` from submit if feed emits it.
4. Extend `AgentSession.dispose` to call `ui_stop()` before joining workers (mirror embed layer - defense in depth).
5. Add managed test: **`test_agent_session_owns_turn_thread`** - mock `run_turn` to block on Event; dispose joins within deadline; `workers_safe` false if turn still alive.

### Acceptance

- Non-stub prompt path: exactly one non-daemon turn thread in `_workers`; no `daemon=True` thread spawned from embed submit path.
- `AgentSession.dispose(deadline_ms=2000)` joins turn thread; `DisposeResult.timed_out=False` when turn completes normally.
- `embed_agent.dispose` → `mark_workers_safe(True)` only after turn thread joined.
- Existing tests pass: `test_ai_tui_phase3.jac`, `test_ai_tui_phase6.jac` ("managed session busy reject"), `test_ai_tui_roundtrip.jac`, `test_ai_tui_contract.jac`.

### Risks / rollback

- **Risk:** Removing duplicate user-row emit breaks transcript if feed is slow. **Mitigation:** keep optimistic user row in AgentSession *or* feed-only, not both; add roundtrip test.
- **Risk:** `run_turn` + feed double-settle idle. **Mitigation:** `_legacy_feed` already gates on bus status; add assertion in phase3 lifecycle test.
- **Rollback:** Revert to `_try_legacy_send` + daemon `ui_send`; keep new APIs unused.

---

## Item 2 - One serialized mailbox / event path

### Design decision

**All projector + queue mutations run on a single adapter-owned dispatcher thread.**

Today `_on_runtime_event` in `TuiSessionAdapter` (`tui_session_adapter.jac:104-131`) is invoked from multiple threads: `_legacy_feed`, stub turn threads, and submit path via `_publish`. Projector internal seq (`ui_event_projector.jac:63-65`) is still updated concurrently even though wire seq is post-coalesce.

Introduce **`SessionEventDispatcher`** (new managed module):

```text
enqueue(raw: UiMutation)   # thread-safe; called from AgentSession/_fanout
close()
run_until(stop: Event)     # loop: dequeue → projector.apply → queue.submit
```

- `TuiSessionAdapter.start`: spawn **`_dispatcher_thread`** (non-daemon, tracked for dispose).
- Replace direct `_on_runtime_event` listener with `dispatcher.enqueue`.
- **`TuiSessionAdapter.dispose`**: `dispatcher.close()` → join dispatcher thread → then runtime dispose.
- **Projector + queue touched only on dispatcher thread** - removes projector seq races and satisfies PLAN.md §6.3 single-owner invariant.

Native side unchanged (already validates wire seq); managed side must not assign wire seq before enqueue.

### Files

| Action | Path |
|--------|------|
| **New** | `jac/jaclang/cli/ai_tui/session_event_dispatcher.jac` |
| Edit | `jac/jaclang/cli/ai_tui/tui_session_adapter.jac` - wire dispatcher, remove inline `_on_runtime_event` projector calls |
| Edit | `jac/jaclang/cli/ai_tui/core/agent_session_runtime.jac` - optional: fanout goes to adapter listener only (no change if adapter subscribes at runtime boundary) |
| Edit | `jac/jaclang/cli/ai_tui/ui_event_projector.jac` - clarify/restrict: `apply()` only from dispatcher (comment + debug assert in dev) |

### Subtasks

1. Implement `SessionEventDispatcher` with `queue.Queue` (or `collections.deque` + Lock) and poison-pill shutdown.
2. Move projector/queue logic from `_on_runtime_event` into dispatcher consumer; keep snapshot_required / ValueError → `queue.require_snapshot` behavior identical.
3. Join dispatcher in `TuiSessionAdapter.dispose` before `runtime.dispose`.
4. Add test **`test_dispatcher_serializes_projector`**: two threads enqueue 100 mutations; drained wire seqs are contiguous with no gaps.

### Acceptance

- Thread sanitizer / stress test: no concurrent `projector.apply` calls.
- Phase 2 queue coalesce tests still pass.
- Dispose joins dispatcher before feed/turn threads released.

### Risks / rollback

- **Risk:** Dispatcher backlog latency on hot paths. **Mitigation:** coalescing still happens in `TuiEventQueue` after projector; dispatcher should be lightweight.
- **Rollback:** Keep synchronous `_on_runtime_event` with a big Lock (interim only - document as unacceptable long-term).

---

## Item 3 - Snapshot equivalence (part_type / role preservation)

### Design decision

**Emit one native `Event` per snapshot message part, mapping `part_type` → `EventKind`.**

Replace flattening in `_events_from_snapshot_messages` (`session_apply.na.jac:250-275`):

| `part_type` (wire) | `EventKind` | Notes |
|--------------------|-------------|-------|
| `text` + role `user` | `USER` | |
| `text` + role `assistant` | `ANSWER` | |
| `thinking` | `REASONING` | |
| `tool_call` | `CALL` | use `tool_name` in `node` |
| `tool_result` | `TOOL_RESULT` | |
| image / `image_ref` | `IMG` | text = ref or placeholder |

**Event IDs:** derive stable int ids: `base = _msg_id(message.id) * 100 + part_index` (document max parts ≤ 99) to avoid upsert collisions between parts of the same message.

**Roles:** do not collapse multi-part messages; order parts as listed in snapshot JSON (matches `embed_agent.snapshot` part order).

### Files

| Action | Path |
|--------|------|
| Edit | `jac/jaclang/cli/ai_tui_na/session_apply.na.jac` - `_part_to_event`, rewrite `_events_from_snapshot_messages` |
| **New** | `jac/jaclang/cli/ai_tui_na/selftest_snapshot_apply.na.jac` - build synthetic snapshot dict in-process, apply, assert event kinds/counts |
| Edit | `jac/jaclang/cli/ai_tui_na/build_unit_selftests.sh` - register `selftest_snapshot_apply` |
| Edit | `jac/tests/cli/tui_selftest_harness.jac` - add harness name |

### Subtasks

1. Implement `_part_kind(part_type, role) -> EventKind` helper mirroring `apply_mutation` + `legacy_event_normalizer.jac` mappings.
2. Build `selftest_snapshot_apply.na.jac` with fixture: user text + assistant text + thinking + tool_call + tool_result + image parts.
3. Add pytest wrapper `test_snapshot_apply_preserves_parts` calling harness.
4. Extend `test_ai_tui_roundtrip.jac` snapshot assertions to check multi-part structure where stub provides it.

### Acceptance

- Selftest prints `PASS` for each part kind.
- After forced `MUT_SNAPSHOT_REQUIRED` + snapshot reload, tool rows still render as CALL/TOOL_RESULT (manual or PTY smoke).
- Invalid snapshot still leaves state untouched (existing staging test).

### Risks / rollback

- **Risk:** Event id scheme clashes with live incremental ids. **Mitigation:** snapshot path calls `state.reset_events()` first; ids only need internal consistency until next mutation.
- **Rollback:** Keep flattening; document known regression.

---

## Item 4 - Production cutover to `InteractiveApp → Tui → ProcessTerminal`

### Design decision

**Both production hosts run the same `InteractiveApp` loop; `ProcessTerminal` is the sole tty owner.**

#### TuiRuntime collapse

Reduce `TuiRuntime` (`runtime.na.jac`) to:

```text
state: TuiState
tui: Tui          # owns screen, frame_renderer, ProcessTerminal
session: EmbedSessionClient | None
embed: EmbedRuntime | None
transport: EmbedPyTransport
cmd_queue: CmdQueue
```

Remove duplicate `screen`, `diff`, `paint_buf` from `TuiRuntime` - `Tui.frame` already wraps `FrameRenderer` (`tui/tui.na.jac`). Migrate any `rt.screen`/`rt.diff` references to `rt.tui.screen` / `rt.tui.frame`.

#### host_embed.na.jac (execve product path)

Replace `tui_loop_once` loop with:

```text
app = InteractiveApp()
rt = TuiRuntime()  # or app holds state directly
_bind(app, embed, session, transport, state)
if app.tui.terminal.open_tty() < 0: ... error path ...
app.tui.enter_screen()
try:
    app.run()  # or while app.step(50).cont
finally:
    app.shutdown()  # → tui.stop() → ProcessTerminal.close_tty()
    session.dispose(...)
    embed.finalize_if_safe()
```

**Delete direct `tty_open`/`tty_close`** from `host_embed.na.jac:109-123`.

#### host_dlopen.na.jac (in-process ctypes path)

Refactor module-global `host_rt` to include **`host_app: InteractiveApp`** (or embed InteractiveApp inside TuiRuntime):

| Export | New implementation |
|--------|-------------------|
| `tui_init` | populate state, `host_app.tui.terminal.open_tty()`, `enter_screen` |
| `tui_wait_key` | `tty_poll` only (unchanged - lock-free) |
| `tui_handle_key` | `host_app.inject_key(parse_key(...))` |
| `tui_render` | `host_app.tui.paint_once()` |
| `tui_shutdown` | `host_app.shutdown()` |
| `tui_apply_batch` / `tui_apply_snapshot` | unchanged (session state mutations) |

Remove dependency on `tui_core.tui_enter_screen` / `tui_leave_screen` / `tui_render_once` / `tui_sync_size` from production paths.

#### Deletions (after parity)

| Delete or deprecate | Condition |
|---------------------|-----------|
| `tui_loop.na.jac` | No imports remain |
| `tui_core.na.jac` functions: `tui_enter_screen`, `tui_leave_screen`, `tui_render_once`, `tui_sync_size` | Move `tui_populate_state`, `tui_seed_agent_meta` to `host_bootstrap.na.jac` or keep as thin helpers |
| `input.na.jac` `handle_key` production use | Keep for `selftest_dispatch.na.jac` OR re-point selftest to `InteractiveApp.inject_key` |

**Parity checklist before deletion:** quit, ctrl-g stop, ctrl-r reset, prompt send, overlay, resize, session drain, backend-dead error, terminal restore on exit.

### Files

| Action | Path |
|--------|------|
| Edit | `jac/jaclang/cli/ai_tui_na/host_embed.na.jac` |
| Edit | `jac/jaclang/cli/ai_tui_na/host_dlopen.na.jac` |
| Edit | `jac/jaclang/cli/ai_tui_na/interactive_app.na.jac` - add `startup()`/`shutdown()` helpers; bind `rt.tui.screen` if needed |
| Edit | `jac/jaclang/cli/ai_tui_na/runtime.na.jac` |
| Edit | `jac/jaclang/cli/ai_tui_na/tui/tui.na.jac` - ensure overlay compositing matches old `tui_render_once` (port overlay compose from `tui_core.na.jac:89-108` into `Tui.paint_once` if missing) |
| Edit | `jac/jaclang/cli/ai_tui_na/tui_core.na.jac` - strip to bootstrap helpers only |
| Delete | `jac/jaclang/cli/ai_tui_na/tui_loop.na.jac` (final step) |
| Edit | `jac/tests/cli/test_ai_tui_bridge.jac` - update teardown order assertions for InteractiveApp shutdown |

### Subtasks

1. Port overlay composite into `Tui.paint_once` (compare `tui_core.tui_render_once` vs current `Tui.paint_once` - overlay path may be missing in production Tui).
2. Collapse `TuiRuntime` fields; fix compile errors across hosts/selftests.
3. Rewire `host_embed.na.jac` to InteractiveApp; verify `--stub` smoke.
4. Rewire `host_dlopen.na.jac` exports; verify `test_ai_tui_in_process.jac`.
5. Run PTY harness (`plans/phase0/pty/harness.py --recoverable --deadline 90`); fix regressions.
6. Delete procedural loop files; update `build_embed.sh` / `_stage_modules.sh` module lists.

### Acceptance

- `grep -r "tui_loop_once\\|tty_open()" jac/jaclang/cli/ai_tui_na/*.na.jac` (excluding `process_terminal.na.jac`, `libc_tty*`) returns empty.
- `ProcessTerminal` is the only module calling `tty_close` on the production render fd.
- `test_ai_tui_bridge.jac` teardown-order test passes (leave_screen before tty close before dispose).
- `test_ai_tui_in_process.jac` passes.
- Phase 6 PTY test passes or skips only on known platform segfault.

### Risks / rollback

- **Risk:** `host_dlopen` ABI break for Python ctypes host. **Mitigation:** keep export names stable; change internals only.
- **Risk:** Missing overlay in Tui paint. **Mitigation:** subtask 1 explicit diff.
- **Rollback:** Feature flag `JAC_AI_TUI_LEGACY_LOOP=1` guard around old loop for one commit cycle (remove before merge).

---

## Item 5 - Generate bridge schemas from one manifest (parallel track)

### Design decision

**JSON manifest + small Python generator invoked by build scripts.**

Create **`jac/jaclang/cli/ai_tui/bridge_schema.manifest.json`**:

```json
{
  "schema_id": "jac.ai_tui.bridge.v1",
  "cmd_kinds": { "CMD_KIND_PROMPT": "prompt", ... },
  "dispositions": { ... },
  "lifecycles": { "LIFE_STARTING": "starting", ... },
  "mutations": { "MUT_RUNTIME_REPLACED": "runtime_replaced", ... }
}
```

Add **`scripts/gen_bridge_schema.py`** (or `jac/jaclang/cli/ai_tui/gen_bridge_schema.py`):

- Emits `bridge_schema.jac` (managed - full encode/decode helpers preserved from template sections).
- Emits `bridge_schema.na.jac` (native - same constants + native coercions).
- Generator copies static helper bodies from `.template.jac` / `.template.na.jac` fragments to avoid rewriting encode/decode logic each run.

Wire into:

- `ai_tui_na/build_embed.sh` - run generator before `_stage_modules.sh`
- `ai_tui_na/build_unit_selftests.sh`
- Optional: pre-commit hook or `test_bridge_schema_generated` that fails if outputs drift from manifest.

Update native consumers:

- `session_apply.parse_tui_status` - handle all `LIFE_*` values (map `starting`/`quiescing`/`disposed`/`failed` explicitly).
- `session_apply._known_mutation_kind` - add `MUT_RUNTIME_REPLACED`; handle in `apply_mutation` (epoch bump + `state.reset_events()` or no-op with layout dirty - match managed projector semantics).

### Files

| Action | Path |
|--------|------|
| **New** | `jac/jaclang/cli/ai_tui/bridge_schema.manifest.json` |
| **New** | `jac/jaclang/cli/ai_tui/gen_bridge_schema.py` |
| **New** | `jac/jaclang/cli/ai_tui/bridge_schema.shared.template.jac` (optional split) |
| Regenerate | `bridge_schema.jac`, `ai_tui_na/bridge_schema.na.jac` |
| Edit | `ai_tui_na/session_apply.na.jac` - full lifecycle map + runtime_replaced |
| Edit | `ai_tui_na/build_embed.sh`, `build_unit_selftests.sh` |
| Edit | `jac/tests/cli/test_ai_tui_contract.jac` - replace manual string drift scan with "generated" marker test |

### Subtasks

1. Extract current constants from both schema files into manifest (single source).
2. Write generator; run once and diff-verify zero behavior change except adding missing constants to native.
3. Extend `parse_tui_status` + `_known_mutation_kind`.
4. Add `test_bridge_schema_matches_manifest` (loads manifest, compares to imported Python constants).

### Acceptance

- `diff bridge_schema.jac bridge_schema.na.jac` constant sections match manifest keys/values.
- `test_ai_tui_contract.jac` drift test passes without reading `.na.jac` source strings.
- Native decode of `runtime_replaced` mutation does not force spurious snapshot.

### Risks / rollback

- **Risk:** Generator breaks native template syntax. **Mitigation:** run `build_unit_selftests.sh` + `selftest_start_decode` in CI.
- **Rollback:** Keep manifest but stop codegen; manual sync (interim).

---

## Item 6 - Replace source-string tests with behavior tests (last)

### Design decision

**Keep structural guardrails that are cheap; convert seam assertions to selftests and import-and-call tests.**

| Test file | Replace | Keep as source guard |
|-----------|---------|----------------------|
| `test_ai_tui_session_effects.jac` | Extend `selftest_session_client.na.jac` or add `selftest_session_dispatch.na.jac` exercising `apply_effects_rt` with mock session recorder | - |
| `test_ai_tui_phase5.jac` | Add `selftest_interactive_app.na.jac`: `inject_key` → editor/quit effects; pytest calls harness | Import purity scan (`_forbidden_import`) - legitimate static guard |
| `test_ai_tui_phase6.jac` | Already has behavior test for busy reject; replace remaining `assert "X" in src` with: (a) `selftest_dispatch` PASS for session path, (b) import `session_dispatch` + call with mock | Legacy frame scan (`_frame_blob`) - keep |
| `test_ai_tui_phase7.jac` | Keep artifact/boot tests; replace `assert "os.execve" in text` with subprocess smoke already present; drop redundant impl string checks covered by smoke | `--help` subprocess test - keep |

### New / extended selftests

| Selftest | Proves |
|----------|--------|
| `selftest_session_dispatch.na.jac` | SEND/STOP/RESET/APPLY/QUIT effects route to session client when `session.started` |
| `selftest_interactive_app.na.jac` | `inject_key(Enter)` → send effect; ctrl-c → quit |
| `selftest_snapshot_apply.na.jac` | (from item 3) part preservation |

### Files

| Action | Path |
|--------|------|
| **New** | `ai_tui_na/selftest_session_dispatch.na.jac`, `selftest_interactive_app.na.jac` |
| Edit | `test_ai_tui_session_effects.jac`, `test_ai_tui_phase5.jac`, `test_ai_tui_phase6.jac`, `test_ai_tui_phase7.jac` |
| Edit | `build_unit_selftests.sh`, `tui_selftest_harness.jac` |

### Subtasks

1. Implement selftests (PASS/FAIL lines pattern matching `selftest_dispatch.na.jac`).
2. Replace source-string tests one file at a time; ensure CI green after each.
3. Document in `plans/SCOPE.md` that phase5/6 structural import scans are intentional guardrails.

### Acceptance

- Count of `assert "..." in *_src` in phase5/6/7/session_effects ≤ 5 total (down from ~29).
- All selftests registered in harness pass via pytest.
- No regression in preserved tests listed in task constraints.

### Risks / rollback

- **Risk:** Selftests miss ctypes/dlopen path. **Mitigation:** keep `test_ai_tui_in_process.jac` as integration backstop.

---

## Files to Modify (summary)

| Path | Items |
|------|-------|
| `ai_agent.jac`, `impl/ai_agent.impl.jac` | 1 |
| `ai_tui/core/agent_session.jac` | 1 |
| `ai_tui/session_event_dispatcher.jac` (new) | 2 |
| `ai_tui/tui_session_adapter.jac` | 2 |
| `ai_tui_na/session_apply.na.jac` | 3, 5 |
| `ai_tui_na/host_embed.na.jac`, `host_dlopen.na.jac` | 4 |
| `ai_tui_na/interactive_app.na.jac`, `runtime.na.jac`, `tui/tui.na.jac` | 4 |
| `ai_tui_na/tui_core.na.jac`, `tui_loop.na.jac` (delete) | 4 |
| `ai_tui/bridge_schema.manifest.json`, `gen_bridge_schema.py` | 5 |
| `bridge_schema.jac`, `bridge_schema.na.jac` | 5 |
| `tests/cli/test_ai_tui_phase*.jac`, `test_ai_tui_session_effects.jac` | 6 |

## New Files (summary)

- `jac/jaclang/cli/ai_tui/session_event_dispatcher.jac`
- `jac/jaclang/cli/ai_tui/bridge_schema.manifest.json`
- `jac/jaclang/cli/ai_tui/gen_bridge_schema.py`
- `jac/jaclang/cli/ai_tui_na/selftest_snapshot_apply.na.jac`
- `jac/jaclang/cli/ai_tui_na/selftest_session_dispatch.na.jac`
- `jac/jaclang/cli/ai_tui_na/selftest_interactive_app.na.jac`

## Dependencies

| Task | Depends on |
|------|------------|
| 2 | 1 (turn/feed threads must not call disposed projector) |
| 3 | 2 optional but recommended (snapshot apply race-free) |
| 4 | 1, 2 (production loop assumes safe dispose + session path) |
| 5 | none (parallel) |
| 6 | 4, 5 (tests target final production seams) |

## Risks (cross-cutting)

1. **Concurrent dispose vs feed** - ordering must be: stop accept → ui_stop → join turn → join feed → join dispatcher → dispose runtime.
2. **Native staging** - every native edit requires `build_embed.sh` / `build_unit_selftests.sh`; do not rely on bare `jac check` for `.na.jac`.
3. **Dual host parity** - embed and dlopen must stay aligned; consider shared `host_run.na.jac` helper to avoid drift.
4. **SCOPE.md claims** - update `plans/SCOPE.md` reality-check table after item 4 lands; several rows currently say "Closed" prematurely.

## Validation commands (run after each item)

```bash
cd jac && python -m pytest tests/cli/test_ai_tui_phase2.jac tests/cli/test_ai_tui_phase3.jac \
  tests/cli/test_ai_tui_phase4.jac tests/cli/test_ai_tui_bridge.jac \
  tests/cli/test_ai_tui_contract.jac tests/cli/test_ai_tui_roundtrip.jac \
  tests/cli/test_ai_tui_native_decode.jac tests/cli/test_ai_tui_in_process.jac -q

cd jac/jaclang/cli/ai_tui_na && ./build_unit_selftests.sh && ./build_embed.sh
```

## Per-item one-liner summary

1. **Single owner:** `ui_prepare_turn` + AgentSession-owned non-daemon `run_turn` thread; no embed-path `ui_send` daemon.
2. **Serialized mailbox:** `SessionEventDispatcher` thread exclusive for projector+queue.
3. **Snapshot equivalence:** one `Event` per part with `part_type`→`EventKind` mapping.
4. **Production cutover:** `host_embed` + `host_dlopen` run `InteractiveApp`; `ProcessTerminal` sole tty owner; delete procedural loop.
5. **Schema codegen:** manifest-driven `bridge_schema.jac` + `.na.jac`; native learns full lifecycle + `runtime_replaced`.
6. **Behavior tests:** selftests for dispatch/InteractiveApp/snapshot; strip source-string assertions from phase5/6/7.
