# GraphMend: FX Graph-Break Elimination

GraphMend is an opt-in set of compiler passes (`jac run --graphmend` / `-g`)
that rewrites PyTorch 2 code so `torch.compile` captures one contiguous FX
graph instead of a fragmented one. TorchDynamo falls back to eager execution
(a "graph break") whenever traced code forces a Python-level decision on
tensor data: a data-dependent `if`, a validation guard that raises, or an
untraceable side-effect call. Each break splits the compiled region and costs
real latency. GraphMend detects the fixable break patterns in the unified IR
(AST, CFG and symbol table together) and re-expresses them as graph-native
dataflow, before Python code generation, so only the Python lowering target is
affected. The JS and native backends see the original tree.

This page is the specification and legality argument for the passes that have
landed. It currently covers detection, trap lowering and predication
(`torch.where` / `torch.cond`); the side-effect deferral transform extends
this page when it lands.

## Activation and plumbing

- `jac run -g model.py` (or `model.jac`) sets `graphmend_enabled` on the
  active `JacProgram`.
- `JacCompiler.get_bytecode` translates that into
  `CompileOptions(graphmend=True)` for user modules. Internal `jaclang.*`
  modules are exempt: they contain no `torch.compile` entry points, so their
  bytecode is flag-independent and recompiling them per run would be waste.
- Every GraphMend pass gates itself on `CompileOptions.graphmend` in
  `before_pass` and prunes immediately when the flag is off, so the schedule
  is inert for normal compiles.
- The passes run in `get_py_code_gen`, immediately before `PyastGenPass`:
  `GraphBreakDetectPass`, then `TrapLoweringPass`, then
  `PredicateCtrlFlowPass`. The order is load-bearing: trap lowering removes
  the `raise` from a validation guard nested inside a data-dependent branch,
  which is what lets predication later hoist that branch's setup statements
  (the lowered assert is re-gated on the branch predicate, see below).
- Cross-pass state is typed and lives on `JacProgram`, not on AST nodes:
  `graphmend_breaks` maps a node id to its `GraphBreakKind` (detection to
  transformation), and `graphmend_helpers` maps a module id to the set of
  `GraphMendHelper` values whose imports the preamble must emit
  (transformation to code generation). Keying analysis results by node id on
  the program is the same idiom `_analyses_run` uses.
- Caching: transformed bytecode must never be served to (or from) a normal
  run. While GraphMend is active the compiler skips the sealed-JIR fast path,
  the on-disk module cache and the precompiled-JIR bundle, and does not write
  the compile result back to the cache. The in-memory hub is safe because the
  flag is constant within a single process. (Variant-keyed cache slots, which
  restore caching under the flag, arrive with the scoped-import work.)

## Detection: `GraphBreakDetectPass`

Detection implements the paper's Dynamo entry-point analysis plus graph-break
type analysis. It records a `GraphBreakKind` (declared in
`jac0core/constant.jac`) per break site; each kind names the single transform
allowed to lower it. Detection breadth grows in lockstep with the transforms:
a data-dependent conditional whose body is exactly one `raise` is tagged
`VAL_GUARD` (consumed by `TrapLoweringPass`); any other data-dependent
conditional is tagged `DYN_CTRL_FL` (consumed by `PredicateCtrlFlowPass`).
The side-effect kind arrives with the deferral pass.

### Entry points

A function or class is in scope when it is `@torch.compile`-decorated
(matched via `has_torch_compile_decorator` in `torch_attr_table.jac`).
Everything outside an entry point is left untouched. Call-site wrapping
(`m = Model(); torch.compile(m)`) is resolved by the scoped-import work,
which is also where whole-module treatment of imported model code lands.

Decorators are matched structurally (a `torch` name with a trailing `compile`
attribute), never by unparsing to text: Python-origin (`.py`) and Jac-origin
(`.jac`) trees unparse differently, so a text match silently fails on `.py`
models, which are the primary target (`jac run model.py -g`).

### Data dependence

