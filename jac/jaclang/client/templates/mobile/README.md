# {{name}}

A cross-platform **mobUI** app in Jac: one source tree that runs on the web
(through `react-native-web`) and on iOS / Android (React Native through Expo).
The UI is written only in `@jac/mobui` primitives, and the backend - a `Todo`
node plus the walkers the UI calls - lives in the same file as the app shell.

## Run it

```bash
jac install                                     # once, and again after editing jac.toml
jac run --client web --dev                      # web preview: View -> <div>, Text -> <span>, hot reload
jac run --show                                  # what a bare `jac run` would do for this app

jac setup react-native                          # once: Expo scaffold in .jac/mobile-rn/
jac run --client react-native --dev             # native: Metro dev server (press a / i, or scan with Expo Go)
jac build --client react-native --platform android   # APK (gradle, or EAS via [client.react_native])
jac build --client react-native --platform ios       # .app / .ipa (xcodebuild on macOS, or EAS)
```

A bare `jac run` on a `mobile` app is the build (`jac build --client react-native`);
the `--dev` forms above are the development loops. `jac run main.jac` addresses
the entry by file instead of by app.

Inside a workspace the app is addressed by name, for example `jac run mobile`.
`jac create --app mobile --kind mobile` scaffolds this template into an existing
project and registers it as `[apps.mobile]`.

## How it is wired

`jac.toml` declares the app:

```toml
[project]
entry-point = "main.jac"
kind = "mobile"              # client = "react-native" (Expo + Metro), client_kind = "mobui"
```

A `mobile` app is a React Native app with the mobUI client kind, so the two
keys need spelling out only when an app overrides them (`client = "mobile"`
picks the Capacitor shell instead). Inside a workspace the same keys live on
the app's table, `[apps.mobile]`.

`client_kind = "mobui"` turns on the compiler guard: any lowercase HTML tag
(`<div>`, `<span>`, `<button>`, ...) that does not resolve to an in-scope
component is `E1105` and blocks codegen. Use the primitive instead:

| HTML | mobUI primitive |
|---|---|
| `div`, `section`, `nav` | `View` |
| `span`, `p`, `h1`-`h6` | `Text` (all text sits inside a `Text`) |
| `button`, `a` | `Pressable` |
| `input`, `textarea` | `TextInput` |
| `img` | `Image` |
| `ul`, `ol`, scroll areas | `ScrollView` (`FlatList` once a list can outgrow a screen) |

Styling is React Native's model only: `StyleSheet.create` objects of camelCase
properties, merged with arrays (`style={[styles.row, {opacity: 0.5}]}`). No CSS
files, no `className`.

## Project structure

```
{{name}}/
├── jac.toml                 # [project] kind = "mobile" + npm dependencies
├── main.jac                 # backend (Todo node, AddTodo / ListTodos walkers) + the app shell
├── theme.jac                # design tokens (obj types) + the StyleSheet
├── screens/
│   └── Home.jac             # the todo screen: presentational, typed props
└── components/
    ├── Button.jac           # Pressable with primary / secondary variants
    ├── Icon.jac             # Lucide icons, web variant (lucide-react)
    └── Icon.native.jac      # same Icon API, native variant (lucide-react-native)
```

`app` (in `main.jac`) owns the state and calls the walkers with `root spawn`;
`HomeScreen` receives `todos`, `draft` and two callbacks as typed props. The
walkers are `:pub`, so no login is needed and every visitor shares one list;
switch them to `:priv` to require authentication and give each user an
isolated graph.

## Components

Components are `def:pub` functions returning `JsxElement`, imported by path:

```jac
import from .components.Button { Button }
```

`Button.jac` wraps `Pressable`. `Icon.jac` / `Icon.native.jac` are a platform
pair: the compiler picks the `.native.jac` file for the react-native target and
the plain `.jac` file otherwise, so one `<Icon name="check" .../>` call renders
real Lucide vectors on both platforms. Keep the two files' public API identical.

## Theme

Tokens in `theme.jac` are `obj` types instantiated into typed globals
(`C.accent`, `S.lg`, `R.pill`, `F.md`) - attribute reads the compiler checks.
Change the defaults on `Palette`, `Spacing`, `Radius` and `FontSize` to re-skin
the whole app.

## Adding dependencies

```bash
jac install --npm some-package
```

Packages the web bundle needs go under `[dependencies.npm]`; packages only the
native (Expo) project needs go under `[dependencies.npm.native]`, which
`jac setup react-native` merges into `.jac/mobile-rn/package.json`.

## Next steps

- Add `done: bool = False` to `Todo` and a `ToggleTodo` walker spawned on the
  node (`todo spawn ToggleTodo()`) to complete items.
- Add a screen under `screens/` and switch between them with a `has` field on
  `app`.
- Add glyphs to both `Icon.jac` and `Icon.native.jac` (same keys in each).
