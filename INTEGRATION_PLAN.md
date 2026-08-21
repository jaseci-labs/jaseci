 Unified JacPython Stabilization Plan

 Objective

 Build and verify one product pipeline:

 ```text
   Python source
     → tokenizer
     → complete generated PEG parser
     → validated AST
     → symbol facts
     → CFG-based code generation
     → verified CFG
     → assembled PyCode
     → jacpython VM
 ```

 PyCode is the sole compiler-to-VM seam.

- The compiler must never construct invalid PyCode.
- The VM executes valid PyCode; it does not repair compiler defects.
- Host CPython is permitted only as an independent test oracle.
- No host fallback exists in the product path.

 ────────────────────────────────────────────────────────────────────────────────

 Architectural ownership

### 1. Grammar generation

 grammar2jac.py owns translation from the pinned CPython grammar to generated Jac rules.

 It must:

- parse grammar actions into a typed action IR;
- translate action families structurally;
- use an explicit CPython type registry;
- reject unknown action forms and pointer types;
- emit stable repository-relative provenance;
- generate the complete pinned grammar.

 It must not use:

- an accumulating ordered-regex pipeline;
- absolute paths;
- unknown-type-to-list[object] fallback;
- grammar deny-lists as feature control.

 Unsupported compiler features are reported after parsing, not hidden from the grammar.

### 2. Parser

 The parser owns only:

 ```text
   tokens → AST or parse diagnostic
 ```

 Generated files contain grammar-derived rules. Handwritten parser actions and PEG mechanics remain separate modules.

### 3. AST validation

 Validation owns all language legality independent of scope resolution:

- node fields and locations;
- expression contexts;
- legal store/delete targets;
- return, yield, break, and continue placement;
- duplicate arguments;
- pattern invariants;
- recursion and nesting limits;
- future-feature preprocessing.

 Codegen receives validated AST only.

### 4. Symbol table

 The symbol-table module owns:

- definitions and uses;
- local/global/nonlocal classification;
- parameters and deterministic ordering;
- free and cell variables;
- scope kinds;
- class and comprehension scopes;
- generator/coroutine flags;
- name mangling.

 Codegen does not rediscover scope facts.

### 5. Compiler diagnostics

 Compiler phases use compiler-owned diagnostics:

 ```text
   ParseDiagnostic
   ValidationDiagnostic
   SymbolDiagnostic
   LoweringDiagnostic
   InternalCompilerDiagnostic
 ```

 product_compile.jac converts them to user-visible Python exceptions at the outer seam. Compiler internals do not use runtime PyError or any as
 control flow.

### 6. Opcode metadata

 One version-pinned generated module owns:

- opcode numbers;
- inline-cache counts;
- stack effects, including jump-specific effects;
- branch classification;
- terminator/fallthrough behavior;
- operand interpretation needed by compiler and VM.

 Unknown metadata is an error. It never defaults to zero stack effect.

 Normal and in-place operators use one shared mapping from operator kind to opcode argument.

### 7. CFG code generation

 Codegen emits through a CFG builder that owns:

- current block;
- block creation;
- edges;
- source locations;
- instruction emission;
- continuation and termination state.

 Expression lowering produces a value and continuation. Statement lowering produces either a continuation or termination.

 Visitors must not embed caller behavior. For example, chained comparison lowering must rejoin its continuation and must not emit RETURN_VALUE.

### 8. Flowgraph verification

 Flowgraph transforms:

 ```text
   UnverifiedCFG → VerifiedCFG
 ```

 It performs a worklist analysis over real control-flow edges:

- reachability;
- stack underflow rejection;
- branch-specific stack effects;
- equal stack depth at joins;
- terminator/fallthrough consistency;
- maximum stack depth;
- valid jump targets;
- exception-region consistency.

 Assembly accepts only VerifiedCFG.

### 9. Assembly

 Assembly owns deterministic conversion from verified CFG to PyCode:

- block layout;
- jump relaxation;
- EXTENDED_ARG;
- cache insertion;
- constants and names;
- line table;
- exception table;
- recursive code metadata.

 It does not recover from malformed IR.

