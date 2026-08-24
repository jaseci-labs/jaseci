# Triage report: `conv_contains_pins.jac`

- source: reference/cpython/Lib/test/test_contains.py
- guest leg: 0/2 marks
- pins: **1 passed** / 2 run (+2 quarantined of 4 extracted)

| pin | result | got |
|---|---|---|
| TestContains.test_nonreflexive | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'NEVER_EQ' from '<unknown>'"> |
| TestContains.test_block_fallback | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| TestContains.test_common_tests | unresolved-name:base_set |
| TestContains.test_builtin_sequence_types | uses-self.aList |

## Expected vs got

### TestContains.test_nonreflexive (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'NEVER_EQ' from '<unknown>'">
