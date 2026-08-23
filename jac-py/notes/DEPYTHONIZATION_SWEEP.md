# De-Pythonization Sweep -- `::py::` Block Removal (2026-08-22, agent QuickViper)

Sweep converting embedded `::py::` blocks in `jac-py/jacpython/*.jac` to native
Jac. Motivation: the branch's goal is a pure-Jac implementation; `::py::` escape
hatches bypass the static checker and hide semantics.

## Outcome

**8 of 10 blocks flattened across 7 files.** One surgical commit per file:

| File | Block content | Commit |
|---|---|---|
| `compiler_validate.jac` | host-compile SyntaxError oracle (`_host_compile_syntax_error`) | `37d12e2c1` |
| `layer2_unittest.jac` | host-equality helper (`_l2_host_equal`) | (same wave) |
| `layer_p2_libtest.jac` | snippet wrapper + platform shims (`_p2_wrap_snippet`, `_p2_libtest_host_*`) | (same wave) |
| `layer_vm_conformance.jac` | vm-host exec/eval/raises oracles (`_vm_host_*`) | (same wave) |
| `host_oracle.jac` | subprocess bridge discovery + `_tokenize` driver | (same wave) |
| `compiler_symtable.jac` | symtable oracle + json-equal comparator (`_host_sym_normalize`, `_sym_oracle_equal`) | (same wave) |
| `layer0_replay_harness.jac` | **580-line** layer-0/1 harvest/replay block | `10f790ea5` |

## Deliberately skipped (2 blocks remain)

| File | Why skipped |
|---|---|
| `ceval.jac` (439-line host bridge) | Hot file at sweep time: item-40/43 lanes mid-flight plus queued follow-ups. Revisit after the chain drains. |
| `objects.jac` (`_py_container_del`) | Was a load-bearing workaround for the compiled-jac `del container[key]` anchor-leak bug; removed after the sv_forget root fix landed (the ::py:: block no longer exists). |

Also excluded by lane ownership: `parser_actions.jac`, `compiler_literals_slice.jac`
(band-11 lit-fix agent active) and HappyZenith's throwaway `_smoke_tmp.jac` /
`_corpus_gate_tmp.jac` temp drivers.

## Conversion patterns that worked

These are the idioms to reuse on any future python→jac conversion in this tree:

1. **Route dynamic values through `getattr()`.** The Jac static checker narrows
   types through `isinstance(x, ast.SomeNode)` into opaque host class objects;
   direct attribute access then errors (E1030/E1031/E1032). `getattr(x, "attr")`
   returns `any` and keeps runtime behavior identical.
2. **Coerce at boundaries.** Wrap dynamic strings with `str()` before `+`
   concatenation and `int()` before int-typed params; annotate local containers
   explicitly (`parts: list[str] = []`) so `join`/`extend` typecheck.
3. **Lazy `and`-chains must become sequential early-return guards.** This is the
   #1 conversion hazard. Python evaluates `isinstance(a, X) and a.attr` lazily;
   native Jac code that hoists `getattr(a, "attr")` eagerly crashes on shapes
   where the guard would have short-circuited. Real crash shapes hit during this
   sweep:
   - non-`Expr` statements (nested `class` def inside a test body)
   - `Expr` whose `.value` is not a `Call` (bare listcomp statement:
     `[x for x in range(2)]`)
   - assert receivers that are not `Name` (`mod.Class.assertX(...)`)
   - `with` items whose `context_expr` is not a `Call`
   Rule of thumb: every `isinstance` test that guards an attribute access in the
   original becomes an explicit `if not isinstance(...): return False;` BEFORE
   the access.
4. **Jac syntax traps:** module-level assignment needs `glob`; `root`, `node`,
   `entry`, `visit` are reserved words; lambda is brace-bodied with typed params
   (`lambda (x: any) { return str(x); }`); Python keyword kwargs need backtick
   escapes (`` json.dumps(..., `default=...) ``); `Path(a) / b` → use the
   `Path(a, b)` constructor form.
5. **Verify against baseline, not vibes.** For each file: `.venv/bin/jac check`
   diffed against a probe run of the HEAD version (pre-existing errors are
   common), plus targeted `jac run` smoke drivers exercising real behavior.
   For the harness, harvest outputs were byte-matched legacy + fixture mode.

## Parity evidence for `10f790ea5`

The p3 ratchet gate currently reports `test_set passed=7 baseline=5`. This is
**pre-existing drift**: verified identical on a clean detached-HEAD worktree.
Cause: item-58's atomic guest-side identity evaluation legitimately passes more
asserts than the old ratchet baseline. Action owed (not part of this sweep):
the item-58 owner should bump the `p3_object_core` manifest baselines.

## Process notes (multi-agent shared tree)

The sweep ran alongside 7 other agents in one checkout. What kept it clean:
reserve files via pi_messenger before editing; never touch another lane's
reserved files (`ceval.jac`, `objects.jac` were hot all night); commit within
minutes of verification, staging only owned paths; when two lanes collided on
`layer0_replay_harness.jac`, resolve via snapshot → surgical rebase of each
side's delta → restore combined state → independent verification (the plan
YoungHawk proposed and both sides executed).
