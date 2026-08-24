# Triage report: `conv_unicode_identifiers_pins.jac`

- source: reference/cpython/Lib/test/test_unicode_identifiers.py
- guest leg: 0/2 marks
- pins: **0 passed** / 2 run (+1 quarantined of 3 extracted)

| pin | result | got |
|---|---|---|
| PEP3131Test.test_valid | VM-CRASH | 🛠  jac dev mode - using compiler source at /var/tmp/wp4-mech-tree/jac ✖ Error: 'utf-8' codec can't encode characters in position 214-215: surrogates not allowed   629 \| # acyclic import (see PLAN.md §4 module-boundary constraint).   630 \| def host_compile_marshal(source: str) -> list[int] {   631 \|  |
| PEP3131Test.test_non_bmp_normalized | VM-CRASH | 🛠  jac dev mode - using compiler source at /var/tmp/wp4-mech-tree/jac ✖ Error: 'utf-8' codec can't encode characters in position 214-215: surrogates not allowed   629 \| # acyclic import (see PLAN.md §4 module-boundary constraint).   630 \| def host_compile_marshal(source: str) -> list[int] {   631 \|  |

## Quarantined at conversion

| test | reason |
|---|---|
| PEP3131Test.test_invalid | host-raised:ModuleNotFoundError: No module named 'test' |

## Expected vs got

### PEP3131Test.test_non_bmp_normalized (VM-CRASH)

- expected: host oracle = `ok`
- got: 🛠  jac dev mode - using compiler source at /var/tmp/wp4-mech-tree/jac
✖ Error: 'utf-8' codec can't encode characters in position 214-215: surrogates not allowed
  629 | # acyclic import (see PLAN.md §4 module-boundary constraint).
  630 | def host_compile_marshal(source: str) -> list[int] {
  631 |

### PEP3131Test.test_valid (VM-CRASH)

- expected: host oracle = `ok`
- got: 🛠  jac dev mode - using compiler source at /var/tmp/wp4-mech-tree/jac
✖ Error: 'utf-8' codec can't encode characters in position 214-215: surrogates not allowed
  629 | # acyclic import (see PLAN.md §4 module-boundary constraint).
  630 | def host_compile_marshal(source: str) -> list[int] {
  631 |
