# EXEC WRITEBACK / EXEC-COMPILED FUNCTION GAP -- RCA (NiceStorm)

## Symptom (farm fp: conv_unpack + MintIce wave5i listcomp reds)

exec()-defined functions fail when their bodies contain tuple-unpack
assignments: "ValueError: not enough values to unpack (expected N, got 0)".
Simple-return bodies work. ~54 listcomp reds share this family.

## Bisect results (all on conv/selfhost-six @ d4680219c base)

| Shape | Result |
|---|---|
| exec at module level, def f(x): return x[0] / len(x) / x+1 | PASS |
| exec def with (a,b,c)=x unpack, module level | PASS (w3-style) |
| SAME string, N=5 dup names + trailing comma, module level | FAIL got 0 |
| exec INSIDE function, distinct names | PASS |
| exec INSIDE function, duplicate names | PASS |
| exec in for-loop body over list-of-(tag,code), N=1..400 all shapes | FAIL ALL |
| 400-target via concat or f-string: identical failures | FAIL |

The inconsistency (near-identical strings flip pass/fail depending on
enclosing statement context) rules out the code STRINGS and points at
execution state / opcode handling.

## Prime suspect: host/guest opcode numbering-space mismatch

Guest-executed code carries GUEST enum numbering; exec-path code is compiled
by the HOST (via _jac_host_source_marshal -> compile -> marshal) and carries
HOST 3.14 numbering. Where the two enums disagree, dispatch misfires.
EpicEagle independently identified a concrete instance: host opcode 36 =
SETUP_ANNOTATIONS reaches guest dispatch unhandled (guest 36 =
JUMP_BACKWARD_NO_INTERRUPT) -> SystemError at ceval.jac:16150
(MintIce conv_type_annotations red). Annotation-heavy modules hit it on
import-shaped exec.

Tuple-unpack correlation fits the same family: host 3.14 may emit opcode
sequences (or numbers) around UNPACK_SEQUENCE/STORE_NAME variants that the
guest either mistranslates or partially supports, and which specific shapes
fail depends on surrounding frame state -- matching the flip-flop bisect.

## Repros (kept)

- jac-py/jacpython/probe_execwb6.jac -- N-sweep, all fail (5..400)
- jac-py/jacpython/probe_execwb7.jac -- context matrix, all pass
- jac-py/jacpython/probe_execwb8.jac -- minimal failing case w/ repr of code str
- jac-py/jacpython/probe_execwb9.jac -- 4-shape matrix incl. trailing comma
- jac-py/tests/conv_unpack/conv_unpack_pins.jac pin 1 -- original farm shape

## Recommended fix direction (for owner decision)

1. SHORT: opcode remap table host->guest applied at unmarshal time on the
   exec path (mirror of any existing pyc-load remapping), plus a
   SETUP_ANNOTATIONS arm (bind empty __annotations__ dict when absent).
   Enumerate divergent opcodes by diffing host dis() vs guest enum for the
   ~30 most common ops.
2. LONG: converge guest enum onto host 3.14 numbering so exec/marshal paths
   need no translation (bigger blast radius; schedule as design block).
3. Either way, add conv_unpack pins + annotation-exec pins to the ratchet
   once green.

## Not the cause (ruled out)

- Harness pollution (fails identically via exec_code product path)
- Code-string construction (repr verified correct; f-string vs concat equal)
- Trailing commas, duplicate names, N size, EXTENDED_ARG thresholds
- exec-into-dict binding itself (ns['f'] retrieval works; simple bodies run)
