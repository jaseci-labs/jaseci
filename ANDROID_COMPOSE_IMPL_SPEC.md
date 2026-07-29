# Jac → Jetpack Compose - implementation spec

Companion to `ANDROID_COMPOSE_PLAN.md`. This is the build-ready breakdown: architecture,
every new file's contract, the concrete translation tables (estree→Kotlin, Tailwind→Modifier,
walker→typed-client), the scaffold deltas, and a task list with acceptance criteria. All facts
below are grounded in the code (refs inline).

---

## 1. Architecture - the recording-backend seam (D1 resolved)

```
uni tree
  │  (unchanged) EsastGenPass walks uni, lowers expressions to estree,
  │              detects reactive intent, builds view_ir - all existing code
  ▼
FrameworkBackend hooks  ── ComposeBackend records intent objects ──►  ComposeModule model
  │  lower_state_field(StateField)      → model.components[cur].state += s
  │  lower_ref_field(RefField)          → model.components[cur].refs  += r
  │  lower_state_update(StateUpdate)    → (returns AssignmentExpression; also recorded)
  │  lower_effect(Effect)               → model.components[cur].effects += e
  │  lower_async_boundary(AsyncBoundary)→ model.components[cur].asyncs  += a
  │  lower_view(ViewElement)            → model.components[cur].view = view
  │  lower_state_read(name)             → es.Identifier(name)     (Compose semantics)
  │  each hook ALSO returns placeholder es.* so EsastGenPass won't crash
  ▼
ComposeEmit (new): model → Kotlin project on disk
  ├─ compose_backend.jac     view_ir  → Compose call tree (kotlin_ast)
  ├─ reactive_compose.jac    reactive_intent → mutableStateOf/LaunchedEffect (kotlin_ast)
  ├─ es_to_kotlin.jac        estree leaves → Kotlin exprs/stmts (kotlin_ast)
  ├─ tailwind_to_modifier.jac className → Modifier chain + color tokens
  ├─ rpc_client.jac          InteropManifest → @Serializable + suspend client
  ├─ kotlin_unparse.jac      kotlin_ast → source text
  └─ gradle_scaffold.jac     Gradle/Manifest/MainActivity/theme/routing (verbatim ports)
```

`AndroidTarget.build()` drives it: run inference schedule, run `EsastGenPass` with the compose
backend active (fills `ComposeBackend.model`, discards `mod.gen.js`), call `ComposeEmit` to
write `apps/android/`, invoke Gradle, return the `.apk` `Path`.

**Package directory `compiler/passes/compose/`** holds: `compose_backend.jac`,
`reactive_compose.jac`, `es_to_kotlin.jac`, `tailwind_to_modifier.jac`, `kotlin_ast.jac`,
`kotlin_unparse.jac`, `rpc_client.jac`, `gradle_scaffold.jac`, `compose_emit.jac`, plus
`impl/` counterparts. The `ComposeBackend` itself lives at
`compiler/passes/ecmascript/backends/compose.jac` (sibling to `react.jac`) so the registry
finds it.

---

## 2. New files - contracts & size estimates

| File | Responsibility | Consumes | Produces | ~LOC |
|---|---|---|---|---|
| `backends/compose.jac` | `ComposeBackend(FrameworkBackend)`: record intents, set Compose expr semantics | intent objs | `ComposeModule` + placeholder estree | 250 |
| `compose/model.jac` | `ComposeModule`/`ComposeComponent` dataclasses (state/refs/effects/asyncs/view per component; module routes; imports set) | - | - | 80 |
| `compose/kotlin_ast.jac` | Kotlin/Compose node `obj`s (mirror `estree.jac`) | - | - | 300 |
| `compose/kotlin_unparse.jac` | `KotlinCodeGenerator`: `gen_<node>` + `generate()` string-dispatch + indent state (mirror `es_unparse.jac`) | kotlin_ast | source text | 400 |
| `compose/es_to_kotlin.jac` | estree Expression **and** Statement subset → kotlin_ast | `es.Expression`/`es.Statement` | kotlin_ast | 500 |
| `compose/tailwind_to_modifier.jac` | className subset → (layout kind, Modifier chain, color/text tokens) | class string | kotlin_ast Modifier + layout hints | 450 |
| `compose/compose_backend.jac` | `view_ir` → Compose call tree; host-tag + component vocab | `ViewElement` | kotlin_ast composable calls | 600 |
| `compose/reactive_compose.jac` | `reactive_intent` → `mutableStateOf`/`LaunchedEffect`/coroutine scope | intent objs | kotlin_ast stmts | 250 |
| `compose/rpc_client.jac` | `InteropManifest.boundary_types` → `@Serializable` data classes + suspend client | manifest | Kotlin source | 350 |
| `compose/gradle_scaffold.jac` | non-`.kt` + boilerplate `.kt` project files (verbatim ports of Dowe `artifacts.rs`) | routes/env/theme | file map | 400 |
| `compose/compose_emit.jac` | orchestrator: `ComposeModule` → project dir on disk | model | files written | 250 |
| `targets/android_target.jac` (+impl) | `AndroidTarget(ClientTarget)`: setup/build/dev/start | entry, project_dir | `.apk` Path | 350 |