A condition is data-dependent when it uses a dynamic torch attribute
directly, or when a bounded use-def trace shows it derives from one. The
dynamic-attribute table (`graphmend/torch_attr_table.jac`) lists ops whose
result depends on tensor data rather than static shape: `item`, `tolist`,
reductions, `nonzero`, `equal`, `allclose`, `unique` and so on. Extending
detection to a new op is one entry in that table. The use-def trace follows
each name in the condition back through its defining assignment (depth-capped
and cycle-guarded), so `seq_len = torch.max(position_ids) + 1` makes a later
`if seq_len > limit:` data-dependent even though the condition itself names
no torch op. Guard shapes the trap transform accepts always name their
dynamic op inline; branch conditions genuinely need the trace, which is why
it landed with the predication pass.

One deliberate precision choice: function parameters are NOT assumed dynamic.
Treating every parameter as tensor-derived would tag static guards such as
`if not isinstance(flag, str): raise`, which Dynamo handles without a break,
and rewriting them would be wrong. Detection keys on torch dynamic
attributes.

## Trap lowering: `TrapLoweringPass`

Validation guards of the form

```python
if not torch.equal(a, b):
    raise ValueError("unsupported attention mask")
```

raise on a data-dependent boolean, which forces the tensor back into the
interpreter and breaks the graph. Unlike data-dependent control flow they
produce no tensor output, so a `torch.where` mux does not apply. Instead the
guard is lowered to a graph-native assertion that raises at runtime without
breaking the graph:

```python
__jac_tensor_eq_assert__(a, b, '[[GM-TRAP ValueError]]unsupported attention mask[[/GM-TRAP]]')
```

and for a condition that is already a tensor boolean
(`.all()` / `.any()` / `.allclose()`):

```python
torch._assert_async(mask.all(), '[[GM-TRAP ValueError]]mask must be all true[[/GM-TRAP]]')
```

### Legality conditions

The pass is a conservative must-analysis: it fires only when safety is
established, and absence of proof means the guard is left intact. A break
left unfixed is a soundness property, not a defect.

1. The tagged `IfStmt` body is exactly one `raise` statement, and the
   condition is a unary `not X`. Only then is "assert X must hold" the exact
   meaning of the original guard.
2. `X` must be convertible to a tensor boolean: `torch.equal(a, b)` (a Python
   bool, special-cased below) or a call already returning a tensor bool
   (`.all`, `.any`, `.allclose`). The `.all`-form match is structural, by
   method name, so it proves nothing about the receiver, and a duck-typed
   receiver returning a Python bool would turn the graph-native assert into a
   type error. Tensor-ness must therefore be established statically: the
   receiver (or, for a comparison or arithmetic expression, at least one
   operand, since tensor operands make the result a tensor) must trace to a
   parameter whose annotation provably denotes the torch tensor class: either
   qualified `torch.Tensor`, or a bare name whose symbol binds at a
   `from torch import Tensor` item (aliased or not). The spelling `Tensor`
   alone proves nothing; a same-named class from another library declines the
   proof through its binding. When the proof holds, the guard lowers to
   `torch._assert_async` directly; when it does not, the guard declines and
   keeps its original Python semantics. Nothing is checked or dispatched at
   runtime.
3. `torch.equal` is rebuilt by the runtime helper `tensor_eq_assert` as a
   tensor op with a static precheck: shapes and dtypes must match before
   evaluating `(a == b).all()`, else the assert condition is a constant
   `tensor(False)`. The precheck is what keeps the rewrite value-equivalent:
   without it, broadcasting could make `(a == b).all()` true for shapes that
   `torch.equal` reports as unequal, and the precheck itself is static
   metadata that adds no break.
