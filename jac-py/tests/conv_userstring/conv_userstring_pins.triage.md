# Triage report: `conv_userstring_pins.jac`

- source: reference/cpython/Lib/test/test_userstring.py
- guest leg: 0/3 marks
- pins: **2 passed** / 3 run (+5 quarantined of 8 extracted)

| pin | result | got |
|---|---|---|
| UserStringTest.test_data | PASS | |
| UserStringTest.test_rmod | PASS | |
| UserStringTest.test_implementation | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'swap_attr'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| UserStringTest.test_mixed_add | unresolved-name:UserStringSubclass |
| UserStringTest.test_mixed_iadd | unresolved-name:UserStringSubclass |
| UserStringTest.test_mixed_cmp | self._assert_cmp |
| UserStringTest.test_encode_default_args | self.checkequal |
| UserStringTest.test_encode_explicit_none_args | self.checkequal |

## Expected vs got

### UserStringTest.test_implementation (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'swap_attr'">