Wiring edits (small): `backends/registry.jac` (+`"compose"` branch), `targets/register.jac`
(+`AndroidTarget()`), `targets/registry.jac` (`ANDROID` enum + `get_target_type` alias),
`runtimelib/client/impl/jac_client_compiler.impl.jac` (`"android"` target_name branch, if a
runtime `.cl.jac` is needed).

---

## 3. `es_to_kotlin` - estree → Kotlin translation table

Covers the full estree unions (`estree.jac:437-443`). Operator source-of-truth: the
`ES_*_OPS` maps at `esast_gen_pass.jac:36-125` - **but** estree already holds JS operator
strings (`===`, `!==`), so `es_to_kotlin` maps *JS-operator-string → Kotlin*, listed below.

### Expressions

| estree node | Kotlin emission | notes |
|---|---|---|
| `Literal` str | `"…"` | escape `\ " $` and newlines (Kotlin templates use `$`) - mirror Dowe `escape_kotlin` |
| `Literal` int/float/bool | `123` / `1.5` / `true`/`false` | - |
| `Literal` None | `null` | - |
| `Identifier` | `name` | backtick-escape Kotlin hard keywords: `is in object fun val var when class this typeof as` |
| `ThisExpression` | `this` | - |
| `MemberExpression` | `obj.prop` / `obj[expr]` (computed) / `obj?.prop` (optional) | - |
| `CallExpression` | `callee(args)` / `callee?.invoke(args)` (optional) | drop `new` - see NewExpression |
| `NewExpression` | `Callee(args)` | Kotlin has no `new` |
| `ConditionalExpression` | `if (t) c else a` | Kotlin `if` is an expression |
| `TemplateLiteral` | `"…${expr}…"` | quasis + interleaved `${…}` |
| `BinaryExpression` | operator-mapped (below) | |
| `LogicalExpression` | `a && b` / `a \|\| b` | same |
| `UnaryExpression` | `-x` / `+x` / `!x` / `x.inv()` | `~` → `.inv()` (Kotlin has no `~`) |
| `AssignmentExpression` | `x = v` / `x += v` … | `**=` unsupported → diagnostic |
| `AwaitExpression` | `<arg>` (drop `await`) | callee is a `suspend fun`; awaiting is implicit in Kotlin |
| `ArrayExpression` | `listOf(a, b, …)` | spread element → `*arr.toTypedArray()` |
| `ObjectExpression` | `mapOf("k" to v, …)` | v1: map; typed data-class promotion later |
| `ArrowFunctionExpression`/`FunctionExpression` | `{ p1, p2 -> <body> }` | body BlockStatement or expr; async_ irrelevant (suspend context) |
| `SpreadElement` | `*<arg>` | in call/list position |
| `JsxElement`/`JsxFragment` | - | never reached: children are lifted to view_ir; if seen → diagnostic |

