# SV_DEPLOY_DIAL_PLAN.md - the `[sv] deploy` dial for the Android/Compose target

> Sibling to `PLAN.md`. This plan turns the *where do the walkers run* question into
> a single `jac.toml` dial with three settings - `remote`, `device`, `local-first` -
> for the Compose/Android target. It is written for an implementer who has **not**
> seen this codebase; every task names the exact file, the exact function, and a
> concrete acceptance check. Read `PLAN.md` first for the umbrella Compose roadmap.
>
> **Status: design only. Nothing here is built.** Phases are ordered so each one
> ships independently and never breaks the previous one. Do phases in order. Do not
> skip ahead - Phase 2 is meaningless without Phase 1's abstraction seam in place.

---

## 0. The one insight

`cl` (UI) code calls a walker the same way no matter where it runs:

```jac
add_todo(title=draft);      # a walker call - a write
todos = list_todos();       # a walker call - a read
```

Today that call is **hard-wired to run remotely over HTTP**. The whole project is:
make the *destination* of that call a build-time choice, and supply the two
destinations that don't exist yet (on-device, and on-device-with-background-sync).

The UI code never changes across the three modes. Only one `jac.toml` stanza and
the generated Kotlin plumbing behind the call change.

---

## 1. Current reality - exactly what exists today (verified in the tree)

Trace one walker call from Jac to the wire:

1. **`cl` calls a walker.** In `compiler/passes/compose/impl/jac_to_kotlin.impl.jac`,
   `JacToKotlin._convert_spawn` (≈ line 655) lowers a walker spawn to a Kotlin call:

   ```kotlin
   JacClient.add_todo(AddTodoRequest(title = draft), nodeId = ...)
   ```

   **`JacClient` is the only backend, and it is named literally, inline.** This is
   the single line the whole abstraction hinges on.

2. **`JacClient` is generated Kotlin.** `compiler/passes/compose/rpc_client.jac`
   + `impl/rpc_client.impl.jac`, function `emit_jac_client(package_name, manifest)`,
   emits a Kotlin `object JacClient` whose `call()` does an `HttpURLConnection` POST
   to `baseUrl + "/walker/" + walker`. It also emits one `@Serializable data class`
   per walker request/response (`AddTodoRequest`, `AddTodoResponse`, …). **This is
   the `remote` backend already - it just isn't *called* remote, and isn't
   swappable.**

3. **The walker shapes come from the manifest.**
   `model.intent.interop_manifest` is an `InteropManifest`
   (`jac0core/codeinfo.jac`, line 538) carrying:
   + `walker_access: dict[str, bool]` - which walkers are client-callable,
   + `boundary_types: dict[str, BoundaryTypeInfo]` - request/response field shapes,
   + `bindings: dict[str, InteropBinding]` - param names/types per walker,
   + `endpoint_effects: dict[str, dict]`.
   Emitted into the model by `AndroidTarget._attach_interop_manifest` /
   `_merge_interop_manifest` in
   `runtimelib/client/targets/impl/android_target.impl.jac` (≈ lines 157–188).

4. **The emit.** `ComposeEmit.write`
   (`compiler/passes/compose/impl/compose_emit.impl.jac` ≈ line 553) writes
   `Screens.kt`, `JacClient.kt`, `JacMath.kt` into the Gradle app module.

### What is **NOT** built (the gap this plan fills)

+ **No on-device graph runtime.** There is no Kotlin/JVM object store for
  `node`/`edge`/anchors, no walker execution, no traversal (`-->`, `[root --> (?T)]`),
  no `spawn`/`report`/`visit`/`del` on device.
+ **No walker-body lowering.** The manifest carries walker *signatures* only. The
  ability *bodies* (`can go with root entry { ... }`) live in the `uni` AST and are
  never lowered for Android. `jac_to_kotlin` lowers plenty of Jac expression/statement
  semantics already, but has never been pointed at a walker body or the graph
  operators.
+ **No deploy dial.** `[sv] deploy` is not read anywhere.
+ **No persistence, no sync.**

The single most important consequence: **`device` and `local-first` require a
Jac→JVM execution path for walkers and the graph - "Seam 1" in the pitch. Phase 2 is
that seam. It is the bulk of the work. Phases 0–1 are cheap and unlock nothing new
by themselves, but they are the scaffold that makes Phase 2 tractable and keeps
`remote` working the entire time.**

---

## 2. Target architecture

Replace the single hard-wired `JacClient` object with a **`JacBackend` interface**
and swap the implementation at build time from the `[sv] deploy` value.