### 10. VM

 The VM owns runtime semantics:

 ```text
   PyCode + frame state → value, suspension, or runtime exception
 ```

 It must:

- reject unsupported opcodes loudly;
- implement stack and frame semantics exactly;
- consume shared opcode/cache metadata;
- remain independent of compiler internals.

 Do not add a VM pre-verifier to compensate for compiler defects.

 ────────────────────────────────────────────────────────────────────────────────

 Implementation program

 Phase 1 — Generator integrity

 Replace the fragile generator seams before expanding syntax.

### Work

- Replace ActionLowerer’s ordered regex pipeline with typed action parsing and translation.
- Add an explicit grammar type registry, including AugOperator*.
- Make unknown action and type forms generation errors.
- Remove absolute paths from generated output.
- Generate stable logical provenance such as:
   reference/cpython/Grammar/python.gram.
- Remove parser feature deny-listing.
- Regenerate parser.jac.

### Gate

- Regeneration equals checked-in output.
- Two differently located checkouts produce identical hashes.
- Unknown action/type fixtures fail generation.
- Full pinned grammar is represented.
- Parser output matches CPython ASTs for the accepted corpus.

 ────────────────────────────────────────────────────────────────────────────────

 Phase 2 — Compiler phase contracts

 Introduce explicit interfaces before repairing individual lowering cases.

### Work

- Add compiler-owned diagnostics.
- Add validation as a mandatory stage.
- Define unverified and verified CFG types.
- Remove as any from product_compile.jac.
- Make unsupported AST constructors return typed diagnostics.
- Remove every silent expression, target, and statement return.

### Gate

- Unknown expressions, statements, and targets cannot produce PyCode.
- Module-level return is rejected by validation.
- Unsupported valid syntax reports NotImplementedError.
- Invalid Python reports SyntaxError.
- Compiler invariant failures report SystemError.
- Product compilation has no host fallback.

 ────────────────────────────────────────────────────────────────────────────────

 Phase 3 — Authoritative opcode and CFG model

 Status: foundation landed (Phases 1, 2, 4, 5 first pass on the active branch).
 This is the critical-path gate before band 3: the current `verify_stackdepth`
 is a linear scan that returns stack-effect `0` for unknown opcodes and clamps
 negative depth — correct for straight-line code, silently wrong once loops and
 branches create join points.

 Principle: generate the data, port the algorithm. Opcode metadata is data
 (machine-readable in CPython), so it is generated like tokens/AST/parser.
 `calculate_stackdepth` is an algorithm with no data form, so it is hand-ported.
 A before B.

### Work

 A — Generate `opcode_meta.jac` (the 4th generator, `tools/opcode_meta2jac.py`):

- Same mold as `tokens2jac.py` / `asdl2jac.py` / `grammar2jac.py`: vendored
   `reference/cpython` input, checked-in Jac output with provenance header,
   `--check` drift guard, `test_opcode_meta2jac.py` reproducibility test.
- Read `Include/opcode_ids.h`; `Include/internal/pycore_opcode_metadata.h`
   (`_PyOpcode_Caches`, `_PyOpcode_Deopt`, and the `_PyOpcode_num_popped` /
   `_PyOpcode_num_pushed` switches); `Include/internal/pycore_opcode_utils.h`
   (`MAX_REAL_OPCODE`, `IS_BLOCK_PUSH_OPCODE`, `HAS_TARGET`);
   `Include/cpython/code.h` (`CO_*`); operator ids from `Include/opcode.h` (`NB_*`).
- Emit opcode id constants, cache counts, deopt map, an exhaustive
   `stack_effect(op, oparg, jump)` over all opcodes (not just currently-emitted
   ones — STORE_ATTR, STORE_SUBSCR, deletes, calls, conditional jumps, COPY, SWAP
   are covered by construction), flags, and jump/terminator classifiers.
   Centralize the operator-to-arg mapping here.
