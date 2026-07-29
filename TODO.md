  1. Unsupported code becomes Kotlin comments, not compile errors

  jac_to_kotlin and the view builder emit /*unsupported …*/ and only
  append diagnostics. ComposeEmit.write() prints warnings and still
  writes files. Gradle may succeed with broken UI or empty screens.

  Production: treat any diagnostic as a hard compile failure; never
  emit KtRaw stubs for user code paths.

  1. Two codegen paths still coexist

  ComposeEmit prefers native compose_view, but falls back to
  ViewComposeEmitter (DOM + Tailwind via compose_backend /
  tailwind_to_modifier / es_to_kotlin). That’s the old “infer Compose
  from web-shaped IR” path - explicitly lossy.

  Production: for framework = "compose", reject comp.view (DOM IR)
  entirely. Delete or quarantine the Tailwind/DOM backend for Android.
  One path only.

  1. Type checking is disabled

  AndroidTarget compiles with CompileOptions(type_check=False).

  Production: enable type checking. Composable exists in builtins but
  is a stub; Modifier, Typography, primitives in
  compose_runtime.cl.jac are mostly any. You need real types (or a
  typed Modifier builder) so mistakes fail in Jac, not in Kotlin.

  1. “v1” surface limits are still real gaps

  Explicit unsupported cases today:
  • dynamic JSX tags
  • spread attributes ({...props})
  • many jac_to_kotlin expression/statement forms (anything not in
    the handled subset)
  • multi-target assignment
  • legacy path still marks img, svg/canvas as “deferred”

  Raw { } is the escape hatch - fine for prototyping, not production
  policy.

  Production: either implement these or fail with a clear error at
  compile time (no Raw as the default fix).

  1. No real compile/run integration gate

  Tests are overwhelmingly string snapshots (generated Kotlin,
  scaffold files, RPC types). The plan’s M4 gate - emulator + live jac
  serve RPC round-trip - is not in CI.

  Production minimum:
  • CI: jac build --client android on compose_android (Gradle
    assemble)
  • Optional but valuable: headless emulator test - launch APK, tap
    counter, RPC greeting against a test server

  Today you can ship codegen regressions that only break on a device.

  1. setup() doesn’t actually set up Android

  It creates apps/android/, patches jac.toml, and warns if
  java/adb/SDK are missing. It does not scaffold Gradle, install SDK
  packages, or create an AVD.

  Production: jac setup android should match RN/desktop quality -
  scaffold project, verify JDK 17+, SDK API level, build-tools,
  emulator image, gradlew, and fail with actionable fixes.

  1. Release builds aren’t shippable yet

  Gradle scaffold has no signing, keystore, or ProGuard/R8
  configuration. assembleRelease may build but won’t produce a
  Play-ready artifact.

  Production: release signing config, minify rules for
  kotlinx-serialization + Compose, versionCode/versionName from
  jac.toml, and documented release workflow.

  1. Dev/HMR is dev-only (acceptable), but brittle

  • 500ms polling instead of a file watcher
  • hot rebuild failures → warning, stale dex on device
  • adb missing → warning + manual instructions instead of hard
    error

  Production for jac dev: reliable watcher, surface rebuild errors in
  the app or CLI, require adb/device before claiming “HMR ready.”

  1. Navigation is a custom when(path) router

  Not Navigation Compose; JacSectionRegistry is minimal. Works for
  demos, not deep linking, back-stack, or transitions at production
  quality.

  Production (if multi-screen apps matter): Nav Compose + proper back
  stack, or document this as an intentional limitation.

  1. Silent registration failure

  register.jac wraps AndroidTarget registration in try/except and
  swallows import errors.

  Production: register unconditionally or fail loudly if the target
  can’t load.

  ────────────────────────────────────────

  Prioritized roadmap (no workarounds)

  ┌──────┬────────────────────────────────────────┬──────────────────┐
  │ Prio │ Work                                   │ Why              │
  │ rity │                                        │                  │
  ├──────┼────────────────────────────────────────┼──────────────────┤
  │ P0   │ DONE: Fail-fast diagnostics; no KtRaw  │ Prevents silent  │
  │      │ in user lowering                       │ broken apps      │
  ├──────┼────────────────────────────────────────┼──────────────────┤
  │ P0   │ DONE: Remove DOM/Tailwind fallback     │ Eliminates the   │
  │      │ for compose framework                  │ lossy path       │
  ├──────┼────────────────────────────────────────┼──────────────────┤
  │ P0   │ PARTIAL: typed surface + opt-in        │ Catch errors     │
  │      │ type_check (full blocked: .dp/.len)    │ before Gradle    │
  ├──────┼────────────────────────────────────────┼──────────────────┤
  │ P0   │ DONE: CI Gradle build (assemble APK).  │ First real       │
  │      │ Emulator smoke test still TODO.        │ quality gate     │
  ├──────┼────────────────────────────────────────┼──────────────────┤
  │ P1   │ Complete setup() (SDK, scaffold,       │ Reproducible     │
  │      │ gradlew)                               │ onboarding       │
  ├──────┼────────────────────────────────────────┼──────────────────┤
  │ P1   │ Release signing + R8/ProGuard          │ Shippable        │
  │      │                                        │ APK/AAB          │
  ├──────┼────────────────────────────────────────┼──────────────────┤
  │ P1   │ On-device RPC e2e (counter + walker    │ Validates the    │
  │      │ against jac serve)                     │ differentiator   │
  ├──────┼────────────────────────────────────────┼──────────────────┤
  │ P2   │ Close v1 gaps (spread attrs, dynamic   │ Less need for    │
  │      │ tags, broader jac_to_kotlin)           │ Raw              │
  ├──────┼────────────────────────────────────────┼──────────────────┤
  │ P2   │ Nav Compose, Image/AsyncImage,         │ Full app parity  │
  │      │ theme/i18n parity                      │                  │
  ├──────┼────────────────────────────────────────┼──────────────────┤
  │ P2   │ HMR hardening (watcher, error UX)      │ Reliable daily   │
  │      │                                        │ dev              │
