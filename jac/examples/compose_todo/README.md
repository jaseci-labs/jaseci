# Compose TODO

A task list built with the Jac → Jetpack Compose pipeline. Uses native
Compose widgets (`OutlinedTextField`, `Card`, `Button`) and reactive `has`
state, not DOM/Tailwind.

## Quick start

```bash
# one-time
jac setup android

# build APK
jac build --client android --platform android
# → apps/android/app/build/outputs/apk/debug/app-debug.apk

# install + launch (starts an emulator when none is connected)
jac start --client android
```

Optional `[client.android] avd = "Small_Phone"` pins which emulator to auto-start.
Override with `JAC_ANDROID_AVD=Other_AVD jac start --client android`.

Requires JDK 17+, `ANDROID_HOME`, and Gradle (or the wrapper generated on first build).

## Features

- Add tasks from a text field; `!` and `urgent` add a priority suffix `(pN)`
- Delete individual tasks or clear all
- Coil header icon via `[dependencies.gradle]` in `jac.toml`
- Scrollable list via JSX list comprehension

## Dev loop (DexClassLoader HMR)

```bash
jac start --client android --dev -p 8010
```

See the [compose_android](../compose_android/README.md) example for HMR details.

## On-device verification

From the repo root (booted emulator or device required):

```bash
COMPOSE_ANDROID_DIR=jac/examples/compose_todo bash scripts/android_compose_device_e2e.sh
```