**Binary/comparison operator map (JS string → Kotlin):**
`===`→`==`, `!==`→`!=`, `==`→`==`, `!=`→`!=`, `<`→`<`, `>`→`>`, `<=`→`<=`, `>=`→`>=`,
`+`→`+`, `-`→`-`, `*`→`*`, `/`→`/` (⚠ int/int is integer division in Kotlin - acceptable v1),
`%`→`%`, `&`→`and`, `|`→`or`, `^`→`xor`, `<<`→`shl`, `>>`→`shr`, `in`→`in`.
(`&`/`|`/`^`/`<<`/`>>` are infix functions in Kotlin, not operators - emit `a and b` etc.)
**Augmented:** `+= -= *= /= %=` pass through; bitwise/`**=` → diagnostic.

**Kotlin identifier caveats:** hard keywords must be backticked; `esast_gen_pass.jac` already
sanitizes some names - replicate its reserved-word handling for the Kotlin set.

### Statements (for `Effect.body: list[es.Statement]`)

| estree | Kotlin |
|---|---|
| `ExpressionStatement` | `<expr>` |
| `BlockStatement` | `{ <stmts> }` |
| `VariableDeclaration` | `val name = init` (const) / `var name = init` |
| `IfStatement` | `if (t) { … } else { … }` |
| `ForOfStatement` | `for (x in <iter>) { … }` |
| `WhileStatement` | `while (t) { … }` |
| `ForStatement` | desugar to `while` (init; while(test){ body; update }) |
| `ReturnStatement` | `return@<label>` inside lambdas (LaunchedEffect/onClick) |
| `TryStatement` | `try { … } catch (e: Exception) { … } finally { … }` |
| `ThrowStatement` | `throw <arg>` |
| `BreakStatement`/`ContinueStatement` | `break`/`continue` |
| `SwitchStatement` | `when (<disc>) { … }` |
| `FunctionDeclaration` | `fun name(params) { … }` (rare in view scope) |
| `ClassDeclaration` | diagnostic (out of scope in view code) |

---

## 4. `tailwind_to_modifier` - className → Compose

Input: a className string (may be static literal, or a per-branch literal harvested from a
ternary/dict - the estree `value` on `StaticAttr`/`DynamicAttr`). Output: `(layout: LayoutKind,
modifier: Modifier chain, text_style: TextStyleParts, unsupported: list[str])`. Tailwind unit
= `0.25rem = 4dp`; fractional (`p-1.5`) → `6.dp`; arbitrary `w-[17px]` → `17.dp`,
`w-[480px]`→`480.dp`. Unsupported class → append to `unsupported` and emit a compile warning
(never silently drop). **Hand-written semantic classes** (`btn`, `card`, `pane-head`, `stat`,
`tok-chip`, `insp-*`, …) are on out-of-scope app components - route to the ignore set.

### Layout (decides Column/Row/Box for `<div>`-family; §6)

