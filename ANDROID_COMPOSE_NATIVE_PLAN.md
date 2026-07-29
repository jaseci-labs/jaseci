# Jac → Jetpack Compose (native, "lose-nothing") - architecture & migration plan

**Decision (2026-07-28):** Build the Android target as **Option 2 - a Compose-faithful Jac
client surface**, not a neutral cross-platform UI IR (Option 1 / the Dowe model).

**Rationale.** React "loses nothing" on web *because the `cl` source is web-shaped* (DOM +
Tailwind + JSX) - React is a near-identity lowering. The same *treatment* for Android means a
**Compose-shaped source surface** where Jetpack Compose is *also* a near-identity lowering.
A neutral IR (Dowe) buys write-once portability at the cost of a sanctioned, bounded
vocabulary - the opposite of the property we want. **Cross-platform single-codebase is
already served by the existing React Native target** (`react_native_target.jac`); this target's
job is native-Compose parity, so a native Android dev adopts Jac and gives up nothing.

## The three client surfaces (the mental model)

Same JSX-in-Jac authoring, three component vocabularies - exactly the web-vs-RN split, extended:

| Surface | Vocabulary | Target | Lowering |
|---|---|---|---|
| `cl` web | DOM tags + Tailwind (`<div class="flex">`) | React/Preact/Solid | near-identity → JSX |
| `cl` RN | RN components (`<View>`, `<Text>`) | React Native | near-identity → RN |
| **`cl` compose (NEW)** | **Compose primitives (`<Column>`, `<Text>`, `<Button>`, `Modifier`)** | **Jetpack Compose** | **near-identity → Kotlin** |

All three sit on the **same shared, already-backend-agnostic reactive/RPC/navigation core**
(`IntentModule`: `StateField`/`RefField`/`Effect`/`AsyncBoundary`/routes, and the typed-RPC
`@Serializable` client). That half is the good part of today's design and it is *kept*.

## What the source looks like (the whole pitch)

**Web `cl` (today):**

```jac
def:pub Counter() -> JsxElement {
    count = use_state(0);
    return <div className="flex flex-col gap-2 p-4">
        <span className="text-lg">{count}</span>
        <button onClick={() => count.set(count + 1)}>Increment</button>
    </div>;
}
```

**Compose `cl` (new surface):**

```jac
def:pub Counter() -> Composable {
    count = use_state(0);
    return <Column modifier={Modifier.padding(16).fillMaxWidth()}
                   verticalArrangement={Arrangement.spacedBy(8.dp)}>
        <Text style={Typography.titleLarge}>{count}</Text>
        <Button onClick={() => count.set(count + 1)}><Text>"Increment"</Text></Button>
    </Column>;
}
```

**Lowers near-identity to Kotlin - nothing inferred, nothing dropped:**

```kotlin
@Composable
fun Counter() {
    var count by remember { mutableStateOf(0) }
    Column(modifier = Modifier.padding(16.dp).fillMaxWidth(),
           verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(count.toString(), style = MaterialTheme.typography.titleLarge)
        Button(onClick = { count += 1 }) { Text("Increment") }
    }
}
```

`Column`/`Row`/`Box` are **explicit in the source** (never sniffed from `flex-col`); `Modifier`
is a **first-class Jac expression** mapping 1:1 to Compose's `Modifier` (no Tailwind parser);
the component set is **open** - any `@Composable` you declare or import, not a curated table.

## Target pipeline

```
*.cl.jac (Compose surface)
   │  ComposeGenPass  - walks `uni` DIRECTLY (sibling to EsastGenPass; NOT inside it)
   │    ├─ IntentCollector (reused)   → IntentModule   [state/effects/async/routes - shared, neutral]
   │    ├─ ComposeViewBuilder (NEW)   → Compose view IR [Composable calls + Modifier chains - native]
   │    └─ JacToKotlin (NEW)          → kotlin_ast      [ALL expr/stmt leaves - replaces es_to_kotlin]
   ▼
   Compose view IR + IntentModule (kotlin_ast leaves)
   │  KotlinEmit
   │    ├─ reactive_compose (reused)  : IntentModule → mutableStateOf / LaunchedEffect / coroutine
   │    ├─ compose_emit    (adapted)  : view IR → @Composable functions
   │    ├─ rpc_client      (reused)   : InteropManifest → @Serializable + suspend client
   │    └─ gradle_scaffold (reused)   : project + Manifest + theme + HMR
   ▼
   Gradle project → APK   (AndroidTarget + HMR - reused)
```

