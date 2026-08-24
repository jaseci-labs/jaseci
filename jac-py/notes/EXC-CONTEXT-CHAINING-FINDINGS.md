# RETRACTED: __context__ self-reference report was a harness artifact

__STATUS: RETRACTED.__ The self-referential __context__ observation does not
reproduce on the real guest execution path (product_exec's own module run).
Three product_exec-direct assertion probes -- plain re-raise-in-except,
ExceptionGroup context threading through split(), and cause threading --
all pass byte-exact on clean tip 9f36fdd96 AND on the P3 kernel branch.

Root cause of the false positive: the exec_code(co, [], explicit-globals)
readback harness used by_run_native loses module-global bindings once a
handled exception exists anywhere in the run (module "completes" without an
error outcome, but globals written before/during handling are absent), so
probes read stale/None values and misreported them as chain corruption.

Residual value: embedders calling exec_code with explicit globals should
know handled-exception runs may not surface global writes there
(possible ceval seam, low priority, non-guest-visible). Guest-visible
chaining semantics are correct.

Lane: exceptions family (LoudStorm). Verified pre-existing on clean tip
9f36fdd96. Blocks 2 P3 kernel pins (__context__/__cause__ threading); runtime
impact broader: implicit exception chaining appears systematically wrong for
exceptions raised INSIDE an except handler.

## Symptom

    try:
        try:
            raise ValueError('inner')
        except ValueError:
            raise TypeError('mid')          # any NEW exception
    except TypeError as t:
        type(t.__context__).__name__        # -> 'TypeError'  (self!)
                                                # host: 'ValueError'

The raised exception's __context__ points at ITSELF instead of the active
handled exception. Same for groups (ExceptionGroup raised in except ->
__context__ == the group). `raise ... from cause` cause-threading through
split() is separately fine at readback; the group-context case blocks P3 pins
"__context__/__cause__ threads onto derived match group".

## Repro harness

_run_native pattern from test_exception_group_kernel_pins.jac (product_exec +
exec_code, read module global r):

    try:
        try:
            raise ValueError('inner')
        except ValueError:
            raise TypeError('mid')
    except TypeError as t:
        r = type(t.__context__).__name__   # guest: 'TypeError'; host: 'ValueError'

## Suspect region

ceval.jac OP_RAISE_VARARGS handling ~14290-14320: implicit-chaining block reads
`handled_exc = exc_handling[len(exc_handling)-1]` with guards
`(result as PyError).exception.context is None` and `not (handled_exc is raised)`.
Observed behavior implies either (a) the new exception is pushed to
exc_handling BEFORE the context decision (top == raised -> guard trips -> some
other site assigns self), or (b) a handler-entry/catch path normalizes
context after the fact. Note bare re-raise (`raise`) correctly preserves
chains, and exceptions raised OUTSIDE any handler are unaffected -- the bug
needs handler-active state plus a fresh exception.

## Scope note

Generic ceval chaining semantics -- serialized-ceval domain, not a lane-local
fix. Suggested first probes: instrument exc_handling push/pop sites around
OP_RAISE_VARARGS; diff handler-entry order for [catch -> raise-new] vs
[try-body raise].