- Delete the hand-copied body of `opcode_meta.jac`. The switches port 1:1 (each
   case is `return <const or simple oparg expr>`), strictly simpler than the
   C-action translation `action_translate.py` already ships.

 B — Port `Python/flowgraph.c::calculate_stackdepth` into `flowgraph.jac`:

- Per-block `startdepth`, edges derived from terminators (`HAS_TARGET` → taken
   effect; fallthrough unless unconditional jump or scope exit).
- Consume the generated `stack_effect`. Plug into the existing `verified_cfg.diag`
   seam (already wired through `product_compile`) — no new error contract.
- Make underflow and inconsistent joins hard `diag` errors.

### Gate

 Reuse the existing positive oracle: `pycode_diff.jac` diffs `stacksize` against
 CPython-produced `PyCode` (asserted in layer8/layer9). The worklist must keep
 those green.

 Hand-built negative CFG fixtures must reject:

- immediate underflow;
- branch-only underflow;
- inconsistent join depth;
- invalid jump target;
- fallthrough after a terminator;
- missing/unknown opcode metadata (now impossible to emit silently — the
   generated table is exhaustive).

 Positive fixtures must match CPython stacksize.

 ────────────────────────────────────────────────────────────────────────────────

 Phase 4 — CFG-builder codegen

 Status: complete (Aug 16 2026). CFG builder owns block emission; stmt_cont
 carries continuation/termination; chained compare/assign lowering uses shared
 compare_oparg from opcode_meta; gate fixtures green in layer9 + compiler_slice.

### Work

- Replace arbitrary supplied-block mutation with a CFG builder.
- Make continuation and termination explicit.
- Rework chained comparisons to compose in nested expressions.
- Use the shared operator mapping.
- Correct chained assignment:
  - evaluate the RHS once;
  - preserve it with COPY;
  - store targets in Python order.
- Implement store/delete target lowering through cohesive target helpers.
- Keep unsupported AugAssign target forms diagnostic until fully implemented.

### Gate

 Bytecode and execution fixtures must cover:

 ```python
   x = y = side_effect()
   obj.x = seq[index()] = value()
   f(x < y < z)
   a = x < y < z
   (x < y < z) and q
 ```

 Assert evaluation count, evaluation order, bytecode parity, stack size, namespace state, and runtime result.

 ────────────────────────────────────────────────────────────────────────────────

 Phase 5 — Semantic front end

### Work

 Complete AST validation and implement the symbol table before functions and closures.

### Gate

 Compare normalized results with CPython for:

- valid and invalid placement;
- assignment contexts;
- global/nonlocal rules;
- module/function/class/comprehension scopes;
- local/global/free/cell classification;
- deterministic variable ordering;
- generator/coroutine flags;
- name mangling.

 ────────────────────────────────────────────────────────────────────────────────

 Phase 6 — Independent VM conformance

 Status: landed on the active branch (band-2 emission set).

 The VM is verified independently using CPython-produced PyCode.

### Work

 Create one VM fixture for every opcode before native codegen begins emitting it.

 Compare:

- values;
- namespace mutations;
- exception types and messages;
- calls and returns;
- closures and cells;
- branches and loops;
- exception handlers;
- generator suspension and resumption.

 If this reveals a VM defect, fix it on a separate VM-focused branch, as required by repository policy.

 Deliverables:

- `jac-py/tools/vm_opcode_fixtures.py` — fixture registry and coverage gate synced
   with `compiler_codegen.jac` emission opcodes and `layer_vm_conformance.jac` markers.
- `jac-py/jacpython/layer_vm_conformance.jac` — proof leg B harness (host compile,
   jacpython VM execute, host oracle compare).
- `jac-py/tools/test_vm_opcode_fixtures.py` — gate unit tests.
- CI: opcode coverage gate, gate tests, and `layer_vm_conformance.jac` in
   `jac-py-gates`.

### Gate

- `vm_opcode_fixtures.py --check` passes under pinned CPython 3.14.6.
- Every band-2 emission opcode has a `# vm-opcode:` (or `# vm-opcode-compiler:`)
   fixture in `layer_vm_conformance.jac` whose sources match the registry.
