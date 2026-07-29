# Jac → Jetpack Compose (Android) backend - plan

Grounded against the actual code: the Jac `cl` frontend
(`jac/jaclang/compiler/passes/ecmascript/`), the `cl` component corpus (165 `.cl.jac`
files), and the Rust reference implementation (`references/crates/generator_android/`, ~35k LOC).

The original design is sound. Three findings from the code change how we build it - read
those first, then the pass shape, then the mapping table.

---

## Three findings that reshape the design

### F1 - The IR is *reusable data*, but the *producer* is welded to the JS pass

`view_ir.jac` and `reactive_intent.jac` are clean `obj` dataclasses - those we consume
verbatim. But they are **not** a standalone pass artifact. They're constructed *inside*
`EsastGenPass` as it walks the `uni` tree (`esast_gen_pass.impl.jac`: `StateField` @3730,
`Effect` @3662, `AsyncBoundary` @3060; view IR by `jsx_processor.jac`), and each
construction is immediately followed by a `self.backend.lower_*(...)` call into a
`FrameworkBackend` whose every method returns **estree** (`framework_backend.jac:12-41`).

So "reuse (import) view_ir / reactive_intent" is only half-true. **Decision D1** (below):
we must either extract the IR-producer out of `EsastGenPass`, or re-walk `uni` in a sibling
pass. `FrameworkBackend` cannot be the seam - it is estree-locked.

### F2 - Do NOT port the reference's reactive lowering. Go idiomatic - which is *also* the original table.

The reference does **not** emit per-signal `mutableStateOf`/`LaunchedEffect`. It ships a ~1100-line
hand-written Kotlin runtime interpreter and feeds it compile-time
**data literals** (action records: `Assign`/`Request`/`Sequence`, request actions,
`mapOf(...)`). State is one `mutableStateMapOf<String,Any?>`; reads are `state.text("id")`,
writes `state.write("id", it)`, actions `state.run("id")`. Reactivity, stdlib, and HTTP all
live in that interpreter string (`reactive_runtime.rs`, `reactive_lowering.rs`).

That two-tier trick exists because the reference's actions are *declarative data*. Jac's
`reactive_intent` is **richer** - `Effect.body` is `list[es.Statement]`, `StateUpdate.value`
is a real `es.Expression`. We have the actual code, so we can generate **idiomatic Compose**
directly - exactly the mapping the original proposal drew:

| Jac `reactive_intent` | → Compose | source |
|---|---|---|
| `StateField(name, init)` | `var name by remember { mutableStateOf(<init→kt>) }` | `reactive_intent.jac:3` |
| `StateUpdate(name, value, aug_op)` | `name = <value→kt>` / `name += …` | `:13` |
| `Effect(body, deps, is_entry=T)` | `LaunchedEffect(Unit) { <body→kt> }` | `:19` |
| `Effect(deps=[a,b], is_entry=F)` | `LaunchedEffect(a, b) { … }` | `:19` |
| `Effect(is_async=T)` | body in `rememberCoroutineScope().launch { … }` | `:23` |
| `RefField(name, init)` | `val name = remember { … }` | `:8` |
| `AsyncBoundary(try, await, except)` | `try { … <await→suspend call> } catch (e) { … }` inside a coroutine scope | `:26` |

**What we adapt from the reference:** the *Compose vocabulary and idioms* - the host/primitive →
Composable mapping (`compose_rendering/`, `generated_views/*`), the `Modifier` builders and
`Color(0xFF…)`/design-token approach (`compose_styles.rs`, `design_tokens_and_names.rs`),
and the Gradle/Manifest/MainActivity scaffold (`artifacts.rs`). We keep its *knowledge of
Compose*; we drop its *runtime-interpreter architecture*.

Consequence: `es_to_kotlin.jac` grows a bit - it must translate `Effect.body` **statements**
(not just expressions): `BlockStatement`, `IfStatement`, `AssignmentExpression`,
`AwaitExpression`, calls. Still bounded (no `eval`, no `with`), but plan for the `Statement`
union, not expression-only. Event-handler bodies are already pre-digested into
`StateUpdate`/`Effect`/`AsyncBoundary` by `reactive_intent`, so we lean on that rather than
lowering raw `onClick` closures.