| class | effect |
|---|---|
| `flex` (no `flex-col`) | `Row` |
| `flex flex-col` | `Column` |
| `grid grid-cols-N` | `LazyVerticalGrid(columns=Fixed(N))` (or simple N-col `Column`+`Row` in v1) |
| `inline-flex` | `Row` |
| `block` / (none) | `Column` |
| `hidden` | wrap emission in `if (false)` / skip |
| `items-center` | Row→`verticalAlignment=CenterVertically`; Column→`horizontalAlignment=CenterHorizontally` |
| `items-start`/`items-end` | Start/End alignment |
| `justify-between`/`-center`/`-end` | `horizontalArrangement=Arrangement.SpaceBetween`/`Center`/`End` (axis by container) |
| `flex-1` | `.weight(1f)` |
| `flex-wrap` | `FlowRow`/`FlowColumn` |
| `shrink-0`/`flex-shrink-0` | (no-op v1; Compose doesn't shrink by default) |

### Spacing → Modifier

`p-N`→`.padding((N*4).dp)`; `px-N`/`py-N`→`.padding(horizontal=/vertical=…)`;
`pt/pr/pb/pl-N`→`.padding(top=/end=/bottom=/start=…)`; `m-*` same via `.padding` on parent
(Compose has no margin - fold into parent arrangement or an outer padding);
`gap-N`→`Arrangement.spacedBy((N*4).dp)` on the container; `space-y-N`→ same vertical.

### Sizing → Modifier

`w-full`→`.fillMaxWidth()`; `h-full`/`h-screen`/`min-h-screen`→`.fillMaxHeight()`;
`w-N`/`h-N`→`.width((N*4).dp)`/`.height(...)`; `w-1/3`→`.fillMaxWidth(0.333f)`;
`w-[17px]`→`.width(17.dp)`; `min-w-0`→`.widthIn(min=0.dp)`; `min-w-48`→`.widthIn(min=192.dp)`;
`max-w-xs/sm`→`.widthIn(max=320.dp/384.dp)`; `max-h-48/64`→`.heightIn(max=…)`;
`max-h-[70vh]`→`.heightIn(max=(0.70*screenHeight))` (needs `LocalConfiguration`).

### Color → token + Modifier  (maps semantic Tailwind theme → `JacDesign` tokens, §5)

`bg-<t>`→`.background(JacDesign.<map(t)>)`; `text-<t>`→ `color=` on `Text`;
`border-<t>`→ color arg of `.border`. Opacity suffix `/NN`→`.copy(alpha = NN/100f)`.
Numeric-scale colors (`bg-teal-500`, chart palettes) → a static `Color(0xFF…)` lookup table.
**Semantic → JacDesign map:** `bg`→`background`, `surface`→`surface`, `surface-2`→`softMuted`,
`fg`→`onBackground`, `muted`→`muted`, `faint`→`muted` (α .6), `line`→`muted` (α .3),
`accent`→`primary`, `accent-fg`→`onPrimary`, `accent-weak`→`softPrimary`,
`accent-hover`→`primary` (α .9), `success[-weak]`→`success`/`softSuccess`,
`warning[-weak]`→`warning`/`softWarning`, `danger[-weak]`→`danger`/`softDanger`,
`info`→`info`, `white`→`Color.White`. (Refine against the real theme JSON during M4.)

### Typography → `TextStyleParts` (applied on `Text`, §6)

`text-xs/sm/base/lg/xl/2xl/3xl`→`fontSize = 12/14/16/18/20/24/30 .sp`; `text-[10px]`→`10.sp`;
`font-medium/semibold/bold`→`FontWeight.Medium/SemiBold/Bold`; `font-mono`→`FontFamily.Monospace`;
`text-center/left/right`→`textAlign = TextAlign.Center/Start/End`;
`tracking-tight/wide/wider`→`letterSpacing`; `uppercase`→`text.uppercase()`;
`capitalize`→`replaceFirstChar…`; `truncate`→`maxLines=1, overflow=Ellipsis`;
`tabular-nums`→`fontFeatureSettings="tnum"`; `whitespace-nowrap`→`softWrap=false`;
`break-all/break-words`→`overflow`/`softWrap` tuning.

### Border / radius / effects / position

`border[-2]`→`.border((1|2).dp, color)`; edge `border-b/t/l/r`→`.drawBehind` line (v1: full
border); `rounded[-md/-lg/-full/-t]`→`.clip(RoundedCornerShape(4/6/8.dp | 50% | top))`;
`ring-1`→`.border` (focus ring); `shadow-sm/md`→`.shadow(2/4 .dp)`;
`opacity-80`→`.alpha(0.8f)`; `overflow-x-auto`/`-y-auto`→`.horizontalScroll(...)`/`.verticalScroll(...)`;
`overflow-hidden`→`.clipToBounds()`; `backdrop-blur-sm`→`.blur(...)` (defer);
`animate-spin`/`animate-pulse`→ known animated-modifier helpers (defer to M-later);
`relative`→ no-op; `absolute`+`inset-0`/`top-4`/`z-50`→ requires `Box` parent +
`.offset`/`.zIndex(50f)` + `.matchParentSize()`.

### Pseudo-variant prefixes (~70 total, low variety)

`hover:` / `group-hover:` → **drop in v1** (no hover on touch) + one-line diagnostic.
`focus:`/`focus-visible:` → drop v1 (or wire to `interactionSource` in form controls later).
`disabled:` → **do** apply, but only inside Button/Input where an `enabled` flag exists
(`disabled:opacity-50` → alpha when `!enabled`). `last:` → drop v1.
Responsive `sm:/md:/lg:/xl:` → resolve against `viewportWidth` (the `maxWidth` from
`BoxWithConstraints`) with breakpoints sm=640/md=768/lg=1024/xl=1280 dp; v1 may collapse to
the base utility and diagnose. No `dark:` exists in the corpus.

---

## 5. `JacDesign` token model (ported from `design_tokens_and_names.rs`)

36 Compose-state color tokens (camelCase) + `radius`, emitted into `DowePages.kt` via the
`JacDesign` singleton and mirrored in `JacTheme.kt` (`JacThemeModule.themes`). Base pairs:
`primary/onPrimary secondary/onSecondary tertiary/onTertiary muted/onMuted background/onBackground
surface/onSurface success/onSuccess info/onInfo warning/onWarning danger/onDanger`; soft pairs:
`softPrimary…onSoftDanger`. Color literal: `#RRGGBB`→`Color(0xFFRRGGBB)`, `#RRGGBBAA`→
`Color(0xAARRGGBB)` (alpha reordered to front, uppercase). `tailwind_to_modifier`'s semantic
map (§4) is the bridge from the `cl` theme names to these tokens. Theme JSON source = the
project's design config (same input the JS path reads); M4 wires the real values.

---

## 6. `compose_backend` - view_ir → Compose call tree

Walk `ViewElement` recursively. One routine handles the shared child union
(`ViewElement.children`, `IfChild.consequent/alternate`, `EachChild.body`). Per node:

- **`HostTag`** → look up the §-3 table in the plan (`div`→Column/Row/Box via
  `tailwind_to_modifier`; `span/p/hN`→`Text`; `button`→`Button`; `input`→`TextField`; etc.).
- **`ComponentTag`** → if the component is in the curated set (plan §"curated components"),
  emit its Compose analog; else emit a diagnostic (D3: sanctioned vocabulary only).
- **`FragmentTag`** → emit children with no wrapper.
- **`DynamicTag`** → diagnostic v1 (runtime-computed tag unsupported).
- **Attrs:** `StaticAttr`/`DynamicAttr` → composable param or Modifier (className→§4; `value`,
  `placeholder`, `type`, etc. → params). `EventAttr` (`onClick`, `onChange`…) → lambda param;
  the handler is pre-digested by `reactive_intent` into `StateUpdate`/`Effect`/`AsyncBoundary`,
  so emit `onClick = { <reactive lowering> }` (§7), falling back to `es_to_kotlin` of the raw
  handler for pure calls. `RefAttr` → bind to a `remember`ed ref. `SpreadAttr` → diagnostic v1.
- **Children:** `TextChild`/`DynamicChild` → `Text(<es_to_kotlin(value)>)`;
  `ElementChild` → recurse; `SlotChild` → `content()` slot param;
  `IfChild` → `if (<test→kt>) { <consequent> } else { <alternate> }`;
  `EachChild` → `<items→kt>.forEach { <item> -> <body> }`, promoted to
  `LazyColumn { items(<items>) { <item> -> … } }` when the list is the scroll container
  (mirrors Dowe `flow_nodes.rs:66`, which stays eager `forEach` - LazyColumn is our upgrade).

Each route becomes a `@Composable fun <Pascal>Screen(viewportWidth, scrollState,
sectionRegistry, navigate, goBack, openExternal)` (signature per Dowe `generated_views.rs:156`).
`JacApp` `when(path)` router ported verbatim from `foundation.rs:38` (see scaffold).

---

## 7. `reactive_compose` - reactive_intent → idiomatic Compose

Emitted at the top of each screen `@Composable` (before the view tree):

| intent | Kotlin |
|---|---|
| `StateField(name, init)` | `var name by remember { mutableStateOf(<init→kt>) }` |
| `RefField(name, init)` | `val name = remember { <init→kt> }` |
| `StateUpdate(name, value, aug_op=None)` | `name = <value→kt>` |
| `StateUpdate(…, aug_op="+")` | `name += <value→kt>` (map aug op via §3) |
| `Effect(body, deps=[], is_entry=T)` | `LaunchedEffect(Unit) { <body stmts→kt> }` |
| `Effect(body, deps=[a,b], is_entry=F)` | `LaunchedEffect(<a→kt>, <b→kt>) { … }` |
| `Effect(is_async=T)` | wrap body in `rememberCoroutineScope().launch { … }` |
| `AsyncBoundary(try, await, except)` | `scope.launch { try { <try→kt, await dropped> } catch (e: Exception) { <except→kt> } }` |

Imports needed (collect into the module import set): `androidx.compose.runtime.{getValue,
setValue, mutableStateOf, remember, LaunchedEffect, rememberCoroutineScope}`,
`kotlinx.coroutines.launch`. State reads inside the view already arrive as bare identifiers
because `ComposeBackend.lower_state_read` returns `Identifier(name)`.

---

## 8. `rpc_client` - the differentiator

Source: `InteropManifest.boundary_types: dict[str, BoundaryTypeInfo]` (`codeinfo.jac:323/349`)

- each `BoundaryTypeInfo` has `name, kind, fields: list[(name,type)], field_defaults,
enum_members, nested_types` - plus `walker_access: dict[str,bool]`. Runtime contract to match
(`client_runtime_core.impl.jac:132`): `POST {BACKEND_URL}/walker/{Name}[/{nodeId}]`, headers
`Content-Type: application/json`, `Accept: application/json`, `Authorization: Bearer <token>`;
response unwrap `payload["data"]`; 401 → clear token.

**Emit, for each `:pub` walker (`walker_access[name] == true`):**

```kotlin
@Serializable data class <Name>Request(val f1: T1, val f2: T2 = <default>, …)   // from fields
@Serializable data class <Name>Response( … )                                    // from report/return boundary type
```

Nested boundary types → nested `@Serializable data class`; enums → `@Serializable enum class`.
**Jac→Kotlin type map:** `str`→`String`, `int`→`Int` (widen to `Long` if annotated),
`float`→`Double`, `bool`→`Boolean`, `bytes`→`ByteArray`, `list[T]`→`List<T>`,
`dict[K,V]`→`Map<K,V>`, `T | None`→`T?`, custom obj→its data class, enum→its enum class.

**Client object (HttpURLConnection + kotlinx-serialization - no extra HTTP dep, keeps Dowe's
networking-light ethos while adding type safety):**

```kotlin
object JacClient {
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    var baseUrl: String = JacEnvironment.BACKEND_URL
    var token: String? = null
    suspend inline fun <reified Req, reified Res> call(
        walker: String, req: Req, nodeId: String? = null
    ): Res = withContext(Dispatchers.IO) {
        val url = URL(baseUrl + "/walker/" + walker + (nodeId?.let { "/$it" } ?: ""))
        (url.openConnection() as HttpURLConnection).run {
            requestMethod = "POST"
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Accept", "application/json")
            token?.let { setRequestProperty("Authorization", "Bearer $it") }
            doOutput = true
            outputStream.use { it.write(json.encodeToString(req).toByteArray()) }
            val body = inputStream.bufferedReader().readText()
            val data = json.parseToJsonElement(body).jsonObject["data"]!!
            json.decodeFromJsonElement<Res>(data)
        }
    }
    // + one typed wrapper per walker:
    suspend fun <name>(req: <Name>Request, nodeId: String? = null): <Name>Response =
        call("<Name>", req, nodeId)
}
```

An `AsyncBoundary` walker call (§7) resolves to `JacClient.<name>(<Name>Request(...))`.
**Acceptance guarantee (D4):** a renamed server `has` field changes the generated
`<Name>Request` field → any Kotlin call site referencing the old name fails to compile. Add a
test asserting exactly this.

---

## 9. Gradle scaffold deltas (over Dowe's verbatim templates)

Dowe's templates (captured verbatim, ready to port): `settings.gradle.kts`, root
`build.gradle.kts` (AGP 8.13.1, Kotlin 2.2.21, compose plugin), `gradle.properties`,
`app/build.gradle.kts` (namespace `dev.dowe.generated`→**parametrize to the app bundle**,
compileSdk 36/minSdk 26, Java 17, Compose BOM 2026.06.01 + material3 + ui + activity-compose
1.11.0), `AndroidManifest.xml` (INTERNET, `.MainActivity`, `dowe-dev://generated` deep link),
`styles.xml`, `MainActivity.kt`, `JacEnvironment.kt` (`BACKEND_URL`), `JacRouting.kt`,
`JacTheme.kt`, `JacLayouts.kt`, `JacResponsive.kt`, and the `JacApp` `when(path)` router.

**Deltas we add for typed RPC (Dowe has none):**

- root `build.gradle.kts` plugins: `+ id("org.jetbrains.kotlin.plugin.serialization") version "2.2.21" apply false`
- `app/build.gradle.kts` plugins: `+ id("org.jetbrains.kotlin.plugin.serialization")`
- `app/build.gradle.kts` deps:
  `+ implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")`
  `+ implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")`
  (HTTP stays on `java.net.HttpURLConnection` - no Retrofit/Ktor/OkHttp dep.)
- **Parametrize the package** `dev.dowe.generated` → the project's bundle id (namespace,
  `package` declarations, source dir `app/src/main/java/<pkg path>/`). Dowe hard-codes it.

