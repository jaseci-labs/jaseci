# PACKETS INDEX: post-Aug-27 workstream packets for Composer 2.5 execution

Written 2026-08-27 as the capability handoff contract after the ox-alpha
token cliff. Each packet is a self-contained recipe; execute in the order
below. Sequencing follows FULL-COMPAT-PLAN.md section 4 (revised x2 after
the QuickRaven I/O census: file I/O verified done at probed depth).

## Execution order and dependencies

| Order | Packet | Depends on | Effort | Unblocks |
|---|---|---|---|---|
| 0 | PACKET-io-edges.md | none | half-day | preserves regression asset; closes W-I/O bookkeeping |
| 1 | PACKET-compression.md | FFI smoke (inside packet) | 2.5-3 days | test_zlib/test_bz2/test_lzma families; pickle/json users |
| 2 | PACKET-subprocess.md | FFI smoke; benefits from compression warm-up | 5-8 days | ~50 suite families incl. everything importing subprocess |
| 3 | PACKET-networking.md | FFI smoke; phases strictly ordered internally | 10-12 days | socket/select/ssl/http/urllib stack, ~60+ families |

Rationale for order: compression is the smallest cbindgen-style job and
proves the externs-link-in-guest-runtime path cheaply before the bigger
packets. Subprocess precedes networking per the revised plan (largest
verified blocker class for real tooling). Networking phase 4 (http/urllib)
may hand off early if pure-Python stdlib import machinery is not ready.

## Shared facts every executor needs

- Guest import precedence in `jac-py/jacpython/ceval.jac`: shim_modules
  (native facades via register_shim_module) beat delegate_modules (host
  delegation registry). Landing a native facade needs no precedence edit;
  delete the stale delegate entry in the same commit as green pins.
- Two-file binding pattern templates live in
  `jac/jaclang/runtimelib/na_stdlib/` (`<mod>.jac` facade +
  `<mod>_native.jac` externs with errno/sign normalization). Copy them,
  do not reinvent.
- Pin harness: `p2_libtest_expect_ok(snippet, expect_stdout=...)` from
  `jac-py/jacpython/layer_p2_libtest.jac`; pin style template:
  `jac-py/jacpython/test_stdlib_delegate.jac`. Capture oracle stdout from
  host python3 before pasting expectations. Never use os.urandom in pins.
- Local gate: `.venv/bin/jac check <file>` (~5s). Do NOT run long suites
  locally; push and let `.github/workflows/jacpy-gates.yml` CI decide.
  Add one matrix line per new test file as its gate lands.
- Reference CPython tree: `reference/cpython/` (pinned 3.14.6). Cite the
  Lib/test source test name in a comment on every pin.
- Shared tree discipline: surgical `git add <paths>`, commit within minutes
  of each green step, never git stash, verify `git log origin/..HEAD`
  contains only your commits before pushing.

## Escalation rule (applies to every packet)

Each packet lists its own STOP conditions. Universal ones: FFI smoke
failure, VM-process segfaults, anything requiring ceval architecture
changes, or any pin stuck red after the packet's stated debugging budget.
Escalate back to a stronger model with a written repro snippet rather than
improvising workarounds.

## Completion tracking

When a packet lands fully green: tick its row here, note the landing SHA,
and flip the corresponding route_hints in jac-py/tools/suite_router.py so
the farm converts and the ratchet absorbs the newly unblocked suite
families (this flip step itself is mechanical; see suite_router.py header).