### Deleted (the lossy tax)

- **`tailwind_to_modifier.jac`** (~421 LOC) - no Tailwind on this surface; `Modifier` is first-class.
- **`es_to_kotlin.jac`** (~678 LOC) - replaced by `jac_to_kotlin` (uni → kotlin_ast). Removes the
  whole class of JS-semantics leakage: `===`/`!==` normalization, JS integer-division/widening,
  `mapOf`-from-object-literal, `__jacSpawn`/`_jac.*` re-special-casing.
- **`_COMPOSE_MODULE` process-wide singleton** - replaced by a pass-scoped module.
- **Placeholder estree** (`_placeholder_stmts`/`_placeholder_expr`) - the Compose path never
  touches the estree spine, so there is nothing to fake.
- **Curated host-tag / `_CURATED` component allowlist** - vocabulary is open; off-list is a
  real user component, not a `/* unsupported */` Column.

### Kept as-is / adapted

- `kotlin_ast.jac`, `kotlin_unparse.jac` - pure Kotlin AST + unparser; reused verbatim.
- `reactive_compose.jac` - `IntentModule` → Compose reactivity; reused, fed kotlin_ast leaves.
- `rpc_client.jac` - the typed-RPC differentiator; reused unchanged.
- `gradle_scaffold.jac`, `compose_emit.jac`, `android_target.*` + HMR - reused; `compose_emit`
  adapted to the native view IR shape.
- `IntentModule`/`IntentCollector`/`reactive_intent` - reused; **one refactor** (below).

## The one real refactor: neutral expression leaves

Today `reactive_intent`/`view_ir` leaves are typed `es.Expression`/`es.Statement`. The Compose
path must carry `kotlin_ast` leaves instead. Make the reactive/view IR **generic over its leaf
type** (or introduce a small `LoweredExpr` sum: `EsLeaf | KtLeaf`), so the *same* intent-detection
logic serves a JS-leaf target (estree) and a Kotlin-leaf target (kotlin_ast). This is what finally
severs the Compose path from the JS spine: `ComposeGenPass` lowers Jac expressions to Kotlin at
collection time and stores kotlin_ast - it never produces or discards estree.

**Why jac→kotlin is *more* faithful than es→kotlin:** Jac has real, typed numeric semantics, so
`==` → Kotlin structural `==` (correct, vs JS `===` hacks), `/` vs `//` map to true float/int
division (kills the conceded integer-division bug), f-strings → Kotlin string templates, `dict`/
`list` → `mapOf`/`listOf` with element types. We translate Jac's own semantics, not JavaScript's.

## Component model - open vocabulary + escape hatch

1. **Compose primitive surface** (Jac stdlib): thin `def:pub`/extern declarations for the Material3
   - foundation set (`Column`, `Row`, `Box`, `Scaffold`, `LazyColumn`, `Text`, `Icon`, `Image`,
   `Button`, `OutlinedTextField`, `Card`, `TopAppBar`, `Checkbox`, `Switch`, …) and the `Modifier`
   builder. Each maps 1:1 to the real Compose call - the emitter recognizes them structurally.
2. **User composables are first-class:** `def:pub Foo(...) -> Composable { return <...>; }` →
   `@Composable fun Foo(...)`. No allowlist; your components compose like Compose's.
3. **Raw-Kotlin escape hatch:** a `kotlin { ... }` inline block / `@raw` composable for anything
   not yet surfaced (custom draw, third-party libraries, platform APIs). Guarantees "lose nothing"
   even before the primitive surface is complete - the RN "native module" equivalent.

