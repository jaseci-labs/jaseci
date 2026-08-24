# Triage report: `conv_string_literals_pins.jac`

- source: reference/cpython/Lib/test/test_string_literals.py
- guest leg: 0/10 marks
- pins: **9 passed** / 10 run (+10 quarantined of 20 extracted)

| pin | result | got |
|---|---|---|
| TestLiterals.test_template | PASS | |
| TestLiterals.test_eval_str_normal | PASS | |
| TestLiterals.test_eval_str_incomplete | PASS | |
| TestLiterals.test_invalid_escape_locations_with_offset | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 0, 1)"'> |
| TestLiterals.test_eval_str_raw | PASS | |
| TestLiterals.test_eval_bytes_normal | PASS | |
| TestLiterals.test_eval_bytes_incomplete | PASS | |
| TestLiterals.test_eval_bytes_raw | PASS | |
| TestLiterals.test_eval_str_u | PASS | |
| TestLiterals.test_uppercase_prefixes | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| TestLiterals.test_eval_str_invalid_escape | self.assertRegex |
| TestLiterals.test_eval_str_invalid_octal_escape | uses-self.assertWarns |
| TestLiterals.test_eval_bytes_invalid_escape | uses-self.assertWarns |
| TestLiterals.test_eval_bytes_invalid_octal_escape | uses-self.assertWarns |
| TestLiterals.test_file_utf_8 | self.check_encoding |
| TestLiterals.test_file_utf_8_error | uses-self.check_encoding |
| TestLiterals.test_file_utf8 | self.check_encoding |
| TestLiterals.test_file_iso_8859_1 | self.check_encoding |
| TestLiterals.test_file_latin_1 | self.check_encoding |
| TestLiterals.test_file_latin9 | self.check_encoding |

## Expected vs got

### TestLiterals.test_invalid_escape_locations_with_offset (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', 0, 1)"'>