4. The original exception must be reconstructible at the call boundary, or the
   guard is left intact. Every one of the following must hold:

   - **An enclosing `@torch.compile`-decorated ability** to carry the eager
     decorator. A guard inside a decorated *class* has none of its own, and an
     async assert can surface after its method has already returned.
   - **A bare, unshadowed builtin exception name**, since the boundary
     resolves the marker through `builtins`. An aliased or qualified type such
     as `errors.ValidationError` would come back as `RuntimeError`, and a name
     the source rebinds (a resolved symbol at the raise site) no longer
     denotes the builtin the boundary would reconstruct, so both decline.
   - **Exactly one positional argument, no keywords, no `from cause`.** The
     marker carries one string, so anything else loses state: extra arguments
     are truncated, `raise ValueError()` would come back as `ValueError('')`
     with `args` changed from `()` to `('',)`, and an explicit chain cannot be
     rebuilt by a boundary that re-raises `from None`.
   - **A message that is a pure string literal** not containing
     `[[/GM-TRAP]]`. An f-string contributes only its `String` parts to
     `lit_value`, so folding one would keep the exception type and silently
     drop the diagnostic; a runtime expression (concatenation,
     `%`-formatting) admits no marker at all; an embedded closing delimiter
     would truncate the restored message.

   Detection still tags these guards; the decline belongs to the transform,
   not to the analysis.

### Exception-type preservation

`torch._assert_async` raises `RuntimeError`, and a graph-native assertion
fails asynchronously: the error surfaces at the call boundary, outside the
traced region, where an in-source `try`/`except` cannot catch it. When the
guard sits in a `@torch.compile`-decorated function and the message is a
string literal, the pass folds a self-describing marker into the message
literal at compile time (`[[GM-TRAP ValueError]]msg[[/GM-TRAP]]`) and
prepends the eager boundary decorator `@__jac_trap_guard__` to the function.
The decorator catches the `RuntimeError` at the boundary, parses the marker,
and re-raises the original exception type with the original message. Parsing
is defensive: an unmarked `RuntimeError`, one whose marker has no terminator
or no closing tag, or one naming something that is not an exception class,
propagates unchanged rather than being reinterpreted. Because condition 4
admits only bare builtin names and rejects messages containing the closing
delimiter, a lowered guard always restores exactly. The residual is an
unrelated `RuntimeError` whose own text embeds a complete, well-formed
marker; it would be restored as the exception that marker names.

The marker is folded at compile time, not concatenated at runtime, so the
assert stays a native torch op inside the graph. That also makes the marker
the limit of what can be preserved: a runtime concat to rebuild a dynamic
message would reintroduce the break it is trying to remove, so there is no
fallback. When the marker cannot be built -- a non-literal message, or an
entry point compiled at a call site with nothing to decorate -- the pass
declines under condition 4 rather than lowering a guard whose exception
contract it cannot honor. Widening this is a coverage question for later
passes (call-site entry resolution lands with the scoped-import PR), not a
licence to weaken the contract now.

### Runtime support

Two helpers back the transform, exported through `jaclib` and imported by
the generated module preamble only when the pass actually used them
(`__jac_tensor_eq_assert__`, `__jac_trap_guard__`). Both live on `JacBuiltin`
in `jac0core/runtime.jac`. The tensor-bool form needs no helper: its
receiver's tensor-ness is proven at compile time, so the pass emits
`torch._assert_async` directly.

## Predication: `PredicateCtrlFlowPass`

A data-dependent `if`/`else` (tagged `DYN_CTRL_FL`) forces TorchDynamo to
pick a Python path from tensor data, splitting the graph at the branch. The
pass rewrites the branch into a single graph-native selection so both paths
stay inside one FX graph. It fires only when both branches produce the same
output, so the rewrite is provably semantics-preserving; anything more
complex (differing targets, elif chains, a missing `else`) is left intact.

The predicate must also be a tensor. `torch.where` rejects a Python `bool`
condition, so a branch whose predicate materializes a scalar (`.item()`,
`.tolist()`, `torch.equal`, `torch.allclose`, named inline or reached through
the use-def chain that tagged the branch) is declined. Nothing is lost by
that: the materializing call is itself the break, and predication cannot
remove it. Such a branch stays tagged `DYN_CTRL_FL` and unrewritten.

### Reconciliation shapes

Three shapes are accepted, matched on the final statement of each branch:

```python
if c: x = A            # same-target assignment
else: x = B            #   -> __gm_cond = c; __gm_true = A; __gm_false = B
                       #      x = torch.where(__gm_cond, __gm_true, __gm_false)

if c: return A         # same-shape return
else: return B         #   -> ...; return torch.where(...)

if c: g(a, k=K)        # common call: same callee, same kwargs, same arity
else: g(b, k=K)        #   -> g(torch.where(__gm_cond, a, b), k=K)
```