- Semantic category fixtures (exceptions, calls, closures, control flow, generators)
   pass on jacpython's VM against host CPython.

 ────────────────────────────────────────────────────────────────────────────────

 Phase 7 — End-to-end language bands

 Only after Phases 1–6:

 1. Band 2 straight-line statements.
 2. Band 3 branches, loops, and comprehensions.
 3. Functions, lambdas, closures, and recursion.
 4. Classes, decorators, imports, and mangling.
 5. Exceptions, with, assertions, and exception tables.
 6. Generators, coroutines, and async.
 7. Pattern matching, type parameters, and remaining Python 3.14 forms.

 Each band must pass all three proof legs before the next begins.

 ────────────────────────────────────────────────────────────────────────────────

 Verification strategy

 Proof leg A — Compiler verification

 Compare jacpython compiler output with CPython 3.14.6:

- AST;
- validation result;
- symbol facts;
- recursive PyCode;
- bytecode and caches;
- constants and nested code;
- names and variable order;
- flags and localsplus;
- stack size;
- line and exception tables.

 This tests the compiler without trusting jacpython’s VM.

 Proof leg B — VM verification

 Run CPython-produced PyCode on jacpython’s VM and compare runtime behavior with CPython.

 This tests the VM without trusting jacpython’s compiler.

 Proof leg C — Product verification

 Run:

 ```text
   source → native jacpython compiler → PyCode → jacpython VM
 ```

 Compare final behavior with CPython.

 Run this leg with host compile, ast.parse, tokenize, and marshal compilation transport poisoned. Any accidental host use must fail immediately.

 Ratcheted CI

 Track each fixture by stage:

 ```text
   tokenize
   parse
   validate
   symbols
   lower
   flowgraph
   assemble
   VM
   end-to-end
 ```

 A fixture may only move from unsupported/failing to passing. Regressions identify the responsible module.

 ────────────────────────────────────────────────────────────────────────────────

 Immediate next steps

 Step 1: Freeze feature expansion

 Do not begin band 3. Do not add more regex action patches, deny-list exceptions, opcode fallbacks, or VM guards.

 Step 2: Update PLAN.md

 Replace the current “A then B, C later” recommendation with this unified program. Record:

- PyCode as the sole compiler–VM seam;
- mandatory validation and symbol stages;
- UnverifiedCFG → VerifiedCFG;
- three-leg verification;
- removal of parser deny-listing and regex action lowering.

 Step 3: Make the current branch safe

 Do not merge the current band-2 claim as complete. Preserve useful parser and fixture work, but require:

- deterministic generated output;
- no any boundary cast;
- no silent codegen paths;
- real chained-assignment coverage;
- no module-level return compilation;
- no stack-underflow masking.

 Do not patch these with local conditionals if they depend on the missing validation or CFG interfaces; move them onto the appropriate foundation
 branch.

 Step 4: First implementation branch

 Start with generator integrity:

- structured action translation;
- explicit type registry;
- stable provenance;
- reproducibility tests.

 This removes the highest upstream source of repeated parser defects.

 Step 5: Second implementation branch

 Implement compiler diagnostics and validation contracts:

- compiler-owned diagnostics;
- mandatory validation;
- fail-loud unsupported cases;
- typed product boundary.

 Step 6: Third implementation branch

 Implement generated opcode metadata and verified CFG:

- authoritative stack effects;
- worklist stack analysis;
- typed verified CFG;
- assembler restriction.

 Step 7: Fourth implementation branch

 Refactor codegen onto the CFG builder, then correctly finish band 2.

 Band 3 entry criteria

 Band 3 begins only when:

- generation is reproducible;
- the full parser does not use readiness deny-lists;
- unsupported syntax fails explicitly after parsing;
- validation rejects illegal placement and targets;
- flowgraph rejects underflow and invalid joins;
- assembly accepts only verified CFG;
- chained assignment and nested comparison fixtures pass;
- all emitted opcodes pass independent VM tests;
- compiler, VM, and end-to-end proof legs are green.
