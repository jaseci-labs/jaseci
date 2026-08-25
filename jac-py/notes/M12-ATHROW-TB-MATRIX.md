# M12 athrow/async-for tb-chain matrix -- PROBE-MATRIX lane (2026-08-08)

Builds on M9-TB-TRAVERSAL-FINDINGS.md (sync generator throw-in tb chains are
host-exact). This slice probes the ASYNC counterparts nobody had covered:
athrow into/escaping async gens, async-for raises, StopAsyncIteration paths,
and delegation-style throw forwarding. Branch `conv/selfhost-six`, tip
`7f743e089` (plus concurrent in-flight edits from other lanes; probes run on
whatever the tree compiles at run time).

## Method

- Scenario scripts are pure-protocol Python (no asyncio): coroutines and
  agens are driven with manual `send(None)` through one `_run()` await, so
  the identical file runs on host python3 and on guest ceval.
- Guest side compiles each script with the HOST oracle
  (`host_compile_marshal`) and executes it via `exec_code`. Consequence for
  triage: **every divergence below is runtime-class by construction** -- no
  guest compiler is in the loop, so "byte-parity" is not an available
  explanation.
- tb chains are walked as `(tb_frame.f_code.co_name, tb_lineno)` pairs.

Repro (one jac process at a time):

```
cd jac-py/jacpython
timeout 20 python3 probes_m12/scenario_X.py          # host truth
timeout 240 jac run probes_m12/probe_X.jac           # guest half
```

(`jac run` resolves sibling modules only from cwd + entry-file dir, so the
wrappers must be launched from `jac-py/jacpython/`.)

## Matrix

| # | Scenario | Host output (chain) | Guest output | Match |
|---|----------|--------------------|--------------|-------|
| A | `athrow(ValueError)` caught INSIDE agen; gen resumes after except | inner walk = single frame `agen@32`; then yields 99, exhausts | identical | YES |
| B | `athrow` ESCAPES agen to caller (finally runs) | `module@40\|drive@24\|_run@17\|agen@32`; then StopAsyncIteration | identical | YES |
| C | async-for over agen raising mid-iteration | `main@37\|agen@31` | `main@37\|`**`main@37`**`\|agen@31` (awaiting frame DUPLICATED) | NO |
| D1 | exhausted `asend` -> StopAsyncIteration into awaiting caller | `module\|drive\|_run`, repr `StopAsyncIteration()` | identical | YES |
| D2 | StopAsyncIteration raised inside agen BODY | converts to `RuntimeError: async generator raised StopAsyncIteration`, chain `module\|drive\|_run` | identical incl. message + chain | YES |
| E | delegation: outer re-throws arriving exc into sub via `athrow(e)`; one throw crosses main->outer->sub->outer->main | value `('outer-yield', 1)`; all three walks exact (`E-main`: `module@55\|drive@25\|_run@18\|outer@49\|sub@33\|outer@45`) | tb chains byte-identical; but first item is `('outer-yield',`**`None`**`)` | NO |
| F | deep chain names+linenos reference shape (raise under two awaits out of an agen) | `module@45\|drive@24\|_run@17\|agen@39\|mid@35\|leaf@31` | identical | YES |

Score: **5/7 scenarios host-exact** (A, B, D1+D2, F). Two divergent, both
RUNTIME-WRONG.

## Findings

### F1 (worst): builtin `anext()` loses the yielded item -- RUNTIME-WRONG

Minimal repro (`scenario_e_delegation_throw.py` distilled):

```python
async def g():
    yield 7
async def m():
    print(await anext(g()))   # host: 7   guest: None
def drive(aw):
    async def _r(): return await aw
    try: _r().send(None)
    except StopIteration as e: return e.value
drive(m())
```

Isolation data:

- `await gen.__anext__()` and `async for` unwrap items correctly (both give
  the value), so `PyAsyncGenASend` + the SEND loop are fine.
- Guest `anext` resolves to the HOST-bridged builtin: `anext(g())` returns an
  object of type `_JacGuestANext`, i.e. the agen crossed to its host face
  (`_jac_make_guest_async_generator`, ceval.jac ~1119).
- Manually driving that face's `__await__()` generator ends with
  `StopIteration.value == None` -- the item is lost inside the bridge face /
  `_drive_anext` itself ("item" outcome never reaches the awaiter as a
  return), NOT in the guest SEND loop.
- Second symptom, same root: `anext(user_obj_with___anext__)` raises
  `TypeError: 'AI' object is not an async iterator` on guest while host
  returns 42 -- generic user objects crossing to host lose `am_anext`
  dispatch, and there is no native guest `anext` to catch them
  (`py_anext` exists at ceval.jac ~6888 but nothing registers it as the
  builtin).

Long-term fix direction: register a native `anext` (and check `aiter`) over
PyObj in the builtins table instead of letting these resolve to host bridges;
the existing `py_anext` is most of the way there. Scenario E's tb chains are
already perfect, so fixing the value path completes E.

### F2: async-for raise duplicates the awaiting frame in the tb chain

Scenario C: when an agen raises during `async for`, the guest prepends the
awaiting frame (`main`) twice at the same line before the agen frame. The
sync counterpart (plain `for` over a raising generator) is host-exact
(`module|sgen`, verified both sides), so the duplication is specific to the
async-for propagation path -- likely recover_exception/tb-prepend firing once
at the GET_AWAITABLE resume point and once more while unwinding out of
`main`. Classification RUNTIME-WRONG (tb construction), not compiler parity:
all probes execute host-compiled bytecode.

## Deliverables in jac-py/jacpython/probes_m12/

- `scenario_{a,b,c,d,e,f}_*.py` -- self-contained scenario sources (host +
  guest identical bytes).
- `probe_{a..f}.jac` -- exec_code wrappers (read the scenario file via the
  ::py:: block; launch from `jac-py/jacpython/`).
- `smoke.jac` -- embedded mini-scenario sanity probe.

No product files touched; nothing committed.
