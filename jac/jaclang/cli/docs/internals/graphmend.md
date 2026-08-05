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
landed. It currently covers detection and trap lowering; the predication
(`torch.where` / `torch.cond`) and side-effect deferral transforms extend this
page as they land.

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
  `GraphBreakDetectPass`, then `TrapLoweringPass`.
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
allowed to lower it:

| Kind | Pattern | Consumer |
|---|---|---|
| `VAL_GUARD` | data-dependent `if not C: raise` | `TrapLoweringPass` |
| `DYN_CTRL_FL` | data-dependent `if`/`else` | predication (future PR) |
| `SIDE_EFFECT` | `print` / logger call | deferral (future PR) |

### Entry points

A function or class is in scope when it is `@torch.compile`-decorated, or
wrapped at a call site: `torch.compile(fn)`, `torch.compile(Model())`, or
`m = Model(); torch.compile(m)` (resolved through the symbol table to the
defining `Ability`/`Archetype`). Methods of a wrapped class become in scope.
Everything outside an entry point is left untouched.

Decorators and call sites are matched structurally (a `torch` name with a
trailing `compile` attribute), never by unparsing to text: Python-origin
(`.py`) and Jac-origin (`.jac`) trees unparse differently, so a text match
silently fails on `.py` models, which are the primary target
(`jac run model.py -g`).

### Data dependence

A condition is data-dependent when it uses a dynamic torch attribute
directly, or when a bounded use-def trace over the symbol table shows it
derives from one (for example `seq_len = torch.max(position_ids) + 1` used in
a later branch). The dynamic-attribute table
(`graphmend/torch_attr_table.jac`) lists ops whose result depends on tensor
data rather than static shape: `item`, `tolist`, reductions, `nonzero`,
`equal`, `allclose`, `unique` and so on. Extending detection to a new op is
one entry in that table.

Two deliberate precision choices:

- Function parameters are NOT assumed dynamic. Treating every parameter as
  tensor-derived would tag static introspection such as
  `if hasattr(self, "flag")`, which Dynamo handles without a break, and
  rewriting it would be wrong. Detection keys on torch dynamic attributes.
- A call like `print(...)` is only tagged `SIDE_EFFECT` when the name still
  resolves to the builtin; a user-defined function that shadows a
  logging-like name is not tagged.

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
2. `X` must be convertible to a tensor boolean. Two cases are accepted:
   `torch.equal(a, b)` (returns a Python bool, special-cased below) and calls
   already returning a tensor bool (`.all`, `.any`, `.allclose`). Anything
   else declines.
3. `torch.equal` is rebuilt by the runtime helper `tensor_eq_assert` as a
   tensor op with a static precheck: shapes and dtypes must match before
   evaluating `(a == b).all()`, else the assert condition is a constant
   `tensor(False)`. The precheck is what keeps the rewrite value-equivalent:
   without it, broadcasting could make `(a == b).all()` true for shapes that
   `torch.equal` reports as unequal, and the precheck itself is static
   metadata that adds no break.

### Exception-type preservation

`torch._assert_async` raises `RuntimeError`, and a graph-native assertion
fails asynchronously: the error surfaces at the call boundary, outside the
traced region, where an in-source `try`/`except` cannot catch it. When the
guard sits in a `@torch.compile`-decorated function and the message is a
string literal, the pass folds a self-describing marker into the message
literal at compile time (`[[GM-TRAP ValueError]]msg[[/GM-TRAP]]`) and
prepends the eager boundary decorator `@__jac_trap_guard__` to the function.
The decorator catches the `RuntimeError` at the boundary, parses the marker,
and re-raises the original exception type with the original message; unmarked
`RuntimeError`s propagate unchanged, and unknown (non-builtin) types degrade
to `RuntimeError` so no message is ever lost.

The marker is folded at compile time, not concatenated at runtime, so the
assert stays a native torch op inside the graph. When the message is not a
literal, or the entry point is a module compiled at a call site (nothing to
decorate), the lowering degrades to message-only rather than declining.

### Runtime support

Two helpers back the transform, exported through `jaclib` and imported by the
generated module preamble only when the pass actually used them
(`__jac_tensor_eq_assert__`, `__jac_trap_guard__`). Both live on `JacBuiltin`
in `jac0core/runtime.jac`.

## Evidence

`tests/compiler/passes/main/test_graphmend_detect.jac` and
`test_graphmend_trap_lowering.jac` assert detection tags and the generated
Python source for `.jac` and `.py` fixtures.
`test_graphmend_trap_integration.jac` (skipped without torch) drives the
transformed code through a counting Dynamo backend and asserts the paper's
metric directly: the validation-guard fixture fragments into two or more
graphs without GraphMend and exactly one with it, and a failing guard under a
real eager-backend compile surfaces as the original `ValueError` with the
original message, with no marker text leaking to the user.
