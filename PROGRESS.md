JacPython is a strong prototype, not yet a usable Python implementation.

Most importantly, there are two separate maturity levels:

1. The VM/runtime is broad and can execute roughly 100 CPython 3.14
   opcodes.
2. The native JacPython compiler has moved well past Band 3 on local
   `jac-python`: Bands 4–6 are committed; Band 7 (generators + full async,
   incl. async generators and async comprehensions) committed; Band 8
   (pattern matching) committed except star sequence patterns and
   match-or captures; Band 9 (sequence unpacking + tuple/list/set/dict/
   starred displays) committed.

These are often conflated in the plans and progress claims.

Repository status (Aug 19 2026)

- upstream/main contains no jac-py/ files.
- All JacPython work is in open PR #6973 (`feat(jac-py): band-3 control
  flow with parser and codegen fixes` — title is stale).
- PR state: OPEN; GitHub `mergeable`: UNKNOWN; pre-commit.ci: ERROR.
- Local branch `jac-python` is **39 commits ahead** of `origin/jac-python`
  (Bands 7/8/9 slices + P1 c2jac corpus — see `git log origin/jac-python..jac-python`).
- Working tree: **dirty** — P2 wave 1 implemented locally but **not committed**:
  ~40 untracked files under `jac-py/Modules/`, `jac-py/tests/`, `jac-py/tools/`,
  `jac-py/PORTING_PLAYBOOK.md`; modified `.github/workflows/ci.yml`,
  `jac/tests/compiler/c2jac/lift_oracle.jac`, P1 stub headers.
- Planning docs (untracked): `INTEGRATION_PLAN.md`, `PR_SPLIT_PLAN.md`, `TODO.md`,
  `PROGRESS.md`, `jac-py/BAND4_SLICE_LEARNINGS.md`.
- Slice learnings: `jac-py/BAND4_SLICE_LEARNINGS.md`, `BAND5_SLICE_LEARNINGS.md`,
  `BAND6_SLICE_LEARNINGS.md`.

Therefore, none of JacPython should currently be considered landed
production functionality.

What is really implemented

### Native compiler pipeline

A real, host-free product path exists:

```text
  Python source
  → tokenizer
  → generated PEG parser
  → typed AST
  → validation
  → symbol table
  → CFG code generation
  → stack/control-flow verification
  → assembler
  → PyCode
  → JacPython VM
```

Entry point: `jac-py/jacpython/product_compile.jac`.

Implemented infrastructure includes:

- CPython 3.14.6-pinned token, ASDL, grammar, and opcode generators
- Generated PEG parser
- Compiler diagnostics
- Validation and symbol-table modules
- CFG builder and worklist stack verifier
- Bytecode assembler with line and exception-table infrastructure
- Differential tests against CPython-produced PyCode
- Independent VM opcode fixture framework

### Committed native language surface

| Band | Scope | Status |
|------|-------|--------|
| **3** | eval/exec modes; constants; binops; comparisons; calls; attr/subscript; assignments; if/while/for/break/continue; comprehensions | Committed (`38ceb1607` and earlier) |
| **4** | Thin functions → recursion → lambdas → closures → defaults → `*args`/`**kwargs`/kw-only → decorators → keyword calls / `CALL_KW` | Committed (8 logical slices) |
| **5** | Imports, classes, name mangling, inheritance | Committed (`ff4014135`) |
| **6** | try/except (typed), raise, except-as, try/finally, with, assert | Committed (6 commits; deferrals below) |
| **7** | `yield`, `yield from`, `async def`, `await`, `async for`, `async with` | Committed |
| **7** | async generators (`CO_ASYNC_GENERATOR`), async list/set/dict comprehensions | Committed (`b3447aa35`, `5f58e2b3a`, `23c524cdc`) |
| **8** | `match`: literal/singleton/capture/wildcard/guard/sequence/mapping/class/match-or | Committed (`a2267d3a5`, `ba47416d9`); star-seq + or-captures open |
| **9** | sequence unpacking (`UNPACK_SEQUENCE`/`UNPACK_EX`); tuple/list/set/dict/starred displays; dict-merge | Committed (`acecb3b98`, `d02180321`) |

Band 4 gate summary is in `TODO.md`. Band 5/6 invariants and deferrals are in
the slice learnings docs.

Band 6 deferrals (still `NotImplementedError` in codegen):

- bare `except`, `try/else`, combined `try/except/finally`, `try` without handler
- `raise ... from cause`
- `with` without `as`, multiple `with` items
- delete cell/free in except-as cleanup

### VM/runtime surface

`jac-py/jacpython/pyc_first.jac` and `objects.jac` contain substantial
runtime work:

- Integers, floats, strings, bytes, lists, tuples, dicts, sets, slices
- User classes, MRO, descriptors, metaclasses
- Functions and bound methods
- Exceptions
- Generator frames, send, throw, close, and yield from
- Coroutine machinery (including async-for opcodes on dirty tree)
- Imports and a small native module importer
- Calls, closures, jumps, comprehensions, exception opcodes, and f-strings

Much of this broad functionality is proven using:

```text
  host CPython compile → marshal → JacPython VM
