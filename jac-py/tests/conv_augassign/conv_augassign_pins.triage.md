# Triage report: `conv_augassign_pins.jac`

- source: reference/cpython/Lib/test/test_augassign.py
- guest leg: 0/5 marks
- pins: **5 passed** / 5 run (+2 quarantined of 7 extracted)

| pin | result | got |
|---|---|---|
| AugAssignTest.testBasic | PASS | |
| AugAssignTest.test_with_unpacking | PASS | |
| AugAssignTest.testInList | PASS | |
| AugAssignTest.testInDict | PASS | |
| AugAssignTest.testSequences | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| AugAssignTest.testCustomMethods1 | uses-self.val |
| AugAssignTest.testCustomMethods2 | unresolved-name:test_self |
