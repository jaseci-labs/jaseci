# Band-12 Frontier Report: typed-Python shapes that still fail or diverge

Reconnaissance scan at jac-python `e573b6b21` (run in an isolated worktree at HEAD;
the shared tree was mid-edit by other lanes). Method: 53-shape differential sweep
(native `parse_file -> symtable -> compile_exec -> verify_cfg -> assemble` vs host
oracle marshal, byte-comparing co_code / names / linetable / exceptiontable /
stacksize / consts recursively incl. nested code objects), a 30-shape narrowing
sweep, and 9 runtime exec probes through the product path. All temp probes deleted.

Headline: **5/53 full shapes PASS byte-exact**; but ~35 of the diverging shapes are
exact in `co_code` and diverge ONLY in the nested-scope linetable: one assembler
root cause masks an otherwise-green compiler.

## Ranked gap table

| # | Shape family | Status | Owning module (suspect) | Effort |
|---|--------------|--------|--------------------------|--------|
| 1 | f-strings (basic, format spec, nested quotes, `=debug`) | DIVERGE co_code+linetable+stacksize(+names); runtime emits literal text (`f'plain {n}'` -> `'plain {n}'`, no interpolation) | compiler_codegen JoinedStr lowering + ceval FORMAT_VALUE/BUILD_STRING | L |
| 2 | Linetable inside EVERY nested def/class scope (~30 shapes: decorators, async, yield, closures, comprehensions-in-fn, del forms, assert, augassign-subscript, nonlocal, annassign, class bodies) | co_code EXACT, linetable diverges | assembler.jac location-table writer (known band-11 gap, now shown near-universal) | M |
| 3 | try/finally with `return` in body (fn scope) | CRASH "list index out of range" during codegen | flowgraph/compiler_exc finally duplication | M |
| 4 | try/finally at module scope | CRASH "NoneType has no len()" post-assemble | same family | M |
| 5 | break/continue inside try (loop) | CRASH codegen "inconsistent stackdepth at block 2 via fallthrough (want 1 have 2)" | flowgraph block-depth for unwind edges | M |
| 6 | for/else (and while/else) followed by more code | CRASH "Invalid CFG, instructions after terminator"; module-scope variant DIVERGE co_code+missing const | flowgraph visit_try-family tail bug generalizes to loop-else tails | M |
| 7 | async-with | CRASH compiler NameError: `await_send_loop` used at compiler_exc.jac:138 without import from compiler_emit.jac | compiler_exc.jac (one-line import fix) + then ceval SEND/ASYNC paths | S (crash) / L (runtime) |
| 8 | String escape decoding: `\uXXXX` stored raw (`'tab\thereu20ac'` vs oracle `'tab\there€'`); `\t` works | DIVERGE const | parser/string-literal unescape pass | S |
| 9 | Bytes literals materialize as str-tagged consts (`b'abc'` hashkey tag `s:`) | DIVERGE const | parser/literals slice bytes literal construction | S |
| 10 | match statements in fn scope (tuple, list, class-as, guard, mapping) | DIVERGE nested co_code+linetable; runtime semantics happen correct | compiler_match.jac fn-scope emission | M |
| 11 | Conditional expression `1 if flag else 2` | DIVERGE co_code+linetable at module scope | compiler_codegen jump synthesis | S |
| 12 | augassign on attribute (`o.a *= 2`) in fn scope | DIVERGE nested co_code (subscript form is linetable-only) | compiler_codegen AugAssign attr path | S |
| 13 | kw-only def WITH defaults (`def f(*, k=1)`) | DIVERGE co_code + wrong defaults const[1] | compiler_defs arguments lowering | S |
| 14 | lambda with defaults | DIVERGE co_code, missing const (defaults tuple); known CO_NESTED/qualname gap family | compile_lambda_cfg | S-M |
| 15 | decorator WITH args (`@deco(1)`) | DIVERGE co_code, missing const | compiler_codegen decorator call lowering | S |
| 16 | `global` stmt write from fn (module-level bytes also shift) | DIVERGE co_code | compiler_emit name-store path | S |
| 17 | `import a.b as c` and `from . import x` (relative) | DIVERGE co_code/names/const (`from mod import y as z` PASSES) | compiler_codegen Import/ImportFrom alias+level handling | S-M |
| 18 | `__slots__` in class body | DIVERGE nested[C] co_code+names (CPython's **slots** class-body machinery unimplemented; ties to TODO 51 runtime enforcement) | compiler_codegen ClassDef + objects slot wiring | M |
| 19 | Star-unpack inside comprehension (`[*ps]` elt) | DIVERGE nested co_code+exctab | compiler_loops comprehension setup | S-M |
| 20 | Positional-only `/` AFTER a defaulted param (`def f(a, b=2, /)`): parse FAILS (returns None); simple `/` forms parse fine | CRASH parse | parser.jac parameters rule | S |

Runtime probes that PASSED (compile diverges but exec semantics OK or exact):
genexp sum, generators/yield + list(), decorators, match execution, chained assign,
starred assign targets, dict/set displays, module listcomp.

## Items 53/54 scope confirmation

- **Item 53 CONFIRMED, RUNTIME-side (not compiler).** `class P` with `__repr__`
  and `__str__` compiles clean (only the universal linetable delta). At exec:
  `repr(P()) == 'R'` works, `str(P())` yields `'None'`; repr-only classes fail
  str-falls-back-to-repr too. Owner: tp_str synthesis at value-exit (walker/
  objects lane), exactly as ledgered.
- **Item 54 CONFIRMED, RUNTIME slot gap.** `slice(1,2) == slice(1,2)` -> False;
  `!=` on unequal slices correctly True (identity fallback, no richcompare arm).
  Compiler not involved.

## Recommended band-12 slices (priority order)

1. **f-string end-to-end** (#1): JoinedStr lowering to FORMAT_VALUE/BUILD_STRING
   with conversion/format-spec plumbing, plus ceval cases. Highest dogfooding
   impact of any single item; every real program prints via f-strings.
2. **Assembler linetable writer** (#2): one root cause gates byte-exactness for
   ~35 already-co_code-exact shapes. Cheapest large conformance win available;
   do it before any new statement slices so goldens stop red-herring.
3. **Exception control-flow stabilization** (#3-#6): try/finally(+return),
   break/continue-in-try stackdepth, else-tail CFG terminator. These are hard
   crashes blocking whole program families, and the tail-terminator bug already
   blocks band-11 conditional-annotation tests.
4. **Async family unblock** (#7): land the missing `await_send_loop` import fix
   first (S, uncrashes the compiler), then async-for co_code alignment and the
   ceval send/throw runtime path as the follow-on.
5. **Literal fidelity pack** (#8, #9, #13, #14, #15): string escape decoder
   (\u/\x/\N/octal), bytes-literal object tags, and the defaults-tuple consts
   (kw-only defs, lambdas, arg'd decorators). All small, independent, and each
   removes a whole class of golden noise.

Fast-follow smalls if capacity remains: cond-expr jumps (#11), augassign-attr
(#12), import alias/level forms (#17), parser posonly-after-default (#20),
comprehension star-unpack exctab (#19), **slots** class-body machinery (#18).