### F3 - The real structural cost is `className` (Tailwind) → `Modifier`, not the host-tag table

The original proposal named the host-tag problem as the hard part. It's real, but the code
shows the *deeper* one: **Jac `cl` expresses layout as Tailwind utility classes on `<div>`**,
e.g. `class="flex items-center gap-2 rounded border p-4"` (`Card.cl.jac`, `Input.cl.jac`,
everywhere). The reference never has this problem - its source carries structured style props, so
`generated_views/*` maps a typed `Box`/`Flex`/`Grid` node straight to `Column`/`Row`.

For us, **`<div>` → `Column` vs `Row` vs `Box` is decided by the className string**
(`flex` + `flex-col`/`flex-row`/absent). And `p-4 gap-2 rounded border bg-… text-…` must
become a `Modifier` chain + Material colors. That is a **Tailwind-subset → Compose Modifier
translator** - a genuine workstream the original plan folded invisibly into
`compose_backend.jac`. It is the Android analog of what CSS generation does on the web path.
Sizing it is the #1 job of the mapping table below.

---

## Decisions to lock before coding

**D1 - RESOLVED, then SUPERSEDED by the IntentCollector extraction (F1).**
> **⚠ SUPERSEDED (2026-07-28):** D1 was the cheaper approximation. The recording
> `ComposeBackend(FrameworkBackend)` has been **deleted** and replaced by a
> backend-agnostic `IntentCollector` + `IntentModule` (`compiler/passes/ecmascript/intent/`),
> which is F1 done properly. Android now runs collector → ComposeEmitter with **no
> `FrameworkBackend` at all** and **no `lower_*` calls**; the placeholder-estree
> tolerance this decision relied on is gone (see `PLAN.md`, fully implemented P0+P1).
> The text below is retained as the historical rationale for the D1 approximation.
>
> **Original D1 rationale (historical):**

`EsastGenPass` is already backend-abstracted (`framework_backend.jac:12-41`): every reactive/
view intent flows through a `FrameworkBackend` method that *receives the intent object* -
`lower_view(view: ViewElement, …)`, `lower_state_field(StateField)`, `lower_ref_field`,
`lower_state_update`, `lower_effect`, `lower_async_boundary`, plus `lower_state_read(name)` /
`lower_view_expr(expr)`. So a Compose target is a **new backend, not a new pass**:

- `ComposeBackend` **records** each intent object into a per-module Compose model (and returns
  a harmless placeholder `es.*` so `EsastGenPass`'s own estree assembly doesn't crash - that
  estree module is discarded for Android).
