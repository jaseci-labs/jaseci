# Placement

Where each top-level element of your program runs -- server, client (browser),
or native -- is a **derived compiler fact**, computed by a whole-program
placement solver. You write plain Jac; the solver reads the evidence and
places every element. The `cl` / `sv` / `na` markers remain fully supported,
but they are **overrides** for decisions inference cannot make, not how
programs are written.

## How placement is decided

Every module gets a **placement summary**: per top-level element, the
capability evidence it carries, its references to sibling elements, and its
value-flow escapes. Summaries are serialized into the module's `.jir` next to
the bytecode. The solver consumes summaries and owns every decision:

| Evidence | Pins toward |
|---|---|
| JSX construction, browser globals (`window`, `Date`, `setTimeout`, ...) | client |
| String-path (npm) imports | client |
| `root` access, node/edge/walker archetypes | server |
| Python imports not covered by the portability table | server |
| extern C declarations (clib imports) | native |
| `def:pub` in a server-anchored module | server (as an endpoint contract) |

From those seeds, placement propagates along symbol references to a fixpoint:
an element referenced by client code follows it into the bundle when its whole
closure can (**pulled client**); requirement-free elements reached from both
spaces compile into each (**dual emission**); and a reference whose closure
cannot move **bridges** instead -- `def:pub` calls over RPC, archetypes as
wire types, native elements over the wasm edge. Cross-module pulls happen
before code generation, so `jac check` sees the same placements as
`jac build`.

The analysis proposes; lowering disposes. A module that prefers native but
fails to lower is demoted to the server with a note naming the cause, and a
client-pulled element that fails ES lowering demotes the same way (its call
sites bridge instead). The portability table
(`jaclang/jac0core/portability.jac`) is the curated fact base for which
python modules may follow their referents into another space -- it is
honestly empty for the client today, so every python import pins server.

## Seeing and reviewing placements

- `jac check --placements` prints every element's space with the evidence
  chain behind it ("seeded client: jsx construction", "dual client: pulled
  through plain import from app.jac", "demoted server: failed ES lowering"),
  plus an estimated boundary-crossing count.
- Editor hover shows `placement: <space> (inferred | explicit marker)` for
  any symbol.
- `jac check --update-placements-lock` writes `jac.placements.lock` next to
  `jac.toml`. Committed, it makes placement changes reviewable: every build
  diffs fresh placements against it and reports flips ("`Ability:record_hit`:
  dual -> server"), so an edit that silently turns three call sites into
  network round trips is loud instead of invisible.

## When do I still write `sv` / `na`?

Surviving annotations are never *placement* facts -- the solver can infer
those. They are *meaning* facts dataflow cannot see:

| Category | Why inference cannot decide | Surface |
|---|---|---|
| Trust boundaries | A pure function can be *placeable* client-side yet *unsafe* there (secrets, price computation, validation) | `sv` as a security pin |
| API contracts | An endpoint is a promise (auth, serialization, versioning) to parties outside the program | `def:pub` in a server-anchored module |
| Stateful identity | Fork-per-space vs single-home for a mutable glob are different programs; both sound | home the glob with its writers via `sv` / `cl` (see W6006) |
| Environment-dependent semantics | Clock / RNG / env / fs mean different things per space; dual emission changes observable behavior | explicit home |
| Foreign-boundary facts | Ecosystem portability is not program dataflow | portability table + clib declarations |
| Cost mandates | The solver optimizes an average; you hold hard constraints it cannot know | `na` as a performance mandate |
| Stability pins | A correct placement flip can still be operationally disruptive | the lockfile + a marker to acknowledge a flip |

Punchline: `cl` and `na` as placement markers are unnecessary. What survives
is `sv`-as-trust-pin, `def:pub`-as-contract, and state / environment / FFI
declarations -- which were never placement markers to begin with.

## Related diagnostics

- `E5082` -- a plain client import references a symbol with no client-side
  presence (dead import).
- `W6005` -- a function-typed parameter at an RPC call site.
- `W6006` -- a mutable glob would be dual-emitted (state fork).
- `W6007` -- client code uses a server-placed function as a value.

See [Diagnostics](diagnostics.md) for the full reference.
