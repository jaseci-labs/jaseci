# Plan: Vectorized byllm functions (`@vectorize` / vmap)

**Branch context:** builds on `fix_param_prompt` (four-zone prompt work in
`jac/jaclang/byllm/impl/mtir.impl.jac`).

## 1. Goal

Syntactic sugar that applies a scalar `by llm` function over a collection:

```jac
import from byllm.lib { Model, vectorize }
glob llm = Model(model_name="gpt-4o-mini");

@vectorize                                # or @vectorize(strategy="batch", batch_size=8)
def classify(text: str) -> Sentiment by llm();

with entry {
    results = classify.vmap(reviews);     # list[Sentiment], order-preserving
}
```

**Semantics contract (the spec):** `vmap` over `f: (T, ...) -> R` is
observationally equivalent to `[f(x, ...) for x in items]`:

- Order-preserving; result `i` corresponds to input `i`.
- Items are independent - no cross-item context may influence a result.
- Execution strategy (N parallel calls vs. one batched call vs. chunked
  batches) is a runtime choice and MUST NOT change observable semantics.

The loop is the *definition*; batching is an *optimization* that must be
validated against it. `batch_size=1` degenerates to the loop.

## 2. Why (justification, for the eventual PR description / paper)

1. Mapping an LLM function over a collection is the dominant byllm workload
   shape; today it is hand-written serial loops.
2. Users **cannot** implement the batched strategy themselves without
   abandoning MTP: the prompt is synthesized from signature + types +
   semstrings inside `MTRuntime.factory`. Only the runtime can rewrite the
   prompt to carry N indexed call frames while preserving declared meaning.
3. Declarative surface lets the runtime evolve (auto batch-size, provider
   prompt caching, batch APIs) with no user-code changes. Precedent:
   `jax.vmap`, NumPy vectorization, SQL set semantics, LOTUS `sem_map`.
4. Cost math: prompt scaffold (persona + signature header + schema zone) is
   typically 200–800 tokens vs. ~tens of tokens per short item; batching
   amortizes the scaffold across the batch (input cost ~1/b for short items)
   and cuts round trips. Known risk from batch-prompting literature: accuracy
   degrades as b grows (contamination, positional bias) - hence chunking,
   validation, and fallback are mandatory, not optional.

## 3. Current call path (verified)

1. Codegen wraps `def f(...) -> R by llm;` with the `by` decorator:
   `jac/jaclang/jac0core/impl/runtime.impl.jac:1728-1748` -
   `_wrapped_caller(*args, **kwargs)` builds
   `MTIR(caller, invoke_args, model.call_params, fetch_mtir(caller)).runtime`
   then `model.invoke(mt_run)`.
2. `MTIR` / `MTRuntime`: `jac/jaclang/byllm/mtir.jac:27-73`;
   `MTRuntime.factory` (four-zone prompt: header / schema / bindings /
   identity) at `jac/jaclang/byllm/impl/mtir.impl.jac:153`.
3. Output typing: `resp_type` → `get_output_schema` / `get_typed_output_schema`
   → `parse_response` (`jac/jaclang/byllm/mtir.jac:62-72`).
4. LLM execution: `Model.invoke` at
   `jac/jaclang/byllm/llm.impl/model.impl.jac:86`.
5. Existing parallel infra to mirror/reuse: shared `ThreadPoolExecutor` +
   dispatch decision tree in `jac/jaclang/byllm/parallel.jac`
   (`_WORKER_POOL`, `dispatch_batch`).

## 4. Surface design decisions

| Decision | Recommendation | Rationale |
|---|---|---|
| Scalar call preserved? | Yes - `@vectorize` leaves `f(x)` intact and attaches `f.vmap(items)` | No type-dispatch magic (ambiguous when `T` is itself a list); checker stays sane; mirrors `jax.vmap` returning a new callable |
| Multiple params | v1: vectorize over the **first** param, remaining args broadcast as scalars; `over="name"` to pick another | Simple, covers the common case; zip/multi-axis later |
| Strategy | `strategy="parallel" \| "batch" \| "auto"`, default `"parallel"` | Loop is the reference; batch is opt-in until measured |
| Batch size | `batch_size: int = 8`; large inputs chunked; chunks dispatched in parallel | Both options compose; literature says keep b small |
| Error policy | `on_error="raise" \| "none"`, default `"raise"`; per-item retry `retries=1` | Failure isolation is a selling point of the loop path |
| Concurrency | `concurrency` param, else reuse `BYLLM_TOOL_WORKERS` pool sizing | Consistent with `parallel.jac` |

## 5. Phase 1 - loop strategy (runtime only, no compiler changes)

New file `jac/jaclang/byllm/vectorize.jac` (+ `impl/vectorize.impl.jac`):

- `def vectorize(fn: Callable) -> Callable` and the parameterized form
  `vectorize(strategy=..., batch_size=..., ...)` (decorator factory).
- Attaches `fn.vmap = <bound dispatcher>`; dispatcher submits one scalar call
  per item to a worker pool (pattern of `parallel.jac::dispatch_batch`,
  including the size==1 inline shortcut), collects in input order.
- Per-item try/except implementing `on_error` / `retries`.
- Export from `jac/jaclang/byllm/lib.jac` (and confirm re-export path used by
  `import from byllm.lib { ... }`).

