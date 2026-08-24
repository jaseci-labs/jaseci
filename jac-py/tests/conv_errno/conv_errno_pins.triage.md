# Triage report: `conv_errno_pins.jac`

- source: reference/cpython/Lib/test/test_errno.py
- guest leg: 0/1 marks
- pins: **1 passed** / 1 run (+2 quarantined of 3 extracted)

| pin | result | got |
|---|---|---|
| ErrorcodeTests.test_attributes_in_errorcode | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| ErrnoAttributeTests.test_for_improper_attributes | self.assertHasAttr |
| ErrnoAttributeTests.test_using_errorcode | self.assertHasAttr |
