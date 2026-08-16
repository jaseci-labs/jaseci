# PROGRESS.md - android-probe branch

Tracks work on the Jac → Android (Jetpack Compose) target. See PLAN.md for the
umbrella roadmap. Update this as work lands.

## This branch's scope

Review findings on the Compose lowering/emit path.

### A1 - typed const namespaces (Arrangement / Alignment) (DONE)

`_install_compose_consts` already installed every `compose_consts.txt` member
onto its `<Name>Namespace` class, but typed them via the generic
`_map_kotlin_type`, which strips to the last dot-component. For `Color.*` the
ptype is the scalar `long`, so named colors were already `int` - but
`Arrangement.Center` (`Arrangement.HorizontalOrVertical`) and
`Alignment.CenterVertically` (`Alignment.Vertical`) collapsed to `foreign-any`,
and so did the matching widget layout params (`Column.verticalArrangement`,
`Box.contentAlignment`, …) for the same reason. Worse, the last-component strip
collides `Arrangement.Vertical` and `Alignment.Vertical` onto one token, so they
could not be told apart.

**Fix:** a single recognition seam, `_compose_layout_type_for`, runs first inside
`_map_kotlin_type` and matches the family by its AndroidX package path
(`compose.foundation.layout.arrangement` / `compose.ui.alignment`) - before the
collision-prone strip - mapping both the bare namespace type and its nested
subtypes onto the one ingested `<Name>Namespace` instance (resolved once and
memoized in `_compose_layout_inst_cache`). One seam unifies two surfaces:

- the named constants: `Arrangement.Center` → `ArrangementNamespace`,
  `Alignment.CenterVertically` → `AlignmentNamespace` (no longer `foreign-any`);
- the widget layout params: `Column.verticalArrangement` → `ArrangementNamespace`,
  `Box.contentAlignment` → `AlignmentNamespace`.

DX payoff: the tighter param types now surface at Jac compile time what used to
slip through to Kotlin - an arrangement/alignment mixup
(`<Column verticalArrangement={Alignment.CenterHorizontally}>`) and a bare
string (`verticalArrangement="center"`) are both flagged, while the correct
pairing stays clean.

`Color(0xFF…)` (the ULong constructor via `ColorNamespace.__call__`) is
unaffected; named colors stay `int` until A2 promotes `Color` to a value class.

**Files:** `type_system/type_evaluator.jac` (cache attr + decl),
`type_system/type_evaluator.impl/ts_declarations.impl.jac` (the seam + the
`_map_kotlin_type` short-circuit). **Tests:** two new cases in
`test_compose_extensions.jac` Part 4 pin the non-any member/param types and the
mixup/wrong-type catches. Verified: `test_compose_extensions.jac` 36/36,
`test_compose_stub_gen.jac` 11/11.

### Blocker 1 - Jac arithmetic semantics not preserved (DONE)

`jac_to_kotlin` lowered Jac `/`, `//`, `%` straight onto Kotlin operators, which
adopt Kotlin's (not Jac's) semantics:

- Jac `/` always yields a float; Kotlin `Int / Int` truncates (`7 / 2` → 3).
- Jac `//` floors toward -inf; Kotlin integer division truncates toward zero.
- Jac `%` takes the divisor's sign; Kotlin `%` takes the dividend's.

The masking test (`test_compose_gen_pass` "maps floor div") asserted `7/2` was
acceptable output, hiding the defect.