## Reactive / RPC / navigation - reused, not reinvented

- **Reactivity:** `reactive_compose` already maps `StateField→mutableStateOf`, `RefField→remember`,
  `Effect→LaunchedEffect`, async→`rememberCoroutineScope().launch`, `AsyncBoundary→try/catch in
  coroutine`. Unchanged; now fed kotlin_ast leaves so bodies are real Jac→Kotlin, not JS→Kotlin.
- **Typed RPC (the differentiator):** `InteropManifest.boundary_types` → `@Serializable data class`
  - `suspend fun` client. Renaming a server field breaks Kotlin compilation. Kept exactly.
- **Navigation:** the existing `when(path)` router + `SharedPreferences` route persistence; a
  Nav-Compose upgrade is a later, isolated swap.

## Migration phases (each ends green)

- **M0 - Fork the surface & pass.** Add `ComposeGenPass` (walks `uni`); register the Compose
  component surface; a trivial `<Column><Text>"hi"</Text></Column>` compiles to a `@Composable`
  and builds under Gradle. No estree involvement. *Gate:* JS fixtures untouched & green.
- **M1 - `jac_to_kotlin` expression/statement lowering.** Replace `es_to_kotlin` for this path:
  literals, identifiers, member/call, binary/logical/unary, conditional, f-strings, collection
  literals, lambdas; statements (block/if/for/while/return/try) for effect bodies. *Gate:* golden
  Kotlin snapshots per construct; numeric-semantics tests (`/` vs `//`, `==`).
- **M2 - `ComposeViewBuilder` + native view IR.** Compose-shaped nodes (composable call + Modifier
  chain + trailing children; `If`/`For` → `if`/`forEach`/`LazyColumn`). `Modifier` expression
  lowering. Delete `tailwind_to_modifier`, the host-tag switch, `_CURATED`. *Gate:* Counter/list
  example renders; snapshot Kotlin.
- **M3 - Leaf-type refactor + singleton kill.** Generalize reactive/view IR leaves; pass-scoped
  module; delete `_COMPOSE_MODULE` + placeholder estree. *Gate:* JS path still byte-identical;
  Compose path independent of `EsastGenPass`.
- **M4 - Reactivity + typed RPC end-to-end.** Interactive counter/form on emulator; an
  `AsyncBoundary` walker call round-trips to a live Jac server; renamed-field → Kotlin compile
  error test. *Gate:* on-device run (first real compile/run gate - today's tests are string-match
  only).
- **M5 - Primitive surface breadth + raw escape hatch + scaffold parity.** Grow the Material
  surface; `kotlin { }` block; theme/typography/icons; HMR re-verified on device.

## Risks / open questions

- **Authoring ergonomics of `Modifier` in JSX-Jac** - validate the `modifier={Modifier.…}`
  chain reads well; consider a Jac-side builder sugar. (Prototype in M2.)
- **jac→kotlin coverage** is the new bounded surface, but it's *Jac* (a language we own and can
  restrict), not unbounded Tailwind - coverage is finite and testable, unlike class strings.
- **On-device verification is the real gap today** - M4 introduces the first compile/run gate;
  everything before it is snapshot-tested.
- **`Composable` return type** needs to be a first-class Jac type the checker understands (so
  `-> Composable` typechecks and user composables compose). Define in M0.
- **Two authoring surfaces to document** - web/RN `cl` vs Compose `cl`. Acceptable: it's the
  RN-vs-web split users already understand; the shared reactive/RPC core keeps the mental model one.

## Supersedes

This supersedes `ANDROID_COMPOSE_PLAN.md` (the "transpile web-shaped IR + Tailwind → Compose"
approach) and the `PLAN.md` IntentCollector extraction *as the Android strategy*. The
IntentCollector/`IntentModule` work is **retained** - it is the shared reactive core all three
surfaces sit on. What changes is the **view/style/expression** half: native Compose surface +
`jac_to_kotlin`, replacing DOM view IR + Tailwind strings + `es_to_kotlin`.
