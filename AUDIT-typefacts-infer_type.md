# Sizing audit + fix: deleting `infer_type` (TODO #3, facts-vs-checker consolidation)

> **STATUS: DONE.** `infer_type` deleted. Full `tests/compiler/c2jac/` green
> (106 passed, same 4 pre-existing CastBuildPass-lifter baseline failures, zero
> regressions). The three-part fix that made it possible:
>
> 1. `TypeFactsPass.transform`: stamp `self.facts.prog = self.prog` (routes the
>    ownership pass's per-module facts through the checker).
> 2. `type_of_via_checker`: when there is no `type_ids` index (the ownership
>    pass's per-module object), return the resolved archetype's bare
>    `arch.name.value` - matching `infer_type`'s name-space semantics exactly.
> 3. `TypeFacts.type_of`: checker-only, `""` fallback; `infer_type`/`_attr_name`
>    and their decls removed (−152/+12). Verified `infer_type` was never
>    load-bearing after (1)+(2) via divergence instrumentation before deleting.
>
> **ALL FOUR ITEMS NOW DONE.**
>
> - **#1 (keystone converter):** extracted `TypeFacts.typebase_to_typename(ty)` -
>   the checker-`TypeBase`→type-token converter - out of `type_of_via_checker`'s
>   inline body (behavior-preserving); `type_of_via_checker` is now a thin wrapper.
>   This is the seam #2 routes field/method/return types through.
> - **#2 (maps checker-derived):** the map *values* in `field_types`/`method_returns`/
>   `func_returns` are now resolved through the checker (eager
>   `TypeEvaluator.get_type_of_expression(annotation)` → `typebase_to_typename`) via
>   new `TypeFactsPass.resolve_ann_token(ann, syntactic)`, with **syntactic fallback**
>   whenever the checker yields no token (generics like `list[int]`, unresolvable).
>   `arch_type_maps` (the syntactic-only builder) deleted; `index_arch` inlined.
>   **Verified:** full `tests/compiler/c2jac/` green (106 passed, same 4 baseline
>   CastBuildPass-lifter fails) AND `JAC_TF_DIVERGE` instrumentation showed **zero**
>   checker-vs-syntactic divergences across the whole corpus - a pure, behavior-
>   preserving swap that is now correct-by-construction for aliased/qualified
>   annotations the corpus doesn't exercise. (Divergence print was instrumentation,
>   removed after measuring - `print` also trips the repo no-print lint gate.)
> - **#3 (delete infer_type):** done (see below).
> - **#4 (delete arch_types.jac):** dead `jaclang/compiler/arch_types.jac` (143 LOC,
>   last `infer_type`/`_attr_name` copy + old buggy `is_ref_arch`) `git rm`'d -
>   unimported; compiler imports clean.
>
> TypeFacts is now a true thin adapter over the real checker: no syntactic
> expression re-inference (#3), and the semantic maps route through the checker
> with a syntactic safety net (#1+#2). Nothing committed yet.
>
> Original sizing analysis below.

---

**Goal:** measure how load-bearing `TypeFacts.infer_type` (the 115-line syntactic
fallback) actually is, so we can decide whether/when it can be deleted and the
jac2c emit lane can drop its shadow type system.

**Method:** env-gated instrumentation in `TypeFacts.type_of` categorizing every
call, run over the full `tests/compiler/c2jac/` suite (110 tests). Categories:

| cat | meaning |
|-----|---------|
| `C` | prog present, `Expr`, checker (`type_of_via_checker`) answered |
| `D` | prog present, `Expr`, checker empty, `infer_type` answered → **the gap** |
| `E` | prog present, `Expr`, both empty |
| `N`/`n` | facts object had `prog=None` → checker bypassed entirely, `infer_type` used |
| `X`/`x` | non-`Expr` `e` (never occurred) |

## Corpus scope

`TypeFacts` / `infer_type` is exercised **only by the jac2c C backend**
(`c_gen_pass`, and the `ownership_facts_pass` it invokes). Confirmed empirically:
running the native `.na` LLVM suite produced **zero** `type_of` calls - the
`NativeGenPass` pipeline never touches `TypeFacts`. So `tests/compiler/c2jac/`
is the complete corpus; there is no separate "na fixture" gap to chase.

## Results

**Baseline (as-is):** 1549 `C`, **240 `N`**, 38 `n`, 0 `D`, 0 `E`.

- The checker answers 100% of the calls it is *eligible* for (`D`=0, `E`=0).
- But 278 calls (`N`+`n`) run against a facts object with `prog=None`, so the
  checker is bypassed and `infer_type` is the sole evaluator. **This - not a
  checker coverage gap - is what keeps `infer_type` alive.**

**Root cause of the `prog=None` bypass:** `get_type_facts()` builds a per-module
`TypeFacts` via `TypeFactsPass.transform`, which never stamps `prog` (or
`type_ids`) onto the facts object. `c_gen` queries a *separate* merged object
(from `get_shared_type_facts`, which does set both), but `ownership_facts_pass`
(`self.tf = get_type_facts(mod, self.prog)`) pulls the un-stamped per-module
object → its queries bypass the checker.

**After stamping `self.facts.prog = self.prog` in `transform`:**
1743 `C`, **64 `D`**, 20 `E`, **0 `N`/`n`**.

- Wiring `prog` moved 194 queries onto the checker and eliminated the bypass.
- 64 residual `D` (infer_type still load-bearing) + 20 `E` (both blind) remain.

**The 64 `D` are two patterns only:**

- 52 `FuncCall` - archetype constructor calls (`Counter(7)`, `Point()`, `Box(inner)`…)
- 12 `Name` - bare locals typed as an archetype (`a` : `Counter`/`Point`)

**Why the checker returns empty for those 64** - instrumented
`type_of_via_checker`'s failure reason: **all 30 distinct cases = `type_ids-None`.**
The checker *correctly* types each as `ClassType(<Archetype>)`; the bridge fails
only at `self.type_ids.has_arch(arch)` because the per-module facts object has
`type_ids = None` (again, only the merged/shared object gets `type_ids` set).
It is **not** a name-keyed-identity keying mismatch and **not** a checker miss.

The 20 `E` are constructor calls where `infer_type` *also* returns empty
(cross-module / factory-returned types its maps don't cover) - deleting
`infer_type` loses nothing there; they are pre-existing latent emit blind spots
orthogonal to this refactor.

## Verdict / sizing

`infer_type` is **not deletable as-is**, but the entire dependency reduces to
**two missing field-wirings on the per-module facts object** that the ownership
pass queries:

1. `prog` - currently `None` (accounts for the 240 `N`).
2. `type_ids` - currently `None` (accounts for the 64 `D`).

Wire both onto that object (or have `ownership_facts_pass` query the shared
facts that already carry them) and the checker answers everything the emitter
asks: `N`, `n`, `D` → 0, leaving only the 20 `E` (which `infer_type` also can't
answer). At that point `infer_type` is dead code and #3 is a clean deletion.

**The one real design question** for the `type_ids` wiring: the shared
`TypeIdIndex` is built from `[mod] + imported_mods` (needed for cross-module
name collisions). The per-module ownership pass doesn't have that set on hand,
so the fix is either (a) route the ownership pass to the shared facts, or
(b) attach a `TypeIdIndex` at per-module construction (single-module index
suffices for the non-colliding majority; collisions need the full set). Squarely
name-keyed-identity work, bounded.

## Bottom line for the PLAN

`#3` is **not** the open-ended "measure coverage across the corpus and burn down a
long divergence list" risk the original scope-out feared. The divergence list is
**64 items in 2 patterns with a single shared root cause** (`type_ids`/`prog`
unset on the per-module ownership facts). Recommended sequencing unchanged:
do #1/#2/#4 (the low-risk keystone + map flip + dead-file delete) first; then #3
becomes: wire `prog`+`type_ids` onto the ownership facts, confirm the audit reads
`D=N=0`, delete `infer_type`.