Emitted `.kt` files under `app/src/main/java/<pkg>/`: `MainActivity.kt`, `JacRouting.kt`,
`JacEnvironment.kt`, `JacTheme.kt`, `JacLayouts.kt`, `JacResponsive.kt`, `Screens.kt` (our
composables + `JacApp` + `JacDesign`), **`JacClient.kt`** (new - typed RPC), `GeneratedViews.kt`.

---

## 10. `AndroidTarget` (mirror `ReactNativeTarget`)

`obj AndroidTarget(ClientTarget)` - `name="android"`, `requires_setup=True`,
`config_section="android"`, `output_dir=Path("apps/android/app/build/outputs")`. Register in
`targets/register.jac:23`; add `ANDROID="android"` to `TargetType` and an alias in
`get_target_type` (`targets/registry.jac`). CLI `--client android --platform android` then
reaches `AndroidTarget.build` with no other CLI change (choices auto-sync via
`sync_client_target_choices`).

- **`setup(project_dir)`**: ensure `apps/android/` scaffold exists (idempotent), write
  `[client.android]` into `jac.toml`, verify JDK/Android SDK/Gradle availability.
- **`build(entry, project_dir, platform)` → `Path`**:
  1. `(model, mod) = self._compile_compose_modules(entry)` - the codegen hook: get
     `program = Jac.program`, `mod = program.compile(entry)`, run inference schedule
     (`get_inference_sched` → `program.run_schedule`), then run `EsastGenPass(ir_in=mod,
     prog=program)` **with the compose backend active** (config `framework="compose"`), and
     read `ComposeBackend.model` (stash it on `mod.gen.compose_model`). Mirror
     `client_bundle.impl.jac:14-27`'s `_ensure_js_generated`, swapping the backend.
  2. `ComposeEmit(model, out=project_dir/"apps/android").write()` - the whole Kotlin project.
  3. Run Gradle: `run_gradle_assemble(project_dir/"apps/android", release=…)` (reuse/mirror
     the helper `MobileTarget._build_android` uses).
  4. `return` the produced `.apk` `Path`.