The common-call form merges each differing positional argument with its own
`torch.where` and emits the call once; kwargs must be textually identical and
the callee texts must match. Branch values that are `None` decline (no tensor
selection exists for it), as does a branch pair mixing a call with a literal
(see below).

### `torch.where` versus `torch.cond`

`torch.where` is an ordinary call, so both operands are evaluated regardless
of the predicate. For symmetric values (bare names, pure arithmetic) that is
harmless and is what the pass emits. When a branch value contains a function
call, evaluating both sides would run a call the original program did not
run, which is not merely wasteful: it is unsound whenever that call is only
valid under its own predicate. For that shape the pass emits `torch.cond`,
whose lambda branches execute only the selected path:

```python
x = torch.cond(__gm_cond_0, lambda: f(a), lambda: g(b), ())
```

The selection is ordered by legality first and cost second: `torch.cond`
introduces branch-dispatch synchronization and disables CUDA Graph capture
for the region, so `torch.where` is preferred wherever it is legal. One gap
remains: a call paired with a literal. `torch.where` would speculate the
call, and `torch.cond` cannot return a Python literal, so neither form is
sound and the branch is left untouched, break included.

### Multi-statement branches and hoisting legality

When both branches end in the same call but carry setup statements before it,
the setups are hoisted to run unconditionally (predication computes both
paths). A hoisted setup must therefore be observationally neutral on the
untaken path. Two obligations apply, and failing either declines the whole
rewrite:

1. Control neutrality: no `return`, `raise`, `break` or `continue` anywhere
   in a setup, else a control transfer becomes unconditional.
2. Effect neutrality: every setup must be one of the licensed forms below.
   Anything else, in particular a non-idempotent observable write such as
   `self.counter += 1`, is declined and the break is left intact.

The licensed forms:

- A pure write to bare local names whose value contains no call, and whose
  target is confined to the region: the name appears nowhere else in the
  enclosing function, and the two branches do not write the same target.
  Without both conditions the write is not neutral, it is just invisible at
  the assignment itself. A name read after the branch would carry the taken
  path's value onto runs that took the other one, and a name written by both
  branches would leave the second write standing for both, so the merged call
  would read the untaken branch's operand.
- An idempotent device move `x = x.to(...)` where the target is textually the
  receiver. Re-running it is a no-op.
- A lowered validation assert (`torch._assert_async(...)` produced by
  `TrapLoweringPass`). It is hoisted but re-gated on the branch predicate so
  it cannot fire on the untaken path: the check `C` becomes
  `torch.logical_or(torch.logical_not(cond), C)` for the true branch and
  `torch.logical_or(cond, C)` for the false branch. The `torch.equal` guard
  form (`__jac_tensor_eq_assert__`) computes its check inside the helper
  where no predicate can be injected, so its presence declines the rewrite
  rather than asserting unconditionally.
- An existence-guarded initialization, under the conditions below.

### The existence-guard license

`if not hasattr(X, "k"): X.k = init(...)` is the one licensed hoist that
creates state earlier than the original program would. The `hasattr` shape
alone is not sufficient; five conditions must hold:

- G1, shape: the guard has no `else` branch.
- G2, memoization: the body definitely assigns `X.k`, so the guard closes and
  re-execution is a genuine no-op. Without this the body re-runs on every
  call, and hoisting it would run a live write on the untaken path.
- G3, body neutrality: every other statement in the body is itself a neutral
  assignment. Only the memoizing write may contain a call (the initializer);
  arbitrary I/O smuggled in under a `hasattr` header is declined.
- G4, confinement: the attribute `k` is read nowhere in the module outside
  the rewritten region, including via string literals equal to `"k"` (which
  could feed `hasattr`/`getattr`/`setattr`). Early existence must not be
  observable by any code the pass can see.
