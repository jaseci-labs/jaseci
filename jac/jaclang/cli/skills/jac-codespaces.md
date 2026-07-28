---
name: jac-codespaces
description: Inferred client/server/native code placement - how the whole-program solver decides what runs where (JSX/npm imports mark code client, python imports and graph archetypes anchor code server, extern C declarations mark code native), what never moves (def:pub endpoints, walkers, shared objs), the [placement.pins] override table, and the --placements/lock review tooling. Load when deciding where code runs, pinning a declaration server-side, migrating marker-era code with `jac fix placement`, or debugging why something landed in the wrong bundle.
---

**Placement is inferred - there is no syntax for it.** Jac compiles one language to three codespaces: server (Python - the default), client (JavaScript/JSX), and native (LLVM). A whole-program placement solver reads the evidence in your code and places every top-level element. The old `sv`/`cl`/`na` markers (blocks, statement prefixes, the `.sv.jac` suffix) were removed and are now syntax errors - run `jac fix placement` to migrate old code (see Migration below). Overrides live in `jac.toml` under `[placement.pins]`, not in the source.

## The evidence rules

1. **Client is structural.** JSX, browser globals, and string-path or `@jac` npm imports (`import from "react" { ... }`) are client evidence; a declaration carrying any of them is seeded client.
2. **Server is anchored by server-only facts.** Python imports (`import os;`, `import from datetime { datetime }`), graph archetypes (`node`/`edge`/`walker`), `::py::` blocks, and typed context blocks anchor their module server. Unreferenced pure code defaults to server too.
3. **Native is seeded by extern C declarations** - an import whose braces declare C-ABI functions is an FFI surface only the native backend can satisfy; it and its users go native. Importing a native module is also native evidence for the importer's crossing, not a relocation (see below).
4. **Placement propagates through references, across modules.** Helpers, `glob`s, and imports that client code uses join the client bundle when their whole closure can move - including helpers imported from other modules (cross-module pulls happen before codegen, so `jac check` sees what `jac build` sees). Requirement-free code reached from both sides is **dual-emitted** into each. A reference whose closure cannot move **bridges** instead: `def:pub` calls over RPC, archetypes as wire types, native calls over the interop edge.

A complete markerless full-stack module - every placement is inferred:

```jac
import from datetime { datetime }               # python import -> server anchor
import from "canvas-confetti" { confetti }      # string-path npm import -> client-only

obj Note {                                      # referenced by BOTH sides -> auto-shared
    has text: str = "";
    has stamp: str = "";
}

def:pub save_note(text: str) -> Note {          # def:pub in a server-anchored module -> endpoint
    return Note(text=text, stamp=str(datetime.now()));
}

glob MAX_LEN: int = 280;                        # referenced by client code -> joins client bundle

def remaining(text: str) -> int {               # referenced only by client code -> client
    return MAX_LEN - len(text);
}

def:pub app() -> JsxElement {                   # JSX -> client
    has text: str = "";
    has notes: list[Note] = [];

    async def handle_save -> None {
        n = await save_note(text);              # client -> def:pub call = auto-RPC bridge
        notes = [n] + notes;
        confetti();
    }

    return <main>
        <input value={text} onChange={lambda (e: ChangeEvent) { text = e.target.value; }} />
        <span>{remaining(text)} left</span>
        <button onClick={handle_save}>Save</button>
        {for n in notes { <p key={n.stamp}>{n.text}</p> }}
    </main>;
}
```

## What inference never relocates

Reference propagation pulls helpers - it does NOT turn server API surface into client code:

- **`def:pub` functions and walkers in a server-anchored module stay server endpoints.** A client reference never inlines them into the bundle; the call compiles to the auto-RPC bridge (`await save_note(...)`, `result = root spawn add_task(title=t);` - see `jac-fullstack-patterns`). `def:pub` / `walker:pub` is the cross-space contract. (A `def:pub` whose own body carries JSX is client by the structural rule - that is how markerless `def:pub app` and components work. And in a module with NO server anchor at all, a pure `def:pub` can be pulled client wholesale - there is no server side to bridge to.)
- **`node`/`edge`/`walker` archetypes never relocate** - they are the persistence/OSP surface and a server anchor for their module. Referenced from client code they are auto-shared: the bundle gets a wire-codec class (`__from_wire`/`__to_wire`, `_jac_id`) while the archetype itself stays server. ⚠ **Receiving and reading such a value works; constructing one client-side does not.** `has progress: JobProgress = JobProgress();` in a client component compiles clean and throws `JobProgress is not defined` at mount. Hold shared types as `T | None = None` on the client and let the server construct them.
- **Plain `obj` archetypes referenced from both sides are auto-shared** the same way - typed instances cross the wire hydrated, no duplicate declaration needed. An `obj` referenced *only* by client code relocates wholesale into the bundle instead (real class, methods and all).

## `[placement.pins]` - the override that always wins

When inference is wrong for reasons dataflow cannot see - the helper wraps a secret, the computation must not run in the browser - pin the element in `jac.toml`. Keys are fnmatch patterns over `module` or `module.element` dotted paths; values are `"server"`, `"client"`, or `"native"`:

```toml
[placement.pins]
"app.API_KEY"   = "server"    # one glob stays out of the JS bundle
"app.summarize" = "server"    # client calls bridge over RPC instead
"kernels.*"     = "server"    # every element of the kernels module
helpers         = "client"    # module-level pin: the whole module is client
```