- **`dev`**: Gradle `installDebug` + `adb` launch + Jac API backend (v1 may stub → full
  rebuild on change; DEX hot-reload deferred).
- **`start`**: `build` then `adb install`/launch (mirror `ReactNativeTarget._start_android`).

Codegen-hook refs: `client_bundle.impl.jac:14-27` (`_ensure_js_generated`),
`react_native_target.impl.jac:342-372` (`_compile_native_jac_modules`), CLI dispatch
`runtimelib/client/cli.jac:173`.

---

## 11. Milestones → tasks (acceptance criteria)

**M0 - Skeleton & dispatch**

- T0.1 Create `compiler/passes/compose/` + `backends/compose.jac` stub (`ComposeBackend`
  returns placeholder estree, records nothing yet). Register `"compose"` in
  `backends/registry.jac`.
- T0.2 `AndroidTarget` + registration + `TargetType.ANDROID`. `build` writes an empty
  Gradle project (scaffold only) and runs Gradle.
- ✅ *Accept:* `jac build --client android --platform android` produces an `.apk` that installs
  and launches to a blank Activity.

**M1 - Static render**

- T1.1 `kotlin_ast.jac` + `kotlin_unparse.jac` (round-trip a hand-built tree to source).
- T1.2 `es_to_kotlin.jac` expression subset (§3 expressions) with unit tests per node.
- T1.3 `tailwind_to_modifier.jac` layout+spacing+sizing+color+typography buckets (§4) + a
  diagnostic for unsupported classes.
