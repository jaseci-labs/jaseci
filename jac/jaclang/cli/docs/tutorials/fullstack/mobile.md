# Building a Mobile App

This tutorial walks you through shipping an existing Jac full-stack app as a native mobile app for Android and iOS. A mobile app is an app of kind `mobile` -- `[project] kind = "mobile"` in a single-app project, or an `[apps.<name>]` table in a workspace next to your web app (`jac create --app mobile --kind mobile` writes one). Jac ships **two** mobile client targets, selected by the app's `client`:

- **Capacitor** (`client = "mobile"`, the kind's default) -- wraps your web bundle in a native webview. Covered in the first half of this page.
- **React Native** (`client = "react-native"`, beta) -- compiles your `cl` UI to platform-native views. Covered in [React Native target](#react-native-target) below.

The examples below name the app `mobile`; in a single-app project drop the name (`jac run --dev`, `jac build --platform android`). `--client <target>` overrides the app's target for one command.

> **Prerequisites**
>
> - Completed: [Project Setup](setup.md) -- you have a working `jac run` web app
> - Node.js is **not** required -- all JS tooling runs on the Bun runtime bundled with `jac`
> - **Android**: Java/JDK 21+, Android SDK (via [Android Studio](https://developer.android.com/studio))
> - **iOS** (macOS only): Xcode, Xcode Command Line Tools, [CocoaPods](https://cocoapods.org/)
> - Time: ~15 minutes for setup, longer on first build

---

## How a Mobile Build Works

When you run `jac build mobile --platform android`, the build does four things:

1. **Compiles the client bundle** -- the same Vite build the web target produces.
2. **Syncs with Capacitor** -- copies the web bundle into the native project (`android/` or `ios/`) and updates native plugins.
3. **Builds the native app** -- runs Gradle (`assembleDebug`) for Android or `xcodebuild` for iOS.
4. **Produces the artifact** -- an `.apk` file for Android, or an Xcode build for iOS.

The result is a native mobile app that loads your Jac frontend in a webview. The same client bundle that runs in the browser runs inside the native shell.

---

## One-Time Setup

From your project root:

```bash
jac setup mobile
```

This sets up the `mobile` app's client target: it installs Capacitor dependencies, creates `capacitor.config.json`, and scaffolds the selected platform. By default, setup follows the app's `[apps.mobile] platform` (else `[client.mobile].default_platform`) and falls back to `ios` on macOS or `android` elsewhere.

You can force a specific scaffold explicitly:

```bash
# Android scaffold only
jac setup mobile --platform android

# iOS scaffold only (macOS only)
jac setup mobile --platform ios

# Both platforms (macOS only; Linux/Windows will scaffold Android)
jac setup mobile --platform all
```

The setup also:

- Checks for required tools (Node.js, Java/JDK, Android SDK, Xcode, CocoaPods)
- Adds a `[client.mobile]` section to your `jac.toml`
- Prints next steps for both platforms

---

## Configure App Metadata

Open `jac.toml` and edit the `[client.mobile]` section that setup created:

```toml
[client.mobile]
app_name = "My Jac App"
app_id = "com.example.myapp"
```

| Field | Description | Default |
|-------|-------------|---------|
| `app_name` | Display name of the app | `Jac App` |
| `app_id` | Reverse-DNS identifier (used by both app stores) | `com.jac.app` |
| `release` | Build release variant instead of debug | `false` |
| `bundle` | Produce AAB (Android App Bundle) instead of APK | `false` |
| `default_platform` | Default platform for `jac run mobile` (the app's `[apps.mobile] platform` wins) | `android` |
| `ios_sdk` | Xcode SDK for iOS builds | `iphonesimulator` |
| `ios_destination` | Xcode destination string | `platform=iOS Simulator,name=iPhone 16,OS=latest` |

These values feed into `capacitor.config.json` and the native build commands automatically.

---

## Android Development

### Dev Loop

Build the web bundle, sync it into the Android project, and launch on a connected device or emulator:

```bash
jac run mobile
```

This runs `cap sync android` followed by `cap run android`.

If you need to force a specific host/IP for live reload, use:

```bash
jac run --dev --host 192.168.1.25 mobile
```

jac-client auto-attempts `adb reverse` for the Vite and API ports before launching Capacitor on Android, so manual `adb reverse` is usually not required.

### Production Build

```bash
# Debug APK (default)
jac build mobile --platform android

# Release APK (set release = true in jac.toml)
# Or release AAB (set bundle = true in jac.toml)
```

The APK lands in `android/app/build/outputs/`. The build uses the project's `gradlew` wrapper automatically.

### Where to Find the APK

After a successful build:

```
android/app/build/outputs/apk/debug/app-debug.apk
```

For release builds:

```
android/app/build/outputs/apk/release/app-release.apk
```

---

## iOS Development

> **Note:** iOS builds require macOS with Xcode installed. You can scaffold the project on any OS, but building requires a Mac.

### Dev Loop

```bash
jac run --platform ios mobile
```

This syncs the web bundle and opens the project on the iOS Simulator via `cap run ios`.

### Production Build

```bash
jac build mobile --platform ios
```

This runs `xcodebuild` targeting the iOS Simulator by default. For device builds or App Store archives, open the project in Xcode:

```bash
npx cap open ios
```

From Xcode you can:

- Select a physical device or simulator
- Configure signing and provisioning profiles
- Archive for App Store distribution

### CocoaPods

Capacitor iOS uses CocoaPods for native dependencies. If `pod install` hasn't been run, Capacitor's sync step handles it. If you add native plugins later, run:

```bash
cd ios/App && pod install
```

---

## Cross-Platform Tips

### Shared Web Bundle

Both platforms use the exact same web bundle. Write your UI once; Capacitor wraps it natively for each platform.

### Native Plugins

Capacitor has a rich plugin ecosystem for camera, geolocation, push notifications, etc. Install them via npm:

```bash
jac install --npm @capacitor/camera
npx cap sync
```

### Testing on Real Devices

- **Android**: Enable USB debugging on your device, connect via USB, and `cap run android` deploys directly.
- **iOS**: Register your device in your Apple Developer account, select it in Xcode, and build.

### Mobile Dev Networking

When using `jac run --dev mobile`, jac-client auto-selects a reachable host by default:

```bash
# Auto host selection (recommended)
jac run --dev mobile
```

Override host selection only when needed:

```bash
jac run --dev --host 192.168.1.25 mobile
```

You can still force iOS or Android in dev with:

```bash
jac run --dev --platform ios mobile
```

### Debugging

- **Android**: Use Chrome DevTools -- navigate to `chrome://inspect` while the app is running on a device/emulator.
- **iOS**: Use Safari Web Inspector -- enable it in Safari → Develop menu.

### Troubleshooting

If mobile dev starts but the app does not load correctly:

1. Check `jac run` output for selected host and Vite port.
2. If needed, set an explicit host with `--host <ip>`.
3. Confirm `adb devices` shows your Android target as authorized.
4. If port forwarding fails, run manual fallback:
   - `adb reverse tcp:5173 tcp:5173`
   - `adb reverse tcp:8000 tcp:8000`
5. Re-run sync after plugin changes:
   - `npx cap sync android`
   - `npx cap sync ios`
6. For iOS signing or provisioning issues, open Xcode:
   - `npx cap open ios`

---

## React Native target

The React Native target (`client = "react-native"` on the app, beta) is the **native** mobile path: instead of wrapping a web bundle in a webview, it compiles your `cl` UI to platform-native views via Expo/Metro/Hermes. This gives native gesture/scroll performance and access to the React Native ecosystem, at the cost of a different rendering and styling model.

### mobUI projects and `@jac/mobui`

A React Native app is a **mobUI** project -- one source tree that compiles to both web (via `react-native-web`) and native (Android/iOS). Because React Native has no DOM, mobUI projects do not use HTML tags. Instead they use Jac's `@jac/mobui` component vocabulary, which projects to every target:

| `@jac/mobui` | Replaces HTML |
|-----------|---------------|
| `View` | `div`, `section`, `main`, `article`, `header`, `footer`, `nav`, `aside` |
| `Text` | `span`, `p`, `h1`-`h6`, `label`, `strong`, `em`, `small` |
| `Pressable` | `button`, `a` |
| `TextInput` | `input`, `textarea` |
| `Image` | `img` |
| `ScrollView` | `ul`, `ol`, scroll areas |
| `FlatList` / `SectionList` | long or grouped lists (virtualized -- prefer over `ScrollView`) |
| `Modal` | `dialog` |
| `Switch` | `input type="checkbox"` |
| `Alert` / `Linking` | `window.alert` / `window.open` |
| `StyleSheet` | CSS / `className` |

Styling is `style={{...}}` objects over a flexbox subset -- no CSS files, no `className`. In a mobUI project, raw HTML tags (`<div>`, `<span>`, ...) are **compile errors** (`E1105`) with a fix-it pointing at the `@jac/mobui` primitive to use instead. See the [diagnostics reference](../../reference/diagnostics.md#mobui-project-jsx-host-tags) for details.

### One-time setup

Declare the app as a mobUI app in `jac.toml` -- `jac create --app mobile --kind mobile` writes this (and `jac create myapp --kind mobile` writes the single-app form):

```toml
[apps.mobile]
kind = "mobile"
path = "mobile"
client = "react-native"
client_kind = "mobui"
```

`client = "react-native"` selects the Expo/Metro target; `client_kind = "mobui"` turns on the `@jac/mobui` host-tag guard for every module under `mobile/` -- and only there, so a web app in the same workspace keeps its HTML. Then, from the project root:

```bash
jac setup mobile
```

This scaffolds an Expo/Metro project at `.jac/mobile-rn/` (configurable via `[client.react_native].project_dir`; it lives under the centralized `.jac` build root, so it stays out of the source tree) and prints next steps.

### Authoring UI with `@jac/mobui`

```jac
import from "@jac/mobui" {
    View, Text, Pressable, TextInput, ScrollView, StyleSheet
}

glob styles = StyleSheet.create({
    screen: {flex: 1, backgroundColor: "#10131c", padding: 24, gap: 16},
    title: {fontSize: 22, fontWeight: "bold", color: "#f4f5fb"},
    button: {padding: 12, borderRadius: 10, backgroundColor: "#6c5ce7", alignItems: "center"},
});

def:pub app -> JsxElement {
    has name: str = "";
    return
        <ScrollView style={styles.screen}>
            <Text style={styles.title}>Hello, {name or "stranger"}</Text>
            <TextInput
                value={name}
                placeholder="Type your name"
                onChangeText={lambda (t: str) { name = t; }}
            />
            <Pressable style={styles.button} onPress={lambda { name = "Jac"; }}>
                <Text>Reset</Text>
            </Pressable>
        </ScrollView>;
}
```

The same source builds for native (`jac build mobile`) and, through `react-native-web`, for the browser (`jac build mobile --client web`).

### Development

```bash
jac run --dev mobile
```

This launches the Jac backend, compiles `.jac` to JS, and runs `expo start` on the bundled Bun. Metro serves both platforms -- pick the device in the Expo CLI (press `a` for Android, `i` for the iOS simulator) or scan the QR code in Expo Go. Editing a `.jac` file recompiles and Metro Fast Refreshes the device. Dev networking is auto-resolved (LAN IPv4 > `127.0.0.1`, override with `JAC_RN_DEV_HOST`); Metro defaults to port `8081` (`JAC_RN_METRO_PORT`); `adb reverse` is auto-attempted for Android.

### Production build

```bash
# Android
jac build mobile --platform android

# iOS (macOS only; non-macOS points at EAS Build)
jac build mobile --platform ios
```

Android produces an APK via `gradlew assembleDebug`. iOS produces a simulator-installable `.app` bundle via `xcodebuild` on macOS (a distributable `.ipa` comes from the EAS Build path); on other platforms the build errors out and points you at EAS Build. Release variants via `[client.react_native].release = true`.

### EAS Update (OTA)

`jac setup mobile` (on a `react-native` app) scaffolds a baseline `eas.json` (with `preview` and `production` profiles). To push OTA updates after each build:

1. **One-time** (inside `.jac/mobile-rn/`): install the updates module and link your EAS project:

   ```bash
   npx expo install expo-updates
   eas update:configure      # writes expo.updates.url into app.json
   ```

   `expo-updates` is not pinned in the scaffold -- `npx expo install` resolves the SDK-matched version.

2. **Opt in** via `jac.toml`:

   ```toml
   [client.react_native]
   eas_update = true
   eas_update_branch = "production"   # "" -> "production" (release) / "preview" (debug)
   ```

3. **Build** as usual -- a successful `jac build mobile` then runs `eas update --branch <branch>` automatically. Set `eas_update_message` to pin a message; leave it empty to let EAS derive one.

See the [jac-client Reference -> EAS Update (OTA)](../../reference/plugins/jac-client.md#eas-update-ota) for the full field list.

### Platform-specific files

When you need platform-exclusive native modules, add a `.native.jac` variant alongside a `.jac` module. The variant is selected by the app's client target: the compiler picks up the `.native.jac` file when the app targets `react-native` and falls back to `.jac` otherwise -- the filename alone decides nothing. The two files must agree on their public surface (names, kinds of declaration, parameters, annotations, `has` fields); each disagreement is `E5105` on the variant, so a drifted pair is caught by `jac check` rather than at first launch. The flagship workspace's `mobile/icon.jac` / `mobile/icon.native.jac` is the worked example. This is a last resort -- prefer components from the `@jac/mobui` vocabulary, which absorb platform divergence internally. Use a file pair only when the platforms need *different imports*; to branch on values, `Platform` is part of the vocabulary already, so `Platform.OS` and `Platform.select({ios: ..., android: ..., default: ...})` work inline.

### What carries over

The React Native target reuses the same Jac -> JS compilation pipeline, the same `JacForm` form system (adapted to RN `TextInput`), the same auth helpers (backed by `expo-secure-store`), and the same walker-call API. Routing is adapted to React Navigation: `Router` -> `NavigationContainer`, `Routes` + `Route` -> `Stack.Navigator` + `Stack.Screen`.

For the full reference, see the [jac-client Reference -> React Native Target](../../reference/plugins/jac-client.md#react-native-target-beta).

---

## What You've Built

By now you should have:

- A `[client.mobile]` section in `jac.toml` controlling app name, identifier, and build mode.
- An `android/` directory with a Capacitor-wrapped Android project.
- An `ios/` directory with a Capacitor-wrapped iOS project (on macOS).
- The ability to build and deploy to both platforms from the same Jac codebase.

For the full reference -- including every CLI option and configuration field -- see the [jac-client Reference → Mobile Target](../../reference/plugins/jac-client.md#mobile-target-capacitor).