The corresponding source is plain Jac - nothing in it says where it runs:

```jac
import os;

glob API_KEY: str = os.getenv("API_KEY") or "";   # pinned server in jac.toml

def summarize(text: str) -> str {   # pinned server; client callers bridge over RPC
    return text[:80];
}
```

Pins feed the solver exactly like the old markers did: a pinned element is immovable, and everything else re-solves around it. A **module-level `"server"` pin** additionally makes client imports of that module full service-boundary imports (non-pub items callable with auth, boundary types collected) - the trust-boundary form. Pins are part of the program: changing them invalidates the compilation cache and shows up in `--placements` evidence as `pinned 'server' ([placement.pins])`.

## Service topology is a config fact, not an import form

Declaring that a module runs as its own service happens ONLY in `jac.toml`:

```toml
[scale.microservices.routes]
math_service = ""          # "" derives the route prefix (/math_service)
orders_app   = "/api/orders"
```

Modules in the routes table (the **service cut**) are server-anchored by definition; plain imports of them lower to RPC service stubs automatically - synchronous Python stubs server-to-server, async JS stubs client-to-service. `jac scale split <module>` writes an entry for you. There is no auto-discovery from source. See `jac-sv-microservices`.

## Native inference - extern C declarations are the seed

An import whose braces contain C-ABI function **declarations** is an FFI surface only the native backend can satisfy, so it seeds native placement - and the declarations that use those extern names (plus the helpers/`glob`s/`obj`s they reference) follow through the same reference propagation:

```jac
import from raylib { def InitWindow(w: i32, h: i32, title: str) -> None; }   # extern decls -> native seed

def open_window() -> None {        # uses InitWindow -> native
    InitWindow(800, 600, "hi");
}
```

- **Consuming a native module is NOT a signal.** `import from mymod { fast_fn }` where `mymod` is native code stays a server-side import - that is the server-to-native ctypes interop crossing, not a reason to relocate the importer. From client code the same import compiles the target to `/static/<stem>.wasm` and binds lazy async wasm stubs (see `jac-native-wasm`).
- **`test` blocks are never pulled native.** `jac test` runs them on the server, where they reach the native code through the generated interop stubs.
- **Referenced by both sides -> stays server.** Client and native inference run independently in one file; a declaration referenced by BOTH sides is placed server, where each side can bridge to it (auto-RPC for the client, py-interop for native).
- **Native-compatible pure code still defaults to server.** Compatibility is not intent: with no FFI seed, going native remains an explicit choice - a `[placement.pins]` entry mapping to `"native"`, a `.na.jac` implementation variant, or `jac nacompile` / `jac run --autonative` auto-promotion. See `jac-native`.

## Reviewing placements - the tooling

- **`jac check <entry> --placements`** prints every element's space with the evidence chain behind it (`seeded client: jsx construction`, `pulled client (dual): closure of client elements`, `pinned 'server' ([placement.pins])`, `ENDPOINT: pub access`), plus an estimated boundary-crossing count. First stop when something landed in the wrong bundle.
- **`jac check --update-placements-lock`** writes `jac.placements.lock` next to `jac.toml`. Commit it: placement flips become reviewable diffs like dependency bumps.
- **`jac check --verify-placements-lock`** fails (exit 1) if any computed placement differs from the committed lock - the parity gate for refactors and CI. An edit that silently turns three call sites into network round trips is loud instead of invisible.
- Editor hover shows `placement: <space> (inferred)` (plus `dual` when emitted into both spaces) for any symbol.

## Migration from marker-era code

`sv`/`cl`/`na` blocks, statement prefixes (`sv def`, `cl import`, `sv import from x { .. }`), and the `.sv.jac` suffix no longer parse - the error message points here. **`jac fix placement`** migrates a file or tree automatically: strips markers, renames `.sv.jac` files, preserves service topology as `[scale.microservices.routes]` entries, and records a `[placement.pins]` entry for any element whose inferred placement differs from its old marker. `--dry-run` previews; run `jac check --placements` after to review what inference decided.

## Rules

- **Markerless always.** Write plain `.jac` and let JSX/npm imports, python imports/archetypes, and extern C declarations decide. There is no placement syntax to reach for.
- **Client code must carry the structural signal.** A component infers client because it contains JSX or an npm import (directly or through what it references); a pure helper with neither stays server until client code references it, then it is pulled (or dual-emitted) into the bundle - across module boundaries too.
- **`def:pub` + JSX body = client component; `def:pub` in a server-anchored module = server endpoint**, RPC-bridged when the client calls it.
- **Pin in `jac.toml`** when client code references something that must stay server-side (secrets, server-only deps, trust boundaries): `[placement.pins] "mod.name" = "server"`.
- **`.cl.jac` / `.na.jac` are implementation-variant suffixes, not placement tools.** Use them for per-space implementations of one interface (e.g. a native stdlib variant); use inference and pins to place ordinary code.
- **Review, then lock.** `--placements` to see the evidence, `--update-placements-lock` + commit to make future flips reviewable.

## See also

- `jac-fullstack-patterns` - entry wiring, RPC call styles, endpoint registration
- `jac-cl-organization` - file layout for multi-component client apps
- `jac-sv-microservices` - the routes-table service cut between server modules
- `jac-native` - the native codespace
- `jac-project-kinds` - which codespaces each project kind combines
