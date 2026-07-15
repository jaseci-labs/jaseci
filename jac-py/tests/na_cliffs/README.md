# T7 — known-na-cliffs conformance gate

The na-clean object core (`Objects/`) is validated against Jac's native backend
**from day one**, so the dual-substrate bet (PLAN.md §4, D4) is continuously
tested rather than discovered broken at P7. This directory is the seed.

Each cliff isolates one documented na landmine **as jacpython's core already
uses it** — these are not abstract; they are the exact shapes in the marshal
reader, `exec_module`, `deref_cell`, and `bytes_to_str`.

## The cliffs

| Fixture | na landmine | jac-py core site | Memory |
|---|---|---|---|
| `cliff_list_int_subscript.na.jac` | `list[int]` subscript | `Reader.r_byte`: `self.data[self.pos]` | na-container-capabilities-2026-07 |
| `cliff_dict_return.na.jac` | dict build/return/subscript (ICE?) | `exec_module() -> dict[str, PyObj]`, `PyDict.items` | na-container-capabilities-2026-07 |
| `cliff_union_receiver.na.jac` | field on `T\|None` receiver (silent drop) | `deref_cell/find_cell/find_handler -> …\|None` then `.val`/`.target` | na-method-call-on-union-receiver |
| `cliff_binary_buffer.na.jac` | str concat drops NUL, `len`=strlen | `bytes_to_str` builds str from bytes incl NUL | na-chr-concat-drops-nul, na-len-strlen-binary-guard |

## Two gates

**Local (compile gate).** `jac nacompile <cliff>.na.jac` must reach
`Object code emitted` with **no `E5090`** and no compiler ICE. Runs without the
LLVM shim — capability check + IR-gen + object emit all happen before the
musl-link step. Drive with `./t7_gate.sh`.

**CI (runtime gate).** Link the emitted object (vendored musl, or system `cc`
per commit f9a89e079) and run it; diff the result against the bytecode-backend
truth pinned in `na_cliffs_ref.jac`. This is what catches the *runtime*
miscompiles (NUL-drop → `len` returns 1 not 2; union-receiver-drop → wrong
value) that compile cleanly but compute the wrong answer.

## Measured status (local, 2026-07-15)

All four **pass the compile gate**: capability-clean, LLVM IR generated, object
code emitted (6.4–8.5 KB). Only the final static-musl link is blocked locally
(environment, not code — no vendored musl on this box). Runtime-correctness legs
are therefore **pending CI** (or a local musl / system-`cc` link). Notably the
dict-return shape did **not** ICE here — better than the folklore; the ratchet
records the measured truth per CPython/jaclang bump.

**The leaf itself compiles.** `t7_gate.sh` also nacompiles the whole na-clean
object core (`jacpython/objects.jac`) self-contained: all 18 data types + slots
+ the `isinstance`-based helpers generate LLVM IR and emit **122 KB of object
code** with zero E5090 (musl link env-blocked, as above). So the leaf is na-clean
in fact, not just by inspection.

**Known na multi-module gap.** Compiling `objects.jac` via a separate entry that
`import from objects { … }` fails with E5090 on the *imported* symbols — na's
multi-module native resolution (see memory `na-resolver-import-order-priming`,
`na-shared-multimodule-rc-wrapper`), not a leaf defect. The eventual
`jacpython.na.jac` native entry will need the flat-module-set priming or the
`--shared` path; tracked for P7.