- T1.4 `compose_backend.jac` host-tag + curated-component vocab (§6); `ComposeBackend.lower_view`
  records; `ComposeEmit` writes `Screens.kt`.
- ✅ *Accept:* a static `Card.cl.jac`/`Button.cl.jac` route renders on device pixel-close to
  the web layout; Gradle compiles clean; unsupported classes surface as build warnings.

**M2 - Reactivity**

- T2.1 `reactive_compose.jac` (§7); `ComposeBackend` records state/ref/update/effect;
  `lower_state_read`→bare identifier, `lower_state_update`→assignment.
- T2.2 `es_to_kotlin` statement subset (§3 statements) for `Effect.body`.
- ✅ *Accept:* an interactive counter + a controlled `<input>` form work on device
  (state updates recompose; two-way binding round-trips).

**M3 - Typed RPC (differentiator)**

- T3.1 `rpc_client.jac` from `InteropManifest.boundary_types` + `walker_access` (§8);
  emit `JacClient.kt` + `@Serializable` types; Gradle deltas (§9).
- T3.2 `AsyncBoundary` → `JacClient.<walker>(...)` call.
- ✅ *Accept:* a `:pub` walker call round-trips against a live `jac serve` backend; **and** a
  test proving a renamed server field breaks Kotlin compilation.

