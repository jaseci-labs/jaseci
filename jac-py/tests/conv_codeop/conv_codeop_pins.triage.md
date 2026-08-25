# Triage report: `conv_codeop_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_codeop.py
- guest leg: 0/4 marks
- pins: **0 passed** / 4 run (+5 quarantined of 9 extracted)

| pin | result | got |
|---|---|---|
| CodeopTests.test_filename | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'category must be a Warning subclass'"> |
| CodeopTests.test_incomplete_warning | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'category must be a Warning subclass'"> |
| CodeopTests.test_invalid_warning | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'category must be a Warning subclass'"> |
| CodeopTests.test_syntax_errors | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'category must be a Warning subclass'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| CodeopTests.test_warning | uses-self.assertRaises |
| CodeopTests.test_valid | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertValid' |
| CodeopTests.test_incomplete | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertIncomplete' |
| CodeopTests.test_invalid | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertInvalid' |
| CodeopTests.test_invalid_exec | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertInvalid' |

## Expected vs got

### CodeopTests.test_filename (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'category must be a Warning subclass'">

### CodeopTests.test_incomplete_warning (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'category must be a Warning subclass'">

### CodeopTests.test_invalid_warning (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'category must be a Warning subclass'">

### CodeopTests.test_syntax_errors (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'category must be a Warning subclass'">