**Fix (runtime helpers, mirroring the esast backend's `_rt` pattern):**

- `compose/impl/jac_to_kotlin.impl.jac` - intercept `DIV`/`FLOOR_DIV`/`MOD` and
  emit `JacMath.truediv/floorDiv/mod(...)` calls (removed those three from
  `_JAC_BINARY_OPS`). Call args are comma-delimited, so this sidesteps the
  `KtBinary` precedence hazard entirely; Kotlin overload resolution preserves
  the Jac result type (Int operands → Int, a float operand → Double).
- `compose/impl/compose_emit.impl.jac` - always emit `JacMath.kt` (same package
  as `Screens.kt`, no import needed) with Int/Long/Double/Number overloads:
  `Math.floorDiv`/`Math.floorMod` for integers, `kotlin.math.floor`/the
  `((a%b)+b)%b` formula for Double.
- Tests: replaced the masking test with negative/int/float coverage
  (`test_compose_gen_pass` "lowers Jac division semantics to JacMath helpers");
  added a runtime-content test (`test_compose_emit` "JacMath runtime encodes …").

Verified: `test_compose_gen_pass` 20/20, `test_compose_emit` 14/14.

### Blocker 2 - repeated export names overwrite on merge (DONE)

`IntentModule.merge_from` keyed components by source export name. The router
lets distinct files share an export name (every page can export `View`); the
path-derived `component_import` is the unique identity. So N pages exporting
`View` collapsed to one component in the aggregate model, and every route
rendered the last-merged page.

**Fix:**

- `compose/compose_model.jac` - `ComposeModule.rename_component(old, new)`
  re-keys both `intent.components` and `compose_views` (and updates `comp.name`)
  so `emit_component_view`'s `compose_view_for(comp.name)` lookup still resolves.
- `runtimelib/.../android_target.impl.jac` (+`.jac` decl) -
  `_compile_page_into_model` now returns `(page_mod, page_model)` without
  merging; `_populate_compose_routes` re-keys each page's component to its
  `component_import` **before** merging, then binds `IntentRoute.component` to
  `component_import` (not `source_export`).
- Test: `test_compose_emit` "repeated export names merge to distinct components
  by component_import" - two pages exporting `View` survive as
  `PagesIndex`/`PagesAbout`.

Verified: `test_android_devserver` 3/3 (exercises the route flow).

### Issue 3 - non-reactive augmented assignments lost their operator (DONE)

`jac_to_kotlin.convert_stmt` lowered non-reactive augmented assignments
(`total += 5`) with a hardcoded `operator='='`, dropping the operator
(`total += 5` → `total = 5`). The reactive path already used
`assignment_kt_op(nd)`; the non-reactive path duplicated that logic with the
wrong operator.

**Fix:** merged the reactive and augmented branches into one path that uses
`assignment_kt_op(nd)` for all augmented (and reactive) assignments -
`compose/impl/jac_to_kotlin.impl.jac`. Regression test
`test_compose_gen_pass` "non-reactive augmented assignment preserves the
operator in Kotlin" (added in `c463f0695`) covers `+=`/`-=`/`*=` on a
non-reactive local. (`//=` still drops its operator - see the compound-
assignment follow-up below; out of scope here.)

### Issue 4 - common JSX return forms silently produced empty/incorrect UI (DONE)

`ComposeGenPass.exit_ability` captured a component's view only when the JSX
was the direct expression of a single top-level `ReturnStmt`; conditional,
variable, and multiple returns were ignored or overwritten, so `ComposeEmit`
shipped an empty or incorrect screen with no warning.

**Fix (recursive lowering + no-silent-failure safety net):**

- `compose_view_builder` - new `lower_component_view(stmts)` walks the body:
  a direct `return <Jsx>` lowers to that element; an `if/else` whose branches
  return JSX lowers to a `ComposeIfChild` held in a nameless fragment root.
  `convert_expr` now handles the `AtomUnit` wrapper (a bare-name condition
  like `if (flag)` previously hit "unsupported expression AtomUnit").
- `compose_native_emit.emit_view` - a nameless fragment root emits its body
  items inline (no wrapper container), so an `if/else` return becomes a Kotlin
  `if (…) { … } else { … }` at the top of the composable.
- Safety net: any JSX the lowering cannot cover (a non-direct return, a branch
  that doesn't all return, an early return shadowing later JSX, …) appends a
  diagnostic via the builder's existing `diagnostics` list, which makes
  `ComposeEmit` raise instead of shipping a broken screen. Lambda bodies are
  excluded from the coverage check (they are their own composable scopes).
- Tests: `test_compose_gen_pass` "JSX nested in an if/else return lowers to a
  Kotlin if/else" (positive); "JSX returned via a variable surfaces a
  diagnostic …" and "multiple top-level JSX returns surface a diagnostic …"
  (the safety net).

Verified: `test_compose_gen_pass` 21/21, `test_compose_emit` 14/14,
`test_android_devserver` 3/3.

**Parser limitation flagged (variable-bound JSX):** `name = <Jsx>` is not
expressible as an assignment in Jac today - the JSX RHS makes the parser split
it into bare expression statements (`node`, `<Jsx>`), so `node = <Column/>;
return node;` never forms a binding (confirmed across plain, `has`-declared,
typed-local, parenthesized, and self-closing forms). Such a body now surfaces a
diagnostic instead of failing silently; real lowering needs a parser change on a
separate branch.

### Issue 5 - development server path traversal (DONE)

The HMR dev server appended an unchecked URL segment to `modules_root` and
bound `0.0.0.0` (network-exposed). Now:

- `dev_server._resolve_versioned_dex` requires the version segment to be exactly
  the generated shape - the first 16 hex digits of a sha256 digest
  (`AndroidTarget._build_hot_dex` → `hasher.hexdigest()[:16]`) - via
  `_is_hex_version`. This rejects every traversal vector (`..`, `.`, separators)
  outright.
- Defense in depth: the resolved path is still checked to remain under
  `modules_root` (`Path.relative_to`).
- `start_jac_dev_server` binds `127.0.0.1` only (the device reaches it over
  `adb reverse` → localhost).
- Tests: `test_android_devserver` covers the live serve + traversal (16-hex
  `fedcba9876543210`), loopback binding, and a unit test that short/non-hex/
  wrong-length/traversal segments all resolve to None.

Verified: `test_android_devserver` 3/3.

### Issue 6 - missing Android tools bypassed intended diagnostics (DONE)

`AndroidTarget._locate_android_tools` initialized `d8`/`android_jar` to
`Path("")`, which normalizes to `.` (truthy), so the `if not str(d8)` / `if not
str(android_jar)` missing-tool guards never fired. Now both use explicit
`(Path | None) = None` sentinels and `is None` checks, so a missing d8 or
android.jar raises the intended `RuntimeError`.

### Issue 7 - screen navigation callbacks mistyped vs the host router (DONE)

CI `test-android-compose` / `test-android-compose-device` failed in
`compileDebugKotlin`: the host `JacApp` wires `navigate`/`openExternal` as local
functions taking typed enums (`JacNavOperation`, `JacExternalMode`), but
`_emit_screen_fun` (`compose_emit.impl.jac`) declared the per-screen callback
props with `String` first params. Passing `::navigate`/`::openExternal` was
then inapplicable (Kotlin function types are contravariant in params), so the
APK would not compile. Introduced by `d88cfcdac`.

**Fix:** changed the screen signature to `navigate: (JacNavOperation, String,
String?) -> Unit, ... openExternal: (JacExternalMode, String) -> Unit`, matching
the host and the typed-enum design locked by `test_compose_emit` #7. No screen
body emits these calls yet, so the only requirement was reference-type parity.

Also unblocked the `jac-check` formatting step: 13 compose/android sources
violated the project's opted-in `strip-comments`/formatting standard, so ran
`jac fmt --lintfix` (the CI autofix) across them; full-tree
`jac fmt --check --lintfix` is clean. Commit `c62b1a221`.

Verified: APK `BUILD SUCCESSFUL`; `test_compose_emit` 14/14,
`test_compose_gen_pass` 21/21, `test_android_devserver` 3/3.

### Issue 8 - adb boot poll assigned None to a CompletedProcess var (DONE)

`jac check` failed on `runtimelib/client/mobile_dev_host.jac:157`:
`error[E1001]: Cannot assign NoneType to CompletedProcess[str]`. The retry loop in
`wait_for_adb_device_boot` did `r = subprocess.run(...)` in the `try` (inferring
`r: CompletedProcess[str]`) and then `r = None` in the `except`, which the checker
rejects - narrowing a concrete type to `None` needs an explicit `... | None`
declaration. An upfront union annotation was tried first but `subprocess.run`'s
`CompletedProcess[str]` attributes resolve to `Unknown` under that annotation,
producing a cascade of new E1032s.

**Fix:** moved the boot-check *inside* the `try`, right after `run`, so `r` is
only ever a concrete `CompletedProcess[str]` (exactly how the sibling
`list_adb_devices` already checks `.returncode`/`.stdout`). The `except` now just
swallows the timeout/error (`} except Exception { }`) and falls through to the
existing `time.sleep(2)` retry - semantics unchanged, no `None`, no guard, no
extra variable. `strip-comments`-clean (no comment).

Verified: `jac check` on the file passes; it was the sole error in the full
`jac check . --ignore ...` run (the only `error[E...]` in the whole repo).

### Issue 9 - duplicate E5082 broke compose type-check tests (DONE)

CI `test-compiler` failed 7 tests in `test_compose_extensions.jac` with
`(missing key: 'name')` on E5082. Commit `8e5b634ad` added a compose-framework
guard reusing code `E5082`, clobbering the existing client-import diagnostic.
`EsastGenPass._ensure_backend` then emitted the import template without
`name`/`module` kwargs. The test helper also passed `no_cgen=True` as a
positional arg while supplying `CompileOptions(...)` without `no_cgen`, so
codegen still ran and hit the guard during type-check-only snippets.

**Fix:**

- `diagnostics.jac` - restore `E5082` for dead client imports; move compose
  framework guard to new `E5086` (was briefly `E5085`, but that collided with
  upstream's hoist error - see self-review sweep below).
- `esast_gen_pass.impl.jac` - emit `E5086` for compose-on-web.
- `test_compose_target_guard.jac` - expect `E5086`.
- `test_compose_extensions.jac` - pass `no_cgen=True` inside `CompileOptions`.

Verified: `test_compose_extensions.jac` 34/34, `test_compose_target_guard.jac` 2/2
(re-run 2026-08-08 after E5086 reallocation: 2/2).

## Known follow-ups (NOT in this change - flagged)

- **Compound-assignment arithmetic (`/=`, `//=`, `%=`) shares Blocker 1's
  defect** and was left out of scope. `detection.jac`'s `ASSIGNMENT_KT_OPS`
  maps `DIV_EQ→'/='`, `MOD_EQ→'%='` (truncate for Int), and `FLOOR_DIV_EQ`
  (`//=`) is absent so `assignment_kt_op` returns `'='` - i.e. `count //= 2`
  lowers to `count = 2` (division dropped entirely). The `JacMath` helpers are
  in place; the fix is to lower these to `count = JacMath.<op>(count, value)`.
  Raise on a separate branch per the one-thing-per-branch rule.
- ~~`test_compose_extensions.jac` "wrong-typed value arg …" fails on the clean
  commit (pre-existing, unrelated - a client-side-presence portability
  diagnostic), confirmed via stash.~~ Fixed in Issue 9 (duplicate E5082).

## Self-review blocker sweep (2026-08-08)

Five confirmed defects found in a multi-agent code review of the branch diff vs
`upstream/main`, all fixed in place (defects in this PR's own work → same branch):

1. **Missing import → `NameError` on `jac start --client android`.**
   `android_target.impl._adb_install_launch` called `adb_install_and_launch`
   (the non-`--dev` install/launch path) but the `client_dev_common` import block
   omitted it; the RN sibling imports it. Added to the import block. No test
   covered this path (why it slipped) - follow-up: cover `_adb_install_launch`.
2. **Duplicate diagnostic code `E5085`.** `upstream/main` already owns `E5085`
   (the codegen "hoisted declarations never emitted" error). Issue 9 moved the
   compose-on-web guard onto `E5085` believing it free, so the two collided and
   the last definition won - `self.emit(E5085)` for compose rendered the *hoist*
   message with unfilled `{names}`/`{scope}`. Reallocated the compose guard to
   the free **E5086** (`diagnostics.jac`, `esast_gen_pass.impl` inline import +
   emit, `test_compose_target_guard.jac`). The E5085 top-level import + emit at
   `esast_gen_pass.impl:7545` legitimately stay (the hoist error).
3. **Kotlin unparser dropped precedence parens.** `gen_kt_binary` /
   `gen_kt_conditional` emitted un-parenthesized output (`(a+b)*c` → `a + b * c`,
   `(a+b).dp` → `a + b.dp`) - a regression vs the sibling `es_unparse`, which
   fully parenthesizes. Now wraps binary + conditional (`KtConditional` is the
   expression form, distinct from statement `KtIf`) and parenthesizes a
   `KtUnary` member-access receiver.
4. **Silent wrong-operator fallback in `jac_to_kotlin`.** `_JAC_BINARY_OPS.get(k,
   '+')` / unary `'-'` / compare `'=='` meant any unmapped op (e.g. `**`,
   `STAR_POW`, mapped nowhere) miscompiled with no diagnostic. Now appends a
   `self.diagnostics` entry and returns `_unsupported(...)` instead of guessing.
   Follow-up: real `**` support needs a `JacMath.pow` overload.
5. **Unbalanced braces in `_emit_async_boundary`.** Opened `LaunchedEffect`,
   `scope.launch`, `try` but closed only catch + launch - the `LaunchedEffect {`
   was never closed, so every async boundary emitted uncompilable Kotlin. Added
   the missing close.

Verification: `test_compose_target_guard.jac` 2/2 after cold-cache rebuild
(~5.5 min; no OOM this run). Remaining blocker fixes (import, unparser parens,
unsupported-op guard, async brace) static-checked for consistency; broader
compose tests left to CI per the prefer-CI rule.

### CI regression fixes + reactive_vars consolidation (2026-08-08)

**CI regressions from blocker sweep (fixed):**

1. **Compose onClick test** - precedence parens from the kotlin unparser fix
   emit `count = (count + 1)` not `count = count + 1`; test assertions updated.
2. **Effect lambda `let probe` hoisting** - intent `record_and_lower_effect`
   collected effect bodies via `_collect_stmt_body` but dropped
   `_prepend_hoisted` that upstream's `_transform_to_useeffect` applied;
   session now prepends hoisted decls when `pass_ref._prepend_hoisted` exists.

**reactive_vars consolidation (pass is single owner):**

- Removed duplicate `reactive_vars` / `reactive_vars_stack` from
  `IntentSession`; session `enter_ability` / `pop_ability_scope` no longer
  fork/sync reactive state (component entry only).
- Removed write-only `collector.reactive_vars`; state names live in
  `IntentModule` components and pass-owned `reactive_vars`.
- `EsastGenPass` / `ComposeGenPass` own `reactive_vars` + `_reactive_vars_stack`;
  sync to `converter` / `lowerer` via `_sync_converter_reactive_vars` /
  `_sync_lowerer_reactive_vars`.
- Removed dead `strict_arch_has` / `use_arch_has_dedup` fields from
  `EsastGenPass` (session already holds the live policy).

Verified: `test_compose_gen_pass.jac` 21/21, `test_js_generation.jac` 96/96,
`test_esast_gen_pass.jac` 41/41.

### Review cleanups F1 + F2 (2026-08-09)

Two follow-up quality fixes from the branch review, landed on this branch
(both are pure no-behavior-change cleanups of the consolidation commit
`83ce930b1`):

- **F1 - removed dead `IntentSession.pop_ability_scope`.** After the
  reactive_vars consolidation it was an empty `return;` no-op, yet still
  declared (`session.jac`), implemented (`session.impl.jac`), and called from
  both `EsastGenPass.exit_ability` and `ComposeGenPass.exit_ability`. Removed
  the decl, the impl, and both call sites. Ordering in both `exit_ability`
  methods is unchanged (the reactive_vars stack-restore still runs next).
- **F2 - factored ComposeGenPass reactive_vars propagation.** The same 3-line
  block (assign `lowerer.reactive_vars` + `converter.reactive_vars`)
  was inlined three times: `enter_ability`, `exit_ability`, and
  `_sync_lowerer_reactive_vars`. EsastGenPass had already factored its
  equivalent into `_sync_converter_reactive_vars`; ComposeGenPass was
  inconsistent. Added `_propagate_reactive_vars()` (declared on the obj)
  and call it from all three spots; `_sync_lowerer_reactive_vars` now just
  recomputes the names and calls it.

Verified: `test_compose_gen_pass.jac` 21/21, `test_esast_gen_pass.jac`
41/41, `test_compose_emit.jac` 14/14; `jac fmt --check` clean on all five
files; `jac check` clean on the compose/session decl+impl pairs (the esast
impl file's isolation-check errors are pre-existing and unaffected - confirmed
via stash: 154 baseline vs 153 with the no-op call removed).

### compose_todo crash fix - LazyColumn inside verticalScroll (2026-08-09)

`compose_todo` used `<LazyColumn>` nested inside the screen `Column`, while
`ComposeEmit.emit_jac_app` wraps every screen in `verticalScroll`. That
pairing gives LazyColumn infinite max height → instant Compose crash on launch
(both dev HMR mount and release `MainActivity`).

**Fix:** replace LazyColumn + Raw `items {}` with a `Column` + JSX list
comprehension (`titles.forEach { … }` in emitted Kotlin), which is safe inside
the parent scroll wrapper. Updated `main.jac`, `README.md`; regenerated
`:hot` `Screens.kt`.

Added `jac/examples/compose_todo/` - a task-list client using the Compose
pipeline (`framework = "compose"`). Demonstrates reactive `has` state
(`list[str]` + `draft`), `OutlinedTextField` input, add/clear handlers, and a
`LazyColumn` fed via `<Raw kotlin="items(titles) { … }">` (the JSX list-
comprehension emitter currently lowers to a non-`@Composable` `forEach`, so Raw
is used for the lazy `items {}` DSL until that emit path is fixed). Verified:
`jac check main.jac` clean; `jac build --client android --platform android` →
`BUILD SUCCESSFUL`, `app-debug.apk` produced.

### Merge upstream/main into android-probe (2026-08-15) - `b614b2c7e`

Merged `upstream/main` (`332fdd95d`, through #8250) into the branch; 7 file
conflicts resolved:

- `.gitignore` - kept both sides (our `.gradle/` + upstream's
  `native_materialize.jac` ignore).
- `jac0core/codeinfo.jac` - took upstream's `stdlib_root` → `stdlib_dir` rename
  (both hunks; ours was identical apart from the name).
- `type_system/type_evaluator.jac` - upstream removed the `as uni` / `as types`
  alias imports in favor of direct names. Kept upstream's decl list + our compose
  decls (`_is_compose_module`, `_compose_children_target`, `_is_compose_slot_param`,
  `_returns_composable`, `_jsx_has_content_children`) restated in direct-name
  style; added `JsxExpression`/`JsxText` to the unitree import list (needed by our
  compose impls); dropped dead decl `_get_enclosing_class_type_params` (never had
  an impl anywhere). Same sed applied to leftover `uni.`/`types.` prefixes in
  `ts_declarations.impl.jac` and `jsx_type_check.impl.jac`.
- `backends/impl/react.impl.jac` - upstream refactored `runtime_symbols` into
  per-kind methods (`state_field_symbols` etc.) but our `intent/es_adapter` calls
  the declared dispatcher, so kept the dispatcher (updated StateField → `useJacState`
  per upstream's new state-cell design) and adopted upstream's `_state_cell_name` /
  `_state_cell_member` helpers; upstream's per-kind impls dropped (undeclared +
  uncalled in the merged tree).
- `impl/esast_gen_pass.impl.jac` - took upstream's `unparse_node` import and the
  `exit_name` guard (`_in_identifier_slot` + `_ensure_backend`).
- `native/llvm/binding/dylib.jac` - took upstream's `with entry` argtypes block.
- `tests/.../test_preact_backend.jac` - dispatcher API + `useJacState`
  expectations (upstream's values, our method names).

Merge-induced checker fixes: `_compose_global_names: set[str] = {}` → `= set()`
(E1001 - `{}` is a dict literal) and `member_type: TypeBase;` annotation in
`ts_declarations.impl.jac` (`_map_ts_type` return widened).

**Important local-verification discovery:** `jac check` on
`type_system/type_evaluator.jac` reports ~196 errors on **pure `upstream/main`
too** - but only when `jac/jaclang/vendor/typeshed/stdlib/` is materialized
(untracked/ignored sidecar; materialized here, absent in fresh clones/worktrees).
The stdlib stubs make the checker resolve typeshed-backed annotations strictly,
surfacing pre-existing E1053/E1030/W1051 noise across the impl files. Verified
the merged tree sits exactly at the upstream+stubs baseline (196 errors,
matching per-file counts; our 3 extras were the two fixes above).
Upstream-without-stubs passes clean, as does our merged tree in the same
configuration. So the merged branch is at parity, not regressed.

Smoke: `jac run` of a small program (globals, ability, f-string, list
comprehension) works with the merged compiler (169 modules compiled incl. our
compose packages).

### Android Gradle dependencies via jac.toml (2026-08-15)

Added `[dependencies.gradle]` support for Compose Android projects: coordinates
from `jac.toml` are emitted into the scaffolded `app/build.gradle.kts` (and
`:hot` in dev mode) as `implementation("…")` lines. `compose_todo` now declares
`io.coil-kt:coil-compose:2.7.0` and renders a network favicon via
`<Raw kotlin={…}>` using `coil.compose.AsyncImage` - proves third-party Android
deps resolve and link. Also added `coil` to `_KOTLIN_IMPORT_ROOTS` for future
Jac `import coil…` → Kotlin import translation.

Verified: `jac build --client android` → `BUILD SUCCESSFUL`,
`app-debug.apk` at `jac/examples/compose_todo/apps/android/app/build/outputs/apk/debug/`.

### Remaining review findings NOT yet fixed (flagged for follow-up)

Higher-value quality items from the same review, deferred (one-thing-per-branch):

- ~~Triplicated `reactive_vars` state + two lock-step stacks (pass + session), and
  a **write-only** `collector.reactive_vars`; dead pass fields
  `strict_arch_has`/`use_arch_has_dedup` (built from hardcoded literals). Make
  the pass the single owner.~~ **DONE** (2026-08-08 - see above).
- The "backend-agnostic" intent core has an **upward dep on the backend**:
  `intent/semantics.jac` imports `KtNode` from `compose.kotlin_ast`; Compose then
  launders leaves through `: any =` + isinstance-or-raise. Parameterize the leaf
  type per backend.
- Coroutine-need computed three ways (one by substring-grepping emitted Kotlin);
  Kotlin imports classified by a hardcoded package-prefix allowlist;
  `jac_type_to_kotlin` string-munges types (mis-parses nested generics);
  duplicate `escape_kotlin`/`escape_kotlin_string`; blanket `except Exception {}`
  across filesystem ops; scattered hardcoded AGP/Kotlin/SDK version pins.

### SV deploy dial - Phase 0 + Phase 1 (`JacBackend` seam) (2026-08-15)

Implements `SV_DEPLOY_DIAL_PLAN.md` Phases 0–1: the `[sv] deploy` dial flows
from `jac.toml` into the Compose model, and walker calls route through a
generated `JacBackend` interface instead of a hard-wired `JacClient` object.

**Phase 0 - config plumbing:**

- `runtimelib/.../android/config.jac` - `resolve_sv_deploy` /
  `resolve_sv_sync_url` read `[sv].deploy` / `[sv].sync` (default `"remote"`;
  raises on unknown deploy values).
- `intent/model.jac` - `sv_deploy` / `sv_sync_url` on `IntentModule`.
- `apply_android_cfg_to_model` sets both fields; `_compile_compose_modules`
  summary prints `deploy=…`.

**Phase 1 - backend seam:**

- `rpc_client.impl.jac` - split emitters:
  `JacBoundary.kt`, `JacBackend.kt` (`interface JacBackend` +
  `object JacBackends { lateinit var current }`), `RemoteBackend.kt` (today's
  HTTP logic, unchanged wire shape), `JacBackendInit.kt` (sets
  `JacBackends.current = RemoteBackend()`). New `emit_sv_backend(...)` returns
  the file map; `device` / `local-first` warn and fall back to `remote`.
  `emit_jac_client` kept as a legacy single-file shim.
- `compose_emit.impl.jac` - writes all backend files instead of `JacClient.kt`.
- `jac_to_kotlin.impl.jac` - `_convert_spawn` emits
  `JacBackends.current.<walker>(...)`.
- `compose_native_emit.impl.jac` - coroutine detection keyed on
  `JacBackends.current`.
- `MainActivity.kt` / `JacDevEntry.kt` - call `JacBackendInit.install()` at
  startup.

**Tests:** `test_compose_scaffold.jac` (deploy dial values + bad-value raise),
`test_compose_rpc.jac` (split emit + device fallback), updated walker-spawn
assertions in `test_compose_gen_pass.jac`. Smoke-verified via `jac run` (local
pytest blocked by embedded postgres recovery on this machine - prefer CI).

### SV deploy dial - Phase 2 (`deploy = "device"`) (2026-08-16)

Implements `SV_DEPLOY_DIAL_PLAN.md` Phase 2: on-device graph runtime + walker
lowering.

**2A - JacGraph runtime templates** (`gradle_templates/jacgraph/`):
`JacAnchor.kt` (Node/RootNode/Dir), `JacGraph.kt` (in-memory store:
spawn/connect/neighbors/delete/persist no-op), `Walker.kt` (report/spawnOn).

**2B - `sv_lower` pass** (`sv_lower.jac` + `impl/sv_lower.impl.jac`):

- Lowers `node` archetypes → `@Serializable` Kotlin classes in `SvNodes.kt`
- Lowers `walker:pub` root-entry abilities → `class Foo(...) : Walker()` with
  `onRootEntry`
- Reuses `JacToKotlin` with `walker_mode=True` for graph operators:
  `++>`, `[root-->][?:T]`, `del`, `report`, `here`, `root`
- Unsupported constructs → compile-time diagnostics (inbound edges, visit, etc.)

**Device backend wiring:**

- `emit_sv_backend(..., deploy="device")` emits `DeviceBackend.kt` (no
  `RemoteBackend`); `JacBackendInit` installs `DeviceBackend()`
- `android_target._compile_compose_modules` runs `sv_lower` when `deploy=device`
- `ComposeEmit.write` emits jacgraph templates + `sv_lower` files

**Example:** `jac/examples/compose_todo` - walkers `add_todo`/`list_todos`/`clear`,
`[sv] deploy = "device"`.

**Tests:** `test_sv_lower.jac` (4 tests), updated `test_compose_rpc.jac` - 9/9
pass with `JAC_DB_URL=sqlite://...` (embedded postgres still flaky locally).

### SV deploy dial - Phase 3 (persistence) (2026-08-15)

On-device graph survives app restarts via a single JSON snapshot at
`filesDir/jac_graph.json` (no Room/SQLite yet - documented tradeoff in template).

**JacGraph runtime:**

- `JacGraph.init(context)` loads snapshot on startup; `persist()` writes after each
  walker (`DeviceBackend` unchanged).
- `JacGraphSerializers` - polymorphic `Node` registry; `SvNodes.kt` registers each
  lowered node type with `registerNodeSubclass(Todo::class, Todo.serializer())`.
- New template `JacGraphSerializers.kt`; `JacGraph.kt` uses lazy `Json` + snapshot
  types `GraphSnapshot` / `EdgeSnapshot`.

**App wiring:**

- `JacBackendInit.install(context)` calls `JacGraph.init` for `deploy=device`;
  `MainActivity` / `JacDevEntry` pass `Context`.
- Remote `install(context: Context? = null)` ignores context (no JacGraph in remote builds).

**Fix (e2e blocker):** `RemoteBackend` override methods dropped `nodeId` default values
(Kotlin forbids defaults on overrides when the interface carries them).

**Tests:** `test_sv_lower.jac` 5/5 (persistence registration + template markers).
**On-device e2e:** `bash scripts/android_compose_device_e2e.sh` **PASSED** on
`compose_android` + booted `Small_Phone` emulator (HMR + DexClassLoader hot-swap +
`JAC_COMPOSE_RENDERED` logcat markers).

### SV deploy dial - Phase 2 (`deploy = "device"`) (2026-08-15)

On-device graph runtime + walker lowering for the Compose/Android target.

**2A - JacGraph templates** (`gradle_templates/jacgraph/`):
`JacAnchor.kt` (abstract `Node`, `RootNode`, `Dir`), `JacGraph.kt` (in-memory
store: `spawnNode`, `connect`, `neighbors`, `delete`, `persist` stub), `Walker.kt`
(`report`, `spawnOn`, `onRootEntry`). Emitted when `sv_deploy == "device"`.

**2B - `sv_lower` pass** (`sv_lower.jac` + `impl/sv_lower.impl.jac`):
Lowers `node` archetypes and pub walker `with Root entry` bodies via
`JacToKotlin` in `walker_mode`. Emits `SvNodes.kt` (e.g. `Todo`, `AddTodo`,
`ListTodos`, `Clear`). `DeviceBackend` in `emit_sv_backend` runs lowered walkers
via `spawnOn` - no `RemoteBackend` / HTTP.

**Graph operators in `jac_to_kotlin`** (walker bodies only): `++>` connect,
`[root-->][?:Type]` traversal (`FilterCompr` trailer on edge refs),
`del`, `report`, `root`/`here`, `self` → `this`. Typed neighbor lists emit
`.filterIsInstance<Type>()`. Unsupported constructs → diagnostics.

**Compose fixes for device example:** sync reactive names before effect lowering;
dedupe async entry `LaunchedEffect`; JSX list comprehension → Kotlin `for` (not
`forEach`); empty walker requests as `@Serializable class` (not empty data class);
`DeviceBackend` overrides without default parameter values.

**Example:** `jac/examples/compose_todo` with `[sv] deploy = "device"` -
`jac build --client android` → `compileDebugKotlin` **BUILD SUCCESSFUL**,
`app-debug.apk` produced. **Tests:** `test_sv_lower.jac` (4 cases; local run
still blocked by embedded postgres on this host - prefer CI).

### SV deploy dial - Phase 3 (`deploy = "device"`) persistence (2026-08-16)

Graph survives app restarts; Context flows through `JacBackendInit`.

**3.1–3.3** `JacGraph.persist()/load()` write a single JSON snapshot
(`GraphSnapshot` nodes+edges) to `Context.filesDir/jac_graph.json` via
kotlinx.serialization; `load()` runs from `JacGraph.init(context)`, called by
`JacBackendInit.install(context)` from `MainActivity.onCreate`.
`DeviceBackend` persists write-through after each walker.

**Fixes found by the Gradle smoke + emulator run:**

- `JacGraphSerializers`: `subclass(klass)` with `KClass<out Node>` hits a
  reified-type error → registrations stored as `PolymorphicModuleBuilder<Node>.() -> Unit`
  lambdas; `registerNodeSubclass(klass, serializer)` pairs, two-arg `subclass`.
- `Node.type` collides with the JSON default class discriminator →
  `classDiscriminator = "kind"` in `JacGraph`'s Json.
- Serializer registration was a lazy top-level `run {}` in SvNodes.kt that never
  ran before first `persist()` → sv_lower reports `node_names`, threading
  (`SvLowerResult.node_names` → `ComposeModule.sv_node_names` →
  `emit_sv_backend(..., node_names)`), and `JacBackendInit.install()` registers
  each node serializer eagerly BEFORE `JacGraph.init`.
- Device deploy no longer emits `JacEnvironment.kt`/`BACKEND_URL`
  (`build_gradle_scaffold(..., sv_deploy=)`).

**Verified:** `jac build --client android --platform android` → BUILD SUCCESSFUL,
`app-debug.apk`; generated app has `JacGraph.kt`/`SvNodes.kt`/`DeviceBackend.kt`,
no `RemoteBackend`/`JacEnvironment`. Emulator acceptance: add todo →
`files/jac_graph.json` written (`kind` discriminator) → force-stop → relaunch →
todo restored. **Tests:** scaffold 6/6, sv_lower 5/5, compose_rpc 5/5
(`JAC_DB_URL=sqlite://...`, embedded postgres still flaky locally).
