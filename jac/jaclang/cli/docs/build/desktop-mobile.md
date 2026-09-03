# I like to build … Desktop & mobile apps

Take a Jac app and give it a native shell -- a desktop window that embeds the OS webview, an Android/iOS webview build, or (for platform-native views) a React Native build. These are the `desktop` and `mobile` [project kinds](../quick-guide/project-kinds.md); a mobile app that targets React Native is a **mobUI** app (`client_kind = "mobui"`). In a [workspace](../reference/apps.md) each one is an `[apps.<name>]` table beside your web app, over the same shared `core/`.

!!! note "Status: beta 🧪"
    The desktop binary renders your `cl` UI and runs `sv` walkers/functions **in-process** on the embedded interpreter (shipped), with full HMR dev mode via `jac run --dev <app>`. Only per-OS installers/code-signing remain open ([issue #6436](https://github.com/jaseci-labs/jaseci/issues/6436)). Both mobile paths are frontend-only -- the app bridges to a Jac server you deploy separately (in a workspace, the `web-app` or `service` app that owns the walkers). Everything else on this page works as shown.

## Your 5-minute quick win {#desktop}

Start from any [full-stack app](fullstack-web.md). Jac compiles your `cl` UI into **one `jac nacompile`d binary that embeds the OS webview** (WebKitGTK / WKWebView / WebView2) -- no Rust toolchain, no PyInstaller, no separate process. The desktop target ships with `jaclang` core, and an app of kind `desktop` builds it with no flag:

```bash
jac create --app studio --kind desktop     # [apps.studio] kind = "desktop", path = "studio"
jac build studio                           # → .jac/client/desktop/<app>  (single binary)
jac run studio                             # build + launch the native window
jac run --dev studio                       # HMR: Vite serves cl on 127.0.0.1, recompiles on .jac saves
```

(In a single-app project, `jac create myapp --kind desktop` and then plain `jac build` / `jac run`; `--client desktop` forces the desktop shell on an app of any other kind.)

In dev mode the native host is built once, then your `cl` UI is served from
Vite on loopback and recompiled on every `.jac` save -- the desktop window
hot-reloads just like `jac run --dev` does for web. Walker/function calls
still go through the embedded in-process runtime, so RPC works identically
to the packaged build.

Window title and size are configured under `[desktop]` in `jac.toml`. On Linux you need the WebKitGTK system libraries (a bundled helper script installs them).

## Ship to Android & iOS {#mobile}

Ship the same client bundle to mobile via **Capacitor**, which wraps it in a native webview. A `mobile` app's default client target is `mobile` (Capacitor). The mobile app is the *frontend only* -- it bridges to your Jac server over HTTP, so deploy the backend separately (e.g. as a [backend service](backend-apis.md#service)):

```bash
# prerequisites: Android: JDK + Android SDK; iOS (macOS): Xcode (no Node.js -- JS tooling runs on the bundled Bun)
jac create --app mobile --kind mobile             # [apps.mobile] kind = "mobile", path = "mobile"
jac setup mobile --platform android              # one-time scaffold (android/)
jac run --dev mobile                             # live reload on device/emulator
jac build mobile --platform android              # → app-debug.apk
```

Use `--platform ios` on macOS to produce an Xcode project. App name and id are set under `[client.mobile]` (or the app's `[apps.mobile.client.mobile]` overlay); `[apps.mobile] platform` sets the default platform.

## Ship platform-native views (React Native) {#react-native}

For **true native views** instead of a webview, the React Native target compiles your `cl` UI to platform-native components via Expo/Metro. Author the UI once in the portable [`@jac/mobui`](../reference/plugins/jac-client.md#the-jacmobui-vocabulary) vocabulary (`View`, `Text`, `Pressable`, ...) and the same source also runs on the web. The app declares it:

```toml
[apps.mobile]
kind = "mobile"
path = "mobile"
client = "react-native"      # native views via Expo/Metro instead of a Capacitor webview
client_kind = "mobui"        # raw HTML tags in this app's modules become E1105
```

`client_kind` is an app property, so the mobUI guard covers only this app's modules -- your HTML-based `web` app next door is untouched. Then:

```bash
# prerequisites: Android: JDK + Android SDK; iOS (macOS): Xcode (no Node.js -- JS tooling runs on the bundled Bun)
jac setup mobile                                 # one-time Expo scaffold (.jac/mobile-rn/)
jac run --dev mobile                             # Metro Fast Refresh on device/emulator
jac run --client web --dev mobile                # the same screens in a browser via react-native-web
jac build mobile --platform android              # → APK (iOS: .app via xcodebuild, .ipa via EAS)
```

The flagship workspace's [`mobile/`](https://github.com/jaseci-labs/jaseci/tree/main/jac/examples/jaclang_org/mobile) app is the worked example: a React Native client for the same social graph the site serves at `/socialize`, with typed theme tokens, `.native.jac` platform-split icons, and `BridgeError` handling around every bridged call. `jac create <name> --awesome` scaffolds the whole workspace, mobile app included.

## Your learning path

- **Concepts you need** → [Core Concepts](../quick-guide/what-makes-jac-different.md) -- the client codespace · [Workspaces & Apps](../reference/apps.md) -- how a mobile app sits beside a web app over shared code
- **Build the app first** → [Full-stack web apps](fullstack-web.md) (a desktop/mobile app is a full-stack app plus a shell)
- **Build it for real** → [Desktop App](../tutorials/fullstack/desktop.md) · [Mobile App](../tutorials/fullstack/mobile.md) (covers both Capacitor and React Native)
- **Look it up** → [jac-desktop reference](../reference/plugins/jac-desktop.md) · [jac-client reference](../reference/plugins/jac-client.md) ([React Native target](../reference/plugins/jac-client.md#react-native-target-beta))

## Going further

- Add AI features → [AI agents & LLM apps](ai-agents.md)
- Scale the backend your app talks to → [Backend APIs & services](backend-apis.md)
