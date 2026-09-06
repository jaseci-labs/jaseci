# The Jac compiler

This directory is the compiler: parsing, analysis, placement, and three code
generators. The pipeline, pass by pass, is documented in
[`cli/docs/internals/compiler_architecture.md`](../cli/docs/internals/compiler_architecture.md);
this file is the map of the tree and the rules that keep it organized.

## Layout

| Directory | Holds | Depends on |
|---|---|---|
| `frontend/` | Lexer, parser, the unified tree (`unitree`), roles and relations, source locations, diagnostics, per-node code info, and the module facts every later layer reads (`module_facts`, `const_fold`, `constant`) | nothing above it |
| `passes/` | Pass infrastructure (`transform`, `uni_pass`, `annex_weave`, `dataflow`) and the analysis passes: symbol tables, declaration matching, semantics, CFG, types, ownership, regions, capabilities, layout | `frontend`, `types` |
| `types/` | The type system and evaluator, compile-time values, the stub catalog, and the ambient `.pyi` surfaces | `frontend` |
| `placement/` | The placement solver: which module runs where, pins, workspaces | `frontend`, `passes` |
| `driver/` | `JacProgram`, `JacCompiler`, the schedules, module resolution, the caches (bytecode, interface, JIR), compile options | everything |
| `backends/common/` | What the generators share: the AST-gen base, the primitive emitter interfaces, the kernel unit lists, the format kernel | `frontend`, `passes` |
| `backends/py/` | Jac to JCIR to CPython bytecode | `backends/common` |
| `backends/es/` | Jac to ESTree to JavaScript, the client framework backends, view IR | `backends/common` |
| `backends/native/` | Jac to LLVM IR, the linkers (ELF, Mach-O, PE, wasm), the wasm runtime, and the in-tree LLVM binding (`llvm/`, a translation of llvmlite, see `llvm/LICENSE.llvmlite`) | `backends/common` |
| `tools/` | Formatter, linter, unparser, normalizer, doc IR, grammar extraction, code intelligence | `frontend`, `passes` |
| `tests/` | Cross-backend equivalence fixtures that ship with the package | |

The loose modules at this level are the native frontend kernel
(`jc_unit`, `jc_materialize`, `native_compiler`, `native_scope`: the parser
compiled natively and loaded as a shared library) and registries shared by
analysis and codegen (`symbol_utils`, `expr_keys`, `type_registry`,
`intrinsic_registry`).

## Rules

**Backends consume facts, they do not compute them.** Types are read from
`Expr.type`, symbols from `.sym`, layouts from the layout registry, and
module structure from `ModuleFacts`. `tests/compiler/test_backend_purity.jac`
scans the backends for analysis APIs and fails on any read that is not
sanctioned there with a reason. If a backend needs a fact, a pass stamps it.

**Shared code lives with the lowest layer that needs it, never in a sibling.**
A helper the passes and two backends all import belongs in `frontend/` or
`backends/common/`, not in the backend that happened to write it first.

**Every generator has the same shape.** One walker declaration
(`jcir_gen_pass.jac`, `esast_gen_pass.jac`, `na_ir_gen_pass.jac`) holds the
state fields and every method signature; the bodies live in
`<name>.impl/<concern>.impl.jac`, one file per concern (expressions,
statements, calls, declarations, module, and so on). There are no mixins and
no redeclared signatures.

**Where bodies go.** A declaration with one body file keeps it in
`impl/<module>.impl.jac`. A declaration with several keeps them in
`<module>.impl/<part>.impl.jac`. Nothing else.

**The bootstrap tier constrains imports.** `jaclang/bootstrap_manifest.py`
lists the modules the seed transpiler (`jac0`) compiles: the frontend, the
driver, placement, the Python backend and the pass bases. A seed module may
import a non-seed module only inside a function body, because a hoisted
import deadlocks bootstrap. That is why many imports in this tree are local
to the function that uses them; `scripts/check_seed_manifest.py` enforces it.

**Type checking.** `jac check .` runs in CI over the whole repository with
the exclusions in the root `.jacignore`. Every entry there is a debt with a
stated reason; the target is an empty file.