```
                       cl calls: JacBackend.current.add_todo(req)   ← unchanged forever
                                          │
                        interface JacBackend (generated, stable)
                                          │
      ┌───────────────────────┬───────────┴───────────────────────┐
      ▼                       ▼                                    ▼
 RemoteBackend           DeviceBackend                     LocalFirstBackend
 (today's JacClient,     (Phase 2: lowered walkers   (Phase 4: DeviceBackend
  HTTP → cloud)           over on-device JacGraph)     + oplog + WorkManager sync)
```

+ **Generated per build:** the `data class` request/response types (unchanged), the
  `JacBackend` interface, and exactly one concrete backend chosen by the dial.
+ **`JacBackend.current`** is a single `object` holder set once at app start.
+ **`cl` codegen change is one line:** `_convert_spawn` emits
  `JacBackend.current.<walker>(...)` instead of `JacClient.<walker>(...)`.

### The dial (`jac.toml`)

```toml
[sv]
deploy = "remote"        # DEFAULT. Emits RemoteBackend only. Today's behavior.

# deploy = "device"      # Emits DeviceBackend + JacGraph runtime + lowered walkers.
                         # No network. Graph persisted on the phone.

# deploy = "local-first"
# sync   = "https://my-server.example/"   # DeviceBackend + oplog + WorkManager sync.
```

Default is `remote` so **every existing project keeps compiling and behaving
exactly as before** until someone opts in.

---

## 3. Phases

### Phase 0 - read the dial (plumbing only, zero behavior change)

**Goal:** the config value flows from `jac.toml` to the emitter. Still always emits
`remote`. Nothing observable changes.

**Tasks**

