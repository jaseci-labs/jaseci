# Socialize, mobile

The mobile face of the jaclang.org workspace: a React Native (mobUI) client
for the same social graph the site serves at `/socialize`. Sign up, post,
like, reply, follow people, browse trending hashtags, and join channels --
against the very same accounts and the very same persisted graph as the web
app, because both consume one domain module: `core/social_graph.jac`.

There is no backend in this directory. Every walker the screens spawn
(`load_feed`, `create_tweet`, `like_tweet`, `follow_user`, `join_channel`,
...) is imported from `core.social_graph`, and the compiler turns each
`root spawn` into a call across the app boundary to the `social_graph`
service app that owns those walkers. Whether that service shares the web
server's process or runs on its own is a profile (`jac run --serve` vs
`--fleet`); nothing here changes between the two.

## Run it

```bash
jac install                              # once: pulls the npm deps
jac run --dev mobile                     # native: Metro, press a / i or scan the Expo Go QR
jac run --dev --platform web mobile      # the same UI in a browser via react-native-web
jac build mobile --platform android      # APK
jac build mobile --platform ios          # .app / .ipa (macOS or EAS)
jac test mobile                          # the pure-Jac helpers in format.jac
```

The first native run needs `jac setup mobile` (an Expo project is scaffolded
under `.jac/mobile-rn/`). Point the app at a running server -- `jac run web`
in another terminal is enough; the dev API base URL is injected for you.

## Layout

```
mobile/
  main.jac            def:pub app -- auth gate, state, screen switch, tab bar
  impl/main.impl.jac  the handlers: every bridged call, wrapped for BridgeError
  theme.jac           tokens as objs (C, S, R, F) + one StyleSheet
  icon.jac            <Icon name=.../> on web    (lucide-react)
  icon.native.jac     <Icon name=.../> on native (lucide-react-native)
  format.jac          pure helpers shared by the screens (+ format.test.jac)
  components/         Avatar, TweetCard, Composer, TabBar, BridgeBanner, StatusView
  screens/            AuthScreen, FeedScreen, ExploreScreen, ChannelsScreen, ProfileScreen
```

## What to look at

**Only `@jac/mobui` primitives.** The app is `kind = "mobile"`, so a
raw `<div>` or `<span>` anywhere in it is a compile error (E1105). Layout is
`View`, text is `Text`, taps are `Pressable`, input is `TextInput`, lists
scroll in a `ScrollView` with a `RefreshControl`, the channel creator is a
`Modal`. Styling is React Native's model: `style={styles.x}` objects from one
`StyleSheet.create` in `theme.jac`, no CSS, no `className`.

**Typed tokens.** `theme.jac` declares the design tokens as `obj`s
(`Colors`, `Spacing`, `Radii`, `Fonts`) and exports one instance of each
(`C`, `S`, `R`, `F`), so `C.accent` is a typed attribute read that the checker
verifies -- not a dict looked up by attribute at runtime. Re-skin the whole app
by editing the field defaults.

**One icon API, two backends.** `icon.jac` and `icon.native.jac` declare the
same `Icon(name, size, color, fill)` over the same name table; the compiler
picks the `.native.jac` file for the app's native platforms (android / ios)
and the plain file for its web platform. The variant-agreement check (E5105)
keeps the two public surfaces identical.

**Friendly failure.** Every bridged call in `impl/main.impl.jac` sits in a
`try { ... } except BridgeError as e { reportBridge(e, ...); }`. The
`BridgeError` family (`BridgeUnavailable`, `BridgeTimeout`, `BridgeRejected`)
comes from `@jac/runtime`; `reportBridge` maps each to a one-line message and
remembers which loader to re-run, and `BridgeBanner` shows it with a Retry
button instead of a crashed screen. Auth calls additionally catch plain
network errors so a dead server reads as "can't reach the server" on the
login form.

**State like the web app.** `def:pub app` keeps its state in `has` fields,
mounts with `can with entry`, reacts to login with `can with [isLoggedIn]
entry`, and passes typed callbacks (`Callable[[str], None]`) down to screens
that own only their local UI state (a draft, an open modal). The shapes it
renders are the domain's own `obj`s and nodes -- `ProfileBundle`,
`ChannelBundle`, `TrendingTag`, `Profile`, `Tweet` -- read straight out of
`result.reports`.

## Theme

Dark-first, jaclang orange (`#ff6b35`) accent, pink likes, blue replies. On
the web target the page is capped at 640px and centred so it reads as a
phone column; on native it fills the screen.
