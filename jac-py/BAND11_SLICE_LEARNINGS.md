# Band 11 slice 2 learnings: module/class-scope AnnAssign via `__annotate__`

## Landed

### Slice 3 (class scope, this drop)

- Class-scope AnnAssign lowers byte-exact vs the host oracle: cellvar
  `__classdict__` (plus `__conditional_annotations__` only when an entry sits
  under control flow), synthetic `__annotate__(format)` closed over the
  classdict cell via `LOAD_FAST_BORROW/BUILD_TUPLE/LOAD_CONST/MAKE_FUNCTION/
  SET_FUNCTION_ATTRIBUTE 8/STORE_NAME __annotate_func__`, emitted after the
  body loop and before the epilogue.
- STACK DISCIPLINE (pinned against host dis): BUILD_MAP pushes a dead
  accumulator; `LOAD_DEREF __classdict__` then stays on the value stack
  across ALL entries and is what RETURN_VALUE actually returns -- the classdict
  IS the annotations dict. Every bare-Name load inside an annotation emits the
  full `LOAD_DEREF __classdict__/LOAD_FROM_DICT_OR_GLOBALS name` pair (the
  pair re-seeds the cell mid-expression, e.g. between `list` and `int` in
  `list[int]`). Each entry ends `COPY 2` (dup the dict above the evaluated
  annotation), key const, STORE_SUBSCR. A leading constant entry relies on the
  leftover cell below and COPYs whatever sits there -- replicate exactly,
  including when no name load ever pushed the cell.
- Conditional-entry machinery is implemented (per-entry membership guard
  inside __annotate__, two-cell closure, SET_ADD registration at the
  AnnAssign site) but UNEXERCISABLE: any if/while/try in a class body fails
  to compile on HEAD with "Invalid CFG, instructions after terminator"
  (pre-existing, function-scope control flow works). Blocked shapes + host
  bytes documented in compiler_slice.jac comments; flip them to parity tests
  once that bug lands.
- Nested classes need `<locals>`-qualified qualnames (`f.<locals>.C.__annotate__`
  for the nested fn AND the class's own __qualname__ const). Our compiler has
  no such machinery for ANY nested def/class yet; collect_ann_plan_class takes
  class_qname so it inherits the fix automatically when sym_class_qualname
  produces full qualnames.
- Runtime: ceval dispatches the stored function's absence of opcode 91 --
  OP_LOAD_FROM_DICT_OR_GLOBALS is NOT implemented in ceval.jac, so calling
  C.__annotate_func__() raises "unsupported opcode 91". Also missing: type
  machinery mapping __annotate_func__ -> dynamic C.__annotate__ /
  C.__annotations__ attributes. layer9 test covers execution up to the
  callable being present in the class dict.

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
- Function-local behavior unchanged; class scope lowered by slice 3 (see
  above).
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
3. RESOLVED by slice 3 (class scope lowered byte-exact; remaining class
   runtime gaps tracked above).
4. Lambda/comprehensions/walrus inside deferred annotations trap loudly
   (unsupported construct) rather than mis-lower.

---

## Band-11 slice addendum: GeneratorExp + NamedExpr (commit 8229ee4d5)

1. Genexp lowering: nested `<genexpr>` code (flags 0x23 = OPTIMIZED|NEWLOCALS|
   GENERATOR, varnames ('.0', targets...), RETURN_GENERATOR prologue + PEP 479
   handler). The outermost iterable is evaluated in the ENCLOSING frame and the
   function is invoked via `CALL 0` whose self_or_null slot carries the iterator
   into `.0` (ceval already implements this convention). A genexp as sole call
   argument lowers callee-setup -> MAKE_FUNCTION -> iterable -> GET_ITER ->
   CALL 0 -> CALL 1.
2. Walrus: value eval + COPY 1 + scope-aware store. Symtable must define the
   walrus target; CPython's symtable visits Assign value BEFORE targets, so
   sym_visit_stmt(Assign) was reordered to match (affects co_varnames order
   whenever a walrus target sits inside an assigned value).
3. comp_leftmost_leaf now descends through NamedExpr so a comprehension elt
   beginning with a walrus still gets the lead STORE_FAST_LOAD_FAST fusion.
4. Fixed all-constant list/set display packing threshold to >= 3 elements
   (CPython packs only longer displays; 1-2 element const lists/sets use
   element loads). This unlocked the pinned b11 walrus golden (`len([1,2])`).
5. Known byte-parity gaps left for a future pass (all verified pre-existing or
   policy-level):
   - flowgraph deliberately omits global STORE_FAST+STORE_FAST and cross-slot
     STORE_FAST+LOAD_FAST fusion (over-fuse risk with coarser CFG blocks);
     CPython fuses both, so `y = (n := v)` in function scope and nested-loop
     genexps keep separate stores here. Needs CPython's finer CFG split of
     comprehension save/restore epilogues before enabling globally.
   - genexp-with-filter exceptiontable: CPython splits the generator protect
     region per block with a gap at the filter-jump block; we register one
     region. co_code matches exactly.
   - inline listcomp inside a function whose elt is `x+1` shape diverges at
     HEAD independent of this slice (SWAP arity at setup / epilogue order).