```

It also still uses host proxies and fallbacks for unported behavior and
modules. That validates the VM; it does not mean the native compiler can
compile those features or that JacPython is self-contained.

### c2jac module porting (P1 / P2 — separate from compiler bands)

Track progress in `TODO.md`. Spec: `jac-py/PLAN.md` §7; playbook:
`jac-py/PORTING_PLAYBOOK.md`.

| Phase | Status | Notes |
|-------|--------|-------|
| **P1** c2jac proving loop | **Committed** (`988e0b6b5`) | Six-module corpus in `_lifted/p1_corpus_slice1b/`; baseline `tier_b_total = 4`; CI gates committed |
| **P2 wave 1** leaf modules | **Implemented locally; pending commit** | Ten staged `jac-py/Modules/*.{c,jac}`; P2 corpus in `_lifted/p2_corpus_wave1/`; oracles, libtest, T8, conformance harness green locally |

**Dual pipeline (P2):** differential oracles read **staged** `jac-py/Modules/{stem}.jac`
(hand edits + PyObj stubs allowed). Corpus lift / T8 / density ratchet read
**lifted** `jac-py/Modules/_lifted/p2_corpus_wave1/{stem}.jac`. Policy:
`jac-py/tools/p2_staged_manifest.json`; drift gate: `test_p2_staged_sync.jac`.

**Known P2 gaps:**

- Wave 1 files are untracked until the next commit; CI wiring exists only in a local `ci.yml` diff.
- Libtest snippets (`test_p2_libtest_partial.jac`) run on **host CPython** only — not JacPython-imported ports.
- Four Tier-B sites remain in the P2 baseline; T8 burn-down is the next proving-loop step.
- Hand-staged oracles (`getbuildinfo`, `_bisectmodule`, `_heapqmodule`, `mysnprintf`) still diverge from fresh c2jac lift until idiom pack catches up.

Current Band 7 status (all committed)

| Slice | Topic | Status |
|-------|-------|--------|
| 1 | `def g(): yield value` | Committed |
| 2 | `yield from` | Committed |
| 3 | `async def` | Committed |
| 4 | `await expr` | Committed |
| 5 | `async for` | Committed |
| 6 | `async with` | Committed |
| 7 | async generators (`CO_ASYNC_GENERATOR`, `CALL_INTRINSIC_1 ASYNC_GEN_WRAP`) | Committed (`b3447aa35`) |
| 8 | async list comprehension (`GET_AITER`/`GET_ANEXT`/`SEND`/`END_ASYNC_FOR`) | Committed (`5f58e2b3a`) |
| 9 | async set/dict comprehensions | Committed (`23c524cdc`) |

Current Band 8 status (pattern matching)

| Slice | Topic | Status |
|-------|-------|--------|
| 1 | `match` literal / wildcard / capture / singleton | Committed |
| 2 | `match` case guards | Committed |
| 3 | `MATCH_SEQUENCE` fixed-length (`case [a, b]:`) | Committed |
| 4 | `MATCH_MAPPING` (`{"k": v}`, `**rest`) | Committed (`a2267d3a5`) |
| 5 | `MATCH_CLASS` (positional + keyword) | Committed (`a2267d3a5`) |
| 6 | match-or value patterns (`case 1 \| 2:`) | Committed (`ba47416d9`) |
| 7 | star sequence patterns (`[a, *rest]`, `[*rest]`) | **Open** (only codegen blocker; symtable done) |
| 8 | match-or with captures | **Open** (`codegen_fail` at codegen ~5427) |

Current Band 9 status (unpacking + displays — all committed)

| Slice | Topic | Status |
|-------|-------|--------|
| 1 | sequence unpacking (`UNPACK_SEQUENCE`, `UNPACK_EX`, nested, mid-star) | Committed |
| 2 | tuple/list displays (const, non-const, empty, singleton) | Committed |
| 3 | set/dict/starred displays (`BUILD_SET`, `BUILD_MAP`, `LIST_EXTEND`, `SET_UPDATE`) | Committed (`acecb3b98`) |
| 4 | dict-merge display (`{**a, 'k': v}` → `DICT_UPDATE`) | Committed (`d02180321`) |

Local Jac test gates

Host oracle requires pinned CPython **3.14.6** via `JACPYTHON_CPYTHON`.
The pinned oracle is `/home/jac/.local/bin/python3.14` (reports 3.14.6);
set `export JACPYTHON_CPYTHON=/home/jac/.local/bin/python3.14` before any
gate. Run `vm_opcode_fixtures.py --check` with that interpreter as the
script runner.

Gate counts below are from the last full run and have grown with the
Band 7/8/9 slices; re-run to refresh exact numbers:

| Gate | Result (last full run) |
|------|------|
| `compiler_slice.jac` | green (async gen + comprehensions added) |
| `layer_unpack.jac` | green (111 tests; Band-9 displays) |
| `layer9_product_exec.jac` | green |
| `layer_vm_conformance.jac` | green |
| `layer10_product_controlflow.jac` | green |
| `compiler_symtable.jac` | green |

Generator / tool gates:

| Tool | Result |
|------|--------|
| `vm_opcode_fixtures.py --check` | PASS |
| `grammar2jac.py --check` | PASS — `parser.jac` up to date |

Current concrete blockers

1. **P2 wave 1 uncommitted** — full gate suite passes locally but ~40 files +
   `ci.yml` / `lift_oracle.jac` diffs are not on the branch yet.
2. **PR #6973 integration** — large historical branch; pre-commit.ci ERROR;
   needs rebase/split strategy — see `PR_SPLIT_PLAN.md`.
3. **CI runtime** — full product test runs can hit multi-minute audit
   timeouts.
4. **Validation / symtable breadth** — interfaces exist; full Python semantic
   coverage remains partial.

Resolved since Aug 16 stabilization

- Band 4 function band closed (all eight slices committed).
- Band 5 classes/imports/mangling closed (`ff4014135`).
- Band 6 exception/with/assert core slices committed.
- Band 7 fully committed: yield / yield-from / async-def / await / async-for /
  async-with / async generators / async list-set-dict comprehensions.
- Band 8 pattern matching committed through match-or value patterns
  (`a2267d3a5`, `ba47416d9`); only star-sequence and or-captures remain.
- Band 9 unpacking + displays committed (`acecb3b98`, `d02180321`).
- String literal tokenizer and assert-message parsing (`fbf0e899b`).
- Parser `ExceptHandler` import gap and `grammar2jac.py --check` drift.

What should happen next

### 1. Finish Band 8 pattern matching

Two codegen-only gaps remain (parser + symtable already done):

1. **Star sequence patterns** (`[a, *rest]`, `[*rest]`, `[a, *mid, b]`) —
   only blocker is `codegen_fail` in `emit_match_pattern_sequence`
   (compiler_codegen.jac ~5176). Lowering: `MATCH_SEQUENCE`, length `>=`
   check when fixed count > 0, `UNPACK_EX (n_before | n_after<<8)`.
2. **Match-or with captures** — `codegen_fail` at ~5427; value/guard match-or
   already works.

Then rebase and resolve PR #6973 conflicts; refresh split plan. Keep existing
JacPython CI gates within predictable time budgets.

### 2. Continue native compiler bands

In order:

1. Finish Band 8 (star sequences, or-captures — above)
2. Close Band 6 deferrals: bare `except`, `try/else`, combined
   `try/except/finally`, `raise ... from`, multi-item / no-`as` `with`,
   cell/free delete in except-as cleanup
3. PEP 695 type parameters (greenfield: parser done, symtable + codegen
   absent — `def f[T]()`, `class C[T]`, `type X = ...`)
4. Remaining Python 3.14 forms

Each band passes compiler-vs-CPython PyCode comparison, CPython-bytecode-on-
JacPython-VM comparison, and full native source-to-JacPython execution.

### 4. Become self-contained

After compiler breadth: remove host fallbacks, port builtin surfaces,
expand native importer, ratchet CPython conformance corpus, na-clean gate,
standalone native JacPython binary.

Honest milestone assessment

┌───────────────────────────────────┬──────────────────────────────────┐
│ Milestone                         │ Status                           │
├───────────────────────────────────┼──────────────────────────────────┤
│ Native source pipeline            │ Implemented                      │
│ architecture                      │                                  │
├───────────────────────────────────┼──────────────────────────────────┤
│ Native expressions and            │ Implemented (committed)          │
│ straight-line modules             │                                  │
├───────────────────────────────────┼──────────────────────────────────┤
│ Native branches, loops,           │ Implemented (committed)          │
│ comprehensions                    │                                  │
├───────────────────────────────────┼──────────────────────────────────┤
│ Native functions                  │ Implemented (committed, Band 4)  │
├───────────────────────────────────┼──────────────────────────────────┤
│ Native classes and imports        │ Implemented (committed, Band 5)  │
├───────────────────────────────────┼──────────────────────────────────┤
│ Native exceptions, with, assert   │ Core slices committed (Band 6);  │
│                                   │ hardening on dirty tree          │
├───────────────────────────────────┼──────────────────────────────────┤
│ Native generators and async       │ Implemented (committed) —        │
│                                   │ yield/await/async-for/async-with │
│                                   │ /async-gen/async-comprehensions  │
├───────────────────────────────────┼──────────────────────────────────┤
│ Native pattern matching           │ Committed except star-seq +      │
│                                   │ or-captures (literal/guard/seq/  │
│                                   │ mapping/class/match-or)          │
├───────────────────────────────────┼──────────────────────────────────┤
│ General Python compilation        │ Not implemented                  │
├───────────────────────────────────┼──────────────────────────────────┤
│ Broad VM execution                │ Substantially implemented,       │
│                                   │ partly host-assisted             │
├───────────────────────────────────┼──────────────────────────────────┤
│ CPython conformance               │ Early subset only                │
├───────────────────────────────────┼──────────────────────────────────┤
│ Self-contained standard library   │ Not implemented                  │
├───────────────────────────────────┼──────────────────────────────────┤
│ Standalone native JacPython       │ Not implemented                  │
├───────────────────────────────────┼──────────────────────────────────┤
│ Production-ready interpreter      │ Not close yet                    │
└───────────────────────────────────┴──────────────────────────────────┘

Track progress on two independent axes: compiler coverage and VM/runtime
coverage. A single “JacPython percent complete” number is misleading.
