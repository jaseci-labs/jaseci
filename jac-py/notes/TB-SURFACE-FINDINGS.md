# TB-SURFACE wave findings (exceptions family, LoudStorm)

Probe/pin wave over traceback surface vs host CPython 3.14. Green shapes are
pinned in jac-py/jacpython/test_tb_surface_pins.jac (product_exec-direct
assertion style). Divergences and a native-codegen crash documented below.

## Pinned green

- __traceback__ non-None after catch; chain headed at the CATCHING frame with
  the call-site lineno; single-frame catch yields one entry at raise line.
- tb_lasti / tb_lineno are ints.
- format_tb list shape matches host exec-from-string behavior: File header
  lines per frame; source-line text omitted on linecache miss.

## Divergences (not pinned; need runtime fixes first)

1. traceback.format_exception(e) returns a ONE-element list with the whole
   rendering concatenated. Host returns per-segment strings (header, one per
   frame, final exception line).
2. print_exception is MISSING from the guest traceback module namespace
   (format_exc/format_tb/format_exception/extract_tb/walk_tb exist).
3. traceback.walk_tb(e.__traceback__) raises
   TypeError "exceptions must derive from BaseException" on a caught
   exception's traceback.

## NATIVE-CODEGEN CRASH (blocks multi-entry walk pins)

Minimal repro (crashes with IndexError "pop from empty list" at OP_RERAISE,
native compile only -- identical source via host marshal compiles and runs
correctly):

    def h():
        raise ValueError('d')
    try:
        h()
    except ValueError as e:
        t = e.__traceback__
        p = []
        while t is not None:
            p.append(t.tb_lineno)
            t = t.tb_next
    raise RuntimeError('obs')

Disassembly proof: the bound-handler as-cleanup epilogue (LOAD_CONST None /
STORE e / DELETE e + RERAISE 1 + RERAISE 0) is laid out BETWEEN the while-loop
head and its body; the loop's JUMP_BACKWARD lands there and executes the
cleanup+RERAISE sequence on the NORMAL path with a 1-entry value stack.
Host-marshal layout for the same source places the loop 82..168 with
POP_EXCEPT inside and reraises after 182. Native etbl also carries overlapping
broad spans ((40,186)/(82,186)) absent from the marshal table.

Suspect: block placement/allocation order in visit_try's bound-handler path
(compiler_exc.jac) interacting with loop backedge targets -- same deferred-
placement class as prior layout bugs. ceval.jac find_handler was also
audited: its first-match-wins scan diverges from CPython's last-match-wins
on overlapping spans; an innermost-wins patch exists but does NOT fix this
crash (the fallthrough is code-layout, not dispatch selection).

Repro scratch: jac-py/jacpython/probe_tb_bisect.jac +
probe_tb_scratch.jac (feat/tb-surface-pins).

## Codegen bug: full disassembly evidence (for the fix lane)

Minimal repro (native crashes, marshal correct): handled exception + tb walk +
trailing module-level raise (see repro above).

NATIVE layout around the failure:

    52 STORE_NAME e          # bind store (match tail)
    54..76 t = e.__traceback__      \
    78..80 p = []                    |  handler body stmts
    82 LC None; 84 STORE e; 86 DELETE e   \  as-cleanup + RERAISE 1 + RERAISE 0
    88 RERAISE 1; 90 RERAISE 0       /  (bound-handler epilogue) -- INLINED MID-BODY
    92 LOAD t; 94 PJIF none         /   loop head
    100..176 loop body (append; t = t.tb_next)
    178 JUMP_BACKWARD -> lands at 82  => executes as-cleanup+RERAISE on the
                                         NORMAL path with 1-entry value stack
    182 LC None; 184 RETURN_VALUE
    186 COPY 3; 188 POP_EXCEPT; 190 RERAISE 1

The bound-handler epilogue blocks are EMITTED INLINE between the second body
statement and the loop head, and the backedge targets them. Host-marshal
layout places POP_EXCEPT + partial cleanup inside the loop range (172..180)
and the reraise chain after 182..196, with the backedge landing safely.

Working hypothesis: block allocation/use ordering in visit_try's
bound-handler path interleaves with while-loop block allocation
(compiler_loops allocates its head during handler-body visitation), and the
as-cleanup/unwind blocks are emitted into the linear stream ahead of the loop
head instead of behind the body. Same deferred/allocation-order placement
class as prior etbl layout bugs.

Fix direction: audit visit_try bound-handler block use() ordering vs
compiler_loops allocations; likely need deferred blocks for the as-cleanup/
reraise chain (placed at their semantic position AFTER body completion), or
allocation-order restoration for loop heads inside handler bodies.

ceval note: find_handler first-match-wins vs CPython last-match-wins remains
open separately (innermost-wins patch drafted, does not affect this crash).

## Routing divergence (facade vs proxy by import context)

heapq_push_pop / heapq_heapify / collections_counter libtest snippets FAIL
when invoked via direct p2_libtest_run_snippet calls from a tests/ pins file
(reproduced on clean tips 5f1eef605 and 49e9728a2), but PASS through
NiceStorm's libtest-driver run on the same tip. Same snippets, same VM --
different import/facade routing path by invocation context. Real finding per
orchestrator adjudication; owner: converter/test-support family
(SlatePetrel canary reconciliation).

## GENERALIZED (post-repro-matrix): while-in-except-handler is broken on native compile

The tb-walk repro was an instance of a broader bug. Matrix on clean tip
49e9728a2, native compile:

| Shape | Result |
|---|---|
| while loop inside BOUND except handler | IndexError "pop from empty list" at OP_RERAISE |
| while loop inside UNBOUND except handler | wrong-error: TypeError "exceptions must derive from BaseException" surfaced from unrelated attr call |
| while loop inside TRY BODY (not handler) | correct |
| straight-line statements in handler | correct |

So ANY `while` in an except handler body miscompiles natively; no traceback
objects required. The tb-walk pins were simply the first probes to hit it.
Repro probes: probe_min4.jac (feat/tb-surface-pins, Q1/Q2/Q3).

Fix locus hypothesis unchanged: handler-body visitation emits epilogue blocks
into the linear stream ahead of the loop head (allocation/use-order
interleave between visit_try bound/unbound paths and compiler_loops).
