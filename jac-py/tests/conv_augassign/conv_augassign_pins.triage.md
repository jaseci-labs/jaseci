# Triage report: `conv_augassign_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_augassign.py
- guest leg: 0/6 marks
- pins: **5 passed** / 6 run (+1 quarantined of 7 extracted)

| pin | result | got |
|---|---|---|
| AugAssignTest.testBasic | PASS | |
| AugAssignTest.test_with_unpacking | PASS | |
| AugAssignTest.testInList | PASS | |
| AugAssignTest.testInDict | PASS | |
| AugAssignTest.testSequences | PASS | |
| AugAssignTest.testCustomMethods1 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertTrue\', False)"'> |

## Quarantined at conversion

| test | reason |
|---|---|
| AugAssignTest.testCustomMethods2 | unresolved-name:test_self |

## Expected vs got

### AugAssignTest.testCustomMethods1 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertTrue\', False)"'>