Enabler in `jac/jaclang/jac0core/impl/runtime.impl.jac:1744` (one-line): have
`JacLLM.by` stamp attributes on `_wrapped_caller` -
`_jac_by_caller = caller; _jac_by_model = model;` - so `vectorize` (and any
future introspection) can reach the underlying callable and model. Phase 1
only needs the wrapper itself, but Phase 2 needs both.

Tests (`jac/jaclang/byllm/tests/test_vectorize.jac`, MockLLM at
`jac/jaclang/byllm/llm.impl/mockllm.impl.jac`; reference:
`tests/test_parallel.jac`):

- order preservation with jittered mock latency;
- broadcast of non-vectorized params;
- `on_error="none"` yields `None` slot, `"raise"` propagates;
- scalar call still works after decoration.

## 6. Phase 2 - batch strategy (MTIR/prompt rewrite)

All in byllm; the seam is `MTRuntime.factory`.

1. **Batch MTIR entry.** Reserved call_param, e.g.
   `call_params["_vmap"] = {"frames": list[dict], "n": int}`, set by the
   dispatcher when `strategy="batch"`. Dispatcher builds it via
   `_jac_by_caller` / `_jac_by_model` + `fetch_mtir(caller)`, bypassing the
   scalar wrapper.
2. **Prompt zones** (`mtir.impl.jac`, factory):
   - Header: unchanged scalar signature + authored sem, plus one line:
     `applied independently to each of N inputs; return one result per input,
     in order`.
   - Schema zone: **unchanged** - types/semstrings described once (this is
     the amortization).
   - Bindings zone: indexed call frames instead of one frame:
     `inputs[0]: text = '...'` … `inputs[N-1]: ...`.
3. **Output typing:** `resp_type = list[R]`; `get_output_schema` /
   `get_typed_output_schema` emit array schema with
   `minItems == maxItems == N`.
4. **Validation in `parse_response` (or wrapper around it):**
   `len(result) == N` and element-type checks; on mismatch → one corrective
   retry (append a repair message), then **fallback: rerun that chunk via the
   Phase-1 per-item path**. Semantics never degrade, only cost.
5. **Guards - refuse batch, fall back to parallel loop (log a warning) when:**
   - `call_params` contains `tools` (ReAct per item is undefined in a batch),
   - `conversation=` is set, `stream=True`,
   - any argument is `Media`,
   - rendered batch exceeds a token budget (rough estimate; split chunk).
6. **Chunking:** split items into `batch_size` chunks; dispatch chunks through
   the Phase-1 pool (chunked-batches-in-parallel is the real production
   shape).

Tests: mock returning correct/short/long/reordered arrays → count validation,
repair retry, fallback; guard tests (tools/stream/media force loop path);
golden-prompt test asserting the batched bindings zone and the once-only
schema zone.

## 7. Phase 3 - optional compiler/typing support

- Teach the type evaluator that `vectorize` lifts types instead of erasing
  them: special-case in `_apply_function_decorators`,
  `jac/jaclang/compiler/type_system/type_evaluator.impl/construct_types.impl.jac:398-420`.
  (Known gap: today a decorated function's type becomes the decorator's
  declared return type; bare `Callable`/`Callable[..., T]` breaks call sites.)
- Later, if the sugar earns it: dedicated surface (e.g. `by llm.map(...)`) -
  parser touchpoints are the five decorated-construct rules in
  `jac/jaclang/jac0core/parser/impl/parser.impl.jac` - **explicitly out of
  scope for now**.

## 8. Evaluation (gen-sem angle)

Use byllm telemetry (`jac/jaclang/byllm/telemetry.jac`) to log per-call:
strategy, chunk size, prompt/output tokens, wall time, validation failures.
Run 2–3 tasks (classification, extraction, enum labeling) sweeping
`batch_size ∈ {1, 2, 4, 8, 16, 32}`; plot accuracy vs. b and $/1k items vs.
b. Data picks the default `batch_size` and justifies `strategy="auto"`
heuristics. This is the measurable claim: *equal task accuracy at k× lower
cost under MTP*.

## 9. Risks / open questions

- **Repr fidelity in batched bindings:** frames use `repr(value)` like the
  scalar path; very large items blow the token budget → need the size guard
  before enabling by default.
- **Provider structured-output quirks:** some backends dislike top-level JSON
  arrays; may need `{"results": [...]}` wrapper object in
  `get_typed_output_schema` for the batch path.
- **`fetch_mtir` scope keys:** confirm MTIR info lookup works when invoked
  from the dispatcher rather than the generated wrapper.
- **Async:** `Model.ainvoke` exists (`acall_llm`,
  `runtime.impl.jac:1724-1726`); Phase 1 uses threads for simplicity, async
  dispatcher is a follow-up.
- Naming: `vectorize` vs `vmap` vs `sem_map` - pick before export.

## 10. Milestones

1. `vectorize.jac` + `by`-wrapper attribute stamping + tests (Phase 1). Ship.
2. Batch prompt rendering + list[R] schema + validation/fallback + guards
   (Phase 2, behind `strategy="batch"`). Ship.
3. Telemetry sweep + defaults + `strategy="auto"` (Phase 2.5).
4. Type-evaluator lift for the decorator (Phase 3, separate PR).
