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
