# M9 tb-traversal slice -- findings (NiceStorm, 2026-08-27)

## Verdict

**tb traversal is already host-exact on tip `9f36fdd96`.** The prereq intel
("walking tb.tb_next does NOT reproduce host frame chain") is STALE -- every
structural shape now matches host CPython 3.14 byte-for-byte on names, order,
and cause chains. The real gap was the missing `traceback` MODULE surface,
now landed as a native shim.

## Probe matrix (host vs guest, product path via exec_code)

| Scenario | Host | Guest | Match |
|---|---|---|---|
| A: nested raise, catch in caller | `outer@8\|inner@4` | same | YES |
| B: throw into suspended generator | single gen frame at yield line | same | YES |
| E: 3-layer propagation to top-level try | module\|lvl1\|lvl2\|lvl3 w/ linenos | same | YES |
| F: catch + bare re-raise accumulates catcher frame | module\|catcher\|lvl1\|lvl2\|lvl3 | same | YES |
| G: raise-from: new tb module-only, **cause** keeps own chain | yes | same | YES |
| H: traceback.extract_tb/format_tb/walk_tb/format_exception | -- | was bridge FAIL → now native shim | FIXED |

(The earlier "digest anomalies" likely predate recent ceval lands or were
measured through the poisoned libtest harness (see fake-shim saga).)

## The gap that DID exist: no `traceback` module surface

`import traceback` succeeded only as a host proxy; the first call passing a
native PyTraceback across the bridge died:
`bridge-table: type 'traceback' has policy BridgePolicy.FAIL but no to_host arm`.
A to_host arm is NOT viable: host types.TracebackType requires a REAL host
frame and guest frames have none. Fix = native surface over the guest chain,
reusing tb_render.jac's linecache-backed formatting (missing source degrades
exactly like the interpreter).

## Landed (branch conv/selfhost-six)

`jac-py/jacpython/tracebackmodule.jac`: extract_tb / format_tb / print_tb /
format_exception (3.14 one-arg form incl. cause/context via tb_format) /
walk_tb + FrameSummary-shaped objects. Registered lazily at both ceval import
resolution sites (weakref/types pattern). Documented v1 divergences in the
file header: plain list not StackSummary subclass, walk_tb returns list,
file= only default stream, TracebackException/format_exc absent.
Gates: jac check tracebackmodule.jac + ceval.jac PASS; probe matrix above all
green post-fix.

## Follow-ups for cadence lane

- tb_lineno provenance across generator throw-in matches host (yield line).
- Remaining unprobed shapes: async-for/athrow chains (M12 territory),
  exception-group traversal, sys.exc_info() interaction with format_exc().
