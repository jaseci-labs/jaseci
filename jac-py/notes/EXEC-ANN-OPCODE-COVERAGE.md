# EXEC-PATH ANNOTATIONS + OPCODE COVERAGE GAP (NiceStone/NiceStorm RCA addendum)

## Correction to the opcode-36 premise

Guest numbering matches host exactly: `jac-py/jacpython/opcode_meta.jac` is
GENERATED from CPython `opcode_ids.h`, and OP_SETUP_ANNOTATIONS = 36 on both
sides. The SystemError was a MISSING DISPATCH ARM, not a numbering mismatch.
An arm is now landed (binds empty __annotations__ when absent).

## The bigger finding: 3.14 does not emit SETUP_ANNOTATIONS for modules

Host 3.14 compiles `x: int = 5` (module level) into PEP 649/749 lazy-
annotation machinery instead:
    MAKE_CELL 0 (__conditional_annotations__)
    LOAD_CONST <code object __annotate__>
    MAKE_FUNCTION / STORE_NAME __annotate__
    BUILD_SET 0 / STORE_NAME __conditional_annotations__
    LOAD_SMALL_INT 5 / STORE_NAME x
    ... SET_ADD, RETURN_VALUE
Consequence: exec()-path annotation support requires the PEP 649 opcode
family plus the __annotate__/__conditional_annotations__ runtime protocol --
NOT a single arm. This is the same machinery family already tracked as the
"PEP 649 lazy annotations" backlog item; exec-path coverage joins that lane.

## Guest convention divergence (pre-existing)

The guest's own compiled path stores annotation VALUES as name strings:
module-level `x: int = 5` yields __annotations__ == {'x': 'int'} on the
libtest/native path. Host 3.14 stores the type object (via __annotate__
evaluation on demand). Any consumer comparing annotation values across
host/guest will see this -- separate fingerprint from the dispatch gap.

## Opcode coverage audit suggestion

With numbering confirmed identical, the remaining exec-path risk is MISSING
ARMS for ops host emits but guest never generates itself. Mechanical check:
disassemble a broad corpus via host dis() over Lib/**/*.py compile(), collect
opcode set, diff against ceval.jac dispatch arms (grep 'if op == OP_'). Any
op in host corpus but absent from dispatch = latent exec-path crash. Cheap to
script; recommended before expanding exec-path test surface.

## Landed in this round

- SETUP_ANNOTATIONS arm (older-marshal payloads; zero cost elsewhere).
- Probes confirming arm dispatches and binds correctly.
