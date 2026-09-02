# The Analysis Cache

The JIR module cache is the compiler's persistent analysis cache: every
module's cache file carries its **exported interface**, its **dependency
hashes**, and its **diagnostics**, and the compiler serves warm work from
those sections instead of recomputing it. This page records the design; the
[Phase 10 gate](compiler_architecture.md#the-jir-carries-semantics-decision-phase-10-gate)
in the architecture page records the decision this supersedes and the part
of it that still stands.

## What the gate got right, and what it missed

The Phase 10 gate rejected serializing *per-expression* semantics
(`Expr.type`, `callee_decl`), and that rejection stands: warm import-path
runs are already analysis-free, and a changed module must re-analyze
regardless of what any cache holds. But the gate was silent about two costs
it did not measure:

1. **The changed module's import closure.** Dependencies are ingested with
   the symtab-only schedule and demand inference walks into them, so every
   fresh `jac check` and every cold LSP start paid parse + symbol-table
   build + demand inference over the whole closure, every process.
2. **Diagnostics.** Nothing persisted them, so a warm no-edit `jac check`
   re-ran all eight analysis passes plus both boundary passes on every
   module, every process.

The analysis cache closes both gaps at the **interface** granularity: what a
module exports is small, stable, and exactly what importers consume.

## The three sections

All three live in the module's cache JIR
([`compiler/driver/jir.jac`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/driver/jir.jac)),
written through the same atomic merge-write funnel as the bytecode sections,
and gated by the same `SEC_MODKEY`/`SEC_ENVKEY` freshness checks.

### `SEC_IFACE` -- the exported interface

The module's exported surface in the **stubcat-generalized encoding**
([`compiler/types/stubcat/`](https://github.com/Jaseci-Labs/jaseci/blob/main/jac/jaclang/compiler/types/stubcat/)):
typed symbols with evaluated types, signatures, overloads, archetype
layouts, enum members, plus the access, ownership, binding-kind, and native
capability facts that the cross-module checkers read. The payload is a
single-module stub catalog produced by `CatalogWriter` in *boundary* mode:
anything homed in another module is written as a stable **symbolic
cross-reference** (module path plus dotted symbol path), never as a pickled
object graph, so payloads stay small and identity survives round trips.

The payload is prefixed with its own sha256 -- the **interface hash**. The
hash names the encoding, so byte-identical surfaces hash identically and any
semantic change to the surface changes the hash.

`compiler/types/stubcat/modiface.jac` holds the build/open entry points;
the typeshed stub catalog itself is the degenerate case of the same format
(whole-world boundary, no cross-references), which is why one codec serves
both.

### `SEC_DEPS` -- dependency hashes for early cutoff

One line per direct dependency: the dependency's resolved path and the
interface hash it had when this module compiled. Validating a module's
analysis sections re-derives each dependency's *current* hash (recompiling
the dependency if its own cache is stale -- which persists its fresh
interface as a side effect) and compares. A **body-only edit** changes the
dep's MODKEY and rewrites its JIR, but its interface hash comes out the
same, so importers replay instead of cascading. An **interface edit**
changes the hash and exactly the affected importers re-analyze.

Comptime dependencies (`SEC_CTDEPS`) fold in through validity rather than
through the hash: a changed comptime input invalidates the module's cache
entirely, the interface is rebuilt, and the rebuild cascades only if the
exported surface actually moved -- the same cutoff rule.

Dependency edges are recorded at the one seam every ingestion path goes
through (`JacProgram.load_dependency_module`), attributed to the innermost
compile frame, so nested dependency compiles record their own edges.

### `SEC_DIAG` -- diagnostics replay

The diagnostics a compile delivered, serialized as flat records (message,
code, full span including the source window, related spans, help text) and
grouped by **analysis profile**: a fingerprint of the compile flavor
(`no_cgen`, `native_parity`) plus the effective diagnostic policy
(suppressions, lint configuration). Replay requires a profile match, which
is what makes it safe that the policy is not part of the ENVKEY.

A warm no-edit `jac check` therefore runs **zero passes**: the module's
MODKEY/ENVKEY are valid, its dependency hashes match, and the stored
profile matches the requested one, so the stored alerts are rehydrated
(rendering byte-identically -- spans carry their source windows) and the
module itself is served from `SEC_IFACE`.

## Hydration is the only path

There is no flag that disables hydration. The two escape hatches are:

- `JAC_REBUILD=1` -- recompute everything and **rewrite** the cache. Results
  are identical by construction; the cache is never silently bypassed.
- `JAC_IFACE_VERIFY=1` -- serve from the cache *and* recompute in a fresh
  program, then diff: hydrated dependency interfaces against a source
  compile of the dep, replayed diagnostics against a fresh analysis. Any
  divergence raises. CI runs the equivalence suites under this mode so
  warmth can never change an observable result silently.

`compile()` keeps its historical return contract: a full-AST module, safe
for every tree-walking caller, present and future. Interface-grade service
is opt-in at the analysis-frontier seams via
`CompileOptions(iface_ok=True)`: dependency ingestion
(`load_dependency_module`), the registry's own dependency revalidation, and
check-style full-analysis compiles. A missed opt-in costs only caching,
never correctness. The one propagating override is
`CompileOptions(need_full_ast=True)` -- a consumer whose *transitive
dependency ingestion* must also be trees (code intelligence, which records
cross-module use-sites) declares it once and it flows through. Neither is a
cache toggle: the frontier seams opt in unconditionally, so hydration is
always on where analysis happens.

## Where it hooks

| Seam | Role |
|------|------|
| `JacCompiler._compile_once` | Serves eligible compiles from the cache before parsing; persists the analysis sections after the pipeline runs |
| `JacProgram.load_dependency_module` | Hub first (dirty buffers shadow disk), then the registry, then a source compile on a miss; records dependency edges |
| `JacProgram.iface_registry` (`compiler/driver/ifacecache.jac`) | Per-program registry: entry freshness, dep-hash validation, hydration, replay, verify |
| `write_module_cache` | Atomic merge-write: analysis writers and the bytecode writer share one JIR per module |
| LSP `_fanout_dependents` | Seeds the reverse-import index from persisted `SEC_DEPS` on first use, so who-imports-X fan-out works from a cold start |

Third-party surface: typed `.py` modules under site-packages persist and
hydrate interfaces under a toolchain+content key (`is_stub_like_path`), so
each is frontend-processed at most once per content across all processes.
`.pyi` files outside the bundled typeshed catalog deliberately keep their
real-AST derivation (a pinned identity contract; their frontend is the
cheap phase) -- they participate in `SEC_DEPS` through their content key
instead, so a stub edit still re-analyzes its importers.

The bootstrap and sealed-image paths are untouched: hydration never engages
for selfhost programs or compiler-tree modules, and the jac0 seed path does
not know the cache exists.

## The codegen lane

Codegen is the must-recompute core, so the cache helps it at the edges
rather than the center:

- **Precompile re-wraps the module cache.** A valid module-cache JIR already
  holds a unit's bytecode; `precompile_unit` re-keys and re-roots it
  directly instead of taking a `get_bytecode` round trip (which would still
  pay hub churn, native-engine restoration, and closure release). A cold
  `jac precompile` over a tree any prior run has compiled collapses to IO.
- **Interface bytes are memoized by MODKEY**, so re-persisting an unchanged
  module (a check after a run, a precompile after a check) reuses the
  encoded payload instead of re-deriving it.
- **The client-boundary walk consumes persisted facts.** When a changed
  module's client dependency is cache-valid, the walk restores the dep's
  interop manifest from `SEC_INTEROP` into `hub.artifacts` (the carrier
  interop consumers check first) and continues traversal over the dep's
  client-context edges recorded in `SEC_DEPS` flags, tree-compiling only on
  a miss. Implicit dataclass constructors synthesize from the interface's
  field-symbol surface (order, types, default and defer bits on each field
  symbol) when a class in the mro is interface-borne, because the cold
  synthesis walks `HasVar` nodes an interface module does not carry -- and
  a subclass must keep regenerating its constructor rather than inheriting
  a frozen one.

## Instrumentation

Every pass execution and cache event is counted on the program
(`JacProgram.analysis.pass_runs`, `.pass_time`, `.cache_events`), and the
acceptance tests (`tests/compiler/test_iface_cache.jac`) assert against
those counters, not timing: a warm no-edit check must show
`analysis_replay == 1` and an empty `pass_runs`; a body-only dep edit must
show the dep's `dep_miss_compile` without the importer's `TypeCheckPass`.
The timing decomposition (`tests/compiler/test_compile_timing.jac` and its
probe) carries `analysis` and `check` phases so cold/warm costs stay
attributable against the pinned baseline.

## Measurements

Stage 0 baseline and Stage 8 re-measurement on the chess fixture (warm
no-edit check, single-module-edit check, cold LSP start) are recorded on the
tracking issue and summarized here once the final numbers land with the
change itself.

## Non-goals (unchanged from the gate)

- Per-expression type hydration: hover data is served by the LSP's live
  in-memory program.
- Caching comptime execution, the placement solve, or import-graph
  resolution: comptime executes code, the solve is whole-program (over
  cached summaries), and the import graph is filesystem truth.