+ **0.1** `runtimelib/client/targets/android/config.jac`: add

  ```jac
  def resolve_sv_deploy(project_dir: Path) -> str   # "remote" | "device" | "local-first"
  def resolve_sv_sync_url(project_dir: Path) -> str | None
  ```

  Read `[sv].deploy` (mirror `load_android_cfg`'s `JacConfig.load` pattern). Default
  `"remote"`. Validate against the three literals; on an unknown value raise a clear
  `RuntimeError` naming the allowed set. `resolve_sv_sync_url` reads `[sv].sync`.
+ **0.2** Carry it on the model. In `jac0core/codeinfo.jac`, on the intent model
  object (the one already holding `package_name`, `backend_url`, `interop_manifest` -
  see line ~600), add `has sv_deploy: str = "remote";` and
  `has sv_sync_url: (str | None) = None;`.
+ **0.3** `runtimelib/client/targets/android/config.jac` →
  `apply_android_cfg_to_model`: set `model.intent.sv_deploy = resolve_sv_deploy(...)`
  and `model.intent.sv_sync_url = resolve_sv_sync_url(...)`.
+ **0.4** `runtimelib/client/targets/impl/android_target.impl.jac`: in
  `_compile_compose_modules`, after `_attach_interop_manifest`, print the chosen mode
  in the existing summary line (`… , deploy=device`).

**Acceptance:** build the `compose_todo` example three times with each `deploy`
value. All three still produce today's output (RemoteBackend). The console reports
the mode. Add a unit test in `tests/compiler/test_compose_scaffold.jac` asserting
`resolve_sv_deploy` returns each of the three values and raises on garbage.

---

### Phase 1 - the `JacBackend` seam (refactor `remote` behind an interface)

**Goal:** introduce the interface and make today's HTTP client one implementation of
it. `remote` behavior is byte-for-byte equivalent (the network call is identical);
only the Kotlin *shape* changes. This is the seam Phase 2 plugs into.

**Tasks**

+ **1.1** Split `rpc_client.impl.jac`'s `_emit_jac_client_body` into three emitters:
  + `_emit_boundary_types(...)` → the `@Serializable data class` block (unchanged
    text; just extracted so all backends share it).
  + `_emit_backend_interface(walker_names, manifest)` → a Kotlin `interface JacBackend`
    with one `suspend fun <walker>(req, nodeId): <Res>` per walker, plus:

    ```kotlin
    object JacBackends { lateinit var current: JacBackend }
    ```

  + `_emit_remote_backend(package_name, ...)` → today's HTTP logic as
    `class RemoteBackend : JacBackend`, `call()` unchanged, methods `override`.
+ **1.2** New top-level `def emit_sv_backend(package_name, manifest, deploy, sync_url) -> dict[str, str]`
  in `rpc_client.jac` (declare) + impl. Returns a **map of filename → Kotlin source**
  (a backend may be more than one file in later phases). For `deploy == "remote"` it
  returns `{ "JacBoundary.kt": ..., "JacBackend.kt": ..., "RemoteBackend.kt": ... }`.
  Keep `emit_jac_client` as a thin shim delegating to the `remote` path so nothing
  else breaks during the transition.
+ **1.3** Emit the backend selection. A generated `JacBackendInit.kt` sets
  `JacBackends.current = RemoteBackend(...)`. Call it from the app entry
  (`gradle_templates/MainActivity.kt` / `JacDevEntry.kt`) in an `onCreate`/init block.
  (Grep those templates for where `JacClient.baseUrl`/`JacEnvironment.BACKEND_URL` is
  referenced today; that is the wiring point.)
+ **1.4** `compose_emit.impl.jac` `ComposeEmit.write`: replace the single
  `emit_jac_client(...)` + `files[".../JacClient.kt"] = client_src` with a loop over
  `emit_sv_backend(...).items()` writing each file. Pass `self.model.intent.sv_deploy`
  and `sv_sync_url`.
+ **1.5** `jac_to_kotlin.impl.jac` `_convert_spawn`: change the emitted callee from
  `JacClient` to `JacBackends.current`. **This is the one `cl`-codegen edit in the
  whole project.** After this, `cl` is forever backend-agnostic.

**Acceptance:** `compose_todo` with a walker (add one - see the example in the task
prompt) builds under `deploy = "remote"`; the generated Kotlin now has
`interface JacBackend` + `class RemoteBackend` + `JacBackends.current`, and `Screens.kt`
calls `JacBackends.current.add_todo(...)`. Gradle `compileDebugKotlin` succeeds
(the CI `test-android-compose` job). Behaviorally identical to pre-Phase-1.

> After Phase 1 the app is *structurally* ready for a second backend. `device` and
> `local-first` still fall back to emitting `RemoteBackend` until Phase 2 lands - wire
> the dial so unknown-yet modes emit remote **with a `console.warning`** ("device
> backend not yet available, emitting remote"). Never silently mis-emit.

---

### Phase 2 - Seam 1: the on-device graph runtime + walker lowering (`deploy = "device"`)

This is the heart. It has two halves that meet in the middle:

+ **2A - a hand-written Kotlin runtime library** (`JacGraph`) that provides the graph
  primitives, shipped as static template files (like `JacMath.kt` today).
+ **2B - a compiler pass** that lowers `sv` node/edge/walker archetypes and their
  ability bodies into Kotlin classes that drive that runtime.

Build 2A first (you can unit-test it in isolation with hand-written Kotlin), then 2B
against it.

#### 2A - the `JacGraph` Kotlin runtime (static templates)

New files under `compiler/passes/compose/gradle_templates/jacgraph/` (emitted verbatim
when `deploy != "remote"`, same mechanism as `JacMath.kt`):

+ **`JacAnchor.kt`** - base for persisted objects: a stable `id: String` (UUID),
  a `type: String`, and a `props: MutableMap<String, Any?>` (or generated typed
  fields - see 2B). Nodes and edges are both anchors.
+ **`JacGraph.kt`** - the in-memory store + traversal engine. Minimum surface the
  `compose_todo` walkers need (grow it strictly as lowering demands):

  ```kotlin
  object JacGraph {
      val root: Node                                   // the singleton root anchor
      fun <T: Node> spawnNode(node: T): T              // materialize + persist a node
      fun connect(from: Node, to: Node, edge: Edge? = null)   // the ++> operator
      fun neighbors(from: Node, dir: Dir, type: String? = null): List<Node>  // --> / <-- with (?Type)
      fun delete(node: Node)                           // the del operator
      fun persist()                                    // flush to storage (Phase 3)
  }
  enum class Dir { OUT, IN, ANY }
  ```

+ **`Walker.kt`** - a base class capturing walker semantics:

  ```kotlin
  abstract class Walker {
      val reports = mutableListOf<Any?>()
      fun report(v: Any?) { reports.add(v) }
      // visit queue for multi-node traversal; for entry-only walkers a single dispatch is enough
      abstract fun onRootEntry(here: Node)   // generated override per `with root entry`
      fun spawnOn(start: Node): List<Any?> { onRootEntry(start); return reports }
  }
  ```

> **Scope discipline (critical for a weaker model):** implement *only* the operators
> the target example uses - `++>` (connect out), `[root --> (?Type)]` (typed out
> neighbors), `del`, `report`, `here`, walker fields, `root`. Do **not** attempt full
> Jac graph semantics (edge archetypes with bodies, `visit`/`disengage`, `<++`, edge
> filters, abilities on nodes, `here` rebinding across a traversal frontier) in this
> phase. Each unsupported construct must raise a **compile-time diagnostic** (reuse the
> `model.intent.diagnostics` refuse-to-emit path in `ComposeEmit.write` - see
> `PLAN.md` Issue 4), never emit silently-wrong Kotlin. Widen coverage in follow-ups.

#### 2B - the walker/node lowering pass

New file pair `compiler/passes/compose/sv_lower.jac` + `impl/sv_lower.impl.jac`.
Model it on `compose_gen_pass` (which already walks `uni` for the `cl` side).

+ **2B.1 - discover the archetypes.** Walk the compiled `uni` module (the same `mod`
  object `_compile_compose_modules` already has) for `node`/`edge`/`walker`
  archetypes. The client-callable set is exactly `manifest.walker_access` (reuse it -
  do not re-derive). For each, capture the archetype AST node.
+ **2B.2 - lower node archetypes → Kotlin classes.** A `node Todo { has title: str;
  has done: bool = False; }` becomes:

  ```kotlin
  @Serializable
  class Todo(var title: String, var done: Boolean = false) : Node() { override val type = "Todo" }
  ```

  Field types map through the **existing** `RpcClientEmitter.jac_type_to_kotlin`
  (already handles `str/int/float/bool/list/dict/optional`). `has` defaults map through
  the existing `kotlin_default_literal`. Reuse both - do not reimplement type mapping.
+ **2B.3 - lower ability bodies → Kotlin.** For each walker's
  `can <name> with root entry { ... }` (and `with <NodeType> entry`), lower the
  statement body with the **existing** `JacToKotlin` converter
  (`jac_to_kotlin.impl.jac`). This is the reuse that makes the phase feasible: arithmetic,
  conditionals, loops, comprehensions, string ops, `self.<field>` all already lower.
  You add lowering **only for the graph operators**, in `JacToKotlin`:

  | Jac construct | Lowers to |
  |---|---|
  | `here ++> Todo(title=self.title)` | `JacGraph.connect(here, JacGraph.spawnNode(Todo(title = this.title)))` |
  | `[root --> (\`?Todo)]` | `JacGraph.neighbors(JacGraph.root, Dir.OUT, "Todo")` |
  | `[here --> (\`?Todo)]` | `JacGraph.neighbors(here, Dir.OUT, "Todo")` |
  | `del t` | `JacGraph.delete(t)` |
  | `report self.out` | `report(this.out)` |
  | `root` (bare) | `JacGraph.root` |

  Guard each: if the traversal has an edge-typed filter, an `<--`/`<++`, a `visit`,
  or anything past the whitelist, emit a diagnostic (2A scope note).

+ **2B.4 - assemble the walker class.** Emit `class AddTodo(val title: String) :
  Walker()` with `override fun onRootEntry(here: Node) { <lowered body> }`. The
  constructor params are the walker's `has` fields (same list already in
  `manifest.bindings[name].param_names/param_types`).
+ **2B.5 - emit `DeviceBackend`.** `emit_sv_backend(..., deploy="device")` returns the
  boundary types + interface (shared with Phase 1) + a generated
  `class DeviceBackend : JacBackend` whose each `override suspend fun add_todo(req,
  nodeId)` does:

  ```kotlin
  val w = AddTodo(title = req.title)
  val reports = w.spawnOn(nodeId?.let { JacGraph.byId(it) } ?: JacGraph.root)
  JacGraph.persist()
  return AddTodoResponse(reports = reports.map { it.toString() })   // shape per boundary_types
  ```

  The response mapping must match the `<Pascal>Response` boundary type exactly (fields
  from `manifest.boundary_types`). For a `report`-list walker that is `reports:
  list[...]`; reuse `_walker_response_info` in `rpc_client.impl.jac`.
+ **2B.6 - build wiring.** In `android_target.impl.jac`, when `sv_deploy != "remote"`,
  run `sv_lower` after the compose model is built and thread its emitted files into
  `ComposeEmit` (extend the model or pass alongside). Ensure `kotlinx.serialization`
  is already a Gradle dep (it is - the RPC client uses it).

**Acceptance:**

+ Add walkers to `compose_todo` (the three from the task prompt: `add_todo`,
  `list_todos`, `clear`) and set `deploy = "device"`.
+ `jac build --client android` emits `JacGraph.kt`, `Walker.kt`, `Todo.kt` (or one
  `SvNodes.kt`), `AddTodo/ListTodos/Clear` walker classes, and `DeviceBackend.kt`.
  **No `RemoteBackend`, no HTTP, no `JacEnvironment.BACKEND_URL`.**
+ `compileDebugKotlin` succeeds.
+ On device/emulator (CI `test-android-compose-device`, or manual per `PLAN.md` C2):
  add three todos, they render from `list_todos()`; the app makes **zero network
  requests** (verify with airplane mode). Clear empties the list.
+ An unsupported graph construct (e.g. `[root <-- (\`?Todo)]`) fails the build with a
  named diagnostic, not a broken APK.

---

### Phase 3 - persistence (make the on-device graph survive app restarts)

Phase 2's `JacGraph` can start purely in-memory. Phase 3 makes it durable. Keep it
behind the same `JacGraph` surface so nothing regenerated in 2B changes.

**Tasks**

+ **3.1** Pick the store. **Recommended: a single-file JSON/append-log snapshot** for
  the first cut (no schema, no migrations, trivial to reason about) - `JacGraph.persist()`
  serializes all anchors+edges via `kotlinx.serialization` to app-internal storage;
  load on init. Room/SQLite is the "proper" answer but adds DAO/entity codegen
  surface; **defer it** unless a real dataset size forces it. Note the tradeoff in
  the file header.
+ **3.2** Implement `JacGraph.load()` (call from `JacBackendInit`) and make
  `persist()` durable (write-through on each walker completion, or debounced).
+ **3.3** Storage location: `Context.filesDir`. The runtime needs a `Context`; pass it
  via `JacBackendInit` at app start (it already runs in `onCreate`).

**Acceptance:** add todos, kill the app, relaunch - todos are still there. Airplane
mode throughout.

---

### Phase 4 - Seam 3: `local-first` (device graph + background sync)

**Goal:** graph lives on device (offline-first, Phase 2+3), and node/edge mutations
replicate to a remote Jac server when connectivity allows. This is the payoff row in
the pitch: the Room+WorkManager pattern, generated.

**Tasks**

+ **4.1 - oplog.** In `JacGraph`, record every mutation (`spawnNode`, `connect`,
  `delete`, field write) as an append-only op with `(opId, anchorId, kind, payload,
  logicalClock)`. Persist alongside the graph.
+ **4.2 - `LocalFirstBackend`.** `emit_sv_backend(..., deploy="local-first")` emits
  everything `device` emits **plus** a `class LocalFirstBackend : JacBackend` that
  wraps `DeviceBackend` (runs the walker locally, returns immediately) and enqueues a
  sync.
+ **4.3 - WorkManager sync worker** (static template `JacSyncWorker.kt`). Periodic +
  network-constrained. On run: POST the pending oplog to `[sv].sync` URL (reuse
  `RemoteBackend`'s HTTP plumbing - factor the `HttpURLConnection` helper out of
  Phase 1 into a shared `JacHttp.kt` so both backends use it), receive remote ops,
  apply them to the local graph, advance the clock.
+ **4.4 - conflict policy.** First cut: **last-writer-wins per anchor field** by
  logical clock. Document it; a CRDT is out of scope. Deletes win over concurrent
  edits (tombstone). Put the policy in one place (`JacSync.kt`) so it is swappable.
+ **4.5 - sync endpoint contract.** Define the wire shape for the oplog POST (a JSON
  batch of ops) and document what the remote Jac server must expose. **Flag to the
  user:** the remote side needs a matching op-ingest endpoint - that is server-side
  Jac work, likely a separate branch. Do not build the server here; specify the
  contract.

**Acceptance:** in airplane mode add todos (they persist, Phase 3). Re-enable network:
the WorkManager job flushes the oplog; a second device pointed at the same `sync` URL
converges. Requires a live sync endpoint - until that exists, unit-test the worker
against a fake server and ship `local-first` with a documented server requirement.

---

## 4. Reference: Jac graph construct → Kotlin mapping (the whitelist for Phase 2)

Implement exactly these in Phase 2. Everything else → compile diagnostic.

| Jac | Kotlin | Owner |
|---|---|---|
| `node T { has f: ty = d; }` | `@Serializable class T(var f: TY = D): Node()` | 2B.2 |
| `walker W { has f: ty; }` | `class W(val f: TY): Walker()` | 2B.4 |
| `can x with root entry { B }` | `override fun onRootEntry(here: Node) { B }` | 2B.3/4 |
| `here ++> T(...)` | `JacGraph.connect(here, JacGraph.spawnNode(T(...)))` | 2B.3 |
| `[X --> (\`?T)]` | `JacGraph.neighbors(X, Dir.OUT, "T")` | 2B.3 |
| `del n` | `JacGraph.delete(n)` | 2B.3 |
| `report e` | `report(e)` | 2B.3 |
| `root` | `JacGraph.root` | 2B.3 |
| `self.f` | `this.f` | already in `JacToKotlin` |
| arithmetic / `if` / `for` / comprehension / str ops | (existing) | already in `JacToKotlin` |

Explicitly deferred (diagnose, don't emit): `<--`, `<++`, edge archetypes with bodies,
edge filters `[--> (\`?T:edge:cond)]`,`visit`,`disengage`, node abilities, walker
`with <T> entry` frontier traversal beyond root, `spawn` returning walker refs.

---

## 5. Testing strategy

+ **Compiler unit tests** (`tests/compiler/`, run one file at a time per CLAUDE.md -
  `pytest path/test_x.jac -x --maxfail=1`, never the full suite, never `-n`):
  + `test_sv_deploy_config.jac` - Phase 0: `resolve_sv_deploy` values + bad-value raise.
  + Extend `test_compose_scaffold.jac` / a new `test_sv_backend_emit.jac` - Phase 1:
    assert emitted Kotlin contains `interface JacBackend`, `class RemoteBackend`,
    `JacBackends.current`, and `Screens.kt` calls `JacBackends.current.<walker>`.
  + `test_sv_lower.jac` - Phase 2: golden-file the lowered `Todo.kt`, `AddTodo` walker,
    `DeviceBackend.kt` for the todo example; assert the diagnostic fires for a
    deferred construct.
+ **Kotlin runtime tests** (in the generated Gradle project, JVM unit tests, no
  device): `JacGraph` connect/neighbors/delete, `Walker.spawnOn` reports, persistence
  round-trip (Phase 3), oplog + LWW merge (Phase 4).
+ **E2E on device:** the two CI jobs `test-android-compose` (build) and
  `test-android-compose-device` (install/launch), plus the manual airplane-mode
  checks in each phase's acceptance.
+ **Regression guard:** every phase re-runs `deploy = "remote"` on `compose_todo` and
  asserts the RemoteBackend output is unchanged from Phase 1's golden.

---

## 6. Risks, sequencing, and what to escalate

+ **Phase 2 is 80% of the effort.** Phases 0/1/3 are days; Phase 2 is the real
  project. Do not under-scope it. Land the runtime (2A) and the todo-slice lowering
  (2B) end-to-end before widening operator coverage.
+ **Reuse is mandatory, not optional.** `JacToKotlin` (expr/stmt lowering),
  `jac_type_to_kotlin`, `kotlin_default_literal`, `boundary_types`, `walker_access`,
  the `diagnostics` refuse-to-emit path, and the `JacMath.kt` static-template
  mechanism all already exist. A weaker model's failure mode here is reimplementing
  these - don't. Point the existing machinery at the walker body.
+ **The dial must degrade loudly.** Any not-yet-implemented mode emits `remote` **with
  a console warning**, never a silent or broken artifact. Mirror the existing
  refuse-to-emit-on-diagnostics stance.
+ **`local-first` needs a server counterpart** (op-ingest endpoint). That is
  out-of-scope server Jac work - specify the contract (4.5) and flag it to the user
  per CLAUDE.md ("if you find a broader issue, tell me") rather than building it here.
+ **Persistence choice (3.1):** start with the JSON snapshot; only escalate to
  Room/SQLite if a real workload demands it - Room adds a whole entity/DAO codegen
  surface that would balloon Phase 3.
+ **If any graph operator turns out to need `visit`/frontier semantics for a realistic
  app** (multi-hop walkers), that is a genuine scope expansion of Seam 1 - stop and
  raise it; don't quietly grow the whitelist into a half-built traversal engine.

---

## 7. Suggested branch/PR breakdown

One PR per phase (Phase 2 may be 2–3 PRs: runtime library, lowering pass, device
backend wiring). Each PR: add a `release_notes/` entry keyed to the **PR number**
(per CLAUDE.md), update `PROGRESS.md`, keep `deploy = "remote"` green. Never attribute
Claude as co-author.