- G5, initializer safety: every call in the memoizing write resolves to
  inspectable code that is pure and non-raising for the arguments this call
  site passes. A bare-name callee must resolve to a module-level function. An
  attribute callee such as `self.rope_init_fn` cannot be resolved from one
  module, but the dispatch-table idiom is still decidable: the candidate set
  is every function reachable through any module-level dict of local
  functions, narrowed by signature compatibility (a function the call would
  raise `TypeError` on cannot be the callee), and every surviving candidate
  must clear the purity check. A `raise` inside a candidate counts as
  unreachable only in the varkwargs-validation form (`if rope_kwargs: raise`)
  when this call passes no unexpected keyword. Purity is transitive into
  local helpers; unresolvable calls are opaque and decline. A library call is
  pure only when the call as a whole is checked, never its leaf name alone.
  A `torch`/`math` call needs its leaf on the pure-operation list (tensor
  construction and elementwise math): being rooted at `torch` proves nothing,
  since `torch.save` writes a file and `torch.manual_seed` mutates global RNG
  state. A pure tensor method (`to`, `float`, `double`, `clone`, `detach`)
  needs a receiver that is itself a pure call, so
  `torch.arange(...).float().to(device)` is accepted while `session.clone()`
  or `store.get(k)` is not: those names are no-ops on a tensor and arbitrary
  work on anything else. The consequence is stated under residuals below.

### Caveat: speculated memoization is a state change, not a no-op

The existence-guard hoist runs the initializer on executions where the
original predicate would have been false, so the memoized attribute exists
earlier than the original program would create it. The `hasattr` guard makes
replay idempotent (running twice equals running once); it does not make
speculation invisible. What makes the hoist legal is confinement (G4): the
attribute is a private memoization slot no other code in the module can test
or read, so no observer inside the compiled module distinguishes "cached now"
from "cached on a later call". Two assumptions remain outside what the
analysis can discharge: an observer in another module (an external `hasattr`,
a `__dict__` or `state_dict()` walk, a subclass in another file) can still
see the slot early, and an attribute callee bound to something other than a
module-level dispatch table would not be seen by G5. The honest phrasing of
the guarantee is therefore equivalence modulo private memoization state.

### Configuration reads: proving `.get` from a constructor invariant

Requiring a pure receiver would cost real coverage on its own. A rope
initializer of the `transformers` `_compute_longrope_parameters` shape reads
its configuration with `config.rope_scaling.get("factor")`. That call is pure
in fact, because the receiver is a plain dict, but no purity list can say so:
the same expression shape covers `session.get(url)`.

The proof comes from the source instead. Before the pass runs, a fact
collector (`graphmend/scope_facts.jac`) scans every module the program has
read and records three tables on `JacProgram`: which classes apply which
decorator to a method, which `__init__` parameters with class annotations are
stored onto `self`, and which attributes a class's construction path forces
to be a dict, i.e. an `if not isinstance(self.attr, dict): raise` reachable
from `__init__` (directly or through a helper `__init__` calls, transformers'
`_rope_scaling_validation` idiom). At a speculated call site the pass then
types each argument, from the call-site annotation or through the stored
attribute types, and accepts `param.attr.get(...)` only when every candidate
class for `param` carries the dict invariant on `attr`. `LooseConfig`-style
classes that never validate the attribute stay opaque and decline.

Two residuals, stated rather than papered over. The transformers validator
permits `None` (`if self.rope_scaling is None: return`), recorded as
`dict_or_none`: a speculated `.get` on a None-config model raises
`AttributeError` on a path the original never executed, the same class of
residual as an initializer that raises for branch-specific arguments. And the
fact tables key on bare class names; module-qualified keys arrive with the
scoped-import work, where whole packages enter the analysis.

## Evidence

`tests/compiler/passes/main/test_graphmend_trap_lowering.jac` and
`test_graphmend_ctrl_flow.jac` assert detection tags and the generated
Python source for `.jac` and `.py` fixtures, including one decline test per
legality condition above.
`test_graphmend_trap_integration.jac` and
`test_graphmend_where_integration.jac` (skipped without torch) drive the
transformed code through a counting Dynamo backend and assert the paper's
metric directly: each fixture fragments into two or more graphs without
GraphMend and exactly one with it. The trap tests additionally check that a
failing guard under a real eager-backend compile surfaces as the original
`ValueError` with the original message, with no marker text leaking to the
user; the predication tests additionally check that a hoisted, re-gated
assert stays dormant when its branch is not taken.