- It sets the Compose-flavored semantics at the two expr hooks: `lower_state_read(x)` →
  bare `Identifier(x)` (a `by remember` var reads directly, unlike React's `x.value`);
  `lower_state_update` → an `AssignmentExpression`. Exactly mirrors how `ReactBackend` encodes
  React semantics - this is the intended extension seam.
- Because `view_ir`/`reactive_intent` leaves are already-lowered `es.Expression`s,
  `es_to_kotlin` translates **estree → Kotlin** and we **reuse every uni→expression visitor in
  `EsastGenPass` for free** - no re-walking `uni`, no duplicated JSX/reactive detection.

Net: zero duplication, zero risk to the JS path's *logic* (we add a backend, we don't touch
react/preact/solid). Registered via `resolve_framework_backend("compose")`
(`backends/registry.jac`). The only "pass-like" new code is a thin **emit step** that reads
the recorded model after `EsastGenPass` runs and writes the Kotlin project. Fallback (only if
`EsastGenPass`'s estree finalization proves too coupled to tolerate placeholder returns): a
sibling `ComposeGenPass` re-walking `uni` - but the probes show the backend seam is clean, so
this is not expected. Full wiring in `ANDROID_COMPOSE_IMPL_SPEC.md`.

**D2 - Reactive architecture: idiomatic Compose (per F2).** Not a runtime data-interpreter.
Confirmed by `reactive_intent` carrying real statements/expressions.

**D3 - v1 component vocabulary is *sanctioned*, not arbitrary.** Support (a) the HTML host-tag
subset in the table, (b) the curated `common/` + `ui/` primitive set. Lowering *arbitrary*
`cl` components to Compose is out of scope - that's what keeps the host-tag/className tables
finite and shippable.

**D4 - Typed RPC is in from day one (the differentiator).** Greenlit by the code:
`InteropManifest.boundary_types` (`codeinfo.jac:323/349`) exposes per-walker field
names+types+defaults+enum members, and `walker_access` marks `:pub`. That is enough to emit
Kotlin `@Serializable data class` request/response types + a `suspend fun` client POSTing to
`/walker/{name}` with `Authorization: Bearer`, unwrapping `.data`. **The reference has zero typed
models** (reflective `HttpURLConnection`+`org.json`). Renaming a server field breaks Kotlin
compilation - a guarantee the reference structurally cannot offer.

**D5 - Two build axes.** `--client` selects the *packaging shell*
(`build.jac:53-92`, choices auto-synced from the target registry); `[client] framework`
selects *codegen* (`config.jac:147`). Android needs **both**: a new `AndroidTarget` in the
target registry **and** a `"compose"` codegen path. (See milestones.)

---

## Pass shape - `jac/jaclang/compiler/passes/compose/` (sibling to `ecmascript/`)

```
# reused as data (imported): view_ir.jac, reactive_intent.jac, estree.jac
kotlin_ast.jac         NEW  Kotlin/Compose node objs (mirror estree.jac)
kotlin_unparse.jac     NEW  KotlinCodeGenerator: gen_<node> per type + generate() dispatch
                            (mirror es_unparse.jac's pascal_to_snake string-dispatch + indent state)
es_to_kotlin.jac       NEW  estree Expression *and Statement* subset → kotlin_ast
                            (Literal, Identifier, Member, Call, Conditional, TemplateLiteral,
                             Binary/Logical/Unary; Block/If/Assignment/Await for Effect bodies)
tailwind_to_modifier.jac  NEW  className subset → (layout kind, Modifier chain, color tokens)  ← F3
compose_backend.jac    NEW  view_ir → Compose call tree; host-tag vocab + component vocab
                            (adapts generated_views/* + compose_rendering/* idioms)
reactive_compose.jac   NEW  reactive_intent → mutableStateOf / LaunchedEffect / coroutine scope
rpc_client.jac         NEW  InteropManifest.boundary_types → @Serializable data classes +
                            suspend-fun client  ← differentiator (D4)
gradle_scaffold.jac    NEW  settings/build.gradle.kts, Manifest, MainActivity, theme, strings,
                            routing, environment module (JacEnvironment)  (port artifacts.rs, add kotlinx-
                            serialization + Ktor/OkHttp deps the reference omits)
compose_gen_pass.jac   NEW  pass entry (mirror esast_gen_pass.jac; per D1, re-walks uni for v1)
```

Registry/target wiring:

- `AndroidTarget(ClientTarget)` in `runtimelib/client/targets/` + register in
  `targets/register.jac:14-24`; add `ANDROID` to `TargetType` (`registry.jac:4`) and
  `get_target_type` (`:14`). CLI `--client android` choice then auto-syncs.
- Codegen selection: gate `compose_gen_pass` on the Android target / a `framework="compose"`
  value; the pass emits a Gradle project dir instead of a JS bundle.
- Defer the DEX hot-module dev host (`dev_*.rs`, `dev_shell/`) - v1 = full Gradle rebuilds.

---

## Component / host-tag mapping table (v1 vocabulary)

Layout tags resolve via `tailwind_to_modifier` (F3), not a fixed Composable.
"reference" = the `generated_views`/`compose_rendering` idiom we adapt.

### HTML host tags

| HTML tag | Compose output | decided by | reference idiom |
|---|---|---|---|
| `div`,`section`,`article`,`main`,`aside` | `Column` \| `Row` \| `Box` | className: `flex`+`flex-col`/`flex-row`; `grid`→grid-analog | `flow_nodes.rs:90/150/202` |
| `header`,`footer`,`nav` | `Row` (bar layout) + zones | className | `navigation_nodes.rs:11`, `styles.rs:201` |
| `form` | `Column` | - | - |
| `span`,`p`,`b`,`strong`,`code`,`label` | `Text(...)` | inline text style from className | `display_nodes.rs:290`, `compose_styles.rs:1` |
| `h1`,`h2`,`h3` | `Text(style = MaterialTheme.typography.*)` | tag→type-scale | `compose_styles.rs` |
| `pre` | `Text(fontFamily = Monospace)` | - | - |
| `hr` | `Divider`/`Box(bg)` | - | `display_nodes.rs:283` |
| `ul`,`li` | `Column` + per-item `Row` | - | - |
| `table`,`thead`,`tbody`,`tr`,`th`,`td` | `Column`/`Row` grid (v1) → `LazyColumn`-analog later | - | `display_media_data_nodes.rs:204` |
| `button` | `Button(onClick=…, colors=…)` | className→variant/colors | `flow_nodes.rs:383` |
| `input` | `TextField`/`OutlinedTextField` (`value`+`onValueChange`) | `type=` attr | `form_nodes.rs:21` |
| `textarea` | `TextField(maxLines>1)` | - | `form_nodes.rs:264` |
| `select`,`option` | `ExposedDropdownMenuBox` + `DropdownMenuItem` | - | `form_nodes.rs:69` |
| `img` | `AsyncImage`/custom loader | - | `media_forms.rs` |
| `svg`,`circle`,`line`,`polyline`,`polygon`,`text` | `Canvas { drawPath/… }` | element→draw op | `generated_views/canvas.rs` |

### Curated components (`scale/admin/ui/components/common/` + `cli/ai_ui/components/ui/`)

| `cl` component | Compose | reference idiom |
|---|---|---|
| `Button` | Material3 `Button` (+variant/scheme/size/loading) | `flow_nodes.rs:383` |
| `Input`,`TextArea` | reference Input/Textarea analog | `form_nodes.rs:21/264` |
| `Select`,`SmallSelect` | `ExposedDropdownMenu` | `form_nodes.rs:69` |
| `Card`,`CardHeader`,`CardBody`,`StatsCard` | Material3 `Card` + slots | `flow_nodes.rs:306` |
| `Badge`,`RoleBadge`,`StatusBadge` | pill `Box`+`Text` (`Chip`) | `overlay_nodes.rs` |
| `Alert`,`InlineAlert` | `Row` clip+bg+border+`Text` | `display_nodes.rs:314` |
| `Spinner`,`LoadingScreen` | `CircularProgressIndicator` | Material3 |
| `Modal`,`ModalFooter` | `Dialog`/`AlertDialog` | `overlay_nodes.rs` |
| `PageHeader`,`OpsUnavailableBanner` | `Row`/`Column` header composite | `navigation_*` |
| `DataTable` | `LazyColumn`-analog / `LazyColumn` | `display_media_data_nodes.rs:204` |
| control-flow: `Show`/`For`/`Outlet`/`Link` | `if`/`forEach`(→`LazyColumn` when scrolling)/nav-slot/nav-lambda | `foundation.rs:38` |

### Reactive & control-flow IR

| view_ir / reactive node | Compose | source |
|---|---|---|
| `IfChild(test, consequent, alternate)` | `if (<test→kt>) { … } else { … }` | `view_ir.jac:72` |
| `EachChild(items, item, key, body)` | `<items→kt>.forEach { item -> … }`; scrollable list → `LazyColumn { items(…) { … } }` | `view_ir.jac:88`; `flow_nodes.rs:66` |
| `TextChild`/`DynamicChild` | `Text(<expr→kt>)` | `view_ir.jac:52/57` |
| `EventAttr(onClick, handler)` | `onClick = { … }` (handler pre-digested via reactive_intent) | `view_ir.jac:35` |
| `StaticAttr`/`DynamicAttr` | Modifier arg / composable param | `view_ir.jac:23/29` |
| `AsyncBoundary` (walker call) | `scope.launch { try { client.walker(...) } catch … }` | `reactive_intent.jac:26` |

### Gaps / risks (where v1 vocabulary stops)

- **Tailwind coverage is unbounded in theory** - enumerate a supported utility subset
  (flex/grid, gap, p-/m-, w-/h-, rounded, border, bg-/text- color scale, text sizes) and
  emit a compile diagnostic for unsupported classes rather than silently dropping. This is
  the single biggest sizing risk; the subset list is the first artifact to nail down.
- **SVG** - v1: static paths → `Canvas` draw ops; defer runtime/animated SVG.
- **Charts/Canvas/Media/Editor/Chat** - the reference ships fat widgets for these; out of v1.
- **Icons** - lucide-react `<Icon/>` usages need an icon-name → Compose vector map (defer to
  a bundled subset).
- **Navigation** - the reference hand-rolls a `when(path)` router (no Nav-Compose). v1: port that
  simple router; Nav-Compose later.

---

## Milestones

- **M0 - Skeleton & dispatch.** `compose/` package, `AndroidTarget` registered, `--client
  android` reaches an empty Gradle project that builds. Prove D5 plumbing end-to-end.
- **M1 - Static render.** `compose_backend` + `kotlin_unparse` + `es_to_kotlin` (expr subset)
  - `tailwind_to_modifier` (subset) render a static `Button.cl.jac`/`Card.cl.jac` to a Screen
  that compiles under Gradle. Proves F3 and the host-tag table.
- **M2 - Reactivity.** `reactive_compose`: `useState`/effects → `mutableStateOf`/
  `LaunchedEffect`; interactive counter/form works on device/emulator. Proves F2.
- **M3 - Typed RPC (differentiator).** `rpc_client` from `InteropManifest`: `@Serializable`
  types + suspend client; an `AsyncBoundary` walker call round-trips to a live Jac server.
  Add a test that a renamed server field fails Kotlin compilation. Proves D4.
- **M4 - Scaffold hardening.** Theme/design tokens, routing, strings/i18n, env config;
  parity pass against the reference's `artifacts.rs` output.
- **Deferred:** DEX hot-reload dev host, charts/canvas/media widgets, Nav-Compose, arbitrary
  component lowering, animated SVG.

## Recommended next artifact

The **Tailwind-subset → Compose Modifier spec** (F3) is now the critical-path unknown, ahead
of the host-tag table which this doc already sizes. Concretely: inventory the distinct
utility classes actually used across the 165 `.cl.jac` files, bucket them
(layout/spacing/sizing/color/typography/border), and define each one's Compose emission -
producing the finite supported set + the diagnostic list for the rest. That spec sizes
`compose_backend.jac` and `tailwind_to_modifier.jac`, the two largest new files.

---

## Status update (2026-07-28): gradle cache DONE; HMR complete (host-side verified)

### Gradle cache - COMPLETE & verified

- `_gradle_properties()` emits `org.gradle.caching/configuration-cache/parallel/daemon`,
  `kotlin.daemon.enabled/kotlin.incremental`, `android.nonTransitiveRClass/nonFinalResIds`.
- `ComposeEmit.write()` is **content-aware** (skips overwriting unchanged files → stable
  mtimes → Gradle/Kotlin incremental compile fires) + `_prune_stale_kotlin()` removes orphan
  `.kt`. Reports `Wrote N, reused M unchanged, pruned K stale`.
- `_run_gradle_assemble` passes `--build-cache`.
- Proof (compose_android example): `Wrote 0, reused 16 unchanged` + `Configuration cache entry reused`.

### HMR - direction: KEEP Compose/Kotlin; DexClassLoader hot-swap via Kotlin compile

**Verified fact:** the reference is 100% **Java + classic Views** (ViewGroup/FrameLayout/Canvas,
zero Compose/Kotlin). Its raw `javac`→`d8` HMR only works on Java. Jetpack Compose is
Kotlin-only. Decision: keep Compose; build HMR on Gradle `compileDebugKotlin` → `d8` merge
→ `DexClassLoader` swap (the modern path; what Compose live-edit does). Preserves the typed
`@Serializable` RPC differentiator + the existing Kotlin backend.

**Device-side kernel - LANDED & Kotlin-valid:**

- `JacDevEntry` (object, `@JvmStatic mount(activity)`) - the shared entry; dev host
  DexClassLoader-loads it and reflectively calls `mount`.
- `JacDevHostActivity` (ComponentActivity) - polls `{devServer}/_jac/dev/modules/manifest.json`
  every 300ms, downloads merged `classes.dex`, `DexClassLoader`-swaps. Kotlin/Compose port of
  the reference's dev host Activity.
- Gated behind `GradleScaffold.dev` / `build_gradle_scaffold(..., dev=True)`. Release (dev=False)
  is untouched; dev files are auto-pruned on release builds. Verified: emits + compiles clean
  against AGP 8.13 / Kotlin 2.2.21.

### HMR Slice 2 (host-side hot loop) - COMPLETE & verified end-to-end (server-side)

- **Dev HTTP server** (`_jac_dev_handler_cls`/`_jac_start_dev_server` in android_target.impl.jac):
  in-process `ThreadingHTTPServer` bound to 0.0.0.0. `GET /_jac/dev/modules/manifest.json`
  → `{version, path}`; `GET /_jac/dev/modules/android/classes.dex` → bytes. Live `state` dict
  the watch loop mutates. Pattern validated via curl.
- **2-module dev Gradle layout** (`dev=True`): base `:app` = `JacDevHostActivity` + Compose deps
  (built+installed ONCE); `:hot` = infra + screens + `JacDevEntry` (self-contained, no project
  dep on :app - AGP forbids lib→app). `_hot_gradle`/`_hot_manifest`/`_settings_gradle(dev)`.
- **ComposeEmit dev routing**: `dev: bool` field; screens → `hot/src/main/java/<pkg>/`, infra →
  `hot/`, host → `app/`. Release auto-`rmtree`s an orphan `hot/` dir.
- **`_build_hot_dex`**: `:hot:compileDebugKotlin` → collect `.class` (javac + kotlin-classes) →
  content-hash version → `d8 --min-api 26 --lib android.jar` → merged `classes.dex`.
- **`dev()` orchestration**: emit dev → build base `:app` → `_adb_reverse_launch` (install +
  `adb reverse` + `am start …/.JacDevHostActivity --es jacDevServer`) → initial hot dex → start
  server → `_watch_hot_reload` (poll `.cl.jac` mtimes → re-emit → rebuild dex → bump version).
- **Proof (compose_android example, no device):** base APK 11.9 MB (`:app:assembleDebug`);
  `:hot` → 32 classes → **hot dex 114 KB** (`d8`), valid `dex\n` magic. Tiny dex vs big base =
  the small-dex/big-base split. Release build still green (`Wrote 0, reused 16 unchanged`).
- **Unverified (needs emulator):** the live on-device `DexClassLoader` swap. Device kernel
  (`JacDevHostActivity`) already compiles clean. `d8` argv length cap noted for huge apps.

### Remaining (polish)

- ✅ Route persistence across swaps - DONE: dev `emit_jac_app` restores the last
  route from `SharedPreferences("jac-hmr")` and persists it via a
  `LaunchedEffect(currentEntry.path)`; survives dex reloads (app storage, not
  classloader-bound). Release path untouched. Tests: `tests/compiler/test_compose_emit.jac`.
- ✅ d8 `@argfile` - DONE: `_build_hot_dex` passes the class list via `@argfile`
  so huge apps don't overflow argv.
- Error overlay / first-bundle optimization - still open.
- **Still unverified:** live on-device `DexClassLoader` swap (needs emulator).
