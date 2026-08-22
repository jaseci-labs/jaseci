# Band 11 slice 2 learnings: module/class-scope AnnAssign via `__annotate__`

## Landed

- Module-scope AnnAssign lowers byte-exact vs the host oracle (b11_annotations
  goldens): module gains cellvar `__conditional_annotations__` (MAKE_CELL with
  NO_LOCATION before RESUME), scope-entry setup bytes
  (`LOAD_CONST <code>/MAKE_FUNCTION/STORE_NAME __annotate__` +
  `BUILD_SET 0/STORE_NAME __conditional_annotations__`), inline value store,
  then per-annotation `LOAD_NAME/LOAD_SMALL_INT i/SET_ADD 1/POP_TOP`.
- Nested `__annotate__(format)` code object: flags OPTIMIZED|NEWLOCALS,
  positional-only varnames ['format'], dead small-int const '2', format>2
  guard raising NotImplementedError (LOAD_COMMON_CONSTANT 1), BUILD_MAP 0,
  guarded COPY/STORE_SUBSCR entry per annotation, RETURN_VALUE.
- Attribute/subscript targets never join the annotation dict (plain assignment
  semantics; bare forms evaluate the target object and POP_TOP).
- Function-local behavior unchanged; class scope still traps loudly
  (NotImplementedError) until the `__classdict__`/`__annotate_func__` closure
  slice lands.
- Runtime: layer9 ceval executes the whole machinery (module MAKE_CELL,
  annotate fn object, format-guarded dict) -- covered by new layer9 tests.

## Non-obvious CPython mechanics pinned empirically (host 3.14.7)

- Setup BYTES sit at scope entry, but the `__annotate__` const/name slots are
  allocated AFTER the whole body: CPython compiles setup into a separate
  instruction stream spliced at entry (`_PyCompile_StartAnnotationSetup`), so
  statement consts interleave BEFORE the code-object const. We emit placeholder
  LOAD_CONST/STORE_NAME instructions and patch their opargs post-body,
  inserting the const before any None that branch duplication enqueued
  mid-loop (host defers the shared return-None to scope finalization;
  literal-None predecessors remain a documented divergence).
- Head location: setup bytes, the __annotate__ guard/BUILD_MAP/STORE_SUBSCR/
  RETURN_VALUE, and the nested fn's firstlineno all derive from the FIRST
  statement's full AST span (compound stmts include their body). Entry-region
  instructions use the owning AnnAssign's span; only the annotation expr's own
  instructions carry their natural spans.
- Dead small-int rule: first 0..255 literal keeps a dead co_consts slot only
  when the pool is empty; registration/guard ints share this path.
- `__conditional_annotations__` is a MODULE cellvar but `__annotate__` reads it
  with LOAD_GLOBAL (class scope would use LOAD_DEREF over `__classdict__`).

## Known gaps / follow-ups

1. Linetable divergence when the head location spans multiple lines (module
   starting with if/def/class before the annotations) and in subscript-heavy
   annotation expressions. The no-annotation baselines (`T = int\ny =
   list[int]`, `x = 1\ntry: ...`) show the same assembler linetable deltas, so
   the gap lives in assembler.jac's location-table writer, not this slice.
2. Import-cycle gate currently FAILS on HEAD independent of this slice
   (compiler_codegen -> compiler_loops/match cycles introduced by the
   codegen-decomposition merge); needs its own fix lane.
3. Class scope: host shape fully documented in goldens (cellvar
   `__classdict__`, `__annotate_func__` closure, LOAD_DEREF index counts fast
   locals first, LOAD_FROM_DICT_OR_GLOBALS for names) -- implementable as a
   follow-up slice; requires an emit-layer hook for classdict name loads.
4. Lambda/comprehensions/walrus inside deferred annotations trap loudly
   (unsupported construct) rather than mis-lower.