**M4 - Scaffold hardening & parity**

- T4.1 Real theme/design-token values (§5) from project config; `JacDesign` + `JacThemeModule`.
- T4.2 Routing/sections, `strings.xml` i18n, `JacEnvironment` from project env, package
  parametrization.
- T4.3 Parity diff vs. Dowe `artifacts.rs` output; fix gaps.
- ✅ *Accept:* a multi-route app with theming, navigation, and a live RPC form builds and runs
  end-to-end from `jac build --client android`.

**Deferred (post-v1):** DEX hot-reload dev host (`dev_*`), charts/canvas/media/editor widgets,
Nav-Compose, arbitrary component lowering, animated SVG, `hover:/focus:` interaction states,
responsive-breakpoint resolution beyond base utilities.

---

## 12. Open decisions / risks

1. **Placeholder-estree tolerance - RESOLVED / eliminated.** ~~ComposeBackend returns dummy
   `es.*` so `EsastGenPass`'s estree finalization doesn't crash.~~ **Superseded (2026-07-28):**
   `ComposeBackend` is **deleted**. Android now runs `IntentCollector` → `ComposeEmit` with no
   `FrameworkBackend` and no `lower_*` calls (`PLAN.md` F1, P0+P1 done). The tolerance risk is
   eliminated by construction: the only placeholder-estree left is 2 tiny generic helpers in
   the `IntentCollector` (the minimal eager-splice residue), not a `FrameworkBackend` lying
   across its whole interface. The sibling-`ComposeGenPass` fallback (D1) was never needed and
   is also superseded.
2. **`m-*` margins / `space-*`.** Compose has no margin; must fold into parent arrangement or
   outer padding. Pick one convention (recommend: emit margin as parent-side padding) and apply
   consistently.
3. **Curated-component fidelity.** The curated `common/` components are themselves `.cl.jac`
   that expand to host tags - decide whether v1 *inlines* their view IR (simplest, reuses the
   host-tag path) or maps each to a bespoke `@Composable`. Recommend **inline** for v1.
4. **`report` vs return envelope.** Confirm the response `data` shape for a walker that uses
   `report` vs a typed return (`esast_gen_pass.impl.jac:1293`) so `<Name>Response` matches.
5. **Package/bundle parametrization** touches every emitted file - bake it into `ComposeEmit`
   from day one rather than retrofitting.
6. **Int division & numeric widening** (`/`, `int`→`Int` vs `Long`) - acceptable v1, revisit if
   arithmetic-heavy views appear.
</content>

</invoke>
